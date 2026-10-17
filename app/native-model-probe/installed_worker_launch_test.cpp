#include "installed_worker_launch.hpp"
#include <cassert>
#include <iostream>
using namespace krisp_probe;
static InstalledWorkerSettings settings() {
    InstalledWorkerSettings s;
    s.nodePath="/runtime/node";s.workerPath="/package/audio_worker.cjs";
    s.addonPath="/installed/a\"b\\c\t\n\x01/é.node";s.modelPath="/installed/model";
    s.adapterPath="/package/adapter";s.libraryPath="/installed/libraries";
    s.nodeSha256=std::string(64,'a');s.adapterSha256=std::string(64,'b');
    s.suppressionLevel=37.5;s.bypass=true;return s;
}
int main(int argc,char** argv) {
    const auto s=settings();wire::Token token{};for(unsigned i=0;i<16;++i)token[i]=i;
    const auto c=buildInstalledWorkerLaunch(s,token);
    assert(c.executable=="/usr/bin/sandbox-exec");assert(c.arguments.size()==9);
    assert(c.arguments[0]=="-p" && c.arguments[1]=="(version 1) (allow default) (deny network*)");
    assert(c.arguments[2]=="/usr/bin/env" && c.arguments[3]=="-i" && c.arguments[4]=="PATH=/usr/bin:/bin" && c.arguments[5]=="DYLD_LIBRARY_PATH="+s.libraryPath && c.arguments[6]==s.nodePath && c.arguments[7]==s.workerPath);
    assert((c.environment==std::vector<std::string>{"PATH=/usr/bin:/bin"}));
    assert(c.token==token);assert(c.startupTimeout.count()==30000 && c.frameTimeout.count()==500 && c.shutdownTimeout.count()==1000);
    const auto& json=c.arguments[8];assert(json.find("a\\\"b\\\\c\\u0009\\u000a\\u0001/é.node")!=std::string::npos);
    assert(json.find("\"suppressionLevel\":37.5,\"bypass\":true")!=std::string::npos);
    assert(c.expectedReadyLine=="OKREADY2 000102030405060708090a0b0c0d0e0f ordinary-nc-direct 48000 480 outbound "+std::string(installed_worker_detail::addonSHA)+" "+installed_worker_detail::modelSHA+" "+s.adapterSha256+" "+s.nodeSha256+"\n");
    assert(json.find("\"modelRole\":\"outbound\",\"modelSha256\":\""+std::string(installedOutboundModelSHA256)+"\"")!=std::string::npos);
    auto inbound=s;inbound.modelRole=InstalledModelRole::inbound;inbound.modelSha256=installedInboundModelSHA256;
    const auto inboundLaunch=buildInstalledWorkerLaunch(inbound,token);
    assert(inboundLaunch.arguments[8].find("\"modelRole\":\"inbound\",\"modelSha256\":\""+std::string(installedInboundModelSHA256)+"\"")!=std::string::npos);
    assert(inboundLaunch.expectedReadyLine=="OKREADY2 000102030405060708090a0b0c0d0e0f ordinary-nc-direct 48000 480 inbound "+std::string(installed_worker_detail::addonSHA)+" "+installedInboundModelSHA256+" "+s.adapterSha256+" "+s.nodeSha256+"\n");
    for(auto bad:{s,inbound}) {
        bad.modelSha256=bad.modelRole==InstalledModelRole::outbound?installedInboundModelSHA256:installedOutboundModelSHA256;
        bool rejected=false;try{buildInstalledWorkerLaunch(bad,token);}catch(const std::invalid_argument&){rejected=true;}assert(rejected);
    }
    for(const auto& digest:{std::string(64,'A'),std::string(63,'a'),std::string(64,'g'),std::string(64,'0')}) {
        auto bad=s;bad.modelSha256=digest;bool rejected=false;try{buildInstalledWorkerLaunch(bad,token);}catch(const std::invalid_argument&){rejected=true;}assert(rejected);
    }
    {
        auto bad=s;bad.modelRole=static_cast<InstalledModelRole>(99);
        bool rejected=false;try{buildInstalledWorkerLaunch(bad,token);}catch(const std::invalid_argument&){rejected=true;}assert(rejected);
    }
    for(auto member:{&InstalledWorkerSettings::nodePath,&InstalledWorkerSettings::workerPath,&InstalledWorkerSettings::addonPath,&InstalledWorkerSettings::modelPath,&InstalledWorkerSettings::adapterPath,&InstalledWorkerSettings::libraryPath}) {
        for(const auto& invalid:{std::string(),std::string("relative"),std::string("/nul\0tail",9),std::string("/\xc0\x80",3),std::string("/\xed\xa0\x80",4)}) {
            auto bad=s;bad.*member=invalid;bool rejected=false;try{buildInstalledWorkerLaunch(bad,token);}catch(const std::invalid_argument&){rejected=true;}assert(rejected);
        }
    }
    for(const auto& invalid:{"/lib:other","/lib\nother","/lib\rother"}) {
        auto bad=s;bad.libraryPath=invalid;bool rejected=false;try{buildInstalledWorkerLaunch(bad,token);}catch(const std::invalid_argument&){rejected=true;}assert(rejected);
    }
    for(auto member:{&InstalledWorkerSettings::nodeSha256,&InstalledWorkerSettings::adapterSha256})for(const auto& invalid:{std::string(64,'A'),std::string(63,'a'),std::string(64,'g')}) {
        auto bad=s;bad.*member=invalid;bool rejected=false;try{buildInstalledWorkerLaunch(bad,token);}catch(const std::invalid_argument&){rejected=true;}assert(rejected);
    }
    for(double invalid:{-1.,101.,std::numeric_limits<double>::infinity(),std::numeric_limits<double>::quiet_NaN()}) {
        auto bad=s;bad.suppressionLevel=invalid;bool rejected=false;try{buildInstalledWorkerLaunch(bad,token);}catch(const std::invalid_argument&){rejected=true;}assert(rejected);
    }
    if(argc==2 && std::string(argv[1])=="--json-fixture")std::cout<<json<<'\n';
    else if(argc==2 && std::string(argv[1])=="--json-fixture-inbound")std::cout<<inboundLaunch.arguments[8]<<'\n';
    else std::cout<<"installed worker launch builder tests passed\n";
}
