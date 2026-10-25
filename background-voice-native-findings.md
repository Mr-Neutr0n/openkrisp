# Background voice native contract

The current desktop requests BVC by selecting a model through its shared NC processor descriptor. Static native evidence supports a shared NC wrapper, not a separate BVC public frame ABI. It does not prove that either HVC model can run through the independent ordinary adapter. Keep its existing model admission unchanged until a separate HVC contract and bounded processing gate pass.

No original JavaScript, addon, model or application was executed. Original reads occurred only through REA captures of own static archive readers and Xcode LLVM tools. No disassembler target was opened, and no physical audio or administrator operation ran.

## Evidence and identities

| Evidence | Observation |
| --- | --- |
| `ev_a1fa9c2e6fd2779b99a70e03b58261d4f4ca70bf26d0e9d2cde7f052e4d623a6` | Current outbound catalog decoded from literal JavaScript strings. Raw output is complete; the rendered history is truncated. |
| `ev_be36529423ed582e869c5228044603a589ff84167270d0169ee5bfb070fc157d` | Focused ProcessorManager and AudioService model-selection projection. Complete raw output. |
| `ev_391c67ddc4edb50b8106f42c98006931e40bbda7a269b5ce1a71ab352b792155` | Bounded native symbol inventory, including RTExclusiveNC, AR BVC and BackgroundSpeakerFix names. |
| `ev_452c9179b564f2bdfd1a12a765bf5873cccbb1fbd2f5899e56b0c6742369215c` | Exact disassembly of GetConfigIfChanged, CreateNCStream and ordinary KMS CreateNCProcessor. All 101223 raw bytes retained. |

These captures exit zero and report verified owned-process cleanup. The archive reader records matching before/after archive SHA256 `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`. Native captures record matching addon SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. Their selected modules and addresses belong to that 3.17.9 investigation, not an arbitrary later installation. The string decoder parses literal tables and substitutes selected aliases; it does not evaluate original modules. Unresolved aliases remain unknown.

An exploratory larger archive capture, `ev_414ced988253990fbe6bf4f8c6274e88ab59aa533f34671147088cdc51cacc2d`, lost its final raw footer to the output bound. It is not used for unchanged-artifact acceptance.

## Model selection

The outbound catalog declares these type-1 entries:

| Name | File | Declared source rates | Work rate | Performance/default |
| --- | --- | --- | --- | --- |
| `hvc-outbound-lfb` | `hs.c6.f.m.75df8f.berlin.kef` | 8001..192000 Hz | 32000 Hz | 75 / true |
| `hvc-outbound-sfb` | `hs.c6.f.s.de56df.bucharest.kef` | 8001..192000 Hz | 32000 Hz | 15 / false |

Both declare `optimized: false`. These are configuration values, not tested rates or quality rankings. Own catalog expectations retain prior hashes `54e2913ea45734adc3323407e43f55b14afade256ab4da6226c2b6e30604cbf4` and `b9e29fb9b45b4069460bb1d664bf4112268f03e516ce6a98e09f86a7a0f4a7c3`, respectively. This investigation did not reread either model or authenticate those hashes anew.

AudioService passes the requested BVC model type, outbound base models, device rate, processing mode and optimized/performance-selection options to ProcessorManager. The manager selects a model name and writes it to `ncProcessor.params.ncModel`; it still constructs `NCProcessor`, whose descriptor uses native `ProcessorType.NC`. Selection can use compatibility and fallback rules. Requesting BVC alone therefore does not prove a particular HVC file was selected. See `background-voice-controls-findings.md` for the separate headset/manual-selection contract.

## Shared native wrapper

`NoiseCanceller::GetConfigIfChanged` at `0xfbc84` reads `ncModel`, `rdThreshold`, `rdModel`, `energyModel` and `noiseSuppressionLevel`. The selected extraction does not read a BVC model-type field or a BVC-only supplier switch.

`CreateNCStream` at `0xfcfb0` resolves the selected model name through the SDK. Its ordinary versus RTExclusiveNC branch depends on RD threshold/path configuration. It does not branch on the JavaScript BVC type integer. The ordinary branch reaches KMS vtable slot `+0x10`; the RD branch reaches `+0x18`, with a different supplier and extra threshold/RD-path arguments. Existing native configuration findings bind those slots to `0xc7720` and `0xc89ac`. Do not equate RTExclusiveNC with BVC merely because both can appear in the same wrapper.

At ordinary KMS construction `0xc7944..0xc797c`, the code writes sampling rate, copies the selected wide model path, clears blob pointer/length and clears the byte at configuration offset 48. It then calls the existing `NoiseCancellation::Configuration`, `PerFrameConfigurationSupplier`, `ResultHandlerWithStats<float>` specialization. This matches the independent 56-byte configuration carrier, including its zero `unknownFlag`. No new BVC-specific external carrier is established in this branch.

The descriptor-to-native processor-construction mapping remains unresolved. The JavaScript NC descriptor and this native NoiseCanceller path are not yet one fully traced original control-flow chain. Effective BVC graph RD/energy settings also need to be bound at that join. No conditioning or enrollment argument appears in the selected native bodies; this bounded observation does not prove its absence elsewhere.

The symbol inventory also contains AR `initBvcProcessor` and DSP `BackgroundSpeakerFix`. Their names do not bind them to this desktop selection. The ordinary per-frame producer previously returned flags `0,0,0,1`, so the third BackgroundSpeakerFix flag must not be enabled as a guessed BVC implementation. See `native-supplier-value-findings.md`.

## Implementation prerequisite

Before claiming the original BVC path, bind the NC descriptor to native NoiseCanceller construction and its effective BVC settings. For an independent candidate-only probe, a separate HVC model role and explicit identity-bearing admission path is the next small implementation step. Keep the ordinary role/hash/backend contract intact. First test selection, model identity, shared configuration/supplier/result carriers and teardown using an own foreign-ABI fixture. Then seek a separately authorized bounded REA CPU probe of the exact admitted HVC model with fresh engines, finite frames and clean teardown. The shared wrapper makes ordinary frame-ABI reuse plausible; it does not establish model loadability, internal backend selection, required RD/energy settings, operating rates or voice isolation.

Do not expose a working BVC toggle from catalog presence alone. Nearby-voice rejection, primary-speaker preservation, headset behavior, latency and tails remain unmeasured. Original automatic selection and a future independent manual policy must remain distinct.

## Construction join and microphone defaults, 2026-10-25

This pass closes the specific NC enum to NoiseCanceller construction join. It supersedes the unresolved construction statement above. It does not claim a live graph or complete product parity. Original inspection used target-free REA captures of own archive readers and Xcode static tools. No native analysis target was selected. No original code executed.

| Evidence | Retained file under `evidence/model-probes/` | Scope and retention |
| --- | --- | --- |
| `ev_f60e52ac70918693325a2ae2e4508bd75c5b1c1e2a4aade5b38f5ff65df2bfd9` | `bvc-dispatch-symbols-20261025.result.json` | Focused symbol inventory. All 14,166 raw bytes retained. Rendered output truncated. |
| `ev_baa4af283367bba30cbe58c37474d1eb54282bd8034da0f538141fe9214fa88c` | `bvc-dispatch-exact-20261025.result.json` | Exact factory, NoiseCanceller allocation helper and C2 disassembly. All 27,907 raw bytes retained. Rendered output truncated. |
| `ev_6bbf782b4100180664a50853b4c70a77e587d22a34fff0a18df9c0eb150557d5` | `bvc-switch-bytes-20261025.result.json` | Two bounded Mach-O switch-table reads. All 1,476 raw bytes retained. Rendered output truncated. |
| `ev_b38f113fcb47bc7b9fe6689706535e3568ac6c9e358ed958f32939de4112a5bc` | `bvc-ctor-c1-20261025.result.json` | Exact C1 constructor. All 3,450 raw bytes retained. Rendered output complete. |
| `ev_b7964535412268a2412bea243aa8abe9f8f8af9354b6f0e637b22e88d411e057` | `bvc-nc-enum-20261025.result.json` | Literal NC enum definitions. All 11,184 raw bytes retained. Rendered output truncated. |
| `ev_7598632c8be8f38508c1b4fbf03da7387c76b3e667bd5b2d4203b0df35f7267c` | `bvc-mic-default-focused-20261025.result.json` | Exact Sentry module range 108349..111348 containing microphone AT defaults. All 9,662 raw bytes retained. Rendered output truncated. |

All listed native captures retain matching before/after addon SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. Both listed archive captures retain matching before/after archive SHA256 `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`. The literal enum capture binds Sentry module SHA256 `cf21e7e4fa19deb6f960223a883fe8831f25d66ba68d15e127731de5aead8579`. This remains the 3.17.9 artifact. Each scenario and own reader is retained beside its result. REA reports exit zero, verified owned-process-group cleanup and removed temporary roots. Some captures separately list platform processes whose environments the OS withheld. That is sampled process visibility, not an incomplete owned-group cleanup claim.

An earlier broad `AT=` query, `ev_56863d4bf5c4fb6368bf35daad401a9def860da402711c0297391e5cf39b40b7`, observed 43,421 raw bytes and retained only 34,883. It is not accepted as a complete raw capture. The focused range above replaces it for microphone defaults. Its retained decoded NCProcessor body agrees with prior complete `ev_f5ab7c72b42ff4a4d14cb47d3bf91893363610cf6acf2c89937c3802d073a6cf`.

### Observed construction

The Sentry JavaScript ProcessorType enum declares `NC=0`. Its ModelType enum also declares NC=0 and BVC=1, but those are separate enums. NCProcessor passes ProcessorType.NC to BaseProcessor. BVC model selection changes `params.ncModel`, not this processor type.

At `ProcessorFactory::CreateProcessor`, `0xe3c54` reads the 16-bit type at ProcessorSpec offset `0x18`. Instructions `0xe3c60..0xe3c74` select a byte from virtual address `0xe8eee8` and branch to `0xe3c78 + byte*4`. The table at file offset 15,265,512 has first byte 117. Thus type zero reaches `0xe3e4c`. That branch forwards the spec ID, suspended byte at `+0x1a`, settings at `+0x20`, frame spec and factory SDK reference. At `0xe3e94` it calls `allocate_shared<NoiseCanceller>` at `0xe4ed0`. That helper calls `NoiseCancellerC1` at `0xfb380` through `0xe4f60`. C1 puts zero in `w2` at `0xfb3a4` before the base Processor constructor. The separate native enum printer table at `0xe8ee64` sends index zero to the literal `NC` branch at `0xe1ac8`. These reads establish the construction join independently of symbol-name similarity.

This is static control flow. This pass does not re-audit every N-API descriptor conversion or exercise graph construction. It closes the factory dispatch gap and combines it with the retained JavaScript descriptor evidence.

### Observed defaults and inferred effective BVC configuration

The packaged microphone processor object `AT` has an NC entry at index 10 with:

```json
{"ncModel":"","rdThreshold":0,"rdModel":"","energyModel":"nc-outbound-sfb","noiseSuppressionLevel":100}
```

A feature-preset expression controls whether that entry exists. Its obfuscated preset key remains unresolved here. Do not apply the speaker's `rdThreshold: 0.96` and configured RD model to this microphone entry.

Complete retained AudioService evidence `ev_6633cc56846dc24c1803403ef109b67197a17228f64422f75143e8dd616f85b1` shows `getGraphSettings` choosing BVC for a compatible microphone and cloning `audioConfig.configs.microphone.processors`. The method does not overwrite RD or energy parameters before ProcessorManager construction. Complete retained ProcessorManager evidence `ev_f5ab7c72b42ff4a4d14cb47d3bf91893363610cf6acf2c89937c3802d073a6cf` shows model selection replacing `ncModel`, and replacing suppression with the current microphone reduction level. RD resolution runs only for a truthy RD name. Energy resolution runs for a truthy energy name, searches outbound base models using ModelType.NC, and can fall back to a default or first NC model. If no such model exists, it clears the energy name.

Inference for the unmodified packaged microphone configuration: BVC reaches NoiseCanceller with RD threshold zero and RD model empty. Its energy request is `nc-outbound-sfb`, subject to catalog resolution. This supports the ordinary NC construction branch already recorded in `ev_452c9179b564f2bdfd1a12a765bf5873cccbb1fbd2f5899e56b0c6742369215c`. The effective suppression comes from current microphone settings, so 100 is a packaged initial value, not a fixed BVC runtime value.

Unknowns remain. Account/config overrides can replace the microphone processor object. This pass did not load those overrides or prove one live catalog's exact energy fallback result. It did not trace the energy model's downstream DSP purpose or prove that a candidate HVC engine needs the energy stream. The independent HVC candidate probe establishes its own ordinary-ABI loadability only, as recorded separately. Nearby-voice quality, primary-speaker preservation and headset behavior remain unmeasured.

### Energy stream affects the alternate stats path

Follow-up exact captures bind the energy result consumers. `ev_54e65aea84f83eb3bf18ae040b90216e0dc3edb5a22919e934929a7e2cd8203b`, `bvc-energy-consumers-20261025.result.json`, contains CreateEnergyStream at `0xfd888` and both result handlers. All 24,678 raw bytes are retained; rendered output is truncated. `ev_e7e57aa461cb151a4f59ced09cebff5763ab27fc2f30fca6a6bf298026f68eb7`, `bvc-energy-stats-20261025.result.json`, contains CollectStreamStats at `0xfcab4`. All 11,618 raw bytes are retained; rendered output is complete. Both retain matching addon SHA256 before/after, exit zero, verified owned-group cleanup and removed temporary roots. The first lists one platform process with withheld environment metadata.

The existing complete raw frame caller capture `ev_f48650f627057b3eea987b64240b2d384d03bf63a03ec3bcd9bbcca40499e412`, `native-frame-caller-disassembly.result.json`, contains NoiseCanceller::ProcessFrameBuffer at `0xfc400`. It keeps the input pointer/extent pair in x22/x23 at `0xfc658`. If CanProcessFrame succeeds and the NC stream at object `+0x1f0` exists, it processes through that NC stream at `0xfc688`. It reads the NC result vector at `+0x238/+0x240` and returns that sample pointer on success. This branch does not process the separate energy stream.

The alternate branch at `0xfc700` processes the energy stream at object `+0x200`, then calls CollectStreamStats with its first Boolean false. It leaves the returned pointer/extent pair as the original input. Thus the selected wrapper does not use energy-model output as its bypass waveform.

CreateEnergyStream stores its own stream at `+0x200/+0x208`. Its ordinary NC result handler at `0xff5e4` copies the energy result prefix to object `+0x250` and its sample vector to `+0x278`. The input-frame-energy handler at `0xff6e8` writes the supplied byte to `+0x250` and `+0x251`. CollectStreamStats selects object `+0x210` for the active NC result or `+0x250` for the energy result at `0xfcb00..0xfcb10`. It copies the selected result vector into temporary storage for reporting, sums stats from `+0x218` and `+0x258`, and invokes the stored reporting callback through the async path. These selected bodies contain no energy-result transfer into the active NC result vector or per-frame NC supplier.

Inference within these complete bodies: the energy stream supports stats when active NC processing is bypassed or unavailable. It is not an extra serial DSP stage for the active NC/HVC waveform. Omitting it from the independent candidate does not by itself establish a waveform discrepancy on that active path. It does leave bypass stats, callbacks, model-loading failures and stream lifecycle behavior outside parity. This does not prove that every downstream consumer of reported stats is diagnostic only, or that stats never influence later UI or selection policy elsewhere.
