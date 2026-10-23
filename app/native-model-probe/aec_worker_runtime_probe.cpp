#include "aec_worker_runtime.hpp"
#include "installed_aec_worker_launch.hpp"
#include <iostream>
int main(int argc,char** argv){
    try{
        if(argc!=7)throw std::invalid_argument("usage: aec-worker-runtime-probe worker workerSHA library microphone.f32le reference.f32le newOutputDirectory");
        krisp_probe::InstalledAECWorkerSettings settings{argv[1],argv[2],argv[3]};
        std::cout<<krisp_probe::aec_runtime::run(argv[4],argv[5],argv[6],[&](const auto& token){
            return krisp_probe::buildInstalledAECWorkerLaunch(settings,token);
        });
        return 0;
    }catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
