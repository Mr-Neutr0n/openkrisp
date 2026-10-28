#pragma once
#include "audio_process_usage.hpp"
#include <map>
#include <set>
namespace labvoice {
struct AudioUsePublication {
    AudioProcessSnapshot snapshot;
    std::string sourceState="running", reason;
    std::vector<std::string> changedDirections;
};
struct AudioUseTimedFrame {
    AudioUsePublication publication;
    uint64_t generation;
    uint64_t coalescedPublications=0;
};
void retainLatestAudioUsePublication(std::optional<AudioUseTimedFrame>&,AudioUseTimedFrame);
std::string audioUsePublicationJSONFields(const AudioUsePublication&);
// Deterministic scheduling: listener sampling, tracker promotion, then storage batch.
// Real original timers can acquire their locks in a different same-tick order.
class AudioUseTiming {
public:
    static constexpr int64_t listenerMS=200, startMS=250, endMS=1200, batchMS=100;
    void membership(const AudioProcessSnapshot&, int64_t now);
    void property(AudioObjectID, int64_t now);
    std::vector<AudioObjectID> due(int64_t now);
    void sample(const AudioProcessSnapshot&, const std::vector<AudioObjectID>&, int64_t now);
    std::optional<AudioUsePublication> tick(int64_t now);
    bool requestRestart(int64_t now);
    bool needsReload(int64_t now) const;
    bool reload(const AudioProcessSnapshot&, int64_t now);
    bool restarting() const { return restartActive; }
private:
    struct Entry {
        AudioProcessUsage published;
        std::optional<AudioProcessUsage> pending;
        std::optional<int64_t> listenerFirst, trackerFirst;
        bool stale=false;
    };
    std::map<AudioObjectID,Entry> entries;
    std::map<AudioObjectID,AudioProcessUsage> delivered;
    std::optional<int64_t> batchFirst;
    bool dirtyInput=false,dirtyOutput=false,readyPending=false,diagnosticPending=false,initialized=false,sourceKnown=true;
    bool restartActive=false, resetSent=false;
    size_t queuedRestarts=0;
    int64_t restartFirst=0;
    std::optional<AudioUsePublication> urgent;
    void dirty(bool input,bool output,int64_t now);
    void failed(const AudioProcessSnapshot&);
    void beginRestart(int64_t now);
    AudioProcessSnapshot snapshot() const;
    static bool normalize(AudioProcessUsage&);
    static std::set<AudioObjectID> ids(const AudioProcessDirection&);
};
}
