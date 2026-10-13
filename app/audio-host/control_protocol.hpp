#pragma once
#include "controls.hpp"
#include <functional>
#include <string>
#include <string_view>
#include <vector>

namespace labvoice {
constexpr uint64_t maximumControlSequence = 9007199254740991ULL;
constexpr size_t maximumControlLine = 4096;
bool validOperationID(std::string_view value) noexcept;
bool parseGain(std::string_view value, float &gain) noexcept;
std::string jsonString(std::string_view value);
std::string controlJSON(const ControlSnapshot &value);
class ControlProtocol {
    std::string operation_;
    uint64_t lastSequence_ = 0;

  public:
    explicit ControlProtocol(std::string operation);
    std::string handle(std::string_view line,
                       const std::function<bool(const ControlSnapshot &)> &publish);
    std::string reject(const std::string &error) const;
};
class RecordingProtocol {
    std::string operation_;
    uint64_t lastSequence_ = 0;
  public:
    explicit RecordingProtocol(std::string operation) : operation_(std::move(operation)) {}
    // Empty result means another command type; parser remains strict for recording commands.
    std::string handle(std::string_view,
        const std::function<std::string(const std::string &, const std::string &, const std::string &)> &);
};
class MicrophoneTestProtocol {
    std::string operation_;
    uint64_t lastSequence_ = 0;
  public:
    explicit MicrophoneTestProtocol(std::string operation) : operation_(std::move(operation)) {}
    std::string handle(std::string_view,
        const std::function<std::string(bool cancel)> &);
};
struct InputLine {
    std::string text;
    std::string error;
};
// At most one 4096-byte unread chunk plus one 4096-byte partial line. No queue.
// Drain a fixed number of complete commands before reading another chunk.
class ControlFramer {
    std::string pending_, partial_;
    size_t position_ = 0;
    bool discarding_ = false, ended_ = false;

  public:
    bool append(std::string_view chunk);
    std::vector<InputLine> take(size_t limit = 8);
    void finish() noexcept { ended_ = true; }
    bool needsRead() const noexcept { return position_ == pending_.size() && !ended_; }
    bool ended() const noexcept {
        return ended_ && position_ == pending_.size() && partial_.empty() && !discarding_;
    }
};
} // namespace labvoice
