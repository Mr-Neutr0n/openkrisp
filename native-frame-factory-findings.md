# Native frame factory construction

Static analysis establishes a C++ construction and ownership path for ordinary noise cancellation. It does not establish a safe C ABI or an executable device-free test harness. No original addon was loaded, initialized, or called.

## Identity and evidence

The selected installed artifact is `/Users/harikp/Applications/krisp.app/Contents/Resources/app.asar.unpacked/.vite/build/node_modules/kr-media-sp/build/Release/kr-media-sp.node`. Each new capture recorded the same SHA256 before and after static disassembly: `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`.

The existing `disassemble-exact-symbols.cjs` helper ran through `bin/rea capture-process`. It read and hashed the artifact, then executed Xcode's `llvm-objdump` for explicit symbols. Node ran this inspection helper, not the addon.

| Evidence | Selected scope |
| --- | --- |
| `ev_9d50689e7c21e8ee795702e6530ac10449eb05a44b7abd684e9ab88ecfff3dd9` | Retained current Mach-O inventory used to select names |
| `ev_3e5e72501abfba06515d44bbbf5c5564f972c47ba920c1571ecc427b1ef7dc6c` | Ordinary KMS NC caller, selected frame factory, SDK processor removal |
| `ev_ee0de6c7502f3081ea0caa2f0a308b20ce13f5b587f3ac1d12c685bc3ce03b0e` | Concrete processor constructor, SDK stream creation and selected SDK processor creation |
| `ev_5373dc2a13b8d8cfb6bf786f8cb81831bb0041c3ac170468ca6f670a339a570e` | Concrete processor destructor and registry removal |
| `ev_edbfb773ae319ad8c2b488172beb490adc7c5cf5828f592b10e88c9d718dadb9` | Coordinated exact vtable proof linking the ordinary addon stream slot to this KMS overload |

Scenarios and captures are under `evidence/model-probes/native-frame-{factory,construction,destruction}-disassembly.*`. The first capture is retained in `.result.toon`; extracted raw frames are `.txt`. The later captures are JSON with corresponding extracted `.result.txt`. These text files are derived reading aids, not separate Evidence. Raw PTY bytes were retained; cumulative rendered terminal frames exceeded their budget in the construction capture. Rendered-frame truncation does not remove its raw disassembly or final identity record. The retained Mach-O export inventory is not exhaustive (`exhaustive:false`, `total:null`). Negative symbol claims below are limited to these selected names and bodies.

All addresses below come from fresh exact-symbol disassembly on the bound digest. The nearby retained `KMSStream` C1 address `0xc771c` is not used to infer a constructor body or ABI here. `CreateNCProcessor` starts at `0xc7720` in the fresh capture.

## Observed construction path

The coordinated vtable capture binds KMSStream table `0x1104a28`, address point `0x1104a38`: slot `+0x10` resolves to ordinary `CreateNCProcessor` at `0xc7720`; slot `+0x18` resolves to the separate exclusive overload at `0xc89ac`. This confirms the ordinary addon bridge reaches the selected method.

The ordinary overload of `Krisp::MediaSP::KMSStream::CreateNCProcessor` at `0xc7720` takes a `std::wstring const&`, a `std::function` per-frame NC configuration supplier, and a `std::function` receiving `NoiseCancellation::ResultHandlerWithStats<float>::value_type const&`. At `0xc7ad4` it calls the SDK's float `createProcessor` overload with ordinary NC `Configuration`, `PerFrameConfigurationSupplier`, and `ResultHandlerWithStats<float>`.

That SDK method is at `0x1d6800`. It calls the matching `KRISP::createFrameProcessor` template at `0x1d688c`, then registers the resulting shared pointer under an SDK mutex at SDK offset `0x98` (`0x1d68ec` onward). It returns the processor's object pointer as the integer handle after temporary shared-pointer releases (`0x1d6954` to `0x1d6994`). This handle must not be treated as a separately owned allocation.

The selected frame factory is at `0x1d6a48`. Its demangled type is structurally:

```cpp
std::shared_ptr<FrameProcessorWithStreamDescriptor<float, Audio::StreamDescriptor>>
createFrameProcessor(
    SdkConfig const&,
    Audio::StreamDescriptor const&,
    Audio::NoiseCancellation::Configuration const&,
    std::shared_ptr<Audio::NoiseCancellation::PerFrameConfigurationSupplier>,
    std::shared_ptr<Audio::NoiseCancellation::ResultHandlerWithStats<float>>);
```

The factory allocates `0xd0` bytes for `Audio::NoiseCancellation::Processor<float, ResultHandlerWithStats<float>>`, calls its constructor at `0x1d6ac4`, allocates a `0x20`-byte libc++ shared ownership control block, and writes the object/control-block pair through the arm64 indirect-result register `x8` (`0x1d6ac8` to `0x1d6ae8`). Supplier and handler are two-word shared-pointer objects, with reference-count operations and unwind cleanup. A plain function pointer or zero-filled callback structure is not this contract. The selected factory body does not consume its incoming `SdkConfig` argument before replacing `x0` for allocation; this does not prove that SDK initialization is globally optional.

## Configuration and lifetime observations

The concrete constructor starts at `0x1dac98`. It installs a vtable address point at `0x110ee38`, copies the result handler shared-pointer pair into processor offsets `0x30/0x38`, and copies the supplier pair into `0x40/0x48`, incrementing their ownership counts (`0x1dace4` to `0x1dad10`). It also stores the incoming descriptor address at processor offset `0x28`. This address store alone does not establish a safe external descriptor lifetime. The SDK wrapper passes a local eight-byte descriptor copy to the factory, so later uses of that stored field need to be resolved before proposing a caller-owned descriptor wrapper.

The ordinary configuration is a C++ object, not JSON. The KMS caller copies a model path as `std::wstring` at configuration offset `0x08` (`0xc794c` onward). The processor constructor tests pointer/length fields at configuration offsets `0x20/0x28` and uses `NcConfigLoader(void const*, size_t)` when both are nonzero, otherwise `NcConfigLoader(std::wstring const&)` at configuration offset `0x08` (`0x1dadb0` to `0x1dadf4`). These are observed offsets, not a complete declaration suitable for allocating the configuration.

Before that branch the constructor calls `readMainKefConfig(Configuration const&)`. Its returned flag can select a separate `DfProcessor` allocation and constructor (`0x1dad74` to `0x1dad9c`). The other branch reads NC/inference configurations, computes sample counts and delay, and allocates processing/resampling state. Model loading and processing setup therefore occur during construction. No analysis here proves which branch a particular supplied model takes.

`SDK::createStream<float, StreamDescriptor>` at `0x1b49c8` validates the descriptor, allocates a `0x28`-byte stream processor registry, copies the descriptor's eight bytes into that registry at offset `0x20`, and transfers its unique ownership into an SDK vector under a mutex (`0x1b4a04` to `0x1b4a48`). The wrapper's stream value is not evidence of independent ownership after SDK destruction.

## Destruction

The selected SDK `destroyProcessor<float, StreamDescriptor>` method at `0x1b4c0c` takes the SDK receiver, a stream value and an integer processor handle. It locks the SDK mutex at `+0x98`, removes the handle from the stream registry, and unlocks. The called removal body starts at `0x1b45b4`; disassembly labels it with an int16 specialization. The fresh float method explicitly calls that address, so the label must not be used to infer that the public float method accepts int16 frames. The removal body manipulates shared ownership and has an exception path. It is not a generic `free(handle)` operation.

The concrete ordinary float processor destructor is at `0x1db8b0`. It destroys an optional `DfProcessor`, resamplers, and `MainCleaner`, releases supplier and result-handler shared ownership, and releases internal buffers. The shared-pointer control block uses virtual destruction on its last-owner path. No standalone generic `destroyFrameProcessor` C entry point was established in this bounded inspection. A caller using the direct shared-pointer factory would need its exact libc++ ownership/destructor ABI; a caller using the SDK registry must use the SDK's matching removal/stream lifetime contract.

## Remaining gaps and next action

A device-free path is plausible because this selected construction path operates on descriptors, model configuration, callbacks, and frame processor objects. Static plausibility is not a successful processing test. Construction may read models and allocate inference state; this inspection did not run it.

Before any invocation, recover only the remaining ordinary-path contracts: the validated `StreamDescriptor` fields/enums, complete NC configuration initialization, concrete supplier/result-handler vtables, process-frame arguments/result timing, and ownership through stream close and SDK destruction. Resolve the processor's descriptor-address field use instead of guessing its lifetime. The actual addon ordinary-NC interface slot is now bound to this KMS overload by the coordinated vtable capture. The RTExclusive overload is a separate branch and is outside this report.

The minimal next action is static verification of those exact call edges and type layouts, then a separately reviewed ABI-safe harness design. Do not call these templates through a guessed C signature, construct zero-filled native objects, initialize the addon, or open an audio device to test this hypothesis.
