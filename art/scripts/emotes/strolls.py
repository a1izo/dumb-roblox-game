"""Strolls, each copied from its reference (art/refs/emotes/<clip>.toml). A stroll is two clips: `<name>`, played
standing still (a loop), and `<name>Walk`, a walk cycle the game plays instead of its own walk and run while the
stroll lasts (the player steers it at the normal speed; LocomotionController). The cycles are built like the
game's own (gait.py): soles planted while down, a stride long enough for full speed (16 studs a second)."""

import math

from animlib import J
from emotes.kit import raise_leg, reach
from gait import Gait, build_cycle, wave
from motion import Motion


def stroll(gait, pose, samples=40):
    """The walk cycle of a stroll: pose(phase) -> (upper body joints, root, offset); the legs follow the soles."""

    def full(phase):
        joints, root, offset = pose(phase)
        joints = dict(joints, root=root)
        joints.update(gait.legs(phase, root, offset))
        return joints, offset

    return build_cycle(gait, samples, full)


def blend(a, b, u):
    """Between two arm values (animlib.J), u from 0 (a) to 1 (b)."""
    ra, pa = a["r"], a.get("p", (0, 0, 0))
    rb, pb = b["r"], b.get("p", (0, 0, 0))
    return J(tuple(x + (y - x) * u for x, y in zip(ra, rb)), tuple(x + (y - x) * u for x, y in zip(pa, pb)))


# Griddy (clip griddy + griddyWalk, item emote_griddy) -----------------------------------------------------
# Allen "Griddy" Davis's dance (New Orleans, 2017-18), carried to the NFL by Justin Jefferson's touchdowns: a
# heel tapped out in front by turns on a low, bouncing crouch, the bent arms swinging across the body against the
# feet, and now and then the hands made into goggles round the eyes while the heels keep tapping. Copied from a
# 15-second lesson filmed at speed (refs: griddy.toml): a tap every 0.3 s.
TAP = 0.3
fwd_r = reach(1, (-0.1, -0.1, -1.05), direction=(-0.5, -0.2, -1.0))  # the right fist swung across the belly
fwd_l = reach(-1, (0.1, -0.1, -1.05), direction=(0.5, -0.2, -1.0))
back_r, back_l = J((-40, 0, 14), (0, 0.04, 0.04)), J((-40, 0, -14), (0, 0.04, 0.04))
# the goggles: fists beside the eyes, elbows out and down (R6's arms are as wide as the face: in front of it they
# would hide it)
goggles_r = reach(1, (0.86, 1.5, -0.6), direction=(0.15, 0.85, -0.5))
goggles_l = reach(-1, (-0.86, 1.5, -0.6), direction=(-0.15, 0.85, -0.5))
heel_r, heel_l = J((32, 0, 4), (0, 0.06, -0.12)), J((32, 0, -4), (0, 0.06, -0.12))

griddy = Motion("griddy", 12 * TAP, loop=True, note="Griddy: heels tapped out by turns, arms swinging across, then the goggles.", unwrap=True)
for i in range(12):
    t = i * TAP
    s = 1 if i % 2 == 0 else -1  # +1: the right heel taps, the left arm swings across
    if i < 8:
        arms = dict(rShoulder=back_r, lShoulder=fwd_l) if s > 0 else dict(rShoulder=fwd_r, lShoulder=back_l)
        root, neck = (-14, -9 * s, 2 * s), (8, 6 * s, -2 * s)
    else:
        arms = dict(rShoulder=goggles_r, lShoulder=goggles_l)
        root, neck = (-9, -3 * s, 2 * s), (4, 3 * s, 0)
    griddy.key(t, "out", offset=(0.04 * s, -0.22, 0), root=root, neck=neck, **arms)
    griddy.key(t + TAP / 2, "sine", offset=(0, -0.1, 0), root=(root[0] + 2, 0, 0), neck=(neck[0], 0, 0), **arms)
    raise_leg(griddy, "rHip" if s > 0 else "lHip", max(0.0, t - 0.09), t, t + 0.05, t + 0.2, heel_r if s > 0 else heel_l)
raise_leg(griddy, "lHip", 12 * TAP - 0.09, 12 * TAP, 12 * TAP, 12 * TAP, heel_l)  # the seam: the last tap's lead-in
griddy.follow("neck", 4.0, 0.65).follow(("rShoulder", "lShoulder"), 6.5, 0.6).plant(stance=0.16)
griddy.build()

GRIDDY = Gait("griddyWalk", period=2 * TAP, stride=9.0, stance=0.45, lift=0.36,
              note="Griddy on the move: low and bouncing, heels landing first, arms swinging across.")


def griddy_pose(phase):
    bob = math.cos(4 * math.pi * (phase - 0.2))
    swing = wave(phase, 0.04)  # +1: the right foot lands, the left arm across
    u = 0.5 + 0.5 * swing
    root = (-15 + 2 * bob, -8 * swing, 2 * wave(phase, 0.1))
    offset = (0.04 * wave(phase, 0.1), -0.16 + 0.12 * bob, 0.0)
    joints = dict(neck=(9 - 3 * bob, 5 * swing, 0), rShoulder=blend(fwd_r, back_r, u), lShoulder=blend(back_l, fwd_l, u))
    return joints, root, offset


stroll(GRIDDY, griddy_pose)
