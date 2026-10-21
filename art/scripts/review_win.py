"""Win cutscene review renders: a paid win cutscene's set (src/shared/Cinema/WinCuts.luau: its Core props, parts,
city, board and pieces), its star on the R6 mannequin in the cutscene's clip holding what EmoteMeta gives it, seen
through the cutscene's own shots (background Blender):

    blender -b --factory-startup --python art/scripts/review_win.py -- cut [cut ...] [--build] [--size=480]

For each cut it writes art/export/previews/wins/<cut>/shot<i>_<a|b|c>.png (each shot's start, middle and end) and
sheet.png (a row a shot). The set is what the game builds before anything happens to it (the events, the candles going
out and the city dying, are not drawn): it shows the framing, not the effects.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import emotemeta  # noqa: E402
import review_emote as rv  # noqa: E402

WINCUTS = os.path.join(emotemeta.ROOT, "src", "shared", "Cinema", "WinCuts.luau")
OUT = os.path.join(common.PREVIEWS, "wins")
AXES4 = rv.AXES.to_4x4()  # Roblox-like (x right, y up, z back) to the rig's Blender frame
FLOOR = [AXES4]  # the floor under the rig, as review_emote.socket_world gives it (the rig object turned)


def rgb(c):
    v = tuple(common.srgb(*c))
    return v if len(v) == 4 else (v[0], v[1], v[2], 1.0)


def material(name, color, glow=False, alpha=0.0, rough=0.7, metal=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = rgb(color)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if glow:
        bsdf.inputs["Emission Color"].default_value = rgb(color)
        bsdf.inputs["Emission Strength"].default_value = 2.0
    if alpha > 0:
        bsdf.inputs["Alpha"].default_value = 1 - alpha
        for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(mat, attr, value)
                break
            except (AttributeError, TypeError):
                continue
    return mat


def angles(rot):
    rx, ry, rz = (math.radians(v) for v in (rot or (0, 0, 0)))
    return (Matrix.Rotation(rx, 4, "X") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rz, 4, "Z"))


def part(spec, coll):
    """A plain part as the game makes it: its shape's own axes (a Roblox cylinder runs along x)."""
    if spec.get("alpha", 0) >= 1:
        return None
    shape = spec.get("shape", "Block")
    sx, sy, sz = spec["size"]
    if shape == "Cylinder":
        bpy.ops.mesh.primitive_cylinder_add(radius=1, depth=2, vertices=24)
        local = Matrix(((0, 0, sx / 2, 0), (sy / 2, 0, 0, 0), (0, sz / 2, 0, 0), (0, 0, 0, 1)))
    elif shape == "Ball":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=20, ring_count=12)
        local = Matrix.Diagonal((sx / 2, sy / 2, sz / 2, 1))
    else:
        bpy.ops.mesh.primitive_cube_add(size=2)
        local = Matrix.Diagonal((sx / 2, sy / 2, sz / 2, 1))
    obj = bpy.context.active_object
    for c in obj.users_collection:
        c.objects.unlink(obj)
    coll.objects.link(obj)
    obj.matrix_world = FLOOR[0] @ Matrix.Translation(spec["at"]) @ angles(spec.get("rot")) @ local
    color = spec.get("color", (120, 120, 120))
    obj.data.materials.append(material("W_" + "_".join(str(int(v)) for v in color) + ("g" if spec.get("glow") else "")
                                       + ("a" if spec.get("alpha") else ""), color, spec.get("glow", False),
                                       spec.get("alpha", 0.0)))
    return obj


def frac(x):
    return x - math.floor(x)


def hash3(a, b, c):
    """The same small hash as Presentation/WinCinema (so the city is the same buildings)."""
    return frac(math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453)


def city(spec):
    """The skyline: the buildings WinCinema.city makes (their lit windows are not drawn here)."""
    out = []
    row, z = 0, -spec["near"]
    while -z < spec["far"]:
        x = -spec["width"] / 2
        k = 0
        while x < spec["width"] / 2:
            w = 14 + 12 * hash3(row, k, spec["seed"])
            h = spec["low"] + (spec["high"] - spec["low"]) * hash3(row + 17, k, spec["seed"])
            d = 18 + 8 * hash3(row, k + 31, spec["seed"])
            out.append({"size": (w, h, d), "at": (x + w / 2, spec["ground"] + h / 2, z - d / 2),
                        "color": (20 + 10 * hash3(row, k, 3), 20, 26)})
            x += w + 4 + 6 * hash3(row + 5, k, spec["seed"])
            k += 1
        z -= 34
        row += 1
    return out


def board(spec):
    out = []
    n, s = int(spec["squares"]), spec["square"]
    cx, cy, cz = spec["at"]
    for i in range(n):
        for j in range(n):
            x = cx - n * s / 2 + s / 2 + i * s
            z = cz - n * s / 2 + s / 2 + j * s
            out.append({"size": (s, 0.5, s), "at": (x, cy, z), "color": spec["light"] if (i + j) % 2 == 0 else spec["dark"]})
    return out


def piece_parts(kind, color, x, z):
    white = (226, 224, 218) if color == "white" else (22, 22, 24)
    if kind == "pawn":
        shapes = [("Cylinder", (0.8, 3.2, 3.2), 0.4), ("Cylinder", (2.6, 1.8, 1.8), 2.1), ("Ball", (1.9, 1.9, 1.9), 3.9)]
    else:
        shapes = [("Cylinder", (0.9, 3.4, 3.4), 0.45), ("Cylinder", (3.6, 2.4, 2.4), 2.7), ("Cylinder", (0.9, 2.9, 2.9), 4.9)]
    out = []
    for shape, size, y in shapes:
        rot = (0, 0, 90) if shape == "Cylinder" else (0, 0, 0)
        out.append({"shape": shape, "size": size, "rot": rot, "at": (x, y, z), "color": white})
    return out


def strings(spec):
    out = []
    for s in spec:
        a, b = Vector(s["from"]), Vector(s["to"])
        mid = (a + b) / 2
        d = b - a
        yaw = math.degrees(math.atan2(-d.z, d.x)) if abs(d.x) + abs(d.z) > 1e-6 else 0
        roll = math.degrees(math.atan2(d.y, math.hypot(d.x, d.z)))
        out.append({"shape": "Cylinder", "size": (d.length, 0.07, 0.07), "at": tuple(mid), "rot": (0, yaw, roll),
                    "color": (180, 20, 30)})
    return out


def as_meta(cut, held):
    """The cut's Core props as floor props of the clip (review_emote's own placing), with the star's held props."""
    props = list(held or [])
    for p in cut.get("props") or []:
        spec = {"model": p["key"], "size": p["size"], "mount": "floor",
                "at": [{"p": list(p["at"])}, {"r": [0, p.get("turn", 0), 0]}],
                "stand": {"shape": "Block", "size": [p["size"], p["size"] * 0.6, p["size"] * 0.6],
                          "color": list(p.get("color", (90, 90, 90)))}}
        if p.get("open"):
            spec["open"] = 0
        if p.get("hidden"):
            spec["show"] = 99
        props.append(spec)
    return {"props": props}


def camera_at(cam, shot, u):
    """The camera through a shot, `u` (0..1) of the way from its framing to its `to`."""
    to = shot.get("to") or {}
    eye0, look0 = Vector(shot["eye"]), Vector(shot["look"])
    eye = eye0.lerp(Vector(to.get("eye", shot["eye"])), u)
    look = look0.lerp(Vector(to.get("look", shot["look"])), u)
    fov = shot["fov"] + (to.get("fov", shot["fov"]) - shot["fov"]) * u
    e, lk = FLOOR[0] @ eye, FLOOR[0] @ look
    cam.location = e
    cam.rotation_euler = (lk - e).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(fov)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    size = 480
    names = []
    build = False
    for a in argv:
        if a.startswith("--size="):
            size = int(a.split("=", 1)[1])
        elif a == "--build":
            build = True
        else:
            names.append(a)
    cuts = emotemeta.read(WINCUTS)
    meta_all = emotemeta.load()
    cat = emotemeta.catalog()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(common.BLEND, "Animations.blend"))
    for obj in list(bpy.data.objects):
        if obj.type in ("CAMERA", "LIGHT") or obj.name.startswith("label_"):
            bpy.data.objects.remove(obj, do_unlink=True)
    arm = bpy.data.objects["R6"]
    clips = [cuts[n]["clip"] for n in names if n in cuts]
    if build:
        rv.build_fresh(arm, clips)
    parts = {child.name: child for child in arm.children}
    rv.bind_rest(arm, parts)
    FLOOR[0] = arm.matrix_world @ AXES4
    lib = rv.library()
    cam = rv.bench(size)
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = size, int(size * 9 / 16)
    floor = bpy.data.objects.get("Floor")
    if floor is not None:
        floor.hide_render = True
    for name in ("Key", "Fill", "Rim"):  # the bench's lights, softer: the set brings its own
        light = bpy.data.objects.get(name)
        if light is not None:
            light.data.energy *= 0.45
    for name in names:
        cut = cuts.get(name)
        if cut is None:
            print(f"[win] no cut {name}")
            continue
        action = bpy.data.actions.get(cut["clip"])
        if action is None:
            print(f"[win] no action {cut['clip']}")
            continue
        length = float(cut["length"])
        arm.animation_data_create()
        arm.animation_data.action = action
        for obj in list(common.collection("Props").objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        coll = common.collection("WinSet")
        for obj in list(coll.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        end = int(round(length * rv.FPS))
        rv.bake_props(arm, parts, as_meta(cut, (meta_all.get(cut["clip"]) or {}).get("props")), cat, lib,
                      list(range(0, end + 1, 2)), length, False)
        specs = list(cut.get("parts") or [])
        if cut.get("city"):
            specs += city(cut["city"])
        if cut.get("board"):
            specs += board(cut["board"])
        for group in cut.get("pieces") or []:
            for x in group["xs"]:
                specs += piece_parts(group["kind"], group["color"], x, group["z"])
        specs += strings(cut.get("strings") or [])
        for spec in specs:
            if not spec.get("hidden"):
                part(spec, coll)
        for spec in cut.get("parts") or []:  # their lights, roughly (Roblox point lights)
            light = spec.get("light")
            if light and light.get("brightness", 0) > 0:
                data = bpy.data.lights.new("WL", "POINT")
                data.color = rgb(light["color"])[:3]
                data.energy = 60 * light["brightness"] * light["range"] / 9
                obj = bpy.data.objects.new("WL", data)
                coll.objects.link(obj)
                obj.location = FLOOR[0] @ Vector(spec["at"])
        folder = os.path.join(OUT, name)
        os.makedirs(folder, exist_ok=True)
        stills = []
        shots = cut["shots"]
        for i, shot in enumerate(shots):
            t1 = shots[i + 1]["at"] if i + 1 < len(shots) else length
            for tag, u in (("a", 0.0), ("b", 0.5), ("c", 1.0)):
                t = shot["at"] + (t1 - shot["at"]) * u - (0.05 if tag == "c" else 0.0)
                scene.frame_set(int(round(max(0.0, t) * rv.FPS)))
                camera_at(cam, shot, u)
                path = os.path.join(folder, f"shot{i + 1}_{tag}.png")
                rv.render_still(path)
                stills.append(path)
        rv.make_sheet(stills, os.path.join(folder, "sheet.png"), cols=3, tile=size // 2, tall=int(size * 9 / 32))
        print(f"[win] {name}: {folder}")


if __name__ == "__main__":
    main()
