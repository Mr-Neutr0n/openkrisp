# openkrisp

Local audio tools for Apple Silicon Macs. Open source, with no account, trial or subscription.

openkrisp is an independent reconstruction of local Krisp capabilities. The current app is a development build named **Lab Voice**. It combines RNNoise processing, virtual audio devices, local recording and a native macOS library. This project is not affiliated with Krisp.

[Project website](https://open-krisp.harikp.com)

**Developer preview.** Virtual-device transfer and physical microphone routing into FFmpeg pass on the development Mac, including Start and Stop in the packaged app. Zoom lists and runs both virtual devices. Separate accent-engine probes convert speech with the exact installed original models and native engine; live app integration is in progress. Real calls, sustained timing and acoustic quality still require acceptance. [CHECKPOINT.md](CHECKPOINT.md) records the evidence. There is no supported end-user release yet.

## What is here

| Area | Implemented in source | Acceptance still required |
| --- | --- | --- |
| Noise reduction | Independent RNNoise processing for microphone and speaker audio | Real-call acceptance, sustained timing and speech quality |
| Virtual audio | Independent microphone, speaker and internal companion endpoints | Discovery, bounded HAL transfer and Zoom device selection pass locally; real calls remain open |
| Recording | Route recording, pause/resume, selected-app recording with optional microphone, retained-file recovery | Native permissions, real capture and original recording comparison |
| Local library | WAV import/playback, search, transcript export, library selection and saved-session transcription | Complete native workflow acceptance and OS Speech recognition |
| Desktop | SwiftUI/AppKit app, floating controls, diagnostics, login controls and power-event handling | Original interaction parity and hardware lifecycle testing |
| Installed providers | Experimental bridges to exact, user-selected local NC, accent, background-voice and AEC files | Live audio quality, latency and compatibility beyond reviewed identities |

Implemented controls have no payment gate. Cloud storage, accounts, meeting bots, uploads and product analytics are excluded. Live captions, diarization, automatic call recording and full feature parity remain incomplete. The [feature ledger](feature-parity-ledger.md) separates retained requirements, evidence and gaps. Its feature counts are not completion percentages.

The default RNNoise engine does not need an installed Krisp app. Optional installed providers require separately obtained local files. This repository does not include or download Krisp binaries, models, icons or compatibility lists.

## Local workspace

The development workspace groups this public repository in `product/` and the private marketing repository in `../website/`. Private evidence and analysis dependencies stay in the grouping folder, outside both repositories. A normal GitHub clone still has `app/`, `verification/` and `./verify` at its own repository root.

See [COMPARISON.md](COMPARISON.md) for the current controlled engine experiment and retained-feature gaps.

## Build and verify

Requirements:

- An Apple Silicon Mac and macOS 13.5 or later for the bundled desktop distribution. Owned audio and driver components retain macOS 12 targets.
- Xcode with Swift 6, Clang, the macOS SDK and XCTest support. Some Command Line Tools installations omit XCTest and cannot run the Swift test suites.
- Python 3 and Node.js on `PATH` for building and fixture checks.
- `gpgv` from GnuPG to verify the pinned official Node release. The desktop packages that signed runtime; users do not need Homebrew or a separate Node installation.
- Node C API headers at `/opt/homebrew/include/node/node_api.h` for the experimental adapter build.

```sh
git clone https://github.com/Mr-Neutr0n/openkrisp.git
cd openkrisp
./verify
```

The root command runs the component suites, sanitizer fixtures and signed development packaging checks. It writes the app to `app/desktop/.build/app/Lab Voice.app`. It does not install a driver, restart CoreAudio, load Krisp, request microphone access or perform a live call test. Read-only device and process inventory checks can run during verification.

For a smaller change, run that component's `./verify`. After dependencies have been built, `app/desktop/build` rebuilds the app and rejects missing or stale helpers. See the [desktop build notes](app/desktop/README.md) for packaging and runtime details.

The Python-only measurement checks also run on other systems:

```sh
./verification/verify
```

These checks validate known signal transformations. They do not measure speech quality or establish original-versus-rebuild parity.

## Try the development app

Open the built `Lab Voice.app` to use the local library. Audio starts only through an explicit capture action. The default library is `~/Library/Application Support/Lab Voice/sessions`. Import copies the selected WAV into that library. Transcript export uses a new destination. Session deletion requires confirmation.

The app and driver use ad-hoc development signatures. They are not notarized. Building the app does not install its virtual audio driver. Driver installation and a CoreAudio restart affect system audio and are separate administrator actions. Review [installation and rollback notes](app/audio-driver/install-notes.md) before any driver work. Do not use a call as the first hardware test.

## Source layout

| Path | Purpose |
| --- | --- |
| [`app/desktop`](app/desktop) | Native desktop app and controller tests |
| [`app/audio-driver`](app/audio-driver) | CoreAudio plug-in and bounded HAL tests |
| [`app/audio-host`](app/audio-host) | Routing, capture, device observation and helper protocol |
| [`app/audio-transport`](app/audio-transport) | Timestamped audio rings and shared-memory transport |
| [`app/noise-engine`](app/noise-engine) | RNNoise integration and allocation tests |
| [`app/local-store`](app/local-store) | Local sessions, recording provenance and transcript storage |
| [`app/local-transcription`](app/local-transcription) | Explicit on-device Apple Speech adapter |
| [`app/model-catalog`](app/model-catalog) | Confined file validation and external model identities |
| [`app/native-model-probe`](app/native-model-probe) | Experimental installed-provider adapters and owned fixtures |
| [`app/accent-engine`](app/accent-engine) | Separate installed accent-model broker and adapter |
| [`app/installer`](app/installer) | Development app and driver package |
| [`app/node-runtime`](app/node-runtime) | Signed official Node runtime, provenance and complete license |
| [`verification`](verification) | Deterministic audio generation and numerical comparison |

## Evidence and limits

The original app is inspected only through REA. Reports retain artifact identities, failures and coverage limits. The original changed version during research; [version-change-findings.md](version-change-findings.md) separates those observations. Static findings and synthetic tests do not prove runtime or acoustic parity.

Start with [CHECKPOINT.md](CHECKPOINT.md), the [feature ledger](feature-parity-ledger.md) and the [comparison plan](parity-verification-plan.md). Component READMEs explain their own contracts. Historical reports can describe older states; the latest verified checkpoint and actual runtime state take precedence. Raw evidence, generated audio, builds and the analysis runtime stay outside Git.

## Contribute

Read [CONTRIBUTING.md](CONTRIBUTING.md) before sending a change. Use [GitHub issues](https://github.com/Mr-Neutr0n/openkrisp/issues) for reproducible bugs and bounded feature work. Do not attach private call recordings, credentials or proprietary model files. See [SECURITY.md](SECURITY.md) for private vulnerability reports.

## License

Project-owned code and documentation use the [MIT license](LICENSE). Vendored RNNoise uses its own BSD-style license, retained in [COPYING](app/noise-engine/vendor/rnnoise/COPYING). [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) records that boundary and the local patch. No license in this repository grants rights to external Krisp code, model weights, assets or trademarks.
