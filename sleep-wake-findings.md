# Sleep and Wake menu commands

Static investigation, 2026-10-28. The installed package identifies itself as Krisp 3.17.9.

Sleep and Wake are test-mode tray commands. They inject application power-monitor events. The inspected handlers do not request operating-system sleep or wake. Both commands appear only when `configService.staticSelector().testMode` is truthy. The packaged `main.testMode` default is false. This does not establish the effective configuration of a running installation.

No original code was executed. REA captured an independent bounded ASAR reader under a network-denial sandbox. The reader parses the archive and literal obfuscation table. It never imports, evaluates or calls the target modules. Application state changes below are static conclusions, not observed behavior.

## Artifact identity and evidence

The selected archive is `/Users/harikp/Applications/krisp.app/Contents/Resources/app.asar`, 30,041,755 bytes, SHA256 `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`. Each successful reader capture verifies unchanged archive identity before and after its read.

Relevant members:

- `.vite/build/BootstrapApp-3T6N5QeL.js`, SHA256 `bbaedd07bcd78d093f1011a41e3aeca92707c1f77fc7cca03305ffd4cd90cff0`.
- `.vite/build/SentryManagerMain-DrYTrfPP.js`, SHA256 `cf21e7e4fa19deb6f960223a883fe8831f25d66ba68d15e127731de5aead8579`.
- `.vite/build/BootstrapPreload-BNUgiXZm.js`, SHA256 `00e4b93b660924d2e6d9a45303c58d0798a46b07c64d4398e80566de3adb1d30`.

Accepted static-reader captures:

| Capture | Evidence ID | Relevant scope |
| --- | --- | --- |
| v4 | `ev_3f7ddb217bad6c20c880b2ca322fface88c7924efbe385a75c2c8e1b4edd9207` | Menu handlers, core event declaration, Main listener and power callback |
| v5 | `ev_05b68a66c7559faa4ff37d10948940824d0d74d383dab9ad47f6a55841faa1b3` | Packaged false default, selector forwarding, complete Main suspend/resume dispatch |
| v6 | `ev_d252ddf903248f2795a41f209f17bfea05bac47ba89580ee3b011c3234ef7ed5` | Complete AppState queue and transition methods |
| v7 | `ev_9a7508fc22b011b377509f2f90e73f800b515f82435be264fddd6d2741f8ab3e` | AudioService, AudioRecordingService and WindowService methods |

All four captures exit with code 0, verify the owned process group and remove the temporary root. Raw terminal records are complete. Rendered terminal snapshots can be truncated independently and are not the source used here. Scenarios and complete results are private files under `evidence/model-probes/sleep-wake-20261028-v{4,5,6,7}.{scenario,result}.json`.

The independent reader is `evidence/model-probes/read-sleep-wake-asar-20261028.cjs`, SHA256 `23a3944405fd6140c70debe53f91e6ea9455ca5a0c3bc9b369406a31aa6b6917`. It derives from the retained speaker-graph reader. The BootstrapApp literal table has 28,833 entries and resolves after 183 rotations. Only literal strings and known direct decoder aliases are substituted. This is not a complete JavaScript deobfuscation claim.

The first schema request, v1, was rejected because this connected capture tool does not accept an executable SHA256 input. The corrected v2 found only literal table entries. Its output included complete raw bytes but truncated rendered states. V3 found the handlers, but cleanup listed three unverified process candidates despite a verified owned group and removed root. V3 is retained as a caveated attempt; accepted v4 and v5 independently establish the menu logic. No candidate process was signaled or repaired.

## Menu and event path

`BaseTray.defaultContextMenu()` appends a separator and the test-only commands at the end of the normal context menu. Sleep and Wake are both unconditional within the test-mode branch. They have no checked state and no state-dependent enabled predicate. The adjacent Fetch profile item requires an account; Sleep and Wake do not share that account predicate.

Sleep logs its click and sends `CoreEvents.POWER_MONITOR_EVENT_CHANGE` with one argument, `BootstrapPreload.PowerMonitorEvent.Suspend`. Wake sends the same core event with `PowerMonitorEvent.Resume`. The event channel is `krisp:core:power_monitor_event_change`.

`Main` binds that event to `onPowerMonitorEventChange`. It also registers the same callback with `NativeUtils.registerTroubleshootingNotifications` during startup. Thus the menu injects an event into the application path used by native power notifications. A `PowerOff` event follows a separate quit branch and emits `system-poweroff`; neither menu handler supplies PowerOff.

Useful decoded character offsets in v4 are 6,983,718 and 6,983,956 for the menu calls, 7,232,682 for the Main event binding, and 7,274,775 for the power callback region. These are offsets in the independently decoded text, not archive byte offsets. The raw default is visible at member character offset 115,042 in SentryManagerMain in v5. BootstrapPreload's static selector forwards `main.testMode` at raw member character offset 14,686.

## State transitions

`Main` constructs `AppState` with bound `resumeServices` and `suspendServices` callbacks. AppState starts in `Active` with an empty in-memory event queue. No persistent sleep preference is written in these inspected methods.

1. Every event is appended to the queue. Suspend immediately awaits `doWork`. Resume schedules `doWork` through `setImmediate`.
2. `doWork` waits in 25 ms intervals while the state is `Activating` or `Suspending`.
3. Once stable, it pops the newest event and discards the remaining queue. While Suspended, only Resume calls `doResume`. While Active, only Suspend calls `doSuspend`.
4. Suspend sets `Suspending`, awaits the suspend callback, then sets `Suspended` in `finally`. Resume sets `Activating`, awaits the resume callback, then sets `Active` in `finally`.
5. Callback errors are logged. They do not stop the final state assignment. Repeating Suspend while already Suspended, or Resume while already Active, causes no callback.

The queue therefore collapses pending events to the newest requested stable state. It does not promise completion of every intermediate request. The deferred Resume branch does not return the later `doWork` promise to the caller. Actual event timing and failures were not exercised.

The complete class is present in v6 around decoded offset 2,555,546.

## Feature dependencies and dispatch order

Main calls each service only if the registrar has an instance. Calls run in source order; most calls are not awaited.

Suspend order is ViewService, AudioRecordingService, ScreenRecordingService, UploadService, CallService, AsrService, AudioService, InterpreterService, InCallHelperService, CalendarService, AiChatService, ActivityService, AccountService, NotificationService, SupervisorInsightsService, VoiceMacrosService and WindowService. Only SupervisorInsightsService's suspend call is explicitly awaited in this dispatch method.

Resume first awaits AccountService. It then calls CalendarService, ActivityService, InterpreterService, InCallHelperService, AiChatService, AudioService, AudioRecordingService, ScreenRecordingService, CallService, AsrService, UploadService, NotificationService, SupervisorInsightsService, VoiceMacrosService and WindowService. ViewService is absent from this explicit resume dispatch. The method does not await these later calls.

This is a broad service lifecycle command. It cannot be reconstructed faithfully as a microphone mute toggle or a flag that only stops a route. AppState reaching a stable state proves only completion of its dispatch callback. It does not prove that every unawaited asynchronous service operation has completed.

### Audio and recording effects

For an initialized AudioService, suspend records whether Krisp microphone and speaker are default devices for Multimedia and Communication roles. It stops an active in-person call, stops and removes outbound microphone and inbound speaker graphs, stops both device audio streams and disposes DeviceManager. If AudioService is not initialized, it returns without these actions.

AudioService resume also requires initialization. It calls DeviceManager.init, reapplies the stored microphone volume-control mode and sets the speaker mode to SYNC_WITH_KRISP. The inspected resume method does not itself restart a graph. Device initialization callbacks, native device restoration and later graph startup are separate dependencies. This report does not establish their full wake behavior.

AudioRecordingService suspend emits CALL_AUDIO_RECORDING_STATE_RESET when initialized. Its resume method only checks initialization and logs. The adjacent ScreenRecordingService methods use the corresponding screen-recording reset event. These methods alone do not prove that recording bytes are finalized, saved or recovered; later event handlers remain outside this pass.

WindowService forwards suspend/resume to DashboardViewHelper. The recovered helper pauses an existing resource-fetch timer and marks itself suspended, then clears that flag and resumes the timer or creates it on resume. No all-window hide operation appears in these methods.

V7 begins the AudioService slice at raw member character offset 3,949,077, the WindowService slice at 6,255,557 and AudioRecordingService at 5,309,675. Some fixed-length slices extend into adjacent classes. Only the explicitly identified methods above support these claims.

## Remaining limits and implementation decision

Menu handlers, packaged default, core event connection, AppState transitions and Main's explicit dependency order are answered by static evidence. Actual runtime availability, effective configuration, native callback event values, wake-time device reenumeration, restored default devices, graph restart, physical routing, recording finalization and complete downstream service behavior remain unverified.

Hidden local commands remain in the requested parity scope. Reconstruct the shared application power-event lifecycle first, then expose Sleep and Wake through the independent development/test surface. Keep their simulation role separate from production operating-system notifications. Preserve active recordings and invalidate stale admission before resume. The source does not justify automatic restart of a previously active route from AudioService.resume alone. This investigation makes no implementation change and claims no runtime parity.


## Production source boundary and follow-up blocker

Accepted v4 establishes that Main registers `onPowerMonitorEventChange` with `BootstrapPreload.NativeUtils.registerTroubleshootingNotifications`. It does not establish the operating-system notification registration inside the native addon. Therefore neither Electron powerMonitor nor NSWorkspace is a verified equivalent production source in this pass.

A follow-up reader capture, v8, returned complete-looking raw output but failed REA cleanup. It reported candidate PID 87674 with an unreadable ownership environment and retained its temporary root. A changed, narrower v9 request then failed before capture because that lifecycle cleanup remained incomplete. These attempts are stored under the same private filename pattern. They have no accepted Evidence ID and do not extend the accepted claim set. No process was signaled, and no provider repair was attempted. Further static native/ASAR reads require the REA lifecycle blocker to be resolved through its supported workflow.

V8's caveated output identifies useful next targets: the preload method forwards to `kr-native-utils.RegisterTroubleshootingNotifications`; the packaged `kr-native-utils/index.js` forwards that export to `./build/Release/kr-native-utils.node`. Electron powerMonitor hits occur in Sentry integration code and do not establish the application lifecycle source. The native registration function and callback mapping remain the next production-source question.

## Recording preservation boundary

Accepted v7 contains `AudioRecordingService.onGraphRemoved`. It invokes `reattachRecordingToActiveGraph`, which updates audio/transcript recording attachments and reapplies paused state from the meeting-assistant model. It does not itself call `stopCallRecord`.

The separate accepted `stopCallRecord` method stops the native audio recorder, closes an open session interval, sets the call end date and updates upload-session metadata. It can discard a pending call or uploader task depending on its arguments, and it emits the recording-state change. `stopCallBackgroundRecord` has a parallel transcript-recorder path. Their presence does not prove that suspend invokes them or waits for them. `dispose` has explicit awaited recording-stop work, but Main's suspend path calls `suspend`, not `dispose`.

V8's unaccepted partial output points to a meeting-assistant listener for `CALL_AUDIO_RECORDING_STATE_RESET`, named `onAudioRecordingStateReset`. Its method body was not recovered in accepted evidence. Whether this is only a UI reset or starts finalization remains unresolved. The call/session path from that reset through native recorder stop, finalized bytes and durable storage is therefore an explicit implementation blocker. Do not equate the reset event, graph teardown, helper stop success or AppState.Suspended with publication of a saved recording.

## Retained and excluded dependency mapping

The dispatch names are recovered; most individual service method bodies remain outside accepted coverage. Map functions to their actual local behavior before reconstructing them. The service name alone does not classify the whole service.

| Dependency | Independent scope |
| --- | --- |
| ViewService, WindowService | Retain local UI lifecycle. Dashboard resource fetching needs its local/cloud boundary preserved. |
| AudioService, AudioRecordingService | Retain local routes, recording and recovery. Recording publication on suspend remains unresolved above. |
| ScreenRecordingService | Local screen-capture contract remains unresolved in the feature ledger. A paid label does not exclude it. |
| AsrService | Retain established on-device transcription and local transcript state. Exclude remote ASR/upload services. |
| InterpreterService | Voice Translation local/service boundary remains unresolved. Do not exclude by name. |
| InCallHelperService | Retain established local helper behavior. Recover its methods before selecting lifecycle effects. |
| CalendarService | Agenda/calendar source boundary remains unresolved. Preserve proven local state. |
| AiChatService, SupervisorInsightsService | Local UI/state remains subject to evidence. Remote generation and telemetry are excluded. |
| ActivityService, VoiceMacrosService | Retain proven local behavior; exact suspend/resume method effects are not recovered here. |
| NotificationService | Local notifications remain retained. Cloud notification delivery, if present, is a separate boundary. |
| CallService | Local call/session state remains retained. Usage upload, billing and telemetry are excluded. |
| UploadService | Remote upload is excluded. Any local recording staging or persistence dependency must first be separated by evidence. |
| AccountService | Vendor authentication, entitlement and account sync are excluded. Do not recreate their waits as local availability gates. |

Next recover the native notification mapping and accepted reset-handler path, then implement the shared retained local lifecycle with explicit recording preservation. Hidden simulation commands reuse that lifecycle. No commercial gate, cloud operation or analytics dependency should be introduced into the independent local path.

## Read-only resume check and retained recording join, 2026-10-28

The specific earlier candidate PID 87674 is now absent in a read-only process listing. The supported REA `binary_session` call reports no open target, no observed analysis activity, null provider operation health and an available process-capture capability. This capability advertisement does not establish that the process-capture lifecycle is usable.

One narrowed follow-up request, v10, selected only `onAudioRecordingStateReset`. REA rejected it before producing any new target observation because process-capture cleanup remains incomplete. It now reports ten live candidates: 28014, 28016, 28297, 28299, 28303, 28304, 28305, 28307, 28308 and 28310. Read-only process metadata identifies all as Chrome or Chrome helper processes. Some belong to process group 23117 and others to 28297 or 28298. None was signaled or modified. Their presence does not establish ownership by this investigation. The global lifecycle condition remains unresolved, even though the original specific candidate is absent. The private v10 scenario/result retains the exact failure. No further capture was attempted after this result.

The complete retained v4-v7 raw outputs contain no `onAudioRecordingStateReset` identifier. V8 contains exactly two occurrences, both in meeting-assistant event listener subscription/unsubscription excerpts. Its complete raw excerpt has archive identity before and after and a member digest, but neither occurrence includes the method body. The failed lifecycle does not by itself prove corruption of those static bytes. They support the bounded lead that the reset event has a meeting-assistant listener, with the capture-cleanup caveat. They do not answer what that listener does.

A missed part of accepted v7 does establish a separate event path. `CoreEvents.RECORDING_CALL_STOPPED` is bound to `AudioRecordingService.onAudioRecordingCallStopped`. That handler obtains the active foreground and background recording records by ASR stream ID. Each prepare method sets an uninitialized stop reason to `auto`. It starts `stopCallRecord(record, false, false)` and `stopCallBackgroundRecord(record, false, false)` through `Promise.all`, attaches an error logger and returns without returning or awaiting the resulting promise. The foreground handler begins at decoded offset 30,405 within v7's AudioRecordingService slice. This adds a known stop-event-to-recorder join; no recovered excerpt joins the suspend reset event to this stop event.

Accepted v7 also establishes that `AudioService.stopAudioRecording` delegates to `callRecorder.stop`, and `stopTranscriptRecording` delegates to `transcriptRecorder.stop`, when initialized. They return `MediaSPErr.NotInitialized` otherwise. These methods occur at decoded offsets 167,536 and 169,147 within v7's AudioService slice. Recorder stop internals, finalized-file publication and durable local-store completion are not in these excerpts.

Once REA's lifecycle is usable again, the next original read should select only the definition of `onAudioRecordingStateReset` and its immediate callees from the exact pinned BootstrapApp member. The next native query should resolve `RegisterTroubleshootingNotifications` and its callback/event mapping in the exact installed `kr-native-utils.node`, using REA artifact identity first. Do not substitute a new session or an unrelated provider repair for verified cleanup. No application code, native execution, audio operation or administrator change ran in this follow-up.

## Purpose-built JavaScript analysis, 2026-10-28

REA's static application-analysis tools remain usable independently of the blocked process-capture lifecycle. A summary-only evidence lookup found no retained `analyze_javascript_application` record for the exact archive digest before this pass. No matching exported application graph was identified among the retained lab files inspected.

A summary-first `analyze_javascript_application` call initially failed its default integrity policy. The ASAR declares SHA256 `38477d90d7ae5c8add1f0ba475556159f46fde5edfc5257cd89b96fa7296be1f` for the unpacked kr-audio-dm native companion, while its observed digest is `ef833e13e87064f51cbb547295b1c65138871906bcae651160b0daeeb3fcb3e6`. The tool's documented `record-and-continue` mode then retained the contradictions and completed partial inert analysis with a 1,024 MiB worker heap and 30-second per-source timeout. It did not execute the application or native addons.

The retained parent application Evidence is `ev_7db961a418a25cdf13782fde221628e96275f062eca583f00b0eba3bfb1bddf2`. Its summary view is `ev_00369a5ed34901565b7f06948eda18c7d6440dbb1707cb4769390be6531bd6ac`. It parsed 19 JavaScript files and reports 10 application unknowns plus 4,293 semantic unknowns. BootstrapApp's semantic worker exhausted its heap. Several other large sources also exhausted their worker heap or exceeded the parent result budget. This partial coverage cannot establish absence of a method or event relationship.

The module inventory page `ev_e149f9e5c32e04184ca57569d38a0666e1ffc1f31ffdf19eb4fb36fd5b7ca58e` selects BootstrapApp's exact asset node `jag_node_96d443a473b4f4d4eed95dceca8ea4608507dd1dcc57e94ceb86f0e614f8650d`. Asset view `ev_342e7aa90b406802a916964329d2aa49c73e03797d29164dd843d4a5ba389be3` confirms 6,368,169 bytes, complete inert parsing and SHA256 `bbaedd07bcd78d093f1011a41e3aeca92707c1f77fc7cca03305ffd4cd90cff0`. This is the same member digest as the prior reader captures. The record-and-continue analysis separately flags unpacked native integrity contradictions for kr-audio-dm, kr-ext-hub, kr-media-sp, kr-native-utils and kr-node-logger. It treats those observed native bytes as untrusted; no native behavior claim follows from this analysis.

An exact outgoing string-seed trace for `onAudioRecordingStateReset`, `ev_0868a665bb178a2fb073787db44c0f4493f1174d4d445ca3614fac5c321f90b9`, returns zero matches with `source_graph_status: partial`. The module views expose retained identities, observations and source ranges, not a generic raw-source window. The exact reset-handler body is therefore still unresolved. A negative trace in this partial graph does not contradict the prior static listener excerpts.

Private results are `evidence/model-probes/sleep-wake-static-analysis-20261028*.result.json`, `sleep-wake-static-module-page-20261028.result.json`, `sleep-wake-static-module-asset-20261028.result.json` and `sleep-wake-static-reset-trace-20261028.result.json`. The complete parent graph is retained in the current REA session. Reuse its Evidence ID while available. No broad analysis rerun, process capture, source extraction or provider repair followed the bounded trace. The next useful capability is a focused inert member/method read or retained decoded-source query, rather than another whole-application semantic analysis at the same limit.

## Native production notification source, 2026-10-28

Focused native REA analysis closes the production-source question. This supersedes the earlier source-boundary unknown. The selected installed artifact is `/Users/harikp/Applications/krisp.app/Contents/Resources/app.asar.unpacked/.vite/build/node_modules/kr-native-utils/build/Release/kr-native-utils.node`, ARM64 Mach-O, observed SHA256 `17eb466b1092c37b0bbc8e04d4a29163a9fbef1a5e1e802be7c842dd59bc94ea`.

Keep its identity separate from the ASAR declaration. The archive declares `5143abf99794e68e3421aca64703108271eb515483857faf672cedac044ce7f0` for this unpacked member. The static application graph records contradiction `ic_515edbb718c3f7c33b0ab50f6dcb98be768bf1376abc9412c3f6aeeb189612f6` with observed-untrusted status. These native conclusions apply to the observed installed digest. They do not prove equivalence to the archive-declared bytes.

REA bound Ghidra 12.1.4 with analysis profile digest `20565088524a2d0359b9b96f46ac48e679d774c7b0092c56abc06de8fdbec11c`. It analyzed the artifact as immutable source. No native addon function ran.

| Function | Address | Evidence |
| --- | --- | --- |
| RegisterTroubleshootingNotificationsNapi | `0xaad8` | `ev_d2a9c62a5bac530e51e866c7f0c0ed066147c4a9e2a6ccb75ea0b517233d05c3` |
| NativeUtilsApi::RegisterTroubleshootingNotifications | `0x7ee04` | `ev_4b670ae6f7f2cfcadc24b757c4266b15410812a057c06833d7edccb7612597e7` |
| HostTroubleshootingService::StartMonitor | `0x8c390` | `ev_be53a11e6a16c4ac8336631e424e217c549ae42a769e39e6a087eaff9ae12a41` |
| HostTroubleshootingService::StartEventListener | `0x8c4fc` | `ev_4ca375f122dce3896b76134fb0a6640ad95576d46cfc20cf4fa1cdc2ae47b9d5` |
| HostTroubleshootingService::EventCallback | `0x8be0c` | `ev_094a77e255f986a67d9883fc97345c715495a9457370dcfd75eacd4c75192eeb` |
| StartSystemShutdownListener | `0x8e3a0` | `ev_563df6349a613486f3ae6e49b5cbff86f99550fd4f075b6198a045969a3e83d3` |
| SystemShutdownNotifier::startWithCallback: | `0x8e208` | `ev_bd03f5d81e257f52d93edc769d8b55ca9be9db339be98ceb497b122abb1f83e5` |
| SystemShutdownNotifier::handlePowerOff: | `0x8e364` | `ev_ea3fd9373e7298b6dd9e755ff160f9fac1b405335fc095706720143466199cc7` |
| PowerManagementEventRaiseCB | `0xa7d8` | `ev_68f6ce82ac4569636f275bb3447fd17edc1676ef3445b975554b102116761e15` |
| Async bridge closure | `0x1b938` | `ev_c8386cae996650e208c8f3b8326607fb0963eb0d8e5c1b4103ee9cb0c284d09a` |
| JavaScript delivery closure | `0x1bc00` | `ev_44abb6c319bea2ba5748d8c5da76c65d5dc82792c4e99c67e279c687062626c4` |
| HostTroubleshootingService::StopMonitor | `0x8c65c` | `ev_fd32d15452107aa9b56baa784d88091f7e615dddfec0833be705edaf8e2e5ac0` |

### Registration and event values

The N-API registration requires exactly one function argument. It creates the asynchronous invoke owner and a Napi ThreadSafeFunction, then passes `PowerManagementEventRaiseCB` into NativeUtilsApi. The API calls its host-troubleshooting service through virtual offset `0x10`. The recovered factory installs vtable `0x311e68`; complete 48-byte read `ev_58cc9f7e8df2e3daa0ec986272ea56481983d91898d67afed598c52e24763368` places `StartMonitor` at that offset and `StopMonitor` at offset `0x18`. Factory dossier `ev_e05e73f958fd9fa7f7366da9420dcf3352e86b9c6988c34f3297e37c0ce8a067` binds the installed concrete implementation.

StartMonitor stores the supplied callback, registers the separate shutdown listener and starts IOKit power listening. StartEventListener calls `IORegisterForSystemPower` with its service instance and EventCallback. On success it adds the IONotificationPort run-loop source to the current CFRunLoop in common modes. An unsuccessful registration returns failure. This source uses IOKit, not Electron powerMonitor or NSWorkspace sleep/wake notifications.

| Native notification | Numeric message | Application event | Other action |
| --- | --- | --- | --- |
| CanSystemSleep | `0xe0000270` | None | Calls IOAllowPowerChange |
| SystemWillSleep | `0xe0000280` | `0`, suspend | Calls IOAllowPowerChange before callback dispatch |
| SystemWillPowerOn | `0xe0000320` | None | Logs that wake has started |
| SystemHasPoweredOn | `0xe0000300` | `1`, resume | Dispatches after the has-powered-on notification |
| NSWorkspaceWillPowerOffNotification | Separate notification | `2`, power off | Calls the stored shutdown callback |

The IOKit constant names were checked against the installed SDK's `IOKit.framework/Headers/IOMessage.h`, definitions at lines 137, 156, 166 and 175. The exact numeric branches and emitted integers come from the original native dossier. Other message values return without dispatch. A null service pointer logs and returns.

SystemShutdownNotifier registers `handlePowerOff:` with the shared NSWorkspace notification center for NSWorkspaceWillPowerOffNotification. That method emits integer 2. Its stored callback forwards the event to the same host-troubleshooting callback. It is distinct from the IOKit suspend/resume source.

### Delivery and preservation implications

PowerManagementEventRaiseCB copies the integer into the async invocation path. The next closure copies it again into an owned task and calls `napi_call_threadsafe_function` in nonblocking mode. Queueing failure is logged. The JavaScript delivery closure checks native-utils initialization, creates a Number from that copied integer and calls the supplied JavaScript function with that number and an empty array. Main's known callback consumes the first event argument.

The system sleep acknowledgement does not await JavaScript dispatch, service suspension or recording save. It occurs before the native suspend callback reaches the async bridge. Therefore the original path does not provide an evidenced operating-system sleep delay for durable recording publication. This makes the existing recording-reset-to-save unknown material: application state, OS acknowledgement and saved recording publication are separate outcomes.

StopMonitor removes the current run-loop source, deregisters IOKit system-power notifications, closes the root service connection and destroys the notification port. Its body does not show removal of the NSWorkspace shutdown observer. That observer's full teardown remains outside this focused question. Actual OS notification timing, delivery during shutdown, application suspension and recording preservation have not been exercised.

### Retained evidence and close limitation

The focused procedure-name search is `ev_558968646ddeb26481a6831712005f169db536ccbbc409ce570ed3c90e793063`. Individual complete native dossier results are private files matching `evidence/model-probes/sleep-wake-native-*-20261028.result.json`. The exported bundle `evidence/model-probes/sleep-wake-native-20261028.bundle.json` contains 36 records in 37,357,933 bytes, including the prior static application graph and the native dossiers.

After export, close_binary was requested. It returned cleanup_incomplete because global process_capture_resources still listed candidates 29629, 32300, 32677 and 32857 with unreadable ownership environments. This was a close failure, not original execution or a native-analysis failure. No cleanup retry, candidate signal or provider repair followed. The target may remain selected; do not assume provider resources closed. The native facts above remain retained with their exact observed artifact identity and complete static dossiers.

The production event source and integer mapping are now answered statically. The remaining immediate prerequisite is the original meeting-assistant reset-handler body and its recording/session completion chain. That question remains separate from the recovered OS notification path.
