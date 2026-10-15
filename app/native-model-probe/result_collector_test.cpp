#include "abi_supplier.hpp"
#include "result_collector.hpp"
#include <cstdlib>
#include <iostream>
#include <limits>

using namespace native_model_probe;

static void require(bool condition, const char* message) {
    if (!condition) { std::cerr << message << '\n'; std::exit(1); }
}

int main() {
    ResultCollector copied(3, 6);
    {
        NCResultValue borrowed;
        borrowed.samples = {0.25f, -0.5f, 1.0f};
        copied.accept(borrowed);
        borrowed.samples.assign(100, 99.0f);
        borrowed.samples.clear();
        borrowed.samples.shrink_to_fit();
    }
    require(copied.samples() == std::vector<float>({0.25f, -0.5f, 1.0f}), "borrowed storage escaped callback");
    NCResultValue valid; valid.samples = {0.0f, -1.0f, 0.5f};
    copied.accept(valid);
    require(copied.error() == ResultError::none && copied.samples().size() == 6 && copied.callbackCount() == 2, "valid callbacks failed");
    copied.accept(valid);
    require(copied.error() == ResultError::outputLimit && copied.samples().size() == 6 && copied.callbackCount() == 3, "output bound failed");

    for (std::size_t count : {std::size_t(0), std::size_t(2), std::size_t(4)}) {
        ResultCollector malformed(3, 6);
        NCResultValue input; input.samples.assign(count, 0.0f);
        malformed.accept(input); malformed.accept(valid);
        require(malformed.error() == ResultError::wrongCount && malformed.samples().empty() && malformed.callbackCount() == 2, "malformed count was accepted or error was cleared");
    }
    for (float bad : {std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::infinity(), -std::numeric_limits<float>::infinity()}) {
        ResultCollector finite(3, 6);
        finite.accept(valid);
        NCResultValue input; input.samples = {0.0f, bad, 1.0f};
        finite.accept(input);
        require(finite.error() == ResultError::nonfinite && finite.samples() == valid.samples && finite.callbackCount() == 2, "nonfinite callback partially copied");
    }
    ResultCollector zeroCapacity(3, 0);
    zeroCapacity.accept(valid);
    require(zeroCapacity.error() == ResultError::outputLimit && zeroCapacity.samples().empty(), "zero output limit ignored");
    bool rejected = false;
    try { ResultCollector invalid(0, 3); } catch (const std::invalid_argument&) { rejected = true; }
    require(rejected, "zero expected frame count accepted");
    std::cout << "result collector tests passed\n";
}
