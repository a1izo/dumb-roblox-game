# Animation inventory: stages 2, 3 and 4 (2026-11-14)

Written by the audit session for [the animation and cutscene plan](animation-cutscene-plan-2026-11-13.md), so that
stages 2 (deaths), 3 (winning cutscenes) and 4 (emotes, base movement) can start the moment the owner clears stage 1.
It is measurement and inventory only. No clip was rebuilt, re-acted, re-exported or changed, and
`art/blend/Animations.blend` was not saved. Read from the repo at `5d417a71` (main on 2026-11-14), the exported clips in
`src/shared/Anim/Clips`, and Tool 1 (`art/scripts/check_motion.py`, commit `ae5e3669`, merged into this branch).

## 0. Read this first

**The plan's death list is out of date.** The plan names 14 custom deaths in `art/scripts/deaths.py`, eight re-enactments in
`art/scripts/deaths_scenes.py` and five styles in `art/scripts/fallen.py`. None of those exist any more (section 1.0). What the
game has today is three cause collapses, one death-at-the-table cutscene, five table reaction clips and **fifteen scene deaths**
(nine from sources, six remade from nothing on 2026-11-11). Section 1 inventories that; read the plan's Stage 2 against it.

**Tool 1 numbers are in.** Every clip below was run through `check_motion.py` (with `--json`; scene clips, win clips and reaction
clips by name, `--emotes`, `--movement`). The **Tool 1** columns give PASS or FAIL and the failing traits; the `T1` tables give
the numbers per trait. The report is a floor: failing it means a clip is not done, passing it says nothing about missing hand
targets or locked cameras. Its limits (from the tool): frozen over 2.5 s, one dead joint over 8 s, torso share under 4%, glides over
2.5 s, mirrored arms over half of 2 s or more of held poses, anticipation under 15% of big moves, slow snaps over 35%, metronome
of 5, one timing for 60% of moves. Loops are not judged on repeating, emotes not on mirrored poses, the movement set on freezing alone.
A scene's extras (killers, copies, soldiers, bystanders) are only `info` to the tool; I ran them by name, so they print as plain
FAILs here and the tables mark them `extra`. Only the lead (the victim, or the saluter) counts for the mark.

**`hold`** (wins only) is my own number, not Tool 1's: how long, counted back from the clip's end, the upper body stays within 6
degrees of its final pose.

**Watched in game: not yet.** Nothing here was watched in the game (the owner had Studio open; no Studio, screen or MCP use).
Every mark is therefore provisional, from what the code, the data and Tool 1 say.

### The bar and the marks

Part 1 counted RoleMuerto (the bar) at 7 moving cameras, 0 locked, 12 effect events, 13 hands on targets, with a reference file;
RoleAce (the weak one) at 2, 6, 3, 2, none. The same count, as yes/no measures, for a scene:

1. a reference file with eight or more beats;
2. five or more moving or following cameras;
3. at most one locked camera;
4. ten or more effect events;
5. five or more hand placements (arms on targets) in the clips.

Wins add a sixth, an ending pose held 1.5 s or more (the plan's rule for them). How each count was made is in section 5.
**Mark rule:** `good` = 4 or more measures, a reference file and a lead clip that passes Tool 1; `re-act` = 2 to 3 measures, or
more but no reference or a failing lead clip; `rebuild` = 0 to 1 measures (a lead clip that passes Tool 1 lifts a `rebuild` to
`re-act`). Where the source itself fixes the camera (sans, Walrider, Blackwall) its 1 or 0 moving cameras are not held against it.
Emotes and movement are not scored like this: the plan says do not redo them, so they stay `good` and only a failing Tool 1
report **and** a wrong look in the game moves one (a failing clip is marked `re-act` provisionally, to be confirmed by the watch).

## 1. Stage 2: deaths

### 1.0 What a death is now

What happened to the plan's list (from `git log`):

- **The 14 custom deaths of `deaths.py`** (really 11 custom deaths and the three collapses). `4cec988c` (2026-11-11) removed five:
  `deathFall` (A long fall), `deathDrown` (Drowned on dry land), `deathChandelier`, `deathPages` (A thousand paper cuts),
  `deathBurn` (Burned from within). `6af353b6` (2026-11-11) retired the other six (`deathHeart`, `deathFrost`, `deathLightning`,
  `deathChip`, `deathClock`, `deathDark`) and remade each as a scene death. `deaths.py` now holds only the three collapses and
  `diveCrash` (the rift dive's crash, not a death at the table).
- **The eight re-enactments of `deaths_scenes.py`**: the file was deleted in `915e90eb` (2026-11-08, "scene deaths rebuilt 1 for 1").
  They are Luau modules in `src/client/Presentation/SceneDeaths/` with their actor clips in `art/scripts/scene_actors.py` (plus the
  ninth, Dead by selection, and the six remade ones).
- **The five styles of `fallen.py`**: deleted in `4cec988c` (the owner, 2026-11-10: "remove death styles completely").
  `Presentation/Fallen.luau` is now only `bodyOf`. `src/shared/Cinema/DeathCuts.luau` is `return {}`, the `CustomDeaths` effect
  table is empty, and `art/scripts/review_deaths.py` has nothing to render (`deathcuts.CUTS = {}`).

How a death plays today (`Presenters/Death.luau`, `Anim/ActingController.luau`):

- A **plain cause** (Heart attack, Disease, Accident): the book opens, then the table cutscene shows the victim playing
  `collapseHeart`, `collapseDisease` or `collapseAccident`, two living players reacting, and the body from above (1.2, 1.3).
- A **custom death** (15 shop causes, every one a scene death): the book opens, then everyone watches that scene's full cutscene on
  a far-off set, then the body where it lies from above under the cause card. The body itself plays `collapseHeart` for every one of
  them (`Causes.CLIP`), so that clip is also what the lying body shows after all 15 scenes.

The plan's Stage 2 order still holds for what is left: 1 the collapses, 2 the table cutscene, 3 and 4 the scene deaths, 5 the
styles (gone), 6 the effects. Item 3 ("the 14 custom deaths, worst first by the report") and item 5 no longer have anything to act
on; item 4 ("one for one with the source") covers the nine sourced scene deaths, and the six remade ones have no source at all.

### 1.1 Stage 2 ranked, worst first

The plan orders Stage 2 by how often a player sees the thing, so the collapses and the table cutscene come first; inside the
collapses and the scene deaths the order is by Tool 1 and the measures of section 1.4.

| Rank | Item | Kind | Mark | Why (one line) |
|---|---|---|---|---|
| 1 | collapseDisease | plain cause | re-act | FAIL Tool 1 (anticipation: 1 of 8 big moves is drawn back first); no reference file; the richest clip (333 keys) but none of it from film |
| 2 | collapseAccident | plain cause | re-act | PASS Tool 1; no reference file, no hand placed on anything, the fastest fall (floor at 0.7 s of 2.3) |
| 3 | collapseHeart | plain cause | re-act | PASS Tool 1; no reference file; the clip the body plays after all 15 scene deaths, so the most seen |
| 4 | the death at the table | cutscene | re-act | one fixed set of cuts for every cause; both witness cuts are 0.55 s (the plan asks 1.5 s); no cause-specific camera |
| 5 | reactCoverMouth | table reaction | re-act | FAIL Tool 1 (torso 3%: only the limbs act); the other four reactions pass |
| 6 | dark, clock | scene death | rebuild | 0 and 1 of 5 measures, no reference, both leads fail Tool 1 |
| 7 | sans, patriot, god, chip | scene death | re-act | 2 of 5 each (chip's lead passes Tool 1; sans and patriot fail; god has no actor clip) |
| 8 | lightning, heart, selection, requiem, sam | scene death | re-act | 3 of 5 each; lightning, heart and selection fail Tool 1, requiem and sam pass |
| 9 | blackwall, frost, ironMan | scene death | re-act | 4 of 5 each, but all three leads fail Tool 1 (frost also has no reference) |
| 10 | walrider | scene death | good | 4 of 5 with a reference; the star has no clip (first-person arms attached by code) |

### 1.2 The three cause collapses (and the dive crash)

| Clip | Built | Length s | Hits floor / lies still s | Reference | Keys | Hand placements | Effect beats (DeathVfx) | Tool 1 | Watched in game | Mark |
|---|---|---|---|---|---|---|---|---|---|---|
| collapseDisease | `art/scripts/deaths.py:143` | 3.4 | 2.887 / 3.4 | none | 333 | 9 | 7 | FAIL: anticipation | not yet | re-act |
| collapseAccident | `art/scripts/deaths.py:191` | 2.3 | 0.7 / 2.3 | none | 205 | 0 | 5 | PASS | not yet | re-act |
| collapseHeart | `art/scripts/deaths.py:105` | 2.7 | 1.647 / 2.7 | none | 227 | 13 | 6 | PASS | not yet | re-act |

- **Effects**: `Presentation/DeathVfx.luau` `BEATS.collapse*` (6, 7 and 5 beats), the shards and chalk outline at the hit
  (`DeathFx.burst`, `DeathFx.chalk`), timing in the generated `src/shared/Anim/DeathTiming.luau`.
- **No reference file.** `art/refs/deaths/` holds the nine scene notes only; the plan asks for film reference for each cause.
- **Seen on the sheet** (`deaths_collapses_front.png`, `deaths_collapses_side.png`, section 4): the three start differently inside half
  a second (a hand clawing in at the chest; a cough with a forearm to the mouth; the arms and a foot flung up), as the plan asks. The
  heart attack lies still for 1.05 s, the accident for 1.6 s, the disease for 0.5 s (hit 2.887 of 3.4). Nothing about the acting itself
  was judged from a sheet.
- `diveCrash` (1.9 s, `deaths.py`, played by `DiveController`): not a death at the table, listed so nobody counts it twice. Not part of stage 2.

T1 numbers (the columns are Tool 1's traits):

| Clip | Verdict | frozen s | dead s (joint) | glides s | slow snaps | anticip. | mirrored arms %, of held s | torso | metronome | same timing | overlap |
|---|---|---|---|---|---|---|---|---|---|---|---|
| collapseDisease | FAIL: anticipation | 0.0 | 0.7 lShoulder | 0.0 | 2/8 | 1/8 | 0% of 0.6 | 29% | 0 | 4/11 | 10/11 |
| collapseAccident | PASS | 0.2 | 1.1 rShoulder | 0.0 | 0/7 | 2/7 | 100% of 1.0 | 21% | 0 | 0/0 | 1/1 |
| collapseHeart | PASS | 0.6 | 0.9 root | 0.0 | 2/8 | 2/8 | 0% of 0.6 | 25% | 0 | 2/5 | 4/4 |

Disease: the four coughs and the sit-down leave only 1 of 8 big moves drawn back first, and 2 of 8 snaps take over 0.35 s with no hold.

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

- The cut lands on the death's first frame (`cue.at` after the book), as the plan asks. The camera moves towards where the body will lie,
  from `bodyAt(mark, clip, timing.still)`, but with one wide/close/over set for all three causes.
- **Shots under 1.5 s**: both witness cuts (0.55 s each). Both witnesses play a reaction clip picked from `Activities.REACTIONS` (five
  clips, a hash of the cue id and the player's id), so two witnesses can match when few players are alive.

The five reaction clips (also used by arrests and verdicts, `ActingController.reactAround`, 3.6 s window):

| Clip | Length s | Keys | Tool 1 | Watched | Mark | Why |
|---|---|---|---|---|---|---|
| reactCoverMouth | 1.8 | 45 | FAIL: torso | not yet | re-act | the torso barely turns (3% of motion): only the limbs act |
| reactHandsHead | 2 | 72 | PASS | not yet | good | a plain one-shot; Tool 1 passes it |
| reactLookAway | 1.8 | 38 | PASS | not yet | good | a plain one-shot; Tool 1 passes it |
| reactGasp | 1.6 | 38 | PASS | not yet | good | a plain one-shot; Tool 1 passes it |
| reactStartle | 1.2 | 59 | PASS | not yet | good | a plain one-shot; Tool 1 passes it |

Sheet: `deaths_table_reactions.png`. Mark for the table cutscene itself: **re-act** (the cuts, not the story).

### 1.4 The 15 scene deaths, ranked worst first

All are in `src/client/Presentation/SceneDeaths/<Module>.luau`, run by `init.luau`, and are the shop's custom deaths (`Cosmetics.luau`
kind `reason`). Cameras are `moving / following / locked` and effects `screen + VFX`, as section 5 says. `Hands` is the hand placements
in all the scene's actor clips; `Bar` is the five measures; `Tool 1 (lead)` is the lead clip's verdict.

| # | Scene | Len s | Reference beats (kind) | Cams moving / following / locked | Effects screen + VFX | Hands | Bar | Tool 1 (lead) | Watched | Mark | Why |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | dark | 11 | 0 (none) | 1 / 0 / 5 | 4 + 1 | 0 | 0/5 | FAIL: symmetry | not yet | rebuild | 0 of 5 and the lead fails Tool 1 (symmetry): no reference, 1 of 6 cameras moves, 5 effects, no hand placed; keep the idea (yanked into the black, the body gone) |
| 2 | clock | 11 | 0 (none) | 2 / 2 / 1 | 3 + 3 | 3 | 1/5 | FAIL: frozen, anticipation | not yet | rebuild | 1 of 5 and the lead fails Tool 1 (frozen 3.8 s, anticipation): no reference, torso 7% of motion, 6 effects, the walk in ticks has no escalating action |
| 3 | sans | 30 | 10 (watched video) | 0 / 0 / 1 | 3 + 0 | 0 | 2/5 | FAIL: anticipation, symmetry | not yet | re-act | lead fails Tool 1 (anticipation 0 of 5, arms mirrored 93% of 27 s asleep); 2 of 5, but 1 locked camera and 3 effects are the source's own (one fixed battle screen), keep the camera |
| 4 | patriot | 25 | 7 (watched video) | 4 / 1 / 1 | 1 + 3 | 4 | 2/5 | FAIL: dead | not yet | re-act | 2 of 5 and the lead fails Tool 1 (dead: the saluter's left arm never moves in 25 s); 4 effect events in 25 s, reference 7 beats |
| 5 | god | 17 | 5 (owner's spec only, no clip) | 3 / 0 / 1 | 4 + 8 | 0 | 2/5 | no star clip | not yet | re-act | 2 of 5: reference is the owner's spec only (5 rows), no acted body (the star is the serpent, code-driven), 4 cameras; no clip for Tool 1 |
| 6 | chip | 11 | 0 (none) | 5 / 0 / 1 | 5 + 3 | 4 | 2/5 | PASS | not yet | re-act | 2 of 5, the lead PASSES Tool 1: no reference, 8 effects, 4 hand placements; the flourish and the bite are worth keeping |
| 7 | lightning | 10 | 0 (none) | 5 / 0 / 1 | 5 + 11 | 2 | 3/5 | FAIL: same, symmetry | not yet | re-act | 3 of 5 and the lead fails Tool 1 (symmetry; the same timing on 13 of 18 moves: the shake is a metronome); no reference, 2 hand placements |
| 8 | heart | 12 | 0 (none) | 6 / 0 / 1 | 5 + 4 | 13 | 3/5 | FAIL: anticipation | not yet | re-act | 3 of 5 and the lead fails Tool 1 (anticipation 1 of 10); no reference file; cameras, effects and hands (13) are near the bar |
| 9 | selection | 14 | 7 (owner's chart) | 6 / 0 / 1 | 6 + 3 | 7 | 3/5 | FAIL: symmetry | not yet | re-act | 3 of 5 and the lead fails Tool 1 (arms mirrored 57% of 10.9 s); reference 7 beats, 9 effects, both just under the bar |
| 10 | requiem | 16.5 | 10 (watched video) | 4 / 1 / 4 | 6 + 11 | 0 | 3/5 | PASS | not yet | re-act | 3 of 5, the lead PASSES Tool 1; 4 of 9 cameras locked, no hand placed; the extras are thin (the killer 34 keys over 16.5 s and fails: dead 11.7 s) |
| 11 | sam | 14 | 16 (watched video) | 4 / 0 / 5 | 4 + 9 | 24 | 3/5 | PASS | not yet | re-act | 3 of 5, the lead PASSES Tool 1; 5 of 9 cameras locked; the acting is the richest (hands 24, 16 reference rows) |
| 12 | blackwall | 23.3 | 10 (watched video) | 1 / 0 / 0 | 5 + 14 | 19 | 4/5 | FAIL: dead, anticipation, symmetry | not yet | re-act | 4 of 5 but the lead fails Tool 1 (dead 14.8 s, anticipation 2 of 16, arms mirrored 98% of 20 s); a first-person ride like the source, keep the camera |
| 13 | frost | 12 | 0 (none) | 6 / 0 / 0 | 4 + 6 | 10 | 4/5 | FAIL: frozen | not yet | re-act | 4 of 5 but no reference file, and the lead fails Tool 1 (frozen 3.4 s, the story's rigid freeze) |
| 14 | ironMan | 18 | 9 (owner's spec and the film's beats, no frame sheet) | 2 / 5 / 2 | 4 + 11 | 7 | 4/5 | FAIL: glides | not yet | re-act | 4 of 5 but the lead fails Tool 1 (glides 3.5 s); reference is the spec and the film's beats, so a frame sheet is still worth watching |
| 15 | walrider | 21.5 | 12 (watched video) | 1 / 0 / 0 | 7 + 7 | 10 | 4/5 | no star clip | not yet | good | 4 of 5; the star's arms are attached to the view by code (no star clip, so nothing for Tool 1); its extras fail only because they sit or stand still by story; a first-person ride like the source |

Ranking inside a mark is by the bar, then by how many traits the lead fails. For the nine sourced scenes the owner's rule applies (plan Stage 2
item 4): put the source's frame sheet beside ours, beat by beat, list every difference in pose, timing, framing and effect, fix the differences,
invent nothing. The six remade ones (heart, frost, lightning, chip, clock, dark) have no source and no reference file: under the plan's loop
they need step 3 (a reference of eight beats or more, in `art/refs/deaths/`) before any acting.

### 1.5 Where each scene death is built

| Scene | Shop name | Cosmetic id | Module | Blender set (`art/scripts/maps/venues/scenes/`) | Reference | Actor clips (`art/scripts/scene_actors.py`) |
|---|---|---|---|---|---|---|
| dark | Taken by the Dark | `reason_dark` | `SceneDeaths/Dark.luau` (204 lines) | remade.py | none | sceneDarkVictim |
| clock | Their Time Ran Out | `reason_clock` | `SceneDeaths/Clock.luau` (235 lines) | remade.py | none | sceneClockVictim |
| sans | heh, didja really think- | `reason_sans` | `SceneDeaths/Sans.luau` (365 lines) | none (void or sky only, built in Luau) | `art/refs/deaths/sans.md` | sceneSansVictim |
| patriot | A true patriot | `reason_patriot` | `SceneDeaths/Patriot.luau` (271 lines) | patriot.py | `art/refs/deaths/patriot.md` | scenePatriotSaluter |
| god | A GOD.. IS NOT... AFRAID OF... | `reason_god` | `SceneDeaths/God.luau` (461 lines) | none (void or sky only, built in Luau) | `art/refs/deaths/god.md` | none |
| chip | Choked on a Potato Chip | `reason_chip` | `SceneDeaths/Chip.luau` (233 lines) | remade.py | none | sceneChipVictim |
| lightning | Struck by Lightning | `reason_lightning` | `SceneDeaths/Lightning.luau` (229 lines) | remade.py | none | sceneLightningVictim |
| heart | A Broken Heart | `reason_heart` | `SceneDeaths/Heart.luau` (282 lines) | remade.py | none | sceneHeartVictim |
| selection | Dead by selection | `reason_selection` | `SceneDeaths/Selection.luau` (495 lines) | selection.py (+ angel_statue.py) | `art/refs/deaths/selection.md` | sceneSelectionVictim |
| requiem | This is... requiem | `reason_requiem` | `SceneDeaths/Requiem.luau` (397 lines) | none (void or sky only, built in Luau) | `art/refs/deaths/requiem.md` | sceneRequiemCopy, sceneRequiemKiller, sceneRequiemVictim |
| sam | Let's dance! | `reason_sam` | `SceneDeaths/Sam.luau` (637 lines) | sam.py | `art/refs/deaths/sam.md` | sceneSamKiller, sceneSamVictim |
| blackwall | Blackwall gateway | `reason_blackwall` | `SceneDeaths/Blackwall.luau` (1096 lines) | blackwall.py | `art/refs/deaths/blackwall.md` | sceneBlackwallBystander, sceneBlackwallVictim |
| frost | Frozen Where They Stood | `reason_frost` | `SceneDeaths/Frost.luau` (226 lines) | remade.py | none | sceneFrostVictim |
| ironMan | and I.. am.. | `reason_ironman` | `SceneDeaths/IronMan.luau` (482 lines) | ironman.py | `art/refs/deaths/ironman.md` | sceneIronKiller, sceneIronSoldier, sceneIronVictim |
| walrider | Walrider | `reason_walrider` | `SceneDeaths/Walrider.luau` (682 lines) | walrider.py | `art/refs/deaths/walrider.md` | sceneWalriderSeated, sceneWalriderSoldier |

Shared pieces: `init.luau` (the context, 25.8 KB), `Sets.luau` (builds the cell's meshes), `Cast.luau` and `Costumes.luau` (extras in marketplace
costumes). The Scenes venue puts one set per cell 1000 studs apart (`plan.py`: patriot 0 through dark 11000); requiem, god and sans have no Blender
set. Skies come from `art/scripts/scene_skies.py`.

### 1.6 Every actor clip of the scene deaths

| Clip | Role | Built | Length s | Keys | Hand placements | Tool 1 | Watched |
|---|---|---|---|---|---|---|---|
| sceneBlackwallBystander | extra | `scene_actors.py:187` | 23.3 | 353 | 0 | FAIL: frozen, dead, overlap | not yet |
| sceneBlackwallVictim | lead | `scene_actors.py:132` | 23.3 | 609 | 19 | FAIL: dead, anticipation, symmetry | not yet |
| sceneChipVictim | lead | `scene_actors.py:752` | 11 | 431 | 4 | PASS | not yet |
| sceneClockVictim | lead | `scene_actors.py:807` | 11 | 217 | 3 | FAIL: frozen, anticipation | not yet |
| sceneDarkVictim | lead | `scene_actors.py:836` | 11 | 483 | 0 | FAIL: symmetry | not yet |
| sceneFrostVictim | lead | `scene_actors.py:680` | 12 | 442 | 10 | FAIL: frozen | not yet |
| sceneHeartVictim | lead | `scene_actors.py:636` | 12 | 299 | 13 | FAIL: anticipation | not yet |
| sceneIronKiller | extra | `scene_actors.py:511` | 18 | 252 | 0 | FAIL: symmetry | not yet |
| sceneIronSoldier | extra | `scene_actors.py:544` | 18 | 32 | 0 | PASS | not yet |
| sceneIronVictim | lead | `scene_actors.py:464` | 18 | 248 | 7 | FAIL: glides | not yet |
| sceneLightningVictim | lead | `scene_actors.py:716` | 10 | 508 | 2 | FAIL: same, symmetry | not yet |
| scenePatriotSaluter | lead | `scene_actors.py:562` | 25 | 109 | 4 | FAIL: dead | not yet |
| sceneRequiemCopy | extra | `scene_actors.py:108` | 16.5 | 73 | 0 | PASS | not yet |
| sceneRequiemKiller | extra | `scene_actors.py:116` | 16.5 | 34 | 0 | FAIL: dead | not yet |
| sceneRequiemVictim | lead | `scene_actors.py:85` | 16.5 | 218 | 0 | PASS | not yet |
| sceneSamKiller | extra | `scene_actors.py:275` | 14 | 525 | 11 | FAIL: same, anticipation | not yet |
| sceneSamVictim | lead | `scene_actors.py:223` | 14 | 544 | 13 | PASS | not yet |
| sceneSansVictim | lead | `scene_actors.py:424` | 30 | 315 | 0 | FAIL: anticipation, symmetry | not yet |
| sceneSelectionVictim | lead | `scene_actors.py:586` | 14 | 89 | 7 | FAIL: symmetry | not yet |
| sceneWalriderSeated | extra | `scene_actors.py:412` | 21.5 | 37 | 0 | FAIL: dead, symmetry | not yet |
| sceneWalriderSoldier1 | extra | `scene_actors.py` (a loop) | 21.5 | 80 | - | FAIL: dead | not yet |
| sceneWalriderSoldier2 | extra | `scene_actors.py` (a loop) | 21.5 | 93 | - | FAIL: dead | not yet |
| sceneWalriderSoldier3 | extra | `scene_actors.py` (a loop) | 21.5 | 202 | - | FAIL: dead | not yet |
| sceneWalriderSoldier4 | extra | `scene_actors.py` (a loop) | 21.5 | 105 | - | FAIL: dead | not yet |

Extras fail on purpose where the story keeps them still (Blackwall's bystander lies dead for 5 s, the Walrider's soldiers and old man sit or stand for the
whole 21.5 s, the Requiem killer stands tall and unhurried). The Tool 1 documentation says the same: an extra's faults are only noted. Even so the
clips with very few keys over their length are worth a look first: `sceneRequiemKiller` (34 keys, 16.5 s), `sceneWalriderSeated` (37 keys, 21.5 s),
`sceneIronSoldier` (32 keys, 18 s).

T1 numbers of the leads and extras:

| Clip | Verdict | frozen s | dead s (joint) | glides s | slow snaps | anticip. | mirrored arms %, of held s | torso | metronome | same timing | overlap |
|---|---|---|---|---|---|---|---|---|---|---|---|
| sceneBlackwallBystander | FAIL: frozen, dead, overlap | 5.0 | 14.9 rShoulder | 0.0 | 1/9 | 3/9 | 0% of 19.9 | 24% | 0 | 3/5 | 1/6 |
| sceneBlackwallVictim | FAIL: dead, anticipation, symmetry | 0.9 | 14.8 rShoulder | 0.0 | 0/16 | 2/16 | 98% of 20.0 | 20% | 0 | 4/13 | 7/10 |
| sceneChipVictim | PASS | 1.5 | 2.8 rShoulder | 0.8 | 0/10 | 2/10 | 12% of 3.6 | 21% | 0 | 3/9 | 7/9 |
| sceneClockVictim | FAIL: frozen, anticipation | 3.8 | 4.5 root | 0.0 | 1/12 | 1/12 | 8% of 6.3 | 7% | 0 | 4/6 | 0/0 |
| sceneDarkVictim | FAIL: symmetry | 0.3 | 4.4 root | 0.4 | 2/23 | 4/23 | 100% of 2.1 | 32% | 4 | 9/24 | 5/5 |
| sceneFrostVictim | FAIL: frozen | 3.4 | 3.9 root | 0.4 | 2/3 | 3/3 | 9% of 3.7 | 18% | 0 | 2/6 | 1/4 |
| sceneHeartVictim | FAIL: anticipation | 1.7 | 3.3 rShoulder | 0.0 | 1/10 | 1/10 | 49% of 6.8 | 24% | 0 | 3/4 | 4/5 |
| sceneIronKiller | FAIL: symmetry | 0.7 | 5.0 lShoulder | 0.0 | 1/2 | 1/2 | 60% of 9.5 | 26% | 0 | 2/5 | 5/5 |
| sceneIronSoldier | PASS | 2.1 | 3.5 rShoulder | 0.0 | 0/0 | 0/0 | 0% of 18.0 | 29% | 0 | 0/0 | 0/0 |
| sceneIronVictim | FAIL: glides | 0.2 | 4.3 rShoulder | 3.5 | 0/4 | 2/4 | 0% of 3.0 | 26% | 0 | 2/6 | 3/3 |
| sceneLightningVictim | FAIL: same, symmetry | 2.1 | 3.4 root | 0.4 | 0/9 | 3/9 | 100% of 4.3 | 17% | 0 | 13/18 | 3/4 |
| scenePatriotSaluter | FAIL: dead | 1.1 | 25.0 lShoulder | 0.4 | 0/1 | 0/1 | 34% of 24.2 | 12% | 0 | 0/0 | 0/0 |
| sceneRequiemCopy | PASS | 1.1 | 3.7 root | 0.0 | 0/2 | 0/2 | 0% of 16.0 | 25% | 0 | 0/0 | 1/1 |
| sceneRequiemKiller | FAIL: dead | 1.1 | 11.7 lShoulder | 0.0 | 0/1 | 0/1 | 7% of 15.6 | 8% | 0 | 0/0 | 0/0 |
| sceneRequiemVictim | PASS | 0.6 | 2.1 root | 0.0 | 0/6 | 2/6 | 0% of 13.2 | 26% | 0 | 1/4 | 4/4 |
| sceneSamKiller | FAIL: same, anticipation | 1.5 | 6.0 lShoulder | 1.1 | 0/17 | 2/17 | 0% of 7.0 | 22% | 0 | 9/15 | 13/16 |
| sceneSamVictim | PASS | 1.8 | 3.3 rShoulder | 0.0 | 1/13 | 4/13 | 35% of 6.4 | 28% | 0 | 5/12 | 13/13 |
| sceneSansVictim | FAIL: anticipation, symmetry | 1.8 | 6.1 rShoulder | 0.0 | 0/5 | 0/5 | 93% of 27.1 | 23% | 0 | 4/7 | 2/2 |
| sceneSelectionVictim | FAIL: symmetry | 1.0 | 6.9 lShoulder | 1.5 | 0/2 | 0/2 | 57% of 10.9 | 14% | 0 | 0/0 | 0/1 |
| sceneWalriderSeated | FAIL: dead, symmetry | 1.5 | 21.5 root | 0.0 | 0/0 | 0/0 | 100% of 21.5 | 15% | 0 | 0/0 | 0/0 |
| sceneWalriderSoldier1 | FAIL: dead | 1.1 | 21.5 rShoulder | 0.0 | 0/0 | 0/0 | 0% of 21.5 | 21% | 0 | 2/6 | 0/0 |
| sceneWalriderSoldier2 | FAIL: dead | 1.2 | 21.5 rShoulder | 2.0 | 0/1 | 0/1 | 0% of 17.2 | 9% | 0 | 0/0 | 0/0 |
| sceneWalriderSoldier3 | FAIL: dead | 0.9 | 14.7 lShoulder | 0.0 | 0/2 | 0/2 | 0% of 21.0 | 46% | 0 | 3/4 | 3/10 |
| sceneWalriderSoldier4 | FAIL: dead | 1.3 | 8.9 rShoulder | 0.5 | 0/0 | 0/0 | 0% of 20.4 | 15% | 0 | 1/5 | 0/0 |

### 1.7 Effects (plan Stage 2 step 6)

- The table cutscene's effects are in 1.3; the per-cause beats are `DeathVfx` (6, 7, 5 beats), each built from `glow`, `pulse`, `dust`, `puff`, a light
  flash and a short shake. The plan's test (a beat on the clip's `fx` moment, a beginning, peak and decay, light on the body and floor, something
  left behind) is partly there: the chalk outline and shards at the hit are the thing left behind.
- The scene deaths carry their own effects (counts in 1.4); `CustomDeaths.luau` and the old per-death effect table are empty. `docs/vfx.md` is the house style.
- The scenes with the fewest VFX events are sans (0 VFX, 3 screen, the source's own), dark (1), patriot (3), chip (3), selection (3) and clock (3).
  Whether a given effect is "one emitter and a flash" needs the in-game watch.

### 1.8 Sheets for the worst few (section 4 has the paths)

`deaths_collapses_front.png` and `_side.png` (all three collapses, 12 frames each), `deaths_scene_remade_victims.png` (the six remade victims),
`deaths_scene_referenced_victims.png` (the sourced ones), `deaths_table_reactions.png`. Seen on the remade sheet: frost's victim stands rigid for the
last five of twelve frames (Tool 1: frozen 3.4 s); clock's ends leaning on its feet, not falling (frozen 3.8 s); dark's body is carried out of frame;
lightning's and heart's victims fall flat and lie still for the rest.

## 2. Stage 3: the eight winning cutscenes

Cut data: `src/shared/Cinema/WinCuts.luau` (one entry each, 8.0 s, played by `Presentation/WinCinema`); star clips: `art/scripts/emotes/wins.py`.
**No win cutscene has a reference file** (`art/refs/` has no wins; the emote notes `newWorld.toml` and the like are for the emotes of those names).
Counted as in Part 1: cameras `moving / locked` (a shot with a `to` drift or a `glide` is moving), `Events` the `events` list, `Beats` the screen
beats (flash, still, shake), `Hands` the placements in the clip; `Bar` is the five measures of section 0 plus the 1.5 s ending hold.

| # | Cut | Clip | Built | Len s | Room | Cams moving / locked | Events + beats | Sounds | Hands | Keys | End hold s | Bar | Tool 1 | Watched | Mark | Why |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | checkmateCoven | `winCheckmateCoven` | `wins.py:387` | 8 | roofrain | 4 / 3 | 3 + 4 | 4 | 3 | 135 | 1.65 | 1/6 | FAIL: anticipation, symmetry | not yet | rebuild | 1 of 6 and FAIL Tool 1 (anticipation 0 of 5, arms mirrored 100% of 5.2 s): 3 of 7 cameras locked, 3 events, 3 hand placements; the action is a finger flick, a small gesture |
| 2 | checkmate | `winCheckmate` | `wins.py:200` | 8 | hall | 4 / 1 | 4 + 3 | 4 | 3 | 90 | 0.8 | 1/6 | FAIL: symmetry | not yet | rebuild | 1 of 6 and FAIL Tool 1 (arms mirrored 100% of 6.7 s): 4 events, 3 hand placements, ends moving (hold 0.8 s); one finger tips the king |
| 3 | newWorld | `winNewWorld` | `wins.py:125` | 8 | rooftop | 4 / 0 | 2 + 3 | 4 | 2 | 165 | 0.8 | 1/6 | PASS | not yet | re-act | 1 of 6 but PASS Tool 1, which lifts it from rebuild: only 2 events and 2 hand placements for the Godhood prize, the arms still move at the end (hold 0.8 s) |
| 4 | finalPageBureau | `winFinalPageBureau` | `wins.py:244` | 8 | archive | 5 / 0 | 12 + 3 | 6 | 27 | 162 | 0.93 | 4/6 | FAIL: anticipation | not yet | re-act | 4 of 6 and no reference; FAIL Tool 1 (anticipation 1 of 8); ends straightening into the light (hold 0.9 s) |
| 5 | caseClosedCoven | `winCaseClosedCoven` | `wins.py:350` | 8 | den | 5 / 1 | 17 + 3 | 4 | 20 | 107 | 1.47 | 4/6 | FAIL: symmetry | not yet | re-act | 4 of 6 and no reference; FAIL Tool 1 (arms mirrored 89% of 5.4 s); hold 1.5 s is on the line; 17 events |
| 6 | finalPage | `winFinalPage` | `wins.py:74` | 8 | writer | 4 / 0 | 9 + 4 | 6 | 19 | 94 | 2.03 | 4/6 | FAIL: symmetry | not yet | re-act | 4 of 6 and no reference; FAIL Tool 1 (arms mirrored 100% of 3.5 s); the smallest clip (275 degrees in 8 s: write, shut, lean back) |
| 7 | newWorldBureau | `winNewWorldBureau` | `wins.py:303` | 8 | steps | 6 / 0 | 18 + 3 | 4 | 6 | 134 | 1.38 | 4/6 | PASS | not yet | re-act | 4 of 6 and no reference, PASS Tool 1; hold 1.4 s, just under 1.5; 18 events |
| 8 | caseClosed | `winCaseClosed` | `wins.py:162` | 8 | office | 4 / 0 | 10 + 2 | 6 | 5 | 78 | 1.53 | 4/6 | PASS | not yet | re-act | 4 of 6 and no reference, PASS Tool 1; the clip is small (382 degrees of motion in 8 s) |

What each cut is (one line):

- `checkmateCoven`: Diavolo on a roof in the rain, the white king flicked over the parapet.
- `checkmate`: Bureau, Godhood: up to a giant black king, tips it with one finger.
- `newWorld`: Coven, Godhood: walks to a roof's edge, the Manual opened, arms spread over the dying city.
- `finalPageBureau`: Ace at the archive: last page burned on a match, the book sealed in an evidence bag.
- `caseClosedCoven`: Diavolo in the armchair, the case file thrown on the fire, laughing.
- `finalPage`: Coven, Sealed: the last name written, the Manual shut, leaning back as the candles die.
- `newWorldBureau`: Ace on the courthouse step, the Manual raised high over the press.
- `caseClosed`: Bureau, Sealed: crouched on a chair, strings snap, the stamp slammed.

T1 numbers:

| Clip | Verdict | frozen s | dead s (joint) | glides s | slow snaps | anticip. | mirrored arms %, of held s | torso | metronome | same timing | overlap |
|---|---|---|---|---|---|---|---|---|---|---|---|
| winCheckmateCoven | FAIL: anticipation, symmetry | 0.5 | 4.8 lShoulder | 1.3 | 1/5 | 0/5 | 100% of 5.2 | 42% | 0 | 3/4 | 3/3 |
| winCheckmate | FAIL: symmetry | 0.4 | 8.0 lShoulder | 0.8 | 0/3 | 0/3 | 100% of 6.7 | 33% | 0 | 0/0 | 0/0 |
| winNewWorld | PASS | 0.3 | 2.7 lShoulder | 1.7 | 0/6 | 1/6 | 0% of 2.0 | 19% | 0 | 3/9 | 1/1 |
| winFinalPageBureau | FAIL: anticipation | 0.3 | 2.5 lShoulder | 0.4 | 0/8 | 1/8 | 28% of 3.1 | 10% | 0 | 2/4 | 2/3 |
| winCaseClosedCoven | FAIL: symmetry | 0.6 | 4.0 lShoulder | 0.0 | 0/4 | 0/4 | 89% of 5.4 | 21% | 0 | 2/4 | 2/4 |
| winFinalPage | FAIL: symmetry | 0.2 | 3.0 lShoulder | 0.0 | 0/0 | 0/0 | 100% of 3.5 | 18% | 0 | 1/4 | 1/2 |
| winNewWorldBureau | PASS | 0.3 | 1.9 lShoulder | 0.4 | 0/4 | 1/4 | 0% of 3.0 | 16% | 0 | 3/5 | 4/4 |
| winCaseClosed | PASS | 0.4 | 8.0 lShoulder | 0.4 | 0/2 | 1/2 | 0% of 5.6 | 20% | 0 | 2/6 | 4/5 |

Five of the eight fail: four on **mirrored arms** (finalPage, checkmate, checkmateCoven, caseClosedCoven: a held two-handed pose, both hands flat on a table or
behind the back; the plan says never both arms doing the same thing) and two on **anticipation** (finalPageBureau, checkmateCoven). All eight pass frozen,
dead, glides and torso share.

- **The ending pose.** The plan wants it held 1.5 s or more while the winning side's name is written in. The `End hold` column (within 6 degrees of
  the final pose) is below 1.5 s for five of the eight (newWorld 0.8, checkmate 0.8, finalPageBureau 0.9, newWorldBureau 1.4, caseClosedCoven 1.5
  borderline); finalPage (2.0), checkmateCoven (1.7) and caseClosed (1.5) pass. `WinCinema` keeps the last frame only `TAIL` = 0.35 s after the cut.
- **The name card is not timed to the ending.** In a match `Presenters/Outro.luau` plays the cut from the cue's start with the typewriter
  `"<side> wins"` card (`Cinema.card`, y 0.74) on screen from the first second until the cut is stopped (`firstShot` seconds in), then goes on to the
  written names. If the owner wants the name written in on the ending pose, that is a change in `Outro.luau`, not in the cuts.
- **Pairs that share a base** (Bureau and Coven): each of the eight already has its own clip, its own room (writer, rooftop, office, hall, archive,
  steps, den, roof in the rain), its own props and its own grade, so the plan's "own ending pose, grade and effect" is met in the data; whether each
  ending reads as a still picture is a watch item.
- Sheets: `wins/newWorld/sheet.png`, `wins/checkmate/sheet.png`, `wins/finalPageBureau/sheet.png`, `wins/checkmateCoven/sheet.png` (the star in the set
  through each shot's start, middle and end; `review_win.py` does not draw the events).

## 3. Stage 4: emotes, then base movement

### 3.1 The first five and the frozen lengths

All five of Wave, Point, Cheer, Laugh and Dance are length-frozen: they copy Roblox's classic `/e` recordings (`art/refs/classic/*.json`, built by
`art/scripts/emotes/free.py` through `classic.py`), and cutscenes, tableaux and the note hand-off play them at fixed times. `art/scripts/check_refs.py`
(`FROZEN`) freezes **nine** lengths, the five and four more:

| Clip | Frozen length s | Plays as | Source | Tool 1 |
|---|---|---|---|---|
| wave | 2.4 | one-shot | Roblox classic | FAIL: torso |
| point | 1.6 | one-shot | Roblox classic | PASS |
| cheer | 2.2 | one-shot | Roblox classic | PASS |
| laugh | 1.2 | loop | Roblox classic | PASS |
| dance | 1.6 | loop | Roblox classic | PASS |
| salute | 2 | one-shot | footage (mocap) | PASS |
| bow | 2.6 | one-shot | footage (mocap) | PASS |
| shrug | 2 | one-shot | footage (mocap) | PASS |
| facepalm | 2.4 | one-shot | footage (mocap) | PASS |

Of the nine only `wave` fails Tool 1 (torso 2% of the motion: only the arm acts). It is Roblox's own recording kept on the owner's call (the free emotes
copy the classics), so a re-act is the owner's decision, and it must keep its 2.4 s. Whatever Stage 4 does to any of the nine changes the poses, not the clock.

### 3.2 The 70 emotes, ranked worst first

All 70 have a reference file (`art/refs/emotes/<clip>.toml`, a source and a date watched); 52 have written beats, 13 name a mocap take, 7 are Roblox
classic recordings (wave, point, cheer, laugh, dance, dance2, dance3), 64 are status `checked` and 6 `authored` (chipAndPen, griddy, justAsPlanned,
matchPointServe, puppetPop, smilingLord: built but not put through `check_refs.py`'s checked state). `check_anims.py` reports 0 failed clips.

**Tool 1 over all 70 (`--emotes`): 63 pass, 7 fail** (diceTower, finalBreakdown, justAsPlanned, preDawnBonk, theLongClimb, twoWeeksNotice, wave). The
order below is: the failing clips first (more failing traits first, then the nearer to a limit), then the passing clips by how close their nearest
limit is (`margin`: the number divided by its limit, 1.0 = at the limit; computed with Tool 1's own limits and judging rules). Per the plan every emote
stays `good` until a failing report **and** a wrong look in the game say otherwise (the owner rated the emotes far above the cutscene acting on
2026-10-27), so the seven failing ones are marked `re-act` only provisionally, for the watch to confirm, except `wave` (kept as Roblox's own).

| # | Clip | Family | Built | Len s | Plays as | Keys | Ref beats | Source | Ref status | Margin | Tool 1 | Watched | Mark | Why |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `diceTower` | prop | `emotes/props.py:215` | 6 | one-shot | 138 | 0 | video reference | checked | 1.80 | FAIL: metronome, anticipation | not yet | re-act | FAIL anticipation and metronome: the stacking beats repeat at one size and interval (5 in a row) |
| 2 | `preDawnBonk` | prop | `emotes/props.py:448` | 3.6 | one-shot | 226 | 0 | video reference | checked | 1.35 | FAIL: same, anticipation | not yet | re-act | FAIL anticipation and same timing (6 of 9) |
| 3 | `finalBreakdown` | pose | `emotes/poses.py:349` | 5.4 | one-shot | 376 | 2 | video reference | checked | 1.28 | FAIL: same, metronome | not yet | re-act | FAIL metronome and same timing (10 of 13 moves take one timing) |
| 4 | `justAsPlanned` | pose | `emotes/poses.py:25` | 9.2 | one-shot | 332 | 3 | video reference | authored | 15.00 | FAIL: anticipation | not yet | re-act | FAIL anticipation (0 of 10 big moves wound up); status authored, a 9.2 s Godhood cutscene emote |
| 5 | `wave` | free | `anims.py:222` | 2.4 | one-shot | 134 | 2 | Roblox classic | checked | 1.76 | FAIL: torso | not yet | good | FAIL torso (2%): Roblox's own recording, length frozen; kept on the owner's call; length frozen |
| 6 | `theLongClimb` | stroll | `anims_emotes.py:728` | 1.84 | loop | 91 | 0 | video reference | checked | 1.17 | FAIL: torso | not yet | re-act | FAIL torso (3%): a stroll's standing loop where only the limbs act; the walk cycle is a separate clip |
| 7 | `twoWeeksNotice` | dance | `emotes/dances.py:392` | 3.2 | one-shot | 418 | 2 | video reference | checked | 1.17 | FAIL: same | not yet | re-act | FAIL same timing (7 of 10 moves take one timing) |
| 8 | `paradeMarch` | stroll | `anims_emotes.py:742` | 3.2 | loop | 232 | 0 | video reference | checked | 0.91 | PASS | not yet | good | stroll, video reference; reference has no written beats |
| 9 | `impossibleLean` | pose | `emotes/poses.py:102` | 4.2 | one-shot | 75 | 1 | video reference | checked | 0.90 | PASS | not yet | good | pose, video reference |
| 10 | `jawlineCheck` | pose | `emotes/poses.py:150` | 3.2 | one-shot | 83 | 1 | video reference | checked | 0.76 | PASS | not yet | good | pose, video reference |
| 11 | `sugarTower` | prop | `emotes/props.py:159` | 6 | one-shot | 111 | 0 | video reference | checked | 0.75 | PASS | not yet | good | prop, video reference; reference has no written beats |
| 12 | `newWorld` | pose | `emotes/poses.py:382` | 6.5 | one-shot | 94 | 1 | video reference | checked | 0.72 | PASS | not yet | good | pose, video reference |
| 13 | `boatAura` | dance | `emotes/dances.py:178` | 6.4 | loop | 272 | 3 | video reference | checked | 0.70 | PASS | not yet | good | dance, video reference |
| 14 | `chipAndPen` | prop | `emotes/props.py:42` | 10.4 | one-shot | 315 | 5 | video reference | authored | 0.68 | PASS | not yet | good | prop, video reference; status authored (not yet checked) |
| 15 | `reapersEyes` | pose | `emotes/poses.py:410` | 3.2 | one-shot | 68 | 1 | video reference | checked | 0.66 | PASS | not yet | good | pose, video reference |
| 16 | `goalCelebration` | dance | `emotes/dances.py:134` | 3 | one-shot | 271 | 2 | video reference | checked | 0.61 | PASS | not yet | good | dance, video reference |
| 17 | `facepalm` | free | `emotes/free.py:141` | 2.4 | one-shot | 78 | 2 | mocap | checked | 0.61 | PASS | not yet | good | free, mocap; length frozen |
| 18 | `writeAir` | older | `emotes/older.py:288` | 3 | one-shot | 125 | 1 | video reference | checked | 0.57 | PASS | not yet | good | older, video reference |
| 19 | `notMyProblem` | stroll | `anims_emotes.py:773` | 3 | loop | 61 | 0 | video reference | checked | 0.55 | PASS | not yet | good | stroll, video reference; reference has no written beats |
| 20 | `fortySeconds` | prop | `emotes/props.py:307` | 4.6 | one-shot | 90 | 0 | video reference | checked | 0.55 | PASS | not yet | good | prop, video reference; reference has no written beats |
| 21 | `animatronicWelcome` | dance | `emotes/dances.py:246` | 9.6 | loop | 386 | 3 | video reference | checked | 0.52 | PASS | not yet | good | dance, video reference |
| 22 | `blindfoldLift` | prop | `emotes/props.py:331` | 4 | loop | 41 | 0 | video reference | checked | 0.50 | PASS | not yet | good | prop, video reference; reference has no written beats |
| 23 | `chairPerch` | prop | `emotes/props.py:134` | 4 | loop | 21 | 0 | video reference | checked | 0.50 | PASS | not yet | good | prop, video reference; reference has no written beats |
| 24 | `deducing` | pose | `emotes/poses.py:313` | 4 | loop | 38 | 1 | video reference | checked | 0.50 | PASS | not yet | good | pose, video reference |
| 25 | `lowBattery` | pose | `emotes/poses.py:254` | 4.6 | one-shot | 128 | 1 | video reference | checked | 0.50 | PASS | not yet | good | pose, video reference |
| 26 | `menacingPose` | pose | `anims_emotes.py:382` | 4 | loop | 25 | 1 | video reference | checked | 0.50 | PASS | not yet | good | pose, video reference |
| 27 | `nahIdWin` | pose | `emotes/poses.py:137` | 4 | loop | 47 | 1 | video reference | checked | 0.50 | PASS | not yet | good | pose, video reference |
| 28 | `strawberryOnTop` | prop | `emotes/props.py:402` | 4 | one-shot | 111 | 0 | video reference | checked | 0.50 | PASS | not yet | good | prop, video reference; reference has no written beats |
| 29 | `think` | older | `emotes/older.py:152` | 4 | loop | 25 | 1 | video reference | checked | 0.50 | PASS | not yet | good | older, video reference |
| 30 | `handshake` | duo | `emotes/duos.py:140` | 2.4 | one-shot | 75 | 0 | video reference | checked | 0.46 | PASS | not yet | good | duo, video reference; reference has no written beats |
| 31 | `cheer` | free | `emotes/free.py:46` | 2.2 | one-shot | 304 | 2 | Roblox classic | checked | 0.45 | PASS | not yet | good | free, Roblox classic; length frozen |
| 32 | `puppetDance` | older | `emotes/older.py:252` | 2 | loop | 228 | 2 | video reference | checked | 0.44 | PASS | not yet | good | older, video reference |
| 33 | `highFive` | duo | `emotes/duos.py:120` | 2 | one-shot | 108 | 0 | video reference | checked | 0.43 | PASS | not yet | good | duo, video reference; reference has no written beats |
| 34 | `chip` | older | `emotes/older.py:105` | 3.4 | one-shot | 79 | 3 | video reference | checked | 0.42 | PASS | not yet | good | older, video reference |
| 35 | `appleToss` | prop | `emotes/props.py:362` | 3.6 | one-shot | 117 | 0 | video reference | checked | 0.40 | PASS | not yet | good | prop, video reference; reference has no written beats |
| 36 | `itsYou` | pose | `emotes/poses.py:188` | 2.6 | one-shot | 107 | 1 | video reference | checked | 0.38 | PASS | not yet | good | pose, video reference |
| 37 | `mushroomStroll` | stroll | `anims_emotes.py:763` | 3 | loop | 25 | 0 | video reference | checked | 0.38 | PASS | not yet | good | stroll, video reference; reference has no written beats |
| 38 | `twoFingerGrip` | prop | `emotes/props.py:477` | 3 | loop | 18 | 0 | video reference | checked | 0.38 | PASS | not yet | good | prop, video reference; reference has no written beats |
| 39 | `salute` | free | `emotes/free.py:78` | 2 | one-shot | 121 | 2 | video reference | checked | 0.37 | PASS | not yet | good | free, video reference; length frozen |
| 40 | `chocolateSnap` | prop | `emotes/props.py:425` | 3.2 | one-shot | 144 | 0 | video reference | checked | 0.36 | PASS | not yet | good | prop, video reference; reference has no written beats |
| 41 | `coinFlip` | older | `emotes/older.py:190` | 3 | one-shot | 137 | 4 | video reference | checked | 0.34 | PASS | not yet | good | older, video reference |
| 42 | `dance` | free | `emotes/free.py:70` | 1.6 | loop | 154 | 2 | Roblox classic | checked | 0.34 | PASS | not yet | good | free, Roblox classic; length frozen |
| 43 | `appleBite` | older | `emotes/older.py:222` | 2.8 | one-shot | 126 | 3 | video reference | checked | 0.33 | PASS | not yet | good | older, video reference |
| 44 | `theEyebrow` | pose | `emotes/poses.py:171` | 3.4 | one-shot | 46 | 1 | video reference | checked | 0.33 | PASS | not yet | good | pose, video reference |
| 45 | `dance2` | older | `emotes/older.py:15` | 2.167 | loop | 277 | 2 | Roblox classic | checked | 0.33 | PASS | not yet | good | older, Roblox classic |
| 46 | `point` | free | `anims.py:112` | 1.6 | one-shot | 79 | 1 | Roblox classic | checked | 0.32 | PASS | not yet | good | free, Roblox classic; length frozen |
| 47 | `glitchStep` | dance | `emotes/dances.py:366` | 2.4 | loop | 177 | 1 | video reference | checked | 0.32 | PASS | not yet | good | dance, video reference |
| 48 | `furiousScribbling` | prop | `emotes/props.py:266` | 2.4 | loop | 81 | 0 | video reference | checked | 0.30 | PASS | not yet | good | prop, video reference; reference has no written beats |
| 49 | `hairTwirl` | pose | `emotes/poses.py:444` | 2.4 | loop | 27 | 1 | video reference | checked | 0.30 | PASS | not yet | good | pose, video reference |
| 50 | `theClassic` | dance | `emotes/dances.py:64` | 6 | loop | 645 | 3 | mocap | checked | 0.28 | PASS | not yet | good | dance, mocap |
| 51 | `griddy` | stroll | `emotes/strolls.py:24` | 3.45 | loop | 313 | 4 | mocap | authored | 0.26 | PASS | not yet | good | stroll, mocap; status authored (not yet checked) |
| 52 | `cuffedLead` | duo | `anims_emotes.py` (built by name in a loop) | 2 | loop | 3 | 0 | video reference | checked | 0.25 | PASS | not yet | good | duo, video reference; reference has no written beats |
| 53 | `reapersCackle` | pose | `emotes/poses.py:331` | 1.6 | loop | 242 | 1 | video reference | checked | 0.25 | PASS | not yet | good | pose, video reference |
| 54 | `footScratch` | pose | `emotes/poses.py:430` | 2 | loop | 24 | 1 | video reference | checked | 0.25 | PASS | not yet | good | pose, video reference |
| 55 | `ratDance` | dance | `emotes/dances.py:123` | 1.132 | loop | 150 | 1 | mocap | checked | 0.23 | PASS | not yet | good | dance, mocap |
| 56 | `laugh` | free | `emotes/free.py:55` | 1.2 | loop | 101 | 1 | Roblox classic | checked | 0.21 | PASS | not yet | good | free, Roblox classic; length frozen |
| 57 | `shrug` | free | `emotes/free.py:129` | 2 | one-shot | 72 | 1 | mocap | checked | 0.21 | PASS | not yet | good | free, mocap; length frozen |
| 58 | `bunnyEars` | dance | `emotes/dances.py:98` | 1.455 | loop | 126 | 1 | mocap | checked | 0.20 | PASS | not yet | good | dance, mocap |
| 59 | `bouncePump` | dance | `emotes/dances.py:86` | 6.486 | loop | 903 | 2 | mocap | checked | 0.18 | PASS | not yet | good | dance, mocap |
| 60 | `twoLeggedBop` | dance | `emotes/dances.py:339` | 2.4 | loop | 244 | 1 | video reference | checked | 0.18 | PASS | not yet | good | dance, video reference |
| 61 | `puppetPop` | dance | `emotes/dances.py:52` | 7.63 | loop | 901 | 16 | mocap | authored | 0.17 | PASS | not yet | good | dance, mocap; status authored (not yet checked) |
| 62 | `takeTheL` | dance | `emotes/dances.py:74` | 1.6 | loop | 229 | 2 | mocap | checked | 0.16 | PASS | not yet | good | dance, mocap |
| 63 | `excuseMeSir` | dance | `emotes/dances.py:290` | 1.6 | loop | 85 | 1 | video reference | checked | 0.15 | PASS | not yet | good | dance, video reference |
| 64 | `officeParty` | dance | `emotes/dances.py:232` | 6.4 | loop | 780 | 3 | mocap | checked | 0.15 | PASS | not yet | good | dance, mocap |
| 65 | `jackpotShuffle` | dance | `emotes/dances.py:111` | 2.8 | loop | 189 | 2 | mocap | checked | 0.12 | PASS | not yet | good | dance, mocap |
| 66 | `smilingLord` | dance | `anims_emotes.py:791` | 4.8 | loop | 244 | 1 | video reference | authored | 0.12 | PASS | not yet | good | dance, video reference; status authored (not yet checked) |
| 67 | `matchPointServe` | duo | `emotes/duos.py` (built by name in a loop) | 0.8 | loop | 47 | 4 | video reference | authored | 0.10 | PASS | not yet | good | duo, video reference; status authored (not yet checked) |
| 68 | `dance3` | older | `emotes/older.py:26` | 1.6 | loop | 192 | 3 | Roblox classic | checked | 0.09 | PASS | not yet | good | older, Roblox classic |
| 69 | `bow` | free | `emotes/free.py:106` | 2.6 | one-shot | 59 | 2 | video reference | checked | 0.09 | PASS | not yet | good | free, video reference; length frozen |
| 70 | `aceCrouch` | older | `emotes/older.py:177` | 4 | loop | 38 | 2 | video reference | checked | 0.07 | PASS | not yet | good | older, video reference |

### 3.3 The worst fifteen, to watch first

The first fifteen rows above: the seven that fail, then the eight passing clips nearest a limit. Sheet of six of them: `emotes_worst_candidates.png`
(notMyProblem, paradeMarch, itsYou, menacingPose, think, cuffedLead; these were picked from the first, interim ranking, before Tool 1 landed, and are not
the fifteen below. The seven failing ones were not rendered; `review_emote.py` with their names does it).

| # | Clip | Len s | Tool 1 | Nearest or failing limit |
|---|---|---|---|---|
| 1 | `diceTower` | 6 | FAIL: metronome, anticipation | anticipation 1 of 12 |
| 2 | `preDawnBonk` | 3.6 | FAIL: same, anticipation | anticipation 1 of 9 |
| 3 | `finalBreakdown` | 5.4 | FAIL: same, metronome | same timing 10 of 13 |
| 4 | `justAsPlanned` | 9.2 | FAIL: anticipation | anticipation 0 of 10 |
| 5 | `wave` | 2.4 | FAIL: torso | torso 2% |
| 6 | `theLongClimb` | 1.84 | FAIL: torso | torso 3% |
| 7 | `twoWeeksNotice` | 3.2 | FAIL: same | same timing 7 of 10 |
| 8 | `paradeMarch` | 3.2 | PASS | torso 4% |
| 9 | `impossibleLean` | 4.2 | PASS | anticipation 1 of 6 |
| 10 | `jawlineCheck` | 3.2 | PASS | torso 5% |
| 11 | `sugarTower` | 6 | PASS | dead 6.0 s of 8 |
| 12 | `newWorld` | 6.5 | PASS | torso 6% |
| 13 | `boatAura` | 6.4 | PASS | torso 6% |
| 14 | `chipAndPen` | 10.4 | PASS | anticipation 2 of 9 |
| 15 | `reapersEyes` | 3.2 | PASS | torso 6% |

T1 numbers for the fifteen:

| Clip | Verdict | frozen s | dead s (joint) | glides s | slow snaps | anticip. | mirrored arms %, of held s | torso | metronome | same timing | overlap |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `diceTower` | FAIL: metronome, anticipation | 0.3 | 6.0 lShoulder | 0.0 | 0/12 | 1/12 | 0% of 0.7 | 20% | 5 | 6/12 | 13/13 |
| `preDawnBonk` | FAIL: same, anticipation | 0.1 | 0.3 neck | 0.0 | 0/9 | 1/9 | 0% of 0.0 | 12% | 3 | 6/9 | 7/8 |
| `finalBreakdown` | FAIL: same, metronome | 0.1 | 1.0 rShoulder | 2.2 | 1/9 | 3/9 | 0% of 0.0 | 20% | 5 | 10/13 | 2/4 |
| `justAsPlanned` | FAIL: anticipation | 0.5 | 1.6 lShoulder | 0.8 | 0/10 | 0/10 | 81% of 2.9 | 14% | 0 | 3/7 | 4/6 |
| `wave` | FAIL: torso | 0.0 | 1.9 neck | 0.0 | 0/2 | 0/2 | 0% of 0.0 | 2% | 0 | 0/0 | 0/0 |
| `theLongClimb` | FAIL: torso | 0.1 | 1.8 root | 0.0 | 0/6 | 2/6 | 0% of 0.0 | 3% | 0 | 3/5 | 0/0 |
| `twoWeeksNotice` | FAIL: same | 0.2 | 0.3 lShoulder | 0.0 | 0/20 | 4/20 | 0% of 0.0 | 9% | 3 | 7/10 | 9/10 |
| `paradeMarch` | PASS | 0.7 | 1.6 root | 0.0 | 0/7 | 7/7 | 100% of 1.2 | 4% | 0 | 2/6 | 1/2 |
| `impossibleLean` | PASS | 0.6 | 3.1 lShoulder | 0.0 | 0/6 | 1/6 | 100% of 2.8 | 35% | 0 | 0/0 | 0/2 |
| `jawlineCheck` | PASS | 0.0 | 2.7 lShoulder | 0.4 | 2/3 | 1/3 | 0% of 0.4 | 5% | 0 | 0/0 | 1/2 |
| `sugarTower` | PASS | 0.1 | 6.0 lShoulder | 0.0 | 0/1 | 1/1 | 0% of 0.8 | 20% | 3 | 3/9 | 1/3 |
| `newWorld` | PASS | 1.1 | 2.2 root | 1.8 | 2/4 | 0/4 | 100% of 2.5 | 6% | 0 | 0/0 | 0/1 |
| `boatAura` | PASS | 0.4 | 1.2 neck | 0.0 | 1/16 | 7/16 | 0% of 0.8 | 6% | 3 | 6/12 | 7/7 |
| `chipAndPen` | PASS | 0.3 | 4.5 lShoulder | 0.0 | 0/9 | 2/9 | 73% of 3.2 | 14% | 0 | 3/13 | 6/8 |
| `reapersEyes` | PASS | 0.0 | 2.9 lShoulder | 0.0 | 2/4 | 1/4 | 49% of 0.8 | 6% | 0 | 0/0 | 0/2 |

The full per-trait numbers for all 70 are in the JSON the report writes (`check_motion.py --emotes --json out.json`); they were not copied here.

### 3.4 Base movement

`docs/animation.md`: the style the owner approved (fluid R6, limbs slide as well as turn, serious, slouched walk, driven run) is not to be changed.
`check_anims.py --quiet` over the movement set today: **0 clips failed** (soles do not slide, nothing below the floor, no gap at the hip, clean seams,
no joint over 900 degrees a second). **Tool 1 (`--movement`, 21 clips, judged on freezing alone): 19 pass, 2 fail: `idle` (the right shoulder stays within 0.6
degrees for 16.5 s) and `idleGuarded` (the whole upper body still for 3.6 s, the right shoulder for 23.1 s).** `idleGuarded` is what everyone in a case
stands in most of the time. The tool's own notes say the idles fail because the shoulders never move over 0.6 degrees and the runtime life layer
(breath, weight shifts, glances) is what animates them, so this is a lead for the watch (twelve people standing in a meeting must not move in step, and
no idle may read as a loop), not a verdict. Marked `re-act` provisionally; the plan's order for looking for stiffness is the order below.

| Order (plan Stage 4) | Clip | Len s | Plays as | check_anims | Slide studs | Peak deg/s | Tool 1 | Watched | Mark |
|---|---|---|---|---|---|---|---|---|---|
| 1 Strafes and backward (least checked) | `walkBack` | 1.05 | loop | ok | 0.019 | 367/s/s | PASS | not yet | good |
| 1 Strafes and backward (least checked) | `walkLeft` | 1.05 | loop | ok | 0.011 | 372/s/s | PASS | not yet | good |
| 1 Strafes and backward (least checked) | `walkRight` | 1.05 | loop | ok | 0.008 | 375/s/s | PASS | not yet | good |
| 1 Strafes and backward (least checked) | `runBack` | 0.64 | loop | ok | 0.013 | 619/s/s | PASS | not yet | good |
| 1 Strafes and backward (least checked) | `runLeft` | 0.64 | loop | ok | 0.016 | 619/s/s | PASS | not yet | good |
| 1 Strafes and backward (least checked) | `runRight` | 0.64 | loop | ok | 0.015 | 619/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `startStep` | 0.36 | one-shot | ok | - | 374/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `stopLeft` | 0.62 | one-shot | ok | - | 262/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `stopRight` | 0.62 | one-shot | ok | - | 262/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `jump` | 0.5 | one-shot | ok | - | 707/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `jumpApex` | 1.2 | loop | ok | - | 17/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `fall` | 1.6 | loop | ok | - | 26/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `fallLong` | 1 | loop | ok | - | 91/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `landLight` | 0.3 | one-shot | ok | - | 123/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `landNormal` | 0.5 | one-shot | ok | - | 393/s/s | PASS | not yet | good |
| 2 Handovers: set off, stop, air, land | `landHeavy` | 0.9 | one-shot | ok | - | 674/s/s | PASS | not yet | good |
| 3 Forward walk and run, from behind | `walk` | 1.05 | loop | ok | 0.019 | 368/s/s | PASS | not yet | good |
| 3 Forward walk and run, from behind | `run` | 0.64 | loop | ok | 0.011 | 637/s/s | PASS | not yet | good |
| 4 Idles (the two that fail first) | `idleGuarded` | 24 | loop | ok | - | 28/s/s | FAIL: frozen, dead | not yet | re-act |
| 4 Idles (the two that fail first) | `idle` | 24 | loop | ok | - | 8/s/s | FAIL: dead | not yet | re-act |
| 5 Fidgets (judged as plain clips, see note) | `idleLook` | 3.4 | one-shot | info | - | 105/s/s | FAIL: symmetry | not yet | good |
| 5 Fidgets (judged as plain clips, see note) | `idleWatch` | 3.2 | one-shot | info | - | 140/s/s | PASS | not yet | good |
| 5 Fidgets (judged as plain clips, see note) | `idleTie` | 2.8 | one-shot | info | - | 238/s/s | FAIL: torso | not yet | good |
| 5 Fidgets (judged as plain clips, see note) | `idleNeck` | 3 | one-shot | info | - | 49/s/s | FAIL: symmetry | not yet | good |
| 5 Fidgets (judged as plain clips, see note) | `idleSleeve` | 2.6 | one-shot | info | - | 128/s/s | PASS | not yet | good |
| 5 Fidgets (judged as plain clips, see note) | `idleHandsBack` | 4.2 | one-shot | info | - | 63/s/s | FAIL: symmetry | not yet | good |
| 5 Fidgets (judged as plain clips, see note) | `idleGlance` | 2.2 | one-shot | info | - | 208/s/s | FAIL: symmetry | not yet | good |
| 5 Fidgets (judged as plain clips, see note) | `idleArmsCross` | 4 | one-shot | info | - | 121/s/s | FAIL: torso, symmetry | not yet | good |
| 5 Fidgets (judged as plain clips, see note) | `idleHand` | 2.8 | one-shot | info | - | 108/s/s | PASS | not yet | good |
| 5 Fidgets (judged as plain clips, see note) | `idleRoom` | 4.4 | one-shot | info | - | 31/s/s | FAIL: glides, symmetry, overlap | not yet | good |
| 6 Seated and flying | `sit` | 8 | loop | ok | - | 24/s/s | PASS | not yet | good |
| 6 Seated and flying | `flyHover` | 4 | loop | info | - | 7/s/s | FAIL: symmetry | not yet | good |
| 6 Seated and flying | `flyGlide` | 2.4 | loop | info | - | 12/s/s | FAIL: symmetry | not yet | good |
| 6 Seated and flying | `flyRise` | 2 | loop | info | - | 10/s/s | PASS | not yet | good |
| 6 Seated and flying | `flyDive` | 2 | loop | info | - | 10/s/s | PASS | not yet | good |

- The fidgets and the flying clips are not in Tool 1's `--movement` set (`sit` is, and passes). I ran them by name, so
  they were judged as plain clips (all traits): nine of fourteen fail, almost all on **mirrored arms** (a fidget that holds both arms the same, for the whole
  clip: idleNeck, idleHandsBack, idleGlance, idleArmsCross, idleLook, idleRoom, flyHover, flyGlide) and `idleTie` on torso share (1%). They stay `good`; that
  the arms hang alike while a head fidget plays is an observation for the watch, not a fault the plan lists for movement.
- Every one of these is built in `art/scripts/locomotion.py` (cycles, handovers, idles, fidgets, sit, flying; `art/scripts/gait.py` is the arithmetic); played
  by `src/client/Anim/LocomotionController.luau` with `Locomotion/Pose.luau`, `Locomotion/Feet.luau` and `Shared/Anim/Gait.luau`.
- **Turning on the spot** has no clip: it is the controller (the body lags its root up to 25 degrees, the head leads, the feet step after).
  `turnLeft` and `turnRight` are in `check_anims.py`'s strict set but not in the exported index. It can only be judged in the game.
- Sheets, from behind as the game's camera sees them: `movement_handovers_from_behind.png` (startStep, stopRight, stopLeft, landNormal, landHeavy, jump,
  jumpApex, fall) and `movement_strafes_back_from_behind.png` (walk, walkBack, walkLeft, walkRight, run, runBack, runLeft, runRight). From behind the arms
  read as small hanging blocks in the walks and as a wide V in the run; whether the torso twist and the head steadiness read at 18 studs is a watch item,
  not something a still sheet shows.

## 4. Contact sheets (uncommitted, outside the repo)

Rendered with the repo's own review scripts through Blender 5.2 in the background, their preview folder redirected so nothing is written in the repo
([review-scripts-write-into-repo](../agent-memory/review-scripts-write-into-repo.md)). Folder: `C:\Users\user\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_556673c9-7214-4c9a-bf5c-2f0366d61099\stages-2-4-sheets`

| Sheet | What | Script |
|---|---|---|
| `deaths_collapses_front.png`, `deaths_collapses_side.png` | collapseHeart, collapseDisease, collapseAccident, 12 frames each, from 35 and 90 degrees | `review_anims.py` |
| `deaths_scene_remade_victims.png` | the six remade victims: heart, frost, lightning, chip, clock, dark (no reference file) | `review_anims.py` |
| `deaths_scene_referenced_victims.png` | requiem, Blackwall, Sam, sans, Iron Man, selection victims and the patriot's saluter | `review_anims.py` |
| `deaths_table_reactions.png` | the five table reaction clips | `review_anims.py` |
| `wins/newWorld/sheet.png`, `wins/checkmate/sheet.png`, `wins/finalPageBureau/sheet.png`, `wins/checkmateCoven/sheet.png` | the star in its set through each shot of four of the worst win cutscenes (events and effects not drawn) | `review_win.py` |
| `emotes_worst_candidates.png` | six of the most still emotes by an early ranking (notMyProblem, paradeMarch, itsYou, menacingPose, think, cuffedLead), 12 frames each | `review_anims.py` |
| `movement_handovers_from_behind.png`, `movement_strafes_back_from_behind.png` | the handovers and the strafe and backward cycles from behind | `review_anims.py` |

`review_deaths.py` was not run: it renders the shop's death scenes from `deathcuts.CUTS`, which is empty now, and running it rewrites
`src/shared/Cinema/DeathCuts.luau`. `review_emote.py` (props and stills per emote) was not run.

## 5. How the counts were made

- **Scene deaths (Luau).** Cameras: `ctx:shot(t, eye, look, fov, { to })` with a `to` table = moving (a drift); `ctx:camera(t0, t1, function(t))` whose function
  uses its time argument = moving (a ride); `ctx:shot` whose eye or look is a function = following (tracks an actor from a fixed offset); a `ctx:shot` with
  plain points or a `ctx:camera` that ignores its time = locked. A locked-looking `ctx:camera` may still follow an actor, because it reads the actor's live
  position. Effects: screen = `Cinema.flash`, `Cinema.still`, `Vfx.Screen.shake`, `ctx:grade`, `ctx:focus`, `Cinema.tint`; VFX = `Vfx.Emit.burst/make/point`,
  `Vfx.Light.*`, `Vfx.Beams.*`, `Vfx.Recipes.*`, `SceneDeaths.emit` (continuous emitters count once). Text lines (`ctx:say`) are not counted. Hands: `reach(`
  calls plus uses of module-level reach constants in the clip's block in `scene_actors.py` (approximate: helper functions are not followed).
- **Wins.** From `WinCuts.luau`: shots, the `events` and `beats` lists, sounds; hands from `wins.py` the same way.
- **Emotes.** Reference beats = `[[beat]]` entries in the toml; built-in file = the file under `art/scripts/emotes/` that holds the `Motion` (later imports
  override `anims_emotes.py` and `anims.py`, the older versions); keys = exported keys over all joints.
- **Tool 1.** `art/scripts/check_motion.py <names> --json out.json` (Blender's Python): scene, win and reaction clips by name, `--emotes`, `--movement`, then the
  fidgets and flying clips by name. It reads the committed exported keys, so a clip rebuilt but not exported measures as the old one.
- **Muerto for comparison** (the plan): 7 moving, 0 locked, 12 effect events, 13 hands, a reference.

## 6. What was not done or not seen, and how to refresh this

- **Not watched in the game at all** (the owner had Studio open; no Studio, screen or MCP use). So no in-game fault list, no sloppy checklist, no time
  stamps; every `Watched` column says `not yet`, and every mark is provisional.
- Contact sheets show poses, not timing or effects; no spacing strips (Tool 2) or silhouette checks (Tool 3) were used. The seven failing emotes were not rendered.
- The hands counts are approximate (section 5), and cameras that follow an actor can read as `locked`.
- Tool 1 judges an extra the same as a lead when run by name; the tables mark extras and the marks use only the lead.
- The scripts that made the numbers (`collect.py`, `interim.py`, `gen_doc.py`, the Tool 1 JSON) are in `C:\Users\user\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_556673c9-7214-4c9a-bf5c-2f0366d61099\stages-2-4-tools`, outside the repo.
  To refresh after a rebuild: re-export the clips, re-run `check_motion.py` as in section 5, then run `gen_doc.py`.

