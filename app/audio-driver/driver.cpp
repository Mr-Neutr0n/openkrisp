#include "../audio-transport/transport.hpp"
#include <CoreAudio/AudioHardware.h>
#include <CoreAudio/AudioServerPlugIn.h>
#include <CoreFoundation/CFPlugInCOM.h>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <limits>
#include <mach/mach_time.h>
#include <mutex>
#ifdef LABVOICE_DISCOVERY_TRACE
#include <os/log.h>
#endif
#ifndef LABVOICE_ROUTE_DELAY_FRAMES
#define LABVOICE_ROUTE_DELAY_FRAMES 960
#endif

namespace {
#ifdef LABVOICE_DISCOVERY_TRACE
std::atomic<unsigned> traceCount{0};
void discoveryTrace(const char *operation, AudioObjectID id,
                    const AudioObjectPropertyAddress *address, UInt32 qualifierSize,
                    const void *qualifier, OSStatus status, UInt32 size, const void *data) {
    const unsigned index = traceCount.fetch_add(1);
    if (index >= 512) return;
    UInt32 selectors[3]{};
    if (address) { selectors[0] = address->mSelector; selectors[1] = address->mScope; selectors[2] = address->mElement; }
    UInt32 classes[2]{}, values[4]{};
    if (address && address->mSelector == kAudioObjectPropertyOwnedObjects && qualifier)
        std::memcpy(classes, qualifier, std::min<size_t>(qualifierSize, sizeof classes));
    if (address && data && (address->mSelector == kAudioObjectPropertyClass ||
        address->mSelector == kAudioObjectPropertyBaseClass ||
        address->mSelector == kAudioObjectPropertyOwner ||
        address->mSelector == kAudioObjectPropertyOwnedObjects ||
        address->mSelector == kAudioPlugInPropertyDeviceList ||
        address->mSelector == kAudioDevicePropertyStreams ||
        address->mSelector == kAudioObjectPropertyControlList))
        std::memcpy(values, data, std::min<size_t>(size, sizeof values));
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT,
        "LVDiscovery n=%{public}u op=%{public}s id=%{public}u sel=%{public}08x scope=%{public}08x element=%{public}u qbytes=%{public}u q0=%{public}08x q1=%{public}08x status=%{public}d bytes=%{public}u v0=%{public}08x v1=%{public}08x v2=%{public}08x v3=%{public}08x",
        index, operation, id, selectors[0], selectors[1], selectors[2], qualifierSize,
        classes[0], classes[1], status, size, values[0], values[1], values[2], values[3]);
}
#define LV_TRACE(...) discoveryTrace(__VA_ARGS__)
#else
#define LV_TRACE(...) ((void)0)
#endif
static_assert(std::atomic<UInt32>::is_always_lock_free, "IO state must be lock-free");
constexpr AudioObjectID plugin = 1, mic = 2, speaker = 3, micStream = 4, speakerStream = 5,
                        feed = 6, monitor = 7, feedStream = 8, monitorStream = 9;
constexpr UInt32 maxFrames = 4096, period = 16384;
AudioServerPlugInDriverInterface interface;
AudioServerPlugInDriverInterface *interfacePointer = &interface;
AudioServerPlugInDriverRef driver = &interfacePointer;
std::atomic<ULONG> references{1};
AudioServerPlugInHostRef host = nullptr;
std::atomic<UInt64> anchor{0};
double ticksPerFrame = 0;
double nanosPerTick = 0;
constexpr UInt32 routeDelay = LABVOICE_ROUTE_DELAY_FRAMES;
constexpr UInt32 ringCapacity = 32768;
constexpr UInt64 staleAfterNs = 250000000;
static_assert(routeDelay < ringCapacity);
struct Route {
    krisp_local::Transport transport;
    std::atomic_flag writer = ATOMIC_FLAG_INIT;
    std::atomic<UInt64> generation{1};
    std::atomic<UInt64> publishedGeneration{0};
    std::atomic<UInt64> readFloor{0};
    explicit Route(UInt32 count) : transport(count, ringCapacity) {
    }
};
Route microphoneRoute{1};
Route speakerRoute{2};
std::mutex lifecycle;
struct Client {
    UInt32 id = 0;
    bool used = false;
    bool running = false;
};
struct DeviceState {
    Client clients[64];
    std::atomic<UInt32> running{0};
} states[4];
bool device(AudioObjectID id) {
    return id == mic || id == speaker || id == feed || id == monitor;
}
bool stream(AudioObjectID id) {
    return id == micStream || id == speakerStream || id == feedStream || id == monitorStream;
}
bool object(AudioObjectID id) {
    return id >= plugin && id <= monitorStream;
}
DeviceState &state(AudioObjectID id) {
    return states[id == mic ? 0 : id == speaker ? 1 : id == feed ? 2 : 3];
}
AudioObjectID streamID(AudioObjectID id) {
    return id == mic       ? micStream
           : id == speaker ? speakerStream
           : id == feed    ? feedStream
                           : monitorStream;
}
AudioObjectID deviceID(AudioObjectID id) {
    return device(id)            ? id
           : id == micStream     ? mic
           : id == speakerStream ? speaker
           : id == feedStream    ? feed
                                 : monitor;
}
AudioObjectID owner(AudioObjectID id) {
    return id == plugin ? kAudioObjectUnknown : device(id) ? plugin : deviceID(id);
}
bool input(AudioObjectID id) {
    return id == mic || id == micStream || id == monitor || id == monitorStream;
}
bool hidden(AudioObjectID id) {
    return id == feed || id == monitor || id == feedStream || id == monitorStream;
}
UInt32 channels(AudioObjectID id) {
    return id == mic || id == micStream || id == feed || id == feedStream ? 1 : 2;
}
CFStringRef deviceUID(AudioObjectID id) {
    switch (deviceID(id)) {
    case mic:
        return CFSTR("dev.hari.labvoice.microphone");
    case speaker:
        return CFSTR("dev.hari.labvoice.speaker");
    case feed:
        return CFSTR("dev.hari.labvoice.feed");
    default:
        return CFSTR("dev.hari.labvoice.monitor");
    }
}
CFStringRef objectName(AudioObjectID id) {
    if (id == plugin)
        return CFSTR("Lab Voice Audio");
    switch (deviceID(id)) {
    case mic:
        return CFSTR("Lab Voice Microphone");
    case speaker:
        return CFSTR("Lab Voice Speaker");
    case feed:
        return CFSTR("Lab Voice App Feed");
    default:
        return CFSTR("Lab Voice App Monitor");
    }
}
Route &routeFor(AudioObjectID id) {
    return id == mic || id == feed ? microphoneRoute : speakerRoute;
}
AudioObjectID producerFor(AudioObjectID id) {
    return id == mic || id == feed ? feed : speaker;
}
void invalidateRoute(AudioObjectID id) {
    if (id == feed || id == speaker)
        routeFor(id).generation.fetch_add(1, std::memory_order_acq_rel);
}
#ifdef LABVOICE_DRIVER_TEST_HOOKS
void (*writeHook)(void *) = nullptr;
void *writeHookContext = nullptr;
#endif
AudioStreamBasicDescription format(AudioObjectID id) {
    return {48000,
            kAudioFormatLinearPCM,
            kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            channels(id) * 4,
            1,
            channels(id) * 4,
            channels(id),
            32,
            0};
}
OSStatus valid(AudioServerPlugInDriverRef d, AudioObjectID id) {
    return d != driver || !object(id) ? OSStatus(kAudioHardwareBadObjectError) : OSStatus(noErr);
}

// Property shape is shared by HasProperty, size, and read; values are built only on read.
OSStatus propertyValue(AudioObjectID id, const AudioObjectPropertyAddress *a, UInt32 qsize,
                  const void *q, UInt32 capacity, UInt32 *size, void *data) {
    if (!object(id))
        return kAudioHardwareBadObjectError;
    if (!a || !size)
        return kAudioHardwareIllegalOperationError;
    if (a->mElement != kAudioObjectPropertyElementMain)
        return kAudioHardwareUnknownPropertyError;
    const auto s = a->mSelector;
    const auto scope = a->mScope;
    const bool global = scope == kAudioObjectPropertyScopeGlobal;
    const bool direction =
        scope == (input(id) ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput);
    auto put = [&](const void *p, UInt32 n) -> OSStatus {
        *size = n;
        if (!data)
            return noErr;
        if (capacity < n)
            return kAudioHardwareBadPropertySizeError;
        if (n)
            std::memcpy(data, p, n);
        return noErr;
    };
    auto scalar = [&](UInt32 v) { return put(&v, sizeof v); };
    auto str = [&](CFStringRef v) {
        if (data && capacity >= sizeof v)
            CFRetain(v);
        return put(&v, sizeof v);
    };
    if (global)
        switch (s) {
        case kAudioObjectPropertyBaseClass:
            return scalar(kAudioObjectClassID);
        case kAudioObjectPropertyClass:
            return scalar(id == plugin ? kAudioPlugInClassID
                          : device(id) ? UInt32(kAudioDeviceClassID)
                                       : UInt32(kAudioStreamClassID));
        case kAudioObjectPropertyOwner:
            return scalar(owner(id));
        case kAudioObjectPropertyName:
            return str(objectName(id));
        case kAudioObjectPropertyManufacturer:
            return str(CFSTR("Independent Audio Lab"));
        case kAudioObjectPropertyOwnedObjects: {
            if (qsize % sizeof(AudioClassID) || (qsize && !q))
                return kAudioHardwareBadPropertySizeError;
            const AudioObjectID candidates[] = {mic, speaker, feed, monitor};
            AudioObjectID ids[4]{};
            UInt32 count = 0;
            auto matches = [&](AudioClassID childClass) {
                if (!qsize) return true;
                for (UInt32 i = 0; i < qsize / sizeof(AudioClassID); ++i) {
                    // memcpy supports an unaligned qualifier buffer.
                    AudioClassID requested;
                    std::memcpy(&requested, static_cast<const char *>(q) + i * sizeof requested, sizeof requested);
                    if (requested == childClass || requested == kAudioObjectClassID) return true;
                }
                return false;
            };
            if (id == plugin && matches(kAudioDeviceClassID)) {
                std::copy(std::begin(candidates), std::end(candidates), ids);
                count = 4;
            } else if (device(id) && matches(kAudioStreamClassID)) {
                ids[0] = streamID(id);
                count = 1;
            }
            return put(ids, count * sizeof(AudioObjectID));
        }
        }
    if (id == plugin && global)
        switch (s) {
        case kAudioPlugInPropertyBundleID:
            return str(CFSTR("dev.hari.labvoice.audio"));
        case kAudioPlugInPropertyDeviceList: {
            AudioObjectID ids[] = {mic, speaker, feed, monitor};
            return put(ids, sizeof ids);
        }
        case kAudioPlugInPropertyTranslateUIDToDevice: {
            if (!data) {
                *size = sizeof(AudioObjectID);
                return noErr;
            }
            if (qsize != sizeof(CFStringRef) || !q)
                return kAudioHardwareBadPropertySizeError;
            CFStringRef uid = *static_cast<const CFStringRef *>(q);
            if (!uid || CFGetTypeID(uid) != CFStringGetTypeID())
                return kAudioHardwareIllegalOperationError;
            for (auto candidate : {mic, speaker, feed, monitor})
                if (CFEqual(uid, deviceUID(candidate)))
                    return scalar(candidate);
            return scalar(kAudioObjectUnknown);
        }
        case kAudioPlugInPropertyResourceBundle:
            return str(CFSTR(""));
        }
    if (device(id)) {
        if (global)
            switch (s) {
            case kAudioDevicePropertyDeviceUID:
                return str(deviceUID(id));
            case kAudioDevicePropertyModelUID:
                return str(CFSTR("dev.hari.labvoice.model.v1"));
            case kAudioDevicePropertyTransportType:
                return scalar(kAudioDeviceTransportTypeVirtual);
            case kAudioDevicePropertyDeviceIsAlive:
                return scalar(1);
            case kAudioDevicePropertyDeviceIsRunning:
                return scalar(state(id).running.load(std::memory_order_relaxed) > 0);
            case kAudioDevicePropertyDeviceIsRunningSomewhere:
                return scalar(state(id).running.load(std::memory_order_relaxed) > 0);
            case kAudioDevicePropertyIsHidden:
                return scalar(hidden(id));
            case kAudioDevicePropertyClockDomain:
                return scalar(0x4c564143);
            case kAudioDevicePropertyZeroTimeStampPeriod:
                return scalar(period);
            case kAudioDevicePropertyClockAlgorithm:
                return scalar(kAudioDeviceClockAlgorithmRaw);
            case kAudioDevicePropertyClockIsStable:
                return scalar(1);
            case kAudioDevicePropertyNominalSampleRate: {
                Float64 rate = 48000;
                return put(&rate, sizeof rate);
            }
            case kAudioDevicePropertyAvailableNominalSampleRates: {
                AudioValueRange range = {48000, 48000};
                return put(&range, sizeof range);
            }
            case kAudioDevicePropertyBufferFrameSize:
                return scalar(channels(id) == 1 ? 480 : 512);
            case kAudioDevicePropertyBufferFrameSizeRange: {
                AudioValueRange range = {15, channels(id) == 1 ? 480.0 : 960.0};
                return put(&range, sizeof range);
            }
            case kAudioObjectPropertyControlList:
                return put(nullptr, 0);
            }
        if (global || scope == kAudioObjectPropertyScopeInput ||
            scope == kAudioObjectPropertyScopeOutput)
            switch (s) {
            case kAudioDevicePropertyStreams: {
                AudioObjectID sid = streamID(id);
                return put(&sid, (global || direction) ? sizeof sid : 0);
            }
            case kAudioDevicePropertyStreamConfiguration: {
                AudioBufferList list{};
                list.mNumberBuffers = direction ? 1 : 0;
                list.mBuffers[0].mNumberChannels = channels(id);
                return put(&list, direction ? sizeof list : offsetof(AudioBufferList, mBuffers));
            }
            }
        if ((scope == kAudioObjectPropertyScopeInput ||
             scope == kAudioObjectPropertyScopeOutput) &&
            s == kAudioDevicePropertySafetyOffset)
            return scalar(UInt32{0});
        if (direction)
            switch (s) {
            case kAudioDevicePropertyLatency:
                return scalar(input(id) ? routeDelay : 0);
            case kAudioDevicePropertyDeviceCanBeDefaultDevice:
            case kAudioDevicePropertyDeviceCanBeDefaultSystemDevice:
                return scalar(!hidden(id));
            case kAudioDevicePropertyPreferredChannelsForStereo: {
                UInt32 cs[] = {1, input(id) ? 1u : 2u};
                return put(cs, sizeof cs);
            }
            }
    }
    if (stream(id) && global)
        switch (s) {
        case kAudioStreamPropertyIsActive:
            return scalar(1);
        case kAudioStreamPropertyDirection:
            return scalar(input(id) ? 1 : 0);
        case kAudioStreamPropertyTerminalType:
            return scalar(input(id) ? kAudioStreamTerminalTypeMicrophone
                                    : kAudioStreamTerminalTypeSpeaker);
        case kAudioStreamPropertyStartingChannel:
            return scalar(1);
        case kAudioStreamPropertyLatency:
            return scalar(0);
        case kAudioStreamPropertyVirtualFormat:
        case kAudioStreamPropertyPhysicalFormat: {
            auto f = format(id);
            return put(&f, sizeof f);
        }
        case kAudioStreamPropertyAvailableVirtualFormats:
        case kAudioStreamPropertyAvailablePhysicalFormats: {
            AudioStreamRangedDescription f = {format(id), {48000, 48000}};
            return put(&f, sizeof f);
        }
        }
    return kAudioHardwareUnknownPropertyError;
}
OSStatus property(AudioObjectID id, const AudioObjectPropertyAddress *address, UInt32 qualifierSize,
                  const void *qualifier, UInt32 capacity, UInt32 *size, void *data,
                  [[maybe_unused]] const char *operation) {
    const OSStatus status = propertyValue(id, address, qualifierSize, qualifier, capacity, size, data);
    LV_TRACE(operation, id, address, qualifierSize, qualifier, status,
             (status == noErr && size) ? *size : 0, data);
    return status;
}
ULONG addref(void *d) {
    return d == driver ? ++references : 0;
}
ULONG release(void *d) {
    if (d != driver)
        return 0;
    ULONG n = references.load();
    while (n > 1 && !references.compare_exchange_weak(n, n - 1)) {
    }
    return references.load();
}
HRESULT query(void *d, REFIID iid, LPVOID *out) {
    if (!out)
        return E_POINTER;
    *out = nullptr;
    if (d != driver)
        return E_NOINTERFACE;
    CFUUIDRef u = CFUUIDCreateFromUUIDBytes(nullptr, iid);
    bool ok = CFEqual(u, IUnknownUUID) || CFEqual(u, kAudioServerPlugInDriverInterfaceUUID);
    CFRelease(u);
    if (!ok)
        return E_NOINTERFACE;
    *out = driver;
    addref(d);
    LV_TRACE("query-success", 1, nullptr, 0, nullptr, noErr, 0, nullptr);
    return S_OK;
}
OSStatus initialize(AudioServerPlugInDriverRef d, AudioServerPlugInHostRef h) {
    LV_TRACE("initialize-enter", 1, nullptr, 0, nullptr, noErr, 0, nullptr);
    if (d != driver || !h)
        return kAudioHardwareIllegalOperationError;
    std::lock_guard<std::mutex> lock(lifecycle);
    if (anchor.load())
        return host == h ? OSStatus(noErr) : OSStatus(kAudioHardwareIllegalOperationError);
    host = h;
    mach_timebase_info_data_t tb;
    mach_timebase_info(&tb);
    nanosPerTick = static_cast<double>(tb.numer) / tb.denom;
    ticksPerFrame = 1e9 / nanosPerTick / 48000.0;
    if (!anchor.load())
        anchor.store(mach_absolute_time(), std::memory_order_release);
    LV_TRACE("initialize-success", 1, nullptr, 0, nullptr, noErr, 0, nullptr);
    return noErr;
}
OSStatus create(AudioServerPlugInDriverRef, CFDictionaryRef, const AudioServerPlugInClientInfo *,
                AudioObjectID *) {
    return kAudioHardwareUnsupportedOperationError;
}
OSStatus destroy(AudioServerPlugInDriverRef, AudioObjectID) {
    return kAudioHardwareUnsupportedOperationError;
}
OSStatus addclient(AudioServerPlugInDriverRef d, AudioObjectID id,
                   const AudioServerPlugInClientInfo *info) {
    if (valid(d, id) || !device(id) || !info)
        return kAudioHardwareBadObjectError;
    std::lock_guard<std::mutex> lock(lifecycle);
    for (auto &c : state(id).clients)
        if (c.used && c.id == info->mClientID)
            return noErr;
    for (auto &c : state(id).clients)
        if (!c.used) {
            c = {info->mClientID, true, false};
            return noErr;
        }
    return kAudioHardwareIllegalOperationError;
}
void notify(AudioObjectID id) {
    if (host && host->PropertiesChanged) {
        AudioObjectPropertyAddress a[] = {
            {kAudioDevicePropertyDeviceIsRunning, kAudioObjectPropertyScopeGlobal, 0},
            {kAudioDevicePropertyDeviceIsRunningSomewhere, kAudioObjectPropertyScopeGlobal, 0}};
        host->PropertiesChanged(host, id, 2, a);
    }
}
OSStatus removeclient(AudioServerPlugInDriverRef d, AudioObjectID id,
                      const AudioServerPlugInClientInfo *info) {
    if (valid(d, id) || !device(id) || !info)
        return kAudioHardwareBadObjectError;
    bool changed = false;
    {
        std::lock_guard<std::mutex> lock(lifecycle);
        for (auto &c : state(id).clients)
            if (c.used && c.id == info->mClientID) {
                if (c.running)
                    changed = state(id).running.fetch_sub(1) == 1;
                c = {};
                if (changed)
                    invalidateRoute(id);
                break;
            }
    }
    if (changed)
        notify(id);
    return noErr;
}
OSStatus config(AudioServerPlugInDriverRef d, AudioObjectID id, UInt64, void *) {
    return valid(d, id) || !device(id) ? kAudioHardwareBadObjectError
                                       : kAudioHardwareUnsupportedOperationError;
}
Boolean has(AudioServerPlugInDriverRef d, AudioObjectID id, pid_t,
            const AudioObjectPropertyAddress *a) {
    UInt32 n = 0;
    if (valid(d, id)) {
        LV_TRACE("has", id, a, 0, nullptr, kAudioHardwareBadObjectError, 0, nullptr);
        return false;
    }
    return property(id, a, 0, nullptr, 0, &n, nullptr, "has") == noErr;
}
OSStatus settable(AudioServerPlugInDriverRef d, AudioObjectID id, pid_t p,
                  const AudioObjectPropertyAddress *a, Boolean *out) {
    if (!out)
        return kAudioHardwareIllegalOperationError;
    if (!has(d, id, p, a))
        return kAudioHardwareUnknownPropertyError;
    *out = false;
    return noErr;
}
OSStatus size(AudioServerPlugInDriverRef d, AudioObjectID id, pid_t,
              const AudioObjectPropertyAddress *a, UInt32 qs, const void *q, UInt32 *out) {
    if (valid(d, id)) {
        LV_TRACE("size", id, a, qs, q, kAudioHardwareBadObjectError, 0, nullptr);
        return kAudioHardwareBadObjectError;
    }
    return property(id, a, qs, q, 0, out, nullptr, "size");
}
OSStatus get(AudioServerPlugInDriverRef d, AudioObjectID id, pid_t,
             const AudioObjectPropertyAddress *a, UInt32 qs, const void *q, UInt32 n, UInt32 *out,
             void *data) {
    if (valid(d, id)) {
        LV_TRACE("get", id, a, qs, q, kAudioHardwareBadObjectError, 0, nullptr);
        return kAudioHardwareBadObjectError;
    }
    if (!data) {
        LV_TRACE("get", id, a, qs, q, kAudioHardwareIllegalOperationError, 0, nullptr);
        return kAudioHardwareIllegalOperationError;
    }
    return property(id, a, qs, q, n, out, data, "get");
}
OSStatus set(AudioServerPlugInDriverRef d, AudioObjectID id, pid_t p,
             const AudioObjectPropertyAddress *a, UInt32, const void *, UInt32, const void *) {
    return has(d, id, p, a) ? kAudioHardwareUnsupportedOperationError
                            : kAudioHardwareUnknownPropertyError;
}
OSStatus running(AudioServerPlugInDriverRef d, AudioObjectID id, UInt32 client, bool start) {
    if (valid(d, id) || !device(id))
        return kAudioHardwareBadObjectError;
    bool changed = false, found = false;
    {
        std::lock_guard<std::mutex> lock(lifecycle);
        for (auto &c : state(id).clients)
            if (c.used && c.id == client) {
                found = true;
                if (c.running != start) {
                    c.running = start;
                    changed = start ? state(id).running.fetch_add(1) == 0
                                    : state(id).running.fetch_sub(1) == 1;
                }
                if (changed && !start)
                    invalidateRoute(id);
                break;
            }
    }
    if (changed)
        notify(id);
    return found ? OSStatus(noErr) : OSStatus(kAudioHardwareIllegalOperationError);
}
OSStatus start(AudioServerPlugInDriverRef d, AudioObjectID id, UInt32 c) {
    return running(d, id, c, true);
}
OSStatus stop(AudioServerPlugInDriverRef d, AudioObjectID id, UInt32 c) {
    return running(d, id, c, false);
}
OSStatus timestamp(AudioServerPlugInDriverRef d, AudioObjectID id, UInt32, Float64 *sample,
                   UInt64 *time, UInt64 *seed) {
    if (valid(d, id) || !device(id))
        return kAudioHardwareBadObjectError;
    if (!sample || !time || !seed)
        return kAudioHardwareIllegalOperationError;
    const UInt64 a = anchor.load(std::memory_order_acquire);
    if (!a)
        return kAudioHardwareNotRunningError;
    const UInt64 elapsed = mach_absolute_time() - a;
    const UInt64 n = static_cast<UInt64>(elapsed / (ticksPerFrame * period));
    *sample = n * period;
    *time = a + static_cast<UInt64>(n * period * ticksPerFrame);
    *seed = 1;
    return noErr;
}
bool operation(AudioObjectID id, UInt32 op) {
    return (input(id) && op == kAudioServerPlugInIOOperationReadInput) ||
           (!input(id) && op == kAudioServerPlugInIOOperationWriteMix);
}
OSStatus will(AudioServerPlugInDriverRef d, AudioObjectID id, UInt32, UInt32 op, Boolean *yes,
              Boolean *inplace) {
    if (valid(d, id) || !device(id))
        return kAudioHardwareBadObjectError;
    if (!yes || !inplace)
        return kAudioHardwareIllegalOperationError;
    *yes = operation(id, op);
    *inplace = true;
    return noErr;
}
OSStatus phase(AudioServerPlugInDriverRef d, AudioObjectID id, UInt32, UInt32 op, UInt32 frames,
               const AudioServerPlugInIOCycleInfo *cycle) {
    if (valid(d, id) || !device(id))
        return kAudioHardwareBadObjectError;
    if (!cycle || frames > maxFrames || !operation(id, op))
        return kAudioHardwareIllegalOperationError;
    return noErr;
}
// SDK mInputTime and mOutputTime describe the first frame of each buffer.
// mNominalIOBufferFrameSize is not a time offset or transport latency.
bool frameIndex(const AudioTimeStamp &stamp, UInt64 &frame) {
    const double sample = stamp.mSampleTime;
    if (!(stamp.mFlags & kAudioTimeStampSampleTimeValid) || !std::isfinite(sample) || sample < 0 ||
        sample >= static_cast<double>(UINT64_MAX / 2) || std::floor(sample) != sample)
        return false;
    frame = static_cast<UInt64>(sample);
    return true;
}
OSStatus io(AudioServerPlugInDriverRef d, AudioObjectID id, AudioObjectID sid, UInt32 client,
            UInt32 op, UInt32 frames, const AudioServerPlugInIOCycleInfo *cycle, void *main,
            void *) {
    auto status = phase(d, id, client, op, frames, cycle);
    if (status)
        return status;
    if (sid != streamID(id))
        return kAudioHardwareBadObjectError;
    if (frames && !main)
        return kAudioHardwareIllegalOperationError;
    auto &route = routeFor(id);
    const UInt64 generation = route.generation.load(std::memory_order_acquire);
    if (!state(id).running.load(std::memory_order_acquire) ||
        !anchor.load(std::memory_order_acquire))
        return kAudioHardwareNotRunningError;
    if (!frames)
        return noErr;
    UInt64 first = 0;
    if (!frameIndex(input(id) ? cycle->mInputTime : cycle->mOutputTime, first) ||
        first > UINT64_MAX / 2 - frames)
        return kAudioHardwareIllegalOperationError;
    auto *samples = static_cast<float *>(main);
    const UInt64 now = static_cast<UInt64>(mach_absolute_time() * nanosPerTick);
    if (!input(id)) {
        // Host WriteMix is the fully mixed device output. The try-once guard also
        // prevents concurrent producer entry without spinning or blocking.
        if (route.writer.test_and_set(std::memory_order_acquire))
            return kAudioHardwareIllegalOperationError;
        if (route.generation.load(std::memory_order_acquire) != generation) {
            route.writer.clear(std::memory_order_release);
            return kAudioHardwareNotRunningError;
        }
#ifdef LABVOICE_DRIVER_TEST_HOOKS
        if (writeHook)
            writeHook(writeHookContext);
#endif
        const bool accepted = route.transport.write(first, samples, frames, now);
        const bool current = route.generation.load(std::memory_order_acquire) == generation;
        if (accepted && current) {
            if (route.publishedGeneration.load(std::memory_order_acquire) != generation)
                route.readFloor.store(first, std::memory_order_release);
            route.publishedGeneration.store(generation, std::memory_order_release);
        }
        route.writer.clear(std::memory_order_release);
        if (!current)
            return kAudioHardwareNotRunningError;
        return accepted ? OSStatus(noErr) : OSStatus(kAudioHardwareIllegalOperationError);
    }
    std::memset(samples, 0, frames * channels(id) * sizeof(float));
    if (!state(producerFor(id)).running.load(std::memory_order_acquire) ||
        route.publishedGeneration.load(std::memory_order_acquire) != generation)
        return noErr;
    UInt32 prefix = first < routeDelay ? std::min<UInt64>(frames, routeDelay - first) : 0;
    if (prefix == frames)
        return noErr;
    UInt64 requested = first + prefix - routeDelay;
    const UInt64 floor = route.readFloor.load(std::memory_order_acquire);
    if (requested < floor) {
        const UInt32 skip = std::min<UInt64>(frames - prefix, floor - requested);
        prefix += skip;
        requested += skip;
    }
    if (prefix < frames)
        route.transport.read(requested, samples + prefix * channels(id), frames - prefix, now,
                             staleAfterNs);
    // A read that overlaps stop may have copied old samples. Discard them before
    // returning if the route's generation changed during that bounded copy.
    if (route.generation.load(std::memory_order_acquire) != generation ||
        route.publishedGeneration.load(std::memory_order_acquire) != generation)
        std::memset(samples, 0, frames * channels(id) * sizeof(float));
    return noErr;
}
AudioServerPlugInDriverInterface makeInterface() {
    return {nullptr,      query,  addref,    release, initialize, create, destroy, addclient,
            removeclient, config, config,    has,     settable,   size,   get,     set,
            start,        stop,   timestamp, will,    phase,      io,     phase};
}
struct InstallInterface {
    InstallInterface() {
        interface = makeInterface();
    }
} installed;
} // namespace
extern "C" __attribute__((visibility("default"))) void *LabVoiceFactory(CFAllocatorRef,
                                                                        CFUUIDRef type) {
    if (!type || !CFEqual(type, kAudioServerPlugInTypeUUID))
        return nullptr;
    LV_TRACE("factory-success", 1, nullptr, 0, nullptr, noErr, 0, nullptr);
    addref(driver);
    return driver;
}

#ifdef LABVOICE_DRIVER_TEST_HOOKS
extern "C"
    __attribute__((visibility("default"))) void LabVoiceTestSetWriteHook(void (*hook)(void *),
                                                                         void *context) {
    writeHook = hook;
    writeHookContext = context;
}
#endif
