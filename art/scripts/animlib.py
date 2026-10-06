"""A small keyframe language for Death's Gambit animations, and the code that turns it into Blender
actions on the R6 rig (art/scripts/rig.py).

Poses are written in the game's joint convention (src/shared/Anim/Joints.luau): degrees around
each joint in its parent's frame, applied like Roblox's CFrame.Angles(x, y, z).
    arms and legs: +x swings forward/up; neck and root: -x leans forward
    right arm / right leg: +z out to the side; left arm / left leg: -z out to the side
    +y turns left
A joint can also move: J(angles, (dx, dy, dz)) slides the part by that many studs in its parent's
frame (x right, y up, z backwards) as well as turning it. R6 has no elbows or knees, so sliding a
leg up fakes a bent knee and sliding an arm forward fakes a bent elbow.
`offset` moves the whole body (the root joint) in studs.

Each key says how the motion arrives at it (ease):
    smooth, linear, sine, in, out, snap, hold
"""

import bpy
from bpy_extras import anim_utils
from mathutils import Vector

from common import M, M_INV, rbx_angles
from rig import JOINTS

FPS = 60

EASES = {
    "smooth": ("BEZIER", "AUTO", None),
    "linear": ("LINEAR", "AUTO", None),
    "sine": ("SINE", "EASE_IN_OUT", None),
    "in": ("CUBIC", "EASE_IN", None),
    "out": ("CUBIC", "EASE_OUT", None),
    "snap": ("EXPO", "EASE_OUT", None),
    "hold": ("CONSTANT", "AUTO", None),
}


def J(angles=(0, 0, 0), pos=(0, 0, 0)):
    """A joint value that turns and slides: J((x, y, z), (dx, dy, dz))."""
    return {"r": _angles(angles), "p": tuple(float(v) for v in pos)}


def _angles(value):
    if isinstance(value, (int, float)):
        return (float(value), 0.0, 0.0)
    return tuple(float(v) for v in value)


def split(value):
    """(angles, position or None) for any joint value."""
    if isinstance(value, dict):
        return _angles(value.get("r", (0, 0, 0))), tuple(value.get("p", (0, 0, 0)))
    return _angles(value), None


class Clip:
    def __init__(self, name, length, loop=False, note="", floor=False):
        self.name = name
        self.floor = floor  # ends on the ground: the export lifts any frame that dips below it
        self.length = float(length)
        self.loop = loop
        self.note = note
        self.keys = {}  # joint -> [(t, angles, position or None, ease)]
        self.offsets = []  # [(t, (x, y, z), ease)]
        self.stride = None  # studs per cycle, for movement clips the game plays by speed

    def pose(self, t, ease="smooth", offset=None, **joints):
        for joint, value in joints.items():
            if joint not in JOINTS:
                raise ValueError(f"{self.name}: unknown joint {joint}")
            angles, pos = split(value)
            self.keys.setdefault(joint, []).append((float(t), angles, pos, ease))
        if offset is not None:
            self.offsets.append((float(t), tuple(float(v) for v in offset), ease))
        return self

    def finish(self):
        """Sorts keys, and closes loops by repeating the first key at the end."""
        for joint, keys in self.keys.items():
            keys.sort(key=lambda k: k[0])
            if self.loop and keys[-1][0] < self.length - 1e-6:
                first = keys[0]
                keys.append((self.length, first[1], first[2], "sine" if first[3] == "hold" else first[3]))
        self.offsets.sort(key=lambda k: k[0])
        if self.loop and self.offsets and self.offsets[-1][0] < self.length - 1e-6:
            self.offsets.append((self.length, self.offsets[0][1], self.offsets[0][2]))
        return self


CLIPS = {}


def clip(name, length, loop=False, note="", floor=False):
    c = Clip(name, length, loop, note, floor)
    CLIPS[name] = c
    return c


# Building actions ------------------------------------------------------------------------------


def _rest(arm, bone_name):
    return arm.data.bones[bone_name].matrix_local.to_3x3()


def bone_quaternion(arm, bone_name, angles):
    """The pose-bone rotation (bone-local quaternion) for a joint rotation in game convention."""
    rest = _rest(arm, bone_name)
    t_blender = M_INV @ rbx_angles(angles) @ M
    q = rest.inverted() @ t_blender @ rest
    return q.to_quaternion()


def bone_location(arm, bone_name, offset):
    """The pose-bone location that slides a part by `offset` studs in its parent's frame."""
    rest = _rest(arm, bone_name)
    return rest.inverted() @ (M_INV @ Vector(offset))


def _channelbag(arm, action):
    return anim_utils.action_ensure_channelbag_for_slot(action, arm.animation_data.action_slot)


def _apply_eases(fcurves, eases):
    """eases[i] is how the motion arrives at key i; Blender stores it on key i - 1."""
    for fc in fcurves:
        points = fc.keyframe_points
        for i in range(len(points)):
            ease = eases[i + 1] if i + 1 < len(eases) else "smooth"
            interp, easing, back = EASES.get(ease, EASES["smooth"])
            kp = points[i]
            kp.interpolation = interp
            if interp == "BEZIER":
                kp.handle_left_type = "AUTO_CLAMPED"
                kp.handle_right_type = "AUTO_CLAMPED"
            else:
                kp.easing = easing
            if back is not None:
                kp.back = back
        fc.update()


def build_action(arm, c):
    c.finish()
    old = bpy.data.actions.get(c.name)
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(c.name)
    action.use_fake_user = True
    action["dg_clip"] = True
    action["length"] = c.length
    action["loop"] = c.loop
    action["joints"] = sorted(c.keys.keys())
    action["moves"] = sorted(j for j, keys in c.keys.items() if any(k[2] is not None for k in keys))
    action["offset"] = len(c.offsets) > 0
    action["note"] = c.note
    if c.stride:
        action["stride"] = c.stride
    action["floor"] = c.floor
    arm.animation_data_create()
    arm.animation_data.action = action

    # Every bone the clip does not use stays at rest.
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)

    for joint, keys in c.keys.items():
        bone_name = JOINTS[joint]
        pb = arm.pose.bones[bone_name]
        previous = None
        moves = any(k[2] is not None for k in keys)
        for t, angles, pos, _ in keys:
            q = bone_quaternion(arm, bone_name, angles)
            if previous is not None and previous.dot(q) < 0:
                q.negate()
            previous = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=t * FPS, group=bone_name)
            if moves and joint != "root":
                pb.location = bone_location(arm, bone_name, pos or (0, 0, 0))
                pb.keyframe_insert("location", frame=t * FPS, group=bone_name)
        bag = _channelbag(arm, action)
        paths = {f'pose.bones["{bone_name}"].rotation_quaternion', f'pose.bones["{bone_name}"].location'}
        fcurves = [fc for fc in bag.fcurves if fc.data_path in paths]
        _apply_eases(fcurves, [k[3] for k in keys])

    if c.offsets:
        pb = arm.pose.bones[JOINTS["root"]]
        for t, offset, _ in c.offsets:
            pb.location = bone_location(arm, JOINTS["root"], offset)
            pb.keyframe_insert("location", frame=t * FPS, group=JOINTS["root"])
        bag = _channelbag(arm, action)
        path = f'pose.bones["{JOINTS["root"]}"].location'
        fcurves = [fc for fc in bag.fcurves if fc.data_path == path]
        _apply_eases(fcurves, [k[2] for k in c.offsets])
    return action


def build_all(arm):
    scene = bpy.context.scene
    scene.render.fps = FPS
    actions = []
    for c in CLIPS.values():
        actions.append(build_action(arm, c))
    return actions
