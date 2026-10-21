"""The emote audit's fixes (2026-10-21, the shop overhaul's B6), laid over every emote's clip once all are made:

- a leg that slides more than check_anims allows out of its hip (a gap under the torso, as a bouncing dance's
  body rises over a planted foot) is drawn back up into it, easing in past GAP_FROM so the leg comes off the
  floor a little at the top of the bounce instead of the torso floating off it;
- a clip with a part below the floor is lifted out of it frame by frame (the export's own floor lift).

Only the clips that break a limit are touched (check_anims.py's numbers); every other clip is left as it was made.
"""

import math
import os
import re

import numpy as np

import posekit
from animlib import CLIPS

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
COSMETICS = os.path.join(ROOT, "src", "shared", "Cosmetics.luau")
QUICKCHAT = os.path.join(ROOT, "src", "shared", "QuickChat.luau")

GAP_LIMIT = 0.12  # check_anims.py LIMITS["gap"]
GAP_FROM = 0.06  # where the easing begins
GAP_MOST = 0.1  # the most a leg is left out of its hip
FLOOR_LIMIT = 0.03  # check_anims.py LIMITS["floor"]
LEGS = {"rHip": "Right Leg", "lHip": "Left Leg"}


def emote_clips():
    """Every emote's clip, and its walk where it has one: the shop's (Cosmetics) and everyone's (QuickChat)."""
    names = re.findall(r'\bemote\s*=\s*"([a-z]\w*)"', open(COSMETICS, encoding="utf-8").read())
    free = open(QUICKCHAT, encoding="utf-8").read()
    names += re.findall(r'\{\s*id\s*=\s*"([a-z]\w*)",\s*name\s*=', free)
    out = []
    for name in names:
        for clip in (name, name + "Walk"):
            if clip in CLIPS and clip not in out:
                out.append(clip)
    return out


def gap_of(joint, angles, pos):
    """How far the top of this leg is below the torso's bottom face (studs; + out of the hip)."""
    world = posekit.fk({joint: {"r": angles, "p": pos or (0.0, 0.0, 0.0)}})
    local = np.linalg.inv(world["Torso"]) @ world[LEGS[joint]]
    top = local[:3, :3] @ np.array([0.0, 1.0, 0.0]) + local[:3, 3]
    return -1.0 - float(top[1])


def eased(gap):
    """The gap left: as it was up to GAP_FROM, then easing towards GAP_MOST."""
    if gap <= GAP_FROM:
        return gap
    span = GAP_MOST - GAP_FROM
    return GAP_FROM + span * math.tanh((gap - GAP_FROM) / span)


def seat_legs(c):
    """Draws the legs back into the hips (in the torso's frame: the slide's y) where they gap; returns the worst
    gap before."""
    worst = 0.0
    gaps = {}
    for joint in LEGS:
        for i, (t, angles, pos, ease) in enumerate(c.keys.get(joint, [])):
            g = gap_of(joint, angles, pos)
            gaps[(joint, i)] = g
            worst = max(worst, g)
    if worst <= GAP_LIMIT:
        return worst
    for (joint, i), g in gaps.items():
        lift = g - eased(g)
        if lift <= 1e-5:
            continue
        t, angles, pos, ease = c.keys[joint][i]
        x, y, z = pos or (0.0, 0.0, 0.0)
        c.keys[joint][i] = (t, angles, (x, y + lift, z), ease)
    return worst


def run():
    changed = []
    for name in emote_clips():
        c = CLIPS[name]
        before = seat_legs(c)
        if before > GAP_LIMIT:
            changed.append(f"{name} (legs {before:.3f})")
    # (clips that dip below the floor: the export lifts each frame out of it; it needs the body's offset keyed)
    for name in FLOOR_FIXES:
        c = CLIPS.get(name)
        if c is None:
            continue
        c.floor = True
        if not c.offsets:
            times = sorted({k[0] for keys in c.keys.values() for k in keys})
            c.offsets = [(t, (0.0, 0.0, 0.0), "linear") for t in times]
        changed.append(f"{name} (floor)")
    return changed


# The emotes check_anims.py found below the floor (2026-10-21): a knee or a heel a few hundredths of a stud under.
FLOOR_FIXES = ("chipAndPen", "smilingLord", "paradeMarch", "glitchStep")
