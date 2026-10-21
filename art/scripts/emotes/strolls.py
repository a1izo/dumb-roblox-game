"""Strolls, each copied from its reference (art/refs/emotes/<clip>.toml). A stroll is two clips: `<name>`, played
standing still (a loop), and `<name>Walk`, a walk cycle the game plays instead of its own walk and run while the
stroll lasts (LocomotionController), the body walking by itself at the stroll's pace (Controllers/StrollWalker).
The cycles are the game's own (locomotion.Cycle): soles that hold where they land."""

import math

import numpy as np

import locomotion
from animlib import J
from emotes import mocap
from motion import Motion


# Griddy (clip griddy + griddyWalk, item emote_griddy) -----------------------------------------------------
# Allen "Griddy" Davis's dance (New Orleans, 2017-18), carried to the NFL by Justin Jefferson's touchdowns: a
# heel tapped out in front by turns on a low, bouncing crouch, the bent arms swinging across the body against the
# feet, and now and then the hands made into goggles round the eyes while the heels keep tapping.
# Motion-captured (2026-10-17, owner's note: the legs looked wrong, the limbs too far apart, not the real dance)
# from Justin Jefferson teaching it (refs: griddy.toml, mocap/griddy.json): 22.15-25.2 s, the taps with the arms
# swinging, the arms brought up into the goggles and held; the loop eases from the goggles back into the taps.
GRIDDY_FROM, GRIDDY_TO, GRIDDY_BACK = 22.15, 25.2, 0.4
griddy = Motion("griddy", GRIDDY_TO - GRIDDY_FROM + GRIDDY_BACK, loop=True,
                note="Griddy: heels tapped out by turns, arms swinging across, then the goggles.", unwrap=True)
mocap.capture(griddy, "griddy", GRIDDY_FROM, 0.0, GRIDDY_TO - GRIDDY_FROM, hold=False, arm_depth=1.0, leg_depth=1.0,
              taps=120.0)
griddy.build()

# On the move (2026-10-17 rebuild): the game's own run cycle (locomotion.Cycle, 16 studs a second, soles that
# hold where they land), so the legs neither skate nor sink as the old 9-stud gait did; on it the Griddy's lean,
# bounce and twist, and the arms of the captured right heel tap (1.4 s into the take) swinging across against
# the feet, mirrored for the left.
def _mirror(v):
    v = np.array(v, float)
    return np.array([v[0], -v[1], -v[2], -v[3], v[4], v[5]])


_tap_pose, _ = griddy.sample(1.4)
_tap_r, _tap_l, _tap_root = _tap_pose["rShoulder"], _tap_pose["lShoulder"], _tap_pose["root"]


def _arm(v):
    return J(tuple(float(a) for a in v[:3]), tuple(float(a) for a in v[3:]))


def griddy_upper(phase):
    bob = locomotion.twice(phase, 0.3)  # +1 up between the taps, -1 sinking onto the landing heel
    s = locomotion.cyc(phase, 0.05)  # +1: the right heel lands, the left arm across
    u = 0.5 + 0.5 * s
    body = dict(
        root=(-16.0 - 2.5 * bob, float(_tap_root[1]) * 0.8 * s, 3.0 * locomotion.cyc(phase, 0.1)),
        neck_world=(-4.0 + 2.0 * bob, 0.0, 0.0),
        offset=(0.04 * locomotion.cyc(phase, 0.1), -0.16 + 0.07 * bob, 0.0),
        rShoulder=_arm(_mirror(_tap_l) * (1 - u) + _tap_r * u),
        lShoulder=_arm(_mirror(_tap_r) * (1 - u) + _tap_l * u),
    )
    return body


locomotion.Cycle("griddyWalk", locomotion.RUN_PERIOD, locomotion.RUN_STANCE, 0.36, upper=griddy_upper,
                 note="Griddy on the move: low and bouncing, heels landing first, arms swinging across.").build()


# The four other walks (2026-10-21: they walk by themselves now, Controllers/StrollWalker, and the old gait.py
# cycles slid their soles a stud and more each step): the game's own cycles, each at its stroll's pace (Cosmetics
# `pace`; the game moves a cycle on by the ground covered, so the pace sets only how quick the steps come). The
# standing clips are still in anims_emotes.py.
def _period(stance, pace):
    """Seconds a cycle takes at this pace, to the nearest whole frame (60 a second), so the loop closes on a frame."""
    return round(locomotion.TRAVEL / stance / pace * 60) / 60


def _cycle(name, pace, stance, lift, upper, note, kind=locomotion.Cycle):
    kind(name, _period(stance, pace), stance, lift, upper=upper, note=note).build()


# The Long Climb (theLongClimbWalk; Subaru's stair climb, the owner's Q24/Q38): an endless stair that is not
# there, at 5 studs a second; the knees brought up high as onto a step, the body leaning into the climb and
# pushing up off each foot, both arms pumping hard against the legs, the head down. Its green steps under each
# footfall and the giant grin behind are its effect (Controllers/EmoteFx).
def climb_upper(phase):
    bob = locomotion.twice(phase, 0.3)  # +1 pushed up over the planted foot, -1 as the next lands
    yaw = -6.0 * locomotion.cyc(phase, 0.03)
    body = dict(
        root=(-12.0 - 2.5 * bob, yaw, 1.5 * locomotion.cyc(phase, 0.12)),
        neck_world=(-10.0, 0.3 * yaw, 0.0),
        offset=(0.03 * locomotion.cyc(phase, 0.1), -0.08 + 0.07 * bob, 0.0),
    )
    body.update(locomotion.arms(phase, swing=38, base=16, out=5, arc=5, lift=0.12, forward=0.18, lag=0.04, across=6))
    return body


class _Climb(locomotion.Cycle):
    """The swinging foot goes up early and high, out in front (the knee brought up onto the next step), then
    comes straight down onto it; the leg may fold as deep as the checks allow."""

    max_sink = 0.58

    def lift_at(self, u):
        return self.lift * math.sin(math.pi * u**1.25)


_cycle("theLongClimbWalk", 5.0, 0.52, 1.15, climb_upper,
       "Climbing an endless stair: high knees, leaning in, pushing up off each foot, the arms pumping.", kind=_Climb)


# Parade March (paradeMarchWalk): stiff and upright, chin up, the arms swinging high and straight in time,
# brisk at 5.5 studs a second.
def march_upper(phase):
    bob = locomotion.twice(phase, 0.3)
    body = dict(
        root=(1.5 - 0.5 * bob, 0.0, 0.6 * locomotion.cyc(phase, 0.12)),
        neck_world=(4.0, 0.0, 0.0),
        offset=(0.0, -0.05 + 0.04 * bob, 0.0),
    )
    body.update(locomotion.arms(phase, swing=46, base=0, out=4, arc=1, lift=0.0, forward=0.0, lag=0.0))
    return body


_cycle("paradeMarchWalk", 5.5, 0.5, 0.6, march_upper,
       "A stiff parade march: upright, chin up, arms swinging high and straight in time.")

# Mushroom Stroll (mushroomStrollWalk): an easy, unbothered walk at 4.5 studs a second, the stick over the right
# shoulder (a mushroom tied to it: the arm of the standing clip), the other arm swinging a little, the head
# bobbing along.
STICK_ARM = J((72, 0, -14), (-0.15, 0.1, -0.1))


def mushroom_upper(phase):
    bob = locomotion.twice(phase, 0.3)
    yaw = 3.0 * locomotion.cyc(phase, 0.05)
    body = dict(
        root=(-2.0 + 0.8 * bob, yaw, 1.2 * locomotion.cyc(phase, 0.1)),
        neck_world=(1.0 - 1.5 * bob, -0.4 * yaw, 0.0),
        offset=(0.04 * locomotion.cyc(phase, 0.12), -0.06 + 0.04 * bob, 0.0),
        rShoulder=STICK_ARM,
    )
    body["lShoulder"] = locomotion.arms(phase, swing=16, base=4, out=4, arc=2, lift=0.02, forward=0.04, lag=0.08)["lShoulder"]
    return body


_cycle("mushroomStrollWalk", 4.5, 0.6, 0.3, mushroom_upper,
       "An easy, unbothered walk with a stick over the shoulder, the other arm swinging a little.")

# Not My Problem (notMyProblemWalk): the lazy slouch of somebody walking away from it all, hands in the pockets
# (the standing clip's), the head tipped, dragging along at 4 studs a second.
POCKET_R, POCKET_L = J((8, 0, -4), (-0.08, 0.12, -0.02)), J((8, 0, 4), (0.08, 0.12, -0.02))


def slouch_upper(phase):
    bob = locomotion.twice(phase, 0.3)
    yaw = 3.0 * locomotion.cyc(phase, 0.05)
    body = dict(
        root=(-12.0 + 0.8 * bob, yaw, 2.0 * locomotion.cyc(phase, 0.1)),
        neck_world=(-14.0, 0.5 * yaw, 7.0),
        offset=(0.05 * locomotion.cyc(phase, 0.12), -0.1 + 0.03 * bob, 0.0),
        rShoulder=POCKET_R,
        lShoulder=POCKET_L,
    )
    return body


_cycle("notMyProblemWalk", 4.0, 0.62, 0.22, slouch_upper,
       "A lazy slouch, hands in the pockets, walking away from it all.")
