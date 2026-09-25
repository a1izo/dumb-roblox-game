"""Builds the map scenes (background Blender):

    blender -b --factory-startup --python art/scripts/run_maps.py -- [venues...] [--preview] [--export]

venues: Lobby Meeting Agency Campus Tokyo (all when none are given)
--preview  renders views of each venue to art/export/previews/map_<Venue>_<n>.png, with the
           props from Props.blend placed and the scene lights on
--export   writes src/server/Maps/Scenes/*.luau, src/shared/SceneMaterials.luau and
           art/export/InkboundMaps.fbx, and saves art/blend/Maps.blend
"""

import importlib
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
from maps import export, matlib, mesher  # noqa: E402

VENUES = ["Lobby", "Meeting", "Agency", "Campus", "Tokyo"]
MODULES = {"Lobby": "lobby", "Meeting": "meeting", "Agency": "agency", "Campus": "campus", "Tokyo": "tokyo"}


def build_venue(name):
    module = importlib.import_module("maps.venues." + MODULES[name])
    scene = mesher.Scene(name)
    module.build(scene)
    coll = common.collection("Scene_" + name)
    started = time.time()
    names = scene.finish(coll)
    print(f"[maps] {name}: {len(names)} meshes, {scene.triangles()} triangles, {len(scene.colliders)} colliders, "
          f"{len(scene.props)} props, {len(scene.lights)} lights ({time.time() - started:.1f}s)")
    return scene, module, coll


# Previews -------------------------------------------------------------------------------------------

_PROPS = {}


def load_props():
    path = os.path.join(common.BLEND, "Props.blend")
    if _PROPS or not os.path.exists(path):
        return _PROPS
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if not n.startswith("Tex_")]
    for obj in dst.objects:
        if obj is not None:
            _PROPS[obj.name] = obj
    return _PROPS


def place_props(scene, coll):
    library = load_props()
    placed = []
    for key, x, y, z, rot, sc in scene.props + scene.preview_props:
        for name in [key] + [k for k in library if k.startswith(key + "_Glow")]:
            src = library.get(name)
            if not src:
                continue
            obj = src.copy()
            obj.location = (-x, z, y)
            obj.rotation_euler = (0, 0, math.radians(rot))
            obj.scale = (sc, sc, sc)
            coll.objects.link(obj)
            placed.append(obj)
    return placed


def add_lights(scene, coll):
    made = []
    for li in scene.lights:
        data = bpy.data.lights.new("L", "SPOT" if li["kind"] == "spot" else "POINT")
        data.color = [c / 255 for c in li["color"]]
        data.energy = li["brightness"] * li["range"] * li["range"] * 1.6
        data.shadow_soft_size = 0.4
        data.use_shadow = li["shadows"]
        if li["kind"] == "spot":
            data.spot_size = math.radians(min(170, li["angle"] * 1.6))
        obj = bpy.data.objects.new("L", data)
        x, y, z = li["pos"]
        obj.location = (-x, z, y)
        if li["kind"] == "spot":
            obj.rotation_euler = (0, 0, 0)  # points down (-Z in Blender)
        coll.objects.link(obj)
        made.append(obj)
    return made


def render_views(name, module, scene):
    render = bpy.context.scene.render
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    render.resolution_x, render.resolution_y = 1280, 720
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.05, 0.055, 0.075, 1)
    bg.inputs["Strength"].default_value = 1.0
    cam_data = bpy.data.cameras.get("MapCam") or bpy.data.cameras.new("MapCam")
    cam = bpy.data.objects.get("MapCam") or bpy.data.objects.new("MapCam", cam_data)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    paths = []
    for i, view in enumerate(getattr(module, "VIEWS", [])):
        (px, py, pz), (tx, ty, tz), lens = view
        cam.location = (-px, pz, py)
        target = (-tx, tz, ty)
        from mathutils import Vector

        direction = Vector(target) - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = lens
        cam_data.clip_end = 2000
        path = os.path.join(common.PREVIEWS, f"map_{name}_{i + 1}.png")
        common.render(path)
        paths.append(path)
    return paths


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [a for a in argv if not a.startswith("--")] or VENUES
    preview = "--preview" in argv
    do_export = "--export" in argv
    common.clear_scene()
    images = matlib.make_textures()
    mesher.use_images(images)
    built = []
    for name in names:
        scene, module, coll = build_venue(name)
        built.append((scene, module, coll))
    if preview:
        for scene, module, coll in built:
            others = [c for s2, m2, c in built if c is not coll]
            for c in others:
                c.hide_render = True
            # Things the game builds itself (table, screens...) only appear in previews.
            stand_in = mesher.Scene(scene.venue + "Preview")
            if hasattr(module, "preview"):
                module.preview(stand_in)
            stand_coll = common.collection("Preview_" + scene.venue)
            stand_in.finish(stand_coll)
            extra = place_props(scene, coll) + place_props(stand_in, stand_coll) + add_lights(scene, coll)
            print("[maps] previews", render_views(scene.venue, module, scene))
            for obj in set(extra) | set(stand_coll.objects):
                bpy.data.objects.remove(obj, do_unlink=True)
            for c in others:
                c.hide_render = False
    if do_export:
        used = set()
        objects = []
        for scene, module, coll in built:
            export.write_scene(scene, f"art/scripts/maps/venues/{MODULES[scene.venue]}.py")
            used |= scene.used
            objects.extend(o for o in coll.objects if o.type == "MESH")
        export.write_materials(used | set(matlib.FLAT))
        objects.extend(export.calibration_cubes(common.collection("Calibration")))
        print("[maps] fbx", export.export_fbx(objects), len(objects), "objects")
        common.save_blend("Maps.blend")


main()
