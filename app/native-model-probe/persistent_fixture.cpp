#include "abi_factory.hpp"
#include <cstdio>
#include <limits>
#include <stdexcept>
#include <utility>

using namespace native_model_probe;
struct SyntheticSdkConfig;
namespace {
std::string imageEventPath;
void appendEvent(const std::string& path, char event) noexcept {
    if (auto* stream = std::fopen(path.c_str(), "ab")) {
        std::fputc(event, stream);
        std::fclose(stream);
    }
}
// This destructor and exception vtable live in the image being unloaded.
class FixtureException final : public std::exception {
public:
    explicit FixtureException(std::string eventPath) : eventPath_(std::move(eventPath)) {}
    ~FixtureException() override { appendEvent(eventPath_, 'E'); }
    const char* what() const noexcept override { return "persistent fixture vendor failure"; }
private:
    std::string eventPath_;
};
struct UnloadRecorder {
    ~UnloadRecorder() { if (!imageEventPath.empty()) appendEvent(imageEventPath, 'U'); }
} unloadRecorder;
class PersistentProcessor final : public ProcessorView {
public:
    PersistentProcessor(const Descriptor& descriptor, const Configuration& configuration,
                        std::shared_ptr<Supplier> supplier, std::shared_ptr<Handler> handler)
        : descriptor_(descriptor), configuration_(configuration), supplier_(std::move(supplier)),
          handler_(std::move(handler)), eventPath_(configuration.modelPath.begin(), configuration.modelPath.end()) {
        record('C');
    }
    ~PersistentProcessor() override {
        if (callbackOnDestruction_) {
            NCResultValue result;
            handler_->handle(result);
        }
        record('D');
    }
    void flush() override {}
    void finalize() override {}
    void updateStreamDescriptor(const Descriptor&) override {}
    void process(const std::vector<float>& input) override {
        // These references must remain valid throughout a persistent session.
        if (descriptor_.durationMilliseconds != 10 || descriptor_.samplingRate != 48000 ||
            configuration_.samplingRate != 48000 || input.size() != 480)
            throw std::runtime_error("persistent fixture lifetime contract");
        const auto supplied = supplier_->supply();
        if (supplied.bypassFilteredSpectrum || supplied.skipStatistics || supplied.backgroundSpeakerFix ||
            supplied.statisticsUpdateFlag != 1 || supplied.suppressionLevel != 37.0f)
            throw std::runtime_error("persistent fixture supplier contract");
        if (input[0] == -9001.0f) throw FixtureException(eventPath_);
        if (input[0] == -9006.0f) callbackOnDestruction_ = true;
        ++frames_;
        if (input[0] == -9003.0f) return;
        NCResultValue result;
        for (float sample : input) result.samples.push_back(sample + static_cast<float>(frames_));
        if (input[0] == -9002.0f) result.samples.pop_back();
        if (input[0] == -9005.0f) result.samples[1] = std::numeric_limits<float>::quiet_NaN();
        handler_->handle(result);
        if (input[0] == -9004.0f) handler_->handle(result);
        // Destroy and overwrite callback storage before returning to the caller.
        result.samples.assign(480, -12345.0f);
    }
private:
    void record(char event) noexcept {
        appendEvent(eventPath_, event);
    }
    const Descriptor& descriptor_;
    const Configuration& configuration_;
    std::shared_ptr<Supplier> supplier_;
    std::shared_ptr<Handler> handler_;
    std::string eventPath_;
    unsigned frames_ = 0;
    bool callbackOnDestruction_ = false;
};
}

// Mach-O prepends its own underscore to this exact dlsym export name.
std::shared_ptr<ProcessorView> persistent_factory(
    const SyntheticSdkConfig&, const Descriptor&, const Configuration&,
    std::shared_ptr<Supplier>, std::shared_ptr<Handler>) __asm__("__ZN5KRISP20createFrameProcessorIfNS_5Audio16StreamDescriptorENS1_17NoiseCancellation13ConfigurationENS3_29PerFrameConfigurationSupplierENS3_22ResultHandlerWithStatsIfEEEENSt3__110shared_ptrINS_34FrameProcessorWithStreamDescriptorIT_T0_EEEERKNS_9SdkConfigERKSC_RKT1_NS9_IT2_EENS9_IT3_EE");
std::shared_ptr<ProcessorView> persistent_factory(
    const SyntheticSdkConfig&, const Descriptor& descriptor, const Configuration& configuration,
    std::shared_ptr<Supplier> supplier, std::shared_ptr<Handler> handler) {
    imageEventPath.assign(configuration.modelPath.begin(), configuration.modelPath.end());
    if (imageEventPath.find("construct-failure") != std::string::npos)
        throw FixtureException(imageEventPath);
    if (configuration.modelData || configuration.modelDataLength || configuration.unknownFlag || !supplier || !handler)
        throw std::invalid_argument("persistent fixture configuration contract");
    return std::make_shared<PersistentProcessor>(descriptor, configuration, std::move(supplier), std::move(handler));
}
