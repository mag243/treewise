"""Draws a small landscape for the sandbox's demo pictures (ADR 0019): a sky
gradient, a sun and two hills, in colours chosen from the file's name, so
each picture differs but is the same every time. Writes a PNG; sips turns
it into the JPEG or HEIC the name asks for.

Usage: python3 -I make_image.py <name> <out.png>
"""

import hashlib
import struct
import sys
import zlib

WIDTH, HEIGHT = 960, 640

SKIES = [
    ((255, 183, 120), (90, 120, 200)),  # sunset
    ((150, 205, 250), (40, 110, 200)),  # noon
    ((250, 160, 170), (70, 60, 140)),  # dusk
    ((200, 230, 240), (90, 160, 190)),  # haze
]
HILLS = [((70, 140, 90), (40, 100, 70)), ((120, 150, 80), (80, 110, 60)), ((60, 90, 120), (40, 60, 90))]


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def hill(x, base, height, phase, length):
    # A smooth bump made of two parabola-like waves, no math module needed.
    u = ((x / length + phase) % 2.0) - 1.0
    return base - height * (1.0 - u * u)


def draw(name):
    digest = hashlib.sha256(name.encode()).digest()
    top, bottom = SKIES[digest[0] % len(SKIES)]
    near, far = HILLS[digest[1] % len(HILLS)]
    sun_x = WIDTH * (0.2 + 0.6 * digest[2] / 255)
    sun_y = HEIGHT * (0.2 + 0.2 * digest[3] / 255)
    sun_r = 40 + digest[4] % 30
    phase_far, phase_near = digest[5] / 255, digest[6] / 255
    rows = []
    for y in range(HEIGHT):
        row = bytearray([0])
        sky = mix(top, bottom, y / HEIGHT)
        for x in range(WIDTH):
            colour = sky
            if (x - sun_x) ** 2 + (y - sun_y) ** 2 < sun_r * sun_r:
                colour = (255, 236, 170)
            if y > hill(x, HEIGHT * 0.78, HEIGHT * 0.25, phase_far, WIDTH * 0.6):
                colour = far
            if y > hill(x, HEIGHT * 0.95, HEIGHT * 0.22, phase_near, WIDTH * 0.45):
                colour = near
            row.extend(colour)
        rows.append(bytes(row))
    return b"".join(rows)


def png(pixels):
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(pixels, 6))
        + chunk(b"IEND", b"")
    )


def main():
    name, out = sys.argv[1], sys.argv[2]
    with open(out, "wb") as file:
        file.write(png(draw(name)))


if __name__ == "__main__":
    main()
