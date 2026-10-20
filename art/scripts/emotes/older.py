"""The nine older shop emotes (before the emote pack): Groove, Spin, Potato chip, Thinker, Coin Flip, Apple Bite,
Puppet Dance, Write in the Air and Ace's Crouch, each copied from its reference (art/refs/emotes/<clip>.toml).
Their lengths are their references' own (only the free emotes' are frozen)."""

import math

from animlib import J
import posekit
from emotes import classic
from emotes.kit import reach
from motion import Motion

# Groove (clip dance2): Roblox's classic /e dance2 for R6 (rbxassetid 182436842), recorded from Roblox's own
# animation (emotes/classic.py): a shuffle from side to side with the arms swung out, at its own 2.17 s loop.
groove = Motion("dance2", 2.1667, loop=True, note="Roblox's classic dance2: a side-to-side shuffle, arms out.",
                unwrap=True, floor=True)
_, own = classic.frames("dance2")
classic.key_span(groove, "dance2", 0.0, own, 0.0)
groove.build()

# Spin (clip dance3): a dancer's turn on one leg, after "Spin on One Leg - Easy Beginner Guide"
# (art/refs/emotes/dance3.toml): a plie to prepare, the arms open; the push, the right foot drawn up to the left knee
# (passe), the arms rounded in front; two turns of about 0.53 s each on the left foot, the head spotting (it holds
# to the front while the body turns, then whips round ahead of it); landing open, back into the plie of the loop.
# The turn is about the left foot, not the hips' middle: the body is moved round so that foot stays put.
spin = Motion("dance3", 1.6, loop=True, note="A dancer's turn on one leg: plie, passe, two turns spotting, land open.")
OPEN_R, OPEN_L = J((12, 0, 72), (0, 0.05, 0)), J((12, 0, -72), (0, 0.05, 0))
ROUND_R = reach(1, (0.55, 0.35, -1.25), direction=(-0.4, 0.1, -1.0))
ROUND_L = reach(-1, (-0.55, 0.35, -1.25), direction=(0.4, 0.1, -1.0))
PASSE = J((58, 0, 28), (0.2, 0.42, -0.12))  # the right foot at the left knee: the leg up, forward and out


def _planted(yaw, drop, root=(0.0, 0.0, 0.0), right=(0.8, 0.0)):
    """Both legs with their soles flat for a body turned `yaw` and lowered `drop` over the left foot: the left sole
    on the floor under the root (the body is moved over it), the right one `right` = (studs out to the side, studs
    off the floor), 0.8 out and down by default."""
    offset = _over_left_foot(yaw, drop)
    angles = (root[0], root[1] + yaw, root[2])
    a = math.radians(yaw)
    right_foot = (right[0] * math.cos(a), right[1], -right[0] * math.sin(a))
    legs = {}
    for joint, side, foot in (("rHip", 1, right_foot), ("lHip", -1, (0.0, 0.0, 0.0))):
        turned, slide = posekit.planted_slide(side, foot, angles, offset)
        legs[joint] = J(turned, tuple(float(v) for v in slide))
    return offset, legs


def _over_left_foot(yaw, drop=0.0):
    """The body's offset that keeps the left hip (x = -0.5 from the torso's middle) over the root while the body is
    turned by `yaw` degrees (Roblox's Ry: x' = x cos + z sin, z' = -x sin + z cos)."""
    a = math.radians(yaw)
    return (0.5 * math.cos(a), -drop, -0.5 * math.sin(a))


# In the plie and the landing both soles are down (the legs solved to the floor); on the turns the body is up on
# the ball of the left foot (0.045 studs).
off, legs = _planted(0, 0.05)
spin.key(0.0, "smooth", offset=off, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=OPEN_R, lShoulder=OPEN_L, **legs)
off, legs = _planted(0, 0.28, (-4, -12, 0))
spin.key(0.25, "in", offset=off, root=(-4, -12, 0), neck=(-2, 10, 0), rShoulder=J((14, 0, 80), (0, 0.06, 0)),
         lShoulder=J((14, 0, -80), (0, 0.06, 0)), **legs)
# the right foot leaving the floor on the push, on its way up to the knee
off, legs = _planted(0, 0.17, (-1, -6, 0), right=(0.45, 0.22))
spin.key(0.32, "smooth", offset=off, root=(-1, -6, 0), **legs)
TURN0, TURN = 0.38, 0.54
spin.key(TURN0, "linear", offset=_over_left_foot(0, 0.06), root=(2, 0, 0), neck=(0, 0, 0), rShoulder=ROUND_R,
         lShoulder=ROUND_L, rHip=PASSE, lHip=J((0, 0, 0), (0, 0.06, 0)))
for n in range(2):
    t0 = TURN0 + n * TURN
    for k in range(1, 13):
        yaw = 360 * n + 30 * k
        spin.key(round(t0 + TURN * k / 12, 4), "linear", offset=_over_left_foot(yaw, -0.045), root=(2, yaw, 0),
                 rShoulder=ROUND_R, lShoulder=ROUND_L, rHip=PASSE, lHip=(0, 0, 0))
    # spotting: the head holds to the front (-70 against the turning body), whips round ahead (+55), settles
    for frac, yaw in ((0.0, 0), (0.22, -70), (0.44, 55), (0.78, 18)):
        spin.key(round(t0 + TURN * frac + (0.002 if frac == 0.0 and n else 0.0), 4), "smooth", neck=(4, yaw, 0))
spin.key(TURN0 + 2 * TURN, "smooth", neck=(0, 0, 0))
# land open, the right foot back down into the plie the loop starts from
off, legs = _planted(708, 0.06, (0, 0, 0), right=(0.45, 0.22))
spin.key(1.47, "smooth", offset=off, root=(0, 708, 0), **legs)
off, legs = _planted(712, 0.18, (-2, 0, 0))
spin.key(1.5, "out", offset=off, root=(-2, 712, 0), neck=(-2, 6, 0), rShoulder=J((14, 0, 78), (0, 0.06, 0)),
         lShoulder=J((14, 0, -78), (0, 0.06, 0)), **legs)
for t, yaw, drop, pitch in ((1.535, 715, 0.13, -1.4), (1.57, 718, 0.08, -0.6)):
    off, legs = _planted(yaw, drop, (pitch, 0, 0))
    spin.key(t, "smooth", offset=off, root=(pitch, yaw, 0), **legs)
off, legs = _planted(720, 0.05)
spin.key(1.6, "smooth", offset=off, root=(0, 720, 0), neck=(0, 0, 0), rShoulder=OPEN_R, lShoulder=OPEN_L, **legs)
spin.follow(("rShoulder", "lShoulder"), 3.0, 0.75)
spin.build()

# Potato chip (clip chip, branch chipEat): Light's "I'll take a potato chip... and eat it!" (Death Note, episode 8;
# art/refs/emotes/chip.toml), standing: the bag of crisps held at the left hip, the right hand goes into it, the
# chip drawn up in a slow arc to face height and held there, the head turned to it (the line's pause). That held
# chip is the press-to-do moment (EAT): pressed, the branch plays the bite, the chip thrust into the mouth with a
# snap of the head, the crunch, a smirking chew. Not pressed, the chip is lowered, still held, a calculating look.
BAG_LOW = reach(-1, (-1.3, -0.55, -0.62), direction=(0.05, -1.0, -0.35))  # the bag held at the left hip
INTO_BAG = reach(1, (-1.05, 0.12, -1.35), direction=(-0.6, -0.5, -0.6))  # the right hand at the bag's mouth
CHIP_UP, CHIP_UP_DIR = (0.95, 1.6, -1.0), (0.15, 0.75, -0.55)
RAISED = reach(1, CHIP_UP, direction=CHIP_UP_DIR)
TO_MOUTH = reach(1, (0.05, 1.0, -0.6), direction=(-0.55, 0.55, -0.6))  # the fist under the chin: the chip above it
LOWERED = reach(1, (0.75, 0.55, -1.05), direction=(0.2, 0.3, -0.9))
REST4 = {"root": (0, 0, 0), "neck": (0, 0, 0), "rShoulder": (0, 0, 0)}

chip = Motion("chip", 3.4, note="Light's potato chip: taken from the bag, held up, a pause (EAT bites it).")
chip.key(0.0, "smooth", lShoulder=BAG_LOW, **REST4)
chip.key(0.35, "smooth", root=(0, 6, 0), neck=(-6, 12, 0), rShoulder=J((20, 0, -10), (0, 0.05, -0.05)),
         lShoulder=BAG_LOW)
chip.key(0.72, "out", root=(-3, 12, 0), neck=(-14, 14, 0), rShoulder=INTO_BAG, lShoulder=BAG_LOW)
chip.key(0.9, "smooth", root=(-3, 11, 0), neck=(-12, 12, 0), rShoulder=INTO_BAG, lShoulder=BAG_LOW)
# the slow arc up, the head following the chip round to the right
chip.key(1.3, "out", root=(2, -6, 0), neck=(4, -16, -4), rShoulder=RAISED, lShoulder=BAG_LOW)
chip.key(2.4, "smooth", root=(2, -7, 0), neck=(6, -18, -5), rShoulder=RAISED, lShoulder=BAG_LOW)
# not eaten: lowered to the chest, held, the head turning back with a level look
chip.key(2.9, "smooth", root=(0, -2, 0), neck=(-4, -6, 0), rShoulder=LOWERED, lShoulder=BAG_LOW)
chip.key(3.4, "smooth", root=(0, 0, 0), neck=(-2, 0, 0), rShoulder=LOWERED, lShoulder=BAG_LOW)
chip.follow(("rShoulder",), 3.5, 0.8)
chip.plant(stance=0.05)
chip.build()

eat = Motion("chipEat", 2.2, note="...and eat it: the chip thrust into the mouth, the crunch, a smirking chew.")
eat.key(0.0, "smooth", root=(2, -7, 0), neck=(6, -18, -5), rShoulder=RAISED, lShoulder=BAG_LOW)
eat.key(0.1, "in", root=(3, -9, 0), neck=(8, -20, -6), rShoulder=reach(1, (1.0, 1.75, -0.85), direction=CHIP_UP_DIR),
        lShoulder=BAG_LOW)  # a hair further up: the wind-up
eat.key(0.24, "snap", offset=(0, -0.06, 0), root=(-6, 4, 0), neck=(-14, 4, 2), rShoulder=TO_MOUTH, lShoulder=BAG_LOW)
eat.key(0.4, "smooth", offset=(0, -0.04, 0), root=(-5, 3, 0), neck=(-10, 2, 1), rShoulder=TO_MOUTH, lShoulder=BAG_LOW)
for i, t in enumerate((0.62, 0.86, 1.1, 1.34)):  # the chew: the jaw's work shows as small nods
    eat.key(t, "smooth", offset=(0, -0.02, 0), root=(-2, -2, 0), neck=(-6 + (3 if i % 2 else -2), -6, 0),
            rShoulder=reach(1, (0.7, 0.45, -0.95), direction=(0.2, 0.3, -0.9)), lShoulder=BAG_LOW)
eat.key(2.2, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 0), lShoulder=BAG_LOW)
eat.follow(("rShoulder",), 3.5, 0.8)
eat.plant(stance=0.05)
eat.build()

# The R6 crouch (the owner's drawing, 2026-10-20): the legs out in front along the floor (pitched about 80 degrees
# forward at the hips, never slid off them), the torso sitting low on their back ends, upright. The body's height
# is worked out so the lowest corner rests on the floor (posekit.on_floor); breathing and rocking go on top of it.
CROUCH_R, CROUCH_L = J((80, 0, 5)), J((80, 0, -5))


def _crouch_key(m, t, ease, root, rise=0.0, z=0.0, **joints):
    """A crouched key: the legs forward, the body resting on the floor, then raised by `rise` (a breath)."""
    legs = {"root": J(root), "rHip": joints.pop("rHip", CROUCH_R), "lHip": joints.pop("lHip", CROUCH_L)}
    ox, oy, oz = posekit.on_floor(legs, (0.0, 0.0, z), floor=0.0)
    m.key(t, ease, offset=(ox, oy + rise, oz), root=root, rHip=legs["rHip"], lHip=legs["lHip"], **joints)


# Thinker (clip think): L's crouch (Death Note; art/refs/emotes/think.toml, the cafe scene where he explains why
# he sits like that): sitting low on his legs, hunched forward, the left arm resting over the knees, the right thumb
# at the lower lip. What makes it L is what never stops: the breathing, the thumb pressing at the lip as he thinks,
# the slow tilt of the head to one side and back. A 4 s loop: two breaths, two presses of the thumb, one tilt.
think = Motion("think", 4.0, loop=True, note="L's crouch: legs out, hunched, the thumb at the lip, the head tilting.")
THUMB = reach(1, (0.12, 0.85, -0.85), direction=(-0.45, 0.75, -0.5))
THUMB_IN = reach(1, (0.1, 0.88, -0.8), direction=(-0.45, 0.75, -0.5))  # the thumb pressed in at the lip
OVER_KNEES = reach(-1, (-0.35, -0.55, -1.5), direction=(0.3, -0.35, -0.9))
for t, breath, thumb, neck in (
    (0.0, 0.0, THUMB, (-2, 0, 0)),
    (0.55, 0.5, THUMB_IN, (-2, 1, -1)),
    (0.8, 0.7, THUMB, (-2, 2, -2)),
    (1.0, 1.0, THUMB, (-1, 4, -4)),
    (1.5, 0.6, THUMB, (-1, 7, -9)),  # the head tilts: something does not add up
    (2.0, 0.0, THUMB, (-1, 7, -9)),
    (2.55, 0.5, THUMB_IN, (-1, 7, -9)),
    (2.8, 0.7, THUMB, (-1, 6, -8)),
    (3.0, 1.0, THUMB, (-1, 5, -6)),
    (3.5, 0.5, THUMB, (-2, 2, -2)),
):
    _crouch_key(think, t, "smooth", (-14 + 2 * breath, 0, 0), rise=0.02 * breath, z=0.0, neck=neck,
                rShoulder=thumb, lShoulder=OVER_KNEES)
think.follow("neck", 1.5, 0.72)
think.follow(("rShoulder", "lShoulder"), 2.2, 0.7)
think.build()

# Ace's Crouch (clip aceCrouch): L sitting low on his legs with his hands hung over his knees (art/refs/emotes/
# aceCrouch.toml): rocking slowly back and forward, the head tilting one way on the way back and the other on the
# way forward, watching. A 4 s loop: two rocks.
crouch = Motion("aceCrouch", 4.0, loop=True, note="L crouched, hands over his knees, rocking, watching.")
for t, back, tilt in ((0.0, 0.0, -1), (1.0, 1.0, 0), (2.0, 0.0, 1), (3.0, 1.0, 0)):
    _crouch_key(crouch, t, "sine", (-10 + 7 * back, 0, 0), neck=(4 - 4 * back, 7 * tilt, 4 * tilt),
                rShoulder=reach(1, (0.75, -0.45 + 0.1 * back, -1.45 + 0.1 * back), direction=(0.05, -0.4, -0.9)),
                lShoulder=reach(-1, (-0.75, -0.45 + 0.1 * back, -1.45 + 0.1 * back), direction=(-0.05, -0.4, -0.9)))
crouch.follow("neck", 1.4, 0.72)
crouch.follow(("rShoulder", "lShoulder"), 1.8, 0.62)
crouch.build()

# Coin Flip (clip coinFlip): the gambler's call, heads or tails (art/refs/emotes/coinFlip.toml): the coin loaded
# on the thumb at the chest, a dip, the flick (the coin spins up, EmoteMeta `tosses`), the head and the body
# following it up and down, caught in the right fist, slapped onto the back of the left hand (the coin moves there),
# both lean in to read it, then the coin is picked back up and readied: FLIP (press-to-do) throws it again.
coin = Motion("coinFlip", 3.0, note="Heads or tails: flicked up, watched, caught, slapped on the back of the hand.")
LOAD = reach(1, (0.55, -0.05, -1.0), direction=(-0.3, 0.45, -0.85))  # the coin on the thumb, at the chest
FLICK = reach(1, (0.7, 0.55, -1.05), direction=(-0.1, 0.85, -0.55))
CATCH = reach(1, (0.5, 0.35, -1.2), direction=(-0.2, 0.55, -0.8))
# the right hand flat on the back of the left (on top of the left forearm, the coin between them)
SLAP = reach(1, (-0.12, 1.02, -1.25), direction=(-0.75, -0.05, -0.65))
SHOW = reach(1, (0.55, 0.35, -1.0), direction=(0.1, 0.6, -0.8))
FLAT = reach(-1, (-0.15, 0.0, -1.2), direction=(0.65, 0.1, -0.75))  # the left forearm across, palm down
HANG_L = J((4, 0, -4))
coin.key(0.0, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=LOAD, lShoulder=HANG_L)
coin.key(0.35, "in", offset=(0.06, -0.12, 0), root=(-3, 4, 0), neck=(-6, 2, 0), rShoulder=reach(1, (0.55, -0.2, -0.98),
         direction=(-0.3, 0.4, -0.85)), lShoulder=HANG_L)  # the dip: knees give, the hand sinks to load
coin.key(0.55, "snap", offset=(0.08, 0.04, 0), root=(3, 2, 0), neck=(12, 0, 0), rShoulder=FLICK, lShoulder=HANG_L)
coin.key(0.95, "out", offset=(0.04, 0.0, 0), root=(5, 0, 0), neck=(26, -4, 0), rShoulder=CATCH,
         lShoulder=reach(-1, (-0.6, -0.3, -0.9), direction=(0.3, 0.2, -0.9)))  # watching it at the top
coin.key(1.35, "in", offset=(0.0, -0.06, 0), root=(-2, 0, 0), neck=(-4, 0, 0), rShoulder=CATCH, lShoulder=FLAT)
coin.key(1.55, "snap", offset=(-0.04, -0.14, 0), root=(-8, -4, 0), neck=(-18, -2, 0), rShoulder=SLAP, lShoulder=FLAT)
coin.key(1.75, "smooth", offset=(-0.04, -0.12, 0), root=(-9, -4, 0), neck=(-22, -2, 0), rShoulder=SLAP, lShoulder=FLAT)
# the reveal: the hand lifts off, both lean in to read it
coin.key(2.05, "out", offset=(-0.02, -0.08, 0), root=(-11, -2, 0), neck=(-26, 4, 3), rShoulder=SHOW, lShoulder=FLAT)
coin.key(2.3, "smooth", offset=(0, -0.06, 0), root=(-8, 0, 0), neck=(-20, 6, 4), rShoulder=SHOW, lShoulder=FLAT)
# picked back up off the hand and readied on the thumb
coin.key(2.5, "smooth", offset=(0, -0.04, 0), root=(-5, 0, 0), neck=(-12, 2, 0), rShoulder=SLAP, lShoulder=FLAT)
coin.key(3.0, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=LOAD, lShoulder=HANG_L)
coin.follow("neck", 2.4, 0.72)
coin.follow(("rShoulder", "lShoulder"), 3.4, 0.75)
coin.plant(stance=0.08)
coin.build()

# Apple Bite (clip appleBite): Ryuk and his apple (Death Note, episode 1; art/refs/emotes/appleBite.toml): the
# apple brought up and looked at greedily, the head drawn back, then the big crunch, the head lunging into it,
# chewing with the whole upper body, a shiver of delight ("in the human world, apples are juicy").
apple = Motion("appleBite", 2.8, note="Ryuk's apple: looked at, one big crunch, a greedy chew and a shiver.")
APPLE_HIP = reach(1, (1.35, -0.75, -0.55), direction=(0.1, -1.0, -0.4))
APPLE_LOOK = reach(1, (0.62, 0.05, -1.45), direction=(-0.25, 0.45, -0.85))  # held out at the chest, eyed
APPLE_MOUTH = reach(1, (0.3, 0.72, -0.9), direction=(-0.45, 0.6, -0.65))  # the apple at the open mouth
APPLE_CHEW = reach(1, (0.62, 0.15, -1.3), direction=(-0.2, 0.45, -0.85))  # drawn away again to chew
apple.key(0.0, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=APPLE_HIP, lShoulder=(4, 0, -4))
apple.key(0.45, "out", offset=(0.05, -0.08, 0), root=(-8, 4, 0), neck=(-14, 6, 4), rShoulder=APPLE_LOOK,
          lShoulder=J((10, 0, -10)))  # hunched over it, eyeing it
apple.key(0.78, "in", offset=(0.05, -0.04, 0), root=(-4, 2, 0), neck=(8, 2, 0), rShoulder=APPLE_MOUTH,
          lShoulder=J((14, 0, -16)))  # the head drawn back: the mouth opens
apple.key(0.9, "snap", offset=(0.03, -0.14, 0), root=(-12, 0, 0), neck=(-5, 0, 0), rShoulder=APPLE_MOUTH,
          lShoulder=J((22, 0, -22)))  # CRUNCH
for i, t in enumerate((1.12, 1.34, 1.56, 1.78)):  # the chew, the shoulders working with the jaw
    up = i % 2 == 0
    apple.key(t, "smooth", offset=(0.02, -0.08 if up else -0.12, 0), root=(-9 if up else -11, 2 if up else -2, 0),
              neck=(-6 if up else -12, 4 if up else -4, 0), rShoulder=APPLE_CHEW, lShoulder=J((16, 0, -16)))
apple.key(2.05, "out", offset=(0, 0.02, 0), root=(4, 0, 3), neck=(14, 0, 6), rShoulder=APPLE_CHEW,
          lShoulder=J((8, 0, -26)))  # the shiver of delight, leaning back
apple.key(2.2, "smooth", offset=(0, 0, 0), root=(2, 0, -3), neck=(8, 0, -5), rShoulder=APPLE_CHEW,
          lShoulder=J((8, 0, -20)))
apple.key(2.8, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=APPLE_HIP, lShoulder=(4, 0, -4))
apple.follow("neck", 2.6, 0.7)
apple.follow(("rShoulder", "lShoulder"), 3.2, 0.72)
apple.plant(stance=0.08)
apple.build()

# Puppet Dance (clip puppetDance): danced like a marionette (art/refs/emotes/puppetDance.toml): nothing moves by
# itself; each beat a string yanks one limb up (a snap) and lets it drop under its own weight (falling, then a
# small bounce), the head lolling to the other side, the body hanging and bobbing on its strings. 120 bpm, a 2 s
# loop of four pulls: the right arm, the left knee, the left arm, the right knee.
puppet = Motion("puppetDance", 2.0, loop=True, note="A marionette: each beat a string yanks a limb up and drops it.")
ARM_DOWN_R, ARM_DOWN_L = J((6, 0, 8), (0, 0.04, 0)), J((6, 0, -8), (0, 0.04, 0))
# (a marionette's hand string lifts the wrist forward and out to about shoulder height, not overhead)
ARM_UP_R, ARM_UP_L = J((88, 0, 42), (0, 0.12, 0)), J((88, 0, -42), (0, 0.12, 0))
KNEE_UP_R, KNEE_UP_L = J((58, 0, 6), (0, 0.3, -0.1)), J((58, 0, -6), (0, 0.3, -0.1))
LEG_DOWN_R, LEG_DOWN_L = J((0, 0, 3)), J((0, 0, -3))
pulls = (("rShoulder", ARM_UP_R, -1), ("lHip", KNEE_UP_L, 1), ("lShoulder", ARM_UP_L, 1), ("rHip", KNEE_UP_R, -1))
rest = {"rShoulder": ARM_DOWN_R, "lShoulder": ARM_DOWN_L, "rHip": LEG_DOWN_R, "lHip": LEG_DOWN_L}
# dropped: the arms swing out a little, the legs splay and the body sinks on them
sag = {"rShoulder": J((2, 0, 14), (0, 0.04, 0)), "lShoulder": J((2, 0, -14), (0, 0.04, 0)), "rHip": J((0, 0, 9)),
       "lHip": J((0, 0, -9))}
# (the loop starts in the last pull's hang, the one still moment: a yank's sharp start is never at the seam)
SHIFT = 0.23


def _pt(t):
    return round((t + SHIFT) % 2.0, 3)


for n, (joint, up, loll) in enumerate(pulls):
    t0 = 0.5 * n
    lifted = dict(rest, **{joint: up})
    # the yank: the limb pulled up, the body tipped by the string, the head thrown the other way
    puppet.key(_pt(t0 + 0.18), "out", floor=True, root=J((0, 0, 3 * loll)), neck=J((-4, 0, 14 * loll)), **lifted)
    puppet.key(_pt(t0 + 0.27), "smooth", floor=True, root=J((0, 0, 3 * loll)), neck=J((-4, 0, 12 * loll)),
               **lifted)  # hangs there a moment
    # dropped: it falls under its own weight (in), the head lolls back, the body sags on its strings
    puppet.key(_pt(t0 + 0.44), "in", floor=True, root=J((-2, 0, -2 * loll)), neck=J((-10, 0, -10 * loll)), **sag)
    # the little bounce at the bottom of the drop, where the next string pulls
    puppet.key(_pt(t0 + 0.5), "out", floor=True, root=J((0, 0, -loll)), neck=J((-6, 0, -6 * loll)), **rest)
puppet.build()

# Write in the Air (clip writeAir): Kira writing a name, with nothing but a finger (art/refs/emotes/writeAir.toml):
# the finger raised, a name written left to right in the air at face height (small sharp loops, the body leaning
# with the hand, the weight moving from one foot to the other), a swooping underline, then the full stop jabbed in
# and a satisfied tilt of the head. The finger's ink shows as an effect (EmoteFx.writeAir).
air = Motion("writeAir", 3.0, note="Kira writes a name in the air: letters, a swooping underline, a jabbed full stop.")
AIR_REST = J((4, 0, 4))


def _finger(x, y, z=-1.65, forward=(0.0, 0.2, -1.0)):
    """The right arm with its fingertip at (x, y, z) (torso frame), pointing `forward`: out in front at the chest,
    never across the face."""
    return reach(1, (x, y, z), direction=forward)


air.key(0.0, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=AIR_REST, lShoulder=(4, 0, -4))
air.key(0.35, "out", offset=(-0.06, 0, 0), root=(0, -10, -2), neck=(-6, 12, 0), rShoulder=_finger(-0.1, 0.8),
        lShoulder=(6, 0, -6))  # the finger raised where the name starts, the eyes on it
# the letters: the fingertip travels right, a small loop up and down for each, the body leaning after it
for i in range(6):
    t = 0.45 + i * 0.22
    x = -0.1 + i * 0.24
    y = 0.8 + (0.12 if i % 2 == 0 else -0.08)
    air.key(round(t, 3), "smooth", offset=(-0.06 + 0.024 * i, 0, 0), root=(0, -10 + 4 * i, -2 + 0.8 * i),
            neck=(-6 + (2 if i % 2 else 0), 12 - 4 * i, 0), rShoulder=_finger(x, y), lShoulder=(6, 0, -6))
# the underline: a swoop back to the left, low
air.key(1.95, "out", offset=(-0.04, -0.06, 0), root=(-3, -8, -1), neck=(-10, 10, 0), rShoulder=_finger(-0.15, 0.48),
        lShoulder=(6, 0, -6))
# the full stop: drawn back, then jabbed in
air.key(2.2, "in", offset=(0.02, 0, 0.04), root=(2, 6, 1), neck=(-2, -6, 0), rShoulder=_finger(1.2, 0.7, -1.2),
        lShoulder=(6, 0, -6))
air.key(2.3, "snap", offset=(0.04, -0.04, -0.06), root=(-5, 6, 1), neck=(-6, -6, 0), rShoulder=_finger(1.2, 0.7, -1.9),
        lShoulder=(6, 0, -6))
air.key(2.55, "smooth", offset=(0.02, 0, 0), root=(-1, 3, 4), neck=(4, -4, 8), rShoulder=_finger(1.15, 0.66, -1.75),
        lShoulder=(6, 0, -6))  # the satisfied tilt
air.key(3.0, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=AIR_REST, lShoulder=(4, 0, -4))
air.follow("neck", 2.4, 0.72)
air.follow(("lShoulder",), 2.2, 0.62)
air.plant(stance=0.1)
air.build()

# Where the props sit (solve_holds.py writes them into EmoteMeta): the bag upright in the left fist at the hip,
# its mouth up; the chip pinched in the right fingers, raised flat towards the face.
HOLDS = {
    # the coin pinched on the thumb at the start; on the back of the left hand after the slap
    # the apple in the right fingers, upright, its middle just past the fist, as it is looked at
    "appleBite/Apple": ("Right Arm", {"rShoulder": APPLE_LOOK}, (0.52, 0.23, -1.79), (0, 0, 0)),
    # the bitten one in the same place, the bite (Blender -Y, towards the body) turned out to the right and forward
    "appleBite/AppleBitten": ("Right Arm", {"rShoulder": APPLE_LOOK}, (0.52, 0.23, -1.79), (0, 120, 0)),
    "coinFlip/Coin": ("Right Arm", {"rShoulder": LOAD}, (0.55, -0.02, -1.25), (90, 0, 0)),
    "coinFlip/CoinBack": ("Left Arm", {"lShoulder": FLAT}, (-0.18, 0.54, -1.22), (0, 0, 0)),
    "coinFlip/CoinUp": ("Right Arm", {"rShoulder": LOAD}, (0.55, -0.02, -1.25), (90, 0, 0)),
    "chip/ChipBag": ("Left Arm", {"lShoulder": BAG_LOW}, (-1.2, -0.5, -1.32), (0, 12, 0)),
    "chip/Chip": ("Right Arm", {"rShoulder": RAISED}, (CHIP_UP[0] + 0.02, CHIP_UP[1] + 0.32, CHIP_UP[2] - 0.08),
                  (90, 0, 0)),
    "chipEat/ChipBag": ("Left Arm", {"lShoulder": BAG_LOW}, (-1.2, -0.5, -1.32), (0, 12, 0)),
    "chipEat/Chip": ("Right Arm", {"rShoulder": RAISED}, (CHIP_UP[0] + 0.02, CHIP_UP[1] + 0.32, CHIP_UP[2] - 0.08),
                     (90, 0, 0)),
}
