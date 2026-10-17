# Experimental installed-model probe

This component can process a bounded synthetic signal through the reviewed installed Krisp NC binary. It is an isolated experiment, not an integrated app provider. It includes no vendor binary, model or header.

`abi_factory.hpp`, `abi_supplier.hpp` and `abi_result.hpp` describe the observed ARM64 libc++ calling convention. The result collector copies borrowed samples during callbacks and rejects incorrect counts, nonfinite samples and excess output. The native adapter preserves original shared ownership and releases the processor before unloading its image. It calls the concrete processor directly without changing SDK state or starting an audio graph.

Run `./verify` on the Mac. It checks independent collector tests and a separate-library ABI fixture in release and ASan/UBSan builds, launcher rejection/publication fixtures, and 20 host-only Node adapter validation cases. These checks do not load Krisp. `./build_probe` builds `build/native-probe.node` using installed Node headers at `/opt/homebrew/include/node`.

## Explicit model experiment

Use `run_probe.cjs` only inside the reviewed network-denied process. The native `.node` module is internal to this launcher and does not enforce its own identity or sandbox checks. The launcher requires explicit absolute `--addon`, `--model`, `--adapter` and new `--output` paths. It requires loopback failure `EPERM` before loading the adapter and binds the addon to SHA256 `adde50ff549700fd535fb9cc8e42d45fa36dca02131009ded727a10625ae8755`. A different installed version is rejected.

The REA runtime scenario uses `/usr/bin/sandbox-exec` with `(version 1) (allow default) (deny network*)`, then `/usr/bin/env` to supply `DYLD_LIBRARY_PATH` for the installed Electron framework's `Versions/A/Libraries`, then Node and this launcher. No microphone or CoreAudio restart is required. The sandbox profile is part of the execution contract; one loopback result alone does not prove all network behavior.

The launcher generates 100 frames of 480 Float32 samples at 48 kHz. Optional `--bypass` and `--suppression-level` from 0 through 100 control the recovered ordinary supplier. On validated success it creates a private output folder containing `output.f32le` and `metadata.json`, including before/after artifact hashes. Existing outputs are refused. No partial run is promoted as success.

Two REA runs against the installed outbound model `c8.f.m.528d1f-1.0.1_1.0.kef` completed with 100 callbacks and 48,000 finite samples each. NC and bypass outputs differ. See `../../native-direct-probe-findings.md` for evidence, hashes and limits. This establishes bounded native processing, not speech-quality parity, complete tail preservation, realtime performance or an app backend.

This adapter is specific to one inspected binary and libc++ ABI. The first factory argument is lowered to an opaque pointer only because the complete inspected factory body does not use it. Do not generalize this to other symbols or versions. Keep original models installed locally; redistribution rights remain unresolved.
