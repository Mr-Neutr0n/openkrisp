#pragma once
#include "noise_engine.hpp"

namespace labvoice {
// Converts any callback partition to 480-sample inference blocks. Adds exactly
// 480 samples of buffering in addition to RNNoise's own algorithmic delay.
// Construct a fresh instance on each stream start. Never share across threads.
class StreamingNoise final {
public:
    static constexpr std::size_t buffering_frames = NoiseEngine::frame_size;
    void process(const float* input, float* output, std::size_t count) noexcept {
        for (std::size_t i = 0; i < count; ++i) {
            const float sample = input[i];
            output[i] = ready_[position_];
            pending_[position_] = sample;
            if (++position_ == NoiseEngine::frame_size) {
                engine_.process(pending_.data(), ready_.data());
                position_ = 0;
            }
        }
    }
    static void callback(void* context, const float* input, float* output, std::size_t count) noexcept {
        static_cast<StreamingNoise*>(context)->process(input, output, count);
    }
private:
    NoiseEngine engine_;
    std::array<float, NoiseEngine::frame_size> pending_{};
    std::array<float, NoiseEngine::frame_size> ready_{};
    std::size_t position_{};
};
}
