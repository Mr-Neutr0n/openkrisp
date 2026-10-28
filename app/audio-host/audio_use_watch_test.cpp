#include "audio_use_watch.hpp"
#include <cassert>
#include <set>
using namespace labvoice;
int main() {
    AudioUseListenerRegistry r; std::set<uint64_t> owned; bool failRemove = false, failAdd = false;
    r.add = [&](const auto& e) { if(failAdd) return false; owned.insert(e.id); return true; };
    r.remove = [&](const auto& e) { if(failRemove) return AudioUseRemoval::failed; assert(owned.erase(e.id)==1); return AudioUseRemoval::removed; };
    AudioUseListenerKey a{1,{1,2,3}}, b{2,{1,2,3}};
    assert(r.reconcile({a})); auto old=r.entries[0]; assert(r.accepts(old.id,old.generation));
    assert(r.reconcile({a})); assert(r.entries.size()==1);
    failRemove=true; assert(!r.reconcile({b})); assert(r.entries.size()==1); assert(!r.accepts(old.id,old.generation));
    assert(!r.stop()); assert(owned.size()==1); assert(r.entries[0].key==a);
    failRemove=false; assert(r.stop()); assert(owned.empty());
    failAdd=true; assert(!r.reconcile({a,b})); assert(r.entries.empty());
    failAdd=false; assert(r.reconcile({a})); auto disabled=r.entries[0];
    failRemove=true; assert(!r.reconcile({b})); failRemove=false;
    assert(r.reconcile({a})); assert(!r.accepts(disabled.id,disabled.generation));
    assert(r.entries.size()==1); assert(r.stop());
    assert(r.reconcile({a,b})); auto stale=r.entries[0]; r.invalidate();
    assert(!r.accepts(stale.id,stale.generation)); assert(r.reconcile({a,b}));
    assert(r.entries.size()==2); assert(r.entries[0].generation==r.generation); assert(r.stop());
    const auto bad=kAudioHardwareBadObjectError;
    AudioUseListenerKey process{100,{kAudioProcessPropertyDevices,kAudioObjectPropertyScopeInput,0}};
    std::optional<std::vector<AudioObjectID>> absent=std::vector<AudioObjectID>{101};
    assert(mayRetireInvalidAudioObject(bad,process,absent,bad));
    assert(!mayRetireInvalidAudioObject(noErr,process,absent,bad));
    assert(!mayRetireInvalidAudioObject(kAudioHardwareIllegalOperationError,process,absent,bad));
    assert(!mayRetireInvalidAudioObject(bad,process,std::nullopt,bad));
    assert(!mayRetireInvalidAudioObject(bad,process,std::vector<AudioObjectID>{100},bad));
    assert(!mayRetireInvalidAudioObject(bad,process,absent,noErr));
    auto system=process;system.object=kAudioObjectSystemObject;
    assert(!mayRetireInvalidAudioObject(bad,system,absent,bad));
    auto other=process;other.address.mSelector=kAudioHardwarePropertyServiceRestarted;
    assert(!mayRetireInvalidAudioObject(bad,other,absent,bad));
    auto badScope=process;badScope.address.mScope=kAudioObjectPropertyScopeGlobal;
    assert(!mayRetireInvalidAudioObject(bad,badScope,absent,bad));
    auto badElement=process;badElement.address.mElement=2;
    assert(!mayRetireInvalidAudioObject(bad,badElement,absent,bad));
    auto running=process;running.address.mSelector=kAudioProcessPropertyIsRunningInput;
    assert(!mayRetireInvalidAudioObject(bad,running,absent,bad));
    running.address.mScope=kAudioObjectPropertyScopeGlobal;
    assert(mayRetireInvalidAudioObject(bad,running,absent,bad));
    running.address.mSelector=kAudioProcessPropertyIsRunningOutput;
    assert(mayRetireInvalidAudioObject(bad,running,absent,bad));
    AudioUseListenerRegistry retired; retired.add=[](const auto&){return true;};
    retired.remove=[](const auto&){return AudioUseRemoval::invalidObjectRetired;};
    assert(retired.reconcile({process}));auto token=retired.entries[0];
    assert(retired.stop());assert(retired.entries.empty());assert(retired.invalidObjectRetired==1);
    assert(retired.removed==0 && retired.removeFailed==0);assert(!retired.accepts(token.id,token.generation));
}
