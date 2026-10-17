"""Emotes with props, each copied from its reference (art/refs/emotes/<clip>.toml). The props' holds in
src/shared/Anim/EmoteMeta.luau are solved from the key poses here (kit.hold), so the fist and the prop meet
where the reference has them; check_props.py measures every contact the meta names."""

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
# down into the chair: the hips back, the knees forward
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
chip.key(9.05, "out", offset=(0, 0, 0), root=(-4, 0, 0), neck=(-22, 0, 0), rShoulder=J((2, 0, 5)),
         lShoulder=J((2, 0, -5)), **standing)
chip.key(9.9, "sine", root=(-3, 0, 0), neck=(-26, 0, 0), rShoulder=J((2, 0, 5)), lShoulder=J((2, 0, -5)), **standing)
chip.key(10.4, "sine", **REST, **standing)
chip.follow("neck", 3.0, 0.75).follow(("lShoulder",), 3.0, 0.8)
chip.build()

# Where each prop sits at the pose that matters (art/scripts/solve_holds.py writes the EmoteMeta `at` and `to`
# lines tagged `-- hold: clip/model` from these): (part, pose, prop pivot in the torso frame, its turn in degrees).
HOLDS = {
    "chipAndPen/ChipBag": ("Left Arm", {"lShoulder": BAG_HOLD}, (-0.65, TOP + 0.08, -1.35), (0, 0, 0)),
    "chipAndPen/Pen": ("Right Arm", {"rShoulder": reach(1, PEN_AT, direction=PEN_DIR)},
                       (PEN_AT[0] + 0.02, PEN_AT[1] - 0.3, PEN_AT[2] + 0.02), (18, 0, -8)),
    "chipAndPen/Chip": ("Right Arm", {"rShoulder": reach(1, RAISE_AT, direction=RAISE_DIR)},
                        (RAISE_AT[0] + 0.02, RAISE_AT[1] + 0.32, RAISE_AT[2] - 0.08), (90, 0, 0)),
}
