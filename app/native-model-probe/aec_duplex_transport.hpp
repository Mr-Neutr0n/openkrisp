#pragma once
#include "aec_worker_protocol.hpp"
#include <atomic>
#include <stdexcept>

namespace krisp_probe {
struct AECDuplexBufferingConfig {
    std::size_t maximumCallbackFrames = 4096;
    std::size_t schedulingBudgetFrames = 4; // Test slack in units of 480 samples.
};
struct AECLaneStamp {
    double inputSampleOrigin = 0, outputSampleOrigin = 0;
    std::uint64_t callbackHostTime = 0;
    bool sampleOriginsValid = true, callbackHostTimeValid = false;
};
struct AECPairedBlock {
    const float* microphone = nullptr;
    const float* finalReference = nullptr; // Stereo interleaved, already committed playback.
    std::size_t count = 0; // Frames, not stereo values.
    std::uint64_t epoch = 0;
    AECLaneStamp microphoneStamp{}, referenceStamp{};
};
// Construct before use. One serialized callback and one broker thread. Never
// reset a live transport. Pairing does not establish equal acoustic time.
class AECDuplexTransport {
  public:
    static constexpr std::size_t capacity = 32, frameSamples = 480;
    static_assert(std::atomic<std::uint64_t>::is_always_lock_free);
    static_assert(std::atomic<unsigned>::is_always_lock_free);
    enum class Fault : unsigned { none, invalid_input, timing, epoch, overflow, deadline,
                                  sequence, invalid_output, worker_dead, stopped, worker_failure };
    // Records the callback containing ONLY the first sample of a model frame.
    // sampleOffset is a sample count from that callback's supplied origins.
    // It is not host ticks, and does not describe later callbacks in the frame.
    struct LaneProvenance {
        std::uint64_t callbackHostTime = 0;
        std::size_t sampleOffset = 0;
        bool callbackHostTimeValid = false;
        double callbackInputSampleOrigin = 0, callbackOutputSampleOrigin = 0;
        bool operator==(const LaneProvenance&) const = default;
    };
    struct Frame {
        aec_wire::Frame wire{};
        LaneProvenance microphoneProvenance{}, referenceProvenance{};
    };
    using PairedBlock = AECPairedBlock;
    using LaneStamp = AECLaneStamp;
    using Request = Frame;
    using Result = Frame;
    struct OutputSpan {
        std::size_t outputOffset = 0, count = 0, frameSampleOffset = 0;
        std::uint64_t sequence = 0, epoch = 0;
        aec_wire::Timing microphoneTiming{}, referenceTiming{};
        LaneProvenance microphoneProvenance{}, referenceProvenance{};
    };
    struct OutputMetadata {
        std::array<OutputSpan, 10> spans{}; // 4096 samples intersect at most 10 frames.
        std::size_t count = 0; // Initial silence has no provenance span.
    };
  private:
    const AECDuplexBufferingConfig buffering_;
    const std::size_t delay_;
    struct Queue {
        std::array<Frame, capacity> slots{};
        std::atomic<std::uint64_t> write{0}, read{0};
        bool push(const Frame& frame) noexcept {
            const auto w = write.load(std::memory_order_relaxed);
            if (w - read.load(std::memory_order_acquire) == capacity) return false;
            slots[w % capacity] = frame;
            write.store(w + 1, std::memory_order_release);
            return true;
        }
        bool pop(Frame& frame) noexcept {
            const auto r = read.load(std::memory_order_relaxed);
            if (r == write.load(std::memory_order_acquire)) return false;
            frame = slots[r % capacity];
            read.store(r + 1, std::memory_order_release);
            return true;
        }
    } requests_, results_;
    std::atomic<unsigned> fault_{0};
    Frame input_{}, output_{}, outstanding_{};
    std::size_t inputOffset_ = 0, outputOffset_ = frameSamples;
    std::uint64_t position_ = 0, nextInput_ = 0, nextOutput_ = 0, brokerNext_ = 0, epoch_ = 0;
    bool haveEpoch_ = false, brokerOutstanding_ = false;
    AECLaneStamp nextMic_{}, nextReference_{};
    static std::size_t checkedDelay(AECDuplexBufferingConfig config) {
        if (!config.maximumCallbackFrames || config.maximumCallbackFrames > 4096)
            throw std::invalid_argument("Maximum callback frames must be 1 through 4096");
        const auto base = (config.maximumCallbackFrames + 958) / frameSamples;
        if (base >= capacity || config.schedulingBudgetFrames >= capacity - base)
            throw std::invalid_argument("Duplex buffering exceeds fixed capacity");
        return (base + config.schedulingBudgetFrames) * frameSamples;
    }
    static bool stampValid(const AECLaneStamp& stamp, std::size_t count) noexcept {
        constexpr double bound = 9007199254740991.0 - 480;
        return stamp.sampleOriginsValid && std::isfinite(stamp.inputSampleOrigin) &&
            std::isfinite(stamp.outputSampleOrigin) &&
            std::abs(stamp.inputSampleOrigin) <= bound - count &&
            std::abs(stamp.outputSampleOrigin) <= bound - count &&
            (stamp.inputSampleOrigin + count) - stamp.inputSampleOrigin == count &&
            (stamp.outputSampleOrigin + count) - stamp.outputSampleOrigin == count;
    }
    static bool follows(const AECLaneStamp& expected, const AECLaneStamp& stamp) noexcept {
        // Callback anchors are retained as observations, without clock conversion
        // or an assumption that host ticks advance at a particular sample rate.
        return stamp.inputSampleOrigin == expected.inputSampleOrigin &&
            stamp.outputSampleOrigin == expected.outputSampleOrigin;
    }
    static aec_wire::Timing timing(const AECLaneStamp& stamp, std::size_t offset) noexcept {
        return {stamp.inputSampleOrigin + offset, stamp.outputSampleOrigin + offset, 0, 1};
    }
    static LaneProvenance provenance(const AECLaneStamp& stamp, std::size_t offset) noexcept {
        return {stamp.callbackHostTime, offset, stamp.callbackHostTimeValid,
                stamp.inputSampleOrigin, stamp.outputSampleOrigin};
    }
    static bool overlaps(const float* a, std::size_t aCount, const float* b, std::size_t bCount) noexcept {
        const auto x = reinterpret_cast<std::uintptr_t>(a), y = reinterpret_cast<std::uintptr_t>(b);
        return x <= y ? y - x < aCount * sizeof(float) : x - y < bCount * sizeof(float);
    }
    static bool sameIdentity(const Frame& a, const Frame& b) noexcept {
        return a.wire.sequence == b.wire.sequence && a.wire.epoch == b.wire.epoch &&
            a.wire.microphoneTiming == b.wire.microphoneTiming && a.wire.referenceTiming == b.wire.referenceTiming &&
            a.microphoneProvenance == b.microphoneProvenance && a.referenceProvenance == b.referenceProvenance;
    }
  public:
    explicit AECDuplexTransport(AECDuplexBufferingConfig config = {})
        : buffering_(config), delay_(checkedDelay(config)) {}
    std::size_t actualDelaySamples() const noexcept { return delay_; }
    std::size_t maximumCallbackFrames() const noexcept { return buffering_.maximumCallbackFrames; }
    const AECDuplexBufferingConfig& bufferingConfig() const noexcept { return buffering_; }
    Fault fault() const noexcept { return static_cast<Fault>(fault_.load(std::memory_order_acquire)); }
    void fail(Fault reason) noexcept {
        if (reason == Fault::none) return;
        unsigned expected = 0;
        fault_.compare_exchange_strong(expected, static_cast<unsigned>(reason),
                                       std::memory_order_release, std::memory_order_relaxed);
    }
    // No allocations, IO, waits or native calls. Output must not overlap either
    // input. Invalid counts above the declared maximum leave the extent untouched;
    // their caller must mute it. Other failures silence the complete output block.
    // Optional metadata describes frame anchors and sample offsets, never inferred
    // host times. Add frameSampleOffset to an anchor only as a sample count.
    bool exchange(const AECPairedBlock& block, float* destination, OutputMetadata* metadata = nullptr) noexcept {
        if (metadata) metadata->count = 0;
        if (!destination || !block.count || block.count > buffering_.maximumCallbackFrames) {
            fail(Fault::invalid_input); return false;
        }
        auto silence = [&] { std::fill_n(destination, block.count, 0.0f); };
        if (fault() != Fault::none) { silence(); return false; }
        if (!block.microphone || !block.finalReference ||
            overlaps(destination, block.count, block.microphone, block.count) ||
            overlaps(destination, block.count, block.finalReference, block.count * 2) ||
            position_ > std::numeric_limits<std::uint64_t>::max() - block.count) {
            fail(Fault::invalid_input); silence(); return false;
        }
        if (!stampValid(block.microphoneStamp, block.count) || !stampValid(block.referenceStamp, block.count) ||
            (haveEpoch_ && (!follows(nextMic_, block.microphoneStamp) || !follows(nextReference_, block.referenceStamp)))) {
            fail(Fault::timing); silence(); return false;
        }
        if (haveEpoch_ && block.epoch != epoch_) { fail(Fault::epoch); silence(); return false; }
        // Reject double precision loss before publishing. Every new frame's
        // origins must also satisfy the worker's exact +480 continuity contract.
        auto micFrame = input_.wire.microphoneTiming, refFrame = input_.wire.referenceTiming;
        bool haveFrame = nextInput_ != 0 || inputOffset_ != 0;
        for (std::size_t offset = inputOffset_ ? frameSamples - inputOffset_ : 0;
             offset < block.count; offset += frameSamples) {
            const auto micNext = timing(block.microphoneStamp, offset);
            const auto refNext = timing(block.referenceStamp, offset);
            if (haveFrame && (micNext.inputSampleOrigin != micFrame.inputSampleOrigin + frameSamples ||
                micNext.outputSampleOrigin != micFrame.outputSampleOrigin + frameSamples ||
                refNext.inputSampleOrigin != refFrame.inputSampleOrigin + frameSamples ||
                refNext.outputSampleOrigin != refFrame.outputSampleOrigin + frameSamples)) {
                fail(Fault::timing); silence(); return false;
            }
            micFrame = micNext; refFrame = refNext; haveFrame = true;
        }
        // Validate the whole callback before publishing any paired frame.
        for (std::size_t i = 0; i < block.count; ++i)
            if (!std::isfinite(block.microphone[i]) || !std::isfinite(block.finalReference[2*i]) ||
                !std::isfinite(block.finalReference[2*i+1])) {
                fail(Fault::invalid_input); silence(); return false;
            }
        silence();
        if (!haveEpoch_) { haveEpoch_ = true; epoch_ = block.epoch; }
        nextMic_ = block.microphoneStamp; nextReference_ = block.referenceStamp;
        nextMic_.inputSampleOrigin += block.count; nextMic_.outputSampleOrigin += block.count;
        nextReference_.inputSampleOrigin += block.count; nextReference_.outputSampleOrigin += block.count;
        for (std::size_t i = 0; i < block.count; ++i) {
            if (fault() != Fault::none) break;
            if (!inputOffset_) {
                input_.wire.kind = aec_wire::Kind::request;
                input_.wire.sequence = nextInput_; input_.wire.epoch = epoch_;
                input_.wire.microphoneTiming = timing(block.microphoneStamp, i);
                input_.wire.referenceTiming = timing(block.referenceStamp, i);
                input_.microphoneProvenance = provenance(block.microphoneStamp, i);
                input_.referenceProvenance = provenance(block.referenceStamp, i);
            }
            input_.wire.microphone[inputOffset_] = block.microphone[i];
            input_.wire.reference[2*inputOffset_] = block.finalReference[2*i];
            input_.wire.reference[2*inputOffset_+1] = block.finalReference[2*i+1];
            if (++inputOffset_ == frameSamples) {
                if (nextInput_ == UINT64_MAX) { fail(Fault::sequence); break; }
                if (!requests_.push(input_)) { fail(Fault::overflow); break; }
                ++nextInput_; inputOffset_ = 0;
            }
            if (position_ >= delay_) {
                if (outputOffset_ == frameSamples) {
                    if (!results_.pop(output_)) { fail(Fault::deadline); break; }
                    if (output_.wire.sequence != nextOutput_++) { fail(Fault::sequence); break; }
                    outputOffset_ = 0;
                }
                if (metadata) {
                    if (!metadata->count || outputOffset_ == 0 || i == 0) {
                        if (metadata->count == metadata->spans.size()) { fail(Fault::overflow); break; }
                        auto& span = metadata->spans[metadata->count++];
                        span = {i, 0, outputOffset_, output_.wire.sequence, output_.wire.epoch,
                                output_.wire.microphoneTiming, output_.wire.referenceTiming,
                                output_.microphoneProvenance, output_.referenceProvenance};
                    }
                    ++metadata->spans[metadata->count-1].count;
                }
                destination[i] = output_.wire.output[outputOffset_++];
            }
            ++position_;
        }
        if (fault() == Fault::none) return true;
        silence(); if (metadata) metadata->count = 0;
        return false;
    }
    // Broker only. false without a fault means no complete pair is ready, or
    // the one outstanding pair still needs a result. No borrowed storage survives.
    bool acquire(Frame& frame) noexcept {
        if (fault() != Fault::none || brokerOutstanding_) return false;
        if (!requests_.pop(frame)) return false;
        if (frame.wire.sequence != brokerNext_) { fail(Fault::sequence); return false; }
        outstanding_ = frame; brokerOutstanding_ = true; return true;
    }
    bool submit(const Frame& frame) noexcept {
        if (fault() != Fault::none) return false;
        if (!brokerOutstanding_ || !sameIdentity(outstanding_, frame)) { fail(Fault::sequence); return false; }
        if (frame.wire.kind != aec_wire::Kind::result) { fail(Fault::invalid_output); return false; }
        for (auto value : frame.wire.output)
            if (!std::isfinite(value)) { fail(Fault::invalid_output); return false; }
        if (!results_.push(frame)) { fail(Fault::overflow); return false; }
        ++brokerNext_; brokerOutstanding_ = false; return true;
    }
};
}
