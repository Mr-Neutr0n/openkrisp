#include "worker_protocol.hpp"
#include <cassert>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>
using namespace krisp_probe::wire;
static Token token() { Token t{}; for (unsigned i = 0; i < 16; ++i) t[i] = i; return t; }
static Frame request() {
    Frame f;
    for (unsigned i = 0; i < samples; ++i) f.values[i] = float(i) * 0.125f;
    return f;
}
static unsigned allowed = mask(Kind::request) | mask(Kind::close);
static void tests() {
    Storage bytes{}; const auto size = encode(request(), token(), bytes);
    assert(size == maxFrameBytes);
    const std::array<std::uint8_t, 8> prefix{'O','K','W','P',1,1,0,0};
    for (unsigned i = 0; i < 8; ++i) assert(bytes[i] == prefix[i]);
    for (unsigned i = 0; i < 16; ++i) assert(bytes[8+i] == i);
    assert(bytes[32] == 0x80 && bytes[33] == 7 && bytes[34] == 0 && bytes[35] == 0);
    assert(bytes[40] == 0 && bytes[41] == 0 && bytes[42] == 0 && bytes[43] == 0x3e);
    unsigned calls = 0;
    Parser parser(token(), allowed);
    for (std::size_t i = 0; i < size; ++i)
        assert(parser.push(std::span(bytes.data()+i, 1), [&](const Frame& f) {
            ++calls; assert(f.sequence == 0 && f.values == request().values); return true;
        }));
    assert(calls == 1 && parser.finish() && !parser.finish());
    {
        Frame f = request(); f.kind = Kind::result;
        f.sequence = UINT64_C(0x123456789abcdef0); f.values[0] = -0.0f;
        Storage b{}; assert(encode(f, token(), b) == maxFrameBytes);
        assert(b[5] == 2 && b[24] == 0xf0 && b[31] == 0x12);
        assert(b[36] == 0 && b[37] == 0 && b[38] == 0 && b[39] == 0x80);
        Parser p(token(), mask(Kind::result), f.sequence);
        assert(p.push(b, [&](const Frame& decoded) {
            return decoded.kind == Kind::result && decoded.sequence == f.sequence &&
                std::signbit(decoded.values[0]) && decoded.values == f.values;
        }));
        assert(p.finish());
    }
    for (auto offset : {0u,4u,6u,8u,24u,32u}) {
        auto bad = bytes; bad[offset] ^= 1;
        Parser p(token(), allowed);
        assert(!p.push(bad, [](const Frame&) { return true; }) && p.failed());
    }
    {
        auto bad = bytes; write(bad.data()+headerBytes, 0x7fc00000, 4);
        Parser p(token(), allowed);
        assert(!p.push(bad, [](const Frame&) { return true; }));
        Frame f = request(); f.values[0] = std::numeric_limits<float>::infinity();
        assert(encode(f, token(), bad) == 0);
    }
    for (std::size_t length : {std::size_t(1), headerBytes, maxFrameBytes-1}) {
        Parser p(token(), allowed);
        assert(p.push(std::span(bytes.data(), length), [](const Frame&) { return true; }));
        assert(!p.finish());
    }
    {
        Parser p(token(), allowed);
        assert(!p.push(bytes, [&](const Frame&) {
            assert(!p.push({}, [](const Frame&) { return true; })); return true;
        }));
    }
    {
        Parser p(token(), allowed);
        assert(!p.push(bytes, [](const Frame&) -> bool { throw 1; }));
    }
    {
        Frame f; f.kind = Kind::close;
        Storage b{}; auto n = encode(f, token(), b);
        Parser p(token(), allowed);
        assert(p.push(std::span(b.data(),n), [](const Frame& f) { return f.kind == Kind::close; }));
        assert(p.closed());
        assert(!p.push(std::span(b.data(),1), [](const Frame&) { return true; }));
    }
    {
        Frame f = request(); f.sequence = UINT64_MAX;
        Storage b{}; encode(f,token(),b);
        for (unsigned i=24; i<32; ++i) assert(b[i] == 255);
        Parser p(token(), allowed, UINT64_MAX);
        assert(p.push(b, [](const Frame& f) { return f.sequence == UINT64_MAX; }));
        assert(!p.push(b, [](const Frame&) { return true; }));
    }
}
int main(int argc, char** argv) {
    tests();
    if (argc == 3 && std::string(argv[1]) == "--emit") {
        std::ofstream file(argv[2], std::ios::binary);
        Storage b{}; auto n = encode(request(),token(),b);
        file.write(reinterpret_cast<const char*>(b.data()), n);
        Frame close; close.kind = Kind::close; close.sequence = 1;
        n = encode(close,token(),b); file.write(reinterpret_cast<const char*>(b.data()), n);
        assert(file.good());
    } else if (argc == 3 && std::string(argv[1]) == "--check") {
        std::ifstream file(argv[2], std::ios::binary); assert(file.good());
        Parser p(token(), allowed); unsigned calls=0;
        std::array<std::uint8_t, 113> b{};
        while (file.read(reinterpret_cast<char*>(b.data()), b.size()) || file.gcount()) {
            assert(p.push(std::span(b.data(), static_cast<std::size_t>(file.gcount())), [&](const Frame& f) {
                assert(f.sequence == calls);
                if (calls == 0) assert(f.kind == Kind::request && f.values == request().values);
                else assert(calls == 1 && f.kind == Kind::close);
                ++calls; return true;
            }));
        }
        assert(p.finish() && p.closed() && calls == 2);
    } else assert(argc == 1);
    std::cout << "native worker protocol tests passed\n";
}
