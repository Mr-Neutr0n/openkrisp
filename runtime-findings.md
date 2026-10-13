# Runtime evidence

Target is Krisp 3.16.8 at `/Users/harikp/Applications/krisp.app`.

REA process capture `ev_4c313308fe0c8de29f4f7fa97629ed7a53b9215f042305cbc88164ad67517eea` launched the shipped executable for 12 seconds, then terminated the owned run. Output reports initialization of NativeUtils, NodeLogger, MediaSP, AudioDM and ExtHub. Sampled renderer arguments include WEB, WEB_OVERLAY, DESKTOP_REPORT_WINDOW and CONFIRMATION_WINDOW. This proves startup activity during that run, not successful feature execution. Raw terminal coverage is complete within the output budget; rendered terminal frames are truncated. Network activity and filesystem effects were not observed.

A subsequent 120-second run was started to inspect the visible UI. Ordinary macOS window metadata identified the app PID and exact windows. That metadata is discovery only, not REA behavior evidence. REA `observe_native_ui` then failed with `process-identity-unavailable`: the selected application did not expose a launch time, so the provider could not verify stable PID identity. No UI capture or interaction was obtained from that call.

Next probe: REA provider-owned Electron scenario, after the current process capture completes. Do not treat failed UI observation as feature absence.

The 120-second capture completed as Evidence `ev_80ba8151343d1e542e14bdf2a3a8ed20612c2c1253f923f71d603f4b8de78db9`. It timed out, sent SIGTERM, then SIGKILL to the owned root. The MCP Electron scenario then failed with `Transport closed`; no scenario Evidence was returned. A process check found no remaining original Krisp executable after failure.

A private analysis runtime under `analysis-runtime/` uses Electron 40.8.5, matching the framework version established by REA. It is excluded from publication. REA CLI controlled capture with that runtime failed because the target page/context/browser closed. This is a different execution environment and cannot establish normal installed-app behavior. A bounded REA process capture is checking startup diagnostics for the failure.

## Successful passive capture

Launching the original executable with a caller-selected loopback debugging port allowed REA CLI passive inspection. Target-list Evidence `ev_c30fa94a5a4b153fb0ae9abb946202381208208e3d43d44ce65aed36c5c5ce50` reports seven local pages. Five main-window instances were observed with 302, 42, 142, 84 and 26 DOM nodes. The corresponding records are `page-0.json` through `page-4.json`. The provider retains DOM structure and attribute names, not UI text. These observations do not establish the visible controls or their behavior. HTTP screenshot capture rejects file-page targets, so it cannot supply Electron screenshots through that operation.

## Earlier UI blocker

Starting the original through macOS LaunchServices with `open -W` resolves the missing launch-date identity. The latest REA native capture fails with `accessibility-denied`, explicitly asking for Accessibility access to the REA host. Screenshot-only capture separately fails with `capture-failed: Failed to start stream due to audio/video capture failure`. No successful original UI screenshot has been captured.

The user was asked to enable the REA host in System Settings > Privacy & Security > Accessibility. Do not bypass macOS permission checks or weaken REA target identity checks. No REA source was modified. Once permission is granted, discover the current Krisp PID/window IDs again before capture; historical IDs are not live targets.

## Permission recheck and first screenshot

After the user reported changing permissions, a fresh REA accessibility observation still returned `accessibility-denied`. The failure is saved in `evidence/access-recheck-ui.json`. Ordinary macOS permission diagnostics identify the responsible application as `/Applications/ChatGPT.app`, bundle ID `com.openai.codex`. Its Accessibility request was denied while ScreenCapture was allowed. These OS logs diagnose the tool host; they are not REA evidence about Krisp features. The user has been given this exact app identity.

REA screenshot-only observation then succeeded as Evidence `ev_fa8bff2cf970ca8119833540f327e2d7927f80e34e5312ea8dd3c4345ee148e0`, retained in `evidence/screen-recheck-ui.json` and its derived PNG. It captured one exact 880 by 660 window. Accessibility was disabled, with that gap explicit in the record. The visible meeting dashboard includes account/upgrade controls and a notice that the free trial ended. This does not establish whether local noise processing remains available. No past meeting was opened and no account action was taken. The screenshot contains account information and remains private evidence.

The LaunchServices process capture again reports incomplete cleanup because macOS withholds environment ownership tokens for `/usr/bin/open`. Preserve the error instead of claiming complete cleanup. Discover current processes again before any further observation.

## Accessibility granted and settings mapped

After the user's final permission confirmation, REA captured a complete, nontruncated Accessibility tree with no reported gaps as `ev_1bd54ca1a2caae597e12864e2a82d77a2ed0ccff14c16c38156e628d33285f4c`. Navigation then captured Account, Noise Cancellation, App, Notifications and AI Note Taker settings. `ui-runtime-map.md` and its JSON companion record 25 control groups, their source paths, and current selections visible in screenshots. Current selections are not proven factory defaults. No account action or past meeting was opened. Raw captures contain private account data and remain excluded from publication.

An attempted Light/System appearance roundtrip failed with inconsistent window geometry before returning any step evidence. Followup read-only observation `ev_05dbe91b84927d1638dc30aab805c8f34035789289571bcd9143a2354c27662f` still shows the AI Note Taker page. This is consistent with failure before navigation, but does not prove a completed roundtrip or restoration. No appearance behavior claim is made. REA identity checks were retained unchanged.

Two fresh original observations later returned `ambiguous-window` with no AX window candidates, although ordinary macOS metadata still listed the process. This is a runtime capture limitation, not a renewed Accessibility-denied error and not feature absence. Earlier successful settings evidence remains valid.
