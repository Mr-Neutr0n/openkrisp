# Original desktop speaker graph

The current desktop JavaScript has a speaker playback graph that starts at the Krisp virtual audio device and ends at the selected physical output device. Its packaged default frame specification is Float32, 48 kHz, two channels, duration 10. The ordinary NC branch selects an inbound model and constructs an NC processor descriptor. This closes the earlier JavaScript graph-wiring gap. It does not establish which branch a running original app uses, or prove a complete original stereo runtime result.

No original application, addon, model, audio route or administrator operation ran for this investigation. New original-file reads occurred only inside REA process captures of a static archive reader. The reader parsed literal strings and replaced selected string-index calls. It did not evaluate original JavaScript, invoke its bootstrap, import its modules or mutate a Ghidra session.

## Identity and retained evidence

The current archive is `/Users/harikp/Applications/krisp.app/Contents/Resources/app.asar`, SHA256 `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`. Each successful archive capture below records the same digest before and after its reads. Its `package.json` reports version 3.17.9. The current Sentry module also embeds `krisp@3.17.9`. This agrees with retained bundle-version evidence `ev_3a54568811b26cf5484325645d4ec772d8a425f658baf6e523ffd035b522b820`.

Historical JavaScript analysis used archive SHA256 `fbd6a39ce6fde8685c6ca4c2ca78343aa50551b1bac74f532fd6c5801a23b622`. The existing `version-change-findings.md` places that analysis in the earlier 3.16.8 investigation. A different current archive digest is therefore not evidence of a further update during this task. No update time or mechanism is inferred.

Current selected modules:

| Module | SHA256 |
| --- | --- |
| `.vite/build/BootstrapApp-3T6N5QeL.js` | `bbaedd07bcd78d093f1011a41e3aeca92707c1f77fc7cca03305ffd4cd90cff0` |
| `.vite/build/SentryManagerMain-DrYTrfPP.js` | `cf21e7e4fa19deb6f960223a883fe8831f25d66ba68d15e127731de5aead8579` |

Captures and derived text are under `evidence/model-probes/`, with the stem below followed by `.scenario.json` and `.result.json`.

| Capture stem | Evidence ID | Selected evidence |
| --- | --- | --- |
| `speaker-graph-asar-seeds-20261018-v1` | `ev_1d12b8556147d4186d750ee2624af3272aba5d208e5e44db8a98e8bf9f2b019d` | Current archive and embedded inbound catalog |
| `speaker-graph-decoded-classes-20261018-v2` | `ev_6633cc56846dc24c1803403ef109b67197a17228f64422f75143e8dd616f85b1` | StreamManager and AudioService callsites |
| `speaker-graph-config-processors-20261018-v1` | `ev_f5ab7c72b42ff4a4d14cb47d3bf91893363610cf6acf2c89937c3802d073a6cf` | ProcessorManager and literal speaker frame defaults |
| `speaker-graph-admission-config-20261018-v1` | `ev_48289fc2d3d251a1c78a3d4bd60e7cbdd8e0a1b72b7a7052596a2b6aa93ff471` | NCProcessor descriptor, speaker processor configuration, package version |
| `speaker-graph-sentry-decoder-20261018-v1` | `ev_e7f448f073b658a14421f39531916cc213d90e87a5fb43d0d5a969bd1cfe77d2` | Sentry module header and speaker processor range |

All five listed captures exited 0 and report verified owned-process-group cleanup with temporary roots removed. They retain complete raw output and final archive hashes. Some result envelopes mark rendered terminal history truncated; their raw terminal observed and retained byte counts match. Claims use the complete raw frames, not the rendered previews. The initial decoded-classes v1 capture exited 1 because a requested class spelling was absent after the first selection succeeded. It is exploratory evidence only; v2 uses corrected seeds and completed. Decoder-shape and symbol-seed captures also remain as supporting records.

The Bootstrap decoder subtracts 168 from a numeric index. Its literal table contains 28,833 entries. The archive reader parses only literal elements through Babel's parser, then reproduces the recorded numeric rotation condition using its own arithmetic. The condition matches after 183 rotations. Selected methods use local aliases of this decoder. Their decoded property names are analyst projections of the captured source, not execution traces. Nested alias calls that the projection does not replace remain visibly unresolved in the retained text. Conclusions below use the resolved outer method bodies and literal configuration values.

## Speaker playback construction

The selected `AudioService` class starts at module character offset 3,949,081. Its `createGraphWithActiveDevice(deviceType, device)` method maps the speaker direction to `StreamType.KRISP_SPK_INBOUND`, obtains `getGraphSettings(deviceType, device)`, then calls `streamManager.createStreamGraph(streamType, settings)`. Failures attempt removal of the partially created stream graph.

`StreamManager` starts at module character offset 3,891,499. Its `createStreamGraph` checks SP initialization and avoids creating an existing graph. It delegates to `createGraphInstance`.

For `KRISP_SPK_INBOUND`, `createGraphInstance` selects:

- frame specification: `audioConfig.configs.speaker.frameSpec`;
- source: empty ID/name, type `KrispAudioDevice`;
- sink: the selected device ID/name, type `SystemAudioDevice`;
- processors: the supplied processor descriptor array.

It passes these to the actual imported addon object's `CreateGraph` method. `StartGraph`, `StopGraph` and `DeleteGraph` are later operations on the returned graph identity. Constructing the descriptor does not itself prove a started stream.

The Sentry module's literal `audio.speaker` configuration has `sampleSpec: {format: 1, rate: 48000, channels: 2}` and `duration: 10`. It refers to speaker processor configuration `hT`. The nearby microphone default is format 1, 32 kHz, one channel. These are packaged defaults. The selected callsite reads the effective configuration object, so later merges or overrides are not ruled out.

A separate `CAPTURE_INBOUND` branch uses process/device loopback and a null sink. `getCaptureGraphSettings` supplies `isNCSuspended: true` and zero suppression. That capture branch must not be treated as the speaker playback NC branch.

## Inbound NC descriptor and model selection

`AudioService.getGraphSettings` distinguishes the microphone and speaker directions. For the speaker it copies `audioConfig.configs.speaker.processors`, uses `audioModelsSelector().inbound`, passes the selected device's sample rate, and uses the speaker suppression level. It disables performance-based model selection for speaker. Optimized-model preference remains configurable.

`ProcessorManager.constructProcessors` looks for an `ncProcessor` configuration. It calls `selectNCProcessorModels`, stores the selected model name in `params.ncModel`, and stores the requested suppression level in `params.noiseSuppressionLevel`. Its mapping constructs `NCProcessor` with the supplied `isNCSuspended` state. `NCProcessor` extends `BaseProcessor` and uses the native `ProcessorType.NC` enum for its descriptor. Ordered configuration entries determine processor order.

The current inbound catalog contains ordinary `nc-inbound-mwb`, type 0, with the exact filename documented in `inbound-model-findings.md`. Dynamic selection filters by requested model type and the device sample-rate range, then falls back to a default/first model if needed. This is a code path to a model name, not proof that every original speaker session chooses that name.

The speaker configuration includes an NC entry only under a feature-preset condition. That entry has default suppression 100, `rdThreshold: 0.96`, a configured `rdModel`, and an empty energy-model name. The preset's obfuscated key was not decoded in this bounded pass. The captured speaker order places volume at index 2, NC at 12, accent processing at 13, recording stages after those, file playback at 20 and the conditional AEC monitor at 21. Those indices are configuration order, not an exercised processing trace. ProcessorManager resolves the RD name from the other-model catalog when configured. The independent ordinary inbound worker does not reproduce that whole configured processor stack.

## Branches and bypass gates

The selected ordinary branch is conditional:

- Speaker settings can request BVC. Interpreter service can also enforce BVC on the speaker. In those cases `getGraphSettings` requests BVC instead of ordinary NC.
- NC is suspended when the NC switcher is off or when the accent-processing switcher is on.
- Graph `passThrough` is set when persistent streaming is enabled and processing should not be active. StreamManager forwards that value as the native graph pass-through parameter, defaulting to false when absent.
- Feature flags can remove inbound NC/BVC models during StreamManager initialization. Other feature conditions determine which processor descriptors exist.
- Profile updates can change speaker suppression level, model preference and related settings. The selected running account, enforcement state and effective values were not read.

These gates prevent the statement that original speaker audio always passes through one active ordinary NC model. They also prevent assuming that NC-off must collapse stereo. The earlier native analysis permits inactive NoiseCanceller processing to return the original input view.

## Connection to the native channel report

The unchanged native addon identity is `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. Existing `native-nc-configuration-findings.md` binds NoiseCanceller model-name lookup and stream creation to the shared frame specification. `KrispMediaSDK::CreateStream` passes its sampling rate and channel byte to KMSStream. `native-speaker-channel-findings.md` establishes that the selected two-channel Float32 KMS bridge averages `(L + R) / 2` into one mono SDK processor and duplicates the processed result.

This investigation now establishes that the desktop playback branch supplies a default stereo frame specification and an ordinary NC descriptor. It does not newly prove the complete native `CreateGraph -> ProcessorFactory -> NoiseCanceller` dispatch and effective frame-spec propagation for that descriptor. The selected current native factory branch was not inspected here. Thus the average/mono/duplicate interpretation is supported for the previously recovered ordinary KMS branch, with a remaining native dispatch join, rather than observed complete original-app stereo behavior.

## Next step and limits

The existing experimental inbound worker implements one supported ordinary-model branch, with separate microphone state and explicit average/duplicate adapters. Retain that qualification. Do not infer that all original speaker modes, RD, accent processing, BVC, volume, recording, capture, pass-through or effective configuration overrides are reproduced.

The smallest further static proof would inspect the current native NC processor-factory case and the graph's frame-spec propagation to NoiseCanceller. A later separately authorized stereo runtime comparison can test the complete original branch. No such execution occurred here. Current UI selection, running device graph, normalized amplitude policy beyond selected code, quality, algorithmic latency, sustained scheduling and model-tail behavior remain unknown.
