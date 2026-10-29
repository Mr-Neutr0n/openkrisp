#include "call_capture.hpp"
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstring>
#include <mutex>
#include <set>
#include <thread>
#include <unistd.h>

namespace labvoice {
bool validateCallCaptureTarget(const CallCaptureTarget& target, const AudioProcessSnapshot& snapshot, std::string& error) {
    if (target.responsiblePID <= 0 || target.responsiblePID == getpid() || target.appID.empty() || target.appID.size() > 4096 || target.appID.find('\0') != std::string::npos || target.processes.empty() || target.processes.size() > 32) {
        error = "invalid_selected_capture_target"; return false;
    }
    if (snapshot.status != "available") { error = "selected_capture_identity_unavailable"; return false; }
    std::set<AudioObjectID> objects;
    std::set<int> pids;
    for (const auto& selected : target.processes) {
        if (!selected.objectID || selected.actualPID <= 0 || selected.actualPID == getpid() || !objects.insert(selected.objectID).second || !pids.insert(selected.actualPID).second) {
            error = "invalid_or_duplicate_selected_process"; return false;
        }
        const AudioProcessUsage* match = nullptr;
        for (const auto& process : snapshot.processes) if (process.objectID == selected.objectID) {
            if (match) { error = "ambiguous_selected_process_object"; return false; }
            match = &process;
        }
        // The observer validates clnt class and PID before setting actualPID.
        // Fallback responsibility cannot admit a capture target.
        if (!match || match->actualPID != selected.actualPID || match->responsiblePID != target.responsiblePID || match->responsibleFallback || match->appID != target.appID || match->output.running != true || !match->output.devices || match->output.devices->empty() || match->usageStale == true || match->stabilizationPending == true) {
            error = "selected_capture_identity_changed_or_incomplete"; return false;
        }
    }
    return true;
}
bool supportedCallCaptureFormat(const AudioStreamBasicDescription& f) noexcept {
    const auto allowed = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsNonMixable;
    const bool planar = (f.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    return f.mFormatID == kAudioFormatLinearPCM && (f.mFormatFlags & ~allowed) == 0 &&
        (f.mFormatFlags & (kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked)) == (kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked) &&
        std::isfinite(f.mSampleRate) && f.mSampleRate >= 8000 && f.mSampleRate <= 192000 && f.mChannelsPerFrame == 2 &&
        f.mBitsPerChannel == 32 && f.mFramesPerPacket == 1 && f.mBytesPerFrame == (planar ? 4 : 8) && f.mBytesPerPacket == f.mBytesPerFrame;
}
bool callCaptureSourceFramesFitWav(uint64_t frames, double rate) noexcept {
    return std::isfinite(rate) && rate >= 8000 && rate <= 192000 &&
        std::ceil(static_cast<long double>(frames) * 48000 / rate) <= callCaptureWavMaximumFrames;
}
struct CallCaptureSession::State {
    static constexpr uint64_t slots = 32;
    static constexpr uint32_t maxFrames = 4096;
    struct Block { std::array<float, maxFrames * 2> samples{}; uint32_t frames = 0; AudioTimeStamp time{}; };
    Observe observe;
    CallCaptureTarget target;
    std::function<bool()> cancellation;
    std::unique_ptr<CallCaptureDriver> driver;
    std::unique_ptr<CallCaptureWriter> writer;
    std::array<Block, slots> queue{};
    std::atomic<uint64_t> produced{0}, consumed{0};
    std::atomic<unsigned> callbacks{0};
    std::atomic<bool> active{false}, finishing{false};
    std::atomic<unsigned> failure{0};
    std::atomic_flag producer = ATOMIC_FLAG_INIT;
    bool used = false, tapped = false, aggregated = false, registered = false, started = false, writerOpen = false, stopped = false;
    AudioStreamBasicDescription format{};
    std::thread worker;
    CallCaptureResult result;
    void fail(unsigned reason) noexcept { unsigned zero = 0; failure.compare_exchange_strong(zero, reason); active.store(false, std::memory_order_release); }
    bool cancelled() noexcept {
        try { return cancellation && cancellation(); }
        catch (...) { fail(8); return true; }
    }
    static void input(void* pointer, const AudioBufferList* buffers, const AudioTimeStamp* time) noexcept {
        auto& s = *static_cast<State*>(pointer);
        s.callbacks.fetch_add(1, std::memory_order_acq_rel);
        if (!s.active.load(std::memory_order_acquire)) { s.callbacks.fetch_sub(1); return; }
        if (s.cancelled()) { s.active.store(false, std::memory_order_release); s.callbacks.fetch_sub(1); return; }
        if (s.producer.test_and_set(std::memory_order_acquire)) { s.fail(1); s.callbacks.fetch_sub(1); return; }
        const auto finish = [&] { s.producer.clear(std::memory_order_release); s.callbacks.fetch_sub(1, std::memory_order_release); };
        const bool planar = (s.format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
        if (!buffers || !time || !(time->mFlags & kAudioTimeStampSampleTimeValid) || !(time->mFlags & kAudioTimeStampHostTimeValid) || !std::isfinite(time->mSampleTime) || buffers->mNumberBuffers != (planar ? 2U : 1U)) { s.fail(2); finish(); return; }
        const auto bytes = buffers->mBuffers[0].mDataByteSize;
        const auto stride = planar ? 4U : 8U;
        const auto frames = bytes / stride;
        if (!frames || frames > maxFrames || bytes % stride) { s.fail(2); finish(); return; }
        for (UInt32 i = 0; i < buffers->mNumberBuffers; ++i) if (!buffers->mBuffers[i].mData || buffers->mBuffers[i].mDataByteSize != bytes || buffers->mBuffers[i].mNumberChannels != (planar ? 1U : 2U)) { s.fail(2); finish(); return; }
        const auto w = s.produced.load(std::memory_order_relaxed);
        if (w - s.consumed.load(std::memory_order_acquire) >= slots) { s.fail(3); finish(); return; }
        auto& block = s.queue[w % slots]; block.frames = frames; block.time = *time;
        std::memcpy(block.samples.data(), buffers->mBuffers[0].mData, bytes);
        if (planar) std::memcpy(block.samples.data() + maxFrames, buffers->mBuffers[1].mData, bytes);
        s.produced.store(w + 1, std::memory_order_release); finish();
    }
    void run() noexcept {
        try {
            std::array<float, maxFrames * 2> interleaved{};
            bool clock = false; double next = 0; uint64_t host = 0;
            while (!finishing.load(std::memory_order_acquire) || consumed.load() != produced.load(std::memory_order_acquire)) {
                const auto r = consumed.load(std::memory_order_relaxed);
                if (r == produced.load(std::memory_order_acquire)) { std::this_thread::sleep_for(std::chrono::milliseconds(2)); continue; }
                const auto& block = queue[r % slots];
                if (clock && (std::abs(block.time.mSampleTime - next) > 0.5 || block.time.mHostTime <= host)) fail(4);
                if (!clock) { result.firstSampleTime = block.time.mSampleTime; result.firstHostTime = block.time.mHostTime; clock = true; }
                result.lastSampleTime = block.time.mSampleTime; result.lastHostTime = block.time.mHostTime;
                next = block.time.mSampleTime + block.frames; host = block.time.mHostTime;
                const bool planar = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
                for (uint32_t i = 0; i < block.frames; ++i) for (uint32_t c = 0; c < 2; ++c) {
                    const auto sample = block.samples[planar ? c * maxFrames + i : 2 * i + c];
                    if (!std::isfinite(sample)) fail(2);
                    interleaved[2 * i + c] = sample;
                }
                if (!callCaptureSourceFramesFitWav(result.sourceFrames + block.frames, format.mSampleRate)) fail(6);
                // Cancellation is linearized at callback admission. Drain already
                // admitted frames on normal Stop; identity/format failures still
                // suppress writes through failure.
                if (!failure.load() && !writer->write(interleaved.data(), block.frames, result.error)) fail(5);
                result.sourceFrames += block.frames;
                consumed.store(r + 1, std::memory_order_release);
            }
        } catch (...) { fail(5); }
    }
};
static_assert(std::atomic<uint64_t>::is_always_lock_free && std::atomic<unsigned>::is_always_lock_free && std::atomic<bool>::is_always_lock_free);
CallCaptureSession::CallCaptureSession(Observe observe, std::unique_ptr<CallCaptureDriver> driver, std::unique_ptr<CallCaptureWriter> writer) : state_(std::make_shared<State>()) {
    state_->observe = std::move(observe); state_->driver = std::move(driver); state_->writer = std::move(writer);
}
CallCaptureSession::~CallCaptureSession() {
    const auto result = stop();
    if (!result.cleanupVerified) {
        // HAL may still own the callback pointer. Retain it for process lifetime.
        static auto* retained = new std::vector<std::shared_ptr<State>>;
        static auto* mutex = new std::mutex;
        std::lock_guard guard(*mutex); retained->push_back(state_);
    }
}
bool CallCaptureSession::start(const CallCaptureTarget& target, const std::string& path, std::string& error, std::function<bool()> cancelled) {
    auto& s = *state_;
    if (s.used || !s.driver || !s.writer || !s.observe) { error = "selected_capture_session_not_reusable"; return false; }
    s.used = true; s.result.path = path; s.target = target; s.cancellation = std::move(cancelled);
    const auto failed = [&] { s.result.error = error; return false; };
    const auto cancelledNow = [&] {
        if (!s.cancelled()) return false;
        error = "selected_capture_cancelled"; return true;
    };
    try {
        if (cancelledNow() || !validateCallCaptureTarget(target, s.observe(), error) || cancelledNow()) return failed();
        // Mark attempted acquisitions too: failed HAL calls may return an owned ID.
        s.tapped = true;
        if (!s.driver->createTap(target, s.format, error) || cancelledNow()) return failed();
        s.result.sourceFormat = s.format;
        if (!supportedCallCaptureFormat(s.format)) { error = "unsupported_selected_capture_source_format"; return failed(); }
        s.writerOpen = true;
        if (!s.writer->open(path, s.format, error) || cancelledNow()) return failed();
        s.aggregated = true;
        if (!s.driver->createAggregate(error) || cancelledNow()) return failed();
        s.registered = true;
        if (!s.driver->registerIO(State::input, &s, error) || cancelledNow()) return failed();
        if (!validateCallCaptureTarget(target, s.observe(), error) || !s.driver->validateFormat(s.format, error) || cancelledNow()) return failed();
        s.worker = std::thread([state = state_] { state->run(); });
        // AudioDeviceStart may block on OS admission. Its early callbacks are
        // discarded until successful return, fresh identity/format validation
        // and a cancellation check.
        if (cancelledNow()) return failed();
        s.started = true;
        if (!s.driver->start(error) || cancelledNow()) return failed();
        // A permission wait can outlive the original process or format. Never
        // admit its early callbacks or rely on the desktop watcher's timing.
        if (!validateCallCaptureTarget(target, s.observe(), error) || !s.driver->validateFormat(s.format, error) || cancelledNow()) return failed();
        s.active.store(true, std::memory_order_release);
        return true;
    } catch (...) { error = "selected_capture_start_exception"; return failed(); }
}
bool CallCaptureSession::validateCurrentTarget(std::string& error) {
    auto& s = *state_;
    const auto cancelled = [&] {
        if (!s.cancelled()) return false;
        s.active.store(false, std::memory_order_release); error = "selected_capture_cancelled"; return true;
    };
    if (cancelled()) return false;
    if (!healthy()) { error = "selected_capture_not_active"; return false; }
    try {
        const bool valid = validateCallCaptureTarget(s.target, s.observe(), error) && s.driver->validateFormat(s.format, error);
        if (cancelled()) return false;
        if (valid) return true;
    } catch (...) { error = "selected_capture_identity_observation_failed"; }
    if (cancelled()) return false;
    s.fail(7); return false;
}
bool CallCaptureSession::healthy() const noexcept { return state_->active.load() && state_->failure.load() == 0; }
AudioStreamBasicDescription CallCaptureSession::sourceFormat() const { return state_->format; }
CallCaptureResult CallCaptureSession::stop() {
    auto& s = *state_;
    if (s.stopped) return s.result;
    s.active.store(false, std::memory_order_release);
    bool safe = true;
    const auto cleanup = [&](const char* name, bool needed, auto operation) {
        if (!needed || !safe) return;
        std::string error;
        if (!operation(error)) { s.result.cleanup.push_back(std::string(name) + ": " + error); safe = false; }
        else s.result.cleanup.push_back(std::string(name) + ": verified");
    };
    cleanup("stop", s.started, [&](auto& e) { return s.driver->stop(e); });
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (s.callbacks.load(std::memory_order_acquire) && std::chrono::steady_clock::now() < deadline) std::this_thread::sleep_for(std::chrono::milliseconds(1));
    if (s.callbacks.load()) { safe = false; s.result.cleanup.push_back("callback_drain: timeout"); }
    cleanup("unregister_io", s.registered, [&](auto& e) { return s.driver->unregisterIO(e); });
    cleanup("destroy_aggregate", s.aggregated, [&](auto& e) { return s.driver->destroyAggregate(e); });
    cleanup("destroy_tap", s.tapped, [&](auto& e) { return s.driver->destroyTap(e); });
    s.finishing.store(true, std::memory_order_release);
    if (s.worker.joinable()) s.worker.join();
    if (s.writerOpen && !s.writer->close(s.result.frames, s.result.error)) s.fail(5);
    s.result.cleanupVerified = safe;
    const auto failure = s.failure.load();
    if (s.result.error.empty() && failure) {
        static const char* errors[] = {"", "concurrent_capture_callback", "invalid_capture_buffer_or_timestamp", "capture_queue_overflow", "source_clock_discontinuity", "capture_writer_failed", "capture_riff32_capacity", "selected_capture_identity_invalidated", "capture_cancellation_predicate_failed"};
        s.result.error = errors[failure];
    }
    if (s.result.error.empty() && !safe) s.result.error = "selected_capture_cleanup_unverified";
    if (s.result.error.empty() && s.result.frames == 0) s.result.error = "selected_capture_no_audio_frames";
    s.result.completed = s.started && safe && !failure && s.result.error.empty() && s.result.frames > 0;
    s.stopped = true; return s.result;
}
}
