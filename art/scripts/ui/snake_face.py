"""Snake's face for A true patriot's saluter (2026-11-12, the user: "snake doesnt have a face"): a Roblox face decal in
the flat style of the avatar faces, a hardened soldier's: narrowed eyes under heavy, low brows, a crease between them,
a short full beard and moustache round a set mouth. Transparent everywhere but the drawing; the head's skin shows
through. Run with Blender's Python:

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\5.2\\python\\bin\\python.exe" art/scripts/ui/snake_face.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
import png  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "art", "export", "textures", "FaceSnake.png")
N = 512


def grid():
    y, x = (np.mgrid[0:N, 0:N] + 0.5) / N
    return x, y


def ellipse(x, y, cx, cy, rx, ry, angle=0.0):
    c, s = np.cos(angle), np.sin(angle)
    dx, dy = x - cx, y - cy
    u = (dx * c + dy * s) / rx
    v = (-dx * s + dy * c) / ry
    return u * u + v * v


def soft(d, edge=0.06):
    return np.clip((1 - d) / edge, 0, 1)


def stroke(x, y, pts, width):
    best = np.full(x.shape, 1e9)
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        dx, dy = bx - ax, by - ay
        ll = dx * dx + dy * dy
        t = np.clip(((x - ax) * dx + (y - ay) * dy) / ll, 0, 1)
        best = np.minimum(best, np.hypot(x - (ax + t * dx), y - (ay + t * dy)))
    return np.clip((width - best) / (width * 0.35), 0, 1)


def main():
    x, y = grid()
    rgb = np.zeros((N, N, 3))
    alpha = np.zeros((N, N))

    def paint(mask, color, a=1.0):
        nonlocal alpha
        m = np.clip(mask, 0, 1) * a
        rgb[:] = rgb * (1 - m[..., None]) + np.array(color)[None, None, :] * m[..., None]
        alpha = np.maximum(alpha, m)

    rng = np.random.default_rng(5)
    # the beard: a short full beard round the jaw and chin, a moustache over the mouth, coarse stubble at its edges
    beard = soft(ellipse(x, y, 0.5, 0.75, 0.25, 0.155), 0.12) * np.clip((y - 0.63) / 0.04, 0, 1)
    hollow = soft(ellipse(x, y, 0.5, 0.71, 0.11, 0.05), 0.4)
    stubble = (rng.random((N, N)) < 0.7) * 0.25 + 0.75
    paint(beard * (1 - hollow * 0.9) * stubble, (0.22, 0.17, 0.12), 0.95)
    moustache = soft(ellipse(x, y, 0.5, 0.655, 0.12, 0.028), 0.3)
    paint(moustache, (0.2, 0.15, 0.1))
    # the mouth: a set line under the moustache
    paint(stroke(x, y, [(0.44, 0.7), (0.5, 0.705), (0.56, 0.7)], 0.006), (0.1, 0.06, 0.05))
    # the eyes: narrowed almonds, whites, dark grey-blue irises looking ahead, upper lids heavy
    for side in (-1, 1):
        cx = 0.5 + side * 0.105
        white = soft(ellipse(x, y, cx, 0.46, 0.055, 0.019, side * -0.08), 0.15)
        paint(white, (0.93, 0.9, 0.86))
        iris = soft(ellipse(x, y, cx + side * -0.006, 0.461, 0.019, 0.019), 0.2) * white
        paint(iris, (0.2, 0.26, 0.3))
        pupil = soft(ellipse(x, y, cx + side * -0.006, 0.461, 0.008, 0.008), 0.3) * white
        paint(pupil, (0.04, 0.04, 0.05))
        # the heavy upper lid line and a lower crease
        lid = [(cx - 0.06, 0.462 + side * 0.0), (cx - 0.02, 0.442), (cx + 0.025, 0.441), (cx + 0.062, 0.455)]
        paint(stroke(x, y, lid, 0.006), (0.12, 0.08, 0.06))
        # the brow: thick, low, angled down toward the nose
        inner, outer = cx - side * 0.05, cx + side * 0.07
        # (the inner end low, toward the nose: stern, not sad)
        brow = [(min(inner, outer), 0.385 if side < 0 else 0.41), (cx, 0.397), (max(inner, outer),
                0.41 if side < 0 else 0.385)]
        paint(stroke(x, y, brow, 0.014), (0.16, 0.12, 0.08))
    # the crease between the brows and the line of the nose
    paint(stroke(x, y, [(0.495, 0.41), (0.5, 0.44)], 0.003), (0.36, 0.25, 0.2), 0.7)
    paint(stroke(x, y, [(0.52, 0.5), (0.53, 0.585), (0.505, 0.6)], 0.004), (0.36, 0.25, 0.2), 0.7)
    img = np.dstack([rgb, alpha])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    png.write(OUT, img)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
