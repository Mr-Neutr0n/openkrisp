#include "accent_worker.hpp"
#include <cassert>
#include <iostream>
#include <vector>

using labvoice::accent::Transport;
static void partition(std::size_t maximum, const std::vector<std::size_t>& blocks) {
    Transport<> transport({maximum,2});
    std::vector<float> in(maximum), out(maximum), actual;
    std::size_t position=0, next=0;
    for (unsigned block=0; block<80; ++block) {
        auto size=blocks[block%blocks.size()];
        for(std::size_t i=0;i<size;++i) in[i]=float(position+i+1)/100000.f;
        assert(transport.exchange(in.data(),out.data(),size));
        actual.insert(actual.end(),out.begin(),out.begin()+size); position+=size;
        Transport<>::Frame frame;
        while(transport.acquire(frame)) {
            assert(frame.sequence==next++);
            frame.produced=frame.sequence!=0;
            for(auto& sample:frame.samples) sample*=0.5f;
            assert(transport.submit(frame));
        }
    }
    const auto delay=transport.actualDelaySamples();
    for(std::size_t i=0;i<actual.size();++i)
        assert(actual[i]==(i<delay+480 ? 0.f : float(i-delay+1)/100000.f*0.5f));
    transport.fail(Transport<>::Fault::stopped);
    assert(!transport.exchange(in.data(),out.data(),maximum));
    for(float sample:out)assert(sample==0);
}
int main(int argc,char** argv) {
    assert(argc==3);
    partition(480,{480,1,127,352}); partition(4096,{4096,512,1,479,17});
    Transport<> late({480,2}); std::array<float,480> in{},out{};
    for(unsigned i=0;i<4;++i)assert(late.exchange(in.data(),out.data(),480));
    assert(!late.exchange(in.data(),out.data(),480)); assert(late.fault()==Transport<>::Fault::deadline);
    Transport<> bad({480,2}); Transport<>::Frame frame;
    assert(bad.exchange(in.data(),out.data(),480)); assert(bad.acquire(frame));
    frame.sequence++; assert(!bad.submit(frame)); assert(bad.fault()==Transport<>::Fault::sequence);
    accent_engine::WorkerLaunchConfig config;
    config.executable=argv[1]; config.arguments={argv[2],"empty-startup","accent-fixture"};
    config.environment={"PATH=/usr/bin:/bin"}; config.expectedReadyLine="accent-fixture\n";
    for(unsigned i=0;i<config.token.size();++i)config.token[i]=i;
    std::string error;
    auto worker=labvoice::accent::Worker::create(config,{480,6},error);
    assert(worker && error.empty()); in.fill(0.4f);
    for(unsigned i=0;i<60;++i) {
        assert(worker->exchange(in.data(),out.data(),480));
        if(i>=9)for(float sample:out)assert(sample==0.2f);
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    assert(worker->healthy()); assert(worker->empty()==1); assert(worker->processed()==60);
    assert(worker->stop()); assert(!worker->healthy());
    assert(!worker->exchange(in.data(),out.data(),480)); for(float sample:out)assert(sample==0);
    config.arguments[1]="startup-crash";
    assert(!labvoice::accent::Worker::create(config,{480,2},error)); assert(!error.empty());
    std::cout << "Accent scheduling transport, explicit empty slot, partitions, deadlines, sequencing, worker startup/stop passed. No vendor assets loaded.\n";
}
