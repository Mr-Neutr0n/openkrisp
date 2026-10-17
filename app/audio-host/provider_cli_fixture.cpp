// Link the production command parser to this route sink. No aggregate, worker,
// microphone or speaker can start in this test executable.
#include "route_cli.hpp"
#include "control_protocol.hpp"
#include <iostream>
int runRoute(const std::string&, const std::string&, bool microphone, bool speaker,
             const RouteControlOptions&, const RouteProviderOptions& options) {
    const auto lane = [](const auto& value) {
        if (!value) { std::cout << "null"; return; }
        std::cout << "{\"role\":" << labvoice::jsonString(krisp_probe::installedModelRoleName(value->modelRole))
                  << ",\"model_sha256\":" << labvoice::jsonString(value->modelSha256)
                  << ",\"node\":" << labvoice::jsonString(value->nodePath)
                  << ",\"model\":" << labvoice::jsonString(value->modelPath) << '}';
    };
    std::cout << "{\"microphone_noise\":" << (microphone ? "true" : "false")
              << ",\"speaker_noise\":" << (speaker ? "true" : "false") << ",\"microphone\":";
    lane(options.installed); std::cout << ",\"speaker\":"; lane(options.installedSpeaker);
    std::cout << "}\n";
    return 0;
}
namespace labvoice {
int runMicrophoneTest(const std::string&, const std::string&, const std::string&, bool) { return 64; }
}
