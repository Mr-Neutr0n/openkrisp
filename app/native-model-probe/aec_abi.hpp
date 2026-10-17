#pragma once
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <span>
#include <stdexcept>

namespace aec_probe {
// Digest-specific ARM64 consumer view, not a recovered SDK header.
struct StreamConfig {
    std::int32_t rate;
    std::uint32_t reserved = 0;
    std::uint64_t channels;
    std::uint64_t frames;
};
static_assert(sizeof(void*) == 8);
static_assert(sizeof(StreamConfig) == 24 && alignof(StreamConfig) == 8);
static_assert(offsetof(StreamConfig, rate) == 0);
static_assert(offsetof(StreamConfig, channels) == 8);
static_assert(offsetof(StreamConfig, frames) == 16);

struct View {
    virtual ~View() = default; // +0x00 / +0x08: matching image deletion
    virtual int initialize() = 0; // +0x10
    virtual void unusedConfig() = 0;
    virtual void unusedMute() = 0;
    virtual void unusedRuntimeSetting() = 0;
    virtual void unusedShortProcess() = 0;
    virtual void unusedPlanarProcess() = 0;
    virtual int process(const float*, const StreamConfig&, const StreamConfig&, float*) = 0; // +0x40
    virtual void unusedShortReverse() = 0;
    virtual void unusedPlanarReverse() = 0;
    virtual int reverse(const float*, const StreamConfig&) = 0; // +0x58
    virtual int delay(int) = 0; // +0x60
};
using Factory = View* (*)();

// Bounded fixture admission only. This does not assert vendor rate support.
inline bool valid(const StreamConfig& config, std::span<const float> samples) noexcept {
    if ((config.rate != 16000 && config.rate != 32000 && config.rate != 48000) ||
        config.reserved || config.channels < 1 || config.channels > 2 ||
        config.frames != static_cast<std::uint64_t>(config.rate / 100) ||
        samples.size() != config.frames * config.channels) return false;
    for (float sample : samples) if (!std::isfinite(sample)) return false;
    return true;
}
inline int reverse(View& view, const StreamConfig& config, std::span<const float> input) {
    if (!valid(config, input)) throw std::invalid_argument("AEC reference frame");
    return view.reverse(input.data(), config);
}
inline int process(View& view, const StreamConfig& config, std::span<const float> input,
                   std::span<float> output) {
    if (!valid(config, input) || output.size() != input.size())
        throw std::invalid_argument("AEC forward frame");
    return view.process(input.data(), config, config, output.data());
}
} // namespace aec_probe
