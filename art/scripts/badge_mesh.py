"""The Operative's badge (BureauBadge) as geometry and its texture layout: the wallet with a real fold and raised
stitches, the shield raised from the shapes of badge_design.py (a rolled rim, a layered eagle, laurel leaves, cloisonne
enamel with raised lettering and a star), the ID card in a stitched leather window. props.bureau_badge() calls build().

Coordinates (builder space, as before the remake): the wallet stands in the XZ plane, its face to -Y, 0.86 wide and 0.6
tall; the shield on the right half (centre x 0.22), the ID card on the left (x -0.22). Each half is turned a couple of
degrees about the fold, so the open wallet lies in a shallow valley and a raking light finds the relief.

The shield's and the card's faces are laid flat in two big rectangles of the 1024 px map and drawn by badge_paint
(finish() below); the leather is baked from the scanned leather as every prop's is; the stitches share a small
rectangle of thread colour."""

import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import badge_design as D
import modelkit as mk

Y0 = -0.015          # the wallet's front face
HALF = (0.42, 0.03, 0.6)
TILT = 2.2           # degrees each half is turned about the fold
CX = {"R": 0.22, "L": -0.22}
INTO = D.INTO
GOLD, ENAMEL, CARD, THREAD, LEATHER = "Badge_Gold", "Badge_Enamel", "Badge_Card", "Badge_Thread", "Badge_Leather"


def _y(h):
    return Y0 - h


class Group:
    """Geometry of one half of the wallet (or the fold), by material, in a bmesh each."""

    def __init__(self, side, mats):
        self.side = side
        self.cx = CX.get(side, 0.0)
        self.turn = math.radians(-TILT if side == "R" else TILT) if side in CX else 0.0
        self.mats = mats
        self.bms = {}

    def bm(self, mat):
        if mat not in self.bms:
            self.bms[mat] = bmesh.new()
        return self.bms[mat]

    def v(self, bm, x, z, h):
        """A vertex at design (x, z) (relative to the half's centre) and height h above the wallet's face."""
        px, py = x + self.cx, _y(h)
        c, s = math.cos(self.turn), math.sin(self.turn)
        return bm.verts.new((px * c - py * s, px * s + py * c, z))

    def objects(self, name):
        out = []
        for mat, bm in self.bms.items():
            mesh = bpy.data.meshes.new(f"{name}_{mat}")
            bm.to_mesh(mesh)
            bm.free()
            mesh.materials.append(self.mats[mat])
            obj = bpy.data.objects.new(f"{name}_{mat}", mesh)
            mk._link(obj)
            out.append(obj)
        self.bms = {}
        return out

    # -- shapes --
    def prism(self, mat, pts, h0, h1, draft=0.0, walls=True):
        """A raised polygon (counter-clockwise in x, z): its outline at h0, its top at h1 drawn in by draft*(h1-h0)."""
        bm = self.bm(mat)
        top_pts = D.offset(pts, -draft * (h1 - h0)) if draft > 0 else pts
        top = [self.v(bm, x, z, h1) for x, z in top_pts]
        bm.faces.new(top)
        if walls and h1 > h0:
            base = [self.v(bm, x, z, h0) for x, z in pts]
            n = len(pts)
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((base[i], base[j], top[j], top[i]))

    def sweep(self, mat, path, profile):
        """A bead swept along a closed counter-clockwise path: profile [(d, h)], d outward from the path."""
        bm = self.bm(mat)
        n = len(path)
        rows = []
        for i in range(n):
            p, a, b = path[i - 1], path[i], path[(i + 1) % n]
            e1 = (a[0] - p[0], a[1] - p[1])
            e2 = (b[0] - a[0], b[1] - a[1])
            l1, l2 = math.hypot(*e1) or 1.0, math.hypot(*e2) or 1.0
            n1, n2 = (e1[1] / l1, -e1[0] / l1), (e2[1] / l2, -e2[0] / l2)
            s = (n1[0] + n2[0], n1[1] + n2[1])
            ls = math.hypot(*s) or 1.0
            s = (s[0] / ls, s[1] / ls)
            cosine = max(0.45, s[0] * n1[0] + s[1] * n1[1])
            rows.append([self.v(bm, a[0] + s[0] * d / cosine, a[1] + s[1] * d / cosine, h) for d, h in profile])
        for i in range(n):
            j = (i + 1) % n
            for k in range(len(profile) - 1):
                bm.faces.new((rows[i][k], rows[i][k + 1], rows[j][k + 1], rows[j][k]))

    def stroke(self, mat, pts, width, h0, h1, closed=False):
        """A polyline `width` wide standing from h0 to h1 with upright walls, mitred at its joints."""
        bm = self.bm(mat)
        n = len(pts)
        left, right = [], []
        for i in range(n):
            a = pts[i]
            if closed:
                p, b = pts[i - 1], pts[(i + 1) % n]
            else:
                p = pts[i - 1] if i > 0 else None
                b = pts[i + 1] if i < n - 1 else None
            tangents = []
            if p is not None:
                d = (a[0] - p[0], a[1] - p[1])
                l = math.hypot(*d) or 1.0
                tangents.append((d[0] / l, d[1] / l))
            if b is not None:
                d = (b[0] - a[0], b[1] - a[1])
                l = math.hypot(*d) or 1.0
                tangents.append((d[0] / l, d[1] / l))
            normals = [(-t[1], t[0]) for t in tangents]
            sx, sz = sum(q[0] for q in normals), sum(q[1] for q in normals)
            ls = math.hypot(sx, sz) or 1.0
            sx, sz = sx / ls, sz / ls
            cosine = max(0.5, sx * normals[0][0] + sz * normals[0][1])
            k = width / 2 / cosine
            left.append((a[0] + sx * k, a[1] + sz * k))
            right.append((a[0] - sx * k, a[1] - sz * k))
        tl = [self.v(bm, x, z, h1) for x, z in left]
        tr = [self.v(bm, x, z, h1) for x, z in right]
        bl = [self.v(bm, x, z, h0) for x, z in left]
        br = [self.v(bm, x, z, h0) for x, z in right]
        last = n if closed else n - 1
        for i in range(last):
            j = (i + 1) % n
            bm.faces.new((tr[i], tr[j], tl[j], tl[i]))
            bm.faces.new((bl[j], bl[i], tl[i], tl[j]))
            bm.faces.new((br[i], br[j], tr[j], tr[i]))
        if not closed:
            bm.faces.new((br[0], bl[0], tl[0], tr[0]))
            bm.faces.new((bl[-1], br[-1], tr[-1], tl[-1]))

    def ridge(self, mat, centre, direction, length, width, height):
        """A stitch: a low ridge along `direction` with sloping sides and pointed ends."""
        bm = self.bm(mat)
        cx, cz = centre
        tx, tz = direction
        nx, nz = -tz, tx
        ra = (cx - tx * length * 0.42, cz - tz * length * 0.42)
        rb = (cx + tx * length * 0.42, cz + tz * length * 0.42)
        wl0 = self.v(bm, ra[0] + nx * width / 2, ra[1] + nz * width / 2, 0.0)
        wr0 = self.v(bm, ra[0] - nx * width / 2, ra[1] - nz * width / 2, 0.0)
        wl1 = self.v(bm, rb[0] + nx * width / 2, rb[1] + nz * width / 2, 0.0)
        wr1 = self.v(bm, rb[0] - nx * width / 2, rb[1] - nz * width / 2, 0.0)
        t0 = self.v(bm, ra[0], ra[1], height)
        t1 = self.v(bm, rb[0], rb[1], height)
        # a hexagon-ish ridge: two sloping sides and two sloping ends (the wide points at the base)
        bm.faces.new((wr0, wr1, t1, t0))
        bm.faces.new((wl1, wl0, t0, t1))


def rounded_rect(w, h, r, n=4):
    """A counter-clockwise rounded rectangle about the origin, n points a corner."""
    pts = []
    for (sx, sz, a0) in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        cx, cz = sx * (w / 2 - r), sz * (h / 2 - r)
        for k in range(n):
            a = math.radians(a0 + 90 * k / (n - 1))
            pts.append((cx + r * math.cos(a), cz + r * math.sin(a)))
    return D.ccw(pts)


def along(path, step, inset_start=0.0):
    """Points and directions every `step` along a closed path."""
    ring = list(path) + [path[0]]
    lengths = [math.dist(a, b) for a, b in zip(ring, ring[1:])]
    total = sum(lengths)
    count = max(1, int(total / step))
    out = []
    for n in range(count):
        want = (n + 0.5) * total / count
        run = 0.0
        for k, l in enumerate(lengths):
            if run + l >= want:
                t = (want - run) / l
                a, b = ring[k], ring[k + 1]
                d = ((b[0] - a[0]) / l, (b[1] - a[1]) / l)
                out.append(((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), d))
                break
            run += l
    return out


def build(mats):
    """mats: {name: material} for GOLD, ENAMEL, CARD, THREAD, LEATHER. Returns (parts, more)."""
    import propkit as pk

    parts = []
    # the wallet's halves (boxes with their edges rounded), each turned about the fold
    for side, x in (("R", CX["R"]), ("L", CX["L"])):
        half = pk.rounded("Half" + side, HALF, (x, 0, 0), mats[LEATHER], r=0.012)
        turn = math.radians(-TILT if side == "R" else TILT)
        c, s = math.cos(turn), math.sin(turn)
        half.location = (x * c, x * s, 0)
        half.rotation_euler = (0, 0, turn)
        parts.append(half)
    parts.append(mk.cylinder("Fold", 0.017, 0.6, (0, 0, 0), mat=mats[LEATHER], verts=12))

    # stitching round both halves' faces and round the card's window
    stitch_path = D.ccw(rounded_rect(HALF[0] - 0.034, HALF[2] - 0.034, 0.03, 5))
    for side in ("R", "L"):
        g = Group(side, mats)
        for (px, pz), d in along(stitch_path, 0.042):
            g.ridge(THREAD, (px, pz), d, 0.024, 0.0050, 0.0022)
        parts += g.objects("Stitch" + side)
    # the card in its window (left half)
    g = Group("L", mats)
    card_outline = D.ccw(rounded_rect(0.34, 0.50, 0.012, 4))
    g.prism(CARD, card_outline, 0.0, 0.0030, draft=0.0)
    window = D.ccw(rounded_rect(0.352, 0.512, 0.016, 5))
    g.sweep(LEATHER, window, [(-0.0135, 0.0), (-0.0105, 0.0058), (0.0105, 0.0058), (0.0135, 0.0)])
    for (px, pz), d in along(D.ccw(rounded_rect(0.376, 0.536, 0.02, 5)), 0.042):
        g.ridge(THREAD, (px, pz), d, 0.020, 0.0044, 0.0020)
    parts += g.objects("Card")
    # the shield and what is on it (right half)
    g = Group("R", mats)
    for it in D.placed_items():
        mat = ENAMEL if it["cls"] in ("enamel", "navy") else GOLD
        if it["kind"] == "poly":
            g.prism(mat, it["pts"], it["h0"], it["h1"], draft=0.0 if it.get("flat") else it["draft"],
                    walls=not it.get("flat"))
        elif it["kind"] == "ring":
            w = it["width"]
            g.sweep(mat, it["pts"], [(-w / 2, it["h0"]), (-w * 0.34, it["h0"] + (it["h1"] - it["h0"]) * 0.62),
                                     (0.0, it["h1"]), (w * 0.34, it["h0"] + (it["h1"] - it["h0"]) * 0.62),
                                     (w / 2, it["h0"])])
        else:
            g.stroke(mat, it["pts"], it["width"], it["h0"], it["h1"], it["closed"])
    parts += g.objects("Shield")
    return parts


# The texture layout -------------------------------------------------------------------------------------------------


def lay_planar(obj, picked, side, rect, box, mirror=False):
    """Flat UVs for faces looking at -Y: seen from the front in the half's own frame (undoing its turn), their (x, z)
    fill `rect` (px of the 1024 map) as `box` (x0, z0, x1, z1) of the design frame."""
    mesh = obj.data
    layer = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    turn = math.radians(-TILT if side == "R" else TILT)
    c, s = math.cos(-turn), math.sin(-turn)
    sx = (rect[2] - rect[0]) / (box[2] - box[0])
    sz = (rect[3] - rect[1]) / (box[3] - box[1])
    cx = CX[side]
    for index in picked:
        for loop in mesh.polygons[index].loop_indices:
            co = mesh.vertices[mesh.loops[loop].vertex_index].co
            x = co.x * c - co.y * s - cx
            u = rect[2] - (x - box[0]) * sx if mirror else rect[0] + (x - box[0]) * sx
            layer.data[loop].uv = (u / 1024.0, (rect[1] + (co.z - box[1]) * sz) / 1024.0)
    return set(picked)


def laid(obj):
    """Lays the shield's faces, the card's face and the thread in their rectangles; what is left is unwrapped."""
    mesh = obj.data
    names = [m.name for m in mesh.materials]

    def faces(match, facing=None):
        out = []
        for p in mesh.polygons:
            if match(names[p.material_index]) and (facing is None or p.normal.y < facing):
                out.append(p.index)
        return out

    done = set()
    done |= lay_planar(obj, faces(lambda n: n.startswith((GOLD, ENAMEL)), -0.12), "R", D.SHIELD_RECT, D.SHIELD_BOX)
    done |= lay_planar(obj, faces(lambda n: n.startswith(CARD), -0.12), "L", D.CARD_RECT, D.CARD_BOX)
    for side, pick in ("R", lambda p: p.center.x > 0.025), ("L", lambda p: p.center.x < -0.025):
        front = [p.index for p in mesh.polygons if names[p.material_index].startswith(LEATHER) and pick(p) and p.normal.y < -0.12]
        back = [p.index for p in mesh.polygons if names[p.material_index].startswith(LEATHER) and pick(p) and p.normal.y > 0.12]
        mirror = side == "L"
        done |= lay_planar(obj, front, side, D.LEATHER_RECT, D.LEATHER_BOX, mirror=mirror)
        done |= lay_planar(obj, back, side, D.LEATHER_RECT, D.LEATHER_BOX, mirror=not mirror)
    fold = [p.index for p in mesh.polygons if names[p.material_index].startswith(LEATHER) and abs(p.center.x) <= 0.025]
    layer0 = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    for index in fold:
        for loop in mesh.polygons[index].loop_indices:
            layer0.data[loop].uv = ((D.FOLD_RECT[0] + 12) / 1024.0, (D.FOLD_RECT[1] + 12) / 1024.0)
    done |= set(fold)
    thread = faces(lambda n: n.startswith(THREAD))
    # (a flat colour: every stitch lies in one small patch)
    layer = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    r = D.THREAD_RECT
    for index in thread:
        for loop in mesh.polygons[index].loop_indices:
            layer.data[loop].uv = ((r[0] + 12) / 1024.0, (r[1] + 12) / 1024.0)
    done |= set(thread)
    return done


def _window(arr, rect):
    h, w = arr.shape[:2]
    return slice(round(rect[1] / 1024 * h), round(rect[3] / 1024 * h)), slice(round(rect[0] / 1024 * w), round(rect[2] / 1024 * w))


def _lay(color, normal, rough, metal, rect, made):
    import badge_paint as P

    win = _window(color, rect)
    rows, cols = win[0].stop - win[0].start, win[1].stop - win[1].start
    src = P.shrink(made["color"], rows, cols) if made["color"].shape[0] > rows else made["color"]
    color[win][..., :3] = np.resize(src, (rows, cols, 3)) if src.shape[:2] != (rows, cols) else src
    win_n = _window(normal, rect)
    rn, cn = win_n[0].stop - win_n[0].start, win_n[1].stop - win_n[1].start
    relief = P.shrink(made["relief"], rn, cn)
    du, dv = made["step"][0] * made["relief"].shape[1] / cn, made["step"][1] * made["relief"].shape[0] / rn
    normal[win_n][..., :3] = P.normals_from(relief, du, dv)
    win_r = _window(rough, rect)
    rr, cr = win_r[0].stop - win_r[0].start, win_r[1].stop - win_r[1].start
    rough[win_r][..., :3] = P.shrink(made["rough"], rr, cr)[..., None]
    if metal is not None:
        win_m = _window(metal, rect)
        rm, cm = win_m[0].stop - win_m[0].start, win_m[1].stop - win_m[1].start
        metal[win_m][..., :3] = P.shrink(made["metal"], rm, cm)[..., None]


def finish(color, normal, rough, metal=None):
    """Draws the shield and the card over the baked maps, and flat thread colour (modelkit.bake's `finish`)."""
    import badge_paint as P

    _lay(color, normal, rough, metal, D.SHIELD_RECT, P.shield())
    _lay(color, normal, rough, metal, D.CARD_RECT, P.card())
    _lay(color, normal, rough, metal, D.LEATHER_RECT, P.leather())
    fold = {"color": np.full((32, 32, 3), np.array([22, 19, 19], np.float32) / 255.0, np.float32),
            "rough": np.full((32, 32), 0.7, np.float32), "metal": np.zeros((32, 32), np.float32),
            "relief": np.zeros((32, 32), np.float32), "step": (0.001, 0.001)}
    _lay(color, normal, rough, metal, D.FOLD_RECT, fold)
    thread = {"color": np.full((32, 32, 3), np.array([124, 104, 82], np.float32) / 255.0, np.float32),
              "rough": np.full((32, 32), 0.78, np.float32), "metal": np.zeros((32, 32), np.float32),
              "relief": np.zeros((32, 32), np.float32), "step": (0.001, 0.001)}
    _lay(color, normal, rough, metal, D.THREAD_RECT, thread)
