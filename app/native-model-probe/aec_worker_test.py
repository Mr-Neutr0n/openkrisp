#!/usr/bin/env python3
"""Exercise only our native AEC worker and independent synthetic producer."""
import hashlib
import json
import os
from pathlib import Path
import select
import struct
import subprocess
import sys
import tempfile
import time

worker, library = map(lambda value: str(Path(value).resolve()), sys.argv[1:])
digest = hashlib.sha256(Path(library).read_bytes()).hexdigest()
token = bytes(range(16))
def frame(kind, sequence, epoch=7, value=0.25, reference=0.1):
    header = bytearray(120)
    struct.pack_into('<IBB', header, 0, 0x41454344, 1, kind)
    header[8:24] = token
    payload = struct.pack('<1440f', *([value]*480 + [reference]*960)) if kind == 1 else b''
    struct.pack_into('<QIQ', header, 24, sequence, len(payload), epoch)
    if kind != 3:
        for offset, origin in [(44, 100.25), (76, 900.75)]:
            struct.pack_into('<ddQI', header, offset, origin+sequence*480, origin+sequence*480+120, sequence+1, 3)
    return bytes(header) + payload
def launch(extra=None, sha=digest, sandbox=True):
    env = {'PATH': '/usr/bin:/bin', **(extra or {})}
    command = ['/bin/sh', '-c', 'exec "$@" 3>&1 1>/dev/null', 'aec-worker', worker, library, sha, token.hex(), str(os.getpid())]
    if sandbox:
        command = ['/usr/bin/sandbox-exec', '-p', '(version 1) (allow default) (deny network*)', *command]
    return subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
def read(process, count):
    result = b''
    deadline = time.monotonic() + 5
    while len(result) < count:
        assert time.monotonic() < deadline, 'response timeout'
        ready, _, _ = select.select([process.stdout], [], [], max(0, deadline-time.monotonic()))
        assert ready, 'response timeout'
        piece = os.read(process.stdout.fileno(), count-len(result))
        assert piece, 'unexpected response EOF'
        result += piece
    return result
def ready(process):
    expected = f'OKAEC1 {digest} 48000 1 48000 2\n'.encode()
    assert read(process, len(expected)) == expected
with tempfile.TemporaryDirectory(prefix='openkrisp-aec-worker-') as directory:
    trace = Path(directory)/'trace'
    process = launch({'OPENKRISP_AEC_FIXTURE_TRACE': str(trace)})
    ready(process)
    for sequence in range(17):
        request = frame(1, sequence, value=sequence/64)
        # Partial request writes exercise actual stream reassembly.
        for chunk in [request[:13], request[13:119], request[119:]]:
            process.stdin.write(chunk); process.stdin.flush()
        response = read(process, 2040)
        expected_header = bytearray(request[:120]); expected_header[5] = 2
        struct.pack_into('<I', expected_header, 32, 1920)
        assert response[:120] == expected_header
        expected = struct.unpack('<f', struct.pack('<f', sequence/64-struct.unpack('<f',struct.pack('<f',0.1))[0]))[0]
        assert struct.unpack('<480f', response[120:]) == (expected,)*480
    process.stdin.write(frame(3,17)); process.stdin.close()
    assert read(process,120) == frame(3,17)
    assert process.stdout.read() == b'' and process.wait(timeout=5) == 0
    events = trace.read_text().splitlines()
    assert events == ['create'] + ['reverse','forward']*17 + ['destroy','unload']
    discontinuity = bytearray(frame(1,1)); struct.pack_into('<d', discontinuity, 44, 100.25)
    for payload in [frame(1,0)+discontinuity, b'', frame(1,0)[:-1], b'bad', frame(1,1), frame(1,0, value=float('nan')),
                    frame(1,0)+frame(1,1,epoch=8), frame(3,0)+b'trailing']:
        process = launch(); ready(process)
        process.communicate(payload, timeout=5)
        assert process.returncode != 0
    for mode in ['factory','reverse','forward']:
        process = launch({'OPENKRISP_AEC_FIXTURE_FAILURE':mode})
        if mode != 'factory': ready(process)
        output,error = process.communicate(frame(1,0),timeout=5)
        assert process.returncode != 0
    for process in [launch(sha='0'*64), launch(sandbox=False)]:
        output,error = process.communicate(timeout=5)
        assert process.returncode != 0 and output == b''
    helper = Path(directory)/'orphan.py'
    helper.write_text("""import os,subprocess,sys,time
worker,library,digest,token,trace,payload=sys.argv[1:]
command=['/usr/bin/sandbox-exec','-p','(version 1) (allow default) (deny network*)','/bin/sh','-c','exec \"$@\" 3>&1 1>/dev/null','aec-worker',worker,library,digest,token,str(os.getpid())]
p=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env={'PATH':'/usr/bin:/bin','OPENKRISP_AEC_FIXTURE_BLOCK_FORWARD':'1','OPENKRISP_AEC_FIXTURE_TRACE':trace})
assert p.stdout.readline().startswith(b'OKAEC1 ')
p.stdin.write(bytes.fromhex(payload));p.stdin.flush()
deadline=time.monotonic()+3
while not os.path.exists(trace) or 'reverse' not in open(trace).read():
    assert time.monotonic()<deadline
    time.sleep(.005)
print(p.pid,flush=True)
os._exit(0)
""")
    orphan_trace = Path(directory)/'orphan-trace'
    helper_result = subprocess.run([sys.executable,str(helper),worker,library,digest,token.hex(),str(orphan_trace),frame(1,0).hex()],
                                   capture_output=True,text=True,check=True,timeout=5)
    orphan_pid = int(helper_result.stdout.strip())
    deadline = time.monotonic()+3
    while True:
        try: os.kill(orphan_pid,0)
        except ProcessLookupError: break
        assert time.monotonic()<deadline, 'blocked orphan worker survived parent loss'
        time.sleep(.005)
    assert orphan_trace.read_text().splitlines() == ['create','reverse']
print('AEC persistent worker admission, duplex ordering, lifetime and malformed-stream tests passed')
