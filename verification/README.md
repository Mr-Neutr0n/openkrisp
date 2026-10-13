# Audio measurements

The original Krisp output baseline is missing. These tools cannot establish a parity pass. They measure sample differences and routing errors. They do not measure speech quality, intelligibility, perceptual parity, or live device behavior.

Run `./verify` from this directory. Python 3 and its standard library are the only requirements. Generated files go under ignored `build/`.

```sh
python3 audio.py generate
python3 audio.py generate --speech /absolute/path/to/authorized-speech.wav
python3 audio.py compare build/fixtures/clean.wav build/fixtures/gain.wav
python3 audio.py compare original-output.wav rebuilt-output.wav --max-delay 160
```

Use an explicitly supplied speech recording that you may use. The tool records no microphone audio. Synthetic fixtures include silence, an impulse, seeded uniform noise, an amplitude-modulated tone, half-gain tone, distinct stereo channels, and a matched clean/noisy pair. The synthetic tone is not speech. Every synthetic fixture has 16,000 frames at 16 kHz, with 16-bit PCM samples. The seed is 731. The speech mixer preserves rate and channel count, scales the peak to at most 0.9, and adds shared noise in the range -0.06 to 0.06. It writes both the scaled clean reference and the noisy version as 16-bit PCM.

The reader accepts uncompressed integer PCM WAV at 8, 16, 24, or 32 bits. Python's `wave` support controls accepted WAV container variants. Float WAV and compressed WAV are unsupported. Unsupported input raises an error. No resampling or channel conversion occurs. Rate or channel mismatch sets `comparable` to false. Width mismatch remains visible in `format_equal` but normalized sample comparison is possible. All integer PCM samples are finite by construction. `finite` therefore does not test float processing inside an engine.

Duration uses frame count divided by sample rate. Rail counts include samples at either integer endpoint. A rail count suggests possible clipping but does not prove it. Peak uses normalized full-scale units.

Alignment searches integer delays from `-max-delay` through `+max-delay`. A positive result means the candidate is late. It chooses the smallest squared error, then the smallest absolute delay, then the negative delay on a tie. It uses the same reference window for every delay, trimming the search radius at both ends. The result reports frames outside that window in each file. A delay bound that leaves no window raises an error. Search costs grow with frame count times delay radius. Use short captures and a bounded radius. Silence and periodic signals cannot establish a unique delay.

`snr_db` is 10 log10 of reference energy divided by squared sample error. It includes gain errors. `null` means zero reference energy or zero error; inspect `exact_window` to distinguish those cases. `fitted_gain` fits one scalar across all channels with no offset term. `residual_rms` measures the remaining difference after that gain fit. `error_rms` measures the raw aligned difference. RMS values use normalized full-scale sample units. Residual is not a measurement of acoustic noise alone. It also includes distortion, speech changes, and routing errors.

The self-check detects exact identity, 0.5 gain within 0.0001, 37 frames of delay, duration growth, channel reversal, added noise, a dropped sample block, and both PCM endpoints. It also exercises the supplied-speech mixing path using the synthetic tone. These limits validate the tooling against known transformations. They are not product acceptance thresholds.

For a future original/rebuilt comparison, feed the same input to both systems. Save each output and the input, capture settings, model selection, device route, and engine state. Compare output format and duration before interpreting aligned metrics. Assess input/output delay separately. A high aligned score can hide latency and cannot establish equivalent noise suppression. No original app, model, or artifact was inspected or run to build these tools.
