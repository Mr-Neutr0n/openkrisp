#include "routing.hpp"
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <stdexcept>
#include <thread>

namespace labvoice {
namespace {
struct Count {
    Context &context;
    explicit Count(Context &c) : context(c) { context.callbacks.fetch_add(1); }
    ~Count() { context.callbacks.fetch_sub(1); }
};
bool validTime(const AudioTimeStamp *time) {
    return time && (time->mFlags & kAudioTimeStampSampleTimeValid) &&
           std::isfinite(time->mSampleTime) && time->mSampleTime >= 0;
}
bool shape(const AudioBufferList *list, const std::vector<UInt32> &expected, UInt32 &frames) {
    if (!list || list->mNumberBuffers != expected.size())
        return false;
    bool found = false;
    for (UInt32 i = 0; i < list->mNumberBuffers; ++i) {
        const auto &b = list->mBuffers[i];
        if (b.mNumberChannels != expected[i] || !b.mNumberChannels)
            return false;
        const UInt32 stride = b.mNumberChannels * sizeof(float);
        if (b.mDataByteSize % stride)
            return false;
        const UInt32 count = b.mDataByteSize / stride;
        if (count > callbackLimit)
            return false;
        if (b.mData) {
            if (found && count != frames)
                return false;
            frames = count;
            found = true;
        }
    }
    return found;
}
float sample(const AudioBufferList *list, UInt32 channel, UInt32 frame) {
    for (UInt32 i = 0; i < list->mNumberBuffers; ++i) {
        const auto &b = list->mBuffers[i];
        if (channel < b.mNumberChannels) {
            if (!b.mData || frame >= b.mDataByteSize / (b.mNumberChannels * sizeof(float)))
                return 0;
            const float value =
                static_cast<const float *>(b.mData)[frame * b.mNumberChannels + channel];
            return std::isfinite(value) ? value : 0;
        }
        channel -= b.mNumberChannels;
    }
    return 0;
}
void put(AudioBufferList *list, UInt32 channel, UInt32 frame, float value) {
    for (UInt32 i = 0; i < list->mNumberBuffers; ++i) {
        auto &b = list->mBuffers[i];
        if (channel < b.mNumberChannels) {
            if (b.mData)
                static_cast<float *>(b.mData)[frame * b.mNumberChannels + channel] =
                    std::isfinite(value) ? value : 0;
            return;
        }
        channel -= b.mNumberChannels;
    }
}
void silent(AudioBufferList *output, UInt32 frames) {
    for (UInt32 i = 0; i < output->mNumberBuffers; ++i)
        if (output->mBuffers[i].mData)
            std::memset(output->mBuffers[i].mData, 0,
                        frames * output->mBuffers[i].mNumberChannels * sizeof(float));
}
void require(OSStatus status, const char *operation) {
    if (status)
        throw std::runtime_error(std::string(operation) + " OSStatus=" + std::to_string(status));
}
} // namespace
Context::Context(Layout value, Processor process, void *data, std::shared_ptr<void> owner)
    : layout(std::move(value)), processor(process), processorData(data),
      processorOwner(std::move(owner)) {
    if (!layout.currentCallbackFrames || layout.currentCallbackFrames > layout.maximumCallbackFrames ||
        !layout.maximumCallbackFrames || layout.maximumCallbackFrames > callbackLimit)
        throw std::invalid_argument("Invalid callback frame bounds");
    auto count = [](const std::vector<UInt32> &buffers) {
        if (buffers.empty() || buffers.size() > bufferLimit)
            throw std::invalid_argument("Unsupported buffer count");
        UInt32 sum = 0;
        for (auto channels : buffers) {
            if (!channels || channels > 64 || sum > 64 - channels)
                throw std::invalid_argument("Unsupported channel count");
            sum += channels;
        }
        return sum;
    };
    const auto in = count(layout.inputBuffers), out = count(layout.outputBuffers);
    if (layout.microphoneChannel >= in || layout.monitorLeft >= in || layout.monitorRight >= in ||
        layout.feedChannel >= out || layout.hardwareLeft >= out || layout.hardwareRight >= out ||
        layout.feedChannel == layout.hardwareLeft || layout.feedChannel == layout.hardwareRight ||
        layout.hardwareLeft == layout.hardwareRight || layout.monitorLeft == layout.monitorRight ||
        layout.microphoneChannel == layout.monitorLeft ||
        layout.microphoneChannel == layout.monitorRight)
        throw std::invalid_argument("Invalid route channel map");
}
OSStatus Context::io(AudioObjectID, const AudioTimeStamp *, const AudioBufferList *input,
                     const AudioTimeStamp *inputTime, AudioBufferList *output,
                     const AudioTimeStamp *outputTime, void *data) noexcept {
    if (!data)
        return kAudioHardwareIllegalOperationError;
    auto &c = *static_cast<Context *>(data);
    Count count(c);
    UInt32 frames = 0;
    if (!shape(output, c.layout.outputBuffers, frames)) {
        c.recording->fail(Recording::Failure::invalid_audio);
        return kAudioHardwareBadPropertySizeError;
    }
    silent(output, frames);
    if (frames > c.layout.maximumCallbackFrames) {
        c.recording->fail(Recording::Failure::route_changed);
        c.changed.store(true, std::memory_order_release);
        return kAudioHardwareBadPropertySizeError;
    }
    if (!c.enabled.load(std::memory_order_acquire) || c.changed.load(std::memory_order_acquire))
        return noErr;
    if (c.rendering.test_and_set(std::memory_order_acquire)) {
        c.recording->fail(Recording::Failure::invalid_audio);
        return kAudioHardwareIllegalOperationError;
    }
    struct Release {
        Context &c;
        ~Release() { c.rendering.clear(std::memory_order_release); }
    } release{c};
    const auto recordingGeneration = c.recording->generation();
    UInt32 inputFrames = 0;
    if (!shape(input, c.layout.inputBuffers, inputFrames) || inputFrames != frames ||
        !validTime(inputTime) || !validTime(outputTime)) {
        c.recording->fail(Recording::Failure::invalid_audio);
        return kAudioHardwareIllegalOperationError;
    }
    for (UInt32 f = 0; f < frames; ++f) {
        c.microphone[f] = sample(input, c.layout.microphoneChannel, f);
        c.monitor[2 * f] = sample(input, c.layout.monitorLeft, f);
        c.monitor[2 * f + 1] = sample(input, c.layout.monitorRight, f);
    }
    bool processed = true;
    if (c.processor)
        processed = c.processor(c.processorData, c.microphone.data(), c.monitor.data(),
                                c.processedMicrophone.data(), c.processedMonitor.data(), frames);
    else {
        std::copy_n(c.microphone.data(), frames, c.processedMicrophone.data());
        std::copy_n(c.monitor.data(), frames * 2, c.processedMonitor.data());
    }
    if (!processed) {
        c.recording->fail(Recording::Failure::route_changed);
        c.changed.store(true, std::memory_order_release);
        return noErr;
    }
    const auto controls = c.controls.load();
    for (UInt32 f = 0; f < frames; ++f) {
        put(output, c.layout.feedChannel, f,
            controlledSample(c.processedMicrophone[f], controls.microphone));
        put(output, c.layout.hardwareLeft, f,
            controlledSample(c.processedMonitor[2 * f], controls.speaker));
        put(output, c.layout.hardwareRight, f,
            controlledSample(c.processedMonitor[2 * f + 1], controls.speaker));
    }
    if (!c.enabled.load(std::memory_order_acquire) || c.changed.load(std::memory_order_acquire))
        silent(output, frames);
    else c.recording->capture(c.processedMicrophone.data(), c.processedMonitor.data(), frames,
                             outputTime->mSampleTime, controls, recordingGeneration, inputTime->mSampleTime);
    return noErr;
}
OSStatus Context::change(AudioObjectID, UInt32, const AudioObjectPropertyAddress *,
                         void *data) noexcept {
    if (data) {
        auto &c = *static_cast<Context *>(data);
        Count count(c);
        c.recording->fail(Recording::Failure::route_changed);
        c.changed.store(true, std::memory_order_release);
    }
    return noErr;
}
Session::~Session() {
    // Real backend blocks retain the disabled context until their registered or
    // queued invocations end, even if HAL cleanup fails. No raw-context free.
    (void)stop();
}
bool Session::start(const Selection &selection, Processor processor, void *processorData,
                    std::shared_ptr<void> processorOwner, ControlSnapshot initial, ProcessorFactory factory) {
    if (aggregate_ || context_) {
        error_ = "Session already owns a route or pending cleanup";
        return false;
    }
    error_.clear();
    if (factory && (processor || processorData || processorOwner)) {
        error_ = "Processor factory cannot be combined with an existing processor binding";
        return false;
    }
    if (!initial.valid()) {
        error_ = "Invalid initial controls";
        return false;
    }
    try {
        require(backend_.create(selection, &aggregate_), "create aggregate");
        if (!aggregate_)
            throw std::runtime_error("Backend returned unknown aggregate");
        context_ = std::make_shared<Context>(backend_.inspect(aggregate_, selection), processor,
                                             processorData, std::move(processorOwner));
        context_->controls.publish(initial);
        const auto proposedWatches = backend_.watches(aggregate_, selection);
        watches_.reserve(proposedWatches.size());
        for (const auto &watch : proposedWatches) {
            require(backend_.addWatch(watch, context_), "add listener");
            watches_.push_back(watch);
        }
        if (context_->layout != backend_.inspect(aggregate_, selection) || context_->changed.load())
            throw std::runtime_error("Aggregate changed during preparation");
        if (factory) {
            auto binding = factory(context_->layout);
            if (!binding.processor)
                throw std::runtime_error("Processor factory returned no processor");
            context_->processor = binding.processor;
            context_->processorData = binding.data;
            context_->processorOwner = std::move(binding.owner);
            // Factory startup may take seconds. Revalidate after that wait and
            // before registering any IOProc capable of invoking the processor.
            if (context_->layout != backend_.inspect(aggregate_, selection) || context_->changed.load())
                throw std::runtime_error("Aggregate changed during processor preparation");
        }
        require(backend_.registerIO(aggregate_, context_, &io_), "register IOProc");
        if (!io_)
            throw std::runtime_error("Backend returned null IOProc");
        context_->enabled.store(true, std::memory_order_release);
        startAttempted_ = true;
        require(backend_.start(aggregate_, io_), "start IOProc");
        if (context_->changed.load())
            throw std::runtime_error("Topology changed during start");
        return true;
    } catch (const std::exception &e) {
        const std::string cause = e.what();
        const bool cleaned = stop();
        error_ = cause + (cleaned ? "" : "; cleanup pending: " + error_);
        return false;
    } catch (...) {
        const bool cleaned = stop();
        error_ = std::string("Route preparation threw a nonstandard exception") +
            (cleaned ? "" : "; cleanup pending: " + error_);
        return false;
    }
}
bool Session::publishControls(const ControlSnapshot &value) noexcept {
    return running() && context_->controls.publish(value);
}
bool Session::stop() noexcept {
    if (context_) {
        context_->enabled.store(false, std::memory_order_release);
        context_->recording->requestStop();
    }
    auto failure = [&](OSStatus status, const char *operation) {
        if (!status)
            return false;
        error_ = std::string(operation) + " OSStatus=" + std::to_string(status);
        return true;
    };
    if (startAttempted_) {
        if (failure(backend_.stop(aggregate_, io_), "stop IOProc"))
            return false;
        startAttempted_ = false;
    }
    if (io_) {
        if (failure(backend_.unregisterIO(aggregate_, io_), "unregister IOProc"))
            return false;
        io_ = nullptr;
    }
    while (!watches_.empty()) {
        if (failure(backend_.removeWatch(watches_.back(), context_.get()), "remove listener"))
            return false;
        watches_.pop_back();
    }
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (context_ && context_->callbacks.load(std::memory_order_acquire)) {
        if (std::chrono::steady_clock::now() >= deadline) {
            error_ = "Callback drain timed out";
            return false;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    if (aggregate_) {
        if (failure(backend_.destroy(aggregate_), "destroy aggregate"))
            return false;
        aggregate_ = kAudioObjectUnknown;
    }
    context_.reset();
    return true;
}
bool Session::service() noexcept {
    if (context_ && context_->changed.load(std::memory_order_acquire))
        return stop();
    return true;
}
} // namespace labvoice
