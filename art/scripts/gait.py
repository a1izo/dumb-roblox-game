"""Movement clips (idle, walk, run, land) for the R6 rig.

R6 legs are single rigid blocks that swing from the hip, so a stance leg is an inverted pendulum
rolling over its sole: first about the heel edge, then (once the leg is upright and the sole lies
flat) about the toe edge. That roll is solved exactly, so a planted foot never slides when the game
plays the cycle at the speed it was made for, and the pelvis rises and falls the way rigid legs make
it (a small vault over each stance; in a run, a flight between steps). The swing leg swings through
and lifts clear by rolling in a little. Each clip records its stride (studs per cycle) for the game.

Angles use the game's joint convention (animlib.py); positions are Roblox studs in the
character's frame (x right, y up, z backwards, forward is -z).
"""

import math

import numpy as np

from animlib import clip
from posekit import HIP_X, HIP_Y, LEG_LENGTH, R, euler, hip_world, leg_contact

SOLE = 1.0  # the leg block is one stud deep (z)
HALF = SOLE / 2


def smoothstep(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def bisect(f, lo, hi, target, rounds=60):
    """x in [lo, hi] with f(x) = target, for a monotone f."""
    increasing = f(hi) > f(lo)
    for _ in range(rounds):
        mid = (lo + hi) / 2
        if (f(mid) < target) == increasing:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


# Stance --------------------------------------------------------------------------------------------


def heel_z(theta):
    """Where the heel (back lower edge) of a leg swung forward by theta is, relative to the hip (z, back +)."""
    t = math.radians(theta)
    return HALF * math.cos(t) - LEG_LENGTH * math.sin(t)


def toe_z(theta):
    t = math.radians(theta)
    return -LEG_LENGTH * math.sin(t) - HALF * math.cos(t)


def travel(theta0):
    """Distance the body travels over a whole stance that starts at +theta0 and ends at -theta0."""
    t = math.radians(theta0)
    return 1 - math.cos(t) + 2 * LEG_LENGTH * math.sin(t) * SOLE


def theta_for_travel(d):
    return bisect(travel, 0.0, 60.0, d)


class Stance:
    """A leg planted for a stance that covers `distance` studs of travel (heel roll, then toe roll)."""

    def __init__(self, distance):
        self.distance = distance
        self.theta0 = theta_for_travel(distance)
        self.z0 = heel_z(self.theta0)
        self.u1 = HALF - self.z0  # travel until the sole lies flat

    def state(self, u):
        """(leg angle in degrees, hip height above the floor) after `u` studs of travel."""
        u = max(0.0, min(self.distance, u))
        if u <= self.u1:
            theta = bisect(heel_z, 0.0, self.theta0, self.z0 + u)
            t = math.radians(theta)
            return theta, LEG_LENGTH * math.cos(t) + HALF * math.sin(t)
        theta = bisect(toe_z, -self.theta0, 0.0, -HALF + (u - self.u1))
        t = math.radians(theta)
        return theta, LEG_LENGTH * math.cos(t) - HALF * math.sin(t)


# One leg ------------------------------------------------------------------------------------------------


def leg_joint(side, world_pitch, world_roll, root):
    """Hip angles (in the torso's frame) for a leg that should be `world_pitch` degrees forward and
    `world_roll` degrees out in the world, whatever the torso is doing."""
    m = R(*root).T @ R(world_pitch, 0, world_roll)
    return euler(m)


def clear_roll(side, pitch, root, offset, clearance, limit=10.0):
    """The smallest inward roll (degrees) that lifts the lowest corner of a swinging leg clear. The
    hip sits at the outer top edge of the leg block, so only an inward roll lifts it: pitching the
    leg or rolling it out only lowers its corners."""

    def low(roll):
        hip = leg_joint(side, pitch, -side * roll, root)
        return leg_contact(side, hip, root, offset)[1]

    if low(0.0) >= clearance:
        return 0.0
    if low(limit) < clearance:
        return limit
    return bisect(low, 0.0, limit, clearance)


class Gait:
    """One looping locomotion cycle. phase 0 = right foot touches down."""

    def __init__(self, name, period, stride, stance, note, apex=0.0, swing_peak=40.0, clearance=0.03):
        self.name = name
        self.period = period
        self.stride = stride
        self.stance_fraction = stance
        self.note = note
        self.apex = apex  # how high the pelvis rises in the flight of a run
        self.swing_peak = swing_peak  # the swing leg's farthest reach forward (degrees)
        self.clearance = clearance
        self.stance = Stance(stride * stance)

    def leg(self, phase):
        """(world pitch, hip height or None while swinging) for one leg at its own phase."""
        s = self.stance_fraction
        st = self.stance
        if phase < s:
            theta, height = st.state(st.distance * phase / s)
            return theta, height
        # swing: from the toe-off angle round to the touch-down angle, reaching out a little
        # further forward on the way (a run reaches and pulls back before the foot lands)
        u = (phase - s) / (1 - s)
        base = -st.theta0 + 2 * st.theta0 * smoothstep(u)
        reach = max(0.0, self.swing_peak - st.theta0)
        bump = math.sin(math.pi * u) ** 2 * (1 - u) / 0.385
        return base + reach * bump, None

    def flight_height(self, phase):
        """Pelvis height in the air: a parabola from the end of one stance to the start of the next."""
        s = self.stance_fraction
        st = self.stance
        end_h = st.state(st.distance)[1]
        start_h = st.state(0)[1]
        u = ((phase - s) % 0.5) / (0.5 - s)
        return end_h + (start_h - end_h) * u + self.apex * 4 * u * (1 - u)

    def pose(self, phase, root, sway=0.0):
        """The hip joints and the pelvis offset at a cycle phase."""
        planted = {}
        swinging = {}
        for side, key, own in ((1, "r", phase), (-1, "l", (phase + 0.5) % 1)):
            theta, height = self.leg(own)
            if height is None:
                swinging[key] = (side, theta)
            else:
                planted[key] = (side, theta, height)
        if planted:
            lift = sum(h - hip_world(side, root, (0, 0, 0))[1] for side, _, h in planted.values()) / len(planted)
        else:
            lift = self.flight_height(phase) - hip_world(1, root, (0, 0, 0))[1]
        offset = (sway, lift, 0.0)
        out = {}
        for key, (side, theta, _) in planted.items():
            out[key + "Hip"] = leg_joint(side, theta, 0.0, root)
        for key, (side, theta) in swinging.items():
            roll = clear_roll(side, theta, root, offset, self.clearance)
            out[key + "Hip"] = leg_joint(side, theta, -side * roll, root)
        return out, offset


def build_cycle(g, samples, pose_fn):
    """Keys `samples` poses per cycle. pose_fn(phase) -> dict of joint values and offset."""
    c = clip(g.name, g.period, loop=True, note=g.note)
    c.stride = g.stride
    for i in range(samples):
        phase = i / samples
        joints, offset = pose_fn(phase)
        c.pose(phase * g.period, "linear", offset=offset, **joints)
    return c


# Run ------------------------------------------------------------------------------------------------
# Full speed in the game is 16 studs/s. Grounded: a steady forward lean, arms pumping close to the
# body, a low flight between steps.

RUN = Gait("run", period=0.54, stride=16 * 0.54, stance=0.22, apex=0.28, swing_peak=34,
           note="Run at 16 studs/s: planted soles never slide, a low flight between steps.")


def run_pose(phase):
    s = RUN.stance_fraction
    yaw = 6 * math.cos(2 * math.pi * phase)  # right hip forward at the right touch-down
    roll = 1.5 * math.cos(2 * math.pi * (phase - s / 2))
    root = (-8, yaw, roll)
    legs, offset = RUN.pose(phase, root, sway=0.03 * math.cos(2 * math.pi * (phase - s / 2)))
    swing = math.cos(2 * math.pi * phase)  # +1: right arm back, left arm forward
    joints = dict(
        root=root,
        neck=(7, -0.8 * yaw, 0),
        rShoulder=(10 - 40 * swing, 0, 3),
        lShoulder=(10 + 40 * swing, 0, -3),
    )
    joints.update(legs)
    return joints, offset


# Walk -----------------------------------------------------------------------------------------------
# A plain walk at about 3 studs/s, used while speeding up and slowing down.

WALK = Gait("walk", period=0.9, stride=2.4, stance=0.62, swing_peak=24,
            note="Walk at about 2.7 studs/s; soles stay planted.")


def walk_pose(phase):
    s = WALK.stance_fraction
    yaw = 3 * math.cos(2 * math.pi * phase)
    roll = 1.2 * math.cos(2 * math.pi * (phase - s / 2))
    root = (-1, yaw, roll)
    legs, offset = WALK.pose(phase, root, sway=0.03 * math.cos(2 * math.pi * (phase - s / 2)))
    swing = math.cos(2 * math.pi * phase)
    joints = dict(
        root=root,
        neck=(1, -0.6 * yaw, 0),
        rShoulder=(-16 * swing, 0, 1.5),
        lShoulder=(16 * swing, 0, -1.5),
    )
    joints.update(legs)
    return joints, offset


# Idle -----------------------------------------------------------------------------------------------


def idle_clip():
    from posekit import planted_legs

    c = clip("idle", 6.0, loop=True, note="Standing still: a slow breath, the weight settling, arms at the sides.")
    steps = 36
    for i in range(steps):
        t = i / steps
        breath = math.sin(2 * math.pi * t * 3)  # three breaths per loop
        shift = math.sin(2 * math.pi * t)  # the weight settles a little to one side and back
        offset = (0.025 * shift, 0.004 * breath, 0.0)
        root = (0.4 * breath, 1.2 * math.sin(2 * math.pi * t + 0.8), -0.6 * shift)
        legs = planted_legs(offset, root, stance=0.02)
        c.pose(
            t * 6.0,
            "linear",
            offset=offset,
            root=root,
            neck=(-0.3 * breath, 3 * math.sin(2 * math.pi * t + 1.9), 0.3 * shift),
            rShoulder=(0.6 * breath, 0, 1.0 + 0.3 * breath),
            lShoulder=(0.6 * breath, 0, -1.0 - 0.3 * breath),
            **legs,
        )
    return c


# Landing --------------------------------------------------------------------------------------------


def land_clip():
    """A small give in the body on landing, then it settles."""
    from posekit import planted_legs

    c = clip("land", 0.4, note="A small give on landing; faded out over the ground pose.")
    keys = [
        (0.0, -0.02, -2, 8),
        (0.08, -0.1, -7, 12),
        (0.22, -0.04, -3, 5),
        (0.4, 0.0, 0, 1),
    ]
    for t, drop, lean, arms in keys:
        offset = (0, drop, 0.02)
        root = (lean, 0, 0)
        legs = planted_legs(offset, root, stance=0.04)
        c.pose(
            t,
            "smooth",
            offset=offset,
            root=root,
            neck=(-lean * 0.5, 0, 0),
            rShoulder=(arms, 0, 1.5 + arms * 0.2),
            lShoulder=(arms, 0, -1.5 - arms * 0.2),
            **legs,
        )
    return c


def build():
    run = build_cycle(RUN, 36, run_pose)
    walk = build_cycle(WALK, 36, walk_pose)
    idle_clip()
    land_clip()
    return {"run": run, "walk": walk}
