---
name: vfx-rollout-4d
description: Stage 4d (2026-11-25), deaths and gameplay moments on the new VFX kit: which Pilot flags are ON or OFF and why, report numbers, what a booth picture can and cannot show, the spec suite run against the worktree, what was left
---
**Flags in `Vfx/Pilot.luau`** (stage 4d block; each read at call time, old code kept behind each).
ON (report FAIL to PASS and seen in a picture): `diveCrash` (the dive's crash into the roof, `DiveController.crashFx`: old 14 emitters, 25% dots, 4 pops, no
core to PASS with 8 emitters, 0% dots; picture `art/export/previews/vfx/rollout/diveCrash_compare.png`, left old, right new: the new is a clean flat blow with a lit
core, the old a spiked slab with more debris). The impact flag `impact` (DeathFx.burst, V3.1) was already ON.
OFF, built: `deathSparks` (picture: soft ring and a small star against the old hard spiked star, not better), `deathChalkDust` (DeathFx.chalk returns early without
the FxChalk texture, so it was never seen), `deathDissolve` (report 4 reasons to 1, but no picture showed either build: the emitters sit in the black torso),
`deathDust`, `deathPuff`, `deathGlow`, `deathAccident` (DeathVfx's collapses: report only, no picture; heart 4 reasons to 1, accident 5 to 2, disease noisy),
`eyeGlow` (a glint as each eye opens, not photographed), `hauntMist` (seen once: a thin pale roll along the floor against the old fuller puff, not clearly better;
the second try was lost to the Governor), `eyesDealEyes` (not photographed), `eyesDealIgnite` (seen: a bright white star in the middle of the face and the deal's
red lost, so not shipped), `manualFire` and `trialWisp` (guarded: they need `VfxFire`, one of the V1.2 sheets that are NOT in Fx 4, so `Vfx.Tex.real("VfxFire")`
is false and the old flame stays whatever the flag says).
Not changed at all: `CustomDeaths` (its effect table is empty since 2026-11-11, every custom death is a scene death), `RoleMuerto`, staging, timing, cameras.
**Where the code is.** New `Vfx/Fresh/Gameplay.luau` (all the new builds: dissolve as three hand-fed `Small.loop` layers, sparks via `Small.tap`, two-emitter
dust and puffs for the collapses, a three-emitter haunt mist, the crash via `Impact.slam` in the roof's dust, eye stars). Callers: `DeathFx` (sparks, chalk dust,
dissolve), `DeathVfx` (the `glow`, `puff`, `dust` helpers and the accident impact), `World/EyeGlow` (`EyeGlow.light` is now public), `UI/HauntBar` (`HauntBar.mist`
public), `Controllers/DiveController` (new `DiveController.crashFx(floor, normal, speed)`), new `Presentation/EyesDealFx` (the eyes' two effect moments moved
out of `Presenters/EyesDeal`, old code kept inside it), `UI/WorldFx` and `Onboarding/TrialWisp` (guarded branches). The catalogue got entries `death_collapseHeart`,
`death_collapseDisease`, `death_collapseAccident`, `moment_haunt_mist`, `moment_dive_crash`, `moment_eyes_deal_ignite`, `moment_eyes_deal_eyes`, `moment_eye_glow`;
the 4c entries `winfx_<kind>` are now `moment_winfx_<kind>` (the catalogue spec "names each id after its family" had been failing since 4c).
**Report numbers, booth, old to new** (reasons; emitters): death_voted_out 4 reasons to 1; collapseHeart 3 reasons (10 emitters) to 1 (12); collapseDisease 3 to 2
(7 to 16 emitters: the sick breaths are 2 emitters each, 4 of them); collapseAccident 5 reasons (20 emitters) to 2 (12); moment_sparks 6 reasons to 2; haunt mist 2 to 2
(2 to 3 emitters); dive crash FAIL to PASS; eyes ignite 4 to 4 (17 to 18 emitters); eyes of 5 to 2; eye glow 6 to 3 (6 to 10 emitters). Cancel halfway: `fx.leftovers` 0
for the dive crash; `fx.verify` 0 problems, 183 entries. Specs against THIS code (the nine Vfx and Emote specs, bundle in Studio's content folder, run in the Play
client): 103 passed, 0 failed.
**Traps found.** (1) Soft sheets (VfxDustRoll, VfxMist, VfxSmokePuff) need particle transparency 0.1 to 0.3, not 0.35 to 0.6: at 0.5 they vanish in the dark booth.
(2) A flat dust roll (`face = "up"`) seen from a low camera is edge-on and shows nothing; put the camera above 4 studs. (3) The Governor thins the kit after the first
10 to 15 s of a play session: take each pair in a FRESH play (stop, start, wait for the loading cover to go, then set the stage), the third effect in the same play often
shows nothing. (4) After a fresh play start a loading screen can cover the pane for several seconds: a capture then shows only the Roblox buttons on black, wait or
retry. (5) `screen_capture` returns a JPEG file under the session's tool-results folder: convert it with System.Drawing into `<name>_compare.png`. (6) A hand-fed
loop on the body's root (HumanoidRootPart is inside the torso) is hidden in a black dummy booth: aim a loop at a part that stands clear of the body to photograph it.
(7) Pairs for effects that read their flag at several beats (DeathVfx) cannot share one picture: flipping a flag between two plays mixes them, play one after the other.
(8) Shared script folders in a spec bundle: `script.Parent.Parent` replaces both `game:GetService("ReplicatedStorage")` and `game:GetService("StarterPlayer")` when
the bundle has `Shared`, `StarterPlayerScripts/Client` and `Tests` side by side (project in the worktree, deleted after).
**Weak or unseen.** Every OFF above; Low graphics, the phone share and Reduce motion by eye; the voted-out dissolve, the collapses and the stare's eyes in a real match
or cutscene; the haunt mist in a lit map. For the next session: the collapses (one fresh play each, old then new), `eyesDealIgnite` with a red-keeping ramp and no white
core on the middle star, the dissolve aimed at the dummy's shoulders, and `manualFire` / `trialWisp` once the V1.2 fire sheets are imported (a Fx v5).
