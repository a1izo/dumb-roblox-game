"""The wasteland beyond the basin's border (remade 2026-11-04 to the reference videos): the plain going on to the
horizon and, standing on it out of reach, the shapes that make the realm what it is. Under the glow in the north,
ranges of jagged pale shards; east and west of it, walls of dark cloud; colossal chains hanging out of the sky into
heaps of junk; billowing masses of rock like cloud turned to stone, lone shards, twisted columns, a few arches,
colossal tusks in pairs and the ribs of skeletons arching out of the ash; dunes.

None of it can be reached (nothing here collides); the farther it is, the coarser it may be, since the fog
hides the detail. Everything is a placement from a seeded random source."""

import math
import random

from maps import geo2d as g2
from maps.venues.lobby import ground as surface
from maps.venues.lobby import plan as P
from maps.venues.lobby import rocks
from maps.venues.lobby.terrain import arch, cloud_bank, column, face


def clear(x, z, r):
    """True when a circle of radius r at (x, z) is clear of the basin and its two ridges, the plateaus and the
    causeways with their chasms."""
    if math.hypot(x, z) < 238.0 + r * 0.9:
        return False
    for ix, iz, ir in (P.ISLET_RUNE, P.ISLET_PARKOUR):
        if math.dist((x, z), (ix, iz)) < ir + 44.0 + r:
            return False
    for a, b in (P.BRIDGE_RUNE, P.BRIDGE_PARKOUR):
        if g2.dist_point_segment((x, z), a, b) < 56.0 + r:
            return False
    return True


def ring_place(rng, count, rmin, rmax, size, taken, tries=40, angles=None):
    """Positions on a ring round the basin: [(x, z, r)] with clear circles of size (lo, hi), growing with distance."""
    out = []
    for _ in range(count):
        for _ in range(tries):
            a = rng.uniform(*angles) if angles else rng.uniform(0, math.tau)
            d = rng.uniform(rmin, rmax)
            r = rng.uniform(*size) * (1.0 + 0.8 * (d - rmin) / (rmax - rmin))
            x, z = math.cos(a) * d, math.sin(a) * d
            if clear(x, z, r) and all(math.dist((x, z), (tx, tz)) > r + tr + 6.0 for tx, tz, tr in taken):
                out.append((x, z, r))
                taken.append((x, z, r))
                break
    return out


def heroes(s, taken):
    """The skyline the first view looks out on (2026-11-04, the reference videos): due north, under the glow, ranges of
    jagged pale shards; colossal chains hanging out of the sky into heaps of junk east and west of it."""
    rng = random.Random(9000)
    # The shard ranges: clusters along two broken lines across the north, the nearer one lower.
    for line, (d0, d1, count, sc) in enumerate(((560.0, 700.0, 16, (0.9, 1.6)), (820.0, 1060.0, 22, (1.4, 2.6)))):
        for k in range(count):
            a = math.radians(rng.uniform(222.0, 318.0))
            d = rng.uniform(d0, d1)
            x, z = math.cos(a) * d, math.sin(a) * d
            k_sc = rng.uniform(*sc)
            key = rng.choice(("RealmShardsB", "RealmShardsB", "RealmShardSpire")) if line else "RealmShardsB"
            if not clear(x, z, 30.0 * k_sc):
                continue
            rocks.rock(s, key, x, z, rng.uniform(0, 360), k_sc * (0.55 if key == "RealmShardSpire" else 1.0),
                       collide=False)
            taken.append((x, z, 26.0 * k_sc))
    # The great chains, hanging out of the sky into heaps of junk (one either side of the glow, one far behind).
    for k, (x, z, sc) in enumerate(((-420.0, -520.0, 1.6), (460.0, -480.0, 1.8), (-180.0, 760.0, 2.0))):
        if not clear(x, z, 60.0):
            continue
        s.prop("GreatChain", x, z, rng.uniform(0, 360), sc, 0.0)
        for q in range(7):
            a = rng.uniform(0, math.tau)
            d = rng.uniform(4.0, 30.0) * sc
            key = rng.choice(("RealmBillowCFar", "RealmBoulderAFar", "RealmCragBFar"))
            rocks.rock(s, key, x + math.cos(a) * d, z + math.sin(a) * d, rng.uniform(0, 360),
                       rng.uniform(0.8, 1.6) * sc * (0.5 if key == "RealmBillowCFar" else 1.0), collide=False)
        taken.append((x, z, 50.0 * sc))


def ribs(s, taken, rng):
    """The ribs of colossal skeletons, arching out of the plain."""
    for k, (cx, cz, span, height, turn) in enumerate(((-330.0, -420.0, 90.0, 70.0, 30.0), (520.0, 160.0, 120.0, 95.0, -60.0),
                                                      (-560.0, 300.0, 100.0, 80.0, 75.0))):
        if not clear(cx, cz, span):
            continue
        taken.append((cx, cz, span))
        t = math.radians(turn)
        along = (math.cos(t), math.sin(t))
        side = (-along[1], along[0])
        for rib in range(6):
            base = (cx + along[0] * rib * span * 0.18, cz + along[1] * rib * span * 0.18)
            points, radii = [], []
            for q in range(9):
                u = q / 8
                ang = math.pi * u
                px = base[0] + side[0] * math.cos(ang) * span / 2
                pz = base[1] + side[1] * math.cos(ang) * span / 2
                py = math.sin(ang) * height * (1 - 0.12 * rib) - 2.0
                points.append((px, py, pz))
                radii.append(3.2 - 1.2 * abs(u - 0.5))
            with s.smooth():
                s.bent_tube("BoneOld", points, radii, 7, caps=(False, False))  # (both feet in the ash)
        for q in range(7):
            a0 = (cx + along[0] * (q - 0.5) * span * 0.18, height - 4 - q * 2.2, cz + along[1] * (q - 0.5) * span * 0.18)
            with s.smooth():
                s.lathe("BoneOld", a0, [(0.0, -3.0), (4.2, -2.2), (4.6, 0.0), (4.2, 2.2), (0.0, 3.0)], 9,
                        caps=(False, False))


def far_world(s):
    rng = random.Random(9001)
    taken = []
    heroes(s, taken)
    ribs(s, taken, rng)
    # Billowing masses of rock on the plain, like cloud turned to stone, bigger the farther they stand.
    for k, (x, z, r) in enumerate(ring_place(rng, 18, 260.0, 1050.0, (16.0, 34.0), taken)):
        key = rng.choice(("RealmBillowAFar", "RealmBillowBFar", "RealmBillowCFar"))
        rocks.rock(s, key, x, z, rng.uniform(0, 360), r / 22.0, collide=False)
    # Shards standing alone or in twos about the plain, and fields of small ones.
    for k, (x, z, r) in enumerate(ring_place(rng, 16, 250.0, 950.0, (8.0, 16.0), taken)):
        for q in range(rng.choice((1, 2))):
            a = rng.uniform(0, math.tau)
            rocks.rock(s, "RealmShardsA", x + math.cos(a) * r * 0.6, z + math.sin(a) * r * 0.6, rng.uniform(0, 360),
                       r / 8.0 * rng.uniform(0.8, 1.3), collide=False)
    # Twisted fluted columns standing alone, and a few arches.
    for k, (x, z, r) in enumerate(ring_place(rng, 8, 300.0, 1000.0, (6.0, 12.0), taken)):
        column(s, x, z, r, r * rng.uniform(9.0, 15.0), 10000 + k, twist=rng.uniform(1.0, 2.6), sides=10, tiers=8,
               collide=False)
    for k, (x, z, r) in enumerate(ring_place(rng, 3, 380.0, 950.0, (40.0, 60.0), taken)):
        arch(s, x, 0.0, z, r * 1.5, r * 1.2, r * 0.17, rng.uniform(0, 180), 10200 + k, sections=11)
    # Colossal tusks curving out of the ground, in pairs.
    for k, (x, z, r) in enumerate(ring_place(rng, 9, 260.0, 850.0, (8.0, 12.0), taken)):
        turn = rng.uniform(0, 360)
        for q, side in enumerate((-1, 1)):
            if q and rng.random() < 0.4:
                continue
            a = math.radians(turn)
            rocks.rock(s, "RealmTuskFar", x + math.cos(a) * side * r, z - math.sin(a) * side * r,
                       turn + (180.0 if side > 0 else 0.0), r / 9.0 * rng.uniform(0.9, 1.4), collide=False)
    # Dunes: long low mounds of ash, out past the ground's own swells and dunes (lobby ground.py, to its REACH).
    for k in range(28):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(240.0, 1200.0)
        x, z = math.cos(a) * d, math.sin(a) * d
        rr = rng.uniform(25.0, 80.0)
        if not clear(x, z, rr * 0.6) or max(abs(x), abs(z)) < surface.REACH + rr:
            continue
        h = rr * rng.uniform(0.08, 0.18)
        with s.smooth():
            s.lathe("RealmAsh", (x, -0.3, z), [(rr, 0.0), (rr * 0.7, h * 0.45), (rr * 0.35, h * 0.9), (0.0, h)], 10,
                    caps=(False, False))
    # Walls of dark cloud on the skyline east and west of the glow (the north is left open over the shards, so the glow
    # shows over them), and lower banks all round.
    for k in range(16):
        side = 1 if k % 2 else -1
        a = math.radians(270.0 + side * rng.uniform(55.0, 150.0))
        d = rng.uniform(700.0, 1200.0)
        x, z = math.cos(a) * d, math.sin(a) * d
        cloud_bank(s, x, rng.uniform(10.0, 160.0), z, rng.uniform(260.0, 560.0), rng.uniform(90.0, 170.0), 10700 + k,
                   rot=math.degrees(a) + 90.0 + rng.uniform(-25.0, 25.0), puffs=rng.randint(7, 10))
    for k in range(5):
        a = math.radians(270.0 + rng.uniform(-40.0, 40.0))
        d = rng.uniform(1050.0, 1250.0)
        cloud_bank(s, math.cos(a) * d, rng.uniform(-20.0, 20.0), math.sin(a) * d, rng.uniform(300.0, 500.0),
                   rng.uniform(40.0, 70.0), 10800 + k, rot=math.degrees(a) + 90.0, puffs=6, height=40.0)


# The skyline's foot: a low wall of dark cloud all round, inside the plain's edge. Where the plain stopped, the
# sky's dark lower half showed under the cloud walls as a black band along the horizon (the 2026-10-12
# pictures); this rises over that edge from every place people stand (the basin, the plateaus, the Spire's
# top), and the haze turns it into a soft dark line. It faces inwards only: nothing of it shows from outside.
SKIRT_R = 1400.0
SKIRT = (-1.0, 28.0)


def horizon_skirt(s):
    n = 64
    y0, y1 = SKIRT
    for k in range(n):
        a0, a1 = math.tau * k / n, math.tau * (k + 1) / n
        p0 = (math.cos(a0) * SKIRT_R, math.sin(a0) * SKIRT_R)
        p1 = (math.cos(a1) * SKIRT_R, math.sin(a1) * SKIRT_R)
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        face(s, "CloudUnder", [(p0[0], y0, p0[1]), (p1[0], y0, p1[1]), (p1[0], y1, p1[1]), (p0[0], y1, p0[1])],
             (mid[0] * 1.5, (y0 + y1) / 2, mid[1] * 1.5))


def build(s):
    far_world(s)
    horizon_skirt(s)
