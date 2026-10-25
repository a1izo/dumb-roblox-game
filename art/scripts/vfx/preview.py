"""Looks at VFX textures as the game would draw them: over the dark realm, added as light (LightEmission 1) and laid
over (LightEmission 0), tinted.

    python art/scripts/vfx/preview.py <out.png> <name> [<name> ...] [--tint r,g,b] [--width 1024]
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from vfx import draw as D  # noqa: E402
from vfx.textures import TEXTURES  # noqa: E402


def panel(img, tint, back):
    """The image laid over `back` (left) and added to it as light (right), side by side."""
    rgb = img[..., :3] * np.array(tint)[None, None, :]
    a = img[..., 3:4]
    base = np.ones_like(rgb) * np.array(back)[None, None, :]
    laid = base * (1 - a) + rgb * a
    added = np.clip(base + rgb * a, 0, 1)
    out = np.concatenate([laid, added], axis=1)
    return np.concatenate([out, np.ones(out.shape[:2] + (1,))], axis=-1)


def main():
    argv = sys.argv[1:]
    out = argv[0]
    tint = (1.0, 1.0, 1.0)
    width = 1024
    names = []
    frames = None
    k = 1
    while k < len(argv):
        if argv[k] == "--tint":
            tint = tuple(float(v) / 255 for v in argv[k + 1].split(","))
            k += 2
        elif argv[k] == "--frames":
            # grid,first,count,step: show those cells of a flipbook side by side, enlarged
            frames = [int(v) for v in argv[k + 1].split(",")]
            k += 2
        elif argv[k] == "--width":
            width = int(argv[k + 1])
            k += 2
        else:
            names.append(argv[k])
            k += 1
    rows = []
    for name in names:
        img = D.read_png(os.path.join(TEXTURES, name + ".png"))
        if frames:
            g, first, count, step = frames
            ch, cw = img.shape[0] // g, img.shape[1] // g
            cells = []
            for n in range(first, first + count * step, step):
                r, c = divmod(n % (g * g), g)
                cells.append(img[r * ch:(r + 1) * ch, c * cw:(c + 1) * cw])
            img = np.concatenate(cells, axis=1)
        h, w, _ = img.shape
        half = width // 2
        nh = max(1, int(h * half / w))
        small = D.resize(img, nh, half)
        rows.append(panel(small, tint, (0.07, 0.07, 0.085)))
        rows.append(np.ones((6, width, 4)) * np.array([0.3, 0.3, 0.3, 1.0]))
    D.write_png(out, np.concatenate(rows, axis=0))
    print("[vfx preview]", out)


if __name__ == "__main__":
    main()
