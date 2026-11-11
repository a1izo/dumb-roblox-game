"""The Grey Realm's ground, as it is seen: one surface of ash from the basin out over the plain round it, never quite
level. Broad swells, ripples the wind has drawn across it in places, ash banked up against the foot of every rock, and
out past the ridge, dunes; crusts of cracked earth lying in patches of the same surface. Wherever something is laid on
the ground or done on it (the plaza, the Academy, the ways, the causeways, the bases...) it lies level a hair under the
paving, and it comes up out of it over a few studs. Holes where the rift and the chasms are.

Walking is on the flat floors terrain.ground lays (and the far plain's): the swells stay low where people go (a foot
sinks a little into the ash), and the banks rise where the rocks' walls keep people off. Past REACH the plain lies level
under the haze, as terrain.far_plain draws it."""

import math
import random

from mathutils import Vector, noise

from maps import geo2d as g2
from maps.venues.lobby import plan as P
from maps.venues.lobby import rocks

STEP = 4.0  # the grid's side over the basin (studs)
INNER = 176.0  # (a square) out to here at STEP (the basin, its ridge just past it); then at COARSE
COARSE = 8.0
REACH = 424.0  # (a square) the relief's reach; the far plain beyond lies level
LOW = -0.06  # the ground's height under what is laid on it (clear of paving laid at 0)
PLAIN = -0.15  # the far plain's height, which the relief comes down to at its edge
WALK = 0.3  # how high the swells and ripples rise where people walk
BANK = 0.7  # ash banked against a rock's foot, at most (studs), over BANK_REACH (a foot sinks that far at most)
BANK_REACH = 5.5
DUNE = 3.2  # the dunes out on the plain, past the basin's ridge
FADE = 5.0  # over how far the ground comes up out of the level round something laid on it
TILE = 64.0  # the surface is drawn in tiles of this side (each its own mesh piece)


def _n(x, z, k=0.0):
    return noise.noise(Vector((x, z, k)), noise_basis="PERLIN_NEW")


def _fbm(x, z, k, octaves=3):
    total, amp, f = 0.0, 1.0, 1.0
    for _ in range(octaves):
        total += amp * _n(x * f, z * f, k + f)
        amp *= 0.5
        f *= 2.1
    return total


def _smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


class Field:
    """What the ground's height depends on: the level places (polygons, each with the pad it keeps level round it),
    the rocks' feet, the holes; with a coarse grid of each so a point asks only its neighbours."""

    CELL = 24.0

    def __init__(self, level, feet, holes):
        self.level, self.feet, self.holes = level, feet, holes
        self._level = self._index([(poly, pad + FADE) for poly, pad in level])
        self._feet = self._index([(poly, BANK_REACH) for poly in feet])

    def _index(self, items):
        grid = {}
        for k, (poly, reach) in enumerate(items):
            x0, z0, x1, z1 = g2.bbox(poly)
            for i in range(math.floor((x0 - reach) / self.CELL), math.floor((x1 + reach) / self.CELL) + 1):
                for j in range(math.floor((z0 - reach) / self.CELL), math.floor((z1 + reach) / self.CELL) + 1):
                    grid.setdefault((i, j), []).append(k)
        return grid

    def _near(self, grid, x, z):
        return grid.get((math.floor(x / self.CELL), math.floor(z / self.CELL)), ())

    def openness(self, x, z):
        """0 on and round what is laid on the ground, rising to 1 over FADE (along a ragged line: the ash has drifted
        unevenly up to the paving's edge)."""
        out = 1.0
        warp = 1.6 * _n(x / 7.0, z / 7.0, 17.1)
        for k in self._near(self._level, x, z):
            poly, pad = self.level[k]
            if g2.contains(poly, (x, z)):
                return 0.0
            d = g2.dist_to_poly_edge(poly, (x, z)) + warp
            if d < pad + FADE:
                out = min(out, _smooth(pad, pad + FADE, d))
        return out

    def bank(self, x, z):
        """How much ash is banked up here against the nearest rock's foot (0 to 1)."""
        best = 0.0
        for k in self._near(self._feet, x, z):
            poly = self.feet[k]
            d = 0.0 if g2.contains(poly, (x, z)) else g2.dist_to_poly_edge(poly, (x, z))
            if d < BANK_REACH:
                best = max(best, (1.0 - d / BANK_REACH) ** 2)
        return best

    def height(self, x, z):
        """The ground's height at (x, z)."""
        edge = max(abs(x), abs(z))
        if edge >= REACH:
            return PLAIN
        m = self.openness(x, z)
        if m <= 0.0:
            return LOW
        # Swells, and ripples where the wind has had the ash (they run across the prevailing wind, which wanders).
        swell = 0.5 + 0.5 * _fbm(x / 46.0, z / 46.0, 3.7, 2)
        heading = 0.7 + 0.5 * _n(x / 140.0, z / 140.0, 9.1)
        wx, wz = math.cos(heading), math.sin(heading)
        phase = (x * wx + z * wz) / 8.5 + 1.4 * _n(x / 26.0, z / 26.0, 2.3)
        ripple = (0.5 + 0.5 * math.sin(phase * math.tau)) ** 2
        patch = max(0.0, min(1.0, 1.6 * _n(x / 64.0, z / 64.0, 5.5) + 0.25))
        relief = WALK * (0.62 * swell + 0.38 * ripple * patch)
        # Out past the basin's ridge, dunes (people never walk there).
        r = math.hypot(x, z)
        out = _smooth(P.rim_r(math.atan2(z, x)) + 6.0, P.rim_r(math.atan2(z, x)) + 70.0, r)
        relief += DUNE * out * (0.5 + 0.5 * _fbm(x / 90.0, z / 90.0, 7.3, 3)) * (0.75 + 0.25 * ripple)
        relief += BANK * self.bank(x, z)
        # (down to the far plain's height at the relief's edge)
        fall = _smooth(REACH - 40.0, REACH, edge)
        return LOW + (relief * (1.0 - fall)) * m + (PLAIN - LOW) * fall

    def normal(self, x, z, e=0.6):
        hx = (self.height(x + e, z) - self.height(x - e, z)) / (2 * e)
        hz = (self.height(x, z + e) - self.height(x, z - e)) / (2 * e)
        length = math.sqrt(hx * hx + 1.0 + hz * hz)
        return (-hx / length, 1.0 / length, -hz / length)

    def scree(self, x, z):
        """Over 0 in a ragged apron of scree (the rock's own surface) round each rock's foot."""
        return self.bank(x, z) - (0.42 + 0.22 * _n(x / 5.0, z / 5.0, 13.3))

    def crust(self, x, z):
        """Over 0 where a crust of cracked earth lies on the ash: patches out in the open, none near the paving."""
        return _fbm(x / 26.0, z / 26.0, 11.9, 2) - 0.36 - 2.0 * max(0.0, 0.6 - self.openness(x, z))


def level_places():
    """(polygon, pad) of everything laid on the ground or done on it: the ground stays level over each and `pad`
    studs round it before it comes up."""
    out = []
    for name, poly in P.footprints().items():
        if name in ("throne rock", "tusks", "arch") or name.startswith("junk"):
            continue  # (rock and bone: the ash banks against those)
        out.append((g2.ccw(poly), 1.5))
    # The paving: the grotto's floor (the bowl is a hole of its own).
    out.append((g2.ccw(P.circle(P.ACADEMY_C, (P.ACADEMY_R + 1.0) * 1.27, 24)), 1.0))
    # The ways' stepping stones, the causeways' decks and the duel's stones.
    for points in WAYS:
        for q in g2.strip_quads(points, 3.6, -3.6):
            out.append((g2.ccw(q), 0.5))
    for a, b in (P.BRIDGE_SHARDS, P.BRIDGE_PARKOUR):
        length = math.dist(a, b)
        out.append((g2.ccw(g2.rect((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, length + 6.0, P.BRIDGE_W + 4.0,
                                   math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0])))), 1.0))
    for x, z in P.DUEL:
        out.append((g2.ccw(P.circle((x, z), 3.4, 10)), 0.5))
    # The plateaus (the relief runs on under them, never up through them).
    for islet in (P.ISLET_SHARDS, P.ISLET_PARKOUR):
        out.append((g2.ccw(P.circle(islet[:2], islet[2] * 1.12, 24)), 0.0))
    return out


# The ways people walk out from the bowl, laid with old flagstones by dressing.ways: to the grotto's mouth, the
# throne's plaque, the carcass and the duel, the two causeways and the chess game.
WAYS = [
    [(-31.0, 24.0), (-52.0, 34.0), (-67.0, 40.0)],
    [(0.0, -17.0), (0.0, -33.0), (0.0, -47.0)],
    [(33.0, 12.0), (60.0, 18.0), (88.0, 25.0), (106.0, 29.0)],
    [(-33.0, 10.0), (-70.0, 4.0), (-108.0, 0.0), (-138.0, -1.0)],
    [(30.0, -4.0), (48.0, -36.0), (66.0, -76.0), (93.0, -95.0)],
    [(-28.0, -4.0), (-44.0, -22.0)],
    [(24.0, 40.0), (46.0, 62.0), (66.0, 80.0)],  # (to the pond's footbridge: lobby/garden.py)
]


def holes():
    """The ground's holes: the rift, the chasms and the bowl (sunk, with floors of its own)."""
    return [g2.ccw(P.RIFT), g2.ccw(P.circle(P.BOWL_C, P.BOWL_R, 32))] + [g2.ccw(P.chasm_outline(c)) for c in P.CHASMS]


def _grid_points(step, lo, hi, rng, keep):
    """Grid corners from lo to hi (a square), each nudged a little (an even grid shows as rows in the light), except
    on the lines `keep` says stay straight (the edge between two grids)."""
    n = int(round((hi - lo) / step))
    pts = {}
    for i in range(n + 1):
        for j in range(n + 1):
            x, z = lo + i * step, lo + j * step
            if not keep(x, z):
                x += rng.uniform(-0.28, 0.28) * step
                z += rng.uniform(-0.28, 0.28) * step
            pts[(i, j)] = (x, z)
    return pts, n


def build(s):
    """Draws the ground (after every rock has stood: their feet are in rocks.FEET)."""
    field = Field(level_places(), list(rocks.FEET), holes())
    hole_polys = field.holes
    hole_boxes = [g2.bbox(h) for h in hole_polys]
    rng = random.Random(4040)
    cells = []  # (polygon of the cell)
    # The basin's grid, fine, and round it the coarse one (its cells inside INNER left out); the two meet along INNER's
    # square, where both keep their corners straight and the fine one's extra corners sit on the coarse edges.
    fine, nf = _grid_points(STEP, -INNER, INNER, rng, lambda x, z: abs(abs(x) - INNER) < 1e-6 or abs(abs(z) - INNER) < 1e-6)
    for i in range(nf):
        for j in range(nf):
            cells.append([fine[(i, j)], fine[(i + 1, j)], fine[(i + 1, j + 1)], fine[(i, j + 1)]])
    coarse, nc = _grid_points(COARSE, -REACH, REACH, rng,
                              lambda x, z: max(abs(x), abs(z)) <= INNER + 1e-6 or abs(abs(x) - REACH) < 1e-6
                              or abs(abs(z) - REACH) < 1e-6)
    for i in range(nc):
        for j in range(nc):
            a, b, c, d = coarse[(i, j)], coarse[(i + 1, j)], coarse[(i + 1, j + 1)], coarse[(i, j + 1)]
            mx, mz = (a[0] + c[0]) / 2, (a[1] + c[1]) / 2
            if max(abs(mx), abs(mz)) < INNER:
                continue
            quad = [a, b, c, d]
            # (a coarse cell on INNER's square takes the fine grid's corners along its side, so no crack opens there)
            quad = _with_fine_edge(quad, STEP)
            cells.append(quad)
    tiles = {}
    heights = {}
    values = {}

    def corner(p):
        key = (round(p[0], 3), round(p[1], 3))
        if key not in heights:
            heights[key] = (field.height(*key), field.normal(*key))
        return heights[key]

    for poly in cells:
        box = g2.bbox(poly)
        pieces = [poly]
        for hp, hb in zip(hole_polys, hole_boxes):
            if g2.bbox_overlap(box, hb):
                pieces = [piece for p in pieces for piece in g2.subtract(g2.ccw(p), hp)]
        for piece in pieces:
            if abs(g2.area(piece)) < 0.02:
                continue
            tris = _fan(piece) if g2.is_convex(piece) else g2.triangulate(g2.ccw(piece))
            for tri in tris:
                # The surfaces' edges follow their own contours: a triangle across one is cut along it.
                for scree, part in _split(tri, field.scree, values):
                    if scree:
                        parts = [("RockGrey", part)]
                    else:
                        parts = [("RealmCrust" if crust else "RealmAsh", bit) for crust, bit in _split(part, field.crust, values)]
                    for mat, bit in parts:
                        cx = sum(p[0] for p in bit) / 3
                        cz = sum(p[1] for p in bit) / 3
                        tiles.setdefault((math.floor(cx / TILE), math.floor(cz / TILE), mat), []).append(bit)
    count = 0
    for (_, _, mat), tris in sorted(tiles.items()):
        verts, normals, faces, uvs, index = [], [], [], [], {}
        for tri in tris:
            ids = []
            for p in g2.cw(tri):  # (clockwise in x-z is counter-clockwise seen from above in Roblox's axes)
                key = (round(p[0], 3), round(p[1], 3))
                if key not in index:
                    h, nrm = corner(p)
                    index[key] = len(verts)
                    verts.append((p[0], h, p[1]))
                    normals.append(nrm)
                ids.append(index[key])
            if len(set(ids)) == 3:
                faces.append(tuple(ids))
                uvs.append(tuple((verts[i][0], -verts[i][2]) for i in ids))
        s.mesh(mat, verts, faces, uvs, normals, ground=True)
        count += len(faces)
    return count


def _split(tri, f, cache):
    """The triangle cut along the line where f crosses 0: [(f > 0, triangle)] (one piece, or three). The point on an
    edge comes from the values at its two ends, so neighbouring triangles cut their shared edge at the same place."""

    def value(p):
        key = (round(p[0], 3), round(p[1], 3), f.__name__)
        if key not in cache:
            cache[key] = f(p[0], p[1])
        return cache[key]

    vals = [value(p) for p in tri]
    sides = [v > 0 for v in vals]
    if all(sides) or not any(sides):
        return [(sides[0], tri)]
    # the corner alone on its side, and the two others
    k = next(i for i in range(3) if sides.count(sides[i]) == 1)
    a, b, c = tri[k], tri[(k + 1) % 3], tri[(k + 2) % 3]
    va, vb, vc = vals[k], vals[(k + 1) % 3], vals[(k + 2) % 3]

    def cut(p, q, vp, vq):
        t = vp / (vp - vq)
        return (round(p[0] + (q[0] - p[0]) * t, 3), round(p[1] + (q[1] - p[1]) * t, 3))

    ab, ac = cut(a, b, va, vb), cut(a, c, va, vc)
    alone = sides[k]
    return [(alone, [a, ab, ac]), (not alone, [ab, b, c]), (not alone, [ab, c, ac])]


def _fan(poly):
    """A convex polygon's triangles, fanned from a corner that lies on a straight side if it has one (a coarse cell
    with a fine corner on its edge), so none of them is flat."""
    p = g2.ccw(poly)
    n = len(p)
    start = 0
    for k in range(n):
        a, b, c = p[k - 1], p[k], p[(k + 1) % n]
        if abs((b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])) < 1e-6:
            start = k
            break
    p = p[start:] + p[:start]
    return [[p[0], p[k], p[k + 1]] for k in range(1, n - 1)]


def _with_fine_edge(quad, step):
    """A coarse cell's outline with the fine grid's corners added along any side lying on INNER's square."""
    out = []
    for k in range(4):
        a, b = quad[k], quad[(k + 1) % 4]
        out.append(a)
        on_x = abs(abs(a[0]) - INNER) < 1e-6 and abs(a[0] - b[0]) < 1e-6
        on_z = abs(abs(a[1]) - INNER) < 1e-6 and abs(a[1] - b[1]) < 1e-6
        if on_x or on_z:
            length = math.dist(a, b)
            n = int(round(length / step))
            for q in range(1, n):
                u = q / n
                out.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u))
    return out
