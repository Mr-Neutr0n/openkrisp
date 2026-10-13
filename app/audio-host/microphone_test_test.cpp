#include "microphone_test.hpp"
#include "control_protocol.hpp"
#include <rnnoise.h>
#include <algorithm>
#include <array>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstring>
#include <fcntl.h>
#include <fstream>
#include <iostream>
#include <sys/stat.h>
#include <thread>
#include <unistd.h>
using namespace labvoice;
namespace {
struct Fake final:MicrophoneBackend {
    std::string fail;
    std::shared_ptr<MicrophoneCapture> retained;
    unsigned registrations=0,starts=0,stops=0;
    MicrophoneSpec inspect(const std::string &uid) override {
        assert(uid=="selected-exact-uid");
        if(fail=="inspect") throw std::runtime_error("unsupported_physical_format");
        return {100,{2},{101}};
    }
    OSStatus watch(const std::shared_ptr<MicrophoneCapture> &c) override { retained=c;return fail=="watch"?-1:0; }
    OSStatus unwatch() override { if(fail=="unwatch") return -1;return 0; }
    OSStatus registerIO(const std::shared_ptr<MicrophoneCapture> &c,AudioDeviceIOProcID *io) override {
        retained=c; ++registrations;*io=reinterpret_cast<AudioDeviceIOProcID>(uintptr_t(1));return fail=="register"?-1:0;
    }
    OSStatus unregisterIO(AudioDeviceIOProcID) override { if(fail=="unregister") return -1;retained.reset();return 0; }
    OSStatus start(AudioDeviceIOProcID) override { ++starts;return fail=="start"?-1:0; }
    OSStatus stop(AudioDeviceIOProcID) override { ++stops;return fail=="stop"?-1:0; }
};
void feed(const std::shared_ptr<MicrophoneCapture> &c,uint32_t count,double time,float value=.25f) {
    std::vector<float> samples(count*2,value), output(count*2,.9f);
    for(uint32_t i=0;i<count;++i) samples[i*2+1]=-.7f; // channel1 is never captured
    AudioBufferList input{},out{};
    input.mNumberBuffers=out.mNumberBuffers=1;
    input.mBuffers[0]={2,count*8,samples.data()};out.mBuffers[0]={2,count*8,output.data()};
    AudioTimeStamp timestamp{};timestamp.mFlags=kAudioTimeStampSampleTimeValid;timestamp.mSampleTime=time;
    c->consume(&input,&timestamp,&out);
    for(float sample:output) assert(sample==0);
}
std::vector<unsigned char> read(const std::string &path) {
    std::ifstream file(path,std::ios::binary);return {std::istreambuf_iterator<char>(file),std::istreambuf_iterator<char>()};
}
uint32_t little(const unsigned char *p) { return p[0]|uint32_t(p[1])<<8|uint32_t(p[2])<<16|uint32_t(p[3])<<24; }
int16_t pcm(float value) { return int16_t(std::clamp<int32_t>(int32_t(std::lround(double(std::clamp(value,-1.f,1.f))*32768)),-32768,32767)); }
}
int main() {
    AudioStreamBasicDescription format{48000,kAudioFormatLinearPCM,kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked,8,1,8,2,32,0};
    assert(microphoneTestFormatSupported(format));
    auto changed=format;changed.mSampleRate=24000;assert(!microphoneTestFormatSupported(changed));
    changed=format;changed.mBitsPerChannel=16;assert(!microphoneTestFormatSupported(changed));
    changed=format;changed.mChannelsPerFrame=0;assert(!microphoneTestFormatSupported(changed));
    changed=format;changed.mChannelsPerFrame=65;assert(!microphoneTestFormatSupported(changed));
    changed=format;changed.mBytesPerFrame=4;assert(!microphoneTestFormatSupported(changed));
    changed=format;changed.mFormatFlags|=kAudioFormatFlagIsBigEndian;assert(!microphoneTestFormatSupported(changed));
    changed=format;changed.mFormatFlags|=kAudioFormatFlagIsNonInterleaved;changed.mBytesPerFrame=changed.mBytesPerPacket=4;
    assert(microphoneTestFormatSupported(changed));
    for(auto channels:{std::vector<UInt32>{},std::vector<UInt32>{0},std::vector<UInt32>{65},std::vector<UInt32>(17,1)}) {
        bool rejected=false;
        try { MicrophoneCapture invalid(MicrophoneSpec{100,channels,{101}}); }
        catch(const std::invalid_argument &) { rejected=true; }
        assert(rejected);
    }

    for(const char *failure:{"inspect","watch","register","start"}) {
        Fake backend;backend.fail=failure;MicrophoneSession session(backend);
        assert(!session.start("selected-exact-uid"));
        assert(session.stop());
    }
    for(const char *failure:{"stop","unregister","unwatch"}) {
        Fake backend;std::shared_ptr<MicrophoneCapture> capture;
        { MicrophoneSession session(backend);assert(session.start("selected-exact-uid"));capture=session.capture();
          backend.fail=failure;assert(!session.stop());assert(!capture->enabled); }
        const auto before=capture->frames.load();feed(capture,15,.25);assert(capture->frames==before);
        backend.fail.clear();backend.retained.reset();
    }
    auto capture=std::make_shared<MicrophoneCapture>(MicrophoneSpec{100,{2},{101}});capture->enabled=true;
    feed(capture,15,.25);feed(capture,15,15.25);assert(capture->frames==30 && !capture->fault);
    feed(capture,15,31.25);assert(capture->fault); // actual gap
    capture=std::make_shared<MicrophoneCapture>(MicrophoneSpec{100,{2},{101}});capture->enabled=true;
    feed(capture,microphoneTestCallbackLimit+1,.25);assert(capture->fault && capture->frames==0);
    capture=std::make_shared<MicrophoneCapture>(MicrophoneSpec{100,{2},{101}});capture->enabled=true;
    feed(capture,15,std::nan(""));assert(capture->fault && capture->frames==0);
    capture=std::make_shared<MicrophoneCapture>(MicrophoneSpec{100,{2},{101}});capture->enabled=true;
    feed(capture,15,.25,std::nan(""));assert(capture->fault && capture->frames==0);
    capture=std::make_shared<MicrophoneCapture>(MicrophoneSpec{100,{2},{101}});capture->enabled=true;
    for(uint32_t first=0;first<microphoneTestMaximum;first+=4096)
        feed(capture,4096,first+.25);
    assert(capture->frames==microphoneTestMaximum && capture->maximumReached && !capture->fault);
    feed(capture,15,0);assert(capture->frames==microphoneTestMaximum);
    char directory[]="/tmp/labvoice-mic-test-XXXXXX";assert(mkdtemp(directory));assert(chmod(directory,0700)==0);
    std::string error;assert(validateMicrophoneTestDirectory(directory,error));
    std::atomic<bool> cancelled{false};
    capture=std::make_shared<MicrophoneCapture>(MicrophoneSpec{100,{1},{101}});
    capture->frames=microphoneTestMinimum-1;
    assert(processMicrophoneTest(capture,directory,cancelled).error=="minimum_duration");
    capture->frames=microphoneTestMinimum+17;
    uint32_t seed=123;
    for(uint32_t i=0;i<capture->frames;++i) {seed=seed*1664525+1013904223;capture->samples[i]=(int32_t(seed>>8)-8388608)*(.2f/8388608.f);}
    const auto result=processMicrophoneTest(capture,directory,cancelled);
    assert(result.status=="completed" && result.frames==microphoneTestMinimum+17);
    auto raw=read(result.originalPath),processed=read(result.processedPath);
    assert(raw.size()==44+result.frames*2 && processed.size()==raw.size());
    assert(little(raw.data()+24)==48000 && little(raw.data()+40)==result.frames*2 && raw[22]==1 && raw[34]==16);
    struct stat info{};assert(stat(result.originalPath.c_str(),&info)==0 && (info.st_mode&0777)==0600);
    assert(stat(result.processedPath.c_str(),&info)==0 && (info.st_mode&0777)==0600);
    DenoiseState *engine=rnnoise_create(nullptr);assert(engine);
    std::array<float,480> input{},output{};
    for(uint32_t first=0;first<result.frames;first+=480) {
        input.fill(0);const auto count=std::min<uint32_t>(480,result.frames-first);
        for(uint32_t i=0;i<count;++i) input[i]=capture->samples[first+i]*32768.f;
        rnnoise_process_frame(engine,output.data(),input.data());
        for(uint32_t i=0;i<count;++i) {
            const int16_t expected=pcm(output[i]/32768.f);
            const auto offset=44+(first+i)*2;
            assert(raw[offset]==(uint16_t(pcm(capture->samples[first+i]))&255));
            assert(raw[offset+1]==(uint16_t(pcm(capture->samples[first+i]))>>8));
            assert(processed[offset]==(uint16_t(expected)&255) && processed[offset+1]==(uint16_t(expected)>>8));
        }
    }
    rnnoise_destroy(engine);
    assert(processMicrophoneTest(capture,directory,cancelled).status=="failed"); // never overwrite
    cancelled=true;assert(processMicrophoneTest(capture,directory,cancelled).status=="cancelled");
    assert(!validateMicrophoneTestDirectory(directory,error));
    unlink(result.originalPath.c_str());unlink(result.processedPath.c_str());
    assert(chmod(directory,0755)==0 && !validateMicrophoneTestDirectory(directory,error));
    chmod(directory,0700);rmdir(directory);
    const std::string operation="12345678-1234-1234-1234-123456789abc";
    MicrophoneTestProtocol protocol(operation);bool stop=false,cancel=false;
    auto apply=[&](bool cancelling) {if(cancelling){cancel=true;return std::string{};}return std::string("minimum_duration");};
    auto command=[&](const char *type,unsigned sequence){return "{\"type\":\""+std::string(type)+"\",\"operationID\":\""+operation+"\",\"sequence\":"+std::to_string(sequence)+"}";};
    assert(protocol.handle(command("test-stop",1),apply).find("minimum_duration")!=std::string::npos && !stop && !cancel);
    assert(protocol.handle(command("test-cancel",1),apply).find("stale_sequence")!=std::string::npos && !cancel);
    assert(protocol.handle(command("test-cancel",2),apply).find("\"accepted\":true")!=std::string::npos && cancel);
    std::cout<<"PASS: synthetic channel0 capture, duplex silence, fractional/gap/nonfinite/bounds/max/min, lifecycle failures/retention, private exclusive mono pair, exact direct RNNoise aligned reference and command/cancellation. No microphone opened.\n";
}
