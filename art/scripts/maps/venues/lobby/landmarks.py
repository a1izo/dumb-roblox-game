"""The Grey Realm's landmarks: the flagstone plaza with its ring of candle stones, the five bases of
the tableaux and the bell round it, the title monolith, the bone throne on its mesa and the Most Wins
slab at its foot, the Academy's ring of broken pillars, a wayside rock, the colossal carcass and the
duel's two slates under its ribs. Each records the anchors the lobby's Luau builds its own things at
(the board, signs, candles, stone figures, drill desks, effigies, apples, the spawn).

A pale light hangs over every place where something is done or read (the lobby is dark, on purpose)."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.city import Frame
from maps.mesher import cross, dot, sub
from maps.venues.lobby import plan as P
from maps.venues.lobby.terrain import blade, boulder, column, needle_field, rock

PALE = (170, 196, 232)


def pool(s, x, y, z, range_=26, brightness=1.0):
    """A pool of the realm's pale light."""
    s.light("point", (x, y, z), PALE, range_, brightness)


def away(s, mat, pts, inside):
    """A face whose front looks away from the point `inside`."""
    n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
    cx = sum(p[0] for p in pts) / len(pts)
    cy = sum(p[1] for p in pts) / len(pts)
    cz = sum(p[2] for p in pts) / len(pts)
    if dot(n, (cx - inside[0], cy - inside[1], cz - inside[2])) < 0:
        pts = list(reversed(pts))
    s.polygon(mat, pts)


def flag_disc(s, g, c, r, seed, mat="RuinFlag", zone="plaza", name=None, y=0.04, broken=0.12):
    """A disc of old flagstones with a ragged edge, a few loose stones strewn past it."""
    rng = random.Random(seed)
    pts = []
    n = 28
    for k in range(n):
        a = 2 * math.pi * k / n
        pts.append((c[0] + math.cos(a) * r * (1 - rng.uniform(0, broken)), c[1] + math.sin(a) * r * (1 - rng.uniform(0, broken))))
    hull = g2.convex_hull(pts)
    city.up_face(s, mat, hull, y)
    s.zone(zone, hull, max(0.0, y - 0.04), name=name)
    for k in range(18):
        a = rng.uniform(0, math.tau)
        d = r * rng.uniform(1.0, 1.25)
        cx, cz = c[0] + math.cos(a) * d, c[1] + math.sin(a) * d
        w = rng.uniform(1.4, 3.2)
        city.up_face(s, mat, g2.rect(cx, cz, w, w * rng.uniform(0.6, 1.0), rng.uniform(0, 90)), y)
    return hull


# The plaza ------------------------------------------------------------------------------------------


def plaza(s, g):
    flag_disc(s, g, P.PLAZA_C, P.PLAZA_R, 31, name="the plaza")
    # A worn ring of darker flagstones round the plaza's middle.
    px, pz = P.PLAZA_C
    for k in range(32):
        a0, a1 = 2 * math.pi * k / 32, 2 * math.pi * (k + 1) / 32
        if k % 5 == 3:
            continue  # worn away
        pts = [(px + math.cos(a) * r, pz + math.sin(a) * r) for a, r in ((a0, 16.0), (a1, 16.0), (a1, 17.2), (a0, 17.2))]
        s.polygon("RuinStone", [(x, 0.09, z) for x, z in reversed(g2.ccw(pts))])
    # The middle is open (the view from the terrace runs over it to the title): a dark disc in the stones, and
    # round it twelve low candle stones. The game stands a candle on each and lights one for every player who
    # is ready (anchors ready<n>, at the stone's top).
    city.up_face(s, "BlackTrim", P.circle(P.PLAZA_C, 2.4, 14), 0.09)
    rng = random.Random(33)
    for k, (x, z) in enumerate(P.ready_stones()):
        h = P.READY_H
        lean = rng.uniform(-0.06, 0.06)
        s.lathe("RuinStone", (x, 0.0, z), [(0.95, 0.0), (0.82, 0.3), (0.72 + lean, h - 0.3), (0.86, h - 0.12), (0.8, h)],
                8, caps=(False, True))
        s.collider((x, h / 2, z), (1.5, h, 1.5), 22.5, True, "RuinStone")
        s.anchor(f"ready{k + 1}", x, h, z, P.rot_towards((x, z), P.PLAZA_C))
    pool(s, px, 7.0, pz, 30, 0.9)


# The monolith and the throne -------------------------------------------------------------------------


def monolith(s):
    x, z, w, t, h = P.MONO
    rng = random.Random(61)
    s.box("RuinStone", (x, 0.4, z), (w + 6.0, 0.8, t + 5.0), collide=True)
    body = h - 9.0
    s.box("RuinStone", (x, 0.8 + body / 2, z), (w, body, t), skip=("-y",))
    # The broken top: blocks of different heights, the corners snapped off (their faces only ever
    # set back, never in front of the carved frame).
    cols = 9
    for k in range(cols):
        cw = w / cols
        cx = x - w / 2 + cw * (k + 0.5)
        edge_drop = 5.0 if k in (0, cols - 1) else 2.5 if k in (1, cols - 2) else 0.0
        top = h - edge_drop - rng.uniform(0, 2.2)
        s.box("RuinStone", (cx, (body + 0.8 + top) / 2, z - rng.uniform(0, 0.3)),
              (cw + 0.02, top - body - 0.8 + 0.02, t - rng.uniform(0, 0.8)), skip=("-y",))
    s.collider((x, h / 2, z), (w, h, t), 0.0, True, None)
    # A carved frame round the title and the tagline (the game writes them on dark panels).
    fz = P.MONO_FACE + 0.3
    for fx in (-23.4, 23.4):
        s.box("RuinStone", (x + fx, 15.5, fz), (1.2, 14.4, 0.6))
        s.box("BoneOld", (x + fx, 23.4, fz + 0.1), (2.0, 1.2, 0.8))
    for fy in (8.2, 22.7):
        s.box("RuinStone", (x, fy, fz), (48.0, 0.9, 0.6))
    s.box("BlackTrim", (x, 15.4, P.MONO_FACE + 0.05), (46.0, 14.0, 0.1))
    # Great tusks either side, curving up and in.
    for side in (-1, 1):
        base = (x + side * 33.0, -0.5, z + 3.0)
        prev = base
        for q in range(1, 9):
            u = q / 8
            p = (x + side * (33.0 + 4.0 * math.sin(u * math.pi) - 9.0 * u * u), 30.0 * u, z + 3.0 + 6.0 * u)
            s.tube("BoneWhite", prev, p, 2.4 * (1 - u * 0.8), 9, caps=False, radius_b=2.4 * (1 - u * 0.8) * 0.93)
            prev = p
        s.collider((base[0] + side * 0.6, 4.0, base[2] + 0.5), (5.0, 8.0, 5.0), 0.0, True, "BoneWhite")
    for side in (-1, 1):
        s.prop("BoneBrazier", x + side * 21.0, P.MONO_FACE + 5.5, side * 30.0)
    s.anchor("title", *P.TITLE[:3], P.TITLE[3], w=P.TITLE[4], h=P.TITLE[5])
    s.anchor("tagline", *P.TAGLINE[:3], P.TAGLINE[3], w=P.TAGLINE[4], h=P.TAGLINE[5])


def throne(s):
    x, z, r, h = P.THRONE_MESA
    s.prop("BoneThrone", x, z, P.THRONE_ROT, 1.0, h)
    # Where the game seats the player with the most wins, in stone: the seat's top (the throne's seat is
    # 4.45 over its foot, its middle a stud behind the throne's own), facing the plaza.
    fx, fz = P.facing(P.THRONE_ROT)
    s.anchor("throne", x - fx * 1.0, h + 4.45, z - fz * 1.0, P.THRONE_ROT, w=5.6, h=8.0)
    f = Frame(x, z, P.THRONE_ROT)
    for lx, lz, rot in ((-5.5, -7.5, 30.0), (6.0, -7.0, 200.0)):
        px, pz = f.w(lx, lz)
        s.prop("SkullPile", px, pz, rot, 1.0, h)
    for side in (-1, 1):
        bx, bz = f.w(side * 8.5, -3.0)
        s.prop("BoneBrazier", bx, bz, 0.0, 1.2, h)


# The steles -----------------------------------------------------------------------------------------------


def steles(s):
    """The stone a board is written on (one is left: Most Wins, low, at the foot of the throne's mesa)."""
    rng = random.Random(83)
    for name, (x, z, rot, bw, bh, board_y) in P.STELES.items():
        f = Frame(x, z, rot)
        sw, sh, t = bw + 4.0, board_y + bh / 2 + 4.0, P.STELE_T
        s.box("RuinStone", (x, 0.35, z), (sw + 2.4, 0.7, t + 2.4), rot, collide=True)
        body = sh - 3.5
        s.box("RuinStone", (x, 0.7 + body / 2, z), (sw, body, t), rot, collide=True, skip=("-y",))
        # A broken top edge (set back a little from the face).
        cols = 4
        for k in range(cols):
            lx = -sw / 2 + sw * (k + 0.5) / cols
            top = sh + rng.uniform(-1.2, 0.6) - (0.8 if k in (0, cols - 1) else 0.0)
            cx, cy, cz = f.w3(lx, 0.0, rng.uniform(0.0, 0.15))
            s.box("RuinStone", (cx, (body + 0.7 + top) / 2, cz), (sw / cols + 0.02, top - body - 0.7 + 0.02, t - 0.3),
                  rot, skip=("-y",))
        # The carved frame round the board, a bone ornament over it.
        fz = -t / 2 - 0.2
        for lx in (-bw / 2 - 0.7, bw / 2 + 0.7):
            s.box("RuinStone", f.w3(lx, board_y, fz), (0.9, bh + 2.3, 0.5), rot)
        for ly in (board_y - bh / 2 - 0.7, board_y + bh / 2 + 0.7):
            s.box("RuinStone", f.w3(0.0, ly, fz), (bw + 2.3, 0.9, 0.5), rot)
        s.box("BlackTrim", f.w3(0.0, board_y, -t / 2 - 0.03), (bw + 0.6, bh + 0.6, 0.06), rot)
        s.box("BoneOld", f.w3(0.0, board_y + bh / 2 + 1.7, fz), (3.0, 0.9, 0.6), rot)
        bx, by, bz = f.w3(0.0, board_y, -t / 2 - 0.17)
        s.anchor(name, bx, by, bz, rot, w=bw, h=bh)
        # A candle cluster at its foot, and a pale light for reading it by.
        cx, cz = f.w(bw / 2 - 1.0, -t / 2 - 2.2)
        s.prop("CandleCluster", cx, cz, rng.uniform(0, 360), 0.9, 0.0)
        lx, ly, lz = f.w3(0.0, board_y + 3.0, -t / 2 - 6.0)
        pool(s, lx, ly, lz)


# Round the plaza: the tableaux and the bell ---------------------------------------------------------------------


def base(s, x, z, r, h, seed):
    """A low round base of old stone, its edge worn, flagged on top; solid (people step up onto it)."""
    rng = random.Random(seed)
    n = 18
    s.lathe("RuinStone", (x, 0.0, z), [(r + 0.6, 0.0), (r + 0.45, h * 0.45), (r, h * 0.5), (r, h)], n, caps=(False, False))
    city.up_face(s, "RuinFlag", P.circle((x, z), r, n), h)
    # A darker ring inlaid near its edge, worn through in places.
    for k in range(n):
        if rng.random() < 0.25:
            continue
        a0, a1 = math.tau * k / n, math.tau * (k + 1) / n
        pts = [(x + math.cos(a) * rr, z + math.sin(a) * rr) for a, rr in ((a0, r - 1.3), (a1, r - 1.3), (a1, r - 0.6),
                                                                         (a0, r - 0.6))]
        s.polygon("RuinStone", [(px, h + 0.05, pz) for px, pz in reversed(g2.ccw(pts))])
    # Two boxes turned against each other stand in for the disc.
    side = r * 1.6
    for rot in (0.0, 45.0):
        s.collider((x, h / 2, z), (side, h, side), rot, True, "RuinStone")


def tableaux(s):
    """The five tableaux, where boards once stood round the plaza: a low round base each, a pale light over
    it. The game stands its stone figures on them (anchors tableau<n> at the base's top, facing the plaza)."""
    for k, (x, z) in enumerate(P.TABLEAUX):
        base(s, x, z, P.TABLEAU_R, P.TABLEAU_H, 520 + k)
        s.anchor(f"tableau{k + 1}", x, P.TABLEAU_H, z, P.rot_towards((x, z), P.PLAZA_C), r=P.TABLEAU_R)
        pool(s, x, P.TABLEAU_H + 9.0, z, 24, 1.0)


def bell(s):
    """The bell of Death's mark, at the sixth place round the plaza: two great tusks rising from a round
    base and crossing over a black bell that hangs between them, clear of people's heads. The game tolls
    it (anchor bell: the bell's mouth)."""
    x, z = P.BELL
    rot = P.rot_towards((x, z), P.PLAZA_C)
    f = Frame(x, z, rot)
    base(s, x, z, P.BELL_R, 0.5, 531)
    top = 11.6
    for side in (-1, 1):
        prev = f.w3(side * 2.9, 0.3, 0.0)
        for q in range(1, 9):
            u = q / 8
            # Out a little, then in and over: the two cross just past the middle.
            lx = side * (2.9 + 1.5 * math.sin(u * math.pi) - 3.6 * u * u)
            p = f.w3(lx, 0.3 + (top - 0.3) * u, side * 0.35 * u)
            s.tube("BoneWhite", prev, p, 0.62 * (1 - u * 0.72), 8, caps=False, radius_b=0.62 * (1 - (u + 0.125) * 0.72))
            prev = p
        fx, fz = f.w(side * 2.9, 0.0)
        s.collider((fx, 3.6, fz), (1.5, 7.2, 1.5), rot, True, "BoneWhite")
    # The yoke it hangs from, lashed where the tusks cross; the bell; its clapper.
    yoke = 9.6
    s.tube("BoneOld", f.w3(-1.5, yoke, 0.0), f.w3(1.5, yoke, 0.0), 0.3, 7)
    mouth = 6.0
    bx, bz = x, z
    s.tube("BlackTrim", (bx, yoke, bz), (bx, mouth + 3.1, bz), 0.12, 6, caps=False)
    s.lathe("BlackTrim", (bx, mouth, bz), [(1.75, 0.0), (1.85, 0.12), (1.6, 0.5), (1.25, 1.4), (1.0, 2.3), (0.7, 2.85),
                                           (0.0, 3.1)], 16, caps=(False, False))
    # The inside of its mouth, seen from below (the profile runs top to bottom, so the faces look inwards).
    s.lathe("BlackTrim", (bx, mouth + 0.02, bz), [(0.0, 1.6), (1.7, 0.0)], 16, caps=(False, False))
    s.tube("BoneOld", (bx, mouth + 1.2, bz), (bx, mouth - 0.5, bz), 0.1, 6)
    s.lathe("BoneOld", (bx, mouth - 0.85, bz), [(0.0, 0.0), (0.3, 0.15), (0.3, 0.4), (0.0, 0.55)], 8, caps=(False, False))
    s.anchor("bell", bx, mouth, bz, rot, r=1.85, h=3.1)
    for side in (-1, 1):
        cx, cz = f.w(side * 1.9, -2.6)
        s.prop("CandleCluster", cx, cz, (side * 50) % 360, 0.8, 0.5)
    pool(s, x, 9.0, z, 24, 1.0)


# The Academy -----------------------------------------------------------------------------------------------


def academy(s, g):
    c = P.ACADEMY_C
    flag_disc(s, g, c, P.ACADEMY_R + 3.0, 97, name="the Academy", broken=0.06)
    rng = random.Random(101)
    gate = math.radians(P.GATE_DIR)
    # The ring of pillars: fluted drums, most broken off; the gate's two stand whole with a lintel.
    count = 16
    for k in range(count):
        a = gate + 2 * math.pi * k / count
        if k in (0,):
            continue
        px, pz = c[0] + math.cos(a) * P.ACADEMY_R, c[1] + math.sin(a) * P.ACADEMY_R
        gate_post = k in (1, count - 1)
        h = 15.5 if gate_post else rng.choice((4.0, 6.5, 9.0, 11.0, 13.0))
        pillar(s, px, pz, h, rng, whole=gate_post)
    # The lintel over the gate (between posts 1 and 15), the sign on its outer face.
    a1, a2 = gate + 2 * math.pi / count, gate - 2 * math.pi / count
    p1 = (c[0] + math.cos(a1) * P.ACADEMY_R, c[1] + math.sin(a1) * P.ACADEMY_R)
    p2 = (c[0] + math.cos(a2) * P.ACADEMY_R, c[1] + math.sin(a2) * P.ACADEMY_R)
    mid = ((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2)
    span = math.dist(p1, p2)
    lrot = P.rot_towards(c, mid)  # faces out of the ring, towards the plaza
    s.box("RuinStone", (mid[0], 16.4, mid[1]), (span + 3.0, 1.8, 2.2), lrot, collide=True)
    s.box("RuinStone", (mid[0], 17.6, mid[1]), (span + 1.0, 0.6, 1.8), lrot)
    f = Frame(mid[0], mid[1], lrot)
    sx, sy, sz = f.w3(0.0, 16.4, -1.27)
    s.anchor("academyGate", sx, sy, sz, lrot, w=16.0, h=1.5)
    # Fallen drums lying about outside the ring.
    for k in range(6):
        a = gate + math.pi + rng.uniform(-2.2, 2.2)
        d = P.ACADEMY_R + rng.uniform(4, 9)
        x, z = c[0] + math.cos(a) * d, c[1] + math.sin(a) * d
        if not g2.contains(P.BASIN, (x, z)):
            continue
        r = 1.3
        yaw = rng.uniform(0, math.tau)
        ax, az = x + math.cos(yaw) * 2.0, z + math.sin(yaw) * 2.0
        bx, bz = x - math.cos(yaw) * 2.0, z - math.sin(yaw) * 2.0
        s.tube("RuinStone", (ax, r, az), (bx, r, bz), r, 12)
        s.collider((x, r, z), (4.0, 2 * r, 2 * r), -math.degrees(yaw), True, "RuinStone")
    # Behind the ring's back, where a tablet once explained the place: two braziers, and a pale light over
    # the ring's middle (the gate's lintel names it).
    back = gate + math.pi
    tx, tz = c[0] + math.cos(back) * (P.ACADEMY_R + 2.0), c[1] + math.sin(back) * (P.ACADEMY_R + 2.0)
    tf = Frame(tx, tz, P.rot_towards((tx, tz), c))
    for side in (-1, 1):
        bx, bz = tf.w(side * 18.5, -3.0)
        s.prop("BoneBrazier", bx, bz, 0.0, 1.0)
    pool(s, c[0], 9.0, c[1], 30, 0.9)
    # The practice altars (the game's drill desks stand in them) and the effigies.
    for k, (x, z, rot) in enumerate(P.altars()):
        s.anchor(f"drill{k + 1}", x, 0.0, z, rot)
        s.preview_prop("PracticeAltar", x, z, rot)
    for k, (x, z, rot) in enumerate(P.effigies()):
        s.anchor(f"dummy{k + 1}", x, 0.0, z, rot)
        s.preview_prop("Puppet", x, z, rot)


def pillar(s, x, z, h, rng, whole=False, y=0.0):
    """A fluted stone pillar on a square base, broken off at h (whole ones get a capital); y is the
    ground's height."""
    s.box("RuinStone", (x, y + 0.6, z), (3.6, 1.2, 3.6), rng.uniform(0, 90), collide=True)
    s.lathe("RuinStone", (x, y + 1.2, z), [(1.35, 0.0), (1.2, 0.5), (1.2, h - 1.2 - (1.0 if whole else 0.0))], 14,
            caps=(False, not whole), flutes=12, flute_depth=0.12)
    if whole:
        s.lathe("RuinStone", (x, y + h - 1.0, z), [(1.2, 0.0), (1.7, 0.6), (1.9, 1.0), (0.0, 1.0)], 14, caps=(False, False))
    else:
        # The break: a jagged cap.
        top = y + h
        for k in range(5):
            a = rng.uniform(0, math.tau)
            s.box("RuinStone", (x + math.cos(a) * 0.5, top - 0.1, z + math.sin(a) * 0.5), (1.0, rng.uniform(0.3, 0.9), 0.8),
                  math.degrees(a))
    s.collider((x, y + h / 2 + 0.6, z), (2.4, h, 2.4), 0.0, True, "RuinStone")


# The wayside rock and the carcass ----------------------------------------------------------------------------


def wayside_rock(s):
    """A low flat-topped rock by the north-west path, a few bones about it (once the dice rock)."""
    x, z, r, h = P.WAYSIDE_ROCK
    rock(s, x, z, r, h, 211, tiers=2, sides=10, taper=0.12, flat_top=True, top_mat="RuinFlag")
    s.prop("SkullPile", x - 9.0, z - 5.0, 40.0, 1.2)
    s.prop("BoneScatter", x + 3.0, z + 9.0, 70.0)


def carcass(s):
    """A colossal thing's remains: its horned skull sunk in the ash, the spine running away from
    it, the ribs arching over the ground either side (people walk between them)."""
    sx, sz, srot = P.CARCASS_SKULL
    s.prop("GiantSkull", sx, sz, srot, 1.0, -0.3)  # resting on its jaw, just settled into the ash
    f = Frame(sx, sz, srot)
    for lx, lz, w, d, hh in ((0.0, 4.5, 11.0, 11.0, 9.0), (0.0, -8.0, 7.0, 12.0, 5.0)):
        cx, cz = f.w(lx, lz)
        s.collider((cx, hh / 2, cz), (w, hh, d), srot, True, "BoneOld")
    spine = P.SPINE
    for k in range(len(spine) - 1):
        a, b = spine[k], spine[k + 1]
        ya = P.SPINE_Y - 1.5 * k
        yb = P.SPINE_Y - 1.5 * (k + 1)
        steps = 3
        for q in range(steps):
            u = (q + 0.5) / steps
            px, pz = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
            py = ya + (yb - ya) * u
            s.lathe("BoneOld", (px, py - 2.2, pz), [(0.0, 0.0), (2.4, 0.4), (2.7, 2.2), (2.4, 4.0), (0.0, 4.4)], 10,
                    caps=(False, False))
            s.tube("BoneOld", (px, py + 2.0, pz), (px, py + 4.0, pz), 0.7, 6, radius_b=0.3)
    # The ribs: from each vertebra out and down to a foot in the ash either side.
    for k in range(len(spine)):
        cx, cz = spine[k]
        if k + 1 < len(spine):
            dx, dz = spine[k + 1][0] - cx, spine[k + 1][1] - cz
        else:
            dx, dz = cx - spine[k - 1][0], cz - spine[k - 1][1]
        length = math.hypot(dx, dz)
        side = (-dz / length, dx / length)
        top = P.SPINE_Y - 1.5 * k
        for sgn in (-1, 1):
            prev = (cx, top, cz)
            for q in range(1, 9):
                u = q / 8
                ang = u * math.pi / 2
                reach = P.RIB_SPAN * (math.sin(ang) * 1.05)
                py = top * math.cos(ang) + 1.8 * math.sin(ang * 2) - 0.6
                p = (cx + side[0] * sgn * reach, py, cz + side[1] * sgn * reach)
                s.tube("BoneWhite", prev, p, 0.9 - 0.3 * u, 7, caps=False, radius_b=0.9 - 0.3 * (u + 0.125))
                prev = p
            fx, fz = cx + side[0] * sgn * P.RIB_SPAN, cz + side[1] * sgn * P.RIB_SPAN
            s.collider((fx, 3.5, fz), (2.6, 7.0, 2.6), 0.0, True, "BoneWhite")
    # Bones strewn inside the cage, between the ribs' feet (clear of them).
    rng = random.Random(131)
    for k in range(len(spine) - 1):
        (ax, az), (bx, bz) = spine[k], spine[k + 1]
        length = math.dist((ax, az), (bx, bz))
        side = (-(bz - az) / length, (bx - ax) / length)
        lateral = 5.0 if k % 2 else -5.0
        px, pz = (ax + bx) / 2 + side[0] * lateral, (az + bz) / 2 + side[1] * lateral
        s.prop("BoneScatter", px, pz, rng.uniform(0, 360), rng.uniform(1.0, 1.3))


def duel(s):
    """The name duel, under the carcass's ribs: two waist-high stones on the spine's line, each with a dark
    slate sloping up towards the other. A duellist stands behind their own stone, looking over it at the
    other one. Anchors duel<n>: the stone's foot, facing the other stone (w, h: the slate)."""
    for k, (p, q) in enumerate((P.DUEL, list(reversed(P.DUEL)))):
        x, z = p
        rot = P.rot_towards(p, q)
        f = Frame(x, z, rot)
        w, d, low, high = 3.4, 1.7, 2.5, 3.3
        s.box("RuinStone", (x, 0.25, z), (w + 1.0, 0.5, d + 1.0), rot, collide=True)
        s.box("RuinStone", (x, 0.5 + (low - 0.5) / 2, z), (w, low - 0.5, d), rot, skip=("-y", "+y"))
        s.collider((x, high / 2, z), (w, high, d), rot, True, "RuinStone")
        # The sloping top: low on the duellist's side (behind, +z in the stone's own frame), high in front.
        inside = f.w3(0.0, low - 0.6, 0.0)
        a, b = f.w3(-w / 2, low, d / 2), f.w3(w / 2, low, d / 2)
        c, e = f.w3(w / 2, high, -d / 2), f.w3(-w / 2, high, -d / 2)
        c0, e0 = f.w3(w / 2, low, -d / 2), f.w3(-w / 2, low, -d / 2)
        away(s, "RuinStone", [a, b, c, e], inside)
        away(s, "RuinStone", [e, c, c0, e0], inside)
        away(s, "RuinStone", [a, e, e0], inside)
        away(s, "RuinStone", [b, c0, c], inside)
        # The slate let into the slope (lifted a hair off it, along the slope's own normal).
        slope = math.atan2(high - low, d)
        lift = 0.03
        ny, nz = math.cos(slope) * lift, math.sin(slope) * lift
        m = 0.3
        sa, sb = f.w3(-w / 2 + m, low + m * math.sin(slope) + ny, d / 2 - m * math.cos(slope) + nz), \
            f.w3(w / 2 - m, low + m * math.sin(slope) + ny, d / 2 - m * math.cos(slope) + nz)
        sc, se = f.w3(w / 2 - m, high - m * math.sin(slope) + ny, -d / 2 + m * math.cos(slope) + nz), \
            f.w3(-w / 2 + m, high - m * math.sin(slope) + ny, -d / 2 + m * math.cos(slope) + nz)
        away(s, "BlackTrim", [sa, sb, sc, se], inside)
        s.anchor(f"duel{k + 1}", x, 0.0, z, rot, w=w - 2 * m, h=round(math.hypot(d, high - low) - 2 * m, 2))
        # A candle cluster beside it, on the side away from the bones strewn under the ribs.
        cx, cz = f.w(-(w / 2 + 1.3), 0.6)
        s.prop("CandleCluster", cx, cz, (k * 140 + 30) % 360, 0.8, 0.0)
    mx, mz = (P.DUEL[0][0] + P.DUEL[1][0]) / 2, (P.DUEL[0][1] + P.DUEL[1][1]) / 2
    pool(s, mx, 8.0, mz, 24, 1.0)


def apples(s):
    """Where the seven grey apples lie (the game makes them; each player finds their own)."""
    for k, (x, y, z) in enumerate(P.apples()):
        s.anchor(f"apple{k + 1}", x, y, z, 0.0)


# The spawn terrace -------------------------------------------------------------------------------------------


def terrace(s, g):
    """A broken ruin a few studs over the plaza's south side: wide steps down its north edge, ruined
    pillars at its corners, a worn ring of dark stone where players appear, the view north."""
    cx, cz, w, d, h = P.TERRACE
    poly = g2.rect(cx, cz, w, d)
    city.terrace(s, g, poly, h, 0.0, top_mat="RuinFlag", wall_mat="RuinStone", zone="plaza", name="the terrace",
                 coping="RuinStone")
    (ax, az), (bx, bz), sw = P.TERRACE_STEPS
    city.stairs(s, g, (ax, az), (bx, bz), h, 0.0, sw, mat="RuinStone", side_mat="RuinStone", step=0.85, name="the steps")
    sx, sz = P.SPAWN
    for k in range(28):
        a0, a1 = 2 * math.pi * k / 28, 2 * math.pi * (k + 1) / 28
        if k % 6 == 4:
            continue
        pts = [(sx + math.cos(a) * r, sz + math.sin(a) * r) for a, r in ((a0, 9.0), (a1, 9.0), (a1, 10.0), (a0, 10.0))]
        s.polygon("RuinStone", [(x, h + 0.06, z) for x, z in reversed(g2.ccw(pts))])
    s.anchor("spawn", sx, h, sz, 0.0)
    rng = random.Random(14)
    back = cz + d / 2 - 1.4
    front = cz - d / 2 + 1.4
    # The corners: pillars, the two at the back whole and the two at the front snapped off.
    for qx, qz, hh, whole in ((-21.0, back, 15.0, True), (21.0, back, 15.0, True), (-21.0, front, 7.0, False),
                              (21.0, front, 10.0, False)):
        pillar(s, cx + qx, qz, hh, rng, whole=whole, y=h)
    # A worn balustrade along the back and the sides (low blocks, gaps where it has fallen).
    for (x0, z0, x1, z1) in ((-23.0, back + 1.1, 23.0, back + 1.1), (-22.7, front - 0.5, -22.7, back + 1.5),
                             (22.7, front - 0.5, 22.7, back + 1.5)):
        length = math.dist((x0, z0), (x1, z1))
        along_x = z0 == z1
        u = 2.0
        while u < length - 2.0:
            run = rng.uniform(2.5, 6.0)
            if rng.random() < 0.3:
                u += run
                continue
            mx = x0 + (x1 - x0) * (u + run / 2) / length
            mz = z0 + (z1 - z0) * (u + run / 2) / length
            bh = rng.uniform(1.0, 2.8)
            s.box("RuinStone", (mx, h + bh / 2, mz), (run if along_x else 1.0, bh, 1.0 if along_x else run), 0.0,
                  skip=("-y",))
            u += run + rng.uniform(0.2, 1.4)
    for side in (-1, 1):
        s.prop("BoneBrazier", cx + side * 14.0, front + 1.6, 0.0, 1.0, h)
    pool(s, sx, h + 9.0, sz, 30, 1.0)


def vistas(s, g):
    """The two ledges at the island's rim where you look out over the clouds: the cleft (north-west),
    between leaning masses of rock; the needle ledge (north-east), a field of spikes with a small
    blade glowing in a rock at its brink."""
    # The cleft.
    cx, cz = P.CLEFT
    a = math.radians(P.CLEFT_DEG)
    out = (math.cos(a), math.sin(a))
    tan = (-out[1], out[0])
    flag_disc(s, g, (cx, cz), P.LEDGE_R, 241, name="the cleft", broken=0.05)
    for side, (r, h, seed) in ((1, (11.0, 46.0, 242)), (-1, (9.0, 38.0, 243))):
        mx, mz = cx + out[0] * 9.0 + tan[0] * side * 17.0, cz + out[1] * 9.0 + tan[1] * side * 17.0
        rock(s, mx, mz, r, h, seed, tiers=4, sides=9, taper=0.55, lean=(-tan[0] * side * 0.2, -tan[1] * side * 0.2))
    for side, seed in ((1, 244), (-1, 245)):
        column(s, cx + out[0] * 15.0 + tan[0] * side * 10.5, cz + out[1] * 15.0 + tan[1] * side * 10.5, 3.2, 30.0, seed,
               twist=1.8, sides=12, tiers=9)
    s.box("RuinFlag", (cx + out[0] * 5.0, 0.4, cz + out[1] * 5.0), (7.0, 0.8, 3.0),
          -math.degrees(math.atan2(out[1], out[0])) + 90.0, collide=True)
    needle_field(s, cx + out[0] * 6.0, cz + out[1] * 6.0, 22.0, 9, 6.0, 20.0, 246,
                 avoid=[(cx, cz, 11.0)], arc=(a - 1.2, a + 1.2))
    # The needle ledge with the relic.
    nx, nz = P.NEEDLE
    b = math.radians(P.NEEDLE_DEG)
    nout = (math.cos(b), math.sin(b))
    flag_disc(s, g, (nx, nz), P.LEDGE_R, 251, name="the needle ledge", broken=0.05)
    needle_field(s, nx + nout[0] * 4.0, nz + nout[1] * 4.0, 20.0, 18, 6.0, 26.0, 252,
                 avoid=[(nx, nz, 8.5)], arc=(b - 1.3, b + 1.3))
    rx, rz = nx + nout[0] * 7.5, nz + nout[1] * 7.5
    top = rock(s, rx, rz, 3.4, 4.6, 253, tiers=3, sides=8, taper=0.4, flat_top=True)
    blade(s, rx, top - 0.6, rz, 1.5, 9.5, 0.4, rot=P.rot_towards((rx, rz), (nx, nz)))
    s.light("point", (rx, top + 6.0, rz), (170, 196, 232), 30, 1.1)
    s.light("point", (nx, 4.0, nz), (150, 176, 214), 22, 0.5)


def toss(s):
    """The stone-toss: a cairn of throwing stones at the rift's rim, a brazier by it; the anchors the game
    builds its prompt and the throw's aim at (the rift's middle and radii for the rules)."""
    x, z, rot = P.TOSS
    s.prop("Cairn", x, z, 40.0, 1.6)
    s.anchor("toss", x, 0.0, z, rot)
    cx, cz = P.RIFT_MID
    s.anchor("rift", cx, 0.0, cz, P.RIFT_TURN, rx=P.RIFT_AXES[0], rz=P.RIFT_AXES[1])
    a = math.radians(rot + 90.0)
    s.prop("BoneBrazier", x + math.cos(a) * 5.0, z + math.sin(a) * 5.0, 0.0, 1.0)
    pool(s, x, 7.0, z, 22, 0.9)


def build(s, g):
    terrace(s, g)
    vistas(s, g)
    plaza(s, g)
    tableaux(s)
    bell(s)
    monolith(s)
    toss(s)
    throne(s)
    steles(s)
    academy(s, g)
    wayside_rock(s)
    carcass(s)
    duel(s)
    apples(s)
    boulder(s, 34.0, -48.0, 2.0, 501)
    boulder(s, -30.0, 58.0, 1.6, 502)
