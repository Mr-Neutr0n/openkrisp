#pragma once

#include <cstddef>
#include <cstdint>
#include <type_traits>

namespace native_model_probe {

// Meaningful bytes recovered from ordinary NC consumers. Names are descriptive,
// not vendor declarations. Only canonical 0/1 flags and finite 0..100 levels.
struct PerFrameValue {
    std::uint8_t bypassFilteredSpectrum;
    std::uint8_t skipStatistics;
    std::uint8_t backgroundSpeakerFix;
    std::uint8_t statisticsUpdateFlag;
    float suppressionLevel;
};
static_assert(std::is_trivially_copyable_v<PerFrameValue>);
static_assert(sizeof(float) == 4);
static_assert(sizeof(PerFrameValue) == 8);
static_assert(alignof(PerFrameValue) == 4);
static_assert(offsetof(PerFrameValue, suppressionLevel) == 4);

} // namespace native_model_probe
