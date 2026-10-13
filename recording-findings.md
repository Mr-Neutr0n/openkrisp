# Recording findings

The retained evidence describes several recording products, not one recorder. Meeting audio, live/in-person notes, temporary NC tests, screen recording and cloud bots must remain separate. The native device recorder supports frame-skipping pause and a sample-derived duration limit. The graph file recorder writes its received frame buffer, but the original meeting graph's source selection, mixing and processing order remain unresolved.

## Current UI vocabulary

Current catalog Evidence `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4`, `evidence/current-translations.json`, contains these exact controls and messages. They are shipped labels, not exercised UI behavior.

| Scope | Keys and text | Established limit |
| --- | --- | --- |
| Audio lifecycle | `click_to_pause_recording`: “Pause Recording”; `click_to_stop_recording`: “Stop Recording”; `click_to_finish_recording`: “Finish Recording”; `web_dashboard.audio_recording_paused`: “Audio Recording paused” | Distinct active/paused/finished wording exists. Resume action and timeline semantics are not established by these labels. |
| Local storage | `note_taker_storage.local_info`: “Save transcripts and recordings locally on your device. On-device storage currently supports English only.”; `local_store_info`: “Your transcripts and recordings are saved directly to your device, and stay private to you.” | Local saving is explicitly offered. English restriction refers to the combined note-taking product, not proof of an audio codec restriction. |
| Location controls | `note_taker_storage.select_location`, `choose_new_location`, `browse_for_location`; `call_in_progress`: “This setting is locked during calls. End your call to change storage location.” | Folder selection and call-time locking are described. Filename layout, overwrite policy, atomicity and save timing remain unknown. |
| Local failures | `location_not_accessible`: “Permission denied. The app can’t save files to the selected folder.”; `location_not_available`: “Selected folder doesn't exist. Please choose a valid folder on your device.” | Missing/inaccessible folder states are explicit. Recovery behavior is not exercised. |
| Capacity | `error_storage_full`: “You can't record. The storage is full.”; `note_taker_tooltip.recording_storage_is_full` | A full-storage block is described. Its local/cloud quota attribution and exact threshold are unknown. |
| Live/in-person | `in_person_recording.long_meeting_dialog.description`: “Krisp supports recordings of up to 4 hours. Your recording was saved successfully.”; `new_meeting_dialog.save_and_switch_btn`: “Save & switch” | Four hours is observed only in this live-recording namespace. It is not established as every recorder's limit. |
| Live processing | `in_person_recording.nc_tooltip`: “Noise Cancellation is disabled during Live Recording.”; `ac_tooltip`: “Accent Conversion is disabled during Live Recording.” | The labels explicitly differ from processed meeting recording. Actual graph configuration is not recovered. |
| Temporary tests | `test_nc.min_record_info`: “Record at least a 5-second sample to hear the difference.”; `test_nc.recording_will_not_leave_device`: “Your recording will never leave your device and won’t be saved.” | A minimum sample and temporary local test policy are described, distinct from saved meetings. |

The catalog also describes system-audio permission (`no_audio_access`), audio recording announcements, cloud bot recording, and screen recording unavailable with on-device storage (`screen_recording_local_info`). These do not establish that local audio recording must use a bot or cloud service. Trial, paid-plan and admin gates are not part of OpenKrisp's requested implementation.

## Focused current native evidence

All original reads used REA capture-process with static exact-symbol disassembly. No original app launch, device start, IO registration, audio capture or setting change occurred. The locked-Mac UI was not retried.

- Device lifecycle: `ev_03e31793b114208efefd2e68567f4341ad706c16f1bd65c44fbcbcf7688f3102`, `evidence/recording/device-lifecycle.result.json`.
- Device construction/start: `ev_40ab92b005f05d1ca15e14b38419d9339ff5e6ebab8122c1c42d08f414ba06a7`, `device-start.result.json`.
- Graph lifecycle: `ev_f5df68333651c84d4ff750f1a8f2b785ca8eac0c0baf7a4d84c6353cc0cd9d53`, `graph-lifecycle.result.json`.

The first two records check unchanged native-utils SHA-256 `17eb466b1092c37b0bbc8e04d4a29163a9fbef1a5e1e802be7c842dd59bc94ea`. The graph record checks unchanged MediaSP SHA-256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. All static helper processes exit 0. Older native addresses must not be reused for native-utils, whose current addresses differ from its retained earlier inventory.

### Device recorder

`DeviceRecorder::Start` creates the miniaudio context, resolves a device, creates that device, creates the encoder and starts the device in that order. Success clears accumulated duration and paused/error flags and marks started. Failures branch out at each initialization stage. These instructions establish a direct selected-device recording path; they do not establish that meeting recording uses it.

Its constructor takes file path, device name, a duration value and error callback. The duration is converted to milliseconds by multiplying by 1000. A zero duration becomes 60000 ms. Thus this native component's zero-argument-value default is 60 seconds, not the live UI's four-hour limit. The caller's actual values and product route remain unknown.

`Pause(bool)` requires started state, returns success without work if already in the requested state, and otherwise stores the pause flag. The device data callback returns before encoder writes when paused or marked stopped/error. Pause omits those frames rather than inserting silence in this component. After a successful write it adds `1000 * framesWritten / encoderSampleRate` to recorded duration using integer division per callback. This is sample-derived active duration, not wall time including pause. The limit check precedes the next write, so a final complete callback can exceed the threshold by one buffer. No exact buffer duration was recovered.

The callback has distinct failure paths for maximum duration and failed file writes, marks the error/stop flag and invokes an asynchronous error callback. Encoder creation logs failed opening the file. `Stop` clears started, marks stopped/error and releases the device, encoder and context resources. The examined stop path does not perform a separate export/save dialog or rename. Final file-header behavior belongs to encoder teardown and was not exercised. Container/channel/rate/bit-depth values for this direct-device path remain unresolved.

### Graph recorders

`FileRecorder::ProcessFrameBuffer` processes pending settings, checks whether the processor can process and whether its media file is ready, then passes the received buffer directly to a media-file write call. It returns the same buffer metadata downstream. This is a graph tap, not proof of a microphone-plus-participant mix. Its position relative to NC, accent conversion, mute and mix must come from the original graph builder, which the retained partial JavaScript graph does not expose.

`FileRecorder::Start` requires frame specification and media-file factory, starts the base processor and logs file path. `Stop` stops the base processor and closes its media file; a nonzero close result logs `MediaFile.Close failed`. `StreamRecorder` settings read `recorderId` and `channelNumber`, which support a separate manager/channel architecture but do not reveal channel assignments or mixing weights in the app.

Retained exact native settings Evidence `ev_b861f861d6fd5d73f723fda8b3a71fdd1a9a72d7cb6350823cd37d3735988d92` identifies file-format enum 0 Invalid, 1 WAV and 2 MP3, plus `filePath`/`fileFormat` settings. This establishes available native formats, not the original local meeting default, sample encoding or filename extension. No original output file was created or validated.

## Independent recording contract and remaining gaps

The transport worker reports OpenKrisp's explicit recording path as a processed stereo microphone-plus-speaker headroom mix, started only by a user click while the route runs. That is an independent implementation choice. It must not be labeled original ordering or mixing parity. Coordinate its output finalization, pause behavior, duration display and failures with the local store and audio verification worker.

Unresolved original semantics: meeting microphone-only versus mixed tracks; participant/system source scope; separate channels versus summed mix; pre/post NC/AC/gain/mute placement; meeting pause duration/silence behavior; save naming and finalization; default format and encoding; local capacity accounting; limits outside the live namespace; resume and retry behavior; crash recovery and partial-file handling. The historical JavaScript graph names start/pause/stop and create/destroy recording APIs, but partial coverage cannot connect these product routes reliably. Preserve that uncertainty rather than merge the native device test recorder with the graph meeting recorder.
