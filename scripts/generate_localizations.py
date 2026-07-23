#!/usr/bin/env python3
"""Generate Localizable.xcstrings + InfoPlist.xcstrings for Buggy Widget."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = Path(__file__).with_name("localization_strings.json")

LOCALES = [
    "es", "es-MX", "fr", "de", "it", "ja", "ko", "zh-Hans", "zh-Hant",
    "pt-BR", "pt-PT", "ru", "ar", "hi", "nl", "tr", "pl", "sv", "da", "fi",
    "nb", "th", "vi", "id", "uk", "he", "cs", "el", "hu", "ro", "ms", "hr", "sk", "ca",
]


def load_data() -> dict:
    data = json.loads(DATA_PATH.read_text(encoding="utf-8"))
    for en, payload in data.items():
        missing = [loc for loc in LOCALES if loc not in payload["localizations"]]
        if missing:
            raise SystemExit(f"Missing {missing} for {en!r}")
    return data


def build_catalog(data: dict) -> dict:
    strings = {}
    for en, payload in data.items():
        localizations = {
            "en": {"stringUnit": {"state": "translated", "value": en}},
        }
        for loc, value in payload["localizations"].items():
            localizations[loc] = {"stringUnit": {"state": "translated", "value": value}}
        strings[en] = {"comment": payload["comment"], "localizations": localizations}
    return {"sourceLanguage": "en", "version": "1.0", "strings": strings}


def build_info_plist(data: dict, photo: bool) -> dict:
    strings: dict = {
        "CFBundleDisplayName": {
            "comment": "App / extension display name",
            "localizations": {
                "en": {"stringUnit": {"state": "translated", "value": "Buggy Widget"}},
                **{
                    loc: {"stringUnit": {"state": "translated", "value": "Buggy Widget"}}
                    for loc in LOCALES
                },
            },
        }
    }
    if photo:
        photo_en = "Choose a photo to use as your widget background."
        photo_locs = data[photo_en]["localizations"]
        strings["NSPhotoLibraryUsageDescription"] = {
            "comment": "Photo library permission purpose string",
            "localizations": {
                "en": {"stringUnit": {"state": "translated", "value": photo_en}},
                **{
                    loc: {"stringUnit": {"state": "translated", "value": photo_locs[loc]}}
                    for loc in LOCALES
                },
            },
        }
    return {"sourceLanguage": "en", "version": "1.0", "strings": strings}


def update_known_regions() -> None:
    pbx = ROOT / "WidgetMaker.xcodeproj" / "project.pbxproj"
    text = pbx.read_text(encoding="utf-8")
    regions = ["en", "Base", *LOCALES]
    block = "knownRegions = (\n" + "".join(f"\t\t\t\t{r},\n" for r in regions) + "\t\t\t);"
    new_text, n = re.subn(
        r"knownRegions = \(\n(?:\t\t\t\t[^\n]+\n)+?\t\t\t\);",
        block,
        text,
        count=1,
    )
    if n != 1:
        raise SystemExit("Failed to patch knownRegions in project.pbxproj")
    pbx.write_text(new_text, encoding="utf-8")


def main() -> None:
    data = load_data()
    catalog = build_catalog(data)
    (ROOT / "Shared" / "Localizable.xcstrings").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (ROOT / "WidgetMaker" / "InfoPlist.xcstrings").write_text(
        json.dumps(build_info_plist(data, photo=True), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (ROOT / "WidgetMakerExtension" / "InfoPlist.xcstrings").write_text(
        json.dumps(build_info_plist(data, photo=False), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    update_known_regions()
    print(f"Wrote {len(data)} strings × {1 + len(LOCALES)} locales")


if __name__ == "__main__":
    main()
