#!/usr/bin/env python3
"""Own injected capture source + actual CLI/writer. Never calls a native tap API."""
import json, os, pathlib, selectors, subprocess, tempfile, time, wave

root = pathlib.Path(__file__).resolve().parent
target = {"responsible_pid": 100, "app_id": "own.fixture", "processes": [{"object_id": 42, "actual_pid": 101}]}
operation = "12345678-1234-1234-1234-123456789abc"
def line(process):
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        assert selector.select(5), "fixture output timeout"
    return json.loads(process.stdout.readline())

for delayed in (False, True):
    with tempfile.TemporaryDirectory(prefix="selected-app-cli-") as temporary:
        path = pathlib.Path(temporary) / "recording.wav"
        args = [str(root / "build/selected-app-capture-cli-fixture"), "--capture-selected-app", "--operation-id", operation,
                "--target-json", json.dumps(target), "--output", str(path)]
        env = dict(os.environ)
        if delayed: env["OPENKRISP_FIXTURE_DELAY"] = "1"
        process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
        try:
            if delayed:
                process.stdin.write(b"stop\n"); process.stdin.flush()
            else:
                started = line(process)
                assert started["event"] == "app_capture_started" and started["operation_id"] == operation
                assert started["target"] == target and started["source"] == "selected_app_output"
                time.sleep(0.05)
                process.stdin.write(b"stop\n"); process.stdin.flush()
            result = line(process)
            assert result["event"] == "app_capture_result" and result["target"] == target
            assert result["cleanup_verified"] and result["path"] == str(path)
            status = process.wait(timeout=5)
            assert not process.stderr.read()
            if delayed:
                assert status == 2 and result["status"] == "failed" and result["frames"] == 0
            else:
                assert status == 0 and result["status"] == "completed" and result["frames"] > 0
                with wave.open(str(path)) as wav:
                    assert (wav.getframerate(), wav.getnchannels(), wav.getsampwidth(), wav.getnframes()) == (48000, 2, 2, result["frames"])
        finally:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=3)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
for args in (["--capture-selected-app"], ["--capture-selected-app", "--unknown"]):
    rejected = subprocess.run([str(root / "build/audio-host"), *args], capture_output=True, timeout=5)
    assert rejected.returncode == 64 and not rejected.stdout
print("Selected-app real CLI/injected source WAV and startup cancellation passed. No native capture executed.")
