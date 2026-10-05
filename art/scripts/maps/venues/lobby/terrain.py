"""The Grey Realm's ground and rock: the island's ash ground (a hole cut for the rift) with its sheer
cliffs, underside and hanging roots, crusts of cracked earth, the broken crown of rock along its rim
with the invisible wall behind it, and the shapes the whole realm is made of: twisted fluted columns,
needle spikes, rocks floating in the air, arches, walls of cloud and the colossal blade.

The distant world (floating rocks, spires, arches, cloud banks, the blade) is placed in
formations.py; the islets and bridges are in islets.py."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.mesher import cross, dot, ry, sub
from maps.venues.lobby import plan as P


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


# The realm's own shapes -----------------------------------------------------------------------------------


def column(s, x, z, r, h, seed, y=0.0, twist=1.3, sides=14, tiers=11, collide=True, mat="RockGrey", flat=False):
    """A fluted rock column, twisting as it rises: a flared foot, lumpy pinches, every other face
    cut back into a flute, the top broken off."""
    rng = random.Random(seed)
    phase = rng.uniform(0, math.tau)
    rings = []
    for t in range(tiers + 1):
        u = t / tiers
        prof = 1.0 + 0.55 * (1 - u) ** 3 + 0.13 * math.sin(u * 9.0 + seed) + 0.09 * math.sin(u * 21.0 + 2 * seed)
        rr = r * prof * (1 - 0.3 * u)
        yy = y - 0.5 if t == 0 else y + h * u
        ang0 = phase + twist * u * math.pi
        ring = []
        for k in range(sides):
            a = ang0 + math.tau * k / sides
            flute = 1.0 - (0.17 if k % 2 else 0.0)
            rk = rr * flute * (0.94 + 0.12 * rng.random())
            yk = yy - (rng.uniform(0, h * 0.05) if t == tiers and not flat else 0.0)
            ring.append((x + math.cos(a) * rk, yk, z + math.sin(a) * rk))
        rings.append(ring)
    for t in range(tiers):
        mid = (x, y + h * (t + 0.5) / tiers, z)
        for k in range(sides):
            k1 = (k + 1) % sides
            face(s, mat, [rings[t][k], rings[t][k1], rings[t + 1][k1]], mid)
            face(s, mat, [rings[t][k], rings[t + 1][k1], rings[t + 1][k]], mid)
    top = rings[-1]
    tc = (x, y + h + 0.3, z)
    for k in range(sides):
        face(s, mat, [tc, top[k], top[(k + 1) % sides]], (x, y + h - 6.0, z))
    if collide:
        ch = min(h, 70.0)
        s.collider((x, y + ch / 2 - 0.5, z), (r * 1.7, ch + 1.0, r * 1.7), math.degrees(phase) % 90, True, mat)


def needle(s, x, z, h, r, seed, y=0.0, lean=0.14, mat="RockGrey"):
    """A tall thin spike of rock, kinked and leaning, a stud or two sunk into the ground."""
    rng = random.Random(seed)
    a = rng.uniform(0, math.tau)
    bend = rng.uniform(-0.1, 0.1)
    mid = (x + math.cos(a) * lean * h * 0.5 + bend * h, y + h * 0.5, z + math.sin(a) * lean * h * 0.5 - bend * h)
    top = (x + math.cos(a) * lean * h, y + h, z + math.sin(a) * lean * h)
    s.tube(mat, (x, y - 1.0, z), mid, r, 5, caps=False, radius_b=r * 0.45)
    s.tube(mat, mid, top, r * 0.45, 5, caps=False, radius_b=0.03)


def needle_field(s, cx, cz, r, count, hmin, hmax, seed, y=0.0, avoid=(), arc=None):
    """Spikes of different heights scattered over a disc (or just an arc of it: (from, to) radians)."""
    rng = random.Random(seed)
    placed = []
    tries = 0
    while len(placed) < count and tries < count * 20:
        tries += 1
        a = rng.uniform(*arc) if arc else rng.uniform(0, math.tau)
        d = r * math.sqrt(rng.random())
        px, pz = cx + math.cos(a) * d, cz + math.sin(a) * d
        if any(math.dist((px, pz), (ax, az)) < ar for ax, az, ar in avoid):
            continue
        if any(math.dist((px, pz), (qx, qz)) < 1.8 for qx, qz in placed):
            continue
        h = rng.uniform(hmin, hmax) * (0.6 + 0.4 * (1 - d / r))
        needle(s, px, pz, h, rng.uniform(0.5, 1.1) * (0.6 + h / hmax * 0.6), seed * 100 + len(placed), y)
        placed.append((px, pz))
    return placed


def floating_rock(s, x, y, z, r, seed, depth=None, mat="RockGrey", top_mat=None, sides=9, spires=0, lean=0.0):
    """A rock hanging in the air: a rough flat top at y, a thick body narrowing to a point `depth`
    below; spires and a boulder or two standing on top."""
    rng = random.Random(seed)
    depth = depth or r * rng.uniform(1.2, 2.2)
    frac = [(0.0, 1.0), (0.1, 1.05), (0.32, 0.86), (0.58, 0.6), (0.82, 0.32)]
    phase = rng.uniform(0, math.tau)
    rings = []
    for u, f in frac:
        ring = []
        for k in range(sides):
            a = phase + math.tau * (k + rng.uniform(-0.18, 0.18)) / sides
            rk = r * f * (0.8 + 0.3 * rng.random())
            yk = y - depth * u + (rng.uniform(-0.04, 0.03) * r if u == 0.0 else rng.uniform(-0.06, 0.06) * depth)
            ring.append((x + math.cos(a) * rk + lean * depth * u, yk, z + math.sin(a) * rk))
        rings.append(ring)
    tip = (x + lean * depth, y - depth, z)
    for i in range(len(frac) - 1):
        mid = (x, y - depth * (frac[i][0] + frac[i + 1][0]) / 2, z)
        for k in range(sides):
            k1 = (k + 1) % sides
            face(s, mat, [rings[i][k], rings[i][k1], rings[i + 1][k1]], mid)
            face(s, mat, [rings[i][k], rings[i + 1][k1], rings[i + 1][k]], mid)
    for k in range(sides):
        face(s, mat, [tip, rings[-1][k], rings[-1][(k + 1) % sides]], (x, y - depth * 0.6, z))
    top = rings[0]
    tc = (x, y + r * 0.04, z)
    for k in range(sides):
        face(s, top_mat or mat, [tc, top[k], top[(k + 1) % sides]], (x, y - 5.0, z))
    for k in range(spires):
        a = rng.uniform(0, math.tau)
        d = r * rng.uniform(0.0, 0.55)
        sr = r * rng.uniform(0.07, 0.16)
        spire(s, x + math.cos(a) * d, z + math.sin(a) * d, sr, sr * rng.uniform(5.0, 11.0), seed * 10 + k, y=y + r * 0.02)
    return depth


def stalactite(s, x, z, y, r, length, seed, mat="RockGrey", sides=6):
    """A rock root hanging from y: wide at its top, narrowing to a point `length` below, leaning a little."""
    rng = random.Random(seed)
    lx, lz = rng.uniform(-0.18, 0.18) * length, rng.uniform(-0.18, 0.18) * length
    levels = [(0.0, 1.0), (0.3, 0.8), (0.65, 0.45)]
    phase = rng.uniform(0, math.tau)
    rings = []
    for u, f in levels:
        ring = []
        for k in range(sides):
            a = phase + math.tau * k / sides
            rk = r * f * (0.8 + 0.4 * rng.random())
            ring.append((x + lx * u + math.cos(a) * rk, y - length * u, z + lz * u + math.sin(a) * rk))
        rings.append(ring)
    tip = (x + lx, y - length, z + lz)
    for i in range(len(levels) - 1):
        mid = (x + lx * (levels[i][0] + levels[i + 1][0]) / 2, y - length * (levels[i][0] + levels[i + 1][0]) / 2,
               z + lz * (levels[i][0] + levels[i + 1][0]) / 2)
        for k in range(sides):
            k1 = (k + 1) % sides
            face(s, mat, [rings[i][k], rings[i][k1], rings[i + 1][k1]], mid)
            face(s, mat, [rings[i][k], rings[i + 1][k1], rings[i + 1][k]], mid)
    for k in range(sides):
        face(s, mat, [tip, rings[-1][k], rings[-1][(k + 1) % sides]], (x + lx * 0.7, y - length * 0.5, z + lz * 0.7))


def arch(s, x, y, z, span, height, thick, rot, seed, mat="RockGrey", sections=12, sides=8):
    """A rock arch: lumpy ring sections along a half ellipse, thick at its two feet and thin at the
    crown. Its feet stand `span` apart along the direction rot (the arch lies in that vertical plane)."""
    rng = random.Random(seed)
    turn = ry(rot)
    rings = []
    centres = []
    for i in range(sections + 1):
        a = math.pi * i / sections
        px, py = -math.cos(a) * span / 2, math.sin(a) * height
        tx, ty = math.sin(a) * span / 2, math.cos(a) * height
        tl = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / tl, tx / tl
        th = thick * (1.25 - 0.55 * math.sin(a)) * (0.9 + 0.2 * rng.random())
        depth = thick * (1.3 - 0.4 * math.sin(a)) * (0.9 + 0.2 * rng.random())
        ring = []
        for k in range(sides):
            ph = math.tau * k / sides
            c, sn = math.cos(ph) * th, math.sin(ph) * depth
            ring.append(turn((px + nx * c, py + ny * c, sn)))
        cx, cy, cz = turn((px, py, 0.0))
        rings.append([(x + p[0], y + p[1], z + p[2]) for p in ring])
        centres.append((x + cx, y + cy, z + cz))
    for i in range(sections):
        mid = tuple((a + b) / 2 for a, b in zip(centres[i], centres[i + 1]))
        for k in range(sides):
            k1 = (k + 1) % sides
            face(s, mat, [rings[i][k], rings[i][k1], rings[i + 1][k1]], mid)
            face(s, mat, [rings[i][k], rings[i + 1][k1], rings[i + 1][k]], mid)
    for end, c in ((0, centres[0]), (sections, centres[-1])):
        for k in range(sides):
            face(s, mat, [c, rings[end][k], rings[end][(k + 1) % sides]], (c[0], c[1] + height, c[2]) if end == 0 else
                 (c[0], c[1] + height, c[2]))


def cloud_bank(s, cx, cy, cz, length, width, seed, rot=0.0, puffs=8, mat="CloudBank", height=None):
    """A wall of cloud: a ragged row of squashed, overlapping puffs (their lowest bellies flat)."""
    rng = random.Random(seed)
    turn = ry(rot)
    height = height or width * 0.9
    for i in range(puffs):
        u = (i + 0.5) / puffs - 0.5
        px, pz = u * length + rng.uniform(-0.04, 0.04) * length, rng.uniform(-0.3, 0.3) * width
        r = width * rng.uniform(0.55, 1.0) * (1.0 - 0.5 * abs(u))
        py = rng.uniform(-0.15, 0.25) * height + (0.5 - abs(u)) * height * 0.4
        ox, oy, oz = turn((px, py, pz))
        s.lathe(mat, (cx + ox, cy + oy, cz + oz), [(0.0, -0.5 * r), (0.95 * r, -0.2 * r), (0.85 * r, 0.3 * r),
                                                    (0.4 * r, 0.62 * r), (0.0, 0.7 * r)], 9, caps=(False, False))


def horn(s, x, y, z, height, curl, rot, r0, mat="BoneWhite", segments=10):
    """A great curved tusk rising from (x, y, z), curling over in the direction rot (degrees)."""
    a = math.radians(rot)
    dx, dz = math.cos(a), math.sin(a)
    prev = (x, y - 1.0, z)
    for q in range(1, segments + 1):
        u = q / segments
        out = curl * (u * u * 0.8 + 0.2 * u)
        p = (x + dx * out, y + height * (u - 0.35 * u * u * u), z + dz * out)
        r = r0 * (1 - u * 0.92)
        s.tube(mat, prev, p, r, 8, caps=False, radius_b=r0 * (1 - (u + 1.0 / segments) * 0.92))
        prev = p


def blade(s, x, y, z, w, length, thick, rot=0.0, mat="RuinStone", glow="RelicGlow", guard=True):
    """A sword standing point-down in the ground at (x, y, z): its flat faces look along the
    direction rot, a fuller of cold light down each face, the crossguard, grip and pommel on top."""
    turn = ry(rot)

    def at(px, py, pz):
        o = turn((px, py, pz))
        return (x + o[0], y + py, z + o[2])

    profile = [(0.0, 0.0), (-0.5 * w, 0.16 * length), (-0.5 * w, length), (0.5 * w, length), (0.5 * w, 0.16 * length)]
    t2 = thick / 2
    for sign in (-1, 1):
        pts = [at(px, py, sign * t2) for px, py in profile]
        s.polygon(mat, pts if sign > 0 else list(reversed(pts)))
    n = len(profile)
    for i in range(n):
        (ax, ay), (bx, by) = profile[i], profile[(i + 1) % n]
        s.polygon(mat, [at(ax, ay, -t2), at(bx, by, -t2), at(bx, by, t2), at(ax, ay, t2)])
    if glow:
        for sign in (-1, 1):
            gw, g0, g1 = w * 0.13, length * 0.22, length * 0.97
            e = t2 + max(0.03, thick * 0.03)
            pts = [at(-gw, g0, sign * e), at(gw, g0, sign * e), at(gw, g1, sign * e), at(-gw, g1, sign * e)]
            s.polygon(glow, pts if sign < 0 else list(reversed(pts)))
    if guard:
        gy = length + w * 0.1
        s.box(mat, at(0, gy, 0), (w * 3.0, w * 0.22, thick * 1.7), rot)
        for sx in (-1, 1):
            s.box(mat, at(sx * w * 1.5, gy + w * 0.12, 0), (w * 0.22, w * 0.5, thick * 1.7), rot)
        s.box(mat, at(0, length + w * 0.65, 0), (w * 0.22, w * 1.0, thick * 0.9), rot)
        s.box(mat, at(0, length + w * 1.3, 0), (w * 0.5, w * 0.34, thick * 1.2), rot)


# The ground ---------------------------------------------------------------------------------------


def islet_poly(c, r, seed, n=22):
    rng = random.Random(seed)
    return [(c[0] + math.cos(math.tau * k / n) * r * (0.9 + 0.2 * rng.random()),
             c[1] + math.sin(math.tau * k / n) * r * (0.9 + 0.2 * rng.random())) for k in range(n)]


def ground(s, g):
    """The island's ground: the whole island polygon in convex pieces, a hole cut for the rift; crusts
    of cracked earth laid over the ash in patches."""
    for piece in g2.convex_pieces(P.BASIN):
        for part in g2.subtract_all([piece], [P.RIFT]):
            if abs(g2.area(part)) < 0.05:
                continue
            g.add(part, "Ash", 0.0, 0, "plaza")
            city.floor(s, part, 0.0, 1.0, "Ash")
    s.zone("offlimits", P.RIFT_GUARD, 0.0)
    rng = random.Random(404)
    for cx, cz, rr in ((-30.0, 70.0, 16.0), (70.0, -40.0, 20.0), (-110.0, -20.0, 18.0), (40.0, 80.0, 14.0),
                       (-60.0, -70.0, 12.0), (100.0, 100.0, 12.0), (-130.0, 50.0, 12.0), (20.0, -100.0, 13.0),
                       (130.0, -10.0, 8.0), (-20.0, 140.0, 10.0), (-90.0, 130.0, 10.0)):
        pts = []
        for k in range(12):
            a = 2 * math.pi * k / 12
            rk = rr * rng.uniform(0.75, 1.1)
            pts.append((cx + math.cos(a) * rk, cz + math.sin(a) * rk * rng.uniform(0.7, 1.0)))
        hull = g2.convex_hull(pts)
        if not all(g2.contains(P.BASIN, p) and g2.dist_to_poly_edge(P.BASIN, p) > 4.0 for p in hull):
            continue
        for piece in g2.subtract_all([hull], [P.RIFT_GUARD]):
            city.up_face(s, "AshCracked", piece, 0.03)


# Cliffs, undersides and the wall round an edge ---------------------------------------------------------

LEVELS = [(0.0, 1.0), (-7.0, 1.035), (-17.0, 0.99), (-30.0, 0.93)]


def cliff(s, poly, seed, plate, centre=(0.0, 0.0), mat="RockGrey", roots=0, hole=None, root_len=(14.0, 70.0)):
    """Sheer cliffs round poly (a star-shaped ring about `centre`): rings dropping to -plate, bulging
    and jagged, the last pulled in; a flat underside below them (cut round `hole`, a convex polygon the
    rift's walls land on), and `roots` rock roots hanging from it. Returns the bottom ring (x, z)."""
    rng = random.Random(seed)
    n = len(poly)
    levels = LEVELS + [(-plate, 0.82)]
    levels = [(y if y > -plate else -plate, f) for y, f in levels]
    rings = []
    for li, (y, f) in enumerate(levels):
        ring = []
        for k, (x, z) in enumerate(poly):
            dx, dz = x - centre[0], z - centre[1]
            r = math.hypot(dx, dz)
            ux, uz = dx / r, dz / r
            push = 0.0 if li == 0 else rng.uniform(-2.2, 3.0) + (3.5 if (k + li) % 5 == 0 else 0.0)
            rr = r * f + push
            drop = 0.0 if li == 0 else rng.uniform(-2.5, 2.5) if li < len(levels) - 1 else rng.uniform(-1.0, 1.0)
            ring.append((centre[0] + ux * rr, y + drop, centre[1] + uz * rr))
        rings.append(ring)
    for li in range(len(levels) - 1):
        a, b = rings[li], rings[li + 1]
        axis = (centre[0], (levels[li][0] + levels[li + 1][0]) / 2, centre[1])
        for k in range(n):
            k1 = (k + 1) % n
            face(s, mat, [a[k], a[k1], b[k1]], axis)
            face(s, mat, [a[k], b[k1], b[k]], axis)
    bottom = [(p[0], p[2]) for p in rings[-1]]
    for piece in g2.convex_pieces(bottom):
        for part in g2.subtract_all([piece], [hole] if hole else []):
            if abs(g2.area(part)) > 0.05:
                city.down_face(s, mat, part, -plate)
    for k in range(roots):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.8) * math.dist(bottom[0], centre)
        x, z = centre[0] + math.cos(a) * d, centre[1] + math.sin(a) * d
        if hole and (g2.contains(hole, (x, z)) or g2.dist_to_poly_edge(hole, (x, z)) < 14.0):
            continue
        if not g2.contains(bottom, (x, z)):
            continue
        stalactite(s, x, z, -plate + 0.5, rng.uniform(2.5, 8.0), rng.uniform(*root_len), seed * 10 + k)
    return bottom


def wall(s, poly, height, gaps=(), y=34.0, gap_w=P.BRIDGE_W + 1.0):
    """The invisible wall following poly (counter-clockwise), `height` tall; `gaps` are points (x, z)
    where a bridge leaves: the wall is left open there, gap_w wide."""
    n = len(poly)
    for k in range(n):
        a, b = poly[k], poly[(k + 1) % n]
        length = math.dist(a, b)
        if length < 0.1:
            continue
        ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        runs = [(0.0, length)]
        for hx, hz in gaps:
            t = (hx - a[0]) * ux + (hz - a[1]) * uz
            off = abs((hx - a[0]) * -uz + (hz - a[1]) * ux)
            if off < 9.0 and -gap_w < t < length + gap_w:
                nxt = []
                for lo, hi in runs:
                    if t - gap_w / 2 > lo:
                        nxt.append((lo, min(hi, t - gap_w / 2)))
                    if t + gap_w / 2 < hi:
                        nxt.append((max(lo, t + gap_w / 2), hi))
                runs = nxt
        for lo, hi in runs:
            if hi - lo < 0.2:
                continue
            m = (lo + hi) / 2
            mx, mz = a[0] + ux * m, a[1] + uz * m
            rot = math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))
            s.collider((mx, y, mz), (hi - lo + 2.0, height, 1.0), rot, False, None)


def edge(s):
    """The broken crown of rock along the island's rim (solid, so it is a wall you can see), here and
    there a bone stake or a cairn; the invisible wall behind it, open where the bridges leave."""
    rng = random.Random(77)
    pts = P.BASIN
    n = len(pts)
    wall(s, pts, 72.0, gaps=[P.BRIDGE_RUNE[0], P.BRIDGE_PARKOUR[0]])
    keep = [P.CLEFT, P.NEEDLE, P.BRIDGE_RUNE[0], P.BRIDGE_PARKOUR[0]]
    solids = []  # (x, z, r) of what stands solid along the rim already
    for k in range(n):
        a, b = pts[k], pts[(k + 1) % n]
        length = math.dist(a, b)
        ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        ox, oz = uz, -ux  # outward (the island runs counter-clockwise)
        kind = (k * 7 + 3) % 5
        u = rng.uniform(1, 4)
        while u < length:
            px, pz = a[0] + ux * u, a[1] + uz * u
            if any(math.dist((px, pz), (x, z)) < r + 4.0 for x, z, r, _, _ in P.OUTCROPS) or \
                    any(math.dist((px, pz), c) < 22.0 for c in keep):
                u += 3.0
                continue
            if kind in (0, 1, 2):
                r = rng.uniform(3.5, 8.0)
                h = r * rng.uniform(0.9, 3.0)
                off = -r * 0.35 + rng.uniform(-1.0, 2.0)  # a little inside the rim, the mass leaning over the drop
                rock(s, px + ox * off, pz + oz * off, r, h, 1000 + k * 37 + int(u), tiers=3,
                     sides=rng.choice((7, 8, 9)), taper=rng.uniform(0.35, 0.7), lean=(ox * 0.05, oz * 0.05))
                solids.append((px + ox * off, pz + oz * off, r))
                u += r * rng.uniform(1.2, 1.9)
            elif kind == 3:
                bone_stake(s, px - ox * 1.2, pz - oz * 1.2, rng.uniform(4.0, 7.5), rng)
                u += rng.uniform(2.6, 4.2)
            else:
                cx, cz = px - ox * 2.0, pz - oz * 2.0
                near = any(math.dist((cx, cz), (qx, qz)) < qr + 5.0 for qx, qz, qr in solids) or \
                    any(math.dist((cx, cz), (x, z)) < r + 6.0 for x, z, r, _, _ in P.OUTCROPS)
                if rng.random() < 0.35 and not near:
                    s.prop("Cairn", cx, cz, rng.uniform(0, 360), rng.uniform(0.9, 1.4))
                    solids.append((cx, cz, 2.4))
                    u += rng.uniform(9, 14)
                else:
                    br = rng.uniform(1.4, 3.2)
                    boulder(s, px - ox * 1.5, pz - oz * 1.5, br, 3000 + k * 13 + int(u))
                    solids.append((px - ox * 1.5, pz - oz * 1.5, br))
                    u += rng.uniform(4, 8)


def bone_stake(s, x, z, h, rng, mat="BoneOld"):
    """A long bone driven into the ash, leaning."""
    lean = (rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25))
    top = (x + lean[0] * h, h, z + lean[1] * h)
    s.tube(mat, (x, -0.3, z), top, 0.28, 7, radius_b=0.2)
    s.lathe(mat, top, [(0.0, -0.1), (0.42, 0.1), (0.36, 0.45), (0.0, 0.55)], 7)


# Outcrops and the throne's mesa -----------------------------------------------------------------------------


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


def build(s, g):
    ground(s, g)
    cliff(s, P.BASIN, 4242, P.PLATE, hole=P.grown(P.RIFT, 3.5), roots=46, root_len=(18.0, 90.0))
    edge(s)
    outcrops(s)
    # The twisted columns that frame the first view.
    for x, z, r, h, seed in P.COLUMNS:
        column(s, x, z, r, h, seed)
