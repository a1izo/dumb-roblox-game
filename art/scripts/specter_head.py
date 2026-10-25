"""The Deathsinger's head (props_specter), sculpted in code to the Ryuk-like pictures (2026-10-25): a pale blue face,
long, with high cheekbones, hollow cheeks and a hard jaw down to a long chin; round staring eyes, yellow with red
irises, in dark rims under a furrowed brow; a wide open grin (a straight upper lip over a deep U, its corners drawn up
toward the ears) with sharp teeth rooted in its gums; pinched slit nostrils; rounded ears (a hoop and a heart on the
left one); and a tall flame of stiff blue spikes standing up off the crown.

Built twice from the same functions: the game mesh, and a high-detail copy (finer, with wrinkles and pores) for its
maps to be baked from (build_props._high_of, "dg_high"). Everything here is in the unit head's space: x across (its
left on +x), y depth (it faces -y), z up, the head about 2 across; props_specter scales and places it."""

import math
import random

import bmesh
import bpy
from mathutils import Vector

import modelkit as mk
import propkit as pk

# The face's features, on the front of the unit head (x across, z up).
EYE_X, EYE_Z = 0.33, 0.12
EYE_RX, EYE_RZ = 0.2, 0.2  # the socket's half-width and half-height (round: the close-up of 2026-10-25)
EYE_TILT = math.radians(4)  # its outer corner up
MOUTH_W = 0.8  # the grin's half-width: its corners drawn up toward the ears
MOUTH_OPEN = MOUTH_W  # (open all the way along: asked 2026-10-25, "dont just give him a line for the grin")
NOSE_Z = -0.2


def upper_edge(x):
    """The upper lip's edge (the close-up of 2026-10-25): nearly straight across under the snout, lifting only toward
    the corners."""
    u = min(1.0, abs(x) / MOUTH_W)
    return -0.46 + 0.16 * u ** 2.6


def lower_edge(x):
    """The lower lip's edge: a deep U, the mouth wide open in the middle, rising hard to meet the upper at the
    corners."""
    u = min(1.0, abs(x) / MOUTH_W)
    return -0.74 + 0.43 * u ** 2.0


def mouth_z(x):
    """The middle of the grin at x."""
    return (upper_edge(x) + lower_edge(x)) / 2


def gape(x):
    """Half the mouth's opening at x (closed only at its corners)."""
    return max(0.006, (upper_edge(x) - lower_edge(x)) / 2)


def smoothstep(a, b, t):
    t = max(0.0, min(1.0, (t - a) / (b - a)))
    return t * t * (3 - 2 * t)


def _band(px, pz, path, width):
    """1 on a line drawn over the face (a list of (x, z)), falling to 0 a `width` away."""
    best = 9.0
    for k in range(len(path) - 1):
        (x0, z0), (x1, z1) = path[k], path[k + 1]
        dx, dz = x1 - x0, z1 - z0
        t = max(0.0, min(1.0, ((px - x0) * dx + (pz - z0) * dz) / (dx * dx + dz * dz)))
        best = min(best, math.hypot(px - (x0 + dx * t), pz - (z0 + dz * t)))
    return max(0.0, 1.0 - best / width)


def _socket(px, pz, sx):
    """How deep inside an eye's socket (0 outside, 1 at its middle), in the socket's tilted ellipse."""
    dx, dz = px - sx * EYE_X, pz - EYE_Z
    c, s = math.cos(EYE_TILT * sx), math.sin(EYE_TILT * sx)
    u, v = dx * c + dz * s, -dx * s + dz * c
    return math.hypot(u / EYE_RX, v / EYE_RZ)


def shape(v):
    """The unit sphere drawn into the head: a skull rounder behind, cheeks wide, the lower face drawn forward into a
    muzzle and narrowed to a small pointed chin."""
    x, y, z = v
    # the outline from the front: widest across the cheekbones, then the jaw cut in straight to a long narrow chin
    width = 0.86 + 0.1 * math.exp(-((z + 0.05) / 0.4) ** 2) - 0.46 * smoothstep(-0.3, -1.0, z) ** 0.85
    x *= width
    z *= 1.08 if z > 0 else 1.34  # (a long lower face)
    if y > 0:
        y *= 1.08 - 0.55 * smoothstep(-0.1, -1.2, z)  # (the skull's back, the jaw's narrower)
    else:
        y *= 0.9
        # the mouth's round drawn a little forward, most in the middle
        m = smoothstep(0.0, -0.45, z) * (1 - smoothstep(-0.95, -1.3, z))
        across = max(0.0, 1 - (x / 0.8) ** 2) ** 1.2
        y -= 0.26 * m * across
    if z < -1.2:
        z = -1.2 + (z + 1.2) * 0.55  # (the jaw's underside, flatter)
    return Vector((x, y, z))


def surface(x, z):
    """The shaped head's front at (x, z), before the sculpting: found by stepping the sphere's point."""
    # (shape() keeps a point's sign and widens x by a factor of z: invert it by a few steps)
    gx, gz = x / 0.9, z / 1.08
    for _ in range(6):
        gy = -math.sqrt(max(0.0, 1 - gx * gx - gz * gz))
        p = shape(Vector((gx, gy, gz)))
        gx += (x - p.x) * 0.9
        gz += (z - p.z) / (1.08 if p.z > 0 else 1.34)
        gx = max(-0.999, min(0.999, gx))
        gz = max(-0.999, min(0.999, gz))
    gy = -math.sqrt(max(0.0, 1 - gx * gx - gz * gz))
    return shape(Vector((gx, gy, gz)))


# Creases drawn on the face: (path, width, depth), all in (x, z).
def _creases(fine):
    lines = []
    for k in range(3 if fine else 0):  # across the forehead, bowed down into the scowl (under the hair's fringe)
        z = 0.5 + k * 0.1
        lines.append(([(-0.46, z + 0.07), (-0.16, z - 0.02), (0.0, z - 0.05), (0.16, z - 0.02), (0.46, z + 0.07)],
                      0.022, 0.016))
    for sx in (-1, 1):
        lines.append(([(sx * 0.05, 0.2), (sx * 0.06, 0.34)], 0.02, 0.022))  # the frown between the brows
        lines.append(([(sx * 0.12, -0.25), (sx * 0.3, -0.33), (sx * 0.55, -0.32), (sx * 0.8, -0.22)], 0.04, 0.04))
        lines.append(([(sx * 0.18, -0.13), (sx * 0.33, -0.11), (sx * 0.5, -0.05)], 0.022, 0.018))  # under the eye
        for k in range(3):  # crow's feet
            a = math.radians(-20 + k * 22)
            o = (sx * 0.58, 0.1)
            lines.append(([o, (o[0] + sx * 0.14 * math.cos(a), o[1] + 0.14 * math.sin(a))], 0.016, 0.014))
    if fine:
        rng = random.Random(7)
        for _ in range(40):  # small creases over the cheeks and the muzzle
            x = rng.uniform(-0.7, 0.7)
            z = rng.uniform(-0.75, 0.0)
            a = rng.uniform(-0.6, 0.6)
            ln = rng.uniform(0.04, 0.1)
            lines.append(([(x, z), (x + ln * math.cos(a), z + ln * math.sin(a))], 0.008, 0.006))
    return lines


def sculpt(u_segments, v_segments, fine=False):
    """The head's shell as a bmesh, with the per-point "dg_shade" (the grey round the eyes and in the folds) and
    "dg_lip" (the dark of the lips) attributes. fine: the high-detail copy's extra creases and pores."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u_segments, v_segments=v_segments, radius=1.0)
    # (the face twice as fine as the rest: the back of the skull is under the hair)
    front = [f for f in bm.faces if f.calc_center_median().y < -0.25 and -0.98 < f.calc_center_median().z < 0.62]
    edges = {e for f in front for e in f.edges}
    bmesh.ops.subdivide_edges(bm, edges=list(edges), cuts=1, use_grid_fill=True)
    # (and the mouth's round twice as fine again: the grin's edge would step)
    mouth = [f for f in bm.faces if f.calc_center_median().y < -0.3 and abs(f.calc_center_median().x) < 0.8
             and -0.6 < f.calc_center_median().z < -0.18]
    edges = {e for f in mouth for e in f.edges}
    bmesh.ops.subdivide_edges(bm, edges=list(edges), cuts=1, use_grid_fill=True)
    for vert in bm.verts:
        vert.co = vert.co.normalized()
    for vert in bm.verts:
        vert.co = shape(vert.co)
    bm.normal_update()
    shade = bm.verts.layers.float.new("dg_shade")
    lip = bm.verts.layers.float.new("dg_lip")
    creases = _creases(fine)
    nose = surface(0.0, NOSE_Z)
    brow_line = [(-0.66, 0.4), (-0.36, 0.33), (-0.14, 0.2), (0.0, 0.13), (0.14, 0.2), (0.36, 0.33), (0.66, 0.4)]
    xs = [-MOUTH_W + k * 2 * MOUTH_W / 40 for k in range(41)]
    upper = [(x, mouth_z(x) + gape(x)) for x in xs]
    lower = [(x, mouth_z(x) - gape(x)) for x in xs]
    pore = bpy.data.textures.get("SpecterPores") or bpy.data.textures.new("SpecterPores", "VORONOI")
    pore.noise_scale = 0.035
    # (each crease's box, so a point far from it skips it)
    boxes = []
    for path, width, depth in creases:
        xs_, zs_ = [q[0] for q in path], [q[1] for q in path]
        boxes.append((min(xs_) - width, max(xs_) + width, min(zs_) - width, max(zs_) + width, path, width, depth))
    for vert in bm.verts:
        p, n = vert.co.copy(), vert.normal.copy()
        if p.y > 0.05:
            vert[shade] = 0.0
            vert[lip] = 0.0
            continue
        front = smoothstep(0.05, -0.25, p.y)
        x, z = p.x, p.z
        out = 0.0
        # the brow ridge: a heavy ridge along the scowl, out over the sockets, falling steep into them
        out += 0.1 * _band(x, z, brow_line, 0.13) ** 1.3
        # the sockets, deep and round, rimmed; the cheekbones under them
        grey = 0.0
        for sx in (-1, 1):
            d = _socket(x, z, sx)
            if d < 1.0:
                out -= 0.13 * (1 - d * d) ** 0.8
            elif d < 1.35:
                out += 0.025 * math.sin((d - 1.0) / 0.35 * math.pi)  # (the rim)
            grey = max(grey, 1 - smoothstep(0.9, 1.6, d))
            # the cheekbones, high and hard under the eyes; the cheeks hollow under them, down to the jaw
            c = math.hypot((x - sx * 0.58) / 1.2, z + 0.16)
            out += 0.09 * max(0.0, 1 - c / 0.2) ** 1.3
            h = math.hypot((x - sx * 0.5) / 1.1, (z + 0.6) / 1.3)
            out -= 0.06 * max(0.0, 1 - h / 0.26) ** 1.4
            # the jaw: a hard ridge from under the ear down and in to the chin, cut away under it
            jaw = [(sx * 0.82, -0.42), (sx * 0.66, -0.9), (sx * 0.38, -1.18), (sx * 0.12, -1.27)]
            out += 0.055 * _band(x, z, jaw, 0.1) ** 1.6
        # the snout over the mouth, pinched to a ridge between the nostrils
        sn = math.hypot(x / 0.18, (z - nose.z) / 0.13)
        out += 0.06 * max(0.0, 1 - sn) ** 1.2
        out += 0.03 * _band(x, z, [(0.0, 0.14), (0.0, NOSE_Z)], 0.07)  # (the bridge)
        # the lips: drawn thin and tight round the open box, then only a dark line along the slit to the ears
        lip_k = 0.0
        if abs(x) < MOUTH_W + 0.05:
            in_box = abs(x) < MOUTH_OPEN + 0.04
            full = 0.03 if in_box else 0.016
            for row, sign in ((upper, 1), (lower, -1)):
                b = _band(x, z, row, full * 2.0)
                if b > 0:
                    out += (0.035 if in_box else 0.0) * b ** 1.5
                    lip_k = max(lip_k, smoothstep(0.3, 0.6, b))
        # the chin: long and squared off under the lower lip
        out += 0.05 * max(0.0, 1 - math.hypot(x / 0.32, (z + 1.12) / 0.16)) ** 0.6
        crease_k = 0.0
        for x0, x1, z0, z1, path, width, depth in boxes:
            if x < x0 or x > x1 or z < z0 or z > z1:
                continue
            b = _band(x, z, path, width)
            if b > 0:
                out -= depth * b * b
                crease_k = max(crease_k, b * 0.7)
        if fine:
            # pores and the skin's fine grain (the high copy only)
            out -= 0.004 * pore.evaluate(p * 1.0)[3] if hasattr(pore, "evaluate") else 0.0
        vert.co = p + n * out * front
        vert[shade] = max(grey * 0.95, crease_k) * front
        vert[lip] = lip_k * front
    for f in bm.faces:
        f.smooth = True
    return bm


def carve(obj, void, gums):
    """The cuts into the shell: the sockets' hollows (for the eyes to sit in), the nostrils and the open mouth, its
    walls the dark of the mouth."""
    cutters = []
    for sx in (-1, 1):
        e = surface(sx * EYE_X, EYE_Z)
        cut = mk.sphere("SocketCut", 1.0, (e.x, e.y + 0.13, e.z), scale=(EYE_RX * 0.86, 0.2, EYE_RZ * 0.86), mat=void,
                        segments=32, rings=18)
        cut.rotation_euler = (0, -EYE_TILT * sx, 0)
        cutters.append(cut)
        n = surface(sx * 0.07, NOSE_Z - 0.03)
        cut = mk.sphere("NostrilCut", 1.0, (n.x, n.y - 0.06, n.z), scale=(0.022, 0.12, 0.05), mat=void, segments=12,
                        rings=8)
        cut.rotation_euler = (0, -sx * math.radians(25), 0)
        cutters.append(cut)
    bmc = bmesh.new()
    xs = [-MOUTH_OPEN * 0.995 + k * 2 * MOUTH_OPEN * 0.995 / 60 for k in range(61)]
    outline = [(x, mouth_z(x) + gape(x) * 0.85) for x in xs] + [(x, mouth_z(x) - gape(x) * 0.85) for x in reversed(xs)]
    front = [bmc.verts.new((x, -1.9, z)) for x, z in outline]
    back = [bmc.verts.new((x * 0.78, -0.25, z)) for x, z in outline]
    bmc.faces.new(front)
    bmc.faces.new(list(reversed(back)))
    for k in range(len(outline)):
        a, b = front[k], front[(k + 1) % len(outline)]
        c, d = back[(k + 1) % len(outline)], back[k]
        bmc.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(bmc, faces=bmc.faces)
    cutters.append(mk._obj_from_bm("MouthCut", bmc, void))  # (the mouth dark inside, behind the teeth)
    for cutter in cutters:
        mod = obj.modifiers.new(cutter.name, "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.material_mode = "TRANSFER"
        mod.object = cutter
    depsgraph = bpy.context.evaluated_depsgraph_get()
    carved = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    old = obj.data
    obj.data = carved
    bpy.data.meshes.remove(old)
    for poly in carved.polygons:
        poly.use_smooth = True
    for cutter in cutters:
        bpy.data.objects.remove(cutter, do_unlink=True)
    return obj


def paint(mat, attribute, rgb, strength=1.0):
    """Mixes `mat`'s colour toward `rgb` by the mesh's per-point `attribute` (0..1)."""
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    socket = bsdf.inputs["Base Color"]
    source = socket.links[0].from_socket if socket.links else None
    read = nodes.new("ShaderNodeAttribute")
    read.attribute_name = attribute
    scale = nodes.new("ShaderNodeMath")
    scale.operation = "MULTIPLY"
    scale.use_clamp = True
    scale.inputs[1].default_value = strength
    links.new(read.outputs["Fac"], scale.inputs[0])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    links.new(scale.outputs[0], mix.inputs[0])
    if source is not None:
        links.new(source, mix.inputs[6])
    else:
        mix.inputs[6].default_value = socket.default_value
    mix.inputs[7].default_value = (*rgb, 1.0)
    links.new(mix.outputs[2], socket)
    return mat


def shell(name, mats, fine):
    """The carved shell, painted (its grey and its lips)."""
    bm = sculpt(176, 120, fine=True) if fine else sculpt(60, 40)
    obj = mk._obj_from_bm(name, bm, mats["face"])
    obj.data.materials.append(mats["void"])
    obj.data.materials.append(mats["gums"])
    return carve(obj, mats["void"], mats["gums"])


def inward(p):
    """From a point on the face toward the head's middle at its height."""
    return (Vector((0.0, 0.1, p.z * 0.6)) - p).normalized()


def loft(name, centres, across, up, widths, depths, mat, sides=12, dish=0.0):
    """A lofted blade along `centres`: at each, an ellipse `widths[k]` along `across[k]` and `depths[k]` along `up`
    crossed with it; dish hollows its front (-y side) by that share of its depth (an ear's bowl). Capped at the
    root, closed to a point at the tip when the last width is 0."""
    bm = bmesh.new()
    rings = []
    for k, c in enumerate(centres):
        a, n = across[k].normalized(), up[k].normalized()
        ring = []
        for i in range(sides):
            t = math.tau * i / sides
            ca, sa = math.cos(t), math.sin(t)
            off = a * (widths[k] * ca) + n * (depths[k] * sa)
            if dish and sa < 0:
                off += n * (depths[k] * dish * (1 - ca * ca) * -sa)
            ring.append(bm.verts.new(c + off))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mk._obj_from_bm(name, bm, mat)
    return mk.smooth(obj)


def strands(name, path, width, flat, mat, sides, grooves=0, groove=0.0, tip_attr=None, up=None):
    """A stiff lock along `path` (points), `width` at its root narrowing to a point, flattened to `flat` of its width
    across `up` (a lock, not a cone); grooves: that many strands' furrows round it, `groove` deep (a share of the
    width; the high-detail copy's). tip_attr: a per-point attribute running 0 at the root to 1 at the tip (its
    colour lightening toward the tip)."""
    bm = bmesh.new()
    tip_layer = bm.verts.layers.float.new(tip_attr) if tip_attr else None
    rings = []
    n = len(path)
    up = up or Vector((0, 0, 1))
    for k, c in enumerate(path):
        t = k / (n - 1)
        d = (path[min(k + 1, n - 1)] - path[max(k - 1, 0)]).normalized()
        a = d.cross(up)
        if a.length < 1e-4:
            a = d.cross(Vector((1, 0, 0)))
        a.normalize()
        b = a.cross(d).normalized()
        r = width * (1 - t) ** 0.85 + 0.002
        ring = []
        for i in range(sides):
            th = math.tau * i / sides
            f = 1.0 - (groove * (0.5 + 0.5 * math.cos(th * grooves)) if grooves else 0.0)
            v = bm.verts.new(c + a * (math.cos(th) * r * f) + b * (math.sin(th) * r * flat * f))
            if tip_layer is not None:
                v[tip_layer] = t
            ring.append(v)
        rings.append(ring)
    for k in range(n - 1):
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    soft = bm.faces.layers.int.new("dg_soft")  # (smooth whatever its few sides' angles: modelkit.auto_smooth)
    for f in bm.faces:
        f[soft] = 1
    return mk.smooth(mk._obj_from_bm(name, bm, mat))


def ruff(name, centre, major, minor, tilt_deg, mat, cols, rows, fine=False, seed=3):
    """A ruff of fur sculpted as one ring round the neck: lumpy clumps all round it, its outer edge hanging in
    scalloped tufts down over the shoulders, and (fine) furrows of strands running out over it from the neck."""
    rng = random.Random(seed)
    phases = [(rng.uniform(5, 9), rng.uniform(0, math.tau)) for _ in range(3)]
    tufts = 34
    bm = bmesh.new()
    tip = bm.verts.layers.float.new("dg_tip")
    tilt = math.radians(tilt_deg)
    grid = []
    for i in range(cols):
        th = math.tau * i / cols
        row = []
        for j in range(rows):
            ph = math.tau * j / rows  # 0 outside, pi/2 on top, pi inside, 3pi/2 underneath
            lump = sum(0.5 + 0.5 * math.cos(th * f + p + ph * 1.3) for f, p in phases) / 3
            outer = max(0.0, math.cos(ph)) * max(0.0, -math.sin(ph) + 0.4)  # (round the outer, lower edge)
            scallop = max(0.0, math.cos(th * tufts + math.sin(th * 3) * 0.8)) ** 3
            r = minor * (1.0 + 0.35 * lump + 0.9 * outer * scallop + 0.25 * outer)
            if fine:
                r *= 1.0 - 0.03 * (0.5 + 0.5 * math.cos(th * 260 + ph * 2.0))  # (the strands, out from the neck)
            # the ring's section: wider than tall, its outer side drooping down over the shoulders
            sx, sz = math.cos(ph) * r * 1.25, math.sin(ph) * r * 0.85 - 0.12 * outer * minor * 4
            p = Vector((math.cos(th) * (major + sx), math.sin(th) * (major + sx) * 0.9, sz))
            p = Vector((p.x, p.y * math.cos(tilt) - p.z * math.sin(tilt), p.y * math.sin(tilt) + p.z * math.cos(tilt)))
            v = bm.verts.new(centre + p)
            v[tip] = max(0.0, math.cos(ph)) * 0.9
            row.append(v)
        grid.append(row)
    for i in range(cols):
        a = (i + 1) % cols
        for j in range(rows):
            b = (j + 1) % rows
            bm.faces.new((grid[i][j], grid[a][j], grid[a][b], grid[i][b]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    return mk._obj_from_bm(name, bm, mat)


def soften(obj):
    """Marks every face of obj "dg_soft" (smooth however few its sides: modelkit.auto_smooth)."""
    attr = obj.data.attributes.get("dg_soft") or obj.data.attributes.new("dg_soft", "INT", "FACE")
    attr.data.foreach_set("value", [1] * len(obj.data.polygons))
    return obj


def scalp(z_front=0.48):
    """Is the head's point (x, y, z) under the hair? Above a hairline high over the brow and low behind."""
    def under(p):
        if p.y < 0:
            line = z_front - 0.22 * min(1.0, abs(p.x) / 0.8)
        else:
            k = min(1.0, p.y / 0.6)
            line = (z_front - 0.22) * (1 - k) - 0.3 * k
        return p.z > line
    return under


def hair(mats, high_mats=None, rng=None):
    """The hair: a cap hugging the skull above the hairline, and a crest of stiff spiked locks thrown up off it and
    swept back, the tallest along the middle, the side ones leaning out, short ones over the brow. Each lock gets a
    high-detail twin with its strands grooved in ("dg_high"). Returns the parts."""
    rng = rng or random.Random(57)
    parts = []

    def hairline(th):
        """How high the hairline runs (an angle of elevation) at the azimuth th (0 in front): high over the brow,
        over the ears at the sides, down to the nape behind."""
        c = math.cos(th)
        return 0.44 * (1 + c) / 2 - 0.62 * (1 - c) / 2 + 0.3 * math.sin(th) ** 2

    def on_skull(th, e, out=1.0):
        return shape(Vector((math.cos(e) * math.sin(th), -math.cos(e) * math.cos(th), math.sin(e)))) * out

    # the cap: rows from the hairline up to the crown, a little out from the skull and fuller over the top; its twin
    # furrowed from the hairline up, the strands combed back into the crest
    def cap(name, cols, rows, furrows, mat):
        bm = bmesh.new()
        tip = bm.verts.layers.float.new("dg_tip")
        grid = []
        for r in range(rows):
            row = []
            for c in range(cols):
                th = math.tau * c / cols
                e0 = hairline(th)
                e = e0 + (math.pi / 2 - e0) * (r / rows)
                fur = 1.0 - (0.012 * (0.5 + 0.5 * math.cos(th * furrows)) if furrows else 0.0)
                v = bm.verts.new(on_skull(th, e, (1.03 + 0.05 * math.sin(math.pi * r / rows)) * fur))
                v[tip] = 0.15 * r / rows
                row.append(v)
            grid.append(row)
        crown = bm.verts.new(shape(Vector((0, 0, 1))) * 1.06)
        crown[tip] = 0.15
        for r in range(rows - 1):
            for c in range(cols):
                d = (c + 1) % cols
                bm.faces.new((grid[r][c], grid[r][d], grid[r + 1][d], grid[r + 1][c]))
        for c in range(cols):
            bm.faces.new((grid[-1][c], grid[-1][(c + 1) % cols], crown))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.05)
        for f in bm.faces:
            f.smooth = True
        return mk._obj_from_bm(name, bm, mat)

    low_cap = cap("HairCap", 56, 14, 0, mats["hair"])
    low_cap["dg_high"] = cap("HairCapHigh", 448, 40, 150, (high_mats or mats)["hair"]).name
    parts.append(low_cap)
    # flat locks lying over the cap, combed up from the hairline toward the crest
    for k in range(30):
        th = math.tau * k / 30 + rng.uniform(-0.08, 0.08)
        e0 = hairline(th) + 0.05
        root = on_skull(th, e0, 1.06)
        mid = on_skull(th + rng.uniform(-0.1, 0.1), e0 + (math.pi / 2 - e0) * 0.45, 1.1)
        end = on_skull(th + rng.uniform(-0.15, 0.15), e0 + (math.pi / 2 - e0) * rng.uniform(0.6, 0.85), 1.16)
        path = [root, root.lerp(mid, 0.5) * 1.01, mid, mid.lerp(end, 0.5) * 1.01, end]
        nrm = root.normalized()
        width = rng.uniform(0.16, 0.22)
        low = strands("HairLie", path, width, 0.3, mats["hair"], 6, tip_attr="dg_tip", up=nrm)
        hi = strands("HairLieHigh", path, width, 0.3, (high_mats or mats)["hair"], 24, grooves=5, groove=0.12,
                     tip_attr="dg_tip", up=nrm)
        low["dg_high"] = hi.name
        parts.append(low)
    # the locks (the full-length picture of 2026-10-25): a tall narrow flame of thin stiff spikes standing up off the
    # crown, the middle ones the tallest and straightest, the outer ones leaning out and back a little; (azimuth,
    # elevation, lean, length, root width)
    locks = []
    for k in range(34):
        th = math.tau * rng.random()
        e = rng.uniform(0.95, 1.5)
        inner = (e - 0.95) / 0.55  # (1 at the crown's top: tall and straight up)
        out = Vector((math.sin(th), -math.cos(th), 0.0)) * (0.8 * (1 - inner) ** 1.2 + 0.05)
        lean = out + Vector((rng.uniform(-0.15, 0.15), 0.1 + rng.uniform(-0.05, 0.12), 1.0))
        length = (0.55 + 1.45 * inner ** 1.3) * rng.uniform(0.82, 1.15)  # (a flame: tallest in the middle)
        locks.append((th, e, lean, length, rng.uniform(0.13, 0.21) * (1.1 - 0.2 * inner)))
    for k in range(7):  # short spikes over the brow, standing up out of the hairline
        th = (k - 3) * 0.2 + rng.uniform(-0.04, 0.04)
        locks.append((th, 0.62, Vector((math.sin(th) * 0.3, -0.25, 1.0)), rng.uniform(0.45, 0.7), rng.uniform(0.12, 0.15)))
    for th, e, lean, length, width in locks:
        root = on_skull(th, e, 1.0)
        lean = lean.normalized()
        bend = Vector((rng.uniform(-0.12, 0.12), 0.18, 0.0))  # (only a little curl back near the tips)
        path = [root]
        for seg in range(1, 7):
            s = seg / 6
            way = (lean + bend * (s * s)).normalized()
            path.append(path[-1] + way * length / 6)
        up = Vector((rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 1.0)).normalized()  # (each turned its own way)
        low = strands("HairLock", path, width, 0.45, mats["hair"], 7, tip_attr="dg_tip", up=up)
        hi = strands("HairLockHigh", path, width, 0.45, (high_mats or mats)["hair"], 28, grooves=5, groove=0.12,
                     tip_attr="dg_tip", up=up)
        low["dg_high"] = hi.name
        parts.append(low)
    return parts


def features(mats, glow, rng=None, iris=None):
    """What sits on the shell: the eyes (round and bulging out of their dark rims, the close-up of 2026-10-25:
    yellow, `glow`, round red irises, `iris`, and small black pupils), the fangs, the ears and the earring. Returns
    (parts, glows)."""
    rng = rng or random.Random(31)
    parts, glows = [], []
    for sx in (-1, 1):
        e = surface(sx * EYE_X, EYE_Z)
        look = -inward(e)  # (out of the face)
        at = e + inward(e) * 0.12
        eye = mk.sphere("Eye", 1.0, tuple(at), scale=(EYE_RX * 0.9, EYE_RX * 0.9, EYE_RZ * 0.9), mat=glow,
                        segments=28, rings=18)
        glows.append(eye)
        front = at + look * (EYE_RX * 0.86)  # (the eyeball's front, a little out of the socket)
        ring = mk.sphere("Iris", 1.0, tuple(front - look * 0.012), mat=iris or glow, segments=20, rings=12)
        ring.rotation_mode = "QUATERNION"
        ring.rotation_quaternion = look.to_track_quat("Y", "Z")
        ring.scale = (0.1, 0.025, 0.1)
        glows.append(ring)
        pupil = mk.sphere("Pupil", 1.0, tuple(front + look * 0.012), mat=mats["void"], segments=14, rings=10)
        pupil.rotation_mode = "QUATERNION"
        pupil.rotation_quaternion = look.to_track_quat("Y", "Z")
        pupil.scale = (0.036, 0.012, 0.036)
        parts.append(pupil)
        lid = mk.torus("Lid", 1.0, 0.1, tuple(at + look * (EYE_RX * 0.45)), mat=mats["lips"], major_segments=36,
                       minor_segments=8)
        lid.rotation_mode = "QUATERNION"
        lid.rotation_quaternion = look.to_track_quat("Z", "Y")
        lid.scale = (EYE_RX * 0.88, EYE_RZ * 0.88, 0.35)
        parts.append(lid)
    # The teeth: sharp, crowded along the grin's top and bottom edges all the way to its corners, each rooted in a strip
    # of gum just inside the lip (none floats), the uppers the bigger, pointing down between the lowers; none reaches
    # past the middle of the opening.
    for row, down in ((1, -1), (-1, 1)):
        def edge(x):
            return mouth_z(x) + row * gape(x) * 0.85

        gum = []
        for k in range(21):
            x = -MOUTH_W * 0.95 + k * 2 * MOUTH_W * 0.95 / 20
            p = surface(x, edge(x) + row * 0.014)
            gum.append(p + inward(p) * 0.065)
        parts.append(soften(mk.smooth(pk.sweep("Gum", gum, 0.04, mats["gums"], sides=8))))
        count = 15 if row > 0 else 14
        for k in range(count):
            t = (k + (0.5 if row < 0 else 0.0)) / 14
            x = -MOUTH_W * 0.86 + t * 2 * MOUTH_W * 0.86
            p = surface(x, edge(x) + row * 0.012)
            root = p + inward(p) * 0.06
            reach = gape(x) * 0.85 + 0.03  # (from the lip's edge to the opening's middle)
            length = min(reach, rng.uniform(0.1, 0.13) if row > 0 else rng.uniform(0.08, 0.1))
            # (pointing into the opening: across the edge's own slope near the corners)
            slope = (edge(x + 0.01) - edge(x - 0.01)) / 0.02
            way = Vector((-0.6 * slope * down, 0.0, down)).normalized()
            tip = root + way * length - inward(p) * 0.035
            tooth = mk.tube("Tooth", root, tip, rng.uniform(0.032, 0.04), 0.003, mat=mats["tooth"], verts=6)
            tooth.scale = (1.0, 0.6, 1.0)
            parts.append(soften(tooth))
    # The ears: rounded, set flat to the head's sides a little back, a hollow toward the front (no long elf's points).
    for sx in (-1, 1):
        root = Vector((sx * 0.88, 0.14, 0.04))
        tip = Vector((sx * 1.16, 0.3, 0.1))
        face_way = Vector((sx * 0.5, -0.86, 0.0)).normalized()  # (the ear's front faces forward and out)
        centres, across, up, widths, depths = [], [], [], [], []
        n = 7
        for k in range(n):
            t = k / (n - 1)
            centres.append(root.lerp(tip, t) + Vector((0, 0, 0.04 * math.sin(t * math.pi))))
            across.append(face_way)
            up.append(Vector((0, 0, 1)))
            widths.append(0.045 * (1 - 0.6 * t) + 0.008)
            depths.append(0.19 * math.sin(math.pi * (0.25 + 0.75 * t)) ** 0.6 * (1 - 0.15 * t) + 0.01)
        parts.append(loft("Ear", centres, across, up, widths, depths, mats["face"], sides=16))
        bowl = mk.sphere("EarBowl", 1.0, tuple(root.lerp(tip, 0.55) - face_way * 0.035), mat=mats["lips"], segments=16,
                         rings=10)
        bowl.rotation_mode = "QUATERNION"
        bowl.rotation_quaternion = face_way.to_track_quat("Y", "Z")
        bowl.scale = (0.07, 0.012, 0.11)
        parts.append(bowl)
    # A hoop through the left ear's root, a heart hanging from it.
    loop = Vector((1.0, 0.18, -0.17))
    parts.append(mk.torus("EarLoop", 0.075, 0.013, tuple(loop), rot=(0, 90, 0), mat=mats["steel"], major_segments=18,
                          minor_segments=6))
    heart = loop + Vector((0.0, -0.01, -0.16))
    for sx in (-1, 1):
        parts.append(mk.sphere("HeartLobe", 0.04, tuple(heart + Vector((sx * 0.03, 0, 0.03))), scale=(1, 0.45, 1),
                               mat=mats["steel"], segments=12, rings=8))
    parts.append(mk.cylinder("HeartPoint", 0.058, 0.035, tuple(heart + Vector((0, 0, -0.025))), rot=(90, 0, 0),
                             mat=mats["steel"], verts=3))
    return parts, glows
