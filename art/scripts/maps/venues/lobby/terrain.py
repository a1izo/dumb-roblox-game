"""The Grey Realm's ground and rock: the basin's ash ground (a hole cut for the rift) with crusts of cracked
earth, the endless plain that runs from the basin's ridge to the horizon, the ridge itself (a continuous crown
of rock, needle fields and spires, with the invisible wall behind it), the chasms under the causeways, and the
shapes the whole realm is made of: twisted fluted columns, needle spikes, rocks floating in the air, arches,
walls of cloud and the colossal blade.

The distant world (spires, mesas, columns, arches, cloud banks, the blade) is placed in formations.py; the
plateaus and causeways are in islets.py."""

import math
import random

import realmrock
from maps import city
from maps import geo2d as g2
from maps.mesher import cross, dot, ry, sub
from maps.venues.lobby import ground as surface
from maps.venues.lobby import plan as P
from maps.venues.lobby import rocks


def face(s, mat, pts, inside):
    """A face whose front looks away from the point `inside`."""
    n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    cz = sum(p[2] for p in pts) / len(pts)
    if dot(n, (cx - inside[0], cy - inside[1], cz - inside[2])) < 0:
        pts = list(reversed(pts))
    s.polygon(mat, pts)


# The rock: every one is a shape of the realm's kit (realmrock.py), stood by rocks.py with colliders round its foot.
# These keep the measures the venue was laid out in (a rock about r across its foot and h tall) and pick the kit
# shape nearest those proportions, scaled between them and turned by the seed; past FAR_FROM the kit's lighter far
# variants stand in.
CRAGS = ("RealmCragA", "RealmCragB", "RealmCragC")
SPIRES = ("RealmSpireA",)
COLUMNS_KIT = ("RealmColumn", "RealmColumnB")
BOULDERS = ("RealmBoulderA", "RealmBoulderB")
NEEDLES = ("RealmNeedleA", "RealmNeedleB")
MESAS = ("RealmMesa",)
FAR_FROM = 300.0


def far(key, x, z, sc=1.0, lighter=False):
    """The kit's far variant of key for a rock standing at (x, z), when it has one and stands far enough out, is
    small enough (a few studs across) that the full one's corners would be wasted, or is asked to be lighter (out
    of reach behind something nearer)."""
    variant = key + "Far"
    small = _reach(key) * sc < 4.0
    return variant if variant in realmrock.KIT and (math.hypot(x, z) > FAR_FROM or small or lighter) else key


def _reach(key):
    sx, _, sz = realmrock.size(key)
    return max(sx, sz) / 2


def fit(keys, r, h, seed):
    """(kit shape, scale): of keys, one of the two whose height over width is nearest h / 2r (by seed), scaled so
    it is about r across its foot and h tall (between the two: one scale keeps its proportions)."""
    want = h / (2.0 * r)
    ranked = sorted(keys, key=lambda k: abs(math.log(realmrock.size(k)[1] / (2.0 * _reach(k)) / want)))
    pool = ranked[:2]
    key = pool[seed % len(pool)]
    return key, math.sqrt((r / _reach(key)) * (h / realmrock.size(key)[1]))


def top_of(key, sc):
    """How high over its ground a kit shape stands, scaled."""
    return (realmrock.size(key)[1] - realmrock.KIT[key].get("sink", 1.0)) * sc


def rock(s, x, z, r, h, seed, mat="RockGrey", y=0.0, tiers=3, sides=9, taper=0.5, lean=(0.0, 0.0), collide=True,
         flat_top=False, squash=1.0, turn=0.0, top_mat=None, collide_h=None, facing=None, lighter=False):
    """A rock about r across its foot and h tall, standing on ground at y: a crag of the kit (a boulder when small,
    a mesa or a slab when its top is flat, a spire when it is tall and thin). Its walls and core keep people out
    (collide; facing: walls only on the sides that look that way, up to collide_h). Returns its top's height. (The
    old faceted rock's other numbers are the kit's own now.)"""
    if flat_top:
        keys = ("RealmSlab",) if h < 1.4 else MESAS + ("RealmSlab",)
    elif r < 4.0 and h < 7.0:
        keys = BOULDERS
    elif h > r * 4.0:
        keys = SPIRES + CRAGS
    else:
        keys = CRAGS
    key, sc = fit(keys, r, h, seed)
    key = far(key, x, z, sc, lighter)
    rot = random.Random(seed).uniform(0, 360)
    rocks.rock(s, key, x, z, rot, sc, y, collide=collide, core_h=collide_h or 60.0, facing=facing)
    return y + top_of(key, sc)


def spire(s, x, z, r, h, seed, y=0.0, collide=False, lighter=False):
    """A tall thin tower of rock, worn to a point or snapped off."""
    return rock(s, x, z, r, h, seed, y=y, collide=collide, lighter=lighter)


def mesa(s, x, z, r, h, seed, y=0.0, collide=True, top_mat="RealmAsh"):
    """A flat-topped rock with steep layered sides, ash lying on its top."""
    return rock(s, x, z, r, h, seed, y=y, collide=collide, flat_top=True)


def boulder(s, x, z, r, seed, y=0.0, collide=True, mat="RockGrey"):
    """A low, rounded boulder."""
    rng = random.Random(seed)
    key, sc = fit(BOULDERS, r, r * rng.uniform(0.8, 1.3), seed)
    key = far(key, x, z, sc)
    rocks.rock(s, key, x, z, rng.uniform(0, 360), sc, y, collide=collide)
    return y + top_of(key, sc)


def column(s, x, z, r, h, seed, y=0.0, twist=1.3, sides=14, tiers=11, collide=True, mat="RockGrey", flat=False):
    """One of the realm's twisted fluted columns, its top broken off."""
    key, sc = fit(COLUMNS_KIT, r, h, seed)
    key = far(key, x, z, sc)
    rocks.rock(s, key, x, z, random.Random(seed).uniform(0, 360), sc, y, collide=collide, core_h=70.0)
    return y + top_of(key, sc)


def needle(s, x, z, h, r, seed, y=0.0, lean=0.14, mat="RockGrey"):
    """A tall thin spike of rock, kinked and leaning, a stud or two sunk into the ground."""
    key, sc = fit(NEEDLES, r, h, seed)
    rocks.rock(s, far(key, x, z, sc), x, z, random.Random(seed).uniform(0, 360), sc, y, collide=False)


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


FLOATERS = ("RealmFloaterA", "RealmFloaterB")


def floating_rock(s, x, y, z, r, seed, depth=None, mat="RockGrey", top_mat=None, sides=9, spires=0, lean=0.0):
    """A rock hanging in the air: its level top at y about r across (old flagstones on it with top_mat RuinFlag), its
    body narrowing to a point `depth` under it; spires standing on top. Returns its depth."""
    rng = random.Random(seed)
    depth = depth or r * rng.uniform(1.2, 2.2)
    key = FLOATERS[seed % 2]
    sc = r / _reach(key)
    rc = realmrock.KIT[key]
    rim = (realmrock.size(key)[1] - rc.get("rise", 0.15)) * sc
    s.prop(key, x, z, rng.uniform(0, 360), round(sc, 3), y - rim)
    for k in range(spires):
        a = rng.uniform(0, math.tau)
        d = r * rng.uniform(0.0, 0.5)
        sr = r * rng.uniform(0.07, 0.16)
        spire(s, x + math.cos(a) * d, z + math.sin(a) * d, sr, sr * rng.uniform(5.0, 11.0), seed * 10 + k, y=y)
    return realmrock.size(key)[1] * sc


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
    # Solid as drawn where a body meets it (2026-11-07): each section low enough to reach, a block over its two rings
    # in the arch's own frame (along its span, across its thickness), from the ground or the section's foot to its top.
    a = math.radians(rot)
    ux, uz = math.cos(a), -math.sin(a)  # (the span's direction, as ry(rot) turns +x)
    vx, vz = math.sin(a), math.cos(a)
    for i in range(sections):
        pts = rings[i] + rings[i + 1]
        low = min(q[1] for q in pts)
        if low > y + 12.0:
            continue
        us = [(q[0] - x) * ux + (q[2] - z) * uz for q in pts]
        vs = [(q[0] - x) * vx + (q[2] - z) * vz for q in pts]
        top = min(max(q[1] for q in pts), y + 14.0)
        bottom = max(y - 0.5, low - 0.2) if low > y + 1.0 else y - 0.5
        cu, cv = (min(us) + max(us)) / 2, (min(vs) + max(vs)) / 2
        s.collider((x + ux * cu + vx * cv, (top + bottom) / 2, z + uz * cu + vz * cv),
                   (max(us) - min(us), top - bottom, max(vs) - min(vs)), rot, True, mat)


def cloud_bank(s, cx, cy, cz, length, width, seed, rot=0.0, puffs=8, mat="CloudBank", height=None):
    """A wall of cloud: a ragged row of soft, overlapping heaps, broad and flat-bellied, smaller ones riding on the
    bigger, shaded smooth (each heap one smooth piece)."""
    rng = random.Random(seed)
    turn = ry(rot)
    height = height or width * 0.75
    for i in range(puffs):
        u = (i + 0.5) / puffs - 0.5
        px, pz = u * length + rng.uniform(-0.04, 0.04) * length, rng.uniform(-0.3, 0.3) * width
        r = width * rng.uniform(0.55, 1.0) * (1.0 - 0.5 * abs(u))
        py = rng.uniform(-0.15, 0.2) * height + (0.5 - abs(u)) * height * 0.35
        for k, (dx, dy, dr) in enumerate(((0.0, 0.0, 1.0), (rng.uniform(-0.4, 0.4), 0.42, 0.62))):
            if k and rng.random() < 0.5:
                continue
            rr = r * dr
            ox, oy, oz = turn((px + dx * r, py + dy * r, pz))
            # (a heap: flat underneath, swelling out, rounded over the top; squashed to lie long and low)
            profile = [(0.0, -0.32 * rr), (0.8 * rr, -0.26 * rr), (1.0 * rr, 0.0), (0.84 * rr, 0.28 * rr),
                       (0.46 * rr, 0.5 * rr), (0.0, 0.56 * rr)]
            with s.smooth():
                s.lathe(mat, (cx + ox, cy + oy, cz + oz), profile, 10, caps=(False, False))


def horn(s, x, y, z, height, curl, rot, r0, mat="BoneWhite", segments=10):
    """A great curved tusk rising from (x, y, z), curling over in the direction rot (degrees)."""
    a = math.radians(rot)
    dx, dz = math.cos(a), math.sin(a)
    points, radii = [(x, y - 1.0, z)], [r0]
    for q in range(1, segments + 1):
        u = q / segments
        out = curl * (u * u * 0.8 + 0.2 * u)
        points.append((x + dx * out, y + height * (u - 0.35 * u * u * u), z + dz * out))
        radii.append(r0 * (1 - u * 0.92))
    with s.smooth():
        s.bent_tube(mat, points, radii, 8, caps=(False, True))  # (its root sunk)


def blade(s, x, y, z, w, length, thick, rot=0.0, mat="RuinStone", glow="RelicGlow", guard=True):
    """A sword standing point-down in the ground at (x, y, z): its flat faces look along the
    direction rot, a fuller of cold light down each face, the crossguard, grip and pommel on top."""
    turn = ry(rot)

    def at(px, py, pz):
        o = turn((px, py, pz))
        return (x + o[0], y + py, z + o[2])

    profile = [(0.0, 0.0), (-0.5 * w, 0.16 * length), (-0.5 * w, length), (0.5 * w, length), (0.5 * w, 0.16 * length)]
    t2 = thick / 2
    middle = at(0.0, length * 0.6, 0.0)
    for sign in (-1, 1):
        face(s, mat, [at(px, py, sign * t2) for px, py in profile], at(0.0, length * 0.6, -sign * t2))
    n = len(profile)
    for i in range(n):
        (ax, ay), (bx, by) = profile[i], profile[(i + 1) % n]
        face(s, mat, [at(ax, ay, -t2), at(bx, by, -t2), at(bx, by, t2), at(ax, ay, t2)], middle)
    if glow:
        for sign in (-1, 1):
            gw, g0, g1 = w * 0.13, length * 0.22, length * 0.97
            e = t2 + max(0.03, thick * 0.03)
            face(s, glow, [at(-gw, g0, sign * e), at(gw, g0, sign * e), at(gw, g1, sign * e), at(-gw, g1, sign * e)],
                 at(0.0, (g0 + g1) / 2, 0.0))
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
    """The island's ground as people walk it: the whole island polygon in convex pieces, a hole cut for the rift, a
    flat floor under each (what is seen is ground.py's: the ash with its swells, ripples, banks and crusts), and the
    stones lying in the ash."""
    bowl = P.circle(P.BOWL_C, P.BOWL_R, 32)
    for piece in g2.convex_pieces(P.BASIN):
        for part in g2.subtract_all([piece], [P.RIFT, bowl]):
            if abs(g2.area(part)) < 0.05:
                continue
            s.zone("plaza", part, 0.0)
            city.floor(s, part, 0.0, 1.0, "RealmAsh")
    s.zone("offlimits", P.RIFT_GUARD, 0.0)
    relief(s)


def relief(s):
    """Stones in the ash (2026-10-25, asked: "improve the lobby terrain (make it more interesting not just flat)"; the
    ground's own swells, ripples and drifts are ground.py's now), all clear of everything standing on it and of the
    rift, and none of it in the way: low slabs of rock breaking through it (a step up at most), and pebbles and
    stones strewn about."""
    rng = random.Random(9090)
    solid = list(P.footprints().values())
    xs = [p[0] for p in P.BASIN]
    zs = [p[1] for p in P.BASIN]

    def clear(x, z, pad, edge=3.0):
        if not g2.contains(P.BASIN, (x, z)) or g2.dist_to_poly_edge(P.BASIN, (x, z)) < edge:
            return False
        if g2.contains(P.RIFT_GUARD, (x, z)) or g2.dist_to_poly_edge(P.RIFT_GUARD, (x, z)) < pad:
            return False
        for poly in solid:
            if g2.contains(poly, (x, z)) or g2.dist_to_poly_edge(poly, (x, z)) < pad:
                return False
        return True

    def spot(pad, edge=3.0, tries=60):
        for _ in range(tries):
            x, z = rng.uniform(min(xs), max(xs)), rng.uniform(min(zs), max(zs))
            if clear(x, z, pad, edge):
                return x, z
        return None

    # Slabs: flat stones breaking through the ash, low enough to walk over.
    for k in range(30):
        r = rng.uniform(1.1, 2.4)
        at = spot(r + 1.0)
        if not at:
            continue
        h = rng.uniform(0.18, 0.4)
        rock(s, at[0], at[1], r, h + 0.5, 6100 + k, mat=rng.choice(("RockGrey", "RuinStone")), y=-0.5, tiers=1,
             sides=rng.choice((5, 6, 7)), taper=0.12, flat_top=True, collide=True, collide_h=h + 0.5,
             squash=rng.uniform(0.55, 1.0), turn=rng.uniform(0, 1))
    # Stones and pebbles strewn about (too small to stand on).
    for k in range(40):
        r = rng.uniform(0.25, 0.6)
        at = spot(r + 0.6)
        if at:
            boulder(s, at[0], at[1], r, 6300 + k, collide=False)


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
    with s.smooth():  # (one surface of rock round the plateau, its ledges kept)
        for li in range(len(levels) - 1):
            a, b = rings[li], rings[li + 1]
            axis = (centre[0], (levels[li][0] + levels[li + 1][0]) / 2, centre[1])
            for k in range(n):
                k1 = (k + 1) % n
                face(s, mat, [a[k], a[k1], b[k1]], axis)
                face(s, mat, [a[k], b[k1], b[k]], axis)


def wall(s, poly, height, gaps=(), y=34.0, gap_w=P.BRIDGE_W + 1.0, reach=9.0):
    """The invisible wall following poly (counter-clockwise), `height` tall; `gaps` are points (x, z)
    where a bridge leaves: the wall is left open there, gap_w wide, on every side within `reach` of the point."""
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
            if off < reach and -gap_w < t < length + gap_w:
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
    """The basin's border (2026-11-04, to the reference videos): billowing cliffs heaped along the south and west, where
    the spawn and the grotto back onto them, and pale shards with broken crags along the north and east, standing
    against the glow; a second rank further out, out of reach, for depth. The invisible wall runs behind the first
    rank, open where the causeways leave."""
    rng = random.Random(77)
    pts = P.BASIN
    n = len(pts)
    wall(s, pts, 72.0, gaps=[P.BRIDGE_SHARDS[0], P.BRIDGE_PARKOUR[0]])
    keep = [P.BRIDGE_SHARDS[0], P.BRIDGE_PARKOUR[0]]
    taken = [(c[0], c[1], r) for c, r in ((P.ACADEMY_C, P.GROTTO_WALL + 14.0), (P.LEDGE[:2], 46.0))]

    def kind_at(x, z):
        deg = math.degrees(math.atan2(z, x)) % 360.0
        return "billow" if 25.0 < deg < 215.0 else "shard"

    for k in range(n):
        a, b = pts[k], pts[(k + 1) % n]
        length = math.dist(a, b)
        ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        ox, oz = uz, -ux  # outward (the basin runs counter-clockwise)
        u = rng.uniform(0, 4)
        while u < length:
            px, pz = a[0] + ux * u, a[1] + uz * u
            if any(math.dist((px, pz), c) < 20.0 for c in keep) or                     any(math.dist((px, pz), (x, z)) < r for x, z, r in taken):
                u += 4.0
                continue
            if kind_at(px, pz) == "billow":
                key = rng.choice(("RealmBillowA", "RealmBillowB", "RealmBillowC", "RealmBillowA"))
                sc = rng.uniform(0.75, 1.15)
            else:
                key = rng.choice(("RealmShardsA", "RealmCragA", "RealmCragB", "RealmCragC", "RealmBillowC",
                                  "RealmShardsB", "RealmCragA"))
                sc = rng.uniform(0.7, 1.1) if key != "RealmShardsB" else rng.uniform(0.45, 0.65)
            off = rng.uniform(1.0, 7.0)
            rx, rz = px + ox * off, pz + oz * off
            rocks.rock(s, key, rx, rz, rng.uniform(0, 360), sc, facing=(-ox, -oz))
            u += max(7.0, rocks.radius(key, sc) * rng.uniform(0.9, 1.3))
    # A second rank behind the first, out of reach: it gives the border depth.
    for k in range(n):
        a, b = pts[k], pts[(k + 1) % n]
        length = math.dist(a, b)
        ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        ox, oz = uz, -ux
        u = rng.uniform(0, 8)
        while u < length:
            px, pz = a[0] + ux * u, a[1] + uz * u
            if any(math.dist((px, pz), c) < 30.0 for c in keep):
                u += 8.0
                continue
            off = rng.uniform(16.0, 40.0)
            if kind_at(px, pz) == "billow":
                key, sc = rng.choice(("RealmBillowB", "RealmBillowA")), rng.uniform(0.9, 1.5)
            else:
                key, sc = rng.choice(("RealmShardsB", "RealmShardsA", "RealmSpireA")), rng.uniform(0.6, 1.1)
            rocks.rock(s, key + ("Far" if key + "Far" in realmrock.KIT else ""), px + ox * off, pz + oz * off,
                       rng.uniform(0, 360), sc, collide=False)
            u += rocks.radius(key, sc) * rng.uniform(1.4, 2.4)


def far_plain(s):
    """The plain, from the basin's ridge to the horizon: ash faces in 250-stud squares (a hair under the basin's
    ground, so the two never fight), cut round the basin and the chasms; a thin big collider under each strip
    so the greybox has a horizon too (nothing reaches it: the wall is in between)."""
    step = 250.0
    n = int(P.FAR // step)
    # (inside the relief's square the ground is ground.py's: the plain's faces start at its edge)
    reach = surface.REACH
    holes = [[(-reach, -reach), (reach, -reach), (reach, reach), (-reach, reach)]]
    for i in range(-n, n):
        for j in range(-n, n):
            x0, z0 = i * step, j * step
            pieces = [[(x0, z0), (x0 + step, z0), (x0 + step, z0 + step), (x0, z0 + step)]]
            pieces = g2.subtract_all(pieces, holes)
            for piece in pieces:
                if abs(g2.area(piece)) > 0.05:
                    city.up_face(s, "RealmAsh", piece, -0.15)
    inner, outer = 195.0, P.FAR
    mid = (inner + outer) / 2
    # (Never over a chasm: the strips are cut round each chasm's box, so no unseen floor hangs over a hole.)
    holes = []
    for c in P.CHASMS:
        xs = [p[0] for p in P.chasm_poly(c)]
        zs = [p[1] for p in P.chasm_poly(c)]
        holes.append((min(xs) - 1.0, min(zs) - 1.0, max(xs) + 1.0, max(zs) + 1.0))
    for cx, cz, w, d in ((0.0, -mid, 2 * outer, outer - inner), (0.0, mid, 2 * outer, outer - inner),
                         (-mid, 0.0, outer - inner, 2 * inner), (mid, 0.0, outer - inner, 2 * inner)):
        rects = [(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2)]
        for hole in holes:
            rects = [piece for r in rects for piece in rect_minus(r, hole)]
        for x0, z0, x1, z1 in rects:
            w2, d2 = x1 - x0, z1 - z0
            pieces = max(1, math.ceil(max(w2, d2) / 1000.0))
            for k in range(pieces):
                if w2 >= d2:
                    s.collider((x0 + w2 * (k + 0.5) / pieces, -0.5, (z0 + z1) / 2), (w2 / pieces, 1.0, d2), 0, False, "RealmAsh")
                else:
                    s.collider(((x0 + x1) / 2, -0.5, z0 + d2 * (k + 0.5) / pieces), (w2, 1.0, d2 / pieces), 0, False, "RealmAsh")


def rect_minus(r, h):
    """An axis-aligned rectangle (x0, z0, x1, z1) less another: up to four rectangles."""
    x0, z0, x1, z1 = r
    hx0, hz0, hx1, hz1 = max(h[0], x0), max(h[1], z0), min(h[2], x1), min(h[3], z1)
    if hx0 >= hx1 or hz0 >= hz1:
        return [r]
    out = [(x0, z0, x1, hz0), (x0, hz1, x1, z1), (x0, hz0, hx0, hz1), (hx1, hz0, x1, hz1)]
    return [p for p in out if p[2] - p[0] > 0.05 and p[3] - p[1] > 0.05]


def chasm(s, c, seed):
    """A deep rift in the plain (cut out of far_plain; its rim P.chasm_outline, jagged, narrowing to cracks at its
    ends: 2026-10-27, it was a rectangle): rock walls dropping in broken ledges to a dark floor, a faint cold glow
    and mist down in it, boulders and needles along its lips. The causeway crosses it, walled both sides."""
    rng = random.Random(seed)
    cx, cz, along, across, rot = c
    outline = P.chasm_outline(c)
    # (each level: its depth and how far in its wall stands; a short steep drop set well in is a ledge the rock
    # breaks back on, never quite flat, so its faces always look up out of the rift)
    levels = [(0.0, 1.0), (-6.0, 0.96), (-8.5, 0.87), (-24.0, 0.82), (-27.0, 0.73), (-48.0, 0.67), (-P.CHASM_DEPTH, 0.6)]
    rings = []
    for li, (y, f) in enumerate(levels):
        ring = []
        for x, z in outline:
            dx, dz = x - cx, z - cz
            push = 0.0 if li == 0 else rng.uniform(-1.6, 1.2)
            ring.append((cx + dx * f + (dx / (math.hypot(dx, dz) or 1.0)) * push, y, cz + dz * f + (dz / (math.hypot(dx, dz) or 1.0)) * push))
        rings.append(ring)
    n = len(outline)
    with s.smooth():  # (the chasm's walls one surface of rock, its ledges kept)
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
    for q in range(7):
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
    for k, c in enumerate(P.CHASMS):
        chasm(s, c, 801 + k)
