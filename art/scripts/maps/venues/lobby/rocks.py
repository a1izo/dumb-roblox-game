"""Standing the realm's rock kit (realmrock.py, the Lobby set's props) about the Grey Realm: a kit shape placed at a
spot, turned and scaled, sunk to its foot, with colliders round its foot from the shape's own outline (so nobody
walks into rock that looks solid, and nobody stands inside it) and a core up its middle.

Everything rocky in the lobby is one of these: the ridge round the basin, the outcrops, the columns, the vistas' rocks,
the boulders and slabs in the ash, the chasms' lips, and the whole far world."""

import math
import random

import realmrock
from maps import geo2d as g2

FEET = []  # every rock's foot outline stood this build (the ground banks ash against them: ground.py)
FOOT_H = 9.0  # how high the walls round a rock's foot stand (people walk, jump and stand against them)
FOOT_T = 3.0  # how thick they are at most


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
    """Stands kit shape `key` at (x, z) on ground at height y, turned rot and scaled sc. collide: walls round its
    foot and a core up its middle (up to core_h over the ground); facing (x, z): walls only on the sides that look
    that way (a ridge rock whose back is past the basin's wall). Returns its foot's outline."""
    sink = realmrock.KIT[key].get("sink", 1.0) * sc
    s.prop(key, x, z, rot % 360.0, round(sc, 3), y - sink)
    foot = outline(key, x, z, rot, sc)
    if abs(y) < 0.5:
        FEET.append(foot)
    if collide:
        # (up to its top as seen, never past it: what stands on a flat-topped rock stands on its core)
        h = min(height(key, sc) - sink, core_h)
        cx, cz = g2.centroid(foot)
        inner = min(g2.dist_to_poly_edge(foot, (cx, cz)), radius(key, sc)) * 0.9
        if inner > 0.6:
            s.collider((cx, y + h / 2 - 0.5, cz), (inner * 1.41, h + 1.0, inner * 1.41), rot % 90.0, True, "RockGrey")
        if walls:
            foot_walls(s, foot, y, facing)
    return foot


def foot_walls(s, poly, y, facing=None):
    """Solid slabs along a rock foot's outline, set in from it, so nobody stands inside the rock where it looks
    solid. facing (x, z): only the sides that face that way."""
    cx, cz = g2.centroid(poly)
    reach = max(math.dist((cx, cz), p) for p in poly)
    if reach < 2.2:
        s.collider((cx, y + FOOT_H / 2 - 0.5, cz), (reach * 1.3, FOOT_H + 1.0, reach * 1.3), 0.0, True, "RockGrey")
        return
    t = min(FOOT_T, reach * 0.5)
    for k in range(len(poly)):
        a, b = poly[k], poly[(k + 1) % len(poly)]
        length = math.dist(a, b)
        if length < 0.3:
            continue
        nx, nz = (b[1] - a[1]) / length, -(b[0] - a[0]) / length
        mx, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        if nx * (mx - cx) + nz * (mz - cz) < 0:
            nx, nz = -nx, -nz
        if facing is not None and nx * facing[0] + nz * facing[1] < -0.2:
            continue
        inset = 0.25 + t / 2
        rot = math.degrees(math.atan2(-(b[1] - a[1]), b[0] - a[0]))
        s.collider((mx - nx * inset, y + FOOT_H / 2 - 0.5, mz - nz * inset), (length + 0.4, FOOT_H + 1.0, t), rot, True,
                   "RockGrey")


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
