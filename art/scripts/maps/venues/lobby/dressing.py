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
    round every prop already stood on the ground that is not rock (the bones by the sweep, the lantern posts)."""
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
    mx, mz = P.GATE
    gate = math.radians(P.GATE_DIR)
    side = (-math.sin(gate), math.cos(gate))
    for k, (off, length) in enumerate(((-5.5, 6.0), (-2.0, 8.0), (1.5, 5.0), (4.8, 7.0))):
        roots.append((mx + side[0] * off, P.GROTTO_MOUTH_H - 0.3, mz + side[1] * off, length))
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
    bones(s, taken)
    grass(s, taken)
    ways(s)
    sway(s)
    ambience(s)
