#include "recording.hpp"
#include "control_protocol.hpp"
#include <cassert>
#include <chrono>
#include <condition_variable>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <mutex>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>
using namespace labvoice;
namespace {
std::mutex mutex;
std::condition_variable condition;
bool blocked = false, released = false;
ssize_t stalledWrite(int fd, const void *data, size_t size) {
    std::unique_lock lock(mutex);
    blocked = true; condition.notify_all();
    condition.wait(lock, [] { return released; });
    lock.unlock(); return write(fd, data, size);
}
ssize_t failedWrite(int, const void *, size_t) { errno = ENOSPC; return -1; }
Recording::Result stop(const std::shared_ptr<Recording> &recording) {
    recording->requestStop();
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
    while (!recording->ready()) {
        assert(std::chrono::steady_clock::now() < deadline);
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    return recording->finish();
}
uint32_t little(const unsigned char *p) { return p[0] | uint32_t(p[1]) << 8 | uint32_t(p[2]) << 16 | uint32_t(p[3]) << 24; }
}
int main() {
    char directory[] = "/tmp/labvoice-record-test-XXXXXX";
    assert(mkdtemp(directory)); assert(chmod(directory, 0700) == 0);
    auto path = [&](const char *name) { return std::string(directory) + "/" + name + ".wav"; };
    std::vector<std::string> files;
    auto begin = [&](const char *name) {
        auto recorder = std::make_shared<Recording>();
        std::string error; files.push_back(path(name)); assert(recorder->start(files.back(), error));
        return recorder;
    };
    float mic[4]{1, .5f, -1, 0}, speaker[8]{0, 1, 0, 1, 0, 1, 0, 1};
    auto recorder = begin("mix");
    auto generation = recorder->generation();
    recorder->capture(mic, speaker, 4, .25, {}, generation);
    recorder->capture(mic, speaker, 4, 4.25, {}, generation);
    assert(recorder->pause());
    recorder->capture(mic, speaker, 4, 8.25, {}, generation);
    assert(recorder->resume());
    recorder->capture(mic, speaker, 4, 100.25, {}, generation); // stale pre-pause callback
    recorder->capture(mic, speaker, 4, 100.25, {{1,true},{.5f,false}}, recorder->generation());
    auto result = stop(recorder); assert(result.completed && result.frames == 12);
    struct stat info{}; assert(stat(result.path.c_str(), &info) == 0 && (info.st_mode & 0777) == 0600 && info.st_size == 92);
    int fd = open(result.path.c_str(), O_RDONLY); unsigned char bytes[92]{};
    assert(read(fd, bytes, sizeof bytes) == sizeof bytes); close(fd);
    assert(!std::memcmp(bytes, "RIFF", 4) && little(bytes + 4) == 84 && little(bytes + 40) == 48);
    assert(bytes[44] == 0 && bytes[45] == 64); // first left mix .5
    assert(bytes[46] == 255 && bytes[47] == 127); // first right full scale
    assert(bytes[76] == 0 && bytes[77] == 0 && bytes[78] == 0 && bytes[79] == 32); // muted mic and attenuated speaker
    std::string error; assert(!recorder->start(result.path, error)); // exclusive, never overwrite
    recorder = begin("gap");
    recorder->capture(mic, speaker, 4, .5, {}, recorder->generation());
    recorder->capture(mic, speaker, 4, 5.5, {}, recorder->generation());
    result = stop(recorder); assert(!result.completed && result.error == "sample_clock_discontinuity");
    fd = open(result.path.c_str(), O_RDONLY); assert(read(fd, bytes, 44) == 44); close(fd);
    assert(little(bytes) == 0); // no finalized header
    recorder = begin("input-gap");
    recorder->capture(mic, speaker, 4, .5, {}, recorder->generation(), 100.5);
    recorder->capture(mic, speaker, 4, 4.5, {}, recorder->generation(), 105.5);
    result = stop(recorder); assert(!result.completed && result.error == "sample_clock_discontinuity");
    recorder = std::make_shared<Recording>(); recorder->setWriterForTest(failedWrite);
    files.push_back(path("disk")); assert(recorder->start(files.back(), error));
    recorder->capture(mic, speaker, 4, 0, {}, recorder->generation());
    result = stop(recorder); assert(!result.completed && result.error == "wav_write_or_finalize_failed");
    recorder = std::make_shared<Recording>(); recorder->setFrameLimitForTest(3);
    files.push_back(path("limit")); assert(recorder->start(files.back(), error));
    recorder->capture(mic, speaker, 4, 0, {}, recorder->generation());
    result = stop(recorder); assert(!result.completed && result.error == "riff_size_limit");
    recorder = std::make_shared<Recording>(); recorder->setWriterForTest(stalledWrite);
    files.push_back(path("overflow")); assert(recorder->start(files.back(), error));
    std::vector<float> mono(4096, .25f), stereo(8192, .5f);
    generation = recorder->generation(); recorder->capture(mono.data(), stereo.data(), 4096, 0, {}, generation);
    { std::unique_lock lock(mutex); condition.wait(lock, [] { return blocked; }); }
    for (unsigned i = 1; i <= 16; ++i) recorder->capture(mono.data(), stereo.data(), 4096, i * 4096, {}, generation);
    { std::lock_guard lock(mutex); released = true; } condition.notify_all();
    result = stop(recorder); assert(!result.completed && result.error == "capture_queue_overflow");
    // Writer storage survives external-owner release while disk IO is paused.
    { std::lock_guard lock(mutex); blocked = false; released = false; }
    recorder = std::make_shared<Recording>(); recorder->setWriterForTest(stalledWrite);
    files.push_back(path("retained")); assert(recorder->start(files.back(), error));
    recorder->capture(mic, speaker, 4, 0, {}, recorder->generation());
    { std::unique_lock lock(mutex); condition.wait(lock, [] { return blocked; }); }
    std::weak_ptr<Recording> weak = recorder;
    recorder->abort(Recording::Failure::drain_timeout);
    recorder.reset();
    assert(!weak.expired());
    { std::lock_guard lock(mutex); released = true; } condition.notify_all();
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
    while (!weak.expired()) {
        assert(std::chrono::steady_clock::now() < deadline);
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    const std::string operation = "12345678-1234-1234-1234-123456789abc";
    RecordingProtocol protocol(operation);
    unsigned calls = 0;
    auto apply = [&](const auto &, const auto &, const auto &) { ++calls; return std::string{}; };
    const std::string command = "{\"type\":\"recording-start\",\"operationID\":\"" + operation + "\",\"sequence\":1,\"recordingID\":\"" + operation + "\",\"path\":\"/private/job.wav\"}";
    assert(protocol.handle(command, apply).find("\"accepted\":true") != std::string::npos && calls == 1);
    assert(protocol.handle(command, apply).find("stale_sequence") != std::string::npos && calls == 1);
    assert(protocol.handle("{\"type\":\"controls\"}", apply).empty());
    assert(protocol.handle("{}", apply).find("missing_field") != std::string::npos);
    for (const auto &file : files) unlink(file.c_str()); rmdir(directory);
    std::cout << "PASS: synthetic PCM16 private/exclusive WAV, fixed mix/mute/gain, fractional clock, pause/resume stale-generation, discontinuity, disk/RIFF/overflow failures and recording protocol. No audio captured.\n";
}
