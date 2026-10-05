"""The world beyond the island: nothing to stand on, only shapes in the haze. Floating rocks of all
sizes with spires on them, suspended islands with broken towers, great arches, leaning boulders,
curving horns, walls of cloud, a litter of floating debris near the island, and, far to the north
and half lost in fog, one colossal blade standing point-down in a rock, with a rock arch in front of
it so the first view frames it.

None of it can be reached (nothing here collides); the farther it is, the coarser it may be, since
the fog hides the detail. Everything is a placement from a seeded random source."""

import math
import random

from maps import geo2d as g2
from maps.venues.lobby import plan as P
from maps.venues.lobby.terrain import arch, blade, cloud_bank, floating_rock, horn, needle_field, rock, spire


def clear(x, z, r):
    """True when a circle of radius r at (x, z) is clear of the island, the two islets and the bridges."""
    if math.hypot(x, z) < 178.0 + r * 0.9:
        return False
    for ix, iz, ir in (P.ISLET_RUNE, P.ISLET_PARKOUR):
        if math.dist((x, z), (ix, iz)) < ir + 46.0 + r:
            return False
    for a, b in (P.BRIDGE_RUNE, P.BRIDGE_PARKOUR):
        if g2.dist_point_segment((x, z), a, b) < 34.0 + r:
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
    """Positions on a ring around the island: [(x, z, r)] with clear circles of size (lo, hi)."""
    out = []
    for _ in range(count):
        for _ in range(tries):
            a = rng.uniform(*angles) if angles else rng.uniform(0, math.tau)
            d = rng.uniform(rmin, rmax)
            r = rng.uniform(*size) * (1.0 + 0.8 * (d - rmin) / (rmax - rmin))
            x, z = math.cos(a) * d, math.sin(a) * d
            if clear(x, z, r) and all(math.dist((x, z), (tx, tz)) > r + tr + 8.0 for tx, tz, tr in taken):
                out.append((x, z, r))
                taken.append((x, z, r))
                break
    return out


def heroes(s, taken):
    """The shapes the first view is built from, north of the island: a great arch with the colossal
    blade standing behind it, and floating islands either side."""
    bx, bz = -34.0, -760.0
    r = 120.0
    taken.append((bx, bz, r))
    depth = floating_rock(s, bx, -30.0, bz, r, 9001, depth=190.0, sides=11, spires=3)
    blade(s, bx, -48.0, bz, 46.0, 420.0, 12.0, rot=0.0)
    for k in range(4):
        a = math.radians(210 + k * 40)
        spire(s, bx + math.cos(a) * 80.0, bz + math.sin(a) * 50.0, 8.0, 40.0 + k * 10.0, 9100 + k, y=-26.0)
    # The arch before it.
    ax, az = -70.0, -540.0
    floating_rock(s, ax - 82.0, -20.0, az, 46.0, 9002, depth=120.0, sides=9)
    floating_rock(s, ax + 82.0, -20.0, az, 40.0, 9003, depth=110.0, sides=9)
    arch(s, ax, -20.0, az, 164.0, 126.0, 17.0, 0.0, 9004, sections=14)
    taken.extend([(ax, az, 110.0)])
    # Floating islands left and right, leaning columns and towers on them.
    for k, (x, z, y, rr, tower) in enumerate(((-300.0, -430.0, 10.0, 70.0, True), (250.0, -470.0, 0.0, 84.0, False),
                                                (-430.0, -150.0, 30.0, 60.0, True), (400.0, -230.0, 20.0, 56.0, False))):
        if not clear(x, z, rr):
            continue
        floating_rock(s, x, y, z, rr, 9200 + k, depth=rr * 1.8, sides=10, spires=2)
        taken.append((x, z, rr))
        if tower:
            ruin_tower(s, x + rr * 0.2, y, z - rr * 0.1, rr * 0.2, rr * 1.9, 9300 + k)
        else:
            needle_field(s, x, z, rr * 0.7, 10, rr * 0.3, rr * 0.9, 9400 + k, y=y)


def far_world(s):
    rng = random.Random(9001)
    taken = []
    heroes(s, taken)
    # Floating rocks, hanging at every height; some with spires.
    for k, (x, z, r) in enumerate(ring_place(rng, 54, 230.0, 940.0, (10.0, 34.0), taken)):
        y = rng.uniform(-70.0, 120.0)
        floating_rock(s, x, y, z, r, 9500 + k, sides=9 if r < 40 else 11, spires=rng.choice((0, 0, 1, 2, 3)))
    # Suspended islands: broad ones with ruins and needles on top.
    for k, (x, z, r) in enumerate(ring_place(rng, 7, 380.0, 900.0, (46.0, 70.0), taken)):
        y = rng.uniform(-40.0, 60.0)
        floating_rock(s, x, y, z, r, 9700 + k, depth=r * 1.7, sides=12, spires=1)
        for q in range(rng.randint(1, 3)):
            a = rng.uniform(0, math.tau)
            ruin_tower(s, x + math.cos(a) * r * 0.45, y, z + math.sin(a) * r * 0.45, rng.uniform(5.0, 9.0),
                       rng.uniform(26.0, 70.0), 9800 + k * 5 + q)
        needle_field(s, x, z, r * 0.7, 12, 10.0, 34.0, 9900 + k, y=y)
    # Leaning boulders on small floating rocks.
    for k, (x, z, r) in enumerate(ring_place(rng, 9, 260.0, 800.0, (14.0, 24.0), taken)):
        y = rng.uniform(-30.0, 80.0)
        floating_rock(s, x, y, z, r, 9950 + k, depth=r * 1.4, sides=8)
        a = rng.uniform(0, math.tau)
        rock(s, x, z, r * 0.7, r * rng.uniform(1.8, 2.8), 9960 + k, y=y, tiers=3, sides=8, taper=0.5,
             lean=(math.cos(a) * 0.4, math.sin(a) * 0.4), collide=False)
    # Further arches, smaller, on their own rocks.
    for k, (x, z, r) in enumerate(ring_place(rng, 4, 420.0, 880.0, (48.0, 64.0), taken)):
        y = rng.uniform(-30.0, 50.0)
        floating_rock(s, x, y, z, r, 9980 + k, depth=r * 1.3, sides=11)
        arch(s, x, y, z, r * 1.2, r * 1.0, r * 0.14, rng.uniform(0, 180), 9990 + k, sections=11)
    # Great horns standing on floating rocks, curling over.
    for k, (x, z, r) in enumerate(ring_place(rng, 7, 280.0, 760.0, (16.0, 26.0), taken)):
        y = rng.uniform(-20.0, 70.0)
        floating_rock(s, x, y, z, r, 10100 + k, depth=r * 1.5, sides=8)
        for q in range(rng.choice((1, 2))):
            a = rng.uniform(0, math.tau)
            horn(s, x + math.cos(a) * r * 0.3, y, z + math.sin(a) * r * 0.3, rng.uniform(40.0, 70.0), rng.uniform(16.0, 34.0),
                 math.degrees(a), rng.uniform(3.0, 4.6))
    # Floating debris: small chunks hanging near the island, thicker round the vista ledges.
    dust = 0
    tries = 0
    while dust < 90 and tries < 600:
        tries += 1
        a = rng.uniform(0, math.tau)
        d = rng.uniform(176.0, 340.0)
        x, z = math.cos(a) * d, math.sin(a) * d
        if not clear(x, z, 7.0):
            continue
        r = rng.uniform(1.4, 6.0)
        floating_rock(s, x, rng.uniform(-60.0, 90.0), z, r, 10200 + dust, depth=r * rng.uniform(1.0, 2.0), sides=6)
        dust += 1
    # Walls of cloud all round: dark masses low on the horizon, pale ones above.
    for k in range(26):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(640.0, 1180.0)
        x, z = math.cos(a) * d, math.sin(a) * d
        if abs(x + 34.0) < 140.0 and z < -400.0 and z > -820.0:
            continue  # keep the view of the blade open
        cloud_bank(s, x, rng.uniform(-110.0, 150.0), z, rng.uniform(220.0, 520.0), rng.uniform(70.0, 150.0), 10300 + k,
                   rot=math.degrees(a) + 90.0 + rng.uniform(-25.0, 25.0), puffs=rng.randint(6, 9))


def build(s):
    far_world(s)
