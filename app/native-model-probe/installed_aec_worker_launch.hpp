#pragma once
#include "aec_worker_broker.hpp"
#include <CommonCrypto/CommonDigest.h>
#include <cerrno>
#include <fcntl.h>
#include <stdexcept>
#include <sys/stat.h>
#include <unistd.h>

namespace krisp_probe {
inline constexpr const char* installedAECLibrarySHA256 = "bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a";
struct InstalledAECWorkerSettings {
    std::string workerPath, workerSha256, libraryPath;
};
namespace installed_aec_worker_detail {
inline void path(const std::string& value) {
    if (value.empty() || value.front() != '/' || value.find('\0') != std::string::npos)
        throw std::invalid_argument("Expected absolute path without NUL");
}
inline void digest(const std::string& value) {
    if (value.size() != 64 || value.find_first_not_of("0123456789abcdef") != std::string::npos)
        throw std::invalid_argument("Expected lowercase SHA256");
}
inline bool same(const struct stat& a, const struct stat& b) {
    return S_ISREG(b.st_mode) && a.st_dev == b.st_dev && a.st_ino == b.st_ino &&
        a.st_size == b.st_size && a.st_mode == b.st_mode &&
        a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
        a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec;
}
// Reads only the explicitly supplied own worker executable, never the vendor
// library. This samples identity/content; it does not bind later path-based spawn
// to this open descriptor. Replacement after return remains a TOCTOU limit.
inline std::string hashWorker(const std::string& value) {
    path(value);
    const int fd = ::open(value.c_str(), O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK);
    if (fd < 0) throw std::runtime_error("AEC worker open failed");
    struct Close { int fd; ~Close() { ::close(fd); } } close{fd};
    struct stat initial{}, final{}, named{};
    if (::fstat(fd, &initial) || !S_ISREG(initial.st_mode) || !(initial.st_mode & 0111) ||
        initial.st_size <= 0 || initial.st_size > 64 * 1024 * 1024)
        throw std::runtime_error("AEC worker size/type/mode rejected");
    CC_SHA256_CTX context;
    if (CC_SHA256_Init(&context) != 1) throw std::runtime_error("AEC worker hash initialize failed");
    std::array<unsigned char, 16384> bytes{};
    off_t remaining = initial.st_size;
    while (remaining) {
        const auto count = ::read(fd, bytes.data(), std::min<off_t>(remaining, bytes.size()));
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0 || CC_SHA256_Update(&context, bytes.data(), static_cast<CC_LONG>(count)) != 1)
            throw std::runtime_error("AEC worker hash read failed");
        remaining -= count;
    }
    if (::fstat(fd, &final) || ::lstat(value.c_str(), &named) || !same(initial, final) || !same(initial, named))
        throw std::runtime_error("AEC worker changed while hashing");
    std::array<unsigned char, CC_SHA256_DIGEST_LENGTH> bytesDigest{};
    if (CC_SHA256_Final(bytesDigest.data(), &context) != 1) throw std::runtime_error("AEC worker hash finalize failed");
    constexpr char hex[] = "0123456789abcdef";
    std::string result;
    for (auto byte : bytesDigest) { result += hex[byte >> 4]; result += hex[byte & 15]; }
    return result;
}
inline std::string tokenHex(const aec_wire::Token& token) {
    constexpr char hex[] = "0123456789abcdef";
    std::string result;
    for (auto byte : token) { result += hex[byte >> 4]; result += hex[byte & 15]; }
    return result;
}
}
// Call on the owner thread immediately before broker construction/start. The
// worker separately admits the fixed library inside the network-denied sandbox.
// No environment is inherited. The readiness line reports its checked library
// digest and stream dimensions; the binary protocol checks the session token.
inline AECWorkerLaunchConfig buildInstalledAECWorkerLaunch(const InstalledAECWorkerSettings& settings,
                                                            aec_wire::Token token) {
    using namespace installed_aec_worker_detail;
    path(settings.workerPath); path(settings.libraryPath); digest(settings.workerSha256);
    if (hashWorker(settings.workerPath) != settings.workerSha256)
        throw std::runtime_error("AEC worker executable SHA256 mismatch");
    AECWorkerLaunchConfig result;
    result.executable = "/usr/bin/sandbox-exec";
    result.arguments = {"-p", "(version 1) (allow default) (deny network*)", settings.workerPath,
                        settings.libraryPath, installedAECLibrarySHA256, tokenHex(token), std::to_string(getpid())};
    result.environment = {"PATH=/usr/bin:/bin"};
    result.expectedReadyLine = std::string("OKAEC1 ") + installedAECLibrarySHA256 + " 48000 1 48000 2\n";
    result.token = token;
    result.startupTimeout = std::chrono::milliseconds(30000);
    result.frameTimeout = std::chrono::milliseconds(500);
    result.shutdownTimeout = std::chrono::milliseconds(1000);
    return result;
}
}
