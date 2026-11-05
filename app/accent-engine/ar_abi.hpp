#pragma once

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <type_traits>
#include <vector>

namespace accent_engine {

// Consumer mirrors for ARM64 libc++ and addon SHA256 adde50ff...ae8755.
// These are separate AR types, not NC types or public vendor SDK declarations.
struct Descriptor {
    std::int32_t durationMilliseconds;
    std::int32_t samplingRate;
};
struct Configuration {
    std::uint32_t samplingRate;
    std::wstring modelPath;
    const void* modelData;
    std::size_t modelDataLength;
    std::uint8_t ringtoneEnabled;
    float ringtoneThreshold;
};
struct PerFrameValue {
    std::uint8_t flag0;
    std::uint8_t flag1;
    std::uint8_t streamFlag;
    std::uint8_t reserved;
    float noiseSuppressionLevel;
};
struct FrameInfo {
    std::byte opaquePrefix[0x28]{};
    std::vector<float> samples;
};
struct Supplier {
    virtual PerFrameValue supply() const = 0;
    virtual ~Supplier() = default;
};
struct Handler {
    virtual void handle(const FrameInfo&) = 0;
    virtual ~Handler() = default;
};
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
static_assert(offsetof(Configuration, ringtoneEnabled) == 48);
static_assert(offsetof(Configuration, ringtoneThreshold) == 52);
static_assert(sizeof(Configuration) == 56 && alignof(Configuration) == 8);
static_assert(sizeof(PerFrameValue) == 8 && alignof(PerFrameValue) == 4);
static_assert(offsetof(PerFrameValue, noiseSuppressionLevel) == 4);
static_assert(std::is_trivially_copyable_v<PerFrameValue>);
static_assert(std::is_standard_layout_v<FrameInfo>);
static_assert(offsetof(FrameInfo, samples) == 0x28);
static_assert(sizeof(FrameInfo) == 0x40 && alignof(FrameInfo) == 8);
static_assert(sizeof(std::shared_ptr<ProcessorView>) == 16);

} // namespace accent_engine
