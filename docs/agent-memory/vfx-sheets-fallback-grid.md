---
name: vfx-sheets-fallback-grid
description: Emit plays a new flipbook sheet by its declared grid and mode only when Tex.real(name) is true; before the import it uses the old texture's own grid (Vfx/Sheets.luau)
---
Flipbook rules live in `src/client/Presentation/Vfx/Sheets.luau` (pure data, specs in `VfxSheets.spec.luau`), and
`Emit.make` applies them. A one-shot new sheet gets its frame rate from the shortest particle life (frames / life), a
random sheet (or `variants = true`) holds one random cell (loop at 0 fps, random start), a loop starts on a random frame.

**Why:** until the place has Fx v4 a new name wears an old texture (`Tex.FALLBACK`); cutting it by the new grid would show
the wrong cells in the live game.

**How to apply:** give a new sheet's spec just `tex` (and `life`); never pass `grid`/`mode` for it. A new name with no
`Tex.FALLBACK` entry (VfxFire, VfxFireBurst, VfxCandle, VfxAuraFlame until the ModelsFx 5 bump) gets no flipbook before the
import. Old names are untouched.
