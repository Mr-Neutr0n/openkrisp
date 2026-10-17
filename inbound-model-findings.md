# Installed inbound NC model

The installed inbound model accepts the reviewed ordinary NC factory with normalized mono Float32 input at 48 kHz, 480 samples per call, in this bounded synthetic experiment. Both NC and bypass runs returned 100 callbacks and 48,000 finite samples across five persistent batches, then confirmed native teardown. The NC capture has an unresolved REA cleanup failure. Stereo behavior, perceptual quality, sustained deadlines and model tail preservation remain unverified.

No physical microphone, playback, CoreAudio graph, driver change or administrator action ran. Original files stayed at their installed paths. At the time of the direct probes, production provider selection was fixed to the outbound model. The later integration checkpoint below adds explicit speaker selection.

## Current identity

Read-only capture `ev_4caf8804496582abe49ba6c762190dc0674e43b81c454a5b6c515371f9e5e5a2` hashes the addon and inbound model without loading either. It exited 0 with complete retained output and verified owned-process cleanup. Files are under `evidence/model-probes/inbound-provider-identity-20261018.*`.

| Artifact | Bytes | SHA256 |
| --- | ---: | --- |
| `kr-media-sp.node` | 26,499,984 | `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755` |
| `c8.w.m.d15e29_1.0.kef` | 13,341,309 | `d1e4e2a94fe27dec1a8fd5a7b36cfac38d183a110f738156d85d1317f98fac8a` |

The model is at `/Users/harikp/Applications/krisp.app/Contents/Resources/resources/models/audio/c8.w.m.d15e29_1.0.kef`. The addon path is the same current artifact used by `native-direct-probe-findings.md`.

Fresh REA `inspect_plist` evidence `ev_89741bd0eebf862f38d26b4698f7686d6fd774157f966f3f8096b704b672eac6`, retained in `evidence/inbound-model-catalog-20261018.json`, decodes the installed `models.json` entry:

- category `inbound`, name `nc-inbound-mwb`, file `c8.w.m.d15e29_1.0.kef`;
- type 0, rate range 0 through 192000, workRate 16000;
- performance 50, optimized false, default true.

These are catalog fields. They do not establish external frame shape or stereo semantics. In particular, `workRate:16000` does not require callers to submit 16 kHz samples.

## Why this probe uses the existing factory

The ABI belongs to the unchanged addon, not the model filename. Retained evidence establishes the ordinary float factory and its shared-pointer supplier/result ownership in `native-frame-factory-findings.md`, especially `ev_3e5e72501abfba06515d44bbbf5c5564f972c47ba920c1571ecc427b1ef7dc6c` and `ev_ee0de6c7502f3081ea0caa2f0a308b20ce13f5b587f3ac1d12c685bc3ce03b0e`. The constructor receives the model path through ordinary NC Configuration and selects processing internals from loaded configuration. It does not require a different factory signature for an inbound catalog name.

Descriptor evidence `ev_47b50132986bf7e01ccbd338eb87744d860460c106f7123fae36ac66ecb592f2` and sample-count evidence `ev_dc6e8efb5aa58e30a8cf530f62eb9e794d65bfe554b62438c1432a715ee6359c` establish a validated 10 ms/48000 descriptor and 480-sample extent. Dispatch evidence `ev_6a9010dfcf231d1025f02fc2bd4db5320fdf395fbb31c04cdcdfd3ae673bf3df` and `ev_4378661bdc5cd8515fcd8b978d327e5ba32c66e0fd163f50886b8406dfbaa334` establishes synchronous copying callbacks, normalized Float32 boundaries and resampling paths.

Before runtime, this supported a candidate experiment only. The model's internal branch and successful construction were not established by those shared method bodies. The observations below now establish bounded mono processing at the proposed external rate and frame size for this exact model digest. They do not identify its internal rate or processing branch.

## Bounded runtime observations

A separate ARM64 adapter was compiled from current independent `native_probe.cpp` with macOS 12 deployment target. Its path is `evidence/model-probes/inbound-adapter-20261018.node`, SHA256 `e0ac9316f2cdaebdafc7372e0d9d145f4df9314825e2c14427269738ffbdf26c`. Node SHA256 is `1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040`.

The private inspection wrapper reuses `runProbe` and `persistentAdapter`. It rejects any other inbound-model, adapter or Node digest. The existing launcher also binds the exact addon digest, checks loopback fails with `EPERM` before loading the adapter, validates counts and finite samples, and hashes addon/model/adapter again after teardown. Both runs used `/usr/bin/sandbox-exec` with `(version 1) (allow default) (deny network*)` and the established `/usr/bin/env` DYLD library path route. This is a recorded denial profile and prerequisite check, not a syscall-level network trace.

Each run used the same seeded-noise/triangle fixture, input SHA256 `6ef4b0e40cf74b1bbe3b97b5d36ee79a2e42b9e7eadb9240afe92a2fc2fc7b5b`. One processor stayed open across batches of 1, 17, 3, 29 and 50 frames. Each returned `processorConstructed`, `directProcessInvoked` and `teardownComplete` true, 100 frames, 100 callbacks and 48,000 finite samples. All recorded before/after addon, model and adapter hashes match. No padding was added.

| Run | Capture status | RMS | Peak absolute | Output SHA256 |
| --- | --- | ---: | ---: | --- |
| `inbound-persistent-nc-20261018-v1` | Helper exit 0; partial REA capture, no Evidence ID | 0.009201080300 | 0.07076429576 | `cf8a006932542aa1eeb9a02e2945e9c9f671804a2bcee7dc92997ab108d90a76` |
| `inbound-persistent-bypass-20261018-v1` | Exit 0; Evidence `ev_4388b9434974bae50da7433fa61fbba3f09b1b18513ce3a453298cbb3d027e8d` | 0.09070920575 | 0.2276525795 | `b01619cae0810c4cfcab9aba535ee5ee399a5da8037228aebdb3c2b5c1e0ad2a` |

The outputs differ in 47,482 samples, with difference RMS 0.08867019672. This establishes a distinct NC-versus-bypass result for the synthetic signal. Reduced energy does not establish speech preservation or perceptual quality.

Scenarios, results, wrapper, adapter and private output folders are under `evidence/model-probes/` with the run names above. Published metadata and output sizes/digests are also retained in the capture filesystem checkpoint.

The NC capture returned `cleanup_incomplete`: REA could not read ownership environments for two live candidates and retained its temporary root. The error envelope contains the complete observed helper output, exit 0 and filesystem result, but no successful Evidence ID. Owned-process-group cleanup and temporary-root removal remain unverified for this capture. No candidate was signaled manually. The bypass capture reports verified owned-process cleanup and removed its temporary root; it separately lists platform processes whose environments were withheld. Do not promote the NC capture to a fully successful REA lifecycle result.

## Integration prerequisites

The experiment supports an explicit experimental inbound provider. The separate static investigation in `native-speaker-channel-findings.md` establishes averaging stereo into one mono processor and duplicating its output for the selected KMS bridge. That contract still needs synthetic adapter tests and a complete original stereo runtime comparison. Two independent mono processors would implement a different channel policy.

Before production selection, extend exact model identity admission, startup acknowledgement and desktop validation together. Bind the inbound digest separately from the proven outbound digest. Keep a fresh processor per stateful channel/session and the existing normalized 48 kHz/480-sample native contract. Re-measure startup cost, sustained processing deadlines and buffering under the actual worker transport. Resolve the NC capture lifecycle limitation before treating both runs as complete REA acceptance. Model quality, original-app comparison, internal latency and finite-input tail preservation still need separate evidence.


## Paced worker and speaker integration, 2026-10-18

The timed worker probe now accepts an explicit `--model-role` option and derives the pinned model digest from that role. Unknown, repeated and missing role arguments reject before opening the synthetic input. The default remains outbound.

REA capture `inbound-paced-nc-20261018-v2` ran the role-bearing production worker against the installed inbound model and the previously signed packaged adapter. The helper exited 0, processed 105 frames including five padding frames, returned 48,000 finite aligned samples and confirmed worker teardown. The callback bound was 512 samples, scheduling budget two model frames and explicit transport delay 2400 samples, or 50 ms. It reported zero queue deadline failures, maximum callback exchange 13 microseconds and maximum scheduling lateness 5328 microseconds. Output SHA256 `cf8a006932542aa1eeb9a02e2945e9c9f671804a2bcee7dc92997ab108d90a76` matches the direct inbound NC result byte for byte.

The probe executable SHA256 was `bb038be1a6104fa2d9e4717b92520cddc0dd6f1346541a4e90355fcf663fe30a`. The packaged adapter SHA256 was `216d95381d62f24605103a179d2782c967621baccdf7f06493d76f06b8d26025`; addon, model and Node pins are unchanged. The worker checks identities before loading, not atomically against loaded images or again after teardown.

REA returned `cleanup_incomplete` because one live candidate's ownership environment was unavailable. The retained partial capture has complete helper output and exit 0 but no successful Evidence ID; owned-process-group cleanup and temporary-root removal are unverified. No candidate was signaled manually. Files are `evidence/model-probes/inbound-paced-nc-20261018-v2.*`. This is short paced mono CPU evidence, not a stereo original-app comparison, sustained deadline guarantee, live route, quality result or model-tail proof.

The independent adapter now supports a separately owned inbound speaker worker. It averages stereo before the mono worker and duplicates its output, with callback-size and finite-value checks. The host and desktop carry separate microphone and speaker configurations and identity acknowledgements. Acceptance tests and remaining gaps are recorded in CHECKPOINT.md.


A later complete capture exercises both installed models through the production dual adapter with verified REA cleanup. Each speaker channel matches the direct inbound bytes. See `dual-installed-adapter-findings.md`. This supplies complete bounded NC capture evidence without changing the earlier partial captures' status or establishing live routing, speech quality or original desktop parity.
