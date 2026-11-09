"""Builds, unwraps and bakes props, renders previews, and exports them for Roblox.

    build(keys)   -> builds the listed props (all when None) in the current file
    export(set)   -> writes art/export/DeathsGambitModels_<set>.fbx and src/shared/ModelCatalog.luau
"""

import json
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

import common
import modelkit as mk
import props
from maps import export as maps_export
from maps import ownprops

CATALOG = os.path.join(common.ROOT, "src", "shared", "ModelCatalog.luau")

# The set that carries the props every map and the game itself use, and the textures below.
CORE = "Core"

# Textures carried into Roblox on flat quads named "Tex_<name>" (see Assets.texture): effect
# textures, and the UI's lettering, paper and icons (art/scripts/ui). They ride in the Core set's
# file.
# (2026-10-25: the old aura sprites, FxPuff and FxTear left the set: the aura and the effects are the VFX kit's now,
# art/scripts/vfx, in their own Fx set; AuraGlow stays for the UI's soft light)
EFFECT_TEXTURES = ["RainStreak", "Smoke", "SoulGlow", "Spark", "SpeechNah",
                   "Snowflake", "Footprint", "FxShard", "FxStatic", "FxChalk",
                   "AuraGlow"]
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
HELD = {"Pen", "Grimoire", "Handcuffs", "Hood", "SuitTorso", "SuitLimb", "SuitTie"}

# Tokyo's first props were shipped from builders older than the ones in the scripts now, and the
# district was laid out around those shapes (a bicycle rack's spacing, a ticket gate's width, a
# cherry tree's reach). Their meshes were KEPT, re-skinned (reskin_one), until the owner's yes to the newer
# shapes (2026-10-25: "make all assets much more high quality and not just basic shapes ... for every asset"). The
# newer shapes are built now for every one whose size is within a little of the kept one's; vehicles, bicycles and
# the cherry tree, larger in their newer shapes, are built and then scaled to fit inside the kept one's box
# (FIT_TO_KEPT), so the lanes and racks laid out for them still hold them. The ticket gate was the last one KEPT; it was
# rebuilt inside its kept box on 2026-11-05 (its flaps reach the box's width, so the gate lines hold); the station clock and the security-camera station were rebuilt
# inside their kept boxes (2026-11-01, the station overhaul); the beer crates were rebuilt as open crates of bottles, fitted to the kept
# box, and the vending machines too (2026-10-26: the kept ones' samples were black slots, their light hidden). To take
# one of these: remove the name here, build it, and run maps/check_v2.py on every map that places it.
KEPT = frozenset()
# (each one's kept box, x across, y deep, z high: what the district was laid out around)
FIT_TO_KEPT = {
    "TicketGate": (2.8, 5.1, 3.47),
    "VendingBlue": (4.25, 3.075, 7.2),
    "VendingWhite": (4.25, 3.075, 7.2),
    "Bicycle": (1.6, 5.54, 3.05),
    "BikeRack": (8.4, 5.54, 3.05),
    "Bus": (8.97, 34.09, 10.48),
    "KeiTruck": (5.14, 10.87, 5.49),
    "PoliceCar": (5.94, 14.07, 5.73),
    "Taxi": (5.74, 14.0, 5.28),
    "SnowBicycle": (1.6, 5.54, 3.05),
    "SnowKeiTruck": (5.14, 10.87, 5.49),
    "SnowPoliceCar": (5.94, 14.07, 5.73),
    "SnowTaxi": (5.74, 14.0, 5.28),
    "TreeSakura": (11.26, 10.14, 13.72),
    "SiteFence": (8.0, 2.57, 10.0),
    "SiteFenceBoard": (8.0, 3.01, 10.155),  # (its sister panel, fitted the same way so the two meet end to end)
    "BeerCrates": (3.1, 1.9, 3.475),
    # (and two Core props remade the same way, for the beds and the parking laid out round their old shapes)
    "Tree": (7.642, 8.402, 13.717),
    "Car": (5.4, 10.9, 3.444),
}
# (a tree takes being drawn up taller and narrower: fitted to the kept one's box along each axis on its own)
FIT_STRETCH = frozenset({"TreeSakura", "SiteFence", "SiteFenceBoard", "Tree"})
# Designs no map places: not built, so no file carries them.
SHELVED = frozenset({"TreeZelkova", "PetalScatter"})


def _piece_objects(key):
    """The meshes of a prop's pieces that move by themselves: <key>_Spine, <key>_Cover, ... (props.piece)."""
    return sorted((o for o in bpy.data.objects if o.get("dg_part") == key), key=lambda o: o.name)


# Displacement textures a part's detail may ask for, by kind: Blender's own procedural textures.
DETAIL_KINDS = {"cells": "VORONOI", "clouds": "CLOUDS", "wrinkles": "MUSGRAVE", "grain": "STUCCI", "rings": "WOOD"}


def _high_of(parts, name):
    """A prop's high-detail copy, for its maps to be baked from (modelkit.bake's `high`): its parts again, each with
    the detail its builder asked for in "dg_detail" ({"sub": extra subdivision levels, "disp": [(kind, strength in
    studs, scale), ...]}, kinds as DETAIL_KINDS: cells for cracked hide, wrinkles for creased skin, clouds for cloth
    folds, grain for fine pitting, rings for banded feather barbs), merged into one mesh. Parts without one are
    copied as they are. A part with "dg_high" (an object's name) lends that object instead: a high-detail mesh its
    builder made itself (strands grooved into hair and fur, the barbs of a feather), used up here."""
    copies = []
    for part in parts:
        own_high = bpy.data.objects.get(part.get("dg_high") or "")
        if own_high is not None:
            copies.append(own_high)
            continue
        copy = part.copy()
        copy.data = part.data.copy()
        common.collection("Build").objects.link(copy)
        detail = part.get("dg_detail")
        detail = json.loads(detail) if isinstance(detail, str) else detail
        if detail:
            levels = int(detail.get("sub", 2))
            if levels:
                sub = copy.modifiers.new("DetailSub", "SUBSURF")
                sub.levels = levels
                sub.render_levels = levels
            for k, (kind, strength, scale) in enumerate(detail.get("disp", [])):
                tex = bpy.data.textures.new(f"Detail_{name}_{part.name}_{k}", DETAIL_KINDS[kind])
                tex.noise_scale = scale
                if kind == "cells":
                    tex.distance_metric = "DISTANCE"
                    tex.color_mode = "INTENSITY"
                    tex.weight_1, tex.weight_2 = -1.0, 1.0  # (F2 - F1: the lines between the cells)
                elif kind == "wrinkles":
                    tex.musgrave_type = "RIDGED_MULTIFRACTAL"
                    tex.noise_intensity = 1.0
                elif kind == "rings":
                    tex.wood_type = "BANDS"
                mod = copy.modifiers.new(f"Detail{k}", "DISPLACE")
                mod.texture = tex
                mod.strength = strength
                mod.mid_level = 0.5
                mod.texture_coords = "GLOBAL"
        copies.append(copy)
    return mk.merge(copies, name)


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


def _sliver(spec):
    """(the smallest UV island an unwrap keeps as it is: four texels of the prop's texture at its largest; smaller
    ones are laid in a neighbour's, modelkit._snap_slivers)"""
    return 4.0 / spec["texture"] ** 2


# A gap this small (studs) between a prop's parts is closed as it is built (_close_hairlines); a part closer than TOUCH
# to another touches it.
HAIRLINE = 0.1
TOUCH = 0.03


def _close_hairlines(parts, glows):
    """Moves each group of a standing prop's parts that hangs a hairline (HAIRLINE studs or less) off everything that
    holds it up (what stands on its lowest level, and what touches that, part by part) the hairline toward it, so it
    touches: the builders' numbers had left a handle a few hundredths of a stud off its door, a screen off its arm, the
    toys over the claw machine's floor (asked 2026-10-25: "make sure nothing floats"). A wider gap is drawn, not
    rounding, and stays for its builder to close. Moving pieces are left out (they stand clear to turn). Returns how
    many groups moved."""
    objs = list(parts) + list(glows)
    if len(objs) < 2:
        return 0
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    boxes = {}
    for obj in objs:
        ev = obj.evaluated_get(depsgraph)
        corners = [ev.matrix_world @ Vector(c) for c in ev.bound_box]
        boxes[obj] = (Vector([min(c[i] for c in corners) for i in range(3)]),
                      Vector([max(c[i] for c in corners) for i in range(3)]))
    floor = min(lo.z for lo, _ in boxes.values())

    def apart(a, b):
        """(how far apart two parts' boxes are, and the separation along +x, +y, +z, -x, -y, -z from a to b)"""
        (lo, hi), (lo2, hi2) = boxes[a], boxes[b]
        seps = [lo2[i] - hi[i] for i in range(3)] + [lo[i] - hi2[i] for i in range(3)]
        return max(seps + [0.0]), seps

    def spread(start, among):
        reached, todo = set(start), list(start)
        while todo:
            a = todo.pop()
            for b in among:
                if b not in reached and apart(a, b)[0] <= TOUCH:
                    reached.add(b)
                    todo.append(b)
        return reached

    moved = 0
    for _ in range(6):  # (a group moved may be what holds the next)
        held = spread({obj for obj in objs if boxes[obj][0].z <= floor + TOUCH}, objs)
        loose = [obj for obj in objs if obj not in held]
        groups, seen = [], set()
        for obj in loose:
            if obj not in seen:
                group = spread({obj}, loose)
                seen |= group
                groups.append(group)
        progress = False
        for group in groups:
            (gap, seps), _, _ = min(((apart(a, h), a, h) for a in group for h in held), key=lambda t: t[0][0])
            if gap > HAIRLINE:
                continue
            axis = seps.index(gap)
            step = Vector((0.0, 0.0, 0.0))
            step[axis % 3] = (gap - 0.005) * (1 if axis < 3 else -1)
            for obj in group:
                obj.location += step
                lo, hi = boxes[obj]
                boxes[obj] = (lo + step, hi + step)
            moved += 1
            progress = True
        if not progress:
            break
    return moved


def _wear(obj, mat):
    """One material on every face of a mesh."""
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.data.polygons.foreach_set("material_index", [0] * len(obj.data.polygons))
    obj.data.update()


def _tiled(parts, key):
    """A tiled prop's one mesh (props.prop's tiled): its parts joined as they are, keeping their map surfaces and their
    UVs, shaded smooth with its creases kept (no weighted normals: a rock's faces are all of a size). Marks which map
    surfaces it wears ("dg_tiled"), for the catalog's fallback colour."""
    if len(parts) > 1 or parts[0].modifiers:
        # Built from parts (masonry, chains): merged with their bevels applied, each keeping its surface; laid out
        # in their surfaces' repeats from the six sides (props_realm.tile_uvs).
        import props_realm

        main = mk.merge(parts, key)
        main.data.name = key
        props_realm.tile_uvs(main)
    else:
        main = parts[0]
        main.name = key
        main.data.name = key
        # (out of the builder's collection, which is emptied after every build, into the props')
        for coll in list(main.users_collection):
            coll.objects.unlink(main)
        common.collection("Props").objects.link(main)
        main.data.polygons.foreach_set("use_smooth", [True] * len(main.data.polygons))
        mk.auto_smooth(main, 55)
    main["dg_tiled"] = json.dumps([m.name[2:] if m.name.startswith("M_") else m.name for m in main.data.materials])
    return main


def _split_surfaces(main, key):
    """A tiled prop wearing more than one surface comes apart into one mesh per surface (no prop before wore two on one
    mesh, and a MeshPart takes one surface): the first stays the prop's own mesh, each other one becomes a piece of it,
    <key>_<Surface> (ModelLibrary brings a prop's pieces with it). Returns {name: piece}."""
    import bmesh

    out = {}
    mats = list(main.data.materials)
    for index, mat in enumerate(mats[1:], start=1):
        surface = mat.name[2:] if mat.name.startswith("M_") else mat.name
        bm = bmesh.new()
        bm.from_mesh(main.data)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != index], context="FACES")
        if not bm.faces:
            bm.free()
            continue
        for f in bm.faces:
            f.material_index = 0
        mesh = bpy.data.meshes.new(f"{key}_{surface}")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(f"{key}_{surface}", mesh)
        common.collection("Props").objects.link(obj)
        out[surface] = obj
    bm = bmesh.new()
    bm.from_mesh(main.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != 0], context="FACES")
    bm.to_mesh(main.data)
    bm.free()
    while len(main.data.materials) > 1:
        main.data.materials.pop()
    return out


# The sets whose props bake at the maps' density (lookbook.DENSITY "venue"): the lobby's scene has no memory to spare
# and Core is loaded in every scene.
VENUE_SETS = ("Agency", "Campus", "Tokyo", "Meeting")


def build_one(key):
    spec = props.BUILDERS[key]
    mk.new_build()
    # (a newer shape fitted to its kept one's box)
    fit_to = Vector(FIT_TO_KEPT[key]) if key in FIT_TO_KEPT else None
    fit_scale = 1.0
    fit_k = Vector((1.0, 1.0, 1.0))  # (the fit along each axis: what glows, lights and the anchor move by)
    _remove(key)
    for obj in _glow_objects(key) + _piece_objects(key):
        bpy.data.objects.remove(obj, do_unlink=True)
    built = spec["build"]()
    parts, glow = built[0], built[1]
    more = built[2] if len(built) > 2 else {}  # a prop in pieces that move by themselves: props.piece
    if spec["pivot"] == "bottom":  # (one that stands: a hung one's parts hang from what it is hung on)
        closed = _close_hairlines(parts, glow)
        if closed:
            print(f"[props] {key}: {closed} hairline gap(s) closed")
    where = "held" if key in HELD else ("venue" if spec.get("set") in VENUE_SETS else "prop")
    # (a hero prop's high-detail copies, made before the parts are merged away: the main mesh's and each own piece's)
    highs = {}
    if spec.get("detail"):
        highs[None] = _high_of(parts, key + "_High")
        for name, piece in more.get("pieces", {}).items():
            if piece["own"] and not piece.get("plain"):
                highs[name] = _high_of(piece["parts"], f"{key}_{name}_High")
    tiled = spec.get("tiled")
    main = _tiled(parts, key) if tiled else mk.merge(parts, key)
    pieces = {name: mk.merge(piece["parts"], f"{key}_{name}") for name, piece in more.get("pieces", {}).items()}
    if tiled:
        # (laid out in the maps' tiling surfaces by its builder: no unwrap and no bake, see props.prop)
        shift = mk.ground(main) if spec["pivot"] == "bottom" else mk.centre(main)
        whole_size = [round(v, 3) for v in mk.dimensions(main)]
        for obj in _piece_objects(key):
            bpy.data.objects.remove(obj, do_unlink=True)
        pieces.update(_split_surfaces(main, key))
    elif pieces:
        # Faces that carry pictures are laid by hand, where the builder's own coordinates still hold.
        mk.unwrap(main, laid=more.get("laid"), into=more.get("into", (0.0, 0.0, 1.0, 1.0)), least=_sliver(spec))
        for name, piece in more["pieces"].items():
            mk.unwrap(pieces[name], laid=piece["laid"], into=piece["into"], least=_sliver(spec))
        shift, whole_size = _settle(spec["pivot"], [main, *pieces.values()])
        for high in highs.values():
            high.data.transform(Matrix.Translation(shift))
        sharing = [pieces[name] for name, piece in more["pieces"].items() if not piece["own"] and piece["bake"]]
        how = {"size": spec["texture"], "where": where, "finish": more.get("finish")}
        if spec.get("detail"):
            how.update(exact=spec.get("exact", False), ao_strength=spec.get("ao", 0.6), high=highs.get(None),
                       normal_full=True, normal_size=spec.get("normal"))
        if sharing:
            baked = _bake_as_one(key, main, sharing, **how)
        else:
            mk.bake(main, **how)
            baked = main.data.materials[0]
        for name, piece in more["pieces"].items():
            if piece["own"]:
                mk.bake(pieces[name], size=piece["exact"] or spec["texture"], where=where, exact=bool(piece["exact"]),
                        finish=piece["finish"], high=highs.get(name), ao_strength=spec.get("ao", 0.6),
                        normal_full=bool(spec.get("detail")), normal_size=piece.get("normal"))
        for obj in [main] + [pieces[name] for name, piece in more["pieces"].items() if not piece["own"]]:
            _wear(obj, baked)
    else:
        shift = mk.ground(main) if spec["pivot"] == "bottom" else mk.centre(main)
        if fit_to is not None:
            have = Vector(mk.dimensions(main))
            if key in FIT_STRETCH:
                fit_k = Vector([fit_to[i] / max(have[i], 1e-6) for i in range(3)])
                fit_scale = min(fit_k)
            else:
                fit_scale = min(fit_to[i] / have[i] for i in range(3) if have[i] > 1e-6)
                fit_k = Vector((fit_scale, fit_scale, fit_scale))
            main.data.transform(Matrix.Diagonal((*fit_k, 1.0)))
        for high in highs.values():
            high.data.transform(Matrix.Translation(shift))
        mk.unwrap(main, least=_sliver(spec))
        mk.bake(main, size=spec["texture"], where=where, ao_strength=spec.get("ao", 0.6), exact=spec.get("exact", False),
                high=highs.get(None), normal_full=bool(spec.get("detail")), normal_size=spec.get("normal"),
                finish=more.get("finish"))
    # (the high-detail copies only lent their surface to the bake)
    for high in highs.values():
        bpy.data.objects.remove(high, do_unlink=True)
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
        obj.data.transform(Matrix.Diagonal((*fit_k, 1.0)))
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
        k = fit_k
        return [round(-(x + shift.x) * k.x, 3), round((z + shift.z) * k.z, 3), round((y + shift.y) * k.y, 3)]

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
        entry["at"] = spot((x, y, z))
        if fit_scale != 1.0 and "range" in entry:
            entry["range"] = round(entry["range"] * fit_scale, 3)
        lights.append(entry)
    main["lights"] = json.dumps(lights)
    # Where its flames burn (a candle's wick tip, x y z in Roblox axes from the pivot, and the flame's height): the
    # game stands a living flame on each (Presentation/Vfx Recipes.flame; World/Flames).
    # (a fifth number 1 marks a fire rather than a candle's flame)
    main["flames"] = json.dumps([spot(f[:3]) + [round(f[3], 3)] + list(f[4:5]) for f in more.get("flames", [])])
    anchor = spec.get("anchor")
    main["anchor"] = json.dumps([round(-(anchor[0] + shift.x) * fit_k.x, 3), round((anchor[1] + shift.y) * fit_k.y, 3)]
                                if anchor else None)
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
    spec = props.BUILDERS[key]
    mk.unwrap(main, least=_sliver(spec))
    mk.bake(main, size=spec["texture"], where="venue" if spec.get("set") in VENUE_SETS else "prop")
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


# Solids cut from a prop's own shape (props.prop(solids=True)) ---------------------------------------------------

SOLID_SLICE = 1.0  # studs: how tall each slice of the prop is cut
SOLID_REACH = 8.5  # how high over the prop's foot slices are cut (a body, jumping, meets nothing higher)
SOLID_CELL = 0.25  # the grid each slice's cross-section is drawn on
SOLID_MAX = 48  # at most this many blocks for one prop (coarser cells until it fits)


def _clip_z(poly, z0, z1):
    """The part of a polygon (points x, y, z) between the heights z0 and z1."""
    def clip(points, keep, cross):
        out = []
        n = len(points)
        for i in range(n):
            a, b = points[i], points[(i + 1) % n]
            ka, kb = keep(a), keep(b)
            if ka:
                out.append(a)
            if ka != kb:
                out.append(cross(a, b))
        return out

    def at(z):
        def cross(a, b):
            t = (z - a[2]) / (b[2] - a[2])
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, z)
        return cross

    pts = clip(poly, lambda q: q[2] >= z0, at(z0))
    if pts:
        pts = clip(pts, lambda q: q[2] <= z1, at(z1))
    return pts


def _touches(poly, x0, y0, x1, y1):
    """Whether a convex polygon (x, y) meets the square [x0, x1] x [y0, y1] (separating axes)."""
    xs = [q[0] for q in poly]
    ys = [q[1] for q in poly]
    if max(xs) < x0 or min(xs) > x1 or max(ys) < y0 or min(ys) > y1:
        return False
    corners = ((x0, y0), (x1, y0), (x1, y1), (x0, y1))
    n = len(poly)
    for i in range(n):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % n]
        nx, ny = by - ay, ax - bx
        if abs(nx) + abs(ny) < 1e-9:
            continue
        ps = [nx * qx + ny * qy for qx, qy in poly]
        cs = [nx * qx + ny * qy for qx, qy in corners]
        if max(ps) < min(cs) - 1e-9 or min(ps) > max(cs) + 1e-9:
            return False
    return True


def _rectangles(grid, w, h):
    """Covers the set cells of a w x h grid (a set of (i, j)) with rectangles (i0, j0, i1, j1), grown greedily."""
    left = set(grid)
    out = []
    for j in range(h):
        for i in range(w):
            if (i, j) not in left:
                continue
            i1 = i
            while (i1 + 1, j) in left:
                i1 += 1
            j1 = j
            while all((k, j1 + 1) in left for k in range(i, i1 + 1)):
                j1 += 1
            for jj in range(j, j1 + 1):
                for ii in range(i, i1 + 1):
                    left.discard((ii, jj))
            out.append((i, j, i1, j1))
    return out


def _filled(grid, w, h):
    """The grid with its enclosed holes filled (a hollow shell's inside is solid too)."""
    outside = set()
    stack = [(i, j) for i in range(-1, w + 1) for j in (-1, h)] + [(i, j) for j in range(h) for i in (-1, w)]
    while stack:
        c = stack.pop()
        if c in outside or c in grid:
            continue
        i, j = c
        if i < -1 or j < -1 or i > w or j > h:
            continue
        outside.add(c)
        stack += [(i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)]
    return {(i, j) for i in range(w) for j in range(h) if (i, j) not in outside}


def cut_solids(objs, cell=SOLID_CELL):
    """Invisible blocks following a prop's shape: its meshes (as settled: the pivot at the origin) cut in slices
    SOLID_SLICE tall from their foot up to SOLID_REACH, each slice's cross-section drawn on a `cell` grid (every cell a
    face of the slice passes through, hollows inside filled), covered with rectangles, and a block merged with the one
    below it when their footprints are the same. [(x, y, z, sx, sy, sz)] in the game's axes (x = -Blender x, y up,
    z = Blender y) from the pivot."""
    tris = []
    for obj in objs:
        me = obj.data
        me.calc_loop_triangles()
        m = obj.matrix_world
        verts = [m @ v.co for v in me.vertices]
        for t in me.loop_triangles:
            tris.append(tuple((verts[i].x, verts[i].y, verts[i].z) for i in t.vertices))
    if not tris:
        return []
    zs = [q[2] for t in tris for q in t]
    xs = [q[0] for t in tris for q in t]
    ys = [q[1] for t in tris for q in t]
    lo_z, hi_z = min(zs), min(max(zs), min(zs) + SOLID_REACH)
    x0, y0 = min(xs) - cell, min(ys) - cell
    w = int(math.ceil((max(xs) - x0) / cell)) + 2
    h = int(math.ceil((max(ys) - y0) / cell)) + 2
    slices = max(1, int(math.ceil((hi_z - lo_z) / SOLID_SLICE)))
    blocks = []  # [i0, j0, i1, j1, k0, k1]
    open_ = {}
    for k in range(slices):
        z0 = lo_z + k * SOLID_SLICE
        z1 = min(z0 + SOLID_SLICE, hi_z)
        grid = set()
        for t in tris:
            if max(q[2] for q in t) < z0 or min(q[2] for q in t) > z1:
                continue
            poly = _clip_z(list(t), z0, z1)
            if len(poly) < 2:
                continue
            flat = [(q[0], q[1]) for q in poly]
            ia = max(0, int((min(q[0] for q in flat) - x0) / cell))
            ib = min(w - 1, int((max(q[0] for q in flat) - x0) / cell))
            ja = max(0, int((min(q[1] for q in flat) - y0) / cell))
            jb = min(h - 1, int((max(q[1] for q in flat) - y0) / cell))
            for i in range(ia, ib + 1):
                for j in range(ja, jb + 1):
                    if (i, j) in grid:
                        continue
                    if _touches(flat, x0 + i * cell, y0 + j * cell, x0 + (i + 1) * cell, y0 + (j + 1) * cell):
                        grid.add((i, j))
        rects = _rectangles(_filled(grid, w, h), w, h)
        now = {}
        for r in rects:
            if r in open_:
                b = open_[r]
                b[5] = k
                now[r] = b
            else:
                b = [r[0], r[1], r[2], r[3], k, k]
                blocks.append(b)
                now[r] = b
        open_ = now
    if len(blocks) > SOLID_MAX and cell < 1.0:
        return cut_solids(objs, cell * 2)
    out = []
    for i0, j0, i1, j1, k0, k1 in blocks:
        bx0, bx1 = x0 + i0 * cell, x0 + (i1 + 1) * cell
        by0, by1 = y0 + j0 * cell, y0 + (j1 + 1) * cell
        bz0 = lo_z + k0 * SOLID_SLICE
        bz1 = min(lo_z + (k1 + 1) * SOLID_SLICE, hi_z)
        out.append((round(-(bx0 + bx1) / 2, 3), round((bz0 + bz1) / 2, 3), round((by0 + by1) / 2, 3),
                    round(bx1 - bx0, 3), round(bz1 - bz0, 3), round(by1 - by0, 3)))
    return out


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
        spec = props.BUILDERS.get(obj.name)
        entry = {
            "size": [size[0], size[2], size[1]],
            "pivot": obj["pivot"],
            "material": obj["material"],
            # (the builder's word, not the blend's: a prop's collision changed in its code holds without a rebuild)
            "collide": bool(spec["collide"]) if spec else bool(obj["collide"]),
        }
        text = ", ".join(f"{k} = {_lua_value(v)}" for k, v in entry.items())

        def to_srgb(x):
            return x * 12.92 if x <= 0.0031308 else 1.055 * (x ** (1 / 2.4)) - 0.055

        # The texture's average colour: the flat look used when the texture fails to load.
        tex = os.path.join(common.TEXTURES, obj.name + "_color.jpg")
        if not os.path.exists(tex):
            tex = os.path.join(common.TEXTURES, obj.name + ".png")  # (a prop not yet baked from the scans)
        if obj.get("dg_tiled"):
            # (a tiled prop: the colour of the first map surface it wears)
            tex = os.path.join(common.TEXTURES, "maps", json.loads(obj["dg_tiled"])[0] + "_color.jpg")
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
        base = ownprops.BASE.get(obj.name)
        if base:
            text += f', base = "{base}"'
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
        if spec and spec.get("solids") and not entry["collide"]:
            pieces = list(_piece_objects(obj.name))
            blocks = cut_solids([obj] + pieces)
            if blocks:
                text += ", solids = " + _lua_value([list(b) for b in blocks])
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
