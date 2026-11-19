#!/usr/bin/env python3
"""Regression tests for the platform-independent localization checker."""

import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "localization", Path(__file__).with_name("check-localization.py")
)
localization = importlib.util.module_from_spec(spec)
spec.loader.exec_module(localization)


class LocalizationTests(unittest.TestCase):
    def test_comments_and_escaped_quotes(self):
        table = localization.parse_strings(
            '/* heading */\n"Hello" = "你好"; // comment\n'
            r'"Quote" = "Say \"hello\"";' + '\n'
        )
        self.assertEqual(table["Hello"], "你好")
        self.assertEqual(table["Quote"], r'Say \"hello\"')

    def test_duplicate_key_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate key"):
            localization.parse_strings('"Done" = "完成";\n"Done" = "完成";')

    def test_missing_semicolon_and_empty_translation_rejected(self):
        for text in ['"Done" = "完成"', '"Done" = "";', '"Done" "完成";', '/* unterminated']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                localization.parse_strings(text)

    def test_printf_reordering_is_allowed(self):
        self.assertEqual(
            localization.format_arguments("Route %lld, %@, %@"),
            localization.format_arguments("%3$@，%2$@，路線 %1$lld"),
        )
        self.assertEqual(
            localization.format_arguments("%lld%% complete"),
            localization.format_arguments("已完成 %lld%%"),
        )
        self.assertEqual(
            localization.format_arguments("%.1f km/h"),
            localization.format_arguments("%.1f 公里／小時"),
        )

    def test_missing_and_wrong_format_types_differ(self):
        signature = localization.format_arguments("Route %lld, %@")
        for translated in ["路線 %lld", "路線 %d，%@", "路線 %@，%lld", "%1$lld，%1$@"]:
            with self.subTest(translated=translated):
                self.assertNotEqual(signature, localization.format_arguments(translated))

    def test_siri_placeholder_extraction(self):
        self.assertEqual(
            localization.intent_key(r"Simulate \(.$place) with \(.applicationName)"),
            "Simulate ${place} with ${applicationName}",
        )

    def test_traditional_tables_are_translated_not_just_declared(self):
        folder = localization.RESOURCES / "zh-Hant.lproj"
        ui = localization.parse_strings((folder / "Localizable.strings").read_text())
        self.assertEqual(ui["Settings"], "設定")
        self.assertEqual(ui["Cycling route"], "單車路線")
        self.assertEqual(ui["Resume Cycling"], "繼續單車模擬")
        # The source still uses these historical Simplified Chinese lookup keys.
        self.assertEqual(ui["地图选点"], "地圖選點")
        permissions = localization.parse_strings((folder / "InfoPlist.strings").read_text())
        self.assertIn("本地網絡", permissions["NSLocalNetworkUsageDescription"])
        phrases = localization.parse_strings((folder / "AppShortcuts.strings").read_text())
        self.assertIn("${applicationName}", phrases["Stop ${applicationName} simulation"])


if __name__ == "__main__":
    unittest.main()
