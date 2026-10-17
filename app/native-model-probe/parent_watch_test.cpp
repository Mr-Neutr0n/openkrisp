#include "parent_watch.hpp"
#include <cassert>
#include <cerrno>
#include <csignal>
#include <iostream>
#include <poll.h>
#include <sys/wait.h>

namespace {
void writeAll(int fd, const void* data, std::size_t size) {
    const auto* bytes = static_cast<const char*>(data);
    while(size) {
        const auto count=write(fd,bytes,size);
        if(count<0 && errno==EINTR) continue;
        assert(count>0); bytes+=count; size-=static_cast<std::size_t>(count);
    }
}
void readAll(int fd,void* data,std::size_t size) {
    auto* bytes=static_cast<char*>(data);
    while(size) {
        pollfd item{fd,POLLIN,0}; assert(poll(&item,1,3000)>0);
        const auto count=read(fd,bytes,size);
        if(count<0 && errno==EINTR) continue;
        assert(count>0); bytes+=count; size-=static_cast<std::size_t>(count);
    }
}
// EOF on the child's private pipe proves it exited. macOS cannot waitpid a
// grandchild after its intermediary parent exits. No subreaper or signal change.
void parentLoss(bool stopped, bool killParent) {
    int observation[2], metadata[2], release[2], parentControl[2];
    assert(pipe(observation)==0 && pipe(metadata)==0 && pipe(release)==0 && pipe(parentControl)==0);
    const auto intermediate=fork(); assert(intermediate>=0);
    if(intermediate==0) {
        close(observation[0]); close(metadata[0]); close(release[1]); close(parentControl[1]);
        const auto expected=getpid();
        const auto child=fork(); if(child<0) _exit(80);
        if(child==0) {
            close(metadata[1]); close(parentControl[0]);
            krisp_probe::ParentWatch watch(expected);
            if(stopped) { watch.stop(); watch.stop(); }
            const char ready='R'; writeAll(observation[1],&ready,1);
            char command;
            // With an active guard, main stays blocked after parent death.
            // With a stopped guard, root explicitly releases this child later.
            while(read(release[0],&command,1)<0 && errno==EINTR) {}
            if(!stopped || getppid()==expected) _exit(81);
            const char survived='S'; writeAll(observation[1],&survived,1);
            _exit(0);
        }
        close(observation[1]); close(release[0]);
        writeAll(metadata[1],&child,sizeof child); close(metadata[1]);
        if(killParent) for(;;) pause();
        char command;
        while(read(parentControl[0],&command,1)<0 && errno==EINTR) {}
        _exit(0);
    }
    close(observation[1]); close(metadata[1]); close(release[0]); close(parentControl[0]);
    pid_t child=-1; readAll(metadata[0],&child,sizeof child); close(metadata[0]); assert(child>1);
    char ready; readAll(observation[0],&ready,1); assert(ready=='R');
    if(killParent) assert(kill(intermediate,SIGKILL)==0);
    else { const char command='X'; writeAll(parentControl[1],&command,1); }
    close(parentControl[1]);
    int status; assert(waitpid(intermediate,&status,0)==intermediate);
    if(stopped) {
        pollfd item{observation[0],POLLIN,0}; assert(poll(&item,1,150)==0);
        const char command='X'; writeAll(release[1],&command,1);
        char survived; readAll(observation[0],&survived,1); assert(survived=='S');
    }
    pollfd item{observation[0],POLLIN,0};
    const int result=poll(&item,1,3000);
    if(result<=0) {
        // Closing our pipe releases the blocked fixture without signaling a
        // reparented PID that could already have been reused.
        close(release[1]);
        pollfd cleanup{observation[0],POLLIN,0};
        (void)poll(&cleanup,1,1000);
        assert(false && "Guarded child failed to exit within deadline");
    }
    char byte; assert(read(observation[0],&byte,1)==0);
    close(observation[0]); close(release[1]);
}
}
int main() {
    for(pid_t wrong:{pid_t(0),pid_t(1),getpid()}) {
        bool rejected=false;
        try { krisp_probe::ParentWatch watch(wrong); }
        catch(const std::invalid_argument&) { rejected=true; }
        assert(rejected);
    }
    {
        const auto start=std::chrono::steady_clock::now();
        krisp_probe::ParentWatch watch(getppid()); watch.stop(); watch.stop();
        assert(std::chrono::steady_clock::now()-start<std::chrono::seconds(1));
    }
    parentLoss(false,true);
    parentLoss(false,false);
    parentLoss(true,true);
    std::cout<<"parent watch tests passed\n";
}
