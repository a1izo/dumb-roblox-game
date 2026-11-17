---
name: vfx-fresh-recipes
description: The remade recipes live in Presentation/Vfx/Fresh (V2.5, 2026-11-17), beside the old Recipes and FxKit; how to call them, where they are declared, and what the pilot has to add
---
`src/client/Presentation/Vfx/Fresh/` (a folder with `init.luau`; the old `Vfx/Recipes.luau` and `FxKit` are untouched, no
caller uses the new ones yet). Fifteen recipes: `impact` (style sharp, heavy or soft), `slam`, `slash`, `glint`, `pillar`,
`arc`, `charge`, `flame`, `fireBurst`, `smokePuff`, `dustKick`, `mist`, `dissolve`, `scatter` (paper, feathers, shards),
`sigil`. Modules: `Impact` (impact, slam), `Slash`, `Shine` (glint, pillar, arc), `Charge`, `Fire` (flame, fireBurst),
`Smoke` (smokePuff, dustKick, mist), `Scatter` (scatter, dissolve), `Floor` (sigil), `Common` (shared helpers), `Defs`
(pure declarations: textures, moments, parameters, booth variants; `Defs.hitOf`, `Defs.idOf`).

Every recipe is `Fresh.<name>(at, options)` with `ramp` (a Palette ramp; the default is `Palette.WORLD.pale`), built on
`Moment.play`, and returns a cancel; `flame` (set, flare, out, destroy), `charge` (release, cancel) and `mist` (stop, destroy)
return handles. `Vfx/init.luau` does NOT export `Fresh` yet: that one line (`Vfx.Fresh = require(script.Fresh)`) is the pilot's.
The booth lists them as `recipe_new_<variant>` (21 entries, built from `Defs.VARIANTS` in `Catalog.fresh`); spec
`VfxRecipes.spec` reads the declarations and the catalogue (not run: needs Studio).

**Why:** the plan keeps the old effects playing until the owner's verdict on the pilot. **How to apply:** switch a caller
to `Fresh.x` one at a time; add a recipe by writing it in a module, declaring it in `Defs.RECIPES` and `Defs.VARIANTS`, and
exporting it in `Fresh/init.luau`. The effect report per recipe (`DebugPanel.fx.report("recipe_new_impact_sharp")`) has not
been run; flames are listed with the accent budget (their steady state fits the world-loop one, the ignition does not), mist
and the sigil with the showpiece one. Related: [[vfx-moment-envelope]], [[vfx-palette-ramps]], [[vfx-sheets-fallback-grid]],
[[vfx-oneshot-sheet-life]].
