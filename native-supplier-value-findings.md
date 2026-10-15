# Ordinary NC per-frame supplier value

Static consumers establish an eight-byte value: four independently consumed one-byte logical flags, followed by one Float32 suppression level. The ordinary arm64 supplier returns these eight bytes in `x0`. This is sufficient for an ABI-equivalent value carrier with canonical zero/one flags; it does not recover the original field names or the supplier object's complete C++ class declaration.

No addon was loaded or initialized, and no model, frame, audio device or administrator operation ran.

## Identity and evidence

Target: `/Users/harikp/Applications/krisp.app/Contents/Resources/app.asar.unpacked/.vite/build/node_modules/kr-media-sp/build/Release/kr-media-sp.node`.

Both new static REA captures recorded SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755` before and after inspection, and exited zero. They ran the existing exact-symbol disassembly helper and LLVM tools only.

| Evidence | Scope |
| --- | --- |
| `ev_f662e1365be4b192dfacaef94e4a1fe90aa8fee30ceee69b9908980fdb324cd3` | `MainCleaner::cleanNoise` and `DfProcessor::process` consumers |
| `ev_cb31e375f551e009bf5174cdc1a90b0d49c5fa42a53d8b1ea6ea5fe876a3b6c5` | `MainCleaner::preProcess`, `infer`, and `postProcess` field consumers |
| `ev_1038c9b008c82aa2a695355c281073d091df676b98d03f584bd75c88bc17740f` | Retained ordinary supplier lambda at `0xfed78`, same addon digest |
| `ev_47b50132986bf7e01ccbd338eb87744d860460c106f7123fae36ac66ecb592f2` | Retained concrete float NC outer process and whole-value copy, same addon digest |

New scenarios/captures are `evidence/model-probes/supplier-value-{consumers,cleaner-fields}.scenario.json` and `.result.json`; derived `.result.txt` files concatenate retained raw frames. The two new captures retain all 65,245 and 77,771 observed raw bytes respectively. Rendered terminal budget omissions are separate from raw method retention. Hashes are before/after samples, not atomic OS image bindings. Inspection did not observe original app execution or network activity.

## Concrete byte layout

The outer float processor calls the supplier object's first virtual method at `0x1db2f4`, then stores its returned `x0` as eight bytes at `x29-0x78` (`0x1db2f8`). On the MainCleaner branch it reconstructs the low four bytes and copies the whole eight-byte value to cleaner offset `0x288` at `0x1db590`. Thus cleaner offsets `0x288..0x28f` correspond to value offsets `0..7`.

| Value offset | Access and type established by consumers | Observed function, provisional description |
| --- | --- | --- |
| `0` | One-byte zero/nonzero logical value; also passed as a C++ `bool` argument | Bypass filtered spectrum: nonzero selects inverse FFT of the original spectrum instead of retaining the filtered inverse FFT (`0x1d3b94..0x1d3ba8`). DfProcessor passes it to `DfPostprocessor::process(..., bool, float, bool)` (`0x1cb0ec..0x1cb108`). |
| `1` | One-byte zero/nonzero logical value; also passed as a C++ `bool` argument | Skip statistics path: nonzero skips energy/statistics resets and aggregation in cleaner and Df consumers, and skips outer stats population. This does not skip all inference (`0x1d1db0`, `0x1d1ff8`, `0x1d21a0`, `0x1caf24`, `0x1db5fc`). |
| `2` | One-byte zero/nonzero logical value | Enable `BackgroundSpeakerFix::frameCompute` on the cleaner output (`0x1d3bac..0x1d3bbc`). No corresponding use was established in the Df path. |
| `3` | One-byte logical value passed to the mangled C++ `NvStatsCalculator::updateStats(bool)` | Statistics update mode/flag at `0x1d2204..0x1d2208`. The exact meaning of true versus false inside `updateStats` is not recovered here. |
| `4` | IEEE Float32: scalar `ldr s`, floating arithmetic | Suppression level expressed on a 100-based scale. Cleaner postprocessing computes `alpha = level/100` and `1-alpha`, then transforms each gain to `alpha*gain + (1-alpha)` below the full-strength threshold (`0x1d3aa8..0x1d3b68`). DfProcessor loads `s0` at value offset 4 and passes a float argument to its postprocessor. |

All four initial bytes are meaningful; they are not unobserved alignment padding. Conditional loads alone do not prove the original source fields were spelled `bool` rather than another one-byte integral type. The typed downstream `bool` calls and canonical producer values support their logical use. Use only canonical zero/one representations in a prospective wrapper. Original identifier spelling is unknown; the descriptions above must not be treated as recovered SDK header names.

A concrete neutral carrier consistent with the observed memory and return ABI is:

```cpp
struct OrdinaryNcPerFrameValueCarrier {
    std::uint8_t bypassFilteredSpectrum;   // offset 0, zero or one
    std::uint8_t skipStatistics;           // offset 1, zero or one
    std::uint8_t backgroundSpeakerFix;     // offset 2, zero or one
    std::uint8_t statisticsUpdateFlag;     // offset 3, zero or one
    float suppressionLevel;               // offset 4
};
static_assert(sizeof(float) == 4);
static_assert(sizeof(OrdinaryNcPerFrameValueCarrier) == 8);
static_assert(alignof(OrdinaryNcPerFrameValueCarrier) == 4);
static_assert(offsetof(OrdinaryNcPerFrameValueCarrier, suppressionLevel) == 4);
```

This is an evidence-backed ABI-equivalent carrier, not a claim to have recovered the exact original source declaration. It has no pointer, ownership, vector, timestamp or sample-count field. Four `bool` fields followed by `float` would have the same observed representation on this arm64 ABI when initialized with canonical values, but reconstructing the nested original type and virtual interface still requires careful C++ ABI work. No callable shim was written.

## Return ABI and actual producer

The actual ordinary supplier invocation wrapper at `0xfed78` loads its captured NoiseCanceller pointer from closure offset 8, reads 32 bits from object `+0x1e8`, and returns:

```text
x0 = 0x01000000 | (UInt64(raw32bits) << 32)
```

On this little-endian target, the four flags are `0, 0, 0, 1`, and the upper 32 bits are the Float32 field's bit pattern. The producer does not convert that field to an integer or double. The outer consumer preserves those bits and uses Float32 arithmetic downstream.

The return uses `x0`, not `s0`, a homogeneous floating aggregate, an output pointer in `x8`, or a heap allocation. The outer processor immediately stores all eight returned bytes. By-reference consumers such as `DfProcessor::process` receive a pointer to that stored value. A shim that returned only a float, or used a caller-provided result buffer, would mismatch this observed call site.

The outer processor's null-supplier fallback initializes bytes `0, 1, 0, 0` plus Float32 `100.0` (`0x1db2d8..0x1db2e0` and `0x1db544..0x1db558`). These are the processor's local fallback values, distinct from the actual addon's ordinary supplier values. Null supplier is not evidence that callbacks or initialization can be omitted generally.

## Scope and limits

The float field is proven to be a suppression/blend control, not an output gain or a sample rate. Separate retained settings extraction clamps the app-level `noiseSuppressionLevel` setting to 0 through 100, but the selected native consumers do not establish a universal finite-value/range validator for externally supplied values. A future adapter should use finite 0 through 100 values and should not infer out-of-range behavior from the app clamp. Full-strength handling uses a threshold just below 100 (`0x42c7ffff`); this is not proof of perceptual strength or parity.

The complete meaningful eight-byte layout and its scalar return ABI are now established for the ordinary NC path. Remaining work is the supplier object's virtual method/lifetime contract and the exact configuration/SDK construction ABI. The callback executes a captured-pointer lambda, so keeping an eight-byte return value correct does not by itself make that captured object safe. This report does not establish flag behavior for every model backend, RTExclusiveNC values, thread safety, callback exceptions or runtime processing success.

Only this new report and uniquely named ignored inspection artifacts were added. No app source, shared contract or obligation ledger was changed.
