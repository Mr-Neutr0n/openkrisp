# Native echo cancellation contract

The installed addon has a distinct local AEC path. `AECMonitor` supplies the reverse reference stream. `AECProcessor` processes the forward stream in place. Both use a string `aecSDKId` to obtain the same stateful AEC object. The selected float path uses interleaved Float32 and 10 ms processing blocks. This contract is separate from the NC model factory.

A smaller direct factory exists in `libaec-sdk.dylib`. It constructs and initializes a WebRTC-backed object without a model path or callback argument. This supports designing an isolated synthetic duplex probe. It does not establish successful AEC processing, echo removal, supported rate combinations, original graph timing or a callable adapter yet.

All new original-file reads used lab `bin/rea capture-process` with read-only hash/LLVM inspection helpers. No original library was loaded, no factory was called, and no audio, administrator, cloud or network operation ran.

## Exact identities

The addon remains SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`, at the reviewed `kr-media-sp/build/Release/kr-media-sp.node` path. Every successful addon capture records matching before/after hashes.

AEC identity capture `ev_90bc2c6dc71532c5708e4a6513ea3495429d8063dc2f9d88deab96700430922e` distinguishes the universal container from its slices:

| Image | Bytes / container offset | SHA256 |
| --- | --- | --- |
| Full `libaec-sdk.dylib` | 1,411,408 bytes | `bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a` |
| ARM64 slice | 657,744 bytes / 753,664 | `55bc1f7cc2e32dbe00cae2cf2deb06765a8d007b77c819a7b16aa6116763d349` |
| x86_64 slice | 733,680 bytes / 16,384 | `78d7e4e035c97276fa877d11dbd26b65c292ebfa4c5a373529adeead179ed046` |

The library is at `Contents/Frameworks/Electron Framework.framework/Versions/A/Libraries/libaec-sdk.dylib` inside the installed Krisp bundle. Its ARM64 declared dependencies are CoreFoundation, libc++ and libSystem, plus its own install name. This is a declared load boundary, not a complete runtime dependency trace.

Historical inventory `evidence/native/aec-macho.json` has subject digest `d1710d9c1f9162bb2db5947aa58b376df82941e593ae06f6652a92ebbccbabd9`. That value matches neither the current full container nor either current slice. The first new helper stopped on this mismatch before disassembly. It is retained as `aec-library-20261018-v1`, Evidence `ev_05184fa6d2e3a58a8d09867c6d954ded8ef621a734043f9bb844613725ae53f2`, exit 1. A fresh capture then bound the current full digest and resolved current symbols and virtual tables directly. No timestamp evidence establishes when or why the historical identity differed.

All addresses below are unslid ARM64 analysis addresses. Addon addresses and AEC-library addresses belong to different images and must not be mixed.

## Evidence

Files are under `evidence/model-probes/`, with each stem followed by `.scenario.json`, `.result.json` and derived `.result.txt`.

| Stem | Evidence ID | Scope |
| --- | --- | --- |
| `aec-factory-20261018-v1` | `ev_1d726deb5968cb257a13c64b5acc0f5d615afd4c8bbc6b9482c38fad00cbaec9` | Shared addon factory and SDK constructor |
| `aec-specs-20261018-v1` | `ev_3948d4fcb8f79850daade604750afc05fa74295a00b787668b6e6f7afe6ea541` | Forward/reverse spec admission and native object creation |
| `aec-frame-wrappers-20261018-v1` | `ev_44c803503f174f13f195c89e2a304dedfb3da49d5974cace06a39920c5c85961` | Float forward and reverse calls |
| `aec-control-start-20261018-v1` | `ev_1193bc162371842800b2da2f41d4dacd85b21d6497d2a7d7e13b041e77cce204` | Monitor/processor start and settings |
| `aec-frame-process-20261018-v1` | `ev_ccb5f73ed927444d486c00b8bd3f4ded73c10311f17ccaeb31a49dda7d922e21` | Settings changes, 10 ms slicing and in-place processing |
| `aec-addon-values-20261018-v1` | `ev_0a448a8b286651622328535483067d3d3aed33f25a095db813644e4dda5661af` | Concrete addon virtual tables and delay-setting literal |
| `aec-library-20261018-v2` | `ev_4a1fd1ee6ecd06276ae7d39964ddb72016544cf93a283ca84ffabe37d9c6a9fc` | Current AEC virtual table, float channel conversion and default creation |
| `aec-image-identity-20261018-v1` | `ev_90bc2c6dc71532c5708e4a6513ea3495429d8063dc2f9d88deab96700430922e` | Full/slice hashes and ARM64 declared dependencies |
| `aec-library-lifecycle-20261018-v1` | `ev_0f391dc80f1bb62a25d7262e199755ae5ae480fefc7016211d6a119335e5b5bf` | Factory initialization, config, destruction and controls |

These nine captures exited 0 with complete raw terminal records, verified owned-process-group cleanup and removed temporary roots. Start/frame-process captures truncate rendered terminal snapshots only. The library capture separately lists a platform process with withheld environment metadata. That is not an exhaustive process trace. Derived text files are reading aids, not separate Evidence.

## Shared state and controls in the addon

`AECSDKFactory::GetSDKInstance(string const&)` starts at `0xfa7e0`. Under a mutex, it looks up a string key, creates a shared `AECSDK` when absent, and maintains a separate reference count. `ReleaseSDKInstance` at `0xfaaf8` decrements that count and removes the map entry at zero. A monitor and processor must use the same key to share reference history. Merely creating two unrelated AEC objects would not reproduce this path.

`AECMonitor::Start` at `0xf62e8` and `AECProcessor::Start` at `0xf787c` read `aecSDKId`, with an empty-string extraction fallback. Both obtain an instance through factory virtual slot `+0x10`. Monitor calls SDK `SetReverseStreamSpec`; processor calls `SetStreamSpec`. The SDK virtual table at `0x1106a30`, address point `0x1106a40`, binds these slots:

| Slot from address point | Method | Addon address |
| --- | --- | --- |
| `+0x10` | SetStreamSpec | `0xf8d94` |
| `+0x18` | SetReverseStreamSpec | `0xf90b4` |
| `+0x28` | AnalyzeReverseStream(Float32) | `0xf95d4` |
| `+0x38` | ProcessStream(Float32) | `0xf9b38` |

`SetStreamSpec` retains the forward frame specification at SDK `+0x60`; `SetReverseStreamSpec` retains the reverse specification at `+0x78`. Both serialize changes with SDK mutex `+0x20`. Once both specifications exist, either setter calls `krips_aec::AEC::create()`, replacing the owned native engine at `+0x88/+0x90`. If either specification is missing, the engine owner is cleared. This is persistent paired state, not a standalone NC frame transform.

The forward processor also reads `processingDelayMs` with float fallback zero. For ordinary nonnegative values, it converts to an unsigned count and resets values above 20000 to zero at `0xf7b88..0xf7b98`. The SDK stores `floor(processingDelayMs / 10)` at `+0x70`. Forward processing decrements that warmup count and can process scratch storage without publishing it to the caller. This is not evidence that the setting calls WebRTC `set_stream_delay_ms` or establishes reference-to-microphone timing. The lower-level delay method exists separately.

Both frame wrappers poll `GetChangedSettings`. A changed SDK ID releases/replaces the shared instance and reapplies its specification; a changed forward processing delay also reapplies the forward spec. Such updates can replace AEC state. They must not be treated as harmless per-frame scalar writes.

## Input and reference shape

Both wrappers derive a processing block from the caller's frame spec. For format 1, the start path selects divisor 25 and computes `rate * channels / 25` bytes. At 48 kHz this is 1920 bytes for mono or 3840 bytes for stereo: 480 Float32 samples per channel, or 10 ms. Format 0 has a separate signed-int16 path; format 2 has an explicit unknown-format rejection. This report proposes only the observed Float32 path.

At `0xf6c78..0xf6c9c` and `0xf82d4..0xf82f8`, processing asserts that the outer duration is at least 10 and is divisible by 10. The wrappers iterate `duration / 10` blocks and assert sufficient input bytes for every block. These are native assertions, not safe malformed-input errors for an external caller.

Monitor passes each reference block to Float32 `AnalyzeReverseStream`. It returns the incoming buffer view unchanged after analysis. Processor passes each forward block to Float32 `ProcessStream`, using the same block pointer for input and output at `0xf8390..0xf83a4`. Inactive/no-instance branches can return success-like values without AEC processing. A zero return or unchanged output alone cannot establish activation.

For the lower-level calls, the addon constructs a `krips_aec::stream_config` with this observed ARM64 layout:

| Offset | Observed field |
| --- | --- |
| `0x00` | signed 32-bit sample rate |
| `0x08` | 64-bit channel count |
| `0x10` | 64-bit frames per channel, calculated as rate / 100 |

The forward call passes the same stream configuration as input and output. The reverse call uses its own specification. No equality check between the forward and reverse rates or channel counts appears in these selected wrappers. The current packaged graph evidence separately identifies a 32 kHz mono microphone frame spec and a 48 kHz stereo speaker frame spec, with effective runtime overrides unresolved. A future duplex design must carry separate forward/reverse specifications. Reusing the NC worker's single 48 kHz/480 contract would not establish original pipeline parity. See `original-speaker-graph-findings.md` for that separate boundary.

## Smaller direct AEC boundary

The current AEC virtual table begins at library `0x60260`, address point `0x60270`. It binds the addon's selected calls to interleaved Float32 overloads:

| Slot | Method | Library address |
| --- | --- | --- |
| `+0x10` | initialize | `0x3e04` |
| `+0x18` | apply_config | `0x3e0c` |
| `+0x20` | set_output_will_be_muted | `0x3ff4` |
| `+0x40` | process_stream(float const*, configs, float*) | `0x41b0` |
| `+0x58` | analyze_reverse_stream(float const*, config) | `0x40e4` |
| `+0x60` | set_stream_delay_ms | `0x3ffc` |

`krips_aec::AEC::create()` at `0x3b48`, exported as `__ZN9krips_aec3AEC6createEv`, builds two config bytes `{1,0}` and calls `create(Config const&)` at `0x3b70`. That method allocates `0x518` bytes, constructs `Aec_WebRTC`, calls virtual initialize, throws `std::logic_error("can not initialize")` on nonzero initialization status, applies the config and returns its object pointer. The addon wraps that pointer in its own shared owner. No NC registry, model path or callback argument occurs in this selected factory route.

The constructor at `0x3d14` constructs a `webrtc::AudioProcessingImpl` subobject at offset 8. `apply_config` maps the two input bytes into WebRTC configuration and calls `ApplyConfig`. Their full source-level names are not established here; callers should not invent a larger config object. The deleting destructor at `0x3dd4` destroys the WebRTC subobject then calls the image's matching operator delete. A future owner must destroy the object before unloading its library, and contain C++ exceptions before unloading code used by those exceptions.

Float `process_stream` at `0x41b0` allocates channel buffers, copies interleaved input into planar storage, invokes the planar overload, and reinterleaves successful output. Reverse analysis at `0x40e4` also deinterleaves before its planar call. The copy loops contain no observed sample scaling. Full accepted sample range, clipping and invalid-value behavior remain unverified. Both calls return an integer status; the addon treats nonzero as an error.

This path allocates and the addon adds mutexes and logging. It must not run inside the CoreAudio callback. The direct library boundary is a candidate for an isolated owned worker, not evidence that the present NC worker protocol already supports AEC.

## Strongest next step and limits

First build a separate foreign-ABI fixture for the no-argument raw factory, exact stream-config layout, selected virtual slots, synchronous interleaved input/output and matching virtual deletion. Review initialization failure and exception lifetime. This avoids reconstructing the addon's graph, settings maps and shared registry solely to reach AEC.

A later authorized synthetic duplex probe can then use the exact installed library in a bounded isolated process. It must pin the current full AEC library digest explicitly, alongside its host/adapter and any addon it loads. Existing NC admission does not pin every transitive dependency and must not be presented as AEC admission. Start with declared separate 10 ms forward/reference frames, validate all sizes and finite values before native entry, serialize both directions, require every status, compare controlled echo/reference-on and reference-off signals, and confirm destruction before publication. Reference-first order would be a stated test policy until original scheduling is recovered.

The remaining gates are actual supported rate/channel combinations, sample scaling and finite-value behavior, reference timing/delay, model-independent initialization behavior, warmup semantics, mute behavior, reset/EOF/drain, thread safety, long-run deadlines and echo quality. The direct API's delay/mute exports do not show that the desktop uses them. No current runtime AEC result exists. No production code or existing NC admission changed in this investigation.
