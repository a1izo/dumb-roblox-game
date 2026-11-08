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
# Roblox shows a Sky's faces as they are (no darkening at night). Graded as dark as a clear night's
# (Tokyo 34, 28, 48) they read black in the game and took the haze and the wet streets' reflections with them;
# as bright as the default night sky (Tokyo 64, 52, 88) they read flat. The owner wanted them moodier
# (2026-10-12): about a third darker than that, with more of the clouds' shapes showing.
SKIES = {
    "Tokyo": ("kloppenheim_07_puresky", (46, 37, 64), 1.1),  # low cloud lit violet from below by the city
    "Campus": ("kloofendal_overcast_puresky", (58, 53, 58), 0.85),  # a snow sky: dull, a little warm, close
    "Agency": ("overcast_soil_puresky", (33, 30, 49), 1.25),  # storm cloud seen from the 38th floor
}
# How many times brighter (in linear light) each graded sky is written. Since the noir retune (2026-11-02, exposure
# 0.1) the game shows a sky far darker than its faces: all three, and even Roblox's own default sky, read pure black,
# and the far cities' towers vanished, leaving their lit windows floating in nothing. Tried in a Studio play test
# (2026-11-06, the user: "brighten skies") at 1, 4, 8 and 16 times: at 8 a dark violet (Tokyo) or dull warm grey
# (Campus) night that the skyline stands out against; 4 still nearly black, 16 lifts the far facades through the
# haze. The Agency's storm sky is graded darker, so it takes 12 to land beside the other two.
LIFT = {"Tokyo": 8.0, "Campus": 8.0, "Agency": 12.0}


def lift(srgb, gain):
    """srgb (0..1) made `gain` times brighter in linear light, clipped at white."""
    linear = np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)
    linear = np.clip(linear * gain, 0.0, 1.0)
    return np.where(linear <= 0.0031308, linear * 12.92, 1.055 * linear ** (1 / 2.4) - 0.055)
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
    # Graded as one picture: the six faces stacked, so each keeps its place in the sky's light and dark. Graded face by
    # face, every face was moved onto the same mean and the sky stepped in tone at each edge (seen 2026-11-08).
    keys = list(FACES)
    stack = np.concatenate([scanlib.to_srgb(face(pano, *FACES[key])).astype(np.float32) for key in keys], axis=0)
    stack = scanlib.grade(stack, colour, keep=0.15, contrast=contrast, limits=(0.0, 1.0))
    stack = lift(stack, LIFT.get(venue, 1.0)).astype(np.float32)
    for index, key in enumerate(keys):
        graded = stack[index * SIZE:(index + 1) * SIZE]
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
