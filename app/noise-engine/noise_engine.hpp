#pragma once
#include <array>
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <mutex>
#include <stdexcept>
#include "rnnoise.h"

namespace labvoice {
// One stream per instance, used by one audio thread. Construct/destroy off the
// callback thread. Only the bundled upstream model is accepted in this engine.
class NoiseEngine final {
public:
    static constexpr std::size_t frame_size = 480;
    static constexpr unsigned sample_rate = 48000;
    NoiseEngine() {
        // Upstream builds shared FFT tables on first process, not on create.
        // Serialize that initialization before any callback can use them.
        static std::once_flag tables;
        std::call_once(tables, [] {
            auto* warm = rnnoise_create(nullptr);
            if (!warm) throw std::bad_alloc();
            std::array<float, frame_size> zero{};
            rnnoise_process_frame(warm, zero.data(), zero.data());
            rnnoise_destroy(warm);
        });
        state_ = rnnoise_create(nullptr);
        if (!state_) throw std::bad_alloc();
    }
    ~NoiseEngine() { rnnoise_destroy(state_); }
    NoiseEngine(const NoiseEngine&) = delete;
    NoiseEngine& operator=(const NoiseEngine&) = delete;
    // Normalized mono float, exactly 10 ms. Input and output may be identical.
    // Invalid input becomes silence. No allocation, locks or I/O on this path.
    float process(const float* input, float* output) noexcept {
        for (std::size_t i = 0; i < frame_size; ++i)
            input_[i] = std::isfinite(input[i]) ? std::clamp(input[i], -1.0f, 1.0f) * 32768.0f : 0.0f;
        const float probability = rnnoise_process_frame(state_, output_.data(), input_.data());
        for (std::size_t i = 0; i < frame_size; ++i)
            output[i] = std::isfinite(output_[i]) ? std::clamp(output_[i] / 32768.0f, -1.0f, 1.0f) : 0.0f;
        return std::isfinite(probability) ? std::clamp(probability, 0.0f, 1.0f) : 0.0f;
    }
private:
    DenoiseState* state_{};
    std::array<float, frame_size> input_{};
    std::array<float, frame_size> output_{};
};
}
