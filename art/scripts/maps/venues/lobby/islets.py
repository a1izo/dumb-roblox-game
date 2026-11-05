"""The two plateaus and the old stone causeways to them. West: the Chain Heap (2026-11-04), a mountain of junk with a
colossal chain hanging into it out of the sky; the Spire Ascent's ten checkpoints climb round the chain on stones and
broken gear wheels hanging in the air. North-east: a garden of pale shards round a flagged floor (the rune courtyard
stood here until 2026-11-05). Each plateau is a raised table of rock standing out on the plain, with its own invisible
wall (open only where the causeway arrives); each causeway runs from the basin's ridge over a deep chasm and up a short
flight of steps onto the plateau.

The game builds the Spire Ascent's own objects (the checkpoint flags, the prompts) at the anchors written here."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.venues.lobby import landmarks, rocks
from maps.venues.lobby import plan as P
from maps.venues.lobby.terrain import floating_rock, islet_poly, plateau_sides, wall

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


def plateau(s, g, c, r, seed, arrive, wall_h):
    """A raised table of rock standing out on the plain: ash on top, rock sides, an invisible wall round the
    rim open at the causeway. arrive: the head of the causeway's flight; the rim is drawn in to it there, a cove
    the flight climbs in front of (the flight ends 7 studs inside the plateau's nominal edge, and ran on into its
    rock: the table's top and sides lay over its upper half, a 4-stud step up out of it)."""
    poly = islet_poly(c, r, seed)
    toward = math.atan2(arrive[1] - c[1], arrive[0] - c[0])
    inner = math.dist(c, arrive) - 0.3
    cove = []
    for x, z in poly:
        a = math.atan2(z - c[1], x - c[0])
        d = math.hypot(x - c[0], z - c[1])
        # (within 30 degrees of the way in: the cove's last corners stand at least 7 studs either side of it, clear
        # of the flight's parapets)
        if abs(math.atan2(math.sin(a - toward), math.cos(a - toward))) < math.radians(30.0) and d > inner:
            x, z = c[0] + (x - c[0]) * inner / d, c[1] + (z - c[1]) * inner / d
        cove.append((x, z))
    poly = cove
    for piece in g2.convex_pieces(poly):
        g.add(piece, "RealmAsh", H, 0, "plaza")
        city.floor(s, piece, H, H + 1.0, "RealmAsh")
    plateau_sides(s, poly, c, seed * 7, H)
    wall(s, g2.ccw(poly), wall_h, gaps=[arrive], y=H + wall_h / 2 - 2.0, reach=1.5)
    return poly


# The shard garden ------------------------------------------------------------------------------------------


def shards(s, g):
    """The north-east plateau: a flagged floor in a garden of pale shards (the rune courtyard's tiles, the slab under
    them and its start were removed with the game, 2026-11-05)."""
    c = P.ISLET_SHARDS[:2]
    poly = plateau(s, g, c, P.ISLET_SHARDS[2], 55, P.BRIDGE_SHARDS[1], 40.0)
    landmarks.flag_disc(s, g, c, 32.0, 57, name="the shard garden", broken=0.05, y=H + 0.04, within=poly)
    # Where the causeway arrives: two shards either side of it.
    bx, bz = P.BRIDGE_SHARDS[1]
    d = math.hypot(bx - c[0], bz - c[1])
    ux, uz = (bx - c[0]) / d, (bz - c[1]) / d
    sx, sz = c[0] + ux * 26.0, c[1] + uz * 26.0
    rng = random.Random(58)
    for side in (-1, 1):
        rocks.rock(s, "RealmShardsA", sx + uz * side * 6.5, sz - ux * side * 6.5, rng.uniform(0, 360), 0.42, y=H)
    # The shard garden round the floor's middle: pale clusters, the tallest at its far side.
    for q in range(11):
        a = math.tau * q / 11 + 0.25
        r = rng.uniform(25.0, 33.0)
        px, pz = c[0] + math.cos(a) * r, c[1] + math.sin(a) * r
        if math.dist((px, pz), (sx, sz)) < 13.0 or not g2.contains(poly, (px, pz)):
            continue
        key, sc = (("RealmShardsA", rng.uniform(0.45, 0.85)) if q % 3 else ("RealmShardsC", rng.uniform(1.6, 2.6)))
        rocks.rock(s, key, px, pz, rng.uniform(0, 360), sc, y=H)
    ox, oz = c[0] - ux * 30.0, c[1] - uz * 30.0
    rocks.rock(s, "RealmShardsB", ox, oz, rng.uniform(0, 360), 0.55, y=H)
    s.light("point", (c[0], H + 14.0, c[1]), (170, 196, 232), 34, 0.8)


# The Spire Ascent, round the Chain Heap ----------------------------------------------------------------------


CHAIN_TOP = 170.0  # how high over the plateau the great chain is seen to hang from (the haze takes it before)


def chain_heap(s, c):
    """The Chain Heap on its plateau: a mountain of junk (rubble, broken gear wheels, piles of giant chain) and, hanging
    into it out of the sky, a colossal chain; solid up its length (the climb's stones hang round it)."""
    s.prop("GreatChain", c[0], c[1], 0.0, 1.0, H - 3.0)
    y = 0.0
    k = 0
    while y < CHAIN_TOP:
        s.collider((c[0], H + y + 4.0, c[1]), (4.2, 8.0, 4.2), 45.0 * (k % 2), True, "DarkMetal")
        y += 8.0
        k += 1
    rng = random.Random(67)
    avoid = [(c[0], c[1], 4.5)]
    for k in range(4):
        a = math.tau * k / 4 + rng.uniform(-0.25, 0.25)
        d = 8.5 if k % 2 else 7.0
        x, z = c[0] + math.cos(a) * d, c[1] + math.sin(a) * d
        if k % 2:
            # (the gear stands on its edge across the way out from the chain)
            landmarks.gear(s, x, z, math.degrees(-a), 1.0, H - 1.2)
        else:
            landmarks.chain_pile(s, x, z, rng.uniform(0, 360), 1.1, H)
        avoid.append((x, z, 5.0))
    rocks.scatter(s, ("RealmBoulderA", "RealmBoulderB", "RealmSlab"), c[0], c[1], 11.0, 16, (0.9, 1.5), 66, y=H,
                  collide=True, spacing=0.55, avoid=avoid)


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
    poly = plateau(s, g, c, P.ISLET_PARKOUR[2], 65, P.BRIDGE_PARKOUR[1], 170.0)
    chain_heap(s, c)
    s.anchor("pkCenter", c[0], H, c[1], 0.0)
    bx, bz = P.BRIDGE_PARKOUR[1]
    d = math.hypot(bx - c[0], bz - c[1])
    ux, uz = (bx - c[0]) / d, (bz - c[1]) / d
    sx, sz = c[0] + ux * 24.0, c[1] + uz * 24.0
    landmarks.flag_disc(s, g, (sx, sz), 6.5, 68, name="the foot of the climb", broken=0.05, y=H + 0.04, loose=6,
                        within=poly)
    s.anchor("pkStart", sx, H, sz, P.rot_towards((sx, sz), c))
    s.light("point", (sx, H + 8.0, sz), (170, 196, 232), 26, 1.0)
    # The climb: stones hanging in the air round the chain, a broken gear wheel at each checkpoint.
    for i, (x, y, z, w, check) in enumerate(pk_platforms()):
        if check:
            turn = (i * 41) % 360
            s.prop("GearPlatform", x, z, turn, round(w / 9.0, 3), y - 1.0)
            # (inside the gear's round, whichever way it is turned)
            s.collider((x, y - 0.6, z), (w * 0.66, 1.2, w * 0.66), turn, True, "DarkMetal")
        else:
            r = w * 0.62
            floating_rock(s, x, y, z, r, 700 + i, depth=r * (1.1 + 0.25 * (i % 3)), sides=7, top_mat="RockGrey")
            s.collider((x, y - 0.6, z), (w * 0.82, 1.2, w * 0.82), (i * 37) % 90, True, "RockGrey")
        if check:
            s.anchor(f"pk{check}", x, y, z, 0.0, w=w)
    # The finish: a cage lantern hangs over the last stone, burning cold.
    x, y, z, w, check = pk_platforms()[-1]
    s.prop("HangingCage", x, z, 0.0, 1.0, y + 12.0 - landmarks.HANGING_CAGE_DROP)
    s.light("point", (x, y + 4.0, z), landmarks.LANTERN, 26, 1.0)
    rng = random.Random(69)
    for q in range(7):
        a = rng.uniform(0, math.tau)
        d2 = rng.uniform(27.0, 34.0)
        px, pz = c[0] + math.cos(a) * d2, c[1] + math.sin(a) * d2
        if math.dist((px, pz), (sx, sz)) < 10.0:
            continue
        key = rng.choice(("RealmBoulderA", "RealmBoulderB", "RealmCragB"))
        rocks.rock(s, key, px, pz, rng.uniform(0, 360), rng.uniform(0.5, 1.1) if key != "RealmCragB" else 0.35, y=H,
                   collide=False)
    return poly


def build(s, g):
    causeway(s, g, P.BRIDGE_SHARDS[0], P.BRIDGE_SHARDS[1], 301, P.CHASMS[0], "bridgeShards")
    causeway(s, g, P.BRIDGE_PARKOUR[0], P.BRIDGE_PARKOUR[1], 302, P.CHASMS[1], "bridgeParkour")
    shards(s, g)
    parkour(s, g)
