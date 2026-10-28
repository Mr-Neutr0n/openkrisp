#include "audio_use_watch.hpp"
#include "audio_process_usage.hpp"
#include "audio_use_timing.hpp"
#include <Block.h>
#include <dispatch/dispatch.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <unistd.h>
#include <chrono>
#include <map>
#include <iostream>
#include <memory>

namespace labvoice {
namespace {
volatile sig_atomic_t interrupted = 0;
void interrupt(int) { interrupted = 1; }
AudioUseListenerKey key(AudioObjectID object, UInt32 selector, UInt32 scope = kAudioObjectPropertyScopeGlobal) {
    return {object,{selector,scope,kAudioObjectPropertyElementMain}};
}
struct NativeWatch;
struct CallbackState { NativeWatch* owner=nullptr; };
int64_t nowMS() { return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
using TimedFrame=AudioUseTimedFrame;
struct NativeWatch {
    bool stabilized;
    AudioUseTiming timing;
    dispatch_source_t timer=nullptr;
    std::optional<TimedFrame> latest;
    std::shared_ptr<CallbackState> callbackState=std::make_shared<CallbackState>();
    dispatch_queue_t queue = dispatch_queue_create("openkrisp.audio-use", DISPATCH_QUEUE_SERIAL);
    AudioUseListenerRegistry registry;
    std::map<uint64_t, AudioObjectPropertyListenerBlock> blocks;
    bool dirty=true, restart=false, stopping=false, timingFault=false;
    std::string failure;
    explicit NativeWatch(bool mode):stabilized(mode) {
        callbackState->owner=this;
        registry.add=[this](const auto& e) {
            const auto id=e.id, epoch=e.generation;
            const UInt32 selector=e.key.address.mSelector;
            const AudioObjectID object=e.key.object;
            const std::weak_ptr<CallbackState> weak=callbackState;
            AudioObjectPropertyListenerBlock block=Block_copy(^(UInt32, const AudioObjectPropertyAddress*) {
                const auto state=weak.lock();
                if(!state || !state->owner) return;
                auto* owner=state->owner;
                if(owner->stopping || !owner->registry.accepts(id,epoch)) return;
                owner->notification(object,selector);
            });
            auto a=e.key.address;
            const auto status=AudioObjectAddPropertyListenerBlock(e.key.object,&a,queue,block);
            if(status!=noErr) { Block_release(block); failure="Listener add OSStatus="+std::to_string(status)+" object="+std::to_string(e.key.object); return false; }
            blocks.emplace(id,block); return true;
        };
        registry.remove=[this](const auto& e) {
            auto a=e.key.address;
            const auto status=AudioObjectRemovePropertyListenerBlock(e.key.object,&a,queue,blocks.at(e.id));
            auto outcome=AudioUseRemoval::removed;
            if(status!=noErr) {
                std::optional<std::vector<AudioObjectID>> current;
                OSStatus probeStatus=kAudioHardwareUnspecifiedError;
                if(status==kAudioHardwareBadObjectError && e.key.object!=kAudioObjectSystemObject) {
                    auto list=key(kAudioObjectSystemObject,kAudioHardwarePropertyProcessObjectList).address;
                    UInt32 size=0;
                    if(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,&list,0,nullptr,&size)==noErr &&
                       size<=1048576 && size%sizeof(AudioObjectID)==0) {
                        std::vector<AudioObjectID> ids(size/sizeof(AudioObjectID));
                        const auto capacity=size;
                        const auto readStatus=AudioObjectGetPropertyData(kAudioObjectSystemObject,&list,0,nullptr,&size,ids.data());
                        if(readStatus==noErr && size<=capacity && size%sizeof(AudioObjectID)==0) {
                            ids.resize(size/sizeof(AudioObjectID)); current=std::move(ids);
                        }
                    }
                    auto classAddress=key(e.key.object,kAudioObjectPropertyClass).address;
                    AudioClassID objectClass=0; size=sizeof objectClass;
                    probeStatus=AudioObjectGetPropertyData(e.key.object,&classAddress,0,nullptr,&size,&objectClass);
                }
                if(!mayRetireInvalidAudioObject(status,e.key,current,probeStatus)) {
                    failure="Listener remove OSStatus="+std::to_string(status)+" object="+std::to_string(e.key.object)+" selector="+std::to_string(a.mSelector);
                    return AudioUseRemoval::failed;
                }
                outcome=AudioUseRemoval::invalidObjectRetired;
            }
            Block_release(blocks.at(e.id)); blocks.erase(e.id); return outcome;
        };
    }
    void capture(int64_t now) {
        if(auto publication=timing.tick(now))retainLatestAudioUsePublication(latest,TimedFrame{std::move(*publication),registry.generation});
    }

    bool resetRegistrations() {
        registry.invalidate();
        if(registry.reconcile(systemKeys()))return true;
        timingFault=true;retainLatestAudioUsePublication(latest,TimedFrame{{{"failed",{}, {failure}},"running","read_error",{}},registry.generation});return false;
    }
    void notification(AudioObjectID object,UInt32 selector) {
        if(!stabilized) {dirty=true;if(selector==kAudioHardwarePropertyServiceRestarted)restart=true;return;}
        const auto now=nowMS();
        if(selector==kAudioHardwarePropertyServiceRestarted) {
            if(timing.requestRestart(now) && !resetRegistrations())return;
            capture(now);return;
        }
        if(object==kAudioObjectSystemObject)dirty=true;
        else timing.property(object,now);
    }
    void advance() {
        if(stopping || timingFault)return;
        auto now=nowMS();
        if(timing.restarting()) {
            capture(now);
            if(timing.needsReload(now)) {
                auto source=refresh();
                const bool next=timing.reload(source,nowMS());
                if(next && !resetRegistrations())return;
                capture(nowMS());
            }
            return;
        }
        if(dirty) {
            auto source=refresh();timing.membership(source,nowMS());
        }
        const auto requested=timing.due(nowMS());
        if(!requested.empty()) {
            auto source=observeAudioProcessUsage();
            timing.sample(source,requested,nowMS());
        }
        capture(nowMS());
    }
    void startTimer() {
        const std::weak_ptr<CallbackState> weak=callbackState;
        timer=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,queue);
        if(!timer) {latest=TimedFrame{{{"failed",{}, {"Unable to create source timing timer."}},"running","read_error",{}},registry.generation};return;}
        dispatch_source_set_timer(timer,dispatch_time(DISPATCH_TIME_NOW,20000000),20000000,100000);
        dispatch_source_set_event_handler(timer, ^{
            const auto state=weak.lock();if(state && state->owner && !state->owner->stopping)state->owner->advance();
        });
        dispatch_resume(timer);advance();
    }
    std::vector<AudioUseListenerKey> systemKeys() { return {key(kAudioObjectSystemObject,kAudioHardwarePropertyProcessObjectList),key(kAudioObjectSystemObject,kAudioHardwarePropertyServiceRestarted)}; }
    AudioProcessSnapshot refresh() {
        dirty=false;
        if (@available(macOS 14.4, *)) {} else { return {"unavailable", {}, {"Audio-process observation requires macOS 14.4."}}; }
        if(restart) {
            restart=false; registry.invalidate();
            if(!registry.reconcile({})) return {"failed",{}, {failure}};
        }
        if(!registry.reconcile(systemAndExisting())) return {"failed",{}, {failure}};
        auto snapshot=observeAudioProcessUsage();
        // A failed system read has no authoritative membership. Keep current listeners.
        if(snapshot.status=="failed" || snapshot.status=="unavailable") return snapshot;
        auto desired=systemKeys();
        for(const auto& p:snapshot.processes) {
            desired.push_back(key(p.objectID,kAudioProcessPropertyIsRunningInput));
            desired.push_back(key(p.objectID,kAudioProcessPropertyIsRunningOutput));
            desired.push_back(key(p.objectID,kAudioProcessPropertyDevices,kAudioObjectPropertyScopeInput));
            desired.push_back(key(p.objectID,kAudioProcessPropertyDevices,kAudioObjectPropertyScopeOutput));
        }
        if(!registry.reconcile(desired)) return {"failed",{}, {failure}};
        // Close the read-before-listener-registration gap with a fresh observation.
        // System list callbacks remain queued on this serial queue for membership races.
        return observeAudioProcessUsage();
    }
    std::vector<AudioUseListenerKey> systemAndExisting() {
        auto keys=systemKeys(); for(const auto& e:registry.entries) if(e.enabled && e.generation==registry.generation) keys.push_back(e.key);
        return keys;
    }
};
}
int watchAudioProcessUsage(bool stabilized) {
    auto* watch=new NativeWatch(stabilized); // Retain callback storage on a failed detach until owned process exit.
    interrupted=0; struct sigaction action{}, oldTerm{}, oldInt{}, oldPipe{};
    action.sa_handler=interrupt; sigemptyset(&action.sa_mask);
    sigaction(SIGTERM,&action,&oldTerm); sigaction(SIGINT,&action,&oldInt);
    action.sa_handler=SIG_IGN; sigaction(SIGPIPE,&action,&oldPipe);
    const int flags=fcntl(STDOUT_FILENO,F_GETFL); if(flags<0 || fcntl(STDOUT_FILENO,F_SETFL,flags|O_NONBLOCK)<0) return 2;
    if(stabilized)dispatch_sync(watch->queue, ^{watch->startTimer();});
    uint64_t wireGeneration=1;
    uint64_t sequence=0; std::string pending, input, controlMessage; size_t written=0;
    auto deadline=std::chrono::steady_clock::now(); bool stop=false, outputFailed=false, controlFailed=false;
    const auto operation=std::to_string(getpid());
    auto envelope=[&](const std::string& event,const std::string& fields) {
        return "{\"version\":1,\"event\":\""+event+"\",\"operation_id\":\""+operation+"\",\"sequence\":"+std::to_string(++sequence)+",\"generation\":"+std::to_string(wireGeneration)+",\"timing_mode\":\""+(stabilized ? "stabilized":"raw")+"\""+fields+"}\n";
    };
    auto enqueue=[&](std::string line) { pending=std::move(line); written=0; deadline=std::chrono::steady_clock::now()+std::chrono::seconds(2); };
    auto flush=[&] {
        if(pending.empty()) return;
        const auto n=write(STDOUT_FILENO,pending.data()+written,pending.size()-written);
        if(n>0) { written+=static_cast<size_t>(n); if(written==pending.size()) {pending.clear();written=0;} }
        else if(n<0 && errno!=EINTR && errno!=EAGAIN && errno!=EWOULDBLOCK) outputFailed=true;
        if(!pending.empty() && std::chrono::steady_clock::now()>deadline) outputFailed=true;
    };
    while(!stop && !interrupted && !outputFailed) {
        if(pending.empty()) {
            __block std::optional<TimedFrame> frame;
            if(stabilized)dispatch_sync(watch->queue, ^{frame=std::move(watch->latest);watch->latest.reset();});
            else {
                __block bool dirty=false;dispatch_sync(watch->queue, ^{dirty=watch->dirty;});
                if(dirty)dispatch_sync(watch->queue, ^{frame=TimedFrame{{watch->refresh(),"running","raw",{}},watch->registry.generation};});
            }
            if(frame) {
                wireGeneration=frame->generation;
                const auto fields=stabilized ? ",\"coalesced_publications\":"+std::to_string(frame->coalescedPublications)+audioUsePublicationJSONFields(frame->publication) : ",\"snapshot\":"+audioProcessUsageJSON(frame->publication.snapshot);
                auto line=envelope("audio_use_snapshot",fields);
                if(line.size()>524800)line=envelope("audio_use_snapshot",(stabilized ? ",\"coalesced_publications\":"+std::to_string(frame->coalescedPublications)+",\"source_state\":\""+frame->publication.sourceState+"\",\"publication_reason\":\"read_error\",\"changed_directions\":[]":"")+std::string(",\"snapshot\":")+audioProcessUsageJSON({"failed",{}, {"Snapshot exceeds streaming line bound."}}));
                enqueue(std::move(line));
            }
        }
        flush();
        pollfd fd{STDIN_FILENO,POLLIN,0}; const auto result=poll(&fd,1,50);
        if(result>0 && (fd.revents&(POLLIN|POLLHUP|POLLERR|POLLNVAL))) {
            char bytes[256]; auto n=read(STDIN_FILENO,bytes,sizeof bytes);
            if(n<=0) {if(n==0 || errno!=EINTR) stop=true;} else {
                input.append(bytes,static_cast<size_t>(n)); if(input.size()>1024) {stop=true;controlFailed=true;controlMessage="Observer control exceeds bound.";}
                size_t end; while((end=input.find('\n'))!=std::string::npos) {if(input.substr(0,end)=="stop") stop=true;else {stop=true;controlFailed=true;controlMessage="Invalid observer control command.";}input.erase(0,end+1);}
            }
        } else if(result<0 && errno!=EINTR) stop=true;
    }
    __block bool cleaned=false;
    dispatch_sync(watch->queue, ^{ watch->stopping=true; watch->callbackState->owner=nullptr; if(watch->timer)dispatch_source_cancel(watch->timer); cleaned=watch->registry.stop(); });
    dispatch_sync(watch->queue, ^{}); // Drain callbacks already submitted before successful removals.
    // Finish any partial line first. Never interleave terminal JSON with a snapshot.
    while(!pending.empty() && !outputFailed) { flush(); if(!pending.empty()) {pollfd out{STDOUT_FILENO,POLLOUT,0};poll(&out,1,20);} }
    wireGeneration=watch->registry.generation;
    if(!outputFailed) {
        const auto cleanupFields=",\"listeners_removed\":"+std::to_string(watch->registry.removed)+
            ",\"listeners_invalid_object_retired\":"+std::to_string(watch->registry.invalidObjectRetired)+
            ",\"listeners_remove_failed\":"+std::to_string(watch->registry.removeFailed)+
            ",\"all_listener_removals_verified\":"+(watch->registry.invalidObjectRetired==0 && watch->registry.removeFailed==0 ? "true" : "false");
        enqueue(cleaned && !controlFailed ? envelope("audio_use_stopped",",\"cleanup_verified\":true"+cleanupFields) : envelope("audio_use_error",",\"message\":\"Observer stop failed; inspect diagnostic.\",\"snapshot\":"+audioProcessUsageJSON({"failed",{}, {controlFailed ? controlMessage:watch->failure}})+cleanupFields));
        while(!pending.empty() && !outputFailed) {flush();if(!pending.empty()){pollfd out{STDOUT_FILENO,POLLOUT,0};poll(&out,1,20);}}
    }
    fcntl(STDOUT_FILENO,F_SETFL,flags);
    sigaction(SIGTERM,&oldTerm,nullptr);sigaction(SIGINT,&oldInt,nullptr);sigaction(SIGPIPE,&oldPipe,nullptr);
    if(cleaned) {if(watch->timer)dispatch_release(watch->timer);dispatch_release(watch->queue);delete watch;}
    return cleaned && !outputFailed && !controlFailed ? 0 : 2;
}
}
