---
name: vfx-fresh-report-fixes
description: How the 21 fresh recipes were made to pass the effect report (2026-11-18) and the report traps seen; what the probe can and cannot be trusted for
---
All 21 `recipe_new_*` pass the effect report in the real place (Fx v4 imported). What fixed them:
- A "pop in" needs life over 0.6 s AND first transparency under 0.5 AND first size over a third of the biggest. Sparks, streaks and
  chips now start transparent (`{0,1},{0.08,0}`); one-shot 16-frame sheets live 0.6 s (the minimum is 0.533), not 0.65 to 0.7.
- Emitters alive: impact moves its residue to 0.8 s after the hit (`residueAfter`); dissolve tears every part through three shared
  emitters on one moving holder (hand `Emit`, so counts show as "+N by hand"); arc uses 4 beam pieces per bolt and is judged as a
  showpiece (a beam row counts as an emitter for the whole watch); mist uses many sprites under 8 studs and an ignition burst
  (rate removed from the copy) plus a glint core.
- The biggest-and-brightest layer must start with the hit: keep later layers (residue haze, dark billow) smaller than the hit's.
- Trap: the very first report in a play session can show a stray extra light and an off-beat layer (warm-up); run it again.

**How to apply:** tune a new recipe against `fx.reportAll`; Rojo serves the MAIN checkout, so fast-forward it after pushing.
