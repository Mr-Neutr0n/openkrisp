#pragma once
#include "wire.hpp"
#include <chrono>
#include <string>
#include <vector>
#include <sys/types.h>
namespace accent_engine {
struct WorkerLaunchConfig {
    std::string executable;
    std::vector<std::string> arguments; // Excludes argv[0].
    std::vector<std::string> environment; // Exact NAME=VALUE entries. No inheritance.
    std::string expectedReadyLine; // Includes final newline. At most 512 bytes.
    wire::Token token{};
    std::chrono::milliseconds startupTimeout{2000}, frameTimeout{500}, shutdownTimeout{1000};
};
// All methods, including destruction, belong to one non-audio broker thread.
// No ownership of caller buffers survives process480. Not safe for concurrent use.
// This object must be the sole reaper of its child. SIGCHLD must not auto-reap.
// Cleanup signals only that direct child, never a process group or descendants.
// Caller supplies an admitted executable, arguments and sanitized environment.
class WorkerBroker {
    using Clock = std::chrono::steady_clock;
    WorkerLaunchConfig config_;
    pid_t pid_ = -1;
    int request_ = -1, response_ = -1;
    std::uint64_t sequence_ = 0;
    bool started_ = false, terminal_ = false, reaped_ = false;
    int status_ = 0;
    std::string error_;
    bool fail(const char*);
    bool reap() noexcept;
    void cleanup() noexcept;
    bool await(short, int, Clock::time_point);
    bool writeBytes(std::span<const std::uint8_t>, Clock::time_point);
    bool readFrame(unsigned, wire::Frame&, Clock::time_point);
    bool noPending();
  public:
    explicit WorkerBroker(WorkerLaunchConfig config) : config_(std::move(config)) {}
    ~WorkerBroker();
    WorkerBroker(const WorkerBroker&) = delete;
    WorkerBroker& operator=(const WorkerBroker&) = delete;
    bool start();
    bool process480(const std::array<float, wire::samples>& input,
                    std::array<float, wire::samples>& output, bool& produced);
    bool close();
    bool service(); // Idle owner-thread check for death or unsolicited output.
    const std::string& error() const noexcept { return error_; }
    pid_t childPID() const noexcept { return pid_; }
};
} // namespace accent_engine
