"""The Grey Realm's dressing (remade 2026-11-04 to the reference videos): pale spiky dead grass in patches across the
ash, heaps of skulls and bones strewn about, old flagstones stepping along the ways from the bowl, roots hanging from
the grotto's mouth and the rift's rim, drifting ash, low mist and the wind. Nothing is placed where the plan has
something solid, where anything built before it stands (its colliders and its props), or on another piece of it
(`blocked`)."""

import math
import random

from maps import catalog
from maps import geo2d as g2
from maps.venues.lobby import ground as surface
from maps.venues.lobby import plan as P
from maps.venues.lobby import rocks

CELL = 8.0
SOLIDS = {}  # (i, j) cell -> outlines of the colliders standing on the ground there (`solids`)


def solids(s):
    """Gathers the colliders that stand on the ground (from under it to above ankle height: walls, cores, posts,
    the rims of dais and pads, the stones breaking through the ash) by 8-stud cell, and returns (x, z, r) circles
    round every prop already stood on the ground that is not rock (the tableaux' bases, the candle stones)."""
    SOLIDS.clear()
    for x, y, z, sx, sy, sz, rot, *_ in s.colliders:
        if y + sy / 2 < 0.2 or y - sy / 2 > 3.0:
            continue
        poly = g2.rect(x, z, sx, sz, rot)
        box = g2.bbox(poly)
        for i in range(math.floor(box[0] / CELL), math.floor(box[2] / CELL) + 1):
            for j in range(math.floor(box[1] / CELL), math.floor(box[3] / CELL) + 1):
                SOLIDS.setdefault((i, j), []).append(poly)
    cat = catalog.load()
    out = []
    for key, x, y, z, rot, sc, *_ in s.props:
        info = cat.get(key)
        if not info or catalog.is_terrain(key) or abs(y) > 1.0:
            continue
        sx, _, sz = info["size"]
        out.append((x, z, math.hypot(sx, sz) / 2 * sc))
    return out


def in_solid(x, z, r):
    """True when a circle of radius r at (x, z) touches one of the colliders `solids` gathered."""
    for i in range(math.floor((x - r) / CELL), math.floor((x + r) / CELL) + 1):
        for j in range(math.floor((z - r) / CELL), math.floor((z + r) / CELL) + 1):
            for poly in SOLIDS.get((i, j), ()):
                if g2.contains(poly, (x, z)) or g2.dist_to_poly_edge(poly, (x, z)) < r:
                    return True
    return False

# x, z, rot, scale
SKULL_PILES = [(-92.0, -18.0, 30.0, 1.0), (66.0, -6.0, 200.0, 1.2), (-28.0, -84.0, 90.0, 1.1), (-58.0, 84.0, 300.0, 0.9),
               (100.0, 92.0, 150.0, 1.1), (-120.0, 24.0, 250.0, 1.2), (36.0, -122.0, 60.0, 1.0), (150.0, 10.0, 10.0, 0.9),
               (-104.0, -78.0, 120.0, 1.1)]
CAIRNS = [(-150.0, 52.0), (64.0, -140.0), (150.0, -40.0), (-52.0, 138.0), (122.0, 98.0), (-14.0, -146.0)]


def blocked(x, z, r, extra=()):
    """True when a circle of radius r at (x, z) would touch anything solid the plan knows of, or one of `extra`
    ((x, z, r) circles), or leave the basin, or reach the rift."""
    if not g2.contains(P.BASIN, (x, z)) or g2.dist_to_poly_edge(P.BASIN, (x, z)) < r + 11.0:
        return True
    if g2.contains(P.RIFT_GUARD, (x, z)) or g2.dist_to_poly_edge(P.RIFT_GUARD, (x, z)) < r + 4.0:
        return True
    for poly in P.footprints().values():
        if g2.contains(poly, (x, z)) or g2.dist_to_poly_edge(poly, (x, z)) < r + 1.0:
            return True
    for ex, ez, er in extra:
        if math.dist((x, z), (ex, ez)) < r + er + 1.0:
            return True
    # (and every rock's foot: the billows and crags stood by terrain, landmarks and the plateaus; well clear of it, since
    # a billowing rock bulges out over its own foot)
    for foot in rocks.FEET:
        if g2.contains(foot, (x, z)) or g2.dist_to_poly_edge(foot, (x, z)) < r + 4.0:
            return True
    return in_solid(x, z, r + 0.6)


def on_way(x, z, pad):
    """True when (x, z) is within pad of one of the ways people walk."""
    return any(g2.dist_point_segment((x, z), a, b) < pad for way in surface.WAYS for a, b in zip(way, way[1:]))


def bones(s, taken):
    for x, z, rot, sc in SKULL_PILES:
        if blocked(x, z, 2.4 * sc, taken) or on_way(x, z, 5.0):
            continue
        s.prop("SkullPile", x, z, rot, sc)
        taken.append((x, z, 2.4 * sc))
    rng = random.Random(1313)
    placed = 0
    tries = 0
    while placed < 18 and tries < 500:
        tries += 1
        a = rng.uniform(0, math.tau)
        d = rng.uniform(36, 150)
        x, z = math.cos(a) * d, math.sin(a) * d
        if blocked(x, z, 2.6, taken) or on_way(x, z, 3.0):
            continue
        s.prop("BoneScatter", x, z, rng.uniform(0, 360), rng.uniform(0.9, 1.4))
        taken.append((x, z, 2.6))
        placed += 1
    for x, z in CAIRNS:
        if not blocked(x, z, 2.2, taken):
            s.prop("Cairn", x, z, (x + z) % 360, rng.uniform(1.0, 1.4))
            taken.append((x, z, 2.2))


def grass(s, taken):
    """Pale spiky dead grass in patches across the ash, thickest toward the basin's edge."""
    rng = random.Random(1717)
    patches = 0
    tries = 0
    while patches < 46 and tries < 900:
        tries += 1
        a = rng.uniform(0, math.tau)
        d = 40.0 + 125.0 * math.sqrt(rng.random())
        cx, cz = math.cos(a) * d, math.sin(a) * d
        if blocked(cx, cz, 3.0, taken) or on_way(cx, cz, 3.0):
            continue
        patches += 1
        for k in range(rng.randint(3, 8)):
            px, pz = cx + rng.uniform(-6.0, 6.0), cz + rng.uniform(-6.0, 6.0)
            if blocked(px, pz, 1.6, taken) or on_way(px, pz, 2.0):
                continue
            sc = rng.uniform(0.7, 1.35)
            s.prop("SpikeGrass", px, pz, rng.uniform(0, 360), round(sc, 3))
            taken.append((px, pz, 1.1 * sc))


# The realm's wreckage (2026-11-14, the user: "make everything more ruined"): what stood along the ways is down. Each
# entry is a spot beside a way or out in the open (x, z, the way it lies in degrees, what it is); a spot the plan has
# taken is left out. Built of the realm's own stone, solid, half sunk in the ash; the hummocks drift over their feet.
RUINS = [
    (-44.0, 40.0, 25.0, "colonnade"), (-60.0, 28.0, 205.0, "wall"), (-84.0, 12.0, 80.0, "column"),
    (-118.0, -10.0, 140.0, "wall"), (-96.0, 22.0, 10.0, "slabs"), (8.0, -40.0, 95.0, "column"),
    (-9.0, -27.0, 300.0, "slabs"), (50.0, 8.0, 60.0, "wall"), (74.0, 30.0, 190.0, "colonnade"),
    (98.0, 16.0, 330.0, "slabs"), (40.0, -22.0, 120.0, "column"), (58.0, -62.0, 40.0, "wall"),
    (80.0, -84.0, 250.0, "colonnade"), (-36.0, -12.0, 170.0, "slabs"), (36.0, 56.0, 15.0, "column"),
    (56.0, 76.0, 100.0, "wall"), (-132.0, 40.0, 60.0, "colonnade"), (126.0, -30.0, 285.0, "column"),
    (-70.0, -52.0, 230.0, "wall"), (20.0, 104.0, 135.0, "slabs"), (-24.0, 118.0, 320.0, "column"),
    (112.0, 64.0, 75.0, "wall"), (-110.0, 74.0, 155.0, "slabs"), (14.0, -96.0, 20.0, "colonnade"),
    (-52.0, -96.0, 110.0, "column"), (140.0, 40.0, 200.0, "slabs"), (-146.0, -40.0, 35.0, "wall"),
    (88.0, 118.0, 260.0, "column"), (-84.0, 112.0, 70.0, "wall"), (118.0, -78.0, 150.0, "slabs"),
]
STONE = "RuinStone"
STOOD = []  # (x, z, reach) of the ruins that stand: the hummocks keep off them (ground.quiet_places)


def _axes(yaw, pitch=0.0, roll=0.0):
    """A box's axes turned `yaw` about the upright, then leant `pitch` (toward its own +z) and `roll` (toward +x)."""
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))
    ux = (cy * cr, sr, -sy * cr)
    uz = (sy * cp, -sp, cy * cp)
    uy = (uz[1] * ux[2] - uz[2] * ux[1], uz[2] * ux[0] - uz[0] * ux[2], uz[0] * ux[1] - uz[1] * ux[0])
    length = math.sqrt(sum(c * c for c in uy))
    uy = tuple(c / length for c in uy)
    # (square the third axis to the other two)
    ux = (uy[1] * uz[2] - uy[2] * uz[1], uy[2] * uz[0] - uy[0] * uz[2], uy[0] * uz[1] - uy[1] * uz[0])
    return ux, uy, uz


def _rubble(s, rng, x, z, reach, count):
    """Broken blocks strewn round a spot: each its own size, turned and leant its own way, sunk a little."""
    for _ in range(count):
        a, d = rng.uniform(0, math.tau), reach * math.sqrt(rng.random())
        w, h, dp = rng.uniform(0.5, 1.5), rng.uniform(0.4, 1.0), rng.uniform(0.5, 1.3)
        ux, uy, uz = _axes(rng.uniform(0, 360), rng.uniform(-24, 24), rng.uniform(-24, 24))
        s.obox(STONE, (x + math.cos(a) * d, h * rng.uniform(0.18, 0.42), z + math.sin(a) * d), (w, h, dp), ux, uy, uz)


def _column(s, rng, x, z, yaw, drums=4):
    """A column down: its stump still standing on its plinth, broken off ragged; its drums lying where they fell,
    in a line that has come apart, each rolled a little out of true and half sunk."""
    r = rng.uniform(1.15, 1.45)
    ux, uy, uz = _axes(yaw + rng.uniform(-8, 8), rng.uniform(-3, 3), rng.uniform(-3, 3))
    s.obox(STONE, (x, 0.3, z), (r * 2.7, 0.75, r * 2.7), ux, uy, uz)
    stump = rng.uniform(1.4, 3.6)
    s.cylinder(STONE, (x, 0.6, z), r, stump, 10, caps=(False, True))
    # (the break: a slanted cap of three steps, never a clean cut)
    for k in range(3):
        a = math.radians(yaw + 120 * k + rng.uniform(-20, 20))
        s.cylinder(STONE, (x + math.cos(a) * r * 0.22, 0.6 + stump, z + math.sin(a) * r * 0.22), r * (0.78 - 0.16 * k),
                   rng.uniform(0.15, 0.5) + 0.18 * k, 9, caps=(False, True))
    s.collider((x, 0.6 + stump / 2, z), (r * 1.8, stump + 1.2, r * 1.8), yaw, True, None)
    dx, dz = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    along = r + rng.uniform(1.6, 2.6)
    for k in range(drums):
        length = rng.uniform(2.0, 3.2)
        side = rng.uniform(-0.9, 0.9) * (1 + 0.4 * k)
        cx, cz = x + dx * (along + length / 2) - dz * side, z + dz * (along + length / 2) + dx * side
        turn = math.radians(yaw + rng.uniform(-16, 16) * (1 + 0.5 * k))
        hx, hz = math.cos(turn) * length / 2, math.sin(turn) * length / 2
        sink = rng.uniform(0.25, 0.6) * r
        tilt = rng.uniform(-0.25, 0.25)
        s.tube(STONE, (cx - hx, r - sink - tilt, cz - hz), (cx + hx, r - sink + tilt, cz + hz), r * rng.uniform(0.94, 1.0),
               10)
        s.collider((cx, (r * 2 - sink) / 2, cz), (length, r * 2 - sink, r * 1.9), -math.degrees(turn), True, None)
        along += length + rng.uniform(0.3, 2.4)
    _rubble(s, rng, x + dx * 3.0, z + dz * 3.0, 4.5, rng.randint(4, 7))
    return along


def _wall(s, rng, x, z, yaw):
    """What is left of a wall: a run of courses broken down in ragged steps, leaning, its fallen blocks at its foot."""
    dx, dz = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    thick = rng.uniform(1.2, 1.7)
    lean = rng.uniform(-7, 7)
    u = -rng.uniform(4.0, 6.5)
    end = -u + rng.uniform(-1.5, 1.5)
    height = rng.uniform(2.4, 5.4)
    while u < end:
        w = rng.uniform(1.4, 2.8)
        height = max(0.7, min(6.2, height + rng.uniform(-1.9, 1.3)))
        cx, cz = x + dx * (u + w / 2), z + dz * (u + w / 2)
        ux, uy, uz = _axes(-yaw + rng.uniform(-3, 3), lean + rng.uniform(-2, 2), rng.uniform(-2, 2))
        s.obox(STONE, (cx, height / 2 - 0.3, cz), (w + 0.02, height, thick * rng.uniform(0.9, 1.05)), ux, uy, uz)
        s.collider((cx, height / 2, cz), (w, height, thick + 0.3), -yaw, True, None)
        # (a loose block left on top of some)
        if rng.random() < 0.4:
            bw = rng.uniform(0.8, 1.3)
            bx, by, bz = _axes(-yaw + rng.uniform(-25, 25), rng.uniform(-8, 8), rng.uniform(-8, 8))
            s.obox(STONE, (cx + dx * rng.uniform(-0.4, 0.4), height, cz + dz * rng.uniform(-0.4, 0.4)),
                   (bw, 0.6, thick * 0.8), bx, by, bz)
        u += w
    for side in (-1, 1):
        _rubble(s, rng, x - dz * side * 2.2, z + dx * side * 2.2, 3.6, rng.randint(2, 5))


def _slabs(s, rng, x, z, yaw):
    """Paving heaved up and broken: a few big flags tipped at their own angles, one standing almost on its edge."""
    for k in range(rng.randint(3, 5)):
        a, d = rng.uniform(0, math.tau), rng.uniform(0.0, 4.2)
        w, dp, t = rng.uniform(2.4, 4.6), rng.uniform(1.8, 3.4), rng.uniform(0.35, 0.6)
        pitch = rng.uniform(62, 78) if k == 0 else rng.uniform(-22, 22)
        ux, uy, uz = _axes(yaw + rng.uniform(-50, 50), pitch, rng.uniform(-12, 12))
        y = (dp / 2) * abs(math.sin(math.radians(pitch))) * 0.7 + t * 0.2
        cx, cz = x + math.cos(a) * d, z + math.sin(a) * d
        s.obox(STONE, (cx, y, cz), (w, t, dp), ux, uy, uz)
        if k == 0:
            s.collider((cx, y, cz), (w * 0.9, dp * 0.9, 1.0), -yaw, True, None)
    _rubble(s, rng, x, z, 5.0, rng.randint(4, 8))


def ruins(s, taken):
    """Stands the realm's wreckage (RUINS) wherever the plan leaves room, and takes its ground."""
    rng = random.Random(909)
    stood = 0
    STOOD.clear()
    for x, z, yaw, kind in RUINS:
        reach = 8.5 if kind in ("colonnade", "wall") else 6.0
        # (the spot wanted, or the nearest clear ground round it: rings out to 30 studs)
        spot = None
        for ring in range(0, 6):
            for k in range(1 if ring == 0 else 10):
                ang = math.tau * k / 10 + ring * 0.7
                px, pz = x + math.cos(ang) * ring * 6.0, z + math.sin(ang) * ring * 6.0
                if not blocked(px, pz, reach, taken) and not on_way(px, pz, reach * 0.55):
                    spot = (px, pz)
                    break
            if spot:
                break
        if spot is None:
            continue
        x, z = spot
        if kind == "column":
            _column(s, rng, x, z, yaw)
        elif kind == "colonnade":
            # two columns of one row: one down along the row, its neighbour only a stump
            _column(s, rng, x, z, yaw, drums=rng.randint(3, 5))
            dx, dz = math.cos(math.radians(yaw + 90)), math.sin(math.radians(yaw + 90))
            _column(s, rng, x + dx * 6.5, z + dz * 6.5, yaw + rng.uniform(150, 210), drums=1)
        elif kind == "wall":
            _wall(s, rng, x, z, yaw)
        else:
            _slabs(s, rng, x, z, yaw)
        taken.append((x, z, reach))
        STOOD.append((x, z, reach))
        stood += 1
    print(f"[lobby] ruins: {stood} of {len(RUINS)} stand")


def stepping(s, points, seed, spacing=3.4):
    """Old flagstones stepping along a way (flush with the ash)."""
    rng = random.Random(seed)
    total = g2.polyline_length(points)
    u = 0.0
    while u < total:
        (x, z), _ = g2.point_along(points, u)
        for side in (-1, 1):
            if rng.random() < 0.7:
                w = rng.uniform(1.6, 2.8)
                ox = side * rng.uniform(0.6, 1.9)
                p = (x + ox, z + rng.uniform(-0.8, 0.8))
                poly = g2.rect(p[0], p[1], w, w * rng.uniform(0.6, 1.0), rng.uniform(0, 90))
                s.polygon("RuinFlag", [(px, 0.035, pz) for px, pz in g2.cw(poly)])
        u += spacing * rng.uniform(0.8, 1.2)


def ways(s):
    for k, points in enumerate(surface.WAYS):
        stepping(s, points, 41 + k)


# Things the game builds and sways in the wind (src/client/World/WindSway): roots hanging from the grotto's mouth and
# from the rift's rim. Anchors root<n> (x, y, z, h = length) hang from their anchor down.
def sway(s):
    roots = []
    # (the roots that hung in the grotto's mouth went with its roof, 2026-11-12)
    cx, cz = P.RIFT_MID
    for k in range(5):
        a = math.tau * k / 5 + 0.4
        x, z = cx + math.cos(a) * (P.RIFT_AXES[0] * 0.9), cz + math.sin(a) * (P.RIFT_AXES[1] * 0.9)
        roots.append((x, -1.5, z, 12.0 + (k * 3) % 7))
    for k, (x, y, z, length) in enumerate(roots):
        s.anchor(f"root{k + 1}", x, y, z, 0.0, h=length)


def ambience(s):
    # Ash drifting over the basin, motes hanging in the still air, mist lying low (all thinned on weak devices).
    for x, z in ((0.0, 0.0), (-90.0, -60.0), (90.0, -60.0), (-80.0, 90.0), (80.0, 90.0)):
        s.emitter("ash", (x, 22.0, z), 0.0, size=(120.0, 30.0, 120.0))
    for x, z in (P.BOWL_C, (-70.0, -40.0), (70.0, 60.0)):
        s.emitter("dust", (x, 10.0, z), 0.0, size=(44.0, 14.0, 44.0))
    for x, z, w, d in ((0.0, 30.0, 90.0, 70.0), (-70.0, -70.0, 70.0, 50.0), (60.0, -90.0, 70.0, 50.0),
                       (110.0, 40.0, 60.0, 70.0)):
        s.emitter("mist", (x, 1.0, z), 0.0, size=(w, 5.0, d))
    gx, gz = P.ACADEMY_C
    s.emitter("mist", (gx, 1.0, gz), 0.0, size=(50.0, 4.0, 50.0))
    # Low belts of cloud along the horizon on every side but the glow's, and the thin layers high over the basin.
    for x, z, w, d in ((0.0, 900.0, 2200.0, 300.0), (-900.0, 0.0, 300.0, 2200.0), (900.0, 0.0, 300.0, 2200.0)):
        s.emitter("realmcloud", (x, 24.0, z), 0.0, size=(w, 40.0, d))
    s.emitter("realmhaze", (0.0, 170.0, 0.0), 0.0, size=(1500.0, 60.0, 1500.0))
    s.emitter("realmhaze", (0.0, 260.0, -300.0), 0.0, size=(1800.0, 60.0, 1400.0))
    # The sounds: wind through the rock at the grotto's mouth and round the great chain (the beds and the one-shots
    # are the client's, Audio/RealmAmbience).
    s.sound("realmRocks", (P.GATE[0], 10.0, P.GATE[1]), 80.0, 0.5)
    s.sound("realmRocks", (P.PK_CENTER[0], 30.0, P.PK_CENTER[1]), 90.0, 0.5)


def build(s):
    taken = solids(s)
    ruins(s, taken)
    bones(s, taken)
    grass(s, taken)
    ways(s)
    sway(s)
    ambience(s)
