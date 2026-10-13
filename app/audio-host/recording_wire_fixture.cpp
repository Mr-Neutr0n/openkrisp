// Test-only wire executable. It never loads CoreAudio or captures a device.
#include "recording.hpp"
#include "control_protocol.hpp"
#include <chrono>
#include <iostream>
#include <thread>
using namespace labvoice;
int main(int argc, char **argv) {
    if (argc != 2 || !validOperationID(argv[1])) return 2;
    const std::string operation = argv[1];
    RecordingProtocol protocol(operation);
    auto recorder = std::make_shared<Recording>();
    std::string id;
    float mic[16], speaker[32];
    for (auto &value : mic) value = .5f;
    for (auto &value : speaker) value = .25f;
    auto publishResult = [&] {
        while (!recorder->ready()) std::this_thread::sleep_for(std::chrono::milliseconds(1));
        const auto result = recorder->finish();
        std::cout << "{\"type\":\"recording-result\",\"operationID\":" << jsonString(operation)
                  << ",\"recordingID\":" << jsonString(id) << ",\"status\":"
                  << jsonString(result.completed ? "completed" : "failed")
                  << ",\"path\":" << jsonString(result.path) << ",\"frames\":" << result.frames
                  << ",\"sampleRate\":48000,\"channels\":2,\"clippedSamples\":" << result.clippedSamples;
        if (!result.completed) std::cout << ",\"partialFrames\":" << result.frames << ",\"error\":" << jsonString(result.error);
        std::cout << '}' << std::endl;
        id.clear();
    };
    std::string line;
    while (std::getline(std::cin, line)) {
        if (line.size() > maximumControlLine) return 2;
        bool finish = false;
        const auto reply = protocol.handle(line, [&](const auto &action, const auto &recordingID, const auto &path) {
            if (action == "start") {
                if (!id.empty()) return std::string("recording_already_active_or_result_pending");
                std::string error;
                if (!recorder->start(path, error)) return error;
                id = recordingID;
                recorder->capture(mic, speaker, 16, .25, {}, recorder->generation());
            } else {
                if (id != recordingID || !recorder->busy()) return std::string("wrong_or_inactive_recording");
                if (action == "pause" && !recorder->pause()) return std::string("recording_not_running");
                if (action == "resume") {
                    if (!recorder->resume()) return std::string("recording_not_paused");
                    recorder->capture(mic, speaker, 16, 1000.25, {}, recorder->generation());
                }
                if (action == "stop") { recorder->requestStop(); finish = true; }
            }
            return std::string{};
        });
        std::cout << reply << std::endl;
        if (finish) publishResult();
    }
    if (!id.empty()) { recorder->requestStop(); publishResult(); }
}
