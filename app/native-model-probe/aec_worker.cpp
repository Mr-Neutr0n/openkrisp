#include "aec_abi.hpp"
#include "aec_worker_protocol.hpp"
#include "parent_watch.hpp"
#include <CommonCrypto/CommonDigest.h>
#include <array>
#include <cerrno>
#include <charconv>
#include <cstring>
#include <dlfcn.h>
#include <fcntl.h>
#include <iostream>
#include <memory>
#include <netinet/in.h>
#include <string>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

namespace {
void require(bool valid, const char* message) { if (!valid) throw std::runtime_error(message); }
struct Descriptor {
    int value;
    explicit Descriptor(int fd) : value(fd) {}
    ~Descriptor() { if (value >= 0) ::close(value); }
};
bool same(const struct stat& a, const struct stat& b) {
    return S_ISREG(b.st_mode) && a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_size == b.st_size &&
        a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
        a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec;
}
std::string hash(const char* path) {
    require(path[0] == '/', "library path must be absolute");
    Descriptor fd(::open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK));
    require(fd.value >= 0, "library open failed");
    struct stat initial{}, final{}, named{};
    require(::fstat(fd.value, &initial) == 0 && S_ISREG(initial.st_mode) &&
            initial.st_size > 0 && initial.st_size <= 64 * 1024 * 1024, "library size/type rejected");
    CC_SHA256_CTX context; require(CC_SHA256_Init(&context) == 1, "hash initialize failed");
    std::array<unsigned char, 16384> buffer{};
    off_t remaining = initial.st_size;
    while (remaining) {
        const auto count = ::read(fd.value, buffer.data(), std::min<off_t>(remaining, buffer.size()));
        if (count < 0 && errno == EINTR) continue;
        require(count > 0, "library read failed");
        require(CC_SHA256_Update(&context, buffer.data(), static_cast<CC_LONG>(count)) == 1, "hash update failed");
        remaining -= count;
    }
    require(::fstat(fd.value, &final) == 0 && ::lstat(path, &named) == 0 &&
            same(initial, final) && same(initial, named), "library changed while hashing");
    std::array<unsigned char, CC_SHA256_DIGEST_LENGTH> digest{};
    require(CC_SHA256_Final(digest.data(), &context) == 1, "hash finalize failed");
    constexpr char hex[] = "0123456789abcdef";
    std::string result;
    for (unsigned char byte : digest) { result += hex[byte >> 4]; result += hex[byte & 15]; }
    return result;
}
void networkGate() {
    Descriptor fd(::socket(AF_INET, SOCK_STREAM, 0));
    require(fd.value >= 0, "network gate socket failed");
    sockaddr_in address{};
    address.sin_family = AF_INET; address.sin_port = htons(9); address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    errno = 0;
    const int result = ::connect(fd.value, reinterpret_cast<sockaddr*>(&address), sizeof(address));
    require(result == -1 && errno == EPERM, "network denial EPERM required");
}
void writeAll(std::span<const std::uint8_t> bytes) {
    while (!bytes.empty()) {
        const auto count = ::write(3, bytes.data(), bytes.size());
        if (count < 0 && errno == EINTR) continue;
        require(count > 0, "worker response write failed");
        bytes = bytes.subspan(static_cast<std::size_t>(count));
    }
}
struct Library {
    void* handle = nullptr;
    explicit Library(const char* path) : handle(::dlopen(path, RTLD_NOW | RTLD_LOCAL)) {
        if (!handle) throw std::runtime_error(::dlerror());
    }
    ~Library() { if (handle) ::dlclose(handle); }
    void close() { void* value = handle; handle = nullptr; require(::dlclose(value) == 0, "library close failed"); }
};
}
namespace {
using namespace krisp_probe::aec_wire;
void session(Library& library, const Token& token, const std::string& digest) {
    auto factory = reinterpret_cast<aec_probe::Factory>(::dlsym(library.handle, "_ZN9krips_aec3AEC6createEv"));
    require(factory != nullptr, "AEC factory export missing");
    std::unique_ptr<aec_probe::View> engine(factory());
    require(engine != nullptr, "null AEC factory result");
    const std::string ready = "OKAEC1 " + digest + " 48000 1 48000 2\n";
    writeAll({reinterpret_cast<const std::uint8_t*>(ready.data()), ready.size()});
    Parser parser(token, mask(Kind::request) | mask(Kind::close));
    Storage encoded;
    bool closed = false, haveEpoch = false;
    std::uint64_t epoch = 0;
    Timing previousMic{}, previousReference{};
    const aec_probe::StreamConfig forward{48000, 0, 1, 480}, reverse{48000, 0, 2, 480};
    std::array<std::uint8_t, 8192> input{};
    while (true) {
        const auto count = ::read(0, input.data(), input.size());
        if (count < 0 && errno == EINTR) continue;
        require(count >= 0, "worker request read failed");
        if (count == 0) {
            require(parser.finish() && closed, "explicit close and clean request EOF required");
            break;
        }
        require(parser.push(std::span(input).first(static_cast<std::size_t>(count)), [&](const Frame& request) {
            if (request.kind == Kind::close) {
                engine.reset();
                library.close();
                Frame ack; ack.kind = Kind::close; ack.sequence = request.sequence; ack.epoch = request.epoch;
                const auto length = encode(ack, token, encoded);
                require(length != 0, "close encode failed");
                writeAll(std::span(encoded).first(length));
                closed = true;
                return true;
            }
            require(!haveEpoch || epoch == request.epoch, "epoch change requires worker restart");
            if (haveEpoch) {
                const auto continuous = [](const Timing& a, const Timing& b) {
                    return a.flags == b.flags && (!(a.flags & 1) ||
                        (b.inputSampleOrigin == a.inputSampleOrigin + 480 && b.outputSampleOrigin == a.outputSampleOrigin + 480)) &&
                        (!(a.flags & 2) || b.hostTime > a.hostTime);
                };
                require(continuous(previousMic, request.microphoneTiming) &&
                        continuous(previousReference, request.referenceTiming), "AEC lane discontinuity");
            }
            epoch = request.epoch; haveEpoch = true;
            previousMic = request.microphoneTiming; previousReference = request.referenceTiming;
            Frame response; response.kind = Kind::result; response.sequence = request.sequence; response.epoch = request.epoch;
            response.microphoneTiming = request.microphoneTiming; response.referenceTiming = request.referenceTiming;
            require(aec_probe::reverse(*engine, reverse, request.reference) == 0, "AEC reverse status");
            require(aec_probe::process(*engine, forward, request.microphone, response.output) == 0, "AEC forward status");
            require(aec_probe::valid(forward, response.output), "AEC nonfinite output");
            const auto length = encode(response, token, encoded);
            require(length != 0, "result encode failed");
            writeAll(std::span(encoded).first(length));
            return true;
        }), "malformed request or AEC processing failure");
    }
}
}
int main(int argc, char** argv) {
    try {
        require(argc == 5, "usage: aec-worker absolute-library expected-sha256 token-hex parent-pid");
        const auto hex = [](char value) { return value >= '0' && value <= '9' ? value - '0' :
            value >= 'a' && value <= 'f' ? value - 'a' + 10 : -1; };
        require(std::strlen(argv[2]) == 64, "invalid library SHA256");
        for (char value : std::string(argv[2])) require(hex(value) >= 0, "invalid library SHA256");
        require(std::strlen(argv[3]) == 32, "invalid token");
        Token token{};
        for (std::size_t i = 0; i < token.size(); ++i) {
            const int high = hex(argv[3][2 * i]), low = hex(argv[3][2 * i + 1]);
            require(high >= 0 && low >= 0, "invalid token"); token[i] = static_cast<std::uint8_t>(high * 16 + low);
        }
        pid_t parent = 0;
        const auto parsed = std::from_chars(argv[4], argv[4] + std::strlen(argv[4]), parent);
        require(parsed.ec == std::errc{} && *parsed.ptr == '\0', "invalid parent PID");
        krisp_probe::ParentWatch watch(parent);
        networkGate();
        const auto digest = hash(argv[1]);
        require(digest == argv[2], "library SHA256 mismatch");
        {
            Library library(argv[1]);
            std::string failure;
            try { session(library, token, digest); }
            catch (const std::exception& error) { failure = error.what(); }
            catch (...) { failure = "unknown foreign AEC exception"; }
            if (library.handle) library.close();
            require(failure.empty(), failure.c_str());
        }
        watch.stop();
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
