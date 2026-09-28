"""What the windows show: Kagegaoka at night, 440 studs down. A grid of lit streets and blocks
runs out to the haze; the river winds through it with its lamps; the expressway crosses the north
on its viaduct; south-west lies the Tokyo District the players know (the station, the scramble
with the glass tower's giant screen). Round the Agency's tower stand its neighbours, as tall, their
aircraft lights blinking. Car lights stream along the avenues, rain runs down the glass, and now
and then a police helicopter sweeps its searchlight across the floors.

Nothing out here can be reached: it is all meshes and effects (no colliders), so the walk stays
inside the glass. Kept cheap: flat colours (no textures this far off), windows as lit bands, lamps
as flat quads; long strips are cut into pieces so no mesh grows past a Roblox part's size."""

import math
import random

from maps import buildings, city
from maps import geo2d as g2
from maps.venues.agency import plan as P

GY = P.STREET_Y  # street level far below
CITY = 1300.0  # the detailed city runs this far from the tower (the haze takes the rest)
FAR = 3400.0  # dark ground and a scatter of lights out to here...
FAR_N = 1450.0  # ...but only this far north: the lobby is built 3000 studs that way (Venues.luau)
PIECE = 400.0  # the longest strip drawn in one piece
PLAZA = (-150.0, -130.0, 150.0, 130.0)  # the tower's own plaza: nothing tall there
AVENUE_EVERY = 130.0
ROAD = 16.0

# Kagegaoka landmarks, south-west of the tower (local studs at street level).
SCRAMBLE = (-430.0, 420.0)
STATION = (-600.0, 400.0, 70.0, 150.0)  # centre x, z, width (x), length (z)
GLASS_TOWER = (-360.0, 330.0)
RIVER = [(-1300, 620), (-900, 580), (-500, 640), (-200, 600), (150, 660), (600, 620), (1300, 680)]
EXPRESSWAY_Z = -520.0

# The neighbouring towers: centre x, z, width, depth, floors (a floor 12 studs, from the street).
NEIGHBOURS = [(70.0, -330.0, 60.0, 50.0, 44), (340.0, -230.0, 50.0, 50.0, 38), (390.0, 130.0, 60.0, 60.0, 42),
              (230.0, 380.0, 50.0, 60.0, 34), (-390.0, -110.0, 60.0, 50.0, 40), (-250.0, -370.0, 50.0, 50.0, 46),
              (-150.0, 460.0, 44.0, 44.0, 30)]
CLADS = ("CityFacade", "CityFacadeWarm", "CityFacade", "CityRoof")


def cuts(a, b, step=PIECE):
    count = max(1, math.ceil((b - a) / step))
    return [(a + (b - a) * k / count, a + (b - a) * (k + 1) / count) for k in range(count)]


def flat(s, mat, x0, z0, x1, z1, y=GY):
    """An upward face over a rectangle, in pieces no longer than PIECE."""
    for a, b in cuts(x0, x1):
        for c, d in cuts(z0, z1):
            s.polygon(mat, [(a, y, d), (b, y, d), (b, y, c), (a, y, c)])


def in_rect(x, z, r, pad=0.0):
    return r[0] - pad <= x <= r[2] + pad and r[1] - pad <= z <= r[3] + pad


def river_z(x):
    for (ax, az), (bx, bz) in zip(RIVER, RIVER[1:]):
        if ax <= x <= bx:
            return az + (bz - az) * (x - ax) / (bx - ax)
    return RIVER[-1][1]


def dash(s, mat, x0, z0, x1, z1, y):
    s.polygon(mat, [(x0, y, z1), (x1, y, z1), (x1, y, z0), (x0, y, z0)])


def ground(s, rng):
    """The streets and blocks' ground, the river, lamp lines along every avenue."""
    lines = [-CITY + k * AVENUE_EVERY for k in range(int(2 * CITY / AVENUE_EVERY) + 1)]
    for x0, z0, x1, z1 in ((-FAR, -FAR_N, FAR, -CITY), (-FAR, CITY, FAR, FAR), (-FAR, -CITY, -CITY, CITY),
                           (CITY, -CITY, FAR, CITY)):
        flat(s, "CoreDark", x0, z0, x1, z1, GY - 0.5)
    flat(s, "CityGround", -CITY, -CITY, CITY, CITY, GY - 0.1)
    for c in lines:
        flat(s, "CityRoad", c - ROAD / 2, -CITY, c + ROAD / 2, CITY, GY)
        flat(s, "CityRoad", -CITY, c - ROAD / 2, CITY, c + ROAD / 2, GY + 0.02)
        for side in (-1, 1):
            o = c + side * (ROAD / 2 + 1.0)
            u = -CITY + rng.uniform(0, 20)
            while u < CITY:
                if not (abs(u) < 150 and abs(o) < 150):
                    lamp = "NeonOrange" if rng.random() < 0.7 else "NeonWarm"
                    dash(s, lamp, o - 0.6, u, o + 0.6, u + 3.0, GY + 0.1)
                    dash(s, lamp, u, o - 0.6, u + 3.0, o + 0.6, GY + 0.1)
                u += 26.0
    # The river: dark water between lamp-lit banks.
    for (ax, az), (bx, bz) in zip(RIVER, RIVER[1:]):
        steps = max(1, math.ceil((bx - ax) / PIECE))
        for k in range(steps):
            x0 = ax + (bx - ax) * k / steps
            x1 = ax + (bx - ax) * (k + 1) / steps
            z0, z1 = river_z(x0), river_z(x1)
            s.polygon("Water", [(x0, GY + 0.3, z0 + 40), (x1, GY + 0.3, z1 + 40), (x1, GY + 0.3, z1 - 40),
                                (x0, GY + 0.3, z0 - 40)])
        for off in (-43.0, 43.0):
            count = int(math.dist((ax, az), (bx, bz)) / 18)
            for k in range(count):
                t = k / count
                x = ax + (bx - ax) * t
                z = az + (bz - az) * t + off
                dash(s, "NeonWarm", x - 0.8, z - 0.8, x + 0.8, z + 0.8, GY + 0.5)
    # Far off, only a scatter of lights under the haze.
    for _ in range(900):
        x = rng.uniform(-FAR, FAR)
        z = rng.uniform(-FAR_N + 20.0, FAR)
        if abs(x) < CITY and abs(z) < CITY:
            continue
        dash(s, rng.choice(("NeonOrange", "WindowLit", "WindowCool")), x, z, x + rng.uniform(4, 14), z + 1.5, GY)


def faces_of(x0, z0, x1, z1):
    return (((x0, z0), (x1, z0), (0, -1)), ((x1, z0), (x1, z1), (1, 0)), ((x1, z1), (x0, z1), (0, 1)),
            ((x0, z1), (x0, z0), (-1, 0)))


def block(s, rng, x0, z0, x1, z1, floors, lit, clad=None):
    """A far building, cheap: its walls and roof, and lit floors as bands across some faces (the
    windows read as bands from this far up). Returns its roof height."""
    top = GY + buildings.height(floors)
    clad = clad or rng.choice(CLADS)
    for a, b, out in faces_of(x0, z0, x1, z1):
        city.vquad(s, clad, a, b, GY, top + 1.2, out)
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
            city.vquad(s, "WindowLit" if rng.random() < 0.65 else "WindowCool", p, q, GY + level + 3.2, GY + level + 9.0,
                       out)
    flat(s, "CityRoof", x0, z0, x1, z1, top + 1.2)
    return top


def tower(s, rng, x0, z0, x1, z1, floors, lit):
    """A tall neighbour, near enough to show its windows one by one on the floors at eye level
    (lit bands lower down, seen from far above). Returns its roof height."""
    top = GY + buildings.height(floors)
    for a, b, out in faces_of(x0, z0, x1, z1):
        city.vquad(s, "CityFacade", a, b, GY, top + 1.5, out)
        length = math.dist(a, b)
        d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        spans = buildings.bays(length, 6.0)
        for level in buildings.floor_levels(floors):
            if GY + level < -140:
                if rng.random() < lit:
                    p = (a[0] + out[0] * 0.08, a[1] + out[1] * 0.08)
                    q = (b[0] + out[0] * 0.08, b[1] + out[1] * 0.08)
                    city.vquad(s, "WindowCool", p, q, GY + level + 3.2, GY + level + 9.0, out)
                continue
            for u0, u1 in spans:
                if rng.random() > lit:
                    continue
                m = (u0 + u1) / 2
                p = (a[0] + d[0] * (m - 2.0) + out[0] * 0.08, a[1] + d[1] * (m - 2.0) + out[1] * 0.08)
                q = (a[0] + d[0] * (m + 2.0) + out[0] * 0.08, a[1] + d[1] * (m + 2.0) + out[1] * 0.08)
                city.vquad(s, "WindowLit" if rng.random() < 0.6 else "WindowCool", p, q, GY + level + 3.0,
                           GY + level + 9.4, out)
    flat(s, "CityRoof", x0, z0, x1, z1, top + 1.5)
    return top


def blocks(s, rng):
    """City blocks between the avenues: lots of buildings, lower near the tower, some taller ones
    further out; rooftop plant and the odd lit sign on top."""
    lines = [-CITY + k * AVENUE_EVERY for k in range(int(2 * CITY / AVENUE_EVERY) + 1)]
    for i in range(len(lines) - 1):
        for j in range(len(lines) - 1):
            x0, x1 = lines[i] + ROAD / 2 + 4, lines[i + 1] - ROAD / 2 - 4
            z0, z1 = lines[j] + ROAD / 2 + 4, lines[j + 1] - ROAD / 2 - 4
            cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
            if in_rect(cx, cz, PLAZA, 60) or abs(cz - river_z(cx)) < 70 or abs(cz - EXPRESSWAY_Z) < 70:
                continue
            if math.dist((cx, cz), SCRAMBLE) < 160 or math.dist((cx, cz), STATION[:2]) < 150:
                continue
            if any(math.dist((cx, cz), (n[0], n[1])) < 90 for n in NEIGHBOURS):
                continue
            dist = math.hypot(cx, cz)
            split = 2 if rng.random() < 0.5 else 4
            lots = ([(x0, z0, cx - 2, z1), (cx + 2, z0, x1, z1)] if split == 2 else
                    [(x0, z0, cx - 2, cz - 2), (cx + 2, z0, x1, cz - 2), (x0, cz + 2, cx - 2, z1), (cx + 2, cz + 2, x1, z1)])
            for lx0, lz0, lx1, lz1 in lots:
                floors = rng.randint(3, 9) if dist < 500 else rng.randint(5, 16)
                if rng.random() < 0.08:
                    floors = rng.randint(18, 26)
                top = block(s, rng, lx0, lz0, lx1, lz1, floors, 0.22 if dist > 800 else 0.32)
                roof(s, rng, lx0, lz0, lx1, lz1, top)


def roof(s, rng, x0, z0, x1, z1, top):
    """Rooftop plant (AC units), sometimes a lit sign or a helipad."""
    for _ in range(rng.randint(1, 2)):
        w, d = rng.uniform(3, 7), rng.uniform(3, 7)
        x = rng.uniform(x0 + w, x1 - w)
        z = rng.uniform(z0 + d, z1 - d)
        s.box("DarkMetal", (x, top + 2.6, z), (w, 2.8, d), skip=("-y",))
    r = rng.random()
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    if r < 0.12:
        s.box(rng.choice(("NeonRed", "NeonPink", "NeonCyan", "NeonYellow", "NeonBlue")), (cx, top + 6.0, cz),
              (min(x1 - x0, 24.0), 3.0, 0.6), rng.choice((0, 90)))
    elif r < 0.16:
        for dx in (-3.0, 3.0):
            dash(s, "NeonYellow", cx + dx - 0.5, cz - 4.0, cx + dx + 0.5, cz + 4.0, top + 1.4)
        dash(s, "NeonYellow", cx - 3.0, cz - 0.5, cx + 3.0, cz + 0.5, top + 1.4)
        for dx, dz in ((-8, -8), (8, -8), (-8, 8), (8, 8)):
            dash(s, "NeonGreen", cx + dx - 0.6, cz + dz - 0.6, cx + dx + 0.6, cz + dz + 0.6, top + 1.4)


def ridge(s, rng):
    """Where the ground stops to the north, a ridge of tall dark towers closes the view."""
    x = -FAR
    while x < FAR:
        w = rng.uniform(60.0, 120.0)
        block(s, rng, x, -FAR_N + 10.0, x + w - 8.0, -FAR_N + 70.0, rng.randint(26, 44), 0.12, "CityFacade")
        x += w


def landmarks(s, rng):
    """Tokyo District as the players know it, seen from above: the station with its lit sign and
    platform roofs, the scramble's white crossings, the glass tower and its giant screen."""
    sx, sz, sw, sl = STATION
    s.box("CityFacadeWarm", (sx, GY + 14, sz), (sw, 28, sl), skip=("-y",))
    for k in range(3):
        s.box("DarkMetal", (sx + sw / 2 + 12 + k * 14, GY + 9, sz), (10, 1.0, sl + 40), skip=("-y",))
        dash(s, "NeonCool", sx + sw / 2 + 9 + k * 14, sz - sl / 2 - 20, sx + sw / 2 + 15 + k * 14, sz + sl / 2 + 20, GY + 9.6)
    s.box("NeonWarm", (sx + sw / 2 + 0.4, GY + 24, sz), (0.6, 4.0, 60.0))
    cx, cz = SCRAMBLE
    dash(s, "CityRoad", cx - 45, cz - 45, cx + 45, cz + 45, GY + 0.05)
    for k in range(-5, 6):
        for dx, dz, w, d in ((k * 6.0, -38.0, 3.0, 10.0), (k * 6.0, 38.0, 3.0, 10.0), (-38.0, k * 6.0, 10.0, 3.0),
                             (38.0, k * 6.0, 10.0, 3.0)):
            dash(s, "WhiteTrim", cx + dx - w / 2, cz + dz - d / 2, cx + dx + w / 2, cz + dz + d / 2, GY + 0.1)
    for k in range(-7, 8):
        x, z = cx + k * 5.0, cz + k * 5.0
        dash(s, "WhiteTrim", x - 1.5, z - 1.5, x + 1.5, z + 1.5, GY + 0.12)
    # The glass tower on the crossing's corner, its giant screen on the face turned to us.
    gx, gz = GLASS_TOWER
    tower(s, rng, gx - 26, gz - 22, gx + 26, gz + 22, 18, 0.5)
    s.box("BlackMetal", (gx, GY + 150, gz - 22.6), (34.0, 21.0, 1.0))
    s.screen((gx, GY + 150, gz - 23.2), 0, 32.0, 19.0, "ads")
    for k, (bx, bz, floors) in enumerate(((-500, 470, 12), (-360, 490, 9), (-490, 340, 8))):
        top = block(s, rng, bx - 22, bz - 20, bx + 22, bz + 20, floors, 0.55)
        s.box(("NeonRed", "NeonPink", "NeonYellow")[k], (bx, top + 6, bz), (30.0, 5.0, 1.0), k * 90)


def expressway(s):
    """The expressway on its viaduct across the north: deck, parapets, piers, lamps."""
    y = GY + 30.0
    z = EXPRESSWAY_Z
    for a, b in cuts(-CITY, CITY):
        s.box("CityRoof", ((a + b) / 2, y, z), (b - a, 3.0, 26.0))
        for side in (-1, 1):
            s.box("CityFacade", ((a + b) / 2, y + 2.5, z + side * 12.6), (b - a, 2.0, 0.8))
    x = -CITY
    while x < CITY:
        s.box("CityFacade", (x, (GY + y) / 2, z), (5.0, y - GY, 5.0), skip=("-y",))
        for side in (-1, 1):
            dash(s, "NeonOrange", x - 1.0, z + side * 11.0 - 0.5, x + 1.0, z + side * 11.0 + 0.5, y + 1.6)
        x += 40.0


def neighbours(s, rng):
    """The towers round the Agency's, some as tall, their tops crowned with aircraft lights."""
    for k, (cx, cz, w, d, floors) in enumerate(NEIGHBOURS):
        top = tower(s, rng, cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2, floors, 0.35)
        s.box("BlackMetal", (cx, top + 3.0, cz), (w + 1.0, 4.0, d + 1.0), skip=("-y",))
        if k % 2 == 0:
            s.box("DarkMetal", (cx, top + 16.0, cz), (1.0, 26.0, 1.0), skip=("-y",))
            s.blinker((cx, top + 29.5, cz), (255, 40, 40), 1.6, 1.6, rng.uniform(0, 1.6))
        for sx in (-1, 1):
            for sz in (-1, 1):
                s.blinker((cx + sx * w / 2, top + 5.6, cz + sz * d / 2), (255, 40, 40), 2.2, 1.2, rng.uniform(0, 2.2))
        if k == 5:
            s.blinker((cx, top + 6.0, cz + d / 2 + 0.6), (255, 255, 255), 1.1, 1.4, 0.0)


def traffic(s):
    """Car lights streaming along the avenues nearest the tower and the expressway: tail lights
    one way, headlights the other (particles the game sends down each road)."""
    # (start x, z, the way it runs as a rot: -90 east, 90 west, 180 south, 0 north)
    lanes = [(-CITY, EXPRESSWAY_Z - 5.0, -90.0), (CITY, EXPRESSWAY_Z + 5.0, 90.0)]
    for c in (-CITY + AVENUE_EVERY * 9, -CITY + AVENUE_EVERY * 12):
        lanes += [(c - 3.5, -CITY, 180.0), (c + 3.5, CITY, 0.0)]
    for c in (-CITY + AVENUE_EVERY * 8, -CITY + AVENUE_EVERY * 12):
        lanes += [(-CITY, c - 3.5, -90.0), (CITY, c + 3.5, 90.0)]
    for k, (x, z, rot) in enumerate(lanes):
        y = GY + (32.0 if abs(z - EXPRESSWAY_Z) < 10 else 1.5)
        s.emitter("traffic_tail" if k % 2 == 0 else "traffic_head", (x, y, z), rot, (6.0, 1.0, 2 * CITY))


def window_rain(s):
    """Rain running down the outside of the glass, a band per floor on every face."""
    p = P.PLATE
    for i in range(len(p)):
        a, b = p[i], p[(i + 1) % len(p)]
        length = math.dist(a, b)
        t = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        n = (t[1], -t[0])
        rot = g2.rot_of(t)
        count = max(1, round(length / 50.0))
        for k in range(count):
            u = length * (k + 0.5) / count
            x = a[0] + t[0] * u + n[0] * 0.35
            z = a[1] + t[1] * u + n[1] * 0.35
            for level in P.LEVELS:
                s.emitter("windowrain", (x, level + 7.0, z), rot, (length / count, 12.0, 0.3))


def helicopter(s):
    """A police helicopter's pass along the south glass and round the cut corner, its searchlight
    on the floors as it goes."""
    path = [(-460.0, 34.0, 170.0), (-180.0, 24.0, 118.0), (-60.0, 20.0, 112.0), (40.0, 20.0, 110.0),
            (110.0, 22.0, 80.0), (150.0, 24.0, 20.0), (200.0, 28.0, -80.0), (460.0, 36.0, -260.0)]
    target = [(-150.0, 6.0, 72.0), (-90.0, 8.0, 70.0), (-40.0, 10.0, 70.0), (20.0, 12.0, 70.0),
              (70.0, 14.0, 58.0), (96.0, 12.0, 28.0), (96.0, 10.0, -20.0), (96.0, 8.0, -70.0)]
    s.fly(path, target, every=95.0, duration=20.0)


def build(s):
    rng = random.Random(3838)
    ground(s, rng)
    blocks(s, rng)
    ridge(s, rng)
    landmarks(s, rng)
    expressway(s)
    neighbours(s, rng)
    traffic(s)
    window_rain(s)
    helicopter(s)
