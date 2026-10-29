#pragma once
#include "audio_process_usage.hpp"
#include "call_capture_timeline.hpp"
#include <CoreAudio/CoreAudio.h>
#include <memory>
#include <string>
#include <vector>

namespace labvoice {
struct CallCaptureProcess { AudioObjectID objectID = 0; int actualPID = 0; };
struct CallCaptureTarget { int responsiblePID = 0; std::string appID; std::vector<CallCaptureProcess> processes; };
struct CallCaptureMicrophoneSpec {
    std::string uid;
    AudioObjectID objectID=0;
    std::vector<UInt32> channels;
    std::vector<AudioObjectID> streams;
    AudioStreamBasicDescription format{}; // Selected channel zero, mono 48 kHz.
};
struct CallCaptureResult {
    bool completed = false, cleanupVerified = true;
    std::string path, error;
    uint64_t frames = 0, sourceFrames = 0, firstHostTime = 0, lastHostTime = 0;
    double firstSampleTime = 0, lastSampleTime = 0;
    AudioStreamBasicDescription sourceFormat{};
    CallCaptureMicrophoneSpec microphone;
    CallCaptureTimelineStats timeline;
    std::vector<std::string> cleanup;
};
bool validateCallCaptureTarget(const CallCaptureTarget&, const AudioProcessSnapshot&, std::string& error);
bool supportedCallCaptureFormat(const AudioStreamBasicDescription&) noexcept;
// RIFF uses a 32-bit container size. Reserve header/chunk space and one maximum
// converter output block. This is a file-format capacity, not a recording quota.
inline constexpr uint64_t callCaptureWavMaximumBytes = uint64_t(UINT32_MAX) + 8;
inline constexpr uint64_t callCaptureWavMaximumFrames = (uint64_t(UINT32_MAX) - 65536) / 4 - 32768;
bool callCaptureSourceFramesFitWav(uint64_t sourceFrames, double sourceRate) noexcept;
// Injected interfaces permit lifecycle and callback tests without creating a tap.
class CallCaptureDriver {
public:
    using Sink = void (*)(void*, const AudioBufferList*, const AudioTimeStamp*) noexcept;
    virtual ~CallCaptureDriver() = default;
    virtual bool createTap(const CallCaptureTarget&, AudioStreamBasicDescription&, std::string&) = 0;
    virtual bool createAggregate(std::string&) = 0;
    virtual bool registerIO(Sink, void*, std::string&) = 0;
    virtual bool start(std::string&) = 0;
    virtual bool validateFormat(const AudioStreamBasicDescription&, std::string&) = 0;
    virtual bool stop(std::string&) = 0;
    virtual bool unregisterIO(std::string&) = 0;
    virtual bool destroyAggregate(std::string&) = 0;
    virtual bool destroyTap(std::string&) = 0;
};
class CallCaptureMicrophone {
public:
    virtual ~CallCaptureMicrophone()=default;
    virtual bool prepare(CallCaptureMicrophoneSpec&,std::string&)=0;
    virtual bool registerIO(CallCaptureDriver::Sink,void*,std::string&)=0;
    virtual bool start(std::string&)=0;
    virtual bool validate(const CallCaptureMicrophoneSpec&,std::string&)=0;
    virtual bool stop(std::string&)=0;
    virtual bool unregisterIO(std::string&)=0;
};
class CallCaptureWriter {
public:
    virtual ~CallCaptureWriter() = default;
    virtual bool open(const std::string&, const AudioStreamBasicDescription&, std::string&) = 0;
    virtual bool write(const float* interleavedStereo, uint32_t frames, std::string&) = 0;
    virtual bool close(uint64_t& outputFrames, std::string&) = 0;
};
class CallCaptureSession {
public:
    using Observe = std::function<AudioProcessSnapshot()>;
    CallCaptureSession(Observe, std::unique_ptr<CallCaptureDriver>, std::unique_ptr<CallCaptureWriter>,
                       std::unique_ptr<CallCaptureMicrophone> = {}, double hostTicksPerSecond = 0);
    ~CallCaptureSession();
    CallCaptureSession(const CallCaptureSession&) = delete;
    // cancelled may run on the audio callback: it must be noexcept, lock-free,
    // allocation-free and retain its token by value through uncertain cleanup.
    bool start(const CallCaptureTarget&, const std::string& outputPath, std::string& error,
               std::function<bool()> cancelled = {});
    bool healthy() const noexcept;
    // Control-thread liveness check. Failure disables intake permanently.
    bool validateCurrentTarget(std::string& error);
    AudioStreamBasicDescription sourceFormat() const;
    CallCaptureMicrophoneSpec microphoneSpec() const;
    CallCaptureResult stop();
private:
    struct State;
    std::shared_ptr<State> state_;
};
// Construction has no hardware side effects. Only start() creates native objects.
std::unique_ptr<CallCaptureSession> makeNativeCallCaptureSession();
std::unique_ptr<CallCaptureSession> makeNativeCallCaptureSession(const std::string& microphoneUID);
std::unique_ptr<CallCaptureMicrophone> makeNativeCallCaptureMicrophone(const std::string& uid);
bool silenceUnexpectedCallCaptureOutputs(AudioBufferList*) noexcept;
// File-only conversion factory also permits synthetic writer verification.
std::unique_ptr<CallCaptureWriter> makeCallCaptureWavWriter();
}
