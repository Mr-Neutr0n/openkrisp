# Offline transcript timing checkpoint

Desktop import preserves recognized times through review, storage and timed text export. The previous import path replaced recognized word segments with one recording-wide paragraph. This change uses the existing transcription and store contracts; it changes desktop code only.

An unchanged recognition draft retains each segment's text, order and start time. Its end time is start plus duration. The draft must match the selected standardized file URL and exact formatted recognition text. The first text edit invalidates the timing candidate, even if the user later restores the original text. Changing the selected file also clears it. Failed or cancelled replacement recognition keeps the previous candidate; late results and stale library revisions cannot publish a replacement.

Import rejects invalid or nonfinite times and confidence, and segment ends beyond the actual WAV duration. It does not clamp or sort segments or invent speakers. Manual text and results without segments retain the prior single recording-wide text entry.

Timed export uses the original segment text on separate lines with the existing millisecond-formatted start markers. The formatted recognition paragraph is not stored separately, so its punctuation or layout can differ from exported word text. Desktop phrase search joins stored segment texts with spaces and still matches titles and speakers. The separate `LocalStore.search` API remains per-segment.

Full desktop verification passed 138 tests and signed packaging/relocation checks. Focused coverage passed 22 tests, including seven new timing tests. The unchanged local-transcription and local-store suites passed 14 and 12 tests. Tests use own WAV fixtures and injected recognition, with no Speech prompt, real recognition or hardware audio.

This establishes independent timing retention and lifecycle behavior. It does not establish original runtime timestamp parity, recognition accuracy, live ASR, diarization or full feature parity.

Verification logs and SHA256:

- `evidence/transcript-timing-local-transcription-verify-20261023.log`: `57eacd32abab9ca067872fe5948531c4d5f33a5f233d23f249d703baa9af1ff8`
- `evidence/transcript-timing-local-store-verify-20261023.log`: `7a31ad53ae070d24ec5825955416931dee73c48c26d7e617819f9f3a19a52d61`
- `evidence/transcript-timing-desktop-verify-20261023.log`: `3dae16820385bfedd235c3746941dd01eec430e44639d2c9609ca41ed395d580`
