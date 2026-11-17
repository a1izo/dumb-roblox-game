"""Ticket V1.4 of docs/handoff/vfx-rework-plan-2026-11-16.md: slashes, lightning arcs and an energy wisp (light textures:
added, black is nothing; white and grey so the game tints them). Route E, eroded: a shape field, minus layered noise
bites, minus a rising threshold, so the shape is eaten from its thin parts first.

    VfxSlashA       4x4 one-shot   a thin fast blade stroke with a hard edge, a faint wake of lines behind it
    VfxSlashB       4x4 one-shot   a wide heavy crescent, a dark-edged thick body, torn notches on its inner edge
    VfxArc          4x4 random     sixteen standalone lightning arcs with branches (each cell is one bolt, running top
                                   to bottom like VfxSparks; Emit picks a cell, it is not an animation)
    VfxEnergyWisp   4x4 loop       a curling wisp of light: a main tendril with a spiral curl and two thinner ones

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/vfx/tex_slash.py [names]
        [--preview OUTDIR]       (numpy only; writes art/export/textures/<name>.png, and with --preview the pictures
                                 that show each sheet over dark and over light, in two tints, and a strip of frames)

Every sheet: 1024 x 1024, a frame is a 256 px cell; the subject stays 4 px or more off every edge of its cell; the two
slashes are a whole life each (born in the first frame, full by frame 4, the trailing end tears away from frame 5 on,
islands at the end). Drawn at twice the size and boxed down, so thin tips are anti-aliased. The helpers are this
file's own copies (tex_impact.py, textures.py, draw.py and noise.py are not edited by this ticket).
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
SS = 1 if os.environ.get("TEX_QUICK") else 2  # supersampling: frames are drawn at SS x the cell and boxed down (TEX_QUICK=1: a rough, fast look)
SAFE = 0.962  # nothing is drawn past this (the cell runs -1..1; 4 px is 0.031)


def texture(fn):
    BUILDERS[fn.__name__] = fn
    return fn


# ---------------------------------------------------------------------------------------------------------------------
# helpers (copies of tex_impact.py's, plus the ones the arcs need)
# ---------------------------------------------------------------------------------------------------------------------


def sstep(a, b, x):
    return D.smoothstep(a, b, x)


def window(x, y):
    """1 inside the safe square, 0 from SAFE outward: no frame ever touches its neighbour."""
    wx = np.clip((SAFE - np.abs(x)) / 0.012, 0, 1)
    wy = np.clip((SAFE - np.abs(y)) / 0.012, 0, 1)
    return wx * wy


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


def fbm_xy(a, b, z, fa, fb, octaves, seed, period_z=None):
    """Layered noise (about -1..1) over two coordinates with their own frequencies (so it can be stretched into
    streaks: low fa and high fb run streaks along a), drifting with z. period_z makes z wrap (a loop)."""
    period = (None, None, period_z)
    n = N.fbm3(a * fa + 11.3, b * fb + 4.7, np.full_like(a, z), octaves=octaves, seed=seed, period=period,
               time_scales=False)
    return np.clip(n * 1.7, -1.0, 1.0)


# ---------------------------------------------------------------------------------------------------------------------
# the slashes: an arc of a circle through two points, the stroke's own coordinates (s along it, dr across it)
# ---------------------------------------------------------------------------------------------------------------------


def arc_geometry(p0, p1, bulge):
    """The circle through p0 and p1 (x, y) whose arc bulges by `bulge` (the sagitta; positive is to the left of the
    way from p0 to p1 as the image is drawn, y down). Returns (cx, cy, R, mid angle, half angle, sign) so that
    s = 0.5 + sign * wrap(angle - mid) / (2 * half) runs 0 at p0 to 1 at p1."""
    p0, p1 = np.array(p0, float), np.array(p1, float)
    v = p1 - p0
    c = float(np.hypot(*v))
    m = (p0 + p1) / 2
    n = np.array([v[1], -v[0]]) / c
    if bulge < 0:
        n, bulge = -n, -bulge
    R = (c * c / 4 + bulge * bulge) / (2 * bulge)
    centre = m - n * (R - bulge)
    mid = math.atan2(n[1], n[0])
    half = math.atan2(c / 2, R - bulge)
    a1 = math.atan2(p1[1] - centre[1], p1[0] - centre[0])
    sign = 1.0 if ((a1 - mid + math.pi) % (2 * math.pi) - math.pi) > 0 else -1.0
    return float(centre[0]), float(centre[1]), float(R), mid, half, sign


def stroke_coords(x, y, geo, wander):
    """(s, dr, a, R) for every pixel: s along the arc (0 at its start, 1 at its end, outside 0..1 beyond the ends), dr
    the distance across it (positive outward, the convex side), a the length along it and R the arc's radius there,
    which wanders a little so the arc is never a circle."""
    cx, cy, R0, mid, half, sign = geo
    dx, dy = x - cx, y - cy
    r = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    s = 0.5 + sign * np.angle(np.exp(1j * (th - mid))) / (2 * half)
    sc = np.clip(s, 0, 1)
    R = R0 * (1 + sum(a * np.sin(f * sc + p) for a, f, p in wander))
    return s, r - R, s * 2 * half * R0, R


def taper(s, p_rise, p_fall):
    """0 at both ends, 1 at its fullest: s^p_rise * (1 - s)^p_fall scaled to a peak of 1."""
    s = np.clip(s, 0, 1)
    peak = (p_rise / (p_rise + p_fall)) ** p_rise * (p_fall / (p_rise + p_fall)) ** p_fall
    return (s ** p_rise) * ((1 - s) ** p_fall) / peak


def _speck_list(rng, n, tear_from, tear_len, s_lo, s_hi, len_rng, wid_rng):
    """Little pieces that come away from the stroke where its tear passes: (s0, born, life, slide, off, drift, length,
    width), all in the stroke's own coordinates."""
    out = []
    for _ in range(n):
        s0 = float(rng.uniform(s_lo, s_hi))
        born = tear_from + s0 / 1.3 * tear_len - float(rng.uniform(0.0, 1.5))
        out.append((s0, born, float(rng.uniform(3.0, 5.0)), float(rng.uniform(0.012, 0.035)),
                    float(rng.uniform(-0.05, 0.05)), float(rng.uniform(-0.012, 0.03)),
                    float(rng.uniform(*len_rng)), float(rng.uniform(*wid_rng))))
    return out


def _slash(kind, seed):
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 6.28, 3)
    if kind == "A":
        geo = arc_geometry((-0.90, 0.80), (0.89, -0.60), 0.52)
        P = dict(wmax=0.088, bias=0.22, pc_o=5.0, pc_i=1.7, rise=0.72, fall=0.5, aaw=0.07, fa=1.0, fb=18.0, bite=1.15,
                 head=[0.5, 0.8, 0.95, 1.0], tear_from=6.0, tear_len=8.5, cool=0.3, turn=0.1, thr_max=0.7, slit=0.0,
                 notch=0.34)
        wander = [(0.045, 5.3, ph[0]), (0.03, 11.0, ph[1])]
        specks = _speck_list(rng, 11, 6.0, 8.5, 0.1, 0.8, (0.05, 0.13), (0.011, 0.022))
    else:
        geo = arc_geometry((-0.42, -0.86), (-0.50, 0.84), 1.08)
        P = dict(wmax=0.3, bias=0.34, pc_o=3.2, pc_i=2.0, rise=0.5, fall=0.85, aaw=0.1, fa=0.8, fb=8.0, bite=1.1,
                 head=[0.55, 0.8, 0.94, 1.0], tear_from=6.5, tear_len=8.0, cool=0.35, turn=0.05, thr_max=0.9, slit=1.0,
                 notch=0.95)
        wander = [(0.05, 4.3, ph[0]), (0.03, 9.0, ph[1])]
        specks = _speck_list(rng, 9, 6.5, 8.0, 0.1, 0.8, (0.09, 0.2), (0.03, 0.06))
    span = 2 * geo[4] * geo[2]  # the arc's length, to turn s into a length

    def scale_of(k):
        return lerp_table(k, [0, 1, 2, 3, 4, 15], [0.9, 0.96, 1.0, 1.0, 1.0, 1.0])

    def frame(k, y, x):
        # the stroke drifts a little as it ages (a slow turn about the cell's middle)
        turn = P["turn"] * sstep(0, 15, k) * (-1 if kind == "A" else 1)
        c, s_ = math.cos(turn), math.sin(turn)
        sc = scale_of(k)
        xr, yr = (x * c + y * s_) / sc, (-x * s_ + y * c) / sc
        s, dr, a, R = stroke_coords(xr, yr, geo, wander)
        head = lerp_table(k, [0, 1, 2, 3, 15], P["head"] + [1.0])
        sp = s / head  # the stroke is born short and grows toward its head; its tip is always a point
        tp = taper(sp, P["rise"], P["fall"])
        w = tp * P["wmax"]
        wo = np.maximum(w * (1 - P["bias"]), 1e-4)
        wi = np.maximum(w * (1 + P["bias"]), 1e-4)
        inside = (s >= 0) & (sp <= 1)
        u = np.where(dr >= 0, dr / wo, dr / wi)  # -1 inner edge .. +1 outer (convex) edge
        au = np.abs(u)
        cross = np.where(dr >= 0, 1 - np.minimum(au, 1) ** P["pc_o"], 1 - np.minimum(au, 1) ** P["pc_i"])
        f = np.where(inside & (au < 1), cross * (0.62 + 0.38 * np.minimum(tp * 1.4, 1.0)), 0.0)
        if kind == "A":  # a wake: two faint thin lines that leave the blade's inner side toward the tail
            for off, hw, cap, lo in [(0.17, 0.012, 0.66, 0.2), (0.3, 0.009, 0.55, 0.34)]:
                line_c = -off * (1 - np.clip(sp, 0, 1)) ** 0.85 - 0.012
                lw = hw * (0.35 + 0.65 * np.minimum(tp * 1.6, 1.0))
                fl = np.clip(1 - np.abs(dr - line_c) / np.maximum(lw, 1e-4), 0, 1) * cap
                fl = fl * sstep(lo, lo + 0.1, sp) * sstep(1.0, 0.9, sp) * inside
                f = np.maximum(f, fl)
        life = np.clip((k - 5.0) / 10.0, 0, 1)  # 0 while it is whole, 1 at the end
        e = np.clip((k - 8.0) / 7.0, 0, 1)
        thr = P["thr_max"] * e ** 1.2
        # streaks run along the stroke, cuts run across it: together they tear it into dashes of light
        n_s = fbm_xy(a, dr, k * 0.12, P["fa"], P["fb"], 4, seed)
        n_c = fbm_xy(a, dr, k * 0.1 + 5.0, P["fa"] * 4.5, P["fb"] * 0.22, 3, seed + 9)
        bite = P["bite"] * (0.04 + 0.96 * life ** 0.9) * (0.5 - 0.5 * (0.6 * n_s + 0.4 * n_c))
        # the trailing end tears first: the front moves along the stroke and each streak lets go at its own place
        front = np.clip((k - P["tear_from"]) / P["tear_len"], 0, 1) * 1.3
        tear = np.clip((front + 0.34 * n_s - s) / 0.22, 0, 1) * 1.5
        # teeth torn out of the inner edge
        n_notch = fbm_xy(a, dr, k * 0.05 + 3.0, 3.0 if kind == "B" else 6.0, 4.0 if kind == "B" else 10.0, 3, seed + 5)
        inner_w = sstep(0.25, -0.85, u)
        notch = P["notch"] * inner_w * sstep(-0.15, 0.55, n_notch) * (0.35 + 0.65 * sstep(0, 5, k))
        # slits: thin lines cut through the body along the stroke (a streak of dark inside the light)
        slit = 0.0
        if P["slit"]:
            n_sl = fbm_xy(a, dr, k * 0.06 + 9.0, 0.7, 15.0, 3, seed + 11)
            slit = (0.42 + 0.7 * life) * sstep(0.42, 0.58, n_sl) * sstep(-0.95, 0.15, u) * sstep(0.05, 0.25, sp)
        g = f - bite - notch - slit - thr - tear
        alpha = np.clip(g / P["aaw"], 0, 1)
        # the three values: white-hot toward the outer edge, a bright body, a darker rim
        if kind == "A":
            v = 0.4 + 0.6 * sstep(-0.55, 0.45, np.clip(u, -1, 1))
            v = np.maximum(v, 0.85 * sstep(0.3, 0.9, g))
            lines = sstep(0.62, 0.85, n_s) * sstep(0.0, 0.7, -u) * 0.45
            v = v * (1 - lines)
        else:
            rim = sstep(0.0, 0.45, g)
            v = 0.3 + 0.7 * sstep(-0.9, 0.75, np.clip(u, -1, 1)) ** 1.4
            v = v * (0.5 + 0.5 * rim)
            v = np.maximum(v, sstep(0.45, 0.85, g) * sstep(0.2, 0.9, np.clip(u, -1, 1)))
            lines = sstep(0.4, 0.6, n_s) * sstep(-0.9, 0.2, u) * 0.5
            v = v * (1 - lines)
        v = v * (1 - P["cool"] * e)
        alpha = np.where(inside, alpha, 0.0)
        if kind == "A":  # a faint wide veil along the stroke's inner side: the air it cuts
            vw = 0.2 * np.minimum(tp * 1.2, 1.0)
            veil = np.clip(1 - np.abs(dr + 0.1 * tp) / np.maximum(vw, 1e-4), 0, 1) ** 1.3
            veil = veil * 0.26 * (0.55 + 0.45 * n_s) * (1 - sstep(0.1, 0.8, e)) * (1 - np.clip(tear, 0, 1)) * inside
            v = np.where(veil > alpha, 0.42, v)
            alpha = np.maximum(alpha, veil)
        # pieces that come away
        sa = np.zeros_like(alpha)
        for s0, born, dur, slide, off, drift, ln, wd in specks:
            age = k - born
            if 0 <= age < dur:
                aj = (s0 + slide * age) * span
                dj = off + drift * age
                shrink = 1 - (age / dur) ** 2
                q = np.hypot((a - aj) / (ln * shrink + 1e-4), (dr - dj) / (wd * shrink + 1e-4))
                sa = np.maximum(sa, np.clip((1 - q) / 0.4, 0, 1))
        v = np.where(sa > alpha, 0.75, v)
        alpha = np.maximum(alpha, sa)
        return np.clip(v, 0, 1), alpha * window(x, y)

    return frame


@texture
def VfxSlashA(cell=256, grid=4, seed=701):
    """A thin fast blade: a long shallow arc across the cell from one corner to the other, hard and white on its outer
    edge, soft and notched on the inner one, two faint wake lines that fan out behind it. It is born as a short stroke
    and grows to its full length by frame 3; from frame 5 its trailing end tears into the wake's lines and specks."""
    return finish_cells(_slash("A", seed), grid * grid, cell, grid)


@texture
def VfxSlashB(cell=256, grid=4, seed=802):
    """A wide heavy crescent: a fat curved body with a dark grey rim and a white-hot outer band, big teeth torn out of
    its inner edge and dark streaks inside; the trailing end breaks off in chunks and the horns come away last."""
    return finish_cells(_slash("B", seed), grid * grid, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# the lightning arcs: sixteen standalone bolts, each running from the top of its cell to the bottom (like VfxSparks, the
# game turns them to where they go). Angular all the way down: kinks, a jitter on every segment, forks that leave the
# main bolt, white-hot thread inside a bright body inside a faint glow. A random sheet: no motion, no erosion.
# ---------------------------------------------------------------------------------------------------------------------

LIM = 0.915  # a bolt's own path stays inside this; its glow is cut at SAFE


def _jitter(rng, pts, amt, parts=2):
    """Lightning is angular all the way down: every segment is split in `parts` and the new points are pushed sideways."""
    out = [pts[0]]
    for (y0, x0), (y1, x1) in zip(pts[:-1], pts[1:]):
        dy, dx = y1 - y0, x1 - x0
        ln = math.hypot(dy, dx) + 1e-9
        ny, nx = -dx / ln, dy / ln
        for j in range(1, parts):
            t = j / parts + rng.uniform(-0.15, 0.15) / parts
            o = rng.uniform(-1, 1) * amt * ln
            out.append((y0 + dy * t + ny * o, x0 + dx * t + nx * o))
        out.append((y1, x1))
    return out


def _clampp(pts):
    return [(float(np.clip(y, -LIM, LIM)), float(np.clip(x, -LIM, LIM))) for y, x in pts]


def _main_path(rng, spec):
    y0, y1 = spec.get("y0", -LIM), spec.get("y1", LIM)
    x0, x1 = spec["x0"], spec["x1"]
    n = spec["kinks"]
    t = np.concatenate([[0.0], np.cumsum(rng.uniform(0.5, 1.5, n))])
    t = t / t[-1]
    off = np.zeros(n + 1)
    sign = 1.0 if rng.random() < 0.5 else -1.0
    for i in range(1, n):
        if rng.random() < 0.8:
            sign = -sign
        off[i] = sign * spec["jag"] * rng.uniform(0.35, 1.0)
    bow = spec.get("bow", 0.0)
    pts = [(y0 + (y1 - y0) * t[i], x0 + (x1 - x0) * t[i] + off[i] + bow * math.sin(math.pi * t[i])) for i in range(n + 1)]
    return _clampp(_jitter(rng, pts, spec["jag"] * 0.22 + 0.01))


def _branch(rng, start, ang, length, segs, kink=0.45):
    """A fork leaving `start` (y, x) heading `ang` radians from straight down, in `segs` kinked pieces."""
    pts = [start]
    y, x = start
    a = ang
    for _ in range(segs):
        ln = length / segs * rng.uniform(0.6, 1.4)
        y += math.cos(a) * ln
        x += math.sin(a) * ln
        pts.append((y, x))
        a += rng.uniform(-kink, kink) * (1 if rng.random() < 0.5 else -1)
    return _clampp(_jitter(rng, pts, 0.05, 2))


def _bolt_lines(spec, seed):
    """[(points, width factor, kind)]: the main bolt, then its forks. kind 'main' tapers at both ends, 'fork' at its tip."""
    rng = np.random.default_rng(seed)
    main = _main_path(rng, spec)
    lines = [(main, 1.0, "main")]
    if spec.get("double"):
        second = _main_path(rng, dict(spec, x0=-spec["x0"] * 0.8 - 0.1, x1=-spec["x1"] * 0.8 + 0.1, kinks=spec["kinks"] + 2,
                                      jag=spec["jag"] * 0.9))
        lines.append((second, 0.8, "main"))
    verts = main[2:-2] if len(main) > 6 else main[1:-1]
    for _ in range(spec.get("branches", 0)):
        i = int(rng.integers(0, len(verts)))
        side = 1.0 if rng.random() < 0.5 else -1.0
        ang = side * rng.uniform(0.35, 1.0) * spec.get("spread", 1.0)
        ln = rng.uniform(0.2, 0.42) * spec.get("bl", 1.0)
        br = _branch(rng, verts[i], ang, ln, int(rng.integers(2, 5)))
        lines.append((br, 0.5, "fork"))
        if rng.random() < spec.get("sub", 0.35):  # a twig off the fork
            j = int(rng.integers(1, len(br) - 1)) if len(br) > 2 else 1
            tw = _branch(rng, br[j], -side * rng.uniform(0.3, 0.9), ln * rng.uniform(0.3, 0.5), 2)
            lines.append((tw, 0.3, "fork"))
    if spec.get("split"):  # a Y: at about 55% down the bolt a second tine of nearly the same weight runs to the bottom
        i = int(len(main) * 0.5)
        side = 1.0 if main[-1][1] > main[i][1] else -1.0
        tine = _branch(rng, main[i], -side * spec["split"], (LIM - main[i][0]) * 1.1, 4, 0.25)
        lines.append((tine, 0.8, "fork"))
    if spec.get("fan"):  # the end of the bolt opens into three tines
        end = main[-4]
        for a in (-0.5, 0.0, 0.55):
            lines.append((_branch(rng, end, a + rng.uniform(-0.1, 0.1), (LIM - end[0]) * 1.1, 2, 0.2), 0.55, "fork"))
    if spec.get("spray"):  # a short bolt ends in a little spray of tines
        end = main[-1]
        for a in (-0.7, -0.15, 0.4, 0.9):
            lines.append((_branch(rng, end, a + rng.uniform(-0.1, 0.1), rng.uniform(0.1, 0.22), 2, 0.3), 0.45, "fork"))
    return lines


def _render_bolt(y, x, lines, w0, seed):
    """(value, alpha): each line is drawn as a thread of white-hot light, a bright body round it and a faint glow."""
    alpha = np.zeros_like(x)
    value = np.zeros_like(x)
    halo = np.zeros_like(x)
    pxl = D.px(y.shape[0]) * 1.3
    for pts, wf, kind in lines:
        seglen = [math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1)]
        total = max(sum(seglen), 1e-6)
        acc = 0.0
        for i in range(len(pts) - 1):
            d, tl = D.segment(y, x, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1])
            s = np.clip((acc + tl * seglen[i]) / total, 0.0, 1.0)
            acc += seglen[i]
            if kind == "main":
                prof = np.minimum(1.0, np.minimum(s / 0.07, (1 - s) / 0.1)) ** 0.8
            else:
                prof = 0.3 + 0.7 * (1 - s) ** 0.9
            w = w0 * wf * prof + 0.0035
            cover = D.aa(d - w, pxl)
            q = np.clip(d / np.maximum(w, 1e-4), 0, 1.5)
            val = 1.0 - 0.55 * sstep(0.22, 1.0, q)  # white-hot thread, a bright body, a darker rim
            alpha = np.maximum(alpha, cover)
            value = np.maximum(value, val * cover)
            halo = np.maximum(halo, 0.3 * np.exp(-(d / (w * 3.2 + 0.012)) ** 2) * (0.45 + 0.55 * prof))
    a = np.maximum(alpha, halo)
    v = np.where(alpha > 0.02, value / np.maximum(alpha, 1e-4), 0.42)
    v = np.where(alpha < halo, 0.42, v)
    return np.clip(v, 0, 1), a


ARC_SPECS = [
    dict(x0=-0.1, x1=0.15, kinks=8, jag=0.17, w=0.034, branches=3, bl=1.0),  # the plain one
    dict(x0=0.2, x1=-0.25, kinks=6, jag=0.3, w=0.052, branches=4, bl=1.2, sub=0.5),  # heavy
    dict(x0=-0.5, x1=0.4, kinks=13, jag=0.075, w=0.019, branches=3, bl=0.7),  # a thin crawler
    dict(x0=0.05, x1=-0.35, kinks=7, jag=0.17, w=0.04, split=0.55, branches=1),  # a Y
    dict(x0=-0.86, x1=0.8, kinks=9, jag=0.12, w=0.03, branches=3, bl=1.1),  # wide diagonal
    dict(x0=-0.25, x1=0.3, kinks=11, jag=0.07, w=0.03, branches=2, bow=0.5),  # a bow
    dict(x0=-0.4, x1=0.35, kinks=7, jag=0.15, w=0.03, double=True, branches=1),  # two strands that cross
    dict(x0=0.2, x1=0.0, kinks=5, jag=0.2, w=0.045, y1=0.2, spray=True),  # a short bolt that ends in a spray
    dict(x0=-0.1, x1=0.1, kinks=8, jag=0.14, w=0.03, branches=6, bl=1.3, sub=0.7, spread=1.2),  # a tree
    dict(x0=0.35, x1=0.3, kinks=7, jag=0.18, w=0.05, split=0.3, branches=0),  # thick, a long fork close beside it
    dict(x0=-0.3, x1=0.3, kinks=4, jag=0.5, w=0.04, branches=2, bl=0.8),  # a big zigzag
    dict(x0=0.0, x1=-0.1, kinks=7, jag=0.16, w=0.034, y1=0.55, fan=True, branches=1),  # opens into three tines
    dict(x0=0.86, x1=-0.8, kinks=9, jag=0.12, w=0.034, branches=3, bl=1.0),  # wide diagonal the other way
    dict(x0=0.1, x1=-0.1, kinks=9, jag=0.1, w=0.03, branches=6, bl=0.55, sub=0.2, spread=1.4),  # stubby forks both sides
    dict(x0=-0.15, x1=0.2, kinks=5, jag=0.06, w=0.022, branches=5, bl=0.45, sub=0.1),  # thin and straight with twigs
    dict(x0=0.0, x1=0.15, kinks=10, jag=0.12, w=0.034, branches=3, bl=1.8, spread=1.5, sub=0.5),  # two forks that reach out wide
]


@texture
def VfxArc(cell=256, grid=4, seed=901):
    """Sixteen lightning arcs, a random sheet: each cell is one standalone bolt from the top of the cell to the bottom,
    kinked and jittered all the way, with forks and twigs, a white-hot thread in a bright body in a faint glow. They
    differ in weight, spread and shape (plain, heavy, thin, a Y, wide diagonals, a bow, two that cross, a short one that
    ends in a spray, a tree, a zigzag, three tines, stubby forks, twigs, wide forks); a few have sparks round them."""
    y, x = D.grid(cell * SS)
    cells = []
    for i, spec in enumerate(ARC_SPECS[: grid * grid]):
        lines = _bolt_lines(spec, seed + i * 13)
        v, a = _render_bolt(y, x, lines, spec["w"], seed + i)
        rng = np.random.default_rng(seed + 500 + i)
        if i % 3 == 1 or spec.get("spray"):  # sparks: small bright specks thrown off near the main bolt
            main = lines[0][0]
            for _ in range(int(rng.integers(3, 6))):
                py, px_ = main[int(rng.integers(1, len(main) - 1))]
                cy, cx = py + rng.uniform(-0.1, 0.1), px_ + rng.uniform(0.04, 0.16) * (1 if rng.random() < 0.5 else -1)
                r = rng.uniform(0.013, 0.024)
                sa = D.aa(np.hypot(y - cy, x - cx) - r, D.px(y.shape[0]) * 1.3)
                v = np.where(sa > a, 0.85, v)
                a = np.maximum(a, sa)
        a = a * window(x, y)
        cells.append(D.resize(D.rgba(v, a), cell, cell))
        sys.stdout.write(".")
        sys.stdout.flush()
    sys.stdout.write("\n")
    return D.bleed(D.sheet(cells, grid))


# ---------------------------------------------------------------------------------------------------------------------
# the energy wisp: a curling tendril of light that rises, with its tip winding into a spiral; a loop. Three tendrils
# share a root. A wave runs up each one and the fraying noise flows along it (both wrap exactly after 16 frames).
# ---------------------------------------------------------------------------------------------------------------------

LOOP_N = 16
WISP_N = 96  # points on a tendril

# one tendril: root (y, x) before fitting, start angle (up is -pi/2; y is down, so a larger angle turns clockwise),
# length, a gentle S, the spiral at the tip, the travelling wave (cycles, size, phase), root width
WISP_TENDRILS = [
    dict(phi0=-1.45, length=3.4, s_amp=0.6, s_cyc=1.1, s_ph=0.2, curl=5.4, curl_pow=3.4, w_cyc=2.0, w_amp=0.34, w_ph=0.0, w0=0.115, seed=1),
    dict(phi0=-1.55, length=3.1, s_amp=0.6, s_cyc=1.1, s_ph=0.5, curl=5.0, curl_pow=3.2, w_cyc=2.0, w_amp=0.42, w_ph=2.4, w0=0.07, seed=2),
    dict(phi0=-1.4, length=2.5, s_amp=0.7, s_cyc=1.2, s_ph=-0.3, curl=4.2, curl_pow=2.8, w_cyc=3.0, w_amp=0.36, w_ph=4.2, w0=0.045, seed=3),
]


def _tendril(spec, t):
    s = np.linspace(0, 1, WISP_N)
    phi = (spec["phi0"] + spec["s_amp"] * np.sin(2 * math.pi * spec["s_cyc"] * s + spec["s_ph"]) * s
           + spec["curl"] * s ** spec["curl_pow"]
           + spec["w_amp"] * np.sin(2 * math.pi * (spec["w_cyc"] * s - t) + spec["w_ph"]) * s ** 0.8)
    ds = spec["length"] / WISP_N
    xs = np.concatenate([[0.0], np.cumsum(np.cos(phi[:-1]) * ds)])
    ys = np.concatenate([[0.0], np.cumsum(np.sin(phi[:-1]) * ds)])
    return ys, xs


def _wisp_fit():
    """One scale and offset for every frame of every tendril, so the wisp fills its cell and never jumps."""
    lo = np.array([1e9, 1e9])
    hi = np.array([-1e9, -1e9])
    for k in range(LOOP_N):
        for spec in WISP_TENDRILS:
            ys, xs = _tendril(spec, k / LOOP_N)
            lo = np.minimum(lo, [ys.min(), xs.min()])
            hi = np.maximum(hi, [ys.max(), xs.max()])
    span = hi - lo
    sy = 2 * 0.87 / float(span[0])
    sx = min(2 * 0.87 / float(span[1]), 1.25 * sy)  # the wisp may be stretched a little sideways to fill its cell
    return (sy, sx), (lo + hi) / 2


def _periodic_noise(a, b, k, fa, fb, octaves, seed, flow=1):
    """Noise over (a, b) that flows along a and boils in time, and is exactly the same at k = 16 as at k = 0."""
    pa, pz = 6, 3
    t = k / LOOP_N
    n = N.fbm3(a * fa + pa * flow * t, b * fb + 4.7, np.full_like(a, pz * t), octaves=octaves, seed=seed,
               period=(pa, None, pz), time_scales=False)
    return np.clip(n * 1.7, -1.0, 1.0)


@texture
def VfxEnergyWisp(cell=256, grid=4, seed=1001):
    """A curling wisp of light, a loop: a tall main tendril that sways in an S and winds into a spiral at its tip and two
    thinner ones beside it. A wave runs up them all and the edge frays into beads that flow toward the tip. White-hot
    thread, bright body, grey frayed edge. Frame 16 runs into frame 1."""
    scale, centre = _wisp_fit()
    y, x = D.grid(cell * SS)
    cells = []
    for k in range(grid * grid):
        t = k / LOOP_N
        best_g = np.full_like(x, -9.0)
        best_v = np.zeros_like(x)
        for spec in WISP_TENDRILS:
            ys, xs = _tendril(spec, t)
            ys, xs = (ys - centre[0]) * scale[0], (xs - centre[1]) * scale[1]
            d = np.full_like(x, 9.0)
            sd = np.zeros_like(x)  # the signed offset from the spine (which side of it), so the fibres are not mirrored
            s_at = np.zeros_like(x)
            for i in range(WISP_N - 1):
                dd, tl = D.segment(y, x, ys[i], xs[i], ys[i + 1], xs[i + 1])
                sn = (i + tl) / (WISP_N - 1)
                m = dd < d
                dy_, dx_ = ys[i + 1] - ys[i], xs[i + 1] - xs[i]
                side = np.sign((y - ys[i]) * dx_ - (x - xs[i]) * dy_)
                d = np.where(m, dd, d)
                sd = np.where(m, side * dd, sd)
                s_at = np.where(m, sn, s_at)
            w = spec["w0"] * taper(s_at, 0.3, 0.5) * (0.85 + 0.15 * np.sin(2 * math.pi * (2 * s_at - t))) + 0.004
            q = d / w
            f = np.clip(1 - np.minimum(q, 1.25) / 1.25, 0, 1) ** 1.1
            a_len = s_at * spec["length"]
            nf = _periodic_noise(a_len, sd, k, 1.3, 11.0, 4, seed + spec["seed"])  # fibres that run along the wisp
            nb = _periodic_noise(a_len, sd, k, 4.5, 3.0, 3, seed + spec["seed"] + 20, flow=2)  # beads across it
            amp_s = 0.55 + 0.45 * sstep(0.25, 1.0, s_at)
            fray = amp_s * (0.5 - 0.5 * (0.7 * nf + 0.3 * nb)) * (0.2 + 0.8 * sstep(0.0, 0.6, q) + 0.4 * sstep(0.6, 1.0, s_at))
            g = f - 1.8 * fray
            pulse = 0.82 + 0.18 * np.sin(2 * math.pi * (2.5 * s_at - t) + spec["seed"])
            v = (0.3 + 0.7 * sstep(0.05, 0.85, g)) * pulse
            v = np.maximum(v, sstep(0.6, 0.9, g))
            take = g > best_g
            best_v = np.where(take, v, best_v)
            best_g = np.where(take, g, best_g)
        alpha = np.clip(best_g / 0.14, 0, 1) * window(x, y)
        cells.append(D.resize(D.rgba(np.clip(best_v, 0, 1), alpha), cell, cell))
        sys.stdout.write(".")
        sys.stdout.flush()
    sys.stdout.write("\n")
    return D.bleed(D.sheet(cells, grid))


# ---------------------------------------------------------------------------------------------------------------------
# build and look
# ---------------------------------------------------------------------------------------------------------------------


NAMES = ["VfxSlashA", "VfxSlashB", "VfxArc", "VfxEnergyWisp"]


def build(names=None):
    for name in names or NAMES:
        if name not in BUILDERS:
            continue
        sys.stdout.write(name + " ")
        img = BUILDERS[name]()
        path = D.write_png(os.path.join(TEXTURES, name + ".png"), img)
        print("[tex_slash]", path, img.shape)


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
    print("[tex_slash preview]", p)
    return p


def strip(name, outdir, picks=(0, 1, 3, 6, 9, 11, 13, 15), tint=(1.0, 0.7, 0.35)):
    """Chosen frames at full cell size, side by side, over dark (added) with a light-backdrop row (laid over): to look
    at the detail. Written to `outdir` (the session's scratch, not the repo)."""
    img = D.read_png(os.path.join(TEXTURES, name + ".png"))
    ch = img.shape[0] // 4
    cells = []
    for n in picks:
        r, c = divmod(n, 4)
        cells.append(img[r * ch:(r + 1) * ch, c * ch:(c + 1) * ch])
    half = len(cells) // 2
    rows = []
    for part in (cells[:half], cells[half:]):
        row = np.concatenate(part, axis=1)
        rows.append(np.concatenate([_panel(row, tint, (0.07, 0.07, 0.085), False),
                                    _panel(row, tint, (0.82, 0.82, 0.8), True)], axis=0))
    m = np.concatenate(rows, axis=0)
    m = np.concatenate([m, np.ones(m.shape[:2] + (1,))], axis=-1)
    p = D.write_png(os.path.join(outdir, name + "_strip.png"), m)
    print("[tex_slash strip]", p)
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
