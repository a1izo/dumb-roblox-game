"""Roblox-side maths without Blender: reads Clips.luau and poses a real R6 rig
(art/data/r6_rig.json) exactly the way the game does (ClipPlayer + PoseController)."""

import json
import math
import os
import re

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
CLIPS = os.path.join(ROOT, "src", "shared", "Anim", "Clips.luau")
RIG = os.path.join(ROOT, "art", "data", "r6_rig.json")

JOINT_MOTORS = {
    "root": "RootJoint",
    "neck": "Neck",
    "lShoulder": "Left Shoulder",
    "rShoulder": "Right Shoulder",
    "lHip": "Left Hip",
    "rHip": "Right Hip",
}


def load_clips(path=CLIPS):
    return read_luau_table(path)


def load_rig(path=RIG):
    with open(path) as f:
        return json.load(f)


# --- Luau table reader ------------------------------------------------------------------


def _tokens(text):
    text = re.sub(r"--[^\n]*", "", text)
    for match in re.finditer(r"-?\d+\.?\d*(?:[eE][-+]?\d+)?|[A-Za-z_]\w*|\"[^\"]*\"|[{}=,]", text):
        yield match.group(0)


def read_luau_table(path):
    tokens = list(_tokens(open(path, encoding="utf-8").read()))
    pos = tokens.index("return") + 1

    def value():
        nonlocal pos
        tok = tokens[pos]
        if tok == "{":
            return table()
        pos += 1
        if tok in ("true", "false"):
            return tok == "true"
        if tok == "nil":
            return None
        if tok.startswith('"'):
            return tok[1:-1]
        return float(tok)

    def table():
        nonlocal pos
        pos += 1
        keyed, listed = {}, []
        while tokens[pos] != "}":
            if tokens[pos + 1] == "=" and re.match(r"[A-Za-z_]", tokens[pos]):
                key = tokens[pos]
                pos += 2
                keyed[key] = value()
            else:
                listed.append(value())
            if tokens[pos] == ",":
                pos += 1
        pos += 1
        return keyed if keyed else listed

    return value()


# --- Roblox CFrame maths ----------------------------------------------------------------


def cf(p=(0, 0, 0), r=None):
    m = np.identity(4)
    if r is not None:
        m[:3, :3] = np.array(r)
    m[:3, 3] = p
    return m


def quat_matrix(x, y, z, w):
    n = math.sqrt(x * x + y * y + z * z + w * w)
    x, y, z, w = x / n, y / n, z / n, w / n
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def slerp(qa, qb, t):
    qa, qb = np.array(qa, float), np.array(qb, float)
    dot = float(np.dot(qa, qb))
    if dot < 0:
        qb, dot = -qb, -dot
    if dot > 0.9995:
        q = qa + (qb - qa) * t
        return q / np.linalg.norm(q)
    theta = math.acos(dot)
    return (math.sin((1 - t) * theta) * qa + math.sin(t * theta) * qb) / math.sin(theta)


def sample_track(track, t):
    times, q = track["t"], track["q"]
    quats = [q[i * 4 : i * 4 + 4] for i in range(len(times))]
    if t <= times[0]:
        return quats[0]
    if t >= times[-1]:
        return quats[-1]
    i = max(k for k in range(len(times)) if times[k] <= t)
    span = times[i + 1] - times[i]
    return slerp(quats[i], quats[i + 1], (t - times[i]) / span if span > 0 else 0)


def sample_offset(clip, t):
    off = clip.get("offset")
    if not off:
        return None
    times, p = off["t"], off["p"]
    pts = [np.array(p[i * 3 : i * 3 + 3]) for i in range(len(times))]
    if t <= times[0]:
        return pts[0]
    if t >= times[-1]:
        return pts[-1]
    i = max(k for k in range(len(times)) if times[k] <= t)
    span = times[i + 1] - times[i]
    a = (t - times[i]) / span if span > 0 else 0
    return pts[i] + (pts[i + 1] - pts[i]) * a


def clip_time(clip, t):
    length = clip["length"]
    if clip["loop"] and length > 0:
        return t % length
    return min(max(t, 0), length)


def pose_parts(rig, clip, t):
    """World CFrames of every part (HumanoidRootPart at its rest place)."""
    t = clip_time(clip, t)
    rotations = {}
    for joint, track in clip["joints"].items():
        rotations[JOINT_MOTORS[joint]] = quat_matrix(*sample_track(track, t))
    offset = sample_offset(clip, t)
    return pose_from(rig, rotations, offset)


def pose_from(rig, rotations, offset=None):
    """World CFrames of every part for joint rotations (3x3, in the parent part's frame, by motor
    name) and a whole-body offset. A joint's rotation becomes its Transform the way the game does
    it (ClipPlayer.transform): basis^-1 * rotation * basis, with basis the rotation of its C0."""
    motor_by_name = {m["name"]: m for m in rig["motors"]}
    transforms = {}
    for name, rot in rotations.items():
        basis = np.array(motor_by_name[name]["c0"]["r"])
        transforms[name] = cf(r=basis.T @ rot @ basis)
    if offset is not None:
        root_name = JOINT_MOTORS["root"]
        basis = np.array(motor_by_name[root_name]["c0"]["r"])
        local = transforms.get(root_name, np.identity(4))
        transforms[root_name] = cf(p=basis.T @ np.array(offset)) @ local
    parts = rig["parts"]
    world = {"HumanoidRootPart": cf(parts["HumanoidRootPart"]["cframe"]["p"])}
    motors = list(rig["motors"])
    while motors:
        for motor in list(motors):
            if motor["part0"] in world:
                c0 = cf(motor["c0"]["p"], motor["c0"]["r"])
                c1 = cf(motor["c1"]["p"], motor["c1"]["r"])
                transform = transforms.get(motor["name"], np.identity(4))
                world[motor["part1"]] = world[motor["part0"]] @ c0 @ transform @ np.linalg.inv(c1)
                motors.remove(motor)
    return world
