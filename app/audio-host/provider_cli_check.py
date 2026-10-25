#!/usr/bin/env python3
"""Reject incomplete provider launches before any aggregate can be created."""
from pathlib import Path
import subprocess
import json
import sys
binary = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parent / 'build/audio-host'
base = [str(binary), '--route', '--input', 'openkrisp-nonexistent-input', '--output', 'openkrisp-nonexistent-output']
complete = ['--microphone-noise-suppression', '--microphone-provider', 'installed-krisp']
for flag in ['node', 'worker', 'addon', 'model', 'adapter', 'library']:
    complete += ['--provider-' + flag, '/fixture/' + flag]
for flag in ['node-sha256', 'adapter-sha256']:
    complete += ['--provider-' + flag, 'a' * 64]
cases = [
    (complete + ['--provider-model-role', 'inbound'], 'Unsupported microphone model role'),
    (complete + ['--provider-model-role', 'unknown'], 'Unsupported microphone model role'),
    (complete + ['--provider-model-role'], 'Repeated or incomplete'),
    (complete + ['--provider-model-role', 'outbound', '--provider-model-role', 'outbound-hvc-lfb'], 'Repeated or incomplete'),
    (['--provider-model-role', 'outbound-hvc-lfb'], 'all runtime options'),
    (complete[:-2] + ['--provider-model-role', 'outbound-hvc-lfb'], 'all runtime options'),
    (complete[1:] + ['--provider-model-role', 'outbound-hvc-lfb'], 'requires microphone suppression'),
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
speaker = [s.replace('--microphone-', '--speaker-') if s.startswith('--microphone-') else
           s.replace('--provider-', '--speaker-provider-', 1) if s.startswith('--provider-') else s for s in complete]
speaker = [x.replace('/fixture/', '/speaker-fixture/') if x.startswith('/fixture/') else 'b' * 64 if x == 'a' * 64 else x for x in speaker]
speaker_cases = [
    (speaker + ['--speaker-provider-model-role', 'outbound-hvc-lfb'], 'Unknown provider option'),
    (speaker + ['--speaker-provider-model-role', 'inbound'], 'Unknown provider option'),
    (speaker[1:], 'requires speaker suppression'),
    (speaker[:-2], 'all runtime options'),
    (speaker + ['--speaker-provider-node', '/another'], 'Repeated or incomplete'),
    (['--speaker-provider', 'unknown'], 'Unsupported speaker provider'),
    (['--speaker-provider-unknown', '/fixture'], 'Unknown provider option'),
    (['--speaker-provider-node'], 'Repeated or incomplete'),
    (speaker[:1] + speaker[3:], 'all runtime options'),
    (complete + speaker[:-2], 'all runtime options'),
    (complete[:-2] + speaker, 'all runtime options'),
]
bad = list(speaker); bad[bad.index('--speaker-provider-node-sha256')+1] = 'bad'
speaker_cases.append((bad, 'Expected lowercase SHA256'))
bad = list(speaker); bad[bad.index('--speaker-provider-worker')+1] = 'relative'
speaker_cases.append((bad, 'Expected absolute UTF-8 path'))
for arguments, error in speaker_cases:
    run = subprocess.run(base + arguments, capture_output=True, text=True, timeout=5)
    assert run.returncode != 0 and error in run.stderr, (arguments, run.returncode, run.stdout, run.stderr)
# This executable uses the actual host.cpp parser but replaces route startup.
fixture = binary.with_name('provider-cli-fixture')
for arguments, mic, spk in [(complete, True, False), (speaker, False, True),
                           (complete + speaker, True, True),
                           (speaker + ['--microphone-noise-suppression'], False, True),
                           (complete + ['--speaker-noise-suppression'], True, False)]:
    run = subprocess.run([str(fixture), *base[1:], *arguments], capture_output=True, text=True, timeout=5)
    assert run.returncode == 0, (run.stdout, run.stderr)
    result = json.loads(run.stdout)
    assert (result['microphone'] is not None) == mic and (result['speaker'] is not None) == spk
    if mic:
        assert result['startup']['provider_model_role'] == 'outbound'
        assert result['microphone']['role'] == 'outbound'
        assert result['microphone']['node'] == '/fixture/node' and result['microphone']['model'] == '/fixture/model'
        assert result['microphone']['model_sha256'] == '12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d'
    if spk:
        assert result['startup']['speaker_provider_model_role'] == 'inbound'
        assert result['speaker']['role'] == 'inbound'
        assert result['speaker']['node'] == '/speaker-fixture/node' and result['speaker']['model'] == '/speaker-fixture/model'
        assert result['speaker']['model_sha256'] == 'd1e4e2a94fe27dec1a8fd5a7b36cfac38d183a110f738156d85d1317f98fac8a'
for role, digest in [('outbound','12110c114a3c6c4e2a00c26b22d06463239d096da9f7b71a948fd3a7005b355d'),
                     ('outbound-hvc-lfb','54e2913ea45734adc3323407e43f55b14afade256ab4da6226c2b6e30604cbf4')]:
    run=subprocess.run([str(fixture),*base[1:],*complete,'--provider-model-role',role,*speaker],capture_output=True,text=True,timeout=5)
    assert run.returncode==0,(run.stdout,run.stderr)
    result=json.loads(run.stdout)
    assert result['microphone']['role']==role and result['microphone']['model_sha256']==digest
    assert result['startup']['provider_model_role']==role and result['startup']['provider_model_sha256']==digest
    assert result['startup']['speaker_provider_model_role']=='inbound'
# Reject the unsupported composition before AEC worker hashing or the route sink.
aec=['--aec-provider','installed-krisp','--aec-worker','/nonexistent/worker','--aec-worker-sha256','a'*64,'--aec-library','/fixture/aec']
for arguments in [complete+['--provider-model-role','outbound-hvc-lfb']+aec,
                  aec+complete+['--provider-model-role','outbound-hvc-lfb']]:
    run=subprocess.run([str(fixture),*base[1:],*arguments],capture_output=True,text=True,timeout=5)
    assert run.returncode!=0 and 'cannot be combined with AEC' in run.stderr and not run.stdout,(run.stdout,run.stderr)
print(f'PASS: {len(cases)+len(speaker_cases)} provider CLI rejections, seven parser profiles and two HVC/AEC rejections. No route started.')
