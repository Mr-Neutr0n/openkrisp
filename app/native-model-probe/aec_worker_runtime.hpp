#pragma once
#include "aec_worker_broker.hpp"
#include <algorithm>
#include <array>
#include <bit>
#include <cerrno>
#include <chrono>
#include <cstring>
#include <fcntl.h>
#include <iomanip>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <cstdio>
#include <vector>

namespace krisp_probe::aec_runtime {
inline void require(bool value, const char* text) { if (!value) throw std::runtime_error(text); }
inline bool same(const struct stat& a, const struct stat& b) {
    return S_ISREG(b.st_mode) && a.st_dev==b.st_dev && a.st_ino==b.st_ino && a.st_size==b.st_size &&
        a.st_mtimespec.tv_sec==b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec==b.st_mtimespec.tv_nsec &&
        a.st_ctimespec.tv_sec==b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec==b.st_ctimespec.tv_nsec;
}
struct Input {
    const char* path;
    int fd = -1;
    struct stat identity{};
    std::vector<float> values;
    Input(const char* source, std::size_t count) : path(source), values(count) {
        static_assert(sizeof(float)==4 && std::endian::native==std::endian::little);
        require(path[0]=='/', "input path must be absolute");
        fd=::open(path,O_RDONLY|O_NOFOLLOW|O_CLOEXEC|O_NONBLOCK);
        require(fd>=0,"input open failed");
        try {
            require(::fstat(fd,&identity)==0 && S_ISREG(identity.st_mode) &&
                    identity.st_size==static_cast<off_t>(count*4),"input size/type rejected");
            auto* cursor=reinterpret_cast<char*>(values.data());
            std::size_t remaining=count*4;
            while(remaining) {
                const auto n=::read(fd,cursor,remaining);
                if(n<0 && errno==EINTR)continue;
                require(n>0,"input read failed"); remaining-=static_cast<std::size_t>(n);cursor+=n;
            }
            for(float value:values)require(std::isfinite(value),"nonfinite input");
            require(unchanged(),"input changed during read");
        } catch(...) {::close(fd);fd=-1;throw;}
    }
    bool unchanged() const {
        struct stat descriptor{},named{};
        return ::fstat(fd,&descriptor)==0 && ::lstat(path,&named)==0 && same(identity,descriptor) && same(identity,named);
    }
    ~Input(){if(fd>=0)::close(fd);}
    Input(const Input&)=delete;
};
struct Publication {
    std::string path;
    struct stat identity{};
    int directoryFD=-1;
    bool published=false, identityCaptured=false;
    struct File { const char* name;struct stat identity{}; };
    std::vector<File> files;
    bool namedMatches() const {
        struct stat actual{};
        return identityCaptured && ::lstat(path.c_str(),&actual)==0 && S_ISDIR(actual.st_mode) &&
            actual.st_dev==identity.st_dev && actual.st_ino==identity.st_ino;
    }
    bool matches() const {
        struct stat actual{},held{};
        return directoryFD>=0 && ::fstat(directoryFD,&held)==0 && ::lstat(path.c_str(),&actual)==0 &&
            S_ISDIR(actual.st_mode) && actual.st_dev==identity.st_dev && actual.st_ino==identity.st_ino &&
            held.st_dev==identity.st_dev && held.st_ino==identity.st_ino;
    }
    explicit Publication(const char* destination) {
        require(destination[0]=='/',"output directory must be absolute");
        std::array<unsigned char,16> random{};arc4random_buf(random.data(),random.size());
        path=std::string(destination)+".staging-";
        constexpr char hex[]="0123456789abcdef";
        for(auto value:random){path+=hex[value>>4];path+=hex[value&15];}
        require(::mkdir(path.c_str(),0700)==0,"staging directory creation failed");
        try {
            require(::lstat(path.c_str(),&identity)==0 && S_ISDIR(identity.st_mode),"staging directory identity failed");
            identityCaptured=true;
            directoryFD=::open(path.c_str(),O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
            require(directoryFD>=0 && matches(),"staging directory open/identity failed");
            require(::fchmod(directoryFD,0700)==0,"staging directory mode failed");
            files.reserve(2);
        }catch(...){
            if(namedMatches())::rmdir(path.c_str());
            if(directoryFD>=0){::close(directoryFD);directoryFD=-1;}
            throw;
        }
    }
    void write(const char* name,const void* data,std::size_t size) {
        File file{name,{}};
        int fd=::openat(directoryFD,name,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,0600);
        require(fd>=0,"exclusive sample/metadata creation failed");
        if(::fstat(fd,&file.identity)!=0){::close(fd);throw std::runtime_error("output identity failed");}
        files.push_back(file);
        try {
            require(::fchmod(fd,0600)==0,"output mode failed");
            const auto* cursor=static_cast<const char*>(data);
            while(size){const auto n=::write(fd,cursor,size);if(n<0 && errno==EINTR)continue;
                require(n>0,"output write failed");size-=static_cast<std::size_t>(n);cursor+=n;}
            require(::fsync(fd)==0,"output sync failed");
            require(::fstat(fd,&files.back().identity)==0,"written output identity failed");
            const int owned=fd;fd=-1;require(::close(owned)==0,"output close failed");
        }catch(...){if(fd>=0)::close(fd);throw;}
    }
    void publish(const char* destination) {
        require(matches(),"staging directory changed");
        for(const auto& file:files){struct stat actual{};
            require(::fstatat(directoryFD,file.name,&actual,AT_SYMLINK_NOFOLLOW)==0 && same(file.identity,actual),
                    "staged file identity changed");}
        require(::renamex_np(path.c_str(),destination,RENAME_EXCL)==0,"exclusive output directory publication failed");
        published=true;
    }
    ~Publication(){
        if(!published && directoryFD>=0){
            for(const auto& file:files){struct stat actual{};
                if(::fstatat(directoryFD,file.name,&actual,AT_SYMLINK_NOFOLLOW)==0 &&
                   actual.st_dev==file.identity.st_dev && actual.st_ino==file.identity.st_ino)
                    ::unlinkat(directoryFD,file.name,0);}
            if(matches())::rmdir(path.c_str());
        }
        if(directoryFD>=0)::close(directoryFD);
    }
};
// Build executes only after complete bounded input validation. Production passes
// its fixed-vendor builder. Own tests supply their independent synthetic launch.
template<class Build>
std::string run(const char* microphonePath,const char* referencePath,const char* outputDirectory,Build build) {
    using Clock=std::chrono::steady_clock;
    const auto started=Clock::now();
    Input microphone(microphonePath,480000),reference(referencePath,960000);
    require(outputDirectory[0]=='/',"output directory must be absolute");
    struct stat destination{};
    require(::lstat(outputDirectory,&destination)!=0 && errno==ENOENT,"output directory must not exist");
    aec_wire::Token token{};arc4random_buf(token.data(),token.size());
    AECWorkerBroker broker(build(token));
    if(!broker.start())throw std::runtime_error(broker.error());
    const auto ready=Clock::now();
    std::vector<float> output(480000);
    std::array<double,1000> latency{};
    for(std::size_t index=0;index<1000;++index){
        aec_wire::Frame request,response;request.epoch=1;request.sequence=index;
        request.microphoneTiming={static_cast<double>(index*480),static_cast<double>(index*480),0,1};
        request.referenceTiming=request.microphoneTiming;
        std::copy_n(microphone.values.begin()+index*480,480,request.microphone.begin());
        std::copy_n(reference.values.begin()+index*960,960,request.reference.begin());
        const auto before=Clock::now();
        if(!broker.process480(request,response))throw std::runtime_error(broker.error());
        latency[index]=std::chrono::duration<double,std::micro>(Clock::now()-before).count();
        for(float value:response.output)require(std::isfinite(value),"nonfinite worker output");
        std::copy(response.output.begin(),response.output.end(),output.begin()+index*480);
    }
    const auto processed=Clock::now();
    if(!broker.close())throw std::runtime_error(broker.error());
    const auto closed=Clock::now();
    require(microphone.unchanged() && reference.unchanged(),"input changed during worker run");
    std::sort(latency.begin(),latency.end());
    const auto milliseconds=[](auto delta){return std::chrono::duration<double,std::milli>(delta).count();};
    std::ostringstream json;json<<std::setprecision(17)
        <<"{\"frames\":1000,\"samples\":480000,\"referenceSamples\":960000,\"forwardRate\":48000,\"forwardChannels\":1,\"referenceRate\":48000,\"referenceChannels\":2,"
        <<"\"teardownComplete\":true,\"timingPolicy\":\"synthetic-contiguous\",\"realtimePaced\":false,"
        <<"\"startupMs\":"<<milliseconds(ready-started)<<",\"processingMs\":"<<milliseconds(processed-ready)
        <<",\"shutdownMs\":"<<milliseconds(closed-processed)<<",\"totalMs\":"<<milliseconds(closed-started)
        <<",\"requestLatencyUs\":{\"p50\":"<<latency[499]<<",\"p95\":"<<latency[949]<<",\"p99\":"<<latency[989]<<",\"max\":"<<latency[999]<<"}}\n";
    const auto metadata=json.str();
    Publication publication(outputDirectory);
    publication.write("worker-output.f32le",output.data(),output.size()*sizeof(float));
    publication.write("metadata.json",metadata.data(),metadata.size());
    require(microphone.unchanged() && reference.unchanged(),"input changed during publication");
    publication.publish(outputDirectory);
    return metadata;
}
} // namespace krisp_probe::aec_runtime
