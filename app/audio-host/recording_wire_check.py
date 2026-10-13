"""Real process/JSON/WAV checks with synthetic samples only, no CoreAudio."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid
import wave

operation = str(uuid.uuid4())
with tempfile.TemporaryDirectory(prefix="labvoice-wire-") as directory:
    os.chmod(directory, 0o700)
    child = subprocess.Popen(["build/recording-wire-fixture", operation], stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, text=True)
    recording = str(uuid.uuid4())
    path = str(Path(directory) / "mix.wav")
    def command(action, sequence, **extra):
        value = dict(type="recording-" + action, operationID=operation,
                     sequence=sequence, recordingID=recording, **extra)
        child.stdin.write(json.dumps(value) + "\n")
        child.stdin.flush()
        reply = json.loads(child.stdout.readline())
        assert reply["type"] == "recording-ack" and reply["sequence"] == sequence
        assert reply["recordingID"] == recording and reply["operationID"] == operation
        return reply
    assert command("start", 1, path=path)["accepted"]
    assert not command("pause", 1)["accepted"]
    assert command("pause", 2)["accepted"]
    assert not command("pause", 3)["accepted"]
    assert command("resume", 4)["accepted"]
    assert command("stop", 5)["accepted"]
    result = json.loads(child.stdout.readline())
    assert result["status"] == "completed" and result["frames"] == 32
    assert result["path"] == path and result["sampleRate"] == 48000 and result["channels"] == 2
    assert os.stat(path).st_mode & 0o777 == 0o600
    with wave.open(path) as wav:
        assert wav.getnframes() == 32 and wav.getsampwidth() == 2 and wav.getframerate() == 48000
    assert not command("start", 6, path=path)["accepted"]
    recording = str(uuid.uuid4())
    assert command("start", 7, path=str(Path(directory) / "eof.wav"))["accepted"]
    child.stdin.close()
    result = json.loads(child.stdout.readline())
    assert result["status"] == "completed" and result["frames"] == 16
    assert child.wait(timeout=3) == 0
print("PASS: actual synthetic recording pipe start/pause/resume/stop, stale/invalid transition, exclusive collision, RIFF validation and EOF finalization.")
