---
name: r6-reach-limits
description: How far an R6 fist can really reach (1.3 to 2.4 studs from the shoulder pivot) and what that did to RoleAce's table, tray and thigh targets (2026-11-14); check hand targets with fist-against-target numbers before shooting
metadata:
  type: reference
---

`emotes.kit.reach` (used by `cinema.acting.body_reach`) puts a fist on a target by pointing the arm and sliding it up to
`max_slide` 0.55 studs. The arm is 2 studs and the fist's middle sits 0.15 before its end, so the shoulder pivot to
the fist is about 1.85 plus or minus 0.55: **a target nearer than about 1.3 or farther than about 2.4 is missed**, and the
fist lands short or sunk into whatever is near (a rest hand 0.25 to 0.4 studs inside the thigh).

Consequences found in RoleAce (2026-11-14), each by printing the fist against its target for every placed hand (the
scratch lab: a Blender run importing the shot, `posekit.fk` of each key, distance of `Arm @ (0, -0.85, 0)` from the target):
- The old set's low table stands 3.6 studs to the armchair's right and 0.6 below the cushion: a hand cannot take a sweet
  from it. The sugar cubes stand on Ace's own thigh instead, and the Butler offers the tray at the chair's right hip.
- A rest pose with the hand on the thigh must put the fist 1.3 or more from the shoulder (along the thigh, a little high).
- After the torso turns, a target fixed in the character's frame can fall inside the 1.3 limit (the cup held at the chest
  missed by 0.6 when the torso turned 28 degrees): move it out.
- A body is two studs wide, so the Butler needs about 3.8 studs of clear floor at a doorway 4 wide: walk him straight
  through it, then veer.
Related: [[r6-held-props-on-paths]], [[cutscene-pipeline]].
