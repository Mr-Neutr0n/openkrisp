#pragma once
#include <atomic>
#include <bit>
#include <cstdint>
#include <limits>
#include <memory>
#include <stdexcept>

namespace krisp_local {
// Wire metadata only. Atomics and slot storage are NOT a mapped wire ABI.
struct Protocol {
    uint32_t version = 1;
    uint32_t sample_rate = 48000;
    uint32_t channels = 0;
    uint32_t capacity_frames = 0;
    uint32_t sample_format = 1; // IEEE754 Float32, interleaved
    uint32_t reserved = 0;
};
static_assert(sizeof(Protocol) == 24);
static_assert(std::atomic<uint64_t>::is_always_lock_free);
static_assert(std::atomic<uint32_t>::is_always_lock_free);

class Transport {
    struct Slot {
        std::atomic<uint64_t> revision{0};
        std::atomic<uint64_t> frame{UINT64_MAX};
        std::atomic<uint32_t> sample[2]{};
    };
    Protocol protocol_;
    std::unique_ptr<Slot[]> slots_;
    std::atomic<uint64_t> heartbeat_{0};
    std::atomic<bool> published_{false};
    uint64_t next_frame_ = 0; // Producer-owned.
    uint64_t last_time_ = 0;
public:
    Transport(uint32_t channels, uint32_t capacity)
        : protocol_{1, 48000, channels, capacity, 1, 0} {
        if ((channels != 1 && channels != 2) || capacity == 0)
            throw std::invalid_argument("mono/stereo and nonzero capacity required");
        slots_ = std::make_unique<Slot[]>(capacity);
    }
    const Protocol& protocol() const noexcept { return protocol_; }

    // Exactly one producer. Frame indices and heartbeat time never move backward.
    // A forward jump leaves a silent gap. UINT64_MAX is reserved, no index wrap.
    bool write(uint64_t first, const float* input, uint32_t count,
               uint64_t monotonic_ns) noexcept {
        if (!input || !count || first < next_frame_ || monotonic_ns < last_time_ ||
            first > UINT64_MAX - count) return false;
        // Revision cannot wrap before frame indices exhaust: each slot gets at
        // most UINT64_MAX publications and revision advances once per phase.
        // Reserve the upper half of the timeline to keep that bound explicit.
        if (first + count > UINT64_MAX / 2) return false;
        for (uint32_t i = 0; i < count; ++i) {
            auto& slot = slots_[(first + i) % protocol_.capacity_frames];
            const auto revision = slot.revision.load();
            slot.revision.store(revision + 1);
            slot.frame.store(first + i);
            for (uint32_t c = 0; c < protocol_.channels; ++c)
                slot.sample[c].store(std::bit_cast<uint32_t>(input[size_t(i) * protocol_.channels + c]));
            slot.revision.store(revision + 2);
        }
        next_frame_ = first + count;
        last_time_ = monotonic_ns;
        heartbeat_.store(monotonic_ns);
        published_.store(true);
        return true;
    }

    // Any number of readers. Returns number of complete frames copied.
    // Every failed frame is zero. No retry loop: concurrent overwrite may drop
    // a frame, but cannot stall the callback or return a torn frame.
    uint32_t read(uint64_t first, float* output, uint32_t count,
                  uint64_t now_ns, uint64_t stale_after_ns) const noexcept {
        if (!output) return 0;
        const bool published = published_.load();
        const auto time = heartbeat_.load();
        const bool fresh = published && now_ns >= time && now_ns - time <= stale_after_ns;
        uint32_t copied = 0;
        for (uint32_t i = 0; i < count; ++i) {
            float values[2]{};
            bool valid = false;
            if (fresh && first <= UINT64_MAX - i) {
                const uint64_t frame = first + i;
                const auto& slot = slots_[frame % protocol_.capacity_frames];
                const auto before = slot.revision.load();
                const auto stamp = slot.frame.load();
                for (uint32_t c = 0; c < protocol_.channels; ++c)
                    values[c] = std::bit_cast<float>(slot.sample[c].load());
                const auto after = slot.revision.load();
                valid = before != 0 && !(before & 1) && before == after && stamp == frame;
            }
            for (uint32_t c = 0; c < protocol_.channels; ++c)
                output[size_t(i) * protocol_.channels + c] = valid ? values[c] : 0.0f;
            copied += valid;
        }
        return copied;
    }
};
} // namespace krisp_local
