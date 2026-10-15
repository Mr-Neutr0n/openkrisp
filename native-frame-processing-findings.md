# Native frame wrapper contract

Static REA observations, 2026-10-15. No addon execution, processing call, audio, device, account or administration action occurred. The analysis does not provide a callable C++ ABI by itself.

## Identity and evidence

REA `capture-process` ran the existing exact-symbol disassembly helper only. Both captures exited 0 and recorded identical pre/post addon SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`.

- Wrapper Evidence `ev_a131a8e23f52b89b9b67275a74a3539fb28d607f62944959896dc19addd9feef`: `evidence/model-probes/native-frame-wrapper-disassembly.result.json`, with its scenario alongside it. Exact methods: `KMSStream::ProcessAudioFrame(MediaFrameBuffer const&, bool)` at `0xcd3ec`; `KMSStream::ProcessFrameBuffer(std::vector<float> const&, bool)` at `0xcd55c`.
- Caller/layout Evidence `ev_f48650f627057b3eea987b64240b2d384d03bf63a03ec3bcd9bbcca40499e412`: `evidence/model-probes/native-frame-caller-disassembly.result.json`, with its scenario alongside it. Exact methods: `FrameProcessingChain::ProcessData(MediaFrameBuffer const&)` at `0x3ef18`; `NoiseCanceller::ProcessFrameBuffer(MediaFrameBuffer const&)` at `0xfc400`.

Addresses are version-bound and require identity revalidation before reuse. Factory/construction is a separate investigation.

## Input frame and processing call

`MediaFrameBuffer` is observed as a 16-byte view: a 64-bit byte count at offset 0 and data pointer at offset 8. `KMSStream::ProcessAudioFrame` loads that pair at `0xcd45c`. Optional preprocessing through the object at `this+0x60` calls `FrameProcessingChain::ProcessData` at `0xcd41c`; a nonzero 16-bit status at returned offset `0x10` logs failure and returns false. On success it takes the same count/pointer pair from the chain result.

The wrapper allocates an owned local `std::vector<float>` and copies `byteCount & ~3` bytes from the view at `0xcd48c` through `0xcd4ac`. Counts below four bytes yield an empty vector. There is no Float32 conversion, scaling or endian conversion here: the bytes are interpreted as float elements by the next call. This supports native Float32 input for this wrapper, but does not recover an amplitude range, channel order or sample rate. Misaligned byte counts are truncated, not validated as an error by this wrapper.

`ProcessFrameBuffer` stores the bool argument at `this+0x58` (`0xcd574`), obtains the embedded SDK stream at `this+0x50` (`0xcd578`), and calls `KRISP::SDK::Stream<float, KRISP::Audio::StreamDescriptor>::pushFrame(std::vector<float> const&)` at `0xcd57c`. The bool is named `isLastFrame` in exception diagnostics. It is not an additional argument to this SDK push call; its use elsewhere is not recovered here. No timestamp is read from the observed 16-byte input view.

This wrapper does not enforce an exact frame size or recover rate/channels. Those values come from stream construction and SDK validation. No particular 10 ms duration, 320/480 sample count, mono requirement or EOF flush recipe should be inferred from these methods alone.

## Return, output and ownership

Both KMS methods return a boolean, not processed samples. `ProcessFrameBuffer` returns true after a normal SDK `pushFrame` return (`0xcd580`); it does not inspect an output vector or return processed-frame ownership. `ProcessAudioFrame` forwards that bool and frees its temporary input vector before return (`0xcd4c0` through `0xcd4dc`). This proves the wrapper's input-copy lifetime through the synchronous call, not whether the SDK copies or retains input internally. Output must be recovered through the stream's configured result handling, not by treating x0 as an audio pointer.

The actual NoiseCanceller caller reinforces synchronous expectations but does not establish the full callback contract. It resets an internal output-vector end pointer (`this+0x240`) to its begin pointer (`this+0x238`) at `0xfc670` through `0xfc674`, calls its stream's virtual method with the input view and false (`0xfc678` through `0xfc688`), then immediately compares output byte length with input byte length (`0xfc690` through `0xfc6a8`). A matching length returns a view into the internal processed buffer. Output storage is therefore processor-owned at this caller; no transfer or lifetime extension is performed in the examined return path. The callback that fills it, exact ownership duration and cross-thread synchronization remain unresolved. Do not retain that returned pointer across another call without additional evidence.

The caller's aggregate return layout differs from `MediaFrameBuffer`: it writes a 16-bit status at result offset 0, then count/pointer at offsets 8 and 16 (`0xfc7a8` through `0xfc7ac`). `FrameProcessingChain::ProcessData` instead returns count/pointer at offsets 0 and 8 plus status at offset 16 (`0x3f0e4` through `0x3f0ec`). They must not be conflated with one another or with an SDK result-handler type. These observations do not establish source-level type names or complete C++ declaration layouts.

## Failures and bypass behavior

`FrameProcessingChain::ProcessData` rejects an uninitialized chain and zero count or null pointer (`0x3ef30` through `0x3ef44`), returning a zero view with status 3. It runs each transform through a virtual call and returns a zero view/status 1 on a transform error (`0x3f0b0` through `0x3f0cc`, `0x3f2c4` through `0x3f2cc`). Success returns the last transform's view/status 0. No output buffer is allocated by this method itself.

`KMSStream::ProcessFrameBuffer` has distinct diagnostic catch paths for `KmsAssertException`, `KmsInvalidInputFrameException`, `KmsInvalidPerFrameConfiguration`, `KmsFrameProcessingException`, and `std::exception`. These paths log frame element count and `isLastFrame`, end the catch, and return false (`0xcd9b0` through `0xcd9c4`). Unmatched exceptions unwind at `0xcda34`; this is not a general no-throw C ABI. A false return must not be treated as valid silence or successful inference.

NoiseCanceller calls `Processor::FrameProcessingFailed` and returns status 1 with the original input view if its stream processing returns false (`0xfc734` through `0xfc754`). Inactive/no-processing paths can return the original input with status 0. A wrong processed-size diagnostic selects the original input pointer before returning status 0 (`0xfc790`), rather than exposing a mismatched processed buffer. Therefore a success-like result or same-sized output alone does not prove NC actually ran; a future probe needs observed processor activation and meaningful output comparisons.

## Remaining prerequisites

A valid device-free native probe still needs the SDK/KMS stream factory contract, ABI-correct configuration and callbacks, exact required frame size/rate/channels, result-handler payload and lifetime, final-frame/drain behavior and teardown. These methods establish a real native frame-push path beneath the graph, so HAL is not proven to be an intrinsic SDK requirement. They do not authorize constructing private objects from guessed offsets or bypassing initialization. No shared model contract, independent source or ledger was changed.

## Ordinary NC result callback, 2026-10-15

New REA Evidence `ev_40533b8680448f249894745d350085d236f7adb2807c02890d3d0a29c2dee276`, `evidence/model-probes/nc-result-callback.result.json`, disassembles only the selected ordinary-NC callback at `0xfee54`. Pre/post addon SHA256 remained `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`, capture exit 0. NC-bridge worker's exact-symbol Evidence `ev_7f1381461f01accde7a825979eddfff46baa4dc724afec191c41bb5ea5b6b18f` identifies the callback as the `std::__function::__func` invocation for `NoiseCanceller::CreateNCStream` lambda `$_1`, taking `NoiseCancellation::ResultHandlerWithStats<float>::value_type const&`. Its wrapper address point is `0x1106dd8`; RTExclusive lambda `$_3` is separate and was not analyzed here.

The exact selected symbol is:

```text
__ZNSt3__110__function6__funcIZN5Krisp7MediaSP14NoiseCanceller14CreateNCStreamERKNS3_15NCConfigurationERKNS_12basic_stringIcNS_11char_traitsIcEENS_9allocatorIcEEEEE3$_1NSB_ISG_EEFvRKN5KRISP5Audio17NoiseCancellation22ResultHandlerWithStatsIfE10value_typeEEEclESP_
```

Observed callback contract:

- `0xfee54` loads the captured NoiseCanceller pointer from closure offset 8. This is a raw captured pointer; the callback itself does not acquire shared ownership of that object. Closure and object lifetime must be established by construction/teardown evidence.
- `0xfee5c` through `0xfee68` copies 40 bytes from payload offsets 0 through `0x27` into processor offsets `0x210` through `0x237`. This is the stats/header portion of the selected stats-bearing payload; individual field meanings are not recovered.
- `0xfee74` reads float-vector begin/end pointers at payload offsets `0x28` and `0x30`. `0xfee78` through `0xfee7c` computes element count as `(end - begin) / 4`. It passes the vector at NoiseCanceller offset `0x238` to libc++ `vector<float>::__assign_with_size` at `0xfee88`, with the payload begin/end range. This copies samples into processor-owned storage; it does not return or retain the payload sample pointer. The callback returns void.
- The short method contains no queue submission, worker creation, lock or thread switch. Sample copy is completed inline in the callback's invoking thread. This does not identify that thread or prove SDK result dispatch always finishes before `pushFrame` returns.

Combined with the previously observed immediate output-size check after stream processing, this establishes a synchronous-delivery expectation in the NoiseCanceller wrapper. It does not establish a whole-SDK scheduling guarantee, callback concurrency contract or safe shared use of a stream across threads. Until exact SDK dispatch is recovered, a probe must not assume that the borrowed processed-buffer view survives another processing call or that a raw captured NoiseCanceller remains alive after stream teardown. Payload vector ownership before callback, callback invocation count, empty-frame/end-of-stream behavior, callback exceptions and final drain remain unresolved. No SDK scheduler or runtime was executed or broadly analyzed.

The small selection capture `ev_b953e4aa894116937b961394cba3ece5a6c14e09c8b992005582acbd94995f10`, `evidence/model-probes/nc-callback-selection.result.json`, also verifies `CreateAudioStreams` delegates first to `CreateNCStream` and then to `CreateEnergyStream`, with cleanup on failure. It supplies no further result-dispatch guarantee.
