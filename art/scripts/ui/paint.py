"""A small painter for the game's drawn pictures, numpy only: shapes filled with sixteen-fold anti-aliasing (scanline
coverage, four rows a pixel and exact spans across), tapered strokes along curves, soft gaussian blurs, value noise,
and layers composited over each other. Coordinates are pixels, x right, y down.

    canvas = np.zeros((h, w, 3), np.float32)
    mask = fill([(x, y), ...], w, h)          # coverage 0..1, the canvas's size
    over(canvas, colour_or_image, mask * 0.8)
"""

import math

import numpy as np

ROWS = 4  # sub-rows a pixel


def fill(points, w, h, bbox_pad=2):
    """Coverage (h, w) of the polygon `points` [(x, y)] (even-odd), anti-aliased."""
    pts = np.asarray(points, np.float64)
    if len(pts) < 3:
        return np.zeros((h, w), np.float32)
    x0 = max(0, int(math.floor(pts[:, 0].min())) - bbox_pad)
    x1 = min(w, int(math.ceil(pts[:, 0].max())) + bbox_pad)
    y0 = max(0, int(math.floor(pts[:, 1].min())) - bbox_pad)
    y1 = min(h, int(math.ceil(pts[:, 1].max())) + bbox_pad)
    out = np.zeros((h, w), np.float32)
    if x1 <= x0 or y1 <= y0:
        return out
    a = pts
    b = np.roll(pts, -1, axis=0)
    ax, ay, bx, by = a[:, 0], a[:, 1], b[:, 0], b[:, 1]
    width = x1 - x0
    cover = np.zeros((y1 - y0, width + 1), np.float64)
    for row in range(y1 - y0):
        acc = np.zeros(width + 1, np.float64)
        for sub in range(ROWS):
            y = y0 + row + (sub + 0.5) / ROWS
            crosses = (ay <= y) != (by <= y)
            if not crosses.any():
                continue
            t = (y - ay[crosses]) / (by[crosses] - ay[crosses])
            xs = np.sort(ax[crosses] + t * (bx[crosses] - ax[crosses])) - x0
            for k in range(0, len(xs) - 1, 2):
                xa, xb = max(0.0, xs[k]), min(float(width), xs[k + 1])
                if xb <= xa:
                    continue
                ia, ib = int(xa), int(xb)
                if ia == ib:
                    acc[ia] += xb - xa
                else:
                    acc[ia] += (ia + 1) - xa
                    acc[ia + 1 : ib] += 1.0
                    acc[ib] += xb - ib
        cover[row] = acc / ROWS
    out[y0:y1, x0:x1] = np.clip(cover[:, :width], 0, 1)
    return out


def bezier(p0, p1, p2, p3, n=40):
    """n + 1 points along a cubic curve."""
    t = np.linspace(0.0, 1.0, n + 1)[:, None]
    p0, p1, p2, p3 = (np.asarray(p, np.float64) for p in (p0, p1, p2, p3))
    pts = (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3
    return [tuple(p) for p in pts]


def quad(p0, p1, p2, n=30):
    """n + 1 points along a quadratic curve."""
    t = np.linspace(0.0, 1.0, n + 1)[:, None]
    p0, p1, p2 = (np.asarray(p, np.float64) for p in (p0, p1, p2))
    pts = (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t ** 2 * p2
    return [tuple(p) for p in pts]


def outline(points, widths):
    """The outline of a stroke along `points` with a width at each point (0 makes a point): a polygon."""
    pts = np.asarray(points, np.float64)
    ws = np.asarray(widths, np.float64)
    n = len(pts)
    left, right = [], []
    for i in range(n):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        d = b - a
        length = math.hypot(d[0], d[1]) or 1.0
        normal = np.array([-d[1], d[0]]) / length
        half = ws[i] / 2
        left.append(tuple(pts[i] + normal * half))
        right.append(tuple(pts[i] - normal * half))
    return left + right[::-1]


def taper(n, base, tip=0.0, power=1.0, start=None):
    """Widths for a stroke of n points: `start` at its first point (default `base`), swelling to `base`, `tip` at its
    end; `power` shapes how late it thins."""
    t = np.linspace(0.0, 1.0, n)
    begin = base if start is None else start
    body = begin + (base - begin) * np.clip(t * 5, 0, 1)
    return list(body * (1 - t ** power) + tip * t ** power)


def stroke(points, widths, w, h):
    return fill(outline(points, widths), w, h)


def ellipse(cx, cy, rx, ry, w, h, angle=0.0, n=96):
    c, s = math.cos(angle), math.sin(angle)
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        x, y = math.cos(a) * rx, math.sin(a) * ry
        pts.append((cx + x * c - y * s, cy + x * s + y * c))
    return fill(pts, w, h)


def _box(a, r, axis):
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    p = np.pad(a, pad, mode="edge")
    c = np.cumsum(p, axis=axis, dtype=np.float64)
    hi = np.take(c, np.arange(2 * r + 1, c.shape[axis]), axis=axis)
    lo = np.take(c, np.arange(0, c.shape[axis] - 2 * r - 1), axis=axis)
    return ((hi - lo) / (2 * r + 1)).astype(np.float32)


def blur(a, sigma):
    """A gaussian blur of `sigma` px (three box passes each way)."""
    if sigma <= 0.3:
        return a
    r = max(1, int(round(math.sqrt(12 * sigma * sigma / 3 + 1) / 2)))
    out = a.astype(np.float32)
    for axis in (0, 1):
        for _ in range(3):
            out = _box(out, r, axis)
    return out


def noise(h, w, cell, seed, octaves=3):
    """Smooth value noise in 0..1, features about `cell` px."""
    rng = np.random.default_rng(seed)
    total = np.zeros((h, w), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        c = max(2, cell / (2 ** o))
        gh, gw = int(h / c) + 3, int(w / c) + 3
        grid = rng.random((gh, gw)).astype(np.float32)
        ys = np.linspace(0, h / c, h, dtype=np.float32)
        xs = np.linspace(0, w / c, w, dtype=np.float32)
        yi, xi = ys.astype(int), xs.astype(int)
        fy, fx = ys - yi, xs - xi
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        g00 = grid[yi][:, xi]
        g01 = grid[yi][:, xi + 1]
        g10 = grid[yi + 1][:, xi]
        g11 = grid[yi + 1][:, xi + 1]
        top = g00 + (g01 - g00) * fx[None, :]
        bottom = g10 + (g11 - g10) * fx[None, :]
        total += amp * (top + (bottom - top) * fy[:, None])
        norm += amp
        amp *= 0.5
    return total / norm


def over(canvas, colour, alpha):
    """Paints `colour` (an (r, g, b) or an (h, w, 3) image) over `canvas` with coverage `alpha` (h, w), in place."""
    a = np.clip(alpha, 0, 1)[..., None]
    col = np.asarray(colour, np.float32)
    canvas *= 1 - a
    canvas += a * col
    return canvas


def layer_over(rgb, alpha, colour, cover):
    """Paints onto a layer with its own alpha (both in place): premultiplied-free 'over'."""
    a = np.clip(cover, 0, 1)
    col = np.asarray(colour, np.float32)
    new_alpha = a + alpha * (1 - a)
    safe = np.where(new_alpha > 1e-6, new_alpha, 1.0)
    rgb[:] = (col * a[..., None] + rgb * (alpha * (1 - a))[..., None]) / safe[..., None]
    alpha[:] = new_alpha
    return rgb, alpha


def grid(h, w):
    """Pixel centre coordinates (y, x), each (h, w)."""
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    return ys + 0.5, xs + 0.5


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
