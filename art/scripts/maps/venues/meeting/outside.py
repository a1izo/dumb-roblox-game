"""What the war room's south windows look out on: Kagegaoka at night from high up in the Central
Tower (the Agency keeps its war room above its two floors). Neighbouring towers stand at about eye
level with lit windows and red lights blinking on their crowns; the streets glow 480 studs down;
rain runs down the glass. Flat colours and big simple pieces: it is only ever seen through the
blinds."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.venues.meeting import plan as P

BASE = -480.0  # the street, far below


def tower(s, rng, x0, z0, x1, z1, y0, top, lit):
    clad = "CityFacade" if rng.random() < 0.7 else "CityFacadeWarm"
    sides = (((x0, z0), (x1, z0), (0, -1)), ((x1, z0), (x1, z1), (1, 0)), ((x1, z1), (x0, z1), (0, 1)),
             ((x0, z1), (x0, z0), (-1, 0)))
    for a, b, out in sides:
        city.vquad(s, clad, a, b, y0, top, out)
        length = math.dist(a, b)
        ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        level = top - 14.0
        count = 0
        while level > max(y0, top - 260.0) and count < 10:
            if rng.random() < lit:
                u0 = rng.uniform(0, length * 0.5)
                u1 = min(length, u0 + rng.uniform(length * 0.25, length))
                pa = (a[0] + ux * u0 + out[0] * 0.3, a[1] + uz * u0 + out[1] * 0.3)
                pb = (a[0] + ux * u1 + out[0] * 0.3, a[1] + uz * u1 + out[1] * 0.3)
                city.vquad(s, "WindowLit" if rng.random() < 0.7 else "WindowCool", pa, pb, level, level + 6.0, out)
                count += 1
            level -= 12.0 * rng.choice((1, 1, 2, 3))
    city.up_face(s, "CityRoof", [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], top)


def build(s):
    rng = random.Random(4040)
    # The street grid far below, glowing.
    x0, x1, z0, z1 = -900.0, 900.0, 40.0, 1500.0
    city.up_face(s, "CityGround", [(x0, z0), (x1, z0), (x1, z1), (x0, z1)], BASE)
    for k in range(-9, 10):
        x = k * 100.0
        city.up_face(s, "CityRoad", g2.rect(x, (z0 + z1) / 2, 14.0, z1 - z0), BASE + 0.2)
        city.up_face(s, "NeonOrange", g2.rect(x - 5.5, (z0 + z1) / 2, 1.2, z1 - z0), BASE + 0.4)
        city.up_face(s, "NeonOrange", g2.rect(x + 5.5, (z0 + z1) / 2, 1.2, z1 - z0), BASE + 0.4)
    for k in range(1, 15):
        z = z0 + k * 100.0
        city.up_face(s, "CityRoad", g2.rect(0.0, z, x1 - x0, 14.0), BASE + 0.2)
        city.up_face(s, "NeonOrange", g2.rect(0.0, z - 5.5, x1 - x0, 1.2), BASE + 0.4)
    # Low blocks between the streets.
    for i in range(-9, 9):
        for j in range(0, 14):
            bx0, bz0 = i * 100.0 + 12.0, z0 + j * 100.0 + 12.0
            if rng.random() < 0.35:
                continue
            w = rng.uniform(40, 76)
            tower(s, rng, bx0, bz0, bx0 + w, bz0 + rng.uniform(40, 76), BASE, BASE + rng.uniform(30, 160), 0.4)
    # The neighbouring towers, their crowns about level with the war room.
    for k, (cx, cz, w, top) in enumerate(((-150.0, 220.0, 60.0, 40.0), (120.0, 300.0, 70.0, 80.0),
                                          (-40.0, 520.0, 64.0, -20.0), (320.0, 460.0, 80.0, 60.0),
                                          (-360.0, 420.0, 70.0, 20.0), (60.0, 820.0, 90.0, 120.0),
                                          (-520.0, 760.0, 80.0, 70.0), (520.0, 900.0, 90.0, 30.0))):
        tower(s, rng, cx - w / 2, cz - w / 2, cx + w / 2, cz + w / 2, BASE, top, 0.55)
        for sx in (-1, 1):
            s.blinker((cx + sx * w / 2, top + 2.0, cz), (255, 40, 40), 1.8 + k * 0.17, 1.8, (k * 0.41) % 2.0)
    # Rain running down the outside of each window.
    w0, sill, head = P.WINDOW
    for x in P.WINDOWS:
        s.emitter("windowrain", (x, (sill + head) / 2, P.HALF + 0.35), 0.0, size=(w0, head - sill, 0.3))
