"""Effect textures, rendered in Blender as white shapes on a transparent background so the game
can tint them (ParticleEmitter.Color, Decal.Color3): ink splats and drops (made from metaballs,
seen from above), a rain streak, a smoke puff, a soul glow, a spark, a snowflake, a shoe's print
in snow, and Tokyo's rain streak, splash and cherry petal (carried in the Tokyo map's own FBX).

    blender -b --factory-startup --python art/scripts/run_textures.py
"""

import math
import os
import random

import bpy
import numpy as np

import common

SIZE = 512


def _scene_for_texture(size):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
    cam_data = bpy.data.cameras.new("TexCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.0
    cam = bpy.data.objects.new("TexCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (0, 0, 5)
    scene.camera = cam
    return scene


def _white():
    mat = bpy.data.materials.get("TexWhite") or bpy.data.materials.new("TexWhite")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (1, 1, 1, 1)
    emit.inputs["Strength"].default_value = 1.0
    out = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(emit.outputs[0], out.inputs[0])
    return mat


def _clear():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def _metaballs(name, balls):
    data = bpy.data.metaballs.new(name)
    data.resolution = 0.02
    data.render_resolution = 0.01
    data.threshold = 0.6
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    for x, y, r in balls:
        el = data.elements.new()
        el.co = (x, y, 0)
        el.radius = r
    data.materials.append(_white())
    return obj


def splat_balls(seed):
    """A central blob, lumpy edges, flung droplets and a few streaks."""
    rng = random.Random(seed)
    balls = [(0, 0, 0.42)]
    for _ in range(14):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.18, 0.4)
        balls.append((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.14, 0.26)))
    for _ in range(9):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.5, 0.85)
        balls.append((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.03, 0.08)))
    for _ in range(4):
        a = rng.uniform(0, math.tau)
        for step in range(5):
            d = 0.3 + step * 0.1
            balls.append((math.cos(a) * d, math.sin(a) * d, 0.09 - step * 0.012))
    return balls


def drop_balls():
    balls = [(0, -0.35, 0.36)]
    for i in range(10):
        y = -0.3 + i * 0.09
        balls.append((0, y, 0.3 - i * 0.027))
    return balls


def render_to(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def save_array(name, rgba):
    """Writes an (h, w, 4) float array (top row first) as a PNG."""
    h, w, _ = rgba.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    img.pixels = np.flipud(rgba).ravel()
    path = os.path.join(common.TEXTURES, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return path


def rain_streak(h=256, w=32):
    y = np.linspace(0, 1, h)[:, None]
    x = np.linspace(-1, 1, w)[None, :]
    core = np.exp(-(x**2) / 0.05)
    fade = np.clip(np.sin(y * math.pi) ** 0.7, 0, 1)
    alpha = core * fade * 0.9
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("RainStreak", rgba)


def smoke(size=256, seed=2):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[-1 : 1 : size * 1j, -1 : 1 : size * 1j]
    r = np.sqrt(x**2 + y**2)
    base = np.clip(1 - r, 0, 1) ** 1.6
    noise = np.zeros_like(base)
    for octave in range(4):
        freq = 4 * 2**octave
        grid = rng.random((freq + 1, freq + 1))
        gx = np.linspace(0, freq, size)
        xi = np.clip(gx.astype(int), 0, freq - 1)
        fx = gx - xi
        a = grid[xi][:, xi]
        b = grid[xi + 1][:, xi]
        c = grid[xi][:, xi + 1]
        d = grid[xi + 1][:, xi + 1]
        fy = fx[:, None]
        fxx = fx[None, :]
        layer = a * (1 - fy) * (1 - fxx) + b * fy * (1 - fxx) + c * (1 - fy) * fxx + d * fy * fxx
        noise += layer / (2**octave)
    noise = noise / noise.max()
    alpha = np.clip(base * (0.55 + 0.6 * noise), 0, 1)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("Smoke", rgba)


def soul_glow(size=256):
    y, x = np.mgrid[-1 : 1 : size * 1j, -1 : 1 : size * 1j]
    r = np.sqrt(x**2 + y**2)
    glow = np.exp(-(r**2) / 0.08) + 0.35 * np.exp(-(r**2) / 0.5)
    cross = np.exp(-(x**2) / 0.002) * np.exp(-(y**2) / 0.25) + np.exp(-(y**2) / 0.002) * np.exp(-(x**2) / 0.25)
    alpha = np.clip(glow + 0.6 * cross, 0, 1)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("SoulGlow", rgba)


def spark(size=128):
    y, x = np.mgrid[-1 : 1 : size * 1j, -1 : 1 : size * 1j]
    star = np.exp(-np.abs(x) * 18) * np.exp(-np.abs(y) * 3) + np.exp(-np.abs(y) * 18) * np.exp(-np.abs(x) * 3)
    core = np.exp(-(x**2 + y**2) / 0.01)
    alpha = np.clip(star + core, 0, 1)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("Spark", rgba)


def snowflake(size=64):
    """A soft flake: a bright core in a fuzzy halo (it falls too small for arms to show)."""
    y, x = np.mgrid[-1 : 1 : size * 1j, -1 : 1 : size * 1j]
    r = np.sqrt(x**2 + y**2)
    alpha = np.clip(np.exp(-(r**2) / 0.12) + 0.25 * np.exp(-(r**2) / 0.45), 0, 1) * np.clip((1 - r) * 4, 0, 1)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("Snowflake", rgba)


def footprint(h=256, w=128):
    """A shoe's print pressed into snow, toe up: the sole and the heel, the tread across them,
    soft at the edges. White, so the game tints it (FootprintController)."""
    y, x = np.mgrid[0 : 1 : h * 1j, -1 : 1 : w * 1j]
    # The sole: an oval over the front two thirds, a little wider at the ball of the foot.
    sole = ((x + 0.05) / 0.78) ** 2 + ((y - 0.32) / 0.3) ** 2
    heel = (x / 0.62) ** 2 + ((y - 0.8) / 0.16) ** 2
    shape = np.clip((1 - np.minimum(sole, heel)) * 6, 0, 1)
    tread = 0.75 + 0.25 * (np.sin(y * 70) > 0)
    alpha = shape * tread * 0.9
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("Footprint", rgba)


def tokyo_rain(h=256, w=16):
    """A falling drop's streak for Tokyo's rain: thin, bright at its head (the bottom, where it
    falls to), fading up its tail. White: the game tints it."""
    y = np.linspace(0, 1, h)[:, None]  # 0 at the top of the image (the tail)
    x = np.linspace(-1, 1, w)[None, :]
    core = np.exp(-(x**2) / 0.15)
    body = np.clip(y ** 1.3, 0, 1) * np.clip((1 - y) * 12, 0, 1)
    head = np.exp(-((y - 0.9) ** 2) / 0.002) * 0.75
    alpha = np.clip(core * (body * 0.95 + head), 0, 1)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("TokyoRain", rgba)


def tokyo_splash(size=128):
    """A drop landing, seen from above: a thin ring with a few droplets thrown round it and a
    faint centre. Laid flat on the ground by the emitter, it grows and fades."""
    y, x = np.mgrid[-1 : 1 : size * 1j, -1 : 1 : size * 1j]
    r = np.sqrt(x**2 + y**2)
    a = np.arctan2(y, x)
    ring = np.exp(-((r - 0.6) ** 2) / 0.006) * (0.8 + 0.2 * np.cos(a * 7))
    drops = np.zeros_like(r)
    for k in range(13):
        ang = k * 2.39996
        rad = 0.78 + 0.1 * np.sin(k * 1.7)
        dx, dy = rad * np.cos(ang), rad * np.sin(ang)
        drops += np.exp(-((x - dx) ** 2 + (y - dy) ** 2) / 0.002)
    centre = np.exp(-(r**2) / 0.06) * 0.3
    alpha = np.clip(ring + drops * 0.8 + centre, 0, 1) * np.clip((1 - r) * 6, 0, 1)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("TokyoSplash", rgba)


def tokyo_petal(size=128):
    """A cherry petal: a rounded teardrop with the notch at its tip, a little darker at its base.
    White and grey only (the game tints it pink)."""
    y, x = np.mgrid[-1 : 1 : size * 1j, -1 : 1 : size * 1j]
    # Base at the bottom (y = 1), the notched tip at the top.
    u = x / (0.46 + 0.22 * (1 - y) * 0.5)
    v = y
    shape = (u**2 + (v * 0.92) ** 2) < 0.72
    notch = (np.abs(x) < 0.12 * np.clip((-0.62 - y) / 0.25, 0, 1) + 0.001) & (y < -0.45)
    body = shape & ~notch
    edge = np.clip((0.72 - (u**2 + (v * 0.92) ** 2)) * 8, 0, 1)
    shade = 0.82 + 0.18 * np.clip(-y, 0, 1)
    alpha = edge * body
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., 0] = shade
    rgba[..., 1] = shade
    rgba[..., 2] = shade
    rgba[..., 3] = alpha
    return save_array("TokyoPetal", rgba)


def campus_flake(size=128):
    """A crisp little snow crystal for the campus: six fine arms and a bright core in a soft halo,
    so it still reads as a flake a few studs away. White: the game tints it."""
    y, x = np.mgrid[-1 : 1 : size * 1j, -1 : 1 : size * 1j]
    r = np.sqrt(x**2 + y**2)
    arms = np.zeros_like(r)
    for k in range(6):
        a = k * math.pi / 3
        along = x * math.cos(a) + y * math.sin(a)
        across = -x * math.sin(a) + y * math.cos(a)
        spine = np.exp(-(across**2) / 0.0016) * np.clip(1 - np.abs(along) / 0.8, 0, 1)
        # A pair of short side branches on each arm.
        for at in (0.35, 0.58):
            for side in (-1, 1):
                bx = (along - np.sign(along) * at) if False else (np.abs(along) - at)
                branch = np.exp(-((across - side * (np.abs(along) - at) * 0.9) ** 2) / 0.0012) * np.clip(
                    1 - np.abs(np.abs(along) - at) / 0.16, 0, 1
                )
                arms += 0.55 * branch * (np.abs(along) > at)
        arms += spine
    core = np.exp(-(r**2) / 0.02)
    halo = 0.3 * np.exp(-(r**2) / 0.25)
    alpha = np.clip(arms * 0.85 + core + halo, 0, 1) * np.clip((1 - r) * 5, 0, 1)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("CampusFlake", rgba)


def feather(h=256, w=128):
    """One black feather (the game colours it): a curved quill, an uneven vane that swells and tapers
    with a ragged edge and slanting barbs, drawn with its tip at the top. White on transparent."""
    y, x = np.mgrid[-1 : 1 : h * 1j, -1 : 1 : w * 1j]
    # The quill bends to one side; the vane is wider on the other side of it and widest low down.
    bend = 0.3 * y**2 - 0.06 * y
    across = x - bend
    t = np.clip((y + 0.8) / 1.55, 0, 1)  # 0 at the base of the vane, 1 at the tip
    swell = np.sin(np.pi * t**0.7) ** 0.85
    width = np.where(across < 0, 0.5, 0.3) * swell
    # Ragged edge: the vane's outline is nibbled into barbs.
    ragged = 0.04 * np.sin(y * 70 + (across < 0) * 1.7) * np.clip(np.abs(across) / 0.2, 0, 1)
    inside = (np.abs(across) < width + ragged) & (y > -0.8) & (y < 0.78)
    edge = np.clip((width + ragged - np.abs(across)) * 16, 0, 1) * inside
    # Barbs slant back from the quill, with a few slits between them.
    barbs = 0.7 + 0.3 * np.sin(y * 52 - np.abs(across) * 26 * np.sign(across))
    slits = 1 - 0.55 * (np.sin(y * 31 + across * 9) > 0.93)
    vane = edge * barbs * slits
    quill = np.exp(-(across**2) / 0.0007) * (y > -0.99) * (y < 0.8)
    alpha = np.clip(np.maximum(vane, quill), 0, 1)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., 3] = alpha
    return save_array("Feather", rgba)


TOKYO = (tokyo_rain, tokyo_splash, tokyo_petal)
CAMPUS = (campus_flake, feather)


def build_only(groups):
    """Writes only some textures ("Tokyo", "Campus"), without rendering the rest again."""
    common.ensure_dirs()
    paths = []
    for name in groups:
        paths.extend(make() for make in {"Tokyo": TOKYO, "Campus": CAMPUS}[name])
    return paths


def build():
    common.ensure_dirs()
    _clear()
    _scene_for_texture(SIZE)
    paths = []
    for i, seed in enumerate((3, 17, 29)):
        obj = _metaballs(f"Splat{i}", splat_balls(seed))
        paths.append(render_to(os.path.join(common.TEXTURES, f"InkSplat{i + 1}.png")))
        bpy.data.objects.remove(obj, do_unlink=True)
    obj = _metaballs("Drop", drop_balls())
    paths.append(render_to(os.path.join(common.TEXTURES, "InkDrop.png")))
    bpy.data.objects.remove(obj, do_unlink=True)
    paths.append(rain_streak())
    paths.append(smoke())
    paths.append(soul_glow())
    paths.append(spark())
    paths.append(snowflake())
    paths.append(footprint())
    paths.extend(make() for make in TOKYO)
    paths.extend(make() for make in CAMPUS)
    return paths
