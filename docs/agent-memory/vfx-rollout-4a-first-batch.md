---
name: vfx-rollout-4a-first-batch
description: Stage 4a first batch (2026-11-18): Aura 1 and 3, Materialize on; two glints and ViewFx off; how the booth sees (or fails to see) old rate-emitter effects
---
Flags in `Vfx/Pilot.luau`: `aura1`, `aura3`, `materialize` ON; `glintGhost`, `glintDive`, `viewfx` OFF (never seen in the game).
Aura level 2 is still the old build (`startOld`); `Aura.start` picks by level and flag. Effect report, booth: level 1 FAIL (17
emitters, 55% dots) to PASS (9 emitters, 2 lights); level 3 FAIL (25 emitters) to PASS (20 emitters, 2 lights); the first report
in a play is a warm-up with a stray 4 lights, read the second.
**Booth trap:** a capture shows ONE good still per play (the Governor goes quiet after a few seconds); and effects made of rate
emitters (the old aura, old Materialize haze) barely show in a still, so before pictures of them understate them. The new aura
feeds its loops by hand (like Fresh/Menace). Disable every PlayerGui ScreenGui first (DGIntro covers the capture), start a fresh
play, bring Studio front, `fx.play(id, {backdrop="lit", camera="close"})`, wait 2.2 s, capture with explicit camera.
Pictures: art/export/previews/vfx/rollout/*_compare.png (main checkout only, untracked).
