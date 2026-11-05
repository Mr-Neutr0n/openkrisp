#pragma once
#include "worker_broker.hpp"
#include <iomanip>
#include <locale>
#include <sstream>
#include <stdexcept>
#include <unistd.h>

namespace krisp_probe {
inline constexpr const char* bundledNodeSHA256 = "533bd644c5ae0e0ea3a80e433aad16b817447ccba1e1eea701875eac80cb75d4";
inline constexpr const char* reviewedHomebrewNodeSHA256 = "1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040";
enum class InstalledModelRole { outbound, inbound, outboundHVC };
inline constexpr const char* installedOutboundModelSHA256 = "12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d";
inline constexpr const char* installedInboundModelSHA256 = "d1e4e2a94fe27dec1a8fd5a7b36cfac38d183a110f738156d85d1317f98fac8a";
// Candidate only: ordinary NC ABI, no claim of original desktop BVC dispatch.
inline constexpr const char* installedOutboundHVCModelSHA256 = "54e2913ea45734adc3323407e43f55b14afade256ab4da6226c2b6e30604cbf4";
inline const char* installedModelRoleName(InstalledModelRole role) {
    switch(role) {
        case InstalledModelRole::outbound: return "outbound";
        case InstalledModelRole::inbound: return "inbound";
        case InstalledModelRole::outboundHVC: return "outbound-hvc-lfb";
    }
    throw std::invalid_argument("Unknown installed model role");
}
inline const char* installedModelSha256(InstalledModelRole role) {
    switch(role) {
        case InstalledModelRole::outbound: return installedOutboundModelSHA256;
        case InstalledModelRole::inbound: return installedInboundModelSHA256;
        case InstalledModelRole::outboundHVC: return installedOutboundHVCModelSHA256;
    }
    throw std::invalid_argument("Unknown installed model role");
}
struct InstalledWorkerSettings {
    std::string nodePath, workerPath, addonPath, modelPath, adapterPath, libraryPath;
    std::string nodeSha256, adapterSha256;
    InstalledModelRole modelRole = InstalledModelRole::outbound;
    std::string modelSha256 = installedOutboundModelSHA256;
    double suppressionLevel = 100;
    bool bypass = false;
};
namespace installed_worker_detail {
inline constexpr const char* addonSHA = "adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755";
inline constexpr const char* modelSHA = installedOutboundModelSHA256; // Existing outbound identity alias.
inline bool utf8(const std::string& value) {
    for (std::size_t i=0;i<value.size();) {
        const auto c=static_cast<unsigned char>(value[i++]);
        if(c<0x80)continue;
        unsigned count=0; std::uint32_t code=0, minimum=0;
        if(c>=0xc2 && c<=0xdf){count=1;code=c&31;minimum=0x80;}
        else if(c>=0xe0 && c<=0xef){count=2;code=c&15;minimum=0x800;}
        else if(c>=0xf0 && c<=0xf4){count=3;code=c&7;minimum=0x10000;}
        else return false;
        if(value.size()-i<count)return false;
        for(unsigned n=0;n<count;++n){const auto b=static_cast<unsigned char>(value[i++]);if((b&0xc0)!=0x80)return false;code=(code<<6)|(b&63);}
        if(code<minimum || code>0x10ffff || (code>=0xd800 && code<=0xdfff))return false;
    }
    return true;
}
inline void path(const std::string& value) {
    if(value.empty() || value.front()!='/' || value.find('\0')!=std::string::npos || !utf8(value))throw std::invalid_argument("Expected absolute UTF-8 path without NUL");
}
inline void digest(const std::string& value) {
    if(value.size()!=64 || value.find_first_not_of("0123456789abcdef")!=std::string::npos)throw std::invalid_argument("Expected lowercase SHA256");
}
inline std::string json(const std::string& value) {
    constexpr char hex[]="0123456789abcdef";
    std::string result="\"";
    for(unsigned char c:value) {
        if(c=='"' || c=='\\'){result+='\\';result+=static_cast<char>(c);}
        else if(c<32){result+="\\u00";result+=hex[c>>4];result+=hex[c&15];}
        else result+=static_cast<char>(c);
    }
    return result+'"';
}
inline std::string tokenHex(const wire::Token& token) {
    constexpr char hex[]="0123456789abcdef";std::string result;
    for(auto c:token){result+=hex[c>>4];result+=hex[c&15];}return result;
}
}
// Pure builder. Caller supplies trusted packaged paths and runtime identities.
// Worker validates installed files. The established macOS host route requires
// /usr/bin/env after sandbox-exec because platform executables strip DYLD values.
// env -i constructs only PATH and the reviewed library path inside the sandbox.
// See model-provider-contract.md. No environment is inherited.
inline WorkerLaunchConfig buildInstalledWorkerLaunch(const InstalledWorkerSettings& settings, wire::Token token) {
    using namespace installed_worker_detail;
    const std::string role=installedModelRoleName(settings.modelRole);
    digest(settings.modelSha256);
    if(settings.modelSha256!=installedModelSha256(settings.modelRole))
        throw std::invalid_argument("Installed model role and SHA256 mismatch");
    for(const auto* value:{&settings.nodePath,&settings.workerPath,&settings.addonPath,&settings.modelPath,&settings.adapterPath,&settings.libraryPath})path(*value);
    if(settings.libraryPath.find_first_of("\n\r:")!=std::string::npos)throw std::invalid_argument("Expected one library directory");
    digest(settings.nodeSha256);digest(settings.adapterSha256);
    if (settings.nodeSha256 != bundledNodeSHA256 && settings.nodeSha256 != reviewedHomebrewNodeSHA256)
        throw std::invalid_argument("Unreviewed Node SHA256");
    if(!std::isfinite(settings.suppressionLevel) || settings.suppressionLevel<0 || settings.suppressionLevel>100)throw std::invalid_argument("Invalid suppression level");
    const auto tokenText=tokenHex(token);
    std::ostringstream level;level.imbue(std::locale::classic());level<<std::setprecision(std::numeric_limits<double>::max_digits10)<<settings.suppressionLevel;
    const std::string config="{\"parentPID\":"+std::to_string(getpid())+",\"modelRole\":"+json(role)+",\"modelSha256\":"+json(settings.modelSha256)+",\"addonPath\":"+json(settings.addonPath)+",\"modelPath\":"+json(settings.modelPath)+",\"adapterPath\":"+json(settings.adapterPath)+",\"adapterSha256\":"+json(settings.adapterSha256)+",\"nodeSha256\":"+json(settings.nodeSha256)+",\"token\":"+json(tokenText)+",\"suppressionLevel\":"+level.str()+",\"bypass\":"+(settings.bypass?"true":"false")+"}";
    WorkerLaunchConfig result;
    result.executable="/usr/bin/sandbox-exec";
    result.arguments={"-p","(version 1) (allow default) (deny network*)","/usr/bin/env","-i","PATH=/usr/bin:/bin","DYLD_LIBRARY_PATH="+settings.libraryPath,settings.nodePath,settings.workerPath,config};
    result.environment={"PATH=/usr/bin:/bin"};
    result.expectedReadyLine="OKREADY2 "+tokenText+" ordinary-nc-direct 48000 480 "+role+" "+addonSHA+" "+settings.modelSha256+" "+settings.adapterSha256+" "+settings.nodeSha256+"\n";
    result.token=token;result.startupTimeout=std::chrono::milliseconds(30000);result.frameTimeout=std::chrono::milliseconds(500);result.shutdownTimeout=std::chrono::milliseconds(1000);
    return result;
}
}
