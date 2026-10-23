# Synthetic speech AEC diagnostic

Locally synthesized speech is more strongly preserved than the independent noise in the previous diagnostic. In four full speech windows, actual-reference output projects onto the processed near-only control with coefficients 0.760 to 0.875, while echo-control coefficients are 0.013 to 0.018. The substantial fit residual prevents a claim of transparent speech preservation or complete echo removal.

## Capture and fixture

REA Evidence `ev_d716ac105235d05154a1eae75f0c558df700d2623033dd93000378c85f1ffbb3` exited 0 with no capture truncation, verified owned-process-group cleanup and removed temporary root. Two unrelated platform processes had withheld environment metadata and were left untouched. This completed capture is separate from the preceding double-talk noise capture with incomplete cleanup.

The runner used the deny-network sandbox and clean environment, required loopback denial `EPERM`, and retained matching before/after sampled SHA256 values:

| Artifact | SHA256 |
| --- | --- |
| Own executable | `ebb940ad1b257412135ba529a6a8df034b0f6f528cbbb5fb8bb651abdd476caa` |
| Full installed AEC library | `bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a` |
| External near input | `e0ef3b22cc3d37ec9b30d22ee87985ba9a1ba64f68ca9e6fda4628ac934a4a27` |

These are file samples, not atomic loaded-image or network syscall observations. The runner reports four fresh engines with 1000 successful reverse and 1000 successful forward calls each, destruction and unload before publication, and retained near-input bytes matching the supplied file.

The fixture metadata records macOS `say` Samantha at rate 160, file output only under a deny-network sandbox. The utterance is: "The local audio test keeps my voice clear while another sound plays in the room." It contains 133018 samples at 32 kHz, or 4.1568125 seconds. Gain 0.212510788 normalizes source RMS to 0.0375. The complete utterance starts at sample 96000 and ends at sample 229018, with zero padding to 320000 samples. It was not cropped. There was no microphone capture or speaker playback.

The far reference, 50 ms echo delay and echo gain 0.6 remain unchanged. The external near input is used without further scaling. Four controls process actual-reference mixture, zero-reference mixture, near-only with zero reference and echo-only with zero reference. Delay/configuration controls remain unset. This report reads retained synthetic files only and runs no original library.

## Independent checks and active-window fits

An independent pass checked all eight files for finite samples, exact counts, SHA256 and whole RMS. All match the retained metrics. There are 960000 interleaved reference values and 320000 values in each mono file. An independent centered two-basis calculation also reproduces the four full-window coefficients below.

The fit uses processed near-only and echo-only controls with an intercept at the same sample indices. It does not fit separate lags. The zero-reference mixture agrees closely with the sum of isolated controls: relative additivity residual RMS is 0.000564 to 0.000593 in these windows. Zero-mixture fit coefficients are approximately one. Normalized Gram condition is 1.005 to 1.021, so basis collinearity does not explain the result.

| Time window | Near coefficient | Echo coefficient | Residual RMS / output RMS |
| --- | ---: | ---: | ---: |
| 3 to 4 seconds | 0.857010 | 0.012550 | 0.390586 |
| 4 to 5 seconds | 0.759591 | 0.016168 | 0.451530 |
| 5 to 6 seconds | 0.875015 | 0.018286 | 0.350255 |
| 6 to 7 seconds | 0.823659 | 0.017439 | 0.403827 |

The window from 7 to 8 seconds contains only the final 0.1568125 seconds of the supplied utterance, plus possible processing tail. It is not a full speech window. Windows 8 to 9 and 9 to 10 have zero near-control RMS and are excluded from component fitting. Internal pauses in the utterance remain part of the full speech windows.

The analysis script correctly computes centered least squares with an intercept and checks conditioning, additivity and residual. Its copied noise-only description was corrected before the final metrics hash. Residual ratios above are RMS ratios, not unexplained-energy fractions.

## Interpretation and retained records

The speech near-control coefficients are much higher than the noise diagnostic's 0.072 to 0.085. This supports stimulus-dependent behavior and shows why noise attenuation alone cannot establish speech failure. Actual-reference processing retains a strong component correlated with this synthesized utterance while reducing the echo-control projection. It still alters the near waveform, and the residual RMS is 35% to 45% of output RMS. Coefficients are projections, not physical preservation percentages. Unresolved delay, filtering and nonlinear processing limit component attribution.

Files are under `evidence/model-probes/aec-speech-20261023-v1/`, with sibling scenario, result and metrics files. Generator metadata is under `aec-speech-fixture-20261023/`. Result SHA256 is `73fdcedf1780281276bc40dab41f4aef6d3c1b3e60ba7a548c93d6d3c3e9216e`; final metrics SHA256 is `095c6a49c0116655c987ae65a98cae8e1d3dc2b5602a6d03d1141c30477a3234`. Derived metrics are calculations from retained bytes, not separate runtime Evidence.

Next, use a broader controlled speech set, measure alignment consistently and assess near-end distortion and residual echo separately. One local voice and utterance do not establish human call quality, transparent preservation, physical duplex performance or production acceptance.
