"""Builds, unwraps and bakes props, renders previews, and exports them for Roblox.

    build(keys)   -> builds the listed props (all when None) in the current file
    export()      -> writes art/export/InkboundModels.fbx and src/shared/ModelCatalog.luau
"""

import json
import os

import bpy
import numpy as np
from mathutils import Matrix

import common
import modelkit as mk
import props
from maps import export as maps_export

CATALOG = os.path.join(common.ROOT, "src", "shared", "ModelCatalog.luau")
FBX = os.path.join(common.EXPORT, "InkboundModels.fbx")

# Textures carried into Roblox on flat quads named "Tex_<name>" (see Assets.texture): effect
# textures, and the UI's lettering, paper and icons (art/scripts/ui).
EFFECT_TEXTURES = ["InkSplat1", "InkSplat2", "InkSplat3", "InkDrop", "RainStreak", "Smoke", "SoulGlow", "Spark"]
UI_TEXTURES = [
    "UiGothic1",
    "UiScrawl1",
    "UiPaper",
    "UiParchment",
    "UiTorn",
    "UiBrush",
    "UiSeal",
    "UiStamp",
    "UiScratches",
    "UiVignette",
    "UiRuled",
    "UiIcons",
]


def texture_carriers():
    """Small quads, one per effect texture, so importing the FBX also uploads the textures."""
    carriers = []
    for i, name in enumerate(EFFECT_TEXTURES + UI_TEXTURES):
        path = os.path.join(common.TEXTURES, name + ".png")
        if not os.path.exists(path):
            continue
        obj_name = "Tex_" + name
        _remove(obj_name)
        image = bpy.data.images.load(path, check_existing=True)
        mat = bpy.data.materials.get(obj_name) or bpy.data.materials.new(obj_name)
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes["Principled BSDF"]
        tex = nodes.get("Image") or nodes.new("ShaderNodeTexImage")
        tex.name = "Image"
        tex.image = image
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mesh = bpy.data.meshes.new(obj_name)
        s = 1.0
        mesh.from_pydata([(-s, 0, -s), (s, 0, -s), (s, 0, s), (-s, 0, s)], [], [(0, 1, 2, 3)])
        uv = mesh.uv_layers.new(name="UVMap")
        for loop, co in zip(uv.data, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop.uv = co
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(obj_name, mesh)
        common.collection("Textures").objects.link(obj)
        obj.location = (40 + (i % 4) * 3, 0, (i // 4) * 3)
        obj["inkbound_texture"] = True
        carriers.append(obj)
    return carriers


def _remove(name):
    obj = bpy.data.objects.get(name)
    if obj:
        bpy.data.objects.remove(obj, do_unlink=True)


def _glow_objects(key):
    """The glowing meshes of a prop: <key>_Glow, <key>_Glow2, ..."""
    found = []
    for obj in bpy.data.objects:
        name = obj.name
        if name == key + "_Glow" or (name.startswith(key + "_Glow") and name[len(key) + 5 :].isdigit()):
            found.append(obj)
    return sorted(found, key=lambda o: o.name)


def build_one(key):
    spec = props.BUILDERS[key]
    mk.new_build()
    _remove(key)
    for obj in _glow_objects(key):
        bpy.data.objects.remove(obj, do_unlink=True)
    parts, glow = spec["build"]()
    main = mk.merge(parts, key)
    shift = mk.ground(main) if spec["pivot"] == "bottom" else mk.centre(main)
    mk.unwrap(main)
    mk.bake(main, size=spec["texture"])
    # Glowing parts, one mesh per colour (each becomes a Neon MeshPart of that colour).
    by_colour = {}
    for part in glow:
        mat = part.data.materials[0]
        colour = tuple(round(c, 3) for c in mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value[:3])
        by_colour.setdefault(colour, []).append(part)
    glow_objs = []
    for i, (colour, group) in enumerate(by_colour.items()):
        obj = mk.merge(group, key + "_Glow" + ("" if i == 0 else str(i + 1)))
        # The glow moves with the main mesh, so it stays in place relative to it.
        obj.data.transform(Matrix.Translation(shift))
        obj["glow_colour"] = list(colour)
        glow_objs.append(obj)
    glow_obj = glow_objs[0] if glow_objs else None
    info = {
        "size": [round(v, 3) for v in mk.dimensions(main)],
        "tris": mk.triangles(main) + sum(mk.triangles(o) for o in glow_objs),
    }
    main["inkbound_prop"] = True
    main["pivot"] = spec["pivot"]
    main["material"] = spec["material"]
    main["collide"] = spec["collide"]
    return main, glow_obj, info


def build(keys=None):
    results = {}
    for key in keys or list(props.BUILDERS):
        _, _, info = build_one(key)
        results[key] = info
    for coll_name in ("Build",):
        coll = bpy.data.collections.get(coll_name)
        if coll:
            for obj in list(coll.objects):
                bpy.data.objects.remove(obj, do_unlink=True)
    return results


def preview(key, path=None, angle=35, height_factor=0.6):
    obj = bpy.data.objects[key]
    size = mk.dimensions(obj)
    radius = max(size) * 0.75 + 0.3
    target = (0, 0, size[2] / 2 if obj.get("pivot") == "bottom" else 0)
    for other in bpy.data.objects:
        other.hide_render = other.type == "MESH" and other.name not in (key, key + "_Glow")
    common.setup_preview(target=target, distance=radius * 2.6, height=radius * height_factor, angle_deg=angle)
    path = path or os.path.join(common.PREVIEWS, "prop_" + key + ".png")
    common.render(path)
    for other in bpy.data.objects:
        other.hide_render = False
    return path


def _lua_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return f"{value:.3f}".rstrip("0").rstrip(".")
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (list, tuple)):
        return "{ " + ", ".join(_lua_value(v) for v in value) + " }"
    raise TypeError(value)


def write_catalog():
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/build_props.py. Every prop in art/export/InkboundModels.fbx:",
        "-- its size in studs (x, y, z with y up), how it is placed (pivot), its Roblox material,",
        "-- whether it collides, and the colour of its glowing part (turned Neon), if any.",
        "",
        "return {",
    ]
    for obj in sorted((o for o in bpy.data.objects if o.get("inkbound_prop")), key=lambda o: o.name):
        size = mk.dimensions(obj)
        entry = {
            "size": [size[0], size[2], size[1]],
            "pivot": obj["pivot"],
            "material": obj["material"],
            "collide": bool(obj["collide"]),
        }
        text = ", ".join(f"{k} = {_lua_value(v)}" for k, v in entry.items())

        def to_srgb(x):
            return x * 12.92 if x <= 0.0031308 else 1.055 * (x ** (1 / 2.4)) - 0.055

        # The texture's average colour: the flat look used when the texture fails to load.
        tex = os.path.join(common.TEXTURES, obj.name + ".png")
        if os.path.exists(tex):
            img = bpy.data.images.load(tex, check_existing=True)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(-1, img.channels)
            opaque = px[px[:, 3] > 0.5] if img.channels == 4 else px
            if len(opaque):
                mean = opaque[:, :3].mean(axis=0)
                text += ", color = { " + ", ".join(str(int(round(float(c) * 255))) for c in mean) + " }"

        colours = []
        for g in _glow_objects(obj.name):
            if "glow_colour" in g:
                rgb = [round(to_srgb(v) * 255) for v in g["glow_colour"]]
                colours.append(f"{{ {rgb[0]}, {rgb[1]}, {rgb[2]} }}")
        if colours:
            text += ", glow = { " + ", ".join(colours) + " }"
        lines.append(f"\t{obj.name} = {{ {text} }},")
    lines.append("}")
    with open(CATALOG, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return CATALOG


def export():
    common.ensure_dirs()
    texture_carriers()
    bpy.context.view_layer.update()
    names = []
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in bpy.data.objects:
        is_glow = "glow_colour" in obj
        if obj.get("inkbound_prop") or obj.get("inkbound_texture") or is_glow:
            obj.select_set(True)
            names.append(obj.name)
    # How the importer turns the file (so props face the way they were made), and the version.
    for obj in maps_export.calibration_cubes(common.collection("Calibration"), "Calib_Props", "Models"):
        obj.select_set(True)
        names.append(obj.name)
    bpy.ops.export_scene.fbx(
        filepath=FBX,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="Z",
        axis_up="Y",
        bake_space_transform=True,
        use_mesh_modifiers=True,
        mesh_smooth_type="OFF",
        path_mode="COPY",
        embed_textures=True,
        add_leaf_bones=False,
    )
    catalog = write_catalog()
    return {"fbx": FBX, "objects": names, "catalog": catalog}
