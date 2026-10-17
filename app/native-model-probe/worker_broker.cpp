#include "worker_broker.hpp"
#include <cerrno>
#include <csignal>
#include <fcntl.h>
#include <poll.h>
#include <spawn.h>
#include <sys/wait.h>
#include <thread>
#include <unistd.h>

namespace krisp_probe {
namespace {
void closeFD(int& fd) noexcept { if (fd >= 0) { ::close(fd); fd = -1; } }
bool validTime(std::chrono::milliseconds t) { return t.count() >= 1 && t.count() <= 30000; }
// Duplicate all spawn sources above target descriptors before making actions.
bool makePipe(int (&fds)[2]) {
    int raw[2]; if (::pipe(raw)) return false;
    fds[0] = fcntl(raw[0], F_DUPFD_CLOEXEC, 10);
    fds[1] = fcntl(raw[1], F_DUPFD_CLOEXEC, 10);
    ::close(raw[0]); ::close(raw[1]);
    if (fds[0] < 0 || fds[1] < 0) { closeFD(fds[0]); closeFD(fds[1]); return false; }
    return true;
}
bool nonblocking(int fd) {
    const int flags = fcntl(fd, F_GETFL);
    return flags >= 0 && fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0;
}
}
bool WorkerBroker::fail(const char* message) {
    if (error_.empty()) error_ = message;
    return false;
}
bool WorkerBroker::reap() noexcept {
    if (pid_ < 0 || reaped_) return reaped_;
    const auto result = waitpid(pid_, &status_, WNOHANG);
    if (result == pid_) reaped_ = true;
    else if (result < 0 && errno == ECHILD) { reaped_ = true; status_ = -1; }
    return reaped_;
}
void WorkerBroker::cleanup() noexcept {
    closeFD(request_); closeFD(response_);
    if (pid_ < 0 || reap()) return;
    kill(pid_, SIGTERM);
    // Cleanup has its own short upper bound, even after an invalid config.
    const auto until = Clock::now() + std::chrono::milliseconds(100);
    while (!reap() && Clock::now() < until) std::this_thread::sleep_for(std::chrono::milliseconds(1));
    if (!reaped_) kill(pid_, SIGKILL);
    const auto killedUntil = Clock::now() + std::chrono::milliseconds(1000);
    while (!reap() && Clock::now() < killedUntil) std::this_thread::sleep_for(std::chrono::milliseconds(1));
}
WorkerBroker::~WorkerBroker() { cleanup(); }
bool WorkerBroker::await(short events, int fd, Clock::time_point deadline) {
    for (;;) {
        const auto now = Clock::now();
        if (now >= deadline) return fail("Worker deadline exceeded");
        pollfd descriptor{fd, events, 0};
        const auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(deadline - now).count();
        const int result = poll(&descriptor, 1, static_cast<int>(std::max<std::int64_t>(1, remaining)));
        if (result < 0 && errno == EINTR) continue;
        if (result < 0) return fail("Worker poll failed");
        if (result == 0) return fail("Worker deadline exceeded");
        if (descriptor.revents & POLLNVAL) return fail("Worker descriptor invalid");
        if (descriptor.revents & (events | POLLHUP | POLLERR)) return true;
    }
}
bool WorkerBroker::writeBytes(std::span<const std::uint8_t> bytes, Clock::time_point deadline) {
    while (!bytes.empty()) {
        if (!await(POLLOUT, request_, deadline)) return false;
        const auto count = ::write(request_, bytes.data(), bytes.size());
        if (count < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (count <= 0) return fail("Worker request write failed");
        bytes = bytes.subspan(static_cast<std::size_t>(count));
    }
    return true;
}
bool WorkerBroker::noPending() {
    std::uint8_t byte;
    const auto count = ::read(response_, &byte, 1);
    if (count > 0) return fail("Unexpected worker output");
    if (count == 0) return fail("Worker response EOF");
    if (errno != EAGAIN && errno != EINTR) return fail("Worker response read failed");
    if (reap()) return fail("Worker exited before request");
    return true;
}
bool WorkerBroker::readFrame(wire::Kind kind, wire::Frame& frame, Clock::time_point deadline) {
    wire::Parser parser(config_.token, wire::mask(kind), sequence_);
    bool received = false;
    std::array<std::uint8_t, wire::maxFrameBytes + 1> bytes{};
    while (!received) {
        if (!await(POLLIN, response_, deadline)) return false;
        const auto count = ::read(response_, bytes.data(), bytes.size());
        if (count < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (count <= 0) return fail("Worker response EOF or read failure");
        if (!parser.push(std::span(bytes.data(), static_cast<std::size_t>(count)), [&](const wire::Frame& value) {
                if (received) return false;
                frame = value; received = true; return true;
            })) return fail("Malformed worker response");
    }
    if (parser.retainedBytes() || !parser.finish()) return fail("Trailing worker response");
    return true;
}
bool WorkerBroker::start() {
    if (started_ || terminal_ || pid_ >= 0) return fail("Worker start already attempted");
    terminal_ = true;
    if (config_.executable.empty() || config_.executable[0] != '/' ||
        config_.executable.find('\0') != std::string::npos ||
        config_.expectedReadyLine.empty() || config_.expectedReadyLine.size() > 512 ||
        config_.expectedReadyLine.back() != '\n' ||
        config_.expectedReadyLine.find('\n') != config_.expectedReadyLine.size() - 1 ||
        !validTime(config_.startupTimeout) || !validTime(config_.frameTimeout) || !validTime(config_.shutdownTimeout) ||
        config_.frameTimeout.count() > 5000 || config_.shutdownTimeout.count() > 5000)
        return fail("Invalid worker launch configuration");
    for (std::size_t i = 0; i + 1 < config_.expectedReadyLine.size(); ++i)
        if (static_cast<unsigned char>(config_.expectedReadyLine[i]) < 32 ||
            static_cast<unsigned char>(config_.expectedReadyLine[i]) > 126) return fail("Readiness must be ASCII");
    for (const auto& s : config_.arguments) if (s.find('\0') != std::string::npos) return fail("Invalid worker argument");
    for (const auto& s : config_.environment)
        if (s.find('\0') != std::string::npos || s.find('=') == std::string::npos || s.front() == '=') return fail("Invalid worker environment");
    int input[2]{-1,-1}, output[2]{-1,-1};
    if (!makePipe(input) || !makePipe(output)) {
        closeFD(input[0]); closeFD(input[1]); closeFD(output[0]); closeFD(output[1]);
        return fail("Worker pipe creation failed");
    }
    int nullFD = open("/dev/null", O_RDWR | O_CLOEXEC);
    if (nullFD >= 0) { const auto duplicate = fcntl(nullFD, F_DUPFD_CLOEXEC, 10); ::close(nullFD); nullFD = duplicate; }
    request_ = input[1]; response_ = output[0];
    bool prepared = nullFD >= 0 && nonblocking(request_) && nonblocking(response_);
#ifdef __APPLE__
    prepared = prepared && fcntl(request_, F_SETNOSIGPIPE, 1) == 0;
#else
#error WorkerBroker requires macOS F_SETNOSIGPIPE for per-descriptor SIGPIPE suppression.
#endif
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attributes;
    const bool actionsOK = posix_spawn_file_actions_init(&actions) == 0;
    const bool attributesOK = posix_spawnattr_init(&attributes) == 0;
    prepared = prepared && actionsOK && attributesOK;
    if (prepared) {
        prepared = posix_spawnattr_setflags(&attributes, POSIX_SPAWN_CLOEXEC_DEFAULT) == 0 &&
            posix_spawn_file_actions_adddup2(&actions, input[0], 0) == 0 &&
            posix_spawn_file_actions_adddup2(&actions, output[1], 3) == 0 &&
            posix_spawn_file_actions_adddup2(&actions, nullFD, 1) == 0 &&
            posix_spawn_file_actions_adddup2(&actions, nullFD, 2) == 0;
        for (int fd : {input[0],input[1],output[0],output[1],nullFD})
            prepared = prepared && posix_spawn_file_actions_addclose(&actions, fd) == 0;
    }
    std::vector<char*> argv{config_.executable.data()}, env;
    for (auto& s : config_.arguments) argv.push_back(s.data());
    argv.push_back(nullptr);
    for (auto& s : config_.environment) env.push_back(s.data());
    env.push_back(nullptr);
    const auto result = prepared ? posix_spawn(&pid_, config_.executable.c_str(), &actions, &attributes, argv.data(), env.data()) : EINVAL;
    if (actionsOK) posix_spawn_file_actions_destroy(&actions);
    if (attributesOK) posix_spawnattr_destroy(&attributes);
    closeFD(input[0]); closeFD(output[1]); closeFD(nullFD);
    if (result) { pid_ = -1; cleanup(); return fail("Worker spawn failed"); }
    const auto deadline = Clock::now() + config_.startupTimeout;
    std::string ready;
    while (ready.size() < 512) {
        if (!await(POLLIN, response_, deadline)) { cleanup(); return false; }
        char byte;
        const auto count = ::read(response_, &byte, 1);
        if (count < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (count != 1) { fail("Worker readiness EOF"); cleanup(); return false; }
        ready += byte;
        if (byte == '\n') break;
    }
    if (ready != config_.expectedReadyLine || !noPending()) {
        fail("Worker readiness mismatch"); cleanup(); return false;
    }
    started_ = true; terminal_ = false; return true;
}
bool WorkerBroker::process480(const std::array<float, wire::samples>& input,
                              std::array<float, wire::samples>& output) {
    output.fill(0);
    if (!started_ || terminal_ || !error_.empty()) return fail("Worker not running");
    if (sequence_ == UINT64_MAX || !noPending()) { fail("Worker sequence exhausted"); cleanup(); return false; }
    wire::Frame request; request.sequence = sequence_; request.values = input;
    wire::Storage bytes{}; const auto size = wire::encode(request, config_.token, bytes);
    if (!size) { fail("Invalid worker input"); cleanup(); return false; }
    const auto deadline = Clock::now() + config_.frameTimeout;
    wire::Frame response;
    if (!writeBytes(std::span(bytes.data(),size),deadline) || !readFrame(wire::Kind::result,response,deadline)) { cleanup(); return false; }
    output = response.values; ++sequence_; return true;
}
bool WorkerBroker::service() {
    if (!started_ || terminal_ || !error_.empty()) return fail("Worker not running");
    if (!noPending()) { cleanup(); return false; }
    return true;
}
bool WorkerBroker::close() {
    if (!started_ || terminal_ || !error_.empty()) { cleanup(); return fail("Worker not running"); }
    terminal_ = true;
    const auto deadline = Clock::now() + config_.shutdownTimeout;
    wire::Frame frame; frame.kind = wire::Kind::close; frame.sequence = sequence_;
    wire::Storage bytes{}; const auto size = wire::encode(frame,config_.token,bytes);
    if (!noPending() || !writeBytes(std::span(bytes.data(),size),deadline)) { cleanup(); return false; }
    closeFD(request_);
    if (!readFrame(wire::Kind::close,frame,deadline)) { cleanup(); return false; }
    for (;;) {
        if (!await(POLLIN,response_,deadline)) { cleanup(); return false; }
        std::uint8_t byte; const auto count = ::read(response_,&byte,1);
        if (count < 0 && (errno == EINTR || errno == EAGAIN)) continue;
        if (count != 0) { fail("Trailing worker output after close"); cleanup(); return false; }
        break;
    }
    closeFD(response_);
    while (!reap() && Clock::now() < deadline) std::this_thread::sleep_for(std::chrono::milliseconds(1));
    if (!reaped_ || status_ == -1 || !WIFEXITED(status_) || WEXITSTATUS(status_) != 0) {
        fail("Worker clean exit not confirmed"); cleanup(); return false;
    }
    return true;
}
} // namespace krisp_probe
