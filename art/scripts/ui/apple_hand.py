"""The hand that catches the apple on the loading screen (UI/AppleLoading), redrawn 2026-11-03 at your word ("make the
hand more high quality"). It was your pencil's light read as one flat shape, a thumb and a single prong; now it is built
of its parts on your sketch's lines (art/refs/ui/apple_sketch.png): the back of the hand and its side, the thumb laid
over the apple's front, the index finger round its right side with the middle and ring fingers' tips behind it, the palm
cupped under it. Each part is shaded as a rounded form under the light from the upper left that lights the apple (a lit
face, a crisp shade, a cool light round the shaded edge, the apple's red light on what faces it, a little sheen), inked
as an anime frame is (a heavier line where the form turns from the light), with the nails, the knuckles, the joints'
creases and the tendons along the back of the hand; out of the white shirt cuff and the dark jacket sleeve.

Three pictures, so the game closes the thumb smoothly (it turns the thumb's picture about its root) rather than in a
few steps, and the apple lands between them:

    AppleHandBack   the inside of the cupped palm, under the apple (seen while the hand waits)
    AppleHandFront  the hand over the apple: the back of the hand and its side, the palm's lip in front of the apple's
                    foot, the three fingers round its right side, the cuff and the sleeve
    AppleThumb      the thumb alone on a square whose middle is its root, laid over the apple with the shade it casts

Coordinates are your sketch's px (1681 x 936), laid on the hand's picture (1024 x 736) by H.
"""

import math
import os

import numpy as np

import flow
import paint as pt
import png

HERE = os.path.dirname(os.path.abspath(__file__))
SKETCH = os.path.normpath(os.path.join(HERE, "..", "..", "refs", "ui", "apple_sketch.png"))

HAND_BOX = (400, 545, 1010, 983)  # the sketch's px the hand's picture covers (x0, y0, x1, y1)
HAND_SCALE = 1024 / 610
HW, HH = 1024, 736

# Measured on your sketch: the apple in the hand (its middle, half width and half height).
HELD = (845.0, 652.0, 105.0, 91.0)

# The thumb, root to tip, along its middle, and its width there (broad at its root, where the ball of the thumb is);
# it turns where it leaves the hand's edge. The web of skin between it and the hand is drawn behind the apple, so it
# shows only while the thumb stands up (the apple covers it once caught).
THUMB_AXIS = [(712, 712), (735, 698), (757, 686), (777, 675), (797, 664), (817, 654), (835, 647), (849, 642)]
THUMB_WIDTHS = [48, 42, 37, 33, 30, 28, 26, 24]
WEB = [(733, 702), (747, 668), (764, 652), (772, 662), (766, 676), (778, 686), (790, 690), (776, 706), (752, 712)]
THUMB_PIVOT = (738.0, 694.0)
THUMB_FADE = (8.0, 20.0)  # sketch px from its root: gone inside the first, whole past the second
THUMB_BALL = 22.0  # the hand's own picture is skin this far round the thumb's root, so it turns over the hand
OPEN_THUMB = -38.0  # degrees the thumb stands up while the hand waits (the game turns it down as the apple lands)
# (where your pencil drew the thumb: the hand's own picture leaves it out)
SKETCH_THUMB = [(655, 712), (700, 690), (740, 675), (800, 647), (830, 635), (845, 634), (853, 641), (850, 650),
                (835, 657), (810, 672), (785, 690), (765, 705), (750, 725), (740, 738), (700, 748)]

# The fingers round the apple's right side, back to front (ring, middle, index), root to tip, and their widths.
FINGERS = [
    ([(926, 770), (940, 757), (950, 741), (956, 724), (959, 711)], [22, 21, 20, 19, 18]),
    ([(912, 741), (924, 732), (936, 718), (944, 703), (950, 685), (954, 668), (955, 656), (954, 647)],
     [25, 24, 23, 22, 21, 20.5, 20, 19.5]),
]

# Your sketch's hand, as the earlier painting measured it: the palm's lip in front of the apple's foot; the curled
# fingers' underside; the ball of the thumb; everything above the palm (where the apple lies); below the wrist.
PALM_LIP = [(750, 722), (782, 733), (820, 745), (850, 750), (880, 744), (905, 730), (922, 714), (945, 690),
            (960, 760), (900, 800), (720, 800)]
UNDERSIDE = [(860, 752), (905, 740), (935, 712), (950, 690), (960, 700), (957, 730), (945, 752), (925, 778),
             (900, 795), (870, 812), (840, 826), (820, 832), (800, 800)]
THUMB_ROOT = [(630, 740), (668, 712), (700, 690), (728, 680), (752, 681), (766, 700), (762, 740), (700, 762),
              (640, 792)]
ABOVE_PALM = [(740, 560), (970, 560), (945, 690), (922, 714), (905, 730), (880, 744), (850, 750), (820, 745),
              (782, 733), (750, 722), (735, 700)]
BELOW_WRIST = [(575, 940), (620, 893), (700, 863), (760, 855), (800, 1000), (560, 1000)]

# The inside of the cupped palm, above the lip, where the apple lies (seen while the hand waits).
CUP = [(742, 705), (760, 694), (800, 687), (850, 685), (900, 679), (930, 669), (942, 667), (950, 698), (928, 722),
       (910, 738), (882, 752), (850, 758), (818, 753), (780, 741), (748, 730)]

# The jacket sleeve, as your sketch draws it: its opening runs down from the step in the forearm's top edge, a little
# wider than the wrist; the white shirt cuff shows just past it; the sleeve carries on past the sketch's edge.
SLEEVE_END = [(541, 848), (557, 877), (570, 903), (584, 932)]
SLEEVE = [(541, 848), (557, 877), (570, 903), (584, 932), (560, 962), (534, 995), (378, 995), (400, 972), (428, 945),
          (453, 921), (478, 900), (503, 880), (527, 862)]
CUFF_WIDTH = 15

# The nails (middle, half length along the digit and half width) and the creases, knuckles and tendons (sketch px).
THUMB_NAIL = ((839, 643), 10.0, 7.2)
INDEX_NAIL = ((954, 652), 7.0, 6.0)
THUMB_CREASES = [[(806, 652), (809, 657), (810, 662)], [(812, 649), (815, 654), (816, 659)]]
FINGER_CREASES = [[(938, 705), (944, 709)], [(945, 680), (951, 683)], [(948, 735), (955, 739)]]
KNUCKLES = [(915, 760), (930, 772), (940, 784)]
TENDONS = [[(640, 790), (720, 768), (800, 757), (880, 755)], [(650, 806), (730, 788), (810, 779), (890, 772)]]

LIGHT = np.array([-0.72, -0.58, -0.38])  # toward the light: up, left and toward us (x right, y down, z away)
LIGHT = LIGHT / np.linalg.norm(LIGHT)
SKIN_LIT = np.array([0.93, 0.9, 0.9], np.float32)
SKIN_SHADE = np.array([0.66, 0.6, 0.65], np.float32)
SKIN_DEEP = np.array([0.36, 0.32, 0.37], np.float32)  # the cupped palm's inside, deep in shade
COOL_RIM = np.array([0.72, 0.74, 0.82], np.float32)
APPLE_GLOW = np.array([0.62, 0.05, 0.08], np.float32)
NAIL = np.array([0.95, 0.88, 0.88], np.float32)
LINE = np.array([0.2, 0.16, 0.19], np.float32)


def H(x, y):
    """Sketch px to the hand picture's px."""
    return ((x - HAND_BOX[0]) * HAND_SCALE, (y - HAND_BOX[1]) * HAND_SCALE)


def hfill(points):
    return pt.fill([H(x, y) for x, y in points], HW, HH)


def hgrid():
    """The sketch px at every pixel of the hand's picture (x, y)."""
    ys, xs = pt.grid(HH, HW)
    return xs / HAND_SCALE + HAND_BOX[0], ys / HAND_SCALE + HAND_BOX[1]


def spline(points, n=10):
    """A smooth curve through `points` (Catmull-Rom), n points from each to the next."""
    pts = np.asarray(points, np.float64)
    padded = np.vstack([pts[0] * 2 - pts[1], pts, pts[-1] * 2 - pts[-2]])
    out = []
    for i in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[i - 1], padded[i], padded[i + 1], padded[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t))
    out.append(pts[-1])
    return [tuple(p) for p in out]


def smooth_fill(points):
    """A closed outline through `points` (sketch px), smoothed, as coverage."""
    closed = list(points) + list(points[:3])
    curve = spline(closed, 8)
    return hfill(curve[: len(points) * 8 + 1])


def digit(axis, widths):
    """A finger or a thumb (coverage): a tube along `axis` (sketch px, root to tip), `widths` across, the tip round."""
    line = spline(axis, 10)
    w = np.interp(np.linspace(0, 1, len(line)), np.linspace(0, 1, len(widths)), widths)
    shape = hfill(pt.outline(line, list(w)))
    tx, ty = H(*line[-1])
    return np.maximum(shape, pt.ellipse(tx, ty, w[-1] / 2 * HAND_SCALE, w[-1] / 2 * HAND_SCALE, HW, HH))


def stroke(points, width, smooth=True):
    """A line (coverage) along `points` (sketch px), `width` picture px."""
    line = spline(points, 8) if smooth and len(points) > 2 else points
    return pt.fill(pt.outline([H(x, y) for x, y in line], [width] * len(line)), HW, HH)


def form(mask, sigma):
    """The way a part's surface faces (h, w, 3; x right, y down, z away), taking its mask as a rounded form: blurred,
    it stands up in its middle and falls away at its edge."""
    height = pt.blur(mask, sigma)
    gy, gx = np.gradient(height)
    k = 7.0 * sigma
    n = np.stack([-gx * k, -gy * k, -np.ones_like(height)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def skin(n, near_apple, base=None):
    """Skin under the light: a lit face, a crisp shade, a cool light round the shaded edge, the apple's red light on
    what faces it, a soft sheen on the lit bulges."""
    ndl = n @ LIGHT
    lit = pt.smoothstep(-0.03, 0.12, ndl)[..., None]
    shade = SKIN_SHADE if base is None else base
    col = shade[None, None] * (1 - lit) + SKIN_LIT[None, None] * lit
    col = col * (0.9 + 0.12 * np.clip(ndl, 0, 1))[..., None]
    edge = pt.smoothstep(0.55, 0.95, 1 + n[..., 2])[..., None]  # (turned away from us, at the outline)
    col = col * (1 - 0.35 * edge * (1 - lit)) + COOL_RIM[None, None] * (0.35 * edge * (1 - lit))
    col = col + APPLE_GLOW[None, None] * (near_apple[..., None] * (0.3 - 0.18 * lit))
    half = LIGHT + np.array([0.0, 0.0, -1.0])
    half = half / np.linalg.norm(half)
    sheen = np.clip(n @ half, 0, 1) ** 28 * 0.1
    return np.clip(col + sheen[..., None], 0, 1)


def apple_light(n):
    """How much of the apple's red reaches each pixel: near the apple and facing it."""
    x, y = hgrid()
    cx, cy, rx, ry = HELD
    dx, dy = cx - x, cy - y
    dist = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
    near = np.exp(-((np.maximum(dist - 0.85, 0) / 0.45) ** 2))
    length = np.sqrt(dx * dx + dy * dy) + 1e-6
    facing = np.clip((n[..., 0] * dx + n[..., 1] * dy) / length, 0, 1)
    return near * (0.35 + 0.65 * facing)


def ink(rgb, alpha, mask, lit_side, width=2.3):
    """The outline round `mask` (in place): thin and light where the form faces the light, heavier where it turns
    away from it."""
    ring = np.clip(mask - flow.shrink(mask, int(round(width))), 0, 1)
    soft = pt.blur(mask, 3.0)
    gy, gx = np.gradient(soft)
    length = np.sqrt(gx * gx + gy * gy) + 1e-6
    outward = np.stack([-gx / length, -gy / length], -1)
    toward = np.clip(outward @ LIGHT[:2] / np.linalg.norm(LIGHT[:2]), 0, 1)
    weight = 0.95 - 0.5 * toward * lit_side
    pt.layer_over(rgb, alpha, LINE, ring * weight)


def nail(rgb, alpha, spec, toward, clip_to):
    """A nail (in place): pale, a white gleam along it, a thin rim; `toward` the digit's way (radians)."""
    (nx, ny), along, across = spec
    cx, cy = H(nx, ny)
    body = pt.ellipse(cx, cy, along * HAND_SCALE, across * HAND_SCALE, HW, HH, angle=toward) * clip_to
    pt.layer_over(rgb, alpha, NAIL, body)
    inner = pt.ellipse(cx - math.cos(toward) * 1.5, cy - math.sin(toward) * 1.5, along * 0.78 * HAND_SCALE,
                       across * 0.7 * HAND_SCALE, HW, HH, angle=toward)
    rim = np.clip(body - inner, 0, 1)
    pt.layer_over(rgb, alpha, LINE, rim * 0.55)
    gx, gy = cx - math.sin(toward) * across * 0.35 * HAND_SCALE, cy + math.cos(toward) * across * -0.35 * HAND_SCALE
    gleam = pt.ellipse(gx, gy, along * 0.55 * HAND_SCALE, across * 0.16 * HAND_SCALE, HW, HH, angle=toward) * body
    pt.layer_over(rgb, alpha, np.array([1.0, 1.0, 1.0], np.float32), gleam * 0.85)


def shifted(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys = slice(max(dy, 0), h + min(dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = mask[yd, xd]
    return out


def sleeve(rgb, alpha, shape):
    """The dark jacket sleeve and the white shirt cuff past it (in place): near black, the light along its top, two
    soft folds, the hem of its opening catching the light; the cuff shaded underneath."""
    x, y = hgrid()
    cloth = hfill(SLEEVE)
    pt.layer_over(rgb, alpha, np.array([0.075, 0.075, 0.088], np.float32), cloth)
    (ax, ay), (bx, by) = SLEEVE_END[0], SLEEVE_END[-1]
    run = np.array([bx - ax, by - ay], np.float64)
    run /= np.linalg.norm(run)
    across = np.array([run[1], -run[0]])  # (along the arm, toward the hand)
    back = (x - ax) * across[0] + (y - ay) * across[1]  # (how far from the opening, toward the hand)
    side = (x - ax) * run[0] + (y - ay) * run[1]  # (along the opening, from its top)
    lit = cloth * (1 - pt.smoothstep(4, 22, side + 0.18 * back))
    pt.layer_over(rgb, alpha, np.array([0.24, 0.24, 0.27], np.float32), pt.blur(lit, 2.0 * HAND_SCALE) * 0.8 * cloth)
    for fold in (-30.0, -62.0):
        crease = np.exp(-(((back - fold - 0.25 * side) / 5.0) ** 2)) * cloth
        pt.layer_over(rgb, alpha, np.array([0.17, 0.17, 0.2], np.float32), crease * 0.6)
        under = np.exp(-(((back - fold - 0.25 * side + 6) / 3.0) ** 2)) * cloth
        pt.layer_over(rgb, alpha, np.array([0.03, 0.03, 0.035], np.float32), under * 0.6)
    hem = np.exp(-(((back + 3.0) / 2.2) ** 2)) * cloth
    pt.layer_over(rgb, alpha, np.array([0.32, 0.32, 0.36], np.float32), hem * 0.8)
    cuff = pt.smoothstep(-0.5, 0.5, back) * (1 - pt.smoothstep(CUFF_WIDTH - 0.5, CUFF_WIDTH + 0.5, back)) * shape
    tone = 0.95 - 0.26 * pt.smoothstep(25, 80, side)
    pt.layer_over(rgb, alpha, np.stack([tone, tone, tone * 1.02], -1).astype(np.float32), pt.blur(cuff, 0.6))
    seam = np.exp(-(((back - CUFF_WIDTH) / 1.2) ** 2)) * shape
    pt.layer_over(rgb, alpha, np.array([0.55, 0.55, 0.6], np.float32), seam * 0.6)
    return cloth


def held_apple(grow=0.0):
    """Where the apple lies in the hand (coverage), a little wider by `grow` sketch px."""
    cx, cy, rx, ry = HELD
    ex, ey = H(cx, cy)
    return pt.ellipse(ex, ey, (rx + grow) * HAND_SCALE, (ry + grow) * HAND_SCALE, HW, HH)


def sketch_lum():
    """Your sketch's lightness laid over the hand's picture (sketch px past its bottom edge carry its last row)."""
    lum = png.read(SKETCH)[..., 0].astype(np.float32) / 255.0
    x, y = hgrid()
    xi = np.clip(x, 0, lum.shape[1] - 1.001)
    yi = np.clip(y, 0, lum.shape[0] - 1.001)
    x0, y0 = xi.astype(int), yi.astype(int)
    fx, fy = xi - x0, yi - y0
    top = lum[y0, x0] * (1 - fx) + lum[y0, x0 + 1] * fx
    bottom = lum[y0 + 1, x0] * (1 - fx) + lum[y0 + 1, x0 + 1] * fx
    return (top * (1 - fy) + bottom * fy).astype(np.float32)


_SILHOUETTE = []


def silhouette():
    """The hand's outline from your sketch (0..1), the thumb left out (it is its own picture): the light your pencil
    leaves against the hatched dark with its holes filled; the apple, what is above the palm and below the wrist taken
    out; the ball of the thumb, the palm's lip, the curled fingers' underside and the sleeve put in; slits closed, thin
    bits dropped, and the pencil's ragged edge smoothed away."""
    if _SILHOUETTE:
        return _SILHOUETTE[0]
    x, y = hgrid()
    light = (pt.blur(sketch_lum(), 7.0 * HAND_SCALE) > 0.5) & (y < 934)
    shape = np.maximum(light.astype(np.float32), hfill(SLEEVE))
    seeds = np.zeros((HH, HW), bool)
    seeds[:4, :] = True
    seeds[:, -4:] = True
    seeds[:, :4] = True
    shape = (~flow.joined(shape < 0.5, seeds, limit=3000)).astype(np.float32)
    shape *= 1 - held_apple(grow=9)
    shape *= 1 - hfill(SKETCH_THUMB)
    shape *= 1 - hfill(ABOVE_PALM)
    shape *= 1 - hfill(BELOW_WRIST)
    px, py = H(*THUMB_PIVOT)
    ball = pt.ellipse(px, py, THUMB_BALL * HAND_SCALE, THUMB_BALL * HAND_SCALE, HW, HH)
    parts = [hfill(THUMB_ROOT), ball, hfill(UNDERSIDE), hfill(PALM_LIP), hfill(SLEEVE)]
    shape = np.maximum.reduce([shape] + parts)
    shape = flow.shrink(flow.grow(shape, 4), 4)
    body = flow.grow(flow.shrink(shape, 6), 6)
    body = np.maximum.reduce([body] + parts)
    wrist = hfill([(600, 820), (640, 820), (640, 860), (600, 860)]) > 0.5
    kept = flow.joined(body > 0.5, wrist & (body > 0.5), limit=3000)
    out = pt.smoothstep(0.42, 0.58, pt.blur(kept.astype(np.float32), 5.0))
    _SILHOUETTE.append(out)
    return out


def front():
    """AppleHandFront (RGBA): the back of the hand and its side, the palm's lip, the three fingers round the apple's
    right side, the cuff and the sleeve, inked."""
    body = silhouette()
    fingers = [digit(axis, widths) for axis, widths in FINGERS]
    shape = np.maximum.reduce([body] + fingers)
    # One rounded form for the hand, the fingers standing up a little from it where they leave it.
    height = pt.blur(body, 30.0)
    for finger in fingers:
        height = np.maximum(height, pt.blur(finger, 6.0) * 0.6 + 0.1 * finger)
    gy, gx = np.gradient(height)
    n = np.stack([-gx * 200.0, -gy * 200.0, -np.ones_like(height)], -1)
    n = n / np.linalg.norm(n, axis=-1, keepdims=True)
    # (the apple's red only faintly: this picture shows while the hand waits too, with no apple in it)
    rgb = skin(n, apple_light(n) * 0.4)
    # The tendons along the back of the hand and the knuckles at the fingers' roots: soft ridges of light.
    for tendon in TENDONS:
        line = stroke(tendon, 3.0)
        rgb = rgb + (pt.blur(line, 2.4) * body)[..., None] * 0.05
        rgb = rgb - (pt.blur(shifted(line, 2, 4), 2.6) * body)[..., None] * 0.035
    for kx, ky in KNUCKLES:
        cx, cy = H(kx, ky)
        bump = pt.blur(pt.ellipse(cx, cy, 7 * HAND_SCALE, 5 * HAND_SCALE, HW, HH), 3.0) * shape
        rgb = rgb + bump[..., None] * 0.045
    rgb = np.clip(rgb, 0, 1).astype(np.float32)
    alpha = shape.astype(np.float32).copy()
    # Each finger's line where it lies across the one behind it, back to front (none where it grows out of the hand),
    # with a little shade on what is behind, just below it.
    behind = body.copy()
    root = pt.smoothstep(0.55, 0.85, pt.blur(body, 14.0))
    for finger in fingers:
        over = finger * pt.smoothstep(0.3, 0.6, pt.blur(behind, 2.0))
        edge = np.clip(finger - flow.shrink(finger, 2), 0, 1) * over
        pt.layer_over(rgb, alpha, LINE, edge * (1 - root) * 0.8)
        drop = np.clip(pt.blur(shifted(finger, 3, 5), 3.0) - finger, 0, 1) * behind
        rgb *= (1 - 0.22 * drop)[..., None]
        behind = np.maximum(behind, finger)
    for crease in FINGER_CREASES:
        pt.layer_over(rgb, alpha, LINE, stroke(crease, 1.4, smooth=False) * shape * 0.5)
    nail(rgb, alpha, INDEX_NAIL, math.radians(-86), fingers[-1])
    cloth = sleeve(rgb, alpha, shape)
    ink(rgb, alpha, np.maximum(shape, cloth), 1.0)
    return np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1).astype(np.float32)


def back():
    """AppleHandBack (RGBA): the inside of the cupped palm, under the apple, deep in shade toward its bottom, the far
    side catching the light; and the web of skin from the thumb's root (seen while the thumb stands up)."""
    cup = np.maximum(hfill(CUP), hfill(WEB))
    n = form(cup, 18.0)
    # (the inside of a cup faces the other way from a dome: its far side is lit)
    n = n * np.array([-1.0, -1.0, 1.0])
    n[..., 2] = -np.abs(n[..., 2])
    n = n / np.linalg.norm(n, axis=-1, keepdims=True)
    rgb = skin(n, apple_light(n) * 0.6, base=SKIN_DEEP)
    x, y = hgrid()
    deep = pt.smoothstep(690, 750, y) * pt.smoothstep(960, 760, x)
    rgb = rgb * (1 - 0.45 * deep[..., None])
    for crease in ([(760, 720), (800, 712), (850, 712), (900, 704)], [(790, 732), (840, 728), (890, 722)]):
        pt.over(rgb, LINE, stroke(crease, 1.3) * cup * 0.14)
    return np.concatenate([np.clip(rgb, 0, 1), cup[..., None]], -1).astype(np.float32)


def thumb_square():
    """The square the thumb's picture covers: its middle the thumb's root (picture px), its half side."""
    px, py = H(*THUMB_PIVOT)
    reach = 0.0
    for x, y in THUMB_AXIS:
        hx, hy = H(x, y)
        reach = max(reach, math.hypot(hx - px, hy - py))
    half = int(math.ceil(reach + 40 * HAND_SCALE))
    return px, py, half


def thumb():
    """AppleThumb (RGBA, a square with the thumb's root in its middle): the thumb as it lies over the apple with the
    web of skin under it, its nail, the creases over its knuckle, the shade it casts down to its right; faded out where
    it lies deep in the hand, so the game can turn it at its root without a seam."""
    shape = digit(THUMB_AXIS, THUMB_WIDTHS)
    n = form(shape, 10.0)
    rgb = skin(n, apple_light(n))
    alpha = shape.astype(np.float32).copy()
    for crease in THUMB_CREASES:
        pt.layer_over(rgb, alpha, LINE, stroke(crease, 1.3) * shape * 0.55)
    direction = math.atan2(THUMB_AXIS[-1][1] - THUMB_AXIS[-2][1], THUMB_AXIS[-1][0] - THUMB_AXIS[-2][0])
    nail(rgb, alpha, THUMB_NAIL, direction, shape)
    ink(rgb, alpha, shape, 1.0)
    # (faded out at its root, where it turns, and where it lies more than a few px inside the hand: the hand's own
    # picture shows there)
    x, y = hgrid()
    reach = np.hypot(x - THUMB_PIVOT[0], y - THUMB_PIVOT[1])
    deep = flow.shrink(silhouette(), 7)
    keep = (1 - pt.smoothstep(0.2, 0.9, pt.blur(deep, 4.0))) * pt.smoothstep(THUMB_FADE[0], THUMB_FADE[1], reach)
    alpha = alpha * keep
    # the shade it casts, down and to the right, where the thumb is not
    cast = np.clip(pt.blur(shifted(shape, int(6 * HAND_SCALE), int(8 * HAND_SCALE)), 5.0 * HAND_SCALE) - shape, 0, 1)
    cast = cast * 0.32 * keep
    total = alpha + cast * (1 - alpha)
    rgb = rgb * (alpha / np.maximum(total, 1e-6))[..., None]
    picture = np.concatenate([np.clip(rgb, 0, 1), total[..., None]], -1).astype(np.float32)
    px, py, half = thumb_square()
    out = np.zeros((2 * half, 2 * half, 4), np.float32)
    x0, y0 = int(round(px)) - half, int(round(py)) - half
    xa, ya = max(0, x0), max(0, y0)
    xb, yb = min(HW, x0 + 2 * half), min(HH, y0 + 2 * half)
    out[ya - y0: yb - y0, xa - x0: xb - x0] = picture[ya:yb, xa:xb]
    return out


def thumb_at(square, degrees):
    """The thumb's square turned `degrees` about its middle (screen y down: negative stands it up), bilinear: what the
    game shows."""
    size = square.shape[0]
    c = size / 2
    a = math.radians(-degrees)
    ys, xs = pt.grid(size, size)
    sx = np.clip(c + (xs - c) * math.cos(a) - (ys - c) * math.sin(a) - 0.5, 0, size - 1.001)
    sy = np.clip(c + (xs - c) * math.sin(a) + (ys - c) * math.cos(a) - 0.5, 0, size - 1.001)
    x0, y0 = sx.astype(int), sy.astype(int)
    fx, fy = (sx - x0)[..., None], (sy - y0)[..., None]
    top = square[y0, x0] * (1 - fx) + square[y0, x0 + 1] * fx
    bottom = square[y0 + 1, x0] * (1 - fx) + square[y0 + 1, x0 + 1] * fx
    return (top * (1 - fy) + bottom * fy).astype(np.float32)
