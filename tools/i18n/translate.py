#!/usr/bin/env python3
"""Translate Treewise's String Catalogs into Dutch and German (ADR 0017).

The translation workflow, for every catalog in the repository:

  translate.py sync     add the English keys the last build extracted
                        (needs a build: tools/build.sh build)
  translate.py status   show, per catalog, how many keys miss nl or de
  translate.py export   write the missing keys with comments and the glossary
                        to tools/i18n/_translation_input.json
  (translate the JSON in a chat; save the reply as _translation_output.json)
  translate.py import   write the translations into the catalogs
  translate.py check    report translations that equal the English source

`import` never overwrites an existing translation unless given --force, and
reformats the catalogs it changed in Xcode's style (xcode_format.py).
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

import xcode_format

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
LANGUAGES = ["nl", "de"]
INPUT = HERE / "_translation_input.json"
OUTPUT = HERE / "_translation_output.json"
IDENTICAL_OK = HERE / "identical-ok.txt"
INTERMEDIATES = ROOT / "build/DerivedData/Build/Intermediates.noindex"

# Each catalog with the build directories of the target whose strings it holds.
CATALOGS = {
    "Apps/TreewiseMac/Resources/Localizable.xcstrings": ["TreewiseMac.build"],
    "Apps/TreewiseiOS/Resources/Localizable.xcstrings": ["TreewiseiOS.build"],
    "Apps/TreewiseMac/Resources/InfoPlist.xcstrings": [],
    "Packages/TreewiseKit/Sources/TreewiseCore/Resources/Localizable.xcstrings": ["TreewiseCore-t.build"],
    "Packages/TreewiseKit/Sources/TreewiseUI/Resources/Localizable.xcstrings": ["TreewiseUI-t.build"],
}

GLOSSARY = {
    "nl": [
        "Treewise and iCloud Drive stay as they are",
        "Use Finder's Dutch terms: folder = map, item = onderdeel, tab = tabblad, "
        "sidebar = navigatiekolom, Favorites = Favorieten, Locations = Locaties, "
        "path bar = padbalk, Enclosing Folder = Bovenliggende map, Trash = Prullenmand",
        "Informal second person (je/jouw), short UI text",
    ],
    "de": [
        "Treewise and iCloud Drive stay as they are",
        "Use Finder's German terms: folder = Ordner, item = Objekt, tab = Tab, "
        "sidebar = Seitenleiste, Favorites = Favoriten, Locations = Orte, "
        "path bar = Pfadleiste, Enclosing Folder = Übergeordneter Ordner, Trash = Papierkorb",
        "Informal second person (du/dein) as macOS uses it, short UI text",
    ],
    "all": [
        "Keep format tokens (%@, %lld, %1$@) exactly; use positional tokens when the order changes",
        "For keys with plural forms, return a `one` and an `other` form",
    ],
}


def load(path):
    with open(ROOT / path, encoding="utf-8") as handle:
        return json.load(handle)


def save(path, catalog):
    with open(ROOT / path, "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, ensure_ascii=False)
    xcode_format.reformat(ROOT / path)


def translatable(entry):
    return entry.get("shouldTranslate", True) is not False


def source(key, entry, language):
    """The English value of a key: plain text, or plural forms."""
    english = entry.get("localizations", {}).get(language, {})
    plural = english.get("variations", {}).get("plural")
    if plural:
        return {form: unit["stringUnit"]["value"] for form, unit in plural.items()}
    return english.get("stringUnit", {}).get("value", key)


def missing(entry, language):
    localization = entry.get("localizations", {}).get(language, {})
    return "stringUnit" not in localization and "variations" not in localization


def catalogs():
    return [(path, load(path)) for path in CATALOGS if (ROOT / path).exists()]


def command_status(_):
    for path, catalog in catalogs():
        keys = [k for k, e in catalog["strings"].items() if translatable(e)]
        gaps = {lang: sum(missing(catalog["strings"][k], lang) for k in keys) for lang in LANGUAGES}
        print(f"{path}: {len(keys)} keys, missing " + ", ".join(f"{l} {n}" for l, n in gaps.items()))


def command_sync(_):
    for path, targets in CATALOGS.items():
        # A release archive leaves its own, older stringsdata behind; only the latest build counts.
        files = [
            str(f)
            for t in targets
            for f in INTERMEDIATES.glob(f"**/{t}/**/*.stringsdata")
            if "ArchiveIntermediates" not in f.parts
        ]
        if not files:
            continue
        # xcstringstool drops `shouldTranslate: false` from keys it re-extracts; put it back.
        untranslated = {k for k, e in load(path)["strings"].items() if not translatable(e)}
        subprocess.run(["xcrun", "xcstringstool", "sync", str(ROOT / path), "--stringsdata", *files], check=True)
        catalog = load(path)
        for key in untranslated & catalog["strings"].keys():
            catalog["strings"][key]["shouldTranslate"] = False
        save(path, catalog)
        print("synced", path, f"({len(files)} stringsdata files)")


def command_export(_):
    strings = {}
    for path, catalog in catalogs():
        for key, entry in catalog["strings"].items():
            needs = [lang for lang in LANGUAGES if translatable(entry) and missing(entry, lang)]
            if needs:
                item = strings.setdefault(key, {"key": key, "comment": entry.get("comment", ""),
                                                "en": source(key, entry, catalog["sourceLanguage"])})
                for lang in needs:
                    item[lang] = None
    INPUT.write_text(json.dumps({
        "instructions": "Fill in every null field with the translation; keep everything else.",
        "glossary": GLOSSARY,
        "strings": sorted(strings.values(), key=lambda s: s["key"]),
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"exported {len(strings)} keys to {INPUT.relative_to(ROOT)}")


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def command_import(args):
    replies = {s["key"]: s for s in json.loads(OUTPUT.read_text(encoding="utf-8"))["strings"]}
    for path, catalog in catalogs():
        changed = False
        for key, entry in catalog["strings"].items():
            reply = replies.get(key)
            for lang in LANGUAGES:
                value = reply.get(lang) if reply else None
                if value is None or not translatable(entry) or (not args.force and not missing(entry, lang)):
                    continue
                localized = {"variations": {"plural": {f: unit(v) for f, v in value.items()}}} \
                    if isinstance(value, dict) else unit(value)
                localizations = entry.setdefault("localizations", {})
                localizations[lang] = localized
                # Xcode keeps the languages in alphabetical order; so does the import.
                entry["localizations"] = dict(sorted(localizations.items()))
                changed = True
        if changed:
            save(path, catalog)
            print("imported into", path)


def command_check(_):
    allowed = set()
    if IDENTICAL_OK.exists():
        allowed = {line.strip() for line in IDENTICAL_OK.read_text(encoding="utf-8").splitlines()
                   if line.strip() and not line.startswith("#")}
    found = False
    for path, catalog in catalogs():
        for key, entry in catalog["strings"].items():
            english = source(key, entry, catalog["sourceLanguage"])
            for lang in LANGUAGES:
                value = entry.get("localizations", {}).get(lang, {}).get("stringUnit", {}).get("value")
                if value is not None and value == english and key not in allowed:
                    print(f"{path}: {lang} equals the English source: {key!r}")
                    found = True
    sys.exit(1 if found else 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["status", "sync", "export", "import", "check"])
    parser.add_argument("--force", action="store_true", help="overwrite existing translations on import")
    args = parser.parse_args()
    globals()["command_" + args.command](args)


if __name__ == "__main__":
    main()
