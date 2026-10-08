"""Checks a venue's dressing (background Blender): props that go into walls or into each other, and props
that float with nothing under them.

    blender -b --factory-startup --python art/scripts/check_sets.py -- Sets [--region x0,z0,x1,z1]

Props are taken as their catalog boxes (ModelCatalog.luau sizes, scaled, turned), the walls and solid
dressing as the scene's colliders. Overlaps under 0.06 studs are let through (touching is fine)."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import common  # noqa: E402
import rbxsim  # noqa: E402

TOL = 0.06
CATALOG = os.path.join(common.ROOT, "src", "shared", "ModelCatalog.luau")


def corners(cx, cz, hx, hz, rot):
    a = math.radians(rot)
    c, s = math.cos(a), math.sin(a)
    # ry(rot): x' = x cos + z sin, z' = -x sin + z cos
    return [(cx + x * c + z * s, cz - x * s + z * c) for x, z in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz))]


def axes(pts):
    out = []
    for i in range(2):
        (x0, z0), (x1, z1) = pts[i], pts[i + 1]
        length = math.hypot(x1 - x0, z1 - z0) or 1.0
        out.append(((x1 - x0) / length, (z1 - z0) / length))
    return out


def overlap2d(a, b):
    """Penetration depth of two convex quads (0 when apart)."""
    depth = float("inf")
    for ax, az in axes(a) + axes(b):
        pa = [x * ax + z * az for x, z in a]
        pb = [x * ax + z * az for x, z in b]
        d = min(max(pa), max(pb)) - max(min(pa), min(pb))
        if d <= 0:
            return 0.0
        depth = min(depth, d)
    return depth


def boxes(scene, catalog):
    out = []
    for i, (key, x, y, z, rot, scale, _) in enumerate(scene.props):
        info = catalog.get(key)
        if not info:
            continue
        sx, sy, sz = (v * scale for v in info["size"])
        y0 = y if info.get("pivot", "bottom") == "bottom" else y - sy / 2
        out.append(("prop", f"{key} ({scene.prop_src[i]})", corners(x, z, sx / 2, sz / 2, rot), y0, y0 + sy))
    for x, y, z, sx, sy, sz, rot, _query, _look in scene.colliders:
        out.append(("solid", f"solid {sx:g}x{sy:g}x{sz:g} at ({x:.1f}, {y:.1f}, {z:.1f})",
                    corners(x, z, sx / 2, sz / 2, rot), y - sy / 2, y + sy / 2))
    return out


def check(scene, region=None):
    catalog = rbxsim.read_luau_table(CATALOG)
    items = boxes(scene, catalog)
    if region:
        x0, z0, x1, z1 = region
        items = [it for it in items if any(x0 <= x <= x1 and z0 <= z <= z1 for x, z in it[2])]
    problems = []
    props = [it for it in items if it[0] == "prop"]
    for i, a in enumerate(props):
        # into a wall or other solid, or into another prop
        for b in items:
            if b is a or (b[0] == "prop" and items.index(b) <= items.index(a)):
                continue
            dy = min(a[4], b[4]) - max(a[3], b[3])
            if dy <= TOL:
                continue
            d = overlap2d(a[2], b[2])
            if d > TOL:
                problems.append(f"overlap {d:.2f}: {a[1]}  <->  {b[1]}")
        # floating: nothing under it
        if a[3] > 0.05:
            held = False
            for b in items:
                if b is a or abs(b[4] - a[3]) > 0.08:
                    continue
                if overlap2d(a[2], b[2]) > 0.0:
                    held = True
                    break
            if not held:
                problems.append(f"floating at y {a[3]:.2f}: {a[1]}")
    return problems


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    import run_maps
    from maps import matlib, mesher

    common.clear_scene()
    mesher.use_images(matlib.make_textures())
    region = None
    if "--region" in argv:
        region = tuple(float(v) for v in argv[argv.index("--region") + 1].split(","))
    for name in [a for a in argv if not a.startswith("--") and "," not in a] or ["Sets"]:
        scene, _, _ = run_maps.build_venue(name)
        problems = check(scene, region)
        for line in problems:
            print("[sets]", name, line)
        print(f"[sets] {name}: {len(problems)} problems")


if __name__ == "__main__":
    main()
