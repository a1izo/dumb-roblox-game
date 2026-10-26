"""The rooftop of the Coven's Godhood win cutscene (src/shared/Cinema/WinCuts.luau newWorld; the owner, 2026-10-26:
"build extremely high quality and rendered scenes in which every cutscene sits"): the flat roof of a tall old block
over the night city, under the red sky the cutscene hangs behind it. A wet tar deck inside a parapet with stone
coping; a wooden water tank on its steel legs with its ladder and bands, a lattice radio mast held by its guy wires
(the cutscene's beacon on its top), the stair hut with its door and lamp, air units and pipes; the building's dark
face dropping 70 to the street the city stands on. The star's mark is the roof's origin (plan.ROOFTOP), near its north
edge, where the star walks to."""

import math

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.ROOFTOP
X0, X1, Z0, Z1 = -20.0, 20.0, -7.25, 17.0
DROP = 70.0  # the street, below the roof
PARAPET = 1.4
TANK = (-9.0, 7.0)  # the water tank's middle (the cutscene's)
MAST = (8.0, 5.0)  # the radio mast's foot (the cutscene's beacon is at 14.1 over it)
HUT = (8.5, 8.0, 13.5, 12.0)  # the stair hut
WARM = (255, 196, 130)


def build(s):
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    kit.floor(s, x0, z0, x1, z1, "AsphaltWet")
    for x, z, rx, rz in ((-3.0, 2.0, 2.6, 1.6), (12.0, -2.5, 1.8, 1.2), (-15.0, 12.0, 2.2, 1.4)):
        kit.puddle(s, OX + x, OZ + z, rx, rz)
    # The parapet round the edge, its stone coping.
    edges = [((x0, z0), (x1, z0)), ((x1, z0), (x1, z1)), ((x1, z1), (x0, z1)), ((x0, z1), (x0, z0))]
    for a, b in edges:
        kit.wall(s, a, b, PARAPET, thick=0.7, core="Concrete", side_s="Concrete", side_n="Concrete")
    for (ax, az), (bx, bz) in edges:
        s.box("Stone", ((ax + bx) / 2, PARAPET + 0.1, (az + bz) / 2), (abs(bx - ax) + 0.9, 0.2, abs(bz - az) + 0.9))
    # The building's face down to the street: dark brick, rows of windows, almost all of them dark.
    for (ax, az), (bx, bz) in edges:
        length = abs(bx - ax) + abs(bz - az)
        along_x = abs(bx - ax) > 0
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        out_x = 0.0 if along_x else (0.45 if mx > OX else -0.45)
        out_z = (0.45 if mz > OZ else -0.45) if along_x else 0.0
        s.box("BrickDark", (mx + out_x, -DROP / 2, mz + out_z), (length + 0.9 if along_x else 0.9, DROP, 0.9 if along_x else length + 0.9))
        for floor in range(15):
            y = -6.0 - floor * 4.4
            for k in range(int(length // 4.0)):
                t = (k + 0.5) * 4.0 - length / 2 + (length % 4.0) / 2
                lit = (floor * 7 + k * 3) % 11 == 0
                cx = mx + (t if along_x else 0.0) + out_x * 2.05
                cz = mz + (0.0 if along_x else t) + out_z * 2.05
                size = (1.6, 2.4, 0.1) if along_x else (0.1, 2.4, 1.6)
                s.box("DimWindow" if lit else "WindowDark", (cx, y, cz), size)
    # The water tank: staves bound in iron, a pointed lid, on four steel legs braced across, its ladder.
    tx, tz = OX + TANK[0], OZ + TANK[1]
    s.cylinder("Wood", (tx, 1.6, tz), 2.0, 4.8, 20)
    s.lathe("Slate", (tx, 6.4, tz), [(2.25, 0.0), (0.15, 1.3)], 20)
    for y in (2.0, 3.6, 5.2, 6.2):
        s.cylinder("BlackMetal", (tx, y, tz), 2.06, 0.14, 20)
    for dx, dz in ((-1.4, -1.4), (1.4, -1.4), (-1.4, 1.4), (1.4, 1.4)):
        s.tube("BlackMetal", (tx + dx, 0.0, tz + dz), (tx + dx * 0.9, 1.65, tz + dz * 0.9), 0.14, 6)
    for (ax, az), (bx, bz) in (((-1.4, -1.4), (1.4, -1.4)), ((1.4, -1.4), (1.4, 1.4)), ((1.4, 1.4), (-1.4, 1.4)),
                               ((-1.4, 1.4), (-1.4, -1.4))):
        s.tube("BlackMetal", (tx + ax, 0.2, tz + az), (tx + bx * 0.9, 1.5, tz + bz * 0.9), 0.06, 4)
    for dx in (-0.35, 0.35):
        s.tube("BlackMetal", (tx + 2.15, 0.0, tz + dx), (tx + 2.15, 6.6, tz + dx), 0.05, 4)
    for k in range(13):
        s.tube("BlackMetal", (tx + 2.15, 0.4 + k * 0.5, tz - 0.35), (tx + 2.15, 0.4 + k * 0.5, tz + 0.35), 0.035, 4)
    # The radio mast: a three-legged lattice tapering to its top, braced in zigzags, three guy wires to the deck.
    mx, mz = OX + MAST[0], OZ + MAST[1]
    top = 13.8
    legs = []
    for k in range(3):
        a = math.tau * k / 3
        legs.append(((mx + 0.6 * math.cos(a), mz + 0.6 * math.sin(a)), (mx + 0.12 * math.cos(a), mz + 0.12 * math.sin(a))))
    for (bx, bz), (tx2, tz2) in legs:
        s.tube("PaintSteel", (bx, 0.0, bz), (tx2, top, tz2), 0.06, 5)
    for k in range(3):
        (ax, az), (atx, atz) = legs[k]
        (bx, bz), (btx, btz) = legs[(k + 1) % 3]
        for j in range(7):
            u0, u1 = j / 7, (j + 1) / 7
            p0 = (ax + (atx - ax) * u0, top * u0, az + (atz - az) * u0)
            p1 = (bx + (btx - bx) * u1, top * u1, bz + (btz - bz) * u1)
            s.tube("PaintSteel", p0, p1, 0.025, 4)
    for gx, gz in ((5.5, 0.0), (-3.0, 4.6), (-3.0, -4.6)):
        s.tube("BlackMetal", (mx, top * 0.66, mz), (mx + gx, 0.05, mz + gz), 0.015, 3)
    # The stair hut: brick walls, a steel door in its north face under a caged lamp, a flat roof with a lip.
    hx0, hz0, hx1, hz1 = OX + HUT[0], OZ + HUT[1], OX + HUT[2], OZ + HUT[3]
    door = {"at": (HUT[2] - HUT[0]) / 2, "w": 2.6, "bottom": 0.0, "top": 5.6, "kind": "door", "frame": "BlackMetal"}
    for a, b, ops in (((hx0, hz0), (hx1, hz0), [door]), ((hx1, hz0), (hx1, hz1), []), ((hx1, hz1), (hx0, hz1), []),
                      ((hx0, hz1), (hx0, hz0), [])):
        kit.wall(s, a, b, 7.0, thick=0.6, core="BrickDark", side_s="BrickDark", side_n="BrickDark", openings=ops)
    s.box("Concrete", ((hx0 + hx1) / 2, 7.15, (hz0 + hz1) / 2), (hx1 - hx0 + 0.8, 0.3, hz1 - hz0 + 0.8))
    s.box("PaintSteel", ((hx0 + hx1) / 2, 2.8, hz0 - 0.05), (2.5, 5.5, 0.12))
    s.light("point", ((hx0 + hx1) / 2, 6.3, hz0 - 0.6), WARM, 9, 0.7, shadows=True, glow=((0.5, 0.35, 0.35), (255, 214, 160)))
    # Air units on their rails and the pipes between them.
    for x, z in ((14.5, 1.5), (-15.5, 2.0)):
        s.box("PaintSteel", (OX + x, 1.2, OZ + z), (3.2, 2.0, 2.4))
        s.box("BlackMetal", (OX + x, 0.1, OZ + z), (3.6, 0.2, 2.8))
        s.cylinder("BlackMetal", (OX + x, 2.2, OZ + z), 0.9, 0.12, 16)
    s.tube("PaintSteel", (OX - 15.5, 0.6, OZ + 3.2), (OX - 15.5, 0.6, OZ + 14.5), 0.22, 8)
    s.tube("PaintSteel", (OX - 15.5, 0.6, OZ + 14.5), (OX + 6.5, 0.6, OZ + 14.5), 0.22, 8)
    for x in range(-14, 6, 4):
        s.box("BlackMetal", (OX + x, 0.2, OZ + 14.5), (0.3, 0.4, 0.6))
