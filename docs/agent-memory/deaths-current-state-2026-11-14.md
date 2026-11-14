---
name: deaths-current-state-2026-11-14
description: What a death is in the game today (3 collapses + the table cutscene + 15 scene deaths) and which older notes and plan lines describe things that no longer exist (the 14 custom deaths, deaths_scenes.py, the five styles)
---

Found 2026-11-14 while taking the Stage 2 inventory ([animation-plan-2026-11](animation-plan-2026-11.md)): the plan and
the older death notes still list parts of the death system that were deleted.

**What exists:**
- `art/scripts/deaths.py`: only `collapseHeart`, `collapseDisease`, `collapseAccident` and `diveCrash` (the rift dive's crash).
  Timing in the generated `src/shared/Anim/DeathTiming.luau` (three entries).
- The table cutscene, `Presentation/Presenters/Death.luau`: the book, then one fixed set of cuts (wide, push, two 0.55 s witness
  cuts, body from above) for the three plain causes; a scene death skips it after the book.
- **15 scene deaths**, each a Luau module in `Presentation/SceneDeaths/` (requiem, blackwall, god, ironMan, sam, walrider, sans,
  patriot, selection from sources; heart, frost, lightning, chip, clock, dark remade from nothing 2026-11-11), their actor clips
  in `art/scripts/scene_actors.py`, sets in the Blender venue Scenes. Every custom death in the shop is one of them
  (`Cosmetics.luau` kind `reason`, field `scene` = seconds). The body of every scene death plays `collapseHeart` (`Causes.CLIP`).
- Reference notes only for the nine sourced scenes: `art/refs/deaths/<style>.md`. God and Iron Man's are the owner's spec, not a
  watched clip; the six remade scenes and the three collapses have none.

**What is gone (do not look for it):** the 14 custom deaths of `deaths.py` (5 removed in `4cec988c`, 6 turned into scene deaths in
`6af353b6`, both 2026-11-11), `art/scripts/deaths_scenes.py` (deleted `915e90eb`, 2026-11-08), `art/scripts/fallen.py` and the
five death styles (deleted `4cec988c`, the owner: "remove death styles completely"), `Presentation/Fallen` styles (only `bodyOf`
is left), the shop death cuts (`Shared/Cinema/DeathCuts.luau` is `return {}`, so `art/scripts/review_deaths.py` renders nothing and
running it rewrites that file), the `CustomDeaths` effect table (empty).

**Why:** the owner kept changing the death system (2026-11-08 scene deaths 1 for 1, 2026-11-10 styles out, 2026-11-11 six more
remade as scenes), and the notes [deaths-2026-11](deaths-2026-11.md) and [deaths-batch2](deaths-batch2.md) were written before.

**How to apply:** before planning death work, read this note and `git log -- art/scripts/deaths.py src/client/Presentation/SceneDeaths`;
the full inventory with measures and marks is in `docs/handoff/animation-inventory-stages-2-4-2026-11-14.md`.
