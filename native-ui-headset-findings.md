# Native desktop observation, 2026-10-28

The signed own app at checkpoint `bd4d4d7` was launched through macOS LaunchServices, using REA capture of `/usr/bin/open -W -n`. This produced a usable launch-time identity where the earlier direct executable launch had not. This is an observed change for this launch, not proof that all REA lifecycle issues are resolved.

The observed executable SHA256 was `49898854f2ea2bc7e89aaad204f0ca72768f9ec17b285b11f59d7a0ac8205a9c`.

## Accepted observations

- Window inventory `ev_97363b52f0f9e906fc86d9aa2c1846d3eec89b0c9fea658b92e0a0d1b8c9e3e5` found own PID 49994 and main window 558997.
- Home observation `ev_553c141e40811474a6f4a878d1053aaaaf5a25169ee443f1975bee8067cdbeca` returned a complete accessibility tree without gaps, screenshot and a completed bounded wait. The app showed Audio stopped and an empty local library.
- Audio-button action `ev_5aa5efdf352b746d5588845323992aa9b21c487553b9b15d85cbe46e0e0b18ed` completed. The screenshot showed the Audio sheet with microphone/speaker choosers, RNNoise provider defaults, disabled Start and a driver-unavailable message. No Start or microphone test was pressed. This confirms navigation and basic visible controls, not device routing or automatic headset policy interaction.

Raw records and PNGs remain private under `evidence/headset-ui-*20261028*`. No user recordings or original assets were read.

## Incomplete launch lifecycle

The launch capture reached its 60-second bound and returned `cleanup_incomplete`. The ownership token for launcher PID 49954 was unavailable. Both SIGTERM and finalization SIGKILL delivery were unverified; exit and settlement were unavailable. The temporary root was retained. This is not an accepted clean process capture.

A later provider-popup attempt returned `target-mismatch: Selected PID does not expose an application executable URL`; it produced no accepted interaction. A read-only process check then found both known PIDs 49994 and 49954 absent. Their exact termination cause is unknown. No unrelated candidate process was signaled.

The accepted native observations remain independent evidence of those exact window states. They do not make the launch lifecycle successful. Automatic mode selection, cache picker, manual confirmation, original visual parity and audio acceptance remain open.

## Longer bounded observation

A fresh 180-second LaunchServices attempt allowed an independent second Audio observation, `ev_0331ccf5d1ed0b1037462ec83f74c3d82ea8f31aae53b544f04d56ea135cdf2b`, on own PID 68720/window 559023. It again showed stopped audio, RNNoise defaults, no selected devices, driver unavailable and disabled Start. Screenshot `evidence/headset-ui-auto-audio-20261028.png` has SHA256 `daa3283ca9189e05ede18f9203eb41af4c5e6e891a1769fd0ac1a974626040af`.

The provider popup action failed with `ambiguous-window` and no matching accessibility window candidates. Inventory `ev_7cf900dc47c235a66adaebc54009650431a3e5fef94812f1cb36834e78b83d8f` found the same own main window with app active=false. No broader window was selected and no alternate input tool was used. Automatic controls were never displayed or accepted. No provider selection, list import or manual confirmation mutation completed.

The launch tool then returned a 180-second MCP transport timeout without normalized exit or cleanup evidence. A read-only check found known app PID 68720 absent. Launcher identity was not exposed by the timed-out result, so launcher cleanup remains unverified. Exact wrapper error is retained in `evidence/headset-ui-auto-launch-20261028.result.json`. This attempt does not establish a clean launch lifecycle.
