# Automatic call activation

Static investigation, 2026-10-28. This report concerns the retained activation family: local calling-app detection, automatic activation policy, user-blocked apps and competing calls. It does not establish live detection or recording parity.

The original has a local CoreAudio process-usage source. It tracks input/output usage, associates helpers with a responsible application and forwards client snapshots to JavaScript. A running or frontmost application alone is not the recovered call signal. The retained JavaScript CallService separately requires microphone and speaker legs and applies policy before selecting a current call.

## Identity and method

REA session state was checked before work. It reported no open target. The selected target was then opened explicitly:

`/Users/harikp/Applications/krisp.app/Contents/Resources/app.asar.unpacked/.vite/build/node_modules/kr-audio-dm/build/Release/kr-audio-dm.node`

Observed ARM64 Mach-O SHA256 is `ef833e13e87064f51cbb547295b1c65138871906bcae651160b0daeeb3fcb3e6`. The ASAR-declared digest is `38477d90d7ae5c8add1f0ba475556159f46fde5edfc5257cd89b96fa7296be1f`. These differ. Native conclusions describe the observed installed bytes, not equivalence to the declared distribution. The surrounding ASAR remains pinned by retained evidence to `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`.

Native functions were inspected through REA's Ghidra provider. No target code executed. No process-capture retry, microphone operation, device start, network operation, administrator change or provider repair occurred.

Native dossiers and procedure searches are retained in `evidence/model-probes/activation-20261028.bundle.json`, 20,498,951 bytes and 38 records. Individual private dossier files use `activation-*-20261028.result.json`.

## CoreAudio source

AudioProcessContainer initializes a system audio-process listener and storage. It registers on AudioObject 1 for the global `prs#` process-object-list property and `srst` service-restarted property. It then takes an initial process-list snapshot. A process-list update reconciles existing objects against the new list, removes disappeared objects and creates trackers for new ones. A failed process-list read is logged and does not constitute an observed empty call list.

Each process listener registers these properties:

| Selector | Scope | Meaning checked against installed CoreAudio SDK |
| --- | --- | --- |
| `piri` | Global | Process running input |
| `piro` | Global | Process running output |
| `pdv#` | Input | Devices used by process input |
| `pdv#` | Output | Devices used by process output |

Property callbacks mark the first pending change time for that process. A timer scans pending records and clears the timestamp before invoking the stored callback once the configured elapsed threshold has been reached. The exact timing section below resolves this threshold to 200 ms. Additional callbacks while pending do not reset that first timestamp. The timer interval is 20 ms. The timer constructor multiplies the supplied 20.0 by 1,000,000 before configuring dispatch time and interval; this closes the units join.

The used-device loader first checks `piri` or `piro`. A false running value yields an empty set for that direction. A true value reads `pdv#` in the respective scope. It builds a set of device object IDs. This is per-process device usage, not an acoustic speech detector.

The process tracker normalizes input-device lists when more than one input device remains. It removes devices without input streams and removes devices that also occur in the output set, stopping once fewer than two input entries remain. The exact normalization is more specific than taking any device with a nonzero running flag.

A second tracker cache compares normalized used-device sets against the last published state. A different state is cached with a first-change timestamp. Further changes update that cached state without resetting the first timestamp. Returning to the published state clears the pending cache and pauses its timer. On a timer tick, a transition that makes a previously nonempty input or output direction empty selects the configured end threshold; otherwise it selects the start threshold. Once the elapsed time strictly exceeds that threshold, the cache becomes the published state and a copied AudioProcessInfo is sent through the stored callback. Packaged threshold defaults are recovered in the follow-up below; effective overrides remain separate.

There is also an older CAStreamTracker/device-activity path. Its ActivityStateChange reads whether a tracked device is in use and emits a device-based stream record. Its callback and device lookup were inspected. The follow-up below resolves registration and version selection; the complete older-source attribution/removal contract remains incomplete. Do not assume that the newer audio-process path is available or selected on every supported macOS version.

## Application identity

CAApiHelper.LoadAudioProcInfo requires a nonzero audio object with class `clnt`. It reads `ppid` in global scope for the actual PID. A zero PID is rejected.

It resolves a responsible PID through the dynamically located `responsibility_get_pid_responsible_for_pid` function. If the function is missing or returns no positive PID, it logs and returns the actual PID as fallback. This is a responsibility lookup, not evidence of walking parent PIDs until a visible app is found.

The responsible PID supplies the localized application name, with binary-name fallback if the localized name is empty. The process bundle ID comes from `pbid`. An empty process bundle falls back to the app name. When the actual and responsible PIDs differ, the responsible bundle ID comes from NSRunningApplication for the responsible PID. If that field remains empty, it falls back to the process bundle field. Application version is also resolved for the responsible PID.

GetAppIdByPID uses NSRunningApplication.runningApplicationWithProcessIdentifier, then bundleIdentifier and UTF8String. A missing application or empty bundle identifier returns an empty string. No synthetic bundle identifier is created there.

The client callback delivers a Number device type and an array of objects. Native serialization establishes these fields:

- `pid`, a numeric PID.
- `actualPids`, a string in the native ClientAppInfo representation.
- `appName`, `appVersion`, `appId` and `deviceId`, strings.

Do not convert `actualPids` into an array based only on its plural spelling. Its native field is serialized as a string. Native stream records are converted into ClientAppInfo, and the client-list callback emits the complete current list for its device type. A container compares prior/current records before triggering a changed-list notification. The follow-up below closes grouping across helpers; the older-source attribution/removal contract remains separate.

## Native evidence

| Function | Address | Evidence ID |
| --- | --- | --- |
| AudioProcessContainer.Initialize | `0x59e10` | `ev_8c3422876542101bb67ccf9de816493e1f81b05ab1ad113e01327d97d4f2cddf` |
| AudioProcessContainer.AddListeners | `0x5a1cc` | `ev_a0fb7c2a4179ec136b4bd717c2ab81b93a0b5c19c69a080a07cdef8d1f8e7c8b` |
| AudioProcessListChangeHandler | `0x5a23c` | `ev_b4dbf406cfb5d2ffac88aee25fad7f89dad6282b6dc7cfb66692c4a318961bf8` |
| AudioProcessListener.AddAudioProcListener | `0x5f910` | `ev_8bd657c7826adc2ed0165e470c284abcf4090835014a02da41a4e16d81763322` |
| AudioProcessListener.HandleAudioProcEvent | `0x5fc18` | `ev_c2c81eb44648e68113abd7d08348cc3cb4828675c857209d0fce253028b43527` |
| Listener timer block | `0x5eba4` | `ev_6c816574348037ed14c1b51ef045d09ab2c4cca0c9a3bd6cff084fd7ee5fd6e7` |
| AudioProcessTracker.Initialize | `0x604ac` | `ev_e20c4eba7adbfafb843386e9680f5891394ac933cddc98db2532bc95e9c39567` |
| HandleUsedDevicesChange | `0x616e4` | `ev_f572b1e9bad39a5e1e528d1755f6b5e04c39bd4418dd8fd8b687a61e8bc427ba` |
| Tracker timer block | `0x60b94` | `ev_631f9e92407633e80e6a0b171b86f976628bfab118f0407e862fb78df359a6db` |
| NormalizeDeviceList | `0x613e0` | `ev_f07f82b4714fe8bd12e93e6841107aa80ece6b799414b9760c7b5df967cb6599` |
| LoadAudioProcInfo | `0x2ff48` | `ev_9d215f51b3bc2b3b8ef0861e9d2e4e4a3678808e8c99bad281709b587db3b477` |
| GetResponsibleProcessID | `0x48418` | `ev_be82651b5219c5f60613f19ac897b4f8fc68da8da37cd594361d1f15399993e5` |
| GetAppIdByPID | `0x4747c` | `ev_f5bb32363fc0ea0d8d39b6d0c24b61694a9b08879f4448001699f8cb02ced36a` |
| LoadAudioProcUsedDevices | `0x30604` | `ev_4138b7225f13fb0146c89879749922e562b7585788e9eeb01c89e4406972ce72` |
| Directional used-device loader | `0x30738` | `ev_d4b6c4623b50855663655c796f08537ea28f3f1c5a8dbf706d0e899f83632d28` |
| ClientAppInfo conversion | `0x1e6e0` | `ev_0ad18afef78389132af1aba7ff8ef13c94340971fad9cd336ac91f743c580eb6` |
| Changed-list comparison | `0x1efe4` | `ev_0415340b262bdfa78c2434b2ddf10eee860ee92c33e7abd24a97a0426820c764` |
| Client snapshot delivery | `0xe180` | `ev_b508de79db0e127c99cd375b5a26c5d1c6314964e3f2e783872f4bf1e73111ad` |
| N-API Initialize | `0x3148` | `ev_0a4f5eb5b8ab9d0a8b57b22b2c82fd1ce1f9a528cbb15f38c4d6a5f58d80a182` |
| GCDTimer constructor | `0x6cdb8` | `ev_4039010543c34c6bb98ddab74ec7aa73e3fcf3d3e3bb28e6b68f017ade4b1833` |

InitializeNapi validates numeric properties named `startStreamEventsDelayThreshold`, `endStreamEventsDelayThreshold` and `newDeviceInteractionDelayThreshold`. This establishes configuration field names, not their packaged values or all later uses.

## Retained JavaScript policy

The following policy comes from retained sleep/wake static-reader outputs, without another original read. Accepted v7, Evidence `ev_9a7508fc22b011b377509f2f90e73f800b515f82435be264fddd6d2741f8ab3e`, includes AudioService's complete relevant methods. The BootstrapApp member SHA256 is `bbaedd07bcd78d093f1011a41e3aeca92707c1f77fc7cca03305ffd4cd90cff0`.

AudioService.onAudioStreamChange filters to streams on Krisp devices and updates CallService usage state. Stream creation resolves the device, requests microphone access when needed and rechecks that the stream still exists after that asynchronous request. It then adds the stream client to CallService. Non-Krisp speaker capture has a separate app-capture/access gate. This is a stale-stream recheck at the real permission boundary. Graph startup and automatic note-taking remain distinct operations.

Additional complete CallService method excerpts are in v8's raw output. The reader exited 0, retained all 394,093 raw bytes and recorded the same archive SHA256 before and after plus the same member digest. Its outer REA cleanup failed, so it is a caveated static observation with no accepted capture Evidence ID. This lifecycle failure does not establish corruption of the emitted static bytes, but these claims must not be described as runtime acceptance. The offsets below refer to the decoded CallService slice in `evidence/model-probes/sleep-wake-20261028-v8.result.json`.

### Call identity and start

`registerStreamClient`, decoded offset 13,958 onward, trims appName and rejects an empty result. It asks accountService.shouldExcludeClient about appId before registering. It finds an existing call by exact trimmed appName equality, otherwise creates a call with name, version, appId and creation time. It adds device usage by direction. The account-derived ignore policy and local user-blocked names are separate filters.

A call is confirmed when it has both legs, app capture is enabled or it uses the Krisp microphone, and it has not been confirmed already. Local known-app tracking excludes the OS-specific capture-exclusion list and the synthetic in-person app. APP_CALL_CONFIRMED is emitted only if the lowercased app name is neither user-blocked nor currently excluded by the external event source.

`startNextAppCall`, decoded offset 60,028, returns while a current callingAppName exists. Otherwise it cancels a pending restart timer and walks calls in array order. It selects the first call with both legs that is not started and passes startAppCall. There is no foreground-app preference in this method.

`startAppCall` requires app capture enabled or a Krisp microphone. It rejects lowercased names in appCaptureExclusions, persisted BLOCKED_USER_APPS and, depending on mode, the external integration exclusion set. Exclusive external-source mode adds a bridge-active gate. On success it sets callingAppName, starts the call, initializes processing histories and emits APP_CALL_STARTED. Cloud/integration availability must not become an independent local capture gate merely because this original branch uses it.

### User-blocked names and competing calls

`setUserAppState`, decoded offset 26,542, persists lowercased application names in BLOCKED_USER_APPS. It uses exact array membership after lowercasing, not bundle-ID identity or substring matching. Blocking the current app calls stopCurrentCall with start-next true and AppBlock initiator. Unblocking invokes startNextAppCall. It emits USER_APPS_CHANGED and BLOCKED_APP_CHANGED after mutation. getUserApps combines remembered names with their current lowercased blocked membership.

`switchAppCall`, decoded offset 25,651, returns if the requested app is already current, absent, or there is no current call. Otherwise it stops the current call with AppSwitch and start-next false, moves the requested call to the front of the calls array, moves the previous current call to the back and invokes startNextAppCall. The recovered maybeSwitchToKrispDeviceCall body at decoded offset 59,994 is empty. Its name is not evidence of automatic switching.

When a current call loses a stream leg, unregisterStreamClient starts a stop-delay timer unless one already exists. It uses callStopDelayMs plus any app-specific extra delay. Restored two-leg usage can cancel that timer and emit APP_CALL_CHANGED, depending on device identity and elapsed time against callStartDelayMs plus the extra delay. Losing all legs on a non-current call removes it. stopCurrentCall clears current identity, emits APP_CALL_STOPPED for a started call and can select the next eligible call when its start-next argument is true.

During initialization, start/stop delays come from audio config and are clamped to named min/max constants. Start delay is capped at stop delay minus 10 ms. Exact default bounds, extra-delay app map, auto-activation preference defaults and the complete Call/leg object semantics were not present in the retained excerpts inspected.

## Reconstruction boundary

The native process-usage source, responsible-app identity, client payload, two-stage stabilization, local name blocking and current-call selection are now statically evidenced. They support a local observer and policy design. They do not yet establish the full automatic note-taking contract.

The follow-up below closes storage-to-StreamInfo grouping, native-source OS selection and packaged delay defaults, and recovers the APP_CALL_STARTED to ASR/recording event join. Before claiming activation parity, recover Call.hasBothLegs/device-usage semantics, effective clamp constants and extra-delay map, and the remaining meeting-assistant activation policy. Recover the local auto-activation preference, manual one-call choice and concurrent-call UI locking separately. Preserve local note-taking and app exclusion while excluding vendor account/entitlement checks, remote generation and telemetry.

A safe implementation must retain the permission-boundary stream recheck, avoid treating an app launch as a call, distinguish helper actual PIDs from responsible app identity and invalidate old observations after device/policy changes. No source or test implementation is added by this report. No physical or synthetic activation scenario ran.

After evidence export, close_binary was requested once. The global process-capture cleanup condition rejected close with candidates 32300, 35284 and 35285 reporting unreadable ownership environments. No candidate action, retry or repair followed. This does not invalidate the retained static native dossiers, but provider closure is not confirmed. The target may remain selected; recheck session state before another task changes it.

## Storage grouping, source selection and defaults, 2026-10-28

This follow-up closes the earlier storage-to-StreamInfo, source-version gate and packaged delay-default unknowns. The observed addon digest is unchanged. REA session state initially reported no open target, so the addon was explicitly rebound before these static queries.

### Responsible PID and device grouping

AudioProcInfoStorage keeps AudioProcessInfo records keyed by audio-process object ID. `AudioProcInfoChanged` replaces that object's record and compares the normalized input/output device sets against its previous record. It marks modified directions and either notifies immediately or starts its configured storage notification interval. It does not treat every identity-field refresh as a directional stream change.

`GetStreams(inputDirection)` walks stored records that have at least one device in that direction. For each such record, it scans all stored records for the same responsible PID and inserts their actual PIDs into a numeric set. It serializes that sorted, unique set as decimal numbers separated by commas, with no spaces and no leading comma. This is the exact `actualPids` string. The sibling scan does not itself require each sibling record to be currently active in the selected direction.

For every device ID in the selected record's active-direction device set, GetStreams produces a StreamInfo. It converts that CoreAudio device ID to a decimal string. The StreamInfo carries actual and responsible PIDs, the grouped actualPids string, app name, version and responsible app identifier. The later StreamInfo-to-ClientAppInfo conversion selects the responsible PID as the client `pid`. Thus one responsible application can yield multiple per-device stream records and one grouped helper-PID string.

The KrispStreamContainer then deduplicates records by the concatenation of the StreamInfo responsible-app-ID string and device-ID string. This key contains no inserted separator. The map uses unique insertion, so duplicate input records with the same key do not create duplicate clients. Changed-list comparison includes StreamInfo equality, then emits a full current client snapshot. This is a two-level mechanism: actual PIDs are grouped by responsible PID, while the published client map keys app identity plus device. Do not replace it with grouping only by display name or only by actual PID.

`NotifyChangesIfAny` regenerates streams independently for each modified direction and emits native device type 0 for input and 1 for output. It clears each modified flag after dispatch. Native callback payload conversion and exact string fields are already established above.

Relevant new dossiers:

| Function | Address | Evidence |
| --- | --- | --- |
| AudioProcInfoStorage.GetStreams | `0x5d5bc` | `ev_41f5318555259bf2b645ad53a8f5c551c1be056417beb209890cd89ac06da78c` |
| AudioProcInfoChanged | `0x5cb7c` | `ev_bbf6e4fcf6991009e85c432c2eefeef14502968e950fcbe1113ea9b04aa47755` |
| NotifyChangesIfAny | `0x5c958` | `ev_36e67c4c3c7849971aac09043e4497d4aa2b5f4164be0bc18d3a1b4efbbea72b` |

The prior changed-list and conversion dossiers complete this join. Type propagation warnings remain in the decompiler output. Field meanings here are tied to the earlier identity loader, layout copies and N-API field serializer, rather than inferred only from variable names.

### Native source version gate and failure behavior

`IsAudioProcessTrackingAvailable` calls `__isPlatformVersionAtLeast(1, 14, 4, 0)`. The selected native source therefore uses the audio-process path on macOS 14.4 and later. This is the original's own gate, not an inference from SDK API availability.

CreateAudioService creates the CA and Krisp handlers in either case. It creates an AudioProcessContainer only when that version gate passes, then passes the optional container into EventHandler. EventHandler.StartMonitor registers audio-process callbacks when the container is present; when absent, it registers the older CA and Krisp stream callbacks. It still registers the non-stream device/state callbacks in the process-container branch.

This is version-selected fallback. It is not evidence that an initialization error in the selected process source silently falls back. EventHandler.Initialize returns a nonzero process-container initialization error instead of removing that container and switching source. A process-container factory error follows a service-creation failure branch. The independent implementation must keep unsupported-source and failed-source states distinct.

| Function | Address | Evidence |
| --- | --- | --- |
| IsAudioProcessTrackingAvailable | `0x47818` | `ev_9fd96cf933b3a7125357596810acc9087b6d5ecc71bd6fe310025fa830363c7c` |
| CreateAudioService | `0x2691c` | `ev_2d095a7c7294a391608fd5249aa7106bd1490de0f5fdbb2577cde1699e9cbcca` |
| EventHandler.Initialize | `0x4a67c` | `ev_f1f8e58fe5b1df55d574acb9a4b0c92f6a58f5e9244825316c7b9c7cb79a00b9` |
| EventHandler.StartMonitor | `0x4a9e4` | `ev_dc85f32438dda2385e2693abfee3a52c8377573df852c0c7f63e55bbad0ba267` |
| RegisterAudioProcessEvents | `0x4af60` | `ev_8024de28173ccbb78380a31cd1dd8c798420c853e354b9eaf9ca0c6ef7b1dab5` |
| RegisterStreamEvents | `0x4b078` | `ev_c0c687ced8052b70ca663e6ba408fd0367780013226e2f20d737a4eeea47dcee` |

The complete older-source callback registration, app attribution and removal behavior remain incomplete. Full activation on macOS 12 through 14.3 therefore still needs that separate source contract.

### Packaged delay defaults recovered from retained evidence

No new original read was needed for these values. Retained accepted static reader Evidence `ev_f5ab7c72b42ff4a4d14cb47d3bf91893363610cf6acf2c89937c3802d073a6cf`, in `speaker-graph-config-processors-20261018-v1.result.json`, contains the SentryManagerMain default configuration around raw member character offsets 120,172 and 120,198. It pins member SHA256 `cf21e7e4fa19deb6f960223a883fe8831f25d66ba68d15e127731de5aead8579` and the unchanged ASAR digest before/after. The reader exited 0 with verified owned-group cleanup, removed its temporary root and retained all 70,167 raw bytes. A second retained capture, `ev_1953b11976e37a492f97468487890af71345e9f07220ec36772b095dab209764`, contains the same defaults.

| Configuration | Windows | macOS | Linux |
| --- | --- | --- | --- |
| startStreamEventsDelayThreshold | 250 ms | 250 ms | 250 ms |
| endStreamEventsDelayThreshold | 1,200 ms | 1,200 ms | 1,000 ms |
| newDeviceInteractionDelayThreshold | 0 ms | 1,000 ms | 0 ms |

The common audio defaults are `appCallStartDelayMs: 500` and `appCallStopDelayMs: 1000`. These are packaged defaults. They do not establish effective values after account/config overrides or identify the still-unrecovered min/max clamp constants and app-specific extra-delay map.

Retained `bvc-mic-default-20261025.result.json`, Evidence `ev_56863d4bf5c4fb6368bf35daad401a9def860da402711c0297391e5cf39b40b7`, contains the platform-selection helper: on macOS it copies the mac start/end/new-device thresholds into the device-manager configuration. The snippet includes direct macOS branch and end-threshold access; some adjacent decoded aliases remain unresolved, so this is used with the exact N-API configuration keys and literal default object rather than claimed as a fully decoded helper.

The Call.hasBothLegs and Call.addDeviceUsage bodies are still absent from the retained excerpts searched. Known CallService policy and accepted AudioService Krisp-device filtering must remain in the reconstruction contract. A name such as hasBothLegs alone does not establish whether the call requires matching process/device identities, which leg takes precedence, or how bridge metadata changes those legs. No replacement leg semantics are invented here.

New dossiers are exported in `evidence/model-probes/activation-grouping-20261028.bundle.json`, 11,818,980 bytes and 14 records. A single close request after export again failed on global process-capture cleanup, listing candidates 32300, 36132 and 36133. No retry, signal or repair followed. All new conclusions are static and carry the installed native digest above. No code or runtime activation changed.


## Retained-evidence follow-up: ordering and recording activation

No new original read or capture was performed. These observations reuse the installed artifact pins above.

### Exact normalization order

Accepted `activation-normalize-devices-20261028.result.json`, Evidence `ev_f07f82b4714fe8bd12e93e6841107aa80ece6b799414b9760c7b5df967cb6599`, function `0x613e0`, has two passes over ascending unsigned input device IDs. First remove devices whose input-stream query returns an empty collection. Stop this pass once fewer than two inputs remain. Then reset to the beginning and remove input devices also present in the output set, again stopping once fewer than two inputs remain. These predicates must not be combined into one pass.

The assembly size checks are `0x61460-0x61468` and `0x615ac-0x615b4`. The first stream getter is `0x61480-0x61494`, with its zero branch at `0x614a4` leading to removal at `0x614d8`. `0x61564` reloads the beginning for the second pass. Its unsigned output-tree lookup is `0x615c0-0x615f0`; matched removal starts at `0x61624`. For inputs `{1: has input streams and overlaps output, 2: no input streams}` and output `{1}`, the first pass removes 2 and leaves singleton 1. The second pass stops immediately. A combined OR predicate would instead remove 1 first and retain 2.

### Stream iteration and tie scope

Retained storage-change and GetStreams dossiers show actual tree operations. Storage insertion compares unsigned CoreAudio object IDs. GetStreams (`0x5d5bc`, Evidence `ev_41f5318555259bf2b645ad53a8f5c551c1be056417beb209890cd89ac06da78c`) starts at the stored begin pointer, advances by right-subtree minimum or parent ascent, and appends StreamInfo objects to the output vector. It visits records in ascending object ID, then their directional device sets in ascending device ID. This follows the comparator plus successor code, not the container name alone. The retained changed-list dossier (`activation-client-update-20261028.result.json`, function `0x1efe4`, Evidence `ev_0415340b262bdfa78c2434b2ddf10eee860ee92c33e7abd24a97a0426820c764`) closes the later tie rule: it rebuilds the client map, walks the source vector forward, and calls `__emplace_unique_key_args` with the concatenated responsibleAppId+deviceId key and shared StreamInfo. It does not overwrite an existing key. The first candidate therefore survives, which selects the lowest object-ID producer for a duplicate key. Distinct keys are later delivered in client-map key order.

### APP_CALL_STARTED to recorder

Retained partial v8 (`sleep-wake-20261028-v8.result.json`) contains the complete relevant AsrService excerpt, query `@decode:let AsrService=class:150000`, raw member start 3,634,562. Its reader exited 0 and pinned unchanged ASAR/member bytes, but REA cleanup failed. It is bounded static observation, not an accepted clean capture. The archive SHA is `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`; BootstrapApp member SHA is `bbaedd07bcd78d093f1011a41e3aeca92707c1f77fc7cca03305ffd4cd90cff0`.

AsrService subscribes to APP_CALL_STARTED, APP_CALL_CHANGED and APP_CALL_STOPPED. `onAppCallStarted` (decoded excerpt offset 53,340) checks initialized state and original account call-app policy, captures call profile flags, invokes speaker-leg start, then invokes asynchronous microphone-leg start with an error handler. The account policy is a vendor dependency to separate from retained local behavior.

Microphone start checks processing readiness and duplicate call ID. If processing already exists, it associates the additional call with the existing transcript's parallel-call list. Otherwise it creates the ASR stream and calls startASRProcessing when the original configuration permits. startASRProcessing (decoded offset 73,498) admits RecordAndTranscript, TranscriptOnly or ScreenRecord modes; it postpones other modes with a 1-second timer. It starts configured local/remote processing, checks success, and rechecks `usageEndedAt` after asynchronous startup. If that call ended and no suitable live call can take over, it removes the stream and stops processing. Successful admission sets call state processing. When call-transcript configuration is available, it emits CALL_TRANSCRIPTION_STATE_CHANGED Started and CoreEvents.RECORDING_CALL_STARTED with the transcript-call object. This is an event join after processing admission, not evidence that every detected call immediately starts a recording.

Accepted v7 Evidence `ev_9a7508fc22b011b377509f2f90e73f800b515f82435be264fddd6d2741f8ab3e` supplies AudioRecordingService, query `@decode:let AudioRecordingService=class:100000`, raw member start 5,309,675, with the same ASAR/member pins. Its event map binds RECORDING_CALL_STARTED to onAudioRecordingCallStarted (decoded offset 24,270). That handler prepares ordinary/background records and invokes their start functions through Promise.all with a catch handler; it does not await completion before returning.

Ordinary preparation (decoded offset 19,009) checks meeting-assistant isRecordingAllowed, directory creation and model availability. It keys records by asrStreamId, suppresses duplicates except Initializing and an approved WaitingForConsent record, and records original usageStartedAt. It can publish WaitingForConsent according to consentApproved and original recordWithoutConsent preset. startCallRecord (decoded offset 12,104) checks RecordAndTranscript or ScreenRecord mode; other modes emit WaitingForRecordingStart. On native startAudioRecording NoError it marks Started, opens a session and emits Started before awaiting upload-record creation. It requests mono MP3 and the selected bitrate. Background preparation/start is a separate account-configured transcription/recovery path. Commercial availability and remote upload are not requirements for the independent local writer.

This closes the direct call-to-ASR-to-recorder event connection. It does not recover the complete meeting-assistant auto/manual preference policy, prove writer finalization on suspend, or resolve Call.hasBothLegs/addDeviceUsage.

### Remaining static access limit

The retained application graph (`ev_7db961a418a25cdf13782fde221628e96275f062eca583f00b0eba3bfb1bddf2`) contains no hasBothLegs or addDeviceUsage property facts. BootstrapApp parsing completed, but semantic extraction exhausted its 1 GiB heap. Generic module views expose identity/ranges and retained semantic tracing cannot recover facts absent from that graph. The retained CallService excerpt contains callers of these methods, not their definitions. Min/max delay constants and app-extra-delay values likewise remain outside its captured range. Repeating the same huge partial graph or a rejected process capture is not a new evidence path. The next required capability is a supported bounded static member/source read around those definitions or a narrowed semantic extractor that can analyze that member without the exhausted whole-module pass. No such new original query was executed here.


Recording-join scope clarification: original account call-app permission, FeatureAvailability, meeting-recording availability, configured remote transcription and background-recording availability are vendor policy inputs. The retained local mechanics are call identity, mode/readiness checks, asynchronous startup, stale-call rejection, local processing and writer state changes. They do not establish that Apple Speech has the original processor's completion or error semantics.

In the same retained AsrService excerpt (decoded offsets 75,800-80,100), local startup awaits audioService.startASRProcessing and accepts only MediaSPErr.NoError or AlreadyCreated, with the local-enabled flag also required. If processingStarted() is false, it marks both call and service error and removes the stream map entry. MemoryAllocationFailed additionally emits retryLoadError. That branch has no recorder-start event and no explicit local stop call in the observed block. A thrown startup error marks service error, clears local/remote/diarization flags and removes the stream map entry. This is not evidence of successful cleanup after a failed native start.

After successful startup, a call that ended during the await may transfer to another ready, unended transcript call. Without a replacement, it removes the stream, invokes local stopASRProcessing(streamId, true), releases/flushed-stops remote processing when present, resets processing flags and returns before recorder-start admission. The stop call is not awaited in that stale-start branch. Recorder admission and recording publication therefore remain distinct from ASR startup success.


### Changed-resource analysis attempt

A later schema check exposed max_heap_mb, so the earlier access-limit conclusion was tested with a supported changed resource budget. Read-only host checks reported 16 GiB physical RAM and 47% system-wide available memory; REA reported no open target and no observed active provider analysis. One static analyze_javascript_application request used the same pinned ASAR, summary detail, record-and-continue, max_heap_mb 2048 and analysis_timeout_ms 120000. It did not execute application code.

The resulting parent Evidence is `ev_9a04cdcd2661f996e180422aa68080f3ee315c1a1285383f22260aa0253026db`; summary view is `ev_7ec29c5a7845db78bf3252ea28bef463093cb8a04a80f36106d3127dc6d0ec37`. The observed archive digest remained unchanged. It parsed 19 JavaScript files with zero parse failures and visited 3,984,680 AST nodes. BootstrapApp still exhausted its heap during semantic extraction. The reported worker heap limit was 2,172,649,472 bytes. The summary also reports semantic heap failures in other members and a parent remaining-result-budget limit for SentryManagerMain. The analysis therefore remains partial, with 4,293 semantic unknowns and 10 application unknowns.

A focused property hasBothLegs callers trace against the new parent (`ev_ac371f76731331724d5b531b68e7fc09570edb86783adba472c3d48e6ed69699`) returned partial coverage and zero seed matches. This bounds the available graph, not the original application's behavior. The new three-record evidence bundle is `evidence/model-probes/activation-js-heap2048-20261028.bundle.json`, 27,898,204 bytes. No additional heap increase, process capture retry or provider repair followed. Missing Call method definitions and effective clamp values remain unresolved after the larger supported heap attempt.

## Exact native timing contract, 2026-10-28

This follow-up reuses the retained listener/tracker/init/change dossiers and adds focused REA native analysis. The selected ARM64 addon digest remains `ef833e13e87064f51cbb547295b1c65138871906bcae651160b0daeeb3fcb3e6`; the different archive-declared addon digest above still applies. No original application or addon code ran. The new native evidence is exported in `evidence/model-probes/activation-timing-20261028.bundle.json`, 30,300,336 bytes and 18 records.

### Three distinct timing stages

| Stage | Configured threshold in the observed process source | Poll interval | Due comparison |
| --- | --- | --- | --- |
| Per-process property listener | 200 ms | 20 ms | elapsed >= 200 |
| Normalized per-process tracker | packaged macOS start 250 ms, end 1,200 ms | 20 ms | now > firstPending + selected delay |
| Shared storage notification batch | 100 ms | 20 ms at this setting | elapsed >= 100 |

The container constructor writes four little-endian 32-bit values at offsets `0xa8..0xb7`: 200, 100, 300, 1000. REA read of `0xea880` returned exact bytes `c8000000640000002c010000e8030000` (`ev_ed76f1ba22b6a52ca0f55ea020f975029d678f3d439f5e8436400d83eb11a2bd`). Constructor assembly at `0x59708..0x59710` loads that vector and writes it to the container. Initialize passes `0xa8` to the listener and `0xac` to storage. It replaces only the tracker start/end fields `0xb0/0xb4` from the supplied configuration. The packaged macOS 250/1200 defaults therefore override constructor-only 300/1000 tracker values. The separately named `newDeviceInteractionDelayThreshold` default 1000 is not an extra stage in this process-source initialization path.

The GCD timer constructor multiplies its double argument by 1,000,000 for both dispatch start and interval, and sets leeway to 100,000 ns. Thus the supplied 20.0 is 20 ms, not the listener's pending threshold. Dispatch scheduling, queue contention, timer phase and whole-millisecond truncation mean these are polling conditions, not proof of a fixed 550 ms end-to-end delay or a hard wall-clock upper bound.

### Listener coalescing

HandleAudioProcEvent uses the process object ID to find its registration and sets its pending timestamp only when the previous timestamp is zero. Additional property callbacks while pending do not reset it. On each timer tick the listener checks nonzero timestamp and `threshold <= nowMilliseconds - firstTimestamp`, clears the timestamp before invoking the stored process callback, and leaves subsequent events to establish a new pending window. This first stage does not compare device sets. A transient property change that reverts within its window still causes a later read, which the tracker can then discard as unchanged.

### Tracker state and end selection

`UsedDevices.HasStream(true)` returns input-set count != 0; false selects output-set count != 0. Its exact body is at `0x20d18`, including the observed offsets `0x10` and `0x28`. The end threshold applies if either direction is nonempty in the published state and empty in the pending state. Removing one device while that direction retains another device does not select end. Switching `{deviceA}` to `{deviceB}` within one direction uses start, as does adding devices or changing a nonempty direction without emptying it. If one direction empties while the other gains devices, end takes precedence.

After the listener callback, HandleUsedDevicesChange reads and normalizes current device sets. A change away from published state creates a pending cache and records the first pending time. Later different pending device sets replace that cache's sets without changing its first timestamp. A repeated identical pending state is a no-op. Returning to the published state clears the pending cache and pauses its timer. Each tracker tick recomputes start versus end from the current pending and published sets, so changing pending content can change the selected threshold without restarting the first timestamp. Publication uses strict `pendingFirst + threshold < nowMilliseconds`, copies pending sets to published, emits a copied AudioProcessInfo, clears pending and pauses the timer.

A tracker property callback reloads used devices, not application identity metadata. Identity is loaded during tracker initialization. Storage does replace a supplied record, but its dirty flags compare only the input/output device sets. Metadata-only replacement therefore does not itself schedule client notification. An inactive sibling's arrival/removal can also change the potential actualPids group without marking a direction dirty, so that metadata can become visible only incidentally with a later directional notification. The independent diagnostic carrier must distinguish this callback contract from its richer raw process inventory.

### Initial state and disappearance

Tracker initialization loads metadata and used devices directly into published AudioProcessInfo, starts the process listener, then normalizes the published input sets. It does not manufacture a pending start transition. GetProcessInfo returns a copy of that published object. The container's new-object path calls GetProcessInfo and storage.AudioProcInfoChanged immediately after tracker creation. Initial/new-process active usage thus bypasses both the 200 ms property coalescer and the tracker start delay. It still enters the shared storage batch. A fully inactive new record is stored but does not by itself dirty either directional callback.

A successful process-list reconciliation calls storage.AudioProcessRemoved for a missing object before retiring its tracker. Removal erases the storage record immediately. It sets input/output dirty bits only for directions that were nonempty in that removed record, and enters the same storage batch. Actual process disappearance does not wait the 1,200 ms per-process end delay. It also discards that tracker's pending state with the tracker. A failed system process-list read is not an authoritative empty membership list and does not justify disappearance.

There is a separate failure-policy distinction: the retained original HandleUsedDevicesChange logs a used-device read failure but continues to normalize its default or partially loaded local sets. It does not return at that error branch. The independent observer's unknown-read policy must remain explicit as a safety divergence. A failed or unknown read must not invent an empty direction or complete a pending absence publication.

### Storage batching

Storage marks input/output dirty bits using OR, so multiple changes during a batch accumulate. The first dirty change resumes its timer and records now only if its batch timestamp was zero. Later changes preserve that first time. At a timer tick, notification occurs when elapsed >= the configured storage interval. Notification builds the current input list first, then current output list, for their respective dirty bits. It clears each sent bit, clears the timestamp, and pauses the timer. This is a fixed first-change batch window, not a trailing quiet-period debounce.

Storage interval zero means no timer and immediate notification. A positive interval below 20 is raised to 20. Its general poll period is max(20, integer interval/10); the observed 100 ms interval therefore polls every 20 ms. The minimum constant at `0xeafe4` is exact bytes `14000000`, Evidence `ev_af44fbe45bb511c965e93e15996385eabfd78c37cb19968cffd3d1b3008b19ba`.

### CoreAudio restart is a separate retained branch

The restart block clears storage, destroys the tracker map, calls ForceNotifyChanges(1000), waits two seconds, then reloads the process list unless the container has been destroyed. Clear cancels pending storage flags/time. ForceNotify sets both directional flags and, with a timer, stores `existingFirstOrNow + 1000`; the normal storage comparator still adds the 100 ms interval. Its empty notification is therefore eligible after approximately 1,100 ms plus polling/scheduling, while the reload happens after the separate two-second wait. This is static behavior, not an executed system restart. The independent generation reset already prevents stale results; reproducing the original timed restart sequence needs its own explicit implementation and synthetic acceptance rather than being silently folded into ordinary start/end stabilization.

### Evidence joins

| Observation | Address | Evidence |
| --- | --- | --- |
| Container constructor and fixed listener/storage defaults | `0x5965c` | `ev_d4eef57bc6d8134bcc1e580c335efe0013ca522f93fb14830a986aa505a11ef9` |
| UsedDevices.HasStream | `0x20d18` | `ev_df02b2ca549aad9ffcf42ffa6ae9af3a3f52fc85ce944b9371029432e89ebcac` |
| Storage constructor, minimum and poll period | `0x5c6c4` | `ev_f7656dd5bf1524e9f26620640009bffe8d98768327aadf8c2157bdeb85f5bcf6` |
| Storage tick comparator | `0x5c8cc` | `ev_45133b47f513808e15901b904d661c5259ca435b67be1ed0fcb77e30d6715640` |
| Storage process removal | `0x5d27c` | `ev_eb55f04feb8f769848a6c5feab2ff50037f25a815586d48ab93930dd9b0971e0` |
| Tracker GetProcessInfo copy | `0x612e8` | `ev_4543e40cbeb89a5d126cb9762182957ef33a1ab4b7c63ec63b5a24b6e6c06136` |
| GCD timer units/start/interval/leeway | `0x6cdb8` | `ev_4039010543c34c6bb98ddab74ec7aa73e3fcf3d3e3bb28e6b68f017ade4b1833` |
| CoreAudio restart block | `0x5b340` | `ev_38cc02c453e14b6ef7a6af4a5e2cd5c2094cab207a9234328f097b175fd7334d` |
| Storage force-notify | `0x5d520` | `ev_b327cf80e127ccc41d56aca483e119d21a4eb4eba9d325d8a562534c8350ffc9` |
| Storage clear | `0x5de88` | `ev_b08005519fbfb7b865a7bb7a08c6588296e0f0d8e25c03b4f90caa3da87b0dfa` |

Existing accepted listener timer `ev_6c816574348037ed14c1b51ef045d09ab2c4cca0c9a3bd6cff084fd7ee5fd6e7`, tracker timer `ev_631f9e92407633e80e6a0b171b86f976628bfab118f0407e862fb78df359a6db`, tracker initialization `ev_e20c4eba7adbfafb843386e9680f5891394ac933cddc98db2532bc95e9c39567` and process-list change `ev_b4dbf406cfb5d2ffac88aee25fad7f89dad6282b6dc7cfb66692c4a318961bf8` complete these joins.

One close request after export again returned cleanup_incomplete for global process-capture ownership checks, listing live candidates 32300, 45346, 45348 and 45349 as environment_unavailable. No retry, process signal, capture or repair followed. Provider closure is not claimed. These retained static dossiers remain pinned to the observed addon digest.

### Error-path precision and independent implementation boundary

Retained `LoadAudioProcUsedDevices` (`0x30604`, `ev_4138b7225f13fb0146c89879749922e562b7585788e9eeb01c89e4406972ce72`) checks object/class, then loads input first. A false input result prevents the output loader call. Output runs only after input succeeds. The directional helper (`0x30738`, `ev_d4b6c4623b50855663655c796f08537ea28f3f1c5a8dbf706d0e899f83632d28`) clears its destination set before checking the running property. A missing running property returns false with an empty destination. A false running value returns success with an empty destination. A true running value requires the scoped device-list property; a missing list returns false after that direction was cleared. Thus explicit false branches can leave both sets empty, or successfully loaded input plus empty output. The caller's logged failure branch still proceeds to normalization/cache comparison. Native CAHAL GetPropertyData/GetPropertyDataSize exception behavior and all exceptional unwind paths were not recovered in this timing task. No claim covers every original OSStatus failure.

The independent stabilized mode therefore records its unknown-read policy as a parity gap: it preserves settled usage, marks held usage stale, cancels only the affected candidate (or all candidates for a failed system-list observation), and requires a valid read before freshness resumes. It does not emulate original default/partial false-return sets as observed emptiness. Settled tracker state and last storage-created publication state remain separate: interrupted batches retain directional provenance, and final valid sets are compared against the last storage-created valid sets before a recovery publication. It does not roll back legitimately settled but unreported tracker history merely because a later raw read differs.

The implementation uses one deterministic native serial queue and a 20 ms source timer. Due listener rows are the only existing-process rows admitted from a bulk read. Its deterministic processing order is listener sampling, tracker promotion, then storage flushing. Original listener/tracker/storage dispatch timers use separate global-queue callbacks and locks; the exact winner of a same-millisecond lock race is not claimed. Bounded transport can coalesce full diagnostic frames while retaining directional invalidations for coalesced available frames. Initial all-idle readiness, immediate restart warning and richer raw diagnostics are labeled carrier events rather than invented native directional callbacks.

The wire exposes `coalesced_publications` whenever the bounded latest-publication slot replaces unsent producer frames. Same-generation available frames retain the union of directional invalidations; failure and generation replacement retain the loss count without joining incompatible directional data. The storage-created comparison map is not an acknowledgment from a wire consumer. A complete current snapshot and a gap count therefore do not prove that every distinct timed transition was delivered. Pure tests cover unsent active-to-empty changed transitions, failure/generation boundaries, and taking the slot before a new publication.

## Call objects, local defaults and timers, 2026-10-29

The previously retained CLI captures were recovered and checked. `call-source-cli-20261028-v1.result.json` has accepted Evidence `ev_2cf465b82ea433b7ae76df9607d53bb649984ab26c63a903ccc0c67074e6e78b`. V2 has accepted Evidence `ev_10b206da213ad74b319d3909864b0cfdbcd1bdb3ac8f37f2e209b670f98be415`. Both execute only the authored static ASAR reader under a network-denying sandbox. Original application code does not execute. Their raw terminal frames retain the output; the truncation flag concerns cumulative rendered terminal frames. V2 retains all 148,701 raw bytes. Before/after archive digests remain `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`, with BootstrapApp member digest `bbaedd07bcd78d093f1011a41e3aeca92707c1f77fc7cca03305ffd4cd90cff0`.

A focused static follow-up, Evidence `ev_a1f28157d423fe9c5880b5f8a26c885a884d294966630784e17d339552a776d9`, closes constructor defaults and clamp expressions. Its private result is `call-source-cli-20261029-v3.result.json`. That file contains REA's TOON output despite the suffix. The process exited zero with verified cleanup. No audio, application launch, network or administrator action occurred.

### Directional call state

`Call` initializes empty microphone/speaker usage and history arrays. Last-active device/process fields start undefined. Capture modes start as DEVICE for microphone and APPLICATION for speaker on macOS. It creates a UUID and retains app name, version, app ID and creation time passed by CallFactory. `hasBothLegs` means both directional usage arrays are nonempty. `hasNoLegs` means both are empty. Active app/device information is the first element for that direction; `hasKrispDeviceUsage` checks any element.

`deviceUsageIndex` matches exact PID and appInfo.deviceId within the specified direction. `addDeviceUsage` inserts only when this identity is absent. It prepends if the direction is microphone and app calls are enabled, or if the device is Krisp. Otherwise it appends. Before prepending to a nonempty array it saves the former first element's PID, actualPids, device ID and isKrisp state as last-active values. A duplicate does not replace stored usage. Device history still appends if it has no element whose id equals appInfo.deviceId. Removal uses the same identity. Removing the first element saves the removed identity and isKrisp state, rather than the new first element.

`confirm` sets confirmedAt. `isStarted` requires startedAt with no stoppedAt. `stop` clears confirmation and sets stoppedAt. A stopped Call that still has legs stays in the calls array and becomes eligible for selection. Starting it again creates a new UUID, sets createdAt to the previous stoppedAt, clears stoppedAt and resets processing counters. This is a new call session on an existing object.

### Preference and event scope

The UserChoices alias `_Ha` maps to APP_CALLS_SETTING_STATE and defaults to true. BLOCKED_USER_APPS defaults to an empty array. MEETING_ASSISTANT_MODE and LAST_MEETING_ASSISTANT_MODE default to RecordAndTranscript. These are packaged defaults, not observations of the installed user's effective settings.

CallService.appCallsEnabled starts false before initialization. `updateAppCallsEnabled` combines the stored local choice with app_capture_mode not being false, then accepts an explicit captureStreamEnabled config override. It combines that result with OS, driverless preset and account availability. Account/preset policy is part of the original implementation; it must not become a new local account dependency in OpenKrisp.

The MeetingAssistantViewModel `onAppCallConfirmed` method only appends the confirmed call and opens JOIN_NEW_MEETING if an in-person meeting is active. This handler alone does not start recording or transcription. The ParallelCallDetectedAddon separately tracks confirmed/started calls and notifies when a call is already started and assistant mode is not Off. Full effective note-taking mode transitions remain a separate contract.

### Exact delay behavior

| Delay | Packaged default | Clamp or adjustment |
| --- | --- | --- |
| Stop | 1000 ms | 100 through 3000 ms |
| Start classification | 500 ms | 50 through 2500 ms, then at most stop delay minus 10 ms |
| Explicit restart | 1000 ms | No clamp recovered in this constructor path |
| Safari extra delay | 300 ms | Added to stop delay and restored-leg classification threshold |

There is no initial start-delay timer in `startNextAppCall`. It selects immediately from array order when no current identity exists. The start delay classifies a restored leg while a stop timer was pending. Registering a restored current call with both legs cancels that timer, then computes floor of elapsed milliseconds. With app capture enabled, it emits APP_CALL_CHANGED and returns if the last-active device differs from the new device, or elapsed is strictly less than start delay plus app extra delay. Otherwise it stops with start-next false and resumes normal selection. Equality takes the stop/reselect branch when device identity is unchanged.

Removing a usage from the current call emits APP_CALL_CHANGED if both legs remain and app calls are enabled. With app calls disabled, it emits that event only if the active microphone is Krisp; otherwise it stops with start-next true. Losing a leg starts one stop timer at stop delay plus app extra delay. Additional removals do not reset it. A non-current call is removed only when it has no legs.

`stopCurrentCall(startNext=true, initiator)` disposes the stop timer first. It stops a started call, emits stop, removes it only if no legs remain, clears current identity, then selects another call if startNext is true. `restartCurrentCall` stops with start-next false, schedules the 1000 ms restart callback, and that callback clears the restart timer then invokes startNextAppCall. startNextAppCall also cancels a pending restart timer before scanning eligible calls.

AudioService's retained snapshot handler updates Krisp-filtered in-use accounting. Call registration/removal comes through separate created/removed stream handlers. Therefore a reconstruction's full-snapshot remove-before-add order is not established by this AudioService handler alone. DeviceManager's complete event-diff order remains unresolved.

### Application version metadata

REA Evidence `ev_9302e74f5a6b02fb7f69dd32816ff6e3efd0c7ec304535f66595e1a74e3089db` inspects GetApplicationVersionByPID at `0x47140` in the same observed addon digest. Its complete dossier is retained in `activation-app-version-20261029.result.json`. The earlier LoadAudioProcInfo callsite supplies the responsible PID.

The helper obtains NSRunningApplication for that PID, takes its bundleURL and appends `Contents/Info.plist`. It loads that URL as an NSDictionary. It first reads CFBundleShortVersionString, accepts an NSString with a non-null UTF8 pointer, and returns its bytes. An empty NSString is accepted and does not trigger fallback. An absent value, wrong type or null pointer falls back to CFBundleVersion with the same checks. A missing application, bundle URL or dictionary, or two invalid values, yields an empty string. This is static decompiler and assembly evidence, not live metadata observation.

The initial guessed native symbol was rejected and corrected to the provider-returned address. No capture cleanup retry, owner signalling or provider repair occurred. The addon remains selected after this focused query because the earlier global capture-owner condition makes closure unconfirmed.

## DeviceManager event ordering and note-taker joins, 2026-10-29

Focused static-reader captures V4 through V7 retain the same archive and BootstrapApp digests stated above. Accepted Evidence IDs are `ev_48fb9b49e0cf39105781dddc94421bc8f733e7723df07ac5b896009992e06d6e`, `ev_1c87a2bd633937074c5206bb6aa49f51dddb8e80f003fff312c29b04d7808fe9`, `ev_d7400aae6c4076376c5724c401845013335e93f66c7c6dfbc545edbcabe22b00` and `ev_cede3aa6eaeab45c330ef70715aa3e55713802486f10b406ee91af29677050b6`. Results are private `call-source-cli-20261029-v{4,5,6,7}.result.json` files. All exited zero with verified owned-group cleanup and removed temporary roots. V6 retained all 81,682 raw output bytes. Platform binaries with withheld ownership environments remain listed as unverified observations in some cleanup reports. No owner action or repair followed. These are static text observations, not original app execution.

### Exact directional stream diff

V4 recovers `equalStreams`: exact equality of appId, deviceId, type and PID. This differs from Call.deviceUsageIndex, which uses direction, PID and device ID. App name, version and actualPids are not stream-diff identity fields.

V5 recovers the complete relevant DeviceManager methods. `onAudioStreamClientsListChange` partitions each native directional client list by whether deviceId exists in that direction's device map. Unknown-device rows go into streamsWithoutDevices and do not enter the inner diff. The inner method assigns each client its direction and a createdAt value from an existing appId match, otherwise the current time. It retains the unfiltered known-device list in allStreams. It then excludes clients whose PID occurs in krispProcessManager.getProcessIds(). This check reads the client's PID, not its actualPids string.

It sorts the remaining incoming array in place with `a.sort((l,u)=>l.appId.localeCompare(u.appId))`, with no locale or options argument. It separately sorts a copy of current streams by the same key for aggregate arraysAreEqual comparison. Stable ties preserve incoming order. It then runs these operations, in this exact order:

1. `onAddNewStream(direction, incoming)`. Walk the sorted incoming array. If no current equalStreams identity exists, append that object to the retained directional stream array, then invoke onAudioStreamCreatedCB with direction and object.
2. `onRemoveOldStreams(direction, incoming)`. Walk the retained directional stream array from its last index down to zero. If incoming has no equalStreams identity, remove the object, then invoke onAudioStreamRemovedCB with direction and removed object.
3. If the sorted aggregate arrays differed, invoke onAudioStreamChangeCB with direction and the resulting retained stream array. Then check availability and dump state.

This closes the earlier add/remove-order unknown. The original adds before removing, and removal callbacks run in reverse retained order. It has separate outbound/microphone and inbound/speaker arrays. It does not replace an existing stream object on metadata-only changes that preserve equalStreams identity. The aggregate callback can still report a difference. The asynchronous microphone permission wait in AudioService can delay call registration after a created callback, so DeviceManager callback order does not prove that every asynchronous Call mutation finishes in that order.

### Note-taker choice and lifecycle

V4 recovers `changeMeetingAssistantMode`. It persists MEETING_ASSISTANT_MODE, sets the view mode and sends MEETING_ASSISTANT_MODE_CHANGED. Selecting TranscriptOnly, RecordAndTranscript or ScreenRecord enters the active-mode path. Transitioning from Off sends TOGGLE_MEETING_NOTES with state true and ASR_TURN_ON_TRANSCRIPTION. Selecting Off sends TOGGLE_MEETING_NOTES with state false. When transcription is already active, TranscriptOnly stops recording modes, RecordAndTranscript starts/resumes audio recording and stops screen recording, and ScreenRecord starts both. Mode selection does not itself create a detected Call.

V7 recovers the view's transient states. Persisted Saving or Stopped is sanitized to RecordAndTranscript during construction. MEETING_SAVING changes one of the three active modes to Saving. Transcription-turned-off changes Saving to Stopped. Transcription-turned-on restores lastProcessingMode only from Stopped. A matching transcription Stopped event clears call identity, start time and pause state. A stale call-ID stop does not clear the active transcription identity. CHANGE_NOTE_TAKER_STATE Paused toggles pause only when currently unpaused; Started/Resumed toggles only when paused; Stopped calls onStopInPersonMeeting. Available-mode selection rejects changes in Saving/Stopped.

The retained AsrService V8 static output, with the cleanup caveat recorded earlier, connects APP_CALL_STARTED to speaker bookkeeping followed by asynchronous microphone processing. It rejects calls under the original app policy and requires readyForProcessing. That readiness excludes disabled, downloading, initializing, loadingModels and error states. `startASRProcessing` admits only TranscriptOnly, RecordAndTranscript and ScreenRecord; another mode schedules/re-schedules a 1000 ms retry. On successful processing it emits CALL_TRANSCRIPTION_STATE_CHANGED Started and sends RECORDING_CALL_STARTED with the transcript-call object. APP_CALL_STOPPED awaits microphone stop, then performs speaker stop. RECORDING_CALL_STOPPED carries the ASR stream identity. Original account, remote ASR and generation policy remain excluded reconstruction dependencies.

V6 independently recovers AudioRecordingService's receiving contract. Its core event table handles RECORDING_CALL_STARTED and RECORDING_CALL_STOPPED, rather than subscribing to APP_CALL_STARTED. Recording entries are keyed by asrStreamId. The start handler prepares foreground/background entries and invokes their starts. `startCallRecord` accepts only RecordAndTranscript or ScreenRecord; otherwise it emits WaitingForRecordingStart. `startRecordingMode` starts the first Initializing entry, optionally pauses it, or resumes an existing paused recording. `stopRecordingMode` pauses and marks the stop reason manual. Recording-call stop prepares entries by ASR stream identity and stops both foreground/background records, marking an unset reason auto.

APP_CALL_CHANGED and audio graph start/removal reattach existing recording to active graphs. A call device change does not by itself create a second recording session. Reattachment preserves the paused state and pauses foreground audio in TranscriptOnly mode. The prepare path records WaitingForConsent when recording consent is absent and recordWithoutConsent is false. The direct startCallRecord body does not itself test that state. This partial source relationship must not be interpreted as permission to bypass a local explicit capture admission.

### Capture scope boundary

Accepted retained AudioService V7, Evidence `ev_9a7508fc22b011b377509f2f90e73f800b515f82435be264fddd6d2741f8ab3e`, connects APP_CALL_STARTED to graph selection. With app capture available and enabled, it creates SYSTEM_MIC_OUTBOUND from the selected active microphone device unless that device is the Krisp mic. For the speaker leg it creates CAPTURE_INBOUND from the selected speaker app when the Call mode is APPLICATION, or from the selected speaker device when mode is DEVICE, unless it is the Krisp speaker. macOS Call defaults APPLICATION speaker capture. Call stop removes these capture graphs. A global processed-route mix alone does not establish this application-scoped capture contract. Native process-tap options and the full application-capture backend remain unresolved here.
