#pragma once
#include "control_protocol.hpp"
#include "../native-model-probe/installed_aec_worker_launch.hpp"
#include <sstream>
namespace labvoice {
// Present only for explicit AEC routes. Existing non-AEC startup fields stay unchanged.
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
} // namespace labvoice
