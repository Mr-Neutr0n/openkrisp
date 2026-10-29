#include "call_capture.hpp"
#import <Foundation/Foundation.h>
#import <CoreAudio/CATapDescription.h>
#include <CoreAudio/AudioHardwareTapping.h>
#include <AudioToolbox/AudioToolbox.h>
#include <cerrno>
#include <cmath>
#include <cstring>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

namespace labvoice {
namespace {
bool status(OSStatus value, const char* operation, std::string& error) {
    if (value == noErr) return true;
    error = std::string(operation) + "_OSStatus_" + std::to_string(value); return false;
}
class NativeDriver final : public CallCaptureDriver {
    AudioObjectID tap_ = kAudioObjectUnknown, aggregate_ = kAudioObjectUnknown;
    AudioDeviceIOProcID io_ = nullptr;
    Sink sink_ = nullptr; void* context_ = nullptr;
    std::string tapUID_;
    AudioStreamBasicDescription format_{};
    static OSStatus input(AudioObjectID, const AudioTimeStamp*, const AudioBufferList* data,
                          const AudioTimeStamp* time, AudioBufferList*, const AudioTimeStamp*, void* context) noexcept {
        auto& self = *static_cast<NativeDriver*>(context);
        self.sink_(self.context_, data, time); return noErr;
    }
public:
    bool createTap(const CallCaptureTarget& target, AudioStreamBasicDescription& format, std::string& error) override {
        if (@available(macOS 14.4, *)) {
            @autoreleasepool {
                NSMutableArray<NSNumber*>* objects = [NSMutableArray arrayWithCapacity:target.processes.size()];
                for (const auto& process : target.processes) [objects addObject:@(process.objectID)];
                CATapDescription* description = [[CATapDescription alloc] initStereoMixdownOfProcesses:objects];
                description.name = @"OpenKrisp selected application output";
                description.UUID = [NSUUID UUID];
                description.privateTap = YES;
                description.exclusive = NO;
                description.muteBehavior = CATapUnmuted;
                if (@available(macOS 26.0, *)) description.processRestoreEnabled = NO;
                tapUID_ = description.UUID.UUIDString.UTF8String;
                const auto created = AudioHardwareCreateProcessTap(description, &tap_);
#if !__has_feature(objc_arc)
                [description release];
#endif
                if (!status(created, "create_selected_process_tap", error)) return false;
                AudioObjectPropertyAddress address{kAudioTapPropertyFormat, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
                UInt32 size = sizeof format_;
                if (!status(AudioObjectGetPropertyData(tap_, &address, 0, nullptr, &size, &format_), "read_tap_format", error)) return false;
                if (size != sizeof format_) { error = "invalid_tap_format_size"; return false; }
                format = format_; return true;
            }
        }
        error = "selected_capture_requires_macos_14_4"; return false;
    }
    bool createAggregate(std::string& error) override {
        @autoreleasepool {
            NSString* uid = [NSUUID UUID].UUIDString;
            NSString* tapUID = [NSString stringWithUTF8String:tapUID_.c_str()];
            NSDictionary* composition = @{
                @kAudioAggregateDeviceNameKey: @"OpenKrisp private selected audio",
                @kAudioAggregateDeviceUIDKey: uid,
                @kAudioAggregateDeviceIsPrivateKey: @YES,
                @kAudioAggregateDeviceIsStackedKey: @NO,
                // SDK: YES makes AudioDeviceStart wait for first tapped audio.
                // NO permits explicit IO start without waiting for app output.
                @kAudioAggregateDeviceTapAutoStartKey: @NO,
                @kAudioAggregateDeviceSubDeviceListKey: @[],
                @kAudioAggregateDeviceTapListKey: @[@{@kAudioSubTapUIDKey: tapUID, @kAudioSubTapDriftCompensationKey: @NO}]
            };
            if (!status(AudioHardwareCreateAggregateDevice((__bridge CFDictionaryRef)composition, &aggregate_), "create_private_tap_aggregate", error)) return false;
            AudioObjectPropertyAddress address{kAudioDevicePropertyStreamFormat, kAudioObjectPropertyScopeInput, kAudioObjectPropertyElementMain};
            AudioStreamBasicDescription actual{}; UInt32 size = sizeof actual;
            if (!status(AudioObjectGetPropertyData(aggregate_, &address, 0, nullptr, &size, &actual), "read_aggregate_input_format", error)) return false;
            if (size != sizeof actual || !supportedCallCaptureFormat(actual) || actual.mSampleRate != format_.mSampleRate || actual.mFormatID != format_.mFormatID || actual.mFormatFlags != format_.mFormatFlags || actual.mChannelsPerFrame != format_.mChannelsPerFrame || actual.mBytesPerFrame != format_.mBytesPerFrame || actual.mBytesPerPacket != format_.mBytesPerPacket || actual.mFramesPerPacket != format_.mFramesPerPacket || actual.mBitsPerChannel != format_.mBitsPerChannel) {
                error = "tap_and_aggregate_format_mismatch"; return false;
            }
            return true;
        }
    }
    bool validateFormat(const AudioStreamBasicDescription& expected, std::string& error) override {
        for (const auto& item : {std::pair<AudioObjectID, AudioObjectPropertyAddress>{tap_, {kAudioTapPropertyFormat, kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain}},
                                std::pair<AudioObjectID, AudioObjectPropertyAddress>{aggregate_, {kAudioDevicePropertyStreamFormat, kAudioObjectPropertyScopeInput, kAudioObjectPropertyElementMain}}}) {
            AudioStreamBasicDescription current{}; UInt32 size = sizeof current;
            if (!status(AudioObjectGetPropertyData(item.first, &item.second, 0, nullptr, &size, &current), "revalidate_capture_format", error)) return false;
            if (size != sizeof current || current.mSampleRate != expected.mSampleRate || current.mFormatID != expected.mFormatID || current.mFormatFlags != expected.mFormatFlags || current.mChannelsPerFrame != expected.mChannelsPerFrame || current.mBytesPerFrame != expected.mBytesPerFrame || current.mBytesPerPacket != expected.mBytesPerPacket || current.mFramesPerPacket != expected.mFramesPerPacket || current.mBitsPerChannel != expected.mBitsPerChannel) {
                error = "selected_capture_source_format_changed"; return false;
            }
        }
        return true;
    }
    bool registerIO(Sink sink, void* context, std::string& error) override {
        sink_ = sink; context_ = context;
        return status(AudioDeviceCreateIOProcID(aggregate_, input, this, &io_), "register_tap_io", error);
    }
    bool start(std::string& error) override { return status(AudioDeviceStart(aggregate_, io_), "start_tap_io", error); }
    bool stop(std::string& error) override { return !io_ || status(AudioDeviceStop(aggregate_, io_), "stop_tap_io", error); }
    bool unregisterIO(std::string& error) override {
        if (!io_) return true;
        if (!status(AudioDeviceDestroyIOProcID(aggregate_, io_), "unregister_tap_io", error)) return false;
        io_ = nullptr; return true;
    }
    bool destroyAggregate(std::string& error) override {
        if (!aggregate_) return true;
        if (!status(AudioHardwareDestroyAggregateDevice(aggregate_), "destroy_private_aggregate", error)) return false;
        aggregate_ = kAudioObjectUnknown; return true;
    }
    bool destroyTap(std::string& error) override {
        if (!tap_) return true;
        if (@available(macOS 14.4, *)) {
            if (!status(AudioHardwareDestroyProcessTap(tap_), "destroy_selected_tap", error)) return false;
            tap_ = kAudioObjectUnknown; return true;
        }
        error = "tap_cleanup_api_unavailable"; return false;
    }
};
class NativeWriter final : public CallCaptureWriter {
    ExtAudioFileRef file_ = nullptr;
    AudioFileID audioFile_ = nullptr;
    std::string parent_, basename_;
    int directory_ = -1, fd_ = -1;
    struct stat directoryIdentity_{}, fileIdentity_{};
    bool failed_ = false;
    static constexpr uint64_t maximumBytes = callCaptureWavMaximumBytes;
    static OSStatus readBytes(void* context, SInt64 position, UInt32 requested, void* buffer, UInt32* actual) {
        *actual = 0;
        if (position < 0 || uint64_t(position) + requested > maximumBytes) return kAudioFilePositionError;
        while (*actual < requested) {
            auto count = pread(*static_cast<int*>(context), static_cast<char*>(buffer) + *actual, requested - *actual, position + *actual);
            if (count < 0 && errno == EINTR) continue;
            if (count < 0) return kAudioFileUnspecifiedError;
            if (!count) break;
            *actual += UInt32(count);
        }
        return noErr;
    }
    static OSStatus writeBytes(void* context, SInt64 position, UInt32 requested, const void* buffer, UInt32* actual) {
        *actual = 0;
        if (position < 0 || uint64_t(position) + requested > maximumBytes) return kAudioFilePositionError;
        while (*actual < requested) {
            auto count = pwrite(*static_cast<int*>(context), static_cast<const char*>(buffer) + *actual, requested - *actual, position + *actual);
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) return kAudioFileUnspecifiedError;
            *actual += UInt32(count);
        }
        return noErr;
    }
    static SInt64 fileSize(void* context) { struct stat info{}; return fstat(*static_cast<int*>(context), &info) ? -1 : info.st_size; }
    static OSStatus setSize(void* context, SInt64 size) {
        return size < 0 || uint64_t(size) > maximumBytes || ftruncate(*static_cast<int*>(context), size) ? OSStatus(kAudioFileUnspecifiedError) : OSStatus(noErr);
    }
    bool identitiesMatch() const {
        struct stat parent{}, entry{}, descriptor{};
        return directory_ >= 0 && fd_ >= 0 && !lstat(parent_.c_str(), &parent) && S_ISDIR(parent.st_mode) &&
            parent.st_dev == directoryIdentity_.st_dev && parent.st_ino == directoryIdentity_.st_ino && parent.st_uid == getuid() && (parent.st_mode & 0777) == 0700 &&
            !fstatat(directory_, basename_.c_str(), &entry, AT_SYMLINK_NOFOLLOW) && !fstat(fd_, &descriptor) &&
            S_ISREG(entry.st_mode) && entry.st_dev == fileIdentity_.st_dev && entry.st_ino == fileIdentity_.st_ino &&
            descriptor.st_dev == entry.st_dev && descriptor.st_ino == entry.st_ino && descriptor.st_uid == getuid() && (descriptor.st_mode & 0777) == 0600;
    }
public:
    ~NativeWriter() override { uint64_t ignored = 0; std::string error; close(ignored, error); }
    bool open(const std::string& path, const AudioStreamBasicDescription& source, std::string& error) override {
        const auto slash = path.rfind('/');
        if (path.empty() || path.front() != '/' || slash == std::string::npos || slash + 1 == path.size() || path.find('\0') != std::string::npos || !path.ends_with(".wav") || !supportedCallCaptureFormat(source)) { error = "invalid_capture_wav_path_or_format"; return false; }
        parent_ = path.substr(0, slash); basename_ = path.substr(slash + 1);
        directory_ = ::open(parent_.c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (directory_ < 0 || fstat(directory_, &directoryIdentity_) || directoryIdentity_.st_uid != getuid() || (directoryIdentity_.st_mode & 0777) != 0700) {
            error = "capture_directory_must_be_owned_private_0700"; failed_ = true; return false;
        }
        fd_ = openat(directory_, basename_.c_str(), O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
        if (fd_ < 0 || fchmod(fd_, 0600) || fstat(fd_, &fileIdentity_) || !identitiesMatch()) { error = "exclusive_capture_file_create_failed"; failed_ = true; return false; }
        AudioStreamBasicDescription destination{};
        destination.mSampleRate = 48000; destination.mFormatID = kAudioFormatLinearPCM;
        destination.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        destination.mBytesPerPacket = 4; destination.mFramesPerPacket = 1; destination.mBytesPerFrame = 4;
        destination.mChannelsPerFrame = 2; destination.mBitsPerChannel = 16;
        // AudioFile can only reach the O_EXCL-created descriptor, never reopen a path.
        if (!status(AudioFileInitializeWithCallbacks(&fd_, readBytes, writeBytes, fileSize, setSize, kAudioFileWAVEType, &destination, 0, &audioFile_), "initialize_capture_wav", error) ||
            !status(ExtAudioFileWrapAudioFileID(audioFile_, true, &file_), "wrap_capture_wav", error)) { failed_ = true; return false; }
        auto client = source;
        client.mFormatFlags &= ~(kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsNonMixable);
        client.mBytesPerFrame = client.mBytesPerPacket = 8;
        if (!status(ExtAudioFileSetProperty(file_, kExtAudioFileProperty_ClientDataFormat, sizeof client, &client), "set_capture_conversion_format", error)) { failed_ = true; return false; }
        return true;
    }
    bool write(const float* stereo, uint32_t frames, std::string& error) override {
        if (!file_ || failed_) { error = "capture_writer_not_open"; return false; }
        AudioBufferList list{1, {{2, frames * 8, const_cast<float*>(stereo)}}};
        if (!status(ExtAudioFileWrite(file_, frames, &list), "write_capture_wav", error)) { failed_ = true; return false; }
        return true;
    }
    bool close(uint64_t& frames, std::string& error) override {
        bool ok = !failed_;
        if (file_) {
            if (!status(ExtAudioFileDispose(file_), "finalize_capture_conversion", error)) ok = false;
            file_ = nullptr;
        }
        if (audioFile_) {
            UInt64 count = 0; UInt32 size = sizeof count;
            if (!status(AudioFileGetProperty(audioFile_, kAudioFilePropertyAudioDataPacketCount, &size, &count), "read_capture_frame_count", error) || size != sizeof count) ok = false;
            else frames = count;
            if (!status(AudioFileClose(audioFile_), "finalize_capture_wav", error)) ok = false;
            audioFile_ = nullptr;
        }
        if (fd_ >= 0) {
            if (!identitiesMatch() || fsync(fd_)) { error = "capture_file_identity_or_sync_failed"; ok = false; }
            ::close(fd_); fd_ = -1;
        }
        if (directory_ >= 0) { if (ok && fsync(directory_)) { error = "capture_directory_sync_failed"; ok = false; } ::close(directory_); directory_ = -1; }
        failed_ = !ok;
        return ok;
    }
};}
std::unique_ptr<CallCaptureWriter> makeCallCaptureWavWriter() { return std::make_unique<NativeWriter>(); }
std::unique_ptr<CallCaptureSession> makeNativeCallCaptureSession() {
    return std::make_unique<CallCaptureSession>(observeAudioProcessUsage, std::make_unique<NativeDriver>(), makeCallCaptureWavWriter());
}
}
