#include "call_capture.hpp"
#include <AudioToolbox/AudioToolbox.h>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <sys/stat.h>
#include <unistd.h>
using namespace labvoice;
namespace {
AudioStreamBasicDescription source(double rate=44100){AudioStreamBasicDescription f{};f.mSampleRate=rate;f.mFormatID=kAudioFormatLinearPCM;f.mFormatFlags=kAudioFormatFlagIsFloat|kAudioFormatFlagIsPacked;f.mBytesPerPacket=f.mBytesPerFrame=8;f.mFramesPerPacket=1;f.mChannelsPerFrame=2;f.mBitsPerChannel=32;return f;}
}
int main(){
 @autoreleasepool {
    char folder[]="/tmp/openkrisp-capture-writer-XXXXXX";assert(mkdtemp(folder));assert(!chmod(folder,0700));
    const std::string parent=folder,path=parent+"/output.wav";std::string error;
    {
        auto writer=makeCallCaptureWavWriter();assert(writer->open(path,source(),error));
        std::vector<float> samples(441*2);
        for(size_t i=0;i<441;++i){samples[2*i]=float(std::sin(i*.02)*.1);samples[2*i+1]=-samples[2*i];}
        for(int block=0;block<10;++block)assert(writer->write(samples.data(),441,error));
        uint64_t frames=0;assert(writer->close(frames,error));assert(frames==4800);
        AudioFileID file=nullptr;NSURL* url=[NSURL fileURLWithPath:[NSString stringWithUTF8String:path.c_str()]];
        assert(AudioFileOpenURL((__bridge CFURLRef)url,kAudioFileReadPermission,kAudioFileWAVEType,&file)==noErr);
        AudioStreamBasicDescription actual{};UInt32 size=sizeof actual;assert(AudioFileGetProperty(file,kAudioFilePropertyDataFormat,&size,&actual)==noErr);
        assert(actual.mSampleRate==48000&&actual.mChannelsPerFrame==2&&actual.mBitsPerChannel==16&&actual.mBytesPerFrame==4);
        assert(AudioFileClose(file)==noErr);struct stat info{};assert(!lstat(path.c_str(),&info)&&S_ISREG(info.st_mode)&&(info.st_mode&0777)==0600);
    }
    {auto writer=makeCallCaptureWavWriter();assert(!writer->open(path,source(),error));}
    {auto writer=makeCallCaptureWavWriter();const auto link=parent+"/link.wav";assert(!symlink(path.c_str(),link.c_str()));assert(!writer->open(link,source(),error));assert(!unlink(link.c_str()));}
    {
        auto writer=makeCallCaptureWavWriter();const auto swap=parent+"/swap.wav",moved=parent+"/moved.wav";
        assert(writer->open(swap,source(48000),error));float audio[8]{};assert(writer->write(audio,4,error));
        assert(!rename(swap.c_str(),moved.c_str()));{std::ofstream replacement(swap);replacement<<"replacement";}
        uint64_t frames=0;assert(!writer->close(frames,error));assert(error=="capture_file_identity_or_sync_failed");
        std::ifstream replacement(swap);std::string content;replacement>>content;assert(content=="replacement");
        assert(!unlink(swap.c_str()));assert(!unlink(moved.c_str()));
    }
    assert(!unlink(path.c_str()));assert(!rmdir(parent.c_str()));
 }
 std::cout<<"Selected-app WAV conversion and file-identity tests passed.\n";
}
