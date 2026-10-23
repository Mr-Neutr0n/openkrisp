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


## Worker session and wire compatibility checkpoint, 2026-10-17

Added a native C++ codec matching the Node worker protocol and a synchronous worker-session runner. The runner retains one supplied processor, handles fragmented reads and partial writes, rejects invalid output, and closes exactly once on explicit close, parent EOF or failure. Review reproduced and fixed swallowed falsy JavaScript exceptions. Explicit close requires the parent to half-close its request pipe and validate both the teardown acknowledgement and child exit; the eventual broker must enforce deadlines.

Synthetic real OS pipe tests pass for fragmented requests, matching responses, explicit close and EOF-only cleanup. Native/Node compatibility checks verify byte-identical frames and cross-decode each implementation's output. The full native component suite passes, including release/ASan/UBSan wire tests and concurrent transport TSan. Log `evidence/native-worker-session-verify-20261017.log`, SHA256 `5b62ce46a401260f6ea9af65597dcb4b5668b22e237abbbf3f9c82826b6351de`. All 88 source fingerprints match. No vendor artifact was loaded by this verification; no physical audio or administrator action occurred.

Next remains production child admission and broker supervision, then explicit app/routing integration. The runner has no production CLI and cannot supervise itself while blocked in synchronous IO. Child death, wall-clock stalls, process reaping and a connected callback-to-worker path still need acceptance tests. This checkpoint adds transport machinery, not a usable installed-model route or full parity.


## Supervised installed-model worker checkpoint, 2026-10-17

Connected the bounded callback queues to a dedicated broker thread. Added gated Node startup, exact readiness, a fixed network-denied launch builder with no inherited environment, nonblocking parent pipes, startup/frame/shutdown deadlines, idle child-death checks and owned direct-child TERM/KILL cleanup. Callback code performs no Node calls, pipe IO or waits. The broker must remain the child's sole reaper; stop and owner release belong to the control thread after callbacks are removed.

REA exercised the production launch builder and broker against the installed outbound model using only synthetic input. NC and bypass each completed 100 frames, 48,000 finite samples and broker-confirmed clean close. Outputs match the earlier direct probes byte for byte. NC startup/processing measured 246/64 ms; bypass measured 126/49 ms for one second of input. These single runs do not establish callback deadlines, quality or algorithmic latency. Bypass Evidence `ev_b3a8b624dc15c550a28ec23f5d92a3f133185e8a256ad71d916c430f4c8e9cb5` is complete. NC processing succeeded but REA's separate cleanup attribution was incomplete, so its retained partial capture has no Evidence ID. See `native-direct-probe-findings.md` for hashes and limits.

Full component verification passed release and ASan/UBSan fixtures, real OS pipe tests, protocol cross-language checks, broker failure/reaping tests, callback-to-worker ordering, repeated stop and confirmed stalled-processing stop. Queue and provider-thread TSan checks pass. Log `evidence/supervised-worker-verify-20261017.log`, SHA256 `f0d275655817140d47dd3d16073b933bbc4511b012fdf2b88dfbe3df5d3e2b1a`. All 99 source fingerprints match. Desktop and CoreAudio routing sources are unchanged. No physical audio, administrator operation or proprietary artifact publication occurred.

Next: timed callback acceptance and measured buffering, plus worker termination after abrupt parent death during permanently hung native processing. Normal EOF cleanup does not cover that hang. Then wire provider selection and identity acknowledgement into the helper and desktop together. Startup file hashes are sampled before reopening; they are not an atomic loaded-image guarantee. Full local parity and physical driver admission remain incomplete.


## Parent-loss protection and timed callbacks checkpoint, 2026-10-18

The installed worker now starts a native parent watch before opening vendor code. The launch builder supplies the actual broker PID. A native thread checks parent identity every 25 ms and exits its own process if the parent changes, even while the Node main thread blocks. Normal teardown stops and joins it. It never signals another PID. Scheduling can delay detection; abnormal exit skips C++ destructors and relies on OS process-resource reclamation.

C++ blocked-thread tests and actual Node/N-API blocked-JS tests pass for parent death and explicit guard stop. The Node test retains a separate request pipe across the intermediate parent's death, confirms parent exit separately from grandchild EOF, and cleans up without signaling a reparented PID. Full component verification passed release/ASan/UBSan and existing provider TSan checks in `evidence/parent-watch-timed-build-verify-20261017.log`, SHA256 `86d16e88d656ef1368cc20ba936a0f0e5938c4bbc09a90a65d350f6a7e762fc5`. The subsequent integration-test addition passed `evidence/parent-watch-node-integration-verify-20261018.log`, SHA256 `320d86f519033af0d0229520ab387edbe1e5a26ba8928a7e2e4bc7178be50cc8`, and is included in component verification. All 104 source fingerprints match.

REA timed probes ran 112 callbacks at 10 ms intervals, with 100 input frames plus 12 zero-padding frames for the explicit queue delay. Both processed all 112 requests with zero queue deadline failures, clean teardown and complete captures with verified owned cleanup. Removing only the 5760-sample transport delay gives output byte-identical to direct probes. NC maximum exchange/scheduling lateness was 10/2478 microseconds; bypass 281/11444 microseconds. Evidence `ev_1e069d57847168a68cb3c388899494a69908eba65b1a2f2803a96984d72c94da` and `ev_aaddd212cf3baed2368d6b1626a14238711366740a68edcc61ec0ba09220a321`. Exact identities and limits are in `native-direct-probe-findings.md`.

This proves paced CPU behavior with a 120 ms synthetic buffer, not accepted live call latency, sustained performance, CoreAudio timing, model-tail recovery or speech quality. Next choose buffering from the actual callback format, then extend route identity acknowledgement and desktop provider selection together. No physical audio or administrator action occurred. Full parity remains incomplete.


## Callback buffering and processor preparation checkpoint, 2026-10-18

Implemented immutable runtime buffer settings and callback-bound checks. The delay includes incomplete model frames, a full callback and an explicit scheduling budget. Defaults remain unchanged. REA tests with 480/1 and 512/2 settings passed at 30 ms and 50 ms explicit buffering, with zero transport deadline faults, clean teardown and byte-identical aligned NC output. This is short paced CPU evidence, not accepted live latency. Exact evidence and limits are in `native-direct-probe-findings.md`.

The audio host retains observed current and maximum aggregate callback sizes, watches size-range changes, and can prepare a processor after listeners are installed but before IO registration. A second inspection after factory startup catches changes during model loading. Context keeps processor ownership through failed callback/listener teardown. Invalid bounds, oversized callbacks, mixed legacy/factory bindings and factory exceptions fail with cleanup. Independent review found and fixed cleanup for nonstandard factory exceptions; no remaining blocker was found in this slice.

The installed worker is still fixed to the proven outbound NC model. Desktop provider selection and matching route acknowledgement are not connected yet. Use the new processor factory and aggregate maximum for that next slice. A large advertised hardware range may still require the conservative 120 ms buffer; do not substitute the current quantum without a proven bound. Physical HAL admission, actual routing, sustained timing, other models and full local parity remain incomplete. No live audio, driver replacement, CoreAudio restart or administrator operation ran.

Verification passed for the full native adapter component, including release/ASan/UBSan/TSan tests; the full audio-host suite, including synthetic routing and read-only hardware inventory; and desktop tests plus signed ARM64/macOS 12 bundle/resource checks. Other components were not repeated. Nine invalid timed-probe option cases also rejected before input access or child launch. All 106 source fingerprints match. Private logs:

- `evidence/runtime-buffering-verify-20261018.log`, SHA256 `c6cfd3e87c4bfe21ae269925ac6c20444a56909b15bc2fb5a32c45d5f1b6e971`.
- `evidence/audio-host-preparation-verify-20261018.log`, SHA256 `89a6071ad2626a1c828ed8c03351eb83e5c0c40930c382cf922f3eb98c88d004`.
- `evidence/desktop-preparation-verify-20261018.log`, SHA256 `a4f1ca438579d512d5c82e97d22b0ab883c916e772ddb58840c9cdc8dd8ff8d9`.


## Installed microphone provider integration, 2026-10-18

Connected the proven installed outbound NC worker to the audio host and explicit desktop selection. Audio retains independent RNNoise as its default. Installed selection requires the user-selected Krisp app and exact reviewed external Node, plus the signed packaged adapter and worker scripts. Validation reads identities off the main thread and admits only the exact outbound model. It does not launch a worker or request microphone access. Selections are session-only. Start captures an immutable configuration and requires a matching helper acknowledgement for provider names, all four identities, maximum callback size and derived delay. Speaker processing remains RNNoise; there is no automatic fallback on provider failure.

The helper prepares the worker from validated aggregate bounds before registering IO. It keeps a separate control-owned adapter, stops the worker on failure and shutdown even when HAL cleanup fails, and retains callback memory in Context. A scope guard covers exception unwinding. Synthetic tests exercise both speaker modes, continuous microphone queues, failure silence, concurrent stop/exchange and late Context release. Provider CLI validation rejects incomplete, duplicate and malformed settings before aggregate creation. Desktop startup allows 40 seconds for installed-model admission, with existing cancellation and late-reply guards.

The bundle includes only our adapter, three scripts and a manifest. The adapter now targets macOS 12; signing precedes hashing. Native and relocated-bundle checks verify hashes, signatures and resources. REA ran the actual signed packaged worker for NC and bypass at 50 ms explicit buffering. Both returned clean teardown, zero deadline faults and output identical to earlier direct probes. Exact evidence and limits are in `native-direct-probe-findings.md`.

Full native component verification, final audio-host verification and desktop verification passed. The desktop has 104 passing tests and signed ARM64/macOS 12 packaging checks. Audio-host checks include release/ASan/UBSan/TSan synthetic installed-adapter coverage and read-only inventory. An earlier audio-host verification invocation ended with status 2 and no diagnostic after partial output while its script was being edited; the final unchanged-script rerun completed successfully. No success claim relies on the partial log. Other components were not repeated. All 116 source fingerprints match.

This is an integrated experimental source checkpoint, not a full-parity release. Native chooser/validation UI, actual installed-model HAL routing, latency/quality, model-tail behavior, other models, AEC, live transcription and remaining lifecycle/UI parity still need work. The physical driver admission/restart remains deferred. No live microphone, CoreAudio restart, administrator operation or vendor-file publication occurred.

Verification logs:

- `evidence/provider-route-native-verify-20261018.log`, SHA256 `c6cfd3e87c4bfe21ae269925ac6c20444a56909b15bc2fb5a32c45d5f1b6e971`.
- `evidence/provider-route-host-final-verify-20261018.log`, SHA256 `314a4847dc1b71489bfa2f83196fd6fb4a795ba25f0394d0543d6024de5ec269`.
- `evidence/provider-route-desktop-verify-20261018.log`, SHA256 `2a40b0522c88e82b58c1ca4fbe7d03ca318180629913e4e49f7f51ae868963a1`.
- `evidence/provider-cli-final-verify-20261018.log`, SHA256 `cbc6ab8f03a2c049f01a8111162492bec7b056777ae4cad7ddf8ffcb9ed7bf08`.


## Inbound evidence and partial native UI acceptance, 2026-10-18

The installed inbound model returned 100 callbacks and 48,000 finite samples in separate synthetic NC and bypass runs. Both helpers completed native teardown. The NC capture has unresolved REA ownership cleanup and no successful Evidence ID; the bypass capture completed. See `inbound-model-findings.md` for identities and exact limitations. This is processing evidence, not perceptual quality or live routing acceptance.

REA opened the independent app through LaunchServices and observed the Audio sheet with audio stopped, no selected devices, driver unavailable and a visually disabled Start audio button. The provider menu showed Independent RNNoise and Installed Krisp outbound NC. Main-window Evidence is `ev_125920966322d0ac4a95f39440e59c51baf71215f22f6bf1571a6281dd4be3e9`; Audio sheet `ev_4febec546cad34f48db0062f7212a2ca5c611f4d17fdae7059da834d616ee4d1`; provider menu `ev_eea41eac38c17fc4a6e685a47dab2f24366a018b477d4051ee74834a31503e42`. No audio or provider validation was started.

Menu selection remains unverified. REA's native-window admission failed while the popup was open. A scoped helper found no matching menu item and performed no AXPress. The launch capture later ended, and a fresh observation could no longer bind that PID to an application executable. No unrelated process was signaled. These observations do not verify the installed-provider chooser, validation action or a route start.

The fresh read-only driver inventory still reports feed and monitor absent. Administrator changes, CoreAudio restart and physical audio remain deferred.


## Explicit model role admission, 2026-10-18

The native worker now accepts only the exact reviewed outbound or inbound role/hash pair. Configuration requires both fields. The readiness record is `OKREADY2` and includes the role and four identities. Legacy nine-field worker configurations are rejected. C++ callers retain outbound defaults. The existing microphone adapter rejects inbound settings before any child or test factory starts; the desktop and host still expose only outbound installed processing.

Independent review found no blocking issue in admission, readiness matching or current desktop/host ownership. Full native and audio-host verification passed, including release, ASan/UBSan, TSan and existing lifecycle checks. Broker fixtures accept both roles and reject a wrong role with otherwise matching hashes. Desktop verification passed with 104 tests and rebuilt signed/relocated bundle resource checks. All 116 recorded source fingerprints match.

Verification logs and SHA256:

- `evidence/model-role-admission-verify-20261018.log`: `c6cfd3e87c4bfe21ae269925ac6c20444a56909b15bc2fb5a32c45d5f1b6e971`.
- `evidence/host-outbound-role-verify-20261018.log`: `f133fc38810d78792217ef1c80c608f38681efd9a3b42ea8de544b9543ebe124`.
- `evidence/model-role-desktop-verify-20261018.log`: `802bf107ee99847547c8d7ccb53fdd2a532a06892dcf1f6fe59a335cfeccebda`.

The selected original stereo bridge is now established by static evidence in `native-speaker-channel-findings.md`. Next implement and test one independently owned inbound worker with stereo averaging before processing and mono duplication afterward. Then connect speaker-specific identity/configuration acknowledgement and desktop selection together. Original desktop topology, complete stereo runtime comparison, sustained deadlines, quality and live driver routing remain unverified. No full-parity release claim is made.


## Installed speaker integration, 2026-10-18

The host and desktop now independently select installed outbound microphone NC and installed inbound speaker NC. Each installed lane owns its worker, model state and immutable identity settings. Speaker processing averages each Float32 stereo pair before its mono worker and duplicates the processed sample to both playback channels. RNNoise and disabled lanes retain their existing processing or passthrough. The UI explains the installed speaker's mono behavior.

Both worker configurations validate before either child starts. Partial startup stops the first worker, and shutdown attempts both even when one fails. The callback preflights the complete input block and rejects nonfinite values or overflow in stereo summation before advancing either lane. Supported-size failures silence both outputs. The separate control-thread owner and scope guard retain safe cleanup when HAL teardown fails.

The CLI keeps existing microphone flags/ACK fields and adds an independent `--speaker-provider-*` namespace with `speaker_provider_*` identity/buffering acknowledgements. Both groups require their suppression option and all runtime fields before aggregate creation. Actual parser fixtures cover five valid single/dual/mixed profiles with distinct lane paths; twenty invalid profiles reject. No fixture starts a route. Desktop selection hashes only requested roles, publishes dual admission atomically, rejects stale results and captures both configurations at start. ACK matching validates each lane and rejects unexpected identities. Startup allows 40 seconds for one installed worker or 70 seconds for two.

Independent review found no actionable defect. Full audio-host verification passed, including release/ASan/UBSan/TSan adapter tests, partial startup, both-worker shutdown, irregular callback continuity, left/right/identical/opposite/distinct stereo inputs, RNNoise/passthrough and retained Context lifetime. Desktop verification passed 109 tests, signed ARM64/macOS 12 packaging and relocated worker-resource checks. The new timed-probe role option compiled with warnings as errors; three invalid-role cases rejected before input access. All 117 source fingerprints match.

- Host log `evidence/installed-speaker-adapter-host-verify-20261018.log`, SHA256 `4b1df7cd9ec48c525c1d95682e19cee5777333f53790755ad62976bd692b4591`.
- Desktop log `evidence/installed-speaker-desktop-verify-20261018.log`, SHA256 `6ad43bac857aa0f0791f674365be2b29f10b21497d6ef182018c789fc4780b5e`.

The paced inbound CPU helper processed 105 frames with zero queue faults at 50 ms explicit buffering and returned output byte-identical to the direct inbound probe. REA ownership cleanup remained incomplete; this is a partial capture, not complete runtime acceptance. Exact metrics and limitations are in `inbound-model-findings.md`. This test used the preceding signed worker package, whose worker protocol and native adapter are unchanged by speaker UI/host integration. It did not exercise the dual adapter with original models.

Next verify the dual adapter with synthetic input through both installed workers, inspect the actual selection/validation UI, and recover the original desktop speaker topology. Actual driver routing, sustained timing, speech quality, model tails, AEC/BVC/accent and the remaining local-feature/UI parity are still open. No physical audio, driver replacement, CoreAudio restart, administrator operation or proprietary-file publication occurred. Full parity remains incomplete.


## Locked-session UI attempt, 2026-10-18

REA confirmed no running independent app before launching the signed bundle for a no-audio UI check. Inventory evidence `ev_3c5b0d96720a99045744cc5377d5f560d281baa216150bbfd12e90a0d9ccd458` preceded the launch; `ev_618c2d6de7ad8a25220dcf8784239d04e92cf4dc6e8baa169233fb5396a73f99` bound its process and windows. The executable SHA256 was `a14945ec24ecf5a73980e1e2893339fe64b5116dd7be34f20486bd6baf3f68d8`.

Native observation could not match the main window geometry. A bounded read-only AX helper returned an application element where a window was expected and no usable Audio controls. A second deduplicated traversal confirmed that condition. These did not exercise provider selection or validation.

Cleanup evidence `ev_438b5f8a35b5037cfec2524632e419d4988d9e8ec39199bf6be7451e5b6cfc79` reported `screenLocked:1` and accepted termination of only the exact test PID after checking executable path, launch timestamp and hash. The LaunchServices `open -W` child exited 0. Its separate REA cleanup attribution was incomplete, so the launch capture has no successful Evidence ID. No unrelated candidate was signaled. UI acceptance remains pending an unlocked session; no route, microphone test, model validation or permission prompt was started.


## Dual installed-model adapter runtime, 2026-10-18

A bounded independent probe now exercises the actual dual adapter with both installed models through its production workers. It creates no CoreAudio route. The deterministic microphone fixture matches prior direct probes; the speaker input alternates the doubled fixture between left and right, so Float32 averaging recovers the exact same mono input. Both lanes use a 512-sample callback bound and two-frame scheduling budget, giving 2400 samples of explicit delay.

REA Evidence `ev_0b8f21763dd187e4803927e806f568fa7fc49656251867462dbba4547a86a1dd` completed with exit 0, no truncation, verified owned-process cleanup and removed temporary root. Both distinct workers processed 105 frames, including five padding frames, and confirmed teardown. Published output has 48,000 finite samples per lane; speaker left/right are identical. Microphone bytes match the direct outbound result, and deinterleaved speaker bytes match the direct inbound result. Independent review checked the input averaging, output bytes and REA lifecycle.

Startup took 197 ms; callback exchange peaked at 18 microseconds and scheduling lateness at 5220 microseconds in this single run. Before/after hashes matched for the reviewed Node, addon, both models and four packaged runtime files. These are sampled file identities, not atomic loaded-image binding. REA does not trace network syscalls or every short-lived process. The production worker's deny-network launch and EPERM prerequisite remain in use.

See `dual-installed-adapter-findings.md` for exact hashes, commands and scope. The probe compiled with warnings as errors and its actual REA execution passed; unchanged production suites were not rerun. All 118 source fingerprints match. No proprietary files were copied into the repository.

This verifies the independent adapter's short CPU execution and channel conversion with the installed models. Original desktop topology, complete original stereo comparison, sustained deadlines, physical routing, quality, algorithmic latency and tail behavior remain unverified. UI acceptance is deferred because the current Mac session is locked. The next independent work is recovering the original desktop speaker topology and other retained local processing contracts; live driver work remains deferred.

The standalone probe's separate build-only check also passed with empty compiler output. Log `evidence/installed-dual-probe-build-20261018.log`, SHA256 `d974dfbf00826a967eabc06068e7c47a36ed3633bdad0a8d90c0a2273b7f615a`. The captured executable was preserved.


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

### Next integration boundary

The current host uses 48 kHz mono microphone and stereo playback in callbacks up to4096frames. The accepted AEC probe uses32 kHz forward. First verify a bounded48 kHz forward/48 kHz reference variant with the same controls before adding a production rate conversion. Then build a separate versioned duplex worker without changing the NC wire contract, pairing microphone and reference samples with sequence/sample-clock information. Reuse parent-watch, bounded transport and owned teardown patterns. Foreign AEC calls stay off the audio callback.

For actual routing, the reference must be the final playback signal after speaker DSP and gain/mute, not raw monitor input. Preserve sample timestamps and measure reference history and added queue delay. An optional experimental AEC stage with microphone NC disabled can precede an explicitly validated AEC-to-NC chain. Physical acoustic timing, sustained worker deadlines and live double-talk remain acceptance gates. The speech probe does not authorize a default-on production feature.


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
