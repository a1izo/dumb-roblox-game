"""Checks a big map scene (format 2) from its export, art/export/scenes/<Venue>.json, without
opening Studio:

  contract   stations clear with a free worker spot and a screen seen from 3 of 8 sides, sheets
             resting on something, spots standing on a floor and inside nothing (all heights)
  zones      nothing of the game's on a road, crossing, water, track, stairs or off-limits
  reach      a walk over the whole map on a 2-stud grid (a body 5.5 tall, steps up to 1.2):
             every spot reachable from the spawns, how long corner to corner takes at 16 studs/s,
             nothing walkable outside the Specter box
  light      how much of the walkable ground is lit (outdoors and indoors), and the darkest patches
  symmetry   how alike the ground floor is to its own mirror image (0 = not at all, 1 = mirrored)
  doorways   every door and gap at floor level keeps DOOR_CLEAR studs free in front of it, on both
             sides (a flag for the hand-check: it names what stands there, it never moves anything)

Every rule covers the spare spots too. Returns a list of problems and prints a report.
"""

import heapq
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from maps import geo2d as g2  # noqa: E402
from maps.layout import FORBIDDEN  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
SIDECARS = os.path.join(ROOT, "art", "export", "scenes")

WALK_SPEED = 16.0
TARGET_WALK = (30.0, 45.0)
STEP = 2.0  # a step up per 2 studs: slopes up to 45 degrees, small ledges
BODY = 5.5
GRID = 2.0
LIGHT_OUT = 0.25
LIGHT_IN = 0.4
SYMMETRY_MAX = 0.5
DOOR_CLEAR = 4.0  # the clear width every doorway keeps (or its own width, when narrower)
DOOR_DEPTH = 3.0  # how far in front of a doorway, on both sides, that width must stay clear


class Solid:
    """A turned box (colliders) or an upright triangle prism (floors) or a tilted slab (ramps)."""

    __slots__ = ("kind", "poly", "y0", "y1", "query", "data", "box")

    def __init__(self, kind, poly, y0, y1, query, data=None):
        self.kind, self.poly, self.y0, self.y1, self.query, self.data = kind, poly, y0, y1, query, data
        self.box = g2.bbox(poly)

    def top_at(self, x, z):
        """The walkable top at (x, z), or None when (x, z) is outside the footprint."""
        # A hair off the exact grid point, so a point on the seam between two slabs counts as
        # on one of them (never on neither).
        x, z = x + 0.0137, z + 0.0093
        if not (self.box[0] <= x <= self.box[2] and self.box[1] <= z <= self.box[3]):
            return None
        if not g2.contains(self.poly, (x, z)):
            return None
        if self.kind == "ramp":
            (ax, az), (bx, bz), ya, yb = self.data
            dx, dz = bx - ax, bz - az
            length2 = dx * dx + dz * dz
            t = max(0.0, min(1.0, ((x - ax) * dx + (z - az) * dz) / length2))
            return ya + (yb - ya) * t
        return self.y1

    def blocks(self, x, z, y0, y1):
        """True when the solid fills any of the height y0..y1 at (x, z)."""
        top = self.top_at(x, z)
        if top is None:
            return False
        bottom = self.y0 if self.kind != "ramp" else top - 1.2
        return top > y0 + 1e-3 and bottom < y1 - 1e-3

    def segment(self, a, b, y):
        """True when the horizontal segment a -> b at height y passes through the solid."""
        if not (self.y0 < y < self.y1) or self.kind == "ramp":
            return False
        if not g2.bbox_overlap(self.box, (min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1]))):
            return False
        if g2.contains(self.poly, a) or g2.contains(self.poly, b):
            return True
        n = len(self.poly)
        for i in range(n):
            if g2.segment_hit(a, b, self.poly[i], self.poly[(i + 1) % n]):
                return True
        return False


class World:
    CELL = 8.0

    def __init__(self, data, catalog):
        self.solids = []
        for c in data["colliders"]:
            x, y, z, sx, sy, sz, rot, query = c[:8]
            self.solids.append(Solid("box", g2.rect(x, z, sx, sz, rot), y - sy / 2, y + sy / 2, query))
        for f in data["floors"]:
            x1, z1, x2, z2, x3, z3, y, thick, look, query = f
            self.solids.append(Solid("floor", [(x1, z1), (x2, z2), (x3, z3)], y - thick, y, query))
        for r in data["ramps"]:
            (ax, az), (bx, bz) = r["a"], r["b"]
            w = r["width"]
            length = math.dist((ax, az), (bx, bz))
            dx, dz = (bx - ax) / length, (bz - az) / length
            nx, nz = dz, -dx
            poly = [(ax + nx * w / 2, az + nz * w / 2), (bx + nx * w / 2, bz + nz * w / 2),
                    (bx - nx * w / 2, bz - nz * w / 2), (ax - nx * w / 2, az - nz * w / 2)]
            self.solids.append(Solid("ramp", poly, r["y0"] - 1, r["y1"], r["query"], ((ax, az), (bx, bz), r["y0"], r["y1"])))
        for key, x, y, z, rot, sc, *_ in data["props"]:
            if key in catalog and catalog[key][2]:
                (sx, sy, sz), pivot, _ = catalog[key]
                sx, sy, sz = sx * sc, sy * sc, sz * sc
                base = y if pivot == "bottom" else y - sy / 2
                self.solids.append(Solid("box", g2.rect(x, z, sx, sz, rot), base, base + sy, True))
        self.grid = {}
        for i, s in enumerate(self.solids):
            for cell in self._cells(s.box):
                self.grid.setdefault(cell, []).append(i)

    def _cells(self, box):
        c = self.CELL
        for i in range(math.floor(box[0] / c), math.floor(box[2] / c) + 1):
            for j in range(math.floor(box[1] / c), math.floor(box[3] / c) + 1):
                yield (i, j)

    def near(self, x, z):
        return [self.solids[i] for i in self.grid.get((math.floor(x / self.CELL), math.floor(z / self.CELL)), ())]

    def along(self, a, b):
        box = (min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1]))
        seen = set()
        for cell in self._cells(box):
            for i in self.grid.get(cell, ()):
                if i not in seen:
                    seen.add(i)
                    yield self.solids[i]

    def tops(self, x, z):
        """Every walkable height at (x, z) with room for a body above it."""
        near = self.near(x, z)
        heights = sorted({round(t, 2) for s in near for t in [s.top_at(x, z)] if t is not None})
        out = []
        for h in heights:
            if not any(s.blocks(x, z, h + 0.3, h + BODY) for s in near):
                out.append(h)
        return out

    def floor_under(self, x, y, z, reach=0.6):
        best = None
        for s in self.near(x, z):
            t = s.top_at(x, z)
            if t is not None and y - reach <= t <= y + 0.35:
                best = t if best is None else max(best, t)
        return best

    def inside(self, x, y, z):
        return [s for s in self.near(x, z) if s.kind == "box" and s.blocks(x, z, y + 0.4, y + 0.6)]

    def sight(self, a, b, y):
        return not any(s.query and s.segment(a, b, y) for s in self.along(a, b))

    def open(self, a, b, y):
        """A body can pass from a to b at floor height y (nothing solid at knee and head height)."""
        for hy in (y + 1.0, y + 3.0, y + 5.0):
            if any(s.segment(a, b, hy) for s in self.along(a, b)):
                return False
        return True


def load_catalog():
    """{prop: (size, pivot, collides)} from src/shared/ModelCatalog.luau."""
    from maps import catalog

    return {k: (v["size"], v["pivot"], v["collide"]) for k, v in catalog.load().items()}


class Zones:
    CELL = 16.0

    def __init__(self, zones):
        self.zones = zones
        self.grid = {}
        for i, z in enumerate(zones):
            box = g2.bbox(z["poly"])
            for a in range(math.floor(box[0] / self.CELL), math.floor(box[2] / self.CELL) + 1):
                for b in range(math.floor(box[1] / self.CELL), math.floor(box[3] / self.CELL) + 1):
                    self.grid.setdefault((a, b), []).append(i)

    def kinds(self, x, y, z):
        out = []
        for i in self.grid.get((math.floor(x / self.CELL), math.floor(z / self.CELL)), ()):
            zone = self.zones[i]
            lo, hi = min(zone["y0"], zone["y1"]), max(zone["y0"], zone["y1"])
            if lo - 1.5 <= y <= hi + 1.5 and g2.contains(zone["poly"], (x, z)):
                out.append(zone["kind"])
        return out


def rotate(rot, v):
    a = math.radians(rot)
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c + v[1] * s, -v[0] * s + v[1] * c)


def contract(data, world, zones, problems):
    from maps import catalog

    cat = catalog.load()
    L, S = data["layout"], data["spare"]
    everything = [(False, L), (True, S)]
    counts = {k: len(L[k]) for k in ("stations", "spawns", "sheets", "hoods", "areas")}
    print("  layout:", counts, "spare:", {k: len(v) for k, v in S.items()})
    for spare, group in everything:
        tag = " (spare)" if spare else ""
        for st in group["stations"]:
            x, y, z, rot = st["x"], st.get("y", 0.0), st["z"], st["rot"]
            name = st["name"] + tag
            for dx in (-2.3, 0, 2.3):
                for dz in (-1.0, 0, 1.0):
                    px, pz = rotate(rot, (dx, dz))
                    hit = [s for s in world.near(x + px, z + pz) if s.kind == "box" and s.blocks(x + px, z + pz, y + 0.5, y + 2.8)]
                    if hit:
                        problems.append(f"{name}: desk overlaps something at y {hit[0].y0:.1f}..{hit[0].y1:.1f}")
                        break
                else:
                    continue
                break
            wx, wz = rotate(rot, (0, -2.6))
            if world.inside(x + wx, y + 2, z + wz):
                problems.append(f"{name}: the worker spot is blocked")
            if world.floor_under(x + wx, y, z + wz) is None:
                problems.append(f"{name}: no floor where the worker stands")
            # The game's screen: where the station's look puts it (its slot), else the console's.
            slot = (cat.get(st.get("prop") or "") or {}).get("screen")
            (lx, ly, lz) = slot["at"] if slot else (0.0, 5.4, 0.8)
            sx, sz = rotate(rot, (lx, lz))
            target = (x + sx, z + sz)
            seen = 0
            for k in range(8):
                a = k / 8 * math.tau
                src = (target[0] + math.sin(a) * 9, target[1] + math.cos(a) * 9)
                end = (target[0] + (src[0] - target[0]) * 0.18, target[1] + (src[1] - target[1]) * 0.18)
                if world.sight(src, end, y + ly):
                    seen += 1
            if seen < 3:
                problems.append(f"{name}: screen seen from only {seen} of 8 sides")
            check_zone(zones, name, x + wx, y, z + wz, problems)
        for i, sh in enumerate(group["sheets"]):
            top = world.floor_under(sh["x"], sh["y"], sh["z"], 1.0)
            if top is None:
                problems.append(f"sheet {i + 1}{tag}: nothing under it")
            elif sh["y"] - top > 0.3:
                problems.append(f"sheet {i + 1}{tag}: floats {sh['y'] - top:.2f} above its surface")
        for kind in ("spawns", "hoods"):
            for it in group[kind]:
                base = it.get("y", 0.0)
                if kind == "hoods":
                    base -= 0.6
                label = f"{kind[:-1]} at {it['x']:.0f}, {base:.0f}, {it['z']:.0f}{tag}"
                if world.inside(it["x"], base + 1, it["z"]):
                    problems.append(f"{label}: inside something")
                if world.floor_under(it["x"], base, it["z"]) is None:
                    problems.append(f"{label}: no floor under it")
                check_zone(zones, label, it["x"], base, it["z"], problems)
        for area in group["areas"]:
            for m in area.get("marks", []):
                label = f"{area['name']} {m['kind']} mark{tag}"
                if world.inside(m["x"], m["y"] + 1, m["z"]):
                    problems.append(f"{label}: inside something")
                if world.floor_under(m["x"], m["y"], m["z"]) is None:
                    problems.append(f"{label}: no floor under it")
                check_zone(zones, label, m["x"], m["y"], m["z"], problems)
            if not area.get("marks") and not spare:
                problems.append(f"{area['name']}: no intro marks")
    tb = L.get("tipBox")
    if tb:
        if world.floor_under(tb["x"], tb.get("y", 0), tb["z"]) is None:
            problems.append("tip box: no floor under it")
        check_zone(zones, "tip box", tb["x"], tb.get("y", 0), tb["z"], problems)


def check_zone(zones, label, x, y, z, problems):
    kinds = zones.kinds(x, y, z)
    if not kinds:
        problems.append(f"{label}: on no zone (unknown ground)")
    bad = [k for k in kinds if k in FORBIDDEN or k == "offlimits"]
    if bad:
        problems.append(f"{label}: stands on {', '.join(sorted(set(bad)))}")


def walk(data, world, problems):
    """Builds the walk graph from the spawns and returns (reached nodes, distance fn)."""
    (x0, y0b, z0), (x1, y1b, z1) = data["bounds"]["min"], data["bounds"]["max"]
    L = data["layout"]
    starts = []

    def key(x, z):
        return (round(x / GRID), round(z / GRID))

    column_cache = {}

    def column(i, j):
        if (i, j) not in column_cache:
            column_cache[(i, j)] = world.tops(i * GRID, j * GRID)
        return column_cache[(i, j)]

    for sp in L["spawns"]:
        i, j = key(sp["x"], sp["z"])
        hs = column(i, j)
        best = min(hs, key=lambda h: abs(h - sp.get("y", 0))) if hs else None
        if best is not None:
            starts.append((i, j, best))
    dist = {}
    heap = [(0.0, s) for s in starts]
    for _, s in heap:
        dist[s] = 0.0
    heapq.heapify(heap)
    outside = 0
    outside_at = []
    while heap:
        d, node = heapq.heappop(heap)
        if d > dist.get(node, 1e18):
            continue
        i, j, h = node
        if not (x0 <= i * GRID <= x1 and z0 <= j * GRID <= z1 and y0b <= h <= y1b):
            outside += 1
            outside_at.append((i * GRID, h, j * GRID))
            continue
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            ni, nj = i + di, j + dj
            for nh in column(ni, nj):
                if abs(nh - h) > STEP:
                    continue
                a, b = (i * GRID, j * GRID), (ni * GRID, nj * GRID)
                if not world.open(a, b, max(h, nh)):
                    continue
                if di and dj and not (world.open(a, (ni * GRID, j * GRID), max(h, nh)) and world.open(a, (i * GRID, nj * GRID), max(h, nh))):
                    continue
                nd = d + GRID * (1.4142 if di and dj else 1.0)
                nn = (ni, nj, nh)
                if nd < dist.get(nn, 1e18):
                    dist[nn] = nd
                    heapq.heappush(heap, (nd, nn))
    if outside:
        problems.append(f"reach: {outside} walkable spots lie outside the Specter box, e.g. "
                        + ", ".join(f"({x:.0f}, {y:.0f}, {z:.0f})" for x, y, z in outside_at[:3]))
    return dist


def reach_report(data, dist, problems):
    by_col = {}
    for (i, j, h), d in dist.items():
        by_col.setdefault((i, j), []).append((h, d))

    def at(x, y, z, r=2):
        ci, cj = round(x / GRID), round(z / GRID)
        best = None
        for di in range(-r, r + 1):
            for dj in range(-r, r + 1):
                for h, d in by_col.get((ci + di, cj + dj), ()):
                    if abs(h - y) <= 1.6 and (best is None or d < best):
                        best = d
        return best

    L, S = data["layout"], data["spare"]
    for spare, group in ((False, L), (True, S)):
        tag = " (spare)" if spare else ""
        for st in group["stations"]:
            wx, wz = rotate(st["rot"], (0, -2.6))
            if at(st["x"] + wx, st.get("y", 0), st["z"] + wz) is None:
                problems.append(f"{st['name']}{tag}: cannot be reached from the spawns")
        for kind in ("sheets", "hoods"):
            for it in group[kind]:
                y = it["y"] - (2.8 if kind == "sheets" else 0.6)
                r = 3 if kind == "sheets" else 2
                if at(it["x"], y, it["z"], r) is None:
                    problems.append(f"{kind[:-1]} at {it['x']:.0f}, {it['z']:.0f}{tag}: cannot be reached")
        for area in group["areas"]:
            if at(area["x"], area["y"], area["z"], 4) is None:
                problems.append(f"{area['name']}{tag}: cannot be reached")
    # Corner to corner: the reachable ground spots nearest each corner, walked between.
    (x0, _, z0), (x1, _, z1) = data["bounds"]["min"], data["bounds"]["max"]
    nodes = list(dist.items())
    corners = [(x0, z0), (x1, z1), (x1, z0), (x0, z1)]
    picks = []
    for cx, cz in corners:
        best = min(nodes, key=lambda it: (it[0][0] * GRID - cx) ** 2 + (it[0][1] * GRID - cz) ** 2)
        picks.append(best[0])
    return picks, len(dist)


def nearest_node(dist, x, y, z):
    """The reached walk node closest to (x, y, z), preferring the floor at height y."""
    return min(dist, key=lambda n: (n[0] * GRID - x) ** 2 + (n[1] * GRID - z) ** 2 + 4 * (n[2] - y) ** 2)


def corner_times(data, world, picks, problems, dist=None):
    """Walk times between opposite corners (a fresh search from each corner). A venue can name
    its own pairs of far points (checks.corners: [[(x, y, z), (x, y, z)], ...]), such as the
    corners of two floors, and its own target (checks.walk: (low, high) seconds)."""
    checks = data.get("checks") or {}
    target = tuple(checks.get("walk") or TARGET_WALK)
    pairs = [(picks[0], picks[1]), (picks[2], picks[3])]
    if checks.get("corners") and dist:
        pairs = [(nearest_node(dist, *a), nearest_node(dist, *b)) for a, b in checks["corners"]]
    times = []
    for a, b in pairs:
        sub = {"layout": {"spawns": [{"x": a[0] * GRID, "z": a[1] * GRID, "y": a[2]}]}, "bounds": data["bounds"]}
        dist = walk(sub, world, [])
        d = min((v for (i, j, h), v in dist.items() if abs(i - b[0]) <= 1 and abs(j - b[1]) <= 1 and abs(h - b[2]) < 3),
                default=None)
        if d is not None:
            times.append(d / WALK_SPEED)
    if times:
        worst = max(times)
        print(f"  walk corner to corner: {', '.join(f'{t:.0f} s' for t in times)}")
        slack = 0 if checks.get("walk") else 20
        if not target[0] <= worst <= target[1] + slack:
            problems.append(f"walk: corner to corner takes {worst:.0f} s (aim for {target[0]:.0f}-{target[1]:.0f} s)")
    return times


def light(data, world, zones, dist, problems):
    from maps import catalog

    lights = list(data["lights"])
    # The lights the props carry (street lights, lanterns, vending machines...).
    cat = catalog.load()
    for key, x, y, z, rot, sc, *rest in data["props"]:
        if rest and rest[0] == "dark":
            continue
        a = math.radians(rot)
        for li in cat.get(key, {}).get("lights", []):
            lx, ly, lz = li["at"]
            wx = x + (lx * math.cos(a) + lz * math.sin(a)) * sc
            wz = z + (-lx * math.sin(a) + lz * math.cos(a)) * sc
            lights.append({"pos": (wx, y + ly * sc, wz), "range": li["range"], "brightness": li["brightness"]})
    print(f"  lights: {len(data['lights'])} in the scene, {len(lights) - len(data['lights'])} carried by props")
    grid = {}
    for i, li in enumerate(lights):
        x, y, z = li["pos"]
        r = li["range"]
        for a in range(math.floor((x - r) / 32), math.floor((x + r) / 32) + 1):
            for b in range(math.floor((z - r) / 32), math.floor((z + r) / 32) + 1):
                grid.setdefault((a, b), []).append(i)
    samples = {}
    for (i, j, h), d in dist.items():
        if i % 2 == 0 and j % 2 == 0:
            samples[(i, j, h)] = True
    dark_out = dark_in = total_out = total_in = 0
    dark_spots = []
    levels = {}
    for (i, j, h) in samples:
        x, z = i * GRID, j * GRID
        y = h + 3.0
        level = 0.0
        for li_index in grid.get((math.floor(x / 32), math.floor(z / 32)), ()):
            li = lights[li_index]
            lx, ly, lz = li["pos"]
            dd = math.dist((x, y, z), (lx, ly, lz))
            if dd >= li["range"]:
                continue
            if abs(ly - y) < 6 and not world.sight((lx, lz), (x, z), (ly + y) / 2):
                continue
            if ly - y >= 6:
                # A lamp above: blocked when a floor lies between.
                if any(s.kind in ("box", "floor") and s.query is not None and s.y0 > y and s.y1 < ly and s.top_at(x, z) is not None
                       for s in world.near(x, z)):
                    continue
            level += li["brightness"] * (1 - dd / li["range"]) ** 2
        kinds = zones.kinds(x, h, z)
        indoor = "interior" in kinds or "platform" in kinds
        key2 = (i // 2, j // 2)
        need = LIGHT_IN if indoor else LIGHT_OUT
        if key2 not in levels or levels[key2][1] > level / need:
            levels[key2] = (h, level / need)
        if indoor:
            total_in += 1
            if level < LIGHT_IN:
                dark_in += 1
                dark_spots.append((x, h, z))
        else:
            total_out += 1
            if level < LIGHT_OUT:
                dark_out += 1
                dark_spots.append((x, h, z))
    write_lightmap(data, levels)
    lit_out = 100 * (1 - dark_out / max(1, total_out))
    lit_in = 100 * (1 - dark_in / max(1, total_in))
    print(f"  light: outdoors {lit_out:.0f}% lit ({total_out} samples), indoors {lit_in:.0f}% lit ({total_in} samples)")
    # Group dark samples into patches (4-stud samples, 8-connected).
    seen = set()
    patches = []
    index = {(round(x / 4), round(z / 4)): (x, h, z) for x, h, z in dark_spots}
    for key0 in index:
        if key0 in seen:
            continue
        stack, patch = [key0], []
        seen.add(key0)
        while stack:
            k = stack.pop()
            patch.append(index[k])
            for dx in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    n = (k[0] + dx, k[1] + dz)
                    if n in index and n not in seen:
                        seen.add(n)
                        stack.append(n)
        if len(patch) * 16 > 64:
            patches.append(patch)
    patches.sort(key=len, reverse=True)
    for patch in patches[:12]:
        cx = sum(p[0] for p in patch) / len(patch)
        cz = sum(p[2] for p in patch) / len(patch)
        print(f"  light: dark patch of {len(patch) * 16} sq studs around {cx:.0f}, {patch[0][1]:.0f}, {cz:.0f}")
    if len(patches) > 12:
        print(f"  light: {len(patches) - 12} more dark patches")
    return lit_out, lit_in


def write_lightmap(data, levels):
    """art/export/previews/light_<Venue>.png: every 4-stud walkable sample from above (the
    darkest level where floors stack): red where it is too dark, then yellow to white by how
    well lit it is. North is up."""
    import struct
    import zlib

    (x0, _, z0), (x1, _, z1) = data["bounds"]["min"], data["bounds"]["max"]
    scale = 3
    w, h = int((x1 - x0) / 4) + 1, int((z1 - z0) / 4) + 1
    rows = []
    grid = {}
    for (ci, cj), (_, ratio) in levels.items():
        grid[(ci, cj)] = ratio
    for r in range(h * scale):
        row = bytearray([0])
        for c in range(w * scale):
            ratio = grid.get((round((x0 + (c // scale) * 4) / 4), round((z0 + (r // scale) * 4) / 4)))
            if ratio is None:
                row += bytes((18, 18, 22))
            elif ratio < 1:
                v = int(60 + 120 * ratio)
                row += bytes((v + 40, 20, 20))
            else:
                v = min(1.0, (ratio - 1) / 3)
                row += bytes((200 + int(55 * v), 170 + int(85 * v), 60 + int(195 * v)))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    png = bytes([137, 80, 78, 71, 13, 10, 26, 10]) + chunk(b"IHDR", struct.pack(">IIBBBBB", w * scale, h * scale, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path = os.path.join(ROOT, "art", "export", "previews", f"light_{data['venue']}.png")
    with open(path, "wb") as f:
        f.write(png)
    print("  light map:", path)


def symmetry(data, dist, problems):
    """A venue can set its own limit (checks.symmetry), or None where being its own mirror image is
    the point (a square room round a round table)."""
    checks = data.get("checks") or {}
    limit = checks.get("symmetry", SYMMETRY_MAX)
    if limit is None:
        print("  symmetry: not checked for this venue (its CHECKS)")
        return 0.0
    (x0, _, z0), (x1, _, z1) = data["bounds"]["min"], data["bounds"]["max"]
    cells = {(i, j) for (i, j, h) in dist if abs(h) < 3}
    if not cells:
        return 0.0
    cx, cz = (x0 + x1) / 2 / GRID, (z0 + z1) / 2 / GRID
    total = ((x1 - x0) / GRID) * ((z1 - z0) / GRID)
    p = len(cells) / total
    scores = []
    for flip in ("x", "z"):
        hits = 0
        for i, j in cells:
            m = (round(2 * cx - i), j) if flip == "x" else (i, round(2 * cz - j))
            if m in cells:
                hits += 1
        overlap = hits / len(cells)
        scores.append((overlap - p) / max(1e-6, 1 - p))
    worst = max(scores)
    print(f"  symmetry: mirror left-right {scores[0]:.2f}, top-bottom {scores[1]:.2f} (walkable ground {p * 100:.0f}%)")
    if worst > limit:
        problems.append(f"symmetry: the ground floor is too much like its mirror image ({worst:.2f})")
    return worst


def ramps(data, problems):
    for r in data["ramps"]:
        if r["pitch"] > 40.5:
            problems.append(f"ramp at {r['a']}: {r['pitch']:.0f} degrees is too steep")
        if r["width"] < 3.5:
            problems.append(f"ramp at {r['a']}: {r['width']:.1f} wide is too narrow")


# Props that stand on the floor and may overlap by design: a bike in its rack, tape strung
# across a fence or a barricade.
MAY_TOUCH = {frozenset(p) for p in (("Bicycle", "BikeRack"), ("PoliceTape", "SiteFence"),
                                    ("PoliceTape", "Barricade"), ("PoliceTape", "PoliceCar"),
                                    ("PoliceTape", "TrafficCone"), ("BarStool", "ShopCounter"),
                                    ("BankerLamp", "Sideboard"))}
TOUCH = 0.2  # how far two things may press into each other (a bin against a wall)
# Props that meet the ground only at a pole or a trunk (their arms and canopies may reach over
# other things): the size of that foot, at the prop's anchor.
FEET = {"StreetLightTokyo": 1.2, "TrafficSignal": 1.2, "PedestrianSignal": 1.0, "UtilityPole": 1.4,
        "RoadSign": 0.8, "BusStopSign": 0.8, "TaxiRankSign": 0.8, "Tree": 2.0, "TreeSakura": 2.0,
        "TreeZelkova": 2.0, "GinkgoBare": 1.9, "PineYukizuri": 1.7, "CampusLamp": 1.2,
        # A tent stands on four thin legs round what stands under it (the map gives the legs colliders).
        "EventTent": 0.5,
        # The Grey Realm's dead trees and lantern posts.
        "DeadTree": 2.0, "DeadTreeGnarled": 2.0, "WitheredAppleTree": 2.0, "LanternPost": 0.6}
# Props that are walls themselves (the barriers across the streets that leave the map): they may
# meet the buildings' walls.
WALLS = {"SiteFence", "PoliceTape", "Barricade"}


def footprints(data, cat):
    """(label, key, footprint, y0, y1) of every prop that stands on a floor, and of every
    station's look (placed by its anchor on the station's origin), shrunk by TOUCH."""
    out = []
    for key, x, y, z, rot, sc, *_ in data["props"]:
        info = cat.get(key)
        if not info or info["pivot"] != "bottom":
            continue
        sx, sy, sz = (v * sc for v in info["size"])
        if key in FEET:
            ax, az = info["anchor"]
            px, pz = rotate(rot, (ax * sc, az * sc))
            foot = FEET[key]
            out.append((f"{key} at {x:.0f}, {z:.0f}", key, g2.rect(x + px, z + pz, foot, foot, rot), y, y + sy))
            continue
        out.append((f"{key} at {x:.0f}, {z:.0f}", key, g2.rect(x, z, sx - 2 * TOUCH, sz - 2 * TOUCH, rot), y, y + sy))
    for group in (data["layout"], data["spare"]):
        for st in group["stations"]:
            info = cat.get(st.get("prop") or "")
            if not info:
                continue
            ax, az = info["anchor"]
            px, pz = rotate(st["rot"], (-ax, -az))
            sx, sy, sz = info["size"]
            y = st.get("y", 0.0)
            out.append((f"{st['name']}'s look", st["prop"],
                        g2.rect(st["x"] + px, st["z"] + pz, sx - 2 * TOUCH, sz - 2 * TOUCH, st["rot"]), y, y + sy))
    return out


def overlaps(data, problems):
    """Nothing that stands on a floor may stand inside another such thing or inside a wall: the
    taxis at the rank, the bus by the station, a desk's back in its wall. A collider wholly inside
    a prop's footprint is that prop's own (a street light's pole, a bus shelter's back)."""
    from maps import catalog

    cat = catalog.load()
    items = footprints(data, cat)
    cell = 8.0

    def cells(box):
        for i in range(math.floor(box[0] / cell), math.floor(box[2] / cell) + 1):
            for j in range(math.floor(box[1] / cell), math.floor(box[3] / cell) + 1):
                yield i, j

    grid = {}
    for n, item in enumerate(items):
        for c in cells(g2.bbox(item[2])):
            grid.setdefault(c, []).append(n)
    found = []
    seen = set()
    for n, (label, key, poly, y0, y1) in enumerate(items):
        for c in cells(g2.bbox(poly)):
            for m in grid.get(c, ()):
                if m <= n or (n, m) in seen:
                    continue
                seen.add((n, m))
                label2, key2, poly2, v0, v1 = items[m]
                if min(y1, v1) - max(y0, v0) < 0.3 or frozenset((key, key2)) in MAY_TOUCH:
                    continue
                if not g2.bbox_overlap(g2.bbox(poly), g2.bbox(poly2)):
                    continue
                if abs(g2.area(g2.intersect(poly, poly2) or [(0, 0)] * 3)) > 0.05:
                    found.append(f"{label} overlaps {label2}")
    walls = {}
    for k, c in enumerate(data["colliders"]):
        x, y, z, sx, sy, sz, rot = c[:7]
        poly = g2.rect(x, z, sx, sz, rot)
        for cc in cells(g2.bbox(poly)):
            walls.setdefault(cc, []).append((poly, y - sy / 2, y + sy / 2))
    for label, key, poly, y0, y1 in items:
        if key in WALLS:
            continue
        grown = g2.rect(*_rect_of(poly, 0.5 + TOUCH))
        hit = None
        for c in cells(g2.bbox(poly)):
            for wpoly, w0, w1 in walls.get(c, ()):
                if w1 <= y0 + 0.3 or w0 >= y1 - 0.3:
                    continue
                if not g2.bbox_overlap(g2.bbox(poly), g2.bbox(wpoly)):
                    continue
                if all(g2.contains(grown, p) for p in wpoly):
                    continue  # its own collider
                if abs(g2.area(g2.intersect(wpoly, poly) or [(0, 0)] * 3)) > 0.05:
                    hit = g2.centroid(poly)
                    break
            if hit:
                break
        if hit:
            found.append(f"{label} stands in a wall or collider")
    problems.extend(found)


def doorways(data, problems):
    """Every door and gap at floor level (kit.opening records them) keeps DOOR_CLEAR studs, or its
    own width when narrower, free for DOOR_DEPTH studs in front of it on both sides: no prop,
    station or collider in the way. A row wholly filled by walls ends that side (a door facing a
    wall across a corridor). Names what stands in the way; never moves anything."""
    from maps import catalog

    cat = catalog.load()
    src = data.get("propSrc") or []
    blockers = []  # (label, poly, y0, y1, is_wall)
    for k, c in enumerate(data["colliders"]):
        x, y, z, sx, sy, sz, rot = c[:7]
        blockers.append((f"collider {sx:.1f}x{sz:.1f} at {x:.1f}, {z:.1f}", g2.rect(x, z, sx, sz, rot), y - sy / 2,
                         y + sy / 2, True))
    for n, (key, x, y, z, rot, sc, *_) in enumerate(data["props"]):
        info = cat.get(key)
        if not info or not info.get("collide", True):
            continue
        sx, sy, sz = (v * sc for v in info["size"])
        base = y if info["pivot"] == "bottom" else y - sy / 2
        where = f" ({src[n]})" if n < len(src) and src[n] else ""
        blockers.append((f"{key} at {x:.1f}, {z:.1f}{where}", g2.rect(x, z, sx, sz, rot), base, base + sy, False))
    for group in (data["layout"], data["spare"]):
        for st in group["stations"]:
            info = cat.get(st.get("prop") or "")
            if not info:
                continue
            ax, az = info["anchor"]
            px, pz = rotate(st["rot"], (-ax, -az))
            sx, sy, sz = info["size"]
            y = st.get("y", 0.0)
            blockers.append((f"station {st['name']}", g2.rect(st["x"] + px, st["z"] + pz, sx, sz, st["rot"]), y,
                             y + sy, False))
    cell = 8.0
    grid = {}
    for i, b in enumerate(blockers):
        box = g2.bbox(b[1])
        for ci in range(math.floor(box[0] / cell), math.floor(box[2] / cell) + 1):
            for cj in range(math.floor(box[1] / cell), math.floor(box[3] / cell) + 1):
                grid.setdefault((ci, cj), []).append(i)

    def hits(px, pz, y):
        out = []
        for i in grid.get((math.floor(px / cell), math.floor(pz / cell)), ()):
            label, poly, y0, y1, wall = blockers[i]
            if y1 > y + 0.5 and y0 < y + 5.0 and g2.contains(poly, (px, pz)):
                out.append(i)
        return out

    flagged = 0
    for x, y, z, w, rot, thick, kind in data.get("openings", []):
        r = math.radians(rot)
        t = (math.cos(r), -math.sin(r))
        nrm = (t[1], -t[0])
        want = min(DOOR_CLEAR, w - 0.3)
        us = [-w / 2 + 0.15 + k * 0.2 for k in range(int((w - 0.3) / 0.2) + 1)]
        worst, names = w, set()
        for side in (1, -1):
            d = thick / 2 + 0.4
            while d <= thick / 2 + DOOR_DEPTH + 1e-6:
                row = []
                for u in us:
                    px = x + t[0] * u + nrm[0] * side * d
                    pz = z + t[1] * u + nrm[1] * side * d
                    row.append(hits(px, pz, y))
                if all(row) and all(blockers[i][4] for h in row for i in h):
                    break  # a wall across the whole way: this side ends here
                run = best = 0
                for h in row:
                    run = 0 if h else run + 1
                    best = max(best, run)
                clear = best * 0.2 + 0.1 if best else 0.0
                if clear < want - 0.01:
                    for h in row:
                        for i in h:
                            names.add(blockers[i][0])
                worst = min(worst, clear)
                d += 0.4
        if worst < want - 0.01:
            flagged += 1
            what = "; ".join(sorted(names)) or "?"
            problems.append(f"doorway ({kind} {w:.1f} wide) at {x:.1f}, {y:.1f}, {z:.1f}: {worst:.1f} clear - {what}")
    print(f"  doorways: {len(data.get('openings', []))} checked, {flagged} crowded")


def crowd_and_traffic(data, world, zones, problems):
    """Tokyo's crowd walks on floors, through open ground, never on a road but at a crossing, never
    near a station's worker or a spawn; its posts stand on floors; the cars' lanes run on roads and
    crossings and stop before the crossing."""
    crowd = data.get("crowd") or {}
    nodes = crowd.get("nodes") or []
    if not nodes:
        return
    keep_clear = []
    for group in (data["layout"], data["spare"]):
        keep_clear += [(st["x"], st["z"], 10.0, "station " + st["name"]) for st in group["stations"]]
        keep_clear += [(sp["x"], sp["z"], 4.0, "a spawn") for sp in group["spawns"]]
    for i, nd in enumerate(nodes):
        label = f"crowd node {i + 1} at {nd['x']:.0f}, {nd['z']:.0f}"
        if world.floor_under(nd["x"], nd["y"], nd["z"], reach=1.0) is None:
            problems.append(f"{label}: no floor under it")
        if world.inside(nd["x"], nd["y"], nd["z"]):
            problems.append(f"{label}: inside something")
        for x, z, r, what in keep_clear:
            if math.dist((x, z), (nd["x"], nd["z"])) < r:
                problems.append(f"{label}: within {r:.0f} of {what}")
    for link in crowd.get("links") or []:
        a, b = nodes[link["a"] - 1], nodes[link["b"] - 1]
        mid = ((a["x"] + b["x"]) / 2, (a["y"] + b["y"]) / 2, (a["z"] + b["z"]) / 2)
        kinds = zones.kinds(*mid)
        label = f"crowd link {link['a']}-{link['b']}"
        if link["kind"] == "crossing":
            if "crossing" not in kinds:
                problems.append(f"{label}: a crossing link off the crossing ({kinds})")
        else:
            if not world.open((a["x"], a["z"]), (b["x"], b["z"]), a["y"]):
                problems.append(f"{label}: something solid in the way")
            if set(kinds) & {"road", "crossing", "water", "track"}:
                problems.append(f"{label}: over {sorted(set(kinds))}")
    for post in crowd.get("posts") or []:
        if world.floor_under(post["x"], post["y"], post["z"], reach=1.0) is None or world.inside(post["x"], post["y"], post["z"]):
            problems.append(f"crowd post at {post['x']:.0f}, {post['z']:.0f}: not standing free on a floor")
    for k, lane in enumerate((data.get("traffic") or {}).get("lanes") or []):
        pts = lane["points"]
        for x, z in pts:
            kinds = zones.kinds(x, 0.0, z)
            if not set(kinds) & {"road", "crossing"}:
                problems.append(f"lane {k + 1}: point {x:.0f}, {z:.0f} off the road ({kinds})")
        # The stop line: the point `stop` studs along the lane.
        left, at = lane["stop"], pts[0]
        for p, q in zip(pts, pts[1:]):
            seg = math.dist(p, q)
            if left <= seg:
                f = left / seg if seg else 0
                at = (p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f)
                break
            left -= seg
        if "crossing" in zones.kinds(at[0], 0.0, at[1]):
            problems.append(f"lane {k + 1}: its stop line is on the crossing")
    print(f"  crowd: {len(nodes)} nodes, {len(crowd.get('links') or [])} links, {len(crowd.get('posts') or [])} posts; "
          f"{len((data.get('traffic') or {}).get('lanes') or [])} lanes")


def _rect_of(poly, grow):
    """(cx, cz, w, d, rot) of a rectangle from g2.rect, grown by `grow` on every side."""
    (x0, z0), (x1, z1), (x2, z2), _ = poly
    w = math.dist((x0, z0), (x1, z1))
    d = math.dist((x1, z1), (x2, z2))
    cx, cz = (x0 + x2) / 2, (z0 + z2) / 2
    rot = math.degrees(math.atan2(-(z1 - z0), x1 - x0))
    return cx, cz, w + 2 * grow, d + 2 * grow, rot


def check(venue, full=True):
    path = os.path.join(SIDECARS, venue + ".json")
    if not os.path.exists(path):
        return [f"{venue}: no export yet (run run_maps.py -- {venue} --export)"]
    data = json.load(open(path, encoding="utf-8"))
    world = World(data, load_catalog())
    zones = Zones(data["zones"])
    problems = []
    print(f"{venue}: {len(world.solids)} solids, {len(data['zones'])} zones, {len(data['lights'])} lights")
    contract(data, world, zones, problems)
    ramps(data, problems)
    overlaps(data, problems)
    doorways(data, problems)
    crowd_and_traffic(data, world, zones, problems)
    if full:
        dist = walk(data, world, problems)
        picks, reach_count = reach_report(data, dist, problems)
        print(f"  reach: {reach_count} walkable spots reached from the spawns")
        corner_times(data, world, picks, problems, dist)
        light(data, world, zones, dist, problems)
        symmetry(data, dist, problems)
    return problems


if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if not a.startswith("--")] or ["Tokyo"]
    total = 0
    for venue in names:
        found = check(venue, "--quick" not in sys.argv)
        total += len(found)
        print(f"{venue}: {'ok' if not found else str(len(found)) + ' problem(s)'}")
        for p in found:
            print("   -", p)
    sys.exit(1 if total else 0)
