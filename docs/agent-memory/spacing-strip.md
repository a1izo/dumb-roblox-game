---
name: spacing-strip
description: "review_strip.py draws one actor's frames 0.05 s apart as black bodies through the shot's own camera (Tool 2 of the animation plan); how to run it, what it reads, and why a run takes two minutes"
metadata:
  type: reference
---

`art/scripts/review_strip.py` (Blender, background) writes one PNG: the actor's frames from t0 to t1, 0.05 s apart in a
row, each as the shot's own camera sees it, the six R6 boxes flat black on white. Under each frame, its time and a bar
for how far the body travelled on the screen since the frame before. A run of equal bars is a glide (the stiffness the
owner sees); a tall bar then flat ones is a snap and a hold. Grey is off-frame or under the letterbox, a red edge is a
camera cut.

```
blender -b --factory-startup --python art/scripts/review_strip.py -- RoleMuerto self 5.2 6.8 art/export/previews/cinema/strips/x.png [--cols=12] [--fixed]
```

- It reads the shot module's own acting (`Motion.sample` with the springs, through `posekit.fk`), not the clips in
  Animations.blend, so it never shows a stale clip and nothing needs rebuilding first. The geometry lives in
  `art/scripts/cinema/silhouette.py` (no bpy at its top, so the drawing code can be tried with Blender's bundled python).
- **Why a run takes about two minutes:** importing any role scene runs `from emotes.kit import reach`, and the emotes
  package builds all 70 emote clips on import. The strip itself takes a second. Give several groups of five arguments
  (Shot actor t0 t1 out.png) to one run, and use `--cols=12` to wrap a long window so the image can be looked at (a
  40 frame row is 9000 pixels wide).
- No hair, hat, prop or set: it says whether the body's own shape reads, not whether something stands in front.

**How to apply:** run it over every big move (0.3 s before to 0.5 s after) at the timing step of the scene loop. Related:
[[animation-bar]], [[cutscene-pipeline]], [[shape-lint]].
