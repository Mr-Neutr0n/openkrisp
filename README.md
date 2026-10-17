# openkrisp

Private checkpoint repository: [Mr-Neutr0n/openkrisp](https://github.com/Mr-Neutr0n/openkrisp). Work resumed on 2026-10-15; [CHECKPOINT.md](CHECKPOINT.md) records the verified baseline and pending work. This is an independent local reconstruction, with no trial period, paid tiers, subscription checks, or usage quotas. All implemented local features are available without payment. Retained local features from the original paid or hidden feature set are in scope for independent implementation; unfinished features remain unavailable until implemented and verified.

Work in progress. This project builds a desktop app and independent audio and storage components, but no complete Krisp replacement. The approved development driver installation succeeded, but HAL cannot yet resolve its expected devices. Registration diagnosis is in progress. Full parity remains unverified.

The reference is the installed macOS Krisp at `~/Applications/krisp.app`. It changed from 3.16.8 to 3.17.9 during inspection; `version-change-findings.md` separates those identities. REA provides the original-app evidence. New implementation code uses ordinary development tools. GPT 6.1 sol workers contribute separate components and evidence analysis.

## Current implementation

| Component | Implemented | Still missing |
| --- | --- | --- |
| `app/audio-transport` | Timestamped mono/stereo rings, same-user shared-memory ABI, stale-producer silence | Audio-service integration, scheduling and latency measurements |
| `app/local-store` | Completed-session import, transcript search/export, interrupted-save visibility and strict selected-folder reopening | Recovery actions, original-format comparison |
| `app/audio-driver` | Virtual devices, hidden companion endpoints and bounded internal audio routing | System-host verification, app capture integration and latency measurements |
| `app/desktop` | Native history, persisted library folder selection, explicit macOS 13+ launch-at-login controls, search, WAV import, playback, transcript export, appearance, an optional floating control panel, model validation, explicit on-device WAV transcription, audio routing, live app-route mute/volume controls explicit recording with pause/resume and history save, and a temporary Original/RNNoise microphone comparison | Full workflow verification, actual audio routing and original UI parity |
| `app/model-catalog` | Confined file validation, SHA256 checks and explicit license metadata | Model inference integration |
| `app/native-model-probe` | Persistent installed-model sessions, supervised Node worker and callback queue connection, with synthetic and REA broker tests | Desktop/CoreAudio provider integration, callback-specific buffering, sustained timing and speech-quality parity |
| `app/noise-engine` | Independent RNNoise processor, arbitrary-size callback adapter and optional mic/speaker processing in the routing helper | Speech-quality comparison and end-to-end latency |
| `app/audio-host` | Device discovery, private aggregate backend, optional noise suppression, atomic app-route mute/gain, bounded background WAV recording, temporary physical-microphone capture and paired RNNoise processing, and desktop helper integration | Real HAL and hardware verification; original device-volume curve and synchronization |
| `app/local-transcription` | Strict on-device Speech framework adapter, cancellation and error handling | User-consented OS recognition test, language/quality parity |
| `verification` | Deterministic audio fixtures and numerical comparison | Original-versus-rebuild stream measurements |

Each directory documents its build and limits. `./verify` runs component checks, including the experimental native adapter's host-only fixtures. It requires Apple Silicon macOS, Xcode command-line tools, Node on PATH and Node headers at `/opt/homebrew/include/node`. No check installs a HAL plug-in, restarts the system audio service or loads Krisp. Separate REA captures verify bounded installed-model processing; speech quality, accent conversion and transcription parity remain unverified.

Run `./verify` to build and check the components in dependency order, including the desktop app. After the audio helper is built, `app/desktop/build` can rebuild the desktop alone; it rejects a missing or stale helper. The output is `app/desktop/.build/app/Lab Voice.app`. It has an ad-hoc signature for local development. It stores imported sessions under `~/Library/Application Support/Lab Voice/sessions` when launched. REA verified initial rendering, Settings reachability, Light appearance, persistence, and a later Dark/System roundtrip. REA observed the Audio sheet with audio stopped; its lower recording layout, live controls and transcription workflow still require further interactive verification. See `desktop-runtime-findings.md`. Its layout is a temporary independent design.

## Evidence and scope

- `PLAN.md` tracks the requested outcome and unresolved access and model decisions.
- `feature-parity-ledger.md` maps retained, excluded and unresolved feature groups to implementation evidence and missing acceptance checks. Paid status does not exclude local capabilities.
- `catalog-current-feature-map.md` groups all 1014 current text keys; `catalog-feature-map.md` retains the earlier 997-key map. Labels do not prove reachable workflows or defaults.
- `feature-findings.md` and `native-findings.md` map wrapper and native boundaries.
- `driver-runtime-findings.md` records the original devices' observed declarations.
- `ui-runtime-map.md` maps observed settings and separates current saved selections from unknown defaults.
- `audio-controls-findings.md` maps original mute, volume curves and device-control boundaries, including unresolved runtime state.
- `recording-findings.md` separates original recording features and documents the observed native recorder contracts.
- `noise-test-findings.md` records original temporary comparison labels and separates them from independent capture and duration choices.
- `model-provider-contract.md` records the installed addon's recovered call contracts and bounded model-loading probes.
- `cloud-exclusion-map.md` traces identified telemetry and remote-service boundaries with coverage limits.
- `parity-verification-plan.md` defines the comparisons still required.

The reconstruction excludes cloud storage, account services, meeting bots, report uploads, and analytics. Both an independent engine and an optional installed-model path are in scope. Bundled Krisp code, models, icons, and raw evidence have not been placed in a public release. Git ignores the private evidence and analysis runtime directories. The requested original-weight publication still requires established redistribution terms. The independent RNNoise source and included model retain their upstream notices under `app/noise-engine/vendor/rnnoise`.

This private repository is an unfinished source checkpoint, not a parity release. It remains in the lab experiment directory.


## Recording verification checkpoint

The root `./verify` passed all ten suites with exit 0 after recording integration and lifecycle fixes. Private log: `evidence/combined-verify-recording.log`. The desktop has 32 passing tests. Synthetic Swift-to-C++ pipe tests validate recording commands, PCM16 finalization, active-frame duration and history import. The signed app build and relocated-resource checks pass. No actual audio was captured. The approved driver installation and CoreAudio restart succeeded, but exact endpoint lookup failed, so real routing remains untested pending registration diagnosis.


## Temporary microphone comparison verification

The combined `./verify` passed all ten component suites after temporary microphone comparison integration, with 46 desktop tests and signed-bundle checks. Synthetic tests cover the Original/RNNoise pair, cancellation, capture ownership and cleanup retry. Private log: `evidence/combined-verify-microphone-test.log`. Actual microphone capture, audible comparison and permission attribution remain untested. The driver diagnostic restart remains deferred while the user is away.


## Library-location verification checkpoint

Implemented persisted existing-folder selection and reopen without data migration or fallback. Shared admission covers active library work, transcription, capture and recording; stale dialogs/results carry revision checks. Recording preparation validates and retains the admitted destination store through final save, rejects same-path replacement and retains failed staging. Missing or invalid preferences remain recoverable through the chooser.

The root `./verify` passed all ten component suites with exit 0, including 54 desktop and 12 local-store tests. Eight focused desktop location tests cover real temporary library imports, restart persistence, missing-folder recovery, stale dialog/results, cancelled authorization and replaced recording destinations. Both independent reviews accepted the changes. Private log: `evidence/combined-verify-library-location.log`. Native picker interaction, real audio routing and original parity remain unverified. No administrator or live audio action ran.


## Local diagnostics checkpoint, 2026-10-15

Implemented private local report export with bounded typed current-run events/status, optional occurrence date/system metadata and an explicitly selected PCM16 mono/stereo WAV sample. Existing destinations and replaced output directories fail without overwriting user files; cleanup tracks owned files. No cloud upload or automatic capture exists.

Desktop `./verify` passed 68 tests plus signed ARM64/macOS 12 packaging and relocated-resource checks. Other nine components remain unchanged from the preceding combined verification. Private log `evidence/desktop-verify-diagnostics.log`, SHA256 `fb545d92a705ccaf2b38318016fe61b8f46714fd534bd9402a31da8d2aba090b`. REA opened Settings/Diagnostics and observed the native form/current status with audio stopped (evidence `ev_c6e9c71877d065d8aee3a404e566c8bc43611817c26e89c4e7011e48d7899d5b`). Save/sample picker workflows, historical log parity and original report schema remain unverified. No audio or administrator action ran.


## Launch-at-login verification

Added explicit ServiceManagement registration controls with actual OS status and activation refresh. macOS 12 reports this feature unavailable. Desktop verification passed 73 tests and packaging checks. Native registration, approval and launch after login remain unverified; development did not change login items. See `startup-findings.md` and `CHECKPOINT.md`.


## Finalized recording recovery

Audio can review retained independent recording folders and explicitly save a copy of validated finalized audio into the selected library. Sources remain untouched. Partial WAVs and `.pending` imports are not repaired. Desktop verification passed 86 tests and packaging checks; native recovery UI and real audio remain unverified. See `recovery-findings.md` and `CHECKPOINT.md`.


## Save before quit

Normal Quit now confirms Save and quit for active recordings and checks that saving succeeded. Failed saves keep the app open. Pending library/recovery/diagnostic work blocks quit, and shutdown blocks new work. Desktop verification passed 97 tests and packaging checks. Native dialogs and actual OS termination remain unverified. See `quit-findings.md` and `CHECKPOINT.md`.
