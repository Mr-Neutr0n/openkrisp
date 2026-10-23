#include "aec_worker_broker.hpp"
#include <cassert>
#include <cerrno>
#include <iostream>
#include <sys/wait.h>
#include <unistd.h>

// Own worker and own synthetic library only. The caller supplies absolute paths
// and the SHA256 of that library. No installed application artifacts are used.
int main(int argc, char** argv) {
    using namespace krisp_probe;
    assert(argc == 4); // worker, synthetic library, synthetic library SHA256
    const std::string worker = argv[1], library = argv[2], digest = argv[3];
    assert(!worker.empty() && worker.front() == '/');
    assert(!library.empty() && library.front() == '/');
    assert(digest.size() == 64 && digest.find_first_not_of("0123456789abcdef") == std::string::npos);
    AECWorkerLaunchConfig config;
    config.executable = "/usr/bin/sandbox-exec";
    config.arguments = {"-p", "(version 1) (allow default) (deny network*)", worker,
                        library, digest, "000102030405060708090a0b0c0d0e0f", std::to_string(getpid())};
    config.environment = {"PATH=/usr/bin:/bin"};
    config.expectedReadyLine = "OKAEC1 " + digest + " 48000 1 48000 2\n";
    for (unsigned i = 0; i < config.token.size(); ++i) config.token[i] = static_cast<std::uint8_t>(i);
    config.frameTimeout = std::chrono::milliseconds(1000);
    AECWorkerBroker broker(std::move(config));
    assert(broker.start());
    aec_wire::Frame input, output;
    input.epoch = 91;
    input.microphoneTiming = {10.25, 137.75, 100, 3};
    input.referenceTiming = {-899.5, 307.25, 900, 3};
    for (unsigned sequence = 0; sequence < 37; ++sequence) {
        input.sequence = sequence;
        // The synthetic AEC subtracts the mean of the first stereo pair.
        // Distinct channels and sample-varying microphone values distinguish
        // this native path from the broker-only fixture's addition operation.
        input.reference.fill(-99.0f);
        input.reference[0] = float(sequence) / 16.0f;
        input.reference[1] = float(sequence + 2) / 16.0f;
        for (std::size_t i = 0; i < input.microphone.size(); ++i)
            input.microphone[i] = float(i) / 32.0f + float(sequence);
        assert(broker.process480(input, output));
        assert(output.kind == aec_wire::Kind::result && output.sequence == sequence && output.epoch == input.epoch);
        assert(output.microphoneTiming == input.microphoneTiming && output.referenceTiming == input.referenceTiming);
        const float reference = (input.reference[0] + input.reference[1]) / 2.0f;
        for (std::size_t i = 0; i < output.output.size(); ++i)
            assert(output.output[i] == input.microphone[i] - reference);
        for (auto* timing : {&input.microphoneTiming, &input.referenceTiming}) {
            timing->inputSampleOrigin += 480;
            timing->outputSampleOrigin += 480;
            timing->hostTime += 100;
        }
    }
    assert(broker.service());
    assert(broker.close() && broker.error().empty());
    int status = 0;
    errno = 0;
    assert(waitpid(broker.childPID(), &status, WNOHANG) == -1 && errno == ECHILD);
    std::cout << "AEC broker/native-worker/synthetic-library integration passed\n";
}
