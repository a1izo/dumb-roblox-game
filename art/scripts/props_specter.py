"""The Deathsinger (Core "Specter"): the death god who stands behind Diavolo, drawn into being in the eye deal and the
role card. Remade 2026-10-25 to the bar of a high-quality Roblox horror model, from the Ryuk-like pictures of the same
day (a full-length one for its pose and hair, a close-up for its face, chest and stapled neck): built the way such
models are, as a game mesh baked from a high-detail copy of itself (props.prop detail=True: every part's creases,
folds, muscles and wear raised in real geometry on the copy, "dg_detail" or its own twin "dg_high", and baked into the
maps). Its body on the main texture; its face (specter_head), its hair, its mane of quills and its gear (belt, chain,
holster, skirt, bracelets) each on a texture of their own (the Face, Hair, Collar and Gear pieces).

Blender space: x across (its right hand on -x), y depth (it faces -y), z up; 1 unit = 1 stud. It stands about nine
studs tall to the top of its hair, hunched forward, its head thrust out, its elbows bowed out wide and its clawed hands
hanging by its knees, the knees turned out and the feet hanging pointed (it floats)."""

import json
import math
import random

import bmesh
import bpy
from mathutils import Euler, Quaternion, Vector
from mathutils.bvhtree import BVHTree

import modelkit as mk
import propkit as pk
from common import srgb
from props import piece, prop
from props_world import skin_body

import specter_head as sh

# Detail asked of the high-detail copy, per surface (build_props._high_of).
SKIN = {"sub": 1, "disp": [("wrinkles", 0.016, 0.2), ("cells", 0.008, 0.055)]}
HIDE = {"sub": 1, "disp": [("clouds", 0.018, 0.32), ("cells", 0.007, 0.05)]}
FACE = {"sub": 1, "disp": [("wrinkles", 0.007, 0.055)]}
CLOTH = {"sub": 1, "disp": [("clouds", 0.03, 0.22), ("grain", 0.004, 0.02)]}
LEATHER = {"sub": 1, "disp": [("cells", 0.005, 0.035)]}
FUR = {"sub": 2, "disp": [("clouds", 0.045, 0.05)]}
FEATHER = {"sub": 1, "disp": [("rings", 0.006, 0.03), ("grain", 0.003, 0.015)]}
BONE = {"sub": 0, "disp": [("grain", 0.004, 0.02)]}


def detailed(obj, detail):
    obj["dg_detail"] = json.dumps(detail)  # (an ID property holds no lists of mixed values: kept as text)
    return obj


def chain_skin(name, mat, joints, bones, levels=2):
    """skin_body over joints given as (x, y, z, rx, ry) and bones as index pairs."""
    return skin_body(name, mat, joints, bones, levels=levels)


def shade_attribute(mat, shadow_rgb, name="dg_shade"):
    """Darkens `mat` toward `shadow_rgb` by the mesh's own float attribute `name` (0..1, per vertex: smooth across
    faces, and kept through the merge and the high-detail copy's subdivision), for painted shading such as the grey
    round a face's eyes."""
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    source = bsdf.inputs["Base Color"].links[0].from_socket
    attribute = nodes.new("ShaderNodeAttribute")
    attribute.attribute_name = name
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    links.new(attribute.outputs["Fac"], mix.inputs[0])
    links.new(source, mix.inputs[6])
    mix.inputs[7].default_value = (*shadow_rgb, 1.0)
    links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return mat


def sculpted(obj, fn):
    """obj with its modifiers applied, every point then moved out along its normal by fn(point, normal) (in to carve)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    old = obj.data
    obj.data = mesh
    bpy.data.meshes.remove(old)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)  # (a skin body's faces may come out facing in)
    bm.normal_update()
    moved = [(v, v.normal * fn(v.co, v.normal)) for v in bm.verts]
    for v, d in moved:
        v.co = v.co + d
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def anatomy(p, n):
    """The chest of the close-up (2026-10-25): gaunt but hard, the pectorals heavy with a hard edge under them, a
    groove down the breastbone, the belly in three pairs of knots split down the middle, the ribs in ridges down the
    flanks."""
    x, z = p.x, p.z
    front = max(0.0, -n.y)
    out = 0.0
    for sx in (-1, 1):
        dz = (z - 5.62) / (0.2 if z > 5.62 else 0.12)  # (falling hard under it)
        d = math.hypot((x - sx * 0.27) / 0.3, dz)
        out += 0.1 * max(0.0, 1 - d * d) ** 0.7 * front
        for k, cz in enumerate((5.18, 4.93, 4.68)):  # the belly's knots
            d = math.hypot((x - sx * 0.12) / 0.105, (z - cz) / 0.1)
            out += (0.05 - 0.008 * k) * max(0.0, 1 - d * d) ** 0.8 * front
    if 4.4 < z < 6.0:  # the breastbone's groove and the belly's line
        out -= 0.028 * max(0.0, 1 - abs(x) / 0.05) * front
    side = sh.smoothstep(0.22, 0.42, abs(x)) * (1 - sh.smoothstep(5.55, 5.75, z)) * sh.smoothstep(4.85, 5.05, z)
    if side > 0:  # the ribs, sloping down toward the front
        phase = (z - 0.3 * abs(x)) / 0.12
        out += 0.022 * max(0.0, math.cos(math.tau * phase)) ** 2 * side
    return out


def on_skin(tree, origin, way):
    """Where a ray from `origin` along `way` first meets the body (a BVH tree of it): (point, normal), or None."""
    hit, normal, _, _ = tree.ray_cast(Vector(origin), Vector(way).normalized(), 10.0)
    return (hit, normal.normalized()) if hit is not None else None


def staple(name, at, normal, across, mat, length=0.15, rise=0.045, sink=0.035, radius=0.017):
    """A surgical staple driven across a seam: its crown standing off the skin, its two legs bent down into it."""
    half = across.normalized() * (length / 2)
    a, b = at - half, at + half
    path = [a - normal * sink, a + normal * rise * 0.8, a + normal * rise + half * 0.12,
            b + normal * rise - half * 0.12, b + normal * rise * 0.8, b - normal * sink]
    return sh.soften(mk.smooth(pk.sweep(name, path, radius, mat, sides=6)))


class Skeleton:
    """Joints and the bones between them, for a skin body."""

    def __init__(self):
        self.joints, self.bones = [], []

    def joint(self, p, rx, ry=None):
        self.joints.append((p[0], p[1], p[2], rx, rx if ry is None else ry))
        return len(self.joints) - 1

    def chain(self, start, points):
        last = start
        for p, rx, *ry in points:
            k = self.joint(p, rx, ry[0] if ry else None)
            if last is not None:
                self.bones.append((last, k))
            last = k
        return last


@prop("Specter", pivot="bottom", material="Fabric", collide=False, texture=1024, ao=0.35, exact=True, detail=True)
def specter():
    rng = random.Random(25)
    # (black, asked 2026-10-25: "make his skin black instead of dark blue"; a little sheen on it, so its muscles and
    # bones still catch the light as the picture's blue highlights do)
    skin = mk.noisy("Spec_Skin_Leather", srgb(12, 13, 17), srgb(38, 41, 54), scale=9, detail=8, roughness=0.48)
    hide = mk.noisy("Spec_Hide_Leather", srgb(8, 9, 12), srgb(26, 28, 36), scale=8, detail=8, roughness=0.55)
    face = mk.noisy("Spec_Face", srgb(168, 176, 204), srgb(214, 218, 234), scale=12, detail=6, roughness=0.5,
                    kind="matte")
    shadow = mk.noisy("Spec_EyeShadow", srgb(40, 40, 50), srgb(86, 84, 96), scale=14, roughness=0.6, kind="matte")
    void = mk.flat("Spec_Void", (0.004, 0.003, 0.005), 0.9)
    gums = mk.noisy("Spec_Gums", srgb(40, 8, 14), srgb(80, 18, 26), scale=20, roughness=0.4, kind="plastic")
    lips = mk.noisy("Spec_Lips", srgb(26, 22, 40), srgb(52, 44, 74), scale=18, roughness=0.35, kind="plastic")
    tooth = mk.noisy("Spec_Tooth", srgb(196, 178, 120), srgb(240, 230, 196), scale=22, roughness=0.32, kind="plastic")
    claw = mk.noisy("Spec_Claw", srgb(12, 12, 16), srgb(52, 52, 60), scale=20, roughness=0.25, kind="plastic")
    hair = mk.noisy("Spec_Hair", srgb(8, 10, 30), srgb(22, 30, 78), scale=6, detail=10, roughness=0.42,
                    stretch=(1, 1, 5))
    fur = mk.noisy("Spec_Fur_Wool", srgb(186, 186, 192), srgb(236, 236, 238), scale=26, detail=12, roughness=0.95)
    plume = mk.noisy("Spec_Plume", srgb(6, 7, 10), srgb(26, 28, 38), scale=14, detail=10, roughness=0.68,
                     stretch=(1, 1, 7))
    quill = mk.noisy("Spec_Quill", srgb(20, 20, 26), srgb(60, 60, 70), scale=20, roughness=0.4, kind="plastic")
    cloth = mk.noisy("Spec_Skirt_Cloth", srgb(6, 6, 8), srgb(24, 22, 28), scale=7, detail=10, roughness=0.9)
    leather = mk.noisy("Spec_Belt_Leather", srgb(48, 18, 16), srgb(96, 40, 32), scale=12, roughness=0.55)
    strap = mk.noisy("Spec_Strap_Leather", srgb(20, 14, 12), srgb(48, 34, 28), scale=12, roughness=0.6)
    thread = mk.flat("Spec_Thread", srgb(170, 150, 110), 0.7, kind="cloth")
    steel = mk.noisy("Spec_Steel", srgb(110, 114, 122), srgb(196, 200, 208), scale=24, roughness=0.28, metallic=0.95,
                     kind="metal")
    bone = mk.noisy("Spec_Bone", srgb(178, 168, 140), srgb(232, 224, 200), scale=14, detail=8, roughness=0.5)
    book = mk.noisy("Spec_Book", srgb(10, 10, 12), srgb(30, 28, 30), scale=12, roughness=0.6, kind="leather")
    glow_eye = mk.emissive("Spec_Glow", srgb(255, 214, 40), 4)
    staple_mat = mk.noisy("Spec_Staple_Steel", srgb(176, 180, 188), srgb(230, 232, 236), scale=24, roughness=0.3,
                          metallic=0.9, kind="metal")
    glow_iris = mk.emissive("Spec_IrisGlow", srgb(225, 30, 20), 6)
    glow_ring = mk.emissive("Spec_RingGlow", srgb(170, 255, 220), 6)
    parts, collar_parts, gear, glows = [], [], [], []
    sh.paint(face, "dg_shade", srgb(34, 36, 60), 1.0)
    sh.paint(face, "dg_lip", srgb(44, 38, 66), 1.0)
    sh.paint(hair, "dg_tip", srgb(40, 58, 130), 0.6)
    sh.paint(fur, "dg_tip", srgb(250, 249, 246), 0.9)
    sh.paint(plume, "dg_tip", srgb(40, 46, 70), 0.6)

    # ---------------------------------------------------------------------------------------------------------
    # The body. The torso a hide of black over a gaunt frame (a waist like a wasp's, the ribs' cage swelling over
    # it), the limbs grown out of it in the same black: long arms bulging at the elbow and the wrist's knuckle, hands
    # of four long knuckled fingers and a thumb, legs bent a little at bony knees, feet drawn out to points.
    # (posed as in the full-length picture of 2026-10-25: hunched forward over its chest, the neck thrust out, the
    # shoulders hiked up)
    torso = Skeleton()
    pelvis = torso.joint((0, 0.12, 3.9), 0.5, 0.36)
    spine = [((0, 0.16, 4.42), 0.3, 0.24), ((0, 0.08, 4.88), 0.44, 0.33), ((0, -0.06, 5.34), 0.56, 0.38),
             ((0, -0.24, 5.8), 0.62, 0.4), ((0, -0.5, 6.22), 0.3, 0.26), ((0, -0.72, 6.48), 0.18, 0.18),
             ((0, -0.9, 6.7), 0.16, 0.16)]
    torso.chain(pelvis, spine)

    def axis_y(z):
        """The spine's line (its y) at height z: leaning forward up the chest and the neck."""
        line = [(3.9, 0.12)] + [(p[2], p[1]) for p, _, _ in spine]
        for (z0, y0), (z1, y1) in zip(line, line[1:]):
            if z <= z1:
                return y0 + (y1 - y0) * max(0.0, (z - z0) / (z1 - z0))
        return line[-1][1]

    for side in (-1, 1):  # (the shoulders' round inside the hide: the limbs grow out of them)
        torso.chain(4, [((side * 0.64, -0.2, 5.94), 0.3, 0.26)])
        torso.chain(0, [((side * 0.34, 0.12, 3.72), 0.3, 0.3)])
    # (the game mesh grown at two levels of smoothing for the muscles to be carved into; the high-detail copy takes it
    # further)
    # (its muscles carved for real into a fine high-detail twin and baked into the normal map: the game mesh is too
    # coarse to hold them, and only carries their broad shape)
    chest = sculpted(chain_skin("Torso", skin, torso.joints, torso.bones, levels=3), anatomy)
    chest["dg_high"] = sculpted(chain_skin("TorsoHigh", skin, torso.joints, torso.bones, levels=5), anatomy).name
    parts.append(chest)
    # the shoulders rounded over the arms' tops (deltoids), so no limb ends in a box
    for side in (-1, 1):
        deltoid = mk.sphere("Deltoid", 1.0, (side * 0.82, -0.2, 5.98), scale=(0.27, 0.25, 0.3), mat=skin, segments=20,
                            rings=14)
        parts.append(detailed(deltoid, SKIN))
    # the collarbones and the spine's knuckles standing under the skin (half sunk in it)
    for side in (-1, 1):
        parts.append(detailed(mk.tube("Collarbone", (side * 0.06, -0.54, 6.0), (side * 0.62, -0.36, 6.06), 0.05, 0.06,
                                      mat=skin, verts=10), SKIN))
    for k in range(8):
        z = 4.4 + k * 0.24
        y = axis_y(z) + 0.24 + 0.14 * min(1.0, (z - 4.4) / 1.0) + 0.02 * math.sin(k)  # (on the bowed back)
        parts.append(detailed(mk.sphere("SpineKnuckle", 0.075, (0, y + (0.04 if 4.8 < z < 5.9 else 0.0), z),
                                        scale=(1.0, 0.7, 0.8), mat=skin, segments=8, rings=6), SKIN))
    # The neck stapled to the body (the close-up of 2026-10-25, asked: "like a part of skin was stapled to the other
    # with a stapler"): the head's pale skin comes down the neck and overlaps the body's in a flap, its edge lifted off
    # it, held by a ring of staples across the edge; a second seam stapled across the upper chest, shoulder to
    # shoulder. Each staple is set where a ray meets the sculpted body.
    bmt = bmesh.new()
    bmt.from_mesh(chest.data)
    bmesh.ops.recalc_face_normals(bmt, faces=bmt.faces)
    tree = BVHTree.FromBMesh(bmt)
    bmt.free()
    count = 48
    heights = ((0.0, 0.034), (0.06, 0.014), (0.15, 0.007), (0.26, 0.006), (0.4, 0.006))  # (up the neck: lift off it)
    rings = []
    for i in range(count):
        th = math.tau * i / count
        d = Vector((math.cos(th), math.sin(th), 0.0))
        z = 6.1 + 0.07 * d.y  # (lower in front)
        column = [on_skin(tree, Vector((0, axis_y(z + h), z + h)) + d * 2.0, -d) for h, _ in heights]
        if all(column):
            rings.append([(c[0] + c[1] * lift, c[1]) for c, (_, lift) in zip(column, heights)])
    ring_lo = [column[0] for column in rings]
    bmf = bmesh.new()
    grid = [[bmf.verts.new(p) for p, _ in column] for column in rings]
    for i in range(len(grid)):
        j = (i + 1) % len(grid)
        for r in range(len(heights) - 1):
            bmf.faces.new((grid[i][r], grid[j][r], grid[j][r + 1], grid[i][r + 1]))
    bmesh.ops.recalc_face_normals(bmf, faces=bmf.faces)
    flap = mk._obj_from_bm("NeckFlap", bmf, face)
    thick = flap.modifiers.new("Solidify", "SOLIDIFY")
    thick.thickness = 0.018
    parts.append(detailed(mk.smooth(flap), FACE))
    for i in range(0, len(ring_lo), 4):  # (a dozen chunky staples round the flap's edge, each driven a little askew)
        (p, n), (q, _) = ring_lo[i], ring_lo[(i + 1) % len(ring_lo)]
        up = n.cross(q - p).normalized()
        up.rotate(Quaternion(n, rng.uniform(-0.3, 0.3)))
        parts.append(staple("Staple", p - n * 0.012, n, up, staple_mat, length=rng.uniform(0.13, 0.17), radius=0.024))
    seam = []
    for k in range(17):
        x = -0.66 + k * 1.32 / 16
        z = 5.98 - 0.16 * (1 - (x / 0.66) ** 2)
        hit = on_skin(tree, (x, -2.0, z), (0, 1, 0))
        if hit:
            seam.append((hit[0] + hit[1] * 0.004, hit[1]))
    parts.append(sh.soften(mk.smooth(pk.sweep("Seam", [p for p, _ in seam], 0.014, lips, sides=6))))
    for k in range(1, len(seam) - 1, 2):
        (p, n), (q, _) = seam[k], seam[k + 1]
        across = n.cross(q - p).normalized()
        across.rotate(Quaternion(n, rng.uniform(-0.3, 0.3)))
        parts.append(staple("Staple", p, n, across, staple_mat, length=rng.uniform(0.12, 0.15), radius=0.022))

    limbs = Skeleton()
    hands = {}
    for side in (-1, 1):
        x = side
        # the arms (the picture's pose): the elbows bowed out wide and back, the forearms coming in again, the hands
        # hanging by the knees
        s, e, w = Vector((x * 0.84, -0.2, 6.02)), Vector((x * 1.5, 0.08, 4.85)), Vector((x * 1.38, -0.5, 3.72))
        shoulder = limbs.joint(tuple(s), 0.24, 0.22)
        wrist = limbs.chain(shoulder, [(tuple(s.lerp(e, 0.4)), 0.19, 0.18), (tuple(s.lerp(e, 0.85)), 0.13, 0.13),
                                       (tuple(e), 0.17, 0.16), (tuple(e.lerp(w, 0.12)), 0.12, 0.12),
                                       (tuple(e.lerp(w, 0.55)), 0.12, 0.11), (tuple(e.lerp(w, 0.93)), 0.08, 0.08),
                                       (tuple(w), 0.1, 0.09)])
        # the hand (asked 2026-10-25, "make the fingers connect properly"): a broad flat palm, a bar of knuckles across
        # its lower edge, and each finger grown out of its own knuckle, so the four run on out of the hand instead of
        # branching as sticks from one point under a knob (the knuckles joined one to the next, no loop for the skin)
        palm_c = w + Vector((x * 0.03, -0.1, -0.2))
        palm = limbs.chain(wrist, [(tuple(palm_c), 0.16, 0.08)])
        knuckles = [palm_c + Vector((x * (f - 1.5) * 0.095, -0.05, -0.16 - 0.015 * abs(f - 1.5))) for f in range(4)]
        joints = [None] * 4
        joints[1] = limbs.chain(palm, [(tuple(knuckles[1]), 0.068, 0.062)])
        joints[0] = limbs.chain(joints[1], [(tuple(knuckles[0]), 0.064, 0.058)])
        joints[2] = limbs.chain(joints[1], [(tuple(knuckles[2]), 0.068, 0.062)])
        joints[3] = limbs.chain(joints[2], [(tuple(knuckles[3]), 0.06, 0.055)])
        tips = []
        for f in range(4):
            spread = (f - 1.5) * 0.085
            k0 = knuckles[f]
            k1 = k0 + Vector((x * spread * 0.5, -0.12, -0.24))
            k2 = k1 + Vector((x * spread * 0.3, -0.06, -0.24))
            k3 = k2 + Vector((x * spread * 0.2, 0.04, -0.16))
            limbs.chain(joints[f], [(tuple(k0 + (k1 - k0) * 0.5), 0.046), (tuple(k1), 0.047),
                                    (tuple(k1 + (k2 - k1) * 0.5), 0.036), (tuple(k2), 0.039), (tuple(k3), 0.03)])
            tips.append((k2, k3, f))
        thumb0 = palm_c + Vector((x * -0.13, -0.04, 0.02))
        thumb1 = thumb0 + Vector((x * -0.08, -0.14, -0.12))
        thumb2 = thumb1 + Vector((x * -0.02, -0.1, -0.12))
        limbs.chain(palm, [(tuple(thumb0), 0.05), (tuple(thumb1), 0.042), (tuple(thumb2), 0.032)])
        tips.append((thumb1, thumb2, 9))
        hands[side] = (palm_c, tips, w + Vector((0, 0.02, 0.06)))
        # the legs: the knees bent and turned out, the shins drawn back in, the feet hanging pointed (it floats)
        hip = limbs.joint((x * 0.36, 0.12, 3.74), 0.27)
        limbs.chain(hip, [((x * 0.5, 0.02, 3.0), 0.21, 0.2), ((x * 0.62, -0.18, 2.32), 0.15),
                          ((x * 0.66, -0.26, 2.12), 0.19), ((x * 0.64, -0.22, 1.92), 0.13),
                          ((x * 0.54, 0.0, 1.2), 0.12, 0.13), ((x * 0.45, 0.12, 0.56), 0.09),
                          ((x * 0.44, 0.14, 0.36), 0.1, 0.12), ((x * 0.42, 0.0, 0.14), 0.09, 0.07),
                          ((x * 0.39, -0.22, 0.02), 0.05, 0.04)])
    parts.append(detailed(chain_skin("Limbs", skin, limbs.joints, limbs.bones, levels=1), dict(SKIN, sub=2)))
    # Claws: hooked, glossy black, out of every fingertip; a ring with a glowing stone on one finger of each hand.
    for side, (palm_c, tips, wrist) in hands.items():
        for k2, k3, f in tips:
            way = (k3 - k2).normalized()
            hook = k3 + way * 0.12 + Vector((0, 0.04, -0.03))
            end = hook + way * 0.08 + Vector((0, 0.07, -0.02))
            parts.append(detailed(mk.tube("Claw", k3 - way * 0.01, hook, 0.03, 0.017, mat=claw, verts=8), BONE))
            parts.append(detailed(mk.tube("ClawTip", hook, end, 0.017, 0.002, mat=claw, verts=8), BONE))
            if f == 2:
                at = k2 + (k3 - k2) * -0.6
                parts.append(mk.torus("Ring", 0.045, 0.014, tuple(at), rot=(25, 0, 0), mat=steel, major_segments=14,
                                      minor_segments=6))
                parts.append(mk.cylinder("RingSet", 0.03, 0.03, tuple(at + Vector((0, -0.05, 0.0))), rot=(90, 0, 0),
                                         mat=steel, verts=10))
                glows.append(mk.sphere("Stone", 0.026, tuple(at + Vector((0, -0.068, 0))), mat=glow_ring, segments=10,
                                       rings=8))

    # ---------------------------------------------------------------------------------------------------------
    # The head (specter_head: sculpted in code to the reference) and its hair, each on a texture of its own (the Face
    # and Hair pieces): the face's own sculpt and the hair's grooved strands are their high-detail twins ("dg_high").
    head_c = Vector((0, -1.04, 6.98))  # (thrust forward on the hunched neck)
    R = 0.62
    hmats = {"face": face, "void": void, "gums": gums, "lips": lips, "tooth": tooth, "steel": steel, "hair": hair}
    low_shell = sh.shell("Head", hmats, fine=False)
    high_shell = sh.shell("HeadHigh", hmats, fine=True)
    low_shell["dg_high"] = high_shell.name
    face_parts = [low_shell]
    more_face, eye_glows = sh.features(hmats, glow_eye, rng=random.Random(31), iris=glow_iris)
    face_parts += more_face
    glows += eye_glows
    hair_parts = sh.hair(hmats, rng=random.Random(57))

    def place(objs):
        """From the unit head to its place on the body (their high-detail twins too)."""
        for obj in objs:
            twin = bpy.data.objects.get(obj.get("dg_high") or "")
            for o in [obj] + ([twin] if twin else []):
                o.location = head_c + Vector(o.location) * R
                o.scale = Vector(o.scale) * R

    place(face_parts + eye_glows + hair_parts)

    # ---------------------------------------------------------------------------------------------------------
    # The collar (its own texture: the Collar piece): a great ragged mane of long black quills off the shoulders and
    # the back, each grooved along its length (their high-detail twins); the neck below the head is stapled to the body
    # (above, with the torso), no fur.

    def quill(root, tip, width, droop):
        """A long ragged black quill from root to tip, drooping at its end, flat as a blade."""
        axis = tip - root
        path = [root + axis * (s / 7) + Vector((0, 0, -droop * (s / 7) ** 2)) for s in range(8)]
        up = axis.cross(Vector((0, 0, 1)))
        up = up.cross(axis).normalized() if up.length > 1e-3 else Vector((0, 0, 1))
        low = sh.strands("Quill", path, width, 0.28, plume, 6, tip_attr="dg_tip", up=up)
        twin = sh.strands("QuillHigh", path, width, 0.28, plume, 24, grooves=8, groove=0.15, tip_attr="dg_tip", up=up)
        low["dg_high"] = twin.name
        collar_parts.append(low)

    for layer, (count, reach, width, lift) in enumerate(((30, (1.5, 2.2), (0.12, 0.17), 0.0),
                                                         (26, (1.0, 1.5), (0.11, 0.15), 0.14),
                                                         (20, (0.6, 1.0), (0.1, 0.13), 0.26))):
        for k in range(count):
            a = math.radians(-160 + k * (320 / (count - 1))) + rng.uniform(-0.06, 0.06)  # round the back, open in front
            sideways = math.sin(a)
            back = math.cos(a)
            root = Vector((sideways * 0.6, -0.12 + back * 0.36, 6.3 + lift + rng.uniform(-0.04, 0.04)))
            # (thrown up behind the head, out and drooping over the shoulders: a mane, not a fan)
            up = 0.2 + 1.3 * max(0.0, back) ** 1.5 + rng.uniform(-0.25, 0.25)
            out = Vector((sideways * 1.3 + rng.uniform(-0.2, 0.2), back * 0.8 + 0.35, up)).normalized()
            length = rng.uniform(*reach) * (0.8 + 0.3 * abs(sideways))
            tip = root + out * length
            quill(root, tip, rng.uniform(*width), (0.25 + 0.45 * abs(sideways)) * length * 0.45)
    for k in range(16):  # short ones hanging over the shoulders and the upper arms
        a = math.radians(-130 + k * (260 / 15))
        root = Vector((math.sin(a) * 0.58, -0.16 + math.cos(a) * 0.34, 6.12))
        tip = root + Vector((math.sin(a) * 0.8, math.cos(a) * 0.45 + 0.2, -0.85))
        quill(root, tip, 0.1, 0.1)


    # ---------------------------------------------------------------------------------------------------------
    # The belt: a broad band of oxblood leather slung low round the hips, stitched along both edges, a carved skull
    # for its buckle, studs round it; a chain looped round under it with small skulls hanging from it; on the right
    # hip a strapped holster with the Manual in it.
    hips_c = Vector((0, 0.1, 4.06))
    rx, ry = 0.56, 0.44

    def round_hips(a, z, out=0.0):
        return Vector((math.sin(a) * (rx + out), hips_c.y + math.cos(a) * (ry + out), z - 0.06 * math.cos(a)))

    bmb = bmesh.new()
    ring_lo, ring_hi, ring_lo2, ring_hi2 = [], [], [], []
    seg = 48
    for i in range(seg):
        a = math.tau * i / seg
        ring_lo.append(bmb.verts.new(round_hips(a, hips_c.z - 0.09, 0.02)))
        ring_hi.append(bmb.verts.new(round_hips(a, hips_c.z + 0.09, 0.02)))
        ring_lo2.append(bmb.verts.new(round_hips(a, hips_c.z - 0.09, -0.03)))
        ring_hi2.append(bmb.verts.new(round_hips(a, hips_c.z + 0.09, -0.03)))
    for i in range(seg):
        j = (i + 1) % seg
        bmb.faces.new((ring_lo[i], ring_lo[j], ring_hi[j], ring_hi[i]))
        bmb.faces.new((ring_hi[i], ring_hi[j], ring_hi2[j], ring_hi2[i]))
        bmb.faces.new((ring_lo2[i], ring_lo2[j], ring_lo[j], ring_lo[i]))
        bmb.faces.new((ring_hi2[i], ring_hi2[j], ring_lo2[j], ring_lo2[i]))
    bmesh.ops.recalc_face_normals(bmb, faces=bmb.faces)
    gear.append(detailed(mk._obj_from_bm("Belt", bmb, leather), LEATHER))
    for i in range(seg):  # the stitching, along both edges
        if i % 2:
            continue
        a0, a1 = math.tau * i / seg, math.tau * (i + 0.8) / seg
        for z in (hips_c.z - 0.065, hips_c.z + 0.065):
            gear.append(mk.tube("Stitch", round_hips(a0, z, 0.025), round_hips(a1, z, 0.025), 0.007, 0.007, mat=thread,
                                 verts=4))
    for k in range(16):
        a = math.tau * (k + 0.5) / 16
        if abs(math.sin(a)) < 0.25 and math.cos(a) < 0:
            continue  # (clear of the buckle)
        gear.append(mk.sphere("Stud", 0.028, tuple(round_hips(a, hips_c.z, 0.03)), mat=steel, segments=6, rings=4))
    buckle_at = round_hips(math.pi, hips_c.z, 0.1)
    for obj in pk.skull("Buckle", tuple(buckle_at), 0.17, bone, void, yaw=0.0, segments=28, teeth=5):
        gear.append(detailed(obj, BONE))
    # the chain: round under the belt from the buckle to the right hip, sagging, and hanging down there
    def chain(points, link=0.055):
        """Oval links along the points, each turned a quarter about the chain from the one before."""
        n = 0
        for k in range(len(points) - 1):
            a, b = points[k], points[k + 1]
            count = max(1, int((b - a).length / (link * 2.2)))
            d = (b - a).normalized()
            q = d.to_track_quat("Y", "Z")
            for i in range(count):
                p = a + (b - a) * ((i + 0.5) / count)
                obj = mk.torus("Link", link, link * 0.26, tuple(p), mat=steel, major_segments=10, minor_segments=5)
                obj.rotation_mode = "QUATERNION"
                obj.rotation_quaternion = q @ Quaternion((0, 1, 0), math.radians(90 * (n % 2)))
                obj.scale = (0.75, 1.25, 1.0)
                gear.append(obj)
                n += 1

    sag = []
    for i in range(13):
        a = math.pi + (-math.pi * 0.62) * (i / 12)  # from the front round to the wearer's right hip (-x)
        z = hips_c.z - 0.22 - 0.16 * math.sin(i / 12 * math.pi)
        sag.append(round_hips(a, z, 0.06))
    chain(sag)
    hang = [sag[-1], sag[-1] + Vector((-0.04, -0.02, -0.38)), sag[-1] + Vector((-0.02, -0.06, -0.7))]
    chain(hang)
    for at, r in ((hang[-1] + Vector((0, -0.02, -0.09)), 0.075), (sag[4] + Vector((0, -0.03, -0.1)), 0.06),
                  (sag[8] + Vector((0, -0.03, -0.1)), 0.06)):
        for obj in pk.skull("Charm", tuple(at), r, bone, void, segments=14, teeth=0):
            gear.append(obj)
    # the holster on the right hip (-x) with the Manual in it, strapped to the belt
    hol = round_hips(-math.pi / 2 + 0.25, hips_c.z - 0.34, 0.09)
    turn = (0, 0, -78)
    gear.append(detailed(pk.rounded("Holster", (0.18, 0.46, 0.58), tuple(hol), strap, r=0.04, rot=turn), LEATHER))
    gear.append(detailed(pk.rounded("HolsterFlap", (0.2, 0.48, 0.18), tuple(hol + Vector((0, 0, 0.26))), strap, r=0.04,
                                     rot=turn), LEATHER))
    gear.append(pk.rounded("Manual", (0.12, 0.4, 0.5), tuple(hol + Vector((0.02, 0, 0.08))), book, r=0.02, rot=turn))
    for dz in (0.2, -0.12):
        gear.append(mk.box("HolsterStrap", (0.21, 0.08, 0.04), tuple(hol + Vector((0, 0, dz))), rot=turn, mat=leather))
    glows.append(mk.sphere("Stone", 0.03, tuple(hol + Vector((-0.06, -0.12, 0.26))), mat=glow_ring, segments=10,
                           rings=8))

    # ---------------------------------------------------------------------------------------------------------
    # The skirt: short, black and torn into long points at its hem, in two layers, pleated and creased.
    def skirt(name, top_z, hem_z, top_r, hem_r, seed, points=13):
        srng = random.Random(seed)
        bms = bmesh.new()
        seg_n = points * 4
        rows = 5
        grid = []
        drop = [0.0] * seg_n
        for i in range(seg_n):
            phase = (i % 4) / 4.0  # (a point every four columns: up at its sides, down at its tip)
            drop[i] = (1.0 - abs(phase * 2 - 1)) * srng.uniform(0.22, 0.55)
        for r in range(rows + 1):
            t = r / rows
            z = top_z + (hem_z - top_z) * t
            rr = top_r + (hem_r - top_r) * t
            row = []
            for i in range(seg_n):
                a = math.tau * i / seg_n
                pleat = 0.035 * math.sin(a * points) * t
                zz = z - drop[i] * (t ** 2)
                row.append(bms.verts.new((math.sin(a) * (rr * 1.05 + pleat), hips_c.y + math.cos(a) * (rr * 0.92 + pleat),
                                          zz)))
            grid.append(row)
        for r in range(rows):
            for i in range(seg_n):
                j = (i + 1) % seg_n
                bms.faces.new((grid[r][i], grid[r][j], grid[r + 1][j], grid[r + 1][i]))
        obj = mk._obj_from_bm(name, bms, cloth)
        solid = obj.modifiers.new("Solidify", "SOLIDIFY")
        solid.thickness = 0.02
        return detailed(obj, CLOTH)

    gear.append(skirt("Skirt", hips_c.z + 0.04, 3.1, 0.54, 0.8, 11))
    gear.append(skirt("SkirtOver", hips_c.z, 3.38, 0.58, 0.82, 12, points=9))

    # ---------------------------------------------------------------------------------------------------------
    # The shoes (asked 2026-10-25, "where are his shoes"; the full-length picture's pointed black ones): glossy black
    # leather over each hanging foot from a rolled collar at the ankle, drawn out past the toes to a long point that
    # turns up a little; a seam down the vamp, a strap over the instep with a small steel buckle.
    shoe = mk.noisy("Spec_Shoe_Leather", srgb(8, 8, 10), srgb(30, 30, 36), scale=10, roughness=0.36)
    sole = mk.noisy("Spec_Sole_Leather", srgb(26, 22, 20), srgb(46, 40, 36), scale=14, roughness=0.6)
    welt = mk.flat("Spec_Welt", srgb(44, 44, 50), 0.6, kind="cloth")
    for side in (-1, 1):
        x = side
        line = [Vector((x * 0.44, 0.15, 0.46)), Vector((x * 0.435, 0.11, 0.3)), Vector((x * 0.42, 0.03, 0.15)),
                Vector((x * 0.405, -0.1, 0.06)), Vector((x * 0.39, -0.27, 0.01)), Vector((x * 0.38, -0.42, 0.02)),
                Vector((x * 0.37, -0.56, 0.05)), Vector((x * 0.36, -0.67, 0.11))]
        widths = [0.15, 0.15, 0.135, 0.12, 0.09, 0.062, 0.032, 0.0]
        depths = [0.15, 0.15, 0.13, 0.1, 0.07, 0.048, 0.026, 0.0]
        across = [Vector((1, 0, 0))] * len(line)
        ups = []
        for k, c in enumerate(line):
            d = (line[min(k + 1, len(line) - 1)] - line[max(k - 1, 0)]).normalized()
            ups.append(d.cross(Vector((1, 0, 0))).normalized())  # (the side over the instep: up)
        gear.append(detailed(sh.loft("Shoe", line, across, ups, widths, depths, shoe, sides=16), LEATHER))
        # the sole, a darker strip under the foot from the heel to the point
        under = [c - u * (dep * 0.9) for c, u, dep in zip(line[2:6], ups[2:6], depths[2:6])]
        gear.append(pk.sweep("Sole", under, [0.05, 0.045, 0.032, 0.012], sole, sides=6))
        gear.append(mk.torus("Collar", 0.15, 0.028, tuple(line[0]), rot=(-14, 0, 0), mat=shoe, major_segments=20,
                             minor_segments=6))
        top = [c + u * (dep * 0.98) for c, u, dep in zip(line[1:7], ups[1:7], depths[1:7])]
        gear.append(sh.soften(mk.smooth(pk.sweep("Seam", top, 0.008, welt, sides=4))))
        strap_c = line[2].lerp(line[3], 0.4)
        gear.append(mk.torus("Strap", 0.135, 0.02, tuple(strap_c), rot=(70, 0, 0), mat=strap, major_segments=20,
                             minor_segments=5))
        gear.append(pk.rounded("Buckle", (0.06, 0.03, 0.05), tuple(strap_c + Vector((x * 0.13, -0.02, 0.02))), steel,
                               r=0.01))

    # ---------------------------------------------------------------------------------------------------------
    # The wrists: a bracelet of small carved skulls on a cord round the right one (-x), a pair of steel bands on the
    # left.
    _, _, rwrist = hands[-1]
    gear.append(mk.torus("Cord", 0.15, 0.018, tuple(rwrist), rot=(62, 0, 18), mat=strap, major_segments=20,
                          minor_segments=6))
    for k in range(7):
        a = math.tau * k / 7
        local = Vector((math.cos(a) * 0.16, math.sin(a) * 0.16, 0))
        local.rotate(Euler((math.radians(62), 0, math.radians(18))))
        at = rwrist + local
        for obj in pk.skull("Bead", tuple(at), 0.05, bone, void, yaw=math.degrees(a) + 90, segments=10, teeth=0):
            gear.append(obj)
    _, _, lwrist = hands[1]
    for dz in (0.04, -0.05):
        gear.append(mk.torus("Band", 0.14, 0.022, tuple(lwrist + Vector((0, 0, dz))), rot=(62, 0, -18), mat=steel,
                              major_segments=20, minor_segments=8))

    # (the eyes' red first: it is the prop's main glow, Specter_Glow; the stones' pale light the second)
    glows.sort(key=lambda o: 0 if o.name.startswith("Eye") else (1 if o.name.startswith("Iris") else 2))
    return parts, glows, {
        "pieces": {
            "Face": piece(face_parts, own=True, exact=1024),
            "Hair": piece(hair_parts, own=True, exact=1024, plain=True),
            "Collar": piece(collar_parts, own=True, exact=1024),
            "Gear": piece(gear, own=True, exact=1024),
        },
    }
