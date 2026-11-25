---
name: vfx-rollout-4e
description: Stage 4e (2026-11-25), the world on the new VFX kit and the guarded fire flags seen with the real Fx 5 sheets: every flag stays OFF (why, with numbers), what was not changed (LampHaze, AirFx, rain, MapAmbient) and how the pictures were taken in the real lobby
---
**Task 1, the fire flags with the real sheets (Fx 5 in the place, `Tex.real("VfxFire")` true in a private client copy).** Pictures are in
`art/export/previews/vfx/rollout/` (main checkout, untracked; left = old, right = new):
- `manualFire` OFF. Left `Recipes.flame` red, right `Fresh.flame` with `Palette.DANGER` (`manualFire_compare.png`) and with a redder ramp and scale 0.75
  (`manualFire_tuned_compare.png`): the new is a fan of white spikes with pink fringes, the white-hot layer (bright 2.3) swallows the red, and it stands
  about twice as tall as the old one at the same scale. The old reads as a red flame. Not better.
- `trialWisp` OFF (`trialWisp_compare.png`): new = detached white teardrops, amber lost; the old is one cohesive flame (both burn to white in the lobby's grey).
- `writeFire` stays ON (`writeFire_compare.png`, old left, new right, mid-write): the new is a sheaf of many fine orange-brown tongues that reads as burning,
  a little muddy brown on the cream page; the old a smooth orange blob. Not worse, so left ON; the brown is a taste call.
- The aura's `VfxAuraFlame` tongues: only one picture (`aura_flame_real.png`, level 2 on the player in the lobby, front view, 40 s into the play): a purple
  haze round the body, the tongues not distinct. NOT judged; the Governor had thinned the loops. The flags stay as they were.

**Task 2, the world (flags in `Vfx/Pilot.luau`, read when a flame is stood; old code kept): all three OFF.**
- Code: `World/Flames` (`worldCandle`, `worldBrazier`), `World/ReadyCircle` (`readyCandles`, with the SAME lamp: `Fresh.flame` got `lightRange`, `lightBrightness`,
  `lightColor` options so nothing about the light changes) and a new `plain` option on `Fresh.flame` (only the body and the white-hot heart: no wandering
  sparks, no soot thread). `Catalog` has `world_candle_fresh` and `world_brazier_fresh` (plain builds) beside `world_candle` / `world_brazier`.
- Report (booth, per flame): old candle FAIL (3 particles, 3 emitters, 67% dots, no core) / full kit candle PASS (8 particles, 5 emitters with its light; 4 without)
  / plain kit candle PASS (2 particles, 3 emitters, 0 lights, 25% dots). Old brazier FAIL (41 particles, 6 emitters, 50% dots) / plain kit brazier 2 particles,
  3 emitters, one reason ("no dark layer", by design). The lobby holds 1 mapped candle and 12 ready candles (unlit ones cost nothing); case maps hold more.
- Pictures: `worldCandle_compare.png`, `worldCandle_close_compare.png` (old left: a leaning white wedge of glow; plain new right: a bright rounder flame with a halo,
  about equal, not clearly better). The full kit candle (`worldCandle_close_compare.png`, taken before the plain build) is crisper (a defined teardrop) but costs
  3 to 8 particles, so worse on cost. `worldBrazier_compare.png` / `worldBrazier_three_compare.png` (old, full new, plain new at scale 1.6): the new is a wider,
  taller fan of separate pale spikes, more detail but like floating teardrops, and a bigger footprint in the lit realm: not clearly better. So no flag is on. To try
  later: a candle with only the soot thread kept (3 emitters), or the brazier at scale 1.2.
- NOT changed, and why: `LampHaze` (the shaft is a Beam, not a particle; the dust motes are 0.07-stud dots with life 8 s, about 13 alive per lamp: a mist sheet cannot
  stand in for a mote and would cost more), `AirFx` (the Tokyo neon haze is meant to be barely there, transparency 0.94: a texture swap to `VfxMist` at equal count shows no
  difference in a picture, `airFxHaze_unclear.png`), `RainController` (weather textures with no kit equivalent), `MapAmbient` (its emitters are made by the server's map
  pipeline, out of scope). Frame time was not measured in a full lobby: nothing that ships changes it; the report rows above are the cost measure.

**Checks.** stylua and selene clean on the six files; `fx.verify` 0 problems; the nine Vfx and Emote specs against this code (bundle recipe in
[[vfx-rollout-4d]]): 103 passed, 0 failed.

**Traps found.** (1) The captured Studio loses the foreground within seconds and the kit stops drawing (15 fps: every steady flame vanishes, old and new
alike): run the front-window script again right before each capture, and if a stand shows nothing, re-front and capture again before blaming the build.
(2) `screen_capture` with an explicit camera shows a stage 6000 studs out as pure black in a play session; stands put in the real lobby (near the player, floor
about y 8.2 at x -5, z 92) photograph fine with an explicit camera, and the lobby's own fog gives the true grey. (3) A camera inside the player's body shows a
jacket: put it above and behind (y 14, z 102) or in front. (4) The fire writing style can be seen by running the private `Styles.write` on a page in a ScreenGui
with `Pilot.on.writeFire` flipped between runs; it needs a pace of 0.35 to 0.6 s per letter or the capture misses the front of the flame.
