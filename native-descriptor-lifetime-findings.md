# Native descriptor values and lifetime

Static REA analysis resolves the selected stream descriptor's two fields and its owned registry copy. The concrete ordinary NC processor retains the constructor's descriptor address at `+0x28`, but the inspected processing, finalization, update and destruction path does not dereference that field. This is a dormant borrowed address in the selected path, not evidence of a use-after-free or an ownership transfer.

No addon loading, SDK initialization, inference, audio, device or administrator action occurred.

## Identity and evidence

The exact installed target remains `/Users/harikp/Applications/krisp.app/Contents/Resources/app.asar.unpacked/.vite/build/node_modules/kr-media-sp/build/Release/kr-media-sp.node`, SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. Every cited new static helper captured the same digest before and after its reads and exited zero. REA launched inspection helpers and LLVM tools only.

| Evidence | Scope |
| --- | --- |
| `ev_5d63bf20292be743ed5cd241986aac90c4ea9658ad983e3d811c2c4e2df21a30` | Defined symbols selected for descriptor validation, concrete float NC process, registry registration/update |
| `ev_47b50132986bf7e01ccbd338eb87744d860460c106f7123fae36ac66ecb592f2` | Descriptor validation and exact concrete float NC process body |
| `ev_a24248f2bb01fbe5f73369475b7acd244b7d96df311a0e22ba742573c5790485` | Shared registry registration and update bodies at the aliases used by the actual caller |
| `ev_dc6e8efb5aa58e30a8cf530f62eb9e794d65bfe554b62438c1432a715ee6359c` | Exact sample-count arithmetic |
| `ev_d783a4e17eacc0f3caff99ad8b6a5d79588d1dea4a892a1a135cb0bafb4efcf4` | Bounded raw concrete NC and registry vtables; instruction at the shared no-op target |
| `ev_6101539f1a9b7a8a54f4f6fb90c2ae7d266c6c34d5acd46b81d9bcd594684c13` | Registry finalize loop |

Captures and scenarios are `evidence/model-probes/descriptor-lifetime-*.result.json` and `.scenario.json`, with derived raw-frame `.result.txt` reading aids. The earlier `descriptor-lifetime-vtables.result.json` attempt emitted excessive alias names and has incomplete raw retention; it is not used to establish the final vtable result. The cited `descriptor-lifetime-vtables-bounded` replacement limits alias output and retains all 14,402 observed raw bytes, including its final identity check. Rendered terminal truncation, where reported separately, is not a missing raw method body.

Constructor, factory and registry creation observations below also cite retained prior Evidence `ev_ee0de6c7502f3081ea0caa2f0a308b20ce13f5b587f3ac1d12c685bc3ce03b0e`; concrete destructor observations cite `ev_5373dc2a13b8d8cfb6bf786f8cb81831bb0041c3ac170468ca6f670a339a570e`. Addresses are unslid addresses from this digest.

## StreamDescriptor validation and extent

`Audio::StreamDescriptor::validateStreamDescriptor()` starts at `0x1b7f0c`. Its successful path reads exactly two 32-bit values and returns void. Invalid values throw `KmsInvalidConfigurationException`, with distinct frame-duration and sampling-rate diagnostics.

| Offset | Meaning established by validation and callers | Accepted raw values |
| --- | --- | --- |
| `0x00` | Frame duration, represented as a 32-bit enum/integer | 10, 15, 20, 30, 32, 40 |
| `0x04` | Sampling rate, represented as a 32-bit enum/integer | 8000, 12000, 16000, 24000, 32000, 44100, 48000, 88200, 96000 |

The first field is validated with a bound of 40 and the mask `0x0000010140108400` (`0x1b7f20` to `0x1b7f44`). The second uses explicit comparisons (`0x1b7f48` to `0x1b7fd4`). The descriptor has an eight-byte copy contract in the selected stream creation and update paths. No channel count, sample format, data pointer or timestamp is read from this descriptor. Those concepts must not be added to it from the separate `AudioFrameSpec` or `MediaFrameBuffer` types.

`FpCommon::getSampleCount(unsigned long, unsigned long)` at `0x4937c4` multiplies its two unsigned inputs, converts the product to double, divides by 1000.0, then converts to an unsigned integer by truncation. Combined with the constructor arguments, this establishes milliseconds for the duration field and samples per second for rate. It does not impose divisibility: for example, 15 ms at 44,100 yields 661 after truncation. This is the selected arithmetic, not a recommendation for arbitrary block partitioning.

## Copies versus retained addresses

`SDK::createStream<float, StreamDescriptor>` at `0x1b49c8` copies the eight input bytes into the heap registry at offset `0x20` (`0x1b4a04` to `0x1b4a08`), validates the original descriptor, then transfers the registry's unique ownership into the SDK's stream vector. The stored registry descriptor is a value copy, not a pointer to the caller's input.

`SDK::createProcessor` at `0x1d6800` reads that registry value from registry offset `0x20` and places an eight-byte copy on its own stack at `sp+0x38` (`0x1d6840` to `0x1d684c`). It passes that stack address to `createFrameProcessor` (`0x1d687c` to `0x1d688c`). The concrete NC constructor at `0x1dac98` stores the incoming descriptor address into processor `+0x28` at `0x1dacd0`. There is no ownership count or descriptor allocation associated with that store.

The constructor also consumes the descriptor values immediately. On the MainCleaner path it sign-extends the two 32-bit fields, computes sample count, and caches rate at processor `+0x50`, count at `+0x58`, and duration at `+0x60` (`0x1dae04` to `0x1dae18`). The process body at `0x1db2b0` uses cached state, including the expected frame count at `+0x58`. Its separate DfProcessor path uses its owned child processor. The inspected outer process body does not read the retained descriptor pointer at `+0x28`.

Registry `registerProcessor` at `0x1b94b0` appends the supplied shared-pointer pair to its vector and maintains shared ownership. It does not replace or rebind processor `+0x28`. Thus the SDK path's temporary descriptor address is retained after its source stack frame returns; no current evidence supports pretending that address points at the registry's permanent value.

This is not by itself an observed invalid dereference. The selected concrete process body, destructor at `0x1db8b0`, and no-op update/finalize methods contain no observed read through that field. No release or delete of that descriptor address is performed by the inspected destructor. The field's intended source-level purpose remains unknown.

## Descriptor updates

Registry `updateStreamDescriptor` at `0x1b83cc` validates the new descriptor first, copies its eight bytes into registry `+0x20`, then iterates processor shared pointers and calls each processor's virtual slot `+0x28` (`0x1b83ec` to `0x1b8438`).

The concrete ordinary float NC vtable at `0x110ee28` has address point `0x110ee38`. Its `+0x28` slot points to `0x110cc`. Raw instruction word `0xd65f03c0` at that address is `ret`. The concrete processor therefore does not rebind the stored descriptor address or refresh its constructor-cached rate/count in this update callback. A successful registry update must not be assumed to reconfigure an already-created ordinary NC processor. Creating a matching processor for the intended descriptor avoids relying on such an unsupported assumption; no runtime update was attempted here.

The exact float alias selectors for some shared methods returned only symbol headers in `llvm-objdump`. The corresponding int16 aliases yielded the actual shared-address bodies. Fresh `nm` identifies both aliases at the same addresses, and the float SDK caller explicitly reaches those bodies. This is an address-sharing observation, not a change of the float processor's sample type.

## Selected close finalization

The float registry vtable is at `0x110ddc0`, address point `0x110ddd0`. Its `+0x18` slot is `finalize` at `0x1b8320`. That body walks its 16-byte shared-pointer entries, temporarily retains each processor, calls processor virtual slot `+0x18` at `0x1b8370`, releases the temporary ownership and advances.

For the selected ordinary float NC processor, both `+0x10` (flush) and `+0x18` (finalize) point to the same `ret` at `0x110cc`. Root's separate close capture `ev_0376deeaf0ee0d3ff1f223467a3d595ad05a88b968dfd8bbd3091e7c96d91097` shows SDK base close invokes registry `+0x18` before erasing the owned registry. Together these establish that this close-finalize edge does not process buffered tail samples or issue a final result callback for this concrete NC processor. It is not a whole-SDK guarantee about other processors, and it does not establish how much algorithmic tail the selected model might retain.

## Remaining limits

The two descriptor values, their validation, registry value copies and selected concrete no-op update contract are now established. The retained `+0x28` address is not an owner, is not rebound by registration, and is not dereferenced along the inspected concrete lifecycle path. No global search or runtime watch proved that every possible external accessor ignores it. A direct native wrapper should keep its descriptor storage stable until the processor is destroyed rather than use this bounded negative result as a broad lifetime promise.

Complete SDK/model initialization, callback types, configuration construction, model branch selection, exception ABI and legal redistribution remain separate work. The descriptor evidence does not authorize invoking the addon through guessed private layouts. Only this new report and uniquely named ignored inspection captures were changed.
