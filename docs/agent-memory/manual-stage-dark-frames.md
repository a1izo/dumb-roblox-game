---
name: manual-stage-dark-frames
description: The Manual stage (BookStage: Outro book, Manual writing shot, death opening) is a black frame under the game's colour grade in a 2026-11-14 play test, any number of names; the grade crushes a page the lamp does not seem to light
---

In a Studio play test on 2026-11-14 (Studio in front, Campus and then Bureau HQ) the BookStage shots were **black under
the game's normal lighting**, with 10 names or 2 (the `manualWrite` shot too). Only switching the client's
`DeathsGambitGrade` ColorCorrection off (HQ: contrast 0.46, saturation -0.60) made the page appear, dim brown with grey
ink; raising the BookStage PointLight four times (4.3 to 17.2) changed nothing, grade on or off, so the page seems lit
by ambient light only and the lamp contributes nothing. Why the lamp does not light it is not known (an invisible 0.2
stud part at y 1500, an engine light budget or altitude limit are the suspects). Run-down, with the table of runs, in
[animation-audit-match-scenes-2026-11-14.md](../handoff/animation-audit-match-scenes-2026-11-14.md) ("The black Manual,
run down"). The BookStage header says this scene has gone black before ("a spotlight lit nothing in the game").

My first note on this was wrong: it said 10 names rendered black and 2 names dim. That comparison was confounded, I had
switched the grade, bloom, depth of field and atmosphere off between the two. Do not repeat it: change one thing per run.

**Why it matters:** the Manual shots are the owner's staging; a black page makes the cause-and-effect beat (the name
being written) invisible, in every match. **How to apply:** before touching the Manual's fit or pace, look at the shot
in a normal play session; if it is black there too, fix the light first (a scratch copy of BookStage: ambient or
exposure for the set, a SurfaceLight or SpotLight, a lower altitude, or a per-shot grade, in that order of try), then
the framing. Related: [[lighting-rework-2026-11]], [[studio-capture-disturbs-camera]].
