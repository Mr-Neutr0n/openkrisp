# Lab Voice desktop

This original provisional SwiftUI and AppKit app uses the sibling LocalStore, ModelCatalog, and LocalTranscription packages, plus the audio-host helper. The bundled desktop distribution requires macOS 13.5 or later on ARM64. Owned audio components retain their macOS 12 source targets. It ships the independent RNNoise helper and its license notice, plus the exact signed official Node runtime and its complete license. It ships no proprietary vendor binaries or model assets, and no cloud services. Its optional installed-provider bridge uses exact caller-selected local files. Model validation reads only caller-selected assets for hashing. Session history does not read Krisp user data.

Use the root `./verify` for the complete dependency order. For component work, build the noise-engine and audio-host components first. Build the own native adapter with `../native-model-probe/build_probe`, the accent adapter with `../accent-engine/build_probe`, and the own AEC worker with `../native-model-probe/build_aec_worker` before packaging. `../node-runtime/prepare` supplies the verified runtime resources. Run `./verify` to compile the release executable, create `.build/app/Lab Voice.app`, apply an ad-hoc signature, and verify bundle metadata, architecture, minimum OS, signature, and metadata resource lookup from a relocated signed copy. `./build` only builds and packages the app. Neither script installs or opens its UI. Verification runs the executable with `--verify-model-catalog`, which exits before scenes or session storage open, and runs the packaged helper with read-only `--list`. It also runs injected controller tests without OS permission requests or live audio. Build outputs stay under ignored `.build/`. Swift and the macOS SDK must be available. The app is not notarized or sandboxed.

The window has local history, title and transcript search, finalized WAV import, recording playback, transcript text export, and a confirmation before selected-session deletion. Imports derive duration from AVAudioFile frame count and sample rate. Transcript text can be entered manually or generated through the explicit Transcribe on this Mac action for a user-selected WAV. The result stays editable and spans the imported recording when saved. Playback uses AVAudioPlayer. The Audio button opens physical device selection and independent microphone/speaker noise reduction options. Status reflects the helper lifecycle and reports running only after a matching startup handshake.

The default library is `~/Library/Application Support/Lab Voice/sessions`. WAV import copies the source into that library. It does not remove or change the source. The WAV must already be finalized and must not change during import. Transcript export requires a new filename because LocalStore does not overwrite existing files. Deletion permanently removes only the selected saved session after user confirmation. The app stops playback before deletion and when selection changes.

A shared model and worker serialize operations across app windows. A worker actor runs inventory, import, export, deletion, and player setup away from the main actor. The UI reports loading, operation errors, missing transcript text, unreadable manifests, and incomplete imports. It retains incomplete imports for recovery through the store. This version has no recovery UI. Search filters loaded history, including transcript text and speaker names.

Verification has passed release builds and bundle checks on this Mac. Earlier REA runtime checks established initial library rendering, Settings reachability, actual Light rendering, persisted Light, and restoration to System. [desktop-runtime-findings.md](../../desktop-runtime-findings.md) retains that evidence and its failed/incomplete steps. The later appearance layout correction and the new transcription/Audio UI have not been visually tested. Interactive import, playback, export, deletion, Dark rendering, and directory-selection flows remain unverified. The Appearance labels use the retained original App settings evidence. The rest of this design remains provisional. Recording-to-library capture, actual HAL audio validation, automatic store refresh, progress within large imports, real OS transcription validation, and UI parity remain unfinished.

## Settings

The main window has a Settings button. The app also provides the standard macOS Settings or Preferences menu entry. App settings expose System, Light, and Dark. `@AppStorage` persists only the Lab Voice `appearance` preference, and `preferredColorScheme` applies the choice to the library window and settings UI. System follows this Mac's appearance. These are the observed original labels from `ui-runtime-map`, not a claim about the original factory default. The independent app starts with System when it has no saved choice. Show widget, library location and Launch at login are described below. Other original settings remain incomplete.

The Models tab lets the user choose an installed app bundle and a dedicated downloaded-model directory, or an independent model root and a manifest inside that root. Nothing scans automatically. Validation runs on a worker actor. Results list model ID, feature, source location, missing or unreadable status, hash match or mismatch, observed SHA256, and license metadata. Assets with no authenticated reference digest remain unverified. Catalogue checks do not activate inference. The reviewed microphone/speaker NC, outbound accent and echo-cancellation providers can be separately selected and validated in Audio. Other catalog models remain unavailable. No vendor model is decoded or copied by catalogue validation. Selected paths and reports remain in memory for the current app session.

`build` packages metadata resources, the audio helper, and its RNNoise license notice under `Contents/Resources`. The helper is individually ad-hoc signed before the outer bundle is signed. The catalog resolves that signed app location and falls back to SwiftPM resources outside packaged apps. `verify` copies the app to a temporary location and runs its headless resource check there. This checks packaging independently of the absolute SwiftPM build path. ModelCatalog's five fixture tests and release build pass after this resource lookup change. The earlier appearance/render evidence above remains valid for that build. New Audio/ASR UI and selected-directory flows still require runtime checks.


## Selected-WAV transcription

The import sheet lists readable language names from the OS supported-locale set. A language must be selected before transcription starts. The selected locale identifier is passed unchanged to the existing LocalTranscription package. That package checks the same locale and on-device capability, sets `requiresOnDeviceRecognition`, and permits no server or language fallback.

Only the explicit Transcribe on this Mac action requests Speech authorization. If transcript text is already present, a Transcribe and replace confirmation is required first. Current text remains until a nonempty recognition result succeeds. A cancelled, failed, unsupported, timed-out, or empty result does not replace it. The text editor is disabled during transcription so new edits cannot be lost to an in-flight result.

The sheet shows progress, errors, and a cancellation action. Changing the selected WAV or closing the sheet cancels the operation. A token prevents a cancelled or older file's late completion from changing the current result. Import is blocked while transcription is pending. The result fills the existing text editor; the user reviews it and then uses normal Import. Recognition segment timings are not persisted through this edited-text import path.

The bundle contains `NSSpeechRecognitionUsageDescription` for selected-WAV recognition. This selected-file flow requests no microphone access. The separate Audio flow now adds a microphone usage description and requests that access only on Start. LocalTranscription remains unchanged.

Verification runs seven injected controller tests for permission timing, permission denial, exact file/locale forwarding, cancellation before start and during the permission wait, stale file results, unsupported on-device recognition, and empty results. It then checks the release ARM64 bundle, deployment target, resources, relocated resource lookup, usage-description metadata, and ad-hoc signature. Tests request no OS authorization and start no recognizer. Real OS recognition, supported-language coverage, permission prompts, and visual/interactive sheet behavior remain unverified.


## Live Audio view

Audio reads device inventory by running the bundled helper with `--list`. It requires explicit microphone and speaker choices by UID and never selects a fallback device. Missing companion endpoints, non-48 kHz devices, invalid channels, permission denial, helper startup errors, and stopped devices prevent a running state. Hardware sample rates are not changed. The helper revalidates actual formats and aggregate properties at startup.

Optional switches enable microphone and speaker processing. Each direction independently selects RNNoise or its reviewed installed NC provider. RNNoise remains the default. They are requested options while stopped; the displayed active settings come from the helper's actual `route_started` JSON event. Plain stdout text does not enable the UI. The event must match both chosen UIDs and processing flags, and the child must still be running. A mismatched or missing handshake triggers Stop. A startup token prevents an older child's delayed callback or stop task from affecting a new route.

The main bundle has `NSMicrophoneUsageDescription`. Only Start asks for microphone authorization. Device refresh and opening Audio request none. On authorization, the app launches `Contents/Resources/helper/audio-host --route` with an argument array, with no shell. Its flushed handshake occurs only after the aggregate and IO callbacks start successfully. The helper contains the RNNoise model. Installed NC choices require the separate exact-identity admission described below. Outbound accent has its separate default-off provider. Other catalog entries do not enable arbitrary inference.

Stop sends SIGTERM and awaits child exit and output closure. The UI stays in Stopping if that wait fails, reports the error, and permits a retry. Normal application termination waits for the same cleanup and declines quitting if the child has not exited. The helper also detects parent process loss and tears down its route. Closing the Audio sheet leaves an explicitly started route active, with its state visible in the main window.

Owned helper/RNNoise binaries retain macOS 12 targets. The signed bundled Node runtime and desktop distribution require macOS 13.5. Verification checks its architecture, `LC_BUILD_VERSION`, individual signature, the outer bundle's deep signature, the unchanged RNNoise COPYING notice at `Contents/Resources/helper/notices/RNNoise-COPYING`, and read-only inventory from a relocated signed copy. Packaging rejects a missing or stale helper binary.

Fourteen injected route-controller tests check explicit choices, no permission on inventory, actual matching readiness, rejection of readiness from an exited child, independent option arguments, permission denial/cancellation, startup failure/timeout, missing driver and mismatched rates, SIGTERM plus awaited exit, failed-stop retry, and the stale mismatch task race. These are controller/process simulations, not real HAL audio evidence. The new Audio view has not been visually tested. Driver installation, CoreAudio restart, microphone attribution to the helper, actual routes, long-running DSP/drift/latency, normal app quit, and rollback remain pending an authorized installed test. No live route or microphone permission prompt runs in verification.

## Installed microphone and speaker providers

Audio offers independent provider selectors for enabled microphone and speaker reduction. Choose the installed Krisp app, then use Validate selected installed providers. The bundled official Node runtime is selected by default. The separately reviewed external Homebrew runtime remains an explicit option; arbitrary Node executables are rejected. Only requested installed directions are read and hashed. Microphone uses outbound `c8.f.m.528d1f-1.0.1_1.0.kef`; speaker uses inbound `c8.w.m.d15e29_1.0.kef`. Their fixed role-specific SHA256 identities, the addon identity, the reviewed Node identity and packaged worker identities must match. A failure blocks Start for the requested configuration. No RNNoise fallback occurs. The app keeps these choices in memory for the current session.

Changing the selected app, Node executable or requested installed directions invalidates admission. Both requested directions must validate before either new admission is published. Start captures immutable per-direction settings. The helper's startup acknowledgment must match both selected provider names and every installed direction's model, addon, adapter and Node digest, callback maximum and derived transport delay. Wrong, missing or unexpected lane metadata stops the helper. Single-worker startup allows 40 seconds; sequential dual-worker startup allows 70 seconds. These waits do not change microphone permission timing, which remains explicit Start only.

Each installed direction has its own model state and isolated worker. Installed speaker processing averages each stereo pair to mono and duplicates the processed mono into both playback channels. It collapses the stereo image. RNNoise speaker processing retains independent left/right state. The installed paths add a bounded transport delay derived from the validated aggregate callback maximum; startup acknowledgment reports the actual sample delay. Physical audio, speech quality, full tail preservation and live scheduling remain unverified.

Packaging places this app's `native-probe.node`, `audio_worker.cjs`, `worker_session.cjs`, `worker_protocol.cjs` and `runtime-manifest.json` under `Contents/Resources/helper/installed-worker`. The adapter is signed before its digest enters the manifest. The exact official Node binary, complete license and provenance are packaged separately under `Contents/Resources/helper/node-runtime`, preserving its upstream Developer ID signature. The installed Krisp addon, Electron libraries and model weights are not copied into the app. Worker startup rechecks identities and requires the recorded network-denied launch profile. File digest checks are not an atomic binding of every subsequent library load.

Desktop `./verify` passes 109 tests, including synthetic role-specific admission, speaker-only and dual selections, all-or-nothing validation, stale validation rejection, independent lane arguments and acknowledgments, permission cancellation and late startup replies. It also passes signed packaging and relocated resource checks. No installed vendor assets, OS permission prompt or live audio route run in this verification. New dual-provider controls still require interactive visual verification.

## App-route volume and mute

Microphone and speaker each have a mute switch and a 0–100% slider. Independent defaults are unmuted and 100%. Values apply as linear attenuation after this app's DSP. They do not write hardware or HAL volume properties. Mute silences routed output while microphone capture and processing continue. Stop audio ends capture.

The Audio sheet has a bounded 600-point height, a scrollable body, and a fixed Start/Stop footer. Its layout still requires visual verification.

Controls can change while stopped or running. Startup and stopping lock them. Startup sends a complete initial tuple and validates the helper's echoed tuple before displaying Running. Live commands use bounded nonblocking stdin writes, an operation UUID, and a strictly increasing sequence. Gains are canonical Float32 values before serialization. Only one command is outstanding; slider movement retains the latest desired tuple. Accepted acknowledgments update the displayed confirmed tuple and send any newer desired tuple. Acceptance means publication for upcoming callbacks, not measured playback.

Rejected commands leave the last accepted tuple visible with an error. Missing acknowledgments make the published state unknown, since the helper may have applied the command. Retry or a new choice sends a newer full tuple. Old-operation and old-sequence responses cannot alter a later route. Stop closes stdin and awaits termination. The stdout reader uses bounded POSIX reads so a short readiness or acknowledgment line arrives without waiting for a full buffer.

The earlier live-controls checkpoint had 23 tests: 13 route controller tests, seven transcription controller tests, and three actual pipe-child tests. Build audio-host with its `./verify` first; the wire test uses its test-only `control-wire-fixture`. A Swift-encoded 37% microphone gain and mute tuple passes through the actual C++ protocol and atomic control publication, and the decoded acknowledgment must match its canonical Float32 values exactly. New cases cover Float32 startup values, startup locking, acknowledgment coalescing, rejection, write failure, lost acknowledgment followed by a return to the previous value, stale responses after replacement, real NDJSON pipe roundtrip, bounded writes, and closed-stdin errors without SIGPIPE. Fixture children only exchange JSON and never open audio devices. Live control audibility, original transfer-curve parity, hardware-level synchronization, and visual UI interaction remain unverified.

## Explicit local session recording

Start recording is available only while the selected audio route is running. Nothing starts recording automatically. Separate controls start, pause, resume, and stop a recording. The indicator distinguishes recording, paused, finalizing, and unknown states. No wall-clock timer is used to calculate a saved duration.

This independent recording contains a 48 kHz PCM16 stereo mix of processed route microphone and speaker audio. Each source is scaled to 50% before mixing. Route gain and mute affect the recorded audio. Paused samples are omitted. This behavior is not evidence of the original app's recording graph, meeting semantics, or feature parity. Recording adds no transcription or cloud upload.

The app creates a unique private job directory under `Application Support/Lab Voice/recording-staging`, with mode 0700 and an exclusive 0600 job manifest. The helper creates the WAV exclusively with mode 0600. No user-selected source file is overwritten. NDJSON recording commands carry the current route operation ID, a separate monotonic request sequence, and a recording UUID. Start becomes Recording only after an accepted start acknowledgment. Pause and resume also require accepted acknowledgments. An accepted stop acknowledges the request; it does not mean the file is finalized.

Only a matching completed result can enter history. The storage actor verifies the exact staging path, a plain regular WAV with mode 0600, finalized RIFF length, PCM16 encoding, 48 kHz stereo layout, and AVAudioFile frame count against the helper's finalized frame count. It uses those frames for the saved duration. LocalStore publishes the imported session atomically with an empty transcript. Existing sessions and supplied transcripts remain unchanged. Only after a successful save does staging cleanup run. A cleanup failure leaves a visible duplicate-file warning.

Stop audio and normal Quit request recording finalization, keep processing recording events while the route is Stopping, and await a pending import before finishing cleanup. A rejected, timed-out, failed, or unexpectedly interrupted recording is never reported as saved. Its private staging metadata and available audio remain. The main window and Audio sheet show retained staging paths after restart. These folders require inspection; a partial WAV may be invalid. No automatic recovery, import, or deletion occurs.

The recording UI correction checkpoint contained 33 tests. Recording tests use injected command streams and actual pipe children that write synthetic WAV files. They cover start gating, acknowledgment correlation, pause/resume states, missing/rejected acknowledgments, unexpected exit, restart visibility, old suspended failure persistence versus a new recording, completion during the actual route Stop path, finalized-frame duration, wrong/incomplete WAV rejection, and preservation of existing transcript history. An actual C++ RecordingProtocol and writer fixture verifies Swift start/pause/resume/stop commands, exclusive WAV creation, and active-frame-only duration without CoreAudio. Build audio-host with `./verify` before desktop verification to provide both wire fixtures. No real recording, OS prompt, live route, or visual UI test runs in verification. Long recordings, disk exhaustion during production capture, OS interruption, actual mixer quality, and interactive Quit remain runtime validation gaps.


## Unlocked UI check and storage correction

After the Mac was unlocked, REA verified the current library and Audio sheet. The Audio header, physical-device selectors, independent processing controls, app-route mute/volume rows, and fixed Start footer were visible. Audio remained stopped. The recording block was present in the Accessibility tree. REA's scrollbar increment action failed with AXError -25206, and a scrollbar button press did not change the screenshot. The lower recording layout therefore remains visually unverified.

REA exposed a real retained-recording inspection failure when `Application Support/Lab Voice` already existed. RecordingStorage now creates that directory only when absent, then validates and reuses it. A temporary-directory regression covers reuse and multiple recording jobs. The focused desktop `./verify` passed all 33 tests, signed-bundle checks, relocated resources, and read-only inventory after the fix.

The Settings Dark selection and restoration to System both completed in REA evidence `ev_4133d193a79f7f04c156017a0fb5c7058a921b49ed7c579a995df0bc150f2ce1`. Screenshots show each selected control. A fresh launch retained System in `ev_0b8d1e6627162ac3d43809af4ab1e5763646874047663774a6ead9d5d0fc511d`. The corrected Audio capture is `ev_9b6abef41a31523ea714fe5f759d3393a5e8e64d84d6a9d9d907956de2870e08`. Both owned Lab Voice processes were verified by exact executable path, sent SIGTERM, and confirmed absent. No audio Start, recording Start, model selection, user WAV import, or original app action ran during these checks.

## Independent floating widget

Settings exposes Show widget. The Widget menu also provides explicit Show widget and Hide widget commands. This preference is saved only in Lab Voice's `showWidget` key. The independent default is false. Original retained evidence shows a current On selection, not a known factory default. Once enabled, the panel reappears on normal app launch. Showing it starts no audio route or recording.

A single reusable macOS 12 NSPanel floats above ordinary windows. It reads the same AudioRouteController and RecordingController as the library and Audio sheet. It shows real audio/recording states, app-route microphone and speaker mute choices, acknowledgment pending/error/unknown status, and Stop audio. Pending or rejected updates show the last accepted mute tuple when known. Acceptance still means publication for upcoming callbacks, not audible proof. Mute controls are locked during loading/startup/stopping, while status and errors remain readable.

The panel contains no meeting title, duration, talk-time percentage, captions, or speaking assistant. Original widget geometry, automatic meeting triggers, close-for-now semantics, and processing behavior remain unknown. Closing the independent panel persists hidden state and reuses the same panel on the next Show action. It does not stop the route, clear a pending recording, or alter capture permissions. Stop audio uses the existing finalization and cleanup path.

The floating-widget checkpoint `./verify` passed 36 tests, the ARM64/macOS 12 release build, ad-hoc signatures, relocated resources and read-only inventory. Three injected lifecycle tests check the independent hidden default, single panel allocation and close/show reuse, persisted visibility, shared controller identity, no audio/permission/recording side effects, and retention of a pending recording when closed. Tests use fixture panels and isolated preferences. Native panel rendering, focus behavior, multiple Spaces, and interactive widget controls remain unverified; no UI app or native panel is launched during verification.

## Temporary microphone comparison

Audio provides Test microphone for the selected physical input. Start test is explicit and is the only action that requests microphone authorization. The current app route must be stopped and the app-route microphone must be unmuted. This route-stopped policy is an independent capture-ownership constraint; retained original evidence does not establish that restriction. A main-actor admission lease protects route and test startup across every window, including permission waits and uncertain cleanup. It is released only after safe cleanup. Shared microphone-permission and signed-helper construction paths serve both flows.

The test selects the exact microphone UID, requires 48 kHz, captures its first channel, and changes no hardware rate/default/volume property. It requires 240,000 captured frames before Stop and limits capture to 2,880,000 frames. Those are five and sixty seconds at 48 kHz. Displayed capture time comes from helper frame progress, never a wall-clock timer. Stop waits for capture teardown and independent RNNoise processing. Cancel during capture or processing requires confirmation. Cancellation intent suppresses late completion and playback. Closing the modal also cancels the test. Normal Quit checks this test even when the audio route is stopped and preserves the existing recording finalization path.

Each test has an exclusive mode-0700 folder in `Application Support/Lab Voice/microphone-tests` and a mode-0600 manifest. The helper creates `original.wav` and `processed.wav` exclusively with mode 0600. A completed result is admitted only after helper exit with status zero, matching startup identity, valid 48 kHz mono PCM16 files, finalized RIFF lengths, equal frame counts within the test bounds, and exact owned paths. The current contract reports known 480-frame adapter buffering alignment. This does not establish total algorithmic delay, original DSP order, or Krisp processing quality parity.

The comparison labels are Original and RNNoise processed. Play is explicit. Switching transfers the current player position to the other file; Replay returns to zero. Playback setup/file reads run on a worker actor. The files never enter LocalStore history or transcription. Retry, Done, confirmed Cancel and normal Quit stop playback, await helper exit, and then remove only that operation's owned directory. If exit or removal cannot be confirmed, the job and admission lease remain, an error/path is shown, and cleanup can be retried. A preparation failure after directory creation also transfers the partial job to this cleanup path. Other owners' folders are never removed. Crash leftovers are listed after restart without automatic deletion.

Synthetic tests cover entry constraints, cancelled permission waits, stale operation messages, minimum capture gating, completion-before-exit rejection, cancellation during processing, uncertain writer retention, suspended preparation/removal failure including partial-preparation errors, interleaved window admission, startup mismatch cancellation, strict pair validation, owner-only cleanup and restart leftovers. Injected audio players test actual A/B position transfer and replay without calling AVAudioPlayer.play. The actual C++ production test loop, synthetic backend, RNNoise and WAV export run over pipes for completion and cancellation. Tests use private temporary disk files; they capture no physical audio, request no OS authorization, and launch no UI. Device-format coverage, live capture/playback, visible modal behavior, real OS permission attribution and original test parity remain unverified.

The temporary microphone-test checkpoint `./verify` passed all 46 desktop tests, the ARM64/macOS 12 release build, ad-hoc signatures, relocated resource lookup and read-only helper inventory. The retained local log is `.build/microphone-test-verify.log`.

## Local library folder

Settings lets the user choose an existing folder for transcripts and recordings. The app validates that folder before saving the preference, then reopens its history. Choosing a folder does not move or delete existing sessions. The saved path persists across restart. A missing, inaccessible, or invalid saved location shows an error and never falls back to the default folder. The user can choose another valid folder to recover.

Folder changes wait for active imports, transcription, recording, audio routes and microphone tests. Open import, export and deletion dialogs retain their library revision and reject actions after a folder change. Late asynchronous history results cannot replace the current folder's history. Cancelling a transcription permission wait releases only that operation's lease; a late grant cannot start recognition.

A recording validates its destination before capture starts and retains the same LocalStore until completion. Removing or replacing that directory causes save to fail and leaves the private recording stage available for recovery. Other history operations reopen the selected path. The preference is a path, not a security-scoped bookmark or a persistent volume/inode identity. Original migration, default-folder and persistence behavior remain unknown. Native folder-picker rendering and unavailable-volume behavior have not been tested interactively.

## Local diagnostics

Settings has a Diagnostics tab for explicit local export. The user chooses an issue category and may add a description, occurrence date, macOS version and architecture, or a finalized mono or stereo PCM16 RIFF/WAVE sample. All optional fields start unselected. The occurrence date describes the issue and does not filter events. Descriptions are limited to 8192 UTF-8 bytes. No sample is captured or selected from session history automatically.

The export creates a new diagnostic folder with report.json and, only when selected, sample.wav. The sample is copied byte-for-byte, including its existing WAV metadata. Other audio formats are unsupported. It refuses an existing destination. The report contains current route, recording, library, microphone-test and control-confirmation states, session count, and the most recent 128 fixed lifecycle/error codes from this app run, with a dropped-event count. Controller error messages, device identifiers, file paths, transcript text and raw OS logs are not logged. The user-entered description and explicitly attached sample are included as supplied. This is a current-state troubleshooting report, not a historical crash log. Nothing is uploaded.

Troubleshooting guidance follows observed app state, including missing virtual-driver inventory, route errors, unconfirmed controls, library errors and retained temporary files. Opening Diagnostics requests no permission and changes no audio, driver or OS setting. JSON, new-folder export, optional WAV format and default choices are independent design decisions. Original log contents, attachment formats, archive format and date-filter behavior remain unknown. Native panel layout and interactive export remain unverified.

## Launch at login

App settings exposes Launch at login through `SMAppService.mainApp` on macOS 13 and later. The app reads the OS status when Settings opens and when the app becomes active. It registers or unregisters only after an explicit toggle action. It stores no substitute preference and never registers automatically. One shared controller keeps Settings windows consistent. On macOS 12 the setting is unavailable.

Enabled, not registered, approval required, service not found and unknown states remain distinct. A checked toggle represents an existing enabled or approval-pending registration; the text reports whether macOS still requires approval. A failed action rereads the OS state and shows the error. Launch at login does not start audio, record, or change which app window opens. The separate original meeting-window launch setting is not implemented here.

Five injected tests check all status states, explicit register/unregister requests, approval and error handling, activation refresh, overlapping actions and stale status reads. They never call the native registration service. The SDK requires a signed app. Actual registration, System Settings approval, login/reboot launch, relocated bundles and macOS 12 fallback remain unverified at runtime; an ad-hoc development build is not proof of these OS workflows.

## Retained recording recovery

Audio always offers Review retained recordings, even when the old staging notice is empty. Recovery scans only this app's known recording-staging directory. It lists eligible finalized 48 kHz stereo PCM16 WAV files and shows fixed rejection reasons and selectable folder paths for invalid stages. It does not repair incomplete audio or recover LocalStore `.pending` imports.

Save copy to library requires confirmation. It copies to the current selected library and refreshes history after success. The original stage stays untouched, including its manifest and failure evidence. Repeated confirmed saves create separate sessions. Source and destination admission are rechecked; failures and temporary-copy cleanup warnings remain visible. No automatic import or deletion occurs.

Scanning and saving require stopped audio, idle recording, and completed microphone-test/helper cleanup. A shared capture admission and library lease block new audio captures and folder changes until the operation settles. Confirmation requests retain the library revision and scan identity; a changed library or newer review invalidates them. Controller tests use injected services plus a real synthetic finalized stage through the actual backend, copying twice and checking history notifications and unchanged source bytes. Native recovery controls, real retained user recordings and interrupted application-exit behavior remain unverified.

## Save before quit

Normal Quit asks Save and quit or Cancel when a recording is active, including paused or pending recording work. Cancel leaves the operation running. Save and quit uses the existing audio stop/finalization path and requires a published session ID from that recording before approving termination. A clean helper exit alone is insufficient. A failed recording save or uncertain helper/test cleanup cancels that quit attempt and shows the reason. A saved session with a nonfatal cleanup warning still counts as saved.

An ongoing import, transcription, recovery, library write or diagnostic export cancels Quit without interrupting that work. During asynchronous quit, a shared gate rejects new capture, recording, device-query helper and library operations. Diagnostic export has an independent pending-work token, without requiring an accessible library. Cancel or failure releases the quit gate; approval keeps it closed until process exit. Only the exact active recording's library lease is exempt from the finish-work check. Read-only history/retained-folder scans keep their existing behavior. Startup registration remains outside this data-save coordination.

Injected tests reproduce the previous clean-stop/failed-import bug through actual route and recording controllers. They also check successful publication with a cleanup warning, Save/Cancel decisions, pending-work admission, duplicate requests, diagnostic export failure and closed-gate entry points. No native quit, NSAlert, physical audio or permission prompt runs in verification. Native prompt presentation, actual process termination, logout, reboot, forced termination and an interrupted OS shutdown remain unverified. This coordinator cannot protect data from a forced process kill.

## Save and relaunch

The app menu offers explicit Relaunch Lab Voice. A busy recording uses Save and relaunch or Cancel. The same termination pipeline as Quit blocks pending library/export work, waits for microphone-test and route shutdown, and requires that recording's published library session before launching anything. Cancellation or failed save/cleanup keeps this instance open. Relaunch never resumes audio or recording.

The launcher requests a new instance of this exact app bundle through Launch Services. It requires a returned running PID absent from the prelaunch application snapshot, an exact bundle URL and a matching executable URL when that optional metadata is present. Bundle metadata gets a bounded 500 ms nonblocking wait. The old instance approves exit only after the new-instance identity is confirmed. Admission stays closed between confirmed launch and old-instance exit, preventing duplicate launches.

A reported launch error keeps the old instance usable and permits an explicit retry. If Launch Services returns an app with uncertain identity, another instance may already exist. This instance stays open, reopens normal work admission and disables further Relaunch attempts. Normal Quit remains available. No unconfirmed process is killed and no rollback is claimed. The metadata wait does not impose a deadline on Launch Services' own completion callback or prove that the new UI finished rendering.

The retained original catalog names `context_menu_relaunch`, `save_and_relaunch` and `wait_for_relaunch_text` in Evidence `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4`; `../../quit-findings.md` records the exact labels and limits. These establish the named workflow. The publication checks, new-instance identity and uncertain-launch handling are independent safety decisions, not recovered original failure semantics. Injected launcher tests and real LocalStore publication integration verify ordering without opening another app. Native launch, prompt presentation and old-process exit still require an unlocked interactive acceptance check.

Final relaunch verification passes 117 desktop tests plus signed ARM64/macOS 12 packaging and relocated-resource checks. The save-before-launch integration uses production RecordingStorage and LocalStore, verifies the finalized synthetic WAV byte-for-byte in the published session, then permits the injected launcher. No native launch, UI, permission prompt or physical audio occurs in verification. Local log: `../../evidence/relaunch-desktop-verify-20261018.log`.


## Installed echo cancellation

Audio has an explicit Cancel speaker echo option, initially off. Choose an
installed Krisp app and validate it before Start. AEC uses the packaged own
worker and the fixed reviewed external `libaec-sdk.dylib`; it does not require
Node. The desktop package contains only our worker and its identity manifest.
Original libraries and models remain external.

Validation runs off the main actor, checks bounded ordinary files and exact
hashes, and rejects observed file changes. It starts no worker or microphone.
Changing the selected app, AEC toggle or microphone-noise option invalidates
AEC admission. A stale validation result cannot restore it. Start still checks
permissions and requires the helper's exact configuration acknowledgement.
Unexpected AEC fields when disabled, missing or wrong identities, invalid
formats or delays, and microphone NC fields in an AEC-only route are rejected.

Microphone noise reduction can run after echo cancellation.
Speaker processing remains available before the final playback reference.
The app allows the worker startup budget for up to three selected workers.
Stop and permission cancellation use the existing supervised route lifecycle.
The choice and file selection remain in memory and do not auto-start audio.

The signed own worker targets ARM64/macOS12. Packaging checks source freshness
and records its hash after signing; verification checks it again after app
relocation. The build writes `build/aec-worker-packaged` and preserves the
frozen probe worker. Physical echo alignment, speech quality, live route
recovery and the new controls' visual acceptance remain unverified.


When microphone noise reduction is selected with AEC, the desktop requires the
explicit `aec-then-nc` acknowledgement, the selected NC identity and both stage
buffering delays. Installed microphone and speaker callback bounds must match
AEC. Missing, unexpected, null or incorrect chain fields reject startup. With
both installed NC directions and AEC enabled, startup allows three worker
launches. RNNoise runs in process and does not add a worker.

The reported total is buffering only, not measured end-to-end latency. The
processing order is independent and does not establish original app parity.
Physical audio quality and the new combination's interactive UI remain pending.

## Installed microphone background voice mode

The installed microphone provider has a separate mode choice. Noise cancellation
is the default. Background voice is experimental and explicitly selects the
reviewed HVC-lfb asset. The speaker always uses its independent inbound NC model.
The app does not detect headset suitability. Use a headset; speech quality and
nearby-voice rejection testing remain pending.

Changing microphone mode clears installed NC and AEC validation, including any
pending validation result. Validate the selected files again before Start.
Mode controls lock while the route is starting, running or stopping. HVC with
AEC is unavailable and rejects Start before permission or helper launch.
Ordinary installed NC and RNNoise can still run after AEC.

The microphone CLI sends `--provider-model-role outbound` or
`--provider-model-role outbound-hvc-lfb`. No speaker model-role flag is sent.
Startup must acknowledge the selected installed microphone and speaker roles,
even for ordinary NC. Wrong, missing or null roles reject startup. A role field
on an RNNoise or disabled lane also rejects startup, including a null field.
Injected resolver and controller tests use own fixtures. The production C++
formatter fixture checks ordinary and HVC microphone acknowledgements with the
independent inbound speaker role. These checks open no original app, audio
hardware or permission prompt.

Background voice now requires an explicit confirmation for the selected
microphone. Confirm selected microphone is a headset stores its exact device
UID and a display name in the versioned local `headsetConfirmations.v1`
preference. It does not infer device type, request permission or launch audio.
Names are labels: renaming a device keeps its UID confirmation, while two
devices with the same name need separate confirmation. Invalid, duplicate or
unsupported saved records grant no confirmations.

Remove revokes one UID. Reset clears only headset confirmations, restores
ordinary microphone mode and clears provider/AEC admission. These actions lock
while audio, recording or another capture is engaged. Changing the selected
microphone invalidates pending validation. A device or installed-role change
while microphone permission is pending also prevents the captured route from
launching. Unconfirmed HVC cannot validate or Start; ordinary NC and RNNoise do
not require confirmation. Confirmations persist, while audio mode remains in
memory and starts in ordinary NC mode.

This exact-UID policy is an independent local design. Retained original controls
evidence records a persistent name-based manual headset allowlist. Original
automatic matching fields, device lists, enterprise policy and effective defaults
remain unresolved. The local confirmation list does not reproduce or claim
original automatic headset detection.


## Local compatibility engine and device metadata

Inventory now carries the global CoreAudio interface name, manufacturer and model UID used by the recovered original matcher. Missing fields from an older helper remain missing; they are never inferred from display names. Optional property read failures produce empty strings with per-device diagnostics and do not discard the device or prevent an otherwise valid name-only match.

`LocalHeadsetPolicy` implements the recovered local blocked, allowed and manual precedence, mode/rate gates and literal UTF-16 substring behavior. Its bounded JSON cache loader preserves prior lists on failed loads. It excludes account/team restrictions and network refresh. The original-method replay did not return dynamic outcomes; the 35 included local fixture expectations come from static source analysis. Host Unicode lowercase version differences and malformed rate coercion remain unverified.

This engine is not yet connected to automatic model selection or a cache importer UI. The explicit experimental mode and exact-UID headset confirmation flow remain in effect. No vendor compatibility list is bundled.


## Transcribe a saved recording

History offers **Transcribe on this Mac…** for a session with a saved recording. Choose an available on-device Speech language, start recognition, review the result and choose **Save transcript**. Recognition only changes the review draft. Cancel or recognition failure preserves the saved transcript. Replacing nonempty review text requires confirmation, and the previous review stays until recognition succeeds. An empty draft cannot be saved through this workflow.

Save updates the same session without copying audio. Unedited recognition keeps segment timing; editing and then reverting text still loses recognition timing and uses the recording-wide range. Session, recording, selection or library changes invalidate the review or reject its save. Library leases block folder switching and Quit while review is open; explicit save also locks that window's selection. In-process store commits and deletion share a lock across windows.

This uses the existing on-device-only Apple backend and requests Speech permission only on an explicit recognition action. It does not implement automatic transcription at recording stop, live captions, diarization or original post-save UI parity. Injected-recognition tests cover the complete saved-WAV-to-timed-export path; OS recognition and native dialog interaction remain separate acceptance steps.


## System power events

The app listens for IOKit sleep/wake and NSWorkspace power-off notifications. Suspend closes new audio admission, cancels pending recognition, stops local playback and finalizes route recording through the existing stop path. Resume refreshes devices and requires explicit user Start and renewed installed-model validation. Cleanup failures stay closed with retry controls. Terminal recording-save failures retain their files and visible warning; they are never reported as saved.

Settings has an opt-in toggle for simulated Sleep/Wake controls. These exercise the application lifecycle only and do not put the Mac to sleep. Simulation is hidden by default. OS acknowledgement happens before asynchronous cleanup, so pre-sleep recording durability is not promised. Actual system sleep/wake and physical audio acceptance remain unverified.


The opt-in listener integration check can be run from `app/desktop` with `LABVOICE_TEST_NATIVE_POWER_REGISTRATION=1 swift test --filter NativePowerRegistrationIntegrationTests`. It only attaches and detaches the own listener, using a callback that records events without invoking application actions. It never requests or posts sleep, wake, shutdown or audio events. The standard suite skips it. Bounded attach/detach passed on October 28; real OS event delivery remains unverified. Native cleanup reports checked return statuses and retains ownership if cleanup is incomplete.


## Observe audio use

Audio offers **Observe audio use** while stopped. It shows a one-time snapshot of active app audio, grouped by responsible application, with unavailable or failed-read states. Refresh Devices clears the observation. Pending observations use the existing cancellation, power and Quit protections. No process metadata is saved by the app.

The one-shot snapshot does not detect calls or start recording. The continuous Watch path feeds the local call tracker described below. Native UI interaction and active-device runtime mapping still need acceptance.

The desktop normalizes input devices with the recovered two-pass algorithm: remove devices without input streams, then remove output overlaps, visiting ascending device IDs and stopping each pass at one remaining input. An unknown property blocks only the branch that needs it. Output usage remains independent. Grouped clients retain sorted unique helper PIDs, including idle siblings, and use the native byte-exact application-ID plus decimal-device-ID deduplication key. The first candidate in ascending process-object order survives.

Missing identity or metadata remains incomplete. Internal feed/monitor endpoints have distinct labels from the public microphone/speaker endpoints; these labels grant no call eligibility. The UI shows app names and devices rather than raw process identifiers. This one-shot path is instantaneous. Watch uses the native timing described below.


## Watch audio use

Audio now offers **Watch audio use** and **Stop watching**. Watching coexists with routes and microphone tests. It reads CoreAudio process metadata without requesting capture permission or starting audio. The display uses the newest one-shot or watched snapshot; stopped or failed observations remain visibly stale.

The streaming helper sends bounded JSON lines. The desktop limits each line to 600 KiB, retains no stdout history and applies read backpressure. Invalid UTF-8, oversized or unfinished lines fail the stream. Operation and source generations reject stale callbacks. An exited, drained helper releases ownership; an unconfirmed live helper stays owned for Stop retry.

Suspend and Quit stop the observer concurrently with existing audio cleanup, so it does not delay recording finalization. Resume does not restart watching. Ownership cleanup and successful native Remove calls are separate results: a vanished process object can have its listener registration retired only after fresh absence and invalid-object checks. The UI reports those registrations separately.

The real helper has passed bounded attach/detach and two-process appearance/disappearance checks. Native desktop Watch/Stop interaction, CoreAudio service restart, active input/output changes and long-running observation remain unverified. Watch requests native stabilized mode and feeds observation-only call tracking. Watching never starts recording.

Watch applies recovered timing in the native helper, before desktop delivery. Brief changes can be delayed or disappear before publication. The controller requires explicit timing mode, source state, publication reason and direction flags. Readiness is distinct from a directional change. During restart recovery it retains the prior view as stale instead of displaying the reset as an observed absence. Transient source-read errors keep the helper alive for recovery.

Unknown per-process reads preserve last published usage with explicit stale markers. This differs from the original native loader's default/partial error behavior and remains a parity gap. Bounded latest-only delivery reports merged publication counts; the current full snapshot can be valid even when intermediate transition history is incomplete.

The opt-in `StabilizedAudioUseIntegrationTests` test uses the real helper through the production Swift controller, with an exact helper SHA admission pin. It skips in ordinary verification. Its bounded accepted runs verified stabilized observation and Stop without starting audio. The latest run also checks call-state handling against observation completeness and invalidation on Stop. This does not establish live transition timing, restart behavior or native UI acceptance.

## Local call tracking

Watching now feeds a local call controller. It tracks ordered microphone and speaker usage, selects the first eligible call, retains a current call until its stop delay expires, and supports blocking, unblocking and switching calls. The all-apps choice defaults to true, matching the recovered packaged local choice. Names use ECMAScript trimming and exact UTF-8 identity; blocked names use exact lowercased identity. Settings persist only in this app.

The current-state recovery baseline remains an independent reconstruction choice. Directional changes now follow the recovered DeviceManager contract: stable app-ID locale sorting, additions first, then reverse retained-order removals. Exact stream identity is app ID, device ID, direction and PID; metadata-only changes preserve the stored object. Native UTF-8 app/device key order supplies stable sort ties. Foundation Locale.current comparison approximates the original no-options JavaScript localeCompare; Electron locale and ICU equivalence remain unverified. Missing history is not reconstructed. Complete observations can refresh the baseline after failures, mode changes or missed publications. Stale input, restart, Stop and power events cancel pending selection timers. Private routing endpoints, the app bundle and its own responsible process are excluded from call candidates.

This is observation-only qualification. It does not request microphone access, admit capture, start ASR or automatically record. The original stream callback order is recovered. Asynchronous permission completion order and the automatic recording join remain incomplete. In all-app mode both physical directions can qualify; disabling it restricts candidates to the public virtual microphone and speaker. No vendor account, trial or cloud gate is used.

Application versions propagate from responsible-app metadata. An empty version is a recovered valid result; null denotes unknown or rejected metadata. Exact verification and native acceptance limits are in the latest CHECKPOINT.md section.

## Record selected app audio

While Watch has a fresh detected call, Audio offers an explicit selected-app recording action. It records output from the selected application's currently active audio processes. It does not include the microphone, start a route, change playback/mute, run ASR or automatically record a call. The first real use can require macOS system-audio capture permission. No permission prompt or live tap has been exercised by verification. The app and floating widget show an independent recording status and Stop action.

The immutable target includes responsible PID, exact app ID and explicit active process object/PID pairs. Unknown, pending, fallback, ambiguous or changed targets cannot start. Selection, call activation, watch generation and power epochs fence asynchronous preparation and startup results. The helper revalidates actual target identity and source format at admission and during capture. It never falls back to a global tap. This path owns the shared capture lease, so route, microphone-test and recovery capture cannot overlap it.

Stop, a changed selection, power or Quit finalize only this owned capture. A verified result and drained successful helper exit are required before importing its validated 48 kHz stereo PCM16 WAV into the pinned library. Failed or uncertain results retain private staging files. Session metadata and recovered copies retain selected-app-output provenance; explicit saved-session transcription preserves it. No automatic transcript is generated.

This is the application-output source needed for per-app call capture, not a complete call recording implementation. Separate microphone audio, clock alignment, processing/ASR integration and original-versus-rebuild audio acceptance remain incomplete. Local tests use injected sources and synthetic WAVs.


Selected-app recording can explicitly include the microphone selected in Audio. This option defaults off and is not persisted. Start acquires the shared capture lease, requests microphone authorization only if needed, refreshes the selected device and rechecks the call, configuration and power state before launching. Changing the source, mode or microphone stops the owned operation without automatic restart. App-only mode never requests microphone access.

The combined recording uses an independent half-app/half-microphone stereo mix over the sources' common timestamp coverage. Successful history records the app process tuples, physical microphone UID/object ID, channel zero and mix/timeline policy. Retained staging distinguishes requested sources from an admitted capture; recovery omits source claims when admission was not verified. No live ASR, automatic call recording, noise processing or original mix parity is implied. Native permission and audio paths still require interactive acceptance.


## Current accent acceptance

The outbound accent path has separate exact-file admission, worker framing and model-empty time slots. It defaults off and rejects microphone NC/AEC composition. Source fixtures, packaging and the packaged helper physical-to-virtual route pass at their recorded checkpoint. GUI accent Start remains unverified after an accessibility-tool timeout at the file picker. See the latest root CHECKPOINT.md for actual identities, the bundled-runtime migration result, queue-delay measurements and remaining acceptance. Older test counts and macOS12 packaging paragraphs above describe their dated builds.
