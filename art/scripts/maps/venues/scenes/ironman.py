"""and I.. am.. (art/refs/deaths/ironman.md): a ruined battlefield at dusk. Churned mud pocked with craters, broken
concrete and rubble everywhere; right behind the victim (z = 2.8) the broken wall they slide down against, rebar
sticking out of its torn top; burnt-out shells of buildings standing round at every distance, their windows holes and
their tops torn away, dark against the orange sky (SkySceneEmber); smoke is the scene's own.

Scene space: the victim at the origin facing -Z (kneeling, then the wall at their back); the warlord at (0, 0, -6.5)
and his army in rows behind him (z -12 to -18): the ground there is flat and clear.
"""

import math
import random

from maps.venues.scenes import models, parts
from maps.venues.scenes import plan as P

OX, OZ = P.IRONMAN
CRATERS = ((14, -26, 7), (-20, -34, 9), (26, 10, 6), (-30, 14, 8), (6, -48, 10), (-8, 28, 5), (40, -40, 12),
           (-46, -10, 9), (34, 40, 10), (-24, 56, 11))


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def ground_h(x, z):
    r = math.hypot(x, z)
    flat = 1 - smooth(6, 22, max(r, math.hypot(x * 1.6, z + 14)))  # (the actors' and the army's ground)
    y = 0.5 * parts.noise2(x, z, seed=41, octaves=4, scale=22.0)
    for cx, cz, cr in CRATERS:
        d = math.hypot(x - cx, z - cz) / cr
        if d < 1.6:
            y += -2.2 * max(0.0, 1 - d * d) + 0.7 * math.exp(-((d - 1.05) ** 2) * 18)
    y += smooth(120, 300, r) * (6 + 6 * parts.noise2(x, z, seed=42, octaves=2, scale=120.0))
    return y * (1 - flat)


def jagged_wall(s, mat, x0, z0, x1, z1, base_y, height, thick, seed, holes=(), broken=0.5, step=0.7):
    """A broken wall from (x0, z0) to (x1, z1): drawn as narrow upright strips, its top torn to random heights,
    rectangular holes (u0, u1, y0, y1 along it) left open; both faces, ends and the strips' tops."""
    r = random.Random(seed)
    length = math.hypot(x1 - x0, z1 - z0)
    ux, uz = (x1 - x0) / length, (z1 - z0) / length
    nx, nz = -uz, ux
    n = max(2, int(length / step))
    tops = []
    t = height
    for k in range(n):
        # (a torn edge: wandering slowly, with now and then a sharp break)
        jump = r.uniform(-0.35, 0.35) * height if r.random() < 0.12 else r.gauss(0, 0.05) * height
        t = max(height * (1 - broken), min(height, t + jump))
        tops.append(t)
    for k in range(n):
        u0, u1 = length * k / n, length * (k + 1) / n
        spans = [(0.0, tops[k])]
        for hu0, hu1, hy0, hy1 in holes:
            if u0 >= hu0 and u1 <= hu1:
                spans = [(a, b) for a, b in ((0.0, hy0), (hy1, tops[k])) if b > a]
        for y0, y1 in spans:
            for side in (-1, 1):
                ox, oz = nx * side * thick / 2, nz * side * thick / 2
                quad = [(x0 + ux * u0 + ox, base_y + y0, z0 + uz * u0 + oz), (x0 + ux * u1 + ox, base_y + y0, z0 + uz * u1 + oz),
                        (x0 + ux * u1 + ox, base_y + y1, z0 + uz * u1 + oz), (x0 + ux * u0 + ox, base_y + y1, z0 + uz * u0 + oz)]
                parts.poly(s, mat, quad, (nx * side, 0, nz * side),
                           [(u0, y0), (u1, y0), (u1, y1), (u0, y1)])
            for y in (y1,) + ((y0,) if y0 > 0 else ()):
                quad = [(x0 + ux * u0 - nx * thick / 2, base_y + y, z0 + uz * u0 - nz * thick / 2),
                        (x0 + ux * u1 - nx * thick / 2, base_y + y, z0 + uz * u1 - nz * thick / 2),
                        (x0 + ux * u1 + nx * thick / 2, base_y + y, z0 + uz * u1 + nz * thick / 2),
                        (x0 + ux * u0 + nx * thick / 2, base_y + y, z0 + uz * u0 + nz * thick / 2)]
                parts.poly(s, mat, quad, (0, 1 if y == y1 else -1, 0))
        # the strip's sides where its neighbour is lower (the torn edge) or at the wall's ends
        for u, other, sgn in ((u0, tops[k - 1] if k > 0 else 0.0, -1), (u1, tops[k + 1] if k < n - 1 else 0.0, 1)):
            if other < tops[k]:
                lo = other
                quad = [(x0 + ux * u - nx * thick / 2, base_y + lo, z0 + uz * u - nz * thick / 2),
                        (x0 + ux * u + nx * thick / 2, base_y + lo, z0 + uz * u + nz * thick / 2),
                        (x0 + ux * u + nx * thick / 2, base_y + tops[k], z0 + uz * u + nz * thick / 2),
                        (x0 + ux * u - nx * thick / 2, base_y + tops[k], z0 + uz * u - nz * thick / 2)]
                parts.poly(s, mat, quad, (ux * sgn, 0, uz * sgn))
    return tops


def shell(s, x, z, w, d, h, seed, rot=0.0, mat="ConcreteDark"):
    """A burnt-out building: four torn walls with rows of window holes, no roof."""
    r = random.Random(seed)
    corners = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]
    a = math.radians(rot)

    def at(px, pz):
        return (x + px * math.cos(a) + pz * math.sin(a), z - px * math.sin(a) + pz * math.cos(a))

    for k in range(4):
        (ax, az), (bx, bz) = corners[k], corners[(k + 1) % 4]
        length = math.hypot(bx - ax, bz - az)
        holes = []
        for floor in range(int(h // 6)):
            for j in range(int(length // 6)):
                u = 2.0 + j * 6
                if u + 2.5 < length:
                    holes.append((u, u + 2.4, floor * 6 + 2.0, floor * 6 + 4.6))
        (wx0, wz0), (wx1, wz1) = at(ax, az), at(bx, bz)
        jagged_wall(s, mat, wx0, wz0, wx1, wz1, -0.5, h * r.uniform(0.6, 1.0), 1.0, seed * 10 + k, holes,
                    broken=0.6, step=2.0)


def build(s):
    def h(wx, wz):
        return ground_h(wx - OX, wz - OZ)

    def step(wx, wz):
        d = max(abs(wx - OX), abs(wz - OZ))
        return 2.0 if d < 60 else (5.0 if d < 160 else 12.0)

    parts.heightfield(s, "WarMud", OX - 340, OZ - 340, OX + 340, OZ + 340, step, h)
    r = random.Random(9)
    # the broken wall behind the victim (they slide down it): concrete, torn top, a hole, rebar from the tear
    tops = jagged_wall(s, "ConcreteDark", OX - 4.0, OZ + 3.4, OX + 5.0, OZ + 2.6, -0.3, 6.4, 1.0, 77,
                       holes=((5.6, 7.0, 2.6, 4.2),), broken=0.45, step=0.45)
    for k in range(9):
        u = 0.6 + k * 0.95
        top = tops[min(len(tops) - 1, int(u / 9.0 * len(tops)))]
        bx, bz = OX - 4.0 + u * 1.0, OZ + 3.4 - u * 0.09
        s.tube("BlackMetal", (bx, top - 0.6, bz), (bx + r.uniform(-0.5, 0.5),
               top + r.uniform(0.6, 1.8), bz + r.uniform(-0.4, 0.4)), 0.05, 4)
    # rubble: broken blocks and stones strewn round, heaps at the walls' feet (never on the actors' marks)
    for k in range(160):
        a = r.uniform(0, math.tau)
        d = r.uniform(4, 70)
        x, z = math.cos(a) * d, math.sin(a) * d
        if abs(x) < 9 and -20 < z < 2.2:
            continue  # (the victim, the warlord and the army)
        size = r.uniform(0.25, 1.4) * (1 + d / 80)
        wx, wz = OX + x, OZ + z
        models.rock(s, "WarRubble" if k % 3 else "ConcreteDark", (wx, h(wx, wz), wz),
                   (size * 1.4, size * 0.6, size), seed=1000 + k, rot=r.uniform(0, 360), segs=(7, 5),
                   sink=0.3, flat_top=0.3)
    for k in range(12):  # (the heap at the broken wall's foot)
        x, z = r.uniform(-4, 5), r.uniform(3.6, 5.0)
        q = r.uniform(0.3, 0.8)
        models.rock(s, "ConcreteDark", (OX + x, 0, OZ + z), (q * 1.3, q * 0.7, q), seed=1300 + k,
                   rot=r.uniform(0, 360), segs=(7, 5), sink=0.3, flat_top=0.4)
    # torn wall fragments near, burnt-out shells further, a skyline of ruins far off
    for k, (x, z, w, rot) in enumerate(((-12, -18, 6, 20), (14, -22, 8, -15), (-18, 8, 7, 70), (16, 12, 9, 100),
                                        (-6, 18, 5, 10))):
        wx, wz = OX + x, OZ + z
        a = math.radians(rot)
        jagged_wall(s, "ConcreteDark" if k % 2 else "BrickDark", wx - math.cos(a) * w / 2, wz + math.sin(a) * w / 2,
                    wx + math.cos(a) * w / 2, wz - math.sin(a) * w / 2, h(wx, wz) - 0.3, r.uniform(5, 10), 1.0,
                    300 + k, broken=0.6, step=0.6)
    for k, (x, z, w, d, hh) in enumerate(((-34, -46, 18, 14, 18), (30, -60, 22, 16, 24), (-60, -20, 16, 20, 14),
                                          (52, -14, 14, 14, 20), (-40, 40, 20, 16, 22), (44, 46, 16, 18, 16),
                                          (4, -90, 26, 18, 30), (-90, -70, 24, 20, 26), (96, -80, 22, 22, 28),
                                          (-110, 30, 26, 20, 24), (110, 24, 22, 18, 30), (0, 110, 30, 20, 26))):
        wx, wz = OX + x, OZ + z
        models.ruin(s, wx, wz, w, d, hh, 40 + k, rot=r.uniform(-25, 25), mat="ConcreteDark" if k % 3 else "BrickDark",
                    ground=h(wx, wz) - 0.4)
    for k in range(22):
        a = r.uniform(0, math.tau)
        dist = r.uniform(170, 280)
        x, z = math.cos(a) * dist, math.sin(a) * dist
        wx, wz = OX + x, OZ + z
        shell(s, wx, wz, r.uniform(20, 40), r.uniform(16, 30), r.uniform(26, 50), 90 + k, rot=r.uniform(0, 90),
              mat="ConcreteDark")
