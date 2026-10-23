# Installed AEC to microphone NC CPU checkpoint

Two REA captures on 2026-10-23 verify the independent AEC-to-outbound-NC chain against a separate, warmup-matched NC baseline. Each retained 480000-sample output is byte-identical to its own baseline. This is bounded functional CPU evidence, not full feature parity.

The chain receives the retained ten-second 48 kHz mono microphone mixture and 48 kHz stereo reference. A fresh standalone NC engine receives the retained direct-AEC output, preceded by the same AEC startup zeros. The oracle never supplies the chain's microphone or reference. The chain removes AEC plus NC queue delay; the synchronous baseline removes only its AEC zero prefix. Processed-frame handshakes occur outside callbacks. Neither run is paced or uses hardware audio.

| Callback maximum / budget | Evidence ID | AEC / NC / total buffering samples | Chain AEC / chain NC / baseline frames |
| --- | --- | --- | --- |
| 480 / 2 | `ev_4b31d8782b9662f39bab53554496e488b242331921089bb9cca38a83d749a607` | 1920 / 1920 / 3840 | 1008 / 1008 / 1004 |
| 4096 / 2 | `ev_024ec6221e035ed54330c43b666c686ceb9570618624d883c6cff1ffe3d45812` | 5760 / 5760 / 11520 | 1024 / 1024 / 1012 |

Both captures exited zero without truncation. All before/after artifact and input hashes match. Both workers in the chain and the standalone baseline closed cleanly before exclusive output publication. REA verified owned-process-group cleanup and removed its temporary root. It separately left unrelated PID 48698 in the 480 capture and PID 49255 in the 4096 capture untouched because ownership could not be verified, with reason `platform_binary_environment_withheld`. This is not a claim that every host process was identified or terminated. Process observation is sampled, and no syscall-level network trace is provided.

The recorded outer sandbox denies network access and supplies a clean Node environment. Each worker also requires its own denial gate. Loopback returned `EPERM`. File hashes are sampled identities, not atomic loaded-image binding or complete transitive dependency admission.

| Bound | Chain and baseline output SHA256 | Independently recomputed RMS |
| --- | --- | --- |
| 480 | `4201d16161d76d5b442be7cabd7b779046fc5d8adc119de6a79a5d3faf478866` | 0.020162382093075353 |
| 4096 | `7dd7f250a2cc55665f5c5e936944a496c95ead89967d11596c2ab3a6ea8a1361` | 0.020018150413605176 |

Each file contains 480000 finite Float32 values, or 1920000 bytes. Independent retained-file analysis found zero bit mismatches, zero numeric mismatches and zero difference RMS in every one-second chain/baseline window. These are level and equality checks, not quality scores.

The two callback bounds do **not** produce the same output. Across bounds, 478780 numeric samples differ, with difference RMS 0.0016221878284013397. The test supplies different AEC startup-zero prefixes at the two bounds. Each has its own matched oracle. These observations do not establish callback-bound invariance or uniquely identify the cause of the cross-bound difference.

The following identities matched before and after both captures:

| Artifact | SHA256 |
| --- | --- |
| node | `1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040` |
| library | `bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a` |
| addon | `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755` |
| model | `12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d` |
| adapter | `216d95381d62f24605103a179d2782c967621baccdf7f06493d76f06b8d26025` |
| ncWorker | `93c0fda34e544a108f19bf8fec1ee6a4d7219cce8beafbe36de5697ea7a648e8` |
| ncSession | `3071ac60f848f3109f8f608eea57a82feaeb3eb02d2ce36fa276f250ffcf8888` |
| ncProtocol | `2d9f55e44af128f36216f7206f4235f4020c9b0fb45eabfebd2e6a56a8c32adc` |
| ncManifest | `b55cf521bb227745d8f334fc1be542e4155b65c1fdf7984b6cb812983f0f8db2` |
| microphone | `f5fe661f990a8e1a97068e8027847359b5d7d2427c6250e12f62a1880ebcfed8` |
| reference | `9e8e9e54c08462adc0301e4cf21dde85a6c02f1a855212602819c7e6c7f2bb05` |
| directAEC | `64ff21c8053d444cd20f1f1a8d34ccd3ade696d1acefcbd46e46364196895f5f` |
| executable | `28049ba29ee4819cb5f2f38ed4db8a81a7a5ecf13cac7a7da62a88724d8ce89a` |
| aecWorker | `f546ee5f38cb3ecf186bc812e4f687f73bca346c1156c6c3c64670ffd78983cf` |
| runner | `0513c3040df2ad7b43677ef620df046a917139b4736116dd777d44628aff5eed` |

Inputs are `aec-speech48-20261023-v1/samples/{mixture-input,reference-input,mixture-reference-on}.f32le` under `evidence/model-probes/`. The last file is used only for the independent baseline. Full admitted paths remain in each output directory's `metadata.json`.

| Retained record | SHA256 |
| --- | --- |
| `aec-nc-chain480-20261023-v1.result.json` | `417d314e385695f969e8500f89a632a8710f95ae0010e896f01ecad7ef9efdf6` |
| `aec-nc-chain480-20261023-v1.metrics.json` | `58049bc6f55e30c3f301551cf73d81a8c5f854b1ddd6f7671c865012d6fc3382` |
| `aec-nc-chain4096-20261023-v1.result.json` | `74b16235d5e58f5ce582004d1818a120c8945032ce834af4373dd87172cc7739` |
| `aec-nc-chain4096-20261023-v1.metrics.json` | `05bca19381b4b1caaa6058894e6569a2c3b540d82f01d0ae888caedd98629067` |
| `evidence/aec-chain-probe-host-verify-20261023.log` | `1f1470954ca3ceb799a407987bbb8b448a42fa98af23a3430f4f7cd8d48a0eb0` |

The metrics files were recomputed from retained outputs with `analyze-aec-nc-chain-20261023.py`; they are derived reading aids, not new runtime Evidence. Full own-fixture audio-host verification exited zero, including release, ASan/UBSan and TSan integration and probe failure/publication checks.

AEC followed by NC remains an independent processing policy. This checkpoint establishes neither original microphone order nor speech preservation, acoustic alignment, sustained deadlines, complete model-tail recovery, physical route acceptance or full local parity. No microphone, speaker, CoreAudio route or administrator action was used. Original libraries and models remain external.
