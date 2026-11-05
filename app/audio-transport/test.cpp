#include "transport.hpp"
#include <array>
#include <cassert>
#include <chrono>
#include <iostream>
#include <thread>
using krisp_local::Transport;

int main() {
    for (uint32_t channels : {1u, 2u}) {
        Transport ring(channels, 4);
        std::array<float, 16> in{}, out{};
        out.fill(99);
        assert(ring.read(0, out.data(), 4, 0, 10) == 0);
        for (unsigned i = 0; i < 4 * channels; ++i) assert(out[i] == 0);
        for (unsigned i = 0; i < 8 * channels; ++i) in[i] = float(i + 1);
        assert(ring.write(0, in.data(), 3, 100));
        assert(ring.read(0, out.data(), 4, 100, 10) == 3);
        for (unsigned i = 0; i < 3 * channels; ++i) assert(out[i] == in[i]);
        for (unsigned i = 3 * channels; i < 4 * channels; ++i) assert(out[i] == 0);
        assert(ring.write(3, in.data() + 3 * channels, 3, 101));
        assert(ring.read(0, out.data(), 6, 101, 10) == 4);
        for (unsigned i = 0; i < 2 * channels; ++i) assert(out[i] == 0);
        for (unsigned i = 2 * channels; i < 6 * channels; ++i) assert(out[i] == in[i]);
        assert(ring.read(2, out.data(), 4, 112, 10) == 0);
        for (unsigned i = 0; i < 4 * channels; ++i) assert(out[i] == 0);
        assert(ring.read(2, out.data(), 4, 100, 10) == 0);
        assert(!ring.write(5, in.data(), 1, 102));
        assert(!ring.write(6, in.data(), 1, 100));
        assert(!ring.write(UINT64_MAX, in.data(), 1, 102));
        assert(ring.write(10, in.data(), 2, 102));
        assert(ring.read(6, out.data(), 6, 102, 10) == 2);
        for (unsigned i = 0; i < 4 * channels; ++i) assert(out[i] == 0);
        assert(ring.read(UINT64_MAX, out.data(), 2, 102, 10) == 0);
    }

    Transport ring(2, 31);
    std::atomic<uint64_t> hint{0};
    std::atomic<bool> done{false};
    std::atomic<bool> firstObserved{false};
    std::thread producer([&] {
        for (uint64_t frame = 1; frame <= 200000; ++frame) {
            float pair[] = {float(frame), -float(frame)};
            assert(ring.write(frame, pair, 1, 0));
            hint.store(frame);
            // Admit one stable read before racing slot replacement. A scheduler
            // may otherwise finish every write during the reader's first miss.
            if (frame == 1) {
                const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
                while (!firstObserved.load()) {
                    assert(std::chrono::steady_clock::now() < deadline);
                    std::this_thread::yield();
                }
            }
        }
        done.store(true);
    });
    uint64_t checked = 0;
    do {
        const auto frame = hint.load();
        float pair[2] = {99, 99};
        const auto copied = ring.read(frame, pair, 1, 0, 0);
        if (copied) {
            assert(pair[0] == float(frame) && pair[1] == -float(frame));
            if (frame == 1) firstObserved.store(true);
            ++checked;
        } else assert(pair[0] == 0 && pair[1] == 0);
        // Race a reader against writes into the same slot across many wraps.
        const uint64_t old = frame > 31 ? frame - 31 : 0;
        const auto old_copied = ring.read(old, pair, 1, 0, 0);
        if (old_copied) assert(pair[0] == float(old) && pair[1] == -float(old));
        else assert(pair[0] == 0 && pair[1] == 0);
    } while (!done.load());
    producer.join();
    assert(checked > 0);
    float last[2]{};
    assert(ring.read(200000, last, 1, 0, 0) == 1);
    assert(last[0] == 200000 && last[1] == -200000);
    std::cout << "transport checks passed, concurrent complete frames: " << checked << '\n';
}
