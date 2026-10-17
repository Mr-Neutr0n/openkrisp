#include <node_api.h>
#include "abi_factory.hpp"
#include "result_collector.hpp"
#include <atomic>
#include <cmath>
#include <cstring>
#include <cstdio>
#include <dlfcn.h>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {
using namespace native_model_probe;
constexpr std::size_t frameSize = 480;
constexpr std::size_t maximumSamples = 96000;
constexpr const char* factorySymbol =
    "_ZN5KRISP20createFrameProcessorIfNS_5Audio16StreamDescriptorENS1_17NoiseCancellation13ConfigurationENS3_29PerFrameConfigurationSupplierENS3_22ResultHandlerWithStatsIfEEEENSt3__110shared_ptrINS_34FrameProcessorWithStreamDescriptorIT_T0_EEEERKNS_9SdkConfigERKSC_RKT1_NS9_IT2_EENS9_IT3_EE";
std::atomic_flag running = ATOMIC_FLAG_INIT;

void check(napi_status status) {
    if (status != napi_ok) throw std::runtime_error("Node API operation failed");
}
napi_value property(napi_env env, napi_value object, const char* key) {
    napi_value value;
    check(napi_get_named_property(env, object, key, &value));
    return value;
}
bool has(napi_env env, napi_value object, const char* key) {
    bool found = false; check(napi_has_named_property(env, object, key, &found)); return found;
}
double number(napi_env env, napi_value value) {
    napi_valuetype type; check(napi_typeof(env, value, &type));
    if (type != napi_number) throw std::invalid_argument("Expected a number");
    double result; check(napi_get_value_double(env, value, &result));
    if (!std::isfinite(result)) throw std::invalid_argument("Expected a finite number");
    return result;
}
struct Path {
    std::string utf8;
    std::wstring wide;
};
Path path(napi_env env, napi_value value) {
    napi_valuetype type; check(napi_typeof(env, value, &type));
    if (type != napi_string) throw std::invalid_argument("Paths must be strings");
    std::size_t length = 0;
    check(napi_get_value_string_utf16(env, value, nullptr, 0, &length));
    if (length == 0 || length > 4096) throw std::invalid_argument("Invalid path length");
    std::vector<char16_t> units(length + 1);
    check(napi_get_value_string_utf16(env, value, units.data(), units.size(), &length));
    if (units[0] != u'/') throw std::invalid_argument("Paths must be absolute");
    static_assert(sizeof(wchar_t) == 4);
    Path result;
    for (std::size_t index = 0; index < length; ++index) {
        std::uint32_t code = units[index];
        if (code == 0) throw std::invalid_argument("Paths cannot contain NUL");
        if (code >= 0xd800 && code <= 0xdbff) {
            if (++index >= length || units[index] < 0xdc00 || units[index] > 0xdfff)
                throw std::invalid_argument("Invalid path Unicode");
            code = 0x10000 + ((code - 0xd800) << 10) + (units[index] - 0xdc00);
        } else if (code >= 0xdc00 && code <= 0xdfff) {
            throw std::invalid_argument("Invalid path Unicode");
        }
        result.wide.push_back(static_cast<wchar_t>(code));
    }
    std::size_t bytes = 0; check(napi_get_value_string_utf8(env, value, nullptr, 0, &bytes));
    std::vector<char> encoded(bytes + 1);
    check(napi_get_value_string_utf8(env, value, encoded.data(), encoded.size(), &bytes));
    result.utf8.assign(encoded.data(), bytes);
    return result;
}
struct Options {
    Path addon, model;
    std::vector<float> input;
    float suppression = 100;
    bool bypass = false;
};
Options options(napi_env env, napi_value value, bool withInput = true) {
    napi_valuetype type; check(napi_typeof(env, value, &type));
    if (type != napi_object) throw std::invalid_argument("run requires an options object");
    if (number(env, property(env, value, "sampleRate")) != 48000 ||
        number(env, property(env, value, "frameSize")) != frameSize)
        throw std::invalid_argument("Only 480-sample frames at 48000 Hz are supported");
    Options result;
    result.addon = path(env, property(env, value, "addonPath"));
    result.model = path(env, property(env, value, "modelPath"));
    if (has(env, value, "suppressionLevel")) {
        const double level = number(env, property(env, value, "suppressionLevel"));
        if (level < 0 || level > 100) throw std::invalid_argument("suppressionLevel must be 0 through 100");
        result.suppression = static_cast<float>(level);
    }
    if (has(env, value, "bypass")) {
        napi_value bypass = property(env, value, "bypass");
        check(napi_typeof(env, bypass, &type));
        if (type != napi_boolean) throw std::invalid_argument("bypass must be boolean");
        check(napi_get_value_bool(env, bypass, &result.bypass));
    }
    if (!withInput) return result;
    napi_value input = property(env, value, "input");
    bool typed = false; check(napi_is_typedarray(env, input, &typed));
    if (!typed) throw std::invalid_argument("input must be a Float32Array");
    napi_typedarray_type arrayType; std::size_t length, offset; void* data; napi_value buffer;
    check(napi_get_typedarray_info(env, input, &arrayType, &length, &data, &buffer, &offset));
    if (arrayType != napi_float32_array || length == 0 || length > maximumSamples || length % frameSize != 0 || data == nullptr)
        throw std::invalid_argument("input must contain 1 through 200 whole 480-sample Float32 frames");
    const auto* samples = static_cast<const float*>(data);
    result.input.assign(samples, samples + length);
    for (float sample : result.input)
        if (!std::isfinite(sample)) throw std::invalid_argument("input contains nonfinite samples");
    return result;
}

class Image {
public:
    explicit Image(const std::string& name) : handle_(dlopen(name.c_str(), RTLD_NOW | RTLD_LOCAL)) {
        if (!handle_) {
            const char* detail = dlerror();
            throw std::runtime_error(std::string("Cannot load the selected native image: ") + (detail ? detail : "no loader diagnostic"));
        }
    }
    ~Image() { if (handle_) dlclose(handle_); }
    void* symbol() {
        dlerror(); void* result = dlsym(handle_, factorySymbol);
        if (dlerror() != nullptr || result == nullptr) throw std::runtime_error("The exact ordinary NC factory export is unavailable");
        return result;
    }
    bool close() noexcept {
        void* previous = std::exchange(handle_, nullptr);
        return previous == nullptr || dlclose(previous) == 0;
    }
private:
    void* handle_;
};
struct FixedSupplier final : Supplier {
    explicit FixedSupplier(const Options& value) : value_{static_cast<std::uint8_t>(value.bypass), 0, 0, 1, value.suppression} {}
    PerFrameValue supply() const noexcept override { return value_; }
    const PerFrameValue value_;
};
struct CopyHandler final : Handler {
    explicit CopyHandler(std::size_t maximum) : collector(frameSize, maximum) {}
    void handle(NCResultValue& value) noexcept override { collector.accept(value); }
    ResultCollector collector;
};
struct Output {
    std::vector<float> samples;
    std::uint64_t callbacks;
    std::size_t frames;
};
Output process(const Options& value, Image& image) {
    // The unused first machine argument is justified only for the reviewed digest.
    // Identity/network gates belong to run_probe.cjs before invoking this function.
    alignas(16) static const std::byte unusedSdkToken[16]{};
    const Descriptor descriptor{10, 48000};
    const Configuration configuration{48000, value.model.wide, nullptr, 0, 0};
    auto supplier = std::make_shared<FixedSupplier>(value);
    auto handler = std::make_shared<CopyHandler>(value.input.size());
    const auto factory = reinterpret_cast<FactoryABI>(image.symbol());
    auto processor = factory(unusedSdkToken, descriptor, configuration, supplier, handler);
    if (!processor) throw std::runtime_error("The factory returned no processor");
    std::vector<float> frame(frameSize);
    std::size_t completed = 0;
    for (std::size_t offset = 0; offset < value.input.size(); offset += frameSize) {
        std::memcpy(frame.data(), value.input.data() + offset, frameSize * sizeof(float));
        const auto before = handler->collector.callbackCount();
        processor->process(frame); // Direct call does not change SDK registration state.
        if (handler->collector.error() != ResultError::none)
            throw std::runtime_error("The result callback rejected its count, samples, copy or output bound");
        if (handler->collector.callbackCount() != before + 1)
            throw std::runtime_error("Expected exactly one synchronous result callback per frame");
        ++completed;
    }
    if (handler->collector.samples().size() != value.input.size())
        throw std::runtime_error("Processed output length does not match whole-frame input length");
    // Keep descriptor, configuration, callbacks and image alive through original deletion.
    processor.reset();
    return {handler->collector.samples(), handler->collector.callbackCount(), completed};
}

void set(napi_env env, napi_value object, const char* name, napi_value value) {
    check(napi_set_named_property(env, object, name, value));
}
napi_value boolean(napi_env env, bool value) { napi_value result; check(napi_get_boolean(env, value, &result)); return result; }
napi_value integer(napi_env env, std::uint64_t value) { napi_value result; check(napi_create_double(env, static_cast<double>(value), &result)); return result; }
napi_value runImpl(napi_env env, napi_callback_info info) {
    if (running.test_and_set()) { napi_throw_error(env, nullptr, "A native probe is already running"); return nullptr; }
    struct Admission { ~Admission() { running.clear(); } } admission;
    // Keep the image loaded until caught vendor exception objects are destroyed.
    std::unique_ptr<Image> image;
    std::string failure;
    Output output{};
    try {
        std::size_t count = 0; napi_value argument;
        check(napi_get_cb_info(env, info, &count, nullptr, nullptr, nullptr));
        if (count != 1) throw std::invalid_argument("run requires one options object");
        check(napi_get_cb_info(env, info, &count, &argument, nullptr, nullptr));
        const auto value = options(env, argument);
        image = std::make_unique<Image>(value.addon.utf8);
        output = process(value, *image);
    } catch (const std::exception& error) {
        failure = error.what();
    } catch (...) {
        failure = "Unknown native processing exception";
    }
    if (image && !image->close()) failure = "Native ownership was released but image unload could not be confirmed";
    image.reset();
    bool pending = false;
    if (napi_is_exception_pending(env, &pending) != napi_ok) return nullptr;
    if (pending) return nullptr;
    if (!failure.empty()) { napi_throw_error(env, nullptr, failure.c_str()); return nullptr; }
    try {
        napi_value result, buffer, samples; void* bytes;
        check(napi_create_object(env, &result));
        check(napi_create_arraybuffer(env, output.samples.size() * sizeof(float), &bytes, &buffer));
        std::memcpy(bytes, output.samples.data(), output.samples.size() * sizeof(float));
        check(napi_create_typedarray(env, napi_float32_array, output.samples.size(), buffer, 0, &samples));
        set(env, result, "samples", samples);
        set(env, result, "framesProcessed", integer(env, output.frames));
        set(env, result, "callbackCount", integer(env, output.callbacks));
        set(env, result, "processorConstructed", boolean(env, true));
        set(env, result, "directProcessInvoked", boolean(env, true));
        set(env, result, "teardownComplete", boolean(env, true));
        napi_value backend; check(napi_create_string_utf8(env, "ordinary-nc-direct", NAPI_AUTO_LENGTH, &backend));
        set(env, result, "backend", backend);
        return result;
    } catch (...) {
        bool exception = false; napi_is_exception_pending(env, &exception);
        if (!exception) napi_throw_error(env, nullptr, "Cannot create the owned probe result");
        return nullptr;
    }
}
napi_value run(napi_env env, napi_callback_info info) {
    try {
        return runImpl(env, info);
    } catch (...) {
        // Also contain allocation failures while formatting another exception.
        bool pending = false;
        if (napi_is_exception_pending(env, &pending) == napi_ok && !pending)
            napi_throw_error(env, nullptr, "Native probe failed before returning a result");
        return nullptr;
    }
}

// Session methods never call JavaScript while vendor ownership is in use. The
// module admission flag also covers getters during open/run option validation.
struct BatchHandler final : Handler {
    std::unique_ptr<ResultCollector> batch;
    bool unexpected = false;
    void handle(NCResultValue& value) noexcept override {
        if (batch) batch->accept(value);
        else unexpected = true;
    }
};
struct Session {
    std::unique_ptr<Image> image;
    const Descriptor descriptor{10, 48000};
    Configuration configuration;
    std::shared_ptr<FixedSupplier> supplier;
    std::shared_ptr<BatchHandler> handler;
    std::shared_ptr<ProcessorView> processor;
    bool closed = false;
    bool teardownComplete = true;
    bool callbackContractViolated = false;
    explicit Session(const Options& value)
        : configuration{48000, value.model.wide, nullptr, 0, 0},
          supplier(std::make_shared<FixedSupplier>(value)),
          handler(std::make_shared<BatchHandler>()) {}
    void construct(const Options& value) {
        image = std::make_unique<Image>(value.addon.utf8);
        alignas(16) static const std::byte token[16]{};
        auto factory = reinterpret_cast<FactoryABI>(image->symbol());
        processor = factory(token, descriptor, configuration, supplier, handler);
        if (!processor) throw std::runtime_error("The factory returned no processor");
        if (handler->unexpected) throw std::runtime_error("Unexpected callback outside a process batch");
    }
    bool close() noexcept {
        closed = true;
        if (handler) handler->batch.reset();
        processor.reset();
        if (handler && handler->unexpected) callbackContractViolated = true;
        handler.reset();
        supplier.reset();
        if (image && !image->close()) teardownComplete = false;
        return teardownComplete;
    }
    ~Session() { close(); }
};
const napi_type_tag sessionTag{0x379522d95786b310ULL, 0x934ef136c826e351ULL};
void finalizeSession(napi_env, void* value, void*) { delete static_cast<Session*>(value); }
Session* receiver(napi_env env, napi_callback_info info, std::size_t expected, napi_value* args) {
    std::size_t count = 0; napi_value self;
    check(napi_get_cb_info(env, info, &count, nullptr, &self, nullptr));
    if (count != expected) throw std::invalid_argument("Incorrect session method argument count");
    check(napi_get_cb_info(env, info, &count, args, &self, nullptr));
    bool tagged = false;
    check(napi_check_object_type_tag(env, self, &sessionTag, &tagged));
    if (!tagged) throw std::invalid_argument("Invalid native session receiver");
    void* data = nullptr; check(napi_unwrap(env, self, &data));
    if (!data) throw std::invalid_argument("Invalid native session receiver");
    return static_cast<Session*>(data);
}
std::vector<float> batchInput(napi_env env, napi_value input) {
    bool typed = false; check(napi_is_typedarray(env, input, &typed));
    if (!typed) throw std::invalid_argument("input must be a Float32Array");
    napi_typedarray_type type; std::size_t length, offset; void* data; napi_value buffer;
    check(napi_get_typedarray_info(env, input, &type, &length, &data, &buffer, &offset));
    if (type != napi_float32_array || !length || length > maximumSamples || length % frameSize || !data)
        throw std::invalid_argument("input must contain 1 through 200 whole 480-sample Float32 frames");
    auto* samples = static_cast<float*>(data);
    std::vector<float> result(samples, samples + length);
    for (float sample : result) if (!std::isfinite(sample))
        throw std::invalid_argument("input contains nonfinite samples");
    return result;
}
void fail(napi_env env, const char* message) {
    bool pending = false;
    if (napi_is_exception_pending(env, &pending) == napi_ok && !pending)
        napi_throw_error(env, nullptr, message);
}
struct Admission { ~Admission() { running.clear(); } };
napi_value sessionProcessImpl(napi_env env, napi_callback_info info) {
    if (running.test_and_set()) { napi_throw_error(env, nullptr, "A native probe is already running"); return nullptr; }
    Admission admission;
    Session* session = nullptr;
    bool enteredNative = false;
    char failure[1024]{};
    try {
        napi_value argument;
        session = receiver(env, info, 1, &argument);
        if (session->closed) throw std::runtime_error("Native session is closed");
        const auto input = batchInput(env, argument); // Invalid input preserves the session.
        session->handler->batch = std::make_unique<ResultCollector>(frameSize, input.size());
        std::vector<float> frame(frameSize);
        enteredNative = true;
        if (session->handler->unexpected) throw std::runtime_error("Unexpected callback outside a process batch");
        auto& collector = *session->handler->batch;
        for (std::size_t offset = 0; offset < input.size(); offset += frameSize) {
            std::memcpy(frame.data(), input.data() + offset, frameSize * sizeof(float));
            auto before = collector.callbackCount();
            session->processor->process(frame);
            if (collector.error() != ResultError::none || collector.callbackCount() != before + 1)
                throw std::runtime_error("Expected one valid synchronous result callback per frame");
        }
        if (collector.samples().size() != input.size()) throw std::runtime_error("Output length mismatch");
        napi_value result, buffer, samples; void* bytes;
        check(napi_create_object(env, &result));
        check(napi_create_arraybuffer(env, input.size() * sizeof(float), &bytes, &buffer));
        std::memcpy(bytes, collector.samples().data(), input.size() * sizeof(float));
        check(napi_create_typedarray(env, napi_float32_array, input.size(), buffer, 0, &samples));
        set(env, result, "samples", samples);
        set(env, result, "framesProcessed", integer(env, input.size() / frameSize));
        set(env, result, "callbackCount", integer(env, collector.callbackCount()));
        set(env, result, "processorConstructed", boolean(env, true));
        set(env, result, "directProcessInvoked", boolean(env, true));
        napi_value backend; check(napi_create_string_utf8(env, "ordinary-nc-direct", NAPI_AUTO_LENGTH, &backend));
        set(env, result, "backend", backend);
        session->handler->batch.reset();
        return result;
    } catch (const std::exception& error) { std::snprintf(failure, sizeof(failure), "%s", error.what()); }
      catch (...) { std::snprintf(failure, sizeof(failure), "%s", "Unknown native session processing exception"); }
    // Caught vendor exceptions are destroyed before releasing their code image.
    if (enteredNative && session && !session->close()) std::snprintf(failure, sizeof(failure), "%s", "Native image unload could not be confirmed");
    fail(env, failure); return nullptr;
}
napi_value sessionCloseImpl(napi_env env, napi_callback_info info) {
    if (running.test_and_set()) { napi_throw_error(env, nullptr, "A native probe is already running"); return nullptr; }
    Admission admission;
    try {
        auto* session = receiver(env, info, 0, nullptr);
        if (!session->close()) throw std::runtime_error("Native image unload could not be confirmed");
        if (session->callbackContractViolated) throw std::runtime_error("Unexpected callback outside a process batch");
        napi_value result; check(napi_create_object(env, &result));
        set(env, result, "teardownComplete", boolean(env, true)); return result;
    } catch (const std::exception& error) { fail(env, error.what()); }
      catch (...) { fail(env, "Native session close failed"); }
    return nullptr;
}
template<napi_value (*Function)(napi_env, napi_callback_info)>
napi_value contain(napi_env env, napi_callback_info info) noexcept {
    try { return Function(env, info); }
    catch (...) {
        bool pending = false;
        if (napi_is_exception_pending(env, &pending) == napi_ok && !pending)
            napi_throw_error(env, nullptr, "Native session operation failed");
        return nullptr;
    }
}
napi_value sessionProcess(napi_env env, napi_callback_info info) { return contain<sessionProcessImpl>(env, info); }
napi_value sessionClose(napi_env env, napi_callback_info info) { return contain<sessionCloseImpl>(env, info); }
napi_value openImpl(napi_env env, napi_callback_info info) {
    if (running.test_and_set()) { napi_throw_error(env, nullptr, "A native probe is already running"); return nullptr; }
    Admission admission;
    std::unique_ptr<Session> session;
    char failure[1024]{};
    try {
        std::size_t count = 0; napi_value argument;
        check(napi_get_cb_info(env, info, &count, nullptr, nullptr, nullptr));
        if (count != 1) throw std::invalid_argument("open requires one options object");
        check(napi_get_cb_info(env, info, &count, &argument, nullptr, nullptr));
        const auto value = options(env, argument, false);
        session = std::make_unique<Session>(value);
        session->construct(value);
        napi_value object; check(napi_create_object(env, &object));
        const napi_property_descriptor methods[] = {
            {"process", nullptr, sessionProcess, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"close", nullptr, sessionClose, nullptr, nullptr, nullptr, napi_default, nullptr}};
        check(napi_define_properties(env, object, 2, methods));
        check(napi_type_tag_object(env, object, &sessionTag));
        check(napi_wrap(env, object, session.get(), finalizeSession, nullptr, nullptr));
        session.release(); return object;
    } catch (const std::exception& error) { std::snprintf(failure, sizeof(failure), "%s", error.what()); }
      catch (...) { std::snprintf(failure, sizeof(failure), "%s", "Unknown native session construction exception"); }
    session.reset(); // Exception object has gone before image unload.
    fail(env, failure); return nullptr;
}
napi_value open(napi_env env, napi_callback_info info) { return contain<openImpl>(env, info); }
napi_value initialize(napi_env env, napi_value exports) {
    napi_value function;
    if (napi_create_function(env, "run", NAPI_AUTO_LENGTH, run, nullptr, &function) != napi_ok ||
        napi_set_named_property(env, exports, "run", function) != napi_ok) {
        napi_throw_error(env, nullptr, "Cannot initialize native probe exports"); return nullptr;
    }
    if (napi_create_function(env, "open", NAPI_AUTO_LENGTH, open, nullptr, &function) != napi_ok ||
        napi_set_named_property(env, exports, "open", function) != napi_ok) {
        napi_throw_error(env, nullptr, "Cannot initialize native session export"); return nullptr;
    }
    return exports;
}
} // namespace

NAPI_MODULE(native_model_probe, initialize)
