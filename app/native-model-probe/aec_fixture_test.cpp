#include "aec_abi.hpp"
#include <array>
#include <dlfcn.h>
#include <iostream>
#include <limits>
#include <memory>
#include <string>
namespace {
void require(bool value, const char* message) { if (!value) throw std::runtime_error(message); }
struct Library {
    void* handle;
    explicit Library(const char* path) : handle(dlopen(path, RTLD_NOW | RTLD_LOCAL)) {
        if (!handle) throw std::runtime_error(dlerror());
    }
    ~Library() { if (handle) dlclose(handle); }
    template<class T> T symbol(const char* name) {
        auto result = reinterpret_cast<T>(dlsym(handle, name));
        require(result != nullptr, "fixture export missing");
        return result;
    }
};
}
int main(int argc, char** argv) {
    try {
        require(argc == 2, "provide own synthetic library");
        Library library(argv[1]); // Outlives engine owners AND caught exceptions.
        std::string failure;
        try {
            auto create = library.symbol<aec_probe::Factory>("synthetic_aec_create");
            auto count = library.symbol<unsigned (*)(unsigned)>("synthetic_aec_count");
            auto fail = library.symbol<void (*)(bool)>("synthetic_aec_fail");
            fail(true);
            bool caught = false;
            try { std::unique_ptr<aec_probe::View> unexpected(create()); }
            catch (const std::exception& error) {
                caught = std::string(error.what()) == "synthetic AEC initialization failure";
                require(count(4) == 0, "exception alive during catch");
            }
            require(caught && count(4) == 1, "foreign exception destroyed before unload");
            fail(false);
            {
                std::unique_ptr<aec_probe::View> engine(create());
                require(engine && count(0) == 1 && engine->initialize() == 0, "factory/initialize slots");
                require(engine->delay(17) == 73, "delay slot");
                aec_probe::StreamConfig forward{32000, 0, 1, 320}, reference{48000, 0, 2, 480};
                std::array<float, 320> mic{};
                std::array<float, 960> speaker{};
                speaker[0] = 0.125f; speaker[1] = 0.375f;
                mic.fill(0.75f);
                for (unsigned frame = 0; frame < 100; ++frame) {
                    require(aec_probe::reverse(*engine, reference, speaker) == 0, "reference status");
                    mic.fill(0.75f);
                    require(aec_probe::process(*engine, forward, mic, mic) == 0, "forward status");
                    for (float sample : mic) require(sample == 0.5f, "interleaved/in-place output");
                }
                auto reject = [&](auto operation) {
                    bool rejected = false;
                    try { operation(); } catch (const std::invalid_argument&) { rejected = true; }
                    require(rejected, "invalid frame admitted");
                    require(count(2) == 100 && count(3) == 100, "invalid frame entered foreign code");
                };
                reject([&] { aec_probe::reverse(*engine, reference, std::span(speaker).first(959)); });
                auto invalid = forward; invalid.frames = UINT64_MAX;
                reject([&] { aec_probe::process(*engine, invalid, mic, mic); });
                invalid = forward; invalid.channels = UINT64_MAX;
                reject([&] { aec_probe::process(*engine, invalid, mic, mic); });
                invalid = forward; invalid.rate = 44100;
                reject([&] { aec_probe::process(*engine, invalid, mic, mic); });
                invalid = forward; invalid.reserved = 1;
                reject([&] { aec_probe::process(*engine, invalid, mic, mic); });
                reject([&] { aec_probe::process(*engine, forward, mic, std::span(mic).first(319)); });
                mic[319] = std::numeric_limits<float>::quiet_NaN();
                reject([&] { aec_probe::process(*engine, forward, mic, mic); });
                speaker[959] = std::numeric_limits<float>::infinity();
                reject([&] { aec_probe::reverse(*engine, reference, speaker); });
            }
            require(count(1) == 1, "matching virtual deletion before unload");
            auto throwCall = library.symbol<void (*)(unsigned)>("synthetic_aec_throw");
            for (unsigned stage : {1u, 2u}) {
                bool callCaught = false;
                throwCall(stage);
                try {
                    std::unique_ptr<aec_probe::View> engine(create());
                    aec_probe::StreamConfig forward{32000, 0, 1, 320}, reference{48000, 0, 2, 480};
                    std::array<float, 320> mic{};
                    std::array<float, 960> speaker{};
                    aec_probe::reverse(*engine, reference, speaker);
                    aec_probe::process(*engine, forward, mic, mic);
                } catch (const std::exception& error) {
                    callCaught = std::string(error.what()) == "synthetic AEC initialization failure";
                    require(count(1) == stage + 1, "engine deleted during foreign exception unwind");
                    require(count(4) == stage, "call exception remains alive in catch");
                }
                require(callCaught && count(4) == stage + 1, "call exception destroyed before unload");
            }
        } catch (const std::exception& error) {
            failure = error.what(); // Copy while foreign type/code is still loaded.
        } catch (...) {
            failure = "unknown foreign exception";
        } // All caught foreign exceptions die before dlclose, including unexpected paths.
        require(dlclose(library.handle) == 0, "fixture unload");
        library.handle = nullptr;
        require(failure.empty(), failure.c_str());
        std::cout << "AEC synthetic foreign ABI passed: 100 duplex frames, deletion and exception lifetime\n";
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
