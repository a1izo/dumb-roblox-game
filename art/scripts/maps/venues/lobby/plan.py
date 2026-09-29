"""The Grey Realm's plan, in local studs: x east, z south (north is -z), y up; the lobby's origin.

An ashen plain under a flat grey sky. The walkable part is a rough basin about 320 studs across,
ringed by rock outcrops and bone-stake lines (invisible walls follow its edge); past them the plain,
its rock spires, mesas and the bones of colossal things run on into the haze.

- The middle: an old flagstone plaza where players appear (facing north), a plinth with the
  Grimoire lying on it, and round the plaza six steles carrying the game's boards.
- North: the title monolith; behind it, up on a mesa nobody can climb, the bone throne.
- South-west: the Academy, a ring of broken pillars with the practice altars and effigies.
- East: the rift, a hole in the ground looking down on Kagegaoka at night far below.
- North-west: the dice rock. South-east: a colossal carcass, its ribcage arching over the ash.

Every place the venue modules use is set here. Run it on its own (python
art/scripts/maps/venues/lobby/plan.py) to check that nothing overlaps and it all stays inside the
basin, clear of the rift.
"""

import math
import os
import sys

if __name__ == "__main__":
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

from maps import geo2d as g2  # noqa: E402

BOUNDS = ((-182.0, -6.0, -182.0), (182.0, 90.0, 182.0))


# A bay of rock cut deep into the basin's west and north-west side (where the plain breaks up into
# boulder fields): its middle (degrees, 0 = east, 90 = south), half its width, how deep it cuts.
BAY = (200.0, 55.0, 62.0)


def bay_depth(a_deg):
    d = abs((a_deg - BAY[0] + 180.0) % 360.0 - 180.0)
    return BAY[2] * 0.5 * (1 + math.cos(math.pi * d / BAY[1])) if d < BAY[1] else 0.0


def in_bay(x, z):
    """True for a point on the basin's edge along the bay (its rock wall)."""
    return bay_depth(math.degrees(math.atan2(z, x)) % 360.0) > 6.0


def _basin():
    pts = []
    n = 40
    for k in range(n):
        a = 2 * math.pi * k / n
        r = 158.0 + 9.0 * math.sin(3 * a + 0.7) + 5.0 * math.sin(5 * a + 2.1) + 3.0 * math.sin(11 * a)
        r -= bay_depth(math.degrees(a))
        pts.append((round(math.cos(a) * r, 2), round(math.sin(a) * r, 2)))
    return pts


BASIN = _basin()  # the walkable ground's edge (counter-clockwise from east)

# The plaza, the spawn and the Grimoire's plinth.
PLAZA_C = (0.0, 8.0)
PLAZA_R = 30.0
SPAWN = (0.0, 20.0)  # players appear here facing north (rot 0)
SPAWNS = [(x, z) for z in (16.0, 22.0) for x in (-9.0, -3.0, 3.0, 9.0)]
PLINTH = (0.0, -8.0, 8.0, 11.0, 3.4)  # x, z, width (x), depth (z), height
GRIMOIRE_SCALE = 2.2

# The title monolith (its face at MONO_FACE, facing south) and the throne's mesa.
MONO = (0.0, -66.0, 52.0, 6.0, 30.0)  # x, z, width, thickness, height
MONO_FACE = MONO[1] + MONO[3] / 2
TITLE = (0.0, 17.0, MONO_FACE + 0.35, 180.0, 44.0, 9.0)  # x, y, z, rot, w, h (the game writes it)
TAGLINE = (0.0, 10.5, MONO_FACE + 0.35, 180.0, 36.0, 3.0)
THRONE_MESA = (58.0, -112.0, 19.0, 14.0)  # x, z, radius, height
THRONE_ROT = 154.0

# The steles: name -> (x, z, rot facing the plaza, board w, board h). The board's middle is 11 up.
STELES = {
    "howto": (-47.0, 4.0, -90.0, 30.0, 14.0),
    "weekly": (-38.0, -27.0, -131.8, 14.0, 14.0),
    "quests": (-38.0, 40.0, -51.7, 14.0, 14.0),
    "nextCase": (47.0, 4.0, 90.0, 26.0, 8.0),
    "wins": (38.0, -27.0, 131.8, 14.0, 14.0),
    "xp": (38.0, 40.0, 51.7, 14.0, 14.0),
}
STELE_T = 2.4  # the stone's thickness
BOARD_Y = 11.0

# The Academy: a ring of broken pillars, its gate facing the plaza.
ACADEMY_C = (-80.0, 84.0)
ACADEMY_R = 25.0  # the pillars' ring; the flagstones reach 28
ALTAR_R = 16.0
GATE_DIR = math.degrees(math.atan2(PLAZA_C[1] - ACADEMY_C[1], PLAZA_C[0] - ACADEMY_C[0]))  # degrees in the x-z plane

# The rift: a hole in the ground (convex), its guard 3.5 outside its edge.
RIFT_C = (98.0, 22.0)
RIFT_AXES = (23.0, 15.0)
RIFT_TURN = 20.0
RIFT_DEPTH = 38.0  # the rock walls down into it
BELOW_Y = -260.0  # Kagegaoka, far beneath
GUARD = 3.5


def _rift():
    pts = []
    n = 16
    t = math.radians(RIFT_TURN)
    for k in range(n):
        a = 2 * math.pi * k / n
        wob = 1.0 + 0.07 * math.sin(3 * a + 1.3) + 0.04 * math.sin(5 * a)
        x, z = math.cos(a) * RIFT_AXES[0] * wob, math.sin(a) * RIFT_AXES[1] * wob
        pts.append((RIFT_C[0] + x * math.cos(t) - z * math.sin(t), RIFT_C[1] + x * math.sin(t) + z * math.cos(t)))
    return g2.convex_hull(pts)


RIFT = _rift()


def grown(poly, d):
    """A convex polygon pushed out by d along each vertex's direction from its middle."""
    cx, cz = g2.centroid(poly)
    out = []
    for x, z in poly:
        dx, dz = x - cx, z - cz
        r = math.hypot(dx, dz)
        out.append((x + dx / r * d, z + dz / r * d))
    return out


RIFT_GUARD = grown(RIFT, GUARD)
APPLE_TREE = (76.0, -6.0)

# The dice rock and the carcass.
DICE_ROCK = (-66.0, -44.0, 3.6, 2.4)  # x, z, radius, height of its flat top
CARCASS_SKULL = (14.0, 116.0, 70.0)  # x, z, rot (facing west-north-west, its spine running east)
SPINE = [(46.0, 118.0), (62.0, 112.0), (78.0, 108.0), (94.0, 106.0), (110.0, 106.0)]
RIB_SPAN = 13.0  # how far each rib's foot lands from the spine
SPINE_Y = 17.0

# Rock outcrops inside the basin: x, z, radius, height, seed.
OUTCROPS = [
    (-122.0, 18.0, 12.0, 24.0, 11),
    (122.0, -62.0, 10.0, 17.0, 12),
    (-44.0, 132.0, 7.0, 11.0, 13),
    (-128.0, -88.0, 13.0, 34.0, 14),
    (16.0, -128.0, 9.0, 20.0, 15),
    (-12.0, 96.0, 4.5, 6.0, 16),
    (60.0, 60.0, 5.0, 7.5, 17),
    (-60.0, -104.0, 6.0, 9.0, 18),
    (130.0, 60.0, 8.0, 14.0, 19),
]

# Where the checks measure the walk across (x, y, z pairs).
CORNERS = [[(-88.0, 0.0, -14.0), (140.0, 0.0, 30.0)], [(-90.0, 0.0, -118.0), (96.0, 0.0, 118.0)],
           [(-100.0, 0.0, 110.0), (104.0, 0.0, -96.0)]]


def facing(rot):
    """The unit (x, z) direction rot faces (rot 0 faces -z)."""
    a = math.radians(rot)
    return (-math.sin(a), -math.cos(a))


def rot_towards(frm, to):
    dx, dz = to[0] - frm[0], to[1] - frm[1]
    return math.degrees(math.atan2(-dx, -dz))


def altars():
    """The seven practice altars: (x, z, rot facing the ring's middle), spread over the ring's back."""
    gate = math.radians(GATE_DIR)
    out = []
    for k in range(7):
        a = gate + math.pi + math.radians(-96 + k * 32)
        x, z = ACADEMY_C[0] + math.cos(a) * ALTAR_R, ACADEMY_C[1] + math.sin(a) * ALTAR_R
        out.append((x, z, rot_towards((x, z), ACADEMY_C)))
    return out


def effigies():
    """The three effigies across the ring's middle, facing the gate."""
    gate = math.radians(GATE_DIR)
    side = (-math.sin(gate), math.cos(gate))
    rot = rot_towards(ACADEMY_C, PLAZA_C)
    return [(ACADEMY_C[0] + side[0] * d, ACADEMY_C[1] + side[1] * d, rot) for d in (-7.0, 0.0, 7.0)]


def circle(c, r, n=16):
    return [(c[0] + math.cos(2 * math.pi * k / n) * r, c[1] + math.sin(2 * math.pi * k / n) * r) for k in range(n)]


def footprints():
    """name -> polygon of everything solid on the ground, for the overlap check."""
    items = {
        "plinth": g2.rect(PLINTH[0], PLINTH[1], PLINTH[2], PLINTH[3]),
        "monolith": g2.rect(MONO[0], MONO[1], MONO[2] + 22.0, MONO[3] + 10.0),  # its base and tusks too
        "throne mesa": circle(THRONE_MESA[:2], THRONE_MESA[2]),
        "rift guard": RIFT_GUARD,
        "dice rock": circle(DICE_ROCK[:2], DICE_ROCK[2] + 5.0),
        "carcass skull": circle(CARCASS_SKULL[:2], 12.0),
        "carcass ribs": g2.convex_hull([(x + dx, z + dz) for x, z in SPINE for dx, dz in
                                        ((0.0, -RIB_SPAN - 3.0), (0.0, RIB_SPAN + 3.0), (-3.0, 0.0), (3.0, 0.0))]),
        "apple tree": circle(APPLE_TREE, 2.0),
    }
    for name, (x, z, rot, w, h) in STELES.items():
        items["stele " + name] = g2.rect(x, z, w + 4.0, STELE_T, rot)
    for k, (x, z, r, h, seed) in enumerate(OUTCROPS):
        items[f"outcrop {k}"] = circle((x, z), r)
    for k, (x, z, rot) in enumerate(altars()):
        items[f"altar {k + 1}"] = g2.rect(x, z, 5.6, 2.9, rot)
    return items


def check():
    problems = []
    basin = BASIN
    items = footprints()
    names = list(items)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            hit = g2.intersect(g2.ccw(items[a]), g2.ccw(items[b])) if g2.is_convex(items[b]) else []
            if hit and abs(g2.area(hit)) > 0.5:
                problems.append(f"{a} overlaps {b}")
    for name in ("plinth", "monolith", "rift guard", "dice rock", "apple tree"):
        if not all(g2.contains(basin, p) for p in items[name]):
            problems.append(f"{name} leaves the basin")
    for x, z in SPAWNS + [SPAWN]:
        if math.dist((x, z), PLAZA_C) > PLAZA_R - 3:
            problems.append(f"spawn {(x, z)} is off the plaza")
        for name, poly in items.items():
            if g2.contains(poly, (x, z)):
                problems.append(f"spawn {(x, z)} stands in {name}")
    # The practice altars: 5 studs clear on the worker's side, and the effigies clear of that.
    for k, (x, z, rot) in enumerate(altars()):
        fx, fz = facing(rot)
        wx, wz = x + fx * 2.6, z + fz * 2.6
        for ex, ez, _ in effigies():
            if math.dist((wx, wz), (ex, ez)) < 5.0:
                problems.append(f"altar {k + 1}'s worker spot is within 5 of an effigy")
        if math.dist((x, z), ACADEMY_C) + 3.2 > ACADEMY_R - 1.5:
            problems.append(f"altar {k + 1} reaches the pillars")
    for name, (x, z, rot, w, h) in STELES.items():
        if math.dist((x, z), PLAZA_C) < PLAZA_R + 4:
            problems.append(f"stele {name} stands on the plaza")
    return sorted(set(problems))


if __name__ == "__main__":
    found = check()
    print(f"{len(footprints())} footprints, {len(found)} problem(s)")
    for p in found:
        print("  -", p)
