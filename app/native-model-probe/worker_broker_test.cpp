#include "worker_broker.hpp"
#include <cassert>
#include <cerrno>
#include <chrono>
#include <csignal>
#include <thread>
#include <iostream>
#include <sys/wait.h>
using namespace krisp_probe;
using namespace std::chrono_literals;
static WorkerLaunchConfig config(const char* node, const char* fixture, const char* mode) {
    WorkerLaunchConfig c;
    c.executable = node; c.arguments = {fixture,mode,"fixture-ready","000102030405060708090a0b0c0d0e0f"};
    c.expectedReadyLine = "fixture-ready\n";
    for (unsigned i=0;i<16;++i) c.token[i]=i;
    c.startupTimeout=1500ms; c.frameTimeout=150ms; c.shutdownTimeout=150ms;
    return c;
}
static void reaped(pid_t pid) { if (pid>0) { int status; errno=0; assert(waitpid(pid,&status,WNOHANG)==-1 && errno==ECHILD); } }
int main(int argc,char** argv) {
    assert(argc==3);
    const auto begin=std::chrono::steady_clock::now();
    {
        WorkerBroker b(config(argv[1],argv[2],"normal"));
        assert(b.start());
        std::array<float,480> input{},output{};
        for(unsigned batch=0;batch<100;++batch) {
            for(unsigned i=0;i<480;++i) input[i]=float(batch+i)*.125f;
            assert(b.process480(input,output));
            for(unsigned i=0;i<480;++i) assert(output[i]==input[i]*.5f);
        }
        assert(b.close()); assert(b.error().empty()); reaped(b.childPID());
    }
    for(auto mode:{"wrong-ready","oversized-ready","startup-crash","startup-stall","ignore-term"}) {
        auto c=config(argv[1],argv[2],mode); c.startupTimeout=150ms;
        WorkerBroker b(c); assert(!b.start()); assert(!b.error().empty()); reaped(b.childPID());
    }
    for(auto mode:{"processing-stall","malformed","crash","trailing"}) {
        WorkerBroker b(config(argv[1],argv[2],mode)); assert(b.start());
        std::array<float,480> input{},output{}; output.fill(7);
        assert(!b.process480(input,output));
        for(auto value:output) assert(value==0);
        const auto error=b.error(); assert(!error.empty());
        assert(!b.close() && b.error()==error); reaped(b.childPID());
    }
    for(auto mode:{"close-stall","nonzero-exit"}) {
        WorkerBroker b(config(argv[1],argv[2],mode)); assert(b.start());
        assert(!b.close()); reaped(b.childPID());
    }
    {
        auto c=config(argv[1],argv[2],"normal"); c.frameTimeout=0ms;
        WorkerBroker b(c); assert(!b.start() && b.childPID()==-1);
    }
    {
        WorkerBroker b(config(argv[1],argv[2],"normal")); assert(b.start()); assert(b.service());
        assert(kill(b.childPID(),SIGKILL)==0);
        auto until=std::chrono::steady_clock::now()+1500ms;
        while(b.service() && std::chrono::steady_clock::now()<until) std::this_thread::yield();
        assert(!b.error().empty()); reaped(b.childPID());
    }
    {
        pid_t pid;
        { WorkerBroker b(config(argv[1],argv[2],"normal")); assert(b.start()); pid=b.childPID(); }
        reaped(pid);
    }
    assert(std::chrono::steady_clock::now()-begin<15s);
    std::cout<<"worker broker tests passed\n";
}
