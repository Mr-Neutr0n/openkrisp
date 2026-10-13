# Independent desktop runtime checks

REA launched the built ARM64 Lab Voice application through LaunchServices. Evidence `ev_7e79f9c040c966f7d36f3d7c386fe3e0eba9ba4042ecf048f1e8431be25cccd4` captures its initial empty local library. The screenshot shows import, settings, refresh and history search controls, with audio processing explicitly unavailable in this build.

Evidence `ev_7c258cb610ba182a2e1b86e6a2a2da0430f408ef08eb66da3dbf92b75cdb3a21` records a completed Settings button action and an open sheet. Its App tab contains System, Light and Dark controls. The screenshot shows System selected, following the Mac's dark appearance. That build duplicated the appearance label. The source now hides the Picker's redundant label and aligns the App controls to the left. This small layout correction still needs a fresh visual capture.

Evidence `ev_d654dd5e943e25c087b158d236229eb68e5c45d86e60102cba31ccffe99b39f2` records a completed Light action and a light screenshot. Its next wait/capture failed with an audio/video stream error. Later steps, including Dark, did not run. Other attempts returned an empty AX window candidate list while the app was inactive. These failures are retained; the multi-step roundtrip did not pass.

The owned runtime then expired. On relaunch, the app's own persisted `appearance` preference remained `light`. A new REA scenario opened Settings and selected System, both actions completed in `ev_e50333c7acd9cb1943023d340182884ef0eb33b860c135ac44db54d628bb8e76`. A read-only check of the independent app's preference domain confirmed `system`. This restores the test preference. No original Krisp preference was changed by these checks.

Initial library rendering, Settings reachability, Light rendering, persistence and System restoration are verified within these runs. Dark rendering, real import/playback/export/delete workflows and model selection UI are not yet verified interactively. Component tests and relocated signed-bundle resource lookup remain separate evidence. These checks do not establish original-app parity.
# Audio integration follow-up

The signed build now includes the Audio sheet and routing helper. A fresh REA launch identified Lab Voice PID 65369 and its main window 222486. Both an initial observation and an observation immediately after explicit REA activation failed exact-window matching: CG bounds were `(330, 206, 810, 497)`, while the Accessibility candidate had no bounds (`nil`). The second attempt disabled screenshot capture and returned the same geometry failure. These are window-matching failures, not Accessibility permission denials. No Audio control was clicked, no audio route started, and this build's Audio view remains interactively unverified. Private records: `evidence/desktop-audio-initial-ui.json`, `desktop-audio-activate.json`, and `desktop-audio-active-ui.json`.


## Locked-session diagnosis

A fresh owned launch on 2026-10-13 selected PID 34716/window 222490. REA screenshot-only observation, with Accessibility disabled, failed with `capture-failed: Failed to start stream due to audio/video capture failure` in private `evidence/desktop-window-pixels.json`. Read-only host discovery then identified foreground `com.apple.loginwindow` PID 408 and `CGSSessionScreenIsLocked=true`, `kCGSSessionOnConsoleKey=true`. The Mac is locked at this checkpoint. This explains a current interactive-test blocker; it does not retroactively prove the cause of every earlier failure. No lock-screen action or unlock attempt was made. Resume fresh UI observation only after the session is unlocked.

## Live-control build checkpoint

The Audio sheet now includes independent app-route mute and 0-to-100% linear attenuation, with scrollable content and fixed header/Start/Stop footer. Twenty-three desktop tests pass, including the actual C++ control protocol over pipes. Lost acknowledgments invalidate confirmed state; delayed messages cannot affect a replacement route. The complete root verification passes in `evidence/combined-verify-live-controls.log`. These checks do not exercise the visible controls or actual audio. The Mac remained locked at the latest host metadata check, so no new visual result is claimed.


## Recording verification checkpoint

The root `./verify` passed all ten suites with exit 0 after recording integration and lifecycle fixes. Private log: `evidence/combined-verify-recording.log`. The desktop has 32 passing tests. Synthetic Swift-to-C++ pipe tests validate recording commands, PCM16 finalization, active-frame duration and history import. The signed app build and relocated-resource checks pass. No actual audio was captured. The approved driver installation and CoreAudio restart succeeded, but exact endpoint lookup failed, so real routing remains untested pending registration diagnosis.


## Unlocked current-build UI check

The unlocked Mac permitted fresh REA capture of the independent app. Initial library evidence `ev_2700fd817c51e1178eaab6f8f7dd08ee22c6350b5a6a88e66f38eab5e3163693` shows Audio stopped and the empty local library. The Audio button action completed in `ev_30941c29cee36045fd7c996e988e1c80eed98b2b8ae88b3df1fc86ed06c2fe46`. Its screenshot shows the Audio header, device choices, independent RNNoise options, 100% app-route volumes, mute rows and fixed Start footer. No audio route started.

That capture exposed a real storage defect: retained-recording inspection failed with Cocoa error 516 because the existing Lab Voice application-support directory was created again without allowing reuse. RecordingStorage now creates that directory only when absent, then validates and reuses it. The new fixture regression uses an existing temporary application-support directory and creates multiple independent jobs. Focused desktop `./verify` passed 33 tests and signed/relocated bundle checks after this isolated fix. A fresh Audio capture `ev_9b6abef41a31523ea714fe5f759d3393a5e8e64d84d6a9d9d907956de2870e08` contains the recording-off state without the retained-inspection error.

The recording block is present in the Accessibility tree, including its description and three controls. Its lower visual layout is not yet verified. A scrollbar button AXPress completed in `ev_2a568830228c9b03728286fdad96316c10a85c177ea47e6ca8ed78c162e431ea`, but the viewed screenshot did not move. REA's selected scrollbar AXIncrement failed with AXError -25206 in `ev_88167f1f7f62b496dac809cc66e9e8595abbe96dd9d5b8f398c255ca08fd9235`. Neither request establishes successful scrolling.

Settings opened in `ev_8880f6552b2be2cc26ba31512ce7b905aeff337676f4082dfd238f87487db545`. Dark selection and System restoration both completed in `ev_4133d193a79f7f04c156017a0fb5c7058a921b49ed7c579a995df0bc150f2ce1`; their screenshots were viewed and show the respective selected controls. The Mac's System appearance was already dark, so this run does not establish a light-to-dark rendering transition. System remained selected after a fresh launch in `ev_0b8d1e6627162ac3d43809af4ab1e5763646874047663774a6ead9d5d0fc511d`.

Cleanup was limited to the two owned launches. PID 73645 and then PID 50152 were each checked against the exact built LabVoice executable path before SIGTERM; both were confirmed absent. The two REA open-W captures exited with code 0. No unrelated process was signaled. No Audio Start, recording Start, permission prompt, user-file import, or original-app action occurred. Raw envelopes and screenshots are retained privately under `evidence/desktop-recording-ui-*`.


## Offline widget checkpoint

The independent floating widget is implemented with persisted visibility, explicit Show/Hide commands, shared audio and recording state, microphone/speaker mute controls, acknowledgment status and Stop audio. Closing hides it without stopping the route or discarding a pending recording. Its independent default is hidden; the original factory default is unknown. Desktop verification passed 36 tests and signed-bundle checks. No widget window was launched while the user was away. Original widget behavior, talk-time, captions and visual parity remain open.

Driver diagnostic files remain installed but await the deferred CoreAudio restart. No new administrator action, permission request or audio test ran during this offline checkpoint.
