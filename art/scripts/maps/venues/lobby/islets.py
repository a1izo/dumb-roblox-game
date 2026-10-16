"""The two plateaus and the old stone causeways to them. West: the Spire Ascent, ten checkpoints climbing a
spiral of floating stones round a tall twisted spire. North-east: the rune courtyard, nine tiles in a broken
ruin. Each plateau is a raised table of rock standing out on the plain, with its own invisible wall (open only
where the causeway arrives); each causeway runs from the basin's ridge over a deep chasm and up a short
flight of steps onto the plateau.

The game builds the mini-games' own objects (the rune tiles, the checkpoint flags, the prompts) at the
anchors written here."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.venues.lobby import landmarks
from maps.venues.lobby import plan as P
from maps.venues.lobby.terrain import blade, column, floating_rock, islet_poly, needle_field, plateau_sides, rock, wall

H = P.PLATEAU_H


PARAPET_T = 1.0  # a parapet's thickness
PARAPET_LOW = 2.4  # the lowest a parapet ever stands over the deck (a breach), so it always reads as a wall
CAP = 13.5  # how high over the deck the parapets' collision reaches: an R6 body's legs do not collide, so its torso
# clears a wall at the top of a jump (about 10.4 over the deck): this is over that, so a jump never clears it
LIP = 2.5  # how far the cap's lip leans in over the deck


def parapet(s, a, ux, uz, rot, off, u0, u1, rng):
    """One side's parapet from u0 to u1 along the causeway: a continuous wall of old blocks, its top worn
    uneven, a coping slab on the whole runs and a squat pier now and then; where it has broken down (a breach)
    it is lower, never open. Visual only: its collision is laid along it by the caller."""
    side = (-uz, ux)

    def at(u, y):
        return (a[0] + ux * u + side[0] * off, y, a[1] + uz * u + side[1] * off)

    u = u0
    next_pier = u0 + rng.uniform(7.0, 11.0)
    while u < u1 - 0.05:
        run = min(rng.uniform(2.8, 7.0), u1 - u)
        if u1 - (u + run) < 1.6:
            run = u1 - u  # no sliver at the end
        breach = rng.random() < 0.18
        h = rng.uniform(PARAPET_LOW, 2.6) if breach else rng.uniform(2.9, 3.4)
        x, _, z = at(u + run / 2, 0.0)
        s.box("RuinStone", (x, h / 2, z), (run, h, PARAPET_T), rot, skip=("-y",))
        if not breach and run > 1.6:
            cut = rng.uniform(0.1, 0.3)
            s.box("RuinStone", (x, h + 0.17, z), (run - cut, 0.34, PARAPET_T + 0.3), rot, skip=("-y",))
        elif breach:
            # A broken top: a chunk still standing on it, off-centre.
            du = rng.uniform(-run / 2 + 0.4, run / 2 - 0.4) if run > 1.2 else 0.0
            bh = rng.uniform(0.3, 0.7)
            bx, _, bz = at(u + run / 2 + du, 0.0)
            s.box("RuinStone", (bx, h + bh / 2, bz), (rng.uniform(0.6, 1.1), bh, PARAPET_T * 0.8), rot + rng.uniform(-6, 6),
                  skip=("-y",))
        if u + run >= next_pier and u + run < u1 - 1.0:
            px, _, pz = at(u + run, 0.0)
            ph = rng.uniform(3.6, 4.2)
            s.box("RuinStone", (px, ph / 2, pz), (1.5, ph, PARAPET_T + 0.5), rot, skip=("-y",))
            s.box("RuinStone", (px, ph + 0.2, pz), (1.8, 0.4, PARAPET_T + 0.8), rot, skip=("-y",))
            next_pier = u + run + rng.uniform(8.0, 12.0)
        u += run


def causeway(s, g, a, b, seed, chasm, name):
    """An old stone causeway from a (the basin's rim) to b (on the plateau): flagstones on a thick slab over the
    plain and across a chasm, piers down into the dark, a flight of steps up onto the plateau at the far end.
    Both sides carry a parapet that is old and broken-topped but never open, and its collision is the parapet
    itself, reaching on over a jump's height (nobody leaves a causeway: the plain beside it is not ground).
    Anchors <name>A (at the rim end) and <name>B (at the head of the steps), each facing along the way
    from there: where someone who falls into the chasm is set back (the end they came from)."""
    rng = random.Random(seed)
    length = math.dist(a, b)
    ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
    rot = math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))
    w = P.BRIDGE_W
    flat = length - P.STAIR_RUN
    foot = (a[0] + ux * flat, a[1] + uz * flat)
    mid = ((a[0] + foot[0]) / 2, (a[1] + foot[1]) / 2)
    poly = g2.rect(mid[0], mid[1], flat, w, rot)
    g.add(poly, "RuinFlag", 0.0, 0, "plaza")
    city.floor(s, poly, 0.0, 1.6, "RuinStone")
    s.box("RuinStone", (mid[0], -1.6, mid[1]), (flat, 3.2, w + 1.4), rot, skip=("+y",))
    s.box("RuinStone", (mid[0], -4.0, mid[1]), (flat * 0.96, 1.6, w - 3.0), rot, skip=("+y",))
    side = (-uz, ux)
    off_abs = w / 2 + 0.2
    # The parapets, from a little inside the basin's rim (the rim's wall leaves its gap there) to the steps'
    # foot; then along the flight, stepping up with it.
    start = -3.0
    for sgn in (-1, 1):
        off = sgn * off_abs
        parapet(s, a, ux, uz, rot, off, start, flat, rng)
        # Collision along it: the wall itself (seen in the greybox) and over it, unseen, up to CAP; it runs on
        # past the steps' foot until their own guard has begun.
        u0, u1 = start, flat + 4.5
        cu = (u0 + u1) / 2
        cx, cz = a[0] + ux * cu + side[0] * off, a[1] + uz * cu + side[1] * off
        s.collider((cx, 1.45, cz), (u1 - u0, 2.9, PARAPET_T), rot, False, "RuinStone")
        s.collider((cx, 2.9 + (CAP - 2.9) / 2, cz), (u1 - u0, CAP - 2.9, PARAPET_T), rot, False, None)
        # A lip leaning over the deck at the top of it: a body climbing the wall by wall-hops (jumping off it,
        # Roblox's trick) meets it overhead; a jump on the deck never reaches it (the head tops out near 12).
        lx = cx - side[0] * sgn * (PARAPET_T / 2 + LIP / 2)
        lz = cz - side[1] * sgn * (PARAPET_T / 2 + LIP / 2)
        s.collider((lx, CAP - 0.25, lz), (u1 - u0, 0.5, LIP), rot, False, None)
        # The flight's parapet: blocks stepping up beside the steps (their guard is CAP high too).
        steps = 6
        for k in range(steps):
            t0, t1 = k / steps, (k + 1) / steps
            top = H * t1 + 2.9
            uc = flat + P.STAIR_RUN * (t0 + t1) / 2
            x, z = a[0] + ux * uc + side[0] * off, a[1] + uz * uc + side[1] * off
            s.box("RuinStone", (x, top / 2, z), (P.STAIR_RUN / steps + 0.02, top, PARAPET_T), rot, skip=("-y",))
            s.box("RuinStone", (x, top + 0.17, z), (P.STAIR_RUN / steps - 0.1, 0.34, PARAPET_T + 0.3), rot)
    s.anchor(name + "A", a[0] + ux * 6.0, 0.0, a[1] + uz * 6.0, P.rot_towards(a, b))
    s.anchor(name + "B", b[0] - ux * 2.0, H, b[1] - uz * 2.0, P.rot_towards(b, a))
    # Piers down into the chasm, now and then a block fallen on the deck.
    for dt in (-11.0, 0.0, 11.0):
        px = chasm[0] + ux * dt
        pz = chasm[1] + uz * dt
        top = P.CHASM_DEPTH - 2.05  # (a hair under the deck: at its height the two flickered)
        s.lathe("RuinStone", (px, -P.CHASM_DEPTH + 2.0, pz), [(0.0, 0.0), (3.4, 4.0), (4.4, P.CHASM_DEPTH - 8.0),
                                                                 (4.8, top), (0.0, top)], 4,
                caps=(False, False))
    for q in range(1, int(flat // 32) + 1):
        t = q * 32.0
        if rng.random() < 0.6:
            s.box("RuinStone", (a[0] + ux * t + side[0] * rng.uniform(-3, 3), 0.5, a[1] + uz * t + side[1] * rng.uniform(-3, 3)),
                  (rng.uniform(1.2, 2.2), 1.0, rng.uniform(1.2, 2.2)), rng.uniform(0, 90))
    # The steps up onto the plateau.
    city.stairs(s, g, foot, b, 0.0, H, w, mat="RuinStone", side_mat="RuinStone", step=0.85, name="the causeway steps",
                guard=CAP)


def plateau(s, g, c, r, seed, centre_dir_pt, wall_h):
    """A raised table of rock standing out on the plain: ash on top, rock sides, an invisible wall round the
    rim open at the causeway."""
    poly = islet_poly(c, r, seed)
    for piece in g2.convex_pieces(poly):
        g.add(piece, "Ash", H, 0, "plaza")
        city.floor(s, piece, H, H + 1.0, "Ash")
    plateau_sides(s, poly, c, seed * 7, H)
    wall(s, g2.ccw(poly), wall_h, gaps=[centre_dir_pt], y=H + wall_h / 2 - 2.0)
    return poly


def edge_point(islet):
    """The plateau's nominal edge where its causeway arrives."""
    d = math.hypot(islet[0], islet[1])
    ux, uz = islet[0] / d, islet[1] / d
    return (islet[0] - ux * islet[2], islet[1] - uz * islet[2])


# The rune courtyard -----------------------------------------------------------------------------------------


def runes(s, g):
    c = P.RUNE_CENTER
    poly = plateau(s, g, c, P.ISLET_RUNE[2], 55, edge_point(P.ISLET_RUNE), 40.0)
    landmarks.flag_disc(s, g, c, 33.0, 57, name="the rune courtyard", broken=0.05, y=H + 0.04)
    # The slab the nine tiles lie on (the game builds the tiles themselves, lit one by one).
    pitch = P.RUNE_TILE + P.RUNE_GAP
    span = pitch * 3 + 1.0
    s.box("RuinStone", (c[0], H + 0.3, c[1]), (span, 0.6, span), collide=True)
    s.box("BlackTrim", (c[0], H + 0.62, c[1]), (span - 0.6, 0.04, span - 0.6))
    s.anchor("runeCenter", c[0], H, c[1], 0.0)
    k = 0
    for j in (-1, 0, 1):
        for i in (-1, 0, 1):
            k += 1
            s.anchor(f"rune{k}", c[0] + i * pitch, H + 0.6, c[1] + j * pitch, 0.0, w=P.RUNE_TILE, h=P.RUNE_TILE)
    # Where the causeway arrives: the stepping spot for starting a run.
    bx, bz = P.BRIDGE_RUNE[1]
    d = math.hypot(bx - c[0], bz - c[1])
    ux, uz = (bx - c[0]) / d, (bz - c[1]) / d
    sx, sz = c[0] + ux * 26.0, c[1] + uz * 26.0
    s.anchor("runeStart", sx, H, sz, P.rot_towards((sx, sz), c))
    s.prop("BoneBrazier", sx + uz * 4.5, sz - ux * 4.5, 0.0, 1.0, H)
    s.prop("BoneBrazier", sx - uz * 4.5, sz + ux * 4.5, 0.0, 1.0, H)
    s.light("point", (sx, H + 8.0, sz), (170, 196, 232), 26, 1.0)
    # A ring of broken pillars round the slab, the far side whole; an obelisk with cold glyphs behind it.
    rng = random.Random(58)
    for q in range(12):
        a = math.tau * q / 12 + 0.2
        px, pz = c[0] + math.cos(a) * 30.0, c[1] + math.sin(a) * 30.0
        if math.dist((px, pz), (sx, sz)) < 14.0 or not g2.contains(poly, (px, pz)):
            continue
        landmarks.pillar(s, px, pz, rng.choice((5.0, 8.0, 12.0, 15.5)), rng, whole=(q % 4 == 0), y=H)
    ox, oz = c[0] - ux * 31.0, c[1] - uz * 31.0
    orot = P.rot_towards((ox, oz), c)
    fx, fz = P.facing(orot)
    s.box("RuinStone", (ox, H + 0.5, oz), (9.0, 1.0, 5.0), orot, collide=True)
    s.box("RuinStone", (ox, H + 12.5, oz), (5.0, 23.0, 3.0), orot, collide=True, skip=("-y",))
    for gy in (6.0, 12.0, 18.0):
        s.box("RelicGlow", (ox + fx * 1.6, H + gy, oz + fz * 1.6), (0.4, 2.4, 0.2), orot)
    s.box("RuinStone", (ox, H + 25.0, oz), (3.4, 3.0, 2.6), orot)
    needle_field(s, c[0], c[1], 36.0, 14, 5.0, 13.0, 59, y=H, avoid=[(c[0], c[1], 24.0), (sx, sz, 12.0)])


# The Spire Ascent -------------------------------------------------------------------------------------------


def pk_platforms():
    """(x, y_top, z, width, checkpoint number or 0) for each stone of the climb, bottom to top (y over the
    plain: the plateau's own height is in it)."""
    cx, cz = P.PK_CENTER
    bx, bz = P.BRIDGE_PARKOUR[1]
    a0 = math.atan2(bz - cz, bx - cx) + 0.5
    n = 40
    out = []
    for i in range(n):
        u = i / (n - 1)
        ang = a0 + i * 0.40
        rr = 23.0 + 3.0 * math.sin(i * 0.8)
        y = H + 2.4 + u * (P.PK_TOP - 2.4)
        check = (i + 1) // 4 if (i + 1) % 4 == 0 else 0
        w = 9.0 if check else 6.4 - 1.9 * u
        out.append((cx + math.cos(ang) * rr, y, cz + math.sin(ang) * rr, w, check))
    return out


def parkour(s, g):
    c = P.PK_CENTER
    poly = plateau(s, g, c, P.ISLET_PARKOUR[2], 65, edge_point(P.ISLET_PARKOUR), 170.0)
    landmarks.flag_disc(s, g, c, 15.0, 67, name="the foot of the spire", broken=0.05, y=H + 0.04)
    # The spire the stones climb round: twisted, fluted, broken off at the top.
    column(s, c[0], c[1], 9.0, P.PK_TOP + 14.0, 68, twist=2.4, sides=16, tiers=22, collide=True, y=H)
    s.anchor("pkCenter", c[0], H, c[1], 0.0)
    bx, bz = P.BRIDGE_PARKOUR[1]
    d = math.hypot(bx - c[0], bz - c[1])
    ux, uz = (bx - c[0]) / d, (bz - c[1]) / d
    sx, sz = c[0] + ux * 24.0, c[1] + uz * 24.0
    s.anchor("pkStart", sx, H, sz, P.rot_towards((sx, sz), c))
    s.prop("BoneBrazier", sx + uz * 4.5, sz - ux * 4.5, 0.0, 1.0, H)
    s.prop("BoneBrazier", sx - uz * 4.5, sz + ux * 4.5, 0.0, 1.0, H)
    s.light("point", (sx, H + 8.0, sz), (170, 196, 232), 26, 1.0)
    for i, (x, y, z, w, check) in enumerate(pk_platforms()):
        r = w * 0.62
        floating_rock(s, x, y, z, r, 700 + i, depth=r * (1.1 + 0.25 * (i % 3)), sides=7,
                      top_mat="RuinFlag" if check else "RockGrey")
        s.collider((x, y - 0.6, z), (w * 0.82, 1.2, w * 0.82), (i * 37) % 90, True, "RockGrey")
        if check:
            s.anchor(f"pk{check}", x, y, z, 0.0, w=w)
    # Cold light at the top: the finish stone has a small blade standing in it.
    x, y, z, w, check = pk_platforms()[-1]
    blade(s, x, y - 0.4, z, 1.1, 7.0, 0.3, rot=0.0)
    s.light("point", (x, y + 5.0, z), (170, 196, 232), 26, 1.0)
    rng = random.Random(69)
    needle_field(s, c[0], c[1], 34.0, 18, 5.0, 14.0, 70, y=H, avoid=[(c[0], c[1], 17.0), (sx, sz, 11.0)])
    for q in range(5):
        a = rng.uniform(0, math.tau)
        d2 = rng.uniform(26.0, 33.0)
        rock(s, c[0] + math.cos(a) * d2, c[1] + math.sin(a) * d2, rng.uniform(2.5, 4.0), rng.uniform(3.0, 8.0), 710 + q,
             y=H, collide=False)
    return poly


def build(s, g):
    causeway(s, g, P.BRIDGE_RUNE[0], P.BRIDGE_RUNE[1], 301, P.CHASMS[0], "bridgeRune")
    causeway(s, g, P.BRIDGE_PARKOUR[0], P.BRIDGE_PARKOUR[1], 302, P.CHASMS[1], "bridgeParkour")
    runes(s, g)
    parkour(s, g)
