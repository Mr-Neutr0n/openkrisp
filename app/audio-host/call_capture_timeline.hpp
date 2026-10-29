#pragma once
#include <CoreAudio/CoreAudio.h>
#include <cstdint>
#include <functional>
#include <memory>
#include <string>

namespace labvoice {
struct CallCaptureTimelineStats {
    uint64_t outputFrames=0, firstHostTime=0, endHostTime=0;
    uint64_t appSourceFrames=0, microphoneSourceFrames=0;
    uint64_t appStartupFrames=0, microphoneStartupFrames=0;
    uint64_t appTailFrames=0, microphoneTailFrames=0;
    double appMaximumDriftPPM=0, microphoneMaximumDriftPPM=0;
    double appFirstSampleTime=0,appLastSampleTime=0,microphoneFirstSampleTime=0,microphoneLastSampleTime=0;
    uint64_t appFirstHostTime=0,appLastHostTime=0,microphoneFirstHostTime=0,microphoneLastHostTime=0;
};
// Off-RT only. Each next callback supplies the preceding block's ending host
// anchor. Source clocks are mapped piecewise to a shared 48 kHz host timeline.
// A 64-tap windowed-sinc interpolator supplies bandlimited drift correction.
class CallCaptureTimeline {
public:
    using Write=std::function<bool(const float*,uint32_t,std::string&)>;
    CallCaptureTimeline(double appRate,double ticksPerSecond,Write);
    ~CallCaptureTimeline();
    bool append(bool microphone,const float* samples,uint32_t frames,const AudioTimeStamp&,std::string&);
    bool finish(CallCaptureTimelineStats&,std::string&);
private:
    struct State;
    std::unique_ptr<State> state_;
};
}
