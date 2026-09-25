"""Builds an R15 reference rig: an armature whose bones pivot where Roblox's R15 Motor6Ds do,
plus a blocky noir mannequin parented to the bones for previews.

Bone names are the Roblox part names. JOINTS maps the short joint names used by the game
(src/shared/Anim/Joints.luau) to the bone that joint moves.
"""

import json
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

import common
from common import rbx_to_blender, srgb

# The joints and parts come from the R15 rig that ships with Roblox Studio (art/data/r15_rig.json,
# written by r15_extract.py), so what the previews show is what the game plays.
_R15 = json.load(open(os.path.join(common.ART, "data", "r15_rig.json")))

# joint name -> (bone / part name, parent part, motor)
_JOINT_PARTS = [
    ("root", "LowerTorso", "HumanoidRootPart", "Root"),
    ("waist", "UpperTorso", "LowerTorso", "Waist"),
    ("neck", "Head", "UpperTorso", "Neck"),
    ("rShoulder", "RightUpperArm", "UpperTorso", "RightShoulder"),
    ("rElbow", "RightLowerArm", "RightUpperArm", "RightElbow"),
    ("rWrist", "RightHand", "RightLowerArm", "RightWrist"),
    ("lShoulder", "LeftUpperArm", "UpperTorso", "LeftShoulder"),
    ("lElbow", "LeftLowerArm", "LeftUpperArm", "LeftElbow"),
    ("lWrist", "LeftHand", "LeftLowerArm", "LeftWrist"),
    ("rHip", "RightUpperLeg", "LowerTorso", "RightHip"),
    ("rKnee", "RightLowerLeg", "RightUpperLeg", "RightKnee"),
    ("rAnkle", "RightFoot", "RightLowerLeg", "RightAnkle"),
    ("lHip", "LeftUpperLeg", "LowerTorso", "LeftHip"),
    ("lKnee", "LeftLowerLeg", "LeftUpperLeg", "LeftKnee"),
    ("lAnkle", "LeftFoot", "LeftLowerLeg", "LeftAnkle"),
]


def _rest_positions():
    """Part centres and joint pivots at rest, with the HumanoidRootPart above the origin."""
    parts = _R15["parts"]
    hrp = parts["HumanoidRootPart"]["cframe"]["p"]
    centre = {name: Vector((p["cframe"]["p"][0] - hrp[0], p["cframe"]["p"][1], p["cframe"]["p"][2] - hrp[2]))
              for name, p in parts.items()}
    pivots = {}
    for motor in _R15["motors"]:
        c0 = motor["c0"]["p"]
        pivots[motor["name"]] = centre[motor["part0"]] + Vector(c0)
    return centre, pivots


PART_CENTRES, MOTOR_PIVOTS = _rest_positions()

# joint name -> (bone / part name, parent bone, pivot in Roblox space, tail in Roblox space)
LAYOUT = []
for _joint, _part, _parent, _motor in _JOINT_PARTS:
    _pivot = MOTOR_PIVOTS[_motor]
    _centre = PART_CENTRES[_part]
    # The bone points from the joint through the middle of its part (feet point forward).
    _tail = _centre + (_centre - _pivot) if (_centre - _pivot).length > 0.05 else _pivot + Vector((0, 0.3, 0))
    if "Foot" in _part:
        _tail = Vector((_pivot.x, _centre.y - 0.1, _pivot.z - 0.5))
    LAYOUT.append((_joint, _part, _parent, tuple(_pivot), tuple(_tail)))

JOINTS = {row[0]: row[1] for row in LAYOUT}
ROOT_PIVOT = tuple(MOTOR_PIVOTS["Root"])

# part -> (centre, size) in Roblox space, for the mannequin. The classic head is a 2x1x1 box
# with a rounded mesh in game; the mannequin uses a block of the same height instead.
PARTS = {}
for _name, _info in _R15["parts"].items():
    if _name == "HumanoidRootPart":
        continue
    _size = tuple(_info["size"])
    if _name == "Head":
        _size = (1.2, 1.2, 1.2)
    PARTS[_name] = (tuple(PART_CENTRES[_name]), _size)

# Leg lengths of this rig (studs), used to match strides on bigger or smaller avatars.
LEG = {
    "hip": MOTOR_PIVOTS["RightHip"].y,
    "thigh": (MOTOR_PIVOTS["RightHip"] - MOTOR_PIVOTS["RightKnee"]).length,
    "shin": (MOTOR_PIVOTS["RightKnee"] - MOTOR_PIVOTS["RightAnkle"]).length,
    "ankle": MOTOR_PIVOTS["RightAnkle"].y,
}

SUIT = srgb(34, 34, 40)
TROUSERS = srgb(26, 26, 30)
SHOES = srgb(12, 12, 13)
SKIN = srgb(232, 196, 160)
SHIRT = srgb(236, 233, 226)
TIE = srgb(190, 22, 36)


def part_material(part):
    if part in ("Head", "RightHand", "LeftHand"):
        return common.material("Skin", SKIN, 0.55)
    if "Foot" in part:
        return common.material("Shoes", SHOES, 0.35)
    if "Leg" in part:
        return common.material("Trousers", TROUSERS, 0.8)
    return common.material("Suit", SUIT, 0.75)


def box(name, center, size, mat, bevel=0.06):
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
    bone = arm.data.bones[bone_name]
    world = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_parent_inverse = (
        arm.matrix_world @ bone.matrix_local @ Matrix.Translation((0, bone.length, 0))
    ).inverted()
    obj.matrix_world = world


def build_rig():
    common.clear_scene()
    coll = common.collection("Rig")
    arm_data = bpy.data.armatures.new("R15")
    arm = bpy.data.objects.new("R15", arm_data)
    coll.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm_data.edit_bones.new("HumanoidRootPart")
    root.head = rbx_to_blender((0, ROOT_PIVOT[1], 0.4))
    root.tail = rbx_to_blender((0, ROOT_PIVOT[1], 1.4))
    for _, bone_name, parent, pivot, tail in LAYOUT:
        bone = arm_data.edit_bones.new(bone_name)
        bone.head = rbx_to_blender(pivot)
        bone.tail = rbx_to_blender(tail)
        bone.roll = 0
        bone.parent = arm_data.edit_bones[parent]
        bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pose_bone in arm.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"

    mannequin = common.collection("Mannequin")
    for part, (center, size) in PARTS.items():
        obj = box(part + "_Mesh", rbx_to_blender(center), (size[0], size[2], size[1]), part_material(part))
        mannequin.objects.link(obj)
        bpy.context.view_layer.update()
        parent_to_bone(obj, arm, part)

    # Details that show which way the mannequin faces: shirt front, tie and eyes.
    torso = PART_CENTRES["UpperTorso"]
    head = PART_CENTRES["Head"]
    details = [
        ("ShirtFront", "UpperTorso", (0, torso.y + 0.42, -0.51), (0.55, 0.7, 0.04), common.material("Shirt", SHIRT, 0.5)),
        ("Tie", "UpperTorso", (0, torso.y + 0.2, -0.54), (0.2, 0.9, 0.04), common.material("Tie", TIE, 0.45)),
        ("EyeL", "Head", (-0.22, head.y + 0.1, -0.61), (0.14, 0.2, 0.04), common.material("Ink", (0.01, 0.01, 0.01), 0.3)),
        ("EyeR", "Head", (0.22, head.y + 0.1, -0.61), (0.14, 0.2, 0.04), common.material("Ink", (0.01, 0.01, 0.01), 0.3)),
    ]
    for name, bone_name, center, size, mat in details:
        obj = box(name, rbx_to_blender(center), (size[0], size[2], size[1]), mat, bevel=0.01)
        mannequin.objects.link(obj)
        bpy.context.view_layer.update()
        parent_to_bone(obj, arm, bone_name)

    floor = box("Floor", (0, 0, -0.05), (30, 30, 0.1), common.material("Floor", srgb(40, 40, 46), 0.9), bevel=0)
    common.collection("Stage").objects.link(floor)
    return arm


if __name__ == "__main__":
    build_rig()
