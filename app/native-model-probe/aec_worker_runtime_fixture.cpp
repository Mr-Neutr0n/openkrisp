// Own-only executable supplies a synthetic launch to the shared harness core.
// Production has no fixture hash override or alternate symbol option.
#include "aec_worker_runtime.hpp"
#include "installed_aec_worker_launch.hpp"
#include <iostream>
int main(int argc,char** argv){
    try{
        if(argc!=8)throw std::invalid_argument("expected worker workerSHA fixture fixtureSHA microphone reference output");
        std::cout<<krisp_probe::aec_runtime::run(argv[5],argv[6],argv[7],[&](const auto& token){
            krisp_probe::aec_runtime::require(krisp_probe::installed_aec_worker_detail::hashWorker(argv[1])==argv[2],"own worker SHA mismatch");
            std::string hex;constexpr char digits[]="0123456789abcdef";
            for(auto value:token){hex+=digits[value>>4];hex+=digits[value&15];}
            krisp_probe::AECWorkerLaunchConfig launch;
            launch.executable="/usr/bin/sandbox-exec";
            launch.arguments={"-p","(version 1) (allow default) (deny network*)",argv[1],argv[3],argv[4],hex,std::to_string(::getpid())};
            launch.environment={"PATH=/usr/bin:/bin"};
            if(const char* mutate=::getenv("OPENKRISP_AEC_RUNTIME_FIXTURE_MUTATE"))
                launch.environment.push_back(std::string("OPENKRISP_AEC_FIXTURE_MUTATE_INPUT=")+mutate);
            if(const char* failure=::getenv("OPENKRISP_AEC_RUNTIME_FIXTURE_FAILURE"))
                launch.environment.push_back(std::string("OPENKRISP_AEC_FIXTURE_FAILURE=")+failure);
            if(::getenv("OPENKRISP_AEC_RUNTIME_FIXTURE_UNLOAD_EXIT"))
                launch.environment.push_back("OPENKRISP_AEC_FIXTURE_UNLOAD_EXIT=1");
            launch.token=token;
            launch.expectedReadyLine=std::string("OKAEC1 ")+argv[4]+" 48000 1 48000 2\n";
            return launch;
        });
        return 0;
    }catch(const std::exception& error){std::cerr<<error.what()<<'\n';return 1;}
}
