"""The apple loading screen (UI/AppleLoading), painted after your pencil sketch (art/refs/ui/apple_sketch.png,
2026-10-27): a red apple turning as it falls through the dark, then caught in a hand rising from the lower left, the
thumb closing over it; coloured like your two frames (a glossy red apple, a pale hand, black).

The apple is modelled (an apple's shape: shoulders, the hollow its stem grows from, the dimple underneath), lit from
the upper left as your sketch lights it and shaded as an anime frame lays it (a lit face and a crisp shade, long sharp
white glints, a lighter rim; no glow round it), so every turn of it is the same apple and the one that lands in the
hand is the one that fell. The hand is your drawing's: its outline taken from the sketch, the shade you hatched on it,
painted pale with a light outline and the apple's red light on the side that faces it, out of a dark jacket sleeve
drawn on your sketch's lines (its opening, the lit top, soft folds) with the white shirt cuff showing past it.

    AppleSpin      1024 x 1024  a 4 x 4 sheet of the apple turning (transparent); its first cell is how it lies in the
                                hand, and the game brings the turn round to it as the hand catches it
    AppleHand1, 2  1024 x 736   the hand, waiting with its thumb up, then with the thumb closed over the apple
                                (transparent; the apple is not in them: the falling one stops in the hand, which is
                                laid over it, palm and fingers in front, with the shade they cast on it)
    AppleClose1..4 1024 x 736   the thumb on its way down over the caught apple, between the two (2026-10-28: the
                                hand swapped straight from waiting to holding, a pop), the game stepping through them

Also writes src/client/UI/LoadingArt.luau (how the hand's picture and the apple's cells sit on the screen, so the
falling apple lands exactly in the hand) and a preview, art/export/previews/apple_loading.png (the fall and the catch,
as the game lays them).

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/ui/intro_frames.py
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

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

# The sheet: 16 turns of the apple, 256 px cells, the apple 196 px across in each (nothing round it).
CELL, GRID = 256, 4
APPLE_PX = 98.0  # its half width in a cell
SUPER = 2  # (painted at twice the size, then halved)

# The hand's picture: the sketch's own px, from HAND_BOX (x0, y0, x1, y1), at HAND_SCALE (to 1024 x 736). The sleeve
# runs on past the sketch's edge, so the hand can rise from below the screen.
HAND_BOX = (400, 545, 1010, 983)
HAND_SCALE = 1024 / 610
HW, HH = 1024, 736

# Measured on the sketch (its px, 1681 x 936): the apple in the hand, its stem at the top right; the thumb over its
# front; the finger round its right side; the palm's lip in front of its foot; the cuff.
HELD = (845.0, 652.0, 105.0, 91.0)  # middle, half width, half height
THUMB = [(655, 712), (700, 690), (740, 675), (800, 647), (830, 635), (845, 634), (853, 641), (850, 650), (835, 657),
         (810, 672), (785, 690), (765, 705), (750, 725), (740, 738), (700, 748)]
THUMB_PIVOT = (700.0, 735.0)  # where the thumb turns at its root
FINGER = [(945, 655), (950, 640), (958, 638), (965, 648), (962, 668), (957, 692), (950, 716), (940, 740), (920, 765),
          (895, 780), (868, 790), (860, 752), (885, 742), (905, 728), (920, 712), (932, 692), (940, 672)]
PALM_LIP = [(750, 722), (782, 733), (820, 745), (850, 750), (880, 744), (905, 730), (922, 714), (945, 690),
            (960, 760), (900, 800), (720, 800)]
# The curled fingers' underside, hatched as dark as the dark round it, between the finger and the hand's lower edge.
UNDERSIDE = [(860, 752), (905, 740), (935, 712), (950, 690), (960, 700), (957, 730), (945, 752), (925, 778),
             (900, 795), (870, 812), (840, 826), (820, 832), (800, 800)]
THUMB_ROOT = [(640, 745), (700, 700), (745, 690), (762, 740), (700, 762), (640, 792)]  # (in both poses)
# The inside of the cupped palm, between the thumb's root and the finger, above the palm's lip: the apple lies in it
# (holding, it shows round the apple; waiting, it is the open palm).
CUP = [(742, 705), (760, 694), (800, 687), (850, 685), (900, 679), (930, 669), (942, 667), (950, 698), (928, 722),
       (910, 738), (882, 752), (850, 758), (818, 753), (780, 741), (748, 730)]  # (its foot under the lip's edge)
# (waiting, the web between the stood-up thumb and the hand, and everything above the palm where the apple will lie)
WEB = [(705, 695), (735, 672), (750, 690), (755, 712), (720, 715)]
WEB_CAUGHT = [(700, 660), (800, 660), (800, 770), (700, 770)]  # (the apple's lower left, where the web meets it)
# (below the wrist's underside, where your sketch's hatching runs on into the dark)
BELOW_WRIST = [(575, 940), (620, 893), (700, 863), (760, 855), (800, 1000), (560, 1000)]
ABOVE_PALM = [(740, 560), (970, 560), (945, 690), (922, 714), (905, 730), (880, 744), (850, 750), (820, 745),
              (782, 733), (750, 722), (735, 700)]
# The cuff's line across the forearm; the white shirt cuff just past it, the dark jacket sleeve beyond, to the frame.
# The jacket sleeve, as your sketch draws it: its opening runs down from the step in the forearm's top edge, a little
# wider than the wrist; the white shirt cuff shows just past it; the sleeve carries on past the sketch's edge.
SLEEVE_END = [(541, 848), (557, 877), (570, 903), (584, 932)]
SLEEVE = [(541, 848), (557, 877), (570, 903), (584, 932), (560, 962), (534, 995), (378, 995), (400, 972), (428, 945),
          (453, 921), (478, 900), (503, 880), (527, 862)]
CUFF_WIDTH = 15
THUMB_LINE = [(850, 650), (835, 657), (810, 672), (785, 690), (765, 705), (750, 725), (742, 737)]  # its underside
OPEN_THUMB = -38.0  # degrees the thumb stands up, waiting
CLOSING = (0.8, 0.58, 0.36, 0.16)  # the thumb's way down over the caught apple (AppleClose1..4), shares of OPEN_THUMB

LIGHT = np.array([-0.72, -0.58, -0.38])  # toward the light: up, left and toward us (x right, y down, z away)
LIGHT = LIGHT / np.linalg.norm(LIGHT)

APPLE_RED = np.array([0.93, 0.07, 0.11], np.float32)
APPLE_SHADE = np.array([0.46, 0.012, 0.055], np.float32)
SKIN = np.array([0.86, 0.85, 0.87], np.float32)
SKIN_SHADE = np.array([0.6, 0.585, 0.615], np.float32)
LINE = (0.2, 0.19, 0.21)


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
    return rotation(TUMBLE, 2 * math.pi * k / (GRID * GRID)) @ HELD_TURN


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


def apple_sheet():
    sheet = np.zeros((CELL * GRID, CELL * GRID, 4), np.float32)
    for k in range(GRID * GRID):
        cell = render_apple(frame_turn(k), APPLE_PX, CELL)
        row, col = divmod(k, GRID)
        sheet[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL] = cell
        print("[apple] turn", k + 1)
    return sheet


# The hand -------------------------------------------------------------------------------------------------------------

def H(x, y):
    """Sketch px to the hand picture's px."""
    return ((x - HAND_BOX[0]) * HAND_SCALE, (y - HAND_BOX[1]) * HAND_SCALE)


def hfill(points):
    return pt.fill([H(x, y) for x, y in points], HW, HH)


def hstroke(points, widths):
    if np.isscalar(widths):
        widths = [widths] * len(points)
    return pt.fill(pt.outline([H(x, y) for x, y in points], [w * HAND_SCALE for w in widths]), HW, HH)


def hgrid():
    ys, xs = pt.grid(HH, HW)
    return xs / HAND_SCALE + HAND_BOX[0], ys / HAND_SCALE + HAND_BOX[1]


def sketch_in_hand():
    """The sketch's lightness laid over the hand's picture (sketch px past its bottom edge carry its last row)."""
    lum = png.read(SKETCH)[..., 0].astype(np.float32) / 255.0
    x, y = hgrid()
    xi = np.clip(x, 0, lum.shape[1] - 1.001)
    yi = np.clip(y, 0, lum.shape[0] - 1.001)
    x0, y0 = xi.astype(int), yi.astype(int)
    fx, fy = xi - x0, yi - y0
    a = lum[y0, x0] * (1 - fx) + lum[y0, x0 + 1] * fx
    b = lum[y0 + 1, x0] * (1 - fx) + lum[y0 + 1, x0 + 1] * fx
    return (a * (1 - fy) + b * fy).astype(np.float32)


def held_apple(grow=0.0):
    cx, cy, rx, ry = HELD
    ex, ey = H(cx, cy)
    return pt.ellipse(ex, ey, (rx + grow) * HAND_SCALE, (ry + grow) * HAND_SCALE, HW, HH)


def turned(points, degrees, pivot=THUMB_PIVOT):
    """Sketch points turned by `degrees` about `pivot` (on screen, y down: negative stands the thumb up)."""
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    return [(pivot[0] + (x - pivot[0]) * c - (y - pivot[1]) * s, pivot[1] + (x - pivot[0]) * s + (y - pivot[1]) * c)
            for x, y in points]


def turn_field(field, mask, degrees):
    """`field` inside `mask` turned by `degrees` about the thumb's root (picture px), bilinear."""
    ys, xs = pt.grid(HH, HW)
    px, py = H(*THUMB_PIVOT)
    a = math.radians(-degrees)
    c, s = math.cos(a), math.sin(a)
    sx = np.clip(px + (xs - px) * c - (ys - py) * s - 0.5, 0, HW - 1.001)
    sy = np.clip(py + (xs - px) * s + (ys - py) * c - 0.5, 0, HH - 1.001)
    x0, y0 = sx.astype(int), sy.astype(int)
    fx, fy = sx - x0, sy - y0

    def at(img):
        top = img[y0, x0] * (1 - fx) + img[y0, x0 + 1] * fx
        return top * (1 - fy) + (img[y0 + 1, x0] * (1 - fx) + img[y0 + 1, x0 + 1] * fx) * fy

    m = at(mask)
    return at(field * mask) / np.maximum(m, 1e-6)


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


def hand_shape(lum, degrees, apple=None):
    """The hand's outline (0..1) with its thumb turned `degrees`: the light the sketch leaves against its dark (its
    hatched shade closed in, its ragged pencil edge smoothed, stray marks dropped); over the apple, only the thumb,
    the finger and the palm's lip (and, holding it, the palm right round its foot); the sleeve as drawn, run on below
    the sketch's edge."""
    x, y = hgrid()
    light = (pt.blur(lum, 5.0 * HAND_SCALE) > 0.5) & (y < 934)
    shape = np.maximum(light.astype(np.float32), hfill(SLEEVE))
    # (holes inside it, where the sketch hatches its shade darker, are hand too)
    seeds = np.zeros((HH, HW), bool)
    seeds[:4, :] = True
    seeds[:, -4:] = True
    seeds[:, :4] = True
    shape = (~flow.joined(shape < 0.5, seeds, limit=3000)).astype(np.float32)
    # The apple (a little wider than drawn, so none of its outline is taken for hand) and the drawn thumb go; the
    # posed thumb, its root, the finger and the palm's lip come in.
    shape *= 1 - held_apple(grow=9)
    shape *= 1 - hfill(THUMB)
    shape *= 1 - hfill(ABOVE_PALM)
    shape *= 1 - hfill(BELOW_WRIST)
    front = [hfill(turned(THUMB, degrees)), hfill(THUMB_ROOT), hfill(FINGER), hfill(UNDERSIDE), hfill(PALM_LIP),
             hfill(SLEEVE)]
    over_apple = 1 - pt.smoothstep(0.3, 0.7, apple) if apple is not None else 1.0
    if degrees:
        # (the web between the thumb and the hand, turning down with it; never over a caught apple)
        front.append(hfill(turned(WEB, degrees - OPEN_THUMB)) * over_apple)
    if apple is not None:
        # (holding: the palm reaches right round the apple's foot, so no gap shows between them)
        front.append(hfill(CUP) * over_apple)
        if degrees:
            # (and while the thumb is still coming down, the skin between it and the palm meets the apple's side)
            front.append(held_apple(grow=12) * hfill(WEB_CAUGHT) * over_apple)
    shape = np.maximum.reduce([shape] + front)
    # (slits closed; thin bits the pencil left go, and anything not joined to the wrist; the edge smoothed)
    shape = flow.shrink(flow.grow(shape, 3), 3)
    body = flow.grow(flow.shrink(shape, 4), 4)
    body = np.maximum.reduce([body] + front)
    wrist = hfill([(600, 820), (640, 820), (640, 860), (600, 860)]) > 0.5
    kept = flow.joined(body > 0.5, wrist & (body > 0.5), limit=3000)
    return pt.smoothstep(0.4, 0.6, pt.blur(kept.astype(np.float32), 2.4))


def paint_hand(lum, shape, degrees):
    """The hand painted (RGB) with its thumb turned `degrees`: pale skin lit from the upper left, the shade you
    hatched on it as a crisp darker tone, the apple's red light on what faces it, its lines, the nails, the white cuff
    and the dark sleeve."""
    x, y = hgrid()
    if degrees:
        # (the sketch's shading on the thumb goes where the thumb goes)
        posed = hfill(turned(THUMB, degrees))
        lum = lum * (1 - posed) + turn_field(lum, hfill(THUMB), degrees) * posed
    tone = 0.93 + 0.07 * pt.smoothstep(880, 650, y)
    rgb = SKIN[None, None] * tone[..., None]
    # Your hatching, smoothed, read as shade: where you drew it dense it falls into the darker tone, crisp-edged.
    hatch = pt.blur(lum, 10 * HAND_SCALE)
    shade = pt.smoothstep(0.72, 0.67, hatch) * shape
    soft = pt.blur(shade, 1.2 * HAND_SCALE)
    rgb = rgb * (1 - soft[..., None]) + SKIN_SHADE[None, None] * soft[..., None]
    # The thumb's underside, turned to the apple, in shade; the apple's red light faintly on what is near it.
    under = pt.blur(hfill(turned(THUMB[8:] + [(770, 694), (825, 662)], degrees)), 1.6 * HAND_SCALE)
    rgb = rgb * (1 - under[..., None]) + SKIN_SHADE[None, None] * under[..., None]
    cx, cy, rx, _ = HELD
    near = np.exp(-(((x - cx) ** 2 + (y - cy) ** 2) / (rx * 1.15) ** 2)) * (0.5 + 0.5 * soft)
    rgb += (near * 0.1)[..., None] * np.array([0.5, 0.0, 0.02])
    rgb[..., 1:] *= (1 - 0.09 * near)[..., None]
    # A light along the back of the hand and the thumb's top, where the light from the upper left falls.
    top = np.clip(shape - shifted(shape, int(-5 * HAND_SCALE), int(7 * HAND_SCALE)), 0, 1)
    rgb += (0.06 * pt.blur(top, 1.0))[..., None]
    # The nails: the thumb's (turned with it) and the finger's, paler with a rim.
    nails = [(turned([(842, 640)], degrees)[0], -0.45 + math.radians(degrees)), ((959, 647), 1.3)]
    for (nx, ny), ang in nails:
        cxp, cyp = H(nx, ny)
        nail = pt.ellipse(cxp, cyp, 9 * HAND_SCALE, 5.5 * HAND_SCALE, HW, HH, angle=ang)
        pt.over(rgb, (0.96, 0.94, 0.95), pt.blur(nail, 0.8) * 0.85)
        ring = np.clip(nail - pt.ellipse(cxp, cyp, 7.3 * HAND_SCALE, 3.9 * HAND_SCALE, HW, HH, angle=ang), 0, 1)
        pt.over(rgb, LINE, ring * 0.5)
    # The jacket sleeve: near black, the light along its top, two soft folds across it, the hem of its opening
    # catching the light; past it the white shirt cuff, shaded underneath.
    sleeve = hfill(SLEEVE) * shape
    pt.over(rgb, (0.075, 0.075, 0.088), sleeve)
    (ax, ay), (bx, by) = SLEEVE_END[0], SLEEVE_END[-1]
    run = np.array([bx - ax, by - ay], np.float64)
    run /= np.linalg.norm(run)
    across = np.array([run[1], -run[0]])  # (along the arm, toward the hand)
    back = (x - ax) * across[0] + (y - ay) * across[1]  # (how far from the opening, toward the hand; negative up it)
    side = (x - ax) * run[0] + (y - ay) * run[1]  # (along the opening, from its top)
    lit = sleeve * (1 - pt.smoothstep(4, 22, side + 0.18 * back))
    pt.over(rgb, (0.24, 0.24, 0.27), pt.blur(lit, 2.0 * HAND_SCALE) * 0.8)
    for fold in (-30.0, -62.0):
        crease = np.exp(-(((back - fold - 0.25 * side) / 5.0) ** 2)) * sleeve
        pt.over(rgb, (0.17, 0.17, 0.2), crease * 0.6)
        pt.over(rgb, (0.03, 0.03, 0.035), np.exp(-(((back - fold - 0.25 * side + 6) / 3.0) ** 2)) * sleeve * 0.6)
    hem = np.exp(-(((back + 3.0) / 2.2) ** 2)) * sleeve
    pt.over(rgb, (0.32, 0.32, 0.36), hem * 0.8)
    cuff = pt.smoothstep(-0.5, 0.5, back) * (1 - pt.smoothstep(CUFF_WIDTH - 0.5, CUFF_WIDTH + 0.5, back)) * shape
    cuff_tone = 0.94 - 0.24 * pt.smoothstep(25, 80, side)
    pt.over(rgb, np.stack([cuff_tone, cuff_tone, cuff_tone * 1.02], -1), pt.blur(cuff, 0.6))
    pt.over(rgb, (0.55, 0.55, 0.6), np.exp(-(((back - CUFF_WIDTH) / 1.2) ** 2)) * shape * 0.6)
    # Its lines: the outline, thin and light on the lit side, a little darker where it turns from the light; the
    # thumb's underside (turned with it).
    soft_shape = pt.blur(shape, 2.0 * HAND_SCALE)
    gy, gx = np.gradient(soft_shape)
    norm = np.sqrt(gx * gx + gy * gy) + 1e-6
    away = np.clip(-gy / norm, 0, 1)  # (its outline facing down, away from the light)
    rim = np.clip(shape - flow.shrink(shape, 2), 0, 1)
    pt.over(rgb, LINE, rim * (0.3 + 0.35 * away))
    line = turned(THUMB_LINE, degrees)
    pt.over(rgb, LINE, pt.blur(hstroke(line, pt.taper(len(line), 1.8, 0.4, start=0.8)), 0.7) * shape * 0.45)
    return np.clip(rgb, 0, 1)


def shifted(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys = slice(max(dy, 0), h + min(dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = mask[yd, xd]
    return out


def hands():
    """The hand pictures (RGBA): waiting, the thumb up; the thumb on its way down over the caught apple (CLOSING);
    and holding, the thumb over the apple. Once the apple is in it, with the shade the hand casts on the apple's
    foot and, as it comes down, the thumb's on its front."""
    lum = sketch_in_hand()
    x, y = hgrid()
    pictures = []
    apple = apple_in_hand()
    for k, degrees in enumerate([OPEN_THUMB] + [OPEN_THUMB * c for c in CLOSING] + [0.0]):
        caught = k > 0
        shape = hand_shape(lum, degrees, apple if caught else None)
        rgb = paint_hand(lum, shape, degrees)
        alpha = shape
        if caught:
            # Over the apple (the falling one, under the picture) a little shade where it sits down in the palm and
            # where the thumb lies on it (nearer it, darker).
            cx, cy, rx, ry = HELD
            foot = pt.smoothstep(cy + 0.55 * ry, cy + 0.95 * ry, y)
            near = 1 - degrees / OPEN_THUMB
            drop = pt.blur(shifted(hfill(turned(THUMB, degrees)), int(6 * HAND_SCALE), int(8 * HAND_SCALE)),
                           (3 + 4 * (1 - near)) * HAND_SCALE)
            cast = np.clip(0.25 * foot + 0.25 * near * drop, 0, 0.35) * apple * (1 - shape)
            alpha = shape + cast * (1 - shape)
            rgb = rgb * (shape / np.maximum(alpha, 1e-6))[..., None]
        pictures.append(np.concatenate([rgb, alpha[..., None]], -1).astype(np.float32))
    return pictures[0], pictures[1:-1], pictures[-1]


# The screen -----------------------------------------------------------------------------------------------------------

def layout():
    """How the pictures sit on a screen 1 high: the hand's picture height, where the apple is caught in it, and the
    apple's cell size beside the hand's."""
    apple_w = 2 * HELD[2] * HAND_SCALE  # the held apple's width in the hand's px
    hand_h = APPLE_ON_SCREEN * HH / apple_w
    cell = CELL * apple_w / (2 * APPLE_PX) / HH  # a cell's size, a share of the hand's height
    cx, cy = H(HELD[0], HELD[1])
    return hand_h, (cx / HW, cy / HH), cell


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


def preview(sheet, waiting, closing, holding):
    """Your sketch's moments at 16:9, as the game lays them: the apple falling, the hand coming up for it, the catch;
    and the sheet of its turns."""
    sh, sw = 540, 960
    hand_h, catch, cell = layout()
    hand_px = hand_h * sh
    cell_px = cell * hand_px
    cx, cy = sw * CATCH[0], sh * CATCH[1]

    def apple_at(canvas, k, y):
        row, col = divmod(k, GRID)
        apple = resized(sheet[row * CELL:(row + 1) * CELL, col * CELL:(col + 1) * CELL], cell_px / CELL)
        over_rgba(canvas, apple, cx - apple.shape[1] / 2, y - apple.shape[0] / 2)

    def hand_at(canvas, pic, lift):
        pic = resized(pic, hand_px / HH)
        over_rgba(canvas, pic, cx - catch[0] * pic.shape[1] + lift * 0.3, cy - catch[1] * pic.shape[0] + lift)

    fall = np.zeros((sh, sw, 3), np.float32)
    apple_at(fall, 5, sh * 0.42)
    coming = np.zeros((sh, sw, 3), np.float32)
    apple_at(coming, 13, sh * 0.62)
    hand_at(coming, waiting, sh * 0.1)
    caught = np.zeros((sh, sw, 3), np.float32)
    apple_at(caught, 0, cy)
    hand_at(caught, holding, 0)
    turns = np.zeros((sh, sw, 3), np.float32)
    flat = sheet[..., :3] * sheet[..., 3:]
    small = resized(flat, sh / flat.shape[0])
    turns[:, : small.shape[1]] = small
    return np.concatenate([np.concatenate([fall, coming], 1), np.concatenate([caught, turns], 1)], 0)


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = apple_sheet()
    png.write(os.path.join(OUT, "AppleSpin.png"), sheet)
    waiting, closing, holding = hands()
    png.write(os.path.join(OUT, "AppleHand1.png"), waiting)
    png.write(os.path.join(OUT, "AppleHand2.png"), holding)
    for k, picture in enumerate(closing):
        png.write(os.path.join(OUT, f"AppleClose{k + 1}.png"), picture)
    png.write(PREVIEW, preview(sheet, waiting, closing, holding))
    print("[apple] wrote", PREVIEW)
    hand_h, catch, cell = layout()
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/ui/intro_frames.py. Do not edit by hand.",
        "-- The apple loading screen's pictures (UI/AppleLoading): the hand's picture (AppleHand1, 2), its height a share",
        "-- of the screen's and its width beside its height; where the apple is caught in it (a share of its width and",
        "-- height from the top left); a cell of the turning apple (AppleSpin), its size a share of the hand's height.",
        "",
        "return {",
        f"\thandHeight = {hand_h:.4f},",
        f"\thandAspect = {HW / HH:.4f},",
        f"\tcatch = Vector2.new({catch[0]:.4f}, {catch[1]:.4f}),",
        f"\tappleCell = {cell:.4f},",
        f"\tcell = {CELL},",
        f"\tgrid = {GRID},",
        "}",
    ]
    with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("[apple] wrote", LUAU)


if __name__ == "__main__":
    main()
