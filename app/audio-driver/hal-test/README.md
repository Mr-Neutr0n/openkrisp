# Actual HAL synthetic routing check

This helper checks the independent Lab Voice virtual routes through the real CoreAudio device I/O API. It opens no physical microphone or speaker and changes no default device, format, buffer size, volume, driver installation, or system setting. Audio starts only with the explicit `--run` argument. The no-argument and `--inventory` modes only read exact Lab Voice device properties.

Run `./verify` to build the ad-hoc signed helper at `build/LabVoiceHALTest.app`, verify its signature, and run release plus AddressSanitizer/UndefinedBehaviorSanitizer callback fixtures. The build targets macOS 12 on the current architecture. Generated artifacts are ignored. Verification does not create a CoreAudio I/O procedure or start any audio device.

## Endpoints and preflight

| Exact UID | Direction used | Channels | Expected visibility |
| --- | --- | --- | --- |
| `dev.hari.labvoice.feed` | Output producer | Mono | Hidden |
| `dev.hari.labvoice.microphone` | Input consumer | Mono | Public |
| `dev.hari.labvoice.speaker` | Output producer | Stereo | Public |
| `dev.hari.labvoice.monitor` | Input consumer | Stereo | Hidden |

System UID translation selects each endpoint, and the returned device UID must match exactly. The helper checks its owner plug-in identifier `dev.hari.labvoice.audio`, virtual transport type, shared clock domain `0x4c564143`, visibility, alive state, nominal 48 kHz rate, and physical and virtual stream formats. Formats must be packed interleaved Float32 with one stream and the declared channel count. Input devices must declare the expected 960-frame route latency. `--run` also requires all four endpoints to be idle before registration. Close other Lab Voice host clients first. A client that starts after preflight can still affect the mix and invalidate results.

Read-only inventory after building:

```sh
build/LabVoiceHALTest.app/Contents/MacOS/LabVoiceHALTest --inventory
```

The read-only checkpoint on this Mac returned the first UID, `dev.hari.labvoice.feed`, as unavailable with status 0 and an unknown device ID. It exited with a failed inventory summary and did not open audio. The remaining endpoints were not inspected after that failure. This is consistent with the pending driver installation, not proof of a routing defect.

## Explicit synthetic run after approval

Run only after the user approves driver installation and this virtual-audio test:

```sh
build/LabVoiceHALTest.app/Contents/MacOS/LabVoiceHALTest --run
```

The helper registers four I/O procedures and starts only the four checked virtual devices. Producers generate deterministic timestamp-indexed samples with peak magnitude below 0.018 in normalized Float32. Channels and restart epochs use distinct patterns. There is no microphone signal, speech file, network traffic, transcription, or physical playback. No recording is written.

The planned media interval is 2.6 seconds, plus CoreAudio setup and cleanup calls:

1. Consumers run alone for 150 ms. Their samples must be zero.
2. Producers start, settle for 100 ms, then run for 800 ms with epoch 1 patterns.
3. Running producers emit a known zero-signal interval for 150 ms.
4. Producers stop. Consumers continue for 350 ms of settling and 150 ms of checked silence.
5. Producers restart with epoch 2 patterns, settle for 100 ms, then run for 800 ms.
6. The helper stops and destroys every created I/O procedure. Cleanup errors are reported.

System API calls can take longer than the planned interval. This is not a hard wall-clock deadline. Actual elapsed time is reported. Callback work accepts at most 4096 frames and uses preallocated timestamp records and lock-free counters. It uses no allocation, mutex, retry loop, disk I/O, or logging in callbacks. Contexts remain alive until process exit, including on a cleanup error path, so an outstanding callback cannot access a freed context.

## Measurements and verdict

Each producer records the sample time passed to its client callback. Each consumer compares input frame R with the recorded producer frame R minus 960. The expected sample comes from that frame's channel and actual emitted epoch. A stamp mismatch or overwrite is counted as `noProducerStamp`, not converted into a successful comparison. The tolerance for finite sample differences is `1e-6`.

Inventory rows contain `uid`, `deviceID`, `sampleRate`, `channels`, `hidden`, `running`, `alive`, and `bufferFrames`. Only endpoints that pass strict validation produce rows. Inventory stops on the first missing or invalid endpoint with stderr details and a false summary. Output consists of JSON lines for inventory, every endpoint's counters, and the final summary. Counts include callbacks, valid frames, matched and mismatched frames, missing producer stamps, zero and nonzero frames, nonfinite frames, layout errors, invalid timestamps, callback overlap, observed sample-time range, timestamp discontinuities, and maximum finite absolute comparison error. A zero maximum with no comparisons does not mean a successful route. Planned media time and measured elapsed time are separate fields. Error text and OSStatus codes go to stderr. Exit status is nonzero for any failed required check or lifecycle API call.

A passing route requires real callbacks, more than 1000 producer and matching consumer frames in each steady epoch, no missing producer stamps or mismatches in those steady intervals, startup silence, stopped silence, and a checked zero-signal interval. Producer callbacks must cease during the checked stopped interval. Invalid layouts, timestamps, overlap, or nonfinite input fail the check. Warmup and stop-settle frames remain in the report but are not scored for exact transfer.

The zero-signal interval tests a known quiet interval. It does not create an unwritten timestamp gap in the driver. Producer stop and restart create an observed client timeline gap when the host keeps its clock running; discontinuities are reported. The 350 ms stop wait exceeds the driver's 250 ms stale threshold, but stopped silence can also result from generation invalidation. This does not independently isolate the driver's heartbeat-expiry path.

The expected 960-frame delay is a declared independent-driver contract. A failure can expose a difference between client timestamp conventions and driver cycle timestamps, scheduling, or the driver itself. It does not identify the cause by itself. The reported time ranges and counts support that investigation. No actual device latency, physical routing latency, speech quality, or original-app parity is established.

## Permission and verification limits

The helper bundle has its own identifier, `dev.hari.labvoice.haltest`, and a microphone usage description that names synthetic virtual input. It has no permission-request API call. macOS may still require audio-input consent or reject an input start. If a prompt occurs, identify this helper and obtain the user's consent before continuing. Driver installation approval alone is not permission to grant an OS prompt automatically. The helper never chooses a physical device as a fallback. It reports failed start and cleanup statuses.

Build and callback fixtures pass in release and under AddressSanitizer/UndefinedBehaviorSanitizer. Fixtures exercise mono and stereo sample-time matching, initial and stopped silence, intentional zero samples, a valid lifecycle verdict, deliberate wrong samples, timestamp rejection, and overwritten producer records. A malformed route cannot produce a successful fixture verdict. These are helper tests, not real HAL routing tests.

`--run` has not been executed. No CoreAudio I/O procedure has been created and no audio device has been started during preparation. Real HAL acceptance, scheduling, live callback counts, cleanup behavior, OS consent, and end-to-end timing remain unverified.
