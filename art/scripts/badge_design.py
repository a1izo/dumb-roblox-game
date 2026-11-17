"""The Operative's badge (BureauBadge), designed once as flat shapes with heights, then used twice: the mesh builder
(badge_mesh.py) raises them into real relief, and the painter (badge_paint.py) draws the same shapes into the shield's
texture, so the engraving, the gloss and the cavities sit exactly where the metal does. Pure Python and numpy: no
Blender needed here, so the design can be previewed with a plain `python art/scripts/badge_paint.py`.

Everything is in studs. A shape is written in the shield's own frame: x right, z up, the middle of the seal's disc
near the origin; badge_mesh moves it to the wallet's right half. Heights (`h`) are studs above the wallet's front
face. 2026-11-17, for the owner's "make the badge way more high quality" (the first remake, Core v41, was flat gold
sheets and a blue rectangle).

An original generic heraldic eagle: spread wings of layered feathers, a head turned to one side, a fanned tail. No
real agency's mark, no words but THE BUREAU and the number 0417."""

import math

# Shapes are drawn at this scale against the wallet half (0.42 x 0.6): the shield stands clear of the stitching.
SC = 0.94

# Heights above the wallet's face (studs).
H_PLATE = 0.014     # the shield's ground
H_RIM = 0.0235      # the rolled rim's crest
H_WALL = 0.0235     # a gold wall round enamel
H_ENAMEL = 0.0175   # the enamel's surface, below its wall
H_LETTER = 0.0265   # raised lettering
H_STAR = 0.0300     # the star
H_EAGLE = 0.0225    # the eagle's body and arms
H_LEAF = 0.0215

# Colours (sRGB 0-255)
GOLD = (220, 176, 90)
GOLD_BRIGHT = (236, 196, 108)
GOLD_GROUND = (168, 130, 62)
GOLD_DEEP = (112, 78, 30)
ENAMEL = (16, 44, 122)
ENAMEL_DARK = (10, 22, 66)
LEATHER = (30, 26, 26)

# Atlas rectangles of the 1024 px colour map (x0, y0, x1, y1 in px, y up from the bottom of the picture).
SHIELD_RECT = (4, 4, 452, 651)
CARD_RECT = (460, 4, 876, 616)
THREAD_RECT = (930, 4, 962, 36)
FOLD_RECT = (970, 4, 1002, 36)
LEATHER_RECT = (4, 660, 259, 1024)
LEATHER_BOX = (-0.21, -0.30, 0.21, 0.30)   # a wallet half, in its own frame
INTO = (270 / 1024.0, 660 / 1024.0, 1.0, 1.0)
SHIELD_BOX = (-0.1735, -0.2495, 0.1735, 0.2500)   # the shield's design frame the rect covers: (x0, z0, x1, z1)
CARD_BOX = (-0.17, -0.25, 0.17, 0.25)


# Polygons -------------------------------------------------------------------------------------------------------


def area(pts):
    return 0.5 * sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))


def ccw(pts):
    return list(pts) if area(pts) > 0 else list(reversed(pts))


def chaikin(pts, times=2):
    for _ in range(times):
        out = []
        for a, b in zip(pts, pts[1:] + pts[:1]):
            out.append((0.75 * a[0] + 0.25 * b[0], 0.75 * a[1] + 0.25 * b[1]))
            out.append((0.25 * a[0] + 0.75 * b[0], 0.25 * a[1] + 0.75 * b[1]))
        pts = out
    return pts


def resample(pts, step):
    """A closed polygon's outline cut into equal steps."""
    ring = list(pts) + [pts[0]]
    lengths = [math.dist(a, b) for a, b in zip(ring, ring[1:])]
    total = sum(lengths)
    count = max(6, round(total / step))
    out, k, run = [], 0, 0.0
    for n in range(count):
        want = total * n / count
        while run + lengths[k] < want - 1e-12 and k < len(lengths) - 1:
            run += lengths[k]
            k += 1
        t = (want - run) / max(lengths[k], 1e-12)
        a, b = ring[k], ring[k + 1]
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def offset(pts, d, limit=2.2):
    """A counter-clockwise polygon moved d outward (inward when d < 0) at its corners, the corner kept within
    `limit` times d."""
    out = []
    n = len(pts)
    for i in range(n):
        p, a, b = pts[i - 1], pts[i], pts[(i + 1) % n]
        e1 = (a[0] - p[0], a[1] - p[1])
        e2 = (b[0] - a[0], b[1] - a[1])
        l1, l2 = math.hypot(*e1) or 1.0, math.hypot(*e2) or 1.0
        n1 = (e1[1] / l1, -e1[0] / l1)
        n2 = (e2[1] / l2, -e2[0] / l2)
        s = (n1[0] + n2[0], n1[1] + n2[1])
        ls = math.hypot(*s) or 1.0
        s = (s[0] / ls, s[1] / ls)
        cosine = max(1.0 / limit, s[0] * n1[0] + s[1] * n1[1])
        out.append((a[0] + s[0] * d / cosine, a[1] + s[1] * d / cosine))
    return out


def circle(cx, cz, r, n=32, start=0.0):
    return [(cx + r * math.cos(start + 2 * math.pi * k / n), cz + r * math.sin(start + 2 * math.pi * k / n))
            for k in range(n)]


def mirror(pts):
    return [(-x, z) for x, z in pts]


def rotate(pts, deg, about=(0.0, 0.0)):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [(about[0] + (x - about[0]) * c - (z - about[1]) * s, about[1] + (x - about[0]) * s + (z - about[1]) * c)
            for x, z in pts]


def move(pts, dx, dz):
    return [(x + dx, z + dz) for x, z in pts]


# Items -----------------------------------------------------------------------------------------------------------
# An item: {"kind": "poly" | "ring" | "stroke", "pts", "h0", "h1", "cls", ...}
#   poly: a raised shape, its outline at the foot, its top drawn in by `draft` (walls leaning like cast metal)
#   ring: a rolled bead swept along a closed path, `width` wide, crest at h1
#   stroke: a polyline of `width`, standing from h0 to h1 with upright walls (lettering, stems)
# cls: "gold" (polished raised metal), "bright" (lighter polished), "ground" (the satin plate), "enamel", "navy".


def poly(pts, h0, h1, cls, draft=0.3, tag="", **extra):
    item = {"kind": "poly", "pts": ccw(pts), "h0": h0, "h1": h1, "cls": cls, "draft": draft, "tag": tag}
    item.update(extra)
    return item


def ring(pts, width, h0, h1, cls, tag="", **extra):
    item = {"kind": "ring", "pts": ccw(pts), "width": width, "h0": h0, "h1": h1, "cls": cls, "tag": tag}
    item.update(extra)
    return item


def stroke(pts, width, h0, h1, cls, tag="", closed=False, **extra):
    item = {"kind": "stroke", "pts": list(pts), "width": width, "h0": h0, "h1": h1, "cls": cls, "tag": tag,
            "closed": closed}
    item.update(extra)
    return item


# The block-letter font (the lettering is stroked, so the mesh and the picture agree) --------------------------------
# Each glyph: polylines in a box 1 wide, 2 tall (z up); `W` = its advance.
GLYPHS = {
    "T": ([[(0, 2), (1, 2)], [(0.5, 2), (0.5, 0)]], 1.0),
    "H": ([[(0, 0), (0, 2)], [(1, 0), (1, 2)], [(0, 1), (1, 1)]], 1.0),
    "E": ([[(1, 2), (0, 2), (0, 0), (1, 0)], [(0, 1), (0.8, 1)]], 0.9),
    "B": ([[(0, 0), (0, 2), (0.65, 2), (0.95, 1.85), (0.95, 1.15), (0.65, 1), (0, 1)],
           [(0.65, 1), (1, 0.85), (1, 0.15), (0.7, 0), (0, 0)]], 1.0),
    "U": ([[(0, 2), (0, 0.35), (0.3, 0), (0.7, 0), (1, 0.35), (1, 2)]], 1.0),
    "R": ([[(0, 0), (0, 2), (0.65, 2), (0.95, 1.85), (0.95, 1.2), (0.65, 1), (0, 1)], [(0.5, 1), (1, 0)]], 1.0),
    "A": ([[(0, 0), (0.5, 2), (1, 0)], [(0.2, 0.7), (0.8, 0.7)]], 1.0),
    "I": ([[(0.5, 0), (0.5, 2)], [(0.15, 2), (0.85, 2)], [(0.15, 0), (0.85, 0)]], 0.7),
    "D": ([[(0, 0), (0, 2), (0.55, 2), (1, 1.55), (1, 0.45), (0.55, 0), (0, 0)]], 1.0),
    "0": ([[(0.3, 0), (0, 0.35), (0, 1.65), (0.3, 2), (0.7, 2), (1, 1.65), (1, 0.35), (0.7, 0), (0.3, 0)]], 1.0),
    "4": ([[(0.75, 0), (0.75, 2), (0, 0.65), (1, 0.65)]], 1.0),
    "1": ([[(0.15, 1.6), (0.55, 2), (0.55, 0)], [(0.2, 0), (0.9, 0)]], 0.8),
    "7": ([[(0, 2), (1, 2), (0.35, 0)]], 1.0),
    " ": ([], 0.6),
}


def text_strokes(body, height, centre, width, gap=0.28):
    """Strokes of a line of the block font: `height` tall, its middle at `centre` (x, z), each stroke `width` wide.
    Returns [(polyline points, width)] in studs, the line centred on `centre`."""
    scale = height / 2.0
    advance = [GLYPHS[c][1] for c in body]
    total = (sum(advance) + gap * (len(body) - 1)) * scale
    x = centre[0] - total / 2
    out = []
    for ch, adv in zip(body, advance):
        for line in GLYPHS[ch][0]:
            out.append(([(x + px * adv * scale, centre[1] - height / 2 + pz * scale) for px, pz in line], width))
        x += (adv + gap) * scale
    return out


# The shield ------------------------------------------------------------------------------------------------------


def shield_outline():
    right = [(0.0, -0.262), (0.052, -0.232), (0.106, -0.186), (0.150, -0.116), (0.172, -0.030), (0.179, 0.060),
             (0.181, 0.150), (0.168, 0.196), (0.135, 0.226), (0.100, 0.214), (0.080, 0.196), (0.052, 0.224),
             (0.0, 0.262)]
    left = [(-x, z) for x, z in reversed(right[1:-1])]
    pts = right + left
    return ccw(chaikin(pts, 2))


def scaled(pts, k=SC):
    return [(x * k, z * k) for x, z in pts]


def _feather(base, angle, length, width, ts=(0.0, 0.18, 0.5, 0.78, 0.94, 1.0), hw=(0.3, 0.46, 0.5, 0.4, 0.2, 0.0)):
    """A feather: a leaf from `base` along `angle` (degrees), `length` long and `width` across."""
    c, s = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    left, right = [], []
    for t, w in zip(ts, hw):
        ax, az = base[0] + c * length * t, base[1] + s * length * t
        nx, nz = -s, c
        left.append((ax + nx * width * w, az + nz * width * w))
        right.append((ax - nx * width * w, az - nz * width * w))
    pts = left + list(reversed(right[:-1]))
    # (the tip comes once)
    return pts


def eagle_items(cz=0.0):
    """The displayed eagle: a fan of wing feathers each side (long flight feathers, mid secondaries, short coverts, all
    radiating from the shoulder and wrist under a tapered arm), a body with a feathered chest, a head turned to the
    viewer's left with a hooked beak, a fan of five tail feathers and two feet. Returned in the shield's frame at scale
    1."""
    items = []
    top = H_EAGLE
    blunt = dict(ts=(0.0, 0.2, 0.55, 0.9, 1.0), hw=(0.34, 0.48, 0.5, 0.36, 0.0))
    # tail: five feathers fanned down from the waist
    for k, ang in enumerate((-90, -66, -114, -43, -137)):
        length = (0.054, 0.052, 0.052, 0.046, 0.046)[k]
        items.append(poly(_feather((0.0, 0.142), ang, length, 0.034, **blunt), H_PLATE, top - 0.0016 * (k // 2 + 1),
                          "gold", draft=0.3, tag="tail", eagle="feather", axis=((0.0, 0.142), ang, length)))
    # body: shoulders, chest, waist
    body = [(0.0, 0.222), (0.026, 0.214), (0.040, 0.192), (0.040, 0.168), (0.032, 0.146), (0.020, 0.130), (0.0, 0.122)]
    body = body + [(-x, z) for x, z in reversed(body[1:-1])]
    items.append(poly(body, H_PLATE, top + 0.0008, "gold", draft=0.4, tag="body", eagle="body"))
    for side in (1, -1):
        sh = (0.030 * side, 0.196)
        wr = (0.074 * side, 0.206)
        # three rows of feathers fanned from the shoulder and the wrist: the flight feathers (longest, lowest), the
        # secondaries, the coverts; each row's angle runs from hanging beside the body to spread out
        rows = (
            (7, 0.034, -100, 4, 0.046, 0.074, 0.0000, "flight", 0.0, 0.034),
            (7, 0.030, -94, -6, 0.030, 0.050, 0.0030, "second", 0.5, 0.030),
            (6, 0.026, -88, -14, 0.018, 0.030, 0.0060, "covert", 1.0, 0.026),
        )
        for n, _, a0, a1, l0, l1, lift, tag, back, wid in rows:
            for i in range(n):
                t = i / (n - 1.0)
                base = (sh[0] + (wr[0] - sh[0]) * t * (0.55 + 0.45 * t), sh[1] + (wr[1] - sh[1]) * t - 0.004 - 0.004 * (1 - t))
                ang = a0 + (a1 - a0) * t ** 0.9
                a = ang if side > 0 else 180 - ang
                length = l0 + (l1 - l0) * t
                items.append(poly(_feather(base, a, length, wid, **blunt), H_PLATE, top + 0.0012 + lift + 0.0003 * i,
                                  "gold", draft=0.3, tag=tag, eagle="feather", axis=(base, a, length)))
        # the arm: a tapered bar from the shoulder out to the wrist and a little past, over the feathers' roots
        arm = [(sh[0] * 0.5, sh[1] + 0.020), (sh[0], sh[1] + 0.022), (wr[0] * 0.7, wr[1] + 0.016), (wr[0] + 0.024 * side, wr[1] + 0.006),
               (wr[0] + 0.026 * side, wr[1] - 0.006), (wr[0] * 0.7, wr[1] - 0.012), (sh[0], sh[1] - 0.010),
               (sh[0] * 0.5, sh[1] - 0.012)]
        items.append(poly(D_chaikin(arm), H_PLATE, top + 0.0085, "gold", draft=0.4, tag="arm", eagle="arm"))
    # head and beak, turned to the viewer's left
    head = circle(-0.002, 0.233, 0.0205, 16)
    items.append(poly(head, H_PLATE, top + 0.0040, "gold", draft=0.35, tag="head", eagle="head"))
    beak = [(-0.012, 0.240), (-0.036, 0.228), (-0.028, 0.219), (-0.020, 0.224), (-0.010, 0.223)]
    items.append(poly(beak, H_PLATE, top + 0.0030, "bright", draft=0.3, tag="beak", eagle="beak"))
    # feet: two clawed feet at the waist
    for side in ():
        foot = [(0.014 * side, 0.134), (0.046 * side, 0.126), (0.058 * side, 0.116), (0.052 * side, 0.112),
                (0.044 * side, 0.114), (0.046 * side, 0.104), (0.040 * side, 0.106), (0.034 * side, 0.116),
                (0.026 * side, 0.108), (0.020 * side, 0.118), (0.014 * side, 0.120)]
        items.append(poly(foot, H_PLATE, top + 0.0003, "gold", draft=0.3, tag="foot", eagle="foot"))
    return [dict(i, pts=[(x, z + cz) for x, z in i["pts"]]) for i in items]


def D_chaikin(pts):
    return chaikin(pts, 2)


def laurel_items(centre, radius):
    """Two laurel branches round the seal, meeting under it."""
    items = []
    cx, cz = centre
    for side in (1, -1):
        stem = []
        for k in range(8):
            a = math.radians(-104 + k * 19.0)
            stem.append((cx + side * radius * math.cos(a), cz + radius * math.sin(a)))
        items.append(stroke(stem, 0.0042, H_PLATE, H_LEAF - 0.0016, "gold", tag="stem", laurel="stem"))
        for k in range(1, 8):
            a = math.radians(-104 + k * 19.0)
            px, pz = cx + side * radius * math.cos(a), cz + radius * math.sin(a)
            # the tangent going up the branch
            tx, tz = -side * math.sin(a), math.cos(a)
            tang = math.degrees(math.atan2(tz, tx))
            fade = 1.0 - 0.30 * k / 7.0
            for turn in (+38, -38):
                items.append(poly(_feather((px, pz), tang + turn, 0.036 * fade, 0.0150, ts=(0.0, 0.3, 0.7, 1.0),
                                           hw=(0.2, 0.5, 0.42, 0.0)), H_PLATE, H_LEAF - (0.0008 if turn < 0 else 0.0),
                                  "gold", draft=0.3, tag="leaf", laurel="leaf",
                                  axis=((px, pz), tang + turn, 0.036 * fade)))
    return items


def ribbon_outline(half, high, notch):
    """A banner with swallowtail ends: half its length, half its height, the depth of the notch."""
    return ccw([(-half, high), (half, high), (half - notch, 0.0), (half, -high), (-half, -high),
                (-half + notch, 0.0)])


def cloisonne(outline, wall, h_wall, h_enamel, cls_enamel, tag):
    """A gold wall (a swept bead) round a pool of enamel set below it."""
    path = resample(chaikin(outline, 2), 0.016)
    inner = offset(path, -wall * 0.5)
    return [poly(inner, H_PLATE, h_enamel, cls_enamel, draft=0.0, tag=tag + "_enamel", flat=True),
            ring(offset(path, -wall * 0.5), wall, H_PLATE, h_wall, "gold", tag=tag + "_wall")]


def badge_items():
    """Every raised shape of the shield, in the shield's frame at scale 1 (scaled() below): bottom to top."""
    items = []
    outline = shield_outline()
    items.append(poly(outline, 0.0, H_PLATE, "ground", draft=0.0, tag="plate"))
    # the rolled rim, a little in from the edge
    rim = resample(offset(outline, -0.013), 0.020)
    items.append(ring(rim, 0.011, H_PLATE, H_RIM, "gold", tag="rim"))
    # the eagle
    items += eagle_items(-0.012)
    # the ribbon under the eagle: THE BUREAU in raised letters on dark enamel
    items += cloisonne(ribbon_outline(0.118, 0.024, 0.020), 0.007, H_WALL - 0.0015, H_ENAMEL, "navy", "ribbon")
    for pts, w in text_strokes("THE BUREAU", 0.027, (0.0, 0.0), 0.0050):
        items.append(stroke(move(pts, 0.0, 0.0), w, H_ENAMEL, H_LETTER, "bright", tag="letter"))
    # the seal: enamel in a gold wall with a raised star
    seal_c, seal_r = (0.0, -0.082), 0.058
    items += cloisonne(circle(seal_c[0], seal_c[1], seal_r, 36), 0.009, H_WALL, H_ENAMEL, "enamel", "seal")
    star = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        rr = 0.041 if k % 2 == 0 else 0.017
        star.append((seal_c[0] + rr * math.cos(a), seal_c[1] + rr * math.sin(a)))
    items.append(poly(star, H_ENAMEL, H_STAR, "bright", draft=0.35, tag="star", star=True, centre=seal_c))
    items += laurel_items(seal_c, 0.088)
    # the number on a small plate at the foot
    items += cloisonne(ribbon_outline(0.058, 0.019, 0.012), 0.006, H_WALL - 0.0015, H_ENAMEL, "navy", "plate")
    for pts, w in text_strokes("0417", 0.024, (0.0, 0.0), 0.0046):
        items.append(stroke(pts, w, H_ENAMEL, H_LETTER, "bright", tag="digit"))
    return items


# Placing the pieces that were drawn about the origin: the ribbon at z 0.068, the plate at z -0.186.
PLACE = {"ribbon": (0.0, 0.030), "plate": (0.0, -0.190)}


def placed_items():
    """badge_items() with the ribbon, its letters, the number plate and its digits moved into place, then everything
    scaled by SC. Heights are not scaled."""
    out = []
    for it in badge_items():
        tag = it["tag"]
        dz = 0.0
        if tag.startswith("ribbon") or tag == "letter":
            dz = PLACE["ribbon"][1]
        elif tag.startswith("plate") and tag != "plate" or tag == "digit":
            dz = PLACE["plate"][1]
        it = dict(it)
        it["pts"] = [(x * SC, (z + dz) * SC) for x, z in it["pts"]]
        for key in ("width",):
            if key in it:
                it[key] *= SC
        if "centre" in it:
            it["centre"] = (it["centre"][0] * SC, it["centre"][1] * SC)
        if "axis" in it:
            (bx, bz), ang, length = it["axis"]
            it["axis"] = ((bx * SC, (bz) * SC), ang, length * SC)
        out.append(it)
    return out
