"""The VFX kit's smoke, rendered from Blender volumes (Cycles): a puff of smoke that billows out from a point and thins
away, lit from above and to one side so it has a lit top and a shadowed belly, one flipbook frame per moment of its
life; and a column of smoke rising. White and grey (the game tints it). Written to art/export/textures/<name>.png.

    blender -b --factory-startup --python art/scripts/vfx/volumes.py [-- VfxSmoke ...]
"""

import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from vfx import draw as D  # noqa: E402
from vfx.textures import TEXTURES  # noqa: E402


def _scene(px, samples=160):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.volume_step_rate = 0.5
    scene.cycles.volume_max_steps = 256
    scene.render.resolution_x = px
    scene.render.resolution_y = px
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = 0.12
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.0
    cam.location = (0, -5, 0)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scene.collection.objects.link(cam)
    scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 7.0
    sun.rotation_euler = (math.radians(35), math.radians(-30), 0)
    scene.collection.objects.link(sun)
    return scene


def _puff_material(name):
    """A volume shaped like a billowing puff: a sphere whose surface the noise pushes out into lumps (density = the
    depth inside that lumpy surface, over a soft edge), eaten away from inside by a second noise as it thins."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    vol = nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Color"].default_value = (0.95, 0.95, 0.95, 1)
    vol.inputs["Anisotropy"].default_value = 0.3
    coord = nodes.new("ShaderNodeTexCoord")

    def value(label, v=0.0):
        node = nodes.new("ShaderNodeValue")
        node.name = label
        node.outputs[0].default_value = v
        return node.outputs[0]

    def math_node(op, a, b):
        node = nodes.new("ShaderNodeMath")
        node.operation = op
        for i, x in enumerate((a, b)):
            if isinstance(x, (int, float)):
                node.inputs[i].default_value = x
            else:
                links.new(x, node.inputs[i])
        return node.outputs[0]

    lumps = nodes.new("ShaderNodeTexNoise")
    lumps.noise_dimensions = "4D"
    lumps.inputs["Scale"].default_value = 1.6
    lumps.inputs["Detail"].default_value = 4.0
    lumps.inputs["Roughness"].default_value = 0.55
    lumps.inputs["Distortion"].default_value = 0.7
    lumps.name = "Lumps"
    eat = nodes.new("ShaderNodeTexNoise")
    eat.noise_dimensions = "4D"
    eat.inputs["Scale"].default_value = 4.5
    eat.inputs["Detail"].default_value = 6.0
    eat.inputs["Roughness"].default_value = 0.6
    eat.name = "Eat"
    links.new(coord.outputs["Object"], lumps.inputs["Vector"])
    links.new(coord.outputs["Object"], eat.inputs["Vector"])
    length = nodes.new("ShaderNodeVectorMath")
    length.operation = "LENGTH"
    links.new(coord.outputs["Object"], length.inputs[0])
    # depth inside the lumpy surface: R - |p| + (lumps - 0.5) * amp
    surface = math_node("ADD", math_node("SUBTRACT", value("Radius", 0.5), length.outputs["Value"]),
                        math_node("MULTIPLY", math_node("SUBTRACT", lumps.outputs["Fac"], 0.5), value("Amp", 0.7)))
    # eaten from inside as it thins: minus (eat - 0.5) * erosion
    surface = math_node("SUBTRACT", surface,
                        math_node("MULTIPLY", math_node("SUBTRACT", eat.outputs["Fac"], 0.42), value("Erode", 0.0)))
    soft = math_node("DIVIDE", surface, value("Soft", 0.12))
    clamped = math_node("MINIMUM", math_node("MAXIMUM", soft, 0.0), 1.0)
    density = math_node("MULTIPLY", clamped, value("Strength", 20.0))
    links.new(density, vol.inputs["Density"])
    links.new(vol.outputs["Volume"], out.inputs["Volume"])
    return mat


def _render_frames(name, frames, px, setup):
    """Renders `frames` frames (setup(k, nodes, obj) sets each) into an 8-bit RGBA list."""
    scene = bpy.context.scene
    path = os.path.join(bpy.app.tempdir, f"{name}_frame.png")
    out = []
    for k in range(frames):
        setup(k)
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(path)
        a = np.array(img.pixels[:], dtype=np.float32).reshape(px, px, 4)[::-1]
        bpy.data.images.remove(img)
        out.append(a)
        print(f"[vfx volumes] {name} {k + 1}/{frames}")
    return out


def smoke_puff(name="VfxSmoke", grid=8, px=128, seed=3.7):
    """A puff of smoke's whole life (8 x 8): it bursts out from a point, billows and thins away."""
    scene = _scene(px)
    bpy.ops.mesh.primitive_cube_add(size=2.0)
    obj = bpy.context.active_object
    mat = _puff_material(name)
    obj.data.materials.append(mat)
    nodes = mat.node_tree.nodes
    n = grid * grid

    def setup(k):
        life = k / (n - 1)
        grow = 1 - (1 - life) ** 2.4
        nodes["Radius"].outputs[0].default_value = 0.2 + 0.46 * grow
        nodes["Amp"].outputs[0].default_value = 0.6 + 0.3 * grow
        # (thinning away softly: in game the old hard-edged holes read as dark cauliflower, 2026-10-25; and a dense
        # ball with a crisp rim read as a soap bubble once it was see-through: a wide soft edge and a thinner body, so
        # a puff is wisps at its rim and denser only in its heart)
        nodes["Erode"].outputs[0].default_value = 1.6 * life ** 1.6
        nodes["Soft"].outputs[0].default_value = 0.26 + 0.3 * life
        nodes["Strength"].outputs[0].default_value = 10.0 * (1 - life) ** 2.2 + 0.25
        nodes["Lumps"].inputs["W"].default_value = seed + life * 0.9
        nodes["Eat"].inputs["W"].default_value = seed * 2 + life * 1.4
        obj.location = (0, 0, 0.1 * life)

    frames = _render_frames(name, n, px, setup)
    img = D.sheet(frames, grid)
    # the colour is the lit smoke's light; un-premultiply what Cycles gave, then bleed into the clear
    a = img[..., 3:4]
    img[..., :3] = np.clip(img[..., :3] / np.maximum(a, 1e-4), 0, 1)
    del scene
    return D.bleed(calm_rims(img))


def calm_rims(img, grid=8):
    """The thin rim of a puff is backlit brighter than its self-shadowed middle, and once the game makes the smoke
    see-through that bright ring is all that shows: it read as soap bubbles (2026-10-25). Each frame's thin parts take
    the colour of its own thick middle, and the light and shade inside it are softened."""
    out = img.copy()
    h, w = img.shape[0] // grid, img.shape[1] // grid
    for r in range(grid):
        for c in range(grid):
            cell = out[r * h:(r + 1) * h, c * w:(c + 1) * w]
            a = cell[..., 3]
            thick = a > 0.45
            middle = cell[..., :3][thick].mean(axis=0) if thick.any() else np.full(3, 0.7)
            k = np.clip((a - 0.4) / 0.5, 0, 1)
            k = (k * k * (3 - 2 * k))[..., None]
            rgb = cell[..., :3] * k + middle * (1 - k)
            cell[..., :3] = middle + (rgb - middle) * 0.3
    return out


def build(names=None):
    makers = {"VfxSmoke": smoke_puff}
    paths = []
    for name, make in makers.items():
        if names and name not in names:
            continue
        img = make()
        path = D.write_png(os.path.join(TEXTURES, name + ".png"), img)
        print("[vfx volumes] wrote", path)
        paths.append(path)
    return paths


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    build(argv or None)
