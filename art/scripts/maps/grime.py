"""Wear for the maps' walls: dirt where it gathers and scuffs where people pass.

The look rulebook (lookbook.py) says dirt gathers low, in a band along a wall's foot, and that scuffs
sit where feet, bags and hands go: beside doors. One sheet holds all of it, art/export/textures/
GrimeWall.png (1024 x 1024, RGBA), and a map pastes pieces of it on walls as quads (kit.py,
`overlay`). Its alpha channel is the dirt's shape, so it sits on any wall colour; the game sets the
surface's AlphaMode to Transparency before the mesh enters the world (SceneBuilder.dress) and shows
nothing at all where it cannot.

    row 0.75 - 1.0   foot band, light      8 studs across (seamless along), 2 studs up
    row 0.50 - 0.75  foot band, medium
    row 0.25 - 0.50  foot band, heavy
    row 0.00 - 0.25  four scuffs, 2 x 2 studs each: kicks, a rub at hand height, a cart's streak, spots

(Rows count up from the bottom of the picture, as texture v does.)

    blender -b --factory-startup --python art/scripts/maps/grime.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common  # noqa: E402

SIZE = 1024
PX_PER_STUD = 128
BAND_H = 256  # 2 studs
SCUFF = 256  # 2 x 2 studs
NAME = "GrimeWall"

# Foot bands, lightest first: how high the dirt reaches (studs), and how dark it is at the floor.
BANDS = [(0.7, 0.36), (1.0, 0.48), (1.35, 0.60)]
SOIL = (36, 33, 30)  # the dirt's colour: a warm dark grey


def _periodic(r, shape, power):
    """Smooth noise that wraps in every direction, spread by 1 / f^power, as -1..1."""
    spectrum = np.fft.fft2(r.standard_normal(shape))
    fy = np.fft.fftfreq(shape[0])[:, None]
    fx = np.fft.fftfreq(shape[1])[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    out = np.real(np.fft.ifft2(spectrum / f**power))
    out -= out.mean()
    return np.clip(out / (3.0 * out.std() + 1e-9), -1, 1)


def _blur(a, sigma):
    """A soft edge for a drawn mark (a Gaussian, through the Fourier domain)."""
    fy = np.fft.fftfreq(a.shape[0])[:, None]
    fx = np.fft.fftfreq(a.shape[1])[None, :]
    kernel = np.exp(-2.0 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * kernel)).astype(np.float32)


def _smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def _band(r, reach, dark):
    """One foot band: alpha (BAND_H x SIZE), rows from the floor up."""
    along = _periodic(r, (1, SIZE), 1.5)[0]  # how high the dirt climbs, wall by wall
    streak = _periodic(r, (1, SIZE), 0.9)[0]  # drips and rubbed streaks
    mottle = _periodic(r, (BAND_H, SIZE), 1.2)
    y = (np.arange(BAND_H) + 0.5) / PX_PER_STUD
    top = reach * (1.0 + 0.4 * along)[None, :]
    rise = np.clip(1.0 - y[:, None] / top, 0.0, 1.0)
    shape = _smooth(rise) ** 1.35
    body = (0.62 + 0.38 * (0.5 + 0.5 * mottle)) * (0.78 + 0.22 * (0.5 + 0.5 * streak))[None, :]
    alpha = dark * shape * body
    alpha *= 1.0 - _smooth((y - 1.5) / 0.3)[:, None]  # nothing in the top fifth, so the quad's edge stays clean
    return alpha.astype(np.float32)


def _capsule(shape, a, b, width):
    """Distance field falloff of a line from a to b (pixels), 1 on the line, 0 beyond `width`."""
    yy, xx = np.mgrid[0 : shape[0], 0 : shape[1]].astype(np.float32)
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length2 = max(dx * dx + dy * dy, 1e-6)
    t = np.clip(((xx - ax) * dx + (yy - ay) * dy) / length2, 0.0, 1.0)
    d = np.hypot(xx - (ax + t * dx), yy - (ay + t * dy))
    return 1.0 - _smooth(d / width)


def _scuffs(r):
    """The four scuff cells as alpha, each SCUFF x SCUFF, with the colour each is drawn in."""
    cells = []
    shape = (SCUFF, SCUFF)
    edge = np.ones(shape, dtype=np.float32)
    ramp = _smooth(np.minimum(np.arange(SCUFF), np.arange(SCUFF)[::-1]) / 10.0)
    edge = ramp[:, None] * ramp[None, :]

    # 0. Kicks: short dark strokes low on the wall, all leaning the same way (a foot swung from one side).
    kick = np.zeros(shape, dtype=np.float32)
    for _ in range(9):
        cx, cy = r.uniform(30, SCUFF - 30), r.uniform(18, 0.5 * SCUFF)
        length = r.uniform(0.18, 0.5) * PX_PER_STUD
        ang = np.radians(r.uniform(5, 40))
        a = (cx - np.cos(ang) * length / 2, cy - np.sin(ang) * length / 2)
        b = (cx + np.cos(ang) * length / 2, cy + np.sin(ang) * length / 2)
        kick = np.maximum(kick, r.uniform(0.3, 0.62) * _capsule(shape, a, b, r.uniform(3.5, 7.0)))
    # Rubber comes off in patches, not in a line: break each stroke up with grain, then soften it.
    kick *= 0.35 + 0.65 * _smooth(0.5 + 1.1 * _periodic(r, shape, 0.7))
    cells.append((_blur(kick, 1.3) * edge, (24, 23, 24)))

    # 1. A rub at hand and shoulder height: a tall soft smear, lighter than the wall's grime (polish).
    yy, xx = np.mgrid[0:SCUFF, 0:SCUFF].astype(np.float32)
    cx, cy = SCUFF * 0.5, SCUFF * 0.5
    sx, sy = 0.2 * PX_PER_STUD, 0.62 * PX_PER_STUD
    rub = np.exp(-(((xx - cx) / sx) ** 2 + ((yy - cy) / sy) ** 2))
    rub *= 0.55 + 0.45 * (0.5 + 0.5 * _periodic(r, shape, 1.4))
    cells.append((0.26 * rub * edge, (96, 92, 86)))

    # 2. A cart's rail mark: two thin horizontal streaks, broken here and there.
    cart = np.zeros(shape, dtype=np.float32)
    for y_studs, strength in ((0.72, 0.5), (0.98, 0.3)):
        y = y_studs * PX_PER_STUD
        line = _capsule(shape, (14, y + r.uniform(-2, 2)), (SCUFF - 14, y + r.uniform(-4, 4)), r.uniform(4.5, 6.5))
        gaps = _periodic(r, (1, SCUFF), 1.5)[0]
        cart = np.maximum(cart, strength * line * (0.3 + 0.7 * _smooth(0.55 + 1.6 * gaps))[None, :])
    cells.append((_blur(cart, 1.6) * edge, (30, 28, 26)))

    # 3. Spots and a few runs: splashes that landed and dried, low on the wall.
    spots = np.zeros(shape, dtype=np.float32)
    for _ in range(16):
        cx, cy = r.uniform(24, SCUFF - 24), r.uniform(14, 0.62 * SCUFF)
        rad = r.uniform(0.025, 0.09) * PX_PER_STUD
        blob = 1.0 - _smooth(np.hypot(xx - cx, yy - cy) / rad)
        spots = np.maximum(spots, r.uniform(0.3, 0.6) * blob)
        if rad > 0.07 * PX_PER_STUD and r.uniform() < 0.35:
            run = r.uniform(0.1, 0.3) * PX_PER_STUD
            spots = np.maximum(spots, 0.22 * _capsule(shape, (cx, cy), (cx, cy - run), 3.0))
    cells.append((_blur(spots, 0.9) * edge, (30, 27, 24)))
    return cells


def build(seed=7):
    """The sheet as an RGBA float array (SIZE x SIZE x 4, rows from the bottom), sRGB values."""
    r = np.random.default_rng(seed)
    sheet = np.zeros((SIZE, SIZE, 4), dtype=np.float32)
    sheet[..., :3] = np.array(SOIL, dtype=np.float32) / 255.0
    # Bands, light at the top of the sheet: rows 0.75-1.0, 0.5-0.75, 0.25-0.5.
    for i, (reach, dark) in enumerate(BANDS):
        row0 = SIZE - (i + 1) * BAND_H
        alpha = _band(r, reach, dark)
        sheet[row0 : row0 + BAND_H, :, 3] = alpha
        tint = 0.88 + 0.24 * (0.5 + 0.5 * _periodic(r, (BAND_H, SIZE), 1.1))
        sheet[row0 : row0 + BAND_H, :, :3] = np.clip(np.array(SOIL, dtype=np.float32) / 255.0 * tint[..., None], 0, 1)
    for k, (alpha, rgb) in enumerate(_scuffs(r)):
        sheet[0:SCUFF, k * SCUFF : (k + 1) * SCUFF, 3] = alpha
        sheet[0:SCUFF, k * SCUFF : (k + 1) * SCUFF, :3] = np.array(rgb, dtype=np.float32) / 255.0
    return sheet


def _save(name, array, alpha=False, non_color=False):
    h, w = array.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=alpha)
    if alpha:
        img.alpha_mode = "STRAIGHT"
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(array.ravel())
    path = os.path.join(common.TEXTURES, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def make():
    path = _save(NAME, build(), alpha=True)
    # Flat normal and roughness maps, eight pixels square. The importer turns a material into a full
    # surface appearance (the only kind whose alpha the game can switch to transparency) only when it
    # has them; a colour map alone becomes a plain texture, which draws the alpha as opaque.
    flat_normal = np.tile(np.array([0.5, 0.5, 1.0, 1.0], dtype=np.float32), (8, 8, 1))
    flat_rough = np.tile(np.array([0.9, 0.9, 0.9, 1.0], dtype=np.float32), (8, 8, 1))
    _save(NAME + "_normal", flat_normal, non_color=True)
    _save(NAME + "_rough", flat_rough, non_color=True)
    print("[grime]", path, os.path.getsize(path), "bytes")
    return path


if __name__ == "__main__":
    make()
