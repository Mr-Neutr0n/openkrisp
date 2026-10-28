# Current driver discovery checkpoint

Read-only checks on October 23, 2026 at approximately 19:10 Asia/Kolkata confirm that the deferred restart remains the next discriminating step.

The installed `/Library/Audio/Plug-Ins/HAL/LabVoiceAudio.driver` has bundle identifier `dev.hari.labvoice.audio`, version `1`, and signed tree SHA256 `5ca286e9483c605f82ecdfabeb830fd640dd5cd534eef3f390a4bef0b98dea95`. Strict signature verification passes. Its executable SHA256 is `02f34771ea1584cf861300c22a1101948645463b3bd2056c8c1a5d17c9e712fa`. This matches the preserved discovery-trace build in `app/audio-driver/install-notes.md`.

Current process inspection confirms `coreaudiod` PID 94316 and the own `Core Audio Driver (LabVoiceAudio.driver)` process PID 94405 both started October 13 at 10:27:21 local time. The receipt still records installation at 10:34:07 that day. Both running services therefore predate installation of the discovery-trace build. This is a fresh process observation, not an assumption based on the old checkpoint.

Root's current host inventory reports both companion endpoints absent without inventory errors. A bounded last-20-minutes unified-log query for `LVDiscovery` or the own driver name found no driver events. The retained `evidence/driver-discovery-trace.log` contains standalone `host-test` events only. The older install log shows a remote load attempt for an earlier build; it does not establish that HAL loaded the installed discovery-trace binary.

The evidence does not yet identify a loader or driver-code defect in the installed debug build. During an authorized audio interruption window, confirm the same installed identity, restart CoreAudio once, record fresh daemon and own remote-driver start times, then run the existing no-IO `discovery_probe.swift` and capture bounded own-driver discovery logs. Do not rebuild or reinstall merely to perform this test. A restart may expose the actual defect rather than fix it, so usable device registration remains unproven.

No installation, removal, restart, audio IO, administrator prompt, original artifact inspection, or vendor execution occurred in this assessment.


## Read-only recheck, 2026-10-28

Fresh process metadata still shows coreaudiod PID 94316 and the own remote driver PID 94405 starting October 13 at 10:27:21. Neither service has restarted since the deferred discovery-trace installation. The current own audio-host `--list` reports both feed and monitor companion endpoints absent and an empty errors list. Private inventory `evidence/driver-inventory-20261028.json` has SHA256 `587bf472092ed93db5ed19ccc86538a9951c09cd645a0c0f8ac11c0a5bab7640`. No IOProc, capture, playback, restart or installer ran. This does not verify the installed binary identity again or establish that the current daemon loaded it. The deferred administrator restart remains the next discriminating driver step.
