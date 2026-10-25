# Background voice cancellation controls

The retained current JavaScript selects BVC through microphone device compatibility and account-derived configuration. It supports a persistent manual headset allowlist. This is a static control contract, not proof of headset detection accuracy, cancellation quality or offline availability. No original execution, device change, audio capture or administrator operation occurred for this report.

## Sources

- `evidence/model-probes/speaker-graph-decoded-classes-20261018-v2.result.txt`, REA `ev_6633cc56846dc24c1803403ef109b67197a17228f64422f75143e8dd616f85b1`: decoded `AudioService` and following `BvcService`, including compatibility, persistence and resource update methods.
- `evidence/model-probes/speaker-graph-admission-config-20261018-v1.result.txt`, REA `ev_48289fc2d3d251a1c78a3d4bd60e7cbdd8e0a1b72b7a7052596a2b6aa93ff471`: graph model selection and account setting propagation.
- `evidence/current-translations.json`, REA `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4`: labels and warnings. Historical catalog `ev_ece7c942d90e27f063fd1be188d354a1a8d0f289e59aadea32bb6dc209566fa7` contains corresponding labels.

The JavaScript captures bind `app.asar` SHA256 `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`, version 3.17.9, and Bootstrap module SHA256 `bbaedd07bcd78d093f1011a41e3aeca92707c1f77fc7cca03305ffd4cd90cff0`. Their complete retained raw output supports these claims despite truncated rendered previews. The decoder leaves some nested aliases unresolved. No fresh original-file inspection was needed.

## Minimal control contract

`BvcService.checkCompatibility(device)` applies the following precedence:

1. Processing mode `ALWAYS_OFF` rejects BVC.
2. False `audioSelector().configs.microphone.headsetVCAvailable` rejects it as unavailable for the user. The logger calls this an administrator restriction; the upstream configuration policy is not established here.
3. Sample rate below 16,000 Hz returns `LOW_RATE`.
4. Team blocked devices precede team allowed devices. A team user-choice entry requires a matching local user-choice entry.
5. Otherwise local blocked devices precede local allowed devices, then local user choice. Unmatched devices return `NOT_DEDICATED`.

Only `ALLOWED` and `USER_CHOICE_ALLOWED` make `isCompatibility` true; exceptions return false. Team matching uses exact comparisons and local matching uses substring comparisons over lowercased device identity fields. Some field accesses remain obfuscated, so this report does not prescribe a complete matching schema. In this packaged branch `fetchTeamDevicesList` immediately returns with “supported only for Enterprise product”; its presence does not establish active team-list retrieval.

Adding a manual headset stores `{name: suppliedName}` in `USER_CHOICE_HEADSET_ALLOW_LIST`, emits activation analytics and `BVC_LISTS_CHANGED`. Removing filters the exact stored name, persists and emits the same change event. Reset clears this stored allowlist and sets the in-memory mode to `AUTO`. The reset body does not itself persist that mode change. Manual mode selection separately persists `BVC_PROCESSING_MODE_MIC`, updates the mode and emits both mode/list changes. The constructor starts at `AUTO`, but refresh loads stored values; this is not proof of the first-run effective default. No unconditional “always on” bypass was established.

AudioService responds to list changes by refreshing selectable microphone devices and changing an existing microphone graph model when compatibility changes between NC and BVC. `getGraphSettings` selects BVC for a compatible microphone, otherwise NC. Speaker `useBvcModels` and interpreter enforcement are separate BVC selection paths. Model selection does not prove active suppression: the separate NC switcher and other graph gates still apply. Account `MIC.enforceBvcDevice` is forwarded to the active-device manager, but its full selection policy was not recovered here.

## Local and network boundaries

Compatibility checks and manual-list writes are local JavaScript operations. The service loads cached `bvcLists.json` containing `allow_list` and `block_list`. Resource refresh uses a resource provider, URL/checksum metadata, cached checksum checks and bounded retry settings. When resource metadata retrieval fails, a nonempty cached file can be treated as available for that update check. These facts show network-dependent list maintenance, not cloud audio processing.

The graph chooses packaged model types through the local media graph path. This does not establish that all BVC models are present, licensed or usable offline, nor that an account can activate BVC without a server. Account refresh and resource subscription are control-plane dependencies. No retained observation here proves audio upload for BVC or absence of upload elsewhere.

## Labels and gaps

Catalog text says BVC requires a headset, can be activated manually for unrecognized devices, may degrade other microphones, is unavailable when the microphone toggle is off, and can be restricted by an administrator. The actual recovered compatibility routine uses policy lists and device identity metadata. It does not demonstrate a live acoustic headset detector. “Cancels nearby voices in addition to noise and echo” is product wording, not evidence of BVC DSP composition or AEC ordering.

A faithful independent control surface can expose automatic compatibility, explicit manual confirmation, remove/reset controls, availability/rate/block reasons and a separate processing switch. It should retain warnings and show unavailable or unknown policy rather than claim original headset detection. Remaining gaps are exact matching-field decoding, UI event payload validation, active-device enforcement behavior, upstream entitlement/default derivation, list contents and update authenticity, model admission, native BVC execution and measured quality. No DSP or full-product parity follows from this control contract.

## Exact matching fields and cached list, 2026-10-25

A focused static REA capture resolves the two nested matcher aliases left unknown above. Evidence `ev_18778f368464b2a9e4ef67192d174ff8a8b7a42d22d3f2bd8638fe0074b9d253` uses the existing own archive reader, SHA256 `654fc22694ce403eee79eb52abbf6fe5559ce552ab46a607752ba8fa96eed96f`, with an in-memory addition of alias `m`. Both matcher closures directly assign `const m=e`, and the enclosing method assigns `e=_0x4b0ed5`. The reader parses the literal table and substitutes strings; it does not execute original modules. The archive has matching before/after SHA256 `40269da405babcd79c18780715c63625d0bb7035f03a480b1732fe067ba911b4`. The capture exits zero and reports verified owned-process cleanup and temporary-root removal. Raw PTY output is complete at 34,960 bytes; rendered history is truncated.

`checkCompatibility` lowercases device `interfaceName`, `manufacturer` and `modelId` before testing entries. The device's display `name` appears in logging, not in these comparisons. Entry matching is:

| Entry shape | Team matcher | Local matcher |
| --- | --- | --- |
| Truthy `name` | Lowercased `interfaceName` equals lowercased entry `name` | Lowercased `interfaceName` includes lowercased entry `name` |
| No truthy `name`, with truthy `manufacturer` and `model_uid` | Both corresponding lowercased fields equal | Device `manufacturer` includes entry `manufacturer`, and device `modelId` includes entry `model_uid`, all lowercased |
| Neither form | False | False |

A truthy entry `name` takes precedence over manufacturer/model fields. The recovered matcher applies no trimming, token boundaries or regular expressions. A device must supply the three lowercased fields even when a name-only entry could match. Malformed fields can throw; `isCompatibility` catches exceptions and returns false. This is static JavaScript behavior, not a tested device classifier.

The preceding precedence list remains correct, with one useful detail: after a team `userChoice` match, the method returns from that branch based only on a matching local `userChoice` entry. It does not inspect local block or allow lists in that branch. Without a team match, local blocked entries precede local allowed entries, then local user choice. Team retrieval still returns immediately in this packaged branch, so these team rules do not establish a populated live team policy.

Evidence `ev_bf65d20227611a5f87a999080958c3764e25cd504f1d34062dd8de9a1cf6545c` statically inventories ASAR member names and selected cache/resource roots. It finds `/Users/harikp/Library/Application Support/krisp/bvcLists.json`, 56,104 bytes, with matching before/after SHA256 `342a5ca1735c6fa0646839d32d3d22717c8184424345db76e76a79d6ac9e4827`. It parses 152 `allow_list` entries and 701 `block_list` entries. Entry keys across both arrays are `name`, `manufacturer` and `model_uid`. The capitalized `Krisp` candidate path returns the same content; these are not established as two distinct files.

The bounded samples include allowed names `tildepro`, `plantronics blackwire` and `poly blackw`, and blocked names `macbook pro`, `macbook air`, `echo dot`, `soundflower`, `camera` and `webcam`. Manufacturer/model pairs also occur in both arrays. These examples identify cache contents, not a recommendation or proof that any connected device matches them. No user-choice store, account data or unrelated file contents were read. Cache freshness, provenance and authenticity against resource metadata remain unknown.

The ASAR inventory covers 185 members and finds no member whose path matches `bvc.*list` or `list.*bvc`, case-insensitively. The directory search examines only `~/Library/Application Support/{krisp,Krisp}`, `~/Library/Logs/krisp`, `/Library/Application Support/krisp`, `/Library/Logs/krisp`, and the selected application's `Contents/Resources/resources`, to depth four, without following symlinks. It visits 1,838 directory entries and selects only files named `bvcLists.json`. It finds no additional distinct list. This bounded negative search does not exclude lists under other names, deeper paths, embedded data or remote resources.

The second capture exits zero and retains all 3,302 raw PTY bytes. REA reports the owned process group verified and temporary root removed, but also lists three supplemental platform-wrapper processes as unverified because their environments were withheld. Owned-group cleanup is verified. The supplemental entries limit visibility into unrelated platform wrappers; they do not report an owned-group cleanup failure. Both captures run own static readers under deny-network profiles and cleared environments. No original application, original module, audio processing, application UI, settings write, network fetch or administrator operation ran.

Remaining acceptance gaps are the mapping from CoreAudio device metadata to original `interfaceName`/`manufacturer`/`modelId`, the effective account entitlement and default mode, authenticated list version/freshness, original device-policy execution, live headset behavior and measured voice isolation. The exact matching schema and observed cache now support an independent policy implementation, but do not by themselves establish original automatic-selection parity.

### Cache field counts and failure behavior

A further narrow REA read, `ev_a763befd06a4987fd6d43e2aab86f0eeee7b83ce95ceac5e22d7d19ff2785625`, computes schema counts without copying the list. It confirms the same cache digest before and after. Top-level keys are exactly `allow_list` and `block_list`.

| Entry shape | Allow count | Block count |
| --- | ---: | ---: |
| `name` only | 122 | 359 |
| `manufacturer` and `model_uid` | 28 | 338 |
| `manufacturer` and `name` | 2 | 1 |
| `model_uid` only | 0 | 3 |

Allow fields have 124 names, 30 manufacturers and 28 model UIDs. Block fields have 360 names, 339 manufacturers and 341 model UIDs. All present values in these fields are nonempty strings, with no null or other value types. Thus 124 allow entries and 360 block entries use the name branch, including the entries with both manufacturer and name. Another 28 allow and 338 block entries use the manufacturer/model branch. Three block entries contain only `model_uid` and cannot match either recovered branch. This is a static consequence of the matcher, not an observed classification run.

For entry fields, missing or empty `name` selects the pair branch. Missing or empty manufacturer or model UID then returns false. A truthy value with an unsupported type can throw when its string method is called. For device fields, missing or null `interfaceName`, `manufacturer` or `modelId` throws during the unconditional lowercase conversion, after the earlier mode, entitlement and rate gates. Empty device strings do not throw; with the observed nonempty cache values, their applicable equality/substring comparisons fail. The matcher performs JavaScript lowercase conversion on both device and entry strings. It does not normalize whitespace or coerce arbitrary values to strings. These outcomes follow from the retained source; original code was not executed to test malformed values.

The earlier complete retained class evidence `ev_6633cc56846dc24c1803403ef109b67197a17228f64422f75143e8dd616f85b1` also binds cache loading behavior. `loadLists` returns false for a missing file or zero size. It reads UTF-8 and parses JSON. Invalid JSON or either top-level value not being an array returns false; it does not replace the prior allow/block arrays in those failure branches. It validates the arrays, not each entry's field schema. File status/read failures outside its JSON `try` block are not locally caught by that method. The constructor starts with an empty `lists` object, so a failed first load does not supply a bundled default list through this method. This does not establish all caller-level error handling or absence of defaults elsewhere.

Manual additions store the supplied value as an entry `name`. The local matcher compares that name as a case-insensitive substring of device `interfaceName`, not device display `name`. In the normal non-team path, a local blocked match wins over both local allow and manual choice. A local allow match returns `ALLOWED` before checking manual choice. In the separate team-user-choice branch, local manual choice decides the result and local blocked/allowed arrays are not visited. Removing a manual choice uses exact stored-name equality, while matching that choice uses lowercase substring comparison.

The schema-count capture exits zero and retains its complete raw output. Its normalized cleanup is `owned_process_group: verified`, `temporary_root: removed`, with ten supplemental `unverified_processes`, each reason `platform_binary_environment_withheld`. These wrapper processes were left untouched. Owned-group cleanup is verified. The supplemental entries describe the same visibility limitation for unrelated platform wrappers as the preceding cache inventory; they do not report an owned-group cleanup failure or establish that original application processes were launched. No vendor list was copied into the repository.


### Retained capture locations

All three new captures are exported under ignored `evidence/model-probes/`. Each basename below has `.result.json` for the complete canonical Evidence record, `.result.txt` for complete raw PTY output, `.scenario.json` for the exact captured scenario, and `.runner.cjs` for the own inline reader source extracted from that scenario. The scenario retains the executed `node -e` source; the runner file is a later convenience copy, not a separately executed artifact.

- `bvc-compatibility-fields-20261025-v1`, Evidence `ev_18778f368464b2a9e4ef67192d174ff8a8b7a42d22d3f2bd8638fe0074b9d253`.
- `bvc-compatibility-cache-20261025-v1`, Evidence `ev_bf65d20227611a5f87a999080958c3764e25cd504f1d34062dd8de9a1cf6545c`.
- `bvc-compatibility-cache-schema-20261025-v1`, Evidence `ev_a763befd06a4987fd6d43e2aab86f0eeee7b83ce95ceac5e22d7d19ff2785625`.

`evidence/model-probes/bvc-compatibility-20261025.bundle.json` retains the complete exported session bundle with canonical record IDs. This export and the per-capture files were produced from retained REA records, without rerunning the readers.
