"""Cutscenes: export them for the game, and render preview videos on the real venue (background Blender):

    blender -b --factory-startup --python art/scripts/run_cinema.py -- --export [Shot ...]
    blender -b --factory-startup --python art/scripts/run_cinema.py -- --lint [Shot ...]   (camera checks)
    blender -b --factory-startup --python art/scripts/run_cinema.py -- --preview Shot [--size=960x540] [--from=0 --to=8]
    blender -b --factory-startup --python art/scripts/run_cinema.py -- --preview Shot --stills=1,4.5,9   (frames as PNGs)
    ... --preview Shot --stills=4.5 --eye=px,py,pz,tx,ty,tz[,fov]   (the staging seen from anywhere)

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


def look_and_atmosphere(bscene):
    """The previews' look: AgX with punch (rich blacks, lights that bloom instead of clipping flat), volumetric
    light shafts, and a bloom pass over lamps, screens and glowing eyes (the game's Bloom)."""
    vs = bscene.view_settings
    vs.view_transform = "AgX"
    vs.look = "AgX - Punchy"
    vs.exposure = 2.0
    ee = bscene.eevee
    ee.volumetric_end = 90.0
    ee.volumetric_tile_size = "4"
    ee.volumetric_samples = 48
    ee.use_volumetric_shadows = True
    tree = bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
    layers = tree.nodes.new("CompositorNodeRLayers")
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.inputs["Type"].default_value = "Bloom"
    glare.inputs["Threshold"].default_value = 0.8
    glare.inputs["Strength"].default_value = 0.5
    out = tree.nodes.new("NodeGroupOutput")
    tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    tree.links.new(layers.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], out.inputs[0])
    bscene.compositing_node_group = tree
    bscene.render.use_compositing = True


def build_set(venue):
    import run_maps

    os.environ["DG_PREVIEW"] = "1"  # (a preview may go without what only an export needs, maps/relief.py)
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
    look_and_atmosphere(bscene)
    world = bscene.world or bpy.data.worlds.new("World")
    bscene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.05, 0.055, 0.085, 1)
    bg.inputs["Strength"].default_value = 1.6
    # a thin haze in the air, so lamps and windows throw beams
    nodes, links = world.node_tree.nodes, world.node_tree.links
    scatter = nodes.new("ShaderNodeVolumeScatter")
    scatter.inputs["Density"].default_value = 0.0018
    scatter.inputs["Anisotropy"].default_value = 0.55
    links.new(scatter.outputs["Volume"], nodes["World Output"].inputs["Volume"])
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
    if actor.extra:
        grey = common.material("Extra", (0.12, 0.12, 0.14), 0.8)
        for obj in parts.values():
            if obj.type == "MESH":
                obj.data.materials.clear()
                obj.data.materials.append(grey)
    if actor.silhouette:
        # A black shell over each part, shown only while the actor is a silhouette (the game's Highlight).
        black = common.material("Silhouette", (0.005, 0.005, 0.006), 0.9)
        t0, t1 = actor.silhouette
        for obj in list(parts.values()):
            if obj.type != "MESH":
                continue
            shell = obj.copy()
            shell.data = obj.data.copy()
            shell.data.materials.clear()
            shell.data.materials.append(black)
            shell.scale = obj.scale * 1.015
            for coll in obj.users_collection:
                coll.objects.link(shell)
            for t, hidden in ((0.0, t0 > 0.0), (t0, False), (t1, True)):
                shell.hide_render = hidden
                shell.keyframe_insert("hide_render", frame=t * FPS)
    add_faces(shot, actor, arm, parts)
    if not actor.extra:
        add_hair(actor, arm, parts, index)
    return root, arm, parts


HAIR = [(0.1, 0.06, 0.035), (0.32, 0.18, 0.08), (0.7, 0.52, 0.24), (0.36, 0.1, 0.04), (0.45, 0.45, 0.48),
        (0.16, 0.12, 0.1)]


def add_hair(actor, arm, parts, index):
    """Stand-in hair, so the grey mannequins read as different people (the game shows real avatars)."""
    socket = arm_socket(arm, "Head", parts)
    mat = common.material(f"Hair{index % len(HAIR)}", HAIR[index % len(HAIR)], 0.7)
    style = index % 3
    dims = parts["Head_Mesh"].dimensions
    # As big as the hair real avatars wear: a full cap well over the head, thick at the back and sides
    # (a bare stand-in head made close-ups look fine in Blender that were all hair in the game).
    w, h, d = dims.x + 0.7, dims.z, dims.y + 0.7
    top, back = h / 2, dims.y / 2
    boxes = [((0, top + 0.22, 0.05), (w, 0.62, d)), ((0, top - 0.45, back + 0.22), (w, 1.25, 0.45)),
             ((w / 2 - 0.15, top - 0.3, 0.12), (0.3, 0.75, d * 0.85)), ((-w / 2 + 0.15, top - 0.3, 0.12), (0.3, 0.75, d * 0.85))]
    if style == 1:  # a fringe
        boxes.append(((0, top - 0.1, -back - 0.12), (w * 0.9, 0.34, 0.24)))
    elif style == 2:  # long at the back and sides
        boxes += [((w / 2 - 0.12, top - 0.95, 0.15), (0.24, 0.9, d * 0.7)), ((-w / 2 + 0.12, top - 0.95, 0.15), (0.24, 0.9, d * 0.7)),
                  ((0, top - 1.25, back + 0.2), (w, 0.7, 0.4))]
    for k, (pos, size) in enumerate(boxes):
        mesh = bpy.data.meshes.new(f"Hair_{actor.slot}_{k}")
        sx, sy, sz = (v / 2 for v in size)
        x, y, z = pos
        verts = [(x + a * sx, y + b * sy, z + c * sz) for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)]
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        mesh.from_pydata(verts, [], faces)
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(mesh.name, mesh)
        common.collection("Actors").objects.link(obj)
        obj.parent = socket


def add_faces(shot, actor, arm, parts):
    """The face decals the shot puts on this actor: one quad per face over the front of the head, each
    shown while it is the one worn (the game swaps the head's face decal instead)."""
    changes = sorted((t, data.get("face") or "") for t, kind, data in shot.events
                     if kind == "face" and data.get("slot") == actor.slot)
    if not changes:
        return
    socket = arm_socket(arm, "Head", parts)
    skin = (0.84, 0.66, 0.52, 1.0)
    for name in sorted({n for _, n in changes if n}):
        path = os.path.join(common.TEXTURES, f"Face{name}.png")
        if not os.path.exists(path):
            print(f"[cinema] no face texture {path}")
            continue
        mat = bpy.data.materials.get("Face" + name)
        if mat is None:
            mat = bpy.data.materials.new("Face" + name)
            mat.use_nodes = True
            nodes, links = mat.node_tree.nodes, mat.node_tree.links
            bsdf = nodes["Principled BSDF"]
            tex = nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(path, check_existing=True)
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.inputs["A"].default_value = skin
            links.new(tex.outputs["Alpha"], mix.inputs["Factor"])
            links.new(tex.outputs["Color"], mix.inputs["B"])
            links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
            bsdf.inputs["Roughness"].default_value = 0.7
        # a quad in the socket's Roblox-like axes (x right, y up, z back): its face to -z, just over the front of
        # the head, as big as the head's face (the rig's head: x width, y depth, z height in its own axes)
        dims = parts["Head_Mesh"].dimensions
        s, z = 0.46 * min(dims.x, dims.z), -(dims.y / 2 + 0.012)
        mesh = bpy.data.meshes.new(f"Face_{actor.slot}_{name}")
        mesh.from_pydata([(s, -s, z), (-s, -s, z), (-s, s, z), (s, s, z)], [], [(0, 1, 2, 3)])
        uv = mesh.uv_layers.new(name="UVMap")
        for loop, co in zip(uv.data, ((0, 0), (1, 0), (1, 1), (0, 1))):  # seen from the front: the actor's right on the left
            loop.uv = co
        mesh.materials.append(mat)
        quad = bpy.data.objects.new(mesh.name, mesh)
        common.collection("Actors").objects.link(quad)
        quad.parent = socket
        keys = [(0.0, False)] + [(t, n == name) for t, n in changes]
        for t, on in keys:
            quad.hide_render = not on
            quad.keyframe_insert("hide_render", frame=t * FPS)


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
    import json

    for prop, part, off, rot, t0, t1, scale in actor.held:
        src = library.get(prop)
        if src is None:
            continue
        socket = arm_socket(arm, part, parts)
        obj = src.copy()
        common.collection("Actors").objects.link(obj)
        obj.parent = socket
        for name in json.loads(src["parts"]) if src.get("parts") else []:  # its pieces (the Manual's board, leaves)
            if library.get(prop + "_" + name) is not None:
                piece = library[prop + "_" + name].copy()
                common.collection("Actors").objects.link(piece)
                piece.parent = obj
                piece.matrix_parent_inverse = Matrix.Identity(4)
                piece.matrix_basis = Matrix.Identity(4)
        local = (Matrix.Translation(Vector(off)) @ Matrix([list(r) for r in shotlib.euler_rotation(*rot)]).to_4x4()
                 @ MAP.to_4x4() @ Matrix.Scale(scale, 4))
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
        # The pieces that move by themselves (Death's Manual's board and leaves), turned open as the game
        # does (ManualBook.pose: about the catalog's hinge line, by its turn about -Y here).
        hinges = json.loads(src["hinge"]) if src.get("hinge") else {}
        turns = json.loads(src["turn"]) if src.get("turn") else {}
        for name in json.loads(src["parts"]) if src.get("parts") else []:
            part = library.get(p.model + "_" + name)
            if part is None:
                continue
            piece = part.copy()
            common.collection("Actors").objects.link(piece)
            piece.parent = obj
            piece.matrix_parent_inverse = Matrix.Identity(4)
            share = p.open or 0.0
            if share and name in hinges and name in turns:
                hx, hy, hz = hinges[name]
                at = Vector((-hx, hz, hy))
                swing = Matrix.Rotation(math.radians(-turns[name] * share), 4, "Y")
                piece.matrix_basis = Matrix.Translation(at) @ swing @ Matrix.Translation(-at)
            else:
                piece.matrix_basis = Matrix.Identity(4)
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
            m = m @ Matrix.Scale(p.scale, 4)
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
    previous = None
    for t, p, q, fov in samples:
        m = shotlib.look_rotation  # noqa: F841 (rotation comes from the quaternion)
        x, y, z, w = q
        rot = np.array([
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ])
        cam.matrix_world = Matrix.Translation(b_pos(p)) @ b_rot(rot, True).to_4x4()
        # Keep each key's angles next to the last one's: a jump of 360 degrees between keys spun the
        # camera through a frame upside down in the previews (the game's own keys are quaternions).
        if previous is not None:
            cam.rotation_euler = cam.matrix_world.to_euler("XYZ", previous)
        previous = cam.rotation_euler.copy()
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


# A font for the contact sheets' labels (ffmpeg on Windows finds none by itself).
FONT = r"C\:/Windows/Fonts/arial.ttf" if os.name == "nt" else "DejaVuSans.ttf"


def cut_times(shot):
    """For each cut: (its start, a moment just in, the middle, a moment before its end)."""
    starts = [g[0][0] for g in shot.cam_groups if g]
    ends = starts[1:] + [shot.length]
    out = []
    for a, b in zip(starts, ends):
        pad = min(0.25, (b - a) / 4)
        out.append((a + pad, (a + b) / 2, b - pad))
    return out


def add_plan_camera(shot):
    """A camera straight down over the actors, to check where everyone stands."""
    pts = []
    for a in shot.actors:
        for t in (0.0, shot.length / 2, shot.length):
            v = a.path.value(t)
            pts.append((v[0], v[2]))
    pts = np.array(pts) if pts else np.zeros((1, 2))
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    centre = (lo + hi) / 2
    span = max(hi[0] - lo[0], (hi[1] - lo[1]) * 16 / 9, 12.0) + 10.0
    data = bpy.data.cameras.new("PlanCam")
    data.type = "ORTHO"
    data.ortho_scale = span
    data.clip_end = 3000
    cam = bpy.data.objects.new("PlanCam", data)
    bpy.context.scene.collection.objects.link(cam)
    top = max((a.path.value(0.0)[1] for a in shot.actors), default=0.0) + 9.0
    cam.matrix_world = Matrix.Translation(b_pos((centre[0], top, centre[1]))) @ b_rot(
        shotlib.look_rotation((centre[0], top, centre[1]), (centre[0], 0.0, centre[1] - 0.001)), True).to_4x4()
    return cam


def letterbox(scene, on):
    """The game's letterbox (Cinema.letterbox: 11% at the top and the bottom), as a render border."""
    scene.render.use_border = on
    scene.render.use_crop_to_border = False
    scene.render.border_min_x, scene.render.border_max_x = 0.0, 1.0
    scene.render.border_min_y, scene.render.border_max_y = (0.11, 0.89) if on else (0.0, 1.0)


def sheet(shot, size=(640, 360)):
    """A contact sheet: every cut at its start, middle and end through the shot's camera, then the
    actors from straight above at the start, middle and end. Written as <Shot>_sheet.png."""
    import subprocess

    library = build_set(shot.venue)
    clips = {a.clip for a in shot.actors if a.clip}
    rig, actions = load_rig(clips)
    for i, actor in enumerate(shot.actors):
        root, arm, parts = place_actor(shot, actor, rig, actions, i)
        add_held(actor, arm, parts, library)
    add_props(shot, library)
    cam = add_camera(shot)
    plan = add_plan_camera(shot)
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.image_settings.media_type = "IMAGE"
    scene.render.image_settings.file_format = "PNG"
    os.makedirs(OUT_DIR, exist_ok=True)
    frames = []
    rows = cut_times(shot) + [(0.3, shot.length / 2, shot.length - 0.3)]
    for r, row in enumerate(rows):
        scene.camera = plan if r == len(rows) - 1 else cam
        letterbox(scene, shot.letterbox and r < len(rows) - 1)
        for k, t in enumerate(row):
            scene.frame_set(int(round(t * FPS)))
            path = os.path.join(OUT_DIR, f"_{shot.name}_{r}_{k}.png")
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            frames.append((path, f"{'plan' if r == len(rows) - 1 else 'cut ' + str(r + 1)}  {t:.2f}s"))
    out = os.path.join(OUT_DIR, f"{shot.name}_sheet.png")
    args, filters = [], []
    for i, (path, label) in enumerate(frames):
        args += ["-i", path]
        filters.append(f"[{i}]drawtext=fontfile='{FONT}':text='{label}':x=8:y=8:fontsize=20:fontcolor=white:box=1:boxcolor=black@0.6[f{i}]")
    n = len(frames)
    layout = "|".join(f"{(i % 3) * size[0]}_{(i // 3) * size[1]}" for i in range(n))
    graph = ";".join(filters) + ";" + "".join(f"[f{i}]" for i in range(n)) + f"xstack=inputs={n}:layout={layout}"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args, "-filter_complex", graph, out], check=True)
    for path, _ in frames:
        os.remove(path)
    return out


def preview(shot, size=(960, 540), t_from=0.0, t_to=None, stills=None, eye=None):
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
    letterbox(scene, shot.letterbox)
    if eye:
        # A look at the staging from anywhere (px, py, pz, tx, ty, tz[, fov]): the stills are taken from there.
        data = bpy.data.cameras.new("EyeCam")
        data.sensor_fit = "VERTICAL"
        data.clip_start = 0.1
        data.clip_end = 3000
        data.angle_y = math.radians(eye[6] if len(eye) > 6 else 60.0)
        look = bpy.data.objects.new("EyeCam", data)
        scene.collection.objects.link(look)
        look.matrix_world = Matrix.Translation(b_pos(eye[:3])) @ b_rot(shotlib.look_rotation(eye[:3], eye[3:6]), True).to_4x4()
        scene.camera = look
        letterbox(scene, False)
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
            for line in shotlib.framing_lint(shots[name]):
                print(f"[frame] {name} {line}")
    if "--clear" in argv:
        # room to move: the actors against the set and each other
        import run_maps
        from cinema import clearance
        from maps import matlib, mesher

        built = {}
        os.environ["DG_PREVIEW"] = "1"  # (a check, like a preview, may go without what only an export needs)
        for name in names:
            venue = shots[name].venue
            if venue not in built:
                common.clear_scene()
                mesher.use_images(matlib.make_textures())
                built[venue] = run_maps.build_venue(venue)[0]
            lines = clearance.report(shots[name], built[venue])
            for line in lines:
                print(f"[clear] {name} {line}")
            print(f"[clear] {name}: {len(lines)} problems")
    if "--export" in argv:
        for name in names:
            print("[cinema] wrote", shotlib.export(shots[name]))
    if "--sheet" in argv:
        for name in names:
            print("[cinema] sheet", sheet(shots[name]))
    if "--preview" in argv:
        size = (960, 540)
        t_from, t_to, stills, eye = 0.0, None, None, None
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
            elif a.startswith("--eye="):
                eye = [float(v) for v in a.split("=")[1].split(",")]
        for name in names:
            print("[cinema] preview", preview(shots[name], size, t_from, t_to, stills, eye))


if __name__ == "__main__":
    main()
