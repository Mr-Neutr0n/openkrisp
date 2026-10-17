#pragma once
#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace krisp_probe {
// One serialized callback producer/consumer and one broker consumer/producer.
// Construct before either thread starts. Never reset a live transport.
template<std::size_t Capacity = 32, std::size_t DelayFrames = 12>
class ProviderTransport {
  public:
    static constexpr std::size_t frameSamples = 480;
    static constexpr std::size_t delaySamples = DelayFrames * frameSamples;
    static_assert(Capacity > 0 && DelayFrames > 0 && DelayFrames < Capacity);
    static_assert(std::atomic<std::uint64_t>::is_always_lock_free);
    static_assert(std::atomic<unsigned>::is_always_lock_free);
    enum class Fault : unsigned { none, invalid_input, overflow, deadline, sequence,
                                  invalid_output, worker_dead, stopped };
    struct Frame {
        std::uint64_t sequence = 0;
        std::array<float, frameSamples> samples{};
    };
  private:
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
    // Counts above 4096 fail without touching the untrusted destination extent.
    // The caller must mute unsupported-size output buffers.
    bool exchange(const float* input, float* output, std::size_t count) noexcept {
        if (!output || count > 4096) { fail(Fault::invalid_input); return false; }
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
            if (position_ >= delaySamples) {
                if (outputOffset_ == frameSamples) {
                    if (!results_.pop(output_)) { fail(Fault::deadline); break; }
                    if (output_.sequence != nextOutput_++) { fail(Fault::sequence); break; }
                    outputOffset_ = 0;
                }
                output[i] = output_.samples[outputOffset_++];
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
            if (!std::isfinite(sample)) { fail(Fault::invalid_output); return false; }
        if (!results_.push(frame)) { fail(Fault::overflow); return false; }
        ++brokerNext_;
        brokerOutstanding_ = false;
        return true;
    }
};
} // namespace krisp_probe
