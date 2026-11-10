"""Pictures the scene deaths show, drawn by hand (no photographs): written to art/export/textures/<Name>.png and carried
into Roblox on quads in the Scenes venue's FBX (its TEXTURES), like its skies; the game finds one by Assets.texture.

    SelectionChart  Dead by selection: the chart on the victim's phone (the user's picture, 2026-11-08, redrawn with
                    no figures and no words): two columns of five dots on paper, red on the left, blue on the right;
                    a red arrow from every left dot to three right dots (an even web), a blue arrow from every right
                    dot to the TOP THREE left dots only (a funnel). The bottom left dot, ringed twice in pencil, is
                    the victim's: no blue arrow comes to it. Inked by hand: every line bows a little, swells and
                    thins, and no two arrowheads are the same (2026-11-10, the user on the chart the scene used to
                    draw live from straight bars: "the way you drew those lines looks completely made by AI").

    blender -b --factory-startup --python art/scripts/scene_pictures.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402

import textures  # noqa: E402

RED = (0.84, 0.16, 0.2)
BLUE = (0.16, 0.42, 0.86)
INK = (0.1, 0.1, 0.12)
PENCIL = (0.3, 0.3, 0.33)
PAPER = (0.965, 0.955, 0.93)

W, H = 512, 640
LEFT = [(112, 84 + 118 * k) for k in range(5)]
RIGHT = [(400, 84 + 118 * k) for k in range(5)]
ME = 4  # the victim's dot: the bottom one on the left
DOT = 26


def _bowed(a, b, bow, rng, pieces=9, width=3.2):
    """A hand's line from a to b: bowed sideways by `bow` px, a little shaky, pressed harder in its middle."""
    ax, ay = a
    bx, by = b
    nx, ny = -(by - ay), bx - ax
    n = math.hypot(nx, ny)
    nx, ny = nx / n, ny / n
    points = []
    for k in range(pieces + 1):
        t = k / pieces
        side = bow * math.sin(math.pi * t) + rng.normal(0, 0.9)
        press = width * (0.72 + 0.4 * math.sin(math.pi * t) + rng.normal(0, 0.05))
        points.append((ax + (bx - ax) * t + nx * side, ay + (by - ay) * t + ny * side, press))
    return points


def _arrow(mask, px, py, a, b, rng, scale, width):
    """An arrow from dot a to dot b, stopping short of both, its head two quick flicks."""
    ax, ay = a
    bx, by = b
    d = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / d, (by - ay) / d
    start = (ax + ux * (DOT + 8), ay + uy * (DOT + 8))
    end = (bx - ux * (DOT + 12 + rng.uniform(0, 5)), by - uy * (DOT + 12 + rng.uniform(0, 5)))
    line = _bowed(start, end, rng.uniform(-9, 9), rng, width=width)
    textures._stroke(mask, px, py, line, scale, wobble=0.1, seed=int(rng.integers(1 << 30)))
    # the head, along the line's own last piece
    (qx, qy, _), (ex, ey, _) = line[-2], line[-1]
    back = math.atan2(qy - ey, qx - ex)
    for sign in (-1, 1):
        angle = back + sign * math.radians(rng.uniform(24, 34))
        length = rng.uniform(15, 21)
        tip = (ex + math.cos(angle) * length, ey + math.sin(angle) * length)
        textures._stroke(mask, px, py, [(ex, ey, width * 1.1), (tip[0], tip[1], width * 0.6)], scale)


def _ring(mask, px, py, centre, radius, rng, scale, turns=2.15, width=2.6):
    """A pencil's ring round a dot: more than once round, never closing on itself."""
    cx, cy = centre
    points = []
    steps = int(26 * turns)
    start = rng.uniform(0, 2 * math.pi)
    for k in range(steps + 1):
        t = k / steps
        a = start + t * turns * 2 * math.pi
        r = radius * (1 + 0.07 * math.sin(a * 1.7 + 1.0) + 0.05 * t)
        points.append((cx + math.cos(a) * r * 1.06, cy + math.sin(a) * r * 0.94, width * (0.8 + 0.3 * math.sin(a * 2.3))))
    textures._stroke(mask, px, py, points, scale, wobble=0.12, seed=int(rng.integers(1 << 30)))


def _blob(px, py, centre, radius, rng, scale):
    """A dot filled by hand: not a compass's circle."""
    cx, cy = centre
    a = np.arctan2(py - cy * scale, px - cx * scale)
    p1, p2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
    r = radius * scale * (1 + 0.05 * np.sin(a * 2 + p1) + 0.03 * np.sin(a * 5 + p2))
    return np.hypot(px - cx * scale, py - cy * scale) <= r


def selection_chart(over=3):
    rng = np.random.default_rng(1108)
    big_w, big_h = W * over, H * over
    scale = float(over)
    py, px = np.mgrid[0:big_h, 0:big_w].astype(np.float32) + 0.5
    red = np.zeros(px.shape, dtype=bool)
    blue = np.zeros(px.shape, dtype=bool)
    ink = np.zeros(px.shape, dtype=bool)
    pencil = np.zeros(px.shape, dtype=bool)
    # the red web: every left dot to three right dots, evenly
    for i in range(5):
        for j in ((i + 1) % 5, (i + 2) % 5, (i + 4) % 5):
            _arrow(red, px, py, LEFT[i], RIGHT[j], rng, scale, 2.6)
    # the blue funnel: every right dot to the top three left dots
    for i in range(5):
        for j in range(3):
            _arrow(blue, px, py, RIGHT[i], LEFT[j], rng, scale, 3.2)
    left_dots = np.zeros(px.shape, dtype=bool)
    right_dots = np.zeros(px.shape, dtype=bool)
    for centre in LEFT:
        left_dots |= _blob(px, py, centre, DOT, rng, scale)
    for centre in RIGHT:
        right_dots |= _blob(px, py, centre, DOT, rng, scale)
    for centre in LEFT + RIGHT:
        _ring(ink, px, py, centre, DOT, rng, scale, turns=1.08, width=2.4)
    _ring(pencil, px, py, LEFT[ME], DOT + 17, rng, scale)
    # paper, with a little tooth
    tooth = rng.normal(0, 0.012, size=(big_h, big_w)).astype(np.float32)
    img = np.empty((big_h, big_w, 3), dtype=np.float32)
    for ch in range(3):
        img[..., ch] = PAPER[ch] + tooth

    def lay(mask, colour, strength=1.0):
        for ch in range(3):
            img[..., ch] = np.where(mask, img[..., ch] * (1 - strength) + colour[ch] * strength, img[..., ch])

    lay(red, RED, 0.92)
    lay(blue, BLUE, 0.92)
    lay(left_dots, RED)
    lay(right_dots, BLUE)
    lay(ink, INK, 0.9)
    lay(pencil, PENCIL, 0.8)
    small = img.reshape(H, over, W, over, 3).mean(axis=(1, 3))
    rgba = np.concatenate([np.clip(small, 0, 1), np.ones((H, W, 1), dtype=np.float32)], axis=-1)
    return textures.save_array("SelectionChart", rgba)


if __name__ == "__main__":
    print("[scene pictures]", selection_chart())
