"""The VFX kit's meshes and its props file, DeathsGambitModels_Fx.fbx (set "Fx"): plain white shapes with their own
UVs laid for the effect textures (a ring's u runs round it and v across it, a tube's v up it...), every face drawn on
both sides, plus a carrier quad for each VFX texture so importing the file uploads them, the calibration cubes and
the version marker. Not baked like the other props (the bake would lay new UVs): the game puts a texture on them.

    blender -b --factory-startup --python art/scripts/vfx/meshes.py [-- --preview]

Sizes (Blender units = studs, Z up, so Roblox's Y): radius 1 round the Z axis, from z 0 up where they have a height.
Presentation/Vfx/Shape.luau knows each one's size and pivot.

UVs (V1.7, 2026-11-17) follow one rule, made for a texture that FLOWS when the mesh turns: u runs ONCE round the
shape's axis (0 to 1, the seam on +X where the first column meets the last, one lattice step wide like every other
column, so a texture that tiles left to right shows no seam), v runs UP it (0 at its base or foot, 1 at its tip or top;
Blender's v counts up from the image's bottom, so an upright picture stands upright and its bottom row is the base).
A shape that is not a body of revolution says in its docstring how it is laid out (a flat ring: u round, v from the
inner edge 0 to the outer edge 1; a band or blade: u along it, v across it with the cutting or outer edge at 1; a
rock: round the Z axis, seam cut into the mesh). Spinning a part about its up then slides the picture round it, and
raising it slides the picture up. art/scripts/vfx/check_meshes.py checks every shape and draws the contact sheet.
Before V1.7 the rule was the opposite (rows ALONG the shape, v = 1 - along, textures twice round); nothing in the game
puts a texture on these meshes but the Manual's page, which did not change.
"""

import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import common  # noqa: E402
from maps import export as maps_export  # noqa: E402

SET = "Fx"
FBX = os.path.join(common.EXPORT, "DeathsGambitModels_Fx.fbx")

# Every texture the kit carries (art/scripts/vfx/textures.py writes them), in the order of the carrier quads.
TEXTURES = [
    "VfxFlame", "VfxCandleFlame", "VfxGlow", "VfxFlare", "VfxEmber", "VfxStreak", "VfxSpike", "VfxBurst", "VfxRing",
    "VfxRingBand", "VfxColumn", "VfxSlash", "VfxSlashBand", "VfxWisp", "VfxDust", "VfxSmoke", "VfxCrack", "VfxCircle",
    "VfxPage", "VfxFeather", "VfxMoth", "VfxChunk", "VfxAsh",
    # the new library (V1.1 to V1.6, the Fx file from ModelsFx 4); each wears an old name in Vfx/Tex.luau until imported
    "VfxSmokePuff", "VfxSmokePlume", "VfxDustRoll", "VfxMist", "VfxImpactA", "VfxImpactB", "VfxImpactC", "VfxShock",
    "VfxGlint", "VfxSparks", "VfxSlashA", "VfxSlashB", "VfxArc", "VfxEnergyWisp", "VfxAshFlakes", "VfxShards",
    "VfxPaper", "VfxFeatherTumble", "VfxCrackA", "VfxCrackB", "VfxScorch", "VfxSigil",
    # V1.2's light fire sheets (the Fx file from ModelsFx 5); each wears a flame in Vfx/Tex.luau until imported
    "VfxFire", "VfxFireBurst", "VfxCandle", "VfxAuraFlame",
]


def _white():
    mat = bpy.data.materials.get("Vfx_White") or bpy.data.materials.new("Vfx_White")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 1, 1, 1)
    return mat


def _mesh(name, verts, faces, uvs, double=True):
    """A mesh from vertices, faces (index lists) and a UV per face corner (lists matching the faces); with `double`
    each face is drawn again turned the other way, with the same UVs."""
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    all_faces, all_uvs = list(faces), list(uvs)
    if double:
        for f, u in zip(faces, uvs):
            all_faces.append(list(reversed(f)))
            all_uvs.append(list(reversed(u)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], all_faces)
    layer = mesh.uv_layers.new(name="UVMap")
    k = 0
    for poly, corner_uvs in zip(mesh.polygons, all_uvs):
        for li, uv in zip(poly.loop_indices, corner_uvs):
            layer.data[li].uv = uv
            k += 1
    mesh.materials.append(_white())
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.update()
    if double:
        _two_sided_normals(mesh, verts, faces)
    obj = bpy.data.objects.new(name, mesh)
    common.collection("VfxMeshes").objects.link(obj)
    obj["dg_vfx"] = True
    return obj


def _two_sided_normals(mesh, verts, faces):
    """Gives a doubled mesh its normals (V1.7). Left to Blender, a face and its twin share every vertex, so their
    normals cancel (zero vectors, or the front's pushed onto the back); a lit texture would shade wrongly and the FBX
    would carry the garbage. Here each vertex's normal is the average of the FRONT faces that stand at its place
    (the seam's twin vertices and the pole's fan agree), and each back face takes the opposite."""
    def place(p):
        return (round(p[0], 5), round(p[1], 5), round(p[2], 5))

    acc = {}
    for f in faces:
        pts = [verts[i] for i in f]
        n = [0.0, 0.0, 0.0]
        for k in range(len(pts)):  # (Newell: its length is the face's area, so big faces count more)
            a, b = pts[k], pts[(k + 1) % len(pts)]
            n[0] += (a[1] - b[1]) * (a[2] + b[2])
            n[1] += (a[2] - b[2]) * (a[0] + b[0])
            n[2] += (a[0] - b[0]) * (a[1] + b[1])
        for i in f:
            s = acc.setdefault(place(verts[i]), [0.0, 0.0, 0.0])
            for c in range(3):
                s[c] += n[c]

    def unit(v):
        length = math.sqrt(sum(c * c for c in v))
        return tuple(c / length for c in v) if length > 1e-12 else (0.0, 0.0, 1.0)

    normals = []
    for poly in mesh.polygons:
        back = poly.index >= len(faces)
        for li in poly.loop_indices:
            n = unit(acc[place(verts[mesh.loops[li].vertex_index])])
            normals.append(tuple(-c for c in n) if back else n)
    mesh.normals_split_custom_set(normals)


def _grid(name, rows, cols, point, uv, wrap=True, double=True):
    """A surface from a (rows+1) x (cols+1) lattice: point(i, j) and uv(i, j) for row i, column j; with `wrap` the
    last column joins the first (its own UVs kept, so a texture wraps round whole)."""
    verts, index = [], {}
    for i in range(rows + 1):
        for j in range(cols + 1):
            index[(i, j)] = len(verts)
            verts.append(point(i, j))
    faces, uvs = [], []
    for i in range(rows):
        for j in range(cols):
            a, b, c, d = (i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)
            faces.append([index[a], index[b], index[c], index[d]])
            uvs.append([uv(*a), uv(*b), uv(*c), uv(*d)])
    return _mesh(name, verts, faces, uvs, double)


def ring():
    """VfxRing: a flat ring, radius 1 out, 0.55 in, lying in the ground's plane. Not a body of height: u round it once
    (0 to 1 from +X, counter-clockwise seen from above), v across it from its inner edge 0 to its outer edge 1 (a
    shockwave's front is the picture's top row). Before V1.7: u across (outer 0 to inner 1), v round twice."""
    n = 96
    return _grid("VfxRing", 1, n,
                 lambda i, j: (math.cos(2 * math.pi * j / n) * (1.0 - 0.45 * i), math.sin(2 * math.pi * j / n) * (1.0 - 0.45 * i), 0.0),
                 lambda i, j: (j / n, 1.0 - float(i)))


def dome():
    """VfxDome: a half sphere of radius 1 over z 0; u round it once, v up from its rim 0 to its top 1 (the top ring
    stays 1.5% short of the pole, a hole 0.02 wide that nothing shows). Before V1.7: u rim to top, v round twice."""
    n, m = 64, 16
    def point(i, j):
        a = 2 * math.pi * j / n
        e = math.pi / 2 * min(i / m, 0.985)
        return (math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))
    return _grid("VfxDome", m, n, point, lambda i, j: (j / n, i / m))


def tube():
    """VfxTube: an open tube of radius 1 from z 0 to 2; u round it once, v up it from its foot 0 to its top 1.
    Before V1.7: u round twice, v = 1 - up (its foot the picture's top row)."""
    n, m = 48, 8
    return _grid("VfxTube", m, n,
                 lambda i, j: (math.cos(2 * math.pi * j / n), math.sin(2 * math.pi * j / n), 2.0 * i / m),
                 lambda i, j: (j / n, i / m))


def cone():
    """VfxCone: an open cone, radius 1 at z 0 narrowing to 0.06 at z 2 (a burst flung up, a funnel turned over); u
    round it once, v up it from its wide foot 0 to its point 1. Before V1.7: u round twice, v = 1 - up (the old text
    said v 0 at the foot; the code gave 1)."""
    n, m = 48, 10
    def point(i, j):
        r = 1.0 - 0.94 * (i / m) ** 0.85
        return (math.cos(2 * math.pi * j / n) * r, math.sin(2 * math.pi * j / n) * r, 2.0 * i / m)
    return _grid("VfxCone", m, n, point, lambda i, j: (j / n, i / m))


def swirl():
    """VfxSwirl: a ribbon wound one and a half times up round the Z axis, radius 1 at its foot to 0.65 at z 2, its
    band 0.5 tall. A helical band, so u runs ALONG the ribbon once, from its foot (0) to its end (1, one and a half
    turns on), and v across the band, its lower edge 0 to its upper 1. Before V1.7: u across, v along three times
    (and 1 at the foot)."""
    n = 120
    turns = 1.5
    def point(i, j):
        s = j / n
        a = 2 * math.pi * turns * s
        r = 1.0 - 0.35 * s
        z = 2.0 * s * 0.8 + (i - 0.5) * 0.5 * (0.6 + 0.4 * math.sin(math.pi * s))
        return (math.cos(a) * r, math.sin(a) * r, max(z, 0.0) + 0.25)
    return _grid("VfxSwirl", 1, n, point, lambda i, j: (j / n, float(i)), wrap=False)


def crescent():
    """VfxCrescent: a flat crescent blade in the ground's plane, a 200-degree arc of radius 1 round its middle, wide
    in the middle and sharp at both ends. A band: u along it from its tail (0) to its head (1), v across it from its
    inner edge 0 to its outer (cutting) edge 1. Before V1.7: u across (outer 0, inner 1), v along, 1 at the tail."""
    n = 64
    span = math.radians(200)
    def point(i, j):
        s = j / n
        a = -span / 2 + span * s
        width = 0.34 * math.sin(math.pi * s) ** 0.8
        r = 1.0 - width * i
        return (math.cos(a) * r, math.sin(a) * r, 0.0)
    return _grid("VfxCrescent", 1, n, point, lambda i, j: (j / n, 1.0 - float(i)), wrap=False)


def sphere():
    """VfxSphere: a sphere of radius 1 round its middle, one-sided (outside only); u round it once, v up from the
    south pole 0 to the north pole 1. The rows nearest each pole stop 0.4% short of it, a hole nothing shows, and a
    texture pinches into it: VfxShell is the sphere for a texture. Before V1.7: u twice round, v = 1 - up."""
    n, m = 48, 24
    def point(i, j):
        a = 2 * math.pi * j / n
        e = -math.pi / 2 + math.pi * min(max(i / m, 0.004), 0.996)
        return (math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))
    return _grid("VfxSphere", m, n, point, lambda i, j: (j / n, i / m), double=False)


def spike_ball(seed=3):
    """VfxSpikes: fourteen sharp spikes thrown out from a point in every direction, 0.6 to 1 long; each spike's v runs
    0 at its root to 1 at its point, u round it."""
    rng = random.Random(seed)
    verts, faces, uvs = [], [], []
    for k in range(14):
        z = rng.uniform(-0.6, 1.0)
        a = rng.uniform(0, 2 * math.pi)
        d = (math.cos(a) * math.sqrt(1 - z * z), math.sin(a) * math.sqrt(1 - z * z), z)
        length = rng.uniform(0.6, 1.0)
        # two vectors across the spike
        up = (0, 0, 1) if abs(d[2]) < 0.9 else (1, 0, 0)
        ax = (d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0])
        n = math.sqrt(sum(c * c for c in ax))
        ax = tuple(c / n for c in ax)
        ay = (d[1] * ax[2] - d[2] * ax[1], d[2] * ax[0] - d[0] * ax[2], d[0] * ax[1] - d[1] * ax[0])
        base = len(verts)
        sides = 5
        r0 = 0.07
        for s in range(sides):
            t = 2 * math.pi * s / sides
            verts.append(tuple(math.cos(t) * r0 * ax[c] + math.sin(t) * r0 * ay[c] for c in range(3)))
        tip = len(verts)
        verts.append(tuple(d[c] * length for c in range(3)))
        for s in range(sides):
            faces.append([base + s, base + (s + 1) % sides, tip])
            uvs.append([(s / sides, 0.0), ((s + 1) / sides, 0.0), ((s + 0.5) / sides, 1.0)])
    return _mesh("VfxSpikes", verts, faces, uvs, double=False)


def shard(seed=5):
    """VfxShard: a long six-sided crystal pointed at both ends, 1 long (z -0.5 .. 0.5), for glass and stone thrown
    off; u round it once, v up it from its lower point 0 to its upper point 1 (each belt vertex's v is its own
    height, so v follows the jitter). Before V1.7: the lower point's u sat on its face's edge, so each lower face's
    picture leaned, and every belt vertex had v 0.45 whatever its height."""
    rng = random.Random(seed)
    sides = 6
    verts = [(0, 0, -0.5)]
    for s in range(sides):
        t = 2 * math.pi * s / sides
        r = 0.16 * rng.uniform(0.8, 1.15)
        verts.append((math.cos(t) * r, math.sin(t) * r * 0.7, rng.uniform(-0.12, 0.08)))
    verts.append((0, 0, 0.5))
    faces, uvs = [], []
    for s in range(sides):
        a, b = 1 + s, 1 + (s + 1) % sides
        va, vb = verts[a][2] + 0.5, verts[b][2] + 0.5
        faces.append([0, b, a])
        uvs.append([((s + 0.5) / sides, 0.0), ((s + 1) / sides, vb), (s / sides, va)])
        faces.append([a, b, sides + 1])
        uvs.append([(s / sides, va), ((s + 1) / sides, vb), ((s + 0.5) / sides, 1.0)])
    return _mesh("VfxShard", verts, faces, uvs, double=False)


def _round_uvs(verts, faces, seam=0.0):
    """Lays a lump round the Z axis: u = the angle round Z (0 at the angle `seam`, in radians), v = height from the
    lowest vertex 0 to the highest 1. A face that crosses the seam is cut in two there (new vertices on the seam
    plane, one piece with u ending at 1, the other starting at 0), so every UV stays inside 0..1 with no stretch. A
    vertex on the axis takes the mean u of its face. Returns (verts, faces, uvs)."""
    zs = [v[2] for v in verts]
    z0, z1 = min(zs), max(zs)
    tau = 2 * math.pi
    out_v, out_f, out_uv = [], [], []
    key = {}

    def vid(p):
        k = (round(p[0], 6), round(p[1], 6), round(p[2], 6))
        if k not in key:
            key[k] = len(out_v)
            out_v.append(tuple(p))
        return key[k]

    for f in faces:
        pts = [verts[i] for i in f]
        us = []
        for p in pts:
            on_axis = math.hypot(p[0], p[1]) < 1e-6
            us.append(None if on_axis else ((math.atan2(p[1], p[0]) - seam) / tau) % 1.0)
        known = [u for u in us if u is not None]
        if max(known) - min(known) > 0.5:  # crosses the seam: lift the low side past 1
            known = [u + 1.0 if u < 0.5 else u for u in known]
            us = [None if u is None else (u + 1.0 if u < 0.5 else u) for u in us]
        mean = sum(known) / len(known)
        corners = [(p, mean if u is None else u, (p[2] - z0) / (z1 - z0)) for p, u in zip(pts, us)]
        for side in (0, 1):  # side 0: the part with u <= 1, side 1: u >= 1 (moved back by 1)
            poly = []
            for k in range(len(corners)):
                p, u, v = corners[k]
                q, w, x = corners[(k + 1) % len(corners)]
                inside = (u <= 1.0) if side == 0 else (u >= 1.0)
                nxt = (w <= 1.0) if side == 0 else (w >= 1.0)
                if inside:
                    poly.append((p, u, v))
                if inside != nxt and abs(w - u) > 1e-9:
                    t = (1.0 - u) / (w - u)
                    poly.append((tuple(p[c] + (q[c] - p[c]) * t for c in range(3)), 1.0, v + (x - v) * t))
            if len(poly) < 3:
                continue
            if max(c[1] for c in poly) - min(c[1] for c in poly) < 1e-9:
                continue
            out_f.append([vid(c[0]) for c in poly])
            out_uv.append([(c[1] - side, c[2]) for c in poly])
    return out_v, out_f, out_uv


def rock(seed=8):
    """VfxRock: a broken lump of stone, about 1 across, flat-faced (debris thrown up by a landing). Not a body of
    revolution: its picture is laid round the Z axis (u once round from +X, v from its lowest point 0 to its highest
    1), and the faces over the +X seam are cut in two there so nothing stretches. Before V1.7: a plan view (u = x, v =
    y), so the sides were smeared."""
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5)
    obj = bpy.context.active_object
    for v in obj.data.vertices:
        v.co *= rng.uniform(0.75, 1.15)
        v.co.z *= 0.75
    verts = [tuple(v.co) for v in obj.data.vertices]
    faces = [list(p.vertices) for p in obj.data.polygons]
    bpy.data.objects.remove(obj, do_unlink=True)
    verts, faces, uvs = _round_uvs(verts, faces)
    made = _mesh("VfxRock", verts, faces, uvs, double=False)
    for poly in made.data.polygons:
        poly.use_smooth = False
    return made


def page():
    """VfxPage: a sheet of paper 1 wide and 1.4 tall, bowed a little, standing in the XZ plane. Flat, not round: u
    across (0 at -X), v up it (0 at its foot, 1 at its top), so the Manual's ruled page texture reads the right way
    up. Unchanged by V1.7 (it already followed the rule)."""
    cols, rows = 6, 8
    return _grid("VfxPage", rows, cols,
                 lambda i, j: (-0.5 + j / cols, 0.06 * math.sin(math.pi * j / cols) - 0.03, 1.4 * (1 - i / rows)),
                 lambda i, j: (j / cols, 1.0 - i / rows), wrap=False)


def slash_arc():
    """VfxSlashArc: a curved blade of light lying in the ground's plane, a 100-degree arc of radius 1 centred on +X,
    thin at both tips (0.01 wide) and widest in the middle (0.31), slightly cupped (its middle line lifts 0.3 of the
    width above the plane, so the blade has a shallow trough along it, not a flat card). A band like VfxCrescent but
    a shorter, narrower, truer blade: u along the arc from its tail (0) to its head (1), v across it from its inner
    edge 0 to its outer cutting edge 1. Stands in the XY plane (turn it to cut at any angle)."""
    n, m = 24, 4
    span = math.radians(100)
    def width(s):
        return 0.30 * math.sin(math.pi * s) ** 0.8 + 0.01
    def point(i, j):
        s = j / n
        a = -span / 2 + span * s
        t = i / m  # 0 at the cutting edge, 1 at the inner edge
        w = width(s)
        r = 1.0 - w * t
        return (math.cos(a) * r, math.sin(a) * r, 0.3 * w * math.sin(math.pi * t))
    return _grid("VfxSlashArc", m, n, point, lambda i, j: (j / n, 1.0 - i / m), wrap=False)


def twister():
    """VfxTwister: a tapering spiral shell, open at both ends: radius 0.12 at its foot (z 0) to 1 at its wide open top
    (z 2), its wall three lobes that twist one and a quarter turns up it and swell as they rise, its axis wandering
    a little (so it reads as a funnel of wind, not a smooth cone). u round it once, along the lobes' own spiral (a
    picture's vertical lines wind up the funnel), v up it from the foot 0 to the top 1."""
    n, m = 24, 12
    turns = 1.25
    def point(i, j):
        h = i / m
        a = 2 * math.pi * j / n
        r = (0.12 + 0.88 * h ** 1.4) * (1.0 + 0.16 * h ** 0.6 * math.cos(3 * a))
        b = a + 2 * math.pi * turns * h
        sway = 0.06 * h * math.sin(2 * math.pi * h)
        return (math.cos(b) * r + sway, math.sin(b) * r, 2.0 * h)
    return _grid("VfxTwister", m, n, point, lambda i, j: (j / n, i / m))


def shell():
    """VfxShell: a full sphere shell of radius 1 round its middle, drawn on both sides, for a texture. u round it once
    (0 at +X), v from the south pole 0 to the north pole 1. Each pole is ONE vertex with a fan of triangles whose
    corner there takes the middle of its own column, so nothing swirls or pinches into a point: the texture's last
    1/16 of rows at each end is the cap (every pole triangle covers that strip), so a texture for it keeps its top and
    bottom rows quiet (the kit's 4 px clear edge) and the pole cannot show. 32 columns by 16 rows."""
    n, m = 32, 16
    verts = [(0.0, 0.0, -1.0)]
    for i in range(1, m):
        e = -math.pi / 2 + math.pi * i / m
        for j in range(n + 1):
            a = 2 * math.pi * j / n
            verts.append((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
    verts.append((0.0, 0.0, 1.0))
    south, north = 0, len(verts) - 1
    def ring(i, j):  # the vertex of ring i (1 .. m - 1), column j (0 .. n)
        return 1 + (i - 1) * (n + 1) + j
    faces, uvs = [], []
    for j in range(n):
        faces.append([south, ring(1, j + 1), ring(1, j)])
        uvs.append([((j + 0.5) / n, 0.0), ((j + 1) / n, 1 / m), (j / n, 1 / m)])
    for i in range(1, m - 1):
        for j in range(n):
            faces.append([ring(i, j), ring(i, j + 1), ring(i + 1, j + 1), ring(i + 1, j)])
            uvs.append([(j / n, i / m), ((j + 1) / n, i / m), ((j + 1) / n, (i + 1) / m), (j / n, (i + 1) / m)])
    for j in range(n):
        faces.append([ring(m - 1, j), ring(m - 1, j + 1), north])
        uvs.append([(j / n, (m - 1) / m), ((j + 1) / n, (m - 1) / m), ((j + 0.5) / n, 1.0)])
    return _mesh("VfxShell", verts, faces, uvs)


BUILDERS = [ring, dome, tube, cone, swirl, crescent, sphere, spike_ball, shard, rock, page, slash_arc, twister, shell]


def carriers():
    """A small quad per VFX texture, its material showing the texture, so the import uploads each."""
    made = []
    for i, name in enumerate(TEXTURES):
        path = os.path.join(common.TEXTURES, name + ".png")
        if not os.path.exists(path):
            print("[vfx meshes] missing texture", name)
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
        common.collection("VfxTextures").objects.link(obj)
        obj.location = (40 + (i % 6) * 3, 0, (i // 6) * 3)
        made.append(obj)
    return made


def build_and_export():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    common.ensure_dirs()
    objects = []
    for k, build in enumerate(BUILDERS):
        obj = build()
        obj.location = (k * 3.0, 20.0, 0.0)  # (apart, for previews; the game uses each mesh alone)
        objects.append(obj)
        print("[vfx meshes]", obj.name, len(obj.data.polygons), "faces")
    objects += carriers()
    objects += maps_export.calibration_cubes(common.collection("CalibrationFx"), "Calib_Props" + SET, "Models" + SET)
    bpy.context.view_layer.update()
    for obj in bpy.data.objects:
        obj.select_set(obj in objects)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(
        filepath=FBX,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="Z",
        axis_up="Y",
        bake_space_transform=True,
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
        add_leaf_bones=False,
    )
    maps_export.write_versions()
    print("[vfx meshes] export", FBX)
    return FBX


if __name__ == "__main__":
    build_and_export()
