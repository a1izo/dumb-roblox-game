"""The lobby's props (set "Lobby", exported to InkboundModels_Lobby.fbx): the Grey Realm, the ashen
wasteland beyond the world where the Grimoire comes from.

- What the game dresses: the Academy's practice altar (round the game's invisible drill desk) and
  the effigy the drills point at (round the practice dummy).
- The wasteland: two kinds of dead tree, a withered apple tree still hung with a few red apples,
  skull piles and scattered bones, a colossal horned skull, stone cairns.
- Fire and light: bone braziers burning pale, a crooked lantern post, candle clusters.
- Its dwellers' things: the bone throne, a dice game left on a rock, vertebra stools.

Built to the semi-real standard (propkit): real sizes at about 3.5 studs to the metre, bevelled
edges, baked colour and ambient occlusion. Props face -Y and stand on z = 0. Every glow material
has a name of its own per colour (modelkit reuses a material by name within a build)."""

import math
import random

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop

PALE_FIRE = (196, 222, 255)  # the realm's fire: cold, blue-white
CANDLE = (255, 196, 128)


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
    """The one fruit tree in the realm: grey and twisted like the rest, yet hung with a few glossy
    red apples, and two more fallen in the ash at its foot (one bitten)."""
    parts, tips = dead_tree(37, "Apl", 13.0, (0.6, 0.9), 5, 0.6, 0.05, 0.4)
    rng = random.Random(8)
    red = mk.noisy("Apl_Apple", srgb(120, 14, 20), srgb(186, 34, 34), scale=6, roughness=0.25)
    stem = mk.flat("Apl_Stem", srgb(40, 30, 22), 0.8)
    flesh = mk.flat("Apl_Flesh", srgb(220, 206, 170), 0.7)
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


@prop("Effigy", pivot="bottom", material="Fabric", collide=False, texture=1024, set="Lobby")
def effigy():
    """The practice effigy the Academy's drills point at: a stuffed sackcloth figure the size of a
    person, bound to a stake by its arms like a scarecrow, a tattered dark cloak hanging from its
    shoulders, a sack for a head tied off at the neck and the crown with a stitched face, and a
    blank paper tag pinned to its chest for a name. It stands on a heap of stones."""
    rng = random.Random(17)
    sack = mk.noisy("Eff_Sack", srgb(104, 98, 86), srgb(146, 138, 122), scale=34, roughness=0.95)
    cloak = mk.noisy("Eff_Cloak", srgb(26, 26, 28), srgb(50, 48, 50), scale=20, roughness=0.9)
    straw = mk.noisy("Eff_Straw", srgb(120, 108, 76), srgb(160, 146, 104), scale=40, roughness=0.9)
    wood = bark_mat("Eff")
    rope = mk.noisy("Eff_Rope", srgb(72, 66, 54), srgb(110, 100, 80), scale=30, roughness=0.95)
    thread = mk.flat("Eff_Thread", srgb(20, 18, 18), 0.8)
    paper = mk.noisy("Eff_Paper", srgb(200, 190, 164), srgb(226, 218, 196), scale=30, roughness=0.8)
    stone = stone_mat("Eff")
    parts = [mk.tube("Stake", (0, 0.4, 0.0), (0, 0.4, 5.2), 0.16, 0.13, mat=wood, verts=7),
             mk.tube("Bar", (-2.0, 0.4, 4.55), (2.0, 0.4, 4.55), 0.11, mat=wood, verts=6)]
    for k, (x, y, r) in enumerate(((-0.5, 0.1, 0.55), (0.45, -0.1, 0.5), (0.0, 0.6, 0.5), (0.1, 0.0, 0.35))):
        parts.append(mk.sphere(f"Stone{k}", r, (x, y, r * 0.55), scale=(1.2, 1, 0.7), mat=stone, segments=8, rings=6))
    # The body: legs, the stuffed torso, the arms bound along the bar, straw spilling from the cuffs.
    for sx in (-1, 1):
        parts.append(mk.tube("Leg", (sx * 0.4, 0.1, 0.55), (sx * 0.4, 0.1, 2.7), 0.3, 0.36, mat=sack, verts=8))
        parts.append(mk.tube("Arm", (sx * 0.9, 0.2, 4.5), (sx * 1.75, 0.3, 4.55), 0.28, 0.24, mat=sack, verts=8))
        parts.append(mk.torus("Tie", 0.26, 0.05, (sx * 1.45, 0.3, 4.55), rot=(0, 90, 0), mat=rope, major_segments=10,
                              minor_segments=4))
        parts.append(mk.torus("TieLeg", 0.34, 0.05, (sx * 0.4, 0.1, 1.5), mat=rope, major_segments=10, minor_segments=4))
        for k in range(4):
            a = rng.uniform(-0.5, 0.5)
            parts.append(mk.tube("Straw", (sx * 1.8, 0.3, 4.55), (sx * 2.25, 0.3 + math.sin(a) * 0.3, 4.4 + math.cos(a) * 0.3),
                                 0.04, 0.01, mat=straw, verts=3))
            parts.append(mk.tube("Straw", (sx * 0.4, 0.1, 0.6), (sx * (0.4 + rng.uniform(-0.3, 0.3)), rng.uniform(-0.4, 0.4), 0.05),
                                 0.04, 0.01, mat=straw, verts=3))
    parts += [pk.rounded("Torso", (1.7, 0.95, 2.1), (0, 0.15, 3.7), sack, r=0.32),
              mk.torus("Waist", 0.85, 0.07, (0, 0.15, 2.75), mat=rope, major_segments=16, minor_segments=4),
              mk.sphere("Head", 0.6, (0, 0.1, 5.45), scale=(1, 0.95, 1.1), mat=sack, segments=12, rings=8),
              mk.cylinder("Neck", 0.28, 0.35, (0, 0.15, 4.85), mat=sack, verts=10),
              mk.torus("NeckTie", 0.28, 0.06, (0, 0.15, 4.88), mat=rope, major_segments=12, minor_segments=4),
              mk.cylinder("Gather", 0.26, 0.45, (0, 0.1, 6.2), mat=sack, verts=10, radius2=0.06),
              mk.torus("CrownTie", 0.16, 0.05, (0, 0.1, 6.12), mat=rope, major_segments=10, minor_segments=4)]
    for k in range(5):
        a = k * 1.3
        parts.append(mk.tube("Tuft", (0, 0.1, 6.4), (math.cos(a) * 0.35, 0.1 + math.sin(a) * 0.3, 6.75), 0.04, 0.01, mat=straw,
                             verts=3))
    # The cloak: tattered strips hung from the shoulders round the back and sides.
    for k in range(9):
        a = math.radians(160 + k * 27.5)
        c, s = math.cos(a), math.sin(a)
        drop = rng.uniform(1.9, 2.7)
        top = (c * 0.95, 0.15 - s * 0.55, 4.75)
        bottom = (c * 1.25, 0.15 - s * 0.8, 4.75 - drop)
        mid = ((top[0] + bottom[0]) / 2, (top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2)
        length = math.dist(top, bottom)
        strip = mk.box("Cloak", (0.62, 0.06, length), mid, rot=(0, 0, 90 - math.degrees(a)), mat=cloak)
        parts.append(strip)
    parts.append(pk.rounded("Mantle", (2.1, 1.25, 0.35), (0, 0.2, 4.8), cloak, r=0.15))
    # The stitched face and the name tag.
    for k in (-1, 1):
        parts.append(mk.box("StitchA", (0.28, 0.03, 0.05), (k * 0.22, -0.46, 5.6), rot=(0, 45, 0), mat=thread))
        parts.append(mk.box("StitchB", (0.28, 0.03, 0.05), (k * 0.22, -0.46, 5.6), rot=(0, -45, 0), mat=thread))
    for k in range(5):
        parts.append(mk.box("Mouth", (0.05, 0.03, 0.14), (-0.2 + k * 0.1, -0.5, 5.2), mat=thread))
    parts.append(mk.box("MouthLine", (0.5, 0.03, 0.03), (0, -0.5, 5.2), mat=thread))
    parts += [mk.box("Tag", (0.8, 0.03, 0.5), (0.3, -0.35, 4.0), rot=(0, 6, 0), mat=paper),
              mk.cylinder("Pin", 0.04, 0.12, (0.3, -0.38, 4.22), rot=(90, 0, 0), mat=thread, verts=6)]
    return parts, []


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
