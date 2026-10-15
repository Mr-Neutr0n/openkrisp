# Native stream close contract

Static REA inspection of installed addon SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755` recovered the selected close path. Each capture hashed the file before and after disassembly. No addon execution or audio occurred.

| Evidence | Scope |
| --- | --- |
| `ev_95b70fb36374891ff7c7d7b2b8f709dfa8daf959cdf603530599b369b9446236` | KMSStream Close and destructor |
| `ev_419684a9660e3c03a6ee66fbecf757bc1e33cf6121385189d8ddbfd38ab2ff74` | Float SDK close wrapper; selected AsyncInvoke Stop symbol returned no instructions |
| `ev_0376deeaf0ee0d3ff1f223467a3d595ad05a88b968dfd8bbd3091e7c96d91097` | Base SDK closeStream |

Raw captures and scenarios are retained under `evidence/model-probes/native-{stream-close,sdk-close,sdk-close-base}-disassembly.*`. Derived text files are reading aids. A successful disassembly process with only a symbol header does not establish the function body.

## Observed path

`KMSStream::Close` at `0xce044` invokes virtual slot `+0x18` on its optional member at `this+0x70`, then calls the float SDK close wrapper with SDK receiver `this+0x38` and a reference to the stream field at `this+0x50`. The selected virtual target is unresolved in this capture. It must not be described as a proven queue drain.

The float SDK wrapper at `0x1b4aa0` reads the caller's stream handle, calls base `SDK::closeStream(StreamFrameProcessorsBase*)` at `0x1b419c`, then zeros the caller's handle at `0x1b4ab8`. This zeroing follows normal return; an exception before that store does not prove invalidation.

Base close searches the SDK stream vector for the handle. A missing entry returns without removing another stream. A matching entry receives a virtual call at slot `+0x18` at `0x1b41f4`. The method then locks SDK mutex `+0x58`, moves later vector entries down and releases the erased unique-owned registry through virtual slot `+0x08`. It updates the vector end and unlocks. The initial lookup and slot call precede this mutex acquisition, so this method alone is not evidence that concurrent push and close are safe.

KMSStream Close catches selected SDK and standard exceptions and logs them. Its void return is not a positive proof of complete cleanup. Its destructor at `0xce528` releases member ownership and processing chains; this selected body has no explicit call to Close or SDK closeStream. A direct wrapper user must preserve explicit close ordering rather than assume object destruction closes a live registry.

## Consequence for a finite processing probe

Use one serialized producer and stop frame submissions before processor/stream teardown. Preserve the SDK and callbacks until processing returns and matching removal/close completes. These are conservative adapter requirements derived from the selected path, not a recovered whole-SDK concurrency guarantee. Do not treat Close as EOF flushing, queue draining or successful output publication. The optional async member remains unresolved. The registry finalization follow-up below narrows the ordinary NC behavior.


## Registry finalization follow-up

The descriptor worker bound registry vtable slot `+0x18` to `finalize` at `0x1b8320` in Evidence `ev_d783a4e17eacc0f3caff99ad8b6a5d79588d1dea4a892a1a135cb0bafb4efcf4`. Evidence `ev_6101539f1a9b7a8a54f4f6fb90c2ae7d266c6c34d5acd46b81d9bcd594684c13` shows that method retaining each processor owner and calling processor slot `+0x18` inline at `0x1b8370`. The same vtable evidence binds the selected ordinary NC processor's slot to a single `RET` at `0x110cc`. Thus this registry finalization step does not process or emit the selected ordinary NC processor's buffered tail. It is not an EOF flush for that processor. Other processor variants and the optional async member are outside this conclusion. See `native-descriptor-lifetime-findings.md` for the vtable and descriptor details.
