#!/usr/bin/env python3
"""Opt-in stabilized readiness and owned cleanup. No audio activity or restart."""
import hashlib
import json
import os
from pathlib import Path
import selectors
import subprocess
import time
if os.environ.get('OPENKRISP_AUDIO_USE_STABILIZED_ATTACH_TEST') != '1':
    raise SystemExit('Set OPENKRISP_AUDIO_USE_STABILIZED_ATTACH_TEST=1 after review.')
started=time.monotonic()
summary={'executable_sha256':hashlib.sha256(Path('build/audio-host').read_bytes()).hexdigest(),
         'deadline_seconds':8,'line_limit_bytes':524800,'ready':False,'cleanup_verified':False,'snapshot_count':0,'max_line_bytes':0}
p=subprocess.Popen(['./build/audio-host','--watch-audio-use-stabilized'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
selector=selectors.DefaultSelector();selector.register(p.stdout,selectors.EVENT_READ)
buffer=b'';sequence=0
try:
    while time.monotonic()-started<8:
        for key,_ in selector.select(0.1):
            data=os.read(key.fd,16384)
            if not data:selector.unregister(key.fileobj);continue
            buffer+=data
            while b'\n' in buffer:
                line,buffer=buffer.split(b'\n',1);assert len(line)+1<=524800
                summary['max_line_bytes']=max(summary['max_line_bytes'],len(line)+1)
                event=json.loads(line)
                assert event['version']==1 and event['sequence']>sequence and event['timing_mode']=='stabilized'
                sequence=event['sequence']
                if event['event']=='audio_use_snapshot':
                    summary['snapshot_count']+=1
                    assert event['source_state']=='running', 'Unexpected recovery state during idle readiness check.'
                    assert event['snapshot']['status']=='available', 'Stabilized source is not available.'
                    assert event['publication_reason'] in ('readiness','changed')
                    assert isinstance(event['coalesced_publications'],int) and event['coalesced_publications']>=0
                    rows=event['snapshot']['processes']
                    assert all(isinstance(row['usage_stale'],bool) and isinstance(row['stabilization_pending'],bool) for row in rows)
                    if not summary['ready']:
                        summary.update(ready=True,readiness_seconds=round(time.monotonic()-started,3),initial_generation=event['generation'],
                                       process_count=len(rows),rows_with_errors=sum(bool(row['errors']) for row in rows),
                                       stale_rows=sum(row['usage_stale'] for row in rows),pending_rows=sum(row['stabilization_pending'] for row in rows),
                                       publication_reason=event['publication_reason'],changed_directions=event['changed_directions'],
                                       coalesced_publications=event['coalesced_publications'])
                        p.stdin.write(b'stop\n');p.stdin.flush()
                elif event['event']=='audio_use_stopped':
                    assert event['cleanup_verified'] is True
                    summary.update(cleanup_verified=True,stop_generation=event['generation'])
                    for field in ('listeners_removed','listeners_invalid_object_retired','listeners_remove_failed','all_listener_removals_verified'):
                        summary[field]=event[field]
            assert len(buffer)<=524800
        if summary['cleanup_verified'] or p.poll() is not None:break
    assert summary['ready'] and summary['cleanup_verified'], 'No stabilized readiness and verified cleanup within deadline.'
    assert p.wait(timeout=2)==0
finally:
    if p.poll() is None:
        p.terminate()
        try:p.wait(timeout=4)
        except subprocess.TimeoutExpired:p.kill();p.wait(timeout=2)
    selector.close()
    summary.update(exit_code=p.returncode,final_sequence=sequence,elapsed_seconds=round(time.monotonic()-started,3))
    print(json.dumps(summary,sort_keys=True),flush=True)
