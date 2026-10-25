#pragma once
#include "control_protocol.hpp"
#include "../native-model-probe/installed_aec_worker_launch.hpp"
#include "../native-model-probe/installed_worker_launch.hpp"
#include <sstream>
namespace labvoice {
// AEC fields are present only for explicit AEC routes. Installed NC lanes
// always report their selected fixed model role with their artifact identities.
inline std::string aecStartupFields(const krisp_probe::InstalledAECWorkerSettings& settings,
                                   std::size_t delay,std::size_t maximum,std::size_t budget){
    std::ostringstream json;
    json << ",\"aec_provider\":\"installed-krisp\",\"aec_worker_sha256\":" << jsonString(settings.workerSha256)
         << ",\"aec_library_sha256\":" << jsonString(krisp_probe::installedAECLibrarySHA256)
         << ",\"aec_delay_samples\":" << delay << ",\"aec_maximum_callback_frames\":" << maximum
         << ",\"aec_scheduling_budget_frames\":" << budget
         << ",\"aec_forward_rate\":48000,\"aec_forward_channels\":1,\"aec_reference_rate\":48000,\"aec_reference_channels\":2";
    return json.str();
}
inline std::string installedNCStartupFields(const char* prefix,const krisp_probe::InstalledWorkerSettings& settings,
                                             std::size_t delay,std::size_t maximum){
    std::ostringstream json;
    json << ',' << jsonString(std::string(prefix)+"model_role") << ':' << jsonString(krisp_probe::installedModelRoleName(settings.modelRole))
         << ',' << jsonString(std::string(prefix)+"model_sha256") << ':' << jsonString(settings.modelSha256)
         << ',' << jsonString(std::string(prefix)+"addon_sha256") << ':' << jsonString(krisp_probe::installed_worker_detail::addonSHA)
         << ',' << jsonString(std::string(prefix)+"adapter_sha256") << ':' << jsonString(settings.adapterSha256)
         << ',' << jsonString(std::string(prefix)+"node_sha256") << ':' << jsonString(settings.nodeSha256)
         << ',' << jsonString(std::string(prefix)+"delay_samples") << ':' << delay
         << ',' << jsonString(std::string(prefix)+"maximum_callback_frames") << ':' << maximum;
    return json.str();
}
inline std::string microphoneChainStartupFields(const krisp_probe::InstalledAECWorkerSettings& aec,
    std::size_t aecDelay,std::size_t maximum,std::size_t budget,bool microphoneNoise,
    const krisp_probe::InstalledWorkerSettings* microphone,std::size_t ncDelay){
    std::ostringstream json;json << aecStartupFields(aec,aecDelay,maximum,budget);
    if(microphoneNoise){
        json << ",\"microphone_processing_order\":\"aec-then-nc\",\"microphone_nc_delay_samples\":" << ncDelay
             << ",\"microphone_total_delay_samples\":" << aecDelay+ncDelay;
        if(microphone)json << installedNCStartupFields("provider_",*microphone,ncDelay,maximum);
    }
    return json.str();
}
} // namespace labvoice
