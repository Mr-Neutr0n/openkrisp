#!/usr/bin/env python3
"""Own injected capture source + actual CLI/writer. Never calls a native tap API."""
import array, json, os, pathlib, selectors, subprocess, sys, tempfile, time, wave

root = pathlib.Path(__file__).resolve().parent
target = {"responsible_pid": 100, "app_id": "own.fixture", "processes": [{"object_id": 42, "actual_pid": 101}]}
operation = "12345678-1234-1234-1234-123456789abc"
def line(process):
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        assert selector.select(5), "fixture output timeout"
    return json.loads(process.stdout.readline())

for dual, delayed in ((False, False), (False, True), (True, False), (True, True)):
    with tempfile.TemporaryDirectory(prefix="selected-app-cli-") as temporary:
        path = pathlib.Path(temporary) / "recording.wav"
        args = [str(root / "build/selected-app-capture-cli-fixture"), "--capture-selected-app", "--operation-id", operation,
                "--target-json", json.dumps(target), "--output", str(path)]
        if dual: args += ["--microphone-uid", "own.fixture.microphone"]
        env = dict(os.environ)
        if delayed: env["OPENKRISP_FIXTURE_DELAY"] = "1"
        process = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
        try:
            if delayed:
                process.stdin.write(b"stop\n"); process.stdin.flush()
            else:
                started = line(process)
                assert started["event"] == "app_capture_started" and started["operation_id"] == operation
                assert started["target"] == target
                assert started["source"] == ("selected_app_output_and_microphone" if dual else "selected_app_output")
                if dual:
                    assert started["microphone_uid"] == "own.fixture.microphone"
                    assert started["microphone_object_id"] == 77
                    assert started["microphone_source_format"]["sample_rate"] == 48000
                    assert started["microphone_source_format"]["channels"] == 1
                    assert started["mix_policy"] == "app_half_mic_half"
                    assert started["timeline_policy"] == "adjacent_host_anchors_common_overlap"
                time.sleep(0.1)
                process.stdin.write(b"stop\n"); process.stdin.flush()
            result = line(process)
            assert result["event"] == "app_capture_result" and result["target"] == target
            assert result["source"] == ("selected_app_output_and_microphone" if dual else "selected_app_output")
            assert result["cleanup_verified"] and result["path"] == str(path)
            status = process.wait(timeout=5)
            assert not process.stderr.read()
            if delayed:
                assert status == 2 and result["status"] == "failed" and result["frames"] == 0
            else:
                assert status == 0 and result["status"] == "completed" and result["frames"] > 0
                with wave.open(str(path)) as wav:
                    assert (wav.getframerate(), wav.getnchannels(), wav.getsampwidth(), wav.getnframes()) == (48000, 2, 2, result["frames"])
                    samples = array.array("h", wav.readframes(wav.getnframes()))
                    if sys.byteorder != "little": samples.byteswap()
                    expected = 8192 if dual else 4096
                    assert samples and max(abs(sample - expected) for sample in samples) <= 2
                    assert samples[::2] == samples[1::2], "mono microphone must enter both output channels equally"
                if dual:
                    timeline = result["timeline"]
                    assert timeline["output_frames"] == result["frames"]
                    assert timeline["first_host_time"] >= 1003000000
                    assert timeline["end_host_time"] > timeline["first_host_time"]
                    assert abs((timeline["end_host_time"] - timeline["first_host_time"]) * 48000 / 1e9 - result["frames"]) < 1
                    for lane in ("app", "microphone"):
                        assert timeline[lane + "_source_frames"] > 0
                        assert timeline[lane + "_startup_frames"] >= 32
                        assert timeline[lane + "_tail_frames"] >= 480
                        assert timeline[lane + "_maximum_drift_ppm"] > 100
                        assert timeline[lane + "_last_host_time"] > timeline[lane + "_first_host_time"]
                    assert result["microphone_object_id"] == 77
                    assert result["mix_policy"] == "app_half_mic_half"
                    assert result["timeline_policy"] == "adjacent_host_anchors_common_overlap"
        finally:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=3)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
for args in (["--capture-selected-app"], ["--capture-selected-app", "--unknown"]):
    rejected = subprocess.run([str(root / "build/audio-host"), *args], capture_output=True, timeout=5)
    assert rejected.returncode == 64 and not rejected.stdout
print("Selected-app real CLI/injected app and dual-source WAV, drift timeline and startup cancellation passed. No native capture executed.")
