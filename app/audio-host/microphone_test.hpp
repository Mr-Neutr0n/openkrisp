#pragma once
#include <CoreAudio/CoreAudio.h>
#include <atomic>
#include <memory>
#include <string>
#include <vector>

namespace labvoice {
constexpr uint32_t microphoneTestMinimum = 5 * 48000;
constexpr uint32_t microphoneTestMaximum = 60 * 48000;
constexpr uint32_t microphoneTestCallbackLimit = 4096;
inline bool microphoneTestFormatSupported(const AudioStreamBasicDescription &f) noexcept {
    const UInt32 flags=kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked;
    const bool planar=f.mFormatFlags & kAudioFormatFlagIsNonInterleaved;
    return f.mSampleRate==48000 && f.mFormatID==kAudioFormatLinearPCM &&
        (f.mFormatFlags & ~kAudioFormatFlagIsNonInterleaved)==flags && f.mBitsPerChannel==32 &&
        f.mChannelsPerFrame && f.mChannelsPerFrame<=64 && f.mFramesPerPacket==1 &&
        f.mBytesPerFrame==(planar?4:f.mChannelsPerFrame*4) && f.mBytesPerPacket==f.mBytesPerFrame;
}
struct MicrophoneSpec {
    AudioObjectID device = 0;
    std::vector<UInt32> channels;
    std::vector<AudioObjectID> streams;
    bool operator==(const MicrophoneSpec &) const = default;
};
struct MicrophoneCapture {
    const MicrophoneSpec spec;
    std::vector<float> samples;
    std::atomic<bool> enabled{false}, maximumReached{false}, fault{false};
    std::atomic<UInt32> callbacks{0}, frames{0};
    std::atomic_flag rendering = ATOMIC_FLAG_INIT;
    bool clockKnown = false;
    double nextSample = 0;
    explicit MicrophoneCapture(MicrophoneSpec);
    void consume(const AudioBufferList *, const AudioTimeStamp *, AudioBufferList *) noexcept;
};
class MicrophoneBackend {
  public:
    virtual ~MicrophoneBackend() = default;
    virtual MicrophoneSpec inspect(const std::string &) = 0;
    virtual OSStatus watch(const std::shared_ptr<MicrophoneCapture> &) = 0;
    virtual OSStatus unwatch() = 0;
    virtual OSStatus registerIO(const std::shared_ptr<MicrophoneCapture> &, AudioDeviceIOProcID *) = 0;
    virtual OSStatus unregisterIO(AudioDeviceIOProcID) = 0;
    virtual OSStatus start(AudioDeviceIOProcID) = 0;
    virtual OSStatus stop(AudioDeviceIOProcID) = 0;
};
class CoreAudioMicrophoneBackend final : public MicrophoneBackend {
    struct Impl;
    std::unique_ptr<Impl> impl_;
  public:
    CoreAudioMicrophoneBackend();
    ~CoreAudioMicrophoneBackend() override;
    MicrophoneSpec inspect(const std::string &) override;
    OSStatus watch(const std::shared_ptr<MicrophoneCapture> &) override;
    OSStatus unwatch() override;
    OSStatus registerIO(const std::shared_ptr<MicrophoneCapture> &, AudioDeviceIOProcID *) override;
    OSStatus unregisterIO(AudioDeviceIOProcID) override;
    OSStatus start(AudioDeviceIOProcID) override;
    OSStatus stop(AudioDeviceIOProcID) override;
};
class MicrophoneSession {
    MicrophoneBackend &backend_;
    AudioDeviceIOProcID io_ = nullptr;
    bool watched_ = false, startAttempted_ = false;
    std::string error_;
    std::shared_ptr<MicrophoneCapture> capture_;
  public:
    explicit MicrophoneSession(MicrophoneBackend &backend) : backend_(backend) {}
    ~MicrophoneSession();
    bool start(const std::string &);
    bool stop();
    std::shared_ptr<MicrophoneCapture> capture() const { return capture_; }
    const std::string &error() const { return error_; }
};
struct MicrophoneTestResult {
    std::string status, error, originalPath, processedPath;
    uint32_t frames = 0;
};
bool validateMicrophoneTestDirectory(const std::string &, std::string &);
MicrophoneTestResult processMicrophoneTest(const std::shared_ptr<MicrophoneCapture> &,
                                         const std::string &, const std::atomic<bool> &cancel);
std::string microphoneTestResultJSON(const std::string &, const MicrophoneTestResult &);
int runMicrophoneTestWithBackend(MicrophoneBackend &, const std::string &, const std::string &, const std::string &, bool);
int runMicrophoneTest(const std::string &, const std::string &, const std::string &, bool);
} // namespace labvoice
