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
constexpr std::uint32_t broadbandSeed = 0x91e10da5u;
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
// Separate deterministic 16 kHz sources, linearly interpolated to each rate.
std::vector<float> noise(std::uint32_t state) {
    std::vector<float> base(160001);
    for (float& sample : base) {
        state ^= state << 13; state ^= state >> 17; state ^= state << 5;
        sample = static_cast<float>(static_cast<int>(state & 65535u) - 32768) / 262144.0f;
    }
    return base;
}
float interpolate(const std::vector<float>& base, std::size_t index, unsigned ratio) {
    const auto lower = index / ratio;
    const float phase = static_cast<float>(index % ratio) / ratio;
    return base[lower] + (base[lower + 1] - base[lower]) * phase;
}
struct NearInput {
    int fd = -1;
    const char* path;
    struct stat identity{};
    std::vector<float> samples;
    explicit NearInput(const char* source) : path(source), samples(320000) {
        require(path[0] == '/', "near input must be an absolute path");
        fd = ::open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
        require(fd >= 0, "near input open failed");
        try {
            require(::fstat(fd, &identity) == 0 && S_ISREG(identity.st_mode) &&
                    identity.st_size == static_cast<off_t>(samples.size() * sizeof(float)),
                    "near input must be exactly 320000 Float32 values");
            char* bytes = reinterpret_cast<char*>(samples.data());
            std::size_t remaining = samples.size() * sizeof(float);
            while (remaining) {
                const auto count = ::read(fd, bytes, remaining);
                if (count < 0 && errno == EINTR) continue;
                require(count > 0, "near input read failed");
                remaining -= static_cast<std::size_t>(count); bytes += count;
            }
            for (std::size_t i = 0; i < samples.size(); ++i)
                require(std::isfinite(samples[i]) && (i >= 96000 || samples[i] == 0.0f),
                        "near input must be finite with first 96000 values zero");
            require(unchanged(), "near input changed during read");
        } catch (...) { ::close(fd); fd = -1; throw; }
    }
    bool unchanged() const noexcept {
        struct stat current{}, named{};
        if (::fstat(fd, &current) != 0 || ::lstat(path, &named) != 0) return false;
        const auto same = [&](const struct stat& value) {
            return S_ISREG(value.st_mode) && value.st_dev == identity.st_dev &&
                value.st_ino == identity.st_ino && value.st_size == identity.st_size &&
                value.st_mtimespec.tv_sec == identity.st_mtimespec.tv_sec &&
                value.st_mtimespec.tv_nsec == identity.st_mtimespec.tv_nsec &&
                value.st_ctimespec.tv_sec == identity.st_ctimespec.tv_sec &&
                value.st_ctimespec.tv_nsec == identity.st_ctimespec.tv_nsec;
        };
        return same(current) && same(named);
    }
    ~NearInput() { if (fd >= 0) ::close(fd); }
};
struct Signals {
    const unsigned frames = 1000;
    std::vector<float> forward, reference, echo, near;
    explicit Signals(const NearInput* input) : forward(320000), reference(960000), echo(320000), near(320000) {
        const auto farBase = noise(broadbandSeed), nearBase = noise(0x6a09e667u);
        for (std::size_t i = 0; i < forward.size(); ++i) {
            echo[i] = i >= 1600 ? 0.6f * interpolate(farBase, i - 1600, 2) : 0.0f;
            near[i] = input ? input->samples[i] :
                i >= 96000 ? 0.6f * interpolate(nearBase, i - 96000, 2) : 0.0f;
            require(std::isfinite(echo[i] + near[i]), "nonfinite input mixture");
            forward[i] = echo[i] + near[i];
        }
        for (std::size_t i = 0; i < reference.size() / 2; ++i)
            reference[2 * i] = reference[2 * i + 1] = interpolate(farBase, i, 3);
    }
};
std::vector<float> run(aec_probe::Factory factory, const Signals& signals, bool referenceOn, bool nearOnly = false, bool echoOnly = false) {
    std::vector<float> result(signals.forward.size());
    std::unique_ptr<aec_probe::View> engine(factory());
    require(engine != nullptr, "null AEC factory result");
    // Factory already initializes the object. No initialize or delay setter call.
    const aec_probe::StreamConfig forward{32000, 0, 1, 320}, reverse{48000, 0, 2, 480};
    const std::array<float, 960> silence{};
    for (unsigned frame = 0; frame < signals.frames; ++frame) {
        const auto mic = std::span(nearOnly ? signals.near : echoOnly ? signals.echo : signals.forward).subspan(frame * 320, 320);
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
struct Directory {
    const char* path;
    bool published = false;
    struct stat identity{};
    explicit Directory(const char* destination) : path(destination) {
        require(::mkdir(path, 0700) == 0, "exclusive output directory creation failed");
        const int fd = ::open(path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
        if (fd < 0) throw std::runtime_error("output directory open failed");
        const bool valid = ::fstat(fd, &identity) == 0 && S_ISDIR(identity.st_mode);
        const bool mode = valid && ::fchmod(fd, 0700) == 0;
        const int closed = ::close(fd);
        if (!mode || closed != 0) {
            if (matches()) ::rmdir(path);
            throw std::runtime_error("output directory identity/mode failed");
        }
    }
    bool matches() const noexcept {
        struct stat current{};
        return ::lstat(path, &current) == 0 && S_ISDIR(current.st_mode) &&
               current.st_dev == identity.st_dev && current.st_ino == identity.st_ino;
    }
    ~Directory() { if (!published && matches()) ::rmdir(path); }
};
int main(int argc, char** argv) {
    try {
        require(argc == 3 || (argc == 5 && std::strcmp(argv[3], "--near-input") == 0),
                "usage: aec-doubletalk-probe library new-private-output-directory [--near-input absolute-f32le-file]");
        static_assert(sizeof(float) == 4 && std::endian::native == std::endian::little);
        const auto nearInput = argc == 5 ? std::make_unique<NearInput>(argv[4]) : nullptr;
        const Signals signals(nearInput.get());
        std::vector<float> on, zero, near, echo;
        {
            Library library(argv[1]);
            std::string failure;
            try {
                auto factory = reinterpret_cast<aec_probe::Factory>(dlsym(library.handle, "_ZN9krips_aec3AEC6createEv"));
                require(factory != nullptr, "AEC factory export missing");
                on = run(factory, signals, true);
                zero = run(factory, signals, false);
                near = run(factory, signals, false, true);
                echo = run(factory, signals, false, false, true);
            } catch (const std::exception& error) { failure = error.what(); }
              catch (...) { failure = "unknown foreign AEC exception"; }
            const int closed = dlclose(library.handle); library.handle = nullptr;
            require(failure.empty(), failure.c_str());
            require(closed == 0, "AEC library close failed");
        }
        require(!nearInput || nearInput->unchanged(), "near input changed during processing");
        Directory directory(argv[2]);
        const std::array<const char*, 8> names{"reference-input.f32le", "echo-input.f32le",
            "near-input.f32le", "mixture-input.f32le", "mixture-reference-on.f32le",
            "mixture-reference-zero.f32le", "near-reference-zero.f32le", "echo-reference-zero.f32le"};
        const std::array<const std::vector<float>*, 8> samples{
            &signals.reference, &signals.echo, &signals.near, &signals.forward, &on, &zero, &near, &echo};
        std::array<std::string, 8> paths;
        std::array<std::unique_ptr<Output>, 8> files;
        for (std::size_t i = 0; i < names.size(); ++i) {
            paths[i] = std::string(argv[2]) + "/" + names[i];
            files[i] = std::make_unique<Output>(paths[i].c_str());
            files[i]->write(*samples[i]);
        }
        for (const auto& file : files) require(file->matches(), "output path identity changed");
        require(directory.matches(), "output directory identity changed");
        require(!nearInput || nearInput->unchanged(), "near input changed during publication");
        for (const auto& file : files) file->published = true;
        directory.published = true;
        std::cout << "{\"fixture\":\"" << (nearInput ? "doubletalk-external-near-v1" : "doubletalk-xorshift32-linear16k-v1") << "\","
                  << "\"nearSource\":\"" << (nearInput ? "external-f32le" : "generated-noise") << "\","
                  << "\"framesPerEngine\":1000,\"engines\":4,\"successfulCallsPerEngine\":2000,"
                  << "\"samplesPerOutput\":320000,\"referenceSamples\":960000,"
                  << "\"forwardRate\":32000,\"forwardChannels\":1,\"referenceRate\":48000,\"referenceChannels\":2,"
                  << "\"farSeed\":2447445413,\"nearSeed\":" << (nearInput ? "null" : "1779033703") << ","
                  << "\"echoGain\":0.6,\"nearGain\":" << (nearInput ? "1.0" : "0.6") << ",\"echoDelaySamples\":1600,"
                  << "\"nearStartSample\":96000,\"delaySetterCalled\":false,\"teardownComplete\":true}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
