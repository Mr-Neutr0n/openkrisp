#include <CoreAudio/AudioHardware.h>
#include <CoreAudio/AudioServerPlugIn.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <array>
#include <atomic>
#include <cassert>
#include <cstring>
#include <dlfcn.h>
#include <iostream>
#include <limits>
#include <vector>

#include <chrono>
#include <thread>

static unsigned notifications = 0;
static OSStatus changed(AudioServerPlugInHostRef, AudioObjectID, UInt32 n,
                        const AudioObjectPropertyAddress *) {
    notifications += n;
    return noErr;
}
static AudioObjectPropertyAddress address(UInt32 selector,
                                          UInt32 scope = kAudioObjectPropertyScopeGlobal) {
    return {selector, scope, 0};
}
template <class T>
T read(AudioServerPlugInDriverRef d, AudioObjectID id, UInt32 selector,
       UInt32 scope = kAudioObjectPropertyScopeGlobal) {
    auto a = address(selector, scope);
    T result{};
    UInt32 size = 0;
    assert((*d)->HasProperty(d, id, 0, &a));
    assert((*d)->GetPropertyDataSize(d, id, 0, &a, 0, nullptr, &size) == noErr &&
           size == sizeof(T));
    assert((*d)->GetPropertyData(d, id, 0, &a, 0, nullptr, sizeof result, &size, &result) ==
               noErr &&
           size == sizeof(T));
    return result;
}
// Replays the two-scope discovery reads observed in the real HAL trace. An
// absent direction has no streams and zero latency, but its scalar properties
// still exist so HAL can finish constructing a single-direction device.
static void discoveryProperties(AudioServerPlugInDriverRef d) {
    for (auto id : {2u, 3u, 6u, 7u}) {
        const bool input = id == 2 || id == 7;
        const bool hidden = id == 6 || id == 7;
        assert(read<UInt32>(d, id, kAudioDevicePropertyTransportType) ==
               kAudioDeviceTransportTypeVirtual);
        for (auto scope : {kAudioObjectPropertyScopeOutput, kAudioObjectPropertyScopeInput}) {
            const bool direction = scope == (input ? kAudioObjectPropertyScopeInput
                                                  : kAudioObjectPropertyScopeOutput);
            // Zoom and Control Center query transport metadata using direction
            // scopes. Their real reads must agree with the global device type.
            assert(read<UInt32>(d, id, kAudioDevicePropertyTransportType, scope) ==
                   kAudioDeviceTransportTypeVirtual);
            assert(read<UInt32>(d, id, kAudioDevicePropertySafetyOffset, scope) == 0);
            assert(read<UInt32>(d, id, kAudioDevicePropertyLatency, scope) ==
                   (direction && input ? 960u : 0u));
            assert(read<UInt32>(d, id, kAudioDevicePropertyDeviceCanBeDefaultDevice, scope) ==
                   UInt32(direction && !hidden));
            assert(read<UInt32>(d, id, kAudioDevicePropertyDeviceCanBeDefaultSystemDevice, scope) ==
                   UInt32(direction && !input && !hidden));
            auto streams = address(kAudioDevicePropertyStreams, scope);
            UInt32 bytes = 99;
            assert((*d)->HasProperty(d, id, 0, &streams));
            assert((*d)->GetPropertyDataSize(d, id, 0, &streams, 0, nullptr, &bytes) == noErr);
            assert(bytes == (direction ? sizeof(AudioObjectID) : 0));
            AudioObjectID stream = 99;
            assert((*d)->GetPropertyData(d, id, 0, &streams, 0, nullptr, sizeof stream,
                                         &bytes, &stream) == noErr);
            assert(direction ? stream == (id == 2 ? 4u : id == 3 ? 5u : id == 6 ? 8u : 9u)
                             : stream == 99);
            auto configuration = address(kAudioDevicePropertyStreamConfiguration, scope);
            AudioBufferList buffers{};
            assert((*d)->GetPropertyData(d, id, 0, &configuration, 0, nullptr,
                                         sizeof buffers, &bytes, &buffers) == noErr);
            assert(buffers.mNumberBuffers == UInt32(direction));
            assert(bytes == (direction ? sizeof buffers : offsetof(AudioBufferList, mBuffers)));
            if (direction)
                assert(buffers.mBuffers[0].mNumberChannels == (id == 2 || id == 6 ? 1u : 2u));
        }
        for (auto selector : {kAudioDevicePropertySafetyOffset, kAudioDevicePropertyLatency,
                              kAudioDevicePropertyDeviceCanBeDefaultDevice,
                              kAudioDevicePropertyDeviceCanBeDefaultSystemDevice}) {
            auto scalar = address(selector);
            UInt32 bytes = 0;
            UInt32 value = 99;
            assert(!(*d)->HasProperty(d, id, 0, &scalar));
            assert((*d)->GetPropertyDataSize(d, id, 0, &scalar, 0, nullptr, &bytes) ==
                   kAudioHardwareUnknownPropertyError);
            assert((*d)->GetPropertyData(d, id, 0, &scalar, 0, nullptr, sizeof value, &bytes,
                                         &value) == kAudioHardwareUnknownPropertyError);
            scalar.mScope = kAudioObjectPropertyScopeInput;
            assert((*d)->GetPropertyData(d, id, 0, &scalar, 0, nullptr, sizeof value - 1,
                                         &bytes, &value) == kAudioHardwareBadPropertySizeError);
            assert(value == 99);
            scalar.mElement = 1;
            assert(!(*d)->HasProperty(d, id, 0, &scalar));
        }
    }
    std::cout << "PASS: all-device discovery scopes, latency, default eligibility, empty directions\n";
}
static void routing(AudioServerPlugInDriverRef d) {
    for (auto id : {2u, 3u, 6u, 7u}) {
        AudioServerPlugInClientInfo client{};
        client.mClientID = 21;
        assert((*d)->AddDeviceClient(d, id, &client) == noErr);
        assert((*d)->StartIO(d, id, 21) == noErr);
    }
    assert(read<UInt32>(d, 6, kAudioDevicePropertyIsHidden) == 1);
    assert(read<UInt32>(d, 7, kAudioDevicePropertyIsHidden) == 1);
    assert(read<UInt32>(d, 2, kAudioDevicePropertyIsHidden) == 0);
    assert(read<UInt32>(d, 6, kAudioDevicePropertyDeviceCanBeDefaultDevice,
                        kAudioObjectPropertyScopeOutput) == 0);
    assert(read<UInt32>(d, 2, kAudioDevicePropertyLatency, kAudioObjectPropertyScopeInput) == 960);
    auto feedUID = read<CFStringRef>(d, 6, kAudioDevicePropertyDeviceUID);
    assert(CFEqual(feedUID, CFSTR("dev.hari.labvoice.feed")));
    CFRelease(feedUID);
    auto monitorUID = read<CFStringRef>(d, 7, kAudioDevicePropertyDeviceUID);
    assert(CFEqual(monitorUID, CFSTR("dev.hari.labvoice.monitor")));
    CFRelease(monitorUID);
    assert(read<AudioStreamBasicDescription>(d, 8, kAudioStreamPropertyVirtualFormat)
               .mChannelsPerFrame == 1);
    assert(read<AudioStreamBasicDescription>(d, 9, kAudioStreamPropertyVirtualFormat)
               .mChannelsPerFrame == 2);
    AudioServerPlugInIOCycleInfo cycle{};
    cycle.mInputTime.mFlags = kAudioTimeStampSampleTimeValid;
    cycle.mOutputTime.mFlags = kAudioTimeStampSampleTimeValid;
    cycle.mOutputTime.mSampleTime = 1024;
    // Deliberately unrelated nominal count and current timestamp.
    cycle.mNominalIOBufferFrameSize = 17;
    cycle.mCurrentTime.mSampleTime = 999999;
    float mono[] = {0.125f, -0.25f, 0.5f, 0.75f};
    float stereo[] = {0.125f, -0.5f, 0.25f, -0.75f, 0.375f, -0.25f, 0.5f, -0.125f};
    float got[8]{};
    cycle.mOutputTime.mSampleTime = 0;
    assert((*d)->DoIOOperation(d, 6, 8, 21, kAudioServerPlugInIOOperationWriteMix, 4, &cycle, mono,
                               nullptr) == noErr);
    cycle.mInputTime.mSampleTime = 958;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 8, &cycle, got,
                               nullptr) == noErr);
    assert(got[0] == 0 && got[1] == 0 && got[6] == 0 && got[7] == 0);
    assert(std::memcmp(got + 2, mono, sizeof mono) == 0);
    cycle.mOutputTime.mSampleTime = 1024;
    assert((*d)->DoIOOperation(d, 6, 8, 21, kAudioServerPlugInIOOperationWriteMix, 4, &cycle, mono,
                               nullptr) == noErr);
    assert((*d)->DoIOOperation(d, 3, 5, 21, kAudioServerPlugInIOOperationWriteMix, 4, &cycle,
                               stereo, nullptr) == noErr);
    cycle.mInputTime.mSampleTime = 1984;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    assert(std::memcmp(got, mono, sizeof mono) == 0);
    assert((*d)->DoIOOperation(d, 7, 9, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    assert(std::memcmp(got, stereo, sizeof stereo) == 0);
    // Read the same writer frame without the fixed delay: it must be a gap.
    cycle.mInputTime.mSampleTime = 1024;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    for (unsigned i = 0; i < 4; ++i)
        assert(got[i] == 0);
    // Forward producer jump leaves holes at 1028..1031.
    cycle.mOutputTime.mSampleTime = 1032;
    assert((*d)->DoIOOperation(d, 6, 8, 21, kAudioServerPlugInIOOperationWriteMix, 4, &cycle, mono,
                               nullptr) == noErr);
    cycle.mInputTime.mSampleTime = 1988;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    for (unsigned i = 0; i < 4; ++i)
        assert(got[i] == 0);
    // Duplicate or backward producer timestamps fail rather than overwrite.
    assert((*d)->DoIOOperation(d, 6, 8, 21, kAudioServerPlugInIOOperationWriteMix, 4, &cycle, mono,
                               nullptr) != noErr);
    assert((*d)->StopIO(d, 6, 21) == noErr);
    cycle.mInputTime.mSampleTime = 1992;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    for (unsigned i = 0; i < 4; ++i)
        assert(got[i] == 0);
    assert((*d)->StartIO(d, 6, 21) == noErr);
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    for (unsigned i = 0; i < 4; ++i)
        assert(got[i] == 0);
    cycle.mOutputTime.mSampleTime = 1040;
    assert((*d)->DoIOOperation(d, 6, 8, 21, kAudioServerPlugInIOOperationWriteMix, 4, &cycle, mono,
                               nullptr) == noErr);
    cycle.mInputTime.mSampleTime = 2000;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    assert(std::memcmp(got, mono, sizeof mono) == 0);
    std::this_thread::sleep_for(std::chrono::milliseconds(260));
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    for (unsigned i = 0; i < 4; ++i)
        assert(got[i] == 0);
    // Publish beyond one ring revolution. The old exact frame stamp must fail.
    std::vector<float> block(4096, 0.625f);
    for (unsigned i = 0; i < 9; ++i) {
        cycle.mOutputTime.mSampleTime = 4096 + i * 4096;
        assert((*d)->DoIOOperation(d, 6, 8, 21, kAudioServerPlugInIOOperationWriteMix, 4096, &cycle,
                                   block.data(), nullptr) == noErr);
    }
    cycle.mInputTime.mSampleTime = 2000;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    for (unsigned i = 0; i < 4; ++i)
        assert(got[i] == 0);
    cycle.mInputTime.mSampleTime = 4096 + 8 * 4096 + 960;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) == noErr);
    for (unsigned i = 0; i < 4; ++i)
        assert(got[i] == 0.625f);
    cycle.mInputTime.mFlags = 0;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) != noErr);
    cycle.mInputTime.mFlags = kAudioTimeStampSampleTimeValid;
    cycle.mInputTime.mSampleTime = 0.5;
    assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle, got,
                               nullptr) != noErr);
    for (double invalid : {-1.0, std::numeric_limits<double>::infinity(),
                           std::numeric_limits<double>::quiet_NaN()}) {
        cycle.mInputTime.mSampleTime = invalid;
        assert((*d)->DoIOOperation(d, 2, 4, 21, kAudioServerPlugInIOOperationReadInput, 4, &cycle,
                                   got, nullptr) == kAudioHardwareIllegalOperationError);
    }
    assert(read<UInt32>(d, 7, kAudioDevicePropertyLatency, kAudioObjectPropertyScopeInput) == 960);
    assert(read<UInt32>(d, 4, kAudioStreamPropertyLatency) == 0);
    assert(read<UInt32>(d, 9, kAudioStreamPropertyLatency) == 0);
    assert(read<UInt32>(d, 3, kAudioDevicePropertyLatency, kAudioObjectPropertyScopeOutput) == 0);
    for (auto id : {2u, 3u, 6u, 7u}) {
        AudioServerPlugInClientInfo client{};
        client.mClientID = 21;
        assert((*d)->RemoveDeviceClient(d, id, &client) == noErr);
        assert(read<UInt32>(d, id, kAudioDevicePropertyDeviceIsRunning) == 0);
    }
    std::cout << "PASS: mono feed to mic, stereo speaker to monitor, fixed timestamp delay, gaps, "
                 "duplicate rejection, stop/restart invalidation, stale silence, ring overwrite, "
                 "startup prefix, invalid timestamps\n";
}
using SetWriteHook = void (*)(void (*)(void *), void *);
struct WriteBarrier {
    std::atomic<bool> entered{false};
    std::atomic<bool> release{false};
};
static void pauseWriter(void *context) {
    auto &barrier = *static_cast<WriteBarrier *>(context);
    barrier.entered.store(true, std::memory_order_release);
    while (!barrier.release.load(std::memory_order_acquire))
        std::this_thread::yield();
}
static void lifecycleRace(AudioServerPlugInDriverRef d, SetWriteHook hook) {
    AudioServerPlugInClientInfo client{};
    client.mClientID = 31;
    for (auto id : {2u, 6u}) {
        assert((*d)->AddDeviceClient(d, id, &client) == noErr);
        assert((*d)->StartIO(d, id, 31) == noErr);
    }
    AudioServerPlugInIOCycleInfo writeCycle{}, readCycle{};
    writeCycle.mOutputTime.mFlags = kAudioTimeStampSampleTimeValid;
    readCycle.mInputTime.mFlags = kAudioTimeStampSampleTimeValid;
    float oldSamples[4] = {0.875f, 0.75f, 0.625f, 0.5f};
    float newSamples[4] = {-0.125f, -0.25f, -0.375f, -0.5f};
    float got[4]{};
    writeCycle.mOutputTime.mSampleTime = 45000;
    assert((*d)->DoIOOperation(d, 6, 8, 31, kAudioServerPlugInIOOperationWriteMix, 4, &writeCycle,
                               oldSamples, nullptr) == noErr);
    WriteBarrier barrier;
    hook(pauseWriter, &barrier);
    writeCycle.mOutputTime.mSampleTime = 50000;
    OSStatus delayedResult = noErr;
    std::thread inFlight([&] {
        delayedResult = (*d)->DoIOOperation(d, 6, 8, 31, kAudioServerPlugInIOOperationWriteMix, 4,
                                            &writeCycle, oldSamples, nullptr);
    });
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (!barrier.entered.load(std::memory_order_acquire)) {
        assert(std::chrono::steady_clock::now() < deadline);
        std::this_thread::yield();
    }
    assert((*d)->StopIO(d, 6, 31) == noErr);
    assert((*d)->StartIO(d, 6, 31) == noErr);
    // Read concurrently with the paused writer after stop/start has completed.
    readCycle.mInputTime.mSampleTime = 45960;
    assert((*d)->DoIOOperation(d, 2, 4, 31, kAudioServerPlugInIOOperationReadInput, 4, &readCycle,
                               got, nullptr) == noErr);
    for (float v : got)
        assert(v == 0);
    barrier.release.store(true, std::memory_order_release);
    inFlight.join();
    hook(nullptr, nullptr);
    assert(delayedResult == kAudioHardwareNotRunningError);
    readCycle.mInputTime.mSampleTime = 50960;
    assert((*d)->DoIOOperation(d, 2, 4, 31, kAudioServerPlugInIOOperationReadInput, 4, &readCycle,
                               got, nullptr) == noErr);
    for (float v : got)
        assert(v == 0);
    writeCycle.mOutputTime.mSampleTime = 50004;
    assert((*d)->DoIOOperation(d, 6, 8, 31, kAudioServerPlugInIOOperationWriteMix, 4, &writeCycle,
                               newSamples, nullptr) == noErr);
    // Publishing the new generation still cannot expose the late old write.
    assert((*d)->DoIOOperation(d, 2, 4, 31, kAudioServerPlugInIOOperationReadInput, 4, &readCycle,
                               got, nullptr) == noErr);
    for (float v : got)
        assert(v == 0);
    readCycle.mInputTime.mSampleTime = 50964;
    assert((*d)->DoIOOperation(d, 2, 4, 31, kAudioServerPlugInIOOperationReadInput, 4, &readCycle,
                               got, nullptr) == noErr);
    assert(std::memcmp(got, newSamples, sizeof got) == 0);
    for (auto id : {2u, 6u})
        assert((*d)->RemoveDeviceClient(d, id, &client) == noErr);
    std::cout << "PASS: paused pre-stop write, concurrent stop/start/read, late publication "
                 "rejection, new generation recovery\n";
}
int main(int argc, char **argv) {
    assert(argc == 2);
    auto library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        std::cerr << dlerror() << '\n';
        return 1;
    }
    auto factory =
        reinterpret_cast<void *(*)(CFAllocatorRef, CFUUIDRef)>(dlsym(library, "LabVoiceFactory"));
    assert(factory);
    assert(factory(nullptr, CFUUIDGetConstantUUIDWithBytes(nullptr, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                                           0, 0, 0, 0, 0)) == nullptr);
    auto d = static_cast<AudioServerPlugInDriverRef>(factory(nullptr, kAudioServerPlugInTypeUUID));
    assert(d && *d);
    void *queried = nullptr;
    assert((*d)->QueryInterface(d, CFUUIDGetUUIDBytes(kAudioServerPlugInDriverInterfaceUUID),
                                &queried) == S_OK &&
           queried == d);
    (*d)->Release(d);
    AudioServerPlugInHostInterface host{};
    host.PropertiesChanged = changed;
    assert((*d)->Initialize(d, &host) == noErr);
    discoveryProperties(d);
    // HAL discovery requests children by class. Streams are not controls or boxes.
    auto owned = address(kAudioObjectPropertyOwnedObjects);
    AudioClassID qualifier = kAudioBoxClassID;
    UInt32 ownedSize = 999;
    assert((*d)->GetPropertyDataSize(d, 1, 0, &owned, sizeof qualifier, &qualifier, &ownedSize) == noErr);
    assert(ownedSize == 0);
    qualifier = kAudioControlClassID;
    assert((*d)->GetPropertyDataSize(d, 2, 0, &owned, sizeof qualifier, &qualifier, &ownedSize) == noErr);
    assert(ownedSize == 0);
    qualifier = kAudioDeviceClassID;
    assert((*d)->GetPropertyDataSize(d, 1, 0, &owned, sizeof qualifier, &qualifier, &ownedSize) == noErr);
    assert(ownedSize == 4 * sizeof(AudioObjectID));
    qualifier = kAudioStreamClassID;
    AudioObjectID child = 0;
    assert((*d)->GetPropertyData(d, 2, 0, &owned, sizeof qualifier, &qualifier, sizeof child, &ownedSize, &child) == noErr);
    assert(ownedSize == sizeof child && child == 4);
    qualifier = kAudioObjectClassID;
    assert((*d)->GetPropertyDataSize(d, 2, 0, &owned, sizeof qualifier, &qualifier, &ownedSize) == noErr && ownedSize == sizeof child);
    AudioClassID qualifiers[] = {kAudioControlClassID, kAudioStreamClassID};
    assert((*d)->GetPropertyDataSize(d, 2, 0, &owned, sizeof qualifiers, qualifiers, &ownedSize) == noErr && ownedSize == sizeof child);
    assert((*d)->GetPropertyDataSize(d, 2, 0, &owned, 1, &qualifier, &ownedSize) == kAudioHardwareBadPropertySizeError);
    auto ids = read<std::array<AudioObjectID, 4>>(d, 1, kAudioPlugInPropertyDeviceList);
    assert(ids[0] == 2 && ids[1] == 3);
    auto micUID = read<CFStringRef>(d, 2, kAudioDevicePropertyDeviceUID);
    assert(CFEqual(micUID, CFSTR("dev.hari.labvoice.microphone")));
    CFRelease(micUID);
    auto speakerUID = read<CFStringRef>(d, 3, kAudioDevicePropertyDeviceUID);
    assert(CFEqual(speakerUID, CFSTR("dev.hari.labvoice.speaker")));
    CFRelease(speakerUID);
    auto a = address(kAudioPlugInPropertyTranslateUIDToDevice);
    CFStringRef uid = CFSTR("dev.hari.labvoice.microphone");
    UInt32 n = 0;
    AudioObjectID translated = 0;
    assert((*d)->GetPropertyData(d, 1, 0, &a, sizeof uid, &uid, sizeof translated, &n,
                                 &translated) == noErr &&
           translated == 2);
    for (AudioObjectID sid : {4u, 5u}) {
        auto f = read<AudioStreamBasicDescription>(d, sid, kAudioStreamPropertyVirtualFormat);
        assert(f.mSampleRate == 48000 && f.mFormatFlags == 9 && f.mBitsPerChannel == 32 &&
               f.mChannelsPerFrame == (sid == 4 ? 1u : 2u));
        assert(f.mBytesPerFrame == f.mChannelsPerFrame * 4);
    }
    assert(read<UInt32>(d, 2, kAudioDevicePropertyDeviceIsAlive) == 1);
    assert(read<UInt32>(d, 2, kAudioDevicePropertyZeroTimeStampPeriod) >= 10923);
    assert(read<UInt32>(d, 2, kAudioDevicePropertyDeviceIsRunning) == 0);
    auto unknown = address('xxxx');
    assert(!(*d)->HasProperty(d, 2, 0, &unknown));
    assert(!(*d)->HasProperty(d, 99, 0, &a));
    a = address(kAudioStreamPropertyVirtualFormat);
    Boolean writable = true;
    assert((*d)->IsPropertySettable(d, 4, 0, &a, &writable) == noErr && !writable);
    char tiny = 0;
    assert((*d)->GetPropertyData(d, 4, 0, &a, 0, nullptr, 1, &n, &tiny) ==
           kAudioHardwareBadPropertySizeError);
    assert((*d)->SetPropertyData(d, 4, 0, &a, 0, nullptr, 1, &tiny) ==
           kAudioHardwareUnsupportedOperationError);
    a = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput);
    assert((*d)->GetPropertyDataSize(d, 2, 0, &a, 0, nullptr, &n) == noErr && n == 0);
    AudioServerPlugInClientInfo client{};
    client.mClientID = 7;
    AudioServerPlugInClientInfo second{};
    second.mClientID = 8;
    assert((*d)->StartIO(d, 2, 7) != noErr);
    for (auto id : {2u, 3u}) {
        assert((*d)->AddDeviceClient(d, id, &client) == noErr);
        assert((*d)->StartIO(d, id, 7) == noErr);
    }
    assert((*d)->AddDeviceClient(d, 2, &second) == noErr);
    assert((*d)->StartIO(d, 2, 8) == noErr);
    assert((*d)->StartIO(d, 2, 8) == noErr);
    assert((*d)->StopIO(d, 2, 7) == noErr &&
           read<UInt32>(d, 2, kAudioDevicePropertyDeviceIsRunning) == 1);
    Boolean yes = false, inplace = false;
    assert((*d)->WillDoIOOperation(d, 2, 8, kAudioServerPlugInIOOperationReadInput, &yes,
                                   &inplace) == noErr &&
           yes && inplace);
    assert((*d)->WillDoIOOperation(d, 2, 8, kAudioServerPlugInIOOperationWriteMix, &yes,
                                   &inplace) == noErr &&
           !yes);
    AudioServerPlugInIOCycleInfo cycle{};
    cycle.mInputTime.mFlags = kAudioTimeStampSampleTimeValid;
    cycle.mOutputTime.mFlags = kAudioTimeStampSampleTimeValid;
    std::vector<float> mono(482, 0.25f);
    std::vector<float> stereo(1024, 0.25f);
    assert((*d)->BeginIOOperation(d, 2, 8, kAudioServerPlugInIOOperationReadInput, 480, &cycle) ==
           noErr);
    assert((*d)->DoIOOperation(d, 2, 4, 8, kAudioServerPlugInIOOperationReadInput, 480, &cycle,
                               mono.data() + 1, nullptr) == noErr);
    assert(mono.front() == 0.25f && mono.back() == 0.25f);
    for (unsigned i = 1; i <= 480; ++i)
        assert(mono[i] == 0);
    assert((*d)->EndIOOperation(d, 2, 8, kAudioServerPlugInIOOperationReadInput, 480, &cycle) ==
           noErr);
    assert((*d)->DoIOOperation(d, 3, 5, 7, kAudioServerPlugInIOOperationWriteMix, 512, &cycle,
                               stereo.data(), nullptr) == noErr);
    for (float sample : stereo)
        assert(sample == 0.25f);
    assert((*d)->DoIOOperation(d, 2, 4, 8, kAudioServerPlugInIOOperationReadInput, 4097, &cycle,
                               mono.data(), nullptr) != noErr);
    assert((*d)->DoIOOperation(d, 2, 5, 8, kAudioServerPlugInIOOperationReadInput, 1, &cycle,
                               mono.data(), nullptr) != noErr);
    assert((*d)->DoIOOperation(d, 2, 4, 8, kAudioServerPlugInIOOperationReadInput, 1, &cycle,
                               nullptr, nullptr) != noErr);
    Float64 s1 = 0, s2 = 0;
    UInt64 t1 = 0, t2 = 0, seed1 = 0, seed2 = 0;
    assert((*d)->GetZeroTimeStamp(d, 2, 8, &s1, &t1, &seed1) == noErr);
    std::this_thread::sleep_for(std::chrono::milliseconds(360));
    assert((*d)->GetZeroTimeStamp(d, 2, 8, &s2, &t2, &seed2) == noErr && s2 > s1 && t2 > t1 &&
           seed1 == seed2 && static_cast<UInt64>(s2) % 16384 == 0);
    assert((*d)->RemoveDeviceClient(d, 2, &second) == noErr &&
           read<UInt32>(d, 2, kAudioDevicePropertyDeviceIsRunning) == 0);
    assert((*d)->DoIOOperation(d, 2, 4, 8, kAudioServerPlugInIOOperationReadInput, 1, &cycle,
                               mono.data(), nullptr) == kAudioHardwareNotRunningError);
    assert((*d)->StopIO(d, 3, 7) == noErr);
    assert((*d)->RemoveDeviceClient(d, 2, &client) == noErr);
    assert((*d)->RemoveDeviceClient(d, 3, &client) == noErr);
    assert(notifications == 8);
    routing(d);
    if (auto hook = reinterpret_cast<SetWriteHook>(dlsym(library, "LabVoiceTestSetWriteHook")))
        lifecycleRace(d, hook);
    (*d)->Release(d);
    std::cout << "PASS: loaded bundle factory, identities, formats, property sizes/scopes, client "
                 "lifecycle, notifications, timestamps, bounded routing callbacks\n";
    // Keep the module loaded until process exit. CoreFoundation may hold bundle-owned constants.
}
