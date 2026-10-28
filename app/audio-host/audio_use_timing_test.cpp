#include "audio_use_timing.hpp"
#include <cassert>
#include <iostream>
using namespace labvoice;
AudioProcessUsage row(unsigned id,bool in,bool out) {
    AudioProcessUsage r{};r.objectID=id;r.actualPID=100+id;r.responsiblePID=100+id;
    r.input.running=in;r.output.running=out;r.input.devices=std::vector<AudioUsedDevice>{};r.output.devices=std::vector<AudioUsedDevice>{};
    if(in)r.input.devices->push_back({10,"input",true});if(out)r.output.devices->push_back({20,"output",true});return r;
}
AudioProcessSnapshot snap(std::initializer_list<AudioProcessUsage> rows){return {"available",rows,{}};}
bool active(const AudioUsePublication& p){return !p.snapshot.processes.empty() && !p.snapshot.processes[0].input.devices->empty();}
int main() {
    AudioUseTiming t;t.membership(snap({row(2,false,false)}),0);assert(!t.tick(99));auto ready=t.tick(100);assert(ready && ready->reason=="readiness" && ready->changedDirections.empty());
    t.property(2,200);t.property(2,300);assert(t.due(399).empty());auto due=t.due(400);assert(due==std::vector<AudioObjectID>{2});
    t.sample(snap({row(2,true,false)}),due,400);assert(!t.tick(650));assert(!t.tick(651));assert(!t.tick(750));auto started=t.tick(751);assert(started && active(*started));
    t.property(2,1000);due=t.due(1200);t.sample(snap({row(2,false,false)}),due,1200);assert(!t.tick(2400));assert(!t.tick(2401));auto ended=t.tick(2501);assert(ended && !active(*ended));
    // Real 20ms scheduling grid: 200 listener, >250 tracker =>460, +100 storage=>560.
    AudioUseTiming grid;grid.membership(snap({row(2,false,false)}),-1000);grid.tick(-900);grid.property(2,0);
    std::optional<AudioUsePublication> emitted;
    for(int ms=0;ms<=560;ms+=20){auto ids=grid.due(ms);if(!ids.empty())grid.sample(snap({row(2,true,false)}),ids,ms);auto p=grid.tick(ms);if(p){assert(ms==560);emitted=p;}}
    assert(emitted && active(*emitted));
    // A bulk sample must not advance unrelated B before its own listener deadline.
    AudioUseTiming bulk;bulk.membership(snap({row(2,false,false),row(3,false,false)}),0);bulk.tick(100);bulk.property(2,200);bulk.property(3,300);
    auto ids=bulk.due(400);assert(ids.size()==1 && ids[0]==2);bulk.sample(snap({row(2,true,false),row(3,true,false)}),ids,400);bulk.tick(651);auto a=bulk.tick(751);assert(a && a->snapshot.processes[1].input.devices->empty());
    // Pending changes retain first time, return-to-published cancels, metadata cannot reset.
    AudioUseTiming keep;keep.membership(snap({row(2,false,false)}),0);keep.tick(100);keep.property(2,200);ids=keep.due(400);keep.sample(snap({row(2,true,false)}),ids,400);
    auto alt=row(2,true,false);alt.input.devices=std::vector<AudioUsedDevice>{{11,"other",true}};alt.appName="changed metadata";
    keep.sample(snap({alt}),{2},600);keep.tick(651);a=keep.tick(751);assert(a && a->snapshot.processes[0].input.devices->at(0).objectID==11);
    keep.property(2,800);ids=keep.due(1000);keep.sample(snap({row(2,false,false)}),ids,1000);keep.sample(snap({alt}),{2},1100);assert(!keep.tick(2300));
    // Partial device removal while direction stays nonempty uses start, not end.
    AudioUseTiming partial;auto two=row(2,true,false);two.input.devices=std::vector<AudioUsedDevice>{{10,"one",true},{11,"two",true}};
    partial.membership(snap({two}),0);partial.tick(100);partial.sample(snap({row(2,true,false)}),{2},200);partial.tick(451);a=partial.tick(551);assert(a && a->snapshot.processes[0].input.devices->size()==1);
    // New objects seed directly; disappearance bypasses end delay and initial transient never leaks.
    AudioUseTiming initial;initial.membership(snap({row(2,true,false)}),0);initial.membership(snap({}),50);a=initial.tick(100);assert(a && a->snapshot.processes.empty());
    initial.membership(snap({row(3,true,false)}),200);a=initial.tick(300);assert(a && active(*a));initial.membership(snap({}),350);a=initial.tick(450);assert(a && a->snapshot.processes.empty());
    // Unknown cancels only its own candidate and cannot become a false end.
    AudioUseTiming unknown;unknown.membership(snap({row(2,true,false),row(3,false,false)}),0);unknown.tick(100);
    unknown.sample(snap({row(2,false,false),row(3,true,false)}),{2,3},200);
    auto bad=row(2,false,false);bad.input.running.reset();unknown.sample(snap({bad}),{2},300);assert(!unknown.tick(300));a=unknown.tick(400);assert(a && a->reason=="read_error" && a->snapshot.processes[0].usageStale==true);
    unknown.tick(451);a=unknown.tick(551);assert(a && active(*a) && !a->snapshot.processes[1].input.devices->empty());
    // An unrelated unknown cannot leak healthy tracker promotion before storage flush.
    AudioUseTiming noLeak;noLeak.membership(snap({row(2,false,false),row(3,false,false)}),0);noLeak.tick(100);
    noLeak.sample(snap({row(2,true,false)}),{2},200);assert(!noLeak.tick(451));
    auto unknownB=row(3,false,false);unknownB.input.running.reset();
    noLeak.sample(snap({unknownB}),{3},480);assert(!noLeak.tick(480));assert(!noLeak.tick(550));
    a=noLeak.tick(551);assert(a && active(*a) && a->snapshot.processes[1].usageStale==true);
    // A global failure retains directional provenance of an unflushed promotion.
    AudioUseTiming provenance;provenance.membership(snap({row(2,false,false)}),0);provenance.tick(100);
    provenance.sample(snap({row(2,true,false)}),{2},200);assert(!provenance.tick(451));
    provenance.membership({"failed",{}, {"injected"}},480);a=provenance.tick(480);assert(a && a->snapshot.status=="failed");assert(!provenance.tick(551));
    provenance.membership(snap({row(2,true,false)}),500);provenance.sample(snap({row(2,true,false)}),{2},500);
    assert(!provenance.tick(599));a=provenance.tick(600);assert(a && active(*a) && a->reason=="changed" && a->changedDirections==std::vector<std::string>{"input"});
    AudioUseTiming rollback;rollback.membership(snap({row(2,false,false)}),0);rollback.tick(100);
    rollback.sample(snap({row(2,true,false)}),{2},200);rollback.tick(451);rollback.membership({"failed",{}, {}},480);rollback.tick(480);
    rollback.membership(snap({row(2,false,false)}),500);rollback.sample(snap({row(2,false,false)}),{2},500);a=rollback.tick(600);assert(a && active(*a) && a->reason=="changed");
    assert(!rollback.tick(1700));assert(!rollback.tick(1701));a=rollback.tick(1801);assert(a && !active(*a));
    // Property-driven recovery needs no unrelated process-list callback.
    AudioUseTiming propertyRecovery;propertyRecovery.membership(snap({row(2,false,false)}),0);propertyRecovery.tick(100);
    propertyRecovery.sample({"failed",{}, {"injected"}},{2},200);propertyRecovery.tick(200);
    propertyRecovery.property(2,300);ids=propertyRecovery.due(500);propertyRecovery.sample(snap({row(2,true,false)}),ids,500);
    a=propertyRecovery.tick(600);assert(a && !active(*a));propertyRecovery.tick(751);a=propertyRecovery.tick(851);assert(a && active(*a) && a->snapshot.processes[0].usageStale==false);
    // Initially unknown ownership can reinitialize on the first valid identity.
    AudioUseTiming identity;auto missing=row(2,true,false);missing.actualPID.reset();missing.responsiblePID.reset();
    identity.membership(snap({missing}),0);a=identity.tick(100);assert(a && a->snapshot.processes[0].usageStale==true);
    identity.membership(snap({row(2,true,false)}),200);a=identity.tick(300);assert(a && a->snapshot.processes[0].usageStale==false);
    assert(a->snapshot.processes[0].actualPID==102);
    AudioUseTiming identitySample;identitySample.membership(snap({missing}),0);identitySample.tick(100);
    identitySample.property(2,200);ids=identitySample.due(400);identitySample.sample(snap({row(2,true,false)}),ids,400);
    a=identitySample.tick(500);assert(a && a->snapshot.processes[0].actualPID==102 && a->snapshot.processes[0].usageStale==false);
    // Metadata-only changes cannot schedule a directional publication.
    auto meta=row(2,true,false);meta.appName="renamed";identity.sample(snap({meta}),{2},400);assert(!identity.tick(1000));
    // Normalization is two ascending passes, not a combined OR filter.
    AudioUseTiming normalization;auto n=row(2,true,true);n.output.devices=std::vector<AudioUsedDevice>{{1,"output",true}};
    n.input.devices=std::vector<AudioUsedDevice>{{1,"one",true},{2,"two",false}};
    normalization.membership(snap({n}),0);a=normalization.tick(100);assert(a && a->snapshot.processes[0].input.devices->size()==1 && a->snapshot.processes[0].input.devices->at(0).objectID==1);
    // A system read failure is not membership disappearance.
    identity.membership({"failed",{}, {"injected read error"}},1100);a=identity.tick(1100);assert(a && a->snapshot.status=="failed");
    identity.membership(snap({row(2,true,false)}),1200);ids=identity.due(1400);assert(ids.size()==1);identity.sample(snap({row(2,true,false)}),ids,1400);a=identity.tick(1500);assert(a && active(*a) && a->snapshot.processes[0].usageStale==false);
    // End pipeline grid: >=200, strict >1200 after sample, >=100 batch =>1520.
    AudioUseTiming endGrid;endGrid.membership(snap({row(2,true,false)}),-1000);endGrid.tick(-900);endGrid.property(2,0);
    for(int ms=0;ms<=1520;ms+=20){auto ds=endGrid.due(ms);if(!ds.empty())endGrid.sample(snap({row(2,false,false)}),ds,ms);auto p=endGrid.tick(ms);if(p){assert(ms==1520);assert(!active(*p));}}
    // Restart reset eligibility, reload hold, repeated serialized restarts, no stale candidates.
    assert(unknown.requestRestart(1000));a=unknown.tick(1000);assert(a && a->sourceState=="restarting");assert(!unknown.tick(2099));a=unknown.tick(2100);assert(a && a->reason=="restart_reset" && a->changedDirections==std::vector<std::string>({"input","output"}));
    assert(!unknown.needsReload(2999));assert(!unknown.requestRestart(1500));assert(unknown.needsReload(3000));assert(unknown.reload(snap({row(2,true,false)}),3000));
    a=unknown.tick(3000);assert(a && a->reason=="restart_begin");assert(!unknown.needsReload(4999));assert(unknown.needsReload(5000));assert(!unknown.reload(snap({row(2,false,false)}),5000));a=unknown.tick(5100);assert(a && !active(*a));
    // Threshold selection changes with pending content without restarting first time.
    AudioUseTiming switchDelay;switchDelay.membership(snap({row(2,true,false)}),0);switchDelay.tick(100);
    switchDelay.sample(snap({row(2,false,false)}),{2},200);
    auto replacement=row(2,true,false);replacement.input.devices=std::vector<AudioUsedDevice>{{11,"replacement",true}};
    switchDelay.sample(snap({replacement}),{2},400);assert(!switchDelay.tick(450));switchDelay.tick(451);a=switchDelay.tick(551);assert(a && a->snapshot.processes[0].input.devices->at(0).objectID==11);
    AudioUseTiming reverse;reverse.membership(snap({row(2,true,false)}),0);reverse.tick(100);reverse.sample(snap({replacement}),{2},200);reverse.sample(snap({row(2,false,false)}),{2},400);
    assert(!reverse.tick(1400));assert(!reverse.tick(1401));a=reverse.tick(1501);assert(a && !active(*a));
    // The bounded output slot explicitly reports skipped timed publications.
    std::optional<AudioUseTimedFrame> slot;
    retainLatestAudioUsePublication(slot,{{snap({row(2,true,false)}),"running","changed",{"input"}},1});
    retainLatestAudioUsePublication(slot,{{snap({row(2,false,false)}),"running","changed",{"input"}},1});
    assert(slot && !active(slot->publication) && slot->coalescedPublications==1 && slot->publication.reason=="changed" && slot->publication.changedDirections==std::vector<std::string>{"input"});
    auto taken=std::move(slot);slot.reset();assert(taken->coalescedPublications==1);
    retainLatestAudioUsePublication(slot,{{snap({row(2,false,false)}),"running","readiness",{}},1});assert(slot->coalescedPublications==0);
    retainLatestAudioUsePublication(slot,{{{"failed",{}, {"injected"}},"running","read_error",{}},1});assert(slot->coalescedPublications==1 && slot->publication.changedDirections.empty());
    retainLatestAudioUsePublication(slot,{{{"unavailable",{}, {}},"restarting","restart_begin",{}},2});assert(slot->coalescedPublications==2 && slot->generation==2 && slot->publication.changedDirections.empty());
    auto huge=row(2,true,false);huge.appName=std::string(530000,'x');
    const auto bounded=audioUsePublicationJSONFields({snap({huge}),"running","changed",{"input"}});
    assert(bounded.find("\"publication_reason\":\"read_error\"")!=std::string::npos);
    assert(bounded.find("\"changed_directions\":[]")!=std::string::npos);
    assert(bounded.find("\"status\":\"failed\"")!=std::string::npos);
    std::cout<<"Audio-use timing stages, due-row isolation, cancellation, normalization, unknown retention, membership and restart tests passed. No audio opened.\n";
}
