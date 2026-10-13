#include "noise_engine.hpp"
#include "streaming_noise.hpp"
#include <cassert>
#include <chrono>
#include <cstdio>
#include <limits>
#include <vector>

int main() {
    using labvoice::NoiseEngine;
    NoiseEngine silence;
    std::array<float, 480> in{}, out{};
    for (int f = 0; f < 200; ++f) {
        auto p = silence.process(in.data(), out.data());
        assert(std::isfinite(p) && p >= 0 && p <= 1);
        for (auto x: out) assert(std::isfinite(x) && std::abs(x) < 1e-7f);
    }
    // Independently created streams must produce the same output. This checks
    // state isolation and handling of in-place buffers.
    NoiseEngine a, b;
    auto* raw = rnnoise_create(nullptr);
    assert(raw);
    unsigned rng = 1234567;
    double input_energy = 0, output_energy = 0;
    const auto start = std::chrono::steady_clock::now();
    for (int f = 0; f < 500; ++f) {
        for (auto& x : in) { rng = rng * 1664525U + 1013904223U; x = (float(rng >> 8) / 16777216.0f - .5f) * .1f; }
        auto inplace = in;
        a.process(in.data(), out.data());
        b.process(inplace.data(), inplace.data());
        std::array<float, 480> raw_input{}, raw_output{};
        for (std::size_t i = 0; i < 480; ++i) raw_input[i] = in[i] * 32768.0f;
        rnnoise_process_frame(raw, raw_output.data(), raw_input.data());
        for (std::size_t i = 0; i < 480; ++i) {
            assert(std::isfinite(out[i]) && std::abs(out[i]) <= 1);
            assert(out[i] == inplace[i]);
            assert(out[i] == std::clamp(raw_output[i] / 32768.0f, -1.0f, 1.0f));
            if (f >= 100) { input_energy += in[i]*in[i]; output_energy += out[i]*out[i]; }
        }
    }
    rnnoise_destroy(raw);
    assert(output_energy > 0 && output_energy < input_energy);
    in.fill(std::numeric_limits<float>::quiet_NaN());
    a.process(in.data(), out.data());
    for (float x : out) assert(std::isfinite(x) && std::abs(x) <= 1);
    // Real callback partitions must not alter samples, startup silence or tail.
    std::vector<float> source(480*20+137), one(source.size()), chunks(source.size());
    for (std::size_t i = 0; i < source.size(); ++i) source[i] = .2f*std::sin(float(i)*.081f);
    labvoice::StreamingNoise streaming_a, streaming_b, streaming_inplace;
    streaming_a.process(source.data(), one.data(), source.size());
    std::size_t cursor = 0, partition = 0;
    const std::size_t sizes[] = {1, 15, 128, 480, 511, 960, 4096};
    while (cursor < source.size()) {
        const auto size = std::min(sizes[partition++ % 7], source.size() - cursor);
        streaming_b.process(source.data()+cursor, chunks.data()+cursor, size);
        cursor += size;
    }
    assert(one == chunks);
    auto inplace_stream = source;
    streaming_inplace.process(inplace_stream.data(), inplace_stream.data(), inplace_stream.size());
    assert(one == inplace_stream);
    streaming_b.process(nullptr, nullptr, 0);
    std::array<float, 823> trailing_input{}, trailing_a{}, trailing_b{};
    streaming_a.process(trailing_input.data(), trailing_a.data(), trailing_input.size());
    streaming_b.process(trailing_input.data(), trailing_b.data(), 17);
    streaming_b.process(trailing_input.data()+17, trailing_b.data()+17, trailing_input.size()-17);
    assert(trailing_a == trailing_b);
    for (std::size_t i = 0; i < 480; ++i) assert(one[i] == 0);
    NoiseEngine reference;
    for (std::size_t i = 0; i + 960 <= source.size(); i += 480) {
        reference.process(source.data()+i, out.data());
        for (std::size_t j = 0; j < 480; ++j) assert(one[i+480+j] == out[j]);
    }
    const double elapsed = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
    std::printf("noise engine: finite output, silence, isolated state, in-place equivalence, noise attenuation %.2f dB; verification workload in %.3f s\n", 10*std::log10(input_energy/output_energy), elapsed);
}
