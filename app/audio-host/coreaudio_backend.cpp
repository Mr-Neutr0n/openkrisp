#include "routing.hpp"
#include <Block.h>
#include <CoreFoundation/CoreFoundation.h>
#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstring>
#include <map>
#include <stdexcept>

namespace labvoice {
namespace {
constexpr const char *feed = "dev.hari.labvoice.feed";
constexpr const char *monitor = "dev.hari.labvoice.monitor";
AudioObjectPropertyAddress property(UInt32 selector,
                                    UInt32 scope = kAudioObjectPropertyScopeGlobal) {
    return {selector, scope, kAudioObjectPropertyElementMain};
}
void require(OSStatus status, const char *operation) {
    if (status)
        throw std::runtime_error(std::string(operation) + " OSStatus=" + std::to_string(status));
}
std::string hex(UInt32 value) {
    constexpr char digits[] = "0123456789abcdef";
    std::string result(8, '0');
    for (unsigned i = 0; i < 8; ++i)
        result[7 - i] = digits[(value >> (i * 4)) & 15];
    return "0x" + result;
}
void requireProperty(OSStatus status, const char *operation, AudioObjectID id,
                     const AudioObjectPropertyAddress &address) {
    if (status)
        throw std::runtime_error(std::string(operation) + " object=" + std::to_string(id) +
                                 " selector=" + hex(address.mSelector) + " scope=" +
                                 hex(address.mScope) + " element=" +
                                 std::to_string(address.mElement) + " OSStatus=" +
                                 std::to_string(status));
}
template <class T>
T scalar(AudioObjectID id, UInt32 selector, UInt32 scope = kAudioObjectPropertyScopeGlobal) {
    const auto a = property(selector, scope);
    T result{};
    UInt32 size = sizeof result;
    requireProperty(AudioObjectGetPropertyData(id, &a, 0, nullptr, &size, &result),
                    "HAL property read", id, a);
    if (size != sizeof result)
        throw std::runtime_error("HAL scalar property size mismatch");
    return result;
}
std::vector<unsigned char> bytes(AudioObjectID id, UInt32 selector, UInt32 scope,
                                  UInt32 qualifierSize = 0, const void *qualifier = nullptr) {
    const auto a = property(selector, scope);
    UInt32 size = 0;
    requireProperty(AudioObjectGetPropertyDataSize(id, &a, qualifierSize, qualifier, &size),
                    "HAL property size", id, a);
    if (size > 1048576)
        throw std::runtime_error("HAL property read bound exceeded");
    std::vector<unsigned char> result(size);
    if (size)
        requireProperty(AudioObjectGetPropertyData(id, &a, qualifierSize, qualifier, &size, result.data()),
                        "HAL array read", id, a);
    if (size > result.size())
        throw std::runtime_error("HAL property grew");
    result.resize(size);
    return result;
}
template <class T>
std::vector<T> array(AudioObjectID id, UInt32 selector,
                     UInt32 scope = kAudioObjectPropertyScopeGlobal,
                     UInt32 qualifierSize = 0, const void *qualifier = nullptr) {
    const auto data = bytes(id, selector, scope, qualifierSize, qualifier);
    if (data.size() % sizeof(T))
        throw std::runtime_error("HAL array property size mismatch");
    std::vector<T> result(data.size() / sizeof(T));
    if (!data.empty())
        std::memcpy(result.data(), data.data(), data.size());
    return result;
}
struct CF {
    CFTypeRef value = nullptr;
    explicit CF(CFTypeRef v) : value(v) {
        if (!value)
            throw std::runtime_error("CoreFoundation allocation failed");
    }
    ~CF() {
        CFRelease(value);
    }
    CF(const CF &) = delete;
};
std::string text(CFStringRef value) {
    if (!value || CFGetTypeID(value) != CFStringGetTypeID())
        throw std::runtime_error("HAL string type mismatch");
    const auto length =
        CFStringGetMaximumSizeForEncoding(CFStringGetLength(value), kCFStringEncodingUTF8) + 1;
    if (length <= 0 || length > 1048576)
        throw std::runtime_error("HAL string bound exceeded");
    std::vector<char> buffer(static_cast<size_t>(length));
    if (!CFStringGetCString(value, buffer.data(), length, kCFStringEncodingUTF8))
        throw std::runtime_error("HAL UTF-8 conversion failed");
    return buffer.data();
}
std::string string(AudioObjectID id, UInt32 selector) {
    CF value(scalar<CFStringRef>(id, selector));
    return text(static_cast<CFStringRef>(value.value));
}
AudioObjectID lookup(const std::string &uid) {
    CF value(CFStringCreateWithCString(nullptr, uid.c_str(), kCFStringEncodingUTF8));
    auto qualifier = static_cast<CFStringRef>(value.value);
    auto a = property(kAudioHardwarePropertyTranslateUIDToDevice);
    AudioObjectID id = kAudioObjectUnknown;
    UInt32 size = sizeof id;
    require(AudioObjectGetPropertyData(kAudioObjectSystemObject, &a, sizeof qualifier, &qualifier,
                                       &size, &id),
            "UID lookup");
    if (!id || size != sizeof id)
        throw std::runtime_error("Required audio device missing: " + uid);
    return id;
}
std::vector<std::string> members(const Selection &s) {
    if (s.inputUID == feed || s.inputUID == monitor || s.outputUID == feed ||
        s.outputUID == monitor)
        throw std::runtime_error("Physical selections cannot be companion endpoints");
    std::vector<std::string> result{feed, monitor};
    for (const auto &uid : {s.inputUID, s.outputUID})
        if (std::find(result.begin(), result.end(), uid) == result.end())
            result.push_back(uid);
    return result;
}
std::vector<UInt32> buffers(AudioObjectID id, UInt32 scope) {
    const auto data = bytes(id, kAudioDevicePropertyStreamConfiguration, scope);
    if (data.size() < offsetof(AudioBufferList, mBuffers))
        throw std::runtime_error("Truncated HAL buffer list");
    UInt32 count = 0;
    std::memcpy(&count, data.data(), sizeof count);
    if (count > bufferLimit ||
        count > (data.size() - offsetof(AudioBufferList, mBuffers)) / sizeof(AudioBuffer))
        throw std::runtime_error("HAL buffer count unsupported");
    std::vector<UInt32> result;
    for (UInt32 i = 0; i < count; ++i) {
        AudioBuffer b{};
        std::memcpy(&b, data.data() + offsetof(AudioBufferList, mBuffers) + i * sizeof b, sizeof b);
        if (!b.mNumberChannels || b.mNumberChannels > 64)
            throw std::runtime_error("HAL buffer channels unsupported");
        result.push_back(b.mNumberChannels);
    }
    return result;
}
UInt32 channels(const std::vector<UInt32> &buffers) {
    UInt32 total = 0;
    for (auto c : buffers) {
        if (total > 64 - c)
            throw std::runtime_error("HAL total channels unsupported");
        total += c;
    }
    return total;
}
void formats(AudioObjectID id, UInt32 scope) {
    UInt32 next = 1;
    for (auto stream : array<AudioObjectID>(id, kAudioDevicePropertyStreams, scope)) {
        const auto f =
            scalar<AudioStreamBasicDescription>(stream, kAudioStreamPropertyVirtualFormat);
        const UInt32 allowed =
            kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
        const UInt32 stride =
            (f.mFormatFlags & kAudioFormatFlagIsNonInterleaved) ? 4 : f.mChannelsPerFrame * 4;
        if (f.mSampleRate != 48000 || f.mFormatID != kAudioFormatLinearPCM ||
            (f.mFormatFlags & ~allowed) || !(f.mFormatFlags & kAudioFormatFlagIsFloat) ||
            !(f.mFormatFlags & kAudioFormatFlagIsPacked) || f.mBitsPerChannel != 32 ||
            f.mBytesPerFrame != stride || f.mFramesPerPacket != 1 || f.mBytesPerPacket != stride ||
            !f.mChannelsPerFrame || f.mChannelsPerFrame > 64 ||
            scalar<UInt32>(stream, kAudioStreamPropertyStartingChannel) != next)
            throw std::runtime_error(
                "Only contiguous 48 kHz packed native Float32 streams are supported");
        next += f.mChannelsPerFrame;
    }
    if (next - 1 != channels(buffers(id, scope)))
        throw std::runtime_error("HAL stream and callback channels differ");
}
void preflight(const Selection &s) {
    const auto list = members(s);
    for (const auto &uid : list) {
        const auto id = lookup(uid);
        if (!scalar<UInt32>(id, kAudioDevicePropertyDeviceIsAlive) ||
            scalar<Float64>(id, kAudioDevicePropertyNominalSampleRate) != 48000)
            throw std::runtime_error("Required member is not alive at 48 kHz: " + uid);
        formats(id, kAudioObjectPropertyScopeInput);
        formats(id, kAudioObjectPropertyScopeOutput);
        if (uid != feed && uid != monitor) {
            auto transport = scalar<UInt32>(id, kAudioDevicePropertyTransportType);
            if (transport == kAudioDeviceTransportTypeVirtual ||
                transport == kAudioDeviceTransportTypeAggregate ||
                transport == kAudioDeviceTransportTypeUnknown)
                throw std::runtime_error("Hardware selections need physical transports");
        }
    }
    const auto feedID = lookup(feed), monitorID = lookup(monitor);
    const auto clock = scalar<UInt32>(feedID, kAudioDevicePropertyClockDomain);
    if (!clock || clock != scalar<UInt32>(monitorID, kAudioDevicePropertyClockDomain))
        throw std::runtime_error("Companion shared clock domain is unconfirmed");
    if (channels(buffers(feedID, kAudioObjectPropertyScopeOutput)) != 1 ||
        channels(buffers(monitorID, kAudioObjectPropertyScopeInput)) != 2)
        throw std::runtime_error("Companion channel contract mismatch");
    const auto captures = channels(buffers(lookup(s.inputUID), kAudioObjectPropertyScopeInput));
    const auto plays = channels(buffers(lookup(s.outputUID), kAudioObjectPropertyScopeOutput));
    if ((captures != 1 && captures != 2) || plays != 2)
        throw std::runtime_error(
            "Select a mono/stereo physical microphone and stereo physical output");
}
void setString(CFMutableDictionaryRef dictionary, CFStringRef key, const std::string &value) {
    CF string(CFStringCreateWithCString(nullptr, value.c_str(), kCFStringEncodingUTF8));
    CFDictionarySetValue(dictionary, key, string.value);
}
void setNumber(CFMutableDictionaryRef dictionary, CFStringRef key, int value) {
    CF number(CFNumberCreate(nullptr, kCFNumberIntType, &value));
    CFDictionarySetValue(dictionary, key, number.value);
}
std::vector<std::string> fullMembers(AudioObjectID aggregate) {
    CF value(scalar<CFArrayRef>(aggregate, kAudioAggregateDevicePropertyFullSubDeviceList));
    if (CFGetTypeID(value.value) != CFArrayGetTypeID())
        throw std::runtime_error("Aggregate list type mismatch");
    auto list = static_cast<CFArrayRef>(value.value);
    std::vector<std::string> result;
    for (CFIndex i = 0; i < CFArrayGetCount(list); ++i)
        result.push_back(text(static_cast<CFStringRef>(CFArrayGetValueAtIndex(list, i))));
    return result;
}
} // namespace
OSStatus CoreAudioBackend::create(const Selection &selection, AudioObjectID *result) {
    if (!result)
        return kAudioHardwareIllegalOperationError;
    *result = kAudioObjectUnknown;
    preflight(selection);
    CF dictionary(CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks,
                                            &kCFTypeDictionaryValueCallBacks));
    auto description = static_cast<CFMutableDictionaryRef>(const_cast<void *>(dictionary.value));
    CF uuid(CFUUIDCreate(nullptr));
    CF uuidString(CFUUIDCreateString(nullptr, static_cast<CFUUIDRef>(uuid.value)));
    setString(description, CFSTR(kAudioAggregateDeviceUIDKey),
              "dev.hari.labvoice.aggregate." + text(static_cast<CFStringRef>(uuidString.value)));
    setString(description, CFSTR(kAudioAggregateDeviceNameKey), "Lab Voice Private Route");
    setString(description, CFSTR(kAudioAggregateDeviceMainSubDeviceKey), feed);
    setNumber(description, CFSTR(kAudioAggregateDeviceIsPrivateKey), 1);
    CF array(CFArrayCreateMutable(nullptr, 0, &kCFTypeArrayCallBacks));
    auto subdevices = static_cast<CFMutableArrayRef>(const_cast<void *>(array.value));
    for (const auto &uid : members(selection)) {
        CF sub(CFDictionaryCreateMutable(nullptr, 0, &kCFTypeDictionaryKeyCallBacks,
                                         &kCFTypeDictionaryValueCallBacks));
        auto item = static_cast<CFMutableDictionaryRef>(const_cast<void *>(sub.value));
        setString(item, CFSTR(kAudioSubDeviceUIDKey), uid);
        setNumber(item, CFSTR(kAudioSubDeviceDriftCompensationKey),
                  uid == feed || uid == monitor ? 0 : 1);
        setNumber(item, CFSTR(kAudioSubDeviceDriftCompensationQualityKey),
                  kAudioAggregateDriftCompensationHighQuality);
        CFArrayAppendValue(subdevices, item);
    }
    CFDictionarySetValue(description, CFSTR(kAudioAggregateDeviceSubDeviceListKey), subdevices);
    return AudioHardwareCreateAggregateDevice(description, result);
}
Layout CoreAudioBackend::inspect(AudioObjectID aggregate, const Selection &selection) {
    preflight(selection);
    const auto expected = members(selection);
    if (fullMembers(aggregate) != expected ||
        string(aggregate, kAudioAggregateDevicePropertyMainSubDevice) != feed ||
        scalar<Float64>(aggregate, kAudioDevicePropertyNominalSampleRate) != 48000 ||
        !scalar<UInt32>(aggregate, kAudioDevicePropertyDeviceIsAlive))
        throw std::runtime_error("Aggregate composition/main/rate/alive readback mismatch");
    CF composition(scalar<CFDictionaryRef>(aggregate, kAudioAggregateDevicePropertyComposition));
    if (CFGetTypeID(composition.value) != CFDictionaryGetTypeID())
        throw std::runtime_error("Aggregate composition type mismatch");
    auto privateValue = CFDictionaryGetValue(static_cast<CFDictionaryRef>(composition.value),
                                             CFSTR(kAudioAggregateDeviceIsPrivateKey));
    int privateFlag = 0;
    if (!privateValue || CFGetTypeID(privateValue) != CFNumberGetTypeID() ||
        !CFNumberGetValue(static_cast<CFNumberRef>(privateValue), kCFNumberIntType, &privateFlag) ||
        privateFlag != 1)
        throw std::runtime_error("Aggregate is not confirmed process-private");
    const auto active =
        array<AudioObjectID>(aggregate, kAudioAggregateDevicePropertyActiveSubDeviceList);
    if (active.size() != expected.size())
        throw std::runtime_error("Aggregate member inactive");
    std::vector<std::string> activeUIDs;
    for (auto id : active)
        activeUIDs.push_back(string(id, kAudioDevicePropertyDeviceUID));
    auto expectedUIDs = expected;
    std::sort(activeUIDs.begin(), activeUIDs.end());
    std::sort(expectedUIDs.begin(), expectedUIDs.end());
    if (activeUIDs != expectedUIDs)
        throw std::runtime_error("Aggregate active member identity mismatch");
    // ActiveSubDeviceList contains the underlying AudioDevice IDs. Drift is an
    // AudioSubDevice property on the aggregate's owned member objects instead.
    const AudioClassID subdeviceClass = kAudioSubDeviceClassID;
    const auto subdevices = array<AudioObjectID>(aggregate, kAudioObjectPropertyOwnedObjects,
                                                 kAudioObjectPropertyScopeGlobal,
                                                 sizeof subdeviceClass, &subdeviceClass);
    if (subdevices.size() != expected.size())
        throw std::runtime_error("Aggregate subdevice object count mismatch");
    std::map<std::string, UInt32> drift;
    for (auto id : subdevices) {
        if (scalar<UInt32>(id, kAudioObjectPropertyClass) != kAudioSubDeviceClassID ||
            scalar<AudioObjectID>(id, kAudioObjectPropertyOwner) != aggregate)
            throw std::runtime_error("Aggregate subdevice object ownership mismatch");
        if (!drift.emplace(string(id, kAudioDevicePropertyDeviceUID),
                           scalar<UInt32>(id, kAudioSubDevicePropertyDriftCompensation)).second)
            throw std::runtime_error("Aggregate subdevice UID duplicated");
    }
    for (const auto &uid : expected)
        if (!drift.count(uid) || bool(drift[uid]) != (uid != feed && uid != monitor))
            throw std::runtime_error("Aggregate drift setting readback mismatch");
    const auto range = scalar<AudioValueRange>(aggregate, kAudioDevicePropertyBufferFrameSizeRange);
    const auto current = scalar<UInt32>(aggregate, kAudioDevicePropertyBufferFrameSize);
    if (!std::isfinite(range.mMinimum) || !std::isfinite(range.mMaximum) ||
        range.mMinimum < 1 || range.mMinimum > range.mMaximum || range.mMaximum > callbackLimit ||
        std::floor(range.mMinimum) != range.mMinimum || std::floor(range.mMaximum) != range.mMaximum ||
        !current || current < range.mMinimum || current > range.mMaximum)
        throw std::runtime_error("Aggregate callback bounds are invalid or exceed preallocation");
    formats(aggregate, kAudioObjectPropertyScopeInput);
    formats(aggregate, kAudioObjectPropertyScopeOutput);
    Layout layout;
    layout.currentCallbackFrames = current;
    layout.maximumCallbackFrames = static_cast<UInt32>(range.mMaximum);
    layout.inputBuffers = buffers(aggregate, kAudioObjectPropertyScopeInput);
    layout.outputBuffers = buffers(aggregate, kAudioObjectPropertyScopeOutput);
    UInt32 in = 0, out = 0;
    for (const auto &uid : expected) {
        const auto id = lookup(uid);
        if (uid == selection.inputUID)
            layout.microphoneChannel = in;
        if (uid == monitor) {
            layout.monitorLeft = in;
            layout.monitorRight = in + 1;
        }
        if (uid == feed)
            layout.feedChannel = out;
        if (uid == selection.outputUID) {
            layout.hardwareLeft = out;
            layout.hardwareRight = out + 1;
        }
        in += channels(buffers(id, kAudioObjectPropertyScopeInput));
        out += channels(buffers(id, kAudioObjectPropertyScopeOutput));
    }
    if (in != channels(layout.inputBuffers) || out != channels(layout.outputBuffers))
        throw std::runtime_error("Aggregate flattened channel map mismatch");
    return layout;
}
struct CoreAudioBackend::Impl {
    struct Listener {
        Watch watch;
        AudioObjectPropertyListenerBlock block;
    };
    std::vector<Listener> listeners;
    ~Impl() {
        for (auto &listener : listeners)
            Block_release(listener.block);
    }
};
std::vector<Watch> CoreAudioBackend::watches(AudioObjectID aggregate, const Selection &selection) {
    std::vector<AudioObjectID> ids{aggregate};
    for (const auto &uid : members(selection))
        ids.push_back(lookup(uid));
    std::vector<Watch> result;
    for (auto id : ids) {
        for (UInt32 selector : std::array<UInt32, 4>{kAudioDevicePropertyDeviceIsAlive,
                                                     kAudioDevicePropertyNominalSampleRate,
                                                     kAudioDevicePropertyBufferFrameSize,
                                                     kAudioDevicePropertyBufferFrameSizeRange})
            result.push_back({id, property(selector)});
        for (auto scope : {kAudioObjectPropertyScopeInput, kAudioObjectPropertyScopeOutput}) {
            result.push_back({id, property(kAudioDevicePropertyStreams, scope)});
            for (auto stream : array<AudioObjectID>(id, kAudioDevicePropertyStreams, scope))
                result.push_back({stream, property(kAudioStreamPropertyVirtualFormat)});
        }
    }
    impl_->listeners.reserve(impl_->listeners.size() + result.size());
    return result;
}
CoreAudioBackend::CoreAudioBackend() : impl_(std::make_unique<Impl>()) {
}
CoreAudioBackend::~CoreAudioBackend() = default;
OSStatus CoreAudioBackend::addWatch(const Watch &w, const std::shared_ptr<Context> &context) {
    // HAL copies this block. Its shared ownership also covers queued callbacks.
    auto owned = context;
    const AudioObjectID watchedID = w.device;
    AudioObjectPropertyListenerBlock block =
        Block_copy(^(UInt32 count, const AudioObjectPropertyAddress *addresses) {
          Context::change(watchedID, count, addresses, owned.get());
        });
    if (!block)
        throw std::runtime_error("Listener block allocation failed");
    const auto result = AudioObjectAddPropertyListenerBlock(w.device, &w.address, nullptr, block);
    if (result) {
        Block_release(block);
        return result;
    }
    try {
        impl_->listeners.push_back({w, block});
    } catch (...) {
        AudioObjectRemovePropertyListenerBlock(w.device, &w.address, nullptr, block);
        Block_release(block);
        throw;
    }
    return noErr;
}
OSStatus CoreAudioBackend::removeWatch(const Watch &w, Context *) {
    auto found =
        std::find_if(impl_->listeners.begin(), impl_->listeners.end(), [&](const auto &listener) {
            return listener.watch.device == w.device &&
                   listener.watch.address.mSelector == w.address.mSelector &&
                   listener.watch.address.mScope == w.address.mScope &&
                   listener.watch.address.mElement == w.address.mElement;
        });
    if (found == impl_->listeners.end())
        return kAudioHardwareIllegalOperationError;
    const auto result =
        AudioObjectRemovePropertyListenerBlock(w.device, &w.address, nullptr, found->block);
    if (!result) {
        Block_release(found->block);
        impl_->listeners.erase(found);
    }
    return result;
}
OSStatus CoreAudioBackend::registerIO(AudioObjectID id, const std::shared_ptr<Context> &context,
                                      AudioDeviceIOProcID *proc) {
    auto owned = context;
    // The API Block_copy's the callback. The context remains alive for any
    // callback already dispatched when stop or unregistration completes.
    return AudioDeviceCreateIOProcIDWithBlock(
        proc, id, nullptr,
        ^(const AudioTimeStamp *now, const AudioBufferList *input, const AudioTimeStamp *inputTime,
          AudioBufferList *output, const AudioTimeStamp *outputTime) {
          const auto status =
              Context::io(id, now, input, inputTime, output, outputTime, owned.get());
          // IOProc return values are ignored by HAL. Faults disable this route via
          // the control-thread service rather than relying on an OSStatus return.
          if (status)
              owned->changed.store(true, std::memory_order_release);
        });
}
OSStatus CoreAudioBackend::start(AudioObjectID id, AudioDeviceIOProcID proc) {
    return AudioDeviceStart(id, proc);
}
OSStatus CoreAudioBackend::stop(AudioObjectID id, AudioDeviceIOProcID proc) {
    return AudioDeviceStop(id, proc);
}
OSStatus CoreAudioBackend::unregisterIO(AudioObjectID id, AudioDeviceIOProcID proc) {
    return AudioDeviceDestroyIOProcID(id, proc);
}
OSStatus CoreAudioBackend::destroy(AudioObjectID id) {
    return AudioHardwareDestroyAggregateDevice(id);
}
} // namespace labvoice
