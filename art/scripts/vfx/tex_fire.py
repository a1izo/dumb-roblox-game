"""Ticket V1.2 of docs/handoff/vfx-rework-plan-2026-11-16.md: fire and flame sheets (light textures: added, black is
nothing; white and grey so the game tints them).

    VfxFire        8x8 loop      one cohesive fire: a body with a few tongues that grow out of it, nothing detaches (redone
                                 2026-11-26 as ModelsFx 6: the first one, free tongues shedding teardrops, read as white spikes)
    VfxFireBurst   8x8 one-shot  a hot ball that opens into tongues; its outer shell goes grey like smoke, then breaks
    VfxCandle      8x8 loop      the realm's pale candle flame: a teardrop with a dark heart at the wick, a bright body,
                                 a lick at the tip, a soft halo (Route E)
    VfxAuraFlame   4x4 loop      a drawn anime flame tongue with a curl, an inner lighter tongue and a flicking tip (Route E)

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/vfx/tex_fire.py [names]
        [--preview OUTDIR]      (numpy only; writes art/export/textures/<name>.png; with --preview the pictures that show
                                each sheet over dark and over light in two tints, plus a strip of frames)
    TEX_QUICK=1 draws at 1x (rough, fast: for looking at shapes, never for the final PNGs)

Every sheet is 1024 x 1024 (8x8 cells of 128 px, 4x4 cells of 256 px), the subject stays 4 px clear of every cell edge,
loops close (frame 64 would be frame 1) and the one-shot is a whole life. Own helpers; the shared modules are not edited.
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
SS = 1 if os.environ.get("TEX_QUICK") else 2
SAFE = 0.962  # for a 256 px cell; narrower cells use safe_of(cell)
TAU = 2 * math.pi


def texture(fn):
    BUILDERS[fn.__name__] = fn
    return fn


def sstep(a, b, x):
    return D.smoothstep(a, b, x)


def safe_of(cell):
    """4.5 px clear of the cell edge, in cell units (a 128 px cell: 0.93, a 256 px cell: 0.965)."""
    return 1.0 - 4.5 * 2.0 / cell


def window(x, y, cell):
    """1 inside the safe square, 0 from SAFE outward (cell px sets how soft the ramp is: one pixel)."""
    ramp = 2.0 / cell
    SAFE = safe_of(cell // SS)
    wx = np.clip((SAFE - np.abs(x)) / ramp, 0, 1)
    wy = np.clip((SAFE - np.abs(y)) / ramp, 0, 1)
    return wx * wy


def finish_cells(frames_fn, count, cell, grid):
    y, x = D.grid(cell * SS)
    cells = []
    for k in range(count):
        v, a = frames_fn(k, y, x)
        img = D.rgba(v, a * window(x, y, cell * SS))
        cells.append(D.resize(img, cell, cell) if SS > 1 else img)
        sys.stdout.write(".")
        sys.stdout.flush()
    sys.stdout.write("\n")
    return D.bleed(D.sheet(cells, grid))


def harm(t, terms):
    """A sum of sines with whole harmonics of the loop (t runs 0..1): closes exactly and never repeats inside it.
    terms = [(amplitude, harmonic, phase)]."""
    return sum(a * math.sin(TAU * (m * t) + p) for a, m, p in terms)


def pulse(t, centre, width):
    """A periodic bump (once per loop) at `centre` (0..1), about `width` wide: closes exactly."""
    d = (t - centre + 0.5) % 1.0 - 0.5
    return math.exp(-(d / width) ** 2)


def pnoise(a, b, c, f_a, f_b, py, pz, octaves, seed, shift_b=0.0):
    """Layered noise (about -1..1) over (a, b) and a time-ish c, periodic over b (period py lattice cells at the first
    octave, `shift_b` lattice cells of scroll: a whole multiple of py closes a loop) and over c (pz). Whole-number
    periods only."""
    n = N.fbm3(a * f_a + 3.1, b * f_b + shift_b + 7.7, np.full_like(a, c), octaves=octaves, seed=seed,
               period=(None, py, pz), time_scales=False)
    return np.clip(n * 1.6, -1.0, 1.0)


# ---------------------------------------------------------------------------------------------------------------------
# The flame engine (V1.2 redo, 2026-11-26). The first VfxFire (seven free standing tongues, each shedding a teardrop) and
# VfxCandle (a fat leaning wedge) read badly in the real lobby: a fan of separate white spikes, torn-off teardrops, a flame
# twice as tall as the old one. A flame is ONE body: a broad round foot, a few tongues that grow out of it and share it
# (they are blended by a smooth maximum, so the valleys between them stay high up the body), a soft taper to every tip,
# and nothing that ever lets go. Motion is waves that travel UP each tongue (so the tips lick and the base stays put), the
# tongues' heights breathing out of step, and an edge bitten by noise that scrolls up; all of it whole harmonics of the loop.
# The sheet carries three values the game tints: a dim rim, a body, and a small hot core LOW in the flame (the game draws a
# smaller copy of the same sheet on top at a high brightness, so the sheet's own core must stay small and its body must
# keep the ramp's colour).
# ---------------------------------------------------------------------------------------------------------------------


def _depth(x, y, t, yb, sp):
    """How deep inside one tongue (1 on its centre line, 0 at its edge, negative outside) each pixel lies at time t."""
    pu = sum(a * pulse(t, c, w) for a, c, w in sp.get("pu", ()))
    H = sp["H"] * (1 + harm(t, sp["hv"]) + pu)
    h = (yb - y) / H
    hc = np.clip(h, 0.0, 1.0)
    amp, cyc, mov, ph = sp["wave"]
    curl, ck, ph2 = sp["curl"]
    xc = (sp["bx"] + sp["lean"] * hc ** 1.4 + amp * hc ** 1.5 * np.sin(TAU * (cyc * hc - mov * t) + ph)
          + curl * hc ** 3 * math.sin(TAU * ck * t + ph2))
    p, q = sp["p"], sp["q"]
    peak = (p / (p + q)) ** p * (q / (p + q)) ** q
    w = sp["W"] * hc ** p * (1 - hc) ** q / peak
    s = 1 - np.abs(x - xc) / np.maximum(w, 1e-3)
    return np.where((h > 0) & (h < 1), s, -1.0)


def _smax(fields, k=12.0):
    """A smooth maximum: the union of the tongues, with no crease where two meet."""
    m = np.maximum.reduce(fields)
    return m + np.log(sum(np.exp(k * (f - m)) for f in fields)) / k


def _halo(x, y, cx, cy, rx, ry, peak):
    """The faint glow round a flame. Its alpha stays just over the texture check's 0.1 out to (rx, ry): that is what gives
    the box the check wants, and the soft light the flame throws on the air."""
    r = np.hypot((x - cx) / rx, (y - cy) / ry)
    return peak * np.exp(-(r ** 2.6) * 1.05)


# the fire: a body mass, a main tongue, two side tongues, two small ones. (bx, lean, H, W are cell units: x runs -1..1)
def _fire_tongues():
    def T(bx, lean, H, W, wave, curl, hv, pu=(), p=0.42, q=0.95):
        return dict(bx=bx, lean=lean, H=H, W=W, wave=wave, curl=curl, hv=hv, pu=pu, p=p, q=q)

    return [
        # body mass
        T(0.00, 0.00, 0.85, 0.39, (0.03, 1.0, 2, 0.4), (0.0, 1, 0.0), [(0.05, 3, 0.5), (0.03, 5, 2.0)], p=0.25),
        # main tongue: the tallest, leans and licks
        T(0.0, 0.02, 1.50, 0.33, (0.14, 1.25, 4, 1.9), (0.16, 3, 0.7), [(0.08, 3, 2.0), (0.07, 5, 4.0)],
          [(0.10, 0.30, 0.06)], p=0.6),
        # left and right tongues lean in toward it at the tips
        T(-0.24, 0.13, 1.18, 0.23, (0.10, 1.3, 5, 3.3), (0.11, 4, 2.1), [(0.10, 5, 0.9), (0.07, 3, 5.2)],
          [(0.14, 0.72, 0.07), (-0.12, 0.28, 0.06)], p=0.7),
        T(0.25, -0.14, 1.04, 0.22, (0.10, 1.15, 6, 5.1), (-0.12, 3, 4.4), [(0.10, 3, 3.1), (0.07, 7, 1.4)],
          [(0.14, 0.45, 0.07), (-0.10, 0.88, 0.05)], p=0.7),
    ]


@texture
def VfxFire(cell=128, grid=8, seed=311):
    """A cohesive fire (a brazier's, a cold fire, the Manual's red one): a broad body with a few tongues that grow out of
    it and breathe. No piece ever detaches. A hot core, small, low; a dim rim; the tips fade out."""
    n_frames = grid * grid
    yb = 0.83
    tongues = _fire_tongues()

    def frame(k, y, x):
        t = k / n_frames
        f = _smax([_depth(x, y, t, yb, sp) for sp in tongues])
        hg = np.clip((yb - y) / 1.45, 0.0, 1.0)
        # the edge is bitten by noise that scrolls up the flame (stronger toward the tips)
        n1 = pnoise(x, -y, 6 * t, 2.4, 1.7, 2, 6, 3, seed, shift_b=6 * t)
        n2 = pnoise(x, -y, 6 * t + 5, 4.6, 3.4, 3, 6, 2, seed + 9, shift_b=6 * t)
        f = f + (0.24 * n1 + 0.08 * n2) * (0.25 + 0.75 * hg)
        alpha = sstep(0.0, 0.26, f)
        alpha = alpha * (1 - 0.3 * sstep(0.55, 1.0, hg))          # the tips thin out
        # the foot is round (a bowl of flame, not a cut): the half width allowed falls to a point over the last 0.2
        u = np.clip((yb - y) / 0.2, 0.0, 1.0)
        lim = 0.12 + 0.6 * np.sqrt(1 - (1 - u) ** 2)
        alpha = alpha * sstep(lim + 0.03, lim - 0.03, np.abs(x))
        # three values: a dim rim, the body, a small hot core low in it
        d = np.clip(f, 0.0, 1.0)
        body = 0.34 + 0.52 * sstep(0.0, 0.8, d)
        sway = 0.03 * math.sin(TAU * t + 1.0)
        core = np.exp(-(((x - sway) / 0.15) ** 2 + ((y - (yb - 0.2)) / 0.23) ** 2))
        flick = 1 + 0.09 * harm(t, [(1.0, 7, 0.3), (0.7, 11, 1.1)])  # the fire's brightness shivers a few times a second
        val = (body * (1 - 0.2 * hg) + 0.30 * core) * flick
        halo_a = _halo(x, y, 0.0, 0.08, 0.83, 0.86, 0.32)
        a_tot = alpha + halo_a * (1 - alpha)
        val_tot = (val * alpha + 0.13 * halo_a * (1 - alpha)) / np.maximum(a_tot, 1e-6)
        return np.clip(val_tot, 0, 1), a_tot

    return finish_cells(frame, n_frames, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# VfxFireBurst: a hot ball, opening into flame tongues, the outer shell turning to grey smoke, the flame breaking into
# islands, the smoke thinning to specks. One life of 64 frames: born at 0, full by about frame 13, eroding from 32.
# ---------------------------------------------------------------------------------------------------------------------


def ease_out(u):
    u = np.clip(u, 0, 1)
    return 1 - (1 - u) ** 2.4


@texture
def VfxFireBurst(cell=128, grid=8, seed=523):
    n_frames = grid * grid

    def frame(k, y, x):
        tt = k / (n_frames - 1)
        r = np.hypot(x, y)
        th = np.arctan2(y, x)
        # an angle noise that is continuous round the circle: tongues
        ca, sa = np.cos(th), np.sin(th)
        life = float(k)
        # envelope of the fire: born a small hot ball, full by 13, shrinking once the flame dies
        grow = ease_out(life / 13.0)
        env = 0.20 + 0.50 * grow
        shrink = 1 - 0.55 * sstep(26, 56, life)
        # tongues reach out, more as it opens (frames 3 to 14)
        open_ = sstep(1.0, 14.0, life)
        tong = N.perlin3(ca * 2.3 + 5, sa * 2.3 + 5, np.full_like(r, life * 0.045), seed=seed)
        tong2 = N.perlin3(ca * 5.5 + 2, sa * 5.5 + 9, np.full_like(r, life * 0.07 + 3), seed=seed + 3)
        reach = env * shrink * (1 + open_ * (0.55 * tong + 0.3 * tong2 + 0.15))
        n_xy = N.fbm3(x * 3.2 + 2.0, y * 3.2 + 6.0, np.full_like(x, life * 0.14), octaves=4, seed=seed + 7)
        n_xy = np.clip(n_xy * 1.6, -1, 1)
        # fire: a disc to the tongue reach, bitten from outside in by noise, a rising threshold kills it by ~58
        thrF = 0.0 + 1.1 * sstep(20, 56, life) ** 1.1
        gf = (1 - r / np.maximum(reach, 1e-3)) * 0.9 - (0.12 + 0.32 * open_) * (0.5 - 0.5 * n_xy) - thrF * 0.8
        af = np.clip(gf / 0.07, 0, 1)
        # smoke: a shell that grows past the flame, puffy, grey, and eroded into islands late
        grow_s = ease_out((life - 3.0) / 28.0)
        Rs = 0.30 + 0.68 * grow_s
        lump = N.fbm3(ca * 1.4 + 9, sa * 1.4 + 1, np.full_like(r, life * 0.02), octaves=3, seed=seed + 11)
        puff = N.fbm3(x * 2.6 + 11.0, y * 2.6 + 3.0, np.full_like(x, life * 0.06 + 4), octaves=5, seed=seed + 13)
        puff = np.clip(puff * 1.7, -1, 1)
        Rl = Rs * (1 + 0.14 * np.clip(lump * 1.5, -1, 1))
        gs = (1 - r / np.maximum(Rl, 1e-3)) * 1.0 - 0.62 * (0.5 - 0.5 * puff) - 0.85 * sstep(30, 62, life) ** 1.0
        gs = gs - 0.18 * (1 - sstep(2, 9, life))
        as_ = np.clip(gs / 0.1, 0, 1) * 0.85
        # value: fire white-hot at the middle then darker; smoke grey with its own light and dark lumps
        cool = 1 - 0.5 * sstep(18, 44, life)
        vf = (0.4 + 0.6 * np.maximum(sstep(0.05, 0.55, gf), sstep(0.35, 0.9, 1 - r / np.maximum(reach, 1e-3)))) * cool
        vs = 0.26 + 0.2 * (0.5 + 0.5 * puff) + 0.14 * sstep(0.0, 0.6, gs)
        take_f = af >= as_ * 0.8
        alpha = np.maximum(af, as_) * (1 - sstep(0.80, 0.915, r))  # a soft round edge before the cell's own
        val = np.where(take_f, vf, vs)
        return np.clip(val, 0, 1), alpha

    return finish_cells(frame, n_frames, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# VfxCandle (redo): the old candle flame's slim shape (it stands about 1.35 of the cell's 2 high, half its width 0.27) with
# what the old one never had: a round foot with a dark heart at the wick, a pale body, a soft taper into a thin tip that
# leans and licks, a small hot core low in the body, and a gentle gust once a loop. One tongue, drawn with the same engine as
# the fire. A faint halo carries the box the texture check measures; it is dim enough not to show.
# ---------------------------------------------------------------------------------------------------------------------


@texture
def VfxCandle(cell=128, grid=8, seed=139):
    n_frames = grid * grid
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, TAU, 12)
    yb = 0.80  # the wick
    main = dict(bx=0.0, lean=0.0, H=1.34, W=0.32, p=0.55, q=1.0, wave=(0.0, 1.0, 1, 0.0), curl=(0.0, 1, 0.0), hv=[], pu=())

    def frame(k, y, x):
        t = k / n_frames
        lean = harm(t, [(0.15, 3, ph[0]), (0.115, 5, ph[1]), (0.08, 9, ph[2])])
        lean += 0.15 * pulse(t, 0.31, 0.06) - 0.17 * pulse(t, 0.72, 0.05)  # the gusts: once each way a loop
        lean = 0.26 * math.tanh(lean / 0.26)  # (a flame never lies down: the lean is soft-limited)
        lick = harm(t, [(0.15, 4, ph[4]), (0.11, 7, ph[5]), (0.08, 11, ph[6])]) + 0.12 * pulse(t, 0.58, 0.05)
        lick = 0.2 * math.tanh(lick / 0.2)
        sp = dict(main)
        sp["lean"] = lean
        sp["curl"] = (lick, 1, 0.0)
        sp["wave"] = (0.05, 1.2, 5, ph[10])
        sp["hv"] = [(0.045, 4, ph[7]), (0.03, 7, ph[8]), (0.025, 6, ph[9])]
        sp["pu"] = [(0.03, 0.31, 0.05), (-0.04, 0.72, 0.06)]
        sp["W"] = 0.32 * (1 + 0.12 * harm(t, [(1.0, 3, ph[11])]))
        f = _depth(x, y, t, yb, sp)
        hg = np.clip((yb - y) / 1.34, 0.0, 1.0)
        edge = pnoise(x, -y, 6 * t, 2.0, 1.5, 2, 6, 2, seed, shift_b=6 * t)
        f = f + 0.26 * edge * (0.2 + 0.8 * hg)
        alpha = sstep(0.0, 0.2, f) * (1 - 0.55 * sstep(0.5, 1.0, hg))   # a long soft taper into the tip
        alpha = alpha * sstep(0.0, 0.05, yb - y)
        d = np.clip(f, 0.0, 1.0)
        body = 0.56 + 0.38 * sstep(0.0, 0.9, d)
        # the bright body is low and slim; the tip is dimmer
        core = np.exp(-(((x - 0.3 * lean * 0.1) / 0.075) ** 2 + ((y - (yb - 0.34)) / 0.2) ** 2))
        flick = 1 + 0.15 * harm(t, [(1.0, 6, ph[3]), (0.7, 10, ph[11])])
        val = (body * (1 - 0.35 * sstep(0.35, 1.0, hg)) + 0.30 * core) * flick
        # the dark heart: a small teardrop hugging the wick, pointed up
        hh = np.clip((yb - y) / 0.36, 0.0, 1.0)
        heart_w = 0.075 * np.sin(np.clip(hh * math.pi, 0, math.pi)) ** 0.8 + 1e-4
        heart = np.clip((heart_w - np.abs(x - 0.25 * lean * hh)) / 0.03, 0, 1) * (hh > 0.02) * (hh < 0.98)
        val = val * (1 - 0.7 * heart)
        alpha = alpha * (1 - 0.3 * heart)
        halo_a = _halo(x, y, 0.0, 0.09, 0.80, 0.84, 0.28)
        a_tot = alpha + halo_a * (1 - alpha)
        val_tot = (val * alpha + 0.13 * halo_a * (1 - alpha)) / np.maximum(a_tot, 1e-6)
        return np.clip(val_tot, 0, 1), a_tot

    return finish_cells(frame, n_frames, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# VfxAuraFlame: a hand-drawn looking flame tongue for tall aura columns. The spine is built by turning a tangent
# (so it bends smoothly and can hook), the outer tongue is hard-edged mid grey, an inner tongue is lighter, a smaller
# tongue stands by it. The tip flicks twice a loop.
# ---------------------------------------------------------------------------------------------------------------------


def _spine(theta0, bend, curl, flick, length, x0, y0, n=200):
    """A curve from (x0, y0) going up: tangent angle from vertical = theta0 + bend sine + curl growth + flick at the end;
    returns arrays (xs, ys, s)."""
    s = np.linspace(0, 1, n)
    th = theta0 + bend * np.sin(TAU * 0.85 * s) + curl * sstep(0.45, 1.0, s) ** 1.4 * 1.0 + flick * sstep(0.82, 1.0, s) ** 2
    ds = length / (n - 1)
    xs = x0 + np.concatenate([[0], np.cumsum(np.sin(th[:-1]) * ds)])
    ys = y0 - np.concatenate([[0], np.cumsum(np.cos(th[:-1]) * ds)])
    return xs, ys, s


def _tongue(x, y, spine, wmax, p, q, px, s_from=0.0, s_to=1.0):
    """Coverage of a tongue along `spine` with a half-width profile s^p (1-s)^q scaled to wmax; hard edge, anti-aliased
    over one pixel (px, in cell units). Returns (alpha, depth) with depth 0 at the edge to 1 at the spine."""
    xs, ys, s = spine
    h, w = x.shape
    flatx, flaty = x.reshape(-1), y.reshape(-1)
    i = np.empty(len(flatx), dtype=np.int64)
    d = np.empty(len(flatx))
    for c0 in range(0, len(flatx), 16384):
        d2 = (flatx[c0:c0 + 16384, None] - xs[None, :]) ** 2 + (flaty[c0:c0 + 16384, None] - ys[None, :]) ** 2
        ii = np.argmin(d2, axis=1)
        i[c0:c0 + 16384] = ii
        d[c0:c0 + 16384] = np.sqrt(d2[np.arange(len(ii)), ii])
    s_at = s[i]
    s_rel = np.clip((s_at - s_from) / max(s_to - s_from, 1e-4), 0, 1)
    peak = (p / (p + q)) ** p * (q / (p + q)) ** q
    wid = wmax * (s_rel ** p) * ((1 - s_rel) ** q) / peak + 1e-4
    ok = (s_at >= s_from - 1e-6) & (s_at <= s_to + 1e-6)
    # the rounded foot: beyond the first sample the distance already includes the end cap
    a = np.clip((wid - d) / px + 0.5, 0, 1) * ok
    depth = np.clip(1 - d / wid, 0, 1) * ok
    return a.reshape(h, w), depth.reshape(h, w)


@texture
def VfxAuraFlame(cell=256, grid=4, seed=907):
    n_frames = grid * grid
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, TAU, 8)

    def frame(k, y, x):
        t = k / n_frames
        px = 2.0 / x.shape[0]
        # main tongue: leans, S-bends, hooks over to the right at the top, flicks its tip twice a loop
        theta0 = -0.06 + 0.05 * math.sin(TAU * t + ph[0])
        bend = 0.6 + 0.1 * math.sin(TAU * t + ph[1])
        curl = 2.5 + 0.3 * math.sin(TAU * t + ph[2])
        flick = 0.5 * math.sin(TAU * 2 * t + ph[3]) + 0.2 * math.sin(TAU * t + ph[4])
        spine = _spine(theta0, bend, curl, flick, 1.85, -0.3, 0.82)
        # a smaller tongue standing at its left, leaning away, a little out of step
        sp2 = _spine(0.35 + 0.08 * math.sin(TAU * t + ph[5]), 0.3, 1.0 + 0.2 * math.sin(TAU * t + ph[6]),
                     0.5 * math.sin(TAU * 2 * t + ph[7]), 1.0, 0.42, 0.82)
        a_main, d_main = _tongue(x, y, spine, 0.31, 0.5, 1.1, px)
        a_in, d_in = _tongue(x, y, spine, 0.14, 0.55, 1.0, px, 0.03, 0.8)
        a_side, d_side = _tongue(x, y, sp2, 0.17, 0.55, 0.85, px)
        a_side_in, _ = _tongue(x, y, sp2, 0.075, 0.6, 0.9, px, 0.05, 0.75)
        alpha = np.maximum(a_main, a_side)
        val = np.where(a_main > 0.5, 0.58, 0.0)
        val = np.where(a_in > 0.5, 1.0, val)
        val = np.where((a_side > 0.5) & (a_main <= 0.5), 0.5, val)
        val = np.where(a_side_in > 0.5, 0.92, val)
        val = np.where(alpha > 0, val, 0.0)
        # a thin darker line of the outer rim on the main tongue only (the cel's edge shading)
        rim = (d_main < 0.18) & (a_main > 0.5) & (a_in < 0.5)
        val = np.where(rim, 0.44, val)
        val = np.where(alpha > 0, np.maximum(val, 0.3), 0.0)
        return val, alpha

    return finish_cells(frame, n_frames, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# build and look
# ---------------------------------------------------------------------------------------------------------------------

NAMES = ["VfxFire", "VfxFireBurst", "VfxCandle", "VfxAuraFlame"]
GRIDS = {"VfxFire": 8, "VfxFireBurst": 8, "VfxCandle": 8, "VfxAuraFlame": 4}


def build(names=None):
    for name in names or NAMES:
        if name not in BUILDERS:
            continue
        sys.stdout.write(name + " ")
        img = BUILDERS[name]()
        path = D.write_png(os.path.join(TEXTURES, name + ".png"), img)
        print("[tex_fire]", path, img.shape)


def _panel(img, tint, back, laid):
    rgb = img[..., :3] * np.array(tint)[None, None, :]
    a = img[..., 3:4]
    base = np.ones_like(rgb) * np.array(back)[None, None, :]
    return base * (1 - a) + rgb * a if laid else np.clip(base + rgb * a, 0, 1)


def preview(name, outdir):
    """<outdir>/<name>_look.png: the whole sheet, over dark added as light in orange and cyan (top), and over light
    grey laid over in the same two tints (bottom): a 2 x 2 at half size."""
    img = D.read_png(os.path.join(TEXTURES, name + ".png"))
    orange, cyan = (1.0, 0.58, 0.24), (0.36, 0.78, 1.0)
    dark, light = (0.07, 0.07, 0.085), (0.82, 0.82, 0.8)
    tl, tr = _panel(img, orange, dark, False), _panel(img, cyan, dark, False)
    bl, br = _panel(img, orange, light, True), _panel(img, cyan, light, True)
    m = np.concatenate([np.concatenate([tl, tr], axis=1), np.concatenate([bl, br], axis=1)], axis=0)
    h, w, _ = m.shape
    m = D.resize(np.concatenate([m, np.ones((h, w, 1))], axis=-1), h // 2, w // 2)
    p = D.write_png(os.path.join(outdir, name + "_look.png"), m)
    print("[tex_fire preview]", p)
    return p


def strip(name, outdir, picks=None, tint=(1.0, 0.7, 0.35)):
    """Chosen frames at full cell size over dark (added) with a light-backdrop row (laid): to look at the detail."""
    g = GRIDS[name]
    img = D.read_png(os.path.join(TEXTURES, name + ".png"))
    ch = img.shape[0] // g
    picks = picks or ([0, 1, 3, 6, 9, 11, 13, 15] if g == 4 else [0, 4, 9, 14, 20, 28, 36, 44, 52, 58, 61, 63])
    cells = [img[(n // g) * ch:(n // g + 1) * ch, (n % g) * ch:(n % g + 1) * ch] for n in picks]
    per = 8 if len(cells) >= 8 and g == 4 else 6
    rows = []
    for i in range(0, len(cells), per):
        part = cells[i:i + per]
        row = np.concatenate(part, axis=1)
        rows.append(np.concatenate([_panel(row, tint, (0.07, 0.07, 0.085), False),
                                    _panel(row, tint, (0.82, 0.82, 0.8), True)], axis=0))
    wmax = max(r.shape[1] for r in rows)
    rows = [np.pad(r, ((0, 0), (0, wmax - r.shape[1]), (0, 0)), constant_values=0.5) for r in rows]
    m = np.concatenate(rows, axis=0)
    m = np.concatenate([m, np.ones(m.shape[:2] + (1,))], axis=-1)
    if ch < 200:  # enlarge small cells so frames can be judged by eye
        m = np.kron(m, np.ones((2, 2, 1)))
    p = D.write_png(os.path.join(outdir, name + "_strip.png"), m)
    print("[tex_fire strip]", p)
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
                strip(name, out)


if __name__ == "__main__":
    main()
