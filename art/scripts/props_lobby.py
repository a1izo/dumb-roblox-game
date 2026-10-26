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
from mathutils import Euler, Matrix, Vector

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
    """A long bone from a to b, grown as one surface (a skin over its line, rounded): each end swelling into two
    rounded knobs side by side, the neck narrowing into a long thin shaft between them."""
    from props_world import skin_body

    ax, ay, az = a
    bx, by, bz = b
    length = math.dist(a, b)
    ux, uy, uz = (bx - ax) / length, (by - ay) / length, (bz - az) / length
    # A side step across the bone for the paired knobs.
    sx, sy = -uy, ux
    s = math.hypot(sx, sy) or 1.0
    sx, sy = sx / s, sy / s
    joints, bones = [], []

    def joint(p, radius):
        joints.append((p[0], p[1], p[2], radius, radius))
        return len(joints) - 1

    last = None
    for t, f in ((0.0, 1.25), (0.1, 1.05), (0.25, 0.82), (0.5, 0.74), (0.75, 0.82), (0.9, 1.05), (1.0, 1.25)):
        k = joint((ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t), r * f)
        if last is not None:
            bones.append((last, k))
        last = k
        if t in (0.0, 1.0):
            for side in (-1, 1):
                # (the knob a little past the end, to the side)
                out = -1 if t == 0.0 else 1
                knob = joint((ax + (bx - ax) * t + (sx * side * 0.7 + ux * out * 0.35) * r,
                              ay + (by - ay) * t + (sy * side * 0.7 + uy * out * 0.35) * r,
                              az + (bz - az) * t + uz * out * 0.35 * r), r * 1.15)
                bones.append((k, knob))
    grown = skin_body(name, mat, joints, bones, levels=1)
    # (thinned to about what the old tube and knobs cost: a throne carries fourteen of them)
    grown.modifiers.new("Decimate", "DECIMATE").ratio = 0.55
    return [grown]


def skull(prefix, x, y, z, r, mat, dark, yaw=0.0, jaw=True, far=False):
    """A human skull of cranium radius r, its face towards -Y turned by yaw degrees about Z: the carved skull
    (propkit.skull: one sculpted shell, the sockets and the nose cut deep into it, teeth along the mouth), lighter
    for a small one and lightest for one seen only from far below (`far`: no teeth, a coarser shell; a prop's mesh
    stays under Roblox's 20,000 triangles). (`jaw` is kept for the callers: the carved skull always has its jaw.)"""
    if far:
        return pk.skull(prefix, (x, y, z), r, mat, dark, yaw=yaw, segments=14, teeth=0)
    return pk.skull(prefix, (x, y, z), r, mat, dark, yaw=yaw, segments=20 if r < 0.45 else 24, teeth=5)


def beast_skull(prefix, x, y, z, s, mat, dark, horn):
    """A horned beast's skull, s times the size of a 1-stud model, facing -Y: a low, long head like a dragon's,
    grown as one surface (the braincase; one heavy shelf of brow over both sockets, no bumps for eyebrows; the long
    snout tapering to a tip hooked down, a ridge down its nose; the cheek arches running back), wide sockets slanting
    down toward the snout, black deep inside, slit nostrils; a row of fangs down each side of the upper jaw, each
    rooted in the snout's underside right over it, the canine long; the lower jaw hanging open from hinges inside
    the braincase, its own teeth standing up from it; and the two horns sweeping out, back and up, each one bar
    growing out of the braincase. (Asked 2026-10-25: "make them scarier".)"""
    def at(dx, dy, dz):
        return (x + dx * s, y + dy * s, z + dz * s)

    els = [("ellipsoid", at(0.0, 0.7, 0.45), 0.9 * s, (0.95, 1.0, 0.75)),  # the braincase
           ("ellipsoid", at(0.0, -0.12, 0.66), 0.56 * s, (1.5, 0.72, 0.4)),  # the brow, one shelf over both sockets
           ("capsule", at(0.0, 0.25, 0.28), at(0.0, -1.4, 0.15), 0.4 * s),  # the snout, broad behind
           ("capsule", at(0.0, -1.4, 0.15), at(0.0, -2.42, 0.05), 0.25 * s),  # tapering
           ("capsule", at(0.0, -2.42, 0.05), at(0.0, -2.7, -0.14), 0.16 * s),  # to a tip hooked down
           ("capsule", at(0.0, -0.45, 0.6), at(0.0, -2.3, 0.34), 0.1 * s)]  # the ridge down the nose
    for k in (-1, 1):
        els += [("capsule", at(k * 0.45, -0.7, 0.04), at(k * 0.85, 0.45, 0.14), 0.13 * s),  # the cheek arch
                ("hollow", at(k * 0.6, -0.32, 0.4), 0.3 * s, (1.15, 0.9, 0.68)),  # the socket, wide
                ("hollow", at(k * 0.11, -2.6, 0.16), 0.08 * s, (0.55, 1.4, 0.8))]  # a nostril, a slit
    head = _blob(prefix + "Head", els, 0.065 * s, 0.42, mat)  # (grown fine and thinned: smooth, but kept light)
    parts = [head]
    for k in (-1, 1):  # (black deep in the sockets, tilted down toward the snout, and in the nostrils)
        socket = mk.sphere(prefix + "Socket", 0.24 * s, at(k * 0.6, -0.2, 0.4), scale=(1.15, 0.9, 0.6), mat=dark,
                           segments=14, rings=8)
        socket.rotation_euler = (0, math.radians(k * 18), 0)
        parts.append(socket)
        parts.append(mk.sphere(prefix + "Nostril", 0.065 * s, at(k * 0.11, -2.55, 0.16), scale=(0.55, 1.4, 0.8),
                               mat=dark, segments=8, rings=6))
    # The lower jaw, dropped open: two rami from hinges inside the braincase, meeting at the chin.
    jaw_els = [("ellipsoid", at(0.0, -2.2, -0.86), 0.16 * s, (1.5, 1.1, 0.8))]  # the chin
    for k in (-1, 1):
        jaw_els += [("capsule", at(k * 0.55, 0.45, 0.0), at(k * 0.38, -0.9, -0.5), 0.15 * s),
                    ("capsule", at(k * 0.38, -0.9, -0.5), at(k * 0.12, -2.15, -0.84), 0.12 * s)]
    jaw = _blob(prefix + "Jaw", jaw_els, 0.065 * s, 0.42, mat)
    parts.append(jaw)
    # The fangs: each rooted a little up into the snout's underside right over it (they hung from one height before,
    # and toward the tip, where the snout rises, they floated; asked 2026-10-25), the lower ones down into the jaw.
    surfaces = []
    for blob in (head, jaw):
        holder = _applied(blob)
        surfaces.append(_surfaces(holder))
        mesh = holder.data
        bpy.data.objects.remove(holder)
        bpy.data.meshes.remove(mesh)
    under, lower = surfaces
    for k in (-1, 1):
        for t in range(6):
            ty = y - (0.35 + t * 0.4) * s
            tx = x + k * (0.36 - t * 0.04) * s
            hit = under.up(tx, ty, z - 2.0 * s)
            if hit is None:
                continue
            length = (0.62 if t == 4 else 0.34 - 0.02 * t) * s  # (the canine, long)
            parts.append(mk.cylinder(prefix + "Tooth", (0.09 if t == 4 else 0.07) * s, length,
                                     (tx, ty, hit + 0.05 * s - length / 2), rot=(180, 0, 0), mat=mat, verts=8,
                                     radius2=0.01 * s))
        for t in range(5):
            u = (t + 0.5) / 5
            ty = y + (-0.75 - 1.3 * u) * s
            tx = x + k * (0.36 - 0.22 * u) * s
            hit = lower.down(tx, ty, z + 2.0 * s)
            if hit is None:
                continue
            length = 0.26 * s
            parts.append(mk.cylinder(prefix + "JawTooth", 0.06 * s, length, (tx, ty, hit - 0.04 * s + length / 2),
                                     mat=mat, verts=8, radius2=0.01 * s))
    # The horns, each one bar sweeping out, back and up from inside the braincase.
    for k in (-1, 1):
        pts, radii = [], []
        for t in range(9):
            u = t / 8
            pts.append(at(k * (0.55 + 2.0 * u), 0.55 + 1.3 * u + 0.3 * u * u, 0.85 + 1.35 * u - 1.1 * u * u * u))
            radii.append(max(0.02 * s, 0.3 * s * (1 - u * 0.93)))
        parts.append(pk.sweep(prefix + "Horn", pts, radii, horn, sides=10))
    return parts


def _applied(obj):
    """obj with its modifiers applied (a copy's mesh), for rays to meet the surface as it will be."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    holder = bpy.data.objects.new(obj.name + "Applied", mesh)
    holder.matrix_world = obj.matrix_basis.copy()
    return holder


def dark_apart(objs, dark):
    """Takes the faces in `dark` (sockets, nostrils, a mouth's line) out of objs into objects of their own, removing
    from objs any object that is all dark, and returns them: given to the prop as a glow, they become flat black parts
    that need no texture, so the holes stay crisp however few pixels a prop's map gives a small skull (in a shared map
    the black smeared over the bone round them). Modifiers are applied first."""
    import bmesh

    depsgraph = bpy.context.evaluated_depsgraph_get()
    out = []
    for obj in list(objs):
        mats = list(obj.data.materials)
        if dark not in mats:
            continue
        idx = mats.index(dark)
        if obj.modifiers:
            mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
            obj.modifiers.clear()
            obj.data = mesh
        if all(poly.material_index == idx for poly in obj.data.polygons):
            objs.remove(obj)
            out.append(obj)
            continue
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        black = bm.copy()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index == idx], context="FACES")
        bmesh.ops.delete(black, geom=[f for f in black.faces if f.material_index != idx], context="FACES")
        for f in black.faces:
            f.material_index = 0
        bm.to_mesh(obj.data)
        bm.free()
        piece = mk._obj_from_bm(obj.name + "Dark", black, dark)
        piece.matrix_basis = obj.matrix_basis.copy()
        out.append(piece)
    return out


def rest_on(parts, z, sink=0.03):
    """Moves a group of parts straight up or down so that its lowest point sits `sink` into a surface at height z
    (a skull set on a ledge, not hovering over it)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    low = min((obj.evaluated_get(depsgraph).matrix_world @ v.co).z for obj in parts
              for v in obj.evaluated_get(depsgraph).to_mesh().vertices)
    for obj in parts:
        obj.evaluated_get(depsgraph).to_mesh_clear()
        obj.location.z += z - sink - low
    return parts


def top_of(parts):
    """The highest point of a group of parts."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    high = max((obj.evaluated_get(depsgraph).matrix_world @ v.co).z for obj in parts
               for v in obj.evaluated_get(depsgraph).to_mesh().vertices)
    for obj in parts:
        obj.evaluated_get(depsgraph).to_mesh_clear()
    return high


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


# An apple's shape (2026-10-25, the owner: "not just basic shapes (for example apples in the lobby)"): a lathed body,
# wider at the shoulders, a dimple at the top and a small one under it, a curled stem and a withered leaf.
APPLE_PROFILE = [(0.0, 0.05), (0.08, 0.0), (0.24, 0.03), (0.38, 0.13), (0.45, 0.3), (0.46, 0.46), (0.42, 0.6),
                 (0.32, 0.7), (0.18, 0.72), (0.08, 0.66), (0.0, 0.62)]


def apple_parts(prefix, at, size, skin, stem, leaf, tilt=0.0, leafy=True):
    """An apple standing at `at` (its foot), `size` times the made size, its stem tilted `tilt` degrees."""
    x, y, z = at
    body = mk.lathe(prefix + "Body", [(r * size, h * size) for r, h in APPLE_PROFILE], mat=skin, segments=18)
    body.location = (x, y, z)
    lean = math.radians(tilt)
    base = (x, y, z + 0.62 * size)
    tip = (x + math.sin(lean) * 0.28 * size, y, z + (0.62 + math.cos(lean) * 0.28) * size)
    parts = [body, mk.tube(prefix + "Stem", base, tip, 0.03 * size, 0.02 * size, mat=stem, verts=6)]
    if leafy:
        blade = mk.sphere(prefix + "Leaf", 0.16 * size, (tip[0] + 0.12 * size, y + 0.02 * size, tip[2] - 0.02 * size),
                          scale=(1.0, 0.42, 0.07), mat=leaf, segments=10, rings=4)
        blade.rotation_euler = (math.radians(55), math.radians(-30), math.radians(10))  # (curling off the stem)
        parts.append(blade)
    return parts


@prop("GreyApple", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Lobby")
def grey_apple():
    """One of the seven grey apples hidden round the realm (the lobby's apple hunt): the realm's own fruit, ash-grey
    with a faint silver sheen and darker streaks, a black stem, a withered grey leaf."""
    skin = mk.noisy("Ga_Skin", srgb(92, 92, 98), srgb(156, 156, 164), scale=9, roughness=0.3, stretch=(1, 1, 4))
    stem = mk.flat("Ga_Stem", srgb(24, 22, 22), 0.8)
    leaf = mk.noisy("Ga_Leaf", srgb(70, 72, 70), srgb(112, 112, 106), scale=14, roughness=0.7)
    return apple_parts("Ga", (0, 0, 0), 1.0, skin, stem, leaf, tilt=14), []


@prop("WitheredAppleTree", pivot="bottom", material="Wood", collide=False, texture=1024, set="Lobby", anchor=(0, 0))
def withered_apple_tree():
    """The one fruit tree in the realm: grey and twisted like the rest, yet hung with a few dull,
    grey-brown apples, and two more fallen in the ash at its foot (one bitten)."""
    parts, tips = dead_tree(37, "Apl", 13.0, (0.6, 0.9), 5, 0.6, 0.05, 0.4)
    rng = random.Random(8)
    red = mk.noisy("Apl_Apple", srgb(58, 52, 48), srgb(104, 96, 88), scale=6, roughness=0.55)
    stem = mk.flat("Apl_Stem", srgb(40, 30, 22), 0.8)
    flesh = mk.flat("Apl_Flesh", srgb(176, 172, 164), 0.7)
    leaf = mk.noisy("Apl_Leaf", srgb(60, 62, 58), srgb(98, 98, 92), scale=14, roughness=0.7)
    for k, ((tx, ty, tz), _) in enumerate(tips[::2][:9]):
        hang = rng.uniform(0.3, 0.7)
        # (hung by its stalk off the twig, the apple's stem meeting the stalk's end: an apple upside-down on it)
        parts.append(mk.tube("Stalk", (tx, ty, tz), (tx, ty, tz - hang), 0.03, mat=stem, verts=4))
        body = mk.lathe("Apple", [(r * 0.95, h * 0.95) for r, h in APPLE_PROFILE], mat=red, segments=18)
        body.location = (tx, ty, tz - hang - 0.6 * 0.95)  # (hanging upright: its top's dimple on the stalk's end)
        parts.append(body)
    for k, (x, y) in enumerate(((2.2, -1.4), (-1.8, 1.9))):
        fallen = apple_parts("Fallen", (x, y, -0.02), 0.95, red, stem, leaf, tilt=40, leafy=False)
        parts += fallen
        if k == 0:
            parts.append(mk.sphere("Bite", 0.24, (x - 0.3, y - 0.2, 0.36), scale=(0.5, 1, 1), mat=flesh, segments=8, rings=6))
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
    # (a lumpy heap of ash, not a smooth dome)
    mound = mk.sphere("Mound", 1.7, (0, 0, 0.1), scale=(1.1, 0.9, 0.42), mat=ash, segments=28, rings=14)
    mk.displace_noise(mound, strength=0.22, scale=0.55, name="SkpMound")
    parts = [mound]
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
            mid = skull.up(0.0, y, 1.0)
            for step in range(9):  # (a little nearer the middle where the muzzle is too narrow there)
                x = sx * max(0.0, 1.7 - k * 0.05 - step * 0.2)
                under = skull.up(x, y, 1.0)
                # (only where the underside is still nearly level with its middle: rooted further out, on the muzzle's
                # curved side, a fang hung down the outside of it, a lone tooth sticking out; asked 2026-10-25)
                if under is not None and mid is not None and under <= mid + 0.35:
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
    """A cairn of flat field stones, each a rough slab (lumpy edges, a tilt of its own) lying on the one under it,
    smaller as they rise, a few fallen stones at its foot and a long bone laid across its top: a waymark at the
    realm's edge."""
    rng = random.Random(3)
    stone = stone_mat("Crn")
    dark = dark_stone_mat("Crn")
    bone = bone_mat("Crn")
    parts = []
    z, r = 0.0, 1.32
    for k in range(7):
        h = r * rng.uniform(0.34, 0.44)
        x, y = rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08)
        slab = mk.sphere(f"Stone{k}", 1.0, (x, y, z + h * 0.42), scale=(r * rng.uniform(0.98, 1.1),
                         r * rng.uniform(0.82, 0.96), h / 2), mat=stone if k % 2 else dark, segments=16, rings=10)
        slab.rotation_euler = (math.radians(rng.uniform(-4, 4)), math.radians(rng.uniform(-4, 4)),
                               math.radians(rng.uniform(0, 180)))
        mk.displace_noise(slab, strength=0.34, scale=0.55, name="CairnStone")
        parts.append(slab)
        z += h * 0.8  # (each lies a little into the one below: no gap under it)
        r *= 0.8
    for k in range(4):
        a = k * 1.7 + 0.4
        sr = rng.uniform(0.22, 0.32)
        pebble = mk.sphere(f"Fallen{k}", 1.0, (math.cos(a) * 1.3, math.sin(a) * 1.15, sr * 0.38),
                           scale=(sr * 1.3, sr, sr * 0.55), mat=dark if k % 2 else stone, segments=10, rings=7)
        mk.displace_noise(pebble, strength=0.3, scale=0.5, name="CairnPebble")
        parts.append(pebble)
    parts += long_bone("TopBone", (-0.85, 0.1, z + 0.08), (0.85, -0.12, z + 0.1), 0.1, bone)
    return parts, []


# Fire and light -----------------------------------------------------------------------------------------


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
    # the bed of embers glows; the fire over it is the game's (a living fire, Presentation/Vfx Recipes.flame)
    glows = [mk.cylinder("Embers", 1.0, 0.2, (0, 0, 4.5), mat=pk.glow("Brz_Ember", (120, 150, 210), 3), verts=14)]
    return parts, glows, {"flames": [(0, 0, 4.55, 2.6, 1)]}


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
    # a stub of candle in the cage; its flame is the game's
    wax = candle_wax("Lnp")
    wick = mk.flat("Lnp_Wick", srgb(16, 14, 13), 0.9)
    body, tip = candle("LnpCandle", cx, cy, cz - 0.58, 0.16, 0.42, wax, wick, random.Random(5), drips=3)
    parts += body
    return parts, [], {"flames": [(tip[0], tip[1], tip[2], 0.6)]}


def candle_wax(key):
    """The realm's candle wax: bone white, a little grey, never warm."""
    return mk.noisy(f"{key}_Wax", srgb(176, 170, 158), srgb(214, 208, 194), scale=14, roughness=0.55)


def candle(name, x, y, z0, r, h, wax, wick, rng, drips=5):
    """One candle standing at (x, y, z0), `r` across its middle and `h` tall: a turned pillar with a soft foot, its top
    melted down into a crater inside a rounded lip that leans a little lower on one side, wax run down its sides in
    drips that end in round beads, and a bent black wick in the crater. Returns (parts, the wick's tip), the tip where
    the game's flame stands (Presentation/Vfx Recipes.flame; nothing on the candle glows itself)."""
    profile = [(r * 1.06, 0.0), (r * 1.03, 0.03), (r * 1.0, 0.08), (r * 0.995, h * 0.5), (r * 1.0, h - 0.07),
               (r * 0.985, h - 0.025), (r * 0.93, h), (r * 0.82, h - 0.012), (r * 0.62, h - 0.05),
               (r * 0.3, h - 0.068), (0.001, h - 0.072)]
    parts = [mk.lathe(f"{name}Body", profile, loc=(x, y, z0), mat=wax, segments=28)]
    # the lip leans down toward one side, where the drips spill over
    low = rng.uniform(0, 2 * math.pi)
    parts.append(mk.torus(f"{name}Lip", r * 0.9, r * 0.09, loc=(x, y, z0 + h - 0.012), mat=wax, major_segments=18,
                          minor_segments=6))
    for k in range(drips):
        # spread round, most on the low side of the lip
        a = low + (k - (drips - 1) / 2) * rng.uniform(0.45, 0.75) if k < drips - 1 else low + math.pi * rng.uniform(0.6, 1.4)
        length = rng.uniform(0.18, 0.58) * h
        rd = rng.uniform(0.022, 0.032) * (r / 0.22) ** 0.5
        ox, oy = math.cos(a), math.sin(a)
        # a ridge hugging the side (its middle sunk 0.45 of its width into the wax), swelling to a teardrop bead
        sink = r + rd * 0.55
        top = (x + ox * sink, y + oy * sink, z0 + h - 0.015)
        bottom = (x + ox * sink, y + oy * sink, z0 + h - length)
        ridge = mk.tube(f"{name}Drip{k}", top, bottom, rd * 0.85, rd * 1.05, mat=wax, verts=8)
        ridge.scale = (1, 1, 1)
        parts.append(ridge)
        bead = mk.sphere(f"{name}Bead{k}", rd * 1.35, (x + ox * (r + rd * 0.5), y + oy * (r + rd * 0.5),
                                                       z0 + h - length - rd * 0.6), scale=(1, 1, 1.6), mat=wax,
                         segments=10, rings=7)
        # (flattened against the side: thin along the side's normal)
        bead.rotation_euler = (0, 0, a)
        bead.scale = (0.62, 1.0, 1.6)
        parts.append(bead)
        # where it spilled over the lip: a soft lump, half in the lip
        spill = mk.sphere(f"{name}Spill{k}", rd * 1.4, (x + ox * r * 0.97, y + oy * r * 0.97, z0 + h - 0.006),
                          mat=wax, segments=10, rings=6)
        spill.rotation_euler = (0, 0, a)
        spill.scale = (0.9, 1.25, 0.55)
        parts.append(spill)
    # the wick: up out of the crater, then bent over a little, its tip charred
    lean = rng.uniform(0, 2 * math.pi)
    base = (x, y, z0 + h - 0.07)
    mid = (x + math.cos(lean) * 0.01, y + math.sin(lean) * 0.01, z0 + h + 0.05)
    tip = (x + math.cos(lean) * 0.035, y + math.sin(lean) * 0.035, z0 + h + 0.1)
    parts.append(mk.tube(f"{name}Wick", base, mid, 0.014, 0.013, mat=wick, verts=5))
    parts.append(mk.tube(f"{name}WickTip", mid, tip, 0.013, 0.009, mat=wick, verts=5))
    return parts, tip


def wax_pool(name, x, y, z0, radius, wax, rng):
    """A pool of old wax round a candle's foot, its edge lumpy where it ran and set."""
    parts = [mk.cylinder(f"{name}Pool", radius, 0.03, (x, y, z0 + 0.015), mat=wax, verts=28, radius2=radius * 0.92)]
    for k in range(4):
        a = rng.uniform(0, 2 * math.pi)
        rr = radius * rng.uniform(0.8, 1.0)
        parts.append(mk.sphere(f"{name}Puddle{k}", radius * rng.uniform(0.2, 0.3),
                               (x + math.cos(a) * rr, y + math.sin(a) * rr, z0 + 0.008), scale=(1, 1, 0.1), mat=wax,
                               segments=20, rings=6))
    return parts


@prop("ReadyCandle", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Lobby")
def ready_candle():
    """A candle for the ready circle at the plaza's middle (one burns for each player who is ready, lit by the
    game): a pillar of bone-white wax a stud tall in a pool of its own, drips run down its leaning side."""
    rng = random.Random(41)
    wax = candle_wax("Rdc")
    wick = mk.flat("Rdc_Wick", srgb(16, 14, 13), 0.9)
    parts = wax_pool("Rdc", 0, 0, 0, 0.42, wax, rng)
    body, tip = candle("Rdc", 0, 0, 0.03, 0.22, 1.0, wax, wick, rng, drips=5)
    parts += body
    return parts, [], {"flames": [(tip[0], tip[1], tip[2], 0.55)]}


@prop("CandleCluster", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Lobby",
      lights=[dict(at=(0, 0, 1.6), kind="point", color=CANDLE, range=10, brightness=0.55)])
def candle_cluster():
    """Stub candles of every height melted together on a pool of old wax, all but one still burning (the game's
    flames stand on their wicks)."""
    rng = random.Random(21)
    wax = candle_wax("Cnd")
    wick = mk.flat("Cnd_Wick", srgb(16, 14, 13), 0.9)
    parts = wax_pool("Cnd", 0, 0, 0, 0.95, wax, rng)
    flames = []
    for k in range(7):
        a = k * 2.4
        rr = 0.15 + 0.5 * (k / 6)
        x, y = math.cos(a) * rr, math.sin(a) * rr
        h = rng.uniform(0.4, 1.5)
        r = rng.uniform(0.1, 0.16)
        body, tip = candle(f"Candle{k}", x, y, 0.03, r, h, wax, wick, rng, drips=3 + k % 3)
        parts += body
        if k != 3:
            flames.append((tip[0], tip[1], tip[2], 0.38 + r * 1.2))
    return parts, [], {"flames": flames}


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
    wax = candle_wax("Alt")
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
    wick = mk.flat("Alt_Wick", srgb(16, 14, 13), 0.9)
    rng = random.Random(17)
    flames = []
    for sx in (-1, 1):
        for k, (dx, h) in enumerate(((0.0, 0.9), (0.28, 0.55), (-0.25, 0.4))):
            x = sx * 2.05 + dx
            body, tip = candle(f"Candle{sx}{k}", x, 0.85, 3.01, 0.12, h, wax, wick, rng, drips=3)
            parts += body
            flames.append((tip[0], tip[1], tip[2], 0.45))
    return parts, [], {"flames": flames}


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
                                 pk.rounded("Foot", (0.32, 0.8, 0.24), (s * 0.32, -0.16, 0.13), wood, r=0.1),
                                 # (the ankle's peg, down from the ball into the foot)
                                 mk.tube("AnklePeg", an, (an[0], an[1], 0.2), 0.07, 0.07, mat=wood, verts=8)]
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


def _fine(profile, step=0.12):
    """A turned shape's profile [(radius, z)] with points added between its own, every `step` studs at most, so
    folds cut into it bend smoothly up its height instead of only at the profile's few rings."""
    out = [profile[0]]
    for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
        n = max(1, int(math.hypot(r1 - r0, z1 - z0) / step))
        out += [(r0 + (r1 - r0) * k / n, z0 + (z1 - z0) * k / n) for k in range(1, n + 1)]
    return out


def _hem(obj, z_below, wave, count, phase=0.0):
    """Lets a turned shape's lowest edge fall in waves (a hem hanging in folds): every vertex below z_below drops
    or rises by up to `wave`, in `count` waves round it."""
    for v in obj.data.vertices:
        if v.co.z < z_below:
            a = math.atan2(v.co.y, v.co.x)
            v.co.z += wave * math.sin(count * a + phase) * min(1.0, (z_below - v.co.z) / 0.3)


def _stone_hand(name, at, mat, side):
    """A stone hand hanging relaxed out of a sleeve: the palm, four fingers curled a little in, the thumb along
    them (one smooth surface)."""
    x, y, z = at
    elements = [("ellipsoid", (x, y, z), 0.13, (0.75, 1.0, 1.25))]
    for k in range(4):
        fy = y - 0.1 + k * 0.065
        top = (x + side * 0.015, fy, z - 0.12)
        mid = (x + side * 0.02, fy - 0.02, z - 0.27)
        tip = (x - side * 0.02, fy - 0.07, z - 0.37 + 0.02 * abs(k - 1.5))
        elements += [("capsule", top, mid, 0.034), ("capsule", mid, tip, 0.029)]
    elements.append(("capsule", (x - side * 0.05, y - 0.12, z - 0.02), (x - side * 0.04, y - 0.2, z - 0.2), 0.035))
    return _blob(name, elements, 0.022, 0.6, mat)


@prop("RobedStatue", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby")
def robed_statue():
    """A tableau's statue: a hooded, faceless figure in a long robe, cut in pale stone, in six pieces the game
    moves as it moves a body (the torso is the prop itself). The stone falls in drapery: deep uneven folds down the
    robe crossed by the fold of its wrap from shoulder to hip, a mantle hanging over the shoulders in scallops, a
    knotted cord at the waist with its two ends hanging, a deep hood drawn forward over a face that is only
    shadow, its rim rolled; bell sleeves flaring at the cuffs over sculpted hands; the skirt falling in folds to a
    hem that waves over the feet."""
    stone = mk.noisy("Rst_Stone", srgb(118, 116, 112), srgb(166, 163, 156), scale=12, roughness=0.9, kind="stone")
    worn = mk.noisy("Rst_Worn", srgb(92, 90, 88), srgb(128, 125, 120), scale=14, roughness=0.92, kind="stone")
    void = void_mat("Rst")
    # The torso: the robe over the chest and shoulders, a cowl round the neck, a cord at the waist.
    body = mk.lathe("Robe", _fine([(0.0, 1.92), (0.98, 1.92), (1.0, 2.3), (1.02, 2.9), (1.04, 3.4), (1.0, 3.8),
                                   (0.9, 3.98), (0.62, 4.08), (0.0, 4.1)]), mat=stone, segments=48)
    _folds(body, 6, 0.13, 1.92, 4.0)
    _folds(body, 13, 0.045, 1.92, 4.0, phase=1.3)
    # A short mantle over the shoulders, the sleeves' tops under it, its edge hanging in scallops.
    # (Every profile here runs from the bottom up: run downwards, a turned shape's faces look inwards.)
    mantle = mk.lathe("Mantle", _fine([(0.0, 3.6), (1.36, 3.34), (1.56, 3.38), (1.46, 3.58), (1.02, 3.92),
                                       (0.66, 4.12), (0.0, 4.14)], 0.08), mat=stone, segments=48)
    _folds(mantle, 9, 0.06, 3.34, 4.12)
    _hem(mantle, 3.45, 0.07, 9, phase=0.5)
    torso = [squashed(body, sx=0.98, sy=0.6), squashed(mantle, sy=0.66),
             squashed(mk.torus("Cowl", 0.6, 0.2, (0, 0, 4.02), mat=stone, major_segments=28, minor_segments=10), sy=0.72),
             squashed(mk.torus("Cord", 1.03, 0.06, (0, 0, 2.28), mat=worn, major_segments=32, minor_segments=8), sy=0.6)]
    # The fold of the wrap, from the left shoulder down across the chest to the right hip, standing on the robe.
    wrap = [(0.62 - 0.9 * t, -0.68 - 0.04 * math.sin(math.pi * t), 3.95 - 1.55 * t) for t in (k / 8 for k in range(9))]
    fold = pk.sweep("Wrap", wrap, [0.09, 0.1, 0.1, 0.1, 0.095, 0.09, 0.085, 0.08, 0.07], stone, sides=8)
    fold.scale = (1.0, 0.55, 1.0)
    torso.append(fold)
    # The cord's knot at the left of the waist and its two ends hanging, each finished in a tassel.
    torso.append(mk.sphere("Knot", 0.11, (0.42, -0.62, 2.27), scale=(1.2, 0.8, 1.0), mat=worn, segments=12, rings=8))
    for k, dx in enumerate((-0.04, 0.07)):
        end = [(0.42 + dx, -0.66, 2.2), (0.44 + dx * 1.5, -0.68, 1.85), (0.45 + dx * 2, -0.67, 1.5)]
        torso.append(pk.sweep("CordEnd", end, 0.04, worn, sides=6))
        torso.append(mk.cylinder("Tassel", 0.06, 0.24, (0.45 + dx * 2, -0.67, 1.38), mat=worn, verts=10, radius2=0.09))
    # The head: the hood drawn forward over a face that is only shadow, its rim rolled round the opening.
    hood = mk.lathe("Hood", _fine([(0.6, 4.02), (0.78, 4.3), (0.84, 4.72), (0.8, 5.12), (0.62, 5.42), (0.32, 5.58),
                                   (0.0, 5.62)], 0.08), mat=stone, segments=40)
    _folds(hood, 7, 0.035, 4.02, 5.6, fade_top=False)
    rim = [(0.46 * math.cos(a), -0.78 + 0.05 * math.sin(a) ** 2, 4.72 + 0.6 * math.sin(a))
           for a in (math.tau * k / 24 for k in range(25))]
    # (a sheet of shadow just inside the rim, so nothing of the hood's inside shows in the opening: a flat disc, as
    # a sphere squashed flat its pole's slivers took the stone's colour, a light speck at the top of the opening)
    shade = mk.cylinder("Shade", 1.0, 0.06, (0, -0.74, 4.72), rot=(90, 0, 0), mat=void, verts=24)
    shade.scale = (0.45, 0.59, 1.0)
    head = [squashed(hood, sy=0.92),
            mk.sphere("Face", 0.5, (0, -0.52, 4.72), scale=(0.98, 0.62, 1.24), mat=void, segments=18, rings=12),
            pk.sweep("HoodRim", rim, 0.06, stone, sides=8, caps=False), shade]
    pieces = {"Head": head}
    hinge = {"Head": (0.0, 0.0, 4.0)}
    for name, x in (("RightArm", -1.5), ("LeftArm", 1.5)):
        # bell sleeves, flaring at the cuff, folded
        sleeve = mk.lathe("Sleeve", _fine([(0.0, 2.0), (0.6, 1.98), (0.64, 2.08), (0.55, 2.4), (0.49, 2.9),
                                           (0.47, 3.5), (0.44, 3.8), (0.3, 3.93), (0.0, 3.97)], 0.1),
                          loc=(x, 0, 0), mat=stone, segments=32)
        _folds(sleeve, 6, 0.05, 1.98, 4.1)
        _folds(sleeve, 11, 0.018, 1.98, 4.1, phase=0.8)
        _hem(sleeve, 2.1, 0.05, 5, phase=1.0 if x > 0 else 0.0)
        hand = _stone_hand("Hand", (x, -0.04, 1.86), worn, 1 if x > 0 else -1)
        pieces[name] = [squashed(sleeve, sy=0.86, about=(x, 0, 0)), hand]  # (just clear of the robe's side)
        hinge[name] = (x * 2 / 3, 0.0, 3.5)
    for name, x in (("RightLeg", -0.5), ("LeftLeg", 0.5)):
        skirt = mk.lathe("Skirt", _fine([(0.0, 0.02), (0.9, 0.02), (0.93, 0.12), (0.78, 0.72), (0.7, 1.4), (0.66, 2.02),
                                         (0.0, 2.06)]), loc=(x, 0, 0), mat=stone, segments=36)
        _folds(skirt, 6, 0.12, 0.0, 2.05, phase=0.6 if x > 0 else 0.0)
        _folds(skirt, 13, 0.04, 0.0, 2.05, phase=1.9 if x > 0 else 0.4)
        _hem(skirt, 0.2, 0.06, 7, phase=0.3 if x > 0 else 2.0)
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
    """The throne of whatever rules this place: a cathedra hewn from dark stone on a stepped plinth. Its seat is a
    block girdled with mouldings and framed panels, a worn cushion of black velvet buttoned into it; its arms are
    carved rests that roll over at their ends, a skull on each; its tall back rises to a cornice, a pointed arch
    sunk in it with a ribcage carved under a flattened skull. Framing it, pilasters of stacked long bones (a skull at
    the head of each), a row of skulls along the top, a horned skull crowning it over crossed bones: that bone work
    is a piece of its own ("Ossuary", sharing the texture), so the carving and the bones each keep under Roblox's
    20,000 triangles. Crossed bones and a skull cut in the seat's front."""
    stone = dark_stone_mat("Thr")
    grey = stone_mat("Thr")
    bone = old_bone_mat("Thr")
    pale = bone_mat("Thr")
    horn = mk.noisy("Thr_Horn", srgb(34, 30, 30), srgb(70, 64, 58), scale=8, roughness=0.8)
    velvet = mk.noisy("Thr_Velvet", srgb(20, 16, 22), srgb(44, 36, 46), scale=30, roughness=0.95)
    void = void_mat("Thr")
    depth = 6.8  # the plinth runs -3.4..3.4 (the prop's middle): nothing reaches past it, so it stays centred
    seat_bottom = 0.6
    parts = [mk.box("Plinth", (7.8, depth, 0.36), (0, 0, 0.18), mat=grey, bevel=0.1),
             mk.box("PlinthStep", (7.2, depth - 0.6, 0.26), (0, 0, 0.47), mat=grey, bevel=0.06),
             # the seat: its block, a base moulding and a lipped top round it, framed panels on its faces
             mk.box("Seat", (6.2, 3.6, 2.76), (0, SEAT_Y + 0.05, seat_bottom + 1.38), mat=stone, bevel=0.1),
             mk.box("SeatBase", (6.44, 3.84, 0.24), (0, SEAT_Y + 0.05, seat_bottom + 0.12), mat=stone, bevel=0.06),
             mk.box("SeatLip", (6.4, 3.8, 0.18), (0, SEAT_Y + 0.05, SEAT_TOP - 0.15), mat=stone, bevel=0.06),
             mk.box("SeatSlab", (5.6, 3.4, 0.12), (0, SEAT_Y, SEAT_TOP - 0.06), mat=grey, bevel=0.04)]
    front = SEAT_Y - 1.75
    parts += pk.frame("FrontPanel", 5.5, 2.2, 0.14, 0.08, (0, front - 0.03, 1.86), grey)
    for sx in (-1, 1):
        for obj in pk.frame(f"SidePanel{sx}", 2.9, 2.0, 0.12, 0.08, (0, 0, 0), grey):
            obj.data.transform(obj.matrix_basis)
            obj.matrix_basis = Matrix.Translation((sx * 3.13, SEAT_Y + 0.05, 1.9)) @ Matrix.Rotation(math.radians(90), 4, "Z")
            parts.append(obj)
    # The cushion: black velvet, worn soft, buttoned in a grid of deep tufts.
    cushion = pk.rounded("Cushion", (5.3, 3.1, 0.32), (0, SEAT_Y - 0.05, SEAT_TOP + 0.12), velvet, r=0.14)
    mk.displace_noise(cushion, strength=0.03, scale=0.4, name="ThrCushion")
    parts.append(cushion)
    for gx in range(4):
        for gy in range(3):
            parts.append(mk.sphere("Tuft", 0.06, (-1.8 + gx * 1.2, SEAT_Y - 1.0 + gy * 0.95, SEAT_TOP + 0.27),
                                   scale=(1, 1, 0.5), mat=velvet, segments=8, rings=5))
    # The back: a slab rising to a stepped cornice; a pointed arch sunk in its face, its rim moulded; under the
    # flattened skull at the arch's head, a ribcage carved in low relief.
    back_mid = SEAT_TOP + 3.3 - 0.06
    parts += [mk.box("Back", (6.2, 1.0, 6.6), (0, BACK_Y + 0.5, back_mid), mat=stone, bevel=0.1),
              mk.box("Cornice", (6.5, 1.2, 0.22), (0, BACK_Y + 0.5, back_mid + 3.2), mat=stone, bevel=0.06),
              mk.box("CorniceLip", (6.3, 1.1, 0.14), (0, BACK_Y + 0.5, back_mid + 3.02), mat=grey, bevel=0.04)]
    arch_base, arch_spring, arch_top, half = SEAT_TOP + 0.9, SEAT_TOP + 4.3, SEAT_TOP + 5.9, 1.8

    def arch(h_w, inset=0.0):
        """The arch's outline in (x, z), anticlockwise from its foot on the left: its sides up from the base to the
        springing, then two arcs (each centred on the other side's springing, an equilateral arch drawn up to the
        point's height) meeting at the point."""
        w = h_w - inset
        base, top = arch_base + inset, arch_top - inset
        rise = (top - arch_spring) / (2 * w * math.sin(math.radians(60)))
        right = [(-w + 2 * w * math.cos(math.radians(a)), arch_spring + 2 * w * math.sin(math.radians(a)) * rise)
                 for a in range(0, 61, 6)]
        left = [(-x, z) for x, z in reversed(right[:-1])]
        return [(-w, base), (w, base)] + right + left

    outline = arch(half)
    panel = mk.extrude_shape("ArchPanel", outline, 0.12, rot=(90, 0, 0), mat=grey)
    panel.location = (0, BACK_Y - 0.02, 0)
    recess = mk.extrude_shape("ArchRecess", arch(half, 0.2), 0.12, rot=(90, 0, 0), mat=stone)
    recess.location = (0, BACK_Y - 0.05, 0)
    parts += [panel, recess, pk.sweep("ArchRim", [(x, BACK_Y - 0.09, z) for x, z in outline] + [(outline[0][0], BACK_Y - 0.09,
                                                                                                    outline[0][1])],
                                      0.07, grey, sides=10, caps=False)]
    relief = skull("Relief", 0, BACK_Y - 0.05, SEAT_TOP + 4.85, 0.5, grey, void, jaw=True, far=True)
    for obj in relief:
        obj.scale = (obj.scale[0], obj.scale[1] * 0.4, obj.scale[2])
    parts += relief
    spine_top, spine_bottom = SEAT_TOP + 4.25, SEAT_TOP + 1.25
    parts.append(pk.sweep("Spine", [(0, BACK_Y - 0.14, spine_top), (0, BACK_Y - 0.16, spine_bottom)], 0.08, bone, sides=12))
    for k in range(5):
        z = spine_top - 0.25 - k * 0.52
        span = 1.25 - k * 0.12
        for sx in (-1, 1):
            rib = [(sx * (0.08 + span * u), BACK_Y - 0.13 - 0.06 * math.sin(math.pi * u), z - 0.55 * u * u - 0.1 * u)
                   for u in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0)]
            parts.append(pk.sweep("Rib", rib, [0.06, 0.06, 0.055, 0.05, 0.045, 0.035], pale if k % 2 else bone, sides=10))
    # Arms: carved rests rolling over at their front ends (their tops level, where the champion's arm lies), a skull
    # on each front end.
    roll = [(1.65, SEAT_TOP), (1.65, SEAT_TOP + 1.0), (-1.45, SEAT_TOP + 1.0), (-1.68, SEAT_TOP + 0.96),
            (-1.86, SEAT_TOP + 0.8), (-1.86, SEAT_TOP + 0.56), (-1.72, SEAT_TOP + 0.42), (-1.55, SEAT_TOP + 0.4),
            (-1.5, SEAT_TOP + 0.2), (-1.42, SEAT_TOP)]
    for sx in (-1, 1):
        arm = mk.extrude_shape(f"Arm{sx}", roll, 1.3, rot=(90, 0, 90), mat=stone, bevel=0.06)
        arm.location = (sx * 2.45, 0, 0)
        parts.append(arm)
        # the roll's spiral cut in each side of its end
        for side in (-1, 1):
            parts.append(mk.torus(f"Volute{sx}{side}", 0.2, 0.035, (sx * 2.45 + side * 0.66, -1.62, SEAT_TOP + 0.66),
                                  rot=(0, 90, 0), mat=grey, major_segments=14, minor_segments=5))
        parts += rest_on(skull(f"ArmSkull{sx}", sx * 2.45, SEAT_Y - 1.35, SEAT_TOP + 1.25, 0.42, pale, void), SEAT_TOP + 0.98)
    # The seat's front: two long bones crossed and a skull where they cross, cut in low relief.
    for sx in (-1, 1):
        parts += long_bone(f"FrontBone{sx}", (sx * -1.7, front - 0.05, 0.95), (sx * 1.7, front - 0.05, 2.75), 0.13, bone)
    parts += skull("FrontSkull", 0, front - 0.1, 1.85, 0.42, pale, void)

    # The ossuary round it (a piece of its own). Every skull sits on what is under it, the stack of bones or the
    # cornice (asked 2026-10-25: "the skulls dont connect ... make sure nothing floats").
    cornice_top = back_mid + 3.31
    bones = []
    for sx in (-1, 1):
        stack = []
        for k, (dx, dy) in enumerate(((0.0, 0.0), (0.32, 0.12), (-0.3, 0.14))):
            x = sx * (3.42 + dx)
            stack += long_bone(f"Pilaster{sx}{k}", (x, BACK_Y + 0.5 + dy, 1.0), (x, BACK_Y + 0.5 + dy, SEAT_TOP + 6.3),
                               0.16, bone if k else pale)
        bones += stack
        bones += rest_on(skull(f"PilasterSkull{sx}", sx * 3.42, BACK_Y + 0.4, SEAT_TOP + 6.95, 0.48, pale, void, far=True),
                         top_of(stack), sink=0.06)
    # A row of skulls along the back's top, as in the ossuary's garlands, long bones laid between them.
    for k in range(5):
        x = (k - 2) * 1.1
        bones += rest_on(skull(f"Row{k}", x, BACK_Y + 0.25, SEAT_TOP + 6.95, 0.38, pale if k % 2 == 0 else bone, void,
                               jaw=k == 2, far=True), cornice_top)
    for k in range(4):
        x = (k - 1.5) * 1.1
        bones += long_bone(f"RowBone{k}", (x - 0.35, BACK_Y + 0.55, SEAT_TOP + 6.62), (x + 0.35, BACK_Y + 0.55, SEAT_TOP + 6.62),
                           0.09, bone)
    # The crest: two long bones crossed behind a horned skull.
    crest_z = SEAT_TOP + 7.7
    for sx in (-1, 1):
        # (each rising from the cornice, its foot set into it)
        bones += long_bone(f"Cross{sx}", (sx * -1.5, BACK_Y + 0.75, cornice_top + 0.08),
                           (sx * 1.5, BACK_Y + 0.75, crest_z + 0.6), 0.17, bone)
    bones += beast_skull("Crown", 0, BACK_Y + 0.1, crest_z, 0.62, pale, void, horn)
    # (the skulls' sockets, noses and mouths flat black parts of their own: dark_apart)
    glows = dark_apart(parts, void) + dark_apart(bones, void)
    rects = grid_rects(2, 2)
    return parts, glows, {"into": rects[0], "pieces": {"Ossuary": piece(bones, into=rects[1])}, "finish": fill_gaps}


def fill_gaps(colour, normal, rough):
    """(a bake's finish: every map's islands grown over the black between them until none is left, so a thin
    part's sliver of an island, a rib or a spine, does not take the black round it, nor a sliver too small for the
    bake to reach any texel of, of which a skull grown smooth has many, stay black: black specks on the bone)"""
    for pixels in (colour, normal, rough):
        mk.bleed(pixels, passes=1024)


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
              mk.box("Chip", (0.4, 0.3, 0.2), (2.6, -1.1, 0.07), rot=(10, 4, 50), mat=dark, bevel=0.05)]
    return parts, []


def _stone_leaf(name, w, h, bow, mat, rng, torn=False, curl=0.0):
    """A page of the stone notebook: a thin sheet `w` out from the spine and `h` tall, bowed `bow` studs at its middle
    (no page lies flat), its outer corner curling by `curl`; torn: its spine edge ripped ragged."""
    import bmesh

    bm = bmesh.new()
    nu, nv = 10, 6
    grid = []
    for i in range(nu + 1):
        u = i / nu
        row = []
        for j in range(nv + 1):
            v = j / nv
            x = u * w
            if torn and i == 0:
                x += rng.uniform(0.0, 0.3)
            y = bow * math.sin(math.pi * u) + curl * (u ** 3) * (v ** 2)
            row.append(bm.verts.new((x, y, (v - 0.5) * h)))
        grid.append(row)
    for i in range(nu):
        for j in range(nv):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
    leaf = mk._obj_from_bm(name, bm, mat)
    thick = leaf.modifiers.new("Sheet", "SOLIDIFY")
    thick.thickness = 0.05
    thick.offset = 0
    mk.smooth(leaf)
    return leaf


@prop("StoneNotebook", pivot="centre", material="Slate", collide=False, texture=256, set="Lobby")
def stone_notebook():
    """A black notebook turned to stone, stopped in its fall over the rift: tumbling, its covers spread a third
    open (rounded boards, a sunken panel on each), the pages fanned between them, each bowed as a page bows, two
    leaves torn loose (ragged at the spine, curling) and stopped beside it. Lines run across the one page that
    shows, too worn to read."""
    cover = mk.noisy("Snb_Cover", srgb(16, 16, 18), srgb(38, 37, 40), scale=10, roughness=0.85)
    panel = mk.noisy("Snb_Panel", srgb(10, 10, 12), srgb(26, 25, 28), scale=14, roughness=0.9)
    page = mk.noisy("Snb_Page", srgb(150, 146, 136), srgb(190, 186, 174), scale=16, roughness=0.9)
    ink = mk.flat("Snb_Ink", srgb(40, 38, 40), 0.9)
    w, h, t = 4.2, 6.0, 0.22  # a cover: across (from the spine), up, thick
    parts = []
    rng = random.Random(41)
    opening = 128.0  # degrees between the covers
    for k, ang in enumerate((-opening / 2, opening / 2)):
        side = -1 if k == 0 else 1
        for obj in (pk.rounded(f"Cover{k}", (w, t, h), (w / 2, 0, 0), cover, r=0.09),
                    mk.box(f"Panel{k}", (w - 0.9, 0.04, h - 1.2), (w / 2 + 0.1, side * (t / 2 + 0.005), 0), mat=panel)):
            obj.matrix_basis = Matrix.Rotation(math.radians(ang), 4, "Z") @ obj.matrix_basis
            parts.append(obj)
    for k in range(7):
        ang = -opening / 2 + 4.0 + k * (opening - 8.0) / 6
        leaf = _stone_leaf(f"Leaf{k}", w - 0.25, h - 0.3, rng.uniform(0.12, 0.3) * (1 if k % 2 else -1), page, rng,
                           curl=rng.uniform(-0.25, 0.25))
        leaf.matrix_basis = Matrix.Rotation(math.radians(ang), 4, "Z") @ Matrix.Translation((0.08, 0, 0))
        parts.append(leaf)
    # The lines on the last leaf before the open cover (the one that shows), worn and broken.
    last = -opening / 2 + 4.0 + 6 * (opening - 8.0) / 6
    for k in range(9):
        length = rng.uniform(1.4, 3.2)
        line = mk.box(f"Line{k}", (length, 0.02, 0.07), (0.4 + length / 2, -0.04, h / 2 - 0.9 - k * 0.5), mat=ink)
        line.matrix_basis = Matrix.Rotation(math.radians(last), 4, "Z") @ line.matrix_basis
        parts.append(line)
    parts.append(mk.cylinder("Spine", t * 1.2, h, (0, 0, 0), mat=cover, verts=14))
    # Two leaves torn loose, stopped where they flew.
    for k, (pos, rot) in enumerate((((5.4, 1.8, 3.4), (20, 35, 70)), ((-3.6, 2.4, -3.8), (-30, 15, 140)))):
        loose = _stone_leaf(f"Loose{k}", w * 0.8, h * 0.8, 0.35, page, rng, torn=True, curl=0.6)
        loose.matrix_basis = (Matrix.Translation(pos) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
                              @ Matrix.Translation((-w * 0.4, 0, 0)))
        parts.append(loose)
    # The whole book tumbling: tipped forward and over.
    tumble = Matrix.Rotation(math.radians(-28), 4, "X") @ Matrix.Rotation(math.radians(18), 4, "Y")
    for obj in parts:
        obj.matrix_basis = tumble @ obj.matrix_basis
    return parts, []
