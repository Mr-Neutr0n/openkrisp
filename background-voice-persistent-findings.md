# Background voice persistent worker gate

The persistent native worker processed the pinned HVC-lfb model in active and bypass modes. Both outputs match the retained direct HVC baseline byte for byte. This passes a bounded worker integration gate. It does not establish background-voice cancellation quality or full original BVC graph parity.

## Retained capture

REA `ev_f0e42f64a009b52eb8aed7c7e30177101eb560c64ade103e2096a899bb788753` is retained at `evidence/model-probes/hvc-persistent-20261025-v1.result.json`. Its reviewed scenario is `evidence/model-probes/hvc-persistent-20261025-v1.scenario.json`. Its runner is `evidence/model-probes/run-hvc-persistent-20261025.cjs`. Outputs and metadata are in `evidence/model-probes/hvc-persistent-20261025-v1/`.

The scenario ran under `/usr/bin/sandbox-exec` with `(deny network*)`, then `/usr/bin/env -i` and an explicit PATH. The runner required a loopback connection attempt to fail with EPERM before starting either child. REA does not observe network activity itself. It recorded exit zero, quiescence, verified owned-process-group cleanup and a removed temporary root. The capture retains all 4,522 raw terminal bytes and all 23,201 rendered terminal bytes. Filesystem snapshots retain all four output files with hashes and no hash omissions. Process sampling retained zero samples, so the child results come from the runner's recorded spawn results and metadata, not a complete REA process trace.

This report reviews retained evidence only. It did not rerun vendor code or inspect original artifacts.

## Identity pins

The runner checked these SHA256 values before and after processing. Every pair matches.

| Runner identity key | SHA256 |
| --- | --- |
| node | `1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040` |
| probe | `1b177d22eb66b45bf16fbb329acc568ed1ca458e94a67bba47e82b1f9ce46a23` |
| worker | `6ceef5bc8e0e230bf3b595cd176d84788bec0e6cb79e3ec82b5bd6ac6a27ef53` |
| session | `3071ac60f848f3109f8f608eea57a82feaeb3eb02d2ce36fa276f250ffcf8888` |
| protocol | `2d9f55e44af128f36216f7206f4235f4020c9b0fb45eabfebd2e6a56a8c32adc` |
| fixture | `5b4e3d349ad5febb4e17e14df1387a34b460cc3485b9d12d87b0be92a267b9d2` |
| helper | `c54f5f3e75a846c7ea234c3e2d3a4ca0a4fef34eb07627177e5e0bd77bf17bce` |
| adapter | `216d95381d62f24605103a179d2782c967621baccdf7f06493d76f06b8d26025` |
| addon | `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755` |
| model | `54e2913ea45734adc3323407e43f55b14afade256ab4da6226c2b6e30604cbf4` |
| activeBaseline | `a04779babdf940bc4c3f3d44b8cb020e4b159cf44b23ec92783b08acf6b21fd1` |
| bypassBaseline | `d65f14f3868eccb927bd4da5b9a2ae2bc61755e29ae08e432cb3129f67c4f671` |
| runner | `9b7a39c7ad1777bb6072b5e912567fddddfbf00ae7ad7f88aa1d703d9932e1d0` |

The `model` key is the installed `hs.c6.f.m.75df8f.berlin.kef` asset. The `addon` key is the installed MediaSP addon. The `adapter` key is the own packaged `native-probe.node`. Worker, session and protocol keys identify the own persistent worker implementation used by this capture. The runner also pinned its own file through the explicit scenario argument. The outer sandbox executable SHA256 is `d1ee30dbde955aaa75c7f801fdfea4df05b10129454d7982eb6453f771436d42`. The scenario digest is `eebaac66e5595900ea9fe3558c9d7e3463b12bad0730ec2ca9495ff08ad37464`.

These are sampled file identities. They do not atomically bind the loaded OS image or prove that current source files still match the captured versions.

## Results

The deterministic noise/triangle-tone fixture contains 48,000 Float32 samples at a 48 kHz mono interface. Each fresh active or bypass probe session sends 100 frames of 480 samples through the persistent worker. The runner generates the same fixture used by the direct baseline and checks input SHA256 `6ef4b0e40cf74b1bbe3b97b5d36ee79a2e42b9e7eadb9240afe92a2fc2fc7b5b` before and after processing.

Each child reports `modelRole: outbound-hvc-lfb`, the pinned model hash, `backend: ordinary-nc-direct`, 100 frames, 48,000 samples, completed status and `teardownComplete: true`. Both child exit codes are zero, without signals, errors or stderr. The backend label identifies the selected ABI path. It does not identify an original desktop BVC graph.

| Mode | Output SHA256 | Samples / bytes | RMS | Peak |
| --- | --- | --- | --- | --- |
| Active | `a04779babdf940bc4c3f3d44b8cb020e4b159cf44b23ec92783b08acf6b21fd1` | 48,000 / 192,000 | 0.004810434738109847 | 0.03459693491458893 |
| Bypass | `d65f14f3868eccb927bd4da5b9a2ae2bc61755e29ae08e432cb3129f67c4f671` | 48,000 / 192,000 | 0.09160575567011363 | 0.23599790036678314 |

The named comparison files are `hvc-candidate-20261023-v1/active/output.f32le` and `hvc-candidate-20261023-v1/bypass/output.f32le`, both under `evidence/model-probes/`. Each comparison reports zero different bytes, zero different samples, zero RMS difference and zero maximum absolute difference. The runner checks sample counts and finite values. REA separately hashes `active.f32le` and `bypass.f32le` and records the same hashes as the runner.

The earlier direct capture `ev_56b1a5141f8d1e8f0eee9728b1d110f18bb2d9e628735ed0e21cca79d2bbb9fe` exited one because its outer runner incorrectly required bypass to equal raw input. Its native children completed. This persistent gate uses the retained direct bypass output as its explicit baseline and exits zero. It does not change the earlier capture's failed status. See `background-voice-candidate-findings.md` for the earlier failure and same-adapter ordinary-model control.

Recorded startup times were 1,087 ms active and 238 ms bypass. Recorded processing times were 44 ms and 45 ms respectively. These are finite probe timings, without audio deadlines or competing load. They do not establish real-time operation or end-to-end latency.

## Functional meaning and limits

The result supports admission of the exact HVC-lfb role through the own persistent worker/probe path for this one bounded input, interface rate and frame size. It also supports byte preservation relative to the corresponding direct HVC processing baseline across that integration. It does not prove arbitrary-duration stability, model switching inside one session, cancellation under load, other rates, HVC-sfb support or tail preservation.

The role is integrated into the native worker/probe only. This capture does not demonstrate an audio-host route or desktop UI control. It does not prove nearby-voice rejection, primary-speaker preservation, headset behavior, AEC composition or full local product parity. The static factory join and microphone defaults are recorded separately in `background-voice-native-findings.md`.

Original NoiseCanceller uses a separate energy path for stats when active NC processing is bypassed or unavailable. That selected wrapper returns original input in its energy-only branch. This direct ABI bypass baseline can contain SDK delay and differs from raw input. Thus byte equality here proves the worker matches its direct ABI baseline. It does not prove original wrapper bypass, energy stats, reporting callbacks or graph lifecycle parity.
