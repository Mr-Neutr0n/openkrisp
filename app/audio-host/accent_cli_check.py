#!/usr/bin/env python3
"""Production route parser linked to a sink, with no audio or vendor load."""
from pathlib import Path
import json
import subprocess

binary = Path(__file__).resolve().parent / 'build/provider-cli-fixture'
base = [str(binary), '--route', '--input', 'fixture-input', '--output', 'fixture-output']
complete = []
for name in ['node', 'worker', 'addon', 'model', 'adapter', 'library']:
    complete += ['--accent-' + name, '/fixture/' + name]
complete += ['--accent-adapter-sha256', 'a' * 64, '--accent-node-sha256', '533bd644c5ae0e0ea3a80e433aad16b817447ccba1e1eea701875eac80cb75d4']
okay = subprocess.run(base + complete, capture_output=True, text=True, timeout=5)
assert okay.returncode == 0, okay.stderr
result = json.loads(okay.stdout)
assert result['accent'] == {'direction': 'outbound', 'model': '/fixture/model'}
assert result['microphone_noise'] is False and result['microphone'] is None
for suffix in [[], ['--speaker-noise-suppression']]:
    result = subprocess.run(base + complete + suffix, capture_output=True, text=True, timeout=5)
    assert result.returncode == 0, result.stderr
bad = list(complete)
bad[1] = 'relative'
unknown = list(complete)
unknown[-1] = 'a' * 64
for args in [unknown, complete[:-2], complete + ['--accent-node', '/other'], complete + ['--accent-target', 'uk'],
             complete + ['--accent-direction', 'inbound'], complete + ['--microphone-noise-suppression'],
             complete + ['--aec-provider', 'installed-krisp', '--aec-worker', '/fixture/worker',
                         '--aec-worker-sha256', 'a' * 64, '--aec-library', '/fixture/library'], bad]:
    result = subprocess.run(base + args, capture_output=True, text=True, timeout=5)
    assert result.returncode != 0, (args, result.stdout)
print('Accent CLI exact complete configuration, separate direction and invalid-composition rejection passed. No route started.')
