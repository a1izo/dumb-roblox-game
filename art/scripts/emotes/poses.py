"""Poses and acted moments, each copied from its reference (art/refs/emotes/<clip>.toml)."""

from animlib import J
from motion import Motion

REST = dict(root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))

# Just As Planned (clip justAsPlanned, item emote_just_as_planned; Diavolo's mastery) ----------------------
# Death Note's "keikaku doori" moment (the anime, once Light has his memories back): seated, he turns his head
# slowly, the eyes slide to the side and catch red; then the head drops, the eyes glare up from under the hair
# and the grin spreads.
# The anime cuts between shots; here it is one continuous move standing: the turn over the left shoulder into
# a stare, the chin down and the shoulders hunched as the grin comes, a silent chuckle in the shoulders, and
# back. (refs: justAsPlanned.toml, the clip's 1.4-9.2 s compressed to 4.4 s.)
plan = Motion("justAsPlanned", 4.4, note="The keikaku doori grin: the head turns, the eyes catch red, the chin drops into the grin.", unwrap=True)
hang_r, hang_l = J((6, 0, 6), (0, 0.04, -0.04)), J((6, 0, -6), (0, 0.04, -0.04))
plan.key(0.0, **REST)
plan.key(0.35, "sine", root=(-1, 0, 0), neck=(-2, 4, 0), rShoulder=hang_r, lShoulder=hang_l)
# the turn: slow, the head leading the shoulders
plan.key(1.15, "sine", root=(-2, 10, 0), neck=(-4, 34, -2), rShoulder=J((8, 0, 7), (0, 0.04, -0.06)),
         lShoulder=J((4, 0, -6), (0, 0.04, 0.02)))
plan.key(1.85, "sine", root=(-2, 11, 0), neck=(-5, 36, -3), rShoulder=J((8, 0, 7), (0, 0.04, -0.06)),
         lShoulder=J((4, 0, -6), (0, 0.04, 0.02)))
# the chin drops, the shoulders come up and forward: the eyes glare up from under the brows
plan.key(2.45, "out", offset=(0, -0.05, 0), root=(-9, 9, 0), neck=(-24, 30, 6),
         rShoulder=J((14, 0, 10), (0, 0.16, -0.12)), lShoulder=J((10, 0, -8), (0, 0.16, -0.06)))
for i in range(3):  # the silent chuckle in the shoulders
    t = 2.75 + 0.2 * i
    plan.key(t, "out", offset=(0, -0.08, 0), root=(-10, 9, 0), neck=(-26, 30, 7),
             rShoulder=J((15, 0, 10), (0, 0.2, -0.12)), lShoulder=J((11, 0, -8), (0, 0.2, -0.06)))
    plan.key(t + 0.1, "sine", offset=(0, -0.05, 0), root=(-9, 9, 0), neck=(-24, 30, 6),
             rShoulder=J((14, 0, 10), (0, 0.15, -0.12)), lShoulder=J((10, 0, -8), (0, 0.15, -0.06)))
plan.key(3.55, offset=(0, -0.05, 0), root=(-9, 9, 0), neck=(-25, 30, 6),
         rShoulder=J((14, 0, 10), (0, 0.16, -0.12)), lShoulder=J((10, 0, -8), (0, 0.16, -0.06)))
plan.key(4.4, "sine", **REST)
plan.follow("neck", 1.6, 0.8).follow(("rShoulder", "lShoulder"), 2.6, 0.75).plant(stance=0.06)
plan.build()
