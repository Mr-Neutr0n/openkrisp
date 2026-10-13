# Cloud and analytics exclusion map

Source is REA Evidence `ev_a171e77e361a92e3a14ece5a0d849dd226d5669aaa7a8dbc9bafd807200e54ca`, saved in `evidence/javascript-initial.json`. This is a projection of retained evidence. It does not establish a complete network or analytics inventory.

## Concrete JavaScript boundaries

| Module | Static operation | Location |
| --- | --- | --- |
| `.vite/build/BootstrapPreload-Bv38cy6d.js` | `read:/closeSentryGracefully` | line 3, column 29329 |
| `.vite/build/BootstrapPreload-Bv38cy6d.js` | `write:/_sentryDebugIds` | line 1, column 550 |
| `.vite/build/webWindowPreload.js` | `read:/_sentryDebugIds` | line 1, column 539 |
| `.vite/build/index.js` | `read:/_sentryDebugIds` | line 1, column 1000 |
| `.vite/build/BootstrapPreload-Bv38cy6d.js` | `read:/captureSentryMessage` | line 3, column 27027 |
| `.vite/build/webWindowPreload.js` | `write:/__SENTRY_IPC__` | line 1, column 12152 |
| `.vite/build/index.js` | `write:/_sentryDebugIdIdentifier` | line 1, column 1050 |
| `.vite/build/webWindowPreload.js` | `write:/_sentryDebugIdIdentifier` | line 1, column 589 |
| `.vite/build/index.js` | `write:/SENTRY_RELEASE` | line 1, column 919 |
| `.vite/build/BootstrapPreload-Bv38cy6d.js` | `read:/captureSentryException` | line 3, column 26975 |
| `.vite/build/webWindowPreload.js` | `write:/_sentryDebugIds` | line 1, column 521 |
| `.vite/build/webWindowPreload.js` | `read:/__SENTRY_IPC__` | line 1, column 12174 |

The preload reads `captureSentryMessage`, `captureSentryException` and `closeSentryGracefully`. The web-window preload reads and writes `__SENTRY_IPC__`. Main and preload modules also register Sentry debug IDs or release markers. These operations identify instrumentation boundaries. The saved semantic graph does not prove their invocation, event payload or transport. The JSON companion retains exact node IDs and source ranges.

## Mixed bundle removal trap

`SentryManagerMain-BCbY-HkL.js` exports `AudioEnhancementState`, `MediaFileMode`, `hasArgument`, `prependPathDirs`, `requireSrc` and `SentryTestMode`. A chunk name does not define its ownership. Removing the whole chunk can remove local audio and utility declarations. Rebuild the needed local declarations independently and omit telemetry hooks.

These exports and the module import edges are recorded under Evidence `ev_a171e77e361a92e3a14ece5a0d849dd226d5669aaa7a8dbc9bafd807200e54ca`. Retained imports include `fs`, `os`, `url`, `zlib`, `worker_threads`, `node:util` and `node:readline`, plus unresolved obfuscated requires. These generic dependencies do not identify remote destinations.

## Endpoint extraction limits

The retained endpoint nodes contain `X-Sentry-Rate-Limits`, `Retry-After`, `sentry.sample_rand` and `sentry.dsc`. They also contain date-unit strings such as `weeks`, `minutes`, `seconds` and `years`. Treat these as heuristic syntax matches, not URLs. No concrete remote HTTP or WebSocket host was recovered in this subset.

`/Krisp.AppService.InstallService/Execute` occurs at `.vite/build/BootstrapApp-BiqTUzCg.js`, line 674, columns 137003 through 137050. It is a service route candidate. The host and transport remain unresolved. The root route `/` and empty route strings also occur. They do not prove cloud access.

## Native boundaries

### libdaily-core-sdk-wrapper.dylib

Evidence `ev_99203e8788bb23c3a6613415e79affe0b66e1cfeb94d12ca7fea0a82cf922fc4`. Static imports, exports and dependencies. No caller path, execution, destination or payload is established.

- `__ZN10daily_core7metrics6native24UnstableTelemetrySession18send_meeting_event28_$u7b$$u7b$closure$u7d$$u7d$10__CALLSITE17hfb68b8d690461fd6E` at `0x185ce48`.
- `__ZN10daily_core7metrics6native24UnstableTelemetrySession18send_meeting_event28_$u7b$$u7b$closure$u7d$$u7d$10__CALLSITE4META17hfafaf6b91e021a84E` at `0x17a2ef0`.
- `__ZN15daily_telemetry11WebRtcStats41get_stream_based_mini_data_logging_stream17h2da274bd9a13f4e4E` at `0x84aee8`.
- `_daily_core_call_client_join` at `0x23b470`.
- `_daily_core_call_client_recording_fns` at `0x3f12c0`.
- `_daily_core_call_client_start_recording` at `0x3f5e7c`.
- `_daily_core_call_client_start_transcription` at `0x3f71d4`.
- `_daily_core_call_client_stop_recording` at `0x3f6204`.
- `_daily_core_call_client_stop_transcription` at `0x3f76d8`.
- `_daily_core_call_client_telemetry_fns` at `0xf1f78`.
- `_daily_core_call_client_transcription_fns` at `0x3f12f8`.
- `_daily_core_call_client_update_recording` at `0x3f64bc`.
- `_daily_core_call_client_update_transcription` at `0x3f77cc`.
- Dependency: `@rpath/libdaily-core-sdk-wrapper.dylib`.

### kr-media-sp.node

Evidence `ev_82a288cac329f8c56c70b229dab17784b6f6ae35d0d61b7bde9ed4b7015715d1`. Static imports, exports and dependencies. No caller path, execution, destination or payload is established.

- `__ZN5Krisp7MediaSP21CreateTranslationNapiERKN4Napi12CallbackInfoE` at `0x28e18`.
- `__ZN5Krisp7MediaSP22EnableTranslationsNapiERKN4Napi12CallbackInfoE` at `0x28d90`.
- `__ZN5Krisp7MediaSP24CreateRtcTranscriberNapiERKN4Napi12CallbackInfoE` at `0x2b550`.
- `__ZN5Krisp7MediaSP25DestroyRtcTranscriberNapiERKN4Napi12CallbackInfoE` at `0x2c88c`.
- Dependency: `@rpath/libdaily-core-sdk-wrapper.dylib`.
- Dependency: `@rpath/libsioclient_tls.3.dylib`.
- Dependency: `@rpath/libkrisp-curl-wss-wrapper.0.dylib`.

The native media component includes local model, audio graph and ASR boundaries as well as remote RTC and translation declarations. Replacing only JavaScript analytics does not establish a local-only audio path. Daily telemetry declarations show a second boundary to exclude. Their presence does not prove that the original app sends telemetry.

## Reconstruction actions

- Sentry capture hooks and IPC: Build local error logging independently. Omit captureSentryMessage, captureSentryException, __SENTRY_IPC__, debug ID registration and remote flush from the reconstruction. Preserve ordinary error display and shutdown sequencing.
- Mixed Sentry-named bundle: Preserve independently implemented audio/media enums and utility behavior. Do not remove an entire chunk based on its filename.
- Native Daily and remote media clients: Use independently licensed local audio capture and local ASR. Do not import Daily telemetry, remote RTC transcription or Socket.IO/WebSocket clients for the local reconstruction.
- Account, cloud storage, meeting bots and report upload: Remove sign-in gates, remote sync, bot attendance and report upload. Keep local folder storage and log export as separate implementations.
- Model acquisition, updates, calendar and screen capture: Keep these unresolved until exact local/network callers are traced. Package approved local assets or provide explicit independent acquisition. Implement local screen capture independently if required by the user.
- Privacy verification: Test the independent build through real local capture, processing, recording and quit paths while monitoring outbound sockets. Verify no analytics SDKs, crash upload, cloud model API or automatic updater enters the final build.

User-facing exclusion scope comes from translation Evidence `ev_ece7c942d90e27f063fd1be188d354a1a8d0f289e59aadea32bb6dc209566fa7`, grouped in `catalog-feature-map.json`. Account, cloud storage, bot and upload labels identify requested exclusions. They do not supply concrete endpoint call paths.

## Remaining limits

- Source JavaScript semantic coverage is partial and truncated. Large bootstrap, preload and renderer bundles exhausted heap or parent result budget.
- Retained request-family relations are zero; this is incomplete coverage, not evidence of no requests.
- Obfuscated require expressions and dynamic members remain unresolved.
- No concrete HTTP or WebSocket remote host was recovered in the retained endpoint-node subset. Header names, date units and local routes are not remote hosts.
- No complete product-analytics event inventory or vendor identification is established.
- Sentry debug markers identify instrumentation, not proof that any event was sent.
- Five native companions mismatch their ASAR declared digests. Native evidence concerns current local bytes.
- This static cloud-boundary analysis used no original app execution, credentials, user account content or live traffic. Separate UI investigations are recorded in their own reports.

Static retained evidence answers where several hooks and native boundaries exist. It leaves exact remote hosts, request bodies, event names, reachable callers, dormant code and default enablement unresolved. No complete absence-of-telemetry claim is made.

## Independent implementation checkpoint

A source search on 2026-10-13 across `app/`, excluding generated builds, vendor code and documentation, found no uses of URLSession, Network.framework, Sentry, Firebase, analytics APIs, WebSocket, Socket.IO, nw_connection, curl or connect. The URL matches were the standard Apple plist DTD and a test that rejects an HTTPS WAV URL. This is a bounded text search, not a complete network audit.

`app/local-transcription/Sources/LocalTranscription/AppleBackend.swift` creates a Speech request with `requiresOnDeviceRecognition=true`, checks on-device capability and availability immediately before task creation, and provides no cloud fallback. The higher-level adapter also rechecks those capabilities after WAV validation. This establishes request policy in the independent source. Actual OS recognition and traffic observations remain pending; system-service behavior cannot be inferred from application-source searches alone.
