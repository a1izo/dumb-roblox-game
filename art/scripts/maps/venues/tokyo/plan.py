"""Tokyo District's plan, in local studs: x east, z south (north is -z), y up, street level at
y 0. Every street, the river, the station and each building's footprint and height live here;
the venue modules build from them, so the layout sits in one place.

The map is 400 x 300 studs, about 35 seconds corner to corner at walking speed. A player is
about 5.2 studs tall; a ground floor is 14 studs and every floor above it 12, so a nine-floor
building stands 110 studs tall.

Run it on its own (python art/scripts/maps/venues/tokyo/plan.py) to check that no building
overlaps a street, the river or another building.
"""

import math
import os
import sys

if __name__ == "__main__":
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

from maps import geo2d as g2  # noqa: E402

X0, X1, Z0, Z1 = -200.0, 200.0, -150.0, 150.0
BOUNDS = ((X0, -30.0, Z0), (X1, 60.0, Z1))
MAP_RECT = [(X0, Z0), (X1, Z0), (X1, Z1), (X0, Z1)]

FLOOR_GF = 14.0
FLOOR_UP = 12.0


def height(floors):
    return FLOOR_GF + FLOOR_UP * (floors - 1)


# Streets ------------------------------------------------------------------------------------------
# name: centre line, road width, sidewalk on the left of travel and on the right. "Left" is the
# kit's normal_left: north when travelling east.

STREETS = {
    # Under the expressway along the north edge; its north side is the map's edge.
    "frontage": dict(points=[(-206, -141), (206, -141)], road=12.0, walk=(0.0, 5.0)),
    # The avenue: in from the north-west, through the scramble, over the river, out under the viaduct.
    "ave_nw": dict(points=[(-106, -154), (-95, -128), (-71, -97), (-40, -62)], road=20.0, walk=(6.0, 6.0)),
    "ave_se": dict(points=[(-40, -62), (-13, -30), (13, 2), (33, 28), (45, 56), (56, 90), (66, 124), (72, 154)],
                   road=20.0, walk=(6.0, 6.0)),
    # The station drive across the plaza (taxis and buses); the plaza is its sidewalk.
    "drive": dict(points=[(-106, -64), (-40, -62)], road=14.0, walk=(0.0, 0.0)),
    "east": dict(points=[(-40, -62), (20, -57), (80, -50), (140, -45), (206, -41)], road=10.0, walk=(4.0, 4.0)),
    "kita": dict(points=[(129, -154), (128, -125), (125, -92), (121, -62), (118, -45)], road=10.0, walk=(4.0, 4.0)),
    "minami": dict(points=[(96, -48), (99, -12), (103, 26)], road=8.0, walk=(3.0, 3.0)),
    # The covered shopping street, for pedestrians only.
    "arcade": dict(points=[(-14, -84), (10, -95), (44, -101), (84, -101), (124, -96)], road=12.0, walk=(0.0, 0.0),
                   kind="arcade"),
    # The back alley behind the east street's south side.
    "ura": dict(points=[(20, -15), (60, -14), (93, -12)], road=5.0, walk=(0.0, 0.0), kind="alley"),
    # Across the river: the lane along the viaduct and the yokocho's alleys (a dog-leg, a cross
    # alley out to the avenue and a dead end).
    "viaduct_lane": dict(points=[(-206, 130), (206, 130)], road=8.0, walk=(0.0, 0.0), kind="lane"),
    "y_a": dict(points=[(-101.5, 50), (-101.5, 127)], road=5.0, walk=(0.0, 0.0), kind="alley"),
    "y_b": dict(points=[(-61.5, 50), (-61.5, 104), (-56.5, 110), (-56.5, 127)], road=5.0, walk=(0.0, 0.0),
                kind="alley"),
    "y_c": dict(points=[(-21.5, 50), (-21.5, 90.5)], road=5.0, walk=(0.0, 0.0), kind="alley"),
    "y_cross": dict(points=[(-170, 90.5), (40, 90.5)], road=5.0, walk=(0.0, 0.0), kind="alley"),
    "y_dead": dict(points=[(-99, 110.5), (-15, 110.5)], road=5.0, walk=(0.0, 0.0), kind="alley"),
    "lane_e": dict(points=[(112, 62), (112, 127)], road=7.0, walk=(0.0, 0.0), kind="lane"),
}
ARCADE_ROOF = 34.0  # the underside of its roof

# The scramble: where the avenue, the drive and the east street meet.
SCRAMBLE_CENTRE = (-40.0, -62.0)

# The river, west to east; it carries on past the map at both ends and goes underground there.
RIVER = [(-330, 34), (-270, 38), (-206, 40), (-150, 46), (-90, 38), (-30, 42), (30, 38), (90, 50), (150, 46),
         (206, 52), (270, 56), (330, 54)]
# Across it (offsets from the centre line, north positive): the channel between its walls is all
# water; nobody can get down to it.
PROM_N = (16.0, 22.0)  # the north promenade, at street level
CHANNEL = (-9.0, 16.0)  # south wall, north wall
PROM_S = (-15.0, -9.0)  # the south promenade
WATER_Y = -6.0
BED_Y = -8.0
RIVER_CULVERTS = (-300.0, 300.0)  # where it disappears under the city
FOOTBRIDGE_X = -97.0

# The metro: an island platform under the station drive, 20 studs down.
PLATFORM_Y = -20.0
PLATFORM_CEILING = -8.0
PLATFORM = (-140.0, -30.0)  # x extent
PLATFORM_Z = (-73.0, -51.0)  # the island platform
TRACKS_Z = ((-82.0, -73.0), (-51.0, -42.0))

# The expressway (north edge) and the rail viaduct (south edge).
EXPRESSWAY_Y = 26.0
EXPRESSWAY_Z = (-152.0, -128.0)
VIADUCT_Z = (134.0, 150.0)
VIADUCT_Y = 18.0
VIADUCT_LANE_Z = (126.0, 134.0)


# Edges and lots -------------------------------------------------------------------------------------


def edge(name, side, extra=0.0):
    """The outer edge of a street (its road and that side's sidewalk), side 1 left, -1 right,
    pushed `extra` further out."""
    st = STREETS[name]
    off = st["road"] / 2 + st["walk"][0 if side > 0 else 1] + extra
    return g2.offset_polyline(st["points"], off * side)


def lot(name, side, u0, u1, depth, gap=0.0):
    """A footprint fronting a street: from u0 to u1 studs along its edge, `depth` deep."""
    e = edge(name, side, gap)
    u1 = min(u1, g2.polyline_length(e))
    front = []
    for p in g2.sub_polyline(e, max(0.0, u0), u1):
        if not front or math.dist(front[-1], p) > 0.05:
            front.append(p)
    back = g2.offset_polyline(front, depth * side)
    return front + list(reversed(back))


def cut(poly, name, side, gap=0.0):
    """poly with whatever lies on (or over) a street removed: keeps the block side of the
    street's edge segment nearest to poly."""
    e = edge(name, side, gap)
    c = g2.centroid(poly)
    best = min(range(len(e) - 1), key=lambda i: g2.dist_point_segment(c, e[i], e[i + 1]))
    a, b = e[best], e[best + 1]
    # clip_halfplane's "left" is the kit's right (the plan is drawn with -z up).
    return g2.clip_halfplane(poly, a, b, keep_left=side < 0)


def line_cut(poly, a, b, keep):
    """poly clipped by the line a -> b; keep "left" or "right" in the kit's sense."""
    return g2.clip_halfplane(poly, a, b, keep_left=keep == "right")


def river_line(offset):
    return g2.offset_polyline(RIVER, offset)


def river_frame(x):
    """(point on the river's centre line at x, unit direction along it) for a spot on the river."""
    best = None
    total = 0.0
    for i in range(len(RIVER) - 1):
        a, b = RIVER[i], RIVER[i + 1]
        seg = math.dist(a, b)
        if a[0] <= x <= b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            best = total + seg * t
        total += seg
    return g2.point_along(RIVER, best if best is not None else 0.0)


# The scramble ---------------------------------------------------------------------------------------
# A big open junction: the avenue (both ways), the drive and the east street end on its sides,
# 30 studs out from the centre; the kerbs between them are the corners people wait on.


def _approach(name, from_end, reach=30.0):
    pts = STREETS[name]["points"]
    length = g2.polyline_length(pts)
    p, d = g2.point_along(pts, length - reach if from_end else reach)
    if from_end:
        d = (-d[0], -d[1])  # pointing out of the junction
    n = g2.normal_left(d)
    hw = STREETS[name]["road"] / 2
    return dict(name=name, at=p, out=d, kerbs=[(p[0] + n[0] * hw, p[1] + n[1] * hw), (p[0] - n[0] * hw, p[1] - n[1] * hw)],
                width=STREETS[name]["road"])


APPROACHES = [_approach("ave_nw", True, 38.0), _approach("east", False, 32.0), _approach("ave_se", False, 38.0),
              _approach("drive", True, 40.0)]
SCRAMBLE = g2.convex_hull([k for a in APPROACHES for k in a["kerbs"]])


def clear_scramble(poly, margin=7.0):
    """poly kept back from the scramble's nearest kerb by a sidewalk `margin` wide."""
    ring = g2.ccw(SCRAMBLE)
    c = g2.centroid(poly)
    n = len(ring)
    best = min(range(n), key=lambda i: g2.dist_point_segment(c, ring[i], ring[(i + 1) % n]))
    a, b = ring[best], ring[(best + 1) % n]
    length = math.dist(a, b)
    out = ((b[1] - a[1]) / length, -(b[0] - a[0]) / length)  # outside a counter-clockwise ring
    return g2.clip_halfplane(poly, (a[0] + out[0] * margin, a[1] + out[1] * margin),
                             (b[0] + out[0] * margin, b[1] + out[1] * margin), keep_left=False)


def _kerb_mid(first, second):
    """The middle of the kerb between two neighbouring approaches (in turning order)."""
    a = min(APPROACHES[first]["kerbs"], key=lambda p: min(math.dist(p, q) for q in APPROACHES[second]["kerbs"]))
    b = min(APPROACHES[second]["kerbs"], key=lambda p: math.dist(p, a))
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


# The two diagonal crossings: corner to corner.
DIAGONALS = [(_kerb_mid(3, 0), _kerb_mid(1, 2)), (_kerb_mid(0, 1), _kerb_mid(2, 3))]

# The metro's stairs: a switchback straight from the ticket gates. Flight 1 runs down west from
# the paid landing behind the gates to a half landing, flight 2 turns back and runs down east
# onto the platform. The stairwell round them stands on the platform's west end, with a walk
# 5 studs wide past it on both sides of the island.
STAIRWELL = (-146.0, -121.0, -67.5, -56.5)  # x0, x1, z0, z1: the inside of its walls
FLIGHT_1 = dict(z=(-67.5, -62.6), top=(-121.0, 0.0), bottom=(-140.0, -10.0))
FLIGHT_2 = dict(z=(-61.4, -56.5), top=(-140.0, -10.0), bottom=(-121.0, -20.0))
DIVIDER = (-62.6, -61.4)  # the wall between the flights (z), a real wall's thickness
HALF_LANDING = (-146.0, -140.0)  # x extent, at flight 1's foot, both flights wide
# The ticket gates face the entrances; the paid landing behind them leads onto flight 1.
GATE_X = -116.0
PAID = (-121.0, -116.0, -70.6, -53.4)  # x0, x1, z0, z1
# The gate cabinets (2.8 studs wide), the lanes between them wide enough for anyone to walk.
GATES_Z = (-69.2, -62.0, -54.8)
# The opening in the hall's floor over flight 1.
HALL_HOLE = [(-140.0, -67.5), (-121.0, -67.5), (-121.0, -62.6), (-140.0, -62.6)]


# Buildings ------------------------------------------------------------------------------------------
# kind: what it is (the kit builds each kind its own way), floors, front: the street it faces,
# use: the interior it holds (None: a closed ground floor).

BUILDINGS = []


def tidy(poly, shortest=1.0):
    """poly without slivers: while an edge is shorter than `shortest`, one of its ends goes (the
    one whose loss changes the outline least). Cuts along bending streets leave such scraps, and
    a wall a few tenths of a stud long only makes trouble (its windows, its offsets)."""
    pts = [tuple(p) for p in poly]
    while len(pts) > 3:
        n = len(pts)
        i = min(range(n), key=lambda k: math.dist(pts[k], pts[(k + 1) % n]))
        if math.dist(pts[i], pts[(i + 1) % n]) >= shortest:
            break
        before, a, b, after = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        lose_a = abs(g2.area([before, a, b]))
        lose_b = abs(g2.area([a, b, after]))
        pts.pop(i if lose_a <= lose_b else (i + 1) % n)
    return pts


def building(name, poly, floors, kind, front=None, use=None, **extra):
    BUILDINGS.append(dict(name=name, poly=tidy(poly), floors=floors, kind=kind, front=front, use=use, **extra))


def rect(cx, cz, w, d, rot=0.0):
    return g2.rect(cx, cz, w, d, rot)


def box(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


def under_expressway(poly):
    """poly kept clear of the expressway's deck (its south edge)."""
    edge = EXPRESSWAY_Z[1]
    return line_cut(poly, (-300.0, edge), (300.0, edge), "right")


def river_cut(poly, gap=0.0):
    """poly without the river corridor (keeps the side of the promenade it is on)."""
    c = g2.centroid(poly)
    north = river_line(PROM_N[1] + gap)
    south = river_line(PROM_S[0] - gap)
    line = north if g2.dist_to_poly_edge(north, c) < g2.dist_to_poly_edge(south, c) else south
    best = min(range(len(line) - 1), key=lambda i: g2.dist_point_segment(c, line[i], line[i + 1]))
    a, b = line[best], line[best + 1]
    # The river runs east: north of it is the kit's left.
    return g2.clip_halfplane(poly, a, b, keep_left=line is south)


def strip(prefix, x0, x1, z0, z1, widths, floors, kind="bar", uses=None, front=None, along="x"):
    """A row of buildings side by side inside a box, split along x (or z) by widths."""
    at = x0 if along == "x" else z0
    for k, w in enumerate(widths):
        poly = box(at, z0, at + w, z1) if along == "x" else box(x0, at, x1, at + w)
        building(f"{prefix}{k + 1}", poly, floors[k % len(floors)], kind, front=front, use=(uses or {}).get(k))
        at += w


# The station: the hall on the ground floor, offices above; a tower rises behind it.
STATION = box(-152, -110, -108, -25)
HALL = box(-148, -92, -110, -40)
building("station", STATION, 6, "station", front="plaza", use="station_hall")
building("station_tower", box(-200, -128, -154, -66), 16, "glass", front="frontage")
building("station_annex", box(-200, -64, -154, -25), 5, "office", front="river")
building("station_north", box(-152, -128, -118, -112), 4, "office", front="frontage")

# Along the river's north promenade, west of the plaza: backs to the station, fronts to the water,
# and an alley between them from the plaza to the footbridge.
building("hotel_west", box(-200, -25, -172, 14), 7, "hotel", front="river")
building("pencil_west", box(-172, -25, -154, 12), 9, "pencil", front="river")
building("flats_west", box(-154, -25, -126, 14), 5, "apartment", front="river")
building("office_riverside", box(-124, -24, -102, 13), 6, "office", front="plaza")
building("flats_footbridge", box(-92, -20, -64, 12), 5, "apartment", front="river")

# The plaza's corner on the scramble: the police box, and offices down the avenue to the bridge.
building("koban", rect(-68, -31, 16, 12, -27), 1, "koban", front="scramble", use="koban")
building("zakkyo_sw", clear_scramble(cut(lot("ave_se", -1, 22, 52, 24), "drive", -1, 8.0)), 8, "zakkyo", front="ave_se")
building("office_bridge_w", river_cut(lot("ave_se", -1, 56, 92, 26)), 7, "office", front="ave_se")

# The north corner: the glass tower with the giant screen, facing the scramble.
building("glass_tower", clear_scramble(line_cut(cut(lot("ave_nw", 1, 60, 101, 34), "arcade", 1, 2.0),
                                                  (-80, -114), (30, -114), "right")), 18, "glass", front="scramble", screen=True)
building("office_nw1", cut(box(-80, -128, -42, -116), "ave_nw", 1), 5, "office", front="frontage")
building("office_nw2", box(-40, -128, -6, -116), 7, "office", front="frontage")
# The arcade's north side, up to Kita-dori.
building("arcade_n1", under_expressway(lot("arcade", 1, 30, 52, 22)), 5, "shop", front="arcade")
building("arcade_n2", under_expressway(lot("arcade", 1, 52, 74, 22)), 7, "shop", front="arcade", use="game_centre")
building("arcade_n3", under_expressway(lot("arcade", 1, 74, 96, 22)), 4, "shop", front="arcade")
building("arcade_n4", under_expressway(lot("arcade", 1, 96, 116, 22)), 6, "shop", front="arcade")
building("arcade_n5", cut(lot("arcade", 1, 116, 140, 22), "kita", -1), 5, "shop", front="arcade")

# The fork between the arcade and the east street: the department store's wedge at the tip,
# shops along the arcade, offices along the east street, a dead-end service alley between.
building("dept_store", clear_scramble(cut(lot("arcade", -1, 0, 62, 40), "east", 1)), 12, "dept", front="scramble", use="dept",
         screen=True)
building("arcade_s1", lot("arcade", -1, 62, 92, 16), 6, "shop", front="arcade", use="drugstore")
building("arcade_s2", lot("arcade", -1, 92, 114, 16), 5, "shop", front="arcade", use="ramen_clinic")
building("east_n1", lot("east", 1, 96, 116, 13), 8, "office", front="east")
building("east_n2", lot("east", 1, 118, 136, 13), 6, "shop", front="east")
building("kita_w", cut(lot("kita", -1, 78, 97, 14), "east", 1), 9, "zakkyo", front="kita")

# East of Kita-dori: the tall blocks at the edge.
building("tower_ne", lot("kita", 1, 26, 62, 30), 12, "office", front="kita")
building("office_ne", lot("kita", 1, 62, 97, 26), 9, "office", front="kita")
building("edge_ne", cut(box(172, -128, 200, -48), "east", 1), 14, "edge")

# South of the east street, east of the avenue: the zakkyo tower on the scramble's corner, the
# konbini, a back alley (ura) and a row facing the river.
building("zakkyo_se", clear_scramble(cut(cut(lot("east", -1, 32, 60, 34), "ave_se", 1), "ura", 1)), 9, "zakkyo", front="scramble")
building("konbini_block", cut(lot("east", -1, 60, 94, 34), "ura", 1), 6, "shop", front="east", use="konbini")
building("east_s2", cut(cut(lot("east", -1, 94, 130, 34), "ura", 1), "minami", -1), 7, "office", front="east")
building("river_bridge_e", river_cut(cut(cut(box(10, -9, 52, 20), "ave_se", 1), "ura", -1)), 7, "office",
         front="ave_se")
building("river_se1", river_cut(box(54, -9, 74, 22)), 5, "apartment", front="river")
building("river_se2", river_cut(cut(box(76, -9, 94, 26), "minami", -1)), 6, "hotel", front="river")
building("east_s3", cut(lot("east", -1, 148, 186, 26), "minami", 1), 8, "office", front="east")
building("edge_se", lot("east", -1, 188, 240, 26), 10, "edge", front="east")
building("river_e1", river_cut(box(110, -4, 146, 26)), 5, "apartment", front="river")
building("river_e2", river_cut(box(150, -2, 200, 30)), 12, "edge", front="river")

# Across the river, east of the avenue: the karaoke tower facing the bridge, the laundromat on a
# lane down to the viaduct.
building("karaoke", river_cut(box(78, 64, 107, 98)), 10, "karaoke", front="ave_se", use="karaoke")
building("karaoke_back", cut(box(76, 101, 108, 125), "ave_se", 1), 4, "apartment", front="viaduct_lane")
building("laundromat", river_cut(box(116, 66, 138, 94)), 4, "apartment", front="lane_e", use="laundromat")
building("flats_se", river_cut(box(140, 64, 176, 94)), 6, "apartment", front="river")
building("edge_s", river_cut(box(178, 66, 200, 125)), 11, "edge")
building("hotel_se", box(116, 97, 176, 125), 5, "hotel", front="viaduct_lane")

# Across the river, west of the avenue: the yokocho. Tiny bars of two or three floors in rows
# between its alleys, flats, a pocket park and business hotels at its west end, and taller
# buildings along the avenue.
building("flats_yw", river_cut(box(-200, 56, -168, 88)), 6, "apartment", front="river")
building("hotel_yw1", box(-200, 113, -160, 125), 6, "hotel", front="viaduct_lane")
building("hotel_yw2", box(-158, 113, -104, 125), 4, "hotel", front="viaduct_lane")
strip("yw_row", -166, -104, 94, 108, [10, 12, 9, 11, 10, 10], [2, 3, 2, 2, 3, 2], front="y_cross")
strip("yp_row", -130, -104, 60, 88, [13, 13], [3, 2], front="y_a")
# Between alley A (x -104..-99) and alley B (x -64..-59).
strip("ya_n", -99, -64, 60, 74, [12, 11, 12], [2, 3, 2], front="river")
strip("ya_s", -99, -64, 74, 88, [9, 13, 13], [3, 2, 2], front="y_cross", uses={1: "izakaya"})
strip("yb_n", -99, -64, 93, 108, [12, 11, 12], [2, 2, 3], front="y_cross")
strip("yb_s", -99, -59, 113, 125, [10, 10, 10, 10], [2, 3, 2, 2], front="viaduct_lane")
# Between alley B and alley C (x -24..-19).
strip("yc_n", -59, -24, 60, 73, [11, 12, 12], [3, 2, 2], front="river")
strip("yc_s", -59, -24, 73, 88, [12, 11, 12], [2, 3, 2], front="y_cross")
strip("yd_n", -54, -18, 93, 108, [12, 12, 12], [2, 3, 2], front="y_cross")
strip("yd_s", -54, -18, 113, 125, [9, 9, 9, 9], [2, 2, 3, 2], front="y_dead")
# Along the avenue: the yokocho's taller edge.
building("yokocho_gate", box(-19, 58, 8, 88), 4, "zakkyo", front="y_cross")
building("yokocho_ne", cut(box(10, 58, 32, 88), "ave_se", -1), 6, "zakkyo", front="ave_se")
building("yokocho_s1", box(-13, 93, 14, 125), 3, "apartment", front="y_cross")
building("yokocho_s2", cut(box(16, 93, 46, 125), "ave_se", -1), 7, "apartment", front="ave_se")


# Checks ---------------------------------------------------------------------------------------------


def bands():
    """Where no building may stand: every street and the river corridor, as convex quads."""
    out = []
    for name, st in STREETS.items():
        left = st["road"] / 2 + st["walk"][0]
        right = st["road"] / 2 + st["walk"][1]
        out += [(name, q) for q in g2.strip_quads(st["points"], left, -right)]
    out += [("river", q) for q in g2.strip_quads(RIVER, PROM_N[1], PROM_S[0])]
    return out


def check():
    problems = []
    streets = bands()
    pieces = [(b["name"], g2.convex_pieces(b["poly"])) for b in BUILDINGS]
    for name, parts in pieces:
        for piece in parts:
            for street, q in streets:
                hit = g2.intersect(piece, q)
                if hit and abs(g2.area(hit)) > 1.0:
                    problems.append(f"{name} overlaps {street} ({abs(g2.area(hit)):.0f} sq studs)")
            for x, z in piece:
                if not (X0 - 0.01 <= x <= X1 + 0.01 and Z0 - 0.01 <= z <= Z1 + 0.01):
                    problems.append(f"{name} leaves the map at ({x:.0f}, {z:.0f})")
                    break
    for i, (a, pa) in enumerate(pieces):
        for b, pb in pieces[i + 1:]:
            for p in pa:
                for q in pb:
                    hit = g2.intersect(p, q)
                    if hit and abs(g2.area(hit)) > 1.0:
                        problems.append(f"{a} overlaps {b}")
    return sorted(set(problems))


if __name__ == "__main__":
    found = check()
    for b in BUILDINGS:
        xs = [p[0] for p in b["poly"]]
        zs = [p[1] for p in b["poly"]]
        print(f"{b['name']:18} {b['kind']:9} {b['floors']:2} floors {height(b['floors']):5.0f} studs  "
              f"x {min(xs):6.0f}..{max(xs):6.0f}  z {min(zs):6.0f}..{max(zs):6.0f}  area {abs(g2.area(b['poly'])):6.0f}")
    print(f"{len(BUILDINGS)} buildings, {len(found)} problem(s)")
    for p in found:
        print("  -", p)
