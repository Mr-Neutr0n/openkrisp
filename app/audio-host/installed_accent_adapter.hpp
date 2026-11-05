#pragma once
#include "accent_worker.hpp"
#include "routing.hpp"
#include "../accent-engine/installed_launch.hpp"
#include <algorithm>
#include <cstdlib>

namespace labvoice {
class InstalledAccentAdapter {
    ProcessorBinding base_;
    std::shared_ptr<accent::Worker> worker_;
    const std::size_t maximum_, current_;
    std::atomic<std::uint64_t> callbacks_{0};
    std::atomic<unsigned> observedMinimum_{callbackLimit}, observedMaximum_{0};
    std::atomic<bool> stopped_{false}, failed_{false};
    InstalledAccentAdapter(ProcessorBinding base, std::shared_ptr<accent::Worker> worker, std::size_t maximum, std::size_t current)
        : base_(std::move(base)), worker_(std::move(worker)), maximum_(maximum), current_(current) {}
  public:
    static std::shared_ptr<InstalledAccentAdapter> create(const Layout& layout,
        const accent_engine::InstalledAccentSettings& settings, ProcessorBinding base, std::string& error, std::size_t schedulingBudgetFrames=2) {
        try {
            if (!layout.currentCallbackFrames || layout.currentCallbackFrames > layout.maximumCallbackFrames ||
                layout.maximumCallbackFrames > callbackLimit || settings.direction != accent_engine::Direction::outbound || base.duplex.processor)
                throw std::invalid_argument("Accent microphone requires valid callback bounds and an outbound-only chain");
            accent_engine::wire::Token token{}; arc4random_buf(token.data(),token.size());
            auto worker = accent::Worker::create(accent_engine::buildInstalledAccentLaunch(settings,token),
                {layout.maximumCallbackFrames,schedulingBudgetFrames},error);
            if (!worker) return {};
            return std::shared_ptr<InstalledAccentAdapter>(new InstalledAccentAdapter(std::move(base),std::move(worker),layout.maximumCallbackFrames,layout.currentCallbackFrames));
        } catch (const std::exception& failure) { error=failure.what(); return {}; }
    }
    ~InstalledAccentAdapter() { (void)stop(); }
    static bool process(void* data,const float* microphone,const float* monitor,float* feed,float* playback,UInt32 count) noexcept {
        if (!data) return false;
        auto& self=*static_cast<InstalledAccentAdapter*>(data);
        if (count) {
            self.callbacks_.fetch_add(1,std::memory_order_relaxed);
            if (count < self.observedMinimum_.load(std::memory_order_relaxed)) self.observedMinimum_.store(count,std::memory_order_relaxed);
            if (count > self.observedMaximum_.load(std::memory_order_relaxed)) self.observedMaximum_.store(count,std::memory_order_relaxed);
        }
        if (!feed || !playback || count > self.maximum_) { self.failed_.store(true,std::memory_order_release); return false; }
        auto silent=[&] { std::fill_n(feed,count,0.f); std::fill_n(playback,count*2,0.f); return false; };
        if (self.stopped_.load(std::memory_order_acquire) || self.failed_.load(std::memory_order_acquire)) return silent();
        bool okay = microphone && monitor;
        if (okay && self.base_.processor) okay=self.base_.processor(self.base_.data,microphone,monitor,feed,playback,count);
        else if (okay) {
            for (UInt32 i=0;i<count;++i) {
                if (!std::isfinite(microphone[i]) || !std::isfinite(monitor[2*i]) || !std::isfinite(monitor[2*i+1])) { okay=false; break; }
                playback[2*i]=monitor[2*i]; playback[2*i+1]=monitor[2*i+1];
            }
        }
        if (!okay || !self.worker_->exchange(microphone,feed,count)) { self.failed_.store(true,std::memory_order_release); return silent(); }
        return self.stopped_.load(std::memory_order_acquire) ? silent() : true;
    }
    bool healthy() const noexcept { return !stopped_.load(std::memory_order_acquire) && !failed_.load(std::memory_order_acquire) && worker_->healthy(); }
    std::string error() const { auto message=worker_->error(); return message.empty() && failed_.load(std::memory_order_acquire) ? "Accent callback failed" : message; }
    bool stop() { stopped_.store(true,std::memory_order_release); return worker_->stop(); }
    auto fault() const noexcept { return worker_->fault(); }
    std::uint64_t callbackCount() const noexcept { return callbacks_.load(std::memory_order_relaxed); }
    unsigned observedMinimum() const noexcept { return callbackCount() ? observedMinimum_.load(std::memory_order_relaxed) : 0; }
    unsigned observedMaximum() const noexcept { return observedMaximum_.load(std::memory_order_relaxed); }
    std::size_t current() const noexcept { return current_; }
    std::size_t maximum() const noexcept { return maximum_; }
    std::size_t delay() const noexcept { return worker_->delay(); }
    std::uint64_t processed() const noexcept { return worker_->processed(); }
    std::uint64_t empty() const noexcept { return worker_->empty(); }
};
} // namespace labvoice
