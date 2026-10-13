#!/usr/bin/env python3
"""Exercise WAV files and check known signal transformations."""
from pathlib import Path
import subprocess
import sys
from audio import read, write, compare

root = Path(__file__).parent
out = root / 'build/fixtures'
subprocess.run([sys.executable, str(root / 'audio.py'), 'generate', '--out', str(out)], check=True)
identity = compare(out/'clean.wav', out/'clean.wav')
assert identity['exact_window'] and identity['fitted_gain'] == 1
assert identity['duration_delta_seconds'] == 0 and identity['candidate']['rail_samples'] == 0
assert compare(out/'silence.wav', out/'silence.wav')['snr_db'] is None
write(out/'other-rate.wav', [[0.0], [0.0]], 8000)
assert compare(out/'silence.wav', out/'other-rate.wav')['comparable'] is False
assert compare(out/'clean.wav', out/'stereo.wav')['comparable'] is False
half = compare(out/'clean.wav', out/'gain.wav')
assert abs(half['fitted_gain'] - 0.5) < 0.0001
assert 5.99 < half['snr_db'] < 6.03 and half['residual_rms'] < 0.00002
fmt, impulse = read(out/'impulse.wav')
write(out/'delayed.wav', [[0.0]]*37 + impulse, fmt['rate'])
delay = compare(out/'impulse.wav', out/'delayed.wav', 50)
assert delay['aligned_delay_frames'] == 37 and delay['exact_window']
assert abs(delay['duration_delta_seconds'] - 37/16000) < 1e-10
_, stereo = read(out/'stereo.wav')
write(out/'reversed.wav', [row[::-1] for row in stereo])
reversed_report = compare(out/'stereo.wav', out/'reversed.wav')
assert reversed_report['error_rms'] > 0.05 and not reversed_report['exact_window']
noisy = compare(out/'clean.wav', out/'clean_noise.wav')
assert noisy['residual_rms'] > 0.03 and not noisy['exact_window']
_, clean = read(out/'clean.wav')
write(out/'lost.wav', [[0.0] if 2000 <= i < 4000 else row for i, row in enumerate(clean)])
assert compare(out/'clean.wav', out/'lost.wav')['error_rms'] > 0.01
write(out/'rails.wav', [[-1.0], [1.0]])
assert compare(out/'rails.wav', out/'rails.wav')['candidate']['rail_samples'] == 2
subprocess.run([sys.executable, str(root/'audio.py'), 'generate', '--out', str(root/'build/speech-mix'), '--speech', str(out/'clean.wav')], check=True)
mixed = compare(root/'build/speech-mix/speech_clean.wav', root/'build/speech-mix/speech_noise.wav')
assert mixed['residual_rms'] > 0.03
# Check CLI JSON serialization as well as the library path.
subprocess.run([sys.executable, str(root/'audio.py'), 'compare', str(out/'clean.wav'), str(out/'gain.wav')], check=True, stdout=subprocess.DEVNULL)
print('PASS: identity, gain, delay, duration, channel reversal, noise, sample loss, rails, speech mix, CLI')
