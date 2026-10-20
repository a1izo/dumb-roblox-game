"""Do the emotes' props sit right on the body? (plain Python, no Blender:)

    python art/scripts/check_props.py [clip ...] [--strict]

Poses the real R6 rig through each clip the way the game does (rbxsim), puts every prop where
src/shared/Anim/EmoteMeta.luau says (the Core model's box from ModelCatalog, scaled as the game scales it)
and measures, frame by frame:
  - how deep a prop goes into the body: any part but the one holding it, and the holding arm above the hand
    (a prop held in the fist may overlap the fist, not the forearm);
  - contacts the meta asks for (`contacts = { { at, prop?, part?, to } }`): how far the prop (or the hand) is
    from the mouth, the other hand, the page... at that beat;
  - floor props: how far off the floor they stand.
Exits 1 (with --strict) when a clip the meta marks `checked = true` breaks a limit; old clips only report.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import emotemeta  # noqa: E402
import rbxsim  # noqa: E402

RATE = 60
PENETRATION = 0.05  # studs a prop may go into the body
CONTACT = 0.15  # studs a contact may be off
HAND = 0.32  # the bottom of an arm (studs up from its end) that is the fist: a held prop may overlap it
FLOOR_PART = 3.0  # the root part stands this high (EmoteController.placeOn)

BODY = ("Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg")
# Named points on the body (part, offset from its middle) a contact can aim at.
POINTS = {
    "mouth": ("Head", (0.0, -0.25, -0.55)),
    "chin": ("Head", (0.0, -0.5, -0.4)),
    "eyes": ("Head", (0.0, 0.1, -0.55)),
    "rightHand": ("Right Arm", (0.0, -0.85, -0.05)),
    "leftHand": ("Left Arm", (0.0, -0.85, -0.05)),
    "rightPinch": ("Right Arm", (0.0, -1.02, -0.2)),
    "leftPinch": ("Left Arm", (0.0, -1.02, -0.2)),
    "leftPalm": ("Left Arm", (0.0, -1.05, -0.05)),
    "chest": ("Torso", (0.0, 0.3, -0.55)),
}


def depth(a, b):
    """How far two oriented boxes (centre, rotation, half sizes) go into each other, 0 when apart (the
    separating-axis test of cinema/clearance.py, here so this file runs without Blender)."""
    c1, r1, h1 = a
    c2, r2, h2 = b
    d = c2 - c1
    best = math.inf
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


def _box(world, centre, half):
    c = world @ np.array([*centre, 1.0])
    return (c[:3], world[:3, :3], np.array(half, float))


def body_boxes(parts, rig, skip=None):
    """(name, box) for every body part; the holding arm only above its fist."""
    out = []
    for name in BODY:
        size = np.array(rig["parts"][name]["size"], float)
        half = size / 2
        if skip == "wrapped " + name:
            continue
        if name == skip:
            if not name.endswith("Arm"):
                continue
            # the arm above the fist: from its top down to HAND studs short of its end
            top, bottom = half[1], -half[1] + HAND
            centre = (0.0, (top + bottom) / 2, 0.0)
            out.append((name + " (forearm)", _box(parts[name], centre, (half[0], (top - bottom) / 2, half[2]))))
            continue
        out.append((name, _box(parts[name], (0, 0, 0), half)))
    return out


def floor_frame(parts):
    root = parts["HumanoidRootPart"]
    m = np.identity(4)
    m[:3, 3] = root[:3, 3] - np.array([0.0, FLOOR_PART, 0.0])
    return m


def prop_frame(prop, mount, at, parts):
    if mount == "floor":
        return floor_frame(parts) @ at
    return parts[mount] @ at


def state_at(prop, t):
    """(mount, at matrix) of a prop at t, or None while it is hidden or in the air."""
    show, hide = prop.get("show"), prop.get("hide")
    if show is not None and t < show - 1e-6:
        return None
    if hide is not None and t > hide + 1e-6:
        return None
    for toss in prop.get("tosses") or []:
        if toss["at"] - 1e-6 <= t <= toss["back"] + 1e-6:
            return None
    mount, at = prop["mount"], emotemeta.steps(prop["at"])
    for move in prop.get("moves") or []:
        if t >= move["at"] + 0.18:
            mount, at = move.get("mount") or mount, emotemeta.steps(move["to"])
        elif t >= move["at"]:
            return None  # being carried
    return mount, at


def check_clip(name, clip, meta, cat, rig):
    rows = []  # (severity, text)
    worst = {}
    length = clip["length"]
    count = max(1, int(round(length * RATE)))
    for i in range(count + 1):
        t = length * i / count
        parts = rbxsim.pose_parts(rig, clip, t)
        for index, prop in enumerate(meta.get("props") or []):
            shape = emotemeta.prop_boxes(prop, cat)
            frames = []  # (world frame of one copy, stands on the floor)
            held = None
            stack = prop.get("stack")
            if stack:
                step = emotemeta.steps(stack["step"])
                at = emotemeta.steps(prop["at"])
                topple = stack.get("topple")
                for k, when in enumerate(stack["times"]):
                    # (a carried copy is in the hand until its time; a toppled tower lies scattered after)
                    if t >= when and not (topple is not None and t >= topple):
                        frames.append((prop_frame(prop, "floor", at, parts), k == 0))
                    at = at @ step
            else:
                state = state_at(prop, t)
                if state is None:
                    continue
                mount, at = state
                frames.append((prop_frame(prop, mount, at, parts), mount == "floor"))
                held = mount
            skip = held
            if held and prop["model"] in emotemeta.WRAPS:
                skip = "wrapped " + held
            allowed = {a["part"] for a in meta.get("allow") or []
                       if int(a["prop"]) == index + 1 and a["from"] <= t <= a["to"]}
            for frame, grounded in frames:
                boxes = [_box(frame, c, h) for c, h in shape]
                for part, body in body_boxes(parts, rig, skip=skip):
                    if part.split(" (")[0] in allowed:
                        continue
                    d = max(depth(box, body) for box in boxes)
                    key = (index, prop["model"], part)
                    if d > worst.get(key, (0.0, 0.0))[0]:
                        worst[key] = (d, t)
                if grounded:
                    key = (index, prop["model"], "floor gap")
                    gap = abs(min(_lowest(box) for box in boxes))
                    if gap > worst.get(key, (0.0, 0.0))[0]:
                        worst[key] = (gap, t)
    for (index, model, part), (d, t) in sorted(worst.items()):
        bad = d > PENETRATION
        rows.append((bad, f"{model:13s} {part:22s} {'into' if part != 'floor gap' else 'gap '} {d:5.2f} at {t:4.2f} s"))
    for contact in meta.get("contacts") or []:
        rows.append(check_contact(clip, contact, meta, cat, rig))
    return rows


def _lowest(box):
    c, r, h = box
    corners = [c + r @ (np.array([sx, sy, sz]) * h) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    return min(p[1] for p in corners)


def point(parts, name):
    part, off = POINTS[name]
    return (parts[part] @ np.array([*off, 1.0]))[:3]


def check_contact(clip, contact, meta, cat, rig):
    """A beat where something must touch: `to` (a body point) and either a body point `from` or a prop (by
    index, its middle unless `end` gives a point in its own frame)."""
    t = contact["at"]
    parts = rbxsim.pose_parts(rig, clip, t)
    target = point(parts, contact["to"])
    if "from" in contact:
        here = point(parts, contact["from"])
        what = contact["from"]
    else:
        prop = meta["props"][int(contact["prop"]) - 1]
        state = state_at(prop, t)
        if state is None:
            return (True, f"contact {prop['model']} -> {contact['to']} at {t:.2f} s: the prop is not on the body then")
        mount, at = state
        centre, _ = emotemeta.prop_box(prop, cat)
        local = np.array(contact.get("end") or centre, float)
        here = (prop_frame(prop, mount, at, parts) @ np.array([*local, 1.0]))[:3]
        what = prop["model"]
    gap = float(np.linalg.norm(here - target))
    limit = contact.get("within", CONTACT)
    return (gap > limit, f"contact {what:>11s} -> {contact['to']:10s} at {t:4.2f} s: {gap:5.2f} studs (limit {limit})")


def run(names=None, strict=False, quiet=False):
    clips = rbxsim.load_clips()
    rig = rbxsim.load_rig()
    meta = emotemeta.load()
    cat = emotemeta.catalog()
    failed = 0
    for name in sorted(names or meta):
        m = meta.get(name) or {}
        if not m.get("props") and not m.get("contacts"):
            continue
        if name not in clips:
            print(f"[props] {name}: no such clip")
            failed += 1
            continue
        rows = check_clip(name, clips[name], m, cat, rig)
        enforced = m.get("checked") is True
        bad = [text for flag, text in rows if flag]
        if bad and enforced:
            failed += 1
        if quiet and not bad:
            continue
        status = "FAIL" if bad and enforced else ("issues" if bad else "ok")
        print(f"[props] {name}: {status}")
        for flag, text in rows:
            if flag or not quiet:
                print(f"    {'!!' if flag else '  '} {text}")
    return failed if strict else 0


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    sys.exit(1 if run(args or None, strict="--strict" in sys.argv) else 0)
