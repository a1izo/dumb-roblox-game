"""The Grey Realm's ground and rock: the basin's ash ground (a hole cut for the rift) with crusts of cracked
earth, the endless plain that runs from the basin's ridge to the horizon, the ridge itself (a continuous crown
of rock, needle fields and spires, with the invisible wall behind it), the chasms under the causeways, and the
shapes the whole realm is made of: twisted fluted columns, needle spikes, rocks floating in the air, arches,
walls of cloud and the colossal blade.

The distant world (spires, mesas, columns, arches, cloud banks, the blade) is placed in formations.py; the
plateaus and causeways are in islets.py."""

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


# Plateau sides, the wall round an edge, the ridge, the plain and the chasms ----------------------------------


def toward(s, mat, pts, target):
    """A face whose front looks towards `target`."""
    n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    cz = sum(p[2] for p in pts) / len(pts)
    if dot(n, (target[0] - cx, target[1] - cy, target[2] - cz)) < 0:
        pts = list(reversed(pts))
    s.polygon(mat, pts)


def plateau_sides(s, poly, centre, seed, top, mat="RockGrey"):
    """The rock sides of a plateau standing `top` over the plain: rings flaring out from its top edge to the
    ground, jagged and bulging."""
    rng = random.Random(seed)
    n = len(poly)
    levels = [(top, 1.0), (top * 0.62, 1.05), (top * 0.25, 1.1), (-0.5, 1.17)]
    rings = []
    for li, (y, f) in enumerate(levels):
        ring = []
        for x, z in poly:
            dx, dz = x - centre[0], z - centre[1]
            r = math.hypot(dx, dz)
            push = 0.0 if li == 0 else rng.uniform(-1.2, 2.4)
            jit = rng.uniform(-0.7, 0.7) if 0 < li < 3 else 0.0
            rr = r * f + push
            ring.append((centre[0] + dx / r * rr, y + jit, centre[1] + dz / r * rr))
        rings.append(ring)
    for li in range(len(levels) - 1):
        a, b = rings[li], rings[li + 1]
        axis = (centre[0], (levels[li][0] + levels[li + 1][0]) / 2, centre[1])
        for k in range(n):
            k1 = (k + 1) % n
            face(s, mat, [a[k], a[k1], b[k1]], axis)
            face(s, mat, [a[k], b[k1], b[k]], axis)


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
    """The basin's border: a continuous ridge of big rock along the rim (solid, so you see it is a wall), needle
    fields and tall spires in and behind it, here and there a bone stake or a cairn, a second ridge of rock
    further out for depth; the invisible wall behind the first ridge, open where the causeways leave."""
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
        ox, oz = uz, -ux  # outward (the basin runs counter-clockwise)
        u = rng.uniform(0, 3)
        while u < length:
            px, pz = a[0] + ux * u, a[1] + uz * u
            if any(math.dist((px, pz), (x, z)) < r + 4.0 for x, z, r, _, _ in P.OUTCROPS) or \
                    any(math.dist((px, pz), c) < 22.0 for c in keep):
                u += 3.5
                continue
            r = rng.uniform(5.5, 10.5)
            h = r * rng.uniform(1.5, 3.4)
            off = rng.uniform(-r * 0.15, r * 0.45)
            rx, rz = px + ox * off, pz + oz * off
            rock(s, rx, rz, r, h, 1000 + k * 37 + int(u), tiers=rng.choice((3, 4)), sides=rng.choice((7, 8, 9)),
                 taper=rng.uniform(0.4, 0.75), lean=(ox * 0.05, oz * 0.05))
            solids.append((rx, rz, r))
            u += r * rng.uniform(0.95, 1.5)
        # Between the rocks of some stretches: needles, a bone stake, a cairn.
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        if not any(math.dist(mid, c) < 26.0 for c in keep):
            kind = (k * 7 + 3) % 5
            if kind in (0, 2):
                needle_field(s, mid[0] + ox * 5.0, mid[1] + oz * 5.0, 8.0, 7, 8.0, 24.0, 3100 + k)
            elif kind == 3:
                bone_stake(s, mid[0] - ox * 1.2, mid[1] - oz * 1.2, rng.uniform(4.0, 7.5), rng)
            elif kind == 4:
                cx, cz = mid[0] - ox * 2.0, mid[1] - oz * 2.0
                near = any(math.dist((cx, cz), (qx, qz)) < qr + 5.0 for qx, qz, qr in solids)
                near = near or any(math.dist((cx, cz), (x, z)) < r + 6.0 for x, z, r, _, _ in P.OUTCROPS)
                if not near:
                    s.prop("Cairn", cx, cz, rng.uniform(0, 360), rng.uniform(0.9, 1.4))
    # A second ridge behind the first and tall spires standing in it, out of reach: it gives the border depth.
    for k in range(n):
        a, b = pts[k], pts[(k + 1) % n]
        length = math.dist(a, b)
        ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        ox, oz = uz, -ux
        u = rng.uniform(0, 6)
        while u < length:
            px, pz = a[0] + ux * u, a[1] + uz * u
            if any(math.dist((px, pz), c) < 30.0 for c in keep):
                u += 6.0
                continue
            off = rng.uniform(13.0, 34.0)
            r = rng.uniform(7.0, 15.0)
            if rng.random() < 0.25:
                spire(s, px + ox * off, pz + oz * off, r * 0.55, r * rng.uniform(5.0, 8.5), 4100 + k * 11 + int(u))
            else:
                rock(s, px + ox * off, pz + oz * off, r, r * rng.uniform(1.2, 3.0), 4200 + k * 13 + int(u), tiers=3,
                     sides=7, taper=0.55, collide=False)
            u += r * rng.uniform(1.8, 2.9)


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


def far_plain(s):
    """The plain, from the basin's ridge to the horizon: ash faces in 250-stud squares (a hair under the basin's
    ground, so the two never fight), cut round the basin and the chasms; a thin big collider under each strip
    so the greybox has a horizon too (nothing reaches it: the wall is in between)."""
    step = 250.0
    n = int(P.FAR // step)
    holes = [piece for piece in g2.convex_pieces(P.BASIN)] + [P.chasm_poly(c) for c in P.CHASMS]
    for i in range(-n, n):
        for j in range(-n, n):
            x0, z0 = i * step, j * step
            pieces = [[(x0, z0), (x0 + step, z0), (x0 + step, z0 + step), (x0, z0 + step)]]
            pieces = g2.subtract_all(pieces, holes)
            for piece in pieces:
                if abs(g2.area(piece)) > 0.05:
                    city.up_face(s, "Ash", piece, -0.15)
    inner, outer = 195.0, P.FAR
    mid = (inner + outer) / 2
    for cx, cz, w, d in ((0.0, -mid, 2 * outer, outer - inner), (0.0, mid, 2 * outer, outer - inner),
                         (-mid, 0.0, outer - inner, 2 * inner), (mid, 0.0, outer - inner, 2 * inner)):
        pieces = max(1, math.ceil(max(w, d) / 1000.0))
        for k in range(pieces):
            if w >= d:
                s.collider((cx - w / 2 + w * (k + 0.5) / pieces, -0.5, cz), (w / pieces, 1.0, d), 0, False, "Ash")
            else:
                s.collider((cx, -0.5, cz - d / 2 + d * (k + 0.5) / pieces), (w, 1.0, d / pieces), 0, False, "Ash")


def chasm(s, c, seed):
    """A deep crack in the plain (cut out of far_plain): jagged rock walls dropping to a dark floor, a faint
    cold glow and mist down in it, boulders and needles along its lips. The causeway crosses it."""
    rng = random.Random(seed)
    cx, cz, along, across, rot = c
    corners = P.chasm_poly(c)
    outline = []
    for k in range(4):
        a, b = corners[k], corners[(k + 1) % 4]
        count = max(2, int(math.dist(a, b) / 9.0))
        for q in range(count):
            t = q / count
            outline.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    levels = [(0.0, 1.0), (-8.0, 1.0), (-20.0, 0.96), (-36.0, 0.9), (-54.0, 0.82), (-P.CHASM_DEPTH, 0.74)]
    rings = []
    for li, (y, f) in enumerate(levels):
        ring = []
        for x, z in outline:
            dx, dz = x - cx, z - cz
            push = 0.0 if li == 0 else rng.uniform(-2.0, 1.6)
            ring.append((cx + dx * f + (dx / (math.hypot(dx, dz) or 1.0)) * push, y, cz + dz * f + (dz / (math.hypot(dx, dz) or 1.0)) * push))
        rings.append(ring)
    n = len(outline)
    for li in range(len(levels) - 1):
        a, b = rings[li], rings[li + 1]
        axis = (cx, (levels[li][0] + levels[li + 1][0]) / 2, cz)
        for k in range(n):
            k1 = (k + 1) % n
            toward(s, "RockGrey", [a[k], a[k1], b[k1]], axis)
            toward(s, "RockGrey", [a[k], b[k1], b[k]], axis)
    bottom = [(p[0], p[2]) for p in rings[-1]]
    for piece in g2.convex_pieces(bottom):
        city.up_face(s, "Abyss", piece, -P.CHASM_DEPTH)
    s.emitter("mist", (cx, -P.CHASM_DEPTH + 10.0, cz), 0.0, size=(along, 6.0, across * 0.5))
    s.light("point", (cx, -34.0, cz), (150, 176, 214), 34, 0.5)
    # The lips: boulders and a few needles along the two long sides, outside the causeway's rails.
    t = math.radians(rot)
    ax, az = math.cos(t), -math.sin(t)  # along the causeway
    sx, sz = -az, ax  # across it
    for q in range(10):
        side = 1 if q % 2 else -1
        across_off = rng.uniform(9.0, across / 2)
        if q % 4 < 2:
            across_off = -across_off
        ex = cx + ax * side * (along / 2 + rng.uniform(1.0, 6.0)) + sx * across_off
        ez = cz + az * side * (along / 2 + rng.uniform(1.0, 6.0)) + sz * across_off
        boulder(s, ex, ez, rng.uniform(1.5, 4.0), seed * 10 + q, collide=False)
    for side in (-1, 1):
        needle_field(s, cx + sx * side * (across / 2 + 4.0), cz + sz * side * (across / 2 + 4.0), 7.0, 5, 8.0, 22.0,
                     seed * 7 + side)


def build(s, g):
    ground(s, g)
    far_plain(s)
    edge(s)
    outcrops(s)
    for k, c in enumerate(P.CHASMS):
        chasm(s, c, 801 + k)
    # The twisted columns that frame the first view.
    for x, z, r, h, seed in P.COLUMNS:
        column(s, x, z, r, h, seed)
