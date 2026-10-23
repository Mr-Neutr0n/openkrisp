#include <charconv>
#include "aec_duplex_paced.hpp"
#include "installed_aec_worker_launch.hpp"
#include <iostream>
int main(int argc,char** argv){
    try{
        if(argc!=9)throw std::invalid_argument("usage: aec-duplex-paced-probe worker workerSHA library microphone reference newOutputDirectory maximumCallbackFrames schedulingBudgetFrames");
        const auto maximum=krisp_probe::aec_paced::number(argv[7]),budget=krisp_probe::aec_paced::number(argv[8]);
        const krisp_probe::InstalledAECWorkerSettings settings{argv[1],argv[2],argv[3]};
        std::cout<<krisp_probe::aec_paced::run(argv[4],argv[5],argv[6],maximum,budget,[&](const auto& token){
            return krisp_probe::buildInstalledAECWorkerLaunch(settings,token);
        });
        return 0;
    }catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
