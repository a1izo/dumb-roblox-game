---
name: vfx-rollout-4b-fourth-batch
description: Stage 4b fourth and last emote batch (2026-11-24): the Penned emotes on the new kit (15 flags ON, 11 OFF), a second try at Reaper's Eyes, the LIFT press, Write in the Air and Bunny Ears; report numbers, the pair-shot method that finally gave readable booth pictures, what stayed unseen
---
**Flags in `Vfx/Pilot.luau`, ON:** `twoLeggedBop`, `ratDance`, `boatAura`, `officeParty`, `glitchStep`, `smilingLord`, `excuseMeSirUp` (Excuse Me, Sir: LOOK UP),
`jackpotShuffle`, `lowBattery` (Low Battery and its CHARGE), `impossibleLean`, `itsYou`, `deducing`, `appleBite`, `appleToss`, and `bunnyEars` now with a real head
moment. `writeAir` stays ON, trimmed. **OFF:** `goalCelebration` (new landing is a small ring against the old thud's big floor wave), `excuseMeSir` (the cough: pale mist
on a dark booth, not seen), `animatronicWelcome` (no visible difference), `reapersCackle`, `appleTossThrow`, `chocolateSnap` (dark pieces on the dark booth, not seen),
`fortySeconds` (the new heartbeat showed a white square and lost the red: worse), `twoFingerGrip`, `furiousScribbling` (+ WRITE IT), `puppetDance` (+ Bye Bye Bye) (report
only, no picture taken), `menacingPoses` (the other five Menacing poses: 13 emitters against 12, no better), `reapersEyes` and `blindfoldLiftUp` (second honest tries,
below). Each flag is read at CALL time by `Common.flag(name, fresh, old)` (Shared.luau), written after the old build, which is untouched.
**Where the code is:** the new builds sit at the END of `Dances`, `Poses`, `Props`, `Older`, `Everyone` (a block "The fourth batch, on the new kit"); `Shared` got `flag`,
`beats` (like `accent`, each beat `lead` seconds early, `make(character, lead)`), `soleFrame`, `throwing` (a CFrame whose UP is the throw direction; straight up is
`CFrame.new`, a look along world up is degenerate). `Fresh/Small` got three small accents: `scuff` (a puff and sparks gone inside 0.6 s, for a step every 0.3 s: the
`stepDust` roll lives 2.3 s and 14 emitters pile up at 3 steps a second), `breath` (a thin blown mist, 2 specks, an optional dark thread) and `flecks` (thrown pieces, any
sheet, falling; two emitters). `Catalog` got real hit times for 12 more emotes.
**Report, booth, before to after (reasons; emitters):** Two-Legged Bop 3 reasons to 1 ("2 layers, a loop needs 4"); Rat Dance 3 to 1; Boat Aura 5 reasons, 9 emitters to
PASS, 4; Office Party 4 to 1 (no ignition), 6 emitters, 0% dots; Glitch Step 5 (100% dots) to 1; Smiling Lord 4 to PASS; Excuse Me Sir LOOK UP 7 to PASS; Jackpot Shuffle 6
(20 emitters, 3 lights) to PASS (4, 1); Low Battery 3 to 1 ("no gather"); its CHARGE 7 (28 emitters, 2 lights) to 1; Impossible Lean 3 to 1; It's You 6 (17 emitters, 83
particles) to PASS (4); Deducing 4 to 1; Apple Bite 4 to 1 (4 emitters); Apple Toss 6 (100% dots) to PASS; Bunny Ears (third batch 7 emitters) 6 emitters, 3 layers, 0 lights.
Cancel halfway: leftovers 0 for every ON emote (`fx.leftovers` after `fx.stop`), `fx.verify` 0 problems. Specs against THIS code: the ten that need only the client and Shared (VfxCatalog, VfxMoment, VfxPalette, VfxProbe, VfxRecipes, VfxSheets, VfxTex, Emotes, EmotePolicy; a bundle of src/client + src/shared + the specs with their `StarterPlayer`/`ReplicatedStorage` lookups rewritten to the bundle root, built into Studio's content folder and loaded with GetObjects in the Play client) 103 passed, 0 failed, same as the HEAD build; the specs that WaitForChild a server module (Clips.spec waits for `Services`) hang the runner, so leave them out.
**Second tries.** Write in the Air: dropped the 0.1 s gather tap and made the full stop's star carry no light of its own (the finger lamp flares with it): 13 emitters to 12
(budget 12); lights 3 vs 2 stay, they are the level-2 aura's. Blindfold Lift LIFT: one star between the eyes, none of the stars carry a light: 19 emitters, 4 lights to 16, 3
(still over: the aura), 26% dots to 0, 72 particles to 38; the picture shows no visible difference (the sphere, ring and rim are the old build's) so it stays OFF. Reaper's
Eyes: the glow dots and the recipe glint are gone (two stars made in place), the mist is two held banks not `Fresh.mist`: 20 emitters (budget 20), dots 10% to 0%, lights 2 to 4
(a different count each run, the old build too); the picture shows a white-pink sparkle over the eyes where the old build has two clear red eyes: NOT clearly better, OFF.
Bunny Ears: two soft pastel leaves (VfxFeather, `face = "up"`, pink and blue) flick up off the crown on the beat; the hands' stars are star + sparks only; no ring. A
streak (`VfxStreak`) did not read as an ear at all.
**How to take readable booth pictures (new, 2026-11-24, replaces fighting `fx.at`):** (1) in a Play client load a private copy as in the third-batch note, and add a second
dummy: `FxBooth.play("emote_matchPointServe", {hold=false, backdrop="lit"})` (effect-less, sets the stage), `body:Clone()` PivotTo +6 studs in X. (2) `Pilot.on.x = false;
stopA = EmoteFx.play(body1, clip, false)`, then `Pilot.on.x = true; stopB = EmoteFx.play(body2, clip, false)`: the old build on one dummy and the new on the other in ONE picture.
(3) after `seconds` of real time `Clock.hold(true)`, then call the stops (so no later beat fires on the frozen frame), but NOT for effects whose stop removes the effect
itself (eyes, batteries, auras: keep them). (4) `task.wait` in the same call until past the hold, then `screen_capture` with an explicit camera. (5) do a warm-up shot first:
the first one in a fresh play shows nothing. (6) A held frame is only what existed at the hold: a beat that fires after it is not frozen. (7) After an aura emote release
the clock and wait 4 s or the next picture is full of the fading aura. (8) The dummy FACES -Z: a face effect needs the camera at z < 6000 and from there +X is on the
LEFT of the picture, so the halves are swapped (`save.ps1 -Swap` in the scratch folder; left = before in the saved compare). (9) Studio kept the foreground for a whole
run once the foreground call had been made; a capture needs no foreground call before it every time. The booth backdrop is dark navy and the dummy black: dark effects
(black feathers, dark smoke, brown crumbs, bone paper, pale breath) are invisible in it, which is why seven emotes stay OFF for want of a picture.
**Weak or unseen:** Office Party's paper is not visible in the booth (only its star); the glitch cyan and magenta show only as white-hot stars; Goal Celebration, Reaper's
Cackle, Apple Toss Throw, Chocolate Snap, Two-Finger Grip, Furious Scribbling, Puppet Dance, the Excuse Me Sir cough are not seen; Reduce motion, low graphics and the
phone share were not looked at; `Fresh.breath` and `Fresh.flecks` have no Defs declaration (they are small helpers, like `tap`).
Compare pictures: `art/export/previews/vfx/rollout/<emote>_compare.png` (main checkout, untracked; left before, right after); `_unseen` files are the ones that showed nothing.
