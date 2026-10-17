#include "installed_noise_adapter.hpp"
#include <cassert>
#include <chrono>
#include <iostream>
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
        assert(built.expectedReadyLine.find(krisp_probe::installed_worker_detail::modelSHA)!=std::string::npos);
        krisp_probe::WorkerLaunchConfig c;
        c.executable=node; c.arguments={script,mode,"fixture-ready","000102030405060708090a0b0c0d0e0f"};
        c.expectedReadyLine="fixture-ready\n";
        for(unsigned i=0;i<16;++i)c.token[i]=i;
        c.startupTimeout=1500ms; c.frameTimeout=150ms; c.shutdownTimeout=150ms;
        return krisp_probe::ProviderWorker::create(std::move(c),error,buffering);
    };
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
        auto adapter=InstalledNoiseAdapter::create(layout(),settings(),false,error,2,fixture(argv[1],argv[2],"normal"));
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
    std::cout<<"installed noise adapter tests passed\n";
}
