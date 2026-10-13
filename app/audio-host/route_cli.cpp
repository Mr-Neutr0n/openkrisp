#include "route_cli.hpp"
#include "control_protocol.hpp"
#include "noise_adapter.hpp"
#include "routing.hpp"
#include <cerrno>
#include <chrono>
#include <csignal>
#include <iostream>
#include <poll.h>
#include <thread>
#include <unistd.h>

namespace {
volatile std::sig_atomic_t interrupted = 0;
void interrupt(int) { interrupted = 1; }
using labvoice::jsonString;
class RouteRecording {
    std::string operation_, id_, path_;
    std::shared_ptr<labvoice::Recording> owner_;
    bool stopRequested_ = false;
    std::chrono::steady_clock::time_point stopDeadline_;
  public:
    labvoice::RecordingProtocol protocol;
    explicit RouteRecording(const std::string &operation) : operation_(operation), protocol(operation) {}
    std::string command(const std::string &action, const std::string &id, const std::string &path,
                        labvoice::Session &session) {
        auto *recording = session.recording();
        if (!session.running() || !recording || interrupted) return "route_not_running";
        if (action == "start") {
            if (!id_.empty()) return "recording_already_active_or_result_pending";
            // Timed-out storage remains owned until a control-thread reap.
            service(session);
            if (owner_) return "previous_writer_cleanup_pending";
            std::string error;
            if (!recording->start(path, error)) return error;
            id_ = id; path_ = path; owner_ = session.recordingOwner(); stopRequested_ = false;
            return {};
        }
        if (id_ != id || !recording->busy()) return "wrong_or_inactive_recording";
        if (action == "stop") {
            recording->requestStop();
            if (!stopRequested_) stopDeadline_ = std::chrono::steady_clock::now() + std::chrono::seconds(2);
            stopRequested_ = true;
        }
        else if (action == "pause" && !recording->pause()) return "recording_not_running";
        else if (action == "resume" && !recording->resume()) return "recording_not_paused";
        return {};
    }
    void service(labvoice::Session &, bool stopping = false) {
        auto *recording = owner_.get();
        if (!recording || !recording->busy()) return;
        if (id_.empty()) {
            // The failed result was already emitted. Do not emit it twice.
            if (recording->ready()) { (void)recording->finish(); owner_.reset(); }
            else if (stopping) recording->requestStop();
            return;
        }
        if (stopping || (stopRequested_ && std::chrono::steady_clock::now() >= stopDeadline_)) {
            recording->requestStop();
            const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
            while (stopping && !recording->ready() && std::chrono::steady_clock::now() < deadline)
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
            if (!recording->ready()) {
                recording->abort(labvoice::Recording::Failure::drain_timeout);
                std::cout << "{\"type\":\"recording-result\",\"operationID\":" << jsonString(operation_)
                          << ",\"recordingID\":" << jsonString(id_)
                          << ",\"status\":\"failed\",\"error\":\"writer_shutdown_pending\",\"path\":" << jsonString(path_)
                          << ",\"frames\":" << recording->writtenFrames() << ",\"partialFrames\":" << recording->writtenFrames()
                          << ",\"sampleRate\":48000,\"channels\":2}" << std::endl;
                id_.clear();
                return;
            }
        }
        if (!stopping && !recording->ready()) return;
        const auto result = recording->finish();
        std::cout << "{\"type\":\"recording-result\",\"operationID\":" << jsonString(operation_)
                  << ",\"recordingID\":" << jsonString(id_) << ",\"status\":"
                  << jsonString(result.completed ? "completed" : "failed") << ",\"path\":"
                  << jsonString(result.path) << ",\"frames\":" << result.frames
                  << ",\"sampleRate\":48000,\"channels\":2,\"clippedSamples\":" << result.clippedSamples;
        if (!result.completed) std::cout << ",\"partialFrames\":" << result.frames
                                        << ",\"error\":" << jsonString(result.error);
        std::cout << '}' << std::endl;
        id_.clear(); owner_.reset();
    }
};
void serviceControls(labvoice::ControlFramer &input, labvoice::ControlProtocol &protocol,
                     labvoice::Session &session, RouteRecording &recording, pid_t parent) {
    if (input.needsRead()) {
        pollfd descriptor{STDIN_FILENO, POLLIN, 0};
        const int ready = poll(&descriptor, 1, 0);
        if (ready < 0 && errno != EINTR) {
            std::cout << protocol.reject("stdin_poll_failed") << std::endl;
            input.finish();
        } else if (ready > 0 && (descriptor.revents & (POLLIN | POLLHUP))) {
            char buffer[labvoice::maximumControlLine];
            const ssize_t count = read(STDIN_FILENO, buffer, sizeof buffer);
            if (count > 0)
                input.append(std::string_view(buffer, size_t(count)));
            else if (count == 0)
                input.finish();
            else if (errno != EINTR) {
                std::cout << protocol.reject("stdin_read_failed") << std::endl;
                input.finish();
            }
        } else if (ready > 0 && (descriptor.revents & (POLLERR | POLLNVAL))) {
            std::cout << protocol.reject("stdin_unavailable") << std::endl;
            input.finish();
        }
    }
    for (const auto &line : input.take(8)) {
        auto reply = line.error.empty()
            ? recording.protocol.handle(line.text, [&](const auto &action, const auto &id, const auto &path) {
                return getppid() == parent ? recording.command(action, id, path, session) : "parent_exited";
              }) : protocol.reject(line.error);
        if (reply.empty()) reply = protocol.handle(line.text, [&](const auto &value) {
            return !interrupted && getppid() == parent && session.publishControls(value);
        });
        std::cout << reply << std::endl;
    }
    if (input.ended())
        interrupted = 1;
}

} // namespace
int runRoute(const std::string &input, const std::string &output, bool microphoneNoise,
             bool speakerNoise, const RouteControlOptions &controls) {
    // Merely compiling this function starts no audio. --route is an explicit start command.
    labvoice::CoreAudioBackend backend;
    std::shared_ptr<labvoice::NoiseAdapter> noise;
    if (microphoneNoise || speakerNoise)
        noise = std::make_shared<labvoice::NoiseAdapter>(microphoneNoise, speakerNoise);
    labvoice::Session session(backend);
    std::unique_ptr<labvoice::ControlProtocol> protocol;
    labvoice::ControlFramer controlInput;
    RouteRecording recording(controls.operationID);
    if (controls.stdinEnabled)
        protocol = std::make_unique<labvoice::ControlProtocol>(controls.operationID);
    interrupted = 0;
    const pid_t parent = getppid();
    const auto oldInt = std::signal(SIGINT, interrupt), oldTerm = std::signal(SIGTERM, interrupt);
    auto restore = [&] {
        std::signal(SIGINT, oldInt);
        std::signal(SIGTERM, oldTerm);
    };
    if (!session.start({input, output}, noise ? labvoice::NoiseAdapter::process : nullptr,
                       noise.get(), noise, controls.initial)) {
        std::cerr << "Route start failed: " << session.error() << '\n';
        restore();
        return 1;
    }
    std::cout << "{\"event\":\"route_started\",\"input_uid\":" << jsonString(input)
              << ",\"output_uid\":" << jsonString(output)
              << ",\"microphone_noise\":" << (microphoneNoise ? "true" : "false")
              << ",\"speaker_noise\":" << (speakerNoise ? "true" : "false") << ","
              << labvoice::controlJSON(controls.initial);
    if (controls.stdinEnabled)
        std::cout << ",\"operationID\":" << jsonString(controls.operationID);
    std::cout << "}" << std::endl;
    std::cout << "Route started. Physical microphone: " << input << "; physical output: " << output
              << "; microphone suppression: " << (microphoneNoise ? "enabled" : "disabled")
              << "; speaker suppression: " << (speakerNoise ? "enabled" : "disabled")
              << ". Stop with Ctrl-C.\n";
    while (!interrupted && session.running() && getppid() == parent) {
        std::this_thread::sleep_for(std::chrono::milliseconds(20));
        if (protocol)
            serviceControls(controlInput, *protocol, session, recording, parent);
        recording.service(session, !session.running());
        if (!session.service())
            break;
    }
    const bool changed = !interrupted;
    recording.service(session, true);
    const bool stopped = session.stop();
    restore();
    if (!stopped) {
        std::cerr << "Route cleanup pending: " << session.error() << '\n';
        return 1;
    }
    if (changed) {
        std::cerr << "Route stopped after device/topology change or parent exit. Revalidate before "
                     "restart.\n";
        return 2;
    }
    return 0;
}
