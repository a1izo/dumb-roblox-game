"""The white brush 斬 painted over the right of the screen in "Let's dance!" (2026-11-12, the user: "the Kanji isnt
accurate at all. It should be entirely on the right part of the screen, covering it"). Drawn here stroke by stroke in
the character's real order and shape (車 on the left: the top bar, the box with its middle bar, the rising bottom bar,
the long centre post; 斤 on the right: the falling tick, the left post sweeping down-left, the bar, the long right
post), each as a loaded brush: pressed hard where it lands, the hairs splitting into dry streaks as it runs out,
ragged edges, splatter thrown off the hard ends. White on transparent, 1024 square. Run with Blender's Python:

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\5.2\\python\\bin\\python.exe" art/scripts/ui/zan_kanji.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
import png  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "art", "export", "textures", "UiZanKanji.png")
N = 1024

WEIGHT = 0.68  # every stroke's width over the numbers below

# (points, width, kind): kind "bar" presses at the start and lifts clean, "post" presses and runs dry to the end,
# "sweep" lands hard and tapers to a point
STROKES = [
    # 車
    ([(0.06, 0.17), (0.25, 0.155), (0.46, 0.14)], 0.042, "bar"),
    ([(0.11, 0.28), (0.115, 0.43), (0.12, 0.6)], 0.04, "post"),
    ([(0.11, 0.28), (0.27, 0.27), (0.41, 0.26), (0.415, 0.27), (0.405, 0.6)], 0.04, "bar"),
    ([(0.14, 0.43), (0.27, 0.42), (0.38, 0.41)], 0.034, "bar"),
    ([(0.13, 0.585), (0.27, 0.575), (0.39, 0.565)], 0.034, "bar"),
    ([(0.04, 0.775), (0.25, 0.735), (0.49, 0.69)], 0.046, "bar"),
    ([(0.265, 0.03), (0.262, 0.5), (0.26, 0.985)], 0.052, "post"),
    # 斤
    ([(0.9, 0.06), (0.78, 0.13), (0.6, 0.2)], 0.042, "sweep"),
    ([(0.6, 0.2), (0.605, 0.4), (0.59, 0.62), (0.55, 0.8), (0.5, 0.93)], 0.05, "sweep"),
    ([(0.6, 0.47), (0.78, 0.455), (0.97, 0.44)], 0.044, "bar"),
    ([(0.8, 0.46), (0.802, 0.72), (0.8, 0.99)], 0.056, "post"),
]


def noise1(x, seed, octaves=4):
    """Smooth value noise of one variable (any shape array), 0..1."""
    rng = np.random.default_rng(seed)
    out = np.zeros_like(x)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        f = 2 ** o
        table = rng.random(4096)
        u = x * f * 40
        i = np.floor(u).astype(int) % 4095
        t = u - np.floor(u)
        t = t * t * (3 - 2 * t)
        out += amp * (table[i] * (1 - t) + table[i + 1] * t)
        total += amp
        amp *= 0.5
    return out / total


def stroke(x, y, pts, width, kind, seed):
    """The ink of one stroke: alpha 0..1 over the grid."""
    pts = np.array(pts)
    seg = pts[1:] - pts[:-1]
    lens = np.hypot(seg[:, 0], seg[:, 1])
    total = lens.sum()
    best_d = np.full(x.shape, 1e9)
    best_t = np.zeros(x.shape)
    best_side = np.zeros(x.shape)
    # (before the first point and past the last, in distance along the stroke: for the cut caps)
    (ax0, ay0), (dx0, dy0), l0 = pts[0], seg[0], lens[0]
    before = -((x - ax0) * dx0 + (y - ay0) * dy0) / l0
    side0 = ((x - ax0) * dy0 - (y - ay0) * dx0) / l0
    (ax1, ay1), (dx1, dy1), l1 = pts[-2], seg[-1], lens[-1]
    beyond = ((x - ax1) * dx1 + (y - ay1) * dy1) / l1 - l1
    run = 0.0
    for (ax, ay), (dx, dy), ll in zip(pts[:-1], seg, lens):
        tt = np.clip(((x - ax) * dx + (y - ay) * dy) / (ll * ll), 0, 1)
        px, py = ax + tt * dx, ay + tt * dy
        d = np.hypot(x - px, y - py)
        side = ((x - ax) * dy - (y - ay) * dx) / ll  # signed distance across the stroke
        closer = d < best_d
        best_d = np.where(closer, d, best_d)
        best_t = np.where(closer, (run + tt * ll) / total, best_t)
        best_side = np.where(closer, side, best_side)
        run += ll
    t = best_t
    # the width along it: the brush lands (a swelling), runs, then lifts (bar), runs dry (post) or tapers (sweep)
    # (the press is on one side: the brush lands at a slant, so the stroke's head is heavier above than below)
    near = np.exp(-((t - 0.05) / 0.08) ** 2)
    land = 1 + near * (0.25 + 0.3 * np.clip(best_side / width, -1, 1))
    if kind == "sweep":
        body = (1 - t) ** 0.7 * 1.05 + 0.04
    elif kind == "post":
        body = 1 - 0.25 * t
    else:
        body = 1 - 0.15 * t + 0.25 * np.exp(-((t - 0.97) / 0.04) ** 2)  # the small press at a bar's end
    w = width * land * body
    # ragged edges: the width wobbles along the stroke
    w = w * (0.9 + 0.2 * noise1(t * 0.35, seed))
    edge = np.clip((w - best_d) / (width * 0.1), 0, 1)
    # the head cut at a slant (where the brush tip met the paper), not round
    cut = width * (0.25 + 0.55 * np.clip(-side0 / width, -1, 1))
    edge = edge * np.where(before > 0, np.clip((cut - before) / (width * 0.08), 0, 1), 1)
    # a dry or lifted end stops square under its streaks; a sweep's tip is already a point
    if kind != "sweep":
        edge = edge * np.where(beyond > 0, np.clip(1 - beyond / (width * 0.25), 0, 1), 1)
    # the dry brush: hairs as streaks across the stroke (by the signed offset), opening up toward the end
    across = best_side / (width * 2) + 0.5
    hairs = noise1(across * 1.1, seed + 11, octaves=3)
    dry_from = 0.55 if kind == "post" else (0.7 if kind == "bar" else 0.45)
    dryness = np.clip((t - dry_from) / (1 - dry_from), 0, 1) ** 1.3
    gaps = np.clip((hairs - (0.62 - 0.4 * dryness)) / 0.06, 0, 1)
    streak = 1 - dryness * (1 - gaps) * 0.95
    # (and the grain of the paper through the ink, faintly)
    return edge * streak


def main():
    y, x = (np.mgrid[0:N, 0:N] + 0.5) / N
    alpha = np.zeros((N, N))
    for k, (pts, width, kind) in enumerate(STROKES):
        alpha = np.maximum(alpha, stroke(x, y, pts, width * WEIGHT, kind, 100 + k * 7))
    # splatter thrown off the hard landings and the ends of the posts
    rng = np.random.default_rng(42)
    for pts, width, kind in STROKES:
        width *= WEIGHT
        for anchor in (pts[0], pts[-1]):
            if rng.random() < 0.7:
                continue
            for _ in range(rng.integers(2, 5)):
                ang = rng.uniform(0, 2 * np.pi)
                dist = width * rng.uniform(1.1, 2.6)
                cx, cy = anchor[0] + np.cos(ang) * dist, anchor[1] + np.sin(ang) * dist
                r = width * rng.uniform(0.06, 0.2)
                d = np.hypot(x - cx, y - cy)
                alpha = np.maximum(alpha, np.clip((r - d) / (r * 0.3 + 1e-4), 0, 1))
    rgb = np.ones((N, N, 3))
    # (a warm grey in the thickest ink would read as paint; the game's stroke is pure white)
    img = np.dstack([rgb, alpha])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    png.write(OUT, img)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
