"""The river: a concrete channel full of water across the south third. A promenade runs along
each bank at street level behind a railing, with an invisible wall over the railing so nobody
gets into the water; the avenue crosses on a road bridge and people on a footbridge further west.
Past the map the river runs on and disappears under the city through a culvert at each end."""

import math

from maps import city, kit
from maps import geo2d as g2
from maps.venues.tokyo import plan as P

NORTH_WALL = P.CHANNEL[1]  # offsets from the centre line, north positive
SOUTH_WALL = P.CHANNEL[0]
DECK = 1.4  # bridge deck thickness
BLOCK_TOP = 14.0  # how high the invisible wall over a railing reaches


def band(a, b, points=None):
    return g2.strip_quads(points or P.RIVER, max(a, b), min(a, b))


def inner_river():
    """The river's centre line between its culverts."""
    length = g2.polyline_length(P.RIVER)
    return g2.sub_polyline(P.RIVER, _u_at(P.RIVER_CULVERTS[0]), min(length, _u_at(P.RIVER_CULVERTS[1])))


def _u_at(x):
    u = 0.0
    for i in range(len(P.RIVER) - 1):
        a, b = P.RIVER[i], P.RIVER[i + 1]
        seg = math.dist(a, b)
        if a[0] <= x <= b[0]:
            return u + seg * (x - a[0]) / (b[0] - a[0])
        u += seg
    return u


def along(points, offset, fn):
    """Calls fn(a, b, direction, north) for every straight piece of the line at `offset`."""
    line = g2.offset_polyline(points, offset)
    for i in range(len(line) - 1):
        a, b = line[i], line[i + 1]
        length = math.dist(a, b)
        if length < 0.05:
            continue
        d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        fn(a, b, d, g2.normal_left(d))


def channel(s, g):
    river = inner_river()
    for q in band(P.PROM_N[1], P.PROM_N[0], river):
        g.add(q, "PaversWarm", 0.0, 2, "lane", "the north promenade")
    for q in band(P.PROM_S[1], P.PROM_S[0], river):
        g.add(q, "PaversWarm", 0.0, 2, "lane", "the south promenade")

    def wall_face(facing):
        def piece(a, b, d, n):
            city.vquad(s, "Concrete", a, b, P.BED_Y, 0.0, (n[0] * facing, n[1] * facing))
            # Drain outlets and weep holes low on the wall, just above the water.
            length = math.dist(a, b)
            for k in range(int(length // 14)):
                t = (k + 0.5) * 14 / length
                p = (a[0] + (b[0] - a[0]) * t + n[0] * facing * 0.05, a[1] + (b[1] - a[1]) * t + n[1] * facing * 0.05)
                s.box("ConcreteDark", (p[0], P.WATER_Y + 1.6, p[1]), (1.4, 1.4, 0.3), g2.rot_of(d))

        return piece

    along(river, NORTH_WALL, wall_face(-1))
    along(river, SOUTH_WALL, wall_face(1))

    def coping(side):
        def piece(a, b, d, n):
            mid = ((a[0] + b[0]) / 2 + n[0] * side * 0.4, (a[1] + b[1]) / 2 + n[1] * side * 0.4)
            s.box("Stone", (mid[0], 0.2, mid[1]), (math.dist(a, b) + 0.8, 0.4, 1.0), g2.rot_of(d), skip=("-y",))

        return piece

    along(river, NORTH_WALL, coping(1))
    along(river, SOUTH_WALL, coping(-1))
    for q in band(NORTH_WALL, SOUTH_WALL, river):
        city.up_face(s, "ConcreteDark", q, P.BED_Y)
        city.up_face(s, "Water", q, P.WATER_Y)
        s.zone("water", q, P.WATER_Y)
    for x in P.RIVER_CULVERTS:
        culvert(s, x)


def culvert(s, x):
    """Where the river goes under the city: a concrete headwall across the channel with a dark
    arched mouth, and the street carrying on over it."""
    (cx, cz), d = P.river_frame(x)
    n = g2.normal_left(d)
    inward = (-d[0], -d[1]) if x > 0 else d
    a = (cx + n[0] * NORTH_WALL, cz + n[1] * NORTH_WALL)
    b = (cx + n[0] * SOUTH_WALL, cz + n[1] * SOUTH_WALL)
    city.vquad(s, "ConcreteDark", a, b, P.BED_Y, 0.0, inward)
    # The mouth: a dark opening with a concrete arch ring standing proud of the wall.
    mid = ((a[0] + b[0]) / 2 + inward[0] * 0.1, (a[1] + b[1]) / 2 + inward[1] * 0.1)
    span = math.dist(a, b) - 4.0
    s.box("BlackTrim", (mid[0], P.WATER_Y + 2.0, mid[1]), (span, 4.0, 0.1), g2.rot_of(n))
    ring = (mid[0] + inward[0] * 0.4, mid[1] + inward[1] * 0.4)
    s.box("Concrete", (ring[0], P.WATER_Y + 4.4, ring[1]), (span + 1.6, 0.8, 0.8), g2.rot_of(n))
    for side in (-1, 1):
        p = (ring[0] + n[0] * side * (span / 2 + 0.4), ring[1] + n[1] * side * (span / 2 + 0.4))
        s.box("Concrete", (p[0], P.WATER_Y + 2.2, p[1]), (0.8, 4.4, 0.8), g2.rot_of(n))
    # The deck over it, so the ground carries on.
    deck = g2.rect(cx + inward[0] * -6, cz + inward[1] * -6, 12, math.dist(a, b) + 2, g2.rot_of(d))
    city.up_face(s, "Asphalt", deck, 0.02)


def blocker(s, a, b, base=3.4):
    """An invisible wall over a railing, up to BLOCK_TOP."""
    length = math.dist(a, b)
    if length < 0.2:
        return
    d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    s.collider((mid[0], (base + BLOCK_TOP) / 2, mid[1]), (length, BLOCK_TOP - base, 0.6), g2.rot_of(d), False, None)


def inside_map(p, margin=0.0):
    return P.X0 - margin <= p[0] <= P.X1 + margin


# Bridges -------------------------------------------------------------------------------------------


def road_bridge(s):
    """The avenue's deck over the channel: its underside, fascias, parapets; returns the railing
    gaps on both banks."""
    st = P.STREETS["ave_se"]
    half = st["road"] / 2 + st["walk"][0]
    channel = band(NORTH_WALL, SOUTH_WALL)
    for q in g2.strip_quads(st["points"], half, -half):
        for c in channel:
            piece = g2.intersect(q, c)
            if piece and abs(g2.area(piece)) > 0.5:
                city.down_face(s, "ConcreteDark", piece, -DECK)
                city.floor(s, piece, 0.0, DECK, look="Concrete")
    for side in (1, -1):
        edge = g2.offset_polyline(st["points"], half * side)
        hits = sorted([h for off in (NORTH_WALL, SOUTH_WALL) for h in g2.polyline_hits(edge, P.river_line(off))],
                      key=lambda h: h[1])
        if len(hits) < 2:
            continue
        a, b = hits[0], hits[-1]
        out = _outward(st["points"], a, side)
        city.vquad(s, "Concrete", a, b, -DECK, 0.0, out)
        parapet(s, a, b, out)
    gaps = {NORTH_WALL: [], SOUTH_WALL: []}
    for off in (NORTH_WALL, SOUTH_WALL):
        for h in g2.polyline_hits(st["points"], P.river_line(off)):
            gaps[off].append((h, 2 * half / _sin_between(st["points"], P.river_line(off), h) + 1.0))
    return gaps


def _outward(points, near, side):
    """The direction out of a street's side (side 1 left, -1 right) near a point."""
    best = min(range(len(points) - 1), key=lambda i: g2.dist_point_segment(near, points[i], points[i + 1]))
    a, b = points[best], points[best + 1]
    length = math.dist(a, b)
    n = g2.normal_left(((b[0] - a[0]) / length, (b[1] - a[1]) / length))
    return (n[0] * side, n[1] * side)


def _sin_between(p, q, near):
    def dir_at(points):
        best = min(range(len(points) - 1), key=lambda i: g2.dist_point_segment(near, points[i], points[i + 1]))
        a, b = points[best], points[best + 1]
        length = math.dist(a, b)
        return ((b[0] - a[0]) / length, (b[1] - a[1]) / length)

    a, b = dir_at(p), dir_at(q)
    return max(0.3, abs(a[0] * b[1] - a[1] * b[0]))


def parapet(s, a, b, out, h=1.4, mat="Concrete"):
    """A concrete parapet with a steel rail on posts along a bridge edge, blocked above."""
    length = math.dist(a, b)
    d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    mid = ((a[0] + b[0]) / 2 - out[0] * 0.4, (a[1] + b[1]) / 2 - out[1] * 0.4)
    s.box(mat, (mid[0], h / 2, mid[1]), (length, h, 0.8), g2.rot_of(d), skip=("-y",))
    s.box("Stone", (mid[0], h + 0.1, mid[1]), (length, 0.2, 1.0), g2.rot_of(d))
    s.box("DarkMetal", (mid[0], h + 1.3, mid[1]), (length, 0.25, 0.25), g2.rot_of(d))
    count = max(1, round(length / 3.0))
    for k in range(count + 1):
        p = (a[0] + d[0] * length * k / count - out[0] * 0.4, a[1] + d[1] * length * k / count - out[1] * 0.4)
        s.box("DarkMetal", (p[0], h + 0.7, p[1]), (0.2, 1.2, 0.2), g2.rot_of(d))
    s.collider((mid[0], 1.7, mid[1]), (length, 3.4, 0.9), g2.rot_of(d), True, None)
    blocker(s, (a[0] - out[0] * 0.4, a[1] - out[1] * 0.4), (b[0] - out[0] * 0.4, b[1] - out[1] * 0.4))


def footbridge(s, g):
    """A deck for people across the river, with glass balustrades under two steel arches."""
    (cx, cz), d = P.river_frame(P.FOOTBRIDGE_X)
    north = g2.normal_left(d)
    width = 6.0
    reach_n, reach_s = NORTH_WALL + 1.0, SOUTH_WALL - 1.0
    p_n = (cx + north[0] * reach_n, cz + north[1] * reach_n)
    p_s = (cx + north[0] * reach_s, cz + north[1] * reach_s)
    length = math.dist(p_n, p_s)
    mid = ((p_n[0] + p_s[0]) / 2, (p_n[1] + p_s[1]) / 2)
    rot = g2.rot_of(d)
    deck = g2.rect(mid[0], mid[1], width, length, rot)
    g.add(deck, "WoodFloor", 0.0, 5, "lane", "the footbridge")
    city.down_face(s, "DarkMetal", deck, -1.0)
    city.floor(s, deck, 0.0, 1.0, look="WoodFloor")
    for side in (1, -1):
        off = (d[0] * side * (width / 2), d[1] * side * (width / 2))
        a = (p_n[0] + off[0], p_n[1] + off[1])
        b = (p_s[0] + off[0], p_s[1] + off[1])
        city.vquad(s, "DarkMetal", a, b, -1.0, 0.0, (d[0] * side, d[1] * side))
        kit.railing(s, [a, b], h=3.4, mat="DarkMetal", glass="Glass")
        blocker(s, a, b)
        # The arch: a steel tube bowing up over the balustrade, with hangers.
        segs = 12
        pts = []
        for k in range(segs + 1):
            t = k / segs
            y = 3.4 + 5.0 * math.sin(math.pi * t)
            pts.append((a[0] + (b[0] - a[0]) * t, y, a[1] + (b[1] - a[1]) * t))
        for k in range(segs):
            s.tube("DarkMetal", pts[k], pts[k + 1], 0.35, 8)
            if 0 < k < segs:
                s.tube("DarkMetal", (pts[k][0], 3.4, pts[k][2]), pts[k], 0.08, 6, caps=False)
    return [(p_n, width + 0.6)], [(p_s, width + 0.6)]


def railings(s, gaps_n, gaps_s):
    river = inner_river()
    for offset, gaps in ((NORTH_WALL + 0.3, gaps_n), (SOUTH_WALL - 0.3, gaps_s)):
        line = g2.offset_polyline(river, offset)
        for raw in g2.split_polyline(line, gaps):
            piece = [raw[0]]
            for p in raw[1:]:
                if math.dist(p, piece[-1]) > 0.1:
                    piece.append(p)
            if len(piece) < 2 or g2.polyline_length(piece) < 1.0:
                continue
            kit.railing(s, piece, h=3.4, mat="BlackMetal")
            for i in range(len(piece) - 1):
                if inside_map(piece[i], 10) or inside_map(piece[i + 1], 10):
                    blocker(s, piece[i], piece[i + 1])


def build(s, g):
    channel(s, g)
    road = road_bridge(s)
    foot_n, foot_s = footbridge(s, g)
    railings(s, road[NORTH_WALL] + foot_n, road[SOUTH_WALL] + foot_s)
