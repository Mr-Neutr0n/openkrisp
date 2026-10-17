#include "installed_worker_launch.hpp"
#include "provider_worker.hpp"
#include <algorithm>
#include <cstdlib>
#include <thread>
#include <charconv>
#include <vector>
#include <array>
#include <cerrno>
#include <chrono>
#include <fcntl.h>
#include <iostream>
#include <stdexcept>
#include <sys/stat.h>
#include <unistd.h>

namespace {
constexpr std::size_t sampleCount = 48000, byteCount = sampleCount * 4;
struct FD {
    int value = -1;
    explicit FD(int fd) : value(fd) { if (fd < 0) throw std::runtime_error("File open failed"); }
    ~FD() { if (value >= 0) ::close(value); }
    FD(const FD&) = delete;
};
void readAll(int fd, std::array<std::uint8_t, byteCount>& bytes) {
    std::size_t offset = 0;
    while (offset < bytes.size()) {
        const auto count = ::read(fd, bytes.data() + offset, bytes.size() - offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) throw std::runtime_error("Input read failed or truncated");
        offset += static_cast<std::size_t>(count);
    }
    std::uint8_t extra;
    ssize_t count;
    do { count = ::read(fd, &extra, 1); } while (count < 0 && errno == EINTR);
    if (count != 0) throw std::runtime_error("Input length changed");
}
bool same(const struct stat& a, const struct stat& b) {
    return a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_size == b.st_size &&
        a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
        a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec;
}
void publish(const char* path, const std::array<std::uint8_t, byteCount>& bytes) {
    FD output(::open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600));
    struct stat owned{};
    if (fstat(output.value, &owned)) throw std::runtime_error("Output identity unavailable");
    try {
        if (fchmod(output.value, 0600)) throw std::runtime_error("Output permissions failed");
        std::size_t offset = 0;
        while (offset < bytes.size()) {
            const auto count = ::write(output.value, bytes.data() + offset, bytes.size() - offset);
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) throw std::runtime_error("Output write failed");
            offset += static_cast<std::size_t>(count);
        }
        if (fsync(output.value)) throw std::runtime_error("Output sync failed");
        struct stat actual{};
        if (lstat(path, &actual) || actual.st_dev != owned.st_dev || actual.st_ino != owned.st_ino ||
            actual.st_size != static_cast<off_t>(byteCount)) throw std::runtime_error("Output identity changed");
        const int descriptor = output.value; output.value = -1;
        if (::close(descriptor)) throw std::runtime_error("Output close failed");
    } catch (...) {
        struct stat actual{};
        if (lstat(path, &actual) == 0 && actual.st_dev == owned.st_dev && actual.st_ino == owned.st_ino)
            unlink(path);
        throw;
    }
}
}
int main(int argc, char** argv) {
    std::int64_t callbackMaxUs=0,schedulingMaxLatenessUs=0;
    std::uint64_t observedProcessedFrames=0;
    unsigned deadlineFailures=0;
    std::size_t bufferDelay=0, paddedFrames=0, maximumCallbackFrames=0;
    // Preserve the original probe default: 480-sample callbacks and 120 ms delay.
    krisp_probe::ProviderBufferingConfig buffering{480,10};
    try {
        if (argc < 11)
            throw std::invalid_argument("Expected node worker addon model adapter library nodeSha adapterSha input output [--bypass] [--maximum-callback-frames N] [--scheduling-budget-frames N]");
        bool bypass=false, haveMaximum=false, haveBudget=false;
        for (int i=11;i<argc;++i) {
            const std::string option=argv[i];
            if (option=="--bypass" && !bypass) { bypass=true; continue; }
            std::size_t* destination=nullptr;
            if (option=="--maximum-callback-frames" && !haveMaximum) {
                haveMaximum=true; destination=&buffering.maximumCallbackFrames;
            } else if (option=="--scheduling-budget-frames" && !haveBudget) {
                haveBudget=true; destination=&buffering.schedulingBudgetFrames;
            }
            if (!destination || ++i==argc) throw std::invalid_argument("Invalid, repeated or incomplete timed probe option");
            const std::string value=argv[i];
            const auto parsed=std::from_chars(value.data(),value.data()+value.size(),*destination);
            if (value.empty() || parsed.ec!=std::errc{} || parsed.ptr!=value.data()+value.size())
                throw std::invalid_argument("Buffering options require unsigned integers");
        }
        // Validate configuration before any child or original artifact is loaded.
        const krisp_probe::ProviderTransport<> validated(buffering);
        bufferDelay=validated.actualDelaySamples();
        maximumCallbackFrames=validated.maximumCallbackFrames();
        paddedFrames=bufferDelay/480;
        // Validate the complete synthetic input before constructing any child.
        FD input(::open(argv[9], O_RDONLY | O_NOFOLLOW | O_CLOEXEC));
        struct stat before{}, after{};
        if (fstat(input.value, &before) || !S_ISREG(before.st_mode) || before.st_size != static_cast<off_t>(byteCount))
            throw std::runtime_error("Input must be exactly 48000 Float32 samples in a regular file");
        std::array<std::uint8_t, byteCount> inputBytes{}, outputBytes{};
        readAll(input.value, inputBytes);
        if (fstat(input.value, &after) || !same(before, after)) throw std::runtime_error("Input identity changed during read");
        for (std::size_t i = 0; i < sampleCount; ++i)
            if (!std::isfinite(std::bit_cast<float>(static_cast<std::uint32_t>(krisp_probe::wire::read(inputBytes.data()+i*4,4)))))
                throw std::runtime_error("Input contains nonfinite samples");
        struct stat destination{};
        if (lstat(argv[10], &destination) == 0 || errno != ENOENT) throw std::runtime_error("Output must not exist");
        krisp_probe::InstalledWorkerSettings settings;
        settings.nodePath=argv[1]; settings.workerPath=argv[2]; settings.addonPath=argv[3];
        settings.modelPath=argv[4]; settings.adapterPath=argv[5]; settings.libraryPath=argv[6];
        settings.nodeSha256=argv[7]; settings.adapterSha256=argv[8]; settings.bypass=bypass;
        krisp_probe::wire::Token token{};
        arc4random_buf(token.data(),token.size());
        std::string startupError;
        auto worker=krisp_probe::ProviderWorker::create(krisp_probe::buildInstalledWorkerLaunch(settings,token),startupError,buffering);
        if(!worker)throw std::runtime_error(startupError);
        using Clock=std::chrono::steady_clock;
        const std::size_t totalSamples=sampleCount+bufferDelay, totalFrames=totalSamples/480;
        std::vector<float> collected(totalSamples);
        std::vector<float> frame(maximumCallbackFrames);
        const auto begin=Clock::now();
        // Paced CPU simulation only. All allocations and waits stay outside
        // exchange. This is not a CoreAudio callback or a realtime guarantee.
        for(std::size_t position=0;position<totalSamples;) {
            const auto count=std::min(maximumCallbackFrames,totalSamples-position);
            for(std::size_t i=0;i<count;++i)
                frame[i]=position+i<sampleCount ? std::bit_cast<float>(static_cast<std::uint32_t>(krisp_probe::wire::read(inputBytes.data()+(position+i)*4,4))) : 0;
            const auto scheduled=begin+std::chrono::nanoseconds(position*1000000000ULL/48000);
            std::this_thread::sleep_until(scheduled);
            const auto entered=Clock::now();
            schedulingMaxLatenessUs=std::max(schedulingMaxLatenessUs,static_cast<std::int64_t>(std::chrono::duration_cast<std::chrono::microseconds>(entered-scheduled).count()));
            const bool accepted=worker->exchange(frame.data(),collected.data()+position,count);
            const auto returned=Clock::now();
            callbackMaxUs=std::max(callbackMaxUs,static_cast<std::int64_t>(std::chrono::duration_cast<std::chrono::microseconds>(returned-entered).count()));
            observedProcessedFrames=worker->processedFrames();
            if(!accepted) {
                if(worker->fault()==krisp_probe::ProviderTransport<>::Fault::deadline)++deadlineFailures;
                throw std::runtime_error("Paced callback exchange failed, transport fault "+std::to_string(static_cast<unsigned>(worker->fault())));
            }
            position+=count;
        }
        // Padding requests must also finish before shutdown and publication.
        const auto drainDeadline=Clock::now()+std::chrono::seconds(2);
        while(worker->processedFrames()<totalFrames && worker->healthy() && Clock::now()<drainDeadline)
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        observedProcessedFrames=worker->processedFrames();
        if(worker->processedFrames()!=totalFrames || !worker->healthy())
            throw std::runtime_error("Paced worker drain did not complete all requests");
        for(std::size_t i=0;i<collected.size();++i) {
            if(!std::isfinite(collected[i]))throw std::runtime_error("Collected output is nonfinite");
            if(i<bufferDelay && collected[i]!=0)throw std::runtime_error("Initial transport delay was not silent");
        }
        for(std::size_t i=0;i<sampleCount;++i)
            krisp_probe::wire::write(outputBytes.data()+i*4,std::bit_cast<std::uint32_t>(collected[i+bufferDelay]),4);
        const auto processedFrames=worker->processedFrames();
        if(!worker->stop())throw std::runtime_error("Worker teardown failed: "+worker->error());
        publish(argv[10],outputBytes);
        std::cout<<"{\"status\":\"completed\",\"observation\":\"paced-cpu-simulation\",\"callbackMaxUs\":"<<callbackMaxUs
                 <<",\"schedulingMaxLatenessUs\":"<<schedulingMaxLatenessUs<<",\"processedFrames\":"<<processedFrames
                 <<",\"inputFrames\":100,\"paddedFrames\":"<<paddedFrames<<",\"bufferDelaySamples\":"<<bufferDelay<<",\"maximumCallbackFrames\":"<<maximumCallbackFrames<<",\"deadlineFailureCount\":"<<deadlineFailures
                 <<",\"samples\":48000,\"teardownComplete\":true}\n";
        // Padding removes only the known transport delay. No model tail claim.
        return 0;
    } catch (const std::exception& error) {
        std::cout<<"{\"status\":\"failed\",\"observation\":\"paced-cpu-simulation\",\"callbackMaxUs\":"<<callbackMaxUs
                 <<",\"schedulingMaxLatenessUs\":"<<schedulingMaxLatenessUs<<",\"processedFrames\":"<<observedProcessedFrames
                 <<",\"inputFrames\":100,\"paddedFrames\":"<<paddedFrames<<",\"bufferDelaySamples\":"<<bufferDelay<<",\"maximumCallbackFrames\":"<<maximumCallbackFrames<<",\"deadlineFailureCount\":"<<deadlineFailures<<"}\n";
        std::cerr << "Timed worker probe failed: " << error.what() << '\n';
        return 1;
    }
}
