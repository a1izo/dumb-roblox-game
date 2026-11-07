"""Where a body can walk into something drawn (2026-11-07, the user: "make it so you cant noclip through anything at
all ... make everything solid so that it matches the structure too"):

    blender -b --factory-startup --python art/scripts/find_ghosts.py -- [venues...] [--out DIR] [--r 1.0]

For every spot check_v2's walk reaches (with the props solid by their own mesh measured as maps/propcols.py does, and
the catalog's cut solids laid), a column from LOW to HIGH studs over the floor, a body's height, is tested against
every drawn triangle (the venue's own pieces and each placed prop's meshes from art/blend/Props.blend) within R studs.
A triangle there with nothing solid within BACK studs of it (a collider, a floor, a ramp, a prop solid by its mesh, a
SceneBuilder SOLID block) is a ghost: a body walks into it. Props solid by their own mesh are never ghosts.

Writes ghost_<Venue>.txt (a summary by owner: a prop, or a material and the script line that drew it) and
ghost_<Venue>.json (each owner, a sample point) to DIR (default art/export/previews). Left by design on 2026-11-07:
grass (SpikeGrass), a shop's noren, snow a foot sinks into, and stairs' treads (their walking slope runs through the
middle of each riser: a foot is up to half a step into a tread or over it).
"""

import json
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mathutils import Matrix, Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402

import common  # noqa: E402
import find_defects  # noqa: E402
from maps import catalog as cat_mod  # noqa: E402
from maps import check_v2, finders, propcols  # noqa: E402
from maps import geo2d as g2  # noqa: E402

R = 1.0  # how close to a body's middle line a drawn face is in its way (an R6 torso is 2 across)
BACK = 0.35  # how close to something solid a drawn face must be to count as solid itself
LOW, HIGH, STEP_H = 0.35, 4.9, 0.45  # the column tested over each spot

# SceneBuilder's SOLID table (src/server/Maps/SceneBuilder.luau), for the props with neither collision nor cut solids.
SOLID = {
    "Bicycle": {"box": 0.25}, "Scooter": {"box": 0.25}, "TrafficCone": {"box": 0.2}, "BarStool": {"box": 0.2},
    "MicStand": {"pole": 0.6, "top": 5}, "StreetLightTokyo": {"pole": 1.2, "top": 8},
    "TrafficSignal": {"pole": 1.0, "top": 8}, "PedestrianSignal": {"pole": 0.6, "top": 8},
    "RoadSign": {"pole": 0.5, "top": 8}, "BusStopSign": {"pole": 0.9, "top": 8},
    "TaxiRankSign": {"pole": 0.8, "top": 8}, "UtilityPole": {"pole": 1.2, "top": 8},
    "TreeSakura": {"pole": 1.3, "top": 6}, "TreeZelkova": {"pole": 1.3, "top": 6},
    "QueuePosts": {"box": 0.2, "top": 3}, "FloorLamp": {"pole": 0.6, "top": 6},
    "BusShelter": {"walls": [(0, 1.9, 11.6, 0.4), (-6, 0.35, 0.4, 3.2), (6, 0.35, 0.4, 3.2)], "top": 7},
}


def solid_boxes(cat, bases, p):
    """SceneBuilder.solidFor's SOLID blocks in Python: [(x, y, z, sx, sy, sz, rot)]."""
    key, x, y, z, rot, sc = p[:6]
    info = cat.get(key)
    if not info or info["collide"] or info.get("solids"):
        return []  # (the catalog's cut solids: check_v2's World lays them)
    want = SOLID.get(key) or SOLID.get(bases.get(key, ""))
    if not want:
        return []
    sx, sy, sz = (v * sc for v in info["size"])
    a = math.radians(rot)

    def at(lx, lz):
        return x + lx * math.cos(a) + lz * math.sin(a), z - lx * math.sin(a) + lz * math.cos(a)

    top = min(want.get("top", sy), sy)
    if "walls" in want:
        return [(*_xz(at(wx * sc, wz * sc), y + top / 2), ww * sc, top, wd * sc, rot) for wx, wz, ww, wd in want["walls"]]
    if "pole" in want:
        ax, az = info.get("anchor") or (0.0, 0.0)
        return [(*_xz(at(ax * sc, az * sc), y + top / 2), want["pole"] * sc, top, want["pole"] * sc, rot)]
    inset = want.get("box", 0) * 2
    return [(x, y + top / 2, z, max(0.2, sx - inset), top, max(0.2, sz - inset), rot)]


def _xz(p, y):
    return p[0], y, p[1]


def load_bases():
    import re

    text = open(cat_mod.PATH, encoding="utf-8").read()
    return {key: m.group(1) for key, body in cat_mod._entries(text) for m in [re.search(r'base = "(\w+)"', body)] if m}


def mesh_tris(obj):
    me = obj.data
    me.calc_loop_triangles()
    return [v.co.copy() for v in me.vertices], [tuple(t.vertices) for t in me.loop_triangles]


def _poly_dist(p, poly):
    return min(g2.dist_point_segment(p, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))


def solid_dist(s, p):
    """How far the point p (x, y, z) is from check_v2's solid s (0 inside it)."""
    x, y, z = p
    if s.kind == "cols":
        best = 1e9
        for dx in (-BACK, 0.0, BACK):
            for dz in (-BACK, 0.0, BACK):
                for lo, hi in s.spans(x + dx, z + dz):
                    d = 0.0 if lo <= y <= hi else min(abs(y - lo), abs(y - hi))
                    best = min(best, d + (0.0 if dx == 0 and dz == 0 else 0.2))
        return best
    d2 = 0.0 if g2.contains(s.poly, (x, z)) else _poly_dist((x, z), s.poly)
    if s.kind == "ramp":
        (ax, az), (bx, bz), ya, yb = s.data
        dx, dz = bx - ax, bz - az
        t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
        top = ya + (yb - ya) * t
        lo, hi = top - 1.2, top
    else:
        lo, hi = s.y0, s.y1
    dy = 0.0 if lo <= y <= hi else min(abs(y - lo), abs(y - hi))
    return math.hypot(d2, dy)


def run(venue, out_dir, reach=R):
    started = time.time()
    scene = find_defects.build(venue)
    cat = cat_mod.load()
    bases = load_bases()
    lo, hi = scene.bounds or ((-100, -10, -100), (100, 60, 100))
    data = {"bounds": {"min": list(lo), "max": list(hi)}, "colliders": [list(c) for c in scene.colliders],
            "floors": [list(f) for f in scene.floors], "ramps": scene.ramps, "props": [list(p) for p in scene.props],
            "layout": scene.layout, "propCols": propcols.for_scene(scene, cat)}
    for p in scene.props:
        for b in solid_boxes(cat, bases, p):
            data["colliders"].append([*b, True, None])
    world = check_v2.World(data, check_v2.load_catalog())
    dist = check_v2.walk(data, world, [])
    # Drawn triangles: the venue's own pieces, then each placed prop's meshes, with whose they are.
    tris = finders.Tris(scene)
    pieces = [(mat, scene.piece_src.get(id(piece), ""), getattr(piece, "ground", False))
              for mat, ps in sorted(scene.pieces.items()) for piece in ps]
    verts = [Vector(v) for v in tris.verts]
    polys = list(tris.polys)
    owner = [("map", tris.pieces[i]) for i in range(len(polys))]
    library = propcols._library()
    parts_of = {}
    for name, obj in library.items():
        if obj.get("dg_part"):
            parts_of.setdefault(obj["dg_part"], []).append(name)
    cache = {}
    for n, p in enumerate(scene.props):
        key, x, y, z, rot, sc = p[:6]
        for name in [key] + [k for k in library if k.startswith(key + "_Glow")] + parts_of.get(key, []):
            obj = library.get(name)
            if obj is None:
                continue
            if name not in cache:
                cache[name] = mesh_tris(obj)
            lv, lt = cache[name]
            m = Matrix.Translation((-x, z, y)) @ Matrix.Rotation(math.radians(rot), 4, "Z") @ Matrix.Scale(sc, 4)
            base = len(verts)
            for v in lv:
                w = m @ v
                verts.append(Vector((-w.x, w.z, w.y)))
            polys.extend(tuple(base + i for i in t) for t in lt)
            owner.extend([("prop", n)] * len(lt))
    tree = BVHTree.FromPolygons(verts, polys, epsilon=0.0)
    heights = [LOW + k * STEP_H for k in range(int((HIGH - LOW) / STEP_H) + 1)]
    ghosts = {}
    for (i, j, h) in dist:
        x, z = i * check_v2.GRID, j * check_v2.GRID
        for dy in heights:
            for loc, _normal, idx, _d in tree.find_nearest_range(Vector((x, h + dy, z)), reach):
                kind, ref = owner[idx]
                if kind == "map":
                    mat, src, ground = pieces[ref]
                    if ground and loc.y < h + 1.0:
                        continue  # (ash and snow a foot sinks into)
                    label = ("map", mat, src)
                else:
                    info = cat.get(scene.props[ref][0])
                    if info and info["collide"]:
                        continue
                    label = ("prop", scene.props[ref][0], ref)
                q = (loc.x, loc.y, loc.z)
                if any(solid_dist(s, q) < BACK for s in world.near(loc.x, loc.z)):
                    continue
                g = ghosts.setdefault(label, [0, q, set()])
                g[0] += 1
                g[2].add((i, j))
    rows = []
    for label, (count, q, cells) in ghosts.items():
        if label[0] == "map":
            rows.append({"kind": "map", "mat": label[1], "src": label[2], "hits": count, "cells": len(cells),
                         "at": [round(c, 1) for c in q]})
        else:
            p = scene.props[label[2]]
            rows.append({"kind": "prop", "key": label[1], "hits": count, "cells": len(cells),
                         "at": [round(p[1], 1), round(p[2], 1), round(p[3], 1)], "src": scene.prop_src[label[2]]})
    rows.sort(key=lambda r: -r["cells"])
    with open(os.path.join(out_dir, f"ghost_{venue}.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(rows, fh, indent=1)
    by = {}
    for r in rows:
        k = r["key"] if r["kind"] == "prop" else r["mat"] + " @ " + r["src"]
        e = by.setdefault(k, [0, 0])
        e[0] += 1
        e[1] += r["cells"]
    lines = [f"{venue}: {len(rows)} owners of something walked into, over {len(dist)} walkable spots "
             f"({time.time() - started:.0f}s)"]
    lines += [f"  {c:6d} spots {n:4d}x  {k}" for k, (n, c) in sorted(by.items(), key=lambda kv: -kv[1][1])]
    with open(os.path.join(out_dir, f"ghost_{venue}.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\n".join(lines[:40]))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = argv[argv.index("--out") + 1] if "--out" in argv else common.PREVIEWS
    reach = float(argv[argv.index("--r") + 1]) if "--r" in argv else R
    venues = [a for a in argv if a in find_defects.VENUES and a != "Sets"] or ["Lobby", "Meeting", "Agency", "Campus",
                                                                                "Tokyo"]
    os.makedirs(out_dir, exist_ok=True)
    for venue in venues:
        run(venue, out_dir, reach)


if __name__ == "__main__":
    main()
