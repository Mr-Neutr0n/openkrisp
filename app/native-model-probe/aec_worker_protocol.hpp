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

namespace krisp_probe::aec_wire {
constexpr std::size_t headerBytes = 120, samples = 480, referenceSamples = 960, payloadBytes = (samples + referenceSamples) * 4;
constexpr std::size_t maxFrameBytes = headerBytes + payloadBytes;
using Token = std::array<std::uint8_t, 16>;
using Storage = std::array<std::uint8_t, maxFrameBytes>;
enum class Kind : std::uint8_t { request = 1, result = 2, close = 3 };
constexpr unsigned mask(Kind kind) { return 1u << static_cast<unsigned>(kind); }
struct Timing {
    double inputSampleOrigin = 0, outputSampleOrigin = 0;
    std::uint64_t hostTime = 0;
    std::uint32_t flags = 0; // bit 0 sample origins valid, bit 1 host time valid
    bool operator==(const Timing&) const = default;
};
inline bool validTiming(const Timing& t) noexcept {
    constexpr double bound = 9007199254740991.0;
    return !(t.flags & ~3u) && std::isfinite(t.inputSampleOrigin) && std::isfinite(t.outputSampleOrigin) &&
        std::abs(t.inputSampleOrigin) <= bound - samples && std::abs(t.outputSampleOrigin) <= bound - samples;
}
struct Frame {
    Kind kind = Kind::request;
    std::uint64_t sequence = 0;
    std::uint64_t epoch = 0;
    Timing microphoneTiming{}, referenceTiming{};
    std::array<float, samples> microphone{}, output{};
    std::array<float, referenceSamples> reference{};
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
    if (frame.kind != Kind::request && frame.kind != Kind::result && frame.kind != Kind::close) return 0;
    const bool close = frame.kind == Kind::close;
    if (!close) {
        if (!validTiming(frame.microphoneTiming) || !validTiming(frame.referenceTiming)) return 0;
        if (frame.kind == Kind::request) {
            for (auto v : frame.microphone) if (!std::isfinite(v)) return 0;
            for (auto v : frame.reference) if (!std::isfinite(v)) return 0;
        } else for (auto v : frame.output) if (!std::isfinite(v)) return 0;
    }
    out.fill(0);
    write(out.data(), 0x41454344, 4);
    out[4] = 1; out[5] = static_cast<std::uint8_t>(frame.kind);
    std::memcpy(out.data() + 8, token.data(), token.size());
    write(out.data() + 24, frame.sequence, 8);
    const auto length = close ? 0 : frame.kind == Kind::request ? payloadBytes : samples * 4;
    write(out.data() + 32, length, 4);
    write(out.data() + 36, frame.epoch, 8);
    if (!close) {
        auto put = [&](std::size_t offset, const Timing& t) {
            write(out.data()+offset, std::bit_cast<std::uint64_t>(t.inputSampleOrigin),8);
            write(out.data()+offset+8, std::bit_cast<std::uint64_t>(t.outputSampleOrigin),8);
            write(out.data()+offset+16,t.hostTime,8); write(out.data()+offset+24,t.flags,4);
        };
        put(44,frame.microphoneTiming); put(76,frame.referenceTiming);
        for (std::size_t i=0;i<length/4;++i) {
            const float v = frame.kind == Kind::result ? frame.output[i] : i < samples ? frame.microphone[i] : frame.reference[i-samples];
            write(out.data()+headerBytes+4*i,std::bit_cast<std::uint32_t>(v),4);
        }
    }
    return headerBytes + length;
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
        constexpr auto all = mask(Kind::request) | mask(Kind::result) | mask(Kind::close);
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
                    if (read(storage_.data(), 4) != 0x41454344 || storage_[4] != 1 ||
                        read(storage_.data() + 6, 2) != 0 || code < 1 || code > 3 ||
                        !(kinds_ & (1u << code)) ||
                        std::memcmp(storage_.data() + 8, token_.data(), 16) != 0 ||
                        read(storage_.data() + 24, 8) != next_) return reject();
                    const auto length = read(storage_.data() + 32, 4);
                    if (length != (code == 3 ? 0 : code == 1 ? payloadBytes : samples * 4)) return reject();
                    target_ += length;
                    if (length) continue;
                }
                Frame frame;
                frame.kind = static_cast<Kind>(code); frame.sequence = next_;
                frame.epoch = read(storage_.data()+36,8);
                if (read(storage_.data()+72,4) || read(storage_.data()+104,4) || read(storage_.data()+108,8) || read(storage_.data()+116,4)) return reject();
                if (code != 3) {
                    auto get = [&](std::size_t offset, Timing& t) {
                        t.inputSampleOrigin=std::bit_cast<double>(read(storage_.data()+offset,8));
                        t.outputSampleOrigin=std::bit_cast<double>(read(storage_.data()+offset+8,8));
                        t.hostTime=read(storage_.data()+offset+16,8); t.flags=static_cast<std::uint32_t>(read(storage_.data()+offset+24,4));
                        return validTiming(t);
                    };
                    if (!get(44,frame.microphoneTiming) || !get(76,frame.referenceTiming)) return reject();
                    const auto count = code == 1 ? samples + referenceSamples : samples;
                    for (std::size_t i=0;i<count;++i) {
                        const auto v=std::bit_cast<float>(static_cast<std::uint32_t>(read(storage_.data()+headerBytes+4*i,4)));
                        if (!std::isfinite(v)) return reject();
                        if (code == 2) frame.output[i]=v;
                        else if (i<samples) frame.microphone[i]=v;
                        else frame.reference[i-samples]=v;
                    }
                } else {
                    for (std::size_t i=44;i<headerBytes;++i) if (storage_[i]) return reject();
                    closed_=true;
                }
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
} // namespace krisp_probe::aec_wire
