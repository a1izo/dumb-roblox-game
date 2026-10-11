"""Tokyo's interiors, furnished by hand: the station hall, the police box, the department store
(two floors), the drugstore, the ramen bar with the clinic upstairs, the game centre, the konbini,
the karaoke hotel (two floors), the laundromat and an izakaya. Each is a room inside its
building's footprint (the building kit leaves those ground floors open): walls with real doors
and shop windows, floor, ceiling, a light fitting in the ceiling for every light, then its
furniture and the case-file stations, sheets and spots that belong there.

Rotations follow the map kit: rot 0 faces -Z, 90 faces -X, 180 faces +Z, -90 faces +X; a
station's worker stands on the side it faces."""

import math

from maps import city, kit
from maps import geo2d as g2
from maps.buildings import edges_of, grow
from maps.venues.tokyo import plan as P

WARM = (255, 226, 190)
COOL = (230, 240, 255)
CEIL = 13.0  # ground-floor ceiling (the floor above is 14)
UP = 14.0  # the first floor up


def building(name):
    return next(b for b in P.BUILDINGS if b["name"] == name)


def edge_towards(poly, direction):
    """The wall of poly (edges_of order) whose outside faces most along direction (x, z)."""
    edges = edges_of(poly)
    return max(range(len(edges)), key=lambda i: edges[i].n[0] * direction[0] + edges[i].n[1] * direction[1]
               + 0.001 * edges[i].length)


def shell(s, g, b, doors, inside="PlasterLight", floor="TileMetroGrey", outside=None, storefront=(), name=None,
          zone=True, holes=(), stairwells=(), ceiling="CeilingDark", look=True, rooms=1):
    """Ground-floor walls round a building's footprint with doors ({edge index: [(u from the
    middle, width)]}) and shop windows on the storefront edges; the floor and the ceiling, open
    over the stairwells (the holes in the floor above), so nobody's head goes through it on the
    way up. look: the camera takes the interior lighting look inside (rooms: floors it covers)."""
    poly = b["poly"]
    outside = outside or "PlasterGrey"
    edges = edges_of(poly)
    for i, e in enumerate(edges):
        a = e.at(0, -0.5)
        c = e.at(e.length, -0.5)
        length = math.dist(a, c)
        # (A door keeps 0.8 of wall at both its sides, however short the wall.)
        fitted = []
        for u, width in doors.get(i, []):
            width = min(width, length - 1.6)
            u = max(-length / 2 + 0.8 + width / 2, min(length / 2 - 0.8 - width / 2, u))
            fitted.append((u, width))
        ops = city.openings_for(length, fitted, CEIL + 1.0, 0.0, storefront=i in storefront)
        kit.wall(s, a, c, UP, thick=1.0, base=0.0, core=outside, side_n=outside, side_s=inside, openings=ops,
                 trim_s={"base": "BlackTrim"})
    inner = grow(poly, -1.0)
    # The floor runs on under the walls to the building's face: in a doorway it is the threshold
    # (short of it the ground would end in a slit down into the dark).
    for piece in g2.subtract_all(g2.convex_pieces(g2.ccw(poly)), [g2.ccw(h) for h in holes]):
        city.up_face(s, floor, piece, 0.1)
        city.floor(s, piece, 0.1, 0.4, floor)
    for e in edges:
        city.vquad(s, floor, e.a, e.b, 0.0, 0.1, e.n)
    for piece in g2.subtract_all(g2.convex_pieces(inner), [g2.ccw(h) for h in stairwells]):
        city.down_face(s, ceiling, piece, CEIL)
    for hole in stairwells:
        # The slab's edge round the opening, between this ceiling and the floor above.
        ring = g2.ccw(hole)
        for k in range(len(ring)):
            p, q = ring[k], ring[(k + 1) % len(ring)]
            length = math.dist(p, q)
            if length < 0.05:
                continue
            away = ((q[1] - p[1]) / length, -(q[0] - p[0]) / length)  # the right of p -> q: out of the hole
            city.vquad(s, inside, p, q, CEIL, UP, (-away[0], -away[1]))
    if zone:
        s.zone("interior", inner, 0.0, name=name or b["name"])
    if look:
        # Boxes filling the room (strips across a turned or odd-shaped one), never out past its
        # walls, so the look changes at the door and not out on the street.
        for x0, z0, x1, z1 in inside_boxes(grow(poly, -1.2)):
            s.look_zone("TokyoDistrict_Inside", (x0, -1.0, z0), (x1, UP + (CEIL if rooms > 1 else 0.0), z1))
    return edges


def _span_at(poly, z):
    """The widest run of x inside poly along the line at z, or None."""
    xs = []
    n = len(poly)
    for i in range(n):
        (ax, az), (bx, bz) = poly[i], poly[(i + 1) % n]
        if (az <= z < bz) or (bz <= z < az):
            xs.append(ax + (bx - ax) * (z - az) / (bz - az))
    xs.sort()
    runs = [(xs[k], xs[k + 1]) for k in range(0, len(xs) - 1, 2)]
    return max(runs, key=lambda r: r[1] - r[0]) if runs else None


def inside_boxes(poly, step=2.0):
    """Axis-aligned boxes (x0, z0, x1, z1) lying inside poly: strips `step` deep, each as wide
    as the polygon is along all of it, merged where neighbours line up."""
    bx0, bz0, bx1, bz1 = g2.bbox(poly)
    strips = []
    z = bz0
    while z < bz1 - 0.2:
        z2 = min(z + step, bz1)
        spans = [_span_at(poly, zz) for zz in (z + 0.01, (z + z2) / 2, z2 - 0.01)]
        if all(spans):
            lo, hi = max(sp[0] for sp in spans), min(sp[1] for sp in spans)
            if hi - lo > 1.0:
                strips.append([lo, z, hi, z2])
        z = z2
    merged = []
    for st in strips:
        last = merged[-1] if merged else None
        if last and abs(last[3] - st[1]) < 1e-6 and abs(last[0] - st[0]) < 0.6 and abs(last[2] - st[2]) < 0.6:
            last[0], last[2], last[3] = max(last[0], st[0]), min(last[2], st[2]), st[3]
        else:
            merged.append(st)
    return [tuple(m) for m in merged]


def upper_room(s, b, floor="CarpetGrey", inside="PlasterLight", holes=(), name=None, ceiling="CeilingDark"):
    """The first floor up as a room: a slab (with holes for stairs), walls' inner faces and their
    colliders, a ceiling. The slab is solid everywhere but the holes, right up to the top step."""
    poly = b["poly"]
    inner = grow(poly, -1.0)
    pieces = g2.subtract_all(g2.convex_pieces(inner), [g2.ccw(h) for h in holes])
    for piece in pieces:
        city.up_face(s, floor, piece, UP)
        city.floor(s, piece, UP, 1.0, floor)
    for piece in g2.convex_pieces(inner):
        city.down_face(s, ceiling, piece, UP + CEIL - 1.0)
    for e in edges_of(inner):
        city.vquad(s, inside, e.a, e.b, UP, UP + 12.0, (-e.n[0], -e.n[1]))
        mid = e.at(e.length / 2, 0.5)
        s.collider((mid[0], UP + 6.0, mid[1]), (e.length + 1.0, 12.0, 1.0), e.rot, True, None)
    s.zone("interior", inner, UP, name=name or b["name"])


# Rooms are lit well enough to read, a step darker than the street's pools of light: every
# fitting's light is scaled down, and its panel is a frosted diffuser that does not bloom.
ROOM_BRIGHTNESS = 0.85
ROOM_RANGE = 1.0


def lights(s, points, y=CEIL, color=WARM, w=3.0, d=1.2, brightness=1.3, range_=22, rot=0.0):
    """Ceiling panels, each with its light."""
    for x, z in points:
        kit.panel_light(s, x, y, z, w, d, color=color, range_=range_ * ROOM_RANGE,
                        brightness=brightness * ROOM_BRIGHTNESS, rot=rot, soft=True)


def counter(s, x, z, rot, w, d=2.4, h=3.5, y=0.0, top="MarbleWhite", body="WhiteTrim"):
    s.box(body, (x, y + h / 2 - 0.05, z), (w, h - 0.1, d), rot)
    s.box(top, (x, y + h - 0.05, z), (w + 0.2, 0.1, d + 0.2), rot)
    s.collider((x, y + h / 2, z), (w, h, d), rot, True, body)
    return y + h + 0.05


def table(s, x, z, w, d, rot=0.0, y=0.0, top="Wood"):
    s.box(top, (x, y + 2.65, z), (w, 0.2, d), rot)
    a = math.radians(rot)
    for dx in (-w / 2 + 0.3, w / 2 - 0.3):
        for dz in (-d / 2 + 0.3, d / 2 - 0.3):
            px = x + dx * math.cos(a) + dz * math.sin(a)
            pz = z - dx * math.sin(a) + dz * math.cos(a)
            s.box("BlackMetal", (px, y + 1.3, pz), (0.2, 2.6, 0.2), rot)
    s.collider((x, y + 1.375, z), (w, 2.75, d), rot, True, top)
    return y + 2.8


def exam_bed(s, x, z, y):
    """A clinic's exam bed along z (head to the south wall) with a curtain on a rail round it."""
    s.box("Steel", (x, y + 1.0, z), (2.4, 0.2, 6.0))
    for dx in (-1.0, 1.0):
        for dz in (-2.7, 2.7):
            s.box("Steel", (x + dx, y + 0.5, z + dz), (0.12, 1.0, 0.12))
    s.box("WhiteTrim", (x, y + 1.35, z), (2.2, 0.5, 5.8))
    s.box("Paper", (x, y + 1.62, z - 0.4), (1.8, 0.04, 4.6))
    s.box("WhiteTrim", (x, y + 1.75, z - 2.4), (1.6, 0.3, 0.9))
    s.collider((x, y + 0.9, z), (2.4, 1.8, 6.0), 0)
    rail = y + 8.0
    s.box("Steel", (x + 1.6, rail, z), (0.08, 0.08, 6.6))
    s.box("Steel", (x, rail, z + 3.3), (3.2, 0.08, 0.08))
    s.box("Fabric", (x + 1.6, y + 4.6, z - 0.9), (0.06, 6.6, 4.6))


def partition(s, a, b, y0, y1, mat="PlasterLight", door=None, glass=False, outer=None):
    """An inner wall from a to b; door = (u from a to its middle, width). glass: True for one
    window in the middle, "band" for glass all along it above waist height (an office you can
    see into). outer: the face on the wall's n side when it differs (the hall outside a room)."""
    ops = []
    if door:
        ops.append({"at": door[0], "w": door[1], "bottom": y0, "top": y0 + 8.4, "kind": "door", "frame": "DarkMetal",
                    "casing": 0.3})
    if glass == "band":
        length = math.dist(a, b)
        spans = [(0.4, length - 0.4)]
        if door:
            d0, d1 = door[0] - door[1] / 2 - 0.7, door[0] + door[1] / 2 + 0.7
            spans = [(0.4, d0), (d1, length - 0.4)]
        for u0, u1 in spans:
            if u1 - u0 >= 1.2:
                ops.append({"at": (u0 + u1) / 2, "w": u1 - u0, "bottom": y0 + 3.0, "top": y0 + 8.0, "kind": "window",
                            "frame": "DarkMetal", "glass": "Glass", "rows": 1, "see_through": True})
    elif glass:
        length = math.dist(a, b)
        ops.append({"at": length / 2 + (4 if door else 0), "w": min(8.0, length - 6), "bottom": y0 + 3.0,
                    "top": y0 + 8.0, "kind": "window", "frame": "DarkMetal", "glass": "Glass", "rows": 1,
                    "see_through": True})
    kit.wall(s, a, b, y1, thick=0.8, base=y0, core=mat, side_n=outer or mat, openings=ops)


def stairs_up(s, g, a, b, y0, y1, width, mat="Stone", rail=True):
    """A straight flight from a (at y0) to b (at y1) with handrails on both sides (solid: nobody
    steps through them off the side of the flight)."""
    city.stairs(s, g, a, b, y0, y1, width, mat, "ConcreteDark", step=0.9, guard=3.3 if rail else 0.0,
                guard_out=-0.2)
    if not rail:
        return
    run = math.dist(a, b)
    d = ((b[0] - a[0]) / run, (b[1] - a[1]) / run)
    n = g2.normal_left(d)
    for side in (1, -1):
        p = (a[0] + n[0] * side * (width / 2 - 0.2), a[1] + n[1] * side * (width / 2 - 0.2))
        q = (b[0] + n[0] * side * (width / 2 - 0.2), b[1] + n[1] * side * (width / 2 - 0.2))
        s.tube("Steel", (p[0], y0 + 3.2, p[1]), (q[0], y1 + 3.2, q[1]), 0.1, 8)
        for t in (0.0, 0.5, 1.0):
            x = p[0] + (q[0] - p[0]) * t
            z = p[1] + (q[1] - p[1]) * t
            y = y0 + (y1 - y0) * t
            s.tube("Steel", (x, y, z), (x, y + 3.2, z), 0.06, 6, caps=False)


def escalator(s, g, a, b, y0, y1, width=3.6):
    """A (still) escalator: metal steps between glass balustrades with black handrails (solid)."""
    city.stairs(s, g, a, b, y0, y1, width, "MetalFloor", "DarkMetal", step=0.7, guard=3.6, guard_out=0.25)
    run = math.dist(a, b)
    d = ((b[0] - a[0]) / run, (b[1] - a[1]) / run)
    n = g2.normal_left(d)
    for side in (1, -1):
        p = (a[0] + n[0] * side * (width / 2 + 0.25), a[1] + n[1] * side * (width / 2 + 0.25))
        q = (b[0] + n[0] * side * (width / 2 + 0.25), b[1] + n[1] * side * (width / 2 + 0.25))
        # One sloping glass panel along the flight (a face each way).
        pts = [(p[0], y0 + 0.6, p[1]), (q[0], y1 + 0.6, q[1]), (q[0], y1 + 3.5, q[1]), (p[0], y0 + 3.5, p[1])]
        s.polygon("Glass", pts)
        s.polygon("Glass", pts[::-1])
        s.tube("BlackTrim", (p[0], y0 + 3.6, p[1]), (q[0], y1 + 3.6, q[1]), 0.14, 8)


def prop_row(s, key, a, b, count, rot, y=0.0):
    for k in range(count):
        t = (k + 0.5) / count
        s.prop(key, a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, rot, 1.0, y)


def hall_sign(s, x, y, z, rot, w, h, text, bg=(24, 26, 32), fg=(250, 214, 70)):
    """A hanging sign board in a hall, lit from inside."""
    s.box("BlackTrim", (x, y, z), (w + 0.4, h + 0.4, 0.6), rot)
    a = math.radians(rot)
    for side in (1, -1):
        fx, fz = x - math.sin(a) * side * 0.35, z - math.cos(a) * side * 0.35
        s.sign((fx, y, fz), rot if side > 0 else rot + 180, w, h, text, "GothamBlack", fg, bg, glow=None)
    s.tube("DarkMetal", (x, y + h / 2, z), (x, CEIL, z), 0.08, 6)


# The station hall ------------------------------------------------------------------------------------


_POSTS = set()


def screen(s, a, b, h=8.0):
    """A tall glass screen from a to b (x, z), solid to its full height: the fences of a station's
    paid area. Square steel posts about every three studs (one post where two screens meet), a
    steel kick-plate along its foot and a rail along its top, the glass between."""
    length = math.dist(a, b)
    t = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    rot = g2.rot_of(t)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    rail = 0.24
    count = max(1, round(length / 2.8))
    for k in range(count + 1):
        u = length * k / count
        p = (a[0] + t[0] * u, a[1] + t[1] * u)
        key = (round(p[0], 1), round(p[1], 1))
        if key in _POSTS:
            continue
        _POSTS.add(key)
        s.box("Steel", (p[0], (h - rail) / 2, p[1]), (0.3, h - rail, 0.3), rot, skip=("-y", "+y"))
        s.box("Steel", (p[0], h + 0.04, p[1]), (0.38, 0.08, 0.38), rot)
    s.box("Steel", (mid[0], 0.25, mid[1]), (length, 0.5, 0.22), rot, skip=("-y",))
    s.box("Steel", (mid[0], h - rail / 2, mid[1]), (length, rail, 0.3), rot)
    s.box("Glass", (mid[0], (0.5 + h - rail) / 2, mid[1]), (length, h - rail - 0.5, 0.06), rot,
          skip=("-y", "+y"))
    s.collider((mid[0], h / 2, mid[1]), (length, h, 0.4), rot, True, None)


def station_hall(s, g):
    b = building("station")
    _POSTS.clear()
    # Entrances on the plaza side (east): three wide doors in a glass front.
    east = edge_towards(b["poly"], (1, 0))
    # The hall has a look of its own (the metro's, below), and the stairs down need no opening above.
    shell(s, g, b, {east: [(-12.5, 8.0), (5.5, 8.0), (23.5, 8.0)]}, inside="TileMetroGrey", floor="TileMetroFloor",
          outside="Concrete", storefront=(east,), name="the station hall", holes=[P.HALL_HOLE], ceiling="Ceiling",
          look=False)
    # The ticket gates, facing the entrances, and behind them the paid landing that leads straight
    # onto flight 1 of the stairs (station.py). Tall glass screens close the landing's sides and
    # run round the opening over flight 1.
    px0, px1, pz0, pz1 = P.PAID
    hx0, hx1 = min(x for x, _ in P.HALL_HOLE), max(x for x, _ in P.HALL_HOLE)
    hz0, hz1 = min(z for _, z in P.HALL_HOLE), max(z for _, z in P.HALL_HOLE)
    for z in P.GATES_Z:
        s.prop("TicketGate", P.GATE_X, z, -90)
    for z in (pz0, pz1):
        screen(s, (px0, z), (px1, z))
    screen(s, (px0, pz0), (px0, hz0))
    screen(s, (px0, hz1), (px0, pz1))
    screen(s, (hx0, hz0 - 0.2), (hx1, hz0 - 0.2))
    screen(s, (hx0, hz1 + 0.2), (hx1, hz1 + 0.2))
    screen(s, (hx0 - 0.2, hz0), (hx0 - 0.2, hz1))
    hall_sign(s, P.GATE_X + 1.0, 11.4, (pz0 + pz1) / 2, -90, 14.0, 1.8, "改札  GATES")
    hall_sign(s, hx1 - 1.5, 8.6, (hz0 + hz1) / 2, -90, 5.0, 1.4, "のりば  PLATFORMS  ↓")
    # Ticket machines against the glass front between the doors, facing into the hall; coin
    # lockers along the south wall; the clock over the concourse in front of the gates.
    for z in (-73.9, -69.8, -55.9, -51.8):
        s.prop("TicketMachine", -110.2, z, 90)
    prop_row(s, "CoinLockers", (-140.0, -27.4), (-126.0, -27.4), 2, 0)
    s.prop("StationClock", -112.0, -62.0, -90, 1.0, 10.0)
    # The CCTV room in the north-east corner, the lost-and-found office in the south-east.
    partition(s, (-124.0, -109.4), (-124.0, -96.0), 0.0, CEIL, "PlasterLight")
    partition(s, (-124.0, -96.0), (-108.6, -96.0), 0.0, CEIL, "PlasterLight", door=(4.0, 5.0), glass=True)
    s.station("Camera", "Station CCTV Room", -114.0, -106.4, 180, prop="StationCCTV")
    s.station("Phone", "Station Staff Phone", -112.0, -100.0, 90, prop="StationReception", spare=True)
    partition(s, (-124.0, -38.0), (-108.6, -38.0), 0.0, CEIL, "PlasterLight", door=(3.5, 5.0), glass=True)
    partition(s, (-124.0, -38.0), (-124.0, -25.6), 0.0, CEIL, "PlasterLight")
    s.station("Fingerprint", "Station Lost & Found", -114.0, -28.6, 0, prop="StationPrintKit")
    table(s, -120.0, -32.0, 4.0, 3.0, 0)
    # Fluorescent fittings: the concourse by the doors, the hall's west side, the paid landing, the
    # two offices.
    for x, z, rot in ((-112.0, -88.0, 90), (-112.0, -74.0, 90), (-112.0, -50.0, 90), (-112.0, -40.0, 90),
                      (-136.0, -100.0, 0), (-136.0, -84.0, 0), (-136.0, -46.0, 0), (-136.0, -34.0, 0),
                      (-118.5, -62.0, 90)):
        kit.tube_light(s, x, CEIL, z, length=7.0, rot=rot, range_=20, brightness=0.8)
    for z in (-103.0, -31.0):
        kit.tube_light(s, -116.0, CEIL, z, length=5.0, rot=0, range_=14, brightness=0.7)
    x0, z0, x1, z1 = g2.bbox(b["poly"])
    s.look_zone("TokyoDistrict_Under", (x0 + 0.5, -1.5, z0 + 0.5), (x1 - 0.5, CEIL + 0.5, z1 - 0.5))
    # Outside: a canopy over each door and the station's name over the front.
    e = edges_of(b["poly"])[east]
    for u in (30.0, 48.0, 66.0):
        x, z = e.at(u, 3.0)
        s.box("DarkMetal", (x, 11.2, z), (6.0, 0.5, 7.0), e.rot)
        s.collider((x, 11.2, z), (6.0, 0.5, 7.0), e.rot, True, None)  # (a roof, for the rain)
        # A downlight under each canopy, over the doors.
        s.box("PanelWarm", (x, 10.93, z), (2.0, 0.04, 2.0), e.rot)
        s.light("spot", (x, 10.6, z), (255, 226, 190), 20, 1.4, False, "Bottom", 100)
    # The name on a lit box across the front, over the canopies.
    bx, bz = e.at(e.length / 2, 0.35)
    s.box("BlackTrim", (bx, 12.6, bz), (40.6, 3.0, 0.7), e.rot)
    x, z = e.at(e.length / 2, 0.86)
    s.sign((x, 12.6, z), e.rot, 40.0, 2.4, "影ヶ丘駅  KAGEGAOKA STATION", "GothamBlack", (24, 24, 28),
           (244, 240, 230), glow=(244, 240, 230))


# The police box --------------------------------------------------------------------------------------


def koban(s, g):
    b = building("koban")
    poly = b["poly"]
    front = edge_towards(poly, (0.46, -0.89))
    edges = edges_of(poly)
    e = edges[front]
    shell(s, g, b, {front: [(3.5, 4.4)]}, inside="PlasterLight", floor="VinylClinic", outside="BrickDark",
          storefront=(front,), name="the police box")
    # Inside: the door to the right, the counter across the left, the print kit on the back wall
    # facing the room, a table with the sheet on it.
    back = e.n  # outward from the front
    def local(u, depth):
        return e.at(e.length / 2 + u, -depth)

    cx, cz = local(-3.5, 3.4)
    counter(s, cx, cz, e.rot + 180, 6.0, 1.8, top="Wood", body="WoodPanel")
    tx, tz = local(4.0, 8.4)
    top = table(s, tx, tz, 4.0, 2.6, e.rot)
    s.sheet(tx, top, tz)
    sx, sz = local(-2.2, 9.4)
    s.station("Fingerprint", "Police Box Print Kit", sx, sz, e.rot, prop="StationPrintKit")
    lx, lz = local(0.0, 6.0)
    lights(s, [(lx, lz)], brightness=1.2, range_=16, rot=e.rot)
    # Outside: the red lamp over the door, the name board, the tip box, the notice board.
    rx, rz = e.at(e.length / 2, 0.8)
    s.box("BlackMetal", (rx, 12.2, rz), (0.4, 0.8, 1.2), e.rot)
    s.box("NeonRed", (rx + back[0] * 0.6, 12.2, rz + back[1] * 0.6), (1.0, 1.0, 1.0), e.rot)
    s.light("point", (rx + back[0] * 1.4, 12.0, rz + back[1] * 1.4), (255, 60, 60), 14, 0.9)
    nx, nz = e.at(e.length / 2 - 4.2, 0.16)
    s.sign((nx, 10.8, nz), e.rot, 3.4, 1.2, "交番", "GothamBlack", (255, 255, 255), (30, 60, 140))
    nx, nz = e.at(e.length / 2 + 4.2, 0.16)
    s.sign((nx, 10.8, nz), e.rot, 3.4, 1.2, "POLICE", "GothamBlack", (255, 255, 255), (30, 60, 140))
    tbx, tbz = e.at(e.length / 2 - 3.5, 2.0)
    s.tip_box(tbx, tbz, e.rot)
    side = edges[edge_towards(poly, (-0.89, -0.46))]
    ox, oz = side.at(side.length / 2, 0.6)
    s.board(ox, 6.5, oz, side.rot, 10.0, 6.0)


# The department store --------------------------------------------------------------------------------


def dept_store(s, g):
    b = building("dept_store")
    poly = b["poly"]
    edges = edges_of(poly)
    tip = edge_towards(poly, (-0.8, 0.6))
    arcade = edge_towards(poly, (-0.3, -0.95))
    street = edge_towards(poly, (0.1, 1.0))
    doors = {arcade: [(-4.0, 6.0)], street: [(-8.0, 6.0)]}
    # Escalators up and a stair beside them, in the middle; the opening above them.
    hole = P.box(10.0, -86.8, 28.0, -71.6)
    shell(s, g, b, doors, inside="PlasterLight", floor="MarbleBlack", outside="Stone",
          storefront=(tip, arcade, street), name="the department store", stairwells=[hole], rooms=2)
    escalator(s, g, (6.0, -74.0), (28.0, -74.0), 0.0, UP)
    escalator(s, g, (28.0, -79.0), (6.0, -79.0), UP, 0.0)
    stairs_up(s, g, (8.0, -84.4), (28.0, -84.4), 0.0, UP, 4.2)
    upper_room(s, b, floor="WoodHerringbone", inside="Wallpaper", holes=[hole], name="the department store",
               ceiling="CeilingPlaster")
    for z in (-87.0, -71.4):
        kit.railing(s, [(10.0, z), (28.0, z)], h=3.6, mat="Gold", base=UP, glass="Glass")
    kit.railing(s, [(9.8, -87.0), (9.8, -71.4)], h=3.6, mat="Gold", base=UP, glass="Glass")
    # Ground floor: cosmetics counters and a mannequin along the east wall, the information desk.
    # The floor in front of the escalators and the stair (between them and the tip's door) stays
    # open: it is the only way onto them.
    for z in (-84.0, -77.0):
        s.prop("DisplayCase", 44.5, z, 90)
    s.prop("Mannequin", 44.8, -71.2, -90)
    s.prop("Mannequin", 40.0, -90.0, 150)
    s.station("Phone", "Store Info Desk", 38.0, -70.2, 180, prop="StationReception", spare=True)
    lights(s, [(-2.0, -76.0), (16.0, -69.4), (17.0, -88.0), (38.0, -84.0), (40.0, -70.0)], brightness=1.4,
           color=(255, 240, 220))
    # First floor: clothes, mannequins, the cash desk, and the security office at the back (the
    # way from the stairs to its door kept clear).
    s.prop("ClothesRack", -3.0, -75.5, 25, 1.0, UP)
    s.prop("Mannequin", 1.5, -80.5, 150, 1.0, UP)
    top = counter(s, 34.5, -76.0, 90, 7.0, y=UP)
    s.sheet(34.5, top, -77.0)
    partition(s, (36.0, -92.4), (36.0, -66.0), UP, UP + CEIL, "PlasterGrey", door=(7.8, 5.0), glass=True,
              outer="Wallpaper")
    s.station("Camera", "Store Security Office", 43.5, -84.0, 90, y=UP, prop="StationCCTV")
    lights(s, [(-2.0, -76.0), (12.0, -69.5), (22.0, -88.2), (33.0, -80.0)], y=UP + CEIL - 1.0, brightness=1.3,
           color=(255, 240, 220))
    lights(s, [(42.0, -84.0)], y=UP + CEIL - 1.0, brightness=1.0, range_=14, color=COOL)


# The shopping street's shops -------------------------------------------------------------------------


def drugstore(s, g):
    """The drugstore, and up a stair at its back the clinic (a common pairing in Tokyo)."""
    b = building("arcade_s1")
    front = edge_towards(b["poly"], (0, -1))
    # The opening ends where the top step does: the landing past it is solid floor.
    hole = P.box(58.5, -84.2, 71.0, -80.2)
    shell(s, g, b, {front: [(2.0, 7.0)]}, inside="PlasterLight", floor="Terrazzo", outside="FacadeTileGrey",
          storefront=(front,), name="the drugstore", stairwells=[hole], rooms=2, ceiling="Ceiling")
    # A row of shelves along the front, the floor to the foot of the stair left open (the flight
    # starts clear of the west wall, so there is room to step onto it).
    s.prop("StoreShelf", 56.0, -92.4, 180)
    s.station("Forensics", "Drugstore Dispensary", 70.0, -88.5, 90, prop="StationLabBench")
    stairs_up(s, g, (53.0, -82.2), (71.0, -82.2), 0.0, UP, 3.6)
    lights(s, [(53.0, -89.0), (63.0, -89.0), (72.0, -90.0)], color=COOL, brightness=1.4)
    upper_room(s, b, floor="VinylClinic", inside="PlasterLight", holes=[hole], name="the clinic", ceiling="Ceiling")
    kit.railing(s, [(58.3, -80.2), (58.3, -84.4), (71.0, -84.4)], h=3.6, mat="Steel", base=UP)
    for x in (50.8, 53.2, 55.6):
        s.prop("Chair", x, -82.6, 0, 1.0, UP)
    for x in (60.4, 64.2):
        exam_bed(s, x, -90.6, UP)
    counter(s, 54.0, -90.5, 180, 7.0, y=UP, top="WhiteTrim", body="PlasterLight")
    s.station("Forensics", "Clinic Lab", 70.0, -92.0, 180, y=UP, prop="StationLabBench")
    lights(s, [(54.0, -88.0), (66.0, -90.0)], y=UP + CEIL - 1.0, color=COOL, brightness=1.4)


def ramen_clinic(s, g):
    b = building("arcade_s2")
    front = edge_towards(b["poly"], (0, -1))
    shell(s, g, b, {front: [(-4.0, 5.0)]}, inside="WoodPanel", floor="WoodFloorDark", outside="BrickRed",
          storefront=(front,), name="the ramen bar", ceiling="CeilingSlats")
    # The bar: a counter with stools, the meal-ticket machine by the door, the kitchen behind
    # (room to walk behind the counter to the pass).
    s.prop("RamenCounter", 90.5, -87.0, 180)
    for x in (85.5, 88.0, 90.5, 93.0, 95.5):
        s.prop("BarStool", x, -89.6, 0)
    s.prop("MealTicketMachine", 83.0, -93.0, 180)
    s.box("Steel", (90.5, 1.6, -81.2), (12.0, 3.2, 2.4), 0)
    s.collider((90.5, 1.6, -81.2), (12.0, 3.2, 2.4), 0, True, "Steel")
    s.sheet(88.0, 3.25, -81.4)
    lights(s, [(86.0, -87.0), (94.0, -85.0)], brightness=1.3)


def game_centre(s, g):
    b = building("arcade_n2")
    front = edge_towards(b["poly"], (0, 1))
    shell(s, g, b, {front: [(0.0, 7.0)]}, inside="PlasterDark", floor="CarpetNavy", outside="PlasterDark",
          storefront=(front,), name="the game centre", ceiling="CeilingPlasterDark")
    for k, x in enumerate((35.0, 39.2, 43.4)):
        s.prop("ClawMachine", x, -111.5, 0 if k % 2 else 180)
    s.prop("ClawMachine", 51.3, -113.0, 90)
    for x in (33.0, 37.0, 41.0):
        s.prop("ArcadeCabinet", x, -119.5, 180)
    partition(s, (45.6, -127.0), (45.6, -119.5), 0.0, CEIL, "PlasterGrey", glass="band")
    partition(s, (45.6, -119.5), (53.8, -119.5), 0.0, CEIL, "PlasterGrey", door=(3.2, 4.5), glass="band")
    s.station("Camera", "Game Centre Office", 50.4, -124.8, 180, prop="StationCCTV", spare=True)
    lights(s, [(38.0, -114.0), (48.0, -114.0), (42.0, -121.0)], color=(220, 200, 255), brightness=1.2)
    lights(s, [(50.0, -125.0)], brightness=0.9, range_=12)


def konbini(s, g):
    b = building("konbini_block")
    front = edge_towards(b["poly"], (0.1, -1))
    shell(s, g, b, {front: [(9.0, 6.0)]}, inside="PlasterLight", floor="TileWhite", outside="FacadeTile",
          storefront=(front,), name="the konbini", ceiling="Ceiling")
    # Counter by the door, three rows of shelves, fridges along the back wall, the back office.
    s.prop("ShopCounter", 40.0, -38.5, 180)
    for x in (24.0, 31.0):
        s.prop("StoreShelf", x, -32.0, 90)
    s.prop("DrinkFridge", 24.0, -20.2, 180)
    s.prop("DrinkFridge", 32.5, -20.2, 180)
    partition(s, (41.0, -27.0), (41.0, -17.6), 0.0, CEIL, "PlasterGrey", glass="band")
    partition(s, (41.0, -27.0), (50.6, -27.0), 0.0, CEIL, "PlasterGrey", door=(3.0, 4.0), glass="band")
    s.station("Camera", "Konbini Back Office", 45.6, -20.2, 0, prop="StationCCTV", spare=True)
    lights(s, [(26.0, -40.0), (36.0, -40.0), (26.0, -30.0), (36.0, -30.0), (30.0, -22.0)], color=COOL,
           brightness=1.5)
    lights(s, [(45.6, -23.0)], brightness=1.0, range_=12)


# Across the river --------------------------------------------------------------------------------------


def karaoke(s, g):
    b = building("karaoke")
    front = edge_towards(b["poly"], (-1, 0))
    river = edge_towards(b["poly"], (0, -1))
    hole = P.box(88.0, 93.2, 100.5, 97.2)
    shell(s, g, b, {front: [(-6.0, 6.0)], river: [(0.0, 5.0)]}, inside="Wallpaper", floor="CarpetRed",
          outside="PlasterDark", storefront=(front,), name="the karaoke lobby", stairwells=[hole], rooms=2,
          ceiling="CeilingPlasterDark")
    s.station("Phone", "Karaoke Front Desk", 104.0, 80.0, 90, prop="StationReception")
    s.prop("Sofa", 86.0, 69.0, 180)
    s.prop("Plant", 81.0, 68.4, 0)
    stairs_up(s, g, (82.0, 95.2), (100.5, 95.2), 0.0, UP, 3.6)
    upper_room(s, b, floor="CarpetPurple", inside="Wallpaper", holes=[hole], name="the karaoke rooms",
               ceiling="CeilingPlasterDark")
    kit.railing(s, [(100.5, 93.0), (88.0, 93.0), (88.0, 97.2)], h=3.6, mat="Steel", base=UP)
    lights(s, [(88.0, 74.0), (98.0, 84.0), (88.0, 88.0)], brightness=1.2, color=(255, 190, 220))
    # Upstairs: a corridor along the west, rooms and the monitor room off it.
    for z0, z1 in ((66.3, 73.0), (73.0, 81.0), (81.0, 89.0)):
        partition(s, (86.0, z0), (86.0, z1), UP, UP + CEIL, "Wallpaper", door=(4.0, 4.2))
        partition(s, (86.0, z1), (106.0, z1), UP, UP + CEIL, "Wallpaper")
    for z in (69.0, 77.0):
        s.prop("Sofa", 102.0, z, 90, 1.0, UP)
        table(s, 96.0, z, 4.0, 3.0, 90, y=UP)
    s.station("Camera", "Hotel Monitor Room", 96.0, 83.0, 180, y=UP, prop="StationCCTV")
    lights(s, [(82.0, 70.0), (82.0, 86.0), (96.0, 69.0), (96.0, 77.0), (96.0, 85.0)], y=UP + CEIL - 1.0,
           brightness=1.0, color=(255, 170, 220), range_=14)


def laundromat(s, g):
    b = building("laundromat")
    front = edge_towards(b["poly"], (-1, 0))
    shell(s, g, b, {front: [(0.0, 6.0)]}, inside="TileMetroGrey", floor="TileChecker", outside="PlasterLight",
          storefront=(front,), name="the laundromat")
    prop_row(s, "Washer", (135.3, 69.0), (135.3, 89.0), 6, 90)
    prop_row(s, "DryerStack", (120.0, 91.3), (132.0, 91.3), 4, 0)
    top = table(s, 126.0, 80.0, 6.0, 3.0, 90)
    s.sheet(126.0, top, 79.0)
    s.prop("Bench", 120.0, 70.5, 180)
    s.station("Phone", "Laundromat Payphone", 128.0, 69.0, 180, prop="StationPhoneBooth")
    lights(s, [(122.0, 74.0), (130.0, 74.0), (122.0, 86.0), (130.0, 86.0)], color=COOL, brightness=1.4)


def izakaya(s, g):
    b = building("ya_s2")
    front = edge_towards(b["poly"], (0, 1))
    shell(s, g, b, {front: [(0.0, 4.4)]}, inside="WoodPanel", floor="WoodFloorDark", outside="WoodPanel",
          name="the izakaya", ceiling="CeilingSlats")
    top = counter(s, -85.4, 82.4, 180, 6.0, d=2.2, top="Wood", body="WoodPanel")
    s.sheet(-86.0, top, 82.2)
    for x in (-87.6, -85.4, -83.2):
        s.prop("BarStool", x, 85.2, 0)
    partition(s, (-89.4, 80.2), (-77.6, 80.2), 0.0, CEIL, "WoodPanel", door=(9.0, 3.6))
    s.prop("BeerCrates", -87.4, 77.2, 90)
    s.prop("BeerCrates", -87.4, 77.2, 90, 1.0, 3.48)
    s.prop("Crate", -84.4, 76.6, 15, 0.6)
    lights(s, [(-83.5, 84.0)], brightness=1.2, range_=14, color=(255, 200, 150))
    lights(s, [(-84.0, 76.0)], brightness=0.8, range_=10, color=(255, 200, 150))


def build(s, g):
    station_hall(s, g)
    koban(s, g)
    dept_store(s, g)
    drugstore(s, g)
    ramen_clinic(s, g)
    game_centre(s, g)
    konbini(s, g)
    karaoke(s, g)
    laundromat(s, g)
    izakaya(s, g)
