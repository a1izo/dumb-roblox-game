"""The small things of Tokyo's streets, each put where it would be: standing menu boards outside
the bars and noodle shop, bagged rubbish under nets at the collection spots, air conditioners up on
the alley walls with their pipes, plants in pots and umbrella stands by doors, posters on the
viaduct's piers and the expressway's, flyers taped round poles, hanging signs, cables run along
walls, and a few bikes, crates and cones. Every one is placed by hand below (a wall and how far
along it), kept off the walking lines and away from the case files' spots."""

from maps import geo2d as g2
from maps.buildings import edges_of
from maps.venues.tokyo import plan as P
from maps.venues.tokyo.dressing import kerb
from maps.venues.tokyo.edges import facing

SPOTS = []  # (kind, x, z, radius, y0, y1): what stands where, for the checks


def wall(name, index):
    """Wall `index` (edges_of order) of building `name`."""
    b = next(b for b in P.BUILDINGS if b["name"] == name)
    return edges_of(b["poly"])[index]


def out_rot(e):
    return facing(e.n[0], e.n[1])


def note(kind, x, z, radius, y0, y1):
    SPOTS.append((kind, x, z, radius, y0, y1))


# The pieces ------------------------------------------------------------------------------------------


def menu_board(s, e, u, out, text, bg=(26, 32, 28), fg=(236, 232, 214)):
    """A standing signboard (a chalk menu on a timber frame, two feet) with its back to the wall."""
    x, z = e.at(u, out)
    rot = out_rot(e)
    s.box("Wood", (x, 1.55, z), (2.0, 2.7, 0.22), e.rot)
    for side in (-1, 1):
        fx, fz = e.at(u + side * 0.8, out)
        s.box("Wood", (fx, 0.1, fz), (0.18, 0.2, 1.2), e.rot, skip=("-y",))
    # (Its back is to the wall: the words on the front only.)
    sx, sz = e.at(u, out + 0.26)
    s.sign((sx, 1.6, sz), rot, 1.7, 2.3, text, "GothamBlack", fg, bg)
    s.collider((x, 1.5, z), (2.0, 3.0, 1.2), e.rot, True, None)
    note("board", x, z, 1.2, 0.0, 3.0)


BAG = [(0.2, 0.0), (0.52, 0.12), (0.6, 0.45), (0.46, 0.8), (0.14, 0.98), (0.0, 1.04)]


def rubbish(s, e, u, out):
    """Bags of rubbish out for collection, a net over them against the crows."""
    bags = [(-0.8, 0.05, 1.0, "Rubber"), (0.15, 0.25, 0.9, "WhiteTrim"), (0.95, -0.05, 1.1, "Rubber"),
            (-0.2, -0.35, 0.8, "TarpBlue"), (0.55, 0.6, 0.75, "WhiteTrim")]
    for du, dout, k, mat in bags:
        x, z = e.at(u + du, out + dout)
        s.lathe(mat, (x, 0.0, z), [(r * k, y * k) for r, y in BAG], 8)
    x, z = e.at(u, out + 0.1)
    s.box("PaintYellow", (x, 1.02, z), (2.9, 0.05, 2.0), e.rot)
    s.collider((x, 0.55, z), (2.6, 1.1, 1.8), e.rot, True, None)
    note("rubbish", x, z, 1.5, 0.0, 1.1)


def air_conditioner(s, e, u, y):
    """An outdoor unit on brackets high on a wall, its pipes run up the wall into it."""
    x, z = e.at(u, 0.5)
    s.box("WhiteTrim", (x, y, z), (2.2, 1.6, 0.9), e.rot)
    gx, gz = e.at(u - 0.2, 0.96)
    s.box("DarkMetal", (gx, y, gz), (1.1, 1.1, 0.04), e.rot)
    for side in (-0.8, 0.8):
        bx, bz = e.at(u + side, 0.5)
        s.box("BlackMetal", (bx, y - 0.86, bz), (0.08, 0.12, 1.0), e.rot)
    a = e.at(u + 1.1, 0.35)
    b = e.at(u + 1.6, 0.18)
    s.tube("CreamTrim", (a[0], y + 0.2, a[1]), (b[0], y + 0.2, b[1]), 0.09, 6)
    s.tube("CreamTrim", (b[0], y + 0.2, b[1]), (b[0], y + 3.2, b[1]), 0.09, 6)
    note("ac", x, z, 1.2, y - 1.0, y + 1.0)


def potted_plants(s, e, u, out):
    """A few plants in pots by a door."""
    pots = [(0.0, 0.0, 0.5, 1.0, "BlackTrim"), (0.95, 0.25, 0.38, 0.75, "BrickRed"), (-0.85, 0.2, 0.34, 0.7, "Stone")]
    for du, dout, r, h, mat in pots:
        x, z = e.at(u + du, out + dout)
        s.cylinder(mat, (x, 0.0, z), r, h, segments=10, radius_top=r * 1.15)
        s.lathe("Foliage", (x, h - 0.05, z), [(0.1, 0.0), (r * 1.5, 0.3), (r * 1.7, 0.9), (r * 1.1, 1.5), (0.0, 1.9)],
                8)
    x, z = e.at(u, out + 0.15)
    s.collider((x, 1.2, z), (2.4, 2.4, 1.3), e.rot, True, None)
    note("plants", x, z, 1.3, 0.0, 2.6)


def umbrella_stand(s, e, u, out):
    """An umbrella stand by a shop's door, a few clear umbrellas furled in it."""
    x, z = e.at(u, out)
    s.cylinder("Steel", (x, 0.0, z), 0.34, 1.3, segments=10)
    for dx, dz, lean in ((0.1, 0.05, 0.25), (-0.12, 0.08, -0.2), (0.02, -0.12, 0.1)):
        base = (x + dx, 0.15, z + dz)
        tip = (x + dx + lean, 2.5, z + dz + lean * 0.4)
        s.tube("Glass", base, tip, 0.13, 6, radius_b=0.05)
        s.tube("BlackTrim", tip, (tip[0] + 0.1, tip[1] + 0.25, tip[2]), 0.04, 4)
    s.collider((x, 0.75, z), (0.8, 1.5, 0.8), 0, True, None)
    note("umbrellas", x, z, 0.5, 0.0, 2.8)


def poster(s, e, u, y, w, h, mat, text=None, fg=(24, 22, 26)):
    """A poster pasted on a wall (words on it, when given, in a transparent board)."""
    e.quad(s, mat, u - w / 2, u + w / 2, y - h / 2, y + h / 2, 0.03)
    if text:
        x, z = e.at(u, -0.1)
        s.sign((x, y, z), out_rot(e), w * 0.86, h * 0.86, text, "GothamBlack", fg, None)


def pier_poster(s, x, z, rot, y, w, h, mat, text=None, fg=(24, 22, 26)):
    """A poster on a free-standing face (a pier) at (x, z) facing rot."""
    import math

    a = math.radians(rot)
    fx, fz = -math.sin(a), -math.cos(a)
    t = (math.cos(a), -math.sin(a))
    p0 = (x - t[0] * w / 2 + fx * 0.03, z - t[1] * w / 2 + fz * 0.03)
    p1 = (x + t[0] * w / 2 + fx * 0.03, z + t[1] * w / 2 + fz * 0.03)
    from maps import city

    city.vquad(s, mat, p0, p1, y - h / 2, y + h / 2, (fx, fz))
    if text:
        s.sign((x - fx * 0.1, y, z - fz * 0.1), rot, w * 0.86, h * 0.86, text, "GothamBlack", fg, None)


def pole_flyers(s, x, z, y=4.2):
    """Flyers taped round a utility pole, one over another."""
    s.box("Paper", (x, y, z), (1.2, 1.0, 1.2), 17)
    s.box("PaintYellow", (x, y + 0.9, z), (1.18, 0.7, 1.18), 17)


def hanging_sign(s, e, u, y, text, bg, fg):
    """A small sign hanging out from a wall on an iron arm, words on both faces."""
    ax, az = e.at(u, 0.8)
    s.box("BlackMetal", (ax, y + 1.05, az), (0.1, 0.1, 1.6), e.rot)
    bx, bz = e.at(u, 1.1)
    s.box("BlackTrim", (bx, y, bz), (0.2, 1.8, 1.3), e.rot)
    for side in (1, -1):
        sx, sz = bx + e.t[0] * side * 0.26, bz + e.t[1] * side * 0.26
        s.sign((sx, y, sz), facing(e.t[0] * side, e.t[1] * side), 1.1, 1.6, text, "GothamBlack", fg, bg,
               glow=bg if side > 0 else None)
    note("hanging sign", bx, bz, 0.8, y - 1.0, y + 1.2)


def cables(s, e, u0, u1, y):
    """Cables clipped along a wall from a junction box."""
    for dy, out, r in ((0.0, 0.12, 0.06), (-0.22, 0.2, 0.05), (0.18, 0.28, 0.08)):
        a, b = e.at(u0, out), e.at(u1, out)
        s.tube("BlackTrim", (a[0], y + dy, a[1]), (b[0], y + dy, b[1]), r, 5)
    u = u0 + 1.5
    while u < u1 - 0.5:
        x, z = e.at(u, 0.2)
        s.box("BlackMetal", (x, y, z), (0.1, 0.6, 0.35), e.rot)
        u += 2.2
    x, z = e.at(u0 - 0.5, 0.18)
    s.box("DarkMetal", (x, y - 0.1, z), (0.8, 1.0, 0.36), e.rot)


def puddle(s, x, z, rx, rz, rot, seed):
    """A puddle: an irregular pool of dark water lying a hair over the ground."""
    import math
    import random

    rng = random.Random(seed)
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)
    count = 11
    wobble = [0.72 + 0.28 * rng.random() for _ in range(count)]
    pts = []
    for k in range(count):
        t = k / count * math.tau
        r = (wobble[k] + wobble[k - 1] + wobble[(k + 1) % count]) / 3
        px, pz = math.cos(t) * rx * r, math.sin(t) * rz * r
        pts.append((x + px * ca - pz * sa, z + px * sa + pz * ca))
    from maps import city

    for k in range(count):
        city.up_face(s, "Puddle", [(x, z), pts[k], pts[(k + 1) % count]], PUDDLE_Y)
    note("puddle", x, z, max(rx, rz), 0.0, 0.0)


PUDDLE_Y = 0.08
# Where the water stands after the rain: along the kerbs, in the scramble's low corners, at alley
# mouths, under the viaduct's drip line, in dips of the promenades and the plaza. (x, z, half
# length, half width, turn, seed.)
PUDDLES = [
    (-19.5, -24.6, 3.2, 1.3, 50, 1),  # the avenue's west kerb below the scramble
    (29.7, 9.8, 2.6, 1.1, 52, 2),  # the avenue's east kerb before the bridge
    (42.4, 74.5, 2.2, 1.0, 72, 3),  # past the bridge, the west kerb
    (49.5, -49.2, 3.0, 1.2, 7, 4),  # the east street's south kerb by the konbini
    (110.3, -51.7, 2.4, 1.0, 5, 5),  # its north kerb at Kita-dori
    (159.7, -39.6, 2.8, 1.1, 4, 6),  # its south kerb near the end
    (118.8, -77.5, 2.0, 0.9, 98, 7),  # Kita-dori's west kerb
    (101.6, -25.3, 1.8, 0.9, 85, 8),  # Minami-dori by the kei truck's work
    (-75.2, -56.5, 3.4, 1.4, 2, 9),  # the station drive's south kerb, the taxis' side
    (-99.8, -70.3, 2.2, 1.2, 0, 10),  # its north kerb by the bus stop
    (-52.0, -48.0, 2.6, 1.8, 30, 11),  # the scramble's south-west corner
    (-28.0, -74.0, 2.2, 1.6, 120, 12),  # its north-east corner
    (-160.0, 132.5, 3.6, 0.9, 0, 13),  # the viaduct's drip line along the lane
    (-45.0, 131.8, 2.8, 0.8, 0, 14),
    (130.0, 132.2, 3.2, 0.9, 0, 15),
    (-100.0, 128.5, 1.6, 1.1, 20, 16),  # where alley A meets the lane
    (111.0, 84.0, 1.5, 2.4, 0, 17),  # the laundromat's lane
    (-101.5, 97.0, 1.1, 1.8, 0, 18),  # alley A by the cross alley
    (-61.5, 66.0, 1.2, 1.6, 0, 19),  # alley B
    (-21.5, 70.0, 1.1, 2.0, 0, 20),  # alley C
    (-80.0, 90.5, 2.4, 1.0, 0, 21),  # the cross alley
    (-40.0, 110.5, 2.0, 1.0, 0, 22),  # the dead end
    (70.0, -13.2, 1.8, 1.0, 2, 23),  # the back alley behind the east street
    (-55.0, 52.0, 2.2, 1.2, 5, 24),  # a dip in the south promenade
    (110.0, 30.0, 2.0, 1.1, -3, 25),  # and in the north one
    (-70.0, -90.0, 2.8, 1.8, 40, 26),  # the station plaza, north of the drive
    (-95.0, -30.0, 2.0, 1.4, 70, 27),  # and south of it
]


def prop(s, key, e, u, out, turn=0.0, radius=1.0, height=3.0):
    x, z = e.at(u, out)
    s.prop(key, x, z, out_rot(e) + turn)
    note(key, x, z, radius, 0.0, height)


# Where they go ---------------------------------------------------------------------------------------


def build(s):
    SPOTS.clear()
    # Menu boards outside the places that would put one out: the noodle bar in the shopping
    # street (past its door), the cafe on the scramble, a bar on the lane under the viaduct, the
    # karaoke on the avenue, the laundromat on its lane, an izakaya facing the promenade.
    menu_board(s, wall("arcade_s2", 1), 11.5, 1.1, "ラーメン\n醤油  ¥850\n味噌  ¥900\n\nOPEN 18:00-2:00")
    menu_board(s, wall("zakkyo_sw", 5), 16.0, 1.2, "カフェ 珈\nCOFFEE  ¥400\nTOAST  ¥350")
    menu_board(s, wall("yb_s3", 2), 7.5, 1.0, "BAR 黒猫\nHAPPY HOUR\n19:00-21:00")
    menu_board(s, wall("karaoke", 3), 20.0, 1.0, "カラオケ 月光\n1H  ¥600\nFREE TIME  ¥1800")
    menu_board(s, wall("laundromat", 3), 4.0, 1.0, "コインランドリー\n24H\n洗濯  ¥400")
    menu_board(s, wall("yokocho_gate", 0), 16.0, 1.0, "居酒屋 まる\n生ビール  ¥500\n焼鳥  ¥180")
    # Rubbish out for the morning: on the viaduct lane by the business hotel and the flats, and
    # on the laundromat's river side.
    rubbish(s, wall("hotel_yw2", 2), 40.0, 1.0)
    rubbish(s, wall("yokocho_s1", 2), 5.0, 1.0)
    rubbish(s, wall("laundromat", 0), 4.0, 1.0)
    # Air conditioners up on the alley walls, clear of heads.
    air_conditioner(s, wall("yb_n1", 3), 4.0, 5.2)
    air_conditioner(s, wall("yd_s1", 3), 6.0, 4.8)
    air_conditioner(s, wall("yc_s1", 3), 10.0, 5.6)
    air_conditioner(s, wall("yokocho_gate", 3), 8.0, 6.0)
    air_conditioner(s, wall("east_n1", 3), 6.0, 5.0)
    # Plants by the business hotel's doors and by the flats and offices on the water.
    potted_plants(s, wall("hotel_se", 2), 22.5, 1.0)
    potted_plants(s, wall("hotel_se", 2), 37.5, 1.0)
    potted_plants(s, wall("flats_yw", 2), 14.0, 1.0)
    potted_plants(s, wall("office_riverside", 2), 6.0, 1.0)
    # Umbrella stands beside the shops' doors: the konbini, the drugstore, the noodle bar, the
    # game centre.
    umbrella_stand(s, wall("konbini_block", 0), 30.3, 0.6)
    umbrella_stand(s, wall("arcade_s1", 0), 21.6, 0.6)
    umbrella_stand(s, wall("arcade_s2", 1), 7.2, 0.6)
    umbrella_stand(s, wall("arcade_n2", 3), 10.0, 0.6)
    # Posters on the viaduct's piers (a club night, a missing cat, a gig), and on the
    # expressway's piers over the frontage road.
    z = P.VIADUCT_Z[0]
    pier_poster(s, -26.7, z, 0, 4.6, 1.6, 2.2, "PaintYellow", "LIVE\n影ヶ丘\nCLUB NOIR\n11.29")
    pier_poster(s, 33.3, z, 0, 4.2, 1.4, 1.9, "Paper", "迷い猫\nさがしています\n黒猫 オス")
    pier_poster(s, -134.7, z, 0, 4.8, 1.6, 2.3, "FabricRed", "JAZZ\nMOONLIGHT\nTRIO", (250, 240, 220))
    pier_poster(s, 141.3, z, 0, 4.4, 1.4, 2.0, "Paper")
    for x in (-42.0, 54.0, 102.0):
        pier_poster(s, x, -148.0, 180, 4.4, 1.5, 2.1, "Paper" if x != 54.0 else "PaintYellow",
                    "貸店舗\nFOR RENT" if x == -42.0 else None)
    # Flyers on the yokocho's alley walls.
    poster(s, wall("yb_n2", 0), 3.0, 4.2, 1.0, 1.4, "Paper")
    poster(s, wall("yc_s3", 2), 2.2, 4.6, 1.2, 1.6, "FabricRed")
    # Flyers taped round two of the east street's poles.
    for u in (88.0, 152.0):
        (x, z), d, into = kerb("east", -1, u, 0.9)
        pole_flyers(s, x, z)
    # Hanging signs out over the sidewalks.
    hanging_sign(s, wall("east_n2", 3), 2.0, 10.2, "喫茶\nKISSA", (60, 30, 20), (250, 220, 170))
    hanging_sign(s, wall("kita_w", 0), 10.0, 10.2, "質\n金", (30, 30, 34), (250, 214, 70))
    hanging_sign(s, wall("east_s2", 0), 20.0, 10.2, "麻雀", (20, 60, 40), (240, 240, 230))
    hanging_sign(s, wall("yc_n1", 0), 2.0, 10.4, "BAR\n霧", (24, 24, 28), (200, 220, 255))
    hanging_sign(s, wall("hotel_yw2", 2), 10.0, 10.2, "HOTEL\nゆき", (240, 236, 226), (30, 30, 36))
    # Cables clipped along walls on the viaduct lane and the promenade.
    cables(s, wall("yb_s1", 2), 1.0, 9.0, 7.4)
    cables(s, wall("yd_s4", 2), 1.0, 8.0, 7.2)
    cables(s, wall("river_se2", 3), 1.0, 10.0, 8.0)
    # Bikes, a scooter, crates, bins, a machine; two cones by the kei truck at its road work.
    prop(s, "Bicycle", wall("hotel_se", 2), 48.0, 1.1, 90)
    prop(s, "Bicycle", wall("yokocho_s1", 2), 14.0, 1.1, 90)
    prop(s, "Scooter", wall("karaoke", 3), 26.0, 1.0, 90)
    prop(s, "BeerCrates", wall("yb_s3", 2), 2.0, 1.0, 0, 1.6, 3.5)
    prop(s, "RecycleBins", wall("laundromat", 3), 19.5, 0.8, 0, 1.8, 3.2)
    prop(s, "VendingWhite", wall("hotel_yw1", 2), 6.0, 1.7, 0, 2.2, 7.2)
    for u in (42.0, 58.0):
        (x, z), d, into = kerb("minami", -1, u, -1.6)
        s.prop("TrafficCone", x, z, 20.0 + u)
        note("TrafficCone", x, z, 0.6, 0.0, 2.2)
    for x, z, rx, rz, rot, seed in PUDDLES:
        puddle(s, x, z, rx, rz, rot, seed)
