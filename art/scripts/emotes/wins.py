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
"""

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

WINS = ("winFinalPage", "winNewWorld", "winCaseClosed", "winCheckmate")
