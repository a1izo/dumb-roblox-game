"""Finders: scripts that point at likely visual defects in a built venue, without Studio. They give
candidates only; every one is looked at (a Blender eye render, or the game) before anything moves.

  zfight    two faces in the same place facing the same way: they flicker as the camera moves
  rest      props floating above whatever is under them, or sunk into it
  fixture   lamps far from any glowing fitting (light from nowhere), and fittings that glow with no
            lamp near them (a bulb that lights nothing)
  leak      light that reaches through a wall, floor or ceiling onto the surfaces beyond: in Roblox a
            light without shadows ignores walls, and only the few lamps nearest the camera cast them
  stretch   textured faces whose picture is stretched one way or sheared (or has no extent at all)
  buried    signs, plaques, screens and clock faces the game draws that stand inside a wall (their
            front looks at the back of a face: nobody can see them)

Runs inside Blender (it needs mathutils): art/scripts/find_defects.py builds each venue and calls
run(). Coordinates are Roblox studs, like the scene's (x right, y up, z backwards).
"""

import math

from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

from maps import matlib

ZFIGHT_GAP = 0.02  # faces closer than this (studs) along their normal draw on top of each other
ZFIGHT_AREA = 0.1  # square studs of overlap worth a look
FLOAT_GAP = 0.12  # a prop's base this far above everything under it floats
SINK_DEPTH = 0.3  # ... and this far below the surface under its middle is sunk
FIXTURE_REACH = 1.2  # a lamp this far from any glowing face has no fitting
LIT_REACH = 4.0  # a fitting with no lamp this close lights nothing
LEAK_LEVEL = 0.12  # the light (brightness x falloff x facing) a surface beyond a wall may get unnoticed
HOUSING = 0.75  # faces this close to a lamp are its own fitting, not a wall
BEYOND = 2.5  # a lit face counts as beyond the wall only this far past it (a beam's shadow is not a leak)
STRETCH = 1.6  # the picture stretched more than this one way against the other
SHEAR = 60.0  # degrees: the picture's axes closer than this on the face

# The fittings whose glow means "a lamp is here" (windows and far scenery glow on their own).
FITTINGS = {"PanelWarm", "PanelCool", "TubeDiffuser", "NeonWarm", "NeonCool"}
FACES = {"Bottom": (0, -1, 0), "Top": (0, 1, 0), "Front": (0, 0, -1), "Back": (0, 0, 1), "Left": (-1, 0, 0),
         "Right": (1, 0, 0)}


def emissive(mat):
    return matlib.is_flat(mat) and matlib.FLAT[mat][0] == "Neon"


def see_through(mat):
    """Glass, water, alpha sheets: they neither stop light nor hold a lamp."""
    if mat in matlib.ALPHA:
        return True
    return matlib.is_flat(mat) and (matlib.FLAT[mat][0] == "Glass" or matlib.FLAT[mat][2] > 0)


def turn(rot, x, z):
    """(x, z) turned rot degrees about +Y (x' = x cos + z sin, z' = -x sin + z cos)."""
    a = math.radians(rot)
    c, s = math.cos(a), math.sin(a)
    return x * c + z * s, -x * s + z * c


class Tris:
    """Every face of the scene as triangles, with its material and piece, and BVH trees over them."""

    def __init__(self, scene):
        self.verts, self.polys, self.mats, self.pieces = [], [], [], []
        self.uvs = []
        self.src = []  # per piece: the script line that made it (when the scene was traced)
        sources = getattr(scene, "piece_src", {})
        pid = 0
        for mat, pieces in sorted(scene.pieces.items()):
            for piece in pieces:
                self.src.append(sources.get(id(piece), ""))
                base = len(self.verts)
                self.verts.extend(Vector(v) for v in piece.verts)
                for face, uv in zip(piece.faces, piece.uvs):
                    self.polys.append(tuple(base + i for i in face))
                    self.mats.append(mat)
                    self.pieces.append(pid)
                    self.uvs.append(uv)
                pid += 1
        self._trees = {}

    def tree(self, which):
        """"all", "opaque" (stops light) or "glow" (emissive): a BVH tree and its triangle indices."""
        if which not in self._trees:
            keep = [i for i, m in enumerate(self.mats)
                    if which == "all" or (which == "opaque" and not see_through(m) and not emissive(m))
                    or (which == "glow" and emissive(m))]
            polys = [self.polys[i] for i in keep]
            tree = BVHTree.FromPolygons(self.verts, polys, epsilon=0.0) if polys else None
            self._trees[which] = (tree, keep)
        return self._trees[which]

    def tri(self, i):
        a, b, c = self.polys[i]
        return self.verts[a], self.verts[b], self.verts[c]


class Eyes:
    """Where a player's eye can be: 5 studs over the walkable floors (scene.floors), every 4 studs. A face
    counts as seen when one of these points near it has a clear line to it, from its front."""

    def __init__(self, scene, step=4.0):
        self.points = []
        for f in scene.floors:
            (x1, z1, x2, z2, x3, z3, y) = f[:7]
            xs, zs = (x1, x2, x3), (z1, z2, z3)
            for gx in range(math.floor(min(xs) / step), math.floor(max(xs) / step) + 1):
                for gz in range(math.floor(min(zs) / step), math.floor(max(zs) / step) + 1):
                    px, pz = (gx + 0.5) * step, (gz + 0.5) * step
                    d1 = (px - x2) * (z1 - z2) - (x1 - x2) * (pz - z2)
                    d2 = (px - x3) * (z2 - z3) - (x2 - x3) * (pz - z3)
                    d3 = (px - x1) * (z3 - z1) - (x3 - x1) * (pz - z1)
                    if not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0)):
                        self.points.append(Vector((px, y + 5.0, pz)))
        self.tree = KDTree(max(1, len(self.points)))
        for i, p in enumerate(self.points):
            self.tree.insert(p, i)
        self.tree.balance()

    def sees(self, everything, point, normal, reach=60.0, tries=48):
        """Whether any eye within reach has a clear line to point, on the side normal faces."""
        if not self.points:
            return True
        near = sorted(self.tree.find_range(point, reach), key=lambda e: e[2])
        checked = 0
        for co, _, dist in near:
            to_eye = co - point
            if to_eye.dot(normal) <= 0.05 * dist:
                continue
            checked += 1
            hit = everything.ray_cast(co, (point - co).normalized(), dist + 0.05)
            if hit[0] is None or hit[3] >= dist - 0.08:
                return True
            if checked >= tries:
                break
        return False


def _where(p):
    return [round(p[0], 1), round(p[1], 1), round(p[2], 1)]


# zfight -------------------------------------------------------------------------------------------

def _clip(subject, a, b):
    """The part of polygon `subject` left of the edge a -> b (2D, counter-clockwise clip)."""
    out = []
    n = len(subject)
    for i in range(n):
        p, q = subject[i], subject[(i + 1) % n]
        side_p = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
        side_q = (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0])
        if side_p >= 0:
            out.append(p)
        if (side_p >= 0) != (side_q >= 0):
            t = side_p / (side_p - side_q)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def _area(poly):
    return abs(sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
                   for i in range(len(poly)))) / 2 if len(poly) >= 3 else 0.0


def _ccw(poly):
    s = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
            for i in range(len(poly)))
    return poly if s >= 0 else poly[::-1]


def zfight(tris, eyes=None):
    everything, _ = tris.tree("all")
    buckets = {}
    planes = []
    for i in range(len(tris.polys)):
        a, b, c = tris.tri(i)
        n = (b - a).cross(c - a)
        area = n.length / 2
        if area < 1e-4:
            planes.append(None)
            continue
        n.normalize()
        d = n.dot(a)
        planes.append((n, d, area))
        key = (round(n.x * 40), round(n.y * 40), round(n.z * 40), math.floor(d / ZFIGHT_GAP))
        buckets.setdefault(key, []).append(i)
    found = {}
    seen = set()
    for key, members in buckets.items():
        nx, ny, nz, k = key
        group = list(members)
        for dk in (1,):
            group += buckets.get((nx, ny, nz, k + dk), [])
        if len(group) < 2:
            continue
        n = planes[group[0]][0]
        u = n.cross(Vector((0, 1, 0)) if abs(n.y) < 0.9 else Vector((1, 0, 0))).normalized()
        v = n.cross(u)
        flat = {}
        grid = {}
        for i in group:
            pts = [(p.dot(u), p.dot(v)) for p in tris.tri(i)]
            flat[i] = _ccw(pts)
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            box = (min(xs), min(ys), max(xs), max(ys))
            for gx in range(math.floor(box[0] / 8), math.floor(box[2] / 8) + 1):
                for gy in range(math.floor(box[1] / 8), math.floor(box[3] / 8) + 1):
                    grid.setdefault((gx, gy), []).append((i, box))
        for cell in grid.values():
            for x in range(len(cell)):
                i, bi = cell[x]
                for y in range(x + 1, len(cell)):
                    j, bj = cell[y]
                    # (Two faces of one material in one place draw the same picture: the world-space UVs
                    # line up, so nothing flickers.)
                    if tris.pieces[i] == tris.pieces[j] or tris.mats[i] == tris.mats[j] or (i, j) in seen:
                        continue
                    if bi[2] <= bj[0] or bj[2] <= bi[0] or bi[3] <= bj[1] or bj[3] <= bi[1]:
                        continue
                    seen.add((i, j))
                    if abs(planes[i][1] - planes[j][1]) > ZFIGHT_GAP:
                        continue
                    poly = flat[i]
                    q = flat[j]
                    for e in range(3):
                        poly = _clip(poly, q[e], q[(e + 1) % 3])
                        if not poly:
                            break
                    overlap = _area(poly)
                    if overlap < 1e-3:
                        continue
                    # Where they overlap, in the world; and whether anyone could see it: a face pressed
                    # against another (its front within a stud of something) is never seen from where anyone stands.
                    cu = sum(q2[0] for q2 in poly) / len(poly)
                    cv = sum(q2[1] for q2 in poly) / len(poly)
                    a = n * planes[i][1] + u * cu + v * cv
                    front = everything.ray_cast(a + n * 0.03, n, 40.0)
                    if front[0] is not None and (front[3] < 1.0 or front[1].dot(n) > 0.3):
                        continue  # pressed against something, or looking into the inside of a solid
                    # A face looking down with nothing under it to stand on is the underside of a floor.
                    if n.y < -0.7 and everything.ray_cast(a + n * 0.03, n, 40.0)[0] is None:
                        continue
                    ma, mb = sorted((tris.mats[i], tris.mats[j]))
                    cluster = (ma, mb, math.floor(a.x / 6), math.floor(a.y / 6), math.floor(a.z / 6))
                    entry = found.setdefault(cluster, {"area": 0.0, "at": a.copy(), "gap": 0.0, "normal": n.copy(),
                                                       "src": sorted({tris.src[tris.pieces[i]], tris.src[tris.pieces[j]]})})
                    entry["area"] += overlap
                    entry["gap"] = max(entry["gap"], abs(planes[i][1] - planes[j][1]))
    out = []
    for (ma, mb, *_), e in found.items():
        if e["area"] >= ZFIGHT_AREA and (eyes is None or eyes.sees(everything, e["at"] + e["normal"] * 0.02, e["normal"])):
            out.append({"kind": "zfight", "at": _where(e["at"]), "detail": f"{ma} / {mb}",
                        "area": round(e["area"], 2), "gap": round(e["gap"], 3), "normal": _where(e["normal"]),
                        "src": e["src"]})
    return out


# rest ---------------------------------------------------------------------------------------------

def _local(box, px, pz):
    """(px, pz) in a prop box's own frame (x along its width, z along its depth)."""
    cx, _, cz, _, _, _, rot = box
    return turn(-rot, px - cx, pz - cz)


def _over(box, px, pz, margin=0.0):
    lx, lz = _local(box, px, pz)
    return abs(lx) <= box[3] / 2 + margin and abs(lz) <= box[5] / 2 + margin


# Props made to hang (from a wire, a hook, a beam) or to perch: they are never "floating".
HANGING = {"Chochin", "LanternString", "PoliceTape", "Noren", "MirrorBall", "Crow"}


def rest(scene, tris, catalog):
    """Props whose base is clear of everything under it (floating), or below the top of the map's
    surface or of another prop under its middle (sunk: a lamp inside a sideboard)."""
    solid, _ = tris.tree("opaque")
    everything, _ = tris.tree("all")
    boxes = []
    for key, x, y, z, rot, sc, *_ in scene.props:
        info = catalog.get(key)
        if not info:
            boxes.append(None)
            continue
        sx, sy, sz = (v * sc for v in info["size"])
        base = y if info["pivot"] == "bottom" else y - sy / 2
        boxes.append((x, base, z, sx, sy, sz, rot))
    # A coarse grid of the boxes, for the props under a point.
    grid = {}
    for i, b in enumerate(boxes):
        if b is None:
            continue
        reach = math.hypot(b[3], b[5]) / 2
        for gx in range(math.floor((b[0] - reach) / 8), math.floor((b[0] + reach) / 8) + 1):
            for gz in range(math.floor((b[2] - reach) / 8), math.floor((b[2] + reach) / 8) + 1):
                grid.setdefault((gx, gz), []).append(i)
    out = []
    down = Vector((0, -1, 0))
    for index, (key, x, y, z, rot, sc, *_) in enumerate(scene.props):
        box = boxes[index]
        if box is None or key in HANGING:
            continue
        cx, base, cz, sx, sy, sz, r = box
        src = scene.prop_src[index] if index < len(scene.prop_src) else ""
        samples = [(0.0, 0.0)] + [(lx * 0.35 * sx, lz * 0.35 * sz) for lx, lz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        gaps, sunk = [], None
        for k, (lx, lz) in enumerate(samples):
            dx, dz = turn(r, lx, lz)
            px, pz = cx + dx, cz + dz
            top = -1e9
            hit = everything.ray_cast(Vector((px, base + 0.4, pz)), down, 60.0) if everything else (None,)
            if hit[0] is not None and hit[1].y > 0.3:
                top = hit[0].y
                if k == 0 and SINK_DEPTH < top - base < sy * 0.6:
                    sunk = ("the floor or the map", top - base)
            for j in grid.get((math.floor(px / 8), math.floor(pz / 8)), ()):
                other = boxes[j]
                if j == index or not _over(other, px, pz):
                    continue
                o_top = other[1] + other[4]
                if o_top <= base + 0.4:
                    top = max(top, o_top)
                elif k == 0 and other[1] < base - 0.05 and o_top - base > SINK_DEPTH:
                    # Standing inside another prop: its top is well above this one's base.
                    sunk = (scene.props[j][0], o_top - base)
            gaps.append(base - top)
        if FLOAT_GAP < min(gaps) < 59:
            # Hung on a wall (a face right behind one of its sides) or from a ceiling: not floating.
            mounted = False
            for lx, lz in ((0, -0.5), (0, 0.5), (-0.5, 0), (0.5, 0)):
                dx, dz = turn(r, lx * sx, lz * sz)
                near = everything.find_nearest(Vector((cx + dx, base + sy / 2, cz + dz)), 0.45)
                if near[0] is not None and abs(near[1].y) < 0.4:
                    mounted = True
            up = everything.ray_cast(Vector((cx, base + sy + 0.01, cz)), Vector((0, 1, 0)), 1.5)
            if not mounted and up[0] is None:
                out.append({"kind": "float", "at": _where((cx, base, cz)), "detail": key, "gap": round(min(gaps), 2),
                            "src": src})
        if sunk:
            out.append({"kind": "sunk", "at": _where((cx, base, cz)), "detail": f"{key} in {sunk[0]}",
                        "depth": round(sunk[1], 2), "src": src})
    return out


# fixture / leak -----------------------------------------------------------------------------------

def lamps(scene, catalog, venue):
    """Every lamp of the scene, its props' and its glowing signs': position, direction, range, strength."""
    out = []
    for i, l in enumerate(scene.lights):
        fx, fy, fz = FACES.get(l.get("face") or "Bottom", (0, -1, 0))
        fx, fz = turn(l.get("rot") or 0.0, fx, fz)  # (a lamp turned by rot: its "Front" faces rot)
        out.append({"src": l.get("src") or f"light {i}", "pos": Vector(l["pos"]), "kind": l["kind"],
                    "dir": Vector((fx, fy, fz)),
                    "angle": l.get("angle", 90), "range": l["range"], "brightness": l["brightness"],
                    "role": l.get("role"), "color": tuple(l["color"]), "prop": None, "shadows": l.get("shadows")})
    for key, x, y, z, rot, sc, *flags in scene.props:
        info = catalog.get(key)
        if not info or (flags and flags[0] == "dark"):
            continue
        for l in info["lights"]:
            ax, ay, az = (v * sc for v in l["at"])
            dx, dz = turn(rot, ax, az)
            fx, fy, fz = FACES.get(l.get("face") or "Bottom", (0, -1, 0))
            fx, fz = turn(rot, fx, fz)  # (a prop's lamp turns with the prop)
            out.append({"src": f"prop {key}", "pos": Vector((x + dx, y + ay, z + dz)), "kind": l.get("kind", "point"),
                        "dir": Vector((fx, fy, fz)), "angle": l.get("angle", 90), "range": l["range"],
                        "brightness": l["brightness"], "role": None, "color": None, "prop": key})
    for s in scene.signs:
        if s.get("glow"):
            fx, fz = turn(s["rot"], 0, -1)
            out.append({"src": "sign " + str(s.get("text", ""))[:20], "pos": Vector(s["pos"]), "kind": "spot",
                        "dir": Vector((fx, 0, fz)), "angle": 120, "range": 10, "brightness": 1.2, "role": "sign",
                        "color": tuple(s["glow"]), "prop": None})
    return out


def fixture(scene, tris, all_lamps, venue):
    glow, keep = tris.tree("glow")
    out = []
    for lamp in all_lamps:
        if lamp["prop"] or lamp["role"] in ("sign",):
            continue
        if venue == "Lobby" and lamp["color"] == (170, 196, 232):
            continue  # the realm's pools: light through the cloud, by the owner's choice
        near = glow.find_nearest(lamp["pos"], 50.0) if glow else (None, None, None, None)
        dist = near[3] if near[0] is not None else 99.0
        if dist > FIXTURE_REACH:
            out.append({"kind": "nofixture", "at": _where(lamp["pos"]), "detail": lamp["src"],
                        "dist": round(dist, 2), "range": lamp["range"], "brightness": lamp["brightness"]})
    tree = KDTree(len(all_lamps))
    for i, lamp in enumerate(all_lamps):
        tree.insert(lamp["pos"], i)
    tree.balance()
    for mat, pieces in scene.pieces.items():
        if mat not in FITTINGS:
            continue
        groups = []
        for piece in pieces:
            c = Vector(piece.centre)
            for g in groups:
                if (g["c"] - c).length < 2.0:
                    g["n"] += 1
                    break
            else:
                groups.append({"c": c, "n": 1})
        for g in groups:
            found = tree.find(g["c"])
            if found[0] is None or found[2] > LIT_REACH:
                out.append({"kind": "dark_fitting", "at": _where(g["c"]), "detail": mat, "pieces": g["n"],
                            "dist": round(found[2], 1) if found[0] is not None else None})
    return out


def _directions(n=160):
    golden = math.pi * (3 - math.sqrt(5))
    out = []
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        r = math.sqrt(1 - y * y)
        out.append(Vector((math.cos(golden * i) * r, y, math.sin(golden * i) * r)))
    return out


def leak(tris, all_lamps):
    opaque, _ = tris.tree("opaque")
    everything, keep_all = tris.tree("all")
    if opaque is None:
        return []
    dirs = _directions()
    out = []
    for lamp in all_lamps:
        if lamp["role"] == "emergency":
            continue
        pos, rng, bright = lamp["pos"], lamp["range"], lamp["brightness"]
        cone = math.cos(math.radians(min(180, lamp["angle"]) / 2))
        leaked, worst, worst_at, worst_mat = 0, 0.0, None, ""
        for d in dirs:
            if lamp["kind"] != "point" and d.dot(lamp["dir"]) < cone:
                continue
            start = pos + d * 0.05
            travelled = 0.05
            wall_at = None  # how far along the ray the first wall was
            for _ in range(8):
                hit = everything.ray_cast(start, d, rng - travelled)
                if hit[0] is None:
                    break
                loc, normal, index, dist = hit
                travelled += dist
                mat = tris.mats[keep_all[index]]
                facing = normal.dot(-d)
                if wall_at is not None and facing > 0.25 and not emissive(mat) and travelled - wall_at >= BEYOND:
                    level = bright * (1 - travelled / rng) ** 2 * facing
                    if level > LEAK_LEVEL:
                        leaked += 1
                        if level > worst:
                            worst, worst_at, worst_mat = level, loc.copy(), mat
                    break
                if wall_at is None and travelled > HOUSING and facing > 0 and not see_through(mat) and not emissive(mat):
                    wall_at = travelled
                start = loc + d * 0.01
                travelled += 0.01
        if leaked >= 3:
            out.append({"kind": "leak", "at": _where(pos), "detail": lamp["src"] + (" (key)" if lamp.get("shadows") else ""),
                        "rays": leaked,
                        "worst": round(worst, 2), "onto": _where(worst_at) if worst_at else None,
                        "onto_mat": worst_mat, "range": rng, "brightness": bright})
    return out


# buried -------------------------------------------------------------------------------------------

def buried(scene, tris):
    everything, keep = tris.tree("all")
    out = []
    things = [("sign", s["pos"], s["rot"], str(s.get("text", ""))[:24]) for s in scene.signs]
    things += [("screen", s["pos"], s["rot"], s.get("loop", "")) for s in scene.screens]
    things += [("clock", c["pos"], c["rot"], "") for c in scene.clocks]
    for kind, pos, rot, label in things:
        fx, fz = turn(rot, 0, -1)
        front = Vector((fx, 0, fz))
        start = Vector(pos) + front * 0.005
        hit = everything.ray_cast(start, front, 1.5)
        if hit[0] is not None and hit[1].dot(front) > 0.3:
            out.append({"kind": "buried", "at": _where(pos), "detail": f"{kind} {label}".strip(),
                        "behind": round(hit[3], 2), "wall": tris.mats[keep[hit[2]]],
                        "src": tris.src[tris.pieces[keep[hit[2]]]]})
    return out


# stretch ------------------------------------------------------------------------------------------

def stretch(tris):
    found = {}
    for i, mat in enumerate(tris.mats):
        if matlib.is_flat(mat) or mat in matlib.ALPHA:
            continue
        a, b, c = tris.tri(i)
        e1, e2 = b - a, c - a
        area = e1.cross(e2).length / 2
        if area < 0.5:
            continue
        (u0, v0), (u1, v1), (u2, v2) = tris.uvs[i]
        du1, dv1, du2, dv2 = u1 - u0, v1 - v0, u2 - u0, v2 - v0
        det = du1 * dv2 - du2 * dv1
        if abs(det) < 1e-9:
            why, value = "no extent", 0.0
        else:
            t = (e1 * dv2 - e2 * dv1) / det
            s = (e2 * du1 - e1 * du2) / det
            lu, lv = t.length, s.length
            if lu < 1e-9 or lv < 1e-9:
                why, value = "no extent", 0.0
            else:
                ratio = max(lu, lv) / min(lu, lv)
                angle = math.degrees(math.acos(max(-1.0, min(1.0, t.dot(s) / (lu * lv)))))
                angle = min(angle, 180 - angle)
                if ratio > STRETCH:
                    why, value = "stretched", ratio
                elif angle < SHEAR:
                    why, value = "sheared", angle
                else:
                    continue
        key = (mat, tris.pieces[i], why)
        entry = found.setdefault(key, {"area": 0.0, "at": (a + b + c) / 3, "value": value,
                                       "src": tris.src[tris.pieces[i]]})
        entry["area"] += area
    out = []
    for (mat, _, why), e in found.items():
        if e["area"] >= 2.0:
            out.append({"kind": "stretch", "at": _where(e["at"]), "detail": f"{mat} {why}",
                        "value": round(e["value"], 2), "area": round(e["area"], 1), "src": e["src"]})
    return out


def inside(scene, at, margin=6.0):
    """Whether a point is within the venue's playable bounds (plus a margin): far scenery is seen only
    from afar, where a flicker or a stray glow is a few pixels."""
    if not scene.bounds:
        return True
    lo, hi = scene.bounds
    return all(lo[k] - margin <= at[k] <= hi[k] + margin for k in range(3))


def run(scene, catalog, venue, kinds=("zfight", "rest", "fixture", "leak", "stretch", "buried")):
    """(finds inside the playable bounds, stats); the stats count the far ones left out."""
    found, stats = _run(scene, catalog, venue, kinds)
    near = [f for f in found if inside(scene, f["at"])]
    stats["far"] = len(found) - len(near)
    return near, stats


def _run(scene, catalog, venue, kinds):
    tris = Tris(scene)
    all_lamps = lamps(scene, catalog, venue)
    eyes = Eyes(scene)
    out = []
    if "zfight" in kinds:
        out += zfight(tris, eyes)
    if "rest" in kinds:
        out += rest(scene, tris, catalog)
    if "fixture" in kinds:
        out += fixture(scene, tris, all_lamps, venue)
    if "leak" in kinds:
        out += leak(tris, all_lamps)
    if "stretch" in kinds:
        out += stretch(tris)
    if "buried" in kinds:
        out += buried(scene, tris)
    return out, {"triangles": len(tris.polys), "lamps": len(all_lamps)}
