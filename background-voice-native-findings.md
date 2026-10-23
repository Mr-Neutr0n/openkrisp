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
