---
name: vfx-rollout-4b-third-batch
description: Stage 4b third batch (2026-11-24): Write in the Air, Blindfold Lift, Ace's Crouch, Chair Perch, Chip and Pen, Strawberry on Top, Sugar Tower (Sealed) and Bunny Ears (Penned) on the new kit; flags, report numbers, how the booth was run from a repo bundle, what stayed weak
---
Flags in `Vfx/Pilot.luau`: `writeAir`, `blindfoldLift`, `aceCrouch`, `chairPerch`, `chipAndPen`, `strawberryOnTop`, `sugarTower`, `bunnyEars` ON;
`blindfoldLiftUp` (the LIFT press, same Props function) OFF because it was only run through the report, never seen. Old code stays behind each flag.
Edits: `EmoteFx/Older.luau` (chip and pen, write in the air, the interview room shared by Ace's crouch and Chair Perch: the lamp and its shaft are
unchanged, the dust became ash flakes + a floor haze with a dark layer, plus a lamp glint and a floor ring at the start), `EmoteFx/Props.luau`
(blindfold, strawberry, sugar tower: `towerFx` got a `sugar` argument), `EmoteFx/Dances.luau` (bunny ears). No new Fresh file: everything is
`Fresh.tap` / `glint` / `dustKick` / `smokePuff` / `Small.loop`. `Vfx/Catalog.luau`: real hits for chipAndPen 7.05, writeAir 2.3, blindfoldLiftUp 0.9,
sugarTower 1.1 (+1.4 for Add/Topple), so the report judges the real beat.
Report, booth, before to after (reasons): Write in the Air FAIL to FAIL (dots 25% to 0, pops gone, 181 to 119 particles; left: 14 emitters vs 12 and
3 lights vs 2, which is the level-2 aura's ten emitters, plus the guessed hit); Blindfold Lift FAIL (13 emitters) to PASS (12, 2 lights); Chair Perch and Ace's
Crouch FAIL (no ignition, 2 layers, no core) to PASS (9 emitters, 2 lights); Chip and Pen 5 reasons (no gather, pops, no core) to 1 (the biggest layer is the desk's
dust roll at 8.95 s, by design; the last two runs also counted 4 lights vs 2, the first two counted 2); Strawberry on Top FAIL (100% dots) to PASS; Sugar Tower FAIL (100% dots, no light) to PASS, Add PASS, Topple 10
emitters vs 6; Bunny Ears 17 emitters, 83% dots, 4 reasons to 7 emitters (budget 6), 0% dots, 1 reason. The LIFT (blindfoldLiftUp) is still FAIL by the aura (18 emitters, 4 lights).
Cancel halfway: leftovers 0 for all eight (chair and ace destroy their dust holders at once; no delayed cleanup).
**How the booth ran new code without Rojo having it:** Rojo serves the main checkout, a worktree's edits are not in the place. Build `src/client` to an
rbxm in Studio's `content` folder (`rojo build <project json with a Folder > Client $path src/client> -o ...\content\dgx_client_N.rbxm`, a NEW name per build:
Studio caches the path), then in the Play CLIENT `execute_luau`: `local root = game:GetObjects("rbxasset://dgx_client_N.rbxm")[1]`,
`require(root.Client.Debug.FxBooth)` and `require(root.Client.Presentation.Vfx.Pilot)` give a private copy of the whole client with your edits; call
`fx.report`, `fx.at`, `fx.play`, `fx.stop`, `fx.leftovers`, `fx.verify` (0 problems) on it and flip `Pilot.on.x` on that copy. Nothing is written to the place.
Delete old rbxm files from `content` after.
**Stills:** (1) `fx.at(id, s)` holds `s` seconds AFTER the catalogue hit (a negative number works for a loop's ignition). (2) The `DGIntro` ScreenGui covers
the screen in a fresh play: `PlayerGui.DGIntro.Enabled = false`. (3) The lit navy look and every loop/beam show only in the first play state; after a few
seconds the booth is dark and grey and rate loops and the lamp shaft vanish, so take before and after each in a FRESH play (stop and start play, front the
window, warm up with one other emote, then the shot). (4) A `fx.at` of a 7 s hit needs a 9 s wait before the capture. Compare pictures are
`art/export/previews/vfx/rollout/<emote>_compare.png` (main checkout, untracked; left = before, right = after); `aceCrouch_compare.png` is a copy of the
Chair Perch one (the two share the build).
**Weak or unseen:** the pastel pink/blue of Bunny Ears' sparks is mostly in the sparks and halo (the star cores are white-hot), and the head ring was dropped for the
budget; the Chair Perch after still did not show the lamp shaft (the beam exists, one in both builds, but did not render in that frame) so the pair is not a
clean like for like; the Chip and Pen before still showed nothing at the bite; Write in the Air's line of stars and the aura were not seen over a full write; the
LIFT, Reduce motion, low graphics and the phone share were not looked at.
