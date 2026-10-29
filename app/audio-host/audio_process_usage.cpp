#include "audio_process_usage.hpp"
#include <exception>
#include <set>
#include <stdexcept>

namespace labvoice {
namespace {
std::string quote(const std::string &text) {
    std::string result = "\"";
    const char *digits = "0123456789abcdef";
    for (unsigned char c : text) {
        if (c == '"' || c == '\\') { result += '\\'; result += c; }
        else if (c < 32) { result += "\\u00"; result += digits[c >> 4]; result += digits[c & 15]; }
        else result += c;
    }
    return result + '"';
}
std::string strings(const std::vector<std::string>& values) {
    std::string out = "["; bool comma = false;
    for (const auto& value : values) { if (comma) out += ','; comma = true; out += quote(value); }
    return out + ']';
}
std::string text(const std::optional<std::string>& value) { return value ? quote(*value) : "null"; }
std::string pid(const std::optional<int>& value) { return value ? std::to_string(*value) : "null"; }
std::string direction(const AudioProcessDirection &value) {
    std::string out = "{\"running\":" + std::string(value.running ? (*value.running ? "true" : "false") : "null") + ",\"devices\":";
    if (!value.devices) return out + "null}";
    out += '['; bool comma = false;
    for (const auto& device : *value.devices) {
        if (comma) out += ','; comma = true;
        out += "{\"object_id\":" + std::to_string(device.objectID) + ",\"uid\":" + text(device.uid) + ",\"has_input_streams\":" + (device.hasInputStreams ? (*device.hasInputStreams ? "true" : "false") : "null") + '}';
    }
    return out + "]}";
}
}
AudioProcessSnapshot readAudioProcessUsage(const AudioProcessReader &reader) {
    AudioProcessSnapshot result{"unavailable", {}, {}};
    if (!reader.hasList()) { result.errors.push_back("CoreAudio process-object list is unavailable on this system."); return result; }
    std::vector<AudioObjectID> ids;
    try { ids = reader.array(kAudioObjectSystemObject, kAudioHardwarePropertyProcessObjectList, kAudioObjectPropertyScopeGlobal); }
    catch (const std::exception& error) { result.status = "failed"; result.errors.push_back(error.what()); return result; }
    if (ids.size() > 1024) { result.status = "failed"; result.errors.push_back("Process count exceeds 1024 snapshot bound."); return result; }
    result.status = "available";
    size_t textBudget = 262144, deviceBudget = 4096;
    const auto readText = [&](AudioObjectID id, UInt32 selector) {
        auto value = reader.text(id, selector);
        if (value.size() > 4096 || value.size() > textBudget) throw std::runtime_error("Snapshot text bound exceeded.");
        textBudget -= value.size(); return value;
    };
    for (auto id : ids) {
        AudioProcessUsage process{}; process.objectID = id;
        try {
            if (reader.scalar(id, kAudioObjectPropertyClass) != kAudioProcessClassID) throw std::runtime_error("Object is not an audio process.");
            auto actual = reader.scalar(id, kAudioProcessPropertyPID);
            if (actual == 0 || actual > 2147483647) throw std::runtime_error("Process PID is missing or invalid.");
            process.actualPID = static_cast<int>(actual);
            const auto responsible = reader.responsiblePID(*process.actualPID);
            process.responsibleFallback = !responsible || *responsible <= 0;
            process.responsibleResolution = !responsible ? "actual_pid_symbol_unavailable" : *responsible <= 0 ? "actual_pid_nonpositive_result" : "responsibility_lookup";
            process.responsiblePID = process.responsibleFallback ? process.actualPID : responsible;
            auto app = reader.app(*process.responsiblePID);
            bool nameInvalid = false, bundleInvalid = false, versionInvalid = false;
            for (const auto& error : app.errors) {
                nameInvalid = nameInvalid || error.rfind("app_name:", 0) == 0;
                bundleInvalid = bundleInvalid || error.rfind("responsible_bundle_id:", 0) == 0;
                versionInvalid = versionInvalid || error.rfind("app_version:", 0) == 0;
            }
            for (auto field : {&app.name, &app.binaryName, &app.bundleID, &app.version}) {
                if (field->size() > 4096 || field->size() > textBudget) {
                    nameInvalid = nameInvalid || field == &app.name;
                    bundleInvalid = bundleInvalid || field == &app.bundleID;
                    versionInvalid = versionInvalid || field == &app.version;
                    field->clear(); process.errors.push_back("Application metadata exceeds snapshot text bound.");
                }
                else textBudget -= field->size();
            }
            process.errors.insert(process.errors.end(), app.errors.begin(), app.errors.end());
            const auto name = nameInvalid ? std::string() : app.name.empty() ? app.binaryName : app.name;
            if (!name.empty()) process.appName = name;
            else process.errors.push_back("Application name is unavailable.");
            if (!versionInvalid) process.appVersion = app.version;
            std::optional<std::string> bundle;
            try { bundle = readText(id, kAudioProcessPropertyBundleID); process.processBundleID = bundle; }
            catch (const std::exception& error) { process.errors.push_back(std::string("process_bundle_id: ") + error.what()); }
            // An observed empty process bundle uses the resolved application name.
            // A failed property read remains unknown rather than inventing emptiness.
            if (bundle && bundle->empty()) bundle = process.appName;
            if (*process.actualPID != *process.responsiblePID && bundleInvalid) process.responsibleBundleID = std::nullopt;
            else if (*process.actualPID != *process.responsiblePID && !app.bundleID.empty()) process.responsibleBundleID = app.bundleID;
            else process.responsibleBundleID = bundle;
            process.appID = process.responsibleBundleID;
        } catch (const std::exception& error) { process.errors.push_back(std::string("identity: ") + error.what()); }
        if (process.actualPID) {
            const auto load = [&](UInt32 selector, UInt32 scope, const char* label, AudioProcessDirection& value) {
                try {
                    auto running = reader.scalar(id, selector);
                    if (running > 1) throw std::runtime_error("Unexpected running flag.");
                    value.running = running == 1;
                    if (!*value.running) { value.devices = std::vector<AudioUsedDevice>{}; return; }
                    const auto devices = reader.array(id, kAudioProcessPropertyDevices, scope);
                    if (devices.size() > 256 || devices.size() > deviceBudget) throw std::runtime_error("Device count exceeds per-process or total snapshot bound.");
                    deviceBudget -= devices.size();
                    value.devices = std::vector<AudioUsedDevice>{};
                    std::set<AudioObjectID> seen;
                    for (auto device : devices) {
                        if (!seen.insert(device).second) continue;
                        AudioUsedDevice used{device, std::nullopt};
                        try { auto uid = readText(device, kAudioDevicePropertyDeviceUID); if (uid.empty()) throw std::runtime_error("Empty UID."); used.uid = uid; }
                        catch (const std::exception& error) { process.errors.push_back(std::string(label) + " device " + std::to_string(device) + ": " + error.what()); }
                        if (scope == kAudioObjectPropertyScopeInput) {
                            try {
                                const auto streams = reader.array(device, kAudioDevicePropertyStreams, kAudioObjectPropertyScopeInput);
                                if (streams.size() > 4096) throw std::runtime_error("Input stream count exceeds snapshot bound.");
                                used.hasInputStreams = !streams.empty();
                            } catch (const std::exception& error) { process.errors.push_back("input device " + std::to_string(device) + " streams: " + error.what()); }
                        }
                        value.devices->push_back(used);
                    }
                } catch (const std::exception& error) { process.errors.push_back(std::string(label) + ": " + error.what()); }
            };
            load(kAudioProcessPropertyIsRunningInput, kAudioObjectPropertyScopeInput, "input", process.input);
            load(kAudioProcessPropertyIsRunningOutput, kAudioObjectPropertyScopeOutput, "output", process.output);
        }
        result.processes.push_back(process);
    }
    return result;
}
std::string audioProcessUsageJSON(const AudioProcessSnapshot &snapshot, bool* boundsFailed) {
    if(boundsFailed)*boundsFailed=false;
    std::string out = "{\"status\":" + quote(snapshot.status) + ",\"errors\":" + strings(snapshot.errors) + ",\"processes\":[";
    bool comma = false;
    for (const auto& process : snapshot.processes) {
        if (out.size() > 524288) {if(boundsFailed)*boundsFailed=true;return "{\"status\":\"failed\",\"processes\":[],\"errors\":[\"Audio-use JSON exceeds 512 KiB snapshot bound.\"]}";}
        if (comma) out += ','; comma = true;
        out += "{\"object_id\":" + std::to_string(process.objectID) + ",\"actual_pid\":" + pid(process.actualPID) +
            ",\"responsible_pid\":" + pid(process.responsiblePID) + ",\"responsible_pid_fallback\":" + (process.responsibleFallback ? "true" : "false") +
            ",\"responsible_pid_resolution\":" + quote(process.responsibleResolution) + ",\"app_name\":" + text(process.appName) + ",\"app_version\":" + text(process.appVersion) +
            ",\"process_bundle_id\":" + text(process.processBundleID) + ",\"responsible_bundle_id\":" + text(process.responsibleBundleID) +
            ",\"app_id\":" + text(process.appID) + ",\"input\":" + direction(process.input) + ",\"output\":" + direction(process.output) + ",\"errors\":" + strings(process.errors);
        if(process.usageStale)out += ",\"usage_stale\":" + std::string(*process.usageStale ? "true":"false");
        if(process.stabilizationPending)out += ",\"stabilization_pending\":" + std::string(*process.stabilizationPending ? "true":"false");
        out += '}';
    }
    out += "]}";
    if (out.size() > 524288) {if(boundsFailed)*boundsFailed=true;return "{\"status\":\"failed\",\"processes\":[],\"errors\":[\"Audio-use JSON exceeds 512 KiB snapshot bound.\"]}";}
    return out;
}
}
