"""The R6 reference rig, taken from Aeresei's "R6 IK + FK Blender Rig" V2.22 (Roblox DevForum,
art/rig/BlenderR6Rig_V2.22.blend, credited in art/README.md).

That file holds a control rig (IK/FK, `__PrimaryArmature`) that drives an `InternalArmature`:
the six real R6 joints, each bone's head on a Motor6D pivot. The game plays joint rotations,
so everything here works on the InternalArmature. build_rig() opens the file, keeps that
armature (renamed "R6") and the blocky body, cuts the constraints that tied it to the control
rig, and dresses the body in the noir mannequin colours. Keyed actions go straight on its bones.
A clip someone animates by hand on the control rig exports just the same, because the exporter
reads the InternalArmature's evaluated pose.

Bone names are Roblox's part names. JOINTS maps the short joint names used by the game
(src/shared/Anim/Joints.luau) to the bone that joint moves. Roblox's six joints:
    root  (RootJoint,      HumanoidRootPart -> Torso)   moves the whole body, and bends the waist
    neck  (Neck,           Torso -> Head)
    rShoulder / lShoulder  (Torso -> Right Arm / Left Arm)
    rHip / lHip            (Torso -> Right Leg / Left Leg)
"""

import json
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

import common
from common import rbx_to_blender, srgb

RIG_FILE = os.path.join(common.ART, "rig", "BlenderR6Rig_V2.22.blend")

_R6 = json.load(open(os.path.join(common.ART, "data", "r6_rig.json")))

JOINTS = {
    "root": "Torso",
    "neck": "Head",
    "rShoulder": "Right Arm",
    "lShoulder": "Left Arm",
    "rHip": "Right Leg",
    "lHip": "Left Leg",
}
MOTORS = {
    "root": "RootJoint",
    "neck": "Neck",
    "rShoulder": "Right Shoulder",
    "lShoulder": "Left Shoulder",
    "rHip": "Right Hip",
    "lHip": "Left Hip",
}
# bone -> the bone it hangs from
PARENT = {
    "Torso": "HumanoidRootPart",
    "Head": "Torso",
    "Right Arm": "Torso",
    "Left Arm": "Torso",
    "Right Leg": "Torso",
    "Left Leg": "Torso",
}

# part -> (centre, size) in Roblox space, standing with the HumanoidRootPart at (0, 3, 0)
PARTS = {name: (tuple(info["cframe"]["p"]), tuple(info["size"])) for name, info in _R6["parts"].items()}


def _pivot(motor_name):
    motor = next(m for m in _R6["motors"] if m["name"] == motor_name)
    base = Vector(_R6["parts"][motor["part0"]]["cframe"]["p"])
    return base + Vector(motor["c0"]["p"])


# Roblox-space joint pivots at rest
PIVOTS = {joint: _pivot(motor) for joint, motor in MOTORS.items()}
ROOT_PIVOT = tuple(PIVOTS["root"])

# Leg geometry (studs): the leg is one rigid 2-stud part swinging from the hip pivot, whose
# x is the torso's edge, half a stud outside the leg's own middle.
LEG = {"hip": PIVOTS["rHip"].y, "length": PARTS["Right Leg"][1][1], "hip_x": PIVOTS["rHip"].x}
ARM = {"length": PARTS["Right Arm"][1][1], "shoulder_y": PIVOTS["rShoulder"].y, "shoulder_x": PIVOTS["rShoulder"].x}

SUIT = srgb(34, 34, 40)
TROUSERS = srgb(26, 26, 30)
SHOES = srgb(12, 12, 13)
SKIN = srgb(232, 196, 160)
SHIRT = srgb(236, 233, 226)
TIE = srgb(190, 22, 36)

_BODY = {  # part -> the mesh object in the downloaded file
    "Torso": "Torso_MBlocky",
    "Head": "Head_MBlocky",
    "Right Arm": "Right Arm_MBlocky",
    "Left Arm": "Left Arm_MBlocky",
    "Right Leg": "Right Leg_MBlocky",
    "Left Leg": "Left Leg_MBlocky",
}


def part_material(part):
    if part == "Head":
        return common.material("Skin", SKIN, 0.55)
    if "Leg" in part:
        return common.material("Trousers", TROUSERS, 0.8)
    return common.material("Suit", SUIT, 0.75)


def box(name, center, size, mat, bevel=0.06):
    """A bevelled box; centre and size in Blender space."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = center
    mesh.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def parent_to_bone(obj, arm, bone_name):
    """Parents obj to one bone of arm, keeping it where it is."""
    bone = arm.data.bones[bone_name]
    world = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_parent_inverse = (
        arm.matrix_world @ bone.matrix_local @ Matrix.Translation((0, bone.length, 0))
    ).inverted()
    obj.matrix_world = world


def reset_pose(arm):
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)


def build_rig():
    """Opens the downloaded rig and returns the R6 armature, ready to be keyed."""
    if not os.path.exists(RIG_FILE):
        raise SystemExit(f"The rig is missing: {RIG_FILE} (see art/README.md)")
    bpy.ops.wm.open_mainfile(filepath=RIG_FILE)
    arm = bpy.data.objects["InternalArmature"]
    keep = {arm.name} | set(_BODY.values())
    for obj in list(bpy.data.objects):
        if obj.name not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for text in list(bpy.data.texts):
        bpy.data.texts.remove(text)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)
    arm.name = "R6"
    arm.data.name = "R6"
    # The file's own drivers (body type, visibility) need its Python scripts and the control rig.
    for obj in list(bpy.data.objects):
        obj.animation_data_clear()
        if obj.data is not None and getattr(obj.data, "animation_data", None):
            obj.data.animation_data_clear()
    for pb in arm.pose.bones:
        for con in list(pb.constraints):
            pb.constraints.remove(con)
    arm.hide_viewport = arm.hide_render = False
    arm.hide_set(False)
    # The file switches rotation inheritance off (its control rig drives each bone separately). Roblox's
    # Motor6Ds chain: a limb turns with the torso it hangs from, and the clips are keyed that way.
    for bone in arm.data.bones:
        bone.use_inherit_rotation = True
    reset_pose(arm)

    scene = bpy.context.scene
    for coll in list(scene.collection.children):
        scene.collection.children.unlink(coll)
    rig_coll = common.collection("Rig")
    mannequin = common.collection("Mannequin")
    for coll_obj in list(scene.collection.objects):
        scene.collection.objects.unlink(coll_obj)
    rig_coll.objects.link(arm)
    bpy.context.view_layer.update()

    for part, mesh_name in _BODY.items():
        obj = bpy.data.objects[mesh_name]
        obj.name = part + "_Mesh"
        obj.hide_viewport = obj.hide_render = False
        mannequin.objects.link(obj)
        obj.hide_set(False)
        obj.data.materials.clear()
        obj.data.materials.append(part_material(part))
        bpy.context.view_layer.update()
        # The file follows a bone with a Child Of constraint; the bone parent below does the same.
        world = obj.matrix_world.copy()
        for con in list(obj.constraints):
            obj.constraints.remove(con)
        obj.matrix_world = world
        bpy.context.view_layer.update()
        parent_to_bone(obj, arm, part)

    # Details that show which way the mannequin faces: shirt front, tie and eyes (Roblox +x right,
    # forward is -z; boxes are given in Roblox space and sized (x, y, z)).
    details = [
        ("ShirtFront", "Torso", (0, 3.42, -0.51), (0.55, 0.7, 0.04), common.material("Shirt", SHIRT, 0.5)),
        ("Tie", "Torso", (0, 3.2, -0.54), (0.2, 0.9, 0.04), common.material("Tie", TIE, 0.45)),
        ("EyeL", "Head", (-0.22, 4.55, -0.52), (0.14, 0.2, 0.04), common.material("Ink", (0.01, 0.01, 0.01), 0.3)),
        ("EyeR", "Head", (0.22, 4.55, -0.52), (0.14, 0.2, 0.04), common.material("Ink", (0.01, 0.01, 0.01), 0.3)),
    ]
    for name, bone_name, center, size, mat in details:
        obj = box(name, rbx_to_blender(center), (size[0], size[2], size[1]), mat, bevel=0.01)
        mannequin.objects.link(obj)
        bpy.context.view_layer.update()
        parent_to_bone(obj, arm, bone_name)

    floor = box("Floor", (0, 0, -0.05), (30, 30, 0.1), common.material("Floor", srgb(40, 40, 46), 0.9), bevel=0)
    common.collection("Stage").objects.link(floor)
    bpy.context.view_layer.objects.active = arm
    return arm


if __name__ == "__main__":
    build_rig()
