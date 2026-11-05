# Development installer

`./verify` checks the preinstall guard against private fixtures, then builds and inspects a combined package. It does not install, request administrator access, launch the app, load a driver through HAL, restart CoreAudio or capture audio.

Build the canonical desktop app first using the repository verification entry point. Then run:

```sh
./app/installer/verify
```

The builder copies the signed app at `app/desktop/.build/app/Lab Voice.app`. It compiles a separate nontrace driver in private staging, targets macOS 12, and runs both normal and test-hook host checks. It does not mutate the canonical app or audio-driver build outputs. Rebuild this installer after the app changes; packaging an older app does not add new capabilities.

Generated files are ignored under `build/`:

- `OpenKrisp-development.pkg`
- `package-manifest.json`, with exact payload hashes and scope
- `preinstall-review.txt`
- `signed-inputs/`, containing the two signed bundles embedded in the package

## Installation scope

The package requires Apple Silicon and macOS 12 or later. Every included Mach-O is checked for ARM64 and a macOS 12 deployment target. This metadata does not prove that every feature or optional external provider works on macOS 12. The fixed installation locations are:

- `/Applications/Lab Voice.app`, identifier `dev.labvoice.desktop`
- `/Library/Audio/Plug-Ins/HAL/LabVoiceAudio.driver`, identifier `dev.hari.labvoice.audio`

The receipt identifier is `dev.hari.openkrisp.development`. Installer also writes its normal receipt and BOM. It does not install original Krisp binaries or models, an external Node runtime, a launch daemon, a network service or a preference file. Existing local data stays outside the package. Optional installed providers still need separately obtained local files and explicit validation in the app.

This first installer supports fresh paths only. Its preinstall rejects any existing app or driver at those locations, including an identical build, a symbolic link or a non-directory parent. It performs no deletion or replacement. The check is preflight, not an atomic reservation against another administrator changing a path during installation. Do not run concurrent installer or removal work at either location.

No upgrade or uninstall workflow is included. On a development Mac with an existing driver, the coordinator must first review its exact signed tree, retain a rollback and use a separate guarded migration. Do not remove a bundle by name alone. The current installer does not provide a two-bundle rollback transaction; preserve a known working build before any separately approved migration.

## Local acceptance

Review the package, manifest, embedded signatures and exact preinstall before an installation test. Installation needs administrator authorization. The package has no postinstall script and never restarts audio. Loading the new driver, any separately approved CoreAudio restart, device discovery, physical capture, playback and meeting-client use remain separate acceptance steps. An already running app or loaded driver can retain its prior code until it exits or its service restarts.

Both bundles have ad-hoc development signatures. The package is unsigned and is not notarized. It is not a production trust or general-download release. A Developer ID Application certificate, Developer ID Installer certificate and notarization are required before making those release claims. Do not disable Gatekeeper or other system protections to test it.

The builder verifies exact archive paths, bounded AppleDouble metadata, expanded bundle digests, bundle signatures, identities, executable targets, relocation policy, the embedded preinstall and the absence of postinstall actions. These checks do not prove feature, acoustic or installer runtime acceptance.
