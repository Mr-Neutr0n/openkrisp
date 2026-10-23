// Link the production command parser to this route sink. No aggregate, worker,
// microphone or speaker can start in this test executable.
#include "route_cli.hpp"
#include "route_aec_ack.hpp"
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
    if(options.installedAEC) {
        std::cout << ",\"aec\":{\"worker\":"<<labvoice::jsonString(options.installedAEC->workerPath)
                  <<",\"worker_sha256\":"<<labvoice::jsonString(options.installedAEC->workerSha256)
                  <<",\"library\":"<<labvoice::jsonString(options.installedAEC->libraryPath)
                  <<",\"library_sha256\":"<<labvoice::jsonString(krisp_probe::installedAECLibrarySHA256)<<'}';
        std::cout << ",\"aec_startup\":{\"microphone_provider\":\"installed-krisp-aec\""
                  <<labvoice::aecStartupFields(*options.installedAEC,5760,4096,2)<<'}';
    }
    std::cout << "}\n";
    return 0;
}
namespace labvoice {
int runMicrophoneTest(const std::string&, const std::string&, const std::string&, bool) { return 64; }
}
