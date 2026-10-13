# Model catalog

This macOS 12 Swift library discovers and hashes explicitly selected local model assets. It ships metadata only. It contains no model weights, KEF decoder, inference backend, downloads, vendor binaries, or license grant.

Run `./verify` for fixture tests and a release build. All test assets live in temporary directories. The tests do not open the original app, downloaded models, or user audio. Add the local package as a dependency and import `ModelCatalog` to use it from desktop code. Run catalog calls on a worker actor or background task, not on an audio callback or the main thread. These calls perform synchronous disk I/O.

## Independent provider manifest

Use `loadIndependentManifest(root:relativeFile:)` with an explicit model root and a relative manifest filename. The JSON object has `schemaVersion: 1`, `providerID`, and a nonempty `models` array. Each entry has these fields:

| Field | Meaning |
| --- | --- |
| `id` | Unique model ID, ASCII letters, digits, period, hyphen, or underscore. At most 128 bytes. |
| `feature` | Nonempty provider-declared feature string. It does not prove processing support. |
| `localFile` | Relative file path below the selected root. |
| `sha256` | Required 64 lowercase hexadecimal digits for independent models. |
| `license` | Object with optional `identifier`, optional `source`, and required `redistribution`. |
| `license.redistribution` | `unknown`, `permitted`, or `prohibited`, supplied by the manifest author. |
| `configuredType` | Optional numeric provider metadata. No runtime meaning is assumed. |

Manifest loading limits input to 1 MiB, requires at most 1024 models, and rejects duplicate IDs. `validate(_:root:)` checks the same manifest constraints, then returns an assessment for each model. A hash mismatch is separate from a missing asset. License status is separate from integrity. Missing license identity, missing license source, or unknown redistribution status sets `unknownLicense` to true. A manifest declaration of permission is metadata, not a legal determination. The caller must establish provenance of the manifest and license evidence before distributing weights.

## Installed provider

`discoverInstalled(appBundle:downloadedModels:)` accepts caller-selected roots. Pass an app bundle root and the dedicated downloaded-model directory, or omit either location. It checks only the 11 expected filenames in both roots. It does not recursively search the Mac or infer a user's installation location. App files are under `Contents/Resources/resources/models/audio/`. Downloaded files are directly below the selected model directory. Both locations produce separate assessments so a missing or mismatched copy does not hide a second copy.

The metadata derives from these saved REA records:

- `projects/krisp/evidence/models-configuration.json`, configuration evidence `ev_016bcec295d94aa5289ae0b5d7b20c241a7d45e880bb797083c9fd4b59c89def`.
- `projects/krisp/evidence/native/artifact.json`, inventory evidence `ev_e9c2f082e96a01b0b07c8d7592751b75938b3ad3d2ed21cf8e2db00c3618b818`.
- `projects/krisp/model-manifest-check.json`, the existing evidence-derived filename and digest summary.

Eight configured bundle files have recorded SHA256 values. The ASR and two accent filenames have no authenticated digest in those reports. They can be detected and hashed, but receive `hashUnverified`. No digest was invented. Installed asset license and redistribution status are unknown. Feature names retain configured family and model names, and `configuredType` retains literal numeric types. Neither field claims recovered tensor contracts or processing semantics. The expected values describe the captured installation, not every Krisp version.

## Validation limits

Paths cannot be absolute, contain empty components, `.` or `..`, NUL, or backslashes. Descriptor-based `openat` traversal rejects symlinks below the chosen root and a symlink at the root itself. Ancestors of the explicitly selected root can contain normal system symlinks such as `/tmp`. Files must be regular files. Directory descriptors fix traversal to opened directories. Hashing streams at most 1 MiB per chunk. Size, modification time, and change time must remain stable across the read. This is a validation snapshot. It does not reserve the file against later replacement, and cannot detect every malicious same-user mutation. An inference loader must revalidate or use the same validated descriptor before consuming bytes.

Assessments report `missing`, `invalidPath`, `unreadable`, `notRegularFile`, `changedDuringRead`, `hashMismatch`, `hashUnverified`, or `verified`. `detected` means a regular asset was read and hashed. `inferenceReady` is always false, and `inferenceBlocker` says no backend is integrated. A valid hash proves correspondence with the supplied digest only. It does not prove format validity, inference compatibility, offline activation, quality, or redistribution rights.

Verification passes five fixture tests covering independent manifest loading, hash checks, corruption, missing files, unknown licenses, path and symlink rejection, duplicate IDs, missing digests, both installed-provider locations, and unavailable inference. The Swift release build also passes. Runtime loading of real models and legal permission remain unresolved.

The installed target changed to Krisp 3.17.9 during inspection. REA configuration Evidence `ev_89741bd0eebf862f38d26b4698f7686d6fd774157f966f3f8096b704b672eac6` changes only the ASR filename to `asr_eng_6.3.0_1.0.kef`; this catalog now expects that current filename. Its digest remains unknown. The eight bundled reference digests still identify the previously measured model bytes; validation compares actual selected files and reports mismatches rather than assuming they stayed unchanged.
