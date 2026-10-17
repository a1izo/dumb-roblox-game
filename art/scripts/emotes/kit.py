"""Helpers for the rebuilt emotes (2026-10-17): every clip in this package copies a real reference, frame by
frame where the reference allows (art/refs/emotes/<clip>.toml holds the source, its timestamps and the beats).

R6 has rigid arms and legs: no elbows, wrists, knees or fingers. A bent elbow is faked by turning the arm along
its forearm and sliding it so the fist lands where the hand was; reach() does that maths, so a pose copied off
a reference frame puts the fist where the dancer's hand is.

Positions here are in the torso's frame, Roblox studs: x right, y up, z backwards (forward is -z), the torso's
middle at the origin (it is 2 tall, 2 wide, 1 deep; the head's middle is 1.5 up).
"""

import math

import numpy as np

import posekit
from animlib import J
from motion import _vec


def lift(m, joint, keys):
    """Takes a joint out of what plant() (or its keys) gave it for a while: keys are (t, weight, value), and
    the joint blends from its own pose towards `value` by `weight` (0: left alone), easing between keys. For a
    leg kicked or raised while the other stays planted."""
    pts = [(float(t), float(w), _vec(v)) for t, w, v in keys]

    def fn(t, pose, _offset):
        for (t0, w0, v0), (t1, w1, v1) in zip(pts, pts[1:]):
            if t0 - 1e-9 <= t <= t1 + 1e-9:
                u = (t - t0) / (t1 - t0) if t1 > t0 else 1.0
                u = 0.5 - 0.5 * math.cos(math.pi * u)
                w = w0 + (w1 - w0) * u
                v = v0 + (v1 - v0) * u
                base = pose[joint] if joint in pose else np.zeros(6)
                pose[joint] = base * (1 - w) + v * w
                return

    m.extra(fn)
    return m


def raise_leg(m, joint, t_up, t_peak, t_hold, t_down, value):
    """lift() for the usual shape: up from t_up, fully at `value` from t_peak to t_hold, down by t_down."""
    return lift(m, joint, ((t_up, 0, value), (t_peak, 1, value), (t_hold, 1, value), (t_down, 0, value)))

# Points on and around the body (torso frame) that hands go to.
FACE = (0.0, 1.45, -0.75)
MOUTH = (0.0, 1.25, -0.7)
CHIN = (0.0, 1.05, -0.7)
CHEST = (0.0, 0.45, -0.75)
BELLY = (0.0, -0.35, -0.75)
OVERHEAD = (0.0, 2.8, -0.2)  # as high as a straight R6 arm reaches


def hip(side):
    """The fist resting on the hip (side 1 right, -1 left)."""
    return (side * 1.08, -0.85, -0.05)


def akimbo(side):
    """Hands on the hips, elbows out: the arm angled out at the bottom (R6's way to show the elbow) with the
    fist slid in to the hip."""
    return reach(side, (side * 1.18, -0.72, 0.12), direction=(side * 0.36, -1.0, 0.22))


def beats(bpm):
    """The length of one beat in seconds."""
    return 60.0 / bpm


class Clock:
    """Times on a reference: `at(src)` turns a time in the source video into clip time (seconds), from the
    segment's start, optionally snapped to the nearest eighth of a beat."""

    def __init__(self, start, bpm=None):
        self.start = start
        self.bpm = bpm

    def at(self, src, snap=False):
        t = src - self.start
        if snap and self.bpm:
            step = beats(self.bpm) / 2
            t = round(t / step) * step
        return round(t, 4)


_HAND = np.array([0.0, -0.85, 0.0, 1.0])  # the fist's middle in an arm's own frame
_SIDES = {1: ("rShoulder", "Right Arm"), -1: ("lShoulder", "Left Arm")}


def arm_angles(direction):
    """Shoulder angles (x, 0, z) that point an arm along `direction` (shoulder to fist, torso frame)."""
    d = np.array(direction, float)
    d = d / np.linalg.norm(d)
    c = math.asin(max(-1.0, min(1.0, d[0])))
    a = math.atan2(-d[2], -d[1]) if abs(math.cos(c)) > 1e-6 else 0.0
    return (math.degrees(a), 0.0, math.degrees(c))


def _solve(side, tgt, d, twist):
    joint, part = _SIDES[side]
    angles = arm_angles(d)
    angles = (angles[0], twist, angles[2])
    world = posekit.fk({joint: angles})
    torso = world["Torso"]
    hand = (world[part] @ _HAND)[:3]
    goal = (torso @ np.array([*tgt, 1.0]))[:3]
    slide = torso[:3, :3].T @ (goal - hand)
    return angles, slide


def reach(side, target, direction=None, twist=0.0, max_slide=0.55):
    """The arm value (animlib.J) that puts this side's fist on `target` (torso frame). With no `direction` the
    arm is straight from the shoulder; with one (the way the forearm points, shoulder side to fist) the arm leans
    that way as far as it can while sliding no more than max_slide studs, so it never comes off its shoulder
    (R6's bent elbow is a lean plus a slide). A target out of reach gets the fist as near as the slide allows."""
    shoulder = np.array([side * 1.5, 1.0, 0.0])
    tgt = np.array(target, float)
    straight = tgt - shoulder
    straight = straight / np.linalg.norm(straight)
    angles, slide = _solve(side, tgt, straight, twist)
    if direction is not None:
        wanted = np.array(direction, float)
        wanted = wanted / np.linalg.norm(wanted)
        lo, hi = 0.0, 1.0
        for _ in range(14):
            mid = (lo + hi) / 2
            d = straight * (1 - mid) + wanted * mid
            a, s = _solve(side, tgt, d / np.linalg.norm(d), twist)
            if np.linalg.norm(s) <= max_slide:
                angles, slide, lo = a, s, mid
            else:
                hi = mid
    n = float(np.linalg.norm(slide))
    if n > max_slide:
        slide = slide * (max_slide / n)
    return J(angles, tuple(round(float(v), 3) for v in slide))


def hold(part, pose, position, rotation=(0.0, 0.0, 0.0)):
    """EmoteMeta `at` steps for a prop welded to `part` ("Right Arm", "Left Arm", "Head", "Torso") so that in
    `pose` (joint values, e.g. {"lShoulder": reach(...)}) its pivot sits at `position` (torso frame) turned by
    `rotation` (degrees, CFrame.Angles, torso frame). Author the key pose, then solve the hold for it."""
    world = posekit.fk(pose)
    target = world["Torso"] @ _cf(position, rotation)
    local = np.linalg.inv(world[part]) @ target
    p = [round(float(v), 3) for v in local[:3, 3]]
    r = [round(float(v), 2) for v in posekit.euler(local[:3, :3])]
    return [{"p": p}, {"r": r}]


def basis_angles(y_axis, z_axis):
    """CFrame.Angles degrees (x, y, z) of the frame whose +y points along `y_axis` and whose +z is as near
    `z_axis` as it can be (made square to y)."""
    y = np.array(y_axis, float)
    y = y / np.linalg.norm(y)
    z = np.array(z_axis, float)
    z = z - y * (z @ y)
    z = z / np.linalg.norm(z)
    x = np.cross(y, z)
    m = np.column_stack([x, y, z])
    return tuple(round(float(a), 2) for a in posekit.euler(m))


def arm_direction(side, value):
    """Which way an arm points (shoulder to fist, torso frame) for an arm value."""
    joint, part = _SIDES[side]
    world = posekit.fk({joint: value})
    m = np.linalg.inv(world["Torso"]) @ world[part]
    return -m[:3, 1]


def _cf(position, rotation):
    m = np.identity(4)
    m[:3, :3] = posekit.R(*rotation)
    m[:3, 3] = position
    return m


def luau_steps(steps):
    """Steps as EmoteMeta writes them."""
    out = []
    for s in steps:
        key = "p" if "p" in s else "r"
        out.append("{ %s = { %s } }" % (key, ", ".join(f"{0.0 if abs(v) < 5e-4 else v:g}" for v in s[key])))
    return "{ " + ", ".join(out) + " }"


def fist_at(side, value):
    """Where this side's fist ends up for an arm value (torso frame), to check a pose."""
    joint, part = _SIDES[side]
    world = posekit.fk({joint: value})
    return (np.linalg.inv(world["Torso"]) @ (world[part] @ _HAND))[:3]


__all__ = ["reach", "arm_angles", "fist_at", "hip", "beats", "Clock", "FACE", "MOUTH", "CHIN", "CHEST", "BELLY",
           "OVERHEAD"]
