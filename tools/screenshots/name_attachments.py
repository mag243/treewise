"""Copies the screenshots of ScreenshotTests out of an exported result bundle
(ADR 0041): each attachment named like 01-main-light becomes 01-main-light.png.

Usage: python3 -I name_attachments.py <exported attachments folder> <output folder>
"""

import json
import re
import shutil
import sys
from pathlib import Path

SCREENSHOT_NAME = re.compile(r"^(\d\d-[a-z0-9-]+)")


def main() -> None:
    exported, output = Path(sys.argv[1]), Path(sys.argv[2])
    manifest = json.loads((exported / "manifest.json").read_text())
    count = 0
    for test in manifest:
        for attachment in test.get("attachments", []):
            match = SCREENSHOT_NAME.match(attachment.get("suggestedHumanReadableName", ""))
            if not match:
                continue
            source = exported / attachment["exportedFileName"]
            shutil.copyfile(source, output / f"{match.group(1)}{source.suffix or '.png'}")
            count += 1
    if count == 0:
        sys.exit("No screenshots in the result bundle.")
    print(f"    {count} screenshots")


if __name__ == "__main__":
    main()
