"""The VFX kit's textures. Each builder returns (name, image) with the image an (h, w, 4) float array, top row first,
straight alpha; most are white or grey so the game tints them (ParticleEmitter.Color, Beam.Color), a few carry their
own colour (the realm's pale candle flame). Written to art/export/textures/<name>.png by build(), carried into Studio
by the Fx props file (art/scripts/vfx/props.py).

    python art/scripts/vfx/textures.py [name ...]       (Blender's Python is enough: numpy only)

The looks, set against the owner's references (2026-10-24: Ink Game's emotes, Jujutsu Shenanigans' emote bursts):
crisp shapes with hot white cores and darker edges, never a soft blob; flames and smoke that move; every flipbook a
whole loop or a whole life.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from vfx import draw as D  # noqa: E402
from vfx import noise as N  # noqa: E402

TEXTURES = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "export",
                        "textures")

BUILDERS = {}


def texture(fn):
    BUILDERS[fn.__name__] = fn
    return fn


def _cell_grid(cell):
    return D.grid(cell)


# Fire ------------------------------------------------------------------------------------------------------------


def _flame_frame(cell, k, frames, seed, width=0.5, sway=1.0, rough=1.0, base_y=0.82, tip_y=-0.45):
    """One frame of a looping flame (frame k of `frames`), as fire shaders draw it: a round-based mask tapering up,
    with noise rising through it that carries more and more of the shape the higher it gets, so the top tears into
    tongues that break off and climb. Every noise rises a whole number of its own periods over the loop (the last frame
    runs into the first). Returns (heat 0..1, alpha) for the cell; heat is how deep inside the flame a pixel is."""
    y, x = _cell_grid(cell)
    phase = k / frames
    t = (base_y - y) / (base_y - tip_y)  # 0 at the base, 1 at the body's tip; tongues climb past it
    tt = np.clip(t, 0, 1.6)
    wander = N.fbm3(np.full_like(t, 0.37), t * 1.0 - phase * 4.0, phase * 2.0, octaves=3, period=(None, 4, 2),
                    seed=seed, time_scales=False)
    xs = x - sway * 0.22 * tt ** 1.6 * wander
    # a round base (a circle's quarter) tapering gently up: the noise makes the tip
    base_round = np.sqrt(np.clip(1 - (1 - np.clip(t / 0.28, 0, 1)) ** 2, 0, 1))
    w = width * base_round * (1 - np.clip(t, 0, 1) * 0.7)
    fx = np.clip(1 - (np.abs(xs) / np.maximum(w, 1e-3)) ** 1.6, 0, 1)
    wide = np.clip(1 - (np.abs(xs) / np.maximum(w * 1.7 + 0.04 * tt, 1e-3)) ** 2, 0, 1)
    n = N.fbm3(xs * 2.6, t * 2.4 - phase * 6.0, phase * 3.0, octaves=5, period=(None, 6, 3), seed=seed + 3,
               time_scales=False) * 0.5 + 0.5
    n2 = N.fbm3(xs * 6.0, t * 5.0 - phase * 15.0, phase * 5.0, octaves=3, period=(None, 15, 5), seed=seed + 7,
                time_scales=False) * 0.5 + 0.5
    # (the noise grows with the height: the base stays whole, the top is torn)
    amount = (0.12 + 1.1 * tt * tt / (0.35 + tt)) * rough * D.smoothstep(0.0, 0.5, wide)
    dens = fx * (1.25 - 1.0 * tt) + ((n - 0.5) + (n2 - 0.5) * 0.3) * amount
    dens = dens * D.smoothstep(0.0, 0.2, wide)
    dens = np.where(t < -0.02, 0, dens)
    heat = np.clip(dens * 1.6, 0, 1)
    alpha = D.smoothstep(0.03, 0.16, heat)
    alpha *= np.clip((1.0 - np.maximum(np.abs(x), np.abs(y))) / 0.06, 0, 1)
    return heat, alpha


@texture
def VfxFlame(cell=128, grid=8, seed=21):
    """A flame's loop (8 x 8 frames, about 2 s at 32 fps), grey: white at the core, grey toward its licking edge, so a
    tint colours the body and leaves the core hot. For fire of any colour (braziers, Godhood flames, auras)."""
    frames = []
    for k in range(grid * grid):
        heat, alpha = _flame_frame(cell, k, grid * grid, seed)
        value = 0.38 + 0.62 * D.smoothstep(0.2, 0.95, heat)
        frames.append(D.rgba(value, alpha))
    return D.bleed(D.sheet(frames, grid))


@texture
def VfxCandleFlame(cell=128, grid=8, seed=34):
    """The realm's candle flame in its own colours (no tint: Color white), built like a real one: a white heart a
    little above the wick, a half-clear pale envelope round it, a faint dark cone right over the wick, a blue foot,
    and a tip that thins to nothing; nothing warm lives in the Grey Realm. Calmer and narrower than VfxFlame."""
    frames = []
    blue = np.array([0.45, 0.60, 1.0])
    envelope = np.array([0.94, 0.91, 0.84])
    white = np.array([1.0, 1.0, 1.0])
    base_y, tip_y = 0.82, -0.55
    for k in range(grid * grid):
        heat, alpha = _flame_frame(cell, k, grid * grid, seed, width=0.34, sway=0.55, rough=0.6, base_y=base_y,
                                   tip_y=tip_y)
        y, x = _cell_grid(cell)
        t = (base_y - y) / (base_y - tip_y)
        core = D.smoothstep(0.38, 0.9, heat) * (1 - D.smoothstep(0.35, 0.75, t))
        foot = D.smoothstep(0.58, 0.8, y) * (1 - D.smoothstep(0.25, 0.7, heat))
        dark = np.exp(-((x / 0.07) ** 2 + ((y - 0.66) / 0.10) ** 2))
        colour = envelope[None, None, :] * (1 - core[..., None]) + white[None, None, :] * core[..., None]
        colour = colour * (1 - foot[..., None] * 0.8) + blue[None, None, :] * (foot[..., None] * 0.8)
        colour = colour * (1 - 0.35 * dark[..., None])
        a = D.smoothstep(0.02, 0.45, heat) * (0.5 + 0.5 * core)
        a = a * (1 - 0.65 * D.smoothstep(0.55, 1.25, t)) * (1 - 0.4 * foot) * (1 - 0.3 * dark)
        a = np.minimum(a, alpha)
        frames.append(np.concatenate([colour, a[..., None]], axis=-1).astype(np.float32))
    return D.bleed(D.sheet(frames, grid))


# Light -----------------------------------------------------------------------------------------------------------


@texture
def VfxGlow(size=256):
    """A light's glow: a small bright core in a long soft wing, to nothing well inside the square."""
    y, x = D.grid(size)
    r = np.sqrt(x * x + y * y)
    a = D.glow(r, core=0.10, falloff=0.32) * np.clip((1 - r) / 0.25, 0, 1)
    return D.rgba(1.0, a / a.max())


@texture
def VfxFlare(size=512):
    """A star flare: a white core, four long thin rays, four shorter ones between them, a faint ring."""
    y, x = D.grid(size)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    a = D.glow(r, core=0.06, falloff=0.16)
    for k in range(8):
        th = k * math.pi / 4
        long = k % 2 == 0
        along = np.abs(x * math.cos(th) + y * math.sin(th))
        across = np.abs(-x * math.sin(th) + y * math.cos(th))
        reach = 0.95 if long else 0.5
        width = 0.012 if long else 0.008
        ray = np.exp(-(across / (width * (1 + 3 * along))) ** 2) * np.clip(1 - along / reach, 0, 1) ** 1.6
        a = np.maximum(a, ray * (1.0 if long else 0.6))
    ring = np.exp(-((r - 0.42) / 0.012) ** 2) * 0.12
    a = np.clip(a + ring, 0, 1) * np.clip((1 - r) / 0.05, 0, 1)
    del ang
    return D.rgba(1.0, a)


@texture
def VfxEmber(size=128):
    """A hot speck: a hard bright dot in a small glow (embers, sparks seen head-on, motes)."""
    y, x = D.grid(size)
    r = np.sqrt(x * x + y * y)
    a = np.clip(D.aa(r - 0.16, D.px(size)) + D.glow(r, 0.2, 0.3) * 0.6, 0, 1) * np.clip((1 - r) / 0.15, 0, 1)
    v = 0.75 + 0.25 * D.aa(r - 0.2, D.px(size))
    return D.bleed(D.rgba(v, a))


@texture
def VfxStreak(h=512, w=64):
    """A spark's streak, head up (VelocityParallel: it stretches along its flight): a white-hot line, thick at the
    head, thinning to its tail, in a narrow glow."""
    y, x = D.grid(h, w)
    # y runs about -8..8 here (the grid's span is across the width): bring it to 0 (head) .. 1 (tail)
    t = (y - y.min()) / (y.max() - y.min())
    width = 0.10 + 0.32 * (1 - t) ** 2
    core = np.exp(-(x / (width * 0.5)) ** 2) * (1 - t) ** 0.6
    halo = np.exp(-(x / (width * 1.6)) ** 2) * (1 - t) ** 1.2 * 0.35
    a = np.clip(core + halo, 0, 1) * np.clip(t / 0.04, 0, 1) * np.clip((1 - np.abs(x)) / 0.2, 0, 1)
    v = 0.7 + 0.3 * np.clip(core * 1.5, 0, 1)
    return D.bleed(D.rgba(v, a))


@texture
def VfxSpike(h=512, w=128):
    """One anime spike, point up (VelocityParallel, flung outward from a hit): a long crisp blade, white along its
    middle, grey toward its edges, its base rounded."""
    y, x = D.grid(h, w)
    t = (y - y.min()) / (y.max() - y.min())  # 0 at the point, 1 at the base
    half = 0.85 * np.clip(t, 0, 1) ** 0.75 * np.clip((1.0 - t) / 0.12, 0, 1) ** 0.5
    d = np.abs(x) - half
    pixel = D.px(w) * 1.2
    a = D.aa(d, pixel) * np.clip(t / 0.01, 0, 1)
    inner = np.clip(1 - np.abs(x) / np.maximum(half, 1e-3), 0, 1)
    v = 0.62 + 0.38 * D.smoothstep(0.35, 0.9, inner)
    return D.bleed(D.rgba(v, a))


@texture
def VfxBurst(size=1024, seed=4):
    """An anime impact burst (Jujutsu Shenanigans' emote bursts): thick crisp spikes of every length round a hot
    middle, white along each spike's spine, grey at its edges, a second ring of short spikes between them."""
    rng = np.random.default_rng(seed)
    y, x = D.grid(size)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    pixel = D.px(size) * 1.2
    alpha = np.zeros_like(r)
    value = np.zeros_like(r)
    count = 16
    for ring, (n, reach0, reach1, width) in enumerate(((count, 0.62, 0.98, 0.20), (count, 0.38, 0.6, 0.16))):
        offset = (0.5 / n * 2 * math.pi) if ring == 1 else 0.0
        for k in range(n):
            th = offset + k * 2 * math.pi / n + rng.uniform(-0.12, 0.12)
            reach = rng.uniform(reach0, reach1)
            wdt = width * rng.uniform(0.75, 1.2)
            # distance along the spike's axis and across it, its half-width tapering from wdt to 0 at `reach`
            along = x * math.cos(th) + y * math.sin(th)
            across = -x * math.sin(th) + y * math.cos(th)
            u = np.clip(along / reach, 0, 1)
            half = wdt * 0.5 * (1 - u) ** 1.1 * D.smoothstep(0.0, 0.25, along / reach + 0.25)
            inside = (along > 0) & (along < reach)
            d = np.where(inside, np.abs(across) - half, 1.0)
            cover = D.aa(d, pixel)
            spine = np.clip(1 - np.abs(across) / np.maximum(half, 1e-4), 0, 1)
            alpha = np.maximum(alpha, cover)
            value = np.maximum(value, cover * (0.6 + 0.4 * D.smoothstep(0.3, 0.85, spine)))
    hub = D.aa(r - 0.2, pixel)
    alpha = np.maximum(alpha, hub)
    value = np.maximum(value, hub)
    value = np.where(alpha > 0, value / np.maximum(alpha, 1e-4), 1.0)
    return D.bleed(D.rgba(value, alpha))


@texture
def VfxRing(size=512, seed=6):
    """A shock ring seen flat: a crisp bright band, a soft glow inside it, broken here and there by noise."""
    y, x = D.grid(size)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    pixel = D.px(size)
    breakup = N.fbm2(np.cos(ang) * 3 + 10, np.sin(ang) * 3 + 10, octaves=4, seed=seed)
    width = 0.045 * (1 + 0.5 * breakup)
    band = D.aa(np.abs(r - 0.86) - width, pixel)
    inner = np.exp(-((r - 0.80) / 0.09) ** 2) * 0.45 * (r < 0.86)
    a = np.clip(band + inner, 0, 1) * np.clip((0.995 - r) / 0.01, 0, 1)
    v = 0.7 + 0.3 * band
    return D.bleed(D.rgba(v, a))


# Textures laid along a beam or a shape (the kit's one rule, found in the lab of 2026-10-24: a Beam lays an image's
# rows along its length, its first row at Attachment0, and its columns across its width; the meshes' UVs follow the
# same: v along the shape, u across it).


@texture
def VfxRingBand(w=128, h=1024, seed=7):
    """A shockwave's band (across: u 0 its leading edge, a hard bright front, then a trail fading behind; along: v,
    streaked, tiling), for the flat beam rings and the ring and dome meshes."""
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx + 0.5) / w
    v = (yy + 0.5) / h
    streak = N.fbm2(u * 3.0, v * 24, octaves=4, period=(None, 24), seed=seed) * 0.5 + 0.5
    front = np.exp(-((u - 0.06) / 0.05) ** 2)
    trail = np.clip(1 - u, 0, 1) ** 2.0 * (0.35 + 0.65 * streak)
    a = np.clip(np.maximum(front, trail * 0.9), 0, 1) * np.clip(u / 0.02, 0, 1) * np.clip((1 - u) / 0.08, 0, 1)
    val = 0.62 + 0.38 * front
    return D.bleed(D.rgba(val, a))


@texture
def VfxColumn(w=256, h=512, seed=11):
    """A column of light for a beam: across, a white core in a wide soft glow; along, faint streaks running its
    length (tiling: scrolled, they race up it)."""
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx + 0.5) / w * 2 - 1
    v = (yy + 0.5) / h
    streak = N.fbm2(u * 9.0, v * 3.0, octaves=4, period=(None, 3), seed=seed) * 0.5 + 0.5
    core = np.exp(-(u / 0.12) ** 2)
    glow = np.exp(-(u / 0.45) ** 2) * (0.35 + 0.65 * streak)
    a = np.clip(core + glow * 0.7, 0, 1) * np.clip((1 - np.abs(u)) / 0.1, 0, 1)
    val = 0.7 + 0.3 * core
    return D.bleed(D.rgba(val, a))


@texture
def VfxSlashBand(w=128, h=1024, seed=13):
    """A slash's band (the crescent mesh and flat slash beams): across, u 0 its cutting edge (white, hard) fading
    behind; along, v 0 its tail (frayed into streaks, faint) to 1 its head (whole and bright)."""
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx + 0.5) / w
    v = (yy + 0.5) / h
    streak = N.fbm2(u * 4.0, v * 18.0, octaves=4, seed=seed) * 0.5 + 0.5
    edge = np.exp(-((u - 0.05) / 0.045) ** 2)
    body = np.clip(1 - u, 0, 1) ** 1.6
    fray = D.smoothstep(0.0, 0.55, v)
    whole = np.where(streak > 1.0 - fray * 0.9 - 0.1, 1.0, 0.25)
    a = np.clip(np.maximum(edge, body * 0.85 * whole), 0, 1) * D.smoothstep(0.0, 0.25, v) * np.clip(u / 0.02, 0, 1)
    a *= np.clip((1 - v) / 0.02, 0, 1)
    val = 0.6 + 0.4 * edge
    return D.bleed(D.rgba(val, a))


@texture
def VfxSlash(w=512, h=256, seed=9):
    """A sword's crescent: a thick arc, hot along its inner edge, frayed into streaks toward its tail (for flat
    billboards and the crescent mesh's u-along/v-across mapping)."""
    y, x = D.grid(h, w)
    # the arc: points at angle a on a circle of radius R round (0, cy)
    cy, R = 0.25, 0.95
    dy, dx = y - cy, x
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dx, -dy)  # 0 straight up from the centre, negative left
    span = 1.25
    s = np.clip((ang + span) / (2 * span), 0, 1)  # 0 at the tail (left), 1 at the head (right)
    thick = 0.16 * np.sin(np.clip(s, 0, 1) * math.pi) ** 0.7 * (0.35 + 0.65 * s)
    off = R - r  # positive inside the circle
    streak = N.fbm2(s * 18, off * 30, octaves=4, seed=seed)
    inside = (np.abs(ang) < span) & (off > -0.02) & (off < thick + 0.04)
    edge = np.exp(-(np.clip(off, 0, None) / 0.03) ** 2) * (off > -0.015)
    body = np.clip(1 - off / np.maximum(thick, 1e-3), 0, 1) ** 0.8 * (0.55 + 0.45 * streak)
    fray = D.smoothstep(0.0, 0.35, s)
    a = np.clip(np.maximum(edge * fray, body * fray), 0, 1) * inside
    v = 0.6 + 0.4 * edge
    a *= D.aa(-off - 0.0, D.px(w) * 2) * 0 + 1
    return D.bleed(D.rgba(v, a))


@texture
def VfxCrack(size=1024, seed=19):
    """Cracks split through the floor from a point: jagged lines branching as they run out, wide and dark near the
    middle and hair-thin at their ends, each with a pale broken lip on one side, and a shallow dark bruise round the
    middle. Grey on clear (a decal: its colour multiplies the floor's)."""
    rng = np.random.default_rng(seed)
    y, x = D.grid(size)
    pixel = D.px(size)
    dark = np.full(x.shape, 9.0)
    lip = np.full(x.shape, 9.0)
    width_at = np.zeros(x.shape)

    def run(ox, oy, angle, length, width, depth):
        points = [(ox, oy)]
        a = angle
        steps = int(length / 0.045)
        for k in range(steps):
            # straight runs with now and then a sharp kink, as stone splits
            a += rng.normal(0, 0.07) + (rng.choice([-1, 1]) * rng.uniform(0.35, 0.7) if rng.random() < 0.18 else 0)
            ox, oy = ox + math.cos(a) * 0.045, oy + math.sin(a) * 0.045
            points.append((ox, oy))
            if depth < 2 and rng.random() < 0.09:
                run(ox, oy, a + rng.choice([-1, 1]) * rng.uniform(0.6, 1.2), length * rng.uniform(0.2, 0.4),
                    width * 0.55, depth + 1)
        for k in range(len(points) - 1):
            (ax, ay), (bx, by) = points[k], points[k + 1]
            d, t = D.segment(y, x, ay, ax, by, bx)
            w = width * (1 - (k + t) / len(points)) ** 0.8 + pixel * 0.5
            nonlocal_update(d, w)

    def nonlocal_update(d, w):
        np.minimum(dark, d - w, out=dark)
        np.minimum(lip, d - w * 1.7, out=lip)

    for k in range(11):
        a = 2 * math.pi * k / 11 + rng.uniform(-0.2, 0.2)
        run(math.cos(a) * 0.05, math.sin(a) * 0.05, a, rng.uniform(0.4, 0.92), rng.uniform(0.007, 0.014), 0)
    r = np.sqrt(x * x + y * y)
    crack = D.aa(dark, pixel)
    rim = D.aa(lip, pixel) * (1 - crack) * 0.35
    bruise = np.exp(-(r / 0.28) ** 2) * 0.45
    alpha = np.clip(np.maximum(crack, np.maximum(rim, bruise)), 0, 1) * np.clip((1 - r) / 0.08, 0, 1)
    value = np.where(crack > 0.5, 0.05, np.where(rim > 0.05, 0.62, 0.18))
    del width_at
    return D.bleed(D.rgba(value, alpha))


@texture
def VfxCircle(size=1024, seed=23):
    """A sigil for the floor under a god's moment: a clock's face of sixty ticks (every fifth long, the forty seconds of
    the Death Note's rule marked heavier), rings within rings, thin lines radiating, a band of written marks between
    two rings, and at its heart a square on its point with a stopwatch's hand stopped at forty seconds. White on clear
    (tinted, laid flat, turned)."""
    rng = np.random.default_rng(seed)
    y, x = D.grid(size)
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    pixel = D.px(size)
    line = lambda d, w: D.aa(np.abs(d) - w, pixel)  # noqa: E731
    a = np.zeros_like(r)
    for rr, w in ((0.97, 0.008), (0.93, 0.003), (0.80, 0.006), (0.66, 0.003), (0.62, 0.006), (0.30, 0.004)):
        a = np.maximum(a, line(r - rr, w))
    # the clock's ticks between 0.80 and 0.93
    for k in range(60):
        th = k * 2 * math.pi / 60
        long = k % 5 == 0
        heavy = k == 40
        r0 = 0.83 if long else 0.88
        d, t = D.segment(y, x, math.sin(th) * r0, math.cos(th) * r0, math.sin(th) * 0.93, math.cos(th) * 0.93)
        a = np.maximum(a, D.aa(d - (0.006 if heavy else 0.0035 if long else 0.002), pixel))
    # radiating lines from the inner ring out to 0.62
    for k in range(24):
        th = k * 2 * math.pi / 24 + 0.06
        d, t = D.segment(y, x, math.sin(th) * 0.3, math.cos(th) * 0.3, math.sin(th) * 0.62, math.cos(th) * 0.62)
        a = np.maximum(a, D.aa(d - 0.0018, pixel) * 0.7)
    # written marks in the band between 0.66 and 0.80: short strokes in clusters, like a line of script round it
    for k in range(120):
        th = k * 2 * math.pi / 120 + rng.uniform(-0.01, 0.01)
        if rng.random() < 0.2:
            continue
        rr = 0.73 + rng.uniform(-0.025, 0.025)
        cx, cy = math.cos(th) * rr, math.sin(th) * rr
        for _ in range(2):
            l = rng.uniform(0.012, 0.03)
            phi = th + math.pi / 2 + rng.uniform(-1.2, 1.2)
            d, t = D.segment(y, x, cy - math.sin(phi) * l, cx - math.cos(phi) * l, cy + math.sin(phi) * l,
                             cx + math.cos(phi) * l)
            a = np.maximum(a, D.aa(d - 0.0028, pixel))
    # at its heart a square turned on its point, and a stopwatch's hand stopped at the fortieth second
    square = [(0.0, 0.29), (0.29, 0.0), (0.0, -0.29), (-0.29, 0.0)]
    for k in range(4):
        (ay, ax), (by, bx) = square[k], square[(k + 1) % 4]
        d, t = D.segment(y, x, ay, ax, by, bx)
        a = np.maximum(a, D.aa(d - 0.003, pixel))
    th = -math.pi / 2 + 40 * 2 * math.pi / 60  # (twelve at the top, clockwise: forty seconds past)
    d, t = D.segment(y, x, -math.sin(th) * -0.06, -math.cos(th) * -0.06, math.sin(th) * 0.26, math.cos(th) * 0.26)
    hand = D.aa(d - (0.006 * (1 - t) + 0.002), pixel)
    hub = D.aa(r - 0.022, pixel)
    a = np.maximum(a, np.maximum(hand, hub))
    glow = np.exp(-((r - 0.8) / 0.12) ** 2) * 0.12 + np.exp(-(r / 0.35) ** 2) * 0.1
    alpha = np.clip(np.maximum(a, glow), 0, 1) * np.clip((1 - r) / 0.02, 0, 1)
    return D.bleed(D.rgba(0.82 + 0.18 * a, alpha))


@texture
def VfxPage(w=256, h=356, seed=29):
    """A page torn from a notebook, in its own colours (Color white): old paper, faint ruled lines, a margin, a few lines
    of small dark handwriting, its top edge torn, its edges a little darker."""
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx + 0.5) / w
    v = (yy + 0.5) / h
    grain = N.fbm2(u * 12, v * 16, octaves=4, seed=seed) * 0.5 + 0.5
    paper = np.stack([0.90 + 0.04 * grain, 0.88 + 0.04 * grain, 0.80 + 0.04 * grain], axis=-1)
    edge = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v))
    paper *= (0.82 + 0.18 * D.smoothstep(0.0, 0.08, edge))[..., None]
    img = np.ones((h, w, 4), dtype=np.float32)
    img[..., :3] = paper
    # ruled lines and the margin
    for k in range(13):
        ly = 0.12 + k * 0.066
        img[..., :3] = np.where((np.abs(v - ly) < 0.0028)[..., None], img[..., :3] * np.array([0.78, 0.82, 0.9]), img[..., :3])
    img[..., :3] = np.where((np.abs(u - 0.14) < 0.004)[..., None], img[..., :3] * np.array([0.9, 0.7, 0.7]), img[..., :3])
    # handwriting: looped cursive along the first lines (the pen circles as it moves on: loops where the circle is
    # wider than its step), words apart, a slant
    pen = np.zeros((h, w))
    for k in range(6):
        ly = 0.12 + (k + 1) * 0.066 - 0.016
        x = 0.18
        end = rng.uniform(0.6, 0.92)
        while x < end:
            word = rng.uniform(0.08, 0.2)
            steps = int(word / 0.0025)
            f = rng.uniform(90, 120)
            pts = []
            for i in range(steps + 1):
                t = i / steps
                px0 = x + t * word + 0.0045 * math.sin(2 * math.pi * f * t * word)
                py0 = ly - 0.012 * (0.5 + 0.5 * math.cos(2 * math.pi * f * t * word)) * (0.7 + 0.3 * math.sin(7 * t))
                pts.append((px0 - (py0 - ly) * 0.35, py0))
            for i in range(steps):
                (ax, ay), (bx, by) = pts[i], pts[i + 1]
                d, _ = D.segment(v, u, ay, ax, by, bx)
                pen = np.maximum(pen, np.clip(1 - d / 0.0032, 0, 1))
            x += word + rng.uniform(0.025, 0.045)
    img[..., :3] = img[..., :3] * (1 - 0.85 * pen[..., None])
    # the torn top: a ragged edge
    tear = 0.03 + 0.02 * (N.fbm2(u * 9, np.zeros_like(u) + 3, octaves=4, seed=seed + 3) * 0.5 + 0.5)
    img[..., 3] = D.smoothstep(0.0, 0.006, v - tear)
    return D.bleed(img)


# Smoke and dust -------------------------------------------------------------------------------------------------


@texture
def VfxWisp(cell=128, grid=4, seed=12):
    """A thread of smoke curling up from a wick that has just gone out (4 x 4, one whole life): thin and pale, it
    rises, sways, widens and thins away."""
    frames = []
    n = grid * grid
    y, x = D.grid(cell)
    for k in range(n):
        life = k / (n - 1)
        top = 0.9 - 1.9 * min(1.0, life * 1.3)  # how far up it has risen (y of its head)
        t = np.clip((0.9 - y) / 1.8, 0, 1)  # 0 at the wick, 1 at the top of the cell
        wx, wy = N.warp2(x * 1.3, y * 1.6 - life * 1.5, strength=0.55, octaves=3, seed=seed)
        curl = 0.28 * t ** 1.3 * N.fbm2(wy * 1.2, life * 2.0 + 3.0, octaves=3, seed=seed + 3)
        width = 0.025 + 0.11 * t ** 1.4 + 0.05 * life
        d = np.abs(x - curl - 0.08 * np.sin(wy * 3 + life * 4) * t) / width
        density = np.clip(1 - d, 0, 1) ** 1.5
        density *= (y > top) * D.smoothstep(top, top + 0.25, y)
        density *= 1 - D.smoothstep(0.6, 1.0, life)
        density *= 0.55 + 0.45 * N.fbm2(wx * 3, wy * 3, octaves=3, seed=seed + 7)
        frames.append(D.rgba(0.85, np.clip(density * 1.6, 0, 1)))
    return D.bleed(D.sheet(frames, grid))


@texture
def VfxDust(cell=128, grid=4, seed=15):
    """An anime dust puff (4 x 4, one whole life): a lumpy cloud lit from above, three hard tones with a darker
    rim, that billows out and is eaten away from inside in hard steps (the owner's tutorial: noise cut into steps)."""
    frames = []
    n = grid * grid
    rng = np.random.default_rng(seed)
    lumps = [(rng.uniform(-0.35, 0.35), rng.uniform(-0.25, 0.3), rng.uniform(0.25, 0.42)) for _ in range(7)]
    y, x = D.grid(cell)
    erosion = N.fbm2(x * 3.0 + 4, y * 3.0 + 4, octaves=4, seed=seed + 1)
    for k in range(n):
        life = k / (n - 1)
        grow = 0.55 + 0.45 * (1 - (1 - life) ** 3)
        rise = -0.12 * life
        h = np.zeros_like(x)
        for (lx, ly, lr) in lumps:
            rr = lr * grow
            dx, dy = x - lx * grow, y - (ly * grow + rise)
            q = 1 - (dx * dx + dy * dy) / (rr * rr)
            h = np.maximum(h, np.sqrt(np.clip(q, 0, None)) * rr)
        inside = h > 0
        # light from above-left: the height field's slope
        gy, gx = np.gradient(h)
        light = np.clip(0.55 - (gy * 0.7 + gx * 0.4) * cell * 0.9, 0, 1)
        tone = np.where(light > 0.62, 1.0, np.where(light > 0.38, 0.78, 0.58))
        rim = inside & (h < 0.02 * grow)
        tone = np.where(rim, 0.5, tone)
        cut = -0.6 + 1.5 * life ** 1.5
        eaten = erosion + (0.35 - h * 2.5) * life * 2 < cut
        alive = inside & ~eaten
        edge_rim = alive & ~np.roll(alive, 1, 0) | alive & ~np.roll(alive, -1, 0)
        tone = np.where(edge_rim & (life > 0.15), 0.52, tone)
        a = D.smoothstep(0.0, 0.004, h) * alive
        frames.append(D.rgba(tone, a))
    return D.bleed(D.sheet(frames, grid))


def build(names=None):
    out = []
    for name, fn in BUILDERS.items():
        if names and name not in names:
            continue
        img = fn()
        path = D.write_png(os.path.join(TEXTURES, name + ".png"), img)
        out.append(path)
        print("[vfx textures]", name, img.shape[1], "x", img.shape[0], path)
    return out


if __name__ == "__main__":
    build(sys.argv[1:] or None)
