"""Duo emotes, each copied from its reference (art/refs/emotes/<clip>.toml). Two players, one clip each, started
on the same server time (DuoService/DuoController)."""

import numpy as np

from animlib import J
from emotes.kit import arm_direction, basis_angles, reach
from motion import Motion

# Match Point (clips matchPointServe + matchPointReturn, item emote_match_point) -------------------------
# Death Note, episode 10 ("Doubt"): L and Light, both former junior champions, play at the university in front
# of everyone. Here: the server (first player) in Light's clean style, the returner in L's slouch. The ball's
# timetable is DuoController.RALLY (the serve at 0.35 s, a hit every 0.8 s by turns, the smash at 5.15 s,
# then 0.55 s for the ball to fly past): the swings below hit on it. (refs: matchPointServe.toml.)
LENGTH = 6.2
HITS_A, HITS_B = (1.95, 3.55), (1.15, 2.75, 4.35)

# The ready position from the anime's rally (Light at 121-124 s): crouched, weight forward, both hands on the
# racket in front, its head up.
# (R6 has no wrist: the racket keeps its angle to the arm, so the arm is held out in front and the racket points
# forward at the waist, not head-up.)
READY_R = reach(1, (0.55, 0.55, -1.55), direction=(-0.2, -0.05, -1.0))
READY_L = reach(-1, (0.2, 0.5, -1.4), direction=(0.45, -0.1, -1.0))
# the forehand: the unit turn back, the strike out in front, the follow-through over the left shoulder
BACK_R = reach(1, (2.0, 0.8, 0.9), direction=(0.6, 0.1, 0.8))
SIDE_R = reach(1, (2.4, 0.7, -0.3))  # on the way back: out to the side, so the racket swings round, not down
CONTACT_R = reach(1, (2.3, 0.25, -1.1), direction=(0.8, -0.1, -0.6))
THROUGH_R = reach(1, (-0.2, 1.25, -1.45), direction=(-0.5, 0.5, -0.8))


def forehand(m, t, slouch=0.0):
    """A forehand hitting at t (the turn back, the strike, the follow-through, back to ready)."""
    m.key(t - 0.5, "sine", offset=(0, -0.21, 0), root=(-9 - slouch, -18, 0), neck=(-4, 16, 0), rShoulder=SIDE_R,
          lShoulder=READY_L)
    m.key(t - 0.32, "out", offset=(0, -0.2, 0), root=(-8 - slouch, -38, 0), neck=(-4, 34, 0), rShoulder=BACK_R,
          lShoulder=reach(-1, (0.2, 0.4, -1.3), direction=(0.3, 0.1, -1.0)))
    m.key(t, "snap", offset=(0, -0.16, -0.06), root=(-6 - slouch, 12, 0), neck=(-2, -10, 0), rShoulder=CONTACT_R,
          lShoulder=J((30, 0, -40), (0, 0.04, 0)))
    m.key(t + 0.18, "out", offset=(0, -0.14, -0.04), root=(-6 - slouch, 30, 0), neck=(-2, -20, 0), rShoulder=THROUGH_R,
          lShoulder=J((24, 0, -22)))
    m.key(t + 0.46, "sine", offset=(0, -0.22, 0), root=(-10 - slouch, 0, 0), neck=(-2 + slouch * 0.3, 0, 0),
          rShoulder=READY_R, lShoulder=READY_L)


serve = Motion("matchPointServe", LENGTH, note="Match Point, the server: the serve, two forehands, the smash and a fist.", unwrap=True)
# the serve: sideways at the line, the toss, the trophy pose, up and over
serve.key(0.0, offset=(0, -0.04, 0), root=(-2, -50, 0), neck=(4, 44, 0),
          rShoulder=reach(1, (1.4, 0.6, 1.0), direction=(0.2, 0.3, 1.0)), lShoulder=reach(-1, (-0.6, 0.3, -1.2)))
serve.key(0.2, "out", offset=(0, -0.14, 0.04), root=(8, -40, 0), neck=(20, 40, 0),
          rShoulder=reach(1, (1.4, 2.0, 0.9), direction=(0.1, 0.4, 1.0)), lShoulder=J((168, 0, -8), (0, 0.24, 0)))
serve.key(0.35, "snap", offset=(0, 0.1, -0.08), root=(2, -10, 0), neck=(16, 10, 0),
          rShoulder=J((176, 0, 6), (0, 0.26, -0.06)), lShoulder=J((60, 0, -14), (0, 0.06, -0.1)))
serve.key(0.55, "out", offset=(0, -0.16, -0.1), root=(-14, 20, 0), neck=(-6, -10, 0), rShoulder=THROUGH_R,
          lShoulder=J((16, 0, -16)))
serve.key(0.9, "sine", offset=(0, -0.22, 0), root=(-10, 0, 0), neck=(-2, 0, 0), rShoulder=READY_R, lShoulder=READY_L)
for t in HITS_A:
    forehand(serve, t)
# the smash: the racket lifted up in front and over, behind the head, the free hand pointing at the ball, down
# through it
serve.key(4.45, "sine", offset=(0, -0.1, 0.02), root=(2, -16, 0), neck=(14, 14, 0),
          rShoulder=reach(1, (1.3, 2.2, -0.7)), lShoulder=J((120, 0, -14), (0, 0.14, 0)))
serve.key(4.8, "out", offset=(0, 0.06, 0.06), root=(8, -30, 0), neck=(24, 26, 0),
          rShoulder=reach(1, (1.3, 2.1, 0.8), direction=(0.1, 0.5, 1.0)), lShoulder=J((150, 0, -14), (0, 0.2, 0)))
serve.key(5.15, "snap", offset=(0, -0.18, -0.12), root=(-16, 10, 0), neck=(-6, -6, 0),
          rShoulder=J((120, 0, 10), (0, 0.14, -0.12)), lShoulder=J((20, 0, -20)))
serve.key(5.35, "out", offset=(0, -0.22, -0.1), root=(-18, 22, 0), neck=(-8, -14, 0), rShoulder=THROUGH_R,
          lShoulder=J((16, 0, -18)))
# the winner's fist (left), the racket hanging
serve.key(5.75, "out", offset=(0, -0.04, 0), root=(4, 0, 0), neck=(12, 0, 0), rShoulder=J((24, 0, 16)),
          lShoulder=reach(-1, (-0.9, 2.45, -0.4)))
serve.key(6.2, offset=(0, -0.04, 0), root=(4, 0, 0), neck=(10, 0, 0), rShoulder=J((22, 0, 15)),
          lShoulder=reach(-1, (-0.92, 2.4, -0.38)))
serve.follow("neck", 3.4, 0.68).follow(("rShoulder", "lShoulder"), 6.0, 0.62).plant(stance=0.32, forward=(0.2, -0.2))
serve.build()

ret = Motion("matchPointReturn", LENGTH, note="Match Point, the returner (L's slouch): three returns, then too late for the smash.", unwrap=True)
SLOUCH = 9.0  # L's way of standing: hunched, the head pushed forward
ret.key(0.0, offset=(0, -0.24, 0), root=(-10 - SLOUCH, 0, 0), neck=(4, 0, 0), rShoulder=READY_R, lShoulder=READY_L)
ret.key(0.6, "sine", offset=(0, -0.28, 0), root=(-12 - SLOUCH, 0, 0), neck=(6, 0, 0), rShoulder=READY_R, lShoulder=READY_L)
for t in HITS_B:
    forehand(ret, t, slouch=SLOUCH)
# the smash goes past: a lunge to the right too late, then upright, looking after it
ret.key(5.45, "snap", offset=(0.55, -0.42, 0), root=(-12, -20, 18), neck=(-4, 30, 0), rShoulder=CONTACT_R,
        lShoulder=J((20, 0, -40)))
ret.key(5.85, "sine", offset=(0.4, -0.3, 0), root=(-14, -10, 10), neck=(-14, 40, 0), rShoulder=J((30, 0, 30)),
        lShoulder=J((14, 0, -20)))
ret.key(6.2, offset=(0.3, -0.22, 0), root=(-12 - SLOUCH * 0.5, 0, 4), neck=(-10, 30, 0), rShoulder=J((12, 0, 10)),
        lShoulder=J((10, 0, -10)))
ret.follow("neck", 3.4, 0.68).follow(("rShoulder", "lShoulder"), 6.0, 0.62).plant(stance=0.32, forward=(0.2, -0.2))
ret.build()

# The racket in the right fist, in line with the arm (R6 has no wrist: a racket cocked against the arm points at
# the floor whenever the arm hangs), the handle's end a little out of the fist and the head beyond it; at the
# forehand's strike its strings face the shot.
_axis = arm_direction(1, CONTACT_R)
_axis = _axis / np.linalg.norm(_axis)
_fist = np.array((2.3, 0.25, -1.1))
_GRIP_TO_PIVOT = 0.95  # the racket's middle from where the fist holds the handle, studs, once scaled
HOLDS = {  # (both players' rackets share this one line in EmoteMeta)
    "matchPointServe/Racket": ("Right Arm", {"rShoulder": CONTACT_R}, tuple(_fist + _axis * _GRIP_TO_PIVOT),
                               basis_angles(_axis, (0.0, 0.0, -1.0))),
}
# The strings' middle, from the racket's pivot (model frame, scaled): DuoController.racketHead aims the ball there.
STRINGS = (0.0, 0.52, 0.0)
