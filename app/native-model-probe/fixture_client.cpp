#include "abi_factory.hpp"
#include "result_collector.hpp"
#include <dlfcn.h>
#include <cmath>
#include <iostream>
#include <stdexcept>

using namespace native_model_probe;
namespace {
void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}
struct Counts { unsigned supplied = 0, handled = 0, supplierDestroyed = 0, handlerDestroyed = 0; };
class TestSupplier final : public Supplier {
public:
    explicit TestSupplier(Counts& counts) : counts_(counts) {}
    PerFrameValue supply() const override { ++counts_.supplied; return {0, 0, 0, 1, 37.0f}; }
    ~TestSupplier() override { ++counts_.supplierDestroyed; }
private:
    Counts& counts_;
};
class TestHandler final : public Handler {
public:
    TestHandler(Counts& counts, ResultCollector& collector) : counts_(counts), collector_(collector) {}
    void handle(NCResultValue& result) override { ++counts_.handled; collector_.accept(result); }
    ~TestHandler() override { ++counts_.handlerDestroyed; }
private:
    Counts& counts_;
    ResultCollector& collector_;
};
}
int main(int argc, char** argv) {
    try {
        require(argc == 2, "provide synthetic dylib path only");
        void* library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
        if (!library) throw std::runtime_error(dlerror());
        auto factory = reinterpret_cast<FactoryABI>(dlsym(library, "synthetic_factory"));
        auto counter = reinterpret_cast<std::uint64_t (*)(unsigned)>(dlsym(library, "synthetic_counter"));
        auto releaseWeak = reinterpret_cast<void (*)()>(dlsym(library, "synthetic_release_weak"));
        require(factory && counter && releaseWeak, "synthetic exports missing");
        Counts counts;
        ResultCollector collector(480, 960);
        Descriptor descriptor{10, 48000};
        Configuration configuration{48000, L"synthetic-only", nullptr, 0, 0};
        alignas(16) static const std::byte token[16]{};
        auto supplier = std::make_shared<TestSupplier>(counts);
        auto handler = std::make_shared<TestHandler>(counts, collector);
        std::weak_ptr<Supplier> supplierWeak = supplier;
        std::weak_ptr<Handler> handlerWeak = handler;
        auto processor = factory(token, descriptor, configuration, supplier, handler);
        require(processor && counter(0) == 1 && counter(1) == 0, "shared return ABI");
        supplier.reset(); handler.reset();
        require(!supplierWeak.expired() && !handlerWeak.expired(), "processor retains callbacks");
        std::vector<float> input(480);
        for (std::size_t i = 0; i < input.size(); ++i) input[i] = static_cast<float>(i) / 1920.0f;
        processor->flush(); processor->finalize(); processor->updateStreamDescriptor(descriptor);
        processor->process(input);
        auto retainedProcessor = processor;
        processor.reset();
        require(counter(1) == 0, "shared ownership retained processor");
        retainedProcessor->process(input);
        require(counts.supplied == 2 && counts.handled == 2, "virtual callback dispatch");
        require(collector.error() == ResultError::none && collector.samples().size() == 960,
                "borrowed result copied");
        for (std::size_t i = 0; i < 960; ++i)
            require(std::abs(collector.samples()[i] - input[i % 480] * 0.37f) < 1e-7f,
                    "supplier value/result layout");
        retainedProcessor.reset();
        require(counter(1) == 1 && counter(2) == 1, "original processor destruction");
        require(supplierWeak.expired() && handlerWeak.expired() &&
                counts.supplierDestroyed == 1 && counts.handlerDestroyed == 1,
                "callback destruction after processor reset");
        supplierWeak.reset(); handlerWeak.reset();
        releaseWeak(); // Destroy library's last control-block reference before unload.
        require(dlclose(library) == 0, "synthetic library unload");
        std::cout << "cross-library synthetic factory ABI passed: 2 callbacks, 960 samples, exact lifetime counts\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
