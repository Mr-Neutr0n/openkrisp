# Checkpoint: resumed 2026-10-15

Hari resumed work on 2026-10-15 and requested autonomous progress with GPT 6.1 sol workers. Implementation has resumed from the private checkpoint tag `checkpoint-2026-10-13`. Password-dependent system changes remain deferred while Hari is away. The implementation and verification below include library-location selection, local diagnostics and launch-at-login controls. The original pause tag remains available.

## Completed implementation

- Native macOS desktop library: persisted folder selection, finalized WAV import, playback, search, transcript export/delete, appearance and model-file validation.
- Local diagnostic report export with bounded current-run event codes, optional issue date/system metadata and an explicitly selected PCM16 WAV sample.
- Explicit selected-WAV on-device Apple Speech adapter, with no cloud fallback.
- Independent RNNoise microphone/speaker processing and private audio routing helper.
- Independent virtual audio driver, timestamped transport and synthetic HAL test tools.
- App-route mute/gain controls, recording with pause/resume, finalized WAV history save and retained failure files.
- Floating control widget with shared route/recording state.
- Temporary selected-microphone Original/RNNoise comparison, explicit playback, replay, cancellation and cleanup.
- REA feature ledger assigning all 1,014 current catalog keys across 32 families: 22 retained, 6 unresolved, 4 excluded. These counts are scope assignments, not completion percentages.

No trial, subscription or payment gate exists in the independent implementation. Cloud services and analytics are excluded. Full feature, visual and audio parity has not been achieved.

## Verification

The last combined `./verify` completed with exit 0 across all ten component suites, including 54 desktop tests and 12 local-store tests. Release, ASan/UBSan, synthetic helper pipe integration, ARM64/macOS 12 packaging, signatures and relocated-resource checks passed. No real microphone capture or audible playback ran. Earlier REA observations verified limited desktop appearance and navigation, not the newly added widget or comparison UI.

The private local log is `evidence/combined-verify-library-location.log`, SHA256 `cffc5e3331f99263e4d92f4cd9ad97e41d98651b99070da6fca9a9850a4e7cce`. It is excluded from Git. The feature ledger now records 52 implementation source fingerprints.

After diagnostics integration, the desktop `./verify` passed 68 tests, signed ARM64/macOS 12 packaging and relocated-resource checks. The other nine components are unchanged from the combined pass above. Private log: `evidence/desktop-verify-diagnostics.log`, SHA256 `fb545d92a705ccaf2b38318016fe61b8f46714fd534bd9402a31da8d2aba090b`. REA opened Settings and Diagnostics in the built app and captured the form/current status with audio stopped. Native save/sample picker workflows remain unverified. A later label-only accessibility change names the issue description editor explicitly; its release build passed. VoiceOver behavior has not been exercised.

## Exact Mac state

The diagnostic independent driver is installed at `/Library/Audio/Plug-Ins/HAL/LabVoiceAudio.driver`. Its signed file-tree SHA256 is `5ca286e9483c605f82ecdfabeb830fd640dd5cd534eef3f390a4bef0b98dea95`. CoreAudio PID 94316 started at 10:27:21 Asia/Kolkata, before the diagnostic replacement. The final restart did not run. Diagnostic-driver loading is unverified. Earlier normal builds registered the plug-in but published no devices; the class-qualifier fix did not resolve that. No live route has run.

Do not reinstall just to restart. After Hari resumes and is available for administrator approval, follow `app/audio-driver/install-notes.md`: revalidate the installed tree, restart once, run the read-only discovery probe and inspect actual service traces. Only if exact endpoints are usable, proceed with the previously approved bounded synthetic HAL test and live routing plan. Otherwise diagnose or use the exact-match rollback. Private rollback script: `evidence/remove-trace-driver.py`. Never rely on stale PIDs.

## Local diagnostics

Settings exports a new private folder containing deterministic JSON and an optional explicitly selected PCM16 mono/stereo WAV copy. Optional date/system metadata are off by default. Reports contain typed current status and bounded event codes from this app run. No upload, historical log collection or automatic recording occurs. Export rejects existing destinations, malformed samples and destination replacement; failure cleanup removes only its owned files. Ten exporter tests and four controller tests are included in the 68-test desktop pass. Original report schema, all issue categories and general attachments remain gaps.

## Library folder selection

The Settings folder picker now validates and persists an existing library folder before switching. History reopens at that location; prior files stay unchanged. Missing, inaccessible or invalid saved paths show an error without silently creating or choosing another library. Imports, transcription, recording and other active writes block switching. Old dialog actions and asynchronous results cannot affect a newly selected library.

Recording preparation validates and retains the destination store identity through completion. A removed or replaced destination fails the save while preserving staging. History operations reopen by path/revision; they do not persist an inode identity across app restarts. The native picker interaction has not been exercised. Eight focused desktop tests and independent review passed; the combined verification also passed.

The next work should follow the retained gaps in `feature-parity-ledger.md`. Driver discovery remains the critical runtime prerequisite. Avoid treating further synthetic tests as proof of full audio parity.

## Remaining major work

- Resolve driver discovery and verify real microphone/speaker routing, cleanup, timing and audio quality.
- Verify and integrate installed original-model inference locally. Current catalog validation is not inference.
- Accent conversion, background-voice isolation, AEC, live ASR/captions, speaker labels and other retained features remain incomplete.
- Complete storage recovery, activation, lifecycle, diagnostics, notification and widget workflows from the feature ledger.
- Complete original-versus-rebuild interaction and audio comparisons. Do not infer parity from passing synthetic tests.

## Repository and local files

Private repository: https://github.com/Mr-Neutr0n/openkrisp

The source remains at `/Users/harikp/Developer/solo/reverse-engineering-lab/projects/krisp`; it is now its own Git repository without moving files. Build from its root with `./verify`. Requires macOS and Xcode command-line tools. The ad-hoc app output is `app/desktop/.build/app/Lab Voice.app`.

Raw REA evidence, original binaries/models/assets, generated audio, build outputs and analysis runtime are excluded. RNNoise source and its included model are included with upstream notices. Original Krisp weight redistribution terms are unresolved. Some historical evidence references and fingerprint keys use the enclosing lab-relative `projects/krisp/` prefix. These are provenance paths, not required checkout locations.

Use this file with `feature-parity-ledger.md`, `PLAN.md` and the component README files to resume. Historical PLAN entries describe previous states. This file records the latest verified source checkpoint; native runtime and full parity remain incomplete.


## Launch at login checkpoint, 2026-10-15

Settings now exposes an explicit user-controlled login item through macOS 13+ ServiceManagement. One shared controller reads actual OS status, distinguishes approval/not-found/unregistered states, refreshes on app activation and after requests, and rejects stale results. No preference write substitutes for OS registration. The app never registers from initialization or refresh. macOS 12 reports this feature unavailable. App settings scrolls to keep the added controls reachable.

Five injected-service tests and independent review passed. Desktop `./verify` passed 73 tests, signed ARM64/macOS 12 packaging and relocated-resource checks. Other nine components are unchanged from the preceding combined verification. Private log: `evidence/desktop-verify-startup.log`, SHA256 `6b1364a425c70f39a6aab7acf38c45ef40cc1a274dae4df3d7d20431fa8ef45a`. Real registration, approval, app relocation and launch after login remain unverified. No login item was changed during development. Original defaults and separate launch-window behavior remain unresolved in `startup-findings.md`.


## Finalized recording recovery checkpoint, 2026-10-15

Audio now has an explicit retained-recording review and confirmed Save copy action. Recovery accepts only private independent staging folders with matching job metadata and finalized 48 kHz stereo PCM16 WAVs. It validates file identity again before saving, retains the selected library instance, blocks capture/folder switching during work, and rejects stale confirmations. Original staging files stay untouched; repeated saves create separate sessions. Temporary cleanup failures identify their paths. This does not repair partial WAVs or recover LocalStore `.pending` imports, and it does not establish original crash-recovery parity.

Desktop `./verify` passed 86 tests, including nine backend tests and four controller tests using synthetic files, plus signed ARM64/macOS 12 packaging/resource checks. Other nine components remain unchanged from the prior combined verification. Private log `evidence/desktop-verify-recovery.log`, SHA256 `41e9430fdb1a70e2139269036c86975e84a4695f1a828e5f8fec89f3218d5ffe`. All 58 ledger source fingerprints match.

A bounded REA native UI attempt failed: Accessibility returned nil geometry for the selected app window, and image-only capture reported a stream capture failure. No recovery button was activated, no real recording was copied, and no audio or administrator action ran. Native UI acceptance remains unverified.


## Save-before-quit checkpoint, 2026-10-15

Reproduced an independent-app defect through the actual route/recording controllers with injected helper/storage: helper stop returned success after recording import failed, so the old delegate would approve quit without a saved session. Normal Quit now offers Save and quit or Cancel for active recording and requires positive session publication before approval. Save failure or uncertain helper/test cleanup leaves the app open. Nonfatal cleanup warnings do not invalidate a published recording.

Existing non-recording library work, recovery or diagnostic export cancels a quit attempt without interruption. A token-owned quit gate prevents new capture, recording, inventory helpers, library work and diagnostics export while shutdown awaits completion. Only the exact active recording library lease is exempt. Cancel/failure releases the gate; successful approval holds it until process exit.

Desktop `./verify` passed 97 tests, including 11 focused quit tests and the reproduced production-controller path, plus signed ARM64/macOS 12 packaging and resource checks. Other nine components remain unchanged from prior combined verification. Private log `evidence/desktop-verify-quit.log`, SHA256 `6db81f305a1042dabff5cc5ca29b9ccdbb55f413f4e1ea51d682f6bb1e279954`. Native alerts, actual termination, logout/reboot, forced kill and interrupted OS shutdown remain unverified. No audio, native quit or administrator action ran.


## Native frame contract checkpoint, 2026-10-15

Three GPT 6.1 sol workers recovered the ordinary NC factory, frame wrapper, callback and stream configuration paths through identity-bound static REA captures. The native layer appears separable from capture, but no standalone callable adapter or successful model output exists yet. Reports are in `native-frame-factory-findings.md`, `native-frame-processing-findings.md` and `native-nc-configuration-findings.md`; `model-provider-contract.md` consolidates them.

The SDK owns processor registry entries and returns non-owning handles. The wrapper copies Float32 input and the callback copies output into NC-owned storage. The caller expects immediate callback output. Matching sizes and success returns do not prove inference because bypass paths can return the original input. Exact configuration construction, descriptor and callback lifetimes, SDK dispatch and EOF/drain contracts remain unresolved. These are the next static questions before any native invocation.

Independent review found no conflicting ABI claims in the three reports. Root verified the duration mask and all 61 implementation source fingerprints. Source is unchanged, so the previous 97-test desktop verification remains the latest run; tests were not repeated for this documentation checkpoint. No addon execution, microphone capture, administrator action or model copying occurred. Full local parity remains incomplete.


## Native dispatch and lifecycle checkpoint, 2026-10-15

Static REA captures now establish synchronous callbacks for the selected ordinary NC path, normalized Float32 input/output scaling, exact frame-count validation, and the descriptor's duration/rate fields. Registry copies and cached processor values are distinguished from the retained borrowed descriptor address. The selected processor does not use that address in its inspected process/update/finalize/destructor path; a future adapter will still retain stable descriptor storage.

SDK close calls registry finalization and removes its owned entry. The selected ordinary NC flush/finalize slots are no-ops, so closing is not a recovered audio-tail flush. Descriptor updates also do not refresh this processor's cached parameters. Finite tests must use an unchanged validated descriptor and record any deliberate whole-frame padding separately from input length. Exact algorithmic latency and tail preservation still require runtime evidence.

The next implementation prerequisite is the remaining native callback/configuration ABI, with the direct typed factory route compared against the KMS wrapper route. See `native-descriptor-lifetime-findings.md`, `native-frame-dispatch-findings.md`, `native-stream-close-findings.md` and `native-nc-callback-construction-findings.md`. No addon processing, audio, model copying or administrator action occurred. Cross-review found no conflicting dispatch/close claims. All 61 source fingerprints still match; application code is unchanged and the prior 97-test desktop pass remains the latest verification.


## Typed callback support checkpoint, 2026-10-15

REA recovered the ordinary supplier return layout and borrowed result payload. Added experimental `app/native-model-probe` ABI carriers and a bounded result collector. It copies valid samples during callbacks, rejects malformed counts/nonfinite values/overflow, and retains no borrowed sample pointer. It does not load the original addon or implement an app provider.

`app/native-model-probe/verify` passes release and ASan/UBSan ownership/bounds fixtures. Independent review found no blockers within this fixture-only scope. Private log `evidence/native-result-collector-verify.log`, SHA256 `af2b23c5bc9c878f57c903eae540ceb7687f0e54dce818b63e0e6d7673da234e`. The 61 prior source fingerprints remain unchanged; five new probe source/verification entries bring the ledger to 66. Desktop code is unchanged, so its prior 97-test verification remains current rather than being rerun.

Next, compile a separate foreign-ABI fixture for callback slots, factory shared-pointer arguments/return and destruction. Then construct the exact-digest isolated processing probe using installed model paths and network denial. The selected factory is exported and its first SdkConfig-reference argument is unused by the recovered body; full SDK reconstruction is not an evidenced prerequisite for this path. No native factory was invoked, and output/latency/tail parity remain incomplete. Reports: `native-supplier-value-findings.md`, `native-result-value-findings.md`, `native-direct-adapter-design.md`.


## Native model processing checkpoint, 2026-10-15

The experimental direct-factory Node adapter now processes samples through the installed outbound NC model without an audio device. Two REA captures completed: NC and bypass each returned 100 callbacks and 48,000 finite samples, with clean process exit and unchanged addon/model/adapter hashes. Outputs differ in 47,500 samples. Both ran under an explicit network-denial sandbox profile and passed the launcher's EPERM prerequisite. See `native-direct-probe-findings.md` for the evidence IDs, hashes and numerical results.

Added the typed factory/callback views, separate-library ABI fixture, native Node adapter, fail-closed launcher and reusable tests. `app/native-model-probe/verify` passes release and ASan/UBSan collector/ownership fixtures, launcher rejection/publication cases and 20 host-only native validation cases. Private log `evidence/native-direct-probe-verify.log`, SHA256 `af5d72df9a55d5ebe11bf51b5d8b0e57e10152dec0579f2ae779b92044711cd3`. The ledger now fingerprints 74 source/verification files. Desktop and prior audio components are unchanged; no full-suite rerun or new physical-audio acceptance is claimed.

This is verified bounded native processing, not complete parity. The next step is a persistent isolated provider and explicit app/routing selection using this call path. Speech quality, sustained latency, initialization cost, tail handling, other models and live microphone/speaker workflows remain open. No vendor files were copied or published, and no CoreAudio or administrator action occurred.


## Resume validation and integration decision, 2026-10-17

The previously interrupted native-processing checkpoint was revalidated and published as commit `82cdf40`, tag `checkpoint-2026-10-17-native-processing`, in the private openkrisp repository. All 74 source fingerprints and both retained runtime outputs match. A fresh read-only REA identity capture, `ev_e019301744673b108100bb03356c7f37c5a64c45f939028457bed0264ff7da30`, confirms the installed addon and outbound model still match the reviewed hashes. It did not execute the addon or audio.

The first persistent provider must retain the proven Node host. An independent source/evidence review found 58 N-API imports from the flat namespace and no Node library in the retained addon's declared dependencies. A plain C++ executable with immediate dynamic binding is not a proven replacement host. Do not add symbol stubs or use lazy binding to conceal that dependency.

Next implementation slice: refactor the native adapter into persistent open/process/close ownership in a network-denied Node child, with a bounded native transport. Reuse the audio host's existing Processor callback and shared owner. The CoreAudio callback must only exchange ready samples and bounded state, never load the model, invoke Node, allocate or wait for inference. Construct the provider before route startup; latch invalid output, overflow, deadline failure or worker death into the existing route-stop path. Preserve callback-owned memory if CoreAudio cleanup fails.

Bind the exact addon/model/adapter and host runtime before loading. Extend the route startup acknowledgement and desktop validation together so the selected provider/model must match. Start with the proven microphone outbound model; speaker RNNoise retains its own identity until the inbound model is verified. Measure buffering delay rather than reusing RNNoise's 480-sample alignment constant. Synthetic worker/transport failures and parent-EOF cleanup must pass before live audio tests. No administrator action has been taken on resume.


## Persistent native sessions and transport checkpoint, 2026-10-17

Persistent `open/process/close` now keeps one installed model alive across batches. Two REA captures returned 100 callbacks and 48,000 finite samples across five irregular batches, with byte-identical output to the earlier single-call NC and bypass runs. A review fix now reports unexpected callbacks during destruction after completing cleanup. Final-build output still matches. The final NC capture has an unresolved REA cleanup-attribution limit, while final bypass has complete evidence and verified cleanup. Exact identities and limits are in `native-direct-probe-findings.md`.

Added callback-safe request/result queues and a bounded worker framing codec. The queues use an explicit synthetic 5760-sample delay, strict sequences and sticky faults. The codec rejects malformed/nonfinite frames, sequence replay, truncated EOF and parser reentry. These are standalone components, not a connected worker or route backend. No live audio, administrator action, driver change or vendor-file publication occurred.

Component verification passed release and ASan/UBSan collector/ABI tests, persistent ownership/failure tests, launcher cases, protocol fixtures and transport release/ASan/UBSan/TSan tests. Concurrent transport coverage uses 20,000 frames with test synchronization outside the callback. Log `evidence/native-persistent-transport-verify-20261017.log`, SHA256 `c3832e71f32964129ebe83d9ea4683760d5dbc16d0e7b445e3ee573f1f2a1398`. The subsequent codec reentry fix passed `evidence/worker-protocol-final-verify-20261017.log`, SHA256 `2d043c48297ef9545e415eb2c6d88449ef330d865dd4010ac61cc2994fb664cd`. All 83 implementation fingerprints match. Root `./verify` now includes this component; its shell syntax passes. Unchanged desktop/audio suites were not repeated, and their prior verification remains the baseline.

Next: connect framing and queues through a supervised Node child and broker, admit exact runtime/model identities before routing, and test timeout, child death, partial pipe IO and parent EOF. Then extend route acknowledgement and desktop provider selection together. The 120 ms test delay is not an accepted realtime budget. Full retained local parity remains incomplete; physical HAL admission still needs the deferred administrator/audio session.
