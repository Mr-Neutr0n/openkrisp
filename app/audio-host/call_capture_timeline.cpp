#include "call_capture_timeline.hpp"
#include "call_capture.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <deque>
#include <limits>
#include <numbers>
#include <stdexcept>
#include <vector>

namespace labvoice {
struct CallCaptureTimeline::State {
    static constexpr unsigned radius=32, taps=64, maximumBlocks=64;
    struct Block {std::vector<float> samples;uint32_t frames;AudioTimeStamp time;uint64_t sourceOffset;};
    struct Lane {
        double nominalRate;unsigned channels;std::deque<Block> blocks;size_t segment=0;
        uint64_t sourceFrames=0,startupFrames=0;double maximumDrift=0;AudioTimeStamp first{},last{};
    };
    Lane app, mic;
    double ticks;
    Write write;
    std::array<double,taps> window{};
    bool started=false,failed=false,finished=false;
    long double origin=0;
    uint64_t outputFrames=0;
    State(double rate,double frequency,Write sink):app{rate,2,{},0,0,0,0,{},{}},mic{48000,1,{},0,0,0,0,{},{}},ticks(frequency),write(std::move(sink)) {
        if(!std::isfinite(rate)||rate<8000||rate>192000||!std::isfinite(ticks)||ticks<=0||!write)throw std::invalid_argument("invalid_call_timeline_configuration");
        for(unsigned i=0;i<taps;++i)window[i]=.42-.5*std::cos(2*std::numbers::pi*i/(taps-1))+.08*std::cos(4*std::numbers::pi*i/(taps-1));
    }
    bool fail(const char* reason,std::string& error){failed=true;error=reason;return false;}
    long double time()const{return origin+static_cast<long double>(outputFrames)*ticks/48000;}
    bool cover(Lane& lane,long double t) {
        while(lane.segment+1<lane.blocks.size()&&t>=lane.blocks[lane.segment+1].time.mHostTime)++lane.segment;
        return lane.segment+1<lane.blocks.size()&&t>=lane.blocks[lane.segment].time.mHostTime;
    }
    float sample(const Lane& lane,ptrdiff_t frame,unsigned channel)const {
        ptrdiff_t segment=ptrdiff_t(lane.segment);
        if(frame<0){--segment;frame+=lane.blocks[size_t(segment)].frames;}
        else if(frame>=lane.blocks[size_t(segment)].frames){frame-=lane.blocks[size_t(segment)].frames;++segment;}
        return lane.blocks[size_t(segment)].samples[size_t(frame)*lane.channels+channel];
    }
    long double sourcePosition(const Lane& lane,long double host)const {
        for(size_t i=0;i+1<lane.blocks.size();++i)if(host<lane.blocks[i+1].time.mHostTime){
            const auto& block=lane.blocks[i];return block.sourceOffset+std::clamp((host-block.time.mHostTime)*block.frames/(lane.blocks[i+1].time.mHostTime-block.time.mHostTime),static_cast<long double>(0),static_cast<long double>(block.frames));
        }
        return lane.blocks.back().sourceOffset;
    }
    std::array<double,2> resample(const Lane& lane,long double host)const {
        const auto& block=lane.blocks[lane.segment];const auto& next=lane.blocks[lane.segment+1];
        const long double duration=next.time.mHostTime-block.time.mHostTime;
        const double position=double((host-block.time.mHostTime)*block.frames/duration);
        const auto center=ptrdiff_t(std::floor(position));
        const double observedRate=double(block.frames*ticks/duration);
        const double cutoff=.90*std::min(1.,48000/observedRate);
        const double step=std::numbers::pi*cutoff;
        double x=double(center)-31-position,angle=step*x;
        double sine=std::sin(angle),cosine=std::cos(angle),sinStep=std::sin(step),cosStep=std::cos(step),normal=0;
        std::array<double,2> value{};
        for(unsigned tap=0;tap<taps;++tap,x+=1){
            const double weight=window[tap]*(std::abs(x)<1e-12?cutoff:sine/(std::numbers::pi*x));
            normal+=weight;
            for(unsigned channel=0;channel<lane.channels;++channel)value[channel]+=weight*sample(lane,center-31+tap,channel);
            const double nextSine=sine*cosStep+cosine*sinStep;cosine=cosine*cosStep-sine*sinStep;sine=nextSine;
        }
        for(auto& channel:value)channel/=normal;
        return value;
    }
    void discardPast(Lane& lane){while(lane.segment>1){lane.blocks.pop_front();--lane.segment;}}
    bool pump(std::string& error){
        if(app.blocks.size()<2||mic.blocks.size()<2)return true;
        if(!started){
            const auto firstSafe=[&](const Lane& lane){return static_cast<long double>(lane.blocks[0].time.mHostTime)+radius*static_cast<long double>(lane.blocks[1].time.mHostTime-lane.blocks[0].time.mHostTime)/lane.blocks[0].frames;};
            origin=std::max(firstSafe(app),firstSafe(mic));started=true;

        }
        std::array<float,1024*2> output{};uint32_t count=0;
        while(cover(app,time())&&cover(mic,time())){
            if(!outputFrames){app.startupFrames=uint64_t(std::ceil(sourcePosition(app,origin)));mic.startupFrames=uint64_t(std::ceil(sourcePosition(mic,origin)));}
            if(outputFrames>=callCaptureWavMaximumFrames)return fail("capture_riff32_capacity",error);
            const auto application=resample(app,time()),microphone=resample(mic,time());
            // Explicit reconstruction mix policy, independent of original DSP.
            output[2*count]=float(.5*application[0]+.5*microphone[0]);
            output[2*count+1]=float(.5*application[1]+.5*microphone[0]);
            if(!std::isfinite(output[2*count])||!std::isfinite(output[2*count+1]))return fail("nonfinite_call_timeline_mix",error);
            ++count;++outputFrames;
            if(count==1024){if(!write(output.data(),count,error)){failed=true;return false;}count=0;}
            discardPast(app);discardPast(mic);
        }
        if(count&&!write(output.data(),count,error)){failed=true;return false;}
        return true;
    }
};
CallCaptureTimeline::CallCaptureTimeline(double rate,double ticks,Write sink):state_(std::make_unique<State>(rate,ticks,std::move(sink))){}
CallCaptureTimeline::~CallCaptureTimeline()=default;
bool CallCaptureTimeline::append(bool microphone,const float* samples,uint32_t frames,const AudioTimeStamp& stamp,std::string& error){
    auto& s=*state_;auto& lane=microphone?s.mic:s.app;
    if(s.failed||s.finished)return s.fail("call_timeline_not_active",error);
    if(!samples||frames<State::taps||frames>4096||(stamp.mFlags&(kAudioTimeStampSampleTimeValid|kAudioTimeStampHostTimeValid))!=(kAudioTimeStampSampleTimeValid|kAudioTimeStampHostTimeValid)||!std::isfinite(stamp.mSampleTime)||stamp.mSampleTime<0||stamp.mSampleTime>9007199254740991.-frames)return s.fail("invalid_call_timeline_block",error);
    for(uint64_t i=0;i<uint64_t(frames)*lane.channels;++i)if(!std::isfinite(samples[i]))return s.fail("nonfinite_call_timeline_sample",error);
    if(!lane.blocks.empty()){
        const auto& previous=lane.blocks.back();
        if(std::abs(stamp.mSampleTime-previous.time.mSampleTime-previous.frames)>1e-6||stamp.mHostTime<=previous.time.mHostTime)return s.fail("call_timeline_clock_discontinuity",error);
        const double rate=previous.frames*s.ticks/(stamp.mHostTime-previous.time.mHostTime),drift=std::abs(rate/lane.nominalRate-1);
        if(!std::isfinite(rate)||drift>.01)return s.fail("call_timeline_host_clock_gap_or_rate_change",error);
        lane.maximumDrift=std::max(lane.maximumDrift,drift*1e6);
    }
    if(lane.blocks.size()>=State::maximumBlocks)return s.fail("call_timeline_lane_overrun",error);
    if(!lane.sourceFrames)lane.first=stamp;lane.last=stamp;
    lane.blocks.push_back({std::vector<float>(samples,samples+uint64_t(frames)*lane.channels),frames,stamp,lane.sourceFrames});lane.sourceFrames+=frames;
    return s.pump(error);
}
bool CallCaptureTimeline::finish(CallCaptureTimelineStats& stats,std::string& error){
    auto& s=*state_;if(s.failed)return false;if(s.finished)return s.fail("call_timeline_already_finished",error);
    if(!s.pump(error))return false;s.finished=true;
    if(!s.started||!s.outputFrames)return s.fail("call_timeline_no_common_coverage",error);
    stats.outputFrames=s.outputFrames;stats.firstHostTime=uint64_t(std::llround(s.origin));stats.endHostTime=uint64_t(std::llround(s.time()));
    stats.appSourceFrames=s.app.sourceFrames;stats.microphoneSourceFrames=s.mic.sourceFrames;
    stats.appStartupFrames=s.app.startupFrames;stats.microphoneStartupFrames=s.mic.startupFrames;
    stats.appTailFrames=s.app.sourceFrames-uint64_t(std::floor(s.sourcePosition(s.app,s.time())));stats.microphoneTailFrames=s.mic.sourceFrames-uint64_t(std::floor(s.sourcePosition(s.mic,s.time())));
    stats.appFirstSampleTime=s.app.first.mSampleTime;stats.appLastSampleTime=s.app.last.mSampleTime;stats.microphoneFirstSampleTime=s.mic.first.mSampleTime;stats.microphoneLastSampleTime=s.mic.last.mSampleTime;
    stats.appFirstHostTime=s.app.first.mHostTime;stats.appLastHostTime=s.app.last.mHostTime;stats.microphoneFirstHostTime=s.mic.first.mHostTime;stats.microphoneLastHostTime=s.mic.last.mHostTime;
    stats.appMaximumDriftPPM=s.app.maximumDrift;stats.microphoneMaximumDriftPPM=s.mic.maximumDrift;
    return true;
}
}
