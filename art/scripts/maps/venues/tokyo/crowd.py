"""Tokyo's crowd and cars (the scramble's mechanic): where the crowd walks and stands, where the cars
drive. Data only: the game moves them (Maps/Mechanics/TokyoDistrict) and every client draws them.

- The crowd's walks: a node at each end of the four zebras, on the pavement (a "kerb" node: walkers
  wait there for the walk signal), a node on each of the scramble's four corners (the diagonals start
  there), chains of nodes out along the streets' sidewalks to the map's edge (the station plaza for the
  drive), and through the station's two side doors into its hall. Crossing links are only walked on the
  walk signal. The rest of the district too (the user's call of 2026-10-27: the crowd walks the whole map):
  a walk down every other street's pavements, the shopping arcade, the lanes and the yokocho's alleys, and
  along both river promenades, each joined to the walks it meets.
- Posts: clerks behind the konbini's till, the ramen bar's counter and the station kiosk, an
  attendant in the game centre.
- The cars' lanes: the avenue straight through both ways and a taxi from the station's rank out along
  the east street, on the left (Japan), each with the distance to its stop line, short of the
  crossing. Every street ends at a closed-road barricade by the map's edge: a lane runs from just
  inside one to just inside the other (cars fade in and out there), with nothing standing in it.

A node is joined to another once, never twice, and a walk too narrow for two to pass (under NARROW wide) is first
widened by moving its nodes (widen) and, where the pavement really is that narrow, marked `single`: the game
sends walkers along it one way at a time.

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

    def solid(self, x, z):
        """Something solid stands at (x, z) anywhere between a walker's knee and its head (a wall,
        a pole, a shopfront's sill or its overhang: the heights a walk is held open at)."""
        return any(s.kind == "box" and s.blocks(x, z, 0.4, 5.2) for s in self.world.near(x, z))

    def stand(self, x, z, room=SHOULDER):
        """A walker can stand at (x, z): on a floor, off the roadway, inside nothing, with nothing
        solid within `room` studs, and clear of the spawns and stations."""
        if self.roadway(x, z) or self.world.floor_under(x, 0.0, z, reach=1.0) is None:
            return False
        if self.solid(x, z):
            return False
        # (Rings no further apart than the thinnest pole is wide.)
        rings = max(1, math.ceil(room / 0.4))
        for ring in range(1, rings + 1):
            r = room * ring / rings
            for k in range(8 * ring):
                a = math.pi * k / (4 * ring)
                if self.solid(x + math.cos(a) * r, z + math.sin(a) * r):
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
        self.fixed = set()  # where nodes stay as they were put: (x, z) of the station's doors and the shops'
        self.shop_nodes = []  # each shop's door node (shops)

    def at(self, node):
        nd = self.s.crowd["nodes"][node - 1]
        return (nd["x"], nd["z"])

    def linked(self, a, b):
        """Whether a link already runs between the two nodes, either way round."""
        return any((lk["a"], lk["b"]) in ((a, b), (b, a)) for lk in self.s.crowd["links"])

    def link(self, a, b, most=WIDEST):
        """A walk between two nodes, as wide as the street lets it be. False (and no link) when
        something is in the way. Two nodes already joined are not joined again (a second link would
        double the odds of that turn) and a node is never joined to itself."""
        if a == b:
            return False
        pa, pb = self.at(a), self.at(b)
        if not self.street.walk(pa, pb):
            return False
        if not self.linked(a, b):
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
            for step in range(1, 60):
                out_by = REACH[name] - 4.0 + 10.0 * step
                u = _u_from_junction(name, out_by)
                if u <= 1.0 or u >= _length(name) - 1.0 or out_by > FAR[name] - 6.0:
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
        w.fixed |= {(-103.0, door_z), (-112.5, door_z)}
        for near in sorted(plaza, key=lambda m: math.dist(w.at(m), (-103.0, door_z)))[:6]:
            if w.join(near, outside):
                break
        else:
            w.missing.append(f"the station door at z {door_z}")
    district(w)
    merge_short(w)
    shops(w)
    widen(w)
    single_file(w)
    ends(w)
    spots(w)
    if w.missing:
        print("[crowd] no walk found for: " + "; ".join(w.missing))


# The rest of the district ------------------------------------------------------------------------------

STEP = 10.0  # studs between a district walk's nodes
TIE = 18.0  # studs: how far a district walk's end looks for a walk to join


def _chain(w, total, at, offsets):
    """Walk nodes every STEP studs along a line `total` long (at(u, across): the point u along it, `across` studs to
    its left), each at the first of `offsets` (or a little along) where a walker can stand with an open walk from
    the one before; where none will do, the chain ends and another starts. Returns the chains laid (two nodes or
    more each), as lists of node numbers."""
    street = w.street
    runs, run = [], []
    u = 1.0
    while u <= total - 1.0:
        last = run[-1] if run else None
        placed = None
        for shift in (0.0, 2.0, -2.0, 4.0, -4.0):
            for across in offsets:
                spot = at(min(max(u + shift, 0.5), total - 0.5), across)
                if street.stand(*spot) and (last is None or street.walk(last, spot)):
                    placed = spot
                    break
            if placed:
                break
        if placed is None:
            if len(run) >= 2:
                runs.append(run)
            run = []
        else:
            run.append(placed)
        u += STEP
    if len(run) >= 2:
        runs.append(run)
    chains = []
    for run in runs:
        nodes = [w.s.crowd_node(*spot) for spot in run]
        for a, b in zip(nodes, nodes[1:]):
            w.link(a, b)
        chains.append(nodes)
    return chains


def _tie(w, chains):
    """Each chain's two ends joined to the nearest node of the other walks within TIE (round a corner when the
    straight way is blocked), so no walk is cut off from the rest."""
    nodes = w.s.crowd["nodes"]
    for chain in chains:
        mine = set(chain)
        for end in (chain[0], chain[-1]):
            p = w.at(end)
            near = sorted((k + 1 for k in range(len(nodes)) if k + 1 not in mine
                           and math.dist(p, (nodes[k]["x"], nodes[k]["z"])) <= TIE),
                          key=lambda m: math.dist(p, w.at(m)))
            for other in near[:6]:
                if w.join(end, other):
                    break


def district(w):
    chains = []
    for name, st in P.STREETS.items():
        if name in TOWARD:
            continue  # (the scramble's own four, laid above)
        pts = st["points"]
        total = g2.polyline_length(pts)

        def at(u, across, pts=pts):
            p, d = g2.point_along(pts, u)
            n = g2.normal_left(d)
            return (p[0] + n[0] * across, p[1] + n[1] * across)

        left, right = st["walk"]
        if left <= 0 and right <= 0:
            # (a pedestrian street, a lane, an alley: down its middle, keeping to either side of it)
            chains += _chain(w, total, at, (0.0, 0.8, -0.8, 1.4, -1.4))
            continue
        for side, width in ((1, left), (-1, right)):
            if width > 0:
                mid = st["road"] / 2 + width / 2
                chains += _chain(w, total, at, tuple(side * (mid + k) for k in (0.0, -0.6, 0.6, -1.1, 1.1)))
    # The river promenades, along the water behind their railings.
    from maps.venues.tokyo import river as R  # (here: river imports the plan and the kit, which this file may not)

    line = R.inner_river()
    total = g2.polyline_length(line)
    for prom in (P.PROM_N, P.PROM_S):
        mid = (prom[0] + prom[1]) / 2

        def along_river(u, across, mid=mid):
            p, d = g2.point_along(line, u)
            n = g2.normal_left(d)
            return (p[0] + n[0] * (mid + across), p[1] + n[1] * (mid + across))

        chains += _chain(w, total, along_river, (0.0, -1.0, 1.0, -1.8, 1.8))
    _tie(w, chains)
    dropped = _one_network(w.s)
    print(f"[crowd] district: {len(chains)} walks laid, {sum(len(c) for c in chains)} nodes; {dropped} nodes cut off "
          "by roads taken out again")


SHORT = 3.0  # studs: two nodes nearer than this are one place (a walk this short is two nodes laid on top of each other)


def _contract(w, keep, drop, index):
    """Joins node `drop` into node `keep` (the link `index` between them goes): everything that ran to `drop` runs to
    `keep`, which stands where it was (a kerb never moves; two plain nodes meet half way when the ground allows), the
    walks round it are measured again and the node numbers close up. False, and nothing changed, when a walk that
    would then run from it is blocked."""
    s, street = w.s, w.street
    nodes, links = s.crowd["nodes"], s.crowd["links"]
    kerb = nodes[keep - 1]["kind"] == "kerb" or nodes[drop - 1]["kind"] == "kerb"
    at = w.at(keep)
    if not kerb:
        mid = (round((at[0] + w.at(drop)[0]) / 2, 2), round((at[1] + w.at(drop)[1]) / 2, 2))
        if street.stand(*mid):
            at = mid
    elif nodes[keep - 1]["kind"] != "kerb":
        at = w.at(drop)
    joined, seen = [], set()
    for i, lk in enumerate(links):
        if i == index:
            continue
        a, b = (keep if lk["a"] == drop else lk["a"]), (keep if lk["b"] == drop else lk["b"])
        if a == b or (min(a, b), max(a, b)) in seen:
            continue  # (a self-link, or a second link between the same two nodes)
        seen.add((min(a, b), max(a, b)))
        joined.append(dict(lk, a=a, b=b))
    for lk in joined:
        if lk["kind"] == "walk" and keep in (lk["a"], lk["b"]):
            far = lk["b"] if lk["a"] == keep else lk["a"]
            if not street.walk(at, w.at(far)):
                return False
    nodes[keep - 1]["x"], nodes[keep - 1]["z"] = at
    if kerb:
        nodes[keep - 1]["kind"] = "kerb"
    for lk in joined:
        if lk["kind"] == "walk" and keep in (lk["a"], lk["b"]):
            far = lk["b"] if lk["a"] == keep else lk["a"]
            lk["width"] = 2 * street.half(at, w.at(far))
    # (the numbers close up over the dropped node)
    renumber = lambda n: n - 1 if n > drop else n  # noqa: E731
    s.crowd["links"] = [dict(lk, a=renumber(lk["a"]), b=renumber(lk["b"])) for lk in joined]
    del nodes[drop - 1]
    return True


def merge_short(w):
    """Contracts every walk shorter than SHORT (nodes laid almost on top of each other: a crowd waiting for the same
    lamp from three sides stood in a heap on a 2-stud hub). Never a station door's node."""
    merged, tried = 0, set()
    while True:
        nodes, links = w.s.crowd["nodes"], w.s.crowd["links"]
        best = None
        for index, lk in enumerate(links):
            if lk["kind"] != "walk":
                continue
            a, b = w.at(lk["a"]), w.at(lk["b"])
            length = math.dist(a, b)
            if length < SHORT and (a, b) not in tried and (best is None or length < best[0]):
                if not any(p in w.fixed for p in (a, b)):
                    best = (length, index, lk["a"], lk["b"], (a, b))
        if best is None:
            break
        _, index, a, b, key = best
        keep, drop = (b, a) if nodes[b - 1]["kind"] == "kerb" and nodes[a - 1]["kind"] != "kerb" else (a, b)
        if _contract(w, keep, drop, index):
            merged += 1
        else:
            tried.add(key)
    print(f"[crowd] {merged} nodes merged into their neighbours (walks under {SHORT:g} studs)")


SHOP_REACH = 12.0  # studs: a post this near a door is the clerk of the shop behind it
DOOR_OUT = (2.5, 3.5, 4.5)  # how far outside a shop's door a walker stands to go in (the first that is free)
DOOR_NODE = 3.5  # studs: a node already this near that spot serves as the door's node


def _outward(rot):
    """The unit vector a door faces out of the building (rot 0 faces -Z, as everywhere in the scene)."""
    a = math.radians(rot)
    return (-math.sin(a), -math.cos(a))


def shops(w):
    """A door node for each shop that has a clerk or attendant in the crowd's posts (the konbini, the ramen bar, the
    game centre): the nearest opening to the post is the shop's door, and a node stands just outside it (an
    existing one when it is close, else a new one joined to the walks round it). Walkers go in and out there
    (ends). The station kiosk stands inside the hall, with no shop door near, and is left out."""
    s, street = w.s, w.street
    for post in s.crowd["posts"]:
        if not s.openings:
            break
        door = min(s.openings, key=lambda o: math.dist((o[0], o[2]), (post["x"], post["z"])))
        dx, _, dz, _, rot = door[:5]
        if math.dist((dx, dz), (post["x"], post["z"])) > SHOP_REACH:
            continue
        out = _outward(rot)
        near = min(range(1, len(s.crowd["nodes"]) + 1), key=lambda m: math.dist(w.at(m), (dx, dz)))
        if math.dist(w.at(near), (dx + out[0] * DOOR_OUT[0], dz + out[1] * DOOR_OUT[0])) <= DOOR_NODE:
            w.shop_nodes.append(near)
            continue
        for reach in DOOR_OUT:
            spot = (round(dx + out[0] * reach, 2), round(dz + out[1] * reach, 2))
            if not street.stand(*spot):
                continue
            node = s.crowd_node(*spot)
            others = sorted((m for m in range(1, node) if math.dist(w.at(m), spot) <= 24.0),
                            key=lambda m: math.dist(w.at(m), spot))
            if any(w.join(node, other) for other in others[:6]):
                w.fixed.add(spot)
                w.shop_nodes.append(node)
                break
            # (no way in from here: the node goes, the numbers stay as they were)
            s.crowd["nodes"].pop()
        else:
            w.missing.append(f"the {post['kind']}'s shop door at {dx:.0f}, {dz:.0f}")


# Where trips begin and end, and how often each is chosen (the sim sends every walker from one end to another by the
# shortest way and takes it out of the world there for a few seconds): the station and the scramble's streets are the
# busiest, a lane or an alley's end the quietest.
W_STATION = 4.0  # each of the station's two side doors
W_AVENUE = 3.0  # the far end of the avenue's sidewalks and of the north street
W_EDGE = 1.5  # a barricade at the map's edge on a service street or lane
W_SHOP = 1.5  # a shop's door
W_ARCADE = 2.0  # the shopping street's far end
W_BACK = 0.6  # the end of an alley, a lane or a back street
EDGE_MARGIN = 18.0  # studs from the map's edge within which a dead end is a barricade


def ends(w):
    """Marks the nodes where trips begin and end (layout.crowd_end): the station's side doors, the map's edge, the
    shops' doors, the shopping street's far end, and every other dead end (an alley's end: a bar's back door)."""
    s = w.s
    nodes = s.crowd["nodes"]
    count = len(nodes)
    degree = [0] * (count + 1)
    for lk in s.crowd["links"]:
        degree[lk["a"]] += 1
        degree[lk["b"]] += 1
    chosen = {}

    def add(node, kind, weight, name):
        if node not in chosen or chosen[node][1] < weight:
            chosen[node] = (kind, weight, name)

    def nearest(point, among=None):
        return min(among or range(1, count + 1), key=lambda m: math.dist(w.at(m), point))

    for x, z in sorted(w.fixed):
        if x < -110.0:  # the hall's side of a station door
            add(nearest((x, z)), "door", W_STATION, "station door")
    for node in w.shop_nodes:
        add(node, "door", W_SHOP, "shop door")
    x0, x1, z0, z1 = P.X0, P.X1, P.Z0, P.Z1
    for m in range(1, count + 1):
        if degree[m] != 1:
            continue
        x, z = w.at(m)
        edge = x - x0 < EDGE_MARGIN or x1 - x < EDGE_MARGIN or z - z0 < EDGE_MARGIN or z1 - z < EDGE_MARGIN
        add(m, "edge" if edge else "door", W_EDGE if edge else W_BACK, "map edge" if edge else "dead end")
    for name, index in (("ave_nw", 0), ("ave_se", -1), ("kita", 0)):
        add(nearest(P.STREETS[name]["points"][index]), "edge", W_AVENUE, name + "'s far end")
    add(nearest(P.STREETS["arcade"]["points"][-1]), "door", W_ARCADE, "the arcade's far end")
    for node, (kind, weight, name) in sorted(chosen.items()):
        s.crowd_end(node, kind, weight, name)
    print(f"[crowd] {len(chosen)} ends: " + ", ".join(
        f"{kind} {sum(1 for k, _, _ in chosen.values() if k == kind)}" for kind in ("edge", "door")))


SPOT_REACH = 4.5  # studs: how far off a walk a pause spot may be (a walker steps off to it)
SPOT_FRONT = (1.9, 2.6, 3.4)  # how far in front of what it looks at a walker stands: the first of these that is free
SPOT_APART = 6.0  # studs: no two spots nearer than this (one walker at each window, each machine)
SPOT_MOST = {"vending": 12, "sign": 36, "rail": 16, "awning": 20}  # how many of each kind
SIGN_LOW = 8.0  # studs: a sign this low or lower is a shop front's, to be looked up at
RAIL_EVERY = 30.0  # studs between the spots along a river promenade


def _rot_facing(dx, dz):
    """The heading (degrees, as a post's rot) of someone who faces along (dx, dz): rot 0 faces -Z."""
    return math.degrees(math.atan2(-dx, -dz))


def _closest(p, a, b):
    """The point on the segment a-b nearest p, and how far along a-b it is."""
    abx, abz = b[0] - a[0], b[1] - a[1]
    length2 = abx * abx + abz * abz
    t = 0.0 if length2 < 1e-9 else max(0.0, min(1.0, ((p[0] - a[0]) * abx + (p[1] - a[1]) * abz) / length2))
    return (a[0] + abx * t, a[1] + abz * t), t * math.sqrt(length2)


def spots(w):
    """Where walkers stop on the way for a reason (layout.crowd_spot): in front of a vending machine, under a low shop
    sign to look up at it, at the river's rail, under an awning out of the rain. Each has the heading its walker faces
    there, and hangs off the nearest walk (within SPOT_REACH, with open ground between): the walker steps off it at
    that place, stands, and steps back on. A spot holds one walker."""
    s, street = w.s, w.street
    nodes, links = s.crowd["nodes"], s.crowd["links"]
    chosen = []
    counts = {kind: 0 for kind in SPOT_MOST}

    def hang(spot):
        """(link number, studs along it) of the walk this spot hangs off, or None."""
        best = None
        for number, lk in enumerate(links, start=1):
            if lk["kind"] != "walk" or lk.get("single"):
                continue  # (nobody steps off a crossing, nor out of the way of the one at a time on a narrow walk)
            a, b = nodes[lk["a"] - 1], nodes[lk["b"] - 1]
            point, along = _closest(spot, (a["x"], a["z"]), (b["x"], b["z"]))
            dist = math.dist(point, spot)
            if dist <= SPOT_REACH and (best is None or dist < best[0]) and street.open(point, spot, 0.3):
                best = (dist, number, along)
        return None if best is None else best[1:]

    def offer(kind, spot, rot):
        if counts[kind] >= SPOT_MOST[kind] or not street.stand(spot[0], spot[1], 0.6):
            return False
        if any(math.dist(spot, other) < SPOT_APART for other in chosen):
            return False
        found = hang(spot)
        if found is None:
            return False
        number, along = found
        s.crowd_spot(round(spot[0], 2), round(spot[1], 2), round(rot, 1), kind, number, round(along, 2))
        chosen.append(spot)
        counts[kind] += 1
        return True

    def in_front(kind, x, z, rot):
        """A spot in front of something at (x, z) that faces out along `rot`, looking at it."""
        out = (-math.sin(math.radians(rot)), -math.cos(math.radians(rot)))
        for reach in SPOT_FRONT:
            if offer(kind, (x + out[0] * reach, z + out[1] * reach), _rot_facing(-out[0], -out[1])):
                return

    for key, x, _, z, rot, *_rest in s.props:
        if key.startswith("Vending"):
            in_front("vending", x, z, rot)
    for sign in s.signs:
        x, y, z = sign["pos"]
        if 0 <= y < SIGN_LOW and sign["w"] <= 4.0:
            in_front("sign", x, z, sign["rot"])
    from maps.venues.tokyo import river as R  # (here: river imports the plan and the kit, which this file may not)

    line = R.inner_river()
    total = g2.polyline_length(line)
    for prom, toward in ((P.PROM_N, -1.0), (P.PROM_S, 1.0)):
        mid = (prom[0] + prom[1]) / 2
        u = RAIL_EVERY / 2
        while u < total - 1.0:
            p, d = g2.point_along(line, u)
            n = g2.normal_left(d)
            spot = (p[0] + n[0] * mid, p[1] + n[1] * mid)
            offer("rail", spot, _rot_facing(n[0] * toward, n[1] * toward))
            u += RAIL_EVERY
    for centre, size, _rot, _amount in s.covers:
        if 8.0 <= centre[1] <= 12.0 and size[2] >= 2.9:
            spot = (centre[0], centre[2])
            # facing the nearest street's centre line: out at the road, the rain falling beyond the awning's edge
            nearest = None
            for st in P.STREETS.values():
                for p, q in zip(st["points"], st["points"][1:]):
                    point, _ = _closest(spot, p, q)
                    if nearest is None or math.dist(point, spot) < nearest[0]:
                        nearest = (math.dist(point, spot), point)
            if nearest is not None and nearest[0] > 0.5:
                offer("awning", spot, _rot_facing(nearest[1][0] - spot[0], nearest[1][1] - spot[1]))
    print("[crowd] pause spots: " + ", ".join(f"{k} {v}" for k, v in counts.items()))


NARROW = 1.5  # studs: a walk narrower than this is single file (two walkers cannot pass or keep left on it)
NUDGE = (0.5, 1.0, 1.5, 2.0, 2.5)  # how far a node may be moved to widen the walks it ends
APART = 3.0  # ...and how close it may come to another node while it moves


def widen(w):
    """Narrow walks (under NARROW wide: a walker cannot keep left on one, nor step round anyone) are widened by
    moving the nodes they run between, a little at a time, to the nearest place where every walk at the node is open
    and wide (never a kerb, a crossing's end or a station door: their places are laid on purpose). A walk that is
    still too narrow where the pavement really is that narrow is marked `single`: the game sends walkers along it
    one way at a time (CrowdSim)."""
    s, street = w.s, w.street
    nodes, links = s.crowd["nodes"], s.crowd["links"]
    stuck = {m for lk in links if lk["kind"] == "crossing" for m in (lk["a"], lk["b"])}
    count = len(nodes)

    def movable(i):
        nd = nodes[i - 1]
        return nd["kind"] == "walk" and i not in stuck and (nd["x"], nd["z"]) not in w.fixed

    def walks_at(i):
        return [lk for lk in links if lk["kind"] == "walk" and i in (lk["a"], lk["b"])]

    def other(lk, i):
        return lk["b"] if lk["a"] == i else lk["a"]

    def trial(i, spot):
        """(how many of the walks at node i are narrow, minus their total width) with it at `spot`; None when
        one of them could not be walked from there."""
        narrow, total = 0, 0.0
        for lk in walks_at(i):
            far = w.at(other(lk, i))
            if not street.walk(spot, far):
                return None
            width = 2 * street.half(spot, far)
            narrow += width < NARROW
            total += width
        return narrow, -total

    moved = 0
    for _ in range(3):
        changed = False
        for i in range(1, count + 1):
            if not movable(i) or all(lk["width"] >= NARROW for lk in walks_at(i)):
                continue
            nd = nodes[i - 1]
            here = (nd["x"], nd["z"])
            best, best_spot = trial(i, here) or (math.inf, 0.0), None
            gaps = {j: min(APART, math.dist(here, w.at(j))) for j in range(1, count + 1) if j != i}
            for reach in NUDGE:
                for k in range(16):
                    a = 2 * math.pi * k / 16
                    spot = (round(here[0] + reach * math.cos(a), 2), round(here[1] + reach * math.sin(a), 2))
                    if any(math.dist(spot, w.at(j)) < gap for j, gap in gaps.items()) or not street.stand(*spot):
                        continue
                    score = trial(i, spot)
                    if score is not None and score < best:
                        best, best_spot = score, spot
            if best_spot is not None:
                nd["x"], nd["z"] = best_spot
                for lk in walks_at(i):
                    lk["width"] = 2 * street.half(w.at(lk["a"]), w.at(lk["b"]))
                moved += 1
                changed = True
        if not changed:
            break
    print(f"[crowd] widening: {moved} nodes moved")


def single_file(w):
    """Marks every walk still under NARROW wide `single` (after the last node is laid and moved)."""
    links = w.s.crowd["links"]
    single = 0
    for lk in links:
        if lk["kind"] == "walk" and lk["width"] < NARROW:
            lk["single"] = True
            single += 1
    print(f"[crowd] {single} of {len(links)} walks are single file")


def _one_network(s):
    """Takes out every node no walk joins to the scramble's (a stretch of pavement or promenade cut off by roads:
    MapContract wants every walk reachable from the others, and a walker put there would pace it for ever).
    Returns how many went."""
    nodes, links = s.crowd["nodes"], s.crowd["links"]
    parent = list(range(len(nodes) + 1))

    def root(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for link in links:
        parent[root(link["a"])] = root(link["b"])
    main = root(1)
    keep = [i for i in range(1, len(nodes) + 1) if root(i) == main]
    number = {old: new for new, old in enumerate(keep, start=1)}
    s.crowd["nodes"] = [nodes[i - 1] for i in keep]
    s.crowd["links"] = [dict(link, a=number[link["a"]], b=number[link["b"]]) for link in links
                        if link["a"] in number and link["b"] in number]
    return len(nodes) - len(keep)


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
    posts(s)  # (first: the walks give each shop with a clerk a door to go in by)
    walks(s)
    lanes(s)
