"""Tokyo's streets dressed by hand: the scramble's signals, street lights where a street really has
them, power poles and their wires, vending machines, bikes, benches and planters, the bus stop and
taxi rank, the covered shopping street's roof and gates, cherry trees and lanterns along the river,
the yokocho's lanterns and curtains, moored boats, the back alleys; the ambient sounds and the
metro train's run.

Every light here comes with the thing that makes it: a lamp head, a lantern, a vending machine,
a sign (props carry their own lights; map fittings are built next to theirs)."""

import math
import random

from maps import city, kit
from maps import geo2d as g2
from maps.buildings import edges_of
from maps.venues.tokyo import plan as P
from maps.venues.tokyo import river as R
from maps.venues.tokyo import station as ST
from maps.venues.tokyo import styles
from maps.venues.tokyo.edges import facing, place

RNG = random.Random(33)


def kerb(name, side, u, inset=1.0):
    """A spot on a street's sidewalk u studs along it, `inset` in from the kerb; with the street's
    direction and the direction from the road into the sidewalk."""
    st = P.STREETS[name]
    p, d = g2.point_along(st["points"], u)
    n = g2.normal_left(d)
    into = (n[0] * side, n[1] * side)
    off = st["road"] / 2 + inset
    return (p[0] + into[0] * off, p[1] + into[1] * off), d, into


def at_front(name, direction, frac, out=1.6):
    """A spot in front of a building's wall that faces `direction`: frac along the wall, `out`
    studs from it; with the rot that faces out from the wall."""
    b = next(b for b in P.BUILDINGS if b["name"] == name)
    edges = edges_of(b["poly"])
    e = max(edges, key=lambda e: e.n[0] * direction[0] + e.n[1] * direction[1] + 0.001 * e.length)
    x, z = e.at(e.length * frac, out)
    return x, z, facing(e.n[0], e.n[1])


def overlaps(a, b, min_area=0.5):
    hit = g2.intersect(a, b)
    return bool(hit) and abs(g2.area(hit)) > min_area


def street_light(s, name, side, u):
    (x, z), d, into = kerb(name, side, u, 0.8)
    place(s, "StreetLightTokyo", x, z, facing(-into[0], -into[1]))
    s.collider((x, 8.0, z), (0.8, 16.0, 0.8), 0, True, None)


def wire(s, a, b, sag=1.2, segments=8):
    prev = a
    for k in range(1, segments + 1):
        t = k / segments
        p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - sag * 4 * t * (1 - t), a[2] + (b[2] - a[2]) * t)
        s.tube("BlackTrim", prev, p, 0.05, 4, caps=False)
        prev = p


def power_line(s, name, side, us, inset=0.9):
    """Concrete poles along a street with their wires strung between the crossarms."""
    tops = []
    for u in us:
        (x, z), d, into = kerb(name, side, u, inset)
        s.prop("UtilityPole", x, z, g2.rot_of(into))
        s.collider((x, 13.0, z), (1.1, 26.0, 1.1), 0, True, None)
        tops.append([(x + into[0] * off, y, z + into[1] * off) for off, y in ((-2.3, 23.6), (2.3, 23.6),
                                                                              (-2.0, 21.0), (2.0, 21.0))])
    for a, b in zip(tops, tops[1:]):
        for pa, pb in zip(a, b):
            wire(s, pa, pb)


# The scramble -------------------------------------------------------------------------------------------


def scramble(s):
    for ap in P.APPROACHES:
        (px, pz), out = ap["at"], ap["out"]
        n = g2.normal_left(out)
        hw = ap["width"] / 2
        # The signal on the left kerb of the traffic coming in (Japan drives on the left), its arm
        # over the incoming lanes and its lamps facing the cars.
        sx, sz = px - n[0] * (hw + 1.4) + out[0] * 2.0, pz - n[1] * (hw + 1.4) + out[1] * 2.0
        place(s, "TrafficSignal", sx, sz, facing(n[0], n[1]))
        s.collider((sx, 6.8, sz), (0.8, 13.6, 0.8), 0, True, None)
        # Walk signals at both ends of the zebra, facing across it.
        back = (px - out[0] * 4.0, pz - out[1] * 4.0)
        for side in (1, -1):
            x = back[0] + n[0] * side * (hw + 1.6)
            z = back[1] + n[1] * side * (hw + 1.6)
            place(s, "PedestrianSignal", x, z, facing(-n[0] * side, -n[1] * side))
            s.collider((x, 4.6, z), (0.5, 9.2, 0.5), 0, True, None)
    # A street light on each of the scramble's four corners (the plaza's between the bus bay and
    # the drive).
    for x, z in ((-85.0, -71.4), (-58.0, -101.0), (-2.0, -52.0), (-54.0, -38.0)):
        place(s, "StreetLightTokyo", x, z, facing(P.SCRAMBLE_CENTRE[0] - x, P.SCRAMBLE_CENTRE[1] - z))
        s.collider((x, 8.0, z), (0.8, 16.0, 0.8), 0, True, None)


# Streets -----------------------------------------------------------------------------------------------


def streets(s):
    # The avenue: street lights on its east side, guard rails along its kerbs.
    lamps = {"ave_nw": (32.0, 78.0), "ave_se": (48.0, 96.0, 168.0, 212.0)}
    for name, us in lamps.items():
        for u in us:
            street_light(s, name, 1, u)
    others = [(n, q) for n, q in P.bands() if n not in ("ave_nw", "ave_se", "river")]
    for name, spans in (("ave_nw", [(22, 62), (70, 76)]), ("ave_se", [(42, 88), (170, 205)])):
        walk = P.STREETS[name]["walk"][0]
        for side in (1, -1):
            for u0, u1 in spans:
                u = u0
                while u + 8 <= u1:
                    (x, z), d, into = kerb(name, side, u + 4, 0.4)
                    # Never across the mouth of a side street, alley or lane (people turn in
                    # there), nor through a street light's post.
                    reach = walk + 3.0
                    foot = [(x - d[0] * 4.5, z - d[1] * 4.5), (x + d[0] * 4.5, z + d[1] * 4.5),
                            (x + d[0] * 4.5 + into[0] * reach, z + d[1] * 4.5 + into[1] * reach),
                            (x - d[0] * 4.5 + into[0] * reach, z - d[1] * 4.5 + into[1] * reach)]
                    post = side == 1 and any(u - 1.0 <= lu <= u + 9.0 for lu in lamps[name])
                    if not post and not any(overlaps(g2.ccw(foot), q) for _, q in others):
                        s.prop("GuardRail", x, z, g2.rot_of(d))
                    u += 8.4
    # Power poles and wires on the small streets.
    power_line(s, "east", -1, [56.0, 88.0, 120.0, 152.0, 186.0, 220.0])
    power_line(s, "kita", -1, [34.0, 64.0, 94.0])
    power_line(s, "minami", 1, [18.0, 46.0, 70.0])
    for u in (70.0, 136.0):
        street_light(s, "east", 1, u)
    street_light(s, "kita", 1, 50.0)
    # The frontage road under the expressway lies in the pier lamps' light (edges.py).
    # Vending machines against walls, bins beside them, bikes and scooters left by the doors.
    # (One machine on the zakkyo's short front, clear of the power pole; the bins by the pair on
    # the next block.)
    vending = [("zakkyo_se", (0, -1), 0.4), ("east_s2", (0, -1), 0.3),
               ("laundromat", (-1, 0), 0.85), ("flats_yw", (1, 0), 0.7),
               ("office_riverside", (0, -1), 0.86), ("yokocho_gate", (0, -1), 0.2)]
    for k, (name, direction, frac) in enumerate(vending):
        x, z, rot = at_front(name, direction, frac, 1.7)
        s.prop(("VendingBlue", "VendingWhite")[k % 2], x, z, rot)
    # By the station's glass front, clear of its doors, facing the plaza.
    s.prop("VendingBlue", -106.2, -30.0, -90)
    for name, direction, frac in (("east_s2", (0, -1), 0.5), ("flats_yw", (1, 0), 0.9)):
        x, z, rot = at_front(name, direction, frac, 0.8)
        s.prop("RecycleBins", x, z, rot)
    for name, direction, frac in (("konbini_block", (0, -1), 0.25), ("flats_footbridge", (0, -1), 0.4),
                                  ("arcade_n1", (0, 1), 0.3)):
        x, z, rot = at_front(name, direction, frac, 2.9)
        s.prop("BikeRack", x, z, rot + 180)
    for name, direction, frac in (("river_se1", (0, -1), 0.3), ("river_se1", (0, -1), 0.6),
                                  ("ya_n1", (0, -1), 0.5), ("yc_n2", (0, -1), 0.4), ("hotel_se", (-1, 0), 0.5)):
        x, z, rot = at_front(name, direction, frac, 1.2)
        s.prop("Bicycle", x, z, rot + 90)
    for name, direction, frac in (("konbini_block", (0, -1), 0.45), ("yokocho_gate", (1, 0), 0.5),
                                  ("river_se2", (1, 0), 0.5)):
        x, z, rot = at_front(name, direction, frac, 1.3)
        s.prop("Scooter", x, z, rot + 90)
    (x, z), d, into = kerb("minami", -1, 50.0, -2.8)
    s.prop("KeiTruck", x, z, g2.rot_of(d) + 90)
    s.collider((x, 2.7, z), (5.2, 5.4, 11.0), g2.rot_of(d) + 90, True, None)


# The station plaza ----------------------------------------------------------------------------------------


def plaza(s):
    # The bus stop on the plaza north of the drive (its shelter and sign: a parked bus would fill
    # the plaza from the station's doors to the scramble), the taxi rank on the drive's south
    # kerb with one cab waiting, clear of the doors.
    s.prop("BusShelter", -90.0, -87.0, 180)
    s.collider((-90.0, 4.2, -88.8), (11.6, 8.4, 0.4), 0, True, None)
    s.prop("BusStopSign", -101.0, -82.8, 180)
    s.prop("TaxiRankSign", -104.0, -55.0, 0)
    s.prop("Taxi", -93.0, -59.4, 90)
    # Trees in beds, benches round them, planters, the plaza's lamps.
    # (The middle bed keeps clear of the phone booth in front of it.)
    for x, z in ((-100.0, -46.0), (-86.0, -31.5), (-100.0, -96.0)):
        s.box("Stone", (x, 0.6, z), (7.0, 1.2, 7.0), 0)
        s.collider((x, 0.6, z), (7.0, 1.2, 7.0), 0, True, "Stone")
        s.prop("Tree", x, z, RNG.uniform(0, 360), 1.0, 1.2)
        s.prop("Bench", x, z + 5.2, 180)
    for x, z in ((-105.2, -50.0), (-103.0, -35.8)):
        s.prop("Planter", x, z, 90)
    for x, z in ((-104.0, -40.0), (-104.0, -104.0)):
        place(s, "StreetLightTokyo", x, z, -90)
        s.collider((x, 8.0, z), (0.8, 16.0, 0.8), 0, True, None)


# The covered shopping street ---------------------------------------------------------------------------


def arcade(s):
    """The roof over the shopping street: steel trusses carrying a glazed roof, pendant lamps,
    hanging banners; a gate arch with the street's name at each end."""
    pts = P.STREETS["arcade"]["points"]
    half = P.STREETS["arcade"]["road"] / 2 + 0.4
    y = P.ARCADE_ROOF
    for q in g2.strip_quads(pts, half, -half):
        city.down_face(s, "GlassDark", q, y + 1.2)
        city.up_face(s, "GlassDark", q, y + 1.3)
    total = g2.polyline_length(pts)
    u = 4.0
    k = 0
    while u < total - 2:
        p, d = g2.point_along(pts, u)
        n = g2.normal_left(d)
        rot = g2.rot_of(n)
        s.box("DarkMetal", (p[0], y, p[1]), (half * 2, 0.6, 0.6), rot)
        s.box("DarkMetal", (p[0], y + 1.0, p[1]), (half * 2, 0.3, 0.3), rot)
        for side in (1, -1):
            s.box("DarkMetal", (p[0] + n[0] * side * half, y - 3.0, p[1] + n[1] * side * half), (0.5, 6.0, 0.5), rot)
        if k % 2 == 0:
            # A pendant lamp under every other truss.
            s.tube("BlackMetal", (p[0], y, p[1]), (p[0], y - 6.0, p[1]), 0.05, 4)
            s.cylinder("BlackMetal", (p[0], y - 6.8, p[1]), 1.1, 0.8, segments=12, radius_top=0.4)
            s.box("NeonWarm", (p[0], y - 6.85, p[1]), (1.2, 0.1, 1.2))
            s.light("point", (p[0], y - 8.0, p[1]), (255, 226, 190), 24, 1.4)
        else:
            colour = RNG.choice(("FabricRed", "CreamTrim", "NeonPink", "Fabric"))
            s.box(colour, (p[0], y - 5.0, p[1]), (0.1, 5.0, 3.0), rot + 90)
        u += 8.0
        k += 1
    for u, out in ((0.0, -1), (total, 1)):
        p, d = g2.point_along(pts, min(u, total - 0.01))
        n = g2.normal_left(d)
        rot = g2.rot_of(n)
        for side in (1, -1):
            s.box("Steel", (p[0] + n[0] * side * (half + 0.4), y / 2 + 2, p[1] + n[1] * side * (half + 0.4)),
                  (1.0, y + 4, 1.0), rot, collide=True)
        s.box("BlackTrim", (p[0], y + 3.2, p[1]), (half * 2 + 2.0, 4.2, 1.4), rot)
        face = facing(d[0] * out, d[1] * out)
        fx, fz = p[0] + d[0] * out * 0.75, p[1] + d[1] * out * 0.75
        s.sign((fx, y + 3.2, fz), face, half * 2 + 1.0, 3.6, "影ヶ丘センター街  CENTER-GAI", "GothamBlack",
               (255, 255, 255), (220, 40, 60), glow=(220, 40, 60))
    for x, z in ((-11.0, -80.0), (-8.0, -84.0), (-5.0, -88.0)):
        s.prop("Bollard", x, z, 0)


# The river -----------------------------------------------------------------------------------------------


def riverside(s):
    """Cherry trees along both promenades with lantern strings between them (one in three lit),
    benches, moored boats, lamps at the road bridge's ends."""
    avoid = [(P.FOOTBRIDGE_X, 9.0)]
    for h in g2.polyline_hits(P.STREETS["ave_se"]["points"], R.inner_river()):
        avoid.append((h[0], 30.0))
    for offset, start, step in ((19.0, -188.0, 16.0), (-12.0, -182.0, 17.0)):
        trees = []
        x = start
        while x < 190.0:
            if not any(abs(x - ax) < reach for ax, reach in avoid):
                (cx, cz), d = P.river_frame(x)
                n = g2.normal_left(d)
                p = (cx + n[0] * offset, cz + n[1] * offset)
                s.prop("TreeSakura", p[0], p[1], RNG.uniform(0, 360), RNG.uniform(0.85, 1.05))
                # The trunk only (the promenade is 6 studs wide, the trees down its middle).
                s.collider((p[0], 3.5, p[1]), (0.8, 7.0, 0.8), 0, True, None)
                trees.append((x, p, d))
            x += step
        for k, (a, b) in enumerate(zip(trees, trees[1:])):
            if b[0] - a[0] > step + 1:
                continue
            (xa, pa, da), (xb, pb, db) = a, b
            mid = ((pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2)
            span = math.dist(pa, pb)
            s.prop("LanternString", mid[0], mid[1], g2.rot_of(da), span / 12.0, 6.6, dark=k % 3 != 1)
        for x in range(int(start) + 24, 180, 64):
            if any(abs(x - ax) < reach + 6 for ax, reach in avoid):
                continue
            (cx, cz), d = P.river_frame(x)
            n = g2.normal_left(d)
            side = 1 if offset > 0 else -1
            p = (cx + n[0] * (offset - side * 1.6), cz + n[1] * (offset - side * 1.6))
            if any(math.dist(p, tp) < 4.5 for _, tp, _ in trees):
                continue  # not under a tree's trunk
            s.prop("Bench", p[0], p[1], facing(-n[0] * side, -n[1] * side))
    for x, side in ((-36.0, 1), (136.0, -1)):
        (cx, cz), d = P.river_frame(x)
        n = g2.normal_left(d)
        off = P.CHANNEL[1] - 5.0 if side > 0 else P.CHANNEL[0] + 5.0
        s.prop("Boat", cx + n[0] * off, cz + n[1] * off, g2.rot_of(d) + 90, 1.0, P.WATER_Y - 1.4)
    # Lamps at the road bridge's four corners.
    for h in g2.polyline_hits(P.STREETS["ave_se"]["points"], P.river_line(P.CHANNEL[1] + 3.0)) + \
            g2.polyline_hits(P.STREETS["ave_se"]["points"], P.river_line(P.CHANNEL[0] - 3.0)):
        for side in (1, -1):
            p, d = h, (0.4, 0.9)
            n = g2.normal_left(d)
            kit.lantern_post(s, p[0] + n[0] * side * 16.4, p[1] + n[1] * side * 16.4, 11.0)


# The yokocho and the viaduct lane ---------------------------------------------------------------------------


def yokocho(s):
    """A pair of red lanterns under every bar's awning (the first lit), a noren in its door,
    crates and bikes; wires tangled over the alleys."""
    bars = [b for b in P.BUILDINGS if b["kind"] == "bar"]
    for k, b in enumerate(bars):
        edges = edges_of(b["poly"])
        for i in styles.fronts(b, P.BUILDINGS)[:1]:
            e = edges[i]
            if e.length < 6:
                continue
            for j, u in enumerate((1.6, e.length - 1.6)):
                x, z = e.at(u, 1.3)
                s.prop("Chochin", x, z, facing(e.n[0], e.n[1]), 1.0, 8.4, dark=j == 1 or k % 3 == 2)
            x, z = e.at(e.length / 2, 0.35)
            if b.get("use") != "izakaya":
                s.prop("Noren", x, z, facing(e.n[0], e.n[1]), 1.0 if e.length > 8 else 0.8, 6.4)
            # Crates and a grill tucked against the front: the alleys are only 5 studs wide.
            if k % 4 == 1:
                x, z = e.at(e.length - 1.8, 1.0)
                s.prop("BeerCrates", x, z, facing(e.n[0], e.n[1]))
            if k % 7 == 3 and e.length >= 10:
                x, z = e.at(e.length / 2 - 2.6, 1.15)  # the other side of the door from the crates
                s.prop("YakitoriGrill", x, z, facing(e.n[0], e.n[1]))
    # Wires zig-zagging over the alleys between the bars' upper floors.
    for name in ("y_a", "y_b", "y_c", "y_cross", "y_dead"):
        pts = P.STREETS[name]["points"]
        total = g2.polyline_length(pts)
        u = 5.0
        side = 1
        while u + 9 < total:
            p0, d0 = g2.point_along(pts, u)
            p1, d1 = g2.point_along(pts, u + 9)
            n0, n1 = g2.normal_left(d0), g2.normal_left(d1)
            a = (p0[0] + n0[0] * side * 2.6, 22.0, p0[1] + n0[1] * side * 2.6)
            b = (p1[0] - n1[0] * side * 2.6, 20.5, p1[1] - n1[1] * side * 2.6)
            wire(s, a, b, sag=0.8, segments=6)
            u += 9
            side = -side
    # The izakaya's own lanterns and curtain.
    iz = next(b for b in P.BUILDINGS if b.get("use") == "izakaya")
    e = edges_of(iz["poly"])[styles.fronts(iz, P.BUILDINGS)[0]]
    x, z = e.at(e.length / 2, 0.35)
    s.prop("Noren", x, z, facing(e.n[0], e.n[1]), 0.8, 6.4)


def viaduct_lane(s):
    """Bars in some of the viaduct's arches: a lantern and a noren; lamps on the piers."""
    z = P.VIADUCT_Z[0] - 0.4
    for x in (-178.0, -118.0, -34.0, 2.0, 122.0, 158.0):
        s.prop("Chochin", x - 3.0, z - 1.0, 180, 1.0, 8.0, dark=x not in (-118.0, 2.0, 158.0))
        s.prop("Noren", x + 1.0, z - 0.2, 180, 0.9, 6.2)
    for x in (-186.0, -150.0, -110.0, -70.0, -20.0, 30.0, 46.0, 100.0, 140.0, 184.0):
        s.box("BlackMetal", (x, 11.5, z - 0.3), (0.8, 1.0, 0.8), 0)
        s.box("NeonWarm", (x, 10.95, z - 0.3), (0.6, 0.1, 0.6), 0)
        s.light("point", (x, 10.2, z - 0.8), (255, 196, 140), 20, 1.1)


# Alleys ---------------------------------------------------------------------------------------------------


def wall_lamp(s, x, z, rot, y=9.0, color=(255, 200, 150)):
    """A caged lamp on a wall facing rot."""
    s.box("BlackMetal", (x, y + 0.3, z), (0.6, 0.8, 0.6), rot)
    s.box("NeonWarm", (x, y - 0.15, z), (0.45, 0.1, 0.45), rot)
    a = math.radians(rot)
    s.light("point", (x - math.sin(a) * 0.8, y - 0.6, z - math.cos(a) * 0.8), color, 16, 0.9)


def alleys(s):
    # The back alley behind the east street: AC units on the walls, bins, a lamp at each end.
    for x, z, rot in ((26.0, -17.2, 0), (60.0, -16.9, 0), (88.0, -15.8, 0)):
        wall_lamp(s, x, z, rot + 180, 8.0)
    for x in (32.0, 40.0, 70.0, 78.0):
        s.box("WhiteTrim", (x, 3.0, -18.4), (2.4, 2.0, 1.2), 3)
    s.prop("TrashCan", 53.0, -17.2, 0)
    s.prop("Crate", 84.0, -17.6, 12, 0.6)
    # The service alley off the east street behind the shopping street's shops, its mouth kept
    # clear (the dumpster along it: the alley is narrower than a dumpster is long; it widens
    # towards the dead end).
    s.prop("Dumpster", 71.0, -77.2, 0)  # past the hood's spot, against the shops' back wall
    wall_lamp(s, 52.0, -78.6, 180, 8.0)


def lamps_on_walls(s, name, offset, spacing=18.0, h=8.0, start=5.0, flicker_every=0):
    """Small caged lamps along a lane, alternating sides, each on a building's wall: where there
    is no wall behind a spot (a side alley opening, a gap between buildings) the lamp moves to
    the other side, or is left out, never hanging in the air."""
    pts = P.STREETS[name]["points"]
    total = g2.polyline_length(pts)
    u, k = start, 0
    while u < total - 2:
        p, d = g2.point_along(pts, u)
        n = g2.normal_left(d)
        for side in ((1, -1) if k % 2 == 0 else (-1, 1)):
            wall = next((w for w in (offset - 1.0 + 0.25 * i for i in range(20))
                         if any(g2.contains(b["poly"], (p[0] + n[0] * side * w, p[1] + n[1] * side * w))
                                for b in P.BUILDINGS)), None)
            if wall is not None:
                x, z = p[0] + n[0] * side * (wall - 0.35), p[1] + n[1] * side * (wall - 0.35)
                flicker = bool(flicker_every) and k % flicker_every == flicker_every - 1
                s.box("BlackMetal", (x, h + 0.3, z), (0.4, 0.6, 0.4), g2.rot_of(d))
                s.box("NeonWarm", (x, h - 0.15, z), (0.5, 0.3, 0.5), g2.rot_of(d))
                s.light("point", (x - n[0] * side * 0.8, h - 0.6, z - n[1] * side * 0.8), (255, 196, 140), 20.0, 1.1,
                        flicker=flicker)
                break
        k += 1
        u += spacing


def dark_corners(s):
    """Light for the stretches the street lights miss: lantern posts along the south promenade's
    west end and at the footbridge, lamps down the laundromat's lane and the yokocho's alleys,
    yard lamps in the back lots, a lamp under the expressway by the station tower."""
    for x in (-156.5, -122.5, -71.5, -37.5):
        (cx, cz), d = P.river_frame(x)
        n = g2.normal_left(d)
        off = P.PROM_S[0] + 1.0
        kit.lantern_post(s, cx + n[0] * off, cz + n[1] * off, 10.0)
    # Lantern posts at both ends of the footbridge.
    (cx, cz), d = P.river_frame(P.FOOTBRIDGE_X)
    n = g2.normal_left(d)
    for off in (P.PROM_N[0] + 2.0, P.PROM_S[1] - 2.0):
        for side in (1, -1):
            kit.lantern_post(s, cx + d[0] * side * 5.5 + n[0] * off, cz + d[1] * side * 5.5 + n[1] * off, 10.0)
    lamps_on_walls(s, "lane_e", 3.2, spacing=16.0, h=8.0, start=6.0)
    lamps_on_walls(s, "y_dead", 2.1, spacing=16.0, h=7.6, start=8.0, flicker_every=3)
    lamps_on_walls(s, "y_cross", 2.1, spacing=22.0, h=7.8, start=10.0, flicker_every=4)
    for x, z in YARD_LAMPS:
        city.pole_lamp(s, x, z)
    x, z, rot = at_front("station_tower", (0, -1), 0.55, 0.3)
    wall_lamp(s, x, z, rot, 9.0)


# Back lots the street lights miss, found by check_v2's light map (walkable ground, clear of
# walls): a cheap lamp on a pole in each.
YARD_LAMPS = [(164.0, -74.0), (162.0, -58.0), (164.0, -96.0), (131.0, -8.0)]


# Sounds and the train ------------------------------------------------------------------------------------


def ambience(s):
    s.sound("mapCityHum", (-40.0, 20.0, -62.0), radius=260.0, volume=0.35)
    s.sound("mapCrossingChirp", (-40.0, 6.0, -62.0), radius=60.0, volume=0.4)
    s.sound("mapStationChime", (-84.0, P.PLATFORM_Y + 8.0, -62.0), radius=70.0, volume=0.5, loop=False)
    s.sound("mapTrainArrive", (-84.0, P.PLATFORM_Y + 4.0, -76.5), radius=90.0, volume=0.6, loop=False)
    for x in (-120.0, 40.0, 150.0):
        (cx, cz), d = P.river_frame(x)
        s.sound("mapRiver", (cx, P.WATER_Y + 1.0, cz), radius=50.0, volume=0.3)
    s.sound("mapLanternCreak", (-60.0, 7.0, 42.0), radius=40.0, volume=0.25)
    s.sound("mapIzakaya", (-60.0, 5.0, 92.0), radius=50.0, volume=0.35)
    track_z = sum(P.TRACKS_Z[0]) / 2
    s.train = {
        "cars": ["TrainHead", "TrainMiddle"],
        "y": ST.TRACK_Y + 0.7,
        "z": track_z,
        "rot": 90,
        "enter": P.PLATFORM[1] + 70.0,
        "stop": (P.PLATFORM[0] + P.PLATFORM[1]) / 2,
        "leave": P.PLATFORM[0] - 70.0,
        "every": 120,
        "dwell": 15,
        "carLength": 51.0,
    }


def build(s):
    scramble(s)
    streets(s)
    plaza(s)
    arcade(s)
    riverside(s)
    yokocho(s)
    viaduct_lane(s)
    alleys(s)
    dark_corners(s)
    ambience(s)
