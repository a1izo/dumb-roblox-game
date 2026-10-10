"""Writes what the game needs from the map scenes (every venue, the lobby and the meeting room
included, has its own):
  src/server/Maps/Scenes/<Venue>/        its layout, anchors, colliders, props, lights, signs...
  src/shared/SceneMaterials.luau         how the game dresses each flat material
  src/shared/MapBounds.luau              each map's Specter box
  art/export/DeathsGambitMaps_<Venue>.fbx every scene mesh (with its textures) plus three calibration
                                         cubes the game uses to undo whatever scale and rotation
                                         the importer applied
"""

import hashlib
import json
import os
import re
import shutil

import bpy

import common
from maps import matlib

SCENES_DIR = os.path.join(common.ROOT, "src", "server", "Maps", "Scenes")
MATERIALS_LUAU = os.path.join(common.ROOT, "src", "shared", "SceneMaterials.luau")

# Calibration cubes: their centres sit at these Roblox positions in the scene space.
CALIBRATION = {"_O": (0, 0, 0), "_X": (64, 0, 0), "_Y": (0, 64, 0)}

# Bumped whenever a props export changes in a way the game depends on. The FBX carries a marker
# mesh DeathsGambit<Kind>_Version_<n>, and the game uses only the newest import of each kind. (The maps'
# versions come from their mesh digests, see next_version.)
VERSION = {"ModelsCore": 2, "ModelsTokyo": 2, "ModelsAgency": 2, "ModelsCampus": 1, "ModelsLobby": 1,
           "ModelsMeeting": 1}


def num(v, digits=3):
    text = f"{v:.{digits}f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def vec(values, digits=3):
    return "{ " + ", ".join(num(v, digits) for v in values) + " }"


def rgb(values):
    return "{ " + ", ".join(str(int(v)) for v in values) + " }"


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def materials_listed():
    """The materials src/shared/SceneMaterials.luau lists now."""
    if not os.path.exists(MATERIALS_LUAU):
        return set()
    with open(MATERIALS_LUAU, encoding="utf-8") as f:
        return set(re.findall(r"^\t(\w+) = \{", f.read(), re.M))


def write_materials(used, merge=True):
    """Writes SceneMaterials.luau for `used`, keeping the materials already listed (other venues
    exported earlier still need theirs) unless merge is False."""
    names = set(used) | (materials_listed() if merge else set())
    with open(MATERIALS_LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write(matlib.luau_table(names))
    return MATERIALS_LUAU


def _cube(name, x, y, z, collection, half=0.5):
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    mesh = bpy.data.meshes.new(name)
    h = half
    verts = [(-h, -h, -h), (h, -h, -h), (h, h, -h), (-h, h, -h), (-h, -h, h), (h, -h, h), (h, h, h), (-h, h, h)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh.from_pydata(verts, [], faces)
    mesh.uv_layers.new(name="UVMap")
    mesh.materials.append(matlib.material("BlackTrim"))
    obj = bpy.data.objects.new(name, mesh)
    obj.location = (-x, z, y)  # Roblox -> Blender
    collection.objects.link(obj)
    return obj


def calibration_cubes(collection, prefix, kind, version=None):
    """The three cubes that tell the game how the importer moved, turned and scaled the file,
    plus the version marker."""
    objects = [_cube(prefix + suffix, x, y, z, collection) for suffix, (x, y, z) in CALIBRATION.items()]
    number = version if version is not None else VERSION[kind]
    objects.append(_cube(f"DeathsGambit{kind}_Version_{number}", 0, -40, 0, collection, half=0.25))
    return objects


def export_fbx(objects, path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="Z",
        axis_up="Y",
        bake_space_transform=True,
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        use_tspace=True,
        path_mode="COPY",
        embed_textures=True,
        add_leaf_bones=False,
    )
    return path


# Big venues (format 2): one FBX each, a folder module of scene data, a JSON copy for checks -----

MAP_BOUNDS_LUAU = os.path.join(common.ROOT, "src", "shared", "MapBounds.luau")
SIDECAR_DIR = os.path.join(common.EXPORT, "scenes")


def venue_fbx(venue):
    return os.path.join(common.EXPORT, f"DeathsGambitMaps_{venue}.fbx")


def mesh_digest(scene):
    """A fingerprint of the meshes (what the Studio import carries): it changes when the
    geometry changes, not when only colliders, props or lights do."""
    h = hashlib.sha1()
    for mat in sorted(scene.pieces):
        pieces = scene.pieces[mat]
        tris = sum(len(p.faces) for p in pieces)
        sx = sy = sz = 0.0
        for p in pieces:
            for x, y, z in p.verts:
                sx += x
                sy += y
                sz += z
        h.update(f"{mat}:{tris}:{sx:.1f}:{sy:.1f}:{sz:.1f};".encode())
    h.update(f"chunk:{scene.chunk};prefix:{scene.prefix}".encode())
    return h.hexdigest()[:16]


def _previous(folder):
    path = os.path.join(folder, "init.luau")
    if not os.path.exists(path):
        return 0, ""
    text = open(path, encoding="utf-8").read()
    version = re.search(r"^\tversion = (\d+),", text, re.M)
    digest = re.search(r"^-- mesh digest: (\w+)", text, re.M)
    return (int(version.group(1)) if version else 0), (digest.group(1) if digest else "")


def next_version(scene):
    """(version, digest): the version goes up only when the meshes changed since the last
    export, so the Studio import is only needed again then."""
    folder = os.path.join(SCENES_DIR, scene.venue)
    old_version, old_digest = _previous(folder)
    digest = mesh_digest(scene)
    if digest == old_digest and old_version > 0:
        return old_version, digest
    return old_version + 1, digest


def _lua(value, digits=3):
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "nil"
    if isinstance(value, (int, float)):
        return num(value, digits)
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, (list, tuple)):
        return ("{ " + ", ".join(_lua(v, digits) for v in value) + " }") if value else "{}"
    if isinstance(value, dict):
        parts = []
        for k, v in value.items():
            if v is None:
                continue
            key = k if re.match(r"^[A-Za-z_]\w*$", k) else f"[{lua_string(k)}]"
            parts.append(f"{key} = {_lua(v, digits)}")
        return ("{ " + ", ".join(parts) + " }") if parts else "{}"
    raise TypeError(value)


def _header(source, what):
    return [
        "--!strict",
        f"-- GENERATED by art/scripts/run_maps.py from {source}. Do not edit by hand.",
        f"-- {what}",
        "",
    ]


def _write(path, lines):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return path


def _items(lines, name, items, comment=None, indent="\t"):
    if comment:
        lines.append(f"{indent}-- {comment}")
    if not items:
        lines.append(f"{indent}{name} = {{}},")
        return
    lines.append(f"{indent}{name} = {{")
    for item in items:
        lines.append(f"{indent}\t{_lua(item)},")
    lines.append(f"{indent}}},")


# Roblox keeps a script's source under about 200 000 characters: longer lists go in chunks.
CHUNK_CHARS = 150_000


def _module(path, source, what, fields):
    """A generated ModuleScript as a folder (path/init.luau) returning a table of `fields`:
    (comment, key, value) where value is a Luau expression or a list of entry expressions. Long
    lists are written to child modules (<Key>1, <Key>2...) and joined when required."""
    os.makedirs(path, exist_ok=True)
    body, written, joined = [], [], False
    for comment, key, value in fields:
        if comment:
            body.append(f"\t-- {comment}")
        if isinstance(value, str):
            body.append(f"\t{key} = {value},")
            continue
        size = sum(len(e) + 4 for e in value)
        if size < CHUNK_CHARS:
            if not value:
                body.append(f"\t{key} = {{}},")
                continue
            body.append(f"\t{key} = {{")
            body += [f"\t\t{e}," for e in value]
            body.append("\t},")
            continue
        chunks, current, current_size = [], [], 0
        for e in value:
            if current and current_size + len(e) + 4 > CHUNK_CHARS:
                chunks.append(current)
                current, current_size = [], 0
            current.append(e)
            current_size += len(e) + 4
        if current:
            chunks.append(current)
        names = []
        for i, chunk in enumerate(chunks, 1):
            name = key[0].upper() + key[1:] + str(i)
            names.append(name)
            lines = _header(source, f"Part {i} of {len(chunks)} of {key}.") + ["return {"]
            lines += [f"\t{e}," for e in chunk] + ["}"]
            written.append(_write(os.path.join(path, name + ".luau"), lines))
        body.append(f"\t{key} = join({{ " + ", ".join(f"require(script.{n}) :: any" for n in names) + " }),")
        joined = True
    lines = _header(source, what)
    if joined:
        lines += [
            "local function join(parts: { { any } }): { any }",
            "\tlocal out = {}",
            "\tfor _, part in ipairs(parts) do",
            "\t\ttable.move(part, 1, #part, #out + 1, out)",
            "\tend",
            "\treturn out",
            "end",
            "",
        ]
    lines += ["return {"] + body + ["}"]
    written.insert(0, _write(os.path.join(path, "init.luau"), lines))
    return written


def _zone_entry(zone):
    flat = []
    for x, z in zone["poly"]:
        flat.extend((round(x, 2), round(z, 2)))
    out = {"kind": zone["kind"], "y0": zone["y0"], "y1": zone["y1"], "points": flat}
    if zone.get("name"):
        out["name"] = zone["name"]
    return out


def write_scene_v2(scene, module, source):
    """Writes src/server/Maps/Scenes/<Venue>/ (init, Layout, Geometry, Dressing) and the JSON
    copy the checks read. Returns (version, paths)."""
    venue = scene.venue
    folder = os.path.join(SCENES_DIR, venue)
    version, digest = next_version(scene)
    if os.path.isdir(folder):
        shutil.rmtree(folder)
    os.makedirs(folder, exist_ok=True)
    legacy = os.path.join(SCENES_DIR, venue + ".luau")
    if os.path.exists(legacy):
        os.remove(legacy)
    map_id = getattr(module, "MAP_ID", None)
    kind = "Maps" + venue
    lo, hi = scene.bounds or ((-100, -10, -100), (100, 60, 100))
    looks = sorted({c[8] for c in scene.colliders if c[8]} | {r["look"] for r in scene.ramps if r["look"]}
                   | {f[8] for f in scene.floors if f[8]} | {st[3] for st in scene.steps})
    look_index = {name: i + 1 for i, name in enumerate(looks)}
    stats = {
        "materials": len(scene.pieces),
        "triangles": scene.triangles(),
        "colliders": len(scene.colliders),
        "floors": len(scene.floors),
        "ramps": len(scene.ramps),
        "props": len(scene.props),
        "lights": len(scene.lights),
        "signs": len(scene.signs),
    }
    fbx_name = os.path.basename(venue_fbx(venue))

    init = _header(source, f"The {venue} scene: its meshes are {scene.prefix}_{venue}_* in {fbx_name}.")
    init.insert(3, f"-- mesh digest: {digest}")
    init += [
        "return {",
        "\tformat = 2,",
        f"\tvenue = {lua_string(venue)},",
        f"\tmapId = {lua_string(map_id) if map_id else 'nil'},",
        f"\tversion = {version},",
        f"\tmeshPrefix = {lua_string(scene.prefix + '_' + venue + '_')},",
        f"\tcalibration = {lua_string('Calib_' + venue)},",
        f"\tmarker = {lua_string(f'DeathsGambit{kind}_Version_{version}')},",
        f"\tfbx = {lua_string(fbx_name)},",
        f"\tbounds = {{ min = {vec(lo)}, max = {vec(hi)} }},",
        f"\tstats = {_lua(stats)},",
        "\tlayout = require(script.Layout),",
        "\tgeometry = require(script.Geometry),",
        "\tdressing = require(script.Dressing),",
        "}",
    ]

    L = scene.layout
    layout_fields = [
        (None, "stations", [_lua(x) for x in L["stations"]]),
        (None, "tipBox", _lua(L["tipBox"]) if L["tipBox"] else "nil"),
        (None, "board", _lua(L["board"]) if L["board"] else "nil"),
    ]
    for kind_name in ("spawns", "sheets", "hoods", "areas"):
        layout_fields.append((None, kind_name, [_lua(x) for x in L[kind_name]]))
    layout_fields.append(("Spare spots of each kind, not used by the game yet (for a later rework of the counts).",
                          "spare", _lua(scene.spare)))
    layout_fields.append(("What kind of ground each place is: kind, floor height (y0 to y1 on slopes), corners x1, z1, x2, z2...",
                          "zones", [_lua(_zone_entry(z)) for z in scene.zones]))
    layout_fields.append((None, "anchors", _lua(scene.anchors)))

    colliders = []
    for c in scene.colliders:
        x, y, z, sx, sy, sz, rot, query, look = c
        colliders.append(f"{{ {num(x)}, {num(y)}, {num(z)}, {num(sx)}, {num(sy)}, {num(sz)}, {num(rot, 2)}, "
                         f"{'true' if query else 'false'}, {look_index.get(look, 0)} }}")
    floors = []
    for f in scene.floors:
        x1, z1, x2, z2, x3, z3, y, thick, look, query = f
        floors.append(f"{{ {num(x1)}, {num(z1)}, {num(x2)}, {num(z2)}, {num(x3)}, {num(z3)}, {num(y)}, {num(thick)}, "
                      f"{look_index.get(look, 0)}, {'true' if query else 'false'} }}")
    ramps = []
    for r in scene.ramps:
        (x, y, z), (w, t_, length) = r["at"], r["size"]
        ramps.append(f"{{ {num(x)}, {num(y)}, {num(z)}, {num(w)}, {num(t_)}, {num(length)}, {num(r['rot'], 2)}, "
                     f"{num(r['pitch'], 2)}, {'true' if r['query'] else 'false'}, {look_index.get(r['look'], 0)} }}")
    steps = [f"{{ {num(c[0])}, {num(c[1])}, {num(c[2])}, {num(sz[0])}, {num(sz[1])}, {num(sz[2])}, {num(rot, 2)}, "
             f"{look_index.get(look, 0)} }}" for c, sz, rot, look in scene.steps]
    geometry_fields = [
        (None, "looks", _lua(looks)),
        ("x, y, z, size x, y, z, degrees about Y, blocks sight lines, look (index into looks, 0 = never shown)",
         "colliders", colliders),
        ("flat floor triangles: x1, z1, x2, z2, x3, z3, top y, thickness, look, blocks sight lines", "floors", floors),
        ("centre x, y, z, width, thickness, length, degrees about Y (facing uphill), pitch, blocks sight lines, look",
         "ramps", ramps),
        ("the steps drawn over each stair's ramp (greybox only): centre x, y, z, size x, y, z, degrees, look",
         "steps", steps),
    ]

    props = [f'{{ "{p[0]}", {num(p[1])}, {num(p[2])}, {num(p[3])}, {num(p[4], 2)}, {num(p[5])}'
             + (f', "{p[6]}"' if len(p) > 6 and p[6] else "") + " }" for p in scene.props]
    lights = [
        f'{{ kind = "{li["kind"]}", at = {vec(li["pos"])}, color = {rgb(li["color"])}, '
        f'range = {num(li["range"], 1)}, brightness = {num(li["brightness"], 2)}, '
        f'shadows = {"true" if li["shadows"] else "false"}, face = "{li["face"]}", angle = {num(li["angle"], 1)}, '
        f'flicker = {"true" if li["flicker"] else "false"}'
        + (f', role = "{li["role"]}"' if li.get("role") else "") + " }"
        for li in scene.lights
    ]
    signs = []
    for sg in scene.signs:
        bg = rgb(sg["bg"]) if sg["bg"] else "nil"
        glow = rgb(sg["glow"]) if sg["glow"] else "nil"
        signs.append(
            f'{{ at = {vec(sg["pos"])}, rot = {num(sg["rot"], 2)}, w = {num(sg["w"])}, h = {num(sg["h"])}, '
            f'text = {lua_string(sg["text"])}, font = "{sg["font"]}", color = {rgb(sg["color"])}, bg = {bg}, '
            f'glow = {glow}, align = "{sg["align"]}" }}'
        )
    emitters = [f'{{ kind = "{em["kind"]}", at = {vec(em["pos"])}, rot = {num(em["rot"], 2)}'
                + (f', size = {vec(em["size"])}' if em.get("size") else "") + " }" for em in scene.emitters]
    covers = [f'{{ at = {vec(c[0])}, size = {vec(c[1])}, rot = {num(c[2], 2)}, amount = {num(c[3], 2)} }}'
              for c in scene.covers]
    blinkers = [f'{{ at = {vec(b["pos"])}, color = {rgb(b["color"])}, period = {num(b["period"], 2)}, '
                f'size = {num(b["size"], 2)}, phase = {num(b["phase"], 2)} }}' for b in scene.blinkers]
    heli = scene.helicopter
    helicopter = (f'{{ path = {{ {", ".join(vec(p) for p in heli["path"])} }}, '
                  f'target = {{ {", ".join(vec(p) for p in heli["target"])} }}, every = {num(heli["every"], 1)}, '
                  f'duration = {num(heli["duration"], 1)} }}') if heli else "nil"
    screens = [f'{{ at = {vec(sc["pos"])}, rot = {num(sc["rot"], 2)}, w = {num(sc["w"])}, h = {num(sc["h"])}, '
               f'loop = {lua_string(sc["loop"])} }}' for sc in scene.screens]
    sounds = [f'{{ key = {lua_string(so["key"])}, at = {vec(so["pos"])}, radius = {num(so["radius"], 1)}, '
              f'volume = {num(so["volume"], 2)}, loop = {"true" if so["loop"] else "false"} }}' for so in scene.sounds]
    look_zones = [f'{{ preset = {lua_string(z["preset"])}, min = {vec(z["min"])}, max = {vec(z["max"])} }}'
                  for z in scene.look_zones]
    waters = [f'{{ at = {vec(w["at"])}, size = {vec(w["size"])}, rot = {num(w["rot"], 2)} }}' for w in scene.waters]
    clocks = [f'{{ at = {vec(c["pos"])}, rot = {num(c["rot"], 2)}, radius = {num(c["radius"], 2)} }}'
              for c in scene.clocks]
    dressing_fields = [
        ("prop, x, y, z, degrees about Y, scale, flags (\"dark\": without its light)", "props", props),
        (None, "lights", lights),
        (None, "signs", signs),
        (None, "emitters", emitters),
        ("boxes that shelter from rain and snow without being solid (awnings, canopies, tree crowns): "
         "centre, size, degrees about Y, how much they stop (1 all, 0.5 half)", "covers", covers),
        ("giant screens the client plays loops on: where the face is, facing rot", "screens", screens),
        ("ambient sounds: an Assets.sfx key (silent while its slot is empty), where, how far it carries",
         "sounds", sounds),
        ("the metro train's run for the client: its path along the platform, where it stops, the cars",
         "train", _lua(scene.train) if scene.train else "nil"),
        ("boxes where the camera switches to a lighting look of their own (LightingPresets.maps)",
         "lookZones", look_zones),
        ("boxes the game fills with Terrain water (centre, size, degrees about Y)", "water", waters),
        ("small lamps the client blinks (aircraft warning lights): where, colour, seconds per blink, size",
         "blinkers", blinkers),
        ("the searchlight helicopter's flight for the client: its path, where its light points, how often",
         "helicopter", helicopter),
        ("clock faces whose hands the client turns: the middle of the dial, facing rot, its radius",
         "clocks", clocks),
    ]

    paths = [_write(os.path.join(folder, "init.luau"), init)]
    paths += _module(os.path.join(folder, "Layout"), source,
                     "Where the game puts its gameplay objects (local to the venue's origin; y is the floor).", layout_fields)
    paths += _module(os.path.join(folder, "Geometry"), source,
                     "The solid parts: invisible colliders (shown in their look when the meshes are not imported) and walkable slopes.",
                     geometry_fields)
    paths += _module(os.path.join(folder, "Dressing"), source,
                     "Props from the prop library, lights, signs and particle emitters.", dressing_fields)
    os.makedirs(SIDECAR_DIR, exist_ok=True)
    sidecar = {
        "venue": venue,
        "mapId": map_id,
        "version": version,
        "bounds": {"min": list(lo), "max": list(hi)},
        "colliders": [list(c) for c in scene.colliders],
        "floors": [list(f) for f in scene.floors],
        "ramps": scene.ramps,
        "props": [list(p) for p in scene.props],
        "propSrc": scene.prop_src,
        "openings": [list(o) for o in scene.openings],
        "lights": scene.lights,
        "layout": scene.layout,
        "spare": scene.spare,
        "zones": scene.zones,
        "anchors": scene.anchors,
        "stats": stats,
        "checks": scene.checks,
    }
    side_path = os.path.join(SIDECAR_DIR, venue + ".json")
    with open(side_path, "w", encoding="utf-8") as f:
        json.dump(sidecar, f)
    paths.append(side_path)
    if map_id and scene.bounds:
        paths.append(write_map_bounds(map_id, lo, hi))
    return version, paths


def write_map_bounds(map_id, lo, hi):
    """src/shared/MapBounds.luau: every Blender-built map's Specter box, merged with the maps
    exported before."""
    entries = {}
    if os.path.exists(MAP_BOUNDS_LUAU):
        text = open(MAP_BOUNDS_LUAU, encoding="utf-8").read()
        for m in re.finditer(r"^\t(\w+) = (\{ min = .*? \}),$", text, re.M):
            entries[m.group(1)] = m.group(2)
    entries[map_id] = f"{{ min = {vec(lo)}, max = {vec(hi)} }}"
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/run_maps.py: the box Specters stay inside on each map built from a",
        "-- Blender scene, local to the map's origin (Venues.MAP).",
        "",
        "return {",
    ]
    for key in sorted(entries):
        lines.append(f"\t{key} = {entries[key]},")
    lines.append("}")
    return _write(MAP_BOUNDS_LUAU, lines)
