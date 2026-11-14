"""Blood on the lens for the scene deaths (2026-11-14, the user on Walrider's: "make those on screen blood splatters way
more high quality"; they were red bars and pills). Four splats and a drip, drawn the way blood lands on glass: a heavy
core with a ragged edge, arms thrown out from it that thin and break into beads, a spray of fine droplets beyond, a
darker rim where it is thin and a wet light on the thick middle. White-free: the pictures are their own reds, on
transparency. Run with Blender's Python:

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\5.2\\python\\bin\\python.exe" art/scripts/ui/blood_splats.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
import png  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "art", "export", "textures")
N = 1024  # drawn large, written at half size


def noise(rng, n, cells):
    """Smooth value noise in 0..1, `cells` lattice cells across."""
    g = rng.random((cells + 2, cells + 2))
    y, x = np.mgrid[0:n, 0:n] / n * cells
    xi, yi = x.astype(int), y.astype(int)
    xf, yf = x - xi, y - yi
    xf, yf = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
    a, b = g[yi, xi], g[yi, xi + 1]
    c, d = g[yi + 1, xi], g[yi + 1, xi + 1]
    return (a * (1 - xf) + b * xf) * (1 - yf) + (c * (1 - xf) + d * xf) * yf


def field_blob(x, y, cx, cy, r):
    return np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (r * r))


def shade(thick, rng):
    """Thickness (0..1+) to colour and alpha: thin edges darker and a little see-through, the thick middle deep red
    with a wet light on its upper left."""
    alpha = np.clip((thick - 0.5) / 0.035, 0, 1)
    depth = np.clip((thick - 0.5) / 0.9, 0, 1)
    rgb = np.zeros(thick.shape + (3,))
    edge = np.array([0.26, 0.0, 0.015])
    mid = np.array([0.58, 0.02, 0.04])
    deep = np.array([0.36, 0.0, 0.02])
    t = depth[..., None]
    rgb[:] = np.where(t < 0.35, edge + (mid - edge) * (t / 0.35), mid + (deep - mid) * ((t - 0.35) / 0.65))
    # the wet light: where the surface tilts toward the upper left (the thickness's slope)
    gy, gx = np.gradient(thick)
    tilt = np.clip((-gx - gy) * N * 0.0035, 0, 1) * np.clip((thick - 0.75) / 0.3, 0, 1)
    spec = np.clip(tilt - 0.5, 0, 0.5) ** 2 * 2.6
    rgb += spec[..., None] * np.array([1.0, 0.6, 0.58])
    # a dark line just inside the edge (blood dries at its rim first)
    rim = np.clip(1 - np.abs(thick - 0.56) / 0.05, 0, 1) * 0.45
    rgb *= (1 - rim)[..., None]
    grain = 0.94 + 0.06 * rng.random(thick.shape)
    rgb *= grain[..., None]
    alpha = alpha * (0.88 + 0.12 * depth)
    return np.clip(rgb, 0, 1), alpha


def splat(seed, arms, core=0.17, spray=90, squash=1.0, lean=0.0):
    rng = np.random.default_rng(seed)
    y, x = (np.mgrid[0:N, 0:N] + 0.5) / N
    y = (y - 0.5) / squash + 0.5
    thick = np.zeros((N, N))
    # the core: a few lobes
    for _ in range(5):
        a, d = rng.random() * 6.283, rng.random() * core * 0.5
        thick += field_blob(x, y, 0.5 + np.cos(a) * d, 0.5 + np.sin(a) * d, core * (0.55 + rng.random() * 0.4)) * 0.9
    # the arms: thrown out from the core, each a chain of beads shrinking with distance, then loose drops beyond
    for k in range(arms):
        a = lean + (k + rng.random() * 0.8) / arms * 6.283
        reach = 0.2 + rng.random() * 0.22
        width = 0.02 + rng.random() * 0.022
        bend = (rng.random() - 0.5) * 0.5
        steps = 46
        for i in range(steps):
            u = i / steps
            r = core * 0.6 + reach * u
            aa = a + bend * u * u
            w = width * (1 - u) ** 0.8 + 0.004
            # (breaks into beads past two thirds of its reach)
            if u > 0.66 and (i % 4) > 1:
                continue
            thick += field_blob(x, y, 0.5 + np.cos(aa) * r, 0.5 + np.sin(aa) * r, w) * 0.85
        for j in range(int(2 + rng.random() * 4)):
            r = core * 0.6 + reach * (1.05 + j * 0.13 + rng.random() * 0.08)
            if r > 0.47:
                break
            aa = a + bend + (rng.random() - 0.5) * 0.07
            thick += field_blob(x, y, 0.5 + np.cos(aa) * r, 0.5 + np.sin(aa) * r,
                                0.012 * (1 - j * 0.16) + rng.random() * 0.004) * 1.3
    # the spray: fine droplets, denser near the core
    for _ in range(spray):
        a = rng.random() * 6.283
        r = core * 0.9 + abs(rng.normal(0, 0.13))
        if r > 0.47:
            continue
        thick += field_blob(x, y, 0.5 + np.cos(a) * r, 0.5 + np.sin(a) * r, 0.0035 + rng.random() * 0.0075) * 1.4
    # the ragged edge
    thick *= 0.78 + 0.5 * noise(rng, N, 22) + 0.16 * noise(rng, N, 70)
    # nothing touches the picture's border
    border = np.clip(np.minimum(np.minimum(x, 1 - x), np.minimum((y - 0.5) * squash + 0.5, 1 - ((y - 0.5) * squash + 0.5)))
                     / 0.03, 0, 1)
    thick *= border
    return shade(thick, rng)


def drip(seed):
    """A run of blood down glass: a bead at the bottom, a thinning tail above it (tall and narrow: 1:4)."""
    rng = np.random.default_rng(seed)
    h, w = N, N // 4
    y, x = np.mgrid[0:h, 0:w]
    x = (x + 0.5) / w
    y = (y + 0.5) / h
    wob = 0.5 + 0.06 * np.sin(y * 9 + seed) + 0.03 * np.sin(y * 23 + seed * 2)
    half = 0.05 + 0.2 * y ** 1.6
    tail = np.exp(-((x - wob) / half) ** 2) * np.clip(y / 0.08, 0, 1)
    bead = np.exp(-(((x - wob[-1]) / 0.34) ** 2 + ((y - 0.93) / 0.055) ** 2))
    thick = tail * 0.95 * np.clip((0.97 - y) / 0.03, 0, 1) + bead * 1.3
    big = np.zeros((N, N))
    big[:, :w] = thick
    rgb, alpha = shade(big, rng)
    return rgb[:, :w], alpha[:, :w]


def save(name, rgb, alpha):
    h, w = alpha.shape
    img = np.dstack([rgb, alpha])
    wsum = alpha.reshape(h // 2, 2, w // 2, 2, 1).sum(axis=(1, 3))
    col = (rgb.reshape(h // 2, 2, w // 2, 2, 3) * alpha.reshape(h // 2, 2, w // 2, 2, 1)).sum(axis=(1, 3))
    out = img.reshape(h // 2, 2, w // 2, 2, 4).mean(axis=(1, 3))
    out[..., :3] = np.where(wsum > 1e-4, col / np.maximum(wsum, 1e-6), 0)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    png.write(path, out)
    print("wrote", path)


def main():
    save("BloodSplatA.png", *splat(3, arms=11))                       # a full burst, all round
    save("BloodSplatB.png", *splat(8, arms=7, core=0.14, spray=140))  # lighter, more spray
    save("BloodSplatC.png", *splat(15, arms=9, core=0.2, spray=60))   # heavy and wet
    save("BloodSplatD.png", *splat(22, arms=6, core=0.12, spray=170, squash=0.72))  # flung sideways: wide and low
    save("BloodDrip.png", *drip(5))


if __name__ == "__main__":
    main()
