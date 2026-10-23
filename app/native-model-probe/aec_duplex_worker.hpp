#pragma once
#include "aec_duplex_transport.hpp"
#include "aec_worker_broker.hpp"
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <string>
#include <thread>

namespace krisp_probe {
// One control thread creates/stops/releases this owner. One serialized audio
// callback calls exchange. Retain ownership until callback removal succeeds,
// including HAL cleanup failure. stop never releases callback-visible storage.
// Broker construction, every operation and destruction stay on its one thread.
class AECDuplexWorker {
    AECDuplexTransport transport_;
    AECWorkerLaunchConfig config_;
    std::thread thread_;
    std::atomic<bool> stopping_{false},finished_{false};
    std::atomic<std::uint64_t> processed_{0};
    std::mutex startupMutex_;
    std::condition_variable startupChanged_;
    bool initialized_=false,ready_=false;
    bool cleanShutdown_=false; // Published by finished_ release or thread join.
    std::string error_; // Read only after finished_ acquire or thread join.
    AECDuplexWorker(AECWorkerLaunchConfig config,AECDuplexBufferingConfig buffering)
        :transport_(buffering),config_(std::move(config)){}
    void initialized(bool ready) noexcept {
        {std::lock_guard lock(startupMutex_);ready_=ready;initialized_=true;}
        startupChanged_.notify_one();
    }
    void run() noexcept {
        try {
            AECWorkerBroker broker(std::move(config_));
            if(!broker.start()) {
                error_=broker.error();
                transport_.fail(AECDuplexTransport::Fault::worker_failure);
                initialized(false);
            } else {
                initialized(true);
                AECDuplexTransport::Frame frame;
                while(!stopping_.load(std::memory_order_acquire) &&
                      transport_.fault()==AECDuplexTransport::Fault::none) {
                    if(!broker.service()) {
                        error_=broker.error();transport_.fail(AECDuplexTransport::Fault::worker_failure);break;
                    }
                    if(!transport_.acquire(frame)) {
                        std::this_thread::sleep_for(std::chrono::milliseconds(1));continue;
                    }
                    aec_wire::Frame response;
                    if(!broker.process480(frame.wire,response)) {
                        error_=broker.error();transport_.fail(AECDuplexTransport::Fault::worker_failure);break;
                    }
                    frame.wire=response;
                    if(!transport_.submit(frame))break;
                    processed_.fetch_add(1,std::memory_order_release);
                }
                const auto fault=transport_.fault();
                if(fault!=AECDuplexTransport::Fault::none && fault!=AECDuplexTransport::Fault::stopped && error_.empty())
                    error_="AEC duplex transport failed";
                const bool closed=broker.close();
                if(!closed && error_.empty())error_=broker.error();
                cleanShutdown_=closed && error_.empty();
            }
        } catch(...) {
            transport_.fail(AECDuplexTransport::Fault::worker_failure);
            try {error_="Unexpected AEC broker failure";}catch(...){}
            initialized(false);
        }
        finished_.store(true,std::memory_order_release);
    }
  public:
    static std::shared_ptr<AECDuplexWorker> create(AECWorkerLaunchConfig config,std::string& error,
                                                  AECDuplexBufferingConfig buffering={}) {
        error.clear();
        std::shared_ptr<AECDuplexWorker> owner;
        // The broker validates exact deadline bounds on its thread. This wait
        // covers startup and bounded cleanup; scheduler delays remain possible.
        if(config.startupTimeout.count()<1 || config.startupTimeout.count()>30000 ||
           config.frameTimeout.count()<1 || config.frameTimeout.count()>5000 ||
           config.shutdownTimeout.count()<1 || config.shutdownTimeout.count()>5000) {
            error="Invalid AEC worker deadlines";return {};
        }
        const auto startupBudget=config.startupTimeout+config.shutdownTimeout+std::chrono::seconds(2);
        try {owner.reset(new AECDuplexWorker(std::move(config),buffering));}
        catch(const std::exception& failure){error=failure.what();return {};}
        try {owner->thread_=std::thread([value=owner.get()]{value->run();});}
        catch(...){error="Could not start AEC broker thread";return {};}
        bool initialized=false,ready=false;
        {
            std::unique_lock lock(owner->startupMutex_);
            initialized=owner->startupChanged_.wait_for(lock,startupBudget,[&]{return owner->initialized_;});
            ready=owner->ready_;
        }
        if(!initialized || !ready || !owner->healthy()) {
            (void)owner->stop();
            error=initialized ? owner->error_ : "AEC broker startup wait expired";
            if(error.empty())error="AEC broker failed during startup";
            return {};
        }
        return owner;
    }
    AECDuplexWorker(const AECDuplexWorker&)=delete;
    AECDuplexWorker& operator=(const AECDuplexWorker&)=delete;
    ~AECDuplexWorker(){(void)stop();}
    bool exchange(const AECDuplexTransport::PairedBlock& input,float* output,
                  AECDuplexTransport::OutputMetadata* metadata=nullptr) noexcept {
        return transport_.exchange(input,output,metadata);
    }
    bool healthy() const noexcept {
        return !finished_.load(std::memory_order_acquire) && transport_.fault()==AECDuplexTransport::Fault::none;
    }
    auto fault() const noexcept{return transport_.fault();}
    std::size_t actualDelaySamples() const noexcept{return transport_.actualDelaySamples();}
    std::size_t maximumCallbackFrames() const noexcept{return transport_.maximumCallbackFrames();}
    const AECDuplexBufferingConfig& bufferingConfig() const noexcept{return transport_.bufferingConfig();}
    std::uint64_t processedFrames() const noexcept{return processed_.load(std::memory_order_acquire);}
    std::string error() const{return finished_.load(std::memory_order_acquire)?error_:std::string{};}
    // Control thread only. Join may wait for startup/frame/shutdown deadlines.
    // Never call from audio or broker threads. Repeated stop returns same result.
    bool stop() {
        stopping_.store(true,std::memory_order_release);
        transport_.fail(AECDuplexTransport::Fault::stopped);
        if(thread_.joinable())thread_.join();
        return cleanShutdown_;
    }
};
} // namespace krisp_probe
