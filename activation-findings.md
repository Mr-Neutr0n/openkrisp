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

Property callbacks mark the first pending change time for that process. A timer scans the pending records and invokes a stored callback once the configured elapsed threshold has been reached, then clears the timestamp. Additional callbacks while pending do not reset that first timestamp. The timer interval is 20 ms. The timer constructor multiplies the supplied 20.0 by 1,000,000 before configuring dispatch time and interval; this closes the units join.

The used-device loader first checks `piri` or `piro`. A false running value yields an empty set for that direction. A true value reads `pdv#` in the respective scope. It builds a set of device object IDs. This is per-process device usage, not an acoustic speech detector.

The process tracker normalizes input-device lists when more than one input device remains. It removes devices without input streams and removes devices that also occur in the output set, stopping once fewer than two input entries remain. The exact normalization is more specific than taking any device with a nonzero running flag.

A second tracker cache compares normalized used-device sets against the last published state. A different state is cached with a first-change timestamp. Further changes update that cached state without resetting the first timestamp. Returning to the published state clears the pending cache and pauses its timer. On a timer tick, a transition that removes an existing input or output leg selects the configured end threshold; otherwise it selects the start threshold. Once the elapsed time strictly exceeds that threshold, the cache becomes the published state and a copied AudioProcessInfo is sent through the stored callback. Exact configured threshold values remain unresolved here.

There is also an older CAStreamTracker/device-activity path. Its ActivityStateChange reads whether a tracked device is in use and emits a device-based stream record. Its callback and device lookup were inspected, but its complete registration and runtime selection relative to AudioProcessContainer remain unresolved. Do not assume that the newer audio-process path is available or selected on every supported macOS version.

## Application identity

CAApiHelper.LoadAudioProcInfo requires a nonzero audio object with class `clnt`. It reads `ppid` in global scope for the actual PID. A zero PID is rejected.

It resolves a responsible PID through the dynamically located `responsibility_get_pid_responsible_for_pid` function. If the function is missing or returns no positive PID, it logs and returns the actual PID as fallback. This is a responsibility lookup, not evidence of walking parent PIDs until a visible app is found.

The responsible PID supplies the localized application name, with binary-name fallback if the localized name is empty. The process bundle ID comes from `pbid`. An empty process bundle falls back to the app name. When the actual and responsible PIDs differ, the responsible bundle ID comes from NSRunningApplication for the responsible PID. If that field remains empty, it falls back to the process bundle field. Application version is also resolved for the responsible PID.

GetAppIdByPID uses NSRunningApplication.runningApplicationWithProcessIdentifier, then bundleIdentifier and UTF8String. A missing application or empty bundle identifier returns an empty string. No synthetic bundle identifier is created there.

The client callback delivers a Number device type and an array of objects. Native serialization establishes these fields:

- `pid`, a numeric PID.
- `actualPids`, a string in the native ClientAppInfo representation.
- `appName`, `appVersion`, `appId` and `deviceId`, strings.

Do not convert `actualPids` into an array based only on its plural spelling. Its native field is serialized as a string. Native stream records are converted into ClientAppInfo, and the client-list callback emits the complete current list for its device type. A container compares prior/current records before triggering a changed-list notification. Exact grouping across helper processes and all fallback paths still need the storage-to-StreamInfo join.

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

Before claiming activation parity, recover the storage-to-StreamInfo grouping join, native-source OS selection/fallback, concrete delay defaults, Call.hasBothLegs/device-usage semantics, and the APP_CALL_STARTED/CONFIRMED path into meeting-assistant recording/transcription. Recover the local auto-activation preference, manual one-call choice and concurrent-call UI locking separately. Preserve local note-taking and app exclusion while excluding vendor account/entitlement checks, remote generation and telemetry.

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
