"""Preview videos of animation clips, for review (background Blender):

    blender -b --factory-startup --python art/scripts/video_anims.py -- out.mp4 [--seconds=4] [--fps=30] \
        [--width=1600] [--height=640] [--angle=0] clip clip ...

Every clip gets its own copy of the R6 mannequin in a row, labelled with the clip's name, all
playing at once and looping. Movement clips play in place. Videos are written to
art/export/previews/anims/. Angles are degrees round the characters (0 = front, 90 = their left).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402

SPACING = 4.6
OUT_DIR = os.path.join(common.PREVIEWS, "anims")


def duplicate_rig(arm, index, offset):
    """A copy of the armature and everything parented to it, shifted by `offset` (Blender x)."""
    scene = bpy.context.scene
    new_arm = arm.copy()
    new_arm.data = arm.data.copy()
    new_arm.name = f"{arm.name}.{index}"
    scene.collection.objects.link(new_arm)
    new_arm.location = (offset, 0, 0)
    for child in arm.children:
        copy = child.copy()
        if child.data is not None:
            copy.data = child.data.copy()
        copy.parent = new_arm
        copy.parent_type = child.parent_type
        copy.parent_bone = child.parent_bone
        copy.matrix_parent_inverse = child.matrix_parent_inverse.copy()
        scene.collection.objects.link(copy)
    return new_arm


def loop(action):
    """Makes every curve of the action repeat, so the clip plays round and round."""
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if not any(m.type == "CYCLES" for m in fc.modifiers):
                        fc.modifiers.new("CYCLES")


def label(text, x, z=0.05):
    curve = bpy.data.curves.new("label_" + text, "FONT")
    curve.body = text
    curve.align_x = "CENTER"
    curve.size = 0.55
    obj = bpy.data.objects.new("label_" + text, curve)
    obj.location = (x, 3.2, z)
    obj.rotation_euler = (math.radians(90), 0, math.radians(180))
    mat = common.material("Label", (1, 1, 1), 0.5, emission=(1, 1, 1), strength=1.0)
    curve.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    out = argv[0]
    seconds, fps, width, height, angle = 4.0, 30, 1600, 640, 0.0
    still = None
    names = []
    for a in argv[1:]:
        if a.startswith("--seconds="):
            seconds = float(a.split("=")[1])
        elif a.startswith("--fps="):
            fps = int(a.split("=")[1])
        elif a.startswith("--width="):
            width = int(a.split("=")[1])
        elif a.startswith("--height="):
            height = int(a.split("=")[1])
        elif a.startswith("--angle="):
            angle = float(a.split("=")[1])
        elif a.startswith("--still="):
            still = float(a.split("=")[1])
        else:
            names.append(a)

    bpy.ops.wm.open_mainfile(filepath=os.path.join(common.BLEND, "Animations.blend"))
    scene = bpy.context.scene
    arm = bpy.data.objects["R6"]
    count = len(names)
    rigs = []
    for i, name in enumerate(names):
        x = -(i - (count - 1) / 2) * SPACING  # the camera looks from +Y, so the first clip is on the left
        action = bpy.data.actions[name]
        loop(action)
        rig = arm if i == 0 else duplicate_rig(arm, i, x)
        if i == 0:
            rig.location = (x, 0, 0)
            for child in rig.children:
                pass
        rigs.append((rig, action, x))
        label(name, x)
    bpy.context.view_layer.update()
    for rig, action, _ in rigs:
        rig.animation_data_create()
        rig.animation_data.action = action
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj.name == "Floor":
            obj.dimensions = (SPACING * count + 12, 14, 0.1)

    # The actions are keyed at 60 frames a second; every other scene frame is rendered, so a video
    # at `fps` (30) plays at real speed.
    scene.render.fps = fps
    scene.render.frame_map_old = 1
    scene.render.frame_map_new = 1
    scene.frame_start = 0
    scene.frame_end = int(seconds * 60) - 1
    scene.frame_step = 60 // fps
    width_total = SPACING * count
    a = math.radians(angle)
    target = Vector((0, 0, 2.7))
    dist = max(16.0, width_total * 1.5)  # a 50 mm lens sees 0.72 x the distance across
    common.setup_preview(target=tuple(target), distance=dist, height=1.5, angle_deg=0, resolution=width, side=1)
    cam = scene.camera
    cam.location = target + Vector((math.sin(a) * dist, math.cos(a) * dist, 1.5))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    os.makedirs(OUT_DIR, exist_ok=True)
    path = out if os.path.isabs(out) else os.path.join(OUT_DIR, out)
    if still is not None:
        scene.frame_set(int(still * 60))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("[video]", path)
        return
    scene.render.image_settings.media_type = "VIDEO"
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "MEDIUM"
    scene.render.filepath = path
    bpy.ops.render.render(animation=True)
    print("[video]", path)


main()
