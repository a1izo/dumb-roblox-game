"""The Specter and the map kit: furniture, street props and set pieces (see props.py)."""

import math
import random

import bmesh
import bpy
from mathutils import Vector

import modelkit as mk
from common import srgb
from props import (
    BONE_A,
    BONE_B,
    BRASS_A,
    BRASS_B,
    DEEP_RED,
    INK,
    IRON_A,
    IRON_B,
    PAPER_A,
    PAPER_B,
    RED,
    STEEL_A,
    STEEL_B,
    WOOD_DARK,
    WOOD_LIGHT,
    prop,
)

LAMP = srgb(255, 214, 160)
LEATHER_RED = (srgb(70, 16, 20), srgb(104, 30, 32))
FOLIAGE = (srgb(34, 62, 40), srgb(70, 104, 66))


def cast_iron(name="Iron"):
    return mk.noisy(name, IRON_A, IRON_B, scale=22, detail=10, roughness=0.55, metallic=0.7)


def dark_wood(name="DarkWood"):
    return mk.wood(name, WOOD_LIGHT, WOOD_DARK, scale=4, rings=14)


# The Specter ----------------------------------------------------------------------------------------------


def robe_mesh(name, mat, rings, segments=40, seed=4):
    """A cloak spun from rings [(radius, z, depth scale)]; the lowest ring is torn into a
    ragged hem."""
    rng = random.Random(seed)
    bm = bmesh.new()
    verts_by_ring = []
    for k, (r, z, depth) in enumerate(rings):
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            zz = z
            rr = r * (1 + 0.04 * math.sin(a * 7 + k))
            if k == 0:
                zz = z + (rng.random() * 0.9 if i % 2 else rng.random() * 0.2)
                rr *= 1.0 + rng.random() * 0.08
            ring.append(bm.verts.new((math.cos(a) * rr, math.sin(a) * rr * depth, zz)))
        verts_by_ring.append(ring)
    for k in range(len(verts_by_ring) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((verts_by_ring[k][i], verts_by_ring[k][j], verts_by_ring[k + 1][j], verts_by_ring[k + 1][i]))
    bm.faces.new(verts_by_ring[-1])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(mat)
    mk._link(obj)
    mk.smooth(obj)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.08
    return obj


def wing(name, mat, side):
    """A ragged, bat-like wing: fingers of bone with torn membrane between them."""
    pts = [(0, 0), (1.2, 1.6), (2.6, 3.4), (3.3, 2.6), (2.9, 2.2), (3.6, 1.2), (2.9, 1.0), (3.1, 0.0),
           (2.4, 0.3), (2.2, -0.9), (1.6, -0.2), (0.8, -0.6)]
    pts = [(x * side, y) for x, y in pts]
    if side < 0:
        pts = list(reversed(pts))
    obj = mk.extrude_shape(name, pts, 0.06, mat=mat)
    return obj


# The Deathsinger (2026-10-25: the owner's reference, a lanky death god of the old manga kind: "he looks extremely
# chopped and ugly ... do his model based on the 7th image and please make it high quality"). One connected body grown
# from a skeleton (a skin of the joints, smoothed), gaunt and long-limbed, hunched, its hands hanging past its hips and
# its feet pointed as it floats; a white face with a wide grin of sharp teeth and burning red eyes, dark blue hair in
# spikes, a great collar of black feathers fanning out round a white fur ruff, a studded belt with a skull buckle and
# hanging chains, a short ragged skirt, a skull at one wrist, rings on its fingers, the Manual at its hip. It faces -Y.


def skin_body(name, mat, joints, bones, levels=2):
    """A smooth body grown from a skeleton: `joints` [(x, y, z, rx, ry)] and `bones` [(i, j)], the Skin modifier
    giving each joint its radii and the Subdivision modifier (`levels`) rounding it all into one surface."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, z)) for (x, y, z, _, _) in joints]
    for i, j in bones:
        bm.edges.new((verts[i], verts[j]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(mat)
    mk._link(obj)
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    layer = mesh.skin_vertices[0].data
    for k, (_, _, _, rx, ry) in enumerate(joints):
        layer[k].radius = (rx, ry)
    layer[0].use_root = True
    sub = obj.modifiers.new("Subdivision", "SUBSURF")
    sub.levels = levels
    sub.render_levels = levels
    return obj


def feather_blade(name, root, tip, width, mat):
    """One long black feather: a blade swept from the root to the tip, widest a third of the way, flat-ish."""
    axis = (tip - root)
    length = axis.length
    # (its flat face toward the front, so a collar fanned out sideways shows its feathers, not their edges)
    side = axis.cross(Vector((0, 1, 0)))
    if side.length < 0.25 * length:
        side = Vector((1, 0, 0))
    side.normalize()
    normal = side.cross(axis).normalized()
    bm = bmesh.new()
    rows = []
    for k in range(7):
        t = k / 6
        half = width * (math.sin(math.pi * min(1.0, 0.18 + t * 0.95)) ** 0.6) * (1 - 0.6 * t)
        centre = root + axis * t + normal * (0.06 * math.sin(math.pi * t) * length)
        rows.append((bm.verts.new(centre - side * half), bm.verts.new(centre + normal * 0.012),
                     bm.verts.new(centre + side * half)))
    for k in range(6):
        a, b = rows[k], rows[k + 1]
        bm.faces.new((a[0], b[0], b[1], a[1]))
        bm.faces.new((a[1], b[1], b[2], a[2]))
    obj = mk._obj_from_bm(name, bm, mat)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.02
    return obj


@prop("Specter", pivot="bottom", material="Fabric", collide=False, texture=1024, ao=0.25, exact=True)
def specter():
    hide = mk.noisy("Spec_Skin", srgb(20, 24, 34), srgb(42, 48, 66), scale=9, detail=8, roughness=0.75)
    face = mk.noisy("Spec_Face", srgb(214, 214, 216), srgb(244, 242, 240), scale=12, detail=6, roughness=0.55)
    void = mk.flat("Spec_Void", (0.005, 0.004, 0.006), 0.9)
    lips = mk.flat("Spec_Lips", (0.012, 0.010, 0.014), 0.5)
    tooth = mk.noisy("Spec_Tooth", srgb(220, 210, 180), srgb(250, 244, 226), scale=20, roughness=0.4)
    hair = mk.noisy("Spec_Hair", srgb(34, 46, 110), srgb(70, 92, 170), scale=8, detail=10, roughness=0.45)
    plume = mk.noisy("Spec_Feather", srgb(6, 6, 8), srgb(26, 24, 32), scale=16, detail=10, roughness=0.6,
                     stretch=(1, 1, 6))
    fur = mk.noisy("Spec_Fur", srgb(206, 204, 200), srgb(246, 244, 240), scale=30, detail=12, roughness=0.9)
    cloth = mk.noisy("Spec_Cloth", srgb(8, 8, 10), srgb(26, 24, 30), scale=7, detail=10, roughness=0.9)
    leather = mk.noisy("Spec_Belt", srgb(44, 18, 18), srgb(82, 34, 30), scale=14, roughness=0.6)
    steel = mk.noisy("Spec_Steel", srgb(120, 124, 132), srgb(186, 190, 198), scale=24, roughness=0.3, metallic=0.9)
    bone = mk.noisy("Spec_Bone", BONE_B, BONE_A, scale=14, detail=8, roughness=0.6)
    book = mk.noisy("Spec_Book", srgb(10, 10, 12), srgb(26, 24, 26), scale=12, roughness=0.7)
    parts = []

    # The body: a skeleton's joints with their radii (x across, y front to back), hunched forward at the shoulders.
    J = [
        (0, 0.12, 3.95, 0.5, 0.36),  # 0 pelvis
        (0, 0.16, 4.55, 0.36, 0.28),  # 1 waist (gaunt)
        (0, 0.08, 5.35, 0.56, 0.38),  # 2 chest
        (0, -0.06, 6.05, 0.6, 0.38),  # 3 shoulders' middle
        (0, -0.32, 6.62, 0.2, 0.2),  # 4 neck
        (0.82, 0.02, 6.12, 0.24, 0.22),  # 5 right shoulder
        (1.18, -0.08, 4.72, 0.14, 0.14),  # 6 right elbow
        (1.3, -0.42, 3.3, 0.11, 0.1),  # 7 right wrist
        (1.33, -0.55, 3.02, 0.17, 0.08),  # 8 right palm
        (-0.82, 0.02, 6.12, 0.24, 0.22),  # 9 left shoulder
        (-1.18, -0.08, 4.72, 0.14, 0.14),  # 10 left elbow
        (-1.3, -0.42, 3.3, 0.11, 0.1),  # 11 left wrist
        (-1.33, -0.55, 3.02, 0.17, 0.08),  # 12 left palm
        (0.36, 0.12, 3.8, 0.27, 0.27),  # 13 right hip
        (0.48, -0.1, 2.1, 0.17, 0.17),  # 14 right knee
        (0.52, 0.16, 0.42, 0.11, 0.11),  # 15 right ankle
        (0.55, -0.3, 0.08, 0.08, 0.1),  # 16 right toe
        (-0.36, 0.12, 3.8, 0.27, 0.27),  # 17 left hip
        (-0.48, -0.1, 2.1, 0.17, 0.17),  # 18 left knee
        (-0.52, 0.16, 0.42, 0.11, 0.11),  # 19 left ankle
        (-0.55, -0.3, 0.08, 0.08, 0.1),  # 20 left toe
    ]
    B = [(0, 1), (1, 2), (2, 3), (3, 4), (3, 5), (5, 6), (6, 7), (7, 8), (3, 9), (9, 10), (10, 11), (11, 12),
         (0, 13), (13, 14), (14, 15), (15, 16), (0, 17), (17, 18), (18, 19), (19, 20)]
    parts.append(skin_body("Body", hide, J, B))
    # long clawed fingers out of each palm, curling, and a ring on one of each hand's (its stone glows)
    glow_red = mk.emissive("Spec_Glow", srgb(255, 30, 40), 8)
    glow_pale = mk.emissive("Spec_RingGlow", srgb(190, 255, 230), 6)
    glows = []
    for side in (1, -1):
        palm = Vector((side * 1.33, -0.55, 3.02))
        # (the hand itself, wrist to knuckles, so the fingers grow out of something)
        parts.append(mk.tube("Hand", Vector((side * 1.3, -0.42, 3.32)), palm + Vector((0, -0.08, -0.12)), 0.12, 0.15,
                             mat=hide, verts=12))
        parts.append(mk.sphere("Palm", 0.17, tuple(palm + Vector((0, -0.05, -0.06))), scale=(1.05, 0.6, 1.0), mat=hide,
                               segments=16, rings=10))
        for f in range(4):
            spread = (f - 1.5) * 0.09
            knuckle = palm + Vector((side * spread, -0.08, -0.12))
            mid = knuckle + Vector((side * spread * 0.6, -0.16, -0.32))
            tip = mid + Vector((side * spread * 0.3, 0.02, -0.3))
            parts.append(mk.tube("Finger", knuckle, mid, 0.05, 0.04, mat=hide, verts=8))
            parts.append(mk.tube("Claw", mid, tip, 0.04, 0.008, mat=hide, verts=8))
            if f == 2:
                parts.append(mk.torus("Ring", 0.055, 0.016, tuple(knuckle + (mid - knuckle) * 0.35), rot=(20, 0, 0),
                                      mat=steel, major_segments=12, minor_segments=6))
                glows.append(mk.sphere("Stone", 0.035, tuple(knuckle + (mid - knuckle) * 0.35 + Vector((0, -0.05, 0))),
                                       mat=glow_pale, segments=8, rings=6))
        thumb_base = palm + Vector((side * -0.14, -0.06, 0.02))
        parts.append(mk.tube("Thumb", thumb_base, thumb_base + Vector((side * -0.08, -0.22, -0.18)), 0.05, 0.01,
                             mat=hide, verts=8))

    # The head: round, jutting forward, white; everything on the face is set against its real front (`front`: the
    # head's surface straight ahead of its middle), so nothing sinks behind it or floats off it.
    head_c = Vector((0, -0.62, 7.25))
    head_r, head_sy = 0.6, 0.9
    front = head_c.y - head_r * head_sy

    def on_face(x, z, out=0.0):
        """The point of the head's surface at (x, z) from its middle, `out` studs forward of it."""
        nx, nz = x / head_r, z / head_r
        depth = math.sqrt(max(1.0 - nx * nx - nz * nz, 0.02)) * head_r * head_sy
        return Vector((x, head_c.y - depth - out, head_c.z + z))

    parts.append(mk.sphere("Head", head_r, tuple(head_c), scale=(0.94, head_sy, 1.0), mat=face, segments=32, rings=24))
    parts.append(mk.sphere("Jaw", 0.46, tuple(head_c + Vector((0, -0.14, -0.4))), scale=(1.02, 0.82, 0.62), mat=face,
                           segments=28, rings=18))
    # a heavy brow over the eyes, and the eyes in deep sockets under it, burning
    parts.append(mk.sphere("Brow", 0.44, tuple(on_face(0, 0.2, -0.16)), scale=(1.0, 0.32, 0.18), mat=face, segments=24,
                           rings=12))
    for side in (1, -1):
        parts.append(mk.sphere("Socket", 0.15, tuple(on_face(side * 0.21, 0.05, -0.05)), scale=(1.2, 0.45, 0.82),
                               mat=void, segments=16, rings=10))
        glows.append(mk.sphere("Eye", 0.095, tuple(on_face(side * 0.21, 0.05, 0.005)), scale=(1.25, 0.5, 0.95),
                               mat=glow_red, segments=12, rings=8))
        # pointed ears, swept back
        ear = mk.tube("Ear", head_c + Vector((side * 0.5, -0.05, 0.02)), head_c + Vector((side * 0.82, 0.25, 0.32)),
                      0.12, 0.01, mat=face, verts=8)
        ear.scale = (1, 0.45, 1)
        parts.append(ear)
    # the earring, a small heart on a loop at the left ear
    parts.append(mk.torus("EarLoop", 0.06, 0.012, tuple(head_c + Vector((-0.58, -0.02, -0.12))), rot=(0, 90, 0),
                          mat=steel, major_segments=12, minor_segments=6))
    parts.append(mk.sphere("Heart", 0.06, tuple(head_c + Vector((-0.6, -0.04, -0.24))), scale=(1, 0.5, 1.1),
                           mat=steel, segments=10, rings=8))
    # the nose: two slits
    for side in (1, -1):
        parts.append(mk.sphere("Nostril", 0.035, tuple(on_face(side * 0.05, -0.1, -0.01)), scale=(0.7, 0.5, 1.4),
                               mat=void, segments=8, rings=6))
    # the grin: a wide crescent from cheek to cheek on the jaw's front (its corners drawn up), thin black lips, a row of
    # big pointed teeth along each edge in front of the dark
    jaw_c = head_c + Vector((0, -0.14, -0.4))
    jaw_r, jaw_sy = 0.46, 0.82

    def on_jaw(x, z, out=0.0):
        nx = x / (jaw_r * 1.02)
        depth = math.sqrt(max(1.0 - nx * nx, 0.04)) * jaw_r * jaw_sy
        return Vector((x, jaw_c.y - depth - out, head_c.z + z))

    # (one smooth crescent laid on the jaw's curve, a hair forward of it; the lips a line along each edge)
    def top_of(x):
        u = x / 0.4
        return -0.31 + 0.12 * u * u

    def bottom_of(x):
        u = x / 0.4
        return -0.44 + 0.05 * u * u

    bm = bmesh.new()
    columns = []
    xs = [-0.4 + k * 0.8 / 24 for k in range(25)]
    for x in xs:
        columns.append((bm.verts.new(on_jaw(x, top_of(x), 0.012)), bm.verts.new(on_jaw(x, bottom_of(x), 0.012))))
    for k in range(24):
        (t0, b0), (t1, b1) = columns[k], columns[k + 1]
        bm.faces.new((t0, t1, b1, b0))
    mouth = mk._obj_from_bm("Grin", bm, void)
    solid = mouth.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.03
    parts.append(mouth)
    for k in range(24):
        for edge in (top_of, bottom_of):
            a0 = on_jaw(xs[k], edge(xs[k]), 0.05)
            a1 = on_jaw(xs[k + 1], edge(xs[k + 1]), 0.05)
            parts.append(mk.tube("Lip", a0, a1, 0.02, 0.02, mat=lips, verts=6))
    # (in front of the mouth's own thickness: it is solid 0.03 out from its face)
    # (the teeth: each row one zigzag ribbon of fangs laid on the jaw's curve in front of the dark, a single island each:
    # two dozen little fangs, or a few strips, bled dark in the bake)
    for edge, down in ((top_of, -1), (bottom_of, 1)):
        bm = bmesh.new()
        fangs = 12
        x0, x1 = -0.33, 0.33
        step = (x1 - x0) / fangs
        root = []
        tips = []
        for k in range(fangs + 1):
            x = x0 + k * step
            root.append(bm.verts.new(on_jaw(x, edge(x) - down * 0.008, 0.066)))
        for k in range(fangs):
            x = x0 + (k + 0.5) * step
            h = 0.075 if abs(x) < 0.16 else 0.058
            tips.append(bm.verts.new(on_jaw(x, edge(x) + down * h, 0.066)))
        for k in range(fangs):
            bm.faces.new((root[k], root[k + 1], tips[k]) if down > 0 else (root[k + 1], root[k], tips[k]))
        teeth = mk._obj_from_bm("Teeth", bm, tooth)
        solid = teeth.modifiers.new("Solidify", "SOLIDIFY")
        solid.thickness = 0.02
        parts.append(teeth)

    # The hair: spikes of dark blue thrown up and back off the crown.
    rng = random.Random(7)
    for k in range(16):
        a = (k / 16) * 2 * math.pi
        root = head_c + Vector((math.cos(a) * 0.32, 0.12 + math.sin(a) * 0.28, 0.42))
        lean = Vector((math.cos(a) * 0.35, 0.35 + math.sin(a) * 0.2, 1.0)).normalized()
        length = rng.uniform(0.7, 1.2) * (1.15 if math.sin(a) > 0 else 0.9)
        parts.append(mk.tube("Hair", root, root + lean * length, rng.uniform(0.11, 0.15), 0.01, mat=hair, verts=8))
    for k in range(5):
        x = (k - 2) * 0.16
        root = head_c + Vector((x, -0.25, 0.48))
        parts.append(mk.tube("Fringe", root, root + Vector((x * 0.4, -0.15, 0.55)), 0.1, 0.01, mat=hair, verts=8))

    # The collar: a ruff of white fur round the neck, and a great fan of long black feathers off the shoulders,
    # spread wide to the sides and up behind the head.
    ruff = mk.torus("Ruff", 0.5, 0.2, (0, -0.22, 6.55), rot=(12, 0, 0), mat=fur, major_segments=40, minor_segments=12)
    mk.displace_noise(ruff, strength=0.08, scale=0.12, name="RuffTufts")
    parts.append(ruff)
    for layer, (count, reach, width, lift) in enumerate(((34, (1.8, 2.9), (0.4, 0.58), 0.0), (26, (0.9, 1.6), (0.32, 0.44), 0.1))):
        for k in range(count):
            a = math.radians(-165 + k * (330 / (count - 1)))  # round the back, open at the front
            sideways = math.sin(a)
            back = math.cos(a)
            root = Vector((sideways * 0.6, 0.15 + back * 0.38, 6.42 + lift))
            up = 0.45 + 0.7 * max(0.0, back) + rng.uniform(-0.15, 0.15)
            out = Vector((sideways * 1.6, back * 0.9 + 0.3, up)).normalized()
            length = rng.uniform(*reach) * (0.75 + 0.45 * abs(sideways))
            tip = root + out * length + Vector((0, 0, -0.3 * abs(sideways)))
            parts.append(feather_blade("Feather", root, tip, rng.uniform(*width), plume))
    for k in range(12):
        a = math.radians(-130 + k * (260 / 11))
        root = Vector((math.sin(a) * 0.55, 0.05 + math.cos(a) * 0.35, 6.25))
        tip = root + Vector((math.sin(a) * 1.0, math.cos(a) * 0.6 + 0.25, -0.65))
        parts.append(feather_blade("Feather", root, tip, 0.22, plume))

    # The belt: studded leather slung round the hips, a skull for its buckle, chains hanging off it.
    parts.append(mk.torus("Belt", 0.5, 0.07, (0, 0.1, 4.12), rot=(-6, 0, 0), mat=leather, major_segments=40,
                          minor_segments=8))
    for k in range(14):
        a = 2 * math.pi * k / 14
        parts.append(mk.sphere("Stud", 0.03, (math.sin(a) * 0.56, 0.1 + math.cos(a) * 0.44, 4.12 - 0.05 * math.cos(a)),
                               mat=steel, segments=8, rings=6))
    buckle = Vector((0, -0.42, 4.08))
    parts.append(mk.sphere("Buckle", 0.14, tuple(buckle), scale=(1, 0.6, 1.05), mat=bone, segments=16, rings=12))
    for side in (1, -1):
        parts.append(mk.sphere("BuckleEye", 0.035, tuple(buckle + Vector((side * 0.05, -0.08, 0.02))), mat=void,
                               segments=8, rings=6))

    def chain(a, b, sag, count):
        for k in range(count):
            t = (k + 0.5) / count
            p = a + (b - a) * t - Vector((0, 0, sag * 4 * t * (1 - t)))
            parts.append(mk.torus("Link", 0.05, 0.014, tuple(p), rot=(90 if k % 2 else 0, 0, 0), mat=steel,
                                  major_segments=10, minor_segments=5))

    chain(Vector((-0.45, -0.2, 4.0)), Vector((0.52, -0.05, 3.95)), 0.35, 16)
    chain(Vector((0.52, -0.05, 3.95)), Vector((0.66, -0.12, 3.1)), 0.05, 9)
    parts.append(mk.sphere("ChainSkull", 0.09, (0.66, -0.14, 3.0), scale=(1, 0.85, 1.05), mat=bone, segments=12,
                           rings=8))
    # The Manual at the hip, chained there.
    parts.append(mk.box("HipBook", (0.36, 0.1, 0.48), (0.66, 0.06, 3.62), rot=(0, 0, -12), mat=book, bevel=0.02))
    parts.append(mk.box("HipBookPages", (0.32, 0.08, 0.44), (0.67, 0.07, 3.62), rot=(0, 0, -12),
                        mat=mk.noisy("Spec_Pages", srgb(150, 110, 60), srgb(200, 160, 100), scale=30), bevel=0.0))
    # The skirt: short, black and torn to tatters at its hem.
    skirt = robe_mesh("Skirt", cloth, [(0.82, 2.95, 0.82), (0.72, 3.45, 0.8), (0.6, 3.95, 0.78), (0.55, 4.15, 0.8)],
                      segments=36, seed=11)
    skirt.location = (0, 0.12, 0)
    mk.displace_noise(skirt, strength=0.06, scale=0.3, name="SkirtFolds")
    parts.append(skirt)
    # A skull at the right wrist, on a cord; a plain band at the left.
    wrist = Vector((1.3, -0.42, 3.3))
    parts.append(mk.torus("Cord", 0.13, 0.02, tuple(wrist), rot=(60, 0, 20), mat=leather, major_segments=16,
                          minor_segments=6))
    parts.append(mk.sphere("WristSkull", 0.1, tuple(wrist + Vector((0.12, -0.06, 0.0))), scale=(0.9, 0.8, 1.05),
                           mat=bone, segments=12, rings=8))
    parts.append(mk.torus("Band", 0.13, 0.025, (-1.3, -0.42, 3.3), rot=(60, 0, -20), mat=steel, major_segments=16,
                          minor_segments=6))
    # (the eyes' red first: it is the prop's main glow, Specter_Glow; the rings' pale stones the second)
    glows.sort(key=lambda o: 0 if o.name.startswith("Eye") else 1)
    return parts, glows


# Street and park ----------------------------------------------------------------------------------------------


@prop("LampPost", pivot="bottom", material="Metal", collide=True, texture=1024)
def lamp_post():
    iron = cast_iron("Lamp_Iron")
    glass = mk.noisy("Lamp_Glass", srgb(40, 44, 52), srgb(70, 76, 90), scale=8, roughness=0.1)
    parts = [
        mk.cylinder("Plinth", 0.62, 0.35, (0, 0, 0.175), mat=iron, verts=8, bevel=0.03),
        mk.cylinder("Plinth2", 0.48, 0.5, (0, 0, 0.6), mat=iron, verts=8, bevel=0.03, radius2=0.36),
        mk.cylinder("Pole", 0.17, 10.6, (0, 0, 6.1), mat=iron, verts=12, radius2=0.12),
    ]
    for z in (1.0, 4.0, 11.2):
        parts.append(mk.torus("Collar", 0.2, 0.05, (0, 0, z), mat=iron, major_segments=16, minor_segments=6))
    # Arm curling out to the front, with a scroll underneath.
    for i in range(10):
        a = math.radians(i * 10)
        parts.append(mk.cylinder("Arm", 0.07, 0.35, (0, -1.1 * math.sin(a), 11.4 + 1.1 * (1 - math.cos(a)) * 0.6),
                                 rot=(90 - i * 6, 0, 0), mat=iron, verts=8))
    parts.append(mk.torus("Scroll", 0.35, 0.04, (0, -0.55, 11.0), rot=(0, 90, 0), mat=iron, major_segments=20,
                          minor_segments=6))
    # Lantern: hexagonal glass box with an iron frame and a pointed roof.
    lx, lz = -1.15, 11.0
    parts.append(mk.cylinder("LanternBase", 0.42, 0.12, (0, lx, lz - 0.7), mat=iron, verts=6))
    parts.append(mk.cylinder("LanternGlass", 0.36, 1.1, (0, lx, lz - 0.1), mat=glass, verts=6, radius2=0.44))
    parts.append(mk.cylinder("LanternRoof", 0.56, 0.5, (0, lx, lz + 0.7), mat=iron, verts=6, radius2=0.05))
    parts.append(mk.sphere("Finial", 0.09, (0, lx, lz + 1.0), mat=iron, segments=10, rings=6))
    for i in range(6):
        a = math.radians(i * 60)
        parts.append(mk.box("Frame", (0.04, 0.04, 1.15), (math.cos(a) * 0.41, lx + math.sin(a) * 0.41, lz - 0.1),
                            mat=iron))
    bulb = [mk.sphere("Bulb", 0.22, (0, lx, lz - 0.1), scale=(1, 1, 1.3), mat=mk.emissive("Lamp_Glow", LAMP, 8),
                      segments=16, rings=10)]
    return parts, bulb


@prop("Bench", pivot="bottom", material="Wood", collide=True, texture=1024)
def bench():
    iron = cast_iron("Bench_Iron")
    wood = dark_wood("Bench_Wood")
    parts = []
    side_profile = [(-0.8, 0), (-0.6, 0), (-0.45, 1.3), (0.55, 1.3), (0.7, 0), (0.9, 0), (0.75, 1.5),
                    (0.95, 3.3), (0.8, 3.35), (0.55, 1.6), (-0.5, 1.6), (-0.65, 2.3), (-0.85, 2.3), (-0.7, 1.4)]
    for x in (-2.6, 2.6):
        side = mk.extrude_shape("Side", side_profile, 0.12, mat=iron, bevel=0.02)
        side.location = (x, 0, 0)
        side.rotation_euler = (math.radians(90), 0, math.radians(90))
        parts.append(side)
    for i in range(5):
        parts.append(mk.box("Seat", (5.8, 0.28, 0.09), (0, -0.55 + i * 0.3, 1.52), mat=wood, bevel=0.03))
    for i in range(3):
        z = 2.0 + i * 0.42
        parts.append(mk.box("Back", (5.8, 0.09, 0.3), (0, 0.72 + i * 0.07, z), rot=(-12, 0, 0), mat=wood, bevel=0.03))
    for x in (-2.6, 2.6):
        parts.append(mk.box("Arm", (0.14, 1.4, 0.1), (x, -0.1, 2.3), mat=iron, bevel=0.03))
    return parts, []


@prop("Crate", pivot="bottom", material="WoodPlanks", collide=True, texture=1024)
def crate():
    planks = mk.wood("Crate_Planks", srgb(150, 112, 70), srgb(94, 66, 40), scale=5, rings=10)
    frame = mk.wood("Crate_Frame", srgb(110, 80, 48), srgb(70, 48, 28), scale=5, rings=10)
    stencil = mk.flat("Crate_Stencil", srgb(40, 30, 24), 0.9)
    s = 4.0
    parts = [mk.box("Core", (s - 0.2, s - 0.2, s - 0.2), (0, 0, s / 2), mat=planks)]
    # Planks with gaps on every side.
    for axis in range(3):
        for sign in (-1, 1):
            for i in range(4):
                offset = -s / 2 + 0.5 + i * 1.0
                size = [s - 0.3, s - 0.3, s - 0.3]
                size[axis] = 0.08
                loc = [0.0, 0.0, s / 2]
                loc[axis] += sign * (s / 2 - 0.08)
                other = (axis + 1) % 3
                size[other] = 0.92
                loc[other] += offset
                parts.append(mk.box("Plank", tuple(size), tuple(loc), mat=planks, bevel=0.02))
    # Frame battens along every edge.
    for x in (-1, 1):
        for y in (-1, 1):
            parts.append(mk.box("Post", (0.32, 0.32, s), (x * (s / 2 - 0.12), y * (s / 2 - 0.12), s / 2), mat=frame,
                                bevel=0.03))
            parts.append(mk.box("RailX", (s, 0.3, 0.3), (0, y * (s / 2 - 0.12), (s - 0.15) if x > 0 else 0.15),
                                mat=frame, bevel=0.03))
            parts.append(mk.box("RailY", (0.3, s, 0.3), (x * (s / 2 - 0.12), 0, (s - 0.15) if y > 0 else 0.15),
                                mat=frame, bevel=0.03))
    # A stencilled "0" on the front.
    parts.append(mk.torus("Stencil", 0.55, 0.08, (0, -s / 2 - 0.04, s / 2), rot=(90, 0, 0), mat=stencil,
                          major_segments=24, minor_segments=4))
    return parts, []


@prop("Dumpster", pivot="bottom", material="Metal", collide=True, texture=1024)
def dumpster():
    green = mk.noisy("Dump_Paint", srgb(24, 50, 36), srgb(46, 70, 52), scale=10, detail=12, roughness=0.6,
                     metallic=0.4)
    rust = mk.noisy("Dump_Rust", srgb(60, 36, 24), srgb(96, 60, 36), scale=14, roughness=0.8)
    lid = mk.noisy("Dump_Lid", srgb(14, 14, 16), srgb(34, 34, 38), scale=12, roughness=0.5)
    parts = [
        mk.box("Body", (6, 3, 3.4), (0, 0, 2.1), mat=green, bevel=0.06),
        mk.box("Base", (6.2, 3.2, 0.3), (0, 0, 0.5), mat=rust, bevel=0.04),
        mk.box("LidL", (2.95, 3.1, 0.12), (-1.5, 0.05, 3.88), rot=(-6, 0, 0), mat=lid, bevel=0.03),
        mk.box("LidR", (2.95, 3.1, 0.12), (1.5, 0.05, 3.9), rot=(-2, 0, 0), mat=lid, bevel=0.03),
    ]
    for x in (-2.6, 2.6):
        parts.append(mk.box("Pocket", (0.5, 3.3, 0.4), (x, 0, 2.6), mat=rust, bevel=0.04))
        for y in (-1.2, 1.2):
            parts.append(mk.cylinder("Wheel", 0.28, 0.2, (x, y, 0.28), rot=(0, 90, 0), mat=lid, verts=16))
    for i in range(5):
        parts.append(mk.box("Rib", (0.12, 0.06, 3.0), (-2.4 + i * 1.2, -1.53, 2.1), mat=green, bevel=0.02))
    return parts, []


@prop("TrashCan", pivot="bottom", material="Metal", collide=True, texture=512)
def trash_can():
    steel = mk.noisy("Trash_Steel", srgb(70, 72, 76), srgb(110, 112, 118), scale=18, roughness=0.4, metallic=0.8)
    parts = [
        mk.lathe("Can", [(0.0, 0.0), (0.55, 0.0), (0.58, 0.1), (0.6, 2.0), (0.64, 2.05), (0.0, 2.05)], mat=steel,
                 segments=24),
        mk.lathe("Lid", [(0.66, 2.05), (0.66, 2.15), (0.5, 2.3), (0.15, 2.38), (0.0, 2.38)], mat=steel, segments=24),
        mk.torus("Handle", 0.14, 0.03, (0, 0, 2.42), rot=(90, 0, 0), mat=steel, major_segments=12, minor_segments=6),
    ]
    for z in (0.5, 1.0, 1.5):
        parts.append(mk.torus("Rib", 0.6, 0.025, (0, 0, z), mat=steel, major_segments=24, minor_segments=4))
    return parts, []


@prop("Hydrant", pivot="bottom", material="Metal", collide=True, texture=512)
def hydrant():
    paint = mk.noisy("Hyd_Paint", srgb(130, 18, 24), srgb(170, 34, 36), scale=16, roughness=0.5, metallic=0.3)
    cap = mk.noisy("Hyd_Cap", srgb(60, 60, 64), srgb(100, 100, 106), scale=16, roughness=0.4, metallic=0.8)
    parts = [
        mk.lathe("Body", [(0.0, 0.0), (0.4, 0.0), (0.4, 0.15), (0.3, 0.2), (0.28, 1.3), (0.34, 1.35), (0.3, 1.5),
                          (0.2, 1.8), (0.0, 1.85)], mat=paint, segments=20),
        mk.cylinder("Nozzle", 0.12, 0.3, (0.38, 0, 1.0), rot=(0, 90, 0), mat=cap, verts=12),
        mk.cylinder("Nozzle", 0.12, 0.3, (-0.38, 0, 1.0), rot=(0, 90, 0), mat=cap, verts=12),
        mk.cylinder("Front", 0.16, 0.25, (0, -0.35, 1.0), rot=(90, 0, 0), mat=cap, verts=12),
        mk.cylinder("Bolt", 0.06, 0.15, (0, 0, 1.9), mat=cap, verts=6),
    ]
    return parts, []


@prop("Tree", pivot="bottom", material="Grass", collide=True, texture=1024)
def tree():
    bark = mk.noisy("Tree_Bark", srgb(34, 26, 22), srgb(60, 46, 36), scale=4, detail=12, roughness=0.9,
                    stretch=(3, 3, 0.4))
    leaves = mk.noisy("Tree_Leaves", *FOLIAGE, scale=3, detail=12, roughness=0.9)
    trunk = mk.lathe("Trunk", [(0.0, 0.0), (1.0, 0.0), (0.75, 0.4), (0.62, 2.0), (0.55, 5.0), (0.45, 8.0),
                               (0.3, 9.5), (0.0, 9.6)], mat=bark, segments=16)
    mk.displace_noise(trunk, strength=0.12, scale=0.8, name="Bark")
    parts = [trunk]
    rng = random.Random(7)
    for i in range(5):
        a = i * 1.3
        length = 3.2 - i * 0.2
        parts.append(mk.cylinder("Branch", 0.22, length,
                                 (math.cos(a) * length * 0.35, math.sin(a) * length * 0.35, 6.5 + i * 0.6),
                                 rot=(math.degrees(math.sin(a)) * -0.8 - 40 * math.sin(a), 40 * math.cos(a), 0),
                                 mat=bark, verts=8, radius2=0.08))
    for i in range(9):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.5, 2.6)
        blob = mk.sphere("Leaves", rng.uniform(2.0, 3.1),
                         (math.cos(a) * r, math.sin(a) * r, rng.uniform(9.0, 12.5)),
                         scale=(1, 1, rng.uniform(0.7, 0.9)), mat=leaves, segments=16, rings=10)
        mk.displace_noise(blob, strength=0.6, scale=0.9, name="Foliage")
        parts.append(blob)
    return parts, []


@prop("Plant", pivot="bottom", material="Grass", collide=True, texture=512)
def plant():
    pot = mk.noisy("Plant_Pot", srgb(40, 30, 28), srgb(70, 52, 44), scale=10, roughness=0.8)
    soil = mk.flat("Plant_Soil", srgb(22, 16, 12), 1.0)
    leaf = mk.noisy("Plant_Leaf", *FOLIAGE, scale=6, roughness=0.7)
    parts = [
        mk.lathe("Pot", [(0.0, 0.0), (0.6, 0.0), (0.8, 1.6), (0.9, 1.7), (0.9, 1.85), (0.0, 1.85)], mat=pot,
                 segments=24),
        mk.cylinder("Soil", 0.82, 0.05, (0, 0, 1.78), mat=soil, verts=24),
    ]
    rng = random.Random(3)
    for i in range(14):
        a = i * (math.tau / 14) + rng.uniform(-0.2, 0.2)
        tilt = rng.uniform(25, 55)
        length = rng.uniform(1.6, 2.6)
        blade = mk.extrude_shape("Leaf", [(0, 0), (0.25, 0.6), (0.18, 1.4), (0, 2.0), (-0.18, 1.4), (-0.25, 0.6)], 0.03,
                                 mat=leaf)
        blade.scale = (1, length / 2.0, 1)
        blade.location = (0, 0, 1.8)
        blade.rotation_euler = (math.radians(90 - tilt), 0, a)
        parts.append(blade)
    return parts, []


@prop("Car", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024)
def car():
    """A 1950s-style noir sedan: the body is one extruded side profile."""
    paint = mk.noisy("Car_Paint", srgb(16, 16, 20), srgb(40, 40, 48), scale=4, roughness=0.25, metallic=0.5)
    chrome = mk.noisy("Car_Chrome", STEEL_B, STEEL_A, scale=10, roughness=0.15, metallic=1.0)
    glass = mk.noisy("Car_Glass", srgb(26, 30, 40), srgb(60, 70, 88), scale=6, roughness=0.05)
    tyre = mk.flat("Car_Tyre", srgb(14, 14, 14), 0.9)
    profile = [(-5.0, 0.55), (-5.15, 1.15), (-5.0, 1.75), (-2.6, 2.05), (-1.4, 2.2), (-0.8, 3.35), (1.3, 3.45),
               (2.5, 2.45), (4.8, 2.2), (5.15, 1.7), (5.15, 0.9), (4.8, 0.55)]
    body = mk.extrude_shape("Body", profile, 4.8, rot=(90, 0, 90), mat=paint, bevel=0.12)
    parts = [body]
    window = [(-0.7, 2.35), (-0.25, 3.2), (1.2, 3.28), (2.2, 2.45)]
    for x in (-2.42, 2.42):
        parts.append(mk.extrude_shape("Window", window, 0.06, (x, 0, 0), rot=(90, 0, 90), mat=glass))
        parts.append(mk.box("Trim", (0.06, 9.6, 0.08), (x * 1.005, 0, 1.45), mat=chrome))
    parts.append(mk.box("Windshield", (4.2, 0.06, 1.25), (0, -1.1, 2.8), rot=(-58, 0, 0), mat=glass))
    parts.append(mk.box("RearWindow", (4.2, 0.06, 1.2), (0, 1.9, 2.95), rot=(50, 0, 0), mat=glass))
    parts.append(mk.box("BumperF", (5.2, 0.4, 0.4), (0, -5.25, 0.85), mat=chrome, bevel=0.12))
    parts.append(mk.box("BumperR", (5.2, 0.4, 0.4), (0, 5.25, 0.85), mat=chrome, bevel=0.12))
    parts.append(mk.box("Grille", (2.4, 0.12, 0.55), (0, -5.12, 1.35), mat=chrome, bevel=0.04))
    for i in range(6):
        parts.append(mk.box("GrilleBar", (0.05, 0.14, 0.5), (-1.0 + i * 0.4, -5.16, 1.35), mat=paint))
    for x in (-2.3, 2.3):
        for y in (-3.3, 3.3):
            parts.append(mk.cylinder("Tyre", 0.95, 0.75, (x, y, 0.95), rot=(0, 90, 0), mat=tyre, verts=24, bevel=0.12))
            parts.append(mk.cylinder("Hub", 0.5, 0.8, (x, y, 0.95), rot=(0, 90, 0), mat=chrome, verts=16))
    glow = [
        mk.sphere("Headlight", 0.3, (x, -5.1, 1.65), scale=(1, 0.5, 1), mat=mk.emissive("Car_Head", srgb(255, 236, 200), 6),
                  segments=14, rings=8)
        for x in (-1.75, 1.75)
    ]
    glow += [mk.box("Tail", (0.7, 0.1, 0.35), (x, 5.17, 1.5), mat=mk.emissive("Car_Tail", RED, 5)) for x in (-1.9, 1.9)]
    return parts, glow


# Offices ------------------------------------------------------------------------------------------------


@prop("Desk", pivot="bottom", material="Wood", collide=True, texture=1024)
def desk():
    wood = dark_wood("Desk_Wood")
    metal = mk.noisy("Desk_Metal", srgb(30, 30, 34), srgb(60, 60, 66), scale=16, roughness=0.4, metallic=0.8)
    plastic = mk.noisy("Desk_Plastic", srgb(196, 188, 170), srgb(222, 214, 196), scale=20, roughness=0.6)
    screen = mk.flat("Desk_Screen", srgb(16, 22, 20), 0.2)
    paper = mk.noisy("Desk_Paper", PAPER_B, PAPER_A, scale=40, roughness=0.9)
    brass = mk.noisy("Desk_Brass", BRASS_B, BRASS_A, scale=14, roughness=0.3, metallic=1.0)
    parts = [
        mk.box("Top", (6.0, 3.0, 0.22), (0, 0, 2.94), mat=wood, bevel=0.05),
        mk.box("Pedestal", (1.9, 2.7, 2.8), (-1.95, 0.05, 1.45), mat=wood, bevel=0.04),
        mk.box("Modesty", (4.0, 0.12, 1.6), (1.0, 1.3, 2.0), mat=wood, bevel=0.03),
        mk.box("LegR", (0.22, 2.7, 2.83), (2.85, 0.05, 1.42), mat=wood, bevel=0.03),
    ]
    for i in range(3):
        z = 0.55 + i * 0.9
        parts.append(mk.box("Drawer", (1.7, 0.06, 0.78), (-1.95, -1.33, z), mat=wood, bevel=0.03))
        parts.append(mk.box("Handle", (0.5, 0.08, 0.07), (-1.95, -1.4, z + 0.15), mat=brass, bevel=0.02))
    # A boxy CRT monitor and keyboard.
    parts.append(mk.box("Monitor", (1.9, 1.7, 1.5), (1.1, 0.5, 3.85), mat=plastic, bevel=0.12))
    parts.append(mk.box("MonitorBack", (1.4, 0.9, 1.1), (1.1, 1.3, 3.8), mat=plastic, bevel=0.15))
    parts.append(mk.box("Bezel", (1.5, 0.05, 1.1), (1.1, -0.36, 3.9), mat=screen, bevel=0.05))
    parts.append(mk.box("Keyboard", (1.8, 0.65, 0.12), (1.0, -0.85, 3.11), rot=(4, 0, 0), mat=plastic, bevel=0.04))
    # Papers and a desk lamp.
    for i, (x, y, r) in enumerate(((-1.4, -0.4, 8), (-1.1, -0.2, -5), (-1.7, 0.3, 14))):
        parts.append(mk.box("Paper", (1.0, 1.3, 0.02), (x, y, 3.06 + i * 0.02), rot=(0, 0, r), mat=paper))
    parts.append(mk.cylinder("LampBase", 0.35, 0.1, (-2.4, 0.9, 3.1), mat=brass, verts=16))
    parts.append(mk.cylinder("LampArm", 0.04, 1.3, (-2.4, 0.75, 3.7), rot=(-20, 0, 0), mat=brass, verts=8))
    parts.append(mk.cylinder("LampShade", 0.5, 0.45, (-2.4, 0.35, 4.3), rot=(-35, 0, 0), mat=mk.flat("Desk_Shade",
                             srgb(20, 60, 36), 0.4), verts=16, radius2=0.18))
    glow = [
        mk.box("Screen", (1.3, 0.04, 0.9), (1.1, -0.39, 3.9), mat=mk.emissive("Desk_Glow", srgb(80, 220, 150), 3)),
        mk.sphere("Bulb", 0.14, (-2.4, 0.18, 4.12), mat=mk.emissive("Desk_Bulb", LAMP, 6), segments=10, rings=8),
    ]
    return parts, glow


@prop("OfficeChair", pivot="bottom", material="Leather", collide=True, texture=512)
def office_chair():
    leather = mk.noisy("Chair_Leather", srgb(22, 20, 22), srgb(44, 40, 42), scale=10, roughness=0.5)
    metal = mk.noisy("Chair_Metal", srgb(60, 60, 66), srgb(110, 110, 118), scale=16, roughness=0.3, metallic=1.0)
    parts = []
    for i in range(5):
        a = math.radians(i * 72)
        parts.append(mk.box("Leg", (0.14, 0.9, 0.12), (math.sin(a) * 0.45, math.cos(a) * 0.45, 0.28),
                            rot=(0, 0, -math.degrees(a)), mat=metal, bevel=0.03))
        parts.append(mk.sphere("Caster", 0.12, (math.sin(a) * 0.88, math.cos(a) * 0.88, 0.12), mat=metal,
                               segments=10, rings=6))
    parts.append(mk.cylinder("Gas", 0.09, 1.1, (0, 0, 0.85), mat=metal, verts=12))
    parts.append(mk.box("Seat", (1.8, 1.7, 0.35), (0, -0.05, 1.55), mat=leather, bevel=0.14, segments=3))
    parts.append(mk.box("Back", (1.7, 0.3, 2.0), (0, 0.8, 2.75), rot=(-8, 0, 0), mat=leather, bevel=0.14, segments=3))
    for x in (-0.95, 0.95):
        parts.append(mk.box("ArmPost", (0.1, 0.1, 0.55), (x, 0.1, 1.9), mat=metal))
        parts.append(mk.box("ArmPad", (0.2, 0.9, 0.1), (x, 0.0, 2.2), mat=leather, bevel=0.04))
    return parts, []


@prop("FilingCabinet", pivot="bottom", material="Metal", collide=True, texture=512)
def filing_cabinet():
    body = mk.noisy("File_Body", srgb(70, 76, 72), srgb(100, 106, 100), scale=14, detail=12, roughness=0.5,
                    metallic=0.6)
    metal = mk.noisy("File_Metal", STEEL_B, STEEL_A, scale=18, roughness=0.3, metallic=1.0)
    label = mk.noisy("File_Label", PAPER_B, PAPER_A, scale=40, roughness=0.9)
    parts = [mk.box("Body", (2.4, 2.0, 5.0), (0, 0, 2.5), mat=body, bevel=0.06)]
    for i in range(3):
        z = 0.95 + i * 1.6
        parts.append(mk.box("Drawer", (2.2, 0.08, 1.45), (0, -1.02, z), mat=body, bevel=0.04))
        parts.append(mk.box("Handle", (0.8, 0.12, 0.12), (0, -1.1, z + 0.25), mat=metal, bevel=0.03))
        parts.append(mk.box("Label", (0.6, 0.04, 0.28), (0, -1.07, z + 0.55), mat=label))
    return parts, []


@prop("Bookshelf", pivot="bottom", material="Wood", collide=True, texture=1024)
def bookshelf():
    wood = dark_wood("Shelf_Wood")
    colours = [srgb(110, 20, 26), srgb(30, 44, 80), srgb(170, 140, 80), srgb(34, 60, 38), srgb(60, 40, 30),
               srgb(20, 20, 24), srgb(140, 130, 118)]
    books = [mk.noisy(f"Shelf_Book{i}", c, tuple(min(1.0, v * 1.4) for v in c), scale=30, roughness=0.7)
             for i, c in enumerate(colours)]
    parts = [
        mk.box("Back", (3.0, 0.1, 8.0), (0, 0.75, 4.0), mat=wood),
        mk.box("SideL", (0.15, 1.6, 8.0), (-1.45, 0, 4.0), mat=wood, bevel=0.03),
        mk.box("SideR", (0.15, 1.6, 8.0), (1.45, 0, 4.0), mat=wood, bevel=0.03),
        mk.box("Crown", (3.2, 1.75, 0.2), (0, 0, 8.0), mat=wood, bevel=0.05),
    ]
    rng = random.Random(11)
    for level in range(4):
        z = 0.2 + level * 1.95
        parts.append(mk.box("Board", (2.8, 1.5, 0.12), (0, 0, z), mat=wood, bevel=0.02))
        x = -1.3
        while x < 1.25:
            thick = rng.uniform(0.14, 0.26)
            tall = rng.uniform(1.1, 1.6)
            if rng.random() < 0.12:
                x += thick
                continue
            lean = rng.uniform(-6, 6) if rng.random() < 0.2 else 0
            parts.append(mk.box("Book", (thick, rng.uniform(0.9, 1.2), tall),
                                (x + thick / 2, -0.05, z + 0.06 + tall / 2), rot=(0, lean, 0),
                                mat=rng.choice(books), bevel=0.015))
            x += thick + 0.01
    return parts, []


@prop("VendingMachine", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024)
def vending_machine():
    body = mk.noisy("Vend_Body", srgb(150, 20, 30), srgb(190, 40, 46), scale=12, roughness=0.4, metallic=0.2)
    dark = mk.noisy("Vend_Dark", srgb(18, 18, 20), srgb(36, 36, 40), scale=12, roughness=0.4)
    glass = mk.noisy("Vend_Glass", srgb(24, 30, 40), srgb(40, 50, 66), scale=6, roughness=0.05)
    cans = [mk.flat(f"Vend_Can{i}", c, 0.3) for i, c in enumerate((srgb(220, 40, 40), srgb(40, 110, 220),
                                                                  srgb(240, 200, 60), srgb(60, 180, 90)))]
    parts = [
        mk.box("Body", (4.0, 2.6, 7.0), (0, 0, 3.5), mat=body, bevel=0.1),
        mk.box("Recess", (2.7, 0.1, 4.2), (-0.45, -0.7, 4.4), mat=dark),
        mk.box("FrameTop", (2.9, 0.2, 0.15), (-0.45, -1.28, 6.55), mat=dark),
        mk.box("FrameBottom", (2.9, 0.2, 0.15), (-0.45, -1.28, 2.25), mat=dark),
        mk.box("FrameLeft", (0.15, 0.2, 4.4), (-1.85, -1.28, 4.4), mat=dark),
        mk.box("Panel", (0.9, 0.1, 4.2), (1.45, -1.28, 4.4), mat=dark, bevel=0.03),
        mk.box("Tray", (2.6, 0.3, 0.8), (-0.45, -1.25, 1.2), mat=dark, bevel=0.05),
        mk.box("Kick", (4.0, 2.4, 0.4), (0, 0.05, 0.2), mat=dark),
    ]
    for row in range(5):
        for col in range(5):
            parts.append(mk.cylinder("Can", 0.18, 0.5, (-1.5 + col * 0.52, -0.95, 2.85 + row * 0.78),
                                     mat=cans[(row + col) % 4], verts=10))
        parts.append(mk.box("Shelf", (2.7, 0.6, 0.06), (-0.45, -0.95, 2.57 + row * 0.78), mat=glass))
    for i in range(6):
        parts.append(mk.box("Button", (0.18, 0.06, 0.18), (1.3 + (i % 2) * 0.3, -1.35, 5.4 - (i // 2) * 0.35),
                            mat=dark, bevel=0.02))
    glow = [mk.box("Sign", (3.6, 0.08, 0.8), (0, -1.3, 6.7), mat=mk.emissive("Vend_Glow", srgb(220, 240, 255), 3))]
    return parts, glow


@prop("ServerRack", pivot="bottom", material="Metal", collide=True, texture=512)
def server_rack():
    frame = mk.noisy("Rack_Frame", srgb(20, 22, 26), srgb(40, 42, 48), scale=14, roughness=0.4, metallic=0.8)
    unit = mk.noisy("Rack_Unit", srgb(30, 32, 36), srgb(54, 56, 62), scale=20, roughness=0.4, metallic=0.6)
    parts = [mk.box("Frame", (3.0, 3.0, 8.0), (0, 0, 4.0), mat=frame, bevel=0.05)]
    for i in range(10):
        parts.append(mk.box("Unit", (2.6, 0.1, 0.6), (0, -1.5, 0.7 + i * 0.7), mat=unit, bevel=0.02))
        for v in range(8):
            parts.append(mk.box("Vent", (0.12, 0.02, 0.35), (-1.0 + v * 0.18, -1.56, 0.7 + i * 0.7), mat=frame))
    glow = []
    rng = random.Random(5)
    for i in range(10):
        for led in range(3):
            colour = (srgb(60, 255, 120), srgb(80, 170, 255), srgb(255, 170, 60))[rng.randrange(3)]
            glow.append(mk.box("Led", (0.08, 0.03, 0.08), (0.8 + led * 0.2, -1.57, 0.8 + i * 0.7),
                               mat=mk.emissive(f"Rack_Led{led}{i}", colour, 5)))
    return parts, glow


@prop("Sofa", pivot="bottom", material="Leather", collide=True, texture=1024)
def sofa():
    leather = mk.noisy("Sofa_Leather", *LEATHER_RED, scale=8, roughness=0.45)
    wood = dark_wood("Sofa_Wood")
    parts = [
        mk.box("Base", (7.0, 3.0, 1.0), (0, 0, 0.9), mat=leather, bevel=0.2, segments=3),
        mk.box("Back", (7.0, 0.8, 2.2), (0, 1.1, 2.0), mat=leather, bevel=0.3, segments=3),
    ]
    for x in (-3.3, 3.3):
        parts.append(mk.box("Arm", (0.8, 3.0, 1.8), (x, 0, 1.6), mat=leather, bevel=0.3, segments=3))
    for x in (-1.7, 0, 1.7):
        parts.append(mk.box("Cushion", (1.65, 2.2, 0.45), (x, -0.25, 1.62), mat=leather, bevel=0.18, segments=3))
    for x in (-2.4, -1.2, 0, 1.2, 2.4):
        for z in (2.2, 2.8):
            parts.append(mk.sphere("Button", 0.07, (x, 0.68, z), mat=mk.flat("Sofa_Button", DEEP_RED, 0.5),
                                   segments=8, rings=6))
    for x in (-3.3, 3.3):
        for y in (-1.2, 1.2):
            parts.append(mk.cylinder("Foot", 0.14, 0.4, (x, y, 0.2), mat=wood, verts=10, radius2=0.1))
    return parts, []


@prop("Table", pivot="bottom", material="Wood", collide=True, texture=512)
def table():
    wood = dark_wood("Table_Wood")
    parts = [mk.box("Top", (5.0, 3.0, 0.22), (0, 0, 2.64), mat=wood, bevel=0.06),
             mk.box("Apron", (4.5, 2.5, 0.35), (0, 0, 2.36), mat=wood, bevel=0.03)]
    for x in (-2.2, 2.2):
        for y in (-1.2, 1.2):
            parts.append(mk.lathe("Leg", [(0.0, 0.0), (0.12, 0.0), (0.16, 0.3), (0.1, 0.8), (0.15, 1.4),
                                          (0.12, 2.0), (0.14, 2.3), (0.0, 2.3)], (x, y, 0), mat=wood, segments=12))
    return parts, []


@prop("MeetingTable", pivot="bottom", material="Wood", collide=True, texture=1024)
def meeting_table():
    wood = mk.wood("Meet_Wood", srgb(70, 40, 28), srgb(34, 18, 12), scale=2, rings=30)
    iron = cast_iron("Meet_Iron")
    felt = mk.noisy("Meet_Felt", srgb(18, 24, 20), srgb(30, 40, 34), scale=30, roughness=1.0)
    parts = [
        mk.cylinder("Top", 13.0, 0.5, (0, 0, 3.0), mat=wood, verts=64, bevel=0.1),
        mk.cylinder("Inset", 10.5, 0.06, (0, 0, 3.26), mat=felt, verts=64),
        mk.cylinder("Rim", 13.05, 0.2, (0, 0, 2.7), mat=iron, verts=64),
        mk.cylinder("Pedestal", 2.4, 2.6, (0, 0, 1.4), mat=iron, verts=32, radius2=1.6),
        mk.cylinder("Foot", 4.0, 0.3, (0, 0, 0.15), mat=iron, verts=32, bevel=0.05),
    ]
    glow = [
        mk.torus("Ring", 11.0, 0.08, (0, 0, 3.27), mat=mk.emissive("Meet_Glow", RED, 4), major_segments=96,
                 minor_segments=6),
        mk.torus("Zero", 1.6, 0.14, (0, 0, 3.3), mat=mk.emissive("Meet_Glow", RED, 4), major_segments=48,
                 minor_segments=6),
    ]
    glow[1].scale = (0.75, 1.0, 1.0)
    return parts, glow


@prop("Chair", pivot="bottom", material="Wood", collide=True, texture=512)
def chair():
    wood = dark_wood("WChair_Wood")
    seat = mk.noisy("WChair_Seat", *LEATHER_RED, scale=10, roughness=0.5)
    parts = [mk.box("Seat", (1.8, 1.8, 0.25), (0, 0, 1.62), mat=seat, bevel=0.08)]
    for x in (-0.75, 0.75):
        for y in (-0.75, 0.75):
            tall = 3.9 if y > 0 else 1.5
            parts.append(mk.box("Leg", (0.16, 0.16, tall), (x, y, tall / 2), mat=wood, bevel=0.03))
    for z in (2.4, 3.0, 3.6):
        parts.append(mk.box("Rail", (1.5, 0.1, 0.25), (0, 0.75, z), mat=wood, bevel=0.03))
    return parts, []
