#include "selected_app_capture_cli.hpp"
#include <atomic>
#include <chrono>
#include <cmath>
#include <thread>
using namespace labvoice;
namespace {
constexpr double ticksPerSecond = 1000000000.;
struct FixtureProducer {
    CallCaptureDriver::Sink sink = nullptr; void* context = nullptr;
    std::atomic<bool> done{false}; std::thread producer;
    bool microphone = false;
    ~FixtureProducer() { stop(); }
    void start() {
        producer = std::thread([this] {
            float samples[960]; for (auto& sample : samples) sample = microphone ? 0.375f : 0.125f;
            AudioBufferList buffers{1, {{microphone ? 1U : 2U, microphone ? 1920U : 3840U, samples}}};
            AudioTimeStamp time{}; time.mFlags = kAudioTimeStampSampleTimeValid | kAudioTimeStampHostTimeValid;
            long double host = 1000000000.L + (microphone ? 3000000.L : 0.L);
            uint64_t block = 0;
            while (!done.load()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(5));
                if (done.load()) break;
                time.mHostTime = uint64_t(std::llround(host));
                sink(context, &buffers, &time);
                // Independent, varying clocks on a common host-time scale.
                const double ppm = microphone ? -600 + 200 * std::sin(block * .08) : 900 + 300 * std::sin(block * .035);
                host += 10000000.L / (1 + ppm / 1000000.);
                time.mSampleTime += 480; ++block;
            }
        });
    }
    void stop() { done.store(true); if (producer.joinable()) producer.join(); }
};
AudioStreamBasicDescription format(UInt32 channels) {
    AudioStreamBasicDescription f{}; f.mSampleRate = 48000; f.mFormatID = kAudioFormatLinearPCM;
    f.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    f.mChannelsPerFrame = channels; f.mBitsPerChannel = 32; f.mFramesPerPacket = 1;
    f.mBytesPerFrame = f.mBytesPerPacket = channels * 4; return f;
}
struct FixtureDriver : CallCaptureDriver {
    FixtureProducer source;
    bool delayed = false;
    bool createTap(const CallCaptureTarget&, AudioStreamBasicDescription& f, std::string&) override {
        // Own simulated permission wait; no native source is constructed.
        if (delayed) std::this_thread::sleep_for(std::chrono::milliseconds(250));
        f = format(2); return true;
    }
    bool createAggregate(std::string&) override { return true; }
    bool validateFormat(const AudioStreamBasicDescription&, std::string&) override { return true; }
    bool registerIO(Sink value, void* pointer, std::string&) override { source.sink = value; source.context = pointer; return true; }
    bool start(std::string&) override { source.start(); return true; }
    bool stop(std::string&) override { source.stop(); return true; }
    bool unregisterIO(std::string&) override { return true; }
    bool destroyAggregate(std::string&) override { return true; }
    bool destroyTap(std::string&) override { return true; }
};
struct FixtureMicrophone : CallCaptureMicrophone {
    FixtureProducer source;
    std::string uid;
    explicit FixtureMicrophone(std::string value) : uid(std::move(value)) { source.microphone = true; }
    bool prepare(CallCaptureMicrophoneSpec& spec, std::string&) override {
        spec.uid = uid; spec.objectID = 77; spec.channels = {1}; spec.streams = {78}; spec.format = format(1); return true;
    }
    bool registerIO(CallCaptureDriver::Sink value, void* pointer, std::string&) override { source.sink = value; source.context = pointer; return true; }
    bool start(std::string&) override { source.start(); return true; }
    bool validate(const CallCaptureMicrophoneSpec& spec, std::string&) override { return spec.uid == uid && spec.objectID == 77; }
    bool stop(std::string&) override { source.stop(); return true; }
    bool unregisterIO(std::string&) override { return true; }
};
AudioProcessSnapshot fixture() {
    AudioProcessUsage row{}; row.objectID = 42; row.actualPID = 101; row.responsiblePID = 100;
    row.appID = "own.fixture"; row.output.running = true; row.output.devices = std::vector<AudioUsedDevice>{{7, "own.speaker"}};
    return {"available", {row}, {}};
}
}
int main(int argc, char** argv) {
    return runSelectedAppCapture(argc, argv, [](const SelectedAppCaptureOptions& options) {
        auto driver = std::make_unique<FixtureDriver>(); driver->delayed = std::getenv("OPENKRISP_FIXTURE_DELAY") != nullptr;
        std::unique_ptr<CallCaptureMicrophone> microphone;
        if (!options.microphoneUID.empty()) microphone = std::make_unique<FixtureMicrophone>(options.microphoneUID);
        return std::make_unique<CallCaptureSession>(fixture, std::move(driver), makeCallCaptureWavWriter(), std::move(microphone), ticksPerSecond);
    });
}
