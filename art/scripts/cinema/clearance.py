"""Room to move: every body part of every actor, all through a shot, against the set's walls and solid
dressing, its props and the other actors. Parts and boxes are oriented boxes (a separating-axis test).

    for line in clearance.report(shot, scene): print(line)

`shot.allow` maps a slot to the things it may touch (prop keys like "ClubChair", or other slots), for the
contacts that are meant: sitting in a chair, a hand on someone's head."""

import math

import numpy as np

import posekit
import rbxsim
from cinema import framing

# R6 part sizes (the head's mesh is smaller than its 2x1x1 box)
SIZES = {"Torso": (2, 2, 1), "Head": (1.2, 1.2, 1.2), "Left Arm": (1, 2, 1), "Right Arm": (1, 2, 1),
         "Left Leg": (1, 2, 1), "Right Leg": (1, 2, 1)}
TOL = 0.12  # touching is fine; this much in is not


def ry(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def part_boxes(shot, slot, t):
    a = framing.actor(shot, slot)
    v = a.path.value(t)
    place, turn = np.array(v[:3]), ry(float(v[3]))
    joints, off = framing._pose(a, t)
    parts = posekit.fk(joints, off)
    out = []
    for name, size in SIZES.items():
        m = parts[name]
        out.append((name, place + turn @ m[:3, 3], turn @ m[:3, :3], np.array(size, float) / 2))
    return out


def depth(a, b):
    """How far two oriented boxes (centre, rotation, half sizes) go into each other (0 when apart)."""
    c1, r1, h1 = a
    c2, r2, h2 = b
    d = c2 - c1
    best = float("inf")
    axes = [r1[:, i] for i in range(3)] + [r2[:, i] for i in range(3)]
    axes += [np.cross(r1[:, i], r2[:, j]) for i in range(3) for j in range(3)]
    for axis in axes:
        n = np.linalg.norm(axis)
        if n < 1e-6:
            continue
        axis = axis / n
        ra = sum(abs(h1[i] * (r1[:, i] @ axis)) for i in range(3))
        rb = sum(abs(h2[i] * (r2[:, i] @ axis)) for i in range(3))
        over = ra + rb - abs(d @ axis)
        if over <= 0:
            return 0.0
        best = min(best, over)
    return best


def set_boxes(scene, catalog):
    """The set's solid boxes: (label, key, centre, rotation, half sizes). The floor is left out."""
    out = []
    for x, y, z, sx, sy, sz, rot, _query, _look in scene.colliders:
        if y + sy / 2 <= 0.05:  # the floor
            continue
        out.append((f"wall/solid at ({x:.0f}, {z:.0f})", "solid", np.array([x, y, z]), ry(rot),
                    np.array([sx, sy, sz]) / 2))
    for key, x, y, z, rot, scale, _ in scene.props:
        info = catalog.get(key)
        if not info:
            continue
        sx, sy, sz = (v * scale for v in info["size"])
        cy = y + sy / 2 if info.get("pivot", "bottom") == "bottom" else y
        out.append((f"{key} at ({x:.0f}, {z:.0f})", key, np.array([x, cy, z]), ry(rot), np.array([sx, sy, sz]) / 2))
    return out


def report(shot, scene, step=0.2):
    catalog = rbxsim.read_luau_table(framing_catalog())
    boxes = set_boxes(scene, catalog)
    allow = getattr(shot, "allow", {}) or {}
    hits = {}
    t = 0.0
    while t <= shot.length + 1e-6:
        bodies = {}
        for a in shot.actors:
            if a.show[0] <= t <= a.show[1]:
                bodies[a.slot] = part_boxes(shot, a.slot, t)
        for slot, parts in bodies.items():
            ok = set(allow.get(slot, ()))
            centre = parts[0][1]
            ground = framing.actor(shot, slot).path.value(t)[1]  # the level they stand at
            for label, key, c, r, h in boxes:
                if key in ok or np.linalg.norm((c - centre)[[0, 2]]) > np.linalg.norm(h) + 3.0:
                    continue
                for name, pc, pr, ph in parts:
                    dd = depth((pc, pr, ph), (c, r, h))
                    if name.endswith("Leg") and key == "solid" and c[1] + h[1] <= ground + 2.1:
                        continue  # the floor and the steps they walk on, low ledges
                    if dd > TOL:
                        hits.setdefault((slot, label), []).append((t, dd, name))
            for other, oparts in bodies.items():
                if other <= slot or other in ok or slot in set(allow.get(other, ())):
                    continue
                if np.linalg.norm((oparts[0][1] - centre)[[0, 2]]) > 6.0:
                    continue
                for name, pc, pr, ph in parts:
                    for oname, oc, orr, oh in oparts:
                        dd = depth((pc, pr, ph), (oc, orr, oh))
                        if dd > TOL:
                            hits.setdefault((slot, other), []).append((t, dd, f"{name}/{oname}"))
        t += step
    lines = []
    for (slot, what), items in sorted(hits.items(), key=lambda kv: kv[1][0][0]):
        worst = max(items, key=lambda i: i[1])
        lines.append(f"{items[0][0]:5.2f}-{items[-1][0]:5.2f}s {slot} into {what}: {worst[1]:.2f} deep ({worst[2]})")
    return lines


def framing_catalog():
    import os

    import common

    return os.path.join(common.ROOT, "src", "shared", "ModelCatalog.luau")
