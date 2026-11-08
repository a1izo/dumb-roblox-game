"""A true patriot (art/refs/deaths/patriot.md): a military cemetery in a sunlit morning mist. Rows of small arched
headstones (mostly weathered grey-brown, every third pale) march away over a gently rolling meadow into the mist; a
big bare oak stands behind the saluter, bare woods behind everything, low hills on the horizon. The dead's headstone
is the pale one at (0, -3.8), its face to the saluter at the origin (the scene writes the name on it). No walls
anywhere: the ground runs 300 studs out and the mist takes it.

Scene space: the saluter at the origin facing -Z (toward the grave); the wide shots look +Z past them, so the rows,
the oak and the woods stand mostly at +Z.
"""

import math
import random

from maps.venues.scenes import parts
from maps.venues.scenes import plan as P

OX, OZ = P.PATRIOT
GRAVE = (0.0, -3.8)


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def ground_h(x, z):
    """Scene-space height: dead flat where the actors stand, a gentle roll through the rows, hills far off."""
    r = math.hypot(x, z)
    near = 0.35 * parts.noise2(x, z, seed=11, octaves=3, scale=34.0) * smooth(5.0, 16.0, r)
    far = smooth(90.0, 280.0, r) * (9.0 + 7.0 * parts.noise2(x, z, seed=12, octaves=3, scale=140.0))
    return near + far


def build(s):
    def h(wx, wz):
        return ground_h(wx - OX, wz - OZ)

    # the meadow: fine near the actors, coarser out in the mist
    def step(wx, wz):
        d = max(abs(wx - OX), abs(wz - OZ))
        return 2.0 if d < 70 else (4.0 if d < 170 else 10.0)

    parts.heightfield(s, "MeadowGrass", OX - 320, OZ - 220, OX + 320, OZ + 420, step, h)

    # the dead's headstone: pale, bigger, its face to the saluter (+Z)
    gx, gz = OX + GRAVE[0], OZ + GRAVE[1]
    parts.headstone(s, "HeadstonePale", gx, gz, 180, w=2.0, h=2.55, t=0.42, bevel=0.07, sag=0.3, arch=10, sink=0.5,
                    y=h(gx, gz), engrave=False)

    # the rows: graves every 4.4 studs along X, rows every 7 along Z, all facing +Z like the dead's
    r = random.Random(5)
    rows = [-3.8 - 7 * k for k in range(1, 6)] + [-3.8] + [-3.8 + 7 * k for k in range(2, 28)]
    for rz in rows:
        far = rz > 70 or rz < -30
        for k in range(-15, 16):
            x = k * 4.4 + (2.2 if int(round(rz)) % 2 else 0.0)
            z = rz + r.uniform(-0.15, 0.15)
            if abs(x) < 2.6 and abs(rz - GRAVE[1]) < 0.5:
                continue  # (the dead's own place)
            if abs(x) < 12 and -17 < z < -6:
                continue  # (where the wide shots stand)
            if abs(x) < 3.2 and -2 < z < 6:
                continue  # (the saluter's ground)
            wx, wz = OX + x, OZ + z
            pale = (k + int(rz)) % 3 == 0
            parts.headstone(s, "HeadstonePale" if pale else "HeadstoneDark", wx, wz, 180 + r.uniform(-2.5, 2.5),
                            w=1.25, h=1.9 + r.uniform(-0.1, 0.1), t=0.3, bevel=0.045, arch=4 if far else 7,
                            sink=0.45, y=h(wx, wz) - r.uniform(0, 0.06), engrave=not far)

    # grass tufts round the actors and the near rows (none on the saluter's feet or the grave's face)
    for k in range(820):
        a = r.uniform(0, math.tau)
        d = 1.4 + abs(r.gauss(0, 11))
        x, z = math.cos(a) * d, math.sin(a) * d * 1.3 + 4
        if math.hypot(x, z) < 1.2 or (abs(x - GRAVE[0]) < 1.8 and -4.4 < z < 0.2):
            continue  # (the saluter's feet; the grave's face and the close-up's line to it)
        wx, wz = OX + x, OZ + z
        parts.grass_clump(s, wx, wz, h(wx, wz), seed=k, blades=7, height=(0.3, 0.75), spread=0.3, dry=0.3)

    # the big bare oak behind the saluter (left of the wide shots), roots in the grass
    tx, tz = OX + 6.0, OZ + 31.0
    parts.bare_tree(s, "Bark", tx, tz, h(tx, tz), 30.0, seed=21, levels=4, trunk=1.25, spread=34.0, lean=(-0.08, 0.05))
    # bare woods: a ragged belt behind the rows and down both sides, fading into the mist
    for k in range(46):
        if k < 30:
            x, z = r.uniform(-260, 260), r.uniform(205, 330)
        else:
            side = -1 if k % 2 else 1
            x, z = side * r.uniform(80, 220), r.uniform(-120, 200)
        wx, wz = OX + x, OZ + z
        parts.bare_tree(s, "Bark", wx, wz, h(wx, wz), r.uniform(22, 36), seed=100 + k, levels=3,
                        trunk=r.uniform(0.6, 1.0), spread=r.uniform(26, 38), sides=6)
    # a few more oaks among the rows, far enough to sit in the mist
    for k, (x, z) in enumerate(((-38, 64), (44, 96), (-70, 130), (26, 150))):
        wx, wz = OX + x, OZ + z
        parts.bare_tree(s, "Bark", wx, wz, h(wx, wz), r.uniform(24, 30), seed=60 + k, levels=3, trunk=0.9, sides=7)
