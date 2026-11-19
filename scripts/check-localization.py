#!/usr/bin/env python3
"""Check Chinese UI coverage, strings syntax, permissions and format arguments.

Runs on any Python 3 host; Xcode/plutil are not needed. Keep complete tables for
both Chinese scripts so zh-Hant never silently falls back to Simplified Chinese.
"""

from __future__ import annotations

import plistlib
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "WrapPin/Resources"
LOCALES = ("zh-Hans", "zh-Hant")
TABLES = ("Localizable.strings", "AppShortcuts.strings", "InfoPlist.strings")
SWIFT_ROOT = ROOT / "WrapPin"
NATIVE_ROOT = ROOT / "Native/WrapPinPairingFFI"

# Tokenize rather than just matching keys: a missing semicolon, unescaped quote
# or duplicate must fail before a broken table can make it into an IPA.
STRINGS_TOKEN = re.compile(
    r'\s+|//[^\n]*|/\*.*?\*/|'
    r'"(?P<key>(?:\\.|[^"\\])*)"\s*=\s*"(?P<value>(?:\\.|[^"\\])*)"\s*;',
    re.DOTALL,
)
LOCALIZED_CALLS = re.compile(
    r'(?:String\(localized:|NSLocalizedString\(|Text\(|Label\(|Button\(|Toggle\('
    r'|Section\(|LabeledContent\(|Picker\(|\.navigationTitle\(|\.alert\('
    r'|\.confirmationDialog\(|\.accessibilityLabel\(|\.accessibilityHint\('
    # App Intents metadata, dialogs and errors shown by Shortcuts and Siri.
    r'|LocalizedStringResource\(|LocalizedStringResource\s*=|IntentDescription\('
    r'|TypeDisplayRepresentation\(name:|@Parameter\(title:|shortTitle:|settingsRowLabel\('
    # Localized copy passed through the app's small view helpers.
    r'|guideRow\(|privacyRow\(|stepRow\(\s*\d+,|\bmessage:|\btext:)'
    r'\s*"((?:\\.|[^"\\])*)"'
)
PARAMETER_SUMMARIES = re.compile(r'Summary\(\s*"((?:\\.|[^"\\])*)"')
SHORTCUT_PHRASES = re.compile(r'"([^"\n]*\\\(\.applicationName\)[^"\n]*)"')
INTENT_PLACEHOLDER = re.compile(r'\\\(\\?\.\$?(\w+)\)')
NAMED_PLACEHOLDER = re.compile(r'\$\{\w+\}')
PRINTF_ARGUMENT = re.compile(
    r'%(?:%|(?:(?P<position>\d+)\$)?[-+ #0\']*(?:\d+)?(?:\.\d+)?'
    r'(?P<type>(?:hh|ll|[hljztL])?[@diuoxXfFeEgGaAcCsSpn]))'
)
NATIVE_MESSAGES = re.compile(
    r'"([^"\n]+)"\.to_string\(\)'
    r'|\bErr\(\s*"([^"\n]+)"\s*\)'
    r'|LocationError::(?:new|recoverable)\(\s*[\w:]+,\s*"([^"\n]+)"'
)


def parse_strings(text: str) -> dict[str, str]:
    """Read a strings table, rejecting malformed and duplicate entries."""
    entries: dict[str, str] = {}
    offset = 0
    while offset < len(text):
        match = STRINGS_TOKEN.match(text, offset)
        line = text.count("\n", 0, offset) + 1
        if match is None:
            raise ValueError(f"line {line}: malformed strings entry")
        if (key := match.group("key")) is not None:
            if key in entries:
                raise ValueError(f"line {line}: duplicate key {key!r}")
            if not (value := match.group("value")):
                raise ValueError(f"line {line}: empty translation for {key!r}")
            entries[key] = value
        offset = match.end()
    return entries


def format_arguments(text: str) -> Counter[tuple[int, str]]:
    """Compare argument indices/types while allowing positional reordering."""
    result: Counter[tuple[int, str]] = Counter()
    next_position = 1
    for match in PRINTF_ARGUMENT.finditer(text):
        if match.group("type") is None:  # A literal %% consumes no argument.
            continue
        position = int(match.group("position") or next_position)
        result[(position, match.group("type"))] += 1
        next_position += 1
    return result


def intent_key(literal: str) -> str:
    return INTENT_PLACEHOLDER.sub(lambda match: "${" + match.group(1) + "}", literal)


def find_required_phrases() -> dict[str, set[str]]:
    phrases: dict[str, set[str]] = {}
    for path in sorted(SWIFT_ROOT.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in SHORTCUT_PHRASES.finditer(text):
            phrases.setdefault(intent_key(match.group(1)), set()).add(str(path.relative_to(ROOT)))
    return phrases


def find_required_keys() -> dict[str, set[str]]:
    required: dict[str, set[str]] = {}
    for path in sorted(SWIFT_ROOT.rglob("*.swift")):
        text = path.read_text(encoding="utf-8")
        for match in LOCALIZED_CALLS.finditer(text):
            key = match.group(1)
            if "\\(" in key:
                continue
            required.setdefault(key, set()).add(str(path.relative_to(ROOT)))
        for match in PARAMETER_SUMMARIES.finditer(text):
            required.setdefault(intent_key(match.group(1)), set()).add(str(path.relative_to(ROOT)))

    for path in sorted(NATIVE_ROOT.rglob("*.rs")):
        text = path.read_text(encoding="utf-8").split("#[cfg(test)]")[0]
        for match in NATIVE_MESSAGES.finditer(text):
            key = next(group for group in match.groups() if group)
            required.setdefault(key, set()).add(str(path.relative_to(ROOT)))
    return required


def main() -> int:
    required = find_required_keys()
    phrases = find_required_phrases()
    with (ROOT / "Configuration/WrapPin-Info.plist").open("rb") as file:
        info = plistlib.load(file)
    permission_keys = {key for key in info if key.startswith("NS") and key.endswith("UsageDescription")}
    required_tables = {
        "Localizable.strings": set(required),
        "AppShortcuts.strings": set(phrases),
        "InfoPlist.strings": permission_keys,
    }
    errors: list[str] = []
    tables: dict[tuple[str, str], dict[str, str]] = {}
    for locale in LOCALES:
        for name in TABLES:
            path = RESOURCES / f"{locale}.lproj" / name
            try:
                entries = parse_strings(path.read_text(encoding="utf-8"))
            except (OSError, ValueError) as error:
                errors.append(f"{locale}/{name}: {error}")
                continue
            tables[(locale, name)] = entries
            for key in sorted(required_tables[name] - entries.keys()):
                errors.append(f"{locale}/{name}: missing {key!r}")
            for key, value in entries.items():
                if format_arguments(key) != format_arguments(value):
                    errors.append(f"{locale}/{name}: format arguments differ for {key!r}")
                if Counter(NAMED_PLACEHOLDER.findall(key)) != Counter(NAMED_PLACEHOLDER.findall(value)):
                    errors.append(f"{locale}/{name}: named placeholders differ for {key!r}")

    # Cover legacy and dynamically selected keys too, not just literals the
    # source scanner can recognize. All translated tables must have key parity.
    for name in TABLES:
        reference = set(tables.get((LOCALES[0], name), {}))
        for locale in LOCALES[1:]:
            keys = set(tables.get((locale, name), {}))
            for key in sorted(reference - keys):
                errors.append(f"{locale}/{name}: missing reference key {key!r}")
            for key in sorted(keys - reference):
                errors.append(f"{LOCALES[0]}/{name}: missing reference key {key!r}")

    project = (ROOT / "WrapPin.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    for locale in LOCALES:
        if f'"{locale}"' not in project:
            errors.append(f"Xcode project does not declare {locale} in knownRegions")

    if errors:
        print("Localization check failed:")
        for error in errors:
            print(f"  {error}")
        return 1
    count = len(tables[(LOCALES[0], "Localizable.strings")])
    print(
        f"Localization check passed: {', '.join(LOCALES)} each have {count} keys covering "
        f"{len(required)} literal UI keys, {len(phrases)} App Shortcuts phrases and "
        f"{len(permission_keys)} permission descriptions; formats and table parity verified."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
