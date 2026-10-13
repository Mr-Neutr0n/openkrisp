#pragma once
#include "../noise-engine/streaming_noise.hpp"
#include "routing.hpp"

namespace labvoice {
// Construct before start. Each channel owns fresh state. No concurrent use.
class NoiseAdapter {
    StreamingNoise microphone_, left_, right_;
    bool microphoneEnabled_, speakerEnabled_;
    std::array<float, callbackLimit> leftInput_{}, rightInput_{}, leftOutput_{}, rightOutput_{};

  public:
    explicit NoiseAdapter(bool microphone, bool speaker)
        : microphoneEnabled_(microphone), speakerEnabled_(speaker) {
    }
    static bool process(void *data, const float *microphone, const float *monitor, float *feed,
                        float *playback, UInt32 count) noexcept {
        auto &self = *static_cast<NoiseAdapter *>(data);
        if (count > callbackLimit)
            return false;
        if (self.microphoneEnabled_)
            self.microphone_.process(microphone, feed, count);
        else
            for (UInt32 i = 0; i < count; ++i)
                feed[i] = microphone[i];
        if (self.speakerEnabled_) {
            for (UInt32 i = 0; i < count; ++i) {
                self.leftInput_[i] = monitor[2 * i];
                self.rightInput_[i] = monitor[2 * i + 1];
            }
            self.left_.process(self.leftInput_.data(), self.leftOutput_.data(), count);
            self.right_.process(self.rightInput_.data(), self.rightOutput_.data(), count);
            for (UInt32 i = 0; i < count; ++i) {
                playback[2 * i] = self.leftOutput_[i];
                playback[2 * i + 1] = self.rightOutput_[i];
            }
        } else
            for (UInt32 i = 0; i < count * 2; ++i)
                playback[i] = monitor[i];
        return true;
    }
};
} // namespace labvoice
