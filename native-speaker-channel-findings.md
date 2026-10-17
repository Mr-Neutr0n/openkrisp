# Native speaker channel path

Static REA observations on 2026-10-18 bind the reviewed KMS bridge to one mono processor. For a two-channel Float32 stream, the bridge averages the input channels, processes the mono frame, then duplicates the result into two output channels. Two independent mono NC instances would implement a different channel policy.

This is a static data-flow conclusion for the selected bridge. It is not an observation of the original desktop speaker graph or a stereo runtime comparison. No model, addon initialization, hardware audio, device mutation or administrator operation ran during this investigation. All original-file reads used REA process captures of static inspection helpers.

## Identity and evidence

Every successful capture below records unchanged addon SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755` before and after inspection. Addresses apply only to that digest. Capture files are under `evidence/model-probes/`, with the table's stem followed by `-20261018-v1.scenario.json` or `.result.json`. Extracted raw disassembly is retained as `.result.txt`.

| Capture stem | Evidence ID | Selected observation |
| --- | --- | --- |
| `speaker-default-spec-definitions` | `ev_4615dfd9d86356d16df51642343a4055a02d2464f133ab85160c6c6a1ef051e5` | Default internal channel count is one |
| `speaker-channel-adapters` | `ev_a25bdea39e71e204846081f35a3be3a9db80a5d7a80ba808b6e642b17c42d724` | KMS forward and reverse channel chains |
| `speaker-channel-chain` | `ev_564aceadd689f7b9c2db894106d1f6929855796695add9cfe87db27c977ed7b4` | Default miniaudio data-converter configuration |
| `speaker-channel-selection` | `ev_6f39d7ff722b29a6f6f71ee1687a8a81ed5a48f46cb70c442bede3c7ac1f573f` | Channel-only mismatch selects MA::FrameTransformer |
| `speaker-channel-matrix` | `ev_131af537521c87fefb02ba0ff265e40820a64dbde7297145a834c15e111f3f8e` | Transformer passes default configuration to miniaudio |
| `speaker-channel-fastpath` | `ev_ead7698e3910c1c4c8e740b8fa3a306165affd3222f2fb47ef4b32f523768679` | Float32 averaging and duplication operations |
| `speaker-data-converter-bridge` | `ev_40a34fb98f97a053784514644ad4f8b998b53e01af86c7eb569c90c323b559c6` | Format mapping and default channel configuration propagation |

All seven captures exited 0. Their raw terminal records are complete. The first channel-adapters capture truncates rendered terminal snapshots only. REA reports verified owned-process-group cleanup and removed temporary roots. Some captures list unrelated processes with unreadable ownership metadata; REA left them untouched. Process sampling is not exhaustive.

## Internal mono binding

The symbol table binds `DefaultKMSFrameSpecPtr` to `0x11770c8`. Its storage is BSS/common, so reading file bytes at that address cannot establish its runtime value. A bounded streamed static reference scan located its writer in `__GLOBAL__sub_I_Definitions.cpp`; the complete writer was then captured separately.

The writer allocates a shared object at `0x3e3f8..0x3e410`. It sets a one-byte channel field to one at allocation offset `+0x20` (`0x3e414`, `0x3e420`). At `0x3e43c`, it forms the frame-spec pointer as allocation `+0x18`; at `0x3e448`, it stores that pointer into the global. Thus the spec's channel byte at `+0x08` is one. The same writer sets format 1, default rate 16000 and duration 10.

The default rate does not mean every NC call resamples to 16 kHz. KMSStream's constructor reads the caller rate at `0xc73ec` and uses it for both temporary chain specifications (`0xc7438`, `0xc7444`). It compares caller channels with the default mono channel at `0xc7424..0xc742c`. On mismatch it constructs the caller-to-mono chain at `0xc7450..0xc7460`, then the reverse chain at `0xc752c..0xc753c`.

The retained result-handler analysis in `native-nc-callback-construction-findings.md` establishes that the handler captured at KMS member `+0x68` applies the reverse chain before invoking the user's result callback. The input wrapper applies the forward chain before SDK push, as recorded in `native-frame-processing-findings.md`. These are conversions around one SDK stream and processor, not a pair of independent left/right model states.

## Exact channel operations

For equal rates and equal Float32 formats, `FrameProcessingChain::MakeProcessors` reaches its channel comparison at `0x3ecc4..0x3ecd0`. A mismatch calls `MakeFrameTransformer` at `0x3ece0`. That method constructs MA::FrameTransformer. It does not select ToMonoConverter.

The transformer maps SDK format 1 to miniaudio format 5 at `0x9a060..0x9a068`. This is the Float32 branch used by the arithmetic below. It passes input/output channels and rates to `ma_data_converter_config_init`. Its initialization calls `ma_data_converter_init` immediately afterward without installing custom channel maps or weights (`0x506c0..0x506d0`). Data-converter initialization propagates the default maps and mixing fields into the channel converter at `0x75ab4..0x75adc`.

With default maps, output channel count one selects conversion path 2 at `0xa29f8..0xa2a10`, including the null-map branch at `0xa2ae0`. The Float32 processing branch converts the input channel count to float at `0x74020`, sums the interleaved samples, divides by that count at `0x740ec`, and stores one result. For stereo input this is `(L + R) / 2`. It is not an unscaled sum.

With one input channel and two output channels, path 3 is selected at `0xa2a84..0xa2a9c`. Its Float32 branch loads each mono sample and stores it twice at `0x74e7c..0x74e80`. Both output channels therefore carry the same processed sample.

A separate ToMonoConverter sums channels without averaging in its selected two-channel branch. Its existence does not override the MA path above. Reusing that sum would choose the wrong gain for this KMS channel conversion.

## Smallest supported next step

Build the experimental speaker path with one independently owned inbound mono NC session. Convert each interleaved stereo pair to a Float32 average before submitting it, then duplicate the processed mono result into both playback channels. Keep microphone and speaker model state separate. Use the exact inbound model identity and mono runtime evidence in `inbound-model-findings.md`; do not generalize admission to arbitrary installed models.

First test the channel adapter with synthetic left-only, right-only, identical, opposite-phase and distinct stereo inputs. Opposite-phase inputs must cancel before NC. Test callback partitioning, queue delay, silence on worker failure, and control-thread shutdown without hardware. Match the observed Float32 arithmetic order when byte-level parity matters. A later authorized isolated original comparison can test the complete stereo bridge before any live routing claim.

## Limits

The selected bridge's default policy is now established. The original desktop's actual speaker graph construction, input channel selection, settings, optional processing branches and device-format conversions are not established here. The reference scan located the default writer; it is not a proof that no code can ever replace the global spec.

No two-channel original inference ran in this investigation. The inbound model's existing mono runtime checks do not establish complete original-app speaker parity. Active processing collapses the stereo image in this bridge. The earlier NoiseCanceller analysis shows that inactive processing can return the original input view, so disabling NC must not be assumed to require the same collapse. Speech quality, clipping policy outside the selected normalized Float32 path, model latency, complete tail handling and sustained live timing remain unverified.
