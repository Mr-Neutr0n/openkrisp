#!/usr/bin/env python3
"""Deterministic PCM WAV fixtures and bounded numerical comparisons."""
import argparse
import json
import math
from pathlib import Path
import random
import struct
import wave


def read(path):
    with wave.open(str(path), 'rb') as w:
        fmt = dict(rate=w.getframerate(), channels=w.getnchannels(), width=w.getsampwidth(), frames=w.getnframes())
        if w.getcomptype() != 'NONE' or fmt['width'] not in (1, 2, 3, 4):
            raise ValueError('Only uncompressed integer PCM WAV with 8/16/24/32 bits is supported')
        raw = w.readframes(fmt['frames'])
    width = fmt['width']
    if len(raw) != fmt['frames'] * fmt['channels'] * width:
        raise ValueError('Truncated PCM payload')
    scale = 2 ** (8 * width - 1)
    values = [(raw[i] - 128) / 128 if width == 1 else int.from_bytes(raw[i:i+width], 'little', signed=True) / scale for i in range(0, len(raw), width)]
    return fmt, [values[i:i+fmt['channels']] for i in range(0, len(values), fmt['channels'])]


def write(path, rows, rate=16000):
    if not rows or not rows[0]:
        raise ValueError('Empty signal')
    channels = len(rows[0])
    data = bytearray()
    for row in rows:
        if len(row) != channels:
            raise ValueError('Inconsistent channel count')
        for value in row:
            if not math.isfinite(value) or not -1 <= value <= 1:
                raise ValueError('Invalid or over-range sample')
            data.extend(struct.pack('<h', max(-32768, min(32767, round(value * 32768)))))
    with wave.open(str(path), 'wb') as w:
        w.setparams((channels, 2, rate, 0, 'NONE', 'not compressed'))
        w.writeframes(data)


def fixtures(out, speech=None):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    rate, count = 16000, 16000
    rng = random.Random(731)
    noise = [[rng.uniform(-0.06, 0.06)] for _ in range(count)]
    clean = [[0.2 * math.sin(2 * math.pi * 437 * i / rate) * (0.5 + 0.5 * math.sin(2 * math.pi * 3 * i / rate))] for i in range(count)]
    signals = {'silence': [[0.0] for _ in range(count)], 'impulse': [[0.5 if i == 1000 else 0.0] for i in range(count)], 'noise': noise, 'clean': clean, 'gain': [[r[0] * 0.5] for r in clean], 'stereo': [[clean[i][0], noise[i][0]] for i in range(count)], 'clean_noise': [[clean[i][0] + noise[i][0]] for i in range(count)]}
    for name, rows in signals.items():
        write(out / (name + '.wav'), rows, rate)
    if speech:
        fmt, rows = read(speech)
        rng = random.Random(731)
        # Reserve 6% headroom and use one shared noise sample across channels.
        peak = max(abs(v) for row in rows for v in row)
        factor = min(1, 0.9 / peak) if peak else 1
        normalized = [[v * factor for v in row] for row in rows]
        mixed = []
        for row in normalized:
            n = rng.uniform(-0.06, 0.06)
            mixed.append([v + n for v in row])
        write(out / 'speech_clean.wav', normalized, fmt['rate'])
        write(out / 'speech_noise.wav', mixed, fmt['rate'])
    (out / 'manifest.json').write_text(json.dumps({'seed': 731, 'synthetic_rate': rate, 'synthetic_frames': count, 'speech_supplied': bool(speech)}, indent=2) + '\n')


def compare(reference, candidate, max_delay=0):
    a_fmt, a = read(reference)
    b_fmt, b = read(candidate)
    report = {'reference_format': a_fmt, 'candidate_format': b_fmt, 'format_equal': all(a_fmt[k] == b_fmt[k] for k in ('rate', 'channels', 'width')), 'duration_delta_seconds': b_fmt['frames'] / b_fmt['rate'] - a_fmt['frames'] / a_fmt['rate']}
    def stats(fmt, rows):
        vals = [v for row in rows for v in row]
        rail = 1 - 1 / 2 ** (8 * fmt['width'] - 1)
        return {'finite': all(math.isfinite(v) for v in vals), 'rail_samples': sum(v <= -1 or v >= rail for v in vals), 'peak': max(map(abs, vals), default=0)}
    report['reference'] = stats(a_fmt, a)
    report['candidate'] = stats(b_fmt, b)
    if a_fmt['rate'] != b_fmt['rate'] or a_fmt['channels'] != b_fmt['channels']:
        report['comparable'] = False
        return report
    if not a or not b or max_delay < 0 or max_delay >= min(len(a), len(b)):
        raise ValueError('Signals must be nonempty and delay bound smaller than both frame counts')
    # Fixed common window avoids rewarding a lag for discarding more samples.
    start, end = max_delay, min(len(a), len(b)) - max_delay
    if end <= start:
        raise ValueError('Delay bound leaves no comparison window')
    energies = []
    for lag in range(-max_delay, max_delay + 1):
        error = sum((a[i][c] - b[i+lag][c]) ** 2 for i in range(start, end) for c in range(a_fmt['channels']))
        energies.append((error, abs(lag), lag))
    error, _, lag = min(energies)
    x = [a[i][c] for i in range(start, end) for c in range(a_fmt['channels'])]
    y = [b[i+lag][c] for i in range(start, end) for c in range(a_fmt['channels'])]
    energy = sum(v*v for v in x)
    gain = sum(v*w for v, w in zip(x, y)) / energy if energy else None
    residual = sum((w - gain*v)**2 for v, w in zip(x, y)) if gain is not None else sum(w*w for w in y)
    report.update(comparable=True, aligned_delay_frames=lag, compared_frames=end-start, reference_frames_outside_window=len(a)-(end-start), candidate_frames_outside_window=len(b)-(end-start), snr_db=10*math.log10(energy/error) if energy and error else None, exact_window=error == 0, error_rms=math.sqrt(error/len(x)), fitted_gain=gain, residual_rms=math.sqrt(residual/len(x)))
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    gen = commands.add_parser('generate')
    gen.add_argument('--out', default=str(Path(__file__).parent / 'build/fixtures'))
    gen.add_argument('--speech')
    cmp = commands.add_parser('compare')
    cmp.add_argument('reference')
    cmp.add_argument('candidate')
    cmp.add_argument('--max-delay', type=int, default=0, help='Search radius in frames; positive delay means candidate is late')
    args = parser.parse_args()
    if args.command == 'generate':
        fixtures(args.out, args.speech)
    else:
        print(json.dumps(compare(args.reference, args.candidate, args.max_delay), indent=2, allow_nan=False))


if __name__ == '__main__':
    main()
