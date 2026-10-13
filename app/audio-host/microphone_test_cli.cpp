#include "microphone_test.hpp"
#include "control_protocol.hpp"
#include <cerrno>
#include <chrono>
#include <csignal>
#include <iostream>
#include <poll.h>
#include <thread>
#include <unistd.h>
namespace labvoice {
namespace {
volatile std::sig_atomic_t signalCancelled=0;
void cancelSignal(int) { signalCancelled=1; }
void input(ControlFramer &framer, MicrophoneTestProtocol &protocol, std::atomic<bool> &cancel,
           bool &stop, const std::shared_ptr<MicrophoneCapture> &capture) {
    if(framer.needsRead()) {
        pollfd descriptor{STDIN_FILENO,POLLIN,0};
        int ready=poll(&descriptor,1,0);
        if(ready<0 && errno!=EINTR) cancel=true;
        else if(ready>0 && (descriptor.revents&(POLLIN|POLLHUP))) {
            char data[maximumControlLine]; ssize_t count=read(STDIN_FILENO,data,sizeof data);
            if(count>0) framer.append(std::string_view(data,size_t(count)));
            else if(count==0) framer.finish();
            else if(errno!=EINTR) cancel=true;
        } else if(ready>0 && (descriptor.revents&(POLLERR|POLLNVAL))) cancel=true;
    }
    for(const auto &line:framer.take(8)) {
        std::cout<<protocol.handle(line.error.empty()?std::string_view(line.text):std::string_view{},[&](bool cancelling) {
            if(cancelling) { cancel=true; return std::string{}; }
            if(cancel.load()) return std::string("test_cancelled");
            if(capture->frames.load()<microphoneTestMinimum) return std::string("minimum_duration");
            stop=true; return std::string{};
        })<<std::endl;
    }
    if(framer.ended()) cancel=true;
}
}
int runMicrophoneTestWithBackend(MicrophoneBackend &backend, const std::string &uid, const std::string &directory,
                                const std::string &operation, bool stdinEnabled) {
    signalCancelled=0;
    const auto previousTerm=std::signal(SIGTERM,cancelSignal),previousInt=std::signal(SIGINT,cancelSignal);
    struct Restore {
        decltype(previousTerm) term, interrupt;
        ~Restore() { std::signal(SIGTERM,term); std::signal(SIGINT,interrupt); }
    } restore{previousTerm,previousInt};
    const pid_t parent=getppid();
    std::string error;
    if(!validateMicrophoneTestDirectory(directory,error)) {
        std::cout<<microphoneTestResultJSON(operation,{"failed",error,{},{},0})<<std::endl; return 1;
    }
    MicrophoneSession session(backend);
    if(signalCancelled || parent<=1 || getppid()!=parent) {
        std::cout<<microphoneTestResultJSON(operation,{"cancelled",{},{},{},0})<<std::endl; return 0;
    }
    if(!session.start(uid)) {
        const bool cancelled=signalCancelled || getppid()!=parent;
        std::cout<<microphoneTestResultJSON(operation,{cancelled?"cancelled":"failed",session.error(),{},{},0})<<std::endl; return cancelled?0:1;
    }
    auto capture=session.capture();
    if(signalCancelled || parent<=1 || getppid()!=parent) {
        const bool stopped=session.stop();
        std::cout<<microphoneTestResultJSON(operation,{stopped?"cancelled":"failed",stopped?std::string{}:session.error(),{},{},capture->frames.load()})<<std::endl;
        return stopped?0:1;
    }
    std::atomic<bool> cancel{false}; bool stop=false;
    ControlFramer framer; MicrophoneTestProtocol protocol(operation);
    std::cout<<"{\"event\":\"test_started\",\"operationID\":"<<jsonString(operation)<<",\"input_uid\":"<<jsonString(uid)
             <<",\"sampleRate\":48000,\"channels\":1,\"minimumFrames\":"<<microphoneTestMinimum
             <<",\"maximumFrames\":"<<microphoneTestMaximum<<"}"<<std::endl;
    auto lastProgress=std::chrono::steady_clock::now()-std::chrono::milliseconds(250);
    auto lastFrameProgress=std::chrono::steady_clock::now();
    UInt32 lastFrames=capture->frames.load();
    bool capturingPhase=true;
    std::string captureFailure;
    auto service=[&] {
        if(signalCancelled || parent<=1 || getppid()!=parent) cancel=true;
        if(stdinEnabled) input(framer,protocol,cancel,stop,capture);
        auto now=std::chrono::steady_clock::now();
        const auto frames=capture->frames.load();
        if(frames!=lastFrames) { lastFrames=frames;lastFrameProgress=now; }
        if(capturingPhase && !cancel.load() && !stop && now-lastFrameProgress>=std::chrono::seconds(3)) {
            captureFailure="microphone_callback_stalled";capture->fault=true;capture->enabled=false;
        }
        if(now-lastProgress>=std::chrono::milliseconds(250)) {
            std::cout<<"{\"event\":\"test_progress\",\"operationID\":"<<jsonString(operation)
                     <<",\"frames\":"<<capture->frames.load()<<"}"<<std::endl; lastProgress=now;
        }
    };
    while(!cancel.load() && !stop && !capture->fault.load() && !capture->maximumReached.load()) {
        service(); std::this_thread::sleep_for(std::chrono::milliseconds(20));
    }
    service();
    capturingPhase=false;
    const bool safelyStopped=session.stop();
    if(signalCancelled || parent<=1 || getppid()!=parent) cancel=true;
    MicrophoneTestResult result; result.frames=capture->frames.load();
    if(!safelyStopped) { result.status="failed"; result.error=session.error(); }
    else if(cancel.load()) result.status="cancelled";
    else if(capture->fault.load()) { result.status="failed"; result.error=captureFailure.empty()?"capture_clock_shape_or_topology_fault":captureFailure; }
    else {
        struct Work { std::atomic<bool> ready{false}; MicrophoneTestResult result; };
        auto work=std::make_shared<Work>(); auto cancelled=std::make_shared<std::atomic<bool>>(false);
        std::thread processing([work,capture,directory,cancelled] {
            work->result=processMicrophoneTest(capture,directory,*cancelled); work->ready.store(true);
        });
        bool cancelObserved=false;
        auto deadline=std::chrono::steady_clock::time_point::max();
        while(!work->ready.load()) {
            service();
            if(cancel.load()) {
                cancelled->store(true);
                if(!cancelObserved) { cancelObserved=true; deadline=std::chrono::steady_clock::now()+std::chrono::seconds(2); }
                if(std::chrono::steady_clock::now()>=deadline) break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        }
        service(); // Observed cancellation wins over an already-ready result.
        if(cancel.load()) cancelled->store(true);
        if(work->ready.load()) { processing.join(); result=work->result; }
        else { processing.detach(); result.status="cancelled"; result.error="processing_cancel_pending"; }
        if(cancel.load()) { result.status="cancelled"; result.originalPath.clear(); result.processedPath.clear(); }
    }
    if(result.status!="failed" && (signalCancelled || parent<=1 || getppid()!=parent)) { result.status="cancelled"; result.originalPath.clear(); result.processedPath.clear(); }
    if(result.status=="completed" && capture->fault.load()) { result.status="failed"; result.error="capture_topology_fault"; result.originalPath.clear(); result.processedPath.clear(); }
    std::cout<<microphoneTestResultJSON(operation,result)<<std::endl;
    return result.status=="failed"?1:0;
}
int runMicrophoneTest(const std::string &uid,const std::string &directory,const std::string &operation,bool stdinEnabled) {
    CoreAudioMicrophoneBackend backend;
    return runMicrophoneTestWithBackend(backend,uid,directory,operation,stdinEnabled);
}
} // namespace labvoice
