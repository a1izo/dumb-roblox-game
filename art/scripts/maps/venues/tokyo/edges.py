"""Where Tokyo District ends, and how the city carries on past it.

Every street, lane and promenade that leaves the map is closed by a site fence ten studs tall with
police tape across it, barricades and cones in front, sometimes a patrol car: a barrier anyone can
see (the fence's own collision stops people, and an invisible wall over it keeps anyone from
getting over). Along the north a concrete wall under the expressway closes the frontage road;
along the south the viaduct does. Past the barriers the streets carry on, lit, between buildings
with lit windows; blocks of the city stand all round out to a tall skyline, the ground runs on
under the fog to the horizon and a dark floor lies under everything, so there is never a void to
see. A safety net stands behind the outermost buildings, where nobody can get to."""

import math
import random

from maps import buildings, catalog, city
from maps import geo2d as g2
from maps.venues.tokyo import plan as P
from maps.venues.tokyo import river

FAR = 700.0  # how far the ground runs past the map
BLOCK_H = 40.0  # the invisible wall over a barrier or edge wall
CAT = catalog.load()


def facing(dx, dz):
    """The rot that faces direction (dx, dz)."""
    return math.degrees(math.atan2(-dx, -dz))


def place(s, key, x, z, rot, y=0.0, dark=False):
    """A prop whose anchor (a pole's foot) stands on (x, z)."""
    ax, az = CAT.get(key, {}).get("anchor", [0.0, 0.0])
    a = math.radians(rot)
    wx = ax * math.cos(a) + az * math.sin(a)
    wz = -ax * math.sin(a) + az * math.cos(a)
    s.prop(key, x - wx, z - wz, rot, 1.0, y, dark)


def barrier(s, a, b, out, rng, car=False):
    """A street closed from a to b (x, z): site fence panels along the line, police tape across
    them, barricades and cones on the near side (out points away from the map)."""
    length = math.dist(a, b)
    d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    rot = facing(-out[0], -out[1])  # the fence's face (its -Z side) looks back into the map
    count = max(1, math.ceil(length / 7.6))
    step = length / count
    for k in range(count):
        c = (a[0] + d[0] * step * (k + 0.5), a[1] + d[1] * step * (k + 0.5))
        s.prop("SiteFence", c[0], c[1], rot)
        s.collider((c[0], 5.0, c[1]), (step + 0.2, 10.0, 0.6), g2.rot_of(d), True, None)
        # Invisible above the fence, so nothing gets over it (the view past it stays open).
        s.collider((c[0], 10.0 + BLOCK_H / 2, c[1]), (step + 0.2, BLOCK_H, 0.6), g2.rot_of(d), False, None)
        tx, tz = c[0] - out[0] * 0.5, c[1] - out[1] * 0.5
        s.prop("PoliceTape", tx, tz, rot, 1.0, 3.6 + 0.2 * (k % 2))
    # Barricades and cones a few studs in front.
    for k in range(max(1, int(length / 6))):
        t = (k + 0.5) / max(1, int(length / 6))
        p = (a[0] + d[0] * length * t - out[0] * 3.0, a[1] + d[1] * length * t - out[1] * 3.0)
        if k % 2 == 0:
            s.prop("Barricade", p[0], p[1], rot + rng.uniform(-8, 8))
        else:
            s.prop("TrafficCone", p[0] + rng.uniform(-1, 1), p[1] + rng.uniform(-1, 1), rng.uniform(0, 90))
    if car:
        p = (a[0] + d[0] * length * 0.35 - out[0] * 9.0, a[1] + d[1] * length * 0.35 - out[1] * 9.0)
        s.prop("PoliceCar", p[0], p[1], g2.rot_of(d) + 90 + rng.uniform(-12, 12))


def barriers(s):
    rng = random.Random(21)
    x0, x1 = P.X0 + 1.5, P.X1 - 1.5
    barrier(s, (x0, -127.0), (x0, -147.5), (-1, 0), rng, car=True)  # the frontage road, west
    barrier(s, (x1, -147.5), (x1, -127.0), (1, 0), rng)  # the frontage road, east
    barrier(s, (-122.0, -148.5), (-84.0, -148.5), (0, -1), rng, car=True)  # the avenue, north
    barrier(s, (118.0, -148.5), (139.0, -148.5), (0, -1), rng)  # Kita-dori, north
    barrier(s, (x1, -53.0), (x1, -30.0), (1, 0), rng, car=True)  # the east street
    barrier(s, (50.0, 147.0), (92.0, 147.0), (0, 1), rng)  # the avenue, south under the viaduct
    for x, out in ((x0, (-1, 0)), (x1, (1, 0))):
        barrier(s, (x, P.VIADUCT_LANE_Z[0] - 0.5), (x, P.VIADUCT_LANE_Z[1] + 0.5), out, rng)
        (cx, cz), d = P.river_frame(x)
        n = g2.normal_left(d)
        for a, b in ((P.PROM_N[1] + 0.5, P.CHANNEL[1]), (P.CHANNEL[0], P.PROM_S[0] - 0.5)):
            barrier(s, (cx + n[0] * a, cz + n[1] * a), (cx + n[0] * b, cz + n[1] * b), out, rng)


def expressway(s):
    """The elevated expressway along the north: its deck, sound walls, piers with sodium lamps
    under the deck, and a concrete wall along the frontage road's far side."""
    z0, z1 = P.EXPRESSWAY_Z
    y = P.EXPRESSWAY_Y
    x0, x1 = -FAR, FAR
    mid_z = (z0 + z1) / 2
    s.box("ConcreteDark", (0.0, y + 1.5, mid_z), (x1 - x0, 3.0, z1 - z0), 0, collide=True)
    for z in (z0 + 0.4, z1 - 0.4):
        s.box("Concrete", (0.0, y + 5.0, z), (x1 - x0, 4.0, 0.8), 0)
        s.box("GlassDark", (0.0, y + 9.0, z), (x1 - x0, 4.0, 0.3), 0)
    # The wall on the frontage road's north side, with openings where the avenue and Kita-dori go on.
    gaps = [(-122.0, -84.0), (118.0, 139.0)]
    cursor = P.X0
    for g0, g1 in gaps + [(P.X1, P.X1)]:
        if g0 - cursor > 0.5:
            c = ((cursor + g0) / 2, -148.6)
            s.box("Concrete", (c[0], 7.0, c[1]), (g0 - cursor, 14.0, 1.2), 0, collide=True)
            s.box("ConcreteDark", (c[0], 14.2, c[1]), (g0 - cursor, 0.4, 1.6), 0)
            s.collider((c[0], 14.0 + BLOCK_H / 2, c[1]), (g0 - cursor, BLOCK_H, 1.2), 0, False, None)
        cursor = g1
    x = -186.0
    while x < P.X1 + 20:
        in_gap = any(g0 - 3 < x < g1 + 3 for g0, g1 in gaps)
        if not in_gap:
            s.box("Concrete", (x, y / 2, -150.5), (4.0, y, 4.0), 0, skip=("-y",), collide=True)
            s.box("Concrete", (x, y - 1.0, mid_z), (4.0, 2.0, z1 - z0), 0, skip=("-y",))
            # A sodium lamp on the pier's face, lighting the road under the deck.
            s.box("BlackMetal", (x, y - 5.0, -148.2), (1.2, 0.8, 1.6), 0)
            s.box("NeonOrange", (x, y - 5.45, -147.8), (0.9, 0.1, 1.0), 0)
            s.light("spot", (x, y - 6.0, -147.2), (255, 176, 90), 34, 2.0, False, "Bottom", 110)
        x += 48.0
    s.zone("offlimits", P.box(P.X0, -150, P.X1, -147.2), 0.0)


def viaduct(s):
    """Brick arches along the south edge carrying the railway; the avenue passes under a steel
    span. Each arch is a shallow niche with a shutter; the bars in some of them are dressed by
    the venue (dressing.py)."""
    z0, z1 = P.VIADUCT_Z
    top = P.VIADUCT_Y
    ave = P.STREETS["ave_se"]
    half = ave["road"] / 2 + ave["walk"][0] + 2
    hits = g2.polyline_hits(ave["points"], [(-FAR, z0), (FAR, z0)])
    gap = (hits[0][0] - half - 4, hits[0][0] + half + 8) if hits else (1e9, 1e9)
    niche = 3.0
    pier = 2.6
    bay = 12.0
    x = -FAR
    while x < FAR:
        nxt = x + bay
        if gap[0] < nxt and x < gap[1]:
            x = nxt
            continue
        s.box("BrickDark", (x + pier / 2, top / 2, z0 + niche / 2), (pier, top, niche), 0, skip=("-y",),
              collide=abs(x) < P.X1 + 20)
        s.box("BrickDark", ((x + nxt) / 2 + pier / 2, top - 2.5, z0 + niche / 2), (nxt - x - pier, 5.0, niche), 0,
              skip=("+y", "-z", "+z"))
        city.vquad(s, "Shutter", (x + pier, z0 + niche), (nxt, z0 + niche), 0.0, top - 5.0, (0, -1))
        x = nxt
    for a, b in ((-FAR, gap[0]), (gap[1], FAR)):
        if b - a > 1:
            s.box("BrickDark", ((a + b) / 2, top / 2, (z0 + niche + z1) / 2), (b - a, top, z1 - z0 - niche), 0,
                  skip=("-y", "-z"))
            lo, hi = max(a, P.X0 - 10), min(b, P.X1 + 10)
            if hi > lo:
                s.collider(((lo + hi) / 2, top / 2, (z0 + niche + z1) / 2), (hi - lo, top, z1 - z0 - niche), 0, True,
                           None)
    s.box("ConcreteDark", (0.0, top + 1.5, (z0 + z1) / 2), (2 * FAR, 3.0, z1 - z0 + 1), 0, collide=True)
    s.box("Concrete", (0.0, top + 4.0, z0 + 0.4), (2 * FAR, 2.0, 0.8), 0)
    # Catenary masts along the tracks on top.
    x = -FAR + 10
    while x < FAR:
        s.box("DarkMetal", (x, top + 9.0, z0 + 2.0), (0.5, 12.0, 0.5), 0)
        s.box("DarkMetal", (x, top + 14.5, (z0 + z1) / 2), (0.4, 0.4, z1 - z0), 0)
        x += 36.0
    s.tube("BlackMetal", (-FAR, top + 13.5, (z0 + z1) / 2 - 3), (FAR, top + 13.5, (z0 + z1) / 2 - 3), 0.06, 4)
    s.tube("BlackMetal", (-FAR, top + 13.5, (z0 + z1) / 2 + 3), (FAR, top + 13.5, (z0 + z1) / 2 + 3), 0.06, 4)
    if hits:
        s.box("DarkMetal", ((gap[0] + gap[1]) / 2, top - 1.0, (z0 + z1) / 2), (gap[1] - gap[0] + 4, 2.0, z1 - z0), 0)
    s.zone("offlimits", P.box(P.X0, z0 + niche, P.X1, z1), 0.0)


# Beyond the map -----------------------------------------------------------------------------------------

# Streets carrying on past the map: (centre line, road width, sidewalk).
BEYOND = [
    ([(-200, -141), (-330, -141), (-420, -150)], 12.0, 5.0),  # the frontage road, west
    ([(200, -141), (330, -141), (420, -132)], 12.0, 5.0),  # the frontage road, east
    ([(-106, -150), (-120, -190), (-150, -260), (-170, -330)], 20.0, 6.0),  # the avenue, north
    ([(72, 150), (80, 200), (70, 260), (40, 330)], 20.0, 6.0),  # the avenue, south
    ([(200, -41), (280, -38), (360, -60)], 10.0, 4.0),  # the east street
    ([(129, -150), (132, -210), (150, -280)], 10.0, 4.0),  # Kita-dori, north
]


def far_ground(s, g):
    """Ground as far as anyone can see, and the streets that go on past the barriers."""
    ring = [(-FAR, -FAR), (FAR, -FAR), (FAR, FAR), (-FAR, FAR)]
    channel = g2.strip_quads(river.inner_river(), P.CHANNEL[1], P.CHANNEL[0])
    around = g2.subtract_all([g2.ccw(ring)], [g2.ccw(P.MAP_RECT)] + channel)
    for piece in around:
        g.add(piece, "ConcreteDark", -0.02, -1, None, None)
    for pts, road, walk in BEYOND:
        for q in g2.strip_quads(pts, road / 2, -road / 2):
            g.add(q, "Asphalt", 0.0, 4, None, None)
        for q in g2.strip_quads(pts, road / 2 + walk, road / 2) + g2.strip_quads(pts, -road / 2, -road / 2 - walk):
            g.add(q, "Pavers", 0.0, 2, None, None)
        city.dashes(s, pts, dash=3, gap=5, w=0.3)
        # Street lamps down the first stretch past the barrier, so the street reads as going on
        # into a lit city rather than into the dark.
        total = g2.polyline_length(pts)
        u, side = 24.0, 1
        while u < min(total, 170.0):
            p, d = g2.point_along(pts, u)
            n = g2.normal_left(d)
            x, z = p[0] + n[0] * side * (road / 2 + 1.0), p[1] + n[1] * side * (road / 2 + 1.0)
            s.box("DarkMetal", (x, 4.5, z), (0.35, 9.0, 0.35), skip=("-y",))
            head = (x - n[0] * side * 1.2, z - n[1] * side * 1.2)
            s.box("BlackMetal", (head[0], 9.1, head[1]), (1.6, 0.3, 0.8), g2.rot_of(d))
            s.box("NeonWarm", (head[0], 8.92, head[1]), (1.2, 0.06, 0.5), g2.rot_of(d), skip=("+y",))
            s.light("point", (head[0], 8.2, head[1]), (255, 200, 140), 26, 1.2)
            u += 36.0
            side = -side
    # The skirt: ground on to the horizon past the far city, and a dark floor under everything,
    # so no view (from above, or through any gap) ever ends in the void.
    for x0, z0, x1, z1 in ((-SKIRT, -SKIRT, SKIRT, -FAR), (-SKIRT, FAR, SKIRT, SKIRT), (-SKIRT, -FAR, -FAR, FAR),
                           (FAR, -FAR, SKIRT, FAR)):
        city.up_face(s, "ConcreteDark", P.box(x0, z0, x1, z1), -0.05)
    city.up_face(s, "CoreDark", P.box(-SKIRT, -SKIRT, SKIRT, SKIRT), UNDER_Y)


# How far the ground runs, well past where the fog has closed in; short of the lobby, which is
# built 3000 studs away (src/shared/Venues.luau).
SKIRT = 1400.0
UNDER_Y = -45.0  # the dark floor under the whole world (below the metro and the river)


def far_city(s, seed=7):
    """Blocks with lit windows at the map's scale, filling every view past the edges, leaving
    the streets that carry on open; taller towers further out make the skyline."""
    rng = random.Random(seed)
    corridors = []
    for pts, road, walk in BEYOND:
        corridors += g2.strip_quads(pts, road / 2 + walk + 2, -road / 2 - walk - 2)
    corridors += g2.strip_quads(P.RIVER, P.PROM_N[1] + 4, P.PROM_S[0] - 4)
    corridors.append(P.box(-FAR, P.EXPRESSWAY_Z[0] - 6, FAR, -150))
    corridors.append(P.box(-FAR, P.VIADUCT_LANE_Z[0] - 2, FAR, 152))
    map_zone = P.box(P.X0 - 4, P.Z0 - 4, P.X1 + 4, P.Z1 + 4)
    x = -560.0
    while x < 560.0:
        w = rng.uniform(26, 40)
        z = -500.0
        while z < 500.0:
            d = rng.uniform(26, 40)
            lot = P.box(x + 2, z + 2, x + w - 2, z + d - 2)
            dist = max(abs(x + w / 2) - P.X1, abs(z + d / 2) - P.Z1)
            clear = not g2.intersect(lot, map_zone) and not any(g2.intersect(lot, c) for c in corridors)
            if clear and dist < SKYLINE:
                if dist < 90:
                    buildings.far(s, lot, rng.randint(4, 12), rng.randint(1, 1 << 30))
                elif dist < 260:
                    buildings.far(s, lot, rng.randint(8, 22), rng.randint(1, 1 << 30))
                else:
                    # The skyline ring: tall and sparsely lit, closing every view out of the map.
                    buildings.far(s, lot, rng.randint(16, 30), rng.randint(1, 1 << 30), lit=0.18)
            z += d
        x += w
    # Where the expressway and the viaduct run out of the city, a tower closes each end, so no
    # view along them reaches the edge of the world.
    for x in (-FAR + 30.0, FAR - 30.0):
        for z0, z1 in ((P.EXPRESSWAY_Z[0] - 40, P.EXPRESSWAY_Z[1] + 30), (P.VIADUCT_LANE_Z[0] - 30, P.VIADUCT_Z[1] + 40)):
            buildings.far(s, P.box(x - 24, z0, x + 24, z1), rng.randint(20, 30), rng.randint(1, 1 << 30), lit=0.2)


SKYLINE = 330.0  # how far past the map's edge the city is built


def perimeter(s):
    """The safety net: behind the outermost buildings, where nobody can walk up to it."""
    lo, hi = -40.0, 200.0
    mid = (lo + hi) / 2
    for x in (P.X0 - 1.0, P.X1 + 1.0):
        s.collider((x, mid, 0.0), (1.0, hi - lo, P.Z1 - P.Z0 + 4), 0, False, None)
    for z in (P.Z0 - 1.0, P.Z1 + 1.0):
        s.collider((0.0, mid, z), (P.X1 - P.X0 + 4, hi - lo, 1.0), 0, False, None)


def build(s, g):
    expressway(s)
    viaduct(s)
    barriers(s)
    far_ground(s, g)
    far_city(s)
    perimeter(s)
