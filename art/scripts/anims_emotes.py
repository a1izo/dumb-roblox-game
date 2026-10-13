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

# Floss: straight arms swung from side to side, one in front of the body and one behind, changing over
# as they pass, the hips swinging the other way. Two swings of 0.25 s.
floss = Motion("floss", 0.5, loop=True, note="Straight arms swung side to side, one in front and one behind, hips the other way.")
for t, s in ((0.0, 1), (0.25, -1)):
    floss.key(t, "sine", offset=(-0.12 * s, -0.06, 0), root=(-2, 4 * s, 6 * s), neck=(0, -4 * s, -3 * s),
              rShoulder=J((-24 * s, 0, 38 * s)), lShoulder=J((24 * s, 0, 38 * s)))
floss.plant(stance=0.1)
floss.build()

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

# Puppet Pop (an original routine on the marionette idea): each limb jerked up on a string and
# dropped, the knees giving way, the "talking hand", a chest pop, the head snapped round, a fist
# pumped. 8 beats of 0.4 s, snapped rather than flowing.
pop = Motion("puppetPop", 3.2, loop=True, note="Limbs jerked up by strings and dropped, a talking hand, pops and a fist pump.")
limp_r, limp_l = J((6, 0, 10)), J((6, 0, -10))
pop.key(0.0, offset=(0, -0.02, 0), root=(0, 0, 0), neck=(-4, 0, 0), rShoulder=limp_r, lShoulder=limp_l)
pop.key(0.4, "snap", offset=(0, 0.02, 0), root=(0, 0, 3), neck=(4, 0, -10), rShoulder=J((24, 0, 96), (0, 0.12, 0)), lShoulder=limp_l)
pop.key(0.8, "snap", offset=(0, 0.02, 0), root=(0, 0, -3), neck=(4, 0, 10),
        rShoulder=J((24, 0, 96), (0, 0.12, 0)), lShoulder=J((24, 0, -96), (0, 0.12, 0)))
pop.key(1.2, "in", offset=(0, -0.18, 0), root=(-8, 0, 0), neck=(-22, 0, 0), rShoulder=limp_r, lShoulder=limp_l)
for i, out in enumerate((0, 1, 0, 1)):  # the talking hand: across the chest, flicked open and shut
    pop.key(1.6 + i * 0.1, "snap", offset=(0, -0.04, 0), root=(-2, 6, 0), neck=(0, 8, 0),
            rShoulder=J((70, 0, -36 + 26 * out), (-0.22 + 0.12 * out, 0.1, -0.2)), lShoulder=J((8, 0, -6)))
pop.key(2.0, "snap", offset=(0, 0, 0.04), root=(-7, 0, 0), neck=(-2, 30, 0), rShoulder=J((12, 0, 8)), lShoulder=J((12, 0, -8)))
pop.key(2.4, "snap", offset=(0, 0.02, 0), root=(3, -4, 0), neck=(8, 10, 0),
        rShoulder=J((154, 0, 10), (0, 0.22, 0)), lShoulder=J((20, 0, -22)))
pop.key(2.6, offset=(0, 0, 0), root=(2, -4, 0), neck=(6, 6, 0), rShoulder=J((148, 0, 10), (0, 0.2, 0)), lShoulder=J((18, 0, -20)))
pop.key(2.8, "snap", offset=(0, -0.12, 0), root=(-6, 0, 0), neck=(-14, -28, 0), rShoulder=limp_r, lShoulder=limp_l)
pop.follow("neck", 5.0, 0.6).follow(ARMS, 6.0, 0.55).plant(stance=0.14)
pop.build()

# Jumpstyle: hops on the beat, a leg kicked out in front then flicked back behind, then the other.
# 4 beats of 0.41 s (about 146 to the minute).
jump = Motion("jumpstyle", 1.64, loop=True, note="Hopping on the beat, kicking a leg forward then back, then the other.")
BEAT = 0.41
for i in range(4):
    t = i * BEAT
    s = 1 if i < 2 else -1  # which leg kicks
    front = i % 2 == 0
    kick = J((54, 0, 4 * s), (0, 0.12, -0.08)) if front else J((-36, 0, 4 * s), (0, 0.14, 0.04))
    stand = J((-6, 0, -3 * s), (0, 0.02, 0))
    jump.key(t, "out", offset=(0, 0.3, 0), root=(-3 if front else 6, 0, 0), neck=(4 if front else -4, 0, 0),
             rHip=kick if s > 0 else stand, lHip=stand if s > 0 else kick,
             rShoulder=J((-20 if (s > 0) == front else 30, 0, 16)), lShoulder=J((30 if (s > 0) == front else -20, 0, -16)))
    jump.key(t + BEAT / 2, "in", offset=(0, 0.0, 0), root=(-2, 0, 0), neck=(0, 0, 0),
             rHip=J((4, 0, 3)), lHip=J((4, 0, -3)), rShoulder=J((6, 0, 12)), lShoulder=J((6, 0, -12)))
soft(jump, arms=3.2)
jump.build()

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

# Sus Lean: leaning in sideways with the head cocked, a hand at the chin and the other arm propping its
# elbow, peering. A loop (also a stance).
sus = Motion("susLean", 4.0, loop=True, note="Leaning in sideways, head cocked, a hand at the chin, peering at someone.")
for t, b in ((0.0, 0.0), (2.0, 1.0)):
    sus.key(t, offset=(0.15, -0.06, -0.05), root=(-10, -10, 10), neck=(-4, 12 + 4 * b, -10),
            rShoulder=J((108, 0, -30), (-0.26, 0.12, -0.2)), lShoulder=J((44, 0, 36), (0.26, 0.02, -0.18)))
soft(sus, head=1.5, arms=1.5).plant(stance=0.08)
sus.build()

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

# Just As Planned: a slow tilt of the head down and to the side, the eyes up from under the brows, a hand
# at the cheek and the other arm folded under its elbow; the smile (the face) grows.
planned = Motion("justAsPlanned", 3.6, note="A slow tilt of the head, the eyes up from under the brows, a hand at the cheek.")
planned.key(0.0, **REST)
planned.key(1.0, "sine", root=(-4, 6, 0), neck=(-16, -8, 10), rShoulder=J((100, 0, -30), (-0.24, 0.14, -0.2)),
            lShoulder=J((54, 0, 34), (0.26, 0.06, -0.2)))
planned.key(2.8, root=(-5, 6, 0), neck=(-17, -8, 15), rShoulder=J((102, 0, -30), (-0.24, 0.15, -0.2)),
            lShoulder=J((54, 0, 34), (0.26, 0.06, -0.2)))
planned.key(3.6, **REST)
soft(planned, head=1.4, arms=2.0).plant(stance=0.06)
planned.build()

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
