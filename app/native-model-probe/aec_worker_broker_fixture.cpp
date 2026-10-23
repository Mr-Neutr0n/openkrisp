#include "aec_worker_protocol.hpp"
#include <unistd.h>
#include <string>
using namespace krisp_probe::aec_wire;
int main(int argc,char**argv){
 if(argc!=2)return 2;std::string mode=argv[1];Token token{};token[0]=7;
 if(mode=="startup-crash")return 1;
 const char ready[]="aec-fixture\n";write(3,ready,sizeof(ready)-1);
 Parser p(token,mask(Kind::request)|mask(Kind::close)); bool closed=false;std::array<uint8_t,777> input{};
 for(;;){auto n=read(0,input.data(),input.size());if(n<0)return 3;if(n==0)return closed?(mode=="nonzero-exit"?7:0):4;
 if(!p.push(std::span(input.data(),size_t(n)),[&](const Frame&request){
 if(mode=="crash")_exit(3);
 if(mode=="stall"){for(;;)pause();}
 if(request.kind==Kind::close && mode=="close-stall"){for(;;)pause();}
 Frame result=request;result.kind=request.kind==Kind::close?Kind::close:Kind::result;
 for(size_t i=0;i<samples;++i)result.output[i]=request.microphone[i]+request.reference[2*i];
 if(mode=="timing")result.microphoneTiming.inputSampleOrigin+=1;
 if(result.kind==Kind::close && mode=="close-epoch")result.epoch=1;
 Storage bytes;auto size=encode(result,token,bytes);if(mode=="malformed")bytes[4]=2;
 if(mode=="trailing"){bytes[size]=0;return write(3,bytes.data(),size+1)==static_cast<ssize_t>(size+1);}
 for(size_t offset=0;offset<size;){auto count=write(3,bytes.data()+offset,std::min(size-offset,size_t(17)));if(count<=0)return false;offset+=count;}
 if(mode=="trailing" || (request.kind==Kind::close && mode=="close-trailing")){uint8_t byte=0;write(3,&byte,1);}
 closed=request.kind==Kind::close;return true;
 }))return 5;}
}
