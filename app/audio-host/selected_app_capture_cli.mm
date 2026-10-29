#include "selected_app_capture_cli.hpp"
#include "control_protocol.hpp"
#import <Foundation/Foundation.h>
#include <cerrno>
#include <cmath>
#include <csignal>
#include <fcntl.h>
#include <poll.h>
#include <set>
#include <unistd.h>
#include <chrono>
#include <iostream>
#include <atomic>
#include <mutex>
#include <thread>

namespace labvoice {
namespace {
std::atomic<bool> stopped{false};
static_assert(std::atomic<bool>::is_always_lock_free);
void stopSignal(int) { stopped.store(true, std::memory_order_relaxed); }
struct Commands {
    std::atomic<bool> requested{false}, finished{false};
    std::mutex mutex;
    std::string error;
};
void readCommands(const std::shared_ptr<Commands>& state) {
    std::string pending, error;
    while (!state->finished.load() && !stopped.load()) {
        pollfd descriptor{STDIN_FILENO, POLLIN | POLLHUP, 0};
        const auto ready = poll(&descriptor, 1, 50);
        if (ready < 0) { if (errno == EINTR) continue; error = "Capture command read failed."; break; }
        if (!ready) continue;
        char bytes[256]; const auto count = read(STDIN_FILENO, bytes, sizeof bytes);
        if (count == 0) { if (!pending.empty()) error = "Incomplete capture command."; break; }
        if (count < 0) { if (errno == EINTR || errno == EAGAIN) continue; error = "Capture command read failed."; break; }
        pending.append(bytes, static_cast<size_t>(count));
        if (pending == "stop\n") break;
        if (pending.size() > 5 || pending.find('\n') != std::string::npos) { error = "Invalid capture command."; break; }
    }
    { std::lock_guard lock(state->mutex); state->error = error; }
    state->requested.store(true);
}
struct SignalScope {
    using Handler = void (*)(int);
    Handler term = signal(SIGTERM, stopSignal), interrupt = signal(SIGINT, stopSignal), pipe = signal(SIGPIPE, SIG_IGN);
    ~SignalScope() { (void)signal(SIGTERM, term); (void)signal(SIGINT, interrupt); (void)signal(SIGPIPE, pipe); }
};
struct CommandReader {
    std::shared_ptr<Commands> state;
    std::thread reader;
    explicit CommandReader(std::shared_ptr<Commands> value) : state(std::move(value)), reader([shared = state] { readCommands(shared); }) {}
    void finish() { state->requested.store(true); state->finished.store(true); if (reader.joinable()) reader.join(); }
    ~CommandReader() { finish(); }
};
NSString* string(const std::string& value) {
    return [[[NSString alloc] initWithBytes:value.data() length:value.size() encoding:NSUTF8StringEncoding] autorelease];
}
bool integer(id value, uint64_t maximum, uint64_t& result) {
    if (![value isKindOfClass:[NSNumber class]] || CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return false;
    const double number = [value doubleValue];
    if (!std::isfinite(number) || number < 1 || number > maximum || std::floor(number) != number) return false;
    result = static_cast<uint64_t>(number); return true;
}
bool keys(NSDictionary* object, NSSet* expected) {
    return [object isKindOfClass:[NSDictionary class]] && [[NSSet setWithArray:object.allKeys] isEqualToSet:expected];
}
NSDictionary* targetJSON(const CallCaptureTarget& target) {
    NSMutableArray* processes = [NSMutableArray array];
    for (const auto& process : target.processes)
        [processes addObject:@{@"object_id": @(process.objectID), @"actual_pid": @(process.actualPID)}];
    return @{@"responsible_pid": @(target.responsiblePID), @"app_id": string(target.appID), @"processes": processes};
}
NSDictionary* formatJSON(const AudioStreamBasicDescription& f) {
    return @{@"sample_rate": @(std::isfinite(f.mSampleRate) ? f.mSampleRate : 0),
        @"channels": @(f.mChannelsPerFrame), @"format_id": @(f.mFormatID), @"format_flags": @(f.mFormatFlags),
        @"bits_per_channel": @(f.mBitsPerChannel), @"bytes_per_frame": @(f.mBytesPerFrame)};
}
void microphoneJSON(NSMutableDictionary* event, const SelectedAppCaptureOptions& options, const CallCaptureMicrophoneSpec& mic) {
    event[@"microphone_uid"] = string(options.microphoneUID);
    event[@"microphone_object_id"] = @(mic.objectID);
    event[@"microphone_source_format"] = formatJSON(mic.format);
    event[@"mix_policy"] = @"app_half_mic_half";
    event[@"timeline_policy"] = @"adjacent_host_anchors_common_overlap";
}
NSDictionary* timelineJSON(const CallCaptureTimelineStats& t) {
    return @{@"output_frames": @(t.outputFrames),
        @"first_host_time": @(t.firstHostTime),
        @"end_host_time": @(t.endHostTime),
        @"app_source_frames": @(t.appSourceFrames),
        @"microphone_source_frames": @(t.microphoneSourceFrames),
        @"app_startup_frames": @(t.appStartupFrames),
        @"microphone_startup_frames": @(t.microphoneStartupFrames),
        @"app_tail_frames": @(t.appTailFrames),
        @"microphone_tail_frames": @(t.microphoneTailFrames),
        @"app_maximum_drift_ppm": @(t.appMaximumDriftPPM),
        @"microphone_maximum_drift_ppm": @(t.microphoneMaximumDriftPPM),
        @"app_first_sample_time": @(t.appFirstSampleTime),
        @"app_last_sample_time": @(t.appLastSampleTime),
        @"microphone_first_sample_time": @(t.microphoneFirstSampleTime),
        @"microphone_last_sample_time": @(t.microphoneLastSampleTime),
        @"app_first_host_time": @(t.appFirstHostTime),
        @"app_last_host_time": @(t.appLastHostTime),
        @"microphone_first_host_time": @(t.microphoneFirstHostTime),
        @"microphone_last_host_time": @(t.microphoneLastHostTime)};
}
// No callback writes stdout. A closed or stalled consumer cannot hold a live
// capture forever at its start acknowledgment.
bool emit(NSDictionary* event) {
    NSData* json = [NSJSONSerialization dataWithJSONObject:event options:0 error:nullptr];
    if (!json || json.length > 98304) return false;
    std::string bytes(static_cast<const char*>(json.bytes), json.length); bytes += '\n';
    const int flags = fcntl(STDOUT_FILENO, F_GETFL);
    if (flags < 0 || fcntl(STDOUT_FILENO, F_SETFL, flags | O_NONBLOCK) < 0) return false;
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    size_t offset = 0;
    while (offset < bytes.size() && std::chrono::steady_clock::now() < deadline) {
        const auto count = write(STDOUT_FILENO, bytes.data() + offset, bytes.size() - offset);
        if (count > 0) { offset += static_cast<size_t>(count); continue; }
        if (count < 0 && errno != EINTR && errno != EAGAIN && errno != EWOULDBLOCK) break;
        pollfd descriptor{STDOUT_FILENO, POLLOUT, 0}; (void)poll(&descriptor, 1, 20);
    }
    (void)fcntl(STDOUT_FILENO, F_SETFL, flags);
    return offset == bytes.size();
}
NSMutableDictionary* envelope(const SelectedAppCaptureOptions& options, NSString* event) {
    return [@{@"version": @1, @"event": event, @"operation_id": string(options.operationID),
        @"target": targetJSON(options.target), @"source": options.microphoneUID.empty() ? @"selected_app_output" : @"selected_app_output_and_microphone",
        @"sample_rate": @48000, @"channels": @2, @"pcm_format": @"pcm16"} mutableCopy];
}
}
bool parseSelectedAppCaptureArguments(int argc, char** argv, SelectedAppCaptureOptions& options, std::string& error) {
    @autoreleasepool {
        options = {};
        error = "Expected --capture-selected-app --operation-id UUID --target-json JSON --output ABSOLUTE_PATH [--microphone-uid UID].";
        if ((argc != 8 && argc != 10) || std::string(argv[1]) != "--capture-selected-app") return false;
        std::set<std::string> seen;
        std::string target;
        for (int index = 2; index < argc; index += 2) {
            const std::string key = argv[index], value = argv[index + 1];
            if (!seen.insert(key).second) return false;
            if (key == "--operation-id") options.operationID = value;
            else if (key == "--target-json") target = value;
            else if (key == "--output") options.output = value;
            else if (key == "--microphone-uid") {
                if (value.empty() || value.size() > 4096 || !string(value)) return false;
                options.microphoneUID = value;
            }
            else return false;
        }
        if (!validOperationID(options.operationID) || options.output.empty() || options.output.front() != '/' ||
            options.output.size() > 4096 || !string(options.output) || target.empty() || target.size() > 16384) return false;
        NSData* bytes = [NSData dataWithBytes:target.data() length:target.size()];
        id object = [NSJSONSerialization JSONObjectWithData:bytes options:0 error:nullptr];
        if (!keys(object, [NSSet setWithArray:@[@"responsible_pid", @"app_id", @"processes"]])) return false;
        uint64_t pid = 0;
        if (!integer(object[@"responsible_pid"], INT32_MAX, pid)) return false;
        id appID = object[@"app_id"], processes = object[@"processes"];
        if (![appID isKindOfClass:[NSString class]] || ![processes isKindOfClass:[NSArray class]] ||
            [processes count] == 0 || [processes count] > 32) return false;
        NSData* appBytes = [appID dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
        if (!appBytes || appBytes.length == 0 || appBytes.length > 4096) return false;
        options.target.responsiblePID = static_cast<int>(pid);
        options.target.appID.assign(static_cast<const char*>(appBytes.bytes), appBytes.length);
        if (options.target.appID.find('\0') != std::string::npos) return false;
        options.target.processes.clear(); std::set<uint64_t> ids, pids;
        for (id process in processes) {
            uint64_t objectID = 0, actualPID = 0;
            if (!keys(process, [NSSet setWithArray:@[@"object_id", @"actual_pid"]]) ||
                !integer(process[@"object_id"], UINT32_MAX, objectID) ||
                !integer(process[@"actual_pid"], INT32_MAX, actualPID) || !ids.insert(objectID).second || !pids.insert(actualPID).second) return false;
            options.target.processes.push_back({static_cast<AudioObjectID>(objectID), static_cast<int>(actualPID)});
        }
        error.clear(); return true;
    }
}
int runSelectedAppCapture(int argc, char** argv, std::function<std::unique_ptr<CallCaptureSession>(const SelectedAppCaptureOptions&)> factory) {
    @autoreleasepool {
        SelectedAppCaptureOptions options; std::string error;
        if (!parseSelectedAppCaptureArguments(argc, argv, options, error)) { std::cerr << error << '\n'; return 64; }
        stopped.store(false);
        SignalScope signals;
        auto session = factory ? factory(options) : (options.microphoneUID.empty() ? makeNativeCallCaptureSession() : makeNativeCallCaptureSession(options.microphoneUID));
        if (!session) return 2;
        auto commands = std::make_shared<Commands>();
        const auto cancelled = [commands] { return stopped.load() || commands->requested.load(); };
        CommandReader reader(commands);
        bool started = session->start(options.target, options.output, error, cancelled);
        if (cancelled() && started) error = "Capture was stopped during startup.";
        if (started && error.empty()) {
            auto event = envelope(options, @"app_capture_started"); event[@"source_format"] = formatJSON(session->sourceFormat());
            if (!options.microphoneUID.empty()) microphoneJSON(event, options, session->microphoneSpec());
            if (!emit(event)) error = "Capture acknowledgment could not be delivered.";
        }
        auto nextValidation = std::chrono::steady_clock::now();
        while (started && error.empty() && !cancelled()) {
            if (!session->healthy()) { if (!cancelled()) error = "Selected application capture source failed."; break; }
            if (std::chrono::steady_clock::now() >= nextValidation) {
                if (!session->validateCurrentTarget(error)) { if (cancelled()) error.clear(); break; }
                nextValidation = std::chrono::steady_clock::now() + std::chrono::milliseconds(250);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        }
        reader.finish();
        { std::lock_guard lock(commands->mutex); if (!commands->error.empty()) error = commands->error; }
        auto result = session->stop();
        if (result.completed && result.path != options.output) error = "Capture output path mismatch.";
        if (!error.empty()) { result.completed = false; result.error = error + (result.error.empty() ? "" : " " + result.error); }
        auto event = envelope(options, @"app_capture_result");
        event[@"status"] = result.completed && result.cleanupVerified ? @"completed" : @"failed";
        event[@"path"] = string(options.output); event[@"frames"] = @(result.frames);
        event[@"cleanup_verified"] = @(result.cleanupVerified);
        event[@"error"] = string(result.error.substr(0, 4096)) ?: @"Invalid native diagnostic.";
        event[@"source_format"] = formatJSON(result.sourceFormat); event[@"source_frames"] = @(result.sourceFrames);
        event[@"first_host_time"] = @(result.firstHostTime); event[@"last_host_time"] = @(result.lastHostTime);
        if (!options.microphoneUID.empty()) {
            microphoneJSON(event, options, result.microphone);
            event[@"timeline"] = timelineJSON(result.timeline);
        }
        const bool delivered = emit(event);
        return delivered && result.completed && result.cleanupVerified ? 0 : 2;
    }
}
}
