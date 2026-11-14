---
name: review-stills
description: art/scripts/review_stills.py (2026-11-14) renders many stills of one shot in a single Blender run; why, and the other slow spots found in the cutscene loop
metadata:
  type: reference
---

`blender -b --factory-startup --python art/scripts/review_stills.py -- RoleAce <outdir> "5.4@cam" "11.4@246,4,-2,238,4.8,-1.9,30"`:
each view is a time and `@cam` (the shot's own camera and the game's letterbox) or a free camera (px,py,pz,tx,ty,tz,fov).
It plays the clips saved in Animations.blend, so bake first (`run_anims.py -- --add A,B`). `run_cinema.py --preview --stills`
builds the venue once per call (about 3 minutes with the rig and the Sets scene), so several looks cost several builds.

Other costs measured on 2026-11-14 (a loop of about 12 minutes per change on this machine): every script that imports a
shot module also builds all 70 emote clips first (about 1.5 minutes), `run_anims.py --add` then exports the whole clip
library (about 6 minutes), and a 960x540 preview video of 17.5 s takes about 17 minutes. Batch the changes of several
poses and cameras into one bake, and run the lint, the export, the stills and the video as parallel Blender runs once
the bake is done. Related: [[cutscene-pipeline]], [[spacing-strip]].
