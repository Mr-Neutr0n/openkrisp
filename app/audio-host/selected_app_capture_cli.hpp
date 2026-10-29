#pragma once
#include "call_capture.hpp"
namespace labvoice {
struct SelectedAppCaptureOptions {
    std::string operationID, output;
    CallCaptureTarget target;
};
bool parseSelectedAppCaptureArguments(int argc, char** argv, SelectedAppCaptureOptions&, std::string& error);
int runSelectedAppCapture(int argc, char** argv,
    std::function<std::unique_ptr<CallCaptureSession>()> factory = makeNativeCallCaptureSession);
}
