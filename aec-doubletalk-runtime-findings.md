# Synthetic double-talk AEC diagnostic

The retained noise experiment does not establish preservation of an independent near-end signal. Actual-reference output has a small projection onto the processed near-only control and a large unexplained residual. This limits the earlier echo-only attenuation result. It does not establish speech damage or production failure.

## Partial capture status

`evidence/model-probes/aec-doubletalk-20261023-v1.result.json` contains a partial observation, not a completed REA Evidence record. There is no Evidence ID. The captured process exited 0 and the runner metadata says completed. The partial terminal and filesystem capture is not truncated. REA nevertheless returned cleanup incomplete: it could not read an ownership token for live candidate PID 9800 and retained its temporary root. Owned-process-group and temporary-root cleanup are unverified. A subsequent read-only process check by the coordinating agent identified PID 9800 as a Chrome renderer under parent/process group 23117; no process action was taken. That check does not retroactively complete REA cleanup.

The recorded scenario used the deny-network sandbox, clean `env -i` environment and bounded runner. The runner required loopback denial `EPERM`. There is no network syscall trace. Before/after sampled SHA256 values match:

| Artifact | SHA256 |
| --- | --- |
| Own double-talk executable | `56fded91425e233ffe847382c004620499c904934f496c529005f58a2f6fc682` |
| Full installed AEC library | `bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a` |

The runner reports four fresh engines, each with 1000 successful reverse and 1000 successful forward calls, followed by engine destruction and library unload before publication. Sampled hashes do not atomically bind loaded images. This analysis reads retained synthetic outputs only. It performs no original-library execution, audio or administrator operation.

## Inputs and controls

The ten-second far source is the earlier deterministic 16 kHz broadband sequence, interpolated to 48 kHz stereo reference and 32 kHz mono echo. Echo has 50 ms delay and gain 0.6. A separate seed `0x6a09e667` supplies an independent near-end noise source with gain 0.6. Near-end input is silent for three seconds, then mixes with echo for seven seconds. This is noise, not speech.

Fresh engines process mixture with actual reference, mixture with zero reference, near-only with zero reference and echo-only with zero reference. Controls remain unset. All seven mono files have 320000 Float32 samples; the reference has 960000 interleaved values. An independent pass checked every retained sample for finiteness, exact counts, SHA256 and whole-run RMS. All match the metrics. Echo input, reference input and echo-only zero-reference output match their earlier broadband capture hashes.

## Control validity and component projection

The analysis script fits centered processed controls with an intercept, at shared sample indices, in each one-second window after near-end onset:

`actual-reference output ≈ intercept + a × near-only zero output + b × echo-only zero output`.

It also checks whether the zero-reference mixture equals the sum of independently processed controls. In the final second, that additivity residual RMS is 0.000030759, only 0.000585 of mixture RMS. Fitting the zero-reference mixture gives near and echo coefficients 1.0000004 and 1.0000044. The control basis correlation is -0.013568 and its normalized Gram condition is 1.027510. Thus control collinearity and a large zero-reference interaction do not explain the result.

| Final-second actual-reference fit | Value |
| --- | ---: |
| Near-control coefficient | 0.0740520 |
| Echo-control coefficient | 0.00400271 |
| Residual RMS | 0.00535361 |
| Residual RMS / output RMS | 0.888815 |
| Actual-reference output RMS | 0.00602332 |
| Zero-reference mixture RMS | 0.05255702 |

An independent centered calculation reproduces both final coefficients. The script correctly solves the two-basis normal equations, includes an intercept and reports additivity, basis correlation, conditioning and residual. The final residual ratio is an RMS ratio, not an unexplained-energy fraction.

Near coefficients range from about 0.0719 to 0.0851 across the seven mixture windows. Normalized residuals range from 0.7954 to 0.8888. These results fail to demonstrate that the independent near-end noise survives as a preserved waveform. They are consistent with substantial attenuation or alteration of that component under this fixture. Because most actual-reference output is outside the two-control fit, coefficients cannot be treated as physical component percentages. Reference-dependent filtering, nonlinear processing and differing delay can also reduce the projection. No arbitrary lag fit was used, and alignment of actual-reference output remains unresolved.

## Retained record and next step

Samples and metadata are in `evidence/model-probes/aec-doubletalk-20261023-v1/`; derived metrics and `analyze-aec-doubletalk.py` are siblings. Result SHA256 is `85cfd63aa4eb861bd9686759f1e137692c24f10b02d1d72e299be0ddf26f5264`; metrics SHA256 is `4ff90c614153c194e0fbd0ce1a69b1f512d77cea798b7bba31ec1470052ebbfd`. Derived calculations are not a completed runtime Evidence record.

Before integration, use a separately reviewed speech-like near-end fixture with simultaneous echo, explicit control comparisons and alignment checks. This can test whether noise classification explains the present result. The current diagnostic does not establish speech preservation, speech quality, physical duplex behavior or production suitability.
