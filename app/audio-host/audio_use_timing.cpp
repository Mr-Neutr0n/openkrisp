#include "audio_use_timing.hpp"
#include <algorithm>
namespace labvoice {
void retainLatestAudioUsePublication(std::optional<AudioUseTimedFrame>& slot,AudioUseTimedFrame incoming) {
    if(slot) {
        incoming.coalescedPublications=slot->coalescedPublications+1;
        if(slot->generation==incoming.generation && slot->publication.sourceState=="running" && incoming.publication.sourceState=="running" && slot->publication.snapshot.status=="available" && incoming.publication.snapshot.status=="available") {
            for(const auto& direction:slot->publication.changedDirections)
                if(std::find(incoming.publication.changedDirections.begin(),incoming.publication.changedDirections.end(),direction)==incoming.publication.changedDirections.end())incoming.publication.changedDirections.push_back(direction);
            if(!incoming.publication.changedDirections.empty()) {incoming.publication.reason="changed";std::sort(incoming.publication.changedDirections.begin(),incoming.publication.changedDirections.end());}
        }
    }
    slot=std::move(incoming);
}
std::string audioUsePublicationJSONFields(const AudioUsePublication& publication) {
    bool overflow=false;const auto body=audioProcessUsageJSON(publication.snapshot,&overflow);
    const auto reason=overflow ? "read_error":publication.reason;
    std::string fields=",\"source_state\":\""+publication.sourceState+"\",\"publication_reason\":\""+reason+"\",\"changed_directions\":[";
    bool comma=false;
    if(!overflow)for(const auto& direction:publication.changedDirections) {if(comma)fields+=',';comma=true;fields+="\""+direction+"\"";}
    return fields+"],\"snapshot\":"+body;
}

std::set<AudioObjectID> AudioUseTiming::ids(const AudioProcessDirection& d) {
    std::set<AudioObjectID> out; if(d.devices) for(const auto& v:*d.devices)out.insert(v.objectID);return out;
}
bool AudioUseTiming::normalize(AudioProcessUsage& row) {
    if(!row.actualPID || !row.responsiblePID || *row.actualPID<=0 || *row.responsiblePID<=0 || !row.input.running || !row.output.running || !row.input.devices || !row.output.devices)return false;
    if((!*row.input.running && !row.input.devices->empty()) || (!*row.output.running && !row.output.devices->empty()))return false;
    auto& in=*row.input.devices;
    std::sort(in.begin(),in.end(),[](const auto& a,const auto& b){return a.objectID<b.objectID;});
    in.erase(std::unique(in.begin(),in.end(),[](const auto& a,const auto& b){return a.objectID==b.objectID;}),in.end());
    if(in.size()>1) {
        for(auto it=in.begin();it!=in.end() && in.size()>1;) {
            if(!it->hasInputStreams)return false;
            if(!*it->hasInputStreams)it=in.erase(it);else ++it;
        }
        const auto out=ids(row.output);
        for(auto it=in.begin();it!=in.end() && in.size()>1;) {
            if(out.contains(it->objectID))it=in.erase(it);else ++it;
        }
    }
    return true;
}
void AudioUseTiming::dirty(bool input,bool output,int64_t now) {
    dirtyInput|=input;dirtyOutput|=output;
    if(!batchFirst)batchFirst=now;
}
void AudioUseTiming::failed(const AudioProcessSnapshot& source) {
    sourceKnown=false;batchFirst.reset();
    for(auto& [id,e]:entries) { (void)id;e.stale=true;e.pending.reset();e.listenerFirst.reset();e.trackerFirst.reset(); }
    urgent=AudioUsePublication{source,"running","read_error",{}};
}
void AudioUseTiming::membership(const AudioProcessSnapshot& source,int64_t now) {
    if(source.status!="available") { failed(source);return; }
    const bool recovering=!sourceKnown;sourceKnown=true;
    std::set<AudioObjectID> present;
    for(auto raw:source.processes) {
        present.insert(raw.objectID);
        auto found=entries.find(raw.objectID);
        if(found!=entries.end() && raw.actualPID && raw.responsiblePID &&
           (raw.actualPID!=found->second.published.actualPID || raw.responsiblePID!=found->second.published.responsiblePID)) {
            dirty(!ids(found->second.published.input).empty(),!ids(found->second.published.output).empty(),now);
            entries.erase(found);found=entries.end();
        }
        if(found!=entries.end()) { if(found->second.stale && !found->second.listenerFirst)found->second.listenerFirst=now;continue; }
        const bool known=normalize(raw);
        Entry entry;entry.published=raw;entry.stale=!known;
        entries.emplace(raw.objectID,std::move(entry));
        if(known && (!ids(raw.input).empty() || !ids(raw.output).empty()))dirty(!ids(raw.input).empty(),!ids(raw.output).empty(),now);
    }
    for(auto it=entries.begin();it!=entries.end();) {
        if(!present.contains(it->first)) {
            const auto& row=it->second.published;
            if(!ids(row.input).empty() || !ids(row.output).empty())dirty(!ids(row.input).empty(),!ids(row.output).empty(),now);
            it=entries.erase(it);
        } else ++it;
    }
    if(!initialized || (recovering && entries.empty())) { initialized=true;readyPending=true;dirty(false,false,now); }
}
void AudioUseTiming::property(AudioObjectID id,int64_t now) {
    if(restartActive)return;
    const auto it=entries.find(id);if(it!=entries.end() && !it->second.listenerFirst)it->second.listenerFirst=now;
}
std::vector<AudioObjectID> AudioUseTiming::due(int64_t now) {
    std::vector<AudioObjectID> out;
    if(restartActive)return out;
    for(auto& [id,e]:entries)if(e.listenerFirst && now-*e.listenerFirst>=listenerMS) { e.listenerFirst.reset();out.push_back(id); }
    return out;
}
void AudioUseTiming::sample(const AudioProcessSnapshot& source,const std::vector<AudioObjectID>& requested,int64_t now) {
    if(restartActive)return;
    if(source.status!="available") {failed(source);return;}
    if(!sourceKnown) {
        sourceKnown=true;
        for(auto& [id,e]:entries)if(e.stale && std::find(requested.begin(),requested.end(),id)==requested.end() && !e.listenerFirst)e.listenerFirst=now;
    }
    for(const auto id:requested) {
        const auto target=entries.find(id);if(target==entries.end())continue;
        auto& e=target->second;
        const auto observed=std::find_if(source.processes.begin(),source.processes.end(),[&](const auto& r){return r.objectID==id;});
        AudioProcessUsage row{};if(observed!=source.processes.end())row=*observed;
        const bool known=observed!=source.processes.end() && normalize(row);
        if(known && (row.actualPID!=e.published.actualPID || row.responsiblePID!=e.published.responsiblePID)) {
            const bool in=!ids(e.published.input).empty() || !ids(row.input).empty();
            const bool out=!ids(e.published.output).empty() || !ids(row.output).empty();
            e=Entry{};e.published=std::move(row);dirty(in,out,now);continue;
        }
        if(!known) {
            e.stale=true;e.pending.reset();e.trackerFirst.reset();
            diagnosticPending=true;dirty(false,false,now);continue;
        }
        const bool wasStale=e.stale;
        e.stale=false;if(wasStale) {readyPending=true;dirty(false,false,now);}
        if(ids(row.input)==ids(e.published.input) && ids(row.output)==ids(e.published.output)) {
            e.pending.reset();e.trackerFirst.reset();e.stale=false;
            if(wasStale) {e.published.input=row.input;e.published.output=row.output;}
            if(wasStale) {readyPending=true;dirty(false,false,now);}
        } else if(!e.pending || ids(row.input)!=ids(e.pending->input) || ids(row.output)!=ids(e.pending->output)) {
            e.pending=std::move(row);if(!e.trackerFirst)e.trackerFirst=now;
        }
    }
}
AudioProcessSnapshot AudioUseTiming::snapshot() const {
    AudioProcessSnapshot out{"available",{}, {}};
    for(const auto& [id,e]:entries) {
        (void)id;auto row=e.published;
        row.usageStale=e.stale;row.stabilizationPending=e.listenerFirst.has_value() || e.pending.has_value();
        if(e.stale)row.errors.push_back("Usage read unknown; last published usage retained by independent safety policy.");
        out.processes.push_back(std::move(row));
    }
    return out;
}
std::optional<AudioUsePublication> AudioUseTiming::tick(int64_t now) {
    if(urgent) {auto out=std::move(urgent);urgent.reset();return out;}
    if(restartActive) {
        if(!resetSent && now-restartFirst>=1100) {
            resetSent=true;
            return AudioUsePublication{{"unavailable",{}, {"CoreAudio restart forced empty reset; recovery remains in progress."}},"restarting","restart_reset",{"input","output"}};
        }
        return std::nullopt;
    }
    if(!sourceKnown)return std::nullopt;
    for(auto& [id,e]:entries) {
        (void)id;if(!e.pending || !e.trackerFirst)continue;
        const bool end=(!ids(e.published.input).empty() && ids(e.pending->input).empty()) ||
            (!ids(e.published.output).empty() && ids(e.pending->output).empty());
        if(now-*e.trackerFirst>(end?endMS:startMS)) {
            const bool in=ids(e.published.input)!=ids(e.pending->input),out=ids(e.published.output)!=ids(e.pending->output);
            e.published.input=e.pending->input;e.published.output=e.pending->output;e.stale=false;
            e.pending.reset();e.trackerFirst.reset();dirty(in,out,now);
        }
    }
    if(batchFirst && now-*batchFirst>=batchMS) {
        // Restore provenance against the last externally delivered valid sets, not only
        // the tracker's settled state. Global read errors may interrupt its batch.
        for(const auto& [id,e]:entries)if(!e.stale) {
            const auto last=delivered.find(id);
            dirtyInput|=ids(e.published.input)!=(last==delivered.end()?std::set<AudioObjectID>{}:ids(last->second.input));
            dirtyOutput|=ids(e.published.output)!=(last==delivered.end()?std::set<AudioObjectID>{}:ids(last->second.output));
        }
        for(const auto& [id,row]:delivered)if(!entries.contains(id)) {dirtyInput|=!ids(row.input).empty();dirtyOutput|=!ids(row.output).empty();}
        const bool unknown=std::any_of(entries.begin(),entries.end(),[](const auto& item){return item.second.stale;});
        AudioUsePublication out{snapshot(),"running",dirtyInput || dirtyOutput ? "changed":diagnosticPending && unknown ? "read_error":"readiness",{}};
        if(dirtyInput)out.changedDirections.push_back("input");if(dirtyOutput)out.changedDirections.push_back("output");
        for(auto it=delivered.begin();it!=delivered.end();) {if(!entries.contains(it->first))it=delivered.erase(it);else ++it;}
        for(const auto& [id,e]:entries)if(!e.stale)delivered[id]=e.published;
        batchFirst.reset();dirtyInput=dirtyOutput=readyPending=diagnosticPending=false;
        return out;
    }
    return std::nullopt;
}
void AudioUseTiming::beginRestart(int64_t now) {
    entries.clear();delivered.clear();batchFirst.reset();dirtyInput=dirtyOutput=readyPending=diagnosticPending=false;initialized=false;
    sourceKnown=true;restartActive=true;restartFirst=now;resetSent=false;
    urgent=AudioUsePublication{{"unavailable",{}, {"CoreAudio restart recovery in progress."}},"restarting","restart_begin",{}};
}
bool AudioUseTiming::requestRestart(int64_t now) {
    if(restartActive) { ++queuedRestarts;return false; }
    beginRestart(now);return true;
}
bool AudioUseTiming::needsReload(int64_t now) const {return restartActive && now-restartFirst>=2000;}
bool AudioUseTiming::reload(const AudioProcessSnapshot& source,int64_t now) {
    restartActive=false;membership(source,now);
    if(queuedRestarts) {--queuedRestarts;beginRestart(now);return true;}return false;
}
}
