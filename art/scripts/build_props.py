"""Builds, unwraps and bakes props, renders previews, and exports them for Roblox.

    build(keys)   -> builds the listed props (all when None) in the current file
    export(set)   -> writes art/export/DeathsGambitModels_<set>.fbx and src/shared/ModelCatalog.luau
"""

import json
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

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
EFFECT_TEXTURES = ["RainStreak", "Smoke", "SoulGlow", "Spark", "SpeechNah", "FxPuff",
                   "Snowflake", "Footprint", "FxShard", "FxStatic", "FxChalk", "FxTear",
                   # (the aura kit's: Presentation/Aura)
                   "AuraGlow", "AuraSpecks", "AuraTwinkle", "AuraHalo", "AuraCrescent", "AuraSpikeRing",
                   "AuraWisp", "AuraBolt"]
UI_TEXTURES = [
    "UiTitle1",
    "UiHead1",
    "UiSemi1",
    "UiRnLight1",
    "UiRnMedium1",
    "UiNotch",
    "UiNotchBtn",
    "UiNotchBtnLine",
    "UiNotchWin",
    "UiNotchWinLine",
    "UiScan",
    "UiGrain",
    "UiVignette",
    "UiIcons",
    "UiWordmark",
]


# Cutscene face decals (art/scripts/ui/faces.py), swapped onto actors' heads by the "face" event.
FACE_TEXTURES = ["FaceGrin", "FaceLaugh", "FaceCrazed", "FaceShock", "FaceStern", "FaceFear", "FaceDevoted"]


def texture_carriers():
    """Small quads, one per effect texture, so importing the FBX also uploads the textures."""
    carriers = []
    for i, name in enumerate(EFFECT_TEXTURES + UI_TEXTURES + FACE_TEXTURES):
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
        obj["dg_texture"] = True
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


# Props held in a hand, in front of the camera: their textures get the denser rule (lookbook.DENSITY).
# (The suit cloth too: it is what the camera follows.)
HELD = {"Notebook", "Pen", "Grimoire", "Handcuffs", "Hood", "SuitTorso", "SuitLimb"}

# Tokyo's first props were shipped from builders older than the ones in the scripts now, and the
# district was laid out around those shapes (a bicycle rack's spacing, a ticket gate's width, a
# cherry tree's reach). Their meshes are KEPT: a build gives the kept mesh the scanned materials
# (reskin_one) and never runs the builder, whose newer shape waits for the owner's yes. To take a
# newer shape: remove the name here, build it, and run maps/check_v2.py on every map that places it.
KEPT = frozenset("""
    ArcadeCabinet BarStool Barricade BeerCrates Bicycle BikeRack Boat Bollard Bus BusShelter BusStopSign
    Chochin ClawMachine ClothesRack CoinLockers DisplayCase DrinkFridge DryerStack GuardRail KeiTruck
    LanternString Mannequin MealTicketMachine Noren Planter PlatformBench PoliceCar PoliceTape PostBox
    RamenCounter RecycleBins RoadSign Scooter ShopCounter SiteFence StationCCTV StationClock
    StationLabBench StationPhoneBooth StationPrintKit StationReception StationSignHanging StoreShelf
    StreetLightTokyo Taxi TaxiRankSign TicketGate TicketMachine TrafficCone TrainHead TrainMiddle
    TreeSakura UtilityPole VendingBlue VendingWhite Washer YakitoriGrill
""".split())
# Designs no map places: not built, so no file carries them.
SHELVED = frozenset({"TreeZelkova", "PetalScatter"})


def _piece_objects(key):
    """The meshes of a prop's pieces that move by themselves: <key>_Spine, <key>_Cover, ... (props.piece)."""
    return sorted((o for o in bpy.data.objects if o.get("dg_part") == key), key=lambda o: o.name)


def _settle(pivot, objs):
    """Moves a prop's meshes together, so that their bottom centre (or their middle) is the origin.
    Returns the shift applied and the size of them all."""
    coords = [v.co for obj in objs for v in obj.data.vertices]
    low = Vector([min(c[i] for c in coords) for i in range(3)])
    high = Vector([max(c[i] for c in coords) for i in range(3)])
    middle = (low + high) / 2
    shift = Vector((-middle.x, -middle.y, -low.z)) if pivot == "bottom" else -middle
    for obj in objs:
        obj.data.transform(Matrix.Translation(shift))
        obj.location = (0, 0, 0)
    return shift, [round(v, 3) for v in high - low]


def _bake_as_one(key, main, sharing, **how):
    """Bakes a prop's main mesh and the pieces that share its textures as one mesh, so they come out
    in one set, and gives them all that set's material."""
    copies = []
    for obj in [main] + sharing:
        copy = obj.copy()
        copy.data = obj.data.copy()
        common.collection("Build").objects.link(copy)
        copies.append(copy)
    bpy.context.view_layer.update()
    for obj in bpy.context.view_layer.objects:
        obj.select_set(obj in copies)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    whole = copies[0]
    main.name = key + "_Main"
    whole.name = key
    mk.bake(whole, **how)
    baked = whole.data.materials[0]
    bpy.data.objects.remove(whole, do_unlink=True)
    main.name = key
    return baked


def _wear(obj, mat):
    """One material on every face of a mesh."""
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.data.polygons.foreach_set("material_index", [0] * len(obj.data.polygons))
    obj.data.update()


def build_one(key):
    spec = props.BUILDERS[key]
    mk.new_build()
    _remove(key)
    for obj in _glow_objects(key) + _piece_objects(key):
        bpy.data.objects.remove(obj, do_unlink=True)
    built = spec["build"]()
    parts, glow = built[0], built[1]
    more = built[2] if len(built) > 2 else {}  # a prop in pieces that move by themselves: props.piece
    where = "held" if key in HELD else "prop"
    main = mk.merge(parts, key)
    pieces = {name: mk.merge(piece["parts"], f"{key}_{name}") for name, piece in more.get("pieces", {}).items()}
    if pieces:
        # Faces that carry pictures are laid by hand, where the builder's own coordinates still hold.
        mk.unwrap(main, laid=more.get("laid"), into=more.get("into", (0.0, 0.0, 1.0, 1.0)))
        for name, piece in more["pieces"].items():
            mk.unwrap(pieces[name], laid=piece["laid"], into=piece["into"])
        shift, whole_size = _settle(spec["pivot"], [main, *pieces.values()])
        sharing = [pieces[name] for name, piece in more["pieces"].items() if not piece["own"] and piece["bake"]]
        how = {"size": spec["texture"], "where": where, "finish": more.get("finish")}
        if sharing:
            baked = _bake_as_one(key, main, sharing, **how)
        else:
            mk.bake(main, **how)
            baked = main.data.materials[0]
        for name, piece in more["pieces"].items():
            if piece["own"]:
                mk.bake(pieces[name], size=piece["exact"] or spec["texture"], where=where, exact=bool(piece["exact"]),
                        finish=piece["finish"])
        for obj in [main] + [pieces[name] for name, piece in more["pieces"].items() if not piece["own"]]:
            _wear(obj, baked)
    else:
        shift = mk.ground(main) if spec["pivot"] == "bottom" else mk.centre(main)
        mk.unwrap(main)
        mk.bake(main, size=spec["texture"], where=where)
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
        "size": whole_size if pieces else [round(v, 3) for v in mk.dimensions(main)],
        "tris": mk.triangles(main) + sum(mk.triangles(o) for o in glow_objs + list(pieces.values())),
    }
    main["dg_prop"] = True
    main["pivot"] = spec["pivot"]
    main["material"] = spec["material"]
    main["collide"] = spec["collide"]
    main["set"] = spec.get("set") or CORE

    def spot(point):
        """A point of the builder's, moved like the mesh and turned into Roblox axes (as the lights below)."""
        x, y, z = point
        return [round(-(x + shift.x), 3), round(z + shift.z, 3), round(y + shift.y, 3)]

    if pieces:
        for obj in pieces.values():
            obj["dg_part"] = key
        main["size"] = json.dumps(whole_size)
        main["parts"] = json.dumps(list(pieces))
        main["hinge"] = json.dumps({name: spot(point) for name, point in more.get("hinge", {}).items()})
        main["turn"] = json.dumps(more.get("turn") or {})
        page = dict(more.get("page") or {})
        if page:
            page["at"] = spot(page["at"])
        main["page"] = json.dumps(page)
    # Lights and the anchor, moved like the mesh and turned into Roblox axes (x -> -x, y <-> z),
    # relative to the prop's pivot.
    lights = []
    for light in spec.get("lights", []):
        x, y, z = light["at"]
        entry = dict(light)
        entry["at"] = [round(-(x + shift.x), 3), round(z + shift.z, 3), round(y + shift.y, 3)]
        lights.append(entry)
    main["lights"] = json.dumps(lights)
    # Where its flames burn (a candle's wick tip, x y z in Roblox axes from the pivot, and the flame's height): the
    # game stands a living flame on each (Presentation/Vfx Recipes.flame; World/Flames).
    # (a fifth number 1 marks a fire rather than a candle's flame)
    main["flames"] = json.dumps([spot(f[:3]) + [round(f[3], 3)] + list(f[4:5]) for f in more.get("flames", [])])
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


def reskin_one(key):
    """A kept prop (KEPT) in the scanned materials, on its own mesh. Each face carries the number of
    its surface ("dg_skin") in the object's list "dg_skins": the two colours it runs between, its kind
    (modelkit.SCANS), roughness and metal, or the two colours and the run of a banded sheet. Its
    glowing parts, lights and anchor stay as they are."""
    main = bpy.data.objects.get(key)
    if main is None or not main.get("dg_skins") or "dg_skin" not in main.data.attributes:
        raise RuntimeError(f"{key} is a kept prop, and art/blend/Props.blend has no kept mesh for it")
    mk.new_build()
    mesh = main.data
    mesh.materials.clear()
    for i, skin in enumerate(json.loads(main["dg_skins"])):
        name = f"{key}_Skin{i}"
        if skin.get("bands"):
            dark, light, frequency, axis = skin["bands"]
            mat = mk.banded(name, dark, light, frequency=frequency, axis=axis, roughness=skin["roughness"])
        else:
            dark, light = skin["colors"]
            mat = mk.noisy(name, dark, light, roughness=skin["roughness"], metallic=skin["metallic"], kind=skin["kind"])
        mesh.materials.append(mat)
    faces = np.zeros(len(mesh.polygons), dtype=np.int32)
    mesh.attributes["dg_skin"].data.foreach_get("value", faces)
    mesh.polygons.foreach_set("material_index", faces)
    mesh.update()
    if "custom_normal" not in mesh.attributes:
        mk.weighted_normals(main)
    mk.unwrap(main)
    mk.bake(main, size=props.BUILDERS[key]["texture"], where="prop")
    glow_objs = _glow_objects(key)
    main["tris"] = mk.triangles(main) + sum(mk.triangles(o) for o in glow_objs)
    info = {"size": [round(v, 3) for v in mk.dimensions(main)], "tris": main["tris"]}
    return main, glow_objs[0] if glow_objs else None, info


def build(keys=None):
    results = {}
    for key in keys or list(props.BUILDERS):
        if key in SHELVED:
            continue
        _, _, info = reskin_one(key) if key in KEPT else build_one(key)
        results[key] = info
    for coll_name in ("Build",):
        coll = bpy.data.collections.get(coll_name)
        if coll:
            for obj in list(coll.objects):
                bpy.data.objects.remove(obj, do_unlink=True)
    return results


def preview(key, path=None, angle=35, height_factor=0.6):
    obj = bpy.data.objects[key]
    # A prop in pieces is framed whole (its "size" covers the pieces too).
    size = json.loads(obj["size"]) if obj.get("size") else mk.dimensions(obj)
    radius = max(size) * 0.75 + 0.3
    target = (0, 0, size[2] / 2 if obj.get("pivot") == "bottom" else 0)
    for other in bpy.data.objects:
        other.hide_render = (other.type == "MESH" and other.name not in (key, key + "_Glow")
                             and other.get("dg_part") != key)
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
        "-- GENERATED by art/scripts/build_props.py. Every prop in art/export/DeathsGambitModels_<set>.fbx:",
        "-- its size in studs (x, y, z with y up), how it is placed (pivot), its Roblox material,",
        "-- whether it collides, and the colour of its glowing part (turned Neon), if any. A prop in pieces",
        "-- that move by themselves (parts: the meshes <Prop>_<part>) also has the point each turns about",
        "-- (hinge) and, for the Manual, the page the game writes on (page), all from the prop's pivot.",
        "",
        "return {",
    ]
    for obj in sorted((o for o in bpy.data.objects if common.flag(o, "prop")), key=lambda o: o.name):
        size = json.loads(obj["size"]) if obj.get("size") else mk.dimensions(obj)
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
        tex = os.path.join(common.TEXTURES, obj.name + "_color.jpg")
        if not os.path.exists(tex):
            tex = os.path.join(common.TEXTURES, obj.name + ".png")  # (a prop not yet baked from the scans)
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
        flames = json.loads(obj.get("flames") or "[]")
        if flames:
            text += ", flames = { " + ", ".join(_lua_value(f) for f in flames) + " }"
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
        parts = json.loads(obj.get("parts") or "[]")
        if parts:
            text += ", parts = " + _lua_value(parts)
            for field in ("hinge", "turn", "page"):
                items = json.loads(obj.get(field) or "{}")
                text += f", {field} = {{ " + ", ".join(f"{k} = {_lua_value(v)}" for k, v in items.items()) + " }"
        lines.append(f"\t{obj.name} = {{ {text} }},")
    lines.append("}")
    with open(CATALOG, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return CATALOG


def _prop_set(obj):
    """The set a prop mesh (or its glow mesh) belongs to (props built before sets had names are
    the Core set's)."""
    if common.flag(obj, "prop"):
        return obj.get("set") or CORE
    if "glow_colour" in obj or obj.get("dg_part"):
        owner = bpy.data.objects.get(obj.get("dg_part") or obj.name.split("_Glow")[0])
        return (owner.get("set") or CORE) if owner else ""
    return ""


def fbx_path(set_name):
    return os.path.join(common.EXPORT, f"DeathsGambitModels_{set_name}.fbx")


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
    """Writes the set's FBX, DeathsGambitModels_<set>.fbx (the Core set's also carries the effect and
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
        mine = (common.flag(obj, "prop") or is_glow or obj.get("dg_part")) and _prop_set(obj) == set_name
        if mine or (set_name == CORE and common.flag(obj, "texture")):
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
    maps_export.write_versions()
    return {"fbx": fbx_path(set_name), "objects": names, "catalog": catalog}
