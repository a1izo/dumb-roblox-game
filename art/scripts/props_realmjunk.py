"""The Grey Realm's junk, lanterns and grass (set "Lobby"), made 2026-11-04 for the lobby's remake to the user's reference
videos: the dish of skulls at the bowl's middle (where the death gods sit and gamble), the cage lanterns hanging in the
grotto, rusted gear wheels and piles of giant chain lying about the junk heaps, the gear
wheels the Spire Ascent's checkpoints are, the colossal chain hanging out of the sky into the Chain Heap, and the pale
spiky dead grass. Forged and rusted iron, weathered stone, bone. They face -Y and stand on z = 0."""

import math
import random

import bmesh
from mathutils import Matrix

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop
from props_academy import weathered
from props_lobby import (bone_mat, dark_apart, drop, fill_gaps, lay_bone, old_bone_mat, skull, stone_mat, turned,
                         void_mat)
from props_realm import surface
from props_realmfire import FORGED


def _rust(prefix):
    return pk.metal(prefix + "Rust_Iron", (44, 30, 24), (92, 64, 48), rough=0.88, metallic=0.35)


def _iron(prefix):
    return pk.metal(prefix + "_Iron", (20, 20, 22), (50, 47, 45), rough=0.66, metallic=0.7)


def ring_prism(name, outer, inner, depth, mat):
    """A solid ring (a gear's rim, a washer) between two loops of the same count in the XY plane, `depth` thick along Z
    (centred): its two faces, its outer and inner walls."""
    bm = bmesh.new()
    n = len(outer)
    rows = []
    for z in (-depth / 2, depth / 2):
        rows.append(([bm.verts.new((x, y, z)) for x, y in outer], [bm.verts.new((x, y, z)) for x, y in inner]))
    (o0, i0), (o1, i1) = rows
    for k in range(n):
        k1 = (k + 1) % n
        bm.faces.new((o1[k], o1[k1], i1[k1], i1[k]))  # front (+Z)
        bm.faces.new((o0[k1], o0[k], i0[k], i0[k1]))  # back
        bm.faces.new((o0[k], o0[k1], o1[k1], o1[k]))  # outer wall
        bm.faces.new((i0[k1], i0[k], i1[k], i1[k1]))  # inner wall
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mk._obj_from_bm(name, bm, mat)
    return mk.smooth(obj)


def gear_loops(r_root, r_tip, r_in, teeth):
    """(outer, inner) loops of a gear wheel's rim: five points a tooth (the root, up its flank, across its tip, down),
    and the inner circle at the same angles."""
    outer, inner = [], []
    for k in range(teeth):
        a0 = math.tau * k / teeth
        da = math.tau / teeth
        for f, r in ((0.0, r_root), (0.22, r_root), (0.34, r_tip), (0.62, r_tip), (0.74, r_root)):
            a = a0 + da * f
            outer.append((math.cos(a) * r, math.sin(a) * r))
            inner.append((math.cos(a) * r_in, math.sin(a) * r_in))
    return outer, inner


def gear(prefix, r, depth, mat, rng, broken=0):
    """A gear wheel of tip radius r lying in the XY plane, `depth` thick: its toothed rim, six spokes, a hub with its
    bore; `broken` teeth knocked off (their gaps filled at the root)."""
    teeth = max(10, int(r * 2.2))
    outer, inner = gear_loops(r * 0.86, r, r * 0.66, teeth)
    for _ in range(broken):
        k = rng.randrange(teeth)
        for j in range(5):
            x, y = outer[k * 5 + j]
            s = (r * 0.86) / math.hypot(x, y)
            outer[k * 5 + j] = (x * s, y * s)
    parts = [ring_prism(prefix + "Rim", outer, inner, depth, mat)]
    for k in range(6):
        a = math.tau * k / 6 + 0.26
        mid = r * 0.42
        parts.append(mk.box(prefix + "Spoke", (r * 0.56, r * 0.12, depth * 0.7), (math.cos(a) * mid, math.sin(a) * mid, 0.0),
                            rot=(0, 0, math.degrees(a)), mat=mat, bevel=0.05))
    hub_out = [(math.cos(math.tau * k / 20) * r * 0.2, math.sin(math.tau * k / 20) * r * 0.2) for k in range(20)]
    hub_in = [(x * 0.42, y * 0.42) for x, y in hub_out]
    parts.append(ring_prism(prefix + "Hub", hub_out, hub_in, depth * 1.3, mat))
    return [weathered(p, FORGED) for p in parts]


def chain_link(name, at, length, width, bar, mat, rot=(0.0, 0.0, 0.0), segments=20):
    """One link of chain: a ring of round bar drawn long (a stadium), `length` along Z and `width` across X, its middle at
    `at`, turned by rot (Euler degrees)."""
    pts = []
    straight = max(0.0, length - width)
    half = width / 2 - bar
    for k in range(segments):
        a = math.tau * k / segments
        x, z = math.cos(a) * half, math.sin(a) * half
        z += straight / 2 if z >= 0 else -straight / 2
        pts.append((x, 0.0, z))
    pts.append(pts[0])
    obj = pk.sweep(name, pts, bar, mat, sides=8, caps=False)
    obj.rotation_euler = tuple(math.radians(v) for v in rot)
    obj.location = at
    return obj


# The dish of skulls ------------------------------------------------------------------------------------------------


@prop("SkullDish", pivot="bottom", material="Slate", collide=True, texture=512, set="Lobby")
def skull_dish():
    """The dish at the bowl's middle, where the death gods sit and gamble: a great shallow dish of old stone on a low
    foot, a band of carving round its rim, heaped with skulls and bones (a beast's among them), lying as they were left."""
    rng = random.Random(4)
    stone = stone_mat("Skd")
    bone, old, dark = bone_mat("Skd"), old_bone_mat("Skd"), void_mat("Skd")
    profile = [(0.001, 0.0), (1.6, 0.0), (1.7, 0.12), (1.4, 0.32), (1.5, 0.42), (3.0, 0.62), (3.4, 0.98), (3.42, 1.18),
               (3.2, 1.22), (2.9, 0.96), (1.8, 0.66), (0.001, 0.6)]
    dish = mk.lathe("Dish", profile, mat=stone, segments=48)
    mk.displace_noise(dish, strength=0.05, scale=0.5, name="SkdDish")
    parts = [dish]
    # The carved band round the rim: a run of notches.
    for k in range(24):
        a = math.tau * k / 24
        parts.append(mk.box("Notch", (0.14, 0.32, 0.18), (math.cos(a) * 3.3, math.sin(a) * 3.3, 0.86),
                            rot=(0, 0, math.degrees(a)), mat=stone, bevel=0.03))
    laid = [dish]
    for k, (x, y, r, yaw, tilt) in enumerate(((0.9, -0.6, 0.44, 20, (0.2, 0.1, 0)), (-1.1, -0.3, 0.42, -35, (-0.3, 0.2, 0)),
                                              (0.2, 1.0, 0.46, 160, (0.1, -0.4, 0)), (-0.5, 0.2, 0.4, 70, (0.5, 0.0, 0)),
                                              (1.5, 0.8, 0.38, 220, (-0.2, 0.3, 0)))):
        bits = turned(skull(f"S{k}", x, y, 3.0, r, bone if k % 2 else old, dark, yaw=yaw, far=k > 2), (x, y, 3.0), tilt)
        drop(bits, laid, sink=0.08)
        laid += bits
        parts += bits
    for k in range(4):
        a = rng.uniform(0, math.tau)
        c = (math.cos(a) * rng.uniform(0.3, 1.6), math.sin(a) * rng.uniform(0.3, 1.6))
        b = rng.uniform(0, math.pi)
        e = (math.cos(b) * 0.9, math.sin(b) * 0.9)
        bits = lay_bone(f"Bone{k}", (c[0] - e[0], c[1] - e[1]), (c[0] + e[0], c[1] + e[1]), 0.09, old if k % 2 else bone,
                        laid)
        laid += bits
        parts += bits
    return parts, dark_apart(parts, dark), {"finish": fill_gaps}


# Lanterns ------------------------------------------------------------------------------------------------------------


def cage_lantern(prefix, at, iron, rng, size=1.0):
    """An iron cage lantern hanging from a ring at its top (at: its bottom's middle): a dished base, eight ribs bowed
    out between two hoops, a peaked cap to the ring, a fat candle inside. Returns (parts, the flame's point)."""
    cx, cy, cz = at
    s = size
    parts = [mk.lathe(prefix + "Base", [(0.0, 0.0), (0.42 * s, 0.0), (0.5 * s, 0.1 * s), (0.46 * s, 0.2 * s),
                                        (0.0, 0.18 * s)], loc=(cx, cy, cz), mat=iron, segments=16)]
    top = cz + 1.7 * s
    for k in range(8):
        a = math.tau * k / 8
        rib = []
        for q in range(7):
            u = q / 6
            r = (0.46 + 0.16 * math.sin(math.pi * u)) * s
            rib.append((cx + math.cos(a) * r, cy + math.sin(a) * r, cz + 0.16 * s + (top - cz - 0.16 * s) * u))
        parts.append(pk.sweep(prefix + "Rib", rib, 0.035 * s, iron, sides=5))
    for z, r in ((cz + 0.62 * s, 0.6), (cz + 1.2 * s, 0.6)):
        parts.append(mk.torus(prefix + "Hoop", r * s, 0.03 * s, (cx, cy, z), mat=iron, major_segments=16, minor_segments=4))
    parts += [mk.lathe(prefix + "Cap", [(0.0, 0.0), (0.5 * s, 0.0), (0.46 * s, 0.08 * s), (0.12 * s, 0.5 * s),
                                        (0.0, 0.55 * s)], loc=(cx, cy, top), mat=iron, segments=16),
              mk.torus(prefix + "Ring", 0.14 * s, 0.035 * s, (cx, cy, top + 0.66 * s), rot=(90, 0, 0), mat=iron,
                       major_segments=10, minor_segments=4)]
    wax = mk.noisy(prefix + "_Wax", srgb(176, 170, 158), srgb(214, 208, 194), scale=14, roughness=0.55)
    candle = mk.lathe(prefix + "Candle", [(0.0, 0.0), (0.2 * s, 0.0), (0.2 * s, 0.5 * s), (0.17 * s, 0.56 * s),
                                          (0.0, 0.52 * s)], loc=(cx, cy, cz + 0.18 * s), mat=wax, segments=12)
    parts.append(candle)
    return [weathered(p, FORGED) if p is not candle else p for p in parts], (cx, cy, cz + 0.85 * s)


HANGING_CAGE_DROP = 9.0  # (landmarks.HANGING_CAGE_DROP: the chain's run from the hook down to the lantern's foot)


@prop("HangingCage", pivot="bottom", material="Metal", collide=False, texture=512, set="Lobby", detail=True, normal=256)
def hanging_cage():
    """A cage lantern hanging on a long chain from a hook (the grotto's, and the one over the Spire Ascent's last
    stone): its foot at z = 0, the chain's top HANGING_CAGE_DROP over it; a candle burning cold inside (its flame is
    the game's)."""
    rng = random.Random(8)
    iron = _iron("Hgc")
    parts, flame = cage_lantern("Hgc", (0.0, 0.0, 0.0), iron, rng, 1.3)
    z = 1.7 * 1.3 + 0.55 * 1.3 + 0.6
    k = 0
    while z < HANGING_CAGE_DROP - 0.2:
        parts.append(chain_link(f"Link{k}", (0.0, 0.0, z + 0.22), 0.5, 0.3, 0.05, iron, rot=(0, 0, 90 * (k % 2)),
                                segments=12))
        z += 0.38
        k += 1
    parts.append(mk.cylinder("Hook", 0.22, 0.2, (0.0, 0.0, HANGING_CAGE_DROP - 0.1), mat=iron, verts=10))
    return parts, [], {"flames": [(flame[0], flame[1], flame[2], 0.7)]}


# Gears and chain ------------------------------------------------------------------------------------------------------


@prop("RustGear", pivot="bottom", material="Metal", collide=True, texture=512, set="Lobby", detail=True, normal=256)
def rust_gear():
    """A broken gear wheel of rusted iron, as big as a cart wheel, standing on its edge half sunk in the junk (the venue
    sinks it): toothed rim, six spokes, a hub with its bore, three teeth knocked off."""
    rng = random.Random(21)
    parts = gear("Gear", 4.0, 0.9, _rust("Rgr"), rng, broken=3)
    turn = Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Rotation(math.radians(8), 4, "Y")
    for obj in parts:
        obj.matrix_basis = turn @ obj.matrix_basis
    return parts, [], {"finish": fill_gaps}


@prop("GearPlatform", pivot="bottom", material="Metal", collide=False, texture=512, set="Lobby", detail=True, normal=256)
def gear_platform():
    """A gear wheel lying flat in the air, 9 across, where the Spire Ascent's checkpoints are (its top at z = 1.0, which
    the venue stands where a stone's top would be): its rim plated over (a deck to land on), a broken length of chain
    hanging from under it."""
    rng = random.Random(22)
    rust = _rust("Gpl")
    iron = _iron("Gpl")
    parts = gear("Gear", 4.5, 0.7, rust, rng, broken=2)
    for obj in parts:
        obj.location = (obj.location[0], obj.location[1], obj.location[2] + 0.6)
    deck = mk.cylinder("Deck", 3.0, 0.12, (0.0, 0.0, 0.94), mat=rust, verts=24)
    parts.append(weathered(deck, FORGED))
    for k in range(10):
        a = math.tau * k / 10
        parts.append(mk.cylinder("Rivet", 0.07, 0.06, (math.cos(a) * 2.7, math.sin(a) * 2.7, 1.02), mat=iron, verts=6))
    for k in range(4):
        parts.append(chain_link(f"Link{k}", (1.2, 0.4, -0.15 - k * 0.6), 0.85, 0.5, 0.09, iron, rot=(0, 0, 90 * (k % 2)),
                                segments=14))
    return parts, [], {"finish": fill_gaps}


@prop("ChainPile", pivot="bottom", material="Metal", collide=True, texture=512, set="Lobby", detail=True, normal=256)
def chain_pile():
    """A heap of giant chain lying tangled in the junk, links as long as an arm, rusted through in places."""
    rng = random.Random(23)
    rust = _rust("Chp")
    parts = []
    # A run of links snaking over itself, each turned a quarter from the last, lying as they fell.
    x, y, z, heading = -2.2, -1.0, 0.36, 0.3
    for k in range(11):
        heading += rng.uniform(-0.7, 0.9)
        x += math.cos(heading) * 0.95
        y += math.sin(heading) * 0.95
        if math.hypot(x, y) > 2.6:
            heading += math.pi * 0.7
        # (a link standing on edge sinks a little into the junk; one lying flat rests on its bar; the middle ones ride
        # over the others)
        over = (0.55 if 3 <= k <= 6 else 0.0) * math.sin((k - 3) / 3 * math.pi)
        lift = (0.17 if k % 2 else 0.6) + over
        rot = (90.0 if k % 2 else 0.0, 0.0, math.degrees(heading) + 90.0)
        link = chain_link(f"Link{k}", (x, y, lift), 1.5, 0.95, 0.17, rust, rot=(rot[0] + rng.uniform(-12, 12), rot[1],
                                                                              rot[2]))
        parts.append(weathered(link, FORGED))
    return parts, [], {"finish": fill_gaps}


GREAT_LINK = (10.0, 6.0, 1.2)  # a link of the great chain: its length, its width, its bar's radius
GREAT_LINKS = 23


@prop("GreatChain", pivot="bottom", material="Metal", collide=True, texture=256, set="Lobby", tiled=True)
def great_chain():
    """The colossal chain hanging out of the sky into the Chain Heap (and, far off, into heaps of junk on the plain):
    links as tall as a house, each turned a quarter from the next, its foot in the junk; worn dark iron (the maps' own
    surface, laid in its repeats)."""
    mat = surface("DarkMetal")
    length, width, bar = GREAT_LINK
    pitch = length - bar * 2.2
    parts = []
    for k in range(GREAT_LINKS):
        z = length / 2 + k * pitch
        parts.append(chain_link(f"Link{k}", (0.0, 0.0, z), length, width, bar, mat, rot=(0, 0, 90 * (k % 2) + 6 * k),
                                segments=24))
    return parts, []


# Grass ----------------------------------------------------------------------------------------------------------------


@prop("SpikeGrass", pivot="bottom", material="Grass", collide=False, texture=256, set="Lobby")
def spike_grass():
    """A clump of the realm's dead grass: stiff pale blades fanning up and out from one root and curving over, sharp at
    their tips, the oldest ones broken and lying."""
    rng = random.Random(31)
    pale = mk.noisy("Spg_Blade", srgb(118, 116, 108), srgb(176, 172, 160), scale=10, roughness=0.9)
    dry = mk.noisy("Spg_Dry", srgb(84, 82, 76), srgb(128, 124, 114), scale=10, roughness=0.92)
    parts = [mk.sphere("Root", 0.22, (0.0, 0.0, 0.02), scale=(1.0, 1.0, 0.5), mat=dry, segments=10, rings=6)]
    for k in range(18):
        a = math.tau * k / 18 + rng.uniform(-0.15, 0.15)
        tilt = rng.uniform(0.15, 0.85)
        h = rng.uniform(1.0, 2.0) * (1.0 - 0.35 * tilt)
        pts, radii = [], []
        for q in range(6):
            u = q / 5
            out = math.sin(tilt) * h * u * (0.6 + 0.6 * u)
            pts.append((math.cos(a) * (0.05 + out), math.sin(a) * (0.05 + out), math.cos(tilt) * h * u - 0.25 * u * u * tilt))
            radii.append(0.05 * (1.0 - u) + 0.004)
        blade = pk.sweep(f"Blade{k}", pts, radii, pale if k % 3 else dry, sides=4)
        parts.append(blade)
    for k in range(3):
        a = rng.uniform(0, math.tau)
        pts = [(math.cos(a) * 0.1, math.sin(a) * 0.1, 0.04), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.06),
               (math.cos(a + 0.2) * 1.5, math.sin(a + 0.2) * 1.5, 0.04)]
        parts.append(pk.sweep(f"Fallen{k}", pts, [0.04, 0.03, 0.006], dry, sides=4))
    return parts, []
