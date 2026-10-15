# Ordinary NC configuration and callback construction

The existing KMS wrapper constructs the concrete virtual supplier and result-handler objects itself. A caller of that wrapper would supply typed libc++ `std::function` objects, not virtual-class instances. This removes one reconstruction problem but adds the KMS object, postprocessing-chain lifetime and libc++ callable ABI. The direct frame factory remains the shorter candidate for a finite future C++ test if its abstract callback types can be declared correctly. Neither route is established as safe to invoke yet.

## Identity and evidence

The selected installed ARM64 addon remains SHA-256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. New captures recorded matching hashes before and after static reads. All addresses are unslid static addresses for that digest.

| Evidence | Capture and scope |
| --- | --- |
| `ev_348793f2ef28896c10a9098f4722a395a1386442d256cb83b3da4896b47ca645` | `evidence/model-probes/native-nc-callback-construction-v1.result.json`: fresh ordinary CreateNCProcessor, KMS constructor, concrete supplier/result methods and destructors |
| `ev_e8df10ca68a4399f9815f8a771bcd23f89979cf80261f32ca0cdc15cbf5b267b` | `evidence/model-probes/native-nc-callback-vtables-v2.result.json`: exact concrete wrapper table words mapped to current symbols |
| `ev_ee0de6c7502f3081ea0caa2f0a308b20ce13f5b587f3ac1d12c685bc3ce03b0e` | Existing same-digest processor construction and configuration consumers |
| `ev_1038c9b008c82aa2a695355c281073d091df676b98d03f584bd75c88bc17740f` | Existing same-digest ordinary NoiseCanceller supplier invoke body |

The new captures run the lab's static inspection helpers through REA capture-process. Those helpers execute Xcode LLVM inspection tools and read the artifact. They never load the addon or call its native functions. Both successful captures exit zero and retain all raw PTY bytes, including final identity checks. Rendered terminal histories exceed their budgets; derived `.result.txt` files concatenate the complete raw frames. Owned process groups report verified cleanup.

A first table-reader attempt, `native-nc-callback-vtables-v1`, exited on a helper JavaScript syntax error before reading the target. Its failed capture is retained separately and supports no target claim. Version 2 corrects that helper and supplies the table evidence above.

## Complete observed ordinary configuration initialization

The ordinary `KMSStream::CreateNCProcessor` starts at `0xc7720`. Its inputs, as named in the mangled symbol, are a `std::__1::wstring const&`, a `std::__1::function<NoiseCancellation::PerFrameConfigurationSupplier::value_type()> const&`, and a `std::__1::function<void(NoiseCancellation::ResultHandlerWithStats<float>::value_type const&)> const&`. The latter two are caller-supplied function objects.

The method constructs its ordinary SDK `NoiseCancellation::Configuration` at stack address `sp+0xb0`. These are its observed meaningful field writes:

| Relative configuration offset | Storage/type evidence | Value initialized by the ordinary wrapper |
| --- | --- | --- |
| `+0x00` | 32-bit scalar originating in the typed `Audio::SamplingRate` constructor argument | KMS member `+0x48`, copied at `0xc7944` through `0xc7948` |
| `+0x08` through `+0x1f` | `std::__1::basic_string<wchar_t>` object, 24 bytes in this build | A copy of the supplied model path. Inline string fields copy directly; external strings use `__init_copy_ctor_external` at `0xc7974` |
| `+0x20` | Pointer, consumed as `void const*` by the model-buffer loader | Null, from `stp xzr,xzr` at `0xc7978` |
| `+0x28` | Length, consumed as `size_t` by the model-buffer loader | Zero, same instruction |
| `+0x30` | One-byte flag | Zero at `0xc797c` |

This is a file-path configuration, not an in-memory model configuration. The existing processor constructor reads the pointer/length pair at `+0x20/+0x28` and selects the buffer loader only when both are nonzero; otherwise it uses the path at `+0x08`. That constructor copies the byte at `+0x30` into NC executable-network configuration field `+0x48` at `0x1daea4` through `0x1daea8`. The flag's source-level name and full semantics are not established. It must not be renamed GPU, acceleration or another guessed option.

The SamplingRate provenance is explicit: KMS constructor `0xc7340` receives `Audio::SamplingRate const&`, loads its 32-bit value at `0xc73ec`, and stores it into KMS `+0x48` at `0xc7400`.

No configuration-wide memset occurs in the selected caller. The observed writes establish a meaningful extent through byte `+0x30`; they do not prove a public `sizeof`, alignment or the contents of padding at `+0x04` through `+0x07` and after `+0x30`. The configuration contains an owning C++ string. A zero-filled byte array or guessed C struct is not a substitute for its construction/destruction contract.

The configuration is passed by reference to SDK createProcessor at `0xc7ad4`. The temporary path is destroyed after that call, including its external allocation branch at `0xc7c08` through `0xc7c0c`. This observed caller uses a scoped configuration. It does not retain that temporary object as the processor's public configuration object.

## Concrete wrapper objects

The result wrapper is instantiated first at `0xc781c` through `0xc78e0`. It allocates `0x30` bytes, copies the caller's result `std::function`, installs its own vptr, and creates a separate `0x20`-byte libc++ shared-ownership control block.

The supplier wrapper follows at `0xc79bc` through `0xc7a80`. It allocates `0x28` bytes, copies the caller's supplier `std::function`, installs its own vptr, and creates another `0x20`-byte shared-ownership control block.

| Object-relative offset | Result wrapper | Supplier wrapper |
| --- | --- | --- |
| `+0x00` | Vptr `0x1104c40` | Vptr `0x1104ce0` |
| `+0x08` through `+0x27` | Copied libc++ function object | Copied libc++ function object |
| `+0x20` | Function's erased callable pointer, within the function object | Same |
| `+0x28` | Captured pointer to the KMS member at `this+0x68` | Outside the allocated supplier object |

Callable copying distinguishes empty, inline and heap cases. It invokes libc++ function clone operations through the source callable's virtual slots. Temporary copies are then destroyed through the appropriate inline/heap operations. These are real C++ function objects with owned callable state, not a plain function pointer plus context tuple.

The SDK call receives shared-pointer pairs for supplier and result handler. The ordinary caller releases its temporary shared references after the SDK call. The processor constructor described in `native-frame-factory-findings.md` retains both pairs, so their lifetime extends through processor ownership. The registry handle is subsequently enabled at `0xc7ba0`. It is not an independently owned wrapper allocation.

The result wrapper's chain-member capture is different from shared ownership. It stores an address inside the KMS object, not a strong reference to that object. The selected code does not extend the KMS object's lifetime merely by retaining the result wrapper. A test that uses this route must preserve the KMS stream and its chain-member storage until processor/callback cleanup is complete.

## Exact virtual slots and forwarding contracts

These concrete wrapper tables put the processing method before the destructor entries. Do not copy the destructor-first slot order of an unrelated C++ interface.

| Wrapper | Table start / address point | Slot from address point | Target |
| --- | --- | --- | --- |
| Result handler | `0x1104c30` / `0x1104c40` | `+0x00` | `handle(value_type&)`, `0xce938` |
| Same | Same | `+0x08` | Complete destructor D1, `0xceabc` |
| Same | Same | `+0x10` | Deleting destructor D0, `0xceb14` |
| Supplier | `0x1104cd0` / `0x1104ce0` | `+0x00` | `supply() const`, `0xcec04` |
| Same | Same | `+0x08` | Complete destructor D1, `0xcec24` |
| Same | Same | `+0x10` | Deleting destructor D0, `0xcec7c` |

Supplier `supply() const` reads its function callable pointer at wrapper `+0x20` and tail-branches to that callable's invocation slot `+0x30`. Empty supplier functions call `std::__throw_bad_function_call` at `0xcec20`. An empty function is not a valid default supplier.

For the actual ordinary NoiseCanceller supplier, the retained invoke body `0xfed78` loads the captured NoiseCanceller's 32-bit field at `+0x1e8` and returns `0x01000000 | (UInt64(value) << 32)` in `x0`. Thus eight meaningful return bytes are observed, with little-endian byte 3 equal to one and bytes 4 through 7 carrying that field's bits. This is not yet proof of the complete C++ value_type declaration, member types, alignment, triviality or all return-ABI classifications. No hidden-result pointer is used in this concrete invoke body; the selected virtual wrapper preserves the callable's return mechanism by tail-call.

Result `handle` receives the mutable SDK `ResultHandlerWithStats<float>::value_type&` in its input reference. The user's copied function accepts a const reference to that same nested value type. `handle` does not forward a raw float pointer/count signature.

If the user's result function is empty, `handle` returns without invoking it. If its captured KMS chain-member points to a chain, it obtains the float-vector range from the result object at `+0x28/+0x30`, passes a byte-length/pointer MediaFrameBuffer to `FrameProcessingChain::ProcessData` at `0xce988`, and, on the zero-status branch, assigns the returned range back to that result vector at `0xce9dc`. It then invokes the user's function with the original result-object reference at `0xce9e4` through `0xce9f4`. The chain-error path logs and can omit that user callback.

Consequences: callback arrival alone does not prove every processing stage succeeded; the wrapper may postprocess/mutate the frame; the callback reference does not demonstrate ownership transfer; and vector assignment can allocate. No realtime allocation or timing guarantee is established.

The D1 destructors destroy the copied libc++ function and return. D0 also deletes the concrete allocation. Both wrappers use original C++ shared-pointer ownership paths. A caller must not free a wrapper, registry handle or control block with an unrelated destructor/free operation.

## Direct factory versus KMS route

| Route | What existing code supplies | Remaining obligations |
| --- | --- | --- |
| Direct ordinary createFrameProcessor | Processor construction and retention of typed callback shared pointers | Correct abstract supplier/handler declarations, exact supplier return type, result reference type, descriptor/configuration, shared_ptr ownership and matching destruction |
| KMS CreateNCProcessor | Concrete virtual callback wrappers, copied user functions, SDK registration/enabling | Valid KMS/SDK stream, exact libc++ std::function and nested value types, model path construction, KMS/chain/context lifetime, matching SDK removal/close |

The concrete tables support a candidate C++ abstract-interface declaration order of processing method first, then virtual destructor. They do not authorize raw vtable patching or establish every aspect of a recreated class definition. The direct route avoids a reconstructed KMS object, its processing-chain capture and the std::function type-erasure boundary. It is therefore the shorter candidate for an eventual finite, device-free test, rather than rebuilding the whole addon.

The KMS route can avoid manually rebuilding the virtual callback classes only if a correctly compiled caller can construct the exact typed std::function arguments. This investigation does not yet provide an ABI-safe C callback registration function or permit passing arbitrary closures through a cast.

## Remaining finite contract gaps

- Resolve the supplier value_type's complete byte layout, size/alignment and return classification from its actual consumers. The observed packed x0 result is useful evidence, not a complete public type declaration.
- Resolve the handler nested value_type's full layout sufficiently to collect output safely. The separate dispatch investigation proves that the selected callback reference is valid only within the synchronous call and its samples must be copied before return. A typed reference can remain opaque for a callback-count-only construction test, but that would not establish valid processed samples or NC quality.
- Confirm the direct abstract callback base declarations and ownership against their call sites, then review a typed C++ shim. The proven slot order is method, D1, D0. Do not guess fields or manufacture instances by writing pointers into byte buffers.
- Integrate the separately investigated descriptor/lifetime contract, and preserve the original processor, callback and model lifetimes. This report does not replace that work.
- Initialization requirements, selected model behavior and thread safety still need separate evidence before a real model test. The dispatch and close reports separately establish the selected no-op finalization and remaining tail-preservation gap.

No addon/native function, model, audio device or admin operation was executed. No shared contract or app source was changed. Static plausibility remains separate from a successful inference test.
