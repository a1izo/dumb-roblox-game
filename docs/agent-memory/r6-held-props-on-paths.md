---
name: r6-held-props-on-paths
description: A prop welded to an R6 forearm tips with it (a cup tips 70 degrees on its way to the lips) and sits inside the arm box when put under its end; key the prop on its own path from the baked motion instead, and place it past the arm's end (RoleAce, 2026-11-14)
metadata:
  type: reference
---

`Actor.hold(prop, arm, offset, rot)` welds a prop to a part, so it turns with the arm. The tray in the old RoleAce was
level only because `keep_arm` re-solved the Butler's arms; a cup welded where it stands on a tray and carried to the lips
tips by the whole difference in arm pitch (about 70 degrees: from a forearm pointing down at the tray to one pointing up
at the mouth). R6 has no wrist to keep it level.

**What works** (`art/scripts/cinema/shots/role_ace.py`: `sampled()`, `Held`, the cube and cup):
- Give the prop its **own path** (`shot.prop(name, show=(t0, t1)).at(t, pos, rot)`, `rot` the tilt you want) with a key
  every 1/30 s, computed from the same motion the clip is baked from: `m._sprung(times)` then `m.sample(t, sprung, i)`
  then `posekit.fk` (after `footwork.apply`, so the springs and the planned feet are included).
- Start it where it lies (the tray's cup, the tower's top cube) and **blend onto the fist over 0.3 s** (smoothstep), so
  it never pops and a few hundredths of reach error never shows.
- **Place it past the arm's end along the arm**: its middle is `radius` beyond the end face (1 stud from the arm's
  middle), so the end touches it. Anything put "under" the end is inside the arm's own box and cannot be seen (the cup
  vanished that way). `Held(side, center_fn, r)` solves the fist target as `centre - (0.15 + r) * axis` with the arm
  pointing straight at the centre; the fist's middle is 0.15 before the end face.
- The prop's pivot is its bottom (SugarCube 0.42 cube, Teacup 0.76 wide and 0.29 high on its saucer): key the bottom
  middle, not the centre. A tipped Teacup tips its saucer too (keep the tilt under about 10 degrees).
- Props welded to a LEG stay put while the body leans (the tower of cubes on a thigh, `hold(..., "Right Leg", ...)`);
  only the one that is taken needs a path. The game's `hold` accepts any part name of the character.
Related: [[r6-near-arm-occlusion]], [[cutscene-pipeline]] (a prop that appears from nowhere).
