#!/usr/bin/env python3
"""Exercise only an own synthetic dylib through the standalone probe."""
import array
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import struct
import tempfile

binary, library = map(str, map(Path, sys.argv[1:]))
for broadband in [False, True]:
    with tempfile.TemporaryDirectory(prefix="openkrisp-aec-direct-") as work:
        root = Path(work)
        paths = [root / name for name in ["forward", "reference", "on", "zero"]]
        command = [binary, library, *map(str, paths)]
        if broadband:
            command.append("--broadband")
        frame_count = 1000 if broadband else 300
        result = subprocess.run(command, capture_output=True, text=True, timeout=30, check=True)
        status = json.loads(result.stdout)
        assert status["framesPerEngine"] == frame_count and status["successfulCallsPerEngine"] == frame_count * 2
        assert status["samplesPerOutput"] == frame_count * 320 and status["teardownComplete"] is True
        assert status["delaySetterCalled"] is False
        data = []
        for path, length in zip(paths, [frame_count * 320, frame_count * 960, frame_count * 320, frame_count * 320]):
            values = array.array("f", path.read_bytes())
            assert len(values) == length and all(map(math.isfinite, values))
            assert path.stat().st_mode & 0o777 == 0o600
            data.append(values)
        assert data[1][::2] == data[1][1::2]
        assert data[3] == data[0]  # Own fixture subtracts zero reference exactly.
        assert data[2] != data[3]
        assert status["mode"] == ("broadband" if broadband else "multitone")
        assert status["fixture"] == ("xorshift32-linear16k-v1" if broadband else "multitone-v1")
        assert status["referenceSamples"] == frame_count * 960
        if broadband:
            assert status["baseNoiseSeed"] == 0x91e10da5
            def f32(value):
                return struct.unpack("f", struct.pack("f", value))[0]
            state = 0x91e10da5
            base = []
            for _ in range(160001):
                state ^= (state << 13) & 0xffffffff
                state ^= state >> 17
                state ^= (state << 5) & 0xffffffff
                base.append(((state & 65535) - 32768) / 262144)
            # Independent rational sample mapping, checks every phase and both ends.
            for index, value in enumerate(data[1][::2]):
                lower, phase = divmod(index, 3)
                expected = base[lower] + (base[lower + 1] - base[lower]) * (phase / 3)
                assert abs(value - expected) < 3e-8
            assert all(value == 0 for value in data[0][:1600])
            for index in range(1600, len(data[0])):
                lower, phase = divmod(index - 1600, 2)
                interpolated = f32(base[lower] + f32(base[lower + 1] - base[lower]) * (phase / 2))
                assert abs(data[0][index] - f32(f32(0.6) * interpolated)) < 3e-8
            # Second invocation must recreate the seed and both controls, byte-for-byte.
            repeated = [root / (path.name + "-repeated") for path in paths]
            subprocess.run([binary, library, *map(str, repeated), "--broadband"],
                           capture_output=True, check=True, timeout=30)
            assert [path.read_bytes() for path in paths] == [path.read_bytes() for path in repeated]
            for path in repeated:
                path.unlink()
        else:
            assert status["baseNoiseSeed"] == 0
        baseline = [path.read_bytes() for path in paths]
        assert subprocess.run(command, capture_output=True, timeout=30).returncode != 0
        assert baseline == [path.read_bytes() for path in paths]
        for path in paths:
            path.unlink()
        # Existing second file forces rollback of the first exclusive output.
        paths[1].write_bytes(b"preserve")
        assert subprocess.run(command, capture_output=True, timeout=30).returncode != 0
        assert paths[1].read_bytes() == b"preserve" and not paths[0].exists()
        assert not paths[2].exists() and not paths[3].exists()
        paths[1].unlink()
        for mode in ["factory", "reverse", "forward"]:
            env = {**os.environ, "OPENKRISP_AEC_FIXTURE_FAILURE": mode}
            failure = subprocess.run(command, env=env, capture_output=True, timeout=30)
            assert failure.returncode != 0
            assert b"synthetic AEC initialization failure" in failure.stderr
            assert not any(path.exists() for path in paths)
        paths[1].symlink_to(root / "absent")
        assert subprocess.run(command, capture_output=True, timeout=30).returncode != 0
        assert paths[1].is_symlink() and not paths[0].exists() and not (root / "absent").exists()
        assert subprocess.run([binary], capture_output=True, timeout=30).returncode != 0
        assert subprocess.run([*command[:6], "--unknown"], capture_output=True, timeout=30).returncode != 0
print("AEC direct probe own-fixture output, rollback and foreign-failure tests passed")
