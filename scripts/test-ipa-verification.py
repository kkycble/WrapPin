#!/usr/bin/env python3
"""Test package validation with tiny ZIP fixtures, never with a real installable app."""

import importlib.util
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("ipa_verification", Path(__file__).with_name("verify-ipa.py"))
ipa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ipa)


class IPAVerificationTests(unittest.TestCase):
    def fixture(self, path, *, changes=None, omit=None, extra=None):
        version = ipa.settings()
        info = {
            "CFBundleIdentifier": "com.suversal.wrappin",
            "CFBundleExecutable": "WrapPin",
            "CFBundleShortVersionString": version["MARKETING_VERSION"],
            "CFBundleVersion": version["CURRENT_PROJECT_VERSION"],
            "WrapPinBuildTimestamp": version["WRAPPIN_BUILD_TIMESTAMP"],
            "MinimumOSVersion": "18.0",
            "UIDeviceFamily": [1, 2],
            "UIBackgroundModes": ["location"],
            "LSApplicationQueriesSchemes": ["localdevvpn", "shadowrocket"],
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "DTPlatformName": "iphoneos",
        }
        info.update(changes or {})
        files = {
            "Info.plist": plistlib.dumps(info),
            "WrapPin": b"\xcf\xfa\xed\xfe" + struct.pack("<I", 0x0100000C),
            "en.lproj/Localizable.strings": b'"Done" = "Done";',
        }
        for locale in ["zh-Hans", "zh-Hant"]:
            for table in ipa.localization.TABLES:
                resource = f"{locale}.lproj/{table}"
                source = ipa.localization.parse_strings((ipa.ROOT / "WrapPin/Resources" / resource).read_text())
                files[resource] = plistlib.dumps(source, fmt=plistlib.FMT_BINARY)
        for filename in ["WrapPin-LICENSE.txt", "THIRD_PARTY_NOTICES.txt", "idevice-LICENSE.txt", "PrivacyInfo.xcprivacy"]:
            files[filename] = b"fixture"
        if omit:
            files.pop(omit)
        files.update(extra or {})
        with zipfile.ZipFile(path, "w") as archive:
            for name, data in files.items():
                archive.writestr("Payload/WrapPin.app/" + name, data)

    def test_package_metadata_and_compiled_strings(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.zip"
            self.fixture(path)
            result = ipa.verify(path)
            self.assertEqual(result["bundle_identifier"], "com.suversal.wrappin")
            self.assertEqual(result["localizations"]["zh-Hant.lproj/AppShortcuts.strings"], 4)
            self.assertEqual(len(result["sha256"]), 64)
            self.assertIn("Not tested", result["physical_device_acceptance"])

    def test_invalid_install_targets_and_private_configuration(self):
        for changes in [
            {"CFBundleVersion": "0"}, {"MinimumOSVersion": "27.0"},
            {"CFBundleSupportedPlatforms": ["iPhoneSimulator"]},
            {"LSApplicationQueriesSchemes": ["localdevvpn"]},
            {"UIDeviceFamily": [1]}, {"WrapPinTelemetryAppID": "unexpected-id"},
            {"WrapPinGeoapifyAPIKey": "unexpected-key"},
        ]:
            with self.subTest(changes=changes), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "fixture.zip"
                self.fixture(path, changes=changes)
                with self.assertRaises(ValueError):
                    ipa.verify(path)

    def test_missing_translations_and_tunnel_extension(self):
        for options in [
            {"omit": "zh-Hant.lproj/Localizable.strings"},
            {"extra": {"zh-Hant.lproj/Localizable.strings": plistlib.dumps({"Settings": "wrong"})}},
            {"extra": {"PlugIns/WrapPinTunnel.appex/Info.plist": b"fixture"}},
            {"extra": {"WrapPin": b"simulator or empty executable"}},
        ]:
            with self.subTest(options=options), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "fixture.zip"
                self.fixture(path, **options)
                with self.assertRaises((ValueError, KeyError)):
                    ipa.verify(path)


if __name__ == "__main__":
    unittest.main()
