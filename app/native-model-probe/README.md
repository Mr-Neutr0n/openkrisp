# Experimental native model probe support

This component prepares a bounded sample collector for an installed-model processing experiment. It does not load Krisp, create a processor, open an audio device or provide an app model backend. It includes no vendor binary, model or header.

`abi_result.hpp` mirrors the observed ARM64 libc++ result layout: 40 opaque prefix bytes followed by a float vector. The SDK owns each callback payload. The collector copies samples while that payload is live and rejects incorrect frame counts, nonfinite samples and output beyond its configured limit. This avoids retaining SDK-owned sample pointers after callback return. The mirror is specific to the inspected binary, not a portable SDK interface or authority to construct SDK-owned values.

`abi_supplier.hpp` records the separately recovered eight-byte supplier value: four one-byte flags and a Float32 suppression level. It does not register a native supplier or call the SDK.

Run `./verify` on the Mac. It compiles independent fixtures in a temporary directory and checks release and AddressSanitizer/UndefinedBehaviorSanitizer builds. Verification does not invoke original code or establish inference quality.

Evidence and remaining ABI requirements are in `../../native-result-value-findings.md`, `../../native-supplier-value-findings.md` and `../../native-direct-adapter-design.md`. A real processing probe still needs reviewed factory and callback construction, identity checks, network isolation, processor activation and teardown. Native output, latency and tail preservation remain unverified.
