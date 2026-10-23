#!/usr/bin/env python3
"""Unassisted paced CPU callbacks through only our AEC fixture library."""
import array
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
fixture,worker,library=map(lambda value:str(Path(value).resolve()),sys.argv[1:4])
maximum=sys.argv[4] if len(sys.argv)>4 else '512'
budget=sys.argv[5] if len(sys.argv)>5 else '4'
worker_sha=hashlib.sha256(Path(worker).read_bytes()).hexdigest()
library_sha=hashlib.sha256(Path(library).read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='openkrisp-aec-paced-') as temporary:
    root=Path(temporary);microphone=root/'microphone';reference=root/'reference'
    mic=array.array('f',((index%113)/256 for index in range(480000)))
    ref=array.array('f',((index//960%17)/128 for index in range(960000)))
    microphone.write_bytes(mic.tobytes());reference.write_bytes(ref.tobytes())
    def command(output,maximum=maximum,budget=budget):
        return [fixture,worker,worker_sha,library,library_sha,str(microphone),str(reference),str(output),maximum,budget]
    destination=root/'output'
    result=subprocess.run(command(destination),capture_output=True,text=True,check=True,timeout=25)
    metadata=json.loads(result.stdout)
    assert metadata==json.loads((destination/'metadata.json').read_text())
    delay=metadata['delaySamples'];total=480000+delay
    assert delay==((int(maximum)+958)//480+int(budget))*480
    assert metadata['outputSamples']==total and metadata['alignedSamples']==480000
    assert metadata['initialSilenceSamples']==delay and metadata['inputSamples']==480000
    assert metadata['callbackCount']==(total+int(maximum)-1)//int(maximum)
    assert 1000<=metadata['processedFrames']<=total//480
    assert metadata['teardownComplete'] is True and metadata['hardwareAudio'] is False
    assert metadata['realtimePaced'] is True
    for name in ['callbackLatenessUs','exchangeDurationUs']:
        values=metadata[name]
        assert 0<=values['p50']<=values['p95']<=values['p99']<=values['max']
    values=array.array('f',(destination/'paced-output.f32le').read_bytes())
    assert len(values)==total and all(map(math.isfinite,values)) and not any(values[:delay])
    for index,value in enumerate(values[delay:]):
        expected=struct.unpack('<f',struct.pack('<f',mic[index]-ref[(index//480)*960]))[0]
        assert value==expected
    assert destination.stat().st_mode&0o777==0o700
    assert all(path.stat().st_mode&0o777==0o600 for path in destination.iterdir())
    original={path.name:path.read_bytes() for path in destination.iterdir()}
    assert subprocess.run(command(destination),capture_output=True,timeout=5).returncode!=0
    assert original=={path.name:path.read_bytes() for path in destination.iterdir()}
    for maximum,budget in [('0','2'),('481','2'),('480','32'),('512','18446744073709551615')]:
        target=root/(maximum+'-'+budget)
        failed=subprocess.run(command(target,maximum,budget),capture_output=True,timeout=5)
        assert failed.returncode!=0 and not target.exists()
    failure=root/'foreign-failure'
    failed=subprocess.run(command(failure),capture_output=True,timeout=5,
                          env={**os.environ,'OPENKRISP_AEC_PACED_FIXTURE_FAILURE':'forward'})
    assert failed.returncode!=0 and not failure.exists()
    assert b'callback=' in failed.stderr and b'samplePosition=' in failed.stderr and b'transportFault=' in failed.stderr
    assert not list(root.glob('*.staging-*'))
print('AEC paced own-worker aligned output, timing metadata and failure publication tests passed')
