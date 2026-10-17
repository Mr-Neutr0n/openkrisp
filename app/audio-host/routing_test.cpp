#include "noise_adapter.hpp"
#include "routing.hpp"
#include <cassert>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>
#include <thread>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

using namespace labvoice;
namespace {
Layout layout() { return {{2, 1}, {1, 2, 1}, 2, 0, 1, 0, 1, 2, 480, callbackLimit}; }
struct Fake final : Backend {
    std::string fail;
    std::vector<std::string> calls;
    Context *context = nullptr;
    std::shared_ptr<Context> owner;
    bool aggregate = false, registered = false, started = false;
    Layout observed = layout();
    UInt32 listeners = 0;
    bool error(const std::string &operation) {
        calls.push_back(operation);
        return fail == operation;
    }
    OSStatus create(const Selection &, AudioObjectID *id) override {
        if (error("create"))
            return -1;
        aggregate = true;
        *id = 100;
        return fail == "create-after-id" ? -1 : noErr;
    }
    Layout inspect(AudioObjectID, const Selection &) override {
        if (error("inspect"))
            throw std::runtime_error("injected inspect failure");
        return observed;
    }
    std::vector<Watch> watches(AudioObjectID, const Selection &) override {
        return {{100, {kAudioDevicePropertyDeviceIsAlive, kAudioObjectPropertyScopeGlobal, 0}},
                {101, {kAudioDevicePropertyNominalSampleRate, kAudioObjectPropertyScopeGlobal, 0}}};
    }
    OSStatus addWatch(const Watch &, const std::shared_ptr<Context> &c) override {
        if (error(listeners ? "watch2" : "watch1"))
            return -1;
        owner = c;
        context = c.get();
        ++listeners;
        return noErr;
    }
    OSStatus removeWatch(const Watch &, Context *) override {
        if (error("unwatch"))
            return -1;
        assert(listeners);
        --listeners;
        return noErr;
    }
    OSStatus registerIO(AudioObjectID, const std::shared_ptr<Context> &c,
                        AudioDeviceIOProcID *proc) override {
        if (error("register"))
            return -1;
        owner = c;
        context = c.get();
        registered = true;
        *proc = reinterpret_cast<AudioDeviceIOProcID>(uintptr_t(1));
        return fail == "register-after-id" ? -1 : noErr;
    }
    OSStatus start(AudioObjectID, AudioDeviceIOProcID) override {
        if (error("start")) {
            started = true;
            return -1;
        }
        started = true;
        if (fail == "change-at-start")
            Context::change(100, 0, nullptr, context);
        return noErr;
    }
    OSStatus stop(AudioObjectID, AudioDeviceIOProcID) override {
        if (error("stop"))
            return -1;
        started = false;
        return noErr;
    }
    OSStatus unregisterIO(AudioObjectID, AudioDeviceIOProcID) override {
        if (error("unregister"))
            return -1;
        registered = false;
        return noErr;
    }
    OSStatus destroy(AudioObjectID) override {
        if (error("destroy"))
            return -1;
        assert(!registered && !listeners && !started);
        aggregate = false;
        context = nullptr;
        owner.reset();
        return noErr;
    }
};
struct ABL {
    UInt32 count;
    AudioBuffer buffers[bufferLimit];
    AudioBufferList *get() { return reinterpret_cast<AudioBufferList *>(this); }
};
static_assert(offsetof(ABL, buffers) == offsetof(AudioBufferList, mBuffers));
struct Cycle {
    ABL input{}, output{};
    std::vector<std::vector<float>> in, out;
    AudioTimeStamp inputTime{}, outputTime{};
    explicit Cycle(const Layout &l, UInt32 frames) {
        input.count = l.inputBuffers.size();
        output.count = l.outputBuffers.size();
        for (auto channels : l.inputBuffers)
            in.emplace_back(frames * channels);
        for (auto channels : l.outputBuffers)
            out.emplace_back(frames * channels, 0.9f);
        for (UInt32 i = 0; i < input.count; ++i)
            input.buffers[i] = {l.inputBuffers[i], UInt32(in[i].size() * 4), in[i].data()};
        for (UInt32 i = 0; i < output.count; ++i)
            output.buffers[i] = {l.outputBuffers[i], UInt32(out[i].size() * 4), out[i].data()};
        inputTime.mFlags = outputTime.mFlags = kAudioTimeStampSampleTimeValid;
        inputTime.mSampleTime = 100.5;
        outputTime.mSampleTime = 200.5;
    }
    OSStatus run(Context *c) {
        return Context::io(100, nullptr, input.get(), &inputTime, output.get(), &outputTime, c);
    }
    bool zero() const {
        for (const auto &buffer : out)
            for (float v : buffer)
                if (v != 0)
                    return false;
        return true;
    }
};
void samples() {
    for (UInt32 frames : {1u, 15u, 480u, 511u, 4096u}) {
        Context c(layout());
        c.enabled = true;
        Cycle cycle(c.layout, frames);
        for (UInt32 i = 0; i < frames; ++i) {
            cycle.in[0][2 * i] = 0.125f;
            cycle.in[0][2 * i + 1] = -0.25f;
            cycle.in[1][i] = 0.5f;
        }
        assert(cycle.run(&c) == noErr);
        for (UInt32 i = 0; i < frames; ++i) {
            assert(cycle.out[0][i] == 0.5f);
            assert(cycle.out[1][2 * i] == 0.125f);
            assert(cycle.out[1][2 * i + 1] == -0.25f);
            assert(cycle.out[2][i] == 0);
        }
    }
    Layout planes = {{1, 1, 1}, {1, 1, 1, 1}, 2, 0, 1, 0, 1, 2, 480, callbackLimit};
    Context planar(planes);
    planar.enabled = true;
    Cycle p(planes, 15);
    for (UInt32 i = 0; i < 15; ++i) {
        p.in[0][i] = 0.125f;
        p.in[1][i] = -0.25f;
        p.in[2][i] = 0.5f;
    }
    assert(p.run(&planar) == noErr);
    for (UInt32 i = 0; i < 15; ++i) {
        assert(p.out[0][i] == 0.5f);
        assert(p.out[1][i] == 0.125f);
        assert(p.out[2][i] == -0.25f);
        assert(p.out[3][i] == 0);
    }
    Context c(layout());
    c.enabled = true;
    Cycle large(c.layout, 4097);
    assert(large.run(&c) == kAudioHardwareBadPropertySizeError);
    assert(large.out[0][0] == 0.9f && large.out[0].back() == 0.9f);
    Cycle bad(c.layout, 15);
    bad.inputTime.mFlags = 0;
    assert(bad.run(&c) != noErr && bad.zero());
    Cycle missing(c.layout, 15);
    missing.input.buffers[1].mData = nullptr;
    assert(missing.run(&c) == noErr && missing.out[0][0] == 0);
    Cycle nonfinite(c.layout, 15);
    nonfinite.in[1][0] = NAN;
    assert(nonfinite.run(&c) == noErr && nonfinite.out[0][0] == 0);
    Cycle wrong(c.layout, 15);
    wrong.input.buffers[0].mNumberChannels = 1;
    assert(wrong.run(&c) != noErr && wrong.zero());
    c.changed = true;
    Cycle changed(c.layout, 15);
    assert(changed.run(&c) == noErr && changed.zero());
    c.changed = false;
    c.enabled = false;
    Cycle stopped(c.layout, 15);
    assert(stopped.run(&c) == noErr && stopped.zero());
}
void preparationFactory() {
    const Processor process=+[](void *, const float *mic, const float *monitor, float *feed,
                               float *playback, UInt32 count) noexcept {
        std::copy_n(mic,count,feed);std::copy_n(monitor,count*2,playback);return true;
    };
    {
        Fake fake;Session session(fake);unsigned calls=0;std::weak_ptr<int> weak;
        assert(session.start({"microphone","speaker"},nullptr,nullptr,{}, {},[&](const Layout &observed){
            ++calls;assert(observed.currentCallbackFrames==480 && observed.maximumCallbackFrames==callbackLimit);
            assert(fake.aggregate && fake.listeners==2 && !fake.registered && !fake.started && !fake.context->enabled.load());
            assert(std::count(fake.calls.begin(),fake.calls.end(),"inspect")==2);
            auto owner=std::make_shared<int>(7);weak=owner;return ProcessorBinding{process,owner.get(),owner};
        }));
        assert(calls==1 && std::count(fake.calls.begin(),fake.calls.end(),"inspect")==3);
        assert(fake.context->processorData==weak.lock().get());
        fake.fail="stop";assert(!session.stop() && !weak.expired());
        fake.fail.clear();assert(session.stop() && weak.expired());
    }
    for(const std::string mode:{"throw","nonstandard","empty","current","maximum","notification","register","pending"}) {
        Fake fake;Session session(fake);std::weak_ptr<int> weak;
        assert(!session.start({"microphone","speaker"},nullptr,nullptr,{}, {},[&](const Layout &) -> ProcessorBinding {
            assert(!fake.registered && !fake.started);
            if(mode=="throw")throw std::runtime_error("factory failed");
            if(mode=="nonstandard")throw 7;
            auto owner=std::make_shared<int>(1);weak=owner;
            if(mode=="empty")return {};
            if(mode=="current" || mode=="pending")fake.observed.currentCallbackFrames=256;
            if(mode=="maximum")fake.observed.maximumCallbackFrames=1024;
            if(mode=="notification")Context::change(100,0,nullptr,fake.context);
            if(mode=="register")fake.fail="register";
            if(mode=="pending")fake.fail="unwatch";
            return {process,owner.get(),owner};
        }));
        if(mode=="pending") {
            assert(!weak.expired() && !fake.registered && !fake.context->enabled.load());
            fake.fail.clear();assert(session.stop());
        }
        assert(!fake.aggregate && !fake.registered && !fake.started && !fake.listeners && weak.expired());
        if(mode!="register")assert(std::find(fake.calls.begin(),fake.calls.end(),"register")==fake.calls.end());
    }
    for(unsigned mode=0;mode<3;++mode) {
        Fake fake;Session session(fake);bool called=false;auto owner=std::make_shared<int>(1);
        assert(!session.start({"microphone","speaker"},mode==0?process:nullptr,
            mode==1?owner.get():nullptr,mode==2?owner:std::shared_ptr<void>{}, {},
            [&](const Layout &){called=true;return ProcessorBinding{};}));
        assert(!called && fake.calls.empty());
    }
    for(unsigned mode=0;mode<4;++mode) {
        auto invalid=layout();
        if(mode==0)invalid.currentCallbackFrames=0;
        if(mode==1)invalid.maximumCallbackFrames=0;
        if(mode==2)invalid.maximumCallbackFrames=479;
        if(mode==3)invalid.maximumCallbackFrames=callbackLimit+1;
        bool rejected=false;try{Context context(invalid);}catch(const std::invalid_argument &){rejected=true;}
        assert(rejected);
    }
    auto bounded=layout();bounded.maximumCallbackFrames=480;
    Context context(bounded,process);context.enabled=true;
    Cycle oversized(bounded,481);assert(oversized.run(&context)!=noErr && oversized.zero() && context.changed.load());
}
void failures() {
    for (const auto &fail : {"create", "create-after-id", "inspect", "watch1", "watch2", "register",
                             "register-after-id", "start", "change-at-start"}) {
        Fake fake;
        fake.fail = fail;
        Session session(fake);
        assert(!session.start({"microphone", "speaker"}));
        assert(!fake.aggregate && !fake.registered && !fake.started && !fake.listeners);
        assert(!session.running() && !session.error().empty());
        assert(session.stop());
    }
    for (const auto &fail : {"stop", "unregister", "unwatch", "destroy"}) {
        Fake fake;
        Session session(fake);
        assert(session.start({"microphone", "speaker"}));
        fake.fail = fail;
        auto *context = fake.context;
        assert(!session.stop() && !session.running());
        assert(fake.aggregate && !session.error().empty());
        if (fake.registered) {
            Cycle late(context->layout, 15);
            assert(late.run(context) == noErr && late.zero());
        }
        fake.fail.clear();
        assert(session.stop());
        assert(!fake.aggregate && !fake.registered && !fake.started && !fake.listeners);
    }
    Fake fake;
    Session session(fake);
    assert(session.start({"microphone", "speaker"}));
    Context::change(100, 0, nullptr, fake.context);
    assert(!session.running());
    assert(session.service());
    assert(!fake.aggregate);
    assert(session.start({"microphone", "speaker"}));
    assert(session.stop());
}
bool failProcess(void *, const float *, const float *, float *, float *, UInt32) noexcept {
    return false;
}
void queuedLifetime() {
    Fake fake;
    Session session(fake);
    assert(session.start({"microphone", "speaker"}));
    auto queued = fake.owner;
    Cycle cycle(queued->layout, 15);
    assert(session.stop());
    assert(!fake.owner && queued.use_count() == 1);
    // Models a copied HAL block already queued before listener/IO removal.
    assert(cycle.run(queued.get()) == noErr && cycle.zero());
    Context::change(100, 0, nullptr, queued.get());
    assert(queued->changed.load());
    Context fail(layout(), failProcess);
    fail.enabled = true;
    Cycle failure(fail.layout, 15);
    assert(failure.run(&fail) == noErr && failure.zero() && fail.changed.load());
    Fake cleanup;
    {
        Session active(cleanup);
        assert(active.start({"microphone", "speaker"}));
        cleanup.fail = "unregister";
    }
    assert(cleanup.owner && !cleanup.owner->enabled.load());
    Cycle afterDestructor(cleanup.owner->layout, 15);
    assert(afterDestructor.run(cleanup.owner.get()) == noErr && afterDestructor.zero());
}
struct Barrier {
    std::atomic<bool> entered{false}, release{false};
};
bool pause(void *value, const float *, const float *, float *mic, float *speaker,
           UInt32 frames) noexcept {
    auto &b = *static_cast<Barrier *>(value);
    b.entered = true;
    while (!b.release.load())
        std::this_thread::yield();
    for (UInt32 i = 0; i < frames; ++i) {
        mic[i] = 0.75f;
        speaker[2 * i] = 0.5f;
        speaker[2 * i + 1] = -0.5f;
    }
    return true;
}
void drain() {
    Fake fake;
    Session session(fake);
    Barrier barrier;
    assert(session.start({"microphone", "speaker"}, pause, &barrier));
    auto *context = fake.context;
    Cycle cycle(context->layout, 15);
    std::thread callback([&] { assert(cycle.run(context) == noErr); });
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (!barrier.entered.load()) {
        assert(std::chrono::steady_clock::now() < deadline);
        std::this_thread::yield();
    }
    bool stopped = false;
    std::thread control([&] { stopped = session.stop(); });
    while (context->enabled.load()) {
        assert(std::chrono::steady_clock::now() < deadline);
        std::this_thread::yield();
    }
    // Callback is still paused, so its context must stay alive until the drain completes.
    assert(context->callbacks.load() == 1);
    barrier.release = true;
    callback.join();
    control.join();
    assert(stopped && !fake.aggregate && cycle.zero());
}
struct OwnedPause {
    std::atomic<bool> entered{false}, release{false};
    std::atomic<bool> *destroyed;
    explicit OwnedPause(std::atomic<bool> &flag) : destroyed(&flag) {}
    ~OwnedPause() { destroyed->store(true); }
    static bool process(void *value, const float *, const float *, float *mono, float *stereo,
                        UInt32 frames) noexcept {
        auto &self = *static_cast<OwnedPause *>(value);
        self.entered.store(true);
        while (!self.release.load())
            std::this_thread::yield();
        for (UInt32 i = 0; i < frames; ++i) {
            mono[i] = 0.5f;
            stereo[2 * i] = 0.25f;
            stereo[2 * i + 1] = -0.25f;
        }
        return true;
    }
};
void processorOwnership() {
    Fake fake;
    std::atomic<bool> destroyed{false};
    auto processor = std::make_shared<OwnedPause>(destroyed);
    std::weak_ptr<OwnedPause> weak = processor;
    auto *rawProcessor = processor.get();
    auto session = std::make_unique<Session>(fake);
    assert(
        session->start({"microphone", "speaker"}, OwnedPause::process, processor.get(), processor));
    auto *context = fake.context;
    Cycle cycle(context->layout, 15);
    std::thread callback([&] { assert(cycle.run(context) == noErr); });
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (!rawProcessor->entered.load()) {
        assert(std::chrono::steady_clock::now() < deadline);
        std::this_thread::yield();
    }
    fake.fail = "stop";
    session.reset();   // Persistent stop failure, destructor cannot drain/unregister.
    processor.reset(); // External application owner is now gone.
    assert(!weak.expired() && !destroyed.load() && !context->enabled.load());
    rawProcessor->release.store(true);
    callback.join();
    assert(cycle.zero());
    assert(!weak.expired() && !destroyed.load());
    fake.fail.clear();
    assert(fake.stop(100, reinterpret_cast<AudioDeviceIOProcID>(uintptr_t(1))) == noErr);
    assert(fake.unregisterIO(100, reinterpret_cast<AudioDeviceIOProcID>(uintptr_t(1))) == noErr);
    Watch watch{100, {kAudioDevicePropertyDeviceIsAlive, kAudioObjectPropertyScopeGlobal, 0}};
    assert(fake.removeWatch(watch, context) == noErr);
    assert(fake.removeWatch(watch, context) == noErr);
    assert(fake.destroy(100) == noErr);
    assert(weak.expired() && destroyed.load());
}
struct AdvancingProcessor {
    UInt32 calls = 0;
};
bool advance(void *data, const float *, const float *, float *microphone, float *speaker,
             UInt32 frames) noexcept {
    auto &state = *static_cast<AdvancingProcessor *>(data);
    ++state.calls;
    for (UInt32 i = 0; i < frames; ++i) {
        microphone[i] = float(state.calls);
        speaker[2 * i] = 2 * float(state.calls);
        speaker[2 * i + 1] = -2 * float(state.calls);
    }
    return true;
}
void liveControls() {
    Context context(layout());
    context.enabled = true;
    assert(context.controls.publish({{0.5f, false}, {0.25f, false}}));
    Cycle cycle(context.layout, 15);
    for (UInt32 i = 0; i < 15; ++i) {
        cycle.in[1][i] = 0.8f;
        cycle.in[0][2 * i] = 0.4f;
        cycle.in[0][2 * i + 1] = -0.4f;
    }
    assert(cycle.run(&context) == noErr);
    for (UInt32 i = 0; i < 15; ++i) {
        assert(cycle.out[0][i] == 0.4f);
        assert(cycle.out[1][2 * i] == 0.1f);
        assert(cycle.out[1][2 * i + 1] == -0.1f);
    }
    const auto prior = context.controls.load();
    assert(!context.controls.publish({{NAN, false}, {1, false}}));
    assert(context.controls.load() == prior);
    assert(context.controls.publish({{1, true}, {1, true}}));
    assert(cycle.run(&context) == noErr && cycle.zero());
    assert(controlledSample(NAN, {1, true}) == 0 && controlledSample(INFINITY, {1, false}) == 0);
    AdvancingProcessor processor;
    Context progressing(layout(), advance, &processor);
    progressing.enabled = true;
    assert(progressing.controls.publish({{1, true}, {1, true}}));
    Cycle advancing(progressing.layout, 15);
    assert(advancing.run(&progressing) == noErr && advancing.zero() && processor.calls == 1);
    assert(progressing.controls.publish({{0.5f, false}, {0.25f, false}}));
    assert(advancing.run(&progressing) == noErr && processor.calls == 2);
    assert(advancing.out[0][0] == 1 && advancing.out[1][0] == 1 && advancing.out[1][1] == -1);
    // Startup snapshot is installed before the fake backend starts callbacks.
    Fake fake;
    Session session(fake);
    assert(session.start({"microphone", "speaker"}, nullptr, nullptr, {},
                         {{0.25f, true}, {0.75f, false}}));
    assert(fake.context->controls.load() == ControlSnapshot({{0.25f, true}, {0.75f, false}}));
    assert(session.publishControls({{0.5f, false}, {0.5f, true}}));
    assert(session.stop());
    assert(!session.publishControls({}));
    Fake invalid;
    Session invalidSession(invalid);
    assert(!invalidSession.start({"microphone", "speaker"}, nullptr, nullptr, {},
                                 {{2, false}, {1, false}}));
    assert(invalid.calls.empty());
}
void publicationDuringProcessing() {
    Barrier barrier;
    Context context(layout(), pause, &barrier);
    context.enabled = true;
    const ControlSnapshot a{{0.25f, false}, {0.75f, true}}, b{{0.75f, true}, {0.25f, false}};
    assert(context.controls.publish(a));
    Cycle cycle(context.layout, 15);
    std::thread callback([&] { assert(cycle.run(&context) == noErr); });
    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (!barrier.entered.load()) {
        assert(std::chrono::steady_clock::now() < deadline);
        std::this_thread::yield();
    }
    assert(context.controls.publish(b));
    barrier.release = true;
    callback.join();
    const float microphone = cycle.out[0][0], speaker = cycle.out[1][0];
    assert((microphone == 0.1875f && speaker == 0) || (microphone == 0 && speaker == 0.125f));
    for (UInt32 i = 0; i < 15; ++i) {
        assert(cycle.out[0][i] == microphone);
        assert(cycle.out[1][2 * i] == speaker && cycle.out[1][2 * i + 1] == -speaker);
    }
    assert(cycle.run(&context) == noErr);
    for (UInt32 i = 0; i < 15; ++i) {
        assert(cycle.out[0][i] == 0);
        assert(cycle.out[1][2 * i] == 0.125f && cycle.out[1][2 * i + 1] == -0.125f);
    }
}
void simultaneousSnapshot() {
    Context context(layout());
    context.enabled = true;
    const ControlSnapshot a{{0.25f, false}, {0.75f, true}}, b{{0.75f, true}, {0.25f, false}};
    assert(context.controls.publish(a));
    std::atomic<bool> stop{false};
    std::thread updates([&] {
        while (!stop.load()) {
            context.controls.publish(a);
            context.controls.publish(b);
        }
    });
    for (int iteration = 0; iteration < 128; ++iteration) {
        Cycle cycle(context.layout, 127);
        for (auto &buffer : cycle.in)
            for (float &value : buffer)
                value = 1;
        assert(cycle.run(&context) == noErr);
        const float microphone = cycle.out[0][0], speaker = cycle.out[1][0];
        assert((microphone == 0.25f && speaker == 0) || (microphone == 0 && speaker == 0.25f));
        for (UInt32 i = 0; i < 127; ++i) {
            assert(cycle.out[0][i] == microphone);
            assert(cycle.out[1][2 * i] == speaker && cycle.out[1][2 * i + 1] == speaker);
        }
    }
    stop = true;
    updates.join();
}
void recordingPausedCallback() {
    char directory[] = "/tmp/labvoice-pause-record-XXXXXX";
    assert(mkdtemp(directory)); assert(chmod(directory, 0700) == 0);
    const auto path = std::string(directory) + "/pause.wav";
    Barrier barrier;
    Context context(layout(), pause, &barrier);
    context.enabled = true;
    auto recording = context.recording;
    std::string error;
    assert(recording->start(path, error));
    Cycle cycle(context.layout, 15);
    std::thread callback([&] { assert(cycle.run(&context) == noErr); });
    while (!barrier.entered.load()) std::this_thread::yield();
    assert(recording->pause() && recording->resume());
    barrier.release = true;
    callback.join(); // Old callback must not be captured after resume.
    cycle.outputTime.mSampleTime += 15;
    assert(cycle.run(&context) == noErr);
    recording->requestStop();
    while (!recording->ready()) std::this_thread::sleep_for(std::chrono::milliseconds(1));
    auto result = recording->finish();
    assert(result.completed && result.frames == 15);
    unlink(path.c_str()); rmdir(directory);
}
void callbackRecording() {
    char directory[] = "/tmp/labvoice-route-record-XXXXXX";
    assert(mkdtemp(directory)); assert(chmod(directory, 0700) == 0);
    const auto path = std::string(directory) + "/callback.wav";
    Fake backend;
    Session session(backend);
    assert(session.start({"input", "output"}));
    auto recording = session.recordingOwner();
    std::string error;
    assert(recording->start(path, error));
    assert(session.publishControls({{1,true},{.5f,false}}));
    Cycle cycle(backend.context->layout, 4);
    for (auto &buffer : cycle.in) for (float &v : buffer) v = 1;
    assert(cycle.run(backend.context) == noErr);
    assert(cycle.out[0][0] == 0 && cycle.out[1][0] == .5f);
    // Paused recording remains a pending job. Topology failure must fail it.
    assert(recording->pause());
    // Topology failure propagates to recording and owner survives Context release.
    Context::change(100, 0, nullptr, backend.context);
    assert(session.service());
    recording->requestStop();
    while (!recording->ready()) std::this_thread::sleep_for(std::chrono::milliseconds(1));
    auto result = recording->finish();
    assert(!result.completed && result.error == "route_changed_or_processor_failed");
    unlink(path.c_str()); rmdir(directory);
}
void noise() {
    for (auto mode : {std::pair{true, false}, std::pair{false, true}, std::pair{false, false}}) {
        NoiseAdapter adapter(mode.first, mode.second);
        Context c(layout(), NoiseAdapter::process, &adapter);
        c.enabled = true;
        Cycle cycle(c.layout, 480);
        for (UInt32 i = 0; i < 480; ++i) {
            cycle.in[1][i] = 0.1f * std::sin(i * 0.2f);
            cycle.in[0][2 * i] = 0.2f * std::sin(i * 0.15f);
            cycle.in[0][2 * i + 1] = -0.15f * std::sin(i * 0.12f);
        }
        assert(cycle.run(&c) == noErr);
        for (UInt32 i = 0; i < 480; ++i) {
            assert(cycle.out[0][i] == (mode.first ? 0 : cycle.in[1][i]));
            assert(cycle.out[1][2 * i] == (mode.second ? 0 : cycle.in[0][2 * i]));
            assert(cycle.out[1][2 * i + 1] == (mode.second ? 0 : cycle.in[0][2 * i + 1]));
        }
        assert(cycle.run(&c) == noErr);
        for (const auto &b : cycle.out)
            for (float value : b)
                assert(std::isfinite(value));
    }
}
} // namespace
int main() {
    samples();
    callbackRecording();
    recordingPausedCallback();
    failures();
    preparationFactory();
    queuedLifetime();
    drain();
    noise();
    liveControls();
    simultaneousSnapshot();
    publicationDuringProcessing();
    processorOwnership();
    std::cout << "PASS: injected routing mono/stereo/planar, bounds/silence, partial-start "
                 "rollback, cleanup retries, topology stop, concurrent callback drain/queued "
                 "lifetime, processor failure silence, processor lifetime after persistent stop "
                 "failure, post-DSP controls/state advance/atomic snapshots, actual RNNoise "
                 "optional buffering. No real "
                 "aggregate or audio started.\n";
}
