#include "provider_worker.hpp"
#include <cassert>
#include <chrono>
#include <iostream>
#include <sys/stat.h>
#include <unistd.h>
using namespace krisp_probe;
using namespace std::chrono_literals;
static WorkerLaunchConfig config(const char* node, const char* fixture, const char* mode) {
    WorkerLaunchConfig c;
    c.executable = node;
    c.arguments = {fixture, mode, "fixture-ready", "000102030405060708090a0b0c0d0e0f"};
    c.expectedReadyLine = "fixture-ready\n";
    for (unsigned i = 0; i < 16; ++i) c.token[i] = i;
    c.startupTimeout = 1500ms; c.frameTimeout = 150ms; c.shutdownTimeout = 150ms;
    return c;
}
int main(int argc, char** argv) {
    assert(argc == 3);
    {
        std::string error;
        auto worker = ProviderWorker::create(config(argv[1], argv[2], "normal"), error);
        assert(worker && error.empty());
        std::array<float, 480> input{}, output{};
        for (unsigned frame = 0; frame < 100; ++frame) {
            input.fill(float(frame));
            assert(worker->exchange(input.data(), output.data(), 17));
            assert(worker->exchange(input.data() + 17, output.data() + 17, 463));
            for (auto sample : output) assert(sample == (frame < 12 ? 0 : float(frame - 12) * .5f));
            // Test pacing is outside exchange. It does not claim realtime latency.
            const auto deadline = std::chrono::steady_clock::now() + 2s;
            while (worker->processedFrames() < frame + 1 && worker->healthy() &&
                   std::chrono::steady_clock::now() < deadline)
                std::this_thread::sleep_for(1ms);
            assert(worker->healthy() && worker->processedFrames() == frame + 1);
        }
        assert(worker->stop());
        assert(worker->stop());
        assert(worker->error().empty());
        output.fill(9);
        assert(!worker->exchange(input.data(), output.data(), 480));
        for (auto value : output) assert(value == 0);
    }
    for (auto buffering : {ProviderBufferingConfig{480,1},ProviderBufferingConfig{512,0}}) {
        std::string error;
        auto worker=ProviderWorker::create(config(argv[1],argv[2],"normal"),error,buffering);
        assert(worker && error.empty());
        const auto delay=((buffering.maximumCallbackFrames+958)/480+buffering.schedulingBudgetFrames)*480;
        assert(worker->actualDelaySamples()==delay);
        assert(worker->maximumCallbackFrames()==buffering.maximumCallbackFrames);
        std::array<float,512> input{},output{};
        std::size_t offset=0;
        for(unsigned block=0;block<150;++block) {
            const auto count=block%3==0?std::size_t(478):block%3==1?buffering.maximumCallbackFrames:std::size_t(1);
            for(std::size_t i=0;i<count;++i) input[i]=float((offset+i)%997);
            assert(worker->exchange(input.data(),output.data(),count));
            for(std::size_t i=0;i<count;++i)
                assert(output[i]==(offset+i<delay?0:float((offset+i-delay)%997)*.5f));
            offset+=count;
            const auto deadline=std::chrono::steady_clock::now()+2s;
            while(worker->processedFrames()<offset/480 && worker->healthy() &&
                  std::chrono::steady_clock::now()<deadline) std::this_thread::sleep_for(1ms);
            assert(worker->healthy() && worker->processedFrames()==offset/480);
        }
        assert(worker->stop());
    }
    {
        std::string error;
        // Buffering rejects before the wrong-ready child can be launched.
        assert(!ProviderWorker::create(config(argv[1],argv[2],"wrong-ready"),error,{0,0}));
        assert(error.find("Maximum callback")!=std::string::npos);
    }
    for (const auto* mode : {"processing-stall", "crash", "malformed"}) {
        std::string error;
        auto worker = ProviderWorker::create(config(argv[1], argv[2], mode), error);
        assert(worker);
        std::array<float, 480> input{}, output{};
        assert(worker->exchange(input.data(), output.data(), 480));
        const auto deadline = std::chrono::steady_clock::now() + 3s;
        while (worker->healthy() && std::chrono::steady_clock::now() < deadline) {
            (void)worker->error(); // Concurrent reads before publication return empty.
            std::this_thread::sleep_for(1ms);
        }
        assert(!worker->healthy());
        assert(!worker->stop());
        assert(!worker->error().empty());
        assert(worker->fault() == ProviderTransport<>::Fault::worker_failure);
    }
    {
        std::string error;
        char marker[] = "/tmp/openkrisp-processing-XXXXXX";
        const int descriptor = mkstemp(marker);
        assert(descriptor >= 0);
        close(descriptor);
        auto launch = config(argv[1], argv[2], "processing-stall");
        launch.frameTimeout = 1000ms;
        launch.arguments.push_back(marker);
        auto worker = ProviderWorker::create(launch, error);
        assert(worker);
        std::array<float, 480> input{}, output{};
        assert(worker->exchange(input.data(), output.data(), 480));
        const auto enteredDeadline = std::chrono::steady_clock::now() + 2s;
        struct stat info{};
        while (stat(marker, &info) == 0 && info.st_size == 0 &&
               std::chrono::steady_clock::now() < enteredDeadline)
            std::this_thread::sleep_for(1ms);
        assert(info.st_size > 0); // Child confirms entry instead of a timing guess.
        const auto start = std::chrono::steady_clock::now();
        assert(!worker->stop());
        assert(std::chrono::steady_clock::now() - start < 2s);
        assert(!worker->error().empty());
        unlink(marker);
    }
    {
        std::string error;
        auto worker = ProviderWorker::create(config(argv[1], argv[2], "close-stall"), error);
        assert(worker && !worker->stop() && !worker->stop());
        assert(!worker->error().empty());
    }
    {
        std::string error;
        assert(!ProviderWorker::create(config(argv[1], argv[2], "wrong-ready"), error));
        assert(!error.empty());
    }
    std::cout << "callback-to-worker broker tests passed\n";
}
