# Local ASR results and callback ownership

Static investigation, 2026-10-29. This closes the native result property names and the JavaScript interpretation of times, indexes and result types. It also identifies the N-API queue and abort boundary. It does not establish successful ASR inference, result accuracy, SDK limits or a complete external-PCM adapter.

Original reads occurred only inside standalone REA captures. Authored readers inspected exact Mach-O symbols or bounded address ranges and parsed packaged JavaScript. They did not load the addon, execute original JavaScript, load a model, capture audio, request permissions or change the shared REA target.

## Identity and evidence

All native observations apply to `kr-media-sp.node` SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. Accepted readers report that digest before and after inspection. JavaScript comes from ASAR SHA256 `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`, Bootstrap member SHA256 `bbaedd07bcd78d093f1011a41e3aeca92707c1f77fc7cca03305ffd4cd90cff0`.

The private results are under `evidence/model-probes/`:

| Result | Evidence | Scope |
| --- | --- | --- |
| `local-asr-result-strings-20261029-v1.result.json` | `ev_f6ebe8417519a9d191cf0293499be62a15512540faf79421272192fd73423c40` | Six exact serializer key strings |
| `local-asr-result-strings-20261029-v2.result.json` | `ev_8ea9aadd48d6df1f7c5f99bff17c8f6ca9095fc90a33fd1fb058994b8750bf79` | Exact KMSMultiStream vtable bytes |
| `local-asr-results-native-20261029-v1.result.json` | `ev_c76fdb7efff90498fb82f4ac74e82c21fc1d85ff4fdcf606beb4aae9131c0af5` | TSF registration, result copies, enqueue, callback and enum names |
| `local-asr-results-native-20261029-v2.result.json` | `ev_8f3ee94dc5434257c5d8bbfc929de54f5d8d25d6f0ae7b46c770629475bd770d` | TSF deleter, per-frame supplier and SDK result handler |
| `local-asr-results-native-20261029-v4.result.json` | `ev_598880dbb50f1ffeb6b08c47305547624c713c64aac8c52f98b3e95b70c02689` | Merged SDK result conversion and TSF creation wrapper |
| `local-asr-results-native-20261029-v5.result.json` | `ev_b2277596e2e192e4df50d49da89ad2f89dd221b93f3dcacdbbb805b61e24d8c4` | TSF creation wrapper continuation |
| `local-asr-results-native-20261029-v6.result.json` | `ev_285855cb65ee02e6c7f3e662dfbd6f7e42ce079c3806870af29345f8c8d757ed` | Exact `napi_create_threadsafe_function` argument join |
| `local-asr-results-native-20261029-v7.result.json` | `ev_7e91b398b2c7832cc9eab99bdacd62f7dce9ab123546ca8ab20d19f2dfdeb366` | Generic TSF JavaScript dispatch and null-environment branch |
| `local-asr-results-js-20261029-v1.result.json` | `ev_7c584558847befbb02172b8df046032fb7539df5cf5ad4f64e5de9b54bfb6ecc` | AsrService consumer and result lifecycle |

These captures exit zero, verify owned-process-group cleanup and remove their temporary roots. Native v2 additionally lists two platform-process environment observations as unverified; that limitation does not change its recorded owned-group outcome. The JavaScript capture marks cumulative rendered terminal frames truncated. All 203,105 raw terminal bytes were retained, including the complete requested decoded slice and final matching ASAR digest. It is not a whole-program or runtime coverage claim.

Native v3 is a retained failed lookup, `ev_e4f35a7027ceca9e707dbf66262536cd290553144e1f8999f36c83950ef8e74e`: a mistaken `0xc444` entry was not a symbol. It exited one without the final reader hash. V4 corrects this to the branch-derived exact entry `0xc440`; conclusions use the complete v4 record. No original runtime retry or process repair occurred.

## Exact result carrier

The native callback at `0x17e3c` constructs eight JavaScript arguments in this order:

```text
streamId,
wordsInbound, piiIndexesInbound,
wordsOutbound, piiIndexesOutbound,
speakersInbound, speakersOutbound,
resultType
```

The result object used by StreamManager preserves these six collection names and `resultType`, as documented in `live-asr-findings.md`. Direction remains part of the contract. A mixed recording cannot recover that distinction later.

The word serializer at `0x18108` visits 40-byte native tuples in vector order. It emits:

| JavaScript property | Native value |
| --- | --- |
| `start` | First Float32 |
| `end` | Second Float32 |
| `text` | UTF-16 string |
| `confidence` | Final Float32 |

The key addresses are `0xe843d3`, `0xe843d9`, `0xe8382a` and `0xe843dd`. The exact-string reader confirms their terminated bytes. The serializer does not sort words, rescale times, validate confidence bounds or expose a final-word flag.

The speaker serializer at `0x184f4` visits 64-byte tuples. It emits `id` from a native byte string, `start` and `end` from size_t values, and `embedding` as an ordinary JavaScript array of numbers converted from Float32. Key addresses are `0xe836af`, the shared start/end keys above, and `0xe843e8`. Embedding dimension and speaker-ID stability are not established. The serializer uses JavaScript Numbers for indexes; it does not establish safe-integer limits.

The PII serializer at `0x183c0` emits the size_t vector as JavaScript numbers. AsrService uses each PII index directly as an index into its corresponding directional word array. These are zero-based word indexes. They are not byte offsets or time intervals.

## Time and speaker index units

AsrService's `collectDiarizedData`, decoded offset 169,985, loops from each speaker's `start` through `end` inclusively and reads the directional word array at each index. Speaker spans therefore use inclusive zero-based word indexes. They do not carry seconds, despite sharing property names with words.

The same consumer passes a word's start to `secondsToTime(Math.ceil(start))`, rounds start/end to three decimal places, and stores word start times without a scale conversion. `buildPiiIntervals`, offset 117,066, subtracts `PII_AUDIO_PADDING_SEC` from word start and publishes `startSec`/`endSec`. Together these establish seconds as the consumer's word-time unit. Native serializers copy the floats without unit conversion.

The absolute time origin remains unresolved. This does not bind ASR seconds to CoreAudio host ticks, capture startup cropping or the saved recording's zero. An adapter needs an explicit source-frame-to-ASR-time join. Confidence is a copied SDK float, not proof of calibration or a guaranteed probability range.

## General and YieldWords

The native enum printer at `0xe2884` maps 0 to None, 1 to General and 2 to YieldWords. `BuildAsrResultFromMerged` at `0x1018bc`, instructions `0x101924..0x101938`, maps SDK type 1 to General, type 2 to YieldWords and other values to None.

`KMSMultiStream::YieldResult`, `0xc1bc4`, sets a flag at object offset `0xc1`. The per-frame supplier at `0xc3810` reads last-frame and yield-result flags. It returns last-frame in its first two bytes and yield-result in its third byte. The SDK result handler at `0xc3ca8` detects SDK type 2, logs a yield result and clears the captured yield flag before converting and forwarding the result. Yield is therefore a per-frame request/result path, not a synchronous transcript return from `YieldResult()`.

AsrService `onResultCallback`, offset 106,102, handles YieldWords separately. It can update intermediate language data, applies configured PII handling, calls `handleYieldResult` and returns. `handleYieldResult`, offset 150,746, assigns synthetic directional speakers and updates the active call's in-call transcript. `setTranscriptContent` replaces its current transcript content from that result rather than blindly appending every payload. A consumer must not assume every yield payload contains only new words.

General enters `callbackResultQueue` and `processResultCallback`. That path checks stream identity and processing/diarizing state, builds raw and diarized transcript data and advances completion state. None and other non-General values are skipped by this path. These are application lifecycle roles, not a generic `isFinal` boolean for arbitrary incremental text. The evidence does not prove that each General callback alone means every ASR and diarization task has finished.

## N-API ownership and shutdown

ASR configuration creates a ThreadSafeFunction with maximum queue size 0 and initial thread count 1. The callsite is `0xe898..0xe8a0`; wrappers at `0xc440`, `0x12208` and `0x12378` preserve these values into `napi_create_threadsafe_function`. Node-API defines zero as an unlimited queue. A new adapter must not claim that this vendor callback queue supplies bounded backpressure. [Node-API documentation](https://nodejs.org/api/n-api.html#asynchronous-thread-safe-function-calls) defines the queue and abort semantics; installed Node headers also establish nonblocking mode 0 and abort mode 1.

The native producer at `0x1750c` retains shared TSF ownership and copies the stream ID and ASRResult into the queued closure. At `0x176c0..0x176c4` it submits with nonblocking mode 0. If enqueue fails, it destroys the closure and frees its allocation. The inspected producer does not propagate that enqueue status as an ASR completion or retry result. No reliable delivery claim follows from returning to the caller.

`AddASRResultTSF` keeps a shared owner in a mutex-protected map. `RemoveASRResultTSF` erases the stream entry; RemoveAll clears map owners. Other copied closures can still retain shared ownership. When the final owner invokes `ThreadSafeFunctionDeleter` at `0x8fb8`, it calls `napi_release_threadsafe_function` with mode 1, then deletes the wrapper. Mode 1 is abort, not a synchronous drain acknowledgment. This does not establish that all queued JavaScript callbacks ran before StopASRProcessing returns.

The JavaScript invocation checks the addon's initialized flag and drops invocation when the addon is no longer initialized. That is a global lifecycle guard, not a per-stream completion barrier. An installed adapter still needs its own stream generation, explicit terminal-result policy and parent-owned shutdown deadline. Abort, callback silence, an SDK stop return and successful recognition are separate outcomes.

The generic TSF dispatch at `0x124e8` also returns directly when both the environment and JavaScript function are null, before calling its wrapped callback. This body does not free the data pointer on that branch. Therefore this investigation cannot claim that abort or environment teardown destroys every queued copied payload. An isolated worker's process exit remains distinct from clean callback draining. A direct SDK result handler should use its own bounded ownership protocol rather than inherit this queue behavior silently.

## Construction join and remaining boundary

The bounded vtable read confirms `0x1104628 + 0x18` contains `0xc17f4`, KMSMultiStream::ProcessAudioFrame. Adjacent slots point to CreateASRProcessor, YieldResult, StopProcessing and Close. This closes that dispatch identity for the feed worker; it does not make arbitrary C++ object construction safe.

Actionable result requirements are now exact names, directional collections, seconds for word times, inclusive word indexes for speaker spans, PII word indexes and separate General/YieldWords paths. Still unresolved are accepted collection/text/embedding bounds, confidence guarantees, full incremental replacement semantics, exact final-result multiplicity/order, SDK callback quiescence and the ASR-time origin relative to external capture. No installed provider was enabled or executed, and no alternative recognizer was substituted.
