"""The meeting seats (shop overhaul, 2026-10-21): how a body sits in its war-room chair for a meeting and the vote.
Six loops, each a seat cosmetic (src/shared/Cosmetics.luau, kind "seat"); the plain one is everyone's. They play
as the body's base layer while it sits (the "Seat" attribute, LocomotionController), so an emote from the waist up
plays over the legs. R6 legs do not bend, so sitting is the legs out level in front, the torso upright on their back
ends (the owner's drawing); the crouch on the chair (Perched) is the same legs, the body hunched over them. Nothing reaches
the table: the war room's chairs stand 6.5 studs back from it.

Every chair a seat can be in shares the war chair's seat as the war room places it (scaled 1.3, so an R6 body fits
between its arms): the cushion's top 2.56 high, and the body's root 0.32 behind the chair's middle (MeetingService
places it there), so the torso's back meets the chair's back and the thighs reach a little past the cushion."""

import posekit
from animlib import J
from emotes.kit import reach
from motion import Motion

SEAT_TOP = 2.56  # WarChair's cushion (props_meeting.py: 0.5 thick round 1.72) at the war room's scale 1.3; every skin's
# Legs as their pitch, yaw and roll in the WORLD (level on the cushion whatever the torso does: _sit turns the hips
# back by the body's lean, which would otherwise tip them, lift their back ends and raise the body off the seat).
SIT_R, SIT_L = (88, 0, 3), (88, 0, -3)  # the legs level in front, a little apart
# Perched: the legs level along the cushion (the owner's drawing, on a seat), a little wider apart. (Tipped down at
# the front like the floor crouch, their tips would pass the cushion's edge and the seat would lift the hips off it.)
PERCH_R, PERCH_L = (88, 0, 6), (88, 0, -6)


def _sit(m, t, ease, root, legs=None, breath=0.0, **joints):
    """A key sat on the war chair: the hips and thighs on its cushion, `breath` (0..1) lifting the chest a little.
    `legs` are world angles (see SIT_R): the hips are turned back by the root's pitch so they stay level."""
    pitch = root[0] - 1.2 * breath
    body = (pitch, root[1], root[2])
    (rp, ry, rr), (lp, ly, lr) = legs or (SIT_R, SIT_L)
    rl, ll = J((rp - pitch, ry, rr)), J((lp - pitch, ly, lr))
    pose = {"root": J(body), "rHip": rl, "lHip": ll}
    ox, oy, oz = posekit.on_seat(pose, (0.0, 0.0, 0.0), seat=SEAT_TOP)
    m.key(round(t, 4), ease, offset=(ox, oy, oz), root=body, rHip=rl, lHip=ll, **joints)


# Hands at rest, torso frame (x right, y up, z back): the knees are the thighs' front ends, 1.9 ahead of the hips.
ON_KNEE_R = reach(1, (0.62, -0.42, -1.55), direction=(0.0, -0.45, -0.9))
ON_KNEE_L = reach(-1, (-0.62, -0.42, -1.55), direction=(0.0, -0.45, -0.9))
FOLDED_R = reach(1, (0.42, -0.36, -1.4), direction=(-0.35, -0.4, -0.85))  # both hands on the right knee
FOLDED_L = reach(-1, (0.12, -0.3, -1.38), direction=(0.55, -0.35, -0.75))
# fingertips meeting under the chin (R6 arms are big: any higher and they hide the face)
STEEPLE_R = reach(1, (0.13, 0.72, -1.3), direction=(-0.35, 0.45, -0.8))
STEEPLE_L = reach(-1, (-0.13, 0.72, -1.3), direction=(0.35, 0.45, -0.8))
ALONG_ARM_R = reach(1, (1.45, -0.35, -1.3), direction=(0.0, -0.3, -1.0))  # the arm laid along the chair's arm
LAP_L = reach(-1, (-0.35, -0.5, -1.0), direction=(0.3, -0.5, -0.8))
CHIN_R = reach(1, (0.18, 1.08, -0.82), direction=(-0.1, 0.85, -0.45))  # the fist under the chin
ACROSS_L = reach(-1, (0.25, -0.42, -1.2), direction=(0.7, -0.3, -0.6))
THUMB_LIP = reach(1, (0.12, 0.85, -0.85), direction=(-0.45, 0.75, -0.5))
OVER_KNEES = reach(-1, (-0.35, -0.55, -1.5), direction=(0.3, -0.35, -0.9))
CROSSED_R, CROSSED_L = (78, -12, -2), (90, 0, -4)  # the right leg over the left
CROSSED_L_OVER, UNDER_R = (78, 12, 2), (90, 0, 4)  # the left over the right

# Plain Seat (seatPlain, item seat_plain, everyone's): square in the chair, hands on the knees, breathing.
plain = Motion("seatPlain", 5.0, loop=True, note="Seated square, hands on the knees, breathing; a glance round.")
for t, b, neck in ((0.0, 0, (-3, 0, 0)), (1.25, 1, (-2, 8, 0)), (2.5, 0, (-3, 2, 0)), (3.75, 1, (-2, -8, 0))):
    _sit(plain, t, "sine", (-2, 0, 0), breath=b, neck=neck, rShoulder=ON_KNEE_R, lShoulder=ON_KNEE_L)
plain.follow("neck", 1.6, 0.75)
plain.build()

# The Calculating Seat (seatComposed): upright, hands folded on the right knee, the eyes moving slowly from face to
# face round the table.
composed = Motion("seatComposed", 8.0, loop=True, note="Upright, hands folded on a knee, the head turning slowly "
                  "from face to face.")
for t, b, look in ((0.0, 0, -20), (1.2, 1, -22), (2.4, 0, 0), (3.4, 1, 2), (4.6, 0, 22), (5.8, 1, 22), (7.0, 0, 2)):
    _sit(composed, t, "smooth", (0, look * 0.12, 0), breath=b, neck=(-4, look, 0), rShoulder=FOLDED_R,
         lShoulder=FOLDED_L)
composed.follow("neck", 1.2, 0.8)
composed.build()

# At Ease (seatEase): leaning back, the right arm laid along the chair's arm, the right leg crossed over the left,
# the head back a little.
ease = Motion("seatEase", 6.0, loop=True, note="Leaning back at ease: an arm along the chair's arm, legs "
              "crossed.")
for t, b, neck in ((0.0, 0, (8, -6, 2)), (1.5, 1, (9, -2, 3)), (3.0, 0, (7, 6, 1)), (4.5, 1, (9, 0, 2))):
    _sit(ease, t, "sine", (7, 4, 0), legs=(CROSSED_R, CROSSED_L), breath=b, neck=neck, rShoulder=ALONG_ARM_R,
         lShoulder=LAP_L)
ease.follow("neck", 1.4, 0.75)
ease.build()

# Steepled (seatSteepled): leaning in, the fingertips steepled under the chin, very still; now and then the eyes
# lift over the hands.
steeple = Motion("seatSteepled", 7.0, loop=True, note="Leaning in, fingertips steepled under the chin, still; "
                 "the eyes lift over the hands now and then.")
for t, b, neck in ((0.0, 0, (-14, 0, 0)), (2.0, 1, (-14, 0, 0)), (3.4, 0, (-4, 6, 0)), (4.6, 1, (-5, 6, 0)),
                   (5.8, 0, (-13, 0, 0))):
    _sit(steeple, t, "smooth", (-9, 0, 0), breath=b * 0.6, neck=neck, rShoulder=STEEPLE_R, lShoulder=STEEPLE_L)
steeple.follow("neck", 1.0, 0.85)
steeple.build()

# Perched (seatPerched): Ace's crouch on the seat (the owner's drawing: the legs out in front along it, the torso
# upright on their back ends), hunched, the thumb at the lip, the left arm over the knees, rocking a little.
perched = Motion("seatPerched", 4.0, loop=True, note="Ace crouched on the seat: thumb at the lip, rocking, thinking.")
for t, b, neck, rock in ((0.0, 0, (-2, 0, 0), 0), (1.0, 1, (-1, 4, -4), 1), (2.0, 0, (-1, 7, -9), 0),
                         (3.0, 1, (-1, 3, -3), 1)):
    _sit(perched, t, "sine", (-12 + 3 * rock, 0, 0), legs=(PERCH_R, PERCH_L), breath=b, neck=neck,
         rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
perched.follow("neck", 1.5, 0.72)
perched.follow(("rShoulder", "lShoulder"), 2.2, 0.7)
perched.build()

# Chin on Fist (seatChin): legs crossed the other way, the chin on the right fist, bored of everyone; a slow sigh.
chin = Motion("seatChin", 6.0, loop=True, note="Legs crossed, chin on a fist, bored; a slow sigh.")
for t, b, neck in ((0.0, 0, (6, -8, 10)), (2.2, 1, (8, -8, 12)), (3.0, 0, (2, -10, 8)), (4.4, 0, (5, -6, 11))):
    _sit(chin, t, "smooth", (-6, -6, 3), legs=(UNDER_R, CROSSED_L_OVER), breath=b, neck=neck, rShoulder=CHIN_R,
         lShoulder=ACROSS_L)
chin.follow("neck", 1.3, 0.8)
chin.build()

SEATS = ("seatPlain", "seatComposed", "seatEase", "seatSteepled", "seatPerched", "seatChin")
