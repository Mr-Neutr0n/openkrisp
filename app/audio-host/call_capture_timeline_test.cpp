#include "call_capture_timeline.hpp"
#include <algorithm>
#include <cassert>
#include <cmath>
#include <iostream>
#include <numbers>
#include <vector>
using namespace labvoice;
namespace {
constexpr double ticks=1e9;constexpr uint64_t base=1000000000000ULL;
struct Event{bool mic;std::vector<float> samples;uint32_t frames;AudioTimeStamp time;};
std::vector<Event> events(double appRate,double duration,double micDelay,bool drift,double frequency=0){
 std::vector<Event> all;
 for(bool mic:{false,true}){
  const double rate=mic?48000:appRate;const uint32_t frames=mic?256:512;uint64_t host=base+uint64_t((mic?micDelay:0)*ticks);double sample=mic?5000:1000;unsigned block=0;
  while(double(host-base)/ticks<duration){
   const double ppm=drift?(mic?-600+300*std::sin(block*.08):900+600*std::sin(block*.035)):0;
   const uint64_t next=host+uint64_t(std::llround(frames*ticks/(rate*(1+ppm/1e6))));
   Event e{mic,{},frames,{}};e.time.mHostTime=host;e.time.mSampleTime=sample;e.time.mFlags=kAudioTimeStampHostTimeValid|kAudioTimeStampSampleTimeValid;
   e.samples.resize(frames*(mic?1:2));
   for(uint32_t i=0;i<frames;++i){const double t=(double(host-base)+double(next-host)*i/frames)/ticks;const float value=frequency?float(mic?0:std::sin(2*std::numbers::pi*frequency*t)):float(std::exp(-std::pow((t-.2)/.00012,2)));
    if(mic)e.samples[i]=value;else{e.samples[2*i]=value;e.samples[2*i+1]=0;}}
   all.push_back(std::move(e));host=next;sample+=frames;++block;
  }
 }
 std::stable_sort(all.begin(),all.end(),[](const auto&a,const auto&b){return a.time.mHostTime<b.time.mHostTime;});return all;
}
struct Output{std::vector<float> samples;CallCaptureTimelineStats stats;};
Output render(double rate,bool drift,double frequency=0,double micDelay=.003,double duration=.4){
 Output output;std::string error;CallCaptureTimeline timeline(rate,ticks,[&](const float*p,uint32_t n,std::string&){output.samples.insert(output.samples.end(),p,p+n*2);return true;});
 for(const auto&e:events(rate,duration,micDelay,drift,frequency))assert(timeline.append(e.mic,e.samples.data(),e.frames,e.time,error));
 assert(timeline.finish(output.stats,error));assert(output.samples.size()==output.stats.outputFrames*2);return output;
}
}
int main(){
 for(double rate:{44100.,48000.,192000.}){
  const auto output=render(rate,true);size_t peak=0;for(size_t i=0;i<output.samples.size()/2;++i)if(output.samples[2*i]>output.samples[2*peak])peak=i;
  const double physicalPeak=double(output.stats.firstHostTime-base)/ticks+double(peak)/48000;
  assert(std::abs(physicalPeak-.2)<2./48000);assert(output.samples[2*peak]>.9f);assert(output.stats.appMaximumDriftPPM>800&&output.stats.microphoneMaximumDriftPPM>100);
  assert(output.stats.appStartupFrames>=32&&output.stats.microphoneStartupFrames>=32);assert(output.stats.appTailFrames>=64&&output.stats.microphoneTailFrames>=64);
 }
 for(double frequency:{1000.,36000.}){
  const auto output=render(192000,false,frequency,0,.2);double energy=0;for(size_t i=512;i<output.samples.size()/2;++i)energy+=std::pow(output.samples[2*i],2);const double rms=std::sqrt(energy/(output.samples.size()/2-512));
  if(frequency==1000)assert(rms>.34&&rms<.36);else assert(rms<.001);
 }
 {std::vector<float> app(256*2),mic(256);std::string error;CallCaptureTimeline timeline(48000,ticks,[](const float*,uint32_t,std::string&){return true;});AudioTimeStamp time{};time.mFlags=kAudioTimeStampHostTimeValid|kAudioTimeStampSampleTimeValid;time.mHostTime=base;time.mSampleTime=0;assert(timeline.append(false,app.data(),256,time,error));time.mHostTime+=5333333;time.mSampleTime=257;assert(!timeline.append(false,app.data(),256,time,error));}
 {std::string error;CallCaptureTimelineStats stats;CallCaptureTimeline timeline(48000,ticks,[](const float*,uint32_t,std::string&){return true;});assert(!timeline.finish(stats,error)&&error=="call_timeline_no_common_coverage");}
 // An unmatched longer app tail must include all cropped anchored blocks.
 {std::string error;CallCaptureTimelineStats stats;CallCaptureTimeline timeline(48000,ticks,[](const float*,uint32_t,std::string&){return true;});auto all=events(48000,.1,0,false);for(const auto&e:all)if(!e.mic||e.time.mHostTime<base+50000000)assert(timeline.append(e.mic,e.samples.data(),e.frames,e.time,error));assert(timeline.finish(stats,error));assert(stats.appTailFrames>2000&&stats.microphoneTailFrames==256);}
 std::cout<<"Call-capture timeline drift, impulse, anti-alias and crop tests passed.\n";
}
