"""The apple loading screen's hand (UI/AppleLoading), modelled and rendered in 3D: a death god's hand in the spirit of
Ryuk's (drawn for this game, not traced from any art). Redone 2026-11-06 at your word ("make ryuks hand more detailed
and high quality textured and rendered"): the painted hand of 2026-11-05 was flat airbrushed grey.

Long gaunt fingers of bone with swollen knuckles creased across, a bony palm cupped round the apple, the ball of the
thumb, a thin forearm; skin a dark blue-grey with pores, fine wrinkles and a mottle of darker blotches, a little light
through it; long black claws with a lacquered shine; a black leather band at the wrist, stitched along both edges,
with steel studs. Lit as the apple is (a soft key from the upper left and in front), a cold rim from behind, and the
apple's own red thrown back onto everything facing it.

It keeps the old hand's contract with the game exactly (art/scripts/ui/apple_hand.py holds it: the picture over your
sketch, HELD, the thumb's axis, hinge, square and open angle), so UI/AppleLoading, LoadingArt.luau and the apple's
sheets are untouched. Three renders:

    AppleHandBack   the whole hand without the apple: seen where the apple is not (the cup of the palm while it waits)
    AppleHandFront  the hand round the apple: the apple held out (a shadow catcher), so what lies behind it is cut away
                    and the fingers' shadows fall on it
    AppleThumb      the thumb alone (the hand held out in front of it, its shadow caught on the apple), on its square

Coordinates are your sketch's px; Blender's world is 1/100 of them: x right, z up (the sketch's y down), y away from
the camera (depth, px; negative is toward you).

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup
        --python art/scripts/ui/apple_hand_3d.py   (one line)
    (add -- --quick for a fast low-sample look, -- --out DIR to write somewhere else)
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import apple_hand as ah  # noqa: E402
import paint as pt  # noqa: E402
import png  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
QUICK = "--quick" in ARGS
OUT = ARGS[ARGS.index("--out") + 1] if "--out" in ARGS else os.path.join(ROOT, "art", "export", "textures")

U = 0.01  # Blender units per sketch px
SUPER = 2  # rendered at twice the picture's size, then averaged down
BALL = 0.575  # a lone metaball's surface lies at this share of its radius
CHAIN = 0.7  # ... and a close chain of them at this share

CX, CY, RX, RY = ah.HELD
RD = 96.0  # the apple's half depth, px
ROOT_FADE = (2.0, 7.0)  # sketch px from the thumb's root: its picture gone inside the first, whole past the second
CATCH_GROW = 2.5  # the apple held out a little wider than it is drawn, px, so no hand behind it shows round its edge


def W(x, y, d=0.0):
    """Sketch px (and depth px) to Blender's world."""
    return Vector((x * U, d * U, -y * U))


def apple_d(x, y):
    """How far out from the apple's middle (1 its outline as drawn)."""
    return math.hypot((x - CX) / RX, (y - CY) / RY)


def depth_at(x, y, r, base, press=0.8):
    """The depth of a finger's middle line at (x, y): laid on the apple's front where it crosses the apple (`press`
    of its radius `r` above the apple's skin, so it grips), easing back to `base` away from the apple's outline."""
    d = apple_d(x, y)
    if d < 1:
        return -(RD * math.sqrt(1 - d * d) + r * press)
    t = pt.smoothstep(1.0, 1.4, d)
    return -r * press * (1 - t) + base * t


# The model ------------------------------------------------------------------------------------------------------------

def metaball(name, resolution):
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = 0.6
    ob = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(ob)
    return mb, ob


def ball(mb, at, r, negative=False):
    """A metaball whose surface, alone, lies `r` px from `at` (world)."""
    e = mb.elements.new()
    e.co = at
    e.radius = r * U / BALL
    e.use_negative = negative
    return e


def chain(mb, points, radii, base, press=0.8, spacing=0.28):
    """A tube through `points` (sketch px), `radii` px along it, laid over the apple (depth_at): metaballs close
    enough that their surface runs smooth. Returns the world points of its middle line and their radii."""
    line = ah.spline(points, 12)
    r_at = np.interp(np.linspace(0, 1, len(line)), np.linspace(0, 1, len(radii)), radii)
    # resample so the balls stand `spacing` of their radius apart
    seg = np.r_[0, np.cumsum(np.hypot(*np.diff(np.array(line), axis=0).T))]
    out, s = [], 0.0
    while s <= seg[-1]:
        x = np.interp(s, seg, [p[0] for p in line])
        y = np.interp(s, seg, [p[1] for p in line])
        r = float(np.interp(s, seg, r_at))
        d = depth_at(x, y, r, base, press)
        e = mb.elements.new()
        e.co = W(x, y, d)
        e.radius = r * U / CHAIN
        out.append((W(x, y, d), r))
        s += max(0.6, spacing * r / CHAIN)
    return out


def ellipsoid(mb, at, half, angle=0.0, negative=False):
    """A metaball ellipsoid whose surface reaches `half` (px: across, depth, up) from `at` (world), turned `angle`
    degrees in the picture's plane (counterclockwise as you see it)."""
    e = mb.elements.new()
    e.type = "ELLIPSOID"
    e.co = at
    big = max(half)
    e.radius = big * U / BALL
    e.size_x, e.size_y, e.size_z = half[0] / big, half[1] / big, half[2] / big
    e.rotation = Quaternion((0, 1, 0), math.radians(-angle))
    e.use_negative = negative
    return e


def hand_parts(mb):
    """The hand but its thumb: forearm, wrist, palm cupped round the apple, the ball of the thumb, the bones of the
    back of the hand, the four fingers. Returns each finger's joints (world points, the way the finger runs there,
    its radius), for the creases, and each fingertip (world point, way, radius), for the claws."""
    # the forearm, up out of the lower left to the wrist and on into the heel of the hand
    elbow = np.array(ah.WRIST) - ah.ARM_WAY * 230
    chain(mb, [tuple(elbow), tuple(np.array(ah.WRIST) - ah.ARM_WAY * 110), ah.WRIST, (742, 800)],
          [42, 39, 36, 34], base=12, press=0)
    # the palm under the apple, the heel of the hand, the ball of the thumb up the apple's left side
    ellipsoid(mb, W(842, 786, 22), (104, 70, 40), angle=14)
    ellipsoid(mb, W(760, 812, 14), (46, 52, 38), angle=30)
    ellipsoid(mb, W(733, 740, -4), (30, 40, 50), angle=-12)
    # the thumb's root as the hand's own skin, a shade thinner than the thumb, so the thumb's picture turns over it
    # (it is drawn on its own) and nothing shows where the two meet
    chain(mb, ah.THUMB_AXIS[:2], [w / 2 * 0.9 for w in ah.THUMB_WIDTHS[:2]], base=-8)
    # the bones of the back of the hand, standing out under thin skin, wrist to each knuckle
    for f, depth in zip(ah.FINGERS, (-20, -26, -30, -32)):
        k = f["joints"][0]
        chain(mb, [(752, 806), ((752 + k[0]) / 2, (806 + k[1]) / 2 + 4), k], [4.5, 4, 6.5], base=depth, press=0)
    # the apple's place, cupped out of the palm
    ellipsoid(mb, W(CX, CY, 0), (RX + 5, RD + 5, RY + 5), negative=True)
    ball(mb, W(*ah.WRIST_BONE, -8), 12)
    joints, tips = [], []
    for f, base in zip(ah.FINGERS, (46, 18, -8, -30)):
        axis, widths = ah.finger_axis(f)
        radii = [w / 2 for w in widths]
        line = chain(mb, axis, radii, base=base)
        ball(mb, line[0][0], radii[0] * 1.08)  # the knuckle
        for k in (1, 2):
            joints.append(_on_line(line, f["joints"][k], radii[2 * k]))
        a, b = line[-4][0], line[-1][0]
        tips.append((b, (b - a).normalized(), line[-1][1], f["claw"]))
    return joints, tips


def _on_line(line, at, r):
    """The point of a chain's middle line nearest the sketch point `at`, the way the line runs there, and `r`."""
    pts = [p for p, _ in line]
    target = W(*at)
    k = min(range(len(pts)), key=lambda i: (pts[i].x - target.x) ** 2 + (pts[i].z - target.z) ** 2)
    a, b = pts[max(0, k - 2)], pts[min(len(pts) - 1, k + 2)]
    return pts[k], (b - a).normalized(), r


def thumb_parts(mb):
    """The thumb, root to tip, laid over the apple's front; its joint and its tip."""
    radii = [w / 2 for w in ah.THUMB_WIDTHS]
    line = chain(mb, ah.THUMB_AXIS, radii, base=-8)
    ball(mb, _on_line(line, ah.THUMB_JOINT, 0)[0], 13)
    ellipsoid(mb, W(CX, CY, 0), (RX + 5, RD + 5, RY + 5), negative=True)
    a, b = line[-4][0], line[-1][0]
    return [_on_line(line, ah.THUMB_JOINT, 12)], (b, (b - a).normalized(), line[-1][1], (30, 30))


def to_mesh(ob, name):
    """A metaball object as a mesh object (smooth shaded)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    me.name = name
    out = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(out)
    bpy.data.objects.remove(ob)
    for p in me.polygons:
        p.use_smooth = True
    return out


def creases(ob, joints, count=3):
    """Folds of skin across each joint: `count` grooves pressed into the surface across the finger's way, deepest on
    its outside, fading round it; a little wavy, as skin folds are."""
    me = ob.data
    n = len(me.vertices)
    co = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(n, 3)
    nor = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("normal", nor)
    nor = nor.reshape(n, 3)
    push = np.zeros(n, np.float32)
    for at, way, r in joints:
        r_w = r * U
        rel = co - np.array(at)
        way = np.array(way)
        t = rel @ way
        perp = rel - np.outer(t, way)
        dist = np.linalg.norm(perp, axis=1)
        near = (np.abs(t) < r_w * 0.9) & (dist < r_w * 1.9)
        if not near.any():
            continue
        side = np.arctan2(perp[:, 0], perp[:, 2])
        tt = t + r_w * 0.12 * np.sin(side * 3.0)
        period = r_w * 0.3
        phase = (tt / period) - np.round(tt / period)
        groove = np.exp(-((phase * period) / (r_w * 0.1)) ** 2)
        span = np.exp(-(t / (r_w * 0.16 * count)) ** 2)
        push = np.where(near, np.maximum(push, groove * span), push)
    amp = 0.75 * U
    co -= nor * (push * amp)[:, None]
    me.vertices.foreach_set("co", co.ravel())
    me.update()


def tube(name, line, radii, ring=16, flat=1.0):
    """A closed tube (mesh object) along `line` (world points), `radii` (world) along it, pointed where a radius is
    0; its cross-section squashed to `flat` along the depth."""
    import bmesh

    bm = bmesh.new()
    rings = []
    for k, (p, r) in enumerate(zip(line, radii)):
        a = line[min(k + 1, len(line) - 1)] - line[max(k - 1, 0)]
        a.normalize()
        side = a.cross(Vector((0, 1, 0)))
        if side.length < 1e-4:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(a).normalized()
        verts = []
        for i in range(ring):
            t = 2 * math.pi * i / ring
            verts.append(bm.verts.new(p + side * (r * math.cos(t)) + up * (r * flat * math.sin(t))))
        rings.append(verts)
    for r0, r1 in zip(rings[:-1], rings[1:]):
        for i in range(ring):
            bm.faces.new((r0[i], r0[(i + 1) % ring], r1[(i + 1) % ring], r1[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def claw(name, tip, way, r, length_hook):
    """A claw growing out of a fingertip: from over the end of the last bone (a nail plate), on along the finger and
    hooking toward the apple, tapering to a point; a little flattened, as a nail is."""
    length, hook = length_hook
    to_apple = (W(CX, CY, 0) - tip)
    to_apple -= way * to_apple.dot(way)
    bend = to_apple.normalized() if to_apple.length > 1e-6 else Vector((0, 0, -1))
    root = tip - way * (r * U * 0.9)
    pts, radii = [], []
    steps = 22
    for k in range(steps + 1):
        s = k / steps
        along = way * (s * (length + r * 0.9) * U)
        curl = bend * (math.sin(math.radians(hook)) * (s ** 2) * length * 0.55 * U)
        pts.append(root + along + curl - Vector((0, r * U * 0.35, 0)) * (1 - s))
        radii.append(r * U * 0.62 * (1 - s) ** 0.8 + 0.25 * U * s)
    return tube(name, pts, radii, ring=14, flat=0.62)


def band():
    """The leather band round the wrist (a short thick tube, its edges rounded) and its studs."""
    import bmesh

    mid_along = (ah.BAND[0] + ah.BAND[1]) / 2
    centre = np.array(ah.WRIST) + ah.ARM_WAY * mid_along
    axis = Vector((ah.ARM_WAY[0], 0, -ah.ARM_WAY[1])).normalized()
    half_len = abs(ah.BAND[1] - ah.BAND[0]) / 2 * U
    radius = 44.5 * U
    bm = bmesh.new()
    seg, rows = 72, 9
    side = axis.cross(Vector((0, 1, 0))).normalized()
    up = side.cross(axis).normalized()
    c = W(centre[0], centre[1], 12)
    grid = []
    for j in range(rows):
        v = j / (rows - 1) * 2 - 1
        bulge = 1 + 0.06 * (1 - v * v) - 0.05 * (abs(v) ** 6)
        row = []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            p = c + axis * (v * half_len) + (side * math.cos(t) + up * math.sin(t)) * (radius * bulge)
            row.append(bm.verts.new(p))
        grid.append(row)
    for r0, r1 in zip(grid[:-1], grid[1:]):
        for i in range(seg):
            bm.faces.new((r0[i], r0[(i + 1) % seg], r1[(i + 1) % seg], r1[i]))
    # (closed at both ends just inside the arm, so it reads as a solid strap)
    bm.faces.new(list(reversed(grid[0])))
    bm.faces.new(grid[-1])
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for loop in f.loops:
            p = loop.vert.co - c
            u = (math.atan2(p.dot(up), p.dot(side)) / (2 * math.pi)) % 1.0
            loop[uv].uv = (u, (p.dot(axis) / half_len + 1) / 2)
    me = bpy.data.meshes.new("Band")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new("Band", me)
    bpy.context.scene.collection.objects.link(ob)
    sub = ob.modifiers.new("Smooth", "SUBSURF")
    sub.levels = sub.render_levels = 1
    studs = []
    toward = Vector((0, -1, 0))
    for k, t in enumerate(np.linspace(-1.25, 1.25, 5)):
        # round the front of the band (as you see it), along its middle
        ang = math.atan2(toward.dot(up), toward.dot(side)) + t
        normal = side * math.cos(ang) + up * math.sin(ang)
        at = c + normal * (radius * 1.05)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=5.6 * U, location=at)
        s = bpy.context.active_object
        s.name = f"Stud{k}"
        s.scale = (1, 1, 0.55)
        s.rotation_mode = "QUATERNION"
        s.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(normal)
        bpy.ops.object.shade_smooth()
        studs.append(s)
    return ob, studs


# Materials ------------------------------------------------------------------------------------------------------------

def _nodes(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for node in list(nt.nodes):
        nt.nodes.remove(node)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return m, nt, bsdf


def _tex(nt, kind, coord, **inputs):
    node = nt.nodes.new(kind)
    nt.links.new(coord, node.inputs["Vector"])
    for key, value in inputs.items():
        if key in node.inputs:
            node.inputs[key].default_value = value
        else:
            setattr(node, key, value)
    return node


def _mix(nt, a, b, fac, blend="MIX"):
    node = nt.nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    node.blend_type = blend
    if isinstance(fac, float):
        node.inputs["Factor"].default_value = fac
    else:
        nt.links.new(fac, node.inputs["Factor"])
    for slot, value in ((6, a), (7, b)):
        if isinstance(value, tuple):
            node.inputs[slot].default_value = value
        else:
            nt.links.new(value, node.inputs[slot])
    return node.outputs[2]


def _math(nt, op, a, b=None):
    node = nt.nodes.new("ShaderNodeMath")
    node.operation = op
    for slot, value in ((0, a), (1, b)):
        if value is None:
            continue
        if isinstance(value, (int, float)):
            node.inputs[slot].default_value = value
        else:
            nt.links.new(value, node.inputs[slot])
    return node.outputs[0]


def skin_material():
    """A death god's skin: dark blue-grey, mottled with darker blotches and a cold violet in the hollows, pores and fine
    wrinkles in its bump, a little light through it (subsurface), a dull sheen."""
    m, nt, bsdf = _nodes("Skin")
    coord = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    mottle = _tex(nt, "ShaderNodeTexNoise", coord, Scale=9.0, Detail=6.0, Roughness=0.6)
    blotch = _tex(nt, "ShaderNodeTexNoise", coord, Scale=3.2, Detail=3.0, Roughness=0.5)
    base = _mix(nt, (0.040, 0.054, 0.086, 1), (0.090, 0.108, 0.150, 1), mottle.outputs["Fac"])
    dark = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(blotch.outputs["Fac"], dark.inputs["Value"])
    dark.inputs["From Min"].default_value = 0.52
    dark.inputs["From Max"].default_value = 0.7
    base = _mix(nt, base, (0.036, 0.032, 0.058, 1), dark.outputs["Result"])
    # veins: thin raised lines winding under the skin, a deeper blue
    vein_noise = _tex(nt, "ShaderNodeTexNoise", coord, Scale=3.6, Detail=3.0, Roughness=0.45)
    vein = _math(nt, "SUBTRACT", 1.0, _math(nt, "MINIMUM", 1.0, _math(nt, "MULTIPLY", 10.0, _math(
        nt, "ABSOLUTE", _math(nt, "SUBTRACT", vein_noise.outputs["Fac"], 0.5)))))
    vein = _math(nt, "POWER", vein, 1.6)
    base = _mix(nt, base, (0.034, 0.046, 0.090, 1), _math(nt, "MULTIPLY", vein, 0.4))
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.12
    ao.samples = 16
    nt.links.new(base, ao.inputs["Color"])
    hollow = _mix(nt, (0.022, 0.02, 0.036, 1), base, ao.outputs["AO"])
    nt.links.new(hollow, bsdf.inputs["Base Color"])
    bsdf.inputs["Subsurface Weight"].default_value = 0.12
    bsdf.inputs["Subsurface Radius"].default_value = (0.45, 0.55, 0.9)
    bsdf.inputs["Subsurface Scale"].default_value = 0.03
    rough = _tex(nt, "ShaderNodeTexNoise", coord, Scale=14.0, Detail=4.0)
    rr = nt.nodes.new("ShaderNodeMapRange")
    nt.links.new(rough.outputs["Fac"], rr.inputs["Value"])
    rr.inputs["To Min"].default_value = 0.42
    rr.inputs["To Max"].default_value = 0.68
    nt.links.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
    bsdf.inputs["Specular IOR Level"].default_value = 0.45
    # bump: pores (cells), fine wrinkles (stretched noise), the slow lumps of skin over bone
    pores = _tex(nt, "ShaderNodeTexVoronoi", coord, Scale=150.0)
    pores.feature = "F1"
    wrinkle_coord = nt.nodes.new("ShaderNodeMapping")
    nt.links.new(coord, wrinkle_coord.inputs["Vector"])
    wrinkle_coord.inputs["Scale"].default_value = (1.0, 1.0, 3.2)
    wrinkle_coord.inputs["Rotation"].default_value = (0.0, 0.7, 0.0)
    wrinkles = _tex(nt, "ShaderNodeTexNoise", wrinkle_coord.outputs["Vector"], Scale=34.0, Detail=10.0, Roughness=0.62,
                    Distortion=0.4)
    lumps = _tex(nt, "ShaderNodeTexNoise", coord, Scale=6.0, Detail=2.0)
    height = _math(nt, "ADD", _math(nt, "MULTIPLY", pores.outputs["Distance"], 0.35),
                   _math(nt, "ADD", _math(nt, "MULTIPLY", wrinkles.outputs["Fac"], 0.8),
                         _math(nt, "ADD", _math(nt, "MULTIPLY", lumps.outputs["Fac"], 0.5),
                               _math(nt, "MULTIPLY", vein, 0.7))))
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.42
    bump.inputs["Distance"].default_value = 0.004
    nt.links.new(height, bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def claw_material():
    """Black horn, lacquered: near black, a clear coat, faint ridges along its length."""
    m, nt, bsdf = _nodes("Claw")
    bsdf.inputs["Base Color"].default_value = (0.010, 0.010, 0.013, 1)
    bsdf.inputs["Roughness"].default_value = 0.32
    bsdf.inputs["Coat Weight"].default_value = 0.8
    bsdf.inputs["Coat Roughness"].default_value = 0.08
    coord = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    ridges = _tex(nt, "ShaderNodeTexNoise", coord, Scale=60.0, Detail=3.0)
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.15
    bump.inputs["Distance"].default_value = 0.002
    nt.links.new(ridges.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def leather_material():
    """Black leather: a soft sheen, a pebbled grain, grey stitches along both edges, its edges worn a shade lighter."""
    m, nt, bsdf = _nodes("Leather")
    uv = nt.nodes.new("ShaderNodeUVMap").outputs["UV"]
    coord = nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(uv, sep.inputs["Vector"])
    u, v = sep.outputs["X"], sep.outputs["Y"]
    # stitches: dashes round the band at 0.16 and 0.84 of its width
    dash = _math(nt, "GREATER_THAN", _math(nt, "SINE", _math(nt, "MULTIPLY", u, 2 * math.pi * 70)), 0.15)
    rows = None
    for at in (0.16, 0.84):
        near = _math(nt, "LESS_THAN", _math(nt, "ABSOLUTE", _math(nt, "SUBTRACT", v, at)), 0.035)
        rows = near if rows is None else _math(nt, "MAXIMUM", rows, near)
    stitch = _math(nt, "MULTIPLY", dash, rows)
    edge = _math(nt, "GREATER_THAN", _math(nt, "ABSOLUTE", _math(nt, "SUBTRACT", v, 0.5)), 0.44)
    col = _mix(nt, (0.012, 0.012, 0.014, 1), (0.05, 0.048, 0.05, 1), edge)
    col = _mix(nt, col, (0.30, 0.30, 0.32, 1), stitch)
    nt.links.new(col, bsdf.inputs["Base Color"])
    grain = _tex(nt, "ShaderNodeTexVoronoi", coord, Scale=90.0)
    rough = _math(nt, "ADD", 0.38, _math(nt, "MULTIPLY", grain.outputs["Distance"], 0.4))
    nt.links.new(rough, bsdf.inputs["Roughness"])
    height = _math(nt, "ADD", grain.outputs["Distance"], _math(nt, "MULTIPLY", stitch, 0.6))
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.003
    nt.links.new(height, bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def steel_material():
    m, nt, bsdf = _nodes("Steel")
    bsdf.inputs["Base Color"].default_value = (0.62, 0.63, 0.66, 1)
    bsdf.inputs["Metallic"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.22
    return m


def apple_glow_material():
    """The apple as the hand sees it: its red, thrown back onto the skin facing it."""
    m, nt, bsdf = _nodes("AppleGlow")
    bsdf.inputs["Base Color"].default_value = (0.75, 0.012, 0.02, 1)
    bsdf.inputs["Roughness"].default_value = 0.35
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.02, 0.03, 1)
    bsdf.inputs["Emission Strength"].default_value = 0.4
    return m


def give(ob, material):
    ob.data.materials.clear()
    ob.data.materials.append(material)


# The scene ------------------------------------------------------------------------------------------------------------

def apple(name, grow, material=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=1.0, location=W(CX, CY, 0))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = ((RX + grow) * U, (RD + grow) * U, (RY + grow) * U)
    bpy.ops.object.shade_smooth()
    if material is not None:
        give(ob, material)
    return ob


def lights():
    world = bpy.data.worlds.new("Night")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.012, 0.014, 0.024, 1)
    bg.inputs["Strength"].default_value = 1.0
    bpy.context.scene.world = world
    light = ah.LIGHT  # toward the light: x right, y down, z away (the sketch's)
    toward = Vector((light[0], light[2], -light[1])).normalized()
    key = bpy.data.lights.new("Key", "SUN")
    key.energy = 3.4
    key.angle = math.radians(9)
    key.color = (1.0, 0.97, 0.93)
    ko = bpy.data.objects.new("Key", key)
    ko.rotation_mode = "QUATERNION"
    ko.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(toward)
    bpy.context.scene.collection.objects.link(ko)
    rim = bpy.data.lights.new("Rim", "SUN")
    rim.energy = 4.0
    rim.angle = math.radians(14)
    rim.color = (0.55, 0.66, 1.0)
    ro = bpy.data.objects.new("Rim", rim)
    ro.rotation_mode = "QUATERNION"
    ro.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector((0.55, 0.75, 0.35)).normalized())
    bpy.context.scene.collection.objects.link(ro)


def camera_and_render():
    sc = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    x0, y0, x1, y1 = ah.HAND_BOX
    cam.ortho_scale = (x1 - x0) * U
    co = bpy.data.objects.new("Cam", cam)
    co.location = W((x0 + x1) / 2, (y0 + y1) / 2, -2000)
    co.rotation_euler = (math.radians(90), 0, 0)
    cam.clip_end = 100
    sc.collection.objects.link(co)
    sc.camera = co
    r = sc.render
    r.engine = "CYCLES"
    r.resolution_x, r.resolution_y = ah.HW * SUPER, ah.HH * SUPER
    r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.cycles.samples = 48 if QUICK else 256
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 8
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = kind
                prefs.get_devices()
                if any(d.type == kind for d in prefs.devices):
                    for d in prefs.devices:
                        d.use = d.type == kind
                    sc.cycles.device = "GPU"
                    print("[hand3d] rendering on", kind)
                    break
            except TypeError:
                continue
    except KeyError:
        pass


def shown(objects, camera=True, shadow=True, rays=True, holdout=False, catcher=False):
    for ob in objects:
        ob.hide_render = False
        ob.visible_camera = camera
        ob.visible_shadow = shadow
        ob.visible_diffuse = rays
        ob.visible_glossy = rays
        ob.visible_transmission = rays
        ob.visible_volume_scatter = rays
        ob.is_holdout = holdout
        ob.is_shadow_catcher = catcher


def hidden(objects):
    for ob in objects:
        ob.hide_render = True


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    big = png.read(path).astype(np.float32) / 255.0
    h, w = big.shape[0] // SUPER, big.shape[1] // SUPER
    a = big[..., 3:]
    blocks = (big[..., :3] * a).reshape(h, SUPER, w, SUPER, 3).mean(axis=(1, 3))
    alpha = a.reshape(h, SUPER, w, SUPER, 1).mean(axis=(1, 3))
    rgb = blocks / np.maximum(alpha, 1e-6)
    return np.concatenate([np.clip(rgb, 0, 1), alpha], -1).astype(np.float32)


def thumb_on_square(picture):
    """The thumb's render laid on its square (the thumb's root its middle) and faded at the root where it turns
    (only just: the hand holds it out where it lies inside the hand, and a longer fade left a dark gap as it stands)."""
    x, y = ah.hgrid()
    reach = np.hypot(x - ah.THUMB_PIVOT[0], y - ah.THUMB_PIVOT[1])
    keep = pt.smoothstep(ROOT_FADE[0], ROOT_FADE[1], reach)
    picture = picture.copy()
    picture[..., 3] *= keep
    px, py, half = ah.thumb_square()
    out = np.zeros((2 * half, 2 * half, 4), np.float32)
    x0, y0 = int(round(px)) - half, int(round(py)) - half
    xa, ya = max(0, x0), max(0, y0)
    xb, yb = min(ah.HW, x0 + 2 * half), min(ah.HH, y0 + 2 * half)
    out[ya - y0: yb - y0, xa - x0: xb - x0] = picture[ya:yb, xa:xb]
    return out


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    res = 0.012 if QUICK else 0.0075
    hand_mb, hand_meta = metaball("HandMeta", res)
    joints, tips = hand_parts(hand_mb)
    thumb_mb, thumb_meta = metaball("ThumbMeta", res)
    thumb_joints, thumb_tip = thumb_parts(thumb_mb)
    hand = to_mesh(hand_meta, "Hand")
    thumb = to_mesh(thumb_meta, "Thumb")
    knuckles = [(p, w, r) for p, w, r in joints]
    creases(hand, knuckles)
    creases(thumb, thumb_joints)
    skin = skin_material()
    give(hand, skin)
    give(thumb, skin)
    claws = [claw(f"Claw{k}", *t) for k, t in enumerate(tips)]
    thumb_claw = claw("ClawThumb", *thumb_tip)
    horn = claw_material()
    for c in claws + [thumb_claw]:
        give(c, horn)
    strap, studs = band()
    give(strap, leather_material())
    steel = steel_material()
    for s in studs:
        give(s, steel)
    glow = apple("AppleGlow", -3.0, apple_glow_material())
    catcher = apple("AppleCatcher", CATCH_GROW)
    lights()
    camera_and_render()

    body = [hand, strap] + claws + studs
    thumbs = [thumb, thumb_claw]
    tmp = os.path.join(OUT, "_hand3d_render.png")
    os.makedirs(OUT, exist_ok=True)

    # the back: the whole hand, no apple anywhere (it shows only where no apple is)
    shown(body)
    hidden(thumbs + [glow, catcher])
    back = render(tmp)
    # the front: the apple held (its red thrown on the hand, it shades the palm), held out of the picture where it
    # lies in front of the hand, the fingers' shadows caught on it
    shown([glow], camera=False)
    shown([catcher], shadow=False, rays=False, catcher=True)
    front = render(tmp)
    # the thumb: alone, the hand held out where it lies in front of it, its own shadow caught on the apple
    shown(thumbs)
    shown(body, shadow=False, holdout=True)
    thumb_picture = thumb_on_square(render(tmp))
    os.remove(tmp)
    png.write(os.path.join(OUT, "AppleHandBack.png"), back)
    png.write(os.path.join(OUT, "AppleHandFront.png"), front)
    png.write(os.path.join(OUT, "AppleThumb.png"), thumb_picture)
    print("[hand3d] wrote AppleHandBack, AppleHandFront, AppleThumb to", OUT)
    if "--blend" in ARGS:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "_hand3d.blend"))


main()
