#include "aec_duplex_transport.hpp"
#include <cassert>
#include <cstdlib>
#include <iostream>
#include <new>
#include <thread>
#include <vector>

thread_local bool callbackGuard = false;
void* operator new(std::size_t size) { assert(!callbackGuard); if (auto* p = std::malloc(size ? size : 1)) return p; throw std::bad_alloc(); }
void* operator new[](std::size_t size) { return ::operator new(size); }
void* operator new(std::size_t size, std::align_val_t alignment) { assert(!callbackGuard); void* p=nullptr; if(posix_memalign(&p,static_cast<std::size_t>(alignment),size ? size : 1))throw std::bad_alloc();return p; }
void* operator new[](std::size_t size, std::align_val_t alignment) { return ::operator new(size,alignment); }
void operator delete(void* p, std::align_val_t) noexcept { std::free(p); }
void operator delete[](void* p, std::align_val_t) noexcept { std::free(p); }
void operator delete(void* p) noexcept { std::free(p); }
void operator delete[](void* p) noexcept { std::free(p); }
using T = krisp_probe::AECDuplexTransport;
using Config = krisp_probe::AECDuplexBufferingConfig;
using Block = krisp_probe::AECPairedBlock;
static float mic(std::uint64_t i) { return float(i % 997) / 8; }
static float left(std::uint64_t i) { return float(i % 251) / 16; }
static float right(std::uint64_t i) { return -float(i % 127) / 32; }
static float expected(std::uint64_t i) { return mic(i) - left(i) + 2 * right(i); }
static Block block(std::size_t count, std::uint64_t position, const float* microphone, const float* reference) {
    Block b{microphone,reference,count,19};
    b.microphoneStamp={10.25+double(position),100.75+double(position),position+700,true,true};
    b.referenceStamp={-500.5+double(position),9000.25+double(position),position+1700,true,true};
    return b;
}
static bool exchange(T& t,const Block& b,float* out,T::OutputMetadata* metadata=nullptr) {
    callbackGuard=true; const bool result=t.exchange(b,out,metadata); callbackGuard=false; return result;
}
static void complete(T& t) {
    T::Frame f;
    while(t.acquire(f)) {
        f.wire.kind=krisp_probe::aec_wire::Kind::result;
        for(std::size_t i=0;i<480;++i) f.wire.output[i]=f.wire.microphone[i]-f.wire.reference[2*i]+2*f.wire.reference[2*i+1];
        assert(t.submit(f));
    }
}
static void partitions(std::size_t maximum,std::size_t budget,bool mixed) {
    T t(Config{maximum,budget});
    const auto delay=((maximum+958)/480+budget)*480;
    assert(t.actualDelaySamples()==delay && t.maximumCallbackFrames()==maximum);
    std::array<float,4096> microphone{},out{};
    std::array<float,8192> reference{};
    std::vector<T::LaneProvenance> micAnchors,refAnchors;
    std::uint64_t position=0;
    constexpr std::array<std::size_t,8> pattern{1,479,480,481,512,4096,17,3};
    std::size_t acquired=0,describedTotal=0;
    const auto turns=std::max<std::size_t>(300,(delay+4*480+maximum-1)/maximum);
    for(std::size_t turn=0;turn<turns;++turn) {
        const auto count=mixed?std::min(maximum,pattern[turn%pattern.size()]):maximum;
        auto b=block(count,position,microphone.data(),reference.data());
        // Save the precise callback containing each model frame's first sample.
        for(std::size_t i=0;i<count;++i) {
            const auto at=position+i;
            microphone[i]=mic(at);reference[2*i]=left(at);reference[2*i+1]=right(at);
            if(at%480==0) {
                micAnchors.push_back({b.microphoneStamp.callbackHostTime,i,true,b.microphoneStamp.inputSampleOrigin,b.microphoneStamp.outputSampleOrigin});
                refAnchors.push_back({b.referenceStamp.callbackHostTime,i,true,b.referenceStamp.inputSampleOrigin,b.referenceStamp.outputSampleOrigin});
            }
        }
        T::OutputMetadata metadata;
        assert(exchange(t,b,out.data(),&metadata));
        for(std::size_t i=0;i<count;++i) assert(out[i]==(position+i<delay?0:expected(position+i-delay)));
        std::size_t described=0;
        for(std::size_t j=0;j<metadata.count;++j) {
            const auto& s=metadata.spans[j];
            assert(s.count && s.outputOffset+s.count<=count && s.frameSampleOffset+s.count<=480);
            assert(s.sequence==(position+s.outputOffset-delay)/480 && s.epoch==19);
            assert(s.frameSampleOffset==(position+s.outputOffset-delay)%480);
            assert(s.microphoneProvenance==micAnchors[s.sequence]);assert(s.referenceProvenance==refAnchors[s.sequence]);
            assert(s.microphoneTiming.inputSampleOrigin==10.25+double(s.sequence*480));
            assert(s.microphoneTiming.outputSampleOrigin==100.75+double(s.sequence*480));
            assert(s.referenceTiming.inputSampleOrigin==-500.5+double(s.sequence*480));
            assert(s.referenceTiming.outputSampleOrigin==9000.25+double(s.sequence*480));
            assert(s.microphoneTiming.flags==1 && s.referenceTiming.flags==1 && !s.microphoneTiming.hostTime && !s.referenceTiming.hostTime);
            described+=s.count;
        }
        const auto initial=position<delay?std::min<std::uint64_t>(count,delay-position):0;
        assert(described==count-initial);describedTotal+=described;
        T::Frame f;
        while(t.acquire(f)) {
            ++acquired;
            const auto seq=f.wire.sequence;assert(f.wire.kind==krisp_probe::aec_wire::Kind::request);
            assert(f.microphoneProvenance==micAnchors[seq] && f.referenceProvenance==refAnchors[seq]);
            for(std::size_t i=0;i<480;++i) {
                assert(f.wire.microphone[i]==mic(seq*480+i));
                assert(f.wire.reference[2*i]==left(seq*480+i));assert(f.wire.reference[2*i+1]==right(seq*480+i));
            }
            f.wire.kind=krisp_probe::aec_wire::Kind::result;
            for(std::size_t i=0;i<480;++i)f.wire.output[i]=expected(seq*480+i);
            assert(t.submit(f));
        }
        position+=count;
    }
    assert(t.fault()==T::Fault::none && acquired>=4 && describedTotal>0);
}
int main() {
    for(auto maximum:{1ul,479ul,480ul,481ul,512ul,4096ul})for(auto budget:{2ul,4ul})for(bool mixed:{false,true})partitions(maximum,budget,mixed);
    for(auto config:{Config{0,2},Config{4097,2},Config{4096,22},Config{480,SIZE_MAX}}) {
        bool rejected=false;try{T t(config);}catch(const std::invalid_argument&){rejected=true;}assert(rejected);
    }
    std::array<float,4096> in{},out{};std::array<float,8192> ref{};
    // A stalled broker produces exactly the fixed startup silence, then a
    // terminal deadline. Pending work cannot be submitted after that fault.
    for(auto budget:{2ul,4ul}) {
        T t(Config{480,budget});std::uint64_t pos=0;T::Frame pending;
        while(pos<t.actualDelaySamples()){assert(exchange(t,block(480,pos,in.data(),ref.data()),out.data()));pos+=480;}
        assert(t.acquire(pending));out.fill(7);T::OutputMetadata metadata;
        assert(!exchange(t,block(480,pos,in.data(),ref.data()),out.data(),&metadata));
        assert(t.fault()==T::Fault::deadline && metadata.count==0);
        for(unsigned i=0;i<480;++i)assert(out[i]==0);
        pending.wire.kind=krisp_probe::aec_wire::Kind::result;assert(!t.submit(pending));
        t.fail(T::Fault::worker_dead);assert(t.fault()==T::Fault::deadline);
    }
    // A late missing result clears valid audio already copied earlier in the
    // same large callback and discards its partially populated metadata.
    {T t;assert(exchange(t,block(4096,0,in.data(),ref.data()),out.data()));T::Frame first;assert(t.acquire(first));first.wire.kind=krisp_probe::aec_wire::Kind::result;first.wire.output.fill(5);assert(t.submit(first));T::OutputMetadata metadata;out.fill(9);assert(!exchange(t,block(4096,4096,in.data(),ref.data()),out.data(),&metadata));assert(t.fault()==T::Fault::deadline && metadata.count==0);for(auto value:out)assert(value==0);}
    // Bounded burst: service three requests together inside the four-frame slack.
    {T t(Config{480,4});for(unsigned i=0;i<40;++i){assert(exchange(t,block(480,i*480,in.data(),ref.data()),out.data()));if(i%3==2)complete(t);}complete(t);}
    for(int mutation=0;mutation<9;++mutation) {
        T t;assert(exchange(t,block(480,0,in.data(),ref.data()),out.data()));complete(t);
        auto b=block(480,480,in.data(),ref.data());
        if(mutation==0)b.microphoneStamp.inputSampleOrigin+=.5;
        if(mutation==1)b.referenceStamp.outputSampleOrigin+=.5;
        if(mutation==2)b.epoch++;
        if(mutation==3)b.referenceStamp.sampleOriginsValid=false;
        if(mutation==4)b.microphoneStamp.outputSampleOrigin=std::numeric_limits<double>::quiet_NaN();
        if(mutation==5)b.referenceStamp.inputSampleOrigin=1e30;
        if(mutation==6)in[479]=std::numeric_limits<float>::infinity();
        if(mutation==7)ref[959]=std::numeric_limits<float>::quiet_NaN();
        if(mutation==8)b.finalReference=nullptr;
        out.fill(9);assert(!exchange(t,b,out.data()));for(unsigned i=0;i<480;++i)assert(out[i]==0);
        T::Frame f;assert(!t.acquire(f));in[479]=0;ref[959]=0;
        assert(!exchange(t,block(480,960,in.data(),ref.data()),out.data()));
    }
    {T t;auto b=block(479,0,in.data(),ref.data());b.microphoneStamp.inputSampleOrigin=4503599627370495.5;assert(!exchange(t,b,out.data()));assert(t.fault()==T::Fault::timing);T::Frame f;assert(!t.acquire(f));}
    // Entire callback is validated before even its first complete pair publishes.
    {T t;in[4095]=std::numeric_limits<float>::quiet_NaN();assert(!exchange(t,block(4096,0,in.data(),ref.data()),out.data()));T::Frame f;assert(!t.acquire(f));in[4095]=0;}
    for(int mutation=0;mutation<7;++mutation) {
        T t;assert(exchange(t,block(480,0,in.data(),ref.data()),out.data()));T::Frame f;assert(t.acquire(f));assert(!t.acquire(f));f.wire.kind=krisp_probe::aec_wire::Kind::result;
        if(mutation==0)f.wire.sequence++;
        if(mutation==1)f.wire.epoch++;
        if(mutation==2)f.wire.referenceTiming.inputSampleOrigin+=1;
        if(mutation==3)f.microphoneProvenance.sampleOffset++;
        if(mutation==4)f.wire.output[479]=std::numeric_limits<float>::infinity();
        if(mutation==5)f.wire.kind=krisp_probe::aec_wire::Kind::request;
        if(mutation==6)f.wire.microphoneTiming.hostTime=1;
        assert(!t.submit(f));assert(t.fault()!=T::Fault::none);out.fill(9);assert(!exchange(t,block(480,480,in.data(),ref.data()),out.data()));for(unsigned i=0;i<480;++i)assert(out[i]==0);
    }
    {T t;T::Frame f;assert(!t.submit(f));assert(t.fault()==T::Fault::sequence);}
    {T t;assert(exchange(t,block(480,0,in.data(),ref.data()),out.data()));T::Frame f;assert(t.acquire(f));f.wire.kind=krisp_probe::aec_wire::Kind::result;assert(t.submit(f));assert(!t.submit(f));}
    {T t(Config{17,2});out.fill(9);assert(!exchange(t,block(18,0,in.data(),ref.data()),out.data()));for(auto x:out)assert(x==9);}
    {T t;auto b=block(480,0,in.data(),ref.data());in.fill(9);assert(!exchange(t,b,in.data()));for(unsigned i=0;i<480;++i)assert(in[i]==0);}
    // Real concurrent SPSC wraparound. Scheduling handshakes stay outside exchange.
    {T t(Config{480,4});std::atomic<unsigned> done{0};std::thread broker([&]{T::Frame f;for(unsigned i=0;i<5000;++i){while(!t.acquire(f))std::this_thread::yield();assert(f.wire.sequence==i);f.wire.kind=krisp_probe::aec_wire::Kind::result;f.wire.output.fill(float(i));assert(t.submit(f));done.store(i+1,std::memory_order_release);}});
     in.fill(0);for(unsigned turn=0;turn<5000;++turn){auto b=block(17,turn*480,in.data(),ref.data());assert(exchange(t,b,out.data()));b=block(463,turn*480+17,in.data()+17,ref.data()+34);assert(exchange(t,b,out.data()+17));for(unsigned i=0;i<480;++i)assert(out[i]==(turn<6?0:float(turn-6)));while(done.load(std::memory_order_acquire)!=turn+1)std::this_thread::yield();}broker.join();}
    std::cout<<"AEC duplex transport tests passed\n";
}
