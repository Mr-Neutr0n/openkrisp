# Native NC configuration bridge

Static evidence supports a path from a model name and audio-frame specification to an SDK stream and a float NC processor. The selected bridge does not itself open an audio device or construct a media graph. This makes an independent frame-processing path plausible, but does not establish a callable standalone ABI or a working processor.

All addresses below belong to the installed ARM64 addon with SHA-256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. They are unslid static addresses, not runtime pointers. Earlier-build addresses must not be substituted.

## Evidence

| Evidence ID | Retained capture | Scope |
| --- | --- | --- |
| `ev_d4f60074bf8b67dd04f6fb7e1582311674529aea6443c48e031ac53312003922` | `evidence/model-probes/native-nc-configuration-disassembly.result.toon` | Exact-symbol disassembly of CreateNCStream, CreateAudioStreams and IsConfigValid |
| `ev_7f1381461f01accde7a825979eddfff46baa4dc724afec191c41bb5ea5b6b18f` | `evidence/model-probes/native-nc-bridge-symbols.result.json` | Current defined-symbol names and addresses for the NC/KMS bridge |
| `ev_edbfb773ae319ad8c2b488172beb490adc7c5cf5828f592b10e88c9d718dadb9` | `evidence/model-probes/native-nc-bridge-vtables.result.json` | Raw KMSStream and KrispMediaSDK vtable words, mapped to current symbols |
| `ev_1038c9b008c82aa2a695355c281073d091df676b98d03f584bd75c88bc17740f` | `evidence/model-probes/native-nc-stream-config-disassembly.result.json` | SDK CreateStream, GetStreamParamsFromSpec, GetLoadedModelPath and ordinary NC per-frame supplier |
| `ev_94ae630db3fe9e81ac277fbb09db07f0d09c6bc66788f12819bddc6ef4703def` | `evidence/model-probes/file-nc-settings-disassembly.result.json` | Existing retained configuration extraction, same addon digest |

The new captures execute only original local inspection helpers and Xcode LLVM tools through REA capture-process. They do not load the addon or call its functions. Every new helper records matching addon hashes before and after its static reads. Captures exit with code zero. Symbol and stream-config captures mark the rendered terminal history truncated, but their raw terminal byte/frame counts are fully retained, including final identity checks. Derived `.result.txt` files contain concatenated raw frames. The first capture retains the CLI's TOON output rather than relabeling it as JSON.

## Model and configuration selection

`NoiseCanceller::GetConfigIfChanged` starts at `0xfbc84`. It obtains changed ProcessorSettings and reads these names:

| Setting | Observed destination in the NCConfiguration object | Evidence |
| --- | --- | --- |
| `ncModel` | string at `+0x0` | `0xfbce0` through `0xfbd3c` |
| `rdThreshold` | Float32 at `+0x38`, extraction fallback zero | `0xfbe58` through `0xfbe90` |
| `rdModel` | string at `+0x40` | `0xfbea4` through `0xfbf00` |
| `energyModel` | string at `+0x58` | `0xfbf1c` through `0xfbf78` |
| `noiseSuppressionLevel` | Float32 at `+0x70`, extraction fallback 100, clamped to 0 through 100 | `0xfbf94` through `0xfc000` |

These are code-level extraction fallbacks, not verified app factory defaults or proof of the current user's selections. The offsets describe this build only and are not a public structure definition.

`IsConfigValid` at `0xfc1c4` checks the RD threshold against zero and one. For ordinary finite values, a threshold with magnitude below the Float32 constant `0x38d1b717`, approximately 0.0001, passes without requiring an RD model name. At or above that magnitude it also requires a nonempty `rdModel`. This is a specific NC configuration check, not proof that models are loaded or an entire processor is ready.

No exact `CreateNCconfig` or `CreateNCConfig` defined symbol appears in the focused current symbol capture. Configuration construction is therefore described through the observed callers, extraction and supplier. This does not rule out inlined or differently named construction code.

## NC stream and processor bridge

`NoiseCanceller::CreateNCStream` starts at `0xfcfb0`.

1. It closes/releases the previous stream held at the NoiseCanceller object's `+0x1f0/+0x1f8` before creating a replacement.
2. An empty `ncModel` takes the return-zero path at `0xfd160` without constructing an NC processor. A zero result alone therefore cannot establish that NC ran.
3. A nonempty model name goes through the SDK interface virtual slot `+0x28` at `0xfd040`. The captured concrete vtable maps that slot to `KrispMediaSDK::GetLoadedModelPath`, `0xd4c28`.
4. The SDK interface virtual slot `+0x30` at `0xfd074` maps to `KrispMediaSDK::CreateStream`, `0xd2db4`. The arguments include this processor's shared AudioFrameSpec at `+0x110`, and a false Boolean argument. The Boolean's complete semantics are not established here.
5. The returned stream is retained at `+0x1f0/+0x1f8`. The bridge resolves an RD model path when the RD branch calls for it, then selects one of two processor overloads below.

`GetLoadedModelPath` locks a mutex at `0xd4c4c`, searches a model-name keyed internal unordered map at `0xd4c58`, and returns a copied wide-string path. Its not-loaded path logs the model name and produces an empty string. This is a loaded-model registry lookup, not a generic file-path argument or proof that any filename is an accepted model name. The CreateNCStream caller separately rejects an empty resolved NC path, and logs distinct NC-model, RD-model and processor-creation failures.

The captured vtables resolve the indirect calls without guessing their targets:

| Concrete table and address point | Call slot | Target |
| --- | --- | --- |
| KrispMediaSDK table `0x11052a0`, address point `0x11052b0` | `+0x28` | GetLoadedModelPath `0xd4c28` |
| Same | `+0x30` | CreateStream `0xd2db4` |
| KMSStream table `0x1104a28`, address point `0x1104a38` | `+0x10` | ordinary CreateNCProcessor `0xc7720` |
| Same | `+0x18` | RTExclusiveNC CreateNCProcessor `0xc89ac` |

For a threshold near zero, call `0xfd290` uses the ordinary slot. Its arguments include the resolved NC model path, a NoiseCancellation per-frame supplier and a ResultHandlerWithStats<float> callback. For the threshold branch at `0xfd3ac`, call `0xfd3f0` uses the RTExclusiveNC overload with the NC path, threshold in the float argument register, resolved RD path, an RTExclusiveNC supplier and a float NC result callback.

Ordinary supplier `$_0` has invoke method `0xfed78`. It loads its captured NoiseCanceller pointer, reads the 32-bit value at object `+0x1e8`, and returns `(UInt64(value) << 32) | 0x01000000`. The exact returned aggregate's field interpretation is not reconstructed here. This is not a proposed function signature for external use.

The ordinary result callback invoke symbol is `$_1` at `0xfee54`; its function wrapper vtable starts at `0x1106dc8`. The exclusive result callback is `$_3` at `0xff21c`. Callback body/frame layout belongs to the separate frame investigation. Factory construction and ownership belong to the separate factory investigation. This report does not infer their contracts from these addresses.

`CreateAudioStreams` at `0xfc290` calls CreateNCStream first, then CreateEnergyStream only when its first result is zero. Despite its name, this selected body does not demonstrate a CoreAudio device stream. Its error path closes/releases the NC stream. Energy-only behavior remains separate from successful NC processing.

## SDK stream construction and graph dependence

`KrispMediaSDK::CreateStream` at `0xd2db4` takes a shared AudioFrameSpec and Boolean. It rejects an empty frame specification, validates it through GetStreamParamsFromSpec at `0xd2df0`, locks the SDK mutex, and checks the initialized SDK pointer. The successful branch calls `SDK::createStream<float, Audio::StreamDescriptor>` at `0xd2e20`, then allocates a shared KMSStream at `0xd2e48`. That allocation carries the logging callback, shared SDK object, sampling rate, channel byte from the frame specification, SDK stream and Boolean.

`GetStreamParamsFromSpec` at `0xd4d50` requires the sample-format field to equal numeric value 1. It accepts 48,000 as one of its explicit sampling-rate comparisons. It validates the frame-duration scalar using a bounded bit mask. The accepted raw scalar values are 10, 15, 20, 30, 32 and 40. These checks do not establish arbitrary input block support or the units and representation of every external frame field.

Observed scope: the selected construction path calls SDK stream/processor operations, model-registry lookup, allocation, synchronization and logging. It has no selected call to device capture, CoreAudio IO, graph construction or meeting state. Its explicit inputs do not include a graph or hardware device.

Inference: the processing layer appears separable from physical capture and graph scheduling once a valid initialized SDK, models, frame specification, processor, callbacks and ownership rules exist. That supports further work on a dedicated frame adapter. It does not prove that the current addon exports a safe standalone callable interface, that model processing works without hidden SDK initialization.

## Remaining unknowns

- Complete SDK initialization, model registry population and license/redistribution rights are not established by this bridge.
- No model weights were copied, decoded or executed. No model inference or audio output was tested.
- Factory ownership, processor lifetime, callbacks, frame storage and processing return semantics require the companion evidence. Numeric object offsets are not sufficient to call the code safely.
- Thread affinity, timing, reentrancy, allocation behavior, bounded callback guarantees, cancellation and shutdown are not proven by this static path.
- The absence of device/graph calls in these selected functions is bounded evidence, not a whole-program proof that every SDK initialization path is device-free.
- All file identities are before/after read samples. Process capture does not provide an atomic binding of every disassembler read, and it does not observe network activity. Platform tool environment metadata is withheld in sampled child-process records. Owned process groups report verified cleanup and the inspection helpers exited; no original app process was started.

No shared contract, app source, decoder, loader, or inferred native-call shim was changed for this investigation.
