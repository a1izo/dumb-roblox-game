"""The emote faces: six expressions drawn as transparent 256 px PNGs for a Roblox face Decal, written to
art/export/faces/. The owner uploads each as a Decal and pastes its id into src/shared/EmoteMedia.luau
(FACES); an emote with `face` swaps it onto the head while it plays.

    python art/scripts/faces.py        (any Python with numpy; Blender's will do)

A face Decal is stretched across the front of the R6 head (twice as wide as it is tall), so the shapes are
drawn narrow: round on the head. Ink strokes, nothing else, in the game's black, the whites of the eyes and
teeth in bone.
"""

import math
import os
import struct
import zlib

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "export", "faces"))
SIZE = 256
SS = 4  # supersampling
N = SIZE * SS
INK = (22, 20, 24)
BONE = (238, 234, 224)
SQUASH = 0.62  # x is squashed by this much (the head stretches the decal sideways)

ys, xs = np.mgrid[0:N, 0:N].astype(np.float32) / N


def _sx(x):
    """A point's x on the canvas: drawn narrower about the middle."""
    return 0.5 + (x - 0.5) * SQUASH


def ellipse(cx, cy, rx, ry):
    cx = _sx(cx)
    rx = rx * SQUASH
    return ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2 <= 1.0


def stroke(points, width):
    """A polyline with round ends, `width` thick (in canvas units, before the squash)."""
    mask = np.zeros((N, N), bool)
    pts = [(_sx(x), y) for x, y in points]
    half = width / 2
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        dx, dy = x1 - x0, y1 - y0
        length2 = dx * dx + dy * dy
        if length2 == 0:
            u = np.zeros_like(xs)
        else:
            u = np.clip(((xs - x0) * dx + (ys - y0) * dy) / length2, 0, 1)
        px, py = x0 + u * dx, y0 + u * dy
        mask |= (xs - px) ** 2 + (ys - py) ** 2 <= half * half
    return mask


def curve(x0, y0, x1, y1, bend, steps=24):
    """Points along a gentle arc from (x0, y0) to (x1, y1), bowed by `bend` (positive: downwards)."""
    out = []
    for i in range(steps + 1):
        t = i / steps
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t + bend * 4 * t * (1 - t)
        out.append((x, y))
    return out


class Face:
    def __init__(self):
        self.ink = np.zeros((N, N), bool)
        self.white = np.zeros((N, N), bool)

    def png(self, path):
        def down(mask):
            return mask.reshape(SIZE, SS, SIZE, SS).mean(axis=(1, 3))

        ink, white = down(self.ink), down(self.white)
        alpha = np.clip(ink + white * (1 - ink), 0, 1)
        rgb = np.zeros((SIZE, SIZE, 3), np.float32)
        safe = np.where(alpha > 0, alpha, 1)
        for c in range(3):
            rgb[..., c] = (INK[c] * ink + BONE[c] * white * (1 - ink)) / safe
        pixels = np.dstack([rgb, alpha * 255]).round().clip(0, 255).astype(np.uint8)
        raw = b"".join(b"\x00" + row.tobytes() for row in pixels)

        def chunk(kind, data):
            return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

        head = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
        with open(path, "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", head) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


EYE_Y = 0.45
LEFT, RIGHT = 0.35, 0.65  # on the picture (the head's own right eye is on the left)
LINE = 0.025
EYE_RY = 0.088


def eyes_open(face, rx=0.058, ry=EYE_RY, pupil=None):
    for x in (LEFT, RIGHT):
        if pupil is None:
            face.ink |= ellipse(x, EYE_Y, rx, ry)
        else:
            face.white |= ellipse(x, EYE_Y, rx, ry)
            face.ink |= ellipse(x, EYE_Y, rx, ry) & ~ellipse(x, EYE_Y, rx - 0.018, ry - 0.016)
            face.ink |= ellipse(x, EYE_Y + 0.006, pupil, pupil * 1.2)


def lids(face, drop, tilt=0.0, which=(LEFT, RIGHT)):
    """Heavy upper lids: everything of the eye above the lid is cut away and the lid drawn."""
    for x in which:
        side = -1 if x < 0.5 else 1
        top = EYE_Y - EYE_RY + drop
        cut = ys < top + (xs - _sx(x)) * tilt * side
        face.ink &= ~(cut & ellipse(x, EYE_Y, 0.08, 0.11))
        face.ink |= stroke([(x - 0.075, top - 0.075 * tilt), (x + 0.075, top + 0.075 * tilt)], LINE)


def deadpan():
    f = Face()
    eyes_open(f)
    lids(f, 0.06)
    f.ink |= stroke([(0.43, 0.66), (0.57, 0.66)], LINE)
    return f


def smirk():
    f = Face()
    eyes_open(f)
    lids(f, 0.035, tilt=0.25)
    f.ink |= stroke(curve(0.41, 0.655, 0.6, 0.62, 0.02), LINE)
    f.ink |= stroke([(0.595, 0.615), (0.615, 0.6)], LINE * 0.9)
    return f


def smug():
    f = Face()
    for x in (LEFT, RIGHT):  # eyes half shut and curved, under easy brows
        f.ink |= ellipse(x, EYE_Y + 0.02, 0.05, 0.045) & (ys > EYE_Y + 0.015)
        f.ink |= stroke(curve(x - 0.06, EYE_Y + 0.02, x + 0.06, EYE_Y + 0.02, -0.012), LINE)
        f.ink |= stroke(curve(x - 0.055, 0.33, x + 0.055, 0.33, -0.018), LINE * 0.9)
    f.ink |= stroke(curve(0.42, 0.63, 0.58, 0.63, 0.035), LINE)
    f.ink |= stroke([(0.58, 0.63), (0.6, 0.615)], LINE * 0.8)
    return f


def raised_brow():
    f = Face()
    eyes_open(f, ry=0.07)
    f.ink |= stroke(curve(LEFT - 0.07, 0.29, LEFT + 0.065, 0.28, -0.05), LINE)  # up, arched
    f.ink |= stroke([(RIGHT - 0.07, 0.335), (RIGHT + 0.07, 0.35)], LINE)  # down, flat
    lids(f, 0.03, which=(RIGHT,))
    f.ink |= stroke([(0.46, 0.66), (0.57, 0.65)], LINE)
    return f


def wide_grin():
    f = Face()
    eyes_open(f, rx=0.06, ry=0.085, pupil=0.012)
    top = curve(0.32, 0.6, 0.68, 0.6, 0.03)
    bottom = curve(0.32, 0.6, 0.68, 0.6, 0.16)
    grin = np.zeros((N, N), bool)
    for (x0, y0), (_, y1) in zip(top, bottom):
        grin |= (np.abs(xs - _sx(x0)) <= 0.02 * SQUASH) & (ys >= y0) & (ys <= y1)
    f.white |= grin
    f.ink |= stroke(top, LINE)
    f.ink |= stroke(bottom, LINE)
    f.ink |= stroke(curve(0.34, 0.66, 0.66, 0.66, 0.06), LINE * 0.6)
    for i in range(1, 8):
        x = 0.32 + 0.36 * i / 8
        y0 = 0.6 + 0.03 * 4 * (i / 8) * (1 - i / 8)
        y1 = 0.6 + 0.16 * 4 * (i / 8) * (1 - i / 8)
        f.ink |= stroke([(x, y0), (x, y1)], LINE * 0.5)
    return f


def stare():
    f = Face()
    eyes_open(f, rx=0.065, ry=0.09, pupil=0.011)
    f.ink |= stroke([(0.47, 0.67), (0.53, 0.67)], LINE * 0.8)
    return f


FACES = {
    "deadpan": deadpan,
    "smirk": smirk,
    "smug": smug,
    "raisedBrow": raised_brow,
    "wideGrin": wide_grin,
    "stare": stare,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, draw in FACES.items():
        path = os.path.join(OUT, f"face_{name}.png")
        draw().png(path)
        print(os.path.relpath(path, os.path.join(HERE, "..", "..")))


if __name__ == "__main__":
    main()
