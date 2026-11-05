#pragma once
#include <algorithm>
#include <array>
#include <bit>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>
#include <span>

namespace accent_engine::wire {
constexpr std::size_t headerBytes = 36, samples = 480, payloadBytes = samples * 4;
constexpr std::size_t maxFrameBytes = headerBytes + payloadBytes;
using Token = std::array<std::uint8_t, 16>;
using Storage = std::array<std::uint8_t, maxFrameBytes>;
enum class Kind : std::uint8_t { request = 1, result = 2, close = 3, empty = 4 };
constexpr unsigned mask(Kind kind) { return 1u << static_cast<unsigned>(kind); }
struct Frame {
    Kind kind = Kind::request;
    std::uint64_t sequence = 0;
    std::array<float, samples> values{}; // Unused for close.
};
static_assert(sizeof(float) == 4 && std::numeric_limits<float>::is_iec559);
inline std::uint64_t read(const std::uint8_t* p, unsigned count) noexcept {
    std::uint64_t value = 0;
    for (unsigned i = 0; i < count; ++i) value |= std::uint64_t(p[i]) << (8 * i);
    return value;
}
inline void write(std::uint8_t* p, std::uint64_t value, unsigned count) noexcept {
    for (unsigned i = 0; i < count; ++i) p[i] = static_cast<std::uint8_t>(value >> (8 * i));
}
// Returns 0 on rejection. No partial frame may be published on rejection.
inline std::size_t encode(const Frame& frame, const Token& token, Storage& out) noexcept {
    if (frame.kind != Kind::request && frame.kind != Kind::result && frame.kind != Kind::close && frame.kind != Kind::empty) return 0;
    const bool close = frame.kind == Kind::close || frame.kind == Kind::empty;
    if (!close) for (auto value : frame.values) if (!std::isfinite(value)) return 0;
    out.fill(0);
    write(out.data(), 0x52414b4f, 4);
    out[4] = 1; out[5] = static_cast<std::uint8_t>(frame.kind);
    std::memcpy(out.data() + 8, token.data(), token.size());
    write(out.data() + 24, frame.sequence, 8);
    write(out.data() + 32, close ? 0 : payloadBytes, 4);
    if (!close) for (std::size_t i = 0; i < samples; ++i)
        write(out.data() + headerBytes + 4 * i, std::bit_cast<std::uint32_t>(frame.values[i]), 4);
    return close ? headerBytes : maxFrameBytes;
}
// Single-thread use. Callback receives a copied, borrowed Frame valid until
// callback return. It must complete synchronously and must not reenter parser.
// false from callback, exception, malformed bytes or reentry poisons parser.
class Parser {
    Token token_;
    unsigned kinds_;
    std::uint64_t next_;
    Storage storage_{};
    std::size_t used_ = 0, target_ = headerBytes;
    bool failed_ = false, closed_ = false, ended_ = false, active_ = false, exhausted_ = false;
    bool reject() noexcept { failed_ = true; return false; }
  public:
    explicit Parser(Token token, unsigned kinds, std::uint64_t firstSequence = 0) noexcept
        : token_(token), kinds_(kinds), next_(firstSequence) {
        constexpr auto all = mask(Kind::request) | mask(Kind::result) | mask(Kind::close) | mask(Kind::empty);
        if (!kinds || (kinds & ~all)) failed_ = true;
    }
    bool failed() const noexcept { return failed_; }
    bool closed() const noexcept { return closed_; }
    std::size_t retainedBytes() const noexcept { return used_; }
    template<class Callback>
    bool push(std::span<const std::uint8_t> bytes, Callback&& callback) noexcept {
        if (failed_ || ended_) return false;
        if (active_) return reject();
        active_ = true;
        struct Guard { bool& flag; ~Guard() { flag = false; } } guard{active_};
        try {
            while (!bytes.empty()) {
                if (closed_ || exhausted_) return reject();
                const auto amount = std::min(target_ - used_, bytes.size());
                std::memcpy(storage_.data() + used_, bytes.data(), amount);
                used_ += amount; bytes = bytes.subspan(amount);
                if (used_ != target_) continue;
                const auto code = storage_[5];
                if (target_ == headerBytes) {
                    if (read(storage_.data(), 4) != 0x52414b4f || storage_[4] != 1 ||
                        read(storage_.data() + 6, 2) != 0 || code < 1 || code > 4 ||
                        !(kinds_ & (1u << code)) ||
                        std::memcmp(storage_.data() + 8, token_.data(), 16) != 0 ||
                        read(storage_.data() + 24, 8) != next_) return reject();
                    const auto length = read(storage_.data() + 32, 4);
                    if (length != ((code == 3 || code == 4) ? 0 : payloadBytes)) return reject();
                    target_ += length;
                    if (length) continue;
                }
                Frame frame;
                frame.kind = static_cast<Kind>(code); frame.sequence = next_;
                if (code != 3 && code != 4) for (std::size_t i = 0; i < samples; ++i) {
                    frame.values[i] = std::bit_cast<float>(static_cast<std::uint32_t>(read(storage_.data() + headerBytes + 4 * i, 4)));
                    if (!std::isfinite(frame.values[i])) return reject();
                }
                else if (code == 3) closed_ = true;
                if (next_ == std::numeric_limits<std::uint64_t>::max()) exhausted_ = true;
                else ++next_;
                used_ = 0; target_ = headerBytes;
                if (!callback(frame) || failed_) return reject();
            }
            return true;
        } catch (...) { return reject(); }
    }
    // Clean boundary EOF is valid without close. Owner decides if close is required.
    bool finish() noexcept {
        if (active_) return reject();
        if (failed_ || ended_) return false;
        ended_ = true;
        return used_ == 0 ? true : reject();
    }
};
} // namespace accent_engine::wire
