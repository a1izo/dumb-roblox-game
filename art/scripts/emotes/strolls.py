"""Strolls, each copied from its reference (art/refs/emotes/<clip>.toml). A stroll is two clips: `<name>`, played
standing still (a loop), and `<name>Walk`, a walk cycle the game plays instead of its own walk and run while the
stroll lasts (LocomotionController), the body walking by itself at the stroll's pace (Controllers/StrollWalker).
The cycles are the game's own (locomotion.Cycle): soles that hold where they land."""

import math

import locomotion
from animlib import J
from motion import Motion


# Griddy (clip griddy + griddyWalk, item emote_griddy): rebuilt 2026-11-16 in emotes/griddy.py (importing it builds
# both clips); the first, motion-captured build is kept in emotes/griddy_mocap.py.
from emotes import griddy  # noqa: E402,F401


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
        # (soft at both ends, so the foot neither snaps off the floor nor slaps down: the old sin(pi u^1.25) came
        # down at full speed and the loop hitched at its seam, 2026-10-24)
        return self.lift * math.sin(math.pi * u**0.85) ** 1.3


_cycle("theLongClimbWalk", 5.0, 0.52, 1.15, climb_upper,
       "Climbing an endless stair: high knees, leaning in, pushing up off each foot, the arms pumping.", kind=_Climb)


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
