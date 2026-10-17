#include "aec_abi.hpp"
#include <algorithm>
#include <array>
#include <bit>
#include <cerrno>
#include <numbers>
#include <chrono>
#include <cstring>
#include <dlfcn.h>
#include <fcntl.h>
#include <iostream>
#include <memory>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

namespace {
constexpr unsigned frames = 300;
constexpr std::size_t samples = frames * 320;
void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}
struct Library {
    void* handle;
    explicit Library(const char* path) : handle(dlopen(path, RTLD_NOW | RTLD_LOCAL)) {
        if (!handle) throw std::runtime_error(dlerror());
    }
    ~Library() { if (handle) dlclose(handle); }
};
// Own continuous-time multitone, evaluated separately at each rate.
float referenceSample(double seconds) {
    return static_cast<float>(0.08 * std::sin(2 * std::numbers::pi * 233 * seconds) +
                              0.06 * std::sin(2 * std::numbers::pi * 617 * seconds) +
                              0.04 * std::sin(2 * std::numbers::pi * 1229 * seconds));
}
struct Signals {
    std::vector<float> forward = std::vector<float>(samples);
    std::vector<float> reference = std::vector<float>(frames * 480 * 2);
    Signals() {
        for (std::size_t i = 0; i < forward.size(); ++i) {
            const double time = static_cast<double>(i) / 32000;
            forward[i] = time >= 0.05 ? 0.6f * referenceSample(time - 0.05) : 0;
        }
        for (std::size_t i = 0; i < reference.size() / 2; ++i) {
            const float value = referenceSample(static_cast<double>(i) / 48000);
            reference[2 * i] = value; reference[2 * i + 1] = value;
        }
    }
};
std::vector<float> run(aec_probe::Factory factory, const Signals& signals, bool referenceOn) {
    std::vector<float> result(samples);
    std::unique_ptr<aec_probe::View> engine(factory());
    require(engine != nullptr, "null AEC factory result");
    // Factory already initializes the object. No initialize or delay setter call.
    const aec_probe::StreamConfig forward{32000, 0, 1, 320}, reverse{48000, 0, 2, 480};
    const std::array<float, 960> silence{};
    for (unsigned frame = 0; frame < frames; ++frame) {
        const auto mic = std::span(signals.forward).subspan(frame * 320, 320);
        const auto speaker = referenceOn ? std::span(signals.reference).subspan(frame * 960, 960)
                                        : std::span<const float>(silence);
        auto output = std::span(result).subspan(frame * 320, 320);
        // Reference-first is an explicit experiment policy, not desktop parity.
        require(aec_probe::reverse(*engine, reverse, speaker) == 0, "AEC reverse status");
        require(aec_probe::process(*engine, forward, mic, output) == 0, "AEC forward status");
        require(aec_probe::valid(forward, output), "AEC nonfinite output");
    }
    return result; // engine destroyed inside loaded-library scope before publication
}
double rms(std::span<const float> data) {
    double sum = 0;
    for (float value : data) sum += static_cast<double>(value) * value;
    return std::sqrt(sum / data.size());
}
struct Output {
    const char* path;
    int fd = -1;
    bool owned = false;
    bool published = false;
    struct stat identity{};
    explicit Output(const char* destination) : path(destination) {}
    bool matches() const noexcept {
        struct stat current{};
        return ::lstat(path, &current) == 0 && S_ISREG(current.st_mode) &&
               current.st_dev == identity.st_dev && current.st_ino == identity.st_ino;
    }
    ~Output() {
        if (fd >= 0) ::close(fd);
        if (owned && !published && matches()) ::unlink(path);
    }
    void write(const std::vector<float>& data) {
        fd = ::open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
        require(fd >= 0, "exclusive output creation failed");
        require(::fstat(fd, &identity) == 0 && S_ISREG(identity.st_mode), "output identity failed");
        owned = true;
        require(::fchmod(fd, 0600) == 0, "output mode failed");
        // Only little-endian ARM64 is admitted by the build/static checks.
        const auto* bytes = reinterpret_cast<const char*>(data.data());
        std::size_t remaining = data.size() * sizeof(float);
        while (remaining) {
            const auto count = ::write(fd, bytes, remaining);
            if (count < 0 && errno == EINTR) continue;
            require(count > 0, "output write failed");
            remaining -= static_cast<std::size_t>(count); bytes += count;
        }
        require(::fsync(fd) == 0, "output sync failed");
        const int descriptor = fd; fd = -1;
        require(::close(descriptor) == 0, "output close failed");
    }
};
}
int main(int argc, char** argv) {
    try {
        require(argc == 6, "usage: aec-direct-probe library forward-input.f32le reference-input.f32le reference-on.f32le reference-zero.f32le");
        for (int i = 2; i < argc; ++i)
            for (int j = i + 1; j < argc; ++j)
                require(std::strcmp(argv[i], argv[j]) != 0, "output destinations must differ");
        static_assert(sizeof(float) == 4 && std::endian::native == std::endian::little);
        const auto started = std::chrono::steady_clock::now();
        const Signals signals;
        std::vector<float> on, zero;
        {
            Library library(argv[1]);
            std::string failure;
            try {
                auto factory = reinterpret_cast<aec_probe::Factory>(dlsym(library.handle, "_ZN9krips_aec3AEC6createEv"));
                require(factory != nullptr, "AEC factory export missing");
                on = run(factory, signals, true);
                zero = run(factory, signals, false);
            } catch (const std::exception& error) { failure = error.what(); }
              catch (...) { failure = "unknown foreign AEC exception"; }
            // Foreign exception objects are dead and both engines are destroyed here.
            const int closed = dlclose(library.handle); library.handle = nullptr;
            require(failure.empty(), failure.c_str());
            require(closed == 0, "AEC library close failed");
        }
        Output forwardFile(argv[2]), referenceFile(argv[3]), onFile(argv[4]), zeroFile(argv[5]);
        forwardFile.write(signals.forward); referenceFile.write(signals.reference);
        onFile.write(on); zeroFile.write(zero);
        require(forwardFile.matches() && referenceFile.matches() && onFile.matches() && zeroFile.matches(),
                "output path identity changed");
        forwardFile.published = true; referenceFile.published = true;
        onFile.published = true; zeroFile.published = true;
        const auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::steady_clock::now() - started).count();
        std::cout << "{\"framesPerEngine\":" << frames << ",\"samplesPerOutput\":" << samples
                  << ",\"forwardRate\":32000,\"forwardChannels\":1,\"referenceRate\":48000,\"referenceChannels\":2"
                  << ",\"referenceOnRms\":" << rms(on) << ",\"referenceZeroRms\":" << rms(zero)
                  << ",\"inputRms\":" << rms(signals.forward)
                  << ",\"referenceRms\":" << rms(signals.reference)
                  << ",\"lateInputRms\":" << rms(std::span(signals.forward).last(32000))
                  << ",\"lateReferenceOnRms\":" << rms(std::span(on).last(32000))
                  << ",\"lateReferenceZeroRms\":" << rms(std::span(zero).last(32000))
                  << ",\"successfulCallsPerEngine\":600,\"delaySetterCalled\":false"
                  << ",\"elapsedMs\":" << elapsed << ",\"teardownComplete\":true}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
