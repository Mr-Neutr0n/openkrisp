# Local session storage

This independent Swift library saves completed recordings and transcripts to a caller-selected directory. It has no network client, account, analytics, automatic retention, or model integration. It does not capture or transcribe audio.

`LocalStore.save` imports a finalized WAV and transcript segments, or a transcript alone. It copies recordings in 1 MiB blocks into a private staging directory. Files use mode 0600 and new directories use 0700. The original recording stays unchanged. A successful save publishes the complete session directory by rename on the same volume. Failed saves keep their staging directory and stay out of normal history. `inventory` reports these entries for a future recovery UI. It also isolates corrupt sessions so other history remains readable.

The manifest stores a schema version, UUID, title, start time, duration, segments, and an optional fixed recording filename. Start time uses Swift Date's numeric seconds since 2001-01-01 UTC and retains fractional seconds. Search matches titles, text, and speakers. Text export refuses to overwrite an existing file. Deletion requires an explicit caller action. No automatic deletion runs.

Run `./verify` with the macOS Swift toolchain. Tests exercise a complete audio import and export, unchanged source bytes, private file modes, failed imports and reopening, corrupt manifests beside healthy sessions, timing validation, history order, and file reference validation.

The catalog supports local storage, transcript search, save, and permission/storage errors. Source: REA Evidence `ev_ece7c942d90e27f063fd1be188d354a1a8d0f289e59aadea32bb6dc209566fa7`. The original storage schema is unknown. This format and its behavior are implementation choices, not a compatible reader for Krisp files.

Remaining work includes recording capture, ASR, pause/resume, the four-hour live-recording limit, recovery controls, storage selection locked during calls, integration with the app, and comparison with original behavior. Audio import checks the RIFF/WAVE signature, not every media chunk. The caller must finalize and validate the audio. File synchronization and same-volume rename do not prove survival of every power-loss case. Export can leave a partial new file if disk I/O fails. A caller must show that error. Disk operations must not run inside audio callbacks.
