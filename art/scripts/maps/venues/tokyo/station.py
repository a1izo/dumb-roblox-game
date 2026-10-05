"""The metro under the station drive: an island platform between two tracks, full-height screen
doors along its edges, tunnel mouths at both ends, and the stairwell at its west end. The stairs
are a switchback straight from the ticket gates in the station hall: flight 1 runs down west to
a half landing, flight 2 turns back and comes down east onto the platform.

Lit like a real platform at night: grey tile, a dark ceiling and fluorescent fittings (kit.tube_
light), no neon. The hall, the stairwell and the metro are a "look zone" with a dimmer lighting
preset of their own (LightingPresets.maps.TokyoDistrict_Under)."""

from maps import city, kit
from maps import geo2d as g2
from maps.venues.tokyo import plan as P

TRACK_Y = P.PLATFORM_Y - 4.0  # the trackbed, a platform's height below
WALL = "TileMetroGrey"
FLOOR = "TileMetroFloor"
CEILING = "CeilingDark"
UNDER = "TokyoDistrict_Under"
HALL_FLOOR = 0.06  # the station hall's floor over the stairs (interiors.shell)


def _face(s, mat, pts, out):
    """A flat face through pts ((x, y, z) corners in order), turned to face `out` (x, y, z)."""
    (ax, ay, az), (bx, by, bz), (cx, cy, cz) = pts[0], pts[1], pts[2]
    u = (bx - ax, by - ay, bz - az)
    v = (cx - ax, cy - ay, cz - az)
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
    if n[0] * out[0] + n[1] * out[1] + n[2] * out[2] < 0:
        pts = list(reversed(pts))
    s.polygon(mat, pts)


def flight_y(flight, x):
    """The height of a flight's walking line at x."""
    (xa, ya), (xb, yb) = flight["top"], flight["bottom"]
    t = (x - xa) / (xb - xa)
    return ya + (yb - ya) * max(0.0, min(1.0, t))


def box_room(s):
    x0, x1 = P.PLATFORM
    z0, z1 = P.TRACKS_Z[0][0], P.TRACKS_Z[1][1]
    top = P.PLATFORM_CEILING
    sx0, sx1, sz0, sz1 = P.STAIRWELL
    # Walls along the tracks.
    city.vquad(s, WALL, (x0, z0), (x1, z0), TRACK_Y, top, (0, 1))
    city.vquad(s, WALL, (x0, z1), (x1, z1), TRACK_Y, top, (0, -1))
    for z in (z0 - 0.5, z1 + 0.5):
        s.collider(((x0 + x1) / 2, (TRACK_Y + top) / 2, z), (x1 - x0, top - TRACK_Y, 1.0), 0, True, None)
    # The ceiling (and the ground above it), except over the stairwell.
    well = P.box(x0 - 1.0, sz0, sx1, sz1)
    for piece in g2.subtract_all([g2.ccw(P.box(x0, z0, x1, z1))], [g2.ccw(well)]):
        city.down_face(s, CEILING, piece, top)
        city.floor(s, piece, top + 2.0, 2.0)
    # Ends: tunnel mouths over the tracks, a tiled wall across the platform (the west one either
    # side of the stairwell, which carries on past it).
    pz0, pz1 = P.PLATFORM_Z
    for x, facing, spans in ((x0, 1, [(pz0, sz0 - 0.5), (sz1 + 0.5, pz1)]), (x1, -1, [(pz0, pz1)])):
        for a, b in spans:
            city.vquad(s, WALL, (x, a), (x, b), P.PLATFORM_Y, top, (facing, 0))
            s.collider((x - facing * 0.5, (P.PLATFORM_Y + top) / 2, (a + b) / 2), (1.0, top - P.PLATFORM_Y, b - a),
                       0, True, None)
        for (t0, t1) in P.TRACKS_Z:
            city.vquad(s, WALL, (x, t0), (x, t1), TRACK_Y + 10.0, top, (facing, 0))
            city.vquad(s, "BlackTrim", (x - facing * 6, t0), (x - facing * 6, t1), TRACK_Y, TRACK_Y + 10.0, (facing, 0))
            # The tunnel's first stretch: its sides and roof, dark, down to the black of its depth.
            back = x - facing * 6
            city.vquad(s, "ConcreteDark", (x, t0), (back, t0), TRACK_Y, TRACK_Y + 10.0, (0, 1))
            city.vquad(s, "ConcreteDark", (x, t1), (back, t1), TRACK_Y, TRACK_Y + 10.0, (0, -1))
            city.down_face(s, "ConcreteDark", P.box(min(x, back), t0, max(x, back), t1), TRACK_Y + 10.0)
            s.collider((x - facing * 6.5, (TRACK_Y + top) / 2, (t0 + t1) / 2), (1.0, top - TRACK_Y, t1 - t0), 0, True,
                       None)
    s.look_zone(UNDER, (x0 - 8.0, TRACK_Y - 2.0, z0 - 1.0), (x1 + 8.0, -1.5, z1 + 1.0))


def platform(s, g):
    x0, x1 = P.PLATFORM
    pz0, pz1 = P.PLATFORM_Z
    island = P.box(x0, pz0, x1, pz1)
    g.add(island, FLOOR, P.PLATFORM_Y, 3, "platform", "the metro platform")
    city.floor(s, island, P.PLATFORM_Y, 4.0, look=FLOOR)
    # Tactile strips along both edges, and the edges' faces down to the tracks.
    for z, facing in ((pz0, -1), (pz1, 1)):
        s.box("PaintYellow", ((x0 + x1) / 2, P.PLATFORM_Y + 0.06, z - facing * 1.6), (x1 - x0, 0.12, 1.0), 0,
              skip=("-y",))
        city.vquad(s, "ConcreteDark", (x0, z), (x1, z), TRACK_Y, P.PLATFORM_Y, (0, facing))
        screen_doors(s, x0, x1, z, facing)
    for t0, t1 in P.TRACKS_Z:
        bed = P.box(x0 - 8, t0, x1 + 8, t1)
        city.up_face(s, "ConcreteDark", bed, TRACK_Y)
        city.floor(s, bed, TRACK_Y, 2.0, look="ConcreteDark")
        s.zone("track", P.box(x0, t0, x1, t1), TRACK_Y)
        mid = (t0 + t1) / 2
        for rail in (-2.4, 2.4):
            s.box("Steel", ((x0 + x1) / 2, TRACK_Y + 0.35, mid + rail), (x1 - x0 + 16, 0.7, 0.35), 0)
    # Fluorescent fittings down the middle, one over each walk past the stairwell.
    mid = (pz0 + pz1) / 2
    for x in (-112.0, -92.0, -72.0, -52.0, -34.0):
        kit.tube_light(s, x, P.PLATFORM_CEILING, mid, length=8.0, rot=0.0, range_=18, brightness=0.6)
    sx0, sx1, sz0, sz1 = P.STAIRWELL
    for z in ((pz0 + sz0) / 2, (sz1 + pz1) / 2):
        kit.tube_light(s, (x0 + sx1) / 2, P.PLATFORM_CEILING, z, length=6.0, rot=0.0, range_=14, brightness=0.5)
    # The station's name on the track walls, facing the platform over each track.
    for z, facing in ((P.TRACKS_Z[0][0] + 0.16, 180), (P.TRACKS_Z[1][1] - 0.16, 0)):
        for x in (-104.0, -64.0):
            s.sign((x, P.PLATFORM_Y + 7.4, z), facing, 12.0, 1.8, "影ヶ丘  KAGEGAOKA", "GothamBlack",
                   (24, 26, 32), (226, 228, 230))


def screen_doors(s, x0, x1, z, facing, h=8.0, bay=6.0):
    """Full-height glass screen doors along a platform edge, up to a header band that meets the
    ceiling: nobody gets onto the tracks, and nothing invisible is needed to stop them."""
    zz = z - facing * 0.4
    top = P.PLATFORM_CEILING
    x = x0 + 1.0
    while x + bay <= x1 - 1.0:
        s.box("DarkMetal", (x, P.PLATFORM_Y + h / 2, zz), (0.4, h, 0.5), 0)
        s.box("Glass", (x + bay / 2, P.PLATFORM_Y + h / 2, zz), (bay - 0.4, h - 0.2, 0.1), 0)
        s.box("BlackTrim", (x + bay / 2, P.PLATFORM_Y + 1.1, zz), (bay - 0.4, 0.12, 0.14), 0)
        x += bay
    s.box("DarkMetal", (x, P.PLATFORM_Y + h / 2, zz), (0.4, h, 0.5), 0)
    # The header: a steel band from the doors to the ceiling with a strip of door lamps.
    s.box("DarkMetal", ((x0 + x1) / 2, (P.PLATFORM_Y + h + top) / 2, zz), (x1 - x0, top - P.PLATFORM_Y - h, 0.6), 0)
    s.collider(((x0 + x1) / 2, (P.PLATFORM_Y + top) / 2, zz), (x1 - x0, top - P.PLATFORM_Y, 0.6), 0, True, None)


def stairwell(s, g):
    """The switchback from the gates down to the platform, inside tiled walls."""
    sx0, sx1, sz0, sz1 = P.STAIRWELL
    f1, f2 = P.FLIGHT_1, P.FLIGHT_2
    land_y = f1["bottom"][1]
    floor_under = -2.0  # the hall floor's underside, the stairwell's ceiling
    # The flights and the half landing.
    for f in (f1, f2):
        zc = (f["z"][0] + f["z"][1]) / 2
        w = f["z"][1] - f["z"][0]
        city.stairs(s, g, (f["top"][0], zc), (f["bottom"][0], zc), f["top"][1], f["bottom"][1], w, "Stone",
                    "ConcreteDark", step=0.9, name="the metro stairs")
    landing = P.box(P.HALF_LANDING[0], sz0, P.HALF_LANDING[1], sz1)
    city.up_face(s, "Stone", landing, land_y)
    city.floor(s, landing, land_y, 1.0, look="Stone")
    s.zone("stairs", landing, land_y, name="the metro stairs")
    # The walls: tiled inside from the platform's level to the hall floor; outside, the part that
    # stands on the platform is tiled too, round the east corners.
    top = HALL_FLOOR
    for z, out in ((sz0, 1), (sz1, -1)):
        city.vquad(s, WALL, (sx0, z), (sx1, z), P.PLATFORM_Y, top, (0, out))
        city.vquad(s, WALL, (P.PLATFORM[0], z - out * 0.5), (sx1 + 0.5, z - out * 0.5), P.PLATFORM_Y,
                   P.PLATFORM_CEILING, (0, -out))
        s.collider(((sx0 + sx1) / 2 + 0.25, (P.PLATFORM_Y + top) / 2, z - out * 0.25), (sx1 - sx0 + 0.5, -P.PLATFORM_Y, 0.5),
                   0, True, None)
    city.vquad(s, WALL, (sx0, sz0), (sx0, sz1), land_y - 10.0, floor_under, (1, 0))
    s.collider((sx0 - 0.25, (P.PLATFORM_Y + top) / 2, (sz0 + sz1) / 2), (0.5, -P.PLATFORM_Y, sz1 - sz0), 0, True, None)
    # The east end: solid under flight 1 and the divider; over flight 2 a doorway onto the
    # platform, a lintel above. Every face of it closed: the outside round both corners, the
    # doorway's jambs and soffit.
    door_top = P.PLATFORM_Y + 9.0
    e1 = (f1["z"][0], P.DIVIDER[1])
    city.vquad(s, WALL, (sx1, e1[0]), (sx1, e1[1]), P.PLATFORM_Y, top, (-1, 0))
    city.vquad(s, WALL, (sx1 + 0.5, sz0 - 0.5), (sx1 + 0.5, e1[1]), P.PLATFORM_Y, P.PLATFORM_CEILING, (1, 0))
    s.collider((sx1 + 0.25, (P.PLATFORM_Y + top) / 2, (e1[0] + e1[1]) / 2), (0.5, -P.PLATFORM_Y, e1[1] - e1[0]), 0,
               True, None)
    e2 = (P.DIVIDER[1], sz1)
    city.vquad(s, WALL, (sx1, e2[0]), (sx1, e2[1]), door_top, floor_under, (-1, 0))
    city.vquad(s, WALL, (sx1 + 0.5, e2[0]), (sx1 + 0.5, sz1 + 0.5), door_top, P.PLATFORM_CEILING, (1, 0))
    city.down_face(s, WALL, P.box(sx1, e2[0], sx1 + 0.5, e2[1]), door_top)
    city.vquad(s, WALL, (sx1, e2[0]), (sx1 + 0.5, e2[0]), P.PLATFORM_Y, door_top, (0, 1))
    city.vquad(s, WALL, (sx1, e2[1]), (sx1 + 0.5, e2[1]), P.PLATFORM_Y, door_top, (0, -1))
    city.vquad(s, WALL, (sx1 + 0.5, e2[1]), (sx1 + 0.5, sz1 + 0.5), P.PLATFORM_Y, door_top, (1, 0))
    s.collider((sx1 + 0.25, (door_top + top) / 2, (e2[0] + e2[1]) / 2), (0.5, top - door_top, e2[1] - e2[0]), 0, True,
               None)
    # Steel edges on the doorway's corners and along its head.
    for z in (e2[0] + 0.12, e2[1] - 0.12):
        s.box("Steel", (sx1 + 0.56, (P.PLATFORM_Y + door_top) / 2, z), (0.12, door_top - P.PLATFORM_Y, 0.24), 0)
    s.box("Steel", (sx1 + 0.56, door_top - 0.06, (e2[0] + e2[1]) / 2), (0.12, 0.12, e2[1] - e2[0]), 0)
    divider(s, f1, f2, floor_under)
    d0, d1 = P.DIVIDER
    # Handrails along both walls and both sides of the divider.
    for f, z in ((f1, sz0 + 0.25), (f1, d0 - 0.3), (f2, d1 + 0.45), (f2, sz1 - 0.25)):
        (ax, ay), (bx, by) = f["top"], f["bottom"]
        s.tube("Steel", (ax, ay + 3.0, z), (bx, by + 3.0, z), 0.09, 8)
    # The ceiling: the hall floor's underside, open over flight 1 (the hole in the hall floor).
    hole = g2.ccw(P.HALL_HOLE)
    for piece in g2.subtract_all([g2.ccw(P.box(sx0, sz0, sx1, sz1))], [hole]):
        city.down_face(s, CEILING, piece, floor_under)
    # The hall floor's edge round the hole, where you can see it.
    hx0 = min(x for x, _ in P.HALL_HOLE)
    city.vquad(s, WALL, (hx0, sz0), (hx0, d0), floor_under, HALL_FLOOR, (1, 0))
    # Fittings: over the half landing and over flight 2's foot.
    kit.tube_light(s, (sx0 + P.HALF_LANDING[1]) / 2, floor_under, (sz0 + sz1) / 2, length=6.0, rot=90.0, range_=14,
                   brightness=0.55)
    kit.tube_light(s, sx1 - 5.0, floor_under, (d1 + sz1) / 2, length=5.0, rot=0.0, range_=14, brightness=0.55)
    s.look_zone(UNDER, (sx0 - 1.0, P.PLATFORM_Y - 1.0, sz0 - 1.0), (sx1 + 1.0, -1.5, sz1 + 1.0))


def divider(s, f1, f2, ceiling):
    """The wall between the flights: a parapet 3.5 over flight 1 and down to flight 2 on its
    other side, a real wall's thickness, with a stone coping along its top, pilasters on its
    tall side and a square column where it ends on the half landing (carrying the hall floor
    over the landing). At the top it runs into the hall floor's slab, whose edge closes over it
    where the parapet dips under the slab."""
    d0, d1 = P.DIVIDER
    xa, xb = f1["bottom"][0], f1["top"][0]
    rail = 3.5
    slab = HALL_FLOOR

    def p1(x):
        return flight_y(f1, x)

    def p2(x):
        return flight_y(f2, x)

    def top(x):
        return min(p1(x) + rail, slab)

    # Where the parapet's top reaches the underside of the hall floor, and the floor itself.
    x_under = xa + (xb - xa) * ((ceiling - rail) - p1(xa)) / (p1(xb) - p1(xa))
    x_flush = xa + (xb - xa) * ((slab - rail) - p1(xa)) / (p1(xb) - p1(xa))
    # Flight 1's side: the parapet, and the slab's edge over it.
    side = [(xa, p1(xa), d0), (xb, p1(xb), d0)]
    if top(xb) > p1(xb) + 0.01:
        side.append((xb, top(xb), d0))
    _face(s, WALL, side + [(x_flush, slab, d0), (xa, top(xa), d0)], (0, 0, -1))
    _face(s, WALL, [(xa, ceiling, d0), (x_under, ceiling, d0), (x_flush, slab, d0), (xa, slab, d0)], (0, 0, -1))
    # Flight 2's side, up to the ceiling over it.
    _face(s, WALL, [(xa, p2(xa), d1), (xb, p2(xb), d1), (xb, ceiling, d1), (x_under, ceiling, d1),
                    (xa, top(xa), d1)], (0, 0, 1))
    # The coping, where it is in sight (further up it is inside the slab).
    lo, hi = d0 - 0.12, d1 + 0.12
    ya, yb = top(xa), top(x_under)
    _face(s, "Stone", [(xa, ya + 0.25, lo), (x_under, yb + 0.25, lo), (x_under, yb + 0.25, hi), (xa, ya + 0.25, hi)],
          (0, 1, 0))
    for z, out in ((lo, -1), (hi, 1)):
        _face(s, "Stone", [(xa, ya, z), (x_under, yb, z), (x_under, yb + 0.25, z), (xa, ya + 0.25, z)], (0, 0, out))
    _face(s, "Stone", [(xa, ya, lo), (x_under, yb, lo), (x_under, yb, d0), (xa, ya, d0)], (0, -1, 0))
    _face(s, "Stone", [(xa, ya, d1), (x_under, yb, d1), (x_under, yb, hi), (xa, ya, hi)], (0, -1, 0))
    # Pilasters on the tall side, from flight 2's steps to the ceiling.
    for x in (xa + (xb - xa) / 3, xa + (xb - xa) * 2 / 3):
        y0 = p2(x)
        s.box(WALL, (x, (y0 + ceiling) / 2, d1 + 0.1), (0.9, ceiling - y0, 0.2), 0, skip=("-y", "+y"))
    # The column on the half landing, the divider's end against it.
    cx0, cx1 = xa - 1.6, xa
    cz0, cz1 = d0 - 0.1, d1 + 0.1
    land = f1["bottom"][1]
    s.box(WALL, ((cx0 + cx1) / 2, (land + ceiling) / 2, (cz0 + cz1) / 2), (cx1 - cx0, ceiling - land, cz1 - cz0), 0,
          skip=("-y", "+y"), collide=True)
    s.box("Stone", ((cx0 + cx1) / 2, land + 0.3, (cz0 + cz1) / 2), (cx1 - cx0 + 0.3, 0.6, cz1 - cz0 + 0.3), 0,
          skip=("-y",))
    s.box("Steel", ((cx0 + cx1) / 2, ceiling - 0.3, (cz0 + cz1) / 2), (cx1 - cx0 + 0.2, 0.6, cz1 - cz0 + 0.2), 0,
          skip=("+y",))
    # Solid, in steps down its slope.
    segments = 8
    for k in range(segments):
        u0 = xa + (xb - xa) * k / segments
        u1 = xa + (xb - xa) * (k + 1) / segments
        high = max(top(u0), top(u1))
        s.collider(((u0 + u1) / 2, (P.PLATFORM_Y + high) / 2, (d0 + d1) / 2), (abs(u1 - u0), high - P.PLATFORM_Y, d1 - d0),
                   0, True, None)


def build(s, g):
    box_room(s)
    platform(s, g)
    stairwell(s, g)
