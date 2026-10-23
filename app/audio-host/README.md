# Physical audio host

This directory now contains a concrete private-aggregate backend, bounded audio routing, lifecycle cleanup, and optional RNNoise processing. It has compiled and passed injected-backend tests. No real aggregate, microphone capture, playback, installation, or rate change has occurred during verification.

Build the sibling noise engine first, then run `./verify`. Verification builds the CLI and `build/libaudio_host.a`, reads actual HAL inventory, and runs routing/lifecycle tests in release and with AddressSanitizer plus UndefinedBehaviorSanitizer. The noise-engine sources remain owned by their separate component. This directory only includes its headers and links its built static libraries.

## Commands

These commands read properties only:

```sh
./build/audio-host --list
./build/audio-host --plan --input 'physical-input-UID' --output 'physical-output-UID'
./build/audio-host --aggregate-plan --input 'physical-input-UID' --output 'physical-output-UID'
```

Both planners return status 2 with `runnable: false`. They produce proposals without creating audio objects. Inventory returns status 0. HAL failures return status 1. Invalid command syntax returns status 64. Outputs from verification stay under ignored `build/`.

The following explicit command starts real microphone capture and playback through a newly created private aggregate. It has not been run here and requires installed companion endpoints and a separately authorized runtime test:

```sh
./build/audio-host --route --input 'physical-input-UID' --output 'physical-output-UID'
```

Suppression defaults to disabled. Add `--noise-suppression` or `--microphone-noise-suppression` for microphone processing. Add `--speaker-noise-suppression` for independent left/right speaker processing. Flags can be combined. The CLI reports enabled processing only after the real route has started successfully. Ctrl-C or SIGTERM requests stop. A device change or callback fault silences and stops the route without automatic restart.

## Aggregate and format contract

The backend resolves the hidden UIDs `dev.hari.labvoice.feed` and `dev.hari.labvoice.monitor` through HAL UID translation. Physical selections are explicit UIDs. Existing default devices and other aggregates are not changed.

The actual backend requires every member to be alive and currently at 48 kHz. It never sets a hardware rate. Hardware capture must have one or two channels. Hardware playback must have two. Every included stream must be contiguous, native-endian, packed Float32 PCM at 48 kHz. Interleaved and noninterleaved Float32 layouts are supported. Other sample types, rates, layouts, and channel selections fail preflight. For a stereo physical microphone, this first implementation selects channel 0. It does not mix the channels.

The composition uses a fresh UID, `private=1`, Feed as the main clock source, Monitor next, and then selected hardware. Hardware input/output sharing one UID is deduplicated. Distinct UIDs sharing a clock domain remain distinct members. Both companion clock domains must match and be nonzero. Drift correction is disabled for those two shared-clock endpoints and explicitly enabled at high quality, value 96, for physical members.

`CoreAudio/AudioHardware.h` defines process-private, nonpersistent aggregation; the main subdevice UID as time source; per-subdevice drift settings; and subdevice list order as the order of aggregate streams. The SDK symbol uses `MainSubDevice`, while the dictionary key remains `master`. Privacy applies to the aggregate object. It does not make the underlying public or hidden devices private or prevent other clients from using them.

After creation, the backend reads back the ordered full member list, active members, main UID, private composition flag, alive state, nominal rate, drift settings, buffer-frame bounds, native stream formats, starting channels, and buffer configuration. It derives channel maps from the verified order and actual channel counts. It verifies again after listeners are registered to close the preparation interval. Any mismatch fails start and triggers rollback.

There is no custom drift estimator or asynchronous resampler. The design delegates independent physical-clock synchronization to HAL's aggregate drift correction. This is a concrete backend design, but its drift behavior has not been measured on an installed route.

### Mixed nominal rates

This Mac runs macOS 26.4.1. Apple's [macOS 26 guide](https://support.apple.com/guide/audio-midi-setup/set-aggregate-device-settings-ams094c7edb4/3.6/mac/26) requires matching nominal aggregate rates. Apple's [macOS 27 guide](https://support.apple.com/guide/audio-midi-setup/set-aggregate-device-settings-ams094c7edb4/3.6/mac/27) separately documents synchronization that converts differing or fixed rates. That does not establish the same contract on installed macOS 26. Therefore a 24 kHz-only input is blocked. A device supporting 48 kHz but currently using another rate also remains blocked until a separately authorized rate change succeeds.

## Callback routing and processing

`Context::io` reads the actual aggregate input buffers and writes the aggregate output buffers. It copies the selected physical microphone channel to mono Feed, and stereo Monitor to the selected physical stereo output. Unused output channels are zero. Buffer maps may contain interleaved buffers or single-channel planes.

The fixed limits are 4,096 frames, 16 buffers per direction, and 64 total channels per direction. Scratch arrays and model state exist before start. The callback allocates no memory, acquires no mutex, logs nothing, and performs no property writes or lifecycle operations. A try-once atomic flag rejects unexpected callback reentry without spinning. Nonfinite sample values become zero. Input and output frame counts must agree. Missing input planes become silence. Invalid format/size/timestamp or processor failure marks the route dirty for the control thread to stop. The SDK says HAL ignores an IOProc's returned status, so the real block adapter does not rely on that return value to stop audio. HAL supplies zeroed output buffers on entry; an unsupported output shape is left untouched and the route is disabled.

Client input/output sample timestamps must be valid, finite, and nonnegative. Fractional timestamps are accepted by this client engine. They remain a separate installed-driver compatibility check because the current driver ring interface requires integral frame positions. Input sample time is the acquisition time; output sample time is the scheduled delivery time. The callback does not treat their difference as zero latency or infer delay from buffer size.

With no processor, the route copies samples directly. `NoiseAdapter` optionally invokes the existing `StreamingNoise`. Every enabled mono channel owns fresh state for each CLI route. Partial callbacks accumulate into 480-frame inference blocks. Each enabled path adds exactly 480 frames of adapter buffering, in addition to RNNoise's algorithmic delay and the driver's 960-frame route delay. Speaker channels use independent states; this does not claim spatial preservation, echo cancellation, or voice isolation. Actual processing time and complete latency still require measurement.

The library accepts a bounded `noexcept` processor and optional `shared_ptr<void>` ownership. Production RNNoise state is retained by `Context`, and callback code uses its raw pointer without per-call ownership copies. Any raw custom processor data supplied without ownership must remain valid until every callback context has been released, including cleanup failure paths.

## Lifecycle and failure behavior

`Session` operations belong to one control thread. Start creates the private aggregate, verifies layout, registers change listeners, revalidates, registers a client IO block, enables its context, and starts IO. Each completed step has a matching rollback. A failed create returning an object ID and a failed IO registration returning a token are also cleaned up. A failed start is followed by stop because IO may have partly started.

Listeners cover alive state, nominal rate, device buffer size, direction stream lists, and stream virtual formats for the aggregate and its members. Listener callbacks only mark the context dirty. The CLI services control work every 20 ms. There is no automatic device-rate change or automatic restart after topology failure.

Stop first disables rendering. It stops IO, removes its registration, removes listeners, drains active callbacks for at most two seconds on the control thread, and destroys the private aggregate. Aggregate destruction is asynchronous according to the SDK. Cleanup errors retain state for retry and prevent another start in the same session.

HAL block callbacks hold shared ownership of their context. Queued or in-flight callbacks can therefore outlive Session teardown safely. The context also owns production processor state. If stop, unregistration, or drain persistently fails, callbacks remain disabled and their memory stays valid through HAL-held blocks. OS resources may remain until explicit cleanup succeeds or the creating process exits. This favors memory safety over freeing callback resources prematurely. The backend must outlive its Session.

## Verification and remaining runtime evidence

Read-only tests use actual HAL properties for physical inventory, missing UID translation, current formats/rates, and dry aggregate proposals. Device counts can change as hardware connects or disconnects. These snapshots are saved in `build/inventory.json`, `compatibility-plan.json`, `aggregate-plan.json`, and, when a mismatched device is present, `mixed-rate-blocked-plan.json`.

All routing and lifecycle tests use an explicitly injected backend. They are not real HAL audio evidence. They check exact mono/stereo/planar channel routing, unused-output silence, variable frame counts through 4,096, oversized/invalid buffers, missing planes, nonfinite values, every startup rollback stage, partial returned handles, cleanup retries, topology stop, concurrent callback drain, queued context lifetime, processor failure, and processor ownership after persistent stop failure plus Session destruction. Optional processing tests invoke the real vendored RNNoise and check bypass behavior, first-block buffering, and finite outputs. They do not establish speech quality.

No runtime route has been tested. Installed validation must establish hidden companion admission, actual subdevice UID/drift readback, format and channel maps, callback limits, driver fractional/integral timestamp behavior, simultaneous public/companion IO, long-run drift compensation, real DSP deadlines, microphone authorization/attribution, total latency, hot removal, partial-failure cleanup, and normal/crash exit. The desktop now packages the individually signed helper and RNNoise license notice, declares microphone usage, and requests microphone access only on its explicit Start action. Actual OS attribution of capture from the helper remains unverified. No feature or audio parity pass is claimed.


## Live attenuation and mute controls

Microphone and speaker gains default to 1 and mutes default to false. Gains are finite Float32 values in 0..1. They apply linear attenuation after the processing stage. Mute forces zero after processing, including for nonfinite output. DSP state keeps advancing while muted, so unmute cannot replay an old suppressed block. Gain adds no extra hard clipping; nonfinite output is zero. These are independent app-route DSP controls. They do not write physical device volume, HAL scalar volume, system mute, or any original app preference. The observed original scalar range is also 0..1, but its transfer curve and whether the original enables driver scaling remain unverified. This is not original volume parity.

A callback reads one packed lock-free 64-bit snapshot for both paths and uses it for the entire output buffer. The gains use all Float32 precision; each gain's otherwise unused sign bit encodes its mute flag. There are no callback allocations, locks, protocol reads, or acknowledgements. UI gains should be canonicalized as `Double(Float(value))` before serialization. Accepted acknowledgements echo the actual canonical Float32 values.

Preselected state can be supplied with `--microphone-gain VALUE`, `--speaker-gain VALUE`, `--microphone-muted`, and `--speaker-muted`. The complete initial snapshot is installed before IO is enabled. The flushed `route_started` event includes microphone/speaker objects showing that initial state. Existing manual CLI behavior still defaults to unity gain and unmuted audio.

### Opt-in stdin protocol

Add both `--control-stdin` and `--operation-id UUID` to enable controls. Without that opt-in the helper never reads stdin. The operation UUID appears in the startup event. Each stdin command is one newline-terminated JSON object with a complete desired snapshot:

```json
{"type":"controls","operationID":"12345678-1234-1234-1234-123456789abc","sequence":1,"microphone":{"muted":false,"gain":0.5},"speaker":{"muted":true,"gain":0.25}}
```

Commands must match the current operation UUID. Sequences are positive integers no larger than 9,007,199,254,740,991 so they round-trip safely in JSON. Every well-correlated, correctly shaped control command consumes its sequence even if its gain payload or lifecycle state is rejected. A later sequence must increase. Unknown or extra fields, duplicates, wrong types, missing state, unsafe sequence values, nonfinite/out-of-range gains, wrong operations, stale commands, and commands after route stop are rejected without changing the controls.

The helper emits and flushes an acknowledgement on stdout from its control thread:

```json
{"type":"controls-ack","operationID":"12345678-1234-1234-1234-123456789abc","sequence":1,"accepted":true,"publication":"next-callback","microphone":{"muted":false,"gain":0.5},"speaker":{"muted":true,"gain":0.25}}
```

Accepted means the complete snapshot was atomically published for subsequent callback reads. It does not prove that a physical frame has played. A callback that has not read its controls yet may also use the update. Rejected replies have `accepted:false` and an `error` string. An invalid frame that cannot be correlated uses sequence 0 and the current operation ID. Callers must not treat those uncorrelated errors as acknowledgements of a pending command. Stdout also carries the startup event and human diagnostics, so clients must distinguish each JSON event type.

The input pump uses nonblocking `poll`, reads at most 4,096 bytes at a time, retains at most one such unread chunk plus a 4,096-byte partial line, and processes at most eight completed commands per control-loop turn. Overlong lines are discarded through their newline and rejected. A partial final command is rejected as `truncated_at_eof`. EOF in control mode requests graceful route shutdown. SIGTERM and parent-process loss also stop the route. The control thread performs all parsing, validation, stdout flushing, and lifecycle operations; the audio thread sees only atomic state.

Control tests check actual callback gains/mutes after DSP, continued state progression while muted, invalid state preservation, startup state before IO, late lifecycle rejection, and complete snapshots under simultaneous publication. Release and ASan/UBSan tests also exercise strict schemas, correlation, sequence limits, split/oversized framing, bounded backlog, and EOF. `build/control-wire-fixture` is a test-only stdin/stdout executable using the real C++ parser and atomic state with no CoreAudio, for cross-language Swift pipe verification. It is not a production CLI mode and is not packaged with the app. All live control and original transfer-curve validation remain pending an authorized installed test.

## Independent local session recording

Recording starts only from an explicit `recording-start` command on an already running `--control-stdin` route. The default CLI captures no file. Recording commands use a separate positive sequence counter bounded by the JSON safe integer limit. Each command includes `operationID` and a UUID `recordingID`. Start also requires an absolute `.wav` path in an existing directory owned by the current user with mode 0700. The helper creates the file exclusively with mode 0600 and refuses existing files or a symlink at the final file or directory component.

The strict NDJSON command types are `recording-start`, `recording-pause`, `recording-resume`, and `recording-stop`. ACKs use `type:"recording-ack"`, the same IDs and sequence, `action:"start"|"pause"|"resume"|"stop"`, and `accepted`. Rejections include `error`. A start ACK means the private file and writer thread are ready. A stop ACK means drain was requested. The subsequent `recording-result` carries `status:"completed"|"failed"`, IDs, path, written `frames`, `sampleRate:48000`, `channels:2`, and `clippedSamples`. Failed results include `error` and `partialFrames`. Desktop must import only a completed result, then independently validate the WAV. A failed result remains authoritative even if failed disk finalization leaves an apparently valid header. The helper attempts to invalidate headers on failure; storage faults can prevent that write.

The independent stereo mix records routed outputs after DSP and live gain/mute. Left is 0.5 times the routed microphone plus 0.5 times routed speaker left; right uses speaker right. This fixed headroom covers full scale inputs. The writer converts to little endian PCM16, saturates values outside [-1,1], and reports the number of clipped samples. The original meeting mix and mute placement remain unknown. These controls do not alter hardware volume properties.

A stable Context-owned queue holds 65536 stereo Float32 frames, about 1.365 seconds at 48k. The serialized callback performs bounded copies and lock-free atomic publication. It does no allocation, file I/O, logging, or locks. A writer thread converts samples and writes disk data. It writes the RIFF header and duration only after a clean producer drain. Queue overflow, disk error, invalid callback shape, route/topology/processor failure, sample clock discontinuity, or RIFF size exhaustion produces failure. Recording failure does not itself stop the audio route. The RIFF limit is a format bound, not a product quota.

Pause disables capture, advances a generation, and waits up to 2 seconds for current producers. Resume resets the expected sample clock and excludes the paused interval from duration. A callback already processing before pause cannot publish stale audio after resume. Contiguous fractional input and output sample-clock origins are supported; progression must agree within 0.000001 sample. Other clock gaps fail the recording instead of compressing missing audio into a successful WAV.

Orderly route stop, SIGTERM, stdin EOF, and parent exit request finalization before route cleanup. A 2 second shutdown timeout reports `writer_shutdown_pending`, with the last fully written frame count, and aborts finalization. The writer retains its storage until it exits; failed HAL cleanup cannot free buffers or join an active writer from the callback thread. Unexpected process exit has no completed result and leaves staging evidence for the desktop. The test-only `build/recording-wire-fixture` supplies synthetic samples through the real protocol and writer; it is not packaged. No real audio recording or device route has been validated.

## Temporary microphone noise comparison

`--microphone-test --input UID --directory ABSOLUTE_PRIVATE_DIRECTORY --operation-id UUID --control-stdin` is a separate explicit capture mode. It needs no virtual driver or aggregate. The selected physical device must already be alive at 48 kHz with supported native packed Float32 client input streams and a buffer size no greater than 4096 frames. Unsupported devices fail with no fallback, sample-rate setter, or default-device change. Duplex output streams are disabled for this IOProc alone. Any unexpected bounded output buffers are zeroed. Physical microphone channel 0 is captured once; the original and processed clips derive from those same samples.

The callback has a preallocated 2,880,000 sample mono buffer, which bounds a test to 60 seconds of captured media. It performs no allocation, logging, file I/O, or locks. Fractional sample-clock origins are supported; contiguous progression must agree within 0.000001 sample. Gaps, nonfinite input, unsupported callback shapes, reentry, and topology changes fail explicitly. Three seconds without captured-frame progress fails as `microphone_callback_stalled`. Both limits are independent temporary-test design policies, not original product limits or paid quotas. A 60 second captured-frame maximum automatically stops capture and processes the pair.

The flushed startup message is `{event:"test_started",operationID,input_uid,sampleRate:48000,channels:1,minimumFrames:240000,maximumFrames:2880000}`. Progress messages use `event:"test_progress"` and the captured `frames`, at most 4 times per second. They continue during processing without inventing additional captured duration. Typed stdin commands contain exactly `type:"test-stop"|"test-cancel"`, `operationID`, and a positive JSON-safe integer `sequence`. ACKs use `type:"test-ack"`, the same IDs and sequence, `action:"stop"|"cancel"`, and `accepted`; failures also include `error`. Stop before 240000 captured frames rejects with `minimum_duration` and keeps capture active. Cancel always works. EOF, SIGINT, SIGTERM, and parent loss cancel. The owning parent is saved before capture preparation and rechecked after start. Reparented orphan jobs are rejected.

Only a successful device stop, IOProc removal, listener removal, and callback drain allows offline processing. HAL blocks retain callback storage when cleanup fails; no valid samples can turn a failed teardown into a completed pair. Processing runs on a background thread. The control loop continues polling cancellation, and an observed cancel prevents success even if the worker result is already ready. A cancellation that cannot finish processing within 2 seconds reports cancellation with `processing_cancel_pending` and never publishes playable success. The desktop must await actual child exit before playing or deleting staging files.

Offline processing uses a fresh pinned RNNoise state. The writer creates exclusive mode 0600 `original.wav` and `processed.wav` in the owned mode 0700 job directory. Both are 48 kHz PCM16 mono with exactly the captured frame count. The raw sample clip is not recaptured for comparison. Processing flushes 480 zeros and removes the StreamingNoise adapter's known 480 frame buffering delay; RNNoise's total algorithmic delay remains unmeasured. No subjective quality or original algorithm parity is claimed. Values outside full scale saturate during PCM16 conversion.

The final JSON uses `event:"test_result"`, `operationID`, `status:"completed"|"cancelled"|"failed"`, `frames`, `sampleRate:48000`, `channels:1`, `engine:"RNNoise"`, `adapterBufferingFrames:480`, and `adapterDelayAligned:true`. Completed results also provide `originalPath` and `processedPath`. Failures include `error`. Only a completed result plus clean child exit and independent file validation permits comparison. Failed or cancelled staging may contain partial files, which must never be treated as successful clips. Nothing enters recording history or cloud storage.

Release and ASan/UBSan tests use synthetic samples and injected lifecycle failures. Processed PCM is checked against direct pinned RNNoise frame inference, including a partial final block. The test-only `build/microphone-test-wire-fixture UUID DIRECTORY [INPUT_UID]` runs the same production controller with a synthetic backend. Its fixture failure hooks never appear in the production CLI. Actual microphone IO, permission attribution, and audible comparison remain unverified. Verification does not invoke the native microphone-test mode.


## Installed microphone and speaker providers

The desktop can independently select the exact reviewed installed outbound microphone model and inbound speaker model. Other lanes use selected RNNoise processing or passthrough. Installed speaker processing averages stereo into one mono stream and duplicates the processed result, matching the selected original KMS bridge. It does not preserve the stereo image while active. `InstalledNoiseAdapter` combines the two paths without calling Node or waiting inside the callback. The processor factory receives the aggregate's validated maximum callback bound before IO registration. It uses a two-frame scheduling budget and reports the resulting queue delay.

The internal helper interface adds `--microphone-provider installed-krisp` plus `--provider-node`, `--provider-worker`, `--provider-addon`, `--provider-model`, `--provider-adapter`, `--provider-library`, `--provider-node-sha256` and `--provider-adapter-sha256`. Microphone suppression must be enabled. The speaker lane uses `--speaker-provider installed-krisp` and the same eight runtime option suffixes under `--speaker-provider-`; speaker suppression must be enabled. Each group derives its own pinned role and model digest. Missing, repeated, unsupported or malformed provider options reject before aggregate creation. The worker verifies the fixed addon/model and supplied Node/adapter hashes before callbacks start. There is no automatic RNNoise fallback on failure.

Startup ACKs identify both providers. Installed microphone metadata retains `provider_*` fields; installed speaker metadata uses `speaker_provider_*`. Each includes its four hashes, maximum callback size and queue delay. Idle worker failure stops the route. Both worker configurations validate before either child starts. Partial startup stops the first worker. A separate control-owned adapter attempts to stop both workers even when one worker or HAL teardown fails; retained Context memory keeps late callbacks safe. A control-scope guard also stops both workers during exception unwinding. Tests use synthetic children and no hardware audio. Actual installed-model routing, complete latency and speech quality remain unverified.

## Offline dual installed-provider probe

`installed_dual_probe.cpp` exercises the production adapter and two installed workers with generated microphone/stereo samples. It never creates a CoreAudio route or opens an audio device. Build from the experiment root after building RNNoise:

```sh
clang++ -mmacosx-version-min=12.0 -std=c++20 -ffp-contract=off -pthread \
  -O2 -Wall -Wextra -Werror -Iapp/noise-engine/vendor/rnnoise/include \
  app/audio-host/installed_dual_probe.cpp app/native-model-probe/worker_broker.cpp \
  app/noise-engine/build/release/librnnoise.a -o app/audio-host/build/installed-dual-probe
```

Compilation does not load vendor code. The positional arguments are `node runtimeDir addon outboundModel inboundModel library adapterSHA workerSHA sessionSHA protocolSHA newOutputDir`. Node and both model roles have fixed reviewed pins. The four supplied hashes bind the already reviewed packaged adapter and scripts. Runtime execution belongs in an explicit REA process capture. The production builder applies network denial to each child and requires its EPERM gate before loading.

The probe generates the known one-second mono fixture and alternates its doubled value between left and right monitor channels. Their Float32 average is exactly the mono fixture. It uses a 512-sample callback bound and two-frame scheduling budget, pads by the derived 2400-sample delay, then requires both 105-frame counts and clean worker stops before publishing exclusive mode-0600 files in a new mode-0700 directory. Output contains the aligned first 48,000 samples per lane. It validates finite output, silent initial buffering and identical speaker channels. Before/after hashes do not atomically bind loaded images. Results and timing limits are in `../../dual-installed-adapter-findings.md`.


### Optional duplex reference hook

`ProcessorBinding` can carry a `DuplexBinding` after the existing speaker stage.
The factory must explicitly declare `microphoneStageDisabled`; the initial hook
uses raw microphone input and does not chain microphone NC. The hook is not yet
connected to the CLI or desktop. Existing bindings follow the original path.

The route computes final playback after speaker processing and gain/mute into
preallocated storage. One final enabled/changed check commits the callback before
the hook receives that exact stereo reference. Later shutdown or hook failure
cannot revise this callback's playback. Failure silences its microphone and
ends subsequent callbacks. This preserves the reference even when a hook returns
false after publishing part of its input. The next callback stays silent.

Sample origins describe the aggregate callback input and scheduled output. A
reference input origin is not historical capture time before speaker buffering.
Host-time validity remains explicit. The hook owner stays with Context through
failed HAL cleanup and queued callbacks. Synthetic tests verify byte equality,
clock fields, gain/mute, speaker delay, failure/stop races and retained ownership.
Actual AEC binding, physical timing and live playback remain pending.
