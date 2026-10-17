#include "installed_noise_adapter.hpp"
#include <CommonCrypto/CommonDigest.h>
#include <cerrno>
#include <chrono>
#include <filesystem>
#include <fcntl.h>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <sys/stat.h>
#include <thread>
#include <unistd.h>
#include <vector>

namespace {
constexpr std::size_t rate=48000, inputSamples=48000, callbackFrames=512, budgetFrames=2;
constexpr const char* nodeSHA="1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040";
constexpr const char* fixtureSHA="6ef4b0e40cf74b1bbe3b97b5d36ee79a2e42b9e7eadb9240afe92a2fc2fc7b5b";
struct FD {
    int value;
    explicit FD(int descriptor):value(descriptor){if(value<0)throw std::runtime_error("File open failed");}
    ~FD(){if(value>=0)::close(value);}
    FD(const FD&)=delete;
};
bool same(const struct stat& a,const struct stat& b) {
    return a.st_dev==b.st_dev && a.st_ino==b.st_ino && a.st_size==b.st_size &&
        a.st_mtimespec.tv_sec==b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec==b.st_mtimespec.tv_nsec &&
        a.st_ctimespec.tv_sec==b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec==b.st_ctimespec.tv_nsec;
}
std::string digestText(const unsigned char* bytes) {
    constexpr char hex[]="0123456789abcdef";std::string text;
    for(unsigned i=0;i<CC_SHA256_DIGEST_LENGTH;++i){text+=hex[bytes[i]>>4];text+=hex[bytes[i]&15];}return text;
}
std::string hashBytes(const std::vector<std::uint8_t>& bytes) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes.data(),static_cast<CC_LONG>(bytes.size()),digest);return digestText(digest);
}
std::string hashFile(const std::string& path) {
    struct stat before{},opened{},after{},current{};
    if(lstat(path.c_str(),&before) || !S_ISREG(before.st_mode) || before.st_size<0 || before.st_size>1073741824)
        throw std::runtime_error("Expected bounded regular nonsymlink file");
    FD file(open(path.c_str(),O_RDONLY|O_NOFOLLOW|O_CLOEXEC));
    if(fstat(file.value,&opened) || !same(before,opened))throw std::runtime_error("File identity changed before hashing");
    CC_SHA256_CTX hash;CC_SHA256_Init(&hash);
    std::array<std::uint8_t,65536> scratch{};std::uint64_t total=0;
    for(;;) {
        const auto count=read(file.value,scratch.data(),scratch.size());
        if(count<0 && errno==EINTR)continue;
        if(count<0)throw std::runtime_error("File hash read failed");
        if(!count)break;
        total+=static_cast<std::uint64_t>(count);
        if(total>static_cast<std::uint64_t>(opened.st_size))throw std::runtime_error("File grew during hash");
        CC_SHA256_Update(&hash,scratch.data(),static_cast<CC_LONG>(count));
    }
    if(total!=static_cast<std::uint64_t>(opened.st_size) || fstat(file.value,&after) ||
        lstat(path.c_str(),&current) || !same(opened,after) || !same(after,current))
        throw std::runtime_error("File changed during hash");
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(digest,&hash);return digestText(digest);
}
std::vector<std::uint8_t> encode(const std::vector<float>& values) {
    std::vector<std::uint8_t> bytes(values.size()*4);
    for(std::size_t i=0;i<values.size();++i)krisp_probe::wire::write(bytes.data()+i*4,std::bit_cast<std::uint32_t>(values[i]),4);
    return bytes;
}
std::string json(const std::string& value){return krisp_probe::installed_worker_detail::json(value);}
void checkDestination(const std::string& path) {
    krisp_probe::installed_worker_detail::path(path);
    struct stat info{};
    if(lstat(path.c_str(),&info)==0 || errno!=ENOENT)throw std::runtime_error("Output directory must not exist");
    const auto parent=std::filesystem::path(path).parent_path();
    if(lstat(parent.c_str(),&info) || !S_ISDIR(info.st_mode))throw std::runtime_error("Output parent must be a nonsymlink directory");
}
struct Output {std::string name;std::vector<std::uint8_t> bytes;};
void publish(const std::string& path,const std::vector<Output>& outputs) {
    if(mkdir(path.c_str(),0700))throw std::runtime_error("Exclusive output directory creation failed");
    FD directory(open(path.c_str(),O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC));
    struct stat owned{};if(fstat(directory.value,&owned))throw std::runtime_error("Output directory identity unavailable");
    struct OwnedFile {std::string name;dev_t dev;ino_t ino;};std::vector<OwnedFile> files;
    try {
        if(fchmod(directory.value,0700))throw std::runtime_error("Output directory permissions failed");
        for(const auto& output:outputs) {
            FD file(openat(directory.value,output.name.c_str(),O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,0600));
            struct stat info{};if(fstat(file.value,&info))throw std::runtime_error("Output file identity unavailable");
            files.push_back({output.name,info.st_dev,info.st_ino});
            if(fchmod(file.value,0600))throw std::runtime_error("Output file permissions failed");
            std::size_t offset=0;
            while(offset<output.bytes.size()) {
                const auto count=write(file.value,output.bytes.data()+offset,output.bytes.size()-offset);
                if(count<0 && errno==EINTR)continue;
                if(count<=0)throw std::runtime_error("Output write failed");
                offset+=static_cast<std::size_t>(count);
            }
            if(fsync(file.value))throw std::runtime_error("Output sync failed");
            struct stat current{};
            if(fstatat(directory.value,output.name.c_str(),&current,AT_SYMLINK_NOFOLLOW) ||
                current.st_dev!=info.st_dev || current.st_ino!=info.st_ino || current.st_size!=static_cast<off_t>(output.bytes.size()))
                throw std::runtime_error("Output file changed");
            const auto descriptor=file.value;file.value=-1;
            if(::close(descriptor))throw std::runtime_error("Output close failed");
        }
        struct stat current{};
        if(lstat(path.c_str(),&current) || current.st_dev!=owned.st_dev || current.st_ino!=owned.st_ino)
            throw std::runtime_error("Output directory changed");
    } catch(...) {
        for(const auto& file:files) {
            struct stat current{};
            if(fstatat(directory.value,file.name.c_str(),&current,AT_SYMLINK_NOFOLLOW)==0 &&
                current.st_dev==file.dev && current.st_ino==file.ino)unlinkat(directory.value,file.name.c_str(),0);
        }
        struct stat current{};
        if(lstat(path.c_str(),&current)==0 && current.st_dev==owned.st_dev && current.st_ino==owned.st_ino)rmdir(path.c_str());
        throw;
    }
}
}
int main(int argc,char** argv) {
    std::shared_ptr<labvoice::InstalledNoiseAdapter> adapter;
    try {
        if(argc!=12)throw std::invalid_argument("Expected node runtimeDir addon outboundModel inboundModel library adapterSHA workerSHA sessionSHA protocolSHA newOutputDir");
        const std::string node=argv[1],runtime=argv[2],addon=argv[3],outbound=argv[4],inbound=argv[5],library=argv[6],destination=argv[11];
        checkDestination(destination);
        const std::array<std::string,4> runtimeNames{"native-probe.node","audio_worker.cjs","worker_session.cjs","worker_protocol.cjs"};
        std::array<std::string,4> expected{};
        for(unsigned i=0;i<expected.size();++i){expected[i]=argv[7+i];krisp_probe::installed_worker_detail::digest(expected[i]);}
        for(const auto* value:{&node,&runtime,&addon,&outbound,&inbound,&library})krisp_probe::installed_worker_detail::path(*value);
        std::vector<std::pair<std::string,std::string>> identities{{node,nodeSHA},{addon,labvoice::InstalledNoiseAdapter::addonSha256()},
            {outbound,krisp_probe::installedOutboundModelSHA256},{inbound,krisp_probe::installedInboundModelSHA256}};
        for(unsigned i=0;i<runtimeNames.size();++i)identities.push_back({runtime+"/"+runtimeNames[i],expected[i]});
        for(const auto& identity:identities)if(hashFile(identity.first)!=identity.second)throw std::runtime_error("Prelaunch artifact identity mismatch");
        std::vector<float> microphone(inputSamples),monitor(inputSamples*2);
        std::uint32_t state=0x4c564e43;
        for(std::size_t i=0;i<inputSamples;++i) {
            state^=state<<13;state^=state>>17;state^=state<<5;
            const double noise=(static_cast<double>(state)/4294967296.-.5)*.08;
            auto triangle=[&](unsigned period){return 1.-4.*std::abs(static_cast<double>(i%period)/period-.5);};
            microphone[i]=static_cast<float>(triangle(160)*.15+triangle(60)*.05+noise);
            // Alternate a doubled signal between channels. Float32 averaging
            // yields the exact mono fixture and detects selecting only one side.
            const bool left=(i/480)%2==0;
            monitor[2*i]=left?microphone[i]*2.f:0.f;
            monitor[2*i+1]=left?0.f:microphone[i]*2.f;
            if((monitor[2*i]+monitor[2*i+1])/2.f!=microphone[i])throw std::runtime_error("Synthetic average mismatch");
        }
        auto inputMonoBytes=encode(microphone),inputStereoBytes=encode(monitor);
        if(hashBytes(inputMonoBytes)!=fixtureSHA)throw std::runtime_error("Synthetic fixture identity mismatch");
        labvoice::InstalledNoiseOptions options;options.schedulingBudgetFrames=budgetFrames;
        krisp_probe::InstalledWorkerSettings settings;
        settings.nodePath=node;settings.workerPath=runtime+"/audio_worker.cjs";settings.addonPath=addon;
        settings.adapterPath=runtime+"/native-probe.node";settings.libraryPath=library;
        settings.nodeSha256=nodeSHA;settings.adapterSha256=expected[0];settings.modelPath=outbound;
        options.microphone=settings;
        settings.modelRole=krisp_probe::InstalledModelRole::inbound;settings.modelSha256=krisp_probe::installedInboundModelSHA256;settings.modelPath=inbound;
        options.speaker=settings;
        labvoice::Layout layout;layout.currentCallbackFrames=layout.maximumCallbackFrames=callbackFrames;
        using Clock=std::chrono::steady_clock;const auto start=Clock::now();
        std::string error;adapter=labvoice::InstalledNoiseAdapter::create(layout,options,error);
        if(!adapter)throw std::runtime_error("Dual adapter startup failed: "+error);
        const auto ready=Clock::now();
        const auto delay=adapter->microphoneDelaySamples();
        if(delay!=adapter->speakerDelaySamples() || delay%480)throw std::runtime_error("Lane delay contract mismatch");
        const auto total=inputSamples+delay,requiredFrames=total/480;
        std::vector<float> collectedMic(total),collectedStereo(total*2);
        std::array<float,callbackFrames> micBlock{};std::array<float,callbackFrames*2> stereoBlock{};
        std::int64_t callbackMaxUs=0,latenessMaxUs=0;const auto begin=Clock::now();
        for(std::size_t position=0;position<total;) {
            const auto count=std::min(callbackFrames,total-position);
            for(std::size_t i=0;i<count;++i) {
                micBlock[i]=position+i<inputSamples?microphone[position+i]:0;
                stereoBlock[2*i]=position+i<inputSamples?monitor[(position+i)*2]:0;
                stereoBlock[2*i+1]=position+i<inputSamples?monitor[(position+i)*2+1]:0;
            }
            const auto scheduled=begin+std::chrono::nanoseconds(position*1000000000ULL/rate);
            std::this_thread::sleep_until(scheduled);const auto entered=Clock::now();
            latenessMaxUs=std::max(latenessMaxUs,std::chrono::duration_cast<std::chrono::microseconds>(entered-scheduled).count());
            const bool ok=labvoice::InstalledNoiseAdapter::process(adapter.get(),micBlock.data(),stereoBlock.data(),
                collectedMic.data()+position,collectedStereo.data()+position*2,static_cast<UInt32>(count));
            callbackMaxUs=std::max(callbackMaxUs,std::chrono::duration_cast<std::chrono::microseconds>(Clock::now()-entered).count());
            if(!ok)throw std::runtime_error("Paced dual callback failed: "+adapter->error());
            position+=count;
        }
        const auto drainDeadline=Clock::now()+std::chrono::seconds(3);
        while(adapter->healthy() && (adapter->microphoneProcessedFrames()<requiredFrames || adapter->speakerProcessedFrames()<requiredFrames) && Clock::now()<drainDeadline)
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        const auto micFrames=adapter->microphoneProcessedFrames(),speakerFrames=adapter->speakerProcessedFrames();
        if(!adapter->healthy() || micFrames!=requiredFrames || speakerFrames!=requiredFrames)throw std::runtime_error("Dual worker drain failed");
        for(std::size_t i=0;i<total;++i) {
            if(!std::isfinite(collectedMic[i]) || !std::isfinite(collectedStereo[2*i]) ||
                !std::isfinite(collectedStereo[2*i+1]) || collectedStereo[2*i]!=collectedStereo[2*i+1])
                throw std::runtime_error("Dual output contract failed");
            if(i<delay && (collectedMic[i]!=0 || collectedStereo[2*i]!=0))throw std::runtime_error("Initial delay was not silent");
        }
        if(!adapter->stop())throw std::runtime_error("Both worker teardown confirmations required: "+adapter->error());
        adapter.reset();
        for(const auto& identity:identities)if(hashFile(identity.first)!=identity.second)throw std::runtime_error("Postrun artifact identity mismatch");
        const auto stopped=Clock::now();
        std::vector<float> alignedMic(collectedMic.begin()+delay,collectedMic.end());
        std::vector<float> alignedStereo(collectedStereo.begin()+delay*2,collectedStereo.end());
        auto outputMonoBytes=encode(alignedMic),outputStereoBytes=encode(alignedStereo);
        std::ostringstream metadata;
        metadata<<"{\"status\":\"completed\",\"observation\":\"paced-dual-adapter-cpu-simulation\",\"inputFrames\":100,\"paddedFrames\":"<<delay/480
            <<",\"microphoneProcessedFrames\":"<<micFrames<<",\"speakerProcessedFrames\":"<<speakerFrames<<",\"samplesPerLane\":48000,\"sampleRate\":48000,\"maximumCallbackFrames\":512,\"schedulingBudgetFrames\":2,\"bufferDelaySamples\":"<<delay
            <<",\"speakerChannelsIdentical\":true,\"teardownComplete\":true,\"startupMs\":"<<std::chrono::duration_cast<std::chrono::milliseconds>(ready-start).count()
            <<",\"runAndStopMs\":"<<std::chrono::duration_cast<std::chrono::milliseconds>(stopped-ready).count()<<",\"callbackMaxUs\":"<<callbackMaxUs<<",\"schedulingMaxLatenessUs\":"<<latenessMaxUs
            <<",\"inputMicrophoneSHA256\":"<<json(hashBytes(inputMonoBytes))<<",\"inputMonitorSHA256\":"<<json(hashBytes(inputStereoBytes))
            <<",\"outputMicrophoneSHA256\":"<<json(hashBytes(outputMonoBytes))<<",\"outputMonitorSHA256\":"<<json(hashBytes(outputStereoBytes))<<",\"artifactsBeforeAndAfter\":[";
        for(std::size_t i=0;i<identities.size();++i){if(i)metadata<<',';metadata<<"{\"path\":"<<json(identities[i].first)<<",\"sha256\":"<<json(identities[i].second)<<'}';}
        metadata<<"],\"limits\":[\"CPU pacing is not CoreAudio acceptance.\",\"Padding removes transport delay only; no model-tail claim.\",\"Production workers require sandbox EPERM before native loading.\"]}\n";
        const auto text=metadata.str();
        publish(destination,{{"input-microphone.f32le",std::move(inputMonoBytes)},{"input-monitor.f32le",std::move(inputStereoBytes)},
            {"output-microphone.f32le",std::move(outputMonoBytes)},{"output-monitor.f32le",std::move(outputStereoBytes)},
            {"metadata.json",std::vector<std::uint8_t>(text.begin(),text.end())}});
        std::cout<<text;return 0;
    } catch(const std::exception& error) {
        if(adapter)(void)adapter->stop();
        std::cerr<<"Dual adapter probe failed: "<<error.what()<<'\n';return 1;
    }
}
