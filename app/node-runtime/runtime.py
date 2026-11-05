"""Prepare and inspect the pinned official Node runtime without executing it."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build"
PROVENANCE = (ROOT / "upstream.json").read_bytes()
UPSTREAM = json.loads(PROVENANCE)
RUNTIME_FILES = {"node", "LICENSE", "provenance.json"}
SYSTEM_LIBRARIES = {
    "/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation",
    "/System/Library/Frameworks/Security.framework/Versions/A/Security",
    "/usr/lib/libc++.1.dylib", "/usr/lib/libSystem.B.dylib",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def regular(path):
    return stat.S_ISREG(path.lstat().st_mode)


def verify_runtime(directory):
    """Check a staged or relocated runtime. Never execute Node or fetch files."""
    directory = Path(directory)
    if directory.is_symlink() or not directory.is_dir() or {p.name for p in directory.iterdir()} != RUNTIME_FILES:
        raise RuntimeError("Expected exactly node, LICENSE and provenance.json in a plain runtime directory")
    if any(not regular(path) for path in directory.iterdir()):
        raise RuntimeError("Node runtime resources must be regular files without symlinks")
    if (directory / "provenance.json").read_bytes() != PROVENANCE:
        raise RuntimeError("Node runtime provenance differs from the pinned upstream record")
    for name, identity in UPSTREAM["files"].items():
        path = directory / name
        if path.stat().st_size != identity["bytes"] or digest(path.read_bytes()) != identity["sha256"]:
            raise RuntimeError("Node runtime file changed: " + name)
    node = directory / "node"
    if not node.stat().st_mode & 0o111:
        raise RuntimeError("Node runtime is not executable")
    if subprocess.check_output(["lipo", "-archs", str(node)], text=True).strip() != "arm64":
        raise RuntimeError("Node runtime must be ARM64")
    commands = subprocess.check_output(["otool", "-l", str(node)], text=True)
    if re.findall(r"^\s*minos\s+(\S+)", commands, re.M) != ["13.5"]:
        raise RuntimeError("Node runtime must retain its macOS 13.5 deployment target")
    libraries = subprocess.check_output(["otool", "-L", str(node)], text=True).splitlines()[1:]
    if {line.strip().split(" (", 1)[0] for line in libraries} != SYSTEM_LIBRARIES:
        raise RuntimeError("Node runtime has an unexpected dynamic dependency")
    subprocess.run(["codesign", "--verify", "--strict", str(node)], check=True)
    signature = subprocess.run(["codesign", "--display", "--verbose=4", str(node)], capture_output=True, text=True, check=True)
    fields = set((signature.stdout + signature.stderr).splitlines())
    if not {"Identifier=node", "TeamIdentifier=HX7739G8FX", "Authority=Developer ID Application: Node.js Foundation (HX7739G8FX)"} <= fields:
        raise RuntimeError("Node runtime did not retain the reviewed upstream signature")
    return UPSTREAM


def fetch(record, destination, limit):
    """Cache only exact pinned bytes. Reject unexpected existing entries."""
    if destination.exists() or destination.is_symlink():
        if not regular(destination) or destination.stat().st_size > limit or digest(destination.read_bytes()) != record["sha256"]:
            raise RuntimeError("Cached upstream file is invalid; review and remove it before retrying: " + str(destination))
        return
    request = urllib.request.Request(record["url"], headers={"User-Agent": "openkrisp-runtime-builder/1"})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read(limit + 1)
    if len(data) > limit or digest(data) != record["sha256"] or ("bytes" in record and len(data) != record["bytes"]):
        raise RuntimeError("Pinned upstream download failed byte validation: " + record["url"])
    destination.write_bytes(data)


def verify_signed_checksums(cache):
    gpgv = shutil.which("gpgv")
    if not gpgv:
        raise RuntimeError("Build-time gpgv is required to verify official Node release checksums")
    with tempfile.TemporaryDirectory(prefix="openkrisp-node-gpgv-") as home:
        result = subprocess.run([gpgv, "--homedir", home, "--keyring", str(cache / "release-keyring.kbx"),
                                 "--status-fd", "1", str(cache / "SHASUMS256.txt.asc")], capture_output=True, text=True)
    (cache / "signature-verification.txt").write_text(result.stdout + result.stderr)
    result.check_returncode()
    signatures = [line.split()[2] for line in result.stdout.splitlines() if line.startswith("[GNUPG:] VALIDSIG ")]
    if signatures != [UPSTREAM["signedChecksums"]["signerFingerprint"]]:
        raise RuntimeError("Node checksum signature did not match the pinned release signer")
    lines = (cache / "SHASUMS256.txt.asc").read_text().splitlines()
    if lines[0] != "-----BEGIN PGP SIGNED MESSAGE-----":
        raise RuntimeError("Expected a clear-signed Node checksum manifest")
    start = lines.index("") + 1
    end = lines.index("-----BEGIN PGP SIGNATURE-----", start)
    records = [line.removeprefix("- ").split() for line in lines[start:end] if line]
    name = UPSTREAM["archive"]["url"].rsplit("/", 1)[1]
    hashes = [record[0] for record in records if len(record) == 2 and record[1] == name]
    if hashes != [UPSTREAM["archive"]["sha256"]]:
        raise RuntimeError("Verified Node manifest does not contain the pinned archive checksum")


def prepare():
    BUILD.mkdir(exist_ok=True)
    if BUILD.is_symlink():
        raise RuntimeError("Runtime build directory must not be a symlink")
    cache = BUILD / "downloads"
    cache.mkdir(exist_ok=True)
    if cache.is_symlink():
        raise RuntimeError("Runtime download cache must not be a symlink")
    fetch(UPSTREAM["releaseKeyring"], cache / "release-keyring.kbx", 2_000_000)
    fetch(UPSTREAM["signedChecksums"], cache / "SHASUMS256.txt.asc", 2_000_000)
    verify_signed_checksums(cache)
    archive = cache / UPSTREAM["archive"]["url"].rsplit("/", 1)[1]
    # No archive download occurs before signature and checksum admission.
    fetch(UPSTREAM["archive"], archive, 100_000_000)
    with tempfile.TemporaryDirectory(prefix="openkrisp-node-stage-", dir=BUILD) as temporary:
        stage = Path(temporary) / "runtime"
        stage.mkdir()
        with tarfile.open(archive, "r:xz") as package:
            for name, member_name in [("node", "bin/node"), ("LICENSE", "LICENSE")]:
                member_path = UPSTREAM["archive"]["root"] + "/" + member_name
                members = [member for member in package.getmembers() if member.name == member_path]
                if len(members) != 1 or not members[0].isfile() or members[0].size != UPSTREAM["files"][name]["bytes"]:
                    raise RuntimeError("Unexpected Node archive member: " + member_path)
                with package.extractfile(members[0]) as content:
                    data = content.read(UPSTREAM["files"][name]["bytes"] + 1)
                if digest(data) != UPSTREAM["files"][name]["sha256"]:
                    raise RuntimeError("Node archive member failed digest validation")
                (stage / name).write_bytes(data)
                (stage / name).chmod(0o755 if name == "node" else 0o644)
        (stage / "provenance.json").write_bytes(PROVENANCE)
        verify_runtime(stage)
        destination = BUILD / "runtime"
        if destination.exists() or destination.is_symlink():
            verify_runtime(destination)
        else:
            os.rename(stage, destination)
    return BUILD / "runtime"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, help="Inspect an existing resource directory without downloading or executing")
    args = parser.parse_args()
    directory = args.runtime if args.runtime is not None else prepare()
    verify_runtime(directory)
    print("Verified official Node " + UPSTREAM["version"] + ": " + str(directory))
    print("No runtime execution, global install, npm, addon/model load or signature mutation performed.")
