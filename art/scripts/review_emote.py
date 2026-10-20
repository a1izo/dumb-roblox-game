"""Emote review renders: a clip on the R6 mannequin WITH its props, placed exactly the way the game places them
(src/shared/Anim/EmoteMeta.luau, as EmoteController.dress reads it), on a plain bench (background Blender):

    blender -b --factory-startup --python art/scripts/review_emote.py -- clip [clip ...]
        [--seconds=N] [--size=720] [--angle=0] [--angle2=40] [--stills=0.5,1.2] [--video] [--closeup=prop]

For each clip it writes to art/export/previews/emotes/<clip>/:
    <clip>.mp4            the clip (looping ones play two rounds), two views side by side when --angle2 is set
    still_<t>.png         frames at the given times (or at every quarter of the clip without --stills)
    closeup_<t>.png       with --closeup: a tight view on the hand holding that prop, at each still time
Props come from art/blend/Props.blend (the Core models the game imports), scaled to their EmoteMeta size; a
prop with no model there shows its stand-in part. Tosses, carries, stacks, show and hide follow the game's
rules frame by frame, so what is seen here is what the game draws.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
import emotemeta  # noqa: E402

OUT = os.path.join(common.PREVIEWS, "emotes")
FPS = 60  # the actions' keys; videos take every other frame (30 fps)
MAP = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))  # Roblox = MAP @ Blender, for props modelled in Props.blend
# A socket's Roblox-like axes in the rig's Blender frame: Roblox x = Blender x, y = Blender z, z = Blender -y.
AXES = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
FLOOR = 3.0


def parse(argv):
    opts = {"seconds": None, "size": 720, "angle": 0.0, "angle2": None, "stills": None, "video": False,
            "closeup": None, "names": []}
    for a in argv:
        if a.startswith("--") and "=" in a:
            key, value = a[2:].split("=", 1)
            if key in ("seconds", "angle", "angle2"):
                opts[key] = float(value)
            elif key == "size":
                opts[key] = int(value)
            elif key == "stills":
                opts[key] = [float(v) for v in value.split(",") if v]
            else:
                opts[key] = value
        elif a == "--video":
            opts["video"] = True
        elif a == "--build":
            opts["build"] = True
        elif a == "--sheet":
            opts["sheet"] = True
        elif a == "--mirror":
            opts["mirror"] = True
        else:
            opts["names"].append(a)
    return opts


# Scene -----------------------------------------------------------------------------------------------------


def bench(size):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.05, 0.05, 0.055, 1)
    bg.inputs["Strength"].default_value = 1.0
    scene.view_settings.view_transform = "AgX"
    # floor and a backdrop, grey like the game's Grey Realm stone, a grid every stud to read slides by
    floor = bpy.data.objects.get("Floor")
    if floor is None:
        mesh = bpy.data.meshes.new("Floor")
        mesh.from_pydata([(-12, -12, 0), (12, -12, 0), (12, 12, 0), (-12, 12, 0)], [], [(0, 1, 2, 3)])
        floor = bpy.data.objects.new("Floor", mesh)
        scene.collection.objects.link(floor)
    mat = bpy.data.materials.new("BenchFloor")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    checker = nodes.new("ShaderNodeTexChecker")
    checker.inputs["Scale"].default_value = 24.0
    checker.inputs["Color1"].default_value = (0.20, 0.20, 0.21, 1)
    checker.inputs["Color2"].default_value = (0.17, 0.17, 0.18, 1)
    coord = nodes.new("ShaderNodeTexCoord")
    links.new(coord.outputs["Object"], checker.inputs["Vector"])
    links.new(checker.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    floor.data.materials.clear()
    floor.data.materials.append(mat)
    floor.location = (0, 0, 0)
    floor.dimensions = (24, 24, 0)
    for name, energy, at in (("Key", 1400, (-5, 7, 9)), ("Fill", 500, (7, 5, 5)), ("Rim", 900, (2, -8, 7))):
        data = bpy.data.lights.new(name, "AREA")
        data.energy = energy
        data.size = 5
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        light.location = at
        light.rotation_euler = (Vector((0, 0, 2.5)) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    cam_data = bpy.data.cameras.new("BenchCam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("BenchCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def aim(cam, target, distance, angle, height=1.0):
    """The camera `distance` from `target` (Blender), `angle` degrees round from the front (the rig faces +Y)."""
    a = math.radians(angle)
    t = Vector(target)
    cam.location = t + Vector((math.sin(a) * distance, math.cos(a) * distance, height))
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()


# Props -----------------------------------------------------------------------------------------------------

_LIBRARY = {}


def library():
    path = os.path.join(common.BLEND, "Props.blend")
    if _LIBRARY or not os.path.exists(path):
        return _LIBRARY
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if not n.startswith("Tex_")]
    for obj in dst.objects:
        if obj is not None:
            _LIBRARY[obj.name] = obj
    for img in bpy.data.images:
        p = bpy.path.abspath(img.filepath) if img.filepath else ""
        if p and not os.path.exists(p):
            local = os.path.join(common.TEXTURES, os.path.basename(p.replace("\\", "/")))
            if os.path.exists(local):
                img.filepath = local
                img.reload()
    return _LIBRARY


def stand_in(prop):
    """The plain part the game shows before an import (EmoteController.build), as a mesh in Roblox-like axes."""
    shape, (sx, sy, sz) = prop["stand"]["shape"], prop["stand"]["size"]
    color = [c / 255 for c in prop["stand"]["color"]]
    mat = common.material("Stand_" + prop["model"], common.srgb(*prop["stand"]["color"]), 0.6)
    del color
    if shape == "Ball":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=sx / 2, segments=20, ring_count=12)
    elif shape == "Cylinder":
        # a Roblox cylinder runs along X; the game turns the stand-in to run along Y (Roblox), Blender z here
        bpy.ops.mesh.primitive_cylinder_add(radius=sy / 2, depth=sx, vertices=20)
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        bpy.context.object.scale = (sx, sz, sy)
        bpy.ops.object.transform_apply(scale=True)
    obj = bpy.context.object
    obj.data.materials.append(mat)
    if prop["mount"] == "floor" and shape != "Ball":
        for v in obj.data.vertices:  # pivot at the bottom, like the game's floor stand-ins
            v.co.z += sy / 2 if shape != "Cylinder" else sx / 2
    obj.name = "Stand_" + prop["model"]
    # the mesh is in Blender axes already; flag it so placement skips the model turn
    obj["roblox_axes"] = True
    return obj


def make_prop(prop, cat, lib):
    """A free-standing copy of the prop (its pieces parented to it), and its local turn+scale matrix."""
    src = lib.get(prop["model"])
    if src is None:
        obj = stand_in(prop)
        # stand-in meshes are built in Blender axes: Roblox-like local = AXES^-1 turns them into the socket frame
        return obj, AXES.inverted().to_4x4()
    obj = src.copy()
    if src.data is not None:
        obj.data = src.data
    common.collection("Props").objects.link(obj)
    import json

    for name in json.loads(src["parts"]) if src.get("parts") else []:
        part = lib.get(prop["model"] + "_" + name)
        if part is None:
            continue
        piece = part.copy()
        common.collection("Props").objects.link(piece)
        piece.parent = obj
        piece.matrix_parent_inverse = Matrix.Identity(4)
        piece.matrix_basis = Matrix.Identity(4)
        # Death's Manual held open (EmoteMeta `open`): each piece turned about its hinge as ManualBook does (the
        # catalog's hinge is in Roblox axes from the pivot; its turn is about Roblox Z, which is Blender Y)
        entry = cat.get(prop["model"]) or {}
        hinge, turn = (entry.get("hinge") or {}).get(name), (entry.get("turn") or {}).get(name)
        if prop.get("open") is not None and hinge and turn:
            hb = Vector((-hinge[0], hinge[2], hinge[1]))
            piece.matrix_basis = (Matrix.Translation(hb) @ Matrix.Rotation(math.radians(-turn), 4, "Y")
                                  @ Matrix.Translation(-hb))
    s = emotemeta.prop_scale(prop, cat) or 1.0
    return obj, MAP.to_4x4() @ Matrix.Scale(s, 4)


def np_to_matrix(m):
    return Matrix([list(row) for row in m])


def socket_world(arm, parts, part):
    """The world matrix of a body part's middle with Roblox-like axes (Blender), this frame."""
    if part == "floor":
        return arm.matrix_world @ Matrix.Translation((0, 0, 0)) @ AXES.to_4x4()
    mesh = parts[part + "_Mesh"]
    centre = mesh.matrix_world @ ((Vector(mesh.bound_box[0]) + Vector(mesh.bound_box[6])) / 2)
    rot = mesh.matrix_world.to_3x3().normalized() @ REST_FIX[part]
    return Matrix.Translation(centre) @ rot.to_4x4()


REST_FIX = {}


def bind_rest(arm, parts):
    """Each part's rest rotation to the Roblox-like socket frame (so sockets follow the parts as in the game)."""
    pose_position = arm.data.pose_position
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    for name in ("Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg"):
        mesh = parts[name + "_Mesh"]
        rest = mesh.matrix_world.to_3x3().normalized()
        REST_FIX[name] = rest.inverted() @ (arm.matrix_world.to_3x3() @ AXES)
    arm.data.pose_position = pose_position
    bpy.context.view_layer.update()


def key_matrix(obj, frame, m, visible=True):
    obj.matrix_world = m if visible else m @ Matrix.Scale(0.0001, 4)
    obj.keyframe_insert("location", frame=frame)
    obj.keyframe_insert("rotation_quaternion", frame=frame)
    obj.keyframe_insert("scale", frame=frame)


def bake_props(arm, parts, meta, cat, lib, frames, length, loop):
    """Keys every prop (and every stacked copy) frame by frame, following the game's rules."""
    scene = bpy.context.scene
    made = []
    for prop in meta.get("props") or []:
        stack = prop.get("stack")
        copies = len(stack["times"]) if stack else 1
        for k in range(copies):
            obj, model = make_prop(prop, cat, lib)
            obj.rotation_mode = "QUATERNION"
            made.append((prop, k, obj, model))
    held = {}  # obj -> (from world matrix, t0) while thrown or carried
    for frame in frames:
        scene.frame_set(frame)
        t = frame / FPS
        tc = (t % length) if loop and length > 0 else min(t, length)
        for prop, k, obj, model in made:
            at = np_to_matrix(emotemeta.steps(prop["at"]))
            visible = True
            if prop.get("stack"):
                step = np_to_matrix(emotemeta.steps(prop["stack"]["step"]))
                for _ in range(k):
                    at = at @ step
                when = prop["stack"]["times"][k]
                visible = tc >= when
                carry, topple = prop["stack"].get("carry"), prop["stack"].get("topple")
                if carry and when > 0 and when - carry["lead"] <= tc < when:  # riding in the hand
                    hand = socket_world(arm, parts, carry["mount"]) @ np_to_matrix(emotemeta.steps(carry["at"])) @ model
                    key_matrix(obj, frame, hand, True)
                    continue
                if topple is not None and tc >= topple:
                    visible = False
                m = socket_world(arm, parts, "floor") @ at @ model
                key_matrix(obj, frame, m, visible)
                continue
            if prop.get("show") is not None and tc < prop["show"]:
                visible = False
            if prop.get("hide") is not None and tc > prop["hide"]:
                visible = False
            mount = prop["mount"]
            m = socket_world(arm, parts, mount) @ at @ model
            for move in prop.get("moves") or []:
                to = np_to_matrix(emotemeta.steps(move["to"]))
                target = socket_world(arm, parts, move.get("mount") or mount) @ to @ model
                if tc >= move["at"] + 0.18:
                    mount, at, m = move.get("mount") or mount, to, target
                elif tc >= move["at"]:
                    u = (tc - move["at"]) / 0.18
                    m = m.lerp(target, u)
            for toss in prop.get("tosses") or []:
                if toss["at"] <= tc <= toss["back"]:
                    key = (id(obj), toss["at"])
                    if key not in held:
                        held[key] = m.to_translation()
                    start = held[key]
                    u = (tc - toss["at"]) / (toss["back"] - toss["at"])
                    home = m.to_translation()
                    up = 4 * u * (1 - u) * toss["height"]
                    pos = start.lerp(home, u) + Vector((0, 0, up))
                    # the game spins it about world X (Roblox x = Blender -x)
                    spin = Matrix.Rotation(-u * math.pi * 2 * toss["spin"], 4, "X")
                    m = Matrix.Translation(pos) @ spin @ AXES.to_4x4() @ model
                elif tc < toss["at"]:
                    held.pop((id(obj), toss["at"]), None)
            key_matrix(obj, frame, m, visible)
    for _, _, obj, _ in made:
        if obj.animation_data and obj.animation_data.action:
            for layer in obj.animation_data.action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for fc in bag.fcurves:
                            for kp in fc.keyframe_points:
                                kp.interpolation = "LINEAR" if not fc.data_path == "scale" else "CONSTANT"
    return made


# Rendering -------------------------------------------------------------------------------------------------


def loop_action(action):
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if not any(mod.type == "CYCLES" for mod in fc.modifiers):
                        fc.modifiers.new("CYCLES")


def render_still(path):
    scene = bpy.context.scene
    scene.render.image_settings.media_type = "IMAGE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def make_sheet(files, out, cols=8, tile=200, mirror=False):
    """The stills joined into one sheet, in order, left to right and top to bottom (mirrored like a dance
    tutorial filmed facing the camera when `mirror`)."""
    rows = math.ceil(len(files) / cols)
    canvas = np.zeros((rows * tile, cols * tile, 4), dtype=np.float32)
    canvas[..., 3] = 1
    for i, path in enumerate(files):
        img = bpy.data.images.load(path)
        img.scale(tile, tile)
        px = np.array(img.pixels[:], dtype=np.float32).reshape(tile, tile, 4)
        if mirror:
            px = px[:, ::-1]
        r, c = divmod(i, cols)
        y0 = (rows - 1 - r) * tile
        canvas[y0 : y0 + tile, c * tile : (c + 1) * tile] = px
        bpy.data.images.remove(img)
    image = bpy.data.images.new("sheet", cols * tile, rows * tile, alpha=True)
    image.pixels = canvas.ravel()
    image.filepath_raw = out
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def render_video(path, start, end):
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end, scene.frame_step = start, end, 2
    scene.render.fps = 30
    scene.render.image_settings.media_type = "VIDEO"
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "HIGH"
    scene.render.filepath = path
    bpy.ops.render.render(animation=True)


def build_fresh(arm, names):
    """--build: the named clips built now from the rebuilt-emote package (art/scripts/emotes), in memory only
    (nothing saved, nothing exported), so a change can be looked at in seconds."""
    import animlib
    import emotes  # noqa: F401  (defines the rebuilt clips)

    bpy.context.scene.render.fps = animlib.FPS
    for name in names:
        if name in animlib.CLIPS:
            animlib.build_action(arm, animlib.CLIPS[name])
            print("[review] built", name)


def main():
    opts = parse(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])
    bpy.ops.wm.open_mainfile(filepath=os.path.join(common.BLEND, "Animations.blend"))
    for obj in list(bpy.data.objects):
        if obj.type in ("CAMERA", "LIGHT") or obj.name.startswith("label_"):
            bpy.data.objects.remove(obj, do_unlink=True)
    arm = bpy.data.objects["R6"]
    if opts.get("build"):
        build_fresh(arm, opts["names"])
    parts = {child.name: child for child in arm.children}
    bind_rest(arm, parts)
    meta_all = emotemeta.load()
    cat = emotemeta.catalog()
    lib = library()
    cam = bench(opts["size"])
    for name in opts["names"]:
        action = bpy.data.actions.get(name)
        if action is None:
            print(f"[review] no action {name}")
            continue
        length = float(action.get("length", 2.0))
        loop = bool(action.get("loop"))
        seconds = opts["seconds"] or (length * 2 if loop else length + 0.6)
        if loop:
            loop_action(action)
        arm.animation_data_create()
        arm.animation_data.action = action
        for obj in list(common.collection("Props").objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        end = int(round(seconds * FPS))
        frames = list(range(0, end + 1, 2))
        bake_props(arm, parts, meta_all.get(name) or {}, cat, lib, frames, length, loop)
        folder = os.path.join(OUT, name)
        os.makedirs(folder, exist_ok=True)
        for old in os.listdir(folder):
            if old.startswith(("still_", "closeup_")):
                os.remove(os.path.join(folder, old))
        aim(cam, (0, 0, 2.6), 13.0, opts["angle"], height=0.6)
        stills = opts["stills"] or [round(length * q, 2) for q in (0.0, 0.25, 0.5, 0.75, 1.0)]
        shots = []
        for t in stills:
            bpy.context.scene.frame_set(int(round(t * FPS)))
            shots.append(os.path.join(folder, f"still_{t:05.2f}.png"))
            render_still(shots[-1])
            if opts["angle2"] is not None:
                aim(cam, (0, 0, 2.6), 13.0, opts["angle2"], height=0.6)
                render_still(os.path.join(folder, f"still_{t:05.2f}_b.png"))
                aim(cam, (0, 0, 2.6), 13.0, opts["angle"], height=0.6)
        if opts["closeup"]:
            prop = next((p for p in (meta_all.get(name) or {}).get("props") or [] if p["model"] == opts["closeup"]), None)
            if prop is not None:
                for t in stills:
                    bpy.context.scene.frame_set(int(round(t * FPS)))
                    target = socket_world(arm, parts, prop["mount"]).to_translation()
                    aim(cam, target, 4.0, opts["angle"] + 25, height=0.8)
                    render_still(os.path.join(folder, f"closeup_{t:05.2f}.png"))
                aim(cam, (0, 0, 2.6), 13.0, opts["angle"], height=0.6)
        if opts.get("sheet"):
            make_sheet(shots, os.path.join(folder, "sheet.png"), cols=8 if len(shots) > 12 else 6,
                       mirror=bool(opts.get("mirror")))
        if opts["video"]:
            render_video(os.path.join(folder, f"{name}.mp4"), 0, end)
        print(f"[review] {name}: {folder}")


if __name__ == "__main__":
    main()
