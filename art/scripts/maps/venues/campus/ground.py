"""The campus ground under snow.

- The lawns lie under untrodden snow (footprints show there: their colliders' look is "Snow"). It is
  not one sheet: patches of an older, bluer snow and thin snow under the trees (the ground showing
  through) are cut into it, and the wind has piled low drifts against the walls and fences that face
  a lawn. The colliders under all of it keep the look "Snow".
- The paths are shovelled down to the wet pavers ("SnowPath"), flush with the lawns (nothing to
  step up onto), and low banks of shovelled snow line them (visual only: you wade through).
- The pond hollow is sunk five studs behind stone retaining walls, with a bamboo fence along its
  rim. Its three ways down are a slope from the avenue side, a stair from the north rim path
  and a slope from the south path. Down in it, a path of snow runs round the frozen pond, and
  an arched bridge crosses the pond's middle; the ice is fenced off by the stone lip round it.
- The forecourt's fountain is frozen.

Every piece of ground has a solid floor under it (city.floor) with the look it shows, and a zone
(park, lane, plaza, water)."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.venues.campus import fit
from maps.venues.campus import plan as P

Y = P.HOLLOW_Y
FLOOR_LOOK = {"auditorium": "Stone", "tower": "Stone", "law": "WoodFloorDark", "library": "WoodFloor",
              "club": "ConcreteDark", "cafeteria": "TileChecker", "science": "TileWhite", "booth": "ConcreteDark"}
PATH_NAMES = {"avenue": ("lane", "the ginkgo avenue"), "forecourt": ("plaza", "the forecourt"),
              "forecourt_s": ("plaza", "the forecourt"), "gate_plaza": ("plaza", "the gate"),
              "south": ("lane", None), "north_rim": ("lane", None)}


def rect(r):
    return P.rect_of(r)


def pieces_minus(poly, holes):
    return [p for p in g2.subtract_all([g2.ccw(q) for q in g2.convex_pieces(poly)], [g2.ccw(h) for h in holes])
            if abs(g2.area(p)) > 0.05]


def building_holes():
    return [rect(r) for r in P.BUILDINGS.values()] + [rect(P.ARCADE)]


# The level ground ------------------------------------------------------------------------------------------


def blob(cx, cz, r, rng, points=22, rough=0.22):
    """An organic outline round (cx, cz): a circle of radius r with soft bumps, counter-clockwise."""
    p1, p2, p3 = (rng.uniform(0, 2 * math.pi) for _ in range(3))
    out = []
    for k in range(points):
        a = 2 * math.pi * k / points
        wobble = 0.55 * math.sin(2 * a + p1) + 0.3 * math.sin(3 * a + p2) + 0.15 * math.sin(5 * a + p3)
        rr = r * (1 + rough * wobble)
        out.append((cx + rr * math.cos(a), cz + rr * math.sin(a)))
    return out


def patches(g, holes):
    """Patches of older snow over the lawns, and thin snow round every tree trunk that stands on one,
    cut into the lawn's snow (priority 2: the paths, 3, still cut them)."""
    rng = random.Random(23)
    for _ in range(46):
        cx, cz = rng.uniform(P.X0 + 10, P.X1 - 10), rng.uniform(P.Z0 + 10, P.Z1 - 10)
        for piece in pieces_minus(blob(cx, cz, rng.uniform(7.0, 16.0), rng), holes):
            g.add(piece, "Snow2", 0.0, 2, "park", None)
    trunks = [(x, z) for z in P.GINKGO_Z for x in P.GINKGO_X if not (x == P.GINKGO_X[0] and z > 56.0)]
    for x, z in trunks:
        for piece in pieces_minus(blob(x, z, rng.uniform(4.5, 6.0), rng, rough=0.3), holes):
            g.add(piece, "SnowThin", 0.0, 2, "park", None)


def drift(s, a, b, out):
    """A low drift of wind-blown snow along a wall's foot from a to b, on its side `out`: steeper
    against the wall, a long tail onto the lawn (look-only, like the banks)."""
    if math.dist(a, b) < 3.0:
        return
    profile = [(0.0, 0.0), (0.0, 0.7), (0.4, 0.78), (1.2, 0.62), (2.2, 0.32), (3.2, 0.08), (3.6, 0.0)]
    s.sweep("Snow", (a[0], 0.0, a[1]), (b[0], 0.0, b[1]), profile, (out[0], 0.0, out[1]), caps=True)


def _on_lawn(x, z, holes):
    if not (P.X0 + 1.5 < x < P.X1 - 1.5 and P.Z0 + 1.5 < z < P.Z1 - 1.5):
        return False
    return not any(g2.contains(h, (x, z)) for h in holes)


def drifts(s):
    """Drifts against every wall and fence face that stands on a lawn: the buildings' faces, the
    tennis court's fence and the campus wall's inner face, wherever 0.5 to 4 studs out is lawn."""
    holes = [rect(r) for r in P.BUILDINGS.values()] + [rect(P.ARCADE), rect(P.HOLLOW), rect(P.COURT)]
    holes += [rect(r) for r in P.PATHS.values()]
    faces = []
    for r in list(P.BUILDINGS.values()) + [P.COURT]:
        x0, z0, x1, z1 = r
        faces += [((x0, z0), (x1, z0), (0, -1)), ((x1, z1), (x0, z1), (0, 1)),
                  ((x0, z1), (x0, z0), (-1, 0)), ((x1, z0), (x1, z1), (1, 0))]
    faces += [((P.X0, P.Z0), (P.X1, P.Z0), (0, 1)), ((P.X1, P.Z1), (P.X0, P.Z1), (0, -1)),
              ((P.X0, P.Z1), (P.X0, P.Z0), (1, 0)), ((P.X1, P.Z0), (P.X1, P.Z1), (-1, 0))]
    for a, b, out in faces:
        length = math.dist(a, b)
        d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        start = None
        steps = int(length)
        for k in range(steps + 1):
            u = k * length / steps
            px, pz = a[0] + d[0] * u, a[1] + d[1] * u
            ok = all(_on_lawn(px + out[0] * w, pz + out[1] * w, holes) for w in (0.5, 2.0, 4.0))
            if ok and start is None:
                start = u
            if (not ok or k == steps) and start is not None:
                end = u if ok else u - 1.0
                if end - start >= 4.0:
                    p0 = (a[0] + d[0] * (start + 0.5), a[1] + d[1] * (start + 0.5))
                    p1 = (a[0] + d[0] * (end - 0.5), a[1] + d[1] * (end - 0.5))
                    drift(s, p0, p1, out)
                start = None


def level(s, g):
    buildings = building_holes()
    for name, r in P.PATHS.items():
        kind, label = PATH_NAMES.get(name, ("lane", None))
        for piece in pieces_minus(rect(r), buildings):
            g.add(piece, "SnowPath", 0.0, 3, kind, label)
            city.floor(s, piece, 0.0, 2.0, "SnowPath")
    lawn_holes = buildings + [rect(P.HOLLOW), rect(P.COURT)] + [rect(r) for r in P.PATHS.values()]
    for piece in pieces_minus(P.box(P.X0, P.Z0, P.X1, P.Z1), lawn_holes):
        g.add(piece, "Snow", 0.0, 1, "park", None)
        city.floor(s, piece, 0.0, 2.0, "Snow")
    patches(g, lawn_holes)
    # The tennis court: snowed over, fenced, look-only.
    g.add(rect(P.COURT), "Snow", 0.0, 2, "offlimits", "the tennis court")
    city.floor(s, rect(P.COURT), 0.0, 2.0, "Snow")
    # Under the buildings (their rooms draw their own floors) and the arcade.
    for name, r in P.BUILDINGS.items():
        city.floor(s, rect(r), 0.0, 2.0, FLOOR_LOOK[name])
    city.floor(s, rect(P.ARCADE), 0.0, 2.0, "Stone")


def bank(s, a, b, out, length_min=2.0):
    """A low bank of shovelled snow along a path's edge from a to b, on the side `out` (x, z)."""
    if math.dist(a, b) < length_min:
        return
    profile = [(0.0, 0.0), (0.35, 0.3), (0.8, 0.55), (1.3, 0.42), (1.8, 0.0)]
    s.sweep("Snow", (a[0], 0.0, a[1]), (b[0], 0.0, b[1]), profile, (out[0], 0.0, out[1]), caps=True)


def banks(s):
    """Banks along the paths where the snow was shovelled onto the lawns."""
    ax0, _, ax1, _ = P.AVENUE
    # The avenue's two sides, broken where paths join it and where the trees stand in them.
    for z0, z1 in ((-30.0, 2.0), (10.0, 44.0)):
        bank(s, (ax0, z0), (ax0, z1), (-1, 0))
    for z0, z1 in ((-30.0, 22.0), (34.0, 37.4), (56.4, 84.0)):
        bank(s, (ax1, z0), (ax1, z1), (1, 0))
    # The east cross path, both sides, and the forecourt's south strip.
    for x0, x1 in ((-8.0, 36.0), (48.0, 54.0), (62.0, 142.0)):
        bank(s, (x0, 34.0), (x1, 34.0), (0, 1))
    bank(s, (-8.0, 22.0), (66.0, 22.0), (0, -1))
    for x0, x1 in ((-52.0, -32.0), (-8.0, 26.0)):
        bank(s, (x0, -30.0), (x1, -30.0), (0, 1))
    # The west cross path and the gate plaza's edge.
    bank(s, (-52.0, 2.0), (-32.0, 2.0), (0, -1))
    bank(s, (-52.0, 10.0), (-32.0, 10.0), (0, 1))
    bank(s, (-8.0, 84.0), (36.0, 84.0), (0, -1))
    # Along the library's path, the side toward the court.
    bank(s, (26.0, -28.0), (62.0, -28.0), (0, 1))


# The hollow ------------------------------------------------------------------------------------------------


def _gap_spans(edge, ways):
    """The rim openings (u0, u1) along an edge (a, b) where the hollow's ways down start."""
    a, b = edge
    length = math.dist(a, b)
    d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    spans = []
    for _, top, _, width in ways:
        u = (top[0] - a[0]) * d[0] + (top[1] - a[1]) * d[1]
        off = abs((top[0] - a[0]) * d[1] - (top[1] - a[1]) * d[0])
        if off < 0.5 and 0 <= u <= length:
            spans.append((u - width / 2 - 0.4, u + width / 2 + 0.4))
    return sorted(spans)


def _runs(length, gaps):
    runs, cursor = [], 0.0
    for g0, g1 in gaps:
        if g0 - cursor > 0.2:
            runs.append((cursor, g0))
        cursor = max(cursor, g1)
    if length - cursor > 0.2:
        runs.append((cursor, length))
    return runs


def bamboo_fence(s, a, b, y=0.0, h=3.0):
    """A yotsume-gaki: bamboo posts and three rails along the rim, snow on the top rail; solid,
    with an invisible guard over it."""
    length = math.dist(a, b)
    d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    count = max(1, round(length / 2.4))
    for k in range(count + 1):
        p = (a[0] + d[0] * length * k / count, a[1] + d[1] * length * k / count)
        s.cylinder("Bamboo", (p[0], y, p[1]), 0.14, h, 6)
    for zz in (0.9, 1.9, h - 0.2):
        s.tube("Bamboo", (a[0], y + zz, a[1]), (b[0], y + zz, b[1]), 0.1, 6)
    s.tube("Snow", (a[0], y + h, a[1]), (b[0], y + h, b[1]), 0.12, 5)
    rot = g2.rot_of(d)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    s.collider((mid[0], y + h / 2, mid[1]), (length, h, 0.4), rot, False, None)
    s.collider((mid[0], y + h + fit.GUARD / 2, mid[1]), (length, fit.GUARD, 0.4), rot, False, None)


def hollow(s, g):
    x0, z0, x1, z1 = P.HOLLOW
    ways = P.HOLLOW_WAYS
    # The floor round the pond (snow; footprints show) and the ice.
    for piece in pieces_minus(rect(P.HOLLOW), [P.POND]):
        g.add(piece, "Snow", Y, 1, "park", "the pond hollow")
        city.floor(s, piece, Y, 2.0, "Snow")
    g.add(P.POND, "Ice", P.POND_Y, 2, "water", "the pond")
    city.floor(s, P.POND, P.POND_Y, 1.0, "Ice")
    # The retaining walls, facing in, with their coping on the rim and a fence along it.
    edges = [((x0, z0), (x1, z0), (0, 1)), ((x1, z0), (x1, z1), (-1, 0)), ((x1, z1), (x0, z1), (0, -1)),
             ((x0, z1), (x0, z0), (1, 0))]
    for a, b, inward in edges:
        length = math.dist(a, b)
        d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        rot = g2.rot_of(d)
        west = a[0] == x0 and b[0] == x0
        gaps = _gap_spans((a, b), ways)
        for u0, u1 in _runs(length, gaps):
            p = (a[0] + d[0] * u0, a[1] + d[1] * u0)
            q = (a[0] + d[0] * u1, a[1] + d[1] * u1)
            city.vquad(s, "Stone", p, q, Y, 0.0, inward)
            mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
            s.collider((mid[0] - inward[0] * 0.5, Y / 2, mid[1] - inward[1] * 0.5), (u1 - u0, -Y, 1.0), rot, True,
                       "Stone")
            if not west:
                s.box("Stone", (mid[0] - inward[0] * 0.3, 0.12, mid[1] - inward[1] * 0.3), (u1 - u0, 0.24, 1.0), rot,
                      skip=("-y",))
                bamboo_fence(s, (p[0] - inward[0] * 0.8, p[1] - inward[1] * 0.8),
                             (q[0] - inward[0] * 0.8, q[1] - inward[1] * 0.8))
    for kind, top, foot, width in ways:
        if kind == "stairs":
            fit.stairs(s, g, top, foot, 0.0, Y, width, "Stone", "Stone", step=0.8)
        else:
            city.slope(s, g, top, foot, 0.0, Y, width, mat="SnowPath", side_mat="Stone", name="the pond hollow",
                       zone="lane", sides=True)
            slope_rails(s, top, foot, 0.0, Y, width)
    pond_edge(s)
    bridge(s, g)


def slope_rails(s, a, b, y0, y1, width, h=3.2):
    """Iron rails down both sides of a slope, a post every few studs, with the invisible guard
    over them, stepped with the slope."""
    run = math.dist(a, b)
    d = ((b[0] - a[0]) / run, (b[1] - a[1]) / run)
    n = g2.normal_left(d)
    rot = g2.rot_of(d)
    count = max(2, round(run / 2.0))
    for side in (1, -1):
        off = width / 2 - 0.15
        p = (a[0] + n[0] * side * off, a[1] + n[1] * side * off)
        q = (b[0] + n[0] * side * off, b[1] + n[1] * side * off)
        s.tube("BlackMetal", (p[0], y0 + h, p[1]), (q[0], y1 + h, q[1]), 0.1, 8)
        s.tube("BlackMetal", (p[0], y0 + h * 0.45, p[1]), (q[0], y1 + h * 0.45, q[1]), 0.06, 6)
        for k in range(count + 1):
            t = k / count
            x, z = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t
            yy = y0 + (y1 - y0) * t
            s.tube("BlackMetal", (x, yy, z), (x, yy + h, z), 0.07, 6, caps=False)
        for k in range(count):
            t0, t1 = k / count, (k + 1) / count
            c = (p[0] + (q[0] - p[0]) * (t0 + t1) / 2, p[1] + (q[1] - p[1]) * (t0 + t1) / 2)
            top = max(y0 + (y1 - y0) * t0, y0 + (y1 - y0) * t1)
            s.collider((c[0], top + (h + fit.GUARD) / 2, c[1]), (run / count + 0.05, h + fit.GUARD, 0.4), rot, False,
                       None)


def pond_edge(s):
    """The stone lip round the ice, and the invisible fence over it (open only under the bridge,
    where the bridge's ramps stand)."""
    pts = P.POND
    bx0, bx1 = P.BRIDGE["x"] - P.BRIDGE["w"] / 2 - 0.4, P.BRIDGE["x"] + P.BRIDGE["w"] / 2 + 0.4
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        length = math.dist(a, b)
        d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        rot = g2.rot_of(d)
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        s.box("Stone", (mid[0], Y - 0.15, mid[1]), (length + 0.8, 0.9, 1.0), rot)
        s.box("Snow", (mid[0], Y + 0.35, mid[1]), (length + 0.6, 0.12, 0.8), rot, skip=("-y",))
        # The guard, cut where the bridge crosses this edge.
        cuts = []
        if min(a[0], b[0]) < bx1 and max(a[0], b[0]) > bx0 and abs(d[0]) > 0.3:
            u0 = (bx0 - a[0]) / d[0]
            u1 = (bx1 - a[0]) / d[0]
            cuts.append((min(u0, u1), max(u0, u1)))
        for u0, u1 in _runs(length, cuts):
            if u1 - u0 < 0.3:
                continue
            c = (a[0] + d[0] * (u0 + u1) / 2, a[1] + d[1] * (u0 + u1) / 2)
            s.collider((c[0], Y + 3.0, c[1]), (u1 - u0 + 0.4, 6.0, 0.6), rot, False, None)


def bridge(s, g):
    """A red arched bridge over the pond's middle: a ramp up from each bank to the flat deck,
    solid under the ramps, planks and a vermilion railing with brass caps, the guard over it."""
    b = P.BRIDGE
    x, w = b["x"], b["w"]
    top = Y + b["rise"]
    zn, zs = b["z0"], b["z1"]
    d0, d1 = zn + b["ramp"], zs - b["ramp"]
    s.ramp((x, zn), (x, d0), Y, top, w, look="WoodFloorDark")
    s.ramp((x, zs), (x, d1), Y, top, w, look="WoodFloorDark")
    city.floor(s, P.box(x - w / 2, d0, x + w / 2, d1), top, 0.6, "WoodFloorDark")
    city.up_face(s, "WoodFloorDark", P.box(x - w / 2, d0, x + w / 2, d1), top)
    for z_lo, z_hi in ((zn, d0), (zs, d1)):
        steps = 6
        for k in range(steps):
            t0, t1 = k / steps, (k + 1) / steps
            za = z_lo + (z_hi - z_lo) * t0
            zb = z_lo + (z_hi - z_lo) * t1
            ya, yb = Y + (top - Y) * t0, Y + (top - Y) * t1
            s.box("WoodFloorDark", (x, (ya + yb) / 2 - 0.1, (za + zb) / 2), (w, 0.3, abs(zb - za) + 0.05),
                  0, skip=("-y",))
            under = min(ya, yb) - 0.2 - Y
            if under > 0.3:
                s.collider((x, Y + under / 2, (za + zb) / 2), (w, under, abs(zb - za)), 0, False, None)
        s.box("Vermilion", (x, (Y + top) / 2 - 0.5, (z_lo + z_hi) / 2), (w + 0.4, top - Y - 0.8, abs(z_hi - z_lo) * 0.6),
              0)
    # Piers under the deck, standing on the ice.
    for zz in (d0 + 2.0, (d0 + d1) / 2, d1 - 2.0):
        for sx in (-1, 1):
            s.box("Vermilion", (x + sx * (w / 2 - 0.3), (P.POND_Y + top) / 2, zz), (0.5, top - P.POND_Y, 0.5), 0)
    # The railings: posts along both sides following the arch, a top rail, brass caps.
    profile = [(zn, Y), (d0, top), (d1, top), (zs, Y)]
    for sx in (-1, 1):
        rx = x + sx * (w / 2 + 0.1)
        for (za, ya), (zb, yb) in zip(profile, profile[1:]):
            s.tube("Vermilion", (rx, ya + 3.0, za), (rx, yb + 3.0, zb), 0.14, 6)
            s.tube("Snow", (rx, ya + 3.16, za), (rx, yb + 3.16, zb), 0.1, 5)
            count = max(1, round(abs(zb - za) / 2.2))
            for k in range(count + 1):
                t = k / count
                zz, yy = za + (zb - za) * t, ya + (yb - ya) * t
                s.box("Vermilion", (rx, yy + 1.5, zz), (0.3, 3.0, 0.3), 0)
            steps = max(1, round(abs(zb - za) / 2.0))
            for k in range(steps):
                t0, t1 = k / steps, (k + 1) / steps
                zc = za + (zb - za) * (t0 + t1) / 2
                yc = max(ya + (yb - ya) * t0, ya + (yb - ya) * t1)
                s.collider((rx, yc + (3.2 + fit.GUARD) / 2, zc), (0.4, 3.2 + fit.GUARD, abs(zb - za) / steps + 0.05),
                           0, False, None)
        for zz in (zn, zs):
            s.lathe("Brass", (rx, Y + 3.0, zz), [(0.0, 0.0), (0.2, 0.1), (0.24, 0.35), (0.0, 0.7)], 8)
    s.zone("lane", P.box(x - w / 2, zn, x + w / 2, zs), Y, top, name="the pond bridge")


# The forecourt's frozen fountain ---------------------------------------------------------------------------

FOUNTAIN = (8.0, -48.0, 6.5)  # centre x, z, basin radius


def fountain(s):
    x, z, r = FOUNTAIN
    s.lathe("Stone", (x, 0, z), [(r + 0.9, 0), (r + 0.9, 1.6), (r + 1.2, 1.8), (r + 1.2, 2.1), (r + 0.2, 2.1),
                                 (r, 1.8)], 32, caps=(False, False))
    s.polygon("Ice", [(x + math.cos(a) * r, 1.3, z + math.sin(a) * r)
                      for a in reversed([2 * math.pi * k / 32 for k in range(32)])])
    s.lathe("Snow", (x, 2.05, z), [(r + 1.15, 0.0), (r + 0.95, 0.14), (r + 0.3, 0.14), (r + 0.25, 0.0)], 32,
            caps=(False, False))
    s.lathe("Stone", (x, 1.2, z), [(1.6, 0), (1.4, 1.0), (0.7, 1.4), (0.55, 3.2), (1.0, 3.5), (2.6, 3.9), (2.8, 4.3),
                                   (2.2, 4.4), (0.5, 4.5), (0.4, 5.8), (0.7, 6.2), (0.15, 7.0)], 24)
    s.lathe("Snow", (x, 5.62, z), [(2.7, 0.0), (1.8, 0.35), (0.5, 0.45), (0.0, 0.45)], 24)
    # Icicles hanging off the upper bowl.
    for k in range(14):
        a = 2 * math.pi * k / 14
        px, pz = x + math.cos(a) * 2.6, z + math.sin(a) * 2.6
        s.lathe("Ice", (px, 4.2 - 0.9 - (k % 3) * 0.3, pz), [(0.0, 0.0), (0.12, 0.9 + (k % 3) * 0.3)], 5)
    s.collider((x, 1.05, z), (2 * r + 2.4, 2.1, 2 * r + 2.4), 0, True, "Stone")
    s.collider((x, 1.05, z), (2 * r + 2.4, 2.1, 2 * r + 2.4), 45, True, "Stone")
    s.collider((x, 3.5, z), (1.6, 7.0, 1.6), 0, True, "Stone")


def build(s, g):
    level(s, g)
    banks(s)
    drifts(s)
    hollow(s, g)
    fountain(s)
