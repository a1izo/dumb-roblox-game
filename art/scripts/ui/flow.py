"""Tools for painting after a pencil sketch, numpy only: resampling, a mask's growing and shrinking, the direction of the
strokes at every pixel (the structure tensor) and line-integral convolution along them (a texture smeared along the
strokes, as hair is). Arrays are (h, w), coordinates pixels, x right, y down.
"""

import math

import numpy as np

import paint as pt


def resample(img, h, w):
    """`img` (h0, w0[, c]) stretched to (h, w), bilinear."""
    h0, w0 = img.shape[:2]
    ys = (np.arange(h) + 0.5) * h0 / h - 0.5
    xs = (np.arange(w) + 0.5) * w0 / w - 0.5
    y0 = np.clip(np.floor(ys).astype(int), 0, h0 - 1)
    x0 = np.clip(np.floor(xs).astype(int), 0, w0 - 1)
    y1 = np.clip(y0 + 1, 0, h0 - 1)
    x1 = np.clip(x0 + 1, 0, w0 - 1)
    fy = np.clip(ys - y0, 0, 1).astype(np.float32)
    fx = np.clip(xs - x0, 0, 1).astype(np.float32)
    if img.ndim == 3:
        fy, fx = fy[:, None, None], fx[None, :, None]
    else:
        fy, fx = fy[:, None], fx[None, :]
    top = img[y0][:, x0] * (1 - fx) + img[y0][:, x1] * fx
    bottom = img[y1][:, x0] * (1 - fx) + img[y1][:, x1] * fx
    return (top * (1 - fy) + bottom * fy).astype(np.float32)


def _disc(r):
    return [(dx, dy) for dy in range(-r, r + 1) for dx in range(-r, r + 1) if dx * dx + dy * dy <= r * r + r]


def grow(mask, r):
    """The mask dilated by a disc of radius `r` px (its maximum over the disc)."""
    if r < 1:
        return mask
    h, w = mask.shape
    pad = np.pad(mask, r, mode="edge")
    out = mask.copy()
    for dx, dy in _disc(r):
        np.maximum(out, pad[r + dy: r + dy + h, r + dx: r + dx + w], out=out)
    return out


def shrink(mask, r):
    return 1 - grow(1 - mask, r)


def close(mask, r):
    """Gaps narrower than about 2r filled, the outline otherwise kept."""
    return shrink(grow(mask, r), r)


def joined(mask, core, limit=600):
    """What of `mask` (bool) is joined to `core` (bool, inside it): `core` grown a pixel at a time within it."""
    have = core & mask
    for _ in range(limit):
        grown = have.copy()
        grown[1:] |= have[:-1]
        grown[:-1] |= have[1:]
        grown[:, 1:] |= have[:, :-1]
        grown[:, :-1] |= have[:, 1:]
        grown &= mask
        if (grown == have).all():
            break
        have = grown
    return have


def orientation(dark, sigma=1.2, spread=7.0):
    """The strokes' direction at every pixel, (cos, sin), from the structure tensor of `dark`, and how sure it is
    (0 none, 1 clean parallel strokes)."""
    d = pt.blur(dark, sigma)
    gy, gx = np.gradient(d)
    jxx = pt.blur(gx * gx, spread)
    jxy = pt.blur(gx * gy, spread)
    jyy = pt.blur(gy * gy, spread)
    # (the gradient's own direction, turned a right angle: the strokes run across it)
    phi = 0.5 * np.arctan2(2 * jxy, jxx - jyy) + math.pi / 2
    root = np.sqrt((jxx - jyy) ** 2 + 4 * jxy * jxy)
    sure = root / np.maximum(jxx + jyy, 1e-9)
    return np.cos(phi).astype(np.float32), np.sin(phi).astype(np.float32), sure.astype(np.float32)


def _sample(img, x, y):
    h, w = img.shape
    x = np.clip(x, 0, w - 1.001)
    y = np.clip(y, 0, h - 1.001)
    x0 = x.astype(np.int32)
    y0 = y.astype(np.int32)
    fx = x - x0
    fy = y - y0
    a = img[y0, x0]
    b = img[y0, x0 + 1]
    c = img[y0 + 1, x0]
    d = img[y0 + 1, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def lic(tex, vx, vy, length, step=1.0):
    """`tex` smeared along the field (vx, vy) over `length` px each way, the far samples weighing less (line-integral
    convolution; the field's sign is free, each step keeps the way it was going)."""
    h, w = tex.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    total = tex.astype(np.float32).copy()
    weight = np.ones_like(total)
    n = int(length / step)
    for sign in (1.0, -1.0):
        x, y = xs.copy(), ys.copy()
        px = vx * sign
        py = vy * sign
        for k in range(1, n + 1):
            dx = _sample(vx, x, y)
            dy = _sample(vy, x, y)
            flip = np.where(dx * px + dy * py < 0, -1.0, 1.0).astype(np.float32)
            dx *= flip
            dy *= flip
            x = x + dx * step
            y = y + dy * step
            px, py = dx, dy
            wgt = 1.0 - (k / (n + 1)) ** 2
            total += _sample(tex, x, y) * wgt
            weight += wgt
    return total / weight
