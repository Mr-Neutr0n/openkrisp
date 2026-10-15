#pragma once

#include <cstddef>
#include <limits>
#include <type_traits>
#include <vector>

namespace native_model_probe {

// Current ARM64 libc++ layout mirror, not an SDK-owned value constructor.
// ev_09d0d4c600e38a28147808f7043ecaf02c0a516eb13c62e2c657967364b86e24
// Prefix fields remain opaque. A callback must not mutate the borrowed value.
struct NCResultValue {
    std::byte prefix[0x28]{};
    std::vector<float> samples;
};

static_assert(sizeof(void*) == 8);
static_assert(sizeof(float) == 4 && std::numeric_limits<float>::is_iec559);
static_assert(sizeof(std::vector<float>) == 0x18);
static_assert(alignof(std::vector<float>) == 8);
static_assert(std::is_standard_layout_v<NCResultValue>);
static_assert(offsetof(NCResultValue, samples) == 0x28);
static_assert(sizeof(NCResultValue) == 0x40);
static_assert(alignof(NCResultValue) == 8);

} // namespace native_model_probe
