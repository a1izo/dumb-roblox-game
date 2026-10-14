"""Checks the exported clips (src/shared/Anim/Clips) for the faults the eye catches in game, with the
game's own maths (rbxsim.py). No Blender needed:

    python art/scripts/check_anims.py [clip ...] [--all] [--quiet]

For each clip, sampled 60 times a second on a standing R6 body:
    slide   how far a sole drifts while it is on the ground (studs), for a movement clip played at its
            own speed (its stride over its length): a planted foot, a toe scuffing as it lifts, a heel
            skating as it lands
    floor   how far any corner of the body goes below the floor (studs), for clips that stand on it
    gap     how far the top of a leg drops out of the torso (R6 fakes knees by sliding legs; past a
            hair the gap shows), and how deep a leg sinks into the torso
    seam    for loops: the jump in pose and in turning speed where the loop starts again
    pop     the fastest a joint turns (degrees a second); a sudden snap shows as a spike
Clips marked strict (STRICT below: the movement set) fail the run when a limit is passed; every other
clip is only reported (with --all, or when named). Exit code 1 on a failure.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import rbxsim  # noqa: E402

RATE = 60
SOLE_DOWN = 0.02  # a sole (its lowest edge) this close to the floor is on it
LEGS = ("Right Leg", "Left Leg")
BODY = ("Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg")

# The clips held to the limits: what a moving or standing body plays all the time.
STRICT = {
    "idle", "idleGuarded", "walk", "walkBack", "walkLeft", "walkRight", "run", "runBack", "runLeft",
    "runRight", "jump", "jumpApex", "fall", "fallLong", "landLight", "landNormal", "landHeavy",
    "startStep", "stopLeft", "stopRight", "turnLeft", "turnRight", "sit",
}
# Clips played in the air (or seated): no floor to stand on, no soles to plant.
AIRBORNE = {"jump", "jumpApex", "fall", "fallLong", "flyHover", "flyGlide", "flyRise", "flyDive", "sit",
            "specterFloat", "dive", "diveBrake", "diveCaught"}
LIMITS = {
    "slide": 0.03,  # studs a sole may drift while it touches the floor
    "floor": 0.03,  # studs a corner may sink below the floor
    "gap": 0.12,  # studs the top of a leg may drop out of the torso
    "sink": 0.6,  # studs a leg may slide up inside the torso
    "seam": 0.5,  # degrees the pose may jump where a loop restarts
    "seam_speed": 120.0,  # degrees a second the turning speed may jump there
    "pop": 900.0,  # degrees a second a joint may turn
}


def corners(size):
    sx, sy, sz = (s / 2 for s in size)
    return np.array([(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)])


def angle_between(a, b):
    """Degrees between two rotation matrices."""
    r = a.T @ b
    c = max(-1.0, min(1.0, (np.trace(r) - 1) / 2))
    return math.degrees(math.acos(c))


def pose(rig, clip, t):
    """World CFrames of every part with the floor at y = 0 (the HumanoidRootPart 3 studs above it)."""
    parts = rbxsim.pose_parts(rig, clip, t)
    floor = rig["parts"]["HumanoidRootPart"]["cframe"]["p"][1] - 3.0
    for m in parts.values():
        m[1, 3] -= floor
    return parts


def joint_rotations(clip, t):
    t = rbxsim.clip_time(clip, t)
    return {j: rbxsim.quat_matrix(*rbxsim.sample_track(track, t)) for j, track in clip["joints"].items()}


def box_points(m, size):
    return (m[:3, :3] @ corners(size).T).T + m[:3, 3]


def check_clip(name, clip, rig):
    length = clip["length"]
    count = max(2, int(round(length * RATE)))
    dt = length / count
    times = [length * i / count for i in range(count + 1)]
    poses = [pose(rig, clip, t) for t in times]
    sizes = {p: rig["parts"][p]["size"] for p in BODY}
    standing = name not in AIRBORNE
    out = {}

    if standing:
        lowest = min(box_points(parts[p], sizes[p])[:, 1].min() for parts in poses for p in BODY)
        out["floor"] = max(0.0, -lowest)

    # slide: the lowest point of each leg while it touches the floor, in the world, for a movement clip
    # played at its own speed (the body moves forward, -z, by its stride each cycle)
    stride = clip.get("stride")
    if stride and standing:
        speed = stride / length
        worst = 0.0
        for leg in LEGS:
            down = None
            for t, parts in zip(times, poses):
                pts = box_points(parts[leg], sizes[leg])
                low = pts[np.argsort(pts[:, 1])[:2]].mean(axis=0)  # the lowest edge's middle
                world = low + np.array([0.0, 0.0, -speed * t])
                if low[1] < SOLE_DOWN:
                    if down is None:
                        down = world
                    worst = max(worst, float(np.linalg.norm((world - down)[[0, 2]])))
                else:
                    down = None
        out["slide"] = worst

    # gap / sink: the top of each leg in the torso's frame (the torso's bottom face is at y = -1)
    gap, sink = 0.0, 0.0
    for parts in poses:
        inv = np.linalg.inv(parts["Torso"])
        for leg in LEGS:
            m = parts[leg]
            top = m[:3, :3] @ np.array([0.0, 1.0, 0.0]) + m[:3, 3]
            local = (inv @ np.array([*top, 1.0]))[:3]
            gap = max(gap, -1.0 - local[1])
            sink = max(sink, local[1] + 1.0)
    out["gap"] = max(0.0, gap)
    out["sink"] = sink

    # pop: the fastest turn of any joint
    rots = [joint_rotations(clip, t) for t in times]
    fastest, where = 0.0, None
    for j in clip["joints"]:
        for i in range(1, len(rots)):
            rate = angle_between(rots[i - 1][j], rots[i][j]) / dt
            if rate > fastest:
                fastest, where = rate, (j, times[i])
    out["pop"] = fastest
    out["pop_at"] = where

    # seam: a loop restarts without a jump in pose or in turning speed
    if clip["loop"]:
        jump, speed_jump = 0.0, 0.0
        end = joint_rotations(clip, length - 1e-6)
        for j in clip["joints"]:
            jump = max(jump, angle_between(rots[0][j], end[j]))
            start_speed = angle_between(rots[0][j], rots[1][j]) / dt
            end_speed = angle_between(rots[-2][j], end[j]) / dt
            speed_jump = max(speed_jump, abs(start_speed - end_speed))
        out["seam"] = jump
        out["seam_speed"] = speed_jump
    return out


def failures(result, strict):
    if not strict:
        return []
    return [f"{key} {result[key]:.3f} > {limit}" for key, limit in LIMITS.items() if key in result and result[key] > limit]


def run(names=None, show_all=False, quiet=False):
    """Checks the clips (all strict ones by default); returns the number that failed."""
    clips = rbxsim.load_clips()
    rig = rbxsim.load_rig()
    failed = 0
    for name in names or sorted(clips):
        if name not in clips:
            print(f"[check_anims] {name}: no such clip")
            failed += 1
            continue
        strict = name in STRICT
        if not (strict or show_all or names):
            continue
        result = check_clip(name, clips[name], rig)
        bad = failures(result, strict)
        failed += 1 if bad else 0
        if quiet and not bad:
            continue
        shown = [f"{k} {result[k]:.3f}" for k in ("slide", "floor", "gap", "sink", "seam", "seam_speed") if k in result]
        joint, at = result["pop_at"] or ("-", 0.0)
        shown.append(f"pop {result['pop']:.0f}/s ({joint} at {at:.2f})")
        mark = "FAIL" if bad else ("ok" if strict else "info")
        print(f"[check_anims] {mark:4} {name}: " + ", ".join(shown) + (("  <- " + "; ".join(bad)) if bad else ""))
    print(f"[check_anims] {failed} clip(s) failed")
    return failed


if __name__ == "__main__":
    args = sys.argv[1:]
    count = run([a for a in args if not a.startswith("--")], "--all" in args, "--quiet" in args)
    sys.exit(1 if count else 0)
