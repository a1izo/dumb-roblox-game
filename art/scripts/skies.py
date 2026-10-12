"""The three maps' skies: photographed sky panoramas (art/source/skies, Poly Haven, CC0; see
art/scripts/sources.py) cut into the six faces Roblox's Sky takes and graded to each map's night.
The lobby has no sky of this kind (its cloud layers are World/RealmSky's).

Each face is written to art/export/textures/Sky<Venue><Face>.png and rides into Roblox on a carrier
quad in the venue's FBX (the venue's TEXTURES list), like the effect textures.

    blender -b --factory-startup --python art/scripts/skies.py [-- Tokyo Campus Agency]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common  # noqa: E402
from maps import scanlib  # noqa: E402

SOURCE = common.source("skies")
SIZE = 512  # a night sky under cloud holds little detail: six small faces are enough

# venue -> (panorama, the sky's own colour at night (sRGB), how much of the clouds' light and dark shows).
# Roblox shows a Sky's faces as they are (no darkening at night), and cloud over a lit city glows: graded as
# dark as a clear night's, they read black in the game (2026-10-12) and took the haze and the wet streets'
# reflections down with them, so they sit about as bright as the default night sky they replace.
SKIES = {
    "Tokyo": ("kloppenheim_07_puresky", (64, 52, 88), 0.9),  # low cloud lit violet from below by the city
    "Campus": ("kloofendal_overcast_puresky", (80, 74, 80), 0.7),  # a snow sky: dull, a little warm, close
    "Agency": ("overcast_soil_puresky", (46, 42, 68), 1.1),  # storm cloud seen from the 38th floor
}
# face -> (the way it looks, its up), in Roblox axes
FACES = {
    "Ft": ((0, 0, -1), (0, 1, 0)),
    "Bk": ((0, 0, 1), (0, 1, 0)),
    "Rt": ((1, 0, 0), (0, 1, 0)),
    "Lf": ((-1, 0, 0), (0, 1, 0)),
    "Up": ((0, 1, 0), (0, 0, 1)),
    "Dn": ((0, -1, 0), (0, 0, -1)),
}


def names(venue):
    """The texture names of a venue's six faces (for its TEXTURES list)."""
    return [f"Sky{venue}{face}" for face in FACES]


def panorama(name):
    """The panorama as a float array [v, u, 3] of linear light, v = 0 at the bottom."""
    path = os.path.join(SOURCE, name, name + "_4k.hdr")
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    buf = np.empty(w * h * img.channels, dtype=np.float32)
    img.pixels.foreach_get(buf)
    arr = buf.reshape(h, w, img.channels)[..., :3].copy()
    bpy.data.images.remove(img)
    return arr


def face(pano, forward, up, size=SIZE):
    """One cube face of the panorama: what a camera looking along `forward` sees."""
    forward, up = np.array(forward, dtype=np.float64), np.array(up, dtype=np.float64)
    right = np.cross(forward, up)
    y, x = (np.mgrid[0:size, 0:size] + 0.5) / size * 2 - 1
    d = forward[None, None, :] + x[..., None] * right[None, None, :] + y[..., None] * up[None, None, :]
    d /= np.sqrt((d * d).sum(axis=-1, keepdims=True))
    h, w = pano.shape[:2]
    u = (np.arctan2(d[..., 0], -d[..., 2]) / (2 * np.pi) + 0.5) * w
    v = (np.arcsin(np.clip(d[..., 1], -1, 1)) / np.pi + 0.5) * h
    return pano[np.clip(v.astype(int), 0, h - 1), u.astype(int) % w]


def make(venue):
    name, colour, contrast = SKIES[venue]
    pano = panorama(name)
    # The day's light brought down to something a film could hold, then graded onto the night's colour:
    # the clouds keep their shapes, and take the colour the map's light gives them.
    pano = pano * (0.18 / max(1e-6, float((pano @ scanlib.LUMA).mean())))
    pano = pano / (1 + pano)
    paths = []
    for key, (forward, up) in FACES.items():
        srgb = scanlib.to_srgb(face(pano, forward, up)).astype(np.float32)
        graded = scanlib.grade(srgb, colour, keep=0.15, contrast=contrast, limits=(0.0, 1.0))
        rgba = np.concatenate([graded, np.ones((SIZE, SIZE, 1), dtype=np.float32)], axis=-1)
        img = bpy.data.images.new(f"Sky{venue}{key}", SIZE, SIZE, alpha=False)
        img.pixels.foreach_set(rgba.ravel())
        path = os.path.join(common.TEXTURES, f"Sky{venue}{key}.png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
        paths.append(path)
    print("[skies]", venue, name)
    return paths


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for venue in argv or list(SKIES):
        make(venue)
