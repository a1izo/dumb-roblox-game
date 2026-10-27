"""The game's two pointers (UI/Cursor), drawn with numpy, white with a black outline:

    CursorLock  64 x 64  the closed-eyes mark the user drew (art/refs/ui/cursor_lashes.png), traced from it: the
                         pointer locked in the middle of the screen in a case's free roam (World/ShoulderCam)
    CursorFree  64 x 64  a fountain-pen nib, bone white, its point on the middle pixel: the pointer everywhere else

Roblox centres a custom pointer on the mouse, so each one's hot spot is the middle of its picture (the gap between
the two lashes; the nib's point). Also writes a preview, art/export/previews/cursors.png (each on dark and on light,
actual size and four times).

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/ui/cursors.py
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flow  # noqa: E402
import paint as pt  # noqa: E402
import png  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
REF = os.path.join(ROOT, "art", "refs", "ui", "cursor_lashes.png")
OUT = os.path.join(ROOT, "art", "export", "textures")
PREVIEW = os.path.join(ROOT, "art", "export", "previews", "cursors.png")

SIZE = 64
SS = 8  # drawn at eight times the size, then averaged down
LASH_WIDTH = 54  # the mark's width on screen, px
THICKEN = 0.9  # the mark's strokes made this much bolder, px (thin strokes vanished under the outline)
NIB = 1.25  # the nib's size against its first drawing
OUTLINE = 1.4  # the black outline, px
WHITE = np.array([0.97, 0.97, 0.97], np.float32)
BONE = np.array([0.93, 0.91, 0.86], np.float32)
BLACK = np.array([0.02, 0.02, 0.025], np.float32)


def down(a):
    """Averages a supersampled (SIZE * SS) array down to SIZE."""
    shape = (SIZE, SS, SIZE, SS) + a.shape[2:]
    return a.reshape(shape).mean(axis=(1, 3))


def outlined(fill_ss):
    """A shape (supersampled coverage) as RGBA: white inside a black outline."""
    hard = (fill_ss > 0.5).astype(np.float32)
    ring = flow.grow(hard, int(round(OUTLINE * SS)))
    fill = down(hard)
    alpha = down(ring)
    rgb = WHITE[None, None] * fill[..., None] + BLACK[None, None] * (1 - fill[..., None])
    return np.concatenate([rgb, alpha[..., None]], -1).astype(np.float32)


def lashes():
    """The user's mark, traced: its dark shapes, scaled to LASH_WIDTH and centred on the middle pixel."""
    grey = png.read(REF)[..., 0].astype(np.float32) / 255.0
    ink = grey < 0.5
    ys, xs = np.nonzero(ink)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = (grey[y0:y1, x0:x1] < 0.5).astype(np.float32)
    h, w = crop.shape
    width = LASH_WIDTH * SS
    height = int(round(h * width / w))
    shape = flow.resample(crop, height, width)
    canvas = np.zeros((SIZE * SS, SIZE * SS), np.float32)
    top = (SIZE * SS - height) // 2
    left = (SIZE * SS - width) // 2
    canvas[top:top + height, left:left + width] = shape
    return outlined(flow.grow((canvas > 0.5).astype(np.float32), int(round(THICKEN * SS))))


def nib():
    """A fountain-pen nib, its point on the middle pixel, its body slanting down to the right (as an arrow does):
    the shoulders, the slit down from the point to the breather hole, the shade on its far half."""
    centre = SIZE * SS / 2
    axis = np.array([math.cos(math.radians(52)), math.sin(math.radians(52))])  # from the point to the back
    side = np.array([-axis[1], axis[0]])

    def at(u, v):
        p = np.array([centre, centre]) + (axis * u + side * v) * SS * NIB
        return (float(p[0]), float(p[1]))

    # half widths along the nib (px from the point): fine at the point, full at the shoulders, a step in at the back
    us = np.linspace(0, 27, 40)
    half = np.interp(us, [0, 1.5, 8, 15, 19, 21, 21.01, 27], [0.25, 1.2, 4.2, 6.6, 7.1, 6.8, 5.2, 5.2])
    left = [at(u, -hw) for u, hw in zip(us, half)]
    right = [at(u, hw) for u, hw in zip(us, half)]
    body = pt.fill(left + right[::-1], SIZE * SS, SIZE * SS)
    hard = (body > 0.5).astype(np.float32)
    ring = flow.grow(hard, int(round(OUTLINE * SS)))
    # the far half a shade darker, the slit and the breather hole in black, a line where the nib meets the pen
    ys, xs = np.mgrid[0:SIZE * SS, 0:SIZE * SS].astype(np.float32)
    rel_v = (xs - centre) * side[0] + (ys - centre) * side[1]
    tone = np.where(rel_v > 0, 0.84, 1.0)[..., None] * BONE[None, None]
    slit = pt.fill(pt.outline([at(1.6, 0), at(12.6, 0)], [0.9 * SS, 0.9 * SS]), SIZE * SS, SIZE * SS)
    hole = pt.ellipse(*at(14.4, 0), 1.7 * SS * NIB, 1.7 * SS * NIB, SIZE * SS, SIZE * SS)
    collar = pt.fill(pt.outline([at(21.3, -6.9), at(21.3, 6.9)], [0.9 * SS, 0.9 * SS]), SIZE * SS, SIZE * SS)
    marks = np.clip(slit + hole + collar, 0, 1) * hard
    rgb = tone * (1 - marks[..., None]) + BLACK[None, None] * marks[..., None]
    rgb = rgb * hard[..., None] + BLACK[None, None] * (1 - hard[..., None])
    alpha = down(ring)
    colour = down(rgb * ring[..., None]) / np.maximum(alpha, 1e-6)[..., None]
    return np.concatenate([colour, alpha[..., None]], -1).astype(np.float32)


def preview(pictures):
    rows = []
    for back in (0.08, 0.78):
        tiles = []
        for picture in pictures:
            for zoom in (1, 4):
                big = np.repeat(np.repeat(picture, zoom, 0), zoom, 1)
                tile = np.full((SIZE * 4, SIZE * 4, 3), back, np.float32)
                h, w = big.shape[:2]
                y, x = (SIZE * 4 - h) // 2, (SIZE * 4 - w) // 2
                a = big[..., 3:]
                tile[y:y + h, x:x + w] = tile[y:y + h, x:x + w] * (1 - a) + big[..., :3] * a
                # the hot spot, a red dot
                tile[SIZE * 2 - 1:SIZE * 2 + 1, SIZE * 2 - 1:SIZE * 2 + 1] = (0.9, 0.1, 0.1)
                tiles.append(tile)
        rows.append(np.concatenate(tiles, axis=1))
    return np.concatenate(rows, axis=0)


def main():
    os.makedirs(OUT, exist_ok=True)
    lock, free = lashes(), nib()
    png.write(os.path.join(OUT, "CursorLock.png"), lock)
    png.write(os.path.join(OUT, "CursorFree.png"), free)
    png.write(PREVIEW, preview([lock, free]))
    print("[cursors] wrote", os.path.join(OUT, "CursorLock.png"), "and CursorFree.png")


if __name__ == "__main__":
    main()
