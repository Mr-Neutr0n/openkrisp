#include "call_capture.hpp"
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstring>
#include <mutex>
#include <set>
#include <thread>
#include <unistd.h>

namespace labvoice {
bool validateCallCaptureTarget(const CallCaptureTarget& target, const AudioProcessSnapshot& snapshot, std::string& error) {
    if (target.responsiblePID <= 0 || target.responsiblePID == getpid() || target.appID.empty() || target.appID.size() > 4096 || target.appID.find('\0') != std::string::npos || target.processes.empty() || target.processes.size() > 32) {
        error = "invalid_selected_capture_target"; return false;
    }
    if (snapshot.status != "available") { error = "selected_capture_identity_unavailable"; return false; }
    std::set<AudioObjectID> objects;
    std::set<int> pids;
    for (const auto& selected : target.processes) {
        if (!selected.objectID || selected.actualPID <= 0 || selected.actualPID == getpid() || !objects.insert(selected.objectID).second || !pids.insert(selected.actualPID).second) {
            error = "invalid_or_duplicate_selected_process"; return false;
        }
        const AudioProcessUsage* match = nullptr;
        for (const auto& process : snapshot.processes) if (process.objectID == selected.objectID) {
            if (match) { error = "ambiguous_selected_process_object"; return false; }
            match = &process;
        }
        // The observer validates clnt class and PID before setting actualPID.
        // Fallback responsibility cannot admit a capture target.
        if (!match || match->actualPID != selected.actualPID || match->responsiblePID != target.responsiblePID || match->responsibleFallback || match->appID != target.appID || match->output.running != true || !match->output.devices || match->output.devices->empty() || match->usageStale == true || match->stabilizationPending == true) {
            error = "selected_capture_identity_changed_or_incomplete"; return false;
        }
    }
    return true;
}
bool supportedCallCaptureFormat(const AudioStreamBasicDescription& f) noexcept {
    const auto allowed = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsNonMixable;
    const bool planar = (f.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
    return f.mFormatID == kAudioFormatLinearPCM && (f.mFormatFlags & ~allowed) == 0 &&
        (f.mFormatFlags & (kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked)) == (kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked) &&
        std::isfinite(f.mSampleRate) && f.mSampleRate >= 8000 && f.mSampleRate <= 192000 && f.mChannelsPerFrame == 2 &&
        f.mBitsPerChannel == 32 && f.mFramesPerPacket == 1 && f.mBytesPerFrame == (planar ? 4 : 8) && f.mBytesPerPacket == f.mBytesPerFrame;
}
bool callCaptureSourceFramesFitWav(uint64_t frames, double rate) noexcept {
    return std::isfinite(rate) && rate >= 8000 && rate <= 192000 &&
        std::ceil(static_cast<long double>(frames) * 48000 / rate) <= callCaptureWavMaximumFrames;
}
struct CallCaptureSession::State {
    static constexpr uint64_t slots = 32;
    static constexpr uint32_t maxFrames = 4096;
    struct Block { std::array<float, maxFrames * 2> samples{}; uint32_t frames = 0; AudioTimeStamp time{}; };
    Observe observe;
    CallCaptureTarget target;
    std::function<bool()> cancellation;
    std::unique_ptr<CallCaptureDriver> driver;
    std::unique_ptr<CallCaptureWriter> writer;
    std::unique_ptr<CallCaptureMicrophone> microphone;
    double hostTicksPerSecond=0;
    struct LaneQueue {
        std::array<Block,slots> blocks{};
        std::atomic<uint64_t> produced{0},consumed{0};
        std::atomic_flag producer=ATOMIC_FLAG_INIT;
    };
    LaneQueue appQueue,micQueue;
    struct InputContext{State* state;bool microphone;};
    InputContext appContext{this,false},micContext{this,true};
    std::atomic<unsigned> callbacks{0};
    std::atomic<bool> active{false}, finishing{false};
    std::atomic<unsigned> failure{0};
    bool micRegistered=false,micStarted=false;
    bool used = false, tapped = false, aggregated = false, registered = false, started = false, writerOpen = false, stopped = false;
    AudioStreamBasicDescription format{};
    std::thread worker;
    CallCaptureResult result;
    void fail(unsigned reason) noexcept { unsigned zero = 0; failure.compare_exchange_strong(zero, reason); active.store(false, std::memory_order_release); }
    bool cancelled() noexcept {
        try { return cancellation && cancellation(); }
        catch (...) { fail(8); return true; }
    }
    static void input(void* pointer,const AudioBufferList* buffers,const AudioTimeStamp* time) noexcept {
        auto& context=*static_cast<InputContext*>(pointer);auto& s=*context.state;
        auto& queue=context.microphone?s.micQueue:s.appQueue;
        s.callbacks.fetch_add(1,std::memory_order_acq_rel);
        if(!s.active.load(std::memory_order_acquire)){s.callbacks.fetch_sub(1);return;}
        if(s.cancelled()){s.active.store(false,std::memory_order_release);s.callbacks.fetch_sub(1);return;}
        if(queue.producer.test_and_set(std::memory_order_acquire)){s.fail(1);s.callbacks.fetch_sub(1);return;}
        const auto finish=[&]{queue.producer.clear(std::memory_order_release);s.callbacks.fetch_sub(1,std::memory_order_release);};
        if(!buffers||!time||(time->mFlags&(kAudioTimeStampSampleTimeValid|kAudioTimeStampHostTimeValid))!=(kAudioTimeStampSampleTimeValid|kAudioTimeStampHostTimeValid)||!std::isfinite(time->mSampleTime)){s.fail(2);finish();return;}
        const bool planar=!context.microphone&&(s.format.mFormatFlags&kAudioFormatFlagIsNonInterleaved);
        const UInt32 expected=context.microphone?UInt32(s.result.microphone.channels.size()):(planar?2U:1U);
        if(!expected||buffers->mNumberBuffers!=expected){s.fail(2);finish();return;}
        uint32_t frames=0;
        for(UInt32 i=0;i<expected;++i){
            const auto& buffer=buffers->mBuffers[i];const auto channels=context.microphone?s.result.microphone.channels[i]:(planar?1U:2U);
            if(!channels||channels>64||!buffer.mData||buffer.mNumberChannels!=channels||buffer.mDataByteSize%(channels*4)){s.fail(2);finish();return;}
            const auto count=buffer.mDataByteSize/(channels*4);
            if(!count||count>maxFrames||(i&&count!=frames)){s.fail(2);finish();return;}frames=count;
        }
        const auto w=queue.produced.load(std::memory_order_relaxed);
        if(w-queue.consumed.load(std::memory_order_acquire)>=slots){s.fail(3);finish();return;}
        auto& block=queue.blocks[w%slots];block.frames=frames;block.time=*time;
        if(context.microphone){const auto* values=static_cast<const float*>(buffers->mBuffers[0].mData);const auto stride=s.result.microphone.channels[0];for(uint32_t i=0;i<frames;++i)block.samples[i]=values[i*stride];}
        else{std::memcpy(block.samples.data(),buffers->mBuffers[0].mData,buffers->mBuffers[0].mDataByteSize);if(planar)std::memcpy(block.samples.data()+maxFrames,buffers->mBuffers[1].mData,buffers->mBuffers[1].mDataByteSize);}
        queue.produced.store(w+1,std::memory_order_release);finish();
    }
    void runApp() noexcept {
        try {
            std::array<float, maxFrames * 2> interleaved{};
            bool clock = false; double next = 0; uint64_t host = 0;
            while (!finishing.load(std::memory_order_acquire) || appQueue.consumed.load() != appQueue.produced.load(std::memory_order_acquire)) {
                const auto r = appQueue.consumed.load(std::memory_order_relaxed);
                if (r == appQueue.produced.load(std::memory_order_acquire)) { std::this_thread::sleep_for(std::chrono::milliseconds(2)); continue; }
                const auto& block = appQueue.blocks[r % slots];
                if (clock && (std::abs(block.time.mSampleTime - next) > 0.5 || block.time.mHostTime <= host)) fail(4);
                if (!clock) { result.firstSampleTime = block.time.mSampleTime; result.firstHostTime = block.time.mHostTime; clock = true; }
                result.lastSampleTime = block.time.mSampleTime; result.lastHostTime = block.time.mHostTime;
                next = block.time.mSampleTime + block.frames; host = block.time.mHostTime;
                const bool planar = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0;
                for (uint32_t i = 0; i < block.frames; ++i) for (uint32_t c = 0; c < 2; ++c) {
                    const auto sample = block.samples[planar ? c * maxFrames + i : 2 * i + c];
                    if (!std::isfinite(sample)) fail(2);
                    interleaved[2 * i + c] = sample;
                }
                if (!callCaptureSourceFramesFitWav(result.sourceFrames + block.frames, format.mSampleRate)) fail(6);
                // Cancellation is linearized at callback admission. Drain already
                // admitted frames on normal Stop; identity/format failures still
                // suppress writes through failure.
                if (!failure.load() && !writer->write(interleaved.data(), block.frames, result.error)) fail(5);
                result.sourceFrames += block.frames;
                appQueue.consumed.store(r + 1, std::memory_order_release);
            }
        } catch (...) { fail(5); }
    }
    void runDual() noexcept {
        try {
            CallCaptureTimeline timeline(format.mSampleRate,hostTicksPerSecond,[&](const float* data,uint32_t frames,std::string& error){return !failure.load()&&writer->write(data,frames,error);});
            std::array<float,maxFrames*2> stereo{};
            while(!finishing.load(std::memory_order_acquire)||appQueue.consumed.load()!=appQueue.produced.load(std::memory_order_acquire)||micQueue.consumed.load()!=micQueue.produced.load(std::memory_order_acquire)){
                bool progressed=false;
                for(bool mic:{false,true}){
                    auto& queue=mic?micQueue:appQueue;const auto r=queue.consumed.load(std::memory_order_relaxed);
                    if(r==queue.produced.load(std::memory_order_acquire))continue;
                    const auto& block=queue.blocks[r%slots];
                    if(!failure.load()){
                        if(mic){if(!timeline.append(true,block.samples.data(),block.frames,block.time,result.error))fail(9);}
                        else{
                            const bool planar=(format.mFormatFlags&kAudioFormatFlagIsNonInterleaved)!=0;
                            for(uint32_t i=0;i<block.frames;++i)for(uint32_t c=0;c<2;++c)stereo[2*i+c]=block.samples[planar?c*maxFrames+i:2*i+c];
                            if(result.sourceFrames==0){result.firstHostTime=block.time.mHostTime;result.firstSampleTime=block.time.mSampleTime;}
                            result.lastHostTime=block.time.mHostTime;result.lastSampleTime=block.time.mSampleTime;result.sourceFrames+=block.frames;
                            if(!timeline.append(false,stereo.data(),block.frames,block.time,result.error))fail(9);
                        }
                    }
                    queue.consumed.store(r+1,std::memory_order_release);progressed=true;
                }
                if(!progressed)std::this_thread::sleep_for(std::chrono::milliseconds(2));
            }
            if(!failure.load()&&!timeline.finish(result.timeline,result.error))fail(9);
        }catch(...){fail(9);}
    }
    void run() noexcept {if(microphone)runDual();else runApp();}

};
static_assert(std::atomic<uint64_t>::is_always_lock_free && std::atomic<unsigned>::is_always_lock_free && std::atomic<bool>::is_always_lock_free);
CallCaptureSession::CallCaptureSession(Observe observe, std::unique_ptr<CallCaptureDriver> driver, std::unique_ptr<CallCaptureWriter> writer,std::unique_ptr<CallCaptureMicrophone> microphone,double hostTicksPerSecond) : state_(std::make_shared<State>()) {
    state_->observe = std::move(observe); state_->driver = std::move(driver); state_->writer = std::move(writer);state_->microphone=std::move(microphone);state_->hostTicksPerSecond=hostTicksPerSecond;
}
CallCaptureSession::~CallCaptureSession() {
    const auto result = stop();
    if (!result.cleanupVerified) {
        // HAL may still own the callback pointer. Retain it for process lifetime.
        static auto* retained = new std::vector<std::shared_ptr<State>>;
        static auto* mutex = new std::mutex;
        std::lock_guard guard(*mutex); retained->push_back(state_);
    }
}
bool CallCaptureSession::start(const CallCaptureTarget& target, const std::string& path, std::string& error, std::function<bool()> cancelled) {
    auto& s = *state_;
    if (s.used || !s.driver || !s.writer || !s.observe) { error = "selected_capture_session_not_reusable"; return false; }
    s.used = true; s.result.path = path; s.target = target; s.cancellation = std::move(cancelled);
    const auto failed = [&] { s.result.error = error; return false; };
    const auto cancelledNow = [&] {
        if (!s.cancelled()) return false;
        error = "selected_capture_cancelled"; return true;
    };
    try {
        if (cancelledNow() || !validateCallCaptureTarget(target, s.observe(), error) || cancelledNow()) return failed();
        // Mark attempted acquisitions too: failed HAL calls may return an owned ID.
        s.tapped = true;
        if (!s.driver->createTap(target, s.format, error) || cancelledNow()) return failed();
        s.result.sourceFormat = s.format;
        if (!supportedCallCaptureFormat(s.format)) { error = "unsupported_selected_capture_source_format"; return failed(); }
        if(s.microphone){
            if(!std::isfinite(s.hostTicksPerSecond)||s.hostTicksPerSecond<=0){error="invalid_host_clock_frequency";return failed();}
            if(!s.microphone->prepare(s.result.microphone,error)||cancelledNow())return failed();
            const auto& mic=s.result.microphone;const auto& f=mic.format;
            bool valid=mic.objectID&&!mic.uid.empty()&&mic.uid.size()<=4096&&mic.uid.find('\0')==std::string::npos&&!mic.channels.empty()&&mic.channels.size()<=16&&!mic.streams.empty()&&mic.streams.size()<=16;
            for(auto channels:mic.channels)valid=valid&&channels>0&&channels<=64;
            for(auto stream:mic.streams)valid=valid&&stream!=0;
            valid=valid&&f.mSampleRate==48000&&f.mFormatID==kAudioFormatLinearPCM&&f.mFormatFlags==(kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked)&&f.mChannelsPerFrame==1&&f.mBitsPerChannel==32&&f.mFramesPerPacket==1&&f.mBytesPerFrame==4&&f.mBytesPerPacket==4;
            if(!valid){error="unsupported_call_microphone_spec";return failed();}
        }
        auto writerFormat=s.format;
        if(s.microphone){writerFormat.mSampleRate=48000;writerFormat.mFormatID=kAudioFormatLinearPCM;writerFormat.mFormatFlags=kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked;writerFormat.mChannelsPerFrame=2;writerFormat.mBitsPerChannel=32;writerFormat.mFramesPerPacket=1;writerFormat.mBytesPerPacket=writerFormat.mBytesPerFrame=8;}
        s.writerOpen = true;
        if (!s.writer->open(path, writerFormat, error) || cancelledNow()) return failed();
        s.aggregated = true;
        if (!s.driver->createAggregate(error) || cancelledNow()) return failed();
        s.registered = true;
        if (!s.driver->registerIO(State::input, &s.appContext, error) || cancelledNow()) return failed();
        if(s.microphone&&!s.micRegistered){s.micRegistered=true;if(!s.microphone->registerIO(State::input,&s.micContext,error)||cancelledNow())return failed();}
        if (!validateCallCaptureTarget(target, s.observe(), error) || !s.driver->validateFormat(s.format, error) || (s.microphone&&!s.microphone->validate(s.result.microphone,error)) || cancelledNow()) return failed();
        s.worker = std::thread([state = state_] { state->run(); });
        // AudioDeviceStart may block on OS admission. Its early callbacks are
        // discarded until successful return, fresh identity/format validation
        // and a cancellation check.
        if (cancelledNow()) return failed();
        s.started = true;
        if (!s.driver->start(error) || cancelledNow()) return failed();
        if(s.microphone){s.micStarted=true;if(!s.microphone->start(error)||cancelledNow())return failed();}
        // A permission wait can outlive the original process or format. Never
        // admit its early callbacks or rely on the desktop watcher's timing.
        if (!validateCallCaptureTarget(target, s.observe(), error) || !s.driver->validateFormat(s.format, error) || (s.microphone&&!s.microphone->validate(s.result.microphone,error)) || cancelledNow()) return failed();
        s.active.store(true, std::memory_order_release);
        return true;
    } catch (...) { error = "selected_capture_start_exception"; return failed(); }
}
bool CallCaptureSession::validateCurrentTarget(std::string& error) {
    auto& s = *state_;
    const auto cancelled = [&] {
        if (!s.cancelled()) return false;
        s.active.store(false, std::memory_order_release); error = "selected_capture_cancelled"; return true;
    };
    if (cancelled()) return false;
    if (!healthy()) { error = "selected_capture_not_active"; return false; }
    try {
        const bool valid = validateCallCaptureTarget(s.target, s.observe(), error) && s.driver->validateFormat(s.format, error) && (!s.microphone||s.microphone->validate(s.result.microphone,error));
        if (cancelled()) return false;
        if (valid) return true;
    } catch (...) { error = "selected_capture_identity_observation_failed"; }
    if (cancelled()) return false;
    s.fail(7); return false;
}
bool CallCaptureSession::healthy() const noexcept { return state_->active.load() && state_->failure.load() == 0; }
AudioStreamBasicDescription CallCaptureSession::sourceFormat() const { return state_->format; }
CallCaptureMicrophoneSpec CallCaptureSession::microphoneSpec() const {return state_->result.microphone;}
CallCaptureResult CallCaptureSession::stop() {
    auto& s = *state_;
    if (s.stopped) return s.result;
    s.active.store(false, std::memory_order_release);
    bool appSafe=true,micSafe=true;
    const auto cleanup=[&](const char* name,bool needed,bool& safe,auto operation){if(!needed||!safe)return;std::string error;if(!operation(error)){s.result.cleanup.push_back(std::string(name)+": "+error);safe=false;}else s.result.cleanup.push_back(std::string(name)+": verified");};
    // Both sources must receive Stop even if the other source cannot verify it.
    cleanup("stop",s.started,appSafe,[&](auto&e){return s.driver->stop(e);});
    cleanup("stop_microphone",s.micStarted,micSafe,[&](auto&e){return s.microphone->stop(e);});
    const auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(2);
    while(s.callbacks.load(std::memory_order_acquire)&&std::chrono::steady_clock::now()<deadline)std::this_thread::sleep_for(std::chrono::milliseconds(1));
    if(s.callbacks.load()){appSafe=micSafe=false;s.result.cleanup.push_back("callback_drain: timeout");}
    cleanup("unregister_microphone",s.micRegistered,micSafe,[&](auto&e){return s.microphone->unregisterIO(e);});
    cleanup("unregister_io",s.registered,appSafe,[&](auto&e){return s.driver->unregisterIO(e);});
    cleanup("destroy_aggregate",s.aggregated,appSafe,[&](auto&e){return s.driver->destroyAggregate(e);});
    cleanup("destroy_tap",s.tapped,appSafe,[&](auto&e){return s.driver->destroyTap(e);});
    const bool safe=appSafe&&micSafe;
    s.finishing.store(true, std::memory_order_release);
    if (s.worker.joinable()) s.worker.join();
    if (s.writerOpen && !s.writer->close(s.result.frames, s.result.error)) s.fail(5);
    if(s.microphone&&!s.failure.load()&&s.result.frames!=s.result.timeline.outputFrames){s.result.error="call_timeline_written_frame_count_mismatch";s.fail(5);}
    s.result.cleanupVerified = safe;
    const auto failure = s.failure.load();
    if (s.result.error.empty() && failure) {
        static const char* errors[] = {"", "concurrent_capture_callback", "invalid_capture_buffer_or_timestamp", "capture_queue_overflow", "source_clock_discontinuity", "capture_writer_failed", "capture_riff32_capacity", "selected_capture_identity_invalidated", "capture_cancellation_predicate_failed", "call_capture_timeline_failed"};
        s.result.error = errors[failure];
    }
    if (s.result.error.empty() && !safe) s.result.error = "selected_capture_cleanup_unverified";
    if (s.result.error.empty() && s.result.frames == 0) s.result.error = "selected_capture_no_audio_frames";
    s.result.completed = s.started && safe && !failure && s.result.error.empty() && s.result.frames > 0;
    s.stopped = true; return s.result;
}
}
