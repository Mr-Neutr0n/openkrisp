#pragma once
#include <CoreAudio/CoreAudio.h>
#include <exception>
#include <string>
#include <vector>

namespace labvoice {
struct DeviceMetadata {
    std::string interfaceName, manufacturer, modelId;
    std::vector<std::string> warnings;
};
// The required name has already been read. Optional metadata cannot remove an
// otherwise routable device or enter the inventory's fatal read-error list.
template<class ReadString> DeviceMetadata readDeviceMetadata(const std::string& name, ReadString read) {
    DeviceMetadata result;result.interfaceName=name;
    const auto optional=[&](AudioObjectPropertySelector selector,const char* field,std::string& value) {
        const AudioObjectPropertyAddress address{selector,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
        try { value=read(address); }
        catch(const std::exception& error) { result.warnings.push_back(std::string(field)+": "+error.what()); }
    };
    optional(kAudioObjectPropertyManufacturer,"manufacturer",result.manufacturer);
    optional(kAudioDevicePropertyModelUID,"model_id",result.modelId);
    return result;
}
}
