"""The Grey Realm's landmarks (remade 2026-11-04 to the user's reference videos): the spawn ledge, the bowl with its
dish of skulls and ring of candle stones, the tableaux round its rim, the throne high on its rock with the plaque at
its foot and Most Wins beside it, the grotto with the Academy inside, the chess game, the stone notebook over the
rift, the carcass with the duel's stones under its ribs, the two tusks, the junk heaps and the great arch. Each
records the anchors the lobby's Luau builds its own things at (the
board, signs, candles, stone figures, drill desks, puppets, the spawn, the games).

The light is the glow's, low in the north (LightingPresets.lobby): a pale pool hangs only where something is done or
read, and the grotto has its own cage lanterns."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.city import Frame
from maps.mesher import cross, dot, sub
from maps.venues.lobby import plan as P
from maps.venues.lobby import rocks, terrain

PALE = (170, 196, 232)  # the realm's cold light
LANTERN = (196, 214, 255)  # the cage lanterns' flame


def pool(s, x, y, z, range_=26, brightness=1.0, colour=PALE):
    """A pool of the realm's pale light."""
    s.light("point", (x, y, z), colour, range_, brightness)


def away(s, mat, pts, inside):
    """A face whose front looks away from the point `inside`."""
    n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    cz = sum(p[2] for p in pts) / len(pts)
    if dot(n, (cx - inside[0], cy - inside[1], cz - inside[2])) < 0:
        pts = list(reversed(pts))
    s.polygon(mat, pts)


def flag_disc(s, g, c, r, seed, mat="RuinFlag", zone="plaza", name=None, y=0.04, broken=0.12, loose=18, within=None):
    """A disc of old flagstones with a ragged edge, a few loose stones strewn past it (only those wholly inside
    `within`, when given: the top of a plateau, whose rim they would hang over)."""
    rng = random.Random(seed)
    pts = []
    n = 28
    for k in range(n):
        a = 2 * math.pi * k / n
        pts.append((c[0] + math.cos(a) * r * (1 - rng.uniform(0, broken)), c[1] + math.sin(a) * r * (1 - rng.uniform(0, broken))))
    hull = g2.convex_hull(pts)
    city.up_face(s, mat, hull, y)
    s.zone(zone, hull, max(0.0, y - 0.04), name=name)
    for k in range(loose):
        a = rng.uniform(0, math.tau)
        d = r * rng.uniform(1.0, 1.25)
        cx, cz = c[0] + math.cos(a) * d, c[1] + math.sin(a) * d
        w = rng.uniform(1.4, 3.2)
        stone = g2.rect(cx, cz, w, w * rng.uniform(0.6, 1.0), rng.uniform(0, 90))
        if within is not None and not all(g2.contains(within, p) for p in stone):
            continue
        city.up_face(s, mat, stone, y)
    return hull


def ring_quads(c, r0, r1, n, a0=0.0, a1=360.0):
    """The quads (x, z) of a ring from r0 to r1 round c, n to the full turn, between the angles a0 and a1 (degrees)."""
    out = []
    steps = max(1, round(n * (a1 - a0) / 360.0))
    for k in range(steps):
        t0 = math.radians(a0 + (a1 - a0) * k / steps)
        t1 = math.radians(a0 + (a1 - a0) * (k + 1) / steps)
        out.append([(c[0] + math.cos(t0) * r0, c[1] + math.sin(t0) * r0), (c[0] + math.cos(t1) * r0, c[1] + math.sin(t1) * r0),
                    (c[0] + math.cos(t1) * r1, c[1] + math.sin(t1) * r1), (c[0] + math.cos(t0) * r1, c[1] + math.sin(t0) * r1)])
    return out


def disc_colliders(s, c, r, y0, y1, mat="RuinStone", planks=6):
    """A round solid from y0 up to y1: diameters of solid laid across it at even turns, wide enough that together
    they fill the disc (their corners stand out past its edge by a few tenths)."""
    w = 2 * r * math.tan(math.pi / (2 * planks)) * 1.05
    for k in range(planks):
        s.collider((c[0], (y0 + y1) / 2, c[1]), (2 * r, y1 - y0, w), 180.0 * k / planks, True, mat)


# The spawn ledge ---------------------------------------------------------------------------------------------


def ledge(s, g):
    """The broad shelf of rock players appear on: old flagstones on its top, one wide flight down its north face to the
    plain, billowing rock heaped along its flanks and cliffs rising behind it; a worn ring of dark stone where players
    appear, facing north over the bowl to the throne against the glow."""
    cx, cz, w, d, h = P.LEDGE
    poly = g2.rect(cx, cz, w, d)
    city.terrace(s, g, poly, h, 0.0, top_mat="RuinFlag", wall_mat="RockGrey", zone="plaza", name="the ledge",
                 coping="RuinStone", coping_under=True)
    (ax, az), (bx, bz), sw = P.LEDGE_STEPS
    city.stairs(s, g, (ax, az), (bx, bz), h, 0.0, sw, mat="RuinStone", side_mat="RockGrey", step=0.8, name="the steps")
    sx, sz = P.SPAWN
    for k in range(28):
        a0, a1 = 2 * math.pi * k / 28, 2 * math.pi * (k + 1) / 28
        if k % 6 == 4:
            continue
        pts = [(sx + math.cos(a) * r, sz + math.sin(a) * r) for a, r in ((a0, 7.6), (a1, 7.6), (a1, 8.4), (a0, 8.4))]
        s.polygon("RuinStone", [(x, h + 0.06, z) for x, z in reversed(g2.ccw(pts))])
    s.anchor("spawn", sx, h, sz, 0.0)
    # The billowing rock along its flanks (hiding the shelf's straight sides) and either side of the flight.
    front = cz - d / 2
    for x, z, rot, sc in ((cx - w / 2 - 5.0, cz + 2.0, 90.0, 0.95), (cx + w / 2 + 5.0, cz - 1.0, 270.0, 1.0),
                          (cx - 21.0, front - 4.0, 8.0, 0.62), (cx + 22.0, front - 3.5, 172.0, 0.6)):
        rocks.rock(s, "RealmBillowShelf", x, z, rot, sc)
    # Cliffs rising behind it, to the basin's rim.
    rng = random.Random(1100)
    for k, (x, z, key, sc) in enumerate(((-24.0, cz + d / 2 + 13.0, "RealmBillowB", 0.95),
                                         (16.0, cz + d / 2 + 15.0, "RealmBillowA", 1.15),
                                         (44.0, cz + d / 2 + 8.0, "RealmBillowC", 1.2),
                                         (-50.0, cz + d / 2 + 4.0, "RealmBillowA", 0.9),
                                         (-4.0, cz + d / 2 + 34.0, "RealmBillowB", 1.25))):
        rocks.rock(s, key, x, z, rng.uniform(0, 360), sc)
    pool(s, sx, h + 9.0, sz, 30, 0.9)


# The bowl -----------------------------------------------------------------------------------------------------


def bowl(s, g):
    """The great shallow bowl of stone sunk in the plain: a flagged floor BOWL_DEPTH down, terraces stepping up from
    it to the rim (each riser of old dressed stone, low enough to walk up), a coping of dark stone round the rim. At the
    floor's middle the dish heaped with skulls; round it the twelve candle stones (the game stands a candle on each
    and lights one for every player who is ready: anchors ready<n>, at the stone's top)."""
    c = P.BOWL_C
    fy = P.bowl_floor_y()
    floor = P.circle(c, P.BOWL_FLOOR_R, 48)
    city.up_face(s, "RuinFlag", floor, fy)
    s.zone("plaza", floor, fy, name="the bowl")
    s.collider((c[0], fy - 0.6, c[1]), (P.BOWL_R * 2.0, 1.2, P.BOWL_R * 2.0), 0.0, True, "RuinFlag")
    # A worn ring of dark stone round the dish, and another at the floor's edge.
    for r0, r1, gap in ((4.6, 5.6, 5), (P.BOWL_FLOOR_R - 1.6, P.BOWL_FLOOR_R - 0.6, 7)):
        for k, q in enumerate(ring_quads(c, r0, r1, 40)):
            if k % gap == gap - 2:
                continue  # worn away
            s.polygon("RuinStone", [(x, fy + 0.05, z) for x, z in reversed(g2.ccw(q))])
    # The terraces: each ring's top flagged, its riser facing in, solid under it.
    below = fy
    for k in range(P.BOWL_STEPS):
        r0, r1, top = P.bowl_step(k)
        for q in ring_quads(c, r0, r1, 56):
            s.polygon("RuinFlag", [(x, top, z) for x, z in reversed(g2.ccw(q))])
        for q in ring_quads(c, r0, r0, 56):
            (x0, z0), (x1, z1) = q[0], q[1]
            away(s, "RuinStone", [(x0, below, z0), (x1, below, z1), (x1, top, z1), (x0, top, z0)],
                 (c[0] + (x0 - c[0]) * 3.0, (below + top) / 2, c[1] + (z0 - c[1]) * 3.0))
        for j in range(16):
            a = math.radians(j * 22.5 + 11.25)
            mid = (r0 + r1) / 2
            s.collider((c[0] + math.cos(a) * mid, (top + fy - 1.2) / 2, c[1] + math.sin(a) * mid),
                       (r1 - r0 + 0.3, top - fy + 1.2, 2 * math.pi * r1 / 16 + 1.0), -j * 22.5 - 11.25, True, "RuinFlag")
        below = top
    s.zone("plaza", P.circle(c, P.BOWL_R, 48), 0.0, name="the bowl's rim")
    for q in ring_quads(c, P.BOWL_R - 0.9, P.BOWL_R + 0.3, 64):
        s.polygon("RuinStone", [(x, 0.12, z) for x, z in reversed(g2.ccw(q))])
    # The dish of skulls, and the candle stones round it.
    s.prop("SkullDish", c[0], c[1], 20.0, 1.0, fy)
    disc_colliders(s, c, P.DISH_R, fy, fy + 1.3, "RuinStone", planks=4)
    rng = random.Random(33)
    for k, (x, z) in enumerate(P.ready_stones()):
        s.prop("CandleStone", x, z, rng.uniform(0, 360), 1.0, fy)
        s.collider((x, fy + P.READY_H / 2, z), (1.5, P.READY_H, 1.5), 22.5, True, "RuinStone")
        s.anchor(f"ready{k + 1}", x, fy + P.READY_H, z, P.rot_towards((x, z), c))
    pool(s, c[0], 8.0, c[1], 34, 1.0)


# Round the bowl: the tableaux ---------------------------------------------------------------------------------


def base(s, x, z, r, h, seed, y=0.0):
    """A low round base of old stone, flagged on top, solid (people step up onto it): the Lobby set's TableauBase
    (props_academy.py, made 6 across its top and 0.7 high), scaled to r."""
    sc = (r + 0.6) / 6.6
    s.prop("TableauBase", x, z, (seed * 37) % 360, round(sc, 3), y)
    side = r * 1.6
    for rot in (0.0, 45.0):
        s.collider((x, y + h / 2, z), (side, h, side), rot, True, "RuinStone")


def tableaux(s):
    """The five tableaux round the bowl's rim: a low round base each, a pale light over it. The game stands its stone
    figures on them (anchors tableau<n> at the base's top, facing the bowl's middle)."""
    for k, (x, z) in enumerate(P.TABLEAUX):
        base(s, x, z, P.TABLEAU_R, P.TABLEAU_H, 520 + k)
        s.anchor(f"tableau{k + 1}", x, P.TABLEAU_H, z, P.rot_towards((x, z), P.BOWL_C), r=P.TABLEAU_R)
        pool(s, x, P.TABLEAU_H + 9.0, z, 22, 0.8)


# The throne -------------------------------------------------------------------------------------------------------


# The throne prop's own measures (props_lobby.bone_throne): its seat's top over its foot, the seat's middle in
# front of the prop's middle, its backrest's face behind it, the seat's width, the back's top.
SEAT_TOP, SEAT_Y, BACK_Y, SEAT_W, BACK_TOP = 3.42, -0.3, 1.45, 6.2, 9.96
THRONE_ROCK_KEY = "RealmThroneRock"


def throne(s):
    """The bone throne, high on a table of rock in the north on the spawn's line, against the glow, facing the spawn
    (nobody climbs it: the game seats the player with the most wins on it, in stone); the plaque stone at the rock's
    foot (the game writes the champion's name and wins on it); one cold light over it."""
    x, z, r, h = P.THRONE_ROCK
    sc = 1.0
    rocks.rock(s, THRONE_ROCK_KEY, x, z, 25.0, sc)
    top = terrain.top_of(THRONE_ROCK_KEY, sc)
    rot = P.THRONE_ROT
    tx, tz = P.THRONE
    f = Frame(tx, tz, rot)
    s.prop("BoneThrone", tx, tz, rot, 1.0, top)
    ax, ay, az = f.w3(0.0, top + SEAT_TOP, SEAT_Y)
    s.anchor("throne", ax, ay, az, rot, w=SEAT_W, h=BACK_TOP - SEAT_TOP)
    s.collider((tx, top + 0.3, tz), (7.8, 0.6, 6.8), rot, True, "RuinStone")
    front, back = SEAT_Y + 0.05 - 1.8, BACK_Y + 1.0
    sx, sz = f.w(0.0, (front + back) / 2)
    s.collider((sx, top + 0.6 + (BACK_TOP - 0.6) / 2, sz), (SEAT_W, BACK_TOP - 0.6, back - front), rot, True, "RuinStone")
    # The plaque stone at the rock's foot: a squat block, a dark slate let into its face.
    pw, ph, pd, pt = 5.6, 2.6, 1.2, 1.9
    px, pz = P.PLAQUE
    pf = Frame(px, pz, rot)
    s.box("RuinStone", (px, 0.3, pz), (pw + 0.8, 0.6, pd + 0.8), rot, collide=True, skip=("-y",))
    s.box("RuinStone", (px, 0.6 + (ph - 0.6) / 2, pz), (pw, ph - 0.6, pd), rot, collide=True, skip=("-y",))
    s.box("RuinStone", (px, ph + 0.12, pz), (pw + 0.3, 0.24, pd + 0.3), rot)
    bx, by, bz = pf.w3(0.0, pt, -pd / 2 - 0.03)
    s.box("BlackTrim", (bx, by, bz), (pw - 0.8, 1.5, 0.06), rot)
    qx, qy, qz = pf.w3(0.0, pt, -pd / 2 - 0.08)
    s.anchor("throneplaque", qx, qy, qz, rot, w=pw - 1.0, h=1.3)
    lx, ly, lz = f.w3(0.0, top + SEAT_TOP + 12.0, -3.0)
    pool(s, lx, ly, lz, 30, 1.1)
    pool(s, px, 7.0, pz - 4.0, 18, 0.7)


def steles(s):
    """The stone a board is written on (one is left: Most Wins, beside the throne's rock): the Lobby set's WinsStele
    (props_academy.py), its slate where the game draws the board; solid, a pale light to read it by."""
    for name, (x, z, rot, bw, bh, board_y) in P.STELES.items():
        f = Frame(x, z, rot)
        t = P.STELE_T
        s.prop("WinsStele", x, z, rot, 1.0)
        s.collider((x, 0.6, z), (16.4, 1.2, 4.4), rot, True, "RuinStone")
        s.collider((x, 8.2, z), (14.0, 14.4, t), rot, True, None)
        bx, by, bz = f.w3(0.0, board_y, -t / 2 - 0.17)
        s.anchor(name, bx, by, bz, rot, w=bw, h=bh)
        lx, ly, lz = f.w3(0.0, board_y + 3.0, -t / 2 - 6.0)
        pool(s, lx, ly, lz, 22, 0.9)


# The grotto and the Academy in it ------------------------------------------------------------------------------------


def _roof_y(r):
    """The grotto roof's height over its floor at r from its middle (an elliptic vault from GROTTO_ROOF over the middle
    down to 14 at the walls)."""
    u = min(1.0, r / (P.GROTTO_WALL + 2.0))
    return 14.0 + (P.GROTTO_ROOF - 14.0) * math.sqrt(max(0.0, 1.0 - u * u))


def _vault(s, c, seed):
    """The grotto's roof: a lumpy vault seen from inside (its faces look down), and its back seen from above (the
    Spire Ascent looks down on it), both shaded smooth; it rests on the billowing walls."""
    rng = random.Random(seed)
    rim = P.GROTTO_WALL + 2.0
    n, rings = 40, 9
    bumps = [(rng.uniform(0, math.tau), rng.uniform(0.2, 0.95), rng.uniform(0.5, 1.4)) for _ in range(14)]

    def lump(a, u):
        return sum(amp * math.exp(-((math.atan2(math.sin(a - ba), math.cos(a - ba)) * 2.2) ** 2 + ((u - bu) * 6.0) ** 2))
                   for ba, bu, amp in bumps)

    rims = []
    for skin, lift, inside in (("in", 0.0, (c[0], 200.0, c[1])), ("out", 2.5, (c[0], -200.0, c[1]))):
        pts = []
        for j in range(rings + 1):
            u = 1.0 - j / rings
            r = rim * u
            row = []
            for k in range(n):
                a = math.tau * k / n
                y = _roof_y(r) + lift - (lump(a, u) if skin == "in" else -0.6 * lump(a, u))
                row.append((c[0] + math.cos(a) * r, y, c[1] + math.sin(a) * r))
            pts.append(row)
        with s.smooth():
            for j in range(rings):
                for k in range(n):
                    k1 = (k + 1) % n
                    quad = [pts[j][k], pts[j][k1], pts[j + 1][k1], pts[j + 1][k]]
                    if j == rings - 1:
                        quad = quad[:3]
                    away(s, "RockGrey", quad, inside)
        rims.append(pts[0])
    # (its rim closed between the two skins, facing out)
    inner, outer = rims
    for k in range(n):
        k1 = (k + 1) % n
        away(s, "RockGrey", [inner[k], inner[k1], outer[k1], outer[k]], (c[0], 20.0, c[1]))


def grotto(s, g):
    """A cave in the south-west cliffs, its mouth toward the bowl: billowing rock all round its walls, a vault over it
    with drips of rock hanging from it, twisted pillars of rock standing up to the vault between the altars, pale
    crystals at the walls' feet, cage lanterns hanging on chains. The Academy is inside: the seven practice altars round
    the floor's back (the game stands its drill desks in them), the three puppets across its middle, the gate's name
    over the mouth (anchor academyGate)."""
    c = P.ACADEMY_C
    gate = P.GATE_DIR
    flag_disc(s, g, c, P.ACADEMY_R + 1.0, 97, name="the Academy", broken=0.06, loose=10)
    rng = random.Random(101)
    # The walls: billowing rock round the circle, turned to face in, a mouth left open toward the bowl.
    keys = ("RealmBillowA", "RealmBillowB", "RealmBillowC")
    count = 9
    for k in range(count):
        a = gate + 360.0 * (k + 0.5) / count
        off = math.atan2(math.sin(math.radians(a - gate)), math.cos(math.radians(a - gate)))
        if abs(math.degrees(off)) < 22.0:
            continue
        r = P.GROTTO_WALL + 9.0 + rng.uniform(-2.0, 3.0)
        x, z = P.polar(c, a, r)
        rocks.rock(s, keys[k % 3], x, z, P.rot_towards((x, z), c) + rng.uniform(-20, 20), rng.uniform(0.95, 1.2))
    # The mouth's two cheeks, either side of the way in and clear of it: a billow's foot reaches far (at 17 degrees
    # out from the gate the two met in the middle, and their foot walls shut the Academy), so each is stood as close
    # as its own outline allows, the way in kept the mouth's width from inside the vault to well out on the ash.
    mx, mz = P.GATE
    ux, uz = mx - c[0], mz - c[1]
    length = math.hypot(ux, uz)
    ux, uz = ux / length, uz / length
    way = ((mx - ux * 10.0, mz - uz * 10.0), (mx + ux * 16.0, mz + uz * 16.0))
    for side in (-1, 1):
        lateral = P.GROTTO_MOUTH_W / 2 + 2.0
        while True:
            x, z = mx + ux * 5.0 - uz * side * lateral, mz + uz * 5.0 + ux * side * lateral
            rot = P.rot_towards((x, z), c) + side * 30.0
            foot = rocks.outline("RealmBillowC", x, z, rot, 0.9)
            gap = min(g2.dist_point_segment(p, *way) for p in foot)
            if gap >= P.GROTTO_MOUTH_W / 2 + 0.5 and not any(g2.contains(foot, q) for q in way):
                break
            lateral += 1.0
        rocks.rock(s, "RealmBillowC", x, z, rot, 0.9)
    # Solid walls round the floor's edge (between the billows nobody gets out), none of them across the mouth.
    wall_r = P.GROTTO_WALL + 1.0
    for k in range(28):
        a0, a1 = 360.0 * k / 28, 360.0 * (k + 1) / 28
        mid = (a0 + a1) / 2
        off = abs(math.degrees(math.atan2(math.sin(math.radians(mid - gate)), math.cos(math.radians(mid - gate)))))
        if off < 90.0 and math.sin(math.radians(off - 180.0 / 28)) * wall_r < P.GROTTO_MOUTH_W / 2:
            continue
        x, z = P.polar(c, mid, wall_r)
        s.collider((x, 6.0, z), (2.4, 12.0, 2 * math.pi * wall_r / 28 + 1.0), -mid, True, "RockGrey")
    # The vault over it all, the lintel over the mouth.
    _vault(s, c, 103)
    mx, mz = P.GATE
    lrot = P.rot_towards(c, (mx, mz))
    rocks.rock(s, "RealmBillowShelf", mx, mz, lrot + 90.0, 0.55, y=P.GROTTO_MOUTH_H)
    f = Frame(mx, mz, lrot)
    sx, sy, sz = f.w3(0.0, P.GROTTO_MOUTH_H - 0.9, -2.6)
    s.anchor("academyGate", sx, sy, sz, lrot, w=14.0, h=1.5)
    s.zone("plaza", g2.rect(mx, mz, P.GROTTO_MOUTH_W, 12.0, lrot), 0.0, name="the grotto's mouth")
    # A pool of the realm's light under the lintel: the way in was black between the lit bowl and the lit Academy.
    pool(s, mx + ux * 2.0, P.GROTTO_MOUTH_H - 3.0, mz + uz * 2.0, range_=22, brightness=0.9)
    # Twisted pillars of rock up to the vault, between the altars and the walls.
    for k, a in enumerate((gate + 130.0, gate + 180.0, gate + 230.0, gate + 80.0, gate + 280.0)):
        x, z = P.polar(c, a, P.ACADEMY_R - 3.5)
        key = "RealmColumn" if k % 2 else "RealmColumnB"
        rocks.rock(s, key, x, z, rng.uniform(0, 360), _roof_y(P.ACADEMY_R - 3.5) / 70.0 + 0.02)
    # Drips of rock from the vault, crystals at the walls' feet.
    cages = [P.polar(c, a, d) for a, d in CAGES]
    for k in range(16):
        a = rng.uniform(0, 360)
        d = rng.uniform(6.0, P.GROTTO_WALL - 4.0)
        x, z = P.polar(c, a, d)
        if any(math.dist((x, z), q) < 4.0 for q in cages):
            continue
        key = "RealmDripB" if k % 3 == 0 else "RealmDripA"
        sc = rng.uniform(0.7, 1.1)
        h = {"RealmDripA": 9.0, "RealmDripB": 15.0}[key] * sc
        s.prop(key, x, z, rng.uniform(0, 360), round(sc, 3), _roof_y(d) - h + 0.4)
    for k in range(14):
        a = gate + rng.uniform(30, 330)
        x, z = P.polar(c, a, P.GROTTO_WALL - rng.uniform(1.0, 4.0))
        s.prop("RealmShardsC", x, z, rng.uniform(0, 360), round(rng.uniform(0.8, 1.6), 3), -0.3)
    # Cage lanterns hanging on chains from the vault, burning cold.
    for k, (a, d) in enumerate(CAGES):
        x, z = P.polar(c, a, d)
        hang = _roof_y(d)
        s.prop("HangingCage", x, z, rng.uniform(0, 360), 1.0, hang - HANGING_CAGE_DROP)
        pool(s, x, hang - HANGING_CAGE_DROP + 1.2, z, 26, 1.0, LANTERN)
    # The practice altars (the game's drill desks stand in them) and the puppets.
    for k, (x, z, rot) in enumerate(P.altars()):
        s.anchor(f"drill{k + 1}", x, 0.0, z, rot)
        s.preview_prop("PracticeAltar", x, z, rot)
        bx, bz = P.facing(rot)
        s.preview_prop("PracticeTablet", x - bx * 2.6, z - bz * 2.6, rot)
    for k, (x, z, rot) in enumerate(P.effigies()):
        s.anchor(f"dummy{k + 1}", x, 0.0, z, rot)
        s.preview_prop("Puppet", x, z, rot)


HANGING_CAGE_DROP = 9.0  # how far under its hook the HangingCage's lantern hangs (props_realmjunk.hanging_cage)
# The grotto's cage lanterns: (direction from the cave's middle, degrees from the gate's; how far out).
CAGES = [(P.GATE_DIR + 150.0, 14.0), (P.GATE_DIR + 210.0, 14.0), (P.GATE_DIR + 100.0, 18.0), (P.GATE_DIR + 260.0, 18.0),
         (P.GATE_DIR, 4.0)]


# The chessboard, the notebook, the rift -----------------------------------------------------------------------------


BOARD_TOP = 0.2  # the chessboard's squares under the pieces stand level at this height


def chessboard(s):
    """A chessboard sunk in the ash: squares of bone-pale and black stone, many sunk or lifted, cracked or gone; its
    pieces left mid-game (the ChessGame prop, on the squares the plan names), the white king toppled on its own
    square."""
    x, z, rot, sq = P.CHESS
    f = Frame(x, z, rot)
    rng = random.Random(281)
    taken = set(P.CHESS_GAME) | {P.CHESS_FALLEN}
    for file in "abcdefgh":
        for rank in range(1, 9):
            name = f"{file}{rank}"
            lx, lz = P.chess_square(name)
            cx, cz = f.w(lx, lz)
            light = ("abcdefgh".index(file) + rank) % 2 == 1
            mat = "BoneOld" if light else "BlackTrim"
            edge = file in "ah" or rank in (1, 8)
            if name not in taken and rng.random() < (0.16 if edge else 0.07):
                continue
            if name in taken:
                top, turn, size = BOARD_TOP, 0.0, sq - 0.12
            else:
                top = BOARD_TOP + rng.choice((0.0, 0.0, -0.06, -0.3, 0.1, 0.16))
                turn = rng.uniform(-4.0, 4.0)
                size = sq - rng.uniform(0.12, 0.4)
            if name not in taken and rng.random() < 0.18:
                for half, dz2, dy in ((-1, -0.05, 0.0), (1, 0.08, rng.uniform(-0.05, 0.08))):
                    hx, hz = f.w(lx + half * size / 4, lz + dz2)
                    s.box(mat, (hx, top + dy - 0.2, hz), (size / 2 - 0.1, 0.4, size), rot + turn, skip=("-y",))
                continue
            s.box(mat, (cx, top - 0.2, cz), (size, 0.4, size), rot + turn, skip=("-y",))
    s.collider((x, BOARD_TOP / 2 - 0.1, z), (sq * 8, BOARD_TOP + 0.2, sq * 8), rot, True, "BoneOld")
    for name, (kind, colour) in P.CHESS_GAME.items():
        cx, cz = f.w(*P.chess_square(name))
        radius = {"K": 1.15, "Q": 1.15, "B": 1.0, "N": 1.05, "R": 1.05, "P": 0.92}[kind]
        height = {"K": 5.2, "Q": 4.6, "B": 4.1, "N": 3.8, "R": 3.4, "P": 2.7}[kind]
        s.collider((cx, BOARD_TOP + height / 2, cz), (radius * 1.7, height, radius * 1.7), rot + 45.0, True, None)
    s.prop("ChessGame", x, z, rot, 1.0, BOARD_TOP)
    kx, kz = f.w(*P.chess_square(P.CHESS_FALLEN))
    s.collider((kx, BOARD_TOP + 1.1, kz), (5.6, 2.2, 2.4), rot, True, None)


def notebook(s):
    """The stone notebook over the rift, stopped in its fall (it neither collides nor casts a shadow on anyone's dive:
    a diver goes in under it)."""
    x, y, z, rot = P.NOTEBOOK
    s.prop("StoneNotebook", x, z, rot, 1.0, y)


def rift_mark(s):
    """The rift's shape for the game's dive (anchor rift: its middle, its turn and radii)."""
    cx, cz = P.RIFT_MID
    s.anchor("rift", cx, 0.0, cz, P.RIFT_TURN, rx=P.RIFT_AXES[0], rz=P.RIFT_AXES[1])
    pool(s, cx, 10.0, cz, 30, 0.6)


# The carcass and the duel; the tusks --------------------------------------------------------------------------------


def carcass(s):
    """A dead death god's remains: its skull sunk in the ash on its open jaw, gazing at the throne, the spine running
    away from it, the ribs arching over the ground either side (people walk between them)."""
    sx, sz, srot = P.CARCASS_SKULL
    s.prop("GiantSkull", sx, sz, srot, 1.0, -0.3)
    f = Frame(sx, sz, srot)
    for lx, lz, w, d, hh in ((0.0, 5.0, 9.5, 13.0, 13.0), (0.0, -7.0, 8.0, 11.0, 7.5)):
        cx, cz = f.w(lx, lz)
        s.collider((cx, hh / 2, cz), (w, hh, d), srot, True, "BoneOld")
    spine = P.SPINE
    points = []
    for k in range(len(spine) - 1):
        a, b = spine[k], spine[k + 1]
        for q in range(4):
            u = q / 4
            points.append((a[0] + (b[0] - a[0]) * u, P.SPINE_Y - 1.5 * (k + u), a[1] + (b[1] - a[1]) * u, q == 0))
    last = spine[-1]
    points.append((last[0], P.SPINE_Y - 1.5 * (len(spine) - 1), last[1], True))
    for k, (px, py, pz, ribbed) in enumerate(points):
        nxt = points[min(k + 1, len(points) - 1)]
        prv = points[max(k - 1, 0)]
        dx, dy, dz = nxt[0] - prv[0], nxt[1] - prv[1], nxt[2] - prv[2]
        n = math.sqrt(dx * dx + dy * dy + dz * dz) or 1.0
        ax, ay, az = dx / n, dy / n, dz / n
        with s.smooth():
            s.tube("BoneOld", (px - ax * 1.5, py - ay * 1.5, pz - az * 1.5),
                   (px + ax * 1.5, py + ay * 1.5, pz + az * 1.5), 2.0, 10, radius_b=1.9)
        if k + 1 < len(points):
            with s.smooth():
                s.tube("BoneWhite", (px + ax * 1.4, py + ay * 1.4, pz + az * 1.4),
                       (nxt[0] - ax * 1.4, nxt[1] - ay * 1.4, nxt[2] - az * 1.4), 1.55, 10)
        with s.smooth():
            s.tube("BoneOld", (px, py + 1.4, pz), (px - ax * 1.0, py + 4.2, pz - az * 1.0), 0.75, 7, radius_b=0.25)
        side = (-az, ax)
        sn = math.hypot(*side) or 1.0
        side = (side[0] / sn, side[1] / sn)
        for sgn in (-1, 1):
            with s.smooth():
                s.tube("BoneOld", (px, py - 0.2, pz), (px + side[0] * sgn * 2.8, py - 0.5, pz + side[1] * sgn * 2.8),
                       0.85, 7, radius_b=0.65)
        if not ribbed:
            continue
        for sgn in (-1, 1):
            rib = [(px + side[0] * sgn * 2.6, py - 0.5, pz + side[1] * sgn * 2.6)]
            radii = [0.6]
            for q in range(1, 9):
                u = q / 8
                ang = u * math.pi / 2
                reach = 2.6 + (P.RIB_SPAN - 2.6) * math.sin(ang) * 1.03
                height = (py - 0.5) * math.cos(ang) + 1.8 * math.sin(ang * 2) - 0.6 * math.sin(ang)
                rib.append((px + side[0] * sgn * reach, height, pz + side[1] * sgn * reach))
                radii.append(0.9 - 0.3 * u)
            with s.smooth():
                s.bent_tube("BoneWhite", rib, radii, 7, caps=(False, False))
            fx, fz = px + side[0] * sgn * P.RIB_SPAN, pz + side[1] * sgn * P.RIB_SPAN
            s.collider((fx, 3.5, fz), (2.6, 7.0, 2.6), 0.0, True, "BoneWhite")
    rng = random.Random(131)
    for k in range(len(spine) - 1):
        (ax, az), (bx, bz) = spine[k], spine[k + 1]
        length = math.dist((ax, az), (bx, bz))
        side = (-(bz - az) / length, (bx - ax) / length)
        lateral = 5.0 if k % 2 else -5.0
        px, pz = (ax + bx) / 2 + side[0] * lateral, (az + bz) / 2 + side[1] * lateral
        s.prop("BoneScatter", px, pz, rng.uniform(0, 360), rng.uniform(1.0, 1.3))


def duel(s):
    """The name duel, under the carcass's ribs: two waist-high stones on the spine's line, each with a dark slate
    sloping up towards the other. Anchors duel<n>: the stone's foot, facing the other stone (w, h: the slate)."""
    for k, (p, q) in enumerate((P.DUEL, list(reversed(P.DUEL)))):
        x, z = p
        rot = P.rot_towards(p, q)
        w, d, low, high = 3.4, 1.7, 2.5, 3.3
        s.prop("DuelStone", x, z, rot, 1.0)
        s.collider((x, 0.25, z), (w + 1.0, 0.5, d + 1.0), rot, True, "RuinStone")
        s.collider((x, high / 2, z), (w, high, d), rot, True, "RuinStone")
        m = 0.3
        s.anchor(f"duel{k + 1}", x, 0.0, z, rot, w=w - 2 * m, h=round(math.hypot(d, high - low) - 2 * m, 2))
    mx, mz = (P.DUEL[0][0] + P.DUEL[1][0]) / 2, (P.DUEL[0][1] + P.DUEL[1][1]) / 2
    pool(s, mx, 8.0, mz, 24, 1.0)


def tusks(s):
    """Two colossal tusks of old bone curving up out of the ash and leaning in over the way between them."""
    x, z, rot = P.TUSKS
    f = Frame(x, z, rot)
    for side, sc in ((-1, 1.0), (1, 0.86)):
        tx, tz = f.w(side * 10.0, 0.0)
        # (the kit's tusk leans toward its own +x; turned so each leans in toward the other)
        rocks.rock(s, "RealmTusk", tx, tz, rot + (180.0 if side > 0 else 0.0), sc, core_h=6.0)


# The junk, the arch ---------------------------------------------------------------------------------------------------


def junk(s):
    """Heaps of junk lying about the plain: rubble, a broken gear wheel half buried, a pile of giant chain."""
    for k, (x, z, r, h, seed) in enumerate(P.JUNK):
        rng = random.Random(seed)
        a = rng.uniform(0, 360)
        gx, gz = P.polar((x, z), a, 2.0)
        gear(s, gx, gz, rng.uniform(0, 360), round(rng.uniform(0.9, 1.3), 3), -0.8)
        cx, cz = P.polar((x, z), a + 180.0, max(r * 0.6, 7.5))
        chain_pile(s, cx, cz, rng.uniform(0, 360), round(rng.uniform(0.9, 1.2), 3))
        rocks.scatter(s, ("RealmBoulderA", "RealmBoulderB", "RealmSlab"), x, z, r, 9, (0.8, 1.5), seed, collide=True,
                      spacing=0.7, avoid=[(gx, gz, 5.5), (cx, cz, 4.5)])


# The RustGear's and the ChainPile's sizes as made (props_realmjunk): the gear stands on its edge across x.
GEAR_SIZE = (7.9, 7.4, 2.0)
PILE_SIZE = (5.8, 2.0, 4.9)


def gear(s, x, z, rot, sc, y=0.0):
    """A broken gear wheel standing on its edge in the junk, solid along its own width."""
    s.prop("RustGear", x, z, rot, sc, y)
    w, h, d = GEAR_SIZE
    s.collider((x, y + h * sc / 2, z), (w * sc * 0.8, h * sc, d * sc * 0.6), rot, True, "DarkMetal")


def chain_pile(s, x, z, rot, sc, y=0.0):
    """A heap of giant chain, solid low over its middle."""
    s.prop("ChainPile", x, z, rot, sc, y)
    w, h, d = PILE_SIZE
    s.collider((x, y + h * sc * 0.4, z), (w * sc * 0.7, h * sc * 0.8, d * sc * 0.7), rot, True, "DarkMetal")


def arch(s):
    """The great arch of twisted rock north-west of the bowl, framing the glow."""
    x, z, span, height, rot = P.ARCH
    terrain.arch(s, x, 0.0, z, span, height, 5.5, rot, 701)
    for side in (-1, 1):
        a = math.radians(-rot)
        fx, fz = x + math.cos(a) * side * span / 2, z + math.sin(a) * side * span / 2
        s.collider((fx, 8.0, fz), (8.0, 16.0, 8.0), rot, True, "RockGrey")


def build(s, g):
    ledge(s, g)
    bowl(s, g)
    tableaux(s)
    throne(s)
    steles(s)
    grotto(s, g)
    chessboard(s)
    notebook(s)
    rift_mark(s)
    carcass(s)
    duel(s)
    tusks(s)
    junk(s)
    arch(s)
