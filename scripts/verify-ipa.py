#!/usr/bin/env python3
"""Validate a Standard/SideStore IPA and optionally write its build receipt.

Works on Linux too, so a downloaded artifact can be checked independently of
Xcode. This verifies package contents, not the eventual SideStore signature or
a physical device's ability to pair or run a simulation.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import struct
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("localization", ROOT / "scripts/check-localization.py")
localization = importlib.util.module_from_spec(spec)
spec.loader.exec_module(localization)


def settings() -> dict[str, str]:
    return {
        key.strip(): value.strip()
        for line in (ROOT / "Configuration/Version.xcconfig").read_text().splitlines()
        if "=" in line and not line.lstrip().startswith("//")
        for key, value in [line.split("=", 1)]
    }


def strings_table(data: bytes) -> dict[str, str]:
    try:
        return plistlib.loads(data)
    except plistlib.InvalidFileException:
        encoding = "utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig"
        return localization.parse_strings(data.decode(encoding))


def verify(path: Path) -> dict:
    version = settings()
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("IPA ZIP integrity check failed")
        names = archive.namelist()
        if any(name.startswith("/") or ".." in Path(name).parts for name in names):
            raise ValueError("IPA contains an unsafe ZIP path")
        apps = {name.split("/")[1] for name in names if name.startswith("Payload/") and "/" in name[8:]}
        if apps != {"WrapPin.app"}:
            raise ValueError(f"Expected only Payload/WrapPin.app, found {sorted(apps)}")
        prefix = "Payload/WrapPin.app/"
        info = plistlib.loads(archive.read(prefix + "Info.plist"))
        expected = {
            "CFBundleShortVersionString": version["MARKETING_VERSION"],
            "CFBundleVersion": version["CURRENT_PROJECT_VERSION"],
            "MinimumOSVersion": "18.0",
            "WrapPinBuildTimestamp": version["WRAPPIN_BUILD_TIMESTAMP"],
        }
        for key, value in expected.items():
            if info.get(key) != value:
                raise ValueError(f"{key}: expected {value!r}, got {info.get(key)!r}")
        if info.get("UIDeviceFamily") != [1, 2]:
            raise ValueError("The IPA must support both iPhone and iPad")
        if info.get("UIBackgroundModes") != ["location"]:
            raise ValueError("Background location keep-alive is missing")
        if "shadowrocket" not in info.get("LSApplicationQueriesSchemes", []):
            raise ValueError("Shadowrocket URL handoff is missing")
        if any("/PlugIns/" in name or name.endswith(".appex/") for name in names):
            raise ValueError("A SideStore Standard IPA must not embed a tunnel/app extension")
        # Reject a simulator .app renamed to .ipa (arm64 CPU alone isn't enough).
        if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"] or info.get("DTPlatformName") != "iphoneos":
            raise ValueError("The archive must be built for a physical iOS device, not the simulator")
        executable = info.get("CFBundleExecutable", "")
        if not executable or Path(executable).name != executable:
            raise ValueError("Invalid app executable name")
        binary = archive.read(prefix + executable)
        if len(binary) < 8 or binary[:4] != b"\xcf\xfa\xed\xfe" or struct.unpack_from("<I", binary, 4)[0] != 0x0100000C:
            raise ValueError("App executable is not a 64-bit arm64 Mach-O binary")
        counts = {}
        for locale in ["zh-Hans", "zh-Hant"]:
            for table in localization.TABLES:
                resource = f"{locale}.lproj/{table}"
                packaged = strings_table(archive.read(prefix + resource))
                source = localization.parse_strings((ROOT / "WrapPin/Resources" / resource).read_text())
                for key, value in source.items():
                    if packaged.get(key) != value:
                        raise ValueError(f"Packaged {resource} is missing or changed at {key!r}")
                counts[resource] = len(packaged)
        if prefix + "en.lproj/Localizable.strings" not in names:
            raise ValueError("English fallback localization is missing")
        for filename in ["WrapPin-LICENSE.txt", "THIRD_PARTY_NOTICES.txt", "idevice-LICENSE.txt", "PrivacyInfo.xcprivacy"]:
            if not any(name.startswith(prefix) and name.endswith("/" + filename) for name in names):
                raise ValueError(f"Required resource is missing: {filename}")
        # This personal fork intentionally leaves analytics and overseas keys unset.
        for key in ["WrapPinTelemetryAppID", "WrapPinTelemetryNamespace", "WrapPinGeoapifyAPIKey"]:
            if info.get(key, ""):
                raise ValueError(f"Personal SideStore build unexpectedly includes {key}")

    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return {
        "filename": path.name,
        "sha256": digest.hexdigest(),
        "size_bytes": path.stat().st_size,
        "version": info["CFBundleShortVersionString"],
        "build": info["CFBundleVersion"],
        "build_timestamp": info["WrapPinBuildTimestamp"],
        "bundle_identifier": info["CFBundleIdentifier"],
        "minimum_os": info["MinimumOSVersion"],
        "architecture": "arm64 (iPhoneOS)",
        "localizations": counts,
        "signing_method": "Unsigned Release archive; SideStore signs on installation",
        "physical_device_acceptance": "Not tested; pairing, Shadowrocket, cycling coverage, background use and SideStore installation need a physical device",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--receipt", type=Path)
    args = parser.parse_args()
    try:
        receipt = verify(args.ipa)
        receipt["source_commit"] = os.environ.get("GITHUB_SHA") or subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip()
        receipt["source_branch"] = os.environ.get("GITHUB_REF_NAME") or subprocess.check_output(
            ["git", "branch", "--show-current"], cwd=ROOT, text=True
        ).strip()
        if os.environ.get("GITHUB_RUN_ID"):
            receipt["build_run"] = f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"
        if sys.platform == "darwin":
            receipt["xcode"] = subprocess.check_output(["xcodebuild", "-version"], text=True).strip()
        if args.receipt:
            args.receipt.parent.mkdir(parents=True, exist_ok=True)
            args.receipt.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps(receipt, ensure_ascii=False, indent=2))
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, plistlib.InvalidFileException) as error:
        print(f"IPA verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
