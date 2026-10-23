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
