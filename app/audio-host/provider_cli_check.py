#!/usr/bin/env python3
"""Reject incomplete provider launches before any aggregate can be created."""
from pathlib import Path
import subprocess
binary = Path(__file__).resolve().parent / 'build/audio-host'
base = [str(binary), '--route', '--input', 'openkrisp-nonexistent-input', '--output', 'openkrisp-nonexistent-output']
complete = ['--microphone-noise-suppression', '--microphone-provider', 'installed-krisp']
for flag in ['node', 'worker', 'addon', 'model', 'adapter', 'library']:
    complete += ['--provider-' + flag, '/fixture/' + flag]
for flag in ['node-sha256', 'adapter-sha256']:
    complete += ['--provider-' + flag, 'a' * 64]
cases = [
    (['--microphone-provider', 'installed-krisp'], 'requires microphone suppression'),
    (complete[1:], 'requires microphone suppression'),
    (complete[:-2], 'all runtime options'),
    (complete + ['--provider-node', '/another'], 'Repeated or incomplete'),
    (['--microphone-provider', 'unknown'], 'Unsupported microphone provider'),
    (['--provider-unknown', '/fixture'], 'Unknown provider option'),
    (['--provider-node'], 'Repeated or incomplete'),
]
bad = list(complete); bad[bad.index('--provider-node-sha256')+1] = 'bad'
cases.append((bad, 'Expected lowercase SHA256'))
bad = list(complete); bad[bad.index('--provider-worker')+1] = 'relative'
cases.append((bad, 'Expected absolute UTF-8 path'))
for arguments, error in cases:
    run = subprocess.run(base + arguments, capture_output=True, text=True, timeout=5)
    assert run.returncode != 0 and error in run.stderr, (arguments, run.returncode, run.stdout, run.stderr)
print('PASS: nine provider CLI rejections before aggregate creation. No route started.')
