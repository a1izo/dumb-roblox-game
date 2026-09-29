"""Builds, unwraps and bakes props, renders previews, and exports them for Roblox.

    build(keys)   -> builds the listed props (all when None) in the current file
    export(set)   -> writes art/export/InkboundModels_<set>.fbx and src/shared/ModelCatalog.luau
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

# The set that carries the props every map and the game itself use, and the textures below.
CORE = "Core"

# Textures carried into Roblox on flat quads named "Tex_<name>" (see Assets.texture): effect
# textures, and the UI's lettering, paper and icons (art/scripts/ui). They ride in the Core set's
# file.
EFFECT_TEXTURES = ["InkSplat1", "InkSplat2", "InkSplat3", "InkDrop", "RainStreak", "Smoke", "SoulGlow", "Spark",
                   "Snowflake", "Footprint"]
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
    main["set"] = spec.get("set") or CORE
    # Lights and the anchor, moved like the mesh and turned into Roblox axes (x -> -x, y <-> z),
    # relative to the prop's pivot.
    lights = []
    for light in spec.get("lights", []):
        x, y, z = light["at"]
        entry = dict(light)
        entry["at"] = [round(-(x + shift.x), 3), round(z + shift.z, 3), round(y + shift.y, 3)]
        lights.append(entry)
    main["lights"] = json.dumps(lights)
    anchor = spec.get("anchor")
    main["anchor"] = json.dumps([round(-(anchor[0] + shift.x), 3), round(anchor[1] + shift.y, 3)] if anchor else None)
    # A station's screen slot stays in design coordinates (the station is placed by its origin).
    screen = spec.get("screen")
    if screen:
        sx, sy, sz, w, h = screen[:5]
        main["screen"] = json.dumps({"at": [round(-sx, 3), round(sz, 3), round(sy, 3)], "size": [w, h],
                                     "tilt": screen[5] if len(screen) > 5 else 0})
    main["tris"] = info["tris"]
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
        "-- GENERATED by art/scripts/build_props.py. Every prop in art/export/InkboundModels_<set>.fbx:",
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

        lights = json.loads(obj.get("lights") or "[]")
        if lights:
            items = ["{ " + ", ".join(f"{k} = {_lua_value(v)}" for k, v in sorted(li.items())) + " }" for li in lights]
            text += ", lights = { " + ", ".join(items) + " }"
        anchor = json.loads(obj.get("anchor") or "null")
        if anchor:
            text += ", anchor = " + _lua_value(anchor)
        screen = json.loads(obj.get("screen") or "null")
        if screen:
            text += (", screen = { at = " + _lua_value(screen["at"]) + ", size = " + _lua_value(screen["size"])
                     + ", tilt = " + _lua_value(screen["tilt"]) + " }")
        text += ", set = " + _lua_value(obj.get("set") or CORE)
        if obj.get("tris"):
            text += ", tris = " + _lua_value(int(obj["tris"]))

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


def _prop_set(obj):
    """The set a prop mesh (or its glow mesh) belongs to (props built before sets had names are
    the Core set's)."""
    if obj.get("inkbound_prop"):
        return obj.get("set") or CORE
    if "glow_colour" in obj:
        owner = bpy.data.objects.get(obj.name.split("_Glow")[0])
        return (owner.get("set") or CORE) if owner else ""
    return ""


def fbx_path(set_name):
    return os.path.join(common.EXPORT, f"InkboundModels_{set_name}.fbx")


def remap_textures():
    """Baked textures saved on another machine keep that machine's paths in Props.blend: point
    them at the same file in art/export/textures, so the export can embed them."""
    fixed = 0
    for img in bpy.data.images:
        path = bpy.path.abspath(img.filepath) if img.filepath else ""
        if path and not os.path.exists(path):
            local = os.path.join(common.TEXTURES, os.path.basename(path.replace("\\", "/")))
            if os.path.exists(local):
                img.filepath = local
                img.reload()
                fixed += 1
    return fixed


def export(set_name):
    """Writes the set's FBX, InkboundModels_<set>.fbx (the Core set's also carries the effect and
    UI textures), and the catalog of every prop."""
    assert set_name, "export(set): name the set (Core, Tokyo, Agency, Campus, Lobby, Meeting)"
    common.ensure_dirs()
    remap_textures()
    if set_name == CORE:
        texture_carriers()
    bpy.context.view_layer.update()
    names = []
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in bpy.data.objects:
        is_glow = "glow_colour" in obj
        mine = (obj.get("inkbound_prop") or is_glow) and _prop_set(obj) == set_name
        if mine or (set_name == CORE and obj.get("inkbound_texture")):
            obj.select_set(True)
            names.append(obj.name)
    # How the importer turns the file (so props face the way they were made), and the version.
    for obj in maps_export.calibration_cubes(common.collection("Calibration" + set_name), "Calib_Props" + set_name,
                                             "Models" + set_name):
        obj.select_set(True)
        names.append(obj.name)
    bpy.ops.export_scene.fbx(
        filepath=fbx_path(set_name),
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
    return {"fbx": fbx_path(set_name), "objects": names, "catalog": catalog}
