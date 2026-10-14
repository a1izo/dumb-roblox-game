"""Numeric check that the exported clips pose a Roblox R6 body like the Blender rig does (background Blender):

    blender -b --factory-startup --python art/scripts/check_export.py -- [clip ...]

For every clip and a spread of times, compares each body part's centre in the Blender rig
(posed by its action) with the same part posed from src/shared/Anim/Clips/ using the
game's maths (rbxsim). Prints the worst distance in studs per clip; anything over a few
hundredths means the export or the playback is wrong. Clips that end on the floor are lifted out
of it by the export (export_anims.lift_to_floor), so for them the whole body's height is matched
first (the torso's) and only the pose is compared.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
from rbxsim import load_clips, load_rig, pose_parts  # noqa: E402

PARTS = ("Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg")


def corners_blender(obj, size):
    """The 8 corners of a part's box in Roblox space, from the part's mesh in the Blender rig.
    (The head mesh is rounded, so its box is rebuilt around the mesh's own centre.)"""
    bb = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    return (mn + mx) / 2, obj.matrix_world.to_3x3()


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    clips = load_clips()
    rig = load_rig()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(common.BLEND, "Animations.blend"))
    arm = bpy.data.objects["R6"]
    scene = bpy.context.scene
    names = argv or sorted(clips)
    worst_all = 0.0
    for name in names:
        clip = clips[name]
        action = bpy.data.actions[name]
        arm.animation_data.action = action
        lifted = bool(action.get("floor"))
        worst = 0.0
        steps = max(4, int(clip["length"] * 4))
        for i in range(steps + 1):
            t = clip["length"] * i / steps
            for pb in arm.pose.bones:
                pb.rotation_quaternion = (1, 0, 0, 0)
                pb.location = (0, 0, 0)
            frame = t * scene.render.fps
            scene.frame_set(int(frame), subframe=frame - int(frame))
            bpy.context.view_layer.update()
            sim = pose_parts(rig, clip, t)
            hrp = rig["parts"]["HumanoidRootPart"]["cframe"]["p"]
            centres = {}
            for part in PARTS:
                obj = bpy.data.objects[part + "_Mesh"]
                centre_b = np.array(common.blender_to_rbx(obj.matrix_world @ ((Vector(obj.bound_box[0]) + Vector(obj.bound_box[6])) / 2)))
                centre_s = sim[part][:3, 3] - np.array([hrp[0], 0, hrp[2]])
                centres[part] = (centre_b, centre_s)
            lift = np.zeros(3)
            if lifted:
                lift[1] = centres["Torso"][1][1] - centres["Torso"][0][1]
            for centre_b, centre_s in centres.values():
                worst = max(worst, float(np.linalg.norm(centre_b + lift - centre_s)))
        worst_all = max(worst_all, worst)
        print(f"[check] {name}: worst part-centre error {worst:.4f} studs")
    arm.animation_data.action = None
    print("[check] worst of all:", round(worst_all, 4))


main()
