# Experimental installed-model probe

This component can process a bounded synthetic signal through the reviewed installed Krisp NC binary. It also supplies the experimental installed-model microphone provider used by the audio host. Live routing remains unverified. It includes no vendor binary, model or header.

`abi_factory.hpp`, `abi_supplier.hpp` and `abi_result.hpp` describe the observed ARM64 libc++ calling convention. The result collector copies borrowed samples during callbacks and rejects incorrect counts, nonfinite samples and excess output. The native adapter preserves original shared ownership and releases the processor before unloading its image. It calls the concrete processor directly without changing SDK state or starting an audio graph.

Run `./verify` on the Mac. It checks independent collector tests and a separate-library ABI fixture in release and ASan/UBSan builds, launcher rejection/publication fixtures, 20 host-only Node adapter validation cases, persistent native-session lifetime/error cases and persistent launcher fixtures. These checks do not load Krisp. `./build_probe` builds `build/native-probe.node` using installed Node headers at `/opt/homebrew/include/node`.

## Explicit model experiment

Use `run_probe.cjs` only inside the reviewed network-denied process. The native `.node` module is internal to this launcher and does not enforce its own identity or sandbox checks. The launcher requires explicit absolute `--addon`, `--model`, `--adapter` and new `--output` paths. It requires loopback failure `EPERM` before loading the adapter and binds the addon to SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. A different installed version is rejected.

The REA runtime scenario uses `/usr/bin/sandbox-exec` with `(version 1) (allow default) (deny network*)`, then `/usr/bin/env` to supply `DYLD_LIBRARY_PATH` for the installed Electron framework's `Versions/A/Libraries`, then Node and this launcher. No microphone or CoreAudio restart is required. The sandbox profile is part of the execution contract; one loopback result alone does not prove all network behavior.

The launcher generates 100 frames of 480 Float32 samples at 48 kHz. Optional `--bypass` and `--suppression-level` from 0 through 100 control the recovered ordinary supplier. On validated success it creates a private output folder containing `output.f32le` and `metadata.json`, including before/after artifact hashes. Existing outputs are refused. No partial run is promoted as success.

Two REA runs against the installed outbound model `c8.f.m.528d1f-1.0.1_1.0.kef` completed with 100 callbacks and 48,000 finite samples each. NC and bypass outputs differ. See `../../native-direct-probe-findings.md` for evidence, hashes and limits. This establishes bounded native processing, not speech-quality parity, complete tail preservation, realtime performance or an app backend.

`run_persistent_probe.cjs` uses the same launcher gates and opens one native session across five process calls of 1, 17, 3, 29 and 50 frames. The adapter exports `open(options)`, `session.process(Float32Array)` and `session.close()`. On 2026-10-17, REA NC and bypass captures each completed five batches, 100 callbacks and 48,000 finite samples with confirmed teardown. Each output is byte-identical to its retained single-call counterpart. The rebuilt adapter digest is `1520a75cee741c8033b49877ac2e59a2156eb6a709ebbd34f28ee4053e8cbd35`. See the findings report for evidence IDs, verification log and process-attribution limits. This verifies the tested batch boundaries only.

This adapter is specific to one inspected binary and libc++ ABI. The first factory argument is lowered to an opaque pointer only because the complete inspected factory body does not use it. Do not generalize this to other symbols or versions. Keep original models installed locally; redistribution rights remain unresolved.

## Provider transport components

`provider_transport.hpp` supplies two fixed-capacity SPSC queues for one serialized audio callback and one broker thread. `exchange` stages 480-sample requests and consumes results at an explicit sample delay. It allocates nothing and does not wait, access pipes or call Node. Missing output at its scheduled sample, invalid values, sequence errors and reported worker failures latch a fault. Supported-size output blocks become silent on failure. Counts above the configured maximum are rejected without touching the destination, so the caller must mute them. Input and output storage must not overlap.

An immutable `ProviderBufferingConfig` sets the maximum callback size from 1 through 4096 and the scheduling budget in 480-sample units. The delay in model frames is `ceil((maximumCallbackFrames + 479) / 480) + schedulingBudgetFrames`. This accounts for partial frames and the whole callback before requesting its output. The budget adds time for broker scheduling; it does not guarantee deadlines. The fixed queues must hold the resulting delay. Configuration errors reject before spawning a worker. The default delay is 5760 samples, or 120 ms at 48 kHz. This is a synthetic test policy, not an accepted live setting or a measurement of model latency. Queue tests cover irregular callback sizes and 20,000 frames with a concurrent broker in release, ASan/UBSan and TSan builds. Test handshakes occur outside the callback and do not establish production scheduling performance.

`worker_protocol.cjs` defines bounded framing for a future pipe worker. Each direction checks a 128-bit session token, a non-wrapping 64-bit sequence and exact finite 480-sample Float32 payloads. Close is terminal. The parser retains at most 1956 bytes, rejects truncated EOF and poisons itself after malformed data or callback reentry. Its callbacks must complete synchronously. A token is a framing identity, not authentication or a readiness acknowledgement.

`worker_protocol.hpp` implements the same wire format for the native broker. Compatibility tests compare emitted bytes exactly and decode each language's output with the other. Both codecs reject malformed frames and do not wrap sequence numbers.

`worker_session.cjs` connects framing to a supplied persistent session through synchronous read/write functions. It handles partial IO and EINTR, validates each processing result and closes the session once on EOF, explicit close or failure. The parent must send close and immediately close its request pipe. The worker acknowledges after teardown and then checks for EOF without trailing bytes. The parent must validate that acknowledgement and child exit. Real OS pipe tests use a synthetic session; they do not load Krisp.

## Supervised worker

`audio_worker.cjs` admits the fixed reviewed addon and an explicit `outbound` or `inbound` model role, plus caller-supplied Node and adapter hashes. Its config requires both `modelRole` and `modelSha256`; each role accepts only its reviewed model digest, and the actual file must match. Missing roles, unknown roles and crossed role/hash pairs reject before loading. `OKREADY2` includes the admitted role and all four artifact hashes, so the broker rejects a role mismatch even when other fields match. It requires loopback denial before loading, opens one model and writes an exact readiness record before processing. The checks sample files before loading; they do not atomically bind files reopened by Node or the dynamic loader. Protocol output uses fd3 so native stdout logging cannot corrupt it.

`installed_worker_launch.hpp` builds the fixed deny-network sandbox command. C++ settings default to the reviewed outbound role and digest. Selecting inbound requires `InstalledModelRole::inbound` and its exact digest together. The audio host and desktop now select each role explicitly for its corresponding lane. It inherits no environment. Inside the sandbox, `/usr/bin/env -i` supplies only PATH and the reviewed library directory before launching Node. This preserves the library path across the platform executable without admitting NODE_OPTIONS, NODE_PATH or other loader variables.

`WorkerBroker` starts the direct child, validates readiness and exchanges one frame at a time through nonblocking parent pipes. It applies startup, frame and shutdown deadlines. Close requires a teardown acknowledgement, response EOF and reaped exit status 0. Errors terminate only its owned child, escalating TERM to KILL with bounded reap polling. The broker must be the child's sole reaper; it does not supervise arbitrary descendants.

`ProviderWorker` connects the callback queues to this broker on a dedicated thread. The callback only copies samples and reads atomic state. Control-thread stop joins the broker thread; callback removal must succeed before releasing the owner. Idle checks detect child death or unexpected output even without another audio callback. Synthetic tests cover callback output order, broker failures, repeated stop and stop during confirmed stalled processing, including TSan.

`installed_worker_probe.cpp` exercises the production builder and broker with a caller-provided one-second synthetic Float32 file. It publishes output exclusively after confirmed close. Building it does not execute the installed addon. Runtime evidence is recorded separately in `../../native-direct-probe-findings.md`.

The launcher supplies its own PID to the worker. Before opening the installed model, `native.watchParent` starts a native guard that checks `getppid()` every 25 ms. Parent loss calls `_exit(72)` in the worker even if its main thread is blocked. It never signals another PID. Normal shutdown stops and joins the guard. Detection depends on scheduling; abnormal exit skips C++ cleanup and relies on OS process-resource reclamation.

`timed_worker_probe.cpp` defaults to 112 callbacks at 10 ms intervals after startup: 100 input frames and 12 zero-padding frames. Options `--maximum-callback-frames N` and `--scheduling-budget-frames N` select a different immutable bound and delay. The probe chunks input at that callback bound, paces by sample position, and pads by the computed delay. For example, 480/1 selects 30 ms; 512/2 selects 50 ms. The final callback may be shorter. It removes only the computed queue delay, waits for all requests, then publishes 48,000 samples after clean stop. REA NC and bypass runs passed with zero queue deadline failures and byte-identical aligned output. This is paced CPU testing, not CoreAudio acceptance, a speech-quality comparison or model-tail recovery.

The desktop and routing helper can now select this worker through the processor preparation hook and validate its startup identity. The helper uses the aggregate's maximum callback bound and a two-frame scheduling budget. The desktop packages only our adapter and worker scripts, with hashes taken after signing. It requires the exact reviewed external Node and addon, with the outbound microphone or inbound speaker model pinned separately. Actual HAL routing and sustained timing remain unverified; 120 ms buffering for a 4096-frame bound is not an accepted live latency budget.

`timed_worker_probe` accepts `--model-role outbound|inbound`, defaulting to outbound. The role selects its fixed model digest; it does not permit arbitrary models. The inbound paced capture returned output identical to the direct mono probe, but REA ownership cleanup remained incomplete. See `../../inbound-model-findings.md` for exact scope and metrics.

### Synthetic AEC foreign ABI fixture

`./verify` also builds `aec_fixture.cpp` as an own dylib and runs
`aec_fixture_test.cpp` against it in release and ASan/UBSan modes. No installed
library is loaded. The producer declares its layout independently from
`aec_abi.hpp`. Checks cover the 24-byte ARM64 stream specification, selected
virtual slots, 100 separate 32 kHz mono forward / 48 kHz stereo reference
10 ms frames, in-place Float32 output, virtual deletion and foreign exceptions
from factory and both frame calls. The library remains loaded until engines
and caught exceptions have been destroyed, including unexpected error paths.

The fixture admits only 16/32/48 kHz and one or two channels with exact finite
10 ms frames. These are test bounds, not established vendor support. Unused
virtual declarations only preserve slot positions and must never be called.
This fixture does not prove echo quality, rate conversion, original scheduling
or compatibility with a loaded vendor library. It is separate from production
NC admission and does not provide a runtime AEC launcher.

### Standalone direct AEC experiment

Build the own CPU-only executable with:

```sh
clang++ -std=c++20 -arch arm64 -O2 -Wall -Wextra -Werror -pedantic \
  aec_direct_probe.cpp -o build/aec-direct-probe
```

Its positional arguments are `libraryPath forward-input.f32le
reference-input.f32le reference-on.f32le reference-zero.f32le`. The default multitone run uses two fresh engines. Each engine processes 300
10 ms blocks, with reverse analysis before forward processing for each block. Forward is 32 kHz mono, reference is 48 kHz stereo. A shared
continuous-time 233/617/1229 Hz multitone generates the reference and a 50 ms
delayed, 0.6-scaled forward echo with no near-end signal. The zero-reference
control receives the same forward samples. No delay setter is called.

The four exclusive 0600 files contain 96000 forward floats, 288000 reference
floats and 96000 floats per output. All are Float32 little-endian. Publication
requires both engine destructions and library unload, every status zero,
finite outputs, completed writes and unchanged output inode identities.
Failures remove only matching owned files. The caller must use a private
output directory without concurrent writers; these path checks are not an
atomic transaction across files. JSON reports all-sample and last-second RMS,
call counts and elapsed time. Three seconds is an exploratory adaptation
window and gives no quality acceptance or desktop timing claim.

Append `--broadband` to select a ten-second baseline. It generates 160001 base
samples at 16 kHz, including one interpolation lookahead sample. A xorshift32
sequence starts at seed `0x91e10da5`, advances with shifts 13, 17 and 5, then
maps the low 16 bits to `(value - 32768) / 262144`. Linear interpolation at
integer sample positions produces the 32 kHz forward and 48 kHz reference
streams from this shared base. The forward stream starts with 1600 zero
samples, then uses the same 50 ms delay and 0.6 gain. Both reference channels
are identical. There is no near-end source.

Broadband mode makes 1000 reverse and 1000 forward calls per engine. It writes
320000 forward floats, 960000 interleaved reference floats and 320000 floats
per output. JSON identifies the selected mode, fixture, seed, rates, channels
and reference sample count. The default multitone stimulus is unchanged.
The ten-second stimulus supports a later alignment and adaptation experiment;
fixture tests do not establish vendor cancellation or delay estimation.

The own-fixture checks cover both modes, all interpolation phases, the exact
forward delay and gain, repeatable broadband bytes, duplicate-output refusal,
rollback, symlink refusal and foreign exceptions. Release and ASan/UBSan runs
use only our dylib.

`./verify` runs this executable only against the own synthetic fixture in
release and ASan/UBSan modes, including output collisions, symlinks, partial
publication rollback and foreign factory/processing exceptions. The fixture
exports the exact factory lookup name, so the probe has no test-only symbol
or vendor-admission bypass option.

Vendor execution is a separate REA-reviewed experiment. Before `dlopen`, its
runner must pin the executable and full library SHA256
`bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a`,
apply a deny-network sandbox and clean environment, then repeat hashes after
exit. This executable does not hash or sandbox itself. The runner must bound
wall time because a synchronous foreign call can stall. No vendor execution
is part of the fixture verification.

### Synthetic double-talk diagnostic

`aec_doubletalk_probe.cpp` is a separate bounded CPU experiment. Build it with
the standalone command above, substituting `aec_doubletalk_probe.cpp` and
`build/aec-doubletalk-probe`. Its arguments are `libraryPath newOutputDirectory`.
The probe creates that directory exclusively with mode 0700 after all engines
are destroyed and the library is unloaded. The caller must provide a new path
inside a private directory without concurrent writers.

The ten-second far reference uses the broadband source above. The echo has
a 50 ms delay and gain 0.6. An independent xorshift32 source uses seed
`0x6a09e667`, the same base rate and interpolation, and gain 0.6. This near-end
source starts at forward sample 96000, exactly three seconds into the run.
The forward mixture is the Float32 sum of echo and near-end samples.

Four fresh engines process mixture with the actual reference, mixture with
zero reference, near-end alone with zero reference, and echo alone with zero
reference. Each engine makes 1000 checked reference-first reverse calls and
1000 checked forward calls. The probe does not set delay or configuration.
It publishes eight exclusive 0600 Float32 little-endian files:

- `reference-input.f32le` contains 960000 interleaved stereo values.
- `echo-input.f32le`, `near-input.f32le` and `mixture-input.f32le` each contain 320000 mono values.
- `mixture-reference-on.f32le`, `mixture-reference-zero.f32le`, `near-reference-zero.f32le` and `echo-reference-zero.f32le` each contain 320000 mono values.

JSON reports fixture identity, seeds, gains, delay, onset, dimensions, call
counts and teardown. The own-fixture tests check every generated sample,
mixture arithmetic, fresh zero-reference controls, repeatability, publication
refusal and foreign exceptions in release and ASan/UBSan modes. Broadband
noise is not speech. These tests establish no speech preservation or vendor
quality result. Processed mixtures may differ from the sum of processed
isolated controls, so residuals cannot uniquely identify echo or near-end
components without checking this interaction.
