#include "installed_noise_adapter.hpp"
#include <cassert>
#include <chrono>
#include <iostream>
#include <vector>
using namespace labvoice;
using namespace std::chrono_literals;
static Layout layout() { return {{3},{3},0,1,2,0,1,2,480,512}; }
static krisp_probe::InstalledWorkerSettings settings() {
    krisp_probe::InstalledWorkerSettings s;
    s.nodePath="/fixture/node"; s.workerPath="/fixture/worker";
    s.addonPath="/fixture/addon"; s.modelPath="/fixture/model";
    s.adapterPath="/fixture/adapter"; s.libraryPath="/fixture/library";
    s.nodeSha256=std::string(64,'a'); s.adapterSha256=std::string(64,'b'); return s;
}
static InstalledNoiseAdapter::WorkerFactory fixture(const char* node,const char* script,const char* mode) {
    return [=](krisp_probe::WorkerLaunchConfig built,std::string& error,krisp_probe::ProviderBufferingConfig buffering) {
        assert(built.executable=="/usr/bin/sandbox-exec");
        assert(built.expectedReadyLine.find(krisp_probe::installedOutboundModelSHA256)!=std::string::npos ||
               built.expectedReadyLine.find(krisp_probe::installedInboundModelSHA256)!=std::string::npos);
        krisp_probe::WorkerLaunchConfig c;
        c.executable=node; c.arguments={script,mode,"fixture-ready","000102030405060708090a0b0c0d0e0f"};
        c.expectedReadyLine="fixture-ready\n";
        for(unsigned i=0;i<16;++i)c.token[i]=i;
        c.startupTimeout=1500ms; c.frameTimeout=150ms; c.shutdownTimeout=150ms;
        return krisp_probe::ProviderWorker::create(std::move(c),error,buffering);
    };
}
static krisp_probe::InstalledWorkerSettings inboundSettings() {
    auto s=settings();s.modelRole=krisp_probe::InstalledModelRole::inbound;
    s.modelSha256=krisp_probe::installedInboundModelSHA256;return s;
}
int main(int argc,char** argv) {
    assert(argc==3);
    for(bool speakerEnabled:{false,true}) {
        std::string error;
        auto adapter=InstalledNoiseAdapter::create(layout(),settings(),speakerEnabled,error,0,fixture(argv[1],argv[2],"normal"));
        assert(adapter && error.empty() && adapter->healthy());
        assert(adapter->maximumCallbackFrames()==512 && adapter->actualDelaySamples()==1440);
        assert(adapter->speakerNoiseEnabled()==speakerEnabled);
        assert(adapter->nodeSha256()==std::string(64,'a') && adapter->adapterSha256()==std::string(64,'b'));
        NoiseAdapter reference(false,speakerEnabled);
        std::array<float,480> mic{},feed{},discard{};
        std::array<float,960> monitor{},playback{},expectedPlayback{};
        for(unsigned block=0;block<100;++block) {
            mic.fill(float(block)*.125f);
            for(unsigned i=0;i<480;++i) { monitor[2*i]=float(i%17)*.001f; monitor[2*i+1]=-float(i%23)*.001f; }
            for(auto offset:{0u,17u}) {
                const auto count=offset?463u:17u;
                assert(InstalledNoiseAdapter::process(adapter.get(),mic.data()+offset,monitor.data()+2*offset,
                                                      feed.data()+offset,playback.data()+2*offset,count));
                assert(NoiseAdapter::process(&reference,mic.data()+offset,monitor.data()+2*offset,
                                            discard.data()+offset,expectedPlayback.data()+2*offset,count));
            }
            assert(playback==expectedPlayback); // Exact existing stereo semantics.
            for(auto sample:feed) assert(sample==(block<3?0:float(block-3)*.0625f));
            const auto deadline=std::chrono::steady_clock::now()+2s;
            while(adapter->processedFrames()<block+1 && adapter->healthy() && std::chrono::steady_clock::now()<deadline)
                std::this_thread::sleep_for(1ms);
            assert(adapter->healthy() && adapter->processedFrames()==block+1);
        }
        assert(adapter->stop() && adapter->stop());
        feed.fill(9); playback.fill(9);
        assert(!InstalledNoiseAdapter::process(adapter.get(),mic.data(),monitor.data(),feed.data(),playback.data(),480));
        for(auto sample:feed)assert(sample==0);
        for(auto sample:playback)assert(sample==0);
        // Exercise real Context failure handling and retained callback ownership.
        std::weak_ptr<InstalledNoiseAdapter> retained=adapter;
        auto context=std::make_shared<Context>(layout(),InstalledNoiseAdapter::process,adapter.get(),adapter);
        adapter.reset(); assert(!retained.expired()); context->enabled=true;
        std::array<float,1440> input{},output{}; input.fill(.1f);output.fill(9);
        AudioBufferList in{},out{};
        in.mNumberBuffers=out.mNumberBuffers=1;
        in.mBuffers[0]={3,static_cast<UInt32>(input.size()*sizeof(float)),input.data()};
        out.mBuffers[0]={3,static_cast<UInt32>(output.size()*sizeof(float)),output.data()};
        AudioTimeStamp time{};time.mFlags=kAudioTimeStampSampleTimeValid;time.mSampleTime=1000;
        assert(Context::io(0,nullptr,&in,&time,&out,&time,context.get())==noErr);
        assert(context->changed);
        for(auto sample:output)assert(sample==0);
        context.reset();assert(retained.expired());
    }
    {
        std::string error;
        InstalledNoiseOptions dual;dual.microphone=settings();dual.speaker=inboundSettings();
        auto adapter=InstalledNoiseAdapter::create(layout(),dual,error,fixture(argv[1],argv[2],"normal"));
        assert(adapter);
        auto context=std::make_shared<Context>(layout(),InstalledNoiseAdapter::process,adapter.get(),adapter);
        std::atomic<bool> running{false}, finished{false};
        auto* callbackOwner=adapter.get();
        std::thread callback([&] {
            std::array<float,480> input{},feed{}; std::array<float,960> monitor{},playback{};
            running.store(true,std::memory_order_release);
            while(callbackOwner->healthy()) {
                // One sample per exchange permits many overlapping stop checks
                // without requiring an inference result in this race fixture.
                (void)InstalledNoiseAdapter::process(callbackOwner,input.data(),monitor.data(),feed.data(),playback.data(),1);
                std::this_thread::yield();
            }
            feed.fill(9);playback.fill(9);
            assert(!InstalledNoiseAdapter::process(callbackOwner,input.data(),monitor.data(),feed.data(),playback.data(),480));
            for(auto sample:feed)assert(sample==0);
            for(auto sample:playback)assert(sample==0);
            finished.store(true,std::memory_order_release);
        });
        while(!running.load(std::memory_order_acquire))std::this_thread::yield();
        (void)adapter->stop(); // Control-thread shutdown concurrent with callback.
        callback.join(); assert(finished.load(std::memory_order_acquire));
        std::weak_ptr<InstalledNoiseAdapter> retained=adapter;
        adapter.reset();assert(!retained.expired());
        // Simulate a late dispatch-thread Context release after failed HAL
        // removal. The worker was already joined on the control thread.
        std::thread lateRelease([owned=std::move(context)]() mutable { owned.reset(); });
        lateRelease.join();assert(retained.expired());
    }
    {
        std::string error; unsigned calls=0;
        InstalledNoiseAdapter::WorkerFactory forbidden=[&](auto,auto&,auto) { ++calls; return std::shared_ptr<krisp_probe::ProviderWorker>{}; };
        auto inbound=settings();
        inbound.modelRole=krisp_probe::InstalledModelRole::inbound;
        inbound.modelSha256=krisp_probe::installedInboundModelSHA256;
        assert(!InstalledNoiseAdapter::create(layout(),inbound,false,error,2,forbidden));
        assert(error=="Installed microphone provider requires outbound model role" && calls==0);
        auto invalid=layout(); invalid.maximumCallbackFrames=4097;
        assert(!InstalledNoiseAdapter::create(invalid,settings(),false,error,2,forbidden));
        assert(!InstalledNoiseAdapter::create(layout(),settings(),false,error,SIZE_MAX,forbidden));
        auto bypass=settings();bypass.bypass=true;
        assert(!InstalledNoiseAdapter::create(layout(),bypass,false,error,2,forbidden));
        assert(calls==0);
        assert(!InstalledNoiseAdapter::create(layout(),settings(),false,error,2,fixture(argv[1],argv[2],"wrong-ready")));
    }
    {
        std::string error;
        auto adapter=InstalledNoiseAdapter::create(layout(),settings(),false,error,2,fixture(argv[1],argv[2],"malformed"));
        assert(adapter);
        std::array<float,480> input{},feed{}; std::array<float,960> monitor{},playback{};
        assert(InstalledNoiseAdapter::process(adapter.get(),input.data(),monitor.data(),feed.data(),playback.data(),480));
        auto deadline=std::chrono::steady_clock::now()+2s;
        while(adapter->healthy() && std::chrono::steady_clock::now()<deadline)std::this_thread::sleep_for(1ms);
        assert(!adapter->healthy() && !adapter->stop() && !adapter->error().empty());
    }
    {
        InstalledNoiseOptions disabled;std::string error;
        auto adapter=InstalledNoiseAdapter::create(layout(),disabled,error);assert(adapter && adapter->healthy());
        assert(!adapter->microphoneInstalled() && !adapter->speakerInstalled());
        assert(adapter->microphoneSettings()==nullptr && adapter->speakerSettings()==nullptr);
        assert(adapter->microphoneDelaySamples()==0 && adapter->speakerDelaySamples()==0);
        std::array<float,17> mic{},feed{};std::array<float,34> monitor{},playback{};
        mic.fill(.25f);for(unsigned i=0;i<17;++i){monitor[2*i]=.125f;monitor[2*i+1]=-.25f;}
        assert(InstalledNoiseAdapter::process(adapter.get(),mic.data(),monitor.data(),feed.data(),playback.data(),17));
        assert(feed==mic && playback==monitor && adapter->stop());
    }
    for(unsigned microphoneMode=0;microphoneMode<3;++microphoneMode) {
        InstalledNoiseOptions options;options.speaker=inboundSettings();options.schedulingBudgetFrames=0;
        if(microphoneMode==1)options.microphoneRNNoise=true;
        if(microphoneMode==2)options.microphone=settings();
        std::string error;
        auto adapter=InstalledNoiseAdapter::create(layout(),options,error,fixture(argv[1],argv[2],"normal"));
        assert(adapter && error.empty() && adapter->speakerInstalled());
        assert(adapter->microphoneInstalled()==(microphoneMode==2));
        assert(adapter->speakerSettings()->modelRole==krisp_probe::InstalledModelRole::inbound);
        assert(adapter->speakerDelaySamples()==1440);
        assert(adapter->microphoneDelaySamples()==(microphoneMode==2?1440:microphoneMode==1?480:0));
        NoiseAdapter fallbackReference(microphoneMode==1,false);
        std::array<float,512> mic{},feed{},referenceFeed{};
        std::array<float,1024> monitor{},playback{},referencePlayback{};
        std::vector<float> micHistory,monoHistory;
        std::size_t position=0;
        for(unsigned block=0;block<160;++block) {
            constexpr std::array<unsigned,5> partitions{17,463,478,512,1};
            const auto count=partitions[block%partitions.size()];
            for(unsigned i=0;i<count;++i) {
                const auto p=position+i;mic[i]=float(p%19)*.015625f;
                float left=0,right=0;
                switch((p/2400)%5) {
                    case 0:left=.25f;break; // Left only.
                    case 1:right=-.5f;break; // Right only.
                    case 2:left=right=.125f;break; // Identical.
                    case 3:left=.25f;right=-.25f;break; // Opposite phase.
                    default:left=float(p%13)*.03125f;right=-float(p%17)*.015625f;
                }
                monitor[2*i]=left;monitor[2*i+1]=right;
                micHistory.push_back(mic[i]);monoHistory.push_back((left+right)/2.f);
            }
            assert(InstalledNoiseAdapter::process(adapter.get(),mic.data(),monitor.data(),feed.data(),playback.data(),count));
            assert(NoiseAdapter::process(&fallbackReference,mic.data(),monitor.data(),referenceFeed.data(),referencePlayback.data(),count));
            for(unsigned i=0;i<count;++i) {
                const auto p=position+i;
                const float expectedSpeaker=p<1440?0:monoHistory[p-1440]*.5f;
                assert(playback[2*i]==expectedSpeaker && playback[2*i+1]==expectedSpeaker);
                const float expectedMic=microphoneMode==2?(p<1440?0:micHistory[p-1440]*.5f):referenceFeed[i];
                assert(feed[i]==expectedMic);
            }
            position+=count;
            const auto deadline=std::chrono::steady_clock::now()+2s;
            while((adapter->speakerProcessedFrames()<position/480 ||
                  (microphoneMode==2 && adapter->microphoneProcessedFrames()<position/480)) &&
                  adapter->healthy() && std::chrono::steady_clock::now()<deadline)std::this_thread::sleep_for(1ms);
            assert(adapter->healthy() && adapter->speakerProcessedFrames()==position/480);
            if(microphoneMode==2)assert(adapter->microphoneProcessedFrames()==position/480);
        }
        assert(adapter->stop());
    }
    {
        // Every lane configuration must be validated before the first launch.
        InstalledNoiseOptions options;options.microphone=settings();options.speaker=inboundSettings();
        options.speaker->nodeSha256="bad";
        unsigned calls=0;std::string error;
        InstalledNoiseAdapter::WorkerFactory forbidden=[&](auto,auto&,auto){++calls;return std::shared_ptr<krisp_probe::ProviderWorker>{};};
        assert(!InstalledNoiseAdapter::create(layout(),options,error,forbidden) && calls==0);
        options.speaker=settings();assert(!InstalledNoiseAdapter::create(layout(),options,error,forbidden) && calls==0);
        options.speaker=inboundSettings();options.speakerRNNoise=true;
        assert(!InstalledNoiseAdapter::create(layout(),options,error,forbidden) && calls==0);
        options.speakerRNNoise=false;options.microphoneRNNoise=true;
        assert(!InstalledNoiseAdapter::create(layout(),options,error,forbidden) && calls==0);
    }
    {
        // A second startup failure must stop the already admitted first worker,
        // even if an injected test retains its owner beyond adapter construction.
        InstalledNoiseOptions options;options.microphone=settings();options.speaker=inboundSettings();
        std::shared_ptr<krisp_probe::ProviderWorker> first;unsigned calls=0;std::string error;
        auto success=fixture(argv[1],argv[2],"normal"),failure=fixture(argv[1],argv[2],"wrong-ready");
        auto factory=[&](auto launch,auto& err,auto buffering) {
            if(++calls==1){first=success(std::move(launch),err,buffering);return first;}
            return failure(std::move(launch),err,buffering);
        };
        assert(!InstalledNoiseAdapter::create(layout(),options,error,factory));
        assert(calls==2 && first && !first->healthy() && first->stop());
    }
    {
        InstalledNoiseOptions options;options.microphone=settings();options.speaker=inboundSettings();
        std::shared_ptr<krisp_probe::ProviderWorker> microphoneWorker,speakerWorker;
        std::string error;
        auto failure=fixture(argv[1],argv[2],"close-stall"),success=fixture(argv[1],argv[2],"normal");
        auto factory=[&](auto launch,auto& err,auto buffering) {
            const bool microphone=launch.expectedReadyLine.find(" outbound ")!=std::string::npos;
            auto worker=(microphone?failure:success)(std::move(launch),err,buffering);
            (microphone?microphoneWorker:speakerWorker)=worker;return worker;
        };
        auto adapter=InstalledNoiseAdapter::create(layout(),options,error,factory);assert(adapter);
        assert(!adapter->stop() && !adapter->stop());
        assert(!microphoneWorker->healthy() && !speakerWorker->healthy() && speakerWorker->stop());
    }
    {
        InstalledNoiseOptions options;options.microphone=settings();options.speaker=inboundSettings();
        std::string error;
        auto adapter=InstalledNoiseAdapter::create(layout(),options,error,fixture(argv[1],argv[2],"normal"));assert(adapter);
        std::array<float,480> mic{},feed{};std::array<float,960> monitor{},playback{};
        monitor[958]=monitor[959]=std::numeric_limits<float>::max();feed.fill(9);playback.fill(9);
        assert(!InstalledNoiseAdapter::process(adapter.get(),mic.data(),monitor.data(),feed.data(),playback.data(),480));
        for(auto value:feed)assert(value==0);for(auto value:playback)assert(value==0);
        assert(adapter->microphoneProcessedFrames()==0 && adapter->speakerProcessedFrames()==0 && !adapter->healthy());
        (void)adapter->stop();
    }
    {
        InstalledNoiseOptions options;options.microphone=settings();options.speaker=inboundSettings();
        std::string error;auto normal=fixture(argv[1],argv[2],"normal"),broken=fixture(argv[1],argv[2],"malformed");
        auto factory=[&](auto launch,auto& err,auto buffering) {
            return (launch.expectedReadyLine.find(" inbound ")!=std::string::npos?broken:normal)(std::move(launch),err,buffering);
        };
        auto adapter=InstalledNoiseAdapter::create(layout(),options,error,factory);assert(adapter);
        std::array<float,480> mic{},feed{};std::array<float,960> monitor{},playback{};
        assert(InstalledNoiseAdapter::process(adapter.get(),mic.data(),monitor.data(),feed.data(),playback.data(),480));
        auto deadline=std::chrono::steady_clock::now()+2s;
        while(adapter->healthy() && std::chrono::steady_clock::now()<deadline)std::this_thread::sleep_for(1ms);
        feed.fill(9);playback.fill(9);
        assert(!InstalledNoiseAdapter::process(adapter.get(),mic.data(),monitor.data(),feed.data(),playback.data(),480));
        for(auto value:feed)assert(value==0);for(auto value:playback)assert(value==0);
        assert(!adapter->stop());
    }
    std::cout<<"installed noise adapter tests passed\n";
}
