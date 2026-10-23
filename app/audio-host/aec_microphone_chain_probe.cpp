#include "aec_microphone_chain_probe.hpp"
#include <charconv>
#include <iostream>
int main(int argc,char** argv) {
    try {
        if(argc!=17)throw std::invalid_argument("usage: aec-microphone-chain-probe aecWorker aecWorkerSHA aecLibrary node nodeSHA ncWorker addon model adapter adapterSHA libraryDir microphone.f32le reference.f32le directAEC.f32le newOutputDirectory maximumCallbackFrames");
        labvoice::chain_probe::Options options;
        options.chain.aec.settings={argv[1],argv[2],argv[3]};
        krisp_probe::InstalledWorkerSettings nc;
        nc.nodePath=argv[4];nc.nodeSha256=argv[5];nc.workerPath=argv[6];nc.addonPath=argv[7];nc.modelPath=argv[8];nc.adapterPath=argv[9];nc.adapterSha256=argv[10];nc.libraryPath=argv[11];
        options.chain.microphone=nc;
        options.microphonePath=argv[12];options.referencePath=argv[13];options.directAECPath=argv[14];options.outputDirectory=argv[15];
        const auto parsed=std::from_chars(argv[16],argv[16]+std::strlen(argv[16]),options.maximumCallbackFrames);
        if(parsed.ec!=std::errc{} || *parsed.ptr)throw std::invalid_argument("invalid maximum callback frames");
        const auto result=labvoice::chain_probe::run(options);std::cout<<result.metadata;return result.comparisonEqual?0:2;
    }catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
