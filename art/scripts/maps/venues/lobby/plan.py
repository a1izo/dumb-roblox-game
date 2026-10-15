"""The Grey Realm's plan, in local studs: x east, z south (north is -z), y up; the lobby's origin.

A never-ending wasteland under a grey sky: cracked ash running to the horizon, huge twisted columns,
mesas and spires rising out of the fog, and walls of cloud on the skyline. The part people can walk is a
rough basin about 320 studs across, bordered by a ridge of rock and needles (an invisible wall follows its
edge); past the ridge the plain goes on, out of reach. Two ruined plateaus stand out on the plain, each
reached by an old stone causeway that crosses a deep chasm; they carry the mini-games.

- The south: the spawn terrace, a broken ruin a few steps above the plaza; players appear on it facing
  north, over the basin, to the colossal blade standing in its mound between two twisted columns.
- The middle: an old flagstone plaza, open, a ring of twelve candle stones at its middle (one burns for each
  player who is ready). Round the plaza, where boards once stood, five low stone bases carry the tableaux
  (stone figures the game stands on them, acting out how a case goes), and a sixth place the bell of
  Death's mark.
- North: the title monolith; behind it, up on a mesa nobody can climb, the bone throne (the game seats the
  player with the most wins on it, in stone); at the mesa's foot a low slab, the one board left: Most Wins.
- South-west: the Academy, a ring of broken pillars with the practice altars and effigies.
- East: the rift, a hole in the ground looking down on Kagegaoka at night far below (the stone toss stands at
  its rim). Its rim is open: a throat of rock drops through the ground into the cloud the realm floats on;
  under the cloud lies the night sky over the city, and far beneath the rift's middle a hall's roof with a
  lit ring is where a dive ends (about 650 studs down).
- North-west: a wayside rock; the cleft. North-east: the needle ledge, where a small blade glows.
  South-east: a colossal carcass, its ribcage arching over the ash; two slates face each other under it (the
  name duel).
- West plateau (over the west causeway): the Spire Ascent. North-east plateau: the rune courtyard.
- Seven grey apples lie about: one under the withered tree, the rest in the far corners.

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

# Everything walkable: the basin, its two plateaus and the parkour's climb (y up to ~130).
BOUNDS = ((-380.0, -6.0, -290.0), (270.0, 150.0, 190.0))
FAR = 1500.0  # how far the plain runs (the fog closes well before)


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

# The plaza, and the ring of candle stones at its middle (the game lights one for each player who is ready).
PLAZA_C = (0.0, 8.0)
PLAZA_R = 30.0
READY_R = 8.0  # the ring's radius
READY_COUNT = 12  # one stone for each player a case can hold
READY_H = 1.7  # a stone's height (low: the view from the terrace to the title goes over them)


def ready_stones():
    """The candle stones (x, z): from the one nearest the terrace's steps, clockwise seen from above."""
    return [(round(PLAZA_C[0] + math.cos(math.radians(90.0 + k * 360.0 / READY_COUNT)) * READY_R, 2),
             round(PLAZA_C[1] + math.sin(math.radians(90.0 + k * 360.0 / READY_COUNT)) * READY_R, 2))
            for k in range(READY_COUNT)]


# The five tableaux (x, z), where boards once stood round the plaza: low round bases the game stands its stone
# figures on, each facing the plaza's middle, in the order the story is told (clockwise from the steps). The
# sixth such place holds the bell of Death's mark.
TABLEAUX = [(-38.0, 40.0), (-47.0, 4.0), (-38.0, -27.0), (38.0, -27.0), (47.0, 4.0)]
TABLEAU_R = 6.0
TABLEAU_H = 0.7
BELL = (38.0, 40.0)
BELL_R = 3.6  # its base

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
ISLET_RUNE = (214.0, -216.0, 40.0)  # the plateaus: x, z, radius
ISLET_PARKOUR = (-326.0, -2.0, 38.0)
PLATEAU_H = 7.0  # how high their tops stand over the plain
BRIDGE_W = 10.0  # the causeways' width
STAIR_RUN = 12.0  # the flight at a causeway's far end, up onto its plateau


def _bridge(islet):
    """(start on the basin's rim, end on the plateau), a straight causeway along the line between their
    middles."""
    deg = math.degrees(math.atan2(islet[1], islet[0])) % 360.0
    a = rim_at(deg, 3.0)
    d = math.hypot(islet[0], islet[1])
    ux, uz = islet[0] / d, islet[1] / d
    b = (islet[0] - ux * (islet[2] - 7.0), islet[1] - uz * (islet[2] - 7.0))
    return a, b


BRIDGE_RUNE = _bridge(ISLET_RUNE)
BRIDGE_PARKOUR = _bridge(ISLET_PARKOUR)


def _chasm(bridge):
    """(x, z, along, across, rot): the chasm under a causeway: `along` studs of it along the causeway,
    `across` studs wide the other way, its middle 45 % of the way along the part before the stairs."""
    a, b = bridge
    length = math.dist(a, b) - STAIR_RUN
    ux, uz = (b[0] - a[0]) / math.dist(a, b), (b[1] - a[1]) / math.dist(a, b)
    t = length * 0.45
    return (a[0] + ux * t, a[1] + uz * t, 34.0, 84.0, math.degrees(math.atan2(-uz, ux)))


CHASMS = [_chasm(BRIDGE_RUNE), _chasm(BRIDGE_PARKOUR)]
CHASM_DEPTH = 72.0


def chasm_poly(c):
    return g2.rect(c[0], c[1], c[2], c[3], c[4])


STELE_T = 2.4  # a stele's thickness

# The Academy: a ring of broken pillars, its gate facing the plaza.
ACADEMY_C = (-80.0, 84.0)
ACADEMY_R = 25.0  # the pillars' ring; the flagstones reach 28
ALTAR_R = 16.0
GATE_DIR = math.degrees(math.atan2(PLAZA_C[1] - ACADEMY_C[1], PLAZA_C[0] - ACADEMY_C[0]))  # degrees in the x-z plane

# The rift: a hole through the island (convex), its guard 3.5 outside its edge.
RIFT_C = (98.0, 22.0)
RIFT_AXES = (23.0, 15.0)
RIFT_TURN = 20.0
RIFT_DEPTH = 76.0  # the throat of rock down through the ground, to the cloud
# The cloud the realm floats on: its underside, a flat deck at CLOUD_Y with heavy lobes hanging from it, out
# to CLOUD_FAR from the rift (past where the haze swallows it); seen from under it only, it seals the realm's
# underside in every direction. The rift's throat opens through it.
CLOUD_Y = -RIFT_DEPTH
CLOUD_FAR = 1300.0
BELOW_Y = -700.0  # Kagegaoka, far beneath (its ground)
CITY_FAR = 1100.0  # how far the city runs out from the point under the rift (studs)
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
TOSS = (64.0, 42.0, -59.5)  # the stone-toss cairn (x, z) and the rot facing the rift's middle
RIFT_MID = g2.centroid(RIFT)

# Far beneath the rift's middle: the hall whose roof a dive ends on. In the city's own units, from the point
# under the rift's middle (the city is drawn at a third of its size): half its width (x), half its depth (z)
# and its floors. It reaches past the whole opening, so whoever goes over the rim anywhere comes down on it.
LANDING = (90.0, 72.0, 13)
CITY_SCALE = 1 / 3
LANDING_Y = BELOW_Y + (LANDING[2] * 12.0 + 1.5) * CITY_SCALE  # its roof
LANDING_RING = 10.5  # the lit ring on the roof (studs)

# The wayside rock (where the dice game was) and the carcass.
WAYSIDE_ROCK = (-66.0, -44.0, 3.6, 2.4)  # x, z, radius, height of its flat top
CARCASS_SKULL = (14.0, 116.0, 70.0)  # x, z, rot (facing west-north-west, its spine running east)
SPINE = [(46.0, 118.0), (62.0, 112.0), (78.0, 108.0), (94.0, 106.0), (110.0, 106.0)]
RIB_SPAN = 13.0  # how far each rib's foot lands from the spine
SPINE_Y = 17.0


def _along(a, b, t):
    return (round(a[0] + (b[0] - a[0]) * t, 2), round(a[1] + (b[1] - a[1]) * t, 2))


# The name duel: two slates under the ribs, on the spine's line, facing each other (x, z).
DUEL = [_along(SPINE[1], SPINE[2], 0.5625), _along(SPINE[2], SPINE[3], 0.4375)]

# The two vista ledges at the rim: the cleft looking out over the plain (north-west) and the needle ledge with
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

# The Spire Ascent: ten checkpoints climbing a spiral of floating stones round the plateau's spire.
PK_CENTER = (ISLET_PARKOUR[0], ISLET_PARKOUR[1])
PK_TOP = 118.0  # the finish's height over the plateau

# The rune courtyard: nine tiles (3 x 3) of 7 studs with 1.8 between them, on the islet's far side.
RUNE_CENTER = (ISLET_RUNE[0], ISLET_RUNE[1])
RUNE_TILE = 7.0
RUNE_GAP = 1.8

# Where the checks measure the walk (x, y, z pairs): the spawn to each islet's far side, and across the island.
CORNERS = [[(0.0, 11.0, 63.0), (ISLET_RUNE[0] + 22.0, PLATEAU_H, ISLET_RUNE[1] - 22.0)],
           [(0.0, 11.0, 63.0), (ISLET_PARKOUR[0] - 22.0, PLATEAU_H, ISLET_PARKOUR[1] + 10.0)],
           [(-100.0, 0.0, 110.0), (104.0, 0.0, -96.0)]]


def facing(rot):
    """The unit (x, z) direction rot faces (rot 0 faces -z)."""
    a = math.radians(rot)
    return (-math.sin(a), -math.cos(a))


def rot_towards(frm, to):
    dx, dz = to[0] - frm[0], to[1] - frm[1]
    return math.degrees(math.atan2(-dx, -dz))


def _wins_slab():
    """At the foot of the throne's mesa, a little to the side of the line from the plaza to the throne (so it
    never stands in front of whoever sits there), facing the plaza."""
    fx, fz = facing(THRONE_ROT)
    a = math.atan2(fz, fx) + math.radians(35.0)
    d = THRONE_MESA[2] + 6.0
    x, z = THRONE_MESA[0] + math.cos(a) * d, THRONE_MESA[1] + math.sin(a) * d
    return (round(x, 2), round(z, 2), round(rot_towards((x, z), PLAZA_C), 1), 10.0, 10.0, 6.0)


# The one board left standing in the world, Most Wins: a low slab. name -> (x, z, rot facing where people come
# from, board w, board h, the board's middle above the ground).
STELES = {"wins": _wins_slab()}


def apples():
    """The seven grey apples: (x, y of the ground there, z). The first lies under the withered tree, where
    anyone finds it; the others in the far corners: the cleft, the needle ledge, by the carcass's skull, behind
    the throne's mesa, behind the spire, behind the rune courtyard."""
    ca, na = math.radians(CLEFT_DEG), math.radians(NEEDLE_DEG)
    out = [
        (APPLE_TREE[0] + 3.0, 0.0, APPLE_TREE[1] + 3.0),
        (CLEFT[0] - math.sin(ca) * 5.0, 0.0, CLEFT[1] + math.cos(ca) * 5.0),
        (NEEDLE[0] - math.sin(na) * 5.0 - math.cos(na), 0.0, NEEDLE[1] + math.cos(na) * 5.0 - math.sin(na)),
        (CARCASS_SKULL[0] - 14.0, 0.0, CARCASS_SKULL[1] - 6.0),
        (40.0, 0.0, -128.0),
    ]
    for islet, d in ((ISLET_PARKOUR, 14.5), (ISLET_RUNE, 21.5)):
        r = math.hypot(islet[0], islet[1])
        out.append((islet[0] + islet[0] / r * d, PLATEAU_H, islet[1] + islet[1] / r * d))
    return [(round(x, 2), y, round(z, 2)) for x, y, z in out]


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
        "ready ring": circle(PLAZA_C, READY_R + 1.5),
        "bell": circle(BELL, BELL_R),
        "monolith": g2.rect(MONO[0], MONO[1], MONO[2] + 22.0, MONO[3] + 10.0),  # its base and tusks too
        "throne mesa": circle(THRONE_MESA[:2], THRONE_MESA[2]),
        "rift guard": RIFT_GUARD,
        "wayside rock": circle(WAYSIDE_ROCK[:2], WAYSIDE_ROCK[2] + 5.0),
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
    for name, (x, z, rot, w, h, by) in STELES.items():
        items["stele " + name] = g2.rect(x, z, w + 4.0, STELE_T, rot)
    for k, c in enumerate(TABLEAUX):
        items[f"tableau {k + 1}"] = circle(c, TABLEAU_R + 0.5)
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
    inside = ["ready ring", "bell", "monolith", "rift guard", "wayside rock", "apple tree", "terrace", "toss cairn",
              "cleft ledge", "needle ledge", "stele wins"] + [f"tableau {k + 1}" for k in range(len(TABLEAUX))]
    for name in inside:
        if not all(g2.contains(basin, p) for p in items[name]):
            problems.append(f"{name} leaves the island")
    # The tableaux and the bell ring the plaza without standing on it; the candle stones stand well inside it.
    for name, c, r in [(f"tableau {k + 1}", c, TABLEAU_R) for k, c in enumerate(TABLEAUX)] + [("bell", BELL, BELL_R)]:
        if math.dist(c, PLAZA_C) - r < PLAZA_R + 4.0:
            problems.append(f"{name} stands on the plaza")
    if READY_R + 2.0 > PLAZA_R - 8.0:
        problems.append("the candle ring reaches the plaza's edge")
    # The duel's slates: under the ribs, on the spine's line, clear of every rib's foot, a fair way apart.
    ribs = items["carcass ribs"]
    for k, p in enumerate(DUEL):
        if not g2.contains(ribs, p):
            problems.append(f"duel slate {k + 1} is outside the ribcage")
        for q in range(len(SPINE)):
            cx, cz = SPINE[q]
            if q + 1 < len(SPINE):
                dx, dz = SPINE[q + 1][0] - cx, SPINE[q + 1][1] - cz
            else:
                dx, dz = cx - SPINE[q - 1][0], cz - SPINE[q - 1][1]
            length = math.hypot(dx, dz)
            for sgn in (-1, 1):
                foot = (cx - dz / length * sgn * RIB_SPAN, cz + dx / length * sgn * RIB_SPAN)
                if math.dist(p, foot) < 6.0:
                    problems.append(f"duel slate {k + 1} is within 6 of a rib's foot")
    if not 10.0 <= math.dist(DUEL[0], DUEL[1]) <= 18.0:
        problems.append(f"the duel's slates are {math.dist(DUEL[0], DUEL[1]):.1f} apart")
    # The apples in the basin: on the ground people can reach, not inside anything solid.
    for k, (x, y, z) in enumerate(apples()):
        if y > 0.0:
            continue
        if not g2.contains(basin, (x, z)) or g2.dist_to_poly_edge(basin, (x, z)) < 14.0:
            problems.append(f"apple {k + 1} is at the rim or past it")
        for name, poly in items.items():
            if name not in ("cleft ledge", "needle ledge") and g2.contains(poly, (x, z)):
                problems.append(f"apple {k + 1} lies inside {name}")
    # The landing hall reaches past the whole opening (the city is not turned with the rift).
    for x, z in RIFT_GUARD:
        if abs(x - RIFT_MID[0]) > LANDING[0] * CITY_SCALE - 2.0 or abs(z - RIFT_MID[1]) > LANDING[1] * CITY_SCALE - 2.0:
            problems.append("the landing hall does not reach under the whole rift")
            break
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
    for name, (x, z, rot, w, h, by) in STELES.items():
        if math.dist((x, z), PLAZA_C) < PLAZA_R + 4:
            problems.append(f"stele {name} stands on the plaza")
        if by - h / 2 < 0.9:
            problems.append(f"stele {name}'s board reaches the ground")
    # The causeways: their heads inside the basin, clear of every solid, and the islets clear of the island.
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
    print("wins slab", STELES["wins"], "duel", DUEL, "landing roof y", LANDING_Y)
    print("apples", apples())
