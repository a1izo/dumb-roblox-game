"""The first join's eye (UI/EyeIntro), painted (2026-10-27, after the owner's references: a face in close profile in the
dark, hair falling across it, the eye shut; then it opens, red). Painted in layers with art/scripts/ui/paint.py, so the
game can move them apart a little for depth:

    IntroBaseL, IntroBaseR   the face with the eye shut, the back hair, the light (two halves, 896 x 1008 each)
    IntroEye1..4             the eye's corner of the picture as it opens (a quarter, half, most of the way, open), laid
                             exactly over the face (EYE_CROP)
    IntroHairL, IntroHairR   the hair in the foreground, out of focus, with its shadow (transparent, two halves)

It also writes src/client/UI/EyeArt.luau (where the eye's crop and the eye itself sit in the picture) and a preview,
art/export/previews/intro_eye.png (shut and open, as the game lays them).

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/ui/eye_intro.py
"""

import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import paint as pt  # noqa: E402
import png  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "art", "export", "textures")
PREVIEW = os.path.join(ROOT, "art", "export", "previews", "intro_eye.png")
LUAU = os.path.join(ROOT, "src", "client", "UI", "EyeArt.luau")

# Designed on a 2048 x 1152 sheet, painted at S of it (each half fits Roblox's 1024 px limit).
S = 0.875
W, H = int(2048 * S), int(1152 * S)
EYE = (640.0, 520.0)  # the eye's middle (design px)
TILT = math.radians(16)  # the eye's line falls toward the nose
A = 236.0  # half the eye's width
B_UP = 112.0  # its upper lid over the middle, open
B_LO = 58.0  # its lower lid under the middle
IRIS_R = 112.0
IRIS_AT = (0.04, -18.0)  # the iris's middle in the eye's frame (its top tucked under the upper lid, its foot under the lower)
EYE_CROP = (280, 210, 1000, 800)  # (x0, y0, x1, y1), design px: everything the opening changes
OPENINGS = (0.3, 0.58, 0.84, 1.0)

INK = (0.025, 0.024, 0.03)
HAIR = (0.055, 0.05, 0.062)
HAIR_LIT = (0.3, 0.285, 0.32)


def P(x, y):
    return (x * S, y * S)


def scaled(points):
    return [P(x, y) for x, y in points]


def fill(points):
    return pt.fill(scaled(points), W, H)


def stroke(points, widths):
    return pt.fill(pt.outline(scaled(points), [w * S for w in widths]), W, H)


# The eye's own frame: u along it (-1 the outer corner, at the left; +1 the inner one), v down from its line.
def to_screen(u, v):
    x, y = u * A, v
    c, s = math.cos(TILT), math.sin(TILT)
    return (EYE[0] + x * c - y * s, EYE[1] + x * s + y * c)


def upper(u):
    return -B_UP * np.maximum(0.0, 1 - u * u) ** 0.72 * (1 - 0.2 * u)


def lower(u):
    return B_LO * np.maximum(0.0, 1 - u * u) ** 1.15 * (1 + 0.12 * u)


def lid(u, openness):
    shut = lower(u) * 0.9
    return shut + (upper(u) - shut) * openness


def curve(fn, u0=-1.0, u1=1.0, n=72):
    return [to_screen(float(u), float(fn(u))) for u in np.linspace(u0, u1, n)]


# The face ------------------------------------------------------------------------------------------------------

# Its profile against the dark (design px, top to bottom): brow, the bridge and tip of the nose, under it, the lip.
PROFILE = [(1872, -20), (1900, 80), (1930, 190), (1958, 280), (1966, 340), (1975, 400), (1992, 480), (2018, 570),
           (2042, 640), (2036, 668), (2004, 690), (1958, 702), (1906, 712), (1866, 726), (1846, 752), (1818, 790),
           (1772, 852), (1716, 930), (1650, 1020), (1580, 1170)]
RIDGE = [(1750, -20), (1800, 140), (1860, 300), (1925, 450), (1990, 590), (2030, 650)]


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


def face(canvas):
    ys, xs = pt.grid(H, W)
    xd, yd = xs / S, ys / S  # design px
    # The light: high on the right (the cheek and the temple), falling away under the hair to the left and below.
    key = np.exp(-(((xd - 1420) / 860) ** 2 + ((yd - 300) / 640) ** 2))
    tone = 0.46 + 0.4 * key
    tone *= 0.72 + 0.28 * pt.smoothstep(-100, 900, xd)
    tone += 0.05 * np.exp(-(((xd - 1260) / 260) ** 2 + ((yd - 430) / 160) ** 2))  # the cheekbone
    # The socket round the eye, the shade under the brow, the hollow by the nose.
    tone -= 0.13 * np.exp(-(((xd - 660) / 300) ** 2 + ((yd - 500) / 230) ** 2))
    tone -= 0.08 * np.exp(-(((xd - 640) / 380) ** 2 + ((yd - 250) / 70) ** 2))
    tone -= 0.06 * np.exp(-(((xd - 1050) / 160) ** 2 + ((yd - 600) / 240) ** 2))
    # A painted skin: broad mottling and a fine grain.
    tone *= 0.97 + 0.06 * pt.noise(H, W, 140 * S, 11)
    tone *= 0.985 + 0.03 * pt.noise(H, W, 5, 12, octaves=2)
    skin = np.stack([tone * 0.97, tone * 0.975, tone], axis=-1)
    canvas[:] = skin
    # The nose's side, turned from the light, and the shadow under it.
    side = pt.blur(fill(RIDGE + PROFILE[:9][::-1]), 6 * S)
    canvas *= (1 - 0.3 * side)[..., None]
    under = pt.blur(fill([(1700, 690), (2048, 640), (2048, 760), (1760, 800)]), 18 * S)
    canvas *= (1 - 0.35 * under)[..., None]
    # The nose's wing and the crease beside it, drawn in.
    pt.over(canvas, INK, pt.blur(stroke(pt.quad((1838, 560), (1866, 610), (1852, 664)), pt.taper(31, 9, 1)), 0.8) * 0.65)
    pt.over(canvas, INK, pt.blur(stroke(pt.quad((1632, 372), (1676, 420), (1694, 488)), pt.taper(31, 7, 0.5)), 1) * 0.5)
    # The dark beyond the profile, its edge caught by a thin rim of light.
    beyond = fill(PROFILE + [(2100, 1200), (2100, -40)])
    pt.over(canvas, (0.012, 0.012, 0.016), beyond)
    rim = pt.blur(stroke([(x - 9, y) for x, y in PROFILE[:12]], [5] * 3 + [4] * 6 + [3] * 3), 1.6 * S)
    pt.over(canvas, (0.93, 0.93, 0.96), rim * 0.55)


def iris(canvas, openness):
    """The iris and what lies on it: red, fibres and a ring of marks, the dark rim, the pupil, the glints."""
    ys, xs = pt.grid(H, W)
    cx, cy = to_screen(*IRIS_AT)
    cx, cy = cx * S, cy * S
    r = IRIS_R * S
    dx, dy = xs - cx, ys - cy
    d = np.sqrt(dx * dx + dy * dy) / r
    ang = np.arctan2(dy, dx)
    inside = np.clip(1.0 + (1.0 - d) * r, 0, 1)  # (anti-aliased disc)
    fibre = 0.5 + 0.5 * np.sin(ang * 46 + 5 * pt.noise(H, W, 9, 31))
    bright = np.stack([np.full_like(d, 0.98), np.full_like(d, 0.12), np.full_like(d, 0.15)], -1)
    deep = np.stack([np.full_like(d, 0.42), np.full_like(d, 0.0), np.full_like(d, 0.035)], -1)
    mix = pt.smoothstep(0.32, 1.0, d)[..., None]
    col = bright * (1 - mix) + deep * mix
    col *= (0.82 + 0.3 * fibre * pt.smoothstep(0.3, 0.5, d) * (1 - pt.smoothstep(0.85, 0.95, d)))[..., None]
    # a ring of fine marks, as if written round it
    marks = (0.5 + 0.5 * np.sin(ang * 34)) ** 8 * pt.smoothstep(0.58, 0.62, d) * (1 - pt.smoothstep(0.7, 0.74, d))
    col += marks[..., None] * np.array([0.6, 0.18, 0.18], np.float32)
    rim = pt.smoothstep(0.84, 0.97, d)
    col *= (1 - 0.8 * rim)[..., None]
    pupil = 1 - pt.smoothstep(0.26, 0.31, d)
    col = col * (1 - pupil[..., None]) + np.array([0.05, 0.0, 0.01], np.float32) * pupil[..., None]
    halo = np.exp(-(((d - 0.36) / 0.06) ** 2))
    col += halo[..., None] * np.array([0.25, 0.02, 0.03], np.float32)
    return col, inside, (cx, cy, r)


def eye(canvas, openness):
    ys, xs = pt.grid(H, W)
    # local frame per pixel (design px)
    c, s = math.cos(TILT), math.sin(TILT)
    rx, ry = xs / S - EYE[0], ys / S - EYE[1]
    lu = (rx * c + ry * s) / A
    lv = -rx * s + ry * c
    edge_pts = curve(lambda u: lid(u, openness))
    low_pts = curve(lower)
    # The upper lid's surface: shaded toward its edge; when shut, the eyeball's swell under it.
    swell = np.exp(-((lu / 0.75) ** 2 + ((lv - lid(0, openness) + 38) / 50) ** 2))
    canvas += (0.05 * swell * (1 - openness))[..., None]
    if openness > 0.02:
        opening = fill(edge_pts + low_pts[::-1])
        u_c = np.clip(lu, -1, 1)
        edge_v = lid(u_c, openness)
        below = np.clip(lv - edge_v, 0, None)
        shade = 0.42 + 0.58 * pt.smoothstep(0, 60, below)
        shade *= 1 - 0.35 * pt.smoothstep(0.45, 1.0, np.abs(lu))
        shade *= 1 - 0.12 * pt.smoothstep(0, 1, (lv - 10) / 50)
        sclera = np.stack([0.7 * shade, 0.705 * shade, 0.74 * shade], -1)
        pt.over(canvas, sclera, opening)
        col, disc, (cx, cy, r) = iris(canvas, openness)
        lidshade = (0.45 + 0.55 * pt.smoothstep(0, 46, below))[..., None]
        pt.over(canvas, col * lidshade, disc * opening)
        # the glints: a big soft one up on the left, a small one low on the right
        glint = pt.ellipse(cx - 0.36 * r, cy - 0.4 * r, 0.32 * r, 0.17 * r, W, H, angle=-0.55)
        pt.over(canvas, (1, 0.97, 0.97), pt.blur(glint, 1.2) * opening * 0.95)
        pt.over(canvas, (1, 0.9, 0.9), pt.ellipse(cx + 0.42 * r, cy + 0.34 * r, 0.07 * r, 0.07 * r, W, H) * opening * 0.7)
        # the inner corner and the lower lid's wet edge
        corner = pt.ellipse(*P(*to_screen(0.93, 8)), 15 * S, 9 * S, W, H, angle=TILT)
        pt.over(canvas, (0.7, 0.6, 0.62), pt.blur(corner, 1.2) * pt.smoothstep(0.1, 0.4, openness))
        wet = stroke(curve(lambda u: lower(u) + 4, -0.85, 0.8), pt.taper(72, 3, 1, start=1))
        pt.over(canvas, (0.92, 0.92, 0.94), pt.blur(wet, 0.8) * 0.3 * openness)
    # The crease over the lid, soft.
    crease = curve(lambda u: upper(u) * (1.22 + 0.1 * openness) - 22, -0.86, 0.55)
    pt.over(canvas, (0.24, 0.24, 0.27), pt.blur(stroke(crease, pt.taper(72, 5, 0.5, start=2)), 1.4 * S) * 0.55)
    # The lash line: heavy, thickest at the outer corner, flicking out past it.
    line = curve(lambda u: lid(u, openness), -1.0, 0.96, 80)
    first = np.array(line[0])
    # (a short flick past the outer corner, along the line's own way out)
    way = first - np.array(line[3])
    way = way / (np.linalg.norm(way) or 1.0)
    wing = first + way * 46 + np.array([0.0, 8.0])
    line = [tuple(wing), tuple(first + way * 22)] + line
    widths = [1, 9] + list(np.interp(np.linspace(0, 1, 80), [0, 0.1, 0.5, 1], [19, 20, 13, 6]))
    pt.over(canvas, INK, stroke(line, widths))
    # The lashes: hanging down and out while it is shut, swept up and out once it is open; longer at the outer corner.
    rng = random.Random(5)
    for k in range(54):
        u = -1.0 + 1.86 * k / 53 + rng.uniform(-0.012, 0.012)
        base = np.array(to_screen(u, lid(u, openness) - 2))
        out = (1 - u) / 2
        # (in clumps: every third lash a little longer)
        length = 30 + 64 * out ** 1.1 + (10 if k % 3 == 0 else 0) + rng.uniform(-6, 6)
        down = math.radians(100 + 38 * out)  # (screen angle, y down: below the line and outward)
        up = math.radians(-100 - 40 * out)
        a = down + (up - down) * openness + TILT
        tip = base + length * np.array([math.cos(a), math.sin(a)])
        bend = a + (-0.5 if openness > 0.5 else 0.5) * (0.4 + out)
        mid = base + 0.55 * length * np.array([math.cos(bend), math.sin(bend)])
        lash = pt.quad(tuple(base), tuple(mid), tuple(tip), 18)
        pt.over(canvas, INK, stroke(lash, pt.taper(19, 4.8 + 2.4 * out, 0, power=1.25)))
    if openness > 0.45:
        pt.over(canvas, (0.1, 0.1, 0.12), stroke(curve(lambda u: lower(u) + 2, -0.95, 0.85, 60),
                                                  pt.taper(60, 4, 1.5, start=2)) * 0.8)
        for k in range(16):
            u = -0.92 + 1.6 * k / 15
            base = np.array(to_screen(u, lower(u) + 3))
            out = (1 - u) / 2
            length = (12 + 16 * out) * pt.smoothstep(0.45, 0.9, openness)
            a = math.radians(95 + 30 * out) + TILT
            tip = base + length * np.array([math.cos(a), math.sin(a)])
            pt.over(canvas, (0.08, 0.08, 0.1), stroke([tuple(base), tuple(tip)], [2.4, 0]) * 0.9)


def lock(rng, base, tip, width, bend, streaks=4, n=44):
    """A lock of hair from `base` to a point at `tip`: its body, and the thin lighter streaks of strands along it.
    Returns (body polygon, [(streak polygon, strength)]) in design px."""
    mid = ((base[0] + tip[0]) / 2 + bend, (base[1] + tip[1]) / 2 + rng.uniform(-30, 30))
    pts = pt.quad(base, mid, tip, n)
    body = pt.outline(pts, pt.taper(n + 1, width, 0, power=1.5))
    lines = []
    arr = np.asarray(pts)
    for k in range(streaks):
        off = rng.uniform(-0.32, 0.32) * width
        start = rng.randint(2, n // 3)
        end = rng.randint(n // 2, n - 4)
        seg = arr[start:end]
        if len(seg) < 4:
            continue
        d = np.gradient(seg, axis=0)
        normal = np.stack([-d[:, 1], d[:, 0]], -1) / np.maximum(np.linalg.norm(d, axis=1, keepdims=True), 1e-6)
        fade = np.linspace(1, 0.2, len(seg))[:, None]
        line = seg + normal * off * fade
        lines.append((pt.outline([tuple(p) for p in line], pt.taper(len(seg), rng.uniform(2.0, 5.5), 0.3)),
                      rng.uniform(0.35, 0.75)))
    return body, lines


def draw_lock(canvas_or_layer, body, lines, tone, lit, alpha_layer=None, strength=1.0):
    mask = fill(body)
    if alpha_layer is None:
        pt.over(canvas_or_layer, tone, mask * strength)
    else:
        pt.layer_over(canvas_or_layer, alpha_layer, tone, mask * strength)
    for poly, amount in lines:
        streak = pt.blur(fill(poly), 0.7 * S) * mask
        if alpha_layer is None:
            pt.over(canvas_or_layer, lit, streak * amount * strength)
        else:
            pt.layer_over(canvas_or_layer, alpha_layer, lit, streak * amount * strength)
    return mask


def back_locks():
    """The hair behind and to the left, as (body, streaks) locks: a dark mass down the left, locks falling from the top
    left over the brow (none over the eye: they stop at its brow), a few at the top right, and loose wisps."""
    rng = random.Random(21)
    locks = []
    for k in range(40):
        x0 = rng.uniform(-220, 760)
        y0 = rng.uniform(-200, -30)
        length = rng.uniform(300, 700)
        ang = math.radians(rng.uniform(58, 108))
        tip = (x0 + math.cos(ang) * length, y0 + math.sin(ang) * length)
        if tip[0] > 320 and tip[1] > 290:
            scale = (290 - y0) / max(tip[1] - y0, 1)
            tip = (x0 + (tip[0] - x0) * scale, y0 + (tip[1] - y0) * scale)
        locks.append(lock(rng, (x0, y0), tip, rng.uniform(40, 110), rng.uniform(-60, 60)))
    for k in range(18):  # down the left edge
        x0 = rng.uniform(-160, 180)
        y0 = rng.uniform(80, 1000)
        tip = (x0 + rng.uniform(20, 170), y0 + rng.uniform(240, 520))
        locks.append(lock(rng, (x0, y0), tip, rng.uniform(60, 140), rng.uniform(-40, 40)))
    for k in range(7):  # the top right
        x0 = rng.uniform(1250, 1900)
        y0 = rng.uniform(-160, -60)
        tip = (x0 + rng.uniform(-120, 60), y0 + rng.uniform(150, 300))
        locks.append(lock(rng, (x0, y0), tip, rng.uniform(30, 70), rng.uniform(-30, 30), streaks=2))
    return locks


WISPS = [  # loose single hairs over the face (design px): start, bend, end
    ((180, 150), (420, 230), (560, 200)),
    ((230, 330), (300, 250), (470, 190)),
    ((1500, -10), (1440, 140), (1500, 260)),
    ((260, 760), (420, 660), (560, 700)),
]


def back_hair(canvas):
    locks = back_locks()
    mass = [(-60, -60), (360, -60), (300, 60), (240, 200), (180, 380), (140, 600), (110, 820), (80, 1220),
            (-60, 1220)]
    pt.over(canvas, HAIR, pt.blur(fill(mass), 3 * S))
    for body, lines in locks:
        tone = np.array(HAIR, np.float32) * random.Random(len(body)).uniform(0.8, 1.25)
        draw_lock(canvas, body, lines, tone, HAIR_LIT)
    for a, b, c in WISPS:
        pts = pt.quad(a, b, c, 40)
        pt.over(canvas, (0.08, 0.075, 0.09), pt.blur(stroke(pts, pt.taper(41, 3.2, 0.4, start=1.2)), 0.5) * 0.7)


def hair_shadow(canvas):
    """The hard-edged shade the hair at the top left casts on the face (down and to the right of it), drawn before it."""
    union = np.zeros((H, W), np.float32)
    for body, _ in back_locks():
        union = np.maximum(union, fill(body))
    shade = pt.blur(shifted(union, 34 * S, 52 * S), 3.5 * S)
    canvas *= (1 - 0.34 * shade)[..., None]


def front_hair():
    """The foreground hair rising from below the frame across the bottom of the face, in locks, in three depths (the
    nearest the most out of focus), with the shadow it casts: an RGBA layer."""
    rgb = np.zeros((H, W, 3), np.float32)
    alpha = np.zeros((H, W), np.float32)
    rng = random.Random(9)
    bands = []
    for depth, (count, widths, blur_px, lift) in enumerate(((16, (36, 80), 0.6, 1.6), (12, (60, 130), 2.6, 1.25),
                                                            (8, (110, 210), 9.0, 1.0))):
        brgb = np.zeros((H, W, 3), np.float32)
        balpha = np.zeros((H, W), np.float32)
        for k in range(count):
            x0 = rng.uniform(-500, 1400)
            y0 = rng.uniform(1200, 1420)
            # (swept up and across to the right, as hair falling over a face turned down)
            lean = rng.uniform(0.15, 1.15)
            reach = rng.uniform(0.3, 0.62) if depth < 2 else rng.uniform(0.22, 0.42)
            ty = 1152 - reach * 1152
            tx = x0 + lean * (y0 - ty)
            # (tips rise highest beside the eye, never across it)
            if 300 < tx < 980 and ty < 730:
                ty = 730 + rng.uniform(0, 90)
            if 300 < x0 < 980 and ty < 740:
                ty = 750
            body, lines = lock(rng, (x0, y0), (tx, ty), rng.uniform(*widths), rng.uniform(-60, 180),
                               streaks=5 if depth < 2 else 3)
            tone = np.array(HAIR, np.float32) * rng.uniform(0.8, 1.7) * lift
            draw_lock(brgb, body, lines, tone, HAIR_LIT, balpha, strength=1.0)
        if blur_px > 0.5:
            premul = pt.blur(brgb * balpha[..., None], blur_px * S)
            balpha = pt.blur(balpha, blur_px * S)
            brgb = premul / np.maximum(balpha, 1e-5)[..., None]
        bands.append((brgb, balpha))
    # Its shadow on the face, under the strands (down and to the right of them, fairly hard).
    union = np.zeros((H, W), np.float32)
    for _, a in bands:
        union = union + a * (1 - union)
    shadow = pt.blur(shifted(union, 20 * S, 30 * S), 9 * S) * 0.5
    pt.layer_over(rgb, alpha, (0.0, 0.0, 0.01), shadow)
    for brgb, balpha in bands:
        pt.layer_over(rgb, alpha, brgb, balpha)
    return rgb, alpha

def finish(canvas, openness):
    """The red light of an open eye on what is round it, a soft bloom, the dark at the corners."""
    if openness > 0.25:
        ys, xs = pt.grid(H, W)
        cx, cy = to_screen(*IRIS_AT)
        d = np.sqrt((xs - cx * S) ** 2 + (ys - cy * S) ** 2) / (S * IRIS_R)
        glow = np.exp(-((d / 2.4) ** 2)) * (openness - 0.25) / 0.75
        # (held inside the eye's crop, so the crop lies over the shut face without a seam)
        x0, y0, x1, y1 = EYE_CROP
        inset = 50
        window = pt.smoothstep(x0 + 4, x0 + inset, xs / S) * (1 - pt.smoothstep(x1 - inset, x1 - 4, xs / S))
        window *= pt.smoothstep(y0 + 4, y0 + inset, ys / S) * (1 - pt.smoothstep(y1 - inset, y1 - 4, ys / S))
        glow *= window
        canvas += glow[..., None] * np.array([0.08, 0.0, 0.008], np.float32)
    bright = np.clip(canvas - 0.86, 0, None)
    canvas += pt.blur(bright, 14 * S) * 0.4
    ys, xs = pt.grid(H, W)
    vx, vy = (xs / S - 1060) / 1150, (ys / S - 520) / 760
    vig = 1 - 0.62 * pt.smoothstep(0.55, 1.25, np.sqrt(vx * vx + vy * vy))
    canvas *= vig[..., None]
    np.clip(canvas, 0, 1, out=canvas)


def render(openness):
    canvas = np.zeros((H, W, 3), np.float32)
    face(canvas)
    hair_shadow(canvas)
    eye(canvas, openness)
    back_hair(canvas)
    finish(canvas, openness)
    return canvas


def crop_px():
    x0, y0, x1, y1 = EYE_CROP
    return int(x0 * S), int(y0 * S), int(x1 * S), int(y1 * S)


def main():
    os.makedirs(OUT, exist_ok=True)
    shut = render(0.0)
    half = W // 2
    png.write(os.path.join(OUT, "IntroBaseL.png"), shut[:, :half])
    png.write(os.path.join(OUT, "IntroBaseR.png"), shut[:, half:])
    x0, y0, x1, y1 = crop_px()
    frames = []
    for k, openness in enumerate(OPENINGS):
        frame = render(openness)
        frames.append(frame)
        # (its edges feathered: outside the eye it is the shut face's own pixels, so the seam cannot show)
        piece = frame[y0:y1, x0:x1]
        ch, cw = piece.shape[:2]
        fy = np.minimum(np.arange(ch), np.arange(ch)[::-1])[:, None]
        fx = np.minimum(np.arange(cw), np.arange(cw)[::-1])[None, :]
        feather = np.clip(np.minimum(fy, fx) / 20.0, 0, 1).astype(np.float32)
        png.write(os.path.join(OUT, f"IntroEye{k + 1}.png"), np.concatenate([piece, feather[..., None]], -1))
        print("[eye] frame", k + 1, openness)
    hair_rgb, hair_alpha = front_hair()
    rgba = np.concatenate([hair_rgb, hair_alpha[..., None]], axis=-1)
    png.write(os.path.join(OUT, "IntroHairL.png"), rgba[:, :half])
    png.write(os.path.join(OUT, "IntroHairR.png"), rgba[:, half:])
    # The preview: shut and open, as the game lays them (the hair over both).
    sheet = []
    for image in (shut, frames[-1]):
        shown = image.copy()
        pt.over(shown, hair_rgb, hair_alpha)
        sheet.append(shown)
    png.write(PREVIEW, np.concatenate(sheet, axis=0))
    ex, ey = to_screen(*IRIS_AT)
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/ui/eye_intro.py. Do not edit by hand.",
        "-- The first join's painted eye (UI/EyeIntro): the picture's size in px, where the eye's crop (IntroEye1..4) lies",
        "-- in it and where the eye itself is (the slow push-in closes on it), as shares of the picture.",
        "",
        "return {",
        f"\tsize = Vector2.new({W}, {H}),",
        f"\tcrop = {{ x = {x0 / W:.5f}, y = {y0 / H:.5f}, w = {(x1 - x0) / W:.5f}, h = {(y1 - y0) / H:.5f} }},",
        f"\teye = Vector2.new({ex * S / W:.4f}, {ey * S / H:.4f}),",
        f"\tframes = {len(OPENINGS)},",
        "}",
    ]
    with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("[eye] wrote", LUAU)


if __name__ == "__main__":
    main()
