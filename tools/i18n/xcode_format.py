#!/usr/bin/env python3
"""Rewrite String Catalogs (.xcstrings) in Xcode's own style.

Python's json.dump writes `"key":` and `{}`, Xcode writes `"key" :` and an
empty object over three lines, without a newline at the end of the file. After
`translate.py import` rewrites a catalog, this restores Xcode's style, so the
diff shows only the translations and Xcode does not reformat it again.
See ADR 0017.

Usage: tools/i18n/xcode_format.py <catalog.xcstrings>...
"""
import json
import sys


def emit(value, indent=0):
    """Returns `value` as JSON in Xcode's style: two-space indent, ` : `
    between key and value, literal unicode."""
    pad = "  " * indent
    child = "  " * (indent + 1)
    if isinstance(value, dict):
        if not value:
            return "{\n\n" + pad + "}"
        entries = [
            child + json.dumps(key, ensure_ascii=False) + " : " + emit(item, indent + 1)
            for key, item in value.items()
        ]
        return "{\n" + ",\n".join(entries) + "\n" + pad + "}"
    if isinstance(value, list):
        if not value:
            return "[]"
        entries = [child + emit(item, indent + 1) for item in value]
        return "[\n" + ",\n".join(entries) + "\n" + pad + "]"
    return json.dumps(value, ensure_ascii=False)


def reformat(path):
    """Rewrites one catalog in Xcode's style."""
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(emit(data))


if __name__ == "__main__":
    for catalog in sys.argv[1:]:
        reformat(catalog)
        print("reformatted", catalog)
