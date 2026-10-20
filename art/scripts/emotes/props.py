"""Emotes with props, each copied from its reference (art/refs/emotes/<clip>.toml). The props' holds in
src/shared/Anim/EmoteMeta.luau are solved from the key poses here (kit.hold), so the fist and the prop meet
where the reference has them; check_props.py measures every contact the meta names."""

import math

import posekit
from animlib import J
from emotes.kit import reach
from motion import Motion

REST = dict(root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))

# Diavolo's Potato Chip (clip chipAndPen, item emote_chip_and_pen) ---------------------------------------
# Death Note, episode 8 ("Glare"): under L's cameras Light studies at his desk, and in the bag of crisps on it is a
# torn page and a tiny TV. He writes a name through the bag's mouth, takes a crisp, raises it slowly ("I'll take
# a potato chip...") and bites it with a flourish ("...and eat it!"). (refs: chipAndPen.toml.)
# Rebuilt as a scene (owner's note, 2026-10-17: the bag must not come from nowhere; a table and a chair fall out
# of the sky, a radio on the right, a normal notebook and the bag on the left; more dramatic, fluid):
#   0.25 he looks up; the table lands in front of him (1.0), the chair behind (1.25), the radio, the notebook with
#   the pen on it and the bag on the table (1.5-1.7); he sits (1.95-2.65); takes the pen (2.85) and the bag
#   (3.05); writes into the bag's mouth (3.3-4.55); puts the pen back (4.75); a hand into the bag, a crisp
#   (5.0-5.3), raised slowly beside the face and held (5.3-6.95); and eat it (7.05); chews, sets the bag down
#   (8.0), stands (8.4-9.0) and watches it all sink into the ink (9.1-10.2).
# Places, in the floor's frame under the body (forward -z): the table's middle 2.05 ahead (its top 2.75 high), the
# chair 1.4 behind (its seat 1.75 high). Seated, the torso's middle is 2.75 up and 0.75 back, so the table top is
# at the torso frame's y = 0 and the torso frame is the floor frame moved (0, 2.75, 0.75).
SEAT = (0, -0.25, 0.75)
TOP = 0.0  # the table top, torso frame (seated)
SIT_LEG_R, SIT_LEG_L = J((84, 0, 3), (0, 0.05, 0)), J((84, 0, -3), (0, 0.05, 0))
STAND_LEG_R, STAND_LEG_L = J((0, 0, 1)), J((0, 0, -1))
ON_TABLE_R = reach(1, (0.95, TOP + 0.55, -1.45), direction=(-0.1, -0.15, -1.0))
ON_TABLE_L = reach(-1, (-0.95, TOP + 0.55, -1.45), direction=(0.1, -0.15, -1.0))
PEN_PICK = reach(1, (0.05, TOP + 0.5, -1.6), direction=(-0.35, -0.2, -1.0))  # the pen off the notebook
BAG_PICK = reach(-1, (-1.5, TOP + 0.8, -1.7), direction=(-0.2, -0.1, -1.0))  # the bag off the table
BAG_HOLD = reach(-1, (-0.65, TOP + 0.65, -1.35), direction=(0.3, -0.25, -1.0))  # held up at the table's edge
PEN_AT, PEN_DIR = (-0.42, TOP + 1.4, -1.4), (-0.45, -0.25, -1.0)  # writing through the bag's mouth
IN_BAG = (-0.55, TOP + 1.2, -1.35)
RAISE_AT, RAISE_DIR = (0.95, 1.75, -0.9), (0.15, 0.75, -0.55)
BITE_AT, BITE_DIR = (0.05, 1.0, -0.58), (-0.55, 0.55, -0.6)

chip = Motion("chipAndPen", 10.4, note="The potato chip: the desk falls from the sky, he sits, writes into the bag, raises a crisp slowly and eats it; it all sinks into ink.", unwrap=True)
standing = dict(rHip=STAND_LEG_R, lHip=STAND_LEG_L)
seated = dict(rHip=SIT_LEG_R, lHip=SIT_LEG_L)
chip.key(0.0, **REST, **standing)
chip.key(0.3, "sine", root=(3, 0, 0), neck=(24, 0, 0), rShoulder=J((0, 0, 4)), lShoulder=J((0, 0, -4)), **standing)
chip.key(0.9, "in", root=(0, 0, 0), neck=(-8, 0, 0), rShoulder=J((0, 0, 4)), lShoulder=J((0, 0, -4)), **standing)
chip.key(1.02, "snap", offset=(0, -0.06, 0), root=(-3, 0, 0), neck=(-12, 0, 0),  # the thud: a flinch
         rShoulder=J((4, 0, 9), (0, 0.12, 0)), lShoulder=J((4, 0, -9), (0, 0.12, 0)), **standing)
chip.key(1.3, "sine", offset=(0, 0, 0.1), root=(0, 8, 0), neck=(-4, 58, 0),  # a glance back at the chair
         rShoulder=J((0, 0, 4)), lShoulder=J((0, 0, -4)), **standing)
chip.key(1.7, "sine", root=(0, 2, 0), neck=(-14, 2, 0), rShoulder=J((0, 0, 4)), lShoulder=J((0, 0, -4)), **standing)
chip.key(1.95, offset=(0, 0, 0), root=(-2, 0, 0), neck=(-12, 0, 0), rShoulder=J((0, 0, 4)), lShoulder=J((0, 0, -4)),
         **standing)
# down into the chair: the knees forward first (so the legs clear the seat's edge), then the hips back
chip.key(2.12, "sine", offset=(0, 0.06, 0.12), root=(-10, 0, 0), neck=(-6, 0, 0), rShoulder=J((14, 0, 6)),
         lShoulder=J((14, 0, -6)), rHip=J((40, 0, 3), (0, 0.02, 0)), lHip=J((40, 0, -3), (0, 0.02, 0)))
chip.key(2.3, "sine", offset=(0, 0.04, 0.66), root=(-16, 0, 0), neck=(-2, 0, 0), rShoulder=J((24, 0, 8)),
         lShoulder=J((24, 0, -8)), rHip=J((46, 0, 3), (0, 0.04, 0)), lHip=J((46, 0, -3), (0, 0.04, 0)))
chip.key(2.65, "out", offset=SEAT, root=(-4, 0, 0), neck=(-10, 0, 0), rShoulder=ON_TABLE_R, lShoulder=ON_TABLE_L,
         **seated)
chip.key(2.85, "sine", offset=SEAT, root=(-6, -4, 0), neck=(-18, -6, 0), rShoulder=PEN_PICK, lShoulder=ON_TABLE_L,
         **seated)
chip.key(3.05, "sine", offset=SEAT, root=(-6, 6, 0), neck=(-16, 14, 0), rShoulder=reach(1, (0.55, TOP + 0.6, -1.3)),
         lShoulder=BAG_PICK, **seated)
chip.key(3.3, "sine", offset=SEAT, root=(-6, 0, 0), neck=(-20, 4, 0), rShoulder=reach(1, PEN_AT, direction=PEN_DIR),
         lShoulder=BAG_HOLD, **seated)
for i in range(11):  # the scribble through the bag's mouth: quick strokes side to side
    t = 3.4 + 0.105 * i
    dx = (0.07, -0.06, 0.05, -0.07, 0.06, -0.05, 0.07, -0.06, 0.04, -0.03, 0.02)[i]
    dy = (0.02, -0.01, 0.02, 0.0, -0.02, 0.02, 0.0, -0.02, 0.01, 0.0, 0.0)[i]
    chip.key(t, "linear", offset=SEAT, root=(-6, 0, 0), neck=(-20, 4 + dx * 20, 0), lShoulder=BAG_HOLD,
             rShoulder=reach(1, (PEN_AT[0] + dx, PEN_AT[1] + dy, PEN_AT[2]), direction=PEN_DIR), **seated)
chip.key(4.75, "sine", offset=SEAT, root=(-6, -3, 0), neck=(-18, -6, 0), rShoulder=PEN_PICK, lShoulder=BAG_HOLD,
         **seated)  # the pen back on the notebook
chip.key(5.0, "sine", offset=SEAT, root=(-5, 0, 0), neck=(-18, 2, 0), lShoulder=BAG_HOLD,
         rShoulder=reach(1, IN_BAG, direction=(-0.35, -0.45, -1.0)), **seated)  # a hand into the bag
chip.key(5.3, "sine", offset=SEAT, root=(-3, -2, 0), neck=(-8, -4, 0), lShoulder=BAG_HOLD,
         rShoulder=reach(1, (0.15, 1.0, -1.1), direction=(-0.2, 0.2, -1.0)), **seated)  # a crisp out
# raised slowly beside the face, the elbow out, the eyes on it; held
chip.key(6.5, "sine", offset=SEAT, root=(2, -6, 0), neck=(12, -16, 0), lShoulder=BAG_HOLD,
         rShoulder=reach(1, RAISE_AT, direction=RAISE_DIR), **seated)
chip.key(6.95, offset=SEAT, root=(2, -7, 0), neck=(13, -18, 0), lShoulder=BAG_HOLD,
         rShoulder=reach(1, (RAISE_AT[0] + 0.02, RAISE_AT[1] + 0.04, RAISE_AT[2]), direction=RAISE_DIR), **seated)
# and eat it: snapped to the mouth, the head meeting it
chip.key(7.05, "snap", offset=SEAT, root=(-3, -4, 0), neck=(-6, -6, 0), lShoulder=BAG_HOLD,
         rShoulder=reach(1, BITE_AT, direction=BITE_DIR), **seated)
chip.key(7.2, "out", offset=SEAT, root=(-3, -3, 0), neck=(-8, -3, 0), lShoulder=BAG_HOLD,
         rShoulder=reach(1, (0.85, 1.35, -0.95)), **seated)
for i, t in enumerate((7.45, 7.65, 7.85)):  # chewing, the eyes front
    chip.key(t, "sine", offset=SEAT, root=(-2, -2, 0), neck=(-3 if i % 2 == 0 else -8, -2, 0), lShoulder=BAG_HOLD,
             rShoulder=ON_TABLE_R, **seated)
chip.key(8.05, "sine", offset=SEAT, root=(-5, 6, 0), neck=(-14, 10, 0), lShoulder=BAG_PICK, rShoulder=ON_TABLE_R,
         **seated)  # the bag set back down
chip.key(8.35, "sine", offset=SEAT, root=(-4, 0, 0), neck=(-10, 0, 0), rShoulder=ON_TABLE_R, lShoulder=ON_TABLE_L,
         **seated)
# up out of the chair, and watching it all sink
chip.key(8.7, "sine", offset=(0, 0.04, 0.66), root=(-16, 0, 0), neck=(-4, 0, 0), rShoulder=J((24, 0, 8)),
         lShoulder=J((24, 0, -8)), rHip=J((46, 0, 3), (0, 0.04, 0)), lHip=J((46, 0, -3), (0, 0.04, 0)))
chip.key(8.88, "sine", offset=(0, 0.06, 0.12), root=(-10, 0, 0), neck=(-12, 0, 0), rShoulder=J((14, 0, 6)),
         lShoulder=J((14, 0, -6)), rHip=J((40, 0, 3), (0, 0.02, 0)), lHip=J((40, 0, -3), (0, 0.02, 0)))
chip.key(9.05, "out", offset=(0, 0, 0), root=(-4, 0, 0), neck=(-22, 0, 0), rShoulder=J((2, 0, 5)),
         lShoulder=J((2, 0, -5)), **standing)
chip.key(9.9, "sine", root=(-3, 0, 0), neck=(-26, 0, 0), rShoulder=J((2, 0, 5)), lShoulder=J((2, 0, -5)), **standing)
chip.key(10.4, "sine", **REST, **standing)
chip.follow("neck", 3.0, 0.75).follow(("lShoulder",), 3.0, 0.8)
chip.build()

# S12 (2026-10-21): the prop emotes, each rebuilt from its reference (art/refs/emotes/<clip>.toml). ------------
HANG_R, HANG_L = J((2, 0, 4)), J((2, 0, -4))
POCKET_R, POCKET_L = J((10, 0, -4), (-0.08, 0.12, -0.02)), J((10, 0, 4), (0.08, 0.12, -0.02))
CROUCH_R, CROUCH_L = J((80, 0, 5)), J((80, 0, -5))  # the R6 crouch: the legs out in front (the owner's drawing)


def _low(m, t, ease, root, rise=0.0, x=0.0, z=0.0, seat=None, legs=None, **joints):
    """A key sat low on the crouch's legs: on the floor (posekit.on_floor), or on a seat `seat` studs high."""
    rl, ll = legs or (CROUCH_R, CROUCH_L)
    pose = {"root": J(root), "rHip": rl, "lHip": ll}
    if seat is None:
        ox, oy, oz = posekit.on_floor(pose, (x, 0.0, z), floor=0.0)
    else:
        ox, oy, oz = posekit.on_seat(pose, (x, 0.0, z), seat=seat)
    m.key(round(t, 4), ease, offset=(ox, oy + rise, oz), root=root, rHip=rl, lHip=ll, **joints)


THUMB_LIP = reach(1, (0.12, 0.85, -0.85), direction=(-0.45, 0.75, -0.5))
OVER_KNEES = reach(-1, (-0.35, -0.55, -1.5), direction=(0.3, -0.35, -0.9))

# Chair Perch (clip chairPerch, item emote_chair_perch) ---------------------------------------------------------
# L on his chair (Death Note; refs: chairPerch.toml): crouched on the seat the R6 way (the legs out in front along
# it, the torso upright on their back ends, the chair's back behind), hunched, the thumb at the lip, the left arm
# over the knees, rocking a little and breathing, the head tilting as he thinks. A 4 s loop.
SEAT_TOP = 1.745  # the Chair's seat (its shape in emotemeta.SHAPES), the chair 0.15 behind the root
perch = Motion("chairPerch", 4.0, loop=True, note="L crouched on his chair: legs along the seat, thumb at the lip, "
               "rocking, thinking.")
for t, breath, neck, rock in ((0.0, 0.0, (-2, 0, 0), 0.0), (1.0, 1.0, (-1, 4, -4), 1.0), (2.0, 0.0, (-1, 7, -9), 0.0),
                              (3.0, 1.0, (-1, 3, -3), 1.0)):
    _low(perch, t, "sine", (-12 + 2 * breath + 3 * rock, 0, 0), rise=0.02 * breath, z=0.12, seat=SEAT_TOP, neck=neck,
         rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
perch.follow("neck", 1.5, 0.72)
perch.follow(("rShoulder", "lShoulder"), 2.2, 0.7)
perch.build()

# Sugar Tower (clip sugarTower; ADD ONE: sugarTowerAdd, or sugarTowerTopple) -------------------------------------
# L's sugar cube tower (Death Note; refs: sugarTower.toml): crouched the R6 way on the floor, he takes cube after
# cube off the pile by his right hip and sets each on the tower beside his right knee, the last one slowly, the
# head close to it; then the thumb to the lip, admiring it. ADD ONE (pushing his luck) sets a sixth: it holds, or
# the tower comes down.
SUGAR_AT = (1.45, -0.7)  # the tower's foot, floor frame (x right, z back)
PILE = reach(1, (1.75, -1.1, -0.1), direction=(0.2, -0.95, -0.2))  # the right hand at the pile by the hip
SUGAR_TIMES = (1.0, 1.8, 2.6, 3.4, 4.6)


def _tower_top(n):
    """The right fist setting the n-th cube (0 = the first) on the tower: torso frame, crouched."""
    return reach(1, (1.45, -1.25 + 0.42 * n, -0.95), direction=(0.05, -0.9, -0.45))


sugar = Motion("sugarTower", 6.0, note="L's sugar tower: crouched, cube after cube off the pile onto the tower, the "
               "last one slowly.")
_low(sugar, 0.0, "smooth", (-6, 0, 0), neck=(-6, 0, 0), rShoulder=HANG_R, lShoulder=OVER_KNEES)
_low(sugar, 0.45, "smooth", (-14, -6, -6), neck=(-24, -10, 0), rShoulder=PILE, lShoulder=OVER_KNEES)
for i, t in enumerate(SUGAR_TIMES):
    slow = i == len(SUGAR_TIMES) - 1
    _low(sugar, t - (0.7 if slow else 0.5), "smooth", (-14, -6, -6), neck=(-24, -12, 0), rShoulder=PILE,
         lShoulder=OVER_KNEES)  # a cube off the pile
    if slow:  # the last one held a moment over the top, the head right down by it
        _low(sugar, t - 0.25, "smooth", (-20, -10, -8), neck=(-30, -16, -6), rShoulder=_tower_top(i + 0.3),
             lShoulder=OVER_KNEES)
    _low(sugar, t, "sine" if slow else "out", (-18 + i, -8, -8), neck=(-28 + 2 * i, -14, -4 if slow else 0),
         rShoulder=_tower_top(i), lShoulder=OVER_KNEES)
_low(sugar, 5.1, "smooth", (-10, -4, -3), neck=(-12, -10, -6), rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
_low(sugar, 6.0, "smooth", (-10, -4, -3), rise=0.01, neck=(-10, -12, -8), rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
sugar.follow("neck", 2.0, 0.75)
sugar.follow(("rShoulder", "lShoulder"), 3.0, 0.75)
sugar.build()

for clip, falls in (("sugarTowerAdd", False), ("sugarTowerTopple", True)):
    m = Motion(clip, 3.4, note="ADD ONE: a sixth cube on the tower" + (", and it all comes down." if falls else ", and "
               "it holds."))
    _low(m, 0.0, "smooth", (-10, -4, -3), neck=(-10, -12, -8), rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
    _low(m, 0.45, "smooth", (-14, -6, -6), neck=(-24, -12, 0), rShoulder=PILE, lShoulder=OVER_KNEES)
    _low(m, 0.95, "smooth", (-20, -10, -8), neck=(-30, -16, -6), rShoulder=_tower_top(5.3), lShoulder=OVER_KNEES)
    _low(m, 1.3, "sine", (-20, -9, -8), neck=(-30, -15, -6), rShoulder=_tower_top(5), lShoulder=OVER_KNEES)
    if falls:  # the wobble, then it goes: a flinch back, then the slump
        _low(m, 1.55, "smooth", (-16, -8, -6), neck=(-24, -12, -4), rShoulder=_tower_top(5.4), lShoulder=OVER_KNEES)
        _low(m, 1.75, "snap", (-2, -4, 2), neck=(4, -8, 6), rShoulder=J((30, 0, 40)), lShoulder=J((30, 0, -30)))
        _low(m, 2.4, "smooth", (-16, -4, -2), neck=(-30, -6, 0), rShoulder=J((10, 0, 8)), lShoulder=OVER_KNEES)
        _low(m, 3.4, "smooth", (-18, -4, -2), neck=(-34, -6, 4), rShoulder=J((8, 0, 8)), lShoulder=OVER_KNEES)
    else:  # it holds: drawn back slowly, a satisfied tilt
        _low(m, 2.0, "smooth", (-10, -4, -3), neck=(-10, -12, -8), rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
        _low(m, 3.4, "smooth", (-9, -4, -3), rise=0.01, neck=(-6, -12, -12), rShoulder=THUMB_LIP, lShoulder=OVER_KNEES)
    m.follow("neck", 2.0, 0.75)
    m.follow(("rShoulder", "lShoulder"), 3.0, 0.7)
    m.build()

# Dice Tower (clip diceTower; ADD ONE: diceTowerAdd, or diceTowerTopple) -----------------------------------------
# Near's dice tower (Death Note; refs: diceTower.toml): sitting on the floor the R6 way, the legs out in a V, he
# takes die after die off the pile by his right hip and builds a tower between his legs, leaning in to each,
# slower as it grows; then leaning back on a hand to look at it. ADD ONE pushes his luck the same way.
SIT_R, SIT_L = J((88, 0, 14)), J((88, 0, -18))
DICE_TIMES = (0.9, 1.6, 2.3, 3.0, 3.7, 4.6)
DICE_PILE = reach(1, (1.7, -1.05, 0.0), direction=(0.2, -0.95, -0.1))
PROP_BACK = J((-24, 0, -30), (0, -0.14, 0.14))  # the left hand propped on the floor behind


def _dice_top(n):
    return reach(1, (-0.05, -1.45 + 0.42 * n, -1.5), direction=(-0.15, -0.85, -0.5))


def _sat(m, t, ease, root, rise=0.0, **joints):
    _low(m, t, ease, root, rise=rise, z=0.25, legs=(SIT_R, SIT_L), **joints)


dice = Motion("diceTower", 6.0, note="Near's dice tower: sat on the floor, die after die off the pile onto the tower "
              "between his legs.")
_sat(dice, 0.0, "smooth", (-10, 0, 0), neck=(-12, 0, 0), rShoulder=HANG_R, lShoulder=PROP_BACK)
for i, t in enumerate(DICE_TIMES):
    _sat(dice, t - 0.45, "smooth", (-12, 8, 4), neck=(-14 + 2 * i, -10, 0), rShoulder=DICE_PILE, lShoulder=PROP_BACK)
    _sat(dice, t, "sine" if i >= 4 else "out", (-16 - i, 0, 0), neck=(-18 + 3 * i, 2, 0), rShoulder=_dice_top(i),
         lShoulder=PROP_BACK)
_sat(dice, 5.2, "sine", (-2, 6, 0), neck=(0, 8, 6), rShoulder=J((20, 0, 10)), lShoulder=PROP_BACK)
_sat(dice, 6.0, "smooth", (-2, 6, 0), neck=(0, 10, 8), rShoulder=J((20, 0, 10)), lShoulder=PROP_BACK)
dice.follow("neck", 2.0, 0.75)
dice.follow(("rShoulder", "lShoulder"), 3.0, 0.75)
dice.build()

for clip, falls in (("diceTowerAdd", False), ("diceTowerTopple", True)):
    m = Motion(clip, 3.4, note="ADD ONE: a seventh die on the tower" + (", and it all comes down." if falls else ", and "
               "it holds."))
    _sat(m, 0.0, "smooth", (-2, 6, 0), neck=(0, 10, 8), rShoulder=J((20, 0, 10)), lShoulder=PROP_BACK)
    _sat(m, 0.45, "smooth", (-12, 8, 4), neck=(-6, -10, 0), rShoulder=DICE_PILE, lShoulder=PROP_BACK)
    _sat(m, 1.0, "smooth", (-22, 0, 0), neck=(-4, 2, 0), rShoulder=_dice_top(6.3), lShoulder=PROP_BACK)
    _sat(m, 1.3, "sine", (-22, 0, 0), neck=(-4, 2, 0), rShoulder=_dice_top(6), lShoulder=PROP_BACK)
    if falls:
        _sat(m, 1.55, "smooth", (-18, 0, 0), neck=(-2, 2, 0), rShoulder=_dice_top(6.4), lShoulder=PROP_BACK)
        _sat(m, 1.75, "snap", (2, 0, 0), neck=(10, 0, 0), rShoulder=J((40, 0, 40)), lShoulder=PROP_BACK)
        _sat(m, 2.5, "smooth", (-6, 0, 0), neck=(-20, 0, 0), rShoulder=J((10, 0, 8)), lShoulder=PROP_BACK)
        _sat(m, 3.4, "smooth", (-6, 0, 0), neck=(-22, 0, 6), rShoulder=J((8, 0, 8)), lShoulder=PROP_BACK)
    else:
        _sat(m, 2.0, "smooth", (-2, 6, 0), neck=(2, 8, 6), rShoulder=J((20, 0, 10)), lShoulder=PROP_BACK)
        _sat(m, 3.4, "smooth", (-2, 6, 0), rise=0.01, neck=(4, 10, 10), rShoulder=J((20, 0, 10)), lShoulder=PROP_BACK)
    m.follow("neck", 2.0, 0.75)
    m.follow(("rShoulder", "lShoulder"), 3.0, 0.7)
    m.build()

# Furious Scribbling (clip furiousScribbling, a loop; WRITE IT: furiousScribblingSlash) -------------------------
# Light writing names in the Death Note (episode 1's montage; refs: furiousScribbling.toml): the Manual held open on
# the left hand at the chest, tilted up to him, the pen racing along line after line, the head over it, the weight
# rocking with the strokes. WRITE IT writes the last name huge, slashes it across, and snaps the book shut.
BOOK_TILT = 35.0  # the open book tilted up to his face, degrees
_n = (0.0, math.cos(math.radians(BOOK_TILT)), math.sin(math.radians(BOOK_TILT)))  # the page's normal (torso frame)
_down = (0.0, -_n[2], _n[1])  # down the page, towards him
PAGE = (-0.15, 0.25, -1.6)  # the open page's middle, torso frame
BOOK_HAND = reach(-1, (-0.3, -0.25, -1.4), direction=(0.45, -0.35, -0.8))  # the left hand under the book
PEN_UP = 0.8  # the fist this far off the page, the pen reaching down to it


def _pen(x, line, lift=0.0):
    """The right arm with the pen's tip on the page: `x` across it, `line` down it (studs), lifted `lift` off it."""
    h = PEN_UP + lift
    at = tuple(PAGE[i] + x * (1.0, 0.0, 0.0)[i] + line * _down[i] + h * _n[i] for i in range(3))
    return reach(1, at, direction=(-0.35, -0.6, -0.7))


fury = Motion("furiousScribbling", 2.4, loop=True, note="Light writing in the Manual: the pen racing along line "
              "after line, the head over the page.")
for i in range(12):
    t = i * 0.2
    along = (i % 4) / 3  # along the line, then back to the next
    stroke = 1 if i % 2 == 0 else -1
    line = (i // 4) % 3
    fury.key(round(t, 4), "smooth", offset=(0.02 * stroke, -0.03, 0), root=(-8, 4 - 4 * along, 0),
             neck=(-30 + 3 * stroke, 6 - 10 * along, 0), lShoulder=BOOK_HAND,
             rShoulder=_pen(-0.35 + 0.6 * along, -0.3 + 0.2 * line, 0.03 * (1 + stroke)))
fury.follow("neck", 4.0, 0.6)
fury.follow("rShoulder", 7.0, 0.55)
fury.follow("lShoulder", 2.0, 0.85)
fury.plant(stance=0.08)
fury.build()

slash = Motion("furiousScribblingSlash", 2.4, note="WRITE IT: the last name written huge, slashed across, the book "
               "snapped shut.")
slash.key(0.0, "smooth", offset=(0, -0.03, 0), root=(-8, 4, 0), neck=(-30, 6, 0), lShoulder=BOOK_HAND,
          rShoulder=_pen(-0.35, -0.3, 0.06))
for i, (x, line) in enumerate(((-0.4, 0.1), (-0.15, -0.25), (0.1, 0.15), (0.3, -0.2))):  # the name, big letters
    slash.key(round(0.2 + 0.18 * i, 4), "smooth", offset=(0, -0.04, 0), root=(-10, 6 - 4 * i, 0),
              neck=(-32, 8 - 6 * i, 0), lShoulder=BOOK_HAND, rShoulder=_pen(x, line))
slash.key(1.05, "in", offset=(0.04, -0.02, 0), root=(-4, -10, 0), neck=(-20, -10, 0), lShoulder=BOOK_HAND,
          rShoulder=_pen(0.55, -0.45, 0.35))  # drawn back, up off the page
slash.key(1.2, "snap", offset=(-0.04, -0.08, 0), root=(-12, 14, 0), neck=(-30, 10, 0), lShoulder=BOOK_HAND,
          rShoulder=_pen(-0.45, 0.25, 0.08))  # SLASHED across
slash.key(1.6, "out", offset=(0, -0.02, 0), root=(-2, 0, 0), neck=(-8, 0, 0),
          lShoulder=reach(-1, (-0.45, 0.0, -1.2), direction=(0.4, -0.2, -0.85)), rShoulder=_pen(0.2, 0.0, 0.3))
slash.key(2.4, "smooth", offset=(0, 0, 0), **REST)
slash.follow("neck", 3.0, 0.7)
slash.follow(("rShoulder", "lShoulder"), 4.0, 0.6)
slash.plant(stance=0.08)
slash.build()

# Forty Seconds (clip fortySeconds, item emote_forty_seconds) -------------------------------------------------
# Light's forty seconds (Death Note: a name written, then the heart attack forty seconds later; refs:
# fortySeconds.toml): the left arm brought up in front, the watch on its wrist read, the right hand in his pocket,
# the seconds counted off with small nods, the weight easing from foot to foot; at forty, the head snaps up, the
# smile. The arm points forward and a little in, so it never crosses the chest.
WRIST = reach(-1, (-0.8, 0.35, -1.9), direction=(0.2, 0.25, -0.95))
watch_ = Motion("fortySeconds", 4.6, note="Light's forty seconds: the watch read, the seconds counted off with nods, "
                "then the snap up and the smile.")
watch_.key(0.0, "smooth", root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -10)))
watch_.key(0.25, "smooth", offset=(0.01, 0, 0), root=(-1, -3, 0), neck=(-8, -4, 0), lShoulder=J((45, 0, -28)),
           rShoulder=POCKET_R)  # (out from the side first: the watch never brushes the body)
watch_.key(0.5, "out", offset=(0.03, 0, 0), root=(-4, -8, 0), neck=(-26, -12, 0), lShoulder=WRIST, rShoulder=POCKET_R)
for k in range(7):
    t = 0.85 + 0.38 * k
    side = 1 if k < 3 else -1
    watch_.key(round(t, 4), "smooth", offset=(0.03 * side, -0.01 * (k % 2), 0), root=(-4, -8, 0),
               neck=(-28 if k % 2 == 0 else -22, -12, 0), lShoulder=WRIST, rShoulder=POCKET_R)
watch_.key(3.45, "snap", offset=(-0.02, 0.01, 0), root=(3, 0, 0), neck=(6, 0, 0),
           lShoulder=J((30, 0, -32)), rShoulder=POCKET_R)  # (dropped out to the side)
watch_.key(4.6, "smooth", offset=(-0.02, 0, 0), root=(3, 2, 0), neck=(4, 4, 4), lShoulder=J((8, 0, -16)), rShoulder=POCKET_R)
watch_.follow("neck", 2.6, 0.7)
watch_.follow(("rShoulder", "lShoulder"), 2.6, 0.75)
watch_.plant(stance=0.08)
watch_.build()


# Blindfold Lift (clip blindfoldLift, a loop; LIFT: blindfoldLiftUp) ------------------------------------------
# Gojo (Jujutsu Kaisen; refs: blindfoldLift.toml): the blindfold on, utterly at ease, the hands in his pockets, the
# weight sunk on a hip, the head tilted, a lazy sway. LIFT: two fingers hook the blindfold and push it up into his
# hair, the head lifting as the eyes open (they light blue), then the hand comes down to his sign before the chest.
blind = Motion("blindfoldLift", 4.0, loop=True, note="Gojo at ease: blindfold on, hands in pockets, a lazy sway.")
for t, side, tilt in ((0.0, 1, 0), (1.0, 1, 1), (2.0, -1, 0), (3.0, -1, -1)):
    blind.key(t, "sine", offset=(0.06 * side, -0.03, 0), root=(3, 6 * side, 3 * side), neck=(4, -6 * side, -3 * side + 6 * tilt),
              rShoulder=POCKET_R, lShoulder=POCKET_L)
blind.follow("neck", 1.4, 0.75)
blind.plant(stance=0.12)
blind.build()

HOOK = reach(1, (0.25, 1.75, -0.65), direction=(-0.35, 0.85, -0.4))  # two fingers at the blindfold's lower edge
PUSHED = reach(1, (0.3, 2.25, -0.35), direction=(-0.3, 0.95, -0.1))  # pushed up into the hair
SIGN = reach(1, (0.15, 0.55, -1.2), direction=(-0.3, 0.85, -0.45))  # the hand raised before the chest, fingers up
up = Motion("blindfoldLiftUp", 3.2, note="LIFT: the blindfold pushed up into the hair, the eyes open, the sign.")
up.key(0.0, "smooth", offset=(0.06, -0.03, 0), root=(3, 6, 3), neck=(4, -6, -3), rShoulder=POCKET_R, lShoulder=POCKET_L)
up.key(0.45, "smooth", offset=(0.03, -0.02, 0), root=(1, 2, 1), neck=(-4, -2, 0), rShoulder=HOOK, lShoulder=POCKET_L)
up.key(0.85, "out", offset=(0.03, -0.01, 0), root=(3, 0, 0), neck=(10, 0, 0), rShoulder=PUSHED, lShoulder=POCKET_L)
up.key(1.15, "smooth", offset=(0.03, -0.01, 0), root=(3, 0, 0), neck=(8, 0, 0), rShoulder=PUSHED, lShoulder=POCKET_L)
up.key(1.55, "out", offset=(0.02, -0.04, 0), root=(-2, -8, 0), neck=(-4, 6, 0), rShoulder=SIGN, lShoulder=POCKET_L)
up.key(2.7, "smooth", offset=(0.02, -0.04, 0), root=(-2, -8, 0), neck=(-6, 6, 0), rShoulder=SIGN, lShoulder=POCKET_L)
up.key(3.2, "smooth", offset=(0.04, -0.03, 0), root=(2, 2, 2), neck=(2, -2, 0), rShoulder=POCKET_R, lShoulder=POCKET_L)
up.follow("neck", 2.0, 0.75)
up.follow(("rShoulder", "lShoulder"), 3.2, 0.7)
up.plant(stance=0.12)
up.build()

# Apple Toss (clip appleToss; TOSS: appleTossThrow) -------------------------------------------------------------
# Light and Ryuk's apple (Death Note; refs: appleToss.toml): the apple tossed up and caught, twice, the knees giving
# with each catch, the eyes following it; then held out to someone who is not there. TOSS: wound back and thrown
# up over the shoulder, and an unseen death god takes it at the top (it is gone in a puff of black feathers).
TOSS_HAND = reach(1, (0.75, 0.35, -1.35), direction=(-0.1, 0.5, -0.85))
TOSS_FLICK = reach(1, (0.75, 0.75, -1.4), direction=(-0.05, 0.8, -0.6))
OFFER = reach(1, (1.1, 0.75, -1.8), direction=(0.25, 0.25, -0.95))
toss = Motion("appleToss", 3.6, note="The apple tossed up and caught twice, the eyes on it, then held out to someone "
              "unseen.")
toss.key(0.0, "smooth", **REST)
for up_t, back in ((0.5, 1.25), (1.55, 2.3)):
    toss.key(up_t - 0.15, "in", offset=(0, -0.08, 0), root=(-3, 0, 0), neck=(-8, 0, 0), rShoulder=TOSS_HAND,
             lShoulder=HANG_L)  # the dip
    toss.key(up_t, "snap", offset=(0, 0.01, 0), root=(1, 0, 0), neck=(12, 0, 0), rShoulder=TOSS_FLICK, lShoulder=HANG_L)
    toss.key((up_t + back) / 2, "smooth", offset=(0, 0, 0), root=(2, 0, 0), neck=(26, 0, 0), rShoulder=TOSS_HAND,
             lShoulder=HANG_L)  # watching it at the top
    toss.key(back, "in", offset=(0, -0.06, 0), root=(-1, 0, 0), neck=(0, 0, 0), rShoulder=TOSS_HAND, lShoulder=HANG_L)
toss.key(2.85, "out", offset=(0.03, 0, 0), root=(0, 12, 0), neck=(2, 18, 0), rShoulder=OFFER, lShoulder=HANG_L)
toss.key(3.6, "smooth", offset=(0.03, 0, 0), root=(0, 12, 0), neck=(2, 18, 2), rShoulder=OFFER, lShoulder=HANG_L)
toss.follow("neck", 3.0, 0.7)
toss.follow(("rShoulder", "lShoulder"), 3.6, 0.7)
toss.plant(stance=0.08)
toss.build()

throw = Motion("appleTossThrow", 2.0, note="TOSS: wound back and thrown up over the shoulder, taken by an unseen death "
               "god.")
throw.key(0.0, "smooth", offset=(0.03, 0, 0), root=(0, 12, 0), neck=(2, 18, 0), rShoulder=OFFER, lShoulder=HANG_L)
throw.key(0.35, "in", offset=(-0.03, -0.08, 0.03), root=(-6, -14, 0), neck=(-6, -10, 0),
          rShoulder=J((-30, 0, 20), (0, 0.05, 0)), lShoulder=J((20, 0, -10)))  # wound back low
throw.key(0.55, "snap", offset=(0.04, 0.02, -0.04), root=(6, 16, 0), neck=(24, 12, 0),
          rShoulder=J((165, 0, 30), (0, 0.18, 0)), lShoulder=J((-10, 0, -14)))  # thrown up and over
throw.key(1.2, "smooth", offset=(0.02, 0, -0.02), root=(5, 14, 0), neck=(34, 20, 0), rShoulder=J((150, 0, 30), (0, 0.15, 0)),
          lShoulder=HANG_L)  # watching it go up, and vanish
throw.key(2.0, "smooth", offset=(0, 0, 0), root=(0, 4, 0), neck=(4, 8, 4), rShoulder=HANG_R, lShoulder=HANG_L)
throw.follow("neck", 2.6, 0.7)
throw.follow(("rShoulder", "lShoulder"), 3.6, 0.6)
throw.plant(stance=0.1)
throw.build()

# Strawberry on Top (clip strawberryOnTop, item emote_strawberry_on_top) ------------------------------------------
# L and his strawberry shortcake (Death Note; refs: strawberryOnTop.toml): hunched, the plate of cake held up in the
# left hand, the strawberry picked off the top between finger and thumb with care, held up and admired at eye
# level, then dropped into the mouth, the head tipping back for it; savoured, eyes half shut.
PLATE = reach(-1, (-0.55, 0.15, -1.55), direction=(0.3, 0.2, -0.95))
PLUCK = reach(1, (-0.25, 0.65, -1.55), direction=(-0.45, 0.35, -0.8))  # the fingers at the strawberry on top
ADMIRE = reach(1, (0.45, 1.65, -1.2), direction=(-0.1, 0.8, -0.6))
INTO_MOUTH = reach(1, (0.08, 1.3, -0.45), direction=(-0.3, 0.85, -0.45))  # at the lips, popped in
straw = Motion("strawberryOnTop", 4.0, note="L's strawberry: the cake held up, the strawberry picked off, admired, "
               "dropped into the mouth.")
straw.key(0.0, "smooth", root=(0, 0, 0), neck=(-6, 0, 0), lShoulder=PLATE, rShoulder=HANG_R)
straw.key(0.45, "out", offset=(0, -0.05, 0), root=(-8, 0, 0), neck=(-18, 0, 0), lShoulder=PLATE, rShoulder=HANG_R)
straw.key(0.85, "smooth", offset=(0, -0.07, 0), root=(-10, 4, 0), neck=(-22, 4, 0), lShoulder=PLATE, rShoulder=PLUCK)
straw.key(1.0, "snap", offset=(0, -0.06, 0), root=(-9, 4, 0), neck=(-20, 4, 0), lShoulder=PLATE,
          rShoulder=reach(1, (-0.2, 0.8, -1.5), direction=(-0.45, 0.4, -0.8)))  # plucked
straw.key(1.6, "smooth", offset=(0, -0.02, 0), root=(-2, -4, 0), neck=(8, -10, 4), lShoulder=PLATE, rShoulder=ADMIRE)
straw.key(2.35, "smooth", offset=(0, -0.02, 0), root=(-1, -4, 0), neck=(10, -12, 8), lShoulder=PLATE, rShoulder=ADMIRE)
straw.key(2.7, "in", offset=(0, -0.01, 0.03), root=(4, 0, 0), neck=(26, 0, 0), lShoulder=PLATE, rShoulder=INTO_MOUTH)
straw.key(3.1, "smooth", offset=(0, -0.04, 0), root=(-4, 0, 0), neck=(-6, 0, 6), lShoulder=PLATE, rShoulder=J((20, 0, 6)))
straw.key(3.6, "smooth", offset=(0, -0.04, 0), root=(-5, 0, 0), neck=(-4, 4, 10), lShoulder=PLATE, rShoulder=J((14, 0, 4)))
straw.key(4.0, "smooth", offset=(0, -0.03, 0), root=(-4, 0, 0), neck=(-6, 2, 6), lShoulder=PLATE, rShoulder=HANG_R)
straw.follow("neck", 2.4, 0.75)
straw.follow(("rShoulder", "lShoulder"), 3.0, 0.75)
straw.plant(stance=0.1)
straw.build()

# Chocolate Snap (clip chocolateSnap, item emote_chocolate_snap) -----------------------------------------------
# Mello's chocolate (Death Note; refs: chocolateSnap.toml): the weight thrown on one hip, the bar held up by the
# mouth, a piece snapped off with a hard twist of the head to the side, chewed with attitude, eyes narrowed; again.
BAR_UP = reach(1, (0.3, 0.8, -0.85), direction=(-0.25, 0.85, -0.45))  # the bar's top at the mouth
BAR_DOWN = reach(1, (0.85, 0.55, -1.25), direction=(0.05, 0.6, -0.8))
choc = Motion("chocolateSnap", 3.2, note="Mello's chocolate: weight on a hip, a piece snapped off with a twist of the "
              "head, chewed with attitude.")
choc.key(0.0, "smooth", **REST)
for bite, away in ((0.75, 0.95), (1.95, 2.15)):
    choc.key(bite - 0.3, "smooth", offset=(0.06, -0.02, 0), root=(0, 6, 4), neck=(2, 8, 4), rShoulder=BAR_UP,
             lShoulder=HANG_L)
    choc.key(bite, "snap", offset=(0.06, -0.04, 0), root=(-3, -6, 4), neck=(-6, -26, 12), rShoulder=BAR_UP,
             lShoulder=HANG_L)  # SNAP
    choc.key(away, "snap", offset=(0.06, -0.03, 0), root=(-2, -4, 4), neck=(-4, -16, 6), rShoulder=BAR_DOWN,
             lShoulder=HANG_L)
    for k, nod in enumerate((4, -2, 4, -2)):
        choc.key(round(away + 0.15 + 0.15 * k, 4), "smooth", offset=(0.06, -0.03, 0), root=(-2, -2, 4),
                 neck=(-4 + nod, -10, 4), rShoulder=BAR_DOWN, lShoulder=HANG_L)
choc.key(3.2, "smooth", offset=(0.04, -0.01, 0), root=(0, 2, 2), neck=(0, -4, 2), rShoulder=BAR_DOWN, lShoulder=HANG_L)
choc.follow("neck", 3.0, 0.6)
choc.follow(("rShoulder", "lShoulder"), 4.0, 0.7)
choc.plant(stance=0.12)
choc.build()

# Pre-Dawn Bonk (clip preDawnBonk, item emote_pre_dawn_bonk) ---------------------------------------------------
# Tung Tung Tung Sahur (the 2025 brainrot meme; refs: preDawnBonk.toml): a wooden figure, stiff as a post, knocking
# on the door before dawn with its bat: three knocks, a stamp of the right foot with each, the body rocking stiffly,
# then once more from high over the head, hard, the whole body following it down.
bonk = Motion("preDawnBonk", 3.6, note="Tung tung tung sahur: stiff, three knocks with a stamp each, then once from "
              "on high.", floor=True)
BAT_UP = J((150, 0, 14), (0, 0.2, 0))
BAT_HIT = J((62, 0, 6), (0, 0.05, -0.14))
STAMP_UP = J((26, 0, 4), (0, 0.28, -0.06))
STAND_R, STAND_L = J((0, 0, 3)), J((0, 0, -3))
bonk.key(0.0, "smooth", offset=(0, 0, 0), **REST, rHip=STAND_R, lHip=STAND_L)
bonk.key(0.3, "smooth", offset=(0, 0, 0), root=(2, 0, 0), neck=(4, 0, 0), rShoulder=J((60, 0, 10), (0, 0.05, -0.1)),
         lShoulder=J((4, 0, -6)), rHip=STAND_R, lHip=STAND_L)
for t in (0.75, 1.25, 1.75):
    bonk.key(t - 0.22, "out", offset=(0, 0.04, 0), root=(4, 0, 2), neck=(6, 0, 0), rShoulder=BAT_UP,
             lShoulder=J((10, 0, -14)), rHip=STAMP_UP, lHip=STAND_L)  # wound up, the foot up
    bonk.key(t, "snap", offset=(0, -0.04, 0), root=(-8, 0, -2), neck=(-8, 0, 0), rShoulder=BAT_HIT,
             lShoulder=J((16, 0, -18)), rHip=STAND_R, lHip=STAND_L)  # TUNG, the stamp
bonk.key(2.3, "out", offset=(0, 0.06, 0.04), root=(12, 0, 0), neck=(14, 0, 0), rShoulder=J((178, 0, 10), (0, 0.26, 0.06)),
         lShoulder=J((30, 0, -30)), rHip=STAND_R, lHip=STAND_L)  # high over the head
bonk.key(2.55, "snap", offset=(0, -0.2, -0.05), root=(-16, 0, 0), neck=(-14, 0, 0), rShoulder=J((48, 0, 4), (0, 0.02, -0.16)),
         lShoulder=J((26, 0, -24)), rHip=J((-6, 0, 8), (0, 0.2, 0)), lHip=J((-6, 0, -8), (0, 0.2, 0)))  # SAHUR
bonk.key(3.05, "smooth", offset=(0, -0.16, 0), root=(-12, 0, 0), neck=(-10, 0, 0), rShoulder=J((50, 0, 4), (0, 0.02, -0.16)),
         lShoulder=J((22, 0, -20)), rHip=J((-5, 0, 7), (0, 0.16, 0)), lHip=J((-5, 0, -7), (0, 0.16, 0)))
bonk.key(3.6, "smooth", offset=(0, 0, 0), **REST, rHip=STAND_R, lHip=STAND_L)
bonk.follow(("rShoulder", "lShoulder"), 4.0, 0.7)
bonk.build()

# Two-Finger Grip (clip twoFingerGrip, item emote_two_finger_grip) ---------------------------------------------
# The two-fingertip phone grip (the meme; refs: twoFingerGrip.toml): hunched, a phone dangled from two fingertips
# at eye level and stared at, the other hand in a pocket; the weight easing from foot to foot, the head tilting,
# the dangling phone swaying a little. A 3 s loop (also a stance).
DANGLE = J((118, 0, -16), (-0.08, 0.12, -0.12))
grip = Motion("twoFingerGrip", 3.0, loop=True, note="A phone dangled from two fingertips at eye level, stared at, "
              "swaying.")
for t, side in ((0.0, 1), (1.5, -1)):
    grip.key(t, "sine", offset=(0.04 * side, -0.08, 0), root=(-10, 3 * side, 2 * side), neck=(-2, 6 + 2 * side, 4 + 3 * side),
             rShoulder=J((118 + side, 0, -16 + 2 * side), (-0.08, 0.12, -0.12)), lShoulder=POCKET_L)
grip.follow("neck", 1.5, 0.75)
grip.follow(("rShoulder", "lShoulder"), 1.5, 0.6)
grip.plant(stance=0.16)
grip.build()


# Where each prop sits at the pose that matters (art/scripts/solve_holds.py writes the EmoteMeta `at` and `to`
# lines tagged `-- hold: clip/model` from these): (part, pose, prop pivot in the torso frame, its turn in degrees).
# (the Manual's pivot is its closed middle; open, its page block lies left of the spine, x = +0.974 in the model,
# and the board on the right: the pivot sits so the spread is centred, tilted up to his face)
_BOOK_SCALE = 1.7 / 3.022
_BOOK_PIVOT = (PAGE[0] - 0.974 * _BOOK_SCALE + 0.55, PAGE[1], PAGE[2])
_PEN_PIVOT = tuple(PAGE[i] + (-0.35 * (1.0, 0.0, 0.0)[i]) + (-0.3) * _down[i] + 0.5 * _n[i] for i in range(3))
HOLDS = {
    "appleToss/Apple": ("Right Arm", {"rShoulder": TOSS_HAND}, (0.72, 0.62, -1.6), (0, 0, 0)),
    "furiousScribbling/Grimoire": ("Left Arm", {"lShoulder": BOOK_HAND}, _BOOK_PIVOT, (BOOK_TILT, 0, 0)),
    "furiousScribbling/Pen": ("Right Arm", {"rShoulder": _pen(-0.35, -0.3)}, _PEN_PIVOT, (BOOK_TILT + 15, 0, -10)),
    "furiousScribbling/Grimoire2": ("Left Arm", {"lShoulder": BOOK_HAND}, _BOOK_PIVOT, (BOOK_TILT, 0, 0)),
    "furiousScribbling/Pen2": ("Right Arm", {"rShoulder": _pen(-0.35, -0.3)}, _PEN_PIVOT, (BOOK_TILT + 15, 0, -10)),
    "appleToss/Apple2": ("Right Arm", {"rShoulder": TOSS_HAND}, (0.72, 0.62, -1.6), (0, 0, 0)),
    "strawberryOnTop/CakeSlice": ("Left Arm", {"lShoulder": PLATE}, (-0.45, 0.62, -2.02), (0, 0, 0)),
    "strawberryOnTop/Strawberry": ("Left Arm", {"lShoulder": PLATE}, (-0.3, 1.15, -2.02), (0, 0, 0)),
    "chocolateSnap/ChocolateBar": ("Right Arm", {"rShoulder": BAR_UP}, (0.22, 1.15, -0.95), (0, 0, 0)),
    "chipAndPen/ChipBag": ("Left Arm", {"lShoulder": BAG_HOLD}, (-0.65, TOP + 0.08, -1.35), (0, 0, 0)),
    "chipAndPen/Pen": ("Right Arm", {"rShoulder": reach(1, PEN_AT, direction=PEN_DIR)},
                       (PEN_AT[0] + 0.02, PEN_AT[1] - 0.3, PEN_AT[2] + 0.02), (18, 0, -8)),
    "chipAndPen/Chip": ("Right Arm", {"rShoulder": reach(1, RAISE_AT, direction=RAISE_DIR)},
                        (RAISE_AT[0] + 0.02, RAISE_AT[1] + 0.32, RAISE_AT[2] - 0.08), (90, 0, 0)),
}
