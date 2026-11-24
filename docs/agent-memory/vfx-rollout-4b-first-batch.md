---
name: vfx-rollout-4b-first-batch
description: Stage 4b first batch (2026-11-24): Aura 2, Menacing Pose, New World, Just As Planned, Final Breakdown on; Reaper's Eyes off; flags, report numbers, how the booth stills were taken
---
Flags in `Vfx/Pilot.luau`: `aura2`, `menacing`, `newWorld`, `justAsPlanned`, `finalBreakdown` ON; `reapersEyes` OFF (one emitter and one
light more than the old build, no clearly better look). Aura level 2 = `startFresh` with the floor ring and pool (eight loop
emitters, no lower bank, no crescents; crescents are level 3's). Menacing's new menace has `lean = Pilot.on.aura2`: only the floor
bank and the star, no light (the aura has them). Report, booth, before to after: aura2+menacing 24 emitters / 2-4 lights to 13 / 2
(still FAIL by one emitter); New World 20/3 lights, dots 16% to 20/4, dots 3%, pops gone; Just As Planned 22/5 to 20/4, dots 19% to
3%; Final Breakdown 21/5 to 20/3 (only the guessed-hit line left). All Godhood hits are guesses (`hit=1`), so "VfxGlint 0.7 s off" is
the aura's beat, not a fault. Flip flags at run time in a play test: `require(PlayerScripts...Pilot).on.x = true`.
Pictures: art/export/previews/vfx/rollout/<emote>_compare.png (main checkout, untracked). Trap: Studio loses the foreground between
tool calls and then the capture is a dark frame with Roblox's buttons: re-do the foreground call (ShowWindow + Alt tap +
SetForegroundWindow) before each capture. A first capture of a play may understate the old effect; re-take in a fresh play.
