#pragma once
#include "aec_microphone_chain.hpp"
#include "../native-model-probe/aec_worker_runtime.hpp"
#include <cstring>

namespace labvoice::chain_probe {
constexpr std::size_t samples=480000;
struct Options {
    AECMicrophoneChainOptions chain;
    std::string microphonePath,referencePath,directAECPath,outputDirectory;
    std::size_t maximumCallbackFrames=480;
};
struct Seams {
    AECMicrophoneChain::AECWorkerFactory aec;
    AECMicrophoneChain::NCWorkerFactory nc;
    // Receives the fixed outbound command. Own tests substitute a synthetic NC.
    std::function<krisp_probe::WorkerLaunchConfig(krisp_probe::WorkerLaunchConfig)> baseline;
};
struct Result {bool comparisonEqual;std::string metadata;};
inline std::string sha256(const std::vector<float>& values) {
    std::array<unsigned char,CC_SHA256_DIGEST_LENGTH> bytes{};
    krisp_probe::aec_runtime::require(CC_SHA256(values.data(),static_cast<CC_LONG>(values.size()*4),bytes.data())!=nullptr,"input digest failed");
    constexpr char hex[]="0123456789abcdef";std::string result;
    for(auto byte:bytes){result+=hex[byte>>4];result+=hex[byte&15];}return result;
}
inline Result run(const Options& options,Seams seams={}) {
    using namespace krisp_probe;
    using aec_runtime::require;
    using Clock=std::chrono::steady_clock;
    const auto started=Clock::now();
    require(options.maximumCallbackFrames==480 || options.maximumCallbackFrames==4096,"maximum callback must be 480 or 4096");
    require(options.chain.microphone.has_value() && !options.chain.microphoneRNNoise,"probe requires installed outbound microphone NC");
    require(options.chain.aec.schedulingBudgetFrames==2 && options.chain.schedulingBudgetFrames==2,"probe requires budget two for both stages");
    aec_runtime::Input microphone(options.microphonePath.c_str(),samples),reference(options.referencePath.c_str(),samples*2),direct(options.directAECPath.c_str(),samples);
    require(!options.outputDirectory.empty() && options.outputDirectory.front()=='/',"output directory must be absolute");
    struct stat destination{};
    require(::lstat(options.outputDirectory.c_str(),&destination)!=0 && errno==ENOENT,"output directory must not exist");
    const auto& nc=*options.chain.microphone;
    require(nc.modelRole==InstalledModelRole::outbound && !nc.bypass,"probe requires active outbound NC");
    wire::Token token{};arc4random_buf(token.data(),token.size());
    auto baselineLaunch=buildInstalledWorkerLaunch(nc,token);
    // All inputs and fixed builders are admitted before any child starts.
    (void)buildInstalledAECWorkerLaunch(options.chain.aec.settings,{});
    const Layout layout{{3},{3},0,1,2,0,1,2,480,static_cast<UInt32>(options.maximumCallbackFrames)};
    std::string error;
    auto chain=AECMicrophoneChain::create(layout,options.chain,error,std::move(seams.aec),std::move(seams.nc));
    if(!chain)throw std::runtime_error(error);
    const auto aecDelay=chain->aecDelaySamples(),ncDelay=chain->microphoneDelaySamples(),totalDelay=chain->totalMicrophoneDelaySamples();
    // No NC transport exists in WorkerBroker. Its prefix is only AEC delay.
    WorkerBroker baseline(seams.baseline?seams.baseline(std::move(baselineLaunch)):std::move(baselineLaunch));
    if(!baseline.start()){(void)chain->stop();throw std::runtime_error(baseline.error());}
    const auto ready=Clock::now();
    std::vector<float> chainOutput(samples),baselineOutput(samples);
    std::array<float,callbackLimit> mic{},output{};std::array<float,callbackLimit*2> ref{};
    const std::size_t submitted=samples+totalDelay;
    for(std::size_t position=0;position<submitted;) {
        const auto count=std::min(options.maximumCallbackFrames,submitted-position);
        std::fill_n(mic.data(),count,0.f);std::fill_n(ref.data(),count*2,0.f);
        const auto retained=position<samples?std::min(count,samples-position):0;
        if(retained){std::copy_n(microphone.values.data()+position,retained,mic.data());std::copy_n(reference.values.data()+position*2,retained*2,ref.data());}
        DuplexBlock block{mic.data(),ref.data(),static_cast<UInt32>(count),chain->epoch(),
            {double(position),double(position),0,true,false},{double(position),double(position),0,true,false}};
        require(AECMicrophoneChain::process(chain.get(),block,output.data()),"chain callback failed");
        for(std::size_t i=0;i<count;++i){require(std::isfinite(output[i]),"nonfinite chain output");const auto at=position+i;if(at>=totalDelay)chainOutput[at-totalDelay]=output[i];}
        position+=count;
        // Functional CPU test: wait outside the callback, never infer pacing.
        const auto expected=position/480;
        const auto deadline=Clock::now()+std::chrono::seconds(5);
        while(chain->healthy() && (chain->aecProcessedFrames()<expected || chain->microphoneProcessedFrames()<expected) && Clock::now()<deadline)
            std::this_thread::yield();
        require(chain->healthy() && chain->aecProcessedFrames()==expected && chain->microphoneProcessedFrames()==expected,"chain processed-frame handshake failed");
    }
    const auto chainProcessed=Clock::now();
    // A fresh NC engine receives the exact AEC startup zeros, then the retained
    // direct-AEC oracle. It never supplies any samples to the actual chain.
    std::array<float,480> input{},result{};
    for(std::size_t position=0;position<samples+aecDelay;position+=480) {
        for(std::size_t i=0;i<480;++i){const auto at=position+i;input[i]=at<aecDelay?0:direct.values[at-aecDelay];}
        if(!baseline.process480(input,result))throw std::runtime_error(baseline.error());
        for(std::size_t i=0;i<480;++i){require(std::isfinite(result[i]),"nonfinite baseline output");const auto at=position+i;if(at>=aecDelay)baselineOutput[at-aecDelay]=result[i];}
    }
    // No short circuit: failure closing either owner cannot skip the other.
    const bool chainClosed=chain->stop();const bool baselineClosed=baseline.close();
    require(chainClosed && baselineClosed,"chain or baseline teardown failed");
    require(microphone.unchanged() && reference.unchanged() && direct.unchanged(),"input changed during run");
    std::size_t mismatches=0,first=samples;double maxDifference=0;
    for(std::size_t i=0;i<samples;++i){if(std::memcmp(&chainOutput[i],&baselineOutput[i],4)){++mismatches;if(first==samples)first=i;}maxDifference=std::max(maxDifference,std::abs(double(chainOutput[i])-baselineOutput[i]));}
    const auto closed=Clock::now();
    const auto milliseconds=[](auto span){return std::chrono::duration<double,std::milli>(span).count();};
    std::ostringstream json;json<<std::setprecision(17)
        <<"{\"comparisonEqual\":"<<(mismatches?"false":"true")<<",\"mismatchSamples\":"<<mismatches<<",\"firstMismatch\":";
    if(first==samples)json<<"null";else json<<first;
    json<<",\"maxAbsoluteDifference\":"<<maxDifference<<",\"frames\":1000,\"samples\":480000,\"referenceSamples\":960000,\"forwardRate\":48000,\"referenceRate\":48000"
        <<",\"maximumCallbackFrames\":"<<options.maximumCallbackFrames<<",\"schedulingBudgetFrames\":2,\"aecDelaySamples\":"<<aecDelay<<",\"ncDelaySamples\":"<<ncDelay<<",\"totalDelaySamples\":"<<totalDelay
        <<",\"chainSubmittedSamples\":"<<submitted<<",\"baselineSubmittedSamples\":"<<samples+aecDelay
        <<",\"chainAECProcessedFrames\":"<<chain->aecProcessedFrames()<<",\"chainNCProcessedFrames\":"<<chain->microphoneProcessedFrames()<<",\"baselineProcessedFrames\":"<<(samples+aecDelay)/480
        <<",\"teardownComplete\":true,\"realtimePaced\":false,\"hardwareAudio\":false,\"timingPolicy\":\"offline-contiguous-with-padding\",\"processingOrder\":\"aec-then-nc\""
        <<",\"librarySha256\":\""<<installedAECLibrarySHA256<<"\",\"aecWorkerSha256\":\""<<options.chain.aec.settings.workerSha256
        <<"\",\"ncNodeSha256\":\""<<nc.nodeSha256<<"\",\"ncAdapterSha256\":\""<<nc.adapterSha256<<"\",\"ncModelSha256\":\""<<nc.modelSha256
        <<"\",\"microphoneSha256\":\""<<sha256(microphone.values)<<"\",\"referenceSha256\":\""<<sha256(reference.values)<<"\",\"directAECSha256\":\""<<sha256(direct.values)
        <<"\",\"startupMs\":"<<milliseconds(ready-started)<<",\"chainProcessingMs\":"<<milliseconds(chainProcessed-ready)<<",\"totalMs\":"<<milliseconds(closed-started)<<"}\n";
    auto metadata=json.str();
    aec_runtime::Publication publication(options.outputDirectory.c_str());
    // Reserve before creating files: Publication retains cleanup identities.
    publication.files.reserve(3);
    publication.write("chain-output.f32le",chainOutput.data(),chainOutput.size()*4);
    publication.write("baseline-nc-output.f32le",baselineOutput.data(),baselineOutput.size()*4);
    publication.write("metadata.json",metadata.data(),metadata.size());
    require(microphone.unchanged() && reference.unchanged() && direct.unchanged(),"input changed during publication");
    publication.publish(options.outputDirectory.c_str());
    return {mismatches==0,std::move(metadata)};
}
}
