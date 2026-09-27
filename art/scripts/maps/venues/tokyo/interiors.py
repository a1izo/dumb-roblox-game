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


def shell(s, g, b, doors, inside="PlasterLight", floor="TileWhite", outside=None, storefront=(), name=None,
          zone=True, holes=()):
    """Ground-floor walls round a building's footprint with doors ({edge index: [(u from the
    middle, width)]}) and shop windows on the storefront edges; the floor and the ceiling."""
    poly = b["poly"]
    outside = outside or "PlasterGrey"
    edges = edges_of(poly)
    for i, e in enumerate(edges):
        a = e.at(0, -0.5)
        c = e.at(e.length, -0.5)
        length = math.dist(a, c)
        ops = city.openings_for(length, doors.get(i, []), CEIL + 1.0, 0.0, storefront=i in storefront)
        kit.wall(s, a, c, UP, thick=1.0, base=0.0, core=outside, side_n=outside, side_s=inside, openings=ops,
                 trim_s={"base": "BlackTrim"})
    inner = grow(poly, -1.0)
    for piece in g2.subtract_all(g2.convex_pieces(inner), [g2.ccw(h) for h in holes]):
        city.up_face(s, floor, piece, 0.06)
        city.floor(s, piece, 0.06, 0.4, floor)
    for piece in g2.convex_pieces(inner):
        city.down_face(s, "Ceiling", piece, CEIL)
    if zone:
        s.zone("interior", inner, 0.0, name=name or b["name"])
    return edges


def upper_room(s, b, floor="CarpetGrey", inside="PlasterLight", holes=(), name=None):
    """The first floor up as a room: a slab (with holes for stairs), walls' inner faces and their
    colliders, a ceiling."""
    poly = b["poly"]
    inner = grow(poly, -1.0)
    pieces = g2.subtract_all(g2.convex_pieces(inner), [g2.ccw(h) for h in holes])
    for piece in pieces:
        city.up_face(s, floor, piece, UP)
        city.floor(s, piece, UP, 1.0, floor)
    for piece in g2.convex_pieces(inner):
        city.down_face(s, "Ceiling", piece, UP + CEIL - 1.0)
    for e in edges_of(inner):
        city.vquad(s, inside, e.a, e.b, UP, UP + 12.0, (-e.n[0], -e.n[1]))
        mid = e.at(e.length / 2, 0.5)
        s.collider((mid[0], UP + 6.0, mid[1]), (e.length + 1.0, 12.0, 1.0), e.rot, True, None)
    s.zone("interior", inner, UP, name=name or b["name"])


def lights(s, points, y=CEIL, color=WARM, w=4.0, d=1.6, brightness=1.3, range_=22, rot=0.0):
    """Ceiling panels, each with its light."""
    for x, z in points:
        kit.panel_light(s, x, y, z, w, d, color=color, range_=range_, brightness=brightness, rot=rot)


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


def partition(s, a, b, y0, y1, mat="PlasterLight", door=None, glass=False):
    """An inner wall from a to b; door = (u from a to its middle, width). glass: True for one
    window in the middle, "band" for glass all along it above waist height (an office you can
    see into)."""
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
    kit.wall(s, a, b, y1, thick=0.6, base=y0, core=mat, openings=ops)


def stairs_up(s, g, a, b, y0, y1, width, mat="Stone", rail=True):
    """A straight flight from a (at y0) to b (at y1) with handrails on both sides."""
    city.stairs(s, g, a, b, y0, y1, width, mat, "ConcreteDark", step=0.9)
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
    """A (still) escalator: metal steps between glass balustrades with black handrails."""
    city.stairs(s, g, a, b, y0, y1, width, "MetalFloor", "DarkMetal", step=0.7)
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


def screen(s, a, b, h=8.0):
    """A tall glass screen on a steel frame from a to b (x, z), solid to its full height: the
    fences of a station's paid area."""
    kit.railing(s, [a, b], h=h, mat="Steel", glass="Glass")
    length = math.dist(a, b)
    rot = g2.rot_of(((b[0] - a[0]) / length, (b[1] - a[1]) / length))
    s.collider(((a[0] + b[0]) / 2, h / 2, (a[1] + b[1]) / 2), (length, h, 0.4), rot, True, None)


def station_hall(s, g):
    b = building("station")
    # Entrances on the plaza side (east): three wide doors in a glass front.
    east = edge_towards(b["poly"], (1, 0))
    shell(s, g, b, {east: [(-12.5, 8.0), (5.5, 8.0), (23.5, 8.0)]}, inside="TileMetroGrey", floor="TileMetroFloor",
          outside="Concrete", storefront=(east,), name="the station hall", holes=[P.HALL_HOLE])
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
        s.prop("TicketMachine", -109.3, z, 90)
    prop_row(s, "CoinLockers", (-140.0, -27.4), (-126.0, -27.4), 2, 0)
    s.prop("StationClock", -112.0, -62.0, -90, 1.0, 10.0)
    # The CCTV room in the north-east corner, the lost-and-found office in the south-east.
    partition(s, (-124.0, -109.4), (-124.0, -96.0), 0.0, CEIL, "PlasterLight")
    partition(s, (-124.0, -96.0), (-108.6, -96.0), 0.0, CEIL, "PlasterLight", door=(4.0, 5.0), glass=True)
    s.station("Camera", "Station CCTV Room", -114.0, -106.4, 180, prop="StationCCTV")
    s.station("Phone", "Station Staff Phone", -120.0, -100.0, -90, prop="StationReception", spare=True)
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
        s.box("DarkMetal", (x, 11.2, z), (6.0, 0.5, 11.0), e.rot)
    x, z = e.at(e.length / 2, 1.0)
    s.sign((x, 12.6, z), e.rot, 40.0, 2.4, "影ヶ丘駅  KAGEGAOKA STATION", "GothamBlack", (24, 24, 28),
           (244, 240, 230), glow=(244, 240, 230))


# The police box --------------------------------------------------------------------------------------


def koban(s, g):
    b = building("koban")
    poly = b["poly"]
    front = edge_towards(poly, (0.46, -0.89))
    edges = edges_of(poly)
    e = edges[front]
    shell(s, g, b, {front: [(3.5, 4.4)]}, inside="PlasterLight", floor="TileWhite", outside="BrickDark",
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
    nx, nz = e.at(e.length / 2 - 4.2, 0.9)
    s.sign((nx, 10.8, nz), e.rot, 3.4, 1.2, "交番", "GothamBlack", (255, 255, 255), (30, 60, 140))
    nx, nz = e.at(e.length / 2 + 4.2, 0.9)
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
    doors = {tip: [(0.0, 6.0)], arcade: [(-4.0, 6.0)], street: [(-8.0, 6.0)]}
    shell(s, g, b, doors, inside="MarbleWhite", floor="MarbleWhite", outside="Stone",
          storefront=(tip, arcade, street), name="the department store")
    # Escalators up and a stair beside them, in the middle; the opening above them.
    escalator(s, g, (6.0, -74.0), (28.0, -74.0), 0.0, UP)
    escalator(s, g, (28.0, -79.0), (6.0, -79.0), UP, 0.0)
    stairs_up(s, g, (8.0, -84.4), (28.0, -84.4), 0.0, UP, 4.2)
    hole = P.box(5.0, -86.8, 28.0, -71.6)
    upper_room(s, b, floor="CarpetRed", inside="Wallpaper", holes=[hole], name="the department store")
    for z in (-87.0, -71.4):
        kit.railing(s, [(5.0, z), (28.0, z)], h=3.6, mat="Gold", base=UP, glass="Glass")
    kit.railing(s, [(4.8, -87.0), (4.8, -71.4)], h=3.6, mat="Gold", base=UP, glass="Glass")
    # Ground floor: cosmetics counters, mannequins by the doors, the information desk.
    for x, z, rot in ((-4.0, -76.0, 25), (0.0, -80.5, 25), (0.5, -71.5, 5)):
        s.prop("DisplayCase", x, z, rot)
    for x, z in ((8.0, -69.8), (22.0, -68.2)):
        s.prop("Mannequin", x, z, 180)
    s.prop("Mannequin", 40.0, -90.0, 150)
    s.station("Phone", "Store Info Desk", 38.0, -70.2, 180, prop="StationReception", spare=True)
    lights(s, [(-2.0, -76.0), (12.0, -78.0), (24.0, -80.0), (38.0, -84.0), (40.0, -70.0)], brightness=1.4,
           color=(255, 240, 220))
    # First floor: clothes, mannequins, the cash desk, and the security office at the back.
    for x, z, rot in ((-3.0, -75.5, 25), (34.0, -71.0, 5)):
        s.prop("ClothesRack", x, z, rot, 1.0, UP)
    for x, z in ((2.0, -72.5), (1.5, -81.0)):
        s.prop("Mannequin", x, z, 150, 1.0, UP)
    top = counter(s, 18.0, -67.6, 180, 7.0, y=UP)
    s.sheet(16.0, top, -67.4)
    partition(s, (36.0, -93.6), (36.0, -66.0), UP, UP + CEIL, "PlasterGrey", door=(9.0, 5.0), glass=True)
    s.station("Camera", "Store Security Office", 43.5, -84.0, 90, y=UP, prop="StationCCTV")
    lights(s, [(-2.0, -76.0), (12.0, -68.0), (22.0, -90.0), (33.0, -80.0)], y=UP + CEIL - 1.0, brightness=1.3,
           color=(255, 240, 220))
    lights(s, [(42.0, -84.0)], y=UP + CEIL - 1.0, brightness=1.0, range_=14, color=COOL)


# The shopping street's shops -------------------------------------------------------------------------


def drugstore(s, g):
    """The drugstore, and up a stair at its back the clinic (a common pairing in Tokyo)."""
    b = building("arcade_s1")
    front = edge_towards(b["poly"], (0, -1))
    shell(s, g, b, {front: [(2.0, 7.0)]}, inside="PlasterLight", floor="TileWhite", outside="FacadeTileGrey",
          storefront=(front,), name="the drugstore")
    s.prop("StoreShelf", 50.3, -89.5, -90)
    s.prop("StoreShelf", 56.0, -92.4, 180)
    s.station("Forensics", "Drugstore Dispensary", 74.9, -87.0, 90, prop="StationLabBench")
    stairs_up(s, g, (50.5, -82.2), (71.0, -82.2), 0.0, UP, 3.6)
    lights(s, [(53.0, -89.0), (63.0, -89.0), (72.0, -90.0)], color=COOL, brightness=1.4)
    upper_room(s, b, floor="TileWhite", inside="PlasterLight", holes=[P.box(58.5, -84.2, 72.0, -80.2)],
               name="the clinic")
    kit.railing(s, [(58.3, -80.2), (58.3, -84.4), (72.0, -84.4)], h=3.6, mat="Steel", base=UP)
    for x in (51.0, 54.0, 57.0):
        s.prop("BarStool", x, -83.0, 0, 1.0, UP)
    counter(s, 54.0, -90.5, 180, 7.0, y=UP, top="WhiteTrim", body="PlasterLight")
    s.station("Forensics", "Clinic Lab", 70.0, -92.6, 180, y=UP, prop="StationLabBench")
    lights(s, [(54.0, -88.0), (66.0, -90.0)], y=UP + CEIL - 1.0, color=COOL, brightness=1.4)


def ramen_clinic(s, g):
    b = building("arcade_s2")
    front = edge_towards(b["poly"], (0, -1))
    shell(s, g, b, {front: [(-4.0, 5.0)]}, inside="WoodPanel", floor="WoodFloorDark", outside="BrickRed",
          storefront=(front,), name="the ramen bar")
    # The bar: a counter with stools, the meal-ticket machine by the door, the kitchen behind.
    s.prop("RamenCounter", 90.5, -86.0, 180)
    for x in (85.5, 88.0, 90.5, 93.0, 95.5):
        s.prop("BarStool", x, -88.6, 0)
    s.prop("MealTicketMachine", 84.8, -93.0, 180)
    s.box("Steel", (90.5, 1.6, -81.2), (12.0, 3.2, 2.4), 0)
    s.collider((90.5, 1.6, -81.2), (12.0, 3.2, 2.4), 0, True, "Steel")
    s.sheet(88.0, 3.25, -81.4)
    lights(s, [(86.0, -87.0), (94.0, -85.0)], brightness=1.3)


def game_centre(s, g):
    b = building("arcade_n2")
    front = edge_towards(b["poly"], (0, 1))
    shell(s, g, b, {front: [(0.0, 7.0)]}, inside="PlasterDark", floor="CarpetGrey", outside="PlasterDark",
          storefront=(front,), name="the game centre")
    for k, x in enumerate((33.0, 37.3, 41.6)):
        s.prop("ClawMachine", x, -111.5, 0 if k % 2 else 180)
    s.prop("ClawMachine", 51.3, -113.0, 90)
    for x in (33.0, 37.0, 41.0):
        s.prop("ArcadeCabinet", x, -119.5, 180)
    partition(s, (46.0, -128.4), (46.0, -121.5), 0.0, CEIL, "PlasterGrey", glass="band")
    partition(s, (46.0, -121.5), (53.8, -121.5), 0.0, CEIL, "PlasterGrey", door=(2.8, 4.5), glass="band")
    s.station("Camera", "Game Centre Office", 50.0, -126.4, 180, prop="StationCCTV", spare=True)
    lights(s, [(38.0, -114.0), (48.0, -114.0), (42.0, -121.0)], color=(220, 200, 255), brightness=1.2)
    lights(s, [(50.0, -126.0)], brightness=0.9, range_=12)


def konbini(s, g):
    b = building("konbini_block")
    front = edge_towards(b["poly"], (0.1, -1))
    shell(s, g, b, {front: [(9.0, 6.0)]}, inside="PlasterLight", floor="TileWhite", outside="FacadeTile",
          storefront=(front,), name="the konbini")
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


# Across the river --------------------------------------------------------------------------------------


def karaoke(s, g):
    b = building("karaoke")
    front = edge_towards(b["poly"], (-1, 0))
    river = edge_towards(b["poly"], (0, -1))
    shell(s, g, b, {front: [(-6.0, 6.0)], river: [(0.0, 5.0)]}, inside="Wallpaper", floor="CarpetRed",
          outside="PlasterDark", storefront=(front,), name="the karaoke lobby")
    s.station("Phone", "Karaoke Front Desk", 104.0, 80.0, 90, prop="StationReception")
    s.prop("Sofa", 86.0, 69.0, 180)
    s.prop("Plant", 80.5, 67.0, 0)
    stairs_up(s, g, (82.0, 95.2), (100.5, 95.2), 0.0, UP, 3.6)
    upper_room(s, b, floor="CarpetGrey", inside="Wallpaper", holes=[P.box(88.0, 93.2, 101.0, 97.2)],
               name="the karaoke rooms")
    kit.railing(s, [(101.0, 93.0), (88.0, 93.0), (88.0, 97.2)], h=3.6, mat="Steel", base=UP)
    lights(s, [(88.0, 74.0), (98.0, 84.0), (88.0, 88.0)], brightness=1.2, color=(255, 190, 220))
    # Upstairs: a corridor along the west, rooms and the monitor room off it.
    for z0, z1 in ((65.0, 73.0), (73.0, 81.0), (81.0, 89.0)):
        partition(s, (86.0, z0), (86.0, z1), UP, UP + CEIL, "Wallpaper", door=(4.0, 4.2))
        partition(s, (86.0, z1), (106.0, z1), UP, UP + CEIL, "Wallpaper")
    for z in (69.0, 77.0):
        s.prop("Sofa", 102.0, z, -90, 1.0, UP)
        table(s, 96.0, z, 4.0, 3.0, 90, y=UP)
    s.station("Camera", "Hotel Monitor Room", 96.0, 83.0, 180, y=UP, prop="StationCCTV")
    lights(s, [(82.0, 70.0), (82.0, 86.0), (96.0, 69.0), (96.0, 77.0), (96.0, 85.0)], y=UP + CEIL - 1.0,
           brightness=1.0, color=(255, 170, 220), range_=14)


def laundromat(s, g):
    b = building("laundromat")
    front = edge_towards(b["poly"], (-1, 0))
    shell(s, g, b, {front: [(0.0, 6.0)]}, inside="TileWhite", floor="TileChecker", outside="PlasterLight",
          storefront=(front,), name="the laundromat")
    prop_row(s, "Washer", (135.3, 69.0), (135.3, 89.0), 6, 90)
    prop_row(s, "DryerStack", (120.0, 91.3), (132.0, 91.3), 4, 0)
    top = table(s, 126.0, 80.0, 6.0, 3.0, 90)
    s.sheet(126.0, top, 79.0)
    s.prop("Bench", 120.0, 70.5, 180)
    s.station("Phone", "Laundromat Payphone", 128.0, 68.4, 180, prop="StationPhoneBooth")
    lights(s, [(122.0, 74.0), (130.0, 74.0), (122.0, 86.0), (130.0, 86.0)], color=COOL, brightness=1.4)


def izakaya(s, g):
    b = building("ya_s2")
    front = edge_towards(b["poly"], (0, 1))
    shell(s, g, b, {front: [(0.0, 4.4)]}, inside="WoodPanel", floor="WoodFloorDark", outside="WoodPanel",
          name="the izakaya")
    top = counter(s, -83.5, 82.4, 180, 9.0, d=2.2, top="Wood", body="WoodPanel")
    s.sheet(-86.0, top, 82.2)
    for x in (-88.0, -85.5, -83.0, -80.5):
        s.prop("BarStool", x, 85.2, 0)
    partition(s, (-89.4, 80.2), (-77.6, 80.2), 0.0, CEIL, "WoodPanel", door=(9.0, 3.6))
    s.prop("DrinkFridge", -84.0, 76.5, 180)
    s.prop("BeerCrates", -79.6, 76.4, 0)
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
