"""Emotes with props, each copied from its reference (art/refs/emotes/<clip>.toml). The props' holds in
src/shared/Anim/EmoteMeta.luau are solved from the key poses here (kit.hold), so the fist and the prop meet
where the reference has them; check_props.py measures every contact the meta names."""

from animlib import J
from emotes.kit import reach
from motion import Motion

REST = dict(root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))

# Diavolo's Potato Chip (clip chipAndPen, item emote_chip_and_pen) ---------------------------------------
# Death Note, episode 8 ("Glare"): under L's cameras Light studies, and in the bag of crisps on his desk is a
# torn page and a tiny TV. He writes a name through the bag's mouth, takes a crisp, raises it slowly ("I'll take
# a potato chip...") and bites it with a flourish ("...and eat it!"), the crisp bursting. Standing here: the bag
# in the left hand, the pen writing into it, the pen dropped in, a crisp taken, raised high with the elbow out,
# held, snapped to the mouth and crunched, then chewed. (refs: chipAndPen.toml.)
# (R6's arms are as wide as the head: the crisp is raised beside the face, not across it, so the face stays
# seen until the bite.)
BAG_L = reach(-1, (-0.78, 0.05, -0.8), direction=(0.25, -0.3, -1.0))
PEN_AT = (-0.18, 0.98, -1.0)
PEN_DIR = (-0.45, -0.25, -1.0)
IN_BAG = (-0.42, 0.55, -0.9)
RAISE_AT, RAISE_DIR = (0.95, 1.65, -0.85), (0.15, 0.75, -0.55)
BITE_AT, BITE_DIR = (0.05, 1.02, -0.62), (-0.55, 0.55, -0.6)

chip = Motion("chipAndPen", 5.0, note="The potato chip: writing into the bag, a crisp raised slowly, then bitten with a flourish.", unwrap=True)
chip.key(0.0, **REST)
chip.key(0.35, "out", root=(-3, 0, 0), neck=(-16, 4, 0), lShoulder=BAG_L,
         rShoulder=reach(1, (0.8, 1.1, -1.0), direction=(-0.2, -0.1, -1.0)))  # over the bag from the right
chip.key(0.55, "sine", root=(-4, 0, 0), neck=(-20, 4, 0), lShoulder=BAG_L, rShoulder=reach(1, PEN_AT, direction=PEN_DIR))
for i in range(10):  # the scribble through the bag's mouth: quick strokes side to side
    t = 0.66 + 0.11 * i
    dx = (0.07, -0.06, 0.05, -0.07, 0.06, -0.05, 0.07, -0.06, 0.04, -0.03)[i]
    dy = (0.02, -0.01, 0.02, 0.0, -0.02, 0.02, 0.0, -0.02, 0.01, 0.0)[i]
    chip.key(t, "linear", root=(-4, 0, 0), neck=(-20, 4 + dx * 20, 0), lShoulder=BAG_L,
             rShoulder=reach(1, (PEN_AT[0] + dx, PEN_AT[1] + dy, PEN_AT[2]), direction=PEN_DIR))
chip.key(1.85, "in", root=(-4, 0, 0), neck=(-22, 4, 0), lShoulder=BAG_L,
         rShoulder=reach(1, (PEN_AT[0], PEN_AT[1] - 0.2, PEN_AT[2]), direction=PEN_DIR))  # the pen pushed into the bag
chip.key(2.05, "out", root=(-4, 0, 0), neck=(-20, 2, 0), lShoulder=BAG_L,
         rShoulder=reach(1, IN_BAG, direction=(-0.35, -0.45, -1.0)))  # the hand in the bag
chip.key(2.3, "sine", root=(-3, -2, 0), neck=(-12, -2, 0), lShoulder=BAG_L,
         rShoulder=reach(1, (0.1, 0.95, -1.0), direction=(-0.2, 0.2, -1.0)))  # a crisp taken out
# raised slowly, the elbow out, the eyes on it
chip.key(3.2, "sine", root=(1, -6, 0), neck=(10, -14, 0), lShoulder=BAG_L, rShoulder=reach(1, RAISE_AT, direction=RAISE_DIR))
chip.key(3.36, root=(1, -6, 0), neck=(11, -15, 0), lShoulder=BAG_L,
         rShoulder=reach(1, (RAISE_AT[0] + 0.02, RAISE_AT[1] + 0.03, RAISE_AT[2]), direction=RAISE_DIR))
# and eat it: snapped to the mouth, the head meeting it
chip.key(3.5, "snap", root=(-2, -4, 0), neck=(-4, -6, 0), lShoulder=BAG_L, rShoulder=reach(1, BITE_AT, direction=BITE_DIR))
chip.key(3.62, "out", root=(-2, -3, 0), neck=(-6, -3, 0), lShoulder=BAG_L,
         rShoulder=reach(1, (0.75, 1.35, -0.95)))  # the hand away up and to the right, over the bag
chip.key(3.8, "sine", root=(-2, -2, 0), neck=(-8, -2, 0), lShoulder=BAG_L, rShoulder=reach(1, (1.3, 0.55, -0.6)))
for i, t in enumerate((3.95, 4.15)):  # chewing, the eyes front
    chip.key(t, "sine", root=(-2, -2, 0), neck=(-3 if i % 2 == 0 else -8, -2, 0), lShoulder=BAG_L,
             rShoulder=J((18 - 8 * i, 0, 12), (0, 0.04, -0.06)))
chip.key(4.45, "sine", root=(-1, 0, 0), neck=(-6, 0, 0), lShoulder=J((30, 0, -8), (0.06, 0.04, -0.1)), rShoulder=J((6, 0, 6)))
chip.key(5.0, "sine", **REST)
chip.follow("neck", 3.4, 0.72).follow(("lShoulder",), 3.0, 0.8).plant(stance=0.06)
chip.build()

# Where each prop sits at the pose that matters (art/scripts/solve_holds.py writes the EmoteMeta `at` lines
# tagged `-- hold: clip/model` from these): (part, pose, prop pivot in the torso frame, its turn in degrees).
HOLDS = {
    "chipAndPen/ChipBag": ("Left Arm", {"lShoulder": BAG_L}, (-0.1, -0.8, -1.02), (10, 0, -6)),
    "chipAndPen/Pen": ("Right Arm", {"rShoulder": reach(1, PEN_AT, direction=PEN_DIR)},
                       (PEN_AT[0] + 0.02, PEN_AT[1] - 0.3, PEN_AT[2] + 0.02), (18, 0, -8)),
    "chipAndPen/Chip": ("Right Arm", {"rShoulder": reach(1, RAISE_AT, direction=RAISE_DIR)},
                        (RAISE_AT[0] + 0.02, RAISE_AT[1] + 0.32, RAISE_AT[2] - 0.08), (90, 0, 0)),
}
