"""Checks the map scenes against each map's gameplay layout without opening Studio:

    python art/scripts/maps/contract_check.py

Uses the colliders and prop placements in src/server/Maps/Scenes/<Venue>.luau (props as boxes
from ModelCatalog) and the layout() tables in the map modules, and reports:
  - station desks that overlap anything, or whose worker spot is blocked
  - station screens seen from fewer than 3 of 8 points around them (like MapContract)
  - paper sheets with nothing under them
  - spawns, hoods and drop points inside something
"""

import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from rbxsim import read_luau_table  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
# The maps still laid out by their Luau module (the big maps made in Blender are checked by check_v2.py).
MAPS = {"Campus": "UniversityCampus"}


def luau_return(path, anchor=None):
    text = open(path, encoding="utf-8").read()
    if anchor:
        text = text[text.index(anchor):]
    tmp = os.path.join(HERE, "_tmp.luau")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    try:
        return read_luau_table(tmp)
    finally:
        os.remove(tmp)


def catalog():
    text = open(os.path.join(ROOT, "src", "shared", "ModelCatalog.luau"), encoding="utf-8").read()
    out = {}
    for m in re.finditer(r"\n\t(\w+) = \{(.*?)\n\t\},?|\n\t(\w+) = \{ (size = .*?) \},", text, re.S):
        name = m.group(1) or m.group(3)
        body = m.group(2) or m.group(4)
        size = re.search(r"size = \{ ([-\d.]+), ([-\d.]+), ([-\d.]+) \}", body)
        pivot = re.search(r'pivot = "(\w+)"', body)
        collide = re.search(r"collide = (true|false)", body)
        if size:
            out[name] = ([float(v) for v in size.groups()], pivot.group(1) if pivot else "bottom",
                         collide and collide.group(1) == "true")
    return out


class Box:
    def __init__(self, x, y, z, sx, sy, sz, rot, query=True, label=""):
        self.c = (x, y, z)
        self.h = (sx / 2, sy / 2, sz / 2)
        self.rot = math.radians(rot)
        self.query = query
        self.label = label

    def to_local(self, p):
        dx, dy, dz = p[0] - self.c[0], p[1] - self.c[1], p[2] - self.c[2]
        c, s = math.cos(self.rot), math.sin(self.rot)
        # inverse of rotation about +Y by rot
        return (dx * c - dz * s, dy, dx * s + dz * c)

    def contains(self, p, margin=0.0):
        lx, ly, lz = self.to_local(p)
        return abs(lx) <= self.h[0] + margin and abs(ly) <= self.h[1] + margin and abs(lz) <= self.h[2] + margin

    def ray(self, a, b):
        """True when the segment a -> b crosses the box (slab test in box space)."""
        la, lb = self.to_local(a), self.to_local(b)
        t0, t1 = 0.0, 1.0
        for i in range(3):
            d = lb[i] - la[i]
            if abs(d) < 1e-9:
                if abs(la[i]) > self.h[i]:
                    return False
                continue
            u0 = (-self.h[i] - la[i]) / d
            u1 = (self.h[i] - la[i]) / d
            if u0 > u1:
                u0, u1 = u1, u0
            t0, t1 = max(t0, u0), min(t1, u1)
            if t0 > t1:
                return False
        return True


def rotate(rot, v):
    a = math.radians(rot)
    c, s = math.cos(a), math.sin(a)
    return (v[0] * c + v[2] * s, v[1], -v[0] * s + v[2] * c)


def boxes_for(venue, cat):
    scene = luau_return(os.path.join(ROOT, "src", "server", "Maps", "Scenes", venue + ".luau"))
    boxes = []
    for c in scene["colliders"]:
        x, y, z, sx, sy, sz, rot, query = c
        boxes.append(Box(x, y, z, sx, sy, sz, rot, query, "collider"))
    for key, x, y, z, rot, sc, *_ in scene["props"]:
        if key not in cat:
            continue
        size, pivot, collide = cat[key]
        if not collide:
            continue
        sx, sy, sz = (v * sc for v in size)
        cy = y + sy / 2 if pivot == "bottom" else y
        boxes.append(Box(x, cy, z, sx, sy, sz, rot, True, key))
    return boxes


def check(venue):
    cat = catalog()
    boxes = boxes_for(venue, cat)
    module = os.path.join(ROOT, "src", "server", "Maps", MAPS[venue] + ".luau")
    layout = luau_return(module, f"function {MAPS[venue]}.layout()")
    problems = []
    for st in layout["stations"]:
        x, z, rot = st["x"], st["z"], st["rot"]
        desk = Box(x, 1.5, z, 5, 3, 2.4, rot)
        for b in boxes:
            if b.label in ("collider",) and b.c[1] + b.h[1] <= 0.3:
                continue  # floors
            for dx in (-2.3, 0, 2.3):
                for dz in (-1.0, 0, 1.0):
                    p = rotate(rot, (dx, 1.5, dz))
                    if b.contains((x + p[0], p[1], z + p[2]), -0.05):
                        problems.append(f"{st['name']}: desk overlaps {b.label} at {tuple(round(v, 1) for v in b.c)}")
                        break
                else:
                    continue
                break
        worker = rotate(rot, (0, 2.5, -2.6))
        for b in boxes:
            if b.contains((x + worker[0], worker[1], z + worker[2])):
                problems.append(f"{st['name']}: the worker spot is blocked by {b.label}")
        screen_off = rotate(rot, (0, 5.4, 0.8))
        target = (x + screen_off[0], 5.4, z + screen_off[2])
        seen = 0
        for k in range(8):
            a = k / 8 * math.tau
            src = (target[0] + math.sin(a) * 9, 5.4, target[2] + math.cos(a) * 9)
            # Stop just short of the screen so the station's own parts do not count.
            end = (target[0] + (src[0] - target[0]) * 0.18, 5.4, target[2] + (src[2] - target[2]) * 0.18)
            if not any(b.query and b.ray(src, end) for b in boxes):
                seen += 1
        if seen < 3:
            problems.append(f"{st['name']}: screen seen from only {seen} of 8 sides")
    for i, sh in enumerate(layout["sheets"]):
        p = (sh["x"], sh["y"] + 0.5, sh["z"])
        below = (sh["x"], sh["y"] - 2.0, sh["z"])
        if not any(b.ray(p, below) for b in boxes if b.query):
            problems.append(f"sheet {i + 1} at {sh['x']}, {sh['y']}, {sh['z']} has nothing under it")
        tops = [b for b in boxes if b.ray(p, below)]
        if tops:
            top = max(b.c[1] + b.h[1] for b in tops)
            if sh["y"] - top > 0.3:
                problems.append(f"sheet {i + 1} floats {sh['y'] - top:.2f} studs above its surface")
    for kind in ("spawns", "hoods", "dropPoints"):
        for item in layout[kind]:
            p = (item["x"], 2.5 if kind == "spawns" else 0.6, item["z"])
            for b in boxes:
                if b.contains(p):
                    problems.append(f"{kind[:-1]} at {item['x']}, {item['z']} is inside {b.label}")
    tb = layout["tipBox"]
    for b in boxes:
        if b.label != "collider" and b.contains((tb["x"], 2, tb["z"])):
            problems.append(f"tip box overlaps {b.label}")
    return problems


def main():
    total = 0
    for venue in MAPS:
        problems = check(venue)
        total += len(problems)
        print(f"{venue}: {'ok' if not problems else str(len(problems)) + ' problem(s)'}")
        for p in problems:
            print("   -", p)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
