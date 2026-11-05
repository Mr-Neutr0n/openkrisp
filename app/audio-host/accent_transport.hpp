#pragma once
#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <stdexcept>

namespace labvoice::accent {
struct BufferingConfig {
    std::size_t maximumCallbackFrames = 4096;
    std::size_t schedulingBudgetFrames = 2; // Units of 480 samples, not callback blocks.
};
// One serialized callback and one broker. A model-empty reply consumes its
// corresponding time slot as silence. This is host policy, not an SDK callback
// or drain. Scheduling delay excludes the model's waveform delay.
// One serialized callback producer/consumer and one broker consumer/producer.
// Construct before either thread starts. Never reset a live transport.
template<std::size_t Capacity = 32, std::size_t DelayFrames = 12>
class Transport {
  public:
    static constexpr std::size_t frameSamples = 480;
    static constexpr std::size_t delaySamples = DelayFrames * frameSamples;
    static_assert(Capacity > 0 && DelayFrames > 0 && DelayFrames < Capacity);
    static_assert(std::atomic<std::uint64_t>::is_always_lock_free);
    static_assert(std::atomic<unsigned>::is_always_lock_free);
    enum class Fault : unsigned { none, invalid_input, overflow, deadline, sequence,
                                  invalid_output, worker_dead, stopped, worker_failure };
    struct Frame {
        std::uint64_t sequence = 0;
        std::array<float, frameSamples> samples{};
        bool produced = true; // Explicit model-empty reply, distinct from a PCM frame.
    };
  private:
    static std::size_t checkedDelay(BufferingConfig config) {
        if (config.maximumCallbackFrames < 1 || config.maximumCallbackFrames > 4096)
            throw std::invalid_argument("Maximum callback frames must be 1 through 4096");
        // A full model frame can finish just after callback entry. Account for
        // its 479 preceding samples plus an entire maximum callback before
        // requiring that result, so inference never has to run inside exchange.
        const auto baseFrames = (config.maximumCallbackFrames + 958) / frameSamples;
        if (baseFrames >= Capacity || config.schedulingBudgetFrames >= Capacity - baseFrames)
            throw std::invalid_argument("Buffering delay exceeds fixed queue capacity");
        return (baseFrames + config.schedulingBudgetFrames) * frameSamples;
    }
    static BufferingConfig legacyConfig() {
        constexpr std::size_t baseFrames = (4096 + 958) / frameSamples;
        if constexpr (DelayFrames < baseFrames)
            throw std::invalid_argument("Legacy delay cannot cover 4096-sample callbacks");
        return {4096, DelayFrames - baseFrames};
    }
    const BufferingConfig buffering_;
    const std::size_t actualDelay_;
    struct Queue {
        std::array<Frame, Capacity> slots{};
        std::atomic<std::uint64_t> write{0}, read{0};
        bool push(const Frame& frame) noexcept {
            const auto w = write.load(std::memory_order_relaxed);
            if (w - read.load(std::memory_order_acquire) == Capacity) return false;
            slots[w % Capacity] = frame;
            write.store(w + 1, std::memory_order_release);
            return true;
        }
        bool pop(Frame& frame) noexcept {
            const auto r = read.load(std::memory_order_relaxed);
            if (r == write.load(std::memory_order_acquire)) return false;
            frame = slots[r % Capacity];
            read.store(r + 1, std::memory_order_release);
            return true;
        }
    } requests_, results_;
    std::atomic<unsigned> fault_{0};
    Frame input_{}, output_{};
    std::size_t inputOffset_ = 0, outputOffset_ = frameSamples;
    std::uint64_t position_ = 0, nextInput_ = 0, nextOutput_ = 0;
    // Broker-owned counters. Exactly one outstanding request keeps submission
    // ordering explicit without sharing callback-owned counters.
    std::uint64_t brokerNext_ = 0;
    bool brokerOutstanding_ = false;
  public:
    Transport() : Transport(legacyConfig()) {}
    explicit Transport(BufferingConfig config)
        : buffering_(config), actualDelay_(checkedDelay(config)) {}
    // Immutable after construction. Default is 5760 samples. For example,
    // maximum480/budget1 gives1440 samples (30ms at48kHz); 512/budget2 gives2400.
    std::size_t actualDelaySamples() const noexcept { return actualDelay_; }
    std::size_t maximumCallbackFrames() const noexcept { return buffering_.maximumCallbackFrames; }
    const BufferingConfig& bufferingConfig() const noexcept { return buffering_; }
    Fault fault() const noexcept {
        return static_cast<Fault>(fault_.load(std::memory_order_acquire));
    }
    void fail(Fault reason) noexcept {
        if (reason == Fault::none) return;
        unsigned expected = 0;
        fault_.compare_exchange_strong(expected, static_cast<unsigned>(reason),
                                       std::memory_order_release, std::memory_order_relaxed);
    }
    // For a valid destination/count, clears the complete destination first.
    // Failure silences the entire block. Input and output must not overlap.
    // Counts above the declared maximum fail without touching the destination extent.
    // The caller must mute unsupported-size output buffers.
    bool exchange(const float* input, float* output, std::size_t count) noexcept {
        if (!output || count > buffering_.maximumCallbackFrames) { fail(Fault::invalid_input); return false; }
        for (std::size_t i = 0; i < count; ++i) output[i] = 0;
        if (fault() != Fault::none) return false;
        if (!input || position_ > std::numeric_limits<std::uint64_t>::max() - count) {
            fail(Fault::invalid_input); return false;
        }
        for (std::size_t i = 0; i < count; ++i) {
            if (!std::isfinite(input[i])) { fail(Fault::invalid_input); break; }
            input_.samples[inputOffset_++] = input[i];
            if (inputOffset_ == frameSamples) {
                input_.sequence = nextInput_++;
                if (!requests_.push(input_)) { fail(Fault::overflow); break; }
                inputOffset_ = 0;
            }
            if (position_ >= actualDelay_) {
                if (outputOffset_ == frameSamples) {
                    if (!results_.pop(output_)) { fail(Fault::deadline); break; }
                    if (output_.sequence != nextOutput_++) { fail(Fault::sequence); break; }
                    outputOffset_ = 0;
                }
                output[i] = output_.produced ? output_.samples[outputOffset_] : 0.f;
                ++outputOffset_;
            }
            ++position_;
        }
        if (fault() == Fault::none) return true;
        for (std::size_t i = 0; i < count; ++i) output[i] = 0;
        return false;
    }
    // Broker only. false with no fault means no complete request is ready.
    bool acquire(Frame& frame) noexcept {
        if (fault() != Fault::none || brokerOutstanding_) return false;
        if (!requests_.pop(frame)) return false;
        if (frame.sequence != brokerNext_) { fail(Fault::sequence); return false; }
        brokerOutstanding_ = true;
        return true;
    }
    // Broker only. Copies samples before returning. No borrowed storage retained.
    bool submit(const Frame& frame) noexcept {
        if (fault() != Fault::none) return false;
        if (!brokerOutstanding_ || frame.sequence != brokerNext_) { fail(Fault::sequence); return false; }
        for (float sample : frame.samples)
            if (frame.produced && !std::isfinite(sample)) { fail(Fault::invalid_output); return false; }
        if (!results_.push(frame)) { fail(Fault::overflow); return false; }
        ++brokerNext_;
        brokerOutstanding_ = false;
        return true;
    }
};
} // namespace labvoice::accent
