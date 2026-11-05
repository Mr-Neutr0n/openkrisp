#!/usr/bin/env python3
"""Exercise only private fixture paths with the production shell guard."""
from pathlib import Path
import hashlib
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
source = (ROOT / "preinstall.sh").read_text()
with tempfile.TemporaryDirectory(prefix="openkrisp-installer-guard-") as temporary:
    root = Path(temporary).resolve()
    app = root / "Applications/Lab Voice.app"
    driver = root / "Library/Audio/Plug-Ins/HAL/LabVoiceAudio.driver"
    text = source.replace("/Applications/Lab Voice.app", str(app)).replace(
        "/Library/Audio/Plug-Ins/HAL/LabVoiceAudio.driver", str(driver))
    assert text.count(str(app)) == text.count(str(driver)) == 1
    script = root / "preinstall"
    script.write_text(text)
    script.chmod(0o755)
    def result(volume="/"):
        return subprocess.run([str(script), "fixture", "fixture", volume], capture_output=True, text=True)
    assert result().returncode == 0
    assert result("/Volumes/Other").returncode == 1
    checks = 2
    for target in [app, driver]:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("retained content")
        before = hashlib.sha256(target.read_bytes()).hexdigest()
        assert result().returncode == 1 and hashlib.sha256(target.read_bytes()).hexdigest() == before
        target.unlink(); checks += 1
        target.mkdir()
        sentinel = target / "keep"
        sentinel.write_text("retained directory")
        assert result().returncode == 1 and sentinel.read_text() == "retained directory"
        sentinel.unlink(); target.rmdir(); checks += 1
        target.symlink_to(root / "missing-target")
        assert result().returncode == 1 and target.is_symlink()
        target.unlink(); checks += 1
    app.parent.rmdir()
    alias = root / "app-parent"
    alias.mkdir()
    app.parent.symlink_to(alias, target_is_directory=True)
    assert result().returncode == 1 and app.parent.is_symlink()
    checks += 1
    app.parent.unlink()
    assert result().returncode == 0
    checks += 1
print(f"Installer guard passed {checks} private-path checks. No system target was accessed or changed.")
