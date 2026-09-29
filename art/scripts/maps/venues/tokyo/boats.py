"""The boats moored on the river, built as map geometry: a yakatabune against the north wall (a
roofed pleasure boat: a black lacquered hull with a red rub rail, a tatami cabin behind lit shoji,
a curved roof turned up at the front, red chochin along its eaves) and a small wooden work boat, a
tenma-sen, against the south wall (open, with ribs, thwarts, floorboards and a sculling oar, a
folded tarp, a bucket and a coil of rope). Both lie at the waterline (P.WATER_Y) in the channel's
Terrain water, fenders against the wall and lines up to rings in it. Nobody can reach them."""

import math

from maps import geo2d as g2
from maps.venues.tokyo import plan as P

WATERLINE = P.WATER_Y


class Frame:
    """A boat's own axes: u along it (+ towards the bow), v across it (+ to port), y up from the
    waterline; placed at centre (x, z) heading along direction."""

    def __init__(self, centre, direction):
        self.c = centre
        self.d = direction
        self.n = g2.normal_left(direction)
        self.rot = g2.rot_of(direction)  # a box's local x along the boat

    def xz(self, u, v):
        return (self.c[0] + self.d[0] * u + self.n[0] * v, self.c[1] + self.d[1] * u + self.n[1] * v)

    def p(self, u, v, y):
        x, z = self.xz(u, v)
        return (x, WATERLINE + y, z)

    def vec(self, du, dv, dy):
        """A direction in the boat's axes, in the world."""
        return (self.d[0] * du + self.n[0] * dv, dy, self.d[1] * du + self.n[1] * dv)

    def box(self, s, mat, u, v, y, size, skip=()):
        """A box centred at (u, v, y): size (along the boat, up, across)."""
        s.box(mat, self.p(u, v, y), size, self.rot, skip=skip)

    def facing(self, du, dv):
        """The rot of something facing along (du, dv) in the boat's axes."""
        x, _, z = self.vec(du, dv, 0)
        return math.degrees(math.atan2(-x, -z))


def face(s, mat, pts, out):
    """A flat face through pts ((x, y, z) in order), turned to face `out` (x, y, z)."""
    (ax, ay, az), (bx, by, bz), (cx, cy, cz) = pts[0], pts[1], pts[-1]
    u = (bx - ax, by - ay, bz - az)
    v = (cx - ax, cy - ay, cz - az)
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
    if n[0] * out[0] + n[1] * out[1] + n[2] * out[2] < 0:
        pts = list(reversed(pts))
    s.polygon(mat, pts)


def profile(b, h, k, flare=0.9):
    """One side of a hull's section, from the gunwale down to the keel: (v, y) points. The top
    half-stud of the side is upright (the rub rail sits on it), then it flares in to a rounded
    bilge and the flat of the bottom."""
    return [(b, h), (b, h - 0.5), (b * flare, 0.0), (b * 0.72, k * 0.72), (b * 0.3, k), (0.0, k)]


def loft(s, f, stations, mat, inward=False):
    """A hull's skin between stations [(u, half beam, gunwale height, keel depth)], both sides,
    closed at the stern (a transom) and at the bow; its faces look out of the hull (or into it,
    for the inside of an open boat)."""
    sign = -1 if inward else 1
    for (u0, b0, h0, k0), (u1, b1, h1, k1) in zip(stations, stations[1:]):
        p0, p1 = profile(b0, h0, k0), profile(b1, h1, k1)
        for side in (1, -1):
            for j in range(len(p0) - 1):
                quad = [f.p(u0, side * p0[j][0], p0[j][1]), f.p(u0, side * p0[j + 1][0], p0[j + 1][1]),
                        f.p(u1, side * p1[j + 1][0], p1[j + 1][1]), f.p(u1, side * p1[j][0], p1[j][1])]
                # Out of the hull: away from its middle line (half-way between gunwale and keel).
                mid_v = side * (p0[j][0] + p0[j + 1][0] + p1[j][0] + p1[j + 1][0]) / 4
                mid_y = (p0[j][1] + p0[j + 1][1] + p1[j][1] + p1[j + 1][1]) / 4
                axis_y = (h0 + k0 + h1 + k1) / 4
                out = f.vec(0, mid_v, mid_y - axis_y)
                face(s, mat, _dedupe(quad), (out[0] * sign, out[1] * sign, out[2] * sign))
    for (u, b, h, k), du in ((stations[0], -1), (stations[-1], 1)):
        if b < 0.08:
            continue
        side_pts = profile(b, h, k)
        ring = [f.p(u, v, y) for v, y in side_pts] + [f.p(u, -v, y) for v, y in reversed(side_pts[:-1])]
        out = f.vec(du * sign, 0, 0)
        face(s, mat, _dedupe(ring), out)


def _dedupe(pts):
    out = []
    for p in pts:
        if not out or math.dist(out[-1], p) > 1e-4:
            out.append(p)
    if len(out) > 2 and math.dist(out[0], out[-1]) < 1e-4:
        out.pop()
    return out


def rub_rail(s, f, stations, mat, low=0.42, high=0.12, out=0.08):
    """A band standing proud of the upright top of the hull's side, all the way round."""
    for (u0, b0, h0, _), (u1, b1, h1, _) in zip(stations, stations[1:]):
        for side in (1, -1):
            a0, a1 = side * b0, side * b1
            e0, e1 = side * (b0 + out), side * (b1 + out)
            face(s, mat, [f.p(u0, e0, h0 - low), f.p(u1, e1, h1 - low), f.p(u1, e1, h1 - high),
                          f.p(u0, e0, h0 - high)], f.vec(0, side, 0))
            face(s, mat, [f.p(u0, a0, h0 - high), f.p(u1, a1, h1 - high), f.p(u1, e1, h1 - high),
                          f.p(u0, e0, h0 - high)], (0, 1, 0))
            face(s, mat, [f.p(u0, a0, h0 - low), f.p(u1, a1, h1 - low), f.p(u1, e1, h1 - low),
                          f.p(u0, e0, h0 - low)], (0, -1, 0))


def ring(s, centre, normal, radius=0.2, mat="BlackMetal"):
    """An iron mooring ring standing in a wall (its face looking along normal (x, z))."""
    t = (-normal[1], normal[0])
    pts = []
    for k in range(9):
        a = k / 8 * math.tau
        pts.append((centre[0] + t[0] * math.cos(a) * radius, centre[1] + math.sin(a) * radius,
                    centre[2] + t[1] * math.cos(a) * radius))
    for a, b in zip(pts, pts[1:]):
        s.tube(mat, a, b, 0.045, 5)


def line(s, a, b, sag=0.35, mat="Bamboo"):
    """A mooring line from a to b (x, y, z), sagging a little in the middle."""
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - sag, (a[2] + b[2]) / 2)
    s.tube(mat, a, mid, 0.05, 5)
    s.tube(mat, mid, b, 0.05, 5)


def _side_of(f):
    """1 when the frame's port side (+v) looks north (to the river's left bank), else -1."""
    (cx, cz), d = P.river_frame(f.c[0])
    n = g2.normal_left(d)
    return 1 if f.n[0] * n[0] + f.n[1] * n[1] > 0 else -1


def moor(s, cleat, x, offset, sag=0.35):
    """A ring in the channel wall at `offset`, under its top, near x; a line to it from the cleat
    (x, y, z)."""
    at, n = wall_point(x, offset, -0.8)
    into = -1 if offset > 0 else 1  # from the face of the wall out over the water
    ring(s, (at[0] + n[0] * into * 0.05, at[1], at[2] + n[1] * into * 0.05), n)
    line(s, cleat, (at[0] + n[0] * into * 0.1, at[1] - 0.25, at[2] + n[1] * into * 0.1), sag)


def wall_point(x, offset, y):
    """A point on the face of a channel wall (offset from the river's centre line) at height y."""
    (cx, cz), d = P.river_frame(x)
    n = g2.normal_left(d)
    return (cx + n[0] * offset, y, cz + n[1] * offset), n


# The yakatabune ---------------------------------------------------------------------------------------

YAKATA = [  # (u, half beam, gunwale height, keel depth): stern to bow, 20 studs long
    (-10.0, 2.0, 1.0, -0.8),
    (-9.0, 2.35, 0.92, -1.05),
    (-6.0, 2.5, 0.88, -1.2),
    (0.0, 2.5, 0.88, -1.2),
    (4.0, 2.46, 0.92, -1.15),
    (6.4, 2.2, 1.05, -1.0),
    (8.2, 1.62, 1.3, -0.72),
    (9.3, 0.85, 1.62, -0.32),
    (10.0, 0.04, 1.9, 0.35),
]
CABIN = (-7.2, 6.0)  # u extent of the cabin
CABIN_W = 2.0  # half width
FLOOR = 0.9  # the cabin floor (the deck)
EAVE = 4.4


def yakatabune(s, f, wall):
    """wall: the side (1 port, -1 starboard) that lies against the channel wall."""
    loft(s, f, YAKATA, "BlackTrim")
    rub_rail(s, f, YAKATA, "Vermilion")
    for (u0, b0, h0, _), (u1, b1, h1, _) in zip(YAKATA, YAKATA[1:]):
        for side in (1, -1):
            face(s, "BlackTrim", [f.p(u0, side * (b0 - 0.14), h0), f.p(u1, side * (b1 - 0.14), h1),
                                  f.p(u1, side * (b1 + 0.02), h1), f.p(u0, side * (b0 + 0.02), h0)], (0, 1, 0))
    # The deck: planks from end to end, a hair under the gunwale.
    for (u0, b0, h0, _), (u1, b1, h1, _) in zip(YAKATA, YAKATA[1:]):
        face(s, "WoodFloorDark", [f.p(u0, -b0, h0 - 0.08), f.p(u1, -b1, h1 - 0.08), f.p(u1, b1, h1 - 0.08),
                                  f.p(u0, b0, h0 - 0.08)], (0, 1, 0))
    cabin(s, f)
    roof(s, f)
    # The bow deck: a low rail round it, a coil of line; the stern: the helm and its lamp post.
    for side in (1, -1):
        pts = [f.p(6.6, side * 2.05, 1.9), f.p(8.2, side * 1.5, 2.15), f.p(9.3, side * 0.75, 2.45)]
        for a, b in zip(pts, pts[1:]):
            s.tube("BlackMetal", a, b, 0.05, 5)
        for u, v, y in ((6.6, 2.05, 1.9), (8.2, 1.5, 2.15), (9.3, 0.75, 2.45)):
            s.tube("BlackMetal", f.p(u, side * v, y - 0.95), f.p(u, side * v, y), 0.05, 5)
    s.lathe("Bamboo", f.p(7.6, -0.6, 1.12), [(0.1, 0.0), (0.45, 0.02), (0.5, 0.12), (0.4, 0.2), (0.1, 0.2)], 12)
    f.box(s, "Wood", -8.4, 0.0, 1.6, (0.3, 1.4, 0.3))
    f.box(s, "BlackTrim", -8.4, 0.0, 2.35, (0.6, 0.12, 1.6))
    # Fenders on the wall side, and the lines up to rings in the wall.
    for u in (-6.0, 0.5, 5.5):
        x, y, z = f.p(u, wall * 2.86, 0.0)
        s.cylinder("Rubber", (x, y - 0.1, z), 0.34, 0.95, segments=10)
        s.tube("Bamboo", f.p(u, wall * 2.76, 0.85), f.p(u, wall * 2.5, 0.88), 0.03, 4)
    offset = P.CHANNEL[1] if wall * _side_of(f) > 0 else P.CHANNEL[0]
    for u, bow in ((-8.8, False), (8.6, True)):
        v = wall * (1.5 if bow else 2.0)
        y = (1.5 if bow else 1.0) + 0.15
        f.box(s, "BlackMetal", u, v, y - 0.07, (0.5, 0.16, 0.18))
        wx, _ = f.xz(u + (1.5 if bow else -1.5), wall * 3.2)
        moor(s, f.p(u, v, y), wx, offset)
    # A warm light inside the cabin, spilling out over the water through the paper.
    s.light("point", f.p(-0.5, 0.0, 2.8), (255, 196, 140), 16, 0.9)


def cabin(s, f):
    """The cabin: dark timber below and above, a band of lit shoji between (paper panels in a
    lattice of dark bars), a door at the front with the boat's name over it."""
    a0, a1 = CABIN
    w = CABIN_W
    low, band0, band1, top = FLOOR, FLOOR + 0.7, EAVE - 0.5, EAVE
    walls = [  # (corner a, corner b, facing (du, dv)) round the cabin
        ((a0, w), (a1, w), (0, 1)),
        ((a1, -w), (a0, -w), (0, -1)),
        ((a1, w), (a1, -w), (1, 0)),
        ((a0, -w), (a0, w), (-1, 0)),
    ]
    for (ua, va), (ub, vb), (du, dv) in walls:
        out = f.vec(du, dv, 0)
        front = du == 1
        for y0, y1, mat in ((low, band0, "WoodPanel"), (band0, band1, "PanelWarm"), (band1, top, "WoodPanel")):
            if front and mat == "PanelWarm":
                continue
            face(s, mat, [f.p(ua, va, y0), f.p(ub, vb, y0), f.p(ub, vb, y1), f.p(ua, va, y1)], out)
        length = math.hypot(ub - ua, vb - va)
        tu, tv = (ub - ua) / length, (vb - va) / length
        if front:
            # Shoji either side of the door; the door itself dark lacquer.
            for c0, c1, mat in ((0.0, 1.3, "PanelWarm"), (1.3, 2.7, "BlackTrim"), (2.7, length, "PanelWarm")):
                face(s, mat, [f.p(ua + tu * c0, va + tv * c0, band0), f.p(ua + tu * c1, va + tv * c1, band0),
                              f.p(ua + tu * c1, va + tv * c1, band1), f.p(ua + tu * c0, va + tv * c0, band1)], out)
        # The lattice: uprights about every stud, two rails across, a frame round the band.
        count = max(2, round(length / 1.0))
        for k in range(count + 1):
            t = length * k / count
            uu, vv = ua + tu * t + du * 0.03, va + tv * t + dv * 0.03
            f.box(s, "BlackTrim", uu, vv, (band0 + band1) / 2, (0.09 if du == 0 else 0.06, band1 - band0,
                                                                 0.06 if du == 0 else 0.09))
        for y in (band0, band0 + (band1 - band0) / 3, band0 + (band1 - band0) * 2 / 3, band1):
            mu, mv = (ua + ub) / 2 + du * 0.035, (va + vb) / 2 + dv * 0.035
            size = (length, 0.08, 0.07) if du == 0 else (0.07, 0.08, length)
            f.box(s, "BlackTrim", mu, mv, y, size)
    # Corner posts.
    for u in (a0, a1):
        for v in (w, -w):
            f.box(s, "WoodPanel", u, v, (low + top) / 2, (0.22, top - low, 0.22), skip=("-y",))
    # The name board over the door.
    x, y, z = f.p(a1 + 0.13, 0.0, band1 + 0.24)
    s.sign((x, y, z), f.facing(1, 0), 1.9, 0.42, "屋形船  月影丸", "GothamBlack", (250, 236, 206), (26, 20, 18))


def roof(s, f):
    """A roof curved across the boat, its eaves out past the walls, turned up at the front."""
    a0, a1 = CABIN
    reach = CABIN_W + 0.5
    rise = 0.75
    us = [a0 - 0.5 + (a1 + 0.7 - (a0 - 0.5)) * k / 10 for k in range(11)]
    ts = [-1 + 2 * k / 8 for k in range(9)]

    def lift(u):
        front = max(0.0, (u - (a1 - 0.6)) / 1.3)
        back = max(0.0, ((a0 + 0.2) - u) / 0.7)
        return 0.38 * front * front + 0.12 * back * back

    def top(u, t):
        return f.p(u, t * reach, EAVE + rise * (1 - t * t) + lift(u))

    def under(u, t):
        return f.p(u, t * reach, EAVE - 0.16 + rise * (1 - t * t) * 0.92 + lift(u))

    for i in range(10):
        for j in range(8):
            u0, u1, t0, t1 = us[i], us[i + 1], ts[j], ts[j + 1]
            face(s, "Slate", [top(u0, t0), top(u1, t0), top(u1, t1), top(u0, t1)], (0, 1, 0))
            face(s, "WoodPanel", [under(u0, t0), under(u1, t0), under(u1, t1), under(u0, t1)], (0, -1, 0))
    for i in range(10):
        for t, dv in ((-1.0, -1), (1.0, 1)):
            face(s, "BlackTrim", [top(us[i], t), top(us[i + 1], t), under(us[i + 1], t), under(us[i], t)],
                 f.vec(0, dv, 0))
    for j in range(8):
        for u, du in ((us[0], -1), (us[-1], 1)):
            face(s, "BlackTrim", [top(u, ts[j]), top(u, ts[j + 1]), under(u, ts[j + 1]), under(u, ts[j])],
                 f.vec(du, 0, 0.2))
    # The vault closed over the cabin's walls: a gable at each end, a strip along each side.
    wt = CABIN_W / reach
    arch = [k / 8 for k in range(-8, 9)]
    for u, du in ((a0, -1), (a1, 1)):
        pts = [f.p(u, -CABIN_W, EAVE), f.p(u, CABIN_W, EAVE)] + [under(u, wt * k) for k in reversed(arch)]
        face(s, "WoodPanel", pts, f.vec(du, 0, 0))
    along = [a0] + [u for u in us if a0 < u < a1] + [a1]
    for side in (1, -1):
        for u0, u1 in zip(along, along[1:]):
            face(s, "WoodPanel", [f.p(u0, side * CABIN_W, EAVE), f.p(u1, side * CABIN_W, EAVE), under(u1, side * wt),
                                  under(u0, side * wt)], f.vec(0, side, 0))
    # The ridge.
    for i in range(10):
        s.tube("BlackTrim", top(us[i], 0.0), top(us[i + 1], 0.0), 0.12, 6)
    # Red chochin along both eaves, two of them lit.
    count = 7
    for side in (1, -1):
        for k in range(count):
            u = a0 + 0.4 + (a1 - a0 - 0.8) * k / (count - 1)
            x, z = f.xz(u, side * (CABIN_W + 0.3))
            s.prop("Chochin", x, z, f.facing(0, side), 0.6, WATERLINE + EAVE - 1.05, dark=k != 3)


# The tenma-sen ----------------------------------------------------------------------------------------

TENMA = [  # a small open work boat, 10 studs long
    (-5.0, 1.0, 0.72, -0.42),
    (-4.1, 1.22, 0.68, -0.52),
    (-1.0, 1.3, 0.66, -0.56),
    (2.0, 1.25, 0.7, -0.52),
    (3.8, 0.95, 0.82, -0.42),
    (4.7, 0.45, 0.98, -0.18),
    (5.0, 0.04, 1.1, 0.25),
]
PLANK = 0.12  # the hull's thickness
BOARDS = -0.28  # the floorboards' top


def tenma_sen(s, f, wall):
    """wall: the side (1 port, -1 starboard) that lies against the channel wall."""
    loft(s, f, TENMA, "Wood")
    # The inside, from the gunwale down to the floorboards, and the gunwale's cap between.
    inner = [(u, max(0.02, b - PLANK), h, k + PLANK) for u, b, h, k in TENMA]
    loft(s, f, inner, "WoodFloor", inward=True)
    for (u0, b0, h0, _), (u1, b1, h1, _) in zip(TENMA, TENMA[1:]):
        for side in (1, -1):
            face(s, "Wood", [f.p(u0, side * b0, h0), f.p(u1, side * b1, h1), f.p(u1, side * max(0.02, b1 - PLANK), h1),
                             f.p(u0, side * max(0.02, b0 - PLANK), h0)], (0, 1, 0))
    # Floorboards (the bilge under them is out of sight).
    for (u0, b0, _, _), (u1, b1, _, _) in zip(TENMA[:-2], TENMA[1:-1]):
        v0, v1 = (b0 - PLANK) * 0.86, (b1 - PLANK) * 0.86
        face(s, "WoodFloorDark", [f.p(u0, -v0, BOARDS), f.p(u1, -v1, BOARDS), f.p(u1, v1, BOARDS),
                                  f.p(u0, v0, BOARDS)], (0, 1, 0))
    # Ribs up the inside, two thwarts across, a stern seat.
    for u in (-3.4, -2.0, -0.6, 0.8, 2.2, 3.4):
        b = _beam_at(TENMA, u) - PLANK
        for side in (1, -1):
            s.tube("WoodPanel", f.p(u, side * b * 0.84, BOARDS), f.p(u, side * (b - 0.02), 0.6), 0.06, 4)
    for u, y in ((-0.8, 0.42), (2.0, 0.44)):
        f.box(s, "Wood", u, 0.0, y, (0.55, 0.1, (_beam_at(TENMA, u) - PLANK) * 2 - 0.05))
    f.box(s, "Wood", -4.3, 0.0, 0.38, (0.9, 0.1, (_beam_at(TENMA, -4.3) - PLANK) * 2 - 0.05))
    # The sculling oar (ro) on its pin at the stern, its blade down in the water.
    pin = f.p(-4.8, 0.35, 0.82)
    blade = f.p(-9.2, 0.9, -1.3)
    s.tube("Wood", f.p(-2.6, 0.2, 1.5), pin, 0.07, 6)
    s.tube("Wood", pin, blade, 0.08, 6)
    bx, by, bz = blade
    s.box("Wood", (bx, by + 0.3, bz), (1.4, 0.06, 0.34), f.rot)
    # A blue tarp folded on the fore thwart, a bucket and a coil of rope on the boards.
    f.box(s, "TarpBlue", 2.0, 0.1, 0.62, (1.1, 0.26, 1.5))
    f.box(s, "TarpBlue", 2.25, -0.15, 0.82, (0.8, 0.18, 1.1))
    x, y, z = f.p(0.4, 0.55, BOARDS)
    s.cylinder("RedTrim", (x, y, z), 0.3, 0.55, segments=10, radius_top=0.36)
    x, y, z = f.p(-2.6, -0.4, BOARDS)
    s.lathe("Bamboo", (x, y, z), [(0.12, 0.0), (0.42, 0.02), (0.46, 0.1), (0.38, 0.17), (0.12, 0.17)], 12)
    # Old tyres for fenders on the wall side, and the lines up to rings in the wall.
    for u in (-2.8, 1.8):
        x, y, z = f.p(u, wall * 1.66, 0.1)
        s.lathe("Rubber", (x, y, z), [(0.18, -0.12), (0.34, -0.14), (0.4, 0.0), (0.34, 0.14), (0.18, 0.12)], 10)
    offset = P.CHANNEL[1] if wall * _side_of(f) > 0 else P.CHANNEL[0]
    for u, stern in ((-4.6, True), (4.3, False)):
        v = wall * (0.6 if stern else 0.35)
        wx, _ = f.xz(u + (-1.4 if stern else 1.4), wall * 2.0)
        moor(s, f.p(u, v, (0.72 if stern else 0.9) + 0.1), wx, offset, sag=0.25)


def _beam_at(stations, u):
    for (u0, b0, _, _), (u1, b1, _, _) in zip(stations, stations[1:]):
        if u0 <= u <= u1:
            return b0 + (b1 - b0) * (u - u0) / (u1 - u0)
    return stations[-1][1]


def moored(x, offset, half_beam, gap):
    """A frame for a boat alongside a channel wall: its centre `half_beam` + `gap` off the wall
    at `offset` (north positive), heading east along the river."""
    (cx, cz), d = P.river_frame(x)
    n = g2.normal_left(d)
    side = 1 if offset > 0 else -1
    off = offset - side * (half_beam + gap)
    return Frame((cx + n[0] * off, cz + n[1] * off), d)


def build(s):
    # The yakatabune on the north wall, west of the road bridge, bow to the east (its port side
    # against the wall).
    yakatabune(s, moored(-41.0, P.CHANNEL[1], 2.5, 0.72), 1)
    # The work boat on the south wall, east of the bridge (its starboard side against it).
    tenma_sen(s, moored(128.0, P.CHANNEL[0], 1.3, 0.42), -1)
