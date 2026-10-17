# Offline dual installed adapter

The production `InstalledNoiseAdapter` completed a bounded CPU probe with separate installed outbound microphone and inbound speaker workers. Both processed 105 frames, including five padding frames, and confirmed clean teardown. The aligned microphone output matches the retained direct outbound result byte for byte. Both speaker channels are identical and each matches the retained direct inbound result byte for byte.

No CoreAudio route, microphone, playback, driver change or administrator action ran. Inputs were generated synthetic samples. No vendor files were copied. This verifies this adapter path and fixture, not live audio, sustained deadlines, speech quality or complete parity.

## Evidence and procedure

REA Evidence `ev_0b8f21763dd187e4803927e806f568fa7fc49656251867462dbba4547a86a1dd` records `installed-dual-adapter-20261018-v1`. The helper exited 0. Raw and rendered output are complete. REA reports verified owned-process-group cleanup and removed its temporary root. Scenario, result, independent comparison and private outputs are under `evidence/model-probes/installed-dual-adapter-20261018-v1*`.

`app/audio-host/installed_dual_probe.cpp` was reviewed before execution and built with ARM64/macOS 12-compatible settings, `-O2 -Wall -Wextra -Werror` and `-ffp-contract=off`, with no compiler warnings. The executable SHA256 is `ee3726007860adb8bea62fadac5a2d80714c89a7e7cfc2ac52caa610e1132682`. Its exact build command is in `app/audio-host/README.md`. It calls the actual production adapter, worker builder, broker and packaged signed native adapter/scripts. There is no test worker injection.

The probe generates 48,000 microphone samples using the existing seeded-noise/triangle fixture. The monitor alternates the doubled fixture between left and right channels every 480 samples, leaving the other channel zero. Float32 `(L + R) / 2` therefore yields the exact microphone fixture. This distinguishes averaging from selecting one channel while keeping a known mono reference.

The callback maximum is 512 samples and scheduling budget is two model frames. Both transports report 2400 samples, or 50 ms, of buffering. The probe adds five zero-padding frames and makes 99 paced callback calls, with a short final callback, before waiting for both 105-frame totals. It verifies finite output, silent initial buffering, identical speaker channels and both worker shutdown confirmations. It then removes only the known transport delay and publishes exactly 48,000 microphone samples and 48,000 stereo monitor frames. No model-tail recovery is claimed.

Publication uses a new exclusive mode-0700 directory and exclusive mode-0600 files. Existing destinations reject. Failed publication removes only files whose identities match its owned files. The probe checks bounded regular nonsymlink artifact files and hashes them before startup and after both workers stop. Each production child uses the fixed deny-network sandbox builder and cannot report ready without its EPERM loopback prerequisite and exact role/hash admission.

## Results

| Measurement | Observed value |
| --- | ---: |
| Microphone processed frames | 105 |
| Speaker processed frames | 105 |
| Input frames per lane | 100 |
| Padding frames per lane | 5 |
| Startup for both workers | 197 ms |
| Run, stop and postrun hash checks | 1085 ms |
| Maximum callback exchange | 18 microseconds |
| Maximum CPU scheduling lateness | 5220 microseconds |
| Microphone RMS / peak | 0.0004894399793 / 0.007924040779 |
| Speaker RMS / peak, each channel | 0.009201080300 / 0.07076429576 |

All callback exchanges succeeded. Timing is one short CPU simulation under the observed machine load. The 50 ms value is queue buffering only, not total model or device latency. `runAndStopMs` also includes the postrun artifact hashes. The measurements do not establish a scheduling guarantee.

| Own signal file | Bytes | SHA256 |
| --- | ---: | --- |
| `input-microphone.f32le` | 192,000 | `6ef4b0e40cf74b1bbe3b97b5d36ee79a2e42b9e7eadb9240afe92a2fc2fc7b5b` |
| `input-monitor.f32le` | 384,000 | `dd7b5388148e68c96d1bb174fc0c1703a1d32e4938de78c825ee47aa3f9b489e` |
| `output-microphone.f32le` | 192,000 | `fd389eb36788f4e2f707d63e987fd9205ff6dc1323ef94cd1ab3600960077290` |
| `output-monitor.f32le` | 384,000 | `ecfc4785ddfa286b2a93dff354058994c9b662ad31f857df1b29ecef4d89661b` |

Independent deinterleaving confirms the left/right bytes are identical. Each channel SHA256 is `cf8a006932542aa1eeb9a02e2945e9c9f671804a2bcee7dc92997ab108d90a76`. The microphone matches `direct-nc-on-v1`; each speaker channel matches `inbound-persistent-nc-20261018-v1` and `inbound-paced-nc-20261018-v2`. The earlier inbound reference captures have unresolved REA cleanup limitations, as recorded in `inbound-model-findings.md`. The new dual capture itself has verified cleanup.

## Admitted artifact identities

Every recorded before/after digest matches. Runtime resources came from the frozen signed `Lab Voice.app/Contents/Resources/helper/installed-worker` package.

| Artifact | SHA256 |
| --- | --- |
| Reviewed Node 26.7.0 | `1ef99ea25fe70c9b67e7efe768ef8ee22148d3cabc703db6131b57aeb617d040` |
| Installed addon | `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755` |
| Outbound model | `12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d` |
| Inbound model | `d1e4e2a94fe27dec1a8fd5a7b36cfac38d183a110f738156d85d1317f98fac8a` |
| Packaged signed `native-probe.node` | `216d95381d62f24605103a179d2782c967621baccdf7f06493d76f06b8d26025` |
| Packaged `audio_worker.cjs` | `93c0fda34e544a108f19bf8fec1ee6a4d7219cce8beafbe36de5697ea7a648e8` |
| Packaged `worker_session.cjs` | `3071ac60f848f3109f8f608eea57a82feaeb3eb02d2ce36fa276f250ffcf8888` |
| Packaged `worker_protocol.cjs` | `2d9f55e44af128f36216f7206f4235f4020c9b0fb45eabfebd2e6a56a8c32adc` |

Hashes sample files before and after execution; they are not atomic operating-system image binding. REA process sampling can omit short-lived descendants. No syscall-level network trace was taken. Sandbox denial and the worker's prerequisite check are observed execution constraints, not proof that the libraries contain no network code or attempted connections. The static speaker-channel evidence still covers the selected KMS bridge, not every original desktop speaker configuration. No full-suite rerun was needed because this task added only the standalone probe and documentation.
