#pragma once
#include "microphone_test.hpp"
namespace labvoice {
MicrophoneSpec inspectPhysicalMicrophone(const std::string&,std::vector<AudioObjectID>& outputStreams);
}
