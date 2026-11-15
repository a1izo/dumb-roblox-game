---
name: manual-stage-dark-frames
description: The Manual stage (BookStage) was a black frame because its far-off set was lit by the wrong look (venue = lobby, 1.8 s of the meeting's look then a 3.5 s blend) and its lamp lights nothing; fixed 2026-11-15 with a "manual" scene look, ambient-lit
---

Found 2026-11-14 in a Studio play test, run down and fixed 2026-11-15 (the owner's "manual yes"). Every BookStage shot
(the Outro's book, the `manualWrite` shot, a death by the Manual's opening, a win cutscene's book) was a black frame, with
any number of names. Full run-down, table of runs and the stills described in
[animation-audit-match-scenes-2026-11-14.md](../handoff/animation-audit-match-scenes-2026-11-14.md) ("The black Manual, run
down"). The facts that will matter again:

- **A set built far from the venues is lit by whatever look the controller picks for its position.** The Manual's set is at
  (0, 1500, 300); `Venues.at` says "lobby". On the cut `LightingController` keeps the previous look for about 1.8 s (the
  meeting's: ambient 0.03, contrast 0.53), then blends over `BLEND` = 3.5 s to the lobby's. Venue changes to or from "sets"
  and "scene" are instant; "lobby" is not. The death scenes avoid all this with `LightingController.scene(key)` and a look in
  `LightingPresets.scenes`; BookStage now does too (`scenes.manual`, cleared with `task.defer` only if
  `LightingController.currentScene() == "manual"`).
- **The set's PointLight lights nothing** (brightness 4.3, 17 and 40; a Neon bulb with its own light over the page too),
  while the same kind of light lit the lobby floor at ground level. Not explained (altitude, the lid, the PBR page are
  suspects), so the set is lit by ambient: rgb(176, 170, 164) with env diffuse 0.5 gives a readable parchment and black
  around it, from the first frame. The sun does not reach the page (the lid). Ambient 0.31 was still near black.
- The colour grade (contrast 0.46 to 0.53 in the meeting) only amplifies a dim page; switching it off is not the fix.
- My first note said 10 names rendered black and 2 names dim: a confounded comparison (I had switched the grade, bloom, depth
  of field and atmosphere off between the runs). Change one thing per run.

**Why it matters:** the Manual shots carry the owner's cause-and-effect beat (the name being written). **How to apply:** a new
shot on a far set needs its own look (`LightingPresets.scenes` + `LightingController.scene`), set before the cut and cleared
after the camera has left; do not trust a lamp in BookStage's set; check a far set's first two seconds and its end in a
play test. The fix is unverified in-game until the owner's Rojo sync (the place's scripts are older; the look was forced
onto `Lighting` on a BookStage copy). Related: [[lighting-rework-2026-11]], [[studio-capture-disturbs-camera]],
[[studio-shared-place-write-blocked]].
