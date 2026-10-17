"""Strolls, each copied from its reference (art/refs/emotes/<clip>.toml). A stroll is two clips: `<name>`, played
standing still (a loop), and `<name>Walk`, a walk cycle the game plays instead of its own walk and run while the
stroll lasts (the player steers it at the normal speed; LocomotionController). The cycles are the game's own
(locomotion.Cycle): soles that hold where they land, a stride long enough for full speed (16 studs a second)."""

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
