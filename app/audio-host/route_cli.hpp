#pragma once
#include "controls.hpp"
#include "../native-model-probe/installed_worker_launch.hpp"
#include "../native-model-probe/installed_aec_worker_launch.hpp"
#include "../accent-engine/installed_launch.hpp"
#include <optional>
#include <string>
struct RouteControlOptions {
    bool stdinEnabled = false;
    std::string operationID;
    labvoice::ControlSnapshot initial;
};
struct RouteProviderOptions {
    std::optional<accent_engine::InstalledAccentSettings> installedAccent;
    std::optional<krisp_probe::InstalledWorkerSettings> installed;
    std::optional<krisp_probe::InstalledWorkerSettings> installedSpeaker;
    std::optional<krisp_probe::InstalledAECWorkerSettings> installedAEC;
};
int runRoute(const std::string &input, const std::string &output, bool microphoneNoise,
             bool speakerNoise, const RouteControlOptions &controls = {},
             const RouteProviderOptions &provider = {});
