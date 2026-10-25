"""Parts for detailed props, on top of modelkit: the small things that make a prop read as real
at arm's length. Bolts, panel seams, louvred vents, handles, hinges, printed labels, rubber feet,
wheels with tyres and rims, cans and bottles, pipes with flanges.

Everything is in Blender space: x across, y depth (props face -Y), z up; 1 unit = 1 stud, and
props are built at about 3.5 studs to the metre (a player is 5.2 studs tall)."""

import math

import bpy

import modelkit as mk
from common import srgb

M = 3.5  # studs per metre

FONT_PATHS = [r"C:\Windows\Fonts\YuGothB.ttc", r"C:\Windows\Fonts\msgothic.ttc"]


# Materials ------------------------------------------------------------------------------------------


def metal(name, rgb_a, rgb_b, rough=0.4, metallic=0.6, scale=18):
    return mk.noisy(name, srgb(*rgb_a), srgb(*rgb_b), scale=scale, roughness=rough, metallic=metallic)


def paint(name, rgb, rough=0.45, wear=12, scale=14):
    """Painted metal or plastic: the colour with a little grime mixed in."""
    r, g, b = rgb
    return mk.noisy(name, srgb(max(0, r - wear), max(0, g - wear), max(0, b - wear)), srgb(r, g, b), scale=scale,
                    roughness=rough)


def plastic(name, rgb, rough=0.35):
    return paint(name, rgb, rough=rough, wear=6, scale=24)


def rubber(name="PK_Rubber"):
    return mk.noisy(name, srgb(16, 16, 18), srgb(30, 30, 32), scale=30, roughness=0.9)


def chrome(name="PK_Chrome"):
    return metal(name, (150, 154, 160), (200, 204, 210), rough=0.2, metallic=1.0, scale=30)


def dark_glass(name="PK_DarkGlass", tint=(24, 30, 40)):
    """Glass seen from outside at night: dark, slightly blue, with a soft sheen (it bakes opaque)."""
    r, g, b = tint
    return mk.noisy(name, srgb(r, g, b), srgb(r + 26, g + 32, b + 44), scale=3, roughness=0.08, stretch=(1, 1, 0.2))


def glow(name, rgb, strength=4.0):
    return mk.emissive(name, srgb(*rgb), strength)


# Letters --------------------------------------------------------------------------------------------


def font():
    f = bpy.data.fonts.get("DeathsGambitJP") or bpy.data.fonts.get("InkboundJP")
    if f:
        return f
    for path in FONT_PATHS:
        try:
            f = bpy.data.fonts.load(path)
            f.name = "DeathsGambitJP"
            return f
        except Exception:  # noqa: BLE001 - try the next font
            continue
    return None


def text(name, body, size, loc, mat, rot=(90, 0, 0), depth=0.0, align="CENTER"):
    """Letters as geometry (baked into the prop's texture), facing -Y by default."""
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = depth
    curve.resolution_u = 2
    curve.align_x = align
    curve.align_y = "CENTER"
    f = font()
    if f:
        curve.font = f
    curve.materials.append(mat)
    obj = bpy.data.objects.new(name, curve)
    obj.location = loc
    obj.rotation_euler = [math.radians(a) for a in rot]
    mk._link(obj)
    return obj


def label(name, body, size, loc, ink, plate=None, pad=0.15, rot=(90, 0, 0), plate_depth=0.04):
    """A printed label: letters on a plate that faces -Y (or turned by rot about its centre)."""
    parts = [text(name, body, size, loc, ink, rot=rot)]
    if plate is not None:
        n = max(1, len(body))
        w = size * 0.95 * n + pad * 2
        h = size * 1.2 + pad * 2
        x, y, z = loc
        if tuple(rot) == (90, 0, 0):
            parts.append(mk.box(name + "Plate", (w, plate_depth, h), (x, y + plate_depth / 2 + 0.005, z), mat=plate))
    return parts


# Small parts ----------------------------------------------------------------------------------------


def bolts(name, points, mat, r=0.06, depth=0.05, axis="y"):
    """Round bolt heads at points, standing out along -Y (axis "y"), +Z ("z") or -X ("x")."""
    rot = {"y": (90, 0, 0), "z": (0, 0, 0), "x": (0, 90, 0)}[axis]
    return [mk.cylinder(name, r, depth, p, rot=rot, mat=mat, verts=8) for p in points]


def seam(name, a, b, mat, w=0.04, d=0.02):
    """A thin dark line between panels, from a to b (both on a face)."""
    return mk.tube(name, a, b, w / 2, mat=mat, verts=4)


def louvres(name, x, y, z, w, h, mat, count=None, depth=0.08, tilt=30):
    """A louvred vent on a face at -Y: slats across (w by h), centred at (x, y, z)."""
    count = count or max(3, int(h / 0.22))
    parts = [mk.box(name + "Frame", (w, depth, h), (x, y + depth / 2, z), mat=mat, bevel=0.02)]
    for k in range(count):
        zz = z - h / 2 + h * (k + 0.5) / count
        parts.append(mk.box(name + "Slat", (w - 0.08, 0.05, h / count * 0.7), (x, y - 0.03, zz), rot=(tilt, 0, 0),
                            mat=mat))
    return parts


def handle(name, x, y, z, length, mat, vertical=True, stand=0.12, r=0.05):
    """A bar handle standing `stand` out from a face at -Y, with two stubs."""
    if vertical:
        a, b = (x, y - stand, z - length / 2), (x, y - stand, z + length / 2)
        s0, s1 = (x, y, z - length / 2 + 0.05), (x, y, z + length / 2 - 0.05)
    else:
        a, b = (x - length / 2, y - stand, z), (x + length / 2, y - stand, z)
        s0, s1 = (x - length / 2 + 0.05, y, z), (x + length / 2 - 0.05, y, z)
    return [mk.tube(name, a, b, r, mat=mat, verts=8),
            mk.tube(name + "S", s0, (s0[0], s0[1] - stand, s0[2]), r * 0.8, mat=mat, verts=6),
            mk.tube(name + "S", s1, (s1[0], s1[1] - stand, s1[2]), r * 0.8, mat=mat, verts=6)]


def hinge(name, x, y, z, h, mat):
    return [mk.cylinder(name, 0.06, h, (x, y, z), mat=mat, verts=8)]


def feet(name, points, mat, r=0.12, h=0.1):
    return [mk.cylinder(name, r, h, (x, y, h / 2), mat=mat, verts=10) for x, y in points]


def wheel(prefix, x, y, r, width, tyre, rim, hub=None, spokes=5, z=None):
    """A wheel turning about X at (x, y), its bottom on the ground (or centred at z): a tyre with a
    rounded tread, a rim with spokes and a hub cap."""
    z = r if z is None else z
    hub = hub or rim
    parts = [
        mk.cylinder(prefix + "Tyre", r, width, (x, y, z), rot=(0, 90, 0), mat=tyre, verts=24, bevel=width * 0.25),
        mk.cylinder(prefix + "Rim", r * 0.62, width + 0.04, (x, y, z), rot=(0, 90, 0), mat=rim, verts=20),
        mk.cylinder(prefix + "Hub", r * 0.2, width + 0.1, (x, y, z), rot=(0, 90, 0), mat=hub, verts=12),
    ]
    side = 1 if x >= 0 else -1
    face = x + side * (width / 2 + 0.03)
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        parts.append(mk.tube(prefix + "Spoke", (face, y, z), (face, y + math.cos(a) * r * 0.58, z + math.sin(a) * r * 0.58),
                             r * 0.07, mat=rim, verts=5))
    return parts


def spoked_wheel(prefix, x, y, r, tyre, rim, spokes=16):
    """A bicycle wheel turning about X, in the YZ plane at x: a thin tyre, a rim and wire spokes."""
    parts = [mk.torus(prefix + "Tyre", r - 0.06, 0.07, (x, y, r), rot=(0, 90, 0), mat=tyre, major_segments=28,
                      minor_segments=6),
             mk.torus(prefix + "Rim", r - 0.16, 0.035, (x, y, r), rot=(0, 90, 0), mat=rim, major_segments=24,
                      minor_segments=4),
             mk.cylinder(prefix + "Hub", 0.1, 0.28, (x, y, r), rot=(0, 90, 0), mat=rim, verts=8)]
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        off = 0.1 if k % 2 else -0.1
        parts.append(mk.tube(prefix + "Spoke", (x + off, y, r), (x, y + math.cos(a) * (r - 0.18), r + math.sin(a) * (r - 0.18)),
                             0.012, mat=rim, verts=3))
    return parts


def can(name, x, y, z, mat, top, r=0.22, h=0.8):
    """A drinks can standing at (x, y, z)."""
    return [mk.cylinder(name, r, h, (x, y, z + h / 2), mat=mat, verts=12),
            mk.cylinder(name + "Top", r * 0.86, 0.06, (x, y, z + h + 0.02), mat=top, verts=12)]


def bottle(name, x, y, z, mat, cap, r=0.24, h=1.3):
    """A plastic drinks bottle: body, shoulder, neck and cap."""
    body = mk.lathe(name, [(0.0, 0), (r, 0.02), (r, h * 0.62), (r * 0.9, h * 0.7), (r * 0.42, h * 0.84),
                           (r * 0.36, h * 0.92), (0.0, h * 0.92)], (x, y, z), mat=mat, segments=12)
    return [body, mk.cylinder(name + "Cap", r * 0.4, h * 0.1, (x, y, z + h * 0.97), mat=cap, verts=10)]


def pipe(name, a, b, r, mat, flanges=True):
    parts = [mk.tube(name, a, b, r, mat=mat, verts=12)]
    if flanges:
        for p in (a, b):
            parts.append(mk.tube(name + "F", p, tuple(pv + (bv - pv) * 0.04 for pv, bv in zip(p, b)), r * 1.5, mat=mat,
                                 verts=12))
    return parts


def rounded(name, size, loc, mat, r=0.08, rot=(0, 0, 0)):
    """A box with rounded edges (bevel of 3 segments)."""
    return mk.box(name, size, loc, rot=rot, mat=mat, bevel=r, segments=3)


def frame(name, w, h, t, depth, loc, mat, rot=(0, 0, 0)):
    """A rectangular frame (w by h, bar thickness t) lying in the XZ plane at loc, `depth` deep."""
    x, y, z = loc
    return [
        mk.box(name + "T", (w, depth, t), (x, y, z + h / 2 - t / 2), rot=rot, mat=mat, bevel=0.02),
        mk.box(name + "B", (w, depth, t), (x, y, z - h / 2 + t / 2), rot=rot, mat=mat, bevel=0.02),
        mk.box(name + "L", (t, depth, h - 2 * t), (x - w / 2 + t / 2, y, z), rot=rot, mat=mat, bevel=0.02),
        mk.box(name + "R", (t, depth, h - 2 * t), (x + w / 2 - t / 2, y, z), rot=rot, mat=mat, bevel=0.02),
    ]


def skull(name, loc, r, mat, dark, yaw=0.0, segments=48, teeth=7):
    """A carved human skull of cranium radius `r` at `loc`, facing -Y turned `yaw` degrees about Z: one sculpted
    shell (the domed cranium swelling behind, temples pinched in, a brow ridge, cheekbones, the face drawn down and
    forward into the jaw and chin) with the eye sockets, the nose's hollow and the line of the mouth pressed into it
    in `dark`, and a row of `teeth` along each side of the mouth (none for 0; a small skull far off needs fewer, and
    fewer `segments`). Parts: [shell, teeth]."""
    import bmesh
    from mathutils import Vector

    def shape(v):
        x, y, z = v
        x *= 0.8
        z *= 0.86
        if y > 0:
            y *= 1.1  # the back of the head swells
        if abs(x) > 0.55 and -0.4 < z < 0.3 and y < 0.2:
            x *= 0.94  # the temples
        if z < 0.12 and y < 0:  # the face, drawn forward and narrowing
            f = min(1.0, (0.12 - z) / 0.8) * min(1.0, -y / 0.55)
            y -= 0.16 * f
            x *= 1 - 0.22 * f
            z -= 0.08 * f
        if y < -0.2 and z < -0.35:  # the jaw, drawn down into a chin
            g = min(1.0, (-0.35 - z) / 0.4) * min(1.0, (-0.2 - y) / 0.5)
            z -= 0.3 * g
            x *= 1 - 0.28 * g
            y -= 0.04 * g
        if z < -0.62 and y > -0.3:
            z = -0.62 + (z + 0.62) * 0.3  # the flat underside behind it
        return Vector((x, y, z))

    def front(x, z_orig):
        """The shaped surface point in front at width x (shaped) and the height a unit-sphere z of `z_orig` takes."""
        y = -math.sqrt(max(0.0, 1 - (x / 0.8) ** 2 - z_orig ** 2))
        return shape(Vector((x / 0.8, y, z_orig)))

    eyes = [front(sx * 0.32, -0.04) for sx in (-1, 1)]
    nose = front(0.0, -0.36)
    zm = front(0.0, -0.56).z  # the mouth's line

    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=segments * 3 // 5, radius=1.0)
    for v in bm.verts:
        v.co = shape(v.co)
    bm.normal_update()
    for v in bm.verts:
        p, n = v.co.copy(), v.normal.copy()
        for sx in (-1, 1):  # the cheekbones
            c = front(sx * 0.5, -0.3)
            dc = (p - c).length
            if dc < 0.24:
                p += n * 0.06 * (1 - dc / 0.24)
        if p.y < -0.5 and abs(p.z - (eyes[0].z + 0.2)) < 0.06 and abs(p.x) < 0.62:  # the brow ridge
            p += n * 0.035
        if p.y < -0.4 and abs(p.x) < 0.36 and abs(p.z - zm) < 0.03:  # the mouth's line
            p -= n * 0.04
        v.co = p
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y < -0.4 and abs(c.x) < 0.34 and abs(c.z - zm) < 0.012:
            f.material_index = 1
        f.smooth = True
    surface = [(v.co.copy(), v.normal.copy()) for v in bm.verts if v.co.y < -0.3 and abs(v.co.z - zm) < 0.1]
    shell = mk._obj_from_bm(name, bm, mat)
    shell.data.materials.append(dark)

    # The sockets and the nose cut clean out of the shell (their walls in `dark`), and the cutters thrown away.
    cutters = []
    for e in eyes:  # (rounded and tilted down at the outer corner, like the orbits)
        socket = mk.sphere(name + "Socket", 1.0, (e.x, e.y + 0.1, e.z), scale=(0.24, 0.3, 0.19), mat=dark,
                           segments=max(8, min(20, segments // 2)), rings=max(6, min(12, segments // 4)))
        socket.rotation_euler = (0, math.copysign(math.radians(14), e.x), 0)
        cutters.append(socket)
    # (a three-sided cone along -Y, its apex up and widest at the face: the nose's hollow)
    cutters.append(mk.cylinder(name + "NoseCut", 0.08, 0.5, (0.0, nose.y + 0.16, nose.z + 0.03), rot=(90, 0, 0),
                               mat=dark, verts=3, radius2=0.15))
    cutters[-1].scale = (0.9, 1.25, 1.0)
    for cutter in cutters:
        cut = shell.modifiers.new(cutter.name, "BOOLEAN")
        cut.operation = "DIFFERENCE"
        cut.solver = "EXACT"
        cut.material_mode = "TRANSFER"
        cut.object = cutter
    depsgraph = bpy.context.evaluated_depsgraph_get()
    carved = bpy.data.meshes.new_from_object(shell.evaluated_get(depsgraph))
    shell.modifiers.clear()
    shell.data = carved
    for poly in carved.polygons:
        poly.use_smooth = True
    for cutter in cutters:
        bpy.data.objects.remove(cutter, do_unlink=True)

    # The teeth: a row above and below the mouth's line, set on the surface there.
    count = teeth
    teeth = []
    for row, dz in (("Upper", 0.05), ("Lower", -0.05)) if count > 0 else ():
        for k in range(count):
            x = -0.28 + 0.56 * k / max(1, count - 1)
            p, n = min(surface, key=lambda s: (s[0].x - x) ** 2 + 4 * (s[0].z - zm - dz) ** 2 + 0.01 * s[0].y)
            yaw_t = math.degrees(math.atan2(n.x, -n.y))
            teeth.append(mk.box(name + row + "Tooth", (0.082, 0.07, 0.088), (p.x + n.x * 0.004, p.y + n.y * 0.004, zm + dz),
                                rot=(0, 0, yaw_t), mat=mat, bevel=0.022 if count > 5 else 0.0))
    parts = [shell] + ([mk.merge(teeth, name + "Teeth")] if teeth else [])
    for obj in parts:
        obj.scale = (r, r, r)
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = (0, 0, math.radians(yaw))
        obj.location = loc
    return parts
