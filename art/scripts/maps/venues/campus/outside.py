"""Where the campus ends, and Kagegaoka beyond it under snow.

- The wall: where no building stands on the edge, a brick wall closes the campus. It is solid
  on the north and west; on the street sides (south and east) it is a low wall with iron
  railings, so the street shows through. Snow lies on its coping. The red gate and the iron
  east gate open onto the streets.
- Outside, both streets run on past the campus in the snow: parked cars, a bus stop, a lit
  konbini, poles and their wires, car lights streaming by, a patrol car at the gate.
- Round it all, the city's blocks with lit windows and snowy roofs out to the haze. On the
  skyline to the north-east stands the Kagegaoka Central Tower: its 38th and 39th floors lit
  (the Agency, working late) and its aircraft lights blinking like its neighbours'.
- A dark floor lies under everything and a safety net stands behind the outermost walls, so
  nothing can be reached and there is never a void to see.

It is all meshes and effects past the wall (no colliders out there but the net), in flat
colours or cheap textures. Long strips are cut into pieces no longer than 400 studs, and
nothing reaches more than 1400 studs north (the lobby is built 3000 studs that way)."""

import math
import random

from maps import buildings, city
from maps import geo2d as g2
from maps.venues.campus import plan as P

X0, Z0, X1, Z1 = P.X0, P.Z0, P.X1, P.Z1
FAR = 700.0
SKIRT = 1400.0
TILE = 700.0
UNDER_Y = -45.0
SKYLINE = 420.0
SOUTH_ST = (Z1 + 2.0, Z1 + 30.0)  # the street along the south wall: its near and far kerbs
EAST_ST = (X1 + 2.0, X1 + 26.0)
TOWER = (560.0, -700.0, 60.0, 52.0)  # the Kagegaoka Central Tower: centre x, z, width, depth
TOWER_TOP = 486.0


def cuts(a, b, step=400.0):
    count = max(1, math.ceil((b - a) / step))
    return [(a + (b - a) * k / count, a + (b - a) * (k + 1) / count) for k in range(count)]


# The wall ------------------------------------------------------------------------------------------------


def solid_wall(s, a, b, h=8.0):
    """A plain brick wall on the boundary, stone piers and coping, snow along the top."""
    length = math.dist(a, b)
    d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    rot = g2.rot_of(d)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    s.box("BrickDark", (mid[0], h / 2, mid[1]), (length, h, 1.4), rot)
    s.box("Stone", (mid[0], h + 0.2, mid[1]), (length + 0.2, 0.4, 1.8), rot)
    s.box("Snow", (mid[0], h + 0.5, mid[1]), (length + 0.1, 0.2, 1.6), rot, skip=("-y",))
    count = max(1, round(length / 8.0))
    for k in range(count + 1):
        p = (a[0] + d[0] * length * k / count, a[1] + d[1] * length * k / count)
        s.box("Stone", (p[0], (h + 1.0) / 2, p[1]), (1.8, h + 1.0, 2.0), rot)
    s.collider((mid[0], 20.0, mid[1]), (length, 40.0, 1.4), rot, True, "BrickDark")


def railing_wall(s, a, b, base=3.4, top=9.0):
    """A low brick wall with iron railings over it (the street shows through), stone piers."""
    length = math.dist(a, b)
    d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    rot = g2.rot_of(d)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    s.box("BrickRed", (mid[0], base / 2, mid[1]), (length, base, 1.4), rot)
    s.box("Stone", (mid[0], base + 0.15, mid[1]), (length + 0.2, 0.3, 1.7), rot)
    s.box("Snow", (mid[0], base + 0.38, mid[1]), (length, 0.16, 1.5), rot, skip=("-y",))
    for yy in (base + 0.9, top - 0.4):
        s.box("BlackMetal", (mid[0], yy, mid[1]), (length, 0.14, 0.14), rot)
    bars = max(2, round(length / 0.9))
    for k in range(bars + 1):
        p = (a[0] + d[0] * length * k / bars, a[1] + d[1] * length * k / bars)
        s.box("BlackMetal", (p[0], (base + top) / 2 + 0.3, p[1]), (0.09, top - base + 0.6, 0.09), rot)
    count = max(1, round(length / 10.0))
    for k in range(count + 1):
        p = (a[0] + d[0] * length * k / count, a[1] + d[1] * length * k / count)
        s.box("Stone", (p[0], (top + 1.0) / 2, p[1]), (1.6, top + 1.0, 1.8), rot)
        s.box("Snow", (p[0], top + 1.08, p[1]), (1.6, 0.16, 1.8), rot, skip=("-y",))
    s.collider((mid[0], base / 2, mid[1]), (length, base, 1.4), rot, True, "BrickRed")
    s.collider((mid[0], (base + 40.0) / 2, mid[1]), (length, 40.0 - base, 1.0), rot, False, None)


def walls(s):
    # North: the gaps either side of the auditorium.
    for x0, x1 in ((P.LAW[2], P.AUDITORIUM[0]), (P.AUDITORIUM[2], P.LIBRARY[0])):
        solid_wall(s, (x0, Z0 + 0.7), (x1, Z0 + 0.7))
    # West: from Law & Letters to the club house, past the hollow.
    solid_wall(s, (X0 + 0.7, P.LAW[3]), (X0 + 0.7, P.CLUB[1]))
    s.box("Stone", (X0 + 0.7, P.HOLLOW_Y / 2, (P.HOLLOW[1] + P.HOLLOW[3]) / 2), (1.4, -P.HOLLOW_Y, P.HOLLOW[3] - P.HOLLOW[1]))
    # East: from the library to the science building, the iron gate in the middle.
    g0, g1 = P.EAST_GATE
    railing_wall(s, (X1 - 0.7, P.LIBRARY[3]), (X1 - 0.7, g0 - 1.0))
    railing_wall(s, (X1 - 0.7, g1 + 1.0), (X1 - 0.7, P.SCIENCE[1]))
    east_gate(s, g0, g1)
    # South: the alley's end, either side of the red gate, the gate plaza.
    railing_wall(s, (P.CLUB[2], Z1 - 0.7), (P.CAFETERIA[0], Z1 - 0.7))
    railing_wall(s, (P.CAFETERIA[2], Z1 - 0.7), (P.GATE[0] - 1.4, Z1 - 0.7))
    railing_wall(s, (P.GATE[2] + 1.4, Z1 - 0.7), (P.SCIENCE[0], Z1 - 0.7))


def east_gate(s, z0, z1):
    """The iron east gate, shut, between two brick piers with lamps; police tape across it."""
    x = X1 - 0.7
    for z in (z0 - 1.0, z1 + 1.0):
        s.box("BrickRed", (x, 5.5, z), (2.4, 11.0, 2.4), collide=True)
        s.box("Stone", (x, 11.3, z), (2.8, 0.6, 2.8))
        s.box("Snow", (x, 11.7, z), (2.6, 0.2, 2.6), skip=("-y",))
        s.box("NeonWarm", (x - 1.3, 8.6, z), (0.1, 0.9, 0.7))
        s.light("point", (x - 2.2, 8.6, z), (255, 210, 150), 18, 0.9)
    bars = round((z1 - z0) / 0.8)
    for k in range(bars + 1):
        z = z0 + (z1 - z0) * k / bars
        s.box("BlackMetal", (x, 4.8, z), (0.1, 9.6 + (0.8 if k % 2 else 0.0), 0.1))
    for yy in (1.0, 5.0, 9.0):
        s.box("BlackMetal", (x, yy, (z0 + z1) / 2), (0.16, 0.2, z1 - z0))
    s.prop("PoliceTape", x - 0.6, (z0 + z1) / 2, 90, (z1 - z0) / 8.4, 3.8)
    s.collider((x, 20.0, (z0 + z1) / 2), (1.0, 40.0, z1 - z0), 0, False, None)


# The streets and the city -------------------------------------------------------------------------------


def streets(s, g, rng):
    # Ground as far as anyone can see, in snow, and the dark floor under everything.
    ring = P.box(-FAR, -FAR, FAR, FAR)
    for piece in g2.subtract_all([g2.ccw(ring)], [g2.ccw(P.box(X0, Z0, X1, Z1))]):
        for c0, c1 in cuts(g2.bbox(piece)[0], g2.bbox(piece)[2]):
            for d0, d1 in cuts(g2.bbox(piece)[1], g2.bbox(piece)[3]):
                part = g2.intersect(g2.ccw(piece), g2.ccw(P.box(c0, d0, c1, d1)))
                if part and abs(g2.area(part)) > 1:
                    g.add(part, "Snow", -0.03, -1, None, None)
    for x0, z0, x1, z1 in tiles(-SKIRT, -SKIRT, SKIRT, SKIRT, TILE):
        if not (-FAR <= x0 and x1 <= FAR and -FAR <= z0 and z1 <= FAR):
            for piece in g2.subtract_all([g2.ccw(P.box(x0, z0, x1, z1))], [g2.ccw(ring)]):
                city.up_face(s, "CoreDark", piece, -0.05)
        city.up_face(s, "CoreDark", P.box(x0, z0, x1, z1), UNDER_Y)
    # The south street and the east street: slush on the road, snowy pavements.
    (sn, sf), (en, ef) = SOUTH_ST, EAST_ST
    for a, b in cuts(-FAR, FAR):
        g.add(P.box(a, sn + 4.0, b, sf - 4.0), "Asphalt", 0.0, 4, None, None)
        g.add(P.box(a, sn, b, sn + 4.0), "SnowPath", 0.0, 3, None, None)
        g.add(P.box(a, sf - 4.0, b, sf), "SnowPath", 0.0, 3, None, None)
    for a, b in cuts(-FAR, sn):
        g.add(P.box(en + 4.0, a, ef - 4.0, b), "Asphalt", 0.0, 4, None, None)
        g.add(P.box(en, a, en + 4.0, b), "SnowPath", 0.0, 3, None, None)
        g.add(P.box(ef - 4.0, a, ef, b), "SnowPath", 0.0, 3, None, None)
    city.dashes(s, [(-FAR, (sn + sf) / 2), (FAR, (sn + sf) / 2)], dash=3, gap=5, w=0.3)
    city.dashes(s, [((en + ef) / 2, -FAR), ((en + ef) / 2, sn)], dash=3, gap=5, w=0.3)
    # Street lamps down both streets, on the far kerb.
    for x in range(-260, 300, 36):
        street_lamp(s, float(x), sf - 1.2, (0, -1))
    for z in range(-300, 100, 36):
        street_lamp(s, ef - 1.2, float(z), (-1, 0))
    # Parked cars under snow, the bus stop, the konbini across from the gate, the patrol car.
    for x, key in ((-120.0, "Car"), (-104.0, "KeiTruck"), (36.0, "Taxi"), (70.0, "Car"), (112.0, "Car")):
        s.prop(key, x, sf - 6.5, -90)
        s.box("Snow", (x, 4.8 if key != "Car" else 3.6, sf - 6.5), (4.6, 0.3, 9.0), 90, skip=("-y",))
    s.prop("PoliceCar", -20.0, sn + 9.0, -80)
    for x in (-27.0, -13.0):
        s.prop("TrafficCone", x, sn + 5.0, rng.uniform(0, 90))
    s.prop("BusShelter", 60.0, sf + 3.4, 180)
    s.prop("BusStopSign", 70.0, sf + 1.0, 180)
    konbini(s, -40.0, sf + 2.0)
    for x in range(-240, 260, 40):
        s.prop("UtilityPole", float(x), sf + 1.4, 180)
    for z, key in ((-150.0, "Car"), (-60.0, "Taxi"), (60.0, "KeiTruck")):
        s.prop(key, ef - 6.5, z, 0)
    # Car lights streaming along both streets and the avenues further out.
    lanes = [(-FAR, (sn + sf) / 2 + 3.0, -90.0), (FAR, (sn + sf) / 2 - 3.0, 90.0), ((en + ef) / 2 - 3.0, -FAR, 180.0),
             ((en + ef) / 2 + 3.0, sn, 0.0), (-FAR, -360.0, -90.0), (FAR, 380.0, 90.0)]
    for k, (x, z, rot) in enumerate(lanes):
        s.emitter("traffic_tail" if k % 2 == 0 else "traffic_head", (x, 1.5, z), rot, (6.0, 1.0, 2 * FAR))


def street_lamp(s, x, z, over):
    s.box("DarkMetal", (x, 4.5, z), (0.35, 9.0, 0.35), skip=("-y",))
    head = (x + over[0] * 1.2, z + over[1] * 1.2)
    s.box("BlackMetal", (head[0], 9.1, head[1]), (1.6, 0.3, 0.8), g2.rot_of(over))
    s.box("NeonWarm", (head[0], 8.92, head[1]), (1.2, 0.06, 0.5), g2.rot_of(over), skip=("+y",))
    s.box("Snow", (head[0], 9.32, head[1]), (1.5, 0.14, 0.7), g2.rot_of(over), skip=("-y",))
    s.light("point", (head[0], 8.2, head[1]), (255, 200, 140), 26, 1.1)


def konbini(s, x, z):
    """The convenience store across the street from the gate: its lit front and sign."""
    w, d, h = 22.0, 18.0, 12.0
    s.box("ConcreteDark", (x, h / 2, z + d / 2), (w, h, d), skip=("-y",))
    s.box("WindowLit", (x, 4.2, z + 0.05), (w - 2.0, 6.4, 0.1))
    s.box("NeonCool", (x, 9.3, z + 0.03), (w - 1.0, 1.6, 0.1))
    s.sign((x, 9.3, z - 0.05), 180, w - 2.0, 1.2, "24H  カゲマート  KAGE MART", "GothamBlack", (40, 110, 70), None)
    s.light("point", (x, 4.0, z - 3.0), (230, 240, 255), 26, 1.2)


def tiles(x0, z0, x1, z1, size):
    out = []
    x = x0
    while x < x1:
        z = z0
        while z < z1:
            out.append((x, z, min(x + size, x1), min(z + size, z1)))
            z += size
        x += size
    return out


CLADS = ("CityFacade", "CityFacadeWarm", "CityFacade", "CityRoof")


def block(s, rng, lot, floors, lit):
    """A block beyond the wall, cheap: flat walls, its lit floors as window bands, snow on its
    roof. Returns the roof's height."""
    x0, z0 = lot[0]
    x1, z1 = lot[2]
    top = buildings.height(floors)
    clad = rng.choice(CLADS)
    for a, b, out in (((x0, z0), (x1, z0), (0, -1)), ((x1, z0), (x1, z1), (1, 0)), ((x1, z1), (x0, z1), (0, 1)),
                      ((x0, z1), (x0, z0), (-1, 0))):
        city.vquad(s, clad, a, b, 0.0, top + 1.2, out)
        length = math.dist(a, b)
        d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        for level in buildings.floor_levels(floors):
            if rng.random() > lit:
                continue
            u0 = rng.uniform(0.0, length * 0.5)
            u1 = min(length - 0.8, u0 + rng.uniform(length * 0.3, length))
            if u1 - u0 < 4:
                continue
            p = (a[0] + d[0] * u0 + out[0] * 0.08, a[1] + d[1] * u0 + out[1] * 0.08)
            q = (a[0] + d[0] * u1 + out[0] * 0.08, a[1] + d[1] * u1 + out[1] * 0.08)
            city.vquad(s, "WindowLit" if rng.random() < 0.65 else "WindowCool", p, q, level + 3.2, level + 9.0, out)
    city.up_face(s, "Snow", P.box(x0, z0, x1, z1), top + 1.2)
    return top


def far_city(s, rng):
    """Blocks with lit windows and snow on their roofs, filling every view past the wall."""
    keep_out = [P.box(X0 - 6, Z0 - 6, X1 + 6, Z1 + 6), P.box(-FAR, SOUTH_ST[0] - 1, FAR, SOUTH_ST[1] + 26),
                P.box(EAST_ST[0] - 1, -FAR, EAST_ST[1] + 26, SOUTH_ST[1] + 26)]
    x = -560.0
    while x < 560.0:
        w = rng.uniform(26, 42)
        z = -560.0
        while z < 560.0:
            d = rng.uniform(26, 42)
            lot = P.box(x + 2, z + 2, x + w - 2, z + d - 2)
            dist = max(abs(x + w / 2) - X1, abs(z + d / 2) - Z1)
            clear = not any(g2.intersect(lot, k) for k in keep_out)
            if clear and dist < SKYLINE:
                if dist < 80:
                    floors = rng.randint(3, 7)
                elif dist < 240:
                    floors = rng.randint(6, 16)
                else:
                    floors = rng.randint(14, 28)
                block(s, rng, lot, floors, 0.3 if dist < 240 else 0.18)
            z += d
        x += w
    # Past the south street and along the east street: a row of low shops and flats facing them.
    for a in range(-300, 300, 30):
        lot = P.box(float(a) + 1.0, SOUTH_ST[1] + 4.0, float(a) + 29.0, SOUTH_ST[1] + 24.0)
        if abs(a + 40) < 20:
            continue
        block(s, rng, lot, rng.randint(2, 5), 0.4)
    for a in range(-320, 90, 30):
        lot = P.box(EAST_ST[1] + 4.0, float(a) + 1.0, EAST_ST[1] + 24.0, float(a) + 29.0)
        block(s, rng, lot, rng.randint(2, 6), 0.4)


def agency_tower(s, rng):
    """The Kagegaoka Central Tower on the skyline, the Agency's two floors lit near its top, and
    its neighbours; every crown blinking red."""
    cx, cz, w, d = TOWER
    x0, z0, x1, z1 = cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2
    for a, b, out in (((x0, z0), (x1, z0), (0, -1)), ((x1, z0), (x1, z1), (1, 0)), ((x1, z1), (x0, z1), (0, 1)),
                      ((x0, z1), (x0, z0), (-1, 0))):
        city.vquad(s, "CityFacade", a, b, 0.0, TOWER_TOP, out)
        length = math.dist(a, b)
        dd = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        p = (a[0] + out[0] * 0.1, a[1] + out[1] * 0.1)
        q = (b[0] + out[0] * 0.1, b[1] + out[1] * 0.1)
        # The Agency's 38th and 39th floors, lit right across; the rest of the tower mostly dark.
        city.vquad(s, "WindowLit", p, q, 440.0, 452.0, out)
        city.vquad(s, "WindowCool", p, q, 454.0, 466.0, out)
        for level in range(20, 430, 12):
            if rng.random() < 0.12:
                u0 = rng.uniform(0, length * 0.6)
                u1 = min(length, u0 + rng.uniform(6, length * 0.4))
                pa = (a[0] + dd[0] * u0 + out[0] * 0.1, a[1] + dd[1] * u0 + out[1] * 0.1)
                pb = (a[0] + dd[0] * u1 + out[0] * 0.1, a[1] + dd[1] * u1 + out[1] * 0.1)
                city.vquad(s, "WindowCool", pa, pb, level + 3.0, level + 9.0, out)
    city.up_face(s, "CityRoof", P.box(x0, z0, x1, z1), TOWER_TOP)
    s.box("BlackMetal", (cx, TOWER_TOP + 8.0, cz), (w - 12.0, 16.0, d - 12.0), skip=("-y",))
    s.box("DarkMetal", (cx, TOWER_TOP + 36.0, cz), (1.6, 40.0, 1.6), skip=("-y",))
    s.blinker((cx, TOWER_TOP + 57.0, cz), (255, 40, 40), 1.6, 2.4, 0.0)
    for sx in (-1, 1):
        for sz in (-1, 1):
            s.blinker((cx + sx * w / 2, TOWER_TOP + 1.5, cz + sz * d / 2), (255, 40, 40), 2.2, 2.0, rng.uniform(0, 2.2))
    s.sign((cx, 470.0, z1 + 0.3), 180, 40.0, 5.0, "KAGEGAOKA CENTRAL TOWER", "GothamBold", (220, 226, 236), None)
    for k, (nx, nz, nw, nfloors) in enumerate(((380.0, -560.0, 48.0, 26), (700.0, -480.0, 52.0, 30),
                                               (-520.0, -620.0, 50.0, 24), (-640.0, 420.0, 46.0, 22),
                                               (640.0, 460.0, 50.0, 25))):
        lot = P.box(nx - nw / 2, nz - nw / 2, nx + nw / 2, nz + nw / 2)
        top = block(s, rng, lot, nfloors, 0.22)
        for sx in (-1, 1):
            s.blinker((nx + sx * nw / 2, top + 2.0, nz), (255, 40, 40), 2.0, 1.6, (k * 0.37) % 2.0)


def perimeter(s):
    """The safety net just outside the boundary, behind everything."""
    lo, hi = -40.0, 220.0
    mid = (lo + hi) / 2
    for x in (X0 - 1.0, X1 + 1.0):
        s.collider((x, mid, 0.0), (1.0, hi - lo, Z1 - Z0 + 4), 0, False, None)
    for z in (Z0 - 1.0, Z1 + 1.0):
        s.collider((0.0, mid, z), (X1 - X0 + 4, hi - lo, 1.0), 0, False, None)


def build(s, g):
    rng = random.Random(1717)
    walls(s)
    streets(s, g, rng)
    far_city(s, rng)
    agency_tower(s, rng)
    perimeter(s)
