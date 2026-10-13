#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <bit>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

namespace {
constexpr uint64_t delay = 960;
constexpr uint32_t capacity = 32768, maximumFrames = 4096;
static_assert(std::atomic<uint64_t>::is_always_lock_free && std::atomic<uint32_t>::is_always_lock_free);
enum Phase : uint32_t { startup, warmup, steady, gap, stoppedWarm, stopped, restartWarm, restarted, phases };
const char* phaseNames[] = {"startup_consumer_only", "producer_warmup", "steady_epoch1", "intentional_zero_gap",
                            "producer_stop_settle", "producer_stopped_over_250ms", "restart_warmup", "steady_epoch2"};
struct Record {
    std::atomic<uint64_t> revision{0}, frame{UINT64_MAX};
    std::atomic<uint32_t> epoch{0};
};
struct Ledger {
    std::array<Record, capacity> records;
    void publish(uint64_t frame, uint32_t epoch) noexcept {
        auto& slot = records[frame % capacity];
        auto version = slot.revision.load();
        slot.revision.store(version + 1); slot.frame.store(frame); slot.epoch.store(epoch);
        slot.revision.store(version + 2);
    }
    bool find(uint64_t frame, uint32_t& epoch) const noexcept {
        const auto& slot = records[frame % capacity];
        auto before = slot.revision.load(), stamp = slot.frame.load();
        epoch = slot.epoch.load();
        auto after = slot.revision.load();
        return before && !(before & 1) && before == after && stamp == frame;
    }
};
float signal(uint64_t frame, uint32_t channel, uint32_t epoch) noexcept {
    if (!epoch) return 0;
    uint64_t x = frame ^ (uint64_t(channel + 1) * 0x9e3779b97f4a7c15ULL) ^ (uint64_t(epoch) << 48);
    x ^= x >> 30; x *= 0xbf58476d1ce4e5b9ULL; x ^= x >> 27; x *= 0x94d049bb133111ebULL; x ^= x >> 31;
    const float amplitude = float(1024 + (x & 8191)) / 524288.0f;
    return x & 8192 ? -amplitude : amplitude; // Nonzero, <= 0.0175763 normalized.
}
struct Counts {
    std::atomic<uint64_t> frames{0}, matched{0}, mismatched{0}, noProducerStamp{0}, zero{0}, nonzero{0}, nonFinite{0};
    std::atomic<uint32_t> maximumErrorBits{0};
};
struct Endpoint {
    const char* uid;
    bool producer;
    bool hidden;
    uint32_t channels;
    AudioDeviceID device = kAudioObjectUnknown;
    AudioDeviceIOProcID proc = nullptr;
    bool started = false;
    Ledger* ledger;
    std::atomic<uint32_t>* phase;
    std::atomic<uint32_t>* epoch;
    std::array<Counts, phases> counts;
    std::atomic<uint64_t> callbacks{0}, invalidTime{0}, invalidLayout{0}, overlap{0}, discontinuities{0};
    std::atomic<uint64_t> firstStamp{UINT64_MAX}, lastEnd{0};
    std::atomic_flag entered = ATOMIC_FLAG_INIT;
    bool seen = false; uint64_t next = 0; // Protected by try-once callback guard.
    Endpoint(const char* u, bool p, bool h, uint32_t c, Ledger* l,
             std::atomic<uint32_t>* ph, std::atomic<uint32_t>* e)
        : uid(u), producer(p), hidden(h), channels(c), ledger(l), phase(ph), epoch(e) {}
};
bool index(const AudioTimeStamp* time, uint64_t& first) noexcept {
    if (!time || !(time->mFlags & kAudioTimeStampSampleTimeValid) || !std::isfinite(time->mSampleTime) ||
        time->mSampleTime < 0 || time->mSampleTime >= double(UINT64_MAX / 2) || std::floor(time->mSampleTime) != time->mSampleTime)
        return false;
    first = uint64_t(time->mSampleTime); return true;
}
bool layout(const AudioBufferList* list, uint32_t channels, uint32_t& frames) noexcept {
    if (!list || list->mNumberBuffers != 1) return false;
    const auto& buffer = list->mBuffers[0];
    if (buffer.mNumberChannels != channels || !buffer.mData || buffer.mDataByteSize % (4 * channels)) return false;
    frames = buffer.mDataByteSize / (4 * channels);
    return frames && frames <= maximumFrames;
}
void silenceOutput(AudioBufferList* output) noexcept {
    if (output && output->mNumberBuffers == 1 && output->mBuffers[0].mData &&
        output->mBuffers[0].mDataByteSize <= maximumFrames * 2 * sizeof(float))
        std::memset(output->mBuffers[0].mData, 0, output->mBuffers[0].mDataByteSize);
}
OSStatus callback(AudioDeviceID, const AudioTimeStamp*, const AudioBufferList* input, const AudioTimeStamp* inputTime,
                  AudioBufferList* output, const AudioTimeStamp* outputTime, void* context) noexcept {
    auto& endpoint = *static_cast<Endpoint*>(context);
    endpoint.callbacks.fetch_add(1);
    if (endpoint.entered.test_and_set()) { if (endpoint.producer) silenceOutput(output); endpoint.overlap.fetch_add(1); return kAudioHardwareIllegalOperationError; }
    struct Exit { std::atomic_flag& flag; ~Exit() { flag.clear(); } } exit{endpoint.entered};
    uint32_t frames = 0;
    if (!layout(endpoint.producer ? output : input, endpoint.channels, frames)) {
        if (endpoint.producer) silenceOutput(output);
        endpoint.invalidLayout.fetch_add(1); return kAudioHardwareIllegalOperationError;
    }
    auto* samples = static_cast<float*>(endpoint.producer ? output->mBuffers[0].mData : input->mBuffers[0].mData);
    uint64_t first = 0;
    if (!index(endpoint.producer ? outputTime : inputTime, first) || first > UINT64_MAX / 2 - frames ||
        (endpoint.seen && first < endpoint.next)) {
        if (endpoint.producer) std::fill_n(samples, size_t(frames) * endpoint.channels, 0.0f);
        endpoint.invalidTime.fetch_add(1); return kAudioHardwareIllegalOperationError;
    }
    if (endpoint.seen && first != endpoint.next) endpoint.discontinuities.fetch_add(1);
    if (!endpoint.seen) endpoint.firstStamp.store(first);
    endpoint.seen = true; endpoint.next = first + frames; endpoint.lastEnd.store(first + frames);
    const uint32_t phase = std::min(endpoint.phase->load(), uint32_t(phases - 1));
    auto& counts = endpoint.counts[phase];
    counts.frames.fetch_add(frames);
    if (endpoint.producer) {
        const auto epoch = endpoint.epoch->load();
        for (uint32_t i = 0; i < frames; ++i) {
            for (uint32_t c = 0; c < endpoint.channels; ++c) samples[size_t(i) * endpoint.channels + c] = signal(first + i, c, epoch);
            endpoint.ledger->publish(first + i, epoch);
        }
        return noErr;
    }
    for (uint32_t i = 0; i < frames; ++i) {
        bool allZero = true, finite = true;
        for (uint32_t c = 0; c < endpoint.channels; ++c) {
            const float sample = samples[size_t(i) * endpoint.channels + c];
            allZero &= sample == 0; finite &= std::isfinite(sample);
        }
        (allZero ? counts.zero : counts.nonzero).fetch_add(1);
        if (!finite) { counts.nonFinite.fetch_add(1); counts.mismatched.fetch_add(1); continue; }
        const bool mustBeSilent = phase == startup || phase == stopped;
        uint32_t epoch = 0;
        const uint64_t at = first + i;
        const bool stamped = at >= delay && endpoint.ledger->find(at - delay, epoch);
        if (!mustBeSilent && !stamped) { counts.noProducerStamp.fetch_add(1); continue; }
        float error = 0;
        for (uint32_t c = 0; c < endpoint.channels; ++c) {
            const float expected = mustBeSilent ? 0 : signal(at - delay, c, epoch);
            error = std::max(error, std::abs(samples[size_t(i) * endpoint.channels + c] - expected));
        }
        if (error > std::bit_cast<float>(counts.maximumErrorBits.load())) counts.maximumErrorBits.store(std::bit_cast<uint32_t>(error));
        (error <= 1e-6f ? counts.matched : counts.mismatched).fetch_add(1);
    }
    return noErr;
}
AudioObjectPropertyAddress address(AudioObjectPropertySelector selector, AudioObjectPropertyScope scope = kAudioObjectPropertyScopeGlobal) {
    return {selector, scope, kAudioObjectPropertyElementMain};
}
template<class T> T read(AudioObjectID object, AudioObjectPropertySelector selector, AudioObjectPropertyScope scope = kAudioObjectPropertyScopeGlobal) {
    T value{}; UInt32 bytes = sizeof(value); auto a = address(selector, scope);
    const OSStatus status = AudioObjectGetPropertyData(object, &a, 0, nullptr, &bytes, &value);
    if (status || bytes != sizeof(value)) throw std::runtime_error("property " + std::to_string(selector) + " failed: " + std::to_string(status));
    return value;
}
AudioDeviceID lookup(const char* uid) {
    auto string = CFStringCreateWithCString(nullptr, uid, kCFStringEncodingUTF8);
    if (!string) throw std::bad_alloc();
    AudioDeviceID id = kAudioObjectUnknown; UInt32 bytes = sizeof(id);
    auto a = address(kAudioHardwarePropertyTranslateUIDToDevice);
    auto status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, sizeof(string), &string, &bytes, &id);
    CFRelease(string);
    if (status || id == kAudioObjectUnknown) throw std::runtime_error(std::string("exact UID unavailable: ") + uid + " status=" + std::to_string(status));
    auto actual = read<CFStringRef>(id, kAudioDevicePropertyDeviceUID);
    string = CFStringCreateWithCString(nullptr, uid, kCFStringEncodingUTF8);
    bool equal = actual && string && CFEqual(actual, string);
    if (actual) CFRelease(actual); if (string) CFRelease(string);
    if (!equal) throw std::runtime_error("translated UID differs");
    return id;
}
void inspect(Endpoint& endpoint, bool requireIdle) {
    endpoint.device = lookup(endpoint.uid);
    const auto scope = endpoint.producer ? kAudioDevicePropertyScopeOutput : kAudioDevicePropertyScopeInput;
    const double rate = read<Float64>(endpoint.device, kAudioDevicePropertyNominalSampleRate);
    const auto hidden = read<UInt32>(endpoint.device, kAudioDevicePropertyIsHidden);
    const auto running = read<UInt32>(endpoint.device, kAudioDevicePropertyDeviceIsRunning);
    const auto alive = read<UInt32>(endpoint.device, kAudioDevicePropertyDeviceIsAlive);
    if (!alive) throw std::runtime_error("exact endpoint is not alive");
    auto streamsAddress = address(kAudioDevicePropertyStreams, scope);
    UInt32 size = 0;
    auto status = AudioObjectGetPropertyDataSize(endpoint.device, &streamsAddress, 0, nullptr, &size);
    if (status || size != sizeof(AudioStreamID)) throw std::runtime_error("expected one stream on exact endpoint");
    AudioStreamID stream = 0;
    status = AudioObjectGetPropertyData(endpoint.device, &streamsAddress, 0, nullptr, &size, &stream);
    if (status) throw std::runtime_error("stream lookup failed: " + std::to_string(status));
    for (auto selector : {kAudioStreamPropertyVirtualFormat, kAudioStreamPropertyPhysicalFormat}) {
        auto format = read<AudioStreamBasicDescription>(stream, selector);
        if (format.mFormatID != kAudioFormatLinearPCM || format.mSampleRate != 48000 || format.mChannelsPerFrame != endpoint.channels ||
            format.mBitsPerChannel != 32 || format.mFramesPerPacket != 1 || format.mBytesPerFrame != 4 * endpoint.channels ||
            format.mBytesPerPacket != format.mBytesPerFrame || !(format.mFormatFlags & kAudioFormatFlagIsFloat) ||
            !(format.mFormatFlags & kAudioFormatFlagIsPacked) || (format.mFormatFlags & (kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsBigEndian)))
            throw std::runtime_error("endpoint format is not 48k interleaved Float32");
    }
    if (rate != 48000 || bool(hidden) != endpoint.hidden) throw std::runtime_error("endpoint rate or visibility differs");
    if (!endpoint.producer && read<UInt32>(endpoint.device, kAudioDevicePropertyLatency, scope) != delay)
        throw std::runtime_error("input device does not declare expected 960-frame route delay");
    const auto plugin = read<AudioObjectID>(endpoint.device, kAudioObjectPropertyOwner);
    auto identity = read<CFStringRef>(plugin, kAudioPlugInPropertyBundleID);
    const bool ownPlugin = identity && CFEqual(identity, CFSTR("dev.hari.labvoice.audio"));
    if (identity) CFRelease(identity);
    if (!ownPlugin || read<UInt32>(endpoint.device, kAudioDevicePropertyTransportType) != kAudioDeviceTransportTypeVirtual ||
        read<UInt32>(endpoint.device, kAudioDevicePropertyClockDomain) != 0x4c564143)
        throw std::runtime_error("endpoint owner, virtual transport, or shared clock domain differs");
    if (requireIdle && running) throw std::runtime_error("endpoint is already running; close other Lab Voice clients before testing");
    std::printf("{\"uid\":\"%s\",\"deviceID\":%u,\"sampleRate\":48000,\"channels\":%u,\"hidden\":%s,\"running\":%s,\"alive\":%s,\"bufferFrames\":%u}\n",
                endpoint.uid, endpoint.device, endpoint.channels, hidden ? "true" : "false", running ? "true" : "false", alive ? "true" : "false",
                read<UInt32>(endpoint.device, kAudioDevicePropertyBufferFrameSize));
}
bool successful(const Endpoint& e) {
    if (e.callbacks.load() == 0 || e.invalidTime.load() || e.invalidLayout.load() || e.overlap.load()) return false;
    for (const auto& counts : e.counts) if (counts.nonFinite.load()) return false;
    if (e.producer) return e.counts[steady].frames.load() > 1000 && e.counts[restarted].frames.load() > 1000 &&
        e.counts[stopped].frames.load() == 0;
    for (auto phase : {startup, stopped}) if (!e.counts[phase].frames.load() || e.counts[phase].nonzero.load() || e.counts[phase].mismatched.load()) return false;
    for (auto phase : {steady, restarted}) if (e.counts[phase].matched.load() < 1000 || e.counts[phase].mismatched.load() || e.counts[phase].noProducerStamp.load()) return false;
    const auto& zeroGap = e.counts[gap];
    if (zeroGap.matched.load() < 1000 || zeroGap.zero.load() < 1000 || zeroGap.mismatched.load() || zeroGap.noProducerStamp.load()) return false;
    return true;
}
void report(const Endpoint& e) {
    std::printf("{\"uid\":\"%s\",\"callbacks\":%llu,\"invalidTimestamps\":%llu,\"layoutErrors\":%llu,\"overlapErrors\":%llu,\"timestampDiscontinuities\":%llu,\"sampleTimeRange\":",
        e.uid, (unsigned long long)e.callbacks.load(), (unsigned long long)e.invalidTime.load(), (unsigned long long)e.invalidLayout.load(),
        (unsigned long long)e.overlap.load(), (unsigned long long)e.discontinuities.load());
    if (e.firstStamp.load() == UINT64_MAX) std::printf("null");
    else std::printf("{\"firstFrame\":%llu,\"lastExclusiveFrame\":%llu}", (unsigned long long)e.firstStamp.load(), (unsigned long long)e.lastEnd.load());
    std::printf(",\"phases\":[");
    for (uint32_t i = 0; i < phases; ++i) {
        const auto& c = e.counts[i];
        std::printf("%s{\"phase\":\"%s\",\"frames\":%llu,\"matched\":%llu,\"mismatched\":%llu,\"noProducerStamp\":%llu,\"zeroFrames\":%llu,\"nonzeroFrames\":%llu,\"nonFiniteFrames\":%llu,\"maximumAbsoluteError\":%.9g}", i ? "," : "", phaseNames[i],
                    (unsigned long long)c.frames.load(), (unsigned long long)c.matched.load(), (unsigned long long)c.mismatched.load(),
                    (unsigned long long)c.noProducerStamp.load(), (unsigned long long)c.zero.load(), (unsigned long long)c.nonzero.load(), (unsigned long long)c.nonFinite.load(), std::bit_cast<float>(c.maximumErrorBits.load()));
    }
    std::printf("],\"checksPassed\":%s}\n", successful(e) ? "true" : "false");
}
struct Harness {
    std::atomic<uint32_t> phase{startup}, epoch{1};
    Ledger mono, stereo;
    Endpoint feed{"dev.hari.labvoice.feed", true, true, 1, &mono, &phase, &epoch};
    Endpoint microphone{"dev.hari.labvoice.microphone", false, false, 1, &mono, &phase, &epoch};
    Endpoint speaker{"dev.hari.labvoice.speaker", true, false, 2, &stereo, &phase, &epoch};
    Endpoint monitor{"dev.hari.labvoice.monitor", false, true, 2, &stereo, &phase, &epoch};
    std::array<Endpoint*, 4> all() { return {&feed, &microphone, &speaker, &monitor}; }
};
OSStatus start(Endpoint& e) { auto status = AudioDeviceStart(e.device, e.proc); if (!status) e.started = true; return status; }
OSStatus stop(Endpoint& e) { if (!e.started) return noErr; auto status = AudioDeviceStop(e.device, e.proc); if (!status) e.started = false; return status; }
void checkedStart(Endpoint& e) { auto status = start(e); if (status) throw std::runtime_error(std::string("AudioDeviceStart ") + e.uid + ": " + std::to_string(status)); }
void checkedStop(Endpoint& e) { auto status = stop(e); if (status) throw std::runtime_error(std::string("AudioDeviceStop ") + e.uid + ": " + std::to_string(status)); }
void interval(Harness& h, Phase phase, int milliseconds) { h.phase.store(phase); std::this_thread::sleep_for(std::chrono::milliseconds(milliseconds)); }
int run(bool audio) {
    // Contexts stay alive through process termination even if a host cleanup RPC
    // fails. No callback can race a freed context on an error path.
    auto* harness = new Harness;
    bool okay = true; std::vector<std::string> errors;
    const auto began = std::chrono::steady_clock::now();
    try {
        for (auto* endpoint : harness->all()) inspect(*endpoint, audio);
        if (!audio) {
            std::puts("{\"mode\":\"read-only-exact-uid-inventory\",\"deviceCount\":4,\"checksPassed\":true}");
            return 0;
        }
        for (auto* endpoint : harness->all()) {
            auto status = AudioDeviceCreateIOProcID(endpoint->device, callback, endpoint, &endpoint->proc);
            if (status) throw std::runtime_error(std::string("AudioDeviceCreateIOProcID ") + endpoint->uid + ": " + std::to_string(status));
        }
        checkedStart(harness->microphone); checkedStart(harness->monitor);
        interval(*harness, startup, 150);
        checkedStart(harness->feed); checkedStart(harness->speaker);
        interval(*harness, warmup, 100); interval(*harness, steady, 800);
        harness->epoch.store(0); interval(*harness, gap, 150);
        harness->phase.store(stoppedWarm); checkedStop(harness->feed); checkedStop(harness->speaker);
        interval(*harness, stoppedWarm, 350); interval(*harness, stopped, 150);
        harness->epoch.store(2); harness->phase.store(restartWarm);
        checkedStart(harness->feed); checkedStart(harness->speaker);
        interval(*harness, restartWarm, 100); interval(*harness, restarted, 800);
    } catch (const std::exception& error) { okay = false; errors.emplace_back(error.what()); }
    if (audio) {
        for (auto* endpoint : harness->all()) {
            auto status = stop(*endpoint);
            if (status) { okay = false; errors.emplace_back(std::string("cleanup stop ") + endpoint->uid + ": " + std::to_string(status)); }
            if (endpoint->proc) {
                status = AudioDeviceDestroyIOProcID(endpoint->device, endpoint->proc);
                if (status) { okay = false; errors.emplace_back(std::string("cleanup destroy ") + endpoint->uid + ": " + std::to_string(status)); }
            }
        }
        for (const auto* endpoint : harness->all()) { report(*endpoint); okay &= successful(*endpoint); }
    }
    for (const auto& error : errors) std::fprintf(stderr, "HAL test error: %s\n", error.c_str());
    const double elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - began).count();
    std::printf("{\"mode\":\"%s\",\"expectedRouteDelayFrames\":960,\"plannedMediaIntervalSeconds\":%.1f,\"elapsedSeconds\":%.6f,\"checksPassed\":%s}\n", audio ? "actual-hal-synthetic" : "read-only-exact-uid-inventory", audio ? 2.6 : 0.0, elapsed, okay ? "true" : "false");
    return okay ? 0 : 1;
}
void validLifecycleMock() {
    auto h = std::make_unique<Harness>();
    for (auto pair : {std::pair{&h->feed, &h->microphone}, std::pair{&h->speaker, &h->monitor}}) {
        auto* producer = pair.first; auto* reader = pair.second;
        std::array<float, 960> samples{};
        AudioBufferList buffers{}; buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = {producer->channels, uint32_t(480 * producer->channels * sizeof(float)), samples.data()};
        AudioTimeStamp out{}, in{}; out.mFlags = in.mFlags = kAudioTimeStampSampleTimeValid;
        uint64_t frame = 10000;
        h->phase.store(startup);
        for (int block = 0; block < 3; ++block) {
            in.mSampleTime = double(frame + delay - 1440 + 480 * block);
            assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, reader) == noErr);
        }
        auto transfer = [&](Phase phase, uint32_t epoch) {
            h->phase.store(phase); h->epoch.store(epoch);
            for (int block = 0; block < 3; ++block, frame += 480) {
                out.mSampleTime = double(frame); in.mSampleTime = double(frame + delay);
                assert(callback(0, nullptr, nullptr, nullptr, &buffers, &out, producer) == noErr);
                assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, reader) == noErr);
            }
        };
        transfer(steady, 1); transfer(gap, 0);
        h->phase.store(stopped);
        for (int block = 0; block < 3; ++block, frame += 480) {
            in.mSampleTime = double(frame + delay);
            assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, reader) == noErr);
        }
        transfer(restarted, 2);
        assert(successful(*producer)); assert(successful(*reader));
    }
}
int mocks() {
    validLifecycleMock();
    auto h = std::make_unique<Harness>();
    for (auto pair : {std::pair{&h->feed, &h->microphone}, std::pair{&h->speaker, &h->monitor}}) {
        auto* producer = pair.first; auto* reader = pair.second;
        std::array<float, 960> samples{};
        AudioBufferList buffers{}; buffers.mNumberBuffers = 1;
        buffers.mBuffers[0] = {producer->channels, uint32_t(480 * producer->channels * sizeof(float)), samples.data()};
        AudioTimeStamp out{}, in{}; out.mFlags = in.mFlags = kAudioTimeStampSampleTimeValid;
        out.mSampleTime = 10000; in.mSampleTime = out.mSampleTime + delay;
        h->phase.store(startup);
        in.mSampleTime = 2000;
        assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, reader) == noErr);
        assert(reader->counts[startup].matched.load() == 480);
        in.mSampleTime = out.mSampleTime + delay;
        h->phase.store(steady);
        assert(callback(0, nullptr, nullptr, nullptr, &buffers, &out, producer) == noErr);
        assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, reader) == noErr);
        assert(reader->counts[steady].matched.load() == 480);
        for (uint32_t c = 0; c < producer->channels; ++c) assert(std::abs(samples[c]) < .02f && samples[c] != 0);
        out.mSampleTime += 480; in.mSampleTime += 480;
        assert(callback(0, nullptr, nullptr, nullptr, &buffers, &out, producer) == noErr);
        samples[0] += .1f;
        assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, reader) == noErr);
        assert(reader->counts[steady].mismatched.load() == 1);
        h->epoch.store(0); h->phase.store(gap); out.mSampleTime += 480; in.mSampleTime += 480;
        assert(callback(0, nullptr, nullptr, nullptr, &buffers, &out, producer) == noErr);
        assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, reader) == noErr);
        assert(reader->counts[gap].zero.load() == 480 && reader->counts[gap].matched.load() == 480);
        h->phase.store(stopped); in.mSampleTime += 480;
        assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, reader) == noErr);
        assert(reader->counts[stopped].matched.load() == 480);
        in.mFlags = 0;
        assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, reader) != noErr);
        assert(reader->invalidTime.load() == 1);
        assert(!successful(*reader)); // Deliberate wrong sample and timestamp cannot produce a pass.
        h->epoch.store(1);
        out.mSampleTime = 10000 + capacity;
        assert(callback(0, nullptr, nullptr, nullptr, &buffers, &out, producer) == noErr);
        Endpoint oldRead{reader->uid, false, reader->hidden, reader->channels, reader->ledger, reader->phase, reader->epoch};
        h->phase.store(steady); in.mFlags = kAudioTimeStampSampleTimeValid; in.mSampleTime = 10000 + delay;
        assert(callback(0, nullptr, &buffers, &in, nullptr, nullptr, &oldRead) == noErr);
        assert(oldRead.counts[steady].noProducerStamp.load() == 480);
        assert(!successful(oldRead)); // Overwritten ledger samples cannot count as matched.
    }
    std::puts("mock callback checks passed: exact 960-frame pairing, mono/stereo, low amplitude, zero gap, startup/stopped silence, deliberate mismatch, timestamp rejection, overwritten ledger detection, valid lifecycle verdict");
    return 0;
}
}
int main(int argc, char** argv) {
    if (argc == 1 || (argc == 2 && std::strcmp(argv[1], "--inventory") == 0)) return run(false);
    if (argc == 2 && std::strcmp(argv[1], "--run") == 0) return run(true);
    if (argc == 2 && std::strcmp(argv[1], "--self-test") == 0) return mocks();
    std::fprintf(stderr, "Usage: LabVoiceHALTest [--inventory | --run | --self-test]\n--run opens only four exact Lab Voice virtual UIDs for a 2.6-second synthetic interval.\n");
    return 2;
}
