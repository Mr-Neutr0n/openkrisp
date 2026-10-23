#include "aec_worker_broker.hpp"
#include <cassert>
#include <cerrno>
#include <sys/wait.h>
#include <iostream>
using namespace krisp_probe;
AECWorkerLaunchConfig config(const char* exe,const char*mode){AECWorkerLaunchConfig c;c.executable=exe;c.arguments={mode};c.expectedReadyLine="aec-fixture\n";c.token[0]=7;c.frameTimeout=std::chrono::milliseconds(100);c.shutdownTimeout=std::chrono::milliseconds(200);return c;}
void reaped(pid_t pid){int status;errno=0;assert(waitpid(pid,&status,WNOHANG)==-1&&errno==ECHILD);}
int main(int argc,char**argv){assert(argc==2);
 {AECWorkerBroker b(config(argv[1],"normal"));assert(b.start());aec_wire::Frame in,out;in.epoch=3;in.microphoneTiming={.25,100.5,1,3};in.referenceTiming={-20.75,200.25,3,3};
 for(unsigned i=0;i<20;++i){in.sequence=i;in.microphone.fill(float(i));in.reference.fill(2);assert(b.process480(in,out));assert(out.output[0]==float(i)+2);in.microphoneTiming.inputSampleOrigin+=480;in.microphoneTiming.outputSampleOrigin+=480;in.microphoneTiming.hostTime++;in.referenceTiming.inputSampleOrigin+=480;in.referenceTiming.outputSampleOrigin+=480;in.referenceTiming.hostTime++;}assert(b.close());reaped(b.childPID());}
 for(auto mode:{"crash","stall","timing","malformed","trailing"}){AECWorkerBroker b(config(argv[1],mode));assert(b.start());aec_wire::Frame in,out;out.output.fill(7);assert(!b.process480(in,out));for(auto x:out.output)assert(x==0);reaped(b.childPID());}
 {AECWorkerBroker b(config(argv[1],"normal"));assert(b.start());aec_wire::Frame in,out;in.microphoneTiming.flags=1;assert(b.process480(in,out));in.sequence=1;assert(!b.process480(in,out));reaped(b.childPID());}
 for(int lane=0;lane<3;++lane){AECWorkerBroker b(config(argv[1],"normal"));assert(b.start());aec_wire::Frame in,out;in.microphoneTiming={.25,20.5,100,3};in.referenceTiming={-4.75,88.25,200,3};assert(b.process480(in,out));in.sequence=1;in.microphoneTiming.inputSampleOrigin+=480;in.microphoneTiming.outputSampleOrigin+=480;in.microphoneTiming.hostTime++;in.referenceTiming.inputSampleOrigin+=480;in.referenceTiming.outputSampleOrigin+=480;in.referenceTiming.hostTime++;
 if(lane==0)in.referenceTiming.inputSampleOrigin+=.5;
 if(lane==1)in.referenceTiming.hostTime--;
 if(lane==2)in.epoch++;
 assert(!b.process480(in,out));reaped(b.childPID());}
 for(auto mode:{"close-stall","close-trailing","close-epoch","nonzero-exit"}){AECWorkerBroker b(config(argv[1],mode));assert(b.start());assert(!b.close());reaped(b.childPID());}
 {AECWorkerBroker b(config(argv[1],"startup-crash"));assert(!b.start());reaped(b.childPID());}
 {pid_t child;{AECWorkerBroker b(config(argv[1],"normal"));assert(b.start());child=b.childPID();assert(b.service());}reaped(child);}
 std::cout<<"AEC broker tests passed\n";
}
