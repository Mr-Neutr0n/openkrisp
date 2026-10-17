#include "installed_worker_launch.hpp"
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
    try {
        if ((argc != 11 && argc != 12) || (argc == 12 && std::string(argv[11]) != "--bypass"))
            throw std::invalid_argument("Expected node worker addon model adapter library nodeSha adapterSha input output [--bypass]");
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
        settings.nodeSha256=argv[7]; settings.adapterSha256=argv[8]; settings.bypass=argc==12;
        krisp_probe::wire::Token token{};
        for (unsigned i=0;i<token.size();++i) token[i]=static_cast<std::uint8_t>(0xa0+i);
        krisp_probe::WorkerBroker broker(krisp_probe::buildInstalledWorkerLaunch(settings,token));
        const auto start=std::chrono::steady_clock::now();
        if (!broker.start()) throw std::runtime_error(broker.error());
        const auto ready=std::chrono::steady_clock::now();
        std::array<float,480> frame{}, result{};
        for (unsigned batch=0;batch<100;++batch) {
            for (unsigned i=0;i<480;++i)
                frame[i]=std::bit_cast<float>(static_cast<std::uint32_t>(krisp_probe::wire::read(inputBytes.data()+(batch*480+i)*4,4)));
            if (!broker.process480(frame,result)) throw std::runtime_error(broker.error());
            for (unsigned i=0;i<480;++i)
                krisp_probe::wire::write(outputBytes.data()+(batch*480+i)*4,std::bit_cast<std::uint32_t>(result[i]),4);
        }
        const auto processed=std::chrono::steady_clock::now();
        if (!broker.close()) throw std::runtime_error(broker.error());
        publish(argv[10],outputBytes);
        std::cout << "{\"status\":\"completed\",\"frames\":100,\"samples\":48000,\"teardownComplete\":true,\"startupMs\":"
                  << std::chrono::duration_cast<std::chrono::milliseconds>(ready-start).count()
                  << ",\"processingMs\":" << std::chrono::duration_cast<std::chrono::milliseconds>(processed-ready).count() << "}\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "Installed worker probe failed: " << error.what() << '\n';
        return 1;
    }
}
