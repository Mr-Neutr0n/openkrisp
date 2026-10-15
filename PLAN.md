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
