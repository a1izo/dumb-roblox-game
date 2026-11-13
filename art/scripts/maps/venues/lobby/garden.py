"""The Grey Realm's garden of the dead (asked 2026-11-10 with fifteen pictures; props in art/scripts/props_garden.py):
everything stays grey, only the flowers' petals are white.

- The spawn ledge's front: a stone balustrade either side of the flight, urns of white roses at its head and foot,
  lanterns at the foot (picture 8; picture 12's lanterns).
- South-east, beside the ledge: a still pond in a stone kerb with lilies on it, a footbridge over it, a stair with
  water running down it into the pond between lanterns, a round temple by it, a willow leaning over it, roses round
  it (pictures 11, 12, 14, 15).
- North-west: the great tree over drifts of white flowers (pictures 5, 6); broken columns on the skyline behind the
  throne; two ruined chapel walls (picture 9).
- The avenue: old trees leaning in over the way to the Academy (picture 13).
- Far beyond the rim, through the fog: the castle on its crag (pictures 7, 8, 10); the dragon circling it is the
  client's (World/LobbyDragon).
- White flowers in drifts over the plain, thickest round the great tree.

Everything people could walk into is solid (colliders), the flowers, roses and lilies excepted. Places are plan.py's;
each lies in its footprint there, so the ground stays level under it and the dressing keeps off it.
"""

import math
import random

from maps import catalog
from maps import geo2d as g2
from maps.venues.lobby import plan as P
from maps.venues.lobby import rocks, terrain
from maps.venues.lobby.ground import WAYS

LANTERN_LIGHT = (226, 228, 236)


class Blocked:
    """Where nothing may grow: the solids standing on the ground (colliders over a stud high) and the feet of the kit
    rocks placed so far, both as polygons in a grid of cells, asked by a circle."""

    CELL = 16.0

    def __init__(self, s):
        self.grid = {}
        for c in s.colliders:
            x, y, z, sx, sy, sz, rot = c[:7]
            if sy <= 1.0 or y - sy / 2 > 2.0:
                continue
            self.add(g2.ccw(g2.rect(x, z, sx, sz, rot)))
        for key, x, y, z, rot, sc, *_ in s.props:
            if key.startswith("Realm") and abs(y) < 8.0:
                try:
                    self.add(rocks.outline(key, x, z, rot, sc))
                except Exception:
                    continue

    def cells(self, box):
        c = self.CELL
        for i in range(math.floor(box[0] / c), math.floor(box[2] / c) + 1):
            for j in range(math.floor(box[1] / c), math.floor(box[3] / c) + 1):
                yield i, j

    def add(self, poly):
        for cell in self.cells(g2.bbox(poly)):
            self.grid.setdefault(cell, []).append(poly)

    def hits(self, x, z, r):
        probe = g2.ccw([(x + math.cos(a) * r, z + math.sin(a) * r) for a in [math.tau * k / 8 for k in range(8)]])
        seen = set()
        for cell in self.cells(g2.bbox(probe)):
            for poly in self.grid.get(cell, ()):
                if id(poly) in seen:
                    continue
                seen.add(id(poly))
                if g2.bbox_overlap(g2.bbox(poly), g2.bbox(probe)) and abs(g2.area(g2.intersect(poly, probe) or
                                                                                  [(0, 0)] * 3)) > 0.05:
                    return True
        return False


def pool(s, x, y, z, range_=26, brightness=1.0, colour=(198, 206, 222)):
    s.light("point", (x, y, z), colour, range_, brightness)


def facing_rot(dx, dz):
    """The rot (degrees about +Y, 0 facing -z) that faces the direction (dx, dz)."""
    return math.degrees(math.atan2(-dx, -dz))


def lean_rot(dx, dz):
    """The rot that turns a prop built leaning toward Roblox -X (props_garden's trees lean toward builder +X) so it
    leans toward (dx, dz)."""
    return math.degrees(math.atan2(dz, -dx))


def turned(rot, v):
    """(x, z) turned by rot as the game turns a prop (check_v2.rotate)."""
    a = math.radians(rot)
    c, sn = math.cos(a), math.sin(a)
    return (v[0] * c + v[1] * sn, -v[0] * sn + v[1] * c)


def by_origin(s, key, x, z, rot, sc=1.0, y=0.0):
    """A prop whose builder origin (its anchor: a tree's trunk, the cascade's foot, the ruin's wall) stands at (x, z):
    the game puts a prop's middle on its spot and its anchor off it, so the spot is the origin less its anchor."""
    ax, az = (catalog.load().get(key) or {}).get("anchor") or (0.0, 0.0)
    dx, dz = turned(rot, (ax * sc, az * sc))
    s.prop(key, round(x - dx, 3), round(z - dz, 3), rot, sc, y)


def tree(s, key, tx, tz, rot, sc, trunk):
    """A tree whose trunk stands at (tx, tz), with a solid round the trunk `trunk` across, turned with it."""
    by_origin(s, key, tx, tz, rot, sc)
    s.collider((tx, 5.0, tz), (trunk * sc, 10.0, trunk * sc), rot, True, None)


def lantern(s, x, z, y=0.0):
    s.prop("LobbyLantern", x, z, 0.0, 1.0, y)
    s.collider((x, y + 2.0, z), (1.3, 4.0, 1.3), 0.0, True, None)


def urn(s, x, z, y=0.0, rot=0.0):
    s.prop("LobbyUrn", x, z, rot, 1.0, y)
    s.collider((x, y + 1.6, z), (2.2, 3.2, 2.2), rot, True, None)


# The ledge ------------------------------------------------------------------------------------------------------


def ledge_front(s):
    """The balustrade along the ledge's front edge either side of the flight, urns of roses at the flight's head and
    foot, lanterns at its foot."""
    cx, cz, w, d, h = P.LEDGE
    front = cz - d / 2
    (_, top_z), (_, foot_z), sw = P.LEDGE_STEPS
    z = front + 0.9
    for side in (-1, 1):
        x0 = sw / 2 + 2.4
        runs = int((w / 2 - x0) // 8.0)
        for k in range(runs):
            s.prop("LobbyBalustrade", side * (x0 + 4.0 + 8.0 * k), z, 0.0 if side > 0 else 180.0, 1.0, h)
        for k in range(runs):
            s.collider((side * (x0 + 4.0 + 8.0 * k), h + 1.8, z), (7.8, 3.6, 1.4), 0.0, True, None)
        urn(s, side * (sw / 2 + 0.9), front + 1.4, h)
        urn(s, side * (sw / 2 + 1.6), foot_z - 2.0)
        lantern(s, side * (sw / 2 + 4.2), foot_z - 1.5)
        for k in range(3):
            s.prop("LobbyRoseBush", side * (sw / 2 + 8.0 + k * 3.6), foot_z - 3.0 - (k % 2) * 1.5, k * 70.0, 0.9)


# The pond garden ------------------------------------------------------------------------------------------------


def pond(s):
    x, z, rx, rz = P.POND
    pts = P.ellipse((x, z), rx, rz, 40)
    # the water, a hand over the ground inside its kerb
    s.polygon("PondWater", [(px, 0.12, pz) for px, pz in reversed(g2.ccw(pts))])
    # the kerb: dressed stone round the edge; a solid wall over it (nobody wades in), open where the bridge lands
    kerb = P.ellipse((x, z), rx + 0.6, rz + 0.6, 40)
    for k in range(len(kerb)):
        (ax, az), (bx, bz) = kerb[k], kerb[(k + 1) % len(kerb)]
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        length = math.dist((ax, az), (bx, bz)) + 0.25
        rot = math.degrees(math.atan2(-(bz - az), bx - ax))
        s.box("RuinStone", (mx, 0.35, mz), (length, 0.7, 1.2), rot)
        if abs(mx - x) < 3.4:
            continue  # (the bridge lands here)
        s.collider((mx, 1.75, mz), (length, 3.5, 1.2), rot, True, None)
    # the footbridge across it (north to south), walkable: two slopes up to its crown and down
    s.prop("LobbyBridge", x, z, 0.0, 1.0, 0.0)
    half = 12.0

    def deck(dz):
        u = dz / half
        return 0.2 + 2.4 * (1 - u * u)

    for a, b in ((-half - 1.0, -half / 2), (-half / 2, 0.0), (0.0, half / 2), (half / 2, half + 1.0)):
        ya, yb = (0.0 if abs(a) > half else deck(a)), (0.0 if abs(b) > half else deck(b))
        lo, hi = (a, b) if ya < yb else (b, a)
        s.ramp((x, z + lo), (x, z + hi), min(ya, yb), max(ya, yb), 4.2)
    for side in (-1, 1):
        s.collider((x + side * 2.2, 2.6, z), (0.6, 3.6, 2 * half), 0.0, True, None)
    # lilies on the water
    for k, (dx, dz, rot) in enumerate(((-8.5, -2.5, 0.0), (8.5, 2.5, 120.0), (-8.5, 2.8, 240.0), (9.0, -2.2, 60.0))):
        s.prop("LobbyLilies", x + dx, z + dz, rot, 0.62 if k % 2 else 0.7, 0.12)


def cascade(s):
    """The stair with water running down it into the pond, between lanterns, its spring under a boulder."""
    x, z = P.CASCADE
    by_origin(s, "LobbyCascade", x, z, 0.0)
    # solid: the steps and their walls, the basin's rim
    s.collider((x, 3.6, z + 6.0), (5.8, 7.2, 13.2), 0.0, True, None)
    s.collider((x, 0.45, z - 2.6), (5.6, 0.9, 5.6), 0.0, True, None)
    for side in (-1, 1):
        lantern(s, x + side * 4.4, z - 0.5)
    rocks.rock(s, "RealmBoulderA", x + 1.0, z + 21.0, 30.0, 0.8)


def rotunda(s):
    x, z, r = P.ROTUNDA
    # (its entrance faces the pond: the prop is round, so only the colliders' ramp cares)
    s.prop("LobbyRotunda", x, z, 0.0, 1.0, 0.0)
    # its two steps as solid discs (each 0.5 high: walked up), its ten columns, its dome out of reach
    for y, rr in ((0.5, 9.4), (1.0, 8.6)):
        n = 20
        for k in range(n):
            a0, a1 = math.tau * k / n, math.tau * (k + 1) / n
            s.floor_tri((x, z), (x + math.cos(a0) * rr, z + math.sin(a0) * rr), (x + math.cos(a1) * rr,
                        z + math.sin(a1) * rr), y, thick=y, look=None)
    for k in range(10):
        a = math.tau * (k + 0.5) / 10
        s.collider((x + math.cos(a) * 7.2, 7.0, z + math.sin(a) * 7.2), (1.5, 12.0, 1.5), 0.0, True, None)
    pool(s, x, 9.0, z, 18, 0.5)


def willow(s):
    x, z = P.WILLOW
    px, pz = P.POND[:2]
    tree(s, "LobbyWillow", x, z, lean_rot(px - x, pz - z), 1.0, 2.4)


def garden_roses(s, rng, blocked):
    x, z, rx, rz = P.POND
    for k in range(14):
        a = math.tau * k / 14 + rng.uniform(-0.1, 0.1)
        if abs(math.cos(a)) < 0.3:
            continue  # (the bridge's ends)
        px, pz = x + math.cos(a) * (rx + 3.2), z + math.sin(a) * (rz + 3.2)
        if math.dist((px, pz), P.ROTUNDA[:2]) < P.ROTUNDA[2] + 2.5:
            continue
        if math.dist((px, pz), (P.CASCADE[0], P.CASCADE[1] + 4.0)) < 9.5:
            continue
        if blocked.hits(px, pz, 2.4):
            continue
        s.prop("LobbyRoseBush", px, pz, rng.uniform(0, 360), rng.uniform(0.8, 1.15))


# The north-west -------------------------------------------------------------------------------------------------


def great_tree(s):
    x, z = P.GREAT_TREE
    tree(s, "LobbyGreatTree", x, z, 200.0, 1.0, 6.6)
    pool(s, x, 30.0, z + 14.0, 40, 0.6)


def columns(s):
    for x, z, sc in P.COLUMNS:
        rot = facing_rot(P.SPAWN[0] - x, P.SPAWN[1] - z)
        s.prop("LobbyColumn", x, z, rot, sc, 0.0)
        s.collider((x, 0.6 * sc, z), (3.6 * sc, 1.2 * sc, 3.6 * sc), rot, True, None)
        s.collider((x, 12.0 * sc, z), (2.3 * sc, 22.0 * sc, 2.3 * sc), rot, True, None)


def ruins(s):
    for x, z, rot in P.RUINS:
        by_origin(s, "LobbyGothicRuin", x, z, rot)
        # the wall's piers (the arches stay open to walk through), the side wall's stub
        for lx, w in ((-11.2, 3.6), (-0.5, 2.0), (12.0, 2.2)):
            # (the builder's +x is Roblox's -x: the piers mirror)
            cx = x - math.cos(math.radians(rot)) * lx
            cz = z + math.sin(math.radians(rot)) * lx
            s.collider((cx, 12.0, cz), (w, 24.0, 3.2), rot, True, None)
        # (over the arches: a lintel band of solid from the springing up)
        for lx, span, spring in ((-5.5, 8.0, 10.0), (6.0, 10.0, 12.0)):
            # (the builder's +x is Roblox's -x: the piers mirror)
            cx = x - math.cos(math.radians(rot)) * lx
            cz = z + math.sin(math.radians(rot)) * lx
            s.collider((cx, spring + 7.0, cz), (span, 12.0, 3.2), rot, True, None)


def avenue(s, blocked):
    """Old trees along the way to the Academy (2026-11-12, the user: "remove those uniformally sitting trees ... dont
    place things mathematically - just do what feels natural"): no pairs, no even spacing. A loose handful placed by
    eye: a close group of three of different sizes on one side, a lone big one across the way further on, a small one
    set well back; each at its own distance from the way, its own size, leaning its own way (mostly toward the way,
    never squarely)."""
    pts = WAYS[0]
    (ax, az), (bx, bz) = pts[-2], pts[-1]
    length = math.dist((ax, az), (bx, bz))
    dx, dz = (bx - ax) / length, (bz - az) / length
    nx, nz = -dz, dx
    tab = P.TABLEAUX[0]
    grotto = P.ACADEMY_C
    # (along the way, out from it (+ right / - left), size, how far its lean is turned off the way's normal, degrees)
    for t, out, sc, turn in ((-9.5, 12.5, 1.02, -24.0), (-5.0, 9.0, 0.78, 14.0), (-1.5, 15.5, 0.9, -40.0),
                             (7.5, -10.5, 1.08, 18.0), (15.5, -17.0, 0.7, -32.0)):
        px, pz = ax + dx * t + nx * out, az + dz * t + nz * out
        if math.dist((px, pz), tab) < P.TABLEAU_R + 3.0 or math.dist((px, pz), grotto) < P.GROTTO_WALL + 5.0:
            continue
        if blocked.hits(px, pz, 3.0):
            continue  # (a trunk in a rock's foot)
        side = 1.0 if out > 0 else -1.0
        a = math.radians(turn)
        lx, lz = -nx * side, -nz * side
        lx, lz = lx * math.cos(a) - lz * math.sin(a), lx * math.sin(a) + lz * math.cos(a)
        tree(s, "LobbyArchTree", px, pz, lean_rot(lx, lz), sc, 2.2)


def castle(s):
    x, z, crag, sc = P.CASTLE
    rocks.rock(s, "RealmMesa", x, z, 30.0, crag)
    top = terrain.top_of("RealmMesa", crag)
    s.prop("LobbyCastle", x, z, 150.0, sc, top - 2.0)


# The flowers ----------------------------------------------------------------------------------------------------


def flowers(s, rng, blocked):
    """Drifts of white flowers over the plain, a carpet round the great tree. Off everything solid and laid (the
    plan's footprints, but the tree's own), off the ways' flagstones, inside the basin."""
    keep_off = [g2.ccw(poly) for name, poly in P.footprints().items() if name != "great tree"]
    for points in WAYS:
        for q in g2.strip_quads(points, 2.6, -2.6):
            keep_off.append(g2.ccw(q))
    keep_off.append(g2.ccw(P.RIFT_GUARD))
    basin = g2.ccw([(x * 0.93, z * 0.93) for x, z in P.BASIN])

    def free(x, z, r):
        if not g2.contains(basin, (x, z)) or blocked.hits(x, z, r):
            return False
        probe = [(x + math.cos(a) * r, z + math.sin(a) * r) for a in (0, 1.57, 3.14, 4.71)] + [(x, z)]
        for poly in keep_off:
            if any(g2.contains(poly, p) for p in probe):
                return False
        return True

    placed = 0

    def drift(cx, cz, spread, count):
        nonlocal placed
        for _ in range(count):
            a = rng.uniform(0, math.tau)
            d = spread * math.sqrt(rng.random())
            x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
            # (one drift, at many sizes: a small one is the same drift shrunk)
            sc = round(rng.uniform(0.6, 1.2), 2)
            if not free(x, z, 6.3 * sc):
                continue
            s.prop("LobbyFlowersA", round(x, 2), round(z, 2), rng.uniform(0, 360), sc, 0.0)
            placed += 1

    # the hill round the great tree: the thickest
    gx, gz = P.GREAT_TREE
    drift(gx, gz, 30.0, 46)
    # drifts across the plain, toward the glow and round the garden
    for cx, cz, spread, count in ((-70.0, -60.0, 16.0, 8), (40.0, -80.0, 18.0, 10), (-12.0, -105.0, 14.0, 8),
                                  (70.0, 70.0, 16.0, 8), (100.0, 115.0, 10.0, 5), (-60.0, 95.0, 14.0, 7),
                                  (-80.0, -10.0, 14.0, 6), (60.0, -10.0, 12.0, 6), (-30.0, 70.0, 10.0, 6),
                                  (30.0, 70.0, 10.0, 6), (-100.0, -130.0, 14.0, 6), (140.0, 40.0, 10.0, 4),
                                  (-50.0, 30.0, 9.0, 6), (-62.0, 46.0, 8.0, 6), (-66.0, 30.0, 8.0, 5)):
        drift(cx, cz, spread, count)
    return placed


def build(s):
    rng = random.Random(1110)
    ledge_front(s)
    pond(s)
    cascade(s)
    rotunda(s)
    willow(s)
    great_tree(s)
    columns(s)
    ruins(s)
    avenue(s, Blocked(s))
    castle(s)
    blocked = Blocked(s)
    garden_roses(s, rng, blocked)
    n = flowers(s, rng, blocked)
    print(f"[garden] {n} drifts of flowers")
