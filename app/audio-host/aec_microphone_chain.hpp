#pragma once
#include "installed_aec_adapter.hpp"
#include "installed_noise_adapter.hpp"

namespace labvoice {
struct AECMicrophoneChainOptions {
    InstalledAECOptions aec;
    std::optional<krisp_probe::InstalledWorkerSettings> microphone;
    bool microphoneRNNoise = false;
    std::size_t schedulingBudgetFrames = 2;
};
// The route's separate processor owns speaker DSP only. This duplex hook runs
// AEC on raw microphone/final playback, then optional microphone-only NC. Retain
// a strong control owner and stop it before a late Context can release storage.
class AECMicrophoneChain : public std::enable_shared_from_this<AECMicrophoneChain> {
    const AECMicrophoneChainOptions options_;
    const std::size_t maximum_;
    std::shared_ptr<InstalledAECAdapter> aec_;
    std::shared_ptr<InstalledNoiseAdapter> microphone_;
    std::array<float,callbackLimit> aecOutput_{};
    std::array<float,callbackLimit*2> dummyMonitor_{},dummyPlayback_{};
    std::atomic<bool> stopped_{false},callbackFailed_{false};
    bool cleanStop_=true; // Control thread only.
    AECMicrophoneChain(AECMicrophoneChainOptions options,std::size_t maximum)
        :options_(std::move(options)),maximum_(maximum){}
    bool reject(float* output,UInt32 count) noexcept {
        if(!stopped_.load(std::memory_order_acquire))callbackFailed_.store(true,std::memory_order_release);
        if(output)std::fill_n(output,count,0.f);return false;
    }
  public:
    using AECWorkerFactory=InstalledAECAdapter::WorkerFactory;
    using NCWorkerFactory=InstalledNoiseAdapter::WorkerFactory;
    // Both fixed builders and buffering contracts are validated before either
    // child starts. The seams retain the existing fixed-builder admission path.
    static std::shared_ptr<AECMicrophoneChain> create(const Layout& layout,
        const AECMicrophoneChainOptions& options,std::string& error,
        AECWorkerFactory aecFactory={},NCWorkerFactory ncFactory={}) {
        error.clear();
        try {
            if(!layout.currentCallbackFrames || !layout.maximumCallbackFrames ||
                layout.currentCallbackFrames>layout.maximumCallbackFrames || layout.maximumCallbackFrames>callbackLimit)
                throw std::invalid_argument("Invalid validated callback bounds");
            if(options.microphone && options.microphoneRNNoise)
                throw std::invalid_argument("Microphone NC cannot select installed and RNNoise together");
            const krisp_probe::AECDuplexTransport aecValidated({layout.maximumCallbackFrames,options.aec.schedulingBudgetFrames});
            const krisp_probe::ProviderTransport<> ncValidated({layout.maximumCallbackFrames,options.schedulingBudgetFrames});
            if(options.microphone) {
                if(options.microphone->modelRole!=krisp_probe::InstalledModelRole::outbound)
                    throw std::invalid_argument("AEC microphone chain requires outbound NC model role");
                if(options.microphone->bypass)
                    throw std::invalid_argument("AEC microphone chain requires active NC suppression");
                (void)krisp_probe::buildInstalledWorkerLaunch(*options.microphone,{});
            }
            (void)krisp_probe::buildInstalledAECWorkerLaunch(options.aec.settings,{});
            auto owner=std::shared_ptr<AECMicrophoneChain>(new AECMicrophoneChain(options,layout.maximumCallbackFrames));
            owner->aec_=InstalledAECAdapter::create(layout,options.aec,true,error,std::move(aecFactory));
            if(!owner->aec_)return {};
            if(options.microphone || options.microphoneRNNoise) {
                InstalledNoiseOptions post;
                post.microphone=options.microphone;post.microphoneRNNoise=options.microphoneRNNoise;
                post.schedulingBudgetFrames=options.schedulingBudgetFrames;
                owner->microphone_=InstalledNoiseAdapter::create(layout,post,error,std::move(ncFactory));
                if(!owner->microphone_){(void)owner->stop();return {};}
            }
            return owner;
        }catch(const std::exception& failure){error=failure.what();return {};}
    }
    ~AECMicrophoneChain(){(void)stop();}
    DuplexBinding binding(){return {process,this,shared_from_this(),epoch()};}
    static bool process(void* data,const DuplexBlock& block,float* output) noexcept {
        if(!data)return false;
        auto& self=*static_cast<AECMicrophoneChain*>(data);
        if(!output || block.count>self.maximum_){self.callbackFailed_.store(true,std::memory_order_release);return false;}
        if(self.stopped_.load(std::memory_order_acquire) || self.callbackFailed_.load(std::memory_order_acquire))
            return self.reject(output,block.count);
        if(!self.aec_->exchange(block,self.aecOutput_.data()))return self.reject(output,block.count);
        if(self.microphone_) {
            if(!InstalledNoiseAdapter::process(self.microphone_.get(),self.aecOutput_.data(),self.dummyMonitor_.data(),
                output,self.dummyPlayback_.data(),block.count))return self.reject(output,block.count);
        }else std::copy_n(self.aecOutput_.data(),block.count,output);
        if(self.stopped_.load(std::memory_order_acquire))return self.reject(output,block.count);
        return true;
    }
    bool healthy()const noexcept {
        return !stopped_.load(std::memory_order_acquire) && !callbackFailed_.load(std::memory_order_acquire) &&
            aec_ && aec_->healthy() && (!microphone_ || microphone_->healthy());
    }
    std::string error()const {
        const auto a=aec_?aec_->error():std::string{};
        const auto n=microphone_?microphone_->error():std::string{};
        if(!a.empty() && !n.empty())return a+"; "+n;
        if(!a.empty())return a;if(!n.empty())return n;
        return callbackFailed_.load(std::memory_order_acquire)?"AEC microphone chain callback failed":std::string{};
    }
    bool stop() {
        stopped_.store(true,std::memory_order_release);
        bool a=true,n=true;
        try{if(aec_)a=aec_->stop();}catch(...){a=false;}
        try{if(microphone_)n=microphone_->stop();}catch(...){n=false;}
        cleanStop_=cleanStop_ && a && n;return cleanStop_;
    }
    const krisp_probe::InstalledAECWorkerSettings& aecSettings()const noexcept{return options_.aec.settings;}
    const krisp_probe::InstalledWorkerSettings* microphoneSettings()const noexcept{return options_.microphone?&*options_.microphone:nullptr;}
    std::size_t aecDelaySamples()const noexcept{return aec_?aec_->actualDelaySamples():0;}
    std::size_t microphoneDelaySamples()const noexcept{return microphone_?microphone_->microphoneDelaySamples():0;}
    std::size_t totalMicrophoneDelaySamples()const noexcept{return aecDelaySamples()+microphoneDelaySamples();}
    std::size_t actualDelaySamples()const noexcept{return totalMicrophoneDelaySamples();}
    std::size_t maximumCallbackFrames()const noexcept{return maximum_;}
    const krisp_probe::AECDuplexBufferingConfig& bufferingConfig()const noexcept{return aec_->bufferingConfig();}
    std::uint64_t aecProcessedFrames()const noexcept{return aec_?aec_->processedFrames():0;}
    std::uint64_t microphoneProcessedFrames()const noexcept{return microphone_?microphone_->microphoneProcessedFrames():0;}
    std::uint64_t epoch()const noexcept{return aec_?aec_->epoch():0;}
};
}
