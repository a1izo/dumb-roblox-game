"""Renders contact sheets of animation poses for review (art/export/previews)."""

import math
import os

import bpy
import numpy as np

import common


def _reset(arm):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)


def render_pose(arm, action_name, t, path, size=256, angle=35):
    scene = bpy.context.scene
    action = bpy.data.actions[action_name]
    arm.animation_data.action = action
    _reset(arm)
    frame = t * scene.render.fps
    whole = int(math.floor(frame))
    scene.frame_set(whole, subframe=frame - whole)
    common.setup_preview(target=(0, 0, 2.6), distance=13, height=2.0, angle_deg=angle, resolution=size)
    return common.render(path)


def sheet(arm, shots, name, columns=6, size=256):
    """shots: [(action, time, angle)]. Writes one image with every shot in a grid."""
    tiles = []
    tmp = os.path.join(common.PREVIEWS, "_tile.png")
    for action_name, t, angle in shots:
        render_pose(arm, action_name, t, tmp, size, angle)
        img = bpy.data.images.load(tmp, check_existing=False)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)
        tiles.append(px)
        bpy.data.images.remove(img)
    rows = math.ceil(len(tiles) / columns)
    canvas = np.zeros((rows * size, columns * size, 4), dtype=np.float32)
    canvas[..., 3] = 1
    for i, tile in enumerate(tiles):
        r, c = divmod(i, columns)
        # Blender images start at the bottom row.
        y0 = (rows - 1 - r) * size
        canvas[y0 : y0 + size, c * size : (c + 1) * size] = tile
    out = bpy.data.images.new(name, columns * size, rows * size, alpha=True)
    out.pixels = canvas.ravel()
    path = os.path.join(common.PREVIEWS, name + ".png")
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)
    if os.path.exists(tmp):
        os.remove(tmp)
    arm.animation_data.action = None
    _reset(arm)
    return path
