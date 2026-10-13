#pragma once
#include "controls.hpp"
#include "recording.hpp"
#include <CoreAudio/CoreAudio.h>
#include <array>
#include <atomic>
#include <memory>
#include <string>
#include <vector>

namespace labvoice {
constexpr UInt32 callbackLimit = 4096;
constexpr UInt32 bufferLimit = 16;
struct Selection {
    std::string inputUID, outputUID;
};
struct Layout {
    std::vector<UInt32> inputBuffers, outputBuffers;
    UInt32 microphoneChannel = 0, monitorLeft = 0, monitorRight = 0;
    UInt32 feedChannel = 0, hardwareLeft = 0, hardwareRight = 0;
    bool operator==(const Layout &) const = default;
};
using Processor = bool (*)(void *, const float *, const float *, float *, float *, UInt32) noexcept;
struct Context {
    Layout layout;
    Processor processor = nullptr;
    void *processorData = nullptr;
    std::shared_ptr<void> processorOwner;
    AtomicControls controls;
    const std::shared_ptr<Recording> recording = std::make_shared<Recording>();
    std::atomic<bool> enabled{false}, changed{false};
    std::atomic<UInt32> callbacks{0};
    std::array<float, callbackLimit> microphone{}, processedMicrophone{};
    std::array<float, callbackLimit * 2> monitor{}, processedMonitor{};
    // One aggregate IOProc is serialized by its backend. Try-once rejects unexpected reentry.
    std::atomic_flag rendering = ATOMIC_FLAG_INIT;
    explicit Context(Layout value, Processor process = nullptr, void *data = nullptr,
                     std::shared_ptr<void> owner = {});
    static OSStatus io(AudioObjectID, const AudioTimeStamp *, const AudioBufferList *,
                       const AudioTimeStamp *, AudioBufferList *, const AudioTimeStamp *,
                       void *) noexcept;
    static OSStatus change(AudioObjectID, UInt32, const AudioObjectPropertyAddress *,
                           void *) noexcept;
};
struct Watch {
    AudioObjectID device;
    AudioObjectPropertyAddress address;
};
class Backend {
  public:
    virtual ~Backend() = default;
    virtual OSStatus create(const Selection &, AudioObjectID *) = 0;
    virtual Layout inspect(AudioObjectID, const Selection &) = 0;
    virtual std::vector<Watch> watches(AudioObjectID, const Selection &) = 0;
    virtual OSStatus addWatch(const Watch &, const std::shared_ptr<Context> &) = 0;
    virtual OSStatus removeWatch(const Watch &, Context *) = 0;
    virtual OSStatus registerIO(AudioObjectID, const std::shared_ptr<Context> &,
                                AudioDeviceIOProcID *) = 0;
    virtual OSStatus start(AudioObjectID, AudioDeviceIOProcID) = 0;
    virtual OSStatus stop(AudioObjectID, AudioDeviceIOProcID) = 0;
    virtual OSStatus unregisterIO(AudioObjectID, AudioDeviceIOProcID) = 0;
    virtual OSStatus destroy(AudioObjectID) = 0;
};
class CoreAudioBackend final : public Backend {
    struct Impl;
    std::unique_ptr<Impl> impl_;

  public:
    CoreAudioBackend();
    ~CoreAudioBackend() override;
    OSStatus create(const Selection &, AudioObjectID *) override;
    Layout inspect(AudioObjectID, const Selection &) override;
    std::vector<Watch> watches(AudioObjectID, const Selection &) override;
    OSStatus addWatch(const Watch &, const std::shared_ptr<Context> &) override;
    OSStatus removeWatch(const Watch &, Context *) override;
    OSStatus registerIO(AudioObjectID, const std::shared_ptr<Context> &,
                        AudioDeviceIOProcID *) override;
    OSStatus start(AudioObjectID, AudioDeviceIOProcID) override;
    OSStatus stop(AudioObjectID, AudioDeviceIOProcID) override;
    OSStatus unregisterIO(AudioObjectID, AudioDeviceIOProcID) override;
    OSStatus destroy(AudioObjectID) override;
};
// All Session methods run on one owning control thread. Backend outlives Session.
// Only the explicit --route CLI path invokes this class. start creates an aggregate and starts
// audio.
class Session {
    Backend &backend_;
    AudioObjectID aggregate_ = kAudioObjectUnknown;
    AudioDeviceIOProcID io_ = nullptr;
    bool startAttempted_ = false;
    std::shared_ptr<Context> context_;
    std::vector<Watch> watches_;
    std::string error_;

  public:
    explicit Session(Backend &backend) : backend_(backend) {}
    ~Session();
    Session(const Session &) = delete;
    Session &operator=(const Session &) = delete;
    bool start(const Selection &, Processor = nullptr, void * = nullptr, std::shared_ptr<void> = {},
               ControlSnapshot = {});
    bool publishControls(const ControlSnapshot &) noexcept;
    std::shared_ptr<Recording> recordingOwner() const { return context_ ? context_->recording : nullptr; }
    Recording *recording() noexcept { return context_ ? context_->recording.get() : nullptr; }
    bool stop() noexcept;
    bool service() noexcept; // Stop a dirty route on the control thread, no automatic restart.
    const std::string &error() const { return error_; }
    bool running() const {
        return context_ && context_->enabled.load() && !context_->changed.load();
    }
};
} // namespace labvoice
