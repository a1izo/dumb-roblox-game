"""Walrider (art/refs/deaths/walrider.md): the asylum's underground lab, seen from the floor and then on your feet.
A bare concrete room, its pale blue-grey floor marked with yellow lines; a vaulted concrete ceiling on ribs with caged
lamps hanging from it; pipes and cable trays down the walls. Across its end (z = -2) a thick wall with the heavy steel
double door (its leaves are the scene's own, they slide), a steel frame and header with a warning lamp, the black and
yellow hazard stripe on the floor before it. Through it a white tiled room under hard fluorescent light, blood on its
floor: where the soldiers and the man in the wheelchair wait.

Scene space: the victim's eyes start on the floor at (0, 0.8, 7.5) looking at it, rise and walk to z = 3.2 looking -Z
at the door; then fall on their back looking up at the vault.
"""

import math

from maps import kit
from maps.venues.scenes import parts
from maps.venues.scenes import plan as P

OX, OZ = P.WALRIDER
HALF = 10.0  # the lab's half width
WALL_H = 9.5  # where the vault springs
RISE = 3.6  # the vault's rise over its span
BACK = 16.0  # the lab's far end (behind the victim)
DOOR_W, DOOR_H = 7.0, 9.0


def W(x, y, z):
    return (OX + x, y, OZ + z)


def vault(s, mat, z0, z1, n=14):
    """A segmental barrel vault over the lab from wall to wall, its soffit seen from below."""
    big = (RISE * RISE + HALF * HALF) / (2 * RISE)
    cy = WALL_H + RISE - big
    pts = []
    for k in range(n + 1):
        x = -HALF + 2 * HALF * k / n
        pts.append((x, cy + math.sqrt(big * big - x * x)))
    for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
        quad = [W(xa, ya, z0), W(xb, yb, z0), W(xb, yb, z1), W(xa, ya, z1)]
        mid = ((xa + xb) / 2, (ya + yb) / 2)
        parts.poly(s, mat, quad, (-mid[0], cy - mid[1], 0))
    return pts


def hazard(s, x0, x1, z0, z1, y=0.015, width=0.6):
    """Black and yellow diagonal stripes on the floor over x0..x1, z0..z1."""
    depth = z1 - z0
    x = x0 - depth
    k = 0
    while x < x1:
        a, b = x, x + width
        quad = [(a, z0), (b, z0), (b + depth, z1), (a + depth, z1)]
        clipped = [(min(max(px, x0), x1), pz) for px, pz in quad]
        if max(p[0] for p in clipped) - min(p[0] for p in clipped) > 0.01:
            parts.poly(s, "HazardYellow" if k % 2 == 0 else "HazardBlack", [W(px, y, pz) for px, pz in clipped],
                       (0, 1, 0))
        x += width
        k += 1


def build(s):
    # the lab: floor, walls, the vault on its ribs
    s.box("LabFloor", W(0, -0.5, (BACK - 2) / 2), (2 * HALF, 1.0, BACK + 2))
    for side in (-1, 1):
        s.box("LabWall", W(side * (HALF + 0.5), WALL_H / 2, (BACK - 2) / 2), (1.0, WALL_H, BACK + 2))
    s.box("LabWall", W(0, (WALL_H + RISE) / 2, BACK + 0.5), (2 * HALF + 2, WALL_H + RISE, 1.0))
    pts = vault(s, "LabWall", -2.0, BACK)
    for z in (1.5, 7.5, 13.5):  # the ribs
        for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
            q0 = [W(xa, ya - 0.7, z - 0.5), W(xb, yb - 0.7, z - 0.5), W(xb, yb - 0.7, z + 0.5), W(xa, ya - 0.7, z + 0.5)]
            parts.poly(s, "ConcreteDark", q0, (0, -1, 0))
            for dz in (-0.5, 0.5):
                parts.poly(s, "ConcreteDark", [W(xa, ya, z + dz), W(xb, yb, z + dz), W(xb, yb - 0.7, z + dz),
                                               W(xa, ya - 0.7, z + dz)], (0, 0, dz))
        for side in (-1, 1):
            s.box("ConcreteDark", W(side * (HALF - 0.35), WALL_H / 2, z), (0.7, WALL_H, 1.0))
    # the floor's yellow lines, water drops where the victim lay, a drain
    for x in (-4.5, 4.5):
        s.box("HazardYellow", W(x, 0.012, 7.5), (0.25, 0.024, 17.0))
    for k, (x, z, w) in enumerate(((-0.4, 7.0, 0.25), (0.3, 6.6, 0.18), (0.9, 7.6, 0.3), (-1.1, 8.2, 0.2),
                                   (0.1, 5.4, 0.22), (1.6, 6.1, 0.16), (-0.7, 5.9, 0.14))):
        pts2 = [W(x + math.cos(a) * w * (1 + 0.25 * math.sin(a * 3 + k)), 0.02, z + math.sin(a) * w * 0.8)
                for a in (math.tau * j / 8 for j in range(8))]
        parts.poly(s, "Puddle", pts2, (0, 1, 0))
    s.box("BlackMetal", W(6.5, 0.015, 10.0), (1.2, 0.03, 1.2))
    # pipes and cable trays down both walls, conduit boxes, caged wall lamps
    for side in (-1, 1):
        x = side * (HALF - 0.4)
        for y, r, mat in ((7.6, 0.32, "PaintSteel"), (8.3, 0.2, "PaintSteel"), (6.9, 0.14, "RedTrim")):
            s.tube(mat, W(x - side * r, y, -1.2), W(x - side * r, y, BACK - 0.5), r, 8)
        s.box("BlackMetal", W(x - side * 0.5, 5.6, 7.0), (0.9, 0.12, 17.5))
        for z in (3.0, 10.5):
            s.box("PaintSteel", W(x - side * 0.25, 3.2, z), (0.5, 1.4, 1.0))
            s.tube("BlackMetal", W(x - side * 0.25, 3.9, z), W(x - side * 0.25, 5.6, z), 0.06, 5)
    kit.sconce(s, OX - HALF + 0.1, 6.2, OZ + 5.0, -90, color=(210, 222, 236), range_=12, brightness=0.5)
    kit.sconce(s, OX + HALF - 0.1, 6.2, OZ + 11.0, 90, color=(210, 222, 236), range_=12, brightness=0.5)
    # caged lamps hanging from the vault (the light seen from the floor at the end)
    for z in (4.5, 10.5):
        kit.pendant(s, OX, WALL_H + RISE - 0.1, OZ + z, drop=3.2, shade="DarkMetal", color=(214, 226, 240),
                    range_=22, brightness=0.9)
    # the door wall: thick concrete either side of the opening and over it
    side_w = HALF - DOOR_W / 2
    for side in (-1, 1):
        s.box("LabWall", W(side * (DOOR_W / 2 + side_w / 2), (WALL_H + RISE) / 2, -2.6), (side_w, WALL_H + RISE, 1.2))
    s.box("LabWall", W(0, (DOOR_H + WALL_H + RISE) / 2, -2.6), (DOOR_W, WALL_H + RISE - DOOR_H, 1.2))
    # its steel frame: posts painted with chevrons, the header with a warning lamp, the door track
    for side in (-1, 1):
        px = side * (DOOR_W / 2 + 0.3)
        s.box("Steel", W(px, DOOR_H / 2, -1.95), (0.6, DOOR_H, 0.3))
        for k in range(9):
            y0 = 0.5 + k * 0.95
            parts.poly(s, "HazardYellow" if k % 2 == 0 else "HazardBlack",
                       [W(px - 0.3, y0, -1.79), W(px + 0.3, y0 + 0.4, -1.79), W(px + 0.3, y0 + 0.9, -1.79),
                        W(px - 0.3, y0 + 0.5, -1.79)], (0, 0, 1))
    s.box("Steel", W(0, DOOR_H + 0.45, -1.95), (DOOR_W + 1.2, 0.9, 0.3))
    s.box("BlackMetal", W(0, DOOR_H + 0.15, -1.55), (DOOR_W * 2 + 1.0, 0.3, 0.3))  # (the leaves' track)
    s.cylinder("NeonRed", W(0, DOOR_H + 0.95, -1.9), 0.28, 0.35, 12)
    s.box("BlackMetal", W(0, DOOR_H + 0.92, -1.9), (0.8, 0.08, 0.5))
    # the hazard stripe on the floor before the door
    hazard(s, -DOOR_W / 2 - 0.4, DOOR_W / 2 + 0.4, -1.8, -0.4)
    # the white tiled room beyond, under hard fluorescent light, blood on its floor
    t0, t1, th = -3.2, -19.0, 11.0
    s.box("TileWhite", W(0, -0.5, (t0 + t1) / 2), (17.0, 1.0, t0 - t1))
    s.box("TileWhite", W(0, th / 2, t1 - 0.5), (17.0, th, 1.0))
    for side in (-1, 1):
        s.box("TileWhite", W(side * 9.0, th / 2, (t0 + t1) / 2), (1.0, th, t0 - t1))
    s.box("Ceiling", W(0, th + 0.25, (t0 + t1) / 2), (17.0, 0.5, t0 - t1))
    for z in (-7.0, -12.5, -17.0):
        kit.tube_light(s, OX - 3.0, th, OZ + z, length=5.0, rot=90, color=(236, 242, 255), range_=20, brightness=1.0)
        kit.tube_light(s, OX + 3.0, th, OZ + z, length=5.0, rot=90, color=(236, 242, 255), range_=20, brightness=1.0)
    for k, (x, z, rx, rz) in enumerate(((-1.6, -8.2, 2.2, 1.3), (2.4, -12.0, 1.4, 1.0), (-3.6, -14.6, 1.1, 0.8),
                                        (0.8, -5.6, 0.9, 0.5), (4.6, -9.4, 0.7, 0.5))):
        pts3 = [W(x + math.cos(a) * rx * (1 + 0.22 * math.sin(a * 3 + k * 2)), 0.02,
                  z + math.sin(a) * rz * (1 + 0.2 * math.cos(a * 2 + k))) for a in (math.tau * j / 12 for j in range(12))]
        parts.poly(s, "BloodDry", pts3, (0, 1, 0))
    for k in range(5):  # a smear dragged toward the back wall
        parts.poly(s, "BloodDry", [W(-1.6 + k * 0.15, 0.021, -9.4 - k * 1.6), W(-0.9 + k * 0.1, 0.021, -9.4 - k * 1.6),
                                   W(-1.0 + k * 0.1, 0.021, -10.9 - k * 1.6), W(-1.5 + k * 0.15, 0.021, -10.9 - k * 1.6)],
                   (0, 1, 0))
    # a steel bench and a cabinet against the far wall, a floor drain
    s.box("Steel", W(-4.5, 2.6, t1 + 1.0), (5.0, 0.15, 1.8))
    for dx in (-2.2, 2.2):
        s.box("Steel", W(-4.5 + dx, 1.3, t1 + 1.0), (0.15, 2.6, 1.6))
    s.box("PaintSteel", W(5.0, 3.0, t1 + 0.7), (3.0, 6.0, 1.2))
    s.box("BlackMetal", W(5.0, 3.0, t1 + 1.31), (0.05, 5.6, 0.04))
    s.box("BlackMetal", W(0.0, 0.015, -11.0), (0.9, 0.03, 0.9))
