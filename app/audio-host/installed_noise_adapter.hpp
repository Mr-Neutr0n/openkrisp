#pragma once
#include "noise_adapter.hpp"
#include "../native-model-probe/installed_worker_launch.hpp"
#include "../native-model-probe/provider_worker.hpp"
#include <algorithm>
#include <cstdlib>
#include <functional>

namespace labvoice {
// Construct on the Session control thread after Layout validation. The Context
// must retain this owner until HAL callbacks are removed. Keep a separate strong
// owner on the control thread through shutdown. The control thread
// must call stop before releasing its owner, even if Session teardown fails.
// stop only latches an atomic transport fault and joins the broker; concurrent
// process calls then fail closed. Callback-owned arrays and speaker state remain
// alive through Context after failed HAL teardown. A late Context release does
// not need to join a running worker because control already stopped it.
class InstalledNoiseAdapter {
  public:
    using WorkerFactory = std::function<std::shared_ptr<krisp_probe::ProviderWorker>(
        krisp_probe::WorkerLaunchConfig, std::string&, krisp_probe::ProviderBufferingConfig)>;
    static constexpr const char* microphoneProvider = "ordinary-nc-direct";
    static constexpr const char* microphoneModel = "nc-outbound-mfb";
    static constexpr const char* microphoneModelFile = "c8.f.m.528d1f-1.0.1_1.0.kef";
  private:
    const krisp_probe::InstalledWorkerSettings settings_;
    const bool speakerEnabled_;
    std::shared_ptr<krisp_probe::ProviderWorker> worker_;
    NoiseAdapter speaker_;
    std::array<float, callbackLimit> discardedFeed_{};
    InstalledNoiseAdapter(const krisp_probe::InstalledWorkerSettings& settings, bool speaker)
        : settings_(settings), speakerEnabled_(speaker), speaker_(false,speaker) {}
  public:
    // WorkerFactory is a C++ test seam. User-facing launch paths must use the
    // default factory, which executes the exact-identity installed builder.
    static std::shared_ptr<InstalledNoiseAdapter> create(
        const Layout& layout, const krisp_probe::InstalledWorkerSettings& settings,
        bool speakerNoise, std::string& error, std::size_t schedulingBudgetFrames = 2,
        WorkerFactory testFactory = {}) {
        error.clear();
        try {
            if (settings.modelRole != krisp_probe::InstalledModelRole::outbound)
                throw std::invalid_argument("Installed microphone provider requires outbound model role");
            if (!layout.currentCallbackFrames || !layout.maximumCallbackFrames ||
                layout.currentCallbackFrames > layout.maximumCallbackFrames ||
                layout.maximumCallbackFrames > callbackLimit)
                throw std::invalid_argument("Invalid validated callback bounds");
            if (settings.bypass)
                throw std::invalid_argument("Installed microphone provider requires active suppression");
            krisp_probe::ProviderBufferingConfig buffering{layout.maximumCallbackFrames,schedulingBudgetFrames};
            // Validate before constructing a child or any test factory call.
            const krisp_probe::ProviderTransport<> validated(buffering);
            (void)validated;
            auto owner=std::shared_ptr<InstalledNoiseAdapter>(new InstalledNoiseAdapter(settings,speakerNoise));
            krisp_probe::wire::Token token{};
            arc4random_buf(token.data(),token.size());
            auto launch=krisp_probe::buildInstalledWorkerLaunch(settings,token);
            owner->worker_=testFactory ? testFactory(std::move(launch),error,buffering)
                                      : krisp_probe::ProviderWorker::create(std::move(launch),error,buffering);
            if (!owner->worker_) {
                if (error.empty()) error="Installed microphone worker startup failed";
                return {};
            }
            // Test factories must preserve the validated callback/delay contract.
            if (owner->worker_->maximumCallbackFrames()!=buffering.maximumCallbackFrames ||
                owner->worker_->actualDelaySamples()!=validated.actualDelaySamples() || !owner->worker_->healthy()) {
                error="Installed microphone worker contract mismatch";
                return {};
            }
            return owner;
        } catch (const std::exception& failure) { error=failure.what(); return {}; }
    }
    static bool process(void* data, const float* microphone, const float* monitor,
                        float* feed, float* playback, UInt32 count) noexcept {
        if (!data) return false;
        auto& self=*static_cast<InstalledNoiseAdapter*>(data);
        if (count>self.maximumCallbackFrames()) return false;
        if (!microphone || !monitor || !feed || !playback) return false;
        // On supported-size failure, silence both outputs. Context also silences
        // its complete HAL output before honoring the returned failure.
        if (!self.worker_->exchange(microphone,feed,count)) {
            std::fill_n(feed,count,0.f); std::fill_n(playback,count*2,0.f);
            return false;
        }
        return NoiseAdapter::process(&self.speaker_,microphone,monitor,
                                     self.discardedFeed_.data(),playback,count);
    }
    bool healthy() const noexcept { return worker_->healthy(); }
    std::string error() const { return worker_->error(); }
    bool stop() { return worker_->stop(); }
    std::size_t actualDelaySamples() const noexcept { return worker_->actualDelaySamples(); }
    std::size_t maximumCallbackFrames() const noexcept { return worker_->maximumCallbackFrames(); }
    std::uint64_t processedFrames() const noexcept { return worker_->processedFrames(); }
    bool speakerNoiseEnabled() const noexcept { return speakerEnabled_; }
    const std::string& nodeSha256() const noexcept { return settings_.nodeSha256; }
    const std::string& adapterSha256() const noexcept { return settings_.adapterSha256; }
    static const char* addonSha256() noexcept { return krisp_probe::installed_worker_detail::addonSHA; }
    static const char* modelSha256() noexcept { return krisp_probe::installed_worker_detail::modelSHA; }
};
} // namespace labvoice
