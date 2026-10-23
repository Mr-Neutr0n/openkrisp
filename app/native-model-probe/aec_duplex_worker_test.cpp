#include "aec_duplex_worker.hpp"
#include "installed_aec_worker_launch.hpp"
#include <array>
#include <cassert>
#include <chrono>
#include <fstream>
#include <iostream>
#include <limits>
#include <vector>
#include <unistd.h>
using namespace krisp_probe;
using namespace std::chrono_literals;
namespace {
std::string hex(const aec_wire::Token& token){
    constexpr char digits[]="0123456789abcdef";std::string value;
    for(auto byte:token){value+=digits[byte>>4];value+=digits[byte&15];}return value;
}
AECWorkerLaunchConfig actual(const char* worker,const char* library,const char* librarySHA){
    AECWorkerLaunchConfig config;config.token[0]=7;
    config.executable="/usr/bin/sandbox-exec";
    config.arguments={"-p","(version 1) (allow default) (deny network*)",worker,library,librarySHA,hex(config.token),std::to_string(getpid())};
    config.environment={"PATH=/usr/bin:/bin"};
    config.expectedReadyLine=std::string("OKAEC1 ")+librarySHA+" 48000 1 48000 2\n";
    config.startupTimeout=2s;config.frameTimeout=200ms;config.shutdownTimeout=200ms;return config;
}
AECWorkerLaunchConfig synthetic(const char* fixture,const char* mode){
    AECWorkerLaunchConfig config;config.executable=fixture;config.arguments={mode};
    config.token[0]=7;config.expectedReadyLine="aec-fixture\n";
    config.startupTimeout=1s;config.frameTimeout=100ms;config.shutdownTimeout=100ms;return config;
}
void waitProcessed(const std::shared_ptr<AECDuplexWorker>& owner,std::uint64_t frames){
    const auto deadline=std::chrono::steady_clock::now()+3s;
    while(owner->processedFrames()<frames && owner->healthy() && std::chrono::steady_clock::now()<deadline)
        std::this_thread::sleep_for(1ms);
    assert(owner->healthy() && owner->processedFrames()==frames);
}
void waitFinished(const std::shared_ptr<AECDuplexWorker>& owner){
    const auto deadline=std::chrono::steady_clock::now()+3s;
    while(owner->healthy() && std::chrono::steady_clock::now()<deadline)std::this_thread::sleep_for(1ms);
    assert(!owner->healthy());
}
}
int main(int argc,char** argv){
    assert(argc==5); // own worker, independent own library, own library SHA, broker fixture
    std::array<float,4096> microphone{},output{};
    std::array<float,8192> reference{};
    for(auto buffering:{AECDuplexBufferingConfig{480,2},AECDuplexBufferingConfig{512,4},AECDuplexBufferingConfig{4096,2}}){
        std::string error;
        auto owner=AECDuplexWorker::create(actual(argv[1],argv[2],argv[3]),error,buffering);
        assert(owner && error.empty() && owner->healthy());
        assert(owner->maximumCallbackFrames()==buffering.maximumCallbackFrames);
        const auto delay=owner->actualDelaySamples();
        std::size_t cursor=0;
        std::vector<std::pair<std::size_t,std::size_t>> callbacks;
        for(unsigned callback=0;callback<180;++callback){
            const std::size_t count=buffering.maximumCallbackFrames==480?480:callback%3==0?17:callback%3==1?buffering.maximumCallbackFrames:463;
            for(std::size_t i=0;i<count;++i){microphone[i]=float((cursor+i)%113)/256;
                const float value=float(((cursor+i)/480)%17)/128;reference[2*i]=reference[2*i+1]=value;}
            AECDuplexTransport::PairedBlock block;
            block.microphone=microphone.data();block.finalReference=reference.data();block.count=count;block.epoch=3;
            block.microphoneStamp={double(cursor)+0.25,double(cursor)+300.25,12345+callback,true,true};
            block.referenceStamp={double(cursor)+7.75,double(cursor)+1207.75,22345+callback,true,true};
            callbacks.push_back({cursor,count});
            AECDuplexTransport::OutputMetadata metadata;
            assert(owner->exchange(block,output.data(),&metadata));
            for(std::size_t i=0;i<count;++i){
                const auto sample=cursor+i;
                const float expected=sample<delay?0:float((sample-delay)%113)/256-float(((sample-delay)/480)%17)/128;
                assert(output[i]==expected);
            }
            std::size_t described=0;
            for(std::size_t i=0;i<metadata.count;++i){
                const auto& span=metadata.spans[i];
                assert(span.count>0 && span.outputOffset+span.count<=count && span.frameSampleOffset+span.count<=480);
                assert(cursor+span.outputOffset>=delay);
                const auto source=cursor+span.outputOffset-delay;
                assert(span.sequence==source/480 && span.frameSampleOffset==source%480 && span.epoch==3);
                assert(span.microphoneTiming.inputSampleOrigin==double(span.sequence*480)+0.25);
                assert(span.referenceTiming.inputSampleOrigin==double(span.sequence*480)+7.75);
                assert(span.microphoneTiming.hostTime==0 && span.referenceTiming.hostTime==0);
                assert(span.microphoneTiming.flags==1 && span.referenceTiming.flags==1);
                const auto origin=span.sequence*480;
                std::size_t first=0;while(first+1<callbacks.size() && callbacks[first+1].first<=origin)++first;
                assert(origin<callbacks[first].first+callbacks[first].second);
                assert(span.microphoneProvenance.callbackHostTime==12345+first && span.referenceProvenance.callbackHostTime==22345+first);
                assert(span.microphoneProvenance.sampleOffset==origin-callbacks[first].first);
                assert(span.referenceProvenance.sampleOffset==span.microphoneProvenance.sampleOffset);
                assert(span.microphoneProvenance.callbackInputSampleOrigin==double(callbacks[first].first)+0.25);
                assert(span.referenceProvenance.callbackOutputSampleOrigin==double(callbacks[first].first)+1207.75);
                described+=span.count;
            }
            assert(described==(cursor+count<=delay?0:std::min(count,cursor+count-delay)));
            // Deliberate test handshake outside exchange. This verifies ordering
            // and lifetime, not production scheduler latency or callback timing.
            cursor+=count;waitProcessed(owner,cursor/480);
        }
        assert(owner->stop() && owner->stop() && owner->error().empty());
        AECDuplexTransport::PairedBlock stopped;
        stopped.microphone=microphone.data();stopped.finalReference=reference.data();stopped.count=480;
        output.fill(9);assert(!owner->exchange(stopped,output.data()));
        for(unsigned i=0;i<480;++i)assert(output[i]==0);
    }
    for(auto duration:{std::chrono::milliseconds::min(),std::chrono::milliseconds::max(),0ms,30001ms}){
        auto config=synthetic(argv[4],"normal");config.startupTimeout=duration;std::string error;
        assert(!AECDuplexWorker::create(std::move(config),error));assert(!error.empty());
    }
    {std::string error;assert(!AECDuplexWorker::create(synthetic(argv[4],"startup-crash"),error));assert(!error.empty());}
    for(const char* mode:{"crash","malformed","timing","stall"}){
        std::string error;auto owner=AECDuplexWorker::create(synthetic(argv[4],mode),error,{480,4});assert(owner);
        AECDuplexTransport::PairedBlock block;block.microphone=microphone.data();block.finalReference=reference.data();block.count=480;
        block.microphoneStamp={0,0,0,true,false};block.referenceStamp=block.microphoneStamp;
        assert(owner->exchange(block,output.data()));waitFinished(owner);assert(!owner->stop());assert(!owner->error().empty());
    }
    for(const char* mode:{"close-stall","close-trailing","nonzero-exit"}){
        std::string error;auto owner=AECDuplexWorker::create(synthetic(argv[4],mode),error,{480,4});assert(owner);
        assert(!owner->stop() && !owner->stop() && !owner->error().empty());
    }
    {
        std::array<char,64> directory{};std::strcpy(directory.data(),"/tmp/openkrisp-aec-owner-XXXXXX");assert(mkdtemp(directory.data()));
        const std::string trace=std::string(directory.data())+"/trace";
        auto config=actual(argv[1],argv[2],argv[3]);
        config.environment.push_back("OPENKRISP_AEC_FIXTURE_BLOCK_FORWARD=1");
        config.environment.push_back("OPENKRISP_AEC_FIXTURE_TRACE="+trace);
        std::string error;auto owner=AECDuplexWorker::create(std::move(config),error,{480,4});assert(owner);
        AECDuplexTransport::PairedBlock block;block.microphone=microphone.data();block.finalReference=reference.data();block.count=480;
        block.microphoneStamp={0,0,0,true,false};block.referenceStamp=block.microphoneStamp;
        assert(owner->exchange(block,output.data()));
        const auto deadline=std::chrono::steady_clock::now()+3s;bool entered=false;
        while(std::chrono::steady_clock::now()<deadline){std::ifstream input(trace);std::string line;
            while(std::getline(input,line))if(line=="reverse")entered=true;
            if(entered)break;std::this_thread::sleep_for(1ms);}
        assert(entered);assert(!owner->stop() && !owner->stop());assert(!owner->error().empty());
        unlink(trace.c_str());rmdir(directory.data());
    }
    std::cout<<"AEC duplex owner own-worker ordering, readiness, lifecycle and failure tests passed\n";
}
