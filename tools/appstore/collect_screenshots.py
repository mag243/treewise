#!/usr/bin/env python3
"""Copies the App Store screenshots out of an exported result bundle (ADR 0118, 0145): each
attachment named appstore-<device>-<locale>-<NN-name> becomes
<output>/<device>/<locale>/<NN-name>.png, checked as the uploader checks it.

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

NAME = re.compile(r"^appstore-([a-z]+(?:-[a-z]+)?)-([a-z]{2}-[A-Z]{2})-(\d\d-[a-z0-9-]+)")


def main() -> None:
    exported, output = Path(sys.argv[1]), Path(sys.argv[2])
    count = 0
    devices = set()
    for manifest in exported.rglob("manifest.json"):
        for test in json.loads(manifest.read_text()):
            for attachment in test.get("attachments", []):
                match = NAME.match(attachment.get("suggestedHumanReadableName", ""))
                if not match:
                    continue
                device, locale, name = match.groups()
                if device not in upload.DEVICES:
                    sys.exit(f"Screenshots of an unknown device: {device}")
                devices.add(device)
                (output / device / locale).mkdir(parents=True, exist_ok=True)
                target = output / device / locale / f"{name}.png"
                shutil.copyfile(manifest.parent / attachment["exportedFileName"], target)
                count += 1
    if count == 0:
        sys.exit("No App Store screenshots in the result bundle.")
    for device in sorted(devices):
        for locale in listing.LOCALES:
            shots = upload.screenshots_of(device, locale, output)
            print(f"    {device}, {locale}: {len(shots)} screenshots")


if __name__ == "__main__":
    main()
