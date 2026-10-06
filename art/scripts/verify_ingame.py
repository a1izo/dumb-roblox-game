"""Checks that the game plays the animations the way they look in Blender (background Blender):

    blender -b --factory-startup --python art/scripts/verify_ingame.py -- [out.png] [clip:time ...]

For each shot it renders two bodies side by side:
  left:  the Blender rig, posed by its action (what the previews show),
  right: a real Roblox R6 body (art/data/r6_rig.json) posed from
         src/shared/Anim/Clips.luau with the same maths the game uses (ClipPlayer +
         PoseController): Part1 = Part0 * C0 * Transform * C1:Inverse().
If the two disagree, the export or the playback is wrong.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
from rbxsim import cf, load_clips, load_rig, pose_parts  # noqa: E402



DEFAULT_SHOTS = [("idle", 0.6), ("walk", 0.0), ("walk", 0.25), ("run", 0.1)]


# --- Blender side -----------------------------------------------------------------------


def box_object(name, world, size, shift, mat):
    sx, sy, sz = (s / 2 for s in size)
    corners = []
    for x in (-sx, sx):
        for y in (-sy, sy):
            for z in (-sz, sz):
                p = world @ np.array([x, y, z, 1.0])
                corners.append(Vector((p[0], -p[2], p[1])) + shift)
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(c) for c in corners], [], faces)
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_sim(rig, clip, t, shift):
    body = common.material("SimBody", common.srgb(120, 150, 205), 0.5)
    face = common.material("SimFace", common.srgb(230, 60, 60), 0.4)
    objs = []
    world = pose_parts(rig, clip, t)
    hrp = rig["parts"]["HumanoidRootPart"]["cframe"]["p"]
    for name, m in world.items():
        if name == "HumanoidRootPart":
            continue
        m = m.copy()
        m[0, 3] -= hrp[0]  # stand the body on the origin
        m[2, 3] -= hrp[2]
        objs.append(box_object("sim_" + name, m, rig["parts"][name]["size"], shift, body))
        if name == "Head":
            nose = m @ cf((0, 0, -0.55))
            objs.append(box_object("sim_nose", nose, (0.35, 0.25, 0.2), shift, face))
    return objs


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = "verify_ingame.png"
    shots = DEFAULT_SHOTS
    rest = []
    angle = 20
    for arg in argv:
        if arg.endswith(".png"):
            out = arg
        elif arg.startswith("--angle="):
            angle = float(arg.split("=")[1])
        else:
            rest.append(arg)
    if rest:
        shots = [(a.split(":")[0], float(a.split(":")[1])) for a in rest]

    clips = load_clips()
    rig = load_rig()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(common.BLEND, "Animations.blend"))
    arm = bpy.data.objects["R6"]
    scene = bpy.context.scene
    size, columns = 400, 4
    tiles = []
    tmp = os.path.join(common.PREVIEWS, "_verify.png")
    shift = Vector((-5.0, 0, 0))  # the sim stands to the Blender rig's right on screen (the camera looks from the +Y side)
    for name, t in shots:
        clip = clips[name]
        t = min(t, clip["length"])
        action = bpy.data.actions.get(name)
        arm.animation_data.action = action
        for pb in arm.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
        frame = t * scene.render.fps
        scene.frame_set(int(frame), subframe=frame - int(frame))
        objs = build_sim(rig, clip, t, shift)
        common.setup_preview(target=(-2.5, 0, 2.0), distance=19, height=2.0, angle_deg=angle, resolution=size, side=1)
        common.render(tmp)
        img = bpy.data.images.load(tmp, check_existing=False)
        tiles.append(np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4))
        bpy.data.images.remove(img)
        for obj in objs:
            bpy.data.objects.remove(obj, do_unlink=True)
    rows = math.ceil(len(tiles) / columns)
    canvas = np.zeros((rows * size, columns * size, 4), dtype=np.float32)
    canvas[..., 3] = 1
    for i, tile in enumerate(tiles):
        r, c = divmod(i, columns)
        y0 = (rows - 1 - r) * size
        canvas[y0 : y0 + size, c * size : (c + 1) * size] = tile
    img = bpy.data.images.new("verify", columns * size, rows * size, alpha=True)
    img.pixels = canvas.ravel()
    path = out if os.path.isabs(out) else os.path.join(common.PREVIEWS, out)
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    if os.path.exists(tmp):
        os.remove(tmp)
    print("[verify]", path, [s[0] for s in shots])


main()
