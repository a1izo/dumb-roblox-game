# Animation inventory: stages 2, 3 and 4 (2026-11-14)

Written by the audit session for [the animation and cutscene plan](animation-cutscene-plan-2026-11-13.md), so that
stages 2 (deaths), 3 (winning cutscenes) and 4 (emotes, base movement) can start the moment the owner clears stage 1.
It is measurement and inventory only. No clip was rebuilt, re-acted, re-exported or changed, and
`art/blend/Animations.blend` was not saved. Everything below was read from the repo at commit `5d417a71` (main on
2026-11-14) and the exported clips in `src/shared/Anim/Clips`.

## 0. Read this first

**The plan's death list is out of date.** The plan (written from older notes) names 14 custom deaths in
`art/scripts/deaths.py`, eight re-enactments in `art/scripts/deaths_scenes.py` and five styles in
`art/scripts/fallen.py`. None of those exist any more (details in section 1.0). What the game has today is three
cause collapses, one death-at-the-table cutscene, five table reaction clips and **fifteen scene deaths** (nine from
sources, six remade from nothing on 2026-11-11). Section 1 inventories that, and the plan's Stage 2 order should be read
against it.

**Tool 1 (the motion report) had not landed when this was written.** The `motion-report` branch
(`refs/heads/claude/motion-report-573df9`) was still at `5d417a71`; its `check_motion.py` existed only as an uncommitted
file in that session's worktree, and that session is listed as failed. I did not use uncommitted work from another session.
So every **Tool 1** column below says `pending`. When the tool is committed: merge it, run it over the clips named in
each table, and fill those columns, the PASS/FAIL and the marks (the marks can only move on evidence).

**Interim numbers.** Until then each table carries three raw numbers read from the exported clips by a small stdlib
script (kept beside the sheets, section 6). They are NOT Tool 1 and carry no PASS/FAIL. They are written
`frozen / hold / root`:

- `frozen`: the longest span (seconds) in which root, neck and both shoulders all stay within 0.6 degrees of where the
  span started (the plan's frozen trait, with the 0.6 degree threshold, but not yet calibrated and not told apart from
  stories that freeze the body on purpose, such as a body lying dead).
- `hold`: how long, counted back from the clip's end, the upper body stays within 6 degrees of its final pose.
- `root`: the root's share of all joint rotation travel in the clip (the plan's torso share, in this rig the root joint).

**Watched in game: not yet.** Nothing here was watched in the game; Roblox Studio was in use by the owner and was not
touched. Every mark is therefore provisional and is based on what the code and data say. The marks are the plan's three
words, with the rule below.

### The bar and the marks

Part 1 of the plan counted RoleMuerto (the bar) at 7 moving cameras, 0 locked, 12 effect events, 13 hands on targets, with a
reference file; RoleAce (the weak one) at 2, 6, 3, 2, none. The same count, as yes/no measures, for a scene:

1. a reference file with eight or more beats;
2. five or more moving or following cameras;
3. at most one locked camera;
4. ten or more effect events;
5. five or more hand placements (arms on targets) in the clips.

(Wins add a sixth: the ending pose holds 1.5 seconds or more, the plan's rule for them. How each count was made is in
section 5.) **Mark rule:** `good` = 4 or more of the measures and a reference file; `re-act` = 2 to 3, or more but no
reference; `rebuild` = 0 to 1. Exceptions are written out where the source itself fixes the camera (sans, Walrider,
Blackwall). Emotes and movement are not scored like this: the plan says do not redo them, so they default to `good` and
only a failing Tool 1 report plus a wrong look in the game moves one.

## 1. Stage 2: deaths

### 1.0 What a death is now

What happened to the plan's list (from `git log`):

- **The 14 custom deaths of `deaths.py`** (really 11 custom deaths and the three collapses; the plan counts the collapses
  twice). `4cec988c` (2026-11-11) removed five: `deathFall` (A long fall), `deathDrown` (Drowned on dry land),
  `deathChandelier`, `deathPages` (A thousand paper cuts), `deathBurn` (Burned from within). `6af353b6` (2026-11-11)
  retired the other six (`deathHeart`, `deathFrost`, `deathLightning`, `deathChip`, `deathClock`, `deathDark`) and
  remade each as a scene death. `deaths.py` now holds only the three collapses and `diveCrash` (the rift dive's
  crash, not a death at the table).
- **The eight re-enactments of `deaths_scenes.py`**: the file was deleted in `915e90eb` (2026-11-08, "scene deaths
  rebuilt 1 for 1"). They are Luau modules in `src/client/Presentation/SceneDeaths/` with their actor clips in
  `art/scripts/scene_actors.py` (plus the ninth, Dead by selection, and the six remade ones).
- **The five styles of `fallen.py`**: deleted in `4cec988c` (the owner, 2026-11-10: "remove death styles completely").
  `Presentation/Fallen.luau` is now only `bodyOf`. `src/shared/Cinema/DeathCuts.luau` is `return {}`, the
  `CustomDeaths` effect table is empty, and `art/scripts/review_deaths.py` has nothing to render (`deathcuts.CUTS = {}`).

How a death plays today (`Presenters/Death.luau`, `Anim/ActingController.luau`):

- A **plain cause** (Heart attack, Disease, Accident): the book opens, then the table cutscene shows the victim playing
  `collapseHeart`, `collapseDisease` or `collapseAccident`, two living players reacting, and the body from above (1.2, 1.3).
- A **custom death** (15 shop causes, every one a scene death): the book opens, then everyone watches that scene's full
  cutscene on a far-off set, then the body where it lies from above under the cause card. The body itself plays
  `collapseHeart` for every one of them (`Causes.CLIP`), so that clip is also what the lying body shows after all 15 scenes.

The plan's Stage 2 order still holds for what is left: 1 the collapses, 2 the table cutscene, 3 and 4 the scene deaths,
5 the styles (gone), 6 the effects. Item 3 ("the 14 custom deaths, worst first by the report") and item 5 no longer have
anything to act on; item 4 ("one for one with the source") now covers all nine sourced scene deaths, and the six remade ones
have no source at all (see below).

### 1.1 Stage 2 ranked, worst first (provisional)

The plan orders Stage 2 by how often a player sees the thing, so the first four are in that order; inside the scene
deaths the order is by the measures of section 1.4. Tool 1 and the in-game watch will reorder this.

| Rank | Item | Kind | Mark | Why (one line) |
|---|---|---|---|---|
| 1 | collapseAccident | plain cause | re-act | no reference file; fastest fall (floor at 0.7 s of 2.3), no hand placed on anything, root only 9% of motion |
| 2 | collapseHeart | plain cause | re-act | no reference file; also the clip the body plays after all 15 scene deaths, so the most seen; 18% root and neck |
| 3 | collapseDisease | plain cause | re-act | no reference file; the richest of the three (333 keys, four coughs, a sit, a roll back) but none of it from film |
| 4 | the death at the table | cutscene | re-act | one fixed set of cuts for every cause; both witness cuts are 0.55 s (the plan asks 1.5 s); no cause-specific camera |
| 5 | dark (Taken by the dark) | scene death | rebuild | 0 of 5 measures: no reference, 1 of 6 cameras moves, 5 effects, no hand placed |
| 6 | clock (Their time ran out) | scene death | rebuild | 1 of 5: no reference, the torso barely acts (root 1.6% of motion), 6 effects |
| 7 | chip, god, patriot | scene death | re-act | 2 of 5 each (see 1.4) |
| 8 | heart, lightning, selection, requiem, sam, frost | scene death | re-act | 3 of 5, or 4 of 5 with no reference (frost) |
| 9 | sans, walrider, blackwall, ironMan | scene death | good | 4 of 5 with a reference, or the source itself fixes the camera (sans, Walrider); watch them first anyway |

### 1.2 The three cause collapses (and the dive crash)

| Clip | Built | Length s | Hits floor / lies still s | Reference | Keys | Hand placements | Effect beats (DeathVfx) | Interim frozen / hold / root | Tool 1 | Watched in game |
|---|---|---|---|---|---|---|---|---|---|---|
| collapseAccident | `art/scripts/deaths.py:191` | 2.3 | 0.7 / 2.3 | none | 205 | 0 | 5 | 0.07 / 0.42 / 9% | pending | not yet |
| collapseHeart | `art/scripts/deaths.py:105` | 2.7 | 1.647 / 2.7 | none | 227 | 13 | 6 | 0.6 / 0.7 / 10% | pending | not yet |
| collapseDisease | `art/scripts/deaths.py:143` | 3.4 | 2.887 / 3.4 | none | 333 | 9 | 7 | 0.02 / 0.05 / 14% | pending | not yet |

- **Effects**: `Presentation/DeathVfx.luau` `BEATS.collapse*` (6, 7 and 5 beats), the shards and chalk outline at the hit
  (`DeathFx.burst`, `DeathFx.chalk`), timing in the generated `src/shared/Anim/DeathTiming.luau`.
- **No reference file.** `art/refs/deaths/` holds the nine scene notes only; the plan asks for film reference for each cause.
- **Seen on the sheet** (`deaths_collapses_front.png`, `deaths_collapses_side.png`, section 4): the three start differently
  inside half a second (a hand clawing in at the chest; a cough with a forearm to the mouth; the arms and a foot flung up),
  which is what the plan asks. The heart attack lies still on the floor for 1.05 s, the accident for 1.6 s, the disease for
  0.5 s (hit 2.887 of 3.4, so the longest build, the shortest rest). Nothing about the acting itself was judged from a sheet.
- Interim `hold` is small for the disease (0.02 s) because its last key rolls the head slowly; the heart attack's is 0.7 s.
- `diveCrash` (1.9 s, `deaths.py`, played by `DiveController`): not a death at the table, listed so nobody counts it twice. Mark: not part of stage 2.

### 1.3 The death at the table, and the reactions

`src/client/Presentation/Presenters/Death.luau` (255 lines). Counted from the code:

| Part | What it does | Count |
|---|---|---|
| Book shot | the Manual alone in the dark, the name and cause written (`ManualTiming.BOOK`) | 1 |
| Victim, first beat | `CameraDirector.cut` to a wide from the front at fov 58 on the clip's first frame, then a push to a close at fov 44 over `hit + 0.45` s, tilted 7 degrees | 1 cut, 1 push |
| Witnesses | two living players picked from the cue id, each a cut at fov 45, `WITNESS` = 0.55 s each | 2 cuts of 0.55 s |
| Body from above | a cut at fov 46 sinking to fov 42 until the end | 1 cut, 1 push |
| Effects | red vignette, red outline and rim light on the victim, the room's lamps dipped, two heartbeats and a flatline, shards and chalk at the hit, the cause card, `DeathVfx` beats (1.2), and on the victim's own screen a screen tear and a desaturate | 11 call sites |
| Scene path | a scene death skips all of that after the book: `SceneDeaths.play`, then one cut and push from above and the card | 1 cut, 1 push |

- The cut lands on the death's first frame (`cue.at` after the book), which is what the plan asks. The camera moves towards where the
  body will lie, from `bodyAt(mark, clip, timing.still)`, but with one wide/close/over set for all three causes.
- **Shots under 1.5 s**: both witness cuts (0.55 s each). Both witness bodies play a reaction clip picked from
  `Activities.REACTIONS` (five clips, a hash of the cue id and the player's id), so two witnesses can match when there are only a few players.

The five reaction clips (also used by arrests and verdicts, `ActingController.reactAround`, 3.6 s window):

| Clip | Length s | Keys | Interim frozen / hold / root | Tool 1 | Watched | Mark | Why |
|---|---|---|---|---|---|---|---|
| reactGasp | 1.6 | 38 | 0.08 / 0.82 / 6% | pending | not yet | good | a plain one-shot; nothing measured says otherwise |
| reactHandsHead | 2 | 72 | 0.1 / 0.42 / 4% | pending | not yet | good | a plain one-shot; nothing measured says otherwise |
| reactCoverMouth | 1.8 | 45 | 0.12 / 1.37 / 2% | pending | not yet | good | a plain one-shot; nothing measured says otherwise |
| reactLookAway | 1.8 | 38 | 0.23 / 1.22 / 10% | pending | not yet | good | a plain one-shot; nothing measured says otherwise |
| reactStartle | 1.2 | 59 | 0.02 / 0.1 / 5% | pending | not yet | good | a plain one-shot; nothing measured says otherwise |

Sheet: `deaths_table_reactions.png`. Mark for the table cutscene itself: **re-act** (the cuts, not the story).

### 1.4 The 15 scene deaths, ranked worst first

All are in `src/client/Presentation/SceneDeaths/<Module>.luau`, run by `init.luau`, and are the shop's custom deaths
(`Cosmetics.luau` kind `reason`). Cameras are counted `moving / following / locked` and effects `screen + VFX`, as
section 5 says. `Hands` is the hand placements in all the scene's actor clips. `Bar` is the five measures of section 0.

| # | Scene | Len s | Reference beats (kind) | Cams moving / following / locked | Effects screen + VFX | Hands | Bar | Mark | Why |
|---|---|---|---|---|---|---|---|---|---|
| 1 | dark | 11 | 0 (none) | 1 / 0 / 5 | 4 + 1 | 0 | 0/5 | rebuild | 0 of 5: no reference, 1 of 6 cameras moves (5 are fixed), 5 effects, no hand placed; keep the idea (yanked into the black, the body gone) |
| 2 | clock | 11 | 0 (none) | 2 / 2 / 1 | 3 + 3 | 3 | 1/5 | rebuild | 1 of 5: no reference, root is 1.6% of all motion (only the limbs act), 6 effects, the walk in ticks has no escalating action |
| 3 | chip | 11 | 0 (none) | 5 / 0 / 1 | 5 + 3 | 4 | 2/5 | re-act | 2 of 5: no reference, 8 effects, 4 hand placements; the big action (the flourish and the bite) is there to keep |
| 4 | god | 17 | 5 (owner's spec only, no clip) | 3 / 0 / 1 | 4 + 8 | 0 | 2/5 | re-act | 2 of 5: reference is the owner's spec only (5 rows), no acted body (the star is the serpent, code-driven), 4 cameras |
| 5 | patriot | 25 | 7 (watched video) | 4 / 1 / 1 | 1 + 3 | 4 | 2/5 | re-act | 2 of 5: 4 effect events in 25 s, reference 7 beats; its 6 cameras (4 drift) are fine |
| 6 | heart | 12 | 0 (none) | 6 / 0 / 1 | 5 + 4 | 13 | 3/5 | re-act | 3 of 5: no reference file; cameras (6 of 7 move), effects (9) and hands (13) are close to the bar |
| 7 | lightning | 10 | 0 (none) | 5 / 0 / 1 | 5 + 11 | 2 | 3/5 | re-act | 3 of 5: no reference, only 2 hand placements; 16 effects |
| 8 | selection | 14 | 7 (owner's chart) | 6 / 0 / 1 | 6 + 3 | 7 | 3/5 | re-act | 3 of 5: reference 7 beats and 9 effects, both just under the bar; 6 of 7 cameras move |
| 9 | requiem | 16.5 | 10 (watched video) | 4 / 1 / 4 | 6 + 11 | 0 | 3/5 | re-act | 3 of 5: 4 of 9 cameras locked, no hand placed (the killer's clip is 34 keys and 122 degrees over 16.5 s, the copies 73 keys) |
| 10 | sam | 14 | 16 (watched video) | 4 / 0 / 5 | 4 + 9 | 24 | 3/5 | re-act | 3 of 5: 5 of 9 cameras locked; the acting is the richest (hands 24, 16 reference rows) |
| 11 | frost | 12 | 0 (none) | 6 / 0 / 0 | 4 + 6 | 10 | 4/5 | re-act | 4 of 5 but no reference file; frozen standing by design (3.4 s) |
| 12 | sans | 30 | 10 (watched video) | 0 / 0 / 1 | 3 + 0 | 0 | 2/5 | good | source is one fixed battle screen: 1 locked camera and 3 effects are the source's own; watch whether 24 s asleep still reads alive |
| 13 | walrider | 21.5 | 12 (watched video) | 1 / 0 / 0 | 7 + 7 | 10 | 4/5 | good | 4 of 5; the source is one first-person ride, so its single moving camera is the source's own; 14 effects; the hand count is the soldiers' (the star's arms are attached to the view by code) |
| 14 | blackwall | 23.3 | 10 (watched video) | 1 / 0 / 0 | 5 + 14 | 19 | 4/5 | good | 4 of 5, a first-person ride like the source; 19 effects and 19 hand placements |
| 15 | ironMan | 18 | 9 (owner's spec and the film's beats, no frame sheet) | 2 / 5 / 2 | 4 + 11 | 7 | 4/5 | good | 4 of 5 with 9 reference rows; the reference is the spec and the film's beats, so a frame sheet is still worth watching |

Ranking inside a mark is by the bar and then by what the numbers above show. For the nine sourced scenes the owner's rule applies
(plan Stage 2 item 4): put the source's frame sheet beside ours, beat by beat, list every difference in pose, timing, framing
and effect, fix the differences, invent nothing. The six remade ones (heart, frost, lightning, chip, clock, dark) have no source
and no reference file: under the plan's loop they need step 3 (a reference, eight beats or more, in `art/refs/deaths/`) before any acting.

### 1.5 Where each scene death is built

| Scene | Shop name | Cosmetic id | Module | Blender set (`art/scripts/maps/venues/scenes/`) | Reference | Actor clips (`art/scripts/scene_actors.py`) |
|---|---|---|---|---|---|---|
| dark | Taken by the Dark | `reason_dark` | `SceneDeaths/Dark.luau` (204 lines) | remade.py | none | sceneDarkVictim |
| clock | Their Time Ran Out | `reason_clock` | `SceneDeaths/Clock.luau` (235 lines) | remade.py | none | sceneClockVictim |
| chip | Choked on a Potato Chip | `reason_chip` | `SceneDeaths/Chip.luau` (233 lines) | remade.py | none | sceneChipVictim |
| god | A GOD.. IS NOT... AFRAID OF... | `reason_god` | `SceneDeaths/God.luau` (461 lines) | none (void or sky only, built in Luau) | `art/refs/deaths/god.md` | none |
| patriot | A true patriot | `reason_patriot` | `SceneDeaths/Patriot.luau` (271 lines) | patriot.py | `art/refs/deaths/patriot.md` | scenePatriotSaluter |
| heart | A Broken Heart | `reason_heart` | `SceneDeaths/Heart.luau` (282 lines) | remade.py | none | sceneHeartVictim |
| lightning | Struck by Lightning | `reason_lightning` | `SceneDeaths/Lightning.luau` (229 lines) | remade.py | none | sceneLightningVictim |
| selection | Dead by selection | `reason_selection` | `SceneDeaths/Selection.luau` (495 lines) | selection.py (+ angel_statue.py) | `art/refs/deaths/selection.md` | sceneSelectionVictim |
| requiem | This is... requiem | `reason_requiem` | `SceneDeaths/Requiem.luau` (397 lines) | none (void or sky only, built in Luau) | `art/refs/deaths/requiem.md` | sceneRequiemCopy, sceneRequiemKiller, sceneRequiemVictim |
| sam | Let's dance! | `reason_sam` | `SceneDeaths/Sam.luau` (637 lines) | sam.py | `art/refs/deaths/sam.md` | sceneSamKiller, sceneSamVictim |
| frost | Frozen Where They Stood | `reason_frost` | `SceneDeaths/Frost.luau` (226 lines) | remade.py | none | sceneFrostVictim |
| sans | heh, didja really think- | `reason_sans` | `SceneDeaths/Sans.luau` (365 lines) | none (void or sky only, built in Luau) | `art/refs/deaths/sans.md` | sceneSansVictim |
| walrider | Walrider | `reason_walrider` | `SceneDeaths/Walrider.luau` (682 lines) | walrider.py | `art/refs/deaths/walrider.md` | sceneWalriderSeated, sceneWalriderSoldier |
| blackwall | Blackwall gateway | `reason_blackwall` | `SceneDeaths/Blackwall.luau` (1096 lines) | blackwall.py | `art/refs/deaths/blackwall.md` | sceneBlackwallBystander, sceneBlackwallVictim |
| ironMan | and I.. am.. | `reason_ironman` | `SceneDeaths/IronMan.luau` (482 lines) | ironman.py | `art/refs/deaths/ironman.md` | sceneIronKiller, sceneIronSoldier, sceneIronVictim |

Shared pieces: `init.luau` (the context, 25.8 KB), `Sets.luau` (builds the cell's meshes), `Cast.luau` and `Costumes.luau` (extras in
marketplace costumes). The Scenes venue puts one set per cell 1000 studs apart (`plan.py`: patriot 0 through dark 11000); requiem, god
and sans have no Blender set. Skies come from `art/scripts/scene_skies.py`.

### 1.6 Every actor clip of the scene deaths

| Clip | Built | Length s | Keys | Hand placements | Interim frozen / hold / root | Tool 1 | Watched |
|---|---|---|---|---|---|---|---|
| sceneBlackwallBystander | `scene_actors.py:187` | 23.3 | 353 | 0 | 5.02 / 5.1 / 11% | pending | not yet |
| sceneBlackwallVictim | `scene_actors.py:132` | 23.3 | 609 | 19 | 0.9 / 0.47 / 10% | pending | not yet |
| sceneChipVictim | `scene_actors.py:752` | 11 | 431 | 4 | 1.37 / 2.1 / 10% | pending | not yet |
| sceneClockVictim | `scene_actors.py:807` | 11 | 217 | 3 | 3.18 / 4 / 2% | pending | not yet |
| sceneDarkVictim | `scene_actors.py:836` | 11 | 483 | 0 | 0.28 / 0.2 / 8% | pending | not yet |
| sceneFrostVictim | `scene_actors.py:680` | 12 | 442 | 10 | 3.42 / 4.22 / 13% | pending | not yet |
| sceneHeartVictim | `scene_actors.py:636` | 12 | 299 | 13 | 1.68 / 1.83 / 10% | pending | not yet |
| sceneIronKiller | `scene_actors.py:511` | 18 | 252 | 0 | 0.52 / 3.07 / 11% | pending | not yet |
| sceneIronSoldier | `scene_actors.py:544` | 18 | 32 | 0 | 1.5 / 8.38 / 15% | pending | not yet |
| sceneIronVictim | `scene_actors.py:464` | 18 | 248 | 7 | 0.22 / 0.92 / 11% | pending | not yet |
| sceneLightningVictim | `scene_actors.py:716` | 10 | 508 | 2 | 2.13 / 3.27 / 9% | pending | not yet |
| scenePatriotSaluter | `scene_actors.py:562` | 25 | 109 | 4 | 1 / 10.47 / 8% | pending | not yet |
| sceneRequiemCopy | `scene_actors.py:108` | 16.5 | 73 | 0 | 0.98 / 3.32 / 13% | pending | not yet |
| sceneRequiemKiller | `scene_actors.py:116` | 16.5 | 34 | 0 | 1 / 9.05 / 6% | pending | not yet |
| sceneRequiemVictim | `scene_actors.py:85` | 16.5 | 218 | 0 | 0.5 / 3.77 / 14% | pending | not yet |
| sceneSamKiller | `scene_actors.py:275` | 14 | 525 | 11 | 1.5 / 0.58 / 13% | pending | not yet |
| sceneSamVictim | `scene_actors.py:223` | 14 | 544 | 13 | 1.72 / 1.05 / 14% | pending | not yet |
| sceneSansVictim | `scene_actors.py:424` | 30 | 315 | 0 | 1.18 / 2.22 / 7% | pending | not yet |
| sceneSelectionVictim | `scene_actors.py:586` | 14 | 89 | 7 | 0.92 / 3.88 / 8% | pending | not yet |
| sceneWalriderSeated | `scene_actors.py:412` | 21.5 | 37 | 0 | 1.5 / 21.5 / 0% | pending | not yet |
| sceneWalriderSoldier1 | `scene_actors.py` (a loop) | 21.5 | 80 | - | 0.98 / 5.6 / 13% | pending | not yet |
| sceneWalriderSoldier2 | `scene_actors.py` (a loop) | 21.5 | 93 | - | 1.1 / 5.62 / 6% | pending | not yet |
| sceneWalriderSoldier3 | `scene_actors.py` (a loop) | 21.5 | 202 | - | 0.8 / 4.4 / 22% | pending | not yet |
| sceneWalriderSoldier4 | `scene_actors.py` (a loop) | 21.5 | 105 | - | 1.12 / 5.48 / 10% | pending | not yet |

A long `frozen` or `hold` is expected in a clip that ends with the body lying dead (Blackwall's bystander 5.0 s, the heart
scene's victim 1.7 s) or stands frozen by the story (frost 3.4 s, clock 3.2 s). Only Tool 1's calibrated `frozen` and the watch can
say which are faults. The clips with very few keys over their length are the ones to check first: `sceneRequiemKiller` (34 keys, 16.5 s),
`sceneWalriderSeated` (37 keys, 21.5 s), `sceneIronSoldier` (32 keys, 18 s), `sceneRequiemCopy` (73 keys). Several are background people on purpose.

### 1.7 Effects (plan Stage 2 step 6)

- The table cutscene's effects are in 1.3; the per-cause beats are `DeathVfx` (6, 7, 5 beats), each built from `glow`, `pulse`,
  `dust`, `puff`, a light flash and a short shake. The plan's test (a beat on the clip's `fx` moment, a beginning, peak and decay, light on
  the body and floor, something left behind) is partly there: the chalk outline and shards at the hit are the thing left behind.
- The scene deaths carry their own effects (screen and VFX counts in 1.4); `CustomDeaths.luau` and the old per-death effect
  table are empty. `docs/vfx.md` is the house style.
- The scenes with the fewest VFX events are sans (0 VFX, 3 screen, the source's own), dark (1 VFX), patriot (3), chip (3), selection (3) and
  clock (3). Whether a given effect is "one emitter and a flash" needs the in-game watch.

### 1.8 Sheets for the worst few (section 4 has the paths)

`deaths_collapses_front.png` and `_side.png` (all three collapses, 12 frames each), `deaths_scene_remade_victims.png` (the six remade victims),
`deaths_scene_referenced_victims.png` (the sourced ones), `deaths_table_reactions.png`. Seen on the remade sheet: frost's victim stands rigid
for the last five of twelve frames; clock's ends leaning on its feet, not falling; dark's body is carried out of frame; lightning's and
heart's victims fall flat and lie still for the rest.

## 2. Stage 3: the eight winning cutscenes

Cut data: `src/shared/Cinema/WinCuts.luau` (one entry each, 8.0 s, played by `Presentation/WinCinema`); star clips:
`art/scripts/emotes/wins.py`. **No win cutscene has a reference file** (`art/refs/` has no wins; the emote notes `newWorld.toml` and the like
are for the emotes of those names). Counted as in Part 1: cameras `moving / locked` (a shot with a `to` drift or a `glide` is moving), `Events`
the `events` list, `Beats` the screen beats (flash, still, shake), `Hands` the placements in the clip.

| # | Cut | Clip | Built | Len s | Room | Cams moving / locked | Events + beats | Sounds | Hands | Keys | Interim frozen / hold / root | Bar | Tool 1 | Watched | Mark | Why |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | checkmateCoven | `winCheckmateCoven` | `wins.py:387` | 8 | roofrain | 4 / 3 | 3 + 4 | 4 | 3 | 135 | 0.37 / 1.65 / 27% | 1/6 | pending | not yet | rebuild | 1 of 6: 3 of 7 cameras locked, 3 events, 3 hand placements; the action is a finger flick, a small gesture |
| 2 | newWorld | `winNewWorld` | `wins.py:125` | 8 | rooftop | 4 / 0 | 2 + 3 | 4 | 2 | 165 | 0.28 / 0.8 / 5% | 1/6 | pending | not yet | rebuild | 1 of 6: only 2 events and 2 hand placements for the Godhood prize, the arms are still moving at the end (hold 0.8 s) |
| 3 | checkmate | `winCheckmate` | `wins.py:200` | 8 | hall | 4 / 1 | 4 + 3 | 4 | 3 | 90 | 0.35 / 0.8 / 6% | 1/6 | pending | not yet | rebuild | 1 of 6: 4 events, 3 hand placements, ends moving (hold 0.8 s); one finger tips the king |
| 4 | finalPageBureau | `winFinalPageBureau` | `wins.py:244` | 8 | archive | 5 / 0 | 12 + 3 | 6 | 27 | 162 | 0.27 / 0.93 / 8% | 4/6 | pending | not yet | re-act | 4 of 6 and no reference: ends straightening into the light (hold 0.9 s) |
| 5 | newWorldBureau | `winNewWorldBureau` | `wins.py:303` | 8 | steps | 6 / 0 | 18 + 3 | 4 | 6 | 134 | 0.23 / 1.38 / 10% | 4/6 | pending | not yet | re-act | 4 of 6 and no reference; hold 1.4 s, just under 1.5; 18 events |
| 6 | caseClosedCoven | `winCaseClosedCoven` | `wins.py:350` | 8 | den | 5 / 1 | 17 + 3 | 4 | 20 | 107 | 0.38 / 1.47 / 16% | 4/6 | pending | not yet | re-act | 4 of 6 and no reference; hold 1.5 s is on the line; 17 events |
| 7 | caseClosed | `winCaseClosed` | `wins.py:162` | 8 | office | 4 / 0 | 10 + 2 | 6 | 5 | 78 | 0.23 / 1.53 / 15% | 4/6 | pending | not yet | re-act | 4 of 6 and no reference; the clip is small (382 degrees of motion in 8 s) |
| 8 | finalPage | `winFinalPage` | `wins.py:74` | 8 | writer | 4 / 0 | 9 + 4 | 6 | 19 | 94 | 0.25 / 2.03 / 16% | 4/6 | pending | not yet | re-act | 4 of 6 and no reference; the smallest clip (275 degrees in 8 s: write, shut, lean back) |

What each cut is (one line):

- `checkmateCoven`: Diavolo on a roof in the rain, the white king flicked over the parapet.
- `newWorld`: Coven, Godhood: walks to a roof's edge, the Manual opened, arms spread over the dying city.
- `checkmate`: Bureau, Godhood: up to a giant black king, tips it with one finger.
- `finalPageBureau`: Ace at the archive: last page burned on a match, the book sealed in an evidence bag.
- `newWorldBureau`: Ace on the courthouse step, the Manual raised high over the press.
- `caseClosedCoven`: Diavolo in the armchair, the case file thrown on the fire, laughing.
- `caseClosed`: Bureau, Sealed: crouched on a chair, strings snap, the stamp slammed.
- `finalPage`: Coven, Sealed: the last name written, the Manual shut, leaning back as the candles die.

- **The ending pose.** The plan wants it held 1.5 s or more while the winning side's name is written in. Measured on the clips,
  the interim `hold` (within 6 degrees of the final pose) is below 1.5 s for five of the eight (newWorld 0.8, checkmate 0.8,
  finalPageBureau 0.9, newWorldBureau 1.4, caseClosedCoven 1.5 borderline); finalPage (2.0), checkmateCoven (1.7) and caseClosed (1.5) pass.
  `WinCinema` keeps the last frame only `TAIL` = 0.35 s after the cut.
- **The name card is not timed to the ending.** In a match `Presenters/Outro.luau` plays the cut from the cue's start with the
  typewriter `"<side> wins"` card (`Cinema.card`, y 0.74) on screen from the first second until the cut is stopped (`firstShot` seconds in), then goes on to the
  written names. If the owner wants the name written in on the ending pose, that is a change in `Outro.luau`, not in the cuts.
- **Pairs that share a base** (Bureau and Coven): each of the eight already has its own clip, its own room (writer, rooftop, office,
  hall, archive, steps, den, roof in the rain), its own props and its own grade, so the plan's "own ending pose, grade and effect"
  is met in the data; whether each ending reads as a still picture is a watch item.
- Sheets: `wins/newWorld/sheet.png`, `wins/checkmate/sheet.png`, `wins/finalPageBureau/sheet.png`, `wins/checkmateCoven/sheet.png` (the star in the set through
  each shot's start, middle and end; `review_win.py` does not draw the events).

## 3. Stage 4: emotes, then base movement

### 3.1 The first five and the frozen lengths

All five of Wave, Point, Cheer, Laugh and Dance are length-frozen: they copy Roblox's classic `/e` recordings (`art/refs/classic/*.json`,
built by `art/scripts/emotes/free.py` through `classic.py`) and cutscenes, tableaux and the note hand-off play them at fixed times.
`art/scripts/check_refs.py` (`FROZEN`) freezes **nine** lengths, the five and four more:

| Clip | Frozen length s | Plays as | Source | Interim frozen / hold / root | Length frozen? |
|---|---|---|---|---|---|
| wave | 2.4 | one-shot | Roblox classic | 0.03 / 0 / 1% | frozen |
| point | 1.6 | one-shot | Roblox classic | 0.05 / 0 / 10% | frozen |
| cheer | 2.2 | one-shot | Roblox classic | 0.02 / 0.07 / 2% | frozen |
| laugh | 1.2 | loop | Roblox classic | 0 / 0.1 / 4% | frozen |
| dance | 1.6 | loop | Roblox classic | 0 / 0 / 0% | frozen |
| salute | 2 | one-shot | footage (mocap) | 0.08 / 0.07 / 7% | frozen |
| bow | 2.6 | one-shot | footage (mocap) | 0.17 / 0.32 / 24% | frozen |
| shrug | 2 | one-shot | footage (mocap) | 0.07 / 0.2 / 14% | frozen |
| facepalm | 2.4 | one-shot | footage (mocap) | 0.05 / 0 / 6% | frozen |

Whatever Stage 4 does to Wave, Point, Cheer, Laugh or Dance (and salute, bow, shrug, facepalm) must keep these lengths; a re-act
changes the poses, not the clock.

### 3.2 The 70 emotes, ranked worst first (interim)

All 70 have a reference file (`art/refs/emotes/<clip>.toml`, a source and a date watched); 52 have written beats, 13 name a mocap
take, 7 are Roblox classic recordings (wave, point, cheer, laugh, dance, dance2, dance3), 64 are status `checked` and 6 `authored` (chipAndPen, griddy, justAsPlanned,
matchPointServe, puppetPop, smilingLord: built but not put through `check_refs.py`'s checked state). `check_anims.py` reports 0 failed
clips (its strict set is the movement set; every emote only gets an `info` line, in `check_anims_all.txt`).

**The ranking is interim.** It sorts by the interim `frozen` span, longest first, then by least motion per second. It is weak on
purpose: no emote has a frozen span over 1.1 s (the plan flags 2.5 s), so the order mostly finds held poses and the stroll standing
loops, which hold still by design while the runtime life layer breathes. Tool 1 replaces it. Per the plan every emote is marked `good`
until a failing report **and** a wrong look in the game say otherwise (the owner rated the emotes far above the cutscene acting on 2026-10-27).

| # | Clip | Family | Built | Len s | Plays as | Keys | Ref beats | Source | Ref status | Interim frozen / hold / root | Motion deg/s | Tool 1 | Watched | Mark | Why |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `notMyProblem` | stroll | `anims_emotes.py:773` | 3 | loop | 61 | 0 | video reference | checked | 1.07 / 1.43 / 6% | 79 | pending | not yet | good | a stroll; the walk cycle is a separate clip; reference has no written beats |
| 2 | `paradeMarch` | stroll | `anims_emotes.py:742` | 3.2 | loop | 232 | 0 | video reference | checked | 0.7 / 0.78 / 1% | 432 | pending | not yet | good | a stroll; the walk cycle is a separate clip; reference has no written beats |
| 3 | `menacingPose` | pose | `anims_emotes.py:382` | 4 | loop | 25 | 1 | video reference | checked | 0.67 / 4 / 19% | 6 | pending | not yet | good | pose, video reference |
| 4 | `itsYou` | pose | `emotes/poses.py:188` | 2.6 | one-shot | 107 | 1 | video reference | checked | 0.67 / 0.02 / 9% | 295 | pending | not yet | good | pose, video reference |
| 5 | `think` | older | `emotes/older.py:152` | 4 | loop | 25 | 1 | video reference | checked | 0.65 / 0.68 / 23% | 9 | pending | not yet | good | older, video reference |
| 6 | `animatronicWelcome` | dance | `emotes/dances.py:246` | 9.6 | loop | 386 | 3 | video reference | checked | 0.57 / 0 / 7% | 179 | pending | not yet | good | dance, video reference |
| 7 | `cuffedLead` | duo | `anims_emotes.py` (built by name in a loop) | 2 | loop | 3 | 0 | video reference | checked | 0.48 / 2 / 0% | 4 | pending | not yet | good | one half of a duo; reference has no written beats |
| 8 | `justAsPlanned` | pose | `emotes/poses.py:25` | 9.2 | one-shot | 332 | 3 | video reference | authored | 0.42 / 0.08 / 10% | 184 | pending | not yet | good | status authored (not yet checked) |
| 9 | `deducing` | pose | `emotes/poses.py:313` | 4 | loop | 38 | 1 | video reference | checked | 0.38 / 0.22 / 13% | 27 | pending | not yet | good | pose, video reference |
| 10 | `glitchStep` | dance | `emotes/dances.py:366` | 2.4 | loop | 177 | 1 | video reference | checked | 0.37 / 0.2 / 9% | 1255 | pending | not yet | good | dance, video reference |
| 11 | `lowBattery` | pose | `emotes/poses.py:254` | 4.6 | one-shot | 128 | 1 | video reference | checked | 0.33 / 1.48 / 14% | 78 | pending | not yet | good | pose, video reference |
| 12 | `mushroomStroll` | stroll | `anims_emotes.py:763` | 3 | loop | 25 | 0 | video reference | checked | 0.3 / 1.33 / 12% | 19 | pending | not yet | good | a stroll; the walk cycle is a separate clip; reference has no written beats |
| 13 | `appleToss` | prop | `emotes/props.py:362` | 3.6 | one-shot | 117 | 0 | video reference | checked | 0.27 / 1.03 / 8% | 118 | pending | not yet | good | reference has no written beats |
| 14 | `boatAura` | dance | `emotes/dances.py:178` | 6.4 | loop | 272 | 3 | video reference | checked | 0.27 / 0.03 / 5% | 288 | pending | not yet | good | dance, video reference |
| 15 | `impossibleLean` | pose | `emotes/poses.py:102` | 4.2 | one-shot | 75 | 1 | video reference | checked | 0.25 / 0.5 / 19% | 117 | pending | not yet | good | pose, video reference |
| 16 | `smilingLord` | dance | `anims_emotes.py:791` | 4.8 | loop | 244 | 1 | video reference | authored | 0.25 / 0.03 / 28% | 358 | pending | not yet | good | status authored (not yet checked) |
| 17 | `newWorld` | pose | `emotes/poses.py:382` | 6.5 | one-shot | 94 | 1 | video reference | checked | 0.23 / 0.07 / 4% | 86 | pending | not yet | good | pose, video reference |
| 18 | `goalCelebration` | dance | `emotes/dances.py:134` | 3 | one-shot | 271 | 2 | video reference | checked | 0.23 / 0.2 / 19% | 671 | pending | not yet | good | dance, video reference |
| 19 | `theEyebrow` | pose | `emotes/poses.py:171` | 3.4 | one-shot | 46 | 1 | video reference | checked | 0.22 / 0.08 / 12% | 51 | pending | not yet | good | pose, video reference |
| 20 | `fortySeconds` | prop | `emotes/props.py:307` | 4.6 | one-shot | 90 | 0 | video reference | checked | 0.22 / 0.3 / 6% | 81 | pending | not yet | good | reference has no written beats |
| 21 | `blindfoldLift` | prop | `emotes/props.py:331` | 4 | loop | 41 | 0 | video reference | checked | 0.18 / 0.38 / 23% | 29 | pending | not yet | good | reference has no written beats |
| 22 | `hairTwirl` | pose | `emotes/poses.py:444` | 2.4 | loop | 27 | 1 | video reference | checked | 0.17 / 2.4 / 41% | 8 | pending | not yet | good | pose, video reference |
| 23 | `chairPerch` | prop | `emotes/props.py:134` | 4 | loop | 21 | 0 | video reference | checked | 0.17 / 1.2 / 47% | 10 | pending | not yet | good | reference has no written beats |
| 24 | `footScratch` | pose | `emotes/poses.py:430` | 2 | loop | 24 | 1 | video reference | checked | 0.17 / 2 / 25% | 16 | pending | not yet | good | pose, video reference |
| 25 | `bow` | free | `emotes/free.py:106` | 2.6 | one-shot | 59 | 2 | video reference | checked | 0.17 / 0.32 / 24% | 66 | pending | not yet | good | length frozen |
| 26 | `chip` | older | `emotes/older.py:105` | 3.4 | one-shot | 79 | 3 | video reference | checked | 0.17 / 0.45 / 9% | 129 | pending | not yet | good | older, video reference |
| 27 | `chipAndPen` | prop | `emotes/props.py:42` | 10.4 | one-shot | 315 | 5 | video reference | authored | 0.17 / 0.1 / 8% | 158 | pending | not yet | good | status authored (not yet checked) |
| 28 | `sugarTower` | prop | `emotes/props.py:159` | 6 | one-shot | 111 | 0 | video reference | checked | 0.15 / 0.88 / 14% | 73 | pending | not yet | good | reference has no written beats |
| 29 | `diceTower` | prop | `emotes/props.py:215` | 6 | one-shot | 138 | 0 | video reference | checked | 0.15 / 0.8 / 15% | 170 | pending | not yet | good | reference has no written beats |
| 30 | `puppetDance` | older | `emotes/older.py:252` | 2 | loop | 228 | 2 | video reference | checked | 0.13 / 0.28 / 4% | 477 | pending | not yet | good | older, video reference |
| 31 | `twoFingerGrip` | prop | `emotes/props.py:477` | 3 | loop | 18 | 0 | video reference | checked | 0.12 / 1.15 / 22% | 22 | pending | not yet | good | reference has no written beats |
| 32 | `nahIdWin` | pose | `emotes/poses.py:137` | 4 | loop | 47 | 1 | video reference | checked | 0.12 / 0.3 / 23% | 40 | pending | not yet | good | pose, video reference |
| 33 | `strawberryOnTop` | prop | `emotes/props.py:402` | 4 | one-shot | 111 | 0 | video reference | checked | 0.12 / 0.18 / 8% | 139 | pending | not yet | good | reference has no written beats |
| 34 | `coinFlip` | older | `emotes/older.py:190` | 3 | one-shot | 137 | 4 | video reference | checked | 0.12 / 0.02 / 8% | 187 | pending | not yet | good | older, video reference |
| 35 | `twoWeeksNotice` | dance | `emotes/dances.py:392` | 3.2 | one-shot | 418 | 2 | video reference | checked | 0.12 / 0.67 / 7% | 921 | pending | not yet | good | dance, video reference |
| 36 | `aceCrouch` | older | `emotes/older.py:177` | 4 | loop | 38 | 2 | video reference | checked | 0.1 / 0.52 / 27% | 25 | pending | not yet | good | older, video reference |
| 37 | `salute` | free | `emotes/free.py:78` | 2 | one-shot | 121 | 2 | video reference | checked | 0.08 / 0.07 / 7% | 184 | pending | not yet | good | length frozen |
| 38 | `writeAir` | older | `emotes/older.py:288` | 3 | one-shot | 125 | 1 | video reference | checked | 0.08 / 0.02 / 11% | 244 | pending | not yet | good | older, video reference |
| 39 | `finalBreakdown` | pose | `emotes/poses.py:349` | 5.4 | one-shot | 376 | 2 | video reference | checked | 0.08 / 0.07 / 13% | 375 | pending | not yet | good | pose, video reference |
| 40 | `shrug` | free | `emotes/free.py:129` | 2 | one-shot | 72 | 1 | mocap | checked | 0.07 / 0.2 / 14% | 125 | pending | not yet | good | length frozen |
| 41 | `appleBite` | older | `emotes/older.py:222` | 2.8 | one-shot | 126 | 3 | video reference | checked | 0.07 / 0.03 / 11% | 200 | pending | not yet | good | older, video reference |
| 42 | `highFive` | duo | `emotes/duos.py:120` | 2 | one-shot | 108 | 0 | video reference | checked | 0.07 / 0.08 / 7% | 269 | pending | not yet | good | one half of a duo; reference has no written beats |
| 43 | `chocolateSnap` | prop | `emotes/props.py:425` | 3.2 | one-shot | 144 | 0 | video reference | checked | 0.05 / 0.27 / 9% | 177 | pending | not yet | good | reference has no written beats |
| 44 | `facepalm` | free | `emotes/free.py:141` | 2.4 | one-shot | 78 | 2 | mocap | checked | 0.05 / 0 / 6% | 195 | pending | not yet | good | length frozen |
| 45 | `jackpotShuffle` | dance | `emotes/dances.py:111` | 2.8 | loop | 189 | 2 | mocap | checked | 0.05 / 0.03 / 13% | 245 | pending | not yet | good | dance, mocap |
| 46 | `point` | free | `anims.py:112` | 1.6 | one-shot | 79 | 1 | Roblox classic | checked | 0.05 / 0 / 10% | 261 | pending | not yet | good | length frozen |
| 47 | `handshake` | duo | `emotes/duos.py:140` | 2.4 | one-shot | 75 | 0 | video reference | checked | 0.03 / 0.05 / 7% | 125 | pending | not yet | good | one half of a duo; reference has no written beats |
| 48 | `jawlineCheck` | pose | `emotes/poses.py:150` | 3.2 | one-shot | 83 | 1 | video reference | checked | 0.03 / 0.38 / 4% | 155 | pending | not yet | good | pose, video reference |
| 49 | `reapersEyes` | pose | `emotes/poses.py:410` | 3.2 | one-shot | 68 | 1 | video reference | checked | 0.03 / 0.4 / 5% | 173 | pending | not yet | good | pose, video reference |
| 50 | `theLongClimb` | stroll | `anims_emotes.py:728` | 1.84 | loop | 91 | 0 | video reference | checked | 0.03 / 0.03 / 0% | 325 | pending | not yet | good | a stroll; the walk cycle is a separate clip; reference has no written beats |
| 51 | `wave` | free | `anims.py:222` | 2.4 | one-shot | 134 | 2 | Roblox classic | checked | 0.03 / 0 / 1% | 344 | pending | not yet | good | length frozen |
| 52 | `preDawnBonk` | prop | `emotes/props.py:448` | 3.6 | one-shot | 226 | 0 | video reference | checked | 0.03 / 0.05 / 9% | 405 | pending | not yet | good | reference has no written beats |
| 53 | `dance2` | older | `emotes/older.py:15` | 2.167 | loop | 277 | 2 | Roblox classic | checked | 0.03 / 0.02 / 5% | 541 | pending | not yet | good | older, Roblox classic |
| 54 | `furiousScribbling` | prop | `emotes/props.py:266` | 2.4 | loop | 81 | 0 | video reference | checked | 0.02 / 0.05 / 10% | 104 | pending | not yet | good | reference has no written beats |
| 55 | `matchPointServe` | duo | `emotes/duos.py` (built by name in a loop) | 0.8 | loop | 47 | 4 | video reference | authored | 0.02 / 0.2 / 28% | 111 | pending | not yet | good | status authored (not yet checked); one half of a duo |
| 56 | `excuseMeSir` | dance | `emotes/dances.py:290` | 1.6 | loop | 85 | 1 | video reference | checked | 0.02 / 0.08 / 15% | 219 | pending | not yet | good | dance, video reference |
| 57 | `bunnyEars` | dance | `emotes/dances.py:98` | 1.455 | loop | 126 | 1 | mocap | checked | 0.02 / 0.03 / 10% | 280 | pending | not yet | good | dance, mocap |
| 58 | `puppetPop` | dance | `emotes/dances.py:52` | 7.63 | loop | 901 | 16 | mocap | authored | 0.02 / 0.07 / 13% | 646 | pending | not yet | good | status authored (not yet checked) |
| 59 | `officeParty` | dance | `emotes/dances.py:232` | 6.4 | loop | 780 | 3 | mocap | checked | 0.02 / 0.02 / 16% | 857 | pending | not yet | good | dance, mocap |
| 60 | `cheer` | free | `emotes/free.py:46` | 2.2 | one-shot | 304 | 2 | Roblox classic | checked | 0.02 / 0.07 / 2% | 1082 | pending | not yet | good | length frozen |
| 61 | `laugh` | free | `emotes/free.py:55` | 1.2 | loop | 101 | 1 | Roblox classic | checked | 0 / 0.1 / 4% | 141 | pending | not yet | good | length frozen |
| 62 | `dance` | free | `emotes/free.py:70` | 1.6 | loop | 154 | 2 | Roblox classic | checked | 0 / 0 / 0% | 454 | pending | not yet | good | length frozen |
| 63 | `twoLeggedBop` | dance | `emotes/dances.py:339` | 2.4 | loop | 244 | 1 | video reference | checked | 0 / 0.07 / 11% | 455 | pending | not yet | good | dance, video reference |
| 64 | `griddy` | stroll | `emotes/strolls.py:24` | 3.45 | loop | 313 | 4 | mocap | authored | 0 / 0.02 / 8% | 558 | pending | not yet | good | status authored (not yet checked); a stroll; the walk cycle is a separate clip |
| 65 | `reapersCackle` | pose | `emotes/poses.py:331` | 1.6 | loop | 242 | 1 | video reference | checked | 0 / 0.03 / 11% | 669 | pending | not yet | good | pose, video reference |
| 66 | `theClassic` | dance | `emotes/dances.py:64` | 6 | loop | 645 | 3 | mocap | checked | 0 / 0 / 8% | 707 | pending | not yet | good | dance, mocap |
| 67 | `ratDance` | dance | `emotes/dances.py:123` | 1.132 | loop | 150 | 1 | mocap | checked | 0 / 0.05 / 9% | 756 | pending | not yet | good | dance, mocap |
| 68 | `takeTheL` | dance | `emotes/dances.py:74` | 1.6 | loop | 229 | 2 | mocap | checked | 0 / 0.02 / 10% | 806 | pending | not yet | good | dance, mocap |
| 69 | `bouncePump` | dance | `emotes/dances.py:86` | 6.486 | loop | 903 | 2 | mocap | checked | 0 / 0.02 / 12% | 937 | pending | not yet | good | dance, mocap |
| 70 | `dance3` | older | `emotes/older.py:26` | 1.6 | loop | 192 | 3 | Roblox classic | checked | 0 / 0 / 37% | 1252 | pending | not yet | good | older, Roblox classic |

### 3.3 The worst fifteen (interim), to watch first

The first fifteen rows of the table above, with the reason each is on the list. They are candidates to watch, not faults.

| # | Clip | Len s | Longest frozen span s (at t) | Motion deg/s | Note |
|---|---|---|---|---|---|
| 1 | `notMyProblem` | 3 | 1.07 at 1.93 | 79 | stroll standing loop; held on purpose |
| 2 | `paradeMarch` | 3.2 | 0.7 at 2.47 | 432 | stroll standing loop |
| 3 | `menacingPose` | 4 | 0.67 at 1.98 | 6 | a 4 s breathing pose loop, 26 degrees of motion in total |
| 4 | `itsYou` | 2.6 | 0.67 at 0.55 | 295 | a pointed pose with a 0.7 s hold at 0.55 s and no hold at the end |
| 5 | `think` | 4 | 0.65 at 1.72 | 9 | L's crouch loop, 35 degrees in 4 s |
| 6 | `animatronicWelcome` | 9.6 | 0.57 at 0 | 179 | a 9.6 s dance with a held opening |
| 7 | `cuffedLead` | 2 | 0.48 at 0.92 | 4 | 3 keys in 2 s, the duo leader's loop |
| 8 | `justAsPlanned` | 9.2 | 0.42 at 8.08 | 184 | a 9.2 s Godhood cutscene emote, status authored, a 0.4 s hold mid-clip |
| 9 | `deducing` | 4 | 0.38 at 2.62 | 27 | a seated pose loop |
| 10 | `glitchStep` | 2.4 | 0.37 at 1 | 1255 | a 2.4 s dance with a held opening beat |
| 11 | `lowBattery` | 4.6 | 0.33 at 1.92 | 78 | a pose with a 1.4 s still end |
| 12 | `mushroomStroll` | 3 | 0.3 at 2.2 | 19 | stroll standing loop |
| 13 | `appleToss` | 3.6 | 0.27 at 2.78 | 118 | a prop emote, a 0.3 s hold |
| 14 | `boatAura` | 6.4 | 0.27 at 5.67 | 288 | a 6.4 s dance, a hold near the end |
| 15 | `impossibleLean` | 4.2 | 0.25 at 2.93 | 117 | a pose, a short hold |

Sheet of the most still ones: `emotes_worst_candidates.png` (notMyProblem, paradeMarch, itsYou, menacingPose, think, cuffedLead). For the full
`review_emote.py` render with props (stills and a video) the clip name goes after `--`; it writes to `art/export/previews/emotes/`, which is gitignored.

### 3.4 Base movement

`docs/animation.md`: the style the owner approved (fluid R6, limbs slide as well as turn, serious, slouched walk, driven run) is not
to be changed. `python art/scripts/check_anims.py --quiet` over the movement set today: **0 clips failed** (soles do not slide, nothing
below the floor, no gap at the hip, clean seams, no joint over 900 degrees a second). The plan's order for looking for stiffness is the
order below, so it is also the ranking (least checked and most seen first). All marks are `good` until Tool 1 and the in-game watch.

| Order (plan Stage 4) | Clip | Len s | Plays as | check_anims | Slide studs | Peak deg/s | Interim frozen / hold / root | Tool 1 | Watched | Mark |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 Strafes and backward (least checked) | `walkBack` | 1.05 | loop | ok | 0.019 | 367/s | 0.07 / 0.12 / 3% | pending | not yet | good |
| 1 Strafes and backward (least checked) | `walkLeft` | 1.05 | loop | ok | 0.011 | 372/s | 0.1 / 0.1 / 3% | pending | not yet | good |
| 1 Strafes and backward (least checked) | `walkRight` | 1.05 | loop | ok | 0.008 | 375/s | 0.1 / 0.1 / 3% | pending | not yet | good |
| 1 Strafes and backward (least checked) | `runBack` | 0.64 | loop | ok | 0.013 | 619/s | 0.03 / 0.03 / 3% | pending | not yet | good |
| 1 Strafes and backward (least checked) | `runLeft` | 0.64 | loop | ok | 0.016 | 619/s | 0.02 / 0.03 / 2% | pending | not yet | good |
| 1 Strafes and backward (least checked) | `runRight` | 0.64 | loop | ok | 0.015 | 619/s | 0.02 / 0.03 / 2% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `startStep` | 0.36 | one-shot | ok | - | 374/s | 0.03 / 0.12 / 18% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `stopLeft` | 0.62 | one-shot | ok | - | 262/s | 0.03 / 0.27 / 13% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `stopRight` | 0.62 | one-shot | ok | - | 262/s | 0.03 / 0.27 / 13% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `jump` | 0.5 | one-shot | ok | - | 707/s | 0 / 0.02 / 4% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `jumpApex` | 1.2 | loop | ok | - | 17/s | 0.1 / 1.2 / 12% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `fall` | 1.6 | loop | ok | - | 26/s | 0.13 / 0.3 / 4% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `fallLong` | 1 | loop | ok | - | 91/s | 0.03 / 0.08 / 5% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `landLight` | 0.3 | one-shot | ok | - | 123/s | 0.02 / 0.3 / 18% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `landNormal` | 0.5 | one-shot | ok | - | 393/s | 0 / 0.05 / 14% | pending | not yet | good |
| 2 Handovers: set off, stop, air, land | `landHeavy` | 0.9 | one-shot | ok | - | 674/s | 0.02 / 0.05 / 11% | pending | not yet | good |
| 3 Forward walk and run, from behind | `walk` | 1.05 | loop | ok | 0.019 | 368/s | 0.07 / 0.08 / 4% | pending | not yet | good |
| 3 Forward walk and run, from behind | `run` | 0.64 | loop | ok | 0.011 | 637/s | 0 / 0.03 / 3% | pending | not yet | good |
| 4 Idles and fidgets | `idle` | 24 | loop | ok | - | 8/s | 2.03 / 24 / 14% | pending | not yet | good |
| 4 Idles and fidgets | `idleGuarded` | 24 | loop | ok | - | 28/s | 2.4 / 13.42 / 14% | pending | not yet | good |
| 4 Idles and fidgets | `idleLook` | 3.4 | one-shot | info | - | 105/s | 0.15 / 0.2 / 20% | pending | not yet | good |
| 4 Idles and fidgets | `idleWatch` | 3.2 | one-shot | info | - | 140/s | 0.9 / 0.07 / 6% | pending | not yet | good |
| 4 Idles and fidgets | `idleTie` | 2.8 | one-shot | info | - | 238/s | 0.6 / 0.05 / 1% | pending | not yet | good |
| 4 Idles and fidgets | `idleNeck` | 3 | one-shot | info | - | 49/s | 0.12 / 0.82 / 4% | pending | not yet | good |
| 4 Idles and fidgets | `idleSleeve` | 2.6 | one-shot | info | - | 128/s | 0.2 / 0.08 / 4% | pending | not yet | good |
| 4 Idles and fidgets | `idleHandsBack` | 4.2 | one-shot | info | - | 63/s | 0.18 / 0.13 / 10% | pending | not yet | good |
| 4 Idles and fidgets | `idleGlance` | 2.2 | one-shot | info | - | 208/s | 0.58 / 0.08 / 21% | pending | not yet | good |
| 4 Idles and fidgets | `idleArmsCross` | 4 | one-shot | info | - | 121/s | 0.35 / 0.05 / 2% | pending | not yet | good |
| 4 Idles and fidgets | `idleHand` | 2.8 | one-shot | info | - | 108/s | 0.12 / 0.07 / 4% | pending | not yet | good |
| 4 Idles and fidgets | `idleRoom` | 4.4 | one-shot | info | - | 31/s | 0.12 / 0.2 / 31% | pending | not yet | good |
| 5 Seated and flying | `sit` | 8 | loop | ok | - | 24/s | 0.9 / 1.17 / 23% | pending | not yet | good |
| 5 Seated and flying | `flyHover` | 4 | loop | info | - | 7/s | 0.2 / 1.23 / 12% | pending | not yet | good |
| 5 Seated and flying | `flyGlide` | 2.4 | loop | info | - | 12/s | 0.43 / 2.4 / 13% | pending | not yet | good |
| 5 Seated and flying | `flyRise` | 2 | loop | info | - | 10/s | 0.42 / 2 / 8% | pending | not yet | good |
| 5 Seated and flying | `flyDive` | 2 | loop | info | - | 10/s | 0.42 / 2 / 6% | pending | not yet | good |

- Every one of these is built in `art/scripts/locomotion.py` (cycles, handovers, idles, fidgets, sit, flying; `art/scripts/gait.py` is the arithmetic);
  played by `src/client/Anim/LocomotionController.luau` with `Locomotion/Pose.luau`, `Locomotion/Feet.luau` and `Shared/Anim/Gait.luau`.
- **Turning on the spot** has no clip: it is the controller (the body lags its root up to 25 degrees, the head leads, the feet step after).
  `turnLeft` and `turnRight` are in `check_anims.py`'s strict set but not in the exported index. It can only be judged in the game.
- The idle's interim numbers (idle: frozen 2.0 s, idleGuarded 2.4 s, 24 s loops with 2.5 to 3.4 keys a second) are the slow breathing by design;
  twelve people standing in a meeting not moving in step is a runtime question (random start points) that no clip number answers.
- Sheets, from behind as the game's camera sees them: `movement_handovers_from_behind.png` (startStep, stopRight, stopLeft, landNormal,
  landHeavy, jump, jumpApex, fall) and `movement_strafes_back_from_behind.png` (walk, walkBack, walkLeft, walkRight, run, runBack,
  runLeft, runRight). From behind the arms read as small hanging blocks in the walks and as a wide V in the run, but whether the torso
  twist and the head steadiness read at 18 studs is a watch item, not something a still sheet shows.

## 4. Contact sheets (uncommitted, outside the repo)

Rendered with the repo's own review scripts through Blender 5.2 in the background, their preview folder redirected so nothing is
written in the repo. Folder: `C:\Users\user\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_556673c9-7214-4c9a-bf5c-2f0366d61099\stages-2-4-sheets`

| Sheet | What | Script |
|---|---|---|
| `deaths_collapses_front.png`, `deaths_collapses_side.png` | collapseHeart, collapseDisease, collapseAccident, 12 frames each, from 35 and 90 degrees | `review_anims.py` |
| `deaths_scene_remade_victims.png` | the six remade victims: heart, frost, lightning, chip, clock, dark (no reference file) | `review_anims.py` |
| `deaths_scene_referenced_victims.png` | requiem, Blackwall, Sam, sans, Iron Man, selection victims and the patriot's saluter | `review_anims.py` |
| `deaths_table_reactions.png` | the five table reaction clips | `review_anims.py` |
| `wins/newWorld/sheet.png`, `wins/checkmate/sheet.png`, `wins/finalPageBureau/sheet.png`, `wins/checkmateCoven/sheet.png` | the star in its set through each shot of four of the worst win cutscenes (events and effects not drawn) | `review_win.py` |
| `emotes_worst_candidates.png` | six of the interim worst emotes, 12 frames each | `review_anims.py` |
| `movement_handovers_from_behind.png`, `movement_strafes_back_from_behind.png` | the handovers and the strafe and backward cycles from behind | `review_anims.py` |

`review_deaths.py` was not run: it renders the shop's death scenes from `deathcuts.CUTS`, which is empty now, and running it rewrites
`src/shared/Cinema/DeathCuts.luau`. `review_emote.py` (props and stills per emote) was not run: the plain sheets above were enough for an inventory.

## 5. How the counts were made

- **Scene deaths (Luau).** Cameras: `ctx:shot(t, eye, look, fov, { to })` with a `to` table = moving (a drift); `ctx:camera(t0, t1, function(t))`
  whose function uses its time argument = moving (a ride); `ctx:shot` whose eye or look is a function = following (tracks an actor from a
  fixed offset); a `ctx:shot` with plain points or a `ctx:camera` that ignores its time = locked. A locked-looking `ctx:camera` may still
  follow an actor, because it reads the actor's live position. Effects: screen = `Cinema.flash`, `Cinema.still`, `Vfx.Screen.shake`, `ctx:grade`,
  `ctx:focus`, `Cinema.tint`; VFX = `Vfx.Emit.burst/make/point`, `Vfx.Light.*`, `Vfx.Beams.*`, `Vfx.Recipes.*`, `SceneDeaths.emit` (continuous
  emitters count once). Text lines (`ctx:say`) are not counted. Hands: `reach(` calls plus uses of module-level reach constants in the clip's
  block in `scene_actors.py` (approximate: helper functions are not followed).
- **Wins.** From `WinCuts.luau`: shots, the `events` and `beats` lists, sounds; hands from `wins.py` the same way.
- **Emotes.** Reference beats = `[[beat]]` entries in the toml; built-in file = the file under `art/scripts/emotes/` that holds the `Motion`
  (later imports override `anims_emotes.py` and `anims.py`, the older versions); keys = exported keys over all joints.
- **Muerto for comparison** (the plan): 7 moving, 0 locked, 12 effect events, 13 hands, a reference.

## 6. What was not done or not seen, and how to refresh this

- **Not watched in the game at all** (the owner had Studio open; no Studio, screen or MCP use). So no in-game fault list, no sloppy checklist,
  no time stamps; every `Watched` column says `not yet`.
- **Tool 1 numbers and PASS/FAIL**: pending (section 0). Merge the `motion-report` branch when its commit message starts `Tool 1 (motion report):`,
  run it over the clips of each table (names are in the tables), replace the interim columns, then re-rank.
- Contact sheets show poses, not timing or effects; no spacing strips (Tool 2) or silhouette checks (Tool 3) were used.
- The hands counts are approximate (section 5). The in-game cameras that follow an actor read as `locked` in the count.
- The scripts that made the numbers (`collect.py`, `interim.py`, `gen_doc.py`) are in `C:\Users\user\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_556673c9-7214-4c9a-bf5c-2f0366d61099\stages-2-4-tools`, outside the repo.

