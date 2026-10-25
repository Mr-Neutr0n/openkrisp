# Krisp local reconstruction

Target: `/Users/harikp/Applications/krisp.app`, confirmed by Hari.

## Requested outcome

Map installed features with REA evidence. Independently implement retained local features, exclude analytics and cloud services, verify parity, then publish to GitHub. Use GPT 6.1 sol workers. Keep original application unchanged.

Publish under repository name `openkrisp`. The independent app has no trial expiry, paid tiers, subscriptions, or usage quotas. Include independently implemented local equivalents of paid and hidden features in the parity inventory. Do not carry over commercial access gates. Operating-system permissions, actual backend availability and resource validation still apply. This does not authorize patching the installed original or bypassing proprietary component licensing. Cloud and analytics exclusions remain in force.

Read-only GitHub preflight on 2026-10-13 resolved the authenticated account to `Mr-Neutr0n`. `gh repo view Mr-Neutr0n/openkrisp` could not resolve a repository. No repository was created and nothing was uploaded. Recheck the destination before publication.

## Checklist

- [x] Establish version, hashes, package composition and integrity discrepancies.
- [ ] Map application workflows, defaults, settings, state and error behavior.
- [ ] Map native audio, virtual devices, models and offline dependencies.
- [ ] Separate retained local features from excluded cloud and analytics behavior.
- [ ] Define reproducible reference scenarios and measurable audio parity criteria.
- [ ] Implement independent local application and redistributable resources.
- [ ] Compare real user workflows and audio output against original.
- [ ] Document remaining differences and verify no analytics or cloud dependency.
- [ ] Publish verified source, build instructions and release to GitHub.

## Evidence status

Krisp 3.16.8, Electron 40.8.5 and KrispAudio 2.1.8 are identified. Initial JavaScript analysis parsed 19 scripts with partial semantic coverage. Five native ASAR companions mismatch their declared hashes. Analysis used record-and-continue; the cause is unknown. Static wrapper requests and matching native handler symbols are in feature-checklist.json. Driver and model interfaces are in native-findings.md. Runtime capture failures are in runtime-findings.md.

The referenced iscreenshoter chat was read. Its public build used independent resources and documented verification gaps. It does not establish any facts about Krisp.

No feature or audio-quality parity is established yet. Independent audio measurement, transport, local storage and virtual-driver components exist. No complete replacement application or release exists yet. Analysis evidence and original resources are private lab material, not automatically public release contents.

## Pending decisions and access

- The user chose both independent and original local model support, and requested original weights on GitHub. Model redistribution terms remain unresolved in the retained bundle evidence. Execution contracts and exact quality parity remain unverified.
- macOS Accessibility and screenshot capture now work after the user enabled the responsible host. REA captured the original settings panels; `ui-runtime-map.md` records current selections and remaining behavior gaps. No further permission response is pending.
- The REA MCP transport closed during owned Electron capture; the installed REA CLI remains usable.

Current outputs include evidence, investigation reports and independent components. No complete replacement app has been built or published. GitHub publication remains requested after full implementation and verification.

## Continuation progress

The previous goal turn made progress by saving REA evidence and identifying access blockers. This turn made further progress without changing those requirements:

- REA decoded the 997-key bundled English catalog. `catalog-feature-map.md` and its JSON companion group every key once into 27 capability groups. Catalog labels do not establish runtime reachability.
- REA decoded model and notification configuration. `model-manifest-findings.md` records eleven configured model entries, eight in the app bundle. Three matching filenames were found by path-only discovery in the app's dedicated downloaded-model folder. REA's artifact opening route rejects raw KEF files, so their contents and identity remain unverified.
- The read-only CoreAudio probe ran through REA. `driver-runtime-findings.md` and `driver-declarations.json` record actual microphone/speaker declarations after the original app starts. No stream was started or recorded.
- `verification/verify` passes deterministic WAV identity, gain, delay, duration, noise, channel reversal and loss checks. This validates the measurement tool, not original/rebuild parity.
- `app/audio-transport/verify` passes release, AddressSanitizer/UndefinedBehaviorSanitizer and ThreadSanitizer checks for independent timestamped mono/stereo transport. Cross-process mapping, HAL integration and actual audio comparisons remain missing.

Shared-memory transport and standalone HAL routing are now implemented below. App-side physical-device routing remains independent of model selection. UI mapping now uses successful REA Accessibility captures. Audio engine integration requires evidence-backed contracts for both requested model providers. No full feature or quality parity claim is supported.

## Transport and storage implementation

- `app/audio-transport/shared_transport.hpp` adds a fixed shared-memory ABI with exclusive same-user ownership, read-only peers and stale-producer silence. Separate-process release and sanitizer tests pass. This is not a verified transport into the system audio service, which may use a different account and sandbox.
- `app/audio-driver` builds an independent unsigned AudioServerPlugIn bundle. Standalone host-interface tests pass for device declarations, lifecycle, timestamps and exact mono/stereo sample routing. Hidden Feed and Monitor endpoints use internal rings with a declared 960-frame delay. A deterministic stop/restart race test passes after generation gating was added. The driver is not installed.
- `app/local-store` saves completed WAV and transcript sessions by publishing a staging directory. Six tests pass for round-trip data, export, private file modes, failed import recovery visibility, corrupt history entries and invalid input. A GPT 6.1 sol read-only review found no material issue within the documented limits. Recording capture and ASR remain missing.
- `cloud-exclusion-map.md` records twelve Sentry-related static operations and native Daily/network boundaries. Large JavaScript bundles have incomplete semantic coverage, so exact endpoints and runtime event delivery remain unresolved. The rebuild must replace local behavior independently rather than import the mixed vendor modules.
- The root `verify` script provides one entry point for all component checks. It does not install a driver or alter the original app.

The driver now uses distinct companion device UIDs and internal rings. Hidden devices do not provide access control. Real system-host acceptance, app-side physical audio routing, permissions, DSP, UI behavior and parity tests remain required.

## Desktop shell and combined verification

`app/desktop/.build/app/Lab Voice.app` builds for ARM64 macOS 12 with an ad-hoc signature. It offers local history, search, finalized WAV import, playback, supplied transcript text, export and confirmed deletion. The worker actor keeps disk operations off the main actor. It does not capture or process microphone audio and has no ASR. Its UI is provisional and has not been launched or visually tested. It does not read Krisp user data.

The root `./verify` passed all five component suites together: deterministic audio measurement, in-process and cross-process transport with sanitizers, six storage tests, production and race-instrumented driver host tests, and desktop release/bundle/signature checks. These are component and build checks, not end-to-end original parity. The race hook is absent from the production driver.

All writes stay in this experiment. No HAL driver was installed, CoreAudio was not restarted, and nothing was published to GitHub. The original app remains unchanged. Next work is physical-device routing into the companion endpoints, a reviewed installation path for real HAL testing, and runtime UI/model comparisons. Accessibility is resolved; native model contracts remain incomplete. The goal remains active.

The prior turn made concrete progress in desktop, driver routing and storage. This continuation revalidated current files, accepted the user's both-provider decision, identified the exact denied Accessibility host from OS logs, and obtained the first successful REA screenshot. Model licensing, model execution contracts, asset validation and physical-device routing are active follow-ups. No completion claim is supported.

## Additional implementation and live UI checks

`ui-runtime-map.md` records 25 settings groups from successful REA navigation. The independent desktop now includes persisted System/Light/Dark appearance and explicit model-directory selection with hash/license validation. Catalog checks do not enable inference. REA successfully opened its Settings sheet and captured an actual switch to Light; the longer screenshot sequence failed afterward, so Dark and a full roundtrip are not yet verified. A fresh run restored System through REA, and the own-app persisted preference confirmed restoration. See desktop-runtime-findings.md.

`app/noise-engine` adds pinned Xiph RNNoise v0.1.1 source and its included independent model, with retained license notices. Its normalized 48 kHz mono processor and arbitrary-callback adapter pass release/sanitizer checks, direct C scaling comparisons, partial-block continuation and seven injected allocation-failure paths. This does not establish speech-quality parity. Integration into physical routing is underway.

The installed model worker recovered and executed local addon initialization and successfully loaded an original NC model through initialization's sdkModels array. Dynamic LoadModels is not the supported NC route. Graph processing and output comparison remain pending. The latest details and Evidence IDs are in model-provider-contract.md.

`app/local-transcription` implements an independent macOS Speech adapter that requires on-device support and prohibits cloud fallback. Fourteen fixture/contract tests and its Swift 6 release build pass. No Speech permission prompt or OS recognition task ran in verification. Integration into explicit WAV import is in progress.

The audio-host backend and optional mic/speaker RNNoise routing now pass release and sanitizer tests. A teardown ownership issue found during review was fixed by retaining processor state in the callback context. Its regression test covers a paused processor, failed stop, Session destruction and delayed callback release. Real aggregate/HAL acceptance remains untested.

The installed reference changed from 3.16.8 to 3.17.9. `version-change-findings.md` records the new addon identity, a 1014-leaf catalog, the ASR 6.3 filename and unchanged driver-version metadata. Earlier evidence remains historical and must not establish current-version parity.

On-device transcription is now reachable from the desktop's selected-WAV import flow, with explicit permission-on-click, locale selection, cancellation, errors and confirmation before replacing existing text. Seven injected controller tests and the rebuilt signed bundle pass. Actual Speech recognition and its interactive flow remain unverified.

## Combined checks and prepared installation

The root `./verify` passed all nine component suites together after the routing ownership fix, ASR import integration and current ASR filename update. The retained output is private `evidence/combined-verify-current.log`. These checks include actual independent DSP and injected routing/controller tests, not real HAL or original-audio parity.

A reversible development driver package is prepared at `app/audio-driver/build/package/LabVoiceAudio-development.pkg`, SHA256 `2b25e35b44db7685f0fb9892d7febe29ed82316ac995366dd4b085e2f8fcf39a`. Root rechecked the package digest, embedded strict signature and preinstall guard. It installs only the independent driver bundle and its receipt, refuses an existing path and includes no automatic restart. User approval is pending for installation, a CoreAudio restart, live routing checks and removal if testing fails. No administrator action or real audio test has run. Desktop route controls and a bounded synthetic HAL test are being prepared independently while approval is pending.

## Desktop routing and synthetic HAL test checkpoint

The desktop packages the independent audio helper, offers explicit physical device choices and separate microphone/speaker RNNoise controls, and requests microphone access only on Start. Running state requires a matching startup handshake. Stop and app quit await helper exit. Seventeen injected desktop tests pass, including delayed-message isolation between routes. The helper and RNNoise objects now explicitly target macOS 12.

`app/audio-driver/hal-test` builds a signed read-only inventory/synthetic-test helper. Release and sanitizer callback fixtures pass. Its explicit `--run` operation is prepared but has not executed. It opens only the four exact independent virtual endpoints; it never selects physical devices. Root verification now includes its offline checks and builds audio-host before desktop packaging.

Fresh REA observation of the new desktop build failed exact-window matching because its Accessibility candidate lacked bounds. No Audio control was exercised. This is separate from the resolved Accessibility permission. Driver installation approval is still pending, and no administrator action, CoreAudio restart, actual route, or GitHub publication has occurred.

The final root `./verify` passed all ten suites together with exit 0; output is retained privately in `evidence/combined-verify-final.log`. An earlier invocation was interrupted by editing the runner while it was executing; the complete stable runner was rerun successfully.

## Live control implementation

REA static evidence in `audio-controls-findings.md` now establishes separate system and virtual mute paths, normalized scalar bounds, a quantized nonlinear virtual-volume curve and conditional driver scaling. UI defaults, persistence and active runtime mapping remain unresolved. The independent implementation adds app-route linear attenuation and mute, without changing physical device levels or claiming the original curve.

The helper accepts bounded, correlated control snapshots through an opt-in stdin channel. It publishes both paths as one lock-free atomic value, applies controls after processing, and acknowledges publication. Desktop controls track acknowledgments and discard messages from earlier routes. A lost acknowledgment makes the state unknown, so reverting to an earlier value still sends a new command. Real pipe tests exposed buffered short reads in the earlier helper client; the client now uses bounded reads that deliver short startup and acknowledgment lines promptly.

The current Mac session is locked, verified through read-only host session metadata. Interactive verification must wait for an unlocked session. This is separate from the resolved Accessibility permission and pending driver-installation approval. No attempt was made to unlock the machine or start audio.

The final combined verification passed all ten suites with exit 0 after live-control integration. Private log: `evidence/combined-verify-live-controls.log`. Desktop now has 23 tests, including Swift-encoded controls through the actual C++ parser over pipes. Routing tests cover mute/gain effects, continued DSP state while muted, startup state, late lifecycle updates and atomic two-path snapshots. The signed ARM64/macOS 12 app and relocated resources/helper checks pass. No real audio or interactive control test ran. A fresh read-only check still found the session locked and the independent driver path absent.


## Local recording implementation

The independent recorder now has explicit start, pause, resume and stop commands. It writes a private 48 kHz PCM16 stereo mix of processed microphone and speaker audio on a background thread, then imports only a validated finalized WAV into history. Saved duration comes from captured frames and excludes pauses. Failed jobs retain staging files and show their paths after restart. This mix is an independent design; original meeting-recording mixing and persistence remain unresolved. See `recording-findings.md` for REA evidence.

Recording tests exercise the actual C++ protocol and writer from Swift with synthetic samples, without opening audio devices. Review found and addressed result loss after route teardown and misleading completion after unexpected interruption. Final combined verification is pending at this checkpoint. The Mac remains locked and the independent driver is absent. The prior driver-installation question remains unanswered.


## Approved installation test

Hari approved installing the reviewed driver, restarting CoreAudio, live routing tests and removal if testing fails. Root revalidated package SHA256 and bundle signature, then installed through macOS administrator authorization. Installer reported success and the authorized CoreAudio restart returned success. Read-only HAL inventory still cannot resolve the exact feed UID. No audio test started. Logs show an attempted plug-in load, an ad-hoc signature warning and creation of a remote driver service. Registration diagnosis is in progress; the warning alone is not yet the proven cause. Private logs: `evidence/driver-install-load.log` and `evidence/driver-remote-service.log`.


## Recording verification checkpoint

The root `./verify` passed all ten suites with exit 0 after recording integration and lifecycle fixes. Private log: `evidence/combined-verify-recording.log`. The desktop has 32 passing tests. Synthetic Swift-to-C++ pipe tests validate recording commands, PCM16 finalization, active-frame duration and history import. The signed app build and relocated-resource checks pass. No actual audio was captured. The approved driver installation and CoreAudio restart succeeded, but exact endpoint lookup failed, so real routing remains untested pending registration diagnosis.

The registration probe resolves plug-in bundle ID `dev.hari.labvoice.audio` to object 49, but both DeviceList and OwnedObjects are empty. This distinguishes registered plug-in from published devices. The worker found an independent source violation: OwnedObjects ignores AudioClassID qualifiers. A focused fix and host-contract regression are in progress; this is not yet a proven cause of the runtime failure. The original reviewed package is archived privately for exact guarded rollback.

The class-filter fix passed standalone host tests and package verification. Root removed only the hash-matching initial driver, forgot its receipt, installed corrected package `3b3018c9e6994c7937199b214d93f6e56de73abb572c805450e6872d3a19f2d4` and restarted CoreAudio. Exact endpoint inventory still fails. Thus the confirmed class-filter bug was not sufficient to resolve discovery. No audio began. A bounded property-call trace is the next diagnostic; no speculative discovery change is planned.

A separate discovery-only diagnostic package is prepared with bounded512-entry logs and no audio callback logging. SHA256 `16d8c98681473a7387e4fa4016b005401fefeefefa5bec7a2251f8b54cf70e8c`, signed tree `5ca286e9483c605f82ecdfabeb830fd640dd5cd534eef3f390a4bef0b98dea95`. Its guarded replacement command is waiting on the macOS administrator prompt. Normal production builds exclude the trace. The corrected non-trace package remains installed until that authorization succeeds.

Fresh unlocked-session REA observation found a real existing-directory error in recording storage. The desktop worker fixed directory reuse after reproducing Cocoa error516, added a regression and passed33desktoptests plus packaging. REA then confirmed the error is gone and a Dark/System roundtrip works. Audio remained stopped; no live recording or microphone capture occurred.


## User away: defer administrator actions

Hari is leaving and expects to return around11. He asked to keep password prompts until the end. Continue source work and offline checks, but do not launch more administrator prompts, system changes, audio restarts or live audio tests while he is away. Do not schedule a restart based only on elapsed time.

Root terminated the still-pending owned osascriptPID80103 as requested. The user then reported approving its prompt. Fresh inspection shows the command had installed the diagnostic bundle before termination: installed signed-treeSHA256 `5ca286e9483c605f82ecdfabeb830fd640dd5cd534eef3f390a4bef0b98dea95`, matching the trace manifest. CoreAudio remainsPID94316, started10:27:21 before this replacement. The final restart did not run. No installer/osascript remains. Thus diagnostic files are installed but their runtime loading is unverified; current discovery logs contain standalone host tests only, not a real service trace. Exact UID inventory still fails. The current rollback guard is `evidence/remove-trace-driver.py`. Resume the batched restart/trace/test or guarded removal only when appropriate under the user's return instruction.


## Offline widget checkpoint

The independent floating widget is implemented with persisted visibility, explicit Show/Hide commands, shared audio and recording state, microphone/speaker mute controls, acknowledgment status and Stop audio. Closing hides it without stopping the route or discarding a pending recording. Its independent default is hidden; the original factory default is unknown. Desktop verification passed 36 tests and signed-bundle checks. No widget window was launched while the user was away. Original widget behavior, talk-time, captions and visual parity remain open.

Driver diagnostic files remain installed but await the deferred CoreAudio restart. No new administrator action, permission request or audio test ran during this offline checkpoint.


## Reviewed parity ledger

`feature-parity-ledger.json` and `.md` now assign all 1,014 current catalog leaves exactly once across 32 workflow families. Root checked exact key coverage and all 26 implementation source fingerprints. The ledger retains 22 local families, leaves 6 local/service contracts unresolved, and excludes 4 service families. These are scope assignments, not completion percentages. It corrects inherited substring grouping errors and explicitly keeps local paid/hidden capabilities in scope without their billing gates. Original limits are evidence to classify, not automatic independent usage quotas.


## Temporary microphone test work

The next retained feature is a temporary microphone noise-suppression comparison. `noise-test-findings.md` records current REA labels for explicit start, at least five seconds, original/processed playback, repeat, quit confirmation and local unsaved policy. Source selection, DSP placement and maximum duration remain unknown. No NC-test-specific active-call restriction was found.

Independent implementation is in progress. A dedicated helper will capture the selected physical microphone without requiring the virtual driver, then process that same clip with RNNoise. The initial implementation requires the app route to be stopped and uses a bounded60-second buffer. These are independent constraints, not observed original behavior or paid quotas. The desktop will request capture only after the user presses Start. Temporary files stay out of history and are removed after confirmed helper exit. Offline tests use synthetic samples; actual audio, prompts and native UI execution remain deferred while Hari is away.


## Temporary microphone comparison checkpoint

The independent temporary test is implemented. Explicit Start captures the selected physical microphone's first channel at 48 kHz without the virtual driver. The same captured sample feeds Original and RNNoise-processed WAVs, with explicit playback, same-position switching, replay and retry. The five-second minimum follows observed labels; the sixty-second buffer bound and requirement to stop the app route are independent constraints. Known adapter buffering is aligned; RNNoise algorithmic delay and original audio parity remain unmeasured.

Shared capture ownership prevents concurrent route/test starts across windows. Cancellation covers permission waits, preparation, capture and processing. Failed or uncertain cleanup retains the owned job and exposes its path; the app does not report removal until cleanup succeeds. Temporary comparisons stay out of history.

Root `./verify` passed all ten component suites with exit 0. The desktop has 46 passing tests, including synthetic C++ helper integration and failed-cleanup retry. Release and sanitizer checks passed, as did signed ARM64/macOS 12 bundle and relocated-resource checks. Independent source review found no remaining material issue. Private log: `evidence/combined-verify-microphone-test.log`. No physical microphone, audible playback, new native UI, administrator prompt or CoreAudio restart ran. Runtime behavior and full parity remain unverified.

Read-only recheck confirms the diagnostic driver tree is unchanged and CoreAudio remains PID 94316, started before that installation. Its load test is still deferred under Hari's request.


## Paused by user

Hari requested stopping work, pushing a private `openkrisp` repository and preserving checkpoints. The goal is paused and workers stopped. Storage-location work produced findings and a plan only, with no source changes or new tests. `CHECKPOINT.md` records current implementation, verification, installed driver state, pending work and exact resume instructions. No new administrator or audio actions were performed.


## Resumed 2026-10-15

Hari resumed autonomous work and reconfirmed GPT 6.1 sol workers. The private checkpoint remains the last completed baseline. Local library folder selection is being implemented, with strict existing-folder admission, a persisted selection, operation-bound destinations and no implicit data migration. Review is checking cross-window dialogs, cancellation and unavailable-folder recovery.

A fresh read-only discovery probe still resolves the independent plug-in but returns no devices for its four exact UIDs. CoreAudio still has PID 94316 from before diagnostic installation. No restart, administrator prompt or live audio was attempted while Hari is away.


## Library-location verification checkpoint

Implemented persisted existing-folder selection and reopen without data migration or fallback. Shared admission covers active library work, transcription, capture and recording; stale dialogs/results carry revision checks. Recording preparation validates and retains the admitted destination store through final save, rejects same-path replacement and retains failed staging. Missing or invalid preferences remain recoverable through the chooser.

The root `./verify` passed all ten component suites with exit 0, including 54 desktop and 12 local-store tests. Eight focused desktop location tests cover real temporary library imports, restart persistence, missing-folder recovery, stale dialog/results, cancelled authorization and replaced recording destinations. Both independent reviews accepted the changes. Private log: `evidence/combined-verify-library-location.log`. Native picker interaction, real audio routing and original parity remain unverified. No administrator or live audio action ran.


## Local diagnostics checkpoint, 2026-10-15

Implemented private local report export with bounded typed current-run events/status, optional occurrence date/system metadata and an explicitly selected PCM16 mono/stereo WAV sample. Existing destinations and replaced output directories fail without overwriting user files; cleanup tracks owned files. No cloud upload or automatic capture exists.

Desktop `./verify` passed 68 tests plus signed ARM64/macOS 12 packaging and relocated-resource checks. Other nine components remain unchanged from the preceding combined verification. Private log `evidence/desktop-verify-diagnostics.log`, SHA256 `fb545d92a705ccaf2b38318016fe61b8f46714fd534bd9402a31da8d2aba090b`. REA opened Settings/Diagnostics and observed the native form/current status with audio stopped (evidence `ev_c6e9c71877d065d8aee3a404e566c8bc43611817c26e89c4e7011e48d7899d5b`). Save/sample picker workflows, historical log parity and original report schema remain unverified. No audio or administrator action ran.


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


## Persistent HVC worker checkpoint, 2026-10-25

The private worker/probe now admits a separate fixed `outbound-hvc-lfb` role. The ordinary outbound/inbound identities and defaults are unchanged. REA `ev_f0e42f64a009b52eb8aed7c7e30177101eb560c64ade103e2096a899bb788753` passed: fresh active and bypass workers each produced 100 frames and 48000 finite samples, matching retained direct-HVC outputs byte for byte, with unchanged pins and verified owned cleanup. The historical failed raw-input bypass assertion remains separate. See `background-voice-persistent-findings.md`.

The native findings close the static NC descriptor construction join and identify packaged RD defaults and the alternate energy/statistics path. Product BVC remains unavailable. Next add explicit microphone selection with exact startup role checks and preserve speaker-only inbound admission. Reject HVC with AEC until a separate composition gate passes. Headset policy, target-speaker preservation, nearby-voice rejection, real-time deadlines and physical audio remain open. No vendor assets are included. The JSON ledger records all 165 current source hashes.


## Experimental HVC route integration, 2026-10-25

Host and desktop now implement explicit installed HVC-lfb microphone selection, with fixed model identity and exact startup role checks. Ordinary NC stays the default. Speakers remain inbound-only. HVC with AEC is rejected before a worker or route starts. Focused own-fixture tests and independent review pass; full verification results are recorded in the latest CHECKPOINT section when complete. No physical audio or new original-model execution was used for this integration.

The next bounded control feature is a persistent local headset confirmation list. Existing hardware inventory exposes stable device UIDs and display names. Use exact UID confirmation, with a stored display name, instead of guessing headset type from a name. Confirmation must not start capture. Remove/reset must invalidate admission and stay locked while a route is engaged; reset should restore ordinary mode and clear only confirmations. Device changes must reject stale validation. This is an independent manual policy. The retained original manual allowlist stores supplied names; this proposal uses exact device UIDs with names for display. Original automatic matching fields/list contents and effective defaults are still unresolved.


## Manual headset confirmation and compatibility evidence, 2026-10-25

The independent desktop now persists explicit headset confirmations by exact device UID with names for display. Experimental HVC validation and Start require confirmation of the selected input. Remove and reset invalidate admission; reset restores ordinary microphone mode and clears only confirmations. Policy controls cannot mutate during capture, recording, loading or quit. Confirmation does not request permission or start audio. A reproduced permission-wait race is fixed by requiring unchanged provider/AEC admission revisions, including when a device or mode changes away and back. Full desktop verification passes 148 tests, signing and relocated-resource checks. Native UI observation failed because stable process launch identity was unavailable; visual acceptance remains unverified.

New static REA captures recover original matching fields, case handling and precedence, plus an observed cached list with 152 allowed and 701 blocked entries. See `background-voice-controls-findings.md` for exact IDs, cache schema and limitations. Original manual matching uses lowercased name substrings and exact-name removal; this checkpoint's exact-UID policy differs and does not establish original compatibility parity. No vendor list is included.

Next recover the original CoreAudio-to-interfaceName/manufacturer/modelId mapping, then implement and compare the original local compatibility precedence with own fixtures and the observed offline list schema. Preserve account/cloud exclusion, report unknown or stale list state, and keep runtime device-policy and acoustic acceptance separate. Physical driver discovery and routing remain deferred administrator-dependent work.


## Native device metadata and local matcher, 2026-10-25

The own helper now reports interface_name, manufacturer and model_id using the recovered global CoreAudio name/manufacturer/model UID selectors. Optional reads preserve the device with empty strings and per-device metadata_read_errors. Swift preserves missing versus empty fields and does not substitute display names. The standalone local engine implements mode/rate gates, local blocked-before-allowed-before-manual precedence, branch-sensitive malformed values, literal UTF-16 matching and exact manual-name removal. Failed bounded cache loads preserve previous lists.

Six accepted static REA captures bind the native field chain. Later device grouping remains unresolved. A separate string-conversion capture retains complete disassembly but failed cleanup acceptance. The attempted extracted-method replay returned no dynamic outcomes: its first wrapper had a syntax error, and the corrected call failed REA lifecycle cleanup. The 35 local cases in the own 43-case fixture are statically expected results, not observed JavaScript executions; eight account/team cases are excluded. See `background-voice-controls-findings.md` and the latest CHECKPOINT section for exact paths and verification.

Next connect offline compatibility-list selection and the recovered local policy to automatic NC/HVC model choice. Carry original manual interface-name matching and blocked-list precedence through the actual controller flow; do not confuse the existing interim UID confirmation list with exact original manual behavior. Invalidate admission on device, mode, list and manual-policy changes, including in-flight validation and permission waits. Keep ordinary noise cancellation available when automatic compatibility is unknown or unavailable, with a clear status. Account/team restrictions, telemetry and network list refresh remain excluded. Original runtime policy comparison, visual controls, physical audio and acoustic quality remain open.
