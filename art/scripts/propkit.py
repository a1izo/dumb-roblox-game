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


def sweep(name, points, radius, mat, sides=6, caps=True):
    """A round bar along the bent line through points (a cord, a coil, a chain's run, a curled stem): one mesh, its
    rings carried along the line so it does not twist, each joint sharing its ring. radius: one number, or one per
    point."""
    import bmesh
    from mathutils import Vector

    pts = [Vector(p) for p in points]
    radii = list(radius) if isinstance(radius, (list, tuple)) else [radius] * len(pts)
    bm = bmesh.new()
    dirs = [(pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized() for k in range(len(pts))]
    w = dirs[0]
    u = w.cross(Vector((0, 0, 1)) if abs(w.z) < 0.9 else Vector((1, 0, 0))).normalized()
    rings = []
    for k, p in enumerate(pts):
        w = dirs[k]
        u = (u - w * u.dot(w)).normalized()
        v = w.cross(u)
        rings.append([bm.verts.new(p + (u * math.cos(2 * math.pi * j / sides) + v * math.sin(2 * math.pi * j / sides))
                                   * radii[k]) for j in range(sides)])
    for k in range(len(pts) - 1):
        for j in range(sides):
            j1 = (j + 1) % sides
            bm.faces.new((rings[k][j], rings[k + 1][j], rings[k + 1][j1], rings[k][j1]))
    if caps:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mk._obj_from_bm(name, bm, mat)
    mk.smooth(obj)
    return obj


def boundary_loop(bm, keep):
    """The open edge of a bmesh (a hood's face opening, a sleeve's cuff) as a list of points in order along it,
    taking only the boundary edges whose two ends pass keep(co); [] when there are none. A whole loop comes back
    closed (its first point again at its end); a part of one, open."""
    edges = [e for e in bm.edges if e.is_boundary and all(keep(v.co) for v in e.verts)]
    if not edges:
        return []
    picked = set(edges)
    ends = [v for v in {v for e in edges for v in e.verts} if sum(1 for e in v.link_edges if e in picked) == 1]
    start = min(ends or {v for e in edges for v in e.verts}, key=lambda v: v.co.z)
    loop, seen, cur = [start], {start}, start
    while True:
        nxt = [e.other_vert(cur) for e in cur.link_edges if e in picked and e.other_vert(cur) not in seen]
        if not nxt:
            break
        cur = nxt[0]
        seen.add(cur)
        loop.append(cur)
    if not ends:
        loop.append(start)
    return [tuple(v.co) for v in loop]


def coil(name, a, b, turns, coil_r, wire_r, mat, sag=0.0):
    """A coiled cord from a to b (a telephone's): a helix of `turns` round the line between them, `coil_r` out from
    it, the wire `wire_r` thick; sag drops its middle."""
    from mathutils import Vector

    a, b = Vector(a), Vector(b)
    axis = (b - a)
    w = axis.normalized()
    u = w.cross(Vector((0, 0, 1)) if abs(w.z) < 0.9 else Vector((1, 0, 0))).normalized()
    v = w.cross(u)
    n = max(8, int(turns * 10))
    pts = []
    for k in range(n + 1):
        t = k / n
        ang = 2 * math.pi * turns * t
        ease = min(1.0, t * 12, (1 - t) * 12)  # (the ends straighten into their sockets)
        p = a + axis * t + (u * math.cos(ang) + v * math.sin(ang)) * coil_r * ease
        p.z -= sag * 4 * t * (1 - t)
        pts.append(p)
    return sweep(name, pts, wire_r, mat, sides=5)


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


def _metaball_mesh(name, elements, resolution, keep):
    """A mesh grown from metaball elements, as props_lobby._blob makes them: ("ellipsoid", centre, radius,
    (sx, sy, sz)), ("capsule", a, b, radius) or ("hollow", centre, radius, (sx, sy, sz)) carving the others, radii
    being the surface's own; keep: the share of its triangles kept. Returns a bmesh."""
    import bmesh
    from mathutils import Vector

    import common

    meta = bpy.data.metaballs.new(name)
    meta.resolution = meta.render_resolution = resolution
    meta.threshold = 0.6
    holder = bpy.data.objects.new(name, meta)
    common.collection("Build").objects.link(holder)
    for element in elements:
        if element[0] in ("ellipsoid", "hollow"):
            _, centre, radius, (sx, sy, sz) = element
            el = meta.elements.new(type="ELLIPSOID")
            el.co = centre
            el.size_x, el.size_y, el.size_z = sx, sy, sz
            el.use_negative = element[0] == "hollow"
        else:
            _, a, b, radius = element
            a, b = Vector(a), Vector(b)
            el = meta.elements.new(type="CAPSULE")
            el.co = (a + b) / 2
            el.size_x = (b - a).length / 2
            el.rotation = Vector((1.0, 0.0, 0.0)).rotation_difference((b - a).normalized())
        el.radius = radius / 0.575  # (a surface radius, at stiffness 2 and threshold 0.6)
        el.stiffness = 2.0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(holder.evaluated_get(depsgraph))
    bpy.data.objects.remove(holder, do_unlink=True)
    bpy.data.metaballs.remove(meta)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bpy.data.meshes.remove(mesh)
    if keep < 1.0:
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        target = int(len(bm.faces) * keep)
        tmp = bpy.data.meshes.new(name + "Thin")
        bm.to_mesh(tmp)
        obj = bpy.data.objects.new(name + "Thin", tmp)
        common.collection("Build").objects.link(obj)
        thin = obj.modifiers.new("Thin", "DECIMATE")
        thin.ratio = target / max(1, len(tmp.polygons))
        done = bpy.data.meshes.new_from_object(obj.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.meshes.remove(tmp)
        bm.free()
        bm = bmesh.new()
        bm.from_mesh(done)
        bpy.data.meshes.remove(done)
    return bm


def skull(name, loc, r, mat, dark, yaw=0.0, segments=48, teeth=7):
    """A carved human skull of cranium radius `r` at `loc`, facing -Y turned `yaw` degrees about Z, cut to look
    menacing (asked 2026-10-25: "their shapes look goofy right now, make them scarier"): one surface grown as a
    real skull is built (the cranium, a heavy brow ridge dipping toward the middle into a scowl, the cheekbones
    flaring out wide under the eyes and running back as arches, the hollow temples, the face drawn down over sunken
    cheeks, the jaw squared at its angles round to the chin), with big sockets cut deep into it slanting down toward
    the nose, a tall pear-shaped nasal hollow, and a grin of long, uneven teeth set into the bone above and below the
    mouth's dark line, `teeth` in each row (none for 0; a small skull far off needs fewer, and fewer `segments`, which
    sets how finely it is grown). Parts: [shell, teeth]."""
    import random

    from mathutils import Vector

    # (no ridges standing over the eyes: two of them read as eyebrows made of bone, asked 2026-10-25 "the eyebrows on
    # the skull look weird"; the forehead itself comes down flat into one shelf of bone over both sockets)
    els = [("ellipsoid", (0.0, 0.12, 0.22), 1.0, (0.8, 0.95, 0.84)),  # the cranium
           ("ellipsoid", (0.0, -0.35, 0.24), 0.6, (1.12, 0.8, 0.95)),  # the forehead
           ("ellipsoid", (0.0, -0.6, -0.02), 0.44, (1.42, 0.52, 0.5)),  # its shelf over the sockets
           ("ellipsoid", (0.0, -0.58, -0.46), 0.36, (1.15, 0.85, 1.0)),  # the face, over the upper teeth
           ("ellipsoid", (0.0, -0.64, -0.97), 0.16, (1.5, 0.8, 1.0))]  # the chin
    for sx in (-1, 1):
        els += [("capsule", (sx * 0.36, -0.72, -0.32), (sx * 0.68, -0.32, -0.3), 0.11),  # a cheekbone
                ("capsule", (sx * 0.68, -0.32, -0.3), (sx * 0.64, 0.1, -0.28), 0.06),  # its arch, back to the ear
                ("capsule", (sx * 0.5, -0.12, -0.78), (sx * 0.28, -0.6, -0.94), 0.14),  # the jaw, from its angle
                ("capsule", (sx * 0.28, -0.6, -0.94), (0.0, -0.64, -0.96), 0.14),  # to the chin
                ("capsule", (sx * 0.5, -0.12, -0.78), (sx * 0.56, 0.06, -0.32), 0.1),  # the jaw's branch up
                ("hollow", (sx * 0.86, -0.2, -0.04), 0.16, (0.4, 1.0, 1.0)),  # the temple
                ("hollow", (sx * 0.42, -0.84, -0.6), 0.12, (1.0, 0.7, 1.0)),  # the cheek, sunken
                ("hollow", (sx * 0.3, -0.86, -0.13), 0.19, (1.1, 1.0, 0.95))]  # the socket's start
    # (a bead of a skull, segments under 12, grown coarser still and thinned harder: a few hundred triangles)
    res = max(0.045, 2.4 / max(8, segments))
    bm = _metaball_mesh(name, els, res, 0.7 if segments >= 12 else 0.4)
    for f in bm.faces:
        f.smooth = True
    bm.normal_update()

    def front_at(x, z, verts):
        """The face's front surface nearest (x, z) as seen from -Y: (point, normal)."""
        best = min((v for v in verts if v.co.y < 0), key=lambda v: (v.co.x - x) ** 2 + (v.co.z - z) ** 2 + 0.02 * v.co.y)
        return best.co.copy(), best.normal.copy()

    zm = -0.79  # the mouth's line
    eyes = [front_at(sx * 0.3, -0.13, bm.verts)[0] for sx in (-1, 1)]
    nose = front_at(0.0, -0.42, bm.verts)[0]
    crack = []  # (a crack running down the forehead from the crown: the line of a thin groove cut into the bone)
    for x, z in ((0.07, 0.96), (0.12, 0.84), (0.1, 0.72), (0.17, 0.6), (0.15, 0.48), (0.2, 0.4)) if segments >= 20 else ():
        p, n = front_at(x, z, bm.verts)
        crack.append(p - n * 0.01)
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y < -0.45 and abs(c.x) < 0.33 and abs(c.z - zm) < 0.026:
            f.material_index = 1
    shell = mk._obj_from_bm(name, bm, mat)
    shell.data.materials.append(dark)

    # The sockets and the nose cut clean out of the shell (their walls in `dark`), and the cutters thrown away.
    cutters = []
    for e in eyes:  # (big and deep, slanting down toward the nose, cut low enough that the brow's bone overhangs them)
        socket = mk.sphere(name + "Socket", 1.0, (e.x * 1.05, e.y + 0.13, e.z - 0.05), scale=(0.27, 0.38, 0.2), mat=dark,
                           segments=max(8, min(20, segments // 2)), rings=max(6, min(12, segments // 4)))
        # (its top edge cut straight, sloping down toward the nose under the brow: the scowl is in the bone)
        inner = -1.0 if e.x > 0 else 1.0
        for v in socket.data.vertices:
            v.co.z = min(v.co.z, 0.42 - 0.38 * v.co.x * inner)
        socket.rotation_euler = (0, -math.copysign(math.radians(10), e.x), 0)
        cutters.append(socket)
    # (the nasal hollow: a tall three-sided cone along -Y, its apex up and its base wide and low: a pear)
    cutters.append(mk.cylinder(name + "NoseCut", 0.06, 0.55, (0.0, nose.y + 0.18, nose.z + 0.03), rot=(90, 0, 0),
                               mat=dark, verts=3, radius2=0.16))
    cutters[-1].scale = (0.85, 1.45, 1.0)
    if crack:
        cutters.append(sweep(name + "Crack", crack, [0.012, 0.02, 0.022, 0.02, 0.016, 0.008], dark, sides=4))
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

    # The teeth: long and uneven, a row above and below the mouth's line, each set into the bone (sunk a little
    # into the face there, so none stands off it).
    count = teeth
    teeth = []
    rng = random.Random(sum(map(ord, name)))
    for row, sign in (("Upper", 1), ("Lower", -1)) if count > 0 else ():
        for k in range(count):
            x = -0.26 + 0.52 * k / max(1, count - 1)
            tall = 0.15 * rng.uniform(0.85, 1.15) * (1.3 if k in (1, count - 2) else 1.0)
            p, n = front_at(x, zm + sign * 0.06, carved.vertices)
            n.z = 0.0
            n.normalize()
            yaw_t = math.degrees(math.atan2(n.x, -n.y))
            teeth.append(mk.box(name + row + "Tooth", (0.07, 0.08, tall),
                                (p.x - n.x * 0.02, p.y - n.y * 0.02, zm + sign * (0.012 + tall / 2)),
                                rot=(rng.uniform(-4, 4), rng.uniform(-5, 5), yaw_t), mat=mat,
                                bevel=0.02 if count > 5 else 0.0))
    parts = [shell] + ([mk.merge(teeth, name + "Teeth")] if teeth else [])
    for obj in parts:
        obj.scale = (r, r, r)
        obj.rotation_mode = "XYZ"
        obj.rotation_euler = (0, 0, math.radians(yaw))
        obj.location = loc
    return parts
