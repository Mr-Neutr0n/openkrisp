# Installed model provider contract

The installed NC model can load locally through the native addon. Current probes recover the initialization, model-object and graph argument schemas. They do not yet establish an audio-processing route. The first network-denied synthetic-file graph stopped at source creation, before processing or output.

Current unresolved prerequisites are approval and installed HAL verification for the prepared LabVoice synthetic source, exact running sample semantics, frame duration units, completed sample processing, validated output and an NC-off comparison. The initialization and model-object fields are recovered.

## Current identity and scope

The installed application changed from 3.16.8 to 3.17.9 during the investigation. Root's current plist Evidence is `ev_3a54568811b26cf5484325645d4ec772d8a425f658baf6e523ffd035b522b820`. Current ARM64 addon SHA-256 is `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`, observed by native REA Evidence `ev_9d50689e7c21e8ee795702e6530ac10449eb05a44b7abd684e9ab88ecfff3dd9`, saved in `evidence/model-probes/current-mediasp-macho.json`. Earlier native digest `168928030a95579e68bfabb7716a9211779d3bcaa18e88be8df43c55ba61385a` belongs to the historical records below. Do not reuse historical procedure addresses for current bytes.

Current runtime logs report KMS 1.19.1 build 500 when the selected model initializes. The probes use only the installed addon, local model files and private synthetic artifacts. They do not launch the application bootstrap, sign in, patch a gate, configure RTC/cloud endpoints, modify vendor files or publish vendor weights.

Initial export and field-rejection probes did not hash the addon inside each run. They establish observed runtime operations but do not bind every earlier observation to an exact in-run digest. Later static and synthetic probes record addon hashes before and after. The synthetic probe also records the selected model hash before and after, and fails if either changes.

## Host and actual addon registration

ARM64 Node v26.7.0 can require the installed addon when `DYLD_LIBRARY_PATH` points at the installed `Electron Framework.framework/Versions/A/Libraries` directory. Export-list Evidence `ev_b8d0c7cf5f318adcc5f8a5a6b4d7ff9a25b20efdc2f7f09f450ecfa1c90df25b` is saved in `evidence/model-probes/list-addon-exports.result.json`. It observed 33 callable exports, including `Initialize`, `LoadModels`, `CreateGraph`, `StartGraph`, `StopGraph`, `DeleteGraph` and `Destroy`. This is a tested host route for this installation. It does not establish Bun compatibility or distributable SDK support.

## Recovered initialization and model objects

```js
Initialize({
  logLevel: 0,
  logPath: privateLogPath,
  modelsDir: installedModelsDirectoryWithTrailingSlash,
  sdkModels: [{type: 0, name: 'nc-outbound-mfb', path: 'c8.f.m.528d1f-1.0.1_1.0.kef'}],
  workingDir: privateWorkingDirectory
  // certBundlePem is read but was omitted in successful local probes.
}, eventCallback, textCallback)
```

Rejected-object probes observed configuration field reads in this order: `logLevel`, `logPath`, `modelsDir`, `sdkModels`, `workingDir`, `certBundlePem`. Missing required arguments or wrong field types return numeric 8. Two callback arguments are required. Empty `sdkModels` with these fields and callbacks returned 0; `Destroy()` returned 0. Evidence `ev_966a8baf8b418b5b148bea4e845cfcfe738a8c2561ffb21c2c8aa971a513fec4` is saved in `initialize-callback2.result.json` under the model-probes directory.

The SDK model object reads `type`, `name`, `path`. Missing type, name or path returns immediate numeric 8. The name is UTF-8 text and the path parser expects a string through its UTF-16 helper. For an accepted object, `LoadModels` returns a promise. Without initialization, that promise resolves numeric 3 after logging `Not initialized`. Evidence `ev_84a22128b009f7b30a69a285bdb9adb2a1ed2998a0b72de76e9301649025806d` is saved in `model-parser-path.result.json`.

Dynamic `LoadModels` is not the NC loading route in this tested implementation. With successful initialization it resolves 8 for type 0, and the local log says `Unsupported model type: NC` and `InvalidArgument`. Evidence `ev_c5b4ac7663cca11697c5404ce7c6b04b1cce55a00ca23de9cfcff680a3debe0d` is saved in `load-installed-nc.result.json`; its generated private log explains the failure. NC loads through initialization's `sdkModels` list instead.

The native loader concatenates `modelsDir` and model `path` literally. An absolute model path duplicates the directory. A directory without a trailing slash produces `audioc8...kef`. Both paths failed to open. Yet `Initialize` still returned 0, so initialization success alone is not model-load proof. The corrected combination of a directory ending `/` and a relative filename logged `NoiseCancellation processor created` and `Model is loaded`. Evidence `ev_577f43a8dd53c48ab08a04142dbf57b9ff04ef5c188d7542aef488f8d024a8fe` is saved in `initialize-slash-nc.result.json`.

An implementation must check immediate status, asynchronous status and actual model/processor availability separately. `await 8` succeeds as a JavaScript expression; a promise resolving 3 or 8 also fulfills. Neither means a usable model.

## Network-denied helper

`/usr/bin/sandbox-exec` is available. Later runtime scenarios declare `(version 1) (allow default) (deny network*)`, then use `/usr/bin/env` to pass the dynamic-library path to Node. This avoids relying on a DYLD environment variable surviving the platform executable's launch. No global network policy changes occur.

The selected model initialized under this policy, Evidence `ev_5a9e5ce9d60f512f388eb9ddcc1625cacc86c3f286f430eb5da4062f7e7d21d3`, saved in `initialize-sandbox-nc.result.json`. A later helper made an explicit synthetic loopback connection attempt and received `EPERM`. Evidence `ev_e356d333d7d00eb4802701cc5e27486b589292076a76641e468dd96e792f40d7` includes that result, model loading, successful creation/deletion of an unstarted type-0 graph and teardown. The denial test does not prove that installed libraries made no other attempts. It demonstrates that this helper's attempted socket operation was denied.

## Recovered graph schema

The accepted N-API parser boundary is five arguments. A previously supplied sixth empty array was not accessed and is not part of the recovered contract.

```js
CreateGraph(
  {id: graphId, parameters: [], callbacks: []},
  {sampleSpec: {format: sampleFormat, rate: 32000, channels: 1}, duration: 10},
  {id: sourceId, name: sourceName, type: mediaType},
  [{id: processorId, type: processorType, suspended: false,
    parameters: [{name: parameterName, value: parameterValue}], callbacks: []}],
  null // A null sink descriptor passes parsing.
)
```

The graph descriptor reads `id`, `parameters`, `callbacks`. The frame descriptor reads `sampleSpec.format`, `sampleSpec.rate`, `sampleSpec.channels`, `duration`. A media descriptor reads `id`, `name`, `type`. Each processor reads `id`, `type`, `suspended`, `parameters`, `callbacks`. Each parameter entry reads `name` and `value`. A string `filePath` parameter and a null sink passed parsing, then reached `Not initialized` with numeric 3. Hash-bound Evidence `ev_e7f9b64617ad1c3aa612db77695876d3cd43b387184df24e37976e828ac5bf81` is saved in `file-path-null-sink.result.json`.

The graph parser accepts numeric enums; this does not establish a usable implementation for every enum. No graph processing occurred in these rejected-input probes. Frame duration 10 was accepted; its unit and exact sample contract still need a successful started graph.

## Current enum and settings evidence

Focused LLVM disassembly was run through REA process capture, rather than another Ghidra import. Exact table ranges came from current native REA section mappings. All these newer readers hash the addon before and after. These are process-captured static-tool results and analyst derivations, not native-provider execution traces.

Media formatter branches identify 0 as `krisp`, 1 as `system`, 2 as `process loopback`, 3 as `device loopback`, 4 as `generator`. Evidence `ev_1c021d180f4b41e4a27e163589224f00e25421aa65db9ee66da7ea255dfa4511` is saved in `media-type-disassembly.result.json`. This first formatter probe was followed by the current native digest inspection.

Processor formatter disassembly and its exact 18-byte jump table identify NC as 0, FILE_REC as 3 and FILE_PLAY as 12. Audio sample formatter pointer entries label formats 0 as `'s'`, 1 as `'f'`, 2 as `'u'`. These short labels alone do not establish sample width or full PCM semantics. Evidence `ev_62dd8d9030ff2592eeca5dc4ef0ad44b65d3f0f67fb5ae3e20acfa200c6c1b60` and `ev_e8f48abc5ea7b1ebcb9d66f90a77e13aa4d6a49e0e14167945add329fe43dcfb` are saved in `processor-format-enums.result.json` and `enum-tables.result.json`.

File-format formatter branches identify 0 as Invalid, 1 as WAV, 2 as MP3. FileRecorder's settings-change code reads `filePath` and `fileFormat`. Evidence `ev_b861f861d6fd5d73f723fda8b3a71fdd1a9a72d7cb6350823cd37d3735988d92` is saved in `record-file-settings.result.json`.

FilePlayer's settings getter reads `fileId`, `filePath`, `fileFormat`, `volumeFactor`, `originalVolumeFactor`, and a playback-state callback name. The NC getter reads `ncModel`, `rdModel`, `energyModel`, `rdThreshold`, `noiseSuppressionLevel`, and `streamStats`. Its suppression value uses a default 100 and clamps to 0 through 100 in this recovered code. Evidence `ev_94ae630db3fe9e81ac277fbb09db07f0d09c6bc66788f12819bddc6ef4703def` is saved in `file-nc-settings-disassembly.result.json`. Raw terminal output was complete at 30170 bytes; rendered terminal frames exceeded their budget. Use raw frames for these findings.

## First synthetic processing attempt and actual blocker

The helper generated a two-second mono 32 kHz PCM16 WAV containing silence, a known tone and deterministic noise. It loaded the installed NC model, then attempted a generator-source graph with FILE_PLAY, NC and FILE_REC processors and no media sink. It did not start a graph because `CreateGraph` returned numeric 2. The native log states `Failed creating source media` for media type `generator`. No output WAV exists.

Evidence `ev_c782fa8d2f7a5c6eab1f9209ceb2bca4fc525257c6e59670acf042c90daf0032` is saved in `synthetic-graph.result.json`. The helper confirmed loopback `EPERM`, KMS 1.19.1 build 500 and unchanged addon/model hashes before and after. The model SHA-256 was `12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d`. A model hash is an identity record, not copied weights or redistribution permission.

Remaining prerequisites are a source supported by the Mac media factory, verified generator IDs or a synthetic CoreAudio source, actual frame encoding and duration units, lifecycle completion, sample output validation and NC-off comparison. The generator enum exists, but the Mac source factory below rejects type 4 before inspecting its ID. The completed focused source-factory reader below proves that type 4 is unsupported on this Mac implementation. Do not instantiate real microphone capture or a cloud channel to hide this blocker.

All current probe helpers, declared scenarios, raw results and synthetic artifacts remain under `evidence/model-probes/`. The earlier test-launch argument assembly failure remains as `graph-create-type0.result.json`; it is not original-app behavior evidence. The corrected scenario is separate.

## Supported source boundary and ready HAL probe

Current macOS `MediaFactory::CreateSourceMedia` disassembly is Evidence `ev_94d750749143b776ca4bd94d8d52169ddaca9216bcec74266ba02b2f18d52a81`, saved in `source-factory-disassembly.result.json`. For types above 2 it subtracts 3 and compares against 3. Types 3 through 5 return status 2 with null media. Therefore type 4 generator is unsupported by this factory, independently of the source ID. Types 0, 1 and 2 enter Krisp-device, system-device or process-capture branches. The prepared next probe uses only type 1 and the independently implemented LabVoice microphone.

Type 1 calls `FindAudioDeviceId(id, name, true)`. The exact lookup disassembly, Evidence `ev_d5ec9a584707a61610e315393ea0cae37bb3370e3b0133c29ceb92b51ffc80fb`, is saved in `system-device-id-disassembly.result.json`. A nonempty `id` is parsed with base-10 `stoi` and passed to `FindAudioDeviceById`. This field is the decimal CoreAudio AudioObjectID as a string. It is not a UID. If the ID lookup fails, the function can fall back to name lookup. An empty ID and empty name can select the default device. The prepared helper supplies a verified numeric ID and the exact LabVoice name; it never supplies empty selections.

The ready helper is `evidence/model-probes/run-labvoice-source.cjs`. It calls the independent `app/audio-driver/hal-test/build/LabVoiceHALTest.app/Contents/MacOS/LabVoiceHALTest --inventory`, which reads exact CoreAudio UIDs without starting audio. The helper requires the complete successful four-device inventory and exactly one alive, visible, mono-input row with UID `dev.hari.labvoice.microphone` and rate 48000. The inventory also verifies endpoint owner, virtual transport, shared clock domain, stream formats and route latency. The helper uses the returned `deviceID` as a decimal type-1 media ID and the driver's declared `Lab Voice Microphone` name, then rechecks the same UID/ID before `StartGraph`. The name is declared by the independent driver; this inventory does not read back the name. Missing or changed devices abort before native initialization or capture. No physical microphone or original shared Krisp HAL fallback is configured. `audio-host --list` is unsuitable here because its device array excludes virtual transports and its companions omit the microphone.

Read-only inventory checkpoint: Evidence `ev_b72c5f7eba68c87c341a913b1cc1557706ca587cdc96e1b96335ebb401afaa78`, saved in `evidence/model-probes/labvoice-inventory.result.json`, exited 1 because exact UID `dev.hari.labvoice.feed` was unavailable. Inspection stopped at that first endpoint, so this does not independently establish the microphone's absence. The helper emitted `checksPassed: false` and no audio was started. The prepared model probes therefore cannot pass preflight in this checkpoint. Rerun this inventory after the approved installation and installed HAL test. The updated Node helper passed `node --check`; its prepared audio scenarios remain unrun.

The NC-on and NC-off scenarios are `labvoice-source-on.scenario.json` and `labvoice-source-off.scenario.json`. They are prepared but have not run. Run them only after installation approval and root's successful installed HAL test. Both use the process-only network-denying sandbox, an explicit loopback denial check, the current addon/model hashes before and after, a private input WAV and private output/log paths, a 12-second process bound and guarded stop/delete/destroy cleanup. The model and addon must match the recorded digests before native initialization. The helper refuses an existing output file, inspects only new native log bytes for model loading, and fails if the current run lacks model-load or NC-processor creation confirmation. NC-off suspends the NC processor; it does not substitute an independent provider or a fake native result.

The declared file-playback parameters are `fileId: 1`, private `filePath`, `fileFormat: 1`, `volumeFactor: 1`, `originalVolumeFactor: 1`. NC uses `ncModel: 'nc-outbound-mfb'` and `noiseSuppressionLevel: 100`. File recording uses private `filePath` and `fileFormat: 1`. These names and value categories come from the recovered getters and N-API parameter probes. Their complete started-graph behavior remains untested.

After root approves the installed route, the intended commands are:

```sh
bin/rea capture-process projects/krisp/evidence/model-probes/labvoice-source-on.scenario.json --format json --full-output > projects/krisp/evidence/model-probes/labvoice-source-on.result.json
bin/rea capture-process projects/krisp/evidence/model-probes/labvoice-source-off.scenario.json --format json --full-output > projects/krisp/evidence/model-probes/labvoice-source-off.result.json
python3 projects/krisp/evidence/model-probes/validate-synthetic-wav.py projects/krisp/evidence/model-probes/labvoice-output-on.wav projects/krisp/evidence/model-probes/labvoice-output-off.wav
```

The validator checks finalized bounded RIFF/WAVE chunks, mono 32 kHz output, supported PCM16 or Float32 encoding, alignment, nonempty finite samples, hashes, levels and paired sample difference. An all-zero NC-off output fails because playback would remain unestablished. Zero NC-on output can be legitimate suppression of these non-speech synthetic signals. A difference does not establish speech quality or latency parity. Syntax checks passed for the prepared Node helper, and the validator parsed the private synthetic input as a fixture. No installed-source runtime has run and no NC output exists.

Current remaining gaps are actual admission and start of the approved LabVoice source, permission behavior for the helper, frame duration/sample interpretation in a running graph, file playback/recording completion, finite validated NC output and the NC-off comparison. HAL installation approval and root's installed HAL test are prerequisites for the ready probes. Do not treat the prepared scripts as processing evidence.

## Historical records retained below

The following sections preserve the earlier static inventory, header finding and Ghidra timeout. Their symbol addresses and original claims remain bound to the earlier artifact identity. Current runtime schemas above supersede the earlier unknown field names. The historical proposed file probe has now been attempted and stopped at source creation as documented above.

## Historical 3.16.8 static boundary

The ARM64 `kr-media-sp.node` has SHA-256 `168928030a95579e68bfabb7716a9211779d3bcaa18e88be8df43c55ba61385a`. Native inspection Evidence is `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1`. It exports `_napi_register_module_v1` at `0x2d428` and `_node_api_module_get_api_version_v1` at `0x2d420`. The required API version value has not been decoded.

The app declares Electron 40.8.5, Evidence `ev_89e1fc43bfba806f7a602eb93548b60e3c78330f852fd683e44835a6ed23428a`. Matching native N-API symbols do not establish compatibility with an independent Bun or Node host. Start with an ARM64 host that demonstrably loads the addon and reports actual export names. Do not load the application bootstrap or its account and cloud initialization.

The addon differs from its ASAR declared companion digest. Contract observations apply to current installed bytes. Exact runtime loads, signature acceptance and host ABI remain unverified.

## JavaScript entry names

Wrapper source is `.vite/build/node_modules/kr-media-sp/index.js`, observed in JavaScript Evidence `ev_a171e77e361a92e3a14ece5a0d849dd226d5669aaa7a8dbc9bafd807200e54ca`. The retained evidence shows static property reads. Registration and invocation remain unverified. Every named N-API handler takes `const Napi::CallbackInfo&` at the C++ boundary. The type name alone says nothing about the number or shapes of JavaScript arguments. The focused loader result below establishes its first array argument.

| Wrapper property | Wrapper location | Native candidate |
| --- | --- | --- |
| `Initialize` | line 4 | `__ZN5Krisp7MediaSP20GlobalInitializeNapiERKN4Napi12CallbackInfoE` at `0x1eb80` |
| `Destroy` | line 5 | Matching handler unresolved |
| `LoadModels` | line 6 | `__ZN5Krisp7MediaSP14LoadModelsNapiERKN4Napi12CallbackInfoE` at `0x1f7ac` |
| `CreateGraph` | line 11 | `__ZN5Krisp7MediaSP15CreateGraphNapiERKN4Napi12CallbackInfoE` at `0x23b6c` |
| `StartGraph` | line 12 | `__ZN5Krisp7MediaSP14StartGraphNapiERKN4Napi12CallbackInfoE` at `0x24624` |
| `StopGraph` | line 13 | `__ZN5Krisp7MediaSP13StopGraphNapiERKN4Napi12CallbackInfoE` at `0x24f1c` |
| `DeleteGraph` | line 14 | `__ZN5Krisp7MediaSP15DeleteGraphNapiERKN4Napi12CallbackInfoE` at `0x252bc` |
| `SuspendProcessor` | line 17 | `__ZN5Krisp7MediaSP20SuspendProcessorNapiERKN4Napi12CallbackInfoE` at `0x25d18` |
| `ResumeProcessor` | line 18 | `__ZN5Krisp7MediaSP19ResumeProcessorNapiERKN4Napi12CallbackInfoE` at `0x263a0` |
| `ChangeProcessorSettings` | line 19 | `__ZN5Krisp7MediaSP27ChangeProcessorSettingsNapiERKN4Napi12CallbackInfoE` at `0x26a28` |

`Initialize` is a wrapper property and `GlobalInitializeNapi` is an observed native candidate. Their actual registration mapping has not been recovered. No direct `process(Float32Array)` or frame-push export appears in this bounded wrapper list. A JavaScript buffer API must not be invented from C++ frame-processing symbols.

## Recovered loader control flow

One focused REA Ghidra decompile completed for `LoadModelsNapi`, exact native identity `__ZN5Krisp7MediaSP14LoadModelsNapiERKN4Napi12CallbackInfoE` at `0x1f7ac`. Evidence `ev_9275044dfb5ee534240e304616388594979919b0e9616fac63bfe86c998aa1f2` is retained in `evidence/native/mediasp-snapshot.json`; the CLI envelope is saved in `evidence/load-models-contract.json`. This is recovered pseudocode, not original source or executed behavior. Ghidra warns that it removed unreachable blocks.

The recovered control flow reads JavaScript argument index 0 through `ArgAsNapiVal`, converts it through `NapiValAsNapiArr`, then calls `SDKModelsFromNapiArr`. If the shared error string remains empty, it constructs a `LoadModelsWorker`, queues N-API async work and returns `LoadModelsWorker::Promise()`. Queue failure raises a Napi error.

Argument and model parsing error branches log `MediaSP::LoadModels. {}` and call `napi_create_double` with bit pattern `0x4020000000000000`, which decodes to 8.0. Thus the candidate JavaScript contract is `LoadModels(modelArray) -> Promise | numeric validation error`. Return value 8 is inferred from the recovered pseudocode and has not been observed at runtime. The exact meaning of 8 and promise resolution/rejection values remain unknown.

A probe must inspect the immediate return value before awaiting it. JavaScript `await 8` completes without throwing and must not be reported as model-load success. Require a real promise or thenable for the recovered success path, record immediate numeric failures, then inspect promise completion separately. This wrapper does not reveal the model-object property names. `SDKModelFromNapiObj` at `0xd558` remains the next small parser target.

## Historical model-object parser timeout

The exact next target was `__ZN5Krisp7MediaSP19SDKModelFromNapiObjERKN4Napi6ObjectERNSt3__112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEE`, observed native address `0xd558`. REA 6.4.0 attempted this single procedure using the same saved snapshot and Ghidra provider. The result is preserved in `evidence/sdk-model-contract.json`.

The provider returned `provider_timeout` for `procedure_pseudo_code`, timeout 330000 ms, after 331244 ms of CLI wall time. It returned no pseudocode and no successful new Evidence ID. The timeout is a tool limitation, not evidence that the parser rejects a model or that its fields cannot be recovered.

No identical retry was run. At that checkpoint the model-object property names remained unresolved. The current runtime probes above now recover them. In particular, neither `file` from models.json nor an invented `path` field is established as a loader property. That checkpoint supplied no model-load result. Current initialization probes above provide the later loading evidence.

## Observed model selection values

The decoded configuration is Evidence `ev_016bcec295d94aa5289ae0b5d7b20c241a7d45e880bb797083c9fd4b59c89def`. These are exact catalog values, not a recovered `LoadModels` argument schema. Paths are relative to `Contents/Resources/resources/models/audio/` for files found in the bundle inventory.

| Category | Name | File | type | Rate range | workRate | performance | default |
| --- | --- | --- | --- | --- | --- | --- | --- |
| accent_reduction | `ar-inbound-wb-c` | `ar_inbound_wb_c_3.12.0_1.0.kef` | 6 | unknown..unknown | unknown | unknown | unknown |
| accent_reduction | `ar-outbound-wb-c` | `ar_outbound_wb_c_ma_3.11.0_1.0.kef` | 6 | unknown..unknown | unknown | unknown | unknown |
| asr | `asr` | `asr_eng_6.2.0_1.0.kef` | 4 | unknown..unknown | unknown | unknown | True |
| inbound | `nc-inbound-mwb` | `c8.w.m.d15e29_1.0.kef` | 0 | 0..192000 | 16000 | 50 | True |
| other | `rd-inbound-wb` | `c6.b78b81_1.0.kef` | 2 | 0..192000 | 16000 | 0 | True |
| diarization | `diar` | `diar_2.0.0_1.0.kef` | 8 | unknown..unknown | unknown | unknown | True |
| outbound | `nc-outbound-mfb` | `c8.f.m.528d1f-1.0.1_1.0.kef` | 0 | 8001..192000 | 32000 | 50 | True |
| outbound | `nc-outbound-sfb` | `c8.f.s.17aa82-1.0.1_1.0.kef` | 0 | 8001..192000 | 32000 | 15 | True |
| outbound | `nc-outbound-snb` | `c5.n.s.20949d_1.2.kef` | 0 | 0..8000 | 8000 | 10 | True |
| outbound | `hvc-outbound-lfb` | `hs.c6.f.m.75df8f.berlin.kef` | 1 | 8001..192000 | 32000 | 75 | True |
| outbound | `hvc-outbound-sfb` | `hs.c6.f.s.de56df.bucharest.kef` | 1 | 8001..192000 | 32000 | 15 | False |

For a first outbound NC probe, `nc-outbound-mfb` maps to `c8.f.m.528d1f-1.0.1_1.0.kef`, type 0, workRate 32000 and catalog input-rate range 8001 through 192000. This is a selection candidate. It does not establish frame length, channel count, sample encoding, scaling, graph direction or processor state. Do not pass the entire models.json entry unchanged without verifying the native parser.

## Native processing candidates

All addresses below come from the same native Evidence. Mangled names retain parameter type declarations. Object layouts, enum values, calling convention details, ownership and return types are not recovered. Direct calls to these C++ methods are not an executable contract.

| Procedure | Address | Declared type information |
| --- | --- | --- | --- |
| `MediaSP::LoadModels` | `0xb3e20` | `const std::vector<SDKModel>&` |
| `KrispMediaSDK::LoadModels` | `0xd4248` | `const std::vector<SDKModel>&` |
| `MediaSP::CreateGraph` | `0xb5dec` | Shared `GraphSpec`, `AudioFrameSpec`, `MediaSpec`; vectors of `ProcessorSpec`; second `MediaSpec` |
| `NoiseCanceller::CreateNCStream` | `0xfcc94` | `const NCConfiguration&`, `const std::string&` |
| `NoiseCanceller::ProcessFrameBuffer` | `0xfc0e4` | `const MediaFrameBuffer&` |
| `KMSStream::ProcessAudioFrame` | `0xcd0d0` | `const MediaFrameBuffer&`, bool |
| `FrameProcessingChain::ProcessData` | `0x3ed6c` | `const MediaFrameBuffer&` |
| `FilePlayer::StartPlayback` | `0xd87dc` | No explicit parameters |
| `FilePlayer::ProcessFrameBuffer` | `0xd8de8` | `const MediaFrameBuffer&` |
| `FileRecorder::ProcessFrameBuffer` | `0xdd9d0` | `const MediaFrameBuffer&` |
| `WAVAudioFile::Read` | `0xf0cd8` | Mutable `MediaFrameBuffer&` |
| `WAVAudioFile::Write` | `0xf108c` | `const MediaFrameBuffer&` |

These file and graph declarations suggest a file-playback or source-to-NC-to-WAV path. They do not prove that file playback can act as a standalone graph source, or that capture hardware can be omitted. Those facts need schema and runtime evidence.

## Exact next parser procedures

| Question | Procedure | Address |
| --- | --- | --- |
| Initialization fields and callbacks | `SPConfigurationFromJS` | `0x8fe4` |
| Loader model fields | `SDKModelFromNapiObj` | `0xd558` |
| Loader array validation | `SDKModelsFromNapiArr` | `0x99d4` |
| Graph identity and flags | `GraphSpecFromNapiObj` | `0xda88` |
| Frame duration and rate | `FrameSpecFromNapiObj` | `0xa83c` |
| Sample encoding and channels | `SampleSpecFromNapiObj` | `0xa324` |
| File/device source and sink schema | `MediaSpecFromNapiObj` | `0xa9fc` |
| Processor chain and settings | `ProcessorSpecsFromNapiArr`, `ProcessorSettingsFromNapiObj` | `0xca6c`, `0xc700` |

Resolve these exact identities in the provider import. Do not treat Mach-O symbol addresses as provider addresses without confirmation. The existing `mediasp-snapshot.json` retains the earlier header dossier, but the current CLI still needs a provider import for new procedures.

## Historical proposed processing probe

This is a proposed controlled probe, not a completed or currently executable script. First recover the loader and graph schemas. Then run only the installed addon in a disposable ARM64 helper process through REA process capture. Use the supported host and installed library paths; keep original weights at their installed paths.

1. Record addon identity, host identity, actual export names and whether loading succeeds. If initialization requires account credentials or network setup, stop and report that requirement. Do not substitute a fake gate result.
2. Generate a short local mono synthetic WAV at 32 kHz. Include silence, a known tone and deterministic noise. Record input bytes and expected frame count. These signals can verify transport and processing; they cannot establish speech quality parity.
3. Initialize only required local logging and model paths, then load the single outbound type-0 NC candidate using recovered argument fields. Record promise completion, returned errors and loaded model identity.
4. Create the smallest validated graph with local file or synthetic source, one NC processor and a local WAV sink. Disable or omit ASR, diarization, RTC, translation, statistics/reporting channels and all network endpoint configuration. If a source-without-hardware graph is unsupported, report the blocker before designing a device route.
5. Start, drain, stop, delete and destroy using the recovered completion contract. Record processed output frames, finite sample values, clipping, channel/rate agreement, input/output timing and an NC-off comparison. Compare valid nonempty samples rather than export-name presence.
6. Monitor actual loaded libraries and outbound socket activity for the helper. A load dependency can contain network code even when the selected graph is local. A successful process exit alone is not proof of no network operations.

## Dependencies and remaining unknowns

The addon links CoreAudio, AudioToolbox, Accelerate, ScreenCaptureKit, MP3 LAME and AEC. It also links `libdaily-core-sdk-wrapper.dylib`, `libsioclient_tls.3.dylib` and `libkrisp-curl-wss-wrapper.0.dylib`. Evidence `ev_495d5179c1cfd10691b76e585ffdf155db8ab9006070248ad9d724519710ccf0` records ARM64 dependency resolution within its declared boundary. It does not prove a network-free selected path. See `cloud-exclusion-map.md` for the remote boundaries.

This historical unknown list is superseded in part by the current runtime contract above. Initialization fields, callbacks, model object fields, literal model path concatenation, graph argument fields and selected enum values are now recovered. Current remaining gaps are a supported synthetic source, sample width and scaling, frame duration units, callback completion, EOF draining, model ownership after initialization, complete error meanings and successful processed output. KEF internal decoding is unnecessary if the vendor loader can use installed files through a recovered supported interface. Do not fake decoding, reconstruct object layouts by guess, patch gates or publish vendor weights.

The retained KEF header dossier, Evidence `ev_ebf047a853a651e85a42b22315e059029e8cbe7241bbfb1222f0d7f92a93846b`, establishes a 52-byte minimum header and three size words. It does not decode weights or establish usable inference. Model redistribution terms remain unresolved in `model-license-findings.md`.

## Device-free route check, 2026-10-15

This check reuses retained REA evidence only. It does not establish that HAL is intrinsically required by the SDK. It establishes that a usable device-free processing contract has not yet been recovered from the addon.

A null source cannot make the existing file-player graph independent of source creation. Current-identity `CreateGraph` disassembly in Evidence `ev_d09b396c0fddbbfe27fbe2ebae2360af53c88764c09c2944cb9afb13fac50bf1` (`evidence/model-probes/graph-generator-disassembly.result.json`) loads graph, frame and source shared-pointer values at `0xb5fd4` through `0xb5fdc`, checks each for zero at `0xb5fe0` through `0xb5fe8`, and branches to the normal path only when all three are nonzero at `0xb5ff4`. The failure diagnostic is “No graphSpec, frameSpec or sourceMediaSpec specified”. This rejects a null-source route before a FilePlayer processor can supply samples. Null sink acceptance does not imply null source acceptance.

The 33 observed JavaScript exports have no generic frame-push or frame-process method (Evidence `ev_b8d0c7cf5f318adcc5f8a5a6b4d7ff9a25b20efdc2f7f09f450ecfa1c90df25b`). FilePlayer remains a processor candidate, not an evidenced source or independent scheduler. Its parameter getter and exported C++ method names do not show whether it injects samples autonomously, replaces each incoming source frame, or requires a running capture clock. The earlier unsupported-generator result therefore does not answer FilePlayer scheduling, and a successful unstarted type-0 graph does not answer processing.

This retained-evidence check identified FilePlayer scheduling as the next static question. The focused check below now answers its incoming-frame behavior. Current retained symbol evidence `ev_9d50689e7c21e8ee795702e6530ac10449eb05a44b7abd684e9ab88ecfff3dd9` identifies `FilePlayer::Start(std::string const&)` at `0xd8228`, `FilePlayer::StartPlayback()` at `0xd8af8`, and `FilePlayer::ProcessFrameBuffer(MediaFrameBuffer const&)` at `0xd9104`. Focused REA disassembly of those exact methods could determine who reads the file and what triggers output. If they require input frames, the next relevant call chain is `GraphManager::StartGraph` at `0x4ab4c` and `Capturer::Start` at `0x38aac`. These addresses apply only to addon SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`; revalidate identity before new original analysis.

Native `NoiseCanceller::ProcessFrameBuffer`, `KMSStream::ProcessFrameBuffer` and SDK `createFrameProcessor` symbols also exist. They are not JavaScript exports. Their object construction, frame layout, callback ABI and ownership contract remain unresolved, so invoking them by guessed layouts would not be a valid bounded processing probe. No new processing attempt, device action or original artifact read was performed for this check.

## FilePlayer scheduling, focused REA static check, 2026-10-15

New Evidence `ev_72c7fb7c08d1bf3c1eb506ec119922e196a95e0f763012f28dbf17032d399376` is retained in `evidence/model-probes/fileplayer-scheduling-disassembly.result.json`, with its scenario alongside it. REA ran only the static disassembly helper against exactly the three methods identified above. The capture exited 0; addon SHA256 before and after was `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. No addon initialization, target runtime execution, audio or device action occurred.

The file player consumes incoming frame calls. `Start` calls `StartPlayback` at `0xd83ec`, allocates/zeros frame-sized buffers, then calls base `Processor::Start` at `0xd8564`. `StartPlayback` creates and opens the media file through virtual calls at `0xd8b5c` and `0xd8ccc`, resets playback positions, and reports open success/failure. These methods contain no visible independent frame-generation loop or timer registration. The base method and media-file internals were not inspected in this bounded check, so that observation is not a proof that every dependency lacks scheduling.

The concrete sample path is in `ProcessFrameBuffer(MediaFrameBuffer const&)`: it retains the input argument in x22 at `0xd9124`, checks `CanProcessFrame` at `0xd9404`, and reads file data through the media-file virtual call at `0xd9500` when buffered file samples are exhausted. It obtains the requested output byte count from the incoming frame at `0xd943c` and again at `0xd9568`; it sizes its output buffer to that count. The mixing loop loads incoming Float32 samples at `0xd9684`, multiplies them by one configured factor at `0xd968c`, then adds scaled file samples at `0xd97c4` through `0xd97d4`. The output buffer is returned at `0xd97ec` through `0xd97f8`. When processing/playback is inactive, `0xd960c` through `0xd9614` returns the incoming frame unchanged. Thus this implementation is an incoming-frame transform/mixer, not an evidenced file-source replacement with its own public sample clock.

Practical conclusion: the recovered JavaScript graph route still needs a supported source that supplies frame calls. Supplying a WAV to FilePlayer does not by itself establish a device-free route, and null source is already rejected. A graph that is only created and never started cannot demonstrate this sample path. A supported source and its start contract remain the blocker for a valid graph-processing probe; the approved synthetic HAL path remains the previously prepared option. This does not establish that all native SDK routes require HAL. No direct-frame native ABI work was attempted.


## Native frame path investigation, 2026-10-15

New identity-bound static REA captures establish a native frame-processing path beneath the JavaScript graph. See `native-frame-factory-findings.md`, `native-frame-processing-findings.md` and `native-nc-configuration-findings.md` for exact symbols, addresses, evidence and coverage limits. These findings do not constitute a callable adapter or successful inference.

The ordinary NC bridge reaches a float SDK factory with C++ shared-pointer supplier/result-handler arguments. The SDK registers the processor and returns a non-owning handle; destruction must follow the corresponding ownership path. The frame wrapper copies Float32 bytes into a vector and calls SDK pushFrame. Its result callback copies samples into NoiseCanceller-owned storage. The caller immediately checks output size, which establishes synchronous expectations in this wrapper, not a complete SDK threading or lifetime guarantee.

Success-like results can return the original input when processing is bypassed or output size is wrong. Future acceptance must establish actual processor activation and compare output, rather than relying on an exit code, boolean return or matching byte count.

A device-free native route remains plausible, but exact descriptor/configuration/callback construction, lifetime, supported framing and drain behavior still require evidence. HAL is not proven to be an intrinsic SDK requirement. The existing source-backed graph test remains prepared but unrun. No original model, binary or asset is included in Git, and no native processing invocation was attempted in this pass.


## Synchronous native dispatch, 2026-10-15

`native-frame-dispatch-findings.md` now resolves the earlier callback-timing and external sample-scaling gaps for the selected active ordinary NC path. SDK push calls the processor inline; both processor branches call the result handler before returning. The local result vector is destroyed after callback return, so a collector must copy it synchronously. External samples use normalized Float32. Both branches require a cached exact frame count.

This does not resolve concurrent use, factory ABI or complete file draining. The DF branch has input/output queues and resamplers. The selected methods have no EOF parameter or short-frame flush. A finite synthetic test can use exact frames and explicit recorded padding, but must not claim that guessed trimming or closing preserves every delayed sample. See `native-stream-close-findings.md` for the distinct close contract and its exception limits.


The descriptor follow-up establishes an eight-byte duration/rate value and sample count `floor(durationMs * rate / 1000)`. A direct adapter must keep this descriptor stable and recreate the processor when changing it; selected NC descriptor-update and finalization callbacks are no-ops. `native-nc-callback-construction-findings.md` identifies the direct typed factory as the shorter candidate than rebuilding KMS and its `std::function` context. The next bounded task is to recover the supplier's packed return type and the stats-plus-vector result type from their consumers, then review a typed C++ shim. No shim or processing attempt is included in this checkpoint.
