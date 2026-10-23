#include "aec_microphone_chain_probe.hpp"
#include <cassert>
#include <cstring>
#include <filesystem>
#include <iostream>
using namespace labvoice;
using namespace std::chrono_literals;
namespace {
struct OwnFactory {
    std::string library,digest,mode;
    bool* invoked=nullptr;
    std::shared_ptr<krisp_probe::AECDuplexWorker> operator()(krisp_probe::AECWorkerLaunchConfig config,std::string& error,krisp_probe::AECDuplexBufferingConfig buffering)const {
        if(invoked)*invoked=true;
        assert(config.executable=="/usr/bin/sandbox-exec" && config.arguments.size()==7);
        assert(config.arguments[0]=="-p" && config.arguments[1]=="(version 1) (allow default) (deny network*)");
        assert(config.arguments[4]==krisp_probe::installedAECLibrarySHA256);
        assert(config.arguments[6]==std::to_string(getpid()));
        assert(config.expectedReadyLine==std::string("OKAEC1 ")+krisp_probe::installedAECLibrarySHA256+" 48000 1 48000 2\n");
        assert(config.environment==std::vector<std::string>{"PATH=/usr/bin:/bin"});
        assert(config.startupTimeout==30s && config.frameTimeout==500ms && config.shutdownTimeout==1s);
        config.arguments[3]=library;config.arguments[4]=digest;
        config.expectedReadyLine="OKAEC1 "+digest+" 48000 1 48000 2\n";
        if(mode=="wrong-ready")config.expectedReadyLine="wrong\n";
        if(mode=="forward")config.environment.push_back("OPENKRISP_AEC_FIXTURE_FAILURE=forward");
        if(mode=="mismatch")++buffering.schedulingBudgetFrames;
        return krisp_probe::AECDuplexWorker::create(std::move(config),error,buffering);
    }
};
}
static krisp_probe::InstalledWorkerSettings ncSettings() {
    krisp_probe::InstalledWorkerSettings s;
    s.nodePath="/fixture/node";s.workerPath="/fixture/worker";s.addonPath="/fixture/addon";
    s.modelPath="/fixture/model";s.adapterPath="/fixture/adapter";s.libraryPath="/fixture/library";
    s.nodeSha256=std::string(64,'a');s.adapterSha256=std::string(64,'b');return s;
}
namespace {
void writeFloats(const std::string& path,const std::vector<float>& values) {
    const int fd=open(path.c_str(),O_WRONLY|O_CREAT|O_TRUNC,0600);assert(fd>=0);
    const auto* cursor=reinterpret_cast<const char*>(values.data());std::size_t remaining=values.size()*4;
    while(remaining){const auto n=write(fd,cursor,remaining);assert(n>0);cursor+=n;remaining-=static_cast<std::size_t>(n);}assert(close(fd)==0);
}
krisp_probe::WorkerLaunchConfig ownNC(krisp_probe::WorkerLaunchConfig built,const char* node,const char* script,const std::string& mode,const std::string& trace) {
    assert(built.expectedReadyLine.find(" outbound ")!=std::string::npos);
    std::string token=krisp_probe::installed_worker_detail::tokenHex(built.token);
    built.executable=node;built.arguments={script,token,mode,trace};built.environment={"PATH=/usr/bin:/bin"};
    built.expectedReadyLine="stateful-nc-ready\n";built.startupTimeout=2s;built.frameTimeout=500ms;built.shutdownTimeout=500ms;return built;
}
bool exists(const std::string& path){struct stat s{};return lstat(path.c_str(),&s)==0;}
std::vector<float> readFloats(const std::string& path){krisp_probe::aec_runtime::Input input(path.c_str(),480000);return input.values;}
}
int main(int argc,char** argv) {
    assert(argc==6); // Own AEC worker/library/SHA, Node, own stateful NC script.
    char directory[]="/tmp/own-chain-probe-XXXXXX";assert(mkdtemp(directory));
    const std::string root=directory,trace=root+"/trace";
    labvoice::chain_probe::Options options;
    options.chain.aec.settings={argv[1],krisp_probe::installed_aec_worker_detail::hashWorker(argv[1]),"/unread/vendor/libAEC"};
    options.chain.microphone=ncSettings();
    options.microphonePath=root+"/mic";options.referencePath=root+"/reference";options.directAECPath=root+"/direct";
    std::vector<float> mic(480000),reference(960000),direct(480000);
    for(std::size_t i=0;i<mic.size();++i){mic[i]=float(i%997)/4096;const auto frame=i/480;const float l=float(frame%17)/128,r=-float(frame%11)/256;reference[2*i]=l;reference[2*i+1]=r;direct[i]=mic[i]-(l+r)/2;}
    writeFloats(options.microphonePath,mic);writeFloats(options.referencePath,reference);writeFloats(options.directAECPath,direct);
    OwnFactory aec{argv[2],argv[3],""};
    auto makeSeams=[&](std::string ncMode="normal",std::string baselineMode="normal") {
        labvoice::chain_probe::Seams seams;seams.aec=aec;
        seams.nc=[&,ncMode](auto launch,auto& error,auto buffering){return krisp_probe::ProviderWorker::create(ownNC(std::move(launch),argv[4],argv[5],ncMode,trace),error,buffering);};
        seams.baseline=[&,baselineMode](auto launch){return ownNC(std::move(launch),argv[4],argv[5],baselineMode,trace);};return seams;
    };
    for(auto maximum:{480ul,4096ul}) {
        options.maximumCallbackFrames=maximum;options.outputDirectory=root+"/output-"+std::to_string(maximum);
        const auto result=labvoice::chain_probe::run(options,makeSeams());assert(result.comparisonEqual);
        assert(result.metadata.find("\"comparisonEqual\":true")!=std::string::npos && result.metadata.find("\"mismatchSamples\":0")!=std::string::npos);
        auto output=readFloats(options.outputDirectory+"/chain-output.f32le"),baseline=readFloats(options.outputDirectory+"/baseline-nc-output.f32le");assert(std::memcmp(output.data(),baseline.data(),output.size()*4)==0);
        // Independent scalar model includes the full leading-zero AEC warmup.
        const auto delay=((maximum+958)/480+2)*480;float state=0;
        for(std::size_t i=0;i<delay+mic.size();++i){const float input=i<delay?0:direct[i-delay];state=(state*.25f+input*.5f)+1.f/4096;if(i>=delay)assert(output[i-delay]==state);}
        assert(result.metadata.find("\"baselineSubmittedSamples\":"+std::to_string(480000+delay))!=std::string::npos);
        const auto metadata=options.outputDirectory+"/metadata.json";assert(exists(metadata));
        // Existing output is rejected before any worker opens and is preserved.
        bool failed=false;try{(void)labvoice::chain_probe::run(options,makeSeams());}catch(...){failed=true;}assert(failed && exists(metadata));
    }
    // The oracle is not chain input: altering it preserves actual chain output
    // and yields a retained explicit byte-mismatch diagnostic.
    const auto saved=direct[123];direct[123]+=.125f;writeFloats(options.directAECPath,direct);
    options.outputDirectory=root+"/mismatch";const auto mismatch=labvoice::chain_probe::run(options,makeSeams());assert(!mismatch.comparisonEqual && mismatch.metadata.find("\"comparisonEqual\":false")!=std::string::npos);
    const auto original=readFloats(root+"/output-4096/chain-output.f32le"),actual=readFloats(options.outputDirectory+"/chain-output.f32le");assert(std::memcmp(original.data(),actual.data(),actual.size()*4)==0);
    direct[123]=saved;writeFloats(options.directAECPath,direct);
    for(unsigned mutation=0;mutation<3;++mutation){options.outputDirectory=root+"/bad-input-"+std::to_string(mutation);if(mutation==0){mic.pop_back();writeFloats(options.microphonePath,mic);}if(mutation==1){mic.push_back(0);mic[7]=NAN;writeFloats(options.microphonePath,mic);}if(mutation==2){mic[7]=float(7)/4096;writeFloats(options.microphonePath,mic);options.maximumCallbackFrames=512;}bool failed=false;try{(void)labvoice::chain_probe::run(options,makeSeams());}catch(...){failed=true;}assert(failed && !exists(options.outputDirectory));}
    mic.back()=float((mic.size()-1)%997)/4096;writeFloats(options.microphonePath,mic);options.maximumCallbackFrames=480;
    for(bool baselineFailure:{false,true}){options.outputDirectory=root+(baselineFailure?"/bad-baseline-close":"/bad-chain-close");bool failed=false;try{(void)labvoice::chain_probe::run(options,makeSeams(baselineFailure?"normal":"bad-close",baselineFailure?"bad-close":"normal"));}catch(...){failed=true;}assert(failed && !exists(options.outputDirectory));}
    // AEC initialization mutates an already admitted oracle. Clean workers alone
    // cannot authorize publishing an input whose sampled identity changed.
    options.outputDirectory=root+"/mutated";auto mutate=makeSeams();mutate.aec=[&](auto launch,auto& error,auto buffering){assert(launch.arguments[4]==krisp_probe::installedAECLibrarySHA256);launch.arguments[3]=argv[2];launch.arguments[4]=argv[3];launch.expectedReadyLine=std::string("OKAEC1 ")+argv[3]+" 48000 1 48000 2\n";launch.environment.push_back("OPENKRISP_AEC_FIXTURE_MUTATE_INPUT="+options.directAECPath);return krisp_probe::AECDuplexWorker::create(std::move(launch),error,buffering);};bool rejected=false;try{(void)labvoice::chain_probe::run(options,std::move(mutate));}catch(...){rejected=true;}assert(rejected && !exists(options.outputDirectory));
    std::filesystem::remove_all(root);
    std::cout<<"AEC microphone chain offline probe own fixtures passed\n";
}
