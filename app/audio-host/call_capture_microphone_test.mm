#include "call_capture.hpp"
#include <cassert>
#include <iostream>
using namespace labvoice;
int main(){
    assert(silenceUnexpectedCallCaptureOutputs(nullptr));
    float samples[]={.8f,-.8f,.5f,-.5f};AudioBufferList output{1,{{2,sizeof samples,samples}}};
    assert(!silenceUnexpectedCallCaptureOutputs(&output));for(float sample:samples)assert(sample==0);
    output.mBuffers[0].mData=nullptr;assert(silenceUnexpectedCallCaptureOutputs(&output));
    output.mNumberBuffers=17;assert(!silenceUnexpectedCallCaptureOutputs(&output));
    std::cout<<"Call-capture unexpected duplex output is bounded and silenced.\n";
}
