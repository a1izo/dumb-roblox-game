"""Movement clips (idle, walk, run, land) generated with leg IK on the real R15 rig.

Feet are placed first (planted feet move backwards exactly as fast as the body moves forwards,
swinging feet follow an arc), the pelvis bobs, sways and turns, and the hip, knee and ankle
angles are solved from there. So a planted foot never slides when the game plays the cycle at
the speed it was made for, and each clip records its stride (studs per cycle) for the game.

Angles use the game's joint convention (animlib.py); positions are Roblox studs in the
character's frame (x right, y up, z backwards, forward is -z).
"""

import math

from mathutils import Matrix, Vector

from animlib import clip
from common import rbx_angles
from rig import LEG, ROOT_PIVOT

L1 = LEG["thigh"]
L2 = LEG["shin"]
ANKLE_Y = LEG["ankle"]
HIP_Y = ROOT_PIVOT[1]
HIP_X = 0.5
FOOT_HALF = 0.5  # the foot reaches half a stud in front of and behind the ankle


def R(x=0.0, y=0.0, z=0.0):
    return rbx_angles((x, y, z))


def euler(m):
    """(x, y, z) degrees with m = CFrame.Angles(x, y, z) = Rx * Ry * Rz."""
    sy = max(-1.0, min(1.0, m[0][2]))
    b = math.asin(sy)
    a = math.atan2(-m[1][2], m[2][2])
    c = math.atan2(-m[0][1], m[0][0])
    return (math.degrees(a), math.degrees(b), math.degrees(c))


def wrap(angle):
    while angle > math.pi:
        angle -= 2 * math.pi
    while angle < -math.pi:
        angle += 2 * math.pi
    return angle


def solve_leg(side, ankle, root_rot, offset, foot_pitch=0.0, foot_yaw=0.0):
    """Hip, knee and ankle angles that put this leg's ankle at `ankle` (character frame) with
    the foot pitched by foot_pitch degrees (toes up +). side is 1 for right, -1 for left.
    Returns (hip, knee, ankle angles, reach error in studs)."""
    pivot = Vector((0, HIP_Y, 0)) + Vector(offset)
    hip = pivot + root_rot @ Vector((side * HIP_X, 0, 0))
    v = root_rot.transposed() @ (Vector(ankle) - hip)
    d = v.length
    reach = min(max(d, abs(L1 - L2) + 1e-3), L1 + L2 - 1e-4)
    cos_k = (reach * reach - L1 * L1 - L2 * L2) / (2 * L1 * L2)
    knee = -math.acos(max(-1.0, min(1.0, cos_k)))
    by = -L1 - L2 * math.cos(knee)
    bz = -L2 * math.sin(knee)
    v = v * (reach / d) if d > 1e-6 else v
    gamma = math.asin(max(-1.0, min(1.0, v.x / -by)))
    c = by * math.cos(gamma)
    theta = wrap(math.atan2(v.z, v.y) - math.atan2(bz, c))
    hip_m = R(math.degrees(theta), 0, math.degrees(gamma))
    knee_m = R(math.degrees(knee))
    target = R(0, foot_yaw, 0) @ R(foot_pitch)
    ankle_m = (root_rot @ hip_m @ knee_m).inverted() @ target
    return (math.degrees(theta), 0.0, math.degrees(gamma)), math.degrees(knee), euler(ankle_m), max(0.0, d - reach)


def planted(point, pitch):
    """Ankle position for a foot whose sole pivots on its toe (pitch < 0) or heel (pitch > 0)
    around `point` (where the flat foot's ankle would be)."""
    p = math.radians(pitch)
    lever = Vector((0, ANKLE_Y, FOOT_HALF if pitch < 0 else -FOOT_HALF))
    toe = Vector(point) + Vector((0, -ANKLE_Y, -FOOT_HALF if pitch < 0 else FOOT_HALF))
    rot = Matrix.Rotation(p, 3, "X")
    return toe + rot @ lever


def smoothstep(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def hermite(points, u):
    """Catmull-Rom through [(u, value)] (u from 0 to 1)."""
    for i in range(len(points) - 1):
        u0, v0 = points[i]
        u1, v1 = points[i + 1]
        if u0 <= u <= u1:
            t = (u - u0) / (u1 - u0) if u1 > u0 else 0
            p_prev = points[i - 1][1] if i > 0 else v0 - (v1 - v0)
            p_next = points[i + 2][1] if i + 2 < len(points) else v1 + (v1 - v0)
            m0 = (v1 - p_prev) / 2
            m1 = (p_next - v0) / 2
            t2, t3 = t * t, t * t * t
            return (2 * t3 - 3 * t2 + 1) * v0 + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * v1 + (t3 - t2) * m1
    return points[-1][1]


class Gait:
    """One looping locomotion cycle. phase 0 = right foot touches down."""

    def __init__(self, name, period, stride, stance, note):
        self.name = name
        self.period = period
        self.stride = stride
        self.stance = stance
        self.note = note
        self.worst_reach = 0.0

    def foot(self, phase, swing_f, swing_y, contact_pitch, toeoff_pitch):
        """Ankle position and foot pitch for one foot at `phase` (0 = its own touch-down)."""
        s = self.stance
        half = self.stride * s / 2
        if phase < s:
            u = phase / s
            point = (0, ANKLE_Y, -(half - self.stride * phase))
            if u < 0.25:
                pitch = contact_pitch * (1 - smoothstep(u / 0.25))
            elif u > 0.55:
                pitch = toeoff_pitch * smoothstep((u - 0.55) / 0.45)
            else:
                pitch = 0.0
            return planted(point, pitch), pitch
        # The swing starts where the toe-off left the ankle and ends at the heel strike.
        start = planted((0, ANKLE_Y, half), toeoff_pitch)
        end = planted((0, ANKLE_Y, -half), contact_pitch)
        f_points = [(0, -start.z)] + [(u, k * half) for u, k in swing_f[1:-1]] + [(1, -end.z)]
        y_points = [(0, start.y)] + list(swing_y[1:-1]) + [(1, end.y)]
        u = (phase - s) / (1 - s)
        f = hermite(f_points, u)
        y = hermite(y_points, u)
        pitch = hermite([(0, toeoff_pitch), (0.3, toeoff_pitch * 1.3), (0.75, 0), (1, contact_pitch)], u)
        return (0, y, -f), pitch


def build_cycle(g, samples, pose_fn):
    """Keys `samples` poses per cycle. pose_fn(phase) -> dict of joint values and offset."""
    c = clip(g.name, g.period, loop=True, note=g.note)
    c.stride = g.stride
    for i in range(samples):
        phase = i / samples
        joints, offset = pose_fn(phase)
        c.pose(phase * g.period, "linear", offset=offset, **joints)
    return c


def legs(g, phase, root, offset, swing_f, swing_y, contact_pitch, toeoff_pitch):
    root_rot = R(*root)
    out = {}
    for side, key, own in ((1, "r", phase), (-1, "l", (phase + 0.5) % 1)):
        ankle, pitch = g.foot(own, swing_f, swing_y, contact_pitch, toeoff_pitch)
        ankle = (side * HIP_X + ankle[0], ankle[1], ankle[2])
        hip, knee, ank, err = solve_leg(side, ankle, root_rot, offset, pitch)
        g.worst_reach = max(g.worst_reach, err)
        out[key + "Hip"] = hip
        out[key + "Knee"] = knee
        out[key + "Ankle"] = ank
    return out


# Run ------------------------------------------------------------------------------------------------
# Full speed in the game is 16 studs/s. Short R15 legs need a quick, springy stride.

RUN = Gait("run", period=0.54, stride=16 * 0.54, stance=0.2, note="Sprint at 16 studs/s; planted feet never slide.")
RUN_SWING_F = [(0, -1.0), (0.22, -1.25), (0.5, -0.35), (0.78, 0.9), (1, 1.0)]
RUN_SWING_Y = [(0, ANKLE_Y + 0.12), (0.22, 1.05), (0.5, 1.1), (0.78, 0.62), (1, ANKLE_Y)]


def run_pose(phase):
    s = RUN.stance
    bob = math.cos(4 * math.pi * (phase - s / 2))  # 1 at mid-stance (lowest)
    yaw = 11 * math.cos(2 * math.pi * phase)  # right hip forward at right touch-down
    roll = 3.5 * math.cos(2 * math.pi * (phase - s / 2))
    root = (-7 - 2.5 * bob, yaw, roll)
    offset = (0.05 * math.cos(2 * math.pi * (phase - s / 2)), -0.21 - 0.08 * bob, 0.0)
    joints = legs(RUN, phase, root, offset, RUN_SWING_F, RUN_SWING_Y, 12, -32)
    joints["root"] = root
    swing = math.cos(2 * math.pi * phase)  # +1: right arm back, left arm forward
    joints.update(
        waist=(-10 - 2 * bob, -1.7 * yaw, -0.6 * roll),
        neck=(10 + 2 * bob, 0.7 * yaw, 0),
        rShoulder=(2 - 54 * swing, 0, 9 + 5 * swing),
        lShoulder=(2 + 54 * swing, 0, -9 + 5 * swing),
        rElbow=92 + 18 * max(0, -swing),
        lElbow=92 + 18 * max(0, swing),
        rWrist=(-8, 0, 4),
        lWrist=(-8, 0, -4),
    )
    return joints, offset


# Walk -----------------------------------------------------------------------------------------------
# A relaxed walk at about 3 studs/s, used while speeding up and slowing down.

WALK = Gait("walk", period=0.8, stride=2.4, stance=0.62, note="Relaxed walk at 3 studs/s; feet stay planted.")
WALK_SWING_F = [(0, -1.0), (0.3, -0.55), (0.65, 0.55), (1, 1.0)]
WALK_SWING_Y = [(0, ANKLE_Y + 0.05), (0.35, ANKLE_Y + 0.42), (0.7, ANKLE_Y + 0.2), (1, ANKLE_Y)]


def walk_pose(phase):
    s = WALK.stance
    lift = math.cos(4 * math.pi * (phase - s / 2))  # 1 at mid-stance (highest in a walk)
    yaw = 7 * math.cos(2 * math.pi * phase)
    roll = 3 * math.cos(2 * math.pi * (phase - s / 2))
    root = (-2, yaw, roll)
    offset = (0.06 * math.cos(2 * math.pi * (phase - s / 2)), -0.13 + 0.035 * lift, 0.0)
    joints = legs(WALK, phase, root, offset, WALK_SWING_F, WALK_SWING_Y, 14, -24)
    joints["root"] = root
    swing = math.cos(2 * math.pi * phase)
    joints.update(
        waist=(-3, -1.5 * yaw, -0.5 * roll),
        neck=(3, 0.5 * yaw, 0),
        rShoulder=(-24 * swing, 0, 7),
        lShoulder=(24 * swing, 0, -7),
        rElbow=16 + 10 * max(0, -swing),
        lElbow=16 + 10 * max(0, swing),
    )
    return joints, offset


# Idle -----------------------------------------------------------------------------------------------


def idle_clip():
    c = clip("idle", 4.0, loop=True, note="Breathing and a slow weight shift, feet planted.")
    steps = 32
    for i in range(steps):
        t = i / steps
        breath = math.sin(2 * math.pi * t * 2)  # two breaths per loop
        shift = math.sin(2 * math.pi * t)  # weight moves right, then left
        offset = (0.07 * shift, -0.06 + 0.012 * breath, 0.0)
        root = (0, 2 * math.sin(2 * math.pi * t + 0.8), -1.8 * shift)
        root_rot = R(*root)
        joints = {"root": root}
        for side, key in ((1, "r"), (-1, "l")):
            ankle = (side * (HIP_X + 0.08), ANKLE_Y, -0.05 if side > 0 else 0.08)
            hip, knee, ank, _ = solve_leg(side, ankle, root_rot, offset, 0, -side * 6)
            joints[key + "Hip"], joints[key + "Knee"], joints[key + "Ankle"] = hip, knee, ank
        joints.update(
            waist=(-1.5 + 1.2 * breath, -1.5 * math.sin(2 * math.pi * t + 0.8), 1.2 * shift),
            neck=(1 - 1.0 * breath, 5 * math.sin(2 * math.pi * t * 0.5 + 1.1), 0.8 * shift),
            rShoulder=(1 + 1.5 * breath, 0, 5 + 1.2 * breath),
            lShoulder=(1 + 1.5 * breath, 0, -5 - 1.2 * breath),
            rElbow=9 + 2 * breath,
            lElbow=9 + 2 * breath,
            rWrist=(0, 0, 3),
            lWrist=(0, 0, -3),
        )
        c.pose(t * 4.0, "linear", offset=offset, **joints)
    return c


# Landing --------------------------------------------------------------------------------------------


def land_clip():
    """Knees absorb the landing with the feet planted, then spring back with a small overshoot."""
    c = clip("land", 0.42, note="Knee dip on landing, feet planted; faded out over the ground pose.")
    keys = [
        (0.0, -0.12, -6, 40),
        (0.07, -0.46, -20, 34),
        (0.16, -0.38, -16, 20),
        (0.3, -0.04, -2, 6),
        (0.42, -0.06, -3, 8),
    ]
    for t, drop, lean, arms in keys:
        offset = (0, drop, 0.05)
        root = (lean * 0.4, 0, 0)
        root_rot = R(*root)
        joints = {"root": root}
        for side, key in ((1, "r"), (-1, "l")):
            ankle = (side * (HIP_X + 0.1), ANKLE_Y, -0.1)
            hip, knee, ank, _ = solve_leg(side, ankle, root_rot, offset)
            joints[key + "Hip"], joints[key + "Knee"], joints[key + "Ankle"] = hip, knee, ank
        joints.update(
            waist=(lean, 0, 0),
            neck=(-lean * 0.7, 0, 0),
            rShoulder=(arms * 0.8, 0, 10 + arms * 0.4),
            lShoulder=(arms * 0.8, 0, -10 - arms * 0.4),
            rElbow=20 + arms * 0.6,
            lElbow=20 + arms * 0.6,
        )
        c.pose(t, "smooth", offset=offset, **joints)
    return c


def build():
    run = build_cycle(RUN, 36, run_pose)
    walk = build_cycle(WALK, 36, walk_pose)
    idle_clip()
    land_clip()
    return {"run": (run, RUN.worst_reach), "walk": (walk, WALK.worst_reach)}
