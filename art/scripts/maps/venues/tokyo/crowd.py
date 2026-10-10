"""Tokyo's crowd and cars (the scramble's mechanic): where the crowd walks and stands, where the cars
drive. Data only: the game moves them (Maps/Mechanics/TokyoDistrict) and every client draws them.

- The crowd's walks: a node at each end of the four zebras, on the pavement (a "kerb" node: walkers
  wait there for the walk signal), a node on each of the scramble's four corners (the diagonals start
  there), chains of nodes out along the streets' sidewalks (the station plaza for the drive), and
  through the station's two side doors into its hall. Crossing links are only walked on the walk
  signal.
- Posts: clerks behind the konbini's till, the ramen bar's counter and the station kiosk, an
  attendant in the game centre.
- The cars' lanes: the avenue straight through both ways and a taxi from the station's rank out along
  the east street, on the left (Japan), each with the distance to its stop line, short of the
  crossing. Every street ends at a closed-road barricade by the map's edge: a lane runs from just
  inside one to just inside the other (cars fade in and out there), with nothing standing in it.

Every node and walk is placed against the scene as it stands, with the checker's own eyes
(check_v2.World): on a floor, on the pavement, inside nothing, round the street lights, planters and
vending machines, and clear of the spawns and the stations."""

import math

from maps import check_v2 as C
from maps import geo2d as g2
from maps.venues.tokyo import plan as P

# The approaches in turning order (plan.APPROACHES): the avenue from the north-west, the east street,
# the avenue to the south-east, the drive. Whether a street's points run toward the junction.
TOWARD = {"ave_nw": True, "east": False, "ave_se": False, "drive": True}
REACH = {"ave_nw": 38.0, "east": 32.0, "ave_se": 38.0, "drive": 40.0}
# How far out from the junction each street's lanes run: to its barricade (the police car parked
# across the east street), the drive to its end at the taxi rank.
FAR = {"ave_nw": 97.0, "east": 214.0, "ave_se": 226.0, "drive": 65.0}

# Nobody of the crowd walks over a station's worker or where a player spawns (check_v2 and the game's
# MapContract.validateCrowd hold the walks to 10 and 4 studs; a little more here).
STATION_CLEAR = 10.5
SPAWN_CLEAR = 4.5
ROADWAY = {"road", "crossing", "water", "track"}
SHOULDER = 0.75  # how far either side of a walk's line must be free of anything solid
WAITING = 1.5  # ...and all round a node where walkers wait in a group (a zebra's end, a corner)
WIDEST = 1.25  # half the widest a walk is (walkers keep to its left, two abreast with those coming)
STOP_SHORT = 2.5  # how far before the scramble's own asphalt a lane's stop line is


def _length(name):
    return g2.polyline_length(P.STREETS[name]["points"])


def _along(name, u, left):
    """The point u studs along a street's centre line, `left` studs to the left of its direction."""
    p, d = g2.point_along(P.STREETS[name]["points"], max(0.5, min(_length(name) - 0.5, u)))
    n = g2.normal_left(d)
    return (p[0] + n[0] * left, p[1] + n[1] * left)


def _u_from_junction(name, dist):
    """The distance along the street's points of a spot `dist` studs out from the junction."""
    return _length(name) - dist if TOWARD[name] else dist


class Street:
    """The scene as the crowd has to walk it: what is solid, what is roadway, what must be kept
    clear."""

    def __init__(self, s):
        data = {"colliders": [list(c) for c in s.colliders], "floors": [list(f) for f in s.floors],
                "ramps": s.ramps, "props": [list(p) for p in s.props]}
        self.world = C.World(data, C.load_catalog())
        self.zones = C.Zones(s.zones)
        self.keep = []
        for group in (s.layout, s.spare):
            self.keep += [(st["x"], st["z"], STATION_CLEAR) for st in group["stations"]]
            self.keep += [(sp["x"], sp["z"], SPAWN_CLEAR) for sp in group["spawns"]]

    def roadway(self, x, z):
        return bool(set(self.zones.kinds(x, 0.0, z)) & ROADWAY)

    def stand(self, x, z, room=SHOULDER):
        """A walker can stand at (x, z): on a floor, off the roadway, inside nothing, with nothing
        solid within `room` studs, and clear of the spawns and stations."""
        if self.roadway(x, z) or self.world.floor_under(x, 0.0, z, reach=1.0) is None:
            return False
        if self.world.inside(x, 0.0, z):
            return False
        # (Rings no further apart than the thinnest pole is wide.)
        rings = max(1, math.ceil(room / 0.4))
        for ring in range(1, rings + 1):
            r = room * ring / rings
            for k in range(8 * ring):
                a = math.pi * k / (4 * ring)
                if self.world.inside(x + math.cos(a) * r, 0.0, z + math.sin(a) * r):
                    return False
        return all(math.dist((x, z), (kx, kz)) >= r for kx, kz, r in self.keep)

    def open(self, a, b, side):
        """Nothing solid on the line a -> b, nor `side` studs to either side of it."""
        length = math.dist(a, b)
        if length < 1e-6:
            return True
        nx, nz = (b[1] - a[1]) / length, -(b[0] - a[0]) / length
        # (Lines no further apart than the thinnest pole is wide.)
        lines = max(1, math.ceil(side / 0.4))
        for k in range(-lines, lines + 1):
            off = side * k / lines
            p = (a[0] + nx * off, a[1] + nz * off)
            q = (b[0] + nx * off, b[1] + nz * off)
            if not self.world.open(p, q, 0.0):
                return False
        return True

    def walk(self, a, b):
        """A walk can run from a to b: open a shoulder's width either side, and never over the
        roadway."""
        if not self.open(a, b, SHOULDER):
            return False
        steps = max(4, int(math.dist(a, b) / 2))
        return not any(self.roadway(a[0] + (b[0] - a[0]) * k / steps, a[1] + (b[1] - a[1]) * k / steps)
                       for k in range(1, steps))

    def half(self, a, b, most=WIDEST):
        """Half the width a walk from a to b can have (its walkers spread that far from its line)."""
        for h in (1.25, 1.0, 0.75, 0.5, 0.25):
            if h <= most and self.open(a, b, h + 0.5):
                return h
        return 0.25


class Walks:
    def __init__(self, s):
        self.s = s
        self.street = Street(s)
        self.missing = []

    def at(self, node):
        nd = self.s.crowd["nodes"][node - 1]
        return (nd["x"], nd["z"])

    def link(self, a, b, most=WIDEST):
        """A walk between two nodes, as wide as the street lets it be. False (and no link) when
        something is in the way."""
        pa, pb = self.at(a), self.at(b)
        if not self.street.walk(pa, pb):
            return False
        self.s.crowd_link(a, b, "walk", 2 * self.street.half(pa, pb, most))
        return True

    def join(self, a, b):
        """A walk from a to b, round a corner when the straight line is blocked (one extra node)."""
        if self.link(a, b):
            return True
        (ax, az), (bx, bz) = self.at(a), self.at(b)
        for via in ((ax, bz), (bx, az), ((ax + bx) / 2, az), ((ax + bx) / 2, bz), (ax, (az + bz) / 2), (bx, (az + bz) / 2)):
            if self.street.stand(*via) and self.street.walk((ax, az), via) and self.street.walk(via, (bx, bz)):
                node = self.s.crowd_node(via[0], via[1])
                self.link(a, node)
                self.link(node, b)
                return True
        return False


def walks(s):
    w = Walks(s)
    street = w.street
    count = len(P.APPROACHES)
    # The corners first: one node each on the pavement between two approaches (the diagonals start
    # there, and a zebra whose own end has no pavement to stand on ends there too).
    corners = {}
    cx, cz = P.SCRAMBLE_CENTRE
    for i in range(count):
        j = (i + 1) % count
        mx, mz = P._kerb_mid(i, j)
        d = math.hypot(mx - cx, mz - cz)
        ux, uz = (mx - cx) / d, (mz - cz) / d
        off = 3.0
        while off < 14.0 and not street.stand(mx + ux * off, mz + uz * off, WAITING):
            off += 0.5
        corners[(i, j)] = s.crowd_node(mx + ux * off, mz + uz * off, kind="kerb")
    kerb_nodes = []  # per approach: [left node, right node]
    for i, ap in enumerate(P.APPROACHES):
        name = ap["name"]
        (px, pz), out = ap["at"], ap["out"]
        n = g2.normal_left(out)
        hw = ap["width"] / 2
        # The zebra's two ends: on its line, 4 studs into the junction, out on the pavement. Where the
        # scramble's asphalt cuts the corner and leaves no pavement on that line, the zebra ends on
        # the corner itself.
        back = (px - out[0] * 4.0, pz - out[1] * 4.0)
        own = [corners[((i - 1) % count, i)], corners[(i, (i + 1) % count)]]
        pair = []
        for side in (1, -1):
            off = hw + 2.6
            while off <= hw + 8.0 and not street.stand(back[0] + n[0] * side * off, back[1] + n[1] * side * off, WAITING):
                off += 0.5
            end = (back[0] + n[0] * side * off, back[1] + n[1] * side * off)
            if off <= hw + 8.0:
                pair.append(s.crowd_node(end[0], end[1], kind="kerb"))
            else:
                pair.append(min(own, key=lambda m: math.dist(w.at(m), end)))
        s.crowd_link(pair[0], pair[1], "crossing", 5.0)
        kerb_nodes.append(pair)
        # Out along both sidewalks (the station plaza beside the drive), every 10 studs or so. A node
        # moves along the street or across the pavement to keep clear of what stands there; when no
        # place will do, it is left out and the walk runs on to the next. A walk that something
        # blocks after a single node (the vending machine that fills the east street's south
        # pavement) is not laid at all: nobody walks ten studs to a dead end.
        walk = P.STREETS[name]["walk"]
        width = max(walk) if max(walk) > 0 else 8.0
        inset = width / 2 if max(walk) > 0 else 4.0
        for side in (1, -1):
            start = pair[0 if side == 1 else 1]
            # The side of the street this chain is on, as the street's own points run: the one
            # nearer where the zebra's end would be.
            end = (back[0] + n[0] * side * (hw + 2.6), back[1] + n[1] * side * (hw + 2.6))
            u0 = _u_from_junction(name, REACH[name] + 6.0)
            sgn = 1 if math.dist(_along(name, u0, hw + inset), end) <= math.dist(_along(name, u0, -(hw + inset)), end) else -1
            chain = []
            for step in range(1, 6):
                u = _u_from_junction(name, REACH[name] - 4.0 + 10.0 * step)
                if u <= 1.0 or u >= _length(name) - 1.0:
                    break
                last = chain[-1] if chain else w.at(start)
                placed = None
                for shift in (0.0, 2.5, -2.5, 4.5, -4.5):
                    for across in (0.0, -0.7, 0.7, -1.3, 1.3, -1.9, 1.9):
                        spot = _along(name, u + shift, sgn * (hw + inset + across))
                        if street.stand(*spot) and street.walk(last, spot):
                            placed = spot
                            break
                    if placed:
                        break
                if placed is not None:
                    chain.append(placed)
            if len(chain) >= 2:
                prev = start
                for spot in chain:
                    cur = s.crowd_node(*spot)
                    w.link(prev, cur, min(WIDEST, inset))
                    prev = cur
    # Each corner joined to the zebra ends either side of it; the diagonals between the corners.
    for (i, j), node in corners.items():
        for k in (i, j):
            nearest = min(kerb_nodes[k], key=lambda m: math.dist(w.at(m), w.at(node)))
            if nearest != node and not w.join(node, nearest):
                w.missing.append(f"corner {i}-{j} to the zebra of approach {k}")
    s.crowd_link(corners[(3, 0)], corners[(1, 2)], "crossing", 4.0)
    s.crowd_link(corners[(0, 1)], corners[(2, 3)], "crossing", 4.0)
    # Into the station hall through its two side doors, from the nearest of the plaza's walks.
    nodes = s.crowd["nodes"]
    plaza = [k + 1 for k, nd in enumerate(nodes) if nd["kind"] == "walk"]
    for door_z in (-80.0, -44.0):
        outside = s.crowd_node(-103.0, door_z)
        inside = s.crowd_node(-112.5, door_z)
        s.crowd_link(outside, inside, "walk", 2.5)
        for near in sorted(plaza, key=lambda m: math.dist(w.at(m), (-103.0, door_z)))[:6]:
            if w.join(near, outside):
                break
        else:
            w.missing.append(f"the station door at z {door_z}")
    if w.missing:
        print("[crowd] no walk found for: " + "; ".join(w.missing))


def posts(s):
    s.crowd_post(40.0, -40.9, 180)  # the konbini's till, facing the shop
    s.crowd_post(90.5, -89.8, 180)  # the ramen bar's cook, behind the counter
    s.crowd_post(-148.9, -100.0, -90)  # the station kiosk
    s.crowd_post(47.6, -108.6, 180, kind="attendant")  # the game centre, by the claw machines


def lanes(s):
    """The cars' lanes: in along the left of one approach, straight over the junction, out along the
    left of the opposite one. Two roads cross here and take turns (ScrambleCycle.roadLamp): road 1 is
    the avenue, both ways; road 2 a taxi pulling out of the station's rank and away down the east
    street (nothing drives into the drive: a taxi stands parked in that lane). A lane's stop line is
    STOP_SHORT studs before its cars would reach the scramble's own asphalt (the zebra is on it)."""
    zones = C.Zones(s.zones)
    for a, b, road, kinds in [(0, 2, 1, None), (2, 0, 1, None), (3, 1, 2, ["Taxi"])]:
        ina, inb = P.APPROACHES[a], P.APPROACHES[b]
        na, nb = ina["name"], inb["name"]
        hwa, hwb = ina["width"] / 2, inb["width"] / 2
        # Coming in: the left of travel toward the junction.
        left_in = hwa / 2 if TOWARD[na] else -hwa / 2
        # Where the lane meets the scramble: the first spot on its way in that is on the crossing.
        meets = REACH[na]
        for tenth in range(int((REACH[na] + 12.0) * 10), int((REACH[na] - 12.0) * 10), -1):
            spot = _along(na, _u_from_junction(na, tenth / 10), left_in)
            if "crossing" in zones.kinds(spot[0], 0.0, spot[1]):
                meets = tenth / 10
                break
        stop_at = meets + STOP_SHORT
        points = [_along(na, _u_from_junction(na, FAR[na]), left_in)]
        dist = FAR[na] - 10.0
        while dist > stop_at + 4.0:
            points.append(_along(na, _u_from_junction(na, dist), left_in))
            dist -= 10.0
        points.append(_along(na, _u_from_junction(na, stop_at), left_in))
        stop = sum(math.dist(points[k], points[k + 1]) for k in range(len(points) - 1))
        # Going out: the left of travel away from the junction.
        left_out = -hwb / 2 if TOWARD[nb] else hwb / 2
        dist = REACH[nb] - 8.0
        while dist < FAR[nb] - 4.0:
            points.append(_along(nb, _u_from_junction(nb, dist), left_out))
            dist += 10.0
        points.append(_along(nb, _u_from_junction(nb, FAR[nb]), left_out))
        s.traffic_lane(points, stop, width=4.0, road=road, kinds=kinds)


def build(s):
    walks(s)
    posts(s)
    lanes(s)
