# Direct ordinary NC adapter design

Static evidence supports a finite, digest-specific direct-factory probe without reconstructing KMSStream or SdkConfig. The selected factory exports a callable C++ symbol, accepts typed callback shared pointers, and returns its own shared pointer. Its first argument is unused. A deliberate machine-ABI adapter can represent that argument as `const void*` pointing to stable opaque storage. This is not an SDK header or a portable C++ function declaration.

No addon load, original function call, model construction, audio, network operation or administrator action occurred in this investigation. The proposed probe remains unexecuted.

## Identity and export

Target: `/Users/harikp/Applications/krisp.app/Contents/Resources/app.asar.unpacked/.vite/build/node_modules/kr-media-sp/build/Release/kr-media-sp.node`.

SHA256: `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. Addresses below are unslid and apply only to this identity.

New static REA Evidence `ev_cf07c284834b262063c868d175d389b8751e3fc2bb4410df8a2f060adf6dc56f` records the Mach-O export trie, focused defined-symbol selection and load dependencies. Pre/post hashes match. Capture exited zero. Files are `evidence/model-probes/direct-adapter-export-init-v1.scenario.json` and `.result.json`; the helper is `inspect-direct-adapter-exports-v1.cjs`. It executed static LLVM tools only.

The export trie contains this exact factory at `0x1d6a48`:

```text
__ZN5KRISP20createFrameProcessorIfNS_5Audio16StreamDescriptorENS1_17NoiseCancellation13ConfigurationENS3_29PerFrameConfigurationSupplierENS3_22ResultHandlerWithStatsIfEEEENSt3__110shared_ptrINS_34FrameProcessorWithStreamDescriptorIT_T0_EEEERKNS_9SdkConfigERKSC_RKT1_NS9_IT2_EENS9_IT3_EE
```

Darwin `dlsym` receives the spelling with one initial underscore removed, beginning `_ZN5KRISP20createFrameProcessor`. The export proof goes beyond an `nm T` listing. It does not prove a future `dlopen` or `dlsym` succeeds in an isolated Node host.

## Factory ABI and the unused argument

The recovered source-shaped signature is:

```cpp
std::shared_ptr<KRISP::FrameProcessorWithStreamDescriptor<
    float, KRISP::Audio::StreamDescriptor>>
createFrameProcessor(
    KRISP::SdkConfig const&,
    KRISP::Audio::StreamDescriptor const&,
    KRISP::Audio::NoiseCancellation::Configuration const&,
    std::shared_ptr<KRISP::Audio::NoiseCancellation::PerFrameConfigurationSupplier>,
    std::shared_ptr<KRISP::Audio::NoiseCancellation::ResultHandlerWithStats<float>>);
```

Factory Evidence `ev_3e5e72501abfba06515d44bbbf5c5564f972c47ba920c1571ecc427b1ef7dc6c` establishes the body and call. Constructor Evidence `ev_ee0de6c7502f3081ea0caa2f0a308b20ce13f5b587f3ac1d12c685bc3ce03b0e` establishes retained ownership.

| ARM64 location | Meaning |
| --- | --- |
| `x0` | Address supplied for SdkConfig const reference. The selected body never reads or forwards it before replacing `w0` with an allocation size. |
| `x1` | Descriptor address. |
| `x2` | NC configuration address. |
| `x3`, `x4` | Addresses of the nontrivial by-value shared-pointer parameter objects. These are not raw callback pointers. |
| `x8` | Compiler-managed indirect result storage for the nontrivial shared-pointer return. |

A prospective adapter typedef can replace only argument zero with `const void*`. All remaining arguments and the return must keep their C++ types:

```cpp
using FactoryABI = std::shared_ptr<ProcessorView> (*)(
    const void*, const Descriptor&, const Configuration&,
    std::shared_ptr<Supplier>, std::shared_ptr<Handler>);
alignas(16) static const std::byte unusedSdkToken[16]{};
// After a reviewed symbol lookup:
// auto processor = factory(unusedSdkToken, descriptor, configuration,
//                          supplier, handler);
```

The aliases here refer to the reviewed target-specific declarations, not arbitrary replacement types. This is a lowered foreign-ABI call. Calling through a different C++ function type is not an ISO C++ source-compatibility claim. The justification is the complete selected machine body and its unused first register, bounded to this digest. A stable aligned nonnull token avoids inventing a full SdkConfig object. Null is unnecessary. Do not extend this substitution to other overloads or future binaries.

The factory allocates a `0xd0` processor, calls its constructor at `0x1d6ac4`, and allocates an original `0x20` libc++ control block. It writes the object/control pair to the `x8` result. Let the compiler generate shared-pointer parameter and return ABI. A raw two-word C return is incorrect.

Keep the returned original control block. Do not delete the processor pointer, free it, or wrap it in a second owning shared pointer. Reset the returned shared pointer before unloading the image. Callback code and callback context must remain alive through processor destruction.

## Initialization and configuration

No SdkConfig read, SDK receiver, registry lookup or SDK initialization call occurs on this selected direct-factory path. The concrete constructor directly reads model configuration and creates the inference components. It calls `readMainKefConfig` at `0x1dad3c`, creates an optional Df processor, constructs `NcConfigLoader` from memory or a wide path at `0x1dadd4` or `0x1dadec`, reads it at `0x1dadf4`, and creates MainCleaner at `0x1daecc`.

This supports proceeding without inventing an SDKInitialize prerequisite. It does not prove model construction succeeds or that loader/module initializers have no effects. The focused symbol selection found only base flush/finalize/destructors, not a named SdkConfig constructor or initialization function. That selection is not whole-program absence proof.

The observed ordinary configuration has sampling rate at offset 0, a 24-byte `std::wstring` at 8, model-data pointer at 32, data length at 40, and a one-byte flag at 48. The ordinary path uses a wide model path, null model-data pointer, zero length and zero flag. The flag's source name remains unknown. Root's separate host layout check gives a natural size of 56 and alignment 8. This is host-layout agreement, not an official vendor declaration. See `native-nc-callback-construction-findings.md`.

The descriptor has two 32-bit fields, duration in milliseconds and sample rate. Ten milliseconds at 48 kHz means 480 float elements. It has no channel field. Keep the descriptor at a stable address through processor destruction. Keep the configuration path valid through factory construction. Retained lifetime analysis is in `native-descriptor-lifetime-findings.md`.

## Processor virtual calls and enable state

The concrete ordinary vtable address point is `0x110ee38`. Evidence `ev_b5ff5d37ae40adbd072b79db14a8775cbf70107d02a6d531b033fb392386e791` and `ev_d783a4e17eacc0f3caff99ad8b6a5d79588d1dea4a892a1a135cb0bafb4efcf4` establish these slots:

| Byte offset | Entry |
| --- | --- |
| 0 | Complete destructor, `0x1db298` |
| 8 | Deleting destructor, `0x1db29c` |
| 16 | flush, no-op |
| 24 | finalize, no-op |
| 32 | process, `0x1db2b0` |
| 40 | updateStreamDescriptor, no-op |

A minimal consumer declaration places its virtual destructor first, followed by `flush`, `finalize`, `process(const std::vector<float>&)` and `updateStreamDescriptor(const Descriptor&)`. It is a virtual-call view only. Do not instantiate it or treat its compiler size as the vendor processor size. There is no enable-method slot in this table.

The constructor writes zero to processor state at offset 8. SDK `Stream::pushFrame` checks state equals one before dispatch, as shown in `ev_9a6f41b241e457bb14648998704e2cd35b838746812f87642b7804ff32f184e4`. Direct concrete `process` does not read that field. It invokes the supplier and processes the frame, as shown in `ev_6a9010dfcf231d1025f02fc2bd4db5320fdf395fbb31c04cdcdfd3ae673bf3df`.

Thus this proposed direct virtual call needs no SDK registry enable or raw state-field patch. That conclusion applies to this concrete implementation and direct entry only. Its no-op flush/finalize do not establish a tail-drain operation.

## Callbacks and ownership

Use the supplier and result declarations reviewed in `native-supplier-value-findings.md` and `native-result-value-findings.md`. Their static evidence now establishes:

- Supplier returns an eight-byte aggregate in `x0`: four meaningful one-byte logical flags, then Float32 level. Use canonical zero/one flags and finite level 0 through 100. The ordinary supplier returns flags `0,0,0,1`.
- Result payload has a 40-byte opaque prefix followed by the target libc++ `std::vector<float>`, giving an observed 64-byte extent. Read samples only and copy them before callback return.
- Callback bases put the method first, then complete and deleting destructors. Supplier method is const; result handler takes mutable payload reference, which the collector should treat as read-only.

Callback slot order differs from the processor's destructor-first interface. Do not reuse one class pattern for both. Preserve shared-pointer parameter ownership and allow original processor destruction to release its retained callback references. Do not throw from callbacks. A collector should record bounded failure state rather than let allocation or validation exceptions escape into vendor frames.

The KMS alternative constructs std::function wrappers and captures a pointer to KMS-owned FrameProcessingChain state. It requires a longer ownership reconstruction. The direct factory needs neither that chain nor the KMS/media graph for the observed concrete process call.

## Finite next verification

1. Compile a separate synthetic factory library with a source-shaped reference first argument that is deliberately unused, typed shared-pointer parameters and shared-pointer return. Call it through the proposed lowered adapter. Verify callback slots, `x8` return, copied samples and destructor/control-block counters. Inspect the synthetic assembly to confirm the intended unused-argument condition. This establishes host compatibility only.
2. Compile the typed Node adapter with reviewed supplier/result/configuration declarations and layout assertions. Run host-only tests without loading the original addon.
3. Review the isolated Node loader and network-denial setup before any original load. The image links several bundled libraries, including daily, socket and curl wrappers. Loading dependencies can run initializers; static dependency presence does not prove network/audio activity. Dependency and NAPI resolution in this new adapter remain untested; earlier addon initialization probes do not verify this adapter.
4. After these checks, run a serial bounded frame probe with exact 480-element normalized Float32 frames and a user-selected model. Copy synchronous output before return, measure callback count, frame size and finite values, and release all vendor ownership before unloading. Callback success alone does not prove suppression quality or Krisp parity.

No complete SdkConfig reconstruction is needed solely for its proven unused argument. Remaining runtime questions are loader/dependency resolution, actual model construction, compiler interoperability with the reviewed callback/value mirrors, exception behavior, and observed finite processing. This report does not claim those tests passed.
