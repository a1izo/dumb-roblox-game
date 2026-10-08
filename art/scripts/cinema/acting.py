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


def walking(m, t0, t1, blend=0.35, speed=4.0):
    """The legs walk between t0 and t1, easing in and out over `blend` seconds, at `speed` studs a second
    (the game's walk is 4; slower walks take shorter, slower steps). The actor's path must cover the
    same distance meanwhile, so the soles do not slide. Plant the feet outside t0..t1."""
    from gait import WALK, Gait

    period = WALK.period * (4.0 / speed) ** 0.5
    g = Gait("walk_" + m.name, period, speed * period, WALK.stance, WALK.lift * min(1.0, speed / 4.0), WALK.note)

    def fn(t, pose, off):
        if t <= t0 - blend or t >= t1 + blend:
            return
        u = min(1.0, (t - (t0 - blend)) / blend, ((t1 + blend) - t) / blend)
        w = u * u * (3 - 2 * u)
        phase = max(0.0, t - t0) / g.period % 1.0
        bob = math.cos(4 * math.pi * (phase - g.stance * 0.25))
        off[1] += w * (-0.1 - 0.05 * bob)
        root = tuple(pose["root"][:3]) if "root" in pose else (0.0, 0.0, 0.0)
        for key, leg in g.legs(phase, root, tuple(off)).items():
            new = np.array([*leg["r"], *leg["p"]], float)
            old = pose.get(key, np.zeros(6))
            pose[key] = old * (1 - w) + new * w

    m.extra(fn)
    return m


def beat(m, t, dur=0.4, antic=0.15, over=0.1, offset=None, **joints):
    """A pose that lands at `t` after a move of `dur` seconds, acted rather than slid: the body first draws
    back a little the other way (anticipation), swings a little past the pose (overshoot) and settles into
    it. Every joint not named holds still. `offset` (x, y, z) moves the body the same way."""
    from motion import _vec

    t0 = max(0.0, t - dur)
    settle = min(m.length, t + dur * 0.6)
    for joint, value in joints.items():
        target = _vec(value)
        ch = m.channels.get(joint)
        prev = ch.value(t0) if ch is not None and ch.keys else np.zeros(6)
        delta = target - prev
        steps = [(t0, prev, "smooth"), (t0 + (t - t0) * 0.3, prev - delta * antic, "smooth"),
                 (t, target + delta * over, "out"), (settle, target, "smooth")]
        for time, vec, ease in steps:
            if ch is not None and any(abs(k[0] - time) < 1e-6 for k in ch.keys):
                continue
            m.key(time, ease, **{joint: J(vec[:3], vec[3:])})
            ch = m.channels[joint]
    if offset is not None:
        prev = m.offset.value(t0) if m.offset.keys else np.zeros(3)
        target = np.array(offset, float)
        delta = target - prev
        for time, vec, ease in ((t0, prev, "smooth"), (t0 + (t - t0) * 0.3, prev - delta * antic, "smooth"),
                                (t, target + delta * over * 0.5, "out"), (settle, target, "smooth")):
            if not any(abs(k[0] - time) < 1e-6 for k in m.offset.keys):
                m.offset.add(time, vec, ease)
    return m


def hold(m, t, **joints):
    """Keys the joints at their current values at t (a pose held until the next beat)."""
    for joint in joints or m.channels:
        ch = m.channels.get(joint)
        if ch is not None and ch.keys and not any(abs(k[0] - t) < 1e-6 for k in ch.keys):
            v = ch.value(t)
            m.key(t, **{joint: J(v[:3], v[3:])})
    if m.offset.keys and not any(abs(k[0] - t) < 1e-6 for k in m.offset.keys):
        m.offset.add(t, m.offset.value(t), "smooth")
    return m
