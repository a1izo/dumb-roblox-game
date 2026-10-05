"""The Grey Realm's dressing, every piece placed by hand: dead trees (their trunks solid), the
braziers round the plaza, crooked lantern posts along the ways people walk, skull piles and loose
bones, old flagstones stepping from the plaza to the Academy, the monolith and the rift; drifting
ash over the whole basin and the wind."""

import math
import random

from maps import catalog
from maps import geo2d as g2
from maps.venues.lobby import plan as P

# kind, x, z, rot, scale
TREES = [
    ("DeadTreeGnarled", -60.0, -12.0, 40.0, 1.0),
    ("DeadTree", -100.0, 40.0, 130.0, 1.0),
    ("DeadTreeGnarled", -78.0, -18.0, 250.0, 1.1),
    ("DeadTreeGnarled", 22.0, -44.0, 300.0, 0.9),
    ("DeadTree", 80.0, 72.0, 10.0, 0.95),
    ("DeadTree", 140.0, 8.0, 200.0, 1.1),
    ("DeadTree", 64.0, -80.0, 80.0, 1.05),
    ("DeadTreeGnarled", -22.0, -100.0, 160.0, 1.0),
    ("DeadTree", -110.0, 100.0, 60.0, 0.9),
    ("DeadTree", 20.0, 64.0, 220.0, 0.85),
    ("DeadTreeGnarled", -30.0, 112.0, 20.0, 1.2),
    ("DeadTree", 90.0, -110.0, 340.0, 1.0),
    ("DeadTreeGnarled", 104.0, 84.0, 100.0, 1.0),
]

LANTERNS = [(-30.0, -22.0, 60.0), (30.0, 44.0, 230.0), (-56.0, 56.0, 150.0), (60.0, 32.0, 290.0), (-50.0, -34.0, 10.0),
            (40.0, 96.0, 120.0), (-90.0, 8.0, 200.0), (104.0, -48.0, 330.0), (-8.0, -84.0, 100.0)]

BRAZIERS = [(23.3, 31.3), (-23.3, 31.3), (-23.3, -15.3), (23.3, -15.3), (72.0, 44.0), (-104.0, 56.0)]

SKULL_PILES = [(-52.0, -52.0, 30.0, 1.0), (128.0, 40.0, 200.0, 1.3), (-40.0, -122.0, 90.0, 1.1), (82.0, -58.0, 300.0, 0.9),
               (-110.0, 36.0, 10.0, 1.4), (8.0, 142.0, 150.0, 1.2), (-100.0, 128.0, 250.0, 1.0)]


def blocked(x, z, r, extra=()):
    """True when a circle of radius r at (x, z) would touch anything solid the plan knows of, or
    one of `extra` ((x, z, r) circles), or leave the basin."""
    if not g2.contains(P.BASIN, (x, z)) or g2.dist_to_poly_edge(P.BASIN, (x, z)) < r + 11.0:
        return True
    for poly in P.footprints().values():
        if g2.contains(poly, (x, z)) or g2.dist_to_poly_edge(poly, (x, z)) < r + 1.0:
            return True
    for ex, ez, er in extra:
        if math.dist((x, z), (ex, ez)) < r + er + 1.0:
            return True
    if math.dist((x, z), P.PLAZA_C) < P.PLAZA_R + r and math.dist((x, z), P.PLINTH[:2]) < 10 + r:
        return True
    return False


def trunk(key, x, z, rot, sc):
    """Where a tree's trunk stands: the prop is placed by the middle of its (leaning) crown, its
    trunk sits off that by its catalog anchor, turned with it."""
    ax, az = (catalog.load().get(key) or {}).get("anchor") or (0.0, 0.0)
    a = math.radians(rot)
    c, s_ = math.cos(a), math.sin(a)
    return x + (ax * c + az * s_) * sc, z + (-ax * s_ + az * c) * sc


def trees(s, taken):
    for kind, x, z, rot, sc in TREES + [("WitheredAppleTree", P.APPLE_TREE[0], P.APPLE_TREE[1], 200.0, 1.0)]:
        if blocked(x, z, 2.5, taken) and kind != "WitheredAppleTree":
            continue
        s.prop(kind, x, z, rot, sc)
        tx, tz = trunk(kind, x, z, rot, sc)
        s.collider((tx, 5.0, tz), (1.8 * sc, 10.0, 1.8 * sc), rot, True, "Bark")
        taken.append((tx, tz, 2.5))


def lights(s, taken):
    for x, z, rot in LANTERNS:
        if blocked(x, z, 1.5, taken):
            continue
        s.prop("LanternPost", x, z, rot)
        taken.append((x, z, 1.5))
    for x, z in BRAZIERS:
        if blocked(x, z, 2.0, taken):
            continue
        s.prop("BoneBrazier", x, z, (x * 7 + z * 3) % 360)
        taken.append((x, z, 2.0))


def bones(s, taken):
    for x, z, rot, sc in SKULL_PILES:
        if blocked(x, z, 2.4 * sc, taken):
            continue
        s.prop("SkullPile", x, z, rot, sc)
        taken.append((x, z, 2.4 * sc))
    rng = random.Random(1313)
    placed = 0
    tries = 0
    while placed < 16 and tries < 400:
        tries += 1
        a = rng.uniform(0, math.tau)
        d = rng.uniform(36, 150)
        x, z = math.cos(a) * d, math.sin(a) * d
        if blocked(x, z, 2.6, taken):
            continue
        s.prop("BoneScatter", x, z, rng.uniform(0, 360), rng.uniform(0.9, 1.4))
        taken.append((x, z, 2.6))
        placed += 1
    for x, z in ((-150.0, 60.0), (60.0, -140.0), (150.0, -40.0), (-60.0, 140.0), (120.0, 90.0)):
        if not blocked(x, z, 2.0, taken):
            s.prop("Cairn", x, z, (x + z) % 360, 1.2)
            taken.append((x, z, 2.0))


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
    stepping(s, [(-22.0, 28.0), (-40.0, 46.0), (-58.0, 62.0), (-64.0, 68.0)], 41)
    stepping(s, [(0.0, -22.0), (0.0, -42.0), (0.0, -58.0)], 42)
    stepping(s, [(28.0, 12.0), (48.0, 18.0), (66.0, 22.0)], 43)
    stepping(s, [(-26.0, -6.0), (-44.0, -24.0), (-58.0, -36.0)], 44)


# Things the game builds and sways in the wind (src/client/World/WindSway): roots hanging from
# lintels and from the island's rim, banners on poles. Anchors: root<n> (x, y, z, h = length) hangs
# from its anchor down; banner<n> stands on its anchor (h = the pole's height).
LINTEL_ROOTS = [(-66.5, 15.5, 64.5, 6.0), (-63.3, 15.5, 68.1, 8.0), (-60.0, 15.5, 71.7, 5.0)]
RIM_ROOT_DEGREES = (196.0, 212.0, 236.0, 250.0, 276.0, 300.0, 322.0, 346.0, 24.0, 118.0, 150.0)
BANNERS = [(-9.0, 11.0, 53.6, 0.0), (9.0, 11.0, 53.6, 0.0), (-46.0, 0.0, 62.0, 40.0), (46.0, 0.0, 66.0, -40.0)]


def sway(s, taken):
    roots = list(LINTEL_ROOTS)
    nx, nz = P.RIFT_MID[0] - 3.0, P.RIFT_MID[1] - P.RIFT_AXES[1] - 9.5
    roots += [(nx - 6.0, 16.2, nz, 7.0), (nx - 1.0, 17.6, nz, 6.0)]
    for deg in RIM_ROOT_DEGREES:
        x, z = P.rim_at(deg, -1.0)
        roots.append((x, -1.5, z, 14.0 + (deg % 7)))
    for k, (x, y, z, length) in enumerate(roots):
        s.anchor(f"root{k + 1}", x, y, z, 0.0, h=length)
    n = 0
    for x, y, z, rot in BANNERS:
        if blocked(x, z, 1.0, taken):
            continue
        n += 1
        s.anchor(f"banner{n}", x, y, z, rot, w=3.2, h=10.0)


def ambience(s):
    # Ash drifting over the island, motes hanging in the still air, mist lying low (all thinned on weak devices).
    for x, z in ((0.0, 0.0), (-90.0, -60.0), (90.0, -60.0), (-80.0, 90.0), (80.0, 90.0)):
        s.emitter("ash", (x, 22.0, z), 0.0, size=(120.0, 30.0, 120.0))
    for x, z in ((0.0, 20.0), (-70.0, -40.0), (70.0, 60.0)):
        s.emitter("dust", (x, 10.0, z), 0.0, size=(44.0, 14.0, 44.0))
    for x, z, w, d in ((0.0, 40.0, 90.0, 60.0), (-70.0, -70.0, 70.0, 50.0), (60.0, -80.0, 70.0, 50.0), (-90.0, 90.0, 70.0, 50.0)):
        s.emitter("mist", (x, 1.0, z), 0.0, size=(w, 5.0, d))
    # Low belts of cloud lying along the horizon on every side, and the thin layers high over the basin.
    for x, z, w, d in ((0.0, -900.0, 2200.0, 300.0), (0.0, 900.0, 2200.0, 300.0), (-900.0, 0.0, 300.0, 2200.0),
                       (900.0, 0.0, 300.0, 2200.0)):
        s.emitter("realmcloud", (x, 24.0, z), 0.0, size=(w, 40.0, d))
    s.emitter("realmhaze", (0.0, 170.0, 0.0), 0.0, size=(1500.0, 60.0, 1500.0))
    s.emitter("realmhaze", (0.0, 260.0, -300.0), 0.0, size=(1800.0, 60.0, 1400.0))
    # The sounds: wind through the rocks at the vistas (the beds and the one-shots are the client's,
    # Audio/RealmAmbience).
    s.sound("realmRocks", (P.CLEFT[0], 14.0, P.CLEFT[1]), 80.0, 0.5)
    s.sound("realmRocks", (P.NEEDLE[0], 12.0, P.NEEDLE[1]), 80.0, 0.5)


def build(s):
    taken = []
    trees(s, taken)
    lights(s, taken)
    bones(s, taken)
    ways(s)
    sway(s, taken)
    ambience(s)
