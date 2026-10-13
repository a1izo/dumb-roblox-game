"""The pictures on Death's Manual: the skull pressed into its cover, the ring and the rays around it,
its ruled pages and the edges of its sheets.

The skull is an old print (art/source/engravings, the Wellcome Collection's, under the Public Domain
Mark; see art/scripts/sources.py): its paper becomes the bone-white ink and its engraved lines the
black leather showing through, and its lower jaw is cut free and let down. The ring and the rays are
drawn here, each line from its own distance to the pixel, at four times the size they are kept at.
Nothing is made by an image generator.

Three covers were drawn for the owner to choose from (2026-10-12): the same skull in
    A  a woven ring with a row of pearls, and many fine rays
    B  a ring of beads, and a few long brush strokes
    C  two hairline rings, and very fine rays

Arrays are indexed [v, u] with v = 0 at the bottom, like Blender's pixel buffer. A cover is COVER
studs (across, up) and its pictures are `scale` pixels to the stud.
"""

import math
import os

import bpy
import numpy as np

import common
from maps import scanlib

COVER = (1.955, 2.7)  # the front board's face (the book is 2.0 across with its spine)
VARIANTS = ("A", "B", "C")

# The print, and what was marked on it by hand, in its own pixels (x across, y DOWN from the top).
PRINT = ("skull_anterior", "skull_anterior.jpg")
# Where the lower jaw parts from the skull: under the upper teeth, over the lower ones.
JAW_LINE = [(0, 1820), (500, 1820), (640, 1950), (700, 2000), (760, 2080), (850, 2160), (930, 2192), (985, 2199),
            (1010, 2186), (1085, 2180), (1120, 2105), (1220, 2100), (1400, 2085), (1545, 2078), (1557, 2052),
            (1633, 2084), (1665, 2082), (1720, 2060), (1800, 2030), (2373, 2030)]
JAW_DROP = 210  # how far the jaw is let down
# What the print shows beside the skull: the shadow it casts and the plate's number.
CAST = [(60, 1990), (540, 1990), (552, 2060), (600, 2190), (630, 2255), (690, 2355), (750, 2430), (850, 2560),
        (990, 2668), (1100, 2702), (1300, 2708), (1420, 2675), (1475, 2615), (1520, 2560), (1660, 2520), (1700, 2900),
        (60, 2900)]
BLANK = [(200, 200), (2150, 200), (2150, 2700), (200, 1800)]  # bare paper inside the plate's frame
MIDDLE = (1186, 1300)  # a point of the skull

DISC = 0.46  # the black disc the skull sits in (radius, studs)
SKULL_HEIGHT = 0.86
SKULL_LEFT = 0.04  # its lit side is its right: moved over, so what shows sits in the middle
BORDER = 0.10  # the pressed line that frames the cover, from its edge
REACH = 0.17  # how near the cover's edge the rays come

_made = {}


# Small tools -----------------------------------------------------------------------------------------


def _blur(a, sigma):
    """A Gaussian blur (through the Fourier domain; the edges are mirrored, so nothing wraps round)."""
    pad = int(3 * sigma) + 1
    wide = np.pad(a, pad, mode="reflect")
    fy = np.fft.fftfreq(wide.shape[0])[:, None]
    fx = np.fft.rfftfreq(wide.shape[1])[None, :]
    kernel = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    out = np.fft.irfft2(np.fft.rfft2(wide) * kernel, s=wide.shape)
    return out[pad:-pad, pad:-pad].astype(np.float32)


def _inside(x, y, points):
    """True where (x, y) lies inside the polygon (crossing count)."""
    inside = np.zeros(np.broadcast(x, y).shape, dtype=bool)
    for (ax, ay), (bx, by) in zip(points, points[1:] + points[:1]):
        if ay == by:
            continue
        crosses = ((ay > y) != (by > y)) & (x < (bx - ax) * (y - ay) / (by - ay) + ax)
        inside ^= crosses
    return inside


def _flood(open_, seeds):
    """The cells that can be reached from the seeds [(row, col)] through open cells."""
    reached = np.zeros_like(open_)
    for row, col in seeds:
        reached[row, col] = open_[row, col]
    count = -1
    while True:
        for _ in range(24):
            grown = reached.copy()
            grown[1:] |= reached[:-1]
            grown[:-1] |= reached[1:]
            grown[:, 1:] |= reached[:, :-1]
            grown[:, :-1] |= reached[:, 1:]
            reached = grown & open_
        total = int(reached.sum())
        if total == count:
            return reached
        count = total


def _stroke(distance, width, pixel):
    """A line `width` wide as coverage 0..1, from each pixel's distance to its middle."""
    return np.clip(0.5 + (width * 0.5 - np.abs(distance)) / pixel, 0.0, 1.0)


def save(path, array):
    """A picture file from an array [v, u] or [v, u, 3] in 0..1 (for looking at)."""
    if array.ndim == 2:
        array = np.repeat(array[..., None], 3, axis=-1)
    h, w = array.shape[:2]
    rgba = np.concatenate([np.clip(array, 0, 1), np.ones((h, w, 1))], axis=-1).astype(np.float32)
    img = bpy.data.images.new("_manual_save", w, h, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


# The skull -------------------------------------------------------------------------------------------


def skull():
    """The skull as ink: 1 where the print's paper is bare bone, 0 where it is engraved or is not the
    skull. Cropped to the skull, jaw let down."""
    if "skull" in _made:
        return _made["skull"]
    path = common.source("engravings", *PRINT)
    probe = bpy.data.images.load(path, check_existing=False)
    w, h = probe.size
    bpy.data.images.remove(probe)
    light = (scanlib._read(path, h, w) @ scanlib.LUMA)[::-1]  # [y, x], y down, as the marks above
    low, high = np.percentile(light, 2), np.percentile(light, 85)
    paper = np.clip((light - low) / (high - low), 0, 1)  # 1 = bare paper, 0 = ink

    # Where the skull is. On a quarter-size copy, bare paper is flooded from the plate's blank corners;
    # hatching and outlines stop it, so what it cannot reach, around the skull's middle, is the skull.
    q = 4
    rows, cols = h // q, w // q
    small = scanlib._shrink(paper[: rows * q, : cols * q], rows, cols)
    y, x = np.mgrid[0:rows, 0:cols] * q
    # (Old paper is mottled: only hatching, or one firm line, counts as drawn.)
    drawn = ((_blur(1 - small, 1.0) > 0.24) | (small < 0.45)) & ~_inside(x, y, CAST)
    bare = _flood(~drawn, [(py // q, px // q) for px, py in BLANK])
    solid = _flood(~bare, [(MIDDLE[1] // q, MIDDLE[0] // q)])
    solid = _blur(solid.astype(np.float32), 1.0) > 0.8  # (the blur widened every line: take that rim off)
    mask = np.zeros((h, w), dtype=np.float32)
    mask[: rows * q, : cols * q] = np.repeat(np.repeat(solid, q, axis=0), q, axis=1)
    mask = scanlib.smoothstep(0.35, 0.65, _blur(mask, 3.0))

    # Ink. Lightly hatched bone stays light with its lines in it; heavy cross-hatching goes to black,
    # so the shaded side of the skull is lost in the leather, as in the owner's first picture.
    tone = _blur(paper, 7.0)
    level = scanlib.smoothstep(0.34, 0.70, tone)
    ink = np.clip(paper * level / np.maximum(tone, 0.08), 0, 1) * mask
    y, x = np.mgrid[0:h, 0:w]
    ink[_inside(x, y, CAST)] = 0.0  # (strokes of the cast shadow that touch the jaw)

    # The jaw, let down. What is under the line moves; the gap is the open mouth. The jaw's two arms
    # ran up behind the cheeks: there they fade into the dark, above the cut and below it.
    xs = np.arange(w, dtype=np.float32)
    cut = np.interp(xs, [p[0] for p in JAW_LINE], [p[1] for p in JAW_LINE])[None, :]
    yy = np.arange(h + JAW_DROP, dtype=np.float32)[:, None]
    tall = np.zeros((h + JAW_DROP, w), dtype=np.float32)
    tall[:h] = ink
    right = scanlib.smoothstep(1650, 1730, xs)[None, :]
    arms = np.maximum(right, 1 - scanlib.smoothstep(700, 790, xs)[None, :])
    upper = tall * (yy < cut) * (1 - right * (1 - scanlib.smoothstep(0, 220, cut - yy)))
    jaw = np.zeros_like(tall)
    jaw[JAW_DROP:] = ink * (yy[:h] >= cut)
    jaw *= 1 - arms * (1 - scanlib.smoothstep(0, 260, yy - JAW_DROP - cut))
    out = np.maximum(upper, jaw)

    filled = np.argwhere(out > 0.02)
    (y0, x0), (y1, x1) = filled.min(axis=0), filled.max(axis=0)
    _made["skull"] = np.ascontiguousarray(out[y0 : y1 + 1, x0 : x1 + 1][::-1])
    return _made["skull"]


# The ring and the rays -------------------------------------------------------------------------------


def _polar(scale):
    """Every pixel of a cover as (x, y, distance from its middle, angle), in studs."""
    w, h = round(COVER[0] * scale), round(COVER[1] * scale)
    v, u = np.mgrid[0:h, 0:w].astype(np.float32)
    x = (u + 0.5) / scale - COVER[0] / 2
    y = (v + 0.5) / scale - COVER[1] / 2
    return x, y, np.hypot(x, y), np.arctan2(y, x)


def _woven(r, a, radius, swing, lobes, phase, width, pixel):
    """A line that weaves in and out around a circle."""
    line = radius + swing * np.sin(lobes * a + phase)
    slope = swing * lobes * np.cos(lobes * a + phase) / np.maximum(r, 1e-3)
    return _stroke((r - line) / np.sqrt(1 + slope * slope), width, pixel)


def _beads(r, a, radius, count, size, pixel, hollow=0.0):
    """A row of round beads on a circle (`hollow`: the width of their outline, when they are rings)."""
    step = 2 * math.pi / count
    near = np.round(a / step) * step
    away = np.sqrt(np.maximum(0, r * r + radius * radius - 2 * r * radius * np.cos(a - near)))
    if hollow:
        return _stroke(away - size, hollow, pixel)
    return np.clip(0.5 + (size - away) / pixel, 0, 1)


def _rays(r, a, pixel, count, start, lengths, width, seed, jitter=0.0, brush=False):
    """Rays from the ring towards the cover's edge. start, width: (low, high), drawn by lot for each
    ray; lengths: how far towards the edge each goes, as a list of shares that repeats round the
    circle, or (low, high) to draw them by lot; brush: strokes that swell and end round, instead of
    needles."""
    rng = np.random.default_rng(seed)
    step = 2 * math.pi / count
    angle = (np.arange(count) + 0.5) * step - math.pi + rng.uniform(-jitter, jitter, count) * step
    edge = np.minimum((COVER[0] / 2 - REACH) / np.maximum(np.abs(np.cos(angle)), 1e-6),
                      (COVER[1] / 2 - REACH) / np.maximum(np.abs(np.sin(angle)), 1e-6))
    if isinstance(lengths, tuple):
        share = rng.uniform(lengths[0], lengths[1], count)
    else:
        share = np.resize(np.array(lengths, dtype=np.float64), count) * rng.uniform(0.94, 1.0, count)
    begin = np.full(count, start[0]) if start[0] == start[1] else rng.uniform(start[0], start[1], count)
    if brush:
        # (Beside the ring the cover's edge is near: a stroke there starts early and stays a stroke.)
        begin = np.minimum(begin, edge - 0.11)
        share = np.maximum(share, 0.09 / (edge - begin))
    end = begin + (edge - begin) * np.minimum(share, 1.0)
    wide = np.full(count, width[0]) if width[0] == width[1] else rng.uniform(width[0], width[1], count)
    angle, begin, end, wide = (v.astype(np.float32) for v in (angle, begin, end, wide))
    out = np.zeros_like(r)
    nearest = np.clip(np.floor((a + math.pi) / step).astype(np.int64), 0, count - 1)
    for offset in (-1, 0, 1):
        i = (nearest + offset) % count
        turn = a - angle[i]
        along, across = r * np.cos(turn), r * np.sin(turn)
        t = np.clip((along - begin[i]) / (end[i] - begin[i]), 0.0, 1.0)
        if brush:
            body = wide[i] * np.power(np.sin(np.pi * np.clip(t, 0.02, 0.98)), 0.55)
        else:
            body = wide[i] * (1.0 - t) ** 1.35
        ends = np.clip((along - begin[i]) / pixel + 0.5, 0, 1) * np.clip((end[i] - along) / pixel + 0.5, 0, 1)
        out = np.maximum(out, _stroke(across, body, pixel) * ends * (body > 0))
    return out.astype(np.float32)


def _frame(x, y, inset, corner, width, pixel):
    """A rounded rectangle's outline, `inset` from the cover's edge."""
    qx = np.abs(x) - (COVER[0] / 2 - inset - corner)
    qy = np.abs(y) - (COVER[1] / 2 - inset - corner)
    away = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - corner
    return _stroke(away, width, pixel)


def emblem(variant, scale):
    """{"ink": the bone-white drawing, "blind": what is pressed in without ink (the frame)} of a
    cover, each 0..1."""
    key = ("emblem", variant, scale)
    if key in _made:
        return _made[key]
    x, y, r, a = _polar(scale)
    pixel = 1.0 / scale
    ink = np.zeros_like(r)

    def add(layer):
        np.maximum(ink, layer, out=ink)

    if variant == "A":
        add(_stroke(r - 0.495, 0.007, pixel))
        for strand in range(3):
            add(_woven(r, a, 0.573, 0.040, 30, strand * 2 * math.pi / 3, 0.0075, pixel))
        add(_beads(r, a, 0.650, 72, 0.0095, pixel))
        add(_stroke(r - 0.678, 0.007, pixel))
        add(_beads(r, a, 0.700, 144, 0.0045, pixel))
        add(_rays(r, a, pixel, 168, (0.722, 0.722), [1.0, 0.42, 0.68, 0.42], (0.0075, 0.0075), seed=3))
    elif variant == "B":
        add(_stroke(r - 0.497, 0.010, pixel))
        add(_beads(r, a, 0.594, 40, 0.034, pixel))
        add(_stroke(r - 0.692, 0.010, pixel))
        add(_rays(r, a, pixel, 30, (0.75, 0.93), (0.5, 1.0), (0.030, 0.046), seed=11, jitter=0.28, brush=True))
    elif variant == "C":
        add(_stroke(r - 0.490, 0.0052, pixel))
        add(_stroke(r - 0.516, 0.0052, pixel))
        add(_stroke(r - 0.662, 0.0045, pixel))
        add(_rays(r, a, pixel, 288, (0.690, 0.690), [1.0, 0.34, 0.6, 0.34, 0.8, 0.34, 0.6, 0.34], (0.0046, 0.0046),
                  seed=5))
    else:
        raise ValueError(f"no cover {variant}")

    # The skull in its disc.
    bone = skull()
    rows = round(SKULL_HEIGHT * scale)
    cols = round(rows * bone.shape[1] / bone.shape[0])
    bone = scanlib._shrink(bone, rows, cols).astype(np.float32)
    v0 = (ink.shape[0] - rows) // 2
    u0 = (ink.shape[1] - cols) // 2 - round(SKULL_LEFT * scale)
    disc = np.clip((DISC - 0.012 - r) / (2 * pixel) + 0.5, 0, 1)
    ink[v0 : v0 + rows, u0 : u0 + cols] = np.maximum(ink[v0 : v0 + rows, u0 : u0 + cols],
                                                     bone * disc[v0 : v0 + rows, u0 : u0 + cols])

    blind = np.maximum(_frame(x, y, BORDER, 0.05, 0.016, pixel), _frame(x, y, BORDER + 0.036, 0.03, 0.006, pixel))
    _made[key] = {"ink": ink, "blind": blind.astype(np.float32)}
    return _made[key]


# Age -------------------------------------------------------------------------------------------------
# The book is very old (the owner, 2026-10-12): its leather is cracked along the joints, the bands and
# the corners, scuffed and scratched, and still black everywhere; its pages are stained and spotted.
# The drawing stays mostly crisp: a few cracks cross it and the ink is rubbed where the grain stands
# highest.

BONE = (236, 228, 208)
CRACKED = (56, 52, 49)
SCUFFED = (50, 48, 47)
SCRATCHED = (68, 65, 62)
RULED = (72, 38, 16)
MARGIN = (104, 42, 22)
STAINED = (98, 50, 18)
SPOTTED = (112, 58, 20)
SHEET_DARK = (86, 44, 14)
SHEET_LIGHT = (236, 166, 92)

PAGE = (1.895, 2.58)  # a page (across, up)
# The ruling, in studs: the first line's distance from the page's head, the lines' pitch, how many,
# and the margin line's distance from the page's left edge. The game writes names on these lines
# (src/shared/ModelCatalog.luau carries them as the Manual's `page`).
RULE = {"first": 0.31, "pitch": 0.118, "count": 18, "margin": 0.26}


def _studs(cols, rows, across, up):
    """Every pixel of a face `across` by `up` studs as (x, y) from its bottom left corner."""
    v, u = np.mgrid[0:rows, 0:cols].astype(np.float32)
    return (u + 0.5) * across / cols, (v + 0.5) * up / rows


def _field(rng, cols, rows, lo, hi):
    """A wandering field in 0..1 (scanlib.drift), cut to the face."""
    size = 1 << int(math.ceil(math.log2(max(cols, rows))))
    return scanlib.drift(rng, size, lo, min(hi, size / 3.0))[:rows, :cols]


def _crackle(rng, cols, rows, pixel, likely):
    """Cracks in old leather: the lines where a wandering field crosses its middle, so that they wind
    and close into cells as leather's do, a coarse net and a fine one. They show where `likely` (0..1)
    is high, in patches."""
    out = np.zeros((rows, cols), dtype=np.float32)
    side = (1 << int(math.ceil(math.log2(max(cols, rows))))) * pixel  # studs the field's square spans
    for cell, width in ((0.16, 0.0075), (0.07, 0.004)):
        f = _field(rng, cols, rows, 0.6 * side / cell, 1.4 * side / cell)
        dv, du = np.gradient(f)
        away = np.abs(f - 0.5) / np.maximum(np.hypot(du, dv), 1e-5) * pixel  # studs to the line
        out = np.maximum(out, _stroke(away, width, pixel) * (0.75 if width < 0.005 else 1.0))
    patches = likely * (0.55 + 0.9 * _field(rng, cols, rows, 2.0, 6.0))
    return (out * scanlib.smoothstep(0.45, 0.8, patches)).astype(np.float32)


def _marks(x, y, lines, pixel):
    """Straight marks [(ax, ay, bx, by, width, strength)] as coverage."""
    out = np.zeros_like(x)
    for ax, ay, bx, by, width, strength in lines:
        dx, dy = bx - ax, by - ay
        t = np.clip(((x - ax) * dx + (y - ay) * dy) / max(dx * dx + dy * dy, 1e-9), 0.0, 1.0)
        away = np.hypot(x - (ax + t * dx), y - (ay + t * dy))
        out = np.maximum(out, strength * _stroke(away, width, pixel))
    return out


def _aged(cols, rows, across, up, seed, joint, amount=1.0):
    """What age did to a leather face: {"crack", "scuff", "rub", "scratch", "grain"}, each 0..1.
    joint: the side the face is hinged on ("left", "right"), or "both" for the spine itself."""
    rng = np.random.default_rng(seed)
    x, y = _studs(cols, rows, across, up)
    pixel = max(across / cols, up / rows)
    edge = np.minimum(np.minimum(x, across - x), np.minimum(y, up - y))
    corner = np.minimum(np.minimum(np.hypot(x, y), np.hypot(across - x, y)),
                        np.minimum(np.hypot(x, up - y), np.hypot(across - x, up - y)))
    if joint == "both":
        hinge = np.minimum(y, up - y)
        likely = 0.55 + 0.45 * (1 - scanlib.smoothstep(0.0, 0.12, hinge))
    else:
        hinge = x if joint == "left" else across - x
        likely = (0.12 + 0.6 * (1 - scanlib.smoothstep(0.0, 0.4, corner)) + 0.3 * (1 - scanlib.smoothstep(0.0, 0.12, edge))
                  + 0.8 * (1 - scanlib.smoothstep(0.02, 0.4, hinge)))
    crack = _crackle(rng, cols, rows, pixel, likely * amount)
    grain = _field(rng, cols, rows, 24.0, 200.0)
    patch = _field(rng, cols, rows, 2.0, 7.0)
    rub = np.clip(0.5 * (1 - scanlib.smoothstep(0.0, 0.05, edge)) + 0.85 * (1 - scanlib.smoothstep(0.0, 0.2, corner)), 0, 1)
    rub = rub * (0.4 + 0.6 * grain)
    scuff = scanlib.smoothstep(0.6, 0.84, patch) * (0.35 + 0.65 * grain) * 0.55
    lines = []
    for _ in range(int(2.5 * across * up)):
        cx, cy = rng.uniform(0, across), rng.uniform(0, up)
        turn, length = rng.uniform(0, math.pi), rng.uniform(0.05, 0.32)
        dx, dy = math.cos(turn) * length / 2, math.sin(turn) * length / 2
        lines.append((cx - dx, cy - dy, cx + dx, cy + dy, rng.uniform(0.003, 0.006), rng.uniform(0.2, 0.55)))
    scratch = _marks(x, y, lines, pixel) * (0.5 + 0.5 * grain)
    return {"crack": crack.astype(np.float32), "scuff": (scuff * amount).astype(np.float32),
            "rub": (rub * amount).astype(np.float32), "scratch": (scratch * amount).astype(np.float32), "grain": grain}


def _leather(age, ink=None, blind=None):
    """A stamp for a leather face: age's marks, and what was pressed into it (ink 0..1, blind 0..1)."""
    tints = [(SCUFFED, age["scuff"]), (SCUFFED, age["rub"] * 0.6), (SCRATCHED, age["scratch"] * 0.5),
             (CRACKED, age["crack"] * 0.85)]
    height = -0.004 * age["crack"] - 0.0012 * age["scratch"]
    rough = [(0.8, np.clip(age["scuff"] + age["rub"], 0, 1) * 0.7), (0.92, age["crack"])]
    if blind is not None:
        height = height - 0.006 * blind
        rough.append((0.42, blind * 0.6))  # (pressed leather is burnished)
    if ink is not None:
        worn = (ink * (1 - 0.9 * age["crack"]) * (1 - 0.5 * age["scratch"]) * (1 - 0.3 * age["rub"])
                * (1 - 0.25 * scanlib.smoothstep(0.55, 0.85, age["grain"])))
        tints.append((BONE, worn * 0.96))
        height = height - 0.0035 * _blur(ink, 0.7)
        rough.append((0.9, worn))
    return {"tints": tints, "height": height.astype(np.float32), "rough": rough}


VARIANT = "A"  # the cover the owner chose (run_manual.py draws all three for the choice)


def cover(cols, rows):
    """The front board's face: the drawing pressed into aged leather."""
    scale = 4.0 * cols / COVER[0]
    drawn = emblem(VARIANT, scale)
    ink = scanlib._shrink(drawn["ink"], rows, cols).astype(np.float32)
    blind = scanlib._shrink(drawn["blind"], rows, cols).astype(np.float32)
    return _leather(_aged(cols, rows, COVER[0], COVER[1], 21, "left"), ink, blind)


def back(cols, rows):
    """The back board's face: the same pressed frame, nothing in it."""
    x, y = _studs(cols, rows, *COVER)
    pixel = max(COVER[0] / cols, COVER[1] / rows)
    x, y = x - COVER[0] / 2, y - COVER[1] / 2
    blind = np.maximum(_frame(x, y, BORDER, 0.05, 0.016, pixel), _frame(x, y, BORDER + 0.036, 0.03, 0.006, pixel))
    return _leather(_aged(cols, rows, COVER[0], COVER[1], 22, "right"), blind=blind.astype(np.float32))


def spine(cols, rows, across, up):
    """The spine's leather: cracked all over, most along its two joints."""
    return _leather(_aged(cols, rows, across, up, 23, "both"))


def page(cols, rows):
    """A ruled page: writing lines and a margin line in dark brown ink, stains, spots, darkened edges."""
    rng = np.random.default_rng(31)
    x, y = _studs(cols, rows, *PAGE)
    down = PAGE[1] - y
    line = np.clip(np.round((down - RULE["first"]) / RULE["pitch"]), 0, RULE["count"] - 1)
    faded = 0.7 + 0.3 * _field(rng, cols, rows, 10.0, 80.0)
    ruled = _stroke(down - (RULE["first"] + line * RULE["pitch"]), 0.0075, PAGE[1] / rows) * faded
    ruled = ruled * (x > 0.07) * (x < PAGE[0] - 0.06)
    margin = _stroke(x - RULE["margin"], 0.008, PAGE[0] / cols) * faded * (down > 0.09) * (y > 0.07)
    edge = np.minimum(np.minimum(x, PAGE[0] - x), np.minimum(y, PAGE[1] - y))
    browned = (1 - scanlib.smoothstep(0.0, 0.3, edge)) * (0.6 + 0.4 * _field(rng, cols, rows, 3.0, 20.0))
    # Tide marks: where something was spilt and dried, darker along its ragged shore.
    pool = _field(rng, cols, rows, 1.5, 5.0) * (0.85 + 0.3 * _field(rng, cols, rows, 10.0, 40.0))
    stain = scanlib.smoothstep(0.62, 0.7, pool) * 0.55 + _stroke(pool - 0.66, 0.03, 0.02) * 0.5
    spots = np.zeros_like(x)
    for _ in range(70):
        cx, cy, size = rng.uniform(0, PAGE[0]), rng.uniform(0, PAGE[1]), rng.uniform(0.006, 0.028)
        spots = np.maximum(spots, rng.uniform(0.3, 0.9) * (1 - scanlib.smoothstep(0.4 * size, size, np.hypot(x - cx, y - cy))))
    tints = [(STAINED, browned * 0.4), (STAINED, np.clip(stain, 0, 1) * 0.3), (SPOTTED, spots * 0.45),
             (RULED, ruled * 0.82), (MARGIN, margin * 0.82)]
    height = (-0.0015 * np.clip(stain, 0, 1)).astype(np.float32)
    return {"tints": tints, "height": height, "rough": []}


def edge(cols, rows, across, up, seed):
    """One side of the page block: its sheets as fine lines, some standing out and some set back, darker
    where hands have held it."""
    rng = np.random.default_rng(seed)
    x, y = _studs(cols, rows, across, up)
    sheets = max(8, rows // 2)
    index = np.clip((y / up * sheets).astype(np.int64), 0, sheets - 1)
    # Each sheet stands out or back by a little, changing slowly along its length.
    size = 1 << int(math.ceil(math.log2(max(cols, sheets))))
    stand = (scanlib.drift(rng, size, 1.0, 10.0)[:sheets, :cols] * 2 - 1) * 0.6 + rng.uniform(-0.4, 0.4, (sheets, 1))
    stand = np.take_along_axis(stand, index, axis=0)
    gap = 0.5 - 0.5 * np.cos(2 * math.pi * (y / up * sheets))  # 0 between two sheets, 1 on a sheet's middle
    held = np.exp(-(((x - across / 2) / (0.28 * across)) ** 2)) * (0.55 + 0.45 * _field(rng, cols, rows, 4.0, 30.0))
    nicks = scanlib.smoothstep(0.8, 0.92, _field(rng, cols, rows, 20.0, 160.0)) * (stand < -0.2)
    tints = [(SHEET_DARK, (1 - gap) * 0.55), (SHEET_DARK, np.clip(-stand, 0, 1) * 0.5),
             (SHEET_LIGHT, np.clip(stand, 0, 1) * 0.3), (STAINED, held * 0.3), (SHEET_DARK, nicks * 0.7)]
    height = (0.004 * stand * gap - 0.002 * (1 - gap) - 0.003 * nicks).astype(np.float32)
    return {"tints": tints, "height": height, "rough": []}


def lay_on(color, normal, rough, rect, stamp, across, up):
    """Lays a stamp over the part of a prop's baked maps that `rect` (u0, v0, u1, v1) covers: a face
    `across` by `up` studs. stamp: a function (cols, rows) -> {"tints": [((r, g, b), cover 0..1)],
    "height": studs, "rough": [(value, cover)]}, made at the colour map's size. The maps are changed in
    place (colour sRGB, normal as its picture 0..1, roughness)."""

    def window(arr):
        h, w = arr.shape[:2]
        return slice(round(rect[1] * h), round(rect[3] * h)), slice(round(rect[0] * w), round(rect[2] * w))

    win = window(color)
    rows, cols = win[0].stop - win[0].start, win[1].stop - win[1].start
    made = stamp(cols, rows)
    part = color[win]
    for rgb, cover_ in made["tints"]:
        a = np.clip(cover_, 0, 1)[..., None]
        part[..., :3] = part[..., :3] * (1 - a) + (np.array(rgb, dtype=np.float32) / 255.0) * a

    win = window(normal)
    rows_n, cols_n = win[0].stop - win[0].start, win[1].stop - win[1].start
    height = scanlib._shrink(made["height"], rows_n, cols_n)
    dv, du = np.gradient(height)
    n = normal[win][..., :3] * 2 - 1
    n[..., 0] -= du / (across / cols_n) * n[..., 2]
    n[..., 1] -= dv / (up / rows_n) * n[..., 2]
    normal[win][..., :3] = scanlib._unit(n) * 0.5 + 0.5

    win = window(rough)
    rows_r, cols_r = win[0].stop - win[0].start, win[1].stop - win[1].start
    part = rough[win]
    for value, cover_ in made["rough"]:
        a = np.clip(scanlib._shrink(cover_, rows_r, cols_r), 0, 1)[..., None]
        part[..., :3] = part[..., :3] * (1 - a) + value * a
