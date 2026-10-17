# Experimental installed-model probe

This component can process a bounded synthetic signal through the reviewed installed Krisp NC binary. It is an isolated experiment, not an integrated app provider. It includes no vendor binary, model or header.

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

`provider_transport.hpp` supplies two fixed-capacity SPSC queues for one serialized audio callback and one broker thread. `exchange` stages 480-sample requests and consumes results at an explicit sample delay. It allocates nothing and does not wait, access pipes or call Node. Missing output at its scheduled sample, invalid values, sequence errors and reported worker failures latch a fault. Supported-size output blocks become silent on failure. Counts above 4096 are rejected without touching the destination, so the caller must mute them. Input and output storage must not overlap.

The default delay is 5760 samples, or 120 ms at 48 kHz. This is a synthetic test policy, not an accepted live setting or a measurement of model latency. Queue tests cover irregular callback sizes and 20,000 frames with a concurrent broker in release, ASan/UBSan and TSan builds. Test handshakes occur outside the callback and do not establish production scheduling performance.

`worker_protocol.cjs` defines bounded framing for a future pipe worker. Each direction checks a 128-bit session token, a non-wrapping 64-bit sequence and exact finite 480-sample Float32 payloads. Close is terminal. The parser retains at most 1956 bytes, rejects truncated EOF and poisons itself after malformed data or callback reentry. Its callbacks must complete synchronously. A token is a framing identity, not authentication or a readiness acknowledgement.

`worker_protocol.hpp` implements the same wire format for the native broker. Compatibility tests compare emitted bytes exactly and decode each language's output with the other. Both codecs reject malformed frames and do not wrap sequence numbers.

`worker_session.cjs` connects framing to a supplied persistent session through synchronous read/write functions. It handles partial IO and EINTR, validates each processing result and closes the session once on EOF, explicit close or failure. The parent must send close and immediately close its request pipe. The worker acknowledges after teardown and then checks for EOF without trailing bytes. The parent must validate that acknowledgement and child exit. Real OS pipe tests use a synthetic session; they do not load Krisp.

## Supervised worker

`audio_worker.cjs` admits the fixed reviewed addon and outbound model, plus caller-supplied Node and adapter hashes. It requires loopback denial before loading, opens one model and writes an exact readiness record before processing. The checks sample files before loading; they do not atomically bind files reopened by Node or the dynamic loader. Protocol output uses fd3 so native stdout logging cannot corrupt it.

`installed_worker_launch.hpp` builds the fixed deny-network sandbox command. It inherits no environment. Inside the sandbox, `/usr/bin/env -i` supplies only PATH and the reviewed library directory before launching Node. This preserves the library path across the platform executable without admitting NODE_OPTIONS, NODE_PATH or other loader variables.

`WorkerBroker` starts the direct child, validates readiness and exchanges one frame at a time through nonblocking parent pipes. It applies startup, frame and shutdown deadlines. Close requires a teardown acknowledgement, response EOF and reaped exit status 0. Errors terminate only its owned child, escalating TERM to KILL with bounded reap polling. The broker must be the child's sole reaper; it does not supervise arbitrary descendants.

`ProviderWorker` connects the callback queues to this broker on a dedicated thread. The callback only copies samples and reads atomic state. Control-thread stop joins the broker thread; callback removal must succeed before releasing the owner. Idle checks detect child death or unexpected output even without another audio callback. Synthetic tests cover callback output order, broker failures, repeated stop and stop during confirmed stalled processing, including TSan.

`installed_worker_probe.cpp` exercises the production builder and broker with a caller-provided one-second synthetic Float32 file. It publishes output exclusively after confirmed close. Building it does not execute the installed addon. Runtime evidence is recorded separately in `../../native-direct-probe-findings.md`.

The launcher supplies its own PID to the worker. Before opening the installed model, `native.watchParent` starts a native guard that checks `getppid()` every 25 ms. Parent loss calls `_exit(72)` in the worker even if its main thread is blocked. It never signals another PID. Normal shutdown stops and joins the guard. Detection depends on scheduling; abnormal exit skips C++ cleanup and relies on OS process-resource reclamation.

`timed_worker_probe.cpp` runs 112 callbacks at 10 ms intervals after startup: 100 input frames and 12 zero-padding frames. It removes only the known 5760-sample queue delay, waits for all requests, then publishes 48,000 samples after clean stop. REA NC and bypass runs passed with zero queue deadline failures and byte-identical aligned output. This is paced CPU testing, not CoreAudio acceptance, a speech-quality comparison or model-tail recovery.

This provider is not connected to the desktop or CoreAudio routing yet. Next, select buffering from the actual callback format and verify sustained timing, then extend route acknowledgement and desktop selection together. The 120 ms synthetic buffering delay is not an accepted live latency budget.
