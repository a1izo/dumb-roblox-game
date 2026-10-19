"""Roblox's classic R6 /e emotes (wave, point, cheer, laugh, dance), copied as they are (2026-10-19, emote overhaul
S8, owner's call: the free emotes copy Roblox's classics).

The recording (art/refs/classic/<name>.json) is every R6 joint's Motor6D.Transform, 30 times a second, for one
pass of the clip, taken in a Studio play test from Roblox's own animation assets (the ids Roblox's chat emote
list gives: CoreScripts/ChatEmoteUsage.lua). A Transform sits in the joint's own frame (C0's rotation, `basis`);
the game's clips are rotations in the parent part's frame (src/shared/Anim/Joints.luau), and the game plays them
back as Transform = basis^-1 * rotation * basis (ClipPlayer.transform). So a recorded Transform turns into the
game's angles as rotation = basis * Transform * basis^-1, and its slide as basis * Transform.Position.
"""

import json
import os

import numpy as np

import posekit


def J(angles, pos):
    """A joint value (animlib.J without Blender, so the recordings can be read outside it)."""
    return {"r": tuple(float(v) for v in angles), "p": tuple(float(v) for v in pos)}


HERE = os.path.dirname(os.path.abspath(__file__))
REFS = os.path.normpath(os.path.join(HERE, "..", "..", "refs", "classic"))

JOINTS = ("root", "neck", "rShoulder", "lShoulder", "rHip", "lHip")


def _matrix(components):
    """(position, 3x3 rotation) from CFrame:GetComponents()."""
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = components
    return np.array([x, y, z]), np.array([[r00, r01, r02], [r10, r11, r12], [r20, r21, r22]])


def load(name):
    """{"length", "c0": {joint: components}, "frames": [{"t", joint: components}]}."""
    with open(os.path.join(REFS, name + ".json"), encoding="utf-8") as fh:
        return json.load(fh)


def frames(name):
    """[(t, {joint: J(angles, slide)})] in the game's convention, one per recorded sample."""
    data = load(name)
    basis = {j: _matrix(data["c0"][j])[1] for j in JOINTS}
    out = []
    for f in data["frames"]:
        joints = {}
        for j in JOINTS:
            pos, rot = _matrix(f[j])
            b = basis[j]
            r = b @ rot @ b.T
            p = b @ pos
            angles = posekit.euler(r)
            joints[j] = J(tuple(round(float(a), 3) for a in angles), tuple(round(float(v), 4) for v in p))
        out.append((float(f["t"]), joints))
    return out, float(data["length"])


def _distance(a, b):
    """How far apart two recorded poses are (degrees, summed over the joints, plus studs of slide x 40)."""
    total = 0.0
    for j in JOINTS:
        ra, rb = np.array(a[j]["r"]), np.array(b[j]["r"])
        d = (ra - rb + 180.0) % 360.0 - 180.0
        total += float(np.abs(d).sum()) + 40.0 * float(np.abs(np.array(a[j]["p"]) - np.array(b[j]["p"])).sum())
    return total


def best_repeat(name, inserted, window):
    """Where to repeat a stretch of `inserted` seconds so the clip runs that much longer: the start t_a in
    `window` whose pose best matches the pose `inserted` later (the play goes to t_a + inserted, then back to
    t_a). Returns (t_a, mismatch)."""
    recorded, _ = frames(name)
    best = None
    for t, joints in recorded:
        if not (window[0] - 1e-6 <= t <= window[1] + 1e-6):
            continue
        later = min(recorded, key=lambda f: abs(f[0] - (t + inserted)))
        if abs(later[0] - (t + inserted)) > 1.0 / 60:
            continue
        miss = _distance(joints, later[1])
        if best is None or miss < best[1]:
            best = (t, miss)
    return best


def key_span(m, name, t0, t1, at, speed=1.0, ease="smooth", root_offset=True):
    """Keys the recording from t0 to t1 (recording seconds, t1 left out) onto Motion m starting at clip time
    `at`, played at `speed`. The root's slide becomes the body's offset. Returns the clip time after the span."""
    recorded, _ = frames(name)
    for t, joints in recorded:
        if t0 - 1e-6 <= t < t1 - 1e-6:
            pose = dict(joints)
            offset = None
            if root_offset:
                offset = pose["root"]["p"]
                pose["root"] = J(pose["root"]["r"], (0.0, 0.0, 0.0))
            m.key(round(at + (t - t0) / speed, 4), ease, offset=offset, **pose)
    return at + (t1 - t0) / speed




__all__ = ["frames", "load", "best_repeat", "key_span", "JOINTS"]
