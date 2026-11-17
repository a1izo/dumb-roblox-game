"""Renders BureauBadge at the three distances the Operative's insert shot can show it, from art/blend/Props.blend:

    blender -b --factory-startup --python art/scripts/review_badge.py -- <tag> [samples] [size]

Writes art/export/previews/badge/<tag>_<view>.png for each of: far (3 studs, fov 20), mid (2 studs, fov 15) and
close (1.2 studs, fov 12), straight on, then the same three turned 28 degrees (the insert's slow arc), all under a
low raking warm light on a dark wool suit cloth. Cycles, CPU. The prop's own baked material is rendered, so the
textures shown are the ones that would be exported. (Written 2026-11-17 for the badge remake: the owner's "make the
badge way more high quality".)"""

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "art", "export", "previews", "badge")

VIEWS = {"far": (3.0, 20), "mid": (2.0, 15), "close": (1.2, 12)}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    tag = argv[0] if argv else "now"
    samples = int(argv[1]) if len(argv) > 1 else 96
    size = int(argv[2]) if len(argv) > 2 else 1280
    only = argv[3].split(",") if len(argv) > 3 and argv[3] != "all" else None
    blend = argv[4] if len(argv) > 4 else os.path.join(ROOT, "art", "blend", "Props.blend")
    bpy.ops.wm.open_mainfile(filepath=blend)
    if len(argv) > 5:
        # (an older badge: its textures are in another folder than art/export/textures)
        for img in bpy.data.images:
            if img.name.startswith("BureauBadge"):
                img.filepath = os.path.join(argv[5], os.path.basename(img.filepath.replace("\\", "/")))
                img.reload()
    badge = bpy.data.objects["BureauBadge"]
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj is not badge:
            obj.hide_render = True
            obj.hide_viewport = True
    badge.hide_render = False
    badge.location = (0, 0, 0)
    badge.rotation_euler = (0, 0, 0)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = size
    scene.render.resolution_y = int(size * 9 / 16)
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "Filmic"
    except Exception:  # noqa: BLE001
        pass
    # the dark suit: a big charcoal wool plane behind the badge (it is held up, so the suit is behind it)
    world = bpy.data.worlds.new("BadgeWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.012, 0.012, 0.014, 1)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    cloth = bpy.data.materials.new("SuitCloth")
    cloth.use_nodes = True
    bsdf = cloth.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.018, 0.019, 0.024, 1)
    bsdf.inputs["Roughness"].default_value = 0.9
    plane = bpy.data.objects.new("Suit", bpy.data.meshes.new("Suit"))
    plane.data.from_pydata([(-6, 0.25, -6), (6, 0.25, -6), (6, 0.25, 6), (-6, 0.25, 6)], [], [(0, 1, 2, 3)])
    plane.data.materials.append(cloth)
    scene.collection.objects.link(plane)
    # a low warm key from the left, a weak cool fill from the right
    def lamp(name, kind, loc, energy, color, size_):
        data = bpy.data.lights.new(name, kind)
        data.energy = energy
        data.color = color
        if kind == "AREA":
            data.size = size_
        obj = bpy.data.objects.new(name, data)
        obj.location = loc
        scene.collection.objects.link(obj)
        direction = Vector((0, 0, 0)) - Vector(loc)
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        return obj

    lamp("Key", "AREA", (-1.3, -0.9, 0.35), 55.0, (1.0, 0.72, 0.42), 0.8)
    lamp("Fill", "AREA", (1.6, -1.6, 0.2), 5.0, (0.6, 0.7, 1.0), 1.5)
    os.makedirs(OUT, exist_ok=True)
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.sensor_fit = "VERTICAL"  # (before the angle: the angle is then the vertical one)
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for yaw in (0, 28):
        for name, (dist, fov) in VIEWS.items():
            label = f"{name}{'' if yaw == 0 else '_turn'}"
            if only and label not in only:
                continue
            cam_data.angle = math.radians(fov)
            cam_data.sensor_fit = "VERTICAL"
            a = math.radians(yaw)
            cam.location = (dist * math.sin(a), -dist * math.cos(a), 0.0)
            direction = Vector((0, 0, 0)) - cam.location
            cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
            # the close one looks at the shield (the right half), the rest at the whole badge
            if name == "close":
                target = Vector((0.22, 0, 0.02))
                cam.location = target + Vector((dist * math.sin(a), -dist * math.cos(a), 0.0))
                cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(OUT, f"{tag}_{label}.png")
            bpy.ops.render.render(write_still=True)
            print("[review_badge]", scene.render.filepath)


main()
