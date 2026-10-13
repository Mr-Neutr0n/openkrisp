#include "recording.hpp"
#include <algorithm>
#include <cerrno>
#include <chrono>
#include <cmath>
#include <cstring>
#include <fcntl.h>
#include <stdexcept>
#include <sys/stat.h>
#include <unistd.h>

namespace labvoice {
namespace {
bool writeAll(int fd, const void *data, size_t size, Recording::WriteFunction function = nullptr) {
    auto bytes = static_cast<const unsigned char *>(data);
    while (size) {
        ssize_t written = function ? function(fd, bytes, size) : write(fd, bytes, size);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return false;
        bytes += written; size -= size_t(written);
    }
    return true;
}
std::array<unsigned char, 44> header(uint64_t frames) {
    std::array<unsigned char, 44> h{};
    auto put = [&](size_t at, uint32_t value, size_t count) {
        for (size_t i = 0; i < count; ++i) h[at + i] = (value >> (8 * i)) & 255;
    };
    std::memcpy(h.data(), "RIFF", 4); put(4, uint32_t(36 + frames * 4), 4);
    std::memcpy(h.data() + 8, "WAVEfmt ", 8); put(16, 16, 4); put(20, 1, 2);
    put(22, 2, 2); put(24, 48000, 4); put(28, 192000, 4); put(32, 4, 2);
    put(34, 16, 2); std::memcpy(h.data() + 36, "data", 4); put(40, uint32_t(frames * 4), 4);
    return h;
}
const char *failureText(Recording::Failure failure) {
    switch (failure) {
    case Recording::Failure::none: return "";
    case Recording::Failure::overflow: return "capture_queue_overflow";
    case Recording::Failure::discontinuity: return "sample_clock_discontinuity";
    case Recording::Failure::invalid_audio: return "invalid_callback_audio";
    case Recording::Failure::disk: return "wav_write_or_finalize_failed";
    case Recording::Failure::size_limit: return "riff_size_limit";
    case Recording::Failure::drain_timeout: return "capture_drain_timeout";
    case Recording::Failure::route_changed: return "route_changed_or_processor_failed";
    }
    return "unknown_recording_failure";
}
} // namespace
Recording::~Recording() {
    requestStop();
    // The writer owns this object through run(). A destructor cannot free live
    // writer storage. Completed-but-unjoined handles detach here so a retained
    // HAL Context's last release never performs a join on its callback thread.
    if (writer_.joinable()) writer_.detach();
}
bool Recording::start(const std::string &path, std::string &error) {
    if (busy()) { error = "recording_already_active_or_result_pending"; return false; }
    const auto slash = path.rfind('/');
    if (path.empty() || path.front() != '/' || slash == std::string::npos || slash + 1 == path.size() ||
        path.find('\0') != std::string::npos || !path.ends_with(".wav")) {
        error = "invalid_absolute_wav_path"; return false;
    }
    int directory = open(path.substr(0, slash).c_str(), O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    struct stat info{};
    if (directory < 0 || fstat(directory, &info) || info.st_uid != getuid() ||
        (info.st_mode & 0777) != 0700) {
        if (directory >= 0) close(directory);
        error = "staging_directory_must_be_owned_private_0700"; return false;
    }
    fd_ = openat(directory, path.substr(slash + 1).c_str(), O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    close(directory);
    if (fd_ < 0) { error = "exclusive_wav_create_failed"; return false; }
    // An unfinished file deliberately has no finalized RIFF header.
    std::array<unsigned char, 44> provisional{};
    if (fchmod(fd_, 0600) || !writeAll(fd_, provisional.data(), provisional.size())) {
        close(fd_); fd_ = -1; error = "wav_prepare_failed"; return false;
    }
    result_ = {}; result_.path = path;
    write_.store(0); read_.store(0); writtenFrames_.store(0); failure_.store(Failure::none);
    clockKnown_ = false; stopping_.store(false); done_.store(false); open_.store(true);
    try { writer_ = std::thread([owner = shared_from_this()] { owner->run(); }); }
    catch (...) { open_.store(false); close(fd_); fd_ = -1; error = "writer_thread_start_failed"; return false; }
    paused_ = false; generation_.fetch_add(1); active_.store(true);
    return true;
}
void Recording::fail(Failure value) noexcept {
    if (!open_.load() || stopping_.load()) return;
    abort(value);
}
void Recording::abort(Failure value) noexcept {
    auto expected = Failure::none;
    failure_.compare_exchange_strong(expected, value);
    active_.store(false); stopping_.store(true);
}
void Recording::requestStop() noexcept { active_.store(false); generation_.fetch_add(1); stopping_.store(true); }
bool Recording::pause() {
    if (!busy() || stopping_.load() || paused_) return false;
    active_.store(false); generation_.fetch_add(1);
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (producers_.load()) {
        if (std::chrono::steady_clock::now() >= deadline) {
            auto expected = Failure::none;
            failure_.compare_exchange_strong(expected, Failure::drain_timeout);
            stopping_.store(true);
            return false;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    if (stopping_.load()) return false;
    paused_ = true; clockKnown_ = false;
    return true;
}
bool Recording::resume() {
    if (!busy() || stopping_.load() || !paused_) return false;
    paused_ = false; generation_.fetch_add(1); active_.store(true);
    return true;
}
void Recording::capture(const float *mono, const float *stereo, uint32_t frames, double sampleTime,
                        const ControlSnapshot &controls, uint64_t generation, double inputSampleTime) noexcept {
    producers_.fetch_add(1);
    struct Release { std::atomic<unsigned> &value; ~Release() { value.fetch_sub(1); } } release{producers_};
    if (!active_.load() || generation != generation_.load()) return;
    if (inputSampleTime == -1) inputSampleTime = sampleTime;
    if (!std::isfinite(inputSampleTime) || inputSampleTime < 0 ||
        inputSampleTime > 9007199254740991.0 - frames ||
        (clockKnown_ && std::abs(inputSampleTime - nextInputSample_) > 0.000001) ||
        !std::isfinite(sampleTime) || sampleTime < 0 || sampleTime > 9007199254740991.0 - frames ||
        (clockKnown_ && std::abs(sampleTime - nextSample_) > 0.000001)) { fail(Failure::discontinuity); return; }
    clockKnown_ = true; nextSample_ = sampleTime + frames; nextInputSample_ = inputSampleTime + frames;
    uint64_t w = write_.load(std::memory_order_relaxed), r = read_.load(std::memory_order_acquire);
    if (frames > capacity || w - r > capacity - frames) { fail(Failure::overflow); return; }
    for (uint32_t i = 0; i < frames; ++i) {
        const float m = controlledSample(mono[i], controls.microphone);
        samples_[(w + i) % capacity] = {
            .5f * m + .5f * controlledSample(stereo[i * 2], controls.speaker),
            .5f * m + .5f * controlledSample(stereo[i * 2 + 1], controls.speaker)};
    }
    write_.store(w + frames, std::memory_order_release);
}
void Recording::run() noexcept {
    std::array<unsigned char, 4096 * 4> pcm{};
    for (;;) {
        uint64_t r = read_.load(std::memory_order_relaxed), w = write_.load(std::memory_order_acquire);
        size_t count = size_t(std::min<uint64_t>(w - r, 4096));
        if (count && failure_.load() == Failure::none) {
            if (result_.frames > limit_ || count > limit_ - result_.frames) {
                failure_.store(Failure::size_limit); active_.store(false); stopping_.store(true);
            } else {
                for (size_t i = 0; i < count; ++i) {
                    const Frame frame = samples_[(r + i) % capacity];
                    const float values[2]{frame.left, frame.right};
                    for (size_t ch = 0; ch < 2; ++ch) {
                        float value = values[ch];
                        if (!std::isfinite(value)) value = 0;
                        if (value > 1 || value < -1) ++result_.clippedSamples;
                        value = std::clamp(value, -1.0f, 1.0f);
                        int32_t integer = int32_t(std::lround(double(value) * 32768));
                        integer = std::clamp(integer, -32768, 32767);
                        uint16_t sample = uint16_t(int16_t(integer));
                        pcm[i * 4 + ch * 2] = sample & 255;
                        pcm[i * 4 + ch * 2 + 1] = sample >> 8;
                    }
                }
                if (!writeAll(fd_, pcm.data(), count * 4, writeFunction_)) {
                    failure_.store(Failure::disk); active_.store(false); stopping_.store(true);
                } else { result_.frames += count; writtenFrames_.store(result_.frames); }
            }
        }
        if (count) read_.store(r + count, std::memory_order_release);
        if (stopping_.load() && producers_.load() == 0 && read_.load() == write_.load()) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    if (failure_.load() == Failure::none) {
        auto h = header(result_.frames);
        if (lseek(fd_, 0, SEEK_SET) < 0 || !writeAll(fd_, h.data(), h.size(), writeFunction_) || fsync(fd_))
            failure_.store(Failure::disk);
    }
    if (failure_.load() != Failure::none) {
        // Best effort invalidation; the failed result remains authoritative if disk IO fails.
        std::array<unsigned char, 44> incomplete{};
        if (lseek(fd_, 0, SEEK_SET) >= 0) (void)writeAll(fd_, incomplete.data(), incomplete.size());
    }
    if (close(fd_)) failure_.store(Failure::disk);
    fd_ = -1;
    result_.completed = failure_.load() == Failure::none;
    result_.error = failureText(failure_.load());
    open_.store(false);
    done_.store(true, std::memory_order_release);
}
Recording::Result Recording::finish() {
    requestStop();
    if (!writer_.joinable() || !ready()) throw std::logic_error("No ready recording result");
    writer_.join();
    return result_;
}
} // namespace labvoice
