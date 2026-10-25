#include "device_metadata.hpp"
#include <cassert>
#include <iostream>
#include <stdexcept>

int main() {
    for(unsigned failures=0;failures<4;++failures) {
        unsigned calls=0;
        auto result=labvoice::readDeviceMetadata("  MiXeD Device  ",[&](const AudioObjectPropertyAddress& address) -> std::string {
            assert(address.mScope==kAudioObjectPropertyScopeGlobal && address.mElement==kAudioObjectPropertyElementMain);
            const unsigned index=calls++;
            assert(address.mSelector==(index==0?AudioObjectPropertySelector(kAudioObjectPropertyManufacturer):AudioObjectPropertySelector(kAudioDevicePropertyModelUID)));
            if(failures&(1u<<index))throw std::runtime_error("fixture read failed");
            return index==0?"Vendor Inc.":"Exact Model UID";
        });
        assert(calls==2 && result.interfaceName=="  MiXeD Device  ");
        assert(result.manufacturer==(failures&1?"":"Vendor Inc."));
        assert(result.modelId==(failures&2?"":"Exact Model UID"));
        assert(result.warnings.size()==unsigned(bool(failures&1)+bool(failures&2)));
        if(failures&1)assert(result.warnings.front()=="manufacturer: fixture read failed");
        if(failures&2)assert(result.warnings.back()=="model_id: fixture read failed");
    }
    const auto empty=labvoice::readDeviceMetadata("Name",[](auto){return std::string{};});
    assert(empty.interfaceName=="Name" && empty.manufacturer.empty() && empty.modelId.empty() && empty.warnings.empty());
    std::cout<<"device metadata selector and optional-read failure tests passed\n";
}
