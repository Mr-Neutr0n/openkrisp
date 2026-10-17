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
