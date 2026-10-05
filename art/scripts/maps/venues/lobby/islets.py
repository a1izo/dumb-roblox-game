"""The two islets and the old bridges to them. West: the Spire Ascent, ten checkpoints climbing a
spiral of floating stones round a tall twisted spire. North-east: the rune courtyard, nine tiles in a
broken ruin. Each islet is a small floating island with its own cliffs and hanging roots; its
invisible wall is open only where the bridge arrives.

The game builds the mini-games' own objects (the rune tiles, the checkpoint flags, the prompts) at
the anchors written here."""

import math
import random

from maps import city
from maps import geo2d as g2
from maps.venues.lobby import landmarks
from maps.venues.lobby import plan as P
from maps.venues.lobby.terrain import blade, cliff, column, floating_rock, islet_poly, needle_field, rock, wall


def deck(s, g, a, b, seed):
    """An old stone bridge from a to b: flagstones on a thick slab, broken parapets, piers going down
    into the fog; invisible rails the length of both sides (nobody falls off a bridge)."""
    rng = random.Random(seed)
    length = math.dist(a, b)
    ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
    rot = math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    w = P.BRIDGE_W
    poly = g2.rect(mid[0], mid[1], length, w, rot)
    g.add(poly, "RuinFlag", 0.0, 0, "plaza")
    city.floor(s, poly, 0.0, 1.6, "RuinStone")
    s.box("RuinStone", (mid[0], -1.6, mid[1]), (length, 3.2, w + 1.4), rot, skip=("+y",))
    s.box("RuinStone", (mid[0], -4.0, mid[1]), (length * 0.96, 1.6, w - 3.0), rot, skip=("+y",))
    side = (-uz, ux)
    # The parapets: low walls along both sides, in broken runs (visual); a rail all along (invisible).
    for sgn in (-1, 1):
        off = sgn * (w / 2 + 0.2)
        u = rng.uniform(0.0, 4.0)
        while u < length - 2.0:
            run = rng.uniform(3.0, 11.0)
            if rng.random() < 0.28:
                u += rng.uniform(4.0, 9.0)  # a gap where the parapet has fallen
                continue
            run = min(run, length - 1.0 - u)
            h = rng.uniform(1.2, 3.4)
            cx = a[0] + ux * (u + run / 2) + side[0] * off
            cz = a[1] + uz * (u + run / 2) + side[1] * off
            s.box("RuinStone", (cx, h / 2, cz), (run, h, 1.0), rot, skip=("-y",))
            u += run + rng.uniform(0.0, 1.5)
        s.collider((mid[0] + side[0] * off, 3.0, mid[1] + side[1] * off), (length, 6.0, 0.6), rot, False, None)
    # Piers: tall tapering stone legs down into the fog, now and then a block fallen on the deck.
    for q in range(1, int(length // 32) + 1):
        t = q * 32.0
        px, pz = a[0] + ux * t, a[1] + uz * t
        s.lathe("RuinStone", (px, -80.0, pz), [(0.0, 0.0), (3.4, 6.0), (4.6, 70.0), (5.2, 78.0), (0.0, 78.0)], 4,
                caps=(False, False))
        if rng.random() < 0.6:
            s.box("RuinStone", (px + side[0] * rng.uniform(-3, 3), 0.5, pz + side[1] * rng.uniform(-3, 3)),
                  (rng.uniform(1.2, 2.2), 1.0, rng.uniform(1.2, 2.2)), rng.uniform(0, 90))


def islet_ground(s, g, c, r, seed, bridge_end, wall_h, plate=26.0, roots=16):
    """A small floating island: ash ground, cliffs and roots, an invisible wall open at the bridge."""
    poly = islet_poly(c, r, seed)
    for piece in g2.convex_pieces(poly):
        g.add(piece, "Ash", 0.0, 0, "plaza")
        city.floor(s, piece, 0.0, 1.0, "Ash")
    cliff(s, poly, seed * 7, plate, centre=c, roots=roots, root_len=(10.0, 55.0))
    wall(s, g2.ccw(poly), wall_h, gaps=[bridge_end], y=wall_h / 2 - 2.0)
    return poly


# The rune courtyard -----------------------------------------------------------------------------------------


def runes(s, g):
    c = P.RUNE_CENTER
    poly = islet_ground(s, g, c, P.ISLET_RUNE[2], 55, P.BRIDGE_RUNE[1], 40.0, plate=24.0, roots=14)
    landmarks.flag_disc(s, g, c, 33.0, 57, name="the rune courtyard", broken=0.05)
    # The slab the nine tiles lie on (the game builds the tiles themselves, lit one by one).
    pitch = P.RUNE_TILE + P.RUNE_GAP
    span = pitch * 3 + 1.0
    s.box("RuinStone", (c[0], 0.3, c[1]), (span, 0.6, span), collide=True)
    s.box("BlackTrim", (c[0], 0.62, c[1]), (span - 0.6, 0.04, span - 0.6))
    s.anchor("runeCenter", c[0], 0.0, c[1], 0.0)
    k = 0
    for j in (-1, 0, 1):
        for i in (-1, 0, 1):
            k += 1
            s.anchor(f"rune{k}", c[0] + i * pitch, 0.6, c[1] + j * pitch, 0.0, w=P.RUNE_TILE, h=P.RUNE_TILE)
    # Where the bridge arrives: the stepping spot for starting a run.
    bx, bz = P.BRIDGE_RUNE[1]
    d = math.hypot(bx - c[0], bz - c[1])
    ux, uz = (bx - c[0]) / d, (bz - c[1]) / d
    sx, sz = c[0] + ux * 26.0, c[1] + uz * 26.0
    s.anchor("runeStart", sx, 0.0, sz, P.rot_towards((sx, sz), c))
    s.prop("BoneBrazier", sx + uz * 4.5, sz - ux * 4.5, 0.0, 1.0)
    s.prop("BoneBrazier", sx - uz * 4.5, sz + ux * 4.5, 0.0, 1.0)
    # A ring of broken pillars round the slab, the far side whole; an obelisk with cold glyphs behind it.
    rng = random.Random(58)
    for q in range(12):
        a = math.tau * q / 12 + 0.2
        px, pz = c[0] + math.cos(a) * 30.0, c[1] + math.sin(a) * 30.0
        if math.dist((px, pz), (sx, sz)) < 14.0 or not g2.contains(poly, (px, pz)):
            continue
        landmarks.pillar(s, px, pz, rng.choice((5.0, 8.0, 12.0, 15.5)), rng, whole=(q % 4 == 0))
    ox, oz = c[0] - ux * 31.0, c[1] - uz * 31.0
    orot = P.rot_towards((ox, oz), c)
    fx, fz = P.facing(orot)
    s.box("RuinStone", (ox, 0.5, oz), (9.0, 1.0, 5.0), orot, collide=True)
    s.box("RuinStone", (ox, 12.5, oz), (5.0, 23.0, 3.0), orot, collide=True, skip=("-y",))
    for gy in (6.0, 12.0, 18.0):
        s.box("RelicGlow", (ox + fx * 1.6, gy, oz + fz * 1.6), (0.4, 2.4, 0.2), orot)
    s.box("RuinStone", (ox, 25.0, oz), (3.4, 3.0, 2.6), orot)
    needle_field(s, c[0], c[1], 36.0, 14, 5.0, 13.0, 59, avoid=[(c[0], c[1], 24.0), (sx, sz, 12.0)])


# The Spire Ascent -------------------------------------------------------------------------------------------


def pk_platforms():
    """(x, y_top, z, width, checkpoint number or 0) for each stone of the climb, bottom to top."""
    cx, cz = P.PK_CENTER
    bx, bz = P.BRIDGE_PARKOUR[1]
    a0 = math.atan2(bz - cz, bx - cx) + 0.5
    n = 40
    out = []
    for i in range(n):
        u = i / (n - 1)
        ang = a0 + i * 0.40
        rr = 23.0 + 3.0 * math.sin(i * 0.8)
        y = 2.4 + u * (P.PK_TOP - 2.4)
        check = (i + 1) // 4 if (i + 1) % 4 == 0 else 0
        w = 9.0 if check else 6.4 - 1.9 * u
        out.append((cx + math.cos(ang) * rr, y, cz + math.sin(ang) * rr, w, check))
    return out


def parkour(s, g):
    c = P.PK_CENTER
    poly = islet_ground(s, g, c, P.ISLET_PARKOUR[2], 65, P.BRIDGE_PARKOUR[1], 170.0, plate=30.0, roots=16)
    landmarks.flag_disc(s, g, c, 15.0, 67, name="the foot of the spire", broken=0.05)
    # The spire the stones climb round: twisted, fluted, broken off at the top.
    column(s, c[0], c[1], 9.0, P.PK_TOP + 14.0, 68, twist=2.4, sides=16, tiers=22, collide=True)
    s.anchor("pkCenter", c[0], 0.0, c[1], 0.0)
    bx, bz = P.BRIDGE_PARKOUR[1]
    d = math.hypot(bx - c[0], bz - c[1])
    ux, uz = (bx - c[0]) / d, (bz - c[1]) / d
    sx, sz = c[0] + ux * 24.0, c[1] + uz * 24.0
    s.anchor("pkStart", sx, 0.0, sz, P.rot_towards((sx, sz), c))
    s.prop("BoneBrazier", sx + uz * 4.5, sz - ux * 4.5, 0.0, 1.0)
    s.prop("BoneBrazier", sx - uz * 4.5, sz + ux * 4.5, 0.0, 1.0)
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
    needle_field(s, c[0], c[1], 34.0, 18, 5.0, 14.0, 70, avoid=[(c[0], c[1], 17.0), (sx, sz, 11.0)])
    for q in range(5):
        a = rng.uniform(0, math.tau)
        d2 = rng.uniform(26.0, 33.0)
        rock(s, c[0] + math.cos(a) * d2, c[1] + math.sin(a) * d2, rng.uniform(2.5, 4.0), rng.uniform(3.0, 8.0), 710 + q,
             collide=False)
    return poly


def build(s, g):
    deck(s, g, P.BRIDGE_RUNE[0], P.BRIDGE_RUNE[1], 301)
    deck(s, g, P.BRIDGE_PARKOUR[0], P.BRIDGE_PARKOUR[1], 302)
    runes(s, g)
    parkour(s, g)
