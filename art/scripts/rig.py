"""Builds an R15 reference rig: an armature whose bones pivot where Roblox's R15 Motor6Ds do,
plus a blocky noir mannequin parented to the bones for previews.

Bone names are the Roblox part names. JOINTS maps the short joint names used by the game
(src/shared/Anim/Joints.luau) to the bone that joint moves.
"""

import bmesh
import bpy
from mathutils import Matrix, Vector

import common
from common import rbx_to_blender, srgb

# joint name -> (bone / part name, parent bone, pivot in Roblox space, tail in Roblox space)
LAYOUT = [
    ("root", "LowerTorso", "HumanoidRootPart", (0, 3.0, 0), (0, 3.2, 0)),
    ("waist", "UpperTorso", "LowerTorso", (0, 3.2, 0), (0, 4.8, 0)),
    ("neck", "Head", "UpperTorso", (0, 4.8, 0), (0, 6.0, 0)),
    ("rShoulder", "RightUpperArm", "UpperTorso", (1.0, 4.55, 0), (1.5, 3.55, 0)),
    ("rElbow", "RightLowerArm", "RightUpperArm", (1.5, 3.55, 0), (1.5, 2.6, 0)),
    ("rWrist", "RightHand", "RightLowerArm", (1.5, 2.6, 0), (1.5, 2.25, 0)),
    ("lShoulder", "LeftUpperArm", "UpperTorso", (-1.0, 4.55, 0), (-1.5, 3.55, 0)),
    ("lElbow", "LeftLowerArm", "LeftUpperArm", (-1.5, 3.55, 0), (-1.5, 2.6, 0)),
    ("lWrist", "LeftHand", "LeftLowerArm", (-1.5, 2.6, 0), (-1.5, 2.25, 0)),
    ("rHip", "RightUpperLeg", "LowerTorso", (0.5, 2.8, 0), (0.5, 1.6, 0)),
    ("rKnee", "RightLowerLeg", "RightUpperLeg", (0.5, 1.6, 0), (0.5, 0.4, 0)),
    ("rAnkle", "RightFoot", "RightLowerLeg", (0.5, 0.4, 0), (0.5, 0.1, -0.6)),
    ("lHip", "LeftUpperLeg", "LowerTorso", (-0.5, 2.8, 0), (-0.5, 1.6, 0)),
    ("lKnee", "LeftLowerLeg", "LeftUpperLeg", (-0.5, 1.6, 0), (-0.5, 0.4, 0)),
    ("lAnkle", "LeftFoot", "LeftLowerLeg", (-0.5, 0.4, 0), (-0.5, 0.1, -0.6)),
]

JOINTS = {row[0]: row[1] for row in LAYOUT}

# part -> (centre, size) in Roblox space, for the mannequin
PARTS = {
    "LowerTorso": ((0, 3.0, 0), (2, 0.4, 1)),
    "UpperTorso": ((0, 4.0, 0), (2, 1.6, 1)),
    "Head": ((0, 5.4, 0), (1.2, 1.2, 1.2)),
    "RightUpperArm": ((1.5, 4.075, 0), (1, 1.05, 1)),
    "RightLowerArm": ((1.5, 3.075, 0), (1, 0.95, 1)),
    "RightHand": ((1.5, 2.425, 0), (0.9, 0.35, 0.9)),
    "LeftUpperArm": ((-1.5, 4.075, 0), (1, 1.05, 1)),
    "LeftLowerArm": ((-1.5, 3.075, 0), (1, 0.95, 1)),
    "LeftHand": ((-1.5, 2.425, 0), (0.9, 0.35, 0.9)),
    "RightUpperLeg": ((0.5, 2.2, 0), (1, 1.2, 1)),
    "RightLowerLeg": ((0.5, 1.0, 0), (1, 1.2, 1)),
    "RightFoot": ((0.5, 0.2, -0.15), (1, 0.4, 1.3)),
    "LeftUpperLeg": ((-0.5, 2.2, 0), (1, 1.2, 1)),
    "LeftLowerLeg": ((-0.5, 1.0, 0), (1, 1.2, 1)),
    "LeftFoot": ((-0.5, 0.2, -0.15), (1, 0.4, 1.3)),
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
    root.head = rbx_to_blender((0, 3.0, 0.4))
    root.tail = rbx_to_blender((0, 3.0, 1.4))
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
    details = [
        ("ShirtFront", "UpperTorso", (0, 4.35, -0.51), (0.55, 0.8, 0.04), common.material("Shirt", SHIRT, 0.5)),
        ("Tie", "UpperTorso", (0, 4.1, -0.54), (0.2, 0.95, 0.04), common.material("Tie", TIE, 0.45)),
        ("EyeL", "Head", (-0.22, 5.5, -0.61), (0.14, 0.2, 0.04), common.material("Ink", (0.01, 0.01, 0.01), 0.3)),
        ("EyeR", "Head", (0.22, 5.5, -0.61), (0.14, 0.2, 0.04), common.material("Ink", (0.01, 0.01, 0.01), 0.3)),
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
