#include "selected_app_capture_cli.hpp"
#include <cassert>
#include <iostream>
using namespace labvoice;
bool parse(std::string json, std::string output = "/tmp/own/output.wav") {
    std::vector<std::string> args{"audio-host", "--capture-selected-app", "--operation-id",
        "12345678-1234-1234-1234-123456789abc", "--target-json", json, "--output", output};
    std::vector<char*> pointers; for (auto& arg : args) pointers.push_back(arg.data());
    SelectedAppCaptureOptions options; std::string error;
    return parseSelectedAppCaptureArguments(static_cast<int>(args.size()), pointers.data(), options, error);
}
int main() {
    assert(parse(R"({"responsible_pid":123,"app_id":"own.app","processes":[{"object_id":4,"actual_pid":124}]})"));
    assert(!parse(R"({"responsible_pid":true,"app_id":"own.app","processes":[{"object_id":4,"actual_pid":124}]})"));
    assert(!parse(R"({"responsible_pid":1.5,"app_id":"own.app","processes":[{"object_id":4,"actual_pid":124}]})"));
    assert(!parse(R"({"responsible_pid":123,"app_id":"own.app","processes":[]})"));
    assert(!parse(R"({"responsible_pid":123,"app_id":"own.app","processes":[{"object_id":4,"actual_pid":124},{"object_id":5,"actual_pid":124}]})"));
    assert(!parse(R"({"responsible_pid":123,"app_id":"own.app\u0000other","processes":[{"object_id":4,"actual_pid":124}]})"));
    assert(!parse(R"({"responsible_pid":123,"app_id":"own.app","processes":[{"object_id":4,"actual_pid":124}],"global":true})"));
    assert(!parse(R"({"responsible_pid":123,"app_id":"own.app","processes":[{"object_id":4,"actual_pid":124}]})", "relative.wav"));
    std::cout << "Selected-app CLI admission parsing tests passed. No source constructed or started.\n";
}
