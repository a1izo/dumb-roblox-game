---
name: vfx-rollout-4b-second-batch
description: Stage 4b second batch (2026-11-24): Cuffed Together, The Long Climb, Griddy, Mushroom Stroll (Condemned), Pre-Dawn Bonk, Dice Tower (Sealed) on the new kit; flags, report numbers, how steps and loops are tested in the booth
---
Flags in `Vfx/Pilot.luau`: `cuffedLead`, `theLongClimb`, `griddy`, `mushroomStroll`, `preDawnBonk`, `diceTower` all ON. New module
`Vfx/Fresh/Small.luau` (`Fresh.tap`, `Fresh.stepDust`, `Fresh.spores`, `Fresh.Small.loop`): the small accents for things that fire
every step or beat (a full `Fresh.impact` piles up past the emitter budget at two a second). Match Point has no effect in
`EmoteFx` (its racket pock is `EmoteFx.pock`), so it was not touched; Sugar Tower still has the old build (only Dice passes `useFresh`).
Report, booth, before to after: Cuffed FAIL (4 reasons, 100% dots, 4 emitters, 0 lights) to PASS (9 emitters, 1 light); Long Climb 4
reasons (1 layer, no ignition, no core) to 1 ("pops out: other", kept from before), 6 emitters, 16 layers; Griddy and Mushroom Stroll
"nothing recorded" (steps are footfalls; the booth fires none) to PASS when steps are fed; Bonk 6 reasons, 18 emitters to 5, 10
emitters (what is left is the guessed hit at 1.0 s against the real blow at 2.55 s); Dice Tower 6 reasons to 3. Cancel halfway:
leftovers 0 after stop for all six (The Long Climb's mist holder is in the kit's folder and goes at once).
**How to test a stroll in the booth:** `fx.play("emote_griddy", ...)` then `LocomotionController.Footfall:Fire(dummy)` every 0.4 s
(moving the dummy with `PivotTo` between steps) and `fx.step(0.01)` to hold; for the report run the same feeder in a second thread.
**Traps:** (1) the first booth state after a fresh play is the lit navy one; after ~10 s the scene goes grey and quiet, soft puffs and
dust vanish: take each still FIRST in its play. (2) Emitters parked inside the body (an Attachment on the root) are hidden by it:
loops ride a part of the kit (`Vfx.Emit.point`, 5 x 0.1 x 5 studs) that a `Clock.every` moves to the feet. (3) `fx.at` ends an emote at
its catalogue length (3 s for The Long Climb): hold at hit + 1.4 or earlier. (4) On the booth path `fx.at("emote_theLongClimb")` did
not show the loop emitters but `EmoteFx.play` on the dummy did (cause not found); judge it with a direct call after `fx.play` of an
effect-less entry (`emote_matchPointServe`) that sets the stage.
Pictures: `art/export/previews/vfx/rollout/<emote>_compare.png` (left = before, right = after; main checkout, untracked).
