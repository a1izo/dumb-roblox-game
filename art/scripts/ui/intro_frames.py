"""The apple loading screen, rendered (2026-10-27, the owner's references: an apple falling in the dark and caught in a
hand), uploaded on their own through Studio's importer (Assets.images). (The first join's eye is painted by
eye_intro.py.)

    AppleSpin      1024 x 1024 a 4 x 4 sheet of a red apple turning (transparent), the game flips through it
    AppleHand1, 2  512 x 512   a hand out of a dark suit sleeve with a white cuff: open and waiting, then cupping the
                               apple (transparent)

Also writes src/client/UI/LoadingArt.luau: where the caught apple sits in the hand's picture and how big the falling
apple is beside it, so the falling sprite lands exactly in the hand.

    blender -b --factory-startup --python art/scripts/ui/intro_frames.py
"""

import math
import os
import random
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import common  # noqa: E402

OUT = common.TEXTURES
LUAU = os.path.join(common.ROOT, "src", "client", "UI", "LoadingArt.luau")


# Scene ---------------------------------------------------------------------------------------------------------


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0, 0, 0, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    scene.world = world
    try:
        scene.eevee.taa_render_samples = 64
    except AttributeError:
        pass
    return scene


def material(name, rgb, rough=0.6, metal=0.0, emit=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(name, size, loc, mat, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=[math.radians(a) for a in rot])
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
    obj.data.materials.append(mat)
    return obj


def ellipsoid(name, radii, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, location=loc,
                                         rotation=[math.radians(a) for a in rot])
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = radii
    bpy.ops.object.shade_smooth()
    obj.data.materials.append(mat)
    return obj


def disc(name, radius, depth, loc, mat, rot=(90, 0, 0), verts=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc,
                                        rotation=[math.radians(a) for a in rot])
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def wedge(name, base, tip, width, depth, mat):
    """A long flat blade from `base` to a point at `tip` (in the x-z plane at the base's y), `width` wide at its base."""
    base, tip = Vector(base), Vector(tip)
    axis = tip - base
    side = Vector((-axis.z, 0, axis.x)).normalized() * width / 2
    front, back = Vector((0, -depth / 2, 0)), Vector((0, depth / 2, 0))
    verts = [base - side + front, base + side + front, tip + front, base - side + back, base + side + back, tip + back]
    faces = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    obj = link(bpy.data.objects.new(name, mesh))
    obj.data.materials.append(mat)
    return obj


def camera(loc, look, ortho=None, lens=50):
    cam_data = bpy.data.cameras.new("Camera")
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho
    else:
        cam_data.lens = lens
    cam = link(bpy.data.objects.new("Camera", cam_data))
    cam.location = loc
    direction = Vector(look) - Vector(loc)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def light(kind, loc, look, energy, size=1.0, color=(1, 1, 1)):
    data = bpy.data.lights.new(kind, kind)
    data.energy = energy
    data.color = color
    if kind == "AREA":
        data.size = size
    obj = link(bpy.data.objects.new(kind, data))
    obj.location = loc
    obj.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return obj


def render(path, width, height, transparent):
    scene = bpy.context.scene
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[intro] wrote", path)
    return path


# The apple and the hand ------------------------------------------------------------------------------------------

APPLE_R = 1.0


def apple(loc, turn=0.0, tilt=0.0):
    """A red apple, lathed: its shoulders broad, a dimple at the stem, the stem and a small leaf."""
    red = material("AppleRed", (0.62, 0.02, 0.03), rough=0.22)
    stem = material("Stem", (0.16, 0.1, 0.05), rough=0.8)
    leaf = material("Leaf", (0.12, 0.2, 0.06), rough=0.5)
    profile = [(0.0, -0.86), (0.32, -0.92), (0.66, -0.78), (0.92, -0.44), (1.0, 0.0), (0.96, 0.4), (0.84, 0.7),
               (0.58, 0.86), (0.26, 0.8), (0.08, 0.62), (0.0, 0.58)]
    verts, faces = [], []
    steps = 48
    for i in range(steps):
        a = 2 * math.pi * i / steps
        for r, z in profile:
            # (a slightly lobed body, as apples are)
            lobe = 1.0 + 0.015 * math.sin(5 * a) * (1 - abs(z))
            verts.append((r * lobe * math.cos(a) * APPLE_R, r * lobe * math.sin(a) * APPLE_R, z * APPLE_R))
    n = len(profile)
    for i in range(steps):
        j = (i + 1) % steps
        for k in range(n - 1):
            faces.append((i * n + k, j * n + k, j * n + k + 1, i * n + k + 1))
    mesh = bpy.data.meshes.new("Apple")
    mesh.from_pydata(verts, [], faces)
    obj = link(bpy.data.objects.new("Apple", mesh))
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.modifiers.new("Smooth", "SUBSURF").levels = 2
    obj.data.materials.append(red)
    parts = [obj]
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.05, depth=0.5, location=(0.04, 0, 0.78), rotation=(0, 0.25, 0))
    s = bpy.context.active_object
    s.data.materials.append(stem)
    parts.append(s)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=1, location=(0.28, 0.0, 0.86))
    lf = bpy.context.active_object
    lf.scale = (0.26, 0.1, 0.08)
    lf.rotation_euler = (0, math.radians(-25), math.radians(20))
    lf.data.materials.append(leaf)
    parts.append(lf)
    root = link(bpy.data.objects.new("AppleRoot", None))
    for part in parts:
        part.parent = root
    root.location = loc
    root.rotation_euler = (math.radians(tilt), math.radians(tilt * 0.4), turn)
    return root


def hand(cupped):
    """A hand out of a dark suit sleeve with a white cuff, reaching up and in from the bottom left, palm up, its
    fingers apart and curling up (round the apple when `cupped`). Built in the hand's own frame (x across the palm,
    y along the fingers, z out of the palm), then laid in. Returns where an apple held in it sits."""
    skin = material("HandSkin", (0.74, 0.72, 0.71), rough=0.6)
    wool = material("Wool", (0.07, 0.07, 0.08), rough=0.85)
    cuff = material("Cuff", (0.9, 0.9, 0.88), rough=0.6)
    root = link(bpy.data.objects.new("Hand", None))

    def piece(name, size, centre, mat, pivot=None, rot=(0, 0, 0), bevel=0.12):
        obj = box(name, size, centre, mat, bevel=bevel)
        obj.parent = pivot or root
        if rot != (0, 0, 0):
            obj.rotation_euler = [math.radians(a) for a in rot]
        return obj

    piece("Sleeve", (2.0, 6.0, 1.9), (0, -4.1, -0.1), wool, bevel=0.2)
    piece("Cuff", (1.66, 0.36, 1.6), (0, -1.0, -0.05), cuff, bevel=0.06)
    piece("Wrist", (1.2, 0.8, 0.8), (0, -0.55, -0.05), skin, bevel=0.25)
    piece("Palm", (1.9, 1.8, 0.6), (0, 0.6, -0.05), skin, bevel=0.25)
    curl = (52, 46) if cupped else (16, 12)
    for k, (x, length) in enumerate(((-0.72, 1.0), (-0.24, 1.15), (0.24, 1.08), (0.72, 0.86))):
        knuckle = link(bpy.data.objects.new("Knuckle", None))
        knuckle.parent = root
        knuckle.location = (x, 1.45, 0.0)
        knuckle.rotation_euler = (math.radians(curl[0] + 3 * k), 0, math.radians(-x * 5))
        piece("Finger", (0.38, length * 0.56, 0.42), (0, length * 0.28, 0), skin, pivot=knuckle, bevel=0.14)
        joint = link(bpy.data.objects.new("Joint", None))
        joint.parent = knuckle
        joint.location = (0, length * 0.56, 0)
        joint.rotation_euler = (math.radians(curl[1]), 0, 0)
        piece("Tip", (0.36, length * 0.48, 0.38), (0, length * 0.22, 0), skin, pivot=joint, bevel=0.14)
    thumb = link(bpy.data.objects.new("Thumb", None))
    thumb.parent = root
    thumb.location = (1.0, 0.1, 0.1)
    thumb.rotation_euler = (math.radians(40 if cupped else 20), 0, math.radians(-35))
    piece("ThumbBase", (0.48, 0.72, 0.46), (0, 0.34, 0), skin, pivot=thumb, bevel=0.15)
    piece("ThumbTip", (0.44, 0.58, 0.42), (0, 0.9, 0.12), skin, pivot=thumb, rot=(25, 0, 0), bevel=0.15)
    # Laid in: the fingers point up and to the right, the palm faces up and a little toward the camera.
    forward = Vector((math.cos(math.radians(24)), 0.0, math.sin(math.radians(24))))
    up = Vector((-math.sin(math.radians(24)), -0.3, math.cos(math.radians(24)))).normalized()
    up = (up - forward * up.dot(forward)).normalized()
    across = forward.cross(up)
    basis = Matrix((across, forward, up)).transposed()
    root.matrix_world = Matrix.Translation(Vector((0, 0, 0))) @ basis.to_4x4()
    bpy.context.view_layer.update()
    return root.matrix_world @ Vector((0.0, 0.55, 1.0))

def hand_scene(cupped):
    reset()
    held = hand(cupped)
    if cupped:
        apple(held, turn=math.radians(25), tilt=-8)
    cam = camera((0.6, -30.0, 0.9), (0.6, 0.0, 0.9), ortho=HAND_ORTHO)
    light("AREA", (-6.0, -12.0, 9.0), (0.0, 0.0, 0.0), 2200.0, size=6.0)
    light("AREA", (7.0, -8.0, -3.0), (0.0, 0.0, 0.0), 500.0, size=5.0, color=(0.85, 0.85, 0.95))
    return cam, held


HAND_ORTHO = 9.0
APPLE_ORTHO = 2.6
CELL = 256
SHEET = 4


def apple_sheet():
    """The apple turning, 16 frames, composed into one 4 x 4 sheet (transparent)."""
    cells = []
    for k in range(SHEET * SHEET):
        reset()
        apple((0, 0, 0), turn=2 * math.pi * k / (SHEET * SHEET), tilt=-14)
        camera((0.0, -20.0, 0.0), (0.0, 0.0, 0.0), ortho=APPLE_ORTHO)
        light("AREA", (-5.0, -8.0, 6.0), (0.0, 0.0, 0.0), 900.0, size=3.0)
        light("AREA", (5.0, -6.0, -2.0), (0.0, 0.0, 0.0), 160.0, size=3.0, color=(0.9, 0.85, 0.9))
        path = render(os.path.join(common.ROOT, "art", "export", "previews", f"_apple_{k:02d}.png"), CELL, CELL, True)
        img = bpy.data.images.load(path)
        cells.append(np.array(img.pixels[:], dtype=np.float32).reshape(CELL, CELL, 4))
    sheet = np.zeros((CELL * SHEET, CELL * SHEET, 4), dtype=np.float32)
    for k, cell in enumerate(cells):
        row, col = divmod(k, SHEET)
        # (Blender's pixels run bottom up: the sheet's first row is its top)
        y0 = (SHEET - 1 - row) * CELL
        sheet[y0:y0 + CELL, col * CELL:(col + 1) * CELL] = cell
    out = bpy.data.images.new("AppleSpin", CELL * SHEET, CELL * SHEET, alpha=True)
    out.pixels = sheet.ravel()
    out.filepath_raw = os.path.join(OUT, "AppleSpin.png")
    out.file_format = "PNG"
    out.save()
    print("[intro] wrote", out.filepath_raw)
    for k in range(SHEET * SHEET):
        os.remove(os.path.join(common.ROOT, "art", "export", "previews", f"_apple_{k:02d}.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    apple_sheet()
    catch = None
    for k, cupped in enumerate((False, True)):
        cam, held = hand_scene(cupped)
        render(os.path.join(OUT, f"AppleHand{k + 1}.png"), 512, 512, True)
        if cupped:
            at = world_to_camera_view(bpy.context.scene, cam, held)
            catch = (round(at.x, 4), round(1 - at.y, 4))
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/ui/intro_frames.py. Do not edit by hand.",
        "-- The apple loading screen's pictures (UI/AppleLoading): where the caught apple sits in the hand's picture",
        "-- (AppleHand2, as a share of its width and height from the top left), and how big the falling apple's picture",
        "-- (one cell of AppleSpin) is beside the hand's (both drawn to the same scale).",
        "",
        "return {",
        f"\tcatch = Vector2.new({catch[0]}, {catch[1]}),",
        f"\tappleScale = {round(APPLE_ORTHO / HAND_ORTHO, 4)},",
        f"\tcell = {CELL},",
        f"\tgrid = {SHEET},",
        "}",
    ]
    with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("[intro] wrote", LUAU)


main()
