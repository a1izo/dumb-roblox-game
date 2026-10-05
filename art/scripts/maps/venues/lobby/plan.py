"""The Grey Realm's plan, in local studs: x east, z south (north is -z), y up; the lobby's origin.

A dead island floating in a grey sea of cloud: the walkable part is a rough island about 320 studs
across with sheer cliffs all round (invisible walls follow its edge) and its roots hanging into the
fog. Two small islets, each reached by an old stone bridge, carry the mini-games. Beyond them
there is no ground at all: floating rocks, rock spires and arches, walls of cloud and, far off in
the haze, one colossal blade standing in a rock.

- The south: the spawn terrace, a broken ruin a few steps above the plaza; players appear on it
  facing north, over the island, to the colossal blade between two twisted columns.
- The middle: an old flagstone plaza, a plinth with the Grimoire lying on it, and round the
  plaza six steles carrying the game's boards.
- North: the title monolith; behind it, up on a mesa nobody can climb, the bone throne.
- South-west: the Academy, a ring of broken pillars with the practice altars and effigies.
- East: the rift, a hole in the island looking down on Kagegaoka at night far below (the stone
  toss stands at its rim).
- North-west: the dice rock; the cleft over the cloud sea. North-east: the needle ledge, where a
  small blade glows. South-east: a colossal carcass, its ribcage arching over the ash.
- West islet (over the west bridge): the Spire Ascent. North-east islet: the rune courtyard.

Every place the venue modules use is set here. Run it on its own (python
art/scripts/maps/venues/lobby/plan.py) to check that nothing overlaps and it all stays inside the
island, clear of the rift.
"""

import math
import os
import sys

if __name__ == "__main__":
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

from maps import geo2d as g2  # noqa: E402

# Everything walkable: the island, its two islets and the parkour's climb (y up to ~125).
BOUNDS = ((-380.0, -70.0, -290.0), (270.0, 150.0, 190.0))


def rim_r(a):
    """The island's radius at angle a (radians, 0 = east, 90 degrees = south)."""
    return 158.0 + 9.0 * math.sin(3 * a + 0.7) + 5.0 * math.sin(5 * a + 2.1) + 3.0 * math.sin(11 * a)


def rim_at(deg, inset=0.0):
    """The (x, z) point `inset` studs inside the island's rim along the direction `deg`."""
    a = math.radians(deg)
    r = rim_r(a) - inset
    return (round(math.cos(a) * r, 2), round(math.sin(a) * r, 2))


def _basin():
    n = 56
    return [rim_at(360.0 * k / n) for k in range(n)]


BASIN = _basin()  # the walkable ground's edge (counter-clockwise from east)

# The plaza and the Grimoire's plinth.
PLAZA_C = (0.0, 8.0)
PLAZA_R = 30.0
PLINTH = (0.0, -8.0, 8.0, 11.0, 3.4)  # x, z, width (x), depth (z), height
GRIMOIRE_SCALE = 2.2

# The spawn terrace: raised a few studs over the plaza's south side, wide steps down its north edge.
TERRACE = (0.0, 62.0, 46.0, 20.0, 11.0)  # x, z, width (x), depth (z), height of its top
TERRACE_STEPS = ((0.0, 52.0), (0.0, 38.6), 22.0)  # top of the flight (y = height), foot (y = 0), width
SPAWN = (0.0, 63.0)  # players appear here facing north (rot 0)
SPAWNS = [(x, z) for z in (58.0, 64.0) for x in (-9.0, -3.0, 3.0, 9.0)]

# The two twisted columns that frame the first view (x, z, radius, height, seed).
COLUMNS = [(-84.0, -28.0, 5.6, 62.0, 31), (74.0, -44.0, 5.0, 68.0, 32)]

# The title monolith (its face at MONO_FACE, facing south) and the throne's mesa.
MONO = (0.0, -66.0, 52.0, 6.0, 30.0)  # x, z, width, thickness, height
MONO_FACE = MONO[1] + MONO[3] / 2
TITLE = (0.0, 17.0, MONO_FACE + 0.35, 180.0, 44.0, 9.0)  # x, y, z, rot, w, h (the game writes it)
TAGLINE = (0.0, 10.5, MONO_FACE + 0.35, 180.0, 36.0, 3.0)
THRONE_MESA = (58.0, -112.0, 19.0, 14.0)  # x, z, radius, height
THRONE_ROT = 154.0

# The two islets (x, z, radius) and the bridges to them from the island's rim.
ISLET_RUNE = (214.0, -216.0, 40.0)
ISLET_PARKOUR = (-326.0, -2.0, 38.0)
BRIDGE_W = 10.0


def _bridge(islet):
    """(start on the island, end on the islet), a straight span along the line between their middles."""
    deg = math.degrees(math.atan2(islet[1], islet[0])) % 360.0
    a = rim_at(deg, 3.0)
    d = math.hypot(islet[0], islet[1])
    ux, uz = islet[0] / d, islet[1] / d
    b = (islet[0] - ux * (islet[2] - 3.0), islet[1] - uz * (islet[2] - 3.0))
    return a, b


BRIDGE_RUNE = _bridge(ISLET_RUNE)
BRIDGE_PARKOUR = _bridge(ISLET_PARKOUR)

# The steles: name -> (x, z, rot facing where people come from, board w, board h). The board's middle is 11 up.
STELES = {
    "howto": (-47.0, 4.0, -90.0, 30.0, 14.0),
    "weekly": (-38.0, -27.0, -131.8, 14.0, 14.0),
    "quests": (-38.0, 40.0, -51.7, 14.0, 14.0),
    "nextCase": (47.0, 4.0, 90.0, 26.0, 8.0),
    "wins": (38.0, -27.0, 131.8, 14.0, 14.0),
    "xp": (38.0, 40.0, 51.7, 14.0, 14.0),
    # The mini-game boards, by the bridge heads (facing the plaza).
    "parkourBoard": (-136.0, -28.0, -90.0, 14.0, 14.0),
    "runesBoard": (90.0, -58.0, 126.0, 14.0, 14.0),
}
STELE_T = 2.4  # the stone's thickness
BOARD_Y = 11.0

# The Academy: a ring of broken pillars, its gate facing the plaza.
ACADEMY_C = (-80.0, 84.0)
ACADEMY_R = 25.0  # the pillars' ring; the flagstones reach 28
ALTAR_R = 16.0
GATE_DIR = math.degrees(math.atan2(PLAZA_C[1] - ACADEMY_C[1], PLAZA_C[0] - ACADEMY_C[0]))  # degrees in the x-z plane

# The rift: a hole through the island (convex), its guard 3.5 outside its edge.
RIFT_C = (98.0, 22.0)
RIFT_AXES = (23.0, 15.0)
RIFT_TURN = 20.0
RIFT_DEPTH = 50.0  # the rock walls down into it, to the island's underside
BELOW_Y = -260.0  # Kagegaoka, far beneath
GUARD = 3.5
PLATE = 50.0  # the island is this thick (its underside is a cap at -PLATE)


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
TOSS = (64.0, 42.0, -59.5)  # the stone-toss cairn (x, z) and the rot facing the rift's middle
RIFT_MID = g2.centroid(RIFT)

# The dice rock and the carcass.
DICE_ROCK = (-66.0, -44.0, 3.6, 2.4)  # x, z, radius, height of its flat top
DICE_SEATS = [(DICE_ROCK[0] + math.cos(math.radians(30 + k * 90)) * (DICE_ROCK[2] + 2.6),
               DICE_ROCK[1] + math.sin(math.radians(30 + k * 90)) * (DICE_ROCK[2] + 2.6)) for k in range(4)]
CARCASS_SKULL = (14.0, 116.0, 70.0)  # x, z, rot (facing west-north-west, its spine running east)
SPINE = [(46.0, 118.0), (62.0, 112.0), (78.0, 108.0), (94.0, 106.0), (110.0, 106.0)]
RIB_SPAN = 13.0  # how far each rib's foot lands from the spine
SPINE_Y = 17.0

# The two vista ledges at the rim: the cleft over the cloud sea (north-west) and the needle ledge with
# the small glowing blade (north-east). x, z of each ledge's middle, and the direction outwards (degrees).
CLEFT_DEG = 236.0
NEEDLE_DEG = 334.0
CLEFT = rim_at(CLEFT_DEG, 22.0)
NEEDLE = rim_at(NEEDLE_DEG, 22.0)
LEDGE_R = 10.0

# Rock outcrops inside the island: x, z, radius, height, seed.
OUTCROPS = [
    (-124.0, 52.0, 12.0, 24.0, 11),
    (-128.0, -88.0, 13.0, 34.0, 14),
    (16.0, -128.0, 9.0, 20.0, 15),
    (-12.0, 96.0, 4.5, 6.0, 16),
    (60.0, 60.0, 5.0, 7.5, 17),
    (-60.0, -104.0, 6.0, 9.0, 18),
    (130.0, 60.0, 8.0, 14.0, 19),
]

# The Spire Ascent: ten checkpoints climbing a spiral of floating stones round the islet's spire.
PK_CENTER = (ISLET_PARKOUR[0], ISLET_PARKOUR[1])
PK_TOP = 118.0  # the finish's height

# The rune courtyard: nine tiles (3 x 3) of 7 studs with 1.8 between them, on the islet's far side.
RUNE_CENTER = (ISLET_RUNE[0], ISLET_RUNE[1])
RUNE_TILE = 7.0
RUNE_GAP = 1.8

# Where the checks measure the walk (x, y, z pairs): the spawn to each islet's far side, and across the island.
CORNERS = [[(0.0, 11.0, 63.0), (ISLET_RUNE[0] + 22.0, 0.0, ISLET_RUNE[1] - 22.0)],
           [(0.0, 11.0, 63.0), (ISLET_PARKOUR[0] - 22.0, 0.0, ISLET_PARKOUR[1] + 10.0)],
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
        "terrace": g2.rect(TERRACE[0], TERRACE[1], TERRACE[2], TERRACE[3]),
        "terrace steps": g2.rect(TERRACE_STEPS[0][0], (TERRACE_STEPS[0][1] + TERRACE_STEPS[1][1]) / 2, TERRACE_STEPS[2],
                                 TERRACE_STEPS[0][1] - TERRACE_STEPS[1][1]),
        "toss cairn": circle(TOSS[:2], 3.0),
        "cleft ledge": circle(CLEFT, LEDGE_R),
        "needle ledge": circle(NEEDLE, LEDGE_R),
    }
    for k, (x, z, r, h, seed) in enumerate(COLUMNS):
        items[f"column {k}"] = circle((x, z), r + 1.5)
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
    for name in ("plinth", "monolith", "rift guard", "dice rock", "apple tree", "terrace", "toss cairn", "cleft ledge",
                 "needle ledge"):
        if not all(g2.contains(basin, p) for p in items[name]):
            problems.append(f"{name} leaves the island")
    for x, z in SPAWNS + [SPAWN]:
        if not g2.contains(items["terrace"], (x, z)):
            problems.append(f"spawn {(x, z)} is off the terrace")
        for name, poly in items.items():
            if name != "terrace" and g2.contains(poly, (x, z)):
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
        if name.endswith("Board"):
            continue
        if math.dist((x, z), PLAZA_C) < PLAZA_R + 4:
            problems.append(f"stele {name} stands on the plaza")
    # The bridges: their heads inside the island, clear of every solid, and the islets clear of the island.
    for name, (a, b) in (("rune", BRIDGE_RUNE), ("parkour", BRIDGE_PARKOUR)):
        deck = g2.rect((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, math.dist(a, b), BRIDGE_W,
                       math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0])))
        for iname, poly in items.items():
            hit = g2.intersect(g2.ccw(deck), g2.ccw(poly)) if g2.is_convex(poly) else []
            if hit and abs(g2.area(hit)) > 0.5:
                problems.append(f"bridge {name} runs through {iname}")
        if math.dist(a, b) < 60.0:
            problems.append(f"bridge {name} is short ({math.dist(a, b):.0f})")
    return sorted(set(problems))


if __name__ == "__main__":
    found = check()
    print(f"{len(footprints())} footprints, {len(found)} problem(s)")
    for p in found:
        print("  -", p)
    print("bridge rune", BRIDGE_RUNE, "bridge parkour", BRIDGE_PARKOUR)
    print("cleft", CLEFT, "needle", NEEDLE)
