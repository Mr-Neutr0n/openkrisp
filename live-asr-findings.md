# Local streaming ASR contract

Static checkpoint, 2026-10-29. The installed local ASR model identity and the JavaScript-to-native start contract are recovered. A direct external-PCM adapter is not yet established. No model loading, inference, original application execution, microphone access or audio capture occurred in this investigation. Original artifacts were read only through REA. The authored readers parse packaged source or disassemble exact native symbols under network denial.

## Evidence and identities

All records below are private retained REA results in `evidence/model-probes/`. Each new capture exited with code 0 and reports owned-process-group cleanup verified and temporary-root removal. The result files retain the authored reader output.

| Result file | Accepted Evidence |
| --- | --- |
| `local-asr-identities-20261029-v1.result.json` | `ev_bffca013e20279822e6caa4b3c7bd70b84ac30caee158b23ccd8681f01d33ee4` |
| `local-asr-static-20261029-v2.result.json` | `ev_f2f01547b3c4fa4f295f9e47581ad808c4fc3e4fc5024788e6a8c8089ba0083d` |
| `local-asr-static-20261029-v3.result.json` | `ev_f1ea90604c3379d4da4a2523a5639d7d5ab1c5c2cc8f1818ed083a46c4131423` |
| `local-asr-symbols-20261029-v2.result.json` | `ev_f5aee3efc53945ac1c2e266acb2b54b56cdb0571d7bdad5ed2e5cc700ce8b516` |
| `local-asr-native-20261029-v1.result.json` | `ev_d967b0234cbec5290ed408e2c2d8a94bd91d6cc4b700988089f41fa2b3357cd1` |
| `local-asr-native-20261029-v2.result.json` | `ev_b9da0a492c4e7f9696cf59a7c5c6b25f78ce3a4c000e7aa6e0445180c1b8750e` |

The exact installed model `/Users/harikp/Library/Application Support/krisp/models/asr_eng_6.3.0_1.0.kef` is a regular file of 616,329,903 bytes, SHA-256 `1720c5ef0a7d921fd6e95be04103ad20dab762ce547ed9d43dd339102262e51f`. The exact older `asr_eng_6.2.0_1.0.kef` path returns ENOENT. The bounded reader used O_NOFOLLOW and verified the opened and final path identities and metadata. This establishes current file identity, not loadability or inference quality.

The installed `kr-media-sp.node` is 26,499,984 bytes, SHA-256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. The ASAR SHA-256 is `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`. Its Bootstrap member `.vite/build/BootstrapApp-3T6N5QeL.js` has SHA-256 `bbaedd07bcd78d093f1011a41e3aeca92707c1f77fc7cca03305ffd4cd90cff0`. The readers hash original files before and after inspection. Native addresses below apply to these addon bytes only.

## Local model and start API

`AsrModelLoader` selects the configured ASR model and resolves its file under the user models directory. It checks file existence, then calls `audioService.loadASRModel(path, forceCpuInference, customVocabulary)`. The StreamManager forwards `LoadASRModel(path, forceCpuInference, customVocabulary)`. The loader retries once with CPU forced if the first attempt fails with CPU not forced. It distinguishes memory-allocation failure from other SDK errors and checks whether it remains initialized after the awaited operation. Original account and feature gates surround this path; they are not prerequisites for an independent local implementation.

StreamManager calls the addon with six arguments:

```js
StartASRProcessing(
  asrStreamId,
  audioConfig.configs.speaker.frameSpec,
  audioConfig.configs.microphone.frameSpec,
  inboundDebugPath,
  outboundDebugPath,
  {
    asrModelPath,
    enablePc: true,
    enableItn: true,
    enableRepetitionRemoval: true,
    enablePiiFiltering,
    enableVad: true,
    diarizeInbound,
    diarizeOutbound,
    customVocabulary,
    enableBeautification,
    forceCpuInference,
    enableYieldWords,
    resultCallback
  }
)
```

The packaged configuration contains microphone `frameSpec: {sampleSpec: {format: 1, rate: 32000, channels: 1}, duration: 10}` and speaker `frameSpec: {sampleSpec: {format: 1, rate: 48000, channels: 2}, duration: 10}`. These are defaults, not proof of accepted rates, channel limits, model-internal framing or frame-count requirements. The unit of `duration` is unresolved in this focused evidence. Native PCM forwarding uses float vectors, but this alone does not prove that every external representation denoted by format 1 is accepted by ASR.

On success, StreamManager configures each selected graph's `ASR_PROC` with `asrStreamId`, `isInboundStream`, `pairStreamIsStarted` and `cacheSizeSec`. It prefers SYSTEM_MIC_OUTBOUND over KRISP_MIC_OUTBOUND, and CAPTURE_INBOUND over KRISP_SPK_INBOUND. The speaker graphs set inbound true. It resumes or suspends processors according to processing state. `updateASRProcessing` changes pair state and suspension for both selected legs. Stop first clears the graph stream identities and pair flags and suspends both processors, then calls `StopASRProcessing(asrStreamId, discardResults)`. `YieldASRResult(asrStreamId)` is a separate native operation.

## Result callback and native feed

The wrapper receives eight native callback arguments:

```js
(nativeStreamId,
 wordsInbound, piiIndexesInbound,
 wordsOutbound, piiIndexesOutbound,
 speakersInbound, speakersOutbound,
 resultType)
```

It copies the six collections into a result object with those exact collection keys and `resultType`, then calls its outer callback with the captured `asrStreamId`. Result enum values are None 0, General 1 and YieldWords 2. These names do not establish partial/final semantics.

The native word serializer at `0x18108` reads a vector of 40-byte tuples containing two floats, a UTF-16 string and a float. The speaker serializer at `0x184f4` reads tuples containing a string, two size_t values and a float vector. Their object-key string addresses were recovered, but the exact key strings and time/index units have not been verified. Do not label the tuple positions as word start/end/confidence or speaker embeddings based on shape alone. NAPI callback symbols include `NonBlockingCall` and result copy/destruction operations; queue capacity, callback-drain guarantees and shutdown ownership remain unresolved.

`ASRProcessor::SendFrameToStream(float const*, size_t)` at `0x100b14` allocates a vector and copies `count * 4` bytes from its input. A direction flag selects which of two vectors is populated. It calls the multistream object and then destroys its temporary vectors. This is not an RT-safe feed path. The virtual dispatch target still needs an exact vtable join before it can be treated as a callable ABI.

`KMSMultiStream::ProcessAudioFrame(const vector<float>& inbound, const vector<float>& outbound, bool, bool)` at `0xc17f4` copies both vectors into an AsyncInvoke closure. It reports dropped frames when invocation fails. There is no host or sample timestamp argument at this boundary. The exact meaning of the two booleans, accepted chunk sizes, queue bounds and failure policy remain unresolved. The upstream capture clock cannot be silently discarded until the required ordering and framing contract is known.

`KMSMultiStream::CreateASRProcessor` at `0xbffa4` builds input frame-processing chains and calls the SDK's `createProcessor` specialization for ASR result handler, per-frame configuration supplier, configuration, `Audio::MultiStreamDescriptor` and `CompositeFrame<float>`. `StopProcessing(bool)` at `0xc1c4c` includes a last-frame send. The bool/discard mapping, flush behavior and final-result delivery order need further recovery. Existing NC processing probes do not validate these ASR-specific contracts.

## Boundary and next step

This is a local model path and native SDK processor path. It does not require a cloud ASR endpoint in the recovered load/start call. It also does not establish that cloud features elsewhere in the application are local. Original AsrService activation and recording joins remain documented, with their evidence caveats, in [activation-findings.md](activation-findings.md). A model hash and static start API do not prove successful offline inference.

The current blocker is the external-PCM construction and lifetime ABI. No direct JavaScript PCM-push export was established. The feasible next investigation is a bounded native recovery of: (1) MultiStreamDescriptor and stream/processor construction and destruction; (2) exact word/speaker property strings, units and General/YieldWords completion semantics; (3) ProcessAudioFrame boolean meanings, framing, backpressure and flush; (4) callback ownership and drain behavior. Only then can an isolated worker adapter be designed and tested with synthetic files under network denial.

The production capture pipeline already retains separate validated app and microphone blocks before its final recording mix. That is a possible future off-RT branch point. Feeding the mixed recording, inventing timestamp/framing rules, or substituting Apple Speech would not implement the recovered native local-ASR contract. No capture refactor or ASR provider was added at this checkpoint.

## Native feed and construction follow-up, 2026-10-29

This section supersedes the earlier unresolved virtual-dispatch and duration-unit statements. It remains static evidence. New accepted records are `local-asr-native-20261029-v3.result.json` (`ev_0b92c6ee4ea15abc0e809b87015aa94be6d0c7bd9199b84897c74f64970e1ce5`), V4 (`ev_6937326b234491d1b43bd25a3853d4ead29799d5c4faf1a3e69ca389b3c14d77`) and V5 (`ev_aa97ded0f5deda47fcce23745df5c314ed861a7ee4be4c8d2c45f097c8d09368`). All exited 0, report group cleanup verified and temporary-root removed, and preserve the same before/after addon hash. V3 additionally lists three failed sysctl process samples; cleanup verification and sample coverage are distinct fields. Symbol inventory V2 is `ev_06a5db615ae411bc139cb0c21cbf69ad38b367f201b591588e04dd32c8b897b5`.

The separate `local-asr-feed-symbols-20261029-v3.result.json` failed outer cleanup verification. It has no accepted Evidence ID. Its envelope reports live candidates 86178/86179 with unavailable ownership environments and sample 86177 with platform-binary environment withheld. No retry, signal or repair was performed. Root later found no rows for those exact PIDs; that establishes later absence, not capture-group cleanup. Do not promote this failed capture to an accepted record. The conclusions below use accepted disassembly.

### Frame sizes and feed flags

`AudioFrameSpec::FrameSize` at `0x3ce4c` reads format at offset 0, rate at 4, channels at 8 and duration at 12. For format 1, it computes `(uint32(rate * channels * duration) * 0x10624dd3) >> 36`, a compiler division by 250, returning bytes. Combined with the four-byte float feed, the default duration 10 therefore represents 10 ms: microphone 320 float values / 1280 bytes and speaker 960 float values / 3840 bytes. This unit is derived from the native formula. It does not establish support for arbitrary sizes, overflow inputs or every declared format.

Reviewer static vtable read `ev_8ea9aadd48d6df1f7c5f99bff17c8f6ca9095fc90a33fd1fb058994b8750bf79`, retained as `local-asr-result-strings-20261029-v2.result.json`, closes the virtual join. The constructor installs vptr `0x1104628`. Its +0x18 entry is `0xc17f4`, ProcessAudioFrame. Other entries are destructors at +0/+8, CreateASRProcessor at +0x10, YieldResult at +0x20, StopProcessing at +0x28 and Close at +0x30.

ProcessAudioFrame copies its two vectors and stores its first bool in closure byte 0x38 and second bool in 0x39. Worker closure `0xc5710` processes nonempty inbound/outbound buffers through their separate FrameProcessingChains. It copies their resulting float buffers. When the first bool is true, it substitutes the stream's shared zero vector for either empty leg. This supports the wrapper's `pairStreamIsStarted` join. The second bool marks the last frame and is stored as the per-frame end state. Normal data is assembled as two consecutive 24-byte libc++ float vectors, then passed by reference to `SDK::Stream<CompositeFrame<float>,MultiStreamDescriptor>::pushFrame`. There is still no timestamp argument in this path.

The zero-vector size is taken from a global FrameSpec during construction. Do not assume it equals either selected source FrameSpec without closing that global configuration join. Exact external input chunk validation and the FrameProcessingChain conversion requirements remain necessary before feeding arbitrary source blocks.

### Queue and stopping

AsyncInvoke::Invoke at `0xc2e6c` locks its mutex and returns false without enqueuing after its stopped flag is set. With a pending list count of at least 20,000, it removes oldest entries until fewer than 20,000 remain, then appends the new closure. It returns false in that case to report loss. False therefore does not imply rejection of the new frame. The queue stores shared stream ownership with each closure. ProcessAudioFrame reports dropped frames from that result. The count bounds pending entries in this queue, not all work or bytes: the worker moves the queued list into a local batch before executing it outside the queue mutex.

AsyncInvoke::Stop at `0xc303c` sets the stopped flag, wakes its condition variable and joins its worker thread. The worker's observed stopped branch can exit without moving remaining queued work to a local batch. Stop must not be treated as a transcript flush guarantee.

`StopProcessing(true)` branches directly to Close. `StopProcessing(false)` normally creates zero-filled vectors using each retained FrameSpec's byte FrameSize divided by four and calls ProcessAudioFrame with `(false, true)`. If its assertion/finalization state is already set, it queues a closing task instead. The last-frame worker path pushes the final composite frame, flushes the SDK stream, disables and destroys the ASR processor under the shared SDK mutex, and closes the SDK stream. Failure paths log and can send empty results. The callback completion and public stop-promise ordering still require the separate result-lifetime investigation.

### Construction boundary and hardware-free startup assessment

KMSMultiStream constructor `0xbfbec` copies/retains these inputs: a six-string error callback, stream ID, shared SDK, shared mutex, inbound FrameSpec, outbound FrameSpec, inbound media file, outbound media file and SDK Stream. Observed field offsets are callback 0x18, ID 0x38, SDK 0x50, mutex 0x60, FrameSpecs 0x70/0x80, media files 0x90/0xa0 and SDK Stream 0xb0. It creates its AsyncInvoke worker and zero buffer. This layout is specific to the pinned build, not a portable C++ header.

SDK createStream at `0x1b5c18` copies a 16-byte MultiStreamDescriptor and invokes its validator. The validator reads two 32-bit duration fields at 0/4 and two 32-bit rates at 8/12. The inbound/outbound field order and the manager factory that constructs it remain unclosed. Validation also has cross-field control flow; its visible constants alone are not an accepted-limit table.

The exported global StartASRProcessing at `0xb4d4c` checks initialized manager and FrameSpec inputs, prepares optional debug WAV files, and calls manager virtual +0x40 to obtain an IKMSMultiStream. It then invokes CreateASRProcessor and removes the stream if processor creation fails. No graph ID is an argument to the exposed start/yield/stop contract. No HAL acquisition appears in the inspected KMSMultiStream constructor. This makes a startup-only probe with empty debug paths plausible without any graph. It does not prove hardware-free initialization or factory behavior: the manager virtual factory and Initialize path must be closed first. No such probe was executed.

A direct adapter must therefore recover the manager factory and descriptor field order, configuration construction/destruction, frame-conversion chain and ownership of returned streams. Calling an internal member function with a guessed object or relying on the field map above is not an implementation. The next narrow static target is the manager virtual +0x40 factory and its SDK createStream call, followed by exact ASR configuration lifetime. Result keys and callback shutdown are tracked separately by the reviewer.

### Manager factory join

A subsequent changed-scope query is accepted as `ev_8a2b7cea914c7f316eefac2b756e0504ddfb7b8c35ebee3fed334d429ec74547`, retained in `local-asr-factory-static-20261029-v1.result.json`. It exited 0 with group cleanup verified and temporary-root removed. One process sample reports platform-binary environment withheld. The authored reader parses the Mach-O symbol table and vtable bytes directly, then disassembles only the selected factory; it does not run the original addon. Addon SHA-256 is unchanged before/after.

The KrispMediaSDK vtable is at `0x11052a0`, with method address point at `0x11052b0`. Address-point +0x40 is `0xd4fb0`, `KrispMediaSDK::CreateMultiStream`. This closes the global StartASRProcessing manager dispatch. The factory checks nonempty ID, nonnull specs, initialization and existing stream-map identity. It calls SDK createStream, allocates KMSMultiStream with shared ownership and stores the stream in its ID map. There are no graph creation or HAL acquisition calls in the inspected factory. This strengthens the static basis for a graph-free start probe; it is not evidence of runtime success or of all Initialize side effects.

The factory closes the descriptor field order as four consecutive 32-bit fields: inbound duration, outbound duration, inbound sampling rate and outbound sampling rate. However, it does not use the selected input rates directly for this descriptor. For each direction it copies the global FrameSpec referenced at `0x11770c8`, substitutes the selected direction's duration, and passes that temporary spec to GetStreamParamsFromSpec. It initializes each helper's output values to duration 10 and rate 16000 before the call, then checks helper success. Those temporary initial values do not prove the global spec or resulting values. The helper at `0xd4d50` has not yet been inspected in this checkpoint. The selected frontend FrameSpecs and native SDK descriptor must remain distinct.

The factory itself now has a concrete constructor path. Remaining startup analysis is the GetStreamParamsFromSpec mapping, global FrameSpec initialization, exact ASR configuration ownership and Initialize side effects. A synthetic CPU-only startup probe could use the exported NAPI lifecycle after those bounds and callback shutdown are reviewed. No such execution is authorized or performed here.

### Normalized SDK frame specification

Two further static captures close the default spec and mapper. `local-asr-normalized-spec-20261029-v1.result.json`, Evidence `ev_16aefd076e80d124a902557c2ea0912e52b507567aae0403bcde085eed9ea133`, and `local-asr-default-spec-20261029-v1.result.json`, Evidence `ev_76e7cb0f1b7755e5b0e9a32a1a672a561f846eb2d768358fbaa086c7aa036e1d`, both exited 0 with owned-group cleanup verified, temporary-root removed and unchanged addon SHA-256. They execute authored static readers only.

Definitions static initializer `0x3e3f0` constructs `DefaultKMSFrameSpecPtr` at `0x11770c8`: format 1, rate 16000, channels 1, duration 10. `GetStreamParamsFromSpec` at `0xd4d50` requires format 1, accepts duration values 10, 15, 20, 30, 32 or 40, and accepts rates 8000, 12000, 16000, 24000, 32000, 44100, 48000, 88200 or 96000. It copies accepted rate and duration into its outputs. It does not inspect channels. These are this mapper's static checks, not a claim that ASR accepts every combination or arbitrary external block sizes.

Combining that initializer with the factory proves that the packaged 10 ms frontend defaults produce SDK descriptor `{inDuration: 10, outDuration: 10, inRate: 16000, outRate: 16000}`. The native ASR SDK receives float composite frames with two mono lanes targeted at 160 samples each per 10 ms. The selected source specs remain microphone 32 kHz mono and speaker 48 kHz stereo. The SDK descriptor does not preserve those source rates or stereo channels.

Accepted native V1 already closes the conversion configuration: CreateASRProcessor at `0xc048c` and `0xc0570` passes each selected lane's AudioSampleSpec and the DefaultKMS AudioSampleSpec to `FrameProcessingChain::Create(..., false)`. The worker applies each chain before constructing its SDK composite frame. This proves the configured target format and routing. The exact resampler/downmix policy, output-size enforcement and behavior on partial external chunks still need inspection or a separately authorized synthetic probe.

KrispMediaSDK::Initialize at `0xd1888` creates the SDK, calls SDK initialize and creates a default SDK stream using DefaultKMSFrameSpecPtr with its bool argument false. It then has model-dependent preload/text-stream paths. There is no direct HAL acquisition in this inspected manager Initialize body. The exported addon Initialize wrapper and SDK initialization internals are separate boundaries; this local observation does not prove that every initialization side effect is hardware-free. The implementation worker owns the exported NAPI parser and worker-lifecycle assessment.


Further original-provider work is parked for the standalone audio acceptance milestone. Exact result keys, time/index units and callback abort limits are retained in [live-asr-results-findings.md](live-asr-results-findings.md). No ASR runtime probe was executed.
