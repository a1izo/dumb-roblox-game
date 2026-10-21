"""The emote pack's clips (2026-10-14; anims.py imports this file at its end, so every helper there is
ready): dances first, then poses, prop emotes, strolls and duos as they land. Each name is the clip id the
shop's emote item plays (src/shared/Cosmetics.luau). The originals they nod to are named in the notes only;
the moves are our own, kept to what an R6 body can do (six joints, rigid limbs: knees and elbows are
faked by sliding the parts).

Dances that loop keep time with one another in the game (each starts on the server's beat), so keep a
loop's length a whole number of beats.
"""

import math

import numpy as np

from anims import ARMS, REST, l_chest, r_chest, r_face, soft
from animlib import J
from motion import Motion, _vec


def lift(m, joint, keys):
    """Takes a joint out of what plant() (or its keys) gave it for a while: keys are (t, weight, value),
    and the joint blends from its own pose towards `value` by `weight` (0: left alone), easing between
    keys. For a leg kicked or raised while the other stays planted."""
    pts = [(float(t), float(w), _vec(v)) for t, w, v in keys]

    def fn(t, pose, _offset):
        for (t0, w0, v0), (t1, w1, v1) in zip(pts, pts[1:]):
            if t0 - 1e-9 <= t <= t1 + 1e-9:
                u = (t - t0) / (t1 - t0) if t1 > t0 else 1.0
                u = 0.5 - 0.5 * math.cos(math.pi * u)
                w = w0 + (w1 - w0) * u
                v = v0 + (v1 - v0) * u
                base = pose[joint] if joint in pose else np.zeros(6)
                pose[joint] = base * (1 - w) + v * w
                return

    m.extra(fn)
    return m


def raise_leg(m, joint, t_up, t_peak, t_hold, t_down, value):
    """lift() for the usual shape: up from t_up, fully at `value` from t_peak to t_hold, down by t_down."""
    return lift(m, joint, ((t_up, 0, value), (t_peak, 1, value), (t_hold, 1, value), (t_down, 0, value)))


# Dances ----------------------------------------------------------------------------------------------------

# Office Party (the workplace group dance, an original routine): step-touches with the arms swinging,
# the arms thrown up, a front kick, a clap, and a turn on the spot to finish the bar. 8 beats of 0.4 s.
party = Motion("officeParty", 3.2, loop=True, note="Step-touch side to side, arms up, a kick, a clap and a turn: the office party.")
party.key(0.0, offset=(0, -0.04, 0), root=(-1, 0, 0), neck=(0, 0, 0),
          rShoulder=J((14, 0, 10)), lShoulder=J((14, 0, -10)))
for i, s in enumerate((1, -1)):
    t = 0.4 + 0.4 * i
    party.key(t, offset=(0.22 * s, -0.12, 0), root=(-3, -7 * s, -4 * s), neck=(-2, -8 * s, 2 * s),
              rShoulder=J((46, 0, 34 if s > 0 else -24), (-0.1 if s < 0 else 0, 0.05, -0.1)),
              lShoulder=J((46, 0, 24 if s > 0 else -34), (0.1 if s > 0 else 0, 0.05, -0.1)))
for i, s in enumerate((1, -1)):
    t = 1.2 + 0.4 * i
    party.key(t, "out", offset=(0.2 * s, -0.06, 0), root=(3, -5 * s, -3 * s), neck=(8, -4 * s, 0),
              rShoulder=J((158, 0, 28), (0, 0.18, 0)), lShoulder=J((158, 0, -28), (0, 0.18, 0)))
party.key(2.0, "snap", offset=(0, 0.02, 0.06), root=(7, 0, 0), neck=(2, 0, 0),
          rShoulder=J((70, 0, 20), (0, 0.05, -0.1)), lShoulder=J((-24, 0, -18)))
party.key(2.4, "out", offset=(0, -0.08, 0), root=(-4, 0, 0), neck=(-6, 0, 0),
          rShoulder=J((82, 0, -30), (-0.22, 0.06, -0.16)), lShoulder=J((82, 0, 30), (0.22, 0.06, -0.16)))
for i in range(1, 5):  # the turn: a full circle back to the start, linear so it never slows mid-turn
    t = 2.4 + 0.2 * i
    open_arms = 70 if i < 4 else 10
    party.key(t, "linear", offset=(0, -0.04, 0), root=(-1, 90 * i, 0), neck=(0, -12 if i < 4 else 0, 0),
              rShoulder=J((20 if i < 4 else 14, 0, open_arms)), lShoulder=J((20 if i < 4 else 14, 0, -open_arms)))
raise_leg(party, "rHip", 1.75, 2.0, 2.12, 2.38, J((74, 0, 4), (0, 0.08, -0.06)))
soft(party, arms=3.4).plant(0.0, 2.4, stance=0.06)
party.build()

# Two-Legged Bop (the dancing dogs): up on the hind legs, paws up in front and pumping in turn, a bounce
# on every beat and the hips swaying. 4 beats of 0.3 s.
bop = Motion("twoLeggedBop", 1.2, loop=True, note="Paws up in front, pumping in turn, bouncing and swaying on every beat.")
for i in range(4):
    t = i * 0.3
    s = 1 if i < 2 else -1
    up = 1 if i % 2 == 0 else -1
    bop.key(t, offset=(0.1 * s, -0.14 if i % 2 == 0 else -0.02, 0), root=(-4, 8 * s, -5 * s), neck=(4 * (i % 2), -6 * s, 7 * s),
            rShoulder=J((80 + 16 * up, 0, -12), (-0.08, 0.1 + 0.05 * up, -0.2)),
            lShoulder=J((80 - 16 * up, 0, 12), (0.08, 0.1 - 0.05 * up, -0.2)))
soft(bop, head=4.0, arms=4.2).plant(stance=0.12)
bop.build()

# Boat Aura (aura farming): feet set wide as if on a racing boat's bow, rocking with it, the face
# deadpan; a hand held out with the other sweeping under it, both fists rolling like a wheel, one arm
# forward and one back, a kiss blown each way, a point at the sky. 16 beats of 0.4 s.
boat = Motion("boatAura", 6.4, loop=True, note="Calm and deadpan on a boat's bow: the sweep, the rolling fists, the kisses, the point to the sky.")


def rock(t):
    return 3.0 * math.sin(2 * math.pi * t / 3.2)


forward = J((80, 0, -6), (-0.08, 0.06, -0.12))
for t, under in ((0.0, 0), (0.4, 1), (0.8, 0), (1.2, 1)):  # the sweep under the held hand
    boat.key(t, offset=(0, -0.06, 0), root=(0, 0, rock(t)), neck=(-2, 0, 0), rShoulder=forward,
             lShoulder=J((46 + 18 * under, 0, -24 + 54 * under), (0.12 * under, 0.04, -0.14)))
for i in range(4):  # the fists rolling over each other, carried left to right and back
    t = 1.6 + 0.4 * i
    side = (-1, 1, 1, -1)[i]
    roll = 1 if i % 2 == 0 else -1
    boat.key(t, offset=(0, -0.06, 0), root=(0, 6 * side, rock(t)), neck=(-2, 4 * side, 0),
             rShoulder=J((74 + 10 * roll, 0, -16 + 22 * side), (-0.12, 0.05, -0.16)),
             lShoulder=J((74 - 10 * roll, 0, 16 + 22 * side), (0.12, 0.05, -0.16)))
boat.key(3.2, "out", offset=(0, -0.06, 0), root=(0, -8, rock(3.2)), neck=(0, -6, 0),
         rShoulder=J((92, 0, 2), (0, 0.06, -0.1)), lShoulder=J((-34, 0, -12)))
boat.key(3.8, offset=(0, -0.06, 0), root=(0, -8, rock(3.8)), neck=(0, -6, 0),
         rShoulder=J((92, 0, 2), (0, 0.06, -0.1)), lShoulder=J((-34, 0, -12)))
boat.key(4.1, offset=(0, -0.06, 0), root=(0, 0, rock(4.1)), neck=(2, 0, 0),
         rShoulder=r_face(118, -30), lShoulder=J((10, 0, -8)))
boat.key(4.35, "out", offset=(0, -0.06, 0), root=(0, -10, rock(4.35)), neck=(0, -14, 0),
         rShoulder=J((96, 0, 52), (0, 0.08, -0.06)), lShoulder=J((10, 0, -8)))
boat.key(4.6, offset=(0, -0.06, 0), root=(0, 0, rock(4.6)), neck=(2, 0, 0),
         rShoulder=J((20, 0, 8)), lShoulder=J((118, 0, 30), (0.28, 0.18, -0.22)))
boat.key(4.85, "out", offset=(0, -0.06, 0), root=(0, 10, rock(4.85)), neck=(0, 14, 0),
         rShoulder=J((20, 0, 8)), lShoulder=J((96, 0, -52), (0, 0.08, -0.06)))
boat.key(5.3, "out", offset=(0, -0.04, 0), root=(3, 0, rock(5.3)), neck=(14, 0, 0),
         rShoulder=J((166, 0, 8), (0, 0.24, 0)), lShoulder=J((12, 0, -8)))
boat.key(5.9, offset=(0, -0.04, 0), root=(3, 0, rock(5.9)), neck=(14, 0, 0),
         rShoulder=J((165, 0, 8), (0, 0.23, 0)), lShoulder=J((12, 0, -8)))
soft(boat, head=2.0, arms=2.6).plant(stance=0.32)
boat.build()

# Jackpot Shuffle (the jackpot dance): a loose sway of the hips from side to side, bent arms swinging
# in front, the shoulders shimmying between beats, the head bobbing. 4 beats of 0.4 s.
jackpot = Motion("jackpotShuffle", 1.6, loop=True, note="Hips swaying loose, bent arms swinging in front, a shimmy between beats.")
for i in range(8):
    t = i * 0.2
    beat = i % 2 == 0
    s = 1 if (i // 2) % 2 == 0 else -1
    shimmy = 0 if beat else (6 if (i // 2) % 2 == 0 else -6)
    jackpot.key(t, offset=(0.17 * s, -0.16 if beat else -0.08, 0), root=(-5, 10 * s, -6 * s), neck=(-6 if beat else 2, -5 * s, 4 * s),
                rShoulder=J((62 + shimmy, 0, -26 * s - 4), (-0.06, 0.06, -0.2)),
                lShoulder=J((62 - shimmy, 0, -26 * s + 4), (0.06, 0.06, -0.2)))
soft(jackpot, head=4.0, arms=3.6).plant(stance=0.2)
jackpot.build()

# The Classic (the default dance): arms pumping across the body by turns with a bounce, then the elbows
# working like pistons while the hips swing. 8 beats of 0.4 s.
classic = Motion("theClassic", 3.2, loop=True, note="Arms pumping across the body, then pistons and a hip swing.")
for i in range(4):
    t = i * 0.4
    s = 1 if i % 2 == 0 else -1
    classic.key(t, offset=(0.06 * s, -0.14, 0), root=(-4, 8 * s, 0), neck=(-6, 4 * s, 0),
                rShoulder=J((58, 0, -42), (-0.16, 0.05, -0.12)) if s > 0 else J((-22, 0, 20)),
                lShoulder=J((-22, 0, -20)) if s > 0 else J((58, 0, 42), (0.16, 0.05, -0.12)))
    classic.key(t + 0.2, offset=(0, -0.04, 0), root=(-2, 0, 0), neck=(-2, 0, 0),
                rShoulder=J((26, 0, -8)), lShoulder=J((26, 0, 8)))
for i in range(4):
    t = 1.6 + i * 0.4
    s = 1 if i % 2 == 0 else -1
    classic.key(t, offset=(0.16 * s, -0.12, 0), root=(-3, 0, -7 * s), neck=(0, 0, 5 * s),
                rShoulder=J((54 + 22 * s, 0, 8), (0, 0.06 + 0.06 * s, -0.22)), lShoulder=J((54 - 22 * s, 0, -8), (0, 0.06 - 0.06 * s, -0.22)))
    classic.key(t + 0.2, offset=(0, -0.06, 0), root=(-3, 0, 0), neck=(0, 0, 0),
                rShoulder=J((54 - 22 * s, 0, 8), (0, 0.06 - 0.06 * s, -0.22)), lShoulder=J((54 + 22 * s, 0, -8), (0, 0.06 + 0.06 * s, -0.22)))
soft(classic, arms=3.6).plant(stance=0.14)
classic.build()

# Bounce Pump (the big bouncy arm pump): arms swung low across the body while a leg swings out to the
# side, then the other way, a bounce through every beat. 4 beats of 0.3 s.
pump = Motion("bouncePump", 1.2, loop=True, note="Arms swung low across the body as a leg swings out, side to side, bouncing.")
for i in range(4):
    t = i * 0.3
    if i % 2 == 0:
        pump.key(t, offset=(0, -0.02, 0), root=(-3, 0, 0), neck=(2, 0, 0),
                 rShoulder=J((22, 0, 6)), lShoulder=J((22, 0, -6)))
    else:
        s = 1 if i == 1 else -1
        pump.key(t, "out", offset=(-0.08 * s, -0.2, 0), root=(-8, -6 * s, 8 * s), neck=(-4, 0, -4 * s),
                 rShoulder=J((34, 0, -46 * s + 6), (-0.08 * s, 0.02, -0.1)), lShoulder=J((34, 0, -46 * s - 6), (-0.08 * s, 0.02, -0.1)))
raise_leg(pump, "rHip", 0.06, 0.26, 0.34, 0.56, J((10, 0, 34), (0, 0.16, 0)))
raise_leg(pump, "lHip", 0.66, 0.86, 0.94, 1.16, J((10, 0, -34), (0, 0.16, 0)))
soft(pump, arms=3.0).plant(stance=0.08)
pump.build()

# Rat Dance: the arms crossing and uncrossing in front of the chest while the legs cross-step, a little
# bob on every step. 4 half-beats of 0.24 s.
rat = Motion("ratDance", 0.96, loop=True, note="Arms crossing and uncrossing in front, legs cross-stepping, a bob on each step.")
for i in range(4):
    t = i * 0.24
    crossed = i % 2 == 0
    s = 1 if i < 2 else -1
    if crossed:
        rat.key(t, offset=(0.05 * s, -0.12, 0), root=(-4, 6 * s, 0), neck=(-4, 4 * s, 0),
                rShoulder=J((70, 0, -46), (-0.3, 0.1, -0.2)), lShoulder=J((66, 0, 46), (0.3, 0.08, -0.2)))
    else:
        rat.key(t, offset=(0.08 * s, -0.02, 0), root=(-2, 0, -3 * s), neck=(2, 0, 3 * s),
                rShoulder=J((44, 0, 30)), lShoulder=J((44, 0, -30)))
# The right leg crosses over on the loop's seam (0 s), the left half-way: the right one in two windows.
cross_r, cross_l = J((14, 0, -14), (-0.08, 0.06, -0.04)), J((14, 0, 14), (0.08, 0.06, -0.04))
lift(rat, "rHip", ((0.0, 1, cross_r), (0.12, 0, cross_r)))
lift(rat, "rHip", ((0.84, 0, cross_r), (0.96, 1, cross_r)))
raise_leg(rat, "lHip", 0.36, 0.48, 0.48, 0.6, cross_l)
soft(rat, head=4.0, arms=4.4).plant(stance=0.1)
rat.build()

# Bunny Ears (the ears dance): hands up on the head flapping like ears on every beat, the hips swaying
# side to side over two. 4 beats of 0.36 s.
bunny = Motion("bunnyEars", 1.44, loop=True, note="Hands on the head flapping like ears, hips swaying side to side.")
for i in range(8):
    t = i * 0.18
    flap = 1 if i % 2 == 0 else -1
    s = 1 if i < 4 else -1
    sway = math.sin(math.pi * (i % 4) / 4)
    bunny.key(t, offset=(0.15 * s * sway, -0.06, 0), root=(-2, 0, -5 * s * sway), neck=(0, 0, 6 * s * sway),
              rShoulder=J((154 + 8 * flap, 0, -18), (-0.14, 0.26, -0.02)),
              lShoulder=J((154 + 8 * flap, 0, 18), (0.14, 0.26, -0.02)))
soft(bunny, head=3.0, arms=5.0).plant(stance=0.08)
bunny.build()

# Puppet Pop (puppetPop): rebuilt 2026-10-17 as the real "Bye Bye Bye" chorus, in emotes/dances.py.

# Glitch Step: a robot's dance that stutters like a tape skipping, held poses and repeats, cut, not
# eased. 12 frames of 0.2 s.
glitch = Motion("glitchStep", 2.4, loop=True, note="Robot poses that skip and stutter like a damaged tape.")
poses = [
    (0.0, (0, -0.04, 0), (0, 0, 0), (0, 0, 0), J((90, 0, 8), (0, 0.04, -0.08)), J((4, 0, -8))),
    (0.2, (0, -0.04, 0), (0, -8, 0), (0, -26, 0), J((160, 0, 10), (0, 0.2, 0)), J((4, 0, -8))),
    (0.4, (0, -0.09, 0), (0, -8, 0), (0, -26, 0), J((160, 0, 10), (0, 0.2, 0)), J((4, 0, -8))),
    (0.6, (0, -0.04, 0), (0, 20, 0), (0, 0, 0), J((90, 0, 6), (0, 0.04, -0.08)), J((90, 0, -6), (0, 0.04, -0.08))),
    (0.8, (0, -0.04, 0), (0, 6, 0), (0, 26, 0), J((4, 0, 8)), J((160, 0, -10), (0, 0.2, 0))),
    (1.0, (0.05, -0.04, 0), (0, 6, 4), (0, 26, 4), J((4, 0, 8)), J((160, 0, -10), (0, 0.2, 0))),
    (1.2, (0, -0.16, 0), (0, 0, 0), (-6, 0, 0), J((2, 0, 90), (0, 0.1, 0)), J((2, 0, -90), (0, 0.1, 0))),
    (1.4, (0, -0.1, 0), (-4, 0, 0), (-4, 0, 0), J((64, 0, -20), (-0.1, 0.08, -0.2)), J((64, 0, 20), (0.1, 0.08, -0.2))),
    (1.6, (0, -0.04, 0), (0, -14, 0), (0, -10, 0), J((88, 0, -4), (0, 0.06, -0.1)), J((8, 0, -8))),
    (1.8, (0, 0.0, 0), (0, -14, 0), (2, -10, 0), J((88, 0, -4), (0, 0.06, -0.1)), J((8, 0, -8))),
    (2.0, (0, -0.02, 0), (4, 0, 0), (10, 0, 0), J((150, 0, 30), (0, 0.18, 0)), J((150, 0, -30), (0, 0.18, 0))),
    (2.2, (0, -0.06, 0), (4, 0, 0), (10, 0, -8), J((150, 0, 30), (0, 0.18, 0)), J((150, 0, -30), (0, 0.18, 0))),
]
for t, off, root, neck, r, l in poses:
    glitch.key(t, "hold", offset=off, root=root, neck=neck, rShoulder=r, lShoulder=l)
glitch.plant(stance=0.12)
glitch.build()

# Goal Celebration (the jump turn): a few quick steps on the spot, a leap with a full turn in the air,
# and the landing wide with both arms thrust down and back, held, then up again. One shot.
goal = Motion("goalCelebration", 2.6, note="Quick steps, a leap with a full turn, and the wide landing with arms thrust down and back.")
goal.key(0.0, **REST, rHip=J((0, 0, 0)), lHip=J((0, 0, 0)))
for i, s in enumerate((1, -1, 1)):
    t = 0.12 + 0.12 * i
    goal.key(t, offset=(0, -0.04, 0), root=(-8, 0, 0), neck=(-4, 0, 0),
             rShoulder=J((-24 * s, 0, 10)), lShoulder=J((24 * s, 0, -10)),
             rHip=J((26 if s > 0 else -10, 0, 2), (0, 0.18 if s > 0 else 0.02, 0)),
             lHip=J((-10 if s > 0 else 26, 0, -2), (0, 0.02 if s > 0 else 0.18, 0)))
goal.key(0.5, "in", offset=(0, -0.3, 0), root=(-10, 0, 0), neck=(-6, 0, 0),
         rShoulder=J((-30, 0, 18)), lShoulder=J((-30, 0, -18)),
         rHip=J((10, 0, 3), (0, 0.3, -0.04)), lHip=J((10, 0, -3), (0, 0.3, -0.04)))
for i in range(1, 5):
    t = 0.5 + 0.13 * i
    high = 1.25 * math.sin(math.pi * i / 5)
    goal.key(t, "linear", offset=(0, high, 0), root=(-4, 90 * i, 0), neck=(6, 0, 0),
             rShoulder=J((150, 0, 20), (0, 0.18, 0)) if i < 4 else J((60, 0, 30)),
             lShoulder=J((40, 0, -40)) if i < 4 else J((60, 0, -30)),
             rHip=J((36, 0, 6), (0, 0.34, -0.1)), lHip=J((30, 0, -6), (0, 0.3, -0.1)))
goal.key(1.2, "in", offset=(0, -0.32, 0), root=(14, 360, 0), neck=(14, 0, 0),
         rShoulder=J((-38, 0, 30), (0, 0.04, 0.06)), lShoulder=J((-38, 0, -30), (0, 0.04, 0.06)),
         rHip=J((0, 0, 18), (0, 0.24, 0)), lHip=J((0, 0, -18), (0, 0.24, 0)))
goal.key(1.95, offset=(0, -0.34, 0), root=(16, 360, 0), neck=(18, 0, 0),
         rShoulder=J((-40, 0, 32), (0, 0.04, 0.06)), lShoulder=J((-40, 0, -32), (0, 0.04, 0.06)))
goal.key(2.6, offset=(0, 0, 0), root=(0, 360, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)),
         rHip=J((0, 0, 0)), lHip=J((0, 0, 0)))
goal.plant(1.2, 2.6, stance=0.42)
soft(goal, arms=3.4)
goal.build()

# Take the L: a hand up to the forehead in an L, hopping from one foot to the other with the free leg
# kicking out. One shot.
take = Motion("takeTheL", 2.8, note="A hand up in an L on the forehead, hopping foot to foot, the free leg kicking out.")
take.key(0.0, **REST)
l_hand = J((150, 0, -22), (-0.2, 0.28, -0.08))
take.key(0.3, "out", offset=(0, -0.04, 0), root=(-2, 0, 0), neck=(4, 0, 0), rShoulder=l_hand, lShoulder=J((12, 0, -12)),
         rHip=J((0, 0, 0)), lHip=J((0, 0, 0)))
for i in range(4):
    t = 0.55 + 0.4 * i
    s = 1 if i % 2 == 0 else -1  # the free leg
    take.key(t, "out", offset=(-0.12 * s, 0.22, 0), root=(-2, -6 * s, 4 * s), neck=(4, 0, -4 * s), rShoulder=l_hand,
             lShoulder=J((30, 0, -26 - 10 * s)),
             rHip=J((34, 0, 26), (0, 0.16, -0.06)) if s > 0 else J((-4, 0, 2)),
             lHip=J((-4, 0, -2)) if s > 0 else J((34, 0, -26), (0, 0.16, -0.06)))
    take.key(t + 0.2, "in", offset=(-0.06 * s, 0.0, 0), root=(-3, 0, 2 * s), neck=(2, 0, 0), rShoulder=l_hand,
             lShoulder=J((20, 0, -18)), rHip=J((2, 0, 2)), lHip=J((2, 0, -2)))
take.key(2.8, **REST, rHip=J((0, 0, 0)), lHip=J((0, 0, 0)), offset=(0, 0, 0))
soft(take, arms=3.0)
take.build()

# Two Weeks' Notice (corporate escape): the arms flung up in despair, a fit of flailing with the head
# shaking, an imaginary letter thrown over the shoulder, a slump, done. One shot.
quit_ = Motion("twoWeeksNotice", 3.2, note="Arms flung up, wild flailing, a letter thrown over the shoulder, a slump.")
quit_.key(0.0, **REST)
quit_.key(0.3, "out", offset=(0, 0.02, 0.05), root=(8, 0, 0), neck=(16, 0, 0),
          rShoulder=J((168, 0, 26), (0, 0.24, 0)), lShoulder=J((168, 0, -26), (0, 0.24, 0)))
for i in range(6):  # flailing: the arms windmilling against each other, the head shaking
    t = 0.55 + 0.2 * i
    s = 1 if i % 2 == 0 else -1
    quit_.key(t, offset=(0.04 * s, -0.04, 0.02), root=(2, 8 * s, 4 * s), neck=(-2, -18 * s, 4 * s),
              rShoulder=J((140 if s > 0 else 30, 0, 50 if s > 0 else 20), (0, 0.12, 0)),
              lShoulder=J((30 if s > 0 else 140, 0, -20 if s > 0 else -50), (0, 0.12, 0)))
quit_.key(1.95, offset=(0, -0.04, 0), root=(-6, -10, 0), neck=(-4, -6, 0),
          rShoulder=J((70, 0, -24), (-0.16, 0.08, -0.1)), lShoulder=J((10, 0, -8)))
quit_.key(2.2, "snap", offset=(0, 0, 0.04), root=(6, 12, 0), neck=(10, 12, 0),
          rShoulder=J((176, 0, 60), (0, 0.2, 0.04)), lShoulder=J((10, 0, -8)))
quit_.key(2.7, offset=(0, -0.08, 0), root=(-10, 0, 0), neck=(-24, 0, 0),
          rShoulder=J((8, 0, 2), (-0.04, -0.06, -0.06)), lShoulder=J((8, 0, -2), (0.04, -0.06, -0.06)))
quit_.key(3.2, **REST)
soft(quit_, arms=3.2).plant(stance=0.12)
quit_.build()


# Poses -----------------------------------------------------------------------------------------------------
# The ones with a face swap a drawn expression onto the head while they play (Shared/EmoteMedia FACES); the
# body has to carry them alone until the owner has uploaded the faces.

# Impossible Lean: a touch of the hat brim, the hands down at the sides, then the whole body tipping
# forward from the ankles, rigid as a plank, held there, and back. The body turns about its middle, so it
# is moved forward and down to keep the feet where they stand.
lean = Motion("impossibleLean", 3.8, note="A touch of the hat, then the whole body leaning far forward from the ankles, held.")
lean.key(0.0, **REST)
lean.key(0.35, root=(0, 0, 0), neck=(-4, 0, 0), rShoulder=J((150, 0, -30), (-0.2, 0.24, -0.1)), lShoulder=J((2, 0, -4)))
lean.key(0.75, root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=J((3, 0, 5)), lShoulder=J((3, 0, -5)))
TIP = 32.0
for i in range(11):  # the tip forward and the way back, keyed finely so the feet stay put
    for t0, t1, a0, a1 in ((0.75, 1.65, 0.0, 1.0), (2.85, 3.6, 1.0, 0.0)):
        t = t0 + (t1 - t0) * i / 10
        u = a0 + (a1 - a0) * (0.5 - 0.5 * math.cos(math.pi * i / 10))
        theta = math.radians(TIP * u)
        lean.key(t, "linear", offset=(0, -3 + 3 * math.cos(theta), -3 * math.sin(theta)), root=(-TIP * u, 0, 0),
                 neck=(-6 + 14 * u, 0, 0), rShoulder=J((3, 0, 5)), lShoulder=J((3, 0, -5)), rHip=J((0, 0, 0)), lHip=J((0, 0, 0)))
lean.key(3.8, **REST, rHip=J((0, 0, 0)), lHip=J((0, 0, 0)), offset=(0, 0, 0))
lean.follow(ARMS, 3.0, 0.7)
lean.build()

# Nah, I'd Win: leaning back on one hip, the chin up, hands in the pockets, utterly sure. A loop (also a
# stance).
win = Motion("nahIdWin", 4.0, loop=True, note="Leaning back on one hip, chin up, hands in the pockets, utterly sure.")
for t, b in ((0.0, 0.0), (2.0, 1.0)):
    win.key(t, offset=(0.07, -0.03, 0), root=(6 + 0.6 * b, 8, 4), neck=(9 - b, -10 + 2 * b, -4),
            rShoulder=J((10, 0, -4), (-0.08, 0.12 + 0.01 * b, -0.02)), lShoulder=J((10, 0, 4), (0.08, 0.12 + 0.01 * b, -0.02)))
soft(win, head=1.4, arms=1.4).plant(stance=0.12)
win.build()

# Jawline Check: a thumb run along the jaw from under the ear to the chin, the chin lifted, a flick off the
# end, and a smug stare.
jaw = Motion("jawlineCheck", 3.2, note="A thumb run along the jaw to the chin, chin up, a flick, a smug stare.")
jaw.key(0.0, **REST)
jaw.key(0.45, "out", root=(2, 0, 0), neck=(10, 10, 0), rShoulder=J((112, 0, -14), (-0.16, 0.16, -0.16)), lShoulder=J((4, 0, -4)))
jaw.key(1.05, root=(2, -2, 0), neck=(13, 2, 0), rShoulder=J((116, 0, -24), (-0.22, 0.15, -0.2)), lShoulder=J((4, 0, -4)))
jaw.key(1.6, root=(2, -4, 0), neck=(15, -6, 0), rShoulder=J((118, 0, -34), (-0.3, 0.14, -0.24)), lShoulder=J((4, 0, -4)))
jaw.key(1.85, "snap", root=(2, -4, 0), neck=(12, -4, 2), rShoulder=J((100, 0, 12), (-0.08, 0.1, -0.14)), lShoulder=J((4, 0, -4)))
jaw.key(2.5, root=(1, -4, 0), neck=(10, -2, 4), rShoulder=J((20, 0, 8)), lShoulder=J((4, 0, -4)))
jaw.key(3.2, **REST)
soft(jaw).plant(stance=0.04)
jaw.build()

# The Eyebrow: the head turned a little and tilted, the chin dipped, a hand on the hip, one brow going up
# (the face) and staying up.
brow = Motion("theEyebrow", 3.4, note="A slow head tilt, a hand on the hip, one eyebrow going up and staying there.")
brow.key(0.0, **REST)
brow.key(0.8, "sine", root=(0, 6, 0), neck=(-6, 14, 8), rShoulder=J((4, 0, 4)), lShoulder=J((14, 0, -34), (0.12, 0.1, 0.06)))
brow.key(2.0, root=(0, 6, 0), neck=(-7, 16, 10), rShoulder=J((4, 0, 4)), lShoulder=J((14, 0, -34), (0.12, 0.1, 0.06)))
brow.key(2.7, root=(0, 6, 0), neck=(-7, 16, 10), rShoulder=J((4, 0, 4)), lShoulder=J((14, 0, -34), (0.12, 0.1, 0.06)))
brow.key(3.4, **REST)
soft(brow, head=1.8).plant(stance=0.06)
brow.build()

# It's You: a sharp turn three-quarters on, the arm thrown out straight at someone, the other hand at the
# brim of the hat, the chin down. Held.
you = Motion("itsYou", 2.6, note="A sharp three-quarter turn, the arm thrown out straight at someone, a hand at the hat brim.")
you.key(0.0, **REST)
you.key(0.22, "snap", root=(-2, -20, 0), neck=(-10, 18, 0), rShoulder=J((92, 0, 2), (0, 0.1, -0.12)),
        lShoulder=J((150, 0, 30), (0.2, 0.24, -0.1)))
you.key(2.0, root=(-3, -20, 0), neck=(-11, 18, 0), rShoulder=J((90, 0, 2), (0, 0.1, -0.12)), lShoulder=J((150, 0, 30), (0.2, 0.24, -0.1)))
you.key(2.6, **REST)
soft(you, arms=4.5).plant(stance=0.18, forward=(0.15, -0.15))
you.build()

# Menacing Pose: a twisted, impossible stance, a hand spread across the face, the other arm flung down and
# back, the head turned over the shoulder; floating signs rise round the body (EmoteFx). A loop.
menace = Motion("menacingPose", 4.0, loop=True, note="A twisted dramatic stance, a hand across the face, the head over the shoulder.")
for t, b in ((0.0, 0.0), (2.0, 1.0)):
    menace.key(t, offset=(0.1, -0.12 - 0.02 * b, 0), root=(-4 + b, 30, -10), neck=(6, -40 + 2 * b, 12),
               rShoulder=J((-30, 0, 40 + 2 * b)), lShoulder=J((132, 0, 42), (0.3, 0.2, -0.2)))
soft(menace, head=1.2, arms=1.2).plant(stance=0.3, forward=(0.3, -0.2))
menace.build()

# Low Battery: powering down by stages, a stutter at each, the head dropping, then the knees going and
# down to sit slumped on the floor. Lobby only (it looks too much like a death).
low = Motion("lowBattery", 4.6, note="Powering down by stages with a stutter at each, down to sit slumped on the floor.")
low.key(0.0, **REST)
low.key(0.6, "snap", offset=(0, -0.12, 0), root=(-6, 0, 0), neck=(-14, 0, 0),
        rShoulder=J((6, 0, 2), (0, -0.05, 0)), lShoulder=J((6, 0, -2), (0, -0.05, 0)))
low.key(0.75, offset=(0, -0.08, 0), root=(-5, 0, 0), neck=(-12, 0, 0), rShoulder=J((5, 0, 2)), lShoulder=J((5, 0, -2)))
low.key(1.4, "snap", offset=(0, -0.35, 0), root=(-14, 0, 2), neck=(-26, 0, 4),
        rShoulder=J((10, 0, 0), (0, -0.08, 0)), lShoulder=J((10, 0, 0), (0, -0.08, 0)))
low.key(1.55, offset=(0, -0.3, 0), root=(-13, 0, 2), neck=(-24, 0, 4), rShoulder=J((9, 0, 0)), lShoulder=J((9, 0, 0)))
low.key(2.3, "in", offset=(0, -0.9, 0.1), root=(-20, 0, 4), neck=(-30, 0, 6), rShoulder=J((14, 0, 2)), lShoulder=J((14, 0, -2)),
        rHip=J((40, 0, 4), (0, 0.5, -0.1)), lHip=J((40, 0, -4), (0, 0.5, -0.1)))
low.key(2.9, "in", offset=(0, 0, 0.2), floor=True, root=(-24, 0, 6), neck=(-36, 0, 8),
        rShoulder=J((12, 0, 6)), lShoulder=J((12, 0, -6)), rHip=J((86, 0, 6)), lHip=J((86, 0, -6)))
low.key(4.6, offset=(0, 0, 0.2), floor=True, root=(-28, 0, 8), neck=(-40, 0, 10),
        rShoulder=J((10, 0, 8)), lShoulder=J((10, 0, -8)), rHip=J((86, 0, 6)), lHip=J((86, 0, -6)))
low.plant(0.0, 1.6, stance=0.04)
soft(low, head=2.0, arms=1.6)
low.build()

# Deducing: hunched, a thumb pressed to the lip, the other hand in a pocket, the eyes going over the room.
# A loop (also a stance).
deduce = Motion("deducing", 4.0, loop=True, note="Hunched, a thumb pressed to the lip, the eyes going over the room.")
for t, look in ((0.0, 0), (1.0, 10), (2.4, -8), (3.0, -6)):
    tap = 6 if t == 3.0 else 0
    deduce.key(t, offset=(0, -0.1, 0), root=(-12, 0, 0), neck=(-6, look, 0),
               rShoulder=r_face(118 + tap, -34), lShoulder=J((8, 0, 4), (0.08, 0.1, -0.02)))
soft(deduce, head=1.6, arms=2.0).plant(stance=0.18)
deduce.build()

# Just As Planned (justAsPlanned): rebuilt 2026-10-17 from the keikaku doori scene, in emotes/poses.py.

# Reaper's Cackle: hunched over, shoulders up round the ears, the arms hanging loose in front, shaking
# with a wide grin (the face). A loop.
cackle = Motion("reapersCackle", 1.2, loop=True, note="Hunched, shoulders up, arms hanging loose, shaking with a wide grin.")
for i in range(12):
    t = i * 0.1
    j = 1 if i % 2 == 0 else -1
    sway = math.sin(2 * math.pi * t / 1.2)
    cackle.key(t, offset=(0.04 * sway, -0.12 + 0.03 * j, 0), root=(-18 + 2 * j, 4 * sway, 3 * sway), neck=(10 + 4 * j, -4 * sway, 0),
               rShoulder=J((20 + 4 * j, 0, -6), (0, 0.12, -0.05)), lShoulder=J((20 - 4 * j, 0, 6), (0, 0.12, -0.05)))
cackle.follow(ARMS, 6.0, 0.5).plant(stance=0.15)
cackle.build()

# Final Breakdown: thrown back laughing with the arms flung wide, shaking, then doubled over clutching the
# stomach, then back once more. Unhinged (the face: a wide grin).
breakdown = Motion("finalBreakdown", 4.4, note="Thrown back laughing, arms flung wide, then doubled over, then back again.")
breakdown.key(0.0, **REST)
breakdown.key(0.5, "out", offset=(0, -0.1, 0.25), root=(22, 0, 0), neck=(30, 0, 0), rShoulder=J((70, 0, 70)), lShoulder=J((70, 0, -70)))
for i in range(1, 12):
    t = 0.5 + 0.12 * i
    j = 1 if i % 2 == 0 else -1
    breakdown.key(t, offset=(0, -0.1, 0.25), root=(22 + 3 * j, 0, 0), neck=(30 + 5 * j, 0, 0),
                  rShoulder=J((70 + 6 * j, 0, 70)), lShoulder=J((70 - 6 * j, 0, -70)))
breakdown.key(2.25, "in", offset=(0, -0.2, -0.1), root=(-26, 0, 0), neck=(-10, 0, 0),
              rShoulder=J((40, 0, -40), (-0.25, 0, -0.15)), lShoulder=J((40, 0, 40), (0.25, 0, -0.15)))
for i in range(1, 8):
    t = 2.25 + 0.12 * i
    j = 1 if i % 2 == 0 else -1
    breakdown.key(t, offset=(0, -0.2 + 0.02 * j, -0.1), root=(-26 + 3 * j, 0, 0), neck=(-10 + 4 * j, 0, 0),
                  rShoulder=J((40, 0, -40), (-0.25, 0, -0.15)), lShoulder=J((40, 0, 40), (0.25, 0, -0.15)))
breakdown.key(3.55, "out", offset=(0, -0.08, 0.2), root=(16, 0, 0), neck=(24, 0, 0), rShoulder=J((54, 0, 54)), lShoulder=J((54, 0, -54)))
breakdown.key(4.4, **REST)
soft(breakdown, arms=3.6).plant(stance=0.2, forward=(0.1, -0.1))
breakdown.build()

# New World: the arms spread wide and lifted, the chest out, the face up, rising off the floor into a beam of
# light from above (EmoteFx), held, and back down.
world = Motion("newWorld", 4.4, note="Arms spread wide and lifted, face up, rising off the floor into a beam of light.")
world.key(0.0, **REST, rHip=J((0, 0, 0)), lHip=J((0, 0, 0)), offset=(0, 0, 0))
world.key(1.4, "sine", offset=(0, 0.35, 0), root=(8, 0, 0), neck=(22, 0, 0), rShoulder=J((40, 0, 110), (0, 0.1, 0)),
          lShoulder=J((40, 0, -110), (0, 0.1, 0)), rHip=J((4, 0, 3)), lHip=J((4, 0, -3)))
world.key(2.5, offset=(0, 0.4, 0), root=(9, 0, 0), neck=(24, 0, 0), rShoulder=J((42, 0, 112), (0, 0.1, 0)),
          lShoulder=J((42, 0, -112), (0, 0.1, 0)), rHip=J((5, 0, 3)), lHip=J((5, 0, -3)))
world.key(3.6, offset=(0, 0.36, 0), root=(8, 0, 0), neck=(22, 0, 0), rShoulder=J((40, 0, 110), (0, 0.1, 0)),
          lShoulder=J((40, 0, -110), (0, 0.1, 0)), rHip=J((4, 0, 3)), lHip=J((4, 0, -3)))
world.key(4.4, "sine", **REST, rHip=J((0, 0, 0)), lHip=J((0, 0, 0)), offset=(0, 0, 0))
soft(world, head=1.6, arms=1.8).follow(("rHip", "lHip"), 1.4, 0.8)
world.build()

# Reaper's Eyes: looking away over the shoulder, then the head turning slowly round to stare, the eyes
# glowing red (EmoteFx). Lobby only (it looks like the Eyes).
eyes = Motion("reapersEyes", 3.2, note="Looking away, then the head turning slowly round to stare, eyes glowing.")
eyes.key(0.0, **REST)
eyes.key(0.5, root=(0, 12, 0), neck=(0, 70, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))
eyes.key(0.9, root=(0, 12, 0), neck=(0, 70, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))
eyes.key(2.5, "sine", root=(-2, 0, 0), neck=(-8, 0, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))
eyes.key(3.2, root=(-2, 0, 0), neck=(-9, 0, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))
eyes.follow("neck", 1.6, 0.9).plant(stance=0.06)
eyes.build()

# Foot Scratch: standing on one leg, the bare foot of the other rubbing up and down the shin, hunched, the
# head down watching. A loop (also a stance).
scratch = Motion("footScratch", 2.0, loop=True, note="On one leg, the other foot rubbing up and down the shin, hunched.")
for t, b in ((0.0, 0.0), (1.0, 1.0)):
    scratch.key(t, offset=(-0.08, -0.05, 0), root=(-8, 4, -3), neck=(-18, 4, 0),
                rShoulder=J((12, 0, 4)), lShoulder=J((12, 0, -4)))
rub_low, rub_high = J((10, 0, -12), (-0.22, 0.34, -0.1)), J((10, 0, -12), (-0.22, 0.6, -0.1))
lift(scratch, "rHip", ((0.0, 1, rub_low), (0.5, 1, rub_high), (1.0, 1, rub_low), (1.5, 1, rub_high), (2.0, 1, rub_low)))
soft(scratch, head=1.6, arms=1.6).plant(stance=0.0)
scratch.build()

# Hair Twirl: sitting on the floor with the legs out in front in a V, slouched, the other hand propped on
# the floor, a hand at the side of the head twisting a lock of hair round a finger. A loop (also a stance;
# rigid R6 legs cannot draw a knee up).
twirl = Motion("hairTwirl", 2.4, loop=True, note="Sitting on the floor, legs out, twisting a lock of hair by the head.")
for i in range(4):
    t = i * 0.6
    a = 2 * math.pi * i / 4
    twirl.key(t, offset=(0, 0, 0.3), floor=True, root=(-10, 8, 0), neck=(-10, 10, 8),
              rShoulder=J((150, 0, -10), (-0.08 + 0.04 * math.cos(a), 0.26, 0.04 * math.sin(a))),
              lShoulder=J((-16, 0, -26), (0, -0.1, 0.1)),
              rHip=J((90, 0, 14)), lHip=J((90, 0, -18)))
soft(twirl, head=1.2, arms=4.0)
twirl.build()


# Emotes with props ---------------------------------------------------------------------------------------
# What each holds or sets down, and when, is in src/shared/Anim/EmoteProps.luau; the timings here and there
# go together.

import posekit  # noqa: E402
from motion import SOLE_X  # noqa: E402


def crouch_legs(offset, root, stance, tilt):
    """The legs of a crouch on the heels (plant() with a tilt), worked out once, so a crouch can be done
    somewhere else than on the floor: on a chair's seat."""
    legs = {}
    for key, side in (("rHip", 1), ("lHip", -1)):
        angles, slide = posekit.planted_slide(side, (side * (SOLE_X + stance), 0.0, 0.0), root, offset, pitch=tilt)
        legs[key] = J(angles, slide)
    return legs


# Pre-Dawn Bonk: stiff as a post, the club brought down three times with a stamp each, then once more
# from high over the head, hard. One shot.
bonk = Motion("preDawnBonk", 3.6, note="Stiff, the club brought down three times with a stamp each, then once from on high.")
bonk.key(0.0, **REST)
bonk.key(0.3, root=(2, 0, 0), neck=(4, 0, 0), rShoulder=J((60, 0, 10), (0, 0.05, -0.1)), lShoulder=J((4, 0, -6)))
stamp = J((26, 0, 4), (0, 0.28, -0.06))
for t in (0.75, 1.25, 1.75):
    bonk.key(t - 0.2, "out", offset=(0, 0.04, 0), root=(4, 0, 0), neck=(6, 0, 0), rShoulder=J((150, 0, 14), (0, 0.2, 0)),
             lShoulder=J((10, 0, -14)))
    bonk.key(t, "snap", offset=(0, -0.1, 0), root=(-8, 0, 0), neck=(-8, 0, 0), rShoulder=J((62, 0, 6), (0, 0.05, -0.14)),
             lShoulder=J((16, 0, -18)))
    raise_leg(bonk, "rHip", t - 0.24, t - 0.12, t - 0.1, t, stamp)
bonk.key(2.3, "out", offset=(0, 0.06, 0.04), root=(12, 0, 0), neck=(14, 0, 0), rShoulder=J((178, 0, 10), (0, 0.26, 0.06)),
         lShoulder=J((30, 0, -30)))
bonk.key(2.55, "snap", offset=(0, -0.2, -0.05), root=(-16, 0, 0), neck=(-14, 0, 0), rShoulder=J((48, 0, 4), (0, 0.02, -0.16)),
         lShoulder=J((26, 0, -24)))
bonk.key(3.05, offset=(0, -0.16, 0), root=(-12, 0, 0), neck=(-10, 0, 0), rShoulder=J((50, 0, 4), (0, 0.02, -0.16)),
         lShoulder=J((22, 0, -20)))
bonk.key(3.6, **REST)
soft(bonk, arms=4.0).plant(stance=0.18)
bonk.build()

# Blindfold Lift: two fingers up to the blindfold over the eyes, pushed up onto the brow, the chin lifting
# to a stare (the face), the hand coming down to a sign before the chest. One shot.
blind = Motion("blindfoldLift", 3.6, note="Fingers to the blindfold, pushed up onto the brow, a stare, a hand sign.")
blind.key(0.0, root=(0, 0, 0), neck=(-4, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))
blind.key(0.55, root=(0, 0, 0), neck=(-4, 0, 0), rShoulder=J((150, 0, -24), (-0.18, 0.3, -0.06)), lShoulder=J((2, 0, -4)))
blind.key(0.95, root=(0, 0, 0), neck=(-3, 0, 0), rShoulder=J((151, 0, -24), (-0.18, 0.3, -0.06)), lShoulder=J((2, 0, -4)))
blind.key(1.35, "out", root=(2, 0, 0), neck=(7, 0, 0), rShoulder=J((168, 0, -18), (-0.14, 0.36, 0.02)), lShoulder=J((2, 0, -4)))
blind.key(1.9, root=(2, 0, 0), neck=(6, 0, 0), rShoulder=J((80, 0, -30), (-0.2, 0.1, -0.18)), lShoulder=J((2, 0, -4)))
blind.key(3.0, root=(2, 0, 0), neck=(6, 0, 0), rShoulder=J((81, 0, -30), (-0.2, 0.1, -0.18)), lShoulder=J((2, 0, -4)))
blind.key(3.6, **REST)
soft(blind, head=2.0).plant(stance=0.08)
blind.build()

# Chair Perch: crouched on the seat of a chair (the game puts one under the body), knees drawn up, a thumb
# at the lip, the other hand on a knee, rocking a little. A loop.
SEAT = 1.75
perch = Motion("chairPerch", 4.0, loop=True, note="Crouched on a chair's seat, knees up, a thumb at the lip, rocking a little.")
perch_off, perch_root = (0, -1.35 + SEAT, 0.1), (-10, 0, 0)
for t, b in ((0.0, 0.0), (2.0, 1.0)):
    perch.key(t, offset=(0, perch_off[1] + 0.03 * b, perch_off[2]), root=(-10 + 2 * b, 0, -2 + 4 * b), neck=(0, 6 - 12 * b, 2 * b),
              rShoulder=r_face(116, -34), lShoulder=J((62, 0, 6), (0.0, 0.06, -0.36)))
# (the legs of the same crouch on the floor: relative to the body they are the same up on the seat)
for key, value in crouch_legs((0, -1.35, perch_off[2]), perch_root, 0.14, 34).items():
    lift(perch, key, ((0.0, 1, value), (4.0, 1, value)))
soft(perch, head=1.4, arms=1.4)
perch.build()

# Two-Finger Grip: hunched, a phone dangled from two fingertips at eye level and looked at, the other hand
# in a pocket. A loop (also a stance).
grip = Motion("twoFingerGrip", 3.0, loop=True, note="Hunched, a phone dangled from two fingertips at eye level.")
for t, b in ((0.0, 0.0), (1.5, 1.0)):
    grip.key(t, offset=(0, -0.08, 0), root=(-10, 0, 0), neck=(-2, 6 + 2 * b, 4),
             rShoulder=J((118 + b, 0, -16), (-0.08, 0.12, -0.12)), lShoulder=J((8, 0, 4), (0.08, 0.1, -0.02)))
soft(grip, head=1.5, arms=1.5).plant(stance=0.16)
grip.build()

# Sugar Tower: crouched on the heels, sugar cubes set one on another into a tower in front, the last one
# slowly; then a look at it. One shot.
sugar = Motion("sugarTower", 5.6, note="Crouched, sugar cubes stacked into a tower one by one, the last one slowly.")
SUGAR = (1.0, 1.8, 2.6, 3.4, 4.4)
sugar.key(0.0, offset=(0, -1.35, 0), root=(-14, 0, 0), neck=(-20, 0, 0), rShoulder=J((40, 0, 30), (0, 0, -0.2)),
          lShoulder=J((62, 0, 6), (0.0, 0.06, -0.36)))
for i, t in enumerate(SUGAR):
    reach = 26 + 11 * i
    sugar.key(t - 0.45, offset=(0, -1.35, 0), root=(-14, 0, 0), neck=(-20, 0, 0), rShoulder=J((40, 0, 34), (0, 0, -0.2)),
              lShoulder=J((62, 0, 6), (0.0, 0.06, -0.36)))
    sugar.key(t, "sine" if i == 4 else "smooth", offset=(0, -1.35, 0), root=(-16, 0, 0), neck=(-22 + 3 * i, 0, 0),
              rShoulder=J((reach, 0, -6), (-0.12, 0.02, -0.3)), lShoulder=J((62, 0, 6), (0.0, 0.06, -0.36)))
sugar.key(4.9, offset=(0, -1.35, 0), root=(-8, 0, 0), neck=(-6, 0, 0), rShoulder=J((60, 0, -6), (0, 0.06, -0.36)),
          lShoulder=J((62, 0, 6), (0.0, 0.06, -0.36)))
sugar.key(5.6, offset=(0, -1.35, 0), root=(-8, 0, 0), neck=(-6, 4, 0), rShoulder=J((60, 0, -6), (0, 0.06, -0.36)),
          lShoulder=J((62, 0, 6), (0.0, 0.06, -0.36)))
soft(sugar, head=1.6, arms=2.4).plant(stance=0.14, tilt=(34, 34))
sugar.build()


def scribble(m, t0, t1, rate=0.1, frantic=1.0):
    """Writing fast in the notebook held at the chest by the left hand, the pen racing along the lines."""
    n = int(round((t1 - t0) / rate))
    for i in range(n + 1):
        t = t0 + i * rate
        along = (i % 5) / 4
        stroke = 1 if i % 2 == 0 else -1
        m.key(t, root=(-7, 3, 0), neck=(-30 + 3 * stroke * frantic, 4 - 6 * along, 0),
              lShoulder=J((54, 0, 30), (0.28, 0.1, -0.22)),
              rShoulder=J((50 + 3 * stroke * frantic, -4 + 8 * along, -16 + 7 * along),
                          (-0.18 + 0.13 * along, 0.06 + 0.02 * stroke * frantic, -0.24)))


# Chip and Pen (chipAndPen): rebuilt 2026-10-17 as Diavolo's Potato Chip, in emotes/props.py.

# Furious Scribbling: writing in a frenzy, the head bobbing with every stroke; one time in three it ends with
# the whole line slashed out (furiousScribblingSlash, chosen by the server). One shot each.
for name, slash in (("furiousScribbling", False), ("furiousScribblingSlash", True)):
    fury = Motion(name, 4.4 if slash else 3.6, note="Writing in a frenzy" + (", then the line slashed out." if slash else "."))
    fury.key(0.0, **REST)
    scribble(fury, 0.25, 3.0, rate=0.08, frantic=2.2)
    if slash:
        fury.key(3.25, "out", root=(-2, -6, 0), neck=(-18, -6, 0), lShoulder=J((54, 0, 30), (0.28, 0.1, -0.22)),
                 rShoulder=J((112, 0, 36), (0, 0.16, -0.16)))
        fury.key(3.45, "snap", root=(-9, 8, 0), neck=(-30, 6, 0), lShoulder=J((54, 0, 30), (0.28, 0.1, -0.22)),
                 rShoulder=J((46, 0, -40), (-0.22, 0.04, -0.24)))
        fury.key(3.9, root=(-8, 8, 0), neck=(-26, 4, 0), lShoulder=J((54, 0, 30), (0.28, 0.1, -0.22)),
                 rShoulder=J((44, 0, -40), (-0.22, 0.04, -0.24)))
        fury.key(4.4, **REST)
    else:
        fury.key(3.6, **REST)
    fury.follow("neck", 5.0, 0.6).follow("rShoulder", 7.0, 0.55).follow("lShoulder", 2.0, 0.8).plant(stance=0.04)
    fury.build()

# Apple Toss: an apple tossed up and caught, twice, the eyes following it, then held out to someone who is
# not there. One shot.
toss = Motion("appleToss", 3.6, note="An apple tossed up and caught twice, then held out to someone unseen.")
toss.key(0.0, **REST)
for up, back in ((0.5, 1.25), (1.55, 2.3)):
    toss.key(up - 0.15, root=(-2, 0, 0), neck=(-6, 0, 0), rShoulder=J((42, 0, -8), (-0.05, 0.04, -0.12)), lShoulder=J((4, 0, -4)))
    toss.key(up, "snap", root=(1, 0, 0), neck=(10, 0, 0), rShoulder=J((82, 0, -8), (-0.05, 0.08, -0.14)), lShoulder=J((4, 0, -4)))
    toss.key((up + back) / 2, root=(2, 0, 0), neck=(24, 0, 0), rShoulder=J((70, 0, -8), (-0.05, 0.06, -0.14)), lShoulder=J((4, 0, -4)))
    toss.key(back, "in", root=(-1, 0, 0), neck=(2, 0, 0), rShoulder=J((66, 0, -8), (-0.05, 0.06, -0.14)), lShoulder=J((4, 0, -4)))
toss.key(2.85, "out", root=(0, 10, 0), neck=(2, 16, 0), rShoulder=J((88, 0, 8), (0, 0.06, -0.12)), lShoulder=J((4, 0, -4)))
toss.key(3.2, root=(0, 10, 0), neck=(2, 16, 0), rShoulder=J((88, 0, 8), (0, 0.06, -0.12)), lShoulder=J((4, 0, -4)))
toss.key(3.6, **REST)
soft(toss, head=3.0, arms=3.6).plant(stance=0.06)
toss.build()

# Strawberry on Top: a plate of cake held up in one hand, the strawberry on top plucked off with care,
# admired at eye level, eaten, savoured. One shot.
straw = Motion("strawberryOnTop", 4.0, note="A plate of cake held up, the strawberry plucked off, admired, eaten.")
plate = J((70, 0, 22), (0.2, 0.08, -0.22))
straw.key(0.0, **REST)
straw.key(0.4, root=(-2, 0, 0), neck=(-14, 0, 0), lShoulder=plate, rShoulder=J((12, 0, 6)))
straw.key(0.8, root=(-4, 0, 0), neck=(-18, 0, 0), lShoulder=plate, rShoulder=J((72, 0, -30), (-0.25, 0.12, -0.25)))
straw.key(1.0, "snap", root=(-3, 0, 0), neck=(-16, 0, 0), lShoulder=plate, rShoulder=J((80, 0, -28), (-0.24, 0.14, -0.24)))
straw.key(1.55, root=(0, 0, 0), neck=(4, 0, 0), lShoulder=plate, rShoulder=J((118, 0, -12), (-0.1, 0.16, -0.16)))
straw.key(2.35, root=(0, 0, 0), neck=(6, 0, 4), lShoulder=plate, rShoulder=J((119, 0, -10), (-0.1, 0.16, -0.16)))
straw.key(2.75, "snap", root=(-3, 0, 0), neck=(-4, 0, 0), lShoulder=plate, rShoulder=r_face(126, -30))
straw.key(3.1, root=(-2, 0, 0), neck=(2, 0, 0), lShoulder=plate, rShoulder=J((30, 0, -6)))
straw.key(3.5, root=(0, 0, 0), neck=(6, 0, 6), lShoulder=plate, rShoulder=J((14, 0, 4)))
straw.key(4.0, **REST)
soft(straw, head=2.4, arms=3.0).plant(stance=0.06)
straw.build()

# Dice Tower: sitting on the floor, legs out, a tower of dice built between them one at a time; then
# leaning back on a hand to look at it. One shot.
dice = Motion("diceTower", 6.0, note="Sitting on the floor, a tower of dice built between the legs, then admired.")
DICE = (0.9, 1.6, 2.3, 3.0, 3.7, 4.6)
sit_legs = dict(rHip=J((90, 0, 14)), lHip=J((90, 0, -18)))
dice.key(0.0, offset=(0, 0, 0.3), floor=True, root=(-12, 0, 0), neck=(-14, 0, 0), rShoulder=J((30, 0, 20)),
         lShoulder=J((-16, 0, -26), (0, -0.1, 0.1)), **sit_legs)
for i, t in enumerate(DICE):
    reach = 38 + 12 * i
    dice.key(t - 0.4, offset=(0, 0, 0.3), floor=True, root=(-12, 0, 0), neck=(-14 + 2 * i, 0, 0), rShoulder=J((34, 0, 30)),
             lShoulder=J((-16, 0, -26), (0, -0.1, 0.1)), **sit_legs)
    dice.key(t, offset=(0, 0, 0.3), floor=True, root=(-14, 0, 0), neck=(-16 + 3 * i, 0, 0),
             rShoulder=J((reach, 0, -4), (-0.1, 0.04, -0.28)), lShoulder=J((-16, 0, -26), (0, -0.1, 0.1)), **sit_legs)
dice.key(5.2, "sine", offset=(0, 0, 0.3), floor=True, root=(-2, 6, 0), neck=(0, 8, 6), rShoulder=J((20, 0, 10)),
         lShoulder=J((-24, 0, -30), (0, -0.14, 0.14)), **sit_legs)
dice.key(6.0, offset=(0, 0, 0.3), floor=True, root=(-2, 6, 0), neck=(0, 10, 8), rShoulder=J((20, 0, 10)),
         lShoulder=J((-24, 0, -30), (0, -0.14, 0.14)), **sit_legs)
soft(dice, head=1.6, arms=2.6)
dice.build()

# Chocolate Snap: a bar of chocolate bitten with a hard jerk of the head, chewed with attitude, bitten
# again. One shot.
choc = Motion("chocolateSnap", 3.2, note="A chocolate bar bitten with a hard jerk of the head, chewed, bitten again.")
choc.key(0.0, **REST)
for bite, away in ((0.7, 0.9), (1.9, 2.1)):
    choc.key(bite - 0.3, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=r_face(124, -30), lShoulder=J((10, 0, -10)))
    choc.key(bite, "snap", root=(-3, -8, 0), neck=(-6, -24, 10), rShoulder=r_face(126, -30), lShoulder=J((10, 0, -10)))
    choc.key(away, "snap", root=(-2, -6, 0), neck=(-4, -16, 6), rShoulder=J((96, 0, -6), (-0.05, 0.08, -0.12)),
             lShoulder=J((10, 0, -10)))
    for k, nod in enumerate((4, -2, 4, -2)):
        choc.key(away + 0.15 + 0.15 * k, root=(-2, -4, 0), neck=(-4 + nod, -10, 4), rShoulder=J((92, 0, -6), (-0.05, 0.08, -0.12)),
                 lShoulder=J((10, 0, -10)))
choc.key(3.2, **REST)
soft(choc, head=3.0, arms=4.0).plant(stance=0.08)
choc.build()

# Forty Seconds: the left wrist brought up and the watch on it read, the head counting the seconds off
# with small nods, then snapping up to stare (the face) as the time runs out. One shot.
watch_ = Motion("fortySeconds", 4.6, note="The watch on the wrist read, the seconds counted off, then a snap up to stare.")
wrist = J((62, 0, 42), (0.25, 0.16, -0.25))
watch_.key(0.0, **REST)
watch_.key(0.5, root=(-3, -6, 0), neck=(-24, -8, 0), lShoulder=wrist, rShoulder=J((4, 0, 4)))
for k in range(7):
    t = 0.85 + 0.38 * k
    watch_.key(t, root=(-3, -6, 0), neck=(-26 if k % 2 == 0 else -21, -8, 0), lShoulder=wrist, rShoulder=J((4, 0, 4)))
watch_.key(3.45, "snap", root=(3, 0, 0), neck=(8, 0, 0), lShoulder=J((40, 0, 30), (0.2, 0.1, -0.2)), rShoulder=J((6, 0, 6)))
watch_.key(4.6, root=(3, 0, 0), neck=(8, 0, 0), lShoulder=J((38, 0, 28), (0.2, 0.1, -0.2)), rShoulder=J((6, 0, 6)))
soft(watch_, head=3.0, arms=2.4).plant(stance=0.06)
watch_.build()


# Strolls -------------------------------------------------------------------------------------------------
# A stroll is two clips: `<name>`, played standing still (a loop), and `<name>Walk`, a walk cycle the game
# plays instead of its own walk and run while the stroll lasts (LocomotionController; picked again, another
# emote, or 30 s end it). The cycles are built like the game's own (gait.py): soles planted while down, so
# feet never slide, and a stride long enough for the game's full speed (16 studs a second).

from gait import Gait, build_cycle, wave  # noqa: E402


def stroll(gait, pose, samples=40):
    """The walk cycle of a stroll: pose(phase) -> (upper body joints, root, offset); the legs follow the soles."""

    def full(phase):
        joints, root, offset = pose(phase)
        joints = dict(joints, root=root)
        joints.update(gait.legs(phase, root, offset))
        return joints, offset

    return build_cycle(gait, samples, full)


# The Long Climb: climbing an endless stair with a blank stare (the face), the knees coming up high and
# slow, one arm hanging dead still, the body rising with each step.
CLIMB = Gait("theLongClimbWalk", period=0.62, stride=9.6, stance=0.55, lift=0.95,
             note="Climbing an endless stair: high slow knees, one arm hanging dead still, a blank stare.")


def climb_pose(phase):
    bob = math.cos(4 * math.pi * (phase - 0.15))
    root = (-6 + 1.0 * bob, 3 * wave(phase, 0.05), 1.2 * wave(phase, 0.1))
    offset = (0.03 * wave(phase, 0.1), -0.06 + 0.12 * bob, 0.0)
    swing = wave(phase, 0.1)
    joints = dict(neck=(-6, -0.6 * root[1], 0), rShoulder=J((2, 0, 4)),
                  lShoulder=J((6 + 10 * swing, 0, -4), (0, 0, -0.04 * swing)))
    return joints, root, offset


stroll(CLIMB, climb_pose)
climb = Motion("theLongClimb", 1.6, loop=True, note="Climbing a stair on the spot: high slow knees, a dead arm, a blank stare.")
for i in range(4):
    t = i * 0.4
    up = i % 2 == 0
    climb.key(t, offset=(0, 0.06 if up else -0.04, 0), root=(-6, 0, 0), neck=(-6, 0, 0), rShoulder=J((2, 0, 4)),
              lShoulder=J((6 + (8 if up else -8), 0, -4)))
raise_leg(climb, "rHip", 0.0, 0.2, 0.3, 0.5, J((44, 0, 4), (0, 0.62, -0.12)))
raise_leg(climb, "lHip", 0.8, 1.0, 1.1, 1.3, J((44, 0, -4), (0, 0.62, -0.12)))
soft(climb, head=1.6, arms=1.6).plant(stance=0.06)
climb.build()

# Parade March: stiff and upright, arms swinging high and straight in time; standing, marking time, then
# the high kick straight up and held, then to attention.
MARCH = Gait("paradeMarchWalk", period=0.6, stride=9.6, stance=0.5, lift=0.62,
             note="A stiff parade march: upright, arms swinging high and straight in time.")


def march_pose(phase):
    bob = math.cos(4 * math.pi * (phase - 0.1))
    root = (1, 0, 0)
    offset = (0, -0.04 + 0.05 * bob, 0.0)
    swing = wave(phase, 0.0)
    joints = dict(neck=(2, 0, 0), rShoulder=J((-44 * swing, 0, 4)), lShoulder=J((44 * swing, 0, -4)))
    return joints, root, offset


stroll(MARCH, march_pose)
parade = Motion("paradeMarch", 3.2, loop=True, note="Marking time stiffly, then a high kick straight up, held, then attention.")
for i in range(4):
    t = i * 0.4
    s = 1 if i % 2 == 0 else -1
    parade.key(t, "snap", offset=(0, 0.02, 0), root=(1, 0, 0), neck=(2, 0, 0), rShoulder=J((-40 * s, 0, 4)), lShoulder=J((40 * s, 0, -4)))
    raise_leg(parade, "rHip" if s > 0 else "lHip", t, t + 0.12, t + 0.22, t + 0.36,
              J((48, 0, 4 * s), (0, 0.4, -0.08)))
parade.key(1.6, offset=(0, 0, 0), root=(1, 0, 0), neck=(2, 0, 0), rShoulder=J((0, 0, 4)), lShoulder=J((0, 0, -4)))
parade.key(1.8, "snap", offset=(0, 0.04, 0.12), root=(10, 0, 0), neck=(-4, 0, 0), rShoulder=J((-10, 0, 30)), lShoulder=J((-10, 0, -30)))
parade.key(2.3, offset=(0, 0.04, 0.12), root=(10, 0, 0), neck=(-4, 0, 0), rShoulder=J((-10, 0, 30)), lShoulder=J((-10, 0, -30)))
parade.key(2.6, "snap", offset=(0, 0, 0), root=(1, 0, 0), neck=(2, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))
parade.key(3.2, offset=(0, 0, 0), root=(1, 0, 0), neck=(2, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))
raise_leg(parade, "rHip", 1.62, 1.8, 2.3, 2.58, J((150, 0, 4), (0, 0.12, -0.1)))
parade.follow(ARMS, 6.0, 0.6).plant(stance=0.04)
parade.build()

# Griddy (griddy, griddyWalk): rebuilt 2026-10-17 from the dance itself, in emotes/strolls.py.

# Mushroom Stroll: an easy, unbothered walk with a stick over the shoulder (a mushroom tied to it), the
# other arm swinging a little; standing, swaying, looking about.
MUSHROOM = Gait("mushroomStrollWalk", period=0.6, stride=9.6, stance=0.6, lift=0.32,
                note="An easy, unbothered walk with a stick over the shoulder.")
STICK_ARM = J((72, 0, -14), (-0.15, 0.1, -0.1))


def mushroom_pose(phase):
    bob = math.cos(4 * math.pi * (phase - 0.15))
    root = (-2 + 0.6 * bob, 3 * wave(phase, 0.05), 1.0 * wave(phase, 0.1))
    offset = (0.04 * wave(phase, 0.12), -0.06 - 0.04 * bob, 0.0)
    swing = wave(phase, 0.1)
    joints = dict(neck=(3, -0.6 * root[1], 0), rShoulder=STICK_ARM, lShoulder=J((4 + 14 * swing, 0, -4)))
    return joints, root, offset


stroll(MUSHROOM, mushroom_pose)
mushroom = Motion("mushroomStroll", 3.0, loop=True, note="Standing easy with a stick over the shoulder, swaying, looking about.")
for t, look in ((0.0, 0), (1.0, 14), (2.0, -4)):  # (a glance to the stick side would put the head into it)
    mushroom.key(t, offset=(0.04 * math.sin(t * 2), -0.02, 0), root=(-1, 0, 2 * math.sin(t * 2)), neck=(2, look, 0),
                 rShoulder=STICK_ARM, lShoulder=J((4, 0, -6)))
soft(mushroom, head=1.4, arms=1.4).plant(stance=0.08)
mushroom.build()

# Not My Problem: a shrug, then the lazy slouch of somebody walking away from it all, hands in the
# pockets; standing, the shrug now and then.
SLOUCH = Gait("notMyProblemWalk", period=0.7, stride=9.0, stance=0.62, lift=0.24,
              note="A lazy slouch, hands in the pockets, walking away from it all.")
POCKET_R, POCKET_L = J((8, 0, -4), (-0.08, 0.12, -0.02)), J((8, 0, 4), (0.08, 0.12, -0.02))


def slouch_pose(phase):
    bob = math.cos(4 * math.pi * (phase - 0.2))
    root = (-12 + 0.8 * bob, 3 * wave(phase, 0.05), 2.0 * wave(phase, 0.1))
    offset = (0.05 * wave(phase, 0.12), -0.1 - 0.04 * bob, 0.0)
    joints = dict(neck=(-6, -0.5 * root[1], 7), rShoulder=POCKET_R, lShoulder=POCKET_L)
    return joints, root, offset


stroll(SLOUCH, slouch_pose)
shrugger = Motion("notMyProblem", 3.0, loop=True, note="A shrug, palms out, then slouched with hands in the pockets.")
shrugger.key(0.0, offset=(0, -0.06, 0), root=(-10, 0, 0), neck=(-6, 0, 7), rShoulder=POCKET_R, lShoulder=POCKET_L)
shrugger.key(0.4, "out", offset=(0, -0.02, 0), root=(-4, 0, 3), neck=(0, 0, 9), rShoulder=J((34, -20, 30), (0.05, 0.2, -0.08)),
             lShoulder=J((34, 20, -30), (-0.05, 0.2, -0.08)))
shrugger.key(1.1, offset=(0, -0.02, 0), root=(-4, 0, 3), neck=(0, 0, 8), rShoulder=J((32, -20, 28), (0.05, 0.18, -0.08)),
             lShoulder=J((32, 20, -28), (-0.05, 0.18, -0.08)))
shrugger.key(1.6, offset=(0, -0.06, 0), root=(-10, 0, 0), neck=(-6, 0, 7), rShoulder=POCKET_R, lShoulder=POCKET_L)
soft(shrugger).plant(stance=0.08)
shrugger.build()


# The owner's replacements (2026-10-14) -------------------------------------------------------------------

# The Smiling Lord (in the place of Floss; the Lord Verity dance): a showman with a cane. A touch of the hat
# brim with the hip cocked and a knee turned in, a pop of the hip the other way, a lean on the cane with
# both hands and a sway, the cane flicked out with a kick behind, a turn on the spot with an arm out, the
# arms flung wide leaning back, and the hat again. 8 beats of 0.6 s; the cane is in the left hand
# (Anim/EmoteProps).
lord = Motion("smilingLord", 4.8, loop=True, note="A showman with a cane: hat tip, hip pops, a lean on the cane, a kick, a turn, arms wide.")
HAT = J((150, 0, -30), (-0.2, 0.24, -0.1))
CANE_DOWN = J((14, 0, -14))
lord.key(0.0, offset=(0.1, -0.04, 0), root=(0, 0, -4), neck=(-6, 6, 0), rShoulder=HAT, lShoulder=CANE_DOWN)
lord.key(0.6, "snap", offset=(-0.1, -0.04, 0), root=(0, 0, 4), neck=(-6, -6, 0), rShoulder=HAT, lShoulder=CANE_DOWN)
for i, s in enumerate((1, -1, 1, -1)):
    t = 1.2 + 0.3 * i
    lord.key(t, offset=(0.12 * s, -0.14, -0.05), root=(-10, 6 * s, -3 * s), neck=(4, -4 * s, 0),
             rShoulder=J((42, 0, -26), (-0.22, 0.02, -0.2)), lShoulder=J((40, 0, 12), (0.16, 0.0, -0.2)))
lord.key(2.4, "snap", offset=(0, 0, 0), root=(4, -12, 0), neck=(6, 18, 0), rShoulder=J((60, 0, 20)), lShoulder=J((34, 0, -66)))
lord.key(2.95, offset=(0, 0, 0), root=(2, 0, 0), neck=(0, 0, 0), rShoulder=J((90, 0, 56)), lShoulder=J((10, 0, -16)))
for i in range(1, 5):  # the turn, linear, all the way round
    lord.key(2.95 + 0.15 * i, "linear", offset=(0, 0, 0), root=(2, 90 * i, 0), neck=(0, -10 if i < 4 else 0, 0),
             rShoulder=J((90, 0, 56)), lShoulder=J((10, 0, -16)))
lord.key(3.95, "out", offset=(0, -0.06, 0.12), root=(12, 360, 0), neck=(18, 0, 0), rShoulder=J((110, 0, 82)),
         lShoulder=J((110, 0, -82)))
lord.key(4.35, offset=(0, -0.06, 0.12), root=(12, 360, 0), neck=(18, 0, 0), rShoulder=J((108, 0, 80)), lShoulder=J((108, 0, -80)))
lord.key(4.8, offset=(0.1, -0.04, 0), root=(0, 360, -4), neck=(-6, 6, 0), rShoulder=HAT, lShoulder=CANE_DOWN)
lift(lord, "lHip", ((0.0, 1, J((12, 0, 12), (0.08, 0.14, -0.04))), (0.5, 1, J((12, 0, 12), (0.08, 0.14, -0.04))), (0.7, 0, J((0, 0, 0)))))
lift(lord, "rHip", ((0.55, 0, J((0, 0, 0))), (0.75, 1, J((12, 0, -12), (-0.08, 0.14, -0.04))), (1.1, 1, J((12, 0, -12), (-0.08, 0.14, -0.04))),
                    (1.25, 0, J((0, 0, 0)))))
raise_leg(lord, "rHip", 2.2, 2.4, 2.6, 2.85, J((-40, 0, 4), (0, 0.12, 0.06)))
lord.plant(0.0, 2.9, stance=0.1)
lord.plant(3.9, 4.8, stance=0.1)
lord.follow("neck", 4.0, 0.7).follow(ARMS, 4.5, 0.62)
lord.build()

# Animatronic Welcome (in the place of Sus Lean; the animatronic family dance): stiff, jerky, held between
# moves like a stage robot, a wide grin (the face). A hand cupped to the ear, a spread hand waving by the
# face, two hands beckoning, a hand to the chest and a point out at you, two hands snapping together like
# jaws, the head jerking from side to side, the arms opened wide in welcome. 8 beats of 0.6 s.
bot = Motion("animatronicWelcome", 4.8, loop=True, note="A stage robot's welcome: ear, wave, beckon, point, a biting snap, jerks, arms wide.")
REST_R, REST_L = J((4, 0, 6)), J((4, 0, -6))


def jerk(t, neck, r, l, root=(0, 0, 0), offset=(0, -0.02, 0)):
    """A pose snapped to and held: the move into it is quick, the stop is dead."""
    bot.key(t, "snap", offset=offset, root=root, neck=neck, rShoulder=r, lShoulder=l)
    bot.key(t + 0.12, "hold", offset=offset, root=root, neck=neck, rShoulder=r, lShoulder=l)


jerk(0.0, (0, 0, 12), J((140, 0, -6), (-0.05, 0.3, 0.02)), REST_L)
for i, z in enumerate((22, 44, 22, 44)):
    jerk(0.6 + 0.15 * i, (0, -10, -6), J((140, 0, z), (0, 0.24, 0)), REST_L)
for i in range(2):
    t = 1.2 + 0.3 * i
    jerk(t, (4, 0, 0), J((72, 0, -6), (0, 0.06, -0.2)), J((72, 0, 6), (0, 0.06, -0.2)), root=(-4, 0, 0))
    jerk(t + 0.15, (2, 0, 0), J((60, 0, -6), (0, 0.06, 0.05)), J((60, 0, 6), (0, 0.06, 0.05)), root=(2, 0, 0))
jerk(1.8, (-4, 0, 0), r_chest(66, -40), REST_L)
jerk(2.1, (-6, 0, 0), J((92, 0, 2), (0, 0.1, -0.14)), REST_L, root=(-4, 0, 0))
for i in range(2):
    t = 2.4 + 0.3 * i
    jerk(t, (8, 0, 0), J((116, 0, -16), (-0.1, 0.18, -0.2)), J((76, 0, 16), (0.1, 0.06, -0.2)), root=(2, 0, 0))
    jerk(t + 0.15, (-6, 0, 0), J((96, 0, -16), (-0.1, 0.1, -0.24)), J((92, 0, 16), (0.1, 0.1, -0.24)), root=(-6, 0, 0),
         offset=(0, -0.02, -0.06))
for i, y in enumerate((30, -30, 30, 0)):
    jerk(3.0 + 0.15 * i, (0, y, 6 if y else 0), J((40, 0, 30), (0, 0.04, -0.1)), J((40, 0, -30), (0, 0.04, -0.1)))
jerk(3.6, (10, 0, 0), J((62, 0, 62)), J((62, 0, -62)), root=(6, 0, 0), offset=(0, -0.02, 0.06))
jerk(4.2, (6, 0, -8), J((60, 0, 58)), J((60, 0, -58)), root=(4, 0, -3), offset=(0, -0.02, 0.06))
bot.key(4.8, "snap", offset=(0, -0.02, 0), root=(0, 0, 0), neck=(0, 0, 12), rShoulder=J((140, 0, -6), (-0.05, 0.3, 0.02)), lShoulder=REST_L)
bot.plant(stance=0.12)
bot.build()

# Excuse Me, Sir (in the place of Jumpstyle; the "excuse me sir" meme): blissful, eyes shut and smiling
# (the face), the face tipped up to the sky, the whole body wobbling and bouncing on the beat like the
# meme's jelly-wobble edit of a still. 4 beats of 0.4 s.
sky = Motion("excuseMeSir", 1.6, loop=True, note="Blissful, face up to the sky, smiling, the whole body wobbling on the beat.")
for i in range(8):
    t = i * 0.2
    beat = i % 2 == 0
    s_ = 1 if (i // 2) % 2 == 0 else -1
    sky.key(t, "out" if beat else "smooth", offset=(0.03 * s_, -0.1 if beat else -0.02, 0.04),
            root=(10 + (2 if beat else 0), 3 * s_, 4 * s_), neck=(30 + (5 if beat else 0), -4 * s_, -7 * s_),
            rShoulder=J((-8, 0, 8), (0, 0.06 if beat else 0.0, 0)), lShoulder=J((-8, 0, -8), (0, 0.06 if beat else 0.0, 0)))
sky.follow("neck", 5.0, 0.45).follow(ARMS, 4.0, 0.5).plant(stance=0.1)
sky.build()


# Duos ----------------------------------------------------------------------------------------------------
# Played by two (DuoService asks the nearest player; DuoController plays it on both, on every screen).

# Match Point (matchPointServe, matchPointReturn): rebuilt 2026-10-17 from the anime's match, in emotes/duos.py.

# Cuffed Together: two chained at the wrist (the leader's left, the follower's right). Only the chained arm is
# keyed, so the body walks as it always does underneath; the arm hangs a little out towards the other.
for name, joint, value in (("cuffedLead", "lShoulder", -1), ("cuffedFollow", "rShoulder", 1)):
    cuff = Motion(name, 2.0, loop=True, note="Chained at the wrist: the arm hanging a little out towards the other one.")
    for t, b in ((0.0, 0.0), (1.0, 1.0)):
        cuff.key(t, **{joint: J((12 + 3 * b, 0, value * (20 + 2 * b)), (0, -0.02 * b, 0))})
    cuff.follow(joint, 2.0, 0.7)
    cuff.build()
