# Installed accent engine

This separate macOS ARM64 adapter uses exact, externally installed Krisp AR
models. It contains no vendor image, weights or downloader. The installed
model license and redistribution status remain unknown. Run original artifacts
only through REA during development.

The current packaged catalog declares the outbound model's source accent as
`any`, the inbound model's source as `inbound`, and both outputs as `us`.
These are original catalog values. A successful model call does not establish
perceptual accent quality. See [the runtime findings](../../accent-engine-findings.md).

## Build and verify

Run `./verify` from this directory. It builds `build/accent-probe.node` using
the local Node C API headers and tests only repository-owned foreign-ABI
fixtures. It does not open any original file, model or audio device.
Broker and wire tests also run with AddressSanitizer and UndefinedBehaviorSanitizer.

## Host contract

Include `installed_launch.hpp` and link `worker_broker.cpp`. Construct
`accent_engine::InstalledAccentSettings` with explicit `nodePath`, `workerPath`,
`addonPath`, `modelPath`, `adapterPath`, `libraryPath`, `adapterSha256`, and
`direction`, either `Direction::outbound` or `Direction::inbound`.
`buildInstalledAccentLaunch(settings, token)` builds the sandboxed launch and
its exact expected readiness acknowledgment. The random token is 16 bytes.
The worker validates the fixed Node, addon, direction-specific model, model
filename and caller-reviewed owned adapter digest before opening the image.
It verifies identities again after native teardown and before the close ack.

Use `WorkerBroker::start()`, then
`process480(input, output, produced)`, and `close()` on one broker thread.
`service()` detects idle death or unsolicited output. No broker method belongs
on a HAL audio callback. The broker uses bounded pipe operations, kills and
reaps its direct child on failure, and preserves the first error in `error()`.
The worker's native parent watch also ends it when its parent exits.

The immutable native format is mono Float32 at 48,000 Hz, 480 samples per frame.
Noise suppression is 100 and ringtone detection is disabled. A new configuration
requires a new session. The worker loads these owned resources together:

- `worker.cjs`
- `wire.cjs`
- `identity.cjs`
- `accent-probe.node`, built from `native_probe.cpp`

The existing reviewed Node executable and external library directory are also
needed. No original dependency is copied by this component. The caller clears
the environment; the launch builder permits only `PATH` and the required
`DYLD_LIBRARY_PATH` inside the deny-network sandbox.

## Output and close

`process480` returns `true` when a request completed correctly. `produced`
distinguishes a model output frame from an explicit empty result. An empty
result is not a converted silence frame. Output is cleared defensively when
`produced` is false. The host must choose and report its own fixed-tick startup
padding policy. It must not count padding as model output.

The current ten-second outbound probes returned one empty startup reply,
then 999 consecutive output frames. This is an observed callback schedule,
not the algorithmic audio delay or a promise about all inputs.
The separate wire has magic bytes `OKAR` and version 1. Requests and output
frames use 1,920 payload bytes. An `empty` reply has zero payload bytes.
Readiness starts with `OKARREADY1` and names the model direction, `us` target
and exact artifact hashes. Request and response sequence numbers must match.

There is no recovered EOF drain. `close()` releases the processor and callbacks,
unloads the image and acknowledges teardown. It does not submit padding or
return a delayed tail. A finite caller can submit explicit zero frames, but
must record that as its own test policy. The live host must fail admission on
an unexpected role, hash, rate, frame shape, target, stale configuration or
readiness acknowledgment.

## File probe

`run_file.cjs` requires explicit external addon, model and input paths, a
direction, reviewed adapter and input digests, and a new output directory.
It accepts up to ten seconds of whole-frame normalized mono Float32 audio.
It records callback positions and per-call time, writes unpadded private output,
and refuses to run without the sandbox's `EPERM` loopback denial.
No input, output or vendor file should be committed.

File hashing occurs before a path is reopened for native loading. It does not
make path loading atomic. Dependency-library identities, human accent quality,
model tail preservation and sustained call scheduling need separate evidence.
