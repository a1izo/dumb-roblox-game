"""Poses and acted moments, each copied from its reference (art/refs/emotes/<clip>.toml)."""

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
