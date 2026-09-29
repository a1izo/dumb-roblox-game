"""The war room's shell: the chevron parquet with its border and the round carpet under the table,
walls panelled to 6.4 in walnut with oxblood damask above, pilasters with brass capitals, a coffered
ceiling with a central rose holding the one hard light over the table, the brass halo round it, and
the Specters' mezzanine (iron on walnut brackets, a railing of balusters) at 12."""

import math

from maps import kit
from maps.venues.meeting import plan as P

HALF, H = P.HALF, P.H
TRIM = {"base": "BlackTrim", "wainscot": ("WoodPanel", 6.4), "rail": "Brass", "crown": "Wood"}


def floor(s):
    kit.floor(s, -HALF, -HALF, HALF, HALF, "Parquet", border=("WoodFloorDark", 2.5))
    s.zone("interior", [(-P.IN, -P.IN), (P.IN, -P.IN), (P.IN, P.IN), (-P.IN, P.IN)], 0.0, name="the war room")
    # The round carpet under the table, a gold band round it.
    n = 64
    r_in, r_gold, r_out = 22.6, 23.2, 23.8
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n

        def at(a, r, y):
            return (math.cos(a) * r, y, math.sin(a) * r)

        s.polygon("CarpetRed", [(0.0, 0.04, 0.0), at(a1, r_in, 0.04), at(a0, r_in, 0.04)])
        s.polygon("Gold", [at(a0, r_in, 0.045), at(a1, r_in, 0.045), at(a1, r_gold, 0.045), at(a0, r_gold, 0.045)])
        s.polygon("CarpetRed", [at(a0, r_gold, 0.04), at(a1, r_gold, 0.04), at(a1, r_out, 0.04), at(a0, r_out, 0.04)])


def walls(s):
    w0, w1, head = P.WINDOW
    windows = []
    for x in P.WINDOWS:
        windows.append({"at": HALF - x, "w": w0, "bottom": w1, "top": head, "kind": "window", "frame": "Wood",
                        "mullions": "Wood", "cols": 2, "rows": 3, "blinds": True, "blinds_side": -1, "slat": "BlindSlat",
                        "sill": "Wood", "glass": "Glass"})
    door = {"at": P.DOOR_Z + HALF, "w": 6.0, "bottom": 0.0, "top": 9.0, "kind": "gap"}  # the east wall runs north to south
    runs = [
        ((-HALF, -HALF), (HALF, -HALF), []),
        ((HALF, -HALF), (HALF, HALF), [door]),
        ((HALF, HALF), (-HALF, HALF), windows),
        ((-HALF, HALF), (-HALF, -HALF), []),
    ]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="Damask", openings=ops, trim_s=TRIM)
    # The records door fills its gap: a closed double door in a moulded case (and the wall behind).
    x = P.IN
    z = P.DOOR_Z
    s.box("ConcreteDark", (HALF + 0.2, 4.5, z), (0.4, 9.0, 6.2))
    for dz in (-1.5, 1.5):
        s.box("WoodPanel", (x - 0.08, 4.4, z + dz), (0.16, 8.8, 2.95))
        s.box("Wood", (x - 0.2, 4.4, z + dz), (0.1, 6.6, 2.1))
        s.box("Brass", (x - 0.3, 4.2, z + dz * 0.2), (0.14, 1.2, 0.16))
    for dz in (-3.25, 3.25):
        s.box("Wood", (x - 0.14, 4.7, z + dz), (0.28, 9.4, 0.5))
    s.box("Wood", (x - 0.14, 9.3, z), (0.28, 0.6, 7.0))
    s.collider((x - 0.2, 4.5, z), (0.4, 9.0, 6.0), 0.0, True, "WoodPanel")
    s.box("Brass", (x - 0.1, 10.4, z), (0.1, 0.7, 3.0))
    s.sign((x - 0.18, 10.4, z), 90, 2.8, 0.55, "RECORDS", "SpecialElite", (30, 22, 14), None)


def pilasters(s):
    """Walnut pilasters on the damask, brass capitals, between the room's features."""
    runs = {
        "n": [-26.5, 26.5],
        "e": [-28.2, 27.9],
        "s": [-25.0, -8.0, 8.0, 25.0],
        "w": [-25.5, -16.0, 16.0, 25.5],
    }
    for side, spots in runs.items():
        for u in spots:
            if side == "n":
                x, z, rot = u, -P.IN, 180.0
            elif side == "s":
                x, z, rot = u, P.IN, 0.0
            elif side == "e":
                x, z, rot = P.IN, u, 90.0
            else:
                x, z, rot = -P.IN, u, -90.0
            a = math.radians(rot)
            fx, fz = -math.sin(a), -math.cos(a)
            cx, cz = x + fx * 0.25, z + fz * 0.25
            s.box("WoodPanel", (cx, 6.1, cz), (1.3, 11.4, 0.5), rot, skip=("-y",))
            s.box("Brass", (cx + fx * 0.05, 11.55, cz + fz * 0.05), (1.6, 0.5, 0.6), rot)
            s.box("Wood", (cx + fx * 0.05, 0.4, cz + fz * 0.05), (1.6, 0.8, 0.6), rot)


def ceiling(s):
    kit.ceiling(s, -HALF, -HALF, HALF, HALF, H, "PlasterDark", beams=7.5, beam_mat="Wood", beam_depth=1.2, beam_w=0.8)
    # The rose over the table: a deep octagonal well, its rim moulded.
    for k in range(8):
        a0, a1 = 2 * math.pi * k / 8, 2 * math.pi * (k + 1) / 8
        p0 = (math.cos(a0) * 6.5, math.sin(a0) * 6.5)
        p1 = (math.cos(a1) * 6.5, math.sin(a1) * 6.5)
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        rot = math.degrees(math.atan2(-(p1[1] - p0[1]), p1[0] - p0[0]))
        s.box("Wood", (mid[0], H - 1.5, mid[1]), (math.dist(p0, p1) + 0.4, 0.8, 0.6), rot)
    s.lathe("Brass", (0.0, H - 2.1, 0.0), [(5.4, 0.0), (5.6, 0.2), (5.4, 0.4)], 32, caps=(False, False))
    kit.spotlight_rig(s, 0.0, H - 1.6, 0.0, range_=28, brightness=5, angle=62)
    # The brass halo: a ring hung on four rods, warm lamps under it.
    y = H - 4.2
    r = 9.0
    for k in range(48):
        a0, a1 = 2 * math.pi * k / 48, 2 * math.pi * (k + 1) / 48
        s.tube("Brass", (math.cos(a0) * r, y, math.sin(a0) * r), (math.cos(a1) * r, y, math.sin(a1) * r), 0.16, 6, caps=False)
    for k in range(16):
        a = 2 * math.pi * k / 16
        s.lathe("CreamTrim", (math.cos(a) * r, y - 0.55, math.sin(a) * r), [(0.34, 0.0), (0.2, 0.5)], 10, caps=(False, False))
        s.lathe("NeonWarm", (math.cos(a) * r, y - 0.5, math.sin(a) * r), [(0.0, 0.0), (0.12, 0.1), (0.0, 0.3)], 8)
    for k in range(4):
        a = 2 * math.pi * k / 4 + math.pi / 4
        s.tube("Brass", (math.cos(a) * r, y, math.sin(a) * r), (math.cos(a) * r, H - 1.2, math.sin(a) * r), 0.05, 6)
        s.light("point", (math.cos(a) * r, y - 0.8, math.sin(a) * r), (255, 214, 170), 22, 0.55)


def gallery(s):
    """The Specters' mezzanine: an iron deck on walnut brackets round three walls and the north
    corners, a railing of balusters along its edge. Nothing on it collides (Specters fly)."""
    y, d = P.GALLERY_Y, P.GALLERY_D
    edge = P.IN
    inner = edge - d
    gap = P.GALLERY_GAP
    slabs = [
        ((edge - d / 2, 0.0), (d, 2 * edge)),  # east
        ((0.0, edge - d / 2), (2 * edge - 2 * d, d)),  # south
        ((-edge + d / 2, 0.0), (d, 2 * edge)),  # west
        (((edge - d + gap) / 2, -edge + d / 2), (edge - d - gap, d)),  # north-east corner
        ((-(edge - d + gap) / 2, -edge + d / 2), (edge - d - gap, d)),  # north-west corner
    ]
    for (x, z), (sx, sz) in slabs:
        s.box("MetalFloor", (x, y - 0.2, z), (sx, 0.4, sz), mats={"-y": "BlackMetal"})
    # The walnut fascia on the deck's open edges.
    fascia = [((inner, -edge + d), (inner, edge - d)), ((inner, edge - d), (-inner, edge - d)),
              ((-inner, edge - d), (-inner, -edge + d)), ((gap, -inner), (inner, -inner)), ((-inner, -inner), (-gap, -inner))]
    for (ax, az), (bx, bz) in fascia:
        mid = ((ax + bx) / 2, (az + bz) / 2)
        length = math.dist((ax, az), (bx, bz))
        rot = 0.0 if abs(az - bz) < 1e-3 else 90.0
        s.box("Wood", (mid[0], y - 0.35, mid[1]), (length + (0.3 if rot == 0 else 0.0), 0.7, 0.3) if rot == 0 else
              (0.3, 0.7, length), 0.0)
    rail = [(gap, -inner), (inner, -inner), (inner, inner), (-inner, inner), (-inner, -inner), (-gap, -inner)]
    kit.railing(s, rail, 3.0, "BlackMetal", 1.2, base=y, collide=False)
    for x in (gap, -gap):
        s.tube("BlackMetal", (x, y, -inner), (x, y, -edge), 0.12, 8)
        s.tube("BlackMetal", (x, y + 3.0, -inner), (x, y + 3.0, -edge), 0.12, 8)
    s.tube("Brass", (gap, y + 3.0, -inner), (inner, y + 3.0, -inner), 0.14, 8)
    # Brackets under the deck: curved walnut struts from the wall.
    # (Placed clear of the board, the photographs, the windows, the clock and the speakers.)
    spots = [(edge, z, (-1, 0)) for z in (-18.5, -10.2, 10.2, 27.0)]
    spots += [(x, edge, (0, -1)) for x in (-24.0, -6.0, 6.0, 24.0)]
    spots += [(-edge, z, (1, 0)) for z in (-24.0, -16.0, -4.0, 4.0, 16.0, 24.0)]
    spots += [(x, -edge, (0, 1)) for x in (-23.0, 23.0)]
    for x, z, (ox, oz) in spots:
        low = (x, y - 3.4, z)
        mid = (x + ox * 1.6, y - 1.4, z + oz * 1.6)
        tip = (x + ox * (d - 0.4), y - 0.4, z + oz * (d - 0.4))
        s.tube("Wood", low, mid, 0.18, 6)
        s.tube("Wood", mid, tip, 0.16, 6)
        s.box("Brass", (x + ox * 0.1, y - 3.5, z + oz * 0.1), (0.5 if ox == 0 else 0.2, 0.3, 0.5 if oz == 0 else 0.2))


def build(s):
    floor(s)
    walls(s)
    pilasters(s)
    ceiling(s)
    gallery(s)
