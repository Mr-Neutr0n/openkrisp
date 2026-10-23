#include "installed_aec_adapter.hpp"
#include <cassert>
#include <chrono>
#include <cstring>
#include <iostream>
#include <new>
#include <cstdlib>
#include <thread>
thread_local bool callbackGuard=false;
void* operator new(std::size_t size){assert(!callbackGuard);if(auto* p=std::malloc(size?size:1))return p;throw std::bad_alloc();}
void* operator new[](std::size_t size){return ::operator new(size);}
void operator delete(void* p)noexcept{std::free(p);}
void operator delete[](void* p)noexcept{std::free(p);}
void* operator new(std::size_t size,std::align_val_t alignment){assert(!callbackGuard);void* p=nullptr;if(posix_memalign(&p,static_cast<std::size_t>(alignment),size?size:1))throw std::bad_alloc();return p;}
void* operator new[](std::size_t size,std::align_val_t alignment){return ::operator new(size,alignment);}
void operator delete(void* p,std::align_val_t)noexcept{std::free(p);}
void operator delete[](void* p,std::align_val_t)noexcept{std::free(p);}
using namespace labvoice;
using namespace std::chrono_literals;
namespace {
Layout layout(UInt32 maximum=4096){return {{3},{3},0,1,2,0,1,2,480,maximum};}
struct Cycle {
    std::array<float,callbackLimit*3> in{},out{};
    AudioBufferList input{},output{};
    AudioTimeStamp inputTime{},outputTime{};
    UInt32 count;
    Cycle(UInt32 frames,std::uint64_t position):count(frames) {
        input.mNumberBuffers=output.mNumberBuffers=1;
        input.mBuffers[0]={3,frames*3*4,in.data()};output.mBuffers[0]={3,frames*3*4,out.data()};
        inputTime.mSampleTime=position+.25;outputTime.mSampleTime=position+700.75;
        inputTime.mHostTime=position+1000;outputTime.mHostTime=position+9000;
        inputTime.mFlags=outputTime.mFlags=kAudioTimeStampSampleTimeValid|kAudioTimeStampHostTimeValid;
        for(UInt32 i=0;i<frames;++i){in[3*i]=float((position+i)%997)/32;in[3*i+1]=float((position+i)%251)/64;in[3*i+2]=-float((position+i)%127)/128;out[3*i]=out[3*i+1]=out[3*i+2]=9;}
    }
    void run(Context& context){callbackGuard=true;const auto result=Context::io(1,nullptr,&input,&inputTime,&output,&outputTime,&context);callbackGuard=false;assert(result==noErr);}
    bool zero()const{for(UInt32 i=0;i<count*3;++i)if(out[i]!=0)return false;return true;}
};
struct Speaker {
    float left=0,right=0;
    unsigned calls=0;
    static bool process(void* data,const float* mic,const float* monitor,float* micOut,float* playback,UInt32 count)noexcept {
        auto& self=*static_cast<Speaker*>(data);++self.calls;
        for(UInt32 i=0;i<count;++i){micOut[i]=mic[i]+999;playback[2*i]=self.left;playback[2*i+1]=self.right;self.left=monitor[2*i]*2;self.right=monitor[2*i+1]*2;}return true;
    }
};
void wait(const std::shared_ptr<InstalledAECAdapter>& owner,std::uint64_t frames) {
    const auto deadline=std::chrono::steady_clock::now()+2s;
    while(owner->processedFrames()<frames && owner->healthy() && std::chrono::steady_clock::now()<deadline)std::this_thread::yield();
    assert(owner->healthy() && owner->processedFrames()==frames);
}
struct OwnFactory {
    std::string library,digest,mode;
    bool* invoked=nullptr;
    std::shared_ptr<krisp_probe::AECDuplexWorker> operator()(krisp_probe::AECWorkerLaunchConfig config,std::string& error,krisp_probe::AECDuplexBufferingConfig buffering)const {
        if(invoked)*invoked=true;
        assert(config.executable=="/usr/bin/sandbox-exec" && config.arguments.size()==7);
        assert(config.arguments[0]=="-p" && config.arguments[1]=="(version 1) (allow default) (deny network*)");
        assert(config.arguments[4]==krisp_probe::installedAECLibrarySHA256);
        assert(config.arguments[6]==std::to_string(getpid()));
        assert(config.expectedReadyLine==std::string("OKAEC1 ")+krisp_probe::installedAECLibrarySHA256+" 48000 1 48000 2\n");
        assert(config.environment==std::vector<std::string>{"PATH=/usr/bin:/bin"});
        assert(config.startupTimeout==30s && config.frameTimeout==500ms && config.shutdownTimeout==1s);
        config.arguments[3]=library;config.arguments[4]=digest;
        config.expectedReadyLine="OKAEC1 "+digest+" 48000 1 48000 2\n";
        if(mode=="wrong-ready")config.expectedReadyLine="wrong\n";
        if(mode=="forward")config.environment.push_back("OPENKRISP_AEC_FIXTURE_FAILURE=forward");
        if(mode=="mismatch")++buffering.schedulingBudgetFrames;
        return krisp_probe::AECDuplexWorker::create(std::move(config),error,buffering);
    }
};
struct Fake final:Backend {
    std::shared_ptr<Context> context;
    bool failUnregister=false;
    OSStatus create(const Selection&,AudioObjectID* id)override{*id=1;return noErr;}
    Layout inspect(AudioObjectID,const Selection&)override{return layout();}
    std::vector<Watch> watches(AudioObjectID,const Selection&)override{return {};}
    OSStatus addWatch(const Watch&,const std::shared_ptr<Context>&)override{return noErr;}
    OSStatus removeWatch(const Watch&,Context*)override{return noErr;}
    OSStatus registerIO(AudioObjectID,const std::shared_ptr<Context>& value,AudioDeviceIOProcID* id)override{context=value;*id=reinterpret_cast<AudioDeviceIOProcID>(uintptr_t(1));return noErr;}
    OSStatus start(AudioObjectID,AudioDeviceIOProcID)override{return noErr;}
    OSStatus stop(AudioObjectID,AudioDeviceIOProcID)override{return noErr;}
    OSStatus unregisterIO(AudioObjectID,AudioDeviceIOProcID)override{return failUnregister?-1:noErr;}
    OSStatus destroy(AudioObjectID)override{context.reset();return noErr;}
};
}
int main(int argc,char** argv) {
    assert(argc==4); // Own worker, own synthetic library, own synthetic SHA256.
    InstalledAECOptions options;
    options.settings={argv[1],krisp_probe::installed_aec_worker_detail::hashWorker(argv[1]),"/unread-vendor/library.dylib"};
    OwnFactory factory{argv[2],argv[3],""};std::string error;
    for(auto maximum:{480u,512u,4096u})for(auto budget:{2ul,4ul}) {
        options.schedulingBudgetFrames=budget;
        auto owner=InstalledAECAdapter::create(layout(maximum),options,true,error,factory);assert(owner && error.empty());
        assert(owner->healthy() && owner->maximumCallbackFrames()==maximum);
        assert(owner->actualDelaySamples()==((maximum+958)/480+budget)*480);
        assert(owner->settings().workerSha256==options.settings.workerSha256);
        assert(std::string(owner->librarySha256())==krisp_probe::installedAECLibrarySHA256);
        const auto saved=owner->settings().libraryPath;options.settings.libraryPath="/another-unread/library";assert(owner->settings().libraryPath==saved);
        Speaker speaker;Context context(layout(maximum),Speaker::process,&speaker,{},owner->binding(),true);context.enabled=true;
        std::array<float,512> referenceMeans{};std::size_t position=0;
        for(unsigned turn=0;turn<40;++turn) {
            const auto count=std::min(maximum,turn%4==0?1u:turn%4==1?479u:turn%4==2?maximum:481u);
            Cycle cycle(count,position);
            const bool muted=turn%5==3;const ControlSnapshot controls{{.5f,false},{.25f,muted}};assert(context.controls.publish(controls));
            const auto previousLeft=speaker.left,previousRight=speaker.right;
            // Calculate the final stereo reference independently of the adapter.
            for(UInt32 i=0;i<count;++i) {
                const float l=muted?0:(i?cycle.in[3*(i-1)+1]*2:previousLeft)*.25f;
                const float r=muted?0:(i?cycle.in[3*(i-1)+2]*2:previousRight)*.25f;
                const auto at=position+i;
                if(at%480==0)referenceMeans[at/480]=(l+r)/2;
            }
            cycle.run(context);
            assert(speaker.calls==turn+1);
            for(UInt32 i=0;i<count;++i) {
                const float l=muted?0:(i?cycle.in[3*(i-1)+1]*2:previousLeft)*.25f;
                const float r=muted?0:(i?cycle.in[3*(i-1)+2]*2:previousRight)*.25f;
                assert(cycle.out[3*i+1]==l && cycle.out[3*i+2]==r);
                const auto at=position+i;
                const auto delay=owner->actualDelaySamples();
                const auto source=at>=delay?at-delay:0;
                const float expected=at<delay?0:(float(source%997)/32-referenceMeans[source/480])*.5f;
                assert(cycle.out[3*i]==expected);
            }
            position+=count;wait(owner,position/480);
        }
        assert(owner->stop());assert(owner->stop());assert(!owner->healthy());
        DuplexBlock b;std::array<float,1> mic{1},output{9};std::array<float,2> ref{.5f,.5f};b.rawMicrophone=mic.data();b.finalPlayback=ref.data();b.count=1;b.epoch=owner->epoch();assert(!InstalledAECAdapter::process(owner.get(),b,output.data()) && output[0]==0);assert(owner->error().empty());
    }
    // Exact per-lane origins/host validity survive mapping and output delay.
    {options.schedulingBudgetFrames=2;auto owner=InstalledAECAdapter::create(layout(480),options,true,error,factory);assert(owner);std::array<float,480> mic{},out{};std::array<float,960> ref{};
     for(unsigned turn=0;turn<12;++turn){DuplexBlock b{mic.data(),ref.data(),480,owner->epoch(),{10.25+turn*480,100.75+turn*480,1234+turn,true,true},{-300.5+turn*480,900.25+turn*480,5678+turn,true,false}};krisp_probe::AECDuplexTransport::OutputMetadata metadata;assert(owner->exchange(b,out.data(),&metadata));if(turn>=4){assert(metadata.count==1);const auto& span=metadata.spans[0];const auto seq=turn-4;assert(span.microphoneTiming.inputSampleOrigin==10.25+seq*480 && span.microphoneTiming.outputSampleOrigin==100.75+seq*480);assert(span.referenceTiming.inputSampleOrigin==-300.5+seq*480 && span.referenceTiming.outputSampleOrigin==900.25+seq*480);assert(span.microphoneTiming.flags==1 && span.referenceTiming.flags==1 && span.microphoneTiming.hostTime==0 && span.referenceTiming.hostTime==0);assert(span.microphoneProvenance.callbackHostTime==1234+seq && span.microphoneProvenance.callbackHostTimeValid);assert(span.referenceProvenance.callbackHostTime==5678+seq && !span.referenceProvenance.callbackHostTimeValid);}wait(owner,turn+1);}assert(owner->stop());}
    bool called=false;auto check=factory;check.invoked=&called;
    assert(!InstalledAECAdapter::create(layout(),options,false,error,check) && !called);
    auto invalid=layout();invalid.currentCallbackFrames=0;assert(!InstalledAECAdapter::create(invalid,options,true,error,check) && !called);
    auto overflow=options;overflow.schedulingBudgetFrames=SIZE_MAX;assert(!InstalledAECAdapter::create(layout(),overflow,true,error,check) && !called);
    auto bad=options;bad.settings.workerSha256[0]=bad.settings.workerSha256[0]=='0'?'1':'0';assert(!InstalledAECAdapter::create(layout(),bad,true,error,check) && !called);
    for(unsigned mutation=0;mutation<2;++mutation){auto owner=InstalledAECAdapter::create(layout(480),options,true,error,factory);assert(owner);std::array<float,480> mic{},out{};std::array<float,960> ref{};out.fill(9);DuplexBlock b{mic.data(),ref.data(),480,owner->epoch(),{0,0,0,true,false},{0,0,0,true,false}};if(mutation==0)b.epoch^=1;else b.referenceTiming.sampleOriginsValid=false;assert(!owner->exchange(b,out.data()) && !owner->healthy());for(auto value:out)assert(value==0);(void)owner->stop();}
    for(const auto mode:{"wrong-ready","mismatch"}){auto f=factory;f.mode=mode;assert(!InstalledAECAdapter::create(layout(),options,true,error,f) && !error.empty());}
    {auto f=factory;f.mode="forward";auto owner=InstalledAECAdapter::create(layout(480),options,true,error,f);assert(owner);std::array<float,480> mic{},out{};std::array<float,960> ref{};DuplexBlock b{mic.data(),ref.data(),480,owner->epoch(),{0,0,0,true,false},{0,0,0,true,false}};assert(owner->exchange(b,out.data()));const auto deadline=std::chrono::steady_clock::now()+2s;while(owner->healthy() && std::chrono::steady_clock::now()<deadline)std::this_thread::yield();assert(!owner->healthy());b.microphoneTiming.inputSampleOrigin=b.microphoneTiming.outputSampleOrigin=b.referenceTiming.inputSampleOrigin=b.referenceTiming.outputSampleOrigin=480;out.fill(9);assert(!owner->exchange(b,out.data()));for(auto value:out)assert(value==0);assert(!owner->stop() && !owner->error().empty());}
    // A strong control owner stops the worker even when HAL teardown fails.
    // The stopped adapter's arrays survive the queued Context until late release.
    {Fake backend;Session session(backend);std::shared_ptr<InstalledAECAdapter> controlOwner;std::weak_ptr<InstalledAECAdapter> weak;
     assert(session.start({"input","output"},nullptr,nullptr,{}, {},[&](const Layout& l){controlOwner=InstalledAECAdapter::create(l,options,true,error,factory);assert(controlOwner);weak=controlOwner;ProcessorBinding binding;binding.microphoneStageDisabled=true;binding.duplex=controlOwner->binding();return binding;}));auto queued=backend.context;backend.failUnregister=true;assert(!session.stop());assert(controlOwner->stop());controlOwner.reset();assert(!weak.expired());Cycle late(480,0);late.run(*queued);assert(late.zero());backend.failUnregister=false;assert(session.stop() && !weak.expired());queued.reset();assert(weak.expired());}
    std::cout<<"Installed AEC adapter synthetic integration passed\n";
}
