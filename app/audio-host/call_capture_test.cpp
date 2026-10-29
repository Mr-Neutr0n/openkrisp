#include "call_capture.hpp"
#include <cassert>
#include <atomic>
#include <chrono>
#include <thread>
#include <iostream>
#include <stdexcept>
using namespace labvoice;
namespace {
AudioStreamBasicDescription format(bool planar = false) {
    AudioStreamBasicDescription f{};
    f.mSampleRate=44100; f.mFormatID=kAudioFormatLinearPCM; f.mFormatFlags=kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked|(planar?kAudioFormatFlagIsNonInterleaved:0);
    f.mChannelsPerFrame=2; f.mBitsPerChannel=32; f.mFramesPerPacket=1; f.mBytesPerFrame=f.mBytesPerPacket=planar?4:8; return f;
}
AudioProcessSnapshot snapshot() {
    AudioProcessSnapshot s{"available", {}, {}}; AudioProcessUsage p{};
    p.objectID=42; p.actualPID=101; p.responsiblePID=100; p.appID="example.call";
    p.output.running=true; p.output.devices=std::vector<AudioUsedDevice>{{44,"speaker"}};
    s.processes.push_back(p); return s;
}
CallCaptureTarget target() { return {100,"example.call",{{42,101}}}; }
struct Shared {
    std::vector<std::string> events; CallCaptureDriver::Sink sink=nullptr; void* context=nullptr;
    std::function<void(const char*)> hook;
    std::string fail; bool planar=false; std::atomic<uint64_t> written{0}; std::vector<float> samples; bool driverDestroyed=false;
};
struct Driver : CallCaptureDriver {
    std::shared_ptr<Shared> s;
    explicit Driver(std::shared_ptr<Shared> shared):s(shared){}
    ~Driver() override { s->driverDestroyed=true; }
    bool op(const char* name,std::string& e) {s->events.push_back(name); if(s->hook)s->hook(name); if(s->fail==name){e=name;return false;}return true;}
    bool createTap(const CallCaptureTarget& t,AudioStreamBasicDescription& f,std::string& e) override {assert(t.processes.size()==1&&t.processes[0].objectID==42);f=format(s->planar);return op("tap",e);}
    bool createAggregate(std::string& e)override{return op("aggregate",e);}
    bool registerIO(Sink sink,void* c,std::string& e)override{s->sink=sink;s->context=c;return op("register",e);}
    bool start(std::string& e)override{return op("start",e);}
    bool validateFormat(const AudioStreamBasicDescription&,std::string& e)override{return op("format",e);}
    bool stop(std::string& e)override{return op("stop",e);}
    bool unregisterIO(std::string& e)override{return op("unregister",e);}
    bool destroyAggregate(std::string& e)override{return op("destroy_aggregate",e);}
    bool destroyTap(std::string& e)override{return op("destroy_tap",e);}
};
struct Writer:CallCaptureWriter {
    std::shared_ptr<Shared>s;explicit Writer(std::shared_ptr<Shared>v):s(v){}
    bool open(const std::string&,const AudioStreamBasicDescription&,std::string&e)override{s->events.push_back("open");if(s->fail=="open"){e="open";return false;}return true;}
    bool write(const float*p,uint32_t n,std::string& error)override{if(s->fail=="write"){error="injected_writer_failure";return false;}s->written+=n;s->samples.insert(s->samples.end(),p,p+n*2);return true;}
    bool close(uint64_t&n,std::string&)override{s->events.push_back("close");n=s->written.load();return true;}
};
struct MicShared {CallCaptureDriver::Sink sink=nullptr;void* context=nullptr;std::string fail;std::vector<std::string> events;std::function<void(const char*)> hook;bool destroyed=false;};
struct Mic:CallCaptureMicrophone {
 std::shared_ptr<MicShared>s;explicit Mic(std::shared_ptr<MicShared>v):s(v){}~Mic()override{s->destroyed=true;}
 bool op(const char*name,std::string&error){s->events.push_back(name);if(s->hook)s->hook(name);if(s->fail==name){error=name;return false;}return true;}
 bool prepare(CallCaptureMicrophoneSpec&spec,std::string&error)override{spec.uid="physical.mic";spec.objectID=77;spec.channels={2};spec.streams={78};spec.format=format();spec.format.mSampleRate=48000;spec.format.mChannelsPerFrame=1;spec.format.mBytesPerFrame=spec.format.mBytesPerPacket=4;return op("micprepare",error);}
 bool registerIO(CallCaptureDriver::Sink sink,void*c,std::string&error)override{s->sink=sink;s->context=c;return op("micregister",error);}
 bool start(std::string&error)override{return op("micstart",error);}
 bool validate(const CallCaptureMicrophoneSpec&,std::string&error)override{return op("micvalidate",error);}
 bool stop(std::string&error)override{return op("micstop",error);}
 bool unregisterIO(std::string&error)override{return op("micunregister",error);}
};
void feedLane(CallCaptureDriver::Sink sink,void* context,bool mic,unsigned block){
 float values[512];for(unsigned i=0;i<256;++i){values[2*i]=mic?.4f:.2f;values[2*i+1]=mic?1000.f:-.2f;}
 AudioBufferList buffers{1,{{2,sizeof values,values}}};AudioTimeStamp time{};time.mSampleTime=block*256;time.mHostTime=1000000000000ULL+uint64_t(std::llround(block*256*1e9/(mic?48000:44100)));time.mFlags=kAudioTimeStampSampleTimeValid|kAudioTimeStampHostTimeValid;sink(context,&buffers,&time);
}
void feed(const std::shared_ptr<Shared>&s,double sample=0,uint64_t host=100) {
    float left[]={.1f,.2f,.3f,.4f};float right[]={-.1f,-.2f,-.3f,-.4f};float stereo[]={.1f,-.1f,.2f,-.2f,.3f,-.3f,.4f,-.4f};
    struct Buffers {UInt32 count;AudioBuffer buffers[2];} buffers{};
    buffers.count=s->planar?2:1;
    buffers.buffers[0]={s->planar?1U:2U,s->planar?16U:32U,s->planar?left:stereo};
    buffers.buffers[1]={1,16,right};AudioTimeStamp time{};time.mSampleTime=sample;time.mHostTime=host;time.mFlags=kAudioTimeStampSampleTimeValid|kAudioTimeStampHostTimeValid;
    s->sink(s->context,reinterpret_cast<AudioBufferList*>(&buffers),&time);
}
}
int main() {
    std::string error;auto good=snapshot();assert(validateCallCaptureTarget(target(),good,error));
    for(int i=0;i<8;++i){auto bad=good;switch(i){case 0:bad.status="failed";break;case 1:bad.processes[0].actualPID=102;break;case 2:bad.processes[0].responsiblePID=102;break;case 3:bad.processes[0].responsibleFallback=true;break;case 4:bad.processes[0].appID="other";break;case 5:bad.processes[0].output.running=false;break;case 6:bad.processes.clear();break;case 7:bad.processes[0].usageStale=true;break;}assert(!validateCallCaptureTarget(target(),bad,error));}
    auto duplicate=target();duplicate.processes.push_back(duplicate.processes[0]);assert(!validateCallCaptureTarget(duplicate,good,error));
    assert(callCaptureSourceFramesFitWav(callCaptureWavMaximumFrames,48000));
    assert(!callCaptureSourceFramesFitWav(callCaptureWavMaximumFrames+1,48000));
    assert(callCaptureSourceFramesFitWav(48000ULL*60*60*5,48000)); // No former four-hour quota.
    assert(!callCaptureSourceFramesFitWav(UINT64_MAX,8000));
    assert(supportedCallCaptureFormat(format()));assert(supportedCallCaptureFormat(format(true)));auto unsupported=format();unsupported.mFormatFlags|=kAudioFormatFlagIsBigEndian;assert(!supportedCallCaptureFormat(unsupported));
    for(bool planar:{false,true}){
        auto shared=std::make_shared<Shared>();shared->planar=planar;int observations=0;
        CallCaptureSession session([&]{++observations;return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));
        assert(session.start(target(),"/fixture.wav",error));assert(observations==3);feed(shared);feed(shared,4,200);
        auto result=session.stop();assert(result.completed&&result.cleanupVerified&&result.frames==8&&result.sourceFrames==8&&result.firstHostTime==100&&result.lastHostTime==200);
        assert(shared->samples.size()==16&&shared->samples[0]==.1f&&shared->samples[1]==-.1f);
        assert((shared->events==std::vector<std::string>{"tap","open","aggregate","register","format","start","format","stop","unregister","destroy_aggregate","destroy_tap","close"}));
        assert(session.stop().completed);assert(!session.start(target(),"/again.wav",error));
    }
    for(const char* mutation:{"identity", "format"}) {
        auto shared=std::make_shared<Shared>();bool changed=false;
        shared->hook=[&](const char* stage){if(std::string(stage)=="start"){feed(shared);changed=true;if(std::string(mutation)=="format")shared->fail="format";}};
        CallCaptureSession session([&]{auto current=good;if(changed&&std::string(mutation)=="identity")current.processes[0].actualPID=999;return current;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));
        assert(!session.start(target(),"/fixture.wav",error));assert(!session.healthy());
        auto result=session.stop();assert(!result.completed&&result.cleanupVerified&&result.sourceFrames==0&&result.frames==0);
        assert(std::find(shared->events.begin(),shared->events.end(),"stop")!=shared->events.end());
    }
    for(const char* cancelAt:{"before", "tap", "start"}) {
        auto shared=std::make_shared<Shared>();bool cancelled=std::string(cancelAt)=="before";
        shared->hook=[&](const char* stage){if(std::string(stage)==cancelAt){if(std::string(stage)=="start")feed(shared);cancelled=true;}};
        CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));
        assert(!session.start(target(),"/fixture.wav",error,[&]{return cancelled;}));assert(error=="selected_capture_cancelled");
        auto result=session.stop();assert(!result.completed&&result.sourceFrames==0&&result.frames==0&&result.cleanupVerified);
        if(std::string(cancelAt)=="before")assert(shared->events.empty());
        if(std::string(cancelAt)=="start")assert(std::find(shared->events.begin(),shared->events.end(),"stop")!=shared->events.end());
    }
    {auto shared=std::make_shared<Shared>();shared->hook=[&](const char* stage){if(std::string(stage)=="start")feed(shared);};
      CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));assert(session.start(target(),"/fixture.wav",error));
      feed(shared,4,200);auto result=session.stop();assert(result.completed&&result.sourceFrames==4&&result.firstSampleTime==4);}
    {auto shared=std::make_shared<Shared>();auto cancel=std::make_shared<std::atomic<bool>>(false);
      CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));assert(session.start(target(),"/fixture.wav",error,[cancel]{return cancel->load();}));feed(shared);
      for(unsigned i=0;i<1000&&shared->written.load()==0;++i)std::this_thread::sleep_for(std::chrono::milliseconds(1));
      assert(shared->written.load()==4);cancel->store(true);assert(!session.validateCurrentTarget(error));feed(shared,4,200);auto result=session.stop();assert(result.completed&&result.frames==4&&result.sourceFrames==4);}
    {auto shared=std::make_shared<Shared>();shared->fail="write";
      CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));assert(session.start(target(),"/fixture.wav",error));feed(shared);
      auto result=session.stop();assert(!result.completed&&result.error=="injected_writer_failure"&&result.frames==0);}
    for(const char* failure:{"tap","open","aggregate","register","start"}){
        auto shared=std::make_shared<Shared>();shared->fail=failure;
        CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));
        assert(!session.start(target(),"/fixture.wav",error));auto result=session.stop();assert(!result.completed&&result.cleanupVerified&&!result.error.empty());
        assert(std::find(shared->events.begin(),shared->events.end(),"destroy_tap")!=shared->events.end());
        if(shared->fail=="start")assert(std::find(shared->events.begin(),shared->events.end(),"stop")!=shared->events.end());
        if(shared->fail=="open")assert(shared->events.back()=="close");
    }
    {auto shared=std::make_shared<Shared>();int reads=0;
      CallCaptureSession session([&]{auto current=good;if(++reads==2)current.processes.clear();return current;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));
      assert(!session.start(target(),"/fixture.wav",error));assert(!session.stop().completed);assert(std::find(shared->events.begin(),shared->events.end(),"start")==shared->events.end());}
    {auto shared=std::make_shared<Shared>();bool gone=false;
      CallCaptureSession session([&]{auto current=good;if(gone)current.processes.clear();return current;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));
      assert(session.start(target(),"/fixture.wav",error));gone=true;assert(!session.validateCurrentTarget(error));feed(shared);auto result=session.stop();assert(!result.completed&&result.sourceFrames==0&&result.error=="selected_capture_identity_invalidated");}
    {auto shared=std::make_shared<Shared>();
      CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));assert(session.start(target(),"/fixture.wav",error));
      shared->fail="format";assert(!session.validateCurrentTarget(error));assert(!session.stop().completed);}
    {auto shared=std::make_shared<Shared>();
      CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));assert(session.start(target(),"/fixture.wav",error));feed(shared);feed(shared,99,200);auto result=session.stop();assert(!result.completed&&result.error=="source_clock_discontinuity");}
    for(const char* failure:{"stop","unregister","destroy_aggregate","destroy_tap"}){
        auto shared=std::make_shared<Shared>();shared->fail=failure;
        {CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared));assert(session.start(target(),"/fixture.wav",error));feed(shared);auto result=session.stop();assert(!result.completed&&!result.cleanupVerified);}
        assert(!shared->driverDestroyed);feed(shared,8,300); // Retained callback context remains safe and rejects intake.
    }
    {auto shared=std::make_shared<Shared>();auto microphone=std::make_shared<MicShared>();
      CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared),std::make_unique<Mic>(microphone),1e9);
      assert(session.start(target(),"/dual.wav",error));assert(session.microphoneSpec().objectID==77);
      for(unsigned i=0;i<10;++i){feedLane(shared->sink,shared->context,false,i);feedLane(microphone->sink,microphone->context,true,i);}
      auto result=session.stop();assert(result.completed&&result.timeline.outputFrames==result.frames&&result.timeline.microphoneSourceFrames==2560&&result.timeline.appSourceFrames==2560);
      for(size_t i=0;i<shared->samples.size()/2;++i){assert(std::abs(shared->samples[2*i]-.3f)<1e-5);assert(std::abs(shared->samples[2*i+1]-.1f)<1e-5);}}
    for(const char* failure:{"micregister","micstart","micvalidate"}){
      auto shared=std::make_shared<Shared>();auto microphone=std::make_shared<MicShared>();microphone->fail=failure;
      CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared),std::make_unique<Mic>(microphone),1e9);
      assert(!session.start(target(),"/dual.wav",error));auto result=session.stop();assert(!result.completed&&result.cleanupVerified&&result.frames==0);
      assert(std::find(microphone->events.begin(),microphone->events.end(),"micunregister")!=microphone->events.end());}
    {auto shared=std::make_shared<Shared>();auto microphone=std::make_shared<MicShared>();
      microphone->hook=[&](const char*stage){if(std::string(stage)=="micstart"){feedLane(shared->sink,shared->context,false,0);feedLane(microphone->sink,microphone->context,true,0);microphone->fail="micvalidate";}};
      CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared),std::make_unique<Mic>(microphone),1e9);
      assert(!session.start(target(),"/dual.wav",error));auto result=session.stop();assert(!result.completed&&result.cleanupVerified&&result.frames==0&&result.sourceFrames==0);}
    for(bool failApp:{false,true}){
      auto shared=std::make_shared<Shared>();auto microphone=std::make_shared<MicShared>();
      if(failApp)shared->fail="stop";else microphone->fail="micstop";
      {CallCaptureSession session([&]{return good;},std::make_unique<Driver>(shared),std::make_unique<Writer>(shared),std::make_unique<Mic>(microphone),1e9);
       assert(session.start(target(),"/dual.wav",error));auto result=session.stop();assert(!result.cleanupVerified&&!result.completed);
       assert(std::find(shared->events.begin(),shared->events.end(),"stop")!=shared->events.end());assert(std::find(microphone->events.begin(),microphone->events.end(),"micstop")!=microphone->events.end());}
      assert(!shared->driverDestroyed&&!microphone->destroyed);}
    std::cout<<"Selected-app capture injected lifecycle tests passed.\n";
}
