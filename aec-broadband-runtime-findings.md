# Broadband AEC CPU probe

The ten-second synthetic broadband capture shows sustained reference-dependent attenuation under the tested direct AEC contract. In the final second, reference-on RMS is 0.137594 times zero-reference RMS, a 17.228035 dB level reduction. This is stronger evidence than the earlier multitone result. It does not establish speech preservation, physical duplex performance or original-app quality parity.

## Capture and identities

REA Evidence `ev_52353b42ce417d7c11c774d3a72032a050eabfe841d20c5b7dd6933dcadd765a` exited 0. Raw and rendered terminal records and filesystem snapshots are not truncated. Cleanup records a verified owned process group and removed temporary root. Two unrelated platform processes had withheld environment metadata and were left untouched. Process sampling is not an exhaustive descendant trace.

The scenario used `/usr/bin/sandbox-exec` with `(version 1) (allow default) (deny network*)`, then `/usr/bin/env -i PATH=/usr/bin:/bin`, Node and the bounded runner. The runner required loopback denial `EPERM`. The sandbox is the declared network boundary; REA does not provide a network syscall trace.

Matching before/after SHA256 samples bind the declared artifacts:

| Artifact | SHA256 |
| --- | --- |
| Own direct probe | `5299da0d23048a98d68a448e634bab3d1cb63af25d7d9764c80b4f43aee8f32d` |
| Full installed AEC library | `bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a` |

These file samples do not atomically bind every loaded image or dependency. No original app, microphone, speaker, HAL graph, administrator action or cloud service was used. This report independently reads retained synthetic outputs only.

## Fixture and completion

`--broadband` generates one deterministic 16 kHz xorshift32 base sequence with seed `0x91e10da5`, then linearly interpolates it to 32 kHz mono forward and 48 kHz stereo reference. Reference channels are identical. Forward input starts with 50 ms of silence, then contains the reference delayed by 50 ms and scaled by 0.6. There is no independent near-end source.

Two fresh engines receive the same forward input. One receives the reference and one receives zeros. Each processes 1000 ten-millisecond blocks, reference first, with 1000 successful reverse and 1000 successful forward calls. Delay/configuration controls remain unset. Both engines were destroyed and the library unloaded before output publication. The probe reports 305 ms for generation, processing and publication without real-time pacing. This is not a callback deadline measurement.

## Independently checked retained samples

A separate pass checked all Float32 little-endian samples for finite values, exact counts and SHA256, then recomputed whole-run and all ten one-second RMS windows. All matched the retained metrics. The directory is mode 0700 and its files are mode 0600.

| File | Samples / bytes | Whole RMS | Final-second RMS |
| --- | ---: | ---: | ---: |
| Forward input | 320000 / 1280000 | 0.037362695381 | 0.037579751213 |
| Reference input | 960000 / 3840000 | 0.060458167206 | Not separately evaluated |
| Reference on | 320000 / 1280000 | 0.004113139706 | 0.005172412187 |
| Reference zero | 320000 / 1280000 | 0.037349239546 | 0.037591950012 |

Reference counts are interleaved values, representing 480000 stereo frames. The final forward window contains exactly 32000 samples covering seconds 9 through 10.

| File | SHA256 |
| --- | --- |
| `forward-input.f32le` | `d54466f028e5f3b4a5d4937e751299aeffde7ba93cdedb5e25084cb0e3c9888c` |
| `reference-input.f32le` | `9e8e9e54c08462adc0301e4cf21dde85a6c02f1a855212602819c7e6c7f2bb05` |
| `reference-on.f32le` | `24bb1f0262a6f837f9224cbd87a49512a72ef699e730bb26fbb5eccc494b7c7f` |
| `reference-zero.f32le` | `8ee0093e7bb15a937dc037115af9f5c9c80c042a865c41e5771b4bdba90bc8de` |

Attenuation decreases during the run. The first-second reference-on/zero ratio is 0.040230, or 27.908995 dB reduction. It reaches 0.137594, or 17.228035 dB, in the final second. Reference-dependent attenuation persists through the ten-second observation, but these results do not establish convergence or stability beyond that interval. These are output-level comparisons, not aligned residual-error or speech-quality scores.

## Bounded alignment check and limits

An independent full-resolution search compares the 2048 input samples from seconds 8 through 8.064 with zero-reference output at every integer lag from -3200 through +3200 samples, or ±100 ms. The maximum uncentered normalized cross-correlation is 0.695340758 at +261 samples, or 8.15625 ms, with positive lag meaning output follows input. Centered Pearson correlation selects the same lag at 0.695089796. The retained metric uses the uncentered measure.

The peak is narrow. An earlier coarse one-millisecond search missed it and is superseded by this full-sample search. One short window with moderate correlation does not establish fixed processing latency, physical end-to-end latency or alignment of the suppressed reference-on output. Do not use this lag alone to claim an aligned echo-error score.

Retained evidence is under `evidence/model-probes/aec-broadband-20261023-v1`, with sibling scenario, result and metrics JSON files. The result SHA256 is `34b20eac396f07034c3e0c81f68954d28362759da6a8a36f044a35832a73eb08`; metrics SHA256 is `61befad3ebf9f78cafe05dd2a678ce79ab0932200bad791990be8dc29b298dfd`. Derived metrics are calculations from retained bytes, not new runtime Evidence.

Before production integration, prioritize a separately reviewed experiment with an independent near-end signal and simultaneous echo. It must distinguish echo cancellation from indiscriminate attenuation and check near-end preservation. Alignment consistency across longer windows remains useful supporting analysis. No production AEC integration, tail recovery, physical audio acceptance or original-app timing parity is established.
