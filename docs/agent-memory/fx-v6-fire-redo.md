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

**IMPORTED 2026-11-26 (place v654 saved, not published).** Uploaded from the main checkout's `art/export` (display name `DeathsGambitModels_Fx_v6`, creator userId
1503130900): asset **123679627680169**, operation 6b3a9b22-e026-40d7-8e45-759aaef4c60b, moderation Approved. Two traps new to the steps in [[imports-by-open-cloud]]:
`open_cloud_invoke` with `files` wants `[{name:"fileContent", path, contentType:"model/fbx"}]` and the JSON goes in `body` as `{"request":"<json string>"}`; and the
permission PATCH body is `{subjectType:"Universe", subjectId, action:"Use", requests:[{assetId (a number), grantToDependencies:true}]}` (the v5 note's flat form is
refused: "Invalid SubjectType"). Inserted into ServerStorage, checked (marker `DeathsGambitModelsFx_Version_6`, 49 `Tex_` quads, the four fire sheets), PackageLink removed,
`PivotTo` the old model's pivot (cubes back at O (75.19, -54.00, 88.40), X +64 in x, Y +64 in y), v5 model destroyed, one Fx model in Workspace, shared with the
universe (`successAssetIds [123679627680169]`). In a Play session the Fx model is not in the Client's Workspace (the game moves it): `Tex.real("VfxFire")` and
`"VfxCandle"` read true anyway.

**Flags, seen in the real lobby with the v6 sheets (2026-11-26; private client copy built by rojo into Studio's content folder, stands at about x -5, z 92, camera 3 to
7 studs in front; old `Recipes.flame` left, `Fresh.flame` right):**
- `worldCandle` and `readyCandles` ON. New candle = a defined teardrop with a dark wick dot and an inner glow, flickers frame to frame, about as tall as the old tall
  narrow shard but rounder; the old reads as a plain white cone. Report (booth): `world_candle` FAIL (dots 67%, no ignition burst, 3 layers, no core, 2 lights; 3 particles,
  3 emitters) to `world_candle_fresh` PASS (dots 25%, 2 particles, 3 emitters, 0 lights): not costlier (world loops budget 12 particles, 4 emitters, 0 lights).
  Pictures `worldCandle_v6_compare.png` (scale 0.7, close), `readyCandles_v6_compare.png` (0.55, close), `worldCandle_v6_far_compare.png`.
- `manualFire`, `trialWisp`, `worldBrazier` stay OFF. The v6 fire is one cohesive flame, but in the lobby it is a flat, milky silhouette with a bright heart at its base:
  `LightEmission` 1 (the kit's default) adds the tint to the grey floor and fog, so DANGER red goes pink, amber goes cream, pale stays pale, and the body colour hardly
  matters (a body colour of (110,10,10) looked the same). Alpha-blending the body (LightEmission 0 to 0.5, with brighter colour) gives a brick-brown or salmon paper
  cut-out. The old flame is smaller, with a lit red glow and a white core, and reads as fire. The new stands about 1.5 to 2 times taller at the same scale. Brazier report:
  `world_brazier_fresh` still FAIL ("no dark layer"), old FAIL (41 particles, 6 emitters). Pictures: `manualFire_v6_compare.png`, `trialWisp_v6_compare.png`,
  `worldBrazier_v6_compare.png` (cut from `fire_v6_three_pairs.png`, three pairs, red / amber / pale), `manualFire_v6_tuning_variants.png` (old + body brightness and
  blend variants). The aura's `VfxAuraFlame` tongues were not photographed (a fresh play shot of the aura was not taken).
- **Heart tuning kept** (Fire.luau, kind "fire" only, so the aura and the candle are unchanged): the white-hot layer is `HEART_SIZE` 0.38 of the body (was 0.5),
  `HEART_BRIGHT` 1.5 (was 2.3), colour lerped 35% from ramp[1] toward ramp[2]. It stops the middle whiting out; it does not fix the flat body. Only reachable behind the
  three OFF flags (and the booth's `recipe_new_flame_fire`).
- **What would make the fire work (not done, needs a sheet redraw + import):** a body sheet with real value contrast (dark edges, a lit core gradient, so the additive
  draw shows structure) and a shorter silhouette, tested through the lobby, not through a dark simulation: the simulation in `art/export/previews/vfx/fire_v6/` did not
  predict the grey-floor pink. Also try a cheaper Luau route first: `LightEmission` about 0.5 with a darker, more saturated body colour plus the old recipe's soot layer.
- Trap: `Fresh.flame`'s `set()` runs a 0.3 s tween that calls `apply()` every frame, which re-enables every emitter; edit emitter properties by hand only after it ends.
Checks: stylua and selene clean on Fire.luau; `fx.verify` 0 problems; the nine Vfx and Emote specs against this code (bundle, Play client): 103 passed, 0 failed.
