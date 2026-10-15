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
| Local history/storage | Staged sessions, history/import/playback/export/delete and validated existing-folder chooser with path persistence, revision/admission guards and recording destination pinning | Desktop54tests/packaging reported pass; native chooser, actual unavailable-volume/disk-full behavior and comprehensive staging recovery UI remain unverified. Independent schema is not original-file compatibility. |
| File transcription | Explicit selected-WAV Apple on-device request and language selection | Real OS recognition, assets and accuracy. Live ASR, diarization, transcript-only capture and live pause/resume are absent. |
| Model selection | Explicit metadata discovery/hash/manifest UI | Integrated installed or arbitrary independent inference. Isolated installed NC load succeeded; synthetic generator graph failed before processing. |
| Appearance | Persisted System/Light/Dark | Current interactive/visual parity. Original default remains unknown. |
| Floating widget | Stable shared NSPanel, persisted explicit show/hide, actual route/recording state, mute status and Stop | Desktop verify passed 36 tests per root/worker checkpoint. Native panel/visual runtime untested. Call-auto-show, hide-for-now restoration, meeting title/time, talk time, captions and speaking assistance are missing. |
| Microphone NC test | Selected first-channel temporary capture, same-input original/RNNoise pair, five-second minimum, cancel/Done and A/B playback | Backend synthetic release/sanitizer/pipe tests and desktop46tests reported passing. Actual capture/playback, native UI, OS attribution and original test DSP contract remain unverified. |
| Lifecycle | Helper handshake, bounded shutdown, parent-loss handling | Startup login item, sleep/wake, save-before-relaunch and installed failure behavior. |

Existing builds and injected tests verify their stated contracts. They do not establish runtime feature parity. This audit did not launch an app, run real audio, install a driver, change original settings or publish anything.

## Paid, hidden and unresolved candidates

- **Live captions:** paid-plan text is evidence of a gate, not a reason to exclude captions. Mac reachability is uncertain because Windows runtime text also appears.
- **Local recording and storage:** “Audio Record” upgrade text and “Business plan” local-storage text do not carry into OpenKrisp. Folder selection and independent busy-operation locking are now implemented and fixture-tested. Native picker, original call-detection parity and comprehensive retained-file recovery remain unverified.
- **Screen recording:** paid text alone does not exclude a local capability. The original on-device-storage restriction leaves the local/cloud boundary unresolved. A new local replacement is optional, not a confirmed requirement.
- **Accent conversion:** microphone and others' accents, visibility preference, variant preparation, headset constraints and original/converted tests. Coming-soon language/variant labels are not proven capabilities. No model conversion inference is implemented.
- **Background voice cancellation:** headset detection, manual activation for unrecognized devices and nearby-speaker isolation. Administrator headset policy is removed; local compatibility and quality are not assumed.
- **Voice Translation:** a diagnostic label and current native translation/playback handlers support an unresolved candidate. Language directions, ASR/TTS contract, service dependence and Mac UI remain unknown. No implementation exists.
- **AI notes, summaries, recap and insights:** audio privacy text does not prove local summary generation. Investigate and retain proven local behavior; remote generation is excluded. A new independent local summary engine is a recommended option, not a confirmed requirement.
- **Live meeting ASR and speaker identification:** selected-file transcription does not provide live capture, diarization, transcript-only mode or automatic meeting save.
- **Performance and audio policy:** Auto/CPU Optimized/Best NC, default restore, AEC, Noise Shield intensity feedback, optimal mic locking and synchronization remain absent.
- **Meeting automation:** call detection, blocked-app list, competing-call switch, agenda/filter/join reminder boundary investigation, in-person notes and call-time preference locking.
- **Participant reminders and announcements:** templates, countdown, skip/cancel and microphone/setup failures, implemented locally without automatic external messages.
- **Widget insights and lifecycle:** measured talk time, speaking assistance, next-call visibility, meeting title/time, startup login item and sleep/wake.
- **Tests and diagnostics:** the temporary five-second original/RNNoise comparison is now implemented and synthetic-tested; live and visual acceptance remain pending. Local logs and troubleshooting/repair remain absent. The original user-selected file upload, developer/reload menus and service-specific network diagnostics need explicit contract decisions.

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
