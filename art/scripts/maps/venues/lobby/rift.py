"""The rift: a hole torn in the Grey Realm's ground, where its dwellers sit and watch the world of
the living. Its rim glows with cold cracks; jagged rock walls drop away into it; and far beneath,
seen through it, lies Kagegaoka at night: streets of lamps, lit windows, the river, the Central
Tower with its red lights.

The rim is open: a lip of broken rock and a worn balustrade stand round it, low enough to step over,
and whoever goes over falls (the game makes a dive of it; until it does, it puts up its own guard at
the `rift` anchor). Straight beneath the opening stands a broad hall whose roof, with a ring of light
on it, is where a dive ends: the only solid thing down there (anchor `landing`).

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

K = P.CITY_SCALE  # the city's scale


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
    levels = [0.0, -9.0, -20.0, -34.0, -50.0, -63.0, -P.RIFT_DEPTH]
    foot = P.grown(poly, 6.0)  # the last ring: the throat's mouth, flaring out into the cloud
    # Each rim point, pushed in or out a little at each level (the walls bulge and overhang). (The levels
    # under -34 draw from a stream of their own, so the rim and everything round it are as they were.)
    deep = random.Random(612)
    rings = []
    for li, y in enumerate(levels):
        ring = []
        for k, (x, z) in enumerate(poly):
            dx, dz = x - cx, z - cz
            r = math.hypot(dx, dz)
            if li == len(levels) - 1:
                ring.append((foot[k][0], y, foot[k][1]))
                continue
            push = 0.0 if li == 0 else (rng if li <= 3 else deep).uniform(-1.8, 2.6) + min(li, 3) * 0.4
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
            # (A hair in front of the rock, towards the rift's middle: on it, the two flickered.)
            a = (a[0] + (cx - a[0]) / math.dist(a, (cx, cz)) * 0.08, a[1] + (cz - a[1]) / math.dist(a, (cx, cz)) * 0.08)
            b = (b[0] + (cx - b[0]) / math.dist(b, (cx, cz)) * 0.08, b[1] + (cz - b[1]) / math.dist(b, (cx, cz)) * 0.08)
            y0 = -rng.uniform(0.5, 1.2)
            y1 = y0 - rng.uniform(0.3, 0.7)
            face_to(s, "RiftGlow", [(a[0], y0, a[1]), (b[0], y0, b[1]), (b[0], y1, b[1]), (a[0], y1, a[1])], (cx, -5.0, cz))
    s.light("point", (cx, -7.0, cz), (170, 196, 232), 40, 1.0)
    s.light("point", (cx, -22.0, cz), (150, 176, 214), 30, 0.6)
    throat(s, rings, levels, cx, cz, rng)
    # The lip: broken rocks round the edge, solid, low enough to hop over.
    for k in range(n):
        p, q = poly[k], poly[(k + 1) % n]
        for t in (0.25, 0.75):
            x, z = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t
            dx, dz = x - cx, z - cz
            r = math.hypot(dx, dz)
            off = rng.uniform(1.2, 2.4)
            boulder(s, x + dx / r * off, z + dz / r * off, rng.uniform(0.7, 1.5), 7000 + k * 2 + int(t * 4), collide=True)
    rim(s, poly, cx, cz, rng)
    # A pale light on the plaza's side of the rim, where people come to it.
    wx, wz = P.PLAZA_C[0] - cx, P.PLAZA_C[1] - cz
    wd = math.hypot(wx, wz)
    s.light("point", (cx + wx / wd * (P.RIFT_AXES[0] + 6.0), 7.0, cz + wz / wd * (P.RIFT_AXES[0] + 6.0)), (170, 196, 232),
            26, 1.0)
    s.emitter("riftwisp", (cx, -3.0, cz), P.RIFT_TURN, size=(P.RIFT_AXES[0] * 1.7, 2.0, P.RIFT_AXES[1] * 1.7))
    s.emitter("mist", (cx, -6.0, cz), P.RIFT_TURN, size=(P.RIFT_AXES[0] * 1.5, 5.0, P.RIFT_AXES[1] * 1.5))
    s.sound("mapRiftHum", (cx, -2.0, cz), 60.0, 0.5)
    # A few tall rocks standing round it, where the watchers sit.
    for k, (a, d, r, h) in enumerate(((0.3, 30.0, 3.5, 7.0), (2.4, 29.0, 2.8, 4.5), (4.3, 31.0, 4.0, 9.0))):
        x, z = cx + math.cos(a) * d, cz + math.sin(a) * d * 0.8
        if g2.contains(P.BASIN, (x, z)):
            rock(s, x, z, r, h, 7100 + k, tiers=2, sides=8, taper=0.35, flat_top=True)


def throat(s, rings, levels, cx, cz, _rng):
    """The throat's dressing under the glow: dead roots hanging from its walls (gone to stone, like the rest of
    the realm), and ledges of broken stone standing out of them, all out of a diver's way (outside the rift's
    own outline, which no diver leaves)."""
    rng = random.Random(613)
    n = len(rings[0])
    for li in range(2, len(levels) - 1):
        ring = rings[li]
        for k in range(n):
            if rng.random() > 0.42:
                continue
            x, y, z = ring[k]
            dx, dz = x - cx, z - cz
            r = math.hypot(dx, dz)
            ox, oz = dx / r, dz / r
            # A root: out of the wall a little above this ring, hanging down, curling in a little at its tip.
            top = (x + ox * 0.6, y + rng.uniform(1.0, 4.0), z + oz * 0.6)
            length = rng.uniform(6.0, 14.0)
            bend = rng.uniform(0.3, 1.0)
            mid = (top[0] - ox * bend * 0.5, top[1] - length * 0.55, top[2] - oz * bend * 0.5)
            tip = (top[0] - ox * bend, top[1] - length, top[2] - oz * bend)
            radius = rng.uniform(0.28, 0.55)
            s.bent_tube("RockGrey", [top, mid, tip], [radius, radius * 0.65, radius * 0.15], 6, caps=(False, True))
        # Now and then a ledge of broken stone standing out of the wall, sloping a little.
        k = rng.randrange(n)
        x, y, z = ring[k]
        dx, dz = x - cx, z - cz
        r = math.hypot(dx, dz)
        rot = math.degrees(math.atan2(-dz, dx))
        s.box("RuinStone", (x + dx / r * 0.4, y - 1.0, z + dz / r * 0.4), (rng.uniform(4.0, 7.0), 1.4, 2.4), rot + 90.0)
        s.box("RuinStone", (x + dx / r * 0.9, y - 2.2, z + dz / r * 0.9), (rng.uniform(2.0, 3.5), 1.0, 1.6), rot + 87.0)


def cloud(s):
    """The cloud the Grey Realm floats on, seen from under it: a deck of dark storm cloud at CLOUD_Y, out past
    where the haze swallows it, with heavy lobes hanging from it (mammatus: big and close round the rift's
    throat, sparser and larger further out), and the throat opening through its middle. Its faces look down
    only: from the realm above nothing of it shows, and from under it nothing of the realm ever does."""
    rng = random.Random(9090)
    cx, cz = g2.centroid(P.RIFT)
    s.anchor("cloud", cx, P.CLOUD_Y, cz, 0.0)  # (the game reads the deck's height from it: the dive's lighting)
    mouth = P.grown(g2.ccw(P.RIFT), 6.0)
    hole_r = max(math.dist((cx, cz), p) for p in mouth)
    step = 250.0
    far = P.CLOUD_FAR
    n = int(math.ceil(far / step))
    y = P.CLOUD_Y
    for i in range(-n, n):
        for j in range(-n, n):
            x0, z0 = cx + i * step, cz + j * step
            pieces = [[(x0, z0), (x0 + step, z0), (x0 + step, z0 + step), (x0, z0 + step)]]
            pieces = g2.subtract_all(pieces, [mouth])
            for piece in pieces:
                if abs(g2.area(piece)) > 0.05:
                    for part in g2.convex_pieces(piece):
                        city.down_face(s, "CloudUnder", part, y)

    def lobe(x, z, r, depth, mat):
        s.lathe(mat, (x, y + 0.6, z), [(0.0, -depth), (0.7 * r, -depth * 0.62), (r, 0.0)], 6, caps=(False, False))

    # Close round the throat: a ragged collar of lobes hugging the mouth, then a jittered field out to 460.
    for k in range(14):
        a = math.tau * k / 14 + rng.uniform(-0.1, 0.1)
        d = hole_r + rng.uniform(6.0, 14.0)
        r = rng.uniform(9.0, 15.0)
        lobe(cx + math.cos(a) * d, cz + math.sin(a) * d, r, r * rng.uniform(0.7, 1.0), "CloudUnderPale")
    spacing = 88.0
    q = int(460.0 // spacing)
    for i in range(-q, q + 1):
        for j in range(-q, q + 1):
            x = cx + i * spacing + rng.uniform(-24.0, 24.0)
            z = cz + j * spacing + rng.uniform(-24.0, 24.0)
            d = math.hypot(x - cx, z - cz)
            if d > 460.0 or d < hole_r + 26.0:
                continue
            r = rng.uniform(22.0, 40.0)
            lobe(x, z, r, r * rng.uniform(0.5, 0.8), "CloudUnderPale" if rng.random() < 0.4 else "CloudUnder")
    spacing = 230.0
    q = int(far // spacing)
    for i in range(-q, q + 1):
        for j in range(-q, q + 1):
            x = cx + i * spacing + rng.uniform(-60.0, 60.0)
            z = cz + j * spacing + rng.uniform(-60.0, 60.0)
            d = math.hypot(x - cx, z - cz)
            if d <= 470.0 or d > far - 80.0:
                continue
            r = rng.uniform(55.0, 95.0)
            lobe(x, z, r, r * rng.uniform(0.4, 0.65), "CloudUnder")


def rim(s, poly, cx, cz, rng):
    """The rift's ruined rim: a band of old flagstones round the edge, a worn balustrade standing
    just outside it (solid, with gaps, never higher than a jump), and a broken arch of two pillars over
    the north side."""
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
            s.box("RuinStone", (mx, h / 2, mz), (run, h, 0.8), rot, collide=True, skip=("-y",))
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
    outer = P.CITY_FAR / K
    # The ground runs out to the far ring (the inner square is drawn on its own, as it always was).
    for x0, z0, x1, z1 in ((-outer, -outer, outer, -half), (-outer, half, outer, outer), (-outer, -half, -half, half),
                           (half, -half, outer, half)):
        b.up("CityGround", x0, z0, x1, z1, 0.0)
    b.up("CityGround", -half, -half, half, half, 0.0)
    step, road = 96.0, 14.0
    # The river: a band across the city, north-west to south-east. It passes north of the point under the rift,
    # so the hall a dive ends on stands among streets and blocks, not in the water.
    river = [(-half, -573.0), (half, 147.0)]
    lw, ld, _ = P.LANDING

    def at_landing(x0, z0, x1, z1, pad=24.0):
        return x0 < lw + pad and x1 > -lw - pad and z0 < ld + pad and z1 > -ld - pad

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
            if near_river(mx, mz, 48.0) or at_landing(x0, z0, x1, z1):
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
    far_city(s, b, half, outer, river)
    landing(s, b)


def far_city(s, b, half, outer, river):
    """The city past the middle, out to where the haze takes it: bigger blocks, plain, fewer lit windows,
    a lit avenue every other block, and now and then a tall tower standing up dark against the haze (what a
    diver sees all round). Cheap: a block is four walls and a roof, a band of windows on some sides."""
    rng = random.Random(8181)
    step = 192.0
    n = int(outer // step)
    (ax, az), (bx, bz) = river
    rdx, rdz = bx - ax, bz - az
    # The river carried on out of the middle both ways, to the far ring's edge.
    length = math.hypot(rdx, rdz)
    ux, uz = rdx / length, rdz / length
    rot = math.degrees(math.atan2(-rdz, rdx))
    run = (outer - half) / max(abs(ux), 1e-3)
    for (ex, ez), sgn in (((bx, bz), 1), ((ax, az), -1)):
        mx, mz = ex + sgn * ux * run / 2, ez + sgn * uz * run / 2
        s.polygon("WindowDark", [b.p(x, 0.3, z) for x, z in g2.cw(g2.rect(mx, mz, run, 80.0, rot))])
        for side in (-1, 1):
            edge = g2.rect(mx + math.sin(math.radians(rot)) * side * 41.0, mz + math.cos(math.radians(rot)) * side * 41.0,
                           run, 2.0, rot)
            s.polygon("DimBand", [b.p(x, 0.5, z) for x, z in g2.cw(edge)])
    for i in range(-n, n + 1):
        c = i * step
        if abs(c) < half:
            continue
        for lo, hi in ((-outer, outer),):
            b.up("CityRoad", c - 9.0, lo, c + 9.0, hi, 0.2)
            b.up("CityRoad", lo, c - 9.0, hi, c + 9.0, 0.2)
            if i % 2 == 0:
                b.up("DimLamp", c - 0.8, lo, c + 0.8, hi, 0.35)
                b.up("DimLamp", lo, c - 0.8, hi, c + 0.8, 0.35)
    for i in range(-n, n):
        for j in range(-n, n):
            x0, z0 = i * step + 14.0, j * step + 14.0
            x1, z1 = (i + 1) * step - 14.0, (j + 1) * step - 14.0
            mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
            if max(abs(mx), abs(mz)) < half + step * 0.5 or math.hypot(mx, mz) > outer - step * 0.5:
                continue
            # (Clear of the river's line, carried on past the middle.)
            t = ((mx - ax) * rdx + (mz - az) * rdz) / (rdx * rdx + rdz * rdz)
            px, pz = ax + rdx * t, az + rdz * t
            if math.hypot(mx - px, mz - pz) < 150.0:
                continue
            if rng.random() < 0.55:
                continue
            tall = rng.random() < 0.07
            floors = int(rng.uniform(30, 60)) if tall else int(rng.uniform(3, 16))
            inset = rng.uniform(0.0, 30.0)
            top = floors * 12.0
            bx0, bz0, bx1, bz1 = x0 + inset, z0 + inset, x1 - inset, z1 - inset
            clad = "CityFacade" if rng.random() < 0.75 else "CityFacadeWarm"
            sides = (((bx0, bz0), (bx1, bz0), (0, -1)), ((bx1, bz0), (bx1, bz1), (1, 0)), ((bx1, bz1), (bx0, bz1), (0, 1)),
                     ((bx0, bz1), (bx0, bz0), (-1, 0)))
            for a, bb, out in sides:
                b.side(clad, a, bb, 0.0, top, out)
                if rng.random() < 0.22:
                    y = rng.randrange(0, max(1, floors)) * 12.0 + 4.0
                    pa = (a[0] + out[0] * 0.6, a[1] + out[1] * 0.6)
                    pb = (bb[0] + out[0] * 0.6, bb[1] + out[1] * 0.6)
                    b.side("DimWarm" if rng.random() < 0.2 else "DimWindow", pa, pb, y, y + 5.0, out)
            b.up("CityRoof", bx0, bz0, bx1, bz1, top)
            if tall and rng.random() < 0.5:
                s.blinker(b.p((bx0 + bx1) / 2, top + 3.0, (bz0 + bz1) / 2), (190, 205, 230), 1.8 + rng.random(), 1.2,
                          rng.uniform(0, 2.0))


def landing(s, b):
    """The hall under the rift's middle: broad and low among the towers, a ring of light on its roof. The roof
    is solid, the one thing down here that is: a dive ends on it (anchor `landing`: its middle, w and h its
    sides, r the ring)."""
    w, d, floors = P.LANDING
    rng = random.Random(4242)
    roof = b.block(rng, -w, -d, w, d, floors, 0.5) + 1.5
    ring = P.LANDING_RING / K
    n = 28
    for k in range(n):
        a0, a1 = math.tau * k / n, math.tau * (k + 1) / n
        quad = [(math.cos(a) * r, math.sin(a) * r) for a, r in ((a0, ring - 3.0), (a1, ring - 3.0), (a1, ring + 3.0),
                                                                (a0, ring + 3.0))]
        s.polygon("DimBand", [b.p(x, roof + 0.4, z) for x, z in g2.cw(quad)])
    mark = [(math.cos(math.tau * k / 12) * 5.0, math.sin(math.tau * k / 12) * 5.0) for k in range(12)]
    s.polygon("DimBandWarm", [b.p(x, roof + 0.4, z) for x, z in g2.cw(mark)])
    for sx in (-w, w):
        for sz in (-d, d):
            s.blinker(b.p(sx, roof + 2.0, sz), (190, 205, 230), 2.4, 0.9, rng.uniform(0, 2.4))
    y = P.LANDING_Y
    s.collider((b.cx, y - 2.0, b.cz), (2 * w * K, 4.0, 2 * d * K), 0.0, True, "Concrete")
    s.anchor("landing", b.cx, y, b.cz, 0.0, w=round(2 * w * K, 2), h=round(2 * d * K, 2), r=P.LANDING_RING)
    s.light("point", (b.cx, y + 9.0, b.cz), (190, 205, 230), 40, 0.9)


def build(s):
    hole(s)
    cloud(s)
    below(s)
