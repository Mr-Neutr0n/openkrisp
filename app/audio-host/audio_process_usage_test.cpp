#include "audio_process_usage.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>
using namespace labvoice;
int main(int argc, char**) {
    int lists = 0, deviceReads = 0;
    bool supported = true, listFailure = false, inputFailure = false, bundleFailure = false, streamFailure = false;
    std::optional<int> responsible = 22;
    AudioProcessApp app{"Owner", "Binary", "owner.bundle", "", {}};
    AudioProcessReader reader;
    reader.hasList = [&] { return supported; };
    reader.array = [&](AudioObjectID id, UInt32 selector, UInt32 scope) {
        if (selector == kAudioHardwarePropertyProcessObjectList) { ++lists; if (listFailure) throw std::runtime_error("list failed"); return std::vector<AudioObjectID>{4}; }
        if (selector == kAudioDevicePropertyStreams) { assert(scope == kAudioObjectPropertyScopeInput); if (streamFailure) throw std::runtime_error("streams failed"); return id == 31 ? std::vector<AudioObjectID>{100} : std::vector<AudioObjectID>{}; }
        assert(id == 4 && selector == kAudioProcessPropertyDevices && scope == kAudioObjectPropertyScopeInput);
        ++deviceReads; return std::vector<AudioObjectID>{31, 32, 31};
    };
    reader.scalar = [&](AudioObjectID id, UInt32 selector) -> UInt32 {
        assert(id == 4);
        if (selector == kAudioObjectPropertyClass) return kAudioProcessClassID;
        if (selector == kAudioProcessPropertyPID) return 11;
        if (selector == kAudioProcessPropertyIsRunningInput) { if (inputFailure) throw std::runtime_error("input failed"); return 1; }
        assert(selector == kAudioProcessPropertyIsRunningOutput); return 0;
    };
    reader.text = [&](AudioObjectID id, UInt32 selector) -> std::string {
        if (id == 4) { assert(selector == kAudioProcessPropertyBundleID); if (bundleFailure) throw std::runtime_error("bundle failed"); return "process.bundle"; }
        assert(selector == kAudioDevicePropertyDeviceUID);
        if (id == 32) throw std::runtime_error("device vanished");
        assert(id == 31); return "dev.hari.labvoice.feed";
    };
    reader.responsiblePID = [&](int pid) { assert(pid == 11); return responsible; };
    reader.app = [&](int pid) { assert(pid == (responsible && *responsible > 0 ? *responsible : 11)); return app; };
    auto snapshot = readAudioProcessUsage(reader);
    const auto& process = snapshot.processes.at(0);
    assert(snapshot.status == "available" && process.actualPID == 11 && process.responsiblePID == 22);
    assert(!process.responsibleFallback && process.appName == "Owner" && process.processBundleID == "process.bundle" && process.appID == "owner.bundle");
    assert(process.input.running == true && process.input.devices->size() == 2);
    assert(process.input.devices->at(0).uid == "dev.hari.labvoice.feed" && !process.input.devices->at(1).uid);
    assert(process.input.devices->at(0).hasInputStreams == true && process.input.devices->at(1).hasInputStreams == false);
    assert(process.output.running == false && process.output.devices->empty() && deviceReads == 1);
    assert(!process.errors.empty());
    if (argc > 1) { std::cout << audioProcessUsageJSON(snapshot) << '\n'; return 0; }
    streamFailure = true;
    auto missingStreams = readAudioProcessUsage(reader).processes.at(0);
    assert(missingStreams.input.running == true && missingStreams.input.devices->at(0).uid == "dev.hari.labvoice.feed");
    assert(!missingStreams.input.devices->at(0).hasInputStreams && !missingStreams.errors.empty());
    assert(missingStreams.output.running == false && missingStreams.output.devices->empty());
    streamFailure = false;
    supported = false; const auto priorLists = lists;
    assert(readAudioProcessUsage(reader).status == "unavailable" && lists == priorLists);
    supported = true; listFailure = true;
    assert(readAudioProcessUsage(reader).status == "failed"); listFailure = false;
    responsible = std::nullopt; app.name = ""; app.bundleID = "";
    auto fallback = readAudioProcessUsage(reader).processes.at(0);
    assert(fallback.responsiblePID == 11 && fallback.responsibleFallback && fallback.appName == "Binary" && fallback.appID == "process.bundle");
    assert(fallback.responsibleResolution == "actual_pid_symbol_unavailable");
    responsible = -1; assert(readAudioProcessUsage(reader).processes.at(0).responsibleResolution == "actual_pid_nonpositive_result");
    inputFailure = true; const auto priorReads = deviceReads;
    auto unknown = readAudioProcessUsage(reader).processes.at(0);
    assert(!unknown.input.running && !unknown.input.devices && deviceReads == priorReads);
    bundleFailure = true; assert(!readAudioProcessUsage(reader).processes.at(0).appID);
    bundleFailure = false; inputFailure = false;
    reader.text = [](AudioObjectID, UInt32) { return std::string(); };
    assert(readAudioProcessUsage(reader).processes.at(0).appID == "Binary");
    reader.array = [](AudioObjectID, UInt32, UInt32) { return std::vector<AudioObjectID>(1025, 4); };
    assert(readAudioProcessUsage(reader).status == "failed");
    AudioProcessSnapshot huge{"available", {}, {}};
    for (int i = 0; i < 500; ++i) { AudioProcessUsage value{}; value.objectID = i; value.appName = std::string(4096, 'x'); huge.processes.push_back(value); }
    const auto bounded = audioProcessUsageJSON(huge);
    assert(bounded.size() < 524288 && bounded.find("\\\"status\\\":\\\"failed\\\"") == std::string::npos);
    assert(bounded.find("\"status\":\"failed\"") != std::string::npos);
    AudioProcessUsage controls{}; controls.objectID = 4; controls.input.running = true;
    controls.input.devices = std::vector<AudioUsedDevice>(64, {31, std::string(4096, '\x01')});
    const auto escaped = audioProcessUsageJSON({"available", {controls}, {}});
    assert(escaped.size() < 524288 && escaped.find("\"status\":\"failed\"") != std::string::npos);
    std::cout << "Audio-process snapshot synthetic tests passed.\n";
}
