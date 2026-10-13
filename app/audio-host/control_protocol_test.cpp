#include "control_protocol.hpp"
#include <cassert>
#include <iostream>
#include <limits>

using namespace labvoice;
namespace {
const std::string operation = "12345678-1234-1234-1234-123456789abc";
std::string command(uint64_t seq, const std::string &microphone = "{\"muted\":false,\"gain\":0.5}",
                    const std::string &speaker = "{\"muted\":true,\"gain\":0.25}",
                    const std::string &id = operation) {
    return "{\"type\":\"controls\",\"operationID\":" + jsonString(id) +
           ",\"sequence\":" + std::to_string(seq) + ",\"microphone\":" + microphone +
           ",\"speaker\":" + speaker + "}";
}
bool accepted(const std::string &reply) {
    return reply.find("\"accepted\":true") != std::string::npos;
}
void protocol() {
    ControlProtocol protocol(operation);
    ControlSnapshot state;
    int count = 0;
    bool live = true;
    auto publish = [&](const ControlSnapshot &value) {
        if (!live)
            return false;
        state = value;
        ++count;
        return true;
    };
    const auto first = protocol.handle(command(1), publish);
    assert(accepted(first) && first.find("\"publication\":\"next-callback\"") != std::string::npos);
    assert(state.microphone.gain == 0.5f && !state.microphone.muted &&
           state.speaker.gain == 0.25f && state.speaker.muted);
    assert(!accepted(protocol.handle(command(1), publish)) && count == 1);
    assert(!accepted(protocol.handle(command(2, "{\"muted\":false,\"gain\":2}"), publish)) &&
           count == 1);
    assert(!accepted(protocol.handle(command(2), publish)) &&
           count == 1); // Rejected payload consumes a valid correlated sequence.
    assert(!accepted(
        protocol.handle(command(3, "{\"muted\":false,\"gain\":1}", "{\"muted\":false,\"gain\":1}",
                                "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"),
                        publish)));
    assert(accepted(protocol.handle(command(3), publish)) &&
           count == 2); // Wrong operation did not advance our sequence.
    live = false;
    assert(!accepted(protocol.handle(command(4), publish)) && count == 2);
    live = true;
    assert(!accepted(protocol.handle(command(4), publish)));
    assert(accepted(protocol.handle(
        command(5, "{\"muted\":true,\"gain\":0}", "{\"muted\":false,\"gain\":1}"), publish)));
    for (const auto &gain : {"-1", "1.01", "1e999", "1e-999", "null", "NaN", "\"0.5\""}) {
        ControlProtocol isolated(operation);
        assert(!accepted(isolated.handle(
            command(1, std::string("{\"muted\":false,\"gain\":") + gain + "}"), publish)));
    }
    for (const auto &malformed :
         {"{}", "[1]", "true", "not json", "{\"sequence\":1,\"sequence\":2}"})
        assert(!accepted(protocol.handle(malformed, publish)));
    auto extra = command(6);
    extra.pop_back();
    extra += ",\"extra\":true}";
    assert(!accepted(protocol.handle(extra, publish)));
    auto duplicate = command(7);
    duplicate.pop_back();
    duplicate += ",\"sequence\":7}";
    assert(!accepted(protocol.handle(duplicate, publish)));
    assert(!accepted(
        protocol.handle(command(8, "{\"muted\":false,\"gain\":1,\"extra\":0}"), publish)));
    assert(!accepted(protocol.handle(command(maximumControlSequence + 1), publish)));
    ControlProtocol cap(operation);
    assert(accepted(cap.handle(command(maximumControlSequence), publish)));
    auto fractional = command(9);
    auto position = fractional.find("\"sequence\":9");
    fractional.replace(position, 12, "\"sequence\":9.0");
    assert(!accepted(protocol.handle(fractional, publish)));
    assert(!accepted(protocol.handle(std::string(maximumControlLine + 1, ' '), publish)));
    assert(protocol.reject("truncated_at_eof").find("\"sequence\":0") != std::string::npos);
    float gain = 0;
    assert(parseGain("0.35", gain) && gain == 0.35f);
    assert(!parseGain("NaN", gain));
    assert(!parseGain("1.5", gain));
    assert(validOperationID(operation) && !validOperationID("not-a-uuid"));
}
void framing() {
    ControlFramer split;
    const auto packet = command(1);
    assert(split.append(packet.substr(0, 17)));
    assert(split.take().empty());
    assert(split.append(packet.substr(17) + "\n"));
    auto lines = split.take();
    assert(lines.size() == 1 && lines[0].text == packet && lines[0].error.empty());
    split.finish();
    assert(split.ended());
    ControlFramer bounded;
    assert(bounded.append(std::string(maximumControlLine, 'a')));
    assert(bounded.take().empty());
    assert(bounded.append("x\n"));
    lines = bounded.take();
    assert(lines.size() == 1 && lines[0].error == "line_too_long");
    assert(bounded.append(command(2) + "\n"));
    lines = bounded.take();
    assert(lines.size() == 1 && lines[0].error.empty());
    ControlFramer partial;
    assert(partial.append(packet));
    assert(partial.take().empty());
    partial.finish();
    lines = partial.take();
    assert(lines.size() == 1 && lines[0].error == "truncated_at_eof" && partial.ended());
    ControlFramer backlog;
    std::string batch;
    for (int i = 0; i < 20; ++i)
        batch += "{}\n";
    assert(backlog.append(batch));
    assert(backlog.take().size() == 8);
    assert(!backlog.append(batch));
    assert(backlog.take().size() == 8);
    assert(backlog.take().size() == 4);
    assert(backlog.needsRead());
    assert(!backlog.append(std::string(maximumControlLine + 1, 'x')));
    ControlFramer eof;
    eof.finish();
    assert(eof.ended() && eof.take().empty());
}
} // namespace
int main() {
    protocol();
    framing();
    std::cout << "PASS: controls schema/sequence/operation/gain rejection, atomic publication ack, "
                 "bounded split/backlog framing and EOF. No real route started.\n";
}
