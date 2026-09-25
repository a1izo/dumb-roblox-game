"""Helpers for keying poses on the real R15 rig: forward kinematics (where every part ends up),
legs that keep the feet planted while the hips move, a kneeling leg, and floor fitting so a
body lying down rests on the floor instead of sinking into it or hovering above it.

Angles are in the game's joint convention (animlib.py); positions are Roblox studs.
"""

import math

import numpy as np

import rbxsim
from gait import ANKLE_Y, HIP_X, HIP_Y, L1, L2, R, euler, solve_leg
from rig import JOINTS, PARTS

_RIG = rbxsim.load_rig()
_MOTOR_OF = {joint: rbxsim.JOINT_MOTORS[joint] for joint in JOINTS}


def _angles(value):
    if isinstance(value, (int, float)):
        return (float(value), 0.0, 0.0)
    return tuple(float(v) for v in value)


def _matrix(value):
    x, y, z = (math.radians(a) for a in _angles(value))
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return rx @ ry @ rz


def fk(joints, offset=(0, 0, 0)):
    """World CFrames (4x4) of every part, with the HumanoidRootPart standing on the origin.
    Joint values are angles (degrees) or 3x3 rotation matrices."""
    transforms = {}
    for joint, value in joints.items():
        m = np.identity(4)
        m[:3, :3] = value if isinstance(value, np.ndarray) else _matrix(value)
        transforms[_MOTOR_OF[joint]] = m
    root = transforms.get("Root", np.identity(4))
    shift = np.identity(4)
    shift[:3, 3] = offset
    transforms["Root"] = shift @ root
    parts = _RIG["parts"]
    hrp = parts["HumanoidRootPart"]["cframe"]["p"]
    world = {"HumanoidRootPart": rbxsim.cf((0, hrp[1], 0))}
    motors = list(_RIG["motors"])
    while motors:
        for motor in list(motors):
            if motor["part0"] in world:
                c0 = rbxsim.cf(motor["c0"]["p"], motor["c0"]["r"])
                c1 = rbxsim.cf(motor["c1"]["p"], motor["c1"]["r"])
                t = transforms.get(motor["name"], np.identity(4))
                world[motor["part1"]] = world[motor["part0"]] @ c0 @ t @ np.linalg.inv(c1)
                motors.remove(motor)
    return world


def lowest(joints, offset=(0, 0, 0)):
    """The lowest point of the body (studs above the floor) in this pose."""
    world = fk(joints, offset)
    low = math.inf
    for name, m in world.items():
        if name == "HumanoidRootPart":
            continue
        sx, sy, sz = (s / 2 for s in PARTS[name][1])
        for x in (-sx, sx):
            for y in (-sy, sy):
                for z in (-sz, sz):
                    low = min(low, (m @ np.array([x, y, z, 1.0]))[1])
    return low


def on_floor(joints, offset=(0, 0, 0), floor=0.02):
    """offset with its height changed so the lowest point of the body rests on the floor."""
    ox, oy, oz = offset
    return (ox, oy + floor - lowest(joints, offset), oz)


def planted_legs(offset=(0, 0, 0), root=(0, 0, 0), stance=0.0, forward=(0.0, 0.0), turn_out=6):
    """Hip, knee and ankle angles that keep both feet flat where they stand while the hips move.
    stance widens the feet (studs); forward moves (right, left) feet forward (studs)."""
    root_rot = R(*root)
    out = {}
    for side, key, ahead in ((1, "r", forward[0]), (-1, "l", forward[1])):
        ankle = (side * (HIP_X + stance), ANKLE_Y, -ahead)
        hip, knee, ank, _ = solve_leg(side, ankle, root_rot, offset, 0, -side * turn_out)
        out[key + "Hip"], out[key + "Knee"], out[key + "Ankle"] = hip, knee, ank
    return out


def fitted_kneel(offset, root, build, floor=0.02, rounds=6):
    """Raises or lowers the hips until the lowest point of the pose rests on the floor. build(offset)
    returns the joints for a hip offset (so planted and kneeling legs are solved again)."""
    ox, oy, oz = offset
    joints = build((ox, oy, oz))
    for _ in range(rounds):
        low = lowest(joints, (ox, oy, oz))
        if abs(low - floor) < 0.005:
            break
        oy += floor - low
        joints = build((ox, oy, oz))
    return (ox, oy, oz), joints


def kneeling_leg(side, offset=(0, 0, 0), root=(0, 0, 0), knee_ahead=-0.3, knee_height=0.5):
    """Angles for a leg kneeling on the floor: the knee rests on the floor `knee_ahead` studs in
    front of the hip line and the shin lies flat behind it, toes curled under. Also returns how
    far the knee falls short of its spot (0 when the hips are low enough)."""
    key = "r" if side > 0 else "l"
    root_rot = np.array(R(*root))
    hip = np.array([0, HIP_Y, 0]) + np.array(offset) + root_rot @ np.array([side * HIP_X, 0, 0])
    knee = np.array([side * HIP_X, knee_height, -knee_ahead])
    v = root_rot.T @ (knee - hip)
    d = float(np.linalg.norm(v))
    u = v / d
    gamma = math.asin(max(-1.0, min(1.0, u[0])))
    theta = math.atan2(-u[2], -u[1])
    hip_m = np.array(R(math.degrees(theta), 0, math.degrees(gamma)))
    # The shin lies flat and points backwards (+z in the world).
    s = np.linalg.inv(root_rot @ hip_m) @ np.array([0, -0.12, 1.0])
    knee_angle = math.degrees(math.atan2(-s[2], -s[1]))
    thigh_and_shin = root_rot @ hip_m @ np.array(R(knee_angle))
    foot = np.linalg.inv(thigh_and_shin) @ np.array(R(-38))
    return {
        key + "Hip": (math.degrees(theta), 0, math.degrees(gamma)),
        key + "Knee": knee_angle,
        key + "Ankle": euler(foot),
    }, max(0.0, d - L1)


__all__ = ["fk", "lowest", "on_floor", "planted_legs", "kneeling_leg", "L1", "L2", "ANKLE_Y"]
