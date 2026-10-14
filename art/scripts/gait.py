"""A simple cycle maker for the R6 rig (the shop's strolls and the cutscenes' walks use it; the game's own
movement set is built in locomotion.py), and the earlier walk's
measures the cutscenes' walks are sized from (WALK below).

The R6 way: legs swing from the hip and slide in
and out of it like knees bending, so a planted sole stays exactly where it lands while the body
travels over it, and a swinging leg lifts by shortening (sliding up) rather than kicking out.

Each leg follows its sole. During the stance the sole is fixed to the ground and moves back as fast
as the body moves forward; the leg points from the hip to the sole and slides to fit (shorter at
mid-stance, when the body is lowest: the knee taking the weight). During the swing the sole travels
forward on an arc and the leg shortens to lift it clear. Each clip records its stride (studs per
cycle), so the game advances the cycle by distance and feet never slide.

The upper body is driven by the same phase with small delays (the arms trail the legs, the head
trails the body), which is what makes the motion flow.

Angles use the game's joint convention (animlib.py); positions are Roblox studs in the
character's frame (x right, y up, z backwards, forward is -z).
"""

import math

from animlib import J, clip
from posekit import hip_world, planted_slide

SOLE_X = 0.5  # the middle of a sole, from the body's middle line


def smoothstep(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def wave(phase, lag=0.0):
    """cos of the cycle, delayed by `lag` (a fraction of the cycle)."""
    return math.cos(2 * math.pi * (phase - lag))


class Gait:
    """One looping locomotion cycle. phase 0 = right foot touches down."""

    def __init__(self, name, period, stride, stance, lift, note, width=0.0):
        self.name = name
        self.period = period
        self.stride = stride  # studs per cycle
        self.stance = stance  # fraction of the cycle a foot is on the ground
        self.lift = lift  # how high a swinging sole rises (studs)
        self.width = width  # extra distance between the soles (studs)
        self.note = note

    def sole(self, phase):
        """(height, z) of a sole at its own phase, in the body frame (z back +)."""
        s = self.stance
        travel = self.stride * s  # how far the body moves over a planted sole
        if phase < s:
            u = phase / s
            return 0.0, -travel / 2 + travel * u
        u = (phase - s) / (1 - s)
        z = travel / 2 - travel * smoothstep(u)
        h = self.lift * math.sin(math.pi * u) ** 1.5
        return h, z

    def legs(self, phase, root, offset):
        out = {}
        for side, key, own in ((1, "rHip", phase), (-1, "lHip", (phase + 0.5) % 1)):
            h, z = self.sole(own)
            foot = (side * (SOLE_X + self.width), h, z)
            hip = hip_world(side, root, offset)
            # the leg leans from the hip towards its sole; it slides along to fit the distance
            pitch = math.degrees(math.atan2(hip[2] - foot[2], hip[1] - foot[1]))
            angles, slide = planted_slide(side, foot, root, offset, pitch=pitch)
            out[key] = J(angles, slide)
        return out


def build_cycle(g, samples, pose_fn):
    """Keys `samples` poses per cycle. pose_fn(phase) -> (joints, offset)."""
    c = clip(g.name, g.period, loop=True, note=g.note)
    c.stride = g.stride
    c.stance = g.stance
    for i in range(samples):
        phase = i / samples
        joints, offset = pose_fn(phase)
        c.pose(phase * g.period, "linear", offset=offset, **joints)
    return c


# The earlier walk's measures: the cutscenes size their actors' walks from them (cinema/acting.py).

WALK = Gait("walk", period=1.15, stride=4.6, stance=0.62, lift=0.3,
            note="A serious walk: long steps, slouched, shoulders rolled forward, arms low and close.")
