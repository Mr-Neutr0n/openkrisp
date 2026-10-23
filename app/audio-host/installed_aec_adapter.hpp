#pragma once
#include "routing.hpp"
#include "../native-model-probe/aec_duplex_worker.hpp"
#include "../native-model-probe/installed_aec_worker_launch.hpp"
#include <algorithm>
#include <cstdlib>
#include <functional>

namespace labvoice {
struct InstalledAECOptions {
    krisp_probe::InstalledAECWorkerSettings settings;
    std::size_t schedulingBudgetFrames = 2;
};
// Create only after validated Layout inspection. Keep a separate strong owner
// on the control thread and call stop before releasing it, even if HAL cleanup
// fails. Context then retains callback-visible storage, with no live broker to
// join when a queued HAL callback eventually releases its copy of the binding.
class InstalledAECAdapter : public std::enable_shared_from_this<InstalledAECAdapter> {
  public:
    using WorkerFactory = std::function<std::shared_ptr<krisp_probe::AECDuplexWorker>(
        krisp_probe::AECWorkerLaunchConfig, std::string&, krisp_probe::AECDuplexBufferingConfig)>;
  private:
    const InstalledAECOptions options_;
    const std::uint64_t epoch_;
    std::shared_ptr<krisp_probe::AECDuplexWorker> worker_;
    std::atomic<bool> stopped_{false}, callbackFailed_{false};
    bool cleanStop_ = true; // Control-thread only.
    InstalledAECAdapter(InstalledAECOptions options, std::uint64_t epoch)
        : options_(std::move(options)), epoch_(epoch) {}
    bool reject(float* output, UInt32 count) noexcept {
        if(!stopped_.load(std::memory_order_acquire))callbackFailed_.store(true,std::memory_order_release);
        if(output)std::fill_n(output,count,0.f);
        return false;
    }
  public:
    // Explicit microphone-stage disablement is the factory caller's contract.
    // Speaker processing remains separate and runs once before this hook. No
    // AEC-to-NC microphone chain is admitted here.
    // The test seam receives the fixed-vendor, admitted-executable command.
    // Production leaves it empty. Own-fixture tests may substitute their own
    // library/digest before creating the real background worker.
    static std::shared_ptr<InstalledAECAdapter> create(
        const Layout& layout, const InstalledAECOptions& options,
        bool microphoneStageDisabled, std::string& error, WorkerFactory testFactory = {}) {
        error.clear();
        try {
            if(!microphoneStageDisabled)
                throw std::invalid_argument("Installed AEC requires microphone NC disabled");
            if(!layout.currentCallbackFrames || !layout.maximumCallbackFrames ||
                layout.currentCallbackFrames>layout.maximumCallbackFrames || layout.maximumCallbackFrames>callbackLimit)
                throw std::invalid_argument("Invalid validated callback bounds");
            const krisp_probe::AECDuplexBufferingConfig buffering{layout.maximumCallbackFrames,options.schedulingBudgetFrames};
            const krisp_probe::AECDuplexTransport validated(buffering);
            krisp_probe::aec_wire::Token token{};arc4random_buf(token.data(),token.size());
            auto launch=krisp_probe::buildInstalledAECWorkerLaunch(options.settings,token);
            std::uint64_t epoch=0;arc4random_buf(&epoch,sizeof(epoch));
            auto owner=std::shared_ptr<InstalledAECAdapter>(new InstalledAECAdapter(options,epoch));
            owner->worker_=testFactory ? testFactory(std::move(launch),error,buffering)
                                      : krisp_probe::AECDuplexWorker::create(std::move(launch),error,buffering);
            if(!owner->worker_) {if(error.empty())error="Installed AEC worker startup failed";return {};}
            if(owner->worker_->maximumCallbackFrames()!=buffering.maximumCallbackFrames ||
                owner->worker_->actualDelaySamples()!=validated.actualDelaySamples() || !owner->worker_->healthy()) {
                error="Installed AEC worker contract mismatch";(void)owner->stop();return {};
            }
            return owner;
        }catch(const std::exception& failure){error=failure.what();return {};}
    }
    ~InstalledAECAdapter(){(void)stop();}
    DuplexBinding binding() { return {process,this,shared_from_this(),epoch_}; }
    static bool process(void* data,const DuplexBlock& block,float* output) noexcept {
        if(!data)return false;
        return static_cast<InstalledAECAdapter*>(data)->exchange(block,output);
    }
    bool exchange(const DuplexBlock& block,float* output,
                  krisp_probe::AECDuplexTransport::OutputMetadata* metadata=nullptr) noexcept {
        auto& self=*this;
        if(metadata)metadata->count=0;
        // Unsupported extents cannot be safely cleared. The route validates its
        // bounds first and owns muting any unsupported hardware buffer extent.
        if(!output || !self.worker_ || block.count>self.maximumCallbackFrames()) {
            self.callbackFailed_.store(true,std::memory_order_release);return false;
        }
        if(self.stopped_.load(std::memory_order_acquire) || self.callbackFailed_.load(std::memory_order_acquire) ||
            block.epoch!=self.epoch_ || !self.worker_->healthy())return self.reject(output,block.count);
        krisp_probe::AECPairedBlock input;
        input.microphone=block.rawMicrophone;input.finalReference=block.finalPlayback;
        input.count=block.count;input.epoch=block.epoch;
        const auto stamp=[](const DuplexLaneTiming& timing) {
            return krisp_probe::AECLaneStamp{timing.inputSampleOrigin,timing.outputSampleOrigin,
                timing.hostTime,timing.sampleOriginsValid,timing.hostTimeValid};
        };
        // Preserve supplied callback anchors. The transport keeps wire host-time
        // validity false and records first-sample anchor/sample-offset provenance.
        // These origins correlate callbacks; no physical echo alignment is inferred.
        input.microphoneStamp=stamp(block.microphoneTiming);
        input.referenceStamp=stamp(block.referenceTiming);
        if(!self.worker_->exchange(input,output,metadata) || self.stopped_.load(std::memory_order_acquire)) {
            if(metadata)metadata->count=0;
            return self.reject(output,block.count);
        }
        return true;
    }
    bool healthy() const noexcept {
        return !stopped_.load(std::memory_order_acquire) && !callbackFailed_.load(std::memory_order_acquire) &&
            worker_ && worker_->healthy();
    }
    std::string error() const {
        const auto failure=worker_?worker_->error():std::string{};
        if(!failure.empty())return failure;
        return callbackFailed_.load(std::memory_order_acquire)?"Installed AEC callback failed":std::string{};
    }
    bool stop() {
        stopped_.store(true,std::memory_order_release);
        bool clean=true;
        try{if(worker_)clean=worker_->stop();}catch(...){clean=false;}
        cleanStop_=cleanStop_ && clean;return cleanStop_;
    }
    const krisp_probe::InstalledAECWorkerSettings& settings() const noexcept{return options_.settings;}
    const krisp_probe::AECDuplexBufferingConfig& bufferingConfig() const noexcept{return worker_->bufferingConfig();}
    std::size_t actualDelaySamples() const noexcept{return worker_?worker_->actualDelaySamples():0;}
    std::size_t maximumCallbackFrames() const noexcept{return worker_?worker_->maximumCallbackFrames():0;}
    std::uint64_t processedFrames() const noexcept{return worker_?worker_->processedFrames():0;}
    std::uint64_t epoch() const noexcept{return epoch_;}
    static const char* librarySha256() noexcept{return krisp_probe::installedAECLibrarySHA256;}
};
}
