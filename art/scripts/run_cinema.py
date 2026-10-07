"""Cutscenes: export them for the game, and render preview videos on the real venue (background Blender):

    blender -b --factory-startup --python art/scripts/run_cinema.py -- --export [Shot ...]
    blender -b --factory-startup --python art/scripts/run_cinema.py -- --lint [Shot ...]   (camera checks)
    blender -b --factory-startup --python art/scripts/run_cinema.py -- --preview Shot [--size=960x540] [--from=0 --to=8]
    blender -b --factory-startup --python art/scripts/run_cinema.py -- --preview Shot --stills=1,4.5,9   (frames as PNGs)

The actors' acting clips must already be built (run_anims.py builds them with the other clips, and
saves them in art/blend/Animations.blend). The preview builds the shot's venue the way run_maps.py
does (props, lamps, signs), puts an R6 mannequin on every actor's path playing its clip, flies the
camera, shows the props and the subtitles, and writes art/export/previews/cinema/<Shot>.mp4.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

import common  # noqa: E402
from cinema import shot as shotlib  # noqa: E402

OUT_DIR = os.path.join(common.PREVIEWS, "cinema")
FPS = 60  # the clips' frame rate; the video is rendered at every other frame (30 fps)
MAP = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))  # Roblox = MAP @ Blender, in the venue scenes
RIG_TURN = Matrix.Rotation(math.pi, 4, "Z")  # the R6 rig faces +Y; venue scenes face -Y
RIG_OBJECTS = ("R6", "Torso_Mesh", "Head_Mesh", "Right Arm_Mesh", "Left Arm_Mesh", "Right Leg_Mesh",
               "Left Leg_Mesh", "ShirtFront", "Tie", "EyeL", "EyeR")


def b_pos(p):
    x, y, z = p
    return Vector((-x, z, y))


def b_rot(m, local_like_roblox=True):
    """A Roblox rotation as a Blender (venue) rotation. Objects whose own axes follow Roblox (the camera)
    need only the world axes changed; objects modelled in the venue convention need both."""
    r = Matrix([list(row) for row in m])
    return MAP.transposed() @ r if local_like_roblox else MAP.transposed() @ r @ MAP


def load_shots():
    import cinema.shots  # noqa: F401  (each module defines its shots)

    return shotlib.SHOTS


# Set ----------------------------------------------------------------------------------------------------


def build_set(venue):
    import run_maps
    from maps import matlib, mesher

    common.clear_scene()
    images = matlib.make_textures()
    mesher.use_images(images)
    scene, module, coll = run_maps.build_venue(venue)
    stand_in = mesher.Scene(scene.venue + "Preview")
    if hasattr(module, "preview"):
        module.preview(stand_in)
    stand_coll = common.collection("Preview_" + scene.venue)
    stand_in.finish(stand_coll)
    run_maps.place_props(scene, coll)
    run_maps.place_props(stand_in, stand_coll)
    run_maps.add_lights(scene, coll)
    run_maps.prop_lights(scene, coll)
    run_maps.draw_signs(scene, coll)
    # Glass reads clearer in the game than the map previews draw it: see through it here.
    for mat in bpy.data.materials:
        if mat.name in ("M_Glass", "M_GlassDark") and mat.node_tree:
            bsdf = mat.node_tree.nodes.get("Principled BSDF")
            if bsdf:
                bsdf.inputs["Alpha"].default_value = 0.12
                bsdf.inputs["Roughness"].default_value = 0.05
            try:
                mat.surface_render_method = "BLENDED"
            except (AttributeError, TypeError):
                pass
    bscene = bpy.context.scene
    bscene.render.engine = "BLENDER_EEVEE"
    bscene.view_settings.view_transform = "Standard"
    world = bscene.world or bpy.data.worlds.new("World")
    bscene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.05, 0.055, 0.085, 1)
    bg.inputs["Strength"].default_value = 1.6
    data = bpy.data.lights.new("Moon", "SUN")
    data.energy = 0.35
    data.color = (0.7, 0.75, 1.0)
    moon = bpy.data.objects.new("Moon", data)
    moon.rotation_euler = (math.radians(50), 0, math.radians(30))
    bscene.collection.objects.link(moon)
    return run_maps.load_props()


# Actors -------------------------------------------------------------------------------------------------


def load_rig(clips):
    path = os.path.join(common.BLEND, "Animations.blend")
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in RIG_OBJECTS]
        dst.actions = [n for n in src.actions if n in clips]
    rig = bpy.data.objects["R6"]
    coll = common.collection("Actors")
    for obj in dst.objects:
        coll.objects.link(obj)
        obj.hide_render = True
        obj.hide_viewport = True
    return rig, {a.name: a for a in dst.actions if a is not None}


def copy_rig(rig, name):
    coll = common.collection("Actors")
    arm = rig.copy()
    arm.data = rig.data.copy()
    arm.name = name
    arm.animation_data_clear()
    coll.objects.link(arm)
    arm.hide_render = arm.hide_viewport = False
    parts = {}
    for child in rig.children:
        c = child.copy()
        if child.data is not None:
            c.data = child.data.copy()
        c.parent = arm
        c.parent_type = child.parent_type
        c.parent_bone = child.parent_bone
        c.matrix_parent_inverse = child.matrix_parent_inverse.copy()
        c.hide_render = c.hide_viewport = False
        coll.objects.link(c)
        parts[child.name] = c
    return arm, parts


def key_transform(obj, frame, matrix):
    obj.matrix_world = matrix
    obj.keyframe_insert("location", frame=frame)
    obj.keyframe_insert("rotation_euler", frame=frame)
    obj.keyframe_insert("scale", frame=frame)


def constant_keys(obj):
    if obj.animation_data and obj.animation_data.action:
        for layer in obj.animation_data.action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for fc in bag.fcurves:
                        if fc.data_path == "scale":
                            for kp in fc.keyframe_points:
                                kp.interpolation = "CONSTANT"


def place_actor(shot, actor, rig, actions, index):
    root = bpy.data.objects.new(f"Path_{actor.slot}", None)
    common.collection("Actors").objects.link(root)
    arm, parts = copy_rig(rig, f"Actor_{actor.slot}")
    arm.parent = root
    arm.matrix_parent_inverse = Matrix.Identity(4)
    arm.matrix_basis = RIG_TURN
    # the path, frame by frame (shown only between show[0] and show[1])
    for t in shot.times():
        v = actor.path.value(t)
        visible = actor.show[0] - 1e-6 <= t <= actor.show[1] + 1e-6
        m = Matrix.Translation(b_pos(v[:3])) @ Matrix.Rotation(math.radians(v[3]), 4, "Z")
        if not visible:
            m = m @ Matrix.Scale(0.0001, 4)
        key_transform(root, t * FPS, m)
    constant_keys(root)
    # the acting: the clip from shot time `at`, looping clips repeated to the end
    action = actions.get(actor.clip) if actor.clip else None
    if action is not None:
        arm.animation_data_create()
        track = arm.animation_data.nla_tracks.new()
        start = actor.at * FPS
        strip = track.strips.new(action.name, int(round(start)), action)
        if action.get("loop"):
            length = float(action["length"]) * FPS
            strip.repeat = max(1.0, (shot.length * FPS - start) / max(1.0, length) + 1)
        strip.extrapolation = "HOLD"
    if actor.silhouette or actor.extra:
        black = common.material("Silhouette", (0.005, 0.005, 0.006), 0.9)
        for obj in parts.values():
            if obj.type == "MESH" and (actor.extra or actor.silhouette[0] <= 0.0):
                obj.data.materials.clear()
                obj.data.materials.append(black if actor.silhouette else common.material("Extra", (0.12, 0.12, 0.14), 0.8))
    return root, arm, parts


def arm_socket(arm, part_name, parts):
    """An empty at the middle of an arm part, with Roblox-like axes, that follows the arm."""
    import rig as riglib

    # Bound in the rest pose, so the socket's axes are the arm part's own (as the game's grip is).
    pose_position = arm.data.pose_position
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    mesh = parts[part_name + "_Mesh"]
    centre = mesh.matrix_world @ ((Vector(mesh.bound_box[0]) + Vector(mesh.bound_box[6])) / 2)
    empty = bpy.data.objects.new("Socket_" + part_name, None)
    common.collection("Actors").objects.link(empty)
    # the rig's own axes: Roblox x = Blender x, Roblox y = Blender z, Roblox z = Blender -y
    axes = arm.matrix_world.to_3x3() @ Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    empty.matrix_world = Matrix.Translation(centre) @ axes.to_4x4()
    riglib.parent_to_bone(empty, arm, part_name)
    arm.data.pose_position = pose_position
    bpy.context.view_layer.update()
    return empty


def add_held(actor, arm, parts, library):
    for prop, part, off, rot, t0, t1 in actor.held:
        src = library.get(prop)
        if src is None:
            continue
        socket = arm_socket(arm, part, parts)
        obj = src.copy()
        common.collection("Actors").objects.link(obj)
        obj.parent = socket
        local = Matrix.Translation(Vector(off)) @ Matrix([list(r) for r in shotlib.euler_rotation(*rot)]).to_4x4() @ MAP.to_4x4()
        for t, show in ((0.0, t0 <= 0.0), (t0, True), (t1, False)):
            obj.matrix_basis = local if show else local @ Matrix.Scale(0.0001, 4)
            obj.keyframe_insert("scale", frame=t * FPS)
            obj.keyframe_insert("location", frame=t * FPS)
            obj.keyframe_insert("rotation_euler", frame=t * FPS)
        constant_keys(obj)


def add_props(shot, library):
    """Each prop with its glowing parts and the lamps it carries, following its path."""
    import json

    for p in shot.props:
        src = library.get(p.model)
        if src is None:
            print(f"[cinema] {shot.name}: no prop {p.model} in Props.blend")
            continue
        obj = src.copy()
        common.collection("Actors").objects.link(obj)
        for name in [k for k in library if k.startswith(p.model + "_Glow")]:
            glow = library[name].copy()
            common.collection("Actors").objects.link(glow)
            glow.parent = obj
            glow.matrix_parent_inverse = Matrix.Identity(4)
            glow.matrix_basis = Matrix.Identity(4)
        for li in json.loads(src["lights"]) if src.get("lights") else []:
            data = bpy.data.lights.new("L", "POINT")
            data.color = [c / 255 for c in li["color"]]
            data.energy = li["brightness"] * li["range"] * li["range"] * 1.6
            data.shadow_soft_size = 0.4
            lamp = bpy.data.objects.new("L", data)
            common.collection("Actors").objects.link(lamp)
            lamp.parent = obj
            lx, ly, lz = li["at"]
            lamp.location = (-lx, lz, ly)
        for t in shot.times():
            v = p.path.value(t)
            m = Matrix.Translation(b_pos(v[:3])) @ b_rot(shotlib.euler_rotation(*v[3:6]), False).to_4x4()
            if not (p.show[0] - 1e-6 <= t <= p.show[1] + 1e-6):
                m = m @ Matrix.Scale(0.0001, 4)
            key_transform(obj, t * FPS, m)
        constant_keys(obj)


# Camera, captions ------------------------------------------------------------------------------------


def add_camera(shot):
    data = bpy.data.cameras.new("ShotCam")
    data.sensor_fit = "VERTICAL"
    data.clip_start = 0.1
    data.clip_end = 3000
    cam = bpy.data.objects.new("ShotCam", data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    samples, _ = shot.camera_samples()
    for t, p, q, fov in samples:
        m = shotlib.look_rotation  # noqa: F841 (rotation comes from the quaternion)
        x, y, z, w = q
        rot = np.array([
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ])
        cam.matrix_world = Matrix.Translation(b_pos(p)) @ b_rot(rot, True).to_4x4()
        cam.keyframe_insert("location", frame=t * FPS)
        cam.keyframe_insert("rotation_euler", frame=t * FPS)
        data.angle_y = math.radians(fov)
        data.keyframe_insert("lens", frame=t * FPS)
    return cam


def add_captions(shot, cam):
    """Subtitles and cards as text under the camera, shown for their time."""
    mat = common.material("Caption", (1, 1, 1), 0.5, emission=(1, 1, 1), strength=2.0)
    for t, kind, data in shot.events:
        text = data.get("text") or (" / ".join(data.get("lines", [])) if data.get("lines") else None)
        if kind not in ("subtitle", "title", "card") or not text:
            continue
        curve = bpy.data.curves.new("cap", "FONT")
        curve.body = text
        curve.align_x = "CENTER"
        curve.size = 0.045 if kind == "subtitle" else 0.07
        curve.materials.append(mat)
        obj = bpy.data.objects.new("cap", curve)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = cam
        y = -0.33 if kind == "subtitle" else 0.0
        dur = data.get("dur", 2.5)
        for tt, show in ((0.0, False), (t, True), (t + dur, False)):
            obj.location = (0, y, -1.0)
            obj.scale = (1, 1, 1) if show else (0.0001, 0.0001, 0.0001)
            obj.keyframe_insert("scale", frame=tt * FPS)
            obj.keyframe_insert("location", frame=tt * FPS)
        constant_keys(obj)


# Main -------------------------------------------------------------------------------------------------


def preview(shot, size=(960, 540), t_from=0.0, t_to=None, stills=None):
    library = build_set(shot.venue)
    clips = {a.clip for a in shot.actors if a.clip}
    rig, actions = load_rig(clips)
    for i, actor in enumerate(shot.actors):
        root, arm, parts = place_actor(shot, actor, rig, actions, i)
        add_held(actor, arm, parts, library)
    add_props(shot, library)
    cam = add_camera(shot)
    add_captions(shot, cam)
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.fps = 30
    scene.frame_start = int(t_from * FPS)
    scene.frame_end = int((t_to if t_to is not None else shot.length) * FPS) - 1
    scene.frame_step = 2
    scene.render.image_settings.media_type = "VIDEO"
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "MEDIUM"
    os.makedirs(OUT_DIR, exist_ok=True)
    if stills:
        scene.render.image_settings.media_type = "IMAGE"
        scene.render.image_settings.file_format = "PNG"
        paths = []
        for t in stills:
            scene.frame_set(int(round(t * FPS)))
            path = os.path.join(OUT_DIR, f"{shot.name}_{t:g}.png")
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            paths.append(path)
        return paths
    path = os.path.join(OUT_DIR, shot.name + ".mp4")
    scene.render.filepath = path
    bpy.ops.render.render(animation=True)
    return path


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    shots = load_shots()
    names = [a for a in argv if not a.startswith("--")] or sorted(shots)
    if "--lint" in argv:
        for name in names:
            for line in shotlib.lint(shots[name]):
                print(f"[lint] {name} {line}")
    if "--export" in argv:
        for name in names:
            print("[cinema] wrote", shotlib.export(shots[name]))
    if "--preview" in argv:
        size = (960, 540)
        t_from, t_to, stills = 0.0, None, None
        for a in argv:
            if a.startswith("--size="):
                w, h = a.split("=")[1].split("x")
                size = (int(w), int(h))
            elif a.startswith("--from="):
                t_from = float(a.split("=")[1])
            elif a.startswith("--to="):
                t_to = float(a.split("=")[1])
            elif a.startswith("--stills="):
                stills = [float(v) for v in a.split("=")[1].split(",")]
        for name in names:
            print("[cinema] preview", preview(shots[name], size, t_from, t_to, stills))


if __name__ == "__main__":
    main()
