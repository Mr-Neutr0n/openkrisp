#!/usr/bin/env python3
"""Opt-in read-only audio-use observation. No IOProc, tap, capture or playback."""
import json
import os
from pathlib import Path
import subprocess

if os.environ.get('LABVOICE_TEST_AUDIO_PROCESS_USAGE') != '1':
    print('Audio-use runtime observation skipped. Set LABVOICE_TEST_AUDIO_PROCESS_USAGE=1 to opt in.')
    raise SystemExit(0)
root = Path(__file__).resolve().parent
result = subprocess.run([str(root / 'build/audio-host'), '--list-audio-use'], capture_output=True, timeout=15, check=True)
data = json.loads(result.stdout)
assert data['operation'] == 'read_only_inventory'
snapshot = data['audio_process_usage']
assert snapshot['status'] in ('available', 'unavailable', 'failed')
assert isinstance(snapshot['errors'], list) and isinstance(snapshot['processes'], list)
for item in snapshot['processes']:
    assert item['object_id'] > 0
    assert item['actual_pid'] is None or item['actual_pid'] > 0
    assert item['responsible_pid'] is None or item['responsible_pid'] > 0
    for direction in ('input', 'output'):
        value = item[direction]
        assert value['running'] in (None, True, False)
        if value['running'] is False:
            assert value['devices'] == []
        if value['devices'] is not None:
            assert all(device['object_id'] >= 0 and (device['uid'] is None or isinstance(device['uid'], str)) for device in value['devices'])
private = root / 'build/audio-process-usage-inventory.json'
private.touch(mode=0o600, exist_ok=True)
private.chmod(0o600)
private.write_bytes(result.stdout)
print('Audio-use runtime snapshot:', snapshot['status'], 'process objects:', len(snapshot['processes']),
      'rows with errors:', sum(bool(item['errors']) for item in snapshot['processes']), 'source errors:', len(snapshot['errors']))
