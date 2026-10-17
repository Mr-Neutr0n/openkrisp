#pragma once
#include <chrono>
#include <condition_variable>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <sys/types.h>
#include <unistd.h>

namespace krisp_probe {
// Own-process parent-loss guard. Construct before loading vendor code. Expected
// parent must be explicit and still current. Never signals another process.
// A native thread checks every 25ms, including while the main thread blocks.
// Scheduling can delay checks, so this is not a hard realtime exit bound.
// Parent loss calls _exit(72): no C++ teardown runs. The OS reclaims process
// resources. stop() belongs to one owner thread and is idempotent; it wakes the
// wait and joins normally without waiting for the polling interval. Join timing
// still depends on scheduler progress. Do not destroy from the watch thread.
class ParentWatch {
    const pid_t expected_;
    std::mutex mutex_;
    std::condition_variable wake_;
    bool stopped_ = false;
    std::thread thread_;
  public:
    explicit ParentWatch(pid_t expectedParent) : expected_(expectedParent) {
        if (expected_ <= 1 || getppid() != expected_)
            throw std::invalid_argument("Expected parent is not the current live parent");
        thread_ = std::thread([this] {
            std::unique_lock lock(mutex_);
            while (!stopped_) {
                if (getppid() != expected_) _exit(72);
                wake_.wait_for(lock, std::chrono::milliseconds(25), [this] { return stopped_; });
            }
        });
    }
    ParentWatch(const ParentWatch&) = delete;
    ParentWatch& operator=(const ParentWatch&) = delete;
    void stop() noexcept {
        { std::lock_guard lock(mutex_); stopped_ = true; }
        wake_.notify_one();
        if (thread_.joinable()) thread_.join();
    }
    ~ParentWatch() { stop(); }
};
} // namespace krisp_probe
