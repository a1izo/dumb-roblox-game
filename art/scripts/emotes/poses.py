"""Poses and acted moments, each copied from its reference (art/refs/emotes/<clip>.toml)."""

import math

import posekit
from animlib import J
from emotes.kit import reach
from motion import Motion

REST = dict(root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))

# Just As Planned (clip justAsPlanned, item emote_just_as_planned; Diavolo's mastery) ----------------------
# Death Note's "keikaku doori" moment (the anime, once Light has his memories back): he turns his head slowly,
# the eyes slide to the side and catch red; then the head drops, the eyes glare up from under the hair and the
# grin spreads. Godhood, so it plays as a scene (owner's note, 2026-10-17: more dramatic, longer, with effects):
#   0.0-1.4  still, the head bowed a little, as the ink spreads out across the floor round him;
#   1.4-2.3  the slow turn over the right shoulder into the stare; the eye catches red (the glint, 2.05);
#   2.5-3.5  the right hand comes up in front, palm up, and slowly closes on it: the plan in his fist;
#   3.6-4.7  the chin drops, the shoulders come up, the grin, a silent chuckle in the shoulders;
#   4.8-6.4  it breaks into Light's laugh: thrown back, arms flung open, shaking (the ink bursts out, 4.9);
#   6.6-7.4  composure: the hands come down, the right one straightens the tie;
#   7.6-8.5  a last look aside over the left shoulder, the glint again (7.75); 9.2 back at rest as the ink sinks.
# Standing (the anime has him seated); the meaning lives in the head and the face (the owner's face pictures),
# the scene in the effects (Controllers/EmoteFx) and the private cutscene (S14).
plan = Motion("justAsPlanned", 9.2, note="Just as planned: the stare and the red glint, the plan closed in a fist, the grin, Light's laugh, the tie, the last look.", unwrap=True)
hang_r, hang_l = J((6, 0, 6), (0, 0.04, -0.04)), J((6, 0, -6), (0, 0.04, -0.04))
palm = J((78, 0, 4), (0, 0.04, -0.08))  # the right hand held out in front of the shoulder, palm up
fist = reach(1, (0.95, 0.85, -1.15), direction=(-0.1, 0.7, -0.7))  # closed on it, drawn up and in a little
fist_low = reach(1, (0.75, 0.3, -1.0), direction=(-0.2, 0.3, -0.9))
wide_r, wide_l = J((40, 0, 104), (0, 0.06, 0)), J((40, 0, -104), (0, 0.06, 0))  # flung open, up and out
wider_r, wider_l = J((44, 0, 112), (0, 0.08, 0)), J((44, 0, -112), (0, 0.08, 0))
tie = reach(1, (0.1, 0.75, -0.75), direction=(-0.35, 0.6, -0.75))  # the fist at the knot of the tie
tie_pull = reach(1, (0.1, 0.62, -0.78), direction=(-0.35, 0.55, -0.8))
plan.key(0.0, **REST)
plan.key(0.6, "sine", offset=(0, 0.02, 0), root=(-2, 0, 0), neck=(-8, 2, 0), rShoulder=hang_r, lShoulder=hang_l)
plan.key(1.3, "sine", offset=(0, 0.0, 0), root=(-3, 1, 0), neck=(-10, 4, 0), rShoulder=hang_r, lShoulder=hang_l)
# the turn: slow, the head leading the shoulders, into the stare
plan.key(2.05, "sine", root=(-2, -18, 0), neck=(-4, -40, -4), rShoulder=J((4, 0, 6), (0, 0.04, 0.02)),
         lShoulder=J((8, 0, -7), (0, 0.04, -0.06)))
plan.key(2.4, root=(-2, -19, 0), neck=(-5, -41, -4), rShoulder=J((4, 0, 6), (0, 0.04, 0.02)),
         lShoulder=J((8, 0, -7), (0, 0.04, -0.06)))
# the hand comes up in front, the eyes down to it
plan.key(3.0, "sine", root=(-3, -4, 0), neck=(-16, -8, 0), rShoulder=palm, lShoulder=hang_l)
plan.key(3.25, root=(-3, -3, 0), neck=(-17, -6, 0), rShoulder=palm, lShoulder=hang_l)
plan.key(3.55, "out", offset=(0, -0.03, 0), root=(-5, -2, 0), neck=(-18, -4, 2), rShoulder=fist, lShoulder=hang_l)
# the chin drops, the shoulders come up and forward: the eyes glare up from under the brows, the grin
plan.key(4.0, "sine", offset=(0, -0.06, 0), root=(-10, -2, 0), neck=(-26, 4, 5), rShoulder=fist_low,
         lShoulder=J((10, 0, -8), (0, 0.16, -0.06)))
for i in range(3):  # the silent chuckle in the shoulders, growing
    t = 4.15 + 0.16 * i
    plan.key(t, "out", offset=(0, -0.09 - 0.01 * i, 0), root=(-11 - i, -2, 0), neck=(-27, 4, 6),
             rShoulder=fist_low, lShoulder=J((11, 0, -8), (0, 0.2, -0.06)))
    plan.key(t + 0.08, "sine", offset=(0, -0.05, 0), root=(-9, -2, 0), neck=(-25, 4, 5),
             rShoulder=fist_low, lShoulder=J((10, 0, -8), (0, 0.15, -0.06)))
# the laugh: a breath down, then thrown back with the arms flung open
plan.key(4.7, "in", offset=(0, -0.12, 0), root=(-14, 0, 0), neck=(-20, 0, 0), rShoulder=fist_low,
         lShoulder=J((12, 0, -10), (0, 0.18, -0.06)))
plan.key(4.95, "snap", offset=(0, 0.03, 0.06), root=(14, 0, 0), neck=(30, 0, 0), rShoulder=wide_r, lShoulder=wide_l)
for i in range(6):  # shaking with it, the arms rising a little
    t = 5.15 + 0.2 * i
    k = i / 5
    up = i % 2 == 0
    plan.key(t, "sine", offset=(0, 0.0 if up else 0.03, 0.06), root=(11 + (4 if up else 0), 0, 1.5 if up else -1.5),
             neck=(26 + (8 if up else 0), 0, 0),
             rShoulder=J((40 + 4 * k, 0, 104 + 8 * k + (0 if up else 4)), (0, 0.06, 0)),
             lShoulder=J((40 + 4 * k, 0, -104 - 8 * k - (0 if up else 4)), (0, 0.06, 0)))
plan.key(6.45, "sine", offset=(0, 0.02, 0.04), root=(13, 0, 0), neck=(28, 0, 0), rShoulder=wider_r, lShoulder=wider_l)
# composure: forward again, the arms come down, the right hand to the tie
plan.key(6.95, "sine", offset=(0, 0, 0), root=(-2, 0, 0), neck=(-6, 0, 0), rShoulder=tie, lShoulder=hang_l)
plan.key(7.2, "out", root=(-2, 0, 0), neck=(-8, 0, 0), rShoulder=tie_pull, lShoulder=hang_l)
plan.key(7.35, root=(-1, 0, 0), neck=(-6, 0, 0), rShoulder=tie_pull, lShoulder=hang_l)
# the last look aside, over the left shoulder
plan.key(7.75, "sine", root=(-2, 15, 0), neck=(-8, 38, 3), rShoulder=hang_r, lShoulder=hang_l)
plan.key(8.5, root=(-2, 16, 0), neck=(-9, 40, 3), rShoulder=hang_r, lShoulder=hang_l)
plan.key(9.2, "sine", **REST)
plan.follow("neck", 1.8, 0.8).follow(("rShoulder", "lShoulder"), 2.8, 0.72).plant(stance=0.06)
plan.build()


# S11 (2026-10-20): the poses, each rebuilt from its reference (art/refs/emotes/<clip>.toml) with the life the old
# ones lacked: a breath, the weight moving from foot to foot, the head never quite still.
POCKET_R = J((10, 0, -4), (-0.08, 0.12, -0.02))  # a hand in the trouser pocket
POCKET_L = J((10, 0, 4), (0.08, 0.12, -0.02))
HANG_R, HANG_L = J((2, 0, 4)), J((2, 0, -4))
BRIM_R = reach(1, (0.75, 2.05, -0.6), direction=(-0.35, 0.85, -0.4))  # the fingers at a hat's brim
BRIM_L = reach(-1, (-0.75, 2.05, -0.6), direction=(0.35, 0.85, -0.4))


def _floor_key(m, t, ease, root, rise=0.0, x=0.0, z=0.0, **joints):
    """A key with the body resting on the floor on whatever touches it (sat, slumped), raised by `rise`."""
    pose = {"root": J(root), "rHip": joints.get("rHip", J((0, 0, 3))), "lHip": joints.get("lHip", J((0, 0, -3)))}
    ox, oy, oz = posekit.on_floor(pose, (x, 0.0, z), floor=0.0)
    m.key(round(t, 4), ease, offset=(ox, oy + rise, oz), root=root, **joints)


# Impossible Lean (clip impossibleLean, item emote_impossible_lean) -----------------------------------------
# Michael Jackson's anti-gravity lean (Smooth Criminal; refs: impossibleLean.toml, the 45-degree lean filmed from
# the side): a touch of the hat brim, the arms down straight at the sides, then the whole body tipping forward
# from the feet in half a second, rigid as a plank, held there two seconds with the barest sway, and back up
# with a little settle. A rigid R6 leg tipped about the sole's middle would put its toes 0.3 studs into the floor,
# so the body tips about the front edge of the soles (the heels lift, as MJ's pegged shoes let them).
lean = Motion("impossibleLean", 4.2, note="MJ's lean: the hat touched, then the whole body tipped 40 degrees from the "
              "ankles, held, and back.", floor=True)
lean.key(0.0, "smooth", offset=(0, 0, 0), **REST)
lean.key(0.35, "out", offset=(0, 0, 0), root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=BRIM_R, lShoulder=HANG_L)
lean.key(0.55, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(-8, 0, 0), rShoulder=BRIM_R, lShoulder=HANG_L)
lean.key(0.85, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(-4, 0, 0), rShoulder=J((-2, 0, 4)), lShoulder=J((-2, 0, -4)))
TIP = 40.0


def _tipped(deg):
    """The body's offset that keeps the soles' front edge (3 studs down, 0.5 forward of the root) where it is while
    the body is tipped `deg` degrees forward."""
    th = math.radians(deg)
    return (0, -3 + 3 * math.cos(th) + 0.5 * math.sin(th), -0.5 - 3 * math.sin(th) + 0.5 * math.cos(th))


STRAIGHT = {"rShoulder": J((-4, 0, 4)), "lShoulder": J((-4, 0, -4)), "rHip": J((0, 0, 0)), "lHip": J((0, 0, 0))}
for t0, t1, a0, a1 in ((0.9, 1.4, 0.0, 1.0), (3.35, 3.8, 1.0, 0.0)):
    for i in range(11):  # keyed finely so the feet stay where they stand
        t = t0 + (t1 - t0) * i / 10
        u = a0 + (a1 - a0) * (0.5 - 0.5 * math.cos(math.pi * i / 10))
        lean.key(round(t, 4), "linear", offset=_tipped(TIP * u), root=(-TIP * u, 0, 0),
                 neck=(-4 + 18 * u, 0, 0), **STRAIGHT)
for t, d in ((1.9, 1.5), (2.5, -1.0), (3.0, 1.0)):  # held: the barest sway, the head lifting to look ahead
    lean.key(t, "smooth", offset=_tipped(TIP + d), root=(-TIP - d, 0, 0),
             neck=(14 + d, 0, 0), **STRAIGHT)
lean.key(3.95, "out", offset=(0, 0, 0.02), root=(3, 0, 0), neck=(-6, 0, 0), **STRAIGHT)  # the settle, a hair back
lean.key(4.2, "smooth", offset=(0, 0, 0), **REST, rHip=J((0, 0, 0)), lHip=J((0, 0, 0)))
lean.follow(("rShoulder", "lShoulder"), 3.0, 0.75)
lean.build()

# Nah, I'd Win (clip nahIdWin, item emote_nah_id_win) -------------------------------------------------------
# Gojo's "Nah, I'd win." (Jujutsu Kaisen, the manga panel; refs: nahIdWin.toml): utterly sure of himself, the hands
# in his pockets, the weight sunk on one hip, leaning back a little, the chin up. Alive: a slow breath, the weight
# rolling over to the other hip and back, the head tilting to a lazy smirk. A 4 s loop (also a stance).
win = Motion("nahIdWin", 4.0, loop=True, note="Gojo's Nah, I'd win: hands in pockets, the weight on a hip, chin up, "
             "rolling lazily from hip to hip.")
for t, side, breath, tilt in ((0.0, 1, 0.0, 0), (1.0, 1, 1.0, 1), (2.0, -1, 0.0, 0), (3.0, -1, 1.0, -1)):
    win.key(t, "sine", offset=(0.07 * side, -0.03 - 0.015 * breath, 0), root=(5 + 1.5 * breath, 8 * side, 4 * side),
            neck=(9 - 2 * breath, -10 * side + 4 * tilt, -4 * side + 6 * tilt), rShoulder=POCKET_R, lShoulder=POCKET_L)
win.follow("neck", 1.4, 0.75)
win.plant(stance=0.12)
win.build()

# Jawline Check (clip jawlineCheck, item emote_jawline_check) -----------------------------------------------
# Mewing's jawline check (refs: jawlineCheck.toml): the chin lifted, the head turned to one side to show the jaw,
# a thumb run along it from under the ear to the chin, turned to the other side, a flick off the chin, the smug
# stare. The weight leans back onto the heels as the chin comes up.
jaw = Motion("jawlineCheck", 3.2, note="Mewing: chin up, the head turned to show the jaw, a thumb along it, the flick, "
             "the smug stare.")
JAW_EAR = reach(1, (0.8, 1.2, -0.45), direction=(-0.15, 0.95, -0.25))  # the arm up beside the face, not across it
JAW_CHIN = reach(1, (0.5, 1.1, -0.8), direction=(-0.3, 0.85, -0.4))
jaw.key(0.0, "smooth", **REST)
jaw.key(0.45, "out", offset=(0.02, 0, 0.03), root=(3, -6, 0), neck=(14, 28, 0), rShoulder=JAW_EAR, lShoulder=HANG_L)
jaw.key(1.05, "smooth", offset=(0.02, 0, 0.03), root=(3, -4, 0), neck=(16, 10, 0), rShoulder=JAW_CHIN, lShoulder=HANG_L)
jaw.key(1.55, "smooth", offset=(-0.02, 0, 0.03), root=(3, 4, 0), neck=(16, -26, 0), rShoulder=JAW_CHIN, lShoulder=HANG_L)
jaw.key(1.8, "snap", offset=(-0.02, 0, 0.02), root=(2, 2, 0), neck=(13, -8, 2),
        rShoulder=reach(1, (0.55, 1.05, -1.25), direction=(0.3, 0.5, -0.8)), lShoulder=HANG_L)  # the flick
jaw.key(2.5, "smooth", offset=(0, 0, 0.01), root=(1, 0, 0), neck=(10, -2, 4), rShoulder=J((10, 0, 6)), lShoulder=HANG_L)
jaw.key(3.2, "smooth", offset=(0, 0, 0), **REST)
jaw.follow(("rShoulder", "lShoulder"), 3.4, 0.75)
jaw.follow("neck", 2.4, 0.8)
jaw.plant(stance=0.06)
jaw.build()

# The Eyebrow (clip theEyebrow, item emote_the_eyebrow) -----------------------------------------------------
# The Rock's raised eyebrow, "the People's Eyebrow" (refs: theEyebrow.toml): the head turns a little and tilts, the
# chin dips, the body leans in towards you, a hand on the hip, the brow goes up (the face) and stays; a slow
# nod of "really?" while it is held.
brow = Motion("theEyebrow", 3.4, note="The Rock's eyebrow: a lean in, the head turned and tilted, chin down, a hand on "
              "the hip, held with a slow nod.")
HIP_L = J((14, 0, -34), (0.12, 0.1, 0.06))
brow.key(0.0, "smooth", **REST)
brow.key(0.8, "sine", offset=(0.03, -0.03, -0.04), root=(-6, 8, 0), neck=(-8, 14, 9), rShoulder=HANG_R, lShoulder=HIP_L)
brow.key(1.5, "sine", offset=(0.03, -0.03, -0.04), root=(-6, 8, 0), neck=(-12, 16, 10), rShoulder=HANG_R, lShoulder=HIP_L)
brow.key(2.1, "sine", offset=(0.03, -0.03, -0.04), root=(-6, 8, 0), neck=(-6, 16, 10), rShoulder=HANG_R, lShoulder=HIP_L)
brow.key(2.7, "smooth", offset=(0.03, -0.03, -0.04), root=(-5, 8, 0), neck=(-9, 16, 10), rShoulder=HANG_R, lShoulder=HIP_L)
brow.key(3.4, "smooth", offset=(0, 0, 0), **REST)
brow.follow("neck", 1.8, 0.8)
brow.follow(("rShoulder", "lShoulder"), 2.6, 0.75)
brow.plant(stance=0.08)
brow.build()

# It's You (clip itsYou, item emote_its_you; Ace's mastery) -------------------------------------------------
# Jotaro's point (JoJo Part 3; refs: itsYou.toml): a sharp turn three-quarters on with a step into it, the right
# arm thrown out straight at someone, the left hand at the cap's brim, the chin down, held with the weight forward.
you = Motion("itsYou", 2.6, note="Jotaro's point: a sharp turn and step, the arm thrown out straight, a hand at the brim, "
             "chin down.")
you.key(0.0, "smooth", **REST)
you.key(0.1, "in", offset=(0, -0.04, 0), root=(-2, 8, 0), neck=(-4, -6, 0), rShoulder=J((-14, 0, 8)),
        lShoulder=J((10, 0, -6)))  # the wind-up
you.key(0.24, "snap", offset=(0.05, -0.08, -0.12), root=(-4, -24, 0), neck=(-12, 20, 0),
        rShoulder=reach(1, (0.9, 1.1, -2.4), direction=(0.05, 0.05, -1.0)), lShoulder=BRIM_L)
you.key(0.5, "smooth", offset=(0.05, -0.07, -0.12), root=(-3, -24, 0), neck=(-11, 19, 0),
        rShoulder=reach(1, (0.9, 1.05, -2.4), direction=(0.05, 0.03, -1.0)), lShoulder=BRIM_L)
you.key(2.0, "smooth", offset=(0.05, -0.08, -0.12), root=(-4, -24, 0), neck=(-12, 20, 0),
        rShoulder=reach(1, (0.9, 1.1, -2.4), direction=(0.05, 0.05, -1.0)), lShoulder=BRIM_L)
you.key(2.6, "smooth", offset=(0, 0, 0), **REST)
you.follow(("rShoulder", "lShoulder"), 4.0, 0.6)
you.follow("neck", 2.6, 0.8)
you.plant(0.0, 0.18, stance=0.06)
you.plant(0.18, 2.4, stance=0.2, forward=(0.0, 0.35))  # the left foot stepped forward into the point
you.plant(2.4, 2.6, stance=0.06)
you.build()

# Menacing Pose (clip menacingPose; NEXT POSE: menacingPose2, menacingPose3, back to the first) ---------------
# JoJo's poses with the ゴゴゴ rising round them (refs: menacingPose.toml). Each is held as a loop, the body
# breathing and the head easing, the stance wide and twisted:
#   1  DIO's: a hand spread across the face, the other arm flung down and back, the head over the shoulder;
#   2  Giorno's: the right forearm raised across the chest, the palm open out, the left hand on the hip, the head
#      tilted, the weight on one leg;
#   3  Jotaro's Star Platinum stance: leaning back, the right arm pointing up and out, the left fist at the hip.
# NEXT POSE (any time) snaps into the next one, round and round.
JOJO = {
    "menacingPose": dict(off=(0.1, -0.12, 0), root=(-4, 30, -10), neck=(6, -40, 12), r=J((-30, 0, 40)),
                         l=J((132, 0, 42), (0.3, 0.2, -0.2)), stance=0.3, forward=(0.3, -0.2)),
    "menacingPose2": dict(off=(-0.06, -0.08, 0), root=(0, -18, 6), neck=(-6, 12, 14),
                          r=reach(1, (-0.2, 0.75, -1.1), direction=(-0.75, 0.55, -0.35)), l=HIP_L, stance=0.22,
                          forward=(-0.25, 0.2)),
    "menacingPose3": dict(off=(0.04, -0.1, 0.08), root=(10, 16, -4), neck=(16, -14, -6),
                          r=J((150, 0, 40), (0, 0.15, 0)), l=J((20, 0, -24), (0.1, 0.05, 0.05)), stance=0.32,
                          forward=(0.2, -0.3)),
}
for clip, p in JOJO.items():
    m = Motion(clip, 4.0, loop=True, note="A JoJo pose, held, menacing.")
    for t, b in ((0.0, 0.0), (1.0, 1.0), (2.0, 0.3), (3.0, 1.0)):  # the breath and the head easing
        ox, oy, oz = p["off"]
        root, neck = p["root"], p["neck"]
        m.key(t, "sine", offset=(ox, oy - 0.02 * b, oz), root=(root[0] + 1.5 * b, root[1], root[2]),
              neck=(neck[0] - 2 * b, neck[1] + 3 * b, neck[2]), rShoulder=p["r"], lShoulder=p["l"])
    m.follow("neck", 1.4, 0.8)
    m.follow(("rShoulder", "lShoulder"), 2.0, 0.8)
    m.plant(stance=p["stance"], forward=p["forward"])
    m.build()

# Low Battery (clip lowBattery; CHARGE plays lowBatteryCharge) ----------------------------------------------
# The low-battery collapse (refs: lowBattery.toml): powering down by stages, a stutter at each (the head drops,
# the shoulders sag, the knees go), then down to sit slumped on the floor, the legs out in front along it (the
# R6 way of sitting: the owner's drawing). CHARGE, once slumped, plugs in: a jolt, another, and it springs back up.
low = Motion("lowBattery", 4.6, note="Powering down by stages with a stutter at each, down to sit slumped on the floor.", floor=True)
SIT_R, SIT_L = J((84, 0, 6)), J((84, 0, -6))
low.key(0.0, "smooth", offset=(0, 0, 0), **REST)
low.key(0.55, "snap", offset=(0, -0.05, 0), root=(-4, 0, 0), neck=(-20, 0, 0), rShoulder=J((3, 0, 3)),
        lShoulder=J((3, 0, -3)))  # the head drops
low.key(0.7, "smooth", offset=(0, -0.03, 0), root=(-3, 0, 0), neck=(-16, 0, 0), rShoulder=J((3, 0, 3)),
        lShoulder=J((3, 0, -3)))  # the stutter back
low.key(1.35, "snap", offset=(0, -0.1, 0), root=(-12, 0, 3), neck=(-28, 0, 4), rShoulder=J((10, 0, 0), (0, -0.08, 0)),
        lShoulder=J((10, 0, 0), (0, -0.08, 0)))  # the shoulders sag
low.key(1.5, "smooth", offset=(0, -0.08, 0), root=(-10, 0, 2), neck=(-25, 0, 4), rShoulder=J((8, 0, 0)), lShoulder=J((8, 0, 0)))
low.key(2.15, "snap", offset=(0, -0.4, 0), root=(-16, 0, 4), neck=(-30, 0, 6), rShoulder=J((12, 0, 2)),
        lShoulder=J((12, 0, -2)))  # the knees go (the legs slide up into the body)
low.key(2.3, "smooth", offset=(0, -0.34, 0), root=(-15, 0, 4), neck=(-29, 0, 6), rShoulder=J((11, 0, 2)),
        lShoulder=J((11, 0, -2)), rHip=J((15, 0, 3), (0, 0.34, 0)), lHip=J((15, 0, -3), (0, 0.34, 0)))
low.plant(0.0, 2.29, stance=0.06)
_floor_key(low, 2.52, "in", (-12, 0, 5), neck=(-30, 0, 7), rShoulder=J((14, 0, 4)), lShoulder=J((14, 0, -4)),
           rHip=J((34, 0, 5), (0, 0.34, 0)), lHip=J((34, 0, -5), (0, 0.34, 0)))
# down onto the floor: the legs swing out in front as the body drops onto them
_floor_key(low, 2.75, "in", (-8, 0, 6), neck=(-32, 0, 8), rShoulder=J((16, 0, 6)), lShoulder=J((16, 0, -6)),
           rHip=J((60, 0, 6), (0, 0.2, 0)), lHip=J((60, 0, -6), (0, 0.2, 0)))
_floor_key(low, 2.95, "out", (-16, 0, 8), rise=0.02, neck=(-38, 0, 10), rShoulder=J((10, 0, 8)),
           lShoulder=J((10, 0, -8)), rHip=SIT_R, lHip=SIT_L)  # the bump
for t, breath in ((3.4, 0.0), (4.0, 1.0), (4.6, 0.0)):  # slumped, a last faint breath
    _floor_key(low, t, "sine", (-24 + 2 * breath, 0, 8), rise=0.01 * breath, neck=(-42 + 3 * breath, 0, 10),
               rShoulder=J((8, 0, 10)), lShoulder=J((8, 0, -10)), rHip=SIT_R, lHip=SIT_L)
low.follow(("rShoulder", "lShoulder"), 2.0, 0.6)
low.follow("neck", 2.4, 0.7)
low.build()

charge = Motion("lowBatteryCharge", 2.4, note="Plugged in: a jolt, another, and springing back up to standing.", floor=True)
_floor_key(charge, 0.0, "smooth", (-24, 0, 8), neck=(-42, 0, 10), rShoulder=J((8, 0, 10)), lShoulder=J((8, 0, -10)),
           rHip=SIT_R, lHip=SIT_L)
_floor_key(charge, 0.15, "snap", (-4, 0, -4), rise=0.08, neck=(10, 0, -6), rShoulder=J((30, 0, 40)),
           lShoulder=J((30, 0, -40)), rHip=SIT_R, lHip=SIT_L)  # the first jolt
_floor_key(charge, 0.4, "in", (-18, 0, 6), neck=(-30, 0, 8), rShoulder=J((10, 0, 12)), lShoulder=J((10, 0, -12)),
           rHip=SIT_R, lHip=SIT_L)
_floor_key(charge, 0.62, "snap", (2, 0, 0), rise=0.12, neck=(16, 0, 0), rShoulder=J((60, 0, 70)),
           lShoulder=J((60, 0, -70)), rHip=SIT_R, lHip=SIT_L)  # the second, bigger
# up: the legs swing down under the body as it rises off the floor
_floor_key(charge, 0.8, "in", (-14, 0, 0), neck=(2, 0, 0), rShoulder=J((50, 0, 40)), lShoulder=J((50, 0, -40)),
           rHip=J((68, 0, 6), (0, 0.3, 0)), lHip=J((68, 0, -6), (0, 0.3, 0)))
_floor_key(charge, 0.95, "out", (-24, 0, 0), neck=(-10, 0, 0), rShoulder=J((40, 0, 20)), lShoulder=J((40, 0, -20)),
           rHip=J((50, 0, 6), (0, 0.4, 0)), lHip=J((50, 0, -6), (0, 0.4, 0)))
charge.key(1.25, "out", offset=(0, -0.2, 0), root=(-8, 0, 0), neck=(-4, 0, 0), rShoulder=J((20, 0, 14)),
           lShoulder=J((20, 0, -14)), rHip=J((0, 0, 4), (0, 0.2, 0)), lHip=J((0, 0, -4), (0, 0.2, 0)))
# fully charged: a flex, arms up
charge.key(1.6, "snap", offset=(0, 0.02, 0), root=(4, 0, 0), neck=(10, 0, 0), rShoulder=J((150, 0, 40), (0, 0.15, 0)),
           lShoulder=J((150, 0, -40), (0, 0.15, 0)), rHip=J((0, 0, 4)), lHip=J((0, 0, -4)))
charge.key(2.0, "smooth", offset=(0, 0, 0), root=(3, 0, 0), neck=(8, 0, 0), rShoulder=J((148, 0, 40), (0, 0.15, 0)),
           lShoulder=J((148, 0, -40), (0, 0.15, 0)), rHip=J((0, 0, 4)), lHip=J((0, 0, -4)))
charge.key(2.4, "smooth", offset=(0, 0, 0), **REST, rHip=J((0, 0, 3)), lHip=J((0, 0, -3)))
charge.plant(1.25, 2.4, stance=0.06)
charge.follow(("rShoulder", "lShoulder"), 3.0, 0.55)
charge.build()

# Deducing (clip deducing, item emote_deducing) -------------------------------------------------------------
# Thumb to the lip, thinking (refs: deducing.toml): hunched a little, the right thumb pressed to the lower lip, the
# left hand in a pocket, the eyes going over the room in stops and starts, the weight shifting as the thought
# turns; twice a tap of the thumb. A 4 s loop (also a stance).
deduce = Motion("deducing", 4.0, loop=True, note="Thumb to the lip, hunched, the eyes going over the room in stops and "
                "starts, tapping.")
THUMB = reach(1, (0.12, 1.1, -0.85), direction=(-0.45, 0.75, -0.5))
THUMB_TAP = reach(1, (0.12, 1.14, -0.8), direction=(-0.45, 0.75, -0.5))
for t, look, side, thumb in ((0.0, 0, 1, THUMB), (0.6, 14, 1, THUMB), (1.1, 14, 1, THUMB_TAP), (1.25, 14, 1, THUMB),
                             (2.0, -12, -1, THUMB), (2.8, -16, -1, THUMB), (3.1, -16, -1, THUMB_TAP),
                             (3.25, -16, -1, THUMB)):
    deduce.key(t, "smooth", offset=(0.04 * side, -0.07, 0), root=(-10, 3 * side, 2 * side), neck=(-6, look, 0),
               rShoulder=thumb, lShoulder=POCKET_L)
deduce.follow("neck", 2.2, 0.85)
deduce.follow(("rShoulder", "lShoulder"), 3.0, 0.7)
deduce.plant(stance=0.16)
deduce.build()

# Reaper's Cackle (clip reapersCackle, item emote_reapers_cackle; Muerto's mastery) -------------------------
# A death god's laugh, Ryuk's "hyuk hyuk" (Death Note; refs: reapersCackle.toml): hunched over, the shoulders heaving
# up round the ears with each burst, the head jerking back, the arms dangling and swinging with it, the knees
# bouncing. Four bursts in a 1.6 s loop.
cackle = Motion("reapersCackle", 1.6, loop=True, note="Ryuk's laugh: hunched, shoulders heaving with each burst, "
                "the head jerking back, arms dangling.")
for i in range(4):
    t = i * 0.4
    side = 1 if i % 2 == 0 else -1
    cackle.key(round(t, 4), "out", offset=(0.04 * side, -0.04, 0), root=(-12, 6 * side, 5 * side), neck=(28, -8 * side, 6 * side),
               rShoulder=J((34, 0, 14), (0, 0.32, -0.06)), lShoulder=J((34, 0, -14), (0, 0.32, -0.06)))  # the burst
    cackle.key(round(t + 0.22, 4), "in", offset=(0.01 * side, -0.16, 0), root=(-26, 2 * side, 1 * side),
               neck=(-4, -2 * side, 0), rShoulder=J((12, 0, -6), (0, 0.02, -0.03)), lShoulder=J((12, 0, 6), (0, 0.02, -0.03)))
cackle.follow(("rShoulder", "lShoulder"), 5.0, 0.4)
cackle.follow("neck", 4.0, 0.5)
cackle.plant(stance=0.16)
cackle.build()

# Final Breakdown (clip finalBreakdown, item emote_final_breakdown) -----------------------------------------
# Light's laugh in the warehouse (Death Note, episode 37; refs: finalBreakdown.toml, the scene at 40-51 s of
# "Light Can't Stop Laughing"): bent over, a hand over his face, the shoulders shaking with a laugh he cannot
# hold in; then the head thrown back, the arms flung open, the full maniac laugh; folding over once more, and up.
breakdown = Motion("finalBreakdown", 5.4, note="Light in the warehouse: bent over, a hand over the face, shaking; "
                   "then thrown back, arms open, the full laugh.")
FACE_R = reach(1, (0.1, 1.45, -0.8), direction=(-0.55, 0.75, -0.35))
breakdown.key(0.0, "smooth", **REST)
breakdown.key(0.6, "in", offset=(0, -0.1, -0.05), root=(-24, 0, 0), neck=(-16, 0, 0), rShoulder=FACE_R,
              lShoulder=J((26, 0, 10), (0.1, 0, -0.1)))
for i in range(10):  # the held-in laugh: small shakes
    t = 0.7 + 0.13 * i
    j = 1 if i % 2 == 0 else -1
    breakdown.key(round(t, 4), "sine", offset=(0, -0.1 + 0.02 * j, -0.05), root=(-24 + 2 * j, 2 * j, 0),
                  neck=(-16 + 3 * j, 0, 0), rShoulder=FACE_R, lShoulder=J((26 + 3 * j, 0, 10), (0.1, 0, -0.1)))
breakdown.key(2.25, "out", offset=(0, -0.06, 0.2), root=(18, 0, 0), neck=(34, 0, 0), rShoulder=J((80, 0, 72)),
              lShoulder=J((80, 0, -72)))  # thrown back
for i in range(12):  # the full laugh
    t = 2.35 + 0.12 * i
    j = 1 if i % 2 == 0 else -1
    breakdown.key(round(t, 4), "sine", offset=(0, -0.06 + 0.02 * j, 0.2), root=(18 + 3 * j, 2 * j, 0),
                  neck=(34 + 6 * j, 0, 0), rShoulder=J((80 + 6 * j, 0, 72)), lShoulder=J((80 - 6 * j, 0, -72)))
breakdown.key(4.2, "in", offset=(0, -0.12, -0.05), root=(-26, 0, 0), neck=(-12, 0, 0),
              rShoulder=J((40, 0, -36), (-0.25, 0, -0.15)), lShoulder=J((40, 0, 36), (0.25, 0, -0.15)))  # folded over
breakdown.key(4.6, "smooth", offset=(0, -0.1, -0.05), root=(-24, 0, 0), neck=(-10, 0, 0),
              rShoulder=J((38, 0, -34), (-0.25, 0, -0.15)), lShoulder=J((38, 0, 34), (0.25, 0, -0.15)))
breakdown.key(5.4, "smooth", offset=(0, 0, 0), **REST)
breakdown.follow(("rShoulder", "lShoulder"), 3.6, 0.6)
breakdown.follow("neck", 3.0, 0.7)
breakdown.plant(stance=0.2, forward=(0.1, -0.1))
breakdown.build()

# New World (clip newWorld, item emote_new_world) -----------------------------------------------------------
# "I will become the god of this new world" (Death Note, episode 1; the owner's answer, 2026-10-20: the arm raised to
# the sky, the fist closed; refs: newWorld.toml): the head bowed, then the right arm rising slowly to the sky, the
# chest opening, the face lifting after it, the fist closing at the top, held in the light (EmoteFx), and down.
world = Motion("newWorld", 6.5, note="The god of the new world: out of the white, bowed, the arm raised slowly to the "
               "sky, the fist closed, the face up, held as a silhouette.")
SKY_R = J((172, 0, 10), (0, 0.2, 0))
# (6.5 s, the owner's Q23: the cutscene opens on white and holds the silhouette; the rise and the fist as before,
# a second later)
world.key(0.0, "smooth", **REST)
world.key(1.1, "smooth", offset=(0, -0.03, 0), root=(-6, 0, 0), neck=(-22, 0, 0), rShoulder=J((10, 0, 6)),
          lShoulder=J((6, 0, -6)))  # bowed
world.key(1.7, "smooth", offset=(0, -0.035, 0), root=(-6.5, 0, 0), neck=(-24, 0, 0), rShoulder=J((10, 0, 6)),
          lShoulder=J((6, 0, -6)))  # still bowed
world.key(2.6, "sine", offset=(0, 0, 0.02), root=(3, 0, 0), neck=(6, 0, 0), rShoulder=J((110, 0, 16), (0, 0.1, 0)),
          lShoulder=J((10, 0, -18)))
world.key(3.3, "out", offset=(0, 0.02, 0.04), root=(7, 0, 0), neck=(28, 0, 0), rShoulder=SKY_R,
          lShoulder=J((14, 0, -26)))  # at the top
world.key(3.42, "snap", offset=(0, 0.02, 0.04), root=(8, 0, 0), neck=(30, 0, 0), rShoulder=J((174, 0, 9), (0, 0.22, 0)),
          lShoulder=J((16, 0, -28)))  # the fist closes
world.key(5.6, "smooth", offset=(0, 0.02, 0.04), root=(8, 0, 0), neck=(30, 0, 0), rShoulder=SKY_R,
          lShoulder=J((14, 0, -28)))  # held
world.key(6.5, "sine", offset=(0, 0, 0), **REST)
world.follow(("rShoulder", "lShoulder"), 2.4, 0.8)
world.follow("neck", 1.8, 0.85)
world.plant(stance=0.12)
world.build()

# Reaper's Eyes (clip reapersEyes, item emote_reapers_eyes) -------------------------------------------------
# A death god's eyes (Death Note; refs: reapersEyes.toml): looking away over the shoulder, a hand coming up over
# the eyes, the head turning slowly round under it to face you, and the hand drawn away to show the eyes, red
# (EmoteFx, at 1.75 s), the stare held, the chin lowering. Lobby only (it looks like the Eyes).
eyes = Motion("reapersEyes", 3.2, note="Looking away, a hand over the eyes, the head turning round under it, the hand "
              "drawn away: red eyes, the stare.")
OVER_EYES = reach(1, (0.05, 1.7, -0.75), direction=(-0.6, 0.75, -0.25))
eyes.key(0.0, "smooth", **REST)
eyes.key(0.45, "smooth", root=(0, 14, 0), neck=(-2, 64, 0), rShoulder=HANG_R, lShoulder=HANG_L)
eyes.key(0.9, "smooth", root=(0, 10, 0), neck=(-4, 50, 0), rShoulder=OVER_EYES, lShoulder=HANG_L)
eyes.key(1.6, "sine", root=(-2, 0, 0), neck=(-8, 0, 0), rShoulder=OVER_EYES, lShoulder=HANG_L)
eyes.key(1.85, "out", root=(-3, 0, 0), neck=(-12, 0, 0), rShoulder=reach(1, (1.4, 1.1, -0.9), direction=(0.6, 0.4, -0.7)),
         lShoulder=HANG_L)  # drawn away
eyes.key(2.5, "smooth", root=(-3, 0, 0), neck=(-14, 0, 0), rShoulder=J((10, 0, 10)), lShoulder=HANG_L)
eyes.key(3.2, "smooth", root=(-2, 0, 0), neck=(-15, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
eyes.follow("neck", 1.6, 0.9)
eyes.follow(("rShoulder", "lShoulder"), 3.0, 0.75)
eyes.plant(stance=0.06)
eyes.build()

# Foot Scratch (clip footScratch, item emote_foot_scratch) --------------------------------------------------
# L's barefoot foot scratch (Death Note; refs: footScratch.toml): hunched, the hands in his pockets, standing on
# the left leg, the right foot rubbing up and down the left shin, the body swaying to keep its balance over the
# one foot, the head down watching. A 2 s loop (also a stance).
scratch = Motion("footScratch", 2.0, loop=True, note="L on one leg, the bare foot rubbing up and down the other shin, "
                 "swaying to balance.")
rub_low, rub_high = J((10, 0, -12), (-0.22, 0.34, -0.1)), J((12, 0, -14), (-0.22, 0.62, -0.1))
for t, high, sway in ((0.0, 0, 0.0), (0.5, 1, 1.0), (1.0, 0, 0.0), (1.5, 1, -1.0)):
    scratch.key(t, "sine", offset=(-0.08 + 0.02 * sway, -0.05, 0), root=(-10, 4, -3 + 2 * sway), neck=(-20, 4, 2 * sway),
                rShoulder=POCKET_R, lShoulder=POCKET_L, rHip=rub_high if high else rub_low)
scratch.follow("neck", 1.6, 0.7)
scratch.plant(stance=0.0)
scratch.build()

# Hair Twirl (clip hairTwirl, item emote_hair_twirl) --------------------------------------------------------
# Near twirling his hair (Death Note; refs: hairTwirl.toml): sitting on the floor, the legs out in front along it in a
# V (the R6 way of sitting), slouched, the left hand on the floor behind, the right forefinger twisting a lock of
# hair round and round at the side of the head, the head tilted to it, a slow rock. A 2.4 s loop (also a stance).
twirl = Motion("hairTwirl", 2.4, loop=True, note="Near on the floor, legs out, twisting a lock of hair round a finger, "
               "the head tilted.")
TW_R, TW_L = J((84, 0, 14)), J((84, 0, -10))
for i in range(4):
    t = i * 0.6
    a = 2 * math.pi * i / 4
    _floor_key(twirl, t, "sine", (-12 + 2 * math.sin(a), 6, 0), neck=(-8, 12, 10 + 3 * math.sin(a)),
               rShoulder=reach(1, (0.95 + 0.06 * math.cos(a), 1.75 + 0.06 * math.sin(a), -0.35), direction=(-0.1, 0.9, -0.4)),
               lShoulder=J((-24, 0, -22), (0, -0.05, 0.1)), rHip=TW_R, lHip=TW_L)
twirl.follow("neck", 1.6, 0.8)
twirl.build()
