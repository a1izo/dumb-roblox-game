"""Cameras that look at the actors: framings worked out from where an actor's head and body really are at
that moment (their path through the set plus their acting clip, through the R6 rig), not from typed
coordinates.

    s.frame(t, "self", "medium", angle=30)            # waist up, from 30 degrees to their left
    s.frame(t, "self", "close", angle=-20, cut=True)  # a cut to head and shoulders
    s.frame(t, "self", "ots", other="ally:1")         # over self's shoulder, onto ally:1
    s.frame(t, "self", "two", other="butler")         # both in frame
    s.follow(t0, t1, "self", "full", angle=150)       # the camera keeps them framed while they move

`angle` is degrees round the subject from straight in front of their face (+ to their left, 180 behind);
`height` raises or lowers the camera from the framing's own eye line (studs); `dist` scales the distance;
`tilt` aims a little above (+) or below the framing's own target (studs)."""

import math

import numpy as np

import posekit
from animlib import J
from motion import MOTIONS

# kind: (the part aimed at, its height offset, distance, vertical fov, camera height above the target)
FRAMINGS = {
    "extreme": ("Head", 0.05, 3.2, 30.0, 0.0),  # the face
    "close": ("Head", -0.35, 5.4, 32.0, 0.1),  # head and shoulders
    "medium": ("Torso", 0.45, 7.6, 36.0, 0.7),  # from the waist up
    "full": ("Torso", -0.4, 11.5, 40.0, 1.4),  # the whole body
    "wide": ("Torso", -0.4, 20.0, 44.0, 4.0),  # the body and the room round it
    "low": ("Torso", 0.6, 7.0, 42.0, -2.0),  # from below: power
    "high": ("Torso", -0.2, 7.5, 42.0, 6.0),  # from above: smallness
    "insert": ("hand", 0.0, 3.4, 30.0, 0.8),  # a hand and what it holds or touches
}


def actor(shot, slot):
    for a in shot.actors:
        if a.slot == slot:
            return a
    raise KeyError(f"{shot.name}: no actor {slot}")


def _pose(a, t):
    motion = a.motion or MOTIONS.get(a.clip)
    if motion is None:
        return {}, (0.0, 0.0, 0.0)
    pose, off = motion.sample(min(max(t - a.at, 0.0), motion.length))
    joints = {j: J(v[:3], v[3:]) for j, v in pose.items()}
    return joints, tuple(off)


def body(shot, slot, t):
    """(the actor's place on the floor, their yaw, {part: world position}) at time t."""
    a = actor(shot, slot)
    v = a.path.value(t)
    place, yaw = np.array(v[:3]), float(v[3])
    joints, off = _pose(a, t)
    parts = posekit.fk(joints, off)
    turn = np.array([[math.cos(math.radians(yaw)), 0, math.sin(math.radians(yaw))], [0, 1, 0],
                     [-math.sin(math.radians(yaw)), 0, math.cos(math.radians(yaw))]])
    world = {name: place + turn @ m[:3, 3] for name, m in parts.items()}
    # the hands: the far end of each arm
    for arm, name in (("Right Arm", "hand"), ("Left Arm", "lhand")):
        m = parts[arm]
        world[name] = place + turn @ (m[:3, 3] + m[:3, :3] @ np.array([0.0, -0.9, 0.0]))
    return place, yaw, world


def part(shot, slot, t, name="Head"):
    return body(shot, slot, t)[2][name]


def facing_dir(yaw):
    """The way a body with this yaw faces (yaw 0 faces -z)."""
    a = math.radians(yaw)
    return np.array([-math.sin(a), 0.0, -math.cos(a)])


def camera(shot, t, slot, kind="medium", angle=0.0, height=0.0, dist=1.0, tilt=0.0, other=None, side=0.0, aim=None):
    """(camera position, look-at point, fov) framing `slot` (and `other`) at time t. `aim` overrides the
    part aimed at ("hand", "lhand", "Head", "Torso"...)."""
    aim_part, aim_dy, base, fov, up = FRAMINGS["medium" if kind in ("ots", "two") else kind]
    aim_part = aim or aim_part
    _, yaw, parts = body(shot, slot, t)
    target = parts[aim_part] + np.array([0.0, aim_dy, 0.0])
    face = facing_dir(yaw)
    if kind == "ots" and other is not None:
        # over the subject's shoulder onto the other: behind and beside the subject, aimed at the other's face
        them = part(shot, other, t, "Head")
        to = them - parts["Head"]
        to[1] = 0.0
        to /= max(np.linalg.norm(to), 1e-6)
        right = np.array([-to[2], 0.0, to[0]])
        offset = right * (1.6 if side >= 0 else -1.6)
        pos = parts["Head"] - to * 3.4 * dist + offset + np.array([0.0, 0.3 + height, 0.0])
        look = them + np.array([0.0, -0.2 + tilt, 0.0])
        return pos, look, 38.0
    if kind == "two" and other is not None:
        them = part(shot, other, t, "Head")
        mid = (parts["Head"] + them) / 2 + np.array([0.0, -0.6, 0.0])
        span = np.linalg.norm((parts["Head"] - them) * np.array([1, 0, 1]))
        across = (them - parts["Head"]) * np.array([1, 0, 1])
        across /= max(np.linalg.norm(across), 1e-6)
        normal = np.array([-across[2], 0.0, across[0]])
        if normal @ face < 0:
            normal = -normal
        a = math.radians(angle)
        direction = normal * math.cos(a) + across * math.sin(a)
        d = (span / 2 + 3.0) / math.tan(math.radians(fov / 2)) * 0.62 * dist
        pos = mid + direction * d + np.array([0.0, up + height, 0.0])
        return pos, mid + np.array([0.0, tilt, 0.0]), 40.0
    a = math.radians(angle)
    left = facing_dir(yaw + 90.0)  # the subject's left
    direction = face * math.cos(a) + left * math.sin(a)
    pos = target + direction * base * dist + np.array([0.0, up + height, 0.0])
    if side:
        pos = pos + np.array([direction[2], 0.0, -direction[0]]) * side
    return pos, target + np.array([0.0, tilt, 0.0]), fov


def frame(shot, t, slot, kind="medium", ease="smooth", cut=False, fov=None, **kw):
    pos, look, auto = camera(shot, t, slot, kind, **kw)
    shot.cam(t, tuple(pos), tuple(look), fov=fov or auto, ease=ease, cut=cut)


def follow(shot, t0, t1, slot, kind="medium", step=0.25, cut=False, fov=None, **kw):
    """Keys every `step` seconds keeping `slot` framed while they move (the first key may be a cut)."""
    n = max(1, int(round((t1 - t0) / step)))
    for i in range(n + 1):
        t = t0 + (t1 - t0) * i / n
        frame(shot, t, slot, kind, ease="linear", cut=cut and i == 0, fov=fov, **kw)


def pan(shot, t0, t1, slot, pos, aim="Head", dy=0.0, fov=40.0, step=0.25, cut=False, drift=(0.0, 0.0, 0.0)):
    """A camera standing at `pos` (drifting by `drift` over the cut) that turns to keep `slot`'s `aim` part
    in the middle of the frame while they move."""
    n = max(1, int(round((t1 - t0) / step)))
    for i in range(n + 1):
        u = i / n
        t = t0 + (t1 - t0) * u
        target = part(shot, slot, t, aim) + np.array([0.0, dy, 0.0])
        p = np.array(pos, float) + np.array(drift, float) * u
        shot.cam(t, tuple(p), tuple(target), fov=fov, ease="linear", cut=cut and i == 0)


def spot(shot, t, slot, kind="medium", **kw):
    """Where `frame` would put the camera (to hold it there for a pan)."""
    pos, _, _ = camera(shot, t, slot, kind, **kw)
    return tuple(pos)
