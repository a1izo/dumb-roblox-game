"""The Grey Realm's title monolith (set "Lobby"; asked 2026-10-27: tall, cracked and black, no eyes, no tusks): one
slab of black basalt on a plinth of three courses of rough-hewn blocks, a raised border round its face and a heavy
moulding round the panel the game writes the title on, its shoulders broken into blocks of different heights, and out
of them a tapering spire in three pieces, each knocked a little askew where it cracked through, snapped off near the
top. Cracks run down its face and up the spire, dark grooves with a faint red light deep in them; chains hang across
the face from iron bolts.

A tiled prop (props.prop's tiled): it is the size of a house, so it wears the map's own surfaces at their density
(the basalt, the rock, the black trim and iron) instead of a bake of its own. Built facing -Y with the middle of its
footprint on the origin; the venue stands it facing the spawn (landmarks.monolith), its face at plan.MONO_FACE."""

import math
import random

import bmesh

import modelkit as mk
import propkit as pk
from props import prop
from props_realm import surface

W, T, H = 52.0, 6.0, 40.0  # the slab (plan.MONO): width, thickness, the height its shoulders reach
FACE = -T / 2  # its face (builder y)


def _loft(name, low, high, z0, z1, mat, slant=None):
    """A tapering section of the spire: its outline at z0 (`low`) and at z1 (`high`), each a list of (x, y) round it;
    `slant` (a, b): the top cut on a plane falling a studs across x and b across y instead (where it snapped)."""
    bm = bmesh.new()
    n = len(low)
    rings = []
    for pts, z in ((low, z0), (high, z1)):
        ring = []
        for x, y in pts:
            zz = z
            if slant and pts is high:
                zz = z + slant[0] * x + slant[1] * y
            ring.append(bm.verts.new((x, y, zz)))
        rings.append(ring)
    for k in range(n):
        k1 = (k + 1) % n
        bm.faces.new((rings[0][k], rings[0][k1], rings[1][k1], rings[1][k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mk._obj_from_bm(name, bm, mat)


def _octagon(w, t, chamfer, cx=0.0, turn=0.0):
    """A rectangle w by t with its corners cut back `chamfer`, turned `turn` degrees, its middle at (cx, 0)."""
    hw, ht, c = w / 2, t / 2, chamfer
    pts = [(-hw + c, -ht), (hw - c, -ht), (hw, -ht + c), (hw, ht - c), (hw - c, ht), (-hw + c, ht), (-hw, ht - c),
           (-hw, -ht + c)]
    a = math.radians(turn)
    return [(cx + x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)) for x, y in pts]


def _crack(parts, glows, rng, start, steps, groove, core, stop, face=FACE, low=1.5):
    """A crack wandering down the face from `start` (x, z): each piece a dark groove standing a hair proud of the face
    with a thin red core in it; now and then it forks. It ends after `steps` pieces, near the foot, or where
    `stop(x, z)` says."""
    x, z = start
    heading = -math.pi / 2 + rng.uniform(-0.5, 0.5)
    for _ in range(steps):
        heading = max(-math.pi + 0.35, min(-0.35, heading + rng.uniform(-0.7, 0.7)))
        length = rng.uniform(0.9, 2.3)
        nx, nz = x + math.cos(heading) * length, z + math.sin(heading) * length
        if nz < low or stop(nx, nz):
            break
        mx, mz = (x + nx) / 2, (z + nz) / 2
        angle = -math.degrees(math.atan2(nz - z, nx - x))
        width = rng.uniform(0.2, 0.3)
        parts.append(mk.box("Crack", (length + 0.12, 0.08, width), (mx, face - 0.03, mz), rot=(0, angle, 0), mat=groove))
        glows.append(mk.box("CrackCore", (length + 0.04, 0.03, 0.05), (mx, face - 0.075, mz), rot=(0, angle, 0), mat=core))
        if rng.random() < 0.18:
            _crack(parts, glows, rng, (nx, nz), rng.randint(2, 4), groove, core, stop, face, low)
        x, z = nx, nz


def _chain(parts, a, b, sag, mat, link=0.95):
    """A heavy iron chain from a to b (x, z on the face), sagging `sag` at its middle: links along the curve, each
    turned a quarter from the one before, a bolt and a ring at each end."""
    span = math.dist(a, b)
    count = max(4, int(span / (link * 0.74)))
    pts = [(a[0] + (b[0] - a[0]) * k / count, a[1] + (b[1] - a[1]) * k / count - sag * 4 * (k / count) * (1 - k / count))
           for k in range(count + 1)]
    for k in range(count):
        (x0, z0), (x1, z1) = pts[k], pts[k + 1]
        angle = -math.degrees(math.atan2(z1 - z0, x1 - x0))
        mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        ring = mk.torus("Link", link * 0.36, 0.085, (mx, FACE - 0.45, mz), mat=mat, major_segments=12, minor_segments=6)
        ring.scale = (1.45, 1.0, 0.75)
        ring.rotation_euler = (math.radians(90 if k % 2 else 0), math.radians(angle), 0)
        parts.append(ring)
    for x, z in (a, b):
        parts.append(mk.box("Bolt", (0.75, 0.32, 0.75), (x, FACE - 0.16, z), mat=mat, bevel=0.06))
        parts.append(mk.torus("BoltRing", 0.3, 0.07, (x, FACE - 0.38, z - 0.3), rot=(90, 0, 0), mat=mat,
                              major_segments=12, minor_segments=6))


# The mini-games' stones (tiled like the monolith; the game builds the plain parts they dress and keeps their tags,
# collisions and lights): the Spire Ascent's checkpoint markers, the rune courtyard's tiles, the start pads, the
# shop window's pedestal on the spawn terrace.


@prop("SpireMarker", pivot="bottom", material="Basalt", collide=False, texture=256, set="Lobby", tiled=True)
def spire_marker():
    """A checkpoint of the Spire Ascent: a small black obelisk on a square foot, chamfered, its top cut flat where the
    game sets its pale glowing cap (3.6 tall; the finish's is scaled up)."""
    basalt = surface("Basalt")
    parts = [mk.box("Foot", (1.3, 1.3, 0.34), (0, 0, 0.17), mat=basalt, bevel=0.06),
             mk.box("FootStep", (1.08, 1.08, 0.18), (0, 0, 0.43), mat=basalt, bevel=0.04)]
    parts.append(_loft("Shaft", _octagon(0.82, 0.82, 0.12), _octagon(0.6, 0.6, 0.09), 0.5, 3.36, basalt))
    parts.append(mk.box("Collar", (0.78, 0.78, 0.12), (0, 0, 3.32), mat=basalt, bevel=0.03))
    parts.append(mk.box("Top", (0.7, 0.7, 0.22), (0, 0, 3.49), mat=basalt, bevel=0.04))
    return parts, []


@prop("RuneTile", pivot="bottom", material="Basalt", collide=False, texture=256, set="Lobby", tiled=True)
def rune_tile():
    """A tile of the rune courtyard (7 across, 0.5 thick; the game lays its glyph over it, lit when it is the tile's
    turn): a slab of black basalt, its edges bevelled and chipped, a groove cut round it inside a narrow border."""
    basalt, trim = surface("Basalt"), surface("BlackTrim")
    rng = random.Random(77)
    parts = [mk.box("Slab", (7.0, 7.0, 0.42), (0, 0, 0.21), mat=basalt, bevel=0.12, segments=2),
             mk.box("Face", (6.1, 6.1, 0.1), (0, 0, 0.45), mat=basalt, bevel=0.03)]
    for (x, y, w, d) in ((0, 3.21, 6.5, 0.14), (0, -3.21, 6.5, 0.14), (3.21, 0, 0.14, 6.5), (-3.21, 0, 0.14, 6.5)):
        parts.append(mk.box("Groove", (w, d, 0.06), (x, y, 0.42), mat=trim))
    for k in range(3):
        a = rng.uniform(0, math.tau)
        parts.append(mk.box("Chip", (0.5, 0.4, 0.2), (math.cos(a) * 3.3, math.sin(a) * 3.3, 0.33), rot=(0, 0, rng.uniform(0, 90)),
                            mat=trim, bevel=0.04))
    return parts, []


@prop("StartPad", pivot="bottom", material="Basalt", collide=False, texture=256, set="Lobby", tiled=True)
def start_pad():
    """Where a mini-game is begun (8 across, 0.3 high; the game lays its pale outline in its border): a square of
    old flagstones in a moulded basalt kerb."""
    basalt, flag = surface("Basalt"), surface("RuinFlag")
    parts = [mk.box("Kerb", (8.0, 8.0, 0.24), (0, 0, 0.12), mat=basalt, bevel=0.07),
             mk.box("Field", (7.0, 7.0, 0.08), (0, 0, 0.27), mat=flag, bevel=0.02)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Corner", (0.9, 0.9, 0.1), (sx * 3.45, sy * 3.45, 0.28), mat=basalt, bevel=0.03))
    return parts, []


@prop("ShopPlinth", pivot="bottom", material="Basalt", collide=False, texture=256, set="Lobby", tiled=True)
def shop_plinth():
    """The pedestal on the spawn terrace the day's emote is shown on (3.2 across, 1.4 high; the game stands its figure
    on the top): a base moulding, a square die with a sunk panel on each face, a cap moulding."""
    basalt, rock, trim = surface("Basalt"), surface("RockGrey"), surface("BlackTrim")
    parts = [mk.box("Base", (3.2, 3.2, 0.26), (0, 0, 0.13), mat=rock, bevel=0.06),
             mk.box("BaseStep", (2.9, 2.9, 0.14), (0, 0, 0.33), mat=basalt, bevel=0.04),
             mk.box("Die", (2.6, 2.6, 0.68), (0, 0, 0.74), mat=basalt, bevel=0.05),
             mk.box("CapStep", (2.9, 2.9, 0.14), (0, 0, 1.15), mat=basalt, bevel=0.04),
             mk.box("Cap", (3.2, 3.2, 0.18), (0, 0, 1.31), mat=rock, bevel=0.06)]
    for k in range(4):
        a = math.radians(90 * k)
        parts.append(mk.box("Panel", (1.9, 0.04, 0.42), (math.sin(a) * 1.3, -math.cos(a) * 1.3, 0.74),
                            rot=(0, 0, 90 * k), mat=trim))
    return parts, []
