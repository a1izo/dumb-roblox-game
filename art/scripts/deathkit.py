"""Shared acting for the deaths (the user's ask of 2026-11-07: every death redone, "very high quality"): the three
plain collapses, the eleven custom deaths and the fallen bodies' death-style clips (deaths.py) are built from these.

How a body goes down, as stage falls teach it and gravity times it (g = 35 studs/s², the real 9.8 m/s² at 0.28 m a
stud): the knees go first and the body drops onto them (a faint's knee drop takes 0.7 s, "How to Faint Safely on
Stage", the Tokyo intro's reference), then it tips over its knees (or, sat down, over its hips; or, frozen stiff, over
its toes) under gravity, a rigid rod about its foot: theta'' = 3g/2L sin theta (rod_fall). The arm on the falling side
leads the body down, or the hand props it up off the floor (an R6 arm cannot bend); the chest bounces once, the head
whips and drops, and then nothing moves.

R6 lies flat only face down (root pitch -90) or on its back (+88); on its side it rests on the lower arm. Every death
ends in one of the two (PRONE or SUPINE, near enough), still: the server locks that last pose into the joints, and a
fallen body's death style (fallen* clips) starts from it.

Angles as everywhere here: root (pitch, yaw, roll), negative pitch bends forward; offset z negative is forward. Arms:
x 0 hangs, 90 straight ahead, 180 overhead; z swings out (right +, left -). Legs: x + swings forward.
"""

import math

import numpy as np

import posekit
from animlib import J

G = 35.0  # studs/s²

REST = dict(root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))
STAND_LEGS = dict(rHip=J((0, 0, 0)), lHip=J((0, 0, 0)))

# Lying down. Face down: the legs straight back along the floor; the arms along the sides (tilted out so an end of the
# arm does not prop the body up). On the back: the legs straight, the arms a little out.
PRONE_LEGS = dict(rHip=J((-2, 0, 4)), lHip=J((-2, 0, -4)))
SUPINE_LEGS = dict(rHip=J((-2, 0, 5)), lHip=J((-4, 0, -5)))
SIDE_R, SIDE_L = J((0, 0, 8)), J((0, 0, -10))  # face down, along the sides
AHEAD_R, AHEAD_L = J((180, 0, 10)), J((180, 0, -10))  # face down, stretched out ahead over the head (flat at 180)
OUT_R, OUT_L = J((0, 0, 84)), J((0, 0, -84))  # face down or on the back: flung out to the sides
BACK_R, BACK_L = J((10, 0, 34)), J((12, 0, -30))  # on the back: a little out from the sides


def mix(a, b, u):
    """A joint value u of the way from a to b (J values or angle tuples)."""
    ra, pa = (a["r"], a["p"]) if isinstance(a, dict) else (tuple(a), (0.0, 0.0, 0.0))
    rb, pb = (b["r"], b["p"]) if isinstance(b, dict) else (tuple(b), (0.0, 0.0, 0.0))
    return J(tuple(x + (y - x) * u for x, y in zip(ra, rb)), tuple(x + (y - x) * u for x, y in zip(pa, pb)))


def clamp01(u):
    return max(0.0, min(1.0, u))


def rod_fall(t0, angle0, angle1=88.0, spin0=0.3, length=3.6, g=G, give=0.12, rate=30):
    """A rigid body tipping over about its base under gravity: a rod of `length` studs pivoting about its foot
    (theta'' = 3g/2L sin theta), from `angle0` degrees off upright with a nudge of `spin0` rad/s, until it lies at
    `angle1`; there it bounces back by `give` of its speed and falls again. Returns ([(t, degrees)] at `rate` a
    second, the moment it hits)."""
    k = 1.5 * g / length
    th, om, t, dt = math.radians(angle0), spin0, t0, 1 / 600
    flat = math.radians(angle1)
    out, hit, nxt = [(t0, angle0)], None, t0 + 1 / rate
    bounced = 0
    while bounced < 2:
        om += k * math.sin(th) * dt
        th += om * dt
        t += dt
        if th >= flat:
            th = flat
            if hit is None:
                hit = t
            om = -give * om if bounced == 0 else 0.0
            bounced += 1
        if t >= nxt:
            out.append((round(t, 4), math.degrees(th)))
            nxt += 1 / rate
    out.append((round(t + 1 / rate, 4), angle1))
    return out, hit


def drop_time(height, g=G):
    """Seconds to fall `height` studs from rest."""
    return math.sqrt(2 * height / g)


def lead_arm(lean, start=38.0):
    """How far out ahead (degrees from hanging) the arm on the falling side must be, for a body tipped `lean` degrees
    forward over its knees, for the hand not to meet the floor before the chest does (the Tokyo intro's fall): 104
    out by 60 degrees of lean, 143 by 75, 176 when it is down."""
    return 176.0 * math.sqrt(max(0.0, (lean - start) / (88.0 - start)))


def turned(pitch, yaw=0.0, roll=0.0):
    """Root angles (CFrame.Angles order) for a body turned `yaw` degrees and then leaning `pitch` (rolled `roll`) in
    its own frame. (root=(pitch, yaw, roll) leans the body in the mark's frame: turned half round, a lean "forward"
    tips it over backwards.)"""
    if abs(yaw) < 1e-9:
        return (float(pitch), 0.0, float(roll))
    return tuple(float(v) for v in posekit.euler(posekit.ry(yaw) @ posekit.rx(pitch) @ posekit.rz(roll)))


def centre(root, hips=(0.0, 0.0), drop=0.0):
    """The body offset that puts the hips' pivot (the torso's bottom middle) at `hips` (x, z on the mark's floor plan)
    `drop` studs below where it stands at rest, for these root angles."""
    up = posekit.R(*root) @ np.array([0.0, 1.0, 0.0])
    return (hips[0] + float(up[0]), -drop + float(up[1]) - 1.0, hips[1] + float(up[2]))


def hips_of(joints, offset):
    """(x, z) of the hips' pivot (the torso's bottom middle) for a pose and body offset."""
    t = posekit.fk({k: v for k, v in joints.items() if k == "root"}, offset)["Torso"]
    p = t @ np.array([0.0, -1.0, 0.0, 1.0])
    return (float(p[0]), float(p[2]))


def body(pitch=0.0, yaw=0.0, roll=0.0, hips=(0.0, 0.0), drop=0.0, **joints):
    """A pose as {joint: value, "offset": ...} (for strike, beat or key): turned and leaning as turned() says, the
    hips at `hips`, `drop` below standing."""
    root = turned(pitch, yaw, roll)
    out = dict(joints)
    out["root"] = root
    out["offset"] = centre(root, hips, drop)
    return out


def body_key(m, t, ease="smooth", pitch=0.0, yaw=0.0, roll=0.0, hips=(0.0, 0.0), drop=0.0, **joints):
    """A key standing (or crouched): the body turned `yaw`, leaning `pitch` (negative forward) about its hips, which
    stand at `hips` and `drop` studs below their rest height."""
    pose = body(pitch, yaw, roll, hips, drop, **joints)
    off = pose.pop("offset")
    m.key(t, ease, offset=off, **pose)


def floor_key(m, t, ease, pitch, yaw, roll, hips, legs, joints):
    """A key resting on the floor: turned and leaning as turned() says, the hips at `hips`, these legs and joints."""
    root = turned(pitch, yaw, roll)
    cx, _, cz = centre(root, hips)
    keyed = dict(joints)
    keyed.update(legs)
    keyed["root"] = root
    m.key(t, ease, offset=(cx, 0.0, cz), floor=True, **keyed)


def kneeling_legs(lean):
    """The legs folded back along the floor under a body leaning `lean` degrees (negative: forward) on its knees
    (cinema.acting.kneel's fold)."""
    fold = -84.0 - (lean + 8.0)
    return dict(rHip=J((fold, 0, 2), (0, 0.15, 0.3)), lHip=J((fold, 0, -2), (0, 0.15, 0.3)))


def kneel_key(m, t, ease="smooth", lean=-8.0, head=-20.0, turn=0.0, roll=0.0, neck=None, hips=(0.0, 0.0), **upper):
    """A key on both knees at `hips`, the body leaning `lean` (negative forward), resting on the floor."""
    joints = dict(neck=neck if neck is not None else (head, 0, 0))
    joints.update(upper)
    floor_key(m, t, ease, lean, turn, roll, hips, kneeling_legs(lean), joints)


def floor_sit_legs(lean, spread=4.0):
    """The legs out in front along the floor under a body sat on it, leaning `lean` degrees back (+)."""
    return dict(rHip=J((90 - lean, 0, spread)), lHip=J((90 - lean, 0, -spread)))


def sit_key(m, t, ease="smooth", lean=10.0, head=0.0, turn=0.0, roll=0.0, neck=None, spread=4.0, hips=(0.0, 0.0),
            **upper):
    """A key sat on the floor at `hips`, the legs out in front, the body leaning `lean` (positive back)."""
    joints = dict(neck=neck if neck is not None else (head, 0, 0))
    joints.update(upper)
    floor_key(m, t, ease, lean, turn, roll, hips, floor_sit_legs(lean, spread), joints)


def prone_key(m, t, ease="smooth", lean=-90.0, turn=0.0, roll=0.0, neck=(12, 0, 14), hips=(0.0, 0.0),
              rShoulder=SIDE_R, lShoulder=SIDE_L, legs=None):
    """A key lying face down, the hips at `hips`, resting on the floor."""
    floor_key(m, t, ease, lean, turn, roll, hips, legs or PRONE_LEGS,
               dict(neck=neck, rShoulder=rShoulder, lShoulder=lShoulder))


def supine_key(m, t, ease="smooth", lean=88.0, turn=0.0, roll=0.0, neck=(18, 0, -10), hips=(0.0, 0.0),
               rShoulder=BACK_R, lShoulder=BACK_L, legs=None):
    """A key lying on the back, the hips at `hips`, resting on the floor."""
    floor_key(m, t, ease, lean, turn, roll, hips, legs or SUPINE_LEGS,
               dict(neck=neck, rShoulder=rShoulder, lShoulder=lShoulder))


SOLE_X = 0.5  # the middle of a sole, out from the body's middle line, standing at rest


def _smooth(u):
    u = clamp01(u)
    return u * u * (3 - 2 * u)


class Feet:
    """Where the soles are (character frame: x right, z back, on the floor), stepping: each foot holds its spot until
    a step lifts it (an arc `lift_h` high at its middle) and puts it down on the next, turned `yaw` degrees."""

    def __init__(self, start=None, steps=(), stance=0.05, lift_h=0.32):
        self.spots = {1: (SOLE_X + stance, 0.0, 0.0), -1: (-(SOLE_X + stance), 0.0, 0.0)}
        if start:
            for side, spot in start.items():
                self.spots[side] = (spot[0], spot[1], spot[2] if len(spot) > 2 else 0.0)
        self.lift_h = lift_h
        self.steps = {1: [], -1: []}  # side -> [(t_up, t_down, from, to)]
        here = dict(self.spots)
        for t_up, t_down, side, to in sorted(steps, key=lambda s: s[0]):
            if isinstance(to, (int, float)):  # a number: that far forward (negative: back), keeping its line
                to = (here[side][0], -float(to), here[side][2])
            to = (to[0], to[1], to[2] if len(to) > 2 else here[side][2])
            self.steps[side].append((t_up, t_down, here[side], to))
            here[side] = to
        self.final = here

    def at(self, side, t):
        """(x, z, yaw, height off the floor) of this foot at t."""
        spot = self.spots[side]
        for t_up, t_down, frm, to in self.steps[side]:
            if t < t_up:
                break
            if t <= t_down:
                u = (t - t_up) / max(1e-6, t_down - t_up)
                e = _smooth(u)
                pos = tuple(a + (b - a) * e for a, b in zip(frm, to))
                return pos[0], pos[1], pos[2], self.lift_h * math.sin(math.pi * u)
            spot = to
        return spot[0], spot[1], spot[2], 0.0


def stand(m, t0, t1, feet, ramp=0.12):
    """The legs stand on `feet` (a Feet) from t0 to t1, each rigid leg leaning to reach its sole and sliding in or out
    of the hip for the rest (a bent knee), never sliding sideways out of it; easing in and out over `ramp`. Key the
    body (root, offset) so the hips stay over the feet: a leg reaches only as far as it is long."""
    import numpy as np

    import posekit
    from cinema.footwork import _leg

    def fn(t, pose, off):
        if t < t0 - 1e-9 or t > t1 + 1e-9:
            return
        w = 1.0
        if ramp > 0:
            w = min(1.0, (t - t0) / ramp if t0 > 0 else 1.0, (t1 - t) / ramp if t1 < m.length else 1.0)
            w = _smooth(w)
        root = tuple(float(v) for v in pose["root"][:3]) if "root" in pose else (0.0, 0.0, 0.0)
        for side, key in ((1, "rHip"), (-1, "lHip")):
            x, z, yaw, h = feet.at(side, t)
            foot = np.array([x, h, z], float)
            top = np.asarray(posekit.hip_world(side, root, tuple(off))) + posekit.R(*root) @ np.array(
                [-side * 0.5, 0.0, 0.0])
            dy = max(0.5, top[1] - foot[1])
            pitch = math.degrees(math.atan2(top[2] - foot[2], dy))
            roll = math.degrees(math.atan2(foot[0] - top[0], dy))
            solved = _leg(side, foot, yaw, root, tuple(off), pitch, roll)
            own = pose.get(key, np.zeros(6))
            pose[key] = own * (1 - w) + solved * w

    m.extra(fn)
    return feet


def shiver(m, t0, t1, joints, amount=1.0, hz=9.0, decay=0.0, seed=0):
    """A fast tremor over whatever the body is doing between t0 and t1: small turns of the named joints (degrees at
    full `amount`: {joint: (x, y, z)}), `hz` a second, dying away by `decay` (0: steady) and easing in and out."""
    ph = seed * 1.3

    def fn(t, pose, off):
        if t < t0 or t > t1:
            return
        u = min(1.0, (t - t0) / 0.08, (t1 - t) / 0.12)
        k = amount * u * (1.0 - decay * (t - t0) / max(1e-6, t1 - t0))
        for joint, (ax, ay, az) in joints.items():
            if joint in pose:
                s1 = math.sin(2 * math.pi * hz * t + ph + len(joint))
                s2 = math.sin(2 * math.pi * hz * 1.37 * t + ph * 2.1 + len(joint) * 0.7)
                w = 0.65 * s1 + 0.35 * s2
                pose[joint][0] += k * ax * w
                pose[joint][1] += k * ay * w
                pose[joint][2] += k * az * w

    m.extra(fn)
    return m


def breaths(m, t0, t1, every=0.9, depth=1.6, joint="root"):
    """Heavy breaths heaving the back (or the chest) of a body lying down: the root pitch lifts `depth` degrees and
    sinks again, `every` seconds, slowing and fading to nothing by t1."""

    def fn(t, pose, off):
        if t < t0 or t > t1 or joint not in pose:
            return
        u = (t - t0) / max(1e-6, t1 - t0)
        fade = (1 - u) ** 1.5
        phase = (t - t0) / (every * (1 + 0.6 * u))
        b = 0.5 - 0.5 * math.cos(2 * math.pi * phase)
        pose[joint][0] += depth * fade * b * (1 if pose[joint][0] < 0 else -1)
        off[1] += 0.03 * fade * b

    m.extra(fn)
    return m


__all__ = [
    "G", "REST", "STAND_LEGS", "turned", "centre", "hips_of", "body", "body_key", "floor_key", "PRONE_LEGS", "SUPINE_LEGS", "SIDE_R", "SIDE_L", "AHEAD_R", "AHEAD_L", "OUT_R",
    "OUT_L", "BACK_R", "BACK_L", "mix", "clamp01", "rod_fall", "drop_time", "lead_arm", "kneeling_legs", "kneel_key",
    "floor_sit_legs", "sit_key", "prone_key", "supine_key", "Feet", "stand", "shiver", "breaths",
]
