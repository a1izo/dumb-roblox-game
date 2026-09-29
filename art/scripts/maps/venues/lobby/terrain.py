"""The Grey Realm's ground and rock: the ash plain (a hole cut for the rift), crusts of cracked earth,
rock outcrops and spires, the ring of rocks and bone stakes along the basin's edge with the
invisible wall behind them, and the plain running on past it (dunes, spires, mesas, the bones of
colossal things) to where the haze closes."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.mesher import cross, dot, sub
from maps.venues.lobby import plan as P

NEAR = 192.0  # the ground within this is cut in cells, with colliders and zones
FAR = 1000.0  # how far the plain runs


def face(s, mat, pts, inside):
    """A face whose front looks away from the point `inside`."""
    n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    cz = sum(p[2] for p in pts) / len(pts)
    if dot(n, (cx - inside[0], cy - inside[1], cz - inside[2])) < 0:
        pts = list(reversed(pts))
    s.polygon(mat, pts)


def rock(s, x, z, r, h, seed, mat="RockGrey", y=0.0, tiers=3, sides=9, taper=0.5, lean=(0.0, 0.0), collide=True,
         flat_top=False, squash=1.0, turn=0.0, top_mat=None, collide_h=None):
    """A rock: rings of jittered points stacked `tiers` high, narrowing by taper, leaning; sides
    and a top joined between them. Sunk half a stud into the ground. With collide, a box inside
    its foot stops people (up to collide_h)."""
    rng = random.Random(seed)
    phase = rng.uniform(0, math.tau)
    rings = []
    for t in range(tiers + 1):
        u = t / tiers
        scale_r = r * (1 - taper * u) * (0.92 + 0.16 * rng.random())
        yy = y - 0.5 if t == 0 else y + h * u * (0.94 + 0.08 * rng.random()) if t < tiers else y + h
        cx, cz = x + lean[0] * u * h, z + lean[1] * u * h
        ring = []
        for k in range(sides):
            a = phase + turn * u + 2 * math.pi * (k + rng.uniform(-0.2, 0.2)) / sides
            rk = scale_r * (0.78 + 0.34 * rng.random())
            yk = yy if (t < tiers or flat_top) else yy - rng.uniform(0, h * 0.12)
            ring.append((cx + math.cos(a) * rk, yk, cz + math.sin(a) * rk * squash))
        rings.append(ring)
    for t in range(tiers):
        lo, hi = rings[t], rings[t + 1]
        mid = (x + lean[0] * (t + 0.5) / tiers * h, y + h * (t + 0.5) / tiers, z + lean[1] * (t + 0.5) / tiers * h)
        for k in range(sides):
            k1 = (k + 1) % sides
            face(s, mat, [lo[k], lo[k1], hi[k1]], mid)
            face(s, mat, [lo[k], hi[k1], hi[k]], mid)
    top = rings[-1]
    tc = (sum(p[0] for p in top) / sides, max(p[1] for p in top) + (0.0 if flat_top else h * 0.04),
          sum(p[2] for p in top) / sides)
    below = (tc[0], tc[1] - 5.0, tc[2])
    for k in range(sides):
        face(s, top_mat or mat, [tc, top[k], top[(k + 1) % sides]], below)
    if collide:
        ch = min(h, collide_h or 60.0)
        inner = r * 0.72
        s.collider((x, y + ch / 2 - 0.5, z), (inner * 1.6, ch + 1.0, inner * 1.6 * squash), math.degrees(phase) % 90, True,
                   mat)
    return tc[1]


def spire(s, x, z, r, h, seed, y=0.0, collide=False):
    """A tall thin rock tower, leaning a little, split into more tiers."""
    rng = random.Random(seed)
    lean = (rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06))
    return rock(s, x, z, r, h, seed, tiers=5, sides=8, taper=0.8, lean=lean, collide=collide, y=y)


def mesa(s, x, z, r, h, seed, y=0.0, collide=True, top_mat="Ash"):
    """A flat-topped rock with steep sides, ash lying on its top."""
    return rock(s, x, z, r, h, seed, tiers=4, sides=14, taper=0.18, flat_top=True, collide=collide, y=y,
                top_mat=top_mat)


def boulder(s, x, z, r, seed, y=0.0, collide=True, mat="RockGrey"):
    """A low, rounded boulder."""
    rng = random.Random(seed)
    return rock(s, x, z, r, r * rng.uniform(0.8, 1.3), seed, tiers=2, sides=7, taper=0.55, collide=collide, y=y,
                squash=rng.uniform(0.7, 1.0), mat=mat)


# The ground ---------------------------------------------------------------------------------------


def ground(s, g):
    """The near ground in 32-stud cells (a hole cut for the rift), each a solid floor; crusts of
    cracked earth laid over the ash in patches; the far plain as plain faces."""
    step = 32.0
    holes = [P.RIFT]
    n = int(NEAR / step)
    for i in range(-n, n):
        for j in range(-n, n):
            cell = [(i * step, j * step), ((i + 1) * step, j * step), ((i + 1) * step, (j + 1) * step),
                    (i * step, (j + 1) * step)]
            mid = ((i + 0.5) * step, (j + 0.5) * step)
            inside = g2.contains(P.BASIN, mid) or any(g2.contains(P.BASIN, p) for p in cell)
            for piece in g2.subtract_all([cell], holes):
                g.add(piece, "Ash", 0.0, 0, "plaza" if inside else "offlimits")
                city.floor(s, piece, 0.0, 1.0, "Ash")
    # The rift: off limits from its guard in.
    s.zone("offlimits", P.RIFT_GUARD, 0.0)
    # Crusts of cracked earth (drawn just over the ash).
    rng = random.Random(404)
    for cx, cz, rr in ((-30.0, 70.0, 16.0), (70.0, -40.0, 20.0), (-110.0, -20.0, 18.0), (40.0, 80.0, 14.0),
                       (-60.0, -70.0, 12.0), (110.0, 110.0, 16.0), (-140.0, 60.0, 14.0), (20.0, -100.0, 13.0),
                       (130.0, -10.0, 10.0), (-20.0, 150.0, 12.0)):
        pts = []
        for k in range(12):
            a = 2 * math.pi * k / 12
            rk = rr * rng.uniform(0.75, 1.1)
            pts.append((cx + math.cos(a) * rk, cz + math.sin(a) * rk * rng.uniform(0.7, 1.0)))
        hull = g2.convex_hull(pts)
        for piece in g2.subtract_all([hull], [P.RIFT_GUARD]):
            city.up_face(s, "AshCracked", piece, 0.03)
    far_plain(s)


def far_plain(s):
    """The plain past the near ground, out to FAR: plain faces in 250-stud squares, a big thin
    collider under each strip so the greybox shows it too."""
    step = 250.0
    for i in range(-4, 4):
        for j in range(-4, 4):
            x0, z0 = i * step, j * step
            x1, z1 = x0 + step, z0 + step
            square = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
            near = [(-NEAR, -NEAR), (NEAR, -NEAR), (NEAR, NEAR), (-NEAR, NEAR)]
            for piece in g2.subtract(square, near):
                city.up_face(s, "Ash", piece, 0.0)
    for (cx, cz, w, d) in ((0.0, -(NEAR + FAR) / 2, 2 * FAR, FAR - NEAR), (0.0, (NEAR + FAR) / 2, 2 * FAR, FAR - NEAR),
                           (-(NEAR + FAR) / 2, 0.0, FAR - NEAR, 2 * NEAR), ((NEAR + FAR) / 2, 0.0, FAR - NEAR, 2 * NEAR)):
        # Split so no collider is wider than a Roblox part may be.
        pieces = max(1, math.ceil(max(w, d) / 1000.0))
        for k in range(pieces):
            if w >= d:
                s.collider((cx - w / 2 + w * (k + 0.5) / pieces, -0.5, cz), (w / pieces, 1.0, d), 0, False, "Ash")
            else:
                s.collider((cx, -0.5, cz - d / 2 + d * (k + 0.5) / pieces), (w, 1.0, d / pieces), 0, False, "Ash")


# The basin's edge -----------------------------------------------------------------------------------


def edge(s):
    """Rocks along the basin's edge, thick in some stretches and sparse in others, bone stakes and
    cairns across the gaps; and the invisible wall that follows the edge, up to 70."""
    rng = random.Random(77)
    pts = P.BASIN
    n = len(pts)
    for k in range(n):
        a, b = pts[k], pts[(k + 1) % n]
        length = math.dist(a, b)
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        rot = math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))
        s.collider((mid[0], 34.0, mid[1]), (length + 2.0, 72.0, 1.0), rot, False, None)
    # Dressing along the edge, just outside it: stretches of rock, stretches of stakes.
    for k in range(n):
        a, b = pts[k], pts[(k + 1) % n]
        length = math.dist(a, b)
        ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        ox, oz = uz, -ux  # outward (the basin runs counter-clockwise)
        kind = (k * 7 + 3) % 5
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        if P.in_bay(*mid):
            kind = 0  # the bay is walled with rock all along
        u = rng.uniform(1, 4)
        while u < length:
            px, pz = a[0] + ux * u, a[1] + uz * u
            if any(math.dist((px, pz), (x, z)) < r + 4.0 for x, z, r, _, _ in P.OUTCROPS):
                u += 3.0  # an outcrop stands here already
                continue
            if kind in (0, 1, 2):
                r = rng.uniform(3.5, 9.0)
                h = r * rng.uniform(0.8, 2.6)
                off = r * 0.55 + rng.uniform(0, 4)
                rock(s, px + ox * off, pz + oz * off, r, h, 1000 + k * 37 + int(u), tiers=3, collide=False,
                     sides=rng.choice((7, 8, 9)), taper=rng.uniform(0.35, 0.7))
                u += r * rng.uniform(1.1, 1.8)
            elif kind == 3:
                bone_stake(s, px + ox * 1.5, pz + oz * 1.5, rng.uniform(4.0, 7.5), rng)
                u += rng.uniform(2.6, 4.2)
            else:
                if rng.random() < 0.35:
                    s.prop("Cairn", px + ox * 2.5, pz + oz * 2.5, rng.uniform(0, 360), rng.uniform(0.9, 1.4))
                    u += rng.uniform(9, 14)
                else:
                    boulder(s, px + ox * 3.0, pz + oz * 3.0, rng.uniform(1.4, 3.2), 3000 + k * 13 + int(u), collide=False)
                    u += rng.uniform(4, 8)


def bone_stake(s, x, z, h, rng, mat="BoneOld"):
    """A long bone driven into the ash, leaning."""
    lean = (rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25))
    top = (x + lean[0] * h, h, z + lean[1] * h)
    s.tube(mat, (x, -0.3, z), top, 0.28, 7, radius_b=0.2)
    s.lathe(mat, top, [(0.0, -0.1), (0.42, 0.1), (0.36, 0.45), (0.0, 0.55)], 7)


# Outcrops, the throne's mesa and the plain beyond -------------------------------------------------------


def outcrops(s):
    for x, z, r, h, seed in P.OUTCROPS:
        rock(s, x, z, r, h, seed, tiers=4 if h > 15 else 3, taper=0.55 if h > 15 else 0.45, collide_h=70.0)
        rng = random.Random(seed)
        for k in range(rng.randint(2, 4)):
            a = rng.uniform(0, math.tau)
            d = r + rng.uniform(1.5, 4.0)
            boulder(s, x + math.cos(a) * d, z + math.sin(a) * d, rng.uniform(0.9, 2.2), seed * 10 + k)
    x, z, r, h = P.THRONE_MESA
    mesa(s, x, z, r, h, 91)
    # Steps of rock up its south face, broken off halfway (nobody climbs to the throne).
    for k in range(3):
        rock(s, x - 6 + k * 3, z + r + 2.5 - k * 1.2, 3.2, 2.5 + k * 3.0, 92 + k, tiers=2, sides=7, taper=0.3,
             flat_top=True)


def beyond(s):
    """The plain past the edge: dunes, rock spires and mesas, the ribs of colossal things, all
    fading into the haze."""
    rng = random.Random(9001)
    placed = []

    def free(x, z, r):
        if g2.contains(P.BASIN, (x, z)) or math.hypot(x, z) < 185 + r:
            return False
        return all(math.dist((x, z), (px, pz)) > r + pr + 6 for px, pz, pr in placed)

    # Dunes: long low mounds of ash.
    for k in range(70):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(200, 900)
        x, z = math.cos(a) * d, math.sin(a) * d
        rr = rng.uniform(25, 70)
        if not free(x, z, rr * 0.6):
            continue
        h = rr * rng.uniform(0.08, 0.18)
        s.lathe("Ash", (x, -0.4, z), [(rr, 0.0), (rr * 0.7, h * 0.45), (rr * 0.35, h * 0.9), (0.0, h)], 14,
                caps=(False, False))
        placed.append((x, z, rr * 0.6))
    # Spires and mesas.
    for k in range(64):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(200, 880)
        x, z = math.cos(a) * d, math.sin(a) * d
        big = d > 420
        if rng.random() < 0.3:
            r = rng.uniform(18, 46) * (1.4 if big else 1.0)
            if not free(x, z, r):
                continue
            mesa(s, x, z, r, rng.uniform(20, 60) * (1.5 if big else 1.0), 5000 + k, collide=False)
        else:
            r = rng.uniform(5, 14) * (1.5 if big else 1.0)
            if not free(x, z, r):
                continue
            spire(s, x, z, r, r * rng.uniform(4.0, 8.0), 6000 + k)
        placed.append((x, z, r))
    # The ribs of colossal skeletons, arching out of the plain.
    for k, (cx, cz, span, height, turn) in enumerate(((-330.0, -420.0, 90.0, 70.0, 30.0), (520.0, 160.0, 120.0, 95.0, -60.0),
                                                      (-560.0, 300.0, 100.0, 80.0, 75.0), (240.0, -620.0, 140.0, 120.0, 10.0))):
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
        # The spine along the top, sunk at both ends.
        for q in range(7):
            a0 = (cx + along[0] * (q - 0.5) * span * 0.18, height - 4 - q * 2.2, cz + along[1] * (q - 0.5) * span * 0.18)
            s.lathe("BoneOld", a0, [(0.0, -3.0), (4.2, -2.2), (4.6, 0.0), (4.2, 2.2), (0.0, 3.0)], 9, caps=(False, False))


def build(s, g):
    ground(s, g)
    edge(s)
    outcrops(s)
    beyond(s)
