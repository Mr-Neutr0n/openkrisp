#include "aec_worker_protocol.hpp"
#include <cassert>
#include <iostream>
using namespace krisp_probe::aec_wire;
int main() {
 Token token{}; token[0]=7; Frame f; f.epoch=9;
 f.microphoneTiming={12.25,100.75,42,3}; f.referenceTiming={-100.5,300.25,70,3};
 for(size_t i=0;i<samples;++i) f.microphone[i]=float(i);
 for(size_t i=0;i<referenceSamples;++i) f.reference[i]=-float(i);
 Storage bytes; auto n=encode(f,token,bytes); assert(n==maxFrameBytes);
 Parser p(token,mask(Kind::request)|mask(Kind::close)); int calls=0;
 for(size_t i=0;i<n;++i) assert(p.push(std::span(bytes.data()+i,1),[&](const Frame& v){++calls;assert(v.microphone==f.microphone && v.reference==f.reference && v.microphoneTiming==f.microphoneTiming);return true;}));
 assert(calls==1 && p.retainedBytes()==0);
 Frame close;close.kind=Kind::close;close.sequence=1; n=encode(close,token,bytes);
 assert(p.push(std::span(bytes.data(),n),[](auto&){return true;}));assert(p.closed());assert(p.finish());
 for(int mutation=0;mutation<10;++mutation){
 n=encode(f,token,bytes);
 if(mutation==0)bytes[4]=2;
 if(mutation==1)bytes[8]^=1;
 if(mutation==2)bytes[32]=1;
 if(mutation==3)bytes[24]=1;
 if(mutation==4)bytes[72]=1;
 if(mutation==5)write(bytes.data()+44,0x7ff8000000000000ULL,8);
 if(mutation==6)write(bytes.data()+headerBytes,0x7fc00000,4);
 if(mutation==7)bytes[68]=4;
 if(mutation==8)write(bytes.data()+52,std::bit_cast<uint64_t>(1e30),8);
 if(mutation==9)bytes[116]=1;
 Parser q(token,mask(Kind::request)); assert(!q.push(std::span(bytes.data(),n),[](auto&){return true;}));assert(q.failed()); assert(!q.push({},[](auto&){return true;}));
 }
 n=encode(f,token,bytes);Parser partial(token,mask(Kind::request));assert(partial.push(std::span(bytes.data(),n-1),[](auto&){return true;}));assert(!partial.finish());
 Frame max=f;max.sequence=UINT64_MAX; n=encode(max,token,bytes);Parser overflow(token,mask(Kind::request),UINT64_MAX);assert(overflow.push(std::span(bytes.data(),n),[](auto&){return true;}));assert(!overflow.push(std::span(bytes.data(),1),[](auto&){return true;}));
 n=encode(f,token,bytes);Parser reentry(token,mask(Kind::request));assert(!reentry.push(std::span(bytes.data(),n),[&](auto&){return reentry.push({},[](auto&){return true;});}));
 std::cout<<"AEC protocol tests passed\n";
}
