"""Ticket V1.5 of docs/handoff/vfx-rework-plan-2026-11-16.md: the MATTER textures. Matter is laid over (not added): lit from
above, shadowed below, white and grey so the game tints it, with real value (a lit side, a mid body, a shadowed side or
edge). They must read in a lit room, so none of them is a glow. Route E (numpy with noise.py); the tumbling ones turn a
flat shape in 3D (a rotation matrix, orthographic) and shade it by which way it faces.

    VfxAshFlakes      4x4 loop     a flake of ash tumbling: crumbled edge, char patches, a lit side and a dark one
    VfxShards         4x4 random   sixteen standalone chunks: eight of stone, eight of glass, with shaded faces
    VfxPaper          4x4 loop     a page tumbling: a front with faint ruled lines and scribbles, a blank back
    VfxFeatherTumble  4x4 loop     a black feather turning: dark barbs, a lit rim, a shining shaft, a quill

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/vfx/tex_matter.py [names]
        [--preview OUTDIR]       (numpy only; writes art/export/textures/<name>.png, and with --preview the pictures
                                 that show each sheet laid over dark and over light, in two tints, and a strip of frames)

TEX_QUICK=1 draws at 1x (fast, rough: for looking at shapes, never for the final PNGs).

Every sheet is 1024 x 1024 (a frame is a 256 px cell); the subject stays 4 px or more off every edge of its cell. A loop
turns whole (the angles are all whole turns or sines of 2 pi t), so frame 16 runs into frame 1. The helpers are this
file's own copies (tex_slash.py, tex_impact.py, textures.py, draw.py and noise.py are not edited by this ticket).
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
SS = 1 if QUICK else 2  # supersampling for the tumblers (drawn at SS x the cell and boxed down)
SS_SHARDS = 1 if QUICK else 3
SAFE = 0.962  # nothing is drawn past this (the cell runs -1..1; 4 px is 0.031)
FIT = 0.93  # the subject's union over all frames reaches this far (the plan: 80% of the cell and more)
LOOP_N = 16

LIGHT = np.array([-0.38, -0.62, 0.68])  # towards the light: up, a little left, in front of the page (x right, y down, z at us)
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
    """1 inside the safe square, 0 from SAFE outward: no frame ever touches its neighbour."""
    wx = np.clip((SAFE - np.abs(x)) / 0.012, 0, 1)
    wy = np.clip((SAFE - np.abs(y)) / 0.012, 0, 1)
    return wx * wy


def nz2(a, b, f, octaves, seed):
    """Layered 2D noise, about -1..1."""
    return np.clip(N.fbm2(a * f + 7.1, b * f + 3.3, octaves=octaves, seed=seed) * 1.7, -1.0, 1.0)


def hash1(i, seed=0):
    """A repeatable pseudo-random 0..1 for integer-valued float arrays."""
    s = np.sin(i * 12.9898 + seed * 78.233) * 43758.5453
    return s - np.floor(s)


def rx(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def plane_map(x, y, R, min_nz):
    """For a flat shape turned by R (local axes: u right, v down, w at the viewer) and seen from the front (orthographic):
    the local (u, v) under each screen pixel. When the shape is edge-on, nz is held to +-min_nz so it stays a thin sliver
    (that is its thickness) instead of dividing by nothing."""
    n = R[:, 2]
    nz = float(n[2])
    nzc = nz if abs(nz) >= min_nz else (min_nz if nz >= 0 else -min_nz)
    z = -(n[0] * x + n[1] * y) / nzc
    u = R[0, 0] * x + R[1, 0] * y + R[2, 0] * z
    v = R[0, 1] * x + R[1, 1] * y + R[2, 1] * z
    return u, v


def world_normal(R, px, py):
    """The surface normal facing the viewer, for a local normal (px, py, 1) (a bend or a crinkle), as (x, y, z)."""
    nl = 1.0 / np.sqrt(px * px + py * py + 1.0)
    lx, ly, lz = px * nl, py * nl, nl
    wx = R[0, 0] * lx + R[0, 1] * ly + R[0, 2] * lz
    wy = R[1, 0] * lx + R[1, 1] * ly + R[1, 2] * lz
    wz = R[2, 0] * lx + R[2, 1] * ly + R[2, 2] * lz
    s = 1.0 if R[2, 2] >= 0 else -1.0
    return wx * s, wy * s, wz * s


def lambert(nx, ny, nzv):
    return nx * LIGHT[0] + ny * LIGHT[1] + nzv * LIGHT[2]


def rim_terms(m, w):
    """Edge light for a shape whose margin is m (positive inside, in the shape's own units): (band, toward). band is 1 at the
    edge and 0 by w inside it; toward is how much the edge faces the light on the screen (+1 up and left, -1 down and
    right), from the screen-space outward direction of the shape."""
    mc = np.clip(m, -0.3, 0.3)
    gy, gx = np.gradient(mc)
    ln = np.hypot(gx, gy) + 1e-9
    ox, oy = -gx / ln, -gy / ln
    lxy = math.hypot(LIGHT[0], LIGHT[1])
    toward = (ox * LIGHT[0] + oy * LIGHT[1]) / lxy
    band = 1.0 - sstep(0.0, w, m)
    return band, toward


def finish_cells(frames_fn, count, cell, grid, ss):
    """Draws `count` frames with frames_fn(k, y, x) -> (value, alpha) at ss x the cell, boxes them to `cell` and lays them
    out left to right, top to bottom."""
    y, x = D.grid(cell * ss)
    cells = []
    for k in range(count):
        v, a = frames_fn(k, y, x)
        img = D.rgba(v, a)
        cells.append(D.resize(img, cell, cell) if ss > 1 else img)
        sys.stdout.write(".")
        sys.stdout.flush()
    sys.stdout.write("\n")
    return D.bleed(D.sheet(cells, grid))


def fit_loop(raw_frame, count):
    """One scale and centre for a whole loop (a tumbling thing never jumps or rescales): the union of every frame's
    shape reaches FIT in one direction. raw_frame(k, y, x, pw) is drawn in the shape's own units; this returns
    (scale, cy, cx): raw = screen * scale + centre."""
    y, x = D.grid(200, span=2.2)
    lo = np.array([9.0, 9.0])
    hi = np.array([-9.0, -9.0])
    for k in range(count):
        _, a = raw_frame(k, y, x, 0.02)
        ys, xs = np.nonzero(a > 0.2)
        if len(ys) == 0:
            continue
        lo = np.minimum(lo, [y[ys, xs].min(), x[ys, xs].min()])
        hi = np.maximum(hi, [y[ys, xs].max(), x[ys, xs].max()])
    c = (lo + hi) / 2
    half = float(max(hi[0] - lo[0], hi[1] - lo[1])) / 2 + 0.012  # a pixel or so for the soft edge
    return half / FIT, float(c[0]), float(c[1])


def tumble_sheet(raw_frame, cell=256, grid=4):
    count = grid * grid
    scale, cy, cx = fit_loop(raw_frame, count)

    def frame(k, y, x):
        pw = D.px(y.shape[0]) * scale * 1.1
        v, a = raw_frame(k, y * scale + cy, x * scale + cx, pw)
        return v, a * window(x, y)

    return finish_cells(frame, count, cell, grid, SS)


# ---------------------------------------------------------------------------------------------------------------------
# VfxPaper: a page tumbling. A front with faint ruled lines and a few lines of scribble (marks, never text), a blank back
# that shows the front's lines faintly through it. A torn top edge, one folded corner, a bend and a crease.
# ---------------------------------------------------------------------------------------------------------------------

PAGE_A, PAGE_B = 0.74, 0.98


def _page_margin(u, v):
    r = np.where(u > 0, np.where(v > 0, 0.03, 0.09), np.where(v > 0, 0.12, 0.05))
    qx = np.abs(u) - (PAGE_A - r)
    qy = np.abs(v) - (PAGE_B - r)
    d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r
    m = -d
    m = np.minimum(m, (PAGE_A + PAGE_B - 0.46 - (u + v)) / math.sqrt(2))  # the folded-off corner (bottom right)
    torn = -PAGE_B + 0.05 * nz2(u * 5.0, np.zeros_like(u), 1.0, 3, 41) + 0.016 * nz2(u * 22.0, np.zeros_like(u), 1.0, 2, 42)
    m = np.minimum(m, v - torn)
    m = m + 0.012 * nz2(u, v, 11.0, 2, 43)
    return m


def _page_marks(u, v):
    """0..1 darkness of the front's marks: faint ruled lines, a margin line and scribbled 'lines of writing' (waves
    with gaps between the words; not letters)."""
    rule_gap = 0.118
    row = (v + 0.62) / rule_gap
    fr = row - np.floor(row)
    ruled = (1 - sstep(0.0, 0.07, np.minimum(fr, 1 - fr))) * sstep(-0.66, -0.6, v) * sstep(0.99, 0.93, v)
    margin = (1 - sstep(0.0, 0.012, np.abs(u + 0.5))) * 0.8
    marks = np.zeros_like(u)
    j = np.floor(row)
    rng = np.random.default_rng(77)
    for jj in range(1, 8):
        yv = -0.62 + rule_gap * jj - 0.034  # the scribble rides just above each line
        length = rng.uniform(0.62, 1.1)  # rows end at their own place
        ph = rng.uniform(0, 6.28, 3)
        f1, f2 = rng.uniform(11, 15), rng.uniform(23, 31)
        wob = 0.019 * np.sin(2 * math.pi * f1 * u + ph[0]) + 0.011 * np.sin(2 * math.pi * f2 * u + ph[1])
        d = np.abs(v - yv - wob * (0.6 + 0.4 * np.sin(2 * math.pi * 3.0 * u + ph[2])))
        stroke = 1 - sstep(0.0, 0.0085, d)
        words = sstep(-0.55, -0.25, nz2(u * 3.6 + jj * 1.7, np.full_like(u, jj * 2.3), 1.0, 2, 50 + jj))
        inside = sstep(-0.42, -0.4, u) * sstep(-0.42 + length, -0.42 + length - 0.04, u)
        marks = np.maximum(marks, stroke * words * inside * (0.78 + 0.22 * jj % 2))
    # a heavier first line (a heading) with a rough underline
    head = np.abs(v + 0.5 - 0.028 * np.sin(2 * math.pi * 7.0 * u + 1.0))
    marks = np.maximum(marks, (1 - sstep(0.0, 0.014, head)) * sstep(-0.4, -0.37, u) * sstep(0.2, 0.17, u) * 0.9)
    under = np.abs(v + 0.4 - 0.01 * np.sin(2 * math.pi * 3.0 * u))
    marks = np.maximum(marks, (1 - sstep(0.0, 0.006, under)) * sstep(-0.4, -0.37, u) * sstep(0.26, 0.23, u) * 0.7)
    return np.clip(np.maximum(marks, np.maximum(ruled * 0.46, margin * 0.5)), 0, 1), ruled


def _paper_frame(k, y, x, pw):
    t = k / LOOP_N
    a = 2 * math.pi * t + 0.42 + 0.3 * math.sin(2 * math.pi * t + 0.8)  # the flip: not an even speed
    R = rz(0.32 * math.sin(2 * math.pi * t + 1.0) + 0.22) @ rx(0.5 * math.sin(2 * math.pi * t + 0.4)) @ ry(a)
    u, v = plane_map(x, y, R, 0.07)
    m = _page_margin(u, v)
    # bend and a crease (a light/dark split along it)
    px = -0.55 * u + 0.12 * np.sin(3.1 * v + 0.5)
    py = 0.62 * v
    cr = (v - 0.32 * u - 0.12) / 1.05
    px = px + 0.34 * np.tanh(cr * 26.0) * (1 - sstep(0.0, 0.5, np.abs(cr))) * -0.7
    py = py + 0.34 * np.tanh(cr * 26.0) * (1 - sstep(0.0, 0.5, np.abs(cr))) * 0.7
    nx, ny, nzv = world_normal(R, px, py)
    lam = lambert(nx, ny, nzv)
    marks, ruled = _page_marks(u, v)
    grain = nz2(u, v, 70.0, 2, 61)
    fibre = nz2(u, v * 0.25, 18.0, 2, 62)
    front = 0.95 - 0.05 * sstep(0.0, 0.5, fibre) + 0.012 * grain
    front = front * (1 - 0.82 * marks)
    stain = nz2(u + 4.0, v - 3.0, 2.4, 3, 63)
    back = 0.74 + 0.07 * fibre + 0.02 * grain + 0.15 * stain
    back = back * (1 - 0.34 * marks)  # the lines show through, faintly
    alb = front if R[2, 2] >= 0 else back
    shade = 0.3 + 0.86 * np.clip(lam, 0, 1) + 0.15 * np.clip(-lam, 0, 1)
    val = alb * shade
    band, toward = rim_terms(m, 0.022)
    val = val + 0.2 * band * np.clip(toward, 0, 1)
    val = val * (1 - 0.35 * band * np.clip(-toward, 0, 1))
    # a soft darkening in the bend's valley and under the crease
    val = val * (1 - 0.12 * np.exp(-((cr + 0.05) / 0.06) ** 2))
    alpha = np.clip(0.5 + m / pw, 0, 1)
    return np.clip(val, 0, 1), alpha


@texture
def VfxPaper(cell=256, grid=4):
    """A page tumbling, a loop: it flips once over and wobbles, so it passes edge-on twice and shows both sides. The front
    is pale with faint ruled lines, a margin line, a heading and lines of scribble; the back is blank, a shade darker, with the
    lines showing through faintly. Torn top edge, folded corner, a bend and a crease; lit from above, shadowed below."""
    return tumble_sheet(_paper_frame, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# VfxAshFlakes: a flake of ash. An uneven chip with a crumbled edge, a hole, bites out of it, dark char patches and pale
# mottle. It turns about a slanted axis and spins in its own plane, so its lit side comes and goes.
# ---------------------------------------------------------------------------------------------------------------------


def _flake_margin(u, v):
    th = np.arctan2(v, u)
    r = np.hypot(u, v)
    rr = 0.84 * (1 + 0.17 * np.sin(2 * th + 1.1) + 0.12 * np.sin(3 * th + 0.4) + 0.07 * np.sin(5 * th + 2.2))
    m = rr - r + 0.11 * nz2(u, v, 2.4, 3, 71) + 0.032 * nz2(u, v, 13.0, 3, 72)
    for ang, dist, rad in ((0.7, 0.84, 0.17), (3.9, 0.8, 0.13), (5.6, 0.9, 0.2)):  # bites taken out of the rim
        bx, by = dist * math.cos(ang), dist * math.sin(ang)
        m = np.minimum(m, np.hypot(u - bx, v - by) - rad + 0.04 * nz2(u, v, 9.0, 2, 73))
    m = np.minimum(m, np.hypot(u + 0.18, v - 0.22) - 0.085 + 0.02 * nz2(u, v, 11.0, 2, 74))  # a hole
    return m


def _flake_frame(k, y, x, pw):
    t = k / LOOP_N
    a = 2 * math.pi * t + 0.5 + 0.35 * math.sin(2 * math.pi * t + 0.3)
    R = (rz(0.7 + 0.45 * math.sin(2 * math.pi * t + 0.6)) @ rx(0.55 * math.sin(2 * math.pi * t + 2.0)) @ ry(a)
         @ rz(-2 * math.pi * t))
    u, v = plane_map(x, y, R, 0.16)
    m = _flake_margin(u, v)
    # a cupped, crinkled surface: bend plus the slope of a noise
    e = 0.02
    nc = nz2(u, v, 3.2, 3, 75)
    gx = (nz2(u + e, v, 3.2, 3, 75) - nc) / e
    gy = (nz2(u, v + e, 3.2, 3, 75) - nc) / e
    px = -1.1 * u + 0.2 * gx
    py = -0.8 * v + 0.2 * gy
    nx, ny, nzv = world_normal(R, px, py)
    lam = lambert(nx, ny, nzv)
    mottle = nz2(u, v, 3.6, 4, 76)
    char = sstep(-0.05, -0.4, nz2(u + 3.0, v - 2.0, 2.2, 3, 77))  # dark burnt patches
    speck = nz2(u, v, 40.0, 2, 78)
    fibre = nz2(u * 0.5, v * 3.0, 14.0, 2, 79)
    front = 0.78 + 0.13 * mottle + 0.05 * speck + 0.04 * fibre
    front = front * (1 - 0.7 * char)
    back = (0.5 + 0.2 * nz2(u + 5.0, v + 1.0, 3.2, 4, 80) + 0.06 * speck) * (1 - 0.5 * sstep(-0.1, -0.5, nz2(u, v, 4.0, 3, 81)))
    alb = front if R[2, 2] >= 0 else back
    alb = alb * (0.74 + 0.26 * sstep(0.0, 0.1, m))  # the crumbling rim is a little darker
    shade = 0.4 + 0.74 * np.clip(lam, 0, 1) + 0.3 * np.clip(-lam, 0, 1)
    val = alb * shade
    band, toward = rim_terms(m, 0.05)
    val = val + 0.34 * band * np.clip(toward, 0, 1)
    val = val * (1 - 0.4 * band * np.clip(-toward, 0, 1))
    alpha = np.clip(0.5 + m / pw, 0, 1)
    return np.clip(val, 0, 1), alpha


@texture
def VfxAshFlakes(cell=256, grid=4):
    """One flake of ash tumbling, a loop (the remake of VfxAsh at 256 px cells): an uneven chip with a crumbled rim, bites out
    of it, a hole, pale mottle and dark char patches, cupped and crinkled. It turns about a slanted axis while spinning in its
    own plane, so a lit pale face, a dark grey back and a thin edge-on sliver follow each other; lit from above."""
    return tumble_sheet(_flake_frame, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# VfxFeatherTumble: a black feather turning about its length. Vane wider on one side than the other, barbs that sweep to the
# tip and end at their own places (a ragged serrated edge, strands at the rim, a split), a shining shaft, a bare quill.
# ---------------------------------------------------------------------------------------------------------------------

BARBS = 15.0  # barbs per unit of length


def _feather_fields(u, v):
    """(m, du, side, t_edge, frac, sc): the margin of the feather (positive inside, in the shape's units), the offset from
    the shaft, which side, how far out to the vane's edge (0 at the shaft, 1 at the rim), the barb's fraction and the
    feather's own length coordinate (0 at the tip, 1 at the end of the vane)."""
    s = (v + 1.0) / 1.62
    sc = np.clip(s, 0, 1)
    c = 0.07 * np.sin(2.2 * v + 0.5) + 0.09 * v * v - 0.02  # the shaft curves
    du = u - c
    left = du < 0
    side = np.where(left, -1.0, 1.0)
    W = np.where(left, 0.46, 0.27)
    prof = np.sin(np.pi * sc ** 0.6) ** 0.8
    b = (v + 0.95 * np.abs(du)) * BARBS
    ib = np.floor(b)
    frac = b - ib
    rnd = hash1(ib, 3.0) * (side > 0) + hash1(ib, 7.0) * (side < 0)
    w = W * prof * (0.8 + 0.2 * rnd)  # barbs end at their own places: a serrated rim
    # a notch where the barbs have come apart (a split)
    split = np.exp(-((b - (4.2 + 0.0) * 1.0 - 11.0) / 1.0) ** 2) * (side < 0)
    w = w * (1 - 0.65 * split * sstep(0.2, 0.5, np.abs(du) / np.maximum(W * prof, 1e-3)))
    m_vane = w - np.abs(du)
    m_vane = np.where((s < 0) | (s > 1.02), -1.0, m_vane)
    t_edge = np.abs(du) / np.maximum(w, 1e-3)
    return m_vane, du, side, t_edge, frac, sc, c, s


def _feather_frame(k, y, x, pw):
    t = k / LOOP_N
    a = 2 * math.pi * t + 0.3 + 0.28 * math.sin(2 * math.pi * t + 0.2)  # it turns about its length
    R = (rz(0.74 + 0.2 * math.sin(2 * math.pi * t + 1.3)) @ rx(0.3 * math.sin(2 * math.pi * t + 0.6)) @ ry(a))
    u, v = plane_map(x, y, R, 0.1)
    m_vane, du, side, t_edge, frac, sc, c, s = _feather_fields(u, v)
    pb = np.abs(frac - 0.5) * 2  # 0 at a barb's middle, 1 in the gap between two
    gap_w = 0.82 * sstep(0.55, 1.0, t_edge) + 0.4 * sstep(0.2, 0.62, v)  # strands at the rim and in the fluffy base
    m_barb = 0.04 + (1 - np.clip(gap_w, 0, 0.9) - pb) * 0.1
    m_vane = np.minimum(m_vane, np.where(t_edge > 0.5, m_barb, 9.0)) + 0.004 * nz2(u, v, 30.0, 1, 91)
    # the tip is soft and a little ragged
    m_vane = np.where(v < -0.9, m_vane - (-0.9 - v) * 0.1, m_vane)
    # the bare quill
    wq = 0.026
    m_q = np.minimum(wq - np.abs(du), np.minimum(0.98 - v, (v - 0.44) / 1.5 + 0.05))
    m_q = np.minimum(m_q, 0.04 + 0 * v)
    m = np.maximum(m_vane, m_q)
    in_q = (m_q > m_vane) & (m_q > 0)
    # the surface: a cup across the vane, a crinkle, and which way the barbs lie
    nc = nz2(u, v, 6.0, 2, 92)
    px = 0.8 * du * 1.0 + 0.1 * (nz2(u + 0.02, v, 6.0, 2, 92) - nc) / 0.02 * 0.2
    py = 0.05 * np.sin(5.0 * v)
    nx, ny, nzv = world_normal(R, px, py)
    lam = lambert(nx, ny, nzv)
    barb_v = 0.45 + 0.55 * (1 - sstep(0.1, 1.0, pb))
    sheen = 0.3 * np.exp(-(((v * 0.55 + du * 1.6) - 0.05) / 0.2) ** 2)
    alb = 0.14 + 0.1 * barb_v + 0.08 * sstep(0.0, 0.4, 1 - t_edge) * barb_v + sheen * barb_v
    alb = alb * (0.85 + 0.15 * nz2(u * 4, v * 0.4, 12.0, 2, 93))
    # the shaft: a thin shining ridge, wide at the base and fine at the tip
    shaft_w = 0.007 + 0.016 * sstep(0.0, 1.0, (v + 1.0) / 1.6)
    ridge = 1 - sstep(0.0, shaft_w, np.abs(du + 0.003))
    alb = np.where(ridge > 0.02, alb * (1 - ridge) + 0.78 * ridge, alb)
    # the quill: a glossy tube, dark with a bright stripe along its lit side
    qs = np.clip(du / wq, -1, 1)
    quill = 0.2 + 0.62 * np.exp(-((qs + 0.45) / 0.22) ** 2)
    alb = np.where(in_q, quill, alb)
    shade = 0.55 + 0.6 * np.clip(lam, 0, 1) + 0.12 * np.clip(-lam, 0, 1)
    val = alb * shade
    band, toward = rim_terms(m, 0.05)
    val = val + 0.5 * band * np.clip(toward, 0, 1) * (0.5 + 0.5 * barb_v)
    val = val * (1 - 0.3 * band * np.clip(-toward, 0, 1))
    alpha = np.clip(0.5 + m / pw, 0, 1)
    return np.clip(val, 0, 1), alpha


@texture
def VfxFeatherTumble(cell=256, grid=4):
    """A black feather turning about its length while it sways, a loop. The vane is wider on one side, its barbs sweep to the
    tip and end at their own places (a serrated rim, strands at the edge, a split), the shaft shines, the quill is a bare dark
    tube; dark barbs with a lit rim on the side that faces the light, a faint sheen across the vane. Passes edge-on twice."""
    return tumble_sheet(_feather_frame, cell, grid)


# ---------------------------------------------------------------------------------------------------------------------
# VfxShards: sixteen standalone chunks, a random sheet (each cell is one piece, not an animation). A piece is a convex body
# made of planes: the nearest plane along each pixel's ray is the face, so every face is flat and shaded by its own normal.
# Eight of stone (a block, a wedge, a pebble, a splinter, a slab, ...) and eight of glass (thin plates with edges at
# angles, slivers and triangles, a bright streak across the broad face, edges that catch light).
# ---------------------------------------------------------------------------------------------------------------------


def _unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def _random_rotation(rng):
    q = rng.normal(size=4)
    q /= np.linalg.norm(q)
    a, b, c, d = q
    return np.array([[a * a + b * b - c * c - d * d, 2 * (b * c - a * d), 2 * (b * d + a * c)],
                     [2 * (b * c + a * d), a * a - b * b + c * c - d * d, 2 * (c * d - a * b)],
                     [2 * (b * d - a * c), 2 * (c * d + a * b), a * a - b * b - c * c + d * d]])


def _stone_planes(rng, kind):
    ext = {"block": (0.9, 0.7, 0.6), "wedge": (1.0, 0.65, 0.5), "pebble": (0.9, 0.8, 0.7), "splinter": (1.0, 0.24, 0.2),
           "slab": (0.95, 0.8, 0.2), "chunk": (0.8, 0.8, 0.7), "flake": (1.0, 0.7, 0.28), "stub": (0.7, 0.5, 0.5)}[kind]
    planes = []
    for ax in range(3):
        for sgn in (1, -1):
            n = np.zeros(3)
            n[ax] = sgn
            n = _unit(n + rng.normal(0, 0.2, 3))
            planes.append((n, ext[ax] * rng.uniform(0.82, 1.0)))
    extra = {"block": 3, "wedge": 4, "pebble": 9, "splinter": 3, "slab": 3, "chunk": 6, "flake": 4, "stub": 5}[kind]
    for _ in range(extra):
        n = _unit(rng.normal(size=3) * np.array([1.0, 1.0, 1.0]))
        d = float(np.sum(np.abs(n) * np.array(ext))) * rng.uniform(0.5, 0.8) if kind != "pebble" else 0.8 * np.mean(ext)
        planes.append((n, d))
    if kind == "splinter":  # a point at one end: two slanting cuts
        planes.append((_unit([1.0, 0.45, 0.1]), 0.8))
        planes.append((_unit([1.0, -0.3, -0.4]), 0.76))
    if kind == "wedge":
        planes.append((_unit([0.2, 0.9, 0.25]), 0.55))
    return planes


def _glass_planes(rng, kind):
    n_pts = {"tri": 3, "sliver": 3, "quad": 4, "penta": 5, "long": 4, "tri2": 3, "tri3": 3, "hook": 4}[kind]
    rx_, ry_ = {"tri": (0.9, 0.8), "sliver": (1.0, 0.2), "quad": (0.85, 0.75), "penta": (0.85, 0.8), "long": (1.0, 0.32),
                "tri2": (0.8, 0.9), "tri3": (1.0, 0.5), "hook": (0.95, 0.4)}[kind]
    ang = np.sort(rng.uniform(0, 2 * math.pi, n_pts))
    # keep them apart enough that no angle gap is over a half turn (a convex polygon that holds the centre)
    gaps = np.diff(np.concatenate([ang, [ang[0] + 2 * math.pi]]))
    if gaps.max() > math.pi * 0.95:
        ang = np.sort(np.linspace(0, 2 * math.pi, n_pts, endpoint=False) + rng.uniform(-0.3, 0.3, n_pts))
    pts = np.stack([rx_ * np.cos(ang) * rng.uniform(0.8, 1.0, n_pts), ry_ * np.sin(ang) * rng.uniform(0.8, 1.0, n_pts)], axis=1)
    thick = {"tri": 0.1, "sliver": 0.07, "quad": 0.12, "penta": 0.09, "long": 0.08, "tri2": 0.11, "tri3": 0.09, "hook": 0.1}[kind]
    tilt = rng.uniform(-0.06, 0.06, 2)
    planes = [(_unit([tilt[0], tilt[1], 1.0]), thick), (_unit([-tilt[0] * 0.6, -tilt[1] * 0.6, -1.0]), thick * rng.uniform(0.7, 1.2))]
    for i in range(n_pts):
        p0, p1 = pts[i], pts[(i + 1) % n_pts]
        e = p1 - p0
        nrm = _unit([e[1], -e[0], 0.0])
        if np.dot(nrm[:2], (p0 + p1) / 2) < 0:
            nrm = -nrm
        nrm = _unit(nrm + np.array([0, 0, rng.uniform(-0.18, 0.18)]))  # edges are not square to the face
        planes.append((nrm, float(np.dot(nrm[:2], p0))))
    if kind in ("quad", "penta", "hook"):  # a chipped corner
        i = int(rng.integers(0, n_pts))
        v = pts[i]
        nrm = _unit([v[0], v[1], rng.uniform(-0.3, 0.3)])
        planes.append((nrm, float(np.linalg.norm(v)) * 0.82))
    return planes


SHARD_KINDS = [  # (material, kind): stone and glass alternate so a neighbouring cell differs
    ("stone", "block"), ("glass", "tri"), ("stone", "wedge"), ("glass", "sliver"),
    ("glass", "quad"), ("stone", "pebble"), ("glass", "penta"), ("stone", "splinter"),
    ("stone", "slab"), ("glass", "long"), ("stone", "chunk"), ("glass", "tri2"),
    ("glass", "tri3"), ("stone", "flake"), ("stone", "stub"), ("glass", "hook"),
]


def _cast(y, x, N_, D_, wob_seed, wob_amp):
    """Ray-casts a convex body of planes n . p <= d along z (the viewer is at +z): (z of the top, z of the bottom, which
    plane is on top, how far the second-nearest bound lies beyond it, the planes' hit mask)."""
    ups = []
    lows = []
    up_idx = []
    for i, (n, d) in enumerate(zip(N_, D_)):
        nzc = n[2] if abs(n[2]) > 1e-3 else (1e-3 if n[2] >= 0 else -1e-3)
        dd = d + wob_amp * nz2(x, y, 3.5, 2, wob_seed + i * 3) if wob_amp else d
        bound = (dd - n[0] * x - n[1] * y) / nzc
        if nzc > 0:
            ups.append(bound.astype(np.float32))
            up_idx.append(i)
        else:
            lows.append(bound.astype(np.float32))
    U = np.stack(ups)
    zlo = np.max(np.stack(lows), axis=0) if lows else np.full(x.shape, -9.0, np.float32)
    order = np.argsort(U, axis=0)
    first = np.take_along_axis(U, order[:1], axis=0)[0]
    second = np.take_along_axis(U, order[1:2], axis=0)[0] if len(ups) > 1 else first + 9
    face = np.array(up_idx)[order[0]]
    return first, zlo, face, second - first


def _shard_cell(i, material, kind, cell, seed):
    rng = np.random.default_rng(seed + i * 101)
    planes = _stone_planes(rng, kind) if material == "stone" else _glass_planes(rng, kind)
    if material == "stone":
        Rm = _random_rotation(rng)
    else:  # a plate is turned so we see its face at a slant and its thickness, never edge-on
        Rm = rx(rng.uniform(-0.95, 0.95)) @ ry(rng.uniform(-0.9, 0.9)) @ rz(rng.uniform(0, 2 * math.pi))
    if kind in ("splinter", "sliver", "long", "flake", "hook", "tri3"):  # thin pieces lie on a diagonal, so they fill the cell
        Rm = rz(rng.choice([-1, 1]) * rng.uniform(0.5, 1.0)) @ Rm
    N_ = np.array([Rm @ n for n, _ in planes])
    D_ = np.array([d for _, d in planes])
    wob = 0.028 if material == "stone" else 0.004
    # fit: the largest this piece is, over the cell
    y0, x0 = D.grid(200, span=1.6)
    zh, zl, _, _ = _cast(y0, x0, N_, D_, 500 + i, wob)
    ys, xs = np.nonzero((zh - zl) > 0.004)
    half = max(y0[ys, xs].max() - y0[ys, xs].min(), x0[ys, xs].max() - x0[ys, xs].min()) / 2 + 0.008
    cy, cx = (y0[ys, xs].max() + y0[ys, xs].min()) / 2, (x0[ys, xs].max() + x0[ys, xs].min()) / 2
    scale = half / FIT
    y, x = D.grid(cell * SS_SHARDS)
    ry_, rx_ = y * scale + cy, x * scale + cx
    zt, zb, face, gap = _cast(ry_, rx_, N_, D_, 500 + i, wob)
    thick = zt - zb
    cover = np.clip(thick / (0.006 * scale / 0.6), 0, 1)
    fn = N_[face]  # the top face's normal at every pixel
    lam = fn[..., 0] * LIGHT[0] + fn[..., 1] * LIGHT[1] + fn[..., 2] * LIGHT[2]
    zc = np.where(np.isfinite(zt), zt, 0)
    if material == "stone":
        gr = nz2(rx_ * 1.0 + face * 7.1, ry_ * 1.0 + zc * 2.0, 5.0, 4, 600 + i)
        spk = nz2(rx_, ry_ + zc, 38.0, 2, 650 + i)
        face_tone = (np.sin(face * 12.9898 + i) * 43758.5453 % 1.0) * 0.16 - 0.08  # each face its own base tone
        alb = 0.62 + face_tone + 0.17 * gr + 0.07 * spk
        # hairline cracks along one or two faces
        rid = N.ridged2(rx_ * 3.0, ry_ * 3.0 + zc * 3.0, octaves=3, seed=700 + i)
        cracks = sstep(0.93, 0.985, rid) * (hash1(face + i * 5, 2.0) > 0.55)
        alb = alb * (1 - 0.5 * cracks)
        shade = 0.4 + 0.7 * np.clip(lam, 0, 1) + 0.07 * np.clip(-lam, 0, 1)
        val = alb * shade
        edge = (1 - sstep(0.0, 0.05 * scale, gap)) * (gap < 8)  # the arris between two front faces catches light
        val = val + 0.2 * edge * np.clip(lam + 0.3, 0, 1)
        band, toward = rim_terms(thick / 0.3, 0.12)
        val = val + 0.12 * band * np.clip(toward, 0, 1)
        val = val * (1 - 0.3 * band * np.clip(-toward, 0, 1))
        alpha = cover
    else:
        big = face < 2
        alb = np.where(big, 0.78, 0.5)
        # a bright streak across the broad face, and a thin second one
        phi = rng.uniform(0.3, 2.6)
        c0 = rng.uniform(-0.25, 0.25)
        pos = (rx_ - cx) * math.cos(phi) + (ry_ - cy) * math.sin(phi)
        streak = np.exp(-((pos - c0 * scale) / (0.11 * scale)) ** 2) * 0.55 + np.exp(-((pos - (c0 + 0.28) * scale) / (0.035 * scale)) ** 2) * 0.35
        shade = 0.34 + 0.8 * np.clip(lam, 0, 1) + 0.06 * np.clip(-lam, 0, 1)
        val = alb * shade + np.where(big, streak, 0.0)
        # darker toward where the glass is thick (seen edge on), bright lines on its arrises
        edge = (1 - sstep(0.0, 0.03 * scale, gap)) * (gap < 8)
        val = val + 0.3 * edge
        band, toward = rim_terms(thick / 0.3, 0.1)
        val = val + 0.35 * band * np.clip(toward, 0, 1)
        val = val * (1 - 0.35 * band * np.clip(-toward, 0, 1))
        alpha = cover * np.where(big, 0.64, 0.96)
        alpha = np.maximum(alpha, cover * np.clip(edge + band * 0.9, 0, 1))
    val = np.where(cover > 0, val, 0.5)
    alpha = alpha * window(x, y)
    img = D.rgba(np.clip(val, 0, 1), alpha)
    return D.resize(img, cell, cell) if SS_SHARDS > 1 else img


@texture
def VfxShards(cell=256, grid=4, seed=1501):
    """Sixteen chunks, a random sheet: each cell is one standalone piece, eight of stone (a block, a wedge, a pebble, a splinter,
    a slab, a chunk, a flake, a stub: flat faces with their own tone, chipped edges, grain and the odd crack) and eight of glass
    (thin plates: triangles, quads, a pentagon, slivers, with angled edges, a bright streak across the broad face, edges that catch the
    light). Lit from above left, shadowed below right; every face is shaded by its own normal."""
    cells = []
    for i, (mat, kind) in enumerate(SHARD_KINDS[: grid * grid]):
        cells.append(_shard_cell(i, mat, kind, cell, seed))
        sys.stdout.write(".")
        sys.stdout.flush()
    sys.stdout.write("\n")
    return D.bleed(D.sheet(cells, grid))


# ---------------------------------------------------------------------------------------------------------------------
# build and look
# ---------------------------------------------------------------------------------------------------------------------

NAMES = ["VfxAshFlakes", "VfxShards", "VfxPaper", "VfxFeatherTumble"]


def build(names=None):
    for name in names or NAMES:
        if name not in BUILDERS:
            continue
        sys.stdout.write(name + " ")
        img = BUILDERS[name]()
        path = D.write_png(os.path.join(TEXTURES, name + ".png"), img)
        print("[tex_matter]", path, img.shape)


TINTS = {"ash": (0.78, 0.74, 0.68), "page": (0.96, 0.9, 0.74), "stone": (0.86, 0.84, 0.8), "cool": (0.6, 0.72, 1.0)}


def _laid(img, tint, back):
    rgb = img[..., :3] * np.array(tint)[None, None, :]
    a = img[..., 3:4]
    return np.ones_like(rgb) * np.array(back)[None, None, :] * (1 - a) + rgb * a


def preview(name, outdir):
    """<outdir>/<name>_look.png: the whole sheet laid over (alpha blended, as matter is) in a 2 x 2: over a dark backdrop and
    over a light one, each in a warm tint and a cool one."""
    img = D.read_png(os.path.join(TEXTURES, name + ".png"))
    warm = TINTS["page"] if name == "VfxPaper" else TINTS["stone"] if name == "VfxShards" else (1.0, 1.0, 1.0)
    cool = TINTS["cool"]
    dark, light = (0.1, 0.1, 0.115), (0.84, 0.84, 0.82)
    tl, tr = _laid(img, warm, dark), _laid(img, cool, dark)
    bl, br = _laid(img, warm, light), _laid(img, cool, light)
    m = np.concatenate([np.concatenate([tl, tr], axis=1), np.concatenate([bl, br], axis=1)], axis=0)
    h, w, _ = m.shape
    m = D.resize(np.concatenate([m, np.ones((h, w, 1))], axis=-1), h // 2, w // 2)
    p = D.write_png(os.path.join(outdir, name + "_look.png"), m)
    print("[tex_matter preview]", p)
    return p


def strip(name, outdir, picks=None, grid=4):
    """Chosen frames at full cell size, side by side: over dark (top) and over light (below), for the detail. Written to
    `outdir` (the session's scratch, not the repo)."""
    img = D.read_png(os.path.join(TEXTURES, name + ".png"))
    ch = img.shape[0] // grid
    picks = picks or (0, 2, 4, 6, 8, 10, 12, 14)
    cells = []
    for n in picks:
        r, c = divmod(n, grid)
        cells.append(img[r * ch:(r + 1) * ch, c * ch:(c + 1) * ch])
    half = len(cells) // 2
    rows = []
    for part in (cells[:half], cells[half:]):
        row = np.concatenate(part, axis=1)
        rows.append(np.concatenate([_laid(row, (1, 1, 1), (0.1, 0.1, 0.115)), _laid(row, (1, 1, 1), (0.84, 0.84, 0.82))], axis=0))
    m = np.concatenate(rows, axis=0)
    m = np.concatenate([m, np.ones(m.shape[:2] + (1,))], axis=-1)
    p = D.write_png(os.path.join(outdir, name + "_strip.png"), m)
    print("[tex_matter strip]", p)
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
