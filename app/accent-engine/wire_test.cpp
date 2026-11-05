#include "wire.hpp"
#include <cassert>
#include <vector>

int main() {
    using namespace accent_engine::wire;
    const Token token{0x47};
    Storage bytes{};
    Frame empty{Kind::empty, 0, {}};
    assert(encode(empty, token, bytes) == headerBytes);
    Parser parser(token, mask(Kind::empty) | mask(Kind::result) | mask(Kind::close));
    unsigned count = 0;
    auto accept = [&](const Frame& value) {
        assert(value.sequence == count);
        assert(value.kind == (count == 0 ? Kind::empty : count == 1 ? Kind::result : Kind::close));
        if (value.kind == Kind::result) assert(value.values[4] == 0.25f);
        ++count; return true;
    };
    for (std::size_t i = 0; i < headerBytes; ++i)
        assert(parser.push({bytes.data() + i, 1}, accept));
    Frame result{Kind::result, 1, {}}; result.values.fill(0.25f);
    const auto length = encode(result, token, bytes);
    for (std::size_t i = 0; i < length; ++i)
        assert(parser.push({bytes.data() + i, 1}, accept));
    Frame closed{Kind::close, 2, {}};
    assert(encode(closed, token, bytes) == headerBytes);
    assert(parser.push({bytes.data(), headerBytes}, accept));
    assert(parser.finish() && parser.closed() && count == 3);
    Parser bad(token, mask(Kind::empty));
    encode(empty, token, bytes); bytes[32] = 4;
    assert(!bad.push({bytes.data(), headerBytes}, [](const Frame&) { return true; }));
    assert(bad.failed());
}
