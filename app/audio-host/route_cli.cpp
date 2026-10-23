#include "route_cli.hpp"
#include "route_aec_ack.hpp"
#include "control_protocol.hpp"
#include "noise_adapter.hpp"
#include "installed_noise_adapter.hpp"
#include "aec_microphone_chain.hpp"
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
             bool speakerNoise, const RouteControlOptions &controls, const RouteProviderOptions &provider) {
    // Merely compiling this function starts no audio. --route is an explicit start command.
    labvoice::CoreAudioBackend backend;
    std::shared_ptr<labvoice::NoiseAdapter> noise;
    const bool preMicrophoneNoise=microphoneNoise && !provider.installedAEC;
    if ((!provider.installed || provider.installedAEC) && !provider.installedSpeaker && (preMicrophoneNoise || speakerNoise))
        noise = std::make_shared<labvoice::NoiseAdapter>(preMicrophoneNoise, speakerNoise);
    // This separate control-thread owner outlives every Session cleanup attempt.
    // Explicit worker stop prevents a queued HAL block's final Context release
    // from performing a blocking worker join on its dispatch thread.
    std::shared_ptr<labvoice::InstalledNoiseAdapter> installed;
    std::shared_ptr<labvoice::AECMicrophoneChain> aec;
    labvoice::Session session(backend);
    struct WorkerStopGuard {
        std::shared_ptr<labvoice::InstalledNoiseAdapter>& owner;
        std::shared_ptr<labvoice::AECMicrophoneChain>& aec;
        ~WorkerStopGuard() {
            if(owner){try{(void)owner->stop();}catch(...){}}
            if(aec){try{(void)aec->stop();}catch(...){}}
        }
    } workerStopGuard{installed,aec};
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
    labvoice::ProcessorFactory prepare;
    if (provider.installed || provider.installedSpeaker || provider.installedAEC) {
        if (provider.installed && !microphoneNoise) { restore(); throw std::invalid_argument("Installed provider requires microphone suppression"); }
        if (provider.installedSpeaker && !speakerNoise) { restore(); throw std::invalid_argument("Installed provider requires speaker suppression"); }
        prepare = [&](const labvoice::Layout &layout) {
            if (interrupted || getppid() != parent) throw std::runtime_error("Route startup cancelled");
            std::string error;
            labvoice::ProcessorBinding binding;
            if((provider.installed && !provider.installedAEC) || provider.installedSpeaker) {
                labvoice::InstalledNoiseOptions options;
                options.microphone=provider.installedAEC ? std::nullopt : provider.installed;
                options.speaker=provider.installedSpeaker;
                options.microphoneRNNoise=preMicrophoneNoise && !provider.installed;
                options.speakerRNNoise=speakerNoise && !provider.installedSpeaker;
                installed=labvoice::InstalledNoiseAdapter::create(layout,options,error);
                if(!installed)throw std::runtime_error(error);
                binding={labvoice::InstalledNoiseAdapter::process,installed.get(),installed};
            } else if(noise) binding={labvoice::NoiseAdapter::process,noise.get(),noise};
            if(provider.installedAEC) {
                labvoice::AECMicrophoneChainOptions options;
                options.aec={*provider.installedAEC,2};
                options.microphone=provider.installed;
                options.microphoneRNNoise=microphoneNoise && !provider.installed;
                options.schedulingBudgetFrames=2;
                aec=labvoice::AECMicrophoneChain::create(layout,options,error);
                if(!aec)throw std::runtime_error(error);
                binding.microphoneStageDisabled=true;
                binding.duplex=aec->binding();
            }
            if (interrupted || getppid() != parent) throw std::runtime_error("Route startup cancelled");
            return binding;
        };
    }
    if (!session.start({input, output}, (noise && !prepare) ? labvoice::NoiseAdapter::process : nullptr,
                       prepare ? nullptr : noise.get(), prepare ? std::shared_ptr<void>{} : noise, controls.initial, prepare)) {
        if (installed) (void)installed->stop();
        if (aec) (void)aec->stop();
        std::cerr << "Route start failed: " << session.error() << '\n';
        restore();
        return 1;
    }
    std::cout << "{\"event\":\"route_started\",\"input_uid\":" << jsonString(input)
              << ",\"output_uid\":" << jsonString(output)
              << ",\"microphone_noise\":" << (microphoneNoise ? "true" : "false")
              << ",\"speaker_noise\":" << (speakerNoise ? "true" : "false") << ","
              << labvoice::controlJSON(controls.initial);
    std::cout << ",\"microphone_provider\":" << jsonString(provider.installedAEC && !microphoneNoise ? "installed-krisp-aec" : provider.installed ? "installed-krisp" : (microphoneNoise ? "rnnoise" : "none"))
              << ",\"speaker_provider\":" << jsonString(provider.installedSpeaker ? "installed-krisp" : (speakerNoise ? "rnnoise" : "none"));
    if (installed) {
        if(const auto* settings=installed->microphoneSettings())
            std::cout<<labvoice::installedNCStartupFields("provider_",*settings,installed->microphoneDelaySamples(),installed->maximumCallbackFrames());
        if(const auto* settings=installed->speakerSettings())
            std::cout<<labvoice::installedNCStartupFields("speaker_provider_",*settings,installed->speakerDelaySamples(),installed->maximumCallbackFrames());
    }
    if(aec)std::cout<<labvoice::microphoneChainStartupFields(aec->aecSettings(),aec->aecDelaySamples(),
        aec->maximumCallbackFrames(),aec->bufferingConfig().schedulingBudgetFrames,
        microphoneNoise,aec->microphoneSettings(),aec->microphoneDelaySamples());
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
        if ((installed && !installed->healthy()) || (aec && !aec->healthy()) || !session.service())
            break;
    }
    const bool changed = !interrupted;
    recording.service(session, true);
    const bool stopped = session.stop();
    const bool workerStopped = !installed || installed->stop();
    const bool aecStopped = !aec || aec->stop();
    restore();
    if (!workerStopped) {
        std::cerr << "Installed provider failed: " << installed->error() << '\n';
        return 1;
    }
    if (!aecStopped) {
        std::cerr << "Microphone processing chain failed: " << aec->error() << '\n';
        return 1;
    }
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
