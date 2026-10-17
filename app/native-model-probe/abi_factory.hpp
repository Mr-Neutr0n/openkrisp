#pragma once

#include "abi_result.hpp"
#include "abi_supplier.hpp"
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace native_model_probe {

// Digest-specific consumer declarations, not recovered public SDK headers.
struct Descriptor {
    std::int32_t durationMilliseconds;
    std::int32_t samplingRate;
};
struct Configuration {
    std::uint32_t samplingRate;
    std::wstring modelPath;
    const void* modelData;
    std::size_t modelDataLength;
    std::uint8_t unknownFlag;
};

// Callback method precedes both destructor slots in the target ABI.
struct Supplier {
    virtual PerFrameValue supply() const = 0;
    virtual ~Supplier() = default;
};
struct Handler {
    virtual void handle(NCResultValue&) = 0;
    virtual ~Handler() = default;
};
// Processor destructor slots precede its methods. Never instantiate this view
// or construct a new owning control block around a vendor pointer.
struct ProcessorView {
    virtual ~ProcessorView() = default;
    virtual void flush() = 0;
    virtual void finalize() = 0;
    virtual void process(const std::vector<float>&) = 0;
    virtual void updateStreamDescriptor(const Descriptor&) = 0;
};
using FactoryABI = std::shared_ptr<ProcessorView> (*)(
    const void*, const Descriptor&, const Configuration&,
    std::shared_ptr<Supplier>, std::shared_ptr<Handler>);

static_assert(sizeof(Descriptor) == 8);
static_assert(offsetof(Configuration, samplingRate) == 0);
static_assert(offsetof(Configuration, modelPath) == 8);
static_assert(offsetof(Configuration, modelData) == 32);
static_assert(offsetof(Configuration, modelDataLength) == 40);
static_assert(offsetof(Configuration, unknownFlag) == 48);
static_assert(sizeof(Configuration) == 56 && alignof(Configuration) == 8);
static_assert(sizeof(std::shared_ptr<ProcessorView>) == 16);

} // namespace native_model_probe
