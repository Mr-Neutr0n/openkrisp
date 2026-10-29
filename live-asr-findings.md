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
