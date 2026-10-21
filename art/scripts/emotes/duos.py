"""Duo emotes, each copied from its reference (art/refs/emotes/<clip>.toml). Two players, one clip each, started
on the same server time (DuoService/DuoController)."""

import numpy as np

from animlib import J
from emotes.kit import arm_direction, basis_angles, reach
from motion import Motion

# Match Point (clips matchPointServe + matchPointReturn, item emote_match_point) -------------------------
# Death Note, episode 10 ("Doubt"): L and Light, both former junior champions, play at the university in front
# of everyone. Here: the server (first player) in Light's clean style, the returner in L's slouch, and the rally
# really played: DuoService keeps the ball, each player presses as it reaches the racket, it comes back a little
# quicker each time, and the first miss ends it. (refs: matchPointServe.toml.)

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


# The rally is played, not scripted (owner's note, 2026-10-17: a timing game, the ball sped up each hit, over at
# the first miss; lively legs). Each player's base clip is a ready loop with footwork (DuoService keeps the ball,
# DuoController lays the strokes over it): the split-step bounce with the weight going side to side.
READY_LENGTH = 0.8


def ready(name, slouch, note):
    m = Motion(name, READY_LENGTH, loop=True, note=note, unwrap=True)
    for i, (x, s) in enumerate(((0.12, 1), (0.0, 0), (-0.12, -1), (0.0, 0))):
        t = i * READY_LENGTH / 4
        low = i % 2 == 0
        m.key(t, "sine", offset=(x, -0.27 if low else -0.15, 0), root=(-10 - slouch + (0 if low else 2), -5 * s, 3 * s),
              neck=(-1 + slouch * 0.4, 4 * s, 0), rShoulder=READY_R, lShoulder=READY_L)
    m.follow("neck", 3.4, 0.7).follow(("rShoulder", "lShoulder"), 5.0, 0.65)
    m.plant(stance=0.34, forward=(0.2, -0.2))
    m.build()
    return m


SLOUCH = 9.0  # L's way of standing: hunched, the head pushed forward
ready("matchPointServe", 0.0, "Match Point, the first player (Light): ready, bouncing on the toes, the weight side to side.")
ready("matchPointReturn", SLOUCH, "Match Point, the second player (L's slouch): ready, bouncing, the weight side to side.")

# Laid over the ready loop (DuoController): the serve (the hit at SERVE_HIT), a forehand (the strike at
# SWING_HIT, started so it meets the ball), the winner's fist, and the one who missed lunging too late.
SERVE_HIT, SWING_HIT = 0.6, 0.55
serving = Motion("matchPointServing", 1.15, note="Match Point: the serve (sideways, the toss, up and over).", unwrap=True)
serving.key(0.0, offset=(0, -0.04, 0), root=(-2, -50, 0), neck=(4, 44, 0),
            rShoulder=reach(1, (1.4, 0.6, 1.0), direction=(0.2, 0.3, 1.0)), lShoulder=reach(-1, (-0.6, 0.3, -1.2)))
serving.key(0.25, "sine", offset=(0, -0.08, 0), root=(-2, -50, 0), neck=(10, 44, 0),
            rShoulder=reach(1, (1.4, 0.9, 1.0), direction=(0.2, 0.3, 1.0)), lShoulder=reach(-1, (-0.7, 1.4, -1.0)))
serving.key(0.45, "out", offset=(0, -0.14, 0.04), root=(8, -40, 0), neck=(20, 40, 0),
            rShoulder=reach(1, (1.4, 2.0, 0.9), direction=(0.1, 0.4, 1.0)), lShoulder=J((168, 0, -8), (0, 0.24, 0)))
serving.key(SERVE_HIT, "snap", offset=(0, 0.1, -0.08), root=(2, -10, 0), neck=(16, 10, 0),
            rShoulder=J((176, 0, 6), (0, 0.26, -0.06)), lShoulder=J((60, 0, -14), (0, 0.06, -0.1)))
serving.key(0.8, "out", offset=(0, -0.16, -0.1), root=(-14, 20, 0), neck=(-6, -10, 0), rShoulder=THROUGH_R,
            lShoulder=J((16, 0, -16)))
serving.key(1.15, "sine", offset=(0, -0.22, 0), root=(-10, 0, 0), neck=(-2, 0, 0), rShoulder=READY_R, lShoulder=READY_L)
serving.follow("neck", 3.4, 0.68).plant(stance=0.32, forward=(0.2, -0.2))
serving.build()

swing = Motion("matchPointSwing", 1.05, note="Match Point: a forehand, a step into it, striking at 0.55 s.", unwrap=True)
swing.key(0.0, offset=(0, -0.24, 0), root=(-10, 0, 0), neck=(-2, 0, 0), rShoulder=READY_R, lShoulder=READY_L)
forehand(swing, SWING_HIT)
swing.follow("neck", 3.4, 0.68).plant(stance=0.36, forward=(0.32, -0.12))
swing.build()

won = Motion("matchPointWin", 1.5, note="Match Point: the winner's fist, the racket hanging.", unwrap=True)
won.key(0.0, offset=(0, -0.22, 0), root=(-10, 0, 0), neck=(-2, 0, 0), rShoulder=READY_R, lShoulder=READY_L)
won.key(0.35, "out", offset=(0, -0.04, 0), root=(4, 0, 0), neck=(12, 0, 0), rShoulder=J((24, 0, 16)),
        lShoulder=reach(-1, (-0.9, 2.45, -0.4)))
won.key(0.55, "sine", offset=(0, -0.1, 0), root=(0, 0, 0), neck=(6, 0, 0), rShoulder=J((24, 0, 16)),
        lShoulder=reach(-1, (-0.9, 1.9, -0.6)))
won.key(0.75, "out", offset=(0, -0.04, 0), root=(4, 0, 0), neck=(12, 0, 0), rShoulder=J((22, 0, 15)),
        lShoulder=reach(-1, (-0.92, 2.4, -0.38)))
won.key(1.5, "sine", offset=(0, -0.04, 0), root=(3, 0, 0), neck=(8, 0, 0), rShoulder=J((20, 0, 14)),
        lShoulder=reach(-1, (-0.92, 2.35, -0.4)))
won.follow("neck", 3.4, 0.68).follow(("lShoulder",), 4.0, 0.6).plant(stance=0.32, forward=(0.2, -0.2))
won.build()

lost = Motion("matchPointLost", 1.5, note="Match Point: a lunge too late, then upright, looking after the ball.", unwrap=True)
lost.key(0.0, offset=(0, -0.24, 0), root=(-12, 0, 0), neck=(0, 0, 0), rShoulder=READY_R, lShoulder=READY_L)
lost.key(0.25, "snap", offset=(0.45, -0.34, 0), root=(-12, -20, 18), neck=(-4, 30, 0), rShoulder=CONTACT_R,
         lShoulder=J((20, 0, -40)))
lost.key(0.8, "sine", offset=(0.4, -0.3, 0), root=(-14, -10, 10), neck=(-14, 40, 0), rShoulder=J((30, 0, 30)),
         lShoulder=J((14, 0, -20)))
lost.key(1.5, offset=(0.3, -0.22, 0), root=(-8, 0, 4), neck=(-10, 30, 0), rShoulder=J((12, 0, 10)),
         lShoulder=J((10, 0, -10)))
lost.follow("neck", 3.4, 0.68).plant(stance=0.36, forward=(0.2, -0.2))
lost.build()


# High Five and Handshake (clips highFive, handshake; free duos): the one asked has walked up to face the one
# asking (DuoService.MEET: 3.0 and 2.6 studs root to root); both play the same clip, so each one's right hand
# meets the other's a little right of their own middle, halfway between them.
HI_UP = reach(1, (0.35, 2.35, -0.95), direction=(-0.05, 0.85, -0.5))  # wound up high
HI_MEET = reach(1, (0.3, 2.0, -1.55), direction=(-0.05, 0.55, -0.85))  # the slap, halfway between them
high = Motion("highFive", 2.0, note="A high five: the hand wound up high, the slap halfway, a grin, the shake of the "
              "hand.", unwrap=True)
high.key(0.0, "smooth", root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))
high.key(0.4, "out", offset=(0, -0.05, 0.05), root=(3, -8, 0), neck=(6, 4, 0), rShoulder=HI_UP, lShoulder=J((10, 0, -10)))
high.key(0.6, "snap", offset=(0, -0.08, -0.12), root=(-6, 6, 0), neck=(2, -4, 0), rShoulder=HI_MEET,
         lShoulder=J((-10, 0, -14)))  # SLAP
high.key(0.85, "smooth", offset=(0, -0.04, -0.08), root=(-3, 4, 0), neck=(6, -2, 4), rShoulder=J((60, 0, 30)),
         lShoulder=J((0, 0, -10)))  # the bounce off it
high.key(1.3, "smooth", offset=(0, 0, 0), root=(0, 0, 2), neck=(4, 0, 6), rShoulder=J((20, 0, 20)), lShoulder=J((2, 0, -6)))
for k, t in enumerate((1.4, 1.5, 1.6)):  # shaking the sting out of the hand
    high.key(t, "smooth", root=(0, 0, 2), neck=(4, 0, 6), rShoulder=J((26 + (6 if k % 2 else -6), 0, 22)), lShoulder=J((2, 0, -6)))
high.key(2.0, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))
high.follow(("rShoulder", "lShoulder"), 3.6, 0.6)
high.follow("neck", 2.6, 0.7)
high.plant(0.0, 0.45, stance=0.08)
high.plant(0.45, 1.2, stance=0.1, forward=(0.0, 0.3))  # the left foot steps into it
high.plant(1.2, 2.0, stance=0.08)
high.build()

SHAKE = reach(1, (0.28, 0.15, -1.3), direction=(-0.15, -0.15, -1.0))  # the right hand out, halfway between them
shake = Motion("handshake", 2.4, note="A handshake: the right hands meet halfway, three firm pumps, a nod, let go.",
               unwrap=True)
shake.key(0.0, "smooth", root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))
shake.key(0.45, "out", offset=(0, -0.02, -0.06), root=(-3, 4, 0), neck=(-2, -2, 0), rShoulder=SHAKE, lShoulder=J((4, 0, -6)))
for k in range(3):  # three firm pumps
    t = 0.65 + 0.25 * k
    shake.key(round(t, 3), "smooth", offset=(0, -0.03, -0.06), root=(-4, 4, 0), neck=(-6 if k == 1 else -2, -2, 0),
              rShoulder=reach(1, (0.28, 0.0, -1.3), direction=(-0.15, -0.3, -0.95)), lShoulder=J((4, 0, -6)))
    shake.key(round(t + 0.12, 3), "smooth", offset=(0, -0.02, -0.06), root=(-3, 4, 0), neck=(-2, -2, 0),
              rShoulder=reach(1, (0.28, 0.3, -1.3), direction=(-0.15, 0.0, -1.0)), lShoulder=J((4, 0, -6)))
shake.key(1.6, "smooth", offset=(0, -0.02, -0.04), root=(-6, 2, 0), neck=(-12, 0, 0), rShoulder=SHAKE,
          lShoulder=J((4, 0, -6)))  # the nod
shake.key(2.4, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))
shake.follow(("rShoulder", "lShoulder"), 3.4, 0.7)
shake.follow("neck", 2.6, 0.75)
shake.plant(stance=0.08)
shake.build()


# The racket in the right fist, in line with the arm (R6 has no wrist: a racket cocked against the arm points at
# the floor whenever the arm hangs), the handle's end a little out of the fist and the head beyond it; at the
# forehand's strike its strings face the shot.
_axis = arm_direction(1, CONTACT_R)
_axis = _axis / np.linalg.norm(_axis)
_fist = np.array((2.3, 0.25, -1.1))
_GRIP_TO_PIVOT = 1.1  # the racket's middle from where the fist holds the handle (near its butt), studs, scaled
HOLDS = {  # (both players' rackets share this one line in EmoteMeta)
    "matchPointServe/Racket": ("Right Arm", {"rShoulder": CONTACT_R}, tuple(_fist + _axis * _GRIP_TO_PIVOT),
                               basis_angles(_axis, (0.0, 0.0, -1.0))),
}
# The strings' middle, from the racket's pivot (model frame, scaled): DuoController.racketHead aims the ball there.
STRINGS = (0.0, 0.73, 0.0)
