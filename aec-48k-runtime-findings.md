# Direct 48 kHz AEC runtime gate

The tested AEC library accepts 48 kHz mono forward and 48 kHz stereo reference through the reviewed direct ABI. Four fresh engines each completed 1000 reverse and 1000 forward calls with zero status and finite output. This clears the tested rate-call gate for a duplex worker implementation. It does not establish full speech quality, physical audio performance or original-app parity.

## Capture and identities

REA Evidence `ev_c7c288999c223b88f07d2b8204b1619118551b8a36f5be48801830cedb4af486` exited 0 with no capture truncation, verified owned-process-group cleanup and removed temporary root. Three unrelated platform processes had withheld environment metadata and were left untouched. The runner used the deny-network sandbox and clean environment and required loopback denial `EPERM`. There is no network syscall trace.

Matching before/after sampled SHA256 values are:

| Artifact | SHA256 |
| --- | --- |
| Own executable | `f3ffb34d885f259307fa9ca9e11f831d4c0dbbc2aa47fd7bea4dafd4d19d7fc3` |
| Full installed AEC library | `bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a` |
| External speech input | `72b535a052e7d4995f13186557f346bd0ca206f3c713f3585995005290c081a1` |

File samples do not atomically bind loaded images. This report independently reads retained synthetic outputs only. It performs no original-library execution, audio capture or playback.

## Fixture and independent checks

`--forward-rate 48000` selects 480 mono samples per ten-millisecond forward block. Reference remains 480 stereo frames per block. Every mono file has 480000 Float32 little-endian values; reference has 960000 interleaved values. Echo is a 0.6-scaled far source delayed by 2400 samples, exactly 50 ms. Near-end speech starts at sample 144000, exactly three seconds. The four fresh controls are actual-reference mixture, zero-reference mixture, near-only zero-reference and echo-only zero-reference. Delay/configuration controls remain unset. Engine destruction and library unload precede publication.

The near fixture uses the same complete Samantha utterance and gain as the 32 kHz speech run. `afconvert` converted the source to 48 kHz mono Float32. Its 199527 samples span 4.1568125 seconds; padding retains the whole utterance through sample 343527. Generator details are in `evidence/model-probes/aec-speech-fixture-20261023/metadata-48k.json`. No microphone or speaker playback was used.

An independent pass checked all eight file hashes, counts, finite samples and whole-run RMS. Results match the retained metrics within floating-point accumulation precision. Independent centered least squares also reproduces the active-window coefficients below.

## Active speech windows

The fit uses processed near-only and echo-only controls with an intercept at shared sample indices, without separate lag fitting. Zero-reference mixture additivity residual RMS is about 2 × 10^-7 of mixture RMS in the four full speech windows. Zero-mixture fit coefficients are approximately one, and normalized Gram condition is 1.003 to 1.022. Thus the control basis is well conditioned and its mixture interaction is small.

| Time window | Near coefficient | Echo coefficient | Residual RMS / output RMS |
| --- | ---: | ---: | ---: |
| 3 to 4 seconds | 0.835903 | 0.003566 | 0.413279 |
| 4 to 5 seconds | 0.788089 | 0.009421 | 0.431857 |
| 5 to 6 seconds | 0.866080 | 0.010540 | 0.363354 |
| 6 to 7 seconds | 0.797001 | 0.017030 | 0.432521 |

The 7-to-8-second window contains only the last 0.1568125 seconds of supplied speech plus possible processing tail. Windows 8 to 10 have zero near-control RMS and are excluded from component fitting.

These coefficients show a strong projection onto synthesized speech and a small echo-control projection, consistent with the earlier 32 kHz diagnostic. Residual RMS remains 36% to 43% of output RMS. This prevents a transparent-preservation or complete-cancellation claim. Coefficients are projections, not physical component percentages; residual ratios are RMS ratios, not energy fractions. Filtering, nonlinear behavior and unresolved alignment limit attribution. The 32 and 48 kHz fixtures also differ in resampling, so these coefficients alone do not rank their quality.

## Retained record and implementation boundary

Samples and metadata are under `evidence/model-probes/aec-speech48-20261023-v1/`, with sibling scenario, result and metrics JSON. Result SHA256 is `112163252ac47a254d8a28fd106136f345e92c97372325d9073744ffdd6206c4`; metrics SHA256 is `1b53b227055783dd168d8b3606d92913f331b190e8780ae73c0671ceb5c1bf79`. Derived metrics are not separate runtime Evidence.

A bounded duplex worker can now use this tested rate shape. It still needs its own transport, identity admission, ordering, failure and teardown verification. This CPU experiment does not establish callback safety, sustained timing, physical reference alignment, tail recovery or broad human speech quality.
