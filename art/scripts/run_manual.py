"""Death's Manual, for looking at before it is built into the game:

    blender -b --factory-startup --python art/scripts/run_manual.py -- [A B C]

builds the book once for each cover named (all three by default; see manual_art.py) and writes
art/export/previews/_manual_sheet.png: for each cover its drawing as it lies in the texture, the book
closed and open, and the closed book again at the sizes it has on screen when it lands in the intro
and when it is held up in the role reveal.

Nothing the game uses is touched: the scene starts empty and is not saved (art/blend/Props.blend is
neither opened nor written), no FBX and no catalog are written, and the textures go to
art/export/previews/_manual/<cover>/ instead of art/export/textures/.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import build_props  # noqa: E402
import common  # noqa: E402
import manual_art  # noqa: E402
import modelkit as mk  # noqa: E402
import props  # noqa: E402
import sheets  # noqa: E402
from common import srgb  # noqa: E402

KEY = "Grimoire"
OUT = os.path.join(common.PREVIEWS, "_manual")
TILE = 900  # a picture's width on the sheet


def pose(cover=0.0, leaves=0.0):
    """Opens the book: cover 0..1 turns the front board over, leaves 0..1 turns the loose leaves over.
    (The game does the same from the catalog's hinge and turn: ManualBook.luau.)"""
    main = bpy.data.objects[KEY]
    hinge, turn = json.loads(main["hinge"]), json.loads(main["turn"])

    def turned(name, share):
        x, y, z = hinge[name]  # (Roblox axes in the catalog: back to Blender's)
        at = Vector((-x, z, y))
        spin = Matrix.Rotation(math.radians(-turn[name] * share), 4, "Y")
        return Matrix.Translation(at) @ spin @ Matrix.Translation(-at)

    bpy.data.objects[KEY + "_Cover"].matrix_world = turned("Cover", cover)
    for i in range(props.LEAVES):
        bpy.data.objects[f"{KEY}_Leaf{i + 1}"].matrix_world = turned(f"Leaf{i + 1}", leaves)


def _stage():
    """A dark floor, a camera and three lamps (the leather is black: it is read by what it reflects)."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.05, 0.055, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    floor = mk.box("ManualFloor", (40, 40, 0.2), (0, 0, -0.317), mat=mk.flat("ManualFloor_Stone", srgb(34, 34, 37), 0.85))
    cam_data = bpy.data.cameras.new("ManualCam")
    cam_data.lens = 60
    cam = bpy.data.objects.new("ManualCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, energy, size, at in (("ManualKey", 700, 4, (-3.5, -2.5, 6.0)), ("ManualFill", 160, 7, (5.0, -5.0, 3.0)),
                                   ("ManualRim", 500, 3, (1.5, 6.0, 4.0))):
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = energy
        light_data.size = size
        light = bpy.data.objects.new(name, light_data)
        scene.collection.objects.link(light)
        light.location = at
        light.rotation_euler = (Vector((0, 0, 0)) - light.location).to_track_quat("-Z", "Y").to_euler()
    return floor, cam


def _shoot(cam, eye, target, width, height, path):
    scene = bpy.context.scene
    cam.location = eye
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    scene.render.resolution_x, scene.render.resolution_y = width, height
    return common.render(path)


def _read(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, img.channels)
    bpy.data.images.remove(img)
    if px.shape[2] == 3:
        px = np.concatenate([px, np.ones((h, w, 1), dtype=np.float32)], axis=-1)
    return px


def _write(path, px):
    h, w = px.shape[:2]
    img = bpy.data.images.new("ManualTile", w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(px, dtype=np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def _tile(pictures, height, path, ground=(0.03, 0.03, 0.033)):
    """Pictures side by side, each at its own size, in the middle of a tile TILE wide."""
    tile = np.ones((height, TILE, 4), dtype=np.float32)
    tile[..., :3] = ground
    gap = (TILE - sum(p.shape[1] for p in pictures)) // (len(pictures) + 1)
    x = gap
    for p in pictures:
        y = (height - p.shape[0]) // 2
        tile[y : y + p.shape[0], x : x + p.shape[1]] = p
        x += p.shape[1] + gap
    return _write(path, tile)


def one(variant, cam):
    """Builds the book with one cover and returns its row of pictures for the sheet."""
    folder = os.path.join(OUT, variant)
    os.makedirs(folder, exist_ok=True)
    common.TEXTURES = folder
    manual_art.VARIANT = variant
    _, _, info = build_props.build_one(KEY)
    print(f"[manual] {variant}: size {info['size']} tris {info['tris']}")
    for name in ("Build",):
        coll = bpy.data.collections.get(name)
        if coll:
            for obj in list(coll.objects):
                if not obj.name.startswith("Manual"):
                    bpy.data.objects.remove(obj, do_unlink=True)

    def shot(name, *args):
        return _shoot(cam, *args, os.path.join(folder, name + ".png"))

    # The drawing as it lies in the cover's texture.
    u0, v0, u1, v1 = props.MANUAL_FRONT
    art = _read(os.path.join(folder, KEY + "_Cover_color.jpg"))
    size = art.shape[0]
    art = art[round(v0 * size) : round(v1 * size), round(u0 * size) : round(u1 * size)]
    flat = _tile([art], art.shape[0] + 40, os.path.join(folder, "flat.png"))

    pose(0, 0)
    closed = shot("closed", (2.6, -4.2, 4.3), (0.05, -0.1, 0.0), TILE, 760)
    # At the sizes it has on screen: landing in the intro (11 studs away), held up in the role reveal (6.5).
    far = shot("far", (2.1, -3.4, 3.5), (0.05, -0.1, 0.0), 280, 280)
    near = shot("near", (0.9, -1.5, 5.2), (0.0, 0.0, 0.0), 520, 620)
    sizes = _tile([_read(near), _read(far)], 660, os.path.join(folder, "sizes.png"))
    pose(1, 1)
    spread = shot("open", (-1.0, -4.9, 5.8), (-1.0, -0.05, -0.1), TILE, 700)
    pose(0.5, 0.0)
    half = shot("half", (2.2, -4.4, 3.4), (-0.4, 0.0, 0.3), TILE, 640)
    return [flat, closed, spread, half, sizes]


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    variants = [a for a in argv if a in manual_art.VARIANTS] or list(manual_art.VARIANTS)
    common.clear_scene()
    mk.new_build()
    _, cam = _stage()
    columns = [one(variant, cam) for variant in variants]
    rows = [[column[i] for column in columns] for i in range(len(columns[0]))]
    path = sheets._compose(rows, os.path.join(common.PREVIEWS, "_manual_sheet.png"))
    print("[manual] sheet", path)


main()
