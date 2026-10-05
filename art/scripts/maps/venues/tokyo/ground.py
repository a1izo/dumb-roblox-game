"""Tokyo's ground at street level: roads, sidewalks, the plazas, the covered shopping street,
the alleys and lanes, the scramble with its zebras, road markings, and the solid floor under it
all (everything but the river channel)."""

import math

from maps import city
from maps.buildings import grow
from maps import geo2d as g2
from maps.venues.tokyo import plan as P

SURFACES = {
    # kind: (material, Ground priority, zone)
    "road": ("AsphaltWet", 4, "road"),
    "arcade": ("PaversWarm", 3, "arcade"),
    "alley": ("ConcreteDark", 3, "alley"),
    "lane": ("PaversWarmWet", 3, "lane"),
}


def streets(g):
    for name, st in P.STREETS.items():
        kind = st.get("kind", "road")
        mat, priority, zone = SURFACES[kind]
        half = st["road"] / 2
        for q in g2.strip_quads(st["points"], half, -half):
            g.add(q, mat, 0.0, priority, zone, name)
        left, right = st["walk"]
        if left:
            for q in g2.strip_quads(st["points"], half + left, half):
                g.add(q, "PaversWet", 0.0, 2, "sidewalk", name)
        if right:
            for q in g2.strip_quads(st["points"], -half, -half - right):
                g.add(q, "PaversWet", 0.0, 2, "sidewalk", name)


def plazas(g):
    # The station plaza, between the station and the avenue; the drive crosses it.
    g.add(P.box(-108, -112, -40, -24), "PaversWarmWet", 0.0, 1, "plaza", "the station plaza")
    # The corners of the scramble: sidewalk all round it, cut by the roads.
    g.add(grow(P.SCRAMBLE, 16.0), "PaversWet", 0.0, 1, "plaza", "the scramble")

def base(s, g):
    """Plain ground wherever nothing else is (yards, gaps between buildings) and the solid floor
    under the whole map, except over the river channel."""
    channel = g2.strip_quads(P.RIVER, P.PROM_N[0], P.PROM_S[1])
    land = g2.subtract_all([g2.ccw(P.MAP_RECT)], channel)
    under = [piece for b in P.BUILDINGS for piece in g2.convex_pieces(b["poly"])]
    for piece in g2.subtract_all(land, under):
        g.add(piece, "ConcreteDark", 0.0, 0, "plaza", None)
    for piece in g2.subtract_all(land, [g2.ccw(P.HALL_HOLE)]):
        city.floor(s, piece, 0.0, 2.0, look="Concrete")


def zebra_band(s, a, b, width, y=0.0, stripe=1.0, gap=1.0, mat="WhiteTrim"):
    """Zebra stripes on the walking line a -> b: each stripe runs across the band (width wide) and
    they follow one another along the line."""
    length = math.dist(a, b)
    d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    rot = g2.rot_of(g2.normal_left(d))
    count = int((length + gap) / (stripe + gap))
    start = (length - (count * (stripe + gap) - gap)) / 2
    for k in range(count):
        u = start + k * (stripe + gap) + stripe / 2
        c = (a[0] + d[0] * u, a[1] + d[1] * u)
        s.box(mat, (c[0], y + 0.06, c[1]), (width, 0.12, stripe), rot, skip=("-y",))


def scramble(s, g):
    g.add(P.SCRAMBLE, "AsphaltWet", 0.0, 6, "crossing", "the scramble")
    for ap in P.APPROACHES:
        (px, pz), (dx, dz) = ap["at"], ap["out"]
        # The zebra just inside the junction, across the road...
        back = (px - dx * 4.0, pz - dz * 4.0)
        n = g2.normal_left(ap["out"])
        hw = ap["width"] / 2 - 0.5
        zebra_band(s, (back[0] + n[0] * hw, back[1] + n[1] * hw), (back[0] - n[0] * hw, back[1] - n[1] * hw), 6.0)
        # ...and the stop line on the lanes coming in (the left of "out" is the way out).
        stop = (px + dx * 1.5, pz + dz * 1.5)
        a = (stop[0] - n[0] * 0.2, stop[1] - n[1] * 0.2)
        b = (stop[0] - n[0] * (ap["width"] / 2 - 0.4), stop[1] - n[1] * (ap["width"] / 2 - 0.4))
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        s.box("WhiteTrim", (mid[0], 0.06, mid[1]), (math.dist(a, b), 0.12, 0.8), g2.rot_of(n), skip=("-y",))
    for a, b in P.DIAGONALS:
        zebra_band(s, a, b, 6.0)


def outside_scramble(name, reach=33.0):
    """A street's centre line without the part inside the scramble."""
    pts = P.STREETS[name]["points"]
    length = g2.polyline_length(pts)
    if math.dist(pts[0], P.SCRAMBLE_CENTRE) < 1.0:
        return g2.sub_polyline(pts, reach, length)
    if math.dist(pts[-1], P.SCRAMBLE_CENTRE) < 1.0:
        return g2.sub_polyline(pts, 0.0, length - reach)
    return pts


def _direction_near(points, near):
    best = min(range(len(points) - 1), key=lambda i: g2.dist_point_segment(near, points[i], points[i + 1]))
    a, b = points[best], points[best + 1]
    length = math.dist(a, b)
    return ((b[0] - a[0]) / length, (b[1] - a[1]) / length)


def junction_cuts(name, pts):
    """Where another road crosses (or meets) this one: (point, width) gaps for its lane lines, so
    no line runs on across the other road's carriageway."""
    cuts = []
    for other, st in P.STREETS.items():
        if other == name or st.get("kind", "road") != "road":
            continue
        for h in g2.polyline_hits(pts, st["points"]):
            a, b = _direction_near(pts, h), _direction_near(st["points"], h)
            sin = max(0.3, abs(a[0] * b[1] - a[1] * b[0]))
            cuts.append((h, (st["road"] + 4.0) / sin))
        # A road ending on this one (a T junction) does not cross it: cut at its end too.
        for end in (st["points"][0], st["points"][-1]):
            p = min((g2.dist_point_segment(end, pts[i], pts[i + 1]) for i in range(len(pts) - 1)))
            if p < P.STREETS[name]["road"] / 2 + 1.0:
                b = _direction_near(st["points"], end)
                a = _direction_near(pts, end)
                sin = max(0.3, abs(a[0] * b[1] - a[1] * b[0]))
                cuts.append((end, (st["road"] + 4.0) / sin))
    return cuts


def trimmed(name, pts):
    return [piece for piece in g2.split_polyline(pts, junction_cuts(name, pts)) if g2.polyline_length(piece) > 2.0]


def markings(s):
    """Lane lines, stopping at the scramble and short of every junction."""
    for name in ("ave_nw", "ave_se"):
        for pts in trimmed(name, outside_scramble(name)):
            city.stripe(s, pts, mat="PaintYellow", w=0.35, offset=0.35)
            city.stripe(s, pts, mat="PaintYellow", w=0.35, offset=-0.35)
            for off in (5.0, -5.0):
                city.dashes(s, pts, dash=4, gap=8, w=0.3, offset=off)
    for name in ("east", "kita", "frontage", "minami"):
        for pts in trimmed(name, outside_scramble(name)):
            city.dashes(s, pts, dash=3, gap=5, w=0.3)


def build(s, g):
    streets(g)
    plazas(g)
    scramble(s, g)
    markings(s)
    base(s, g)
