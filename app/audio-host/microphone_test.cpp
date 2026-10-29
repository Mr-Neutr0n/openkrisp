#include "microphone_test.hpp"
#include "control_protocol.hpp"
#include "../noise-engine/streaming_noise.hpp"
#include <algorithm>
#include <array>
#include <cerrno>
#include <chrono>
#include <cmath>
#include <cstring>
#include <fcntl.h>
#include <stdexcept>
#include <sys/stat.h>
#include <thread>
#include <unistd.h>

namespace labvoice {
MicrophoneCapture::MicrophoneCapture(MicrophoneSpec value)
    : spec(std::move(value)), samples(microphoneTestMaximum) {
    if (!spec.device) throw std::invalid_argument("invalid_microphone_device");
    if (spec.channels.empty() || spec.channels.size() > 16)
        throw std::invalid_argument("unsupported_input_buffers");
    for (auto channels : spec.channels)
        if (!channels || channels > 64) throw std::invalid_argument("unsupported_input_channels");
}
void MicrophoneCapture::consume(const AudioBufferList *input, const AudioTimeStamp *time,
                                AudioBufferList *output) noexcept {
    callbacks.fetch_add(1);
    struct Exit { std::atomic<UInt32> &count; ~Exit() { count.fetch_sub(1); } } exit{callbacks};
    // This IOProc never produces media. Zero its bounded duplex output buffers.
    if (output) {
        if (output->mNumberBuffers > 16) { fault = true; enabled = false; return; }
        for (UInt32 i = 0; i < output->mNumberBuffers; ++i) {
            const auto &buffer = output->mBuffers[i];
            if (buffer.mNumberChannels > 64 || buffer.mDataByteSize > microphoneTestCallbackLimit * 64 * 4) {
                fault = true; enabled = false; return;
            }
            if (buffer.mData) std::memset(buffer.mData, 0, buffer.mDataByteSize);
        }
    }
    if (!enabled.load() || fault.load()) return;
    if (rendering.test_and_set()) { fault = true; enabled = false; return; }
    struct Release { std::atomic_flag &flag; ~Release() { flag.clear(); } } release{rendering};
    auto bad = [&] { fault.store(true); enabled.store(false); };
    if (!input || input->mNumberBuffers != spec.channels.size() || !time ||
        !(time->mFlags & kAudioTimeStampSampleTimeValid) || !std::isfinite(time->mSampleTime) ||
        time->mSampleTime < 0 || time->mSampleTime > 9007199254740991.0 - microphoneTestCallbackLimit) {
        bad(); return;
    }
    UInt32 count = 0;
    for (UInt32 i = 0; i < input->mNumberBuffers; ++i) {
        const auto &buffer = input->mBuffers[i];
        const UInt32 stride = spec.channels[i] * 4;
        if (buffer.mNumberChannels != spec.channels[i] || !buffer.mData || buffer.mDataByteSize % stride) {
            bad(); return;
        }
        const UInt32 size = buffer.mDataByteSize / stride;
        if (size > microphoneTestCallbackLimit || (i && size != count)) { bad(); return; }
        count = size;
    }
    if (clockKnown && std::abs(time->mSampleTime - nextSample) > .000001) { bad(); return; }
    clockKnown = true; nextSample = time->mSampleTime + count;
    const UInt32 first = frames.load(std::memory_order_relaxed);
    const UInt32 accepted = std::min(count, microphoneTestMaximum - first);
    const auto &buffer = input->mBuffers[0];
    const auto *values = static_cast<const float *>(buffer.mData);
    for (UInt32 i = 0; i < accepted; ++i) {
        const float value = values[i * spec.channels[0]];
        if (!std::isfinite(value)) { bad(); return; }
        samples[first + i] = value;
    }
    frames.store(first + accepted, std::memory_order_release);
    if (first + accepted == microphoneTestMaximum) { maximumReached = true; enabled = false; }
}
MicrophoneSession::~MicrophoneSession() { (void)stop(); }
bool MicrophoneSession::start(const std::string &uid) {
    if (capture_ || io_ || watched_) { error_ = "session_already_prepared"; return false; }
    try {
        capture_ = std::make_shared<MicrophoneCapture>(backend_.inspect(uid));
        watched_ = true; // watch may partially register before a failure.
        if (backend_.watch(capture_)) throw std::runtime_error("microphone_watch_failed");
        if (capture_->spec != backend_.inspect(uid) || capture_->fault.load())
            throw std::runtime_error("microphone_changed_during_prepare");
        if (backend_.registerIO(capture_, &io_) || !io_) throw std::runtime_error("microphone_register_failed");
        capture_->enabled = true; startAttempted_ = true;
        if (backend_.start(io_)) throw std::runtime_error("microphone_start_failed");
        if (capture_->fault.load()) throw std::runtime_error("microphone_changed_during_start");
        return true;
    } catch (const std::exception &error) {
        const std::string reason = error.what();
        const bool cleaned = stop();
        error_ = reason + (cleaned ? "" : "; cleanup_pending:" + error_);
        return false;
    }
}
bool MicrophoneSession::stop() {
    if (capture_) capture_->enabled = false;
    if (startAttempted_) {
        if (backend_.stop(io_)) { error_ = "microphone_stop_failed"; return false; }
        startAttempted_ = false;
    }
    if (io_) {
        if (backend_.unregisterIO(io_)) { error_ = "microphone_unregister_failed"; return false; }
        io_ = nullptr;
    }
    if (watched_) {
        if (backend_.unwatch()) { error_ = "microphone_unwatch_failed"; return false; }
        watched_ = false;
    }
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (capture_ && capture_->callbacks.load()) {
        if (std::chrono::steady_clock::now() >= deadline) { error_ = "microphone_drain_timeout"; return false; }
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    return true;
}
namespace {
int directoryFD(const std::string &path) {
    if (path.empty() || path.front() != '/' || path.back() == '/' || path.find('\0') != std::string::npos) return -1;
    int fd = open(path.c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    struct stat info{};
    if (fd < 0) return -1;
    if (fstat(fd, &info) || info.st_uid != getuid() || (info.st_mode & 0777) != 0700) { close(fd); return -1; }
    return fd;
}
bool writeAll(int fd, const void *data, size_t count) {
    auto bytes = static_cast<const unsigned char *>(data);
    while (count) {
        const ssize_t done = write(fd, bytes, count);
        if (done < 0 && errno == EINTR) continue;
        if (done <= 0) return false;
        bytes += done; count -= size_t(done);
    }
    return true;
}
bool monoWav(int directory, const char *name, const float *samples, uint32_t count,
             const std::atomic<bool> &cancel, std::string &error) {
    if (cancel.load()) return false;
    int fd = openat(directory, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (fd < 0) { error = "exclusive_wav_create_failed"; return false; }
    std::array<unsigned char,44> header{};
    bool okay = fchmod(fd, 0600) == 0 && writeAll(fd, header.data(), header.size());
    std::array<unsigned char,960> pcm{};
    for (uint32_t first = 0; okay && first < count; first += 480) {
        if (cancel.load()) { okay = false; break; }
        const auto frames = std::min<uint32_t>(480, count - first);
        for (uint32_t i = 0; i < frames; ++i) {
            if (!std::isfinite(samples[first+i])) { okay = false; error = "nonfinite_processed_sample"; break; }
            const auto value = std::clamp<int32_t>(int32_t(std::lround(double(std::clamp(samples[first+i], -1.f, 1.f)) * 32768)), -32768, 32767);
            uint16_t bits = uint16_t(int16_t(value)); pcm[i*2] = bits & 255; pcm[i*2+1] = bits >> 8;
        }
        if (okay) okay = writeAll(fd, pcm.data(), frames * 2);
    }
    auto put = [&](size_t at, uint32_t value, size_t length) { for (size_t i=0;i<length;++i) header[at+i]=(value>>(i*8))&255; };
    if (okay && !cancel.load()) {
        std::memcpy(header.data(), "RIFF",4); put(4,36+count*2,4); std::memcpy(header.data()+8,"WAVEfmt ",8);
        put(16,16,4);put(20,1,2);put(22,1,2);put(24,48000,4);put(28,96000,4);put(32,2,2);put(34,16,2);
        std::memcpy(header.data()+36,"data",4);put(40,count*2,4);
        okay = lseek(fd,0,SEEK_SET)>=0 && writeAll(fd,header.data(),header.size()) && fsync(fd)==0;
    } else okay = false;
    if (close(fd)) okay = false;
    if (!okay && error.empty() && !cancel.load()) error = "wav_write_or_finalize_failed";
    return okay;
}
}
bool validateMicrophoneTestDirectory(const std::string &path, std::string &error) {
    int fd = directoryFD(path);
    if (fd < 0) { error = "test_directory_must_be_absolute_owned_private_0700"; return false; }
    bool okay = true;
    for (const char *name : {"original.wav", "processed.wav"}) {
        struct stat info{};
        if (fstatat(fd,name,&info,AT_SYMLINK_NOFOLLOW)==0 || errno != ENOENT) okay = false;
    }
    close(fd);
    if (!okay) error = "test_wav_path_already_exists";
    return okay;
}
MicrophoneTestResult processMicrophoneTest(const std::shared_ptr<MicrophoneCapture> &capture,
                                         const std::string &directory, const std::atomic<bool> &cancel) {
    MicrophoneTestResult result; result.frames = capture->frames.load(); result.status = "failed";
    if (cancel.load()) { result.status = "cancelled"; return result; }
    if (capture->enabled.load() || capture->callbacks.load() || capture->fault.load()) {
        result.error = "capture_not_safely_stopped_or_faulted"; return result;
    }
    if (result.frames < microphoneTestMinimum || result.frames > microphoneTestMaximum) {
        result.error = "minimum_duration"; return result;
    }
    int fd = directoryFD(directory);
    if (fd < 0) { result.error = "test_directory_must_be_absolute_owned_private_0700"; return result; }
    try {
        StreamingNoise engine;
        std::vector<float> delayed(size_t(result.frames) + StreamingNoise::buffering_frames);
        for (uint32_t first=0;first<result.frames;first+=480) {
            if (cancel.load()) break;
            const uint32_t count = std::min<uint32_t>(480,result.frames-first);
            engine.process(capture->samples.data()+first, delayed.data()+first, count);
        }
        std::array<float,480> zeros{};
        if (!cancel.load()) engine.process(zeros.data(), delayed.data()+result.frames, zeros.size());
        if (!cancel.load() && monoWav(fd,"original.wav",capture->samples.data(),result.frames,cancel,result.error) &&
            monoWav(fd,"processed.wav",delayed.data()+StreamingNoise::buffering_frames,result.frames,cancel,result.error)) {
            result.status = "completed"; result.originalPath = directory+"/original.wav"; result.processedPath = directory+"/processed.wav";
        } else if (cancel.load()) result.status = "cancelled";
    } catch (const std::exception &error) { result.error = error.what(); }
    close(fd);
    return result;
}
std::string microphoneTestResultJSON(const std::string &operation, const MicrophoneTestResult &result) {
    std::string json = "{\"event\":\"test_result\",\"operationID\":"+jsonString(operation)+",\"status\":"+jsonString(result.status)+
        ",\"frames\":"+std::to_string(result.frames)+",\"sampleRate\":48000,\"channels\":1,\"engine\":\"RNNoise\",\"adapterBufferingFrames\":480,\"adapterDelayAligned\":true";
    if (!result.error.empty()) json += ",\"error\":"+jsonString(result.error);
    if (result.status=="completed") json += ",\"originalPath\":"+jsonString(result.originalPath)+",\"processedPath\":"+jsonString(result.processedPath);
    return json+"}";
}
} // namespace labvoice
