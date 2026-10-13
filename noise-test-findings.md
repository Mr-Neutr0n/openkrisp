# Microphone noise test workflow

Current catalog Evidence `ev_58c2d2c98cd0dc8a434233efa30e9e4448d97ecb7441ea8fc36caaa79099b6f4` describes an explicit local sample test, a five-second minimum instruction, with/without comparison, repeat, Done, and confirmation when quitting during recording. It also asks users to unmute the Krisp Microphone before starting. These are observed shipped labels, not an exercised UI state machine or DSP contract.

The catalog belongs to the current 3.17.9 checkpoint, whose plist Evidence is `ev_3a54568811b26cf5484325645d4ec772d8a425f658baf6e523ffd035b522b820`. No app UI, audio, settings or permissions were changed for this report. The Mac's earlier locked state was not used to justify further UI attempts.

## Observed controls and messages

All rows cite the current catalog Evidence above. Preserve exact key attribution; behavior in the final column is limited to what the wording supports.

| Phase/context | Exact keys and relevant text | Supported observation |
| --- | --- | --- |
| Entry | `nav_btn_test_nc`, `companion.test_nc`, `window_title_test_nc`: “Test Noise Cancellation”; `test_my_audio`: “Test my audio” | Test entry/window labels exist. Exact Mac reachability and menu placement are unverified. |
| Before capture | `test_nc.start_to_test_audio`: “To test the audio, start the recording.”; `test_nc.press_to_record`: “Press to start” | Capture has an explicit start affordance. Automatic capture on opening is not established. |
| Mute admission | `text_unmute_krisp_for_test_nc`: “Unmute Krisp Microphone to start testing Noise Cancellation” | The text refers to the Krisp microphone. It does not require changing physical hardware mute, nor prove automatic unmuting. |
| Recording | `test_nc.text_recording`: “Recording...”; `test_nc.min_record_info`: “Record at least a 5-second sample to hear the difference.” | A five-second minimum is instructed. Button disabling, sample-count versus wall-time enforcement and handling a shorter recording are unknown. |
| Guidance | `test_nc.try_to_clap`: “Try to clap and talk at the same time 👏”; `test_nc.ac_try`: “Talk with your natural voice and pace” | Speech plus transient-noise guidance exists. It is not a quality threshold or proof of accent processing in this NC test. |
| Comparison | `test_nc.without_krisp`: “Without Krisp”; `test_nc.with_krisp`: “With Krisp ✨”; `test_nc.switch_the_toggle_for_magic`: “Switch the toggle – hear the difference?” | A user comparison toggle is described. Default selection, replay position and whether switching restarts playback are unknown. |
| Processing wording | `test_nc.magic_time`: “Time for magic”; `test_nc.vc_is_on`: “Voice Cancellation is ON.”; `test_nc.vc_is_off`: “Voice Cancellation is OFF.” | Processing/status labels exist. “Voice Cancellation” does not prove BVC, AEC or a particular SDK processor. |
| Repeat/finish | `test_nc.record_again`: “Record again”; `test_nc.btn_done`: “Done” | Repeat and close/finish controls exist. Repeat cleanup and exact Done behavior are unverified. |
| Quit during capture | `test_nc.cancel_testing`: “Recording is in progress”; `test_nc.cancel_testing_confirm`: “Are you sure you want to quit the test?” | A capture-time quit confirmation is described. Confirm/cancel button labels, whether capture continues while the dialog is open and cleanup order are unknown. |
| Failure | `test_nc.error_occurred`: “Error occurred”; `test_nc.try_again_later_testing`: “An error occurred during the testing. Please try again later.”; `test_nc.problem_with_recording`: “Something wrong with the recording?” | Generic failure/retry-later guidance exists. There is no recovered typed error-to-state mapping or guaranteed retry button. |
| Troubleshooting | `test_nc.report_problem`: “Report a problem”; `test_nc.issue`, `report_problem.test_nc_issue`: “Having issues with testing noise cancellation” | A report affordance exists. Original remote submission is excluded; a local diagnostic export is a separate independent design. |
| Temporary/local policy | `test_nc.recording_will_not_leave_device`: “Your recording will never leave your device and won’t be saved.” | The test promises local, unsaved recordings. This does not prove no temporary disk writes, a cleanup implementation or crash-safe deletion. It is distinct from saved meeting recording. |

## Candidate state model, not a runtime trace

This table is a reconstruction hypothesis supported by the labels. Transitions requiring control timing or actual capture remain acceptance work.

| State | Candidate action | Next state | Evidence and uncertainty |
| --- | --- | --- | --- |
| Ready | Explicit Start, microphone unmuted | Recording | Entry/start/unmute labels. Permission, device and active-call admission are unresolved. |
| Recording | Finish sample after at least five seconds | Preparing comparison | Minimum instruction and “Time for magic”. A separate Stop/Finish test button is not identified by these labels; its trigger is unknown. |
| Preparing comparison | Successful preparation | Comparison | With/without labels suggest two audible choices. File format, two buffers versus reprocessing and source alignment are unknown. |
| Comparison | Toggle with/without | Comparison | Comparison wording. It does not establish parallel live paths or toggle latency. |
| Comparison | Record again | Ready or Recording | Repeat label. Immediate restart versus an idle prompt is unknown. |
| Recording | Quit | Quit confirmation | Explicit capture-in-progress confirmation. Continue/abort semantics require verification. |
| Any active test state | Error | Failure | Generic error text only; cancellation is not proven to share this state. |
| Comparison/Failure | Done or close | Closed | Done label exists. Final cleanup and default restoration remain unknown. |

## Calls, native support and unresolved contracts

No NC-test-specific active-call restriction was found in the retained current labels. `in_person_recording.note_taker.call_tooltip` says “You can’t take a note while in a call”, but belongs to in-person notes, not NC testing. `allowed_to_switched_on` says “You can only change it once during the meeting”, with an unresolved referent. Neither establishes an NC-test admission rule. Live-recording NC-disabled labels likewise do not prove test availability during a call. An independent test may reject concurrent routing to avoid capture conflicts, but must label that as its own policy.

Current static device-recorder Evidence `ev_03e31793b114208efefd2e68567f4341ad706c16f1bd65c44fbcbcf7688f3102` and `ev_40ab92b005f05d1ca15e14b38419d9339ff5e6ebab8122c1c42d08f414ba06a7` establish start, pause, stop, file-open/write failure and sample-derived duration behavior in native-utils SHA-256 `17eb466b1092c37b0bbc8e04d4a29163a9fbef1a5e1e802be7c842dd59bc94ea`. Zero configured duration defaults to 60 seconds in that component. Its caller is not connected to the NC-test UI by retained evidence. Do not impose that maximum or pause semantics on the NC test as original behavior.

Current MediaSP file/player settings Evidence `ev_b861f861d6fd5d73f723fda8b3a71fdd1a9a72d7cb6350823cd37d3735988d92` and `ev_94ae630db3fe9e81ac277fbb09db07f0d09c6bc66788f12819bddc6ef4703def` names WAV/MP3 file formats and `fileId`, `filePath`, `fileFormat`, `volumeFactor`, `originalVolumeFactor`. These are native capabilities, not an authenticated NC-test graph. See [recording-findings.md](recording-findings.md) for scope and identities.

The following remain unknown: physical versus virtual microphone source; microphone-only versus mixed input; raw capture versus processed capture; NC model/parameters; whether both comparison outputs come from the same samples; pre/post gain, mute, AEC or BVC order; playback channel/rate/format; maximum duration; minimum enforcement; record stop trigger; call admission; playback seek/restart behavior; temporary storage location and cleanup; cancel/error/close ordering; restoration of previous device/settings state.

For an independent implementation, explicit selected-microphone capture, a five-second sample-count check, one shared source for bypass/processed comparison, and no library import or upload are reasonable design choices. They must be described as independent choices until the original contract is established. No paid, trial or commercial usage limit belongs in this local test. Any technical capture bound must be stated independently and must not be inferred from the native recorder default or unrelated meeting limits.
