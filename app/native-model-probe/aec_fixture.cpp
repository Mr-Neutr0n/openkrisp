// Own synthetic producer. Deliberately does not include the consumer ABI view.
#include <cstddef>
#include <cstdint>
#include <exception>
#include <stdexcept>
namespace {
struct Spec { int rate; unsigned padding; std::size_t channels; std::size_t frames; };
unsigned counts[5]{}; // created, destroyed, reference calls, forward calls, exceptions destroyed
bool failFactory = false;
unsigned throwStage = 0;
class FactoryError final : public std::exception {
public:
    ~FactoryError() override { ++counts[4]; }
    const char* what() const noexcept override { return "synthetic AEC initialization failure"; }
};
class Engine {
public:
    virtual ~Engine() { ++counts[1]; }
    virtual int initialize() { return 0; }
    virtual void config() { throw std::logic_error("wrong slot"); }
    virtual void mute() { throw std::logic_error("wrong slot"); }
    virtual void runtime() { throw std::logic_error("wrong slot"); }
    virtual void shortForward() { throw std::logic_error("wrong slot"); }
    virtual void planarForward() { throw std::logic_error("wrong slot"); }
    virtual int forward(const float* input, const Spec& in, const Spec& out, float* output) {
        if (throwStage == 2) throw FactoryError();
        if (in.rate != 32000 || in.channels != 1 || in.frames != 320 || in.padding ||
            out.rate != in.rate || out.channels != in.channels || out.frames != in.frames ||
            out.padding || !referenceSeen_) throw std::runtime_error("forward ABI/config/order");
        ++counts[3];
        for (std::size_t i = 0; i < in.frames; ++i) output[i] = input[i] - reference_;
        return 0;
    }
    virtual void shortReference() { throw std::logic_error("wrong slot"); }
    virtual void planarReference() { throw std::logic_error("wrong slot"); }
    virtual int reference(const float* input, const Spec& spec) {
        if (throwStage == 1) throw FactoryError();
        if (spec.rate != 48000 || spec.channels != 2 || spec.frames != 480 || spec.padding)
            throw std::runtime_error("reference ABI/config");
        ++counts[2];
        reference_ = (input[0] + input[1]) / 2;
        referenceSeen_ = true;
        return 0;
    }
    virtual int delay(int value) { return value == 17 ? 73 : -1; }
private:
    float reference_ = 0;
    bool referenceSeen_ = false;
};
}
extern "C" void synthetic_aec_throw(unsigned stage) { throwStage = stage; }
extern "C" void synthetic_aec_fail(bool value) { failFactory = value; }
extern "C" unsigned synthetic_aec_count(unsigned index) { return index < 5 ? counts[index] : 999; }
extern "C" Engine* synthetic_aec_create() {
    if (failFactory) throw FactoryError();
    ++counts[0];
    return new Engine;
}
