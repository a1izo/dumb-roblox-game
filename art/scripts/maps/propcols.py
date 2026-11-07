"""The shape of the props that are solid by their own mesh, as the checks see it (2026-11-07: every rock of the lobby
and most props collide by their mesh now, which Roblox follows closely; check_v2's walk took each as its whole box).

For each prop key: its mesh (Props.blend, as built: its pivot at the origin) cut into columns on a grid seen from above,
each column the heights where the mesh is solid, found by a ray dropped through it. In the game's axes from the prop's
pivot (x = -Blender x, y up, z = Blender y), unscaled:

    {"cell": 1.0, "x0": ..., "z0": ..., "cols": {"i,j": [[y0, y1], ...]}}

Runs inside Blender (mathutils). maps/export.py writes them into the venue's sidecar (propCols) for check_v2.
"""

import math
import os

from mathutils import Vector
from mathutils.bvhtree import BVHTree

import common

_LIBRARY = {}
_CACHE = {}
SHEET = 0.3  # a lone face (a board, a cloth) is taken as solid this thick about it


def _library():
    if _LIBRARY:
        return _LIBRARY
    import bpy

    path = os.path.join(common.BLEND, "Props.blend")
    have = {o.name: o for o in bpy.data.objects if o.type == "MESH" and (common.flag(o, "prop") or o.get("dg_part"))}
    if not have and os.path.exists(path):
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if not n.startswith("Tex_")]
        have = {o.name: o for o in dst.objects if o is not None and o.type == "MESH"}
    _LIBRARY.update(have)
    return _LIBRARY


def _triangles(key):
    lib = _library()
    objs = [lib[key]] if key in lib else []
    objs += [o for o in lib.values() if o.get("dg_part") == key]
    verts, polys = [], []
    for obj in objs:
        me = obj.data
        me.calc_loop_triangles()
        base = len(verts)
        verts.extend(Vector(v.co) for v in me.vertices)
        polys.extend(tuple(base + i for i in t.vertices) for t in me.loop_triangles)
    return verts, polys


def _intervals(hits):
    """Solid spans from the hits of a ray dropped through a mesh (height, the face's up-facing), top to bottom."""
    out = []
    inside_from = None
    for z, up in hits:
        if up > 0.05:  # its top face: the solid begins under it
            if inside_from is None:
                inside_from = z
        elif up < -0.05:  # its underside: the solid ends here
            if inside_from is not None:
                out.append([z, inside_from])
                inside_from = None
            else:
                out.append([z - SHEET / 2, z + SHEET / 2])
        else:
            out.append([z - SHEET / 2, z + SHEET / 2])
    if inside_from is not None:
        low = hits[-1][0]
        out.append([min(low, inside_from - SHEET), inside_from])
    if not out and hits:
        out.append([hits[-1][0], hits[0][0]])
    out.sort()
    merged = []
    for a, b in out:
        if merged and a <= merged[-1][1] + 0.3:
            merged[-1][1] = max(merged[-1][1], b)
        else:
            merged.append([a, b])
    return [[round(a, 2), round(b, 2)] for a, b in merged]


def columns(key):
    """The prop's columns (see the module's note), or None when its mesh is not in Props.blend."""
    if key in _CACHE:
        return _CACHE[key]
    verts, polys = _triangles(key)
    if not polys:
        _CACHE[key] = None
        return None
    tree = BVHTree.FromPolygons(verts, polys, epsilon=0.0)
    xs = [-v.x for v in verts]
    zs = [v.y for v in verts]
    top = max(v.z for v in verts) + 1.0
    span = max(max(xs) - min(xs), max(zs) - min(zs))
    cell = 0.5 if span < 8.0 else 1.0
    x0, z0 = min(xs), min(zs)
    nx, nz = int(math.ceil((max(xs) - x0) / cell)) + 1, int(math.ceil((max(zs) - z0) / cell)) + 1
    down = Vector((0.0, 0.0, -1.0))
    cols = {}
    for i in range(nx):
        for j in range(nz):
            lx, lz = x0 + (i + 0.5) * cell, z0 + (j + 0.5) * cell
            origin = Vector((-lx, lz, top))
            hits = []
            for _ in range(64):
                loc, normal, _index, _dist = tree.ray_cast(origin, down, 1e6)
                if loc is None:
                    break
                hits.append((loc.z, normal.z))
                origin = loc + down * 1e-3
            if hits:
                cols[f"{i},{j}"] = _intervals(hits)
    out = {"cell": cell, "x0": round(x0, 3), "z0": round(z0, 3), "cols": cols}
    _CACHE[key] = out
    return out


def for_scene(scene, catalog):
    """{key: columns} for every prop the scene places that is solid by its own mesh."""
    out = {}
    for p in scene.props:
        key = p[0]
        info = catalog.get(key)
        if info and info.get("collide") and key not in out:
            cols = columns(key)
            if cols:
                out[key] = cols
    return out
