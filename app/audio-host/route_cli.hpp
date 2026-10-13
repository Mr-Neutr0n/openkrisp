#pragma once
#include "controls.hpp"
#include <string>
struct RouteControlOptions {
    bool stdinEnabled = false;
    std::string operationID;
    labvoice::ControlSnapshot initial;
};
int runRoute(const std::string &input, const std::string &output, bool microphoneNoise,
             bool speakerNoise, const RouteControlOptions &controls = {});
