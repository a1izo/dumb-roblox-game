---
name: r6-one-knee
description: How an R6 body kneels on one knee without reading as a split (2026-11-15, the user on Thanos: "dont make thanos do a split ... make him KNEEL"); scene_actors.one_knee(pitch)
metadata:
  type: feedback
---

An R6 leg is one block with no knee. Keying a "thigh forward" (rHip 88) and a "thigh back" (lHip -70) gives two
horizontal blocks pointing opposite ways: a split. The user rejected it (Iron Man's warlord, 2026-11-15).

What reads as one knee (`scene_actors.one_knee(pitch)`):
- the raised knee's leg is its SHIN: near upright (6 degrees forward in the world), slid up 0.45 and forward 0.9 so it
  stands in front of the body (the thigh is "inside" the torso);
- the down leg goes down and back from the hip to its knee on the floor (-46 degrees);
- both are set against the body's lean (`pitch`, the floor_key's), so they hold their place as the body bows;
- a hand can rest on the raised knee: rShoulder about J((40..43, 0, -16..-18)) with the body leaning 6 to 14.

Check it with the scratchpad's pose_view.py (Blender boxes from rbxsim, side and three-quarter views), not by eye in
the key numbers. Both knees (kneeling_legs, legs folded back along the floor) were already fine.
Related: [[animation-bar]], [[r6-reach-limits]], [[deaths-2026-11]].
