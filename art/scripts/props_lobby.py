"""The lobby's props (set "Lobby", exported to DeathsGambitModels_Lobby.fbx): the Grey Realm, the ashen
wasteland beyond the world where the Grimoire comes from.

- What the game dresses: the Academy's practice altar (round the game's invisible drill desk), the
  three puppets the drills point at (round the practice dummies) and the hand above that holds their
  strings.
- The wasteland: two kinds of dead tree, a withered apple tree still hung with a few dull grey-brown apples,
  skull piles and scattered bones, a colossal horned skull, stone cairns.
- Fire and light: bone braziers burning pale, a crooked lantern post, candle clusters.
- Its dwellers' things: the bone throne.

Built to the semi-real standard (propkit): real sizes at about 3.5 studs to the metre, bevelled
edges, baked colour and ambient occlusion. Props face -Y and stand on z = 0. Every glow material
has a name of its own per colour (modelkit reuses a material by name within a build)."""

import math
import random

import bpy
from mathutils import Matrix, Vector

import common

import modelkit as mk
import propkit as pk
from common import srgb
from props import piece, prop

PALE_FIRE = (196, 222, 255)  # the realm's fire: cold, blue-white
CANDLE = (232, 226, 214)  # a candle's light here is pale and neutral, nothing warm lives in the realm


def bone_mat(prefix):
    return mk.noisy(prefix + "_Bone", srgb(158, 152, 136), srgb(212, 206, 188), scale=16, roughness=0.75)


def old_bone_mat(prefix):
    return mk.noisy(prefix + "_OldBone", srgb(112, 106, 94), srgb(164, 156, 138), scale=12, roughness=0.85)


def stone_mat(prefix):
    return mk.noisy(prefix + "_Stone", srgb(70, 70, 72), srgb(112, 110, 108), scale=10, roughness=0.92)


def dark_stone_mat(prefix):
    return mk.noisy(prefix + "_DarkStone", srgb(40, 40, 44), srgb(66, 66, 70), scale=12, roughness=0.9)


def bark_mat(prefix):
    return mk.noisy(prefix + "_Bark", srgb(34, 32, 32), srgb(72, 68, 66), scale=11, roughness=0.95, stretch=(1, 1, 0.3))


def iron_mat(prefix):
    return pk.metal(prefix + "_Iron", (24, 24, 26), (48, 46, 46), rough=0.7, metallic=0.6)


def void_mat(prefix):
    return mk.flat(prefix + "_Void", srgb(8, 8, 10), roughness=0.95)


# Bones -------------------------------------------------------------------------------------------------


def long_bone(name, a, b, r, mat):
    """A long bone from a to b: the shaft and a double knob at each end."""
    ax, ay, az = a
    bx, by, bz = b
    length = math.dist(a, b)
    ux, uy, uz = (bx - ax) / length, (by - ay) / length, (bz - az) / length
    # A side step across the bone for the paired knobs.
    sx, sy = -uy, ux
    s = math.hypot(sx, sy) or 1.0
    sx, sy = sx / s * r * 0.9, sy / s * r * 0.9
    parts = [mk.tube(name, a, b, r, r * 0.9, mat=mat, verts=8)]
    for (px, py, pz) in (a, b):
        for k in (-1, 1):
            parts.append(mk.sphere(name + "Knob", r * 1.55, (px + sx * k, py + sy * k, pz), mat=mat, segments=8,
                                   rings=6))
    return parts


def skull(prefix, x, y, z, r, mat, dark, yaw=0.0, jaw=True):
    """A human skull of cranium radius r, its face towards -Y turned by yaw degrees about Z: the
    domed cranium, cheekbones, the dark eye sockets and nose, the jaw with its teeth."""
    a = math.radians(yaw)

    def at(lx, ly, lz):
        return (x + lx * math.cos(a) - ly * math.sin(a), y + lx * math.sin(a) + ly * math.cos(a), z + lz)

    parts = [mk.sphere(prefix + "Cranium", r, at(0, 0.1 * r, 0.15 * r), scale=(0.9, 1.08, 0.95), mat=mat, segments=14,
                       rings=10),
             mk.sphere(prefix + "Face", r * 0.62, at(0, -0.62 * r, -0.28 * r), scale=(1.05, 0.7, 0.9), mat=mat, segments=10,
                       rings=8)]
    for k in (-1, 1):
        parts.append(mk.sphere(prefix + "Eye", r * 0.22, at(k * 0.32 * r, -0.95 * r, -0.12 * r), scale=(1.1, 0.6, 1.0),
                               mat=dark, segments=8, rings=6))
        parts.append(mk.sphere(prefix + "Cheek", r * 0.2, at(k * 0.55 * r, -0.72 * r, -0.36 * r), mat=mat, segments=6,
                               rings=4))
    parts.append(mk.sphere(prefix + "Nose", r * 0.1, at(0, -1.0 * r, -0.4 * r), scale=(0.9, 0.6, 1.4), mat=dark, segments=6,
                           rings=4))
    if jaw:
        parts.append(mk.box(prefix + "Jaw", (0.78 * r, 0.62 * r, 0.26 * r), at(0, -0.7 * r, -0.74 * r), rot=(0, 0, yaw),
                            mat=mat, bevel=0.1 * r))
        parts.append(mk.box(prefix + "Teeth", (0.62 * r, 0.06 * r, 0.12 * r), at(0, -1.0 * r, -0.6 * r), rot=(0, 0, yaw),
                            mat=mat))
    return parts


def beast_skull(prefix, x, y, z, s, mat, dark, horn, jaw=True):
    """A colossal horned beast's skull, s times the size of a 1-stud model, facing -Y: a low, long
    head like a great ram's or a dragon's. The braincase at the back, the long tapering muzzle, deep
    sockets under heavy brows, cheekbone arches, the lower jaw hanging a little open with its teeth,
    and the horns curling out, back and up."""
    parts = [mk.sphere(prefix + "Vault", 0.95 * s, (x, y + 0.75 * s, z + 0.45 * s), scale=(0.9, 1.0, 0.72), mat=mat,
                       segments=18, rings=12)]
    # The muzzle: one long turned shape tapering to the tip, flattened.
    muzzle = mk.lathe(prefix + "Muzzle", [(0.0, -0.4 * s), (0.6 * s, -0.2 * s), (0.72 * s, 0.3 * s), (0.64 * s, 1.0 * s),
                                          (0.52 * s, 1.7 * s), (0.42 * s, 2.3 * s), (0.3 * s, 2.75 * s), (0.0, 2.95 * s)],
                      (x, y + 0.3 * s, z + 0.25 * s), mat=mat, segments=16)
    muzzle.rotation_euler = (math.radians(90), 0, 0)
    muzzle.scale = (0.9, 0.62, 1.0)
    parts.append(muzzle)
    parts.append(mk.box(prefix + "Crest", (0.2 * s, 2.2 * s, 0.14 * s), (x, y - 0.9 * s, z + 0.6 * s), rot=(-9, 0, 0),
                        mat=mat, bevel=0.06 * s))
    for k in (-1, 1):
        # Brow, socket, cheekbone arch.
        parts.append(mk.tube(prefix + "Brow", (x + k * 0.3 * s, y - 0.3 * s, z + 0.7 * s),
                             (x + k * 0.72 * s, y + 0.0 * s, z + 0.76 * s), 0.16 * s, 0.13 * s, mat=mat, verts=8))
        parts.append(mk.sphere(prefix + "Socket", 0.3 * s, (x + k * 0.55 * s, y - 0.12 * s, z + 0.5 * s),
                               scale=(0.9, 1.0, 0.72), mat=dark, segments=10, rings=8))
        parts.append(mk.tube(prefix + "Arch", (x + k * 0.45 * s, y - 0.7 * s, z + 0.12 * s),
                             (x + k * 0.8 * s, y + 0.5 * s, z + 0.2 * s), 0.12 * s, 0.15 * s, mat=mat, verts=8))
        parts.append(mk.sphere(prefix + "Nostril", 0.1 * s, (x + k * 0.12 * s, y - 2.45 * s, z + 0.38 * s),
                               scale=(0.8, 1.3, 0.6), mat=dark, segments=6, rings=4))
        # The horns: curving out, back and up in tapering segments.
        pts = [(x + k * 0.7 * s, y + 0.55 * s, z + 0.95 * s)]
        for t in range(1, 8):
            u = t / 7
            pts.append((x + k * (0.7 + 1.9 * u) * s, y + (0.55 + 1.3 * u + 0.3 * u * u) * s,
                        z + (0.95 + 1.35 * u - 1.1 * u * u * u) * s))
        for t in range(7):
            r0 = 0.3 * s * (1 - t / 7.5)
            r1 = 0.3 * s * (1 - (t + 1) / 7.5)
            parts.append(mk.tube(prefix + "Horn", pts[t], pts[t + 1], r0, max(0.02, r1), mat=horn, verts=8))
        # Teeth down each side of the upper jaw.
        for t in range(6):
            ty = y - (0.3 + t * 0.4) * s
            parts.append(mk.cylinder(prefix + "Tooth", 0.07 * s, 0.34 * s, (x + k * (0.44 - t * 0.04) * s, ty, z - 0.2 * s),
                                     rot=(180, 0, 0), mat=mat, verts=6, radius2=0.01 * s))
    if jaw:
        # The lower jaw, dropped open a little: two long rami meeting at the chin, their teeth up.
        chin = (x, y - 2.45 * s, z - 0.62 * s)
        for k in (-1, 1):
            back = (x + k * 0.72 * s, y + 0.55 * s, z - 0.25 * s)
            mid = (x + k * 0.5 * s, y - 1.0 * s, z - 0.55 * s)
            parts.append(mk.tube(prefix + "Jaw", back, mid, 0.2 * s, 0.17 * s, mat=mat, verts=8))
            parts.append(mk.tube(prefix + "Jaw", mid, chin, 0.17 * s, 0.14 * s, mat=mat, verts=8))
            for t in range(5):
                u = (t + 0.5) / 5
                tx = x + k * (0.5 - 0.42 * u) * s
                ty = y + (-1.0 - 1.4 * u) * s
                parts.append(mk.cylinder(prefix + "JawTooth", 0.06 * s, 0.3 * s, (tx, ty, z - 0.36 * s), mat=mat, verts=6,
                                         radius2=0.01 * s))
        parts.append(mk.sphere(prefix + "Chin", 0.2 * s, chin, scale=(1.2, 1, 0.8), mat=mat, segments=8, rings=6))
    return parts


# Trees -------------------------------------------------------------------------------------------------


def _branch(parts, rng, start, direction, length, radius, depth, bark, spread, rise, twist, tips):
    """A twisted limb: three bent, tapering tubes, then its children."""
    dx, dy, dz = direction
    pts = [start]
    for k in range(1, 4):
        u = k / 3
        jitter = length * 0.12
        pts.append((start[0] + dx * length * u + rng.uniform(-jitter, jitter),
                    start[1] + dy * length * u + rng.uniform(-jitter, jitter),
                    start[2] + dz * length * u + rng.uniform(-jitter, jitter) * 0.6))
    tip_r = radius * 0.58
    verts = 7 if radius > 0.3 else 5
    for k in range(3):
        r0 = radius + (tip_r - radius) * k / 3
        r1 = radius + (tip_r - radius) * (k + 1) / 3
        parts.append(mk.tube("Limb", pts[k], pts[k + 1], r0, r1, mat=bark, verts=verts))
    end = pts[-1]
    if depth == 0:
        tips.append((end, (dx, dy, dz)))
        return
    base = math.atan2(dy, dx) + twist
    count = rng.choice((2, 2, 3))
    for k in range(count):
        yaw = base + rng.uniform(-spread, spread) + (k - (count - 1) / 2) * spread
        pitch = math.atan2(dz, math.hypot(dx, dy)) + rng.uniform(-0.35, 0.25) + rise
        pitch = max(-0.5, min(1.3, pitch))
        nd = (math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch))
        _branch(parts, rng, end, nd, length * rng.uniform(0.55, 0.75), tip_r, depth - 1, bark, spread, rise, twist, tips)


def _roots(parts, rng, r, bark, count=5):
    for k in range(count):
        a = 2 * math.pi * k / count + rng.uniform(-0.3, 0.3)
        reach = r * rng.uniform(2.2, 3.2)
        mid = (math.cos(a) * reach * 0.55, math.sin(a) * reach * 0.55, 0.35)
        end = (math.cos(a) * reach, math.sin(a) * reach, -0.1)
        parts.append(mk.tube("Root", (0, 0, 1.2), mid, r * 0.55, r * 0.3, mat=bark, verts=6))
        parts.append(mk.tube("Root", mid, end, r * 0.3, r * 0.08, mat=bark, verts=5))


def dead_tree(seed, prefix, height, lean, limbs, spread, rise, twist):
    rng = random.Random(seed)
    bark = bark_mat(prefix)
    parts, tips = [], []
    r = 0.9
    _roots(parts, rng, r, bark)
    # The trunk: bent in three pieces, leaning.
    pts = [(0, 0, 0)]
    for k in range(1, 4):
        u = k / 3
        pts.append((lean[0] * u * u + rng.uniform(-0.4, 0.4), lean[1] * u * u + rng.uniform(-0.4, 0.4), height * 0.55 * u))
    for k in range(3):
        parts.append(mk.tube("Trunk", pts[k], pts[k + 1], r * (1 - 0.18 * k), r * (1 - 0.18 * (k + 1)), mat=bark, verts=9))
    parts.append(mk.cylinder("Flare", r * 1.7, 1.2, (0, 0, 0.6), mat=bark, verts=9, radius2=r))
    head = pts[-1]
    for k in range(limbs):
        yaw = 2 * math.pi * k / limbs + rng.uniform(-0.4, 0.4)
        pitch = rng.uniform(0.35, 0.8)
        d = (math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch))
        start = pts[2] if k % 2 else head
        _branch(parts, rng, start, d, height * rng.uniform(0.26, 0.34), r * 0.5, 2, bark, spread, rise, twist, tips)
    # A knot hole and a broken stub.
    parts.append(mk.sphere("Knot", 0.35, (pts[1][0], pts[1][1] - r * 0.85, pts[1][2] + 0.4), scale=(1, 0.5, 1.3),
                           mat=void_mat(prefix), segments=8, rings=6))
    return parts, tips


# The realm's pines (2026-10-16, after Japanese black pines bent by the sea wind, and the way an ink brush draws
# them): a thick trunk curving away from the wind, a few limbs reaching nearly level the same way, and on their
# ends flat clouds of needles, layered, almost black against the grey sky. Same keys, sizes and places as the dead
# trees they replace.
def _needle_pad(parts, rng, centre, size, mat, prefix):
    """A cloud of needles: overlapping flattened lumps, its underside flat, its edge ragged."""
    cx, cy, cz = centre
    for k in range(rng.randint(4, 6)):
        r = size * rng.uniform(0.36, 0.56)
        at = (cx + rng.uniform(-0.5, 0.5) * size, cy + rng.uniform(-0.45, 0.45) * size, cz + rng.uniform(-0.06, 0.16) * size)
        lump = mk.sphere(prefix + "Pad", r, at, scale=(1.0, 0.85, 0.36), mat=mat, segments=12, rings=6)
        mk.displace_noise(lump, strength=r * 0.24, scale=r * 0.38, name=prefix + "Needles")
        parts.append(lump)


def black_pine(seed, prefix, height, lean, limbs, reach, droop):
    """A wind-bent black pine `height` tall, its top `lean` (x, y) downwind of its foot."""
    rng = random.Random(seed)
    bark = mk.noisy(prefix + "_Bark", srgb(22, 20, 20), srgb(50, 46, 44), scale=10, roughness=0.95, stretch=(1, 1, 0.35))
    needles = mk.noisy(prefix + "_Needles", srgb(12, 15, 13), srgb(32, 38, 33), scale=14, roughness=0.9)
    parts = []
    r = 0.82
    _roots(parts, rng, r, bark, count=4)
    parts.append(mk.cylinder("Flare", r * 1.6, 1.1, (0, 0, 0.55), mat=bark, verts=9, radius2=r))
    # The trunk: five pieces curving away from the wind and back, as a pine's does.
    wind = math.atan2(lean[1], lean[0])
    side = (-math.sin(wind), math.cos(wind))
    pts = [(0.0, 0.0, 0.0)]
    for k in range(1, 6):
        u = k / 5
        sway = math.sin(u * math.pi * 1.4) * 0.7
        pts.append((lean[0] * u ** 1.5 + side[0] * sway, lean[1] * u ** 1.5 + side[1] * sway, height * 0.8 * u))
    for k in range(5):
        parts.append(mk.tube("Trunk", pts[k], pts[k + 1], r * (1 - 0.12 * k), r * (1 - 0.12 * (k + 1)), mat=bark, verts=9))
    # The limbs: nearly level, most of them downwind, the short ones upwind; a pad at each end, sometimes one
    # more along the way.
    for k in range(limbs):
        start = pts[3 + k % 3]  # (from the upper trunk: lower down, the pads heaped into a bush)
        downwind = k % 3 != 2
        yaw = wind + (rng.uniform(-0.9, 0.9) if downwind else math.pi + rng.uniform(-0.6, 0.6))
        length = reach * rng.uniform(0.7, 1.0) * (1.0 if downwind else 0.45)
        d = (math.cos(yaw), math.sin(yaw))
        prev = start
        rr = r * 0.42
        for q in range(1, 4):
            u = q / 3
            p = (start[0] + d[0] * length * u, start[1] + d[1] * length * u,
                 start[2] + length * (0.18 * u - droop * u * u) + rng.uniform(-0.2, 0.2))
            parts.append(mk.tube("Limb", prev, p, rr * (1 - 0.25 * (q - 1)), rr * (1 - 0.25 * q), mat=bark, verts=6))
            prev = p
        _needle_pad(parts, rng, (prev[0], prev[1], prev[2] + 0.5), rng.uniform(2.4, 3.4) * (1.0 if downwind else 0.7),
                    needles, prefix)
        if downwind and rng.random() < 0.5:
            mid = (start[0] + d[0] * length * 0.55, start[1] + d[1] * length * 0.55, start[2] + length * 0.04 + 0.5)
            _needle_pad(parts, rng, mid, rng.uniform(1.6, 2.2), needles, prefix)
    # The crown: a flat pad over the trunk's top, a smaller one above it.
    top = pts[-1]
    _needle_pad(parts, rng, (top[0], top[1], top[2] + 0.6), 3.4, needles, prefix)
    _needle_pad(parts, rng, (top[0] + lean[0] * 0.15, top[1] + lean[1] * 0.15, top[2] + 1.9), 2.2, needles, prefix)
    return parts


@prop("DeadTree", pivot="bottom", material="Wood", collide=False, texture=1024, set="Lobby", anchor=(0, 0))
def dead_tree_tall():
    """A tall black pine of the wasteland (the key is the dead tree's it replaced): a trunk curving away from
    the wind, its limbs reaching downwind, flat dark clouds of needles on their ends."""
    return black_pine(11, "Pnt", 15.5, (3.4, 1.6), 6, 6.2, 0.22), []


@prop("DeadTreeGnarled", pivot="bottom", material="Wood", collide=False, texture=1024, set="Lobby", anchor=(0, 0))
def dead_tree_gnarled():
    """A low black pine flattened by the wind (the key is the gnarled dead tree's it replaced): a squat trunk
    bent far over, its limbs spreading wide and flat, the kind the realm's dwellers hang their lanterns in."""
    return black_pine(23, "Png", 10.0, (5.0, -1.8), 5, 5.0, 0.3), []


@prop("WitheredAppleTree", pivot="bottom", material="Wood", collide=False, texture=1024, set="Lobby", anchor=(0, 0))
def withered_apple_tree():
    """The one fruit tree in the realm: grey and twisted like the rest, yet hung with a few dull,
    grey-brown apples, and two more fallen in the ash at its foot (one bitten)."""
    parts, tips = dead_tree(37, "Apl", 13.0, (0.6, 0.9), 5, 0.6, 0.05, 0.4)
    rng = random.Random(8)
    red = mk.noisy("Apl_Apple", srgb(58, 52, 48), srgb(104, 96, 88), scale=6, roughness=0.55)
    stem = mk.flat("Apl_Stem", srgb(40, 30, 22), 0.8)
    flesh = mk.flat("Apl_Flesh", srgb(176, 172, 164), 0.7)
    for k, ((tx, ty, tz), _) in enumerate(tips[::2][:9]):
        hang = rng.uniform(0.3, 0.7)
        parts.append(mk.tube("Stalk", (tx, ty, tz), (tx, ty, tz - hang), 0.03, mat=stem, verts=4))
        parts.append(mk.sphere("Apple", 0.42, (tx, ty, tz - hang - 0.38), scale=(1, 1, 0.9), mat=red, segments=12, rings=8))
    for k, (x, y) in enumerate(((2.2, -1.4), (-1.8, 1.9))):
        parts.append(mk.sphere("Fallen", 0.42, (x, y, 0.38), scale=(1, 1, 0.9), mat=red, segments=12, rings=8))
        parts.append(mk.tube("FallenStem", (x, y, 0.72), (x + 0.1, y, 0.9), 0.03, mat=stem, verts=4))
        if k == 0:
            parts.append(mk.sphere("Bite", 0.24, (x - 0.3, y - 0.2, 0.5), scale=(0.5, 1, 1), mat=flesh, segments=8, rings=6))
    return parts, []


# The wasteland ------------------------------------------------------------------------------------------


@prop("SkullPile", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Lobby")
def skull_pile():
    """A heap of skulls and long bones, the old ones half sunk in the ash at the bottom."""
    rng = random.Random(5)
    bone = bone_mat("Skp")
    old = old_bone_mat("Skp")
    dark = void_mat("Skp")
    ash = mk.noisy("Skp_Ash", srgb(80, 80, 82), srgb(112, 112, 114), scale=20, roughness=0.95)
    parts = [mk.sphere("Mound", 1.7, (0, 0, 0.1), scale=(1.1, 0.9, 0.42), mat=ash, segments=14, rings=8)]
    placed = [(-0.9, -0.5, 0.75, 0.45, 20), (0.8, -0.6, 0.7, 0.42, -25), (0.0, 0.5, 0.85, 0.46, 170),
              (-0.2, -0.3, 1.45, 0.44, 5), (1.3, 0.5, 0.55, 0.38, 70), (-1.4, 0.4, 0.5, 0.4, -80)]
    for k, (x, y, z, r, yaw) in enumerate(placed):
        parts += skull(f"S{k}", x, y, z, r, old if k < 2 else bone, dark, yaw=yaw, jaw=k % 2 == 0)
    for k in range(7):
        a = rng.uniform(0, math.tau)
        c = (rng.uniform(-1.2, 1.2), rng.uniform(-0.8, 0.8), rng.uniform(0.3, 0.9))
        half = rng.uniform(0.7, 1.1)
        d = (math.cos(a) * half, math.sin(a) * half, rng.uniform(-0.25, 0.25))
        parts += long_bone("Bone", (c[0] - d[0], c[1] - d[1], c[2] - d[2]), (c[0] + d[0], c[1] + d[1], c[2] + d[2]), 0.09,
                           bone if k % 2 else old)
    return parts, []


@prop("BoneScatter", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Lobby")
def bone_scatter():
    """Bones lying loose in the ash: a skull on its side, a jaw, ribs and long bones."""
    rng = random.Random(14)
    bone = bone_mat("Bsc")
    old = old_bone_mat("Bsc")
    dark = void_mat("Bsc")
    parts = skull("Sk", 0.6, -0.3, 0.36, 0.4, bone, dark, yaw=35, jaw=False)
    for k in range(6):
        a = rng.uniform(0, math.tau)
        c = (rng.uniform(-1.8, 1.8), rng.uniform(-1.6, 1.6), 0.1)
        half = rng.uniform(0.5, 1.0)
        d = (math.cos(a) * half, math.sin(a) * half, 0)
        parts += long_bone("Bone", (c[0] - d[0], c[1] - d[1], 0.1), (c[0] + d[0], c[1] + d[1], 0.1), 0.08,
                           old if k % 2 else bone)
    for k in range(3):
        cx, cy = -1.0 + k * 0.35, 1.0
        pts = [(cx + math.cos(t / 5 * math.pi) * 0.8, cy + math.sin(t / 5 * math.pi) * 0.4, 0.08) for t in range(6)]
        for t in range(5):
            parts.append(mk.tube("Rib", pts[t], pts[t + 1], 0.06, 0.05, mat=old, verts=5))
    return parts, []


@prop("GiantSkull", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Lobby")
def giant_skull():
    """The skull of a dead death god, the size of a house, settled into the ash on its open jaw (2026-10-16; the
    key is the beast's skull it replaced, same size and place): a tall narrow vault, a long muzzle, sockets so
    deep they are black, heavy brows and cheek arches, two horns broken off at the stump, a crest of small spines
    down the crown, the long jaw dropped open with its fangs."""
    bone = old_bone_mat("Gsk")
    pale = bone_mat("Gsk")
    horn = mk.noisy("Gsk_Horn", srgb(30, 27, 26), srgb(70, 64, 58), scale=8, roughness=0.85, stretch=(1, 1, 0.4))
    dark = void_mat("Gsk")
    # (Builder coordinates: it faces -Y, its jaw on the ground.)
    head = [
        ("ellipsoid", (0.0, 5.2, 8.2), 6.2, (0.72, 1.18, 0.9)),  # the vault
        ("ellipsoid", (0.0, -5.6, 6.2), 3.6, (0.66, 1.75, 0.62)),  # the muzzle
        ("capsule", (-4.6, -0.6, 9.4), (4.6, -0.6, 9.4), 1.7),  # the brows
        ("capsule", (-3.9, -3.2, 5.0), (-4.9, 3.6, 5.6), 1.05),  # the cheek arches
        ("capsule", (3.9, -3.2, 5.0), (4.9, 3.6, 5.6), 1.05),
        ("ellipsoid", (0.0, 11.0, 6.6), 3.2, (0.9, 0.7, 0.9)),  # the back of the skull, over the spine's socket
        ("hollow", (-2.7, -1.6, 7.9), 2.25, (1.0, 0.9, 1.2)),  # the sockets
        ("hollow", (2.7, -1.6, 7.9), 2.25, (1.0, 0.9, 1.2)),
        ("hollow", (0.0, -8.4, 6.9), 1.1, (0.6, 1.4, 1.2)),  # the nose
    ]
    parts = [_blob("GskHead", head, 0.55, 0.45, bone)]
    skull = _surfaces(parts[0])
    # Deep in the sockets and the nose, black.
    for x in (-2.7, 2.7):
        parts.append(mk.sphere("Socket", 1.6, (x, -0.6, 7.8), scale=(1.0, 0.8, 1.15), mat=dark, segments=12, rings=8))
    parts.append(mk.sphere("Nose", 0.75, (0.0, -7.8, 6.8), scale=(0.6, 1.1, 1.1), mat=dark, segments=8, rings=6))
    # The horns, broken off: thick stumps curving back, their ends snapped and splintered.
    for sx in (-1, 1):
        base, mid, end = (sx * 3.4, 0.6, 11.6), (sx * 4.6, 2.4, 13.4), (sx * 5.3, 4.4, 14.3)
        parts.append(mk.tube("HornStump", base, mid, 1.55, 1.3, mat=horn, verts=10))
        parts.append(mk.tube("HornStump", mid, end, 1.3, 1.08, mat=horn, verts=10))
        for k in range(4):
            a = math.tau * k / 4 + 0.4
            at = (end[0] + math.cos(a) * 0.6, end[1] + math.sin(a) * 0.5, end[2] + 0.3)
            parts.append(mk.cylinder("Splinter", 0.32, 0.9, at, rot=(18 * math.cos(a), 18 * math.sin(a), 0), mat=horn, verts=5,
                                     radius2=0.04))
    # A crest of small spines down the crown, each rooted 0.45 deep in the bone right under it. (They stood on the
    # vault's ellipsoid, which the blended head's surface sinks away from: pale spikes hovering over the crown, read as
    # more loose teeth, the owner's word of 2026-10-24.)
    for k in range(6):
        y = -0.4 + k * 2.3
        h = 1.6 - abs(k - 2) * 0.22
        top = skull.down(0.0, y, 40.0)
        if top is None:
            continue
        parts.append(mk.cylinder("Crest", 0.32, h, (0.0, y, top - 0.45 + h / 2), rot=(-14, 0, 0), mat=pale, verts=6,
                                 radius2=0.03))
    # The fangs of the upper jaw, long and uneven, each rooted 0.3 deep in the muzzle's underside right over it.
    # (They hung from one fixed height that the muzzle's curve rose away from, and near its tip there was no bone
    # over them at all: a row of spikes floating in the open mouth, the owner's screenshot of 2026-10-24.)
    rng = random.Random(29)
    for sx in (-1, 1):
        for k in range(7):
            y = -10.4 + k * 1.55
            length = rng.uniform(1.0, 2.2) * (1.25 if k == 1 else 1.0)
            root = None
            for step in range(7):  # (a little nearer the middle where the muzzle is too narrow there)
                x = sx * (1.7 - k * 0.05 - step * 0.25)
                under = skull.up(x, y, 1.0)
                if under is not None:
                    root = (x, under + 0.3)
                    break
            if root:
                parts.append(mk.cylinder("Fang", 0.26, length, (root[0], y, root[1] - length / 2), rot=(180, 0, 0),
                                         mat=pale, verts=6, radius2=0.03))
    # The jaw, dropped open and lying in the ash: two long rami meeting at the chin, fangs up, each rooted 0.3 deep in
    # the bone's top right under it.
    jaw = [("capsule", (-4.2, 6.4, 3.4), (-2.0, -6.0, 1.0), 1.15), ("capsule", (4.2, 6.4, 3.4), (2.0, -6.0, 1.0), 1.15),
           ("capsule", (-2.0, -6.0, 1.0), (0.0, -11.6, 0.9), 1.05), ("capsule", (2.0, -6.0, 1.0), (0.0, -11.6, 0.9), 1.05)]
    parts.append(_blob("GskJaw", jaw, 0.45, 0.45, bone))
    lower = _surfaces(parts[-1])
    for sx in (-1, 1):
        for k in range(6):
            u = (k + 0.5) / 6
            x0 = sx * (2.0 - 1.9 * u) if u > 0.5 else sx * (3.6 - 3.2 * u)
            y = -1.0 - 9.6 * u
            length = rng.uniform(0.8, 1.7)
            for dx in (0.0, -0.3, 0.3, -0.6, 0.6):
                top = lower.down(x0 + sx * dx, y, 8.0)
                if top is not None:
                    parts.append(mk.cylinder("JawFang", 0.22, length, (x0 + sx * dx, y, top - 0.3 + length / 2),
                                             mat=pale, verts=6, radius2=0.03))
                    break
    return parts, []


class _surfaces:
    """Where vertical rays meet a mesh (in the builder's own coordinates): up(x, y, from_z) the first surface above
    a point, down(x, y, from_z) the first below; None where the ray misses it."""

    def __init__(self, obj):
        from mathutils.bvhtree import BVHTree

        mesh = obj.data
        self.tree = BVHTree.FromPolygons([obj.matrix_world @ v.co for v in mesh.vertices],
                                         [list(p.vertices) for p in mesh.polygons])

    def _cast(self, x, y, z, dz):
        at, _, _, _ = self.tree.ray_cast(Vector((x, y, z)), Vector((0.0, 0.0, dz)), 40.0)
        return at.z if at is not None else None

    def up(self, x, y, from_z):
        return self._cast(x, y, from_z, 1.0)

    def down(self, x, y, from_z):
        return self._cast(x, y, from_z, -1.0)


@prop("Cairn", pivot="bottom", material="Slate", collide=True, texture=512, set="Lobby")
def cairn():
    """A cairn of flat grey stones, a long bone laid across its top: a waymark at the realm's edge."""
    rng = random.Random(3)
    stone = stone_mat("Crn")
    dark = dark_stone_mat("Crn")
    bone = bone_mat("Crn")
    parts = []
    z = 0.0
    r = 1.4
    for k in range(6):
        h = rng.uniform(0.45, 0.7)
        body = mk.cylinder(f"Stone{k}", r, h, (rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), z + h / 2),
                           rot=(rng.uniform(-5, 5), rng.uniform(-5, 5), rng.uniform(0, 90)), mat=stone if k % 2 else dark,
                           verts=9, bevel=0.1)
        parts.append(body)
        z += h * 0.92
        r *= 0.8
    parts += long_bone("TopBone", (-0.9, 0.1, z + 0.12), (0.9, -0.1, z + 0.12), 0.1, bone)
    return parts, []


# Fire and light -----------------------------------------------------------------------------------------


def pale_flame(name, x, y, z, r, h, key):
    """Tongues of pale fire rising from (x, y, z)."""
    glow = pk.glow(key, PALE_FIRE, 5)
    parts = [mk.cylinder(name, r, h, (x, y, z + h / 2), mat=glow, verts=8, radius2=0.02)]
    for k in range(3):
        a = k * 2.1
        parts.append(mk.cylinder(name, r * 0.55, h * 0.7, (x + math.cos(a) * r * 0.55, y + math.sin(a) * r * 0.55,
                                                           z + h * 0.35), mat=glow, verts=6, radius2=0.02))
    return parts


@prop("BoneBrazier", pivot="bottom", material="Metal", collide=True, texture=1024, set="Lobby",
      lights=[dict(at=(0, 0, 5.4), kind="point", color=PALE_FIRE, range=26, brightness=1.15)])
def bone_brazier():
    """A brazier burning with the realm's pale fire: a black iron bowl on three long bones lashed
    together with rope, embers glowing under the flames, ash spilled round its feet."""
    bone = bone_mat("Brz")
    iron = iron_mat("Brz")
    rope = mk.noisy("Brz_Rope", srgb(72, 66, 54), srgb(110, 100, 80), scale=30, roughness=0.95)
    ash = mk.noisy("Brz_Ash", srgb(70, 70, 72), srgb(104, 104, 106), scale=20, roughness=0.95)
    parts = [mk.cylinder("Ash", 1.5, 0.1, (0, 0, 0.05), mat=ash, verts=16, radius2=1.2)]
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.3
        foot = (math.cos(a) * 1.25, math.sin(a) * 1.25, 0.05)
        top = (math.cos(a) * 0.55, math.sin(a) * 0.55, 3.9)
        parts += long_bone(f"Leg{k}", foot, top, 0.11, bone)
    parts.append(mk.torus("Lash", 0.6, 0.08, (0, 0, 3.1), mat=rope, major_segments=16, minor_segments=5))
    parts.append(mk.torus("Lash2", 0.58, 0.07, (0, 0, 3.3), mat=rope, major_segments=16, minor_segments=5))
    parts += [mk.lathe("Bowl", [(0.3, 0.0), (1.05, 0.25), (1.35, 0.8), (1.42, 0.95), (1.3, 0.95), (0.95, 0.35), (0.0, 0.3)],
                       (0, 0, 3.85), mat=iron, segments=18),
              mk.torus("Rim", 1.38, 0.07, (0, 0, 4.8), mat=iron, major_segments=24, minor_segments=6)]
    for k in range(6):
        a = 2 * math.pi * k / 6
        parts.append(mk.cylinder("Spike", 0.06, 0.5, (math.cos(a) * 1.38, math.sin(a) * 1.38, 5.05), mat=iron, verts=6,
                                 radius2=0.0))
    glows = [mk.cylinder("Embers", 1.0, 0.2, (0, 0, 4.5), mat=pk.glow("Brz_Ember", (120, 150, 210), 3), verts=14)]
    glows += pale_flame("Flame", 0, 0, 4.55, 0.7, 1.9, "Brz_Flame")
    return parts, glows


@prop("LanternPost", pivot="bottom", material="Wood", collide=True, texture=512, set="Lobby", anchor=(0, 0),
      lights=[dict(at=(0, -1.9, 6.6), kind="point", color=PALE_FIRE, range=18, brightness=0.8)])
def lantern_post():
    """A crooked post of black wood driven into the ash, a hooked arm at its head, and hanging from
    it an iron cage lantern with a pale flame inside."""
    wood = bark_mat("Lnp")
    iron = iron_mat("Lnp")
    bone = bone_mat("Lnp")
    parts = [mk.tube("Post", (0, 0, -0.2), (0.15, 0.1, 4.5), 0.26, 0.22, mat=wood, verts=7),
             mk.tube("Post2", (0.15, 0.1, 4.5), (0.05, 0.0, 8.4), 0.22, 0.17, mat=wood, verts=7),
             mk.tube("Arm", (0.05, 0.0, 7.9), (0.05, -1.9, 8.3), 0.12, 0.09, mat=wood, verts=6),
             mk.tube("Brace", (0.1, 0.05, 6.8), (0.05, -1.1, 8.1), 0.07, mat=wood, verts=5),
             mk.cylinder("Collar", 0.3, 0.25, (0.02, 0.0, 1.0), mat=iron, verts=8),
             mk.tube("Chain", (0.05, -1.9, 8.2), (0.05, -1.9, 7.55), 0.03, mat=iron, verts=4)]
    parts += long_bone("Charm", (0.35, -0.22, 5.2), (0.3, -0.25, 6.1), 0.05, bone)
    cx, cy, cz = 0.05, -1.9, 6.6
    parts += [mk.cylinder("CageTop", 0.55, 0.2, (cx, cy, cz + 0.85), mat=iron, verts=8, radius2=0.2),
              mk.torus("Ring", 0.12, 0.03, (cx, cy, cz + 1.02), rot=(90, 0, 0), mat=iron, major_segments=8,
                       minor_segments=4),
              mk.cylinder("CageBase", 0.45, 0.14, (cx, cy, cz - 0.72), mat=iron, verts=8)]
    for k in range(6):
        a = 2 * math.pi * k / 6
        parts.append(mk.tube("Bar", (cx + math.cos(a) * 0.42, cy + math.sin(a) * 0.42, cz - 0.66),
                             (cx + math.cos(a) * 0.46, cy + math.sin(a) * 0.46, cz + 0.76), 0.03, mat=iron, verts=4))
    glows = pale_flame("Flame", cx, cy, cz - 0.6, 0.22, 0.9, "Lnp_Flame")
    glows.append(mk.sphere("Glow", 0.28, (cx, cy, cz - 0.2), scale=(1, 1, 1.4), mat=pk.glow("Lnp_Core", (225, 238, 255), 3),
                           segments=8, rings=6))
    return parts, glows


@prop("CandleCluster", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Lobby",
      lights=[dict(at=(0, 0, 1.6), kind="point", color=CANDLE, range=10, brightness=0.55)])
def candle_cluster():
    """Stub candles of every height melted together on a pool of old wax, most still burning."""
    rng = random.Random(21)
    wax = mk.noisy("Cnd_Wax", srgb(186, 178, 160), srgb(222, 216, 198), scale=14, roughness=0.6)
    wick = mk.flat("Cnd_Wick", srgb(20, 18, 16), 0.9)
    parts = [mk.cylinder("Pool", 0.9, 0.08, (0, 0, 0.04), mat=wax, verts=14, radius2=0.75)]
    glows = []
    flame = pk.glow("Cnd_Flame", CANDLE, 6)
    for k in range(7):
        a = k * 2.4
        rr = 0.15 + 0.5 * (k / 6)
        x, y = math.cos(a) * rr, math.sin(a) * rr
        h = rng.uniform(0.4, 1.5)
        r = rng.uniform(0.1, 0.16)
        parts.append(mk.cylinder(f"Candle{k}", r, h, (x, y, 0.06 + h / 2), mat=wax, verts=8))
        parts.append(mk.sphere(f"Drip{k}", r * 1.1, (x, y, 0.06 + h - 0.05), scale=(1, 1, 0.5), mat=wax, segments=8, rings=4))
        parts.append(mk.tube(f"Wick{k}", (x, y, 0.06 + h), (x, y, 0.06 + h + 0.08), 0.015, mat=wick, verts=3))
        if k != 3:
            glows.append(mk.sphere(f"Flame{k}", 0.06, (x, y, 0.06 + h + 0.17), scale=(1, 1, 2.2), mat=flame, segments=6,
                                   rings=4))
    return parts, glows


# The Academy ---------------------------------------------------------------------------------------------


@prop("PracticeAltar", pivot="bottom", material="Slate", collide=False, texture=1024, set="Lobby", anchor=(0, 0),
      lights=[dict(at=(0, 0.7, 4.0), kind="point", color=CANDLE, range=11, brightness=0.6)])
def practice_altar():
    """The Academy's practice altar, built round the game's invisible drill desk (5 x 3 x 2.4, the
    one practising stands at -Y): a slab of grey stone on two carved legs with skulls set in them,
    an old ledger lying open on it with a quill in its inkwell, and candles burning at the back."""
    stone = stone_mat("Alt")
    dark = dark_stone_mat("Alt")
    bone = bone_mat("Alt")
    void = void_mat("Alt")
    leather = mk.noisy("Alt_Leather", srgb(26, 20, 20), srgb(52, 38, 34), scale=14, roughness=0.7)
    pages = mk.banded("Alt_Pages", srgb(176, 166, 140), srgb(214, 206, 182), frequency=150, axis="Z")
    ink = mk.flat("Alt_Ink", srgb(14, 12, 12), 0.4)
    wax = mk.noisy("Alt_Wax", srgb(186, 178, 160), srgb(222, 216, 198), scale=14, roughness=0.6)
    parts = [mk.box("Plinth", (5.6, 2.9, 0.3), (0, 0, 0.15), mat=dark, bevel=0.06),
             mk.box("Slab", (5.2, 2.6, 0.42), (0, 0, 2.8), mat=stone, bevel=0.08),
             mk.box("Apron", (4.2, 2.1, 0.5), (0, 0, 2.35), mat=dark, bevel=0.05)]
    for sx in (-1, 1):
        parts += [mk.box("Leg", (1.1, 2.1, 2.1), (sx * 1.9, 0, 1.3), mat=stone, bevel=0.1),
                  mk.box("LegCap", (1.3, 2.3, 0.2), (sx * 1.9, 0, 2.28), mat=dark, bevel=0.04)]
        parts += skull(f"LegSkull{sx}", sx * 1.9, -1.02, 1.35, 0.34, bone, void)
    # The ledger lying open, the quill and the inkwell.
    for side in (-1, 1):
        parts.append(mk.box("Page", (1.25, 1.55, 0.12), (side * 0.66, -0.25, 3.09), rot=(0, side * -4, 0), mat=pages))
        parts.append(mk.box("Board", (1.35, 1.65, 0.06), (side * 0.68, -0.25, 3.03), rot=(0, side * -4, 0), mat=leather))
    parts.append(mk.cylinder("Spine", 0.08, 1.62, (0, -0.25, 3.06), rot=(90, 0, 0), mat=leather, verts=8))
    for k in range(4):
        parts.append(mk.box("Line", (0.9, 0.03, 0.01), (-0.66, -0.7 + k * 0.28, 3.16), mat=ink))
    parts += [mk.cylinder("Inkwell", 0.18, 0.3, (1.7, 0.4, 3.16), mat=ink, verts=10, radius2=0.12),
              mk.tube("Quill", (1.7, 0.4, 3.2), (2.0, 0.9, 4.2), 0.03, 0.01, mat=bone, verts=4),
              mk.box("Vane", (0.06, 0.2, 0.7), (1.9, 0.75, 3.95), rot=(-25, 0, 18), mat=bone)]
    glows = []
    flame = pk.glow("Alt_Flame", CANDLE, 6)
    for sx in (-1, 1):
        for k, (dx, h) in enumerate(((0.0, 0.9), (0.28, 0.55), (-0.25, 0.4))):
            x = sx * 2.05 + dx
            parts.append(mk.cylinder("Candle", 0.12, h, (x, 0.85, 3.01 + h / 2), mat=wax, verts=8))
            glows.append(mk.sphere("Flame", 0.06, (x, 0.85, 3.01 + h + 0.15), scale=(1, 1, 2.2), mat=flame, segments=6,
                                   rings=4))
    return parts, glows


# The Academy's puppets (the owner's reference of 2026-10-13: a wooden artist's mannequin on strings, held
# by a hand) -------------------------------------------------------------------------------------------------


def spindle(name, a, b, radii, mat, segments=12):
    """A turned limb from a to b, its radius at evenly spaced stations along it (radii[0] at a), the
    ends rounded off a little."""
    a, b = Vector(a), Vector(b)
    axis = b - a
    length = axis.length
    n = len(radii) - 1
    profile = [(radii[0] * 0.55, 0.0)]
    for k, r in enumerate(radii):
        profile.append((r, length * (0.06 + 0.88 * k / n)))
    profile.append((radii[-1] * 0.55, length))
    obj = mk.lathe(name, profile, mat=mat, segments=segments)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = axis.normalized().to_track_quat("Z", "Y")
    obj.location = a
    return obj


def squashed(obj, sx=1.0, sy=1.0, sz=1.0, about=(0.0, 0.0, 0.0)):
    """Scales a part's mesh about a point (builder coordinates), after it is placed."""
    about = Vector(about)
    obj.data.transform(obj.matrix_basis)
    obj.matrix_basis = Matrix.Identity(4)
    obj.data.transform(Matrix.Translation(about) @ Matrix.Diagonal((sx, sy, sz, 1.0)) @ Matrix.Translation(-about))
    return obj


def grid_rects(count, cols):
    """`count` cells of a texture in a grid `cols` wide, each with a little margin, as (u0, v0, u1, v1)."""
    rows = math.ceil(count / cols)
    w, h = 1.0 / cols, 1.0 / rows
    return [((k % cols) * w + 0.006, (k // cols) * h + 0.006, (k % cols + 1) * w - 0.006, (k // cols + 1) * h - 0.006)
            for k in range(count)]


# Where the puppet bends (builder coordinates: it faces -Y, its left is +X, its feet on z = 0). Each moving
# piece turns about the joint at its top, which is the ball it carries.
def puppet_joints():
    joints = {"waist": (0.0, 0.0, 3.98), "neck": (0.0, 0.0, 5.38)}
    for side, s in (("L", 1), ("R", -1)):
        joints["shoulder" + side] = (s * 0.74, 0.0, 5.06)
        joints["elbow" + side] = (s * 0.9, 0.02, 3.98)
        joints["wrist" + side] = (s * 1.02, 0.0, 2.92)
        joints["hip" + side] = (s * 0.34, 0.0, 3.42)
        joints["knee" + side] = (s * 0.32, -0.02, 2.04)
        joints["ankle" + side] = (s * 0.32, 0.04, 0.44)
    return joints


@prop("Puppet", pivot="bottom", material="Wood", collide=False, texture=512, set="Lobby")
def puppet():
    """One of the Academy's three practice puppets: a life-size wooden artist's mannequin, pale wood gone
    a little grey, a faceless egg of a head, a dark oval on its chest (where its name tag is pinned) and
    a ball at every joint. It hangs on strings from the hand above (the game draws the strings and moves
    the pieces: the pelvis is the prop itself, every other piece turns about the ball at its top)."""
    wood = mk.wood("Pup_Wood", srgb(206, 198, 182), srgb(156, 148, 132))
    ball = mk.wood("Pup_JointWood", srgb(168, 160, 146), srgb(122, 114, 102))
    oval = mk.flat("Pup_Oval", srgb(22, 21, 21), 0.85)
    j = puppet_joints()

    pelvis = [pk.rounded("Pelvis", (1.0, 0.62, 0.62), (0, 0, 3.6), wood, r=0.24)]
    chest = [squashed(mk.lathe("Chest", [(0.3, 4.1), (0.46, 4.16), (0.52, 4.35), (0.6, 4.7), (0.64, 4.95), (0.6, 5.15),
                                         (0.46, 5.28), (0.24, 5.34)], mat=wood, segments=16), sy=0.62),
             mk.sphere("Waist", 0.24, j["waist"], scale=(1.0, 0.8, 0.85), mat=ball, segments=12, rings=8),
             mk.sphere("Oval", 0.3, (0, -0.33, 4.62), scale=(0.9, 0.2, 1.22), mat=oval, segments=14, rings=8)]
    head = [mk.sphere("Neck", 0.13, j["neck"], mat=ball, segments=10, rings=6),
            mk.tube("NeckPeg", (0, 0, 5.3), (0, 0, 5.6), 0.1, 0.09, mat=wood, verts=10),
            squashed(mk.lathe("Head", [(0.16, 5.5), (0.27, 5.56), (0.33, 5.68), (0.36, 5.86), (0.355, 6.04), (0.31, 6.2),
                                       (0.22, 6.33), (0.1, 6.4)], loc=(0, -0.03, 0), mat=wood, segments=16), sy=0.94,
                     about=(0, -0.03, 0))]
    pieces = {"Chest": chest, "Head": head}
    hinge = {"Chest": j["waist"], "Head": j["neck"]}
    for side, s in (("L", 1), ("R", -1)):
        sh, el, wr = j["shoulder" + side], j["elbow" + side], j["wrist" + side]
        hp, kn, an = j["hip" + side], j["knee" + side], j["ankle" + side]
        pieces["UpperArm" + side] = [mk.sphere("Shoulder", 0.2, sh, mat=ball, segments=12, rings=8),
                                     spindle("UpperArm", sh, el, [0.16, 0.17, 0.15, 0.12], wood)]
        pieces["Forearm" + side] = [mk.sphere("Elbow", 0.14, el, mat=ball, segments=10, rings=8),
                                    spindle("Forearm", el, wr, [0.12, 0.14, 0.12, 0.09], wood)]
        pieces["Hand" + side] = [mk.sphere("Wrist", 0.1, wr, mat=ball, segments=10, rings=6),
                                 mk.sphere("Hand", 0.2, (wr[0] + s * 0.02, wr[1], wr[2] - 0.34), scale=(0.42, 0.85, 1.55),
                                           mat=wood, segments=12, rings=8)]
        pieces["Thigh" + side] = [mk.sphere("Hip", 0.23, hp, mat=ball, segments=12, rings=8),
                                  spindle("Thigh", hp, kn, [0.26, 0.29, 0.25, 0.19], wood)]
        pieces["Shin" + side] = [mk.sphere("Knee", 0.2, kn, mat=ball, segments=12, rings=8),
                                 spindle("Shin", kn, an, [0.18, 0.21, 0.17, 0.12], wood)]
        pieces["Foot" + side] = [mk.sphere("Ankle", 0.13, an, mat=ball, segments=10, rings=6),
                                 pk.rounded("Foot", (0.32, 0.8, 0.24), (s * 0.32, -0.16, 0.13), wood, r=0.1)]
        for name, joint in (("UpperArm", sh), ("Forearm", el), ("Hand", wr), ("Thigh", hp), ("Shin", kn),
                            ("Foot", an)):
            hinge[name + side] = joint
    # Not pieces: where the head's string is tied, and where the name tag is pinned (the oval's middle).
    hinge["HeadTop"] = (0, -0.03, 6.4)
    hinge["Tag"] = (0, -0.39, 4.62)
    # One texture: the pelvis and each piece in a cell of their own.
    rects = grid_rects(1 + len(pieces), 4)
    more = {
        "into": rects[0],
        "pieces": {name: piece(parts, into=rects[k + 1]) for k, (name, parts) in enumerate(pieces.items())},
        "hinge": hinge,
    }
    return pelvis, [], more


# The tableaux's statues (2026-10-16, after robed and veiled figures in stone): the game's stone figures wear this
# instead of plain blocks once the Lobby set is imported (client World/StoneFigures), one piece on each of the six
# R6 parts, so the tableaux keep their gestures and their short loops. Hooded, faceless, a long robe with its
# folds cut deep (the bake leaves ash dark in them), bell sleeves with blunt stone hands, the skirt in two halves
# that meet down the middle. Made standing at rest as R6 is: torso 2 x 2 x 1 at z 2..4, the arms beside it, the
# legs under it, the head over it; it faces -Y, its right is -X.
def _folds(obj, count, depth, z0, z1, phase=0.0, fade_top=True):
    """Cuts `count` vertical folds into a turned shape (its axis the object's local Z): pushed in and out by
    `depth`, fading out towards z1 (or towards both ends)."""
    for v in obj.data.vertices:
        x, y, z = v.co
        r = math.hypot(x, y)
        if r < 1e-4:
            continue
        u = min(1.0, max(0.0, (z - z0) / max(1e-6, z1 - z0)))
        w = (1.0 - u) if fade_top else math.sin(u * math.pi)
        k = depth * math.sin(count * math.atan2(y, x) + phase) * w
        v.co.x += x / r * k
        v.co.y += y / r * k


def _halved(obj, keep_sign, at=0.0):
    """Flattens a turned shape's far side onto the plane x = at (builder coordinates), so two halves meet there
    without passing through each other (where they did, the bake left both dark)."""
    for v in obj.data.vertices:
        if (v.co.x - at) * keep_sign < 0:
            v.co.x = at
    return obj


@prop("RobedStatue", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby")
def robed_statue():
    """A tableau's statue: a hooded, faceless figure in a long robe, cut in pale stone, in six pieces the game
    moves as it moves a body (the torso is the prop itself)."""
    stone = mk.noisy("Rst_Stone", srgb(118, 116, 112), srgb(166, 163, 156), scale=12, roughness=0.9, kind="stone")
    worn = mk.noisy("Rst_Worn", srgb(92, 90, 88), srgb(128, 125, 120), scale=14, roughness=0.92, kind="stone")
    void = void_mat("Rst")
    # The torso: the robe over the chest and shoulders, a cowl round the neck, a cord at the waist.
    body = mk.lathe("Robe", [(0.0, 1.92), (0.98, 1.92), (1.0, 2.3), (1.02, 2.9), (1.04, 3.4), (1.0, 3.8), (0.9, 3.98),
                             (0.62, 4.08), (0.0, 4.1)], mat=stone, segments=24)
    _folds(body, 7, 0.06, 1.92, 4.0)
    # A short mantle over the shoulders, the sleeves' tops under it.
    # (Every profile here runs from the bottom up: run downwards, a turned shape's faces look inwards.)
    mantle = mk.lathe("Mantle", [(0.0, 3.6), (1.36, 3.34), (1.56, 3.38), (1.46, 3.58), (1.02, 3.92), (0.66, 4.12),
                                 (0.0, 4.14)], mat=stone, segments=24)
    _folds(mantle, 9, 0.05, 3.34, 4.12)
    torso = [squashed(body, sx=0.98, sy=0.6), squashed(mantle, sy=0.66),
             squashed(mk.torus("Cowl", 0.6, 0.2, (0, 0, 4.02), mat=stone, major_segments=20, minor_segments=8), sy=0.72),
             squashed(mk.torus("Cord", 1.03, 0.06, (0, 0, 2.28), mat=worn, major_segments=24, minor_segments=6), sy=0.6)]
    # The head: the hood drawn forward over a face that is only shadow.
    hood = mk.lathe("Hood", [(0.6, 4.02), (0.78, 4.3), (0.84, 4.72), (0.8, 5.12), (0.62, 5.42), (0.32, 5.58), (0.0, 5.62)],
                    mat=stone, segments=20)
    _folds(hood, 5, 0.03, 4.02, 5.6, fade_top=False)
    head = [squashed(hood, sy=0.92),
            mk.sphere("Face", 0.5, (0, -0.5, 4.72), scale=(0.88, 0.62, 1.12), mat=void, segments=14, rings=10),
            mk.cylinder("Peak", 0.18, 0.5, (0, -0.42, 5.36), rot=(-62, 0, 0), mat=stone, verts=8, radius2=0.02)]
    pieces = {"Head": head}
    hinge = {"Head": (0.0, 0.0, 4.0)}
    for name, x in (("RightArm", -1.5), ("LeftArm", 1.5)):
        sleeve = mk.lathe("Sleeve", [(0.0, 2.04), (0.38, 2.04), (0.55, 2.08), (0.58, 2.2), (0.5, 2.9), (0.47, 3.5),
                                      (0.44, 3.8), (0.3, 3.93), (0.0, 3.97)], loc=(x, 0, 0), mat=stone, segments=16)
        _folds(sleeve, 5, 0.04, 2.0, 4.1)
        hand = mk.sphere("Hand", 0.3, (x, -0.04, 1.84), scale=(0.72, 0.9, 1.35), mat=worn, segments=12, rings=8)
        pieces[name] = [squashed(sleeve, sy=0.86, about=(x, 0, 0)), hand]  # (just clear of the robe's side)
        hinge[name] = (x * 2 / 3, 0.0, 3.5)
    for name, x in (("RightLeg", -0.5), ("LeftLeg", 0.5)):
        skirt = mk.lathe("Skirt", [(0.0, 0.02), (0.9, 0.02), (0.93, 0.12), (0.78, 0.72), (0.7, 1.4), (0.66, 2.02),
                                    (0.0, 2.06)], loc=(x, 0, 0), mat=stone, segments=18)
        _folds(skirt, 6, 0.07, 0.0, 2.05, phase=0.6 if x > 0 else 0.0)
        squashed(skirt, sy=0.82, about=(x, 0, 0))
        pieces[name] = [_halved(skirt, 1 if x > 0 else -1)]
        hinge[name] = (x * 2, 0.0, 2.0)
    for parts in [torso] + list(pieces.values()):
        for obj in parts:
            mk.displace_noise(obj, strength=0.018, scale=0.32, name="RstChips")
    rects = grid_rects(1 + len(pieces), 3)
    more = {
        "into": rects[0],
        "pieces": {name: piece(parts, into=rects[k + 1]) for k, (name, parts) in enumerate(pieces.items())},
        "hinge": hinge,
    }
    return torso, [], more


# The hand that holds the strings (builder coordinates; it is made flat, palm down, fingers towards -Y and
# the wrist towards +Y, then tilted, so the fingers hang down in front, like the reference's). Skin is one
# smooth surface: each piece is a metaball (balls and capsules that melt into one another, which gives the
# soft swell of knuckles and the heel of the palm), turned into a mesh and thinned.
HAND_SCALE = 1.15
HAND_TILT = 25.0  # degrees the hand is tipped forward about X (the knuckles go down, the wrist up)
# finger: (knuckle x, sideways lean per unit forward, phalanx lengths, base radius)
FINGERS = {
    "Index": (3.0, 0.13, (3.6, 2.4, 1.9), 0.92),
    "Middle": (1.0, 0.03, (4.0, 2.8, 2.1), 0.95),
    "Ring": (-1.1, -0.07, (3.7, 2.6, 2.0), 0.88),
    "Little": (-3.2, -0.2, (2.9, 1.9, 1.7), 0.75),
}
CURL = (30.0, 75.0, 105.0)  # each phalanx's angle below the palm's plane, knuckle to tip
BLOB = 0.575  # an element's surface radius, as a share of its field radius (stiffness 2, threshold 0.6)


def _blob(name, elements, resolution, keep, mat):
    """A smooth surface from metaball elements, as a mesh: ("ball", centre, radius), ("ellipsoid", centre,
    radius, (sx, sy, sz)), ("capsule", a, b, radius) or ("hollow", centre, radius, (sx, sy, sz)) (an ellipsoid
    that carves the others), radii being the surface's own. keep: the share of its triangles kept (decimated)."""
    meta = bpy.data.metaballs.new(name)
    meta.resolution = resolution
    meta.render_resolution = resolution
    meta.threshold = 0.6
    holder = bpy.data.objects.new(name, meta)
    common.collection("Build").objects.link(holder)
    for element in elements:
        if element[0] == "ball":
            _, centre, r = element
            el = meta.elements.new(type="BALL")
            el.co = centre
        elif element[0] in ("ellipsoid", "hollow"):
            _, centre, r, (sx, sy, sz) = element
            el = meta.elements.new(type="ELLIPSOID")
            el.co = centre
            el.size_x, el.size_y, el.size_z = sx, sy, sz
            el.use_negative = element[0] == "hollow"
        else:
            _, a, b, r = element
            a, b = Vector(a), Vector(b)
            el = meta.elements.new(type="CAPSULE")
            el.co = (a + b) / 2
            el.size_x = (b - a).length / 2
            el.rotation = Vector((1.0, 0.0, 0.0)).rotation_difference((b - a).normalized())
        el.radius = r / BLOB
        el.stiffness = 2.0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(holder.evaluated_get(depsgraph))
    bpy.data.objects.remove(holder, do_unlink=True)
    bpy.data.metaballs.remove(meta)
    mesh.name = name
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    common.collection("Build").objects.link(obj)
    mk.smooth(obj)
    if keep < 1.0:
        mod = obj.modifiers.new("Thin", "DECIMATE")
        mod.ratio = keep
    return obj


def _basis(origin, along, out, scale):
    """A matrix placing a unit shape at `origin`, its local Y along `along`, local Z towards `out`, scaled
    by `scale` (x, y, z)."""
    y = Vector(along).normalized()
    z = (Vector(out) - y * Vector(out).dot(y)).normalized()
    x = y.cross(z)
    rot = Matrix((x, y, z)).transposed().to_4x4()
    return Matrix.Translation(origin) @ rot @ Matrix.Diagonal((*scale, 1.0))


def _shaped(obj, matrix):
    obj.data.transform(matrix)
    obj.matrix_basis = Matrix.Identity(4)
    return obj


def _nail_and_tie(name, joint, d, length, r, back, nail, string):
    """The nail on the back of a last phalanx (from `joint`, along `d`), and the string's loop round it."""
    mid = joint + d * length * 0.62
    parts = [_shaped(mk.sphere(name + "Nail", 1.0, mat=nail, segments=12, rings=6),
                     _basis(mid + back * r * 0.86, d, back, (r * 0.74, length * 0.34, r * 0.2)))]
    tie = joint + d * length * 0.36
    loop = mk.torus(name + "Tie", r * 1.04, 0.05, mat=string, major_segments=16, minor_segments=4)
    loop.rotation_mode = "QUATERNION"
    loop.rotation_quaternion = d.to_track_quat("Z", "Y")
    loop.location = tie
    parts.append(loop)
    return parts, tie


def _finger(name, knuckle, lean, lengths, radius, skin, nail, string):
    """A finger curled down from its knuckle: three phalanges melting into one another, a nail and the
    string's tie round the last one. Returns the parts, the middle joint and the tie."""
    at = Vector(knuckle)
    r = radius
    elements = [("ball", tuple(at), r * 1.05)]
    joints = []
    for length, angle in zip(lengths, CURL):
        a = math.radians(angle)
        d = Vector((lean, -math.cos(a), -math.sin(a))).normalized()
        end = at + d * length
        elements.append(("capsule", tuple(at), tuple(end), r))
        joints.append((at, d, length, r))
        at = end
        r *= 0.86
    parts = [_blob("Mb" + name, elements, 0.2, 0.35, skin)]
    joint, d, length, r = joints[-1]
    a = math.radians(CURL[-1])
    back = Vector((0.0, -math.sin(a), math.cos(a)))
    more, tie = _nail_and_tie(name, joint, d, length, r * 0.92, back, nail, string)
    return parts + more, joints[1][0], tie


@prop("PuppeteerHand", pivot="centre", material="SmoothPlastic", collide=False, texture=512, set="Lobby")
def puppeteer_hand():
    """The hand above the Academy that holds the puppets' strings (the game's tagline: the fate Diavolo
    chose for you): one huge, pale human hand, palm down, its fingers hanging in front with a string tied
    round the tip of each, the wrist going into a dark robe's sleeve that rises behind into the dark.
    (2026-10-23: Roblox's moderation removed the first version's mesh, the palm and a long bare arm of
    smooth skin with no fingers on it (they are pieces of their own); that piece alone read wrongly. The
    skin now ends at the wrist, the arm is cloth: a sleeve with a flared cuff and its folds.)
    The thumb and each finger are pieces (they move); `hinge` also names each one's tip and middle joint,
    where the game ties the strings, Anchor (the middle of the fingertips), ArmEnd and Above."""
    skin = mk.noisy("Hand_Skin", srgb(168, 160, 152), srgb(214, 207, 199), roughness=0.5)
    nail = mk.flat("Hand_Nail", srgb(194, 184, 180), 0.35)
    string = mk.flat("Hand_String", srgb(196, 192, 182), 0.8)
    # The palm and the back of the hand: a slab of melted balls, the knuckles' row along its front, the
    # heel of the palm under the thumb and the little finger.
    palm = [("ellipsoid", (x, y, 0.0), 2.3, (1.0, 1.0, 0.6)) for x in (-2.2, 0.0, 2.2) for y in (-2.4, 0.4)]
    for finger, (x, _, _, r) in FINGERS.items():
        palm.append(("ball", (x, -4.25, 0.15), r * 1.12))
    palm += [("ball", (3.2, 1.3, -0.55), 1.75), ("ball", (-3.2, 1.5, -0.35), 1.45),
             ("ball", (0.0, 3.4, 0.0), 2.05)]
    main = [_blob("MbPalm", palm, 0.42, 0.3, skin)]
    # The sleeve: dark cloth from just behind the wrist, rising behind into the dark, a little wider as it goes;
    # a flared cuff round the wrist, a hem at its edge, and soft folds round it.
    arm_from, arm_to = Vector((0.0, 3.0, 0.05)), Vector((0.0, 21.0, 1.9))
    cloth = mk.noisy("Hand_Sleeve", srgb(24, 24, 28), srgb(48, 47, 54), scale=5.0, roughness=0.92)
    hem = mk.flat("Hand_Hem", srgb(62, 58, 60), 0.85)
    axis = (arm_to - arm_from).normalized()
    sleeve = [mk.tube("Sleeve", tuple(arm_from + axis * 1.2), tuple(arm_to), 3.0, 3.7, mat=cloth, verts=12),
              mk.tube("Cuff", tuple(arm_from - axis * 0.3), tuple(arm_from + axis * 2.2), 3.9, 3.15, mat=cloth,
                      verts=12)]
    edge = mk.torus("CuffHem", 3.85, 0.22, mat=hem, major_segments=24, minor_segments=6)
    edge.rotation_mode = "QUATERNION"
    edge.rotation_quaternion = axis.to_track_quat("Z", "Y")
    edge.location = arm_from - axis * 0.25
    sleeve.append(edge)
    for k, t in enumerate((0.3, 0.52, 0.74)):
        at = arm_from.lerp(arm_to, t)
        fold = mk.torus(f"Fold{k}", 3.05 + 0.7 * t, 0.3, mat=cloth, major_segments=20, minor_segments=5)
        fold.rotation_mode = "QUATERNION"
        fold.rotation_quaternion = axis.to_track_quat("Z", "Y")
        fold.location = at
        fold.scale = (1.0, 0.86, 1.0)
        sleeve.append(fold)
    main += sleeve
    pieces = {}
    points = {}
    tips = []
    for finger, (x, lean, lengths, r) in FINGERS.items():
        knuckle = (x, -4.4, 0.0)
        parts, middle, tie = _finger(finger, knuckle, lean, lengths, r, skin, nail, string)
        pieces[finger] = parts
        points[finger] = knuckle
        points[finger + "Mid"] = tuple(middle)
        points[finger + "Tip"] = tuple(tie)
        tips.append(tie)
    # The thumb: from the heel of the palm on the thumb's side, forward, out and down.
    base, knuckle1, knuckle2, tip = (Vector((3.5, 1.0, -0.7)), Vector((5.0, -1.6, -2.0)), Vector((5.6, -4.0, -3.4)),
                                     Vector((5.75, -5.7, -5.0)))
    thumb = [_blob("MbThumb", [("ball", tuple(base), 1.35), ("capsule", tuple(base), tuple(knuckle1), 1.2),
                               ("capsule", tuple(knuckle1), tuple(knuckle2), 1.02),
                               ("capsule", tuple(knuckle2), tuple(tip), 0.86)], 0.2, 0.35, skin)]
    d = (tip - knuckle2).normalized()
    out = Vector((0.6, -0.2, 0.8))
    back = (out - d * out.dot(d)).normalized()
    more, tie = _nail_and_tie("Thumb", knuckle2, d, (tip - knuckle2).length, 0.86, back, nail, string)
    pieces["Thumb"] = thumb + more
    points["Thumb"] = tuple(base)
    points["ThumbMid"] = tuple(knuckle1)
    points["ThumbTip"] = tuple(tie)
    tips.append(tie)
    points["Anchor"] = tuple(sum(tips, Vector()) / len(tips))
    # Where the arm ends in the dark (the game's haze gathers there), and a spot over the back of the hand
    # (the game's light, from above).
    points["ArmEnd"] = tuple(arm_to)
    points["Above"] = (0.0, -1.0, 7.0)
    # Tilt it all forward and scale it up (meshes and points alike).
    turn = Matrix.Rotation(math.radians(HAND_TILT), 4, "X") @ Matrix.Diagonal((HAND_SCALE,) * 3 + (1.0,))
    for obj in main + [p for parts in pieces.values() for p in parts]:
        obj.matrix_basis = turn @ obj.matrix_basis
    points = {name: tuple(turn @ Vector(p)) for name, p in points.items()}
    # One texture: the palm and arm in the biggest square, the thumb and each finger in a small one.
    rects = [(0.006, 0.006, 0.66, 0.66), (0.67, 0.006, 0.994, 0.33), (0.67, 0.34, 0.994, 0.66),
             (0.006, 0.67, 0.33, 0.994), (0.34, 0.67, 0.66, 0.994), (0.67, 0.67, 0.994, 0.994)]
    more = {
        "into": rects[0],
        "pieces": {name: piece(parts, into=rects[k + 1]) for k, (name, parts) in enumerate(pieces.items())},
        "hinge": points,
    }
    return main, [], more


# Its dwellers' things -------------------------------------------------------------------------------------


# The throne (2026-10-16, after the Sedlec ossuary's order of bones and a stone bishop's chair): a cathedra of dark
# stone, heavy arms, a tall back between two pilasters of stacked long bones, a row of skulls along its top, a
# horned skull crowning it between crossed bones; nothing higher than THRONE_H. The game seats its stone
# champion on it: the seat's top is SEAT_TOP over the foot, the seat's middle SEAT_Y in front of the prop's
# middle (maps/venues/lobby/landmarks.throne reads both), the backrest's face BACK_Y behind it.
THRONE_H = 12.1
SEAT_TOP = 3.42
SEAT_Y = -0.3
BACK_Y = 1.45


@prop("BoneThrone", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Lobby")
def bone_throne():
    """The throne of whatever rules this place: a cathedra hewn from dark stone, its arms ending in skulls, its
    tall back framed by pilasters of stacked long bones and crowned with a row of skulls and a horned skull over
    crossed bones; crossed bones and a skull cut in the seat's front."""
    stone = dark_stone_mat("Thr")
    grey = stone_mat("Thr")
    bone = old_bone_mat("Thr")
    pale = bone_mat("Thr")
    horn = mk.noisy("Thr_Horn", srgb(34, 30, 30), srgb(70, 64, 58), scale=8, roughness=0.8)
    void = void_mat("Thr")
    depth = 6.8  # the plinth runs -3.4..3.4 (the prop's middle): nothing reaches past it, so it stays centred
    parts = [mk.box("Plinth", (7.8, depth, 0.6), (0, 0, 0.3), mat=grey, bevel=0.12),
             mk.box("Seat", (6.2, 3.6, 2.76), (0, SEAT_Y + 0.05, 0.6 + 1.38), mat=stone, bevel=0.14),
             mk.box("SeatSlab", (5.6, 3.4, 0.12), (0, SEAT_Y, SEAT_TOP - 0.06), mat=grey, bevel=0.04),
             mk.box("Back", (6.2, 1.0, 6.6), (0, BACK_Y + 0.5, SEAT_TOP + 3.3 - 0.06), mat=stone, bevel=0.14),
             mk.box("BackPanel", (4.2, 0.12, 4.6), (0, BACK_Y - 0.04, SEAT_TOP + 3.4), mat=grey, bevel=0.04),
             mk.box("BackInset", (3.6, 0.12, 4.0), (0, BACK_Y - 0.08, SEAT_TOP + 3.4), mat=stone, bevel=0.03)]
    # Carved in the inset, over where the champion's head comes: a skull, flattened into the stone.
    relief = skull("Relief", 0, BACK_Y - 0.05, SEAT_TOP + 4.85, 0.5, grey, void, jaw=True)
    for obj in relief:
        obj.scale = (obj.scale[0], obj.scale[1] * 0.4, obj.scale[2])
    parts += relief
    # Arms: solid blocks over the seat's sides, a skull on each front end.
    for sx in (-1, 1):
        parts.append(mk.box("Arm", (1.3, 3.5, 1.0), (sx * 2.45, SEAT_Y + 0.2, SEAT_TOP + 0.5), mat=stone, bevel=0.14))
        parts.append(mk.box("ArmFoot", (1.3, 0.9, 0.9), (sx * 2.45, SEAT_Y - 1.2, SEAT_TOP - 0.1), mat=stone, bevel=0.1))
        parts += skull(f"ArmSkull{sx}", sx * 2.45, SEAT_Y - 1.6, SEAT_TOP + 1.25, 0.42, pale, void)
    # The pilasters: three long bones stacked upright beside the back, a skull at the head of each.
    for sx in (-1, 1):
        for k, (dx, dy) in enumerate(((0.0, 0.0), (0.32, 0.12), (-0.3, 0.14))):
            x = sx * (3.42 + dx)
            parts += long_bone(f"Pilaster{sx}{k}", (x, BACK_Y + 0.5 + dy, 1.0), (x, BACK_Y + 0.5 + dy, SEAT_TOP + 6.3),
                               0.16, bone if k else pale)
        parts += skull(f"PilasterSkull{sx}", sx * 3.42, BACK_Y + 0.3, SEAT_TOP + 6.95, 0.48, pale, void)
    # A row of skulls along the back's top, as in the ossuary's garlands, long bones laid between them.
    for k in range(5):
        x = (k - 2) * 1.1
        parts += skull(f"Row{k}", x, BACK_Y + 0.25, SEAT_TOP + 6.95, 0.38, pale if k % 2 == 0 else bone, void, jaw=k == 2)
    for k in range(4):
        x = (k - 1.5) * 1.1
        parts += long_bone(f"RowBone{k}", (x - 0.35, BACK_Y + 0.55, SEAT_TOP + 6.62), (x + 0.35, BACK_Y + 0.55, SEAT_TOP + 6.62),
                           0.09, bone)
    # The crest: two long bones crossed behind a horned skull.
    crest_z = SEAT_TOP + 7.7
    for sx in (-1, 1):
        parts += long_bone(f"Cross{sx}", (sx * -1.5, BACK_Y + 0.75, crest_z - 1.0), (sx * 1.5, BACK_Y + 0.75, crest_z + 0.6),
                           0.17, bone)
    parts += beast_skull("Crown", 0, BACK_Y + 0.1, crest_z, 0.62, pale, void, horn, jaw=False)
    # The seat's front: two long bones crossed and a skull where they cross, cut in low relief.
    front = SEAT_Y - 1.75
    for sx in (-1, 1):
        parts += long_bone(f"FrontBone{sx}", (sx * -1.7, front - 0.05, 0.95), (sx * 1.7, front - 0.05, 2.75), 0.13, bone)
    parts += skull("FrontSkull", 0, front - 0.1, 1.85, 0.42, pale, void)
    return parts, []


# The chess game sunk in the ash (maps/venues/lobby/plan.py CHESS_GAME): Staunton silhouettes, so a piece reads at a
# glance, carved like the Lewis chessmen (heavy, worn, chipped). A square is 3.2 studs; the king stands 5.2.
CHESS_SQUARE = 3.2


def _piece_mats(colour):
    if colour == "w":
        return (mk.noisy("Chs_Bone", srgb(150, 144, 128), srgb(206, 199, 180), scale=14, roughness=0.8),
                mk.noisy("Chs_BoneDark", srgb(96, 90, 80), srgb(140, 132, 116), scale=14, roughness=0.85))
    return (mk.noisy("Chs_Ebony", srgb(22, 22, 25), srgb(48, 47, 52), scale=12, roughness=0.75),
            mk.noisy("Chs_EbonyDark", srgb(14, 14, 16), srgb(30, 30, 34), scale=12, roughness=0.8))


def _staunton(name, kind, colour, x, y, z=0.0, axis=None):
    """One piece, standing at (x, y) (or lying along `axis`, a unit (x, y) direction: its foot at (x, y)),
    as parts. Kinds: K Q R B N P."""
    body, dark = _piece_mats(colour)
    base = [(0.0, 0.0), (1.15, 0.0), (1.18, 0.16), (1.05, 0.32), (0.86, 0.42), (0.9, 0.56), (0.66, 0.7)]
    profiles = {
        "K": base + [(0.46, 2.55), (0.76, 2.7), (0.8, 2.86), (0.52, 2.98), (0.64, 3.66), (0.72, 3.9), (0.5, 4.02),
                     (0.0, 4.1)],
        "Q": base + [(0.44, 2.4), (0.74, 2.55), (0.78, 2.7), (0.5, 2.82), (0.66, 3.5), (0.78, 3.78), (0.6, 3.84),
                     (0.0, 3.9)],
        "B": [(0.0, 0.0), (1.0, 0.0), (1.03, 0.15), (0.9, 0.3), (0.74, 0.4), (0.78, 0.52), (0.56, 0.66), (0.38, 2.05),
              (0.66, 2.18), (0.68, 2.32), (0.4, 2.42), (0.0, 2.44)],
        "R": [(0.0, 0.0), (1.05, 0.0), (1.08, 0.16), (0.96, 0.3), (0.84, 0.42), (0.84, 2.4), (0.98, 2.6), (1.0, 3.0),
              (0.72, 3.0), (0.72, 2.84), (0.0, 2.84)],
        "N": [(0.0, 0.0), (1.05, 0.0), (1.08, 0.16), (0.96, 0.3), (0.82, 0.42), (0.86, 0.6), (0.7, 0.78), (0.0, 0.8)],
        "P": [(0.0, 0.0), (0.92, 0.0), (0.95, 0.14), (0.82, 0.28), (0.66, 0.36), (0.7, 0.48), (0.48, 0.6), (0.3, 1.5),
              (0.56, 1.6), (0.58, 1.7), (0.3, 1.78), (0.0, 1.8)],
    }
    parts = [mk.lathe(name + "Body", profiles[kind], mat=body, segments=16)]
    if kind == "K":
        parts += [mk.box(name + "CrossV", (0.32, 0.32, 1.0), (0, 0, 4.5), mat=body, bevel=0.06),
                  mk.box(name + "CrossH", (0.86, 0.32, 0.3), (0, 0, 4.66), mat=body, bevel=0.06)]
    elif kind == "Q":
        for k in range(8):
            a = math.tau * k / 8
            parts.append(mk.sphere(name + "Point", 0.15, (math.cos(a) * 0.66, math.sin(a) * 0.66, 3.92), mat=body,
                                   segments=8, rings=5))
        parts.append(mk.sphere(name + "Orb", 0.3, (0, 0, 4.15), mat=body, segments=10, rings=7))
    elif kind == "B":
        parts.append(mk.sphere(name + "Mitre", 0.62, (0, 0, 3.0), scale=(1.0, 1.0, 1.4), mat=body, segments=14, rings=10))
        parts.append(mk.box(name + "Slit", (0.12, 1.3, 0.5), (0.18, 0, 3.15), rot=(0, -38, 0), mat=dark))
        parts.append(mk.sphere(name + "Knob", 0.2, (0, 0, 3.92), mat=body, segments=8, rings=6))
    elif kind == "P":
        parts.append(mk.sphere(name + "Head", 0.5, (0, 0, 2.2), mat=body, segments=14, rings=10))
    elif kind == "R":
        for k in range(5):
            a = math.tau * (k + 0.5) / 5
            parts.append(mk.box(name + "Merlon", (0.5, 0.36, 0.42), (math.cos(a) * 0.82, math.sin(a) * 0.82, 3.2),
                                rot=(0, 0, math.degrees(a) + 90), mat=body, bevel=0.05))
    elif kind == "N":
        # The horse's head and neck, a side outline cut from a thick slab, the mane a ridge down its back.
        outline = [(-0.6, 0.0), (0.45, 0.0), (0.58, 0.62), (0.36, 1.2), (0.98, 1.55), (1.08, 1.86), (0.62, 2.36), (0.36, 2.76),
                   (0.2, 2.96), (0.04, 2.62), (-0.18, 2.54), (-0.52, 2.1), (-0.68, 1.2), (-0.64, 0.5)]
        head = mk.extrude_shape(name + "Head", outline, 0.92, (0, 0, 0.78), rot=(90, 0, 0), mat=body, bevel=0.1)
        head.rotation_euler = (math.radians(90), 0, math.radians(-90))  # facing -Y (forward), like the others
        parts.append(head)
        parts.append(mk.tube(name + "Mane", (0.0, 0.62, 3.0), (0.0, 0.66, 1.0), 0.14, 0.18, mat=dark, verts=6))
        for k in (-1, 1):
            parts.append(mk.sphere(name + "Eye", 0.09, (k * 0.47, -0.55, 2.95), mat=dark, segments=6, rings=4))
    for obj in parts:
        mk.displace_noise(obj, strength=0.035, scale=0.45, name=name + "Wear")
        if axis is None:
            obj.location = (obj.location[0] + x, obj.location[1] + y, obj.location[2] + z)
    if axis is not None:
        # Lying down: turned about the piece's foot so its length runs along `axis`, resting on its widest rings.
        ang = math.atan2(axis[1], axis[0])
        turn = Matrix.Translation(Vector((x, y, z + 1.12))) @ Matrix.Rotation(ang, 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "Y")
        for obj in parts:
            obj.matrix_basis = turn @ obj.matrix_basis
    return parts


@prop("ChessGame", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Lobby", anchor=(0, 0))
def chess_game():
    """The pieces of a game left on the sunk board, where the plan's position stands them (the toppled king is
    a prop of its own). Its origin is the board's middle; the board itself is the map's."""
    from maps.venues.lobby import plan as LP

    parts = []
    for square, (kind, colour) in sorted(LP.CHESS_GAME.items()):
        lx, lz = LP.chess_square(square)
        # (Roblox's local x is the builder's -x, its local z the builder's y.)
        parts += _staunton(square + kind + colour, kind, colour, -lx, lz)
    # The white king toppled on its square, lying along the first rank, its cross snapped off beside it.
    lx, lz = LP.chess_square(LP.CHESS_FALLEN)
    king = [obj for obj in _staunton("Fallen", "K", "w", -lx - 2.0, lz, axis=(1.0, 0.0)) if "Cross" not in obj.name]
    body, _ = _piece_mats("w")
    king.append(mk.box("FallenCross", (1.0, 0.32, 0.32), (-lx + 2.6, lz + 0.9, 0.16), rot=(0, 0, 24), mat=body, bevel=0.06))
    return parts + king, []


@prop("ChessKingFallen", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Lobby")
def chess_king_fallen():
    """A white king of the sunk board's set, toppled: lying on its side, its cross snapped off beside it."""
    body, dark = _piece_mats("w")
    parts = [obj for obj in _staunton("King", "K", "w", -2.3, 0.0, axis=(1.0, 0.0)) if "Cross" not in obj.name]
    d = (math.cos(math.radians(24)), math.sin(math.radians(24)))
    cx, cy = 3.5, 0.9
    parts += [mk.box("CrossV", (1.0, 0.32, 0.32), (cx, cy, 0.16), rot=(0, 0, 24), mat=body, bevel=0.06),
              mk.box("CrossH", (0.3, 0.86, 0.3), (cx + d[0] * 0.16, cy + d[1] * 0.16, 0.15), rot=(0, 0, 24), mat=body,
                     bevel=0.06),
              mk.box("Chip", (0.4, 0.3, 0.2), (2.6, -1.1, 0.1), rot=(10, 4, 50), mat=dark, bevel=0.05)]
    return parts, []


@prop("StoneNotebook", pivot="centre", material="Slate", collide=False, texture=256, set="Lobby")
def stone_notebook():
    """A black notebook turned to stone, stopped in its fall over the rift: tumbling, its covers spread a third
    open, the pages fanned between them, two leaves torn loose and stopped beside it. Lines run across the
    one page that shows, too worn to read."""
    cover = mk.noisy("Snb_Cover", srgb(16, 16, 18), srgb(38, 37, 40), scale=10, roughness=0.85)
    page = mk.noisy("Snb_Page", srgb(150, 146, 136), srgb(190, 186, 174), scale=16, roughness=0.9)
    ink = mk.flat("Snb_Ink", srgb(40, 38, 40), 0.9)
    w, h, t = 4.2, 6.0, 0.22  # a cover: across (from the spine), up, thick
    parts = []
    opening = 128.0  # degrees between the covers
    for k, ang in enumerate((-opening / 2, opening / 2)):
        board = mk.box(f"Cover{k}", (w, t, h), (w / 2, 0, 0), mat=cover, bevel=0.05)
        board.matrix_basis = Matrix.Rotation(math.radians(ang), 4, "Z") @ board.matrix_basis
        parts.append(board)
    for k in range(7):
        ang = -opening / 2 + 4.0 + k * (opening - 8.0) / 6
        leaf = mk.box(f"Leaf{k}", (w - 0.25, 0.05, h - 0.3), ((w - 0.25) / 2 + 0.08, 0, 0), mat=page)
        leaf.matrix_basis = Matrix.Rotation(math.radians(ang), 4, "Z") @ leaf.matrix_basis
        parts.append(leaf)
    # The lines on the last leaf before the open cover (the one that shows), worn and broken.
    rng = random.Random(41)
    last = -opening / 2 + 4.0 + 6 * (opening - 8.0) / 6
    for k in range(9):
        length = rng.uniform(1.4, 3.2)
        line = mk.box(f"Line{k}", (length, 0.02, 0.07), (0.4 + length / 2, -0.04, h / 2 - 0.9 - k * 0.5), mat=ink)
        line.matrix_basis = Matrix.Rotation(math.radians(last), 4, "Z") @ line.matrix_basis
        parts.append(line)
    parts.append(mk.cylinder("Spine", t * 1.2, h, (0, 0, 0), mat=cover, verts=10))
    # Two leaves torn loose, stopped where they flew.
    for k, (pos, rot) in enumerate((((5.4, 1.8, 3.4), (20, 35, 70)), ((-3.6, 2.4, -3.8), (-30, 15, 140)))):
        parts.append(mk.box(f"Loose{k}", (w * 0.8, 0.05, h * 0.8), pos, rot=rot, mat=page))
    # The whole book tumbling: tipped forward and over.
    tumble = Matrix.Rotation(math.radians(-28), 4, "X") @ Matrix.Rotation(math.radians(18), 4, "Y")
    for obj in parts:
        obj.matrix_basis = tumble @ obj.matrix_basis
    return parts, []
