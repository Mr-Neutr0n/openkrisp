#include "aec_microphone_chain.hpp"
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
static krisp_probe::InstalledWorkerSettings ncSettings() {
    krisp_probe::InstalledWorkerSettings s;
    s.nodePath="/fixture/node";s.workerPath="/fixture/worker";s.addonPath="/fixture/addon";
    s.modelPath="/fixture/model";s.adapterPath="/fixture/adapter";s.libraryPath="/fixture/library";
    s.nodeSha256=std::string(64,'a');s.adapterSha256=std::string(64,'b');return s;
}
static AECMicrophoneChain::NCWorkerFactory ncFactory(const char* node,const char* script,const char* mode) {
    return [=](krisp_probe::WorkerLaunchConfig built,std::string& error,krisp_probe::ProviderBufferingConfig buffering){
        assert(built.executable=="/usr/bin/sandbox-exec");
        assert(built.expectedReadyLine.find(" outbound ")!=std::string::npos);
        krisp_probe::WorkerLaunchConfig config;config.executable=node;
        config.arguments={script,mode,"chain-fixture-ready","000102030405060708090a0b0c0d0e0f"};config.expectedReadyLine="chain-fixture-ready\n";
        for(unsigned i=0;i<16;++i)config.token[i]=i;
        config.startupTimeout=1000ms;config.frameTimeout=100ms;config.shutdownTimeout=100ms;
        return krisp_probe::ProviderWorker::create(std::move(config),error,buffering);
    };
}
static void waitChain(const std::shared_ptr<AECMicrophoneChain>& chain,std::uint64_t frames,bool installed) {
    const auto deadline=std::chrono::steady_clock::now()+2s;
    while(chain->healthy() && (chain->aecProcessedFrames()<frames || (installed && chain->microphoneProcessedFrames()<frames)) && std::chrono::steady_clock::now()<deadline)std::this_thread::yield();
    assert(chain->healthy() && chain->aecProcessedFrames()==frames && (!installed || chain->microphoneProcessedFrames()==frames));
}
int main(int argc,char** argv) {
    assert(argc==6); // Own AEC worker/library/SHA, Node executable, own NC fixture script.
    AECMicrophoneChainOptions options;
    options.aec.settings={argv[1],krisp_probe::installed_aec_worker_detail::hashWorker(argv[1]),"/unread/vendor/libAEC"};
    OwnFactory aecFactory{argv[2],argv[3],""};const auto normalNC=ncFactory(argv[4],argv[5],"normal");std::string error;
    for(auto maximum:{480u,512u,4096u})for(unsigned mode:{0u,1u,2u}) {
        const bool installed=mode==1;
        options.microphone=installed?std::optional{ncSettings()}:std::nullopt;options.microphoneRNNoise=mode==2;
        auto chain=AECMicrophoneChain::create(layout(maximum),options,error,aecFactory,normalNC);assert(chain && error.empty());
        const auto aecDelay=((maximum+958)/480+2)*480;
        const auto ncDelay=installed?aecDelay:mode==2?480:0;
        assert(chain->aecDelaySamples()==aecDelay && chain->microphoneDelaySamples()==ncDelay && chain->actualDelaySamples()==aecDelay+ncDelay);
        assert(chain->maximumCallbackFrames()==maximum && (chain->microphoneSettings()!=nullptr)==installed);
        Speaker speaker;Context context(layout(maximum),Speaker::process,&speaker,{},chain->binding(),true);context.enabled=true;
        NoiseAdapter baseline(true,false);
        std::array<float,1024> referenceMeans{};
        std::array<float,callbackLimit> baselineInput{},baselineOutput{};
        std::array<float,callbackLimit*2> zeroMonitor{},discard{};
        std::size_t position=0;
        for(unsigned turn=0;turn<60;++turn) {
            const UInt32 count=std::min(maximum,turn%6==0?1u:turn%6==1?479u:turn%6==2?480u:turn%6==3?481u:turn%6==4?512u:4096u);
            Cycle cycle(count,position);const bool speakerMute=turn%7==3,micMute=turn%11==5;
            assert(context.controls.publish({{.5f,micMute},{.25f,speakerMute}}));
            const float previousLeft=speaker.left,previousRight=speaker.right;
            for(UInt32 i=0;i<count;++i) {
                const float l=speakerMute?0:(i?cycle.in[3*(i-1)+1]*2:previousLeft)*.25f;
                const float r=speakerMute?0:(i?cycle.in[3*(i-1)+2]*2:previousRight)*.25f;
                const auto at=position+i;if(at%480==0)referenceMeans[at/480]=(l+r)/2;
                const auto source=at>=aecDelay?at-aecDelay:0;
                baselineInput[i]=at<aecDelay?0:float(source%997)/32-referenceMeans[source/480];
            }
            if(mode==2)assert(NoiseAdapter::process(&baseline,baselineInput.data(),zeroMonitor.data(),baselineOutput.data(),discard.data(),count));
            cycle.run(context);assert(speaker.calls==turn+1);
            for(UInt32 i=0;i<count;++i) {
                const float l=speakerMute?0:(i?cycle.in[3*(i-1)+1]*2:previousLeft)*.25f;
                const float r=speakerMute?0:(i?cycle.in[3*(i-1)+2]*2:previousRight)*.25f;
                assert(cycle.out[3*i+1]==l && cycle.out[3*i+2]==r);
                const auto at=position+i;const std::size_t delay=aecDelay+ncDelay,source=at>=delay?at-delay:0;
                float expected=mode==2?baselineOutput[i]:at<delay?0:(float(source%997)/32-referenceMeans[source/480])*(installed?.5f:1.f);
                expected=micMute?0:expected*.5f;assert(cycle.out[3*i]==expected);
            }
            position+=count;waitChain(chain,position/480,installed);
        }
        assert(chain->stop() && chain->stop() && !chain->healthy());
        DuplexBlock block;block.count=1;block.epoch=chain->epoch();float out=9;assert(!AECMicrophoneChain::process(chain.get(),block,&out) && out==0 && chain->error().empty());
    }
    // Bad second-stage contracts cannot start the first child.
    unsigned aecCalls=0,ncCalls=0;
    AECMicrophoneChain::AECWorkerFactory noAEC=[&](auto,auto&,auto){++aecCalls;return std::shared_ptr<krisp_probe::AECDuplexWorker>{};};
    AECMicrophoneChain::NCWorkerFactory noNC=[&](auto,auto&,auto){++ncCalls;return std::shared_ptr<krisp_probe::ProviderWorker>{};};
    options.microphone=ncSettings();options.microphoneRNNoise=false;
    for(unsigned mutation=0;mutation<6;++mutation){auto bad=options;
        if(mutation==0)bad.microphoneRNNoise=true;
        if(mutation==1)bad.microphone->modelRole=krisp_probe::InstalledModelRole::inbound;
        if(mutation==2)bad.microphone->bypass=true;
        if(mutation==3)bad.microphone->adapterSha256="bad";
        if(mutation==4)bad.microphone->modelPath="relative";
        if(mutation==5)bad.schedulingBudgetFrames=SIZE_MAX;
        assert(!AECMicrophoneChain::create(layout(),bad,error,noAEC,noNC) && !error.empty() && aecCalls==0 && ncCalls==0);
    }
    // Failure starting NC stops the AEC child; a later valid create still works.
    assert(!AECMicrophoneChain::create(layout(),options,error,aecFactory,ncFactory(argv[4],argv[5],"wrong-ready")) && !error.empty());
    for(bool failAEC:{false,true}) {
        auto a=aecFactory;if(failAEC)a.mode="forward";
        std::shared_ptr<krisp_probe::ProviderWorker> postWorker;
        auto selected=failAEC?normalNC:ncFactory(argv[4],argv[5],"malformed");
        auto capture=[&](auto launch,auto& failure,auto buffering){postWorker=selected(std::move(launch),failure,buffering);return postWorker;};
        auto chain=AECMicrophoneChain::create(layout(480),options,error,a,capture);assert(chain);
        std::array<float,480> mic{},out{};std::array<float,960> ref{};
        DuplexBlock block{mic.data(),ref.data(),480,chain->epoch(),{0,0,0,true,false},{0,0,0,true,false}};assert(AECMicrophoneChain::process(chain.get(),block,out.data()));
        const auto deadline=std::chrono::steady_clock::now()+2s;while(chain->healthy() && std::chrono::steady_clock::now()<deadline)std::this_thread::yield();assert(!chain->healthy());
        block.microphoneTiming.inputSampleOrigin=block.microphoneTiming.outputSampleOrigin=block.referenceTiming.inputSampleOrigin=block.referenceTiming.outputSampleOrigin=480;
        out.fill(9);assert(!AECMicrophoneChain::process(chain.get(),block,out.data()));for(auto v:out)assert(v==0);assert(!chain->stop() && !chain->error().empty());assert(postWorker && !postWorker->healthy());
    }
    // Control stop overlaps repeated callbacks. Binding ownership keeps stopped
    // storage alive after the separate control owner is released. All waits are
    // outside the guarded callback invocation.
    for(bool rnnoise:{false,true}) {
        auto selected=options;selected.microphone=rnnoise?std::nullopt:std::optional{ncSettings()};selected.microphoneRNNoise=rnnoise;
        auto owner=AECMicrophoneChain::create(layout(480),selected,error,aecFactory,normalNC);assert(owner);
        auto context=std::make_shared<Context>(layout(480),nullptr,nullptr,std::shared_ptr<void>{},owner->binding(),true);
        std::weak_ptr<AECMicrophoneChain> weak=owner;auto* raw=owner.get();
        std::atomic<bool> entered{false},released{false};
        std::thread callback([&]{std::array<float,480> mic{},out{};std::array<float,960> ref{};std::size_t position=0;
            while(raw->healthy() && !released.load()) {
                DuplexBlock block{mic.data(),ref.data(),1,raw->epoch(),{double(position),double(position),0,true,false},{double(position),double(position),0,true,false}};
                callbackGuard=true;(void)AECMicrophoneChain::process(raw,block,out.data());callbackGuard=false;
                ++position;entered.store(true);std::this_thread::yield();
            }
            while(!released.load())std::this_thread::yield();
            out.fill(9);DuplexBlock late;late.count=480;late.epoch=raw->epoch();callbackGuard=true;const bool result=AECMicrophoneChain::process(raw,late,out.data());callbackGuard=false;assert(!result);for(auto v:out)assert(v==0);
        });
        while(!entered.load())std::this_thread::yield();const bool clean=owner->stop();owner.reset();assert(!weak.expired());released.store(true);callback.join();if(clean)assert(weak.lock()->error().empty());context.reset();assert(weak.expired());
    }
    // A failed second worker close is reported even after AEC closes cleanly.
    {auto chain=AECMicrophoneChain::create(layout(),options,error,aecFactory,ncFactory(argv[4],argv[5],"close-stall"));assert(chain);assert(!chain->stop() && !chain->stop());}
    {Fake backend;Session session(backend);std::shared_ptr<AECMicrophoneChain> owner;std::weak_ptr<AECMicrophoneChain> weak;
     assert(session.start({"input","output"},nullptr,nullptr,{}, {},[&](const Layout& l){owner=AECMicrophoneChain::create(l,options,error,aecFactory,normalNC);assert(owner);weak=owner;ProcessorBinding binding;binding.microphoneStageDisabled=true;binding.duplex=owner->binding();return binding;}));auto queued=backend.context;backend.failUnregister=true;assert(!session.stop());assert(owner->stop());owner.reset();assert(!weak.expired());Cycle late(480,0);late.run(*queued);assert(late.zero());backend.failUnregister=false;assert(session.stop() && !weak.expired());queued.reset();assert(weak.expired());}
    std::cout<<"AEC to microphone NC chain synthetic integration passed\n";
}
