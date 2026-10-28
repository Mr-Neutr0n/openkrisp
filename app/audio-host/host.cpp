#include <set>
#include "control_protocol.hpp"
#include "device_metadata.hpp"
#include "audio_process_usage.hpp"
#include "audio_use_watch.hpp"
#include "route_cli.hpp"
#include "microphone_test.hpp"
#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
constexpr auto global = kAudioObjectPropertyScopeGlobal;
constexpr auto input = kAudioObjectPropertyScopeInput;
constexpr auto output = kAudioObjectPropertyScopeOutput;
constexpr const char *feedUID = "dev.hari.labvoice.feed";
constexpr const char *monitorUID = "dev.hari.labvoice.monitor";
std::string quote(const std::string &text) {
    std::string result = "\"";
    const char *digits = "0123456789abcdef";
    for (unsigned char c : text) {
        if (c == '"' || c == '\\') {
            result += '\\';
            result += c;
        } else if (c < 32) {
            result += "\\u00";
            result += digits[c >> 4];
            result += digits[c & 15];
        } else
            result += c;
    }
    return result + '"';
}
AudioObjectPropertyAddress address(UInt32 selector, UInt32 scope = global) {
    return {selector, scope, kAudioObjectPropertyElementMain};
}
void check(OSStatus status, const char *operation) {
    if (status != noErr)
        throw std::runtime_error(std::string(operation) + " OSStatus=" + std::to_string(status));
}
template <class T> T scalar(AudioObjectID id, UInt32 selector, UInt32 scope = global) {
    auto a = address(selector, scope);
    T result{};
    UInt32 bytes = sizeof result;
    check(AudioObjectGetPropertyData(id, &a, 0, nullptr, &bytes, &result), "property read");
    if (bytes != sizeof result)
        throw std::runtime_error("Unexpected scalar property size");
    return result;
}
std::vector<unsigned char> bytes(AudioObjectID id, UInt32 selector, UInt32 scope = global) {
    auto a = address(selector, scope);
    UInt32 size = 0;
    check(AudioObjectGetPropertyDataSize(id, &a, 0, nullptr, &size), "property size");
    if (size > 1048576)
        throw std::runtime_error("Property exceeds 1 MiB read bound");
    std::vector<unsigned char> result(size);
    if (size)
        check(AudioObjectGetPropertyData(id, &a, 0, nullptr, &size, result.data()), "array read");
    if (size > result.size())
        throw std::runtime_error("Property grew during read");
    result.resize(size);
    return result;
}
template <class T> std::vector<T> array(AudioObjectID id, UInt32 selector, UInt32 scope = global) {
    auto data = bytes(id, selector, scope);
    if (data.size() % sizeof(T))
        throw std::runtime_error("Unexpected array property size");
    std::vector<T> result(data.size() / sizeof(T));
    if (!data.empty())
        std::memcpy(result.data(), data.data(), data.size());
    return result;
}
std::string string(AudioObjectID id, UInt32 selector, UInt32 scope = global) {
    auto value = scalar<CFStringRef>(id, selector, scope);
    if (!value)
        throw std::runtime_error("Null string property");
    const auto count =
        CFStringGetMaximumSizeForEncoding(CFStringGetLength(value), kCFStringEncodingUTF8) + 1;
    std::vector<char> text(static_cast<size_t>(count));
    const bool success = CFStringGetCString(value, text.data(), count, kCFStringEncodingUTF8);
    CFRelease(value);
    if (!success)
        throw std::runtime_error("Invalid UTF-8 string property");
    return text.data();
}
AudioObjectID lookup(const std::string &uid) {
    auto value = CFStringCreateWithCString(nullptr, uid.c_str(), kCFStringEncodingUTF8);
    if (!value)
        throw std::runtime_error("Invalid UTF-8 UID");
    auto a = address(kAudioHardwarePropertyTranslateUIDToDevice);
    AudioObjectID result = kAudioObjectUnknown;
    UInt32 count = sizeof result;
    const auto status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, sizeof value,
                                                   &value, &count, &result);
    CFRelease(value);
    check(status, "UID translation");
    if (count != sizeof result)
        throw std::runtime_error("Unexpected UID translation size");
    return result;
}
UInt32 channelCount(AudioObjectID id, UInt32 scope) {
    const auto data = bytes(id, kAudioDevicePropertyStreamConfiguration, scope);
    if (data.size() < offsetof(AudioBufferList, mBuffers))
        throw std::runtime_error("Truncated buffer list");
    UInt32 buffers = 0;
    std::memcpy(&buffers, data.data(), sizeof buffers);
    if (buffers > (data.size() - offsetof(AudioBufferList, mBuffers)) / sizeof(AudioBuffer))
        throw std::runtime_error("Invalid buffer count");
    UInt32 channels = 0;
    for (UInt32 i = 0; i < buffers; ++i) {
        AudioBuffer buffer{};
        std::memcpy(&buffer,
                    data.data() + offsetof(AudioBufferList, mBuffers) + i * sizeof(AudioBuffer),
                    sizeof buffer);
        if (buffer.mNumberChannels > 4096 || channels > 4096 - buffer.mNumberChannels)
            throw std::runtime_error("Channel count exceeds 4096");
        channels += buffer.mNumberChannels;
    }
    return channels;
}
struct Direction {
    UInt32 channels = 0;
    std::vector<AudioStreamBasicDescription> current;
    std::vector<AudioStreamRangedDescription> available;
};
struct Device {
    AudioObjectID id = 0;
    std::string uid, name;
    labvoice::DeviceMetadata metadata;
    UInt32 transport = 0, clock = 0, alive = 0, buffer = 0;
    double rate = 0;
    std::vector<AudioValueRange> nominalRates;
    Direction capture, playback;
};
Direction inspectDirection(AudioObjectID id, UInt32 scope) {
    Direction result;
    result.channels = channelCount(id, scope);
    for (auto stream : array<AudioObjectID>(id, kAudioDevicePropertyStreams, scope)) {
        result.current.push_back(
            scalar<AudioStreamBasicDescription>(stream, kAudioStreamPropertyVirtualFormat));
        auto formats = array<AudioStreamRangedDescription>(
            stream, kAudioStreamPropertyAvailableVirtualFormats);
        result.available.insert(result.available.end(), formats.begin(), formats.end());
    }
    return result;
}
Device inspect(AudioObjectID id) {
    Device d;
    d.id = id;
    d.uid = string(id, kAudioDevicePropertyDeviceUID);
    d.name = string(id, kAudioObjectPropertyName);
    d.metadata = labvoice::readDeviceMetadata(d.name,[id](const AudioObjectPropertyAddress& a) {
        return string(id,a.mSelector,a.mScope);
    });
    d.transport = scalar<UInt32>(id, kAudioDevicePropertyTransportType);
    d.clock = scalar<UInt32>(id, kAudioDevicePropertyClockDomain);
    d.alive = scalar<UInt32>(id, kAudioDevicePropertyDeviceIsAlive);
    d.rate = scalar<Float64>(id, kAudioDevicePropertyNominalSampleRate);
    d.nominalRates = array<AudioValueRange>(id, kAudioDevicePropertyAvailableNominalSampleRates);
    d.buffer = scalar<UInt32>(id, kAudioDevicePropertyBufferFrameSize);
    if (!std::isfinite(d.rate) || d.rate <= 0)
        throw std::runtime_error("Invalid nominal rate");
    d.capture = inspectDirection(id, input);
    d.playback = inspectDirection(id, output);
    return d;
}
bool physical(UInt32 transport) {
    return transport != kAudioDeviceTransportTypeVirtual &&
           transport != kAudioDeviceTransportTypeAggregate &&
           transport != kAudioDeviceTransportTypeUnknown;
}
void formatJSON(const AudioStreamBasicDescription &f) {
    std::cout << "{\"rate\":" << f.mSampleRate << ",\"format_id\":" << f.mFormatID
              << ",\"flags\":" << f.mFormatFlags << ",\"channels\":" << f.mChannelsPerFrame
              << ",\"bits\":" << f.mBitsPerChannel << ",\"bytes_per_frame\":" << f.mBytesPerFrame
              << "}";
}
void directionJSON(const Direction &d) {
    std::cout << "{\"channels\":" << d.channels << ",\"current_formats\":[";
    bool comma = false;
    for (const auto &f : d.current) {
        if (comma)
            std::cout << ',';
        comma = true;
        formatJSON(f);
    }
    std::cout << "],\"available_formats\":[";
    comma = false;
    for (const auto &f : d.available) {
        if (comma)
            std::cout << ',';
        comma = true;
        std::cout << "{\"format\":";
        formatJSON(f.mFormat);
        std::cout << ",\"min_rate\":" << f.mSampleRateRange.mMinimum
                  << ",\"max_rate\":" << f.mSampleRateRange.mMaximum << "}";
    }
    std::cout << "]}";
}
void deviceJSON(const Device &d) {
    std::cout << "{\"id\":" << d.id << ",\"uid\":" << quote(d.uid) << ",\"name\":" << quote(d.name)
              << ",\"interface_name\":" << quote(d.metadata.interfaceName)
              << ",\"manufacturer\":" << quote(d.metadata.manufacturer)
              << ",\"model_id\":" << quote(d.metadata.modelId)
              << ",\"metadata_read_errors\":[";
    for(std::size_t i=0;i<d.metadata.warnings.size();++i) {
        if(i)std::cout<<',';
        std::cout<<quote(d.metadata.warnings[i]);
    }
    std::cout << ']' << ",\"transport\":" << d.transport << ",\"clock_domain\":" << d.clock
              << ",\"alive\":" << d.alive << ",\"nominal_rate\":" << d.rate
              << ",\"buffer_frames\":" << d.buffer << ",\"input\":";
    directionJSON(d.capture);
    std::cout << ",\"output\":";
    directionJSON(d.playback);
    std::cout << ",\"available_nominal_rates\":[";
    bool comma = false;
    for (const auto &range : d.nominalRates) {
        if (comma)
            std::cout << ',';
        comma = true;
        std::cout << "{\"min\":" << range.mMinimum << ",\"max\":" << range.mMaximum << '}';
    }
    std::cout << "]}";
}
bool nativeFloat(const Direction &d, UInt32 channels) {
    if (d.channels != channels || d.current.size() != 1)
        return false;
    const auto &f = d.current.front();
    return f.mSampleRate == 48000 && f.mFormatID == kAudioFormatLinearPCM &&
           f.mFormatFlags == (kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked) &&
           f.mChannelsPerFrame == channels && f.mBitsPerChannel == 32 &&
           f.mBytesPerFrame == channels * 4 && f.mFramesPerPacket == 1 &&
           f.mBytesPerPacket == channels * 4;
}
void list(bool observeAudioUse = false) {
    std::cout << "{\"operation\":\"read_only_inventory\",\"devices\":[";
    bool comma = false;
    std::vector<std::string> errors;
    for (auto id : array<AudioObjectID>(kAudioObjectSystemObject, kAudioHardwarePropertyDevices)) {
        try {
            // Inspect physical devices and our own endpoints only. Other virtual drivers are
            // excluded.
            auto transport = scalar<UInt32>(id, kAudioDevicePropertyTransportType);
            if (!physical(transport))
                continue;
            auto d = inspect(id);
            if (comma)
                std::cout << ',';
            comma = true;
            deviceJSON(d);
        } catch (const std::exception &e) {
            errors.push_back("device " + std::to_string(id) + ": " + e.what());
        }
    }
    std::cout << "],\"companion_devices\":[";
    comma = false;
    for (auto uid : {feedUID, monitorUID}) {
        if (comma)
            std::cout << ',';
        comma = true;
        try {
            auto id = lookup(uid);
            std::cout << "{\"uid\":" << quote(uid) << ",\"present\":" << (id ? "true" : "false");
            if (id) {
                std::cout << ",\"device\":";
                deviceJSON(inspect(id));
            }
            std::cout << '}';
        } catch (const std::exception &e) {
            throw std::runtime_error(std::string("companion lookup: ") + e.what());
        }
    }
    std::cout << "],\"errors\":[";
    comma = false;
    for (const auto &e : errors) {
        if (comma)
            std::cout << ',';
        comma = true;
        std::cout << quote(e);
    }
    std::cout << ']';
    if (observeAudioUse) std::cout << ",\"audio_process_usage\":" << labvoice::audioProcessUsageJSON(labvoice::observeAudioProcessUsage());
    std::cout << "}\n";
}
int plan(const std::string &inputUID, const std::string &outputUID) {
    std::vector<std::string> blockers;
    std::vector<Device> devices;
    std::vector<std::string> adaptations;
    struct Selection {
        std::string first;
        UInt32 second;
        bool companion;
    };
    for (const auto &selection : std::vector<Selection>{{inputUID, input, false},
                                                        {outputUID, output, false},
                                                        {feedUID, output, true},
                                                        {monitorUID, input, true}}) {
        try {
            const auto id = lookup(selection.first);
            if (!id) {
                blockers.push_back("Missing device UID: " + selection.first);
                continue;
            }
            auto d = inspect(id);
            const auto &direction = selection.second == input ? d.capture : d.playback;
            if (!d.alive || !direction.channels)
                blockers.push_back("Device is unavailable in requested direction: " +
                                   selection.first);
            if (selection.companion) {
                if (!nativeFloat(direction, selection.first == feedUID ? 1 : 2))
                    blockers.push_back(
                        "Companion format does not match interleaved Float32 48 kHz contract: " +
                        selection.first);
            } else if (!physical(d.transport))
                blockers.push_back("Hardware selection must use a physical transport: " +
                                   selection.first);
            if (!selection.companion) {
                if (direction.current.size() != 1 ||
                    (direction.channels != 1 && direction.channels != 2))
                    blockers.push_back("Initial backend design supports one mono or stereo "
                                       "hardware stream only: " +
                                       selection.first);
                for (const auto &f : direction.current)
                    if (f.mFormatID != kAudioFormatLinearPCM)
                        blockers.push_back(
                            "Initial backend design requires hardware client linear PCM: " +
                            selection.first);
                std::string adaptation =
                    "{\"uid\":" + quote(d.uid) + ",\"role\":" +
                    quote(selection.second == input ? "physical_capture" : "physical_playback") +
                    ",\"hardware_rate\":" + std::to_string(d.rate) +
                    ",\"internal_rate\":48000,\"client_sample_type\":\"Float32\",\"hardware_"
                    "channels\":" +
                    std::to_string(direction.channels) +
                    ",\"target_channels\":" + std::to_string(selection.second == input ? 1 : 2) +
                    ",\"nominal_rate_conversion_required\":" +
                    (d.rate == 48000 ? "false" : "true") +
                    ",\"adaptive_clock_bridge_required\":true,\"unit_configuration_verified\":"
                    "false}";
                adaptations.push_back(adaptation);
            }
            devices.push_back(d);
        } catch (const std::exception &e) {
            blockers.push_back(selection.first + ": " + e.what());
        }
    }
    blockers.push_back("No audio backend is started or implemented. Hardware format conversion and "
                       "channel selection require explicit AUHAL client configuration.");
    blockers.push_back(
        "Independent physical and virtual clocks require adaptive resampling or a validated "
        "drift-compensated aggregate. Equal nominal rates do not establish synchrony.");
    blockers.push_back("Device change handling, callback lifetime, preallocated buffer bounds, and "
                       "processing stage remain unimplemented.");
    std::cout << "{\"operation\":\"read_only_compatibility_plan\",\"runnable\":false,\"hardware_"
                 "input_uid\":"
              << quote(inputUID) << ",\"hardware_output_uid\":" << quote(outputUID)
              << ",\"resolved_devices\":[";
    bool comma = false;
    for (const auto &d : devices) {
        if (comma)
            std::cout << ',';
        comma = true;
        deviceJSON(d);
    }
    std::cout << "],\"hardware_adaptations\":[";
    comma = false;
    for (const auto &adaptation : adaptations) {
        if (comma)
            std::cout << ',';
        comma = true;
        std::cout << adaptation;
    }
    std::cout << "],\"blockers\":[";
    comma = false;
    for (const auto &b : blockers) {
        if (comma)
            std::cout << ',';
        comma = true;
        std::cout << quote(b);
    }
    std::cout << "]}\n";
    return 2;
}
bool supportsRate(const Device &d, double rate) {
    return std::any_of(d.nominalRates.begin(), d.nominalRates.end(), [rate](const auto &range) {
        return range.mMinimum <= rate && rate <= range.mMaximum;
    });
}
int aggregatePlan(const std::string &inputUID, const std::string &outputUID) {
    struct Member {
        std::string uid;
        std::vector<std::string> roles;
        bool present = false;
        Device device;
    };
    std::vector<Member> members;
    auto add = [&](const std::string &uid, const std::string &role) {
        auto found = std::find_if(members.begin(), members.end(),
                                  [&](const auto &m) { return m.uid == uid; });
        if (found == members.end())
            members.push_back({uid, {role}, false, {}});
        else
            found->roles.push_back(role);
    };
    // Preserve subdevice order. Equal clock domains are not equal device UIDs.
    add(feedUID, "processed_microphone_output");
    add(monitorUID, "speaker_monitor_input");
    add(inputUID, "physical_microphone_input");
    add(outputUID, "physical_speaker_output");
    std::vector<std::string> blockers;
    for (auto &member : members) {
        try {
            auto id = lookup(member.uid);
            if (!id) {
                blockers.push_back("Missing aggregate member: " + member.uid);
                continue;
            }
            member.device = inspect(id);
            member.present = true;
            if (!member.device.alive)
                blockers.push_back("Inactive member: " + member.uid);
            const bool physicalRole =
                std::any_of(member.roles.begin(), member.roles.end(),
                            [](const auto &role) { return role.rfind("physical_", 0) == 0; });
            if (physicalRole && !physical(member.device.transport))
                blockers.push_back("Hardware member is not a physical transport: " + member.uid);
            for (const auto &role : member.roles) {
                if (role == "physical_microphone_input" && !member.device.capture.channels)
                    blockers.push_back("Selected physical microphone has no input channels: " +
                                       member.uid);
                if (role == "physical_speaker_output" && !member.device.playback.channels)
                    blockers.push_back("Selected physical output has no output channels: " +
                                       member.uid);
            }
            if (member.uid == feedUID && !nativeFloat(member.device.playback, 1))
                blockers.push_back("Feed format contract mismatch");
            if (member.uid == monitorUID && !nativeFloat(member.device.capture, 2))
                blockers.push_back("Monitor format contract mismatch");
            if (member.device.rate != 48000) {
                blockers.push_back(
                    supportsRate(member.device, 48000)
                        ? "Member supports 48 kHz but is not currently at that rate; changing it "
                          "needs separate authorization: " +
                              member.uid
                        : "Member does not declare 48 kHz support; installed macOS26 mixed-rate "
                          "aggregate conversion is not established: " +
                              member.uid);
            }
        } catch (const std::exception &e) {
            blockers.push_back(member.uid + ": " + e.what());
        }
    }
    const auto &main = members.front();
    const auto &monitor = members[1];
    const bool ownClockConfirmed = main.present && monitor.present && main.device.clock != 0 &&
                                   main.device.clock == monitor.device.clock;
    if (!ownClockConfirmed)
        blockers.push_back("Companion common nonzero clock domain must be confirmed before "
                           "disabling monitor drift compensation");
    blockers.push_back("Aggregate creation, active composition, stream mapping, callback timing, "
                       "and teardown remain untested; no aggregate was created");
    auto uuid = CFUUIDCreate(nullptr);
    auto uuidText = CFUUIDCreateString(nullptr, uuid);
    CFRelease(uuid);
    char uuidBuffer[128]{};
    const bool encoded =
        CFStringGetCString(uuidText, uuidBuffer, sizeof uuidBuffer, kCFStringEncodingUTF8);
    CFRelease(uuidText);
    if (!encoded)
        throw std::runtime_error("Aggregate plan UUID conversion failed");
    std::cout << "{\"operation\":\"read_only_private_aggregate_plan\",\"runnable\":false,\"target_"
                 "rate\":48000,\"composition_proposal\":{";
    std::cout << quote(kAudioAggregateDeviceUIDKey) << ':'
              << quote(std::string("dev.hari.labvoice.aggregate.") + uuidBuffer) << ',';
    std::cout << quote(kAudioAggregateDeviceNameKey) << ':' << quote("Lab Voice Private Route")
              << ',';
    std::cout << quote(kAudioAggregateDeviceIsPrivateKey) << ":1,"
              << quote(kAudioAggregateDeviceMainSubDeviceKey) << ':' << quote(feedUID) << ',';
    std::cout << quote(kAudioAggregateDeviceSubDeviceListKey) << ":[";
    bool comma = false;
    for (const auto &member : members) {
        if (comma)
            std::cout << ',';
        comma = true;
        const bool drift =
            member.uid != feedUID && !(member.uid == monitorUID && ownClockConfirmed);
        std::cout << '{' << quote(kAudioSubDeviceUIDKey) << ':' << quote(member.uid) << ','
                  << quote(kAudioSubDeviceDriftCompensationKey) << ':' << (drift ? 1 : 0) << ','
                  << quote(kAudioSubDeviceDriftCompensationQualityKey) << ':'
                  << kAudioAggregateDriftCompensationHighQuality << '}';
    }
    std::cout << "]},\"members\":[";
    comma = false;
    for (const auto &member : members) {
        if (comma)
            std::cout << ',';
        comma = true;
        std::cout << "{\"uid\":" << quote(member.uid)
                  << ",\"present\":" << (member.present ? "true" : "false") << ",\"roles\":[";
        bool roleComma = false;
        for (const auto &role : member.roles) {
            if (roleComma)
                std::cout << ',';
            roleComma = true;
            std::cout << quote(role);
        }
        std::cout << ']';
        if (member.present) {
            std::cout << ",\"device\":";
            deviceJSON(member.device);
        }
        std::cout << '}';
    }
    std::cout << "],\"companion_clock_confirmed\":" << (ownClockConfirmed ? "true" : "false")
              << ",\"blockers\":[";
    comma = false;
    for (const auto &blocker : blockers) {
        if (comma)
            std::cout << ',';
        comma = true;
        std::cout << quote(blocker);
    }
    std::cout << "],\"lifecycle_plan\":[\"Revalidate member UIDs, 48 kHz rates and alive "
                 "state\",\"Create one process-private aggregate from this composition after "
                 "authorization\",\"Read back active/full subdevices, main device, drift flags, "
                 "nominal rate and stream layout\",\"Build actual channel maps from verified "
                 "ordered subdevices and stream starting channels\",\"Create bounded owned client "
                 "buffers, callback and property listeners\",\"Start only after capture/playback "
                 "authorization and processing readiness\",\"On stop or any topology/rate change, "
                 "stop and drain callbacks, remove listeners, destroy client and aggregate\"]}\n";
    return 2;
}

} // namespace
int main(int argc, char **argv) {
    try {
        if (argc == 2 && std::string(argv[1]) == "--watch-audio-use-stabilized") return labvoice::watchAudioProcessUsage(true);
        if (argc == 2 && std::string(argv[1]) == "--watch-audio-use") return labvoice::watchAudioProcessUsage();
        if (argc == 2 && (std::string(argv[1]) == "--list" || std::string(argv[1]) == "--list-audio-use")) {
            list(std::string(argv[1]) == "--list-audio-use");
            return 0;
        }
        if (argc == 6 && std::string(argv[1]) == "--plan" && std::string(argv[2]) == "--input" &&
            std::string(argv[4]) == "--output")
            return plan(argv[3], argv[5]);
        if (argc == 6 && std::string(argv[1]) == "--aggregate-plan" &&
            std::string(argv[2]) == "--input" && std::string(argv[4]) == "--output")
            return aggregatePlan(argv[3], argv[5]);
        if (argc >= 2 && std::string(argv[1]) == "--microphone-test") {
            std::string uid, directory, operation;
            bool stdinEnabled = false;
            for (int i=2;i<argc;++i) {
                const std::string flag=argv[i];
                if (flag=="--control-stdin") { if(stdinEnabled) return 64; stdinEnabled=true; }
                else if(flag=="--input" || flag=="--directory" || flag=="--operation-id") {
                    if(++i==argc) return 64;
                    auto &value=flag=="--input"?uid:flag=="--directory"?directory:operation;
                    if(!value.empty()) return 64;
                    value=argv[i];
                } else return 64;
            }
            if(uid.empty() || directory.empty() || !labvoice::validOperationID(operation)) return 64;
            return labvoice::runMicrophoneTest(uid,directory,operation,stdinEnabled);
        }
        if (argc >= 6 && std::string(argv[1]) == "--route" && std::string(argv[2]) == "--input" &&
            std::string(argv[4]) == "--output") {
            bool microphone = false, speaker = false;
            RouteControlOptions controls;
            RouteProviderOptions provider;
            krisp_probe::InstalledWorkerSettings settings, speakerSettings;
            speakerSettings.modelRole = krisp_probe::InstalledModelRole::inbound;
            speakerSettings.modelSha256 = krisp_probe::installedInboundModelSHA256;
            bool installedProvider = false, installedSpeaker = false, installedAEC = false;
            krisp_probe::InstalledAECWorkerSettings aecSettings;
            std::set<std::string> aecFlags;
            std::set<std::string> providerFlags, speakerProviderFlags;
            for (int i = 6; i < argc; ++i) {
                const std::string flag = argv[i];
                if (flag.rfind("--aec-",0)==0) {
                    if(!aecFlags.insert(flag).second || ++i==argc)
                        throw std::invalid_argument("Repeated or incomplete AEC option");
                    const std::string value=argv[i];
                    if(flag=="--aec-provider") {
                        if(value!="installed-krisp")throw std::invalid_argument("Unsupported AEC provider");
                        installedAEC=true;
                    } else if(flag=="--aec-worker")aecSettings.workerPath=value;
                    else if(flag=="--aec-worker-sha256")aecSettings.workerSha256=value;
                    else if(flag=="--aec-library")aecSettings.libraryPath=value;
                    else throw std::invalid_argument("Unknown AEC option");
                } else if (flag == "--microphone-provider" || flag.rfind("--provider-", 0) == 0 ||
                    flag == "--speaker-provider" || flag.rfind("--speaker-provider-", 0) == 0) {
                    const bool speakerOption = flag.rfind("--speaker-provider", 0) == 0;
                    auto &seen = speakerOption ? speakerProviderFlags : providerFlags;
                    auto &selected = speakerOption ? speakerSettings : settings;
                    if (!seen.insert(flag).second || ++i == argc)
                        throw std::invalid_argument("Repeated or incomplete provider option");
                    const std::string value = argv[i];
                    const std::string name = speakerOption ? flag.substr(10) : flag.substr(2);
                    if (flag == "--microphone-provider" || flag == "--speaker-provider") {
                        if (value != "installed-krisp")
                            throw std::invalid_argument(speakerOption ? "Unsupported speaker provider" : "Unsupported microphone provider");
                        (speakerOption ? installedSpeaker : installedProvider) = true;
                    } else if (name == "provider-node") selected.nodePath = value;
                    else if (name == "provider-worker") selected.workerPath = value;
                    else if (name == "provider-addon") selected.addonPath = value;
                    else if (name == "provider-model") selected.modelPath = value;
                    else if (name == "provider-model-role" && !speakerOption) {
                        if(value=="outbound")selected.modelRole=krisp_probe::InstalledModelRole::outbound;
                        else if(value=="outbound-hvc-lfb")selected.modelRole=krisp_probe::InstalledModelRole::outboundHVC;
                        else throw std::invalid_argument("Unsupported microphone model role");
                        selected.modelSha256=krisp_probe::installedModelSha256(selected.modelRole);
                    }
                    else if (name == "provider-adapter") selected.adapterPath = value;
                    else if (name == "provider-library") selected.libraryPath = value;
                    else if (name == "provider-node-sha256") selected.nodeSha256 = value;
                    else if (name == "provider-adapter-sha256") selected.adapterSha256 = value;
                    else throw std::invalid_argument("Unknown provider option");
                } else if (flag == "--noise-suppression" || flag == "--microphone-noise-suppression")
                    microphone = true;
                else if (flag == "--speaker-noise-suppression")
                    speaker = true;
                else if (flag == "--control-stdin")
                    controls.stdinEnabled = true;
                else if (flag == "--operation-id") {
                    if (++i == argc || !labvoice::validOperationID(argv[i])) {
                        std::cerr << "Invalid operation UUID\n";
                        return 64;
                    }
                    controls.operationID = argv[i];
                } else if (flag == "--microphone-muted")
                    controls.initial.microphone.muted = true;
                else if (flag == "--speaker-muted")
                    controls.initial.speaker.muted = true;
                else if (flag == "--microphone-gain" || flag == "--speaker-gain") {
                    float gain = 0;
                    if (++i == argc || !labvoice::parseGain(argv[i], gain)) {
                        std::cerr << "Gain must be finite and in0..1\n";
                        return 64;
                    }
                    (flag == "--microphone-gain" ? controls.initial.microphone
                                                 : controls.initial.speaker)
                        .gain = gain;
                } else {
                    std::cerr << "Unknown route flag: " << flag << '\n';
                    return 64;
                }
            }
            if (controls.stdinEnabled != !controls.operationID.empty()) {
                std::cerr << "--control-stdin and --operation-id must be supplied together\n";
                return 64;
            }
            if(installedAEC && settings.modelRole==krisp_probe::InstalledModelRole::outboundHVC)
                throw std::invalid_argument("HVC microphone processing cannot be combined with AEC");
            if(!aecFlags.empty()) {
                if(!installedAEC || aecFlags.size()!=4)
                    throw std::invalid_argument("AEC provider requires all runtime options");
                (void)krisp_probe::buildInstalledAECWorkerLaunch(aecSettings,{});
                provider.installedAEC=std::move(aecSettings);
            }
            if (!providerFlags.empty()) {
                if (!installedProvider || !microphone || providerFlags.size() != (providerFlags.count("--provider-model-role") ? 10u : 9u))
                    throw std::invalid_argument("Installed provider requires microphone suppression and all runtime options");
                // Syntax validation before aggregate creation. Worker admission
                // checks actual artifacts before any callback can run.
                (void)krisp_probe::buildInstalledWorkerLaunch(settings, {});
                provider.installed = std::move(settings);
            }
            if (!speakerProviderFlags.empty()) {
                if (!installedSpeaker || !speaker || speakerProviderFlags.size() != 9)
                    throw std::invalid_argument("Installed provider requires speaker suppression and all runtime options");
                (void)krisp_probe::buildInstalledWorkerLaunch(speakerSettings, {});
                provider.installedSpeaker = std::move(speakerSettings);
            }
            return runRoute(argv[3], argv[5], microphone, speaker, controls, provider);
        }
        std::cerr << "Usage: audio-host --list | --plan/--aggregate-plan --input DEVICE_UID "
                     "--output DEVICE_UID\n";
        return 64;
    } catch (const std::exception &e) {
        std::cerr << e.what() << '\n';
        return 1;
    }
}
