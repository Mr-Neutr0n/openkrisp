#include "provider_transport.hpp"
#include <cassert>
#include <iostream>
#include <limits>
#include <thread>
using T = krisp_probe::ProviderTransport<>;
static void service(T& transport) {
    T::Frame frame;
    while (transport.acquire(frame)) {
        for (auto& value : frame.samples) value *= 0.5f;
        assert(transport.submit(frame));
    }
}
int main() {
    assert(T{}.actualDelaySamples() == T::delaySamples);
    assert((krisp_probe::ProviderTransport<32,11>{}.actualDelaySamples() == 5280));
    for (auto maximum : {std::size_t(1),17ul,479ul,480ul,481ul,512ul,4096ul}) {
        for (auto budget : {std::size_t(0),1ul,2ul}) {
            krisp_probe::ProviderBufferingConfig config{maximum,budget};
            T t(config);
            const auto delay=((maximum+958)/480+budget)*480;
            assert(t.actualDelaySamples()==delay && t.maximumCallbackFrames()==maximum);
            config.maximumCallbackFrames=0; // Constructor copied immutable settings.
            assert(t.bufferingConfig().maximumCallbackFrames==maximum);
            std::array<float,4096> input{},output{};
            std::size_t offset=0;
            for(unsigned block=0;block<1500;++block) {
                // 478 then512 is an adversarial boundary: frame completion can
                // occur near callback entry. Broker only runs after the block.
                const auto count=std::min(maximum, block%3==0?std::size_t(478):
                                                     block%3==1?maximum:std::size_t(1));
                for(std::size_t i=0;i<count;++i) input[i]=float((offset+i)%997);
                assert(t.exchange(input.data(),output.data(),count));
                for(std::size_t i=0;i<count;++i)
                    assert(output[i]==(offset+i<delay?0:float((offset+i-delay)%997)*.5f));
                offset+=count;
                service(t);
            }
        }
    }
    for (auto config : {krisp_probe::ProviderBufferingConfig{0,0},
                        krisp_probe::ProviderBufferingConfig{4097,0},
                        krisp_probe::ProviderBufferingConfig{4096,22},
                        krisp_probe::ProviderBufferingConfig{480,std::numeric_limits<std::size_t>::max()}}) {
        bool rejected=false;
        try { T t(config); } catch(const std::invalid_argument&) { rejected=true; }
        assert(rejected);
    }
    assert(T(krisp_probe::ProviderBufferingConfig{4096,21}).actualDelaySamples()==31*480);
    {
        T t(krisp_probe::ProviderBufferingConfig{17,0});
        std::array<float,18> input{},output{}; output.fill(9);
        assert(!t.exchange(input.data(),output.data(),18));
        for(auto value:output) assert(value==9); // Extent above declaration stays untouched.
        assert(t.fault()==T::Fault::invalid_input);
    }
    {
        T t;
        std::array<float, 4096> in{}, out{};
        std::uint64_t offset = 0;
        constexpr std::array<std::size_t, 8> chunks{1, 17, 479, 960, 3, 4096, 23, 480};
        for (unsigned block = 0; block < 1000; ++block) {
            auto count = chunks[block % chunks.size()];
            for (std::size_t i = 0; i < count; ++i) in[i] = float((offset + i) % 997);
            assert(t.exchange(in.data(), out.data(), count));
            for (std::size_t i = 0; i < count; ++i) {
                const auto pos = offset + i;
                const float expected = pos < T::delaySamples ? 0 : float((pos - T::delaySamples) % 997) * 0.5f;
                assert(out[i] == expected);
            }
            offset += count;
            service(t);
        }
    }
    {
        T t;
        std::array<float, 480> in{}, out{};
        for (unsigned i = 0; i < 12; ++i) assert(t.exchange(in.data(), out.data(), 480));
        out.fill(9);
        assert(!t.exchange(in.data(), out.data(), 480));
        assert(t.fault() == T::Fault::deadline);
        for (auto value : out) assert(value == 0);
        t.fail(T::Fault::worker_dead);
        assert(t.fault() == T::Fault::deadline);
    }
    {
        T t; T::Frame frame;
        std::array<float, 480> in{}, out{};
        assert(t.exchange(in.data(), out.data(), 480));
        assert(t.acquire(frame));
        assert(!t.acquire(frame));
        ++frame.sequence;
        assert(!t.submit(frame));
        assert(t.fault() == T::Fault::sequence);
    }
    {
        T t; T::Frame frame;
        std::array<float, 480> in{}, out{};
        assert(t.exchange(in.data(), out.data(), 480));
        assert(t.acquire(frame));
        frame.samples[479] = std::numeric_limits<float>::infinity();
        assert(!t.submit(frame));
        assert(t.fault() == T::Fault::invalid_output);
    }
    {
        T t; T::Frame frame;
        assert(!t.submit(frame));
        assert(t.fault() == T::Fault::sequence);
    }
    {
        T t;
        float in = std::numeric_limits<float>::quiet_NaN(), out = 9;
        assert(!t.exchange(&in, &out, 1));
        assert(out == 0 && t.fault() == T::Fault::invalid_input);
    }
    {
        T t;
        float in = 1, out = 9;
        t.fail(T::Fault::worker_dead);
        assert(!t.exchange(&in, &out, 1));
        assert(out == 0 && t.fault() == T::Fault::worker_dead);
    }
    {
        T t; T::Frame frame;
        std::array<float, 480> in{}, out{};
        assert(t.exchange(in.data(), out.data(), 480));
        assert(t.acquire(frame));
        assert(t.submit(frame));
        assert(!t.submit(frame));
        assert(t.fault() == T::Fault::sequence);
    }
    {
        T t;
        float in = 1, out = 9;
        assert(!t.exchange(&in, &out, 4097));
        assert(out == 9 && t.fault() == T::Fault::invalid_input);
    }
    {
        // Handshakes occur outside exchange. This tests real concurrent queue
        // access without making model deadlines depend on scheduler speed.
        T t;
        std::atomic<unsigned> completed{0};
        std::thread broker([&] {
            T::Frame frame;
            for (unsigned i = 0; i < 20000; ++i) {
                while (!t.acquire(frame)) std::this_thread::yield();
                assert(frame.sequence == i);
                for (auto& sample : frame.samples) sample *= 0.5f;
                assert(t.submit(frame));
                completed.store(i + 1, std::memory_order_release);
            }
        });
        std::array<float, 480> in{}, out{};
        for (unsigned block = 0; block < 20000; ++block) {
            in.fill(float(block % 997));
            // Irregular partitions also overlap broker activity with callback
            // publication/consumption, including ring wraparound.
            assert(t.exchange(in.data(), out.data(), 17));
            assert(t.exchange(in.data() + 17, out.data() + 17, 463));
            for (auto sample : out)
                assert(sample == (block < 12 ? 0 : float((block - 12) % 997) * 0.5f));
            while (completed.load(std::memory_order_acquire) != block + 1)
                std::this_thread::yield();
        }
        broker.join();
        assert(t.fault() == T::Fault::none);
    }
    std::cout << "provider transport tests passed\n";
}
