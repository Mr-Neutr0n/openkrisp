#!/usr/bin/env python3
"""Exercise only an own synthetic dylib through the standalone probe."""
import array
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile

binary, library = map(str, map(Path, sys.argv[1:]))
with tempfile.TemporaryDirectory(prefix="openkrisp-aec-direct-") as work:
    root = Path(work)
    paths = [root / name for name in ["forward", "reference", "on", "zero"]]
    command = [binary, library, *map(str, paths)]
    result = subprocess.run(command, capture_output=True, text=True, timeout=30, check=True)
    status = json.loads(result.stdout)
    assert status["framesPerEngine"] == 300 and status["successfulCallsPerEngine"] == 600
    assert status["samplesPerOutput"] == 96000 and status["teardownComplete"] is True
    assert status["delaySetterCalled"] is False
    data = []
    for path, length in zip(paths, [96000, 288000, 96000, 96000]):
        values = array.array("f", path.read_bytes())
        assert len(values) == length and all(map(math.isfinite, values))
        assert path.stat().st_mode & 0o777 == 0o600
        data.append(values)
    assert data[1][::2] == data[1][1::2]
    assert data[3] == data[0]  # Own fixture subtracts zero reference exactly.
    assert data[2] != data[3]
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
print("AEC direct probe own-fixture output, rollback and foreign-failure tests passed")
