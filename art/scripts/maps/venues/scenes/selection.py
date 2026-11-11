"""Dead by selection (art/refs/deaths/selection.md), the place redone 2026-11-11 to the user's second picture: an old
cemetery at night in fog, under the stars (SkySceneNight; the fog is the scene's look, LightingPresets.selection).
Ahead of the victim, a little to the right, the angel on her tall pedestal: a robed figure, wings raised and fanned
behind, one hand at her breast, a wreath hanging from the other, facing them. Round her the stones crowd in, tall
and old, many of them leaning: round-topped slabs on plinths, arched headstones, crosses, an urn on its column, an
obelisk; bare trees in the fog. At the angel's foot and by a stone at the left, mounds of melted white wax with
candles burning on them (the user's first picture; the flames are the scene's own, Selection.luau CANDLES).

Scene space: the victim at the origin facing -Z, on flat grass; the ground rolls away beyond 8 studs.
"""

import math
import random

from maps import mesher
from maps.venues.scenes import models, parts
from maps.venues.scenes import plan as P

OX, OZ = P.SELECTION
ANGEL = (3.8, -7.6)  # her pedestal's middle; she faces +Z (the victim)
# The candles: (x, base height, z, height) in scene space. Selection.luau's CANDLES lights a flame on each tip.
CANDLES = [
    (2.2, 0.6, -4.3, 0.9), (2.8, 0.6, -4.6, 1.25), (2.55, 0.6, -3.95, 0.6), (1.95, 0.42, -4.75, 0.5),
    (5.05, 1.15, -4.75, 0.8), (5.95, 0.52, -4.3, 1.05),
    (-3.1, 0.5, -3.5, 0.7), (-3.55, 0.5, -3.85, 1.1),
]
MOUNDS = [  # (x, z, radius, height): the wax heaps the candles stand on
    (2.45, -4.35, 1.05, 0.6), (5.25, -4.65, 0.85, 0.52), (-3.3, -3.65, 0.8, 0.5),
]
COLUMN = (5.2, -4.75, 0.48, 1.15)  # a tall pillar of run wax on the second heap


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def ground_h(x, z):
    """Flat where the victim and the camera stand, rolling a little through the graves, sinking away far off."""
    r = math.hypot(x, z)
    return (0.45 * parts.noise2(x, z, seed=31, octaves=3, scale=26.0) * smooth(7.0, 16.0, r)
            - smooth(60.0, 160.0, r) * 4.0)


def W(x, y, z):
    return (OX + x, y, OZ + z)


def quad2(s, mat, pts):
    """A thin blade seen from both sides."""
    n = mesher.cross(mesher.sub(pts[1], pts[0]), mesher.sub(pts[2], pts[0]))
    parts.poly(s, mat, pts, n, [(0, 0)] * len(pts))
    parts.poly(s, mat, list(reversed(pts)), (-n[0], -n[1], -n[2]), [(0, 0)] * len(pts))


def slab(s, mat, x, z, rot, w, h, t, lean=0.0, tilt=0.0, sink=0.35, cap=True, y=0.0):
    """A tall stone slab, leaning `lean` degrees forward (its face to rot) and `tilt` to its side, sunk into the
    ground; a rounded cap (a half cylinder across its top) when cap."""
    turn = mesher.ry(rot)
    ux, back, up = turn((1, 0, 0)), turn((0, 0, 1)), (0, 1, 0)
    l, k = math.radians(lean), math.radians(tilt)
    uy = mesher.norm(tuple(math.cos(l) * up[i] - math.sin(l) * back[i] + math.sin(k) * ux[i] for i in range(3)))
    uz = mesher.norm(mesher.cross(ux, uy))
    ux = mesher.cross(uy, uz)
    base = (OX + x, y - sink, OZ + z)
    centre = tuple(base[i] + uy[i] * h / 2 for i in range(3))
    s.obox(mat, centre, (w, h, t), ux, uy, uz)
    if cap:
        # the rounded top: a half disc of the slab's thickness, in segments
        top = tuple(base[i] + uy[i] * h for i in range(3))
        n = 8
        for j in range(n):
            a0, a1 = math.pi * j / n, math.pi * (j + 1) / n
            pts = []
            for a in (a0, a1):
                pts.append(tuple(top[i] + ux[i] * math.cos(a) * w / 2 + uy[i] * math.sin(a) * w * 0.32 for i in range(3)))
            for side in (1, -1):
                face = [top, pts[0], pts[1]]
                face = [tuple(p[i] + uz[i] * side * t / 2 for i in range(3)) for p in face]
                parts.poly(s, mat, face, tuple(uz[i] * side for i in range(3)))
            rim = [tuple(p[i] + uz[i] * sd * t / 2 for i in range(3)) for p, sd in
                   ((pts[0], 1), (pts[1], 1), (pts[1], -1), (pts[0], -1))]
            mid = ((pts[0][0] + pts[1][0]) / 2 - top[0], (pts[0][1] + pts[1][1]) / 2 - top[1],
                   (pts[0][2] + pts[1][2]) / 2 - top[2])
            parts.poly(s, mat, rim, mid)
    # its plinth, square on the ground
    s.box(mat, W(x, y + 0.12, z), (w + 0.4, 0.5, t + 0.45), rot)


def cross_stone(s, mat, x, z, rot, h, lean=0.0, y=0.0):
    turn = mesher.ry(rot)
    ux, back, up = turn((1, 0, 0)), turn((0, 0, 1)), (0, 1, 0)
    l = math.radians(lean)
    uy = mesher.norm(tuple(math.cos(l) * up[i] - math.sin(l) * back[i] for i in range(3)))
    uz = mesher.norm(mesher.cross(ux, uy))
    base = (OX + x, y - 0.3, OZ + z)
    s.obox(mat, tuple(base[i] + uy[i] * h / 2 for i in range(3)), (0.32, h, 0.3), ux, uy, uz)
    arm = tuple(base[i] + uy[i] * h * 0.72 for i in range(3))
    s.obox(mat, arm, (h * 0.5, 0.3, 0.3), ux, uy, uz)
    s.box(mat, W(x, y + 0.1, z), (0.9, 0.45, 0.8), rot)


def urn_column(s, x, z, y=0.0):
    """The urn monument of the picture's left: a stepped base, a square column with a cornice, an urn with a lid."""
    m = "HeadstoneDark"
    s.box(m, W(x, y + 0.3, z), (2.6, 0.6, 2.6))
    s.box(m, W(x, y + 0.75, z), (2.1, 0.3, 2.1))
    s.box(m, W(x, y + 2.3, z), (1.6, 2.8, 1.6))
    s.box(m, W(x, y + 3.85, z), (2.0, 0.3, 2.0))
    s.lathe(m, W(x, y + 4.0, z), [(0.45, 0.0), (0.2, 0.25), (0.3, 0.45), (0.62, 0.9), (0.68, 1.25), (0.5, 1.6),
                                  (0.3, 1.72), (0.36, 1.85), (0.12, 2.1), (0.0, 2.2)], segments=20)


def obelisk(s, x, z, h, y=0.0):
    m = "HeadstoneDark"
    s.box(m, W(x, y + 0.35, z), (2.4, 0.7, 2.4))
    s.box(m, W(x, y + 0.95, z), (1.8, 0.5, 1.8))
    s.lathe(m, W(x, y + 1.2, z), [(1.0, 0.0), (0.68, h), (0.0, h + 0.8)], segments=4)


def angel(s):
    """The angel on her pedestal (the picture's right): a tall pedestal of three courses with a sunk panel, she stands
    on its top in a long robe gathered at the waist, her head bowed a little, one hand at her breast, a wreath hanging
    from the other; two great wings raised behind her shoulders, their feathers fanned in three layers."""
    m, pale = "HeadstoneDark", "HeadstonePale"
    ax, az = ANGEL
    rot = 180.0  # she faces +Z

    def L(u, v, w):
        return parts.place((u, v, w), OX + ax, 0.0, OZ + az, rot)

    # the pedestal
    s.box(m, W(ax, 0.35, az), (3.2, 0.7, 3.0))
    s.box(m, W(ax, 0.85, az), (2.7, 0.35, 2.5))
    s.box(m, W(ax, 2.3, az), (2.2, 2.6, 2.0))
    s.box(m, W(ax, 2.3, az + 1.02), (1.6, 1.8, 0.06))  # the sunk panel's frame, toward the victim
    s.box(m, W(ax, 3.75, az), (2.6, 0.3, 2.4))
    s.box(m, W(ax, 4.05, az), (1.9, 0.3, 1.7))
    y0 = 4.2
    # the robe: a long turned body, wider at the hem, narrow at the waist, the shoulders, the neck
    s.lathe(pale, W(ax, y0, az), [(0.82, 0.0), (0.74, 0.5), (0.62, 1.4), (0.5, 2.2), (0.44, 2.6), (0.52, 3.05),
                                  (0.58, 3.35), (0.42, 3.6), (0.16, 3.72), (0.13, 3.85)], segments=22)
    # folds down the robe: thin ridges
    for k in range(9):
        a = math.tau * k / 9
        bottom = L(math.cos(a) * 0.8, y0 + 0.05, math.sin(a) * 0.8)
        top = L(math.cos(a) * 0.48, y0 + 2.3, math.sin(a) * 0.48)
        s.tube(pale, bottom, top, 0.06, segments=5)
    # the head, bowed forward a little
    hx, hy, hz = L(0.0, y0 + 4.12, -0.08)
    s.lathe(pale, (hx, hy - 0.3, hz), [(0.0, 0.0), (0.2, 0.06), (0.28, 0.24), (0.29, 0.38), (0.24, 0.52), (0.12, 0.6),
                                       (0.0, 0.62)], segments=16)
    # hair gathered at the back
    s.lathe(pale, L(0.0, y0 + 3.86, 0.18), [(0.0, 0.0), (0.18, 0.08), (0.2, 0.3), (0.0, 0.42)], segments=10)
    # the arms: the right hand at the breast, the left down at the side holding the wreath
    s.bent_tube(pale, [L(-0.55, y0 + 3.3, 0.0), L(-0.62, y0 + 2.75, -0.2), L(-0.15, y0 + 2.95, -0.42)],
                [0.15, 0.13, 0.1], segments=7)
    s.bent_tube(pale, [L(0.55, y0 + 3.3, 0.0), L(0.68, y0 + 2.6, -0.05), L(0.74, y0 + 1.95, -0.2)],
                [0.15, 0.13, 0.1], segments=7)
    wreath = [L(0.76 + math.cos(a) * 0.3, y0 + 1.6 + math.sin(a) * 0.32, -0.25) for a in
              [math.tau * k / 14 for k in range(15)]]
    s.bent_tube(m, wreath, [0.08] * len(wreath), segments=5)
    # the wings, raised behind her (the picture's): a leading edge curving up and out from each shoulder blade to a
    # high tip; from it the feathers, turning along it from hanging down at the root to reaching up and out at the
    # tip, long flight feathers behind and two shorter rows of coverts over them
    for side in (-1, 1):
        def edge(u):
            return (side * (0.3 + 1.05 * u - 0.15 * u * u), y0 + 3.3 + 3.0 * u - 0.6 * u * u, 0.4 + 0.35 * u)

        for layer, (count, length, width) in enumerate(((13, 1.7, 0.3), (10, 1.05, 0.32), (8, 0.55, 0.3))):
            for k in range(count):
                u = 0.04 + 0.96 * k / (count - 1)
                start = edge(u * (1 - 0.06 * layer))
                # the feather's way: down and a little out at the root, up and out at the tip
                ang = math.radians(-100 + 150 * u ** 1.3)
                d = (side * math.cos(ang) * 0.8 + side * 0.3, math.sin(ang), 0.12)
                dl = math.sqrt(sum(c * c for c in d))
                d = tuple(c / dl for c in d)
                reach = length * (0.75 + 0.5 * math.sin(math.pi * min(1.0, u * 1.1)))
                start = (start[0], start[1], start[2] - 0.05 * layer)
                tip = tuple(start[i] + d[i] * reach for i in range(3))
                across = mesher.norm(mesher.cross(d, (0, 0, 1)))
                half = width / 2
                p0 = tuple(start[i] - across[i] * half * 0.7 for i in range(3))
                p1 = tuple(start[i] + across[i] * half * 0.7 for i in range(3))
                mid = tuple(start[i] + d[i] * reach * 0.62 for i in range(3))
                p2 = tuple(mid[i] + across[i] * half for i in range(3))
                p3 = tuple(mid[i] - across[i] * half for i in range(3))
                mat = m if layer == 0 else pale
                quad2(s, mat, [L(*p0), L(*p1), L(*p2), L(*p3)])
                quad2(s, mat, [L(*p3), L(*p2), L(*tip)])
        # the wing's bone along its leading edge
        bone = [L(*edge(u / 8)) for u in range(9)]
        s.bent_tube(pale, bone, [0.14 - 0.012 * k for k in range(9)], segments=6)


def candles(s):
    """The wax: heaps of melted white candle wax, run down in drips, candles standing out of them."""
    wax = "PaintWhite"
    r = random.Random(77)
    for x, z, rad, h in MOUNDS:
        prof = [(rad, 0.0), (rad * 0.94, h * 0.3), (rad * 0.78, h * 0.62), (rad * 0.52, h * 0.88), (rad * 0.2, h),
                (0.0, h)]
        s.lathe(wax, W(x, -0.05, z), prof, segments=18)
        # drips down its sides and lumps at its foot
        for k in range(14):
            a = r.uniform(0, math.tau)
            top = (x + math.cos(a) * rad * 0.55, h * 0.85, z + math.sin(a) * rad * 0.55)
            foot = (x + math.cos(a) * rad * 1.02, 0.0, z + math.sin(a) * rad * 1.02)
            s.tube(wax, W(*top), W(*foot), r.uniform(0.04, 0.08), segments=5)
        for k in range(6):
            a = r.uniform(0, math.tau)
            s.lathe(wax, W(x + math.cos(a) * rad * 1.05, -0.05, z + math.sin(a) * rad * 1.05),
                    [(0.18, 0.0), (0.12, 0.1), (0.0, 0.14)], segments=8)
    cx, cz, crad, ch = COLUMN
    s.lathe(wax, W(cx, 0.4, cz), [(crad, 0.0), (crad * 0.9, ch * 0.5), (crad * 0.8, ch - 0.35), (crad * 0.55, ch - 0.4),
                                   (0.0, ch - 0.38)], segments=16)
    for k in range(12):
        a = math.tau * k / 12 + r.uniform(-0.2, 0.2)
        s.tube(wax, W(cx + math.cos(a) * crad * 0.8, ch - 0.1, cz + math.sin(a) * crad * 0.8),
               W(cx + math.cos(a) * crad * 0.98, 0.45 + r.uniform(0, 0.35), cz + math.sin(a) * crad * 0.98), 0.05,
               segments=5)
    for x, base, z, h in CANDLES:
        s.cylinder(wax, W(x, base - 0.1, z), 0.075, h + 0.1, segments=10)
        s.cylinder("Tyre", W(x, base + h, z), 0.012, 0.07, segments=4)  # the wick
        # a collar of run wax where it stands, and a drip down its side
        s.lathe(wax, W(x, base - 0.05, z), [(0.16, 0.0), (0.11, 0.08), (0.08, 0.14)], segments=10)
        s.tube(wax, W(x + 0.07, base + h - 0.05, z), W(x + 0.08, base + h * 0.4, z + 0.01), 0.018, segments=4)


def build(s):
    def h(wx, wz):
        return ground_h(wx - OX, wz - OZ)

    def step(wx, wz):
        d = max(abs(wx - OX), abs(wz - OZ))
        return 2.0 if d < 50 else (5.0 if d < 110 else 12.0)

    parts.heightfield(s, "MeadowGrass", OX - 180, OZ - 180, OX + 180, OZ + 180, step, h)
    angel(s)
    candles(s)
    # the stones close round the victim and the angel (the picture's own crowd): tall slabs leaning, old headstones
    near = [  # (x, z, rot, w, h, lean, tilt, kind)
        (-2.4, -6.8, 0, 2.0, 3.6, 4, -3, "slab"), (-5.2, -7.6, 8, 1.8, 3.0, -3, 5, "slab"),
        (0.6, -10.5, -4, 2.2, 3.8, 6, 2, "slab"), (7.4, -6.6, -10, 1.6, 4.2, -5, -4, "slab"),
        (-3.6, -2.4, 15, 1.4, 2.2, 7, 6, "arch"), (6.8, -2.6, -20, 1.5, 2.6, 3, -8, "slab"),
        (-7.8, -3.4, 5, 1.6, 2.6, -6, 3, "slab"), (8.8, -10.2, 0, 1.9, 3.4, 4, 3, "slab"),
        (-1.0, -14.5, 0, 1.6, 2.4, 0, 0, "cross"), (5.6, -12.8, 0, 1.6, 3.0, -3, 0, "cross"),
        (-6.4, -12.0, 10, 1.4, 2.4, 2, -5, "arch"), (3.4, -16.0, 0, 2.0, 3.2, 5, -2, "slab"),
    ]
    for x, z, rot, w, hh, lean, tilt, kind in near:
        y = ground_h(x, z)
        mat = "HeadstoneDark" if (int(x * 3 + z) % 3) else "HeadstonePale"
        if kind == "slab":
            slab(s, mat, x, z, rot, w, hh, 0.5, lean=lean, tilt=tilt, y=y)
        elif kind == "cross":
            cross_stone(s, mat, x, z, rot, hh, lean=lean, y=y)
        else:
            parts.headstone(s, mat, OX + x, OZ + z, rot + 180 if z > 0 else rot, w=w, h=hh, t=0.4, sink=0.4, y=y,
                            engrave=True, plinth=True)
    urn_column(s, -9.5, -15.0, ground_h(-9.5, -15.0))
    obelisk(s, 12.5, -19.0, 6.5, ground_h(12.5, -19.0))
    # the crowd beyond, fading into the fog: rows that wander, every stone its own
    r = random.Random(11)
    for k in range(260):
        a = r.uniform(0, math.tau)
        d = 9.0 + abs(r.gauss(0, 28))
        x, z = math.cos(a) * d, math.sin(a) * d - 4.0
        if math.hypot(x, z) < 6.0 or (-8.0 < x < 3.0 and 4.0 < z < 14.0) or (0.5 < x < 7.5 and -10.0 < z < -2.5):
            continue  # (the victim's ground, the wide shot's line, the angel and the candles)
        y = ground_h(x, z)
        rot = r.uniform(-12, 12) + (180 if z > 0 else 0)
        mat = "HeadstonePale" if r.random() < 0.25 else "HeadstoneDark"
        pick = r.random()
        if pick < 0.45:
            slab(s, mat, x, z, rot, r.uniform(1.2, 2.1), r.uniform(1.8, 3.6), r.uniform(0.35, 0.55),
                 lean=r.uniform(-7, 7), tilt=r.uniform(-6, 6), y=y, cap=r.random() < 0.7)
        elif pick < 0.8:
            parts.headstone(s, mat, OX + x, OZ + z, rot, w=r.uniform(1.1, 1.6), h=r.uniform(1.6, 2.4), t=0.34,
                            sink=0.4, y=y, engrave=d < 25, plinth=r.random() < 0.4, arch=5)
        elif pick < 0.93:
            cross_stone(s, mat, x, z, rot, r.uniform(1.8, 3.0), lean=r.uniform(-6, 6), y=y)
        elif d > 18:
            obelisk(s, x, z, r.uniform(3.5, 6.0), y)
    # grass tufts round the victim and the stones near
    for k in range(520):
        a = r.uniform(0, math.tau)
        d = 1.2 + abs(r.gauss(0, 9))
        x, z = math.cos(a) * d, math.sin(a) * d - 3.0
        if math.hypot(x, z) < 1.0 or any(math.hypot(x - mx, z - mz) < mr + 0.3 for mx, mz, mr, _ in MOUNDS):
            continue
        models.grass_clump(s, OX + x, OZ + z, ground_h(x, z), seed=k, blades=7, height=(0.3, 0.8), spread=0.3,
                           dry=0.45)
    # bare trees in the fog
    for k in range(18):
        a = r.uniform(0, math.tau)
        d = r.uniform(16, 70)
        x, z = math.cos(a) * d, math.sin(a) * d - 6
        if -9 < x < 4 and z > 2:
            continue
        parts.bare_tree(s, "Bark", OX + x, OZ + z, ground_h(x, z), r.uniform(18, 30), seed=300 + k, levels=3,
                        trunk=r.uniform(0.5, 0.9), spread=r.uniform(26, 38), sides=6)
    parts.bare_tree(s, "Bark", OX - 10.0, OZ - 7.0, ground_h(-10.0, -7.0), 22.0, seed=290, levels=4, trunk=0.8,
                    lean=(0.06, 0.03))
