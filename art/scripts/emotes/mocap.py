"""Motion capture from a reference video (2026-10-17): the dancer's pose, tracked on frames of the source
(art/refs/mocap/<clip>.json, MediaPipe Pose Landmarker), turned into R6 keys.

What carries over, and how an R6 body (rigid limbs, no knees or elbows) shows it:
- the torso: its lean, twist and sway, from the hips and shoulders (the root joint);
- the head: where the face points and its tilt (neck);
- each arm: its line from shoulder to wrist, with the fist slid to where the hand is (kit.reach);
- each leg: its line from hip to ankle, slid up into the hip by as much as the knee bends (a bent knee
  shortens a real leg; R6 shows it as the leg sliding up), so the body sinks into a bounce by itself;
- the weight: the hips' travel left and right (from the picture), and the height that keeps the lower
  foot on the floor;
- planted feet stay put while the body moves over them (the leg slides a little to hold the sole).

Positions are Roblox studs in the character's frame (x right, y up, z backwards; the floor at y = 0), as in
posekit. The tracker's world points are metres with x to the right of the picture, y down and z away from the
camera; the dancer faces the camera, so the character's right is the picture's left.
"""

import json
import math
import os

import numpy as np

import posekit
from animlib import J
from emotes.kit import _solve, arm_angles, fist_at

HERE = os.path.dirname(os.path.abspath(__file__))
REFS = os.path.normpath(os.path.join(HERE, "..", "..", "refs", "mocap"))

NOSE, L_EYE, R_EYE, L_EAR, R_EAR = 0, 2, 5, 7, 8
L_SH, R_SH, L_EL, R_EL, L_WR, R_WR = 11, 12, 13, 14, 15, 16
L_HIP, R_HIP, L_KNEE, R_KNEE, L_ANK, R_ANK = 23, 24, 25, 26, 27, 28
L_HEEL, R_HEEL, L_TOE, R_TOE = 29, 30, 31, 32

R6_SHOULDER = 1.5  # the arm's middle line from the torso's middle
R6_SHOULDER_Y = 1.0  # the top of the arm above the torso's middle
R6_FIST = 1.85  # shoulder top to fist
def _unit(v):
    n = float(np.linalg.norm(v))
    return v / n if n > 1e-9 else v


class Take:
    """One clip's tracked frames: points[frame][landmark] (character axes, metres), picture[frame][landmark]
    (0..1, x right, y down), times (source seconds), visibility; the pictures' size, and whether the camera pans
    (then the picture says nothing about where the body is on the floor)."""

    def __init__(self, clip):
        with open(os.path.join(REFS, clip + ".json"), encoding="utf-8") as fh:
            data = json.load(fh)
        ids = data["landmarks"]
        self.size = tuple(data.get("size", (260, 462)))
        self.panning = bool(data.get("panning"))
        n = len(data["frames"])
        self.times = np.array([f["t"] for f in data["frames"]])
        self.points = np.zeros((n, 33, 3))
        self.picture = np.zeros((n, 33, 2))
        self.seen = np.zeros((n, 33))
        for i, f in enumerate(data["frames"]):
            for k, lid in enumerate(ids):
                x, y, z, v = f["w"][k]
                self.points[i, lid] = (-x, -y, z)
                self.picture[i, lid] = f["i"][k]
                self.seen[i, lid] = v
        self.clip = clip

    def smooth(self, passes=1):
        """A light [1 2 1] filter along time (ends kept), to take the tracker's jitter out without losing hits."""
        for _ in range(passes):
            for arr in (self.points, self.picture):
                inner = 0.25 * arr[:-2] + 0.5 * arr[1:-1] + 0.25 * arr[2:]
                arr[1:-1] = inner
        return self


def torso_frame(p):
    """The torso's axes (columns right, up, back) from the hips and shoulders: the shoulders lead its twist."""
    hips = (p[L_HIP] + p[R_HIP]) / 2
    shoulders = (p[L_SH] + p[R_SH]) / 2
    up = _unit(shoulders - hips)
    right = _unit(0.6 * (p[R_SH] - p[L_SH]) + 0.4 * (p[R_HIP] - p[L_HIP]))
    back = _unit(np.cross(right, up))
    right = np.cross(up, back)
    return np.column_stack([right, up, back]), hips, shoulders


def head_frame(p, pitch_fix):
    ears = (p[L_EAR] + p[R_EAR]) / 2
    forward = _unit(p[NOSE] - ears)
    right = _unit(0.5 * (p[R_EYE] - p[L_EYE]) + 0.5 * (p[R_EAR] - p[L_EAR]))
    back = -forward
    up = _unit(np.cross(back, right))
    right = np.cross(up, back)
    # a level face has the nose a little below the ears: turn that back out
    return np.column_stack([right, up, back]) @ posekit.rx(pitch_fix)


def _arm_target(side, wrist_t, shoulder_t, scale):
    """Where the R6 fist goes for a hand at wrist_t (torso frame, metres from the torso's middle): measured from
    the shoulder at the arm's scale, except across the body, where the hand's place between the shoulders maps
    onto R6's wider chest (so hands that meet in front of a person meet in front of the R6 torso too)."""
    x6 = side * R6_SHOULDER + (wrist_t[0] - shoulder_t[0]) * scale
    inside = side * wrist_t[0] < side * shoulder_t[0]
    if inside:
        x6 = R6_SHOULDER * wrist_t[0] / abs(shoulder_t[0])
    y6 = R6_SHOULDER_Y + (wrist_t[1] - shoulder_t[1]) * scale
    z6 = (wrist_t[2] - shoulder_t[2]) * scale
    return np.array([x6, y6, z6])


# How far an R6 arm may slide off its shoulder to put the fist where the hand is (studs), judged along the arm:
# across it freely (it reads as the elbow); out of the shoulder hardly at all (a gap shows); back into the
# shoulder a little for a lowered arm (its top would poke up over the shoulder) and a lot for a raised one (it
# sinks behind the shoulder, R6's bent elbow). A lowered arm never rises past the shoulder line.
SLIDE_SIDE, SLIDE_UP, EXTEND, RETRACT_LOW, RETRACT_HIGH = 0.45, 0.12, 0.12, 0.12, 0.65


def _clamp_slide(s, d):
    """Slide s (torso frame) kept within what an arm pointing along d (shoulder to fist) can show."""
    s = np.array(s, float)
    d = _unit(np.array(d, float))
    along = float(s @ d)
    perp = s - along * d
    raised = max(0.0, min(1.0, (d[1] + 0.2) / 1.2))  # 0 hanging, 1 straight up
    along = max(-(RETRACT_LOW + (RETRACT_HIGH - RETRACT_LOW) * raised), min(EXTEND, along))
    n = float(np.linalg.norm(perp))
    if n > SLIDE_SIDE:
        perp = perp * (SLIDE_SIDE / n)
    out = perp + along * d
    if d[1] < 0.3:
        out[1] = min(out[1], SLIDE_UP)
    return out


def _clear_head(side, target):
    """A hand at the eyes or forehead (goggles, a salute) goes beside the face: an R6 fist is as big as half the
    face, so in front of it it would hide it."""
    x, y, z = (float(v) for v in target)
    if 1.1 < y < 2.2 and abs(x) < 0.9 and z > -1.2:
        x = side * 0.9
    return np.array([x, y, z])


def arm(side, target, prefer):
    """The arm value that best shows a hand at `target` (torso frame) with the arm along `prefer` (the way the
    real arm points, from the shoulder): candidates lean from `prefer` towards the target, each slid to the target
    as far as the slide limits allow; the pick misses the target least for the least lean."""
    target = np.array(target, float)
    prefer = _unit(np.array(prefer, float))
    shoulder = np.array([side * R6_SHOULDER, R6_SHOULDER_Y, 0.0])
    straight = _unit(target - shoulder)
    best = None
    for u in np.linspace(0.0, 1.0, 11):
        d = _unit(prefer * (1 - u) + straight * u)
        angles, slide = _solve(side, target, d, 0.0)
        kept = _clamp_slide(slide, d)
        miss = float(np.linalg.norm(slide - kept))
        lean = math.acos(max(-1.0, min(1.0, float(d @ prefer))))
        cost = miss + 0.45 * lean
        if best is None or cost < best[0]:
            best = (cost, angles, kept)
    return J(best[1], tuple(round(float(v), 3) for v in best[2]))


def upright(points):
    """The take turned so the floor is level and the dancer faces ahead: the tracker's axes follow the camera, so
    a camera looking down tips the whole body back (the median line from the hips down to the ankles is taken
    as straight down), and the median facing of the torso is taken as straight ahead."""
    down = _unit(np.median([_unit((f[L_ANK] + f[R_ANK]) / 2 - (f[L_HIP] + f[R_HIP]) / 2) for f in points], axis=0))
    p = np.einsum("ij,fkj->fki", _arc(down, DOWN), points)
    yaw = float(np.median([posekit.euler(torso_frame(f)[0])[1] for f in p]))
    return np.einsum("ij,fkj->fki", posekit.ry(-yaw), p)


TAP_MAX = 28.0  # degrees a heel tap may tilt a leg forward


def solve(take, lead=0.0, head_fix=None, contact=0.022, arm_depth=0.6, leg_depth=0.5, taps=0.0):
    """Per frame: (time, joints, offset). lead shifts the times (clip time = source time - lead). arm_depth and
    leg_depth flatten how far hands and feet reach towards or away from the camera (the tracker's depth runs
    deep on some takes: arms out to the sides come back angled at the camera, feet side by side a stride apart).
    taps (degrees a metre) tilts the foot that is ahead of the other further forward: a heel tapped out in front
    is a short reach a real ankle and knee show, which a rigid R6 leg only shows tilted."""
    p = upright(take.points)
    n = len(p)
    # sizes of this dancer: straight arm and leg lengths (a high percentile of what was measured)
    arm_len = np.percentile([np.linalg.norm(f[R_WR] - f[R_SH]) for f in p]
                            + [np.linalg.norm(f[L_WR] - f[L_SH]) for f in p], 95)
    leg_len = np.percentile([np.linalg.norm(f[R_ANK] - f[R_HIP]) for f in p]
                            + [np.linalg.norm(f[L_ANK] - f[L_HIP]) for f in p], 95)
    arm_scale = R6_FIST / arm_len
    leg_scale = posekit.LEG_LENGTH / leg_len
    # metres per picture pixel, from the body's height in the picture against its height in the world
    sizes = []
    for i in range(n):
        world = np.linalg.norm((p[i, L_SH] + p[i, R_SH]) / 2 - (p[i, L_ANK] + p[i, R_ANK]) / 2)
        pic = take.picture[i]
        a = ((pic[L_SH] + pic[R_SH]) / 2 - (pic[L_ANK] + pic[R_ANK]) / 2) * np.array(take.size)
        sizes.append(world / max(1e-6, np.linalg.norm(a)))
    m_per_px = float(np.median(sizes))
    hips_x0 = float(np.median([(take.picture[i, L_HIP, 0] + take.picture[i, R_HIP, 0]) / 2 for i in range(n)]))
    floor_y = float(np.percentile(np.concatenate([take.picture[:, L_ANK, 1], take.picture[:, R_ANK, 1]]), 97))
    # the head's median pitch and roll against the torso, taken as level (a face's landmarks sit off its axes)
    heads = np.array([posekit.euler(torso_frame(f)[0].T @ head_frame(f, 0.0)) for f in p])
    if head_fix is None:
        head_fix = -float(np.median(heads[:, 0]))
    head_roll = -float(np.median(heads[:, 2]))

    out = []
    targets = {}
    for i in range(n):
        f = p[i]
        mt, hips, shoulders = torso_frame(f)
        middle = (hips + shoulders) / 2
        root = posekit.euler(mt)
        neck = posekit.euler(mt.T @ head_frame(f, head_fix) @ posekit.rz(head_roll))
        joints = {"root": root, "neck": neck}
        for side, sh, el, wr, joint in ((1, R_SH, R_EL, R_WR, "rShoulder"), (-1, L_SH, L_EL, L_WR, "lShoulder")):
            wrist_t = mt.T @ (f[wr] - middle)
            elbow_t = mt.T @ (f[el] - middle)
            shoulder_t = mt.T @ (f[sh] - middle)
            for v in (wrist_t, elbow_t):
                v[2] = shoulder_t[2] + (v[2] - shoulder_t[2]) * arm_depth
            target = _clear_head(side, _arm_target(side, wrist_t, shoulder_t, arm_scale))
            # the R6 arm stands for the upper arm and the forearm together: halfway between their lines
            line = _unit(elbow_t - shoulder_t) + _unit(wrist_t - shoulder_t)
            joints[joint] = arm(side, target, line)
            targets[joint] = target
        # legs: their lines in the world, how far each knee bends (slide up), then the height on the floor
        legs = {}
        for side, hp, an, joint in ((1, R_HIP, R_ANK, "rHip"), (-1, L_HIP, L_ANK, "lHip")):
            d = f[an] - f[hp]
            bend_d = d.copy()
            d[2] *= leg_depth
            pitch, _, roll = arm_angles(d)
            if taps:
                ahead = float(f[L_ANK if an == R_ANK else R_ANK][2] - f[an][2])  # metres in front of the other
                pitch += max(0.0, min(TAP_MAX, ahead * taps))
            bend = min(LEG_SINK, max(0.0, 1.0 - np.linalg.norm(bend_d) / leg_len) * posekit.LEG_LENGTH)
            if take.panning:
                # the camera moves: a foot is down when its ankle is as low as the lower one (world, hip-relative)
                down = f[an][1] <= min(f[R_ANK][1], f[L_ANK][1]) + FOOT_UP
            else:
                down = take.picture[i, an, 1] >= floor_y - contact
            legs[joint] = (side, pitch, roll, bend, down)
        if take.panning:
            x = 0.0  # set below, from where the feet are
        else:
            x = -((take.picture[i, L_HIP, 0] + take.picture[i, R_HIP, 0]) / 2 - hips_x0) * take.size[0] * m_per_px * leg_scale
        offset = np.array([x, 0.0, 0.0])
        soles = {}
        for joint, (side, pitch, roll, bend, _) in legs.items():
            world = posekit.R(pitch, 0, roll)
            soles[joint] = posekit.hip_world(side, root, offset) + world @ np.array([-side * 0.5, -posekit.LEG_LENGTH + bend, 0.0])
        # the lower leg's lowest corner on the floor
        offset[1] = -min(s[1] - _lift(legs[j][1], legs[j][2]) for j, s in soles.items())
        out.append({"t": float(take.times[i] - lead), "joints": joints, "offset": offset, "legs": legs,
                    "soles": {j: s + np.array([0, offset[1], 0]) for j, s in soles.items()}, "targets": targets})
        targets = {}
    if take.panning:
        _travel_from_feet(out)
    return out, {"arm_len": arm_len, "leg_len": leg_len, "m_per_px": m_per_px, "head_fix": head_fix,
                 "head_roll": head_roll, "floor_y": floor_y}


FOOT_UP = 0.04  # metres an ankle may sit above the lower one and still count as down (panning takes)


def _travel_from_feet(frames):
    """For a take filmed by a moving camera: the body's sway left and right over its feet, from where the feet on
    the floor are under it (the feet stay put, so the body moves the other way), centred and smoothed."""
    xs = []
    for f in frames:
        down = [s[0] for j, s in f["soles"].items() if f["legs"][j][4]] or [s[0] for s in f["soles"].values()]
        xs.append(-float(np.mean(down)))
    xs = np.array(xs) - float(np.median(xs))
    for _ in range(2):
        xs[1:-1] = 0.25 * xs[:-2] + 0.5 * xs[1:-1] + 0.25 * xs[2:]
    for f, x in zip(frames, xs):
        f["offset"][0] = x
        for s in f["soles"].values():
            s[0] += x


LEG_SINK = 0.55  # studs a leg may slide up into the torso (a bent knee)
LEG_DROP = 0.06  # studs a leg may slide down out of it (more shows a gap at the hip)
LEG_SHIFT = 0.3  # studs a planted leg may shift across to hold its sole


def _lift(pitch, roll):
    """How far the middle of a sole sits above the leg's lowest corner when the leg is tilted (studs)."""
    world = posekit.R(pitch, 0, roll)
    return -min((world @ np.array([x, 0.0, z]))[1] for x in (-0.5, 0.5) for z in (-0.5, 0.5))


def pin_feet(frames, hold=True):
    """Feet on the floor stay where they landed: through each stretch a sole is down, it is held at the place it
    first touched, its lowest corner on the floor (the leg keeps its tilt and slides by the difference, within
    what an R6 leg can show: up into the hip for a bent knee, hardly down out of it). hold=False lets every foot
    follow the tracked leg (for steps that brush the floor, like the Griddy's heel taps)."""
    held = {}
    for f in frames:
        root = tuple(f["joints"]["root"])
        offset = f["offset"]
        for joint, (side, pitch, roll, bend, down) in f["legs"].items():
            sole = f["soles"][joint]
            if down and hold:
                spot = held.setdefault(joint, np.array([sole[0], 0.0, sole[2]]))
                foot = np.array([spot[0], _lift(pitch, roll), spot[2]])
            else:
                held.pop(joint, None)
                foot = sole
            angles, slide = posekit.planted_slide(side, tuple(foot), root, tuple(offset), pitch=pitch, roll=roll)
            axis = posekit.R(*angles) @ np.array([0.0, 1.0, 0.0])  # up the leg, torso frame
            slide = np.array(slide)
            along = float(slide @ axis)
            across = slide - along * axis
            n = float(np.linalg.norm(across))
            if n > LEG_SHIFT:
                across *= LEG_SHIFT / n
            slide = across + max(-LEG_DROP, min(LEG_SINK, along)) * axis
            f["joints"][joint] = J(angles, tuple(float(v) for v in slide))
    return frames


def _turn(axis, angle):
    """Rotation by `angle` (radians) about the unit `axis`."""
    x, y, z = axis
    c, s = math.cos(angle), math.sin(angle)
    k = np.array([[0, -z, y], [z, 0, -x], [-y, x, 0]])
    return np.eye(3) + s * k + (1 - c) * (k @ k)


def _arc(a, b):
    """The shortest turn taking unit vector a onto unit vector b."""
    axis = np.cross(a, b)
    s = float(np.linalg.norm(axis))
    c = float(np.clip(a @ b, -1.0, 1.0))
    if s < 1e-9:
        return np.eye(3)
    return _turn(axis / s, math.atan2(s, c))


DOWN = np.array([0.0, -1.0, 0.0])


def steady_arms(frames, loop=True):
    """The arms' twist carried from frame to frame: each frame's arm turns the least it can from the frame before
    to point its new way (angles solved from a direction alone twist the arm a quarter turn as it passes out to
    the side, which shows as a spin and a speed spike). On a loop, the twist left over at the end is spread back
    through the clip so the loop closes. Then each fist is slid to its target again."""
    for joint, side in (("rShoulder", 1), ("lShoulder", -1)):
        dirs = []
        for f in frames:
            r = f["joints"][joint]["r"]
            dirs.append(posekit.R(*r) @ DOWN)
        turns = [_arc(DOWN, dirs[0])]
        for a, b in zip(dirs, dirs[1:]):
            turns.append(_arc(a, b) @ turns[-1])
        if loop and len(turns) > 2:
            end = _arc(dirs[-1], dirs[0]) @ turns[-1]
            rest = end @ turns[0].T  # a turn about dirs[0]
            angle = math.atan2(float(dirs[0] @ np.array([rest[2, 1] - rest[1, 2], rest[0, 2] - rest[2, 0],
                                                         rest[1, 0] - rest[0, 1]])) / 2, (np.trace(rest) - 1) / 2)
            n = len(turns)
            turns = [_turn(dirs[i], -angle * i / n) @ turns[i] for i in range(n)]
        for f, m in zip(frames, turns):
            angles = posekit.euler(m)
            target = f["targets"][joint]
            fist = fist_at(side, angles)
            slide = _clamp_slide(np.array(target) - fist, m @ DOWN)
            f["joints"][joint] = J(angles, tuple(round(float(v), 3) for v in slide))
    return frames


def between(frames, t0, t1):
    """The solved frames from t0 to t1 (clip time)."""
    return [f for f in frames if t0 - 1e-6 <= f["t"] <= t1 + 1e-6]


def keys(m, frames, ease="smooth"):
    """Every solved frame as a key on Motion m."""
    for f in frames:
        m.key(round(f["t"], 4), ease, offset=tuple(float(v) for v in f["offset"]), **f["joints"])
    return m


def capture(m, clip, lead, t0, t1, loop=True, hold=True, **options):
    """The usual run: track file -> smoothed -> solved -> the stretch t0..t1 (clip time) with feet pinned and arms
    steadied -> keys on m. Returns the solved frames."""
    frames, _sizes = solve(Take(clip).smooth(), lead=lead, **options)
    frames = between(frames, t0, t1)
    pin_feet(frames, hold=hold)
    steady_arms(frames, loop=loop)
    keys(m, frames)
    return frames


__all__ = ["Take", "solve", "pin_feet", "steady_arms", "between", "keys", "capture"]
