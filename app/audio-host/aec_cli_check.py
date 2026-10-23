#!/usr/bin/env python3
"""Exercise real host CLI parsing through a sink that cannot start audio or workers."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import tempfile

root=Path(__file__).resolve().parent
fixture=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else root/'build/provider-cli-fixture'
base=[str(fixture),'--route','--input','fixture-mic','--output','fixture-speaker']
with tempfile.TemporaryDirectory(prefix='openkrisp-aec-cli-') as temporary:
    worker=Path(temporary)/'own-worker'
    worker.write_bytes(b'#!/bin/sh\nexit 70\n');worker.chmod(0o700)
    digest=hashlib.sha256(worker.read_bytes()).hexdigest()
    complete=['--aec-provider','installed-krisp','--aec-worker',str(worker),'--aec-worker-sha256',digest,'--aec-library','/fixture/libaec-sdk.dylib']
    for flags in [[],['--speaker-noise-suppression']]:
        result=subprocess.run(base+complete+flags,capture_output=True,text=True,check=True,timeout=5)
        value=json.loads(result.stdout)
        assert value['microphone_noise'] is False and value['microphone'] is None
        assert value['speaker_noise']==bool(flags)
        assert value['aec']=={'worker':str(worker),'worker_sha256':digest,'library':'/fixture/libaec-sdk.dylib',
                              'library_sha256':'bd75d4f1188c778647afab3899c731ecd31ecf4e05751a3e3fc632a616414a3a'}
        ack=value['aec_startup']
        assert ack=={'microphone_provider':'installed-krisp-aec','aec_provider':'installed-krisp',
                     'aec_worker_sha256':digest,'aec_library_sha256':value['aec']['library_sha256'],
                     'aec_delay_samples':5760,'aec_maximum_callback_frames':4096,'aec_scheduling_budget_frames':2,
                     'aec_forward_rate':48000,'aec_forward_channels':1,'aec_reference_rate':48000,'aec_reference_channels':2}
    speaker=['--speaker-noise-suppression','--speaker-provider','installed-krisp']
    for name in ['node','worker','addon','model','adapter','library']:
        speaker+=['--speaker-provider-'+name,'/fixture/'+name]
    for name in ['node-sha256','adapter-sha256']:speaker+=['--speaker-provider-'+name,'a'*64]
    result=subprocess.run(base+complete+speaker,capture_output=True,text=True,check=True,timeout=5)
    assert json.loads(result.stdout)['speaker']['role']=='inbound'
    failures=[(complete[:-2],'all runtime options'),(complete[2:],'all runtime options'),
              (complete+['--aec-worker',str(worker)],'Repeated or incomplete'),
              (['--aec-worker'],'Repeated or incomplete'),(['--aec-provider','other'],'Unsupported AEC'),
              (complete+['--aec-library-sha256','b'*64],'Unknown AEC'),
              (complete+['--noise-suppression'],'cannot be combined'),
              (complete+['--microphone-noise-suppression'],'cannot be combined'),
              (complete+['--microphone-provider','installed-krisp'],'cannot be combined')]
    for flag,replacement,message in [('--aec-worker','relative','absolute path'),
                                     ('--aec-library','relative','absolute path'),
                                     ('--aec-worker-sha256','bad','lowercase SHA256'),
                                     ('--aec-worker-sha256','0'*64,'SHA256 mismatch')]:
        changed=complete.copy();changed[changed.index(flag)+1]=replacement;failures.append((changed,message))
    for flags,message in failures:
        result=subprocess.run(base+flags,capture_output=True,text=True,timeout=5)
        assert result.returncode!=0 and message in result.stderr,(flags,result.stdout,result.stderr)
    off=json.loads(subprocess.run(base,capture_output=True,text=True,check=True,timeout=5).stdout)
    assert not any(key.startswith('aec') for key in off)
print('AEC CLI opt-in, conflicts, exact startup identity fields and legacy-off tests passed; no route started')
