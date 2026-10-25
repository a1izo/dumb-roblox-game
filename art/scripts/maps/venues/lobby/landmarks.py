"""The Grey Realm's landmarks: the flagstone plaza with its ring of candle stones, the five bases of
the tableaux and the bell round it, the bone throne on its dais at the plaza's north edge with its plaque
and the Most Wins slab beside it, the title monolith behind them, the old mesa with the fallen king, the
Academy's ring of broken pillars, the chessboard sunk in the ash, the stone notebook over the rift, the
colossal carcass and the duel's two slates under its ribs. Each records the anchors the lobby's Luau builds its own things at
(the board, signs, candles, stone figures, drill desks, effigies, apples, the spawn).

A pale light hangs over every place where something is done or read (the lobby is dark, on purpose)."""

import math
import random

from maps import city, scratches
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
        back = rng.uniform(0, 0.3)
        s.box("RuinStone", (cx, (body + 0.8 + top) / 2, z - back),
              (cw + 0.02, top - body - 0.8 + 0.02, t - 2 * back - rng.uniform(0, 0.8)), skip=("-y",))
    s.collider((x, h / 2, z), (w, h, t), 0.0, True, None)
    # A carved frame round the title and the tagline (the game writes them on a dark panel), raised over the
    # throne that stands in front.
    fz = P.MONO_FACE + 0.3
    py, ph = P.PANEL
    for fx in (-23.4, 23.4):
        s.box("RuinStone", (x + fx, py, fz), (1.2, ph + 0.4, 0.6))
        s.box("BoneOld", (x + fx, py + ph / 2 + 1.15, fz + 0.1), (2.0, 1.2, 0.8))
    for fy in (py - ph / 2 - 0.45, py + ph / 2 + 0.45):
        s.box("RuinStone", (x, fy, fz), (48.0, 0.9, 0.6))
    s.box("BlackTrim", (x, py, P.MONO_FACE + 0.05), (46.0, ph, 0.1))
    # Great tusks either side, curving up and in.
    for side in (-1, 1):
        base = (x + side * 33.0, -0.5, z + 3.0)
        prev = base
        for q in range(1, 9):
            u = q / 8
            p = (x + side * (33.0 + 4.0 * math.sin(u * math.pi) - 9.0 * u * u), 30.0 * u, z + 3.0 + 6.0 * u)
            r0 = 2.4 * (1 - (q - 1) / 8 * 0.8)
            r1 = 2.4 * (1 - u * 0.8) if q < 8 else 0.08
            s.tube("BoneWhite", prev, p, r0, 9, caps=True, radius_b=r1)
            prev = p
        s.collider((base[0] + side * 0.6, 4.0, base[2] + 0.5), (5.0, 8.0, 5.0), 0.0, True, "BoneWhite")
    for side in (-1, 1):
        s.prop("BoneBrazier", x + side * 21.0, P.MONO_FACE + 5.5, side * 30.0)
    # Under the panel, either side of where the throne stands: two carved eyes, and names scratched over the face.
    f = Frame(x, z, 180.0)
    for ex, ey in P.MONO_EYES:
        carved_eye(s, f, -ex, ey, -t / 2, 5.0, 2.1)
    scratches.overlay(s, (x - w / 2 + 0.6, P.MONO_FACE), (x + w / 2 - 0.6, P.MONO_FACE), 1.2, 13.8, (0.0, 1.0))
    s.anchor("title", *P.TITLE[:3], P.TITLE[3], w=P.TITLE[4], h=P.TITLE[5])
    s.anchor("tagline", *P.TAGLINE[:3], P.TAGLINE[3], w=P.TAGLINE[4], h=P.TAGLINE[5])


# The throne prop's own measures (props_lobby.bone_throne): its seat's top over its foot, the seat's middle in
# front of the prop's middle, its backrest's face behind it, the seat's width, the back's top.
SEAT_TOP, SEAT_Y, BACK_Y, SEAT_W, BACK_TOP = 3.42, -0.3, 1.45, 6.2, 9.96
THRONE_BACK = 1.0  # how far behind the dais' middle the throne stands (room for the plaque's reader in front)


def carved_eye(s, f, lx, ly, lz, w, h):
    """An eye carved in an upright face (the face at local depth lz of frame f, looking out along -z): its
    almond of pale stone standing a little proud, the dark round iris, a glint, a heavy brow over it."""
    inside = f.w3(lx, ly, lz + 1.0)
    n = 12
    upper = [(-w / 2 * math.cos(math.pi * k / n), h / 2 * math.sin(math.pi * k / n) ** 0.8) for k in range(n + 1)]
    lower = [(x, -y * 0.8) for x, y in reversed(upper[1:-1])]
    almond = [f.w3(lx + x, ly + y, lz - 0.06) for x, y in upper + lower]
    away(s, "BoneOld", almond, inside)
    for r, mat, dz, (ox, oy) in ((h * 0.4, "BlackTrim", 0.1, (0.0, -0.04 * h)), (h * 0.09, "BoneWhite", 0.13, (-0.12 * h, 0.08 * h))):
        ring = [f.w3(lx + ox + math.cos(math.tau * k / 14) * r, ly + oy + math.sin(math.tau * k / 14) * r, lz - dz)
                for k in range(14)]
        away(s, mat, ring, inside)
    bx, by, bz = f.w3(lx, ly + h * 0.62, lz - 0.12)
    s.box("RuinStone", (bx, by, bz), (w * 0.95, h * 0.18, 0.36), f.rot)


def eye_stones(s):
    """Standing stones at the ridge's foot, each a carved eye turned on the plaza, names scratched under it."""
    rng = random.Random(311)
    for k, (x, z, rot) in enumerate(P.eye_stones()):
        f = Frame(x, z, rot)
        w, h, t = 3.4, 6.6, 1.3
        s.box("RuinStone", (x, 0.25, z), (w + 1.0, 0.5, t + 1.0), rot, collide=True, skip=("-y",))
        s.box("RuinStone", (x, 0.5 + (h - 1.5) / 2, z), (w, h - 1.5, t), rot, collide=True, skip=("-y",))
        # The broken top: two blocks of different heights, set back from the face.
        for side in (-1, 1):
            top = h - rng.uniform(0.0, 1.0)
            cx, cy, cz = f.w3(side * w / 4, 0.0, rng.uniform(0.05, 0.2))
            s.box("RuinStone", (cx, (h - 1.0 + top) / 2, cz), (w / 2 + 0.02, top - h + 1.0 + 0.02, t - 0.3), rot,
                  skip=("-y",))
        carved_eye(s, f, 0.0, 4.2, -t / 2, 2.4, 1.0)
        a, b = f.w(-w / 2 + 0.15, -t / 2), f.w(w / 2 - 0.15, -t / 2)
        scratches.overlay(s, a, b, 0.8, 3.3, f.dir(0.0, -1.0), u0=0.31 * k, v0=0.17 * k)


def throne(s):
    """The bone throne on its dais at the plaza's north edge, on the spawn's line, facing it: three steps of old
    stone, the throne at the back of the top one, a plaque stone at the dais' foot (the game writes the
    champion's name and wins on it), two braziers at its front corners and one cold light from above."""
    x, z = P.THRONE
    w, d, steps, rise = P.DAIS
    rot = P.THRONE_ROT
    f = Frame(x, z, rot)
    # The steps: each set back from the front and the sides, flush at the back.
    for k in range(steps):
        sw, sd = w - 2.4 * k, d - 1.4 * k
        lz = 0.7 * k
        cx, cz = f.w(0.0, lz)
        top = rise * (k + 1)
        s.box("RuinStone", (cx, top - rise / 2, cz), (sw, rise, sd), rot, collide=True, skip=("-y", "+y"))
        city.up_face(s, "RuinFlag", g2.rect(cx, cz, sw, sd, rot), top)
    s.zone("plaza", g2.rect(x, z, w, d, rot), 0.0, name="the throne's dais")
    floor = rise * steps
    tx, tz = f.w(0.0, THRONE_BACK)
    s.prop("BoneThrone", tx, tz, rot, 1.0, floor)
    # Where the game seats the player with the most wins, in stone: the seat's top, at its middle, facing the
    # spawn; w the seat's width, h the room up to the back's top.
    ax, ay, az = f.w3(0.0, floor + SEAT_TOP, THRONE_BACK + SEAT_Y)
    s.anchor("throne", ax, ay, az, rot, w=SEAT_W, h=BACK_TOP - SEAT_TOP)
    # Nobody stands on the seat or walks through the throne: its plinth and the whole seated room up to the
    # back's top are solid (the stone champion fills it).
    cx, cz = f.w(0.0, THRONE_BACK)
    s.collider((cx, floor + 0.3, cz), (7.8, 0.6, 6.8), rot, True, "RuinStone")
    front, back = SEAT_Y + 0.05 - 1.8, BACK_Y + 1.0  # the seat block's front, the back's rear face
    sx, sz = f.w(0.0, THRONE_BACK + (front + back) / 2)
    s.collider((sx, floor + 0.6 + (BACK_TOP - 0.6) / 2, sz), (SEAT_W, BACK_TOP - 0.6, back - front), rot, True,
               "RuinStone")
    # The plaque stone at the dais' foot: a squat block, a dark slate let into its face.
    pw, ph, pd, pt = 5.6, 2.6, 1.2, 1.9  # block width, height, depth; the slate's middle above the ground
    px, pz = f.w(0.0, -d / 2 - 2.4)
    s.box("RuinStone", (px, 0.3, pz), (pw + 0.8, 0.6, pd + 0.8), rot, collide=True, skip=("-y",))
    s.box("RuinStone", (px, 0.6 + (ph - 0.6) / 2, pz), (pw, ph - 0.6, pd), rot, collide=True, skip=("-y",))
    s.box("RuinStone", (px, ph + 0.12, pz), (pw + 0.3, 0.24, pd + 0.3), rot)
    bx, by, bz = f.w3(0.0, pt, -d / 2 - 2.4 - pd / 2 - 0.03)
    s.box("BlackTrim", (bx, by, bz), (pw - 0.8, 1.5, 0.06), rot)
    qx, qy, qz = f.w3(0.0, pt, -d / 2 - 2.4 - pd / 2 - 0.08)
    s.anchor("throneplaque", qx, qy, qz, rot, w=pw - 1.0, h=1.3)
    # Braziers at the dais' front corners (the two that stood by the throne on the mesa).
    for side in (-1, 1):
        bx2, bz2 = f.w(side * (w / 2 + 2.2), -d / 2 + 1.0)
        s.prop("BoneBrazier", bx2, bz2, 0.0, 1.2)
    # One cold light from above: the realm's pale light, a pool over the throne.
    lx, ly, lz2 = f.w3(0.0, floor + SEAT_TOP + 13.0, THRONE_BACK - 1.0)
    pool(s, lx, ly, lz2, 26, 1.2)


def old_mesa(s):
    """The mesa the throne stood on (nobody climbs it): a chess king lies fallen across its top, the skull piles
    left round it."""
    x, z, r, h = P.OLD_MESA
    kx, kz, krot, ks = P.FALLEN_KING
    s.prop("ChessKingFallen", kx, kz, krot, ks, h)
    f = Frame(kx, kz, krot)
    for lz, rot in ((-8.5, 30.0), (8.5, 200.0)):
        px, pz = f.w(0.0, lz)
        s.prop("SkullPile", px, pz, rot, 1.0, h)


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
        points, radii = [], []
        for q in range(9):
            u = q / 8
            # Out a little, then in and over: the two cross just past the middle.
            lx = side * (2.9 + 1.5 * math.sin(u * math.pi) - 3.6 * u * u)
            points.append(f.w3(lx, 0.3 + (top - 0.3) * u, side * 0.35 * u))
            radii.append(0.62 * (1 - u * 0.72))
        s.bent_tube("BoneWhite", points, radii, 8)
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


# The chessboard's squares under the pieces stand level at this height (the pieces' prop stands on it); the
# others are sunk, lifted or broken out.
BOARD_TOP = 0.2


def chessboard(s):
    """A chessboard sunk in the ash by the north-west path (where the dice rock stood): squares of bone-pale and
    black stone, many sunk or lifted, cracked or gone; its pieces left mid-game (the ChessGame prop, on the
    squares the plan names) and the white king toppled on its own square."""
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
                continue  # gone: the ash shows through
            if name in taken:
                top, turn, size = BOARD_TOP, 0.0, sq - 0.12
            else:
                top = BOARD_TOP + rng.choice((0.0, 0.0, -0.06, -0.3, 0.1, 0.16))
                turn = rng.uniform(-4.0, 4.0)
                size = sq - rng.uniform(0.12, 0.4)
            if name not in taken and rng.random() < 0.18:
                # Cracked in two, the halves apart a little and at different heights.
                for half, dz2, dy in ((-1, -0.05, 0.0), (1, 0.08, rng.uniform(-0.05, 0.08))):
                    hx, hz = f.w(lx + half * size / 4, lz + dz2)
                    s.box(mat, (hx, top + dy - 0.2, hz), (size / 2 - 0.1, 0.4, size), rot + turn, skip=("-y",))
                continue
            s.box(mat, (cx, top - 0.2, cz), (size, 0.4, size), rot + turn, skip=("-y",))
    # A collider under the whole board (its squares are low enough to walk over), and one round each piece.
    s.collider((x, BOARD_TOP / 2 - 0.1, z), (sq * 8, BOARD_TOP + 0.2, sq * 8), rot, True, "BoneOld")
    for name, (kind, colour) in P.CHESS_GAME.items():
        cx, cz = f.w(*P.chess_square(name))
        radius = {"K": 1.15, "Q": 1.15, "B": 1.0, "N": 1.05, "R": 1.05, "P": 0.92}[kind]
        height = {"K": 5.2, "Q": 4.6, "B": 4.1, "N": 3.8, "R": 3.4, "P": 2.7}[kind]
        s.collider((cx, BOARD_TOP + height / 2, cz), (radius * 1.7, height, radius * 1.7), rot + 45.0, True, None)
    s.prop("ChessGame", x, z, rot, 1.0, BOARD_TOP)
    # The toppled king on its square (in the set's mesh), lying along the first rank.
    kx, kz = f.w(*P.chess_square(P.CHESS_FALLEN))
    s.collider((kx, BOARD_TOP + 1.1, kz), (5.6, 2.2, 2.4), rot, True, None)
    # (No light of its own: bone-white and black, the pieces read in the realm's dusk, and the lobby keeps to its
    # number of lights.)


def notebook(s):
    """The stone notebook over the rift, stopped in its fall (it neither collides nor casts a shadow on
    anyone's dive: a diver goes in under it)."""
    x, y, z, rot = P.NOTEBOOK
    s.prop("StoneNotebook", x, z, rot, 1.0, y)


def carcass(s):
    """A dead death god's remains: its skull sunk in the ash on its open jaw, the spine running away from
    it, the ribs arching over the ground either side (people walk between them)."""
    sx, sz, srot = P.CARCASS_SKULL
    s.prop("GiantSkull", sx, sz, srot, 1.0, -0.3)  # a dead death god's, resting on its open jaw in the ash
    f = Frame(sx, sz, srot)
    # Its vault (13 long, 9.5 wide, the horn stumps over it) and its muzzle with the jaw under it.
    for lx, lz, w, d, hh in ((0.0, 5.0, 9.5, 13.0, 13.0), (0.0, -7.0, 8.0, 11.0, 7.5)):
        cx, cz = f.w(lx, lz)
        s.collider((cx, hh / 2, cz), (w, hh, d), srot, True, "BoneOld")
    # The spine (2026-10-25, the owner: "make sure everything connects", the ribs' tops floating under the old upright
    # drums): vertebrae lying along it, a disc between each and the next so the column is one, a spine up off each
    # and a process out to each side; a vertebra at every rib, and each rib growing out of its vertebra's process.
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
        # the vertebra's body, a drum lying along the spine, and the disc on to the next
        s.tube("BoneOld", (px - ax * 1.5, py - ay * 1.5, pz - az * 1.5), (px + ax * 1.5, py + ay * 1.5, pz + az * 1.5),
               2.0, 10, radius_b=1.9)
        if k + 1 < len(points):
            s.tube("BoneWhite", (px + ax * 1.4, py + ay * 1.4, pz + az * 1.4),
                   (nxt[0] - ax * 1.4, nxt[1] - ay * 1.4, nxt[2] - az * 1.4), 1.55, 10)
        # its spine up and back, and a process out to each side
        s.tube("BoneOld", (px, py + 1.4, pz), (px - ax * 1.0, py + 4.2, pz - az * 1.0), 0.75, 7, radius_b=0.25)
        side = (-az, ax)
        sn = math.hypot(*side) or 1.0
        side = (side[0] / sn, side[1] / sn)
        for sgn in (-1, 1):
            s.tube("BoneOld", (px, py - 0.2, pz), (px + side[0] * sgn * 2.8, py - 0.5, pz + side[1] * sgn * 2.8), 0.85, 7,
                   radius_b=0.65)
        if not ribbed:
            continue
        # the ribs: from the process's end out and down to a foot in the ash either side
        # (each one bar, bent, so no seam opens at its bends; its head thin enough to start inside the process)
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
            s.bent_tube("BoneWhite", rib, radii, 7)
            fx, fz = px + side[0] * sgn * P.RIB_SPAN, pz + side[1] * sgn * P.RIB_SPAN
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
                 coping="RuinStone", coping_under=True)
    (ax, az), (bx, bz), sw = P.TERRACE_STEPS
    city.stairs(s, g, (ax, az), (bx, bz), h, 0.0, sw, mat="RuinStone", side_mat="RuinStone", step=0.85, name="the steps")
    sx, sz = P.SPAWN
    for k in range(28):
        a0, a1 = 2 * math.pi * k / 28, 2 * math.pi * (k + 1) / 28
        if k % 6 == 4:
            continue
        pts = [(sx + math.cos(a) * r, sz + math.sin(a) * r) for a, r in ((a0, 7.6), (a1, 7.6), (a1, 8.4), (a0, 8.4))]
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
    for (x0, z0, x1, z1) in ((-23.0, back + 0.8, 23.0, back + 0.8), (-22.4, front - 0.5, -22.4, back + 1.2),
                             (22.4, front - 0.5, 22.4, back + 1.2)):
        length = math.dist((x0, z0), (x1, z1))
        along_x = z0 == z1
        u = 2.0
        while u < length - 2.0:
            run = rng.uniform(2.5, 6.0)
            if rng.random() < 0.3:
                u += run
                continue
            run = min(run, length - u)  # (the last block stops at the line's end, on the terrace)
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
    pool(s, nx, 4.0, nz, 22, 0.5)


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
    old_mesa(s)
    steles(s)
    academy(s, g)
    chessboard(s)
    notebook(s)
    eye_stones(s)
    carcass(s)
    duel(s)
    apples(s)
    boulder(s, 34.0, -48.0, 2.0, 501)
    boulder(s, -30.0, 58.0, 1.6, 502)
