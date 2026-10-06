"""Helpers for keying poses on the R6 rig: forward kinematics (where every part ends up), rigid
legs that keep the feet where they are while the hips move, and floor fitting so a body lying
down rests on the floor instead of sinking into it or hovering above it.

R6 legs and arms are single rigid parts (no knees, elbows or ankles), so a leg only has a pitch
(x) and a roll (z): its foot can reach the points on a sphere round the hip.

Angles are in the game's joint convention (animlib.py); positions are Roblox studs (x right,
y up, z backwards; forward is -z) with the HumanoidRootPart standing on the origin.
"""

import math

import numpy as np

import rbxsim
from rig import JOINTS, LEG, PARTS, PIVOTS

_RIG = rbxsim.load_rig()
_MOTOR_OF = {joint: rbxsim.JOINT_MOTORS[joint] for joint in JOINTS}
ROOT_MOTOR = rbxsim.JOINT_MOTORS["root"]

HIP_X = LEG["hip_x"]  # the hip pivot's distance from the middle (the torso's edge)
HIP_Y = LEG["hip"]
LEG_LENGTH = LEG["length"]


def rx(deg):
    a = math.radians(deg)
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


def ry(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def rz(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


def R(x=0.0, y=0.0, z=0.0):
    """Roblox CFrame.Angles(x, y, z) in degrees: Rx * Ry * Rz."""
    return rx(x) @ ry(y) @ rz(z)


def _angles(value):
    if isinstance(value, (int, float)):
        return (float(value), 0.0, 0.0)
    return tuple(float(v) for v in value)


def _matrix(value):
    return R(*_angles(value))


def euler(m):
    """(x, y, z) degrees with m = CFrame.Angles(x, y, z) = Rx * Ry * Rz."""
    sy = max(-1.0, min(1.0, m[0][2]))
    b = math.asin(sy)
    a = math.atan2(-m[1][2], m[2][2])
    c = math.atan2(-m[0][1], m[0][0])
    return (math.degrees(a), math.degrees(b), math.degrees(c))


def fk(joints, offset=(0, 0, 0)):
    """World CFrames (4x4) of every part, with the HumanoidRootPart standing on the origin.
    Joint values are angles (degrees) or 3x3 rotation matrices, in the parent part's frame."""
    rotations = {}
    for joint, value in joints.items():
        rotations[_MOTOR_OF[joint]] = value if isinstance(value, np.ndarray) else _matrix(value)
    world = rbxsim.pose_from(_RIG, rotations, offset)
    hrp = _RIG["parts"]["HumanoidRootPart"]["cframe"]["p"]
    # pose_from leaves the root part at its rest place; stand it on the origin axis
    shift = rbxsim.cf((-hrp[0], 0, -hrp[2]))
    return {name: shift @ m for name, m in world.items()}


def _corners(name):
    sx, sy, sz = (s / 2 for s in PARTS[name][1])
    return [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]


def lowest_of(joints, names, offset=(0, 0, 0)):
    """The lowest point (studs above the floor) of the named parts in this pose."""
    world = fk(joints, offset)
    low = math.inf
    for name in names:
        m = world[name]
        for c in _corners(name):
            low = min(low, (m @ np.array([*c, 1.0]))[1])
    return low


def lowest(joints, offset=(0, 0, 0)):
    """The lowest point of the body (studs above the floor) in this pose."""
    return lowest_of(joints, [n for n in PARTS if n != "HumanoidRootPart"], offset)


def on_floor(joints, offset=(0, 0, 0), floor=0.02):
    """offset with its height changed so the lowest point of the body rests on the floor."""
    ox, oy, oz = offset
    return (ox, oy + floor - lowest(joints, offset), oz)


SEAT_PARTS = ("Torso", "Left Leg", "Right Leg")


def on_seat(joints, offset=(0, 0, 0), seat=1.75):
    """offset with its height changed so the hips and thighs rest on a seat `seat` studs high."""
    ox, oy, oz = offset
    return (ox, oy + seat - lowest_of(joints, SEAT_PARTS, offset), oz)


# Legs -------------------------------------------------------------------------------------------------

_LEG_NAME = {1: "Right Leg", -1: "Left Leg"}


def hip_world(side, root=(0, 0, 0), offset=(0, 0, 0)):
    """Where this hip pivots (character frame), for a body moved by `offset` and turned by `root`."""
    pivot = np.array(PIVOTS["root"])
    return pivot + np.array(offset) + R(*root) @ (np.array([side * HIP_X, HIP_Y, 0.0]) - pivot)


def leg_angles_for(side, foot, root=(0, 0, 0), offset=(0, 0, 0)):
    """Hip angles (x pitch, 0, z roll) that put the middle of this leg's sole at `foot` (character
    frame). A leg is rigid, so a foot out of reach ends up as near as it can get. Returns the
    angles and how far short or long the foot is (studs)."""
    a = -side * 0.5  # the sole's middle sits half a stud in from the hip pivot
    reach = math.hypot(a, LEG_LENGTH)
    v = R(*root).T @ (np.array(foot) - hip_world(side, root, offset))
    length = float(np.linalg.norm(v))
    err = abs(length - reach)
    if length > 1e-6:
        v = v * (reach / length)
    phi = math.atan2(LEG_LENGTH, a)
    gamma = phi - math.acos(max(-1.0, min(1.0, v[0] / reach)))
    v1y = a * math.sin(gamma) - LEG_LENGTH * math.cos(gamma)
    theta = math.atan2(v[2] / v1y, v[1] / v1y)
    return (math.degrees(theta), 0.0, math.degrees(gamma)), err


def planted_legs(offset=(0, 0, 0), root=(0, 0, 0), stance=0.0, forward=(0.0, 0.0)):
    """Hip angles that keep both soles where they stand while the hips move (they splay or step as
    far as rigid legs allow). stance widens the feet (studs); forward moves (right, left) soles
    forward (studs)."""
    out = {}
    reach = math.hypot(0.5, LEG_LENGTH)
    for side, key, ahead in ((1, "r", forward[0]), (-1, "l", forward[1])):
        foot = (side * (abs(-side * 0.5 + side * HIP_X) + stance), 0.0, -ahead)
        hip = hip_world(side, root, offset)
        flat = reach * reach - (hip[1] - foot[1]) ** 2 - (hip[2] - foot[2]) ** 2
        if flat > 0 and abs(abs(foot[0] - hip[0]) - math.sqrt(flat)) > 1e-3:
            # A rigid leg cannot keep its sole where it is once the hips move: it reaches in or out by
            # the smallest amount (in, unless that would cross the middle; then the soles go out).
            d = math.sqrt(flat)
            inward = hip[0] - side * d
            foot = (inward if side * inward >= 0.25 else hip[0] + side * d, foot[1], foot[2])
        out[key + "Hip"], _ = leg_angles_for(side, foot, root, offset)
    return out


def leg_contact(side, hip, root=(0, 0, 0), offset=(0, 0, 0)):
    """The lowest corner of this leg in the character frame for hip angles `hip`."""
    m = R(*root) @ _matrix(hip)
    h = hip_world(side, root, offset)
    best = None
    for cx, cy, cz in _corners("Right Leg"):
        # corners of the leg box, relative to the hip pivot at its top outer edge
        p = h + m @ np.array([cx - side * 0.5, cy - 1.0, cz])
        if best is None or p[1] < best[1]:
            best = p
    return best


__all__ = [
    "fk",
    "lowest",
    "lowest_of",
    "on_floor",
    "on_seat",
    "planted_legs",
    "leg_angles_for",
    "leg_contact",
    "hip_world",
    "R",
    "euler",
    "HIP_X",
    "HIP_Y",
    "LEG_LENGTH",
]
