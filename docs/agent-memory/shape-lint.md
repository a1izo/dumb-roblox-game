---
name: shape-lint
description: "run_cinema.py --lint prints [shape] notes (Tool 3): holds where both arms are hidden in the torso's outline or a raised arm covers the head, from the shot's own camera; how a held pose is defined and how the numbers were calibrated on RoleMuerto"
metadata:
  type: reference
---

`run_cinema.py --lint` prints `[shape]` lines from `cinema/silhouette.py` (`shape_lint`). It samples each actor's
`Motion` every 0.05 s (springs and extras included), takes a **held pose** as any moment where the head, hands, arm middles
and torso corners (in the actor's own frame) move under 0.25 studs over 0.15 s either side, projects the six R6 boxes
through the shot's camera at that time (the head a 1.2 box, outlines are convex hulls) and reads two things: both
arms more than 70 percent inside the torso's outline, or a raised hand (0.5 studs above the shoulder joint) whose arm
covers over 40 percent of the head. Actors with a `silhouette=` window get stricter lines (50 and 20 percent) while
they are drawn black. Only bodies whose torso is at least a tenth of the frame tall are read.

**Why those numbers:** the first rule (hand at shoulder height, 20 percent of the head) printed 7 notes on RoleMuerto
(the good scene), mostly the writing poses, and 10 on RoleButler (a tray carried level). The plan says the rule is
fixed, not the scene: "raised" now means over the shoulder, the head line is 40 percent. Result: Muerto 1 (the
wind-up before the first slash), Diavolo 0, Operative 0, Ace 2, Butler 1, MeetingIntro 2, Agency 5. Arms hanging at
the sides are 7 percent in the torso from the front and 83 to 100 from the side, so a side-on camera on a standing
still body will always say "both arms hidden".

**How to apply:** after a `[shape]` note, look at that hold with [[spacing-strip]] or a `--preview` still; change the
arm or the angle, not the threshold. To try other numbers without waiting two minutes for the shots to load, pickle
`silhouette.poses(...)` for each actor once and run `shape_lint` on stand-in shots offline (Blender's own python runs
silhouette.py without bpy).
