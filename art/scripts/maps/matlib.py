"""Map materials: tiling textured materials (colour, normal and roughness maps from texlib) and
flat materials that the game colours at runtime (metal trims, glass, neon, screens).

Textured materials keep their texture after import (a SurfaceAppearance or TextureID on the
MeshPart). Flat materials are listed in src/shared/SceneMaterials.luau with the Roblox colour,
material, transparency and reflectance the game gives them. Textured ones get a fallback there
too (a Roblox material and the texture's average colour), which the game uses when an imported
texture fails to load.
"""

import os

import bpy
import numpy as np

import common
from maps import texlib

TEX_DIR = os.path.join(common.EXPORT, "textures", "maps")

# name -> (Roblox material, sRGB colour, transparency, reflectance)
FLAT = {
    "BlackMetal": ("Metal", (26, 26, 30), 0, 0),
    "DarkMetal": ("Metal", (58, 60, 66), 0, 0),
    "Steel": ("Metal", (150, 152, 158), 0, 0),
    "Brass": ("Metal", (176, 140, 72), 0, 0.05),
    "Gold": ("Metal", (214, 176, 96), 0, 0.1),
    "WhiteTrim": ("SmoothPlastic", (218, 214, 204), 0, 0),
    "CreamTrim": ("SmoothPlastic", (196, 184, 160), 0, 0),
    "BlackTrim": ("SmoothPlastic", (20, 20, 24), 0, 0),
    "RedTrim": ("SmoothPlastic", (150, 22, 32), 0, 0),
    "PaintYellow": ("SmoothPlastic", (222, 190, 60), 0, 0),
    "Rubber": ("SmoothPlastic", (30, 30, 32), 0, 0),
    "Glass": ("Glass", (150, 180, 210), 0.6, 0.2),
    "GlassDark": ("Glass", (40, 52, 66), 0.35, 0.25),
    "Water": ("Glass", (40, 90, 120), 0.35, 0.3),
    "Puddle": ("Glass", (16, 16, 22), 0.15, 0.35),
    "Screen": ("SmoothPlastic", (14, 16, 22), 0, 0.1),
    "Paper": ("SmoothPlastic", (226, 220, 205), 0, 0),
    "Fabric": ("Fabric", (40, 40, 46), 0, 0),
    "FabricRed": ("Fabric", (120, 24, 30), 0, 0),
    "Leather": ("Leather", (40, 26, 22), 0, 0),
    "Wood": ("Wood", (86, 58, 38), 0, 0),
    "Foliage": ("Grass", (44, 74, 40), 0, 0),
    "Bark": ("Wood", (60, 44, 34), 0, 0),
    "NeonWarm": ("Neon", (255, 214, 160), 0, 0),
    "NeonCool": ("Neon", (200, 225, 255), 0, 0),
    # A fluorescent fitting's diffuser: it reads as lit without blooming (see kit.tube_light).
    "TubeDiffuser": ("Neon", (150, 158, 170), 0, 0),
    # Frosted ceiling panels in rooms people walk into: lit, but too dim to bloom.
    "PanelWarm": ("Neon", (156, 138, 112), 0, 0),
    "PanelCool": ("Neon", (130, 140, 156), 0, 0),
    "NeonRed": ("Neon", (255, 40, 60), 0, 0),
    "NeonPink": ("Neon", (255, 80, 200), 0, 0),
    "NeonCyan": ("Neon", (60, 230, 255), 0, 0),
    "NeonGreen": ("Neon", (100, 255, 140), 0, 0),
    "NeonYellow": ("Neon", (255, 220, 70), 0, 0),
    "NeonBlue": ("Neon", (80, 150, 255), 0, 0),
    "NeonOrange": ("Neon", (255, 130, 50), 0, 0),
    # Windows seen from the street: opaque, so nothing behind them ever shows (the low floors have
    # rooms behind clear glass instead, see buildings.window).
    "WindowLit": ("Neon", (255, 208, 140), 0, 0),
    "WindowCool": ("Neon", (150, 180, 230), 0, 0),
    "WindowDark": ("Glass", (22, 26, 34), 0, 0.35),
    "WindowGlass": ("Glass", (70, 80, 96), 0.55, 0.3),
    # Agency HQ: the tower's floor-to-ceiling glass (clear enough to see the city far below), frosted
    # office glass and the interrogation room's one-way mirror (dark, reflective).
    "CurtainGlass": ("Glass", (70, 82, 100), 0.72, 0.12),
    "GlassFrosted": ("Glass", (196, 204, 212), 0.2, 0.05),
    "MirrorGlass": ("Glass", (30, 34, 40), 0.25, 0.6),
    # The city seen from high up (Agency HQ's windows): flat, cheap, dark.
    "CityFacade": ("SmoothPlastic", (40, 42, 52), 0, 0),
    "CityFacadeWarm": ("SmoothPlastic", (54, 48, 46), 0, 0),
    "CityGround": ("SmoothPlastic", (24, 24, 28), 0, 0),
    "CityRoad": ("SmoothPlastic", (15, 15, 19), 0, 0),
    "CityRoof": ("SmoothPlastic", (31, 32, 38), 0, 0),
    # The shallow rooms behind the low windows and in shop windows: a lit room's walls glow
    # softly (nothing lights them at night), a dark room is just dark.
    "RoomLitBack": ("Neon", (150, 118, 84), 0, 0),
    "RoomLitSide": ("Neon", (108, 84, 60), 0, 0),
    "RoomLitCeiling": ("Neon", (186, 156, 118), 0, 0),
    "RoomCoolBack": ("Neon", (86, 102, 132), 0, 0),
    "RoomCoolSide": ("Neon", (62, 74, 98), 0, 0),
    "RoomCoolCeiling": ("Neon", (120, 138, 170), 0, 0),
    "RoomDark": ("SmoothPlastic", (18, 18, 22), 0, 0),
    "CoreDark": ("SmoothPlastic", (14, 15, 18), 0, 0),
    # Massing: plain blocks at true height, for reviewing a layout before its buildings are made.
    "MassLight": ("SmoothPlastic", (208, 204, 196), 0, 0),
    "MassMid": ("SmoothPlastic", (168, 166, 162), 0, 0),
    "MassWarm": ("SmoothPlastic", (214, 190, 156), 0, 0),
    "MassGlass": ("SmoothPlastic", (128, 146, 166), 0, 0),
    "MassBand": ("SmoothPlastic", (92, 92, 96), 0, 0),
    "MassEnter": ("Neon", (255, 196, 110), 0, 0),
    "MassClosed": ("SmoothPlastic", (64, 64, 70), 0, 0),
}


# Textured material name fragment -> the Roblox material closest to it (first match wins).
FALLBACK_KIND = [
    ("MetalFloor", "DiamondPlate"),
    ("Shutter", "CorrodedMetal"),
    ("Marble", "Marble"),
    ("Wood", "WoodPlanks"),
    ("Carpet", "Fabric"),
    ("Wallpaper", "Fabric"),
    ("Tile", "Slate"),
    ("Concrete", "Concrete"),
    ("Plaster", "Plaster"),
    ("Ceiling", "Plaster"),
    ("Brick", "Brick"),
    ("Stone", "Cobblestone"),
    ("Asphalt", "Asphalt"),
    ("Pavers", "Pavement"),
    ("Grass", "Grass"),
    ("Hedge", "LeafyGrass"),
    ("Slate", "Slate"),
    ("Dirt", "Ground"),
]


def fallback_look(name):
    """(Roblox material, sRGB colour) for a textured material whose texture did not load: the
    closest Roblox material and the average colour of its colour map."""
    kind = next((k for key, k in FALLBACK_KIND if key in name), "SmoothPlastic")
    path = os.path.join(TEX_DIR, f"{name}_color.jpg")
    rgb = (128, 128, 128)
    if os.path.exists(path):
        img = bpy.data.images.load(path, check_existing=True)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, img.channels)[:, :3]
        mean = px.mean(axis=0)
        rgb = tuple(int(round(float(c) * 255)) for c in mean)
    return kind, rgb


def tile_size(name):
    """Studs covered by one repeat of a textured material (1 for flat materials)."""
    if name in texlib.LIBRARY:
        return texlib.LIBRARY[name][1]
    return 4.0


def is_flat(name):
    return name in FLAT


def _save(name, array, non_color, size=None, quality=90):
    """Saves a map as JPEG (much smaller than PNG for noisy textures, which keeps the FBX light)."""
    h, w = array.shape[:2]
    img = bpy.data.images.get(name) or bpy.data.images.new(name, w, h, alpha=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    if array.ndim == 2:
        array = np.stack([array, array, array], axis=-1)
    rgba = np.concatenate([array, np.ones((h, w, 1))], axis=-1).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    if size and size != w:
        img.scale(size, size)
    path = os.path.join(TEX_DIR, name + ".jpg")
    img.filepath_raw = path
    img.file_format = "JPEG"
    img.save(filepath=path, quality=quality)
    img.filepath = path
    return img


def make_textures(names=None, force=False):
    """Draws the textures (skipping ones already on disk unless force) and returns
    {material: {"color": image, "normal": image, "rough": image}}."""
    os.makedirs(TEX_DIR, exist_ok=True)
    out = {}
    for name, (generator, _) in texlib.LIBRARY.items():
        if names and name not in names:
            continue
        paths = {kind: os.path.join(TEX_DIR, f"{name}_{kind}.jpg") for kind in ("color", "normal", "rough")}
        if not force and all(os.path.exists(p) for p in paths.values()):
            images = {}
            for kind, path in paths.items():
                img = bpy.data.images.load(path, check_existing=True)
                if kind != "color":
                    img.colorspace_settings.name = "Non-Color"
                images[kind] = img
            out[name] = images
            continue
        maps = generator()
        out[name] = {
            "color": _save(f"{name}_color", maps["color"], False, quality=90),
            "normal": _save(f"{name}_normal", maps["normal"], True, quality=94),
            "rough": _save(f"{name}_rough", maps["rough"], True, size=512, quality=88),
        }
        print("[maps] texture", name)
    return out


def material(name, images=None):
    """The Blender material for a map material (textured or flat)."""
    mat = bpy.data.materials.get("M_" + name)
    if mat:
        return mat
    mat = bpy.data.materials.new("M_" + name)
    mat.use_nodes = True
    mat.use_backface_culling = True  # Roblox draws only the front of mesh faces
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    if name in FLAT:
        kind, rgb, alpha, _ = FLAT[name]
        color = common.srgb(*rgb)
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        bsdf.inputs["Roughness"].default_value = 0.3 if kind in ("Metal", "Glass") else 0.6
        bsdf.inputs["Metallic"].default_value = 0.9 if kind == "Metal" else 0.0
        if kind == "Neon":
            bsdf.inputs["Emission Color"].default_value = (*color, 1)
            bsdf.inputs["Emission Strength"].default_value = 3.0
        if alpha > 0:
            bsdf.inputs["Alpha"].default_value = 1 - alpha
        mat.diffuse_color = (*color, 1)
        return mat
    tex = images[name]
    color = nodes.new("ShaderNodeTexImage")
    color.image = tex["color"]
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    rough = nodes.new("ShaderNodeTexImage")
    rough.image = tex["rough"]
    links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = tex["normal"]
    nmap = nodes.new("ShaderNodeNormalMap")
    links.new(normal.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def luau_table(used):
    """src/shared/SceneMaterials.luau: how the game dresses each flat material."""
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/maps/matlib.py. Map meshes are named Scene_<Venue>_<Material>_<n>.",
        "-- Textured materials keep the texture they were imported with (their fallback is used when",
        "-- the texture fails to load); the flat ones are coloured by the game: material, colour,",
        "-- transparency, reflectance.",
        "",
        "return {",
    ]
    for name in sorted(used):
        if name in FLAT:
            kind, rgb, alpha, refl = FLAT[name]
            lines.append(
                f'\t{name} = {{ material = "{kind}", color = {{ {rgb[0]}, {rgb[1]}, {rgb[2]} }}, '
                f"transparency = {alpha}, reflectance = {refl} }},"
            )
        else:
            kind, rgb = fallback_look(name)
            lines.append(
                f'\t{name} = {{ textured = true, fallback = {{ material = "{kind}", '
                f"color = {{ {rgb[0]}, {rgb[1]}, {rgb[2]} }} }} }},"
            )
    lines.append("}")
    return "\n".join(lines) + "\n"
