#pragma once
#include "aec_duplex_worker.hpp"
#include "aec_worker_runtime.hpp"
#include <thread>
#include <charconv>

namespace krisp_probe::aec_paced {
inline std::string quantiles(std::vector<double> values){
    std::sort(values.begin(),values.end());
    const auto rank=[&](std::size_t percent){return values[(values.size()*percent+99)/100-1];};
    std::ostringstream json;json<<std::setprecision(17)<<"{\"p50\":"<<rank(50)<<",\"p95\":"<<rank(95)
        <<",\"p99\":"<<rank(99)<<",\"max\":"<<values.back()<<"}";return json.str();
}
template<class Build>
std::string run(const char* microphonePath,const char* referencePath,const char* outputDirectory,
                std::size_t maximum,std::size_t budget,Build build){
    using namespace aec_runtime;
    using Clock=std::chrono::steady_clock;
    require(maximum==480 || maximum==512 || maximum==4096,"callback maximum must be 480, 512 or 4096");
    // Validate queue capacity before invoking any launch builder.
    require(budget<32 && (maximum+958)/480+budget<32,"invalid duplex scheduling budget");
    require(outputDirectory[0]=='/',"output directory must be absolute");
    struct stat destination{};
    require(::lstat(outputDirectory,&destination)!=0 && errno==ENOENT,"output directory must not exist");
    Input microphone(microphonePath,480000),reference(referencePath,960000);
    aec_wire::Token token{};arc4random_buf(token.data(),token.size());
    std::string error;
    auto owner=AECDuplexWorker::create(build(token),error,{maximum,budget});
    if(!owner)throw std::runtime_error(error);
    const auto delay=owner->actualDelaySamples(),total=480000+delay;
    std::vector<float> output(total);
    std::array<float,4096> mic{};
    std::array<float,8192> ref{};
    std::vector<double> lateness,duration;
    const auto callbacks=(total+maximum-1)/maximum;
    lateness.reserve(callbacks);duration.reserve(callbacks);
    const auto pacedStart=Clock::now();
    for(std::size_t position=0;position<total;){
        const auto count=std::min(maximum,total-position);
        for(std::size_t i=0;i<count;++i){
            const auto sample=position+i;
            mic[i]=sample<480000?microphone.values[sample]:0;
            ref[2*i]=sample<480000?reference.values[2*sample]:0;
            ref[2*i+1]=sample<480000?reference.values[2*sample+1]:0;
        }
        const auto target=pacedStart+std::chrono::duration_cast<Clock::duration>(std::chrono::duration<double>(double(position)/48000));
        std::this_thread::sleep_until(target);
        const auto entered=Clock::now();
        lateness.push_back(std::max(0.0,std::chrono::duration<double,std::micro>(entered-target).count()));
        AECPairedBlock block{mic.data(),ref.data(),count,1,
            {double(position),double(position),0,true,false},{double(position),double(position),0,true,false}};
        const auto exchangeStarted=Clock::now();
        const bool exchanged=owner->exchange(block,output.data()+position);
        duration.push_back(std::chrono::duration<double,std::micro>(Clock::now()-exchangeStarted).count());
        if(!exchanged){
            const auto fault=owner->fault();
            (void)owner->stop();
            std::ostringstream failure;failure<<"paced duplex exchange failed callback="<<duration.size()-1
                <<" samplePosition="<<position<<" transportFault="<<static_cast<unsigned>(fault)
                <<" latenessUs="<<lateness.back()<<" workerError="<<owner->error();
            throw std::runtime_error(failure.str());
        }
        position+=count;
    }
    const auto callbacksEnded=Clock::now();
    const bool clean=owner->stop();
    const auto stopped=Clock::now();
    if(!clean)throw std::runtime_error(owner->error().empty()?"paced duplex shutdown failed":owner->error());
    const auto processed=owner->processedFrames();
    require(processed>=1000 && processed<=total/480,"unexpected processed frame count");
    for(std::size_t i=0;i<output.size();++i)
        require(std::isfinite(output[i]) && (i>=delay || output[i]==0),"invalid paced output or initial buffering");
    require(microphone.unchanged() && reference.unchanged(),"input changed during paced run");
    std::ostringstream json;json<<std::setprecision(17)
        <<"{\"inputSamples\":480000,\"referenceSamples\":960000,\"outputSamples\":"<<total
        <<",\"delaySamples\":"<<delay<<",\"initialSilenceSamples\":"<<delay<<",\"alignedSamples\":480000,"
        <<"\"forwardRate\":48000,\"forwardChannels\":1,\"referenceRate\":48000,\"referenceChannels\":2,"
        <<"\"maximumCallbackFrames\":"<<maximum<<",\"schedulingBudgetFrames\":"<<budget
        <<",\"callbackCount\":"<<callbacks<<",\"processedFrames\":"<<processed
        <<",\"teardownComplete\":true,\"realtimePaced\":true,\"hardwareAudio\":false,\"timingPolicy\":\"synthetic-contiguous\","
        <<"\"callbackLatenessUs\":"<<quantiles(lateness)<<",\"exchangeDurationUs\":"<<quantiles(duration)
        <<",\"totalPacedMs\":"<<std::chrono::duration<double,std::milli>(callbacksEnded-pacedStart).count()
        <<",\"shutdownMs\":"<<std::chrono::duration<double,std::milli>(stopped-callbacksEnded).count()<<"}\n";
    const auto metadata=json.str();
    Publication publication(outputDirectory);
    publication.write("paced-output.f32le",output.data(),output.size()*sizeof(float));
    publication.write("metadata.json",metadata.data(),metadata.size());
    require(microphone.unchanged() && reference.unchanged(),"input changed during paced publication");
    publication.publish(outputDirectory);
    return metadata;
}
inline std::size_t number(const char* text){
    std::size_t value=0;
    const auto parsed=std::from_chars(text,text+std::strlen(text),value);
    if(parsed.ec!=std::errc{} || *parsed.ptr!='\0')throw std::invalid_argument("invalid decimal option");
    return value;
}
} // namespace krisp_probe::aec_paced
