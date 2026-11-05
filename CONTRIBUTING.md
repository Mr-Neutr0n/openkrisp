# Contributing

Start with [README.md](README.md), the latest section linked from [CHECKPOINT.md](CHECKPOINT.md), and the [feature ledger](feature-parity-ledger.md). Check the relevant component README and findings report before changing recovered behavior.

## Changes

Keep each pull request focused on one observable behavior. Explain the trigger, the change and what you verified. Distinguish source tests, real device behavior and acoustic results. Do not describe untested behavior as parity. Open an issue before a change that adds a service, dependency or new architecture.

Code belongs in `app/`. Shared fixtures belong in `verification/`. Keep exact installed-provider role/hash checks and stale asynchronous-result guards. A late permission response must not start a superseded configuration.

## Verification

Run the changed component's `./verify` on an Apple Silicon Mac with the requirements listed in the README. Run root `./verify` for changes across components. Desktop verification also checks development packaging, signatures and relocated resources.

Reproduce an audio bug through the real user path before adding a regression. Use owned or explicitly authorized samples. Record hardware, OS, app build and route settings when they affect the result. Keep live capture, audible playback, driver installation and CoreAudio restart as separate acceptance steps. Follow [install-notes.md](app/audio-driver/install-notes.md) for driver work.

GitHub Actions checks numerical fixtures on Linux and runs root `./verify` on an Apple Silicon macOS runner with Xcode. These jobs do not install the driver or prove live audio behavior. The hosted macOS job gives the positive synthetic paced AEC fixture 12 scheduling frames through `OPENKRISP_PACED_FIXTURE_BUDGET_FRAMES`. Local defaults remain 2 frames in release and 4 under sanitizers. Exact-output and forced-failure checks remain active. This test setting does not change production buffering or establish latency acceptance.

## Files and reports

- Do not commit original Krisp binaries, weights, assets or compatibility lists.
- Do not commit private recordings, raw REA evidence, builds, credentials or the analysis runtime.
- Keep RNNoise notices and document changes to vendored source.
- Inspect or execute the installed original only through REA. Preserve evidence identities, artifact hashes, failures and coverage limits.
- Update the checkpoint and ledger source fingerprints after verified implementation changes.

For a bug report, include reproduction steps, expected and observed results, macOS version and the relevant commit. Remove personal paths and session details from logs. A synthetic sample is preferable when it reproduces the failure. Report vulnerabilities through [SECURITY.md](SECURITY.md).

Contributions to project-owned code use the repository's MIT license. Do not submit material unless you have the right to contribute it under the applicable license.
