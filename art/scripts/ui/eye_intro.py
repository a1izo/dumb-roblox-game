"""The first join's eye (UI/EyeIntro), painted after your sketch (art/refs/ui/eye_sketch.png, 2026-10-27): a face turned
away in the dark and turned over, the eye on the left, the nose to the right with its nostril, the mouth up in the top
right corner, hair falling across from the left and up from below; the eye shut, then it opens, red. Every shape is
measured off the sketch (in its own pixels, 1670 x 942): the face's lines, the nose and the lids by hand (the lower lid
off a flood fill of the drawn white), the lashes along them the ways they were drawn, the hair and the mouth taken from
the pencil itself (where it is dense, and its strokes for the hair's way). The colours and shadows are your colour
frame's. Painted in layers with art/scripts/ui/paint.py, so the game can move them apart a little for depth:

    IntroBaseL, IntroBaseR   the face with the eye shut, the mouth, the light (two halves, 896 x 1008 each)
    IntroEye1..4             the eye's corner of the picture as it opens (a third, over half, most of the way, open),
                             laid exactly over the face (its edges feathered into the shut face's own pixels)
    IntroHairL, IntroHairR   the hair in front, a touch out of focus (transparent, two halves)

It also writes src/client/UI/EyeArt.luau (where the eye's crop and the eye itself sit in the picture) and a preview,
art/export/previews/intro_eye.png (shut and open, as the game lays them, and the sketch under them).

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/ui/eye_intro.py
"""

import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flow  # noqa: E402
import paint as pt  # noqa: E402
import png  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "art", "export", "textures")
PREVIEW = os.path.join(ROOT, "art", "export", "previews", "intro_eye.png")
LUAU = os.path.join(ROOT, "src", "client", "UI", "EyeArt.luau")
SKETCH = os.path.join(ROOT, "art", "refs", "ui", "eye_sketch.png")

SW, SH = 1670, 942  # the sketch
W, H = 1792, 1008  # the picture (each half fits Roblox's 1024 px limit)
K = W / SW  # sketch px -> picture px
OY = (H - SH * K) / 2
OPENINGS = (0.3, 0.58, 0.84, 1.0)

# The colours are read off your colour frame (sampled): grey skin, a dark plane where the face turns away, black beyond,
# near-black hair with a warm dull sheen, a greyed white and a crimson iris.
BG = (0.006, 0.006, 0.007)
SKIN = (0.78, 0.77, 0.775)
PLANE = (0.335, 0.322, 0.318)  # the nose and mouth's plane, turned from the light
STRIP = (0.6, 0.592, 0.593)  # the light caught along its foot and up its far edge
INK = (0.04, 0.038, 0.045)
HAIR_BASE = (0.03, 0.025, 0.022)
HAIR_BODY = (0.135, 0.12, 0.11)
HAIR_SHEEN = (0.52, 0.48, 0.45)
SCLERA = (0.86, 0.84, 0.85)
LIGHT = (-0.55, 0.835)  # which way shadows fall across the picture (the light is above and to the right)
SHADE = (0.6, 0.595, 0.61)  # what a shadow leaves of the light on skin: a flat grey, as the frame's are
SHADOW = (0.03, 0.03, 0.035)  # the front hair's shadow, laid over whatever is under it

# ---- the sketch's geometry (sketch px) ----

FACE_EDGE = [  # the face's edge on the right, from the top of the frame round the nose's foot
    (1670, 343), (1645, 357), (1620, 372), (1600, 388), (1580, 410), (1562, 432), (1548, 452), (1534, 470),
    (1524, 490), (1519, 515), (1518, 545), (1519, 575), (1520, 605), (1517, 635), (1512, 660), (1500, 688),
    (1485, 708), (1468, 722), (1450, 733),
]
UNDERSIDE = [  # the line under the face, from the nose's foot back into the hair
    (1450, 733), (1425, 724), (1400, 716), (1375, 709), (1350, 702), (1300, 692), (1250, 684), (1200, 679),
    (1150, 678), (1100, 677), (1050, 673),
]
FACE_FOOT = [(1000, 674), (900, 688), (800, 702), (680, 725), (560, 760), (440, 815), (350, 880), (300, 942)]
BROW_LINE = [  # the shadow's edge over the eye, its upper end leaving the frame
    (368, 210), (372, 195), (378, 180), (386, 168), (398, 158), (420, 146), (450, 132), (480, 122), (520, 110),
    (560, 98), (600, 85), (640, 70), (680, 55), (710, 40), (740, 20), (760, 4), (762, 0),
]
CREASE = [(380, 228), (420, 240), (460, 252), (500, 266), (530, 281), (552, 296), (575, 312), (598, 330)]
BRIDGE = [  # two light lines off the eye's inner corner
    [(687, 390), (715, 410), (742, 433), (765, 458), (790, 483)],
    [(723, 403), (742, 428), (758, 455), (772, 480), (781, 498)],
]
NOSE_TOP = [
    (1028, 497), (1050, 470), (1075, 445), (1100, 420), (1125, 397), (1150, 375), (1175, 354), (1200, 336),
    (1225, 320), (1255, 305), (1280, 296), (1302, 290), (1330, 294), (1350, 300), (1400, 315), (1450, 335),
    (1480, 348), (1494, 362), (1497, 380), (1492, 420), (1490, 470), (1495, 510), (1505, 545), (1515, 575),
]
NOSTRIL = [
    (1371, 343), (1363, 360), (1357, 385), (1359, 410), (1367, 438), (1379, 464), (1392, 490), (1406, 518),
    (1401, 488), (1394, 462), (1387, 438), (1380, 414), (1376, 390), (1374, 366),
]
HAIR_FRONT_ZONE = [  # where the hair in front may be (the pencil decides where it is)
    (0, 0), (395, 0), (372, 60), (335, 150), (300, 232), (262, 300), (330, 250), (520, 270), (700, 340),
    (830, 360), (930, 330), (990, 380), (1030, 470), (1060, 560), (1085, 640), (1110, 668), (1300, 686),
    (1440, 728), (1520, 760), (1670, 780), (1670, 942), (0, 942),
]
EYE_KEEP = [  # round the eye the pencil is the eye's (its lashes, the lid's fold, the lines off its corner), never hair
    (258, 280), (300, 245), (380, 215), (470, 232), (560, 272), (640, 318), (720, 368), (805, 425), (835, 480),
    (815, 512), (775, 520), (740, 470), (690, 420), (620, 380), (540, 345), (450, 318), (370, 315), (352, 330),
    (352, 395), (300, 398), (258, 392),
]
MOUTH_ZONE = [  # the mouth, up in the top right corner (the face is turned over): your shapes there, skin and not hair
    (1365, 0), (1670, 0), (1670, 326), (1640, 336), (1600, 322), (1530, 262), (1450, 172), (1385, 70),
]
MOUTH_PARTING = [  # the dark line along the lips' upper edge, out to the corner's point
    (1416, -4), (1440, 22), (1462, 45), (1485, 72), (1505, 95), (1530, 125), (1555, 148), (1580, 167), (1610, 183),
    (1650, 198),
]
MOUTH_EDGE = [(1583, -4), (1605, 18), (1628, 40), (1650, 58), (1674, 74)]  # the other lip's edge, leaving the frame

# The eye: its frame runs from the outer corner O to the inner corner I (u along it, v across it, down positive).
O = (345.0, 305.0)
I = (767.0, 505.0)
EA = math.atan2(I[1] - O[1], I[0] - O[0])
EC, ES = math.cos(EA), math.sin(EA)
U0, U1 = 28, 467  # where the eye's white starts and ends along u
IRIS = (560.5, 479.5, 89.5, 68.5)  # its middle and radii
PUPIL = 26.0 / 89.5
GLINT = ((490.5, 444.5), 38.0, 11.0, math.radians(30))  # middle, half-length, half-width, angle
UPPER_LID = [  # the upper lid's edge (u, v), read off the drawn line
    (U0, 12.0), (45, 6.0), (64, -6.0), (81, -15.0), (110, -25.0), (139, -33.0), (167, -39.0), (195, -43.0),
    (222, -45.5), (249, -46.0), (277, -46.0), (305, -45.0), (332, -41.5), (359, -37.0), (377, -30.0), (394, -21.0),
    (406, -12.0), (416, -4.0), (430, 2.0), (445, 4.0), (U1, 0.0),
]
LOWER_LID = [  # the lower lid's edge: the eye's white flood-filled in the sketch, its edge read off along u
    (U0, 12.0), (40, 19.0), (52, 28.0), (64, 38.0), (76, 49.0), (88, 59.0), (100, 68.0), (112, 76.0), (124, 83.0),
    (136, 92.0), (148, 102.0), (160, 109.0), (172, 115.0), (184, 120.0), (196, 122.0), (208, 125.0), (220, 131.0),
    (232, 135.0), (244, 137.0), (256, 137.5), (268, 136.5), (280, 134.0), (292, 130.0), (304, 125.0), (316, 118.0),
    (328, 108.0), (340, 98.0), (352, 90.0), (364, 82.0), (376, 75.0), (388, 67.0), (400, 56.0), (412, 44.0),
    (424, 33.0), (436, 22.0), (448, 12.0), (460, 4.0), (U1, 0.0),
]
LASH_LINE = [  # the upper lid's lash line (u, v), from beyond the outer corner to the inner
    (-17, 0.0), (34, -21.6), (105, -47.5), (165, -59.6), (219, -63.9), (263, -63.8), (296, -63.0), (337, -60.0),
    (368, -52.6), (401, -40.8), (432, -22.2), (467, 0.0),
]
LOWER_BAND = [  # how far below the lower lid its lash line is (u, px): thick at the outer side, as drawn
    (-11, 0.0), (U0, 6.0), (50, 30.0), (76, 40.0), (100, 44.0), (136, 42.0), (169, 34.0), (209, 24.0), (252, 11.0),
    (300, 8.0), (344, 8.0), (383, 6.0), (424, 6.0), (467, 0.0),
]
UP_DIR = [(-17, 200), (20, 214), (60, 232), (110, 250), (170, 263), (250, 276), (330, 290), (400, 312), (440, 338),
          (467, 352)]
UP_LEN = [(-17, 68), (10, 76), (45, 62), (90, 46), (140, 30), (200, 21), (300, 20), (370, 26), (420, 32), (467, 26)]
LO_DIR = [(-11, 198), (20, 185), (50, 175), (80, 158), (110, 140), (150, 122), (200, 105), (260, 95), (330, 82),
          (400, 55), (440, 22), (455, 10)]
LO_LEN = [(-11, 66), (20, 74), (50, 64), (80, 46), (110, 38), (150, 34), (200, 32), (260, 31), (330, 28), (400, 22),
          (440, 17), (455, 12)]
MEET = 0.78  # where the lids meet, shut: this share of the way down the open eye


def P(x, y):
    return (x * K, y * K + OY)


def scaled(points):
    return [P(x, y) for x, y in points]


def fill(points):
    return pt.fill(scaled(points), W, H)


def stroke(points, widths):
    return pt.stroke(scaled(points), np.asarray(widths, np.float64) * K, W, H)


def table(rows, u):
    xs, ys = zip(*rows)
    return np.interp(u, xs, ys)


def eye_xy(u, v):
    return O[0] + u * EC - v * ES, O[1] + u * ES + v * EC


def eye_uv(x, y):
    dx, dy = x - O[0], y - O[1]
    return dx * EC + dy * ES, -dx * ES + dy * EC


def sketch_grid():
    """Each picture px's place on the sketch (x, y)."""
    ys, xs = pt.grid(H, W)
    return xs / K, (ys - OY) / K


def resample(a):
    """A sketch-sized map onto the picture (bilinear)."""
    sx, sy = sketch_grid()
    sx, sy = sx - 0.5, sy - 0.5
    x0 = np.clip(np.floor(sx).astype(np.int32), 0, SW - 2)
    y0 = np.clip(np.floor(sy).astype(np.int32), 0, SH - 2)
    fx = np.clip(sx - x0, 0, 1)
    fy = np.clip(sy - y0, 0, 1)
    top = a[y0, x0] * (1 - fx) + a[y0, x0 + 1] * fx
    bottom = a[y0 + 1, x0] * (1 - fx) + a[y0 + 1, x0 + 1] * fx
    return (top * (1 - fy) + bottom * fy).astype(np.float32)


def pencil():
    """The sketch's pencil: 0 on the paper, 1 on its darkest line (sketch px)."""
    rgb = png.read(SKETCH)[..., :3].astype(np.float32) / 255
    lum = rgb.mean(axis=-1)
    paper = np.maximum(pt.blur(lum, 40), np.percentile(lum, 70))
    return np.clip((paper - lum) / 0.55, 0, 1)


def shifted(a, dx, dy):
    """`a` moved dx, dy whole px, what comes in empty."""
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    into = (slice(max(dy, 0), h + min(dy, 0)), slice(max(dx, 0), w + min(dx, 0)))
    out[into] = a[max(-dy, 0) : h - max(dy, 0), max(-dx, 0) : w - max(dx, 0)]
    return out


def rounded(points, passes=2):
    """An open polyline with its corners cut (Chaikin), its ends kept."""
    pts = [tuple(p) for p in points]
    for _ in range(passes):
        out = [pts[0]]
        for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
            out += [(0.75 * ax + 0.25 * bx, 0.75 * ay + 0.25 * by), (0.25 * ax + 0.75 * bx, 0.25 * ay + 0.75 * by)]
        pts = out + [pts[-1]]
    return pts


def distance_to(points, sx, sy):
    """Each px's distance (sketch px) to the polyline `points`."""
    out = np.full(sx.shape, 1e9, np.float32)
    pts = np.asarray(points, np.float32)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        dx, dy = bx - ax, by - ay
        t = np.clip(((sx - ax) * dx + (sy - ay) * dy) / (dx * dx + dy * dy), 0, 1)
        out = np.minimum(out, np.hypot(sx - ax - dx * t, sy - ay - dy * t))
    return out


def cast(mask, reach):
    """The shadow `mask` throws `reach` px along the light: a crisp shape close by, a soft penumbra further out."""
    dx, dy = LIGHT
    near = pt.blur(shifted(mask, round(dx * reach), round(dy * reach)), 1.6)
    far = pt.blur(shifted(mask, round(dx * reach * 1.6), round(dy * reach * 1.6)), reach * 0.5)
    return np.clip(0.9 * near + 0.25 * far, 0, 1)


def shade(canvas, amount, tint=SHADE):
    """Darkens `canvas` toward its shadow by `amount` (0..1), in place."""
    canvas *= 1 - np.clip(amount, 0, 1)[..., None] * (1 - np.asarray(tint, np.float32))


def smooth1d(a, sigma):
    r = int(sigma * 3)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    return np.convolve(np.pad(a, r, mode="edge"), k, mode="valid")


def opening():
    """The lids' edges at each whole u from U0 to U1, smoothed."""
    us = np.arange(U0, U1 + 1)
    return us, smooth1d(table(UPPER_LID, us), 3.0), smooth1d(table(LOWER_LID, us), 3.0)


class Eye:
    """The eye's lids at an openness, in its frame."""

    def __init__(self):
        self.us, self.top, self.bot = opening()
        self.meet = self.top + MEET * (self.bot - self.top)

    def lids(self, u, openness):
        """The upper and lower lid's edges at u (arrays), at this openness."""
        top = np.interp(u, self.us, self.top)
        bot = np.interp(u, self.us, self.bot)
        meet = np.interp(u, self.us, self.meet)
        # (beyond the outer corner the upper edge runs on to meet the lash line's end)
        before = np.clip((u + 17) / (U0 + 17), 0, 1)
        top = np.where(u < U0, top * before, top)
        shut = 1 - openness
        return top + (meet - top) * shut, bot - (bot - meet) * shut

    def lash_line(self, u, openness):
        """The upper lid's lash line at u: it rides with the lid, its band thinner as it stretches shut."""
        top, _ = self.lids(u, openness)
        band = np.maximum(self.lids(u, 1.0)[0] - table(LASH_LINE, u), 0)
        return top - band * (0.55 + 0.45 * openness)

    def lower_line(self, u, openness):
        _, bot = self.lids(u, openness)
        bot = np.where(u < U0, np.interp(u, (-11, U0), (-2.5, self.bot[0])), bot)
        return bot + table(LOWER_BAND, u) * (0.45 + 0.55 * openness)


def capsule(qx, qy, ax, ay, bx, by, radius):
    """Coverage of a rounded bar from a to b (`radius` wide each side) at points q, anti-aliased."""
    dx, dy = bx - ax, by - ay
    t = np.clip(((qx - ax) * dx + (qy - ay) * dy) / max(dx * dx + dy * dy, 1e-9), 0, 1)
    d = np.hypot(qx - (ax + dx * t), qy - (ay + dy * t)) - radius
    return np.clip(0.5 - d, 0, 1)


def lashes_along(line, dirs, lengths, u0, u1, step, seed, width, openness):
    """Tapered lashes rooted along `line(u)`, each pointing its table's way (degrees, y down), curling a little, in
    clumps of two or three whose tips draw together."""
    rng = random.Random(seed)
    cover = np.zeros((H, W), np.float32)

    def path(u, angle, length, curl):
        root = eye_xy(u, float(line(np.array([u]), openness)[0]))
        pts = []
        for k in range(9):
            f = k / 8
            a = angle + curl * f * f
            pts.append((root[0] + math.cos(a) * length * f, root[1] + math.sin(a) * length * f))
        return np.array(pts)

    u = u0
    while u <= u1:
        angle = math.radians(table(dirs, u) + rng.uniform(-6, 6))
        length = table(lengths, u) * rng.uniform(0.8, 1.25)
        curl = math.radians(rng.uniform(-4, 12)) * (1 if math.cos(angle) < 0 else -1)
        main = path(u, angle, length, curl)
        members = rng.choice((1, 2, 2, 3))
        for j in range(members):
            du = (j - (members - 1) / 2) * rng.uniform(2.6, 3.6)
            mine = path(min(max(u + du, u0), u1), angle + math.radians(rng.uniform(-5, 5)),
                        length * rng.uniform(0.82, 1.0), curl)
            pull = np.array([pt.smoothstep(0.35, 1.0, k / 8) for k in range(9)])[:, None] * 0.55
            pts = mine + (main - mine) * pull
            base = width * rng.uniform(0.85, 1.15) * (1.2 if length > 40 else 1.0)
            cover = np.maximum(cover, stroke([tuple(p) for p in pts], pt.taper(9, base, 0.2, power=1.2)))
        u += step * rng.uniform(0.75, 1.3) * (0.6 + 0.4 * members)
    return cover


# ---- the face ----


def face(sx, sy):
    """The face, its shadows and lines, and the dark round it (no eye, no hair): flat greys with crisp shadow shapes,
    as your colour frame paints it, its outlines mostly left to the tones."""
    canvas = np.empty((H, W, 3), np.float32)
    canvas[:] = BG
    skin_area = 1 - fill(FACE_EDGE + UNDERSIDE[1:] + FACE_FOOT + [(1670, 942)])
    # A gentle light: brightest round the eye, a little lower toward the top of the frame and the lower left.
    lit = 0.86 + 0.14 * pt.smoothstep(-0.2, 0.9, (sx / SW) * 0.45 + (1 - sy / SH) * 0.35)
    lit *= 1 - 0.08 * pt.smoothstep(260, 0, sy) * pt.smoothstep(300, 900, sx)
    lit += 0.05 * np.exp(-(((sx - 600) / 330) ** 2) - (((sy - 420) / 220) ** 2))
    skin = np.empty_like(canvas)
    skin[:] = SKIN
    skin *= lit[..., None]
    # The shadow above the eye: a plane a shade down, its edge crisp along the line.
    above = fill([(250, 0)] + BROW_LINE[::-1] + [(330, 280), (250, 300)])
    shade(skin, above * 0.3)
    # The nose and mouth's plane, turned from the light: flat, a touch deeper along its top edge and lighter low on its
    # right; the light caught in a strip along its foot and up its far edge.
    plane = fill(rounded(NOSE_TOP) + FACE_EDGE[10:] + UNDERSIDE[1:-1] + [(1060, 668), (1040, 600), (1030, 540)])
    near_top = distance_to(NOSE_TOP[:16], sx, sy)
    tone = np.empty_like(canvas)
    tone[:] = PLANE
    tone *= (0.9 + 0.1 * pt.smoothstep(0, 60, near_top) + 0.08 * pt.smoothstep(1150, 1480, sx))[..., None]
    pt.over(skin, tone, plane)
    foot = distance_to(UNDERSIDE, sx, sy)
    edge = distance_to(FACE_EDGE, sx, sy)
    strip = np.clip(0.5 + (21 - foot) * K, 0, 1) * pt.smoothstep(1055, 1095, sx)
    strip = np.maximum(strip, np.clip(0.5 + (17 - edge) * K, 0, 1) * pt.smoothstep(560, 640, sy))
    pt.over(skin, STRIP, plane * strip)
    # Skin, not paper: the faintest grain.
    skin *= (1 + (pt.noise(H, W, 3, 11, 2) - 0.5) * 0.02 + (pt.noise(H, W, 80, 12, 3) - 0.5) * 0.03)[..., None]
    pt.over(canvas, skin, skin_area)
    # The nostril: a dark slash with a darker heart, its edges soft.
    nostril = pt.blur(fill(NOSTRIL), 0.8)
    pt.over(canvas, (0.2, 0.192, 0.19), nostril)
    pt.over(canvas, (0.11, 0.105, 0.105), np.clip(nostril * 2 - 1, 0, 1) * 0.8)
    # The few lines the frame keeps: the shadow's edge over the eye faint, the lid's fold and the lines off its corner.
    lines = [
        (BROW_LINE, 1.6, 0.6, 0.3),
        (CREASE, 1.5, 0.4, 0.4),
    ] + [(b, 1.3, 0.3, 0.32) for b in BRIDGE]
    for points, width, tip, alpha in lines:
        n = len(points)
        widths = [tip + (width - tip) * math.sin(math.pi * (k / (n - 1)) * 0.98 + 0.01) ** 0.5 for k in range(n)]
        pt.over(canvas, INK, stroke(points, widths) * alpha)
    return canvas, skin_area


# ---- the eye ----


def eye(canvas, eye_model, openness, sx, sy):
    """The eye at an openness over the face: the eyeball through the lids, the lids' bands and lines, the lashes."""
    u, v = eye_uv(sx, sy)
    top, bot = eye_model.lids(u, openness)
    inside = (u > U0) & (u < U1)
    seen = np.where(inside, np.clip(0.5 + (v - top) * K, 0, 1) * np.clip(0.5 + (bot - v) * K, 0, 1), 0.0)
    ball = np.empty((H, W, 3), np.float32)
    ball[:] = SCLERA
    ball *= (1 - 0.18 * np.clip(np.abs(u - 245) / 220, 0, 1) ** 2)[..., None]
    # The iris.
    cx, cy, rx, ry = IRIS
    ex, ey = (sx - cx) / rx, (sy - cy) / ry
    r = np.hypot(ex, ey)
    iris = np.zeros((H, W, 3), np.float32)
    iris[:] = (0.4, 0.015, 0.08)
    qx, qy = ex * 80, ey * 80
    rng = random.Random(7)
    spokes = np.zeros((H, W), np.float32)
    n = 30
    for k in range(n):
        a = 2 * math.pi * (k + rng.uniform(-0.18, 0.18)) / n
        r0 = 0.42 + rng.uniform(0, 0.06)
        r1 = 0.8 - rng.uniform(0, 0.09)
        w = rng.uniform(1.8, 2.6)
        if rng.random() < 0.35:
            mid = rng.uniform(r0 + 0.1, r1 - 0.1)
            pieces = ((r0, mid - 0.035), (mid + 0.035, r1))
        else:
            pieces = ((r0, r1),)
        for p0, p1 in pieces:
            c, s = math.cos(a), math.sin(a)
            spokes = np.maximum(spokes, capsule(qx, qy, c * p0 * 80, s * p0 * 80, c * p1 * 80, s * p1 * 80, w))
    pt.over(iris, (1.0, 0.5, 0.6), spokes * 0.92)
    pt.over(iris, (0.56, 0.03, 0.14), pt.smoothstep(0.8, 0.84, r))
    pt.over(iris, (0.95, 0.4, 0.5), np.clip(1 - np.abs(r - 0.865) / 0.012, 0, 1) * 0.45)
    pt.over(iris, (0.16, 0.0, 0.04), pt.smoothstep(0.885, 0.93, r))
    pt.over(iris, (0.5, 0.04, 0.12), pt.smoothstep(0.42, 0.37, r))
    pt.over(iris, (0.2, 0.0, 0.03), pt.smoothstep(0.345, 0.325, r))
    pt.over(iris, (0.015, 0.0, 0.004), pt.smoothstep(PUPIL + 0.012, PUPIL - 0.012, r))
    # (its left side in shadow as drawn, and light caught low on its right)
    iris *= (0.72 + 0.28 * pt.smoothstep(-0.9, 0.5, ex))[..., None]
    catch = pt.smoothstep(0.45, 0.85, r) * pt.smoothstep(0.85, 1.0, 1 - r)
    catch *= pt.smoothstep(0.1, 0.9, ex * 0.4 + ey * 0.9)
    iris += (catch * 0.25)[..., None] * np.array([1.0, 0.2, 0.35], np.float32)
    pt.over(ball, iris, np.clip((1 - r) * rx * K + 0.5, 0, 1))
    # The glint.
    (gx, gy), half, wide, ga = GLINT
    gc, gs = math.cos(ga), math.sin(ga)
    glint = capsule(sx * K, sy * K, (gx - gc * half) * K, (gy - gs * half) * K, (gx + gc * half) * K,
                    (gy + gs * half) * K, wide * K)
    ball += (pt.blur(glint, 6) * 0.25)[..., None]
    pt.over(ball, (1.0, 0.99, 0.99), glint)
    # The lid's shadow over the top of the eye, a softer one along the lower lid.
    ball *= (0.55 + 0.45 * pt.smoothstep(0, 22, v - top))[..., None]
    ball *= (0.86 + 0.14 * pt.smoothstep(0, 12, bot - v))[..., None]
    # The inner corner's pink.
    pt.over(ball, (0.66, 0.52, 0.53), pt.smoothstep(408, 428, u) * 0.9)
    pt.over(canvas, ball, seen)
    # The lid, shut or partly so: the skin over the eyeball catches the light in its middle.
    over_ball = inside * np.clip(0.5 + (top - v) * K, 0, 1) * np.clip(0.5 + (v - eye_model.lids(u, 1.0)[0]) * K, 0, 1)
    swell = np.exp(-(((u - 240) / 170) ** 2) - (((v - 40) / 70) ** 2))
    canvas *= (1 + over_ball * swell * 0.08)[..., None]
    # The upper lid's band: the heavy lash line, the lid's rim under it, the fine edge; the socket's shade over it.
    line_v = eye_model.lash_line(u, openness)
    rim = (u > -17) & (u < U1)
    socket = np.where((u > -30) & (u < U1 + 10), pt.smoothstep(50, 0, line_v - v) * (v < line_v), 0.0)
    shade(canvas, socket * 0.26 * np.clip(np.sin(np.clip((u + 30) / (U1 + 40), 0, 1) * math.pi), 0, 1))
    band = np.where(rim, np.clip(0.5 + (v - line_v) * K, 0, 1) * np.clip(0.5 + (top - v) * K, 0, 1), 0.0)
    depth = np.clip((v - line_v) / np.maximum(top - line_v, 1), 0, 1)
    band_rgb = np.empty_like(canvas)
    band_rgb[:] = (0.46, 0.45, 0.47)
    band_rgb *= (0.3 + 0.7 * depth ** 1.6)[..., None]
    pt.over(canvas, band_rgb, band)
    for share in (0.36, 0.68):
        at = line_v + (top - line_v) * share
        pt.over(canvas, INK, np.where(rim, np.clip(1 - np.abs(v - at) / 0.7, 0, 1) * 0.2, 0.0))
    heavy = 2.5 + 5.5 * np.clip(np.sin(np.clip((u + 17) / (U1 + 17), 0, 1) * math.pi), 0, 1) ** 0.6
    ink = np.where(rim, np.clip(0.5 + (v - line_v + 1) * K, 0, 1) * np.clip(0.5 + (line_v + heavy - v) * K, 0, 1), 0.0)
    pt.over(canvas, INK, ink)
    edge = np.where(inside, np.clip(1 - np.abs(v - top) / 1.1, 0, 1), 0.0)
    pt.over(canvas, INK, edge * 0.9)
    # The lower lid: its edge, a light rim, its lash line; the band between thick toward the outer corner.
    low = eye_model.lower_line(u, openness)
    rim_low = (u > -11) & (u < U1)
    band_low = np.where(rim_low, np.clip(0.5 + (v - bot) * K, 0, 1) * np.clip(0.5 + (low - v) * K, 0, 1), 0.0)
    thick = pt.smoothstep(10, 30, low - bot)
    across = np.clip((v - bot) / np.maximum(low - bot, 1), 0, 1)
    low_rgb = np.empty_like(canvas)
    low_rgb[:] = (0.7, 0.69, 0.71)
    dark_band = np.empty_like(canvas)
    dark_band[:] = (0.1, 0.095, 0.105)
    dark_band *= (1.9 - 0.9 * across)[..., None]
    pt.over(low_rgb, dark_band, thick * (0.4 + 0.6 * openness))
    pt.over(canvas, low_rgb, band_low)
    pt.over(canvas, INK, np.where(inside, np.clip(1 - np.abs(v - bot) / 1.0, 0, 1), 0.0) * 0.9)
    pt.over(canvas, INK, np.where(rim_low, np.clip(1 - np.abs(v - low) / 1.0, 0, 1), 0.0) * 0.85)
    under = np.where(rim_low, pt.smoothstep(30, 14, v - low) * (v > low), 0.0)
    shade(canvas, under * 0.45)
    # The lashes, the shadows they throw on the eye and the lid under them, then the lashes themselves.
    up = lashes_along(eye_model.lash_line, UP_DIR, UP_LEN, -17, 462, 10.0, 21, 4.2, openness)
    lo = lashes_along(eye_model.lower_line, LO_DIR, LO_LEN, -11, 455, 9.0, 22, 2.6, openness)
    lo *= 0.55 + 0.45 * openness
    shade(canvas, pt.blur(shifted(up, -3, 8), 2.2) * seen * 0.5, (0.5, 0.5, 0.6))
    shade(canvas, pt.blur(shifted(np.maximum(up, lo), -4, 6), 3.0) * (1 - seen) * 0.22)
    pt.over(canvas, INK, np.maximum(up, lo))
    return np.maximum(np.maximum(up, lo), np.maximum(band, band_low))


# ---- the hair ----


def lips(canvas, mask, sx, sy):
    """The mouth, up in the corner: your shapes there in the soft flat grey of a lip in shade, a little deeper along the
    parting, the parting itself a dark line tapering out to the corner's point, as your colour frame paints them."""
    soft = pt.blur(mask, 1.6)
    deeper = pt.smoothstep(34, 4, distance_to(MOUTH_PARTING, sx, sy))
    canvas *= (1 - soft * (0.33 + 0.1 * deeper))[..., None]
    for points, width, tip, alpha in ((MOUTH_PARTING, 4.2, 0.8, 0.85), (MOUTH_EDGE, 2.2, 0.6, 0.6)):
        n = len(points)
        widths = [width + (tip - width) * (k / (n - 1)) ** 1.5 for k in range(n)]
        pt.over(canvas, (0.12, 0.112, 0.112), pt.blur(stroke(points, widths), 0.6) * alpha)


def hair(dark, eye_zone, sx, sy):
    """The hair where the pencil is dense (and the mouth's shapes, which the pencil drew as densely): the hair in front
    on its own layer. Painted as your colour
    frame's hair is: near-black locks, a little lighter through their bodies than at their edges, with long thin
    streaks of dull warm sheen running the way your pencil runs, tapering out at both ends."""
    d = resample(dark)
    dense = pt.smoothstep(0.12, 0.2, pt.blur(d, 4.3 * K))
    dense = pt.smoothstep(0.38, 0.62, pt.blur(dense, 1.6))
    # (the narrow gaps the pencil left between strokes closed: they are part of the lock, not holes through it)
    dense = np.maximum(dense, pt.smoothstep(0.22, 0.42, pt.blur(dense, 4.5 * K)))
    front = dense * fill(HAIR_FRONT_ZONE) * (1 - eye_zone)
    # (no crumbs: only hair joined to a lock of some thickness stays, and the small gaps left in it close)
    solid = front > 0.5
    keep = flow.joined(solid, flow.shrink(solid.astype(np.float32), 7) > 0.5)
    front = front * flow.grow(keep.astype(np.float32), 2)
    front = np.maximum(front, flow.close(front, 5))
    mouth = dense * fill(MOUTH_ZONE)
    # The locks: their bodies (where the pencil was lighter) a little up from black, their edges down to it.
    body = 1 - pt.smoothstep(0.25, 0.85, pt.blur(d, 6 * K))
    rgb = np.empty((H, W, 3), np.float32)
    rgb[:] = HAIR_BASE
    pt.over(rgb, HAIR_BODY, body * 0.9)
    # (and the dark parting between one lock and the next, where your pencil drew their edges)
    parting = pt.smoothstep(0.5, 0.9, pt.blur(d, 1.4))
    rgb *= (1 - 0.45 * parting)[..., None]
    # The sheen: sparse seeds smeared along the strokes' way into long streaks, a fine set and a broad soft one.
    fx, fy, _ = flow.orientation(d, 2.0, 12.0)
    rng = np.random.default_rng(5)
    on = dense > 0.5

    def streaks(density, soften, length):
        seeds = (rng.random((H, W)) < density) * rng.uniform(0.35, 1.0, (H, W))
        smeared = flow.lic(pt.blur(seeds.astype(np.float32), soften), fx, fy, length, 1.0)
        return np.clip(smeared / max(float(np.percentile(smeared[on], 99.3)), 1e-6), 0, 1)

    fine = streaks(0.0022, 0.7, 42.0) ** 1.2
    broad = pt.blur(streaks(0.0005, 2.4, 80.0), 1.5)
    sheen = np.clip(0.75 * fine + 0.55 * broad, 0, 1)
    # (brighter through the lock bodies and toward the light, dimmer deep in the lower left)
    light = pt.smoothstep(-0.1, 0.8, (sx / SW) * 0.5 + (1 - sy / SH) * 0.6)
    sheen *= (0.35 + 0.65 * body) * (0.35 + 0.65 * light)
    pt.over(rgb, HAIR_SHEEN, sheen)
    rgb *= (0.6 + 0.4 * light)[..., None]
    return np.clip(rgb, 0, 1), front, mouth


# ---- the whole ----


def finish(canvas, openness, window):
    """The red light of an open eye on what is round it, a soft bloom, the dark at the edges, the grade."""
    ys, xs = pt.grid(H, W)
    if openness > 0.25:
        cx, cy = P(IRIS[0], IRIS[1])
        d = np.hypot(xs - cx, (ys - cy) * 1.2) / (IRIS[2] * K)
        glow = np.exp(-((d / 2.2) ** 2)) * (openness - 0.25) / 0.75
        x0, y0, x1, y1 = window
        inset = 50
        held = pt.smoothstep(x0 + 4, x0 + inset, xs) * (1 - pt.smoothstep(x1 - inset, x1 - 4, xs))
        held *= pt.smoothstep(y0 + 4, y0 + inset, ys) * (1 - pt.smoothstep(y1 - inset, y1 - 4, ys))
        canvas += (glow * held)[..., None] * np.array([0.07, 0.0, 0.02], np.float32)
    bright = np.clip(canvas - 0.9, 0, None)
    canvas += pt.blur(bright, 12) * 0.25
    vx, vy = (xs - 980) / 1150, (ys - 430) / 700
    edge = np.sqrt(vx * vx + vy * vy)
    canvas *= (1 - 0.6 * pt.smoothstep(0.5, 1.25, edge))[..., None]
    lum = canvas.mean(axis=-1)
    canvas[..., 0] *= 1 + 0.05 * (lum - 0.45)
    canvas[..., 2] *= 1 - 0.05 * (lum - 0.45)
    np.clip(canvas, 0, 1, out=canvas)


class Picture:
    def __init__(self):
        self.dark = pencil()
        self.sx, self.sy = sketch_grid()
        self.eye_model = Eye()
        self.face, self.skin = face(self.sx, self.sy)
        # Where the eye is (open and shut, with its lashes) the pencil is the eye's, not hair.
        scratch = self.face.copy()
        drawn = np.maximum(eye(scratch, self.eye_model, 1.0, self.sx, self.sy),
                           eye(scratch.copy(), self.eye_model, 0.0, self.sx, self.sy))
        u, v = eye_uv(self.sx, self.sy)
        top, bot = self.eye_model.lids(u, 1.0)
        white = ((u > U0) & (u < U1) & (v > top - 2) & (v < bot + 2)).astype(np.float32)
        zone = np.maximum(np.clip(pt.blur(np.maximum(drawn, white), 5 * K) * 4, 0, 1), fill(EYE_KEEP))
        # (its edge rounded, so no lock ends ragged on it)
        self.eye_zone = pt.smoothstep(0.25, 0.6, pt.blur(zone, 7 * K))
        self.hair_rgb, self.front, self.mouth = hair(self.dark, self.eye_zone, self.sx, self.sy)
        # The shadow the hair in front throws on the face goes with it on its layer (it is nearer, and moves).
        self.front_shadow = cast(self.front, 26) * (1 - self.front) * 0.4
        # (and the skin sinks into shade where hair lies close over it)
        self.occlusion = pt.blur(self.front, 22 * K) * self.skin * 0.35
        ys, xs = np.nonzero(self.eye_zone > 0.02)
        pad = 40
        self.window = (max(0, int(xs.min()) - pad), max(0, int(ys.min()) - pad), min(W, int(xs.max()) + pad),
                       min(H, int(ys.max()) + pad))

    def render(self, openness):
        canvas = self.face.copy()
        eye(canvas, self.eye_model, openness, self.sx, self.sy)
        shade(canvas, self.occlusion)
        lips(canvas, self.mouth, self.sx, self.sy)
        finish(canvas, openness, self.window)
        return canvas

    def near(self):
        """The hair in front with the shadow it throws: a touch out of focus, darkened as the rest is."""
        tone = np.zeros((H, W, 3), np.float32)
        tone[:] = 0.5
        finish(tone, 0.0, self.window)
        hair_rgb = self.hair_rgb * (tone / 0.5)
        rgb = np.empty((H, W, 3), np.float32)
        rgb[:] = SHADOW
        alpha = np.zeros((H, W), np.float32)
        pt.layer_over(rgb, alpha, SHADOW, self.front_shadow)
        pt.layer_over(rgb, alpha, hair_rgb, self.front)
        for c in range(3):
            rgb[..., c] = pt.blur(rgb[..., c], 1.4)
        return rgb, pt.blur(alpha, 1.5)


def main():
    os.makedirs(OUT, exist_ok=True)
    pic = Picture()
    shut = pic.render(0.0)
    half = W // 2
    png.write(os.path.join(OUT, "IntroBaseL.png"), shut[:, :half])
    png.write(os.path.join(OUT, "IntroBaseR.png"), shut[:, half:])
    x0, y0, x1, y1 = pic.window
    frames = []
    for k, openness in enumerate(OPENINGS):
        frame = pic.render(openness)
        frames.append(frame)
        # (its edges feathered: outside the eye it is the shut face's own pixels, so the seam cannot show)
        piece = frame[y0:y1, x0:x1]
        ch, cw = piece.shape[:2]
        fy = np.minimum(np.arange(ch), np.arange(ch)[::-1])[:, None]
        fx = np.minimum(np.arange(cw), np.arange(cw)[::-1])[None, :]
        feather = np.clip(np.minimum(fy, fx) / 20.0, 0, 1).astype(np.float32)
        png.write(os.path.join(OUT, f"IntroEye{k + 1}.png"), np.concatenate([piece, feather[..., None]], -1))
        print("[eye] frame", k + 1, openness)
    hair_rgb, hair_alpha = pic.near()
    rgba = np.concatenate([hair_rgb, hair_alpha[..., None]], axis=-1)
    png.write(os.path.join(OUT, "IntroHairL.png"), rgba[:, :half])
    png.write(os.path.join(OUT, "IntroHairR.png"), rgba[:, half:])
    # The preview: shut and open as the game lays them (the hair over both), and the sketch.
    sheet = []
    for image in (shut, frames[-1]):
        shown = image.copy()
        pt.over(shown, hair_rgb, hair_alpha)
        sheet.append(shown)
    sketch = np.repeat((1 - resample(pic.dark) * 0.85)[..., None], 3, axis=2)
    sheet.append(sketch)
    png.write(PREVIEW, np.concatenate(sheet, axis=0))
    ex, ey = P(IRIS[0], IRIS[1])
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/ui/eye_intro.py. Do not edit by hand.",
        "-- The first join's painted eye (UI/EyeIntro): the picture's size in px, where the eye's crop (IntroEye1..4) lies",
        "-- in it and where the eye itself is (the slow push-in closes on it), as shares of the picture.",
        "",
        "return {",
        f"\tsize = Vector2.new({W}, {H}),",
        f"\tcrop = {{ x = {x0 / W:.5f}, y = {y0 / H:.5f}, w = {(x1 - x0) / W:.5f}, h = {(y1 - y0) / H:.5f} }},",
        f"\teye = Vector2.new({ex / W:.4f}, {ey / H:.4f}),",
        f"\tframes = {len(OPENINGS)},",
        "}",
    ]
    with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("[eye] wrote", LUAU)


if __name__ == "__main__":
    main()
