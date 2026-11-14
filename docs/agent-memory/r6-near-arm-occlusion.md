---
name: r6-near-arm-occlusion
description: On a seated R6 actor the arm nearest the lens is a 1 by 2 stud block that covers the face whenever a hand goes to the mouth; act with the far arm, shoot at head height, frame at least 4.5 studs tall (RoleAce, 2026-11-14)
metadata:
  type: feedback
---

Found building RoleAce: with the camera on the actor's right (and then front-right), every beat that raised the right hand
(over a sugar cube, to the lips, a cup to the mouth) put the arm between the lens and the face. The shape lint said so
too (`[shape] ... the head is overlapped by the raised right arm (61 percent)`), and the stills were a wall of dark arm
with a strip of hair above it. A camera below the head made it worse: it looks up the arm's underside across the chin.

**Why:** R6 arms are boxes 1 stud wide and 2 long that cannot be bent, so a hand at the mouth is a whole arm in front of
the cheek, and at 3 to 5 studs from the lens one arm is half the frame.
**How to apply:** (1) give the hand-to-mouth beats to the FAR arm from the camera that watches them, so only the fist
and what it holds come round the face, and let the near arm hug the knee; (2) put the camera at the actor's head height,
not below it; (3) frame at least 4.5 studs tall at the figure (fov 34 or more at 7 to 8 studs) and creep to a tight fov
only for a stare, where nothing is raised; (4) an object held in a fist sits past the arm's end, never under it (it is
inside the arm box): see [[r6-held-props-on-paths]]; (5) run `run_cinema.py --lint` and read the `[shape]` lines.
RoleAce ended with the tower of sugar cubes and the cup on the right (far) side of Ace for a camera on his left, and
no `[shape]` notes. Related: [[cutscene-quality-bar]].
