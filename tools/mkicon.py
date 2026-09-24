#!/usr/bin/env python3
"""Generate simple app icons for the Region Changer webOS app.

Pure-stdlib PNG writer (no PIL/ImageMagick). Draws a dark rounded-square
badge with concentric "location/region" rings and a center dot.
"""
import struct
import zlib
import os


def roundrect(canvas, size, x0, y0, x1, y1, radius, color):
    import math
    for y in range(y0, y1):
        for x in range(x0, x1):
            # distance to nearest corner center -> rounded corners
            cx = max(min(x, x0 + radius - 1), x1 - radius)
            cy = max(min(y, y0 + radius - 1), y1 - radius)
            if (x - cx) ** 2 + (y - cy) ** 2 > radius ** 2:
                continue
            canvas[y * size + x] = color


def circle(canvas, size, cx, cy, radius, color, width=1):
    for y in range(max(0, cy - radius), min(size, cy + radius)):
        for x in range(max(0, cx - radius), min(size, cx + radius)):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if abs(d - radius) <= width:
                canvas[y * size + x] = color


def disk(canvas, size, cx, cy, radius, color):
    for y in range(max(0, cy - radius), min(size, cy + radius)):
        for x in range(max(0, cx - radius), min(size, cx + radius)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2:
                canvas[y * size + x] = color


def make_icon(size, out_path):
    NAVY = (13, 27, 42)
    CYAN = (64, 197, 231)
    WHITE = (255, 255, 255)
    ORANGE = (255, 150, 64)

    canvas = [NAVY] * (size * size)
    pad = int(size * 0.05)
    radius = int(size * 0.18)
    roundrect(canvas, size, pad, pad, size - pad, size - pad, radius, NAVY)

    cx = cy = size // 2
    rw = max(1, int(size * 0.02))
    u = size
    for r, col in (
        (int(u * 0.36), CYAN),
        (int(u * 0.26), WHITE),
        (int(u * 0.16), CYAN),
    ):
        circle(canvas, size, cx, cy, r, col, rw)
    disk(canvas, size, cx, cy, int(u * 0.06), ORANGE)

    write_png(out_path, size, size, canvas)


def write_png(path, w, h, rows_of_pixels):
    raw = bytearray()
    for y in range(h):
        raw.append(0)  # filter type 0
        raw += bytes(c for px in rows_of_pixels[y * w:(y + 1) * w] for c in px)
    comp = zlib.compress(bytes(raw), 9)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)  # 8bit RGB
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", comp))
        f.write(chunk(b"IEND", b""))


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    app = os.path.join(
        here, "..", "pkg", "usr", "palm", "applications",
        "org.webosbrew.regionchanger")
    os.makedirs(app, exist_ok=True)
    make_icon(80, os.path.join(app, "icon.png"))
    make_icon(130, os.path.join(app, "largeIcon.png"))
    print("icons written to", app)


if __name__ == "__main__":
    main()