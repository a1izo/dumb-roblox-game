"""The R6 reference rig, built here from code: an armature "R6" with one bone per part of Roblox's
classic R6 body (art/data/r6_rig.json), each bone's head on its Motor6D pivot, and the blocky body
parented to those bones in the noir mannequin colours. Keyed actions go straight on its bones.

The bones keep the frames of the rig the first clips were made on (Aeresei's "R6 IK + FK Blender
Rig" V2.22, whose InternalArmature this used to load from a downloaded file): the same heads,
lengths and axes, so a clip keyed on either rig exports to the same numbers. (A joint's exported
rotation is its pose relative to its bone's rest frame, so the frames cancel out in any case.)

Bone names are Roblox's part names. JOINTS maps the short joint names used by the game
(src/shared/Anim/Joints.luau) to the bone that joint moves. Roblox's six joints:
    root  (RootJoint,      HumanoidRootPart -> Torso)   moves the whole body, and bends the waist
    neck  (Neck,           Torso -> Head)
    rShoulder / lShoulder  (Torso -> Right Arm / Left Arm)
    rHip / lHip            (Torso -> Right Leg / Left Leg)
"""

import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

import common
from common import rbx_to_blender, srgb

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

_S2 = 1 / math.sqrt(2)
_A5, _B5 = 2 / math.sqrt(5), 1 / math.sqrt(5)

# bone -> (rest frame, rows of its 3x3 in Blender space; head (Blender space); length). An arm's bone
# points from the shoulder pivot down and out, a leg's from the hip pivot to the middle of the floor.
BONES = {
    "HumanoidRootPart": (((1, 0, 0), (0, 0, -1), (0, 1, 0)), (0, 0, 3), 0.01),
    "Torso": (((-1, 0, 0), (0, -1, 0), (0, 0, 1)), (0, 0, 3), 0.25),
    "Head": (((1, 0, 0), (0, 0, -1), (0, 1, 0)), (0, 0, 4), 1.0),
    "Right Arm": (((-_S2, _S2, 0), (0, 0, -1), (-_S2, -_S2, 0)), (1, 0, 3.5), math.sqrt(2)),
    "Left Arm": (((-_S2, -_S2, 0), (0, 0, -1), (_S2, -_S2, 0)), (-1, 0, 3.5), math.sqrt(2)),
    "Right Leg": (((-_A5, -_B5, 0), (0, 0, -1), (_B5, -_A5, 0)), (1, 0, 2), math.sqrt(5)),
    "Left Leg": (((-_A5, _B5, 0), (0, 0, -1), (-_B5, -_A5, 0)), (-1, 0, 2), math.sqrt(5)),
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


def head_mesh(name, center, mat):
    """The classic R6 head: a rounded cylinder 1.2 studs across and tall, standing up (Blender z)."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=32, radius1=0.6, radius2=0.6, depth=1.2)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = center
    mesh.materials.append(mat)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = 0.16
    mod.segments = 4
    mod.limit_method = "ANGLE"
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def _armature():
    data = bpy.data.armatures.new("R6")
    arm = bpy.data.objects.new("R6", data)
    common.collection("Rig").objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    edit = {}
    for name, (rows, head, length) in BONES.items():
        eb = data.edit_bones.new(name)
        frame = Matrix(rows).to_4x4()
        frame.translation = Vector(head)
        eb.head = Vector(head)
        eb.tail = Vector(head) + Vector((0, 1, 0))
        eb.matrix = frame
        eb.length = length
        eb.use_connect = False
        eb.use_inherit_rotation = True
        eb.use_local_location = True
        edit[name] = eb
    for name, eb in edit.items():
        parent = PARENT.get(name)
        if parent:
            eb.parent = edit[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    reset_pose(arm)
    return arm


def build_rig():
    """A fresh scene holding the R6 armature and its mannequin; returns the armature, ready to be keyed."""
    common.clear_scene()
    scene = bpy.context.scene
    for coll_obj in list(scene.collection.objects):
        scene.collection.objects.unlink(coll_obj)
    arm = _armature()
    mannequin = common.collection("Mannequin")
    bpy.context.view_layer.update()

    for part in JOINTS.values():
        center, size = PARTS[part]
        mat = part_material(part)
        if part == "Head":
            obj = head_mesh(part + "_Mesh", rbx_to_blender(center), mat)
        else:
            obj = box(part + "_Mesh", rbx_to_blender(center), (size[0], size[2], size[1]), mat, bevel=0.04)
        mannequin.objects.link(obj)
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
