# Ordinary NC result-value layout

Static REA observations, 2026-10-15. No runtime/addon calls, model construction, audio or administration actions occurred. This report concerns the ordinary float stats-bearing result payload only, not the result-handler object's virtual interface.

## Evidence

New Evidence `ev_09d0d4c600e38a28147808f7043ecaf02c0a516eb13c62e2c657967364b86e24` is retained in `evidence/model-probes/result-value-layout-20261015.result.json`, with its scenario alongside it. REA exact-symbol disassembly inspected the stats filler, `NCStreamStats::operator+=`, and `NCStreamStats::ToSPParameters`. Capture exited 0 and pre/post addon SHA256 matched `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`.

Construction/destruction observations below reuse exact ordinary float processor Evidence `ev_6a9010dfcf231d1025f02fc2bd4db5320fdf395fbb31c04cdcdfd3ae673bf3df`; consumer observations reuse callback Evidence `ev_40533b8680448f249894745d350085d236f7adb2807c02890d3d0a29c2dee276` and NoiseCanceller caller Evidence `ev_f48650f627057b3eea987b64240b2d384d03bf63a03ec3bcd9bbcca40499e412`. Each is bound to the same digest. Callback synchrony is covered separately in `native-frame-dispatch-findings.md` and is not re-established here.

## Observed byte layout

The result payload type is `NoiseCancellation::ResultHandlerWithStats<float>::value_type`. In `Processor::process`, its base is `x29-0x70`. The owned vector begins at `x29-0x48`, exactly 40 bytes after that base. The callback at `0xfee54` consumes the same 40-byte prefix and vector offsets. The SDK virtual handler accepts a mutable reference; the KMS user callback accepts a const reference, as recovered in `native-nc-callback-construction-findings.md`. A collector should treat the borrowed payload as read-only.

| Payload offset | Width | Evidence-supported interpretation |
| --- | --- | --- |
| `0x00` | 1 | Byte written by converting NvStats double at source offset 0 to integer, then storing low byte. Meaning/name and signedness unresolved. |
| `0x01` | 1 | Same conversion from source double at offset 8. Meaning/name and signedness unresolved. |
| `0x02` | 2 | No semantic read/write recovered; preserve as padding/unknown bytes. |
| `0x04` | 4 | Classification-like integer: initialized 0; selected to 1 or 2 from comparisons of source double at `+0x10` with -1 and 0.5. Exact enum names unresolved. |
| `0x08` | 4 | Raw 32-bit NvStats source field from `+0x18`. |
| `0x0c` | 4 | UInt32 count from NoiseIntensity map key 0. |
| `0x10` | 4 | UInt32 count from NoiseIntensity map key 1. |
| `0x14` | 4 | UInt32 count from NoiseIntensity map key 2. |
| `0x18` | 4 | UInt32 count from NoiseIntensity map key 3. |
| `0x1c` | 8 | Double-width bits copied from NvStats source `+0x48` using unaligned store. Meaning unresolved. |
| `0x24` | 4 | Raw 32-bit source field from NvStats `+0x50`. |
| `0x28` | 8 | `std::vector<float>` begin pointer. |
| `0x30` | 8 | Vector end pointer. |
| `0x38` | 8 | Vector capacity-end pointer. |

The prefix extent is 40 bytes, vector extent 24 bytes, total observed payload extent 64 bytes. These are byte offsets, not a recovered source header. Do not insert a naturally aligned `double` member at `0x1c`: that would change the layout unless explicit packing were used. The original packed-member/aggregate declaration is unknown.

The filler at `0x1da844` is named with template argument `short` (`Is`) in the retained symbol, but the actual ordinary float processor calls that exact shared helper at `0x1db500` and `0x1db654`. This does not change the selected output vector's float type. It establishes only the prefix writes performed by that helper on this path.

The named `Stats` subobject starts at payload offset 8: NoiseCanceller passes its stored prefix base `this+0x210` plus 8 (`this+0x218`) to `NCStreamStats::operator+=` at `0xfc5c8`. That consumer at `0xe1dc0` reads two 16-byte blocks, hence a 32-byte Stats extent in this use. It performs integer-lane addition; do not infer semantic field names or ordinary aligned C++ field declarations from it. `ToSPParameters` formats the accumulated counters, not the full result-value object. A finite sample collector can ignore the prefix entirely.

## Minimal layout mirror for a read-only callback

For this ARM64 libc++ target, the smallest useful candidate mirror is opaque stats bytes followed by the actual libc++ vector type:

```cpp
#include <cstddef>
#include <cstdint>
#include <type_traits>
#include <vector>

struct NCResultValueMirror {
    std::byte prefix[0x28];
    std::vector<float> samples;
};
static_assert(sizeof(void*) == 8);
static_assert(sizeof(std::vector<float>) == 0x18);
static_assert(alignof(std::vector<float>) == 8);
static_assert(std::is_standard_layout_v<NCResultValueMirror>);
static_assert(offsetof(NCResultValueMirror, samples) == 0x28);
static_assert(sizeof(NCResultValueMirror) == 0x40);
static_assert(alignof(NCResultValueMirror) == 8);
```

This is a target-specific ABI mirror candidate, not an official SDK declaration or a portable interchange format. The observed vector requires natural 8-byte alignment, and the compiler uses aligned stack storage for the aggregate. The disassembly does not independently prove absence of a source-level over-alignment annotation; its exact declared alignment cannot be recovered from these accesses alone. Do not use this mirror to allocate, construct or destroy SDK-owned values. A matching SDK declaration is preferable; the adapter must validate its toolchain layout before relying on this candidate. No compiler/runtime ABI test was run in this task.

For callback consumption, copy `samples` into independent storage while the const reference is live. Do not move, clear, resize or destroy the SDK vector and do not retain its data pointer. Prefix fields can be copied as bytes if needed; unaligned numeric reads require `memcpy`, not a misaligned `double*` cast. Names, enum values, padding and selected source-level packing remain unresolved.

## Ownership and destruction

The processor constructs the payload vector in local storage: zero begin/end/capacity at `0x1db2d0` through `0x1db2d4`, then moves returned vector ownership into it at `0x1db3fc` through `0x1db408` or `0x1db5ec` through `0x1db5f8`. It passes the aggregate by reference to the SDK handler and deletes its vector allocation after callback return at `0x1db6b4` through `0x1db6c0`. Exception-cleanup paths also release the local vector. Thus the payload owns sample storage, while the callback borrows it. The existing NoiseCanceller callback copies its float range into another owned vector, consistent with that lifetime.

The observed prefix contains no owning pointer requiring callback-side cleanup. It is copied as 40 raw bytes by the consumer. This does not establish a general source-level triviality trait or a stable schema across versions. The callback handler object's inheritance/vtable, constructor/destructor, factory ABI and exception contract are separate requirements before a typed file-to-file adapter can be called safely. No prior reports, implementation source or ledger files were edited.
