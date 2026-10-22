"""Effect textures, rendered in Blender as white shapes on a transparent background so the game
can tint them (ParticleEmitter.Color, Decal.Color3): a rain streak, a smoke puff, a soul glow, a
spark, a snowflake, a shoe's print in snow, and Tokyo's rain streak, splash and cherry petal (carried in the Tokyo map's own FBX).

    blender -b --factory-startup --python art/scripts/run_textures.py
"""

import math
import os

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


def _clear():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


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


# Nah, I'd Win's speech bubble (the owner's reference of 2026-10-22: a manga balloon drawn by hand, a little
# lopsided, a short tail down to the left, the line lettered in three rows of italic brush capitals). Drawn
# here, not copied: the outline and every letter are brush strokes laid out as in the reference (420 px wide).
SPEECH_OUTLINE = [(80, 80), (225, 19), (340, 114), (344, 128), (343, 200), (341, 283), (296, 348), (212, 363),
                  (162, 404), (172, 352), (76, 300), (73, 200)]
# Each stroke: points (x, y, width), the brush swelling and thinning along it.
SPEECH_LETTERS = [
    # NAH,
    [(153, 111, 7), (147, 135, 9.5), (142, 158, 8.5)],
    [(151, 113, 8), (160, 135, 9.5), (169, 157, 8.5)],
    [(180, 106, 7), (175, 132, 9.5), (169, 157, 8)],
    [(214, 108, 6), (200, 133, 9.5), (187, 158, 8.5)],
    [(214, 108, 6), (216, 133, 9.5), (217, 158, 8.5)],
    [(192, 147, 7), (205, 146, 8.5), (217, 145, 7)],
    [(241, 112, 8), (236, 135, 9.5), (232, 158, 8.5)],
    [(265, 108, 8), (260, 133, 9.5), (256, 158, 8.5)],
    [(236, 137, 7), (249, 137, 8.5), (262, 136, 7)],
    [(281, 149, 10), (277, 158, 8), (272, 169, 3.5)],
    # I'D
    [(208, 167, 8), (203, 179, 6.5), (197, 190, 3.5)],
    [(155, 187, 4), (164, 179, 10), (180, 174, 10.5), (196, 173, 5)],
    [(174, 185, 9), (171, 199, 9.5), (167, 213, 9)],
    [(146, 222, 4), (159, 218, 10.5), (175, 215, 9.5), (188, 214, 4)],
    [(225, 183, 8.5), (221, 202, 9.5), (217, 222, 8.5)],
    [(218, 185, 5), (225, 178, 9), (240, 174, 10), (254, 177, 9.5), (256, 187, 9), (250, 199, 9.5),
     (239, 210, 9.5), (228, 218, 9), (217, 222, 7)],
    # WIN.
    [(143, 238, 8.5), (139, 262, 9.5), (134, 286, 9)],
    [(134, 286, 8), (146, 267, 9), (158, 249, 7)],
    [(158, 249, 7), (162, 267, 9), (167, 285, 9)],
    [(167, 285, 8), (172, 260, 9.5), (177, 235, 8.5)],
    [(189, 247, 4), (199, 240, 10), (215, 237, 10.5), (229, 235, 5)],
    [(203, 247, 9), (201, 262, 9.5), (199, 277, 9)],
    [(180, 287, 4), (192, 282, 10.5), (208, 279, 9.5), (222, 278, 4)],
    [(242, 238, 8.5), (238, 262, 9.5), (233, 286, 9)],
    [(241, 240, 8.5), (249, 261, 9.5), (257, 282, 9)],
    [(269, 232, 8), (265, 257, 9.5), (262, 281, 8.5)],
    [(282, 278, 11), (288, 282, 10)],
]


def _segment_distance(px, py, ax, ay, bx, by):
    """Distance from each pixel to the segment a-b, and how far along it (0..1) the nearest point is."""
    dx, dy = bx - ax, by - ay
    length2 = max(dx * dx + dy * dy, 1e-9)
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / length2, 0.0, 1.0)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy)), t


def _stroke(mask, px, py, points, scale, wobble=0.0, seed=0):
    """Paints a brush stroke through points (x, y, width) into mask (True where it lies)."""
    rng = np.random.default_rng(seed)
    for (ax, ay, aw), (bx, by, bw) in zip(points, points[1:]):
        d, t = _segment_distance(px, py, ax * scale, ay * scale, bx * scale, by * scale)
        half = (aw + (bw - aw) * t) * scale / 2
        if wobble:
            half = half * (1 + wobble * np.sin(t * math.pi * rng.uniform(2, 5) + rng.uniform(0, 6)))
        mask |= d <= half


def _inside(px, py, polygon):
    """Even-odd: which pixels lie inside the polygon."""
    inside = np.zeros(px.shape, dtype=bool)
    n = len(polygon)
    for k in range(n):
        (ax, ay), (bx, by) = polygon[k], polygon[(k + 1) % n]
        crosses = ((ay > py) != (by > py)) & (px < (bx - ax) * (py - ay) / ((by - ay) + 1e-12) + ax)
        inside ^= crosses
    return inside


def speech_nah(size=512, over=2):
    """Nah, I'd Win's speech bubble: white inside a black hand-drawn edge, the three rows of lettering, the rest
    clear (drawn `over` times bigger, then averaged down, for soft edges)."""
    big = size * over
    scale = big / 420
    py, px = np.mgrid[0:big, 0:big].astype(np.float32) + 0.5
    # the edge's middle line runs 3 px (of the reference's) inside the outer edge it was measured by
    cx = sum(x for x, _ in SPEECH_OUTLINE) / len(SPEECH_OUTLINE)
    cy = sum(y for _, y in SPEECH_OUTLINE) / len(SPEECH_OUTLINE)
    middle = []
    for x, y in SPEECH_OUTLINE:
        d = math.hypot(x - cx, y - cy)
        middle.append(((x - (x - cx) / d * 3) * scale, (y - (y - cy) / d * 3) * scale))
    fill = _inside(px, py, middle)
    edge = np.zeros(px.shape, dtype=bool)
    closed = SPEECH_OUTLINE + SPEECH_OUTLINE[:1]
    for k, ((ax, ay), (bx, by)) in enumerate(zip(closed, closed[1:])):
        _stroke(edge, px, py, [(ax, ay, 5.8), (bx, by, 5.8)], scale, wobble=0.07, seed=k)
    letters = np.zeros(px.shape, dtype=bool)
    for k, points in enumerate(SPEECH_LETTERS):
        _stroke(letters, px, py, points, scale, wobble=0.06, seed=100 + k)
    alpha = (fill | edge).astype(np.float32)
    white = (fill & ~edge & ~letters).astype(np.float32)
    # averaged down: coverage for the alpha, the shade where there is any
    alpha = alpha.reshape(size, over, size, over).mean(axis=(1, 3))
    shade = white.reshape(size, over, size, over).mean(axis=(1, 3)) / np.maximum(alpha, 1e-6)
    rgba = np.zeros((size, size, 4), dtype=np.float32)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = np.clip(shade, 0, 1) * 0.98
    rgba[..., 3] = alpha
    return save_array("SpeechNah", rgba)


SPEECH = (speech_nah,)


def fx_puff(cell=128, grid=4, seed=11):
    """The FX kit's hard-edged puff (the owner's tutorial: a noise cut into hard steps): a 4 x 4 flipbook of a round
    puff of smoothed noise whose threshold rises frame by frame, so it breaks up and is eaten away with sharp edges,
    a darker rim inside each edge. White (the game tints it)."""
    rng = np.random.default_rng(seed)

    def smooth(n):
        """A grid of n x n random values blown up to the cell with smoothstep blends."""
        values = rng.random((n + 1, n + 1))
        t = np.linspace(0, n, cell)
        i0 = np.clip(np.floor(t).astype(int), 0, n - 1)
        f = t - i0
        f = f * f * (3 - 2 * f)
        fy, fx = f[:, None], f[None, :]
        a, b = values[i0][:, i0], values[i0 + 1][:, i0]
        c, d = values[i0][:, i0 + 1], values[i0 + 1][:, i0 + 1]
        return a * (1 - fy) * (1 - fx) + b * fy * (1 - fx) + c * (1 - fy) * fx + d * fy * fx

    noise = 0.7 * smooth(8) + 0.3 * smooth(16)
    y, x = np.mgrid[0:cell, 0:cell] / (cell - 1) * 2 - 1
    radial = np.clip(1 - np.sqrt(x * x + y * y), 0, 1)
    field = (radial * 0.75 + noise * 0.45) * np.clip(radial * 3, 0, 1)  # (nothing reaches the cell's edge)
    sheet = np.zeros((cell * grid, cell * grid, 4), dtype=np.float32)
    frames = grid * grid
    for k in range(frames):
        cut = 0.25 + 0.6 * (k / (frames - 1)) ** 1.2
        solid = field > cut
        rim = solid & (field < cut + 0.05)
        shade = np.where(rim, 0.72, 1.0)
        cell_rgba = np.zeros((cell, cell, 4), dtype=np.float32)
        cell_rgba[..., 0] = cell_rgba[..., 1] = cell_rgba[..., 2] = shade
        cell_rgba[..., 3] = solid.astype(np.float32)
        r, c = divmod(k, grid)
        sheet[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell] = cell_rgba
    return save_array("FxPuff", sheet)


FX_KIT = (fx_puff,)


TOKYO = (tokyo_rain, tokyo_splash, tokyo_petal)
CAMPUS = (campus_flake, feather)


def build_only(groups):
    """Writes only some textures ("Tokyo", "Campus", "Speech", "Fx"), without rendering the rest again."""
    common.ensure_dirs()
    paths = []
    for name in groups:
        paths.extend(make() for make in {"Tokyo": TOKYO, "Campus": CAMPUS, "Speech": SPEECH, "Fx": FX_KIT}[name])
    return paths


def build():
    common.ensure_dirs()
    _clear()
    _scene_for_texture(SIZE)
    paths = []
    paths.append(rain_streak())
    paths.append(speech_nah())
    paths.append(fx_puff())
    paths.append(smoke())
    paths.append(soul_glow())
    paths.append(spark())
    paths.append(snowflake())
    paths.append(footprint())
    paths.extend(make() for make in TOKYO)
    paths.extend(make() for make in CAMPUS)
    return paths
