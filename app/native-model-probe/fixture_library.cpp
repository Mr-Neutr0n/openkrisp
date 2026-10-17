#include "abi_factory.hpp"
#include <stdexcept>
#include <utility>

using namespace native_model_probe;
struct SyntheticSdkConfig; // No object is constructed or accessed.
namespace {
std::uint64_t created = 0;
std::uint64_t destroyed = 0;
std::weak_ptr<ProcessorView> lastProcessor;
class SyntheticProcessor final : public ProcessorView {
public:
    SyntheticProcessor(const Descriptor& descriptor, std::shared_ptr<Supplier> supplier,
                       std::shared_ptr<Handler> handler)
        : descriptor_(descriptor), supplier_(std::move(supplier)), handler_(std::move(handler)) {
        ++created;
    }
    ~SyntheticProcessor() override { ++destroyed; }
    void flush() override {}
    void finalize() override {}
    void updateStreamDescriptor(const Descriptor&) override {}
    void process(const std::vector<float>& input) override {
        if (descriptor_.durationMilliseconds != 10 || descriptor_.samplingRate != 48000 ||
            input.size() != 480) throw std::invalid_argument("fixture frame contract");
        const auto value = supplier_->supply();
        if (value.bypassFilteredSpectrum != 0 || value.skipStatistics != 0 ||
            value.backgroundSpeakerFix != 0 || value.statisticsUpdateFlag != 1 ||
            value.suppressionLevel != 37.0f) throw std::runtime_error("supplier ABI mismatch");
        NCResultValue result;
        result.samples.reserve(input.size());
        for (float sample : input) result.samples.push_back(sample * (value.suppressionLevel / 100.0f));
        handler_->handle(result);
        // Payload/vector die here; client must have copied during callback.
    }
private:
    const Descriptor& descriptor_;
    std::shared_ptr<Supplier> supplier_;
    std::shared_ptr<Handler> handler_;
};
}

// Intentionally differs from the client's lowered first parameter only.
// A separate translation unit and dynamic lookup prevent whole-program folding.
std::shared_ptr<ProcessorView> synthetic_factory(
    const SyntheticSdkConfig&, const Descriptor&, const Configuration&,
    std::shared_ptr<Supplier>, std::shared_ptr<Handler>) __asm__("_synthetic_factory");
std::shared_ptr<ProcessorView> synthetic_factory(
    const SyntheticSdkConfig&, const Descriptor& descriptor, const Configuration& config,
    std::shared_ptr<Supplier> supplier, std::shared_ptr<Handler> handler) {
    if (config.samplingRate != 48000 || config.modelPath != L"synthetic-only" ||
        config.modelData || config.modelDataLength || config.unknownFlag || !supplier || !handler)
        throw std::invalid_argument("fixture configuration contract");
    auto processor = std::make_shared<SyntheticProcessor>(descriptor, std::move(supplier), std::move(handler));
    lastProcessor = processor;
    return processor;
}
extern "C" std::uint64_t synthetic_counter(unsigned index) {
    switch (index) {
        case 0: return created;
        case 1: return destroyed;
        case 2: return lastProcessor.expired() ? 1 : 0;
        default: return UINT64_MAX;
    }
}
extern "C" void synthetic_release_weak() { lastProcessor.reset(); }
