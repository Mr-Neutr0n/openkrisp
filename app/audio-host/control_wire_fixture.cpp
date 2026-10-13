// Test-only executable. Uses the real protocol and atomic state, no CoreAudio.
#include "control_protocol.hpp"
#include <cassert>
#include <cerrno>
#include <iostream>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc != 2 || !labvoice::validOperationID(argv[1]))
        return 64;
    labvoice::ControlProtocol protocol(argv[1]);
    labvoice::AtomicControls controls;
    labvoice::ControlFramer input;
    while (!input.ended()) {
        if (input.needsRead()) {
            char buffer[labvoice::maximumControlLine];
            const auto count = read(STDIN_FILENO, buffer, sizeof buffer);
            if (count > 0)
                input.append(std::string_view(buffer, size_t(count)));
            else if (count == 0)
                input.finish();
            else if (errno != EINTR)
                return 1;
        }
        for (const auto &line : input.take()) {
            const auto ack =
                line.error.empty()
                    ? protocol.handle(line.text,
                                      [&](const auto &value) {
                                          const bool accepted = controls.publish(value);
                                          assert(!accepted || controls.load() == value);
                                          return accepted;
                                      })
                    : protocol.reject(line.error);
            std::cout << ack << std::endl;
        }
    }
}
