"""The Grey Realm's plan, in local studs: x east, z south (north is -z), y up; the lobby's origin.

Remade from nothing on 2026-11-04 after the user's two reference videos of the death gods' realm: a flat grey
plain running out of sight under one blinding glow low in the north, dark walls of cloud east and west, jagged
pale shards on the skyline, colossal bones curving out of the ground, heaps of junk hung with giant chains, a
great stone bowl where the death gods sit and gamble, grottos lit by cage lanterns, and the hole they look down
through on the human world. The part people can walk is a rough basin about 320 studs across (an invisible wall
follows its edge, behind cliffs and shards); past it the plain goes on, out of reach. Two plateaus over chasms:
the Spire Ascent climbs on one, the other is a garden of shards.

- South: the spawn ledge, a broad shelf of billowing rock backed by cliffs; players appear on it facing north,
  over the bowl to the throne standing against the glow.
- The middle: the bowl, a great shallow basin of stone sunk in the plain in steps; at its floor's middle a dish
  heaped with skulls, the twelve candle stones round it (one burns for each player who is ready). The five
  tableaux stand round its rim (stone figures the game stands on them, acting out how a case goes).
- North, on the line from the spawn: the bone throne high on a rock against the glow (the game seats the player
  with the most wins on it, in stone), the plaque at the rock's foot, Most Wins on a slab beside it.
- North-east: the rift, the hole down to the human world, the stone notebook hanging over it in its fall.
- East: the colossal carcass, its ribs arching out of the ash; the name duel's two stones under them.
- South-west: the grotto, a cave in the cliffs where the Academy is (the practice altars, the puppets).
- West plateau (over its causeway): the Chain Heap, a mountain of junk with a colossal chain hanging into it out
  of the sky; the Spire Ascent climbs round it. North-east plateau: a garden of pale shards.
- North-west: a chess game sunk in the ash; two colossal tusks; junk heaps here and there.

Every place the venue modules use is set here. Run it on its own (python
art/scripts/maps/venues/lobby/plan.py) to check that nothing overlaps and it all stays inside the
basin, clear of the rift.
"""

import math
import os
import random
import sys

if __name__ == "__main__":
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

from maps import geo2d as g2  # noqa: E402

# Everything walkable: the basin, its two plateaus and the Spire Ascent's climb (y up to ~130).
BOUNDS = ((-380.0, -6.0, -290.0), (270.0, 150.0, 190.0))
FAR = 1500.0  # how far the plain runs (the fog closes well before)

# Where the light comes from: one blinding glow low in the north (the direction in the x-z plane, degrees from +x
# toward +z, and its height over the horizon). The throne and the rift's vortex stand against it from the spawn.
GLOW_DIR = 270.0
GLOW_ELEV = 8.0


def rim_r(a):
    """The basin's radius at angle a (radians, 0 = east, 90 degrees = south)."""
    return 158.0 + 9.0 * math.sin(3 * a + 0.7) + 5.0 * math.sin(5 * a + 2.1) + 3.0 * math.sin(11 * a)


def rim_at(deg, inset=0.0):
    """The (x, z) point `inset` studs inside the basin's rim along the direction `deg`."""
    a = math.radians(deg)
    r = rim_r(a) - inset
    return (round(math.cos(a) * r, 2), round(math.sin(a) * r, 2))


def _basin():
    n = 56
    return [rim_at(360.0 * k / n) for k in range(n)]


BASIN = _basin()  # the walkable ground's edge (counter-clockwise from east)


def polar(c, deg, r):
    """The point r from c along the direction deg."""
    a = math.radians(deg)
    return (round(c[0] + math.cos(a) * r, 2), round(c[1] + math.sin(a) * r, 2))


def facing(rot):
    """The unit (x, z) direction rot faces (rot 0 faces -z)."""
    a = math.radians(rot)
    return (-math.sin(a), -math.cos(a))


def rot_towards(frm, to):
    dx, dz = to[0] - frm[0], to[1] - frm[1]
    return math.degrees(math.atan2(-dx, -dz))


def circle(c, r, n=16):
    return [(c[0] + math.cos(2 * math.pi * k / n) * r, c[1] + math.sin(2 * math.pi * k / n) * r) for k in range(n)]


# The spawn ledge: a broad shelf of rock in the south, its top LEDGE[4] over the plain, one wide flight down its
# north face; players appear on it facing north.
LEDGE = (0.0, 100.0, 60.0, 26.0, 8.0)  # x, z, width (x), depth (z), height of its top
LEDGE_STEPS = ((0.0, 87.0), (0.0, 71.0), 20.0)  # top of the flight (y = height), its foot (y = 0), its width
SPAWN = (0.0, 102.0)  # players appear here facing north (rot 0)
SPAWNS = [(x, z) for z in (97.0, 105.0) for x in (-13.0, -4.5, 4.5, 13.0)]
SHOP = (17.0, 97.0)  # (the shop's window stands spawn + (15, -2): LobbyFixtures; kept clear here)

# The bowl: a great shallow basin of stone sunk in the plain, its floor BOWL_DEPTH under it, terraces between.
BOWL_C = (0.0, 16.0)
BOWL_R = 32.0  # its rim, level with the plain
BOWL_FLOOR_R = 15.0
BOWL_STEPS = 3
BOWL_DEPTH = 1.8  # (three rises of 0.6: walked down without a jump anywhere round it)
DISH_R = 3.4  # the dish of skulls at the floor's middle
READY_R = 7.5  # the candle stones' ring
READY_COUNT = 12  # one stone for each player a case can hold
READY_H = 1.7


def bowl_floor_y():
    return -BOWL_DEPTH


def bowl_step(k):
    """Terrace k (0 = the lowest, round the floor; BOWL_STEPS - 1 = the top one, at the rim): (inner radius, outer
    radius, its top's height)."""
    span = (BOWL_R - BOWL_FLOOR_R) / BOWL_STEPS
    r0 = BOWL_FLOOR_R + span * k
    return (r0, r0 + span, -BOWL_DEPTH + BOWL_DEPTH * (k + 1) / BOWL_STEPS)


def ready_stones():
    """The candle stones (x, z): from the one nearest the spawn's steps (south), clockwise seen from above."""
    return [polar(BOWL_C, 90.0 + k * 360.0 / READY_COUNT, READY_R) for k in range(READY_COUNT)]


# The five tableaux round the bowl's rim (clockwise from the spawn's side, the order the story is told), each a low
# round base facing the bowl's middle.
TABLEAU_RING = 44.0
TABLEAU_R = 6.0
TABLEAU_H = 0.7
TABLEAU_DEG = [148.0, 200.0, 250.0, 302.0, 354.0]
TABLEAUX = [polar(BOWL_C, d, TABLEAU_RING) for d in TABLEAU_DEG]

# The throne, high on its rock in the north on the spawn's line, against the glow, facing the spawn; the plaque at
# the rock's foot, Most Wins on a slab beside it.
THRONE = (0.0, -64.0)
THRONE_ROT = 180.0
THRONE_ROCK = (0.0, -66.0, 9.5, 16.0)  # x, z, radius of its top, its top's height (realmrock RealmThroneRock)
PLAQUE = (0.0, -49.0)  # the plaque stone at the rock's foot (its middle)
STELE_T = 2.4


def _wins_slab():
    """Beside the throne's rock (east of it), facing the bowl."""
    x, z = THRONE_ROCK[0] + THRONE_ROCK[2] + 12.0, THRONE_ROCK[1] + 8.0
    return (round(x, 2), round(z, 2), round(rot_towards((x, z), BOWL_C), 1), 10.0, 10.0, 6.0)


# The one board left standing in the world, Most Wins: a slab. name -> (x, z, rot facing where people come from,
# board w, board h, the board's middle above the ground).
STELES = {"wins": _wins_slab()}

# The two plateaus (x, z, radius) and the causeways to them from the basin's rim.
ISLET_SHARDS = (214.0, -216.0, 40.0)
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


BRIDGE_SHARDS = _bridge(ISLET_SHARDS)
BRIDGE_PARKOUR = _bridge(ISLET_PARKOUR)


def _chasm(bridge):
    """(x, z, along, across, rot): the chasm under a causeway: `along` studs of it along the causeway,
    `across` studs wide the other way, its middle 45 % of the way along the part before the stairs."""
    a, b = bridge
    length = math.dist(a, b) - STAIR_RUN
    ux, uz = (b[0] - a[0]) / math.dist(a, b), (b[1] - a[1]) / math.dist(a, b)
    t = length * 0.45
    return (a[0] + ux * t, a[1] + uz * t, 34.0, 84.0, math.degrees(math.atan2(-uz, ux)))


CHASMS = [_chasm(BRIDGE_SHARDS), _chasm(BRIDGE_PARKOUR)]
CHASM_DEPTH = 72.0


def chasm_poly(c):
    return g2.rect(c[0], c[1], c[2], c[3], c[4])


def chasm_outline(c, step=4.5):
    """The chasm's rim on the plain: a jagged crack running across the causeway, widest where the causeway crosses
    it (the full span the causeway was built over, so its piers still stand in the dark) and narrowing to cracks at
    its two ends, its edge broken every few studs; always inside chasm_poly. Counter-clockwise."""
    cx, cz, along, across, rot = c
    rng = random.Random(int(abs(cx) * 7 + abs(cz) * 13))
    t = math.radians(rot)
    ax, az = math.cos(t), -math.sin(t)  # along the causeway
    sx, sz = -az, ax  # across it: the crack's length
    half_len = across / 2 - 0.6
    count = max(18, int(2 * half_len / step))
    crossing = 7.0 / half_len  # (|u| under this: where the causeway and its parapets cross, the full span)
    left, right = [], []
    for k in range(count + 1):
        u = -1 + 2 * k / count
        shape = 0.28 + 0.72 * (1 - u * u) ** 0.7
        wobble = 0.12 * math.sin(3.1 * u + 1.3) + 0.07 * math.sin(7.7 * u + 0.4)
        for side, out in ((1, left), (-1, right)):
            if abs(u) < crossing:
                w = along / 2 - 0.3
            else:
                w = (along / 2 - 0.3) * max(0.12, min(1.0, shape + wobble * side + rng.uniform(-0.1, 0.1)))
            out.append((cx + sx * u * half_len + ax * side * w, cz + sz * u * half_len + az * side * w))
    return g2.ccw(left + list(reversed(right)))


# The grotto: a cave in the south-west cliffs, its mouth toward the bowl; the Academy inside it (the seven practice
# altars round its floor's back, the three puppets across its middle, the gate's name over the mouth).
ACADEMY_C = (-104.0, 52.0)
ACADEMY_R = 26.0  # the cave floor's radius (walkable); its walls stand out to GROTTO_WALL
GROTTO_WALL = 36.0
GROTTO_ROOF = 34.0  # the roof's height over the floor's middle (the puppets' hand hangs 22 over them)
GROTTO_MOUTH_W = 16.0  # the mouth's width
GROTTO_MOUTH_H = 13.0
ALTAR_R = 16.0
GATE_DIR = math.degrees(math.atan2(BOWL_C[1] - ACADEMY_C[1], BOWL_C[0] - ACADEMY_C[0]))  # degrees in the x-z plane
GATE = polar(ACADEMY_C, GATE_DIR, GROTTO_WALL - 3.0)  # the mouth's middle


def altars():
    """The seven practice altars: (x, z, rot facing the cave's middle), spread over the back of its floor."""
    out = []
    for k in range(7):
        a = math.radians(GATE_DIR + 180.0 - 96.0 + k * 32.0)
        x, z = ACADEMY_C[0] + math.cos(a) * ALTAR_R, ACADEMY_C[1] + math.sin(a) * ALTAR_R
        out.append((round(x, 2), round(z, 2), rot_towards((x, z), ACADEMY_C)))
    return out


def effigies():
    """The three puppets across the cave's middle, facing the mouth."""
    gate = math.radians(GATE_DIR)
    side = (-math.sin(gate), math.cos(gate))
    rot = rot_towards(ACADEMY_C, BOWL_C)
    return [(ACADEMY_C[0] + side[0] * d, ACADEMY_C[1] + side[1] * d, rot) for d in (-7.0, 0.0, 7.0)]


# The rift: the hole down to the human world (convex), its guard 3.5 outside its edge.
RIFT_C = (90.0, -44.0)
RIFT_AXES = (24.0, 16.0)
RIFT_TURN = 20.0
RIFT_DEPTH = 76.0  # the throat of rock down through the ground, to the cloud
# The cloud the realm floats on: its underside, a flat deck at CLOUD_Y with heavy lobes hanging from it, out
# to CLOUD_FAR from the rift; seen from under it only, it seals the realm's underside in every direction. The rift's
# throat opens through it.
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
RIFT_MID = g2.centroid(RIFT)
# The stone notebook over the rift, stopped in its fall: x, y, z, rot (high enough that a dive goes under it).
NOTEBOOK = (RIFT_C[0] + 2.0, 22.0, RIFT_C[1] - 2.0, 35.0)

# Far beneath the rift's middle: the hall whose roof a dive ends on. In the city's own units, from the point
# under the rift's middle (the city is drawn at a third of its size): half its width (x), half its depth (z)
# and its floors. It reaches past the whole opening, so whoever goes over the rim anywhere comes down on it.
LANDING = (90.0, 72.0, 13)
CITY_SCALE = 1 / 3
LANDING_Y = BELOW_Y + (LANDING[2] * 12.0 + 1.5) * CITY_SCALE  # its roof
LANDING_RING = 10.5  # the lit ring on the roof (studs)

# The carcass in the east: a colossal skeleton half sunk in the ash, its skull at the north end looking west, its
# spine running south, its ribs arching over; the name duel's two stones under the ribs, facing each other.
CARCASS_SKULL = (112.0, -12.0, 40.0)  # x, z, rot (gazing north-west, toward the throne)
SPINE = [(120.0, 6.0), (122.0, 22.0), (122.0, 38.0), (120.0, 54.0), (115.0, 70.0)]
RIB_SPAN = 13.0  # how far each rib's foot lands from the spine
SPINE_Y = 17.0


def _along(a, b, t):
    return (round(a[0] + (b[0] - a[0]) * t, 2), round(a[1] + (b[1] - a[1]) * t, 2))


DUEL = [_along(SPINE[1], SPINE[2], 0.5625), _along(SPINE[2], SPINE[3], 0.4375)]

# The chess game sunk in the ash, north-west: x, z, its turn, a square's side. Its pieces stand mid-game; the
# white king lies toppled.
CHESS = (-62.0, -40.0, 18.0, 3.2)
CHESS_GAME = {
    "a7": ("R", "w"), "c3": ("N", "w"), "a3": ("P", "w"), "b2": ("P", "w"), "f2": ("P", "w"), "g2": ("P", "w"),
    "h2": ("P", "w"),
    "g8": ("K", "b"), "e1": ("R", "b"), "b6": ("Q", "b"), "b7": ("B", "b"), "f6": ("N", "b"), "c5": ("P", "b"),
    "f7": ("P", "b"), "g6": ("P", "b"), "h7": ("P", "b"),
}
CHESS_FALLEN = "g1"  # the white king's square


def chess_square(name):
    """A square's middle in the board's own frame (x, z): white plays up the board from its south edge (+z),
    the a-file to the west (-x)."""
    f = "abcdefgh".index(name[0])
    r = int(name[1]) - 1
    return ((f - 3.5) * CHESS[3], (3.5 - r) * CHESS[3])


# Two colossal tusks curving up out of the ash (north-west), crossing over the way between them: x, z, rot.
TUSKS = (-76.0, -104.0, 160.0)

# Heaps of junk (rubble, broken gears, giant chains): x, z, radius, height, seed.
JUNK = [
    (-116.0, -28.0, 11.0, 9.0, 41),
    (58.0, -128.0, 10.0, 8.0, 42),
    (150.0, -8.0, 8.0, 7.0, 43),
    (-24.0, -136.0, 7.0, 6.0, 44),
]

# Where the great arch of twisted rock stands, framing the throne's glow from the bowl (x, z, span, height, rot).
ARCH = (-118.0, -96.0, 30.0, 38.0, 64.0)

# The garden of the dead (2026-11-10, the user's pictures; lobby/garden.py): white flowers everywhere else grey.
# South-east, beside the spawn ledge: a still pond (x, z, radius across x, radius across z) crossed by a stone
# footbridge, a cascade of water down a stair into it from the south, a round temple by it, a willow leaning over it.
POND = (68.0, 96.0, 14.0, 9.0)
ROTUNDA = (96.0, 96.0, 9.6)  # x, z, the radius of its lowest step
CASCADE = (76.0, 114.0)  # the middle of its foot; its stair climbs south (+z) from the pond
WILLOW = (84.0, 82.0)
# North-west of the throne: the great tree over a hill of white flowers (Bloodborne's), broken columns on the skyline
# behind the throne, ruined chapel walls; the avenue of old trees on the way to the Academy.
GREAT_TREE = (-38.0, -92.0)
COLUMNS = [(14.0, -106.0, 1.0), (34.0, -118.0, 1.25), (52.0, -100.0, 0.85), (-6.0, -128.0, 1.4), (24.0, -142.0, 1.6)]
RUINS = [(-106.0, -64.0, 238.0), (-60.0, -132.0, 202.0)]  # x, z, rot (its arches' faces toward the bowl)
# Far beyond the north-west rim, through the fog: the castle on its crag (a dragon circles it: World/LobbyDragon).
CASTLE = (-150.0, -720.0, 1.4, 1.5)  # x, z, the crag's scale, the castle's scale (against the glow, left of the throne)


def ellipse(c, rx, rz, n=32):
    return [(round(c[0] + math.cos(math.tau * k / n) * rx, 2), round(c[1] + math.sin(math.tau * k / n) * rz, 2))
            for k in range(n)]


# The Spire Ascent: ten checkpoints climbing round the colossal chain that hangs into the Chain Heap.
PK_CENTER = (ISLET_PARKOUR[0], ISLET_PARKOUR[1])
PK_TOP = 118.0  # the finish's height over the plateau

# Where the checks measure the walk (x, y, z pairs): the spawn to each plateau's far side, and across the basin.
CORNERS = [[(SPAWN[0], LEDGE[4], SPAWN[1]), (ISLET_SHARDS[0] + 22.0, PLATEAU_H, ISLET_SHARDS[1] - 22.0)],
           [(SPAWN[0], LEDGE[4], SPAWN[1]), (ISLET_PARKOUR[0] - 22.0, PLATEAU_H, ISLET_PARKOUR[1] + 10.0)],
           [(-100.0, 0.0, 110.0), (104.0, 0.0, -96.0)]]


def footprints():
    """name -> polygon of everything solid on the ground, for the overlap check."""
    items = {
        "bowl": circle(BOWL_C, BOWL_R + 1.0, 24),
        "throne rock": circle(THRONE_ROCK[:2], THRONE_ROCK[2] * 1.45, 16),
        "plaque": g2.rect(PLAQUE[0], PLAQUE[1], 6.4, 2.0),
        "rift guard": RIFT_GUARD,
        "chessboard": g2.rect(CHESS[0], CHESS[1], CHESS[3] * 8 + 3.0, CHESS[3] * 8 + 3.0, CHESS[2]),
        "carcass skull": circle(CARCASS_SKULL[:2], 12.0),
        "carcass ribs": g2.convex_hull([(x + dx, z + dz) for x, z in SPINE for dx, dz in
                                        ((-RIB_SPAN - 3.0, 0.0), (RIB_SPAN + 3.0, 0.0), (0.0, -3.0), (0.0, 3.0))]),
        "tusks": circle(TUSKS[:2], 14.0),
        "ledge": g2.rect(LEDGE[0], LEDGE[1], LEDGE[2], LEDGE[3]),
        "ledge steps": g2.rect(LEDGE_STEPS[0][0], (LEDGE_STEPS[0][1] + LEDGE_STEPS[1][1]) / 2, LEDGE_STEPS[2],
                               LEDGE_STEPS[0][1] - LEDGE_STEPS[1][1]),
        "grotto": circle(ACADEMY_C, GROTTO_WALL + 4.0, 24),
        "arch": g2.rect(ARCH[0], ARCH[1], ARCH[2] + 12.0, 12.0, ARCH[4]),
        "pond": ellipse(POND[:2], POND[2] + 1.5, POND[3] + 1.5),
        "rotunda": circle(ROTUNDA[:2], ROTUNDA[2] + 0.5, 20),
        "cascade": g2.rect(CASCADE[0], CASCADE[1] + 4.55, 6.4, 20.6),
        "great tree": circle(GREAT_TREE, 6.0, 12),
    }
    for k, (x, z, sc) in enumerate(COLUMNS):
        items[f"column {k + 1}"] = g2.rect(x, z, 4.0 * sc, 4.0 * sc)
    for k, (x, z, rot) in enumerate(RUINS):
        items[f"ruin {k + 1}"] = g2.rect(x, z, 30.0, 5.0, rot)
    for name, (x, z, rot, w, h, by) in STELES.items():
        items["stele " + name] = g2.rect(x, z, w + 4.0, STELE_T, rot)
    for k, c in enumerate(TABLEAUX):
        items[f"tableau {k + 1}"] = circle(c, TABLEAU_R + 0.5)
    for k, (x, z, r, h, seed) in enumerate(JUNK):
        items[f"junk {k + 1}"] = circle((x, z), r)
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
    inside = ["bowl", "throne rock", "plaque", "rift guard", "chessboard", "ledge", "stele wins", "carcass skull",
              "pond", "rotunda", "cascade", "great tree", "ruin 1", "ruin 2"]
    inside += [f"column {k + 1}" for k in range(len(COLUMNS))]
    inside += [f"tableau {k + 1}" for k in range(len(TABLEAUX))]
    for name in inside:
        if not all(g2.contains(basin, p) for p in items[name]):
            problems.append(f"{name} leaves the basin")
    # The throne on the spawn's line, against the glow; its rock clear of the bowl.
    if abs(THRONE[0] - SPAWN[0]) > 0.01:
        problems.append("the throne is off the spawn's line")
    if math.dist(THRONE_ROCK[:2], BOWL_C) < BOWL_R + THRONE_ROCK[2] + 12.0:
        problems.append("the throne's rock crowds the bowl")
    # The candle ring well inside the floor, round the dish.
    if READY_R + 2.0 > BOWL_FLOOR_R - 2.0 or READY_R - 1.5 < DISH_R + 1.0:
        problems.append("the candle ring does not fit between the dish and the floor's edge")
    # The duel's stones: under the ribs, on the spine's line, clear of every rib's foot, a fair way apart.
    ribs = items["carcass ribs"]
    for k, p in enumerate(DUEL):
        if not g2.contains(ribs, p):
            problems.append(f"duel stone {k + 1} is outside the ribcage")
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
                    problems.append(f"duel stone {k + 1} is within 6 of a rib's foot")
                if not g2.contains(basin, foot):
                    problems.append(f"a rib's foot at {foot} is past the rim")
    if not 10.0 <= math.dist(DUEL[0], DUEL[1]) <= 18.0:
        problems.append(f"the duel's stones are {math.dist(DUEL[0], DUEL[1]):.1f} apart")
    # The landing hall reaches past the whole opening (the city is not turned with the rift).
    for x, z in RIFT_GUARD:
        if abs(x - RIFT_MID[0]) > LANDING[0] * CITY_SCALE - 2.0 or abs(z - RIFT_MID[1]) > LANDING[1] * CITY_SCALE - 2.0:
            problems.append("the landing hall does not reach under the whole rift")
            break
    for x, z in SPAWNS + [SPAWN]:
        if not g2.contains(items["ledge"], (x, z)):
            problems.append(f"spawn {(x, z)} is off the ledge")
    if g2.contains(items["ledge"], SHOP) is False:
        problems.append("the shop's window is off the ledge")
    # The practice altars: 5 studs clear on the worker's side, the puppets clear of that, all inside the cave floor.
    for k, (x, z, rot) in enumerate(altars()):
        fx, fz = facing(rot)
        wx, wz = x + fx * 2.6, z + fz * 2.6
        for ex, ez, _ in effigies():
            if math.dist((wx, wz), (ex, ez)) < 5.0:
                problems.append(f"altar {k + 1}'s worker spot is within 5 of a puppet")
        if math.dist((x, z), ACADEMY_C) + 3.2 > ACADEMY_R - 1.0:
            problems.append(f"altar {k + 1} reaches the cave's wall")
    if math.dist(GATE, ACADEMY_C) > GROTTO_WALL:
        problems.append("the gate is outside the cave")
    for name, (x, z, rot, w, h, by) in STELES.items():
        if by - h / 2 < 0.9:
            problems.append(f"stele {name}'s board reaches the ground")
    # The causeways: their heads inside the basin, clear of every solid, and longer than 60.
    for name, (a, b) in (("shards", BRIDGE_SHARDS), ("parkour", BRIDGE_PARKOUR)):
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
    print("bridge shards", BRIDGE_SHARDS, "bridge parkour", BRIDGE_PARKOUR)
    print("wins slab", STELES["wins"], "duel", DUEL, "gate", GATE)
    print("tableaux", TABLEAUX)
