#!/usr/bin/env python3
"""Own-file integration for bounded AEC worker runtime publication."""
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
fixture,worker,library=map(lambda item:str(Path(item).resolve()),sys.argv[1:])
worker_sha=hashlib.sha256(Path(worker).read_bytes()).hexdigest()
library_sha=hashlib.sha256(Path(library).read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='openkrisp-aec-runtime-') as temporary:
    root=Path(temporary)
    microphone=root/'microphone';reference=root/'reference'
    mic=array.array('f',((index%480-240)/1024 for index in range(480000)))
    ref=array.array('f',((index//960%32)/128 for index in range(960000)))
    microphone.write_bytes(mic.tobytes());reference.write_bytes(ref.tobytes())
    def command(output,mic_path=microphone,ref_path=reference):
        return [fixture,worker,worker_sha,library,library_sha,str(mic_path),str(ref_path),str(output)]
    output=root/'success'
    result=subprocess.run(command(output),capture_output=True,text=True,check=True,timeout=30)
    metadata=json.loads(result.stdout)
    assert metadata==json.loads((output/'metadata.json').read_text())
    assert metadata['frames']==1000 and metadata['samples']==480000 and metadata['teardownComplete'] is True
    assert metadata['realtimePaced'] is False
    latency=metadata['requestLatencyUs']
    assert 0<=latency['p50']<=latency['p95']<=latency['p99']<=latency['max']
    values=array.array('f',(output/'worker-output.f32le').read_bytes())
    assert len(values)==480000 and all(map(math.isfinite,values))
    for index,value in enumerate(values):
        assert value==struct.unpack('<f',struct.pack('<f',mic[index]-ref[(index//480)*960]))[0]
    assert output.stat().st_mode&0o777==0o700
    assert all(path.stat().st_mode&0o777==0o600 for path in output.iterdir())
    baseline={path.name:path.read_bytes() for path in output.iterdir()}
    assert subprocess.run(command(output),capture_output=True,timeout=30).returncode!=0
    assert baseline=={path.name:path.read_bytes() for path in output.iterdir()}
    for label,payload in [('short',b'\0'*4),('long',mic.tobytes()+b'\0'),
                          ('nan',struct.pack('<f',float('nan'))+mic.tobytes()[4:])]:
        invalid=root/label;invalid.write_bytes(payload)
        destination=root/(label+'-output')
        assert subprocess.run(command(destination,invalid),capture_output=True,timeout=30).returncode!=0
        assert not destination.exists()
    linked=root/'linked';linked.symlink_to(microphone)
    assert subprocess.run(command(root/'linked-output',linked),capture_output=True,timeout=30).returncode!=0
    for label,environment in [('foreign',{'OPENKRISP_AEC_RUNTIME_FIXTURE_FAILURE':'forward'}),
                              ('close',{'OPENKRISP_AEC_RUNTIME_FIXTURE_UNLOAD_EXIT':'1'})]:
        destination=root/(label+'-output')
        failed=subprocess.run(command(destination),capture_output=True,timeout=30,env={**os.environ,**environment})
        assert failed.returncode!=0 and not destination.exists()
        assert not list(root.glob('*.staging-*'))
    changed=root/'changed-output'
    failure=subprocess.run(command(changed),capture_output=True,timeout=30,
                           env={**os.environ,'OPENKRISP_AEC_RUNTIME_FIXTURE_MUTATE':str(microphone)})
    assert failure.returncode!=0 and b'input changed during worker run' in failure.stderr
    assert not changed.exists()
    assert not list(root.glob('*.staging-*'))
print('AEC runtime own-fixture exact output, metadata, exclusive publication and input rejection passed')
