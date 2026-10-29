#include "call_capture.hpp"
#include "microphone_test.hpp"
#include "microphone_inspection.hpp"
#include <Block.h>
#include <atomic>
#include <array>
#include <cstddef>
#include <cstring>
#include <stdexcept>

namespace labvoice {
bool silenceUnexpectedCallCaptureOutputs(AudioBufferList* output) noexcept {
    if(!output)return true;
    if(output->mNumberBuffers>16)return false;
    bool disabled=true;
    for(UInt32 i=0;i<output->mNumberBuffers;++i){
        const auto& buffer=output->mBuffers[i];
        if(buffer.mNumberChannels>64||buffer.mDataByteSize>4096*64*4)return false;
        if(buffer.mData){std::memset(buffer.mData,0,buffer.mDataByteSize);disabled=false;}
    }
    return disabled;
}
namespace {
AudioObjectPropertyAddress address(UInt32 selector,UInt32 scope=kAudioObjectPropertyScopeGlobal){return{selector,scope,kAudioObjectPropertyElementMain};}
bool status(OSStatus value,const char* operation,std::string&error){if(!value)return true;error=std::string(operation)+"_OSStatus_"+std::to_string(value);return false;}
class NativeMicrophone final:public CallCaptureMicrophone {
    std::string uid_;
    MicrophoneSpec inspected_;
    std::vector<AudioObjectID> outputs_;
    struct Listener{AudioObjectID id;AudioObjectPropertyAddress property;AudioObjectPropertyListenerBlock block;};
    std::vector<Listener> listeners_;
    AudioDeviceIOProcID io_=nullptr;
    CallCaptureDriver::Sink sink_=nullptr;void* context_=nullptr;
    std::shared_ptr<std::atomic<bool>> fault_=std::make_shared<std::atomic<bool>>(false);
    dispatch_queue_t queue_=dispatch_queue_create("openkrisp.call-microphone",DISPATCH_QUEUE_SERIAL);
    static OSStatus input(AudioObjectID,const AudioTimeStamp*,const AudioBufferList* data,const AudioTimeStamp* time,AudioBufferList* output,const AudioTimeStamp*,void* context)noexcept{
        auto& self=*static_cast<NativeMicrophone*>(context);
        // Output streams are disabled for this IOProc. Never write playback data.
        const bool unexpectedOutput=!silenceUnexpectedCallCaptureOutputs(output);
        self.sink_(self.context_,self.fault_->load(std::memory_order_acquire)||unexpectedOutput?nullptr:data,time);return noErr;
    }
public:
    explicit NativeMicrophone(std::string uid):uid_(std::move(uid)){}
    ~NativeMicrophone()override{if(queue_)dispatch_release(queue_);}
    bool prepare(CallCaptureMicrophoneSpec& result,std::string&error)override{
        try{
            if(uid_.empty()||uid_.size()>4096||uid_.find('\0')!=std::string::npos){error="invalid_call_microphone_uid";return false;}
            inspected_=inspectPhysicalMicrophone(uid_,outputs_);
            result.uid=uid_;result.objectID=inspected_.device;result.channels=inspected_.channels;result.streams=inspected_.streams;
            result.format={};result.format.mSampleRate=48000;result.format.mFormatID=kAudioFormatLinearPCM;
            result.format.mFormatFlags=kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked;result.format.mBytesPerPacket=result.format.mBytesPerFrame=4;
            result.format.mFramesPerPacket=1;result.format.mChannelsPerFrame=1;result.format.mBitsPerChannel=32;return true;
        }catch(const std::exception&e){error=e.what();return false;}
    }
    bool registerIO(CallCaptureDriver::Sink sink,void* context,std::string&error)override{
        sink_=sink;context_=context;
        std::vector<std::pair<AudioObjectID,AudioObjectPropertyAddress>> properties;
        for(UInt32 selector:std::array<UInt32,5>{kAudioDevicePropertyDeviceIsAlive,kAudioDevicePropertyNominalSampleRate,kAudioDevicePropertyBufferFrameSize,kAudioDevicePropertyDeviceUID,kAudioDevicePropertyTransportType})properties.push_back({inspected_.device,address(selector)});
        properties.push_back({inspected_.device,address(kAudioDevicePropertyStreams,kAudioObjectPropertyScopeInput)});
        properties.push_back({inspected_.device,address(kAudioDevicePropertyStreams,kAudioObjectPropertyScopeOutput)});
        for(auto stream:inspected_.streams)properties.push_back({stream,address(kAudioStreamPropertyVirtualFormat)});
        listeners_.reserve(properties.size()); // Allocate before the first HAL ownership acquisition.
        for(const auto& listener:properties){
            auto owner=fault_;
            AudioObjectPropertyListenerBlock block=Block_copy(^(UInt32,const AudioObjectPropertyAddress*){owner->store(true,std::memory_order_release);});
            if(!block){error="allocate_call_microphone_listener_failed";return false;}
            if(!status(AudioObjectAddPropertyListenerBlock(listener.first,&listener.second,queue_,block),"watch_call_microphone",error)){Block_release(block);return false;}
            listeners_.push_back({listener.first,listener.second,block});
        }
        if(!status(AudioDeviceCreateIOProcID(inspected_.device,input,this,&io_),"register_call_microphone_io",error))return false;
        if(!outputs_.empty()){
            std::vector<unsigned char> data(offsetof(AudioHardwareIOProcStreamUsage,mStreamIsOn)+outputs_.size()*sizeof(UInt32));
            auto* usage=reinterpret_cast<AudioHardwareIOProcStreamUsage*>(data.data());usage->mIOProc=reinterpret_cast<void*>(io_);usage->mNumberStreams=UInt32(outputs_.size());
            const auto property=address(kAudioDevicePropertyIOProcStreamUsage,kAudioObjectPropertyScopeOutput);
            if(!status(AudioObjectSetPropertyData(inspected_.device,&property,0,nullptr,UInt32(data.size()),usage),"disable_call_microphone_duplex_outputs",error))return false;
        }
        return true;
    }
    bool start(std::string&error)override{return status(AudioDeviceStart(inspected_.device,io_),"start_call_microphone",error);}
    bool validate(const CallCaptureMicrophoneSpec& expected,std::string&error)override{
        try{
            std::vector<AudioObjectID> outputs;const auto current=inspectPhysicalMicrophone(uid_,outputs);
            if(fault_->load(std::memory_order_acquire)||expected.uid!=uid_||expected.objectID!=inspected_.device||current!=inspected_||outputs!=outputs_){error="call_microphone_identity_layout_or_format_changed";return false;}
            return true;
        }catch(const std::exception&e){error=e.what();return false;}
    }
    bool stop(std::string&error)override{return !io_||status(AudioDeviceStop(inspected_.device,io_),"stop_call_microphone",error);}
    bool unregisterIO(std::string&error)override{
        if(io_){if(!status(AudioDeviceDestroyIOProcID(inspected_.device,io_),"unregister_call_microphone_io",error))return false;io_=nullptr;}
        while(!listeners_.empty()){
            const auto& listener=listeners_.back();
            if(!status(AudioObjectRemovePropertyListenerBlock(listener.id,&listener.property,queue_,listener.block),"unwatch_call_microphone",error))return false;
            Block_release(listener.block);listeners_.pop_back();
        }
        dispatch_sync(queue_, ^{}); // Drain notifications queued before verified removals.
        return true;
    }
};
}
std::unique_ptr<CallCaptureMicrophone> makeNativeCallCaptureMicrophone(const std::string&uid){return std::make_unique<NativeMicrophone>(uid);}
}
