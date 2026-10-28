"""The paid win cutscenes' star (shop overhaul, 2026-10-21; the owner's Q35): what the winner's copy acts on each
set, 8 s each. The sets, the camera and the effects are src/shared/Cinema/WinCuts.luau (played by
Presentation/WinCinema); the numbers here are that file's, in the star's floor frame (x right, y up, z back; the star
starts on its mark at the origin facing -z).

    winFinalPage   the Coven's Sealed one: at a table by a rain-streaked window, the last name written, the Manual
                   snapped shut, leaning back as the candles go out (the Potato Chip scene's table and chair: the
                   Table's middle 2.05 ahead, its top 2.75 high; the Chair 1.4 behind, its seat 1.75 high)
    winNewWorld    the Coven's Godhood one: walking to a roof's edge with the Manual, opening it as its pages tear
                   loose, then the arms spread over the city as its lights die (the parapet 6.7 ahead)
    winCaseClosed  the Bureau's Sealed one: crouched on a chair before a desk (the owner's R6 crouch), watching the
                   evidence board's strings snap, then the stamp slammed on the case file and a sugar cube at the lip
                   (the Chair 0.15 behind, its seat 1.745 high; the Table's middle 3.3 ahead, top 2.75)
    winCheckmate   the Bureau's Godhood one: on a vast chessboard, walking up to a giant black king and tipping it
                   over with one finger (the king's front 5.9 ahead)

and each told for the other side (the user, 2026-10-27: every shop win cutscene for both Ace and the Coven):

    winFinalPageBureau   Ace at the archive's table at dawn: the Manual's last page torn out and burned on a match,
                         the book shut and sealed in an evidence bag (the table's near edge 0.8 ahead, its top 2.75)
    winNewWorldBureau    Ace down to the courthouse's top step with the Manual, raising it high over the press as
                         the screens across the square show the news
    winCaseClosedCoven   Diavolo in the detective's armchair before the fire, the case file read and thrown on it,
                         laughing as the string wall burns (the ClubChair's cushion 2.0 high, its back behind)
    winCheckmateCoven    Diavolo at a crate on a roof's edge in the rain, the white king flicked off the board and
                         over the parapet, watching it fall (the board 2.4 high, 2.4 ahead)
"""

import posekit
from animlib import J
from emotes.kit import reach
from emotes.props import BOOK_HAND, THUMB_LIP, OVER_KNEES, _low
from motion import Motion

REST = dict(root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))
STAND = dict(rHip=J((0, 0, 1)), lHip=J((0, 0, -1)))
LENGTH = 8.0


def walk(m, t0, t1, z0, z1, steps, upper, rise=0.0):
    """Steps from z0 to z1 (floor frame) between t0 and t1: the legs swinging in turn, the body bobbing up (so a swung
    sole never dips into the floor), the root
    swaying; `upper(t, k)` gives the key's other joints at step k."""
    span = (t1 - t0) / steps
    for k in range(steps + 1):
        t = t0 + k * span
        z = z0 + (z1 - z0) * k / steps
        lead = 1 if k % 2 == 0 else -1  # which leg is ahead at this contact
        last = k == steps
        legs = (dict(rHip=J((0, 0, 1)), lHip=J((0, 0, -1))) if k == 0 or last
                else dict(rHip=J((22 * lead, 0, 1)), lHip=J((-18 * lead, 0, -1))))
        m.key(round(t, 4), "smooth", offset=(0, 0.02 if 0 < k < steps else 0.0 + rise, z), **legs, **upper(t, k))
        if not last:  # passing: the legs together, the body up
            mid = t + span / 2
            zm = z + (z1 - z0) / steps / 2
            m.key(round(mid, 4), "smooth", offset=(0, 0.06 + rise, zm), rHip=J((4 * lead, 0, 1)),
                  lHip=J((-4 * lead, 0, -1)), **upper(mid, k))


# The Final Page (winFinalPage) -------------------------------------------------------------------------------
# Seated like the Potato Chip scene: the torso's middle 2.75 up and 0.75 back, so the table top is the torso frame's
# y = 0. The open Manual lies on the table, its page's middle at torso (0.0, 0.1, -2.05).
SEAT = (0, -0.25, 0.75)
SIT = dict(rHip=J((84, 0, 3), (0, 0.05, 0)), lHip=J((84, 0, -3), (0, 0.05, 0)))
FLAT_L = reach(-1, (-1.05, 0.45, -1.6), direction=(0.1, -0.25, -1.0))  # the left hand flat by the book
FLAT_R = reach(1, (1.05, 0.45, -1.6), direction=(-0.1, -0.25, -1.0))


def write_at(x, y, lift=0.0):
    """The right fist with the pen's tip on the page at (x across, y down it)."""
    return reach(1, (0.1 + x, 0.95 + lift, -1.95 - y), direction=(-0.3, -0.6, -0.75))


page = Motion("winFinalPage", LENGTH, note="The Final Page: the last name written, the Manual snapped shut, leaning "
              "back as the candles die; a silhouette in the lightning.", unwrap=True)
page.key(0.0, "smooth", offset=SEAT, root=(-10, 0, 0), neck=(-26, 0, 0), rShoulder=write_at(-0.3, 0.0),
         lShoulder=FLAT_L, **SIT)
for i in range(12):  # the last name, in hard quick strokes
    t = 0.2 + 0.17 * i
    x = -0.3 + 0.06 * i + (0.05 if i % 2 else -0.04)
    y = (0.06 if i % 3 == 0 else -0.04)
    page.key(round(t, 4), "linear" if 0 < i < 11 else "smooth", offset=SEAT, root=(-10, 2 - 0.3 * i, 0),
             neck=(-26, 4 - 0.8 * i, 0), rShoulder=write_at(x, y, 0.04 if i % 2 else 0.0), lShoulder=FLAT_L, **SIT)
page.key(2.3, "out", offset=SEAT, root=(-8, -2, 0), neck=(-24, -4, 0), rShoulder=write_at(0.45, 0.3, 0.3),
         lShoulder=FLAT_L, **SIT)  # the pen down by the book
page.key(2.6, "smooth", offset=SEAT, root=(-6, 0, 0), neck=(-20, 0, 0),
         rShoulder=reach(1, (0.95, 1.15, -2.0), direction=(-0.3, -0.4, -0.85)), lShoulder=FLAT_L, **SIT)  # the cover
page.key(2.88, "in", offset=SEAT, root=(-4, 4, 0), neck=(-16, 4, 0),
         rShoulder=reach(1, (0.35, 1.45, -2.0), direction=(-0.55, -0.2, -0.8)), lShoulder=FLAT_L, **SIT)  # lifted
page.key(3.0, "snap", offset=SEAT, root=(-12, -2, 0), neck=(-22, 0, 0),
         rShoulder=reach(1, (-0.15, 0.55, -2.0), direction=(-0.3, -0.7, -0.65)), lShoulder=FLAT_L, **SIT)  # SHUT
page.key(3.35, "out", offset=SEAT, root=(-9, 0, 0), neck=(-14, 0, 0),
         rShoulder=reach(1, (0.35, 0.5, -1.9), direction=(-0.2, -0.6, -0.8)),
         lShoulder=reach(-1, (-0.35, 0.5, -1.9), direction=(0.2, -0.6, -0.8)), **SIT)  # both hands on it
for t, neck in ((4.2, (-4, 2, 0)), (5.0, (2, 0, 0))):  # the head up: the candles going, one by one
    page.key(t, "sine", offset=SEAT, root=(-4 + t, 0, 0), neck=neck,
             rShoulder=reach(1, (0.35, 0.5, -1.85), direction=(-0.2, -0.6, -0.8)),
             lShoulder=reach(-1, (-0.35, 0.5, -1.85), direction=(0.2, -0.6, -0.8)), **SIT)
page.key(6.2, "sine", offset=(SEAT[0], SEAT[1], SEAT[2] + 0.12), root=(6, 0, 0), neck=(10, 0, 0), rShoulder=FLAT_R,
         lShoulder=FLAT_L, **SIT)  # leaning back, the chin up: the silhouette
page.key(7.1, "sine", offset=(SEAT[0], SEAT[1] + 0.02, SEAT[2] + 0.15), root=(8, 1, 0), neck=(11, 2, 0),
         rShoulder=FLAT_R, lShoulder=FLAT_L, **SIT)  # a breath in the stillness (the body never freezes)
page.key(8.0, "smooth", offset=(SEAT[0], SEAT[1], SEAT[2] + 0.14), root=(7, 2, 0), neck=(12, 4, 0), rShoulder=FLAT_R,
         lShoulder=FLAT_L, **SIT)
page.follow("neck", 3.0, 0.75).follow(("lShoulder",), 2.5, 0.8)
page.build()


# God of the New World (winNewWorld) ---------------------------------------------------------------------------
# Walks 4.5 studs to the roof's edge (0.4-2.6) with the Manual closed in the left hand, opens it before the chest
# (2.6-3.0; its pages tear loose), looks down on the city (3.0-6.0), then spreads the arms wide over it.
BOOK_DOWN = J((6, 0, -6), (0.0, 0.05, 0.0))  # the book hanging in the left hand
BOOK_UP = BOOK_HAND  # held open before the chest (Furious Scribbling's pose: its grip on the Manual fits it)
OPEN_R = reach(1, (0.45, 0.45, -1.4), direction=(-0.45, -0.2, -0.85))  # the right hand turning it open
SPREAD_R, SPREAD_L = J((18, 0, 116)), J((18, 0, -116))
EDGE = -4.5


def roof_upper(t, k):
    swing = 10 * (1 if k % 2 else -1)
    return dict(root=(-2, 2 * (1 if k % 2 else -1), 0), neck=(-6, 0, 0), rShoulder=J((swing, 0, 4)),
                lShoulder=BOOK_DOWN)


god = Motion("winNewWorld", LENGTH, note="God of the New World: to the roof's edge, the Manual opened as its pages "
             "tear loose, the arms spread over the dying city.", unwrap=True, floor=True)
god.key(0.0, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(-4, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=BOOK_DOWN,
        **STAND)
walk(god, 0.4, 2.6, 0.0, EDGE, 4, roof_upper)
god.key(2.85, "out", offset=(0, 0, EDGE), root=(-4, 0, 0), neck=(-12, 0, 0), rShoulder=OPEN_R, lShoulder=BOOK_UP,
        **STAND)
god.key(3.1, "snap", offset=(0, 0.02, EDGE), root=(2, 0, 0), neck=(-4, 0, 0),
        rShoulder=J((30, 0, 40)), lShoulder=BOOK_UP, **STAND)  # the pages tear loose: a flinch back
for t, neck in ((3.8, (-18, -8, 0)), (4.8, (-20, 6, 0)), (5.7, (-16, 0, 0))):  # looking down on it, the lights going
    god.key(t, "sine", offset=(0, 0, EDGE), root=(-3, 0, 0), neck=neck, rShoulder=J((10, 0, 12)),
            lShoulder=BOOK_UP, **STAND)
god.key(6.05, "in", offset=(0, -0.04, EDGE), root=(-6, 0, 0), neck=(-10, 0, 0), rShoulder=J((10, 0, 20)),
        lShoulder=reach(-1, (-0.6, 0.1, -1.2)), **STAND)  # gathering
god.key(6.7, "out", offset=(0, 0.04, EDGE), root=(8, 0, 0), neck=(16, 0, 0), rShoulder=SPREAD_R, lShoulder=SPREAD_L,
        **STAND)  # the arms spread
god.key(6.95, "sine", offset=(0, 0.06, EDGE), root=(10, 0, 0), neck=(19, 0, 0), rShoulder=J((20, 0, 125)),
        lShoulder=J((20, 0, -125)), **STAND)  # past wide, then settling: the Godhood beat lands with weight
god.key(8.0, "smooth", offset=(0, 0.05, EDGE), root=(9, 0, 0), neck=(18, 0, 2), rShoulder=J((22, 0, 118)),
        lShoulder=J((22, 0, -118)), **STAND)
god.follow("neck", 2.4, 0.75).follow(("rShoulder", "lShoulder"), 2.6, 0.72)
god.build()


# Case Closed (winCaseClosed) ----------------------------------------------------------------------------------
# Crouched on the chair (Chair Perch's way), the thumb at the lip, watching the board's strings snap (2.4-4.2);
# then the stamp off the desk and slammed on the case file (4.8), and a sugar cube from the bowl to the lip.
SEAT_TOP = 1.745
STAMP_AT = (0.8, -0.65, -2.25)  # the stamp on the desk, torso frame (crouched)
FILE_AT = (0.0, -0.4, -2.3)  # the case file's middle, under the stamp's blow
BOWL_AT = (1.5, -0.6, -2.2)  # (on the right, past the stamp: the right hand never crosses the left arm)


def perch(m, t, ease, root, **joints):
    _low(m, t, ease, root, z=0.12, seat=SEAT_TOP, **joints)


case = Motion("winCaseClosed", LENGTH, note="Case Closed: crouched on the chair, watching the strings snap; the stamp "
              "slammed down, a sugar cube to the lip.", unwrap=True)
for t, neck in ((0.0, (8, 0, -2)), (1.2, (9, -6, -4)), (2.4, (10, 4, -2)), (3.1, (8, -10, -6)), (3.7, (10, 8, 0)),
                (4.15, (6, 0, 0))):
    perch(case, t, "sine", (-12, 0, 0), neck=neck, rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
perch(case, 4.45, "smooth", (-22, -6, 0), neck=(-14, 6, 0),
      rShoulder=reach(1, (STAMP_AT[0], STAMP_AT[1] + 0.55, STAMP_AT[2]), direction=(-0.2, -0.75, -0.6)),
      lShoulder=OVER_KNEES)  # a hand to the stamp
perch(case, 4.68, "in", (-14, -2, 0), neck=(-12, 4, 0),
      rShoulder=reach(1, (0.25, 0.4, -2.0), direction=(-0.2, -0.3, -0.9)), lShoulder=OVER_KNEES)  # lifted high
perch(case, 4.8, "snap", (-26, 0, 0), neck=(-22, 0, 0),
      rShoulder=reach(1, (FILE_AT[0], FILE_AT[1] + 0.55, FILE_AT[2]), direction=(-0.1, -0.85, -0.5)),
      lShoulder=OVER_KNEES)  # CLOSED
perch(case, 5.25, "out", (-20, 0, 0), neck=(-16, 0, 0),
      rShoulder=reach(1, (FILE_AT[0] + 0.1, FILE_AT[1] + 0.6, FILE_AT[2]), direction=(-0.1, -0.8, -0.55)),
      lShoulder=OVER_KNEES)
perch(case, 5.75, "smooth", (-16, -8, 0), neck=(-14, -12, 0),
      rShoulder=reach(1, (BOWL_AT[0], BOWL_AT[1] + 0.5, BOWL_AT[2]), direction=(0.2, -0.75, -0.6)),
      lShoulder=OVER_KNEES)  # into the bowl
perch(case, 6.5, "sine", (-12, 2, 0), neck=(0, 6, 0), rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)  # to the lip
perch(case, 8.0, "smooth", (-11, 2, 0), neck=(2, 8, 2), rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
case.follow("neck", 2.2, 0.75).follow(("rShoulder", "lShoulder"), 3.0, 0.7)
case.build()


# Checkmate (winCheckmate) -------------------------------------------------------------------------------------
# Hands behind the back, still (0-2.0); three steps up to the king (2.0-3.4, to z -3.6); one finger to its side and a
# push (3.5-4.2); back a step, hands behind again, watching it fall and shatter; the chin up to the end.
BEHIND_R, BEHIND_L = J((-22, 0, 14), (0.0, 0.0, 0.18)), J((-22, 0, -14), (0.0, 0.0, 0.18))
UP_TO = -3.6
TOUCH = reach(1, (0.25, 1.15, -2.2), direction=(-0.1, 0.05, -1.0))  # one finger on the king's side
PUSH = reach(1, (0.2, 1.15, -2.45), direction=(-0.1, 0.05, -1.0))


def board_upper(t, k):
    return dict(root=(-1, 1.5 * (1 if k % 2 else -1), 0), neck=(-2, 0, 0), rShoulder=BEHIND_R, lShoulder=BEHIND_L)


mate = Motion("winCheckmate", LENGTH, note="Checkmate: up to the giant black king, one finger, a push; it falls and "
              "shatters while the white pieces light up.", unwrap=True, floor=True)
mate.key(0.0, "smooth", offset=(0, 0, 0), root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=BEHIND_R, lShoulder=BEHIND_L,
         **STAND)
mate.key(1.4, "sine", offset=(0, 0, 0), root=(0, 0, 0), neck=(2, 0, 0), rShoulder=BEHIND_R, lShoulder=BEHIND_L,
         **STAND)  # the eyes up to the king
walk(mate, 2.0, 3.4, 0.0, UP_TO, 3, board_upper)
mate.key(3.75, "smooth", offset=(0, 0, UP_TO), root=(-2, 0, 0), neck=(4, 0, 0), rShoulder=TOUCH, lShoulder=BEHIND_L,
         **STAND)
mate.key(3.95, "sine", offset=(0, 0, UP_TO), root=(-2, 0, 0), neck=(4, 0, 0), rShoulder=TOUCH, lShoulder=BEHIND_L,
         **STAND)
mate.key(4.15, "out", offset=(0, 0, UP_TO - 0.05), root=(-5, 0, 0), neck=(2, 0, 0), rShoulder=PUSH,
         lShoulder=BEHIND_L, **STAND)  # the push
mate.key(4.6, "smooth", offset=(0, 0, UP_TO), root=(0, 0, 0), neck=(6, 0, 0), rShoulder=BEHIND_R,
         lShoulder=BEHIND_L, **STAND)
walk(mate, 4.9, 5.4, UP_TO, UP_TO + 1.0, 1, board_upper)  # a step back
for t, neck, shift in ((6.0, (10, 0, 0), 0.0), (6.8, (8, -8, 0), 0.05), (8.0, (12, -14, 2), -0.03)):
    # watching it fall, then towards us; the weight easing from foot to foot (a held body never freezes)
    mate.key(t, "sine", offset=(shift, 0, UP_TO + 1.0), root=(2, 0, -30 * shift), neck=neck, rShoulder=BEHIND_R,
             lShoulder=BEHIND_L, **STAND)
mate.follow("neck", 2.0, 0.8).follow(("rShoulder", "lShoulder"), 3.0, 0.75)
mate.build()



# The Final Page, for the Bureau (winFinalPageBureau) ---------------------------------------------------------
# Standing at the archive's table (its near edge 0.8 ahead, the top 2.75 high: torso frame y -0.25), the open Manual
# before it (its middle 1.75 ahead). Reading (0-1.6); the last page torn out (2.3-2.45); a match from the box, struck
# (2.6-3.05) and put to the page's corner (3.45); the page held up burning, watched (3.6-5.0); the book shut (5.55)
# and pressed into the evidence bag, sealed (6.0-6.5); straightening into the light.
LEAN = dict(rHip=J((14, 0, 1)), lHip=J((14, 0, -1)))  # (the hips back a little: leaning over the table)
PALM_L = reach(-1, (-1.15, -0.05, -1.55), direction=(0.15, -0.6, -0.8))  # the left hand flat on the table
PAGE_R = reach(1, (0.75, 0.1, -2.05), direction=(-0.2, -0.55, -0.8))  # the right hand on the last page's corner
TORN = reach(1, (0.75, 0.75, -1.15), direction=(-0.25, 0.35, -0.9))  # the page up off the book
SHOWN = reach(1, (0.35, 1.0, -1.25), direction=(-0.3, 0.55, -0.75))  # held up before the face, burning
BOX_L = reach(-1, (-1.25, -0.05, -1.25), direction=(0.2, -0.55, -0.8))  # the matchbox on the table
STRIKE_L = reach(-1, (-0.75, 0.35, -1.2), direction=(0.35, 0.05, -0.9))
TO_PAGE = reach(-1, (0.05, 0.6, -1.2), direction=(0.55, 0.25, -0.75))  # the match to the page's lower corner
BOOK_R = reach(1, (0.55, 0.1, -1.75), direction=(-0.25, -0.55, -0.8))
SHUT_R = reach(1, (-0.15, 0.15, -1.75), direction=(-0.45, -0.55, -0.7))
PRESS_R = reach(1, (0.25, 0.05, -1.75), direction=(-0.2, -0.65, -0.75))
PRESS_L = reach(-1, (-0.25, 0.05, -1.75), direction=(0.2, -0.65, -0.75))
SIDE_R, SIDE_L = J((4, 0, 5)), J((4, 0, -5))

final = Motion("winFinalPageBureau", LENGTH, note="The Final Page, for the Bureau: at the archive's table at dawn, "
               "the Manual's last page torn out and burned, the book sealed in an evidence bag.", unwrap=True,
               floor=True)
for t, neck, root in ((0.0, (-34, 0, 0), (-12, 0, 0)), (0.9, (-36, -4, 0), (-12, -2, 0)),
                      (1.6, (-33, 4, 0), (-13, 1, 0))):  # reading the last page
    final.key(t, "sine", offset=(0, 0, 0), root=root, neck=neck, rShoulder=SIDE_R, lShoulder=PALM_L, **LEAN)
final.key(2.1, "smooth", offset=(0, 0, 0), root=(-16, 4, 0), neck=(-30, 6, 0), rShoulder=PAGE_R, lShoulder=PALM_L,
          **LEAN)
final.key(2.3, "in", offset=(0, 0, 0), root=(-15, 4, 0), neck=(-28, 6, 0), rShoulder=PAGE_R, lShoulder=PALM_L,
          **LEAN)  # a grip on it
final.key(2.45, "snap", offset=(0, 0.02, 0.05), root=(-6, -2, 0), neck=(-14, 2, 0), rShoulder=TORN,
          lShoulder=PALM_L, **LEAN)  # torn out
final.key(2.7, "out", offset=(0, 0, 0), root=(-8, -6, 0), neck=(-18, -10, 0), rShoulder=TORN, lShoulder=BOX_L, **LEAN)
final.key(2.95, "smooth", offset=(0, 0, 0), root=(-6, -3, 0), neck=(-10, -4, 0), rShoulder=TORN, lShoulder=STRIKE_L,
          **LEAN)
final.key(3.05, "snap", offset=(0, 0, 0), root=(-6, -3, 0), neck=(-10, -2, 0), rShoulder=TORN,
          lShoulder=reach(-1, (-0.45, 0.55, -1.3), direction=(0.5, 0.2, -0.8)), **LEAN)  # struck
final.key(3.45, "smooth", offset=(0, 0, 0), root=(-4, 0, 0), neck=(-4, 2, 0), rShoulder=SHOWN, lShoulder=TO_PAGE,
          **LEAN)  # it catches
final.key(3.75, "out", offset=(0, 0, 0), root=(-3, 0, 0), neck=(-2, 2, 0), rShoulder=SHOWN,
          lShoulder=reach(-1, (-0.9, -0.2, -0.9), direction=(0.2, -0.8, -0.5)), **LEAN)  # the match shaken out
for t, neck in ((4.3, (2, 4, 0)), (5.0, (0, -2, 0))):  # watching it burn down to the fingers
    final.key(t, "sine", offset=(0, 0, 0), root=(-2, 0, 0), neck=neck, rShoulder=SHOWN, lShoulder=SIDE_L, **LEAN)
final.key(5.2, "out", offset=(0, 0, 0), root=(-8, 0, 0), neck=(-16, 0, 0),
          rShoulder=reach(1, (0.7, 0.4, -1.2), direction=(-0.2, -0.3, -0.9)), lShoulder=SIDE_L, **LEAN)  # let go
final.key(5.4, "smooth", offset=(0, 0, 0), root=(-14, 0, 0), neck=(-28, 0, 0), rShoulder=BOOK_R, lShoulder=PALM_L,
          **LEAN)
final.key(5.55, "snap", offset=(0, 0, 0), root=(-15, -2, 0), neck=(-30, -2, 0), rShoulder=SHUT_R, lShoulder=PALM_L,
          **LEAN)  # shut
final.key(6.0, "smooth", offset=(0, 0, 0), root=(-16, 0, 0), neck=(-30, 0, 0), rShoulder=PRESS_R, lShoulder=PRESS_L,
          **LEAN)  # into the bag
final.key(6.45, "in", offset=(0, -0.02, 0), root=(-17, 0, 0), neck=(-32, 0, 0),
          rShoulder=reach(1, (0.3, -0.02, -1.75), direction=(-0.2, -0.7, -0.7)),
          lShoulder=reach(-1, (-0.3, -0.02, -1.75), direction=(0.2, -0.7, -0.7)), **LEAN)  # sealed
final.key(7.0, "sine", offset=(0, 0, 0.1), root=(0, 0, 0), neck=(4, 0, 0), rShoulder=SIDE_R, lShoulder=SIDE_L,
          **STAND)  # straightening, the face up into the light
final.key(8.0, "smooth", offset=(0, 0, 0.12), root=(1, 2, 0), neck=(8, 4, 0), rShoulder=SIDE_R, lShoulder=SIDE_L,
          **STAND)
final.follow("neck", 2.4, 0.75).follow(("rShoulder", "lShoulder"), 2.8, 0.72)
final.build()


# God of the New World, for the Bureau (winNewWorldBureau) -----------------------------------------------------
# From the portico two steps down to the top step's edge (0.3-1.4) with the Manual shut at the left side; the book
# taken into the right hand before the chest (2.0-2.5); raised high over the head (2.8-3.55) as the screens across the
# square show the news and the press's cameras go off; turned to one side and the other with it up (3.6-6.0); brought
# down to the chest, held there, the chin up (6.3-8.0).
STEPS_FROM, STEPS_TO = 1.6, 0.25
HIGH = J((172, 0, 8), (0.0, 0.05, 0.0))  # the right arm straight up
CHEST_R = reach(1, (0.15, 0.25, -1.1), direction=(-0.6, 0.0, -0.8))
CHEST_L = reach(-1, (-0.2, 0.0, -1.1), direction=(0.6, -0.2, -0.75))


def steps_upper(t, k):
    swing = 9 * (1 if k % 2 else -1)
    return dict(root=(-1, 2 * (1 if k % 2 else -1), 0), neck=(-8, 0, 0), rShoulder=J((swing, 0, 4)),
                lShoulder=BOOK_DOWN)


court = Motion("winNewWorldBureau", LENGTH, note="God of the New World, for the Bureau: down to the courthouse's top "
               "step with the Manual, raised high over the press as the news breaks.", unwrap=True, floor=True)
court.key(0.0, "smooth", offset=(0, 0, STEPS_FROM), root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=J((0, 0, 3)),
          lShoulder=BOOK_DOWN, **STAND)
walk(court, 0.3, 1.4, STEPS_FROM, STEPS_TO, 2, steps_upper)
court.key(1.9, "sine", offset=(0, 0, STEPS_TO), root=(-2, 0, 0), neck=(-14, -4, 0), rShoulder=J((0, 0, 3)),
          lShoulder=BOOK_DOWN, **STAND)  # looking down on them
court.key(2.25, "smooth", offset=(0, 0, STEPS_TO), root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=CHEST_R,
          lShoulder=CHEST_L, **STAND)  # the book to the right hand
court.key(2.55, "in", offset=(0, -0.03, STEPS_TO), root=(-4, 0, 0), neck=(-4, 0, 0),
          rShoulder=reach(1, (0.7, 0.5, -0.9), direction=(-0.2, 0.4, -0.9)), lShoulder=J((4, 0, -6)), **STAND)
court.key(3.3, "out", offset=(0, 0.06, STEPS_TO), root=(6, 0, 0), neck=(14, 0, 0), rShoulder=HIGH,
          lShoulder=J((20, 0, -26)), **STAND)  # raised
court.key(3.55, "sine", offset=(0, 0.07, STEPS_TO), root=(7, 0, 0), neck=(16, 0, 0),
          rShoulder=J((176, 0, 6), (0.0, 0.06, 0.0)), lShoulder=J((22, 0, -30)), **STAND)
for t, yaw in ((4.4, 12), (5.3, -10), (6.0, 2)):  # turned to one side of the press and the other
    court.key(t, "sine", offset=(0, 0.06, STEPS_TO), root=(6, yaw, 0), neck=(12, yaw * 0.6, 0), rShoulder=HIGH,
              lShoulder=J((18, 0, -26)), **STAND)
court.key(6.6, "smooth", offset=(0, 0.02, STEPS_TO), root=(2, 0, 0), neck=(6, 0, 0), rShoulder=CHEST_R,
          lShoulder=J((4, 0, -6)), **STAND)  # down to the chest
court.key(7.3, "sine", offset=(0, 0.02, STEPS_TO), root=(3, 2, 0), neck=(10, 2, 0), rShoulder=CHEST_R,
          lShoulder=J((4, 0, -6)), **STAND)
court.key(8.0, "smooth", offset=(0, 0.03, STEPS_TO), root=(3, 0, 0), neck=(12, 0, 0), rShoulder=CHEST_R,
          lShoulder=J((4, 0, -6)), **STAND)
court.follow("neck", 2.4, 0.75).follow(("rShoulder", "lShoulder"), 2.6, 0.72)
court.build()


# Case Closed, for the Coven (winCaseClosedCoven) --------------------------------------------------------------
# Sat back in the detective's armchair (its cushion 2.0 high) before the fire, the case file held up in the right
# hand and read (0-2.0); shut, a look at the fire (2.0-2.6); thrown on it (3.2); laughing as the flames reach the
# string wall (3.8-6.0); the fingers steepled, watching it burn (6.3-8.0).
CHAIR_SIT = dict(rHip=J((80, 0, 4), (0, 0.05, 0)), lHip=J((80, 0, -4), (0, 0.05, 0)))
FILE_UP = reach(1, (0.35, 0.45, -1.2), direction=(-0.35, 0.4, -0.85))  # the file held up to read
TURN_L = reach(-1, (-0.15, 0.4, -1.25), direction=(0.55, 0.3, -0.8))  # the left hand turning its pages
REST_R = reach(1, (1.35, -0.75, -0.6), direction=(0.05, -0.9, -0.45))  # the hands on the armrests
REST_L = reach(-1, (-1.35, -0.75, -0.6), direction=(-0.05, -0.9, -0.45))
STEEPLE_R = reach(1, (0.08, 0.35, -1.0), direction=(-0.7, 0.35, -0.6))
STEEPLE_L = reach(-1, (-0.08, 0.35, -1.0), direction=(0.7, 0.35, -0.6))


def chair(m, t, ease, root, back=0.0, **joints):
    pose = dict(root=J(root), **CHAIR_SIT)
    ox, oy, oz = posekit.on_seat(pose, (0.0, 0.0, 0.7 + back), seat=2.0)
    m.key(round(t, 4), ease, offset=(ox, oy, oz), root=root, **CHAIR_SIT, **joints)


den = Motion("winCaseClosedCoven", LENGTH, note="Case Closed, for the Coven: in the detective's armchair, the case "
             "file read and thrown on the fire, laughing as the string wall burns.", unwrap=True)
for t, neck in ((0.0, (-10, 0, 0)), (0.8, (-12, -4, 0)), (1.5, (-9, 3, 0))):  # reading it, unhurried
    chair(den, t, "sine", (8, 0, 0), neck=neck, rShoulder=FILE_UP, lShoulder=TURN_L)
chair(den, 2.0, "smooth", (8, 0, 0), neck=(-4, 0, 0), rShoulder=FILE_UP, lShoulder=REST_L)  # shut
chair(den, 2.55, "sine", (6, -6, 0), neck=(-2, -8, 0), rShoulder=FILE_UP, lShoulder=REST_L)  # a look at the fire
chair(den, 2.95, "in", (12, 8, 0), neck=(0, -2, 0),
      rShoulder=reach(1, (1.3, 0.9, -0.2), direction=(0.3, 0.5, -0.8)), lShoulder=REST_L)  # drawn back
chair(den, 3.2, "snap", (-4, -6, 0), neck=(-6, -4, 0),
      rShoulder=reach(1, (0.5, 0.35, -1.9), direction=(-0.15, 0.1, -1.0)), lShoulder=REST_L)  # thrown
chair(den, 3.55, "out", (0, -2, 0), neck=(-4, 0, 0), rShoulder=reach(1, (0.8, 0.1, -1.6), direction=(0, -0.4, -0.9)),
      lShoulder=REST_L)
for t, root, neck in ((4.0, (14, 0, 0), (18, 0, 0)), (4.35, (10, 0, 0), (10, 0, 0)), (4.7, (16, 0, 0), (22, 0, 0)),
                      (5.05, (11, 0, 0), (12, 0, 0)), (5.45, (17, 0, 0), (24, 2, 0)), (6.0, (12, 0, 0), (8, 0, 0))):
    # the laugh: thrown back, shaking, the hands on the armrests
    chair(den, t, "sine", root, back=0.05, neck=neck, rShoulder=REST_R, lShoulder=REST_L)
chair(den, 6.5, "smooth", (4, 0, 0), neck=(-8, 0, 0), rShoulder=STEEPLE_R, lShoulder=STEEPLE_L)  # fingers steepled
chair(den, 7.3, "sine", (3, 0, 0), neck=(-10, 2, 0), rShoulder=STEEPLE_R, lShoulder=STEEPLE_L)
chair(den, 8.0, "smooth", (3, 0, 0), neck=(-9, 0, 0), rShoulder=STEEPLE_R, lShoulder=STEEPLE_L)
den.follow("neck", 2.6, 0.72).follow(("rShoulder", "lShoulder"), 2.8, 0.72)
den.build()


# Checkmate, for the Coven (winCheckmateCoven) -----------------------------------------------------------------
# At the crate by the roof's edge in the rain, the hands behind the back, looking down at the board (0-1.6); leaning
# in, one finger to the white king (2.1-2.55) and a flick (2.7) that sends it over the parapet; watching it fall
# (2.8-5.0); the head thrown back in the lightning (5.4), turned away from the edge, walking off (6.4-8.0).
KING_AT = (0.3, -0.3, -2.0)  # the white king's middle on the board, torso frame
ON_KING = reach(1, (KING_AT[0] + 0.05, KING_AT[1] + 0.1, KING_AT[2] + 0.35), direction=(-0.1, -0.2, -1.0))
FLICK = reach(1, (KING_AT[0] - 0.05, KING_AT[1] + 0.15, KING_AT[2] - 0.15), direction=(-0.1, -0.1, -1.0))


def leave_upper(t, k):
    return dict(root=(0, 180 + 1.5 * (1 if k % 2 else -1), 0), neck=(0, 0, 0), rShoulder=BEHIND_R,
                lShoulder=BEHIND_L)


roof = Motion("winCheckmateCoven", LENGTH, note="Checkmate, for the Coven: at a crate on a roof's edge in the rain, "
              "the white king flicked over the parapet, watched all the way down.", unwrap=True, floor=True)
roof.key(0.0, "smooth", offset=(0, 0, 0), root=(-4, 0, 0), neck=(-30, 0, 0), rShoulder=BEHIND_R, lShoulder=BEHIND_L,
         **STAND)
roof.key(1.6, "sine", offset=(0, 0, 0), root=(-5, 2, 0), neck=(-32, 4, 0), rShoulder=BEHIND_R, lShoulder=BEHIND_L,
         **STAND)
roof.key(2.1, "smooth", offset=(0, 0, -0.1), root=(-16, 0, 0), neck=(-24, 0, 0),
         rShoulder=reach(1, (0.8, 0.2, -1.6), direction=(-0.1, -0.3, -0.95)), lShoulder=BEHIND_L, **LEAN)
roof.key(2.55, "sine", offset=(0, 0, -0.1), root=(-18, 0, 0), neck=(-26, 2, 0), rShoulder=ON_KING,
         lShoulder=BEHIND_L, **LEAN)  # one finger to it
roof.key(2.7, "snap", offset=(0, 0, -0.12), root=(-19, 0, 0), neck=(-26, 0, 0), rShoulder=FLICK, lShoulder=BEHIND_L,
         **LEAN)  # the flick
roof.key(3.1, "out", offset=(0, 0, -0.1), root=(-14, 0, 0), neck=(-36, 0, 0), rShoulder=BEHIND_R,
         lShoulder=BEHIND_L, **LEAN)
for t, neck in ((3.9, (-44, 2, 0)), (4.7, (-48, -2, 0))):  # down after it, all the way
    roof.key(t, "sine", offset=(0, 0, -0.1), root=(-12, 0, 0), neck=neck, rShoulder=BEHIND_R, lShoulder=BEHIND_L,
             **LEAN)
roof.key(5.4, "out", offset=(0, 0.04, 0), root=(10, 0, 0), neck=(26, 0, 0), rShoulder=J((-10, 0, 18)),
         lShoulder=J((-10, 0, -18)), **STAND)  # the head thrown back in the lightning
roof.key(6.0, "sine", offset=(0, 0, 0), root=(6, 60, 0), neck=(10, 10, 0), rShoulder=BEHIND_R, lShoulder=BEHIND_L,
         **STAND)
roof.key(6.4, "smooth", offset=(0, 0, 0.1), root=(0, 180, 0), neck=(-2, 0, 0), rShoulder=BEHIND_R,
         lShoulder=BEHIND_L, **STAND)  # turned from the edge
walk(roof, 6.5, 8.0, 0.1, 2.3, 3, leave_upper)
roof.follow("neck", 2.2, 0.75).follow(("rShoulder", "lShoulder"), 2.8, 0.72)
roof.build()

WINS = ("winFinalPage", "winNewWorld", "winCaseClosed", "winCheckmate", "winFinalPageBureau", "winNewWorldBureau",
        "winCaseClosedCoven", "winCheckmateCoven")
