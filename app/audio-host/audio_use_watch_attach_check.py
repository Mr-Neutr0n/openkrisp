#!/usr/bin/env python3
"""Opt-in read-only CoreAudio listener acceptance; excluded from default verify."""
import hashlib
from pathlib import Path
import json
import os
import selectors
import subprocess
import time
if os.environ.get('OPENKRISP_AUDIO_USE_ATTACH_TEST') != '1':
    raise SystemExit('Set OPENKRISP_AUDIO_USE_ATTACH_TEST=1 after review to attach read-only listeners.')
executable_sha256 = hashlib.sha256(Path('./build/audio-host').read_bytes()).hexdigest()
started = time.monotonic()
summary = {'executable_sha256': executable_sha256, 'snapshot_count': 0, 'process_count': 0, 'rows_with_errors': 0, 'source_error_count': 0, 'initial_generation': None, 'stop_generation': None, 'status': None, 'cleanup_verified': False, 'max_line_bytes': 0, 'deadline_seconds': 8, 'line_limit_bytes': 524800}
p = subprocess.Popen(['./build/audio-host', '--watch-audio-use'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
sel = selectors.DefaultSelector()
sel.register(p.stdout, selectors.EVENT_READ)
buffer = b''
sequence = 0
ready = stopped = False
try:
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        for key, _ in sel.select(0.1):
            data = os.read(key.fd, 16384)
            if not data:
                break
            buffer += data
            while b'\n' in buffer:
                line, buffer = buffer.split(b'\n', 1)
                summary['max_line_bytes'] = max(summary['max_line_bytes'], len(line) + 1)
                assert len(line) + 1 <= 524800
                event = json.loads(line)
                assert event['version'] == 1 and event['sequence'] > sequence
                sequence = event['sequence']
                if event['event'] == 'audio_use_snapshot':
                    summary['snapshot_count'] += 1
                if event['event'] == 'audio_use_snapshot' and not ready:
                    snapshot = event['snapshot']
                    summary.update(status=snapshot['status'], initial_generation=event['generation'], process_count=len(snapshot['processes']), rows_with_errors=sum(bool(row['errors']) for row in snapshot['processes']), source_error_count=len(snapshot['errors']))
                    assert snapshot['status'] == 'available', 'Initial snapshot status: ' + snapshot['status']
                    ready = True
                    p.stdin.write(b'stop\n')
                    p.stdin.flush()
                elif event['event'] == 'audio_use_stopped':
                    assert event['cleanup_verified'] is True
                    stopped = True
                    summary.update(cleanup_verified=True, stop_generation=event['generation'])
            assert len(buffer) <= 524800
        if stopped or p.poll() is not None:
            break
    assert ready and stopped, 'No available snapshot and verified detach within 8 seconds.'
    assert p.wait(timeout=2) == 0
finally:
    if p.poll() is None:
        p.terminate()
        try:
            p.wait(timeout=4)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait(timeout=2)
    sel.close()
    summary.update(exit_code=p.returncode, final_sequence=sequence, elapsed_seconds=round(time.monotonic() - started, 3), ready=ready, stopped=stopped)
    print(json.dumps(summary, sort_keys=True), flush=True)
