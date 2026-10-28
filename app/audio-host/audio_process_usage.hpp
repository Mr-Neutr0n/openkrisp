#pragma once
#include <CoreAudio/CoreAudio.h>
#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace labvoice {
struct AudioProcessApp { std::string name, binaryName, bundleID, version; std::vector<std::string> errors; };
struct AudioProcessReader {
    std::function<bool()> hasList;
    std::function<std::vector<AudioObjectID>(AudioObjectID, UInt32, UInt32)> array;
    std::function<UInt32(AudioObjectID, UInt32)> scalar;
    std::function<std::string(AudioObjectID, UInt32)> text;
    std::function<std::optional<int>(int)> responsiblePID;
    std::function<AudioProcessApp(int)> app;
};
struct AudioUsedDevice { AudioObjectID objectID; std::optional<std::string> uid; std::optional<bool> hasInputStreams = std::nullopt; };
struct AudioProcessDirection {
    std::optional<bool> running;
    std::optional<std::vector<AudioUsedDevice>> devices;
};
struct AudioProcessUsage {
    AudioObjectID objectID;
    std::optional<int> actualPID, responsiblePID;
    std::optional<std::string> appName, processBundleID, responsibleBundleID, appID, appVersion;
    bool responsibleFallback = false;
    std::string responsibleResolution;
    AudioProcessDirection input, output;
    std::vector<std::string> errors;
};
struct AudioProcessSnapshot {
    std::string status;
    std::vector<AudioProcessUsage> processes;
    std::vector<std::string> errors;
};
AudioProcessSnapshot readAudioProcessUsage(const AudioProcessReader &reader);
std::string audioProcessUsageJSON(const AudioProcessSnapshot &snapshot);
AudioProcessSnapshot observeAudioProcessUsage();
}
