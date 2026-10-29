#include "selected_app_capture_cli.hpp"
#include <atomic>
#include <chrono>
#include <thread>
using namespace labvoice;
namespace {
struct FixtureDriver : CallCaptureDriver {
    Sink sink = nullptr; void* context = nullptr;
    std::atomic<bool> done{false}; std::thread producer;
    bool delayed = false;
    ~FixtureDriver() override { std::string error; stop(error); }
    bool createTap(const CallCaptureTarget&, AudioStreamBasicDescription& f, std::string&) override {
        // Own simulated permission wait; no native source is constructed.
        if (delayed) std::this_thread::sleep_for(std::chrono::milliseconds(250));
        f = {}; f.mSampleRate = 48000; f.mFormatID = kAudioFormatLinearPCM;
        f.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
        f.mChannelsPerFrame = 2; f.mBitsPerChannel = 32;
        f.mFramesPerPacket = 1; f.mBytesPerFrame = f.mBytesPerPacket = 8; return true;
    }
    bool createAggregate(std::string&) override { return true; }
    bool validateFormat(const AudioStreamBasicDescription&, std::string&) override { return true; }
    bool registerIO(Sink value, void* pointer, std::string&) override { sink = value; context = pointer; return true; }
    bool start(std::string&) override {
        producer = std::thread([this] {
            float samples[960]; for (auto& sample : samples) sample = 0.125f;
            AudioBufferList buffers{1, {{2, sizeof samples, samples}}};
            AudioTimeStamp time{}; time.mFlags = kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid;
            time.mHostTime = 1;
            while (!done.load()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(2));
                sink(context, &buffers, &time); time.mSampleTime += 480; time.mHostTime += 100;
            }
        }); return true;
    }
    bool stop(std::string&) override { done.store(true); if (producer.joinable()) producer.join(); return true; }
    bool unregisterIO(std::string&) override { return true; }
    bool destroyAggregate(std::string&) override { return true; }
    bool destroyTap(std::string&) override { return true; }
};
AudioProcessSnapshot fixture() {
    AudioProcessUsage row{}; row.objectID = 42; row.actualPID = 101; row.responsiblePID = 100;
    row.appID = "own.fixture"; row.output.running = true; row.output.devices = std::vector<AudioUsedDevice>{{7, "own.speaker"}};
    return {"available", {row}, {}};
}
}
int main(int argc, char** argv) {
    return runSelectedAppCapture(argc, argv, [] {
        auto driver = std::make_unique<FixtureDriver>(); driver->delayed = std::getenv("OPENKRISP_FIXTURE_DELAY") != nullptr;
        return std::make_unique<CallCaptureSession>(fixture, std::move(driver), makeCallCaptureWavWriter());
    });
}
