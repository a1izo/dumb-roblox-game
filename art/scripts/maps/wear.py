"""Small wear for the maps' walls, one sheet of four marks (graphics plan phase 12, 2026-11-26):

    cell 0  chair-back scuffs: grey rubs and short black streaks where chair backs and bags knock the wall
    cell 1  a stain under a pipe joint: damp that ran down a wall from a coupling
    cell 2  a darker patch round a light switch: the grime of fingers, with a smudge under the plate
    cell 3  tape marks: the pale residue at the corners of a notice that was taken down, and its dirty outline

art/export/textures/WearOffice.png (512 x 512, RGBA: four cells of 2 x 2 studs at 128 pixels a stud). Like the grime
sheet (grime.py) its alpha channel is the mark's shape, so it sits on any wall colour; the game sets the surface's
AlphaMode to Transparency (SceneBuilder.dress) and shows nothing where it cannot. kit.wear places the marks.

    blender -b --factory-startup --python art/scripts/maps/wear.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy  # noqa: E402
import numpy as np  # noqa: E402

import common  # noqa: E402
from maps import grime  # noqa: E402

NAME = "WearOffice"
CELL = 256  # 2 x 2 studs
SIZE = 512
PX = 128  # pixels a stud
CELLS = 4  # scuff, stain, switch, tape (the cell's index in kit.WEAR_CELLS)


def _edge():
    ramp = grime._smooth(np.minimum(np.arange(CELL), np.arange(CELL)[::-1]) / 12.0)
    return ramp[:, None] * ramp[None, :]


def _scuff(r):
    """Cell 0: two soft rubs at chair-back height, short black streaks leaning one way (rows count up from the floor)."""
    shape = (CELL, CELL)
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    rub = np.zeros(shape, dtype=np.float32)
    for y, strength in ((0.55 * CELL, 0.34), (0.43 * CELL, 0.22)):
        line = grime._capsule(shape, (30 + r.uniform(0, 20), y + r.uniform(-4, 4)),
                              (CELL - 30 - r.uniform(0, 30), y + r.uniform(-8, 8)), r.uniform(9, 14))
        breakup = 0.4 + 0.6 * grime._smooth(0.5 + 1.2 * grime._periodic(r, shape, 0.9))
        rub = np.maximum(rub, strength * line * breakup)
    streak = np.zeros(shape, dtype=np.float32)
    for _ in range(7):
        cx, cy = r.uniform(34, CELL - 34), r.uniform(0.3 * CELL, 0.72 * CELL)
        length = r.uniform(0.2, 0.5) * PX
        ang = np.radians(r.uniform(-12, 18))
        a = (cx - np.cos(ang) * length / 2, cy - np.sin(ang) * length / 2)
        b = (cx + np.cos(ang) * length / 2, cy + np.sin(ang) * length / 2)
        streak = np.maximum(streak, r.uniform(0.35, 0.7) * grime._capsule(shape, a, b, r.uniform(2.5, 4.5)))
    streak *= 0.35 + 0.65 * grime._smooth(0.5 + 1.1 * grime._periodic(r, shape, 0.7))
    alpha = np.maximum(grime._blur(rub, 2.0), grime._blur(streak, 1.0)) * _edge()
    return alpha, (34, 32, 33)


def _stain(r):
    """Cell 1: damp under a pipe joint: a wide, soft patch, darkest just under the collar, fading down and out, no hard line
    (an earlier version with thin run streaks read as a black crack in the game, 2026-11-26)."""
    shape = (CELL, CELL)
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    depth = (CELL - yy) / CELL  # 0 at the top (the joint), 1 at the foot
    sway = 6.0 * np.sin(depth * 3.0 + r.uniform(0, 6))
    half = 52.0 + 44.0 * np.sqrt(depth)  # a fan that widens as it falls (px; the cell is 256 wide)
    d = np.abs(xx - CELL / 2 - sway) / half
    fan = (1.0 - grime._smooth(d)) ** 1.5
    fall = (1.0 - grime._smooth((depth - 0.1) / 0.8)) * grime._smooth(depth / 0.16)  # soft in at the top, long soft out
    cloud = 0.6 + 0.4 * grime._smooth(0.5 + 1.0 * grime._periodic(r, shape, 1.4))
    alpha = grime._blur(0.38 * fan * fall * cloud, 6.0)
    return np.clip(alpha, 0, 0.4) * _edge(), (70, 62, 54)


def _switch(r):
    """Cell 2: finger grime round a switch plate at the cell's middle (the plate is 0.34 x 0.5 studs), a smudge below it."""
    shape = (CELL, CELL)
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    cx, cy = CELL / 2, CELL / 2
    box = np.hypot((xx - cx) / 36.0, (yy - cy) / 52.0)  # distance in plates, rounded: 1 at the plate
    halo = (1.0 - grime._smooth((box - 1.0) / 0.95)) * 0.5
    halo *= 0.7 + 0.3 * grime._smooth(0.5 + 1.0 * grime._periodic(r, shape, 1.1))
    halo *= 0.55 + 0.45 * grime._smooth((cy + 90.0 - yy) / 90.0 + 0.3)  # heavier below, where a hand comes up to it
    smudge = np.zeros(shape, dtype=np.float32)
    for k in range(3):
        sx, sy = cx + r.uniform(-24, 24), cy - 62 - r.uniform(0, 26)
        smudge = np.maximum(smudge, r.uniform(0.18, 0.3) * np.exp(-(((xx - sx) / 12.0) ** 2 + ((yy - sy) / 7.0) ** 2)))
    return np.clip(grime._blur(halo + smudge, 1.2), 0, 0.8) * _edge(), (36, 34, 30)


def _tape(r):
    """Cell 3: the four corners of a notice (1.4 x 1.0 studs) that hung here: pale residue strips, a faint dirty outline."""
    shape = (CELL, CELL)
    cx, cy = CELL / 2, CELL / 2
    w, h = 0.7 * PX, 0.5 * PX
    corners = [(cx - w, cy - h), (cx + w, cy - h), (cx - w, cy + h), (cx + w, cy + h)]
    tape = np.zeros(shape, dtype=np.float32)
    for k, (px, py) in enumerate(corners):
        sx, sy = (1 if k % 2 == 0 else -1), (1 if k < 2 else -1)
        ang = np.radians(r.uniform(-8, 8))
        length = r.uniform(0.2, 0.3) * PX
        a = (px + sx * 2, py + sy * 2)
        b = (px + sx * 2 + np.cos(ang) * length * sx, py + sy * 2 + np.sin(ang) * length * 0.35 * sy)
        tape = np.maximum(tape, r.uniform(0.5, 0.75) * grime._capsule(shape, a, b, r.uniform(5.0, 7.0)))
        if r.uniform() < 0.6:  # a curled bit that stayed behind
            c = (px - sx * r.uniform(4, 9), py - sy * r.uniform(8, 16))
            tape = np.maximum(tape, 0.4 * grime._capsule(shape, c, (c[0], c[1] - sy * 10), 3.0))
    tape *= 0.55 + 0.45 * grime._smooth(0.5 + 1.2 * grime._periodic(r, shape, 0.8))
    yy, xx = np.mgrid[0:CELL, 0:CELL].astype(np.float32)
    rect = np.maximum(np.abs(xx - cx) / w, np.abs(yy - cy) / h)
    outline = 0.16 * np.exp(-(((rect - 1.0) * 24.0) ** 2)) * (0.4 + 0.6 * grime._smooth(0.5 + grime._periodic(r, shape, 0.8)))
    alpha = (np.clip(tape, 0, 0.85) + outline) * _edge()
    return np.clip(grime._blur(alpha, 0.8), 0, 0.85), (178, 164, 128)


def build(seed=21):
    """The sheet as an RGBA float array (SIZE x SIZE x 4, rows from the bottom), sRGB values."""
    r = np.random.default_rng(seed)
    sheet = np.zeros((SIZE, SIZE, 4), dtype=np.float32)
    for k, make in enumerate((_scuff, _stain, _switch, _tape)):
        alpha, rgb = make(r)
        c, row = k % 2, k // 2
        sheet[row * CELL:(row + 1) * CELL, c * CELL:(c + 1) * CELL, 3] = alpha
        sheet[row * CELL:(row + 1) * CELL, c * CELL:(c + 1) * CELL, :3] = np.array(rgb, dtype=np.float32) / 255.0
    return sheet


def make():
    path = grime._save(NAME, build(), alpha=True)
    # Flat normal and roughness maps, as the grime sheet's: with them the importer makes a full surface appearance.
    grime._save(NAME + "_normal", np.tile(np.array([0.5, 0.5, 1.0, 1.0], dtype=np.float32), (8, 8, 1)), non_color=True)
    grime._save(NAME + "_rough", np.tile(np.array([0.9, 0.9, 0.9, 1.0], dtype=np.float32), (8, 8, 1)), non_color=True)
    print("[wear]", path, os.path.getsize(path), "bytes")
    return path


if __name__ == "__main__":
    make()
