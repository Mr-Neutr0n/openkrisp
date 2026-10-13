// Test-only injected source. The real CLI/controller and RNNoise/export path run;
// no CoreAudio backend method is invoked and no physical microphone is opened.
#include "microphone_test.hpp"
#include "control_protocol.hpp"
#include <array>
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <chrono>
#include <thread>
using namespace labvoice;
class Synthetic final:public MicrophoneBackend {
    std::shared_ptr<MicrophoneCapture> capture_;
    std::thread producer_;
    const std::string failure_ = std::getenv("LABVOICE_MIC_FIXTURE_FAILURE") ? std::getenv("LABVOICE_MIC_FIXTURE_FAILURE") : "";
  public:
    ~Synthetic() override { if(producer_.joinable()) producer_.join(); }
    MicrophoneSpec inspect(const std::string &) override { return {100, failure_=="zero-layout" ? std::vector<UInt32>{} : failure_=="oversized-layout" ? std::vector<UInt32>{65} : std::vector<UInt32>{1},{101}}; }
    OSStatus watch(const std::shared_ptr<MicrophoneCapture> &capture) override { capture_=capture;return 0; }
    OSStatus unwatch() override { return failure_=="unwatch"?-1:0; }
    OSStatus registerIO(const std::shared_ptr<MicrophoneCapture> &capture,AudioDeviceIOProcID *io) override {
        capture_=capture;*io=reinterpret_cast<AudioDeviceIOProcID>(uintptr_t(1));return 0;
    }
    OSStatus unregisterIO(AudioDeviceIOProcID) override { return failure_=="unregister"?-1:0; }
    OSStatus start(AudioDeviceIOProcID) override {
        if(failure_=="no-callback") return 0;
        if(failure_=="slow-start") std::this_thread::sleep_for(std::chrono::milliseconds(300));
        auto capture=capture_;
        const auto failure=failure_;
        producer_=std::thread([capture,failure] {
            std::array<float,4096> values{};uint32_t seed=17;
            const uint32_t target=failure=="maximum"?microphoneTestMaximum:microphoneTestMinimum;
            for(uint32_t first=0;first<target && capture->enabled.load();first+=4096) {
                auto count=std::min<uint32_t>(4096,target-first);
                for(uint32_t i=0;i<count;++i) {
                    seed=seed*1664525+1013904223;
                    values[i]=.15f*std::sin(float(first+i)*.071f)+(int32_t(seed>>8)-8388608)*(.04f/8388608.f);
                }
                AudioBufferList input{};input.mNumberBuffers=1;input.mBuffers[0]={1,count*4,values.data()};
                AudioTimeStamp time{};time.mFlags=kAudioTimeStampSampleTimeValid;time.mSampleTime=first+.25+(failure=="gap" && first?1:0);
                if(failure=="oversized-callback") input.mBuffers[0].mDataByteSize=4097*4;
                capture->consume(&input,&time,nullptr);
                if(failure=="slow-capture") std::this_thread::sleep_for(std::chrono::milliseconds(first?10:2000));
            }
            if(failure=="topology") { capture->fault=true;capture->enabled=false; }
        });return 0;
    }
    OSStatus stop(AudioDeviceIOProcID) override { if(producer_.joinable()) producer_.join();return failure_=="stop"?-1:0; }
};
int main(int argc,char **argv) {
    if((argc!=3 && argc!=4) || !validOperationID(argv[1])) return 64;
    Synthetic backend;
    return runMicrophoneTestWithBackend(backend,argc==4?argv[3]:"synthetic-microphone",argv[2],argv[1],!std::getenv("LABVOICE_MIC_FIXTURE_NO_STDIN"));
}
