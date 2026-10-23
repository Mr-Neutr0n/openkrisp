#!/usr/bin/env python3
"""Check generated controls and publication using only the independent own dylib."""
import array
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

binary, library = sys.argv[1:]
names = ['reference-input', 'echo-input', 'near-input', 'mixture-input',
         'mixture-reference-on', 'mixture-reference-zero', 'near-reference-zero', 'echo-reference-zero']
def f32(value):
    return struct.unpack('f', struct.pack('f', value))[0]
def base(seed):
    values = []
    for _ in range(160001):
        seed ^= (seed << 13) & 0xffffffff
        seed ^= seed >> 17
        seed ^= (seed << 5) & 0xffffffff
        values.append(((seed & 65535) - 32768) / 262144)
    return values
def sample(values, index, ratio):
    lower, phase = divmod(index, ratio)
    return f32(values[lower] + f32(f32(values[lower + 1] - values[lower]) * f32(phase / ratio)))
with tempfile.TemporaryDirectory(prefix='openkrisp-doubletalk-') as temporary:
    root = Path(temporary)
    destination = root / 'output'
    command = [binary, library, str(destination)]
    result = subprocess.run(command, capture_output=True, text=True, check=True, timeout=30)
    status = json.loads(result.stdout)
    assert status['engines'] == 4 and status['successfulCallsPerEngine'] == 2000
    assert status['framesPerEngine'] == 1000 and status['teardownComplete'] is True
    assert status['delaySetterCalled'] is False
    assert status['farSeed'] == 0x91e10da5 and status['nearSeed'] == 0x6a09e667
    assert status['echoGain'] == status['nearGain'] == 0.6
    assert destination.stat().st_mode & 0o777 == 0o700
    data = []
    for index, name in enumerate(names):
        path = destination / (name + '.f32le')
        values = array.array('f', path.read_bytes())
        assert len(values) == (960000 if index == 0 else 320000)
        assert all(map(math.isfinite, values)) and path.stat().st_mode & 0o777 == 0o600
        data.append(values)
    reference, echo, near, mixture, on, zero, near_zero, echo_zero = data
    assert reference[::2] == reference[1::2]
    assert zero == mixture and near_zero == near and echo_zero == echo
    assert on != zero and near != echo
    far, close = base(0x91e10da5), base(0x6a09e667)
    for index, value in enumerate(reference[::2]):
        assert abs(value - sample(far, index, 3)) < 3e-8
    for index in range(320000):
        expected_echo = f32(f32(0.6) * sample(far, index - 1600, 2)) if index >= 1600 else 0
        expected_near = f32(f32(0.6) * sample(close, index - 96000, 2)) if index >= 96000 else 0
        assert abs(echo[index] - expected_echo) < 3e-8
        assert abs(near[index] - expected_near) < 3e-8
        assert mixture[index] == f32(echo[index] + near[index])
        # Synthetic fixture subtracts first reverse sample per block. This also
        # detects reference state leaking into either fresh zero-reference engine.
        assert on[index] == f32(mixture[index] - reference[(index // 320) * 960])
    original = [path.read_bytes() for path in sorted(destination.iterdir())]
    assert subprocess.run(command, capture_output=True, timeout=30).returncode != 0
    assert original == [path.read_bytes() for path in sorted(destination.iterdir())]
    repeated = root / 'repeated'
    subprocess.run([binary, library, str(repeated)], capture_output=True, check=True, timeout=30)
    assert original == [path.read_bytes() for path in sorted(repeated.iterdir())]
    for stage in ['factory', 'reverse', 'forward']:
        target = root / stage
        result = subprocess.run([binary, library, str(target)], capture_output=True,
                                env={**os.environ, 'OPENKRISP_AEC_FIXTURE_FAILURE': stage}, timeout=30)
        assert result.returncode != 0 and b'synthetic AEC initialization failure' in result.stderr
        assert not target.exists()
    link = root / 'link'
    link.symlink_to(root / 'absent')
    assert subprocess.run([binary, library, str(link)], capture_output=True, timeout=30).returncode != 0
    assert link.is_symlink() and not (root / 'absent').exists()
    external = root / 'caller-near.f32le'
    supplied = array.array('f', [0.0] * 320000)
    for index in range(96000, 320000):
        supplied[index] = ((index % 97) - 48) / 1024
    external.write_bytes(supplied.tobytes())
    external_output = root / 'external'
    external_command = [binary, library, str(external_output), '--near-input', str(external)]
    result = subprocess.run(external_command, capture_output=True, text=True, check=True, timeout=30)
    status = json.loads(result.stdout)
    assert status['nearSource'] == 'external-f32le' and status['nearSeed'] is None
    assert status['fixture'] == 'doubletalk-external-near-v1' and status['nearGain'] == 1
    assert (external_output / 'near-input.f32le').read_bytes() == supplied.tobytes()
    assert (external_output / 'near-reference-zero.f32le').read_bytes() == supplied.tobytes()
    mixed = array.array('f', (external_output / 'mixture-input.f32le').read_bytes())
    assert all(value == f32(echo[index] + supplied[index]) for index, value in enumerate(mixed))
    for label, payload in [('short', b'\0' * 4), ('long', supplied.tobytes() + b'\0'),
                           ('nan', b'\0' * (96000 * 4) + struct.pack('<f', float('nan')) + b'\0' * (223999 * 4)),
                           ('early', struct.pack('<f', 0.25) + b'\0' * (319999 * 4))]:
        invalid = root / label
        invalid.write_bytes(payload)
        target = root / (label + '-output')
        failed = subprocess.run([binary, library, str(target), '--near-input', str(invalid)],
                                capture_output=True, timeout=30)
        assert failed.returncode != 0 and not target.exists()
    mutated_output = root / 'mutated-output'
    failed = subprocess.run([binary, library, str(mutated_output), '--near-input', str(external)],
                            env={**os.environ, 'OPENKRISP_AEC_FIXTURE_MUTATE_INPUT': str(external)},
                            capture_output=True, timeout=30)
    assert failed.returncode != 0 and b'near input changed during processing' in failed.stderr
    assert not mutated_output.exists()
    assert subprocess.run([binary], capture_output=True, timeout=30).returncode != 0
print('AEC doubletalk own-fixture signal, fresh control, publication and failure tests passed')
