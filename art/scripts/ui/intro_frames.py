"""The apple loading screen (UI/AppleLoading), painted after your pencil sketch (art/refs/ui/apple_sketch.png,
2026-10-27): a red apple turning as it falls through the dark, then caught in a hand rising from the lower left, the
thumb closing over it; coloured like your two frames (a glossy red apple, black), the hand a death god's.

The apple is modelled (an apple's shape: shoulders, the hollow its stem grows from, the dimple underneath), lit from
the upper left as your sketch lights it and shaded as an anime frame lays it (a lit face and a crisp shade, long sharp
white glints, a lighter rim; no glow round it), so every turn of it is the same apple and the one that lands in the
hand is the one that fell. The hand is ui/apple_hand.py's (a death god's since 2026-11-05, in the spirit of Ryuk's;
the thumb its own picture so it closes smoothly).

    AppleSpin1..4  1024 x 1024  four 4 x 4 sheets of the apple turning (transparent), 64 cells to a turn (2026-11-03:
                                16 a turn stepped at about 15 a second as it fell; now it turns smoothly); the first
                                cell of the first sheet is how it lies in the hand, and the game brings the turn round
                                to it as the hand catches it
    AppleHandBack  1024 x 736   the inside of the cupped palm, under the apple
    AppleHandFront 1024 x 736   the hand over the apple (the palm's lip, the fingers round its right side, the sleeve)
    AppleThumb     square       the thumb on a square round its root; the game stands it up while the hand waits and
                                turns it down over the apple as it lands

Also writes src/client/UI/LoadingArt.luau (how the hand's picture and the apple's cells sit on the screen, so the
falling apple lands exactly in the hand) and a preview, art/export/previews/apple_loading.png (the fall and the catch,
as the game lays them).

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/ui/intro_frames.py
    (add --hand to redraw only the hand's three pictures, the apple's sheets read back as they are)
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import apple_hand as ah  # noqa: E402
import flow  # noqa: E402
import paint as pt  # noqa: E402
import png  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SKETCH = os.path.join(ROOT, "art", "refs", "ui", "apple_sketch.png")
OUT = os.path.join(ROOT, "art", "export", "textures")
PREVIEW = os.path.join(ROOT, "art", "export", "previews", "apple_loading.png")
LUAU = os.path.join(ROOT, "src", "client", "UI", "LoadingArt.luau")

# The screen, as your frames lay it: the apple a fifth of the screen's height across, caught a little left of the
# middle's height below it, the hand reaching up out of the lower left.
APPLE_ON_SCREEN = 0.21  # the apple's width, a share of the screen's height
CATCH = (0.5, 0.72)  # where it is caught, shares of the screen

# The sheets: 64 turns of the apple on four 4 x 4 sheets, 256 px cells, the apple 196 px across in each (nothing
# round it).
CELL, GRID, SHEETS = 256, 4, 4
FRAMES = GRID * GRID * SHEETS
APPLE_PX = 98.0  # its half width in a cell
SUPER = 2  # (painted at twice the size, then halved)

# The hand's picture and where the apple lies in it (ui/apple_hand.py).
HAND_SCALE, HW, HH, HELD, H = ah.HAND_SCALE, ah.HW, ah.HH, ah.HELD, ah.H

LIGHT = np.array([-0.72, -0.58, -0.38])  # toward the light: up, left and toward us (x right, y down, z away)
LIGHT = LIGHT / np.linalg.norm(LIGHT)

APPLE_RED = np.array([0.93, 0.07, 0.11], np.float32)
APPLE_SHADE = np.array([0.46, 0.012, 0.055], np.float32)


# The apple ------------------------------------------------------------------------------------------------------------

def rotation(axis, angle):
    """The matrix turning by `angle` (radians) about `axis` (Rodrigues)."""
    a = np.asarray(axis, np.float64)
    a = a / np.linalg.norm(a)
    k = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + math.sin(angle) * k + (1 - math.cos(angle)) * (k @ k)


def turned_to(stem):
    """A turn taking the apple's own stem axis (+z) to `stem`."""
    s = np.asarray(stem, np.float64)
    s = s / np.linalg.norm(s)
    z = np.array([0.0, 0.0, 1.0])
    axis = np.cross(z, s)
    if np.linalg.norm(axis) < 1e-9:
        return np.eye(3)
    return rotation(axis, math.acos(np.clip(z @ s, -1, 1)))


# How it lies in the hand (the stem up, leaning right and toward us, as the sketch has it); how it tumbles as it falls.
HELD_TURN = turned_to((0.33, -0.82, -0.47)) @ rotation((0, 0, 1), 0.6)
TUMBLE = (1.0, 0.45, 0.35)


def frame_turn(k):
    return rotation(TUMBLE, 2 * math.pi * k / FRAMES) @ HELD_TURN


def apple_shape(q):
    """The apple's surface, roughly a signed distance (negative inside), at points `q` in its own frame (stem +z),
    its half width 1: an apple's shoulders, the hollow at its stem, the dimple underneath."""
    r = np.sqrt((q * q).sum(-1)) + 1e-9
    theta = np.arccos(np.clip(q[..., 2] / r, -1, 1))
    rho = 1.0 + 0.06 * np.sin(theta) ** 2 + 0.07 * np.cos(theta)
    rho -= 0.3 * np.exp(-((theta / 0.4) ** 2)) + 0.08 * np.exp(-(((math.pi - theta) / 0.5) ** 2))
    return (r - rho * 0.94) * 0.8


STEM = ((0.0, 0.0, 0.55), (0.06, 0.03, 0.93), (0.2, 0.05, 1.12))  # its root, bend and tip (own frame)


def stem_shape(q):
    a, b, c = (np.array(p) for p in STEM)
    best = np.full(q.shape[:-1], 9.0)
    for p0, p1, w0, w1 in ((a, b, 0.055, 0.047), (b, c, 0.047, 0.035)):
        d = p1 - p0
        t = np.clip(((q - p0) @ d) / (d @ d), 0, 1)
        dist = np.sqrt((((q - p0) - t[..., None] * d) ** 2).sum(-1)) - (w0 + (w1 - w0) * t)
        best = np.minimum(best, dist)
    return best


def render_apple(turn, half_px, size, body_only=False):
    """The apple (RGBA, `size` square) with its half width `half_px`, turned by `turn`; or with `body_only`, just
    where it is (0..1)."""
    n = size * SUPER
    half = half_px * SUPER
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float64)
    x = (xs + 0.5 - n / 2) / half
    y = (ys + 0.5 - n / 2) / half
    inside = x * x + y * y < 1.6
    px, py = x[inside], y[inside]
    m = turn.T  # world to its own frame

    def field(p):
        q = p @ m.T
        return np.minimum(apple_shape(q), stem_shape(q))

    # March from in front (z = -1.5) back until inside, then halve the step to the surface.
    steps = 120
    zs = np.linspace(-1.5, 1.5, steps)
    hit = np.full(px.shape, np.nan)
    for z in zs:
        f = field(np.stack([px, py, np.full(px.shape, z)], -1))
        hit[np.isnan(hit) & (f < 0)] = z
    got = ~np.isnan(hit)
    lo = hit[got] - (zs[1] - zs[0])
    hi = hit[got].copy()
    gx, gy = px[got], py[got]
    for _ in range(14):
        mid = (lo + hi) / 2
        f = field(np.stack([gx, gy, mid], -1))
        hi = np.where(f < 0, mid, hi)
        lo = np.where(f < 0, lo, mid)
    p = np.stack([gx, gy, hi], -1)
    eps = 2e-3
    grad = np.stack([field(p + np.array([eps, 0, 0])) - field(p - np.array([eps, 0, 0])),
                     field(p + np.array([0, eps, 0])) - field(p - np.array([0, eps, 0])),
                     field(p + np.array([0, 0, eps])) - field(p - np.array([0, 0, eps]))], -1)
    nrm = grad / (np.linalg.norm(grad, axis=-1, keepdims=True) + 1e-12)
    q = p @ m.T
    is_stem = stem_shape(q) < apple_shape(q)
    r = np.linalg.norm(q, axis=-1) + 1e-9
    theta = np.arccos(np.clip(q[:, 2] / r, -1, 1))
    phi = np.arctan2(q[:, 1], q[:, 0])
    view = np.array([0.0, 0.0, -1.0])
    ndl = nrm @ LIGHT
    ndv = np.clip(nrm @ view, 0, 1)  # (how much it faces us: 1 head on, 0 at the outline)
    # A lit face and a shade with a crisp edge between (soft enough not to stair), the shade deepest away from the
    # light, the light's own warmth on the lit face.
    lit = pt.smoothstep(-0.06, 0.07, ndl)
    col = APPLE_SHADE[None] * (1 - lit[:, None]) + APPLE_RED[None] * lit[:, None]
    col *= (0.86 + 0.18 * np.clip(ndl, 0, 1))[:, None]
    col *= (1 - 0.35 * pt.smoothstep(0.0, -0.7, ndl))[:, None]
    # Its skin: faint streaks down from the stem, darker in the hollow and the dimple, a yellow blush near the stem.
    streak = 0.5 + 0.5 * np.sin(phi * 31 + 1.6 * np.sin(phi * 7 + theta * 4))
    col *= (1 - 0.05 * streak * pt.smoothstep(0.3, 1.0, theta) * (1 - pt.smoothstep(2.2, 2.8, theta)))[:, None]
    col *= (1 - 0.55 * np.exp(-((theta / 0.36) ** 2)))[:, None]
    col *= (1 - 0.3 * np.exp(-(((math.pi - theta) / 0.3) ** 2)))[:, None]
    col += (np.exp(-((theta / 0.5) ** 2)) * 0.12)[:, None] * np.array([0.5, 0.35, 0.0])
    # (the hollow the stem grows from and the dimple underneath: no rim light or glint in them, or they ring)
    hollows = np.maximum(np.exp(-((theta / 0.5) ** 2)), np.exp(-(((math.pi - theta) / 0.55) ** 2)))
    # The calyx in the dimple: the dried star of the flower it grew from, small and dark.
    bottom = math.pi - theta
    star = 0.1 * (0.62 + 0.38 * np.abs(np.cos(2.5 * phi)))
    calyx = 1 - pt.smoothstep(star * 0.85, star * 1.1, bottom)
    col = col * (1 - 0.85 * calyx[:, None]) + np.array([0.2, 0.09, 0.05]) * 0.85 * calyx[:, None]
    # A lighter rim where it turns away (the dark beyond lights it red), and along the lit edge a pale band.
    edge = (1 - ndv) ** 3 * (1 - hollows)
    col += (edge * pt.smoothstep(0.1, 0.7, nrm[:, 0]) * 0.5)[:, None] * np.array([0.6, 0.06, 0.08])
    col += (edge * lit * 0.5)[:, None] * np.array([0.5, 0.25, 0.27])
    # The glints, small and sharp as your frames have them: one up on the left, a thin crescent of light along the
    # lit edge, a pin of light low on the right; a soft sheen round the first.
    half_vec = LIGHT + np.array([0.0, 0.0, -1.0])
    half_vec /= np.linalg.norm(half_vec)
    ndh = np.clip(nrm @ half_vec, 0, 1)
    off = nrm - half_vec[None]
    along = np.array([0.72, -0.69, 0.0])
    across_ = np.cross(half_vec, along)
    across_ /= np.linalg.norm(across_)
    streak_d = (off @ along / 0.3) ** 2 + (off @ across_ / 0.1) ** 2
    sharp = 1 - pt.smoothstep(0.75, 1.0, streak_d)
    rim_band = pt.smoothstep(0.5, 0.58, 1 - ndv) * (1 - pt.smoothstep(0.76, 0.84, 1 - ndv))
    crescent = rim_band * pt.smoothstep(0.62, 0.8, ndl) * (1 - hollows)
    second = np.array([0.6, 0.5, -0.62])
    second /= np.linalg.norm(second)
    half2 = second + np.array([0.0, 0.0, -1.0])
    half2 /= np.linalg.norm(half2)
    small = pt.smoothstep(0.991, 0.995, np.clip(nrm @ half2, 0, 1))
    small *= 1 - pt.smoothstep(0.05, 0.3, hollows)
    sharp_cut = 1 - pt.smoothstep(0.05, 0.3, hollows)
    col += (ndh ** 30 * 0.25 * (1 - hollows))[:, None] * np.array([1.0, 0.8, 0.8])
    col = col * (1 - 0.75 * crescent[:, None]) + np.array([1.0, 0.82, 0.82]) * 0.75 * crescent[:, None]
    sharp = sharp * sharp_cut
    col = col * (1 - sharp[:, None]) + np.array([1.0, 0.97, 0.96]) * sharp[:, None]
    col = col * (1 - 0.85 * small[:, None]) + np.array([1.0, 0.88, 0.88]) * 0.85 * small[:, None]
    # The stem: dark brown wood, its lit side a little paler.
    wood = np.array([0.16, 0.09, 0.045]) * (0.8 + 0.9 * np.clip(ndl, 0, 1))[:, None]
    col = np.where(is_stem[:, None], wood, col)
    rgb = np.zeros((n, n, 3), np.float32)
    alpha = np.zeros((n, n), np.float32)
    idx = np.flatnonzero(inside.ravel())[got]
    rgb.reshape(-1, 3)[idx] = col
    alpha.reshape(-1)[idx] = 1.0
    # (halved: four samples a pixel)
    rgb = rgb.reshape(size, SUPER, size, SUPER, 3).mean((1, 3))
    alpha = alpha.reshape(size, SUPER, size, SUPER).mean((1, 3))
    if body_only:
        return alpha
    rgb = rgb / np.maximum(alpha, 1e-6)[..., None]
    out_rgb, out_a = rgb, alpha
    return np.concatenate([out_rgb, out_a[..., None]], -1).astype(np.float32)


def apple_sheets():
    """The four sheets of the apple's turns, 16 to a sheet, in order."""
    sheets = []
    for index in range(SHEETS):
        sheet = np.zeros((CELL * GRID, CELL * GRID, 4), np.float32)
        for k in range(GRID * GRID):
            cell = render_apple(frame_turn(index * GRID * GRID + k), APPLE_PX, CELL)
            row, col = divmod(k, GRID)
            sheet[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL] = cell
        print("[apple] sheet", index + 1)
        sheets.append(sheet)
    return sheets


def apple_cell(sheets, k):
    """The apple's k-th turn (RGBA)."""
    index, k = divmod(k % FRAMES, GRID * GRID)
    row, col = divmod(k, GRID)
    return sheets[index][row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL]


# The hand -------------------------------------------------------------------------------------------------------------

def apple_in_hand():
    """Where the falling apple lies once caught (its first turn), in the hand's picture (0..1): the apple's cell drawn
    at the hand's scale over the caught spot, exactly as the game lays the two."""
    cell = render_apple(frame_turn(0), APPLE_PX, CELL, body_only=True)
    size = CELL * HELD[2] * HAND_SCALE / APPLE_PX
    big = flow.resample(cell.astype(np.float32), int(round(size)), int(round(size)))
    out = np.zeros((HH, HW), np.float32)
    cx, cy = H(HELD[0], HELD[1])
    x0, y0 = int(round(cx - big.shape[1] / 2)), int(round(cy - big.shape[0] / 2))
    xa, ya = max(0, x0), max(0, y0)
    xb, yb = min(HW, x0 + big.shape[1]), min(HH, y0 + big.shape[0])
    out[ya:yb, xa:xb] = big[ya - y0: yb - y0, xa - x0: xb - x0]
    return out


# The screen -----------------------------------------------------------------------------------------------------------

def layout():
    """How the pictures sit on a screen 1 high: the hand's picture height, where the apple is caught in it, the apple's
    cell size beside the hand's, and the thumb's square (its middle in the hand's picture, its side beside the hand's
    height)."""
    apple_w = 2 * HELD[2] * HAND_SCALE  # the held apple's width in the hand's px
    hand_h = APPLE_ON_SCREEN * HH / apple_w
    cell = CELL * apple_w / (2 * APPLE_PX) / HH  # a cell's size, a share of the hand's height
    cx, cy = H(HELD[0], HELD[1])
    px, py, half = ah.thumb_square()
    return hand_h, (cx / HW, cy / HH), cell, (px / HW, py / HH), 2 * half / HH


def over_rgba(canvas, img, x0, y0):
    """`img` (RGBA) laid on `canvas` (RGB) with its top left at (x0, y0), clipped."""
    h, w = img.shape[:2]
    ch, cw = canvas.shape[:2]
    xa, ya = max(0, int(x0)), max(0, int(y0))
    xb, yb = min(cw, int(x0) + w), min(ch, int(y0) + h)
    if xb <= xa or yb <= ya:
        return
    part = img[ya - int(y0): yb - int(y0), xa - int(x0): xb - int(x0)]
    pt.over(canvas[ya:yb, xa:xb], part[..., :3], part[..., 3])


def resized(img, scale):
    h, w = img.shape[:2]
    return flow.resample(img, max(1, int(round(h * scale))), max(1, int(round(w * scale))))


def preview(sheets, back, front, thumb):
    """Your sketch's moments at 16:9, as the game lays them: the apple falling, the hand coming up for it with the thumb
    up, the thumb half way down over the caught apple, the catch; and the first sheet of its turns."""
    sh, sw = 540, 960
    hand_h, catch, cell, pivot, thumb_side = layout()
    hand_px = hand_h * sh
    cell_px = cell * hand_px
    cx, cy = sw * CATCH[0], sh * CATCH[1]

    def apple_at(canvas, k, y):
        apple = resized(apple_cell(sheets, k), cell_px / CELL)
        over_rgba(canvas, apple, cx - apple.shape[1] / 2, y - apple.shape[0] / 2)

    def hand_at(canvas, degrees, lift, apple_k=None, apple_y=None):
        scale = hand_px / HH
        left, top = cx - catch[0] * HW * scale + lift * 0.3, cy - catch[1] * HH * scale + lift
        over_rgba(canvas, resized(back, scale), left, top)
        if apple_k is not None:
            apple_at(canvas, apple_k, apple_y)
        over_rgba(canvas, resized(front, scale), left, top)
        turned = resized(ah.thumb_at(thumb, degrees), scale)
        over_rgba(canvas, turned, left + pivot[0] * HW * scale - turned.shape[1] / 2,
                  top + pivot[1] * HH * scale - turned.shape[0] / 2)

    fall = np.zeros((sh, sw, 3), np.float32)
    apple_at(fall, 22, sh * 0.42)
    coming = np.zeros((sh, sw, 3), np.float32)
    hand_at(coming, ah.OPEN_THUMB, sh * 0.1, 54, sh * 0.62)
    closing = np.zeros((sh, sw, 3), np.float32)
    hand_at(closing, ah.OPEN_THUMB * 0.45, 0, 0, cy)
    caught = np.zeros((sh, sw, 3), np.float32)
    hand_at(caught, 0.0, 0, 0, cy)
    top_row = np.concatenate([fall, coming], 1)
    bottom_row = np.concatenate([closing, caught], 1)
    turns = np.zeros((sh, sw * 2, 3), np.float32)
    flat = sheets[0][..., :3] * sheets[0][..., 3:]
    small = resized(flat, sh / flat.shape[0])
    turns[:, : small.shape[1]] = small
    return np.concatenate([top_row, bottom_row, turns], 0)


def main():
    os.makedirs(OUT, exist_ok=True)
    if "--hand" in sys.argv:
        # (the hand alone: the apple's sheets as they are on disk, untouched)
        sheets = [png.read(os.path.join(OUT, f"AppleSpin{index + 1}.png")).astype(np.float32) / 255.0
                  for index in range(SHEETS)]
    else:
        sheets = apple_sheets()
        for index, sheet in enumerate(sheets):
            png.write(os.path.join(OUT, f"AppleSpin{index + 1}.png"), sheet)
    back, front, thumb = ah.back(), ah.front(), ah.thumb()
    png.write(os.path.join(OUT, "AppleHandBack.png"), back)
    png.write(os.path.join(OUT, "AppleHandFront.png"), front)
    png.write(os.path.join(OUT, "AppleThumb.png"), thumb)
    png.write(PREVIEW, preview(sheets, back, front, thumb))
    print("[apple] wrote", PREVIEW)
    hand_h, catch, cell, pivot, thumb_side = layout()
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/ui/intro_frames.py. Do not edit by hand.",
        "-- The apple loading screen's pictures (UI/AppleLoading): the hand's pictures (AppleHandBack, AppleHandFront),",
        "-- their height a share of the screen's and their width beside their height; where the apple is caught in them",
        "-- (a share of their width and height from the top left); a cell of the turning apple (AppleSpin1..sheets,",
        "-- `frames` cells to a turn), its size a share of the hand's height; the thumb's square (AppleThumb), its middle",
        "-- (the thumb's root) in the hand's picture, its side a share of the hand's height, and how far it stands up",
        "-- (degrees) while the hand waits.",
        "",
        "return {",
        f"\thandHeight = {hand_h:.4f},",
        f"\thandAspect = {HW / HH:.4f},",
        f"\tcatch = Vector2.new({catch[0]:.4f}, {catch[1]:.4f}),",
        f"\tappleCell = {cell:.4f},",
        f"\tcell = {CELL},",
        f"\tgrid = {GRID},",
        f"\tsheets = {SHEETS},",
        f"\tframes = {FRAMES},",
        f"\tthumbPivot = Vector2.new({pivot[0]:.4f}, {pivot[1]:.4f}),",
        f"\tthumbSize = {thumb_side:.4f},",
        f"\tthumbOpen = {ah.OPEN_THUMB:.1f},",
        "}",
    ]
    with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("[apple] wrote", LUAU)


if __name__ == "__main__":
    main()
