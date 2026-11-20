"""The screenshots of the UI review's dark runs that are not dark.

The simulator does not pass a change of the device's appearance on to the app, so a dark run
can look at the light screens and still pass; this finds that. Each screenshot named `-dark`
is shrunk to one pixel by `sips`, whose brightness says whether the screen is mostly dark.

Usage: python3 -I dark.py <review folder>
Prints each light one and exits 1 when there is one.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

# A dark screen's average brightness, of 255, stays well below the middle.
MOST_FOR_DARK = 128
BMP_PIXELS_OFFSET = 10


def brightness(png: Path, scratch: Path) -> int:
    pixel = scratch / "pixel.bmp"
    subprocess.run(
        ["sips", "-s", "format", "bmp", "-z", "1", "1", str(png), "--out", str(pixel)],
        capture_output=True, check=True)
    data = pixel.read_bytes()
    start = int.from_bytes(data[BMP_PIXELS_OFFSET:BMP_PIXELS_OFFSET + 4], "little")
    blue, green, red = data[start], data[start + 1], data[start + 2]
    return (red + green + blue) // 3


def main() -> int:
    folder = Path(sys.argv[1])
    light = []
    with tempfile.TemporaryDirectory() as scratch:
        for png in sorted(folder.glob("*-dark.png")):
            if brightness(png, Path(scratch)) > MOST_FOR_DARK:
                light.append(png.stem)
    for name in light:
        print(f"{name}: light, though from a dark run")
    return 1 if light else 0


if __name__ == "__main__":
    sys.exit(main())
