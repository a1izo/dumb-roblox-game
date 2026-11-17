"""Ticket V1.3 of docs/handoff/vfx-rework-plan-2026-11-16.md: the impact family of light textures (added, black is
nothing; white and grey so the game tints them). Route E, eroded: a shape field, plus layered noise, cut by a threshold
that rises frame by frame so the shape is eaten from its thin parts first.

    VfxImpactA   4x4 one-shot   sharp: thin long rays, a hard white core
    VfxImpactB   4x4 one-shot   heavy: thick short wedges, a big dense core, cracks inside
    VfxImpactC   4x4 one-shot   soft: round lobes that bloom out of a core
    VfxShock     4x4 one-shot   a shock ring whose band thins and breaks into arcs
    VfxGlint     4x4 one-shot   a star that opens, turns and closes (arms break into beads)
    VfxSparks    2x2 random     four spark streaks, head up (for VelocityParallel): straight, bent, forked, short

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/vfx/tex_impact.py [names]
        [--preview OUTDIR]       (numpy only; writes art/export/textures/<name>.png, and with --preview the
                                            pictures that show each sheet over dark and over light, in two tints)

Every sheet: 1024 x 1024; a frame is a 256 px cell (512 px for the 2x2); the subject stays 4 px or more off every edge of
its cell; each one-shot is a whole life (born in the first frame, full by frame 4, eroding from the middle, islands at
the end). Drawn at twice the size and boxed down, so thin tips are anti-aliased. The helpers are this file's own copies
(textures.py, draw.py and noise.py are not edited by this ticket).
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
SS = 2  # supersampling: frames are drawn at SS x the cell and boxed down
SAFE = 0.962  # nothing is drawn past this (the cell runs -1..1; 4 px is 0.031)


def texture(fn):
    BUILDERS[fn.__name__] = fn
    return fn


# ---------------------------------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------------------------------


def sstep(a, b, x):
    return D.smoothstep(a, b, x)


def window(x, y):
    """1 inside the safe square, 0 from SAFE outward: no frame ever touches its neighbour."""
    wx = np.clip((SAFE - np.abs(x)) / 0.012, 0, 1)
    wy = np.clip((SAFE - np.abs(y)) / 0.012, 0, 1)
    return wx * wy


def noise_signed(x, y, z, freq, octaves, seed):
    """Layered noise, about -1..1, drifting slowly with z (so the broken edge boils from frame to frame)."""
    n = N.fbm3(x * freq + 11.3, y * freq + 4.7, np.full_like(x, z), octaves=octaves, seed=seed)
    return np.clip(n * 1.7, -1.0, 1.0)


def polar(x, y):
    return np.hypot(x, y), np.arctan2(y, x)


def ray_field(x, y, rays):
    """The union of rays, each (angle, reach, half-width at the root, taper power, bend, cap). A ray's field is 1 on its
    spine and falls to 0 at its edge, and it is weaker toward its tip, so a rising threshold eats tips and edges first."""
    f = np.zeros_like(x)
    for th, reach, w0, p, bend, cap in rays:
        c, s = math.cos(th), math.sin(th)
        along = x * c + y * s
        across = -x * s + y * c - bend * along * along
        t = along / reach
        tc = np.clip(1 - t, 0, 1)
        half = w0 * tc ** p
        spine = np.clip(1 - np.abs(across) / np.maximum(half, 1e-4), 0, 1)
        body = 0.5 + 0.5 * tc ** 0.5
        fr = np.where((t > 0) & (t < 1), spine * body, 0.0)
        f = np.maximum(f, np.minimum(fr, cap))
    return f


def finish_cells(frames_fn, count, cell, grid):
    """Draws `count` frames with frames_fn(k, y, x) -> (value, alpha) at SS x the cell, boxes them to `cell` and lays
    them out left to right, top to bottom."""
    y, x = D.grid(cell * SS)
    cells = []
    for k in range(count):
        v, a = frames_fn(k, y, x)
        img = D.rgba(v, a)
        cells.append(D.resize(img, cell, cell) if SS > 1 else img)
        sys.stdout.write(".")
        sys.stdout.flush()
    sys.stdout.write("\n")
    return D.bleed(D.sheet(cells, grid))


def lerp_table(k, xs, ys):
    return float(np.interp(k, xs, ys))


# ---------------------------------------------------------------------------------------------------------------------
# the impact bursts
# ---------------------------------------------------------------------------------------------------------------------


def _axis_angles(rng, n, axis_jitter=0.1):
    """n ray angles spread unevenly round the circle, with four of them close to the axes (so the burst really reaches
    the cell's four sides)."""
    base = np.sort(rng.uniform(0, 2 * math.pi, n))
    gaps = np.diff(np.concatenate([base, [base[0] + 2 * math.pi]]))
    # even out only the worst clumps: keep what rng gave unless two rays sit on top of each other
    for i in range(n):
        if gaps[i] < 0.12:
            base[(i + 1) % n] += 0.12 - gaps[i]
    axes = [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]
    for ax in axes:
        j = int(np.argmin(np.abs(np.angle(np.exp(1j * (base - ax))))))
        base[j] = ax + rng.uniform(-axis_jitter, axis_jitter)
    return base, axes


def impact_rays_sharp(rng):
    n = 11
    ang, axes = _axis_angles(rng, n, 0.07)
    rays = []
    for th in ang:
        near_axis = any(abs(np.angle(np.exp(1j * (th - a)))) < 0.1 for a in axes)
        reach = 0.97 if near_axis else rng.choice([rng.uniform(0.3, 0.5), rng.uniform(0.55, 0.9)])
        rays.append((float(th), float(reach), float(rng.uniform(0.05, 0.1)), 1.0, float(rng.uniform(-0.18, 0.18)), 1.0))
    for _ in range(9):  # hairlines: long, thin, faint, gone first
        rays.append((float(rng.uniform(0, 2 * math.pi)), float(rng.uniform(0.5, 0.92)), float(rng.uniform(0.016, 0.026)),
                     0.8, float(rng.uniform(-0.2, 0.2)), 0.6))
    for _ in range(12):  # a dense fan of short spikes round the core
        rays.append((float(rng.uniform(0, 2 * math.pi)), float(rng.uniform(0.26, 0.5)), float(rng.uniform(0.05, 0.085)),
                     1.0, float(rng.uniform(-0.1, 0.1)), 1.0))
    return rays


def impact_rays_heavy(rng):
    n = 9
    ang, axes = _axis_angles(rng, n, 0.12)
    rays = []
    for th in ang:
        near_axis = any(abs(np.angle(np.exp(1j * (th - a)))) < 0.14 for a in axes)
        reach = 0.975 if near_axis else rng.uniform(0.62, 0.93)
        rays.append((float(th), float(reach), float(rng.uniform(0.17, 0.26)), 0.75, float(rng.uniform(-0.06, 0.06)), 1.0))
    for _ in range(8):  # short wedges in the gaps
        rays.append((float(rng.uniform(0, 2 * math.pi)), float(rng.uniform(0.38, 0.58)), float(rng.uniform(0.09, 0.14)),
                     0.7, 0.0, 0.85))
    return rays


def lobes_soft(rng):
    """(angle, distance, radius) of the round lobes round the middle of the soft burst."""
    out = []
    n = 8
    base = np.arange(n) * 2 * math.pi / n + rng.uniform(-0.25, 0.25, n) * 1.0
    base[0] = 0.04
    base[2] = math.pi / 2 - 0.05
    base[4] = math.pi + 0.06
    base[6] = 3 * math.pi / 2 + 0.03
    for i, th in enumerate(base):
        rad = rng.uniform(0.19, 0.3)
        dist = 0.955 - rad if i % 2 == 0 else min(0.955 - rad, rng.uniform(0.42, 0.62))
        out.append((float(th), float(dist), float(rad)))
    for _ in range(5):  # small buds between the big lobes
        out.append((float(rng.uniform(0, 2 * math.pi)), float(rng.uniform(0.25, 0.5)), float(rng.uniform(0.08, 0.13))))
    return out


def _core_radius(th, rc, wob, seed_x):
    """A ragged round core: its radius wanders with the angle."""
    return rc * (1 + wob * np.sin(3 * th + seed_x) * 0.5 + wob * 0.5 * np.sin(5 * th + 2.1 * seed_x))


def _impact(kind, seed):
    rng = np.random.default_rng(seed)
    if kind == "A":
        rays = impact_rays_sharp(rng)
        P = dict(freq=7.0, octaves=4, aaw=0.10, thr_t=0.62, thr_gamma=1.25, amp_end=1.0, amp0=0.06, rc=0.21, wob=0.34)
    elif kind == "B":
        rays = impact_rays_heavy(rng)
        P = dict(freq=3.2, octaves=4, aaw=0.10, thr_t=1.05, thr_gamma=1.3, amp_end=0.95, amp0=0.05, rc=0.3, wob=0.28)
    else:
        rays = None
        P = dict(freq=3.0, octaves=3, aaw=0.22, thr_t=1.05, thr_gamma=1.0, amp_end=0.5, amp0=0.03, rc=0.34, wob=0.12)
    lobes = lobes_soft(rng) if kind == "C" else None
    phase = float(rng.uniform(0, 6))

    def scale_of(k):
        if kind == "A":
            return lerp_table(k, [0, 1, 2, 3, 5, 15], [0.34, 0.72, 0.9, 0.96, 1.0, 1.0])
        if kind == "B":
            return lerp_table(k, [0, 1, 2, 3, 15], [0.42, 0.8, 0.97, 1.0, 1.0])
        return 1.0

    def growth_of(k):  # the soft burst blooms: lobes move out and swell
        return lerp_table(k, [0, 1, 2, 3, 4, 5, 15], [0.0, 0.3, 0.62, 0.86, 0.97, 1.0, 1.0])

    def shape(x, y, k):
        r, th = polar(x, y)
        if kind in ("A", "B"):
            sh = [(a, r * (1 + 0.05 * math.sin(k * 2.3 + i * 1.7)), w, pw, b + 0.03 * math.sin(k * 1.9 + i), cp)
                  for i, (a, r, w, pw, b, cp) in enumerate(rays)]
            f = ray_field(x, y, sh)
            rcore = _core_radius(th, P["rc"], P["wob"], phase)
            core = 1.3 * (1 - r / rcore)
            if kind == "B":
                core = 1.45 * (1 - r / rcore) + 0.15
            return np.maximum(f, np.clip(core, 0, 1.6))
        g = growth_of(k)
        acc = np.zeros_like(x)
        for a, dist, rad in lobes:
            # a club of light from the core out to a round end: thin at the root, swelling to the lobe
            c, s_ = math.cos(a), math.sin(a)
            along = x * c + y * s_
            across = -x * s_ + y * c
            far = dist * (0.35 + 0.65 * g)
            rr = rad * (0.45 + 0.55 * g)
            u = np.clip(along / max(far, 1e-3), 0, 1)
            radius = rr * (0.32 + 0.68 * u ** 0.8)
            d = np.where(along < far, np.abs(across), np.hypot(across, along - far))
            d = np.where(along < 0, np.hypot(across, along), d)
            fr = np.clip(1 - d / np.maximum(radius, 1e-3), 0, 1) ** 0.8 * (0.4 + 0.6 * sstep(0.0, 0.75, u))
            acc = acc + fr ** 3
        rcore = _core_radius(th, P["rc"] * (0.6 + 0.4 * g), P["wob"], phase)
        core = np.clip(1.3 * (1 - r / rcore), 0, 1.5) ** 1.0
        return np.maximum(np.minimum(acc ** (1 / 3), 1.0), core)

    def frame(k, y, x):
        s = scale_of(k)
        f0 = shape(x / s, y / s, k)
        e = np.clip((k - 6.0) / 9.0, 0, 1)
        thr = P["thr_t"] * e ** P["thr_gamma"]
        amp = P["amp0"] + (P["amp_end"] - P["amp0"]) * np.clip((k - 4.0) / 11.0, 0, 1)
        n = noise_signed(x, y, k * 0.11, P["freq"], P["octaves"], seed)
        g = f0 - amp * (0.5 - 0.5 * n) - thr
        alpha = np.clip(g / P["aaw"], 0, 1) * window(x, y)
        if kind == "A":
            v = 0.38 + 0.62 * sstep(0.04, 0.8, g)
            v = np.maximum(v, sstep(0.72, 0.88, g))  # a hard white core
        elif kind == "B":
            v = 0.4 + 0.6 * sstep(0.04, 0.95, g)
            crack = sstep(0.9, 0.975, N.ridged2(x * 2.6 + 3, y * 2.6 + 7, octaves=3, seed=seed + 5))
            v = v * (1 - 0.38 * crack * (1 - sstep(0.85, 1.2, f0)))
            v = np.maximum(v, sstep(0.9, 1.05, g))
        else:
            v = 0.34 + 0.66 * sstep(0.0, 1.0, g) ** 1.2
        return np.clip(v, 0, 1), alpha

    return frame


@texture
def VfxImpactA(cell=256, grid=4, seed=101):
    """Sharp: fifteen thin long rays, each a little bent and none alike, hairlines between them, a small hard white
    core. The thin rays are eaten into dashes and then shards from the middle of the life on."""
    return finish_cells(_impact("A", seed), grid * grid, cell, grid)


@texture
def VfxImpactB(cell=256, grid=4, seed=202):
    """Heavy: nine thick short wedges and a big dense ragged core with dark cracks inside; the wedges break into
    chunks (coarse noise), the core goes last."""
    return finish_cells(_impact("B", seed), grid * grid, cell, grid)


@texture
def VfxImpactC(cell=256, grid=4, seed=303):
    """Soft: round lobes that move out of the core and swell (a bloom), smooth inside, soft at the edge; they come away
    from the middle one by one as blobs."""
    return finish_cells(_impact("C", seed), grid * grid, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# the shock ring
# ---------------------------------------------------------------------------------------------------------------------


@texture
def VfxShock(cell=256, grid=4, seed=404):
    """A shock ring seen flat: it races out in the first frames, then holds its size while the band thins; the outside
    edge is white-hot, the inside trails off into grey; noise cuts the band into arcs that shorten into islands. The
    radius wanders with the angle, so it is never a circle."""
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 6.28, 4)

    def frame(k, y, x):
        r, th = polar(x, y)
        wander = 0.02 * np.sin(2 * th + ph[0]) + 0.014 * np.sin(3 * th + ph[1]) + 0.01 * np.sin(5 * th + ph[2])
        rad0 = lerp_table(k, [0, 1, 2, 3, 15], [0.30, 0.6, 0.78, 0.84, 0.865])
        R = rad0 + wander * (0.4 + 0.6 * min(k / 3.0, 1.0))
        # the band thins over the life, and is thicker in some places than others
        thick = lerp_table(k, [0, 3, 6, 15], [0.11, 0.1, 0.09, 0.05])
        nth = noise_signed(np.cos(th) * 1.3, np.sin(th) * 1.3, k * 0.05, 1.7, 3, seed + 1)
        half = thick * np.clip(1 + (0.45 + 0.5 * np.clip((k - 4.0) / 8.0, 0, 1)) * nth, 0.12, 2.0)
        dr = r - R  # positive outside
        # white-hot edge on the outside, a long trailing skirt inside
        outer = np.clip(1 - np.maximum(dr, 0) / (half * 0.55), 0, 1)
        inner = np.clip(1 + np.minimum(dr, 0) / np.minimum(half * 2.2, R * 0.7), 0, 1)
        f = np.where(dr >= 0, outer, inner ** 1.3) * 1.0
        # arcs: gaps open round the ring from the middle of the life, with tapering ends
        around = noise_signed(np.cos(th + 0.08 * k) * 1.6, np.sin(th + 0.08 * k) * 1.6, 3.0, 1.3, 2, seed + 9)
        gap_c = -0.95 + 1.2 * np.clip((k - 5.0) / 9.0, 0, 1)
        f = f * np.clip((around - gap_c) / 0.3, 0, 1) ** 0.7
        e = np.clip((k - 6.0) / 9.0, 0, 1)
        thr = 0.36 * e ** 1.0
        amp = 0.05 + 0.9 * np.clip((k - 4.0) / 9.0, 0, 1)
        n = noise_signed(x, y, k * 0.09, 5.0, 4, seed)
        g = f - amp * (0.5 - 0.5 * n) - thr
        alpha = np.clip(g / 0.10, 0, 1) * window(x, y)
        v = 0.32 + 0.68 * sstep(0.1, 0.9, g)
        v = np.maximum(v, sstep(0.75, 0.9, g) * 1.0)
        return np.clip(v, 0, 1), alpha

    return finish_cells(frame, grid * grid, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# the glint
# ---------------------------------------------------------------------------------------------------------------------


@texture
def VfxGlint(cell=256, grid=4, seed=505):
    """A four-point star with a small white nucleus and no ring round it. It opens (arms grow out of the nucleus),
    turns a quarter of the way round, and closes: the arms shorten and break into beads. The vertical arms are thicker
    and longer than the horizontal ones; two diagonal arms and a few tiny ones are uneven."""
    rng = np.random.default_rng(seed)
    # (angle in the star's own frame, reach, half-width at the root, thickness weight)
    arms = [
        (-math.pi / 2, 0.97, 0.050), (math.pi / 2, 0.90, 0.046),  # up, down
        (math.pi, 0.90, 0.036), (0.0, 0.95, 0.036),  # left, right
        (-math.pi / 4 - 0.1, 0.52, 0.026), (math.pi / 4 + 0.07, 0.40, 0.022),
        (3 * math.pi / 4 - 0.05, 0.46, 0.022), (-3 * math.pi / 4 + 0.12, 0.56, 0.026),
        (-math.pi / 2 + 0.38, 0.27, 0.014), (math.pi / 2 - 0.42, 0.22, 0.014), (0.36, 0.24, 0.014), (math.pi - 0.4, 0.28, 0.014),
    ]

    def frame(k, y, x):
        life = k / 15.0
        open_ = lerp_table(k, [0, 1, 2, 3, 4, 15], [0.22, 0.55, 0.84, 1.0, 1.0, 1.0])
        close = lerp_table(k, [0, 8, 11, 15], [1.0, 1.0, 0.82, 0.5])
        phi = 0.62 * sstep(0.0, 1.0, life)  # turns a quarter way round (the arms are 90 degrees apart)
        c, s = math.cos(phi), math.sin(phi)
        xr, yr = x * c + y * s, -x * s + y * c  # the star's own frame
        rays = []
        for th, reach, w0 in arms:
            rays.append((th, reach * open_ * close, w0 * (0.6 + 0.4 * open_), 1.5, 0.0, 1.0))
        f = ray_field(xr, yr, rays)
        r = np.hypot(x, y)
        nuc = np.clip(1.4 * (1 - r / (0.075 * (0.5 + 0.5 * open_) * (0.6 + 0.4 * close))), 0, 1.4)
        f0 = np.maximum(f, nuc)
        e = np.clip((k - 7.0) / 8.0, 0, 1)
        thr = 0.9 * e ** 1.1
        amp = 0.03 + 0.9 * np.clip((k - 6.0) / 8.0, 0, 1)
        n = noise_signed(x, y, k * 0.1, 12.0, 3, seed)
        g = f0 - amp * (0.5 - 0.5 * n) - thr
        core_a = np.clip(g / 0.10, 0, 1)
        # a faint soft haze along the arms and round the nucleus (no outline): gone before the arms are
        haze = np.exp(-(np.hypot(x, y) / 0.11) ** 2) * 0.55
        for th, reach, w0 in arms[:4]:
            c2, s2 = math.cos(th), math.sin(th)
            along = xr * c2 + yr * s2
            across = -xr * s2 + yr * c2
            t = np.clip(along / (reach * open_ * close), 0, 1.5)
            haze = np.maximum(haze, np.where((along > 0) & (t < 1), np.exp(-(across / (w0 * 2.6)) ** 2) * (1 - t) ** 1.6 * 0.4, 0))
        haze = haze * (1 - sstep(0.1, 0.8, e))
        alpha = np.maximum(core_a, haze) * window(x, y)
        v = 0.4 + 0.6 * sstep(0.05, 0.85, g)
        v = np.maximum(v, sstep(0.8, 1.0, g))
        v = np.where(core_a > 0.5, v, 0.55 + 0.4 * haze)
        return np.clip(v, 0, 1), alpha

    return finish_cells(frame, grid * grid, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# the sparks
# ---------------------------------------------------------------------------------------------------------------------


def _streak(y, x, path, branches=(), w_head=0.05, seed=0, gaps=True):
    """A spark streak along a polyline path [(y, x), ...] from its head (first point) to its tail; branches are more
    polylines that leave the main one (each [(y, x), ...] with its own head width factor at the end of the list).
    Thick and white-hot at the head, thinning to a hairline tail, a soft halo round it. Returns (value, alpha)."""
    alpha = np.zeros_like(x)
    value = np.zeros_like(x)
    halo = np.zeros_like(x)
    lines = [(path, 1.0)] + [(b[:-1], b[-1]) for b in branches]
    for pts, wf in lines:
        seglen = [math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1)]
        total = sum(seglen)
        acc = 0.0
        for i in range(len(pts) - 1):
            d, tloc = D.segment(y, x, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1])
            s = (acc + tloc * seglen[i]) / total  # 0 head .. 1 tail
            acc += seglen[i]
            w = (w_head * wf) * (1 - s) ** 1.35 + 0.0045
            cover = D.aa(d - w, D.px(y.shape[0]) * 1.3)
            if gaps:  # the last part of the tail breaks into dashes
                gap = N.perlin2(s * 9.0 + 3.0, np.full_like(s, seed * 0.37), seed=seed + 3)
                cover = cover * (1 - sstep(0.62, 0.9, s) * sstep(-0.05, 0.25, gap))
            across = np.clip(1 - d / np.maximum(w, 1e-4), 0, 1)
            val = (0.5 + 0.5 * (1 - s) ** 0.8) * (0.72 + 0.28 * sstep(0.0, 0.75, across))
            val = np.maximum(val, sstep(0.6, 0.9, across) * (1 - s) ** 0.5)
            alpha = np.maximum(alpha, cover)
            value = np.maximum(value, val * cover)
            halo = np.maximum(halo, 0.3 * np.exp(-(d / (w * 2.2 + 0.012)) ** 2) * (1 - s) ** 0.9)
    a = np.maximum(alpha, halo)
    v = np.where(alpha > 0.02, value / np.maximum(alpha, 1e-4), 0.6)
    return np.clip(v, 0, 1), a


@texture
def VfxSparks(cell=512, grid=2, seed=606):
    """Four spark streaks in a 2x2 random sheet, head up (the game stretches them along their flight with
    VelocityParallel): straight, bent (one elbow), forked (a kink and a side branch), short (a stubby one)."""
    y, x = D.grid(cell * SS)
    lo, hi = -0.89, 0.94
    streaks = []
    # straight: a hair of wobble down its length
    streaks.append(dict(path=[(lo, 0.015), (-0.5, -0.012), (0.0, 0.01), (0.5, -0.01), (hi, 0.0)], w=0.052, seed=1))
    # bent: straight down, then an elbow and a leaning tail; the whole path sits in the cell
    streaks.append(dict(path=[(lo, 0.12), (-0.35, 0.10), (-0.02, -0.02), (0.4, -0.2), (hi, -0.34)], w=0.05, seed=2))
    # forked: a kinked main line and a branch that leaves it a third of the way down (the last number is its width factor)
    streaks.append(dict(path=[(lo, -0.1), (-0.45, -0.07), (-0.2, 0.08), (0.2, 0.02), (hi, 0.1)],
                        branches=[[(-0.2, 0.08), (0.05, 0.3), (0.3, 0.4), (0.56, 0.46), 0.55]], w=0.05, seed=3))
    # short: a stubby spark, thick head, half the length
    streaks.append(dict(path=[(-0.45, 0.01), (-0.2, -0.015), (0.2, 0.01), (0.5, 0.0)], w=0.085, seed=4))
    cells = []
    for sp in streaks:
        v, a = _streak(y, x, sp["path"], sp.get("branches", ()), sp["w"], sp["seed"], gaps=sp["seed"] != 4)
        a = a * window(x, y)
        cells.append(D.resize(D.rgba(v, a), cell, cell))
    return D.bleed(D.sheet(cells, grid))


# ---------------------------------------------------------------------------------------------------------------------
# build and look
# ---------------------------------------------------------------------------------------------------------------------

NAMES = ["VfxImpactA", "VfxImpactB", "VfxImpactC", "VfxShock", "VfxGlint", "VfxSparks"]


def build(names=None):
    for name in names or NAMES:
        sys.stdout.write(name + " ")
        img = BUILDERS[name]()
        path = D.write_png(os.path.join(TEXTURES, name + ".png"), img)
        print("[tex_impact]", path, img.shape)


def _panel(img, tint, back, laid):
    rgb = img[..., :3] * np.array(tint)[None, None, :]
    a = img[..., 3:4]
    base = np.ones_like(rgb) * np.array(back)[None, None, :]
    out = base * (1 - a) + rgb * a if laid else np.clip(base + rgb * a, 0, 1)
    return out


def preview(name, outdir):
    """Writes <outdir>/<name>_look.png: the sheet (1024) over dark added as light, tinted orange and cyan, and over a
    light grey laid over (alpha blended), the same two tints: a 2 x 2 of the whole sheet."""
    img = D.read_png(os.path.join(TEXTURES, name + ".png"))
    orange, cyan = (1.0, 0.58, 0.24), (0.36, 0.78, 1.0)
    dark, light = (0.07, 0.07, 0.085), (0.82, 0.82, 0.8)
    tl = _panel(img, orange, dark, False)
    tr = _panel(img, cyan, dark, False)
    bl = _panel(img, orange, light, True)
    br = _panel(img, cyan, light, True)
    m = np.concatenate([np.concatenate([tl, tr], axis=1), np.concatenate([bl, br], axis=1)], axis=0)
    h, w, _ = m.shape
    m = D.resize(np.concatenate([m, np.ones((h, w, 1))], axis=-1), h // 2, w // 2)
    p = D.write_png(os.path.join(outdir, name + "_look.png"), m)
    print("[tex_impact preview]", p)
    return p


def strip(name, outdir, picks=(0, 3, 7, 9, 11, 13, 15), tint=(1.0, 0.7, 0.35)):
    """Chosen frames of a one-shot at full cell size, side by side, over dark (added) with a light-backdrop row
    (laid over): to look at the detail."""
    img = D.read_png(os.path.join(TEXTURES, name + ".png"))
    g = 4 if img.shape[0] == 1024 and name != "VfxSparks" else 2
    ch = img.shape[0] // g
    picks = [p for p in picks if p < g * g]
    cells = []
    for n in picks:
        r, c = divmod(n, g)
        cells.append(img[r * ch:(r + 1) * ch, c * ch:(c + 1) * ch])
    row = np.concatenate(cells, axis=1)
    dark = _panel(row, tint, (0.07, 0.07, 0.085), False)
    light = _panel(row, tint, (0.82, 0.82, 0.8), True)
    m = np.concatenate([dark, light], axis=0)
    m = np.concatenate([m, np.ones(m.shape[:2] + (1,))], axis=-1)
    if m.shape[1] > 1792:
        f = m.shape[1] // 1792 + (1 if m.shape[1] % 1792 else 0)
        # shrink by a whole factor
        while m.shape[1] % f or m.shape[0] % f:
            f += 1
        m = D.resize(m, m.shape[0] // f, m.shape[1] // f)
    p = D.write_png(os.path.join(outdir, name + "_strip.png"), m)
    print("[tex_impact strip]", p)
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
            preview(name, out)
            strip(name, out)


if __name__ == "__main__":
    main()
