"""Names scratched into the Grey Realm's stone: rows of them, too worn and too crowded to read, a few struck
through. One sheet, art/export/textures/ScratchNames.png (1024 x 512, RGBA: 8 x 4 studs at 128 pixels a stud),
pasted on upright faces as quads (`overlay`). Its alpha channel is the scratches' shape: pale where the blade
cut through the weathered skin of the stone, a dark lip under each cut. Like the grime sheet (grime.py), the
game sets the surface's AlphaMode to Transparency before the mesh enters the world and shows nothing where it
cannot.

No glyph is a real letter: each "name" is a run of short strokes leaning like a hurried hand, so nothing on
the walls can be read or names anything.

    blender -b --factory-startup --python art/scripts/maps/scratches.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common  # noqa: E402

W, H = 1024, 512
PX_PER_STUD = 128
NAME = "ScratchNames"
PALE = (176, 170, 158)  # the stone under its weathered skin
LIP = (30, 29, 31)  # the shadow under a cut


def _smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def _stroke(cut, lip, a, b, width, strength):
    """A scratch from a to b (pixels): the cut itself pale, a thin lip a pixel and a half under it."""
    for field, (ox, oy), w, s in ((cut, (0.0, 0.0), width, strength), (lip, (0.6, -1.5), width * 0.8, strength * 0.8)):
        ax, ay, bx, by = a[0] + ox, a[1] + oy, b[0] + ox, b[1] + oy
        x0, x1 = int(max(0, min(ax, bx) - w - 2)), int(min(W, max(ax, bx) + w + 3))
        y0, y1 = int(max(0, min(ay, by) - w - 2)), int(min(H, max(ay, by) + w + 3))
        if x1 <= x0 or y1 <= y0:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        dx, dy = bx - ax, by - ay
        length2 = max(dx * dx + dy * dy, 1e-6)
        t = np.clip(((xx - ax) * dx + (yy - ay) * dy) / length2, 0.0, 1.0)
        d = np.hypot(xx - (ax + t * dx), yy - (ay + t * dy))
        field[y0:y1, x0:x1] = np.maximum(field[y0:y1, x0:x1], s * (1.0 - _smooth(d / w)))


def _name(r, cut, lip, x, y, height, strength):
    """One name from (x, y) (its baseline's start, pixels): 3 to 9 glyphs of 2 to 4 strokes. Returns its end."""
    lean = r.uniform(0.15, 0.4)  # a hurried hand leans forward
    for _ in range(r.integers(3, 10)):
        gw = height * r.uniform(0.45, 0.8)
        for _ in range(r.integers(2, 5)):
            kind = r.integers(0, 4)
            if kind == 0:  # an upright
                u = r.uniform(0, gw)
                a, b = (x + u, y), (x + u + lean * height, y + height * r.uniform(0.6, 1.05))
            elif kind == 1:  # a cross-bar
                v = r.uniform(0.2, 0.9) * height
                a, b = (x + lean * v, y + v), (x + gw + lean * v, y + v + r.uniform(-0.15, 0.15) * height)
            elif kind == 2:  # a slant
                a, b = (x, y + r.uniform(0, 0.4) * height), (x + gw, y + r.uniform(0.6, 1.0) * height)
            else:  # a hook
                a, b = (x + gw * 0.2, y + height), (x + gw, y + height * r.uniform(0.0, 0.5))
            _stroke(cut, lip, a, b, r.uniform(1.4, 2.4), strength * r.uniform(0.75, 1.0))
        x += gw + height * r.uniform(0.12, 0.3)
    return x


def build(seed=13):
    """The sheet as an RGBA float array (H x W x 4, rows from the bottom), sRGB values."""
    r = np.random.default_rng(seed)
    cut = np.zeros((H, W), dtype=np.float32)
    lip = np.zeros((H, W), dtype=np.float32)
    y = 20.0
    while y < H - 60:
        height = r.uniform(0.26, 0.42) * PX_PER_STUD
        x = r.uniform(10, 60)
        while x < W - 120:
            strength = r.choice([0.35, 0.55, 0.8, 0.95])  # old names worn faint, new ones sharp
            start = x
            x = _name(r, cut, lip, x, y, height, strength)
            if r.uniform() < 0.18:
                # Struck through: one long cut over the whole name.
                mid = y + height * r.uniform(0.35, 0.6)
                _stroke(cut, lip, (start - 6, mid), (x + 4, mid + r.uniform(-6, 6)), 2.2, min(1.0, strength + 0.1))
            x += r.uniform(0.35, 1.0) * PX_PER_STUD
        y += height + r.uniform(0.18, 0.4) * PX_PER_STUD
    # Weathering: the cuts break up and fade here and there.
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    weather = 0.65 + 0.35 * np.sin(xx * 0.021 + np.sin(yy * 0.05) * 2.0) * np.cos(yy * 0.013 + xx * 0.004)
    cut *= weather
    lip *= weather * 0.7
    # Clear of the sheet's edges, so a quad's border never shows a cut in half.
    edge = _smooth(np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy)) / 10.0)
    cut *= edge
    lip *= edge
    sheet = np.zeros((H, W, 4), dtype=np.float32)
    pale = np.array(PALE, dtype=np.float32) / 255.0
    dark = np.array(LIP, dtype=np.float32) / 255.0
    lead = cut >= lip
    sheet[..., :3] = np.where(lead[..., None], pale, dark)
    sheet[..., 3] = np.maximum(cut * 0.9, lip * 0.75)
    return sheet[::-1]  # rows from the bottom, as texture v counts


def _save(name, array, alpha=False, non_color=False):
    h, w = array.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=alpha)
    if alpha:
        img.alpha_mode = "STRAIGHT"
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.ascontiguousarray(array).ravel())
    path = os.path.join(common.TEXTURES, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def make():
    path = _save(NAME, build(), alpha=True)
    # Flat normal and roughness maps, as the grime sheet's: with them the importer makes a full surface
    # appearance, the only kind whose alpha the game can switch to transparency.
    _save(NAME + "_normal", np.tile(np.array([0.5, 0.5, 1.0, 1.0], dtype=np.float32), (8, 8, 1)), non_color=True)
    _save(NAME + "_rough", np.tile(np.array([0.85, 0.85, 0.85, 1.0], dtype=np.float32), (8, 8, 1)), non_color=True)
    print("[scratches]", path, os.path.getsize(path), "bytes")
    return path


def overlay(s, a, b, y0, y1, out, u0=0.0, v0=0.0, studs=(8.0, 4.0)):
    """Names scratched over an upright face from ground point a to b (x, z), facing out (x, z), between heights
    y0 and y1 (a hair in front of it): the sheet repeats every `studs` (across, up), starting at (u0, v0)."""
    right = (out[1], -out[0])
    if (b[0] - a[0]) * right[0] + (b[1] - a[1]) * right[1] < 0:
        a, b = b, a
    off = 0.04
    a2 = (a[0] + out[0] * off, a[1] + out[1] * off)
    b2 = (b[0] + out[0] * off, b[1] + out[1] * off)
    length = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
    u1 = u0 + length / studs[0]
    v1 = v0 + (y1 - y0) / studs[1]
    s.polygon(NAME, [(a2[0], y0, a2[1]), (b2[0], y0, b2[1]), (b2[0], y1, b2[1]), (a2[0], y1, a2[1])],
              uvs=[(u0, v0), (u1, v0), (u1, v1), (u0, v1)], tile=1.0)


if __name__ == "__main__":
    make()
