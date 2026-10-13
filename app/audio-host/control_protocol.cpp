#include "control_protocol.hpp"
#include <cerrno>
#include <charconv>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <map>
#include <sstream>
#include <stdexcept>
#include <variant>

namespace labvoice {
namespace {
struct Number {
    std::string text;
};
struct JSON {
    using Object = std::map<std::string, JSON>;
    std::variant<bool, std::string, Number, Object> value;
};
class Parser {
    std::string_view source_;
    size_t at_ = 0;
    [[noreturn]] void fail() { throw std::runtime_error("invalid_json"); }
    void spaces() {
        while (at_ < source_.size() && (source_[at_] == ' ' || source_[at_] == '\t' ||
                                        source_[at_] == '\r' || source_[at_] == '\n'))
            ++at_;
    }
    bool take(char c) {
        spaces();
        if (at_ < source_.size() && source_[at_] == c) {
            ++at_;
            return true;
        }
        return false;
    }
    std::string string() {
        if (!take('"'))
            fail();
        std::string value;
        while (at_ < source_.size()) {
            unsigned char c = source_[at_++];
            if (c == '"')
                return value;
            if (c < 32)
                fail();
            if (c == '\\') {
                if (at_ == source_.size())
                    fail();
                c = source_[at_++];
                switch (c) {
                case '"':
                case '\\':
                case '/':
                    break;
                case 'b':
                    c = '\b';
                    break;
                case 'f':
                    c = '\f';
                    break;
                case 'n':
                    c = '\n';
                    break;
                case 'r':
                    c = '\r';
                    break;
                case 't':
                    c = '\t';
                    break;
                case 'u': {
                    unsigned code = 0;
                    for (int i = 0; i < 4; ++i) {
                        if (at_ == source_.size())
                            fail();
                        const char h = source_[at_++];
                        code *= 16;
                        if (h >= '0' && h <= '9')
                            code += h - '0';
                        else if (h >= 'a' && h <= 'f')
                            code += h - 'a' + 10;
                        else if (h >= 'A' && h <= 'F')
                            code += h - 'A' + 10;
                        else
                            fail();
                    }
                    if (code > 127)
                        fail();
                    c = static_cast<unsigned char>(code);
                    break;
                }
                default:
                    fail();
                }
            }
            value += c;
        }
        fail();
    }
    Number number() {
        spaces();
        const size_t start = at_;
        if (at_ < source_.size() && source_[at_] == '-')
            ++at_;
        if (at_ == source_.size())
            fail();
        if (source_[at_] == '0')
            ++at_;
        else {
            if (source_[at_] < '1' || source_[at_] > '9')
                fail();
            while (at_ < source_.size() && source_[at_] >= '0' && source_[at_] <= '9')
                ++at_;
        }
        if (at_ < source_.size() && source_[at_] == '.') {
            ++at_;
            size_t first = at_;
            while (at_ < source_.size() && source_[at_] >= '0' && source_[at_] <= '9')
                ++at_;
            if (first == at_)
                fail();
        }
        if (at_ < source_.size() && (source_[at_] == 'e' || source_[at_] == 'E')) {
            ++at_;
            if (at_ < source_.size() && (source_[at_] == '+' || source_[at_] == '-'))
                ++at_;
            size_t first = at_;
            while (at_ < source_.size() && source_[at_] >= '0' && source_[at_] <= '9')
                ++at_;
            if (first == at_)
                fail();
        }
        return {std::string(source_.substr(start, at_ - start))};
    }
    JSON value(unsigned depth) {
        if (depth > 3)
            fail();
        spaces();
        if (at_ == source_.size())
            fail();
        if (source_[at_] == '{') {
            ++at_;
            JSON::Object object;
            if (take('}'))
                return {std::move(object)};
            do {
                auto key = string();
                if (!take(':'))
                    fail();
                auto item = value(depth + 1);
                if (!object.emplace(std::move(key), std::move(item)).second)
                    throw std::runtime_error("duplicate_field");
                if (take('}'))
                    return {std::move(object)};
            } while (take(','));
            fail();
        }
        if (source_[at_] == '"')
            return {string()};
        if (source_.substr(at_, 4) == "true") {
            at_ += 4;
            return {true};
        }
        if (source_.substr(at_, 5) == "false") {
            at_ += 5;
            return {false};
        }
        return {number()};
    }

  public:
    explicit Parser(std::string_view source) : source_(source) {}
    JSON parse() {
        auto result = value(0);
        spaces();
        if (at_ != source_.size())
            fail();
        return result;
    }
};
const JSON::Object &object(const JSON &value) {
    auto result = std::get_if<JSON::Object>(&value.value);
    if (!result)
        throw std::runtime_error("invalid_schema");
    return *result;
}
const JSON &field(const JSON::Object &value, const char *key) {
    auto found = value.find(key);
    if (found == value.end())
        throw std::runtime_error("missing_field");
    return found->second;
}
std::string text(const JSON &value) {
    auto result = std::get_if<std::string>(&value.value);
    if (!result)
        throw std::runtime_error("invalid_schema");
    return *result;
}
uint64_t sequence(const JSON &value) {
    auto result = std::get_if<Number>(&value.value);
    if (!result)
        throw std::runtime_error("invalid_sequence");
    uint64_t number = 0;
    const auto parse =
        std::from_chars(result->text.data(), result->text.data() + result->text.size(), number);
    if (parse.ec != std::errc{} || parse.ptr != result->text.data() + result->text.size() ||
        !number || number > maximumControlSequence)
        throw std::runtime_error("invalid_sequence");
    return number;
}
PathControl path(const JSON &value) {
    const auto &fields = object(value);
    if (fields.size() != 2 || !fields.count("muted") || !fields.count("gain"))
        throw std::runtime_error("invalid_path_schema");
    const auto *muted = std::get_if<bool>(&field(fields, "muted").value);
    const auto *number = std::get_if<Number>(&field(fields, "gain").value);
    float gain = 0;
    if (!muted || !number || !parseGain(number->text, gain))
        throw std::runtime_error("invalid_path_control");
    return {gain, *muted};
}
std::string ack(const std::string &operation, uint64_t seq, bool accepted, const std::string &error,
                const ControlSnapshot *value) {
    std::ostringstream out;
    out << "{\"type\":\"controls-ack\",\"operationID\":" << jsonString(operation)
        << ",\"sequence\":" << seq << ",\"accepted\":" << (accepted ? "true" : "false");
    if (accepted)
        out << ",\"publication\":\"next-callback\"," << controlJSON(*value);
    else
        out << ",\"error\":" << jsonString(error);
    out << '}';
    return out.str();
}
} // namespace
bool validOperationID(std::string_view value) noexcept {
    if (value.size() != 36)
        return false;
    for (size_t i = 0; i < value.size(); ++i) {
        const char c = value[i];
        if (i == 8 || i == 13 || i == 18 || i == 23) {
            if (c != '-')
                return false;
        } else if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')))
            return false;
    }
    return true;
}
bool parseGain(std::string_view value, float &gain) noexcept {
    if (value.empty() || value.size() > 64)
        return false;
    // Caller supplies a JSON numeric token; reject whitespace and nonnumeric CLI forms too.
    for (char c : value)
        if (!((c >= '0' && c <= '9') || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E'))
            return false;
    char copy[65]{};
    std::memcpy(copy, value.data(), value.size());
    char *end = nullptr;
    errno = 0;
    const double number = std::strtod(copy, &end);
    if (end != copy + value.size() || errno == ERANGE || !std::isfinite(number) || number < 0 ||
        number > 1)
        return false;
    gain = number == 0 ? 0 : static_cast<float>(number);
    return std::isfinite(gain);
}
std::string jsonString(std::string_view value) {
    std::string result = "\"";
    const char *hex = "0123456789abcdef";
    for (unsigned char c : value) {
        if (c == '"' || c == '\\') {
            result += '\\';
            result += c;
        } else if (c < 32) {
            result += "\\u00";
            result += hex[c >> 4];
            result += hex[c & 15];
        } else
            result += c;
    }
    return result + '"';
}
std::string controlJSON(const ControlSnapshot &value) {
    std::ostringstream out;
    out << std::setprecision(17);
    out << "\"microphone\":{\"muted\":" << (value.microphone.muted ? "true" : "false")
        << ",\"gain\":" << double(value.microphone.gain)
        << "},\"speaker\":{\"muted\":" << (value.speaker.muted ? "true" : "false")
        << ",\"gain\":" << double(value.speaker.gain) << '}';
    return out.str();
}
ControlProtocol::ControlProtocol(std::string operation) : operation_(std::move(operation)) {
    if (!validOperationID(operation_))
        throw std::invalid_argument("Invalid operation UUID");
}
std::string ControlProtocol::handle(std::string_view line,
                                    const std::function<bool(const ControlSnapshot &)> &publish) {
    std::string operation = operation_;
    uint64_t seq = 0;
    try {
        if (line.size() > maximumControlLine)
            throw std::runtime_error("line_too_long");
        auto parsed = Parser(line).parse();
        const auto &fields = object(parsed);
        // Extract valid correlation before reporting the remaining schema errors.
        operation = text(field(fields, "operationID"));
        seq = sequence(field(fields, "sequence"));
        if (fields.size() != 5 || !fields.count("type") || !fields.count("microphone") ||
            !fields.count("speaker"))
            throw std::runtime_error("invalid_schema");
        if (text(field(fields, "type")) != "controls")
            throw std::runtime_error("invalid_type");
        if (!validOperationID(operation) || operation != operation_)
            throw std::runtime_error("wrong_operation");
        if (seq <= lastSequence_)
            throw std::runtime_error("stale_sequence");
        lastSequence_ = seq;
        ControlSnapshot value{path(field(fields, "microphone")), path(field(fields, "speaker"))};
        if (!publish(value))
            throw std::runtime_error("route_not_running");
        return ack(operation, seq, true, "", &value);
    } catch (const std::exception &e) {
        return ack(operation, seq, false, e.what(), nullptr);
    }
}
std::string ControlProtocol::reject(const std::string &error) const {
    return ack(operation_, 0, false, error, nullptr);
}
std::string RecordingProtocol::handle(std::string_view line,
    const std::function<std::string(const std::string &, const std::string &, const std::string &)> &apply) {
    std::string operation = operation_, id, action;
    uint64_t seq = 0;
    std::string error;
    try {
        if (line.size() > maximumControlLine) throw std::runtime_error("line_too_long");
        auto parsed = Parser(line).parse();
        const auto &fields = object(parsed);
        auto type = text(field(fields, "type"));
        if (!type.starts_with("recording-")) return {};
        action = type.substr(10);
        operation = text(field(fields, "operationID"));
        seq = sequence(field(fields, "sequence"));
        id = text(field(fields, "recordingID"));
        if (action != "start" && action != "stop" && action != "pause" && action != "resume")
            throw std::runtime_error("invalid_recording_action");
        if (fields.size() != (action == "start" ? 5 : 4)) throw std::runtime_error("invalid_schema");
        if (operation != operation_ || !validOperationID(operation)) throw std::runtime_error("wrong_operation");
        if (!validOperationID(id)) throw std::runtime_error("invalid_recording_id");
        if (seq <= lastSequence_) throw std::runtime_error("stale_sequence");
        lastSequence_ = seq;
        auto file = action == "start" ? text(field(fields, "path")) : std::string{};
        error = apply(action, id, file);
    } catch (const std::exception &e) { error = e.what(); }
    std::ostringstream out;
    out << "{\"type\":\"recording-ack\",\"operationID\":" << jsonString(operation)
        << ",\"sequence\":" << seq << ",\"recordingID\":" << jsonString(id)
        << ",\"action\":" << jsonString(action) << ",\"accepted\":" << (error.empty() ? "true" : "false");
    if (!error.empty()) out << ",\"error\":" << jsonString(error);
    out << '}';
    return out.str();
}
std::string MicrophoneTestProtocol::handle(std::string_view line,
    const std::function<std::string(bool)> &apply) {
    std::string operation = operation_, action, error;
    uint64_t seq = 0;
    try {
        if (line.size() > maximumControlLine) throw std::runtime_error("line_too_long");
        auto parsed = Parser(line).parse();
        const auto &fields = object(parsed);
        operation = text(field(fields, "operationID"));
        seq = sequence(field(fields, "sequence"));
        auto type = text(field(fields, "type"));
        if (fields.size() != 3 || (type != "test-stop" && type != "test-cancel"))
            throw std::runtime_error("invalid_schema");
        action = type == "test-stop" ? "stop" : "cancel";
        if (!validOperationID(operation) || operation != operation_) throw std::runtime_error("wrong_operation");
        if (seq <= lastSequence_) throw std::runtime_error("stale_sequence");
        lastSequence_ = seq;
        error = apply(action == "cancel");
    } catch (const std::exception &failure) { error = failure.what(); }
    std::string result = "{\"type\":\"test-ack\",\"operationID\":" + jsonString(operation) +
        ",\"sequence\":" + std::to_string(seq) + ",\"action\":" + jsonString(action) +
        ",\"accepted\":" + (error.empty() ? "true" : "false");
    if (!error.empty()) result += ",\"error\":" + jsonString(error);
    return result + "}";
}
bool ControlFramer::append(std::string_view chunk) {
    if (!needsRead() || chunk.size() > maximumControlLine)
        return false;
    pending_.assign(chunk);
    position_ = 0;
    return true;
}
std::vector<InputLine> ControlFramer::take(size_t limit) {
    std::vector<InputLine> result;
    while (position_ < pending_.size() && result.size() < limit) {
        const char c = pending_[position_++];
        if (c == '\n') {
            if (discarding_)
                result.push_back({{}, "line_too_long"});
            else
                result.push_back({std::move(partial_), {}});
            partial_.clear();
            discarding_ = false;
        } else if (!discarding_) {
            if (partial_.size() == maximumControlLine) {
                partial_.clear();
                discarding_ = true;
            } else
                partial_ += c;
        }
    }
    if (ended_ && position_ == pending_.size() && result.size() < limit &&
        (discarding_ || !partial_.empty())) {
        result.push_back({{}, discarding_ ? "line_too_long" : "truncated_at_eof"});
        partial_.clear();
        discarding_ = false;
    }
    return result;
}
} // namespace labvoice
