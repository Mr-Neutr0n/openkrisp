#pragma once
#include "aec_worker_protocol.hpp"
#include <chrono>
#include <string>
#include <vector>
#include <sys/types.h>
namespace krisp_probe {
struct AECWorkerLaunchConfig {
    std::string executable;
    std::vector<std::string> arguments; // Excludes argv[0].
    std::vector<std::string> environment; // Exact NAME=VALUE entries. No inheritance.
    std::string expectedReadyLine; // Includes final newline. At most 512 bytes.
    aec_wire::Token token{};
    std::chrono::milliseconds startupTimeout{2000}, frameTimeout{500}, shutdownTimeout{1000};
};
// All methods, including destruction, belong to one non-audio broker thread.
// No ownership of caller buffers survives process480. Not safe for concurrent use.
// This object must be the sole reaper of its child. SIGCHLD must not auto-reap.
// Cleanup signals only that direct child, never a process group or descendants.
// Caller supplies an admitted executable, arguments and sanitized environment.
class AECWorkerBroker {
    using Clock = std::chrono::steady_clock;
    AECWorkerLaunchConfig config_;
    pid_t pid_ = -1;
    int request_ = -1, response_ = -1;
    std::uint64_t sequence_ = 0;
    aec_wire::Frame previous_{};
    bool havePrevious_ = false;
    bool started_ = false, terminal_ = false, reaped_ = false;
    int status_ = 0;
    std::string error_;
    bool fail(const char*);
    bool reap() noexcept;
    void cleanup() noexcept;
    bool await(short, int, Clock::time_point);
    bool writeBytes(std::span<const std::uint8_t>, Clock::time_point);
    bool readFrame(aec_wire::Kind, aec_wire::Frame&, Clock::time_point);
    bool noPending();
  public:
    explicit AECWorkerBroker(AECWorkerLaunchConfig config) : config_(std::move(config)) {}
    ~AECWorkerBroker();
    AECWorkerBroker(const AECWorkerBroker&) = delete;
    AECWorkerBroker& operator=(const AECWorkerBroker&) = delete;
    bool start();
    // Broker validates each lane's sample continuity. A new epoch requires a fresh worker.
    bool process480(const aec_wire::Frame& input, aec_wire::Frame& output);
    bool close();
    bool service(); // Idle owner-thread check for death or unsolicited output.
    const std::string& error() const noexcept { return error_; }
    pid_t childPID() const noexcept { return pid_; }
};
} // namespace krisp_probe
