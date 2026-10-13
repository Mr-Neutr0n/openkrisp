"""Exercise the production controller with a synthetic backend, never a device."""
import json
import os
from pathlib import Path
import queue
import signal
import subprocess
import sys
import tempfile
import threading
import time
import uuid
import wave

fixture = str(Path('build/microphone-test-wire-fixture').resolve())

def start(directory, failure=''):
    operation = str(uuid.uuid4())
    environment = os.environ.copy()
    environment['LABVOICE_MIC_FIXTURE_FAILURE'] = failure
    child = subprocess.Popen([fixture, operation, directory], stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=environment)
    messages = queue.Queue()
    def read():
        for line in child.stdout:
            messages.put(json.loads(line))
        messages.put(None)
    threading.Thread(target=read, daemon=True).start()
    return child, operation, messages

def event(messages, name, timeout=5):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = messages.get(timeout=max(.01, deadline-time.monotonic()))
        assert value is not None, 'unexpected child EOF'
        if value.get('event') == name or value.get('type') == name:
            return value
    raise AssertionError(name)

def send(child, operation, kind, sequence):
    child.stdin.write(json.dumps(dict(type=kind, operationID=operation, sequence=sequence))+'\n')
    child.stdin.flush()

def sufficient(messages):
    while True:
        value = event(messages, 'test_progress')
        if value['frames'] >= 240000:
            return

with tempfile.TemporaryDirectory(prefix='labvoice-mic-wire-') as root:
    def directory(name):
        result = str(Path(root)/name)
        os.mkdir(result, 0o700)
        return result
    path = directory('success')
    child, operation, messages = start(path)
    value = event(messages, 'test_started')
    assert value['operationID'] == operation and value['minimumFrames'] == 240000 and value['maximumFrames'] == 2880000
    sufficient(messages)
    send(child, operation, 'test-stop', 1)
    assert event(messages, 'test-ack')['accepted']
    result = event(messages, 'test_result')
    assert result['status'] == 'completed' and result['frames'] == 240000 and result['engine'] == 'RNNoise'
    assert result['adapterBufferingFrames'] == 480 and result['adapterDelayAligned']
    assert child.wait(timeout=3) == 0
    for key, name in [('originalPath','original.wav'), ('processedPath','processed.wav')]:
        assert result[key] == str(Path(path)/name) and os.stat(result[key]).st_mode & 0o777 == 0o600
        with wave.open(result[key]) as wav:
            assert wav.getnframes() == 240000 and wav.getframerate() == 48000 and wav.getnchannels() == 1 and wav.getsampwidth() == 2
    child, operation, messages = start(directory('early'), 'slow-capture')
    event(messages, 'test_started')
    send(child, operation, 'test-stop', 1)
    reply = event(messages, 'test-ack')
    assert not reply['accepted'] and reply['error'] == 'minimum_duration'
    send(child, operation, 'test-cancel', 2)
    assert event(messages, 'test-ack')['accepted']
    assert event(messages, 'test_result')['status'] == 'cancelled' and child.wait(timeout=3) == 0
    for mode in ['eof','sigterm','processing-cancel']:
        path = directory(mode)
        child, operation, messages = start(path)
        event(messages, 'test_started')
        if mode == 'eof':
            child.stdin.close()
        elif mode == 'sigterm':
            child.send_signal(signal.SIGTERM)
        else:
            sufficient(messages)
            send(child, operation, 'test-stop', 1)
            event(messages, 'test-ack')
            send(child, operation, 'test-cancel', 2)
            assert event(messages, 'test-ack')['accepted']
        assert event(messages, 'test_result')['status'] == 'cancelled' and child.wait(timeout=3) == 0
    for failure in ['stop','unregister','unwatch','gap','oversized-callback','zero-layout','oversized-layout','topology','no-callback']:
        path = directory(failure)
        child, operation, messages = start(path, failure)
        if failure in ['stop','unregister','unwatch']:
            event(messages, 'test_started'); sufficient(messages)
            send(child, operation, 'test-stop', 1)
        result = event(messages, 'test_result', 6)
        assert result['status'] == 'failed' and 'originalPath' not in result and 'processedPath' not in result
        if failure == 'no-callback': assert result['error'] == 'microphone_callback_stalled'
        assert child.wait(timeout=4) != 0 and not list(Path(path).glob('*.wav'))
    path = directory('automatic-maximum')
    child, operation, messages = start(path, 'maximum')
    event(messages, 'test_started')
    result = event(messages, 'test_result', 15)
    assert result['status'] == 'completed' and result['frames'] == 2880000
    assert child.wait(timeout=3) == 0
    with wave.open(result['processedPath']) as wav:
        assert wav.getnframes() == 2880000
    # The actual owner exits while start is paused. Stdin is disabled to prove
    # cancellation comes from the early parent snapshot, not from EOF.
    path = directory('parent-loss')
    operation = str(uuid.uuid4())
    launcher = '''import os,subprocess,sys,time
os.environ['LABVOICE_MIC_FIXTURE_FAILURE']='slow-start'
os.environ['LABVOICE_MIC_FIXTURE_NO_STDIN']='1'
subprocess.Popen(sys.argv[1:],stdin=subprocess.DEVNULL)
time.sleep(.1)
os._exit(0)
'''
    owner = subprocess.Popen([sys.executable, '-c', launcher, fixture, operation, path],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    output, error = owner.communicate(timeout=4)
    values = [json.loads(line) for line in output.splitlines()]
    assert values[-1]['event'] == 'test_result' and values[-1]['status'] == 'cancelled', (values,error)
    assert not list(Path(path).glob('*.wav'))
print('PASS: production test controller real pipes: successful same-input WAV pair, minimum rejection, explicit cancel, EOF/SIGTERM/processing cancel, parent loss during start without stdin, zero/oversized layouts, clock/topology faults, teardown failures and bounded callback stall. No physical microphone opened.')
