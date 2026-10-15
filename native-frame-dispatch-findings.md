# Ordinary NC frame dispatch

Static REA investigation, 2026-10-15. No addon execution, object construction, inference call, audio, capture, administration or network operation occurred. This report follows selected frame methods only; factory/lifetime and stream-close investigations are separate.

## New evidence and identity

Each REA capture used a declared read-only helper, exited 0, and recorded unchanged pre/post addon SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`:

| Evidence ID | Retained capture | Scope |
| --- | --- | --- |
| `ev_9a6f41b241e457bb14648998704e2cd35b838746812f87642b7804ff32f184e4` | `evidence/model-probes/dispatch-pushframe-20261015.result.json` | Float SDK stream push method |
| `ev_b5ff5d37ae40adbd072b79db14a8775cbf70107d02a6d531b033fb392386e791` | `evidence/model-probes/dispatch-vtable-20261015.result.json` | Exact ordinary NC processor vtable |
| `ev_6a9010dfcf231d1025f02fc2bd4db5320fdf395fbb31c04cdcdfd3ae673bf3df` | `evidence/model-probes/dispatch-nc-process-20261015.result.json` | Ordinary float stats-bearing NC processor method |
| `ev_4378661bdc5cd8515fcd8b978d327e5ba32c66e0fd163f50886b8406dfbaa334` | `evidence/model-probes/dispatch-frame-adapters-20261015.result.json` | Selected DF processing and common audio adapters |

Each scenario is saved beside its result. Raw captured frames hold the retained static output; this is process-capture evidence of disassembly, not format-aware recovery of C++ declarations. Current method names were selected from retained symbol records, including `ev_5d63bf20292be743ed5cd241986aac90c4ea9658ad983e3d811c2c4e2df21a30`. Addresses are identity-bound.

## Dispatch and callback timing

`SDK::Stream<float, Audio::StreamDescriptor>::pushFrame(vector<float> const&)` at `0x1b48f4` walks the stream's shared processor list. It retains each processor's shared owner for the call, checks processor state at object offset 8 equals 1, and calls vtable slot `+0x20` inline at `0x1b495c`. It then releases that temporary owner and continues. Empty lists or inactive processors produce no processor call. This method creates no worker, queue or deferred task.

The ordinary stats-bearing NC processor vtable begins at `0x110ee28`, address point `0x110ee38`. Its slot `+0x20`, table address `0x110ee58`, points to `0x1db2b0`: `NoiseCancellation::Processor<float, ResultHandlerWithStats<float>>::process(vector<float> const&)`.

This selected `process` method performs processing and directly invokes the stored result handler before returning. The DF branch calls result-handler vtable slot 0 at `0x1db53c`; the other branch calls it at `0x1db690`. Both pass the address of a local stats-plus-vector payload and free its vector after callback return at `0x1db6b4` through `0x1db6c0`. There is no asynchronous dispatch at these call sites. Combined with the callback body already recovered in `native-frame-processing-findings.md` (Evidence `ev_40533b8680448f249894745d350085d236f7adb2807c02890d3d0a29c2dee276`), the selected active ordinary NC path copies samples into NoiseCanceller-owned storage before this `pushFrame` call returns normally. Its callback runs on the caller's thread in this call chain.

This establishes selected-path synchronous dispatch, not global thread safety or every SDK path. Shared stream-list mutation, simultaneous push calls, callback reentrancy and processor teardown synchronization were not analyzed. An exception can interrupt the call before callback completion. A future probe must verify active processor registration and callback count; a normal empty/inactive stream push is not inference proof.

## Input validation and scaling

The processor's byte flag at `this+0xc0` chooses two implementations. Which branch the selected installed KEF selects is not established by these frame methods.

- MainCleaner branch: `0x1db55c` through `0x1db56c` compares vector element count `(end-begin)/4` with cached expected count at processor offset `0x58`. A mismatch throws `KmsInvalidParameterException` with “input size must be” diagnostic at `0x1db6e8` through `0x1db754`. It runs `AudioPreparer::process`, `MainCleaner::cleanNoise`, then `AudioFinalizer::process`. An empty optional cleaner result throws `bad_optional_access` at `0x1db75c`; it is not normal EOF.
- DF branch: the outer processor copies Float32 input and multiplies by exactly 32768 (`0x47000000`) before `DfProcessor::process` at `0x1db3e8`. After processing it divides by 32768 (`0x38000000`) and clamps finite ordered outputs to [-1,1] before callback. `DfProcessor::process` at `0x1cae08` separately checks input float count against its own cached count at offset `0x98` (`0x1cae30` through `0x1cae40`). A mismatch throws “DfProcessor::process(): Invalid frame size.”

`AudioPreparer<vector<float>>::process` at `0x1d9750` copies input, resamples, scales by 32768 and clamps to [-32768,32767]. `AudioFinalizer<vector<float>>::process` at `0x1d9900` resamples output and scales/clamps back to normalized Float32. Resampler initialization, exact rates/channels and numerical filter delay are not recovered in these bodies. These paths support normalized Float32 external samples; they do not prove handling of NaNs/infinities or a complete multichannel order contract. Exact expected frame counts must come from validated construction, not guessed callback sizes.

## Buffering and finite-input limits

DF processing retains state across calls. It resamples input at `0x1cae58`, appends into an input queue referenced by `this+0xf8` (`0x1caec0` through `0x1caf20`), processes available model windows through preprocessor/inference/postprocessor calls, and uses a separate output queue referenced by `this+0x100`. It checks available output against a fixed requested count from `this+0xc0` at `0x1cb790` through `0x1cb7ac`, copies/advances that queue, then output-resamples at `0x1cba4c`. These are real buffering boundaries; callback synchrony does not imply zero algorithmic delay or that every output sample corresponds to the current input frame alone. Queue initialization, priming counts, window/hop sizes and exact retained tail are unresolved.

Neither SDK `pushFrame` nor the selected processor `process` accepts an EOF flag. Their input argument is only the float vector. The wrapper's separately observed `isLastFrame` byte is not passed through this SDK method. There is no special final-short-frame or empty-frame drain path in these selected methods: both processing branches require their cached exact input count. No claim is made that stream close drains buffers. MainCleaner and resampler internal buffering were not expanded in this task.

## Practical test contract and remaining blockers

A future finite synthetic test can use serial, exact-sized Float32 pushes with a validated active ordinary processor and a synchronous result collector that copies callback samples before return. It can verify callback count, output sizes, finite samples and NC-on/off differences without a HAL source. That is now supported by the selected dispatch evidence, rather than export-name inference. It still requires ABI-correct factory/configuration/lifetime work from the separate investigation and an observed successful run.

Complete file-to-file equivalence remains unproven. A probe must record any deliberate whole-frame padding separately and retain original input length; padding is an independent bounded test policy, not recovered EOF semantics. Do not assume an empty frame flushes the stream, that close emits delayed samples, or that trimming a guessed delay preserves speech. End-to-end tail preservation and algorithmic latency remain acceptance gaps until a real supported drain/reset contract or measured bounded behavior establishes them. No previous findings, shared contract, independent source or parity ledger was edited.
