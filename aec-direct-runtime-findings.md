# Direct AEC CPU probe

A bounded REA capture on 2026-10-18 successfully called the installed AEC library through the reviewed standalone adapter. It returned finite output and completed destruction and unload. This establishes the tested factory and duplex processing ABI. The short multitone fixture does not establish useful echo cancellation or original-app quality parity.

No original app, microphone, speaker, HAL audio graph, administrator action or cloud service was used. This analysis reads retained synthetic outputs only. It performs no further original-library execution.

## Execution and identities

Evidence `ev_dc0785e71d0f2a842f97891ee8393ea074fd739ebe64ce0857c2aa60d4051547` exited 0 with no capture truncation, verified owned-process-group cleanup and removed temporary roots. Its scenario and result are `evidence/model-probes/aec-cpu-20261018-v1.scenario.json` and `.result.json`. The result file SHA256 is `f444477ae08eaceab7df3491a1fa9a2d94b564dfc9c2e52e74ea57a8609b03da`.

The scenario uses `/usr/bin/sandbox-exec` with `(version 1) (allow default) (deny network*)`, then `/usr/bin/env -i PATH=/usr/bin:/bin`, the selected Node runtime and the bounded runner. The runner required loopback denial `EPERM` before admission. This prerequisite and the recorded sandbox profile establish the declared execution boundary. REA does not provide a syscall-level network trace.

The runner sampled matching before/after SHA256 identities:

| Artifact | SHA256 |
| --- | --- |
| Full installed `libaec-sdk.dylib` | `bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a` |
| Own `build/aec-direct-probe` | `a2af66b94e4fe910dbf197bd0513b1aa47f00dbf2e614f13b4a234cd24b1763f` |

The library remains at its installed Electron Framework library path. The full universal-container digest is distinct from its ARM64 slice digest, as documented in `native-echo-contract-findings.md`. Before/after hashes do not provide an atomic binding of every loaded image or dependency.

## Fixture and completed calls

`app/native-model-probe/aec_direct_probe.cpp` generates three seconds of continuous-time tones at 233, 617 and 1229 Hz. It evaluates that same signal independently at the two stream rates. The reverse input is 48 kHz interleaved stereo with identical channels. The forward input is 32 kHz mono, initially silent for 50 ms, then a 0.6-scaled copy of the reference delayed by 50 ms. There is no speech or independent near-end source.

Two fresh engines process the same forward input. One receives the reference; the other receives zero reverse samples. Each processes 300 ten-millisecond blocks, with reverse analysis before forward processing. All 300 reverse and 300 forward calls per engine returned status 0. No explicit delay setter or reinitialization call was used. Reference-first order is an experiment policy, not proof of the original graph's scheduling.

The probe reported `teardownComplete:true` after both engine destructions and successful `dlclose`, before publishing four exclusive output files. Its reported 84 ms covers signal generation, both runs and output publication, without real-time pacing. That duration is not callback deadline or sustained live-performance evidence.

## Independently checked retained samples

A separate Python pass read every retained Float32 little-endian sample, checked finite values, recomputed file hashes and calculated RMS with double-precision accumulation. The private output directory is mode 0700; its four sample files and metadata are mode 0600. The reference count below is interleaved sample values, representing 144,000 stereo frames.

| File | Sample values / bytes | Whole RMS | Last-second RMS |
| --- | ---: | ---: | ---: |
| `forward-input.f32le` | 96,000 / 384,000 | 0.045312236003 | 0.045694640491 |
| `reference-input.f32le` | 288,000 / 1,152,000 | 0.076157731027 | 0.076157731027 |
| `reference-on.f32le` | 96,000 / 384,000 | 0.038088079000 | 0.045261668973 |
| `reference-zero.f32le` | 96,000 / 384,000 | 0.045249270998 | 0.045694475482 |

The last-second window is exactly the final 32,000 forward samples or 96,000 interleaved reverse samples, covering seconds 2 through 3.

| File | SHA256 |
| --- | --- |
| `forward-input.f32le` | `4dad86f42324de2480d511ac6e7781938accffabac4416b90ec49c6c9ebdc1cd` |
| `reference-input.f32le` | `d464bd3a10b53beacbbcafe64991d5176d96196c396650319eefec3b462c40c6` |
| `reference-on.f32le` | `05f46294a079fd756389c2c049e6b36376e62e8d626a796924681111bdd70d27` |
| `reference-zero.f32le` | `4a3de25001bd64746d51918f250cfacea9580bff89036eb080d65f4a3e906869` |

The whole-run reference-on/reference-zero RMS ratio is 0.841739064, a level reduction of 1.496450 dB. In the final second, the ratio is 0.990528253, only 0.082663 dB or about 0.95% lower RMS. Reference-on and reference-zero differ in 94,739 of 96,000 samples. Their difference RMS is 0.023426072824 over the full run and 0.001928881452 in the final second.

The whole-run RMS conceals a large time variation. Reference-on RMS is 0.000983206 in the first half-second, 0.027029635 during seconds 1 through 1.5, then approximately 0.045261669 over the final second. Thus the reference affects the output, but its early attenuation does not establish stable useful cancellation. These observations do not identify a cause. Raw unaligned sample error against the input is not an echo-quality score because processing delay is not measured.

Full derived metrics, including half-second windows, are retained in `evidence/model-probes/aec-cpu-20261018-v1.metrics.json`, SHA256 `04edc2d9e09475114a5b7c9061dc7ef0adc532342a39a968006ce58259560815`. They are a reading aid calculated from retained bytes, not a new REA runtime observation.

## Next meaningful diagnostic

Use a deterministic broadband sequence from one shared 16 kHz base signal, resampled to 32 kHz forward and 48 kHz reverse. Keep the current 50 ms forward delay, 0.6 gain, identical reverse channels, reference-first call order and unset delay/config controls for the baseline. Extend that baseline to ten seconds and retain all inputs and outputs. This changes the stimulus and adaptation observation window for a specific reason. Three tones can make delay estimation ambiguous, and three seconds gives limited adaptation coverage.

Compare reference-on and zero-reference runs by time window. Estimate input/output alignment using the known broadband signal before interpreting residual error or echo attenuation. If cancellation still does not persist, inspect delay/configuration semantics against the retained addon contract before changing those controls. Neither insufficient adaptation nor incorrect delay/configuration has been proved by this capture. A new run requires the same reviewed executable and identity boundaries, or review of a changed probe first.

No production AEC integration, physical duplex behavior, speech preservation, double-talk behavior, complete tail handling or original-app timing parity is established here.
