"""Builds the map scenes (background Blender):

    blender -b --factory-startup --python art/scripts/run_maps.py -- [venues...] [--preview] [--export]

venues: Lobby Meeting Agency Campus Tokyo (all when none are given)
--preview  renders views of each venue to art/export/previews/map_<Venue>_<n>.png (--views 3,4
           for some of them), with the
           props from Props.blend placed and the scene lights on
--plan     renders top-down plans of each floor level with the gameplay spots marked
           (art/export/previews/plan_<Venue>_<level>.png)
--proplan  the hand-check plans: every level in tiles (--tile 64x48 --ppu 30 --levels ground,upper
           --region x0,z0,x1,z1) with each prop placed, numbered, named and arrowed (its front), a
           10-stud grid, and a .txt legend per tile (plan_props_<Venue>_<level>_<i>_<j>.png/.txt)
--eyes "px,py,pz,tx,ty,tz[,lens];..."  ad-hoc perspective views (eye_<Venue>_<n>.png), studs
--out DIR  writes the renders there instead of art/export/previews (use it for scratch renders)
--massing  renders the venue's MASSING_VIEWS like an architect's model, with player-sized figures
           for scale (art/export/previews/massing_<Venue>_<n>.png)
--export   each venue's src/server/Maps/Scenes/<Venue>/, art/export/DeathsGambitMaps_<Venue>.fbx and
           art/export/scenes/<Venue>.json (for the checks), and for the maps src/shared/MapBounds.luau.
           Always merges src/shared/SceneMaterials.luau and saves the .blend (Maps_<Venue>.blend)
--materials rewrites only src/shared/SceneMaterials.luau (for the materials it lists now)
"""

import importlib
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
from maps import export, matlib, mesher  # noqa: E402

VENUES = ["Lobby", "Meeting", "Agency", "Campus", "Tokyo"]
MODULES = {"Lobby": "lobby", "Meeting": "meeting", "Agency": "agency", "Campus": "campus", "Tokyo": "tokyo"}


def build_venue(name):
    """Every venue is a package with FORMAT = 2: an FBX of its own and scene data with its gameplay
    layout and anchors (see maps/export.py)."""
    module = importlib.import_module("maps.venues." + MODULES[name])
    assert getattr(module, "FORMAT", 1) >= 2, f"{name}: every venue is FORMAT 2 now"
    scene = mesher.Scene(name, prefix="Map", chunk=128.0)
    module.build(scene)
    coll = common.collection("Scene_" + name)
    started = time.time()
    names = scene.finish(coll)
    print(f"[maps] {name}: {len(names)} meshes, {scene.triangles()} triangles, {len(scene.colliders)} colliders, "
          f"{len(scene.ramps)} ramps, {len(scene.props)} props, {len(scene.lights)} lights, "
          f"{len(scene.layout['areas'])} areas ({time.time() - started:.1f}s)")
    return scene, module, coll


# Plans: top-down views of every floor level, with the gameplay spots marked -------------------------

SOCKET_COLOURS = {
    "Camera": (0.2, 0.55, 1.0),
    "Fingerprint": (0.2, 1.0, 0.6),
    "Phone": (1.0, 0.85, 0.2),
    "Forensics": (0.85, 0.3, 1.0),
    "spawn": (1.0, 1.0, 1.0),
    "sheet": (1.0, 0.95, 0.75),
    "hood": (0.05, 0.05, 0.05),
    "area": (1.0, 0.5, 0.1),
    "spare": (0.45, 0.45, 0.45),
    "tip": (1.0, 0.1, 0.2),
}


def _marker(coll, name, x, y, z, colour, radius=2.2, height=0.6, text=None, text_size=6.0):
    mat = bpy.data.materials.get("Plan_" + name) or bpy.data.materials.new("Plan_" + name)
    mat.diffuse_color = (*colour, 1.0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=height, location=(-x, z, y + height / 2))
    obj = bpy.context.active_object
    obj.data.materials.append(mat)
    for c in obj.users_collection:
        c.objects.unlink(obj)
    coll.objects.link(obj)
    made = [obj]
    if text:
        curve = bpy.data.curves.new("PlanText", "FONT")
        curve.body = text
        curve.size = text_size
        curve.align_x = "CENTER"
        t = bpy.data.objects.new("PlanText", curve)
        t.location = (-x, z - radius - 1, y + height + 0.2)
        t.rotation_euler = (0, 0, math.pi)  # reads left to right in the plan (north up)
        t.data.materials.append(mat)
        coll.objects.link(t)
        made.append(t)
    return made


def render_plans(scene, module):
    """art/export/previews/plan_<Venue>_<level>.png: orthographic views from above, cut just
    under each floor's ceiling, with stations (by type), spawns, sheets, hoods and
    area names marked; spare spots in grey."""
    (x0, y0, z0), (x1, y1, z1) = scene.bounds or ((-100, 0, -100), (100, 60, 100))
    coll = common.collection("PlanMarkers")
    L, S = scene.layout, scene.spare
    for st in L["stations"]:
        _marker(coll, st["type"], st["x"], st["y"], st["z"], SOCKET_COLOURS[st["type"]], text=st["name"], text_size=4)
    for st in S["stations"]:
        _marker(coll, "spare", st["x"], st["y"], st["z"], SOCKET_COLOURS["spare"], radius=1.6)
    for kind, items, colour, r in (("spawn", L["spawns"], "spawn", 1.4), ("sheet", L["sheets"], "sheet", 1.0),
                                   ("hood", L["hoods"], "hood", 1.6), ("spawn_s", S["spawns"], "spare", 0.9)):
        for it in items:
            _marker(coll, colour, it["x"], it["y"], it["z"], SOCKET_COLOURS[colour], radius=r)
    for it in L["areas"]:
        _marker(coll, "area", it["x"], it["y"], it["z"], SOCKET_COLOURS["area"], radius=0.8, height=0.3,
                text=it["name"], text_size=7)
        for m in it["marks"]:
            _marker(coll, "area", m["x"], m["y"], m["z"], SOCKET_COLOURS["area"], radius=0.6, height=0.4)
    if L["tipBox"]:
        tb = L["tipBox"]
        _marker(coll, "tip", tb["x"], tb["y"], tb["z"], SOCKET_COLOURS["tip"], radius=1.6, text="TIP BOX", text_size=3)
    bscene = bpy.context.scene
    bscene.render.engine = "BLENDER_WORKBENCH"
    shading = bscene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "TEXTURE"
    shading.show_shadows = True
    shading.show_cavity = True
    width, depth = x1 - x0, z1 - z0
    px = 2400
    bscene.render.resolution_x = px
    bscene.render.resolution_y = int(px * depth / width)
    cam_data = bpy.data.cameras.get("PlanCam") or bpy.data.cameras.new("PlanCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(width, depth)
    cam = bpy.data.objects.get("PlanCam") or bpy.data.objects.new("PlanCam", cam_data)
    if cam.name not in bscene.collection.objects:
        bscene.collection.objects.link(cam)
    bscene.camera = cam
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    paths = []
    for name, cut in getattr(module, "PLAN_LEVELS", [("ground", 9.0)]):
        cam.location = (-cx, cz, cut)
        cam.rotation_euler = (0, 0, math.radians(180))
        cam_data.clip_start = 0.05
        cam_data.clip_end = cut - y0 + 20
        path = os.path.join(common.PREVIEWS, f"plan_{scene.venue}_{name}.png")
        common.render(path)
        paths.append(path)
    for obj in list(coll.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return paths


# Prop plans, for the hand-check: a level seen from above in tiles, every prop placed, numbered and
# named, with an arrow for the way its front faces and a 10-stud grid; each tile comes with a text
# legend (number, prop, position, rotation, and the script line that placed it). They are aids for
# looking; nothing here decides where a prop goes. -------------------------------------------------------

PLAN_LABEL = (1.0, 0.92, 0.2)
PLAN_ARROW = (1.0, 0.1, 0.75)
PLAN_GRID = (0.1, 0.85, 0.95)
# Props that look the same from every side get no facing arrow (it would only be noise).
ROUND_HINTS = ("Ginkgo", "Tree", "Plant", "Lamp", "Snowman", "Planter", "Hydrant", "TrashCan", "BarStool", "Bollard",
               "Bush", "Shrub", "Pine", "Cherry", "Lantern", "Post", "Cairn", "Stump")


def _flat(name, rgb):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1.0)
    return mat


def _label(coll, text, x, z, y, size, mat):
    curve = bpy.data.curves.new("PlanLabel", "FONT")
    curve.body = text
    curve.size = size
    curve.align_x = "CENTER"
    obj = bpy.data.objects.new("PlanLabel", curve)
    obj.location = (-x, z, y)
    obj.rotation_euler = (0, 0, math.pi)  # reads left to right in the plan (north up)
    obj.data.materials.append(mat)
    coll.objects.link(obj)
    return obj


def _flat_mesh(coll, name, quads, tris, y, mat):
    """One object of flat quads and triangles, each a list of (x, z) Roblox points, drawn at height y."""
    verts, faces = [], []
    for poly in list(quads) + list(tris):
        base = len(verts)
        verts.extend((-px, pz, y) for px, pz in poly)
        faces.append(tuple(range(base, base + len(poly))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    coll.objects.link(obj)
    return obj


def _arrow(x, z, rot, length):
    """(shaft quad, head triangle) for a prop at (x, z) whose front faces rot (0 faces -Z)."""
    a = math.radians(rot)
    fx, fz = -math.sin(a), -math.cos(a)
    px, pz = -fz, fx
    head = min(0.9, length * 0.4)
    bx, bz = x + fx * (length - head), z + fz * (length - head)
    tx, tz = x + fx * length, z + fz * length
    w, hw = 0.16, 0.55
    shaft = [(x + px * w, z + pz * w), (bx + px * w, bz + pz * w), (bx - px * w, bz - pz * w), (x - px * w, z - pz * w)]
    tip = [(bx + px * hw, bz + pz * hw), (tx, tz), (bx - px * hw, bz - pz * hw)]
    return shaft, tip


def _grid_lines(x0, z0, x1, z1, step=10.0, thick=0.035):
    quads = []
    gx = math.ceil(x0 / step) * step
    while gx <= x1:
        quads.append([(gx - thick, z0), (gx + thick, z0), (gx + thick, z1), (gx - thick, z1)])
        gx += step
    gz = math.ceil(z0 / step) * step
    while gz <= z1:
        quads.append([(x0, gz - thick), (x1, gz - thick), (x1, gz + thick), (x0, gz + thick)])
        gz += step
    return quads


def render_propplans(scene, module, coll, opts):
    """art/export/previews/plan_props_<Venue>_<level>_<i>_<j>.png (+ .txt legend) for each tile that holds
    props of the level. opts: tile (w, d) studs, ppu pixels per stud, levels (names or None), region
    (x0, z0, x1, z1) or None."""
    from maps import catalog

    sizes = catalog.load()
    library = load_props()
    tw, td = opts["tile"]
    ppu = opts["ppu"]
    (bx0, by0, bz0), (bx1, by1, bz1) = scene.bounds or ((-100, 0, -100), (100, 60, 100))
    if opts["region"]:
        bx0, bz0, bx1, bz1 = opts["region"]
    label_mat, arrow_mat, grid_mat = _flat("PlanLabel", PLAN_LABEL), _flat("PlanArrow", PLAN_ARROW), _flat("PlanGrid", PLAN_GRID)
    # Every prop stays placed for all tiles; only the labels are made per tile.
    placed = place_props(scene, coll)
    bscene = bpy.context.scene
    bscene.render.engine = "BLENDER_WORKBENCH"
    shading = bscene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "TEXTURE"
    shading.show_shadows = False  # shadows across snow and lawns only confuse a plan
    shading.show_cavity = True
    # The night textures are dark: lift them so props and ground can be told apart by eye.
    bscene.view_settings.view_transform = "Standard"
    bscene.view_settings.exposure = opts["bright"]
    cam_data = bpy.data.cameras.get("PlanCam") or bpy.data.cameras.new("PlanCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(tw, td)
    cam_data.clip_start = 0.05
    cam = bpy.data.objects.get("PlanCam") or bpy.data.objects.new("PlanCam", cam_data)
    if cam.name not in bscene.collection.objects:
        bscene.collection.objects.link(cam)
    bscene.camera = cam
    bscene.render.resolution_x, bscene.render.resolution_y = int(tw * ppu), int(td * ppu)
    levels = getattr(module, "PLAN_LEVELS", [("ground", 9.0)])
    written = []
    for li, (lname, cut) in enumerate(levels):
        if opts["levels"] and lname not in opts["levels"]:
            continue
        lo = levels[li - 1][1] - 1.5 if li else -1e9
        members = [i for i, p in enumerate(scene.props) if lo < p[2] <= cut]
        nx, nz = math.ceil((bx1 - bx0) / tw), math.ceil((bz1 - bz0) / td)
        for ix in range(nx):
            for iz in range(nz):
                x0, z0 = bx0 + ix * tw, bz0 + iz * td
                x1, z1 = x0 + tw, z0 + td
                inside = [i for i in members if x0 <= scene.props[i][1] < x1 and z0 <= scene.props[i][3] < z1]
                if not inside:
                    continue
                made = []
                arrows = []
                for i in inside:
                    key, x, y, z, rot, sc, *_ = scene.props[i]
                    info = sizes.get(key, {})
                    w, d = (info.get("size") or [2.0, 0, 2.0])[0], (info.get("size") or [2.0, 0, 2.0])[2]
                    if not any(h in key for h in ROUND_HINTS):
                        arrows.append(_arrow(x, z, rot, max(1.6, 0.5 * max(w, d) * sc + 1.0)))
                    text = f"{i} {key[:13]}"
                    made.append(_label(coll, text, x, z + 0.0, cut - 0.15, 1.05, label_mat))
                shafts = [a[0] for a in arrows]
                heads = [a[1] for a in arrows]
                made.append(_flat_mesh(coll, "PlanArrows", shafts, heads, cut - 0.3, arrow_mat))
                made.append(_flat_mesh(coll, "PlanGrid", _grid_lines(x0, z0, x1, z1), [], cut - 0.5, grid_mat))
                gx = math.ceil(x0 / 20.0) * 20.0
                while gx < x1:
                    gz = math.ceil(z0 / 20.0) * 20.0
                    while gz < z1:
                        made.append(_label(coll, f"{gx:g},{gz:g}", gx, gz, cut - 0.6, 0.9, _flat("PlanGridText", PLAN_GRID)))
                        gz += 20.0
                    gx += 20.0
                cam.location = (-(x0 + x1) / 2, (z0 + z1) / 2, cut)
                cam.rotation_euler = (0, 0, math.radians(180))
                cam_data.clip_end = cut - by0 + 20
                stem = f"plan_props_{scene.venue}_{lname}_{ix}_{iz}"
                path = os.path.join(common.PREVIEWS, stem + ".png")
                common.render(path)
                with open(os.path.join(common.PREVIEWS, stem + ".txt"), "w", encoding="utf-8", newline="\n") as f:
                    f.write(f"{scene.venue} {lname} tile {ix},{iz}: x {x0:g}..{x1:g}, z {z0:g}..{z1:g}, cut y {cut:g}\n")
                    for i in inside:
                        key, x, y, z, rot, sc, flags = (*scene.props[i][:6], scene.props[i][6] if len(scene.props[i]) > 6 else "")
                        src = scene.prop_src[i] if i < len(scene.prop_src) else ""
                        f.write(f"{i:4d} {key:22s} x={x:8.2f} y={y:6.2f} z={z:8.2f} rot={rot:7.1f} sc={sc:4.2f} {flags} <- {src}\n")
                written.append(path)
                for obj in made:
                    data = obj.data
                    bpy.data.objects.remove(obj, do_unlink=True)
                    if data is not None and data.users == 0:
                        (bpy.data.curves if isinstance(data, bpy.types.TextCurve) else bpy.data.meshes).remove(data)
    for obj in placed:
        bpy.data.objects.remove(obj, do_unlink=True)
    return written


# Previews -------------------------------------------------------------------------------------------

_PROPS = {}


def load_props():
    path = os.path.join(common.BLEND, "Props.blend")
    if _PROPS or not os.path.exists(path):
        return _PROPS
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if not n.startswith("Tex_")]
    for obj in dst.objects:
        if obj is not None:
            _PROPS[obj.name] = obj
    # Baked textures saved on another machine keep that machine's paths: find them by name here.
    for img in bpy.data.images:
        path = bpy.path.abspath(img.filepath) if img.filepath else ""
        if path and not os.path.exists(path):
            local = os.path.join(common.TEXTURES, os.path.basename(path.replace("\\", "/")))
            if os.path.exists(local):
                img.filepath = local
                img.reload()
    return _PROPS


def place_props(scene, coll):
    library = load_props()
    placed = []
    for key, x, y, z, rot, sc, *_ in scene.props + scene.preview_props:
        for name in [key] + [k for k in library if k.startswith(key + "_Glow")]:
            src = library.get(name)
            if not src:
                continue
            obj = src.copy()
            obj.location = (-x, z, y)
            obj.rotation_euler = (0, 0, math.radians(rot))
            obj.scale = (sc, sc, sc)
            coll.objects.link(obj)
            placed.append(obj)
    return placed


def add_lights(scene, coll):
    made = []
    for li in scene.lights:
        data = bpy.data.lights.new("L", "SPOT" if li["kind"] == "spot" else "POINT")
        data.color = [c / 255 for c in li["color"]]
        data.energy = li["brightness"] * li["range"] * li["range"] * 1.6
        data.shadow_soft_size = 0.4
        data.use_shadow = li["shadows"]
        if li["kind"] == "spot":
            data.spot_size = math.radians(min(170, li["angle"] * 1.6))
        obj = bpy.data.objects.new("L", data)
        x, y, z = li["pos"]
        obj.location = (-x, z, y)
        if li["kind"] == "spot":
            obj.rotation_euler = (0, 0, 0)  # points down (-Z in Blender)
        coll.objects.link(obj)
        made.append(obj)
    return made


def _light(coll, kind, pos, color, range_, brightness, shadows=False, angle=90):
    data = bpy.data.lights.new("L", "SPOT" if kind == "spot" else "POINT")
    data.color = [c / 255 for c in color]
    data.energy = brightness * range_ * range_ * 1.6
    data.shadow_soft_size = 0.4
    data.use_shadow = shadows
    if kind == "spot":
        data.spot_size = math.radians(min(170, angle * 1.6))
    obj = bpy.data.objects.new("L", data)
    x, y, z = pos
    obj.location = (-x, z, y)
    coll.objects.link(obj)
    return obj


def prop_lights(scene, coll):
    """The lights the placed props carry (their catalog lights), unless placed dark."""
    import json

    library = load_props()
    made = []
    for key, x, y, z, rot, sc, *rest in scene.props + scene.preview_props:
        src = library.get(key)
        if not src or (rest and rest[0] == "dark") or not src.get("lights"):
            continue
        a = math.radians(rot)
        for li in json.loads(src["lights"]):
            lx, ly, lz = li["at"]
            wx = x + (lx * math.cos(a) + lz * math.sin(a)) * sc
            wz = z + (-lx * math.sin(a) + lz * math.cos(a)) * sc
            made.append(_light(coll, li.get("kind", "point"), (wx, y + ly * sc, wz), li["color"], li["range"],
                               li["brightness"], angle=li.get("angle", 90)))
    return made


def _flat_material(name, rgb, glow):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    colour = common.srgb(*rgb)
    bsdf.inputs["Base Color"].default_value = (*colour, 1)
    if glow:
        bsdf.inputs["Emission Color"].default_value = (*colour, 1)
        bsdf.inputs["Emission Strength"].default_value = 1.6
    return mat


def draw_signs(scene, coll):
    """Signs and screens as the game will show them (boards with their words; screens lit)."""
    import bmesh

    font = None
    for path in (r"C:\Windows\Fonts\YuGothB.ttc", r"C:\Windows\Fonts\msgothic.ttc"):
        try:
            font = bpy.data.fonts.load(path, check_existing=True)
            break
        except Exception:  # noqa: BLE001 - try the next font
            continue
    made = []

    def board(name, pos, rot, w, h, mat, depth=0.1):
        mesh = bpy.data.meshes.new(name)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(w, depth, h), verts=bm.verts)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        obj.data.materials.append(mat)
        x, y, z = pos
        obj.location = (-x, z, y)
        obj.rotation_euler = (0, 0, math.radians(rot))
        coll.objects.link(obj)
        return obj

    for sg in scene.signs:
        if sg["bg"]:
            made.append(board("Sign", sg["pos"], sg["rot"], sg["w"], sg["h"],
                              _flat_material("SignBg_%d_%d_%d" % tuple(sg["bg"]), sg["bg"], bool(sg["glow"]))))
        lines = sg["text"].split("\n")
        longest = max(len(line) for line in lines) or 1
        size = min(sg["h"] * 0.75 / len(lines), sg["w"] * 0.95 / max(1.0, longest * 0.62))
        curve = bpy.data.curves.new("SignText", "FONT")
        curve.body = sg["text"]
        curve.size = size
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        curve.space_line = 0.9
        if font:
            curve.font = font
        curve.materials.append(_flat_material("SignInk_%d_%d_%d" % tuple(sg["color"]), sg["color"], True))
        obj = bpy.data.objects.new("SignText", curve)
        a = math.radians(sg["rot"])
        fx, fz = -math.sin(a), -math.cos(a)
        x, y, z = sg["pos"]
        obj.location = (-(x + fx * 0.12), z + fz * 0.12, y)
        obj.rotation_euler = (math.radians(90), 0, a)
        coll.objects.link(obj)
        made.append(obj)
    colours = [(120, 60, 255), (40, 200, 255), (255, 70, 160), (255, 200, 60)]
    for k, sc in enumerate(scene.screens):
        made.append(board("Screen", sc["pos"], sc["rot"], sc["w"], sc["h"],
                          _flat_material("ScreenGlow%d" % k, colours[k % len(colours)], True), depth=0.05))
    return made


def render_views(name, module, scene, only=None, views=None, tag="map"):
    render = bpy.context.scene.render
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    render.resolution_x, render.resolution_y = 1280, 720
    bpy.context.scene.view_settings.view_transform = "Standard"
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.05, 0.055, 0.085, 1)
    bg.inputs["Strength"].default_value = 1.6
    # A dim moon so what no lamp reaches still reads, as the game's night ambient does.
    moon = bpy.data.objects.get("Moon")
    if not moon:
        data = bpy.data.lights.new("Moon", "SUN")
        data.energy = 0.35
        data.color = (0.7, 0.75, 1.0)
        moon = bpy.data.objects.new("Moon", data)
        moon.rotation_euler = (math.radians(50), 0, math.radians(30))
        bpy.context.scene.collection.objects.link(moon)
    cam_data = bpy.data.cameras.get("MapCam") or bpy.data.cameras.new("MapCam")
    cam = bpy.data.objects.get("MapCam") or bpy.data.objects.new("MapCam", cam_data)
    if cam.name not in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    paths = []
    for i, view in enumerate(views if views is not None else getattr(module, "VIEWS", [])):
        if only and i + 1 not in only:
            continue
        (px, py, pz), (tx, ty, tz), lens = view
        cam.location = (-px, pz, py)
        target = (-tx, tz, ty)
        from mathutils import Vector

        direction = Vector(target) - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = lens
        cam_data.clip_end = 2000
        path = os.path.join(common.PREVIEWS, f"{tag}_{name}_{i + 1}.png")
        common.render(path)
        paths.append(path)
    return paths


# Massing views: the map as plain blocks at true height, lit like a model, with player-sized
# figures standing in them for scale ------------------------------------------------------------------

FIGURE_PARTS = [  # (Roblox local centre, size): an R15-sized body, 5.2 studs tall
    ((0.5, 1.0, 0.0), (0.9, 2.0, 0.9)),
    ((-0.5, 1.0, 0.0), (0.9, 2.0, 0.9)),
    ((0.0, 3.0, 0.0), (2.0, 2.0, 1.0)),
    ((1.5, 3.0, 0.0), (0.9, 2.0, 0.9)),
    ((-1.5, 3.0, 0.0), (0.9, 2.0, 0.9)),
    ((0.0, 4.6, 0.0), (1.2, 1.2, 1.2)),
]


def add_figure(coll, x, y, z, rot):
    mat = bpy.data.materials.get("ScaleFigure") or bpy.data.materials.new("ScaleFigure")
    mat.diffuse_color = (0.9, 0.12, 0.08, 1.0)
    a = math.radians(rot)
    made = []
    for (ox, oy, oz), (sx, sy, sz) in FIGURE_PARTS:
        wx = x + ox * math.cos(a) + oz * math.sin(a)
        wz = z - ox * math.sin(a) + oz * math.cos(a)
        mesh = bpy.data.meshes.new("ScaleFigure")
        obj = bpy.data.objects.new("ScaleFigure", mesh)
        import bmesh

        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bm.to_mesh(mesh)
        bm.free()
        obj.data.materials.append(mat)
        obj.location = (-wx, wz, y + oy)
        obj.scale = (sx, sz, sy)
        obj.rotation_euler = (0, 0, a)
        coll.objects.link(obj)
        made.append(obj)
    return made


def render_massing(scene, module):
    bscene = bpy.context.scene
    bscene.render.engine = "BLENDER_WORKBENCH"
    bscene.render.resolution_x, bscene.render.resolution_y = 1600, 900
    shading = bscene.display.shading
    shading.light = "FLAT"
    shading.color_type = "TEXTURE"
    shading.show_shadows = True
    shading.shadow_intensity = 0.45
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.show_backface_culling = True
    bscene.display.light_direction = (0.45, -0.35, 0.82)
    bscene.view_settings.view_transform = "Standard"
    world = bscene.world or bpy.data.worlds.new("World")
    bscene.world = world
    world.color = (0.58, 0.64, 0.74)
    coll = common.collection("ScaleFigures")
    figures = [o for (x, y, z, rot) in getattr(module, "FIGURES", []) for o in add_figure(coll, x, y, z, rot)]
    cam_data = bpy.data.cameras.get("MassCam") or bpy.data.cameras.new("MassCam")
    cam = bpy.data.objects.get("MassCam") or bpy.data.objects.new("MassCam", cam_data)
    if cam.name not in bscene.collection.objects:
        bscene.collection.objects.link(cam)
    bscene.camera = cam
    from mathutils import Vector

    paths = []
    for i, ((px, py, pz), (tx, ty, tz), lens) in enumerate(getattr(module, "MASSING_VIEWS", [])):
        cam.location = (-px, pz, py)
        cam.rotation_euler = (Vector((-tx, tz, ty)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam_data.lens = lens
        cam_data.clip_start = 0.3
        cam_data.clip_end = 3000
        path = os.path.join(common.PREVIEWS, f"massing_{scene.venue}_{i + 1}.png")
        common.render(path)
        paths.append(path)
    for obj in figures:
        bpy.data.objects.remove(obj, do_unlink=True)
    return paths


def texture_carriers(names, venue):
    """Small quads Tex_<name>, one per effect texture a venue's effects use (its TEXTURES), so
    importing the venue's FBX also brings those textures in (ModelLibrary.carrierTexture)."""
    carriers = []
    coll = common.collection("Textures_" + venue)
    for i, name in enumerate(names):
        path = os.path.join(common.TEXTURES, name + ".png")
        if not os.path.exists(path):
            print(f"[maps] WARNING: no texture {path} (run art/scripts/run_textures.py)")
            continue
        obj_name = "Tex_" + name
        old = bpy.data.objects.get(obj_name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
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
        mesh.from_pydata([(-1, 0, -1), (1, 0, -1), (1, 0, 1), (-1, 0, 1)], [], [(0, 1, 2, 3)])
        uv = mesh.uv_layers.new(name="UVMap")
        for loop, co in zip(uv.data, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop.uv = co
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(obj_name, mesh)
        coll.objects.link(obj)
        obj.location = (i * 3.0, -60.0, 0.0)
        obj["dg_texture"] = True
        carriers.append(obj)
    return carriers


def rewrite_materials():
    import re

    with open(export.MATERIALS_LUAU, encoding="utf-8") as f:
        used = set(re.findall(r"^	(\w+) = \{", f.read(), re.M))
    print("[maps] materials", export.write_materials(used), len(used))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--materials" in argv:
        rewrite_materials()
        return
    names = [a for a in argv if a in VENUES] or VENUES
    eyes = None
    if "--eyes" in argv:
        # "px,py,pz,tx,ty,tz[,lens];..." in Roblox studs: ad-hoc perspective views (props, lights and signs
        # on), written as eye_<Venue>_<n>.png.
        eyes = []
        for spec in argv[argv.index("--eyes") + 1].split(";"):
            v = [float(n) for n in spec.split(",")]
            eyes.append(((v[0], v[1], v[2]), (v[3], v[4], v[5]), v[6] if len(v) > 6 else 28.0))
    preview = "--preview" in argv or eyes is not None
    do_export = "--export" in argv
    plan = "--plan" in argv
    if "--out" in argv:
        # Scratch renders (not the tracked previews).
        common.PREVIEWS = os.path.abspath(argv[argv.index("--out") + 1])
        os.makedirs(common.PREVIEWS, exist_ok=True)
    propplans = None
    if "--proplan" in argv:
        # --tile 64x48 --ppu 30 --levels ground,upper --region x0,z0,x1,z1 (all optional)
        tile = argv[argv.index("--tile") + 1] if "--tile" in argv else "64x48"
        region = argv[argv.index("--region") + 1] if "--region" in argv else None
        levels = argv[argv.index("--levels") + 1] if "--levels" in argv else None
        propplans = {
            "tile": tuple(float(n) for n in tile.split("x")),
            "ppu": float(argv[argv.index("--ppu") + 1]) if "--ppu" in argv else 30.0,
            "bright": float(argv[argv.index("--bright") + 1]) if "--bright" in argv else 2.2,
            "levels": set(levels.split(",")) if levels else None,
            "region": tuple(float(n) for n in region.split(",")) if region else None,
        }
    common.clear_scene()
    images = matlib.make_textures()
    mesher.use_images(images)
    built = []
    for name in names:
        scene, module, coll = build_venue(name)
        built.append((scene, module, coll))
    if preview:
        for scene, module, coll in built:
            others = [c for s2, m2, c in built if c is not coll]
            for c in others:
                c.hide_render = True
            # Things the game builds itself (table, screens...) only appear in previews.
            stand_in = mesher.Scene(scene.venue + "Preview")
            if hasattr(module, "preview"):
                module.preview(stand_in)
            stand_coll = common.collection("Preview_" + scene.venue)
            stand_in.finish(stand_coll)
            extra = (place_props(scene, coll) + place_props(stand_in, stand_coll) + add_lights(scene, coll)
                     + prop_lights(scene, coll) + draw_signs(scene, coll))
            only = None
            if "--views" in argv:
                only = {int(v) for v in argv[argv.index("--views") + 1].split(",")}
            if eyes is not None:
                print("[maps] eyes", render_views(scene.venue, module, scene, only, views=eyes, tag="eye"))
            else:
                print("[maps] previews", render_views(scene.venue, module, scene, only))
            for obj in set(extra) | set(stand_coll.objects):
                bpy.data.objects.remove(obj, do_unlink=True)
            for c in others:
                c.hide_render = False
    if plan:
        for scene, module, coll in built:
            others = [c for s2, m2, c in built if c is not coll]
            for c in others:
                c.hide_render = True
            print("[maps] plans", render_plans(scene, module))
            for c in others:
                c.hide_render = False
    if propplans is not None:
        for scene, module, coll in built:
            others = [c for s2, m2, c in built if c is not coll]
            for c in others:
                c.hide_render = True
            written = render_propplans(scene, module, coll, propplans)
            print(f"[maps] prop plans: {len(written)} tiles in {common.PREVIEWS}")
            for c in others:
                c.hide_render = False
    if "--massing" in argv:
        for scene, module, coll in built:
            print("[maps] massing", render_massing(scene, module))
    if do_export:
        used = set()
        for scene, module, coll in built:
            used |= scene.used
            source = f"art/scripts/maps/venues/{MODULES[scene.venue]}"
            version, paths = export.write_scene_v2(scene, module, source)
            objects = [o for o in coll.objects if o.type == "MESH"]
            objects.extend(export.calibration_cubes(common.collection("Calibration_" + scene.venue),
                                                    "Calib_" + scene.venue, "Maps" + scene.venue, version))
            objects.extend(texture_carriers(getattr(module, "TEXTURES", ()), scene.venue))
            path = export.export_fbx(objects, export.venue_fbx(scene.venue))
            size = os.path.getsize(path) / 1e6
            print(f"[maps] {scene.venue} v{version}: {path} ({size:.1f} MB, {len(objects)} objects)")
            if size > 50:
                print(f"[maps] WARNING: {scene.venue}'s FBX is over 50 MB; Studio may refuse it. Split the venue.")
            for p in paths:
                print("[maps]   wrote", p)
        export.write_materials(used | set(matlib.FLAT))
        common.save_blend(f"Maps_{'_'.join(names)}.blend")


main()
