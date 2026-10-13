#pragma once
#include <atomic>
#include <bit>
#include <cmath>
#include <cstdint>

namespace labvoice {
struct PathControl {
    float gain = 1.0f;
    bool muted = false;
    bool operator==(const PathControl &) const = default;
};
struct ControlSnapshot {
    PathControl microphone, speaker;
    bool operator==(const ControlSnapshot &) const = default;
    bool valid() const noexcept {
        return std::isfinite(microphone.gain) && microphone.gain >= 0 && microphone.gain <= 1 &&
               std::isfinite(speaker.gain) && speaker.gain >= 0 && speaker.gain <= 1;
    }
};
class AtomicControls {
    static_assert(std::atomic<uint64_t>::is_always_lock_free);
    // Valid nonnegative Float32 gains never use their sign bit. Use that bit for
    // mute, preserving all gain precision in one atomic two-path snapshot.
    std::atomic<uint64_t> bits_{0x3f8000003f800000ULL};
    static uint32_t encode(PathControl value) noexcept {
        return std::bit_cast<uint32_t>(value.gain == 0 ? 0.0f : value.gain) |
               (value.muted ? 0x80000000U : 0);
    }
    static PathControl decode(uint32_t value) noexcept {
        return {std::bit_cast<float>(value & 0x7fffffffU), bool(value & 0x80000000U)};
    }

  public:
    bool publish(const ControlSnapshot &value) noexcept {
        if (!value.valid())
            return false;
        bits_.store(uint64_t(encode(value.microphone)) | (uint64_t(encode(value.speaker)) << 32),
                    std::memory_order_release);
        return true;
    }
    ControlSnapshot load() const noexcept {
        const auto value = bits_.load(std::memory_order_acquire);
        return {decode(uint32_t(value)), decode(uint32_t(value >> 32))};
    }
};
inline float controlledSample(float value, PathControl control) noexcept {
    // Test mute before multiplication: zero times NaN is still NaN.
    if (control.muted || !std::isfinite(value))
        return 0;
    const float result = value * control.gain;
    return std::isfinite(result) ? result : 0;
}
} // namespace labvoice
