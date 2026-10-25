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

# The paid seats, redone 2026-10-25 (the owner: "make the sitting styles more unique and exaggerated because right
# now they look boring"): each a character with a bigger pose and something it does, not a pose that breathes.

# The Calculating Seat (seatComposed): bolt upright, hands folded on the right knee, chin up; the head sweeps the
# table and locks onto one face, then another (a snap and a small lean in each time), drops to the hands to think,
# the right forefinger tapping on the knuckles, and lifts again.
TAP_R = reach(1, (0.42, -0.24, -1.42), direction=(-0.35, -0.2, -0.9))  # the right hand lifted off the left for a tap
composed = Motion("seatComposed", 8.0, loop=True, note="Upright, chin up, hands folded on a knee: the head sweeps "
                  "the table and locks onto a face, then another; looks down to think, a finger tapping.")
for t, ease, b, look, lean, neck_pitch in ((0.0, "smooth", 0, -10, 0, 4), (0.6, "snap", 1, -40, -7, 2),
                                           (1.8, "smooth", 0, -38, -5, 3), (2.6, "sine", 1, 0, 0, 5),
                                           (3.2, "snap", 0, 42, -7, 2), (4.4, "smooth", 1, 40, -5, 3),
                                           (5.2, "sine", 0, 4, -3, -16), (6.6, "smooth", 1, 2, -2, -14),
                                           (7.4, "sine", 0, -8, 0, 4)):
    _sit(composed, t, ease, (lean, look * 0.25, 0), breath=b, neck=(neck_pitch, look, 0), rShoulder=FOLDED_R,
         lShoulder=FOLDED_L)
for k, t in enumerate((5.5, 5.75, 6.0, 6.25)):
    composed.key(t, "snap", rShoulder=TAP_R if k % 2 == 0 else FOLDED_R)
composed.key(6.5, "smooth", rShoulder=FOLDED_R)
composed.follow("neck", 2.2, 0.62)
composed.build()

# At Ease (seatEase): lounging far back as if the chair were a throne, the right arm laid along the chair's arm, the
# left hand behind the head, the right leg crossed over and its foot swinging lazily; halfway, a long yawn and a
# stretch, the right arm up over the head.
BEHIND_HEAD_L = reach(-1, (-0.55, 1.5, 0.35), direction=(0.35, 0.65, 0.65))
STRETCH_R = reach(1, (0.9, 2.7, -0.2), direction=(-0.1, 1.0, -0.05))
ease = Motion("seatEase", 6.0, loop=True, note="Lounging far back: an arm along the chair's arm, a hand behind the "
              "head, legs crossed and a foot swinging; a long yawn and stretch.")
for t, swing, b, neck in ((0.0, 72, 0, (12, -10, 4)), (0.7, 82, 1, (13, -8, 5)), (1.4, 72, 0, (12, -6, 4)),
                          (2.1, 82, 1, (11, -4, 3)), (3.6, 76, 1, (26, 0, 0)), (4.6, 80, 0, (14, 6, -2)),
                          (5.3, 72, 1, (12, -4, 3))):
    _sit(ease, t, "sine", (16, 6, -2), legs=((swing, -12, -2), CROSSED_L), breath=b, neck=neck,
         rShoulder=ALONG_ARM_R, lShoulder=BEHIND_HEAD_L)
ease.key(2.8, "smooth", rShoulder=ALONG_ARM_R)
ease.key(3.6, "out", rShoulder=STRETCH_R)
ease.key(4.4, "sine", rShoulder=STRETCH_R)
ease.key(5.0, "smooth", rShoulder=ALONG_ARM_R)
ease.follow("neck", 1.4, 0.75)
ease.follow("rShoulder", 2.0, 0.7)
ease.build()

# Steepled (seatSteepled): hunched far in over steepled fingers, the head low so the eyes look up over the hands at
# whoever is talking; the fingertips tapping together; now and then the head tips slowly to one side, a long stare,
# and a lean back that brings it down level again.
STEEPLE_APART_R = reach(1, (0.22, 0.7, -1.3), direction=(-0.35, 0.45, -0.8))
STEEPLE_APART_L = reach(-1, (-0.22, 0.7, -1.3), direction=(0.35, 0.45, -0.8))
steeple = Motion("seatSteepled", 7.0, loop=True, note="Hunched far in over steepled fingers, eyes up over the hands; "
                 "the fingertips tapping; a slow tilt of the head and a long stare.")
for t, ease_, b, lean, neck in ((0.0, "smooth", 0, -18, (-4, 0, 0)), (1.6, "smooth", 1, -19, (-3, 4, 0)),
                                (2.8, "sine", 0, -17, (-2, 8, 14)), (4.4, "smooth", 1, -16, (-2, 6, 15)),
                                (5.4, "sine", 0, -10, (-8, 0, 2)), (6.3, "smooth", 1, -18, (-4, -2, 0))):
    _sit(steeple, t, ease_, (lean, 0, 0), breath=b * 0.6, neck=neck, rShoulder=STEEPLE_R, lShoulder=STEEPLE_L)
for start in (0.5, 5.8):
    for k in range(4):
        apart = k % 2 == 0
        steeple.key(round(start + 0.16 * k, 4), "snap", rShoulder=STEEPLE_APART_R if apart else STEEPLE_R,
                    lShoulder=STEEPLE_APART_L if apart else STEEPLE_L)
    steeple.key(round(start + 0.7, 4), "smooth", rShoulder=STEEPLE_R, lShoulder=STEEPLE_L)
steeple.follow("neck", 1.0, 0.85)
steeple.build()

# Perched (seatPerched): Ace's crouch on the seat (the owner's drawing: the legs out in front along it, the torso
# upright on their back ends), hunched deep and rocking, the thumb at the lip, the head cocked far to one side and
# then the other; a sudden snap of the head toward whoever spoke, a stare, and back to rocking.
perched = Motion("seatPerched", 4.0, loop=True, note="Ace crouched on the seat: hunched deep and rocking, thumb at "
                 "the lip, the head cocking side to side; a snap glance at a speaker.")
for t, ease_, b, neck, rock in ((0.0, "sine", 0, (-4, 0, -14), 0), (0.9, "sine", 1, (-3, 4, 10), 1),
                                (1.8, "sine", 0, (-4, 2, -12), 0), (2.5, "snap", 1, (2, 36, 4), 1),
                                (3.3, "smooth", 0, (0, 30, 2), 0)):
    _sit(perched, t, ease_, (-22 + 6 * rock, 0, rock * 3 - 1.5), legs=(PERCH_R, PERCH_L), breath=b, neck=neck,
         rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
perched.follow("neck", 2.4, 0.6)
perched.follow(("rShoulder", "lShoulder"), 2.2, 0.7)
perched.build()

# Chin on Fist (seatChin), redesigned 2026-10-22 and pushed further 2026-10-25: sunk low and bored of everyone,
# slouched back with the legs stretched out long and crossed at the ankles, the chin on the right fist, the head
# lolling over; a heavy sigh that lifts and drops the whole body, the left fingers drumming fast on the chair's arm,
# and an eye-roll, the head thrown back and round.
ANKLES_R, ANKLES_L = (84, -7, -1), (80, 8, 2)  # stretched out, the left ankle over the right
DRUM_L = reach(-1, (-1.45, -0.32, -1.25), direction=(0.0, -0.3, -1.0))  # the hand on the chair's arm
DRUM_UP_L = reach(-1, (-1.45, -0.18, -1.25), direction=(0.0, 0.0, -1.0))  # the fingers lifted for a tap
chin = Motion("seatChin", 6.0, loop=True, note="Sunk low, legs out crossed at the ankles, chin on a fist, drumming "
              "the chair's arm; a heavy sigh and an eye-roll.")
for t, ease_, b, neck, lean in ((0.0, "smooth", 0, (8, -10, 16), 13), (1.4, "smooth", 0, (9, -12, 20), 14),
                                (2.2, "out", 1, (14, -6, 10), 6), (3.0, "in", 0, (6, -12, 18), 16),
                                (4.0, "sine", 0, (24, -18, 6), 12), (4.6, "sine", 0, (22, 16, -4), 12),
                                (5.3, "smooth", 0, (8, -10, 17), 14)):
    _sit(chin, t, ease_, (lean, -6, 4), legs=(ANKLES_R, ANKLES_L), breath=b, neck=neck, rShoulder=CHIN_R,
         lShoulder=DRUM_L)
for start in (0.5, 3.2):
    for k in range(6):
        chin.key(round(start + 0.1 * k, 4), "snap", lShoulder=DRUM_UP_L if k % 2 == 0 else DRUM_L)
    chin.key(round(start + 0.7, 4), "smooth", lShoulder=DRUM_L)
chin.follow("neck", 1.3, 0.8)
chin.build()

SEATS = ("seatPlain", "seatComposed", "seatEase", "seatSteepled", "seatPerched", "seatChin")
