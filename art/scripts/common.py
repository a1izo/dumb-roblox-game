"""Shared helpers for the Inkbound Blender scripts.

Coordinates: Roblox is Y-up and characters face -Z; Blender is Z-up and our rig faces -Y.
    roblox = M @ blender, with M = [[-1, 0, 0], [0, 0, 1], [0, 1, 0]]
so a character's right side (+X in Roblox) is -X in Blender. 1 Blender unit = 1 stud.
"""

import math
import os

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
ART = os.path.join(ROOT, "art")
EXPORT = os.path.join(ART, "export")
PREVIEWS = os.path.join(EXPORT, "previews")
TEXTURES = os.path.join(EXPORT, "textures")
BLEND = os.path.join(ART, "blend")

M = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
M_INV = M.transposed()


def rbx_to_blender(v):
    """A Roblox-space vector (x, y, z) in Blender space."""
    return M_INV @ Vector(v)


def blender_to_rbx(v):
    return M @ Vector(v)


def rbx_angles(deg):
    """Roblox CFrame.Angles(rx, ry, rz) (degrees) as a 3x3 matrix in Roblox space.
    CFrame.Angles applies Z, then Y, then X: R = Rx * Ry * Rz."""
    rx, ry, rz = (math.radians(a) for a in deg)
    return (
        Matrix.Rotation(rx, 3, "X") @ Matrix.Rotation(ry, 3, "Y") @ Matrix.Rotation(rz, 3, "Z")
    )


def ensure_dirs():
    for path in (EXPORT, PREVIEWS, TEXTURES, BLEND):
        os.makedirs(path, exist_ok=True)


def clear_scene():
    """Removes every object and orphan datablock in the current file."""
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for collection in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.armatures,
        bpy.data.actions,
        bpy.data.images,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.curves,
    ):
        for block in list(collection):
            if block.users == 0:
                collection.remove(block)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)


def collection(name):
    coll = bpy.data.collections.get(name)
    if not coll:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    return coll


def material(name, color, roughness=0.6, metallic=0.0, emission=None, strength=1.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    mat.diffuse_color = (*color, 1.0)
    return mat


def srgb(r, g, b):
    """0-255 sRGB colour to linear floats for Blender materials."""

    def lin(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin(r), lin(g), lin(b))


def setup_preview(target=(0, 0, 3), distance=11.0, height=3.5, angle_deg=35, resolution=640):
    """A camera, a key light and a rim light pointed at `target` (Blender space)."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.film_transparent = False
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.32, 0.33, 0.36, 1)
        bg.inputs["Strength"].default_value = 1.0

    cam_data = bpy.data.cameras.get("PreviewCam") or bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.get("PreviewCam") or bpy.data.objects.new("PreviewCam", cam_data)
    if cam.name not in scene.collection.objects:
        scene.collection.objects.link(cam)
    a = math.radians(angle_deg)
    t = Vector(target)
    cam.location = t + Vector((math.sin(a) * distance, -math.cos(a) * distance, height))
    direction = t - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 50
    scene.camera = cam

    for name, energy, offset in (("KeyLight", 900, (-4, -6, 8)), ("RimLight", 600, (5, 6, 6))):
        light_data = bpy.data.lights.get(name) or bpy.data.lights.new(name, "AREA")
        light_data.energy = energy
        light_data.size = 4
        light = bpy.data.objects.get(name) or bpy.data.objects.new(name, light_data)
        if light.name not in scene.collection.objects:
            scene.collection.objects.link(light)
        light.location = t + Vector(offset)
        light.rotation_euler = (t - light.location).to_track_quat("-Z", "Y").to_euler()
    return cam


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def save_blend(name):
    ensure_dirs()
    path = os.path.join(BLEND, name)
    bpy.ops.wm.save_as_mainfile(filepath=path)
    return path
