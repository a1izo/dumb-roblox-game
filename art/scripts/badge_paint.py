"""Draws the Operative's badge textures (BureauBadge) from the shapes of badge_design.py: the shield's face (satin gold
ground with an engraved sunburst, the polished rolled rim with a bead, the eagle's feathers grooved one by one, laurel
leaves veined, the star faceted, glossy enamel with its own roughness and no metal) and the ID card (header band,
photo box with a head and shoulders, typed lines from a small stroke font, a signature, a hologram, a bar code).

Pure numpy, no Blender: `python art/scripts/badge_paint.py [outdir]` writes a preview of each picture. Inside the
game's pipeline badge_mesh.finish() calls shield() and card() and lays their results over the baked maps.

Colours are sRGB 0-1, roughness 0-1, metalness 0-1, relief in studs (a height field the normal map is made from, only
the engraving and grain: the raised shapes themselves are real geometry)."""

import math
import os
import struct
import sys
import zlib

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import badge_design as D  # noqa: E402


# Rasterising ---------------------------------------------------------------------------------------------------------


class Canvas:
    """A picture of one rectangle of the atlas: `w` x `h` px, covering `box` (x0, z0, x1, z1) of the design frame."""

    def __init__(self, rect, box):
        self.w = rect[2] - rect[0]
        self.h = rect[3] - rect[1]
        self.box = box
        self.sx = self.w / (box[2] - box[0])
        self.sz = self.h / (box[3] - box[1])

    def px(self, pts):
        return [((x - self.box[0]) * self.sx, (z - self.box[1]) * self.sz) for x, z in pts]

    def grid(self):
        """Design coordinates (x, z) of every pixel's middle."""
        xs = self.box[0] + (np.arange(self.w) + 0.5) / self.sx
        zs = self.box[1] + (np.arange(self.h) + 0.5) / self.sz
        return np.meshgrid(xs, zs)


def fill(pts_px, shape, ss=4):
    """Coverage 0-1 of a polygon (pixel coordinates) over an array of `shape` (h, w); returns (y0, y1, x0, x1, cover)
    of the part it touches."""
    h, w = shape
    p = np.asarray(pts_px, dtype=np.float64)
    ya, yb = max(0, int(math.floor(p[:, 1].min()))), min(h, int(math.ceil(p[:, 1].max())) + 1)
    xa, xb = max(0, int(math.floor(p[:, 0].min()))), min(w, int(math.ceil(p[:, 0].max())) + 1)
    if ya >= yb or xa >= xb:
        return 0, 0, 0, 0, np.zeros((0, 0), np.float32)
    acc = np.zeros((yb - ya, xb - xa + 1), np.float32)
    x1, y1 = p[:, 0], p[:, 1]
    x2, y2 = np.roll(x1, -1), np.roll(y1, -1)
    live = y1 != y2
    x1, y1, x2, y2 = x1[live], y1[live], x2[live], y2[live]
    lo, hi = np.minimum(y1, y2), np.maximum(y1, y2)
    slope = (x2 - x1) / (y2 - y1)
    for row in range(ya, yb):
        for k in range(ss):
            ys = row + (k + 0.5) / ss
            hit = (lo <= ys) & (ys < hi)
            if not hit.any():
                continue
            xs = np.sort(x1[hit] + (ys - y1[hit]) * slope[hit]) - xa
            for a, b in zip(xs[0::2], xs[1::2]):
                a, b = max(a, 0.0), min(b, xb - xa)
                if b <= a:
                    continue
                ia, ib = int(math.floor(a)), int(math.floor(b))
                if ia == ib:
                    acc[row - ya, ia] += b - a
                else:
                    acc[row - ya, ia] += ia + 1 - a
                    acc[row - ya, ib] += b - ib
                    if ib > ia + 1:
                        acc[row - ya, ia + 1:ib] += 1.0
    return ya, yb, xa, xb, np.clip(acc[:, : xb - xa] / ss, 0, 1)


def paste(shape, crop):
    """A full-size array from a fill() result."""
    out = np.zeros(shape, np.float32)
    ya, yb, xa, xb, cover = crop
    if cover.size:
        out[ya:yb, xa:xb] = cover
    return out


def line_cover(pts_px, width_px, shape, closed=False):
    """Coverage of a polyline `width_px` wide (round joints), as a full array."""
    h, w = shape
    p = np.asarray(pts_px, dtype=np.float64)
    if closed:
        p = np.vstack([p, p[:1]])
    out = np.zeros(shape, np.float32)
    r = width_px / 2 + 1.0
    for a, b in zip(p[:-1], p[1:]):
        x0, x1 = max(0, int(min(a[0], b[0]) - r)), min(w, int(max(a[0], b[0]) + r) + 1)
        y0, y1 = max(0, int(min(a[1], b[1]) - r)), min(h, int(max(a[1], b[1]) + r) + 1)
        if x0 >= x1 or y0 >= y1:
            continue
        xs = np.arange(x0, x1) + 0.5
        ys = np.arange(y0, y1) + 0.5
        gx, gy = np.meshgrid(xs, ys)
        d = b - a
        l2 = float(d @ d)
        t = np.clip(((gx - a[0]) * d[0] + (gy - a[1]) * d[1]) / l2, 0, 1) if l2 > 1e-12 else np.zeros_like(gx)
        dist = np.hypot(gx - (a[0] + t * d[0]), gy - (a[1] + t * d[1]))
        cov = np.clip(width_px / 2 + 0.5 - dist, 0, 1).astype(np.float32)
        out[y0:y1, x0:x1] = np.maximum(out[y0:y1, x0:x1], cov)
    return out


def blur(a, r):
    """A box blur of radius r (twice, so nearly round), edges repeated."""
    out = a.astype(np.float32)
    for _ in range(2):
        for axis in (0, 1):
            pad = [(0, 0), (0, 0)]
            pad[axis] = (r + 1, r)
            padded = np.pad(out, pad, mode="edge")
            c = np.cumsum(padded, axis=axis, dtype=np.float64)
            hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
            lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
            out = ((hi - lo) / (2 * r + 1)).astype(np.float32)
    return out


def shrink(a, rows, cols):
    """An array averaged down to rows x cols."""
    for axis, count in ((0, rows), (1, cols)):
        have = a.shape[axis]
        if count >= have:
            continue
        edges = (np.arange(count) * have) // count
        sizes = np.diff(np.append(edges, have)).reshape([-1 if i == axis else 1 for i in range(a.ndim)])
        a = np.add.reduceat(a, edges, axis=axis) / sizes
    return a


def noise(shape, scale, seed):
    """Smooth value noise 0-1, features about `scale` px."""
    rng = np.random.default_rng(seed)
    h, w = shape
    gh, gw = int(h / scale) + 3, int(w / scale) + 3
    g = rng.random((gh, gw)).astype(np.float32)
    ys = np.arange(h) / scale
    xs = np.arange(w) / scale
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = ys - y0, xs - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0] * (1 - fx) + g[y0][:, x0 + 1] * fx
    b = g[y0 + 1][:, x0] * (1 - fx) + g[y0 + 1][:, x0 + 1] * fx
    return (a * (1 - fy)[:, None] + b * fy[:, None]).astype(np.float32)


def rgb(c):
    return np.array(c, np.float32) / 255.0


def mix(col, c, a):
    col[...] = col * (1 - a[..., None]) + np.asarray(c, np.float32) * a[..., None]


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - 0.055)


def normals_from(height, du, dv):
    """A tangent-space normal map (0-1 picture) from a height field `height` (studs); du, dv: studs a pixel spans."""
    gv, gu = np.gradient(height)
    n = np.dstack([-gu / du, -gv / dv, np.ones_like(height)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


# The shield ----------------------------------------------------------------------------------------------------------

CLASS_LOOK = {
    # class: (top colour, wall colour, roughness, metal)
    "ground": (D.GOLD_GROUND, D.GOLD_GROUND, 0.46, 1.0),
    "gold": (D.GOLD, (172, 128, 52), 0.26, 1.0),
    "bright": (D.GOLD_BRIGHT, (186, 142, 62), 0.20, 1.0),
    "enamel": (D.ENAMEL, D.ENAMEL, 0.10, 0.0),
    "navy": (D.ENAMEL_DARK, D.ENAMEL_DARK, 0.08, 0.0),
}


def _ring_path(item):
    return item["pts"]


def along_path(path, X, Z, mask):
    """For each masked pixel the distance to a closed path and how far along it (studs) the nearest point lies."""
    path = list(path) + [path[0]]
    best = np.full(X.shape, 1e9, np.float32)
    where = np.zeros(X.shape, np.float32)
    run = 0.0
    xs, zs = X[mask], Z[mask]
    bd = np.full(xs.shape, 1e9, np.float32)
    bs = np.zeros(xs.shape, np.float32)
    for a, b in zip(path[:-1], path[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        l2 = dx * dx + dz * dz
        l = math.sqrt(l2)
        t = np.clip(((xs - a[0]) * dx + (zs - a[1]) * dz) / max(l2, 1e-12), 0, 1)
        d = np.hypot(xs - (a[0] + t * dx), zs - (a[1] + t * dz))
        better = d < bd
        bd = np.where(better, d, bd)
        bs = np.where(better, run + t * l, bs)
        run += l
    best[mask] = bd
    where[mask] = bs
    return best, where


def shield(seed=7):
    """The shield's picture set: dict(color (h, w, 3), rough (h, w), metal (h, w), relief (h, w) studs, size (w, h) px,
    studs_per_px (du, dv))."""
    cv = Canvas(D.SHIELD_RECT, D.SHIELD_BOX)
    shape = (cv.h, cv.w)
    X, Z = cv.grid()
    rng = np.random.default_rng(seed)
    col = np.zeros(shape + (3,), np.float32)
    col[...] = rgb(D.GOLD_GROUND)
    rough = np.full(shape, 0.46, np.float32)
    metal = np.ones(shape, np.float32)
    H = np.zeros(shape, np.float32)
    micro = np.zeros(shape, np.float32)
    owner = np.full(shape, -1, np.int32)
    tops = {}
    items = D.placed_items()
    plate_mask = None
    # (the strokes of one line of lettering are one shape: painted separately their walls would cut each other)
    groups = {}
    for it in items:
        if it["kind"] == "stroke" and it["tag"] in ("letter", "digit"):
            wpx = it["width"] * cv.sx
            base_ = line_cover(cv.px(it["pts"]), wpx, shape, closed=it["closed"])
            top_ = line_cover(cv.px(it["pts"]), max(1.0, wpx - 2.2), shape, closed=it["closed"])
            g = groups.setdefault(it["tag"], [np.zeros(shape, np.float32), np.zeros(shape, np.float32)])
            g[0] = np.maximum(g[0], base_)
            g[1] = np.maximum(g[1], top_)
    for k, it in enumerate(items):
        look = CLASS_LOOK[it["cls"]]
        pts = it["pts"]
        if it["kind"] == "poly":
            base = paste(shape, fill(cv.px(pts), shape))
            if it.get("flat") or it["draft"] <= 0:
                top = base
            else:
                top = paste(shape, fill(cv.px(D.offset(pts, -it["draft"] * (it["h1"] - it["h0"]))), shape))
        elif it["kind"] == "ring":
            wpx = it["width"] * cv.sx
            base = line_cover(cv.px(pts), wpx, shape, closed=True)
            top = line_cover(cv.px(pts), wpx * 0.45, shape, closed=True)
        elif it["tag"] in groups:
            base, top = groups[it["tag"]]
        else:
            wpx = it["width"] * cv.sx
            base = line_cover(cv.px(pts), wpx, shape, closed=it["closed"])
            top = line_cover(cv.px(pts), max(1.0, wpx - 2.2), shape, closed=it["closed"])
        if it["tag"] == "plate":
            plate_mask = base
        wall = np.clip(base - top, 0, 1)
        flat = it.get("flat")
        # colour: the wall darker, the top as the class
        if it["cls"] in ("enamel", "navy"):
            mix(col, rgb(look[0]), base)
        else:
            mix(col, rgb(look[1]), base)
            mix(col, rgb(look[0]), top)
        a = base > 0.5
        rough[a] = look[2]
        metal[a] = look[3]
        owner[a] = k
        tops[k] = top
        height = it["h0"] + (it["h1"] - it["h0"]) * np.where(top > 0.5, 1.0, 0.5)
        H = np.where(a, np.maximum(H, height) if it["tag"] != "plate" else height, H)
        if it["tag"] == "plate":
            H[:] = np.where(a, it["h1"], 0.0)
        # (a polished top catches the light at its edge)
        if it["cls"] in ("gold", "bright") and it["kind"] != "stroke":
            edge = np.clip(top - blur(top, 1) * 1.0, 0, 1) * (top > 0.5)
            mix(col, np.minimum(rgb(look[0]) * 1.18 + 0.03, 1.0), edge * 0.6)
    plate = plate_mask > 0.5

    # the satin ground: an engraved sunburst about the seal, fine stipple, an engraved line inside the rim
    ground = (owner == 0) | (H <= D.H_PLATE + 1e-4) & plate
    sc = None
    for it in items:
        if it.get("star"):
            sc = it["centre"]
    ang = np.arctan2(Z - sc[1], X - sc[0])
    pitch = math.radians(2.4)
    f = (ang / pitch) % 1.0
    ray = np.clip(1.0 - np.abs(f - 0.5) * 2.0 * 1.0, 0, 1) ** 8
    radius = np.hypot(X - sc[0], Z - sc[1])
    ray *= np.clip((radius - 0.07) / 0.03, 0, 1)
    stip = noise(shape, 1.6, seed + 1) - 0.5
    gmask = (ground & (owner == 0)).astype(np.float32)
    micro += gmask * (-0.00055 * ray + 0.0004 * stip)
    mix(col, np.array(D.GOLD_GROUND, np.float32) / 255 * 0.72, ray * gmask * 0.55)
    col[..., :] *= (1 + 0.10 * stip * gmask)[..., None]
    # an engraved fine line a little inside the rim
    outline = D.scaled(D.shield_outline())
    inside = D.resample(D.offset(outline, -0.034 * D.SC), 0.012)
    line = line_cover(cv.px(inside), 1.8, shape, closed=True)
    line *= gmask
    micro -= 0.0007 * line
    mix(col, rgb(D.GOLD_DEEP), line * 0.7)

    # decor, drawn only where the item shows (nothing taller laid over it)
    groove = np.zeros(shape, np.float32)
    dark = np.zeros(shape, np.float32)
    for k, it in enumerate(items):
        shown = (owner == k).astype(np.float32) * (tops[k] > 0.4)
        if it.get("eagle") == "feather" or it.get("laurel") == "leaf":
            (bx, bz), ang_deg, length = it["axis"]
            c, s = math.cos(math.radians(ang_deg)), math.sin(math.radians(ang_deg))
            nx, nz = -s, c
            hw_max = 0.5 * (0.026 if it.get("eagle") else 0.0125) * D.SC
            rib = [(bx + c * length * t, bz + s * length * t) for t in (0.05, 0.9)]
            g = line_cover(cv.px(rib), 1.9, shape)
            if it.get("eagle"):
                pitch_s = 0.0052 * D.SC
                n_barbs = int(length * 0.82 / pitch_s)
                for i in range(1, n_barbs):
                    u = 0.10 * length + i * pitch_s
                    px_, pz_ = bx + c * u, bz + s * u
                    reach = hw_max * 0.8 * math.sin(math.pi * min(1.0, u / length) ** 0.8)
                    for sgn in (1, -1):
                        tip = (px_ + c * reach * 0.6 + sgn * nx * reach, pz_ + s * reach * 0.6 + sgn * nz * reach)
                        g = np.maximum(g, line_cover(cv.px([(px_, pz_), tip]), 1.0, shape) * 0.8)
            else:
                for i in range(2, 9):
                    u = 0.11 * length * i
                    px_, pz_ = bx + c * u, bz + s * u
                    reach = hw_max * 0.8 * math.sin(math.pi * min(1.0, u / length))
                    for sgn in (1, -1):
                        tip = (px_ + c * reach * 0.7 + sgn * nx * reach, pz_ + s * reach * 0.7 + sgn * nz * reach)
                        g = np.maximum(g, line_cover(cv.px([(px_, pz_), tip]), 1.0, shape) * 0.8)
            groove = np.maximum(groove, g * shown)
        elif it.get("eagle") == "body":
            # chest feathers: rows of small scallops
            for row in range(10):
                z = (0.118 + row * 0.0074) * D.SC
                for col_i in range(-3, 4):
                    x = (col_i * 0.0085 + (0.0042 if row % 2 else 0.0)) * D.SC
                    arc = [(x - 0.0035 * D.SC, z), (x, z - 0.003 * D.SC), (x + 0.0035 * D.SC, z)]
                    groove = np.maximum(groove, line_cover(cv.px(arc), 1.2, shape) * shown * 0.8)
        elif it.get("eagle") == "head":
            eye = circle_cover(cv, (-0.0085 * D.SC, 0.2235 * D.SC), 0.0032 * D.SC, shape)
            dark = np.maximum(dark, eye * shown)
        elif it.get("eagle") == "arm":
            for i in range(5):
                u = 0.28 + i * 0.16
                x0 = it["pts"][0][0]
                xa = (it["pts"][0][0] * (1 - u) + it["pts"][2][0] * u)
                za = (it["pts"][0][1] * (1 - u) + it["pts"][2][1] * u)
                groove = np.maximum(groove, line_cover(cv.px([(xa, za + 0.010 * D.SC), (xa, za - 0.010 * D.SC)]), 1.1, shape) * shown * 0.7)
        elif it.get("star"):
            pts = it["pts"]
            for q in range(10):
                groove = np.maximum(groove, line_cover(cv.px([it["centre"], pts[q]]), 1.5, shape) * shown)
            facet = (np.floor(((np.arctan2(Z - it["centre"][1], X - it["centre"][0]) - math.pi / 2) / (math.pi / 5)) % 10) % 2)
            mix(col, col * 0.84, (shown * facet).astype(np.float32))
        elif it["tag"].endswith("_enamel"):
            r = np.hypot(X - sc[0], Z - sc[1]) if it["tag"] == "seal_enamel" else 0
            n = noise(shape, 26.0, seed + 5 + k)
            m = (owner == k).astype(np.float32)
            shade = (0.94 + 0.14 * n)
            if it["tag"] == "seal_enamel":
                shade = shade * (1.12 - 0.5 * np.clip(r / (0.072 * D.SC), 0, 1) ** 2)
            col[...] = np.where(m[..., None] > 0, col * shade[..., None], col)
            rough[owner == k] = 0.07 + 0.05 * n[owner == k]
    micro -= 0.0009 * groove
    mix(col, col * 0.45, groove * 0.75)
    mix(col, rgb((12, 10, 8)), dark)

    # a rope bead round the rolled rim
    for k, it in enumerate(items):
        if it["tag"] == "rim":
            mask = (owner == k)
            d, s = along_path(it["pts"], X, Z, mask)
            pitch_b = 0.0105 * D.SC
            bead = 0.5 - 0.5 * np.cos(2 * math.pi * s / pitch_b)
            m = mask.astype(np.float32)
            micro += m * (0.0006 * (bead - 0.5))
            col[...] = np.where(mask[..., None], col * (0.80 + 0.30 * bead[..., None]), col)
            rough[mask] = 0.24 + 0.10 * (1 - bead[mask])

    # cavities: shade the colour where the height is lower than its surroundings
    cav = np.clip(blur(H, 9) - H, 0, None)
    ao = np.exp(-cav * 60.0)
    col *= (0.4 + 0.6 * ao)[..., None]
    # a trace of wear and finger grease on the polished metal
    wear = noise(shape, 14.0, seed + 99)
    col *= (0.94 + 0.12 * wear)[..., None]
    rough = np.clip(rough + 0.06 * (wear - 0.5), 0.05, 1.0)
    return {"color": np.clip(col, 0, 1), "rough": rough, "metal": metal, "relief": micro, "size": (cv.w, cv.h),
            "step": (1.0 / cv.sx, 1.0 / cv.sz), "height": H}


def circle_cover(cv, c, r, shape):
    pts = [(c[0] + r * math.cos(2 * math.pi * k / 16), c[1] + r * math.sin(2 * math.pi * k / 16)) for k in range(16)]
    return paste(shape, fill(cv.px(pts), shape))


# Typed text -----------------------------------------------------------------------------------------------------------

_LOWER = [
    [[(0.1, 0), (0.1, 1.45)]],
    [[(0.05, 0.5), (0.12, 0.85), (0.3, 1.0), (0.48, 0.85), (0.55, 0.5), (0.48, 0.15), (0.3, 0), (0.12, 0.15), (0.05, 0.5)]],
    [[(0.05, 0), (0.05, 1)], [(0.05, 0.8), (0.25, 1.0), (0.5, 0.8), (0.5, 0)]],
    [[(0.05, 0.5), (0.55, 0.5), (0.55, 0.8), (0.3, 1.0), (0.05, 0.8), (0.05, 0.2), (0.3, 0), (0.55, 0.15)]],
    [[(0.55, 0), (0.55, 1)], [(0.55, 0.8), (0.3, 1.0), (0.05, 0.8), (0.05, 0.2), (0.3, 0), (0.55, 0.2)]],
    [[(0.25, 1.3), (0.25, 0.15), (0.4, 0)], [(0.05, 1.0), (0.5, 1.0)]],
    [[(0.2, 0), (0.2, 1)], [(0.2, 1.25), (0.2, 1.32)]],
    [[(0.1, 0), (0.1, 1)], [(0.1, 0.75), (0.3, 1.0), (0.5, 0.95)]],
    [[(0.05, 1.0), (0.05, 0.2), (0.25, 0), (0.5, 0.2)], [(0.5, 0), (0.5, 1)]],
    [[(0.55, 0.85), (0.3, 1.0), (0.05, 0.8), (0.05, 0.2), (0.3, 0), (0.55, 0.15)]],
    [[(0.55, 0), (0.55, 1.45)], [(0.55, 0.8), (0.3, 1.0), (0.05, 0.8), (0.05, 0.2), (0.3, 0), (0.55, 0.2)]],
    [[(0.05, 0), (0.05, 1.45)], [(0.05, 0.8), (0.25, 1.0), (0.5, 0.8), (0.5, 0)]],
    [[(0.55, 1.0), (0.55, -0.35), (0.35, -0.5), (0.1, -0.4)], [(0.55, 0.8), (0.3, 1.0), (0.05, 0.8), (0.05, 0.2), (0.3, 0), (0.55, 0.2)]],
    [[(0.05, 0.1), (0.3, 0), (0.5, 0.2), (0.3, 0.45), (0.1, 0.65), (0.3, 1.0), (0.55, 0.9)]],
]


def typed_line(cv, shape, x, z, length, xh, rng, ink_width_px=1.1, caps=False):
    """A line of text-like marks (letters from a small stroke font, drawn in a random order: nonsense, which is what the
    card should print) starting at (x, z), about `length` studs long, `xh` the x-height. Returns the coverage."""
    out = np.zeros(shape, np.float32)
    cur = x
    glyph_w = xh * 0.62
    while cur < x + length - glyph_w:
        if rng.random() < 0.16:
            cur += glyph_w * 0.7
            continue
        g = _LOWER[int(rng.integers(0, len(_LOWER)))]
        for poly in g:
            pts = cv.px([(cur + px * glyph_w / 0.6, z + pz * xh) for px, pz in poly])
            if len(pts) == 2 and abs(poly[0][1] - poly[1][1]) < 0.1 and poly[0][1] > 1.2:
                pts = [pts[0], (pts[0][0] + 0.5, pts[0][1])]
            out = np.maximum(out, line_cover(pts, ink_width_px, shape))
        cur += glyph_w * 1.15
    return out


def block_text(cv, shape, body, height, centre, stroke, align="centre", width_px=None):
    """The block font as coverage; `centre` x is the middle (align "centre") or the left end (align "left")."""
    out = np.zeros(shape, np.float32)
    strokes = D.text_strokes(body, height, centre, stroke)
    if align == "left":
        xs = [p[0] for pts, _ in strokes for p in pts]
        shift = centre[0] - min(xs)
        strokes = [([(x + shift, z) for x, z in pts], w) for pts, w in strokes]
    elif align == "right":
        xs = [p[0] for pts, _ in strokes for p in pts]
        shift = centre[0] - max(xs)
        strokes = [([(x + shift, z) for x, z in pts], w) for pts, w in strokes]
    for pts, w in strokes:
        out = np.maximum(out, line_cover(cv.px(pts), max(1.0, w * cv.sx), shape))
    return out


# The ID card ---------------------------------------------------------------------------------------------------------


def card(seed=11):
    cv = Canvas(D.CARD_RECT, D.CARD_BOX)
    shape = (cv.h, cv.w)
    X, Z = cv.grid()
    rng = np.random.default_rng(seed)
    col = np.zeros(shape + (3,), np.float32)
    col[...] = rgb((238, 236, 228))
    fibre = noise(shape, 1.3, seed) - 0.5
    col *= (1 + 0.035 * fibre)[..., None]
    rough = np.full(shape, 0.34, np.float32)
    metal = np.zeros(shape, np.float32)
    micro = np.zeros(shape, np.float32)

    def rect(x0, z0, x1, z1):
        return paste(shape, fill(cv.px([(x0, z0), (x1, z0), (x1, z1), (x0, z1)]), shape))

    # a faint security weave over the body: fine sine lines in pale blue
    weave = np.zeros(shape, np.float32)
    for i in range(24):
        z0 = 0.145 - i * 0.0185
        pts = [(x, z0 + 0.0055 * math.sin((x + 0.017 * i) * 70.0) + 0.0025 * math.sin(x * 31.0 + i)) for x in np.linspace(-0.17, 0.17, 90)]
        weave = np.maximum(weave, line_cover(cv.px(pts), 0.9, shape))
    body_area = rect(-0.17, -0.25, 0.17, 0.150)
    mix(col, rgb((205, 218, 236)), weave * body_area * 0.55)

    # header band, a gold rule under it
    band = rect(-0.17, 0.152, 0.17, 0.25)
    mix(col, rgb((18, 44, 110)), band)
    grad = np.clip((Z - 0.152) / 0.098, 0, 1)
    col += (band * grad * 0.06)[..., None] * np.array([0.5, 0.7, 1.0], np.float32)
    rough[band > 0.5] = 0.28
    rule = rect(-0.17, 0.1465, 0.17, 0.1525)
    mix(col, rgb(D.GOLD), rule)
    rough[rule > 0.5] = 0.30
    metal[rule > 0.5] = 0.6
    head = block_text(cv, shape, "THE BUREAU", 0.034, (0.02, 0.205), 0.0050)
    mix(col, rgb((244, 244, 240)), head)
    idt = block_text(cv, shape, "ID", 0.0225, (0.158, 0.2285), 0.0036, align="right")
    mix(col, rgb((236, 200, 120)), idt)
    # the small gold seal at the header's left, with a star
    seal = circle_cover(cv, (-0.118, 0.201), 0.032, shape)
    ring = np.clip(seal - circle_cover(cv, (-0.118, 0.201), 0.0275, shape), 0, 1)
    mix(col, rgb(D.GOLD), seal * 0.9)
    mix(col, rgb((18, 44, 110)), circle_cover(cv, (-0.118, 0.201), 0.0255, shape))
    star = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        rr = 0.021 if k % 2 == 0 else 0.0085
        star.append((-0.118 + rr * math.cos(a), 0.2 + rr * math.sin(a)))
    mix(col, rgb(D.GOLD_BRIGHT), paste(shape, fill(cv.px(star), shape)))
    rough[seal > 0.5] = 0.3
    metal[seal > 0.5] = 0.5

    # the photo: a box with a border, a grey-blue studio ground, a head and shoulders in a dark jacket
    px0, pz0, px1, pz1 = -0.152, -0.050, -0.030, 0.112
    box = rect(px0, pz0, px1, pz1)
    inner = rect(px0 + 0.0035, pz0 + 0.0035, px1 - 0.0035, pz1 - 0.0035)
    mix(col, rgb((60, 66, 78)), box)
    t = np.clip((Z - pz0) / (pz1 - pz0), 0, 1)
    ground = rgb((132, 146, 168))[None, None, :] * (0.78 + 0.34 * t)[..., None] * (1 + 0.07 * (noise(shape, 3, seed + 2) - 0.5))[..., None]
    mix(col, ground, inner)
    cx = (px0 + px1) / 2
    jacket = np.zeros(shape, np.float32)
    # shoulders: a wide rounded wedge from the photo's foot
    sh = [(cx - 0.060, pz0), (cx - 0.056, pz0 + 0.026), (cx - 0.036, pz0 + 0.044), (cx - 0.014, pz0 + 0.052),
          (cx + 0.014, pz0 + 0.052), (cx + 0.036, pz0 + 0.044), (cx + 0.056, pz0 + 0.026), (cx + 0.060, pz0)]
    jacket = paste(shape, fill(cv.px(sh), shape))
    neck = paste(shape, fill(cv.px([(cx - 0.012, pz0 + 0.040), (cx - 0.011, pz0 + 0.060), (cx + 0.011, pz0 + 0.060), (cx + 0.012, pz0 + 0.040)]), shape))
    headp = [(cx + 0.027 * math.cos(2 * math.pi * k / 24), pz0 + 0.092 + 0.034 * math.sin(2 * math.pi * k / 24)) for k in range(24)]
    headm = paste(shape, fill(cv.px(headp), shape))
    hairline = pz0 + 0.100 + 0.014 * (1 - np.clip(np.abs(X - cx) / 0.027, 0, 1) ** 2)
    hair = (Z > hairline).astype(np.float32)
    mix(col, rgb((34, 38, 48)), jacket * inner)
    mix(col, rgb((176, 144, 122)), neck * inner)
    mix(col, rgb((190, 158, 134)), headm * inner)
    mix(col, rgb((40, 32, 28)), hair * headm * inner)
    # shirt collar and tie: a white V and a dark stripe
    collar = paste(shape, fill(cv.px([(cx - 0.016, pz0 + 0.052), (cx, pz0 + 0.034), (cx + 0.016, pz0 + 0.052), (cx + 0.010, pz0 + 0.054), (cx, pz0 + 0.043), (cx - 0.010, pz0 + 0.054)]), shape))
    tie = paste(shape, fill(cv.px([(cx - 0.0055, pz0 + 0.040), (cx + 0.0055, pz0 + 0.040), (cx + 0.0085, pz0), (cx - 0.0085, pz0)]), shape))
    mix(col, rgb((228, 228, 226)), collar * jacket * inner)
    mix(col, rgb((20, 40, 96)), tie * inner)
    # soft light on the face and a vignette, a film grain
    vig = 1 - 0.30 * np.clip(np.hypot((X - cx) / 0.07, (Z - (pz0 + 0.06)) / 0.10) - 0.8, 0, 1)
    col = np.where(inner[..., None] > 0, col * vig[..., None], col)
    grain = (noise(shape, 1.1, seed + 3) - 0.5) * 0.10
    col = np.where(inner[..., None] > 0, col * (1 + grain[..., None]), col)
    rough[box > 0.5] = 0.30

    # the right column: a title and four pairs of label and value lines
    ink = np.zeros(shape, np.float32)
    x0 = -0.010
    title = block_text(cv, shape, "ID 0417", 0.020, (x0, 0.100), 0.0030, align="left")
    ink = np.maximum(ink, title)
    labels = np.zeros(shape, np.float32)
    for i in range(4):
        zl = 0.066 - i * 0.0345
        labels = np.maximum(labels, typed_line(cv, shape, x0, zl, [0.052, 0.040, 0.060, 0.046][i], 0.0058, rng, 0.9))
        ink = np.maximum(ink, typed_line(cv, shape, x0, zl - 0.0155, [0.130, 0.104, 0.122, 0.082][i], 0.0092, rng, 1.35))
    # under the photo: two longer pairs
    for i, (ln, lv) in enumerate(((0.050, 0.250), (0.044, 0.190))):
        zl = -0.085 - i * 0.0465
        labels = np.maximum(labels, typed_line(cv, shape, -0.152, zl, ln, 0.0058, rng, 0.9))
        ink = np.maximum(ink, typed_line(cv, shape, -0.152, zl - 0.0155, lv, 0.0092, rng, 1.35))
    mix(col, rgb((118, 120, 130)), labels)
    mix(col, rgb((28, 30, 40)), ink)
    # a pen signature, looped
    sig = []
    for k in range(70):
        u = k / 69.0
        sig.append((-0.148 + 0.116 * u + 0.012 * math.sin(u * 17.0), -0.202 + 0.014 * math.sin(u * 23.0 + 1.0) * (1 - 0.4 * u) + 0.006 * math.cos(u * 41.0)))
    sigc = line_cover(cv.px(sig), 1.5, shape)
    mix(col, rgb((24, 30, 92)), sigc)
    # the hologram: a disc of turning silver and colour, rings pressed into it
    hc = (0.108, -0.175)
    holo = circle_cover(cv, hc, 0.034, shape)
    ang = np.arctan2(Z - hc[1], X - hc[0])
    rr = np.hypot(X - hc[0], Z - hc[1])
    tint = np.dstack([0.78 + 0.18 * np.sin(ang * 3 + rr * 120), 0.80 + 0.16 * np.sin(ang * 3 + rr * 120 + 2.1), 0.84 + 0.16 * np.sin(ang * 3 + rr * 120 + 4.2)])
    mix(col, np.clip(tint, 0, 1) * (0.85 + 0.15 * np.cos(rr * 500)[..., None]), holo)
    for q in (0.012, 0.022, 0.030):
        r_ = np.clip(1 - np.abs(rr - q) / 0.0012, 0, 1)
        mix(col, rgb((90, 96, 110)), r_ * holo * 0.5)
        micro -= 0.0003 * r_ * holo
    hstar = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        r2 = 0.018 if k % 2 == 0 else 0.0075
        hstar.append((hc[0] + r2 * math.cos(a), hc[1] + r2 * math.sin(a)))
    mix(col, rgb((236, 238, 244)), paste(shape, fill(cv.px(hstar), shape)) * 0.8)
    rough[holo > 0.5] = 0.14
    metal[holo > 0.5] = 0.55
    # the bar code
    bars = np.zeros(shape, np.float32)
    x = -0.152
    while x < 0.150:
        wd = float(rng.choice([0.0016, 0.0016, 0.0032, 0.0048]))
        bars = np.maximum(bars, rect(x, -0.243, x + wd, -0.205))
        x += wd + float(rng.choice([0.0016, 0.0016, 0.0032]))
    mix(col, rgb((24, 26, 32)), bars)
    # printed ink stands a little proud of the laminate
    micro += 0.00028 * np.maximum.reduce([ink, bars, sigc * 0.6, head * 0.0])
    micro += 0.0002 * (fibre)
    rough = np.where(ink > 0.5, 0.52, rough)
    return {"color": np.clip(col, 0, 1), "rough": rough, "metal": metal, "relief": micro, "size": (cv.w, cv.h),
            "step": (1.0 / cv.sx, 1.0 / cv.sz)}


# The leather ---------------------------------------------------------------------------------------------------------


def leather(seed=23):
    """Black pebbled leather for a wallet half in its own frame (D.LEATHER_BOX): round-topped cells of about 3 mm
    with dark grooves between them (a Voronoi cell map), a slow wrinkle, rubbed edges, and the fold's crease down
    the side at u = 0 (both halves are laid so that their fold is on that side)."""
    cv = Canvas(D.LEATHER_RECT, D.LEATHER_BOX)
    shape = (cv.h, cv.w)
    X, Z = cv.grid()
    rng = np.random.default_rng(seed)
    cell = 0.0105
    nx, nz = int((D.LEATHER_BOX[2] - D.LEATHER_BOX[0]) / cell) + 4, int((D.LEATHER_BOX[3] - D.LEATHER_BOX[1]) / cell) + 4
    pts = rng.random((nz, nx, 2)).astype(np.float32)
    tint = rng.random((nz, nx)).astype(np.float32)
    gx = np.floor((X - D.LEATHER_BOX[0]) / cell).astype(int) + 1
    gz = np.floor((Z - D.LEATHER_BOX[1]) / cell).astype(int) + 1
    f1 = np.full(shape, 9.0, np.float32)
    f2 = np.full(shape, 9.0, np.float32)
    ident = np.zeros(shape, np.float32)
    for dz in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx, cz = gx + dx, gz + dz
            px = D.LEATHER_BOX[0] + (cx - 1 + pts[cz, cx, 0]) * cell
            pz = D.LEATHER_BOX[1] + (cz - 1 + pts[cz, cx, 1]) * cell
            d = np.hypot(X - px, Z - pz) / cell
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            ident = np.where(closer, tint[cz, cx], ident)
            f1 = np.where(closer, d, f1)
    edge = np.clip((f2 - f1) / 0.62, 0, 1)
    dome = edge * edge * (3 - 2 * edge) * (0.82 + 0.18 * np.clip(1 - f1, 0, 1))
    wrinkle = noise(shape, 38.0, seed + 1) - 0.5
    fine = noise(shape, 1.5, seed + 2) - 0.5
    micro = 0.0016 * dome + 0.0008 * wrinkle + 0.0003 * fine
    col = np.zeros(shape + (3,), np.float32)
    base = rgb((22, 19, 19))
    col[...] = base
    col *= (0.90 + 0.22 * ident)[..., None]
    col *= (0.60 + 0.40 * dome)[..., None]
    col += np.array([0.018, 0.012, 0.008], np.float32) * (dome * (0.6 + 0.8 * ident))[..., None]
    # the fold: a darker valley and a soft rolled lip beside it
    u = X - D.LEATHER_BOX[0]
    crease = np.exp(-(u / 0.011) ** 2)
    lip = np.exp(-((u - 0.028) / 0.013) ** 2)
    micro += -0.0035 * crease + 0.0020 * lip
    col *= (1 - 0.5 * crease)[..., None]
    # the rubbed edges of a handled wallet: a little lighter and smoother
    ex = np.clip((np.abs(X) - 0.19) / 0.02, 0, 1) + np.clip((np.abs(Z) - 0.282) / 0.018, 0, 1)
    ex = np.clip(ex, 0, 1) * (0.5 + noise(shape, 6.0, seed + 3))
    col *= (1 + 0.45 * ex)[..., None]
    rough = np.clip(0.92 - 0.20 * dome - 0.12 * ex + 0.05 * fine, 0.3, 1.0).astype(np.float32)
    return {"color": np.clip(col, 0, 1), "rough": rough, "metal": np.zeros(shape, np.float32), "relief": micro,
            "size": (cv.w, cv.h), "step": (1.0 / cv.sx, 1.0 / cv.sz)}


# Writing a preview ------------------------------------------------------------------------------------------------------


def write_png(path, arr):
    """arr: uint8 [h, w, 3], row 0 on top."""
    h, w, _ = arr.shape
    raw = b"".join(b"\x00" + arr[i].tobytes() for i in range(h))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def preview(result, path, relief_path=None):
    img = (np.clip(result["color"], 0, 1) * 255).astype(np.uint8)[::-1]
    write_png(path, img)
    if relief_path:
        du, dv = result["step"]
        n = normals_from(result["relief"] + result.get("height", 0) * 0.0, du, dv)
        light = np.array([-0.5, 0.6, 0.62])
        light /= np.linalg.norm(light)
        shade = np.clip(((n * 2 - 1) * light).sum(axis=2), 0, 1)
        write_png(relief_path, (shade[..., None].repeat(3, axis=2) * 255).astype(np.uint8)[::-1])


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    s = shield()
    preview(s, os.path.join(out, "shield.png"), os.path.join(out, "shield_relief.png"))
    c = card()
    preview(c, os.path.join(out, "card.png"), os.path.join(out, "card_relief.png"))
    preview(leather(), os.path.join(out, "leather.png"), os.path.join(out, "leather_relief.png"))
    print("done", s["size"], c["size"])
