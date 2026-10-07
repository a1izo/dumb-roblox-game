"""Shared acting for the cutscenes: seated bodies, standing bodies, hands, the usual overlap.

Poses are game-convention joint values (animlib.py); `seated(...)` works out the body's height so the
hips rest on a seat `seat` studs above the floor (the actor's path stands on the floor in front of
it, under the hips)."""

import math

import numpy as np

import posekit
from animlib import J

ARMS = ("rShoulder", "lShoulder")


def soft(m, head=3.0, arms=2.4, head_damp=0.72, arm_damp=0.62):
    """The usual overlap: the head and the arms trail the body a little."""
    m.follow("neck", head, head_damp)
    m.follow(ARMS, arms, arm_damp)
    return m


def seat_offset(joints, seat, xz=(0.0, 0.0)):
    """The body offset that rests these joints' hips on a seat `seat` studs high."""
    return posekit.on_seat(joints, (xz[0], 0.0, xz[1]), seat)


def seated(m, t, ease="smooth", seat=1.6, lean=-8.0, legs=82.0, turn=0.0, xz=(0.0, 0.0), **upper):
    """A key sitting on a seat: thighs forward, the body leaning `lean` degrees and turned `turn` degrees
    (the thighs stay square to the seat)."""
    joints = dict(root=(lean, turn, 0), rHip=J((legs, -turn, 3), (0, -0.05, 0)), lHip=J((legs, -turn, -3), (0, -0.05, 0)))
    joints.update(upper)
    off = seat_offset(joints, seat, xz)
    m.key(t, ease, offset=off, **joints)
    return off


# Arms at a desk: hands on the desk top in front of a seated body.
def desk_arms(write=0.0, look=0.0):
    """(rShoulder, lShoulder) for writing at a desk; write in -1..1 moves the pen along the line."""
    r = J((70 + 2 * write, -6 + 6 * write, -14 + 5 * write), (-0.14 + 0.1 * write, 0.04, -0.3))
    left = J((64, 0, 22), (0.2, 0.04, -0.3))
    return r, left


def facing(frm, to):
    """The yaw that faces from (x, z) towards (x, z) (yaw 0 faces -z, +90 faces -x)."""
    dx, dz = to[0] - frm[0], to[1] - frm[1]
    return math.degrees(math.atan2(-dx, -dz))


PRAY = dict(rShoulder=J((62, 0, -30), (-0.26, 0.1, -0.22)), lShoulder=J((62, 0, 30), (0.26, 0.1, -0.22)))


def kneel(m, t, ease="smooth", lean=-8.0, head=-28.0, turn=0.0, **upper):
    """A key kneeling on both knees: the legs folded back along the floor (the shins), the body low on them
    (its height worked out so the legs rest on the floor)."""
    # the legs stay down on the floor however far the body bows over them
    fold = -84.0 - (lean + 8.0)
    joints = dict(root=(lean, turn, 0), neck=(head, 0, 0), rHip=J((fold, 0, 2), (0, 0.15, 0.3)),
                  lHip=J((fold, 0, -2), (0, 0.15, 0.3)))
    joints.update(upper)
    m.key(t, ease, floor=True, **joints)


def walking(m, t0, t1, blend=0.35):
    """The legs walk (the game's walk) between t0 and t1, easing in and out over `blend` seconds. The
    actor's path must cover WALK.stride / WALK.period (4 studs a second) meanwhile, so the soles do
    not slide. Plant the feet outside t0..t1."""
    from gait import WALK

    def fn(t, pose, off):
        if t <= t0 - blend or t >= t1 + blend:
            return
        u = min(1.0, (t - (t0 - blend)) / blend, ((t1 + blend) - t) / blend)
        w = u * u * (3 - 2 * u)
        phase = max(0.0, t - t0) / WALK.period % 1.0
        bob = math.cos(4 * math.pi * (phase - WALK.stance * 0.25))
        off[1] += w * (-0.1 - 0.05 * bob)
        root = tuple(pose["root"][:3]) if "root" in pose else (0.0, 0.0, 0.0)
        for key, leg in WALK.legs(phase, root, tuple(off)).items():
            new = np.array([*leg["r"], *leg["p"]], float)
            old = pose.get(key, np.zeros(6))
            pose[key] = old * (1 - w) + new * w

    m.extra(fn)
    return m
