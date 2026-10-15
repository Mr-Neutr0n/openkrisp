#pragma once

#include "abi_result.hpp"
#include <cmath>
#include <cstdint>
#include <limits>
#include <stdexcept>

namespace native_model_probe {

enum class ResultError { none, wrongCount, nonfinite, outputLimit, callbackCountOverflow, copyFailed };

// One serial producer only. Copies borrowed samples during callback execution.
// Errors are sticky; accepted prefixes remain available for diagnostics only.
class ResultCollector {
public:
    ResultCollector(std::size_t expectedSamplesPerCallback, std::size_t maxSamples)
        : expected_(expectedSamplesPerCallback), maximum_(maxSamples) {
        if (expected_ == 0) throw std::invalid_argument("expected sample count must be positive");
        samples_.reserve(maximum_);
    }

    void accept(const NCResultValue& value) noexcept {
        if (callbacks_ == std::numeric_limits<std::uint64_t>::max()) {
            if (error_ == ResultError::none) error_ = ResultError::callbackCountOverflow;
            return;
        }
        ++callbacks_;
        if (error_ != ResultError::none) return;
        if (value.samples.size() != expected_) { error_ = ResultError::wrongCount; return; }
        if (value.samples.size() > maximum_ - samples_.size()) {
            error_ = ResultError::outputLimit; return;
        }
        for (float sample : value.samples) {
            if (!std::isfinite(sample)) { error_ = ResultError::nonfinite; return; }
        }
        try {
            samples_.insert(samples_.end(), value.samples.begin(), value.samples.end());
        } catch (...) {
            error_ = ResultError::copyFailed;
        }
    }

    std::uint64_t callbackCount() const noexcept { return callbacks_; }
    ResultError error() const noexcept { return error_; }
    const std::vector<float>& samples() const noexcept { return samples_; }

private:
    const std::size_t expected_;
    const std::size_t maximum_;
    std::uint64_t callbacks_ = 0;
    ResultError error_ = ResultError::none;
    std::vector<float> samples_;
};

} // namespace native_model_probe
