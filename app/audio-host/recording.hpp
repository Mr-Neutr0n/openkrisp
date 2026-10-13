#pragma once
#include "controls.hpp"
#include <array>
#include <atomic>
#include <cstdint>
#include <string>
#include <memory>
#include <thread>
#include <sys/types.h>

namespace labvoice {
static_assert(std::atomic<uint64_t>::is_always_lock_free);
static_assert(std::atomic<unsigned>::is_always_lock_free);
static_assert(std::atomic<bool>::is_always_lock_free);
// Stable Context-owned storage. Only the serialized IO callback produces samples.
class Recording : public std::enable_shared_from_this<Recording> {
  public:
    static constexpr uint64_t capacity = 65536;
    static constexpr uint64_t maximumFrames = (UINT32_MAX - 36ULL) / 4;
    enum class Failure : unsigned { none, overflow, discontinuity, invalid_audio, disk, size_limit, drain_timeout, route_changed };
    struct Result {
        bool completed = false;
        std::string path, error;
        uint64_t frames = 0, clippedSamples = 0;
    };
    Recording() = default;
    ~Recording();
    Recording(const Recording &) = delete;
    bool start(const std::string &path, std::string &error);
    void requestStop() noexcept;
    bool pause();
    bool resume();
    uint64_t generation() const noexcept { return generation_.load(); }
    bool ready() const noexcept { return done_.load(std::memory_order_acquire); }
    bool busy() const noexcept { return writer_.joinable(); }
    Result finish(); // Control thread, only after ready, or orderly shutdown.
    void capture(const float *mono, const float *stereo, uint32_t frames, double sampleTime,
                 const ControlSnapshot &, uint64_t generation, double inputSampleTime = -1) noexcept;
    void fail(Failure) noexcept;
    void abort(Failure) noexcept;
    uint64_t writtenFrames() const noexcept { return writtenFrames_.load(); }
    // Explicit test injection, never exposed through the production CLI.
    void setFrameLimitForTest(uint64_t frames) { limit_ = frames; }
    using WriteFunction = ssize_t (*)(int, const void *, size_t);
    void setWriterForTest(WriteFunction function) { writeFunction_ = function; }
  private:
    struct Frame { float left, right; };
    std::array<Frame, capacity> samples_{};
    std::atomic<uint64_t> write_{0}, read_{0}, writtenFrames_{0};
    std::atomic<unsigned> producers_{0};
    std::atomic<uint64_t> generation_{0};
    bool paused_ = false;
    std::atomic<bool> active_{false}, stopping_{false}, done_{false}, open_{false};
    std::atomic<Failure> failure_{Failure::none};
    bool clockKnown_ = false;
    double nextSample_ = 0, nextInputSample_ = 0;
    uint64_t limit_ = maximumFrames;
    std::thread writer_;
    int fd_ = -1;
    WriteFunction writeFunction_ = nullptr;
    Result result_;
    void run() noexcept;
};
} // namespace labvoice
