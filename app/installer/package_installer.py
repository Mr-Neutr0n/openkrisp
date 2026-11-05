"""Combined app/driver package construction with no system installation effects."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import struct
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
PRODUCT = ROOT.parent.parent
APP_REL = Path("Applications/Lab Voice.app")
DRIVER_REL = Path("Library/Audio/Plug-Ins/HAL/LabVoiceAudio.driver")
APP_ID = "dev.labvoice.desktop"
DRIVER_ID = "dev.hari.labvoice.audio"
PACKAGE_ID = "dev.hari.openkrisp.development"


def run(*args, **kwargs):
    return subprocess.run(list(map(str, args)), check=True, **kwargs)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def files_for(directory):
    directory = Path(directory)
    if directory.is_symlink() or not directory.is_dir():
        raise RuntimeError("Expected a plain bundle directory")
    result = {}
    for path in sorted(directory.rglob("*")):
        if path.is_symlink():
            raise RuntimeError("Bundle contains a symbolic link: " + str(path))
        if path.is_file():
            relative = path.relative_to(directory).as_posix()
            if any(ord(character) < 32 for character in relative):
                raise RuntimeError("Unsupported control character in payload path")
            result[relative] = digest(path)
        elif not path.is_dir():
            raise RuntimeError("Bundle contains a special file")
    return result


def tree_hash(files):
    return hashlib.sha256(json.dumps(files, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def inspect_bundle(bundle, identifier, executable):
    files = files_for(bundle)
    with (bundle / "Contents/Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    if info.get("CFBundleIdentifier") != identifier or info.get("CFBundleExecutable") != executable:
        raise RuntimeError("Unexpected bundle identity")
    if identifier == APP_ID:
        if info.get("LSMinimumSystemVersion") != "13.5":
            raise RuntimeError("Bundled Node distribution must declare macOS 13.5")
        notice = bundle / "Contents/Resources/helper/notices/RNNoise-COPYING"
        if not notice.is_file() or notice.read_bytes() != (PRODUCT / "app/noise-engine/vendor/rnnoise/COPYING").read_bytes():
            raise RuntimeError("RNNoise distribution notice is missing or changed")
        run("python3", PRODUCT / "app/node-runtime/verify", "--runtime", bundle / "Contents/Resources/helper/node-runtime")
    run("codesign", "--verify", "--deep", "--strict", bundle)
    signature = subprocess.run(["codesign", "--display", "--verbose=4", str(bundle)],
                               capture_output=True, text=True, check=True)
    if "Signature=adhoc" not in signature.stdout + signature.stderr:
        raise RuntimeError("This development builder expects an ad-hoc signed bundle")
    for relative in files:
        path = bundle / relative
        if path.suffix.lower() in {".kef", ".asar", ".dylib", ".wav", ".aiff", ".mp3", ".m4a"} or path.name == "kr-media-sp.node":
            raise RuntimeError("Excluded vendor/runtime/audio artifact: " + relative)
        with path.open("rb") as handle:
            magic = handle.read(4)
        if magic not in {b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xca\xfe\xba\xbe"}:
            continue
        architecture = subprocess.check_output(["lipo", "-archs", str(path)], text=True).strip()
        if architecture != "arm64":
            raise RuntimeError("Payload executable is not ARM64: " + relative)
        commands = subprocess.check_output(["otool", "-l", str(path)], text=True)
        versions = re.findall(r"^\s*minos\s+(\d+)\.(\d+)", commands, re.M)
        maximum = (13, 5) if identifier == APP_ID else (12, 0)
        if not versions or any(tuple(map(int, version)) > maximum for version in versions):
            raise RuntimeError("Payload executable exceeds the declared deployment target: " + relative)
    return files, info


def build_driver(destination, build):
    source = PRODUCT / "app/audio-driver"
    names = ["driver.cpp", "test.cpp", "Info.plist"]
    before = {name: digest(source / name) for name in names}
    macos = destination / "Contents/MacOS"
    macos.mkdir(parents=True)
    shutil.copy2(source / "Info.plist", destination / "Contents/Info.plist")
    common = ["clang++", "-mmacosx-version-min=12.0", "-std=c++20", "-Wall", "-Wextra", "-Werror"]
    frameworks = ["-framework", "CoreAudio", "-framework", "CoreFoundation"]
    # This isolated production build never defines the discovery or test-hook flags.
    run(*common, "-bundle", source / "driver.cpp", *frameworks, "-o", macos / "LabVoiceAudio")
    host = build / "driver-host-test"
    run(*common, source / "test.cpp", *frameworks, "-o", host)
    run(host, macos / "LabVoiceAudio")
    hooks = build / "driver-test-hooks.bundle"
    run(*common, "-DLABVOICE_DRIVER_TEST_HOOKS", "-bundle", source / "driver.cpp", *frameworks, "-o", hooks)
    run(host, hooks)
    after = {name: digest(source / name) for name in names}
    if before != after:
        raise RuntimeError("Driver source changed while constructing the package")
    run("xattr", "-cr", destination)
    run("codesign", "--force", "--sign", "-", "--identifier", DRIVER_ID, destination)
    return before


def validate_appledouble(data):
    if not 26 <= len(data) <= 1048576:
        raise RuntimeError("Invalid AppleDouble length")
    magic, version = struct.unpack_from(">II", data)
    count = struct.unpack_from(">H", data, 24)[0]
    end = 26 + count * 12
    if magic != 0x00051607 or version != 0x00020000 or not 1 <= count <= 64 or end > len(data):
        raise RuntimeError("Invalid AppleDouble header")
    spans = []
    for index in range(count):
        _, offset, length = struct.unpack_from(">III", data, 26 + index * 12)
        if offset < end or offset + length > len(data):
            raise RuntimeError("Invalid AppleDouble entry bounds")
        if length:
            spans.append((offset, offset + length))
    spans.sort()
    if any(first[1] > second[0] for first, second in zip(spans, spans[1:])):
        raise RuntimeError("Overlapping AppleDouble entries")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, default=PRODUCT / "app/desktop/.build/app/Lab Voice.app")
    parser.add_argument("--version", default="0.1.0")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+(?:\.\d+){0,2}", args.version):
        parser.error("version must contain one to three numeric components")
    app = args.app.absolute()
    original, _ = inspect_bundle(app, APP_ID, "LabVoice")
    output = ROOT / "build"
    output.mkdir(exist_ok=True)
    preinstall = (ROOT / "preinstall.sh").read_text()
    run("sh", "-n", ROOT / "preinstall.sh")
    with tempfile.TemporaryDirectory(prefix="openkrisp-installer-") as temporary:
        stage = Path(temporary)
        payload = stage / "payload"
        staged_app, driver = payload / APP_REL, payload / DRIVER_REL
        staged_app.parent.mkdir(parents=True)
        driver.parent.mkdir(parents=True)
        shutil.copytree(app, staged_app)
        if files_for(staged_app) != original or files_for(app) != original:
            raise RuntimeError("App changed while copying the installer input")
        driver_source = build_driver(driver, stage)
        app_files, _ = inspect_bundle(staged_app, APP_ID, "LabVoice")
        driver_files, _ = inspect_bundle(driver, DRIVER_ID, "LabVoiceAudio")
        scripts = stage / "scripts"
        scripts.mkdir()
        (scripts / "preinstall").write_text(preinstall)
        (scripts / "preinstall").chmod(0o755)
        components = stage / "components.plist"
        with components.open("wb") as handle:
            plistlib.dump([{"RootRelativeBundlePath": path.as_posix(), "BundleIsRelocatable": False,
                           "BundleIsVersionChecked": False, "BundleHasStrictIdentifier": True,
                           "BundleOverwriteAction": "upgrade"} for path in [APP_REL, DRIVER_REL]], handle)
        package = stage / "OpenKrisp-development.pkg"
        run("pkgbuild", "--root", payload, "--component-plist", components, "--scripts", scripts,
            "--install-location", "/", "--identifier", PACKAGE_ID, "--version", args.version,
            "--ownership", "recommended", package)
        expected = {path.relative_to(payload).as_posix() for path in payload.rglob("*")}
        expected.add(".")
        entries = subprocess.check_output(["pkgutil", "--payload-files", str(package)], text=True).splitlines()
        plain, metadata = set(), set()
        for entry in entries:
            entry = entry.removeprefix("./").rstrip("/") or "."
            path = PurePosixPath(entry)
            if path.name.startswith("._"):
                if str(path.with_name(path.name[2:])) not in expected:
                    raise RuntimeError("AppleDouble member outside payload whitelist")
                metadata.add(entry)
            else:
                plain.add(entry)
        if plain != expected:
            raise RuntimeError("Installer payload paths differ from staging")
        flat = stage / "flat"
        run("pkgutil", "--expand", package, flat)
        metadata_hashes = {}
        for entry in sorted(metadata):
            raw = subprocess.check_output(["tar", "--no-mac-metadata", "-xOf", str(flat / "Payload"), "./" + entry])
            validate_appledouble(raw)
            metadata_hashes[entry] = hashlib.sha256(raw).hexdigest()
        expanded = stage / "expanded"
        run("pkgutil", "--expand-full", package, expanded)
        if files_for(expanded / "Payload" / APP_REL) != app_files or files_for(expanded / "Payload" / DRIVER_REL) != driver_files:
            raise RuntimeError("Expanded bundles differ from the signed staged inputs")
        inspect_bundle(expanded / "Payload" / APP_REL, APP_ID, "LabVoice")
        inspect_bundle(expanded / "Payload" / DRIVER_REL, DRIVER_ID, "LabVoiceAudio")
        info = ET.parse(expanded / "PackageInfo").getroot()
        if info.attrib.get("identifier") != PACKAGE_ID or info.attrib.get("install-location") != "/" or info.attrib.get("relocatable") != "false":
            raise RuntimeError("Incorrect package identifier, location or relocation policy")
        records = {item.attrib.get("path", "").removeprefix("./"): item.attrib.get("id") for item in info.findall("bundle")}
        if records != {APP_REL.as_posix(): APP_ID, DRIVER_REL.as_posix(): DRIVER_ID} or len(info.find("relocate")):
            raise RuntimeError("Incorrect bundled identities or relocation entries")
        extracted = expanded / "Scripts"
        if sorted(path.name for path in extracted.iterdir()) != ["preinstall"] or (extracted / "preinstall").read_text() != preinstall:
            raise RuntimeError("Installer scripts differ from the reviewed preinstall")
        signature = subprocess.run(["pkgutil", "--check-signature", str(package)], capture_output=True, text=True)
        if "no signature" not in (signature.stdout + signature.stderr).lower():
            raise RuntimeError("Development package must remain unsigned")
        destination = output / package.name
        shutil.copy2(package, destination)
        signed = output / "signed-inputs"
        if signed.exists():
            shutil.rmtree(signed)
        signed.mkdir()
        shutil.copytree(expanded / "Payload" / APP_REL, signed / APP_REL.name)
        shutil.copytree(expanded / "Payload" / DRIVER_REL, signed / DRIVER_REL.name)
        manifest = {"schemaVersion": 1, "packageIdentifier": PACKAGE_ID, "version": args.version,
                    "packageSHA256": digest(destination), "installPaths": ["/" + path.as_posix() for path in [APP_REL, DRIVER_REL]],
                    "appTreeSHA256": tree_hash(app_files), "driverTreeSHA256": tree_hash(driver_files),
                    "appFiles": app_files, "driverFiles": driver_files, "driverSourceSHA256": driver_source,
                    "preinstallSHA256": hashlib.sha256(preinstall.encode()).hexdigest(),
                    "payloadPaths": sorted(expected), "archiveMetadataAppleDouble": metadata_hashes,
                    "minimumMacOS": "13.5", "architecture": "arm64", "driverDiscoveryTrace": False,
                    "nodeRuntimeSHA256": "533bd644c5ae0e0ea3a80e433aad16b817447ccba1e1eea701875eac80cb75d4",
                    "signature": "ad-hoc app/driver, original Developer ID Node runtime, unsigned package; not notarized", "existingTargets": "refused, including identical bundles",
                    "automaticActions": [], "verification": ["driver host tests and test-hook variant", "signed input snapshot equality",
                    "ARM64/macOS13.5 app and macOS12 driver executable metadata", "exact payload whitelist and AppleDouble bounds", "expanded bundle hashes and signatures",
                    "bundle identifiers, RNNoise and complete Node notices, pinned Node provenance/signature and fixed install locations", "relocation disabled", "single reviewed preinstall, no postinstall", "unsigned package"]}
        (output / "package-manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        (output / "preinstall-review.txt").write_text(preinstall)
        print("Package:", destination)
        print("Package SHA256:", manifest["packageSHA256"])
        print("App tree SHA256:", manifest["appTreeSHA256"])
        print("Driver tree SHA256:", manifest["driverTreeSHA256"])
        print("No installation, administrator request, CoreAudio restart, app launch, model load or capture performed.")
