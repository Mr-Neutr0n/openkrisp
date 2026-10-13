# Development driver package

`./package` builds the existing host-tested driver, signs a copy ad hoc, builds an unsigned local installer package, and validates its archive. It does not install, call sudo, request admin authorization, restart CoreAudio, or load the plug-in through HAL. The host test uses `dlopen` in a standalone process only.

The current review artifacts are under ignored `build/package/`:

| Artifact | Purpose |
| --- | --- |
| `LabVoiceAudio-development.pkg` | Unsigned component package for the current startup volume |
| `LabVoiceAudio.driver` | The ad-hoc signed bundle embedded in that package |
| `package-manifest.json` | Package SHA256, signed file digests, bundle tree digest, archive paths, and validation results |
| `preinstall-review.txt` | Exact preinstall guard for review |

Initial approved package SHA256: `2b25e35b44db7685f0fb9892d7febe29ed82316ac995366dd4b085e2f8fcf39a`.

Initial approved signed bundle tree SHA256: `4eeaa2d8d51df6f02637c1266d2178393e62c74ae835955f19913492b4663048`.

The bundle identifier is `dev.hari.labvoice.audio`, version `1`. The package receipt identifier is `dev.hari.labvoice.audio.development`, version `1`. Rebuilding can change the package digest and compiled binary. These recorded digests describe this build only. Review the new manifest and update any pinned uninstall digest before approving a later build.

## Exact installation scope

The package installs one bundle at `/Library/Audio/Plug-Ins/HAL/LabVoiceAudio.driver`. Bundle relocation is disabled. Its three regular files are:

- `Contents/Info.plist`
- `Contents/MacOS/LabVoiceAudio`
- `Contents/_CodeSignature/CodeResources`

The package creates the bundle and its `Contents`, `MacOS`, and `_CodeSignature` directories as needed. Package ownership uses Installer's recommended ownership for a system destination. Installer also registers its normal receipt and BOM under `/var/db/receipts/` for `dev.hari.labvoice.audio.development`. It does not install an app, launch daemon, kernel extension, network service, preference file, or another driver's contents. The package issues no command to change default input or output selection. Approved initial and corrected installs registered the plug-in but exposed no devices. The debug build still needs a restart and discovery trace.

The archive contains seven AppleDouble metadata members for whitelisted bundle files and directories. On this Mac these carry regenerated provenance metadata. They are package-format companions, not additional plug-ins. The script verifies AppleDouble magic, version, size, entry bounds, and nonoverlap, and requires every companion to map to a whitelisted path. Full package expansion consumes these records as metadata and leaves only the three expected regular files. The manifest records their archive paths and digests.

The preinstall script refuses any target volume other than `/`. It also refuses the exact driver path if any file, directory, or symlink already exists there, including an identical earlier build. This is a preflight check, not an atomic reservation against another administrator modifying the path during installation. Do not run concurrent installer or removal work at that path. There is no postinstall script or automatic restart command.

If HAL accepts the bundle, it can publish Lab Voice Microphone and Speaker, plus hidden app feed and monitor endpoints. Acceptance and device registration are not proven by packaging. Ad-hoc signing is for local development. The package has no Developer ID Installer signature, notarization, or production trust claim. Remote plug-in loading was observed; usable device registration remains unproven.

## Review before any installation approval

These commands inspect the prepared artifact. They do not install it:

```sh
shasum -a 256 projects/krisp/app/audio-driver/build/package/LabVoiceAudio-development.pkg
codesign --verify --strict projects/krisp/app/audio-driver/build/package/LabVoiceAudio.driver
pkgutil --payload-files projects/krisp/app/audio-driver/build/package/LabVoiceAudio-development.pkg
cat projects/krisp/app/audio-driver/build/package/preinstall-review.txt
```

Only after explicit user approval and an agreed audio interruption window may an administrator run the reviewed package with Installer. No installation command was executed while preparing these artifacts. Installation needs admin authorization. CoreAudio may discover a plug-in independently; loading and timing still need real validation.

## Guarded uninstall for the installed debug build only

The recipe below now pins the installed discovery-trace tree. The earlier initial package and manifest are preserved under `../../evidence/approved-driver-package-initial/`; their different digest is recorded above. Do not execute this recipe while the user's deferral is in effect.

Keep the matching manifest before installation. Do not remove a driver solely because its name or bundle identifier looks familiar. The following removal recipe requires administrator authorization and user approval covering removal. Approval for an installation test with rollback can cover that cleanup; do not ask again when the existing approval already applies. It verifies the exact hardcoded path, rejects symlinks, checks the bundle identifier and signature, and requires the complete file tree to match this build's pinned SHA256. A mismatch aborts without removing anything. The code uses no wildcard or directory above the experiment bundle as a deletion target.

Run from the repository root only after uninstall approval:

```sh
sudo /usr/bin/python3 - <<'PY'
import hashlib
import json
import os
import pathlib
import plistlib
import shutil
import subprocess

bundle = pathlib.Path('/Library/Audio/Plug-Ins/HAL/LabVoiceAudio.driver')
expected_id = 'dev.hari.labvoice.audio'
expected_tree = '5ca286e9483c605f82ecdfabeb830fd640dd5cd534eef3f390a4bef0b98dea95'
if os.geteuid() != 0:
    raise SystemExit('Admin authorization is required.')
if bundle.is_symlink() or not bundle.is_dir() or any(p.is_symlink() for p in bundle.parents):
    raise SystemExit('Refusing a missing, non-directory, or aliased target.')
with (bundle / 'Contents/Info.plist').open('rb') as handle:
    if plistlib.load(handle).get('CFBundleIdentifier') != expected_id:
        raise SystemExit('Refusing a different bundle identity.')
subprocess.run(['/usr/bin/codesign', '--verify', '--strict', str(bundle)], check=True)
files = {}
for path in sorted(bundle.rglob('*')):
    if path.is_symlink():
        raise SystemExit('Refusing a symlink inside the bundle.')
    if path.is_file():
        files[path.relative_to(bundle).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    elif not path.is_dir():
        raise SystemExit('Refusing a special file inside the bundle.')
digest = hashlib.sha256(json.dumps(files, sort_keys=True, separators=(',', ':')).encode('utf-8')).hexdigest()
if digest != expected_tree:
    raise SystemExit('Refusing a driver that differs from the approved experiment build.')
shutil.rmtree(bundle)
print('Removed only the verified Lab Voice Audio experiment bundle.')
PY
```

After that guarded removal succeeds, an administrator may remove this experiment's receipt if needed:

```sh
sudo /usr/sbin/pkgutil --forget dev.hari.labvoice.audio.development
```

Forgetting a receipt does not remove driver files and is not an uninstall by itself. Do not forget unrelated receipts.

## CoreAudio interruption and remaining validation

A loaded driver can remain in coreaudiod memory after its files are removed. A separately approved CoreAudio restart or Mac restart may be needed after installation or removal. Restarting CoreAudio interrupts all active audio clients, recordings, calls, and playback. Close them first. No restart command is included in the package or executed during preparation.

The prepared package passes the existing driver host checks, exact archive path checks, embedded file digest comparison, embedded strict signature validation, fixed install-location and identifier checks, relocation checks, and installer-script inspection. The package is confirmed unsigned. Approved installation and CoreAudio restart tests have occurred. Initial and class-filter-corrected packages both failed exact UID discovery. No live routing or production distribution result follows from those installs.


## Paused debug installation checkpoint

The user approved bounded installation, restart, live tests, and rollback, then deferred all password prompts and system changes until returning around 11:00 on October 13, 2026. Existing authorization does not permit running those actions during the deferral. No additional system changes, audio tests, or prompts may run now.

Root verified that the installed bundle matches the discovery-trace signed tree `5ca286e9483c605f82ecdfabeb830fd640dd5cd534eef3f390a4bef0b98dea95`. Its package SHA256 is `16d8c98681473a7387e4fa4016b005401fefeefefa5bec7a2251f8b54cf70e8c`. The exact manifest is `build/package-discovery-trace/package-manifest.json`.

| Build | Package SHA256 | Signed tree SHA256 | Observed result |
| --- | --- | --- | --- |
| Initial approved | `2b25e35b44db7685f0fb9892d7febe29ed82316ac995366dd4b085e2f8fcf39a` | `4eeaa2d8d51df6f02637c1266d2178393e62c74ae835955f19913492b4663048` | Plug-in registered, devices absent |
| Qualified OwnedObjects | `3b3018c9e6994c7937199b214d93f6e56de73abb572c805450e6872d3a19f2d4` | `bde86321fb7c4f2ac1189b77ff62d492e61de4238b91d099221fc7467fa268d0` | Restarted, same missing UID |
| Discovery trace | `16d8c98681473a7387e4fa4016b005401fefeefefa5bec7a2251f8b54cf70e8c` | `5ca286e9483c605f82ecdfabeb830fd640dd5cd534eef3f390a4bef0b98dea95` | Verified installed on disk, restart pending |
 The receipt install-time value `1791867847` corresponds to October 13, 2026 at 10:34:07 Asia/Kolkata, or 05:04:07 UTC.

The last observed coreaudiod PID was 94316, started at 10:27:21 local time, before the debug installation. The pending administrator workflow was canceled and the subsequent CoreAudio restart did not happen. Disk installation of the debug bundle does not establish that the running audio service loaded it. `../../evidence/driver-discovery-trace.log` contains LVDiscovery entries from standalone host-test processes only. There is no actual HAL discovery trace yet. Do not derive a runtime cause from those entries.

### Prepared next actions after the user returns

Root owns the administrative batch. First confirm the preserved manifest against the current installed bundle. Then use the existing approved window for one CoreAudio restart. Record the new daemon and remote-service PIDs and their start times. Do not reinstall or rebuild merely to restart the already verified debug bundle.

Run the prepared probe once after restart. It translates only the independent bundle and four known device UIDs, and reads that plug-in's bounded DeviceList and OwnedObjects arrays. It registers no IOProc and opens no audio:

```sh
swift projects/krisp/app/audio-driver/discovery_probe.swift > projects/krisp/evidence/driver-debug-after-restart-probe.json
/usr/bin/log show --last 2m --info --debug --style compact --predicate 'eventMessage CONTAINS "LVDiscovery" AND process != "host-test"' > projects/krisp/evidence/driver-debug-after-restart-trace.log
```

`swiftc -typecheck discovery_probe.swift` passed offline. The probe has not been executed in the deferred checkpoint. Inspect actual remote-driver factory, query, Initialize, and discovery Has/Get/Size entries. The trace is capped at 512 entries and does not log IO callbacks. A missing trace must be distinguished from a loaded driver rejecting a property. An empty client device list alone does not justify an initialization-notification change.

If registration becomes usable, the already approved exact-UID synthetic test can proceed before physical capture, subject to the user's return. If the bounded trace still supplies no cause, root should batch the guarded exact-debug-tree removal, this experiment's receipt cleanup if needed, and a final CoreAudio restart. Preserve manifests and logs. Do not remove a different tree or modify other drivers. Defer the whole administrative sequence to the end rather than issuing further password prompts while the user is away.
