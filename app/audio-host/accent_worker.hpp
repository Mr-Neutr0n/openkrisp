#pragma once
#include "accent_transport.hpp"
#include "../accent-engine/worker_broker.hpp"
#include <future>
#include <memory>
#include <thread>

namespace labvoice::accent {
// The callback only exchanges fixed storage. The broker and child live solely
// on this owner's thread. Control retains this owner through HAL teardown.
class Worker {
    Transport<> transport_;
    std::thread thread_;
    std::atomic<bool> stopping_{false}, finished_{false};
    std::atomic<std::uint64_t> processed_{0}, empty_{0};
    std::string error_; // Published by finished_ or join.
    bool clean_ = false;
    explicit Worker(BufferingConfig buffering) : transport_(buffering) {}
    void run(accent_engine::WorkerLaunchConfig config, std::promise<bool> ready) noexcept {
        bool announced = false;
        try {
            accent_engine::WorkerBroker broker(std::move(config));
            const bool started = broker.start();
            if (!started) error_ = broker.error();
            ready.set_value(started); announced = true;
            if (started) {
                Transport<>::Frame frame;
                while (!stopping_.load(std::memory_order_acquire) && transport_.fault() == Transport<>::Fault::none) {
                    if (!broker.service()) { error_ = broker.error(); transport_.fail(Transport<>::Fault::worker_failure); break; }
                    if (!transport_.acquire(frame)) { std::this_thread::sleep_for(std::chrono::milliseconds(1)); continue; }
                    std::array<float, 480> output{};
                    bool produced = false;
                    if (!broker.process480(frame.samples, output, produced)) {
                        error_ = broker.error(); transport_.fail(Transport<>::Fault::worker_failure); break;
                    }
                    frame.samples = output; frame.produced = produced;
                    if (!transport_.submit(frame)) break;
                    processed_.fetch_add(1, std::memory_order_release);
                    if (!produced) empty_.fetch_add(1, std::memory_order_release);
                }
                const auto fault = transport_.fault();
                if (fault != Transport<>::Fault::none && fault != Transport<>::Fault::stopped && error_.empty())
                    error_ = "Accent transport failed";
            }
            const bool closed = broker.close();
            if (!closed && error_.empty()) error_ = broker.error();
            clean_ = closed && error_.empty();
        } catch (...) {
            transport_.fail(Transport<>::Fault::worker_failure);
            error_ = "Unexpected accent broker failure";
            if (!announced) { try { ready.set_value(false); } catch (...) {} }
        }
        finished_.store(true, std::memory_order_release);
    }
  public:
    static std::shared_ptr<Worker> create(accent_engine::WorkerLaunchConfig config,
                                          BufferingConfig buffering, std::string& error) {
        std::shared_ptr<Worker> owner;
        try {
            owner.reset(new Worker(buffering));
            std::promise<bool> ready; auto started = ready.get_future();
            owner->thread_ = std::thread([p=owner.get(), config=std::move(config), ready=std::move(ready)]() mutable {
                p->run(std::move(config), std::move(ready));
            });
            if (!started.get()) { (void)owner->stop(); error = owner->error_; return {}; }
        } catch (const std::exception& failure) { error = failure.what(); return {}; }
        return owner;
    }
    ~Worker() { (void)stop(); }
    bool exchange(const float* input, float* output, std::size_t count) noexcept { return transport_.exchange(input, output, count); }
    bool healthy() const noexcept { return !finished_.load(std::memory_order_acquire) && transport_.fault() == Transport<>::Fault::none; }
    std::string error() const { return finished_.load(std::memory_order_acquire) ? error_ : std::string{}; }
    std::size_t delay() const noexcept { return transport_.actualDelaySamples(); }
    std::uint64_t processed() const noexcept { return processed_.load(std::memory_order_acquire); }
    std::uint64_t empty() const noexcept { return empty_.load(std::memory_order_acquire); }
    bool stop() {
        stopping_.store(true, std::memory_order_release); transport_.fail(Transport<>::Fault::stopped);
        if (thread_.joinable()) thread_.join();
        return clean_;
    }
};
} // namespace labvoice::accent
