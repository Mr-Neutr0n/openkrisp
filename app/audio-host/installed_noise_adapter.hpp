#pragma once
#include "noise_adapter.hpp"
#include "../native-model-probe/installed_worker_launch.hpp"
#include "../native-model-probe/provider_worker.hpp"
#include <algorithm>
#include <cstdlib>
#include <functional>
#include <optional>

namespace labvoice {
struct InstalledNoiseOptions {
    std::optional<krisp_probe::InstalledWorkerSettings> microphone, speaker;
    bool microphoneRNNoise = false, speakerRNNoise = false;
    std::size_t schedulingBudgetFrames = 2;
};
// Construct after Layout validation. Keep a separate strong control-thread owner
// through shutdown and stop BOTH workers before releasing it, even if Session
// teardown fails. stop only latches atomic state and joins brokers. Outstanding
// callbacks then fail closed while Context retains arrays and DSP state. A late
// Context release cannot join a live worker because control already stopped it.
class InstalledNoiseAdapter {
  public:
    using WorkerFactory = std::function<std::shared_ptr<krisp_probe::ProviderWorker>(
        krisp_probe::WorkerLaunchConfig, std::string&, krisp_probe::ProviderBufferingConfig)>;
    static constexpr const char* microphoneProvider = "ordinary-nc-direct";
    static constexpr const char* microphoneModel = "nc-outbound-mfb";
    static constexpr const char* microphoneModelFile = "c8.f.m.528d1f-1.0.1_1.0.kef";
    static constexpr const char* speakerModel = "nc-inbound-mwb";
    static constexpr const char* speakerModelFile = "c8.w.m.d15e29_1.0.kef";
  private:
    const InstalledNoiseOptions options_;
    const std::size_t maximum_;
    std::shared_ptr<krisp_probe::ProviderWorker> microphone_, speaker_;
    NoiseAdapter fallback_;
    std::array<float, callbackLimit> monoInput_{}, monoOutput_{};
    std::atomic<bool> stopped_{false}, callbackFailed_{false};
    bool cleanStop_ = true; // Control-thread only.
    InstalledNoiseAdapter(InstalledNoiseOptions options, std::size_t maximum)
        : options_(std::move(options)), maximum_(maximum),
          fallback_(options_.microphoneRNNoise,options_.speakerRNNoise) {}
    bool reject(float* feed,float* playback,UInt32 count) noexcept {
        if(!stopped_.load(std::memory_order_acquire))callbackFailed_.store(true,std::memory_order_release);
        return silent(feed,playback,count);
    }
    static bool silent(float* feed,float* playback,UInt32 count) noexcept {
        std::fill_n(feed,count,0.f);std::fill_n(playback,count*2,0.f);return false;
    }
  public:
    // Test seam receives the role-bearing, exact-identity launch. Production
    // callers leave it empty and use the real ProviderWorker factory.
    static std::shared_ptr<InstalledNoiseAdapter> create(
        const Layout& layout,const InstalledNoiseOptions& options,std::string& error,
        WorkerFactory testFactory = {}) {
        error.clear();
        try {
            if (!layout.currentCallbackFrames || !layout.maximumCallbackFrames ||
                layout.currentCallbackFrames>layout.maximumCallbackFrames || layout.maximumCallbackFrames>callbackLimit)
                throw std::invalid_argument("Invalid validated callback bounds");
            if ((options.microphone && options.microphoneRNNoise) || (options.speaker && options.speakerRNNoise))
                throw std::invalid_argument("A lane cannot select both installed and RNNoise processing");
            const krisp_probe::ProviderBufferingConfig buffering{layout.maximumCallbackFrames,options.schedulingBudgetFrames};
            const krisp_probe::ProviderTransport<> validated(buffering);
            auto launch=[&](const std::optional<krisp_probe::InstalledWorkerSettings>& settings,
                            krisp_probe::InstalledModelRole role,const char* roleError)
                            -> std::optional<krisp_probe::WorkerLaunchConfig> {
                if (!settings) return {};
                if (settings->modelRole!=role &&
                    !(role==krisp_probe::InstalledModelRole::outbound && settings->modelRole==krisp_probe::InstalledModelRole::outboundHVC))
                    throw std::invalid_argument(roleError);
                if (settings->bypass) throw std::invalid_argument("Installed provider requires active suppression");
                krisp_probe::wire::Token token{};arc4random_buf(token.data(),token.size());
                return krisp_probe::buildInstalledWorkerLaunch(*settings,token);
            };
            // Build both commands before spawning either child. This validates
            // every path, role, digest and option, including the second lane.
            auto microphoneLaunch=launch(options.microphone,krisp_probe::InstalledModelRole::outbound,
                                         "Installed microphone provider requires outbound or outbound-hvc-lfb model role");
            auto speakerLaunch=launch(options.speaker,krisp_probe::InstalledModelRole::inbound,
                                      "Installed speaker provider requires inbound model role");
            auto owner=std::shared_ptr<InstalledNoiseAdapter>(new InstalledNoiseAdapter(options,layout.maximumCallbackFrames));
            auto start=[&](std::optional<krisp_probe::WorkerLaunchConfig>& config,
                           std::shared_ptr<krisp_probe::ProviderWorker>& worker) {
                if (!config) return true;
                worker=testFactory ? testFactory(std::move(*config),error,buffering)
                                   : krisp_probe::ProviderWorker::create(std::move(*config),error,buffering);
                if (!worker) { if(error.empty())error="Installed worker startup failed";return false; }
                if (worker->maximumCallbackFrames()!=buffering.maximumCallbackFrames ||
                    worker->actualDelaySamples()!=validated.actualDelaySamples() || !worker->healthy()) {
                    error="Installed worker contract mismatch";return false;
                }
                return true;
            };
            if (!start(microphoneLaunch,owner->microphone_) || !start(speakerLaunch,owner->speaker_)) {
                (void)owner->stop();return {};
            }
            return owner;
        } catch(const std::exception& failure) { error=failure.what();return {}; }
    }
    // Microphone-installed/speaker-RNNoise API admits the two fixed microphone roles.
    static std::shared_ptr<InstalledNoiseAdapter> create(
        const Layout& layout,const krisp_probe::InstalledWorkerSettings& settings,
        bool speakerNoise,std::string& error,std::size_t schedulingBudgetFrames=2,
        WorkerFactory testFactory={}) {
        InstalledNoiseOptions options;options.microphone=settings;options.speakerRNNoise=speakerNoise;
        options.schedulingBudgetFrames=schedulingBudgetFrames;
        return create(layout,options,error,std::move(testFactory));
    }
    ~InstalledNoiseAdapter() { (void)stop(); }
    static bool process(void* data,const float* microphone,const float* monitor,
                        float* feed,float* playback,UInt32 count) noexcept {
        if (!data) return false;
        auto& self=*static_cast<InstalledNoiseAdapter*>(data);
        if (count>self.maximum_ || !feed || !playback) {
            self.callbackFailed_.store(true,std::memory_order_release);return false;
        }
        if (self.stopped_.load(std::memory_order_acquire) || self.callbackFailed_.load(std::memory_order_acquire))
            return silent(feed,playback,count);
        if (!microphone || !monitor) return self.reject(feed,playback,count);
        // Validate the entire block before advancing either worker or RNNoise
        // state. A bad second lane must not partially advance the first lane.
        for(UInt32 i=0;i<count;++i) {
            if (!std::isfinite(microphone[i]) || !std::isfinite(monitor[2*i]) || !std::isfinite(monitor[2*i+1]))
                return self.reject(feed,playback,count);
            if (self.speaker_) {
                // Preserve recovered Float32 sum-then-divide order. Overflow
                // rejects instead of silently selecting a different average.
                const float sum=monitor[2*i]+monitor[2*i+1];
                self.monoInput_[i]=sum/2.f;
                if (!std::isfinite(self.monoInput_[i])) return self.reject(feed,playback,count);
            }
        }
        // The existing adapter keeps independent fresh RNNoise state per channel
        // and copies unprocessed lanes. Installed results replace only their lane.
        if (!NoiseAdapter::process(&self.fallback_,microphone,monitor,feed,playback,count))
            return self.reject(feed,playback,count);
        if (self.microphone_ && !self.microphone_->exchange(microphone,feed,count))
            return self.reject(feed,playback,count);
        if (self.speaker_) {
            if (!self.speaker_->exchange(self.monoInput_.data(),self.monoOutput_.data(),count))
                return self.reject(feed,playback,count);
            for(UInt32 i=0;i<count;++i)playback[2*i]=playback[2*i+1]=self.monoOutput_[i];
        }
        if(self.stopped_.load(std::memory_order_acquire))return silent(feed,playback,count);
        return true;
    }
    bool healthy() const noexcept {
        return !stopped_.load(std::memory_order_acquire) && !callbackFailed_.load(std::memory_order_acquire) &&
            (!microphone_ || microphone_->healthy()) && (!speaker_ || speaker_->healthy());
    }
    std::string error() const {
        const auto mic=microphone_?microphone_->error():std::string{};
        const auto speaker=speaker_?speaker_->error():std::string{};
        if (mic.empty() && speaker.empty() && callbackFailed_.load(std::memory_order_acquire))
            return "Installed provider callback failed";
        return mic.empty()?speaker:speaker.empty()?mic:mic+"; "+speaker;
    }
    bool stop() {
        stopped_.store(true,std::memory_order_release);
        // No short-circuit: a failed microphone shutdown cannot skip speaker.
        bool mic=true,speaker=true;
        try { if(microphone_)mic=microphone_->stop(); } catch(...) { mic=false; }
        try { if(speaker_)speaker=speaker_->stop(); } catch(...) { speaker=false; }
        cleanStop_=cleanStop_ && mic && speaker;return cleanStop_;
    }
    bool microphoneInstalled() const noexcept { return options_.microphone.has_value(); }
    bool speakerInstalled() const noexcept { return options_.speaker.has_value(); }
    const krisp_probe::InstalledWorkerSettings* microphoneSettings() const noexcept { return options_.microphone?&*options_.microphone:nullptr; }
    const krisp_probe::InstalledWorkerSettings* speakerSettings() const noexcept { return options_.speaker?&*options_.speaker:nullptr; }
    std::size_t microphoneDelaySamples() const noexcept { return microphone_?microphone_->actualDelaySamples():options_.microphoneRNNoise?480:0; }
    std::size_t speakerDelaySamples() const noexcept { return speaker_?speaker_->actualDelaySamples():options_.speakerRNNoise?480:0; }
    std::size_t actualDelaySamples() const noexcept { return microphoneDelaySamples(); }
    std::size_t maximumCallbackFrames() const noexcept { return maximum_; }
    std::uint64_t microphoneProcessedFrames() const noexcept { return microphone_?microphone_->processedFrames():0; }
    std::uint64_t speakerProcessedFrames() const noexcept { return speaker_?speaker_->processedFrames():0; }
    std::uint64_t processedFrames() const noexcept { return microphoneProcessedFrames(); }
    bool speakerNoiseEnabled() const noexcept { return options_.speakerRNNoise || speakerInstalled(); }
    const std::string& nodeSha256() const noexcept { static const std::string empty;return options_.microphone?options_.microphone->nodeSha256:empty; }
    const std::string& adapterSha256() const noexcept { static const std::string empty;return options_.microphone?options_.microphone->adapterSha256:empty; }
    static const char* addonSha256() noexcept { return krisp_probe::installed_worker_detail::addonSHA; }
    static const char* modelSha256() noexcept { return krisp_probe::installedOutboundModelSHA256; }
};
} // namespace labvoice
