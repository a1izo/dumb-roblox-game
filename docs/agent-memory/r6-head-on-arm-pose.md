---
name: r6-head-on-arm-pose
description: A seated R6 body cannot prop its chin on a fist (the fist is 1.1 studs from the shoulder, under the 1.3 reach limit); lay the arm along the desk and the head on it instead, with the numbers that worked (IntroCampus noticer, 2026-11-15)
metadata:
  type: reference
---

The Campus intro's bored student is Light with his chin in his hand. On R6 that pose does not exist: the fist under the
chin is about 1.1 studs from the shoulder pivot, and `reach` only places a fist 1.3 to 2.4 studs from it
([[r6-reach-limits]]); a scan of lean, roll, neck tilt and fist place found no pose with the fist nearer than 1 stud to
the cheek, and the earlier attempt (2026-10-28) had a straight arm hiding the face. What reads as the same boredom and
holds from a camera on the other side: **the far arm lies forward along the desk and the head rests on it.**

The numbers (the seated body of `intro_campus.body`, the character frame is the floor under the root, facing -z, +x his
right; `body_reach(-1, ..., (-0.6, desk_top + 0.5, -1.5), direction=(0, -0.5, -0.85))`): trunk lean -18, root roll +6,
neck (pitch -6, yaw 0, roll +24) puts the head centre at about (-0.35, 4.2, -0.5), 1.15 studs from the arm's axis and
facing forward and down (face direction y about -0.4). Turn the neck yaw to -16 and the head faces the door, on the arm.
Check a pose of this kind with a scan (a Blender script: for each lean, roll, neck, fist place, `posekit.fk`, the
distance from the head centre to the shoulder-to-fist segment, the fist's error against its target) rather than by eye.

The frame lint wants more: a face turned within 60 degrees of the lens, a head under 62 percent of the visible frame, and
a head not bowed (face direction y over -0.55), so the pose above is as far down as a face can go.
Related: [[r6-near-arm-occlusion]], [[fast-run-launcher]].
