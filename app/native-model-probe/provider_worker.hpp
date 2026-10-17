#pragma once
#include "provider_transport.hpp"
#include "worker_broker.hpp"
#include <atomic>
#include <chrono>
#include <memory>
#include <string>
#include <thread>

namespace krisp_probe {
// The control thread creates, stops and releases this owner. Exactly one audio
// callback calls exchange. Keep the owner alive until callback removal succeeds.
// All pipe IO and inference waits run on the broker thread, never in exchange.
class ProviderWorker {
    ProviderTransport<> transport_;
    WorkerBroker broker_;
    std::thread thread_;
    std::atomic<bool> stopping_{false}, finished_{false};
    std::atomic<std::uint64_t> processed_{0};
    bool cleanShutdown_ = false; // Published by finished_ or thread join.
    std::string error_; // Read only after join or finished_ acquire.
    explicit ProviderWorker(WorkerLaunchConfig config, ProviderBufferingConfig buffering)
        : transport_(buffering), broker_(std::move(config)) {}
    void run() noexcept {
        try {
            ProviderTransport<>::Frame frame;
            while (!stopping_.load(std::memory_order_acquire) &&
                   transport_.fault() == ProviderTransport<>::Fault::none) {
                if (!broker_.service()) {
                    transport_.fail(ProviderTransport<>::Fault::worker_failure);
                    error_ = broker_.error();
                    break;
                }
                if (!transport_.acquire(frame)) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(1));
                    continue;
                }
                std::array<float, 480> result{};
                if (!broker_.process480(frame.samples, result)) {
                    transport_.fail(ProviderTransport<>::Fault::worker_failure);
                    error_ = broker_.error();
                    break;
                }
                frame.samples = result;
                if (!transport_.submit(frame)) break;
                processed_.fetch_add(1, std::memory_order_release);
            }
            const auto fault = transport_.fault();
            if (fault != ProviderTransport<>::Fault::none &&
                fault != ProviderTransport<>::Fault::stopped && error_.empty())
                error_ = "Audio provider transport failed";
            const bool closed = broker_.close();
            if (!closed && error_.empty()) error_ = broker_.error();
            cleanShutdown_ = closed && error_.empty();
        } catch (...) {
            transport_.fail(ProviderTransport<>::Fault::worker_failure);
            try { error_ = "Unexpected broker failure"; (void)broker_.close(); } catch (...) {}
        }
        finished_.store(true, std::memory_order_release);
    }
  public:
    static std::shared_ptr<ProviderWorker> create(WorkerLaunchConfig config, std::string& error,
                                                 ProviderBufferingConfig buffering = {}) {
        std::shared_ptr<ProviderWorker> owner;
        try { owner.reset(new ProviderWorker(std::move(config), buffering)); }
        catch (const std::invalid_argument& failure) { error = failure.what(); return {}; }
        if (!owner->broker_.start()) { error = owner->broker_.error(); return {}; }
        try { owner->thread_ = std::thread([p = owner.get()] { p->run(); }); }
        catch (...) { error = "Could not start provider broker thread"; return {}; }
        return owner;
    }
    ProviderWorker(const ProviderWorker&) = delete;
    ProviderWorker& operator=(const ProviderWorker&) = delete;
    ~ProviderWorker() { (void)stop(); }
    bool exchange(const float* input, float* output, std::size_t count) noexcept {
        return transport_.exchange(input, output, count);
    }
    std::size_t actualDelaySamples() const noexcept { return transport_.actualDelaySamples(); }
    std::size_t maximumCallbackFrames() const noexcept { return transport_.maximumCallbackFrames(); }
    const ProviderBufferingConfig& bufferingConfig() const noexcept { return transport_.bufferingConfig(); }
    bool healthy() const noexcept {
        return !finished_.load(std::memory_order_acquire) &&
               transport_.fault() == ProviderTransport<>::Fault::none;
    }
    auto fault() const noexcept { return transport_.fault(); }
    std::uint64_t processedFrames() const noexcept { return processed_.load(std::memory_order_acquire); }
    std::string error() const {
        return finished_.load(std::memory_order_acquire) ? error_ : std::string{};
    }
    // Control thread only. Join can wait for the bounded broker operation and
    // shutdown deadlines. Never call from the audio callback or broker thread.
    bool stop() {
        stopping_.store(true, std::memory_order_release);
        transport_.fail(ProviderTransport<>::Fault::stopped);
        if (thread_.joinable()) thread_.join();
        if (!finished_.load(std::memory_order_acquire)) {
            cleanShutdown_ = broker_.close();
            if (!cleanShutdown_) error_ = broker_.error();
            finished_.store(true, std::memory_order_release);
        }
        return cleanShutdown_;
    }
};
} // namespace krisp_probe
