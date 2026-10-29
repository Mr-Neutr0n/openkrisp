#include "microphone_test.hpp"
#include "microphone_inspection.hpp"
#include <Block.h>
#include <algorithm>
#include <array>
#include <cstddef>
#include <cstring>
#include <stdexcept>

namespace labvoice {
namespace {
AudioObjectPropertyAddress property(UInt32 selector, UInt32 scope = kAudioObjectPropertyScopeGlobal) { return {selector,scope,0}; }

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
MicrophoneSpec CoreAudioMicrophoneBackend::inspect(const std::string& uid) {
    auto spec=inspectPhysicalMicrophone(uid,impl_->outputStreams);impl_->device=spec.device;return spec;
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
