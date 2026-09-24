"""Samples every Inkbound action on the R15 rig and writes src/shared/Anim/Clips.luau.

For each clip and each joint it uses, the rotation of the joint in its parent's frame is
sampled 30 times a second, converted to Roblox space, and reduced to the fewest keys that
stay within a small angle of the curve (so snappy moves keep their shape). The game plays the
keys back with spherical interpolation.
"""

import math
import os

import bpy
from mathutils import Matrix, Quaternion, Vector

from common import M, M_INV, ROOT
from rig import JOINTS, LAYOUT

SAMPLE_FPS = 30
ANGLE_TOLERANCE = math.radians(0.6)
OFFSET_TOLERANCE = 0.01
OUT = os.path.join(ROOT, "src", "shared", "Anim", "Clips.luau")

PARENT = {row[1]: row[2] for row in LAYOUT}


def _delta(arm, bone_name):
    """World-space rotation of a bone relative to its rest orientation."""
    if bone_name == "HumanoidRootPart":
        return Matrix.Identity(3)
    pb = arm.pose.bones[bone_name]
    rest = arm.data.bones[bone_name].matrix_local.to_3x3()
    return pb.matrix.to_3x3() @ rest.inverted()


def sample_joint(arm, joint):
    bone = JOINTS[joint]
    t_blender = _delta(arm, PARENT[bone]).inverted() @ _delta(arm, bone)
    q = (M @ t_blender @ M_INV).to_quaternion()
    q.normalize()
    return q


def sample_offset(arm):
    bone = JOINTS["root"]
    pb = arm.pose.bones[bone]
    rest_head = arm.data.bones[bone].head_local
    return M @ (pb.head - rest_head)


def _angle(a, b):
    d = abs(a.dot(b))
    return 2 * math.acos(min(1.0, d))


def reduce_quats(times, quats):
    """Douglas-Peucker on quaternions: keeps keys whose removal would bend the curve too much."""
    keep = {0, len(quats) - 1}

    def recurse(i, j):
        if j <= i + 1:
            return
        worst, worst_k = -1.0, None
        for k in range(i + 1, j):
            f = (times[k] - times[i]) / (times[j] - times[i])
            approx = quats[i].slerp(quats[j], f)
            err = _angle(approx, quats[k])
            if err > worst:
                worst, worst_k = err, k
        if worst > ANGLE_TOLERANCE:
            keep.add(worst_k)
            recurse(i, worst_k)
            recurse(worst_k, j)

    recurse(0, len(quats) - 1)
    return sorted(keep)


def reduce_vectors(times, vectors):
    keep = {0, len(vectors) - 1}

    def recurse(i, j):
        if j <= i + 1:
            return
        worst, worst_k = -1.0, None
        for k in range(i + 1, j):
            f = (times[k] - times[i]) / (times[j] - times[i])
            approx = vectors[i].lerp(vectors[j], f)
            err = (approx - vectors[k]).length
            if err > worst:
                worst, worst_k = err, k
        if worst > OFFSET_TOLERANCE:
            keep.add(worst_k)
            recurse(i, worst_k)
            recurse(worst_k, j)

    recurse(0, len(vectors) - 1)
    return sorted(keep)


def fmt(value, digits):
    text = f"{value:.{digits}f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def sample_action(arm, action):
    scene = bpy.context.scene
    fps = scene.render.fps
    length = float(action["length"])
    joints = list(action["joints"])
    has_offset = bool(action.get("offset", False))
    arm.animation_data.action = action
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)

    count = max(1, int(round(length * SAMPLE_FPS)))
    times = [length * i / count for i in range(count + 1)]
    samples = {joint: [] for joint in joints}
    offsets = []
    for t in times:
        frame = t * fps
        whole = int(math.floor(frame))
        scene.frame_set(whole, subframe=frame - whole)
        for joint in joints:
            q = sample_joint(arm, joint)
            previous = samples[joint][-1] if samples[joint] else None
            if previous is not None and previous.dot(q) < 0:
                q.negate()
            samples[joint].append(q)
        if has_offset:
            offsets.append(sample_offset(arm))
    return length, times, samples, offsets


def clip_lua(name, action, length, times, samples, offsets):
    lines = [f"\t{name} = {{"]
    lines.append(f"\t\tlength = {fmt(length, 3)},")
    lines.append(f"\t\tloop = {'true' if action['loop'] else 'false'},")
    lines.append("\t\tjoints = {")
    for joint in sorted(samples):
        quats = samples[joint]
        keep = reduce_quats(times, quats)
        t_text = ", ".join(fmt(times[i], 3) for i in keep)
        q_text = ", ".join(
            f"{fmt(quats[i].x, 4)}, {fmt(quats[i].y, 4)}, {fmt(quats[i].z, 4)}, {fmt(quats[i].w, 4)}" for i in keep
        )
        lines.append(f"\t\t\t{joint} = {{ t = {{ {t_text} }}, q = {{ {q_text} }} }},")
    lines.append("\t\t},")
    if offsets:
        keep = reduce_vectors(times, offsets)
        t_text = ", ".join(fmt(times[i], 3) for i in keep)
        p_text = ", ".join(f"{fmt(offsets[i].x, 3)}, {fmt(offsets[i].y, 3)}, {fmt(offsets[i].z, 3)}" for i in keep)
        lines.append(f"\t\toffset = {{ t = {{ {t_text} }}, p = {{ {p_text} }} }},")
    lines.append("\t},")
    return lines


def export(arm):
    actions = sorted((a for a in bpy.data.actions if a.get("inkbound_clip")), key=lambda a: a.name)
    body = [
        "--!strict",
        "-- GENERATED by art/scripts/export_anims.py from art/blend/Animations.blend. Do not edit by hand:",
        "-- change the keys in art/scripts/anims.py (or the actions in Blender) and export again.",
        "--",
        "-- Each clip: length (seconds), loop, and per joint the key times with quaternions",
        "-- (x, y, z, w) in the joint's parent frame; offset moves the whole body (studs).",
        "",
        "return {",
    ]
    stats = {}
    for action in actions:
        length, times, samples, offsets = sample_action(arm, action)
        lines = clip_lua(action.name, action, length, times, samples, offsets)
        body.extend(lines)
        stats[action.name] = sum(line.count(",") for line in lines)
    body.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(body) + "\n")
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    return {"file": OUT, "clips": len(actions), "size": os.path.getsize(OUT)}
