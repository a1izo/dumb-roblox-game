---
name: vfx-palette-ramps
description: Vfx/Palette holds the colour ramps {core, body, edge}; an Emit spec takes ramp = in place of color; shop ramps are full colour, world ramps grey
---
`src/client/Presentation/Vfx/Palette.luau`: `Palette.sequence(ramp)` gives three keypoints (core at 0, body at 0.5, edge at 1);
`Emit.make` uses `spec.ramp` over `spec.color`. Ramps: `Palette.rarity(id)` (five tiers, from Rarity.COLORS), `Palette.shop(color)`,
`Palette.emote(clip)` (the AURAS colours of EmoteFx copied in, plus The Long Climb's green; keep them in step, do not change
an emote's colour), `Palette.WORLD.{ash,bone,smoke,soot,dust,pale}` and `Palette.DANGER`. Shop edge = same hue, saturation kept
or raised, value x 0.4, never a grey.

**Why:** the owner, 2026-11-16, "Yes, full colour": shop things wear their own colour at full strength; docs/vfx.md rule 1
(grey world, red = danger) now covers world and gameplay effects only.

**How to apply:** world and gameplay effects take a WORLD ramp (or DANGER); anything bought takes `Palette.rarity` / `emote`
/ `shop`. Specs: `VfxPalette.spec.luau`.
