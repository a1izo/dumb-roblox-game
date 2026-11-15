---
name: stills-trap-absolute-outdir
description: review_stills.py given a relative outdir writes under C:\art\ (outside the repo); give an absolute one with forward slashes, and quote paths with spaces; a 960x540 still of the Campus book shot stalled over 10 minutes on a CPU render, 640x360 (DG_SIZE) does not (2026-11-15)
metadata:
  type: feedback
---

Found rendering the IntroCampus stills ([[review-stills]]):

- `review_stills.py -- Shot art/export/previews/cinema/x "t@cam"` wrote its PNGs to `C:\art\export\previews\cinema\x`
  (Blender resolves a relative render path from the drive root, not the working folder). Pass an absolute outdir
  (`$(pwd -W)/art/export/...` in Git Bash). A stray `C:\art` folder was left behind from this; it is only stills and can
  be deleted by the owner.
- The same goes for the images given to a contact-sheet script: relative paths silently fail, and a path with a space
  (`roblox games`) must be quoted in every argument.
- The renders are on the CPU here (the log says `Failed to create GPU texture`): the Campus intro's book hanging in the
  lamp's volumetric light (11.8 s) did not finish in over ten minutes at 960x540 beside two other Blender runs, and the
  whole before-video at that size was hopeless. `DG_SIZE=640x360` renders a still in a few seconds; use it for the loop and
  render the full size only for the owner's video, with no other Blender running.
- Other agents run Blender at the same time (two RoleDiavolo stills runs); a render that stalls may only be starved.
  Check the process's CPU time before killing it.
