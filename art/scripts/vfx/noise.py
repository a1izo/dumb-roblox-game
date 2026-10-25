"""Gradient (Perlin) noise for the VFX textures, on numpy arrays: 2D and 3D, each axis optionally periodic so a texture
tiles and a flipbook loops (time as the third axis, wrapped), fractal sums of it and domain warps."""

import numpy as np

_TABLES = {}


def _table(seed):
    """A permutation and unit gradients (2D and 3D) for a seed."""
    if seed not in _TABLES:
        rng = np.random.default_rng(seed)
        perm = rng.permutation(256)
        angles = rng.random(256) * 2 * np.pi
        g2 = np.stack([np.cos(angles), np.sin(angles)], axis=-1)
        v = rng.normal(size=(256, 3))
        g3 = v / np.linalg.norm(v, axis=1, keepdims=True)
        _TABLES[seed] = (np.concatenate([perm, perm]), g2, g3)
    return _TABLES[seed]


def _fade(t):
    return t * t * t * (t * (t * 6 - 15) + 10)


def _wrap(i, period):
    return np.mod(i, period) if period else i


def perlin2(x, y, period=(None, None), seed=0):
    """Noise in about [-1, 1] at (x, y); period (px, py) in lattice cells makes it tile."""
    perm, g2, _ = _table(seed)
    x = np.asarray(x, dtype=np.float64)
    y = np.asarray(y, dtype=np.float64)
    xi, yi = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64)
    xf, yf = x - xi, y - yi
    px, py = period
    x0, x1 = _wrap(xi, px) & 255, _wrap(xi + 1, px) & 255
    y0, y1 = _wrap(yi, py) & 255, _wrap(yi + 1, py) & 255

    def grad(ix, iy, dx, dy):
        g = g2[perm[perm[ix] + iy] & 255]
        return g[..., 0] * dx + g[..., 1] * dy

    u, v = _fade(xf), _fade(yf)
    n00 = grad(x0, y0, xf, yf)
    n10 = grad(x1, y0, xf - 1, yf)
    n01 = grad(x0, y1, xf, yf - 1)
    n11 = grad(x1, y1, xf - 1, yf - 1)
    a = n00 + u * (n10 - n00)
    b = n01 + u * (n11 - n01)
    return (a + v * (b - a)) * 1.414


def perlin3(x, y, z, period=(None, None, None), seed=0):
    """Noise in about [-1, 1] at (x, y, z); period (px, py, pz) makes each axis wrap (z for looping time)."""
    perm, _, g3 = _table(seed)
    x = np.asarray(x, dtype=np.float64)
    y = np.asarray(y, dtype=np.float64)
    z = np.asarray(z, dtype=np.float64) + np.zeros_like(x)
    xi, yi, zi = (np.floor(c).astype(np.int64) for c in (x, y, z))
    xf, yf, zf = x - xi, y - yi, z - zi
    px, py, pz = period
    xs = (_wrap(xi, px) & 255, _wrap(xi + 1, px) & 255)
    ys = (_wrap(yi, py) & 255, _wrap(yi + 1, py) & 255)
    zs = (_wrap(zi, pz) & 255, _wrap(zi + 1, pz) & 255)
    u, v, w = _fade(xf), _fade(yf), _fade(zf)

    def grad(ix, iy, iz, dx, dy, dz):
        g = g3[perm[perm[perm[ix] + iy] + iz] & 255]
        return g[..., 0] * dx + g[..., 1] * dy + g[..., 2] * dz

    out = 0.0
    for a in (0, 1):
        for b in (0, 1):
            for c in (0, 1):
                n = grad(xs[a], ys[b], zs[c], xf - a, yf - b, zf - c)
                weight = (u if a else 1 - u) * (v if b else 1 - v) * (w if c else 1 - w)
                out = out + n * weight
    return out * 1.15


def fbm2(x, y, octaves=5, lacunarity=2.0, gain=0.5, period=(None, None), seed=0):
    """A fractal sum of perlin2, normalised to about [-1, 1]; periods double with the octaves (so it still tiles)."""
    total, amp, norm, f = 0.0, 1.0, 0.0, 1.0
    for k in range(octaves):
        p = tuple(int(round(c * f)) if c else None for c in period)
        total = total + amp * perlin2(x * f, y * f, p, seed + k * 17)
        norm += amp
        amp *= gain
        f *= lacunarity
    return total / norm


def fbm3(x, y, z, octaves=5, lacunarity=2.0, gain=0.5, period=(None, None, None), seed=0, time_scales=True):
    """A fractal sum of perlin3. With time_scales False the third axis keeps its rate over the octaves (a loop's
    period stays whole for every octave)."""
    total, amp, norm, f = 0.0, 1.0, 0.0, 1.0
    for k in range(octaves):
        fz = f if time_scales else 1.0
        p = (
            int(round(period[0] * f)) if period[0] else None,
            int(round(period[1] * f)) if period[1] else None,
            int(round(period[2] * fz)) if period[2] else None,
        )
        total = total + amp * perlin3(x * f, y * f, z * fz, p, seed + k * 17)
        norm += amp
        amp *= gain
        f *= lacunarity
    return total / norm


def ridged2(x, y, octaves=5, seed=0, period=(None, None)):
    """Ridged noise in [0, 1]: sharp crests where the noise crosses nought (cracks, veins, lightning-like folds)."""
    total, amp, norm, f = 0.0, 1.0, 0.0, 1.0
    for k in range(octaves):
        p = tuple(int(round(c * f)) if c else None for c in period)
        n = 1.0 - np.abs(perlin2(x * f, y * f, p, seed + k * 31))
        total = total + amp * n * n
        norm += amp
        amp *= 0.5
        f *= 2.0
    return total / norm


def warp2(x, y, strength=1.0, octaves=4, seed=0, period=(None, None)):
    """Coordinates pushed about by noise (a domain warp): curling, flowing shapes from plain noise."""
    qx = fbm2(x + 5.2, y + 1.3, octaves, seed=seed + 101, period=period)
    qy = fbm2(x + 1.7, y + 9.2, octaves, seed=seed + 202, period=period)
    return x + strength * qx, y + strength * qy
