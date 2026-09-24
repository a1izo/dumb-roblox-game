"""Joins preview images into one sheet (background Blender):

    blender -b --factory-startup --python art/scripts/contact_sheet.py -- out.png columns tile a.png b.png ...
Relative names are looked up in art/export/previews.
"""

import math
import os
import sys

import bpy
import numpy as np


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    out, columns, tile = argv[0], int(argv[1]), int(argv[2])
    folder = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "export", "previews")
    files = [f if os.path.isabs(f) else os.path.join(folder, f) for f in argv[3:]]
    if not os.path.isabs(out):
        out = os.path.join(folder, out)
    rows = math.ceil(len(files) / columns)
    canvas = np.zeros((rows * tile, columns * tile, 4), dtype=np.float32)
    canvas[..., 3] = 1
    for i, path in enumerate(files):
        img = bpy.data.images.load(path)
        img.scale(tile, tile)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(tile, tile, 4)
        r, c = divmod(i, columns)
        y0 = (rows - 1 - r) * tile
        canvas[y0 : y0 + tile, c * tile : (c + 1) * tile] = px
        bpy.data.images.remove(img)
    image = bpy.data.images.new("sheet", columns * tile, rows * tile, alpha=True)
    image.pixels = canvas.ravel()
    image.filepath_raw = out
    image.file_format = "PNG"
    image.save()


main()
