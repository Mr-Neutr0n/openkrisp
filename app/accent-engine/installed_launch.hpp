#pragma once

#include "worker_broker.hpp"
#include <stdexcept>
#include <unistd.h>

namespace accent_engine {
enum class Direction { outbound, inbound };
inline constexpr const char* addonSHA256 = "adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755";
inline constexpr const char* nodeSHA256 = "533bd644c5ae0e0ea3a80e433aad16b817447ccba1e1eea701875eac80cb75d4";
inline constexpr const char* homebrewNodeSHA256 = "1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040";
inline constexpr const char* outboundModelSHA256 = "8ada1e4c3d2b3ef3c1440e39dfdfb825c7b0a4c0695c9e0ba6b06b576f124855";
inline constexpr const char* inboundModelSHA256 = "73a59147ba88d0075e6a688f3cc641c5a46a6ffbb591c2f386b3affdb3e781df";
inline const char* directionName(Direction value) {
    switch (value) {
        case Direction::outbound: return "outbound";
        case Direction::inbound: return "inbound";
    }
    throw std::invalid_argument("Unknown accent direction");
}
inline const char* modelSHA256(Direction value) {
    switch (value) {
        case Direction::outbound: return outboundModelSHA256;
        case Direction::inbound: return inboundModelSHA256;
    }
    throw std::invalid_argument("Unknown accent direction");
}
struct InstalledAccentSettings {
    std::string nodePath, workerPath, addonPath, modelPath, adapterPath, libraryPath;
    std::string adapterSha256;
    std::string nodeSha256 = nodeSHA256;
    Direction direction = Direction::outbound;
};
namespace launch_detail {
inline void path(const std::string& value) {
    if (value.empty() || value.front() != '/' || value.find('\0') != std::string::npos)
        throw std::invalid_argument("Expected absolute accent path without NUL");
}
inline void digest(const std::string& value) {
    if (value.size() != 64 || value.find_first_not_of("0123456789abcdef") != std::string::npos)
        throw std::invalid_argument("Expected accent SHA256");
}
inline std::string json(const std::string& value) {
    constexpr char hex[] = "0123456789abcdef";
    std::string result = "\"";
    for (unsigned char c : value) {
        if (c == '"' || c == '\\') { result += '\\'; result += static_cast<char>(c); }
        else if (c < 32) { result += "\\u00"; result += hex[c >> 4]; result += hex[c & 15]; }
        else result += static_cast<char>(c);
    }
    return result + '"';
}
inline std::string tokenHex(const wire::Token& token) {
    constexpr char hex[] = "0123456789abcdef";
    std::string result;
    for (auto c : token) { result += hex[c >> 4]; result += hex[c & 15]; }
    return result;
}
} // namespace launch_detail

// Fixed current AR identities and US target. No vendor files are copied.
// Caller validates packaged owned helper paths and keeps this off audio threads.
inline WorkerLaunchConfig buildInstalledAccentLaunch(const InstalledAccentSettings& settings, wire::Token token) {
    using namespace launch_detail;
    for (const auto* value : {&settings.nodePath, &settings.workerPath, &settings.addonPath,
                             &settings.modelPath, &settings.adapterPath, &settings.libraryPath}) path(*value);
    if (settings.libraryPath.find_first_of("\n\r:") != std::string::npos)
        throw std::invalid_argument("Expected one accent library directory");
    digest(settings.adapterSha256);
    if (settings.nodeSha256 != nodeSHA256 && settings.nodeSha256 != homebrewNodeSHA256)
        throw std::invalid_argument("Unreviewed accent Node SHA256");
    const std::string role = directionName(settings.direction), model = modelSHA256(settings.direction);
    const auto tokenText = tokenHex(token);
    const std::string config = "{\"parentPID\":" + std::to_string(getpid()) +
        ",\"direction\":" + json(role) + ",\"addonPath\":" + json(settings.addonPath) +
        ",\"modelPath\":" + json(settings.modelPath) + ",\"adapterPath\":" + json(settings.adapterPath) +
        ",\"adapterSHA256\":" + json(settings.adapterSha256) + ",\"nodeSHA256\":" + json(settings.nodeSha256) + ",\"token\":" + json(tokenText) + "}";
    WorkerLaunchConfig result;
    result.executable = "/usr/bin/sandbox-exec";
    result.arguments = {"-p", "(version 1) (allow default) (deny network*)", "/usr/bin/env", "-i",
        "PATH=/usr/bin:/bin", "DYLD_LIBRARY_PATH=" + settings.libraryPath,
        settings.nodePath, settings.workerPath, config};
    result.environment = {"PATH=/usr/bin:/bin"};
    result.expectedReadyLine = "OKARREADY1 " + tokenText + " accent-direct 48000 480 " + role + " us " +
        addonSHA256 + " " + model + " " + settings.adapterSha256 + " " + settings.nodeSha256 + "\n";
    result.token = token;
    result.startupTimeout = std::chrono::milliseconds(30000);
    result.frameTimeout = std::chrono::milliseconds(500);
    result.shutdownTimeout = std::chrono::milliseconds(1000);
    return result;
}
} // namespace accent_engine
