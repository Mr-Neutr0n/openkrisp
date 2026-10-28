# OpenKrisp feature parity gap ledger

This is a scope and acceptance audit, not a completion claim. All **1014 current catalog leaves** are assigned exactly once to **32 workflow families** in [feature-parity-ledger.json](feature-parity-ledger.json). A leaf is supporting text, not one feature. The ledger separates implementation presence from verified behavior and records source fingerprints at this snapshot.

**22 families remain retained, 6 have unresolved local/service or platform contracts, and 4 describe excluded services.** These counts are assignment totals, not coverage percentages. Paid, hidden, trial or admin labels never exclude the underlying local function. Exclusions cover vendor accounts/billing enforcement, cloud/bot services, remote support/sales submission and analytics/telemetry. Established local capabilities stay in scope. Replacing a cloud-backed function with a new local adaptation is an optional recommendation, not a confirmed requirement.

Current labels come from REA Evidence `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4`; current app version 3.17.9 is bound to plist Evidence `ev_3a54568811b26cf5484325645d4ec772d8a425f658baf6e523ffd035b522b820`. Historical partial JavaScript Evidence `ev_a171e77e361a92e3a14ece5a0d849dd226d5669aaa7a8dbc9bafd807200e54ca` remains bound to ASAR SHA-256 `fbd6a39ce6fde8685c6ca4c2ca78343aa50551b1bac74f532fd6c5801a23b622`. Current native contracts use their separate recorded digests. The JSON registry gives exact identities and limits; an old symbol or label is not proof of current execution.

## Implemented pieces and acceptance gaps

| Workflow | Independent code present | Missing acceptance or behavior |
| --- | --- | --- |
| Physical/virtual audio routing | HAL, shared transport, route helper and explicit device UI | Installed synthetic HAL admission, actual routing, permission attribution, timestamps, concurrent clients, unplug/crash/recovery and latency. |
| Mic/speaker NC | Independent RNNoise path | Actual routed samples and speech quality. AEC, BVC and original installed-model processing are not supplied by RNNoise. |
| Gain/mute | Live ACK-based app-route linear attenuation | Actual sample result and OS behavior. Original nonlinear HAL curve, hardware mute/gain, lock level and sync policy remain absent. |
| Audio recording | Explicit processed stereo headroom mix, pause/resume, writer and local save | Real user recording path and saved output. Original mix/order, in-person live mode, scheduled association and save/switch remain missing. Classify the original four-hour limit; do not import a usage quota. |
| Local history/storage | Staged sessions, history/import/playback/export/delete and validated existing-folder chooser with path persistence, revision/admission guards, recording destination pinning and explicit finalized-stage copy | Desktop86tests/packaging reported pass; native chooser/recovery UI, actual unavailable-volume/disk-full behavior and incomplete-file salvage remain unverified. Independent schema is not original-file compatibility. |
| File transcription | Explicit selected-WAV Apple on-device request and language selection | Real OS recognition, assets and accuracy. Live ASR, diarization, transcript-only capture and live pause/resume are absent. |
| Model selection | Explicit metadata discovery/hash/manifest UI | Integrated installed or arbitrary independent inference. Persistent and supervised-worker NC/bypass probes produce 48,000 finite samples matching single-call outputs. A broker thread connects callback queues to the worker. Timed CPU probes and native parent-loss tests pass; the 120 ms test buffer is not accepted live latency. Desktop/CoreAudio integration is absent. Both latest timed captures have verified cleanup. Speech quality, timing, tail handling and app integration remain unverified. |
| Appearance | Persisted System/Light/Dark | Current interactive/visual parity. Original default remains unknown. |
| Floating widget | Stable shared NSPanel, persisted explicit show/hide, actual route/recording state, mute status and Stop | Desktop verify passed 36 tests per root/worker checkpoint. Native panel/visual runtime untested. Call-auto-show, hide-for-now restoration, meeting title/time, talk time, captions and speaking assistance are missing. |
| Microphone NC test | Selected first-channel temporary capture, same-input original/RNNoise pair, five-second minimum, cancel/Done and A/B playback | Backend synthetic release/sanitizer/pipe tests and desktop46tests reported passing. Actual capture/playback, native UI, OS attribution and original test DSP contract remain unverified. |
| Local diagnostics | Explicit private report folder, current typed status/recent event codes, optional occurrence date/system metadata and explicit selected WAV copy | Desktop68tests/packaging reported pass. Native pickers, production filesystem failures, historical logs, original report schema/options and full taxonomy remain unverified. No upload or active network/HAR collection. |
| Lifecycle | Helper handshake, bounded shutdown, parent-loss handling | Startup login item, sleep/wake, save-before-relaunch and installed failure behavior. |

Existing builds and injected tests verify their stated contracts. They do not establish runtime feature parity. This audit did not launch an app, run real audio, install a driver, change original settings or publish anything.

## Paid, hidden and unresolved candidates

- **Live captions:** paid-plan text is evidence of a gate, not a reason to exclude captions. Mac reachability is uncertain because Windows runtime text also appears.
- **Local recording and storage:** “Audio Record” upgrade text and “Business plan” local-storage text do not carry into OpenKrisp. Folder selection and independent busy-operation locking are now implemented and fixture-tested. Finalized-stage explicit copy is now synthetic-tested. Native picker/recovery UI, original call-detection parity, incomplete-file salvage and LocalStore .pending recovery remain unverified or unimplemented.
- **Screen recording:** paid text alone does not exclude a local capability. The original on-device-storage restriction leaves the local/cloud boundary unresolved. A new local replacement is optional, not a confirmed requirement.
- **Accent conversion:** microphone and others' accents, visibility preference, variant preparation, headset constraints and original/converted tests. Coming-soon language/variant labels are not proven capabilities. No model conversion inference is implemented.
- **Background voice cancellation:** headset detection, manual activation for unrecognized devices and nearby-speaker isolation. Administrator headset policy is removed; local compatibility and quality are not assumed.
- **Voice Translation:** a diagnostic label and current native translation/playback handlers support an unresolved candidate. Language directions, ASR/TTS contract, service dependence and Mac UI remain unknown. No implementation exists.
- **AI notes, summaries, recap and insights:** audio privacy text does not prove local summary generation. Investigate and retain proven local behavior; remote generation is excluded. A new independent local summary engine is a recommended option, not a confirmed requirement.
- **Live meeting ASR and speaker identification:** selected-file transcription does not provide live capture, diarization, transcript-only mode or automatic meeting save.
- **Performance and audio policy:** Auto/CPU Optimized/Best NC, default restore, AEC, Noise Shield intensity feedback, optimal mic locking and synchronization remain absent.
- **Meeting automation:** call detection, blocked-app list, competing-call switch, agenda/filter/join reminder boundary investigation, in-person notes and call-time preference locking.
- **Participant reminders and announcements:** templates, countdown, skip/cancel and microphone/setup failures, implemented locally without automatic external messages.
- **Widget insights and lifecycle:** measured talk time, speaking assistance, next-call visibility, meeting title/time, actual launch-at-login acceptance, meeting-window startup and sleep/wake.
- **Tests and diagnostics:** the temporary five-second original/RNNoise comparison is now implemented and synthetic-tested; live and visual acceptance remain pending. An independent current-run diagnostic report is now implemented and fixture-tested. Historical logs, detailed troubleshooting/repair and original developer/reload actions remain outstanding. The original user-selected file upload, developer/reload menus and service-specific network diagnostics need explicit contract decisions.

## Corrections to the prior map

The old account-policy family held 94 labels. Concrete local gate-related labels now support their local family; generic subscription/authentication decorations remain excluded only as gate UI. The new version adds organization/version restrictions, which do not become independent local availability restrictions.

The old bot substring rule incorrectly grouped `report_problem.accent_robotic_voice` and `report_problem.others_state_my_voice_robotic` as cloud bots. They are now local diagnostics. Generic “Manage preferences” and “Finalizing AI setup” no longer prove cloud-only execution. Shared refresh/update labels were reassigned by their actual text. Voice Translation and file upload now have explicit unresolved workflows rather than disappearing inside diagnostic/menu buckets.

The unresolved families are agenda/calendar source, screen capture, summary generation, service connectivity/proxy distinctions, Voice Translation and original file processing/upload. Investigate their local/service boundaries. Proven local behavior remains retained; local replacements for cloud-backed functions are optional recommendations requiring a later scope decision. Exact quotes, every assigned key, implemented files, verification limits and missing acceptance are in the JSON. Silent telemetry has a separate excluded family despite having no catalog leaves; the catalog cannot establish its absence.

The original live/in-person four-hour limit is a reference observation, not an unconditional implementation requirement. Its cause remains unknown. Distinguish a genuine resource/format constraint from a commercial quota. OpenKrisp adds no usage quotas; any independent technical bound must be explained on its own evidence.


## Temporary microphone-test checkpoint

The independent microphone test uses exact selected physical UID and first input channel without changing hardware rate/default/volume. Both original and RNNoise files derive from the same bounded captured samples. Capture minimum is five seconds by frame count; maximum is an independent sixty-second memory/processing bound. Route-stopped admission is an independent ownership policy, not a recovered original call restriction. The output trims the known 480-frame streaming-adapter buffering, without claiming total algorithmic delay compensation.

A completed comparison requires successful capture teardown, private exclusive paired WAVs, matching helper identity/result, clean child exit and exact owned-path media validation. Cancellation waits for child exit before removing owned files and retains ownership when cleanup is uncertain. Playback is explicit; no history session or upload is created. Backend worker reports synthetic release/sanitizer and production-loop pipe suites passing, and desktop verification reports 46 tests plus packaging passing. This read-only review found no remaining material issue in the stated scope. No native capture, playback, UI or permission action ran in the review or those fixtures. Root's combined `./verify` completed with exit 0 across all ten suites, including 46 desktop tests. The retained log is [combined-verify-microphone-test.log](evidence/combined-verify-microphone-test.log). This confirms synthetic/build checks only.


## Local storage-location checkpoint

Settings can now choose and reopen an existing independent library. Admission succeeds before the saved path changes. Missing, inaccessible or malformed saved locations show an error without falling back or creating a replacement. Choosing a library moves or deletes no data and changes no existing directory permissions. Shared admission prevents switching under active app audio, microphone tests, recording, import or transcription. Dialog revisions and stale-result checks prevent a delayed old-library action from targeting the new folder. Cancelling an authorization wait releases only that operation's lease.

Recording validates and retains its destination LocalStore before capture; disappearance or replacement fails save and retains staging. General history reopening remains path/revision based. Stored paths are not security-scoped bookmarks or permanent volume identities. These are independent decisions; the original migration, reopen, persistence and default-folder contracts remain unknown.

The stable source review found no remaining material issue in this scope. Desktop verification passed 54 tests and packaging; eight focused location tests also passed. Root's combined `./verify` completed with exit 0 across all ten suites, including 54 desktop tests. Its log is [combined-verify-library-location.log](evidence/combined-verify-library-location.log). Tests use independent temporary files and injected work, without original UI, native folder-picker interaction, real audio, calls or administration. Actual native chooser rendering, removable-volume recovery and disk exhaustion still need acceptance. No original/runtime parity pass is claimed.


## Local diagnostics checkpoint

Settings now exports a new private local folder containing `report.json` and, only after explicit file selection, `sample.wav`. The independent report uses typed current status and bounded recent event codes, plus the user's description. Optional occurrence date and macOS-version/architecture fields default off; the sample defaults to none. Date is user metadata, not a recovered historical-log filter. The supported sample is a validated finalized PCM16 mono/stereo RIFF/WAVE copied without source mutation. There is no automatic capture, history scan, vendor-log access, upload, telemetry or network/HAR collection.

The output format and defaults are independent choices. The original “Include the sample recording” label does not establish its source or whether it only affected submission. The app accurately calls this current-run diagnostics, not historical crash logs. General attachments, full original subcategories and historical log collection remain absent.

Read-only review found no remaining material issue within snapshot, explicit optional content, exclusive/private output and identity-owned failure cleanup. Core cancellation tests do not imply a cancellation UI. Worker reports final desktop `./verify` passed 68 tests plus signed release/resource checks, with local log `app/desktop/.build/diagnostics-verify.log`. Root confirmed the desktop log: 68 tests and packaging passed. Other nine components are unchanged from the preceding combined pass. Root REA subsequently opened the native Diagnostics tab and observed its form/current status with audio stopped; save/sample picker workflows remain unverified. No native UI picker, user recording, real audio or original/runtime parity test ran in this review.

## Launch-at-login checkpoint

Settings now provides explicit `SMAppService.mainApp` launch-at-login control on macOS 13 and later; macOS 12 reports unsupported. The shared controller reads actual OS registration status, preserves approval-required and unknown states, and stores no substitute desired preference. Initialization, refresh and activation do not register the app. This change adds no automatic audio or recording activation and does not implement the separate original meetings-window launch preference. Original startup defaults and hidden/window behavior remain unknown; see [startup-findings.md](startup-findings.md).

Five injected-service tests cover statuses, explicit actions, approval, failures, stale refresh, duplicate admission and activation refresh. Read-only review found no material issue. Worker reports full desktop `./verify` exit 0 with 73 tests plus ARM64/macOS 12 release, signature and resource checks; local log `app/desktop/.build/startup-verify.log`. Actual registration/unregistration, approval UI, login/reboot and native Settings interaction remain unverified. Lifecycle parity remains partial. The ledger records 54 independent implementation fingerprints at this checkpoint.

## Finalized recording recovery checkpoint

Retained independent staging folders can now be reviewed and explicitly copied into the current library. Only unchanged finalized private 48 kHz stereo PCM16 WAVs are eligible. The source remains untouched, each confirmed copy creates a new session, and no manifest selects arbitrary source paths. Shared capture/library admission prevents recovery during active capture and pins the library across asynchronous work. Stale review/confirmation results cannot redirect a save. Unconfirmed temporary cleanup identifies its path and distinguishes successful publication from copy failure.

Read-only review found no remaining material issue in this scope. Nine backend filesystem tests and four controller tests passed; worker reports final desktop `./verify` exit 0 with 86 tests plus signed release/resource checks, log `app/desktop/.build/recovery-verify.log`. All files are synthetic. Partial-WAV salvage, LocalStore `.pending` recovery, original crash parity, native recovery UI and live audio remain unverified or unimplemented. See [recovery-findings.md](recovery-findings.md). The ledger now records 58 matching implementation fingerprints.

## Save-before-quit checkpoint

Normal application quit now offers Save and quit or Cancel for a busy recording. It requires library publication as well as helper shutdown; failed save or uncertain cleanup keeps the app open and preserves retained files. In-progress library/import/recovery work and diagnostic export block quit without interruption. Shared admission prevents new work during finalization. This independent preservation policy does not add automatic discard or establish original failure semantics.

Eight coordinator/gate tests and three independent route/recording integration tests passed. Read-only bounded review found no remaining material issue. Worker reports desktop `./verify` exit 0 with 97 tests plus ARM64/macOS 12 signed release/resource checks, log `app/desktop/.build/quit-verify.log`. Native confirmation prompt, actual termination, process logout, forced kill and interrupted OS shutdown remain unverified. Relaunch/save and sleep/wake remain separate gaps. See [quit-findings.md](quit-findings.md). All 61 implementation fingerprints match this checkpoint.

Native installed-model investigation: [factory](native-frame-factory-findings.md), [frame processing](native-frame-processing-findings.md) and [configuration](native-nc-configuration-findings.md) now have static REA contracts. Installed-model inference remains isolated-probe-only, with no completed native output.

The next static pass establishes [synchronous dispatch](native-frame-dispatch-findings.md), [descriptor values and lifetime](native-descriptor-lifetime-findings.md), and [selected close semantics](native-stream-close-findings.md). The selected NC finalizer does not flush delayed output. Native runtime inference remains unverified.

Experimental [native probe support](app/native-model-probe/README.md) now validates borrowed-result copying and output bounds in independent fixtures. This does not load Krisp or establish installed-model inference.

[Actual native processing evidence](native-direct-probe-findings.md) now supersedes earlier load-only statements for the selected installed outbound NC model. This remains an experimental isolated provider, not desktop feature parity.


## Callback buffering and route preparation

Runtime buffer configuration and a pre-IO processor factory now exist. REA NC tests at 30/50 ms explicit queue delay passed with unchanged aligned output. Audio-host bounds and lifetime fixtures passed. The provider is still unconnected to desktop routing, and these short CPU captures do not establish live latency or full parity. See `CHECKPOINT.md` and `native-direct-probe-findings.md`.


## Installed outbound provider integration

The desktop now admits an explicit installed outbound NC microphone provider and checks its helper startup identity. Speakers retain RNNoise. Synthetic bridge/lifecycle tests, 104 desktop tests and signed-resource checks pass. REA verified packaged-worker NC/bypass output against earlier probes. Actual HAL routing, quality, sustained latency and full parity remain unverified. See the latest `CHECKPOINT.md` entry.


## Inbound evidence and worker admission, 2026-10-18

The exact inbound model has bounded direct mono processing evidence. Its NC capture has unresolved REA cleanup; the bypass capture completed. Static evidence establishes stereo averaging into one mono state and duplicated output in the selected original KMS bridge. See [inbound-model-findings.md](inbound-model-findings.md) and [native-speaker-channel-findings.md](native-speaker-channel-findings.md). Original desktop topology and complete stereo runtime parity remain unresolved.

Native admission now binds explicit outbound/inbound roles to exact model hashes and role-bearing readiness. The microphone adapter remains outbound-only. Native, host and desktop verification passed; 116 source fingerprints match. Speaker integration, live routing and full local parity remain incomplete.


## Installed speaker integration, 2026-10-18

The desktop and host now support independently selected installed outbound microphone and inbound speaker NC. The speaker adapter uses the recovered stereo average and duplicated mono output, with a separate stateful worker. Startup and acknowledgement validate each lane. Synthetic tests cover channel arithmetic, callback partitions, invalid input, partial startup and both-worker cleanup. Desktop verification passed 109 tests and signed packaging checks. All 117 source fingerprints match.

A paced inbound CPU helper returned the direct probe's output exactly with zero queue deadline faults, but REA ownership cleanup was incomplete. No original stereo comparison, dual installed-worker adapter runtime or physical route has passed. The ledger's earlier metadata-only installed-provider status is corrected to partial integration.


## Dual installed-model runtime, 2026-10-18

The production dual adapter completed a paced CPU run using both installed models, with complete REA cleanup. Both workers processed 105 frames and shut down cleanly. Microphone output and deinterleaved speaker output match their direct-model baselines byte for byte. See [dual-installed-adapter-findings.md](dual-installed-adapter-findings.md). All 118 source fingerprints match. This does not prove live routing, complete original stereo behavior, sustained scheduling or quality. Native UI acceptance remains pending an unlocked Mac session.


## Save and relaunch and original audio contracts, 2026-10-18

The app menu now offers Relaunch Lab Voice. An active recording requires Save and relaunch or Cancel. The shared quit transaction confirms library publication and stopped audio before opening a new instance of the current bundle. Confirmed launch closes the old instance; failure keeps it usable. An uncertain returned identity blocks further relaunch attempts in that instance while allowing normal quit. No audio-resume arguments are passed. Original discard and failure semantics remain unresolved.

Independent review found no actionable issue. Final desktop `./verify` passed 117 tests, signed ARM64/macOS 12 packaging and relocated resources. The save-before-launch integration uses production RecordingStorage and LocalStore with a synthetic WAV and checks byte-exact publication inside the launch callback. Private log `evidence/relaunch-desktop-verify-20261018.log`, SHA256 `fa03065451fbad605fc60471b38934c0755101597d8b577a348ceb48ce3ff963`. Native launch, replacement UI readiness and prompts remain untested. Launch Services has no callback deadline in this implementation. Other components are unchanged from their preceding verification.

`original-speaker-graph-findings.md` binds the current 3.17.9 desktop speaker graph to default 48 kHz stereo Float32 and conditional inbound NC. BVC, accent, suspension and pass-through remain separate branches. The packaged microphone default is 32 kHz mono; effective overrides and the native processor-factory join remain unresolved. This does not establish full original runtime parity.

`native-echo-contract-findings.md` establishes shared AEC state, separate forward/reference specifications, 10 ms Float32 calls and the direct factory ABI from nine successful static REA captures. Current full AEC-library SHA256 is `bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a`. No AEC runtime, hardware audio or administrator action ran. An independent foreign-ABI fixture is the next step. Full retained-feature parity remains incomplete.


## Independent AEC interface fixture, 2026-10-18

The native probe suite now includes a separate synthetic AEC library and consumer. It checks the 24-byte ARM64 stream specification, selected virtual slots, 100 paired frames with separate 32 kHz mono forward and 48 kHz stereo reference inputs, in-place output and malformed-input rejection. These rates are fixture bounds, not verified vendor support. The library remains loaded until engines and caught foreign exceptions are destroyed. Review identified and fixed the error-path unload order; forward and reverse exception tests cover it.

Independent review found no remaining actionable issue. Focused release and ASan/UBSan checks passed. No original library, audio device, network or administrator action was used. This is experimental probe support, not a production echo canceller. The next runtime investigation must pin the current AEC library and establish actual supported frame combinations, reference timing and output behavior through REA before integration.

Complete native-model-probe `./verify` passed, including existing release, sanitizer and thread-sanitizer suites. Private log `evidence/aec-fixture-verify-20261018.log`, SHA256 `e938d9faae83810f9ad4261d4aa5edf184dc59f3627c62a8d082c2e6835ada26`. All 123 tracked implementation fingerprints match this checkpoint.


## Installed AEC direct CPU checkpoint, 2026-10-18

A standalone probe now calls the installed AEC library through its reviewed factory and Float32 interface. REA capture `ev_dc0785e71d0f2a842f97891ee8393ea074fd739ebe64ce0857c2aa60d4051547` completed with exit 0, no output truncation and verified owned-process cleanup. The deny-network runner confirmed EPERM before loading and matching library/executable hashes before and after execution. Both fresh engines accepted 300 forward/reference frame pairs, with all 600 calls per engine successful and finite output. Engine destruction and library unload preceded output publication.

The three-second synthetic fixture uses 32 kHz mono microphone input and 48 kHz stereo reference input. It compares a matching reference against zero reference with the same delayed multitone microphone signal. Last-second reference-on RMS was 0.0452617 versus 0.0456945 with zero reference. This establishes bounded direct processing, not useful echo suppression or quality parity. No production AEC, physical route, near-end preservation or original scheduling acceptance is claimed. See `aec-direct-runtime-findings.md` for exact identities, metrics and the next diagnostic.

Own-fixture release and ASan/UBSan tests plus the complete native-model-probe `./verify` passed. Independent review found and resolved output rollback ownership before execution. Full verification log `evidence/aec-direct-full-verify-20261018.log`, SHA256 `bffbb95e8f83e96d4d541d58098b6710e8683bbceb90574bc5faa221fdb7c068`. The captured executable SHA256 is `a2af66b94e4fe910dbf197bd0513b1aa47f00dbf2e614f13b4a234cd24b1763f`. Other component sources are unchanged. All 125 ledger source fingerprints match. Original assets remain external and excluded from Git.


## Broadband AEC checkpoint, 2026-10-23

The interrupted broadband probe work is complete. Default multitone behavior remains available; `--broadband` uses a deterministic shared 16 kHz source resampled to 32 kHz mono forward and 48 kHz stereo reference over ten seconds. Echo delay remains 50 ms at gain 0.6, reference-first scheduling remains explicit, and no delay/config controls change. Own-fixture tests verify all sample phases, initial silence, repeatability and both modes' failure cleanup.

REA `ev_52353b42ce417d7c11c774d3a72032a050eabfe841d20c5b7dd6933dcadd765a` completed both fresh engines with 2000 successful calls each. Library and executable before/after hashes match, outputs are finite, capture is not truncated and owned-process cleanup is verified. Two unrelated platform processes had unverifiable ownership and were left untouched. No hardware audio or administrator action ran.

Final-second matching-reference RMS was 0.005172412 versus 0.037591950 with zero reference, a 17.228 dB level reduction for the echo-only fixture. The weaker earlier multitone result remains valid for that different stimulus. Bounded zero-reference correlation peaks at 261 samples with normalized correlation about 0.695, which does not establish exact physical latency. See `aec-broadband-runtime-findings.md` for hashes, window metrics and limits. Next validate independent near-end preservation during simultaneous echo before production AEC integration; this result is not speech-quality or full parity acceptance.

Independent source review and full native `./verify` passed, including both probe modes in release and ASan/UBSan. Frozen executable SHA256 `5299da0d23048a98d68a448e634bab3d1cb63af25d7d9764c80b4f43aee8f32d`. Private verification log `evidence/aec-broadband-verify-20261023.log`, SHA256 `bffbb95e8f83e96d4d541d58098b6710e8683bbceb90574bc5faa221fdb7c068`. All 125 ledger source fingerprints match. Other components are unchanged.


## Synthetic double-talk checkpoint, 2026-10-23

A separate four-engine probe now compares mixed echo/independent near-end input with actual and zero reference, plus isolated near-end and echo zero-reference controls. The independent near signal begins after three seconds; all signals are deterministic noise, not speech. Every engine uses the existing 32 kHz mono/48 kHz stereo contract, fixed 50 ms echo delay and unchanged AEC settings. Outputs publish only after destruction and unload, with private directory and file identity checks.

The installed probe returned four sets of 2000 successful calls and finite outputs with matching pre/post hashes. However, REA returned `cleanup_incomplete` because it could not read an ownership token for candidate PID 9800. A read-only process check identified that candidate as a Chrome renderer in another process group; no signal was sent. The temporary capture root remains retained. This is a partial observation, not a successful Evidence ID or fully verified cleanup. Result `evidence/model-probes/aec-doubletalk-20261023-v1.result.json`, SHA256 `85cfd63aa4eb861bd9686759f1e137692c24f10b02d1d72e299be0ddf26f5264`.

In the final second, zero-reference mixture differs from the sum of isolated controls by about 0.0585% of mixture RMS. A centered fit of matching-reference output onto those controls gives a near coefficient about 0.074 and echo coefficient about 0.004, but normalized residual about 0.889. These are projections, not physical component percentages. Independent noise preservation is not established. Synthetic speech or a reviewed speech-like input is the next diagnostic; do not infer call quality from this noise-only test. See `aec-doubletalk-runtime-findings.md`.

Independent source review and full native `./verify` passed, including release and ASan/UBSan double-talk fixtures. Verification log `evidence/aec-doubletalk-verify-20261023.log`, SHA256 `9915006b0acf36e17eed5dd54c53c66f2e61cb7f60e7c9ff5f23f19fa3b51382`. Frozen executable SHA256 `56fded91425e233ffe847382c004620499c904934f496c529005f58a2f6fc682`. All 127 implementation fingerprints match. No production AEC integration, hardware audio or administrator action ran.


## Synthesized speech AEC checkpoint, 2026-10-23

The double-talk probe now optionally accepts an explicit finite Float32 near-input file with exactly 320000 samples and three seconds of initial silence. It snapshots identity and checks for observed changes through publication; default noise remains unchanged. A local Samantha voice rendered the complete test sentence to a 32 kHz mono file under a deny-network sandbox, without microphone capture or playback. Its 133018 samples were scaled to RMS0.0375 and placed after three seconds, with zero padding and no cropping. Generated audio remains private and excluded from Git.

REA `ev_d716ac105235d05154a1eae75f0c558df700d2623033dd93000378c85f1ffbb3` completed all four engines with 2000 successful calls each, finite outputs, matching library/executable/input before/after hashes and verified owned cleanup. Two unrelated platform processes were left untouched. In full speech windows3..6, projections onto processed controls give near coefficients0.760..0.875 and echo coefficients0.0126..0.0183. Normalized fit residuals0.350..0.452 remain material. These are synthetic control projections, not speech-fidelity percentages. The speech result is more favorable than independent noise, but neither transparent audio nor real call quality is established. Window7 is only partly active; windows8/9 have no near speech and are excluded from near preservation fits. See `aec-speech-runtime-findings.md`.

Independent review and the full native `./verify` passed, including release/ASan/UBSan external-input and mutation tests. Log `evidence/aec-speech-verify-20261023.log`, SHA256 `9915006b0acf36e17eed5dd54c53c66f2e61cb7f60e7c9ff5f23f19fa3b51382`. Frozen executable SHA256 `ebb940ad1b257412135ba529a6a8df034b0f6f528cbbb5fb8bb651abdd476caa`; retained near input SHA256 `e0ef3b22cc3d37ec9b30d22ee87985ba9a1ba64f68ca9e6fda4628ac934a4a27`. All127 source fingerprints match. Production AEC and physical audio acceptance remain outstanding.


## Host-rate AEC gate, 2026-10-23

The double-talk probe now accepts only explicit forward rates 32000 or 48000, preserving 32000 by default. All forward dimensions, initial silence and echo delay derive from that selected rate; reference remains 48 kHz stereo. The same speech utterance was converted from 32 to 48 kHz with `afconvert`, retaining the prior gain and complete utterance, then padded to 480000 samples with onset 144000.

REA `ev_c7c288999c223b88f07d2b8204b1619118551b8a36f5be48801830cedb4af486` completed four fresh engines at 48 kHz forward/48 kHz reference, each with 2000 successful calls. Outputs were finite, before/after hashes matched, capture was not truncated and owned cleanup was verified. Three unrelated platform processes were left untouched. In full active speech windows, near-control projections are 0.788..0.866, echo projections 0.0036..0.0170 and normalized residuals 0.363..0.433. Zero-reference additivity residual is about 2e-7 of mixture RMS. This establishes the tested host-rate interface, not transparent quality or live timing. See `aec-48k-runtime-findings.md`.

Both rates passed own-fixture release and ASan/UBSan tests, independent review and full native `./verify`. Private log `evidence/aec-48k-verify-20261023.log`, SHA256 `ffccc57c28a42a2b53f80e9e3000340d1c03164b1ad66aab85f1f0429210eed3`. Frozen executable SHA256 `f3ffb34d885f259307fa9ca9e11f831d4c0dbbc2aa47fd7bea4dafd4d19d7fc3`; 48k near-input SHA256 `72b535a052e7d4995f13186557f346bd0ca206f3c713f3585995005290c081a1`. All 127 source fingerprints match.

### Concrete duplex integration plan

The 48k gate clears the need for a resampler in the initial independent worker. Add a separate versioned duplex protocol carrying 480 mono microphone and 960 interleaved reference values, per-lane sample origins, host-time validity, epoch and sequence. One persistent engine must analyze reference then process microphone. Reuse bounded SPSC/broker/parent-watch ownership patterns without changing existing NC wire semantics. All native calls, IPC and teardown stay off callback threads.

Current `routing.cpp` runs combined mic/speaker DSP before applying controls. For optional AEC, initially disable mic NC and let existing DSP produce only speaker output plus raw mic. Compute final controlled speaker samples into preallocated storage and use those exact samples for both hardware output and AEC reference. Never feed raw monitor or speaker output before gain/mute. The current final-state recheck can overwrite playback with silence after DSP; reference submission must follow the same commit decision or close its epoch. Do not enqueue nonzero reference then overwrite playback with zeros.

Keep input/output sample origins distinct, including fractional offsets. Validate each lane's continuity before advancing state; discontinuity/restart ends the epoch. Pairing is callback correlation, not proof of equal acoustic time. Preserve microphone capture timestamps through output queue delay and use scheduled final playback timestamps for reference. Existing NC queue delay may reach 120 ms at a 4096-frame bound; duplex capacity and delay need their own measured acceptance. Later AEC-to-NC requires separate speaker/microphone stages, because calling the combined adapter twice advances both lanes twice.

Required integration tests include reference byte equality with actual controlled stereo output, speaker delay/mute, irregular callback partitions, unequal lane origins, clock jumps, epoch loss, deadline/malformed worker responses, silence on failure and final shutdown, callback allocation guards, AEC-off unchanged behavior, and retained ownership through failed HAL cleanup. Physical acoustic timing and live double-talk remain outstanding.


## Persistent duplex AEC worker checkpoint, 2026-10-23

A separate native worker now keeps one AEC engine for a fixed 48 kHz mono microphone and stereo playback-reference session. Its versioned protocol carries 480 microphone and 960 reference samples, token, sequence, epoch and per-lane sample origins/host-time flags. Both broker and worker reject timestamp discontinuity or epoch changes; a new epoch needs a fresh worker. Each frame runs reference analysis before forward processing. Existing NC behavior and live routing are unchanged.

The worker checks a caller-supplied library SHA256 and network-denial EPERM before loading. ParentWatch also exits the worker if its expected parent disappears while foreign processing is blocked. Explicit close destroys the engine and unloads the library before acknowledgement. The broker checks acknowledgement identity, EOF and exit status, enforces bounded operations and owns only its direct child's cleanup. These are generic worker checks: a fixed vendor/executable admission launcher is still required. File hash sampling is not an atomic binding to loader reads.

Three GPT 6.1 sol workers implemented the native worker, protocol/broker and independent review. Review found and resolved native lane-continuity validation and close-ACK epoch validation. Full native-model-probe `./verify` passed, including release and ASan/UBSan persistent-worker tests, malformed stream/failure cases, blocked parent-loss containment and 37 end-to-end broker/native-worker/own-library frames. Existing native checks also passed. Log `evidence/aec-persistent-verify-20261023.log`, SHA256 `92c2ae594ab71baf0a8941b5d884559b418acb7c3a16bffd8bc98e365da63dd1`. All 136 implementation fingerprints match. No installed library, physical audio or administrator action ran for this checkpoint.

Next: add a fixed-library and admitted-executable launch boundary, then use REA for a bounded installed-library worker capture against the retained 48 kHz speech fixture. Compare its output with the direct baseline before implementing callback buffering and final-playback reference routing. Real-time deadlines, physical acoustic timing, quality parity and full local feature parity remain incomplete. Original libraries/models remain external and excluded from Git.


## Installed AEC worker runtime checkpoint, 2026-10-23

The new launcher hashes the actual worker executable before constructing its command, supplies the fixed reviewed AEC library hash, and uses an exact clean environment inside the deny-network sandbox. The bounded runtime probe admits exact finite 480000 microphone and 960000 reference samples, sends 1000 continuous frame pairs, and publishes output plus metadata only after close acknowledgement, EOF and exit zero. Inputs are checked for observed changes. Publication uses a held staging directory descriptor and exclusive rename. File hash and path checks remain sampled, not atomic loader/spawn binding.

REA `ev_1e44c445f3046272d10ccf5d66e835c8156f15fbc15f4a579d2015f4b3971acd` completed with exit zero, no truncation, verified owned-process cleanup and removed temporary root. One unrelated process with unavailable ownership inspection was left untouched. Before/after library, worker, probe and input hashes match. All 480000 finite output samples are byte-identical to the direct speech48 reference-on baseline, SHA256 `64ff21c8053d444cd20f1f1a8d34ccd3ade696d1acefcbd46e46364196895f5f`. Independent review recomputed the file identity, sample equality and ten window RMS values.

Observed request round-trip latency was median 0.198666 ms, p95 0.284875 ms, p99 0.376208 ms and maximum 12.396417 ms. Processing 1000 requests took 206.559042 ms. This was unpaced synthetic CPU processing while native verification ran concurrently, not a controlled benchmark. The maximum exceeded one 10 ms audio block. Sustained deadlines, callback buffering, physical timing and live quality remain unverified. Startup time includes input admission and launch. No audio devices, administrator operations or cloud service ran.

The full native `./verify` passed, including new release/ASan/UBSan launcher and runtime tests, input mutation, foreign failure and failed close with no output publication. Source review resolved sequence advancement and staging ownership before capture. Verification log SHA256 `19b5fff010487b2d6177f3a0dea7ec8104aac57f69bcb6c37babcd589f3c3a6c`; capture result SHA256 `f8f08f7f4210d430074f1cb60675c521a04586d842948426b6bb99545623b8ce`; metrics SHA256 `5293e526e223f27fde388983020087ce9b490535769a4bc347012460d3c7b9d3`. Files are retained under `evidence/aec-worker-runtime-verify-20261023.log` and `evidence/model-probes/aec-worker-20261023-v1*`.

Frozen worker SHA256 `f546ee5f38cb3ecf186bc812e4f687f73bca346c1156c6c3c64670ffd78983cf`; runtime probe SHA256 `2476858d8672740b483d8da2a512932a10cde2d750552ef4cb3ab0998cb53308`. All 142 implementation fingerprints match. Original libraries/models and generated audio remain external or ignored, and no vendor assets are published.

Next implement separate bounded duplex callback transport with paired microphone/final-playback reference frames, preserved per-lane timing, deterministic startup delay and silence on failure. Test irregular callback partitions and late worker replies before touching live routing. Keep initial AEC with microphone NC disabled until the separate AEC-to-NC chain is implemented and verified. Full retained local feature parity remains incomplete.


### Duplex callback transport handoff

Use separate AECDuplexTransport/AECDuplexWorker types and leave NC transport unchanged. The callback supplies paired mono microphone/stereo final reference, count, fixed epoch and distinct per-lane input/output sample origins. A bounded request queue accumulates complete 480-frame pairs without padding; a result queue returns only microphone audio. Preserve origins as callback origin plus integer sample offset, including fractional unequal origins across partial-frame boundaries. Validate continuity before publishing. No callback allocation, IPC, waits or foreign calls.

A callback can yield several model frames but supplies only one host-time anchor. Do not repeat that anchor as distinct frame timestamps or invent host ticks. Initially clear wire host-time validity for the epoch and retain callback anchor plus sample offset in local provenance. Any future conversion to frame-origin host times needs an explicit validated clock mapping. Epoch or sample-continuity loss requires a fresh worker.

Keep deterministic initial silence and delayed output. Test scheduling budgets of two and four frames; do not choose a production delay solely from one unpaced timing observation. The conservative formula is `(ceil((maximumCallbackFrames + 479) / 480) + budgetFrames) * 480`. At maximum4096 and budget4 this is6720 samples/140ms, which is a test configuration rather than parity acceptance. A missing result at its scheduled sample faults and silences the whole microphone callback block, even if the IPC timeout has not expired. Never skip/repeat results or silently change latency.

Next tests cover sample-exact paired accumulation for1/479/480/481/512/4096 and mixed partitions, unequal fractional lane origins, host-anchor provenance, exact startup delay, stalls/bursts, out-of-order results, overflow/clock faults and callback allocation guards. Keep worker construction/service/close/destruction on one owner thread and retain ownership through failed callback removal. Later route tests must compare reference bytes to committed final playback after speaker DSP and gain/mute. Paced throughput and physical audio acceptance remain separate gates.


## Paired duplex callback transport checkpoint, 2026-10-23

`AECDuplexTransport` now assembles exact 480-sample microphone/960-value stereo reference pairs across callbacks using bounded request/result queues. It preserves distinct fractional lane sample origins and first-sample callback provenance. Output metadata maps delayed microphone spans to their source frames. Host-time validity stays false on the wire; sample offsets do not invent host ticks. Whole-callback preflight rejects nonfinite samples, epoch/clock discontinuity and double-precision loss before publication. Missing or invalid scheduled results silence the complete supported output block and latch a fault.

`AECDuplexWorker` constructs, starts, services, closes and destroys its broker on one background thread. Control-thread creation waits for readiness; callbacks only use preallocated transport storage and lock-free atomics. Stop signals failure and joins. The owner must still be retained until callback removal/drain succeeds; actual route binding remains pending. Deadline ranges are validated before duration arithmetic.

Release, ASan/UBSan and TSan focused tests and the complete native-model-probe `./verify` passed. Tests cover tiny callbacks past startup delay, uniform and mixed 1/479/480/481/512/4096 partitions, exact stereo/reference and delayed output, metadata, bounded worker bursts, missing replies, terminal faults, identity/provenance tampering, ordinary/aligned C++ allocation guards and 5000 concurrent queue wraps. Owner integration uses the actual own worker/own library at 480/512/4096 bounds with budgets 2/4 and explicit processed-frame handshakes. It includes readiness/processing/close failures and stop during blocked foreign processing. Those handshakes test ordering/lifetime, not real-time scheduling.

Independent review resolved deadline arithmetic overflow, lossy large-origin timestamp progression and a tiny-callback test that had ended before a full frame. Full log `evidence/aec-duplex-verify-20261023.log`, SHA256 `9a920be98f43af67b2ae1c221d0d8ebca7ec62a2a98bb31d78d8bb0c1e2ed4f9`. All 146 implementation fingerprints match. Existing NC behavior and live route code are unchanged. No original component, hardware audio or administrator operation ran for this checkpoint.

Default test buffering 4096/four yields 6720 samples/140ms, not validated product latency. Next validate paced callback-to-installed-worker behavior through REA, then bind the transport to final playback after speaker DSP and gain/mute. Reference publication and actual playback must share the same final commit decision, including silence on route shutdown/fault. Keep initial AEC microphone NC disabled; a later AEC-to-NC chain needs separate processing stages. Live acoustic timing, speech quality, route lifecycle and full local parity remain incomplete.


## Paced AEC and final-playback hook checkpoint, 2026-10-23

The new paced probe drives AECDuplexWorker from steady-clock sample deadlines without processed-frame handshakes. It adds zero input/reference for the fixed transport delay, retains the initial silence in output and checks clean shutdown before exclusive publication. REA ran two installed-library cases against the retained speech48 inputs:

| Callback bound / budget | Evidence | Initial delay | Callbacks | Aligned result |
| --- | --- | --- | --- | --- |
| 480 / 2 | ev_871829065ec9d3cd5469015953e05a28fcbba21f35b0dcb40131b84eac637695 | 1920 samples / 40 ms | 1004 | 480000 samples byte-identical |
| 4096 / 2 | ev_e297f06d5c4f0c9f54358a9c42c0f3427690562ddb4e9f698edafa7a8c95240e | 5760 samples / 120 ms | 119 | 480000 samples byte-identical |

Both captures exited zero, were untruncated, verified owned-process cleanup and removed temporary roots. All before/after library, executable and input hashes match. Both zero prefixes are exact; aligned output SHA256 is `64ff21c8053d444cd20f1f1a8d34ccd3ade696d1acefcbd46e46364196895f5f`. Processed-frame counts 1003/1006 include padding. Stop may discard remaining padding requests after all original 1000 results have been consumed. This is transport flushing, not acoustic tail recovery.

Maximum callback lateness was 2.506709 ms and 5.892667 ms respectively. Maximum exchange duration was 25.833 us and 52.875 us. Full component suites finished before these captures, but host scheduling and other workloads were uncontrolled. No CoreAudio callback, physical route, speech-quality parity or sustained production deadline is established. `totalPacedMs` ends after the final callback invocation, not physical playback completion. Frozen paced probe SHA256 `115c32c6a77cfc776a411198f7242238734b15f8819077ea37d23bcf4d11b025`.

The route now has an optional duplex hook behind ProcessorFactory. It requires explicit microphone-stage disablement and receives raw microphone plus final stereo playback after speaker DSP and gain/mute. One final enabled/changed check commits the callback before publishing its reference. A subsequent hook failure or shutdown cannot replace that playback with different samples; microphone output becomes silent on failure and the next callback stops. The owner remains with Context through failed HAL cleanup. This hook is not yet connected to AECDuplexWorker, CLI or desktop selection. Existing non-duplex behavior remains unchanged.

Synthetic route tests compare reference and actual output bytes at 1/479/480/481/512/4096 frames, with speaker delay, gain/mute, fractional sample origins, host validity, hook failures, shutdown races and retained ownership. Full audio-host and native-model-probe verification passed. Native log `evidence/aec-paced-native-verify-20261023.log` SHA256 `27fa4898b40c0dadccfd52bc7d07fb8f6c0374d9882ccb9c1d4e39913d019a6a`; host log `evidence/aec-route-hook-verify-20261023.log` SHA256 `da59975897d23c92cd5846ece926bb1dba9749ee2d1ad5b0b806dc8149e87066`. Independent source and evidence review passed. All 150 source fingerprints match.

Raw evidence/metrics remain under `evidence/model-probes/aec-paced480-b2-20261023-v1*` and `aec-paced4096-b2-20261023-v1*`. Result hashes are `2471cf014e17c7a67026768657c4543d32838798c12ab386ff9fe153f59e777f` and `33401a8d42299ab82904af5bf7f24f79a7877621cc09359a72e9e6a85a5e89bb`; metrics hashes are `89c3fd7f50c31c9a05d32b4168cb5603b46482a09505cecdb48c9e55522a0a14` and `a6facf1e63082c0c24cda5f5c9103e7be8ed5e09f501a427f75802007067015b`.

Next add the admitted AEC route adapter/factory and explicit configuration, with microphone NC disabled initially and speaker processing retained. Map callback origins and host anchors into the duplex transport without treating aggregate input origins as historical capture time before speaker delay. Verify through the synthetic route before any hardware run. Add UI/CLI behavior and restore/error paths without enabling AEC by default. Physical acceptance, the AEC-to-NC chain and full retained local parity remain incomplete. No administrator action or physical audio run occurred; proprietary assets remain external and excluded from Git.


## Explicit AEC route checkpoint, 2026-10-23

The explicit installed AEC adapter now connects the validated route layout to AECDuplexWorker. It passes raw microphone and final stereo playback after speaker processing, gain and mute, while preserving separate lane sample origins and host-anchor validity. The callback performs no worker launch, IPC or join. A separate control owner stops the worker through startup failure and failed HAL cleanup; queued callbacks retain stopped storage. Expected callbacks after clean stop produce silence without a false diagnostic.

The helper accepts exactly four AEC runtime options and checks the own worker hash before route creation and again before launch. The installed library hash stays fixed. AEC defaults off, rejects microphone NC/provider combinations, and supports existing speaker processing once. Startup JSON reports AEC identity, format, callback bound and delay. The distinct microphone provider causes older desktop clients to reject unexpected AEC rather than silently ignore it. Existing AEC-off fields stay unchanged.

Full audio-host verification passed, including release, ASan/UBSan and TSan adapter tests. Own-worker/own-library route tests cover maximum callback bounds of 480/512/4096, budgets2/4, irregular partitions, exact final reference and delayed microphone output, timing provenance, fixed admission, foreign failure and retained ownership. Explicit processed-frame handshakes occur outside callbacks; these tests do not prove real-time scheduling. CLI parser/ACK tests use a sink that cannot create routes. Desktop verification passed117tests plus signed ARM64/macOS12 packaging and relocation checks. Independent review found no remaining issues.

Verification logs: `evidence/aec-route-adapter-verify-20261023.log` SHA256 `53da3c19ee6933ac493fdff9c0c0d813f26fdf5c114d81034bcbe0e0f9accab3`; `evidence/aec-route-desktop-verify-20261023.log` SHA256 `4335c4afed34835dd4b7ce5c885a435163bbc9d9ebf9cf0ec34f70fbab70cb78`.

Next package the own AEC worker and add explicit desktop selection with matching startup acknowledgement and restore/error tests. Keep microphone NC disabled until a separate AEC-to-NC chain is validated. Physical audio, acoustic alignment, speech quality, desktop visual acceptance and full retained local parity remain incomplete. No original code, physical audio or administrator action ran in this checkpoint. Vendor assets remain external and excluded from Git.


## Desktop AEC checkpoint, 2026-10-23

The desktop app now bundles its own signed ARM64/macOS12 AEC worker and offers explicit echo-cancellation selection, initially off. The installed app supplies the fixed reviewed external library. AEC-only validation does not require Node. It checks bounded ordinary files, executable mode, the exact manifest and hashes, and observed identity changes without loading vendor code or starting audio. The packaged worker build preserves the frozen runtime-probe executable.

Changing the selected app, AEC toggle or microphone-noise option invalidates admission. Validation IDs reject stale completions. The UI and controller reject simultaneous microphone NC and AEC; speaker processing remains available. Start still requires microphone authorization and exact helper acknowledgement. AEC acknowledgement checks reject missing, incorrect, null or unknown AEC fields, microphone NC metadata, and inconsistent callback bounds between AEC and installed speaker processing. Disabled AEC rejects all AEC fields. Startup budgets count both workers when selected.

Full desktop verification passed128tests, release build, signed package and relocated-resource checks. New controller tests cover default-off/noNode validation, configuration invalidation, failed and stale validation, mismatched acknowledgement, late readiness, permission cancellation, and AEC plus installed speaker processing. Resolver tests use own files with injected vendor hashes; actual hashing, symlink/mode/bounds and observed mutation rejection are tested independently. The packaged executable also passed the existing release adapter integration against a freshly compiled own synthetic library. Independent GPT6.1sol review found no remaining issues.

Verification logs: `evidence/aec-desktop-verify-20261023.log` SHA256 `80afb14134221ce5af362018982a4298093c0ba6867003f922d1816034b78108`; `evidence/aec-packaged-worker-verify-20261023.log` SHA256 `1d83287bbbec6e07aec962a005e86f716023f25792e7656148edb5dee373a034`.

No physical route, microphone, OS prompt, original artifact execution or administrator operation ran. Original libraries/models remain external and excluded from Git. UI rendering, acoustic alignment, speech quality, device lifecycle and full retained local parity are still unverified or incomplete. Next implement and verify the separate AEC-to-microphone-NC chain, including combined startup delay and failure propagation, before allowing both toggles. Physical acceptance remains a separate gate.


## Combined AEC and microphone NC checkpoint, 2026-10-23

The independent microphone pipeline now supports AEC followed by RNNoise or the reviewed installed outbound NC provider. `AECMicrophoneChain` feeds the entire AEC output stream, including startup silence, into a microphone-only NC adapter. Speaker processing runs once before the final playback reference. Both stage contracts validate before either chain worker starts. Control ownership stops both workers even if one fails and retains stopped storage through failed HAL cleanup. The existing NC adapter no longer reports an intentional concurrent stop as a new callback failure; prior failures remain recorded.

CLI and desktop now allow AEC with microphone NC. Combined startup adds explicit `aec-then-nc` order, NC delay and summed buffering delay, while preserving AEC-only and non-AEC fields. Installed microphone and speaker identities retain their existing fields. Swift checks exact chain-field presence, order, stage delays and matching callback bounds. Up to three worker launches receive a 100-second startup budget. AEC remains off by default and file/processing changes invalidate admission.

Full audio-host verification passed, including release, ASan/UBSan and TSan chain tests with own AEC library/worker and own Node NC fixture. Tests cover bounds of 480/512/4096, irregular partitions, exact sequential output, speaker gain/mute/reference, microphone gain/mute, callback C++ allocation guards, startup/processing/close failures, stop concurrency and retained ownership. The RNNoise baseline receives identical AEC startup zeros and callback partitions, preserving its warmup state. Full desktop verification passed 131 tests and signed packaging/relocation checks, including four microphone/speaker profiles, three-worker startup, wrong-order stop and production C++ formatter-to-Swift acknowledgement parsing. Independent GPT6.1sol review found no remaining issues.

Verification logs: `evidence/aec-chain-host-verify-20261023.log` SHA256 `920f1ab8c8a9eea03ed1cc88fe04bff23cc72cda372ad776a38141154482e1f9`; `evidence/aec-chain-desktop-verify-20261023.log` SHA256 `f6b493968fef20d9001bb00eb4cedfd35996fef9a7f37b952a7cef29761549de`.

This order is an independent implementation policy, not a demonstrated original Krisp microphone order. Summed delay describes buffering only; it excludes model algorithm latency, speaker processing and acoustic delay, and does not promise exact startup silence for arbitrary model outputs. Synthetic worker handshakes establish sequence/lifetime, not real-time deadlines. No original component execution, physical audio or administrator operation ran. Vendor assets remain external. Next validate the combined installed AEC/NC CPU path through REA against an explicit sequential baseline before physical routing and quality acceptance. Visual UI, acoustic timing, device lifecycle and full retained local parity remain incomplete.


## Combined installed AEC and microphone NC CPU checkpoint, 2026-10-23

REA `ev_4b31d8782b9662f39bab53554496e488b242331921089bb9cca38a83d749a607` at maximum 480/budget 2 and `ev_024ec6221e035ed54330c43b666c686ceb9570618624d883c6cff1ffe3d45812` at maximum 4096/budget 2 completed with zero mismatches against separate warmup-matched outbound NC baselines. Each output contains 480000 finite samples. Chain AEC/NC and baseline frame counts were 1008/1008/1004 and 1024/1024/1012. Per-stage buffering was 1920/5760 samples respectively, with total 3840/11520. Both captures exited zero without truncation; owned cleanup was verified and temporary roots removed. Unrelated PIDs 48698/49255 were left untouched with `platform_binary_environment_withheld` because ownership could not be verified.

Output pairs have SHA256 `4201d16161d76d5b442be7cabd7b779046fc5d8adc119de6a79a5d3faf478866` and `7dd7f250a2cc55665f5c5e936944a496c95ead89967d11596c2ab3a6ea8a1361`. Equality holds within each bound only. Across bounds, 478780 numeric samples differ with RMS difference 0.0016221878284013397; AEC startup-zero prefixes differ, and no unique cause or callback-bound invariance is established.

Full own-fixture host verification exited zero: `evidence/aec-chain-probe-host-verify-20261023.log`, SHA256 `1f1470954ca3ceb799a407987bbb8b448a42fa98af23a3430f4f7cd8d48a0eb0`. All before/after pins match. See `aec-nc-chain-runtime-findings.md` for exact artifacts, result/metrics hashes and capture limits. The new four-file probe and 164 source fingerprints are recorded in the parity ledger. Desktop fingerprints use committed `fada15b` sources so subsequent offline-transcription work is excluded.

This unpaced functional handshake test does not establish real-time behavior, original processing order, acoustic quality, full model tails, physical routing or full parity. These remain acceptance gates; AEC remains off by default. No hardware audio or administrator action ran.


## Offline transcript timing checkpoint, 2026-10-23

Desktop import now preserves recognized segment text, order and timing through storage and timed export. Exact unchanged drafts retain timing; edits irreversibly invalidate it, selected-file changes clear it, and failed or cancelled replacements preserve the prior candidate. Manual text and missing segments keep the recording-wide fallback. Desktop phrase search spans stored word boundaries; `LocalStore.search` remains per-segment. Full desktop verification passed 138 tests, with 22 focused tests including seven new timing tests; unchanged transcription/store suites passed 14/12. Tests use own fixtures and injected recognition. Export uses segment text and millisecond start markers, not a separately stored formatted paragraph. Original timestamp parity, live ASR, diarization and real recognition accuracy remain unverified. See `offline-transcript-timing-findings.md`.

- `evidence/transcript-timing-local-transcription-verify-20261023.log` SHA256 `57eacd32abab9ca067872fe5948531c4d5f33a5f233d23f249d703baa9af1ff8`.
- `evidence/transcript-timing-local-store-verify-20261023.log` SHA256 `7a31ad53ae070d24ec5825955416931dee73c48c26d7e617819f9f3a19a52d61`.
- `evidence/transcript-timing-desktop-verify-20261023.log` SHA256 `3dae16820385bfedd235c3746941dd01eec430e44639d2c9609ca41ed395d580`.


## Background voice evidence checkpoint, 2026-10-23

Static controls/native recovery and bounded HVC candidate processing are documented in `background-voice-controls-findings.md`, `background-voice-native-findings.md` and `background-voice-candidate-findings.md`. REA `ev_56b1a5141f8d1e8f0eee9728b1d110f18bb2d9e628735ed0e21cca79d2bbb9fe` retains two successful 100-frame/48000-finite-sample children, but outer exit 1 remains recorded because raw-input bypass equality was an invalid oracle. Candidate bypass matches retained ordinary bypass. Same-adapter ordinary active control `ev_2f7141d178b135212d4f829f61124b34f138dcc284d300ba85dc65837dd2e446` exited 0; 47500 samples differ from HVC, establishing model-dependent output only. Production BVC remains unavailable and metadata-only in the ledger. Next recover shared NC descriptor dispatch and effective BVC settings before admitting a distinct persistent HVC role; quality and hardware remain separate gates. Fresh driver checks confirm the trace tree and current own services predating its installation, so the deferred restart remains diagnostic, not a proven fix. See `driver-current-discovery-findings.md`. All 165 source fingerprints match; source is unchanged and the latest 138-test desktop pass remains applicable. No tests or vendor runtime were rerun for this documentation update.


## Persistent HVC worker checkpoint, 2026-10-25

The private worker/probe now admits a separate fixed `outbound-hvc-lfb` role. The ordinary outbound/inbound identities and defaults are unchanged. REA `ev_f0e42f64a009b52eb8aed7c7e30177101eb560c64ade103e2096a899bb788753` passed: fresh active and bypass workers each produced 100 frames and 48000 finite samples, matching retained direct-HVC outputs byte for byte, with unchanged pins and verified owned cleanup. The historical failed raw-input bypass assertion remains separate. See `background-voice-persistent-findings.md`.

The native findings close the static NC descriptor construction join and identify packaged RD defaults and the alternate energy/statistics path. Product BVC remains unavailable. Next add explicit microphone selection with exact startup role checks and preserve speaker-only inbound admission. Reject HVC with AEC until a separate composition gate passes. Headset policy, target-speaker preservation, nearby-voice rejection, real-time deadlines and physical audio remain open. No vendor assets are included. The JSON ledger records all 165 current source hashes.


## Experimental background-voice microphone selection, 2026-10-25

Desktop and audio host now expose an explicit installed HVC-lfb microphone mode with exact role/hash admission. Ordinary NC remains the default; speakers stay inbound-only. Mode changes invalidate validation, and startup must confirm the selected model. HVC with AEC is rejected before route launch. Own-fixture tests cover CLI admission, injected controller state, stale results, production C++ formatter-to-Swift acknowledgement and invalid role/hash combinations. See the latest CHECKPOINT section for full verification results.

This supersedes the earlier product-unavailable status. The mode is experimental. Actual installed-HVC product routing, voice isolation, target-speaker preservation, real-time deadlines and visual acceptance are unverified. Per-device headset confirmation, automatic compatibility, remove/reset policy, HVC-sfb and original energy/bypass statistics remain incomplete. Vendor assets stay external.


## Manual headset confirmation and compatibility evidence, 2026-10-25

The independent desktop now persists explicit headset confirmations by exact device UID with names for display. Experimental HVC validation and Start require confirmation of the selected input. Remove and reset invalidate admission; reset restores ordinary microphone mode and clears only confirmations. Policy controls cannot mutate during capture, recording, loading or quit. Confirmation does not request permission or start audio. A reproduced permission-wait race is fixed by requiring unchanged provider/AEC admission revisions, including when a device or mode changes away and back. Full desktop verification passes 148 tests, signing and relocated-resource checks. Native UI observation failed because stable process launch identity was unavailable; visual acceptance remains unverified.

New static REA captures recover original matching fields, case handling and precedence, plus an observed cached list with 152 allowed and 701 blocked entries. See `background-voice-controls-findings.md` for exact IDs, cache schema and limitations. Original manual matching uses lowercased name substrings and exact-name removal; this checkpoint's exact-UID policy differs and does not establish original compatibility parity. No vendor list is included.

Next recover the original CoreAudio-to-interfaceName/manufacturer/modelId mapping, then implement and compare the original local compatibility precedence with own fixtures and the observed offline list schema. Preserve account/cloud exclusion, report unknown or stale list state, and keep runtime device-policy and acoustic acceptance separate. Physical driver discovery and routing remain deferred administrator-dependent work.


## Native device metadata and local matcher, 2026-10-25

The own helper now reports interface_name, manufacturer and model_id using the recovered global CoreAudio name/manufacturer/model UID selectors. Optional reads preserve the device with empty strings and per-device metadata_read_errors. Swift preserves missing versus empty fields and does not substitute display names. The standalone local engine implements mode/rate gates, local blocked-before-allowed-before-manual precedence, branch-sensitive malformed values, literal UTF-16 matching and exact manual-name removal. Failed bounded cache loads preserve previous lists.

Six accepted static REA captures bind the native field chain. Later device grouping remains unresolved. A separate string-conversion capture retains complete disassembly but failed cleanup acceptance. The attempted extracted-method replay returned no dynamic outcomes: its first wrapper had a syntax error, and the corrected call failed REA lifecycle cleanup. The 35 local cases in the own 43-case fixture are statically expected results, not observed JavaScript executions; eight account/team cases are excluded. See `background-voice-controls-findings.md` and the latest CHECKPOINT section for exact paths and verification.

Next connect offline compatibility-list selection and the recovered local policy to automatic NC/HVC model choice. Carry original manual interface-name matching and blocked-list precedence through the actual controller flow; do not confuse the existing interim UID confirmation list with exact original manual behavior. Invalidate admission on device, mode, list and manual-policy changes, including in-flight validation and permission waits. Keep ordinary noise cancellation available when automatic compatibility is unknown or unavailable, with a clear status. Account/team restrictions, telemetry and network list refresh remain excluded. Original runtime policy comparison, visual controls, physical audio and acoustic quality remain open.


## Automatic local headset policy, 2026-10-28

The desktop now connects the recovered local policy to installed microphone model selection. Automatic mode selects HVC only for an allowed or manually allowed device; blocked, low-rate, unmatched and unknown results use ordinary NC. Explicit off remains the independent initial default because the original effective first-run default is unresolved. Reset clears manual names and returns to automatic mode, preserving imported allow/block lists. HVC with AEC remains rejected.

Manual choices now store interface names and match case-insensitive UTF-16 substrings. Removal and identity preserve exact UTF-16 spelling, including canonically equivalent names. The old UID-only preference is ignored rather than converted into broader name matches. Successful cache imports copy validated JSON atomically into this app's local cache. Failed imports preserve prior lists. The 1 MiB bounded reader rejects links and special files. No original list is bundled or automatically read, and no network refresh runs.

Inventory replacement invalidates provider/AEC admission even when the selected UID stays the same. Successful cache changes, manual changes and mode changes also revoke admission. Pending validation and permission roundtrips cannot restore superseded model selection. Existing exact role/hash startup checks remain in force. Policy changes and import are locked while capture or other engaged operations run.

Full desktop verification passed 171 tests, ARM64/macOS12 packaging, signing and relocated-resource checks. Tests cover imported allow-only HVC resolution, blocked precedence, ordinary fallback, reset retaining lists, persistence and malformed imports, exact Unicode identity, same-UID metadata changes and delayed validation/permission results. Three GPT 6.1 sol workers implemented and reviewed the changes; no review findings remain. The root AGENTS.md now documents repository-specific execution and evidence rules.

Log: `evidence/headset-auto-desktop-verify-20261028.log`, SHA256 `69b5d2db93b49ae76fd7c1b37e5c30a739e981f674a120e561624b0ab1ef84cc`. Only desktop source changed, so the unchanged host remains covered by the previous host verification. No original execution, physical audio, administrator action or native UI interaction ran.

Original runtime-policy comparison, first-run/mode persistence, later device grouping, cache provenance, JSON/Unicode edge cases, native picker/control acceptance, driver discovery, physical routing and acoustic quality remain open. Full retained-feature parity is incomplete. Next verify the actual automatic-policy workflow through REA when its native process identity/lifecycle path is usable, and continue the remaining feature ledger. The administrator-dependent driver step stays deferred while Hari is away.


## Native UI and power lifecycle evidence, 2026-10-28

REA now observed the own home window and opened Audio after LaunchServices launch. Accepted captures confirm stopped state, RNNoise defaults, disabled Start and unavailable driver. The provider popup failed exact-window binding; automatic-policy interaction remains unverified. Both bounded launch attempts have incomplete lifecycle evidence. Known app PIDs were absent afterward, but no clean launcher teardown is claimed. See `native-ui-headset-findings.md` for exact accepted IDs, screenshots and preserved failures.

Four accepted static REA captures recover original Sleep/Wake test commands, packaged default false, shared application power callback, newest-event AppState coalescing and Main service dispatch. Suspend tears down audio graphs/streams/device management; resume reinitializes devices without directly restarting graphs in the inspected method. Hidden commands remain retained as power-event simulation, separate from production notifications. See `sleep-wake-findings.md`.

The production native notification mapping and recording reset-to-finalization path remain unresolved. Follow-up captures hit REA lifecycle cleanup failures and are not accepted evidence. Next recover these joins before implementing shared local suspend/resume with recording preservation and stale-admission invalidation. Local notifications and other retained services remain in scope; account/cloud/analytics dependencies stay excluded. Do not infer recording publication from graph removal or AppState completion.

No source changed after `bd4d4d7`. Its 171-test desktop/signing/relocation result remains applicable; tests were not rerun for these reports. All 177 source fingerprints still match. No original application code, physical audio or administrator action ran. Full parity remains incomplete.


## Device inventory cancellation, 2026-10-28

A production-controller reproduction showed that a canceled device query could later replace inventory or publish an error. The query now carries its own identity, cancellation state, completion state and shared stop task. Cancellation revokes publication immediately. Loading remains engaged until the read continuation and stop flight both finish, protecting the helper service slot. Duplicate Stop calls share a flight; old completions cannot clear a replacement query or stop a new route. Failed stop remains retryable, and Quit refuses until the query drains. This prepares one required lifecycle invariant; it does not implement OS suspend/resume.

The pre-fix test failed two assertions. Six new regression tests cover stale success/error, read and stop completion in both orders, replacement queries, failed stop/retry, duplicate Stop and the real QuitCoordinator path. Thirty focused tests and full desktop verification passed. Full verification ran 177 tests plus ARM64/macOS12 packaging, signing and relocated-resource checks. Independent GPT 6.1 sol review found no remaining issue.

- Reproduction `evidence/inventory-cancel-repro-20261028.log`: SHA256 `db0038f6e08af60113e1d24eac9bb35b7ea05f6ef7b53dcbd7ed4e655a9b8c22`.
- Focused `evidence/inventory-cancel-focused-20261028.log`: SHA256 `e20e95b7dfe34120f12cb475b29b9f0de6bc28d701025c3437db2f2ffa31e7bd`.
- Full desktop `evidence/inventory-cancel-desktop-verify-20261028.log`: SHA256 `f280dba788e84f5841e6121f15fdfe70ed27fd06bba22383193af4b2a44632f2`.

Retained original output adds a separate recording-stop event join: foreground/background stop calls run through an unawaited Promise.all. The suspend-reset handler and durable publication join remain unknown. REA advertises capture capability but still rejects execution because of unresolved process cleanup; no further original reads were attempted after one narrowed revalidation failed. See the latest section of `sleep-wake-findings.md`. No original application code, hardware capture or administrator action ran. Full retained-feature parity remains incomplete.


## Saved recording transcription, 2026-10-28

History now offers explicit on-device transcription for an existing saved recording. The user chooses a language, starts recognition, reviews or edits the draft and chooses Save transcript. Recognition changes only the draft. Cancellation and failure preserve the saved transcript; replacing nonempty review text needs confirmation. Empty text is not accepted by this UI. Unedited recognition retains word timing; any text edit invalidates timing even if later reverted.

LocalStore captures the expected session and root/session-directory/manifest/recording identities. Save validates that snapshot and segment bounds, synchronizes a private temporary manifest, rechecks the snapshot and atomically replaces only session.json. Session ID/title/date/duration and audio stay unchanged. Shared process locking serializes commits and deletion across store instances. File metadata detects ordinary mutation/replacement; it is not a cryptographic recording snapshot or compare-and-swap against arbitrary external writers. Power-loss directory durability is not claimed.

Desktop review holds a library activity lease, fences selection roundtrips and late recognition/preparation results, and locks selection/dismissal during save. Failed saves preserve the review and show an error. A real own finalized WAV fixture runs through saved history, injected recognition, reviewed same-session replacement, phrase search and timed export; tests verify unchanged audio bytes/inode/mtime and one session. This is an independent local workflow, not recovered original post-save UI semantics. Live ASR, diarization, automatic recording transcription and accuracy remain open.

Verification passed 18 local-store tests, 29 focused desktop tests and the full 184-test desktop suite, including ARM64/macOS12 packaging, signing and relocated-resource checks. GPT 6.1 sol implementation and independent review found no remaining blocking issue. A development selection didSet recursion failure was corrected with a guarded selection setter; its full raw crash log was not retained, so only the final passing test evidence is claimed.

- Store log `evidence/history-transcript-store-20261028.log`, SHA256 `1952db980442e33dc063c9b364026a149501dda151b776a2c9a5f0c1cc45effe`.
- Focused log `evidence/saved-transcript-focused-20261028.log`, SHA256 `a73aee95ab1ee35aa3d557144c8284d09d88cda5c9cea84d47a8d5c7003122f6`.
- Desktop log `evidence/history-transcript-desktop-20261028.log`, SHA256 `3199445feea6ac2ea349f60ec15d8fc5949bb39e550586e00fdcbad61f0a5cb9`.

REA's purpose-built inert application analysis worked independently of process capture but produced a partial graph after semantic workers exhausted their budgets. The exact BootstrapApp identity matches prior evidence; unpacked native integrity contradictions are explicitly retained. An empty reset-handler trace in that partial graph is not an absence proof. The original recording-reset handler remains unresolved. See `sleep-wake-findings.md` for IDs, pins and limits. No original code, OS recognition, physical audio or administrator action ran. Next complete native/real offline recognition acceptance when available and continue lifecycle/feature gaps; full parity remains incomplete.


## Local power lifecycle, 2026-10-28

The app now listens for IOKit system-power events on the main common run loop. Can-sleep is acknowledged without suspension; will-sleep is acknowledged before dispatching Suspend; has-powered-on dispatches Resume. Will-power-on does not resume services. NSWorkspace power-off enters the existing normal termination pipeline. Registration errors remain visible, and termination removes listeners. Native source/mapping is recovered statically in `sleep-wake-findings.md`, including observed-versus-declared addon identities and retained evidence. No original code ran.

The shared lifecycle closes admission synchronously on Suspend, cancels pending recognition without discarding review text, invalidates device/model/permission results and stops registered history/comparison playback. It serializes cleanup and the newest requested event, including Suspend arriving during Resume. Route shutdown uses existing recording finalization. Unconfirmed live cleanup keeps admission closed and exposes retry. A terminal recording publication failure with no live writer retains files and a warning; Resume may proceed without claiming that recording was saved. This is an explicit independent preservation policy because the original reset-to-publication join remains unresolved.

Resume refreshes device metadata and revokes model admission. It never restarts capture, recording, recognition or playback. File-only writes/reviews retain their existing leases and preservation rules. Quit stays separate from the power gate. Settings can reveal labeled simulated Sleep/Wake controls, default hidden; they call the same lifecycle without requesting OS sleep or wake. Their Settings placement is not original tray-menu parity.

Full desktop verification passed 195 tests, ARM64/macOS12 packaging, signing and relocated-resource checks. The 53-test focused run includes nine lifecycle tests and two native mapping tests. Fixtures cover newest-event ordering, interrupted Resume, cleanup failure/retry, stale inventory/provider/permission results, two history players, comparison playback epochs, recognition cancellation preserving a timed draft, recording publication and retained failure across Wake, and no automatic helper restart. Independent GPT 6.1 sol review found no blocking issue.

- Focused log `evidence/power-lifecycle-focused-20261028.log`: SHA256 `41da04041f030e06a6db66f6e3e10d72f5b2305b0069550c9389ae3149006e7c`.
- Desktop log `evidence/power-lifecycle-desktop-20261028.log`: SHA256 `32c0b3096cb065bc9ee02114b9cbdd98a6ef15f95208cd47419a2503a225ab40`.

The original native callback acknowledges OS sleep before async application cleanup. Neither the evidence nor this implementation promises recording publication before the machine sleeps. Actual listener delivery, system sleep/wake/shutdown, native simulation controls, physical routing and recording survival across sleep remain unverified. The original recording-reset handler, default-device restoration and later graph restart remain separate gaps. Native analysis close failed due unrelated process-capture resource ownership checks; the exported static evidence is preserved and provider shutdown is not claimed. No physical audio, forced OS power event or administrator action ran. Full retained-feature parity remains incomplete.


## Native listener acceptance and activation evidence, 2026-10-28

An opt-in integration test attached the own NativePowerNotifications class to real IOKit notifications in the test process, without posting or forcing any event. It observed nonzero connection/notifier handles, a notification port, main common-mode run-loop membership and the power-off observer. Repeated Start retained the same registration. Stop confirmed source removal, IODeregisterForSystemPower status 0 and IOServiceClose status 0; port destruction and observer removal were requested and all owned resource fields cleared. No callbacks occurred. This proves bounded listener attach/detach, not delivery during real sleep/wake, packaged app startup or shutdown behavior.

The adapter now reports teardown outcomes instead of discarding statuses. Failed native cleanup retains handles and the callback owner, prevents registration over leftovers and allows explicit retry. Successful cleanup clears stale cleanup error. The native APIs for port destruction and observer removal have no return status, so those are reported as requested operations. Failure branches received source review, not forced kernel failures.

Full desktop verification enumerated 196 tests: 195 passed and the opt-in listener test was skipped. That listener test passed separately once under a bounded run. ARM64/macOS12 packaging, signing and relocated-resource checks passed. The later successful-cleanup error-label correction did not change registration or native teardown calls and did not justify another live attach.

- Live listener log `evidence/native-power-registration-runtime-20261028.log`, SHA256 `aa2bf67d7f54be7d8773b828878d9f00f5e5c083cb4c70ce68d98bfa9be5bc19`.
- Full desktop log `evidence/native-power-registration-desktop-20261028.log`, SHA256 `a85ad110eaa941cdd936dfaf870ac325900dd2db85879b99651477c8e1f8b134`.

A fresh own device inventory still reports feed/monitor endpoints absent with no inventory errors. CoreAudio and the own remote driver retain their October 13 start times, before the installed diagnostic build. No restart or installer ran. See `driver-current-discovery-findings.md`; the deferred administrator step remains pending.

REA native analysis and qualified retained JavaScript excerpts recover local CoreAudio audio-use detection, responsible-process identity, client payload, stabilization, lowercased app-name blocking and competing-call selection. See `activation-findings.md`. Running/frontmost applications alone are not calls. Concrete delay defaults, stream grouping, older-OS fallback, auto-activation preferences and the call-to-note-taking path remain unresolved. No activation implementation or original runtime behavior is claimed. Full retained-feature parity remains incomplete.


## Audio-use snapshot, 2026-10-28

Activation now has a partial prerequisite implementation: explicit read-only process usage in the helper and Audio view. It preserves unknown/error states, actual/responsible identity and device UIDs, with bounded output, cancellation protection and a checked timestamp. It does not qualify calls or activate recording. Full desktop verification passed 198 tests with one opt-in skip and signed/relocated packaging. One runtime snapshot observed 39 idle processes; active-device mapping and native UI remain unverified. See CHECKPOINT.md for exact logs and the error-path corrections made after that runtime read.

REA evidence recovers storage grouping, source selection and packaged timing defaults. Continuous observation, Call leg semantics, effective preferences and recording/transcription activation remain incomplete. No physical audio or original code ran. The ledger contains 193 source and verification fingerprints.

Full audio-host verification also passed release and sanitizer suites. Its exact log hash is recorded in CHECKPOINT.md.


## Grouped audio use, 2026-10-28

The visible snapshot now uses recovered two-pass input normalization and responsible-app grouping. It includes idle helper PIDs and preserves exact byte keys, ascending candidate order and first-candidate deduplication. Unknown state stays incomplete; internal driver endpoints gain no call eligibility. Six grouping tests and the production C++-to-Swift path cover these rules. Native callback output ordering and app version remain unverified or unavailable.

The call-to-ASR-to-recorder event join is now statically mapped. One changed-resource 2 GiB analysis still exhausted semantic extraction, leaving Call leg definitions and effective delay clamps unresolved. Continuous activation and physical audio remain incomplete. The ledger records 195 source and verification fingerprints; exact component results are in CHECKPOINT.md.
