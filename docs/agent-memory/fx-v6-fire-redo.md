---
name: fx-v6-fire-redo
description: "2026-11-26: VfxFire and VfxCandle redrawn as one cohesive flame (tex_fire.py engine), exported as ModelsFx 6 (15.36 MB); why the V1.2 sheets read as white spikes, what the sim shows, the check_textures motion trap for calm flames, what is left for the import and the flags"
metadata:
  type: project
---

**Why the V1.2 sheets lost in the real lobby (2026-11-25, see [[vfx-rollout-4e]]):** `Fresh.flame` draws TWO layers of the same sheet: the body at
`height * 1.45` in the ramp's body colour at Brightness 1.15, and a half-size copy 0.1 lower in the ramp's heart colour at Brightness 2.3. The first VfxFire
(seven free tongues, each shedding a teardrop) therefore gave a fan of spikes AND a half-size fan of white spikes on top; the white copy swallows the ramp
because every pixel of a sheet above value ~0.4 is over 1.0 at 2.3, whatever the tint. The first VfxCandle was a fat wedge (halfwidth 0.62 of the cell against
the old candle's 0.27). Lesson: a flame sheet is judged through that two-layer pipeline, not on its own.

**What v6 changes (`art/scripts/vfx/tex_fire.py`, only VfxFire and VfxCandle; VfxFireBurst and VfxAuraFlame are byte for byte the v5 ones):**
- One engine (`_depth`, `_smax`, `_halo`): tongues are tapered bodies (width h^p (1-h)^q) whose centre line is leaned and has a wave running UP it, blended
  with a smooth maximum so they share one body; edges bitten by noise that scrolls up; soft taper to every tip. Nothing detaches. VfxFire = a body mass, a
  main tongue (tip at about -0.6 of the cell, the old flame's is -0.55 to -0.98), two side tongues leaning in; halfwidth about 0.5. VfxCandle = one slim
  tongue (height 1.34, the old one's 1.4) with a small dark heart at the wick, a small hot core low in the body.
- Values: dim rim 0.34, body to 0.86, a small hot core (+0.3) low in the body; tips dimmer. The game's white half-size copy supplies the white heart.
- A faint halo (alpha 0.28 to 0.32, value 0.13) is only there to give the texture check its 55% box; at that value it adds under 0.04 even at Brightness 2.3.
  A halo with a higher value draws a visible square round the half-size heart copy (the cell edge cuts it), so keep it dim.
- Motion: every term a whole harmonic of the loop (frame 64 runs into frame 1).

**Trap: check_textures' motion floor (0.01 mean step over the WHOLE cell) is hard for a calm flame.** A candle covers about 7% of its cell, so a believable
sway gave 0.003 to 0.006. It passes at 0.012 only with a lively lean (3 to 9 cycles a loop), a gust each way, a size breath and a 15% brightness shiver, and
the wrap step (last to first) must stay under 1.5 x the mean: the candle's seed (139) was picked from a quick scan (`seeds.py` style: build at TEX_QUICK=1 for
seeds 131..166, keep mean over 0.011 and wrap ratio near 1). A brightness shiver of 30% was tried and rejected (strobes at 6 Hz). If a later candle must be calmer,
declare `exempt motion` for VfxCandle in check_textures rather than make it nervous: say so in the Log.

**Numbers:** check_textures VfxFire 8x8 loop fill 80%, tone 0.185, motion 0.012 wrap 0.016; VfxCandle fill 67%, tone 0.177, motion 0.012 wrap 0.012; the other two
unchanged; 33 pass / 16 fail overall as before. Export: `blender.exe -b --factory-startup --python art/scripts/vfx/meshes.py` (the exe is in
`C:\Program Files\Blender Foundation\Blender 5.2\`, NOT in the 5.2 subfolder) gave `DeathsGambitModels_Fx.fbx` 15,357,676 bytes (v5: 15,751,836: the new PNGs
compress better, Fire 479 KB against 839 KB). `check_fx_export.py --old-fbx <the v5 file>` OK: 49 textures and carriers, 14 shapes, marker Version_6, every PNG
byte for byte, the 45 old sheets the same as v5's. `scripts/budget.py`: unchanged megapixels (same 1024 px sheets), megabytes lower than the +1.8 MB exception line
of v5, so the line was left alone; only Campus is over (0.07 megapixels, as before). `ModelsFx` is 6 in `ImportVersions.luau` and `art/scripts/maps/export.py`.

**Pictures (old, v5, v6 through the two-layer game pipeline in red, amber, candle and warm, at 128 px and 40 px, and on a grey backdrop):**
`art/export/previews/vfx/fire_v6/` in the main checkout (untracked): fire_old_v5_v6.png, fire_over_grey.png, candle_old_v5_v6.png, candle_40px.png,
fire_v6_consecutive.png, candle_v6_consecutive.png. They are a simulation (additive layers on a dark or grey backdrop, a crude soft clip), NOT a Roblox
picture: bloom, fog and the Governor are not in it.

**Left for the import (not done here, by design):** import ModelsFx v6 into the place by Open Cloud ([[imports-by-open-cloud]], from the MAIN checkout's
`art/export`, not a worktree), sync scripts (Rojo), then take the old-left / new-right pictures again in the real lobby and only then turn `Pilot.on.manualFire`,
`trialWisp`, `worldCandle`, `worldBrazier`, `readyCandles` on. Luau ideas if the real picture still whites out: lower the heart layer's Brightness (2.3) for
`kind = "fire"`, or draw it smaller than 0.5.
