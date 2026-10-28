#!/usr/bin/env python3
"""Opt-in callback/membership acceptance. Own observers only; no audio activity."""
import hashlib
import json
import os
from pathlib import Path
import selectors
import subprocess
import time

if os.environ.get('OPENKRISP_AUDIO_USE_MEMBERSHIP_TEST') != '1':
    raise SystemExit('Set OPENKRISP_AUDIO_USE_MEMBERSHIP_TEST=1 after plan review.')
LINE_LIMIT = 524800
started = time.monotonic()
selector = selectors.DefaultSelector()
children = []
summary = {'executable_sha256': hashlib.sha256(Path('build/audio-host').read_bytes()).hexdigest(),
           'overall_deadline_seconds': 20, 'phase_deadline_seconds': 5, 'line_limit_bytes': LINE_LIMIT,
           'result': 'not_observed', 'appearance': False, 'disappearance': False, 'children': {}}

class Child:
    def __init__(self, name):
        self.name = name
        self.p = subprocess.Popen(['./build/audio-host', '--watch-audio-use'], stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.buffer = b''
        self.sequence = 0
        self.generation = 0
        self.last = None
        self.stop_sent = False
        self.stopped = False
        self.stats = {'snapshot_count': 0, 'failed_snapshots': 0, 'available_snapshots': 0,
                      'max_line_bytes': 0, 'max_process_count': 0, 'cleanup_verified': False,
                      'forced_termination': False, 'forced_kill': False, 'source_diagnostics': []}
        summary['children'][name] = self.stats
        children.append(self)
        selector.register(self.p.stdout, selectors.EVENT_READ, self)

    def stop(self):
        if self.p.poll() is None and not self.stop_sent:
            self.stop_sent = True
            try:
                self.p.stdin.write(b'stop\n')
                self.p.stdin.flush()
            except (BrokenPipeError, OSError):
                pass

    def receive(self, data):
        self.buffer += data
        while b'\n' in self.buffer:
            line, self.buffer = self.buffer.split(b'\n', 1)
            assert len(line) + 1 <= LINE_LIMIT, 'Observer line exceeds limit.'
            self.stats['max_line_bytes'] = max(self.stats['max_line_bytes'], len(line) + 1)
            event = json.loads(line)
            assert event['version'] == 1 and event['sequence'] > self.sequence, 'Invalid version or event sequence.'
            assert event['generation'] >= self.generation, 'Observer generation regressed.'
            self.sequence, self.generation = event['sequence'], event['generation']
            if event['event'] == 'audio_use_snapshot':
                snapshot = event['snapshot']
                self.stats['snapshot_count'] += 1
                self.stats['max_process_count'] = max(self.stats['max_process_count'], len(snapshot['processes']))
                if snapshot['status'] == 'available':
                    self.stats['available_snapshots'] += 1
                else:
                    self.stats['failed_snapshots'] += 1
                for diagnostic in snapshot['errors']:
                    if len(self.stats['source_diagnostics']) < 16:
                        self.stats['source_diagnostics'].append(str(diagnostic)[:512])
                self.last = (self.sequence, snapshot)
            elif event['event'] == 'audio_use_stopped':
                assert event.get('cleanup_verified') is True, 'Unverified stop event.'
                self.stopped = True
                self.stats['cleanup_verified'] = True
                for field in ('listeners_removed', 'listeners_invalid_object_retired', 'listeners_remove_failed', 'all_listener_removals_verified'):
                    self.stats[field] = event.get(field)
                assert all(isinstance(self.stats[field], int) and self.stats[field] >= 0 for field in ('listeners_removed', 'listeners_invalid_object_retired', 'listeners_remove_failed')), 'Missing listener ownership outcome counts.'
                assert isinstance(self.stats['all_listener_removals_verified'], bool), 'Missing listener removal distinction.'
            elif event['event'] == 'audio_use_error':
                self.stats['terminal_error'] = True
                for diagnostic in event.get('snapshot', {}).get('errors', []):
                    if len(self.stats['source_diagnostics']) < 16:
                        self.stats['source_diagnostics'].append(str(diagnostic)[:512])
        assert len(self.buffer) <= LINE_LIMIT, 'Observer partial line exceeds limit.'

def pump():
    for key, _ in selector.select(0.05):
        data = os.read(key.fd, 16384)
        if data:
            key.data.receive(data)
        else:
            selector.unregister(key.fileobj)

def until(predicate, phase):
    deadline = min(started + 20, time.monotonic() + 5)
    while time.monotonic() < deadline:
        pump()
        if predicate():
            return True
    summary['unobserved_phase'] = phase
    return False

def available(child):
    return child.last is not None and child.last[1]['status'] == 'available'

def contains(child, pid):
    return available(child) and any(row['actual_pid'] == pid for row in child.last[1]['processes'])

try:
    a = Child('A')
    if until(lambda: available(a), 'A baseline'):
        summary['baseline_sequence'] = a.sequence
        b = Child('B')
        if until(lambda: available(b) and contains(a, b.p.pid), 'B appearance'):
            summary['appearance'] = True
            summary['appearance_sequence'] = a.last[0]
            # Drain complete currently readable events before the stop phase.
            # Acquisition timestamps are unavailable; receipt order is the evidence bound.
            while time.monotonic() < started + 20 and selector.select(0):
                pump()
            stop_sequence = a.sequence
            summary['stop_request_A_sequence'] = stop_sequence
            b.stop()
            if until(lambda: b.stopped and b.p.poll() == 0, 'B verified stop'):
                summary['B_exit_A_sequence'] = a.sequence
                # Require a later available observation with no unresolved process PID.
                # It can arrive during B cleanup; do not claim a post-exit acquisition time.
                if until(lambda: available(a) and a.last[0] > stop_sequence and all(isinstance(row['actual_pid'], int) and row['actual_pid'] > 0 for row in a.last[1]['processes']) and not contains(a, b.p.pid), 'B disappearance'):
                    summary['disappearance'] = True
                    summary['disappearance_timing'] = 'received_during_or_after_B_stop'
                    summary['acquisition_timestamp_available'] = False
                    summary['disappearance_sequence'] = a.last[0]
                    summary['result'] = 'observed'
except Exception as error:
    summary['result'] = 'failed'
    summary['error_type'] = type(error).__name__
finally:
    for child in children:
        child.stop()
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline and any(c.p.poll() is None for c in children):
        try:
            pump()
        except Exception as error:
            summary['cleanup_parser_error'] = type(error).__name__
            break
    for child in children:
        if child.p.poll() is None:
            child.stats['forced_termination'] = True
            child.p.terminate()
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline and any(c.p.poll() is None for c in children):
        try:
            pump()
        except Exception:
            break
    for child in children:
        if child.p.poll() is None:
            child.stats['forced_kill'] = True
            child.p.kill()
        child.p.wait(timeout=2)
        child.stats.update(exit_code=child.p.returncode, final_sequence=child.sequence,
                           final_generation=child.generation, partial_bytes=len(child.buffer))
        child.p.stdin.close()
        child.p.stdout.close()
        child.p.stderr.close()
    selector.close()
    summary['elapsed_seconds'] = round(time.monotonic() - started, 3)
    summary['all_cleanup_verified'] = all(c.stopped and c.p.returncode == 0 for c in children)
    print(json.dumps(summary, sort_keys=True), flush=True)
raise SystemExit(0 if summary['result'] == 'observed' and summary['all_cleanup_verified'] else 2)
