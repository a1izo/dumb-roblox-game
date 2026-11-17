"""Ticket V1.6 of docs/handoff/vfx-rework-plan-2026-11-16.md: the FLOOR textures, four single 1024 px images, Route E (numpy
with noise.py, no Blender). Seen from straight above, white and grey so the game tints them.

    VfxCrackA   matter  a spider crack from an impact point: ragged central hole, radial cracks that branch, short links between
                        them, hairlines, chips; a near-black groove, a lit lip on the side that faces the light, a dark lip on
                        the other side, soot in the corner of the groove
    VfxCrackB   matter  one long fracture across the cell: it swells and pinches shut, kinks like split stone, a few branches, a
                        second hairline fracture beside it, hairlines, chips, broken edges
    VfxScorch   matter  a burn mark: soft sooty falloff and spatter outside, a hard ragged charred edge, a dark core of crust
                        plates with ash seams and pits; no glow (it is matter)
    VfxSigil    light   the floor circle (a remake of VfxCircle): rings and a star drawn by a hand with a brush (the weight
                        swells and thins, the ring is a spiral that does not quite close, dry-brush tails), a band of abstract
                        glyph-like marks (no letters), irregular ticks, a seven-point star, nodes, a small inner figure

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/vfx/tex_floor.py [names]
        [--preview OUTDIR]       (numpy only; writes art/export/textures/<name>.png, and with --preview <name>_look.png)

TEX_QUICK=1 draws at 1x (fast, rough: for looking at shapes, never for the final PNGs).

The cracks are shaded from a height field: the groove is a hole, its lip is a bevel (steepest at the groove's edge), chips are
bumps; the light comes from above left, so the lip on the lower right of a groove faces the light (white) and the lip on the
upper left faces away (black). Everywhere the surface is flat the image is clear, so the floor shows through. The helpers are
this file's own copies (tex_matter.py, tex_slash.py, textures.py, draw.py and noise.py are not edited by this ticket).
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from vfx import draw as D  # noqa: E402
from vfx import noise as N  # noqa: E402

ART = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEXTURES = os.path.join(ART, "export", "textures")

BUILDERS = {}
QUICK = bool(os.environ.get("TEX_QUICK"))
SS = 1 if QUICK else 2  # drawn at SS x 1024 and boxed down
OUT = 1024
SAFE = 0.962  # nothing is drawn past this (the image runs -1..1; 4 px is 0.0078, so 0.962 leaves 19 px: the soft edges need it)
EDGE = 0.985  # the hard limit of the window: 4 px of clear
LIGHT = np.array([-0.5, -0.7, 0.55])  # towards the light (x right, y down, z at us): above and left
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def texture(fn):
    BUILDERS[fn.__name__] = fn
    return fn


# ---------------------------------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------------------------------


def sstep(a, b, x):
    return D.smoothstep(a, b, x)


def window(x, y):
    """1 inside the safe square, 0 from EDGE outward (nothing may touch the image's edge)."""
    wx = np.clip((EDGE - np.abs(x)) / (EDGE - SAFE), 0, 1)
    wy = np.clip((EDGE - np.abs(y)) / (EDGE - SAFE), 0, 1)
    return wx * wy


def nz2(a, b, f, octaves, seed):
    """Layered 2D noise, about -1..1."""
    return np.clip(N.fbm2(a * f + 7.1, b * f + 3.3, octaves=octaves, seed=seed) * 1.7, -1.0, 1.0)


def smooth_knots(rng, n, lo, hi, count=None):
    """A smooth random curve over n samples: random knots (about every 6 samples) joined by a cosine ease."""
    k = count or max(3, n // 6)
    knots = rng.uniform(lo, hi, k + 1)
    t = np.linspace(0, k, n)
    i = np.minimum(t.astype(int), k - 1)
    f = t - i
    f = 0.5 - 0.5 * np.cos(np.pi * f)
    return knots[i] * (1 - f) + knots[i + 1] * f


def box_blur(a, r, passes=3):
    """A separable box blur by cumulative sums (edges clamp), 3 passes is close to a gaussian."""
    out = a.astype(np.float32)
    for _ in range(passes):
        for ax in (0, 1):
            k = 2 * r + 1
            pad = [(0, 0), (0, 0)]
            pad[ax] = (r + 1, r)
            p = np.pad(out, pad, mode="edge")
            c = np.cumsum(p, axis=ax, dtype=np.float64)
            hi = np.take(c, np.arange(k, c.shape[ax]), axis=ax)
            lo = np.take(c, np.arange(0, c.shape[ax] - k), axis=ax)
            out = ((hi - lo) / k).astype(np.float32)
    return out


def _patch(n, y0, y1, x0, x1):
    half = n / 2
    ys = (np.arange(y0, y1) + 0.5 - half) / half
    xs = (np.arange(x0, x1) + 0.5 - half) / half
    return np.meshgrid(ys, xs, indexing="ij")


def _box(n, cy, cx, ry, rx):
    """Pixel bounds (clamped) of a box centred (cy, cx) with half sizes (ry, rx), in grid units."""
    half = n / 2
    y0 = int(max(0, math.floor((cy - ry + 1) * half) - 1))
    y1 = int(min(n, math.ceil((cy + ry + 1) * half) + 1))
    x0 = int(max(0, math.floor((cx - rx + 1) * half) - 1))
    x1 = int(min(n, math.ceil((cx + rx + 1) * half) + 1))
    return y0, y1, x0, x1


# ---------------------------------------------------------------------------------------------------------------------
# cracks: paths, a distance field, a height field, shading
# ---------------------------------------------------------------------------------------------------------------------


def trace(rng, p0, ang, length, w0, w1, step=0.02, wander=0.06, kink=0.15, kink_mag=(0.3, 0.75), bound=0.93,
          target=None, pull=0.0, swell=(0.7, 1.35), taper=0.85):
    """A crack path from p0 = (y, x): a random walk with now and then a sharp kink, as stone splits. Returns (points,
    half widths): the width runs from w0 at the start down to w1 at the end, times a smooth uneven swell."""
    pts = [np.array(p0, dtype=float)]
    a = ang
    done = 0.0
    while done < length:
        a += rng.normal(0, wander)
        if rng.random() < kink:
            a += rng.choice([-1, 1]) * rng.uniform(*kink_mag)
        if target is not None and pull:
            want = math.atan2(target[0] - pts[-1][0], target[1] - pts[-1][1])
            diff = (want - a + math.pi) % (2 * math.pi) - math.pi
            a += pull * diff
        s = step * rng.uniform(0.6, 1.5)
        q = pts[-1] + s * np.array([math.sin(a), math.cos(a)])
        if abs(q[0]) > bound or abs(q[1]) > bound:
            # end on the boundary
            d = np.array([math.sin(a), math.cos(a)])
            tmax = s
            for ax in (0, 1):
                if abs(q[ax]) > bound and abs(d[ax]) > 1e-9:
                    tmax = min(tmax, (math.copysign(bound, q[ax]) - pts[-1][ax]) / d[ax])
            if tmax > 1e-4:
                pts.append(pts[-1] + tmax * d)
            break
        pts.append(q)
        done += s
    pts = np.array(pts)
    if len(pts) < 3:
        pts = np.vstack([pts, pts[-1] + 1e-3])
    seg = np.hypot(*(pts[1:] - pts[:-1]).T)
    cum = np.concatenate([[0], np.cumsum(seg)])
    t = cum / max(cum[-1], 1e-9)
    sw = smooth_knots(rng, len(pts), *swell)
    w = (w1 + (w0 - w1) * (1 - t) ** taper) * sw
    return pts, np.maximum(w, 0.0013)


def heading(pts, i):
    a, b = pts[max(0, i - 1)], pts[min(len(pts) - 1, i + 1)]
    return math.atan2(b[0] - a[0], b[1] - a[1])


def grow(rng, paths, pts, w, depth, max_depth, rate, len_frac, length, bound=0.93, wander=0.08, kink=0.16):
    """Adds branches along (pts, w) to `paths`, each a smaller trace; recursion to max_depth."""
    paths.append((pts, w))
    if depth >= max_depth:
        return
    last = -99
    for i in range(3, len(pts) - 2):
        if i - last < 4 or rng.random() > rate:
            continue
        last = i
        side = rng.choice([-1, 1])
        ang = heading(pts, i) + side * rng.uniform(0.45, 1.15)
        ln = length * rng.uniform(*len_frac)
        w0 = max(w[i] * 0.62, 0.0016 if depth + 1 >= 2 else 0.003)
        bp, bw = trace(rng, pts[i], ang, ln, w0, 0.0013, step=0.016 if depth >= 1 else 0.02, wander=wander, kink=kink,
                       bound=bound)
        grow(rng, paths, bp, bw, depth + 1, max_depth, rate * 0.8, len_frac, ln, bound, wander, kink)


def point_at(pts, dist_from, r):
    """The first point on a path whose distance from `dist_from` is at least r (or None)."""
    d = np.hypot(pts[:, 0] - dist_from[0], pts[:, 1] - dist_from[1])
    k = np.nonzero(d >= r)[0]
    return pts[k[0]] if len(k) else None


class Field:
    """A signed distance to a set of tapered segments (negative inside), and the half width of the nearest one."""

    def __init__(self, n):
        self.n = n
        self.sd = np.full((n, n), 9.0, dtype=np.float32)
        self.wl = np.zeros((n, n), dtype=np.float32)

    def seg(self, a, b, wa, wb):
        pad = 6.0 * max(wa, wb) + 0.016
        pad = min(pad, 0.085)
        y0, y1, x0, x1 = _box(self.n, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2, abs(a[0] - b[0]) / 2 + pad,
                              abs(a[1] - b[1]) / 2 + pad)
        if y1 <= y0 or x1 <= x0:
            return
        Y, X = _patch(self.n, y0, y1, x0, x1)
        dist, t = D.segment(Y, X, a[0], a[1], b[0], b[1])
        w = wa + (wb - wa) * t
        s = (dist - w).astype(np.float32)
        view = self.sd[y0:y1, x0:x1]
        m = s < view
        view[m] = s[m]
        self.wl[y0:y1, x0:x1][m] = w[m].astype(np.float32)

    def path(self, pts, w):
        for k in range(len(pts) - 1):
            self.seg(pts[k], pts[k + 1], w[k], w[k + 1])


def chips_height(n, rng, chips):
    """Height bumps: chips of stone beside the cracks. chips: list of (y, x, radius, height). Elliptical with a ragged
    outline (a few straight facets), as small broken pieces are."""
    H = np.zeros((n, n), dtype=np.float32)
    for (cy, cx, r, h) in chips:
        y0, y1, x0, x1 = _box(n, cy, cx, r * 1.5, r * 1.5)
        if y1 <= y0 or x1 <= x0:
            continue
        Y, X = _patch(n, y0, y1, x0, x1)
        ang = rng.uniform(0, math.pi)
        el = rng.uniform(0.55, 1.0)
        c, s = math.cos(ang), math.sin(ang)
        u = (X - cx) * c + (Y - cy) * s
        v = (-(X - cx) * s + (Y - cy) * c) / el
        rr = np.hypot(u, v)
        th = np.arctan2(v, u)
        facets = 5 + int(rng.integers(0, 3))
        rough = 1.0 - 0.28 * np.abs(np.sin(th * facets / 2 + rng.uniform(0, 3)))
        q = np.clip(1.0 - rr / (r * rough), 0, 1)
        H[y0:y1, x0:x1] = np.maximum(H[y0:y1, x0:x1], (h * q ** 0.7).astype(np.float32))
    return H


def shade_cracks(field, rng, seed, chips=(), extra_alpha=None):
    """From a Field (and chips) to an (n, n, 4) image: AO soot, lit and dark lip from the height field, the groove."""
    n = field.n
    y, x = D.grid(n)
    pix = 2.0 / n
    wl = field.wl
    # broken edges: noise moves the groove's edge by a part of its width, and the odd chip is bitten out
    n_a = nz2(x, y, 52, 4, seed)
    n_b = nz2(x, y, 17, 3, seed + 3)
    amp = 0.30 * wl + 0.0006
    sd = field.sd + amp * n_a
    bite = np.clip((n_b - 0.45) * 2.2, 0, 1)
    sd = sd - bite * wl * 0.9 * (field.sd < 0.02)
    lw = np.maximum(2.0 * wl + 0.003, 0.005)  # the lip's width
    spos = np.clip(sd, 0, None)
    bh = 0.95 * lw
    H = -bh * np.exp(-spos / (0.38 * lw))
    H = np.where(sd < 0, -bh, H)
    grain = nz2(x, y, 150, 2, seed + 9)
    H = H + 0.10 * lw * grain * np.exp(-spos / (2.2 * lw))
    if len(chips):
        H = H + chips_height(n, rng, chips)
    hy, hx = np.gradient(H, pix)
    nrm = np.sqrt(hx * hx + hy * hy + 1.0)
    lam = (-hx * LIGHT[0] - hy * LIGHT[1] + LIGHT[2]) / nrm
    dl = lam - LIGHT[2]
    lit = np.clip(dl * 2.4, 0, 1) ** 0.85
    dark = np.clip(-dl * 2.8, 0, 1) ** 0.85 * 0.92
    groove = D.aa(sd, pix)
    ao = 0.34 * np.exp(-spos / (2.4 * lw)) * (1 - groove)
    ao = ao * (0.75 + 0.25 * (0.5 + 0.5 * nz2(x, y, 9, 3, seed + 5)))
    img = np.zeros((n, n, 4), dtype=np.float32)
    img = D.over(img, D.rgba(0.05, ao))
    img = D.over(img, D.rgba(0.04, dark))
    lv = 0.9 + 0.1 * grain
    img = D.over(img, D.rgba(lv, lit))
    gv = 0.03 + 0.05 * np.clip(0.5 + 0.5 * nz2(x, y, 90, 3, seed + 11), 0, 1) ** 2
    img = D.over(img, D.rgba(gv, groove))
    if extra_alpha is not None:
        a, v = extra_alpha
        img = D.over(D.rgba(v, a), img)  # under everything
    return img, (x, y)


def finish(img, xy):
    x, y = xy
    img = img.copy()
    img[..., 3] *= window(x, y)
    if img.shape[0] != OUT:
        img = D.resize(img, OUT, OUT)
    return D.bleed(img)


def lip_chips(rng, paths, count, wmin=0.0045):
    """Chip positions beside the wider parts of the cracks."""
    out = []
    cand = []
    for pts, w in paths:
        for i in range(len(pts)):
            if w[i] >= wmin:
                cand.append((pts[i], w[i], heading(pts, i)))
    if not cand:
        return out
    for _ in range(count):
        p, w, a = cand[int(rng.integers(0, len(cand)))]
        side = rng.choice([-1, 1])
        off = w * rng.uniform(1.6, 5.0) + 0.006
        cy = p[0] + side * off * math.cos(a)
        cx = p[1] - side * off * math.sin(a)
        r = rng.uniform(0.0035, 0.0075 + 0.5 * w)
        out.append((cy, cx, r, 0.8 * r))
    return out


@texture
def VfxCrackA(seed=4101):
    """A spider crack from an impact point (see the file's docstring)."""
    rng = np.random.default_rng(seed)
    n = OUT * SS
    field = Field(n)
    c = np.array([0.03, -0.04])
    paths = []
    # the radial cracks: uneven angles, uneven lengths; four of them run to the edge so the subject fills its cell
    count = 11
    gaps = rng.uniform(0.55, 1.6, count)
    angs = np.cumsum(gaps) / gaps.sum() * 2 * math.pi + rng.uniform(0, 6)
    long_ids = set(rng.choice(count, 4, replace=False).tolist())
    # make sure the long ones are spread (one per side, roughly): re-aim them
    targets = [(-0.8, 0.0), (0.0, 0.85), (0.85, -0.2), (0.0, -0.9)]
    for k, ti in enumerate(sorted(long_ids)):
        angs[ti] = math.atan2(targets[k][0] - c[0], targets[k][1] - c[1]) + rng.uniform(-0.25, 0.25)
    radials = []
    for k in range(count):
        ln = 1.8 if k in long_ids else rng.uniform(0.45, 0.95)
        w0 = rng.uniform(0.008, 0.0125) if k in long_ids else rng.uniform(0.006, 0.0105)
        start = c + 0.02 * np.array([math.sin(angs[k]), math.cos(angs[k])])
        pts, w = trace(rng, start, angs[k], ln, w0, 0.0016, step=0.022, wander=0.04, kink=0.11, kink_mag=(0.25, 0.55),
                       taper=1.3)
        radials.append((pts, w))
        grow(rng, paths, pts, w, 0, 3, 0.05, (0.15, 0.35), ln if ln < 1.2 else 0.9)
    # a ragged hole at the impact point: fat short segments in every direction
    for k in range(9):
        a = rng.uniform(0, 2 * math.pi)
        ln = rng.uniform(0.02, 0.055)
        pts = np.array([c, c + ln * np.array([math.sin(a), math.cos(a)])])
        paths.append((pts, np.array([rng.uniform(0.014, 0.022), 0.006])))
    # short links between neighbouring radials at a few radii (the web), jagged, thinner than the radials
    order = np.argsort(angs % (2 * math.pi))
    for r in (0.13, 0.24, 0.38, 0.55):
        for idx in range(count):
            if rng.random() < 0.30:
                continue
            ra = radials[order[idx]][0]
            rb = radials[order[(idx + 1) % count]][0]
            pa, pb = point_at(ra, c, r * rng.uniform(0.9, 1.15)), point_at(rb, c, r * rng.uniform(0.9, 1.15))
            if pa is None or pb is None or np.hypot(*(pa - pb)) > 0.45:
                continue
            m = 3 + int(rng.integers(0, 3))
            pts = [pa]
            d = pb - pa
            perp = np.array([-d[1], d[0]]) / max(np.hypot(*d), 1e-6)
            for j in range(1, m):
                f = j / m
                pts.append(pa + d * f + perp * rng.normal(0, 0.014))
            pts.append(pb)
            pts = np.array(pts)
            w = np.linspace(0.0050, 0.0030, len(pts)) * rng.uniform(0.8, 1.3)
            paths.append((pts, w))
    for pts, w in paths:
        field.path(pts, w)
    chips = lip_chips(rng, paths, 70)
    # a dusting of damage round the impact: a dark soft bruise, mottled
    img, xy = shade_cracks(field, rng, seed, chips)
    x, y = xy
    r = np.hypot(x - c[1], y - c[0])
    mott = np.clip(0.55 + 0.45 * nz2(x, y, 11, 4, seed + 21), 0, 1)
    pits = np.clip(nz2(x, y, 120, 2, seed + 22) - 0.25, 0, 1)
    bruise = np.exp(-(r / 0.26) ** 2) * 0.34 * mott
    bruise = np.maximum(bruise, np.exp(-(r / 0.17) ** 2) * 0.55 * pits)
    img = D.over(D.rgba(0.1, bruise), img)
    return finish(img, xy)


@texture
def VfxCrackB(seed=4202):
    """One long fracture across the cell (see the file's docstring)."""
    rng = np.random.default_rng(seed)
    n = OUT * SS
    field = Field(n)
    paths = []
    start = np.array([-0.80, -0.93])
    end = np.array([0.82, 0.93])
    ang = math.atan2(end[0] - start[0], end[1] - start[1])
    pts, w = trace(rng, start, ang, 3.0, 0.004, 0.004, step=0.016, wander=0.045, kink=0.2, kink_mag=(0.28, 0.6),
                   target=end, pull=0.1)
    # the opening swells and pinches shut: lens-shaped widths along the length
    t = np.linspace(0, 1, len(pts))
    lens = np.zeros_like(t)
    for _ in range(4):
        c0, wd = rng.uniform(0.1, 0.9), rng.uniform(0.07, 0.16)
        lens = np.maximum(lens, np.exp(-((t - c0) / wd) ** 2) * rng.uniform(0.55, 1.0))
    w = 0.0034 + 0.0085 * lens ** 1.1
    w = w * smooth_knots(rng, len(pts), 0.8, 1.25) * (1 - 0.7 * t ** 6)
    w = np.maximum(w, 0.0015)
    # a few branches (long and few) and fine hairlines
    grow_paths = []
    grow(rng, grow_paths, pts, w, 0, 1, 0.045, (0.2, 0.45), 1.2, wander=0.06, kink=0.2)
    paths.extend(grow_paths[:1])
    for bp, bw in grow_paths[1:]:
        paths.append((bp, bw))
    # a second fracture running beside the first for part of its length, hairline, which meets it again
    k0 = int(len(pts) * rng.uniform(0.18, 0.3))
    k1 = int(len(pts) * rng.uniform(0.55, 0.7))
    side = pts[k0:k1].copy()
    a = heading(pts, (k0 + k1) // 2)
    off = np.array([-math.cos(a), math.sin(a)]) * 0.045
    for i in range(len(side)):
        fade = math.sin(math.pi * i / max(len(side) - 1, 1)) ** 0.5
        side[i] = side[i] + off * fade + rng.normal(0, 0.003, 2)
    paths.append((side, np.full(len(side), 0.0022) * smooth_knots(rng, len(side), 0.8, 1.4)))
    # extra hairlines: short, from random points of the main fracture
    for _ in range(11):
        i = int(rng.integers(6, len(pts) - 6))
        ang2 = heading(pts, i) + rng.choice([-1, 1]) * rng.uniform(0.35, 1.3)
        bp, bw = trace(rng, pts[i], ang2, rng.uniform(0.05, 0.2), 0.0024, 0.0013, step=0.013, wander=0.09, kink=0.22)
        paths.append((bp, bw))
    for pp, ww in paths:
        field.path(pp, ww)
    chips = lip_chips(rng, paths, 80, wmin=0.0035)
    img, xy = shade_cracks(field, rng, seed, chips)
    x, y = xy
    # a pale spall along the opening where the surface has flaked: a little dust, laid over
    sd = field.sd
    near = np.exp(-np.clip(sd, 0, None) / 0.03)
    mott = np.clip(0.5 + 0.5 * nz2(x, y, 14, 4, seed + 23), 0, 1)
    dust = near * mott * 0.2 * (field.wl > 0.004)
    img = D.over(D.rgba(0.12, dust), img)
    return finish(img, xy)


# ---------------------------------------------------------------------------------------------------------------------
# scorch
# ---------------------------------------------------------------------------------------------------------------------


@texture
def VfxScorch(seed=4303):
    """A burn mark: matter, no glow (see the file's docstring)."""
    rng = np.random.default_rng(seed)
    n = OUT * SS
    y, x = D.grid(n)
    # a long-ish uneven blob: rotate, stretch, warp
    ang = 0.5
    c, s = math.cos(ang), math.sin(ang)
    u = (x * c + y * s) / 1.0
    v = (-x * s + y * c) / 0.82
    wu, wv = N.warp2(u * 1.6, v * 1.6, 0.16, 3, seed)
    th = np.arctan2(wv, wu)
    rr = np.hypot(wu, wv) / 1.6
    # lobes: the radius follows the angle through a few low frequencies, plus noise
    tongue = np.clip(0.6 * np.sin(7 * th + 1.3) + 0.5 * np.sin(11 * th + 4.1) + 0.4 * np.sin(17 * th + 0.4), 0, 1)
    lobes = 1.0 + 0.17 * np.sin(2 * th + 0.7) + 0.12 * np.sin(3 * th + 2.1) + 0.07 * np.sin(5 * th + 4.0) + 0.16 * tongue
    ragged = 0.07 * nz2(x, y, 9, 4, seed + 1) + 0.05 * nz2(x, y, 38, 3, seed + 2) + 0.02 * nz2(x, y, 110, 2, seed + 14)
    R = 0.66
    m = (R * lobes - rr) / R + ragged  # > 0 inside the hard edge
    pix = 2.0 / n
    # hard edge: a crisp cut at m = 0, anti-aliased over a pixel in m units
    k = pix / R * 1.2
    inside = np.clip(m / k + 0.5, 0, 1)
    # the crust: plates (cellular cracks) with ash seams, and pits with a pale rim
    plates = _cells(x, y, 7.5, seed + 4)
    plates2 = _cells(x, y, 24.0, seed + 5)
    seam = np.clip(1.0 - plates[1] / 0.10, 0, 1)  # near a cell border: 1
    seam2 = np.clip(1.0 - plates2[1] / 0.07, 0, 1)
    grain = nz2(x, y, 90, 3, seed + 6)
    mottle = nz2(x, y, 6, 4, seed + 7)
    pits = _pits(x, y, seed + 8)
    # three values: a dark core, a lighter scorched band inside the edge (the surface is browned, not burnt through), and
    # a charred line right at the hard edge
    core = 0.045 + 0.035 * (0.5 + 0.5 * mottle) + 0.03 * grain
    band = 0.28 + 0.14 * mottle + 0.06 * grain  # a browned band along the rim
    w_band = 1.0 - sstep(0.06, 0.30, m)
    val = core * (1 - w_band) + band * w_band
    # plates are a little lighter at their middles (they curl up), seams run grey between them (ash), a patch or two of ash
    val = val + 0.15 * plates[3] ** 1.5 * sstep(0.06, 0.3, m)
    ash = np.clip(seam * 0.42 + seam2 * 0.2, 0, 1) * (0.4 + 0.6 * (0.5 + 0.5 * mottle)) * sstep(0.06, 0.3, m)
    ashpatch = np.clip(nz2(x, y, 12, 4, seed + 9) - 0.0, 0, 1) * sstep(0.12, 0.4, m)
    val = val + 0.7 * ash + 0.85 * ashpatch
    # a charred line just inside the hard edge
    rim = np.exp(-(np.clip(m, 0, None) / 0.013) ** 2)
    val = val * (1 - 0.8 * rim)
    # pits: a dark centre, a pale ring
    val = val * (1 - 0.9 * pits[0]) + 0.38 * pits[1] * (1 - pits[0])
    val = np.clip(val, 0.02, 0.9)
    # the soft part outside: soot, falling off in streaks that point away from the middle, plus spatter
    out = np.clip(-m, 0, None)
    streak = 0.5 + 0.5 * N.fbm2(np.arctan2(y, x) * 5.0 + 3.0, np.hypot(x, y) * 1.3, octaves=3, seed=seed + 10)
    fall = np.exp(-(out / (0.07 + 0.16 * streak)) ** 1.15)
    soot = fall * (0.5 + 0.5 * np.clip(nz2(x, y, 26, 4, seed + 11) * 0.8 + 0.5, 0, 1)) * 0.72
    spat = np.clip(nz2(x, y, 140, 2, seed + 12) - 0.35, 0, 1) * np.exp(-(out / 0.3) ** 1.2) * 1.6
    spat = np.clip(spat, 0, 0.8)
    soft_a = np.clip(np.maximum(soot, spat), 0, 0.9)
    soft_v = 0.10 + 0.10 * (0.5 + 0.5 * nz2(x, y, 20, 3, seed + 13))
    # the hard part: opaque; the crust is a little see-through only in the pale ash
    hard_a = inside * (0.97 - 0.12 * ashpatch)
    a = np.maximum(soft_a * (1 - inside), hard_a)
    v = np.where(inside > 0.5, val, soft_v)
    v = val * inside + soft_v * (1 - inside)
    img = D.rgba(v, a)
    img[..., 3] *= window(x, y)
    if SS != 1:
        img = D.resize(img, OUT, OUT)
    return D.bleed(img)


def _cells(x, y, f, seed):
    """Cellular (Worley) distances at frequency f: (nearest, second nearest, nearest - second, 1 - nearest scaled)."""
    rng = np.random.default_rng(seed)
    gx, gy = x * f, y * f
    ix, iy = np.floor(gx).astype(np.int32), np.floor(gy).astype(np.int32)
    d1 = np.full(x.shape, 9.0, dtype=np.float32)
    d2 = np.full(x.shape, 9.0, dtype=np.float32)
    # hash-based feature points per lattice cell
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx, cy = ix + dx, iy + dy
            h1 = _hash(cx * 73 + cy * 197, seed)
            h2 = _hash(cx * 151 + cy * 31, seed + 5)
            px_, py_ = cx + h1, cy + h2
            d = np.hypot(gx - px_, gy - py_).astype(np.float32)
            nd1 = np.minimum(d1, d)
            d2 = np.minimum(np.maximum(d1, d), d2)
            d1 = nd1
    mid = np.clip(1.0 - d1 / 0.9, 0, 1)
    return d1, d2 - d1 + d1 * 0, d2, mid


def _hash(i, seed):
    s = np.sin(i.astype(np.float64) * 12.9898 + seed * 78.233) * 43758.5453
    return (s - np.floor(s)).astype(np.float32)


def _pits(x, y, seed):
    """Ember pits: small irregular holes, dark in the middle, with a pale ash lip on the side that faces the light (up and
    left). (dark, lip) in 0..1. The lattice is warped by noise so no pit is a circle."""
    f = 26.0
    wy, wx = 0.35 * nz2(x, y, 31, 2, seed + 1), 0.35 * nz2(x, y, 29, 2, seed + 2)
    gx, gy = x * f + wx * 2.0, y * f + wy * 2.0
    ix, iy = np.floor(gx).astype(np.int32), np.floor(gy).astype(np.int32)
    dark = np.zeros(x.shape, dtype=np.float32)
    lip = np.zeros(x.shape, dtype=np.float32)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx, cy = ix + dx, iy + dy
            h1 = _hash(cx * 73 + cy * 197, seed)
            h2 = _hash(cx * 151 + cy * 31, seed + 5)
            h3 = _hash(cx * 11 + cy * 53, seed + 9)
            px_, py_ = cx + 0.2 + 0.6 * h1, cy + 0.2 + 0.6 * h2
            rad = 0.09 + 0.2 * h3 ** 2
            present = (h3 > 0.82).astype(np.float32)
            d = np.hypot(gx - px_, gy - py_)
            dark = np.maximum(dark, present * np.clip(1.0 - d / rad, 0, 1) ** 0.6)
            # the lip: a crescent where the point lies up-left of the pit's centre, just outside the hole
            side = np.clip(((px_ - gx) * 0.6 + (py_ - gy) * 0.8) / np.maximum(d, 1e-4), 0, 1)
            lip = np.maximum(lip, present * np.exp(-((d - rad * 1.2) / (rad * 0.3)) ** 2) * side ** 1.5)
    return dark, lip


# ---------------------------------------------------------------------------------------------------------------------
# sigil
# ---------------------------------------------------------------------------------------------------------------------


class Brush:
    """A canvas for strokes: coverage (0..1) and value (0..1). A stroke is a polyline with a width and a value at every
    point; the edge is anti-aliased; `dry` thins the ink into streaks towards the end of the stroke (a dry brush)."""

    def __init__(self, n, seed=0):
        self.n = n
        self.cov = np.zeros((n, n), dtype=np.float32)
        self.val = np.zeros((n, n), dtype=np.float32)
        self.seed = seed

    def stroke(self, pts, w, v=1.0, dry=0.0, soft=1.0):
        pts = np.asarray(pts, dtype=float)
        k = len(pts)
        w = np.broadcast_to(np.asarray(w, dtype=float), (k,))
        v = np.broadcast_to(np.asarray(v, dtype=float), (k,))
        seg = np.hypot(*(pts[1:] - pts[:-1]).T)
        cum = np.concatenate([[0], np.cumsum(seg)])
        total = max(cum[-1], 1e-9)
        pix = 2.0 / self.n * soft
        for i in range(k - 1):
            a, b = pts[i], pts[i + 1]
            pad = max(w[i], w[i + 1]) * 1.6 + 3 * pix
            y0, y1, x0, x1 = _box(self.n, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2, abs(a[0] - b[0]) / 2 + pad,
                                  abs(a[1] - b[1]) / 2 + pad)
            if y1 <= y0 or x1 <= x0:
                continue
            Y, X = _patch(self.n, y0, y1, x0, x1)
            dist, t = D.segment(Y, X, a[0], a[1], b[0], b[1])
            ww = w[i] + (w[i + 1] - w[i]) * t
            c = np.clip(0.5 - (dist - ww) / pix, 0, 1)
            if dry > 0:
                s = (cum[i] + t * (cum[i + 1] - cum[i])) / total
                lat = (-(X - a[1]) * (b[0] - a[0]) + (Y - a[0]) * (b[1] - a[1])) / max(seg[i], 1e-9)
                streak = 0.5 + 0.5 * N.perlin2(lat / max(w[i], 1e-4) * 1.7 + self.seed, s * total * 9.0, seed=self.seed)
                thr = dry * sstep(0.45, 1.0, s)
                c = c * sstep(thr - 0.15, thr + 0.1, streak)
            vv = v[i] + (v[i + 1] - v[i]) * t
            cv = self.cov[y0:y1, x0:x1]
            better = c > cv
            self.val[y0:y1, x0:x1] = np.where(better, vv, self.val[y0:y1, x0:x1])
            self.cov[y0:y1, x0:x1] = np.maximum(cv, c)


def hand_ring(br, rng, centre, R, w, turns=1.03, wob=0.008, drift=0.008, gap=None, vbase=0.9, press=1.0, dry=0.55):
    """A circle drawn in one go: a spiral of `turns` turns (so the end does not meet the start), the radius wobbling and
    drifting, the weight swelling and thinning by hand, heavy at the start, thin and dry at the end."""
    segs = max(40, int(2 * math.pi * R * turns / 0.011))
    th0 = rng.uniform(0, 2 * math.pi)
    th = th0 + np.linspace(0, 2 * math.pi * turns, segs)
    t = np.linspace(0, 1, segs)
    ph = rng.uniform(0, 6.28, 4)
    wobble = wob * (0.55 * np.sin(2 * th + ph[0]) + 0.3 * np.sin(3 * th + ph[1]) + 0.25 * np.sin(5 * th + ph[2])
                    + 0.15 * np.sin(9 * th + ph[3]))
    r = R + wobble + drift * t
    wl = w * smooth_knots(rng, segs, 0.4, 1.7, count=max(5, int(R * 14)))
    wl = wl * (1.0 + 0.5 * np.exp(-(t / 0.05) ** 2)) * np.clip(1 - 0.78 * sstep(0.82, 1.0, t), 0.1, 1) * press
    vals = vbase * smooth_knots(rng, segs, 0.72, 1.0, count=max(4, int(R * 10)))
    pts = np.stack([centre[0] + r * np.sin(th), centre[1] + r * np.cos(th)], axis=1)
    if gap is not None:
        # break the ring into arcs: gap is a list of (start_t, end_t) in 0..1 to leave empty
        edges = [0.0] + [e for g in gap for e in g] + [1.0]
        for j in range(0, len(edges), 2):
            i0, i1 = int(edges[j] * (segs - 1)), int(edges[j + 1] * (segs - 1))
            if i1 - i0 >= 2:
                wl2 = wl[i0:i1 + 1] * np.concatenate([[0.5, 0.8], np.ones(max(0, i1 - i0 - 3)), [0.8, 0.45]])[: i1 - i0 + 1]
                br.stroke(pts[i0:i1 + 1], wl2, vals[i0:i1 + 1], dry=dry * 0.5)
        return
    br.stroke(pts, wl, vals, dry=dry)


def hand_line(br, rng, a, b, w, bow=0.006, overshoot=(0.0, 0.025), v=0.92, dry=0.35, taper=True):
    """A straight stroke drawn by a hand: a slight bow, overshoots at both ends, thick in the middle."""
    a = np.array(a, dtype=float)
    b = np.array(b, dtype=float)
    d = b - a
    ln = max(np.hypot(*d), 1e-6)
    u = d / ln
    a = a - u * rng.uniform(*overshoot)
    b = b + u * rng.uniform(*overshoot)
    m = max(6, int(ln / 0.012))
    t = np.linspace(0, 1, m)
    perp = np.array([-u[1], u[0]])
    bend = bow * rng.uniform(-1, 1) * np.sin(np.pi * t)
    pts = a[None, :] + (b - a)[None, :] * t[:, None] + perp[None, :] * bend[:, None]
    wl = w * smooth_knots(rng, m, 0.7, 1.35, count=4)
    if taper:
        wl = wl * (0.45 + 0.55 * np.sin(np.pi * np.clip(t * 0.9 + 0.05, 0, 1)) ** 0.6)
    br.stroke(pts, wl, v * smooth_knots(rng, m, 0.8, 1.0, count=3), dry=dry)


def hand_circle(br, rng, c, r, w, turns=1.06, v=0.9):
    """A small circle: a short spiral that overshoots."""
    segs = max(14, int(2 * math.pi * r / 0.008))
    th = rng.uniform(0, 6.28) + np.linspace(0, 2 * math.pi * turns, segs)
    rr = r * (1 + 0.05 * np.sin(2 * th + rng.uniform(0, 6)) + np.linspace(0, 0.1, segs))
    pts = np.stack([c[0] + rr * np.sin(th), c[1] + rr * np.cos(th)], axis=1)
    wl = w * smooth_knots(rng, segs, 0.65, 1.3, count=4) * (1 - 0.5 * sstep(0.8, 1.0, np.linspace(0, 1, segs)))
    br.stroke(pts, wl, v, dry=0.2)


def dot(br, c, r, v=0.95):
    br.stroke([c, (c[0] + 1e-4, c[1] + 1e-4)], r, v)


def _glyph(kind, rng):
    """A glyph as strokes in local units (u outward, v along the band), about 1 unit across: lists of polylines and
    circles. Abstract marks, built so that none reads as a letter or a numeral."""
    j = lambda s=0.06: rng.normal(0, s)  # noqa: E731
    if kind == 0:  # a bar with a dot off to one side
        s = rng.choice([-1, 1])
        return {"lines": [[(-1.0, j()), (0.8, j())]], "dots": [(0.9 + j(), 0.9 * s)], "circles": []}
    if kind == 1:  # two nested chevrons (like arrowheads)
        return {"lines": [[(-0.9, -0.7), (0.0 + j(), 0.0), (-0.9, 0.7)], [(0.0, -0.55), (0.8 + j(), 0.0), (0.0, 0.55)]],
                "dots": [], "circles": []}
    if kind == 2:  # a comb: a bar along the band with three teeth towards the centre and a stub away
        return {"lines": [[(0.0, -1.0), (0.0, 1.0)], [(0, -0.8), (-0.9, -0.8 + j())], [(0, 0.0), (-0.9, j())],
                          [(0, 0.8), (-0.9, 0.8 + j())], [(0, 0.2), (0.7, 0.2)]], "dots": [], "circles": []}
    if kind == 3:  # a triangle outline with a dot on its point
        return {"lines": [[(-0.8, -0.8), (-0.8, 0.8), (0.6, j()), (-0.8, -0.8)]], "dots": [(0.95, j(0.1))], "circles": []}
    if kind == 4:  # a crescent: an arc with a dot in its mouth
        th = np.linspace(0.5, 2 * math.pi - 0.6, 14)
        return {"lines": [[(0.9 * math.cos(t), 0.9 * math.sin(t)) for t in th]], "dots": [(0.25, 0.0)], "circles": []}
    if kind == 5:  # a hook: a small spiral
        th = np.linspace(0, 3.4 * math.pi, 22)
        rr = 0.12 + 0.2 * th / math.pi
        return {"lines": [[(rr[i] * math.cos(th[i]) - 0.1, rr[i] * math.sin(th[i])) for i in range(len(th))]],
                "dots": [], "circles": []}
    if kind == 6:  # a diamond with a bar through it that does not reach the ends
        return {"lines": [[(0, -0.9), (0.8, 0), (0, 0.9), (-0.8, 0), (0, -0.9)], [(-0.45, -0.3), (0.5, 0.35)]],
                "dots": [], "circles": []}
    if kind == 7:  # three dots on a slant
        return {"lines": [], "dots": [(-0.7, -0.8), (0.0, 0.0), (0.7, 0.8)], "circles": []}
    if kind == 8:  # a zigzag bar of two teeth
        return {"lines": [[(-0.9, -1.0), (0.4, -0.45), (-0.4, 0.15), (0.9, 0.7)]], "dots": [], "circles": []}
    if kind == 9:  # a ring with a short bar that does not touch it
        return {"lines": [[(0.95, -0.5), (0.95, 0.5)]], "dots": [], "circles": [((-0.1, 0.0), 0.55)]}
    if kind == 10:  # two short arcs facing each other
        th = np.linspace(-1.0, 1.0, 9)
        return {"lines": [[(0.65 * math.cos(t) - 0.5, 0.65 * math.sin(t)) for t in th],
                          [(-0.65 * math.cos(t) + 0.5, 0.65 * math.sin(t)) for t in th]], "dots": [], "circles": []}
    # 11: a stepped line (a staircase) with a dot
    return {"lines": [[(-0.9, -0.9), (-0.9, -0.3), (-0.2, -0.3), (-0.2, 0.3), (0.5, 0.3), (0.5, 0.9)]],
            "dots": [(0.9, -0.7)], "circles": []}


def place_glyph(br, rng, kind, centre, r, th, size, w):
    """Draws glyph `kind` at radius r, angle th; u points outward along the radius, v along the band."""
    g = _glyph(kind, rng)
    su, sv = rng.uniform(0.85, 1.2), rng.uniform(0.85, 1.2)
    tilt = rng.normal(0, 0.18)
    cth, sth = math.cos(th), math.sin(th)
    ct, st = math.cos(tilt), math.sin(tilt)

    def world(p):
        u0, v0 = p[0] * su * size, p[1] * sv * size
        u1, v1 = u0 * ct - v0 * st, u0 * st + v0 * ct
        rr = r + u1
        # v is along the band: convert the tangential offset to an angle step
        a = th + v1 / max(r, 0.05)
        return (centre[0] + rr * math.sin(a), centre[1] + rr * math.cos(a))

    wl = w * rng.uniform(0.8, 1.25)
    for line in g["lines"]:
        pts = []
        for i in range(len(line) - 1):
            p, q = np.array(line[i]), np.array(line[i + 1])
            m = max(2, int(np.hypot(*(q - p)) * size / 0.01))
            for k in range(m):
                pts.append(p + (q - p) * k / m)
        pts.append(np.array(line[-1]))
        wp = np.array([world(p) for p in pts])
        wls = wl * smooth_knots(rng, len(wp), 0.75, 1.25, count=3)
        br.stroke(wp, wls, 0.92 * rng.uniform(0.85, 1.0), dry=0.12)
    for d_ in g["dots"]:
        dot(br, world(d_), wl * 1.5, 0.95)
    for (cc, rad) in g["circles"]:
        wc = world(cc)
        hand_circle(br, rng, wc, rad * size, wl * 0.9, v=0.9)


@texture
def VfxSigil(seed=4404):
    """The floor circle: rings and a star drawn by a brush (see the file's docstring)."""
    rng = np.random.default_rng(seed)
    n = OUT * SS
    br = Brush(n, seed)
    cen = np.array([0.004, -0.003])  # (y, x): nothing is dead centre
    lw = 1.0  # the base line weight (grid units: 0.002 is 1 px at 1024)

    # --- the rings, each drawn in one stroke, each a little off its neighbour's centre
    def off():
        return cen + rng.normal(0, 0.0045, 2)

    hand_ring(br, rng, off(), 0.912, 0.0105 * lw, turns=1.035, wob=0.007, drift=0.01, vbase=0.98)
    hand_ring(br, rng, off(), 0.862, 0.0042 * lw, turns=1.02, wob=0.006, drift=-0.006, vbase=0.88)
    hand_ring(br, rng, off(), 0.742, 0.0068 * lw, turns=1.04, wob=0.007, drift=0.008, vbase=0.95)
    hand_ring(br, rng, off(), 0.722, 0.0030 * lw, turns=1.02, wob=0.006, drift=-0.005, vbase=0.78)
    # a ring broken into five arcs of different lengths
    gaps = []
    t0 = rng.uniform(0.08, 0.2)
    for _ in range(4):
        gaps.append((t0, t0 + rng.uniform(0.02, 0.05)))
        t0 += gaps[-1][1] - gaps[-1][0] + rng.uniform(0.12, 0.26)
        if t0 > 0.95:
            break
    gaps = [g for g in gaps if g[1] < 0.97]
    hand_ring(br, rng, off(), 0.646, 0.0055 * lw, turns=1.0, wob=0.006, drift=0.0, vbase=0.9, gap=gaps)
    hand_ring(br, rng, off(), 0.318, 0.0058 * lw, turns=1.045, wob=0.005, drift=0.006, vbase=0.95)
    hand_ring(br, rng, off(), 0.296, 0.0028 * lw, turns=1.02, wob=0.004, drift=-0.004, vbase=0.75)

    # --- tick marks round the rim: irregular spacing, lengths and weights, mostly between the two outer rings
    th = rng.uniform(0, 0.2)
    while th < 2 * math.pi - 0.05:
        step = rng.uniform(0.045, 0.085)
        big = rng.random() < 0.16
        r0, r1 = 0.884, 0.884 + (rng.uniform(0.020, 0.032) if big else rng.uniform(0.008, 0.019))
        rr0 = r0 + 0.012 * math.sin(th * 3 + 1.0)
        a = (cen[0] + rr0 * math.sin(th), cen[1] + rr0 * math.cos(th))
        b = (cen[0] + (r1 + 0.012 * math.sin(th * 3 + 1.0)) * math.sin(th), cen[1] + (r1 + 0.012 * math.sin(th * 3 + 1.0)) * math.cos(th))
        hand_line(br, rng, a, b, (0.0034 if big else 0.0022) * lw, bow=0.001, overshoot=(0, 0.002), v=0.9, dry=0.0)
        th += step

    # --- the band of glyph-like marks between the rings at 0.862 and 0.742
    th = rng.uniform(0, 0.1)
    kinds = [0, 1, 3, 5, 6, 7, 9, 10]  # no comb, zigzag, staircase or crescent: they read as letters
    last = -1
    while th < 2 * math.pi - 0.12:
        step = rng.uniform(0.07, 0.115)
        if rng.random() < 0.08:
            th += step * 0.9  # a gap in the writing
            continue
        kind = int(rng.choice([k for k in kinds if k != last]))
        last = kind
        rg = 0.802 + 0.006 * math.sin(th * 4 + 2) + rng.normal(0, 0.003)
        place_glyph(br, rng, kind, cen, rg, th, 0.032 * rng.uniform(0.85, 1.15), 0.0027 * lw)
        th += step

    # --- thin radial lines between the 0.742 and 0.646 rings in a few sectors (like the reference's rays)
    for _ in range(3):
        t0 = rng.uniform(0, 2 * math.pi)
        span = rng.uniform(0.35, 0.8)
        m = int(rng.integers(5, 10))
        for k in range(m):
            t = t0 + span * (k + rng.uniform(-0.25, 0.25)) / m
            ra, rb = 0.652, 0.652 + rng.uniform(0.045, 0.085)
            a = (cen[0] + ra * math.sin(t), cen[1] + ra * math.cos(t))
            b = (cen[0] + rb * math.sin(t), cen[1] + rb * math.cos(t))
            hand_line(br, rng, a, b, 0.0018 * lw, bow=0.001, overshoot=(0, 0.004), v=0.8, dry=0.3)

    # --- marks in the band between 0.646 and 0.32: a seven-point star drawn as seven strokes that cross and overshoot
    star_r = 0.585
    ang0 = rng.uniform(0, 2 * math.pi)
    verts = []
    for k in range(7):
        a = ang0 + 2 * math.pi * k / 7 + rng.normal(0, 0.035)
        r_ = star_r * (1 + rng.normal(0, 0.02))
        verts.append((cen[0] + r_ * math.sin(a), cen[1] + r_ * math.cos(a)))
    for k in range(7):
        hand_line(br, rng, verts[k], verts[(k + 3) % 7], 0.0048 * lw, bow=0.012, overshoot=(0.004, 0.034),
                  v=rng.uniform(0.82, 1.0), dry=0.4)
    # nodes at the star's points: small circles of varied size, some open
    for k in range(7):
        rr = rng.uniform(0.018, 0.034)
        hand_circle(br, rng, verts[k], rr, 0.0036 * lw, turns=rng.uniform(0.85, 1.1))
        if rng.random() < 0.7:
            dot(br, verts[k], 0.0042 * lw, 0.98)
    # an inner heptagon-ish polygon of five sides, rotated, at the middle of the star (a second figure)
    pr = 0.268
    pa = rng.uniform(0, 2 * math.pi)
    pv = []
    for k in range(5):
        a = pa + 2 * math.pi * k / 5 + rng.normal(0, 0.06)
        r_ = pr * (1 + rng.normal(0, 0.04))
        pv.append((cen[0] + r_ * math.sin(a), cen[1] + r_ * math.cos(a)))
    for k in range(5):
        hand_line(br, rng, pv[k], pv[(k + 1) % 5], 0.0045 * lw, bow=0.008, overshoot=(0.002, 0.02), v=rng.uniform(0.85, 1.0),
                  dry=0.3)
    # the centre: a small spiral and a dot, off the centre
    th_ = np.linspace(0, 3.2 * math.pi, 40)
    rr_ = 0.012 + 0.05 * th_ / (3.2 * math.pi)
    sp = np.stack([cen[0] + 0.01 + rr_ * np.sin(th_ + 1.0), cen[1] - 0.008 + rr_ * np.cos(th_ + 1.0)], axis=1)
    br.stroke(sp, np.linspace(0.0045, 0.0022, len(sp)) * lw, 0.95, dry=0.25)
    dot(br, (cen[0] + 0.012, cen[1] - 0.006), 0.009, 1.0)
    # short hairline marks that tie the rings together, a few, loose
    for _ in range(9):
        t = rng.uniform(0, 2 * math.pi)
        r0 = rng.choice([0.33, 0.45, 0.52])
        r1 = r0 + rng.uniform(0.03, 0.08)
        a = (cen[0] + r0 * math.sin(t), cen[1] + r0 * math.cos(t))
        b = (cen[0] + r1 * math.sin(t + rng.normal(0, 0.05)), cen[1] + r1 * math.cos(t + rng.normal(0, 0.05)))
        hand_line(br, rng, a, b, 0.0017 * lw, bow=0.002, overshoot=(0, 0.004), v=0.75, dry=0.3)

    y, x = D.grid(n)
    cov = br.cov
    r = np.hypot(x - cen[1], y - cen[0])
    # a glow: a soft wing round the strokes, and a faint mottled disc inside the innermost ring: LIGHT, so nothing dark here
    blur = box_blur(cov, int(6 * SS), 3)
    wide = box_blur(cov, int(20 * SS), 3)
    halo = np.clip(blur * 1.6, 0, 1) * 0.34 + np.clip(wide * 3.0, 0, 1) * 0.16
    disc = np.clip(0.5 + 0.5 * nz2(x, y, 7, 4, seed + 3), 0, 1) * np.exp(-(r / 0.3) ** 3) * 0.16
    # values: the stroke's own value, with the hot core: a stroke is white in the middle and greyer at the wings
    core = np.clip(box_blur(cov, int(1.5 * SS), 2) * 1.4, 0, 1)
    val = br.val ** 1.8 * (0.2 + 0.8 * core)  # thin strokes are greyer, thick ones white-hot
    a_line = np.clip(cov, 0, 1)
    a_all = np.maximum(a_line, np.maximum(halo, disc))
    v_all = np.where(a_line > 0.01, val * a_line + 0.55 * (1 - a_line), 0.55 + 0.2 * halo)
    img = D.rgba(v_all, a_all)
    img[..., 3] *= window(x, y)
    if SS != 1:
        img = D.resize(img, OUT, OUT)
    return D.bleed(img)


# ---------------------------------------------------------------------------------------------------------------------
# build and look
# ---------------------------------------------------------------------------------------------------------------------

NAMES = ["VfxCrackA", "VfxCrackB", "VfxScorch", "VfxSigil"]


def build(names=None):
    for name in names or NAMES:
        if name not in BUILDERS:
            continue
        sys.stdout.write(name + " ")
        sys.stdout.flush()
        img = BUILDERS[name]()
        path = D.write_png(os.path.join(TEXTURES, name + ".png"), img)
        print("[tex_floor]", path, img.shape)


def _floor(h, w, base, seed):
    """A made-up floor to judge a decal against: concrete with noise and a few joint lines."""
    y, x = D.grid(h, w)
    v = base + 0.07 * nz2(x, y, 5, 5, seed) + 0.035 * nz2(x, y, 40, 3, seed + 1)
    joint = np.minimum(np.abs(np.sin(x * math.pi * 1.5)), np.abs(np.sin(y * math.pi * 1.5)))
    v = v - 0.05 * (joint < 0.03)
    return np.clip(np.stack([v, v, v * 0.98], axis=-1), 0, 1)


def _laid(img, tint, back):
    rgb = img[..., :3] * np.array(tint)[None, None, :]
    a = img[..., 3:4]
    return back * (1 - a) + rgb * a


def _added(img, tint, back):
    rgb = img[..., :3] * np.array(tint)[None, None, :]
    return np.clip(back + rgb * img[..., 3:4], 0, 1)


def preview(name, outdir, cell=640):
    """<outdir>/<name>_look.png. Matter (cracks, scorch): the image laid over a light floor and a dark floor, each in a
    plain tint and a coloured one (2 x 2). Light (the sigil): added over the dark realm in an orange and a cool tint, and the
    same laid over a light floor so a mistake in value shows."""
    img = D.read_png(os.path.join(TEXTURES, name + ".png"))
    small = D.resize(img, cell, cell)
    light_b = _floor(cell, cell, 0.66, 31)
    dark_b = _floor(cell, cell, 0.13, 32)
    dark_realm = np.ones((cell, cell, 3)) * np.array([0.07, 0.07, 0.085])
    if name == "VfxSigil":
        tl = _added(small, (1.0, 0.62, 0.3), dark_b * 0.5 + dark_realm * 0.5)
        tr = _added(small, (0.55, 0.78, 1.0), dark_b * 0.5 + dark_realm * 0.5)
        bl = _added(small, (1.0, 1.0, 1.0), dark_realm)
        br_ = _laid(small, (0.5, 0.7, 1.0), light_b)
    else:
        tint2 = (0.85, 0.62, 0.45) if name == "VfxScorch" else (0.7, 0.8, 0.95)
        tl = _laid(small, (1, 1, 1), light_b)
        tr = _laid(small, tint2, light_b)
        bl = _laid(small, (1, 1, 1), dark_b)
        br_ = _laid(small, tint2, dark_b)
    m = np.concatenate([np.concatenate([tl, tr], axis=1), np.concatenate([bl, br_], axis=1)], axis=0)
    m = np.concatenate([m, np.ones(m.shape[:2] + (1,))], axis=-1)
    p = D.write_png(os.path.join(outdir, name + "_look.png"), m)
    print("[tex_floor preview]", p)
    return p


def main():
    argv = sys.argv[1:]
    out = None
    names = []
    k = 0
    while k < len(argv):
        if argv[k] == "--preview":
            out = argv[k + 1]
            k += 2
        else:
            names.append(argv[k])
            k += 1
    build(names or None)
    if out:
        for name in names or NAMES:
            if name in BUILDERS:
                preview(name, out)


if __name__ == "__main__":
    main()
