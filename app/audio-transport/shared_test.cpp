#include "shared_transport.hpp"
#include <cassert>
#include <ctime>
#include <iostream>
#include <memory>
#include <sys/wait.h>
using krisp_local::SharedTransport;
static uint64_t now() {
    timespec t{}; assert(clock_gettime(CLOCK_MONOTONIC, &t) == 0);
    return uint64_t(t.tv_sec) * 1000000000 + uint64_t(t.tv_nsec);
}
static void send(int fd, char c) { assert(::write(fd, &c, 1) == 1); }
static char receive(int fd) { char c = 0; assert(::read(fd, &c, 1) == 1); return c; }
int main(int argc, char** argv) {
    if (argc == 5) {
        SharedTransport reader(argv[2]);
        const int reply = std::stoi(argv[3]), command = std::stoi(argv[4]);
        float output[8];
        assert(reader.read(0, output, 4, now(), 1000000000) == 0);
        for (unsigned i = 0; i < 4 * reader.channels(); ++i) assert(output[i] == 0);
        const float input[2] = {1, -1};
        assert(!reader.write(0, input, 1, now()));
        send(reply, 'R');
        uint64_t accepted = 0;
        uint64_t end;
        do {
            end = reader.end_frame();
            if (!end) continue;
            const auto frame = end - 1;
            if (reader.read(frame, output, 1, now(), 1000000000)) {
                assert(output[0] == float(frame));
                if (reader.channels() == 2) assert(output[1] == -float(frame));
                ++accepted;
            } else {
                assert(output[0] == 0);
                if (reader.channels() == 2) assert(output[1] == 0);
            }
            const auto old = frame > 31 ? frame - 31 : 0;
            if (reader.read(old, output, 1, now(), 1000000000)) {
                assert(output[0] == float(old));
                if (reader.channels() == 2) assert(output[1] == -float(old));
            } else assert(output[0] == 0);
        } while (end < 100001);
        assert(accepted > 0);
        assert(reader.read(100000, output, 1, now(), 1000000000) == 1);
        assert(output[0] == 100000);
        usleep(5000);
        assert(reader.read(100000, output, 1, now(), 1000000) == 0);
        assert(output[0] == 0);
        send(reply, 'D');
        assert(receive(command) == 'G');
        float gap[24]{};
        assert(reader.read(100001, gap, 11, now(), 1000000000) == 2);
        for (unsigned i = 0; i < 9 * reader.channels(); ++i) assert(gap[i] == 0);
        assert(gap[9 * reader.channels()] == 100010);
        assert(gap[10 * reader.channels()] == 100011);
        send(reply, 'G');
        assert(receive(command) == 'C');
        assert(reader.read(100000, output, 1, now(), UINT64_MAX) == 0);
        assert(output[0] == 0);
        std::cout << "cross-process " << reader.channels() << " channels, complete frames: " << accepted << '\n';
        return 0;
    }
    for (uint32_t channels : {1u, 2u}) {
        const std::string name = "/kl-test-" + std::to_string(getpid()) + "-" + std::to_string(channels);
        auto owner = std::make_unique<SharedTransport>(name, channels, 31);
        bool duplicate_failed = false;
        try { SharedTransport duplicate(name, channels, 31); } catch (const std::runtime_error&) { duplicate_failed = true; }
        assert(duplicate_failed);
        int replies[2], commands[2]; assert(pipe(replies) == 0 && pipe(commands) == 0);
        const pid_t child = fork(); assert(child >= 0);
        if (child == 0) {
            close(replies[0]); close(commands[1]);
            const auto reply = std::to_string(replies[1]), command = std::to_string(commands[0]);
            execl(argv[0], argv[0], "child", name.c_str(), reply.c_str(), command.c_str(), nullptr);
            _exit(127);
        }
        close(replies[1]); close(commands[0]);
        assert(receive(replies[0]) == 'R');
        float samples[2];
        for (uint64_t frame = 1; frame <= 100000; ++frame) {
            samples[0] = float(frame); samples[1] = -float(frame);
            assert(owner->write(frame, samples, 1, now()));
        }
        assert(!owner->write(100000, samples, 1, now()));
        assert(!owner->write(100001, samples, 961, now()));
        assert(receive(replies[0]) == 'D');
        float jump[4] = {100010, -100010, 100011, -100011};
        if (channels == 1) jump[1] = 100011;
        assert(owner->write(100010, jump, 2, now()));
        send(commands[1], 'G');
        assert(receive(replies[0]) == 'G');
        owner.reset();
        send(commands[1], 'C');
        int status = 0; assert(waitpid(child, &status, 0) == child);
        assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
        close(replies[0]); close(commands[1]);
        bool removed = false;
        try { SharedTransport missing(name); } catch (const std::runtime_error&) { removed = true; }
        assert(removed);
    }
    // Abrupt owner exit leaves mappings and name alive, but heartbeat expires.
    const std::string crash_name = "/kl-crash-" + std::to_string(getpid());
    int replies[2], commands[2]; assert(pipe(replies) == 0 && pipe(commands) == 0);
    const auto child = fork(); assert(child >= 0);
    if (child == 0) {
        close(replies[0]); close(commands[1]);
        SharedTransport writer(crash_name, 2, 4);
        send(replies[1], 'R');
        assert(receive(commands[0]) == 'W');
        float pair[] = {7, -7};
        assert(writer.write(7, pair, 1, now()));
        send(replies[1], 'D');
        _exit(0); // Deliberately bypass owner cleanup.
    }
    close(replies[1]); close(commands[0]);
    assert(receive(replies[0]) == 'R');
    SharedTransport survivor(crash_name);
    send(commands[1], 'W');
    assert(receive(replies[0]) == 'D');
    int status = 0; assert(waitpid(child, &status, 0) == child);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
    float pair[2]{};
    assert(survivor.read(7, pair, 1, now(), 1000000000) == 1);
    assert(pair[0] == 7 && pair[1] == -7);
    usleep(5000);
    assert(survivor.read(7, pair, 1, now(), 1000000) == 0);
    assert(pair[0] == 0 && pair[1] == 0);
    assert(shm_unlink(crash_name.c_str()) == 0);
    close(replies[0]); close(commands[1]);
    std::cout << "shared owner lifecycle and abrupt-exit checks passed\n";
}
