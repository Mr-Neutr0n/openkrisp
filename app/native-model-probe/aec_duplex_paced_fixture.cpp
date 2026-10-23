#include <charconv>
#include "aec_duplex_paced.hpp"
#include "installed_aec_worker_launch.hpp"
#include <iostream>
// Own-only launch entry. Production always uses the fixed-vendor builder.
int main(int argc,char** argv){
    try{
        if(argc!=10)throw std::invalid_argument("expected worker workerSHA fixture fixtureSHA microphone reference output maximum budget");
        const auto maximum=krisp_probe::aec_paced::number(argv[8]),budget=krisp_probe::aec_paced::number(argv[9]);
        std::cout<<krisp_probe::aec_paced::run(argv[5],argv[6],argv[7],maximum,budget,[&](const auto& token){
            krisp_probe::aec_runtime::require(krisp_probe::installed_aec_worker_detail::hashWorker(argv[1])==argv[2],"own worker SHA mismatch");
            std::string hex;constexpr char digits[]="0123456789abcdef";
            for(auto value:token){hex+=digits[value>>4];hex+=digits[value&15];}
            krisp_probe::AECWorkerLaunchConfig config;
            config.executable="/usr/bin/sandbox-exec";
            config.arguments={"-p","(version 1) (allow default) (deny network*)",argv[1],argv[3],argv[4],hex,std::to_string(getpid())};
            config.environment={"PATH=/usr/bin:/bin"};config.token=token;
            config.expectedReadyLine=std::string("OKAEC1 ")+argv[4]+" 48000 1 48000 2\n";
            if(const char* failure=::getenv("OPENKRISP_AEC_PACED_FIXTURE_FAILURE"))
                config.environment.push_back(std::string("OPENKRISP_AEC_FIXTURE_FAILURE=")+failure);
            if(::getenv("OPENKRISP_AEC_PACED_FIXTURE_UNLOAD_EXIT"))config.environment.push_back("OPENKRISP_AEC_FIXTURE_UNLOAD_EXIT=1");
            if(const char* mutation=::getenv("OPENKRISP_AEC_PACED_FIXTURE_MUTATE"))
                config.environment.push_back(std::string("OPENKRISP_AEC_FIXTURE_MUTATE_INPUT=")+mutation);
            return config;
        });return 0;
    }catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
