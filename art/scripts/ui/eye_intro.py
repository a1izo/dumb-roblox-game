"""The first join's eye (UI/EyeIntro), painted after your pencil sketch (art/refs/ui/eye_sketch.png, 2026-10-27): a
face in close profile, the eye wide under a heavy lid, the nose turned away, hair falling across from the left and
rising in points from below; coloured and lit after your two frames (grey skin, the nose's plane in shade, black beyond
the profile, dark hair with lighter strands, the eye red). Every shape of the face and the eye is placed from the sketch
(measured on it, sketch px); the hair is the sketch's own strokes: where it is drawn, its outline, and the way its
strands run (art/scripts/ui/flow.py follows the pencil), painted over in dark locks with lighter strands.

Painted in layers, so the game can move them apart a little for depth:

    IntroBaseL, IntroBaseR   the face with the eye shut, the hair behind, the light (two halves, 896 x 1008 each)
    IntroEye1..4             the eye's corner of the picture as it opens (a third, more than half, most of the way, open),
                             laid exactly over the face (EYE_CROP)
    IntroHairL, IntroHairR   the hair rising in front from below, with the shade it casts (transparent, two halves)

It also writes src/client/UI/EyeArt.luau (where the eye's crop and the eye itself sit in the picture) and a preview,
art/export/previews/intro_eye.png (shut and open, as the game lays them). The sketch's hair (its outline and strands)
takes about a minute and is kept between runs in the temp folder.

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/ui/eye_intro.py
"""

import hashlib
import math
import os
import random
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flow  # noqa: E402
import paint as pt  # noqa: E402
import png  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SKETCH = os.path.join(ROOT, "art", "refs", "ui", "eye_sketch.png")
OUT = os.path.join(ROOT, "art", "export", "textures")
PREVIEW = os.path.join(ROOT, "art", "export", "previews", "intro_eye.png")
LUAU = os.path.join(ROOT, "src", "client", "UI", "EyeArt.luau")

# The picture (each half fits Roblox's 1024 px limit); every shape below is in the sketch's px (1670 x 942).
W, H = 1792, 1008
SW, SH = 1670, 942
KX, KY = W / SW, H / SH
K = (KX + KY) / 2
OPENINGS = (0.3, 0.58, 0.84, 1.0)
SHUT = 0.2  # where the shut lids meet, down the open eye (0 the upper lid's line, 1 the lower's)
EYE_CROP = (240, 190, 840, 640)  # (x0, y0, x1, y1), sketch px: everything the opening changes

# The face, measured on the sketch -----------------------------------------------------------------------------------

BROW = [(368, 212), (380, 182), (396, 160), (420, 147), (450, 135), (500, 121), (540, 110), (575, 95), (625, 70),
        (670, 45), (700, 25), (745, 0)]
UPPER = [(333, 303), (360, 316), (380, 320), (410, 322), (440, 324), (480, 333), (520, 344), (560, 360), (600, 378),
         (640, 403), (680, 432), (710, 458), (740, 486), (767, 504)]
LOWER = [(333, 303), (350, 330), (365, 360), (380, 388), (400, 416), (420, 450), (440, 480), (460, 500), (500, 528),
         (540, 546), (580, 544), (620, 534), (660, 529), (700, 515), (730, 502), (767, 504)]
IRIS = (560.0, 480.0, 92.0, 71.0)  # middle, half width, half height (an ellipse: the eye is turned from us)
PUPIL = (27.0, 25.0)
GLINT = ((462, 430), (518, 462), 12.0)  # a capsule: its two ends and half its width
NOSE_TOP = [(1000, 505), (1050, 460), (1110, 410), (1150, 372), (1200, 332), (1250, 306), (1290, 289), (1320, 288),
            (1350, 296), (1400, 315), (1440, 333), (1475, 350), (1490, 365), (1497, 382), (1500, 420), (1503, 470),
            (1505, 515)]
PROFILE = [(1670, 293), (1655, 330), (1630, 360), (1600, 380), (1570, 398), (1545, 425), (1527, 452), (1515, 478),
           (1505, 515), (1508, 550), (1512, 590), (1508, 625), (1500, 655), (1488, 682), (1472, 708), (1458, 725),
           (1448, 735)]
NOSE_BOTTOM = [(1448, 735), (1420, 723), (1390, 713), (1350, 704), (1300, 697), (1250, 693), (1200, 688),
               (1160, 684), (1125, 680), (1090, 674), (1050, 665)]
NOSTRIL = [(1368, 345), (1360, 380), (1356, 410), (1370, 440), (1388, 475), (1402, 515), (1395, 470), (1385, 430),
           (1375, 395)]
UNDER_EYE = [(470, 590), (550, 596), (650, 581), (750, 548), (800, 528)]
CORNER_SHADE = [(690, 395), (740, 418), (796, 476), (802, 516), (770, 506), (735, 470), (700, 430)]

# The hair: what the sketch draws there is hair, but for these (the eye and its lashes, and the face's own lines).
# (its lower left follows the lock that falls across the eye's outer corner, which stays hair)
EYE_KEEP = [(268, 236), (300, 228), (345, 243), (420, 212), (560, 238), (700, 326), (805, 430), (805, 520), (760, 578),
            (600, 600), (470, 592), (420, 548), (405, 500), (395, 455), (380, 420), (360, 385), (340, 352), (300, 372),
            (268, 330)]
FACE_LINES = [(BROW, 14), (NOSE_TOP, 14), (PROFILE, 22), (NOSE_BOTTOM, 14)]
# Places that are surely skin or the dark beyond (a paper gap the hair closes round, not reached from these, is a gap
# between strands: a lighter strand)
OPEN = [(900, 150), (600, 250), (1300, 500), (1600, 800), (1640, 60), (1560, 350), (560, 480), (700, 560), (1350, 850),
        (1050, 560), (1200, 450), (880, 480)]
# Where the sketch's hair is redrawn: scraps by the eye's outer corner (pencil lashes, the lid's lines) and under it go,
# and the lock that falls across the corner is drawn whole, tapering up to it.
HAIR_CLEAN = [[(300, 335), (352, 340), (395, 420), (418, 470), (436, 545), (345, 545), (330, 450), (300, 420)],
              [(640, 578), (714, 578), (714, 614), (640, 614)]]
HAIR_ADD = [[(337, 328), (350, 360), (368, 400), (386, 445), (400, 490), (412, 540), (424, 600), (432, 660), (400, 700),
             (350, 700), (345, 620), (340, 540), (336, 460), (333, 400), (333, 360)]]
# The hair in front: the points rising from below and the locks crossing under the eye from the left.
NEAR_ZONE = [(470, 950), (455, 800), (470, 690), (520, 640), (640, 615), (790, 560), (830, 400), (950, 330), (1010, 420),
             (1100, 520), (1200, 600), (1330, 690), (1480, 740), (1480, 950)]

SKIN = (1.0, 0.985, 0.99)
INK = (0.02, 0.018, 0.02)
DARK = (0.012, 0.011, 0.013)


def P(x, y):
    return (x * KX, y * KY)


def scaled(points):
    return [P(x, y) for x, y in points]


def fill(points):
    return pt.fill(scaled(points), W, H)


def stroke(points, widths):
    if np.isscalar(widths):
        widths = [widths] * len(points)
    return pt.fill(pt.outline(scaled(points), [w * K for w in widths]), W, H)


def shifted(mask, dx, dy):
    """`mask` moved by (dx, dy) px, what comes in empty (no wrapping round)."""
    out = np.zeros_like(mask)
    h, w = mask.shape
    dx, dy = int(dx), int(dy)
    ys = slice(max(dy, 0), h + min(dy, 0))
    xs = slice(max(dx, 0), w + min(dx, 0))
    yd = slice(max(-dy, 0), h + min(-dy, 0))
    xd = slice(max(-dx, 0), w + min(-dx, 0))
    out[ys, xs] = mask[yd, xd]
    return out


def sketch_grid():
    """Every pixel's place on the sketch (x, y), sketch px."""
    ys, xs = pt.grid(H, W)
    return xs / KX, ys / KY


def along(line, xs):
    """The line's y at each of `xs` (the line runs left to right)."""
    a = np.asarray(line, np.float64)
    return np.interp(xs, a[:, 0], a[:, 1])


def gauss(x, y, cx, cy, rx, ry):
    return np.exp(-(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2))


# The sketch's hair --------------------------------------------------------------------------------------------------

def _key():
    h = hashlib.sha1()
    with open(SKETCH, "rb") as f:
        h.update(f.read())
    with open(os.path.join(HERE, "flow.py"), "rb") as f:
        h.update(f.read())
    h.update(repr((W, H, EYE_KEEP, FACE_LINES, OPEN, HAIR_CLEAN, HAIR_ADD, 6)).encode())  # (bump when the reading changes)
    return h.hexdigest()[:16]


def reached(free, seeds):
    """What of `free` (bool) is joined to the `seeds` (bool), at half size: grown a pixel at a time until it stops."""
    small = flow.resample(free.astype(np.float32), H // 2, W // 2) > 0.5
    have = flow.resample(seeds.astype(np.float32), H // 2, W // 2) > 0.05
    have &= small
    for _ in range(4000):
        grown = have.copy()
        grown[1:] |= have[:-1]
        grown[:-1] |= have[1:]
        grown[:, 1:] |= have[:, :-1]
        grown[:, :-1] |= have[:, 1:]
        grown &= small
        if (grown == have).all():
            break
        have = grown
    return flow.resample(have.astype(np.float32), H, W)


def sketch_hair():
    """From the sketch: `mask` (where the hair is, 0..1), `smooth` (its pencil smeared along the strands: dark where
    it is drawn dense, light in the gaps between) and `fine` (noise smeared along them: single strands)."""
    path = os.path.join(tempfile.gettempdir(), f"dg_eye_hair_{_key()}.npz")
    if os.path.exists(path):
        got = np.load(path)
        return {k: got[k] for k in got.files}
    print("[eye] reading the sketch's hair (about a minute; kept for next time)")
    lum = png.read(SKETCH)[..., 0].astype(np.float32) / 255.0
    dark = np.clip((0.9 - flow.resample(lum, H, W)) / 0.55, 0, 1)
    wipe = fill(EYE_KEEP)
    for line, width in FACE_LINES:
        wipe = np.maximum(wipe, stroke(line, width))
    wipe = np.maximum(wipe, stroke(NOSTRIL + NOSTRIL[:1], 16))
    wipe = np.maximum(wipe, fill(NOSTRIL))
    drawn = pt.smoothstep(0.18, 0.4, pt.blur(dark * (1 - wipe), 1.5)) > 0.5
    mask = flow.close(drawn.astype(np.float32), 5)
    # (the paper left inside it, joined to no open place, is a gap between strands: hair too)
    seeds = np.zeros((H, W), bool)
    for x, y in OPEN:
        px, py = P(x, y)
        seeds[int(py) - 3: int(py) + 4, int(px) - 3: int(px) + 4] = True
    outside = reached(mask < 0.5, seeds)
    mask = np.maximum(mask, 1 - outside) > 0.5
    # Bits too thin to be a lock and joined to none (stray marks, the ends of the face's lines) go; a lock's thin
    # point stays, joined to its body.
    mask = flow.joined(mask, flow.shrink(mask.astype(np.float32), 4) > 0.5)
    for poly in HAIR_CLEAN:
        mask &= fill(poly) < 0.5
    for poly in HAIR_ADD:
        mask |= fill(poly) > 0.5
    vx, vy, _ = flow.orientation(dark, 1.2, 7.0)
    # (its outline smoothed along the strands, where the pencil wobbles, its points kept sharp)
    mask = flow.lic(mask.astype(np.float32), vx, vy, 5)
    mask = pt.smoothstep(0.4, 0.6, pt.blur(mask, 0.9))
    smooth = flow.lic(pt.blur(dark, 0.8), vx, vy, 22)
    rng = np.random.default_rng(3)
    maps = {"mask": mask.astype(np.float32), "smooth": smooth.astype(np.float32)}
    # Noise smeared along the strands, short (single hairs) and long (the strands of light down a lock).
    for name, length in (("fine", 24), ("long", 46)):
        streaks = flow.lic(rng.random((H, W)).astype(np.float32), vx, vy, length)
        maps[name] = ((streaks - streaks.mean()) / (streaks.std() + 1e-6)).astype(np.float32)
    np.savez_compressed(path, **maps)
    return maps


def hair_colour(maps, mask, near):
    """The hair's colour (h, w, 3): near black, lighter strands where the sketch leaves gaps between its strokes, the
    light falling on it from the eye's side, a lit edge on its outline toward the light."""
    x, y = sketch_grid()
    gap = np.clip((0.74 - maps["smooth"]) / 0.58, 0, 1) ** 1.35
    if near:
        light = 0.42 + 0.58 * gauss(x, y, 760, 420, 560, 360)
        light *= 1 - 0.55 * pt.smoothstep(640, 950, y)
    else:
        light = 0.32 + 0.68 * gauss(x, y, 520, 470, 460, 330)
        light *= 1 - 0.35 * pt.smoothstep(0, 260, -(x - 140))  # (darker toward the left edge)
        light = np.maximum(light, 1.7 * gauss(x, y, 1560, 150, 190, 210))  # the locks at the top right, in the light
    # Near black, a dull sheen where the sketch leaves room between its strokes, long thin strands of light down the
    # locks (more of them in that sheen), single hairs here and there.
    strands = pt.smoothstep(1.45, 2.4, maps["long"]) * (0.3 + 0.7 * gap)
    hairs = pt.smoothstep(1.5, 2.5, maps["fine"]) * gap
    value = 0.02 + light * (0.03 + 0.21 * gap ** 1.4 + 0.4 * strands + 0.08 * hairs)
    value += 0.01 * maps["fine"] * (0.3 + gap)
    # The edge toward the light (up and to the right) catches it.
    soft = pt.blur(mask, 2.0 * K)
    gy, gx = np.gradient(soft)
    norm = np.sqrt(gx * gx + gy * gy) + 1e-6
    facing = np.clip((-gx * 0.55 + gy * 0.83) / norm, 0, 1)  # (the outward normal is -grad)
    edge = mask * (1 - pt.smoothstep(0.55, 0.95, pt.blur(mask, 3.0 * K)))
    value += 0.22 * edge * facing * light
    value = np.clip(value, 0, 1)
    warm = np.stack([value * 1.03, value * 0.975, value * 0.955], -1)
    return warm + np.array([0.002, 0.002, 0.006], np.float32)


# The face -----------------------------------------------------------------------------------------------------------

def face(canvas):
    x, y = sketch_grid()
    # Skin, lit from the front and left: brightest beside the eye, a little less toward the top and the nose.
    tone = 0.6 + 0.21 * gauss(x, y, 760, 380, 620, 420)
    tone += 0.05 * gauss(x, y, 1200, 120, 500, 220)
    tone -= 0.06 * pt.smoothstep(450, 250, x) * pt.smoothstep(150, 0, y)
    # A painted skin: broad mottling and a fine grain.
    tone *= 0.975 + 0.05 * pt.noise(H, W, 120, 11)
    tone *= 0.988 + 0.024 * pt.noise(H, W, 4, 12, octaves=2)
    canvas[:] = np.stack([tone * SKIN[0], tone * SKIN[1], tone * SKIN[2]], -1)
    # The brow, in shade above its line (a plane turned from the light, its edge crisp).
    brow = pt.blur(fill(BROW + [(780, -30), (240, -30), (240, 260)]), 1.3 * K)
    shade = 0.5 + 0.17 * pt.smoothstep(520, 780, x) - 0.05 * pt.smoothstep(200, 0, y)
    canvas *= (1 - brow * (1 - shade))[..., None]
    # The socket round the eye, soft, and the shade in its inner corner (crisp, as the sketch hatches it).
    canvas *= (1 - 0.1 * gauss(x, y, 560, 420, 260, 150))[..., None]
    canvas *= (1 - 0.22 * pt.blur(fill(CORNER_SHADE), 3 * K))[..., None]
    lid = pt.blur(fill(UPPER + [(767, 470), (700, 400), (600, 330), (500, 296), (400, 284), (333, 290)]), 6 * K)
    canvas *= (1 - 0.1 * lid)[..., None]
    # The fold under the eye, faint.
    pt.over(canvas, (0.4, 0.39, 0.4), pt.blur(stroke(UNDER_EYE, pt.taper(len(UNDER_EYE), 3, 1, start=1)), 1.5) * 0.35)
    # The nose: its side turned from the light, a flat plane of shade (lighter toward its foot), the light caught
    # along its foot, the nostril.
    side = NOSE_TOP + PROFILE[9:] + NOSE_BOTTOM[1:] + [(960, 660), (890, 640), (920, 560)]
    plane = pt.blur(fill(side), 1.2 * K)
    nose = 0.43 + 0.07 * pt.smoothstep(470, 690, y) - 0.04 * pt.smoothstep(1380, 1500, x)
    nose *= 0.985 + 0.03 * pt.noise(H, W, 60, 13)
    pt.over(canvas, np.stack([nose * 1.02, nose * 0.96, nose * 0.96], -1), plane)
    foot = [(x0, y0 - 16) for x0, y0 in NOSE_BOTTOM[:-1]]
    lit = pt.blur(stroke(foot, pt.taper(len(foot), 22, 6, start=8)), 5 * K) * plane
    canvas += (0.2 * lit)[..., None]
    nostril = pt.blur(fill(NOSTRIL), 1.0 * K)
    pt.over(canvas, (0.1, 0.085, 0.09), nostril * 0.9)
    # The dark beyond the profile and under the nose, its edge caught by a thin rim of light.
    beyond = PROFILE + NOSE_BOTTOM[1:] + [(990, 662), (860, 652), (800, 980), (1700, 980), (1700, 280)]
    edge = pt.blur(fill(beyond), 0.8 * K)
    deep = 0.012 + 0.025 * gauss(x, y, 1560, 560, 160, 260)
    pt.over(canvas, np.stack([deep, deep * 0.95, deep * 1.15], -1), edge)
    rim = [(px - 5, py) for px, py in PROFILE[:12]]
    fade = 1 - 0.6 * pt.smoothstep(380, 660, y)
    pt.over(canvas, (0.95, 0.94, 0.96), pt.blur(stroke(rim, pt.taper(len(rim), 4, 2, start=2)), 1.4 * K) * 0.5 * fade)


# The eye -------------------------------------------------------------------------------------------------------------

XS = np.linspace(333, 767, 160)


def lids(openness, xs=XS):
    """The upper lid's edge (its lashes' line) and the lower lid's at `xs`. Shut, they meet on one line a little under
    the open upper lid's (as your shut frame draws it, the lashes along it pointing up); opening, they part."""
    up, low = along(UPPER, xs), along(LOWER, xs)
    shut = up + SHUT * (low - up)
    return shut + openness * (up - shut), shut + openness * (low - shut)


def lash(base, angle, length, width, bend):
    """A tapered lash from `base` (sketch px) at `angle` (degrees, y down), curling by `bend` (degrees) to its tip."""
    a0 = math.radians(angle)
    a1 = math.radians(angle + bend)
    mid = (base[0] + math.cos(a0) * length * 0.5, base[1] + math.sin(a0) * length * 0.5)
    tip = (mid[0] + math.cos(a1) * length * 0.5, mid[1] + math.sin(a1) * length * 0.5)
    pts = pt.quad(base, mid, tip, 14)
    return pt.fill(pt.outline(scaled(pts), [w * K for w in pt.taper(15, width, 0, power=1.3)]), W, H)


def eye(canvas, openness):
    x, y = sketch_grid()
    edge, low = lids(openness)
    up, under = along(UPPER, XS), along(LOWER, XS)
    edge_line = list(zip(XS, edge))
    # The lids over what they cover: the skin swelling over the eyeball beneath, a soft shade under the shut line.
    if openness < 1:
        cover = 1 - openness
        lid = fill(list(zip(XS, up - 4)) + list(zip(XS[::-1], under[::-1] + 4)))
        swell = gauss(x, y, 560, along(UPPER, x) + (along(LOWER, x) - along(UPPER, x)) * 0.5, 170, 55)
        canvas += (lid * swell * 0.06 * cover)[..., None]
        below = np.clip(y - along(edge_line, x), 0, None)
        canvas *= (1 - lid * 0.16 * cover * np.exp(-below / 14) * (below > 0))[..., None]
        fold = list(zip(XS[10:150], under[10:150] + 6))
        pt.over(canvas, (0.36, 0.35, 0.37), pt.blur(stroke(fold, pt.taper(len(fold), 3.0, 0.6, start=0.8)), 1.6 * K)
                * 0.4 * cover)
    if openness > 0.02:
        opening = fill(edge_line + list(zip(XS[::-1], low[::-1])))
        below = np.clip(y - along(edge_line, x), 0, None)
        # The white: in the lid's shade under its edge, darker toward the corners, a little cold.
        shade = 0.42 + 0.58 * pt.smoothstep(0, 50, below)
        shade *= 1 - 0.32 * pt.smoothstep(120, 230, np.abs(x - 560))
        shade *= 1 - 0.12 * pt.smoothstep(470, 545, y)
        white = np.stack([0.87 * shade, 0.865 * shade, 0.885 * shade], -1)
        pt.over(canvas, white, opening)
        iris(canvas, opening, shade, openness)
        # The inner corner, pink-grey and wet.
        corner = pt.ellipse(*P(750, 500), 13 * K, 7 * K, W, H, angle=0.3)
        pt.over(canvas, (0.62, 0.5, 0.52), pt.blur(corner, 1.2 * K) * pt.smoothstep(0.1, 0.4, openness))
        # The lower lid's wet rim catching the light.
        wet = list(zip(XS[20:150], low[20:150] - 3))
        pt.over(canvas, (0.93, 0.92, 0.94), pt.blur(stroke(wet, 1.8), 0.8) * 0.4 * openness)
    # The lower lid (it shows as the eye opens): the line of its rim below, its edge, its lashes.
    showing = pt.smoothstep(0.0, 0.6, openness)
    rim = list(zip(XS[8:154], low[8:154] + 10))
    pt.over(canvas, (0.28, 0.27, 0.28), pt.blur(stroke(rim, pt.taper(len(rim), 2.8, 0.8, start=0.8)), 0.9 * K)
            * 0.6 * showing)
    lower_line = list(zip(XS[2:158], low[2:158]))
    pt.over(canvas, INK, stroke(lower_line, pt.taper(len(lower_line), 5.5, 2.0, start=3.0)) * 0.92 * showing)
    rng = random.Random(7)
    lashes = np.zeros((H, W), np.float32)
    if openness > 0.02:
        for k in range(44):
            bx = 384 + 362 * k / 43 + rng.uniform(-2, 2)
            t = (bx - 384) / 362
            angle = 126 - 56 * t + rng.uniform(-7, 7) + (5 if k % 3 == 0 else -4 if k % 3 == 2 else 0)
            length = (19 + 17 * math.sin(math.pi * min(1, t * 1.25)) + rng.uniform(-4, 5) + 6 * (k % 4 == 0))
            length *= 0.45 + 0.55 * showing
            by = float(along(list(zip(XS, low)), bx)) + 3
            lashes = np.maximum(lashes, lash((bx, by), angle, length, 3.4, 12 - 24 * t))
    # The upper lid's rim: its outer line, the band of the lid's thickness, the heavy lash line.
    top = list(zip(XS[4:152], edge[4:152] - 14))
    band = fill(list(zip(XS[2:156], edge[2:156] - 14)) + list(zip(XS[155:1:-1], edge[155:1:-1])))
    pt.over(canvas, (0.34, 0.33, 0.34), pt.blur(band, 0.8) * 0.85)
    pt.over(canvas, INK, stroke(top, pt.taper(len(top), 4.0, 1.2, start=2.4)) * 0.9)
    crease = [(px, py - (46 - 30 * pt.smoothstep(560, 720, px))) for px, py in zip(XS[25:140], up[25:140])]
    pt.over(canvas, (0.3, 0.29, 0.31), pt.blur(stroke(crease, pt.taper(len(crease), 2.8, 0.6, start=0.8)), 1.2 * K)
            * 0.55)
    widths = np.interp(np.linspace(0, 1, len(edge_line)), [0, 0.06, 0.4, 0.85, 1], [9, 17, 13, 8, 3])
    pt.over(canvas, INK, stroke(edge_line, list(widths)))
    # The upper lashes: a long fan out of the outer corner, short ones along the lid in little clumps, a few up out of
    # the inner end.
    for k in range(15):
        t = k / 14
        bx = 333 + 44 * t
        by = float(along(edge_line, bx)) - 3 - 10 * t
        angle = 166 + 90 * t + rng.uniform(-5, 5)
        length = 72 - 30 * t + rng.uniform(-8, 6)
        lashes = np.maximum(lashes, lash((bx, by), angle, length, 5.2, 16 + 6 * t))
    for k in range(34):
        bx = 382 + 318 * k / 33 + rng.uniform(-3, 3)
        by = float(along(edge_line, bx)) - 14
        t = (bx - 382) / 318
        clump = (5 if k % 3 == 0 else -5 if k % 3 == 2 else 0)
        angle = 250 + 42 * t ** 2 + clump + rng.uniform(-6, 6)
        length = 17 + 11 * (k % 3 == 1) + 9 * (1 - t) + rng.uniform(-3, 4)
        lashes = np.maximum(lashes, lash((bx, by), angle, length, 3.8, 10))
    for k in range(7):
        bx = 700 + 8 * k
        by = float(along(edge_line, bx)) - 7
        lashes = np.maximum(lashes, lash((bx, by), 298 + 4 * k, 22 - 1.5 * k, 3.0, 8))
    pt.over(canvas, INK, lashes)


def iris(canvas, opening, shade, openness):
    x, y = sketch_grid()
    cx, cy, rx, ry = IRIS
    u, v = (x - cx) / rx, (y - cy) / ry
    d = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)
    disc = pt.ellipse(*P(cx, cy), rx * KX, ry * KY, W, H) * opening
    # Red: bright toward the pupil, deep toward the rim; spokes of lighter red out from the pupil, as the sketch draws
    # them; a ring round the pupil; the dark rim.
    bright = np.array([0.86, 0.07, 0.12], np.float32)
    deep = np.array([0.36, 0.0, 0.05], np.float32)
    mix = pt.smoothstep(0.3, 0.95, d)[..., None]
    col = bright * (1 - mix) + deep * mix
    wobble = 0.5 * pt.noise(H, W, 10, 31)
    spokes = (0.5 + 0.5 * np.sin(ang * 30 + wobble)) ** 5
    reach = pt.smoothstep(0.36, 0.42, d) * (1 - pt.smoothstep(0.7, 0.82, d))
    col = col + (spokes * reach)[..., None] * np.array([0.42, 0.14, 0.14], np.float32)
    col *= (1 - 0.35 * (1 - spokes) * reach)[..., None]
    ring = np.exp(-(((d - 0.36) / 0.035) ** 2))
    col += ring[..., None] * np.array([0.3, 0.05, 0.06], np.float32)
    rimmed = pt.smoothstep(0.82, 0.97, d)
    col *= (1 - 0.82 * rimmed)[..., None]
    pupil = 1 - pt.smoothstep(0.93, 1.05, np.sqrt(((x - cx) / PUPIL[0]) ** 2 + ((y - cy) / PUPIL[1]) ** 2))
    col = col * (1 - pupil[..., None]) + np.array([0.05, 0.0, 0.012], np.float32) * pupil[..., None]
    pt.over(canvas, col * shade[..., None], disc)
    # The glints: the long one up on the left, as drawn, and a small one low on the right.
    (ax, ay), (bx, by), half = GLINT
    capsule = pt.fill(pt.outline(scaled(pt.quad((ax, ay), ((ax + bx) / 2, (ay + by) / 2 - 2), (bx, by), 20)),
                                 [half * 2 * K * s for s in np.sqrt(np.clip(1 - np.linspace(-1, 1, 21) ** 6, 0, 1))]),
                      W, H)
    pt.over(canvas, (1.0, 0.97, 0.97), pt.blur(capsule, 0.9 * K) * opening * 0.96)
    small = pt.ellipse(*P(cx + 0.46 * rx, cy + 0.36 * ry), 6 * K, 5 * K, W, H)
    pt.over(canvas, (1.0, 0.9, 0.9), pt.blur(small, 0.8) * opening * 0.7)


# The hair in the picture ---------------------------------------------------------------------------------------------

def zones():
    x, y = sketch_grid()
    near = pt.blur(fill(NEAR_ZONE), 10 * K)
    # (the near hair's foot, low in the picture, has more hair behind it: the face there stays hair if it moves)
    behind = pt.smoothstep(660, 790, y)
    return near, behind


def back_hair(canvas, maps, shadow=True):
    near, behind = zones()
    # (with the near hair over it, it covers just what the sketch's hair does: where the near layer fades out at its
    # zone's edge, the hair behind is whole, so nothing shows through, nor when the near layer drifts)
    z = near * (1 - behind)
    hair = maps["mask"]
    mask = hair * (1 - z) / np.maximum(1 - hair * z, 1e-4)
    if shadow:
        # The hair shades the skin beside it (the light from the front and left: its shade falls right and down),
        # crisp-edged as a cel shadow, softer the further it falls.
        drop = np.maximum(pt.blur(shifted(mask, 12 * K, 7 * K), 1.6 * K) * 0.3,
                          pt.blur(shifted(mask, 22 * K, 13 * K), 7 * K) * 0.18)
        canvas *= (1 - drop)[..., None]
    pt.over(canvas, hair_colour(maps, maps["mask"], near=False), mask)


def near_shadow(canvas, maps):
    near, _ = zones()
    hair = maps["mask"] * near
    drop = np.maximum(pt.blur(shifted(hair, 10 * K, 7 * K), 1.6 * K) * 0.34,
                      pt.blur(shifted(hair, 20 * K, 14 * K), 6 * K) * 0.2)
    canvas *= (1 - drop)[..., None]


def front_hair(maps):
    """The near hair, an RGBA layer."""
    near, _ = zones()
    alpha = (maps["mask"] * near).astype(np.float32)
    rgb = hair_colour(maps, maps["mask"], near=True)
    return rgb, alpha


# The picture ---------------------------------------------------------------------------------------------------------

def finish(canvas, openness):
    """The red light of an open eye on what is round it, a soft bloom, the dark at the corners, the grade."""
    x, y = sketch_grid()
    if openness > 0.25:
        cx, cy, rx, _ = IRIS
        d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / rx
        glow = np.exp(-((d / 2.2) ** 2)) * (openness - 0.25) / 0.75
        # (held inside the eye's crop, so the crop lies over the shut face without a seam)
        x0, y0, x1, y1 = EYE_CROP
        inset = 45
        window = pt.smoothstep(x0 + 4, x0 + inset, x) * (1 - pt.smoothstep(x1 - inset, x1 - 4, x))
        window *= pt.smoothstep(y0 + 4, y0 + inset, y) * (1 - pt.smoothstep(y1 - inset, y1 - 4, y))
        canvas += (glow * window)[..., None] * np.array([0.05, 0.0, 0.006], np.float32)
    bright = np.clip(canvas - 0.84, 0, None)
    canvas += pt.blur(bright, 12 * K) * 0.35
    vx, vy = (x - 820) / 1000, (y - 450) / 640
    edge = np.sqrt(vx * vx + vy * vy)
    canvas *= (1 - 0.5 * pt.smoothstep(0.6, 1.3, edge))[..., None]
    # The shadows a touch cold, the lights a touch warm.
    lum = canvas.mean(axis=-1)
    canvas[..., 0] *= 1 + 0.04 * (lum - 0.4)
    canvas[..., 2] *= 1 - 0.04 * (lum - 0.4)
    np.clip(canvas, 0, 1, out=canvas)


def render(openness, maps):
    canvas = np.zeros((H, W, 3), np.float32)
    face(canvas)
    near_shadow(canvas, maps)
    eye(canvas, openness)
    back_hair(canvas, maps)
    finish(canvas, openness)
    return canvas


def crop_px():
    x0, y0, x1, y1 = EYE_CROP
    (a, b), (c, d) = P(x0, y0), P(x1, y1)
    return int(a), int(b), int(c), int(d)


def main():
    os.makedirs(OUT, exist_ok=True)
    maps = sketch_hair()
    quick = "--preview" in sys.argv
    shut = render(0.0, maps)
    half = W // 2
    x0, y0, x1, y1 = crop_px()
    frames = []
    for k, openness in enumerate(OPENINGS):
        if quick and openness < 1:
            continue
        frame = render(openness, maps)
        frames.append(frame)
        if quick:
            continue
        # (its edges feathered: outside the eye it is the shut face's own pixels, so the seam cannot show)
        piece = frame[y0:y1, x0:x1]
        ch, cw = piece.shape[:2]
        fy = np.minimum(np.arange(ch), np.arange(ch)[::-1])[:, None]
        fx = np.minimum(np.arange(cw), np.arange(cw)[::-1])[None, :]
        feather = np.clip(np.minimum(fy, fx) / 20.0, 0, 1).astype(np.float32)
        png.write(os.path.join(OUT, f"IntroEye{k + 1}.png"), np.concatenate([piece, feather[..., None]], -1))
        print("[eye] frame", k + 1, openness)
    hair_rgb, hair_alpha = front_hair(maps)
    if not quick:
        png.write(os.path.join(OUT, "IntroBaseL.png"), shut[:, :half])
        png.write(os.path.join(OUT, "IntroBaseR.png"), shut[:, half:])
        rgba = np.concatenate([hair_rgb, hair_alpha[..., None]], axis=-1)
        png.write(os.path.join(OUT, "IntroHairL.png"), rgba[:, :half])
        png.write(os.path.join(OUT, "IntroHairR.png"), rgba[:, half:])
    # The preview: shut and open, as the game lays them (the near hair over both).
    sheet = []
    for image in (shut, frames[-1]):
        shown = image.copy()
        pt.over(shown, hair_rgb, hair_alpha)
        sheet.append(shown)
    png.write(PREVIEW, np.concatenate(sheet, axis=0))
    print("[eye] wrote", PREVIEW)
    if quick:
        return
    cx, cy = P(IRIS[0], IRIS[1])
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/ui/eye_intro.py. Do not edit by hand.",
        "-- The first join's painted eye (UI/EyeIntro): the picture's size in px, where the eye's crop (IntroEye1..4) lies",
        "-- in it and where the eye itself is (the slow push-in closes on it), as shares of the picture.",
        "",
        "return {",
        f"\tsize = Vector2.new({W}, {H}),",
        f"\tcrop = {{ x = {x0 / W:.5f}, y = {y0 / H:.5f}, w = {(x1 - x0) / W:.5f}, h = {(y1 - y0) / H:.5f} }},",
        f"\teye = Vector2.new({cx / W:.4f}, {cy / H:.4f}),",
        f"\tframes = {len(OPENINGS)},",
        "}",
    ]
    with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("[eye] wrote", LUAU)


if __name__ == "__main__":
    main()
