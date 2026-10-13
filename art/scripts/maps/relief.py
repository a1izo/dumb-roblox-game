"""Real relief on a wall: a scan's relief tile (made by art/scripts/heightmap.py) laid over chosen faces
of a scene, so that the joints of a stone wall are cut into the mesh instead of only painted on.

The tile repeats with the face's own UVs, so its grooves lie under the joints the texture shows. It only
goes into the wall (the faces stay where the colliders, props and signs were placed against them), and
it comes up to nothing at a face's edges (corners, window reveals, the ground, the top of the band), so
the faces around it still meet it. What is laid moves to the material <mat>Relief, whose normal map
(scanlib) is made for its facets; the rest of each face stays as it was.
"""

import math
import os

import numpy as np

import common
from maps import mesher


def load(scan):
    path = os.path.join(common.source("prepared"), f"{scan}_relief.npz")
    if not os.path.exists(path):
        raise FileNotFoundError(f"{path} is missing: run art/scripts/heightmap.py {scan} (see there)")
    data = np.load(path)
    return {key: data[key] for key in data.files}


def _uv_of(piece):
    """Each vertex's UV (repeats), from the face corners that use it."""
    uv = [None] * len(piece.verts)
    for face, corners in zip(piece.faces, piece.uvs):
        for i, c in zip(face, corners):
            uv[i] = c
    return uv


def _affine(points, uvs):
    """(origin, U, V) with point = origin + U u + V v on the face's plane."""
    p0, p1, p2 = (np.array(points[i], dtype=np.float64) for i in range(3))
    (u0, v0), (u1, v1), (u2, v2) = uvs[0], uvs[1], uvs[2]
    m = np.array([[u1 - u0, v1 - v0], [u2 - u0, v2 - v0]])
    U, V = np.linalg.solve(m, np.array([p1 - p0, p2 - p0]))
    return p0 - U * u0 - V * v0, U, V


def _clip(poly, inside, cross):
    """Sutherland-Hodgman: the part of a convex polygon (list of points) where inside(p) holds."""
    out = []
    for i, p in enumerate(poly):
        q = poly[i - 1]
        if inside(p):
            if not inside(q):
                out.append(cross(q, p))
            out.append(p)
        elif inside(q):
            out.append(cross(q, p))
    return out


def _half_plane(a, b):
    """inside/cross for the left of the directed edge a -> b (a counter-clockwise polygon's inside)."""
    ex, ey = b[0] - a[0], b[1] - a[1]

    def side(p):
        return ex * (p[1] - a[1]) - ey * (p[0] - a[0])

    def inside(p):
        return side(p) >= -1e-12

    def cross(p, q):
        sp, sq = side(p), side(q)
        t = sp / (sp - sq)
        return tuple(p[k] + (q[k] - p[k]) * t for k in range(len(p)))

    return inside, cross


def _ccw(poly):
    area = sum(poly[i - 1][0] * p[1] - p[0] * poly[i - 1][1] for i, p in enumerate(poly))
    return poly if area > 0 else poly[::-1]


def _edge_distance(p, poly):
    """Distance from a point inside a convex polygon to its nearest edge (same units)."""
    best = math.inf
    for i, b in enumerate(poly):
        a = poly[i - 1]
        ex, ey = b[0] - a[0], b[1] - a[1]
        length = math.hypot(ex, ey)
        if length > 1e-12:
            best = min(best, abs(ex * (p[1] - a[1]) - ey * (p[0] - a[0])) / length)
    return best


def _smoothstep(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def _lay(tile, region, tile_studs, fade):
    """The tile's triangles over a convex region of the face (UV polygon, counter-clockwise), clipped to
    it: [((u, v, depth) x 3)], depth in studs into the wall, faded out towards the region's edges."""
    tri_uv, tri_d = tile["uv"], tile["depth"]
    us = [p[0] for p in region]
    vs = [p[1] for p in region]
    t_lo, t_hi = tri_uv.min(axis=(0, 1)), tri_uv.max(axis=(0, 1))
    edges = [_half_plane(region[i - 1], region[i]) for i in range(len(region))]
    out = []
    for i in range(int(math.floor(min(us) - t_hi[0])), int(math.ceil(max(us) - t_lo[0])) + 1):
        for j in range(int(math.floor(min(vs) - t_hi[1])), int(math.ceil(max(vs) - t_lo[1])) + 1):
            shift = np.array([i, j], dtype=np.float64)
            lo = tri_uv.min(axis=1) + shift
            hi = tri_uv.max(axis=1) + shift
            near = (hi[:, 0] >= min(us)) & (lo[:, 0] <= max(us)) & (hi[:, 1] >= min(vs)) & (lo[:, 1] <= max(vs))
            for t in np.nonzero(near)[0]:
                poly = [(tri_uv[t, k, 0] + i, tri_uv[t, k, 1] + j, tri_d[t, k]) for k in range(3)]
                for inside, cross in edges:
                    poly = _clip(poly, inside, cross)
                    if len(poly) < 3:
                        break
                if len(poly) < 3:
                    continue
                faded = []
                for u, v, d in poly:
                    edge = _edge_distance((u, v), region) * tile_studs
                    faded.append((u, v, d * _smoothstep(edge / fade)))
                for k in range(1, len(faded) - 1):
                    out.append((faded[0], faded[k], faded[k + 1]))
    return out


def _nearest(points, x, z):
    """The point of a polyline [(x, z)] nearest to (x, z)."""
    best, out = math.inf, points[0]
    for (ax, az), (bx, bz) in zip(points, points[1:]):
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / max(1e-12, dx * dx + dz * dz)))
        px, pz = ax + t * dx, az + t * dz
        d = math.hypot(x - px, z - pz)
        if d < best:
            best, out = d, (px, pz)
    return out


def _on(piece, segments, near, street):
    """Whether a face lies on one of the wall lines (x, z segments) and faces the street (a polyline)."""
    xs = [p[0] for p in piece.verts]
    zs = [p[2] for p in piece.verts]
    n = mesher.norm(mesher.cross(mesher.sub(piece.verts[1], piece.verts[0]), mesher.sub(piece.verts[2], piece.verts[0])))
    if abs(n[1]) > 0.05:
        return False
    for (ax, az), (bx, bz) in segments:
        dx, dz = bx - ax, bz - az
        length = math.hypot(dx, dz)
        dx, dz = dx / length, dz / length
        if abs(n[0] * dx + n[2] * dz) > 0.2:
            continue
        ok = True
        for x, z in zip(xs, zs):
            along = (x - ax) * dx + (z - az) * dz
            off = abs((x - ax) * -dz + (z - az) * dx)
            if off > near or along < -near or along > length + near:
                ok = False
                break
        if not ok:
            continue
        cx, cz = sum(xs) / len(xs), sum(zs) / len(zs)
        sx, sz = _nearest(street, cx, cz)
        if n[0] * (sx - cx) + n[2] * (sz - cz) > 0:
            return True
    return False


def apply(scene, mat, scan, segments, street, top, cap, near=1.2, fade=0.15):
    """Lays the relief over the faces of `mat` on the wall lines `segments` ([((x, z), (x, z))]) that face
    the street (its centre line, [(x, z)]), from the ground up to the bed joint nearest `top` studs.
    Raises if that would add more than `cap` triangles. Returns (triangles added, band top)."""
    tile = load(scan)
    tile_studs = float(tile["tile_studs"])
    # The band ends on the upper arris of a bed joint (v up: above the joint's middle), so the whole joint
    # is cut and the block above starts flat.
    tops = [(float(b) + float(tile["arris_v"]) + k) * tile_studs for b in tile["beds_v"] for k in range(-2, 40)]
    band = min(tops, key=lambda y: abs(y - top))
    relief_mat = mat + "Relief"
    before = scene.triangles()
    keep, picked = [], []
    for piece in scene.pieces.get(mat, []):
        lowest = min(p[1] for p in piece.verts)
        (picked if lowest < band - 1e-6 and _on(piece, segments, near, street) else keep).append(piece)
    scene.pieces[mat] = keep
    for piece in picked:
        _relieve(scene, piece, mat, relief_mat, tile, tile_studs, band, fade)
    added = scene.triangles() - before
    print(f"[relief] {mat}: {len(picked)} faces up to y {band:.2f}, {added} triangles added (cap {cap})")
    if added > cap:
        raise RuntimeError(f"relief on {mat} adds {added} triangles, over the cap of {cap}: make the tile coarser "
                           "(art/scripts/heightmap.py --face-step) or the band smaller")
    return added, band


def _relieve(scene, piece, mat, relief_mat, tile, tile_studs, band, fade):
    uvs = _uv_of(piece)
    origin, U, V = _affine(piece.verts, uvs)
    normal = np.array(mesher.norm(mesher.cross(mesher.sub(piece.verts[1], piece.verts[0]),
                                               mesher.sub(piece.verts[2], piece.verts[0]))))
    face = _ccw([tuple(uv) for uv in uvs])
    # Whether counter-clockwise in UV is counter-clockwise seen from the front.
    front = float(np.dot(np.cross(U, V), normal)) > 0

    def y_of(p):
        return origin[1] + U[1] * p[0] + V[1] * p[1]

    def at_band(p, q):
        t = (band - y_of(p)) / (y_of(q) - y_of(p))
        return tuple(p[k] + (q[k] - p[k]) * t for k in range(len(p)))

    lower = _clip(face, lambda p: y_of(p) <= band + 1e-9, at_band)
    upper = _clip(face, lambda p: y_of(p) >= band - 1e-9, at_band)
    tris = _lay(tile, lower, tile_studs, fade) if len(lower) >= 3 else []
    if tris:
        out = mesher.Piece()
        for corners in tris:
            pts = [tuple(float(x) for x in origin + U * u + V * v - normal * d) for u, v, d in corners]
            # Counter-clockwise from the front, like every face of the scene.
            if np.dot(np.cross(np.subtract(pts[1], pts[0]), np.subtract(pts[2], pts[0])), normal) < 0:
                pts = [pts[0], pts[2], pts[1]]
                corners = (corners[0], corners[2], corners[1])
            base = len(out.verts)
            out.verts.extend(pts)
            out.faces.append((base, base + 1, base + 2))
            out.uvs.append(tuple((u, v) for u, v, _ in corners))
        out.centre = tuple(float(x) for x in np.mean(np.array(out.verts), axis=0))
        scene.pieces.setdefault(relief_mat, []).append(out)
        scene.used.add(relief_mat)
    if len(upper) >= 3:
        # The rest of the face, with the relief's vertices along the band's line added, so the two meet
        # vertex for vertex (no T-junctions to crack open).
        on_line = sorted({(u, v) for t in tris for u, v, d in t if abs(y_of((u, v)) - band) < 1e-6})
        ring = _with_points(upper if front else upper[::-1], on_line, y_of, band)
        pts = [tuple(float(x) for x in origin + U * u + V * v) for u, v in ring]
        scene.polygon(mat, pts, uvs=[(u * tile_studs, v * tile_studs) for u, v in ring], tile=tile_studs)


def _with_points(poly, points, y_of, band):
    """The polygon (convex, in UV) with `points` inserted along its edge on the band's line, starting from
    a corner off that line so a fan from it makes no sliver."""
    if not points:
        return poly
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        if abs(y_of(a) - band) < 1e-6 and abs(y_of(b) - band) < 1e-6:
            da = np.subtract(b, a)
            inner = [p for p in points if 1e-9 < np.dot(np.subtract(p, a), da) / np.dot(da, da) < 1 - 1e-9]
            inner.sort(key=lambda p: np.dot(np.subtract(p, a), da))
            ring = poly[: i + 1] + inner + poly[i + 1:]
            start = next(k for k, p in enumerate(ring) if abs(y_of(p) - band) > 1e-6)
            return ring[start:] + ring[:start]
    return poly
