"""The wasteland beyond the basin's ridge: the plain going on to the horizon, and standing on it, out of reach,
the shapes that make the realm what it is. Spires in clusters, mesas with ruins and needles on them, huge
twisted fluted columns, leaning boulders, arches, curving horns, the ribs of colossal skeletons, low ridges,
dunes, needle fields; walls of cloud on the skyline; and, far to the north, one colossal blade standing in a
rock mound, with a rock arch before it so the first view frames it. A handful of rocks float high in the sky,
the only things that do.

None of it can be reached (nothing here collides); the farther it is, the coarser it may be, since the fog
hides the detail. Everything is a placement from a seeded random source."""

import math
import random

from maps import geo2d as g2
from maps.venues.lobby import plan as P
from maps.venues.lobby.terrain import (arch, blade, boulder, cloud_bank, column, floating_rock, horn, mesa,
                                       needle_field, rock, spire)


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


def ruin_tower(s, x, y, z, w, h, seed, mat="RuinStone"):
    """A broken stone tower: a tapering eight-sided shaft, its top torn into blocks, dark slits."""
    rng = random.Random(seed)
    s.lathe(mat, (x, y - 1.0, z), [(w * 1.25, 0.0), (w * 1.0, h * 0.12), (w * 0.88, h * 0.55), (w * 0.8, h)], 8,
            caps=(False, False))
    for k in range(8):
        a = math.tau * (k + 0.5) / 8
        top = h - rng.uniform(0.0, h * 0.14)
        bw = w * 0.5
        s.box(mat, (x + math.cos(a) * w * 0.55, y + top, z + math.sin(a) * w * 0.55), (bw, rng.uniform(1.0, h * 0.1), bw),
              math.degrees(a))
    for level in (0.28, 0.5, 0.74):
        for k in range(4):
            a = math.tau * (k + 0.5) / 4 + 0.4
            rr = w * (1.0 - 0.2 * level) * 0.93
            s.box("Abyss", (x + math.cos(a) * rr, y + h * level, z + math.sin(a) * rr), (w * 0.16, h * 0.07, 0.5),
                  -math.degrees(a) + 90.0)


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
    """The shapes the first view is built from, north of the basin: the colossal blade in its mound with a great
    arch before it, and giant twisted columns either side."""
    bx, bz = -34.0, -760.0
    taken.append((bx, bz, 110.0))
    mesa(s, bx, bz, 96.0, 38.0, 9001, collide=False)
    blade(s, bx, 34.0, bz, 46.0, 420.0, 12.0, rot=0.0)
    for k in range(4):
        a = math.radians(205 + k * 45)
        spire(s, bx + math.cos(a) * 118.0, bz + math.sin(a) * 70.0, 9.0, 55.0 + k * 14.0, 9100 + k)
    # The arch before it, its feet on two mounds.
    ax, az = -70.0, -540.0
    mesa(s, ax - 82.0, az, 34.0, 16.0, 9002, collide=False)
    mesa(s, ax + 82.0, az, 30.0, 14.0, 9003, collide=False)
    arch(s, ax, 15.0, az, 164.0, 126.0, 17.0, 0.0, 9004, sections=14)
    taken.extend([(ax, az, 110.0)])
    # Giant twisted columns, the mountains of this place.
    for k, (x, z, r, h) in enumerate(((-300.0, -430.0, 22.0, 210.0), (250.0, -470.0, 26.0, 240.0),
                                       (-430.0, -150.0, 18.0, 170.0), (400.0, -230.0, 20.0, 190.0),
                                       (-90.0, 560.0, 20.0, 180.0), (320.0, 380.0, 24.0, 220.0))):
        if not clear(x, z, r):
            continue
        column(s, x, z, r, h, 9200 + k, twist=1.8, sides=12, tiers=12, collide=False)
        taken.append((x, z, r * 1.5))
        if k % 2 == 0:
            ruin_tower(s, x + r * 2.2, 0.0, z, r * 0.3, r * 2.4, 9300 + k)


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
            prev = None
            for q in range(9):
                u = q / 8
                ang = math.pi * u
                px = base[0] + side[0] * math.cos(ang) * span / 2
                pz = base[1] + side[1] * math.cos(ang) * span / 2
                py = math.sin(ang) * height * (1 - 0.12 * rib) - 2.0
                if prev:
                    s.tube("BoneOld", prev, (px, py, pz), 3.2 - 1.2 * abs(u - 0.5), 7, caps=False)
                prev = (px, py, pz)
        for q in range(7):
            a0 = (cx + along[0] * (q - 0.5) * span * 0.18, height - 4 - q * 2.2, cz + along[1] * (q - 0.5) * span * 0.18)
            s.lathe("BoneOld", a0, [(0.0, -3.0), (4.2, -2.2), (4.6, 0.0), (4.2, 2.2), (0.0, 3.0)], 9, caps=(False, False))


def far_world(s):
    rng = random.Random(9001)
    taken = []
    heroes(s, taken)
    ribs(s, taken, rng)
    # Spires in clusters, taller and fatter the farther they stand.
    for k in range(22):
        for x, z, r in ring_place(rng, 1, 250.0, 1150.0, (4.0, 10.0), taken):
            for q in range(rng.randint(2, 5)):
                a = rng.uniform(0, math.tau)
                d = rng.uniform(0.0, r * 2.2)
                sr = r * rng.uniform(0.5, 1.0)
                spire(s, x + math.cos(a) * d, z + math.sin(a) * d, sr, sr * rng.uniform(5.0, 10.0), 9500 + k * 7 + q)
    # Mesas with needles and ruins on top.
    for k, (x, z, r) in enumerate(ring_place(rng, 12, 300.0, 1100.0, (28.0, 60.0), taken)):
        top = rng.uniform(18.0, 62.0) * (1.0 + 0.4 * r / 90.0)
        mesa(s, x, z, r, top, 9700 + k, collide=False)
        if k % 3 == 0:
            for q in range(rng.randint(1, 2)):
                a = rng.uniform(0, math.tau)
                ruin_tower(s, x + math.cos(a) * r * 0.4, top, z + math.sin(a) * r * 0.4, rng.uniform(5.0, 9.0),
                           rng.uniform(26.0, 70.0), 9800 + k * 5 + q)
        needle_field(s, x, z, r * 0.7, 7, 8.0, 30.0, 9900 + k, y=top)
    # Twisted fluted columns standing alone.
    for k, (x, z, r) in enumerate(ring_place(rng, 14, 260.0, 1000.0, (6.0, 12.0), taken)):
        column(s, x, z, r, r * rng.uniform(9.0, 15.0), 10000 + k, twist=rng.uniform(1.0, 2.6), sides=10, tiers=8, collide=False)
    # Leaning boulders as big as houses.
    for k, (x, z, r) in enumerate(ring_place(rng, 8, 260.0, 900.0, (16.0, 30.0), taken)):
        a = rng.uniform(0, math.tau)
        rock(s, x, z, r, r * rng.uniform(1.6, 2.6), 10100 + k, tiers=3, sides=8, taper=0.5,
             lean=(math.cos(a) * 0.4, math.sin(a) * 0.4), collide=False)
    # Arches standing on the ground, big enough to walk a town through.
    for k, (x, z, r) in enumerate(ring_place(rng, 4, 380.0, 950.0, (40.0, 60.0), taken)):
        arch(s, x, 0.0, z, r * 1.5, r * 1.2, r * 0.17, rng.uniform(0, 180), 10200 + k, sections=11)
    # Great horns standing out of the ground, curling over.
    for k, (x, z, r) in enumerate(ring_place(rng, 8, 280.0, 800.0, (6.0, 10.0), taken)):
        for q in range(rng.choice((1, 2))):
            a = rng.uniform(0, math.tau)
            horn(s, x + math.cos(a) * r, 0.0, z + math.sin(a) * r, rng.uniform(40.0, 75.0), rng.uniform(16.0, 34.0),
                 math.degrees(a), rng.uniform(3.0, 4.6))
    # Fields of needles across the plain.
    for k, (x, z, r) in enumerate(ring_place(rng, 12, 240.0, 1000.0, (14.0, 24.0), taken)):
        needle_field(s, x, z, r, rng.randint(12, 20), 8.0, 38.0, 10300 + k)
    # Low ridges: a line of rocks, falling away at both ends.
    for k in range(5):
        a0 = rng.uniform(0, math.tau)
        d0 = rng.uniform(280.0, 800.0)
        heading = rng.uniform(0, math.tau)
        length = rng.uniform(160.0, 360.0)
        count = int(length / 18.0)
        for q in range(count):
            u = q / max(1, count - 1)
            x = math.cos(a0) * d0 + math.cos(heading) * length * (u - 0.5) + rng.uniform(-6, 6)
            z = math.sin(a0) * d0 + math.sin(heading) * length * (u - 0.5) + rng.uniform(-6, 6)
            if not clear(x, z, 12.0):
                continue
            r = rng.uniform(9.0, 18.0) * (0.5 + math.sin(math.pi * u))
            rock(s, x, z, r, r * rng.uniform(0.9, 1.8), 10400 + k * 40 + q, tiers=2, sides=7, taper=0.45, collide=False)
    # Dunes: long low mounds of ash.
    for k in range(28):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(240.0, 1200.0)
        x, z = math.cos(a) * d, math.sin(a) * d
        rr = rng.uniform(25.0, 80.0)
        if not clear(x, z, rr * 0.6):
            continue
        h = rr * rng.uniform(0.08, 0.18)
        s.lathe("Ash", (x, -0.3, z), [(rr, 0.0), (rr * 0.7, h * 0.45), (rr * 0.35, h * 0.9), (0.0, h)], 10, caps=(False, False))
    # The only things that float: a few rocks high in the sky, and debris about them.
    for k, (x, z, r) in enumerate(ring_place(rng, 12, 300.0, 1000.0, (14.0, 30.0), taken)):
        floating_rock(s, x, rng.uniform(90.0, 240.0), z, r, 10500 + k, depth=r * rng.uniform(1.2, 2.0), sides=9,
                      spires=rng.choice((0, 1, 2)))
    dust = 0
    tries = 0
    while dust < 26 and tries < 300:
        tries += 1
        a = rng.uniform(0, math.tau)
        d = rng.uniform(200.0, 600.0)
        x, z = math.cos(a) * d, math.sin(a) * d
        if not clear(x, z, 7.0):
            continue
        r = rng.uniform(1.5, 5.0)
        floating_rock(s, x, rng.uniform(55.0, 190.0), z, r, 10600 + dust, depth=r * rng.uniform(1.0, 2.0), sides=6)
        dust += 1
    # Walls of cloud on the skyline: dark masses low, pale ones above.
    for k in range(20):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(760.0, 1250.0)
        x, z = math.cos(a) * d, math.sin(a) * d
        if abs(x + 34.0) < 150.0 and -820.0 < z < -380.0:
            continue  # keep the view of the blade open
        cloud_bank(s, x, rng.uniform(-10.0, 130.0), z, rng.uniform(220.0, 520.0), rng.uniform(70.0, 150.0), 10700 + k,
                   rot=math.degrees(a) + 90.0 + rng.uniform(-25.0, 25.0), puffs=rng.randint(6, 9))


def build(s):
    far_world(s)
