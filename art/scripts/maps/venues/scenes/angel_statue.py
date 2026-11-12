"""The mourning angel on her pedestal in Dead by selection's cemetery (2026-11-12, the user: "the statue - redo it too";
the first one was turned and swept primitives). Modelled here as one stone sculpture: the robe a cloth surface falling
in folds to a flared hem; the body and arms grown smooth from a skeleton (skin modifier, subdivided); the head bowed,
the hair framing the face and drawn back to a knot, both hands clasped at the breast, the sleeves hanging; and two great wings raised behind her
shoulders, each a bony leading edge with real feathers hung from it in three rows (long primaries, secondaries, short
coverts over them), every feather a curved blade with thickness. Reduced to a stone budget and handed to the set as
a smooth piece in Roblox's axes.

Built in Blender's axes (z up), facing +Y (Roblox +Z); feet at the origin, about 4 studs tall.
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

TARGET_TRIS = 16000


def _robe(bm):
    """The robe from the hem to the waist: a cloth surface whose folds run down from the sash, deepest at the hem."""
    seg, rings = 72, 22
    height = 2.08
    grid = []
    for i in range(rings + 1):
        t = i / rings
        z = t * height
        r = 0.42 + 0.38 * (1 - t) ** 1.4  # (flared at the hem, narrow at the waist)
        fold = 0.075 * (1 - t) ** 0.8 + 0.008
        row = []
        for j in range(seg):
            th = math.tau * j / seg
            wobble = math.sin(th * 11 + 0.6 * math.sin(th * 3) + t * 0.9) + 0.35 * math.sin(th * 23 + 1.3)
            rr = r + fold * wobble
            row.append(bm.verts.new((math.cos(th) * rr, math.sin(th) * rr * 0.86 - 0.04 * (1 - t), z)))
        grid.append(row)
    for i in range(rings):
        for j in range(seg):
            a, b = grid[i][j], grid[i][(j + 1) % seg]
            c, d = grid[i + 1][(j + 1) % seg], grid[i + 1][j]
            bm.faces.new((a, b, c, d))
    hem = bm.verts.new((0, 0, 0.02))
    for j in range(seg):
        bm.faces.new((grid[0][(j + 1) % seg], grid[0][j], hem))


def _skin_figure():
    """The body above the robe and the arms, from a skeleton (Blender's skin modifier, then subdivided smooth)."""
    me = bpy.data.meshes.new("AngelSkeleton")
    pts = {
        "pelvis": (0, 0.0, 1.95), "waist": (0, 0.0, 2.15), "chest": (0, 0.02, 2.55), "top": (0, -0.02, 2.86),
        "neck": (0, 0.05, 3.08),
        "l_sh": (-0.45, -0.02, 2.84), "l_el": (-0.46, 0.18, 2.34), "l_wr": (-0.12, 0.42, 2.58),
        "r_sh": (0.45, -0.02, 2.84), "r_el": (0.46, 0.18, 2.34), "r_wr": (0.12, 0.42, 2.58),
    }
    names = list(pts)
    edges = [("pelvis", "waist"), ("waist", "chest"), ("chest", "top"), ("top", "neck"), ("top", "l_sh"),
             ("l_sh", "l_el"), ("l_el", "l_wr"), ("top", "r_sh"), ("r_sh", "r_el"), ("r_el", "r_wr")]
    me.from_pydata([pts[n] for n in names], [(names.index(x), names.index(y)) for x, y in edges], [])
    obj = bpy.data.objects.new("AngelSkeleton", me)
    bpy.context.scene.collection.objects.link(obj)
    obj.modifiers.new("Skin", "SKIN")
    radii = {
        "pelvis": (0.42, 0.34), "waist": (0.38, 0.3), "chest": (0.4, 0.28), "top": (0.36, 0.24), "neck": (0.1, 0.1),
        "l_sh": (0.14, 0.14), "l_el": (0.12, 0.12), "l_wr": (0.085, 0.085),
        "r_sh": (0.14, 0.14), "r_el": (0.12, 0.12), "r_wr": (0.085, 0.085),
    }
    for i, n in enumerate(names):
        me.skin_vertices[0].data[i].radius = radii[n]
    me.skin_vertices[0].data[0].use_root = True
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    return obj


def _ellipsoid(bm, centre, radii, tilt_x=0.0, segments=24, rings=16):
    m = Matrix.Translation(Vector(centre)) @ Matrix.Rotation(math.radians(tilt_x), 4, "X") @ Matrix.Diagonal(
        (radii[0], radii[1], radii[2], 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0, matrix=m)


def _head_and_hands(bm):
    # the face, bowed: an oval, the nose and the brow standing from it
    _ellipsoid(bm, (0, 0.13, 3.32), (0.165, 0.19, 0.235), tilt_x=-26)
    _ellipsoid(bm, (0, 0.315, 3.27), (0.03, 0.05, 0.075), tilt_x=-30, segments=12, rings=8)
    _ellipsoid(bm, (0, 0.29, 3.37), (0.12, 0.04, 0.03), tilt_x=-26, segments=12, rings=8)
    # the hair: over the crown and down the sides, framing the face, drawn back to a knot at the nape
    _ellipsoid(bm, (0, 0.03, 3.4), (0.21, 0.215, 0.235), tilt_x=-26)
    for side in (-1, 1):
        _ellipsoid(bm, (side * 0.15, 0.1, 3.24), (0.075, 0.12, 0.17), tilt_x=-20, segments=14, rings=10)
    _ellipsoid(bm, (0, -0.16, 3.3), (0.12, 0.11, 0.12))
    # the hands pressed together at the breast, fingers up
    for side in (-1, 1):
        _ellipsoid(bm, (side * 0.035, 0.46, 2.68), (0.04, 0.075, 0.15), tilt_x=-14, segments=14, rings=10)
    # the sleeves: wide cloth falling from the forearms
    for side in (-1, 1):
        _ellipsoid(bm, (side * 0.32, 0.27, 2.26), (0.12, 0.1, 0.32), tilt_x=12, segments=18, rings=12)


def _feather(bm, root, direction, across, length, width, curl, thick):
    """One feather into `bm`: a blade from `root` along `direction`, narrow at the quill, broad through the middle and
    rounded at the tip, curved by `curl` and given thickness."""
    normal = direction.cross(across).normalized()
    rows, cols = 8, 3
    top, bottom = [], []
    for i in range(rows):
        t = i / (rows - 1)
        if t < 0.45:
            half = width * 0.5 * (0.3 + 0.7 * t / 0.45)
        else:
            q = (t - 0.45) / 0.55
            half = width * 0.5 * math.sqrt(max(0.0, 1 - q * q * 0.96))
        centre = root + direction * (length * t) - normal * (curl * t * t)
        rt, rb = [], []
        for j in range(cols):
            sv = -1 + 2 * j / (cols - 1)
            p = centre + across * (half * sv) + normal * (0.06 * width * (1 - sv * sv))
            rt.append(bm.verts.new(p + normal * thick * 0.5))
            rb.append(bm.verts.new(p - normal * thick * 0.5))
        top.append(rt)
        bottom.append(rb)
    for i in range(rows - 1):
        for j in range(cols - 1):
            bm.faces.new((top[i][j], top[i][j + 1], top[i + 1][j + 1], top[i + 1][j]))
            bm.faces.new((bottom[i][j], bottom[i + 1][j], bottom[i + 1][j + 1], bottom[i][j + 1]))
    ring_t = ([top[i][0] for i in range(rows)] + [top[rows - 1][j] for j in range(1, cols)]
              + [top[i][cols - 1] for i in range(rows - 2, -1, -1)] + [top[0][j] for j in range(cols - 2, 0, -1)])
    ring_b = ([bottom[i][0] for i in range(rows)] + [bottom[rows - 1][j] for j in range(1, cols)]
              + [bottom[i][cols - 1] for i in range(rows - 2, -1, -1)] + [bottom[0][j] for j in range(cols - 2, 0, -1)])
    n = len(ring_t)
    for k in range(n):
        try:
            bm.faces.new((ring_t[k], ring_b[k], ring_b[(k + 1) % n], ring_t[(k + 1) % n]))
        except ValueError:
            pass


def _tube(bm, points, radii, sides=10):
    """A smooth tube through `points` (Vectors) with a radius at each, capped at both ends."""
    rings = []
    for i, p in enumerate(points):
        a = points[max(0, i - 1)]
        b = points[min(len(points) - 1, i + 1)]
        t = (b - a).normalized()
        n = t.cross(Vector((0, 0, 1)))
        if n.length < 1e-4:
            n = t.cross(Vector((1, 0, 0)))
        n.normalize()
        bnorm = t.cross(n).normalized()
        ring = []
        for k in range(sides):
            ang = math.tau * k / sides
            ring.append(bm.verts.new(p + (n * math.cos(ang) + bnorm * math.sin(ang)) * radii[i]))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def _wings():
    bm = bmesh.new()
    for side in (-1, 1):
        # the leading edge: from the shoulder blade up, out and back to a high tip (raised wings, as in the picture)
        def edge(u):
            return Vector((side * (0.22 + 1.25 * u - 0.25 * u * u), -0.32 - 0.55 * u, 2.95 + 2.6 * u - 0.55 * u * u))

        # (no bone drawn: the coverts along the leading edge are the wing's edge, as on a real wing; a tube there read
        # as a pole)
        rows = ((14, 1.55, 0.5, 0.0), (16, 1.0, 0.46, 0.04), (18, 0.55, 0.4, 0.08), (20, 0.32, 0.3, 0.1))
        for layer, (count, length, width, lift) in enumerate(rows):
            for k in range(count):
                u = 0.03 + 0.97 * k / (count - 1)
                root = edge(u * (1 - 0.05 * layer)) + Vector((0, -0.04 * layer, -0.02 * layer))
                # the feathers hang down and back at the root, sweep out and up toward the tip
                ang = math.radians(-100 + 95 * u ** 1.3)
                d = Vector((side * (math.cos(ang) * 0.85 + 0.2), -0.28 - 0.1 * u, math.sin(ang))).normalized()
                tangent = (edge(min(1, u + 0.02)) - edge(max(0, u - 0.02))).normalized()
                across = d.cross(tangent).cross(d).normalized()
                reach = length * (0.7 + 0.55 * math.sin(math.pi * min(1.0, u * 1.08)))
                _feather(bm, root, d, across, reach, width * (1 - 0.15 * u), curl=0.12 + lift, thick=0.035)
    me = bpy.data.meshes.new("AngelWings")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("AngelWings", me)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _evaluated_mesh(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    return me


def build_mesh():
    """The statue as (verts, faces, normals) in Blender's axes, triangulated, reduced to TARGET_TRIS."""
    bm_body = bmesh.new()
    _robe(bm_body)
    _head_and_hands(bm_body)
    body_me = bpy.data.meshes.new("AngelRobe")
    bm_body.to_mesh(body_me)
    bm_body.free()
    body = bpy.data.objects.new("AngelRobe", body_me)
    bpy.context.scene.collection.objects.link(body)
    figure = _skin_figure()
    wings = _wings()
    wsub = wings.modifiers.new("Sub", "SUBSURF")
    wsub.levels = 1
    bm = bmesh.new()
    for obj in (body, figure, wings):
        me = _evaluated_mesh(obj)
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("AngelAll")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("AngelAll", me)
    bpy.context.scene.collection.objects.link(obj)
    tris = len(me.polygons)
    if tris > TARGET_TRIS:
        dec = obj.modifiers.new("Dec", "DECIMATE")
        dec.ratio = TARGET_TRIS / tris
        me = _evaluated_mesh(obj)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.normal_update()
    bm.verts.index_update()
    verts = [tuple(v.co) for v in bm.verts]
    faces = [tuple(v.index for v in f.verts) for f in bm.faces]
    normals = [tuple(v.normal) for v in bm.verts]
    bm.free()
    for o in (body, figure, wings, obj):
        bpy.data.objects.remove(o, do_unlink=True)
    return verts, faces, normals


def place(s, mat, at, facing_deg=0.0, scale=1.0):
    """The statue into scene `s` (Roblox axes: `at` = where her feet stand, she faces +Z turned `facing_deg` about up)."""
    verts, faces, normals = build_mesh()
    a = math.radians(facing_deg)
    ca, sa = math.cos(a), math.sin(a)

    def to_roblox(v):
        # Blender (x, y, z) facing +Y -> Roblox (x, y up, z) facing +Z: x -> -x, z -> y, y -> z (a proper turn)
        x, y, z = -v[0] * scale, v[2] * scale, v[1] * scale
        return (at[0] + x * ca + z * sa, at[1] + y, at[2] - x * sa + z * ca)

    def dir_roblox(n):
        x, y, z = -n[0], n[2], n[1]
        return (x * ca + z * sa, y, -x * sa + z * ca)

    rv = [to_roblox(v) for v in verts]
    rn = [dir_roblox(n) for n in normals]
    # stone UVs: projected along each face's main axis, in studs
    uvs = []
    for f in faces:
        p = [rv[i] for i in f]
        e1 = [p[1][k] - p[0][k] for k in range(3)]
        e2 = [p[2][k] - p[0][k] for k in range(3)]
        n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
        ax = max(range(3), key=lambda k: abs(n[k]))
        u_k, v_k = [(1, 2), (0, 2), (0, 1)][ax]
        uvs.append([(q[u_k], q[v_k]) for q in p])
    # (the mirror in to_roblox keeps the turn proper: winding stays counter-clockwise from the front)
    s.mesh(mat, rv, faces, uvs, normals=rn)
    return len(faces)
