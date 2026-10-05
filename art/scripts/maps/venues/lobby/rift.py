"""The rift: a hole torn in the Grey Realm's ground, where its dwellers sit and watch the world of
the living. Its rim glows with cold cracks; jagged rock walls drop away into it; and far beneath,
seen through it, lies Kagegaoka at night: streets of lamps, lit windows, the river, the Central
Tower with its red lights. Nobody can fall in: an invisible guard stands a few studs back from the
edge, behind a lip of broken rock.

The city is built at a third of its size (a city three times as far away looks the same), so its
tallest tower still ends well under the realm."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.mesher import cross, dot, sub
from maps.venues.lobby import plan as P
from maps.venues.lobby.landmarks import pillar
from maps.venues.lobby.terrain import boulder, rock

K = 1 / 3  # the city's scale


def face_to(s, mat, pts, target):
    """A face whose front looks towards `target`."""
    n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    cz = sum(p[2] for p in pts) / len(pts)
    if dot(n, (target[0] - cx, target[1] - cy, target[2] - cz)) < 0:
        pts = list(reversed(pts))
    s.polygon(mat, pts)


def hole(s):
    rng = random.Random(611)
    cx, cz = g2.centroid(P.RIFT)
    poly = g2.ccw(P.RIFT)
    n = len(poly)
    levels = [0.0, -9.0, -20.0, -34.0, -P.RIFT_DEPTH]
    foot = P.grown(poly, 3.5)  # the last ring: the opening in the island's underside
    # Each rim point, pushed in or out a little at each level (the walls bulge and overhang).
    rings = []
    for li, y in enumerate(levels):
        ring = []
        for k, (x, z) in enumerate(poly):
            dx, dz = x - cx, z - cz
            r = math.hypot(dx, dz)
            if li == len(levels) - 1:
                ring.append((foot[k][0], y, foot[k][1]))
                continue
            push = 0.0 if li == 0 else rng.uniform(-1.8, 2.6) + li * 0.4
            ring.append((x + dx / r * push, y, z + dz / r * push))
        rings.append(ring)
    for li in range(len(levels) - 1):
        a, b = rings[li], rings[li + 1]
        for k in range(n):
            k1 = (k + 1) % n
            axis = (cx, (levels[li] + levels[li + 1]) / 2, cz)
            face_to(s, "RockGrey", [a[k], a[k1], b[k1]], axis)
            face_to(s, "RockGrey", [a[k], b[k1], b[k]], axis)
    # The glowing cracks just under the rim, and the cold light rising from them.
    for k in range(n):
        p, q = poly[k], poly[(k + 1) % n]
        for t0, t1 in ((0.08, 0.4), (0.55, 0.9)):
            a = (p[0] + (q[0] - p[0]) * t0, p[1] + (q[1] - p[1]) * t0)
            b = (p[0] + (q[0] - p[0]) * t1, p[1] + (q[1] - p[1]) * t1)
            y0 = -rng.uniform(0.5, 1.2)
            y1 = y0 - rng.uniform(0.3, 0.7)
            face_to(s, "RiftGlow", [(a[0], y0, a[1]), (b[0], y0, b[1]), (b[0], y1, b[1]), (a[0], y1, a[1])], (cx, -5.0, cz))
    s.light("point", (cx, -7.0, cz), (170, 196, 232), 40, 1.0)
    s.light("point", (cx, -22.0, cz), (150, 176, 214), 30, 0.6)
    # The lip: broken rocks round the edge, between it and the guard.
    guard = g2.ccw(P.RIFT_GUARD)
    for k in range(n):
        p, q = poly[k], poly[(k + 1) % n]
        for t in (0.25, 0.75):
            x, z = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t
            dx, dz = x - cx, z - cz
            r = math.hypot(dx, dz)
            off = rng.uniform(1.2, 2.4)
            boulder(s, x + dx / r * off, z + dz / r * off, rng.uniform(0.7, 1.5), 7000 + k * 2 + int(t * 4), collide=False)
    for k in range(len(guard)):
        a, b = guard[k], guard[(k + 1) % len(guard)]
        length = math.dist(a, b)
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        rot = math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))
        s.collider((mid[0], 12.0, mid[1]), (length + 1.0, 26.0, 1.0), rot, False, None)
    rim(s, poly, cx, cz, rng)
    s.emitter("riftwisp", (cx, -3.0, cz), P.RIFT_TURN, size=(P.RIFT_AXES[0] * 1.7, 2.0, P.RIFT_AXES[1] * 1.7))
    s.emitter("mist", (cx, -6.0, cz), P.RIFT_TURN, size=(P.RIFT_AXES[0] * 1.5, 5.0, P.RIFT_AXES[1] * 1.5))
    s.sound("mapRiftHum", (cx, -2.0, cz), 60.0, 0.5)
    # A few tall rocks standing round it, where the watchers sit.
    for k, (a, d, r, h) in enumerate(((0.3, 30.0, 3.5, 7.0), (2.4, 29.0, 2.8, 4.5), (4.3, 31.0, 4.0, 9.0))):
        x, z = cx + math.cos(a) * d, cz + math.sin(a) * d * 0.8
        if g2.contains(P.BASIN, (x, z)):
            rock(s, x, z, r, h, 7100 + k, tiers=2, sides=8, taper=0.35, flat_top=True)


def rim(s, poly, cx, cz, rng):
    """The rift's ruined rim: a band of old flagstones round the edge, a worn balustrade standing
    between the stones and the guard, and a broken arch of two pillars over the north side."""
    ring = P.grown(poly, 3.3)
    n = len(poly)
    for k in range(n):
        k1 = (k + 1) % n
        quad = [poly[k], poly[k1], ring[k1], ring[k]]
        city.up_face(s, "RuinFlag", quad, 0.04)
    outer = P.grown(poly, 2.6)
    for k in range(n):
        a, b = outer[k], outer[(k + 1) % n]
        length = math.dist(a, b)
        ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        rot = math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))
        u = 0.4
        while u < length - 0.6:
            run = rng.uniform(1.6, 4.0)
            if rng.random() < 0.34:
                u += run
                continue
            run = min(run, length - u - 0.2)
            h = rng.uniform(1.0, 3.0)
            mx, mz = a[0] + ux * (u + run / 2), a[1] + uz * (u + run / 2)
            s.box("RuinStone", (mx, h / 2, mz), (run, h, 0.8), rot, skip=("-y",))
            if rng.random() < 0.4:
                s.box("RuinStone", (mx, h + 0.4, mz), (run * 0.7, 0.8, 1.1), rot)
            u += run + rng.uniform(0.1, 0.9)
    # The arch, north of the rift: one pillar whole with a stub of lintel, one snapped off.
    nx, nz = cx - 3.0, cz - P.RIFT_AXES[1] - 9.5
    if g2.contains(P.BASIN, (nx, nz)):
        pillar(s, nx - 7.0, nz, 16.0, rng, whole=True)
        pillar(s, nx + 7.0, nz, 8.5, rng, whole=False)
        s.box("RuinStone", (nx - 3.0, 17.0, nz), (9.5, 1.6, 2.6), 0.0, collide=True)
        s.box("RuinStone", (nx - 1.5, 18.4, nz), (6.0, 1.2, 2.0), 0.0)


# Kagegaoka far below --------------------------------------------------------------------------------------


class Below:
    """Draws the city in its own units (x, z from the rift's middle, y up from its ground), scaled by K
    under the rift."""

    def __init__(self, s):
        self.s = s
        self.cx, self.cz = g2.centroid(P.RIFT)

    def p(self, x, y, z):
        return (self.cx + x * K, P.BELOW_Y + y * K, self.cz + z * K)

    def up(self, mat, x0, z0, x1, z1, y):
        self.s.polygon(mat, [self.p(x0, y, z1), self.p(x1, y, z1), self.p(x1, y, z0), self.p(x0, y, z0)])

    def side(self, mat, a, b, y0, y1, out):
        pts = [self.p(a[0], y0, a[1]), self.p(b[0], y0, b[1]), self.p(b[0], y1, b[1]), self.p(a[0], y1, a[1])]
        n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
        if n[0] * out[0] + n[2] * out[1] < 0:
            pts.reverse()
        self.s.polygon(mat, pts)

    def block(self, rng, x0, z0, x1, z1, floors, lit):
        top = floors * 12.0
        clad = "CityFacade" if rng.random() < 0.7 else "CityFacadeWarm"
        sides = (((x0, z0), (x1, z0), (0, -1)), ((x1, z0), (x1, z1), (1, 0)), ((x1, z1), (x0, z1), (0, 1)),
                 ((x0, z1), (x0, z0), (-1, 0)))
        for a, b, out in sides:
            self.side(clad, a, b, 0.0, top + 1.5, out)
            length = math.dist(a, b)
            ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
            # A few lit bands of windows (at most six a side): whole floors, or a run along one.
            for f in range(0, floors, max(1, floors // 6)):
                if rng.random() > lit:
                    continue
                y = f * 12.0 + 4.0
                u0 = rng.uniform(0, length * 0.5)
                u1 = min(length, u0 + rng.uniform(length * 0.2, length))
                pa = (a[0] + ux * u0 + out[0] * 0.6, a[1] + uz * u0 + out[1] * 0.6)
                pb = (a[0] + ux * u1 + out[0] * 0.6, a[1] + uz * u1 + out[1] * 0.6)
                self.side("DimWarm" if rng.random() < 0.16 else "DimWindow", pa, pb, y, y + 5.0, out)
        self.up("CityRoof", x0, z0, x1, z1, top + 1.5)
        return top


def below(s):
    """Kagegaoka at night: the ground, a grid of streets with their lamps, blocks of lit windows, a
    river crossing it with its bridges, the station's glow and the Central Tower with its lights."""
    b = Below(s)
    rng = random.Random(8080)
    half = 1000.0
    b.up("CityGround", -half, -half, half, half, 0.0)
    step, road = 96.0, 14.0
    # The river: a band across the city, north-west to south-east.
    river = [(-half, -300.0), (half, 420.0)]

    def near_river(x, z, pad):
        (ax, az), (bx, bz) = river
        return g2.dist_point_segment((x, z), (ax, az), (bx, bz)) < 40.0 + pad

    rot = math.degrees(math.atan2(-(river[1][1] - river[0][1]), river[1][0] - river[0][0]))
    length = math.dist(*river)
    mid = ((river[0][0] + river[1][0]) / 2, (river[0][1] + river[1][1]) / 2)
    poly = g2.rect(mid[0], mid[1], length, 80.0, rot)
    s.polygon("WindowDark", [b.p(x, 0.3, z) for x, z in g2.cw(poly)])
    for side in (-1, 1):
        edge = g2.rect(mid[0] + math.sin(math.radians(rot)) * side * 41.0, mid[1] + math.cos(math.radians(rot)) * side * 41.0,
                       length, 2.0, rot)
        s.polygon("DimBand", [b.p(x, 0.5, z) for x, z in g2.cw(edge)])
    n = int(half // step)
    for i in range(-n, n + 1):
        c = i * step
        # Streets both ways, with a line of lamps down each side.
        b.up("CityRoad", c - road / 2, -half, c + road / 2, half, 0.2)
        b.up("CityRoad", -half, c - road / 2, half, c + road / 2, 0.2)
        for off in (-road / 2 + 1.0, road / 2 - 1.0):
            b.up("DimLamp", c + off - 0.8, -half, c + off + 0.8, half, 0.35)
            b.up("DimLamp", -half, c + off - 0.8, half, c + off + 0.8, 0.35)
    towers = []
    for i in range(-n, n):
        for j in range(-n, n):
            x0, z0 = i * step + road / 2 + 3.0, j * step + road / 2 + 3.0
            x1, z1 = (i + 1) * step - road / 2 - 3.0, (j + 1) * step - road / 2 - 3.0
            mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
            if near_river(mx, mz, 48.0):
                continue
            dist = math.hypot(mx, mz)
            if dist > 860:
                continue
            # Busier and taller towards the middle.
            centre = max(0.0, 1 - dist / 900.0)
            if rng.random() < 0.5:
                floors = int(rng.uniform(3, 8) + centre * rng.uniform(4, 26))
                b.block(rng, x0, z0, x1, z1, floors, 0.35 + 0.2 * centre)
                if floors > 18:
                    towers.append(((x0 + x1) / 2, floors * 12.0 + 1.5, (z0 + z1) / 2))
            else:
                w = (x1 - x0) / 2 - 2.0
                for qx in (0, 1):
                    for qz in (0, 1):
                        if rng.random() < 0.2:
                            continue
                        floors = int(rng.uniform(2, 6) + centre * rng.uniform(0, 12))
                        bx0, bz0 = x0 + qx * (w + 4.0), z0 + qz * (w + 4.0)
                        b.block(rng, bx0, bz0, bx0 + w, bz0 + w, floors, 0.3 + 0.2 * centre)
    for k, (x, y, z) in enumerate(towers[:24]):
        s.blinker(b.p(x, y + 3.0, z), (190, 205, 230), 1.6 + (k % 5) * 0.3, 1.1, (k * 0.37) % 2.0)
    # The station's glow, and the Central Tower a little off the middle, lit at its 38th floor.
    b.up("DimBand", 150.0, -60.0, 330.0, -40.0, 0.6)
    b.up("DimBandWarm", 150.0, -20.0, 330.0, -4.0, 0.6)
    tx0, tz0, tx1, tz1 = -200.0, 120.0, -150.0, 170.0
    top = 480.0
    for a, bb, out in (((tx0, tz0), (tx1, tz0), (0, -1)), ((tx1, tz0), (tx1, tz1), (1, 0)),
                       ((tx1, tz1), (tx0, tz1), (0, 1)), ((tx0, tz1), (tx0, tz0), (-1, 0))):
        b.side("CityFacade", a, bb, 0.0, top, out)
        pa = (a[0] + out[0] * 0.6, a[1] + out[1] * 0.6)
        pb = (bb[0] + out[0] * 0.6, bb[1] + out[1] * 0.6)
        b.side("DimWarm", pa, pb, 440.0, 452.0, out)
        b.side("DimWindow", pa, pb, 454.0, 466.0, out)
        for level in range(20, 430, 36):
            if rng.random() < 0.3:
                b.side("DimWindow", pa, pb, level, level + 6.0, out)
    b.up("CityRoof", tx0, tz0, tx1, tz1, top)
    s.blinker(b.p((tx0 + tx1) / 2, top + 30.0, (tz0 + tz1) / 2), (190, 205, 230), 1.6, 1.4, 0.0)
    for sx in (tx0, tx1):
        for sz in (tz0, tz1):
            s.blinker(b.p(sx, top + 1.5, sz), (190, 205, 230), 2.2, 0.9, rng.uniform(0, 2.2))
    s.box("DarkMetal", b.p((tx0 + tx1) / 2, top + 15.0, (tz0 + tz1) / 2), (1.6 * K * 3, 30 * K, 1.6 * K * 3), skip=("-y",))


def build(s):
    hole(s)
    below(s)
