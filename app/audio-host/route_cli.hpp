#pragma once
#include "controls.hpp"
#include "../native-model-probe/installed_worker_launch.hpp"
#include <optional>
#include <string>
struct RouteControlOptions {
    bool stdinEnabled = false;
    std::string operationID;
    labvoice::ControlSnapshot initial;
};
struct RouteProviderOptions {
    std::optional<krisp_probe::InstalledWorkerSettings> installed;
};
int runRoute(const std::string &input, const std::string &output, bool microphoneNoise,
             bool speakerNoise, const RouteControlOptions &controls = {},
             const RouteProviderOptions &provider = {});
