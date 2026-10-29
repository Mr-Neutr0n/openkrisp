# Packaged model manifest

REA configuration Evidence `ev_016bcec295d94aa5289ae0b5d7b20c241a7d45e880bb797083c9fd4b59c89def` and bundle inventory `ev_e9c2f082e96a01b0b07c8d7592751b75938b3ad3d2ed21cf8e2db00c3618b818` establish the following static declarations.

| Family | Name | Source-rate range | Work rate | Performance field | Default field | In app bundle |
| --- | --- | --- | --- | --- | --- | --- |
| accent_reduction | ar-inbound-wb-c | not declared | not declared | not declared | not declared | false |
| accent_reduction | ar-outbound-wb-c | not declared | not declared | not declared | not declared | false |
| asr | asr | not declared | not declared | not declared | true | false |
| inbound | nc-inbound-mwb | 0 to 192000 | 16000 | 50 | true | true |
| other | rd-inbound-wb | 0 to 192000 | 16000 | 0 | true | true |
| diarization | diar | not declared | not declared | not declared | true | true |
| outbound | nc-outbound-mfb | 8001 to 192000 | 32000 | 50 | true | true |
| outbound | nc-outbound-sfb | 8001 to 192000 | 32000 | 15 | true | true |
| outbound | nc-outbound-snb | 0 to 8000 | 8000 | 10 | true | true |
| outbound | hvc-outbound-lfb | 8001 to 192000 | 32000 | 75 | true | true |
| outbound | hvc-outbound-sfb | 8001 to 192000 | 32000 | 15 | false | true |

All rate values are in hertz. The manifest declares eight files present in the app bundle and three absent there: the English ASR file and the two accent-conversion files. Absence from this inventory does not establish absence from the Mac or inability to download them. The initial app-bundle inventory did not search downloaded model locations.

The language_detection list is empty. That does not prove language detection is unavailable. Multiple outbound entries declare default=true, so this field alone cannot establish the selected UI default. The meanings of performance, type, optimized and other selection rules require code or runtime evidence.

The manifest names make noise cancellation, voice cancellation, ASR, diarization and accent conversion useful follow-up targets. They do not establish perceptual quality, processing latency, offline licensing, tensor shape, or model redistribution rights.

## Dedicated downloaded-model folder

A later path-only search limited to KEF/model filenames found all three configured filenames under `~/Library/Application Support/krisp/models/`. This is filesystem discovery, not a successful REA content inventory. No account, transcript, recording, log or credential file was read. REA `inspect_artifact` rejected the directory opening route and the three raw KEF files as unsupported. It did not authenticate their digests or decode them. Presence at these paths does not establish loadability, offline activation or redistribution rights.


## Current downloaded ASR identity, 2026-10-29

A bounded REA static read now closes the current ASR file-identity gap. Evidence `ev_bffca013e20279822e6caa4b3c7bd70b84ac30caee158b23ccd8681f01d33ee4` read only the exact current and old ASR paths plus the media addon path. The current `asr_eng_6.3.0_1.0.kef` is a regular 616,329,903-byte file with SHA256 `1720c5ef0a7d921fd6e95be04103ad20dab762ce547ed9d43dd339102262e51f`; descriptor/path identity stayed unchanged while hashing. The exact old 6.2.0 path returned ENOENT. Reader exit was zero, owned-process cleanup was verified, and its temporary root was removed.

No model was loaded or executed, and no directory-wide inventory or user-recording read occurred. This establishes current bytes for catalog validation, not inference compatibility, offline availability or redistribution rights. The two accent model identities remain separate unresolved work. See live-asr-findings.md for the streaming interface investigation.
