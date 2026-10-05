"""The tower round the Agency's two floors: slabs and ceilings, the curtain wall (floor-to-ceiling
glass between steel mullions, roller blinds, a sill along the glass), the core
(the lifts on 38F, the video wall over the atrium on 39F, closed service doors, the evidence
board), the fire stair in the core's east end, and the atrium: the hole in 39F's floor over the
lobby, the grand stair up its west side and glass balconies round it."""

import math
import random

from maps import city, kit
from maps import geo2d as g2
from maps.venues.agency import fit
from maps.venues.agency import plan as P

MULLION = 5.0  # studs between the curtain wall's mullions
GLASS_T = 0.5  # the curtain wall's collider sits this far inside the glass line


def edges():
    """The plate's outer edges, each going so its "n" side is the outside."""
    p = P.PLATE
    return [(p[i], p[(i + 1) % len(p)]) for i in range(len(p))]


def plate_minus(holes):
    return g2.subtract_all([g2.ccw(q) for q in g2.convex_pieces(P.PLATE)], [g2.ccw(h) for h in holes])


# Slabs --------------------------------------------------------------------------------------------------

SHAFT_HOLE = P.box(P.SHAFT[0], P.SHAFT[1], P.SHAFT[2], P.LANDING[0])  # 39F's floor is open over the flights
VOID = P.rect_of(P.VOID)


def slabs(s):
    # 38F's floor, 39F's floor (open over the atrium and the fire stair's flights) and the roof
    # over 39F (it also stops the rain: the rain looks up for a roof).
    for piece in g2.convex_pieces(P.PLATE):
        city.floor(s, piece, P.L1, 1.0, "CarpetNavy")
        city.floor(s, piece, P.ROOF, 1.0, None)
    for piece in plate_minus([VOID, SHAFT_HOLE]):
        city.floor(s, piece, P.L2, 1.0, "CarpetNavy")
    # The slab's edge round the atrium and the stair well, between 38F's ceiling and 39F's floor.
    for hole in (VOID, SHAFT_HOLE):
        ring = g2.ccw(hole)
        for k in range(len(ring)):
            a, b = ring[k], ring[(k + 1) % len(ring)]
            length = math.dist(a, b)
            away = ((b[1] - a[1]) / length, -(b[0] - a[0]) / length)  # out of the hole
            city.vquad(s, "ConcreteDark", a, b, P.CEIL1, P.L2, (-away[0], -away[1]))
            lip = (-away[0] * 0.05, -away[1] * 0.05)  # 0.05 proud of the concrete, so the two never flicker
            city.vquad(s, "BlackMetal", (a[0] + lip[0], a[1] + lip[1]), (b[0] + lip[0], b[1] + lip[1]), P.L2 - 0.02,
                       P.L2 + 0.02, (-away[0], -away[1]))
    # Ceilings: 38F's everywhere but over the atrium; 39F's everywhere (the atrium's too).
    core = P.rect_of(P.CORE)
    landing1 = P.box(P.SHAFT[0], P.LANDING[0], P.SHAFT[2], P.LANDING[1])
    for piece in plate_minus([VOID, core]):
        city.down_face(s, "CeilingDark", piece, P.CEIL1)
    city.down_face(s, "CeilingDark", landing1, P.CEIL1)
    for piece in plate_minus([core, VOID]):
        city.down_face(s, "CeilingDark", piece, P.CEIL2)
    city.down_face(s, "CeilingDark", VOID, P.CEIL2)
    city.down_face(s, "ConcreteDark", P.rect_of(P.SHAFT), P.CEIL2)
    # A coffer grid under the atrium's ceiling.
    x0, z0, x1, z1 = P.VOID
    for x in (x0 + 8.4, x0 + 16.8, x0 + 25.2, x0 + 33.6):
        s.box("DarkMetal", (x, P.CEIL2 - 0.3, (z0 + z1) / 2), (0.5, 0.6, z1 - z0), skip=("+y",))
    for z in (z0 + 7.5, z0 + 15.0, z0 + 22.5):
        s.box("DarkMetal", ((x0 + x1) / 2, P.CEIL2 - 0.31, z), (x1 - x0, 0.6, 0.5), skip=("+y",))


# The curtain wall ---------------------------------------------------------------------------------------


def curtain(s):
    rng = random.Random(38)
    for a, b in edges():
        length = math.dist(a, b)
        t = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        n = (t[1], -t[0])  # outward
        rot = g2.rot_of(t)
        bays = max(1, round(length / MULLION))
        step = length / bays

        def at(u, out=0.0):
            return (a[0] + t[0] * u + n[0] * out, a[1] + t[1] * u + n[1] * out)

        # The wall's collider: the glass line, full height (it blocks sight and the camera).
        c = at(length / 2, -GLASS_T)
        s.collider((c[0], (P.ROOF - 1.0) / 2, c[1]), (length + 1.0, P.ROOF + 1.0, 1.0), rot, True, "CurtainGlass")
        for level in P.LEVELS:
            top = level + (P.CEIL1 - P.L1)
            # The glass, inside and out, and a spandrel band at the slab.
            mid = at(length / 2)
            s.box("CurtainGlass", (mid[0], (level + 0.35 + top) / 2, mid[1]), (length, top - level - 0.35, 0.08), rot,
                  skip=("+x", "-x", "+y", "-y"))
            s.box("BlackMetal", (mid[0], top + 0.7, mid[1]), (length, 1.4, 0.5), rot, skip=("-y",))
            s.box("BlackMetal", (mid[0], level + 0.18, mid[1]), (length, 0.36, 0.4), rot)
            # The low sill inside, along the glass (a heater cover).
            sill = at(length / 2, -0.9)
            s.box("DarkMetal", (sill[0], level + 0.45, sill[1]), (length - 1.2, 0.9, 0.9), rot)
            for k in range(bays):
                u0 = k * step
                # Roller blinds: their box under the ceiling; some pulled part-way down.
                p = at(u0 + step / 2, -0.35)
                s.box("DarkMetal", (p[0], top - 0.35, p[1]), (step - 0.3, 0.4, 0.35), rot, skip=("+y",))
                if rng.random() < 0.22:
                    drop = rng.uniform(2.0, 7.0)
                    s.box("Fabric", (p[0], top - 0.55 - drop / 2, p[1]), (step - 0.4, drop, 0.04), rot)
        # Mullions inside and fins outside, the full height of both floors.
        for k in range(bays + 1):
            u = k * step
            p = at(u)
            s.box("BlackMetal", (p[0], P.ROOF / 2, p[1]), (0.22, P.ROOF, 0.3), rot)
            q = at(u, 0.5)
            s.box("DarkMetal", (q[0], P.ROOF / 2 + 0.5, q[1]), (0.25, P.ROOF + 1.0, 0.8), rot, skip=("-y",))


# The core ------------------------------------------------------------------------------------------------


def core_walls(s):
    x0, z0, x1, z1 = P.CORE
    sx0 = P.SHAFT[0]
    for level in P.LEVELS:
        y1 = level + P.L2 - P.L1
        up = level == P.L2
        # North face: closed service doors (toilets on 38F, stores on 39F).
        kit.wall(s, (x0, z0), (x1, z0), y1, base=level, core="ConcreteDark", side_n="PlasterGrey",
                 side_s="ConcreteDark", trim_n={"base": "BlackTrim"})
        # East face: the fire stair's door, into its landing.
        door = {"at": P.STAIR_DOOR_Z - z0, "w": 4.6, "bottom": level, "top": level + fit.DOOR_H, "kind": "door",
                "frame": "RedTrim", "casing": 0.3}
        kit.wall(s, (x1, z0), (x1, z1), y1, base=level, core="ConcreteDark", side_n="PlasterGrey",
                 side_s="ConcreteDark", openings=[door], trim_n={"base": "BlackTrim"})
        # South face: the lifts on 38F (stone), the video wall on 39F.
        kit.wall(s, (x1, z1), (x0, z1), y1, base=level, core="ConcreteDark",
                 side_n="BlackTrim" if up else "MarbleBlack", side_s="ConcreteDark", trim_n=None if up else {"base": "BlackTrim"})
        # West face.
        kit.wall(s, (x0, z1), (x0, z0), y1, base=level, core="ConcreteDark", side_n="WoodPanel" if up else "PlasterGrey",
                 side_s="ConcreteDark", trim_n={"base": "BlackTrim"})
        # The stair shaft's inner wall (its east side faces the flights).
        kit.wall(s, (sx0, z0), (sx0, z1), y1, base=level, core="ConcreteDark", side_n="PlasterGrey",
                 side_s="ConcreteDark")
    # Service doors on the north face, and their plates.
    for x, text in ((0.0, "WC 男"), (8.0, "WC 女"), (18.0, "清掃 JANITOR"), (25.0, "倉庫 STORE")):
        fit.closed_door(s, x, z0 - 0.5, 0, P.L1, 3.8, sign=text)
    for x, text in ((4.0, "倉庫 STORE"), (16.0, "電気室 ELECTRICAL"), (26.0, "機械室 PLANT")):
        fit.closed_door(s, x, z0 - 0.5, 0, P.L2, 3.8, "DarkMetal", sign=text)
    # The fire stair's doors: exit signs over them, 38F/39F plates beside them.
    for level, text in ((P.L1, "38F"), (P.L2, "39F")):
        fit.exit_sign(s, x1 + 0.5, level + 9.6, P.STAIR_DOOR_Z, -90)
        fit.plaque(s, x1 + 0.5, level + 6.0, P.STAIR_DOOR_Z - 4.6, -90, 2.4, 1.2, "非常階段 " + text, (250, 250, 250),
                   (150, 22, 32))


def lifts(s):
    """38F's lift lobby: three lifts, their call panels, the floor sign and the crest wall."""
    z = P.CORE[3] + 0.5
    for x in P.LIFTS_X:
        s.prop("ElevatorDoors", x, z + 0.43, 180)
        fit.downlight(s, x, z + 4.0, P.CEIL1, range_=14, brightness=0.7)
    # The crest wall west of the lifts (the grand stair's head faces it).
    s.box("WoodPanel", (-1.0, 6.5, z + 0.1), (13.0, 12.6, 0.2), 180)
    fit.plaque(s, -1.0, 9.6, z + 0.2, 180, 10.0, 1.4, P.TOWER + " 38F", (230, 214, 170), (20, 20, 24))
    fit.plaque(s, -1.0, 7.6, z + 0.2, 180, 10.0, 1.0, "THE AGENCY  ·  RECEPTION", (200, 200, 205), (20, 20, 24))
    s.box("Brass", (-1.0, 5.9, z + 0.3), (9.0, 0.12, 0.06), 180)
    s.light("spot", (-1.0, 12.4, z + 1.5), fit.WARM, 16, 1.0, False, "Bottom", 70)
    # The grand stair's head, faced in stone (38F sees its tall end from the lifts).
    x0, x1 = P.GRAND["x"]
    s.box("MarbleBlack", ((x0 + x1) / 2, P.L2 / 2, P.GRAND["z1"] - 0.05), (x1 - x0, P.L2, 0.1), 180)


def video_wall(s):
    """39F: a wall of screens over the atrium, on the core's south face."""
    x0, x1 = P.VIDEO_WALL
    z = P.CORE[3] + 0.5
    cols, rows = 4, 2
    w = (x1 - x0 - 1.2) / cols
    h = 4.6
    s.box("BlackMetal", ((x0 + x1) / 2, P.L2 + 11.3, z + 0.2), (x1 - x0 + 0.8, 11.0, 0.4), 180)
    loops = ["map", "cctv", "news", "cctv", "cctv", "map", "cctv", "news"]
    k = 0
    for row in range(rows):
        y = P.L2 + 8.4 + row * (h + 0.3) + h / 2
        for col in range(cols):
            x = x0 + 0.6 + w * (col + 0.5)
            s.box("Screen", (x, y, z + 0.45), (w - 0.3, h - 0.2, 0.1), 180)
            s.screen((x, y, z + 0.55), 180, w - 0.5, h - 0.4, loops[k])
            k += 1
    # Blue spill from the screens onto the deck, and a console ledge under them.
    for x in (x0 + 8, (x0 + x1) / 2, x1 - 8):
        s.light("point", (x, P.L2 + 10.0, z + 5.0), (120, 170, 255), 22, 0.7)
    s.box("DarkMetal", ((x0 + x1) / 2, P.L2 + 2.6, z + 0.9), (x1 - x0 - 4, 0.3, 1.6), 180)
    s.box("BlackMetal", ((x0 + x1) / 2, P.L2 + 1.3, z + 0.3), (x1 - x0 - 4, 2.6, 0.4), 180)
    s.collider(((x0 + x1) / 2, P.L2 + 1.4, z + 0.9), (x1 - x0 - 4, 2.8, 1.6), 180, True, "DarkMetal")


def board(s):
    """The evidence board on the core's west face at 39F, where the corridor opens out."""
    s.board(P.CORE[0] - 1.0, P.L2 + 6.5, -28.0, 90, 12.0, 7.0)
    for dz in (-6.0, 6.0):
        fit.downlight(s, P.CORE[0] - 4.0, -28.0 + dz * 0.5, P.CEIL2, range_=14, brightness=0.8, angle=80)


# The fire stair -----------------------------------------------------------------------------------------


def fire_stair(s, g):
    x0, z0, x1, z1 = P.SHAFT
    fa, fb = P.FLIGHT_A, P.FLIGHT_B
    ax = sum(fa["x"]) / 2
    bx = sum(fb["x"]) / 2
    fit.stairs(s, g, (ax, fa["z0"]), (ax, fa["z1"]), fa["y0"], fa["y1"], fa["x"][1] - fa["x"][0], "ConcreteDark",
               "ConcreteDark", rails=(False, False))
    fit.stairs(s, g, (bx, fb["z0"]), (bx, fb["z1"]), fb["y0"], fb["y1"], fb["x"][1] - fb["x"][0], "ConcreteDark",
               "ConcreteDark", rails=(False, False))
    # The half landing, solid underneath on 38F, and the block under flight B there.
    h0, h1 = P.HALF_LANDING
    city.floor(s, P.box(x0, h0, x1, h1), 7.0, 1.0, "ConcreteDark")
    city.up_face(s, "ConcreteDark", P.box(x0, h0, x1, h1), 7.0)
    s.collider(((x0 + x1) / 2, 3.0, (h0 + h1) / 2), (x1 - x0, 6.0, h1 - h0), 0, True, "ConcreteDark")
    s.box("ConcreteDark", ((x0 + x1) / 2, 3.0, h1 + 0.01), (x1 - x0, 6.0, 0.02), 0)
    b0, b1 = fb["x"]
    s.collider(((x0 + P.DIVIDER[0]) / 2, 3.5, (fb["z0"] + fb["z1"]) / 2), (P.DIVIDER[0] - x0, 7.0, fb["z1"] - fb["z0"]), 0,
               True, "ConcreteDark")
    s.box("ConcreteDark", ((x0 + P.DIVIDER[0]) / 2, 3.5, fb["z1"] + 0.01), (P.DIVIDER[0] - x0, 7.0, 0.02), 0)
    # The wall between the flights, up to a rail's height over the upper flight.
    d0, d1 = P.DIVIDER
    s.box("ConcreteDark", ((d0 + d1) / 2, (P.L2 + 3.6) / 2, (fb["z0"] + fb["z1"]) / 2), (d1 - d0, P.L2 + 3.6, 16.0),
          collide=True)
    s.tube("Steel", ((d0 + d1) / 2, P.L2 + 3.7, fb["z0"]), ((d0 + d1) / 2, P.L2 + 3.7, fb["z1"]), 0.08, 8)
    # 39F's landing edge over flight A.
    fit.railing(s, [(d1, P.LANDING[0] - 0.2), (x1 - 0.5, P.LANDING[0] - 0.2)], P.L2)
    # Landings: floors as the rest of the floor; fittings on the walls.
    for level in P.LEVELS:
        kit.tube_light(s, (x0 + x1) / 2, level + P.CEIL1, -10.0, length=6.0, rot=90, range_=16, brightness=0.8)
    fit.wall_lamp(s, (x0 + x1) / 2, 7.0 + 7.5, z0 + 0.5, 180)
    fit.wall_lamp(s, x1 - 0.5, P.L2 + 7.5, -22.0, 90)
    for level, y in ((P.L1, 7.0), (P.L2, 21.0)):
        fit.plaque(s, x0 + 0.6, y, -35.0, -90, 3.0, 1.2, "38F ↓  39F ↑" if level == P.L1 else "39F", (250, 250, 250),
                   (40, 40, 44))
    for level in P.LEVELS:
        city.up_face(s, "ConcreteDark", P.box(x0, P.LANDING[0], x1, P.LANDING[1]), level)
    s.zone("interior", P.box(x0, P.LANDING[0], x1, P.LANDING[1]), P.L1, name="the fire stair")
    s.zone("interior", P.box(x0, P.LANDING[0], x1, P.LANDING[1]), P.L2, name="the fire stair")
    s.zone("interior", P.box(x0, h0, x1, h1), 7.0, name="the fire stair")


# The atrium ------------------------------------------------------------------------------------------------


def atrium(s, g):
    x0, z0, x1, z1 = P.VOID
    gx0, gx1 = P.GRAND["x"]
    cx = (gx0 + gx1) / 2
    fit.stairs(s, g, (cx, P.GRAND["z0"]), (cx, P.GRAND["z1"]), P.L1, P.L2, gx1 - gx0, "MarbleBlack", "WoodPanel",
               glass="Glass")
    # 39F's balconies round the hole (the stair arrives at its north-west corner).
    fit.balcony(s, [(gx1, z0 + 0.2), (x1 - 0.2, z0 + 0.2), (x1 - 0.2, z1 - 0.2), (x0 + 0.2, z1 - 0.2)], P.L2)
    fit.balcony(s, [(x0 - 0.2, z1 - 0.2), (x0 - 0.2, z0 + 1.5)], P.L2)
    # Uplights set in the lobby floor round the atrium, washing the balconies' undersides.
    for x, z in ((7.0, 6.5), (36.0, 6.5), (36.0, 32.0), (22.0, 32.5)):
        s.box("Brass", (x, 0.08, z), (1.0, 0.16, 1.0))
        s.box("NeonWarm", (x, 0.17, z), (0.7, 0.03, 0.7))
        s.light("spot", (x, 0.3, z), fit.WARM, 22, 0.9, False, "Top", 70)
    # A tall pendant cluster hanging into the atrium from 39F's ceiling.
    for dx, dz, drop in ((0, 0, 7.0), (-5, 3, 9.0), (6, -4, 8.0), (3, 6, 10.0)):
        kit.pendant(s, (x0 + x1) / 2 + 4 + dx, P.CEIL2, (z0 + z1) / 2 + dz, drop=drop, shade="Brass",
                    color=fit.WARM, range_=30, brightness=1.4, wide=1.2)


def build(s, g):
    slabs(s)
    curtain(s)
    core_walls(s)
    lifts(s)
    video_wall(s)
    board(s)
    fire_stair(s, g)
    atrium(s, g)
