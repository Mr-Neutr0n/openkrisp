# Checkpoint

Latest verified work: [Selected app audio source, 2026-10-29](#selected-app-audio-source-2026-10-29). Earlier sections retain historical implementation and evidence limits.

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


## AEC route adapter and explicit CLI checkpoint, 2026-10-23

The explicit installed AEC adapter now connects the validated route layout to AECDuplexWorker. It passes raw microphone and final stereo playback after speaker processing, gain and mute, while preserving separate lane sample origins and host-anchor validity. The callback performs no worker launch, IPC or join. A separate control owner stops the worker through startup failure and failed HAL cleanup; queued callbacks retain stopped storage. Expected callbacks after clean stop produce silence without a false diagnostic.

The helper accepts exactly four AEC runtime options and checks the own worker hash before route creation and again before launch. The installed library hash stays fixed. AEC defaults off, rejects microphone NC/provider combinations, and supports existing speaker processing once. Startup JSON reports AEC identity, format, callback bound and delay. The distinct microphone provider causes older desktop clients to reject unexpected AEC rather than silently ignore it. Existing AEC-off fields stay unchanged.

Full audio-host verification passed, including release, ASan/UBSan and TSan adapter tests. Own-worker/own-library route tests cover maximum callback bounds of 480/512/4096, budgets2/4, irregular partitions, exact final reference and delayed microphone output, timing provenance, fixed admission, foreign failure and retained ownership. Explicit processed-frame handshakes occur outside callbacks; these tests do not prove real-time scheduling. CLI parser/ACK tests use a sink that cannot create routes. Desktop verification passed117tests plus signed ARM64/macOS12 packaging and relocation checks. Independent review found no remaining issues.

Verification logs: `evidence/aec-route-adapter-verify-20261023.log` SHA256 `53da3c19ee6933ac493fdff9c0c0d813f26fdf5c114d81034bcbe0e0f9accab3`; `evidence/aec-route-desktop-verify-20261023.log` SHA256 `4335c4afed34835dd4b7ce5c885a435163bbc9d9ebf9cf0ec34f70fbab70cb78`.

Next package the own AEC worker and add explicit desktop selection with matching startup acknowledgement and restore/error tests. Keep microphone NC disabled until a separate AEC-to-NC chain is validated. Physical audio, acoustic alignment, speech quality, desktop visual acceptance and full retained local parity remain incomplete. No original code, physical audio or administrator action ran in this checkpoint. Vendor assets remain external and excluded from Git.


## Packaged AEC worker and desktop controls, 2026-10-23

The desktop app now bundles its own signed ARM64/macOS12 AEC worker and offers explicit echo-cancellation selection, initially off. The installed app supplies the fixed reviewed external library. AEC-only validation does not require Node. It checks bounded ordinary files, executable mode, the exact manifest and hashes, and observed identity changes without loading vendor code or starting audio. The packaged worker build preserves the frozen runtime-probe executable.

Changing the selected app, AEC toggle or microphone-noise option invalidates admission. Validation IDs reject stale completions. The UI and controller reject simultaneous microphone NC and AEC; speaker processing remains available. Start still requires microphone authorization and exact helper acknowledgement. AEC acknowledgement checks reject missing, incorrect, null or unknown AEC fields, microphone NC metadata, and inconsistent callback bounds between AEC and installed speaker processing. Disabled AEC rejects all AEC fields. Startup budgets count both workers when selected.

Full desktop verification passed128tests, release build, signed package and relocated-resource checks. New controller tests cover default-off/noNode validation, configuration invalidation, failed and stale validation, mismatched acknowledgement, late readiness, permission cancellation, and AEC plus installed speaker processing. Resolver tests use own files with injected vendor hashes; actual hashing, symlink/mode/bounds and observed mutation rejection are tested independently. The packaged executable also passed the existing release adapter integration against a freshly compiled own synthetic library. Independent GPT6.1sol review found no remaining issues.

Verification logs: `evidence/aec-desktop-verify-20261023.log` SHA256 `80afb14134221ce5af362018982a4298093c0ba6867003f922d1816034b78108`; `evidence/aec-packaged-worker-verify-20261023.log` SHA256 `1d83287bbbec6e07aec962a005e86f716023f25792e7656148edb5dee373a034`.

No physical route, microphone, OS prompt, original artifact execution or administrator operation ran. Original libraries/models remain external and excluded from Git. UI rendering, acoustic alignment, speech quality, device lifecycle and full retained local parity are still unverified or incomplete. Next implement and verify the separate AEC-to-microphone-NC chain, including combined startup delay and failure propagation, before allowing both toggles. Physical acceptance remains a separate gate.


## AEC to microphone NC chain checkpoint, 2026-10-23

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

The own worker and probe now admit the exact `outbound-hvc-lfb` model as a separate role. Existing outbound/inbound defaults and identities remain unchanged. The probe accepts explicit model role and bypass options, rejects duplicates/unknown values before loading input, and reports the admitted role/hash. Product microphone selection and headset policy remain absent.

REA `ev_f0e42f64a009b52eb8aed7c7e30177101eb560c64ade103e2096a899bb788753` passed with complete raw output, unchanged before/after pins and verified owned cleanup. Fresh active and bypass persistent workers each returned 100 frames, 48000 finite samples and confirmed teardown. Their bytes match the retained direct-HVC outputs. See `background-voice-persistent-findings.md` for exact pins and comparison hashes. The historical direct capture's failed raw-input assertion remains recorded. Static REA findings now close the NC descriptor construction join and identify packaged RD defaults and the alternate energy/statistics branch.

Full native-model-probe and audio-host verification passed, including their existing release and sanitizer suites. Desktop verification passed 138 tests, ARM64/macOS12 build, signing and relocated-resource checks. Its first packaging attempt rejected the stale audio helper; rebuilding the helper resolved that dependency failure. Independent GPT6.1sol reviews found no remaining source or report issues. All 165 source fingerprints match.

- `evidence/hvc-persistent-native-verify-20261025.log` SHA256 `27fa4898b40c0dadccfd52bc7d07fb8f6c0374d9882ccb9c1d4e39913d019a6a`.
- `evidence/hvc-persistent-audio-host-verify-20261025.log` SHA256 `acd06b866b17276a3bc787b10bc4276ca713356a7e513dead5c956ddc7c1a491`.
- `evidence/hvc-persistent-desktop-verify-20261025.log` SHA256 `ff012b0ef7169ced5ca5453e5feeb1ee23c493712e17aa9fb5c2aa4d42916bac`.

Next integrate explicit installed microphone HVC selection, exact role/hash startup checks and invalidation when settings change. Preserve inbound-only speaker admission and reject HVC with AEC until separate composition validation. This bounded CPU evidence does not establish voice isolation, target-speaker preservation, real-time deadlines, physical routing or full retained local parity. No physical audio, administrator action or original app UI ran. Vendor binaries/models remain external and excluded from Git.


## Experimental HVC microphone integration, 2026-10-25

The desktop installed microphone provider now offers explicit experimental background-voice selection using the fixed HVC-lfb model. Ordinary NC remains the default. Changing mode invalidates model validation and pending results. The selected microphone role is separate from the speaker, which stays inbound-only. Startup requires the exact selected role and artifact hashes for both installed lanes. Missing, null, unknown or inactive-lane role fields reject the acknowledgement.

The host accepts optional microphone-only `--provider-model-role outbound|outbound-hvc-lfb` and derives the fixed hash internally. Old ordinary profiles remain valid. HVC with AEC rejects in the desktop controller/options, parser, route entry and AEC chain before worker or route startup. The UI locks selection during an active route, advises headset use and notes that quality testing remains pending. There is no automatic headset inference or persistent per-device confirmation yet.

Full audio-host verification passed, including release, ASan/UBSan and TSan integration checks. Full desktop verification passed 142 tests, signed ARM64/macOS12 packaging and resource checks after relocation. New tests cover exact HVC model resolution, stale mode validation, malformed roles, crossed hashes, microphone-only admission, HVC/AEC no-launch behavior and real C++ parser/formatter-to-Swift acknowledgement decoding. Independent GPT6.1sol source/test reviews found no remaining issues. All 165 recorded source fingerprints match.

- `evidence/hvc-route-host-verify-20261025.log` SHA256 `b7967306bc4858ad7e7d92aeab1685b21b83aeec708d4ba81533cc171f24f513`.
- `evidence/hvc-route-desktop-verify-20261025.log` SHA256 `a3f0d662409551f0d3eb612866f168cbfbe726455c0abf8fb1a86ddad5e7206c`.

This checkpoint adds product controls and own-fixture route integration. The retained persistent CPU gate remains the installed HVC processing evidence; no new vendor execution or real audio route ran here. Voice isolation, target-speaker preservation, real-time deadlines, physical driver/routing acceptance, native visual interaction and full feature parity remain unverified or incomplete. HVC with AEC stays unavailable until its own composition gate. Original models and binaries remain external and excluded from Git.

Next implement the local per-device headset confirmation policy described in PLAN.md. Preserve the deferred administrator-dependent driver discovery step. Do not reinstall the driver merely to restart CoreAudio, and do not treat synthetic tests as physical routing acceptance.


## Manual headset confirmation, 2026-10-25

Desktop now persists explicit confirmations by exact device UID, with stored names used only for display. Experimental HVC validation and Start require a confirmed selected input. Remove and reset invalidate model admission; reset clears only confirmations and returns to ordinary microphone mode. Policy mutations reject while a route, recording, inventory load, other capture or quit is active. Confirmation itself never requests microphone permission or starts a helper. Malformed, duplicate, unsupported-version or oversized stored records grant no confirmations. This is an independent manual policy; the original matches manual name substrings, so original compatibility parity remains incomplete.

A production-controller test reproduced stale startup when input UID or HVC mode changed away and back during the permission wait. The fix captures provider/AEC admission revisions at Start and requires them unchanged before helper creation. The regression verifies zero helper launches for both roundtrips. Full desktop verification passes 148 tests, ARM64/macOS12 build, signing and relocated-resource checks. Focused tests cover persistence, renamed devices, equal names with distinct UIDs, scoped remove/reset, malformed records, stale validation and capture-free confirmation. Independent GPT6.1sol review found no remaining issue. All 167 source fingerprints match.

- Failed pre-fix reproduction: `evidence/headset-policy-repro-20261025.log`, SHA256 `d5a30b8c21fb9b9d8bd32d69809fc5b058d15dff7a696dd9a6450abe2fe28806`.
- Passing 27 focused tests: `evidence/headset-policy-focused-20261025.log`, SHA256 `d7a30074e2dd4e1ba20cf915787bf8055c7e3da301a16b8e83f8c0388d8b6fc9`.
- Full verification: `evidence/headset-policy-desktop-verify-20261025.log`, SHA256 `661679a12c6e7fef58abb747a453b01f9c45d39de3f0eb5b68b880844d58a617`.

Static REA captures `ev_18778f368464b2a9e4ef67192d174ff8a8b7a42d22d3f2bd8638fe0074b9d253`, `ev_bf65d20227611a5f87a999080958c3764e25cd504f1d34062dd8de9a1cf6545c` and `ev_a763befd06a4987fd6d43e2aab86f0eeee7b83ce95ceac5e22d7d19ff2785625` recover exact original interfaceName/manufacturer/modelId matching, case handling, precedence, cache parsing and observed list schema. The cache contains 152 allow and 701 block entries; three model_uid-only blocks do not match the recovered predicate. See `background-voice-controls-findings.md` for retained paths, pins and bounded coverage. No vendor list is included in Git.

Native UI acceptance remains unverified. Window inventory `ev_ca6fa1ca97f0069e2bc88581b5da05964fd6f59a1f2a8ea98e35c865e3302fb7` found the newly launched app PID 57664/window 487514. An initial empty-step request was rejected by schema; the corrected wait-only scenario then failed with `process-identity-unavailable` because the selected app exposed no launch time. No control was activated or screenshot accepted. Retained result: `evidence/headset-ui-observe-20261025.result.json`.

The direct own-app launch reached its 180-second bound and received SIGTERM. Its partial observation records signal 15/timeout. REA returned cleanup incomplete because ownership tokens for three live candidates could not be read, and retained its temporary root. A subsequent read-only process check found the known app PID absent; two remaining candidate PIDs were Chrome renderers in a different process group, and the third was absent. None was signaled or modified. Preserve this as an incomplete cleanup report, not a successful REA capture. Raw result: `evidence/headset-ui-launch-20261025.result.json`. No physical audio, original application execution or administrator operation ran.

Next recover the original CoreAudio metadata mapping and implement automatic local compatibility with the recovered precedence. Keep native UI, driver discovery, physical routing, acoustic quality and complete retained-feature parity as separate open requirements.


## Native metadata and local compatibility engine, 2026-10-25

The helper now exposes `interface_name`, `manufacturer`, `model_id` and per-device `metadata_read_errors`. It reads the original-mapped CoreAudio global name, manufacturer and model UID selectors at main element zero. Optional property failures keep empty strings and diagnostics without discarding an otherwise routable device or changing global inventory-error behavior. Swift preserves absent versus empty metadata and never derives interface identity from display names. Optional-read diagnostics are informational; name-only compatibility can still match, as in the recovered original path. The new header participates in stale-helper packaging checks.

The standalone `LocalHeadsetPolicy` implements local mode/rate gates, blocked-before-allowed-before-manual precedence, truthiness and branch-sensitive malformed fields, UTF-16 substring matching and exact manual-name removal. Its bounded external-cache parser preserves previous lists on failed loads. Null entries skip matching because the recovered method guards null before field access. Account/team policy and network refresh are excluded. This engine is not yet connected to automatic model selection; explicit HVC and the interim exact-UID confirmation flow remain unchanged.

Full audio-host verification passed release and sanitizer suites. Full desktop verification passed 160 tests, signed ARM64/macOS12 packaging and relocated-resource checks. Focused tests cover metadata selector/scope failures, optional-field continuation, absent/empty decoding and 35 local cases from an own 43-case static fixture; eight team/account cases are explicitly excluded. The fixture contains no original source or vendor list. Independent GPT6.1sol reviews found no actionable issue. All 175 recorded source/verification/fixture fingerprints match.

- Host log `evidence/headset-metadata-host-verify-20261025.log`, SHA256 `a7598b0ff965c56836cb233fcdb817f9ffc36d5a720dc9a59f1e83d6aac7dc03`.
- Desktop log `evidence/headset-metadata-desktop-verify-20261025.log`, SHA256 `612861afedb3ba60349a66612b25c158efbf80cc74432319a5c5d3bc59d77738`.
- Focused log `evidence/headset-metadata-focused-20261025.log`, SHA256 `3fbe207c37874530e10a924d42b6ef4ff6e379174c94e9fb7565730cb759ce11`.

The native mapping report binds six accepted static REA captures in `background-voice-controls-findings.md`. Later device grouping/name mutation remains unresolved. A string-conversion capture has complete disassembly but failed cleanup acceptance; a subsequent grouping query returned no usable observation. Those failures are retained and are not counted as accepted runtime evidence.

Original extracted-method replay produced no dynamic outcomes. Attempt v1 failed before invocation because its method wrapper had a syntax error; corrected v2 failed REA process lifecycle cleanup. Exact scenarios, runner pins and failure records are retained under `evidence/model-probes/bvc-matcher-extracted-20261025-*`, summarized in its notes file. The own fixture expectations are derived from static source. They do not prove original JavaScript execution parity. A read-only check found candidate PID87915 absent and PID88374 a Chrome renderer in a different process group; neither was signaled, and no provider repair or bypass was attempted.

Next connect offline list selection and recovered local/manual policy to automatic NC/HVC selection, with stale-admission protection and ordinary-NC fallback for unavailable compatibility. Preserve separate gates for actual policy execution, later native grouping, cache provenance, JSON/Unicode edge cases, physical routing, acoustic quality, visual acceptance and full retained-feature parity. No physical audio, original application execution or administrator action ran in this checkpoint. Vendor assets remain external.


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

The helper now supports explicit `--list-audio-use`, and Audio offers Observe audio use with a checked timestamp. Ordinary Refresh Devices does not inspect processes and clears the previous observation. The read-only snapshot preserves actual and responsible PIDs, optional input/output activity, current device UIDs and per-row errors. It does not start audio or infer calls. Cancellation, power and Quit use the existing inventory-generation protections.

The original's macOS 14.4 source gate is implemented. Unsupported and failed sources stay distinct; failed direction reads remain unknown. Process, device, text and serialized-output bounds prevent optional process data from swallowing normal inventory. App version remains unknown. No continuous listener, grouping, normalization, debounce, blocked-app policy or recording activation is implemented by this checkpoint.

A single bounded runtime query on macOS 26.4.1 returned 39 process records. All reported idle input/output flags. Responsibility lookup resolved 33 records and fell back for six; 15 had different actual and responsible PIDs. Active-device mapping was not exercised live. This observation preceded final serializer-error and missing-name diagnostic corrections. It supports the unchanged successful-read path, not an exact-final-build runtime claim. Raw process metadata remains private and ignored.

Independent GPT 6.1 sol review caught and closed a nested oversized-JSON schema error. The regression exercises control-character escaping expansion. Full desktop verification enumerated 199 tests: 198 passed and the opt-in native power listener test was skipped. ARM64/macOS12 packaging, signing and relocated-resource checks passed. Native snapshot UI interaction remains unverified.

Full audio-host verification also passed release and sanitizer suites. The default runtime process query remained skipped.

- Host log `evidence/audio-process-usage-host-verify-20261028.log`, SHA256 `2f0e79ef4732e932dda97a0bcf2b54d2d036f2748c657ec94af0613c2a578a3d`.
- Desktop log `evidence/audio-process-usage-desktop-verify-20261028.log`, SHA256 `05f69b8a32dd6cd209def5fd2a0e03f29d517776f8ef9113f5e97662f5e191d4`.
- Runtime snapshot `evidence/audio-process-usage-runtime-20261028.json`, SHA256 `b81fbf7bc3f4343948f7a6cbf5f3568f435648851b462f100aca66df67e1e801`.

REA static evidence also closes responsible-PID/device grouping, the source-version branch and packaged start/stop delay defaults. `activation-findings.md` records exact evidence and remaining limits. Call.hasBothLegs/addDeviceUsage, effective delay overrides, older-source behavior and the recording/transcription activation join remain unresolved. Original code did not execute. No physical audio or administrator action ran.

Next implement the continuous observation lifecycle and recovered grouping, then connect call policy only after its missing leg and activation semantics are established. The administrator-dependent driver restart stays deferred. Full retained-feature and audio parity remain incomplete.


## Grouped audio use, 2026-10-28

The explicit Audio snapshot now shows active app usage grouped by responsible application. The helper supplies optional input-stream metadata for each used input device. Desktop normalization follows two separate ascending-ID passes: remove devices without input streams, then remove output overlaps. Each pass stops at one remaining input. Unknown metadata blocks only decisions that need it; output usage remains independently available.

Grouping includes sorted unique actual PIDs from all records for each responsible PID, including idle helpers. It visits processes and devices in ascending object-ID order, then deduplicates each direction by the exact UTF-8 application-ID plus decimal device-ID key. The first candidate survives, matching retained native unique insertion. Unknown owners invalidate complete helper-PID lists. Key collisions remain visible as incomplete results. Public microphone/speaker and internal feed/monitor UIDs stay distinct without granting call eligibility.

The view shows app names and device use instead of raw PID rows. Presentation groups sort by responsible PID; original callback output ordering is not claimed. App version remains unknown. This is still an explicit instantaneous snapshot, without continuous listeners, timing stabilization, call qualification or recording activation. Native UI and active-device runtime mapping remain unverified.

Six new grouping tests cover the two-pass counterexample, singleton stopping, branch-sensitive unknowns, output independence, inactive sibling PIDs, ascending collision selection, Unicode byte identity and public/private device roles. The production C++ formatter feeds Swift decoding and grouping in an existing integration test. A native injected stream-property failure preserves unknown metadata and row errors. Nine focused tests passed. Independent GPT 6.1 sol review found no remaining issue.

Retained REA evidence now establishes the direct APP_CALL_STARTED to ASR admission to recorder-start event path, including stale-call rejection and failure boundaries. Account and remote-service gates are separated from local mechanics in `activation-findings.md`. A single static reanalysis with a larger 2 GiB heap still exhausted semantic extraction. Its partial graph cannot recover the missing Call leg definitions or effective delay clamps; zero trace matches are not an absence proof. No original application code, physical audio, runtime process query or administrator action ran in this checkpoint.

Next implement continuous observation and recovered stabilization, and obtain the remaining Call and local activation-policy definitions through a supported bounded source path. The driver restart remains deferred. Full retained-feature and acoustic parity remain incomplete.

Full audio-host verification passed release and sanitizer suites. Full desktop verification enumerated 205 tests: 204 passed and one opt-in native listener test was skipped. ARM64/macOS12 packaging, signing and relocated-resource checks passed. Host pass-message text matches the prior run, so its log hash is unchanged; source fingerprints and stale-helper packaging checks bind this rebuilt source.

- `evidence/audio-use-grouping-host-verify-20261028.log`, SHA256 `2f0e79ef4732e932dda97a0bcf2b54d2d036f2748c657ec94af0613c2a578a3d`.
- `evidence/audio-use-grouping-desktop-verify-20261028.log`, SHA256 `2a574b8ec0a6316570e4581f41530b4596f9db9cfce3a014f19c2546376d6034`.
- `evidence/audio-use-grouping-focused-20261028.log`, SHA256 `e625055353ceca8023cd764c62802366966d15f351c969d2816bda9f4d9d8b49`.


## Continuous audio-use observation, 2026-10-28

Audio now offers explicit Watch/Stop and feeds changing snapshots through the existing grouping path. The native helper registers system process-list/service-restart listeners and each process's input/output running and device-list listeners. Registrations retain exact object/address/queue/block identities. Generation checks reject old callbacks. Copied blocks use weak callback state, so late delivery cannot access a deleted owner. A source restart rebuilds registrations; failed process-list reads do not mean an empty list.

The helper emits bounded NDJSON with one pending output line and nonblocking writes. A two-second write deadline initiates cleanup; CoreAudio cleanup calls have no hard API deadline. Desktop streaming applies backpressure, a 600 KiB line bound, strict UTF-8 and no accumulated stdout history. Oversized or incomplete lines fail instead of exposing a parsed suffix. The newest one-shot or watched observation wins display selection. Failed/stopped results remain stale.

Watching owns no capture lease and can coexist with routes. Suspend and Quit stop it concurrently with existing audio/test cleanup. Resume does not restart watching or capture. Deferred cleanup is fenced to its operation, and unexpected drained exit releases process ownership while preserving the diagnostic. A live or undrained child remains owned for retry.

Real membership testing reproduced a normal-exit failure after observer A saw owned helper B appear. Diagnostic collection identified OSStatus 560947818, BadObject, for the vanished process's device-list listener. The fix permits retirement only for an exact process registration when Remove returns BadObject, a fresh successful bounded process-list read excludes its ID and a class probe also returns BadObject. System registrations, unknown membership and other errors remain failures. Retirement is reported separately from successful removal.

The revised bounded test passed in 0.86 seconds. A observed B present at sequence 2 and absent in an available snapshot with fully resolved PIDs at sequence 3. A reported 158 successful removals and four verified invalid-object retirements; B reported 162 successful removals and no retirements. Both reported resolved ownership and exited 0 without forced signals. A correctly reported that not every registration ended through successful Remove. Receipt during/after B's stop does not prove exact acquisition time. The tested helper SHA256 is `68debbdc54e4a5665e7349d3335ffdd82e48f3ad75e4372f6f5a0a0f6633b49b`.

Independent GPT 6.1 sol review closed callback-lifetime, stream bounds, deferred-cleanup, stale-display and teardown-reporting findings. Tests cover ownership failures and strict retirement predicates, unknown states, power/Quit and actual own NDJSON child transport exceeding 2.8 MiB without retained history. No original code, microphone capture, audible playback, administrator action or CoreAudio restart ran. Native desktop controls, active audio changes, real restart delivery and sustained operation remain unverified.

Next add the recovered timing stabilization and complete call qualification/local activation policy. The existing Call definitions and effective delay bounds remain unresolved in the available REA graph. Full retained-feature and acoustic parity remain incomplete.

Final full host release/sanitizer verification passed, and its rebuilt helper hash exactly matches the successful membership artifact. Desktop verification enumerated 219 tests: 218 passed and one opt-in native power-listener test was skipped. Signed ARM64/macOS12 packaging and relocated resources passed against that helper. The host log uses unchanged pass-message text and therefore shares the previous log digest; source fingerprints bind the changed implementation.

- `evidence/audio-use-watch-final-host-verify-20261028.log`, SHA256 `2f0e79ef4732e932dda97a0bcf2b54d2d036f2748c657ec94af0613c2a578a3d`.
- `evidence/audio-use-watch-retirement-desktop-verify-20261028.log`, SHA256 `a4c28cd3fd7ac005861518827f0e323b32a0c170dea6aeedb524bf9eb0c622f7`.
- `evidence/audio-use-watch-membership-runtime-20261028.log`, SHA256 `9fab283a004f5c50741443ffcce98986bdef54552e0a8c3f3d20d8c7c29a922b`.
- `evidence/audio-use-watch-membership-diagnostic-20261028.log`, SHA256 `3b8d503a9174bbe54cf35e1b09f099e722c9842468ab38ee4fff425e4f8d69b0`.
- `evidence/audio-use-watch-membership-retirement-runtime-20261028.log`, SHA256 `c01582e4b6155d68825d65eb83a3ed0ea35a7ef460f1f9349e13e7ad0f7b785d`.


## Native audio-use timing, 2026-10-28

Watch now requests `--watch-audio-use-stabilized`. Raw watch and one-shot observation remain available. REA recovered the native listener's >=200 ms first-event window, per-process tracker strict >250/>1200 ms thresholds and shared >=100 ms storage batch. The end threshold applies only when a previously nonempty direction becomes empty. Initial/new records and actual process disappearance bypass the tracker delay. `activation-findings.md` records exact constructor values, overrides, timer comparisons and evidence identities.

The production engine uses integer monotonic milliseconds and a native 20 ms timer independent of stdout backpressure. Bulk reads update only due process rows. Candidate replacement preserves its first time; reverting cancels it. Storage accumulates direction flags without restarting its batch. Recovery retains settled history and compares against prior storage publications so read failures do not turn an undisclosed transition into a readiness-only event. The deterministic same-tick ordering does not reproduce every possible ordering of the original's separate timer queues.

Restart timing clears state, permits the forced reset at 1100 ms and holds reload for 2000 ms, with repeated requests serialized. Explicit restarting/reset metadata keeps the desktop's last good view stale rather than presenting reset as observed absence. Ordinary read failures remain recoverable. Unknown per-process usage freezes published state and marks it stale; this is an explicit independent divergence from the original's default/partial failure handling. Arbitrary native exception paths remain unresolved.

Every stabilized snapshot identifies timing mode, source state, publication reason and affected directions. Independent all-idle readiness is labeled separately. Bounded latest-only transport reports coalesced publication counts and preserves direction flags where applicable. The desktop retains per-operation loss counts without falsely marking the latest full snapshot stale. Intermediate notification history is not guaranteed.

The one authorized live test connected the actual native helper to the production Swift controller and bounded streaming reader. It passed in 0.279 seconds with 40 processes, zero partial rows, running/available stabilized readiness and coalesced count zero. Explicit Stop drained exit 0, with 162 verified successful removals and no retirements or failures. No fallback signal was needed. Helper SHA256 before and after matched `4ef3192b17d221acca2dc1af33ecd697e7c248ed57bcb3b83a13e470613c9d19`. The separate Python stabilized harness remains unrun; raw membership testing was not repeated because inactive helper changes intentionally need not produce stabilized directional callbacks.

Native fake-clock tests cover boundaries, transient/reverting/changing candidates, initial/destruction cases, batching, recovery provenance, restart cycles and coalesced history. Desktop fixtures cover mode/provenance rejection, reconnects, transient failures, stale groups and production streaming. Independent GPT 6.1 sol review found no remaining blocker. Full host verification passed; full desktop verification enumerated 227 tests, with 225 passed and two opt-in skips, plus signed ARM64/macOS12 packaging and relocation.

No original code, physical audio, administrator action or actual CoreAudio restart ran. Live activity timing, real restart delivery, native controls, sustained operation and original runtime comparison remain open. Next complete Call leg definitions and local automatic-activation, blocked-app and competing-call policy. Full retained-feature and acoustic parity remain incomplete.

- `evidence/audio-use-stabilized-final-host-verify-20261028.log`, SHA256 `7dbe723eb3275c5fe746f094681d24335e7e1b747f3f12f1ac5c3c30810d4b14`.
- `evidence/audio-use-stabilized-final-desktop-verify-20261028.log`, SHA256 `a2c5ec901b73686505a14d535d7279568a608c6cb81aec65aa1092e7b948e44e`.
- `evidence/audio-use-stabilized-native-controller-20261028.log`, SHA256 `cac0062e93e9b00bc985e60529f1c627f5ea53a50b80e9425149f2cdb7515fd4`.


## Local call tracking, 2026-10-29

The continuous Watch path now feeds local call tracking with ordered microphone/speaker usage, immediate first-eligible selection, retained current-call stop timing, and visible block/unblock/switch controls. The all-apps setting defaults to true from the recovered packaged choice. Names use ECMAScript trimming and exact UTF-8 identity; blocked names use exact lowercased identity. Safari adds 300 ms to the recovered 1000 ms stop and 500 ms restored-leg classification thresholds. The start threshold is not an initial-start delay. Stop, restart, errors and power changes cancel policy timers and invalidate current identity.

Complete snapshots can establish or refresh present call state after missing history. This baseline does not reconstruct prior call transitions. Native client-map key order is retained separately from PID display order. Full-snapshot remove-before-add event adaptation remains an independent reconstruction choice because the original DeviceManager event-diff contract is unresolved. The app excludes its own process/bundle and private feed/monitor endpoints from call candidates.

This is observation-only tracking. It does not request microphone access or automatically start capture, transcription or recording. All-app mode can qualify two physical directions without the original capture-permission admission. Disabling it restricts tracked clients to the public virtual microphone/speaker. These boundaries are explicit; automatic activation parity is not established.

REA recovered Call usage identity/order, packaged local defaults, delay clamps, restart behavior and responsible-app version lookup. The helper now reads the responsible application's Contents/Info.plist, accepts CFBundleShortVersionString including an empty string, then falls back to CFBundleVersion only for an absent/invalid first value. Missing metadata yields an empty version; independent bounds failures remain null with errors. Version metadata reaches grouped clients and the initial tracked call. See activation-findings.md for evidence identities and remaining event/permission boundaries.

Full host release/sanitizer verification passed. Desktop verification enumerated 239 tests: 237 passed and two opt-in tests skipped. Signed ARM64/macOS12 packaging and relocated resources passed. Independent GPT 6.1 sol review closed native-order, atomic baseline, private/self routing, exact name identity, stopped-event invalidation and guarded-refresh issues. Metadata review found no remaining issue.

One real helper-to-production-controller test passed in 0.318 seconds against helper SHA256 `15ae2102e9d1aa65a587b46f2b15a4d95a1abd0ad9a73cb0818892d8b37fbfea`. It observed 39 process rows, no partial rows, a changed publication and zero coalesced publications. The test checks call freshness against observation completeness, refresh eligibility when complete, and invalidation on Stop. Stop exited zero with 158 successful listener removals, no retirements/failures and no fallback signal. This does not verify live call transitions, native UI controls or original event ordering. No capture, playback, permission prompt, driver change or CoreAudio restart ran.

A separate status-only Speech preflight reported authorization notDetermined and on-device recognizer support for en-US and en_IN. Its standalone execution identity does not establish packaged-app authorization. Real saved-session recognition remains untested; no permission request or speech synthesis ran. Administrator-dependent driver discovery remains deferred. Next complete original stream-event ordering and capture admission, connect local recording/ASR activation, and perform actual UI/audio comparisons. Full retained-feature and acoustic parity remain incomplete.

- Host log `evidence/call-tracking-host-verify-20261029.log`, SHA256 `10856f453e2c9fe670de5d3cdd784e196fb10c212cb44a55d2a2903db9699ad3`.
- Desktop log `evidence/desktop-verify-call-tracking.log`, SHA256 `7106af9ed48eb4cfff299df83828aaad1372b1d6fbd32193d08e3a26a019fb5f`.
- Native integration `evidence/call-tracking-native-controller-20261029.log`, SHA256 `5a73ce4da64fa2fb4de357344206c286a4c6966149811c0b90ce51a930466d08`.
- Speech preflight `evidence/saved-transcription-preflight-20261028.log`, SHA256 `008133012cec7f440010a01f6b9ce145a7b8a7c09d8e9f24a8bb99f4a263564a`.


## Call event ordering, 2026-10-29

REA now recovers the original DeviceManager stream diff. Incoming clients are stably sorted by appId.localeCompare, new identities are appended and emitted first, then missing identities are removed from the retained array in reverse order. Identity is exact app ID, device ID, direction and PID. Names, versions and helper-PID metadata are retained when that identity remains unchanged. The desktop adapter now follows this contract, replacing its previous remove-before-add and name-based comparison. A virtual microphone replacement no longer invents a call restart due solely to the wrong diff order.

Native byte-key order supplies stable ties before application-ID locale sorting. Foundation Locale.current comparison approximates JavaScript's no-options localeCompare. Original Electron resolved locale/ICU equivalence remains unverified. Source callback order is known; the original asynchronous microphone-permission wait can still change completed call-registration order. Current-state baseline recovery and unknown-read policy remain separate reconstruction boundaries.

REA also closes note-taker mode transitions, ASR readiness/event ordering and recorder attachment by ASR stream ID. Recording starts from successful ASR processing events, not directly from call detection; graph changes reattach the existing recording. macOS speaker capture is selected-application audio. The current independent route recorder mixes the full route, so automatic global-route recording was not added as a substitute. See activation-findings.md for evidence and exact scope.

Desktop ./verify passed with 242 tests enumerated, 240 passed and two opt-in skips, plus signed ARM64/macOS12 packaging and relocated resources. Independent GPT 6.1 sol review found no blocking issue in the corrected adapter. Host code is unchanged from the previous passing checkpoint. No real call, native UI, capture, playback, permission prompt or administrator operation ran. A fresh read-only own-helper inventory still reports both private driver endpoints absent with no inventory errors. Full automatic activation and acoustic parity remain incomplete.

Next implement selected-app capture as a separate production input source. The existing route Context requires feed/monitor/hardware aggregation and cannot isolate an app by changing its output UID. A call capture target must retain responsible identity and selected actual process IDs, resolve/revalidate their current CoreAudio object IDs, preserve distinct microphone/app lanes, handle their formats/clocks, and verify callback/aggregate/tap teardown before replacement. Local ASR needs a stream/session owner; the current saved-transcript UI controller is tied to explicit history selection and review. Do not treat either a global route mix or a selected saved row as an equivalent call source.

Desktop log: `evidence/desktop-verify-call-stream-diff.log`, SHA256 `0a190538a1b06707eda91bc01c7f6134d440d9796f5fa0a9d463899e48176696`.

After the full run, one test fixture was strengthened to distinguish native byte order from locale case ordering. The three focused stream-diff tests passed against that final test source. Production source and packaged binary were unchanged. Supplemental log `evidence/desktop-stream-diff-final-test.log`, SHA256 `2250ab94c6c39509c250aa35aa4d0e3a1936abab49f48129dc9028bb7794df21`.


## Selected app audio source, 2026-10-29

Audio now offers explicit recording of the currently selected application's output. It uses active process tuples from the raw observed source, with exact responsible PID/app ID, actual PID/object ID, call activation and watch generation. Unknown, pending, fallback, duplicated or ambiguous targets cannot start. The shared capture lease excludes route, microphone-test and recovery overlap. App and widget status retain a Stop action outside the Audio sheet. This is app-output-only recording; the microphone, noise processing, live ASR and automatic call recording are not included.

The new macOS 14.4+ native source creates a private nonexclusive unmuted process tap and private input aggregate. It never substitutes a global tap, changes hardware output/mute or restores future processes by bundle ID. The source checks exact target identity and tap/aggregate format before and after AudioDeviceStart and during capture. Callback intake stays disabled through startup and any permission wait. A concurrent bounded stdin reader supplies a shared cancellation token; a stale/cancelled startup cannot admit frames. Normal Stop prevents new intake and drains already admitted frames.

The callback copies into a bounded 32-block queue. Off-thread conversion supports Float32 stereo interleaved/planar sources from 8 through 192 kHz and writes 48 kHz stereo PCM16. Invalid buffers, overruns, nonfinite samples, clock discontinuity, target/format change and writer errors prevent completed status. File capacity follows RIFF's 32-bit size with converter/header reserve, not a four-hour quota. TapAutoStart remains false because the SDK says true makes AudioDeviceStart wait for first tap audio; it is not a tap-enable switch. Actual native format mapping and tap behavior remain untested.

Cleanup orders source stop, callback drain, IOProc removal, aggregate destruction and tap destruction. Attempted acquisitions count as owned even when a native operation partially fails. Uncertain cleanup retains callback context until process exit. WAV creation uses an exclusive 0600 fd under the held private directory, AudioFile callbacks and identity revalidation. The CLI bounds target parsing, commands and emitted lines, echoes immutable target/operation/source, and has bounded output delivery. Scoped cleanup joins its control reader and restores signal handlers on exceptional exits.

Desktop saves only after a matching completed result, verified native cleanup, drained successful helper exit and independent WAV/header/format/frame validation. The library destination stays pinned through preparation/import. Typed optional RecordingSource metadata records selected-app-output provenance and survives transcript replacement and recovered copies; legacy manifests/jobs still load. Target selection changes, power and Quit finalize only the owned recording. Failed saves or uncertain cleanup retain staging and cannot be satisfied by an unrelated earlier recording. No automatic recording or transcription was enabled.

Independent GPT 6.1 sol review closed partial native ownership, fd identity, startup cancellation, post-permission target checks, protocol bounds, late-result fences and recovery-provenance gaps. Synthetic lifecycle and file-conversion tests cover these boundaries. A real CLI pipe test uses an injected source and actual WAV writer, verifies successful recording plus cancellation during simulated startup, and never invokes native tap APIs. Conversion fixtures verify 44.1 kHz to 48 kHz output. These checks do not establish live capture or acoustic parity.

Local-store verification passed 20 tests. Desktop verification enumerated 255 tests: 253 passed and two opt-in tests skipped, plus ARM64/macOS12 packaging, signing, system-audio usage-description presence and relocated-resource checks. No live capture, native UI, permission prompt, playback, ASR, driver installation or CoreAudio restart ran.

Next connect a distinct microphone source and its timeline to selected-app capture, then local processing/stream ASR and the recovered ASR-session recording lifecycle. Explicit saved-session transcription remains available separately. Real permission, tap capture, sustained timing, source switching and original-versus-rebuild audio comparison are required before claiming a working full call recorder. Virtual-driver discovery and full retained-feature parity remain incomplete.

- Local store: `evidence/selected-app-local-store-verify-20261029.log`, SHA256 `d228647e2397936f6ad451a85dbc1244cd6bf83ccb68a7ba04faf01349ce303f`.
- Desktop: `evidence/desktop-verify-selected-app-capture.log`, SHA256 `b685af359b43f556a18a334afd35adf3f6984eae03d270d0cc1215a67fcf0e9d`.

Full host release and sanitizer verification passed against the final source, including native lifecycle, actual synthetic WAV conversion and real CLI/injected-source cancellation tests. Log `evidence/selected-app-host-frozen-verify-20261029.log`, SHA256 `caa8300d6d20648437487480b2f9b35de16620d617c5b7da883417ca5c87b3ec`. The rebuilt helper SHA256 is `84528fe88645349aff6ca7752a873f92aaea81636b1bba443fcfc1121293be35`; it was packaged and tested with injected sources, not used for live capture.
