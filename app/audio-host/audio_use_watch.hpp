#pragma once
#include <CoreAudio/CoreAudio.h>
#include <algorithm>
#include <cstdint>
#include <functional>
#include <optional>
#include <vector>
namespace labvoice {
struct AudioUseListenerKey {
    AudioObjectID object; AudioObjectPropertyAddress address;
    bool operator==(const AudioUseListenerKey& other) const {
        return object == other.object && address.mSelector == other.address.mSelector &&
            address.mScope == other.address.mScope && address.mElement == other.address.mElement;
    }
};
enum class AudioUseRemoval { removed, invalidObjectRetired, failed };
inline bool mayRetireInvalidAudioObject(OSStatus removalStatus, const AudioUseListenerKey& key,
                                       const std::optional<std::vector<AudioObjectID>>& currentProcesses,
                                       OSStatus classProbeStatus) {
    const auto selector=key.address.mSelector;
    const bool processSelector=key.address.mElement==kAudioObjectPropertyElementMain &&
        (((selector==kAudioProcessPropertyIsRunningInput || selector==kAudioProcessPropertyIsRunningOutput) &&
          key.address.mScope==kAudioObjectPropertyScopeGlobal) ||
         (selector==kAudioProcessPropertyDevices && (key.address.mScope==kAudioObjectPropertyScopeInput || key.address.mScope==kAudioObjectPropertyScopeOutput)));
    return key.object!=kAudioObjectSystemObject && processSelector &&
        removalStatus==kAudioHardwareBadObjectError && classProbeStatus==kAudioHardwareBadObjectError &&
        currentProcesses && std::find(currentProcesses->begin(),currentProcesses->end(),key.object)==currentProcesses->end();
}
// Failed removal keeps the exact registration owned. Callbacks are fenced before removal.
class AudioUseListenerRegistry {
public:
    struct Entry { uint64_t id, generation; AudioUseListenerKey key; bool enabled; };
    uint64_t generation = 1;
    std::vector<Entry> entries;
    size_t removed=0, invalidObjectRetired=0, removeFailed=0;
    std::function<bool(const Entry&)> add;
    std::function<AudioUseRemoval(const Entry&)> remove;
    bool reconcile(const std::vector<AudioUseListenerKey>& desired) {
        bool ok = true;
        for (auto it = entries.begin(); it != entries.end();) {
            if (!it->enabled || it->generation != generation || std::find(desired.begin(), desired.end(), it->key) == desired.end()) {
                it->enabled = false;
                const auto outcome=remove(*it);
                if(outcome==AudioUseRemoval::failed) { ++removeFailed; ok=false; ++it; }
                else { if(outcome==AudioUseRemoval::removed) ++removed; else ++invalidObjectRetired; it=entries.erase(it); }
            } else ++it;
        }
        if (!ok) return false;
        for (const auto& key : desired) {
            if (std::any_of(entries.begin(), entries.end(), [&](const Entry& e) { return e.key == key && e.enabled; })) continue;
            Entry entry{++nextID, generation, key, true};
            if (!add(entry)) return false;
            entries.push_back(entry);
        }
        return true;
    }
    bool accepts(uint64_t id, uint64_t epoch) const {
        return epoch == generation && std::any_of(entries.begin(), entries.end(), [&](const Entry& e) { return e.id == id && e.enabled; });
    }
    void invalidate() { ++generation; for (auto& e : entries) e.enabled = false; }
    bool stop() { invalidate(); return reconcile({}); }
private: uint64_t nextID = 0;
};
int watchAudioProcessUsage(bool stabilized=false);
}
