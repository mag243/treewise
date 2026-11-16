#!/usr/bin/env python3
"""Copies the App Store screenshots out of an exported result bundle (ADR 0118): each
attachment named appstore-<locale>-<NN-name> becomes <output>/<locale>/<NN-name>.png,
checked as the uploader checks it.

Usage: python3 -I collect_screenshots.py <exported attachments folder> <output folder>
"""

import json
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import listing  # noqa: E402
import upload  # noqa: E402

NAME = re.compile(r"^appstore-([a-z]{2}-[A-Z]{2})-(\d\d-[a-z0-9-]+)")


def main() -> None:
    exported, output = Path(sys.argv[1]), Path(sys.argv[2])
    count = 0
    for manifest in exported.rglob("manifest.json"):
        for test in json.loads(manifest.read_text()):
            for attachment in test.get("attachments", []):
                match = NAME.match(attachment.get("suggestedHumanReadableName", ""))
                if not match:
                    continue
                locale, name = match.groups()
                (output / locale).mkdir(parents=True, exist_ok=True)
                shutil.copyfile(manifest.parent / attachment["exportedFileName"], output / locale / f"{name}.png")
                count += 1
    if count == 0:
        sys.exit("No App Store screenshots in the result bundle.")
    for locale in listing.LOCALES:
        shots = upload.screenshots_of(locale, output)
        print(f"    {locale}: {len(shots)} screenshots")


if __name__ == "__main__":
    main()
