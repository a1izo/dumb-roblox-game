"""The lobby's props (set "Lobby", exported to DeathsGambitModels_Lobby.fbx): the Grey Realm, the ashen
wasteland beyond the world where the Grimoire comes from.

- What the game dresses: the Academy's practice altar (round the game's invisible drill desk), the
  three puppets the drills point at (round the practice dummies) and the hand above that holds their
  strings.
- The wasteland: two kinds of dead tree, a withered apple tree still hung with a few dull grey-brown apples,
  skull piles and scattered bones, a colossal horned skull, stone cairns.
- Fire and light: bone braziers burning pale, a crooked lantern post, candle clusters.
- Its dwellers' things: the bone throne, a dice game left on a rock, vertebra stools.

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


@prop("DeadTree", pivot="bottom", material="Wood", collide=False, texture=1024, set="Lobby", anchor=(0, 0))
def dead_tree_tall():
    """A tall dead tree of the wasteland: a leaning trunk split into bare, twisting limbs that
    reach up and out, roots clawing over the ash."""
    parts, _ = dead_tree(11, "Dtr", 17.0, (1.2, 0.6), 5, 0.55, 0.15, 0.35)
    return parts, []


@prop("DeadTreeGnarled", pivot="bottom", material="Wood", collide=False, texture=1024, set="Lobby", anchor=(0, 0))
def dead_tree_gnarled():
    """A low, gnarled dead tree: a squat bent trunk, its crooked limbs spreading wide and flat, the
    kind the realm's dwellers hang their lanterns in."""
    parts, _ = dead_tree(23, "Dtg", 11.0, (2.2, -0.8), 4, 0.8, -0.1, 0.6)
    return parts, []


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


@prop("GiantSkull", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Lobby")
def giant_skull():
    """The skull of something colossal that died here long ago: a horned, long-snouted head the
    size of a house, its dark sockets and the stumps of its teeth, sinking into the ash."""
    bone = old_bone_mat("Gsk")
    horn = mk.noisy("Gsk_Horn", srgb(38, 34, 32), srgb(80, 72, 64), scale=8, roughness=0.8, stretch=(1, 1, 0.4))
    dark = void_mat("Gsk")
    parts = beast_skull("B", 0, 0, 5.0, 6.0, bone, dark, horn)
    return parts, []


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
ARM_FADE = 12  # steps in which the arm darkens into the haze


def _blob(name, elements, resolution, keep, mat):
    """A smooth surface from metaball elements, as a mesh: ("ball", centre, radius), ("ellipsoid", centre,
    radius, (sx, sy, sz)) or ("capsule", a, b, radius), radii being the surface's own. keep: the share of
    its triangles kept (decimated)."""
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
        elif element[0] == "ellipsoid":
            _, centre, r, (sx, sy, sz) = element
            el = meta.elements.new(type="ELLIPSOID")
            el.co = centre
            el.size_x, el.size_y, el.size_z = sx, sy, sz
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
    chose for you): one huge, pale, smooth human hand, palm down, its fingers hanging in front with a
    string tied round the tip of each, the wrist rising behind into the dark, where the arm fades out.
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
             ("ball", (0.0, 3.6, 0.0), 2.2)]
    # The wrist and the arm, rising behind: a run of balls growing a little wider.
    arm_from, arm_to = Vector((0.0, 3.6, 0.0)), Vector((0.0, 21.0, 1.9))
    for k in range(9):
        t = k / 8
        palm.append(("ball", tuple(arm_from.lerp(arm_to, t)), 2.35 + 0.75 * t))
    main = [_blob("MbPalm", palm, 0.42, 0.3, skin)]
    # The arm darkens step by step into the haze (the lobby's atmosphere colour), from the wrist back.
    steps = [skin]
    for k in range(1, ARM_FADE + 1):
        f = 1.0 - 0.9 * (k / ARM_FADE) ** 0.8
        steps.append(mk.noisy(f"Hand_Skin{k}", srgb(*(int(34 + (c - 34) * f) for c in (168, 160, 152))),
                              srgb(*(int(36 + (c - 36) * f) for c in (214, 207, 199))), roughness=0.6))
    blob = main[0]
    for mat in steps[1:]:
        blob.data.materials.append(mat)
    axis = (arm_to - arm_from).normalized()
    start, span = 6.0, (arm_to - arm_from).length - 6.0
    for poly in blob.data.polygons:
        t = (Vector(poly.center) - arm_from).dot(axis)
        poly.material_index = 0 if t <= start else min(ARM_FADE, 1 + int((t - start) / span * ARM_FADE))
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


@prop("BoneThrone", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Lobby")
def bone_throne():
    """The throne of whatever rules this place: a seat hewn from dark stone on a stepped dais, its
    tall back a fan of great ribs, a horned skull crowning it and skulls on the ends of its arms."""
    stone = dark_stone_mat("Thr")
    grey = stone_mat("Thr")
    bone = old_bone_mat("Thr")
    horn = mk.noisy("Thr_Horn", srgb(34, 30, 30), srgb(70, 64, 58), scale=8, roughness=0.8)
    void = void_mat("Thr")
    parts = [mk.box("Dais1", (12.0, 9.0, 0.8), (0, 0.6, 0.4), mat=grey, bevel=0.1),
             mk.box("Dais2", (10.0, 7.2, 0.8), (0, 0.9, 1.2), mat=stone, bevel=0.1),
             mk.box("Seat", (6.4, 4.4, 2.6), (0, 1.2, 2.9), mat=stone, bevel=0.2),
             mk.box("Cushion", (5.6, 3.6, 0.3), (0, 1.0, 4.3), mat=grey, bevel=0.1),
             mk.box("Back", (6.0, 1.4, 8.0), (0, 3.2, 6.2), mat=stone, bevel=0.2),
             mk.box("BackPanel", (4.4, 0.1, 5.6), (0, 2.46, 6.6), mat=grey, bevel=0.05),
             mk.box("BackInset", (3.8, 0.1, 5.0), (0, 2.42, 6.6), mat=stone, bevel=0.05)]
    for sx in (-1, 1):
        parts += [mk.box("Arm", (1.1, 4.4, 1.8), (sx * 3.6, 1.0, 4.9), mat=stone, bevel=0.15)]
        parts += skull(f"ArmSkull{sx}", sx * 3.6, -1.4, 6.1, 0.55, bone, void)
    # The fan of great ribs rising behind the back, each curving out and up to a point.
    for k in range(9):
        t = (k - 4) / 4
        pts = []
        for j in range(5):
            u = j / 4
            spread = t * (2.4 + 3.8 * math.sin(u * math.pi / 2))
            pts.append((spread, 3.7 + 0.9 * u * u, 4.6 + (11.0 - abs(t) * 4.2) * u - 0.8 * abs(t) * u * u))
        r = 0.36 - abs(t) * 0.1
        for j in range(4):
            parts.append(mk.tube("Rib", pts[j], pts[j + 1], r * (1 - j * 0.2), max(0.04, r * (1 - (j + 1) * 0.22)), mat=bone,
                                 verts=7))
    parts += beast_skull("Crown", 0, 3.0, 11.6, 1.5, bone, void, horn, jaw=False)
    for k in (-1, 1):
        parts.append(mk.sphere("Orb", 0.4, (k * 2.4, 1.0, 1.9), mat=grey, segments=10, rings=8))
    return parts, []


@prop("DiceGame", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Lobby")
def dice_game():
    """A dice game abandoned mid-throw: bone dice, a cup carved from a skull, tally sticks and a
    little heap of bone tokens, laid out on a scrap of dark cloth."""
    bone = bone_mat("Dcg")
    old = old_bone_mat("Dcg")
    void = void_mat("Dcg")
    cloth = mk.noisy("Dcg_Cloth", srgb(40, 34, 36), srgb(64, 54, 56), scale=24, roughness=0.95)
    parts = [mk.box("Cloth", (3.2, 2.2, 0.04), (0, 0, 0.02), rot=(0, 0, 8), mat=cloth)]
    for k, (x, y, yaw) in enumerate(((-0.6, -0.3, 15), (0.1, -0.5, -30), (0.5, 0.1, 50))):
        parts.append(mk.box(f"Die{k}", (0.4, 0.4, 0.4), (x, y, 0.24), rot=(0, 0, yaw), mat=bone, bevel=0.06))
        a = math.radians(yaw)
        for dx, dy in ((-0.1, -0.1), (0.1, 0.1), (0.0, 0.0))[:k + 1]:
            parts.append(mk.cylinder("Pip", 0.04, 0.02, (x + dx * math.cos(a) - dy * math.sin(a),
                                                        y + dx * math.sin(a) + dy * math.cos(a), 0.445), mat=void, verts=6))
    parts += skull("Cup", 1.1, 0.5, 0.42, 0.4, old, void, yaw=160, jaw=False)
    for k in range(5):
        parts.append(mk.box("Tally", (0.05, 0.9, 0.05), (-1.2 + k * 0.12, 0.6, 0.07), rot=(0, 0, 4 * k), mat=old))
    for k in range(6):
        a = k * 1.9
        parts.append(mk.cylinder("Token", 0.13, 0.05, (-0.6 + math.cos(a) * 0.2, 0.5 + math.sin(a) * 0.2, 0.07 + (k % 3) * 0.05),
                                 mat=bone, verts=10))
    return parts, []


@prop("BoneStool", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Lobby")
def bone_stool():
    """A stool made from one great vertebra: the round body to sit on, its spines and wings worn
    smooth."""
    bone = old_bone_mat("Bst")
    void = void_mat("Bst")
    parts = [mk.lathe("Body", [(0.0, 0.0), (0.95, 0.0), (1.05, 0.2), (0.85, 0.9), (1.0, 1.6), (0.9, 1.75), (0.0, 1.75)],
                      (0, 0, 0), mat=bone, segments=16),
             mk.cylinder("Canal", 0.3, 0.1, (0, 0.2, 1.75), mat=void, verts=10)]
    for sx in (-1, 1):
        parts.append(mk.tube("Wing", (sx * 0.8, 0.2, 1.3), (sx * 1.6, 0.5, 1.5), 0.25, 0.1, mat=bone, verts=7))
    parts.append(mk.tube("Spine", (0, 0.7, 1.2), (0, 1.5, 1.0), 0.22, 0.08, mat=bone, verts=7))
    return parts, []
