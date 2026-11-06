"""The hand that catches the apple on the loading screen (UI/AppleLoading). Redrawn 2026-11-05 at your word ("the hand
drawing is ugly, change it, make it ryuks hand instead"): a death god's hand in the spirit of Ryuk's, drawn for this
game (not traced from any art). Long, gaunt fingers of bone with knobbly knuckles, dark blue-grey skin over tendons,
long dark nails grown into claws, a black studded leather band round the wrist. It keeps the old hand's place and
movement: the same picture over your sketch (art/refs/ui/apple_sketch.png), the thumb's root, hinge and open angle
where they were, so UI/AppleLoading and the apple's sheets are untouched.

2026-11-06, your word ("dont make ryuks hand 3d, and make the apple fit the hand", "the nails look weird"; a 3D render
of it was tried and dropped that day): the apple is smaller and sits down in the palm (HELD), the palm's edge follows
its foot, the fingers and thumb are longer and thicker and fan round it; the skin is shaded as an anime frame is (a
hard terminator, a core shadow, hatching, a crisp rim, a shine, grain) instead of airbrushed; each claw grows out from
under its fingertip's skin like a talon instead of sitting on it as a black cap.

Each part is shaded as a rounded form under the light from the upper left that lights the apple (a lit face, a crisp
shade, a cool light round the shaded edge, the apple's red light on what faces it), inked as an anime frame is (a
heavier line where the form turns from the light): the fingers' joints swell and their shafts run thin, each joint
creased; the tendons stand along the back of the hand, the knuckles stand out of it.

Three pictures, so the game closes the thumb smoothly (it turns the thumb's picture about its root) and the apple
lands between them:

    AppleHandBack   the inside of the cupped palm, under the apple (seen while the hand waits)
    AppleHandFront  the hand over the apple: the back of the hand and the forearm, the palm's lip in front of the
                    apple's foot, the four fingers round its right side with their claws, the studded wristband
    AppleThumb      the thumb alone on a square whose middle is its root, laid over the apple with the shade it casts

Coordinates are your sketch's px (1681 x 936), laid on the hand's picture (1024 x 736) by H.
"""

import math

import numpy as np

import flow
import paint as pt

HAND_BOX = (400, 545, 1010, 983)  # the sketch's px the hand's picture covers (x0, y0, x1, y1)
HAND_SCALE = 1024 / 610
HW, HH = 1024, 736

# The apple in the hand (its middle, half width and half height): first measured on your sketch (845, 652, 105, 91),
# made smaller and set down into the palm on 2026-11-06 ("make the apple fit the hand": it was wider than the grip,
# resting on the palm's edge with the fingers a thin column down its side). The screen keeps the hand's size
# (intro_frames APPLE_ON_SCREEN shrank alike), so the hand is what grew round it.
HELD = (842.0, 666.0, 88.0, 76.0)

# The thumb, root to tip, along its middle (the old hand's line from its hinge on, so its square, which reaches to
# its tip, and its hinge stay where they were; it starts at the hinge now, rounded, so nothing of it shows behind the
# hand as it stands up), and its width there: broad at its root, thin along its bones, swelling at its joint. It turns where it leaves the
# hand's edge. The web of skin between it and the hand is drawn behind the apple, so it shows only while the thumb
# stands up (the apple covers it once caught).
THUMB_AXIS = [(722, 704), (735, 698), (757, 686), (777, 675), (797, 664), (817, 654), (835, 647), (849, 642)]
THUMB_WIDTHS = [46, 41, 34, 30, 35, 27, 24, 22]
THUMB_JOINT = (799.0, 663.0)  # its knuckle, where its two bones meet
WEB = [(733, 702), (747, 668), (764, 652), (772, 662), (766, 676), (778, 686), (790, 690), (776, 706), (752, 712)]
THUMB_PIVOT = (738.0, 694.0)
THUMB_FADE = (8.0, 20.0)  # sketch px from its root: gone inside the first, whole past the second
THUMB_BALL = 22.0  # the hand's own picture is skin this far round the thumb's root, so it turns over the hand
OPEN_THUMB = -38.0  # degrees the thumb stands up while the hand waits (the game turns it down as the apple lands)


def round_apple(degrees, off):
    """A point round the held apple: `degrees` round from its right (down positive), `off` sketch px out from it."""
    a = math.radians(degrees)
    return (HELD[0] + (HELD[2] + off) * math.cos(a), HELD[1] + (HELD[3] + off) * math.sin(a))


# The four fingers round the apple's right side, back to front (little, ring, middle, index): the knuckle each grows
# from at the hand's end, then its two middle joints and its tip, wrapped round the apple a little further out the
# further back the finger is, so each shows past the one in front; how thick it is at the knuckle, along its bones and
# at its joints; and its claw (length, and how far it hooks in toward the apple, degrees).
FINGERS = [
    {"joints": [(912, 796), round_apple(52, 24), round_apple(30, 28), round_apple(12, 26)], "scale": 0.95,
     "claw": (30, 34)},
    {"joints": [(920, 778), round_apple(40, 12), round_apple(10, 14), round_apple(-12, 10)], "scale": 1.02,
     "claw": (34, 36)},
    {"joints": [(918, 758), round_apple(26, -4), round_apple(-10, -6), round_apple(-36, -10)], "scale": 1.08,
     "claw": (37, 38)},
    {"joints": [(904, 742), round_apple(12, -20), round_apple(-28, -24), round_apple(-62, -26)], "scale": 1.12,
     "claw": (40, 40)},
]
# (sketch px across: the knuckle, the bone, the joint, the bone, the joint, the last bone, the tip)
FINGER_WIDTHS = [36, 26, 32.5, 23, 27.5, 20.5, 18.5]

# The back of the hand and the forearm, one outline: up from the bottom edge along the forearm's top, the wrist, the
# ball of the thumb to its root, the palm's lip along the apple's foot to the index finger's knuckle; then back under
# the knuckles, along the hand's underside, the wrist's bone and the forearm's underside.
ARM = [
    (500, 990), (560, 925), (620, 862), (668, 815), (698, 786), (710, 760), (710, 732), (712, 708), (720, 688),
    (736, 673), (752, 671), (764, 682), (770, 698), (783, 724), (811, 740), (842, 746), (873, 741), (899, 730),
    (922, 738),
    (934, 752), (936, 772), (930, 792), (916, 806), (890, 816), (852, 824), (812, 830), (776, 836), (746, 846),
    (722, 862), (700, 884), (676, 914), (650, 950), (624, 990),
]
WRIST = (707.0, 830.0)  # the wrist's middle
ARM_WAY = np.array([145.0, -160.0]) / math.hypot(145.0, -160.0)  # up the forearm toward the hand
# The band round the wrist: where along the forearm it lies (sketch px from the wrist toward the elbow), how far its
# near edge bows toward the hand (it is round), and the studs along it (across it, -1 its top edge to 1 its underside).
BAND = (-14.0, -46.0)
BAND_BOW = 7.0
STUDS = (-0.66, -0.2, 0.26, 0.7)

# The inside of the cupped palm, above the lip, where the apple lies (seen while the hand waits): a dish just inside
# the apple's lower half, so once caught the apple hides it all.
CUP = [round_apple(a, -2) for a in range(178, 0, -16)] + [(924, 660), (880, 650), (842, 648), (800, 650), (764, 660)]

# The tendons standing along the back of the hand (wrist to each knuckle), and the thumb's own up to its root.
TENDONS = [
    [(712, 808), (770, 790), (840, 770), (890, 754), (912, 746)],
    [(718, 822), (780, 806), (850, 788), (900, 772), (922, 766)],
    [(726, 836), (790, 822), (856, 806), (900, 794), (920, 788)],
]
THUMB_TENDON = [(684, 812), (706, 776), (720, 740), (734, 704)]
WRIST_BONE = (742.0, 850.0)  # the knob of bone at the wrist's underside

LIGHT = np.array([-0.72, -0.58, -0.38])  # toward the light: up, left and toward us (x right, y down, z away)
LIGHT = LIGHT / np.linalg.norm(LIGHT)
# A death god's skin: dark blue-grey, a cold slate where it is lit.
SKIN_LIT = np.array([0.33, 0.365, 0.42], np.float32)
SKIN_SHADE = np.array([0.165, 0.185, 0.23], np.float32)
SKIN_DEEP = np.array([0.09, 0.1, 0.125], np.float32)  # the cupped palm's inside, deep in shade
COOL_RIM = np.array([0.4, 0.47, 0.58], np.float32)
APPLE_GLOW = np.array([0.5, 0.04, 0.07], np.float32)
CLAW = np.array([0.06, 0.06, 0.075], np.float32)
CLAW_SHINE = np.array([0.6, 0.62, 0.68], np.float32)
LEATHER = np.array([0.05, 0.05, 0.058], np.float32)
LEATHER_LIT = np.array([0.2, 0.2, 0.225], np.float32)
STEEL = np.array([0.62, 0.63, 0.66], np.float32)
LINE = np.array([0.025, 0.025, 0.04], np.float32)


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
    """A finger or a thumb (coverage): a tube along `axis` (sketch px, root to tip), `widths` across, both ends
    round."""
    line = spline(axis, 10)
    w = np.interp(np.linspace(0, 1, len(line)), np.linspace(0, 1, len(widths)), widths)
    shape = hfill(pt.outline(line, list(w)))
    for end, width in ((line[0], w[0]), (line[-1], w[-1])):
        ex, ey = H(*end)
        shape = np.maximum(shape, pt.ellipse(ex, ey, width / 2 * HAND_SCALE, width / 2 * HAND_SCALE, HW, HH))
    return shape


def stroke(points, width, smooth=True):
    """A line (coverage) along `points` (sketch px), `width` picture px."""
    line = spline(points, 8) if smooth and len(points) > 2 else points
    return pt.fill(pt.outline([H(x, y) for x, y in line], [width] * len(line)), HW, HH)


def tapered(points, width, tip=0.3):
    """A line (coverage) along `points` (sketch px), `width` picture px in its middle, thinning to `tip` at both ends."""
    line = spline(points, 8) if len(points) > 2 else points
    m = len(line)
    widths = [tip + (width - tip) * max(0.0, math.sin(math.pi * k / (m - 1))) ** 0.7 for k in range(m)]
    return pt.fill(pt.outline([H(x, y) for x, y in line], widths), HW, HH)


def form(mask, sigma):
    """The way a part's surface faces (h, w, 3; x right, y down, z away), taking its mask as a rounded form: blurred,
    it stands up in its middle and falls away at its edge."""
    height = pt.blur(mask, sigma)
    gy, gx = np.gradient(height)
    k = 7.0 * sigma
    n = np.stack([-gx * k, -gy * k, -np.ones_like(height)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def normals(height, k):
    gy, gx = np.gradient(height)
    n = np.stack([-gx * k, -gy * k, -np.ones_like(height)], -1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def skin(n, near_apple, base=None):
    """Skin under the light, drawn as an anime frame shades it (2026-11-06: it was airbrushed): a lit face and a shade
    cut hard at the terminator, a deeper core shadow inside the shade, the shade hatched in fine ink strokes, a crisp
    cold rim where the shaded form turns away from us, the apple's red light on what faces it, a hard shine on the lit
    bulges (bone under thin skin) and a faint grain, so it reads as skin and not plastic."""
    h, w = n.shape[:2]
    ndl = n @ LIGHT
    lit = pt.smoothstep(-0.03, 0.03, ndl)[..., None]
    core = (1 - pt.smoothstep(-0.4, -0.34, ndl))[..., None]
    shade = SKIN_SHADE if base is None else base
    col = shade[None, None] * (1 - lit) + SKIN_LIT[None, None] * lit
    col = col * (1 - 0.32 * core) * (0.93 + 0.1 * np.clip(ndl, 0, 1))[..., None]
    ys, xs = pt.grid(h, w)
    strokes = pt.smoothstep(0.72, 0.92, 0.5 + 0.5 * np.cos(2 * math.pi * (xs + ys * 0.85) / 4.6))
    strokes *= pt.smoothstep(0.38, 0.55, pt.noise(h, w, 9, 77, 2))
    col = col * (1 - 0.2 * strokes[..., None] * (1 - lit) * (0.5 + 0.5 * core))
    edge = pt.smoothstep(0.84, 0.9, 1 + n[..., 2])[..., None]  # (turned away from us, at the outline)
    col = col * (1 - 0.55 * edge * (1 - lit)) + COOL_RIM[None, None] * (0.55 * edge * (1 - lit))
    col = col + APPLE_GLOW[None, None] * (near_apple[..., None] * (0.3 - 0.18 * lit))
    half = LIGHT + np.array([0.0, 0.0, -1.0])
    half = half / np.linalg.norm(half)
    shine = pt.smoothstep(0.955, 0.975, n @ half) * 0.16
    col = col * (1 + (pt.noise(h, w, 2.5, 78, 1) - 0.5) * 0.07)[..., None]
    return np.clip(col + shine[..., None], 0, 1)


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


def ink(rgb, alpha, mask, lit_side, width=2.3, where=None):
    """The outline round `mask` (in place): thin and light where the form faces the light, heavier where it turns
    away from it; only `where` if given."""
    ring = np.clip(mask - flow.shrink(mask, int(round(width))), 0, 1)
    soft = pt.blur(mask, 3.0)
    gy, gx = np.gradient(soft)
    length = np.sqrt(gx * gx + gy * gy) + 1e-6
    outward = np.stack([-gx / length, -gy / length], -1)
    toward = np.clip(outward @ LIGHT[:2] / np.linalg.norm(LIGHT[:2]), 0, 1)
    weight = 0.95 - 0.45 * toward * lit_side
    if where is not None:
        weight = weight * where
    pt.layer_over(rgb, alpha, LINE, ring * weight)


def shifted(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys = slice(max(dy, 0), h + min(dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = mask[yd, xd]
    return out


def held_apple(grow=0.0):
    """Where the apple lies in the hand (coverage), a little wider by `grow` sketch px."""
    cx, cy, rx, ry = HELD
    ex, ey = H(cx, cy)
    return pt.ellipse(ex, ey, (rx + grow) * HAND_SCALE, (ry + grow) * HAND_SCALE, HW, HH)


# The parts ------------------------------------------------------------------------------------------------------------

def finger_axis(finger):
    """A finger's middle line through its joints, with a point half way along each bone (so the widths swell at the
    joints and run thin between), and the widths there."""
    j = finger["joints"]
    pts = []
    for a, b in zip(j[:-1], j[1:]):
        pts += [a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)]
    pts.append(j[-1])
    return pts, [w * finger["scale"] for w in FINGER_WIDTHS]


def claw(tip, before, width, length, hook):
    """A claw (coverage) as Ryuk's are: one long nail growing out of the fingertip (redrawn 2026-11-06, "the nails
    look weird": they were a black cap on the tip with a hook stuck on it). Its root is a rounded nail bed lying over
    the last bone, `width` sketch px across, from just behind the tip; it runs on along the finger, `length` sketch px
    past the tip, bending `hook` degrees toward the apple only over its last stretch, tapering to a needle point.
    Returns its coverage, its middle line (picture px) and which way across it faces the light (unit)."""
    way = np.array(tip, np.float64) - np.array(before, np.float64)
    way /= np.linalg.norm(way)
    to_apple = np.array([HELD[0], HELD[1]]) - np.array(tip)
    turn = math.radians(hook) * (1 if way[0] * to_apple[1] - way[1] * to_apple[0] > 0 else -1)
    point = np.array(tip, np.float64) - way * width * 0.95
    step = (width * 0.95 + length) / 39
    pts = [point.copy()]
    for k in range(1, 40):
        t = k / 39
        a = turn * pt.smoothstep(0.4, 1.0, t)
        d = np.array([way[0] * math.cos(a) - way[1] * math.sin(a), way[0] * math.sin(a) + way[1] * math.cos(a)])
        point = point + d * step
        pts.append(point.copy())
    line = [H(*p) for p in pts]
    widths = []
    for t in np.linspace(0, 1, len(line)):
        bed = 0.75 + 0.25 * pt.smoothstep(0.0, 0.22, t)  # (its root, under the fingertip's skin)
        widths.append(width * HAND_SCALE * bed * (1 - pt.smoothstep(0.18, 1.0, t)) ** 0.9 + 0.5)
    shape = pt.fill(pt.outline(line, widths), HW, HH)
    across = np.array([-way[1], way[0]])
    if across @ LIGHT[:2] < 0:
        across = -across
    return shape, line, (across, widths)


def paint_claw(rgb, alpha, shape, line, side_widths, skin_clip=None):
    """A claw (in place): black horn with a blue cast; a long sharp glint down its lit side and a fainter cold one on
    its shaded side, as lacquer catches light; inked. Its root lies under the fingertip's skin (`skin_clip`, the
    finger), so it grows out of the tip like a talon instead of sitting on it as a cap."""
    across, widths = side_widths
    if skin_clip is not None:
        root = pt.fill(pt.outline(line[:16], [w * 2.4 + 4 for w in widths[:16]]), HW, HH)
        shape = shape * (1 - np.clip(skin_clip * 1.2, 0, 1) * root)
    pt.layer_over(rgb, alpha, CLAW, shape)
    m = len(line)
    for side, colour, strength, span in ((0.26, CLAW_SHINE, 0.9, (0.1, 0.78)), (-0.3, COOL_RIM, 0.45, (0.2, 0.7))):
        k0, k1 = int(m * span[0]), int(m * span[1])
        pts = [(line[k][0] + across[0] * side * widths[k], line[k][1] + across[1] * side * widths[k])
               for k in range(k0, k1)]
        thick = [0.25 + 1.7 * math.sin(math.pi * i / (len(pts) - 1)) for i in range(len(pts))]
        glint = pt.fill(pt.outline(pts, thick), HW, HH)
        pt.layer_over(rgb, alpha, colour, glint * shape * strength)
    ink(rgb, alpha, shape, 1.0, width=1.5)


def wrinkles(rgb, alpha, at, across, width, clip, count=3, strength=0.55):
    """The creases over a knuckle (in place): short curved lines across the finger at `at` (sketch px), `across` its
    way across it (unit), `width` the finger's width there."""
    ax, ay = across
    way = (-ay, ax)
    for k in range(count):
        off = (k - (count - 1) / 2) * 3.4
        cx, cy = at[0] + way[0] * off, at[1] + way[1] * off
        half = width * (0.36 - 0.06 * abs(k - (count - 1) / 2))
        bow = 1.6
        pts = [(cx - ax * half + way[0] * bow, cy - ay * half + way[1] * bow), (cx, cy),
               (cx + ax * half + way[0] * bow, cy + ay * half + way[1] * bow)]
        pt.layer_over(rgb, alpha, LINE, tapered(pts, 1.5, 0.2) * clip * strength)


def bump(rgb, at, rx, ry, clip, light=0.07):
    """A knob of bone under the skin (in place): lit on its upper left, shaded on its lower right."""
    cx, cy = H(*at)
    blob = pt.blur(pt.ellipse(cx, cy, rx * HAND_SCALE, ry * HAND_SCALE, HW, HH), 2.0 * HAND_SCALE)
    lit = shifted(blob, -2, -3)
    dark = shifted(blob, 3, 4)
    rgb += ((lit - dark).clip(0, 1) * clip)[..., None] * light
    rgb -= ((dark - lit).clip(0, 1) * clip)[..., None] * light * 0.9


def band_shape():
    """The wristband (coverage) and, at every pixel, how far along it (0 its near edge, 1 its far edge) and across it
    (-1 its top edge, 1 its underside)."""
    x, y = hgrid()
    way = ARM_WAY
    across = np.array([way[1], -way[0]]) * -1  # (toward the forearm's underside: down and right)
    rel_x, rel_y = x - WRIST[0], y - WRIST[1]
    along = rel_x * way[0] + rel_y * way[1]
    side = rel_x * across[0] + rel_y * across[1]
    half = 41.0
    t = np.clip(side / half, -1, 1)
    bow = BAND_BOW * (1 - t * t)
    near, far = BAND[0] + bow, BAND[1] + bow
    inside = pt.smoothstep(-0.7, 0.7, near - along) * pt.smoothstep(-0.7, 0.7, along - far)
    inside *= pt.smoothstep(-0.7, 0.7, half - np.abs(side))
    return inside, (near - along) / (near - far), t, along, side


def silhouette():
    """The back of the hand and the forearm (0..1): the outline smoothed, the ball of the thumb's root put in (so the
    thumb turns over skin)."""
    body = smooth_fill(ARM)
    px, py = H(*THUMB_PIVOT)
    ball = pt.ellipse(px, py, THUMB_BALL * HAND_SCALE, THUMB_BALL * HAND_SCALE, HW, HH)
    return np.maximum(body, ball)


def front():
    """AppleHandFront (RGBA): the forearm and the back of the hand with its tendons and knuckles, the palm's lip, the
    four fingers round the apple's right side with their claws, the studded band at the wrist; inked."""
    body = silhouette()
    x, y = hgrid()
    # The back of the hand as one rounded form, the tendons and the knuckles standing up from it.
    height = pt.blur(body, 26.0)
    for tendon in TENDONS + [THUMB_TENDON]:
        height = height + pt.blur(tapered(tendon, 5.0, 1.0), 3.2) * 0.05
    for f in FINGERS:
        kx, ky = H(*f["joints"][0])
        height = height + pt.blur(pt.ellipse(kx, ky, 11 * HAND_SCALE, 9 * HAND_SCALE, HW, HH), 5.0) * 0.07
    n = normals(height, 210.0)
    rgb = skin(n, apple_light(n) * 0.35).astype(np.float32)
    # (the bones of a gaunt hand: hollows between the tendons, a darker underside)
    hollow = pt.blur(body, 10.0) - pt.blur(body, 30.0)
    rgb *= (1 - 0.18 * np.clip(-hollow * 3, 0, 1))[..., None]
    for tendon in TENDONS:
        groove = tapered([(px + 3, py + 6) for px, py in tendon], 4.0, 0.5)
        rgb *= (1 - 0.15 * pt.blur(groove, 4.0) * body)[..., None]
        ridge = tapered([(px - 1, py - 1.5) for px, py in tendon], 2.4, 0.3)
        rgb += (pt.blur(ridge, 1.2) * body)[..., None] * np.array([0.09, 0.1, 0.11], np.float32)
    ridge = tapered([(px - 1, py - 1.5) for px, py in THUMB_TENDON], 2.6, 0.3)
    rgb += (pt.blur(ridge, 1.2) * body)[..., None] * np.array([0.08, 0.09, 0.1], np.float32)
    bump(rgb, WRIST_BONE, 14, 10, body, 0.08)
    alpha = body.astype(np.float32).copy()
    # (skin, not plastic: the faintest mottling) and the palm's lip's crease
    rgb *= (1 + (pt.noise(HH, HW, 26, 31, 3) - 0.5) * 0.09 + (pt.noise(HH, HW, 4, 32, 2) - 0.5) * 0.04)[..., None]
    pt.layer_over(rgb, alpha, LINE, tapered([(760, 732), (800, 745), (845, 752), (885, 749)], 1.4, 0.2) * body * 0.4)

    # The fingers, back to front: each its own rounded form with swollen joints, creased at them, inked where it lies
    # over what is behind it (not where it grows out of the hand), with its claw.
    behind = body.copy()
    gy, gx = pt.grid(HH, HW)
    for f in FINGERS:
        axis, widths = finger_axis(f)
        shape = digit(axis, widths)
        fn = form(shape, 5.5)
        frgb = skin(fn, apple_light(fn) * 0.7)
        joints = f["joints"]
        kx, ky = H(*joints[0])
        root = 1 - pt.smoothstep(14 * HAND_SCALE, 24 * HAND_SCALE, np.hypot(gx - kx, gy - ky))
        # (a soft shade on what is behind, just below it)
        drop = np.clip(pt.blur(shifted(shape, 4, 6), 4.0) - shape, 0, 1) * behind
        rgb *= (1 - 0.35 * drop)[..., None]
        pt.layer_over(rgb, alpha, frgb, shape)
        for k, joint in enumerate(joints[1:3]):
            prev, nxt = joints[k], joints[k + 2]
            way = np.array(nxt, float) - np.array(prev, float)
            way /= np.linalg.norm(way)
            bump(rgb, joint, 7 * f["scale"], 6 * f["scale"], shape, 0.06)
            wrinkles(rgb, alpha, joint, (way[0], way[1]), widths[2 + 2 * k], shape, count=3)
        ink(rgb, alpha, shape, 1.0, where=1 - root)
        # (its nail, dark, over the end of its last bone, and the claw it grows into)
        tip, before = joints[-1], joints[-2]
        way = np.array(tip, float) - np.array(before, float)
        way /= np.linalg.norm(way)
        length, hook = f["claw"]
        shape_c, line, sides = claw(tip, before, widths[-1] * 0.62, length, hook)
        paint_claw(rgb, alpha, shape_c, line, sides, skin_clip=shape)
        behind = np.maximum(behind, shape)

    # The band round the wrist: black leather, the light along its top, a stitched rim at each edge, steel studs.
    inside, along, across, _, _ = band_shape()
    inside = inside * pt.smoothstep(0.2, 0.6, pt.blur(np.maximum(body, flow.grow(body, 5)), 1.0))
    # (it stands a little proud of the arm all round)
    proud = flow.grow((inside > 0.5).astype(np.float32), 4)
    proud = pt.blur(proud, 0.8) * pt.smoothstep(0.3, 0.7, flow.grow(body, 6))
    lit = pt.smoothstep(0.2, -0.85, across)
    leather = LEATHER[None, None] * (1 - lit[..., None]) + LEATHER_LIT[None, None] * lit[..., None]
    sheen = np.exp(-(((across + 0.45) / 0.14) ** 2)) * 0.12
    leather = leather + sheen[..., None]
    pt.layer_over(rgb, alpha, leather, proud)
    for edge in (0.13, 0.87):
        stitch = np.exp(-(((along - edge) / 0.035) ** 2)) * (np.sin((across * 40.0)) > 0.1)
        pt.layer_over(rgb, alpha, np.array([0.36, 0.36, 0.4], np.float32), stitch * proud * 0.7)
    rim = np.exp(-(((along - 0.0) / 0.05) ** 2)) + np.exp(-(((along - 1.0) / 0.05) ** 2))
    pt.layer_over(rgb, alpha, LINE, np.clip(rim, 0, 1) * proud * 0.5)
    for t in STUDS:
        across_v = np.array([ARM_WAY[1], -ARM_WAY[0]]) * -1
        mid = np.array(WRIST) + ARM_WAY * ((BAND[0] + BAND[1]) / 2 + BAND_BOW * (1 - t * t)) + across_v * t * 41.0
        cx, cy = H(*mid)
        r = 6.2 * HAND_SCALE * (1 - 0.35 * abs(t) ** 2)
        stud = pt.ellipse(cx, cy, r * (1 - 0.3 * abs(t)), r, HW, HH, angle=math.atan2(across_v[1], across_v[0]))
        sn = form(stud, 2.5 * HAND_SCALE)
        ndl = sn @ LIGHT
        metal = STEEL[None, None] * (0.32 + 0.75 * np.clip(ndl, 0, 1))[..., None]
        glint = pt.smoothstep(0.86, 0.95, ndl)[..., None]
        metal = metal * (1 - glint) + glint * 1.0
        shadow = np.clip(pt.blur(shifted(stud, 3, 4), 2.0) - stud, 0, 1)
        rgb *= (1 - 0.5 * shadow * proud)[..., None]
        pt.layer_over(rgb, alpha, metal, stud)
        ink(rgb, alpha, stud, 1.0, width=1.4)
    ink(rgb, alpha, proud, 1.0, width=1.8)

    whole = np.maximum(body, behind)
    ink(rgb, alpha, np.clip(whole, 0, 1), 1.0, width=2.6)
    return np.concatenate([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)[..., None]], -1).astype(np.float32)


def back():
    """AppleHandBack (RGBA): the inside of the cupped palm, under the apple, deep in shade toward its bottom, the far
    side catching the light, its lines; and the web of skin from the thumb's root (seen while the thumb stands up)."""
    cup = np.maximum(hfill(CUP), hfill(WEB))
    n = form(cup, 18.0)
    # (the inside of a cup faces the other way from a dome: its far side is lit)
    n = n * np.array([-1.0, -1.0, 1.0])
    n[..., 2] = -np.abs(n[..., 2])
    n = n / np.linalg.norm(n, axis=-1, keepdims=True)
    rgb = skin(n, apple_light(n) * 0.6, base=SKIN_DEEP)
    x, y = hgrid()
    deep = pt.smoothstep(690, 750, y) * pt.smoothstep(960, 760, x)
    rgb = rgb * (1 - 0.5 * deep[..., None])
    for crease in ([(760, 720), (800, 712), (850, 712), (900, 704)], [(790, 732), (840, 728), (890, 722)],
                   [(812, 700), (850, 696), (880, 690)]):
        pt.over(rgb, LINE, tapered(crease, 1.6, 0.2) * cup * 0.45)
    alpha = cup.astype(np.float32).copy()
    ink(rgb, alpha, cup, 1.0, width=1.8)
    return np.concatenate([np.clip(rgb, 0, 1), alpha[..., None]], -1).astype(np.float32)


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
    """AppleThumb (RGBA, a square with the thumb's root in its middle): the gaunt thumb as it lies over the apple, its
    knuckle swollen and creased, its nail grown into a claw, the shade it casts down to its right; faded out where it
    lies deep in the hand, so the game can turn it at its root without a seam."""
    shape = digit(THUMB_AXIS, THUMB_WIDTHS)
    n = form(shape, 7.0)
    rgb = skin(n, apple_light(n))
    alpha = shape.astype(np.float32).copy()
    way = np.array(THUMB_AXIS[5], float) - np.array(THUMB_AXIS[3], float)
    way /= np.linalg.norm(way)
    bump(rgb, THUMB_JOINT, 9, 7, shape, 0.07)
    wrinkles(rgb, alpha, THUMB_JOINT, (way[0], way[1]), 22.0, shape, count=3, strength=0.6)
    ink(rgb, alpha, shape, 1.0)
    tip, before = THUMB_AXIS[-1], THUMB_AXIS[-3]
    tw = np.array(tip, float) - np.array(before, float)
    tw /= np.linalg.norm(tw)
    shape_c, line, sides = claw(tip, before, THUMB_WIDTHS[-1] * 0.62, 34, 24)
    paint_claw(rgb, alpha, shape_c, line, sides, skin_clip=shape)
    whole = np.maximum(shape, shape_c)
    # (faded out at its root, where it turns, and where it lies more than a few px inside the hand: the hand's own
    # picture shows there)
    x, y = hgrid()
    reach = np.hypot(x - THUMB_PIVOT[0], y - THUMB_PIVOT[1])
    deep = flow.shrink(silhouette(), 7)
    keep = (1 - pt.smoothstep(0.2, 0.9, pt.blur(deep, 4.0))) * pt.smoothstep(THUMB_FADE[0], THUMB_FADE[1], reach)
    alpha = alpha * keep
    # the shade it casts, down and to the right, where the thumb is not
    cast = np.clip(pt.blur(shifted(whole, int(6 * HAND_SCALE), int(8 * HAND_SCALE)), 5.0 * HAND_SCALE) - whole, 0, 1)
    cast = cast * 0.36 * keep
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
