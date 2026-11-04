"""The Grey Realm's rock kit: the shapes the lobby is built from (spires, crags, twisted columns, mesas, boulders,
needles, slabs, arches and the rocks that float), each made once and stood about the realm many times, turned and
scaled (props_realm.py registers them as the Lobby set's props; the lobby's venue places them).

Every shape is a lofted surface: rings stacked up an axis that leans and curves, each ring an irregular outline. The
rock's character comes from four things laid over it, all from seeded noise so a shape is the same every time it is
made: strata (hard bands standing proud of softer ones that weathered back, so ledges run round the rock), joints
(the vertical cracks columnar rock splits along), lumps (fractal noise at the scale of a stud or two) and its top
(snapped off on a slant, worn to a point, flat under ash, or domed). The faces are shaded smooth with the creases kept
sharp, and they wear the realm's tiling rock scan (maps/scanlib, RockGrey) laid round the axis in bands, one band to a
stratum, so the seams hide in the ledges: a rock gets the map surfaces' density (73 px to the stud) instead of a bake
of its own.

The same function gives a shape to the props builder (in Blender) and its footprint to the venue (the outline its
colliders follow), so they always agree. Coordinates are the builder's: studs, z up, the shape's foot at z = 0 and the
middle of its bounding box over the origin (as build_props grounds a prop)."""

import math
import random

from mathutils import Matrix, Vector, noise

TILE = 14.0  # studs one repeat of the rock scan covers (scanlib's RockGrey)


def _n(x, y, z):
    return noise.noise(Vector((x, y, z)), noise_basis="PERLIN_NEW")


def _fbm(x, y, z, octaves=4):
    total, amp, freq = 0.0, 1.0, 1.0
    for _ in range(octaves):
        total += amp * _n(x * freq, y * freq, z * freq)
        amp *= 0.5
        freq *= 2.03
    return total


def _ridge(x, y, z):
    """Thin dark lines (a crack's trace): 1 on the line, falling off fast."""
    return (1.0 - min(1.0, abs(_n(x, y, z)) * 3.2)) ** 3


def _smooth(a, b, x):
    if b == a:
        return 1.0 if x >= b else 0.0
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


# A shape's recipe. kind: "pillar" (everything lofted: spires, crags, columns, mesas, boulders, needles, slabs),
# "arch" or "floater". The pillar's numbers:
#   h, r           its height and its radius at the foot (before the profile)
#   profile        [(t, k)]: the radius along the height (t 0 foot .. 1 top), as a share of r
#   lobes          how irregular its outline is (0 round)
#   squash         its outline's depth against its width (1 round)
#   lean, curve    how far its top stands off (x, y in studs) and how the lean grows (1 straight, 2 curving over)
#   twist          turns its outline makes from foot to top (a twisted column)
#   flutes, flute  grooves running up it (how many, how deep as a share of the radius)
#   strata         (thickness, how far the hard bands stand out as a share of the radius, how much they waver)
#   joints         (how many vertical cracks round it, how deep as a share of the radius)
#   lumps          (size in studs, depth in studs)
#   top            "point", "broken" (snapped on a slant), "flat" (mesa) or "dome"
#   seg, rings     the outline's corners, and how many rings at most between the strata's own
#   sink           how far its foot goes under the ground
#   only_far       made only to give its far variant (the shape itself is never stood, so it is not a prop)
KIT = {
    # The ridge round the basin: broad masses of layered rock, broken off on top.
    "RealmCragA": dict(kind="pillar", seed=11, h=26.0, r=11.0, profile=[(0, 1.12), (0.08, 1.0), (0.55, 0.86), (0.85, 0.66),
                                                                        (1.0, 0.42)],
                       lobes=0.22, squash=0.78, lean=(1.4, -0.6), curve=1.2, strata=(3.2, 0.13, 0.5), cuts=4,
                       joints=(7, 0.13), lumps=(2.4, 0.35), top="broken", seg=36, rings=16),
    "RealmCragB": dict(kind="pillar", seed=12, h=18.0, r=12.5, profile=[(0, 1.1), (0.1, 1.0), (0.6, 0.9), (0.9, 0.72),
                                                                        (1.0, 0.55)],
                       lobes=0.26, squash=0.7, lean=(-1.0, 0.8), curve=1.0, strata=(2.8, 0.14, 0.6), cuts=5,
                       joints=(8, 0.14), lumps=(2.2, 0.35), top="broken", seg=36, rings=14),
    "RealmCragC": dict(kind="pillar", seed=13, h=38.0, r=9.5, profile=[(0, 1.18), (0.07, 1.0), (0.4, 0.84), (0.75, 0.62),
                                                                       (1.0, 0.36)],
                       lobes=0.2, squash=0.82, lean=(2.2, 1.0), curve=1.4, strata=(3.8, 0.13, 0.45), cuts=4,
                       joints=(6, 0.14), lumps=(2.6, 0.35), top="broken", seg=34, rings=18),
    # Tall spires: worn to points, leaning, curving.
    "RealmSpireA": dict(kind="pillar", seed=21, h=64.0, r=7.0, profile=[(0, 1.25), (0.06, 1.0), (0.3, 0.8), (0.6, 0.52),
                                                                        (0.85, 0.28), (1.0, 0.08)],
                        lobes=0.18, squash=0.85, lean=(4.0, 1.5), curve=1.8, strata=(4.2, 0.12, 0.4), cuts=3,
                        joints=(5, 0.12), lumps=(2.4, 0.3), top="point", seg=30, rings=22),
    # The realm's own: a fluted column twisting as it rises, its top snapped off.
    "RealmColumn": dict(kind="pillar", seed=31, h=70.0, r=6.2, profile=[(0, 1.55), (0.05, 1.18), (0.14, 1.0), (0.5, 0.9),
                                                                        (0.8, 0.82), (1.0, 0.74)],
                        lobes=0.06, squash=1.0, lean=(1.2, 0.0), curve=1.0, twist=0.55, flutes=7, flute=0.2,
                        strata=(5.5, 0.04, 0.3), joints=(0, 0.0), lumps=(2.6, 0.25), top="broken", seg=56, rings=40),
    # A great flat-topped mass, ash lying on it (the far plain's mesas).
    "RealmMesa": dict(kind="pillar", seed=41, h=30.0, r=34.0, profile=[(0, 1.12), (0.12, 1.0), (0.7, 0.93), (0.92, 0.88),
                                                                       (1.0, 0.82)],
                      lobes=0.2, squash=0.85, lean=(0.0, 0.0), curve=1.0, strata=(3.0, 0.05, 0.5), cuts=6,
                      joints=(12, 0.04), lumps=(4.0, 0.5), top="flat", seg=64, rings=24),
    # Boulders, rounded erratics left lying about.
    "RealmBoulderA": dict(kind="pillar", seed=51, h=5.2, r=4.2, profile=[(0, 0.86), (0.2, 1.0), (0.55, 0.92), (0.85, 0.62),
                                                                         (1.0, 0.0)],
                          lobes=0.22, squash=0.78, lean=(0.4, 0.0), curve=1.0, strata=(1.6, 0.03, 0.8),
                          joints=(3, 0.04), lumps=(1.6, 0.28), top="dome", seg=28, rings=12, sink=0.6),
    "RealmBoulderB": dict(kind="pillar", seed=52, h=3.6, r=3.4, profile=[(0, 0.9), (0.25, 1.0), (0.6, 0.86), (0.9, 0.5),
                                                                         (1.0, 0.0)],
                          lobes=0.3, squash=0.66, lean=(-0.3, 0.2), curve=1.0, strata=(1.2, 0.04, 0.8),
                          joints=(2, 0.05), lumps=(1.2, 0.24), top="dome", seg=26, rings=10, sink=0.5),
    # Needles: thin spikes of rock in fields, many to a field (light).
    "RealmNeedleA": dict(kind="pillar", dust=False, only_far=True, seed=61, h=16.0, r=1.1, profile=[(0, 1.3), (0.08, 1.0), (0.5, 0.62), (0.85, 0.25),
                                                                         (1.0, 0.0)],
                         lobes=0.25, squash=0.8, lean=(1.2, 0.4), curve=1.6, strata=(2.2, 0.08, 0.6),
                         joints=(3, 0.08), lumps=(0.9, 0.08), top="point", seg=10, rings=12),
    "RealmNeedleB": dict(kind="pillar", dust=False, only_far=True, seed=62, h=24.0, r=1.5, profile=[(0, 1.35), (0.06, 1.0), (0.45, 0.66), (0.8, 0.3),
                                                                         (1.0, 0.0)],
                         lobes=0.3, squash=0.75, lean=(-1.6, 1.2), curve=2.0, strata=(2.6, 0.08, 0.6),
                         joints=(3, 0.08), lumps=(1.1, 0.1), top="point", seg=10, rings=14),
    # Flat stones breaking through the ash, low enough to step over or onto.
    "RealmSlab": dict(kind="pillar", dust=False, seed=71, h=0.9, r=2.4, profile=[(0, 1.0), (0.6, 0.98), (1.0, 0.86)],
                      lobes=0.32, squash=0.62, lean=(0.0, 0.0), curve=1.0, strata=(0.0, 0.0, 0.0),
                      joints=(3, 0.05), lumps=(0.9, 0.08), top="flat", seg=20, rings=4, sink=0.5),
    # A second column, taller and slimmer, turning the other way (the two that frame the first view are one each).
    "RealmColumnB": dict(kind="pillar", seed=32, h=72.0, r=5.4, profile=[(0, 1.6), (0.05, 1.2), (0.15, 1.0), (0.55, 0.88),
                                                                         (0.85, 0.8), (1.0, 0.7)],
                         lobes=0.08, squash=0.94, lean=(-1.6, 0.8), curve=1.3, twist=-0.7, flutes=6, flute=0.22,
                         strata=(6.0, 0.04, 0.3), joints=(0, 0.0), lumps=(2.4, 0.25), top="broken", seg=52, rings=40),
    # Rocks that hang in the air: a level top (the Spire Ascent's stones are stood on), the body narrowing under it
    # to a point, ash on top; the checkpoints' stones carry old flagstones instead.
    "RealmFloaterA": dict(kind="pillar", hang=True, seed=81, h=8.0, r=5.0, profile=[(0, 1.0), (0.1, 1.05), (0.32, 0.88),
                                                                                    (0.6, 0.58), (0.85, 0.28), (1.0, 0.0)],
                          lobes=0.2, squash=0.9, lean=(0.8, -0.4), curve=1.6, strata=(1.4, 0.06, 0.6), cuts=2,
                          joints=(3, 0.06), lumps=(1.4, 0.18), top="point", seg=28, rings=12, sink=0.0, rise=0.08),
    "RealmFloaterB": dict(kind="pillar", hang=True, seed=82, h=11.0, r=5.0, profile=[(0, 1.0), (0.08, 1.04), (0.3, 0.9),
                                                                                     (0.55, 0.64), (0.8, 0.34), (1.0, 0.0)],
                          lobes=0.24, squash=0.86, lean=(-1.0, 0.9), curve=2.0, strata=(1.6, 0.07, 0.6), cuts=2,
                          joints=(3, 0.07), lumps=(1.5, 0.2), top="point", seg=28, rings=14, sink=0.0, rise=0.08),
    # (2026-11-04, the user's reference videos) Billowing cliffs: rounded masses heaped with bulges like cloud turned
    # to stone, soft bands across them; the cliffs behind the spawn and round the grotto, and the cave's walls.
    "RealmBillowA": dict(kind="pillar", dust=False, seed=91, h=30.0, r=15.0, profile=[(0, 1.06), (0.1, 1.0), (0.45, 0.95),
                                                                          (0.72, 0.84), (0.9, 0.6), (1.0, 0.0)],
                         lobes=0.3, squash=0.74, lean=(1.2, -0.6), curve=1.2, strata=(7.0, 0.04, 0.6),
                         joints=(3, 0.05), lumps=(1.6, 0.22), billows=(110, 5.0, 3.8), top="dome", seg=64, rings=44),
    "RealmBillowB": dict(kind="pillar", dust=False, seed=92, h=44.0, r=17.0, profile=[(0, 1.08), (0.08, 1.0), (0.4, 0.93),
                                                                          (0.7, 0.8), (0.88, 0.58), (1.0, 0.0)],
                         lobes=0.34, squash=0.7, lean=(-2.0, 1.2), curve=1.4, strata=(8.0, 0.04, 0.6),
                         joints=(3, 0.05), lumps=(1.8, 0.24), billows=(170, 6.0, 4.6), top="dome", seg=72, rings=56),
    "RealmBillowC": dict(kind="pillar", dust=False, seed=93, h=16.0, r=12.0, profile=[(0, 1.05), (0.15, 1.0), (0.5, 0.92),
                                                                          (0.8, 0.72), (1.0, 0.0)],
                         lobes=0.36, squash=0.72, lean=(0.6, 0.4), curve=1.0, strata=(5.0, 0.04, 0.6),
                         joints=(2, 0.05), lumps=(1.4, 0.2), billows=(80, 4.2, 3.2), top="dome", seg=52, rings=30),
    # A long low shelf of the same rock, flat on top (the spawn ledge's sides, the grotto's sill).
    "RealmBillowShelf": dict(kind="pillar", dust=False, seed=94, h=8.0, r=16.0, profile=[(0, 1.04), (0.2, 1.0), (0.7, 0.97),
                                                                             (0.92, 0.9), (1.0, 0.84)],
                             lobes=0.2, squash=0.45, lean=(0.0, 0.0), curve=1.0, strata=(3.0, 0.03, 0.5),
                             joints=(2, 0.04), lumps=(1.2, 0.2), billows=(60, 3.4, 2.4), top="flat", seg=60,
                             rings=12, sink=1.0),
    # The throne's rock: a table of layered rock standing alone in the north, flat on top, fractured down its sides.
    "RealmThroneRock": dict(kind="pillar", seed=98, h=16.0, r=11.0, profile=[(0, 1.25), (0.08, 1.08), (0.3, 1.0),
                                                                              (0.75, 0.95), (0.92, 0.9), (1.0, 0.86)],
                            lobes=0.18, squash=0.9, lean=(0.0, 0.0), curve=1.0, strata=(2.6, 0.08, 0.5), cuts=4,
                            joints=(6, 0.08), lumps=(2.0, 0.3), top="flat", seg=48, rings=24, sink=1.0),
    # Drips of rock hanging from the grotto's roof (a flat top against the roof, a point underneath).
    "RealmDripA": dict(kind="pillar", hang=True, dust=False, seed=95, h=9.0, r=1.8,
                       profile=[(0, 1.0), (0.15, 0.9), (0.5, 0.55), (0.85, 0.2), (1.0, 0.0)], lobes=0.22, squash=0.8,
                       lean=(0.3, -0.2), curve=1.4, strata=(0.0, 0.0, 0.0), joints=(0, 0.0), lumps=(0.9, 0.12),
                       top="point", seg=12, rings=10, sink=0.0, rise=0.0),
    "RealmDripB": dict(kind="pillar", hang=True, dust=False, seed=96, h=15.0, r=2.6,
                       profile=[(0, 1.0), (0.12, 0.92), (0.45, 0.6), (0.8, 0.26), (1.0, 0.0)], lobes=0.26, squash=0.78,
                       lean=(-0.5, 0.4), curve=1.6, strata=(0.0, 0.0, 0.0), joints=(0, 0.0), lumps=(1.1, 0.16),
                       top="point", seg=12, rings=12, sink=0.0, rise=0.0),
    # A colossal tusk of old bone curving up out of the ash, its growth rings round it.
    "RealmTusk": dict(kind="pillar", dust=False, mat="BoneOld", seed=97, h=46.0, r=4.2,
                      profile=[(0, 1.18), (0.06, 1.0), (0.45, 0.82), (0.75, 0.55), (0.92, 0.26), (1.0, 0.0)],
                      lobes=0.06, squash=0.86, lean=(20.0, 0.0), curve=2.4, strata=(2.6, 0.02, 0.2),
                      joints=(0, 0.0), lumps=(1.6, 0.12), top="point", seg=24, rings=34, sink=2.0),
}


def _shard(seed, h, r, lean=(0.0, 0.0), sides=6):
    """One shard: a few flat faces running up to a sharp point, split flat here and there."""
    return dict(kind="pillar", dust=False, seed=seed, h=h, r=r,
                profile=[(0, 1.0), (0.1, 0.96), (0.55, 0.62), (0.85, 0.24), (1.0, 0.0)], lobes=0.24, squash=0.74,
                lean=lean, curve=1.3, strata=(0.0, 0.0, 0.0), cuts=2, joints=(0, 0.0), lumps=(max(1.0, r), 0.0),
                top="point", seg=sides, rings=5)


# Clusters of shards, pale, like broken glass grown out of the rock (the skyline's jagged ranges, the rune
# courtyard's garden, crystals in the grotto): kind "cluster", its parts (a pillar's recipe, where its foot stands
# (x, y), how far it leans out (degrees about x and y), its turn about z).
SHARD = "RealmShard"
KIT["RealmShardsA"] = dict(kind="cluster", mat=SHARD, dust=False, seg=6, sink=1.0, parts=[
    (_shard(101, 26.0, 3.2, (0.8, -0.4)), (0.0, 0.0), (4.0, -3.0), 0.0),
    (_shard(102, 17.0, 2.3), (3.4, 1.0), (-6.0, 22.0), 40.0),
    (_shard(103, 14.0, 2.0), (-3.0, 1.8), (10.0, -24.0), 75.0),
    (_shard(104, 11.0, 1.7), (0.6, -3.2), (28.0, 6.0), 15.0),
    (_shard(105, 8.0, 1.4), (-2.2, -2.4), (22.0, -20.0), 110.0),
])
KIT["RealmShardsB"] = dict(kind="cluster", mat=SHARD, dust=False, seg=6, sink=1.0, parts=[
    (_shard(111, 64.0, 7.0, (3.0, 1.0)), (0.0, 0.0), (5.0, 3.0), 0.0),
    (_shard(112, 42.0, 5.2), (8.0, -2.0), (-4.0, 18.0), 30.0),
    (_shard(113, 36.0, 4.6), (-7.0, 3.0), (8.0, -16.0), 65.0),
    (_shard(114, 26.0, 3.8), (2.0, 7.5), (-20.0, 4.0), 100.0),
    (_shard(115, 20.0, 3.2), (-4.0, -6.5), (18.0, -10.0), 140.0),
    (_shard(116, 14.0, 2.6), (9.0, 6.0), (-16.0, 20.0), 170.0),
])
KIT["RealmShardsC"] = dict(kind="cluster", mat=SHARD, dust=False, seg=6, sink=0.4, parts=[
    (_shard(121, 6.0, 0.9), (0.0, 0.0), (6.0, -4.0), 0.0),
    (_shard(122, 4.0, 0.7), (1.0, 0.3), (-8.0, 26.0), 50.0),
    (_shard(123, 3.4, 0.6), (-0.9, 0.5), (14.0, -28.0), 85.0),
    (_shard(124, 2.6, 0.5), (0.2, -1.0), (30.0, 8.0), 20.0),
])
KIT["RealmShardSpire"] = dict(kind="cluster", mat=SHARD, dust=False, seg=6, sink=1.0, far=True, parts=[
    (_shard(131, 96.0, 10.0, (6.0, -2.0), sides=7), (0.0, 0.0), (3.0, -2.0), 0.0),
    (_shard(132, 40.0, 5.0), (10.0, 4.0), (-8.0, 20.0), 60.0),
])

# Far variants: the same shapes with a third of their corners, for the far plain (the fog takes the rest); the
# needles, by the hundred out there, with half.
for _key in ("RealmNeedleA", "RealmNeedleB"):
    KIT[_key + "Far"] = dict(KIT[_key], seg=5, rings=6, far=True)
# Far variants: the same shapes with a third of their corners, for the far plain (the fog takes the rest).
# (not for the shapes the lobby never stands far off: their far variants would only be dead weight in the export)
FAR_SKIP = {"RealmBillowShelf", "RealmCragA", "RealmCragC", "RealmMesa", "RealmThroneRock"}
for _key in [k for k, rc in KIT.items() if rc["seg"] >= 24 and not rc.get("far") and not rc.get("hang")
             and k not in FAR_SKIP]:
    _rc = KIT[_key]
    KIT[_key + "Far"] = dict(_rc, seg=max(12, _rc["seg"] // 3), rings=max(6, _rc["rings"] // 3), far=True,
                             lumps=(_rc["lumps"][0] * 2.0, _rc["lumps"][1]))


def _profile(points, t):
    for (t0, k0), (t1, k1) in zip(points, points[1:]):
        if t <= t1:
            u = (t - t0) / max(1e-6, t1 - t0)
            u = u * u * (3 - 2 * u)
            return k0 + (k1 - k0) * u
    return points[-1][1]


def _beds(rc, rng):
    """The strata from the foot up: [(z0, z1, how hard)], each bed its own thickness, the hard ones standing out
    (1), the soft ones weathered back (down to -0.6)."""
    thick = rc["strata"][0]
    if thick <= 0:
        return []
    beds, z = [], -rc.get("sink", 1.0)
    while z < rc["h"]:
        t = thick * rng.choice((0.45, 0.6, 0.8, 1.0, 1.0, 1.3, 1.7))
        hard = rng.choice((1.0, 1.0, 0.8, 0.5, 0.2, -0.3, -0.6))
        beds.append((z, z + t, hard))
        z += t
    return beds


def _ring_heights(rc, beds):
    """The heights of the rings: evenly spread, plus each bed's lip and foot so its ledge stays crisp; returns sorted
    t values (0..1)."""
    h = rc["h"]
    ts = {k / rc["rings"] for k in range(rc["rings"] + 1)}
    for z0, z1, hard in beds:
        for u in ((0.0, 0.8) if rc.get("far") else (0.0, 0.07, 0.8, 0.93)):
            t = (z0 + u * (z1 - z0)) / h
            if 0.0 < t < 1.0:
                ts.add(round(t, 4))
    out = sorted(ts)
    # (rings closer than a tenth of a stud are merged)
    merged = [out[0]]
    for t in out[1:]:
        if (t - merged[-1]) * h > 0.12:
            merged.append(t)
    if merged[-1] != 1.0:
        merged[-1] = 1.0
    return merged


def _bed_at(beds, z):
    """(how far the rock stands out at height z, from its bed): a bed is full across its middle and falls to its
    neighbours' over a sharp lip at its top and foot."""
    if not beds:
        return 0.0
    for k, (z0, z1, hard) in enumerate(beds):
        if z < z1 or k == len(beds) - 1:
            u = (z - z0) / max(1e-6, z1 - z0)
            below = beds[k - 1][2] if k else hard
            above = beds[k + 1][2] if k + 1 < len(beds) else hard
            if u < 0.07:
                return below + (hard - below) * _smooth(0.0, 0.07, u)
            if u > 0.8:
                # (the top of a bed rounds back a little before the next one starts: the ledge's lip)
                return hard + (min(hard, above) - hard) * _smooth(0.8, 1.0, u) * 0.9 + (above - hard) * _smooth(0.93, 1.0, u) * 0.1
            return hard
    return 0.0


def pillar(rc):
    """(verts, faces, uvs, top) of a lofted shape: verts [(x, y, z)], faces [vertex indices], uvs per face [(u, v)]
    per corner (in repeats of TILE), and the first index of the top cap's faces."""
    rng = random.Random(rc["seed"])
    seed = rc["seed"] * 17.31
    h, r = rc["h"], rc["r"]
    seg = rc["seg"]
    sink = rc.get("sink", 1.0)
    lobes = [(k, rng.uniform(0, math.tau), rc["lobes"] * rng.uniform(0.5, 1.0) / k ** 0.7) for k in (2, 3, 4, 5)]
    thick, proud, waver = rc["strata"]
    joints = []
    if rc["joints"][0]:
        for _ in range(rc["joints"][0]):
            joints.append((rng.uniform(0, math.tau), rc["joints"][1] * rng.uniform(0.6, 1.2), rng.uniform(0.25, 0.7)))
    lump_size, lump_depth = rc["lumps"]
    lean_x, lean_y = rc["lean"]
    twist = rc.get("twist", 0.0)
    flutes, flute = rc.get("flutes", 0), rc.get("flute", 0.0)
    beds = _beds(rc, rng)
    # Billows: round bulges heaped over the surface (a billowing cliff), from their own seed so the other shapes keep
    # theirs: (direction round the rock, height as a share of h, size in studs, how far it swells out).
    billows = []
    if rc.get("billows"):
        brng = random.Random(rc["seed"] * 31 + 7)
        count, bsize, bdepth = rc["billows"]
        for _ in range(count):
            billows.append((brng.uniform(0, math.tau), brng.uniform(-0.05, 0.95), bsize * brng.uniform(0.6, 1.35),
                            bdepth * brng.uniform(0.55, 1.2)))
    ts = _ring_heights(rc, beds)
    # Fracture planes down its sides: where the rock split away along a joint it stands as a flat cliff (each plane:
    # its direction round the rock, its tilt back as it rises, how far out it stands as a share of the radius).
    cuts = [(rng.uniform(0, math.tau), rng.uniform(-0.12, 0.2), rng.uniform(0.62, 0.86)) for _ in range(rc.get("cuts", 0))]
    # The broken top: a slanted plane (its fall across the top, as a share of the radius there).
    slant_a = rng.uniform(0, math.tau)
    slant = rng.uniform(0.25, 0.55)

    def centre(t):
        k = t ** rc["curve"]
        wob = 0.6 * _n(seed + 3.1, t * 2.0, 0.0)
        return lean_x * k + wob * r * 0.05, lean_y * k + 0.6 * _n(seed + 7.7, t * 2.0, 1.0) * r * 0.05

    rows = []  # per ring: list of (x, y, z)
    for j, t in enumerate(ts):
        z = -sink if j == 0 else h * t
        cx, cy = centre(t)
        k_prof = _profile(rc["profile"], t)
        spin = twist * math.tau * t
        row = []
        for i in range(seg):
            al = math.tau * i / seg
            a = al + spin
            rad = r * k_prof
            rad *= 1.0 + sum(amp * math.cos(k * al + ph) for k, ph, amp in lobes)
            if flutes:
                rad *= 1.0 - flute * (0.5 + 0.5 * math.cos(flutes * al)) ** 3
            for ja, depth, width in joints:
                d = math.atan2(math.sin(a - ja), math.cos(a - ja))
                wander = 0.15 * _n(seed + ja, z * 0.08, 0.0)
                d -= wander
                rad *= 1.0 - depth * math.exp(-(d / (width * 0.22)) ** 2)
            ux, uy = math.cos(a), math.sin(a) * rc["squash"]
            for ca, tilt, out in cuts:
                # (the plane's distance from the axis along its own direction; points past it come back onto it)
                nx, ny = math.cos(ca), math.sin(ca)
                along = ux * nx + uy * ny
                limit = r * k_prof * out * (1.0 - tilt * t)
                if along > 1e-3 and rad * along > limit:
                    rad = limit / along
            if beds:
                # (the strata waver round the rock and dip a little across it, so a ledge is never level)
                yy = z + waver * thick * _fbm(math.cos(a) * 0.6 + seed, math.sin(a) * 0.6, 0.3, 2)
                stand = _bed_at(beds, yy)
                # (how far a bed stands out changes round the rock: in places it has weathered back to the face)
                stand *= 0.55 + 0.45 * (0.5 + 0.5 * _n(seed + math.cos(a) * 1.3, math.sin(a) * 1.3, yy / thick * 0.35))
                rad *= 1.0 + proud * stand
            # (each bulb a dome over the surface; where two meet, the higher one wins, so a crease runs between them
            # as between the bulbs of a cauliflower)
            bulge = 0.0
            for ba, bt, bs, bd in billows:
                da = math.atan2(math.sin(al - ba), math.cos(al - ba)) * rad
                dz = z - bt * h
                q = (da * da + dz * dz) / (bs * bs)
                if q < 1.0:
                    bulge = max(bulge, bd * math.sqrt(1.0 - q))
            rad += bulge
            # Lumps: a broad swell and a finer knobbliness (the scan carries the grain).
            px, py = ux * rad, uy * rad
            lump = lump_depth * (_fbm((px + cx) / (lump_size * 2.6) + seed, (py + cy) / (lump_size * 2.6),
                                      z / (lump_size * 2.6), 2)
                                 + 0.45 * _fbm((px + cx) / lump_size + seed, (py + cy) / lump_size, z / lump_size, 2))
            rad2 = rad + lump
            row.append([cx + ux * rad2, cy + uy * rad2, z])
        rows.append(row)
    # The top.
    top_kind = rc["top"]
    if top_kind == "broken":
        # Every ring's points above the slanted plane are brought down onto it: the rock snapped there.
        tx, ty = math.cos(slant_a), math.sin(slant_a)
        cut0 = h * 0.94
        last = rows[-1]
        cx, cy = centre(1.0)
        rr = max(math.hypot(p[0] - cx, p[1] - cy) for p in last)
        for row in rows[len(rows) // 2:]:
            for p in row:
                plane = cut0 + ((p[0] - cx) * tx + (p[1] - cy) * ty) / rr * slant * rr * 0.6
                plane += 0.35 * lump_depth * _fbm(p[0] * 0.4 + seed, p[1] * 0.4, 5.0, 3)
                if p[2] > plane:
                    p[2] = plane
    verts = [tuple(p) for row in rows for p in row]
    faces, uvs = [], []
    # Bands for the UVs: one per stratum (the seam between two is the ledge), each a whole number of repeats round.
    band_of = []
    for j in range(len(rows) - 1):
        zmid = (rows[j][0][2] + rows[j + 1][0][2]) / 2
        if beds:
            band_of.append(next((k for k, (z0, z1, _) in enumerate(beds) if zmid < z1), len(beds) - 1))
        else:
            band_of.append(int(zmid // 8.0))
    radii = {}
    for j in range(len(rows) - 1):
        cx, cy = centre(ts[j])
        mean = sum(math.hypot(p[0] - cx, p[1] - cy) for p in rows[j]) / seg
        radii.setdefault(band_of[j], []).append(mean)
    around = {b: max(1, round(math.tau * (sum(v) / len(v)) / TILE)) for b, v in radii.items()}
    for j in range(len(rows) - 1):
        k = around[band_of[j]]
        for i in range(seg):
            i1 = (i + 1) % seg
            a, b = j * seg + i, j * seg + i1
            c, d = (j + 1) * seg + i1, (j + 1) * seg + i
            u0, u1 = k * i / seg, k * (i + 1) / seg
            faces.append((a, b, c, d))
            uvs.append(((u0, verts[a][2] / TILE), (u1, verts[b][2] / TILE), (u1, verts[c][2] / TILE),
                        (u0, verts[d][2] / TILE)))
    top_first = len(faces)
    last = len(rows) - 1
    ring = [last * seg + i for i in range(seg)]
    cx = sum(verts[i][0] for i in ring) / seg
    cy = sum(verts[i][1] for i in ring) / seg
    cz = sum(verts[i][2] for i in ring) / seg
    if top_kind == "point":
        tip = (cx, cy, h)
    elif top_kind == "dome":
        tip = (cx, cy, h)
    elif top_kind == "flat":
        tip = (cx, cy, max(verts[i][2] for i in ring) + rc.get("rise", 0.15))
    else:
        tip = (cx, cy, cz + rng.uniform(-0.3, 0.6))
    verts.append(tip)
    tip_i = len(verts) - 1
    for i in range(seg):
        a, b = ring[i], ring[(i + 1) % seg]
        faces.append((a, b, tip_i))
        uvs.append(((verts[a][0] / TILE, verts[a][1] / TILE), (verts[b][0] / TILE, verts[b][1] / TILE),
                    (tip[0] / TILE, tip[1] / TILE)))
    if rc.get("hang"):
        # A rock that hangs in the air: its foot is its flat top, capped (a level stone a body stands on, rising
        # `rise` at its middle), its "top" the point it narrows to underneath: the shape is turned upside down.
        base = list(range(seg))
        bx = sum(verts[i][0] for i in base) / seg
        by = sum(verts[i][1] for i in base) / seg
        bz = min(verts[i][2] for i in base)
        for i in base:
            verts[i] = (verts[i][0], verts[i][1], bz)
        verts.append((bx, by, bz - rc.get("rise", 0.15)))
        mid = len(verts) - 1
        for i in range(seg):
            a, b = base[i], base[(i + 1) % seg]
            faces.append((b, a, mid))
            uvs.append(((verts[b][0] / TILE, verts[b][1] / TILE), (verts[a][0] / TILE, verts[a][1] / TILE),
                        (bx / TILE, by / TILE)))
        top = max(v[2] for v in verts)
        verts = [(x, y, top - z) for x, y, z in verts]
        faces = [tuple(reversed(f)) for f in faces]
        uvs = [tuple(reversed(u)) for u in uvs]
    return verts, faces, uvs, top_first


def _cluster(rc):
    """(verts, faces, uvs, top) of a cluster: its parts' pillars, each leaned out and turned and stood at its own spot."""
    verts, faces, uvs = [], [], []
    for sub, (dx, dy), (tx, ty), yaw in rc["parts"]:
        v, f, u, _ = pillar(dict(sub, sink=rc.get("sink", 1.0)))
        m = (Matrix.Translation((dx, dy, 0.0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
             @ Matrix.Rotation(math.radians(tx), 4, "X") @ Matrix.Rotation(math.radians(ty), 4, "Y"))
        base = len(verts)
        verts += [tuple(m @ Vector(p)) for p in v]
        faces += [tuple(i + base for i in face) for face in f]
        uvs += u
    return verts, faces, uvs, len(faces)


_SHAPES = {}


def shape(key):
    """(verts, faces, uvs, top) of a kit shape, grounded: its foot at z = 0 (the sunk part under), the middle of its
    bounding box over the origin."""
    if key not in _SHAPES:
        rc = KIT[key]
        verts, faces, uvs, top = _cluster(rc) if rc["kind"] == "cluster" else pillar(rc)
        xs = [v[0] for v in verts]
        ys = [v[1] for v in verts]
        mx, my = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        low = min(v[2] for v in verts)
        verts = [(x - mx, y - my, z - low) for x, y, z in verts]
        _SHAPES[key] = (verts, faces, uvs, top)
    return _SHAPES[key]


# The surfaces a kit shape wears: its rock, and the ash that settles on whatever faces up (every ledge, the tops,
# the flare of its foot), as the map's own ground wears it.
ROCK, DUST = "RockGrey", "RealmAsh"
DUST_UP = 0.72  # a face whose normal points up more than this holds ash


def surfaces(key):
    """The two map surfaces a shape wears: its rock, and what lies on whatever faces up (ash, or the old flagstones
    laid on a stone people climb onto: recipe "dust_mat")."""
    return KIT[key].get("mat", ROCK), KIT[key].get("dust_mat", DUST)


def materials(key):
    """The surface of each face (an index into (ROCK, DUST)): ash where the face looks up enough for it to settle and
    the shape lets it (recipe "dust": False keeps a shape bare)."""
    verts, faces, _, _ = shape(key)
    if not KIT[key].get("dust", True):
        return [0] * len(faces)
    out = []
    for f in faces:
        a, b, c = verts[f[0]], verts[f[1]], verts[f[2]]
        ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
        vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
        nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        if len(f) == 4:
            d = verts[f[3]]
            wx, wy, wz = d[0] - a[0], d[1] - a[1], d[2] - a[2]
            nx += vy * wz - vz * wy
            ny += vz * wx - vx * wz
            nz += vx * wy - vy * wx
        length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        out.append(1 if nz / length > DUST_UP else 0)
    return out


_FOOT = {}


def footprint(key, upto=4.0):
    """The outline of the shape's foot (from the ground to `upto` studs up) as a convex polygon of (x, z) in Roblox
    axes (x = -builder x, z = builder y), counter-clockwise from above, with the shape placed by build_props'
    grounding (its bounding box's middle on the origin, its lowest point at y = 0). For the venue's colliders."""
    if (key, upto) not in _FOOT:
        verts, _, _, _ = shape(key)
        if KIT[key]["kind"] == "cluster":
            # (a cluster's parts are no one ring structure: its foot is what of it stands under `upto`)
            low = min(v[2] for v in verts)
            top = low + KIT[key].get("sink", 1.0) + upto
            _FOOT[(key, upto)] = _hull([(-v[0], v[1]) for v in verts if v[2] <= top])
            return _FOOT[(key, upto)]
        seg = KIT[key]["seg"]
        rows = [verts[j * seg:(j + 1) * seg] for j in range((len(verts) - 1) // seg)]
        low = min(v[2] for v in verts)
        sink = KIT[key].get("sink", 1.0)
        pts = []
        # (each column of the surface cut at a few heights between the ground and `upto`: rings may lie further
        # apart than that, so the outline is read off the faces between them)
        for at in (low + sink + 0.05, low + sink + upto * 0.5, low + sink + upto):
            for i in range(seg):
                for j in range(len(rows) - 1):
                    a, b = rows[j][i], rows[j + 1][i]
                    if a[2] <= at <= b[2] or b[2] <= at <= a[2]:
                        t = 0.0 if abs(b[2] - a[2]) < 1e-9 else (at - a[2]) / (b[2] - a[2])
                        pts.append((-(a[0] + (b[0] - a[0]) * t), a[1] + (b[1] - a[1]) * t))
                        break
        _FOOT[(key, upto)] = _hull(pts)
    return _FOOT[(key, upto)]


def size(key):
    """(x, y, z) in Roblox axes: the shape's bounding box, as the catalog will give it."""
    verts, _, _, _ = shape(key)
    xs, ys, zs = [v[0] for v in verts], [v[1] for v in verts], [v[2] for v in verts]
    return (max(xs) - min(xs), max(zs) - min(zs), max(ys) - min(ys))


def _hull(points):
    pts = sorted(set((round(x, 3), round(z, 3)) for x, z in points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]
