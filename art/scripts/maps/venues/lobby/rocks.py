"""Standing the realm's rock kit (realmrock.py, the Lobby set's props) about the Grey Realm: a kit shape placed at a
spot, turned and scaled, sunk to its foot. Every shape is solid by its own mesh (2026-11-07, the user: "make everything
solid so that it matches the structure"): until then each stood in boxes laid round its foot's outline and a core up its
middle, which its bulges and overhangs reached past (walked into) and its creases fell short of (stopped by nothing).

Everything rocky in the lobby is one of these: the ridge round the basin, the outcrops, the columns, the vistas' rocks,
the boulders and slabs in the ash, the chasms' lips, and the whole far world."""

import math
import random

import realmrock
from maps import geo2d as g2

FEET = []  # every rock's foot outline stood this build (the ground banks ash against them: ground.py)


def turn(rot, x, z):
    """(x, z) turned by rot degrees about +Y, as Roblox turns a prop placed at rot."""
    a = math.radians(rot)
    return x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)


def outline(key, x, z, rot, sc, upto=4.0):
    """The rock's foot (from the ground to `upto` studs up, in its own scale) as a convex polygon in the venue,
    counter-clockwise from above."""
    out = []
    for lx, lz in realmrock.footprint(key, upto / sc):
        dx, dz = turn(rot, lx * sc, lz * sc)
        out.append((x + dx, z + dz))
    return g2.ccw(g2.convex_hull(out))


def height(key, sc):
    return realmrock.size(key)[1] * sc


def radius(key, sc):
    """How far its foot reaches from where it stands, at most."""
    sx, _, sz = realmrock.size(key)
    return max(sx, sz) / 2 * sc


def rock(s, key, x, z, rot=0.0, sc=1.0, y=0.0, collide=True, core_h=60.0, facing=None, walls=True):
    """Stands kit shape `key` at (x, z) on ground at height y, turned rot and scaled sc; it is solid by its own mesh.
    Returns its foot's outline. (collide, core_h, facing and walls laid the boxes it stood in before 2026-11-07; they
    are kept so the venue's calls read as they did, and do nothing now.)"""
    sink = realmrock.KIT[key].get("sink", 1.0) * sc
    s.prop(key, x, z, rot % 360.0, round(sc, 3), y - sink)
    foot = outline(key, x, z, rot, sc)
    if abs(y) < 0.5:
        FEET.append(foot)
    return foot


def scatter(s, keys, cx, cz, r, count, sc, seed, y=0.0, avoid=(), arc=None, collide=False, spacing=1.0):
    """`count` kit shapes (chosen from keys) strewn over a disc of radius r (or an arc of it: (from, to) radians),
    each scaled within sc (lo, hi), smaller towards the disc's edge; clear of `avoid` circles (x, z, r)."""
    rng = random.Random(seed)
    placed, tries = [], 0
    while len(placed) < count and tries < count * 25:
        tries += 1
        a = rng.uniform(*arc) if arc else rng.uniform(0, math.tau)
        d = r * math.sqrt(rng.random())
        px, pz = cx + math.cos(a) * d, cz + math.sin(a) * d
        k = rng.uniform(*sc) * (0.6 + 0.4 * (1 - d / max(r, 1e-6)))
        key = rng.choice(keys)
        rr = radius(key, k) * 0.6
        if any(math.dist((px, pz), (ax, az)) < ar + rr for ax, az, ar in avoid):
            continue
        if any(math.dist((px, pz), (qx, qz)) < (qr + rr) * spacing for qx, qz, qr in placed):
            continue
        rock(s, key, px, pz, rng.uniform(0, 360), k, y, collide=collide)
        placed.append((px, pz, rr))
    return placed
