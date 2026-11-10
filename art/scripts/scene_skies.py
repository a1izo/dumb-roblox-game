"""The scene deaths' skies, drawn (no photographs): the six faces Roblox's Sky takes for each, written to
art/export/textures/SkyScene<Name><Face>.png and carried into Roblox on quads in the Scenes venue's FBX (its TEXTURES),
like the maps' skies (skies.py). SceneDeaths shows them through LightingPresets.scenes (World/LightingController).

    Mist     A true patriot: a pale overcast morning, the sun a soft glow through the mist at the upper left
    Dusk     Let's dance!: a desert dusk, gold at the horizon, brown-grey above, long streaks of cloud
    Ember    and I.. am..: a battlefield's orange dusk under drifting smoke
    Requiem  This is... requiem: the star void, violet with magenta and green nebulae, dense white stars
    God      A GOD.. IS NOT... AFRAID OF...: a purple sky of stars and nebulae, magenta and cyan

    blender -b --factory-startup --python art/scripts/scene_skies.py [-- Mist Dusk ...]

Faces keep skies.py's names (the way its camera looks), but Roblox shows SkyboxLf toward +X and SkyboxRt toward -X:
World/LightingController swaps the two for every sky (seen 2026-11-08 as a seam down the nebula, and checked on the
maps' skies the same night: their cloud bands met only with the swap).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common  # noqa: E402
import skies  # noqa: E402
from maps import scanlib  # noqa: E402

# Where each sky's sun stands (a direction toward it; LightingPresets.scenes aims Roblox's sun the same way).
SUNS = {
    "Mist": (0.5, 0.26, 0.83),
    "Dusk": (0.55, 0.16, 0.82),
    "Ember": (-0.28, 0.10, -0.95),
}


def _unit(v):
    v = np.asarray(v, dtype=np.float64)
    return v / np.linalg.norm(v)


def directions(forward, up, size):
    forward, up = np.array(forward, dtype=np.float64), np.array(up, dtype=np.float64)
    right = np.cross(forward, up)
    y, x = (np.mgrid[0:size, 0:size] + 0.5) / size * 2 - 1
    d = forward[None, None, :] + x[..., None] * right[None, None, :] + y[..., None] * up[None, None, :]
    return d / np.sqrt((d * d).sum(axis=-1, keepdims=True))


def fbm(d, seed, octaves=5, waves=12, base=2.0, gain=0.55):
    """Smooth noise over directions in about -1..1: waves at random angles, octave over octave."""
    r = np.random.default_rng(seed)
    total = np.zeros(d.shape[:2])
    amp, f, norm = 1.0, base, 0.0
    for _ in range(octaves):
        for _ in range(waves):
            k = _unit(r.normal(size=3))
            total += amp * np.sin((d @ k) * f * np.pi + r.uniform(0, 2 * np.pi))
            norm += amp
        amp *= gain
        f *= 2.1
    return total / norm * 2.4


def stars(d, seed, count, size):
    """Points of light: `count` stars over the sphere, splatted where they land on this face (d: its directions)."""
    r = np.random.default_rng(seed)
    pts = r.normal(size=(count, 3))
    pts /= np.linalg.norm(pts, axis=1, keepdims=True)
    bright = r.uniform(0.2, 1.0, count) ** 3
    h, w = d.shape[:2]
    # the face's own axes, from its corner directions
    f = _unit(d[h // 2, w // 2])
    right = _unit(d[h // 2, -1] - d[h // 2, 0])
    up = _unit(d[-1, w // 2] - d[0, w // 2])
    out = np.zeros((h, w))
    pf = pts @ f
    ok = pf > 0.3
    x = (pts[ok] @ right) / pf[ok]
    y = (pts[ok] @ up) / pf[ok]
    b = bright[ok]
    inside = (np.abs(x) < 1) & (np.abs(y) < 1)
    px = ((x[inside] + 1) / 2 * w).astype(int).clip(0, w - 1)
    py = ((y[inside] + 1) / 2 * h).astype(int).clip(0, h - 1)
    b = b[inside]
    np.maximum.at(out, (py, px), b)
    big = b > 0.45
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        np.maximum.at(out, ((py[big] + dy).clip(0, h - 1), (px[big] + dx).clip(0, w - 1)), b[big] * 0.4)
    return out


def rgb(c):
    return np.array(c, dtype=np.float64) / 255.0


def gradient(elev, stops):
    """A colour per pixel from its elevation (-1 down .. 1 up) through stops [(elev, (r, g, b))]."""
    out = np.zeros(elev.shape + (3,))
    es = [e for e, _ in stops]
    for ch in range(3):
        out[..., ch] = np.interp(elev, es, [rgb(c)[ch] for _, c in stops])
    return out


def glow(d, sun, width, power=1.0):
    cos = np.clip(d @ _unit(sun), -1, 1)
    return np.exp(-(1 - cos) / width) * power


def mist(d, size):
    elev = d[..., 1]
    sky = gradient(elev, [(-1, (214, 210, 198)), (0.0, (236, 232, 220)), (0.12, (226, 224, 216)),
                          (0.45, (204, 206, 206)), (1, (186, 190, 196))])
    cloud = fbm(d * np.array([1, 2.2, 1]), 11, octaves=5)
    sky *= 1 + 0.05 * cloud[..., None]
    g = glow(d, SUNS["Mist"], 0.06, 0.35) + glow(d, SUNS["Mist"], 0.006, 0.6)
    sky += g[..., None] * rgb((255, 246, 222))
    return sky


def dusk(d, size):
    elev = d[..., 1]
    sky = gradient(elev, [(-1, (120, 92, 64)), (-0.02, (226, 168, 104)), (0.04, (240, 196, 126)),
                          (0.16, (206, 150, 96)), (0.4, (150, 112, 86)), (1, (84, 72, 72))])
    streak = fbm(d * np.array([0.6, 5.0, 0.6]), 21, octaves=5)
    band = np.exp(-((elev - 0.14) / 0.12) ** 2)
    sky *= (1 - 0.18 * np.clip(streak, 0, 1) * band)[..., None]
    sky += (0.12 * np.clip(streak, 0, 1) * band * glow(d, SUNS["Dusk"], 0.5, 1.0))[..., None] * rgb((255, 210, 150))
    g = glow(d, SUNS["Dusk"], 0.05, 0.5) + glow(d, SUNS["Dusk"], 0.004, 1.2)
    sky += g[..., None] * rgb((255, 224, 160))
    return sky


def ember(d, size):
    elev = d[..., 1]
    sky = gradient(elev, [(-1, (70, 44, 36)), (-0.02, (214, 120, 62)), (0.03, (244, 152, 78)),
                          (0.14, (196, 98, 54)), (0.35, (112, 58, 46)), (1, (40, 32, 38))])
    smoke = np.clip(fbm(d * np.array([1.0, 1.6, 1.0]), 31, octaves=6) * 0.7 + 0.1, 0, 1)
    sky *= (1 - 0.55 * smoke * np.clip(elev * 4 + 0.6, 0, 1))[..., None]
    g = glow(d, SUNS["Ember"], 0.04, 0.45) + glow(d, SUNS["Ember"], 0.004, 1.0)
    sky += g[..., None] * rgb((255, 196, 120))
    return sky


def nebula(d, size, base, clouds, seed, star_count, star_tint=(255, 255, 255)):
    sky = np.ones(d.shape[:2] + (3,)) * rgb(base)
    for k, (colour, amount, scale) in enumerate(clouds):
        n = fbm(d * scale, seed + k * 7, octaves=6, waves=10)
        warp = fbm(d * scale * 0.5, seed + k * 7 + 3, octaves=3, waves=8)
        m = np.clip(n * 0.65 + warp * 0.45 + 0.05, 0, 1) ** 1.4
        sky += (m * amount)[..., None] * rgb(colour)
    dust = np.clip(fbm(d * 3.0, seed + 99, octaves=6) * 0.5 + 0.2, 0, 1)
    sky *= (0.7 + 0.3 * dust)[..., None]
    s = stars(d, seed + 5, star_count, size)
    sky += s[..., None] * rgb(star_tint) * 1.4
    return sky


def requiem(d, size):
    """2026-11-10, the user: "the sky isnt accurate". The anime's rewind is a BRIGHT galaxy, not a dark one: violet and
    blue cores, pink veils, green patches, dense bright stars and a white glow."""
    sky = nebula(d, size, (40, 22, 86), [((168, 96, 255), 1.7, 1.0), ((255, 104, 214), 1.25, 1.4),
                                         ((90, 140, 255), 1.0, 0.8), ((80, 236, 160), 0.85, 1.8)], 41, 30000,
                 (255, 250, 255))
    # a band of bright galaxy light across the sky, and the white glow where the light breaks through
    band = np.exp(-((d @ _unit((0.2, 0.9, 0.35))) / 0.28) ** 2)
    core = np.clip(fbm(d * 1.4, 77, octaves=5) * 0.5 + 0.5, 0, 1) ** 2
    sky += (band * core * 0.55)[..., None] * rgb((236, 214, 255))
    sky += glow(d, (-0.7, 0.2, -0.6), 0.05, 0.9)[..., None] * rgb((255, 250, 240))
    return sky


def god(d, size):
    return nebula(d, size, (52, 18, 100), [((160, 60, 240), 0.95, 0.9), ((240, 70, 200), 0.8, 1.3),
                                           ((70, 220, 255), 0.5, 1.7)], 51, 8000, (240, 230, 255))


SKIES = {"Mist": (mist, 512), "Dusk": (dusk, 512), "Ember": (ember, 512), "Requiem": (requiem, 1024),
         "God": (god, 1024)}


def make(name):
    fn, size = SKIES[name]
    paths = []
    for key, (forward, up) in skies.FACES.items():
        d = directions(forward, up, size)
        srgb = np.clip(fn(d, size), 0, 1).astype(np.float32)
        rgba = np.concatenate([srgb, np.ones((size, size, 1), dtype=np.float32)], axis=-1)
        img = bpy.data.images.new(f"SkyScene{name}{key}", size, size, alpha=False)
        img.pixels.foreach_set(rgba.ravel())
        path = os.path.join(common.TEXTURES, f"SkyScene{name}{key}.png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
        paths.append(path)
    print("[scene skies]", name)
    return paths


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for sky_name in argv or list(SKIES):
        make(sky_name)
    _ = scanlib  # (the textures folder exists once scanlib is loaded)
