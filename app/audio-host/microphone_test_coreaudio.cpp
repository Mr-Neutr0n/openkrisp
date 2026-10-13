#include "microphone_test.hpp"
#include <Block.h>
#include <algorithm>
#include <array>
#include <cstddef>
#include <cstring>
#include <stdexcept>

namespace labvoice {
namespace {
AudioObjectPropertyAddress property(UInt32 selector, UInt32 scope = kAudioObjectPropertyScopeGlobal) { return {selector,scope,0}; }
void require(OSStatus status) { if (status) throw std::runtime_error("microphone_HAL_property_status="+std::to_string(status)); }
template<class T> T scalar(AudioObjectID device, UInt32 selector, UInt32 scope = kAudioObjectPropertyScopeGlobal) {
    T value{}; UInt32 bytes=sizeof value; auto a=property(selector,scope);
    require(AudioObjectGetPropertyData(device,&a,0,nullptr,&bytes,&value));
    if(bytes!=sizeof value) throw std::runtime_error("microphone_property_size_mismatch");
    return value;
}
std::vector<unsigned char> bytes(AudioObjectID device, UInt32 selector, UInt32 scope) {
    auto a=property(selector,scope); UInt32 count=0;
    require(AudioObjectGetPropertyDataSize(device,&a,0,nullptr,&count));
    if(count>65536) throw std::runtime_error("microphone_property_bound");
    std::vector<unsigned char> data(count);
    if(count) require(AudioObjectGetPropertyData(device,&a,0,nullptr,&count,data.data()));
    if(count>data.size()) throw std::runtime_error("microphone_property_grew");
    data.resize(count); return data;
}
std::vector<AudioObjectID> streams(AudioObjectID device, UInt32 scope) {
    auto data=bytes(device,kAudioDevicePropertyStreams,scope);
    if(data.size()%4 || data.size()/4>16) throw std::runtime_error("microphone_stream_bound");
    std::vector<AudioObjectID> values(data.size()/4);
    if(!data.empty()) std::memcpy(values.data(),data.data(),data.size());
    return values;
}
}
struct CoreAudioMicrophoneBackend::Impl {
    AudioObjectID device=0;
    std::vector<AudioObjectID> outputStreams;
    struct Listener { AudioObjectID id; AudioObjectPropertyAddress address; AudioObjectPropertyListenerBlock block; };
    std::vector<Listener> listeners;
    ~Impl() { for(auto &listener:listeners) Block_release(listener.block); }
};
CoreAudioMicrophoneBackend::CoreAudioMicrophoneBackend():impl_(std::make_unique<Impl>()) {}
CoreAudioMicrophoneBackend::~CoreAudioMicrophoneBackend()=default;
MicrophoneSpec CoreAudioMicrophoneBackend::inspect(const std::string &uid) {
    if(uid.empty() || uid.find('\0')!=std::string::npos) throw std::runtime_error("invalid_microphone_uid");
    CFStringRef string=CFStringCreateWithCString(nullptr,uid.c_str(),kCFStringEncodingUTF8);
    if(!string) throw std::runtime_error("invalid_microphone_uid");
    AudioObjectID device=0; UInt32 count=sizeof device; auto a=property(kAudioHardwarePropertyTranslateUIDToDevice);
    const OSStatus status=AudioObjectGetPropertyData(kAudioObjectSystemObject,&a,sizeof string,&string,&count,&device);
    CFRelease(string); require(status);
    if(!device || count!=sizeof device) throw std::runtime_error("selected_microphone_missing");
    CFStringRef actual=scalar<CFStringRef>(device,kAudioDevicePropertyDeviceUID);
    string=CFStringCreateWithCString(nullptr,uid.c_str(),kCFStringEncodingUTF8);
    const bool equal=actual && string && CFEqual(actual,string);
    if(actual) CFRelease(actual); if(string) CFRelease(string);
    if(!equal) throw std::runtime_error("microphone_uid_translation_mismatch");
    const UInt32 transport=scalar<UInt32>(device,kAudioDevicePropertyTransportType);
    if(transport==kAudioDeviceTransportTypeVirtual || transport==kAudioDeviceTransportTypeAggregate ||
       uid.starts_with("dev.hari.labvoice.")) throw std::runtime_error("physical_microphone_required");
    if(!scalar<UInt32>(device,kAudioDevicePropertyDeviceIsAlive) || scalar<Float64>(device,kAudioDevicePropertyNominalSampleRate)!=48000)
        throw std::runtime_error("microphone_requires_alive_48k_device");
    const UInt32 size=scalar<UInt32>(device,kAudioDevicePropertyBufferFrameSize);
    if(!size || size>microphoneTestCallbackLimit) throw std::runtime_error("microphone_buffer_size_unsupported");
    MicrophoneSpec spec; spec.device=device; spec.streams=streams(device,kAudioObjectPropertyScopeInput);
    if(spec.streams.empty()) throw std::runtime_error("microphone_has_no_input_stream");
    for(auto stream:spec.streams) {
        const auto f=scalar<AudioStreamBasicDescription>(stream,kAudioStreamPropertyVirtualFormat);
        if(!microphoneTestFormatSupported(f))
            throw std::runtime_error("microphone_requires_native_float32_48k");
    }
    const auto configuration=bytes(device,kAudioDevicePropertyStreamConfiguration,kAudioObjectPropertyScopeInput);
    UInt32 buffers=0;
    if(configuration.size()<offsetof(AudioBufferList,mBuffers)) throw std::runtime_error("microphone_truncated_layout");
    std::memcpy(&buffers,configuration.data(),4);
    if(!buffers || buffers>16 || configuration.size()<offsetof(AudioBufferList,mBuffers)+buffers*sizeof(AudioBuffer))
        throw std::runtime_error("microphone_layout_bound");
    for(UInt32 i=0;i<buffers;++i) {
        AudioBuffer b{}; std::memcpy(&b,configuration.data()+offsetof(AudioBufferList,mBuffers)+i*sizeof b,sizeof b);
        if(!b.mNumberChannels || b.mNumberChannels>64) throw std::runtime_error("microphone_channel_bound");
        spec.channels.push_back(b.mNumberChannels);
    }
    impl_->device=device; impl_->outputStreams=streams(device,kAudioObjectPropertyScopeOutput);
    return spec;
}
OSStatus CoreAudioMicrophoneBackend::watch(const std::shared_ptr<MicrophoneCapture> &capture) {
    std::vector<std::pair<AudioObjectID,AudioObjectPropertyAddress>> properties;
    for(UInt32 selector:std::array<UInt32,3>{kAudioDevicePropertyDeviceIsAlive,kAudioDevicePropertyNominalSampleRate,kAudioDevicePropertyBufferFrameSize})
        properties.push_back({impl_->device,property(selector)});
    properties.push_back({impl_->device,property(kAudioDevicePropertyStreams,kAudioObjectPropertyScopeInput)});
    properties.push_back({impl_->device,property(kAudioDevicePropertyStreams,kAudioObjectPropertyScopeOutput)});
    for(auto stream:capture->spec.streams) properties.push_back({stream,property(kAudioStreamPropertyVirtualFormat)});
    impl_->listeners.reserve(properties.size());
    for(const auto &[id,a]:properties) {
        auto owner=capture;
        AudioObjectPropertyListenerBlock block=Block_copy(^(UInt32,const AudioObjectPropertyAddress *) {
            owner->fault.store(true); owner->enabled.store(false);
        });
        if(!block) return kAudioHardwareUnspecifiedError;
        const auto status=AudioObjectAddPropertyListenerBlock(id,&a,nullptr,block);
        if(status) { Block_release(block); return status; }
        impl_->listeners.push_back({id,a,block});
    }
    return noErr;
}
OSStatus CoreAudioMicrophoneBackend::unwatch() {
    while(!impl_->listeners.empty()) {
        const auto &listener=impl_->listeners.back();
        const auto status=AudioObjectRemovePropertyListenerBlock(listener.id,&listener.address,nullptr,listener.block);
        if(status) return status;
        Block_release(listener.block); impl_->listeners.pop_back();
    }
    return noErr;
}
OSStatus CoreAudioMicrophoneBackend::registerIO(const std::shared_ptr<MicrophoneCapture> &capture, AudioDeviceIOProcID *io) {
    auto owner=capture;
    const auto status=AudioDeviceCreateIOProcIDWithBlock(io,impl_->device,nullptr,
        ^(const AudioTimeStamp *,const AudioBufferList *input,const AudioTimeStamp *time,
          AudioBufferList *output,const AudioTimeStamp *) { owner->consume(input,time,output); });
    if(status) return status;
    // Per-IOProc configuration only. Disabled duplex outputs arrive with NULL pointers.
    if(!impl_->outputStreams.empty()) {
        std::vector<unsigned char> storage(offsetof(AudioHardwareIOProcStreamUsage,mStreamIsOn)+impl_->outputStreams.size()*4);
        auto *usage=reinterpret_cast<AudioHardwareIOProcStreamUsage *>(storage.data());
        usage->mIOProc=reinterpret_cast<void *>(*io); usage->mNumberStreams=impl_->outputStreams.size();
        auto a=property(kAudioDevicePropertyIOProcStreamUsage,kAudioObjectPropertyScopeOutput);
        return AudioObjectSetPropertyData(impl_->device,&a,0,nullptr,storage.size(),usage);
    }
    return noErr;
}
OSStatus CoreAudioMicrophoneBackend::unregisterIO(AudioDeviceIOProcID io) { return AudioDeviceDestroyIOProcID(impl_->device,io); }
OSStatus CoreAudioMicrophoneBackend::start(AudioDeviceIOProcID io) { return AudioDeviceStart(impl_->device,io); }
OSStatus CoreAudioMicrophoneBackend::stop(AudioDeviceIOProcID io) { return AudioDeviceStop(impl_->device,io); }
} // namespace labvoice
