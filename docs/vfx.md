# Effects (VFX)

How the game's effects are made, as built by the VFX rework (2026-11-16 to 2026-11-26; the plan and its Log are
`docs/handoff/vfx-rework-plan-2026-11-16.md`). Written to describe what is in the repo and the place today, not what was
hoped: where something was built but is switched off, or was never seen in a real match, this page says so.
`docs/emotes.md` says where each emote's effect lives; the notes in `docs/agent-memory/` (the `vfx-*`, `fx-*` ones) hold
the per-batch numbers and the traps.

**In one paragraph.** There is a kit (`src/client/Presentation/Vfx/`), a texture and mesh library that comes into the
place in the Fx props file (ModelsFx, now version 6), a debug booth that plays any one effect alone and an effect report
that scores it against a bar written as numbers. The new recipes (`Vfx/Fresh/`) sit beside the old ones (`Vfx/Recipes`,
`Presentation/FxKit`), and one switch per effect (`Vfx/Pilot.luau`, 101 flags: 57 ON, 44 OFF) says which build plays. An
effect went ON only when its report passed (or got better) and a booth or lobby picture was clearly better than the old;
everything else stayed OFF and still plays the old way. Nothing was watched in a real match.

## What was built

### The kit (`src/client/Presentation/Vfx/`)

| Module | What it is |
| --- | --- |
| `init` | The public door: `Vfx.Tex`, `Clock`, `Ease`, `Emit`, `Shape`, `Beams`, `Light`, `Screen`, `Ground`, `Rim`, `Recipes`, plus `Vfx.quiet()` (Low graphics or the Governor cut effects) and `Vfx.still()` (Reduce motion). `Fresh`, `Moment`, `Palette`, `Probe`, `Sheets`, `Catalog` and `Pilot` are not exported here: callers require them by path. |
| `Clock` | One per-frame clock for everything that moves (never `TweenService`, whose `Completed` a throttled client can miss). It can be held, so pictures stand still; every step is wrapped so one effect's error never stops another's. |
| `Emit` | Particles from plain specs: `Emit.make`, `Emit.burst`, `Emit.hold`. Specs take `tex`, `size`, `alpha`, `life`, `speed`, `light` (LightEmission), `lit`, `bright`, `ramp = { core, body, edge }`, `grid`/`mode`/`fps`, `variants` and more (the header lists them). Every rate and burst passes through `Emit.share()` (60% on touch, 40% on Low or under pressure). |
| `Sheets` | Pure data: which texture is a flipbook, its grid and how it plays. 8 old sheets keep their old way; 22 new ones play by a declared mode (loop, one-shot with the rate set from the particle's life so the last frame lands at its death, random cell held). `Sheets.plan` answers an emitter's grid, mode and rate. |
| `Moment` | The envelope: `Moment.play(at, { gather, hit, body, residue, lead })` runs the five moments on the kit's clock round one hit time, so a recipe has them by construction and the probe can see them. |
| `Palette` | Colour ramps `{ core, body, edge }`: `Palette.shop(color)` (full colour, the edge a darker shade of the same hue), `Palette.rarity(id)` (the five tiers), `Palette.emote(clip)` (14 emotes' own colours), `Palette.WORLD` (greys, ash, bone, smoke, soot, dust, pale: all under 0.2 saturation) and `Palette.DANGER` (red). |
| `Tex` | Texture names to ids: the id of each name's carrier quad (`Tex_<name>`) in the Fx import. `Tex.FALLBACK` maps each new name to the old texture it wears when the place has an older Fx file; `Tex.real(name)` says whether the real one is there. A workspace attribute `DGVfxLocal` reads the PNGs from Studio's content folder (the harness and private copies). |
| `Shape` | 14 solid meshes (ring, dome, tube, cone, swirl, crescent, sphere, spikes, shard, rock, page, slashArc, twister, shell) grown, held and faded on a curve. Textured shapes are an opt-in that stays off (`Shape.TEXTURED = false`: the Studio test of surface appearances on kit meshes was never run), so shapes are Neon. |
| `Beams` | Ribbons between two points, a flat ring of four curved beams on the floor, lightning (a jagged chain of beams that re-draws a few times a second). |
| `Light` | A flash that dies on a curve (up in 0.04 to 0.06 s, down about three times slower, never a shadow) and a living flame's flicker. |
| `Screen` | Shake, colour flash, field-of-view punch and the anime impact frame: this player's own screen only, none under Reduce motion. |
| `Ground`, `Rim` | Marks on the floor (scorch, cracks, a glowing circle) and debris; a body lit at its edges by a Highlight (skipped when too many are up). |
| `Probe` | The effect report's recorder and judge (below). Off by default; one `if Probe.on then` line in each maker. |
| `Catalog` | The list of every effect, `{ id, family, source, tier, hit, length, play }`: recipes, auras, emotes (from `EmoteFx.clips()`), deaths, scene deaths, wins, writing, covers, forms, moments, world, plus the `recipe_new_*` variants and the `world_*_fresh` pairs (93 entries at stage 4c, a few more since). |
| `Fresh/*` | The remade recipes, below. |
| `Recipes`, `Presentation/FxKit` | The OLD recipes and the older thin layer. Still called (see "Removal plan"). |
| `Pilot` | The flag table (below). |

**The Fresh recipes** (`Vfx/Fresh/`, each built on `Moment`, with a dark layer laid over rather than added, a white-hot core
at brightness about 2.3, a light on the beat, and a residue): `impact` (styles sharp, heavy, soft), `slam`, `slash`, `glint`,
`pillar`, `arc`, `charge`, `flame` (candle, fire or aura kind), `fireBurst`, `smokePuff`, `dustKick`, `mist`, `dissolve`,
`scatter` (paper, feathers, shards), `sigil`; and, added by the roll-out, `Menace`, `Small` (`tap`, `stepDust`, `spores`,
`scuff`, `breath`, flecks: the accents for things that fire every step or beat), `Gameplay` (dissolve, sparks, floor dust,
haunt mist, the dive crash, the eyes) and `Win` (the win cuts' fx kinds). `Fresh/Defs` is the pure declaration of all of
it (textures, moments, parameters, booth variants, `Defs.hitOf`, `Defs.idOf`). Each is `Fresh.<name>(at, options)` with
`ramp`, and returns a cancel (or a handle: `flame` has set, flare, out, destroy; `charge` has release; `mist` has stop).

### The texture library and the meshes (`art/scripts/vfx/`)

- 49 textures ride in the Fx props file as `Tex_<name>` carrier quads: the 23 old ones and 26 new 1024 px sheets (smoke
  puff, plume, dust roll, mist; fire, fire burst, candle, aura flame; impact A, B, C, shock, glint, sparks; slash A, B,
  arc, energy wisp; ash flakes, shards, paper, feather tumble; crack A, B, scorch, sigil). `VfxGlow`, `VfxEmber` and
  `VfxStreak` stay as the support dots (a halo behind, specks, a glint on top); the plan's rule is that the main layer of an
  effect is a shaped texture or mesh, never one of those.
- They are drawn by script, nothing borrowed: `tex_smoke.py`, `tex_fire.py`, `tex_impact.py`, `tex_slash.py`,
  `tex_matter.py`, `tex_floor.py` with `noise.py`, `draw.py`, `volumes.py`; `meshes.py` builds the 14 shapes (one UV rule:
  u once round, v up; `check_meshes.py`) and the Fx file; `preview.py` draws a sheet tinted over dark or light (they are white
  on clear, so never judge one in an image viewer).
- `check_textures.py` (Blender's Python, writes nothing) judges fill, edge, tone, motion, erosion and size. Today: 33 pass,
  16 fail, and all 16 are OLD sheets: VfxAsh, VfxCandleFlame, VfxChunk, VfxCircle, VfxColumn, VfxCrack, VfxDust,
  VfxFeather, VfxFlame, VfxMoth, VfxPage, VfxRing, VfxRingBand, VfxSlash, VfxSmoke, VfxWisp. Every new sheet passes. A
  pass is a floor (not small, flat, still or bleeding), not a judgement.
- Fx v6 (2026-11-26): `DeathsGambitModels_Fx.fbx`, 15,357,676 bytes, built by `meshes.py` alone, version marker
  `DeathsGambitModelsFx_Version_6` (bumped in `art/scripts/maps/export.py` and `src/shared/ImportVersions.luau`), checked by
  `check_fx_export.py` (every PNG embedded byte for byte, the old ones equal to the previous file's, UVs, carriers, the
  marker). Imported by Open Cloud (asset 123679627680169, shared with the universe, place v654 saved, not published).
- Budget: the Fx file counts in every scene (`scripts/budget.py`). `art/budget.json` records two exceptions (Fx 4: about
  23 megapixels and 11 MB; Fx 5: 4.2 megapixels and 1.8 MB), both written as the owner's call to veto: they were not shown the
  figures. With them only Campus is over, by 0.07 megapixels, as it already was. The old sheets that a Stage 5 clean-up
  would have deleted to give 8.3 megapixels back are all still in use, so those exceptions stand (see "Removal plan").
- The fire sheets took two tries. v5's `VfxFire` read in the real lobby as a fan of white spikes: the game draws every flame
  sheet twice (a body layer and a half-size white-hot copy), so a sheet of separate tongues gives two fans. v6 draws one
  cohesive flame each (tongues grown from one body, nothing detached). A flame sheet is judged through that two-layer draw,
  not on its own (`docs/agent-memory/fx-v6-fire-redo.md`).

### The booth and the effect report

- **Booth** (`src/client/Debug/FxBooth.luau`, the Effects tab of the debug panel, F2): a grey cell 6000 studs out
  (`FxBooth.ORIGIN`; `World/Away` parks the crowd and rain), a dummy, backdrop `dark` or `lit`, camera `follow` (18 studs
  back, as a player sees an emote) or `close`, and `hold`. Hooks, also on `DebugPanel.fx`: `list()`, `play(id, opts)`,
  `stop()`, `at(id, seconds)` (plays and holds the clock that many seconds after `hit`), `step(s)`, `release()`,
  `leftovers()` (what is left in `Camera.DGVfx`; 0 after Stop), `verify()` (every catalogue entry plays, the list matches
  `EmoteFx.clips()`; returns `{}` when clean), `report(id)` and `reportAll(...)`. `play` and `at` yield, so give each its own
  thread. Emotes play as a player sees them (`preview = false`), whole scenes (wins, scene deaths, writing) on the player's own
  camera.
- **Report** (`Vfx/Probe.luau`, `FxBooth.report`): plays the effect with the probe on and prints `PASS` or `FAIL` with
  reasons. `Probe.judge` reads: **dots** (layers whose texture is one of the plain dots; fail over half, or no shaped layer),
  **moments** (a layer before the hit, the biggest and brightest starting within 0.05 s of it, something alive 1 s after;
  loops: an ignition burst and four layers), **pops** (a long life born half opaque at a third of its size, or dying not
  shrunk away), **values** (a dark layer under 0.5 light when the biggest layer is over 3 studs, a core with brightness 2 or
  more), **light** (a light on the beat for sealed and up), **cost** (peak particles, big sprites, emitters, lights, against
  the budgets below). It cannot see hand-fired `:Emit` counts (it says `+N by hand`), parts, meshes, highlights, sounds, or
  changes made after an emitter is built, and its counts are at 100%, not after `Emit.share()`. It is a floor, not a judge.
  The first report of a play session is a warm-up (a stray light, an off-beat layer): run it twice and read the second.
- Specs (data only, `src/server/Tests/`): `VfxCatalog`, `VfxTex`, `VfxSheets`, `VfxMoment`, `VfxPalette`, `VfxRecipes`,
  `VfxProbe`, with the `Emotes` and `EmotePolicy` ones: the nine Vfx and Emote specs passed 103, failed 0 at the last
  run (2026-11-26).

**Budgets** (Part 9 of the plan; the report reads them):

| Tier of effect | Particles alive at peak | Sprites of 8 studs or more | Emitters | Lights |
| --- | --- | --- | --- | --- |
| World loop (a candle, haze) | 12 | 1 | 4 | 0 (the prop has the lamp) |
| Accent (Penned, a step, a glint) | 60 | 2 | 6 | 1 |
| Showpiece (Sealed, Condemned, a death) | 250 | 6 | 12 | 2 |
| Scene (Godhood, a scene death, a win) | 600 | 10 | 20 | 3 |

Design at 100% and check at 40%. Loops keep under 40 particles a second per emitter. Lights never cast shadows. A new
texture costs memory on every phone, so textures are reused.

## The Pilot flags (`Vfx/Pilot.luau`)

`Pilot.on.<name>`: true plays the new build (Fresh), false plays the old build that is still in the code. The call sites read the
table, so a before and an after come from the same code with one flag flipped; a script sync (Rojo) picks a change up. There
are **101 flags: 57 ON, 44 OFF.** ON means: the effect report passed or had fewer reasons AND a booth or lobby picture read
clearly better than the old (the plan's rule: a thing that is not better does not ship). ON does not mean seen in a real
match, on a phone, on Low graphics or under Reduce motion: none of that was looked at. OFF means built and either not
seen in any picture or not better; the reason is on the row. The OFF reasons come from the comments in `Pilot.luau` and the
rollout notes (`vfx-rollout-4a-first-batch` to `4f`, `fx-v6-fire-redo`); a few "not seen" ones are the booth's limit
(a black dummy, rate emitters and short soft sheets that do not show in a still), not a verdict that they look bad.


**Pilot and aura (read in Presentation/DeathFx, EmoteFx/Poses, World/CoverTells, Presentation/Aura)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `impact` | ON |  |
| `menacing` | ON |  |
| `cover` | ON |  |
| `aura1` | ON |  |
| `aura3` | ON |  |
| `aura2` | ON |  |

**Godhood emotes (Controllers/EmoteFx/Godhood)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `finalBreakdown` | ON |  |
| `justAsPlanned` | ON |  |
| `reapersEyes` | OFF | the second try (20 emitters) was not clearly better than the old build (vfx-rollout-4b-fourth-batch) |
| `newWorld` | ON |  |

**Emotes, second batch (EmoteFx/Duos, Strolls, Props)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `cuffedLead` | ON |  |
| `theLongClimb` | ON |  |
| `griddy` | ON |  |
| `mushroomStroll` | ON |  |
| `preDawnBonk` | ON |  |
| `diceTower` | ON |  |

**Emotes, third batch (EmoteFx/Older, Props, Dances)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `writeAir` | ON |  |
| `blindfoldLift` | ON |  |
| `blindfoldLiftUp` | OFF | the LIFT press (never seen in the booth: stays off |
| `aceCrouch` | ON |  |
| `chairPerch` | ON |  |
| `chipAndPen` | ON |  |
| `strawberryOnTop` | ON |  |
| `sugarTower` | ON |  |
| `bunnyEars` | ON |  |

**Emotes, fourth batch (EmoteFx/Dances, Poses, Props, Older, Everyone)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `twoLeggedBop` | ON |  |
| `ratDance` | ON |  |
| `boatAura` | ON |  |
| `officeParty` | ON |  |
| `glitchStep` | ON |  |
| `goalCelebration` | OFF | the landing is a small ring against the old thud's big floor wave and cracks: weaker, so not shipped |
| `smilingLord` | ON |  |
| `excuseMeSir` | OFF | Excuse Me, Sir: the cough; a breath of pale mist, not seen in the dark booth |
| `excuseMeSirUp` | ON | its LOOK UP: the glint of sky |
| `animatronicWelcome` | OFF | no visible difference in the booth |
| `jackpotShuffle` | ON |  |
| `lowBattery` | ON | Low Battery and its CHARGE |
| `impossibleLean` | ON |  |
| `itsYou` | ON |  |
| `deducing` | ON |  |
| `reapersCackle` | OFF | dark smoke on a dark booth: not seen |
| `menacingPoses` | OFF | the other five poses of Menacing Pose, NEXT POSE: 13 emitters against 12, no better than the old build |
| `twoFingerGrip` | OFF | report only, no picture taken |
| `furiousScribbling` | OFF | Furious Scribbling and WRITE IT: report only, no picture taken |
| `appleTossThrow` | OFF | black feathers on a dark booth: not seen |
| `chocolateSnap` | OFF | dark crumbs on a dark booth: not seen |
| `fortySeconds` | OFF | the new heartbeat showed a white square and lost the red: worse than the old build |
| `appleBite` | ON |  |
| `puppetDance` | OFF | Puppet Dance and Bye Bye Bye: report only, no picture taken |
| `appleToss` | ON |  |

**Manual covers other than the Black Mirror (World/CoverTells)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `coverOxblood` | ON |  |
| `coverGilded` | ON |  |
| `coverBurnt` | ON |  |
| `coverCasefile` | OFF | the pages did not show in the booth, before or after: not seen |
| `coverIron` | ON |  |
| `coverScale` | OFF | the eye did not show in the booth, before or after: not seen |

**Win cuts, fx act kinds (Presentation/WinCinema, Fresh/Win)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `winFxImpact` | ON |  |
| `winFxGlint` | ON |  |
| `winFxPillar` | ON |  |
| `winFxWave` | OFF | 2026-11-26 side by side in the lobby: the new ring is a thin pale line, the old a wide band: not clearly better |
| `winFxBolt` | ON | 2026-11-26, fired beside a real cut and in the lobby: forked branching strokes, the old bolt is a stack of pasted white quads |
| `winFxSparks` | ON | 2026-11-26: thin hot streaks and a star, the old sparks are short white dashes |
| `winFxBloom` | OFF | 2026-11-26: floods the floor white in the lobby light: too much |
| `winFxRing` | OFF | 2026-11-26: a dark smoky rim round the white ring reads heavy |
| `winFxDust` | ON | 2026-11-26: a soft shaped puff on the floor, the old dust is nearly invisible |
| `winFxEmbers` | OFF | 2026-11-26: the orange never showed among the kinds fired side by side: not seen |
| `winFxMotes` | OFF | 2026-11-26: reads as glitter stars, not dust drifting in a light |
| `winFxAsh` | OFF | 2026-11-26: big black clumps against the old fine flakes |
| `winFxDrizzle` | OFF | 2026-11-26: no different from the old thin streaks |

**Writing styles (Presentation/Styles.write)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `writeQuill` | ON |  |
| `writeTypewriter` | ON |  |
| `writeFire` | ON |  |
| `writeKnife` | ON |  |
| `writeChalk` | ON |  |
| `writeFrost` | ON |  |

**Deathsinger forms (Presentation/Styles.form; retired from sale, still owned and worn)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `formEmbers` | OFF | retired from sale; the booth picture showed only the shoulder flames, the same in both builds: not seen to differ |
| `formVeil` | OFF | not seen |
| `formChains` | OFF | not seen |
| `formCrows` | OFF | not seen |
| `formMoths` | OFF | not seen |

**Deaths and gameplay moments (Presentation/DeathFx, DeathVfx, EyesDealFx, Fresh/Gameplay and the callers named)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `deathSparks` | OFF | handcuffs, the Manual landing: DeathFx.sparks; the booth picture showed a soft ring with a small star against the old hard spiked star: not better |
| `deathChalkDust` | OFF | the dust as the chalk outline cuts in: DeathFx.chalk; the FxChalk picture is not in Fx 4 here, so never seen |
| `deathDissolve` | OFF | voted out: the ash off the body, DeathFx.dissolve; report fewer reasons but nothing showed in a booth picture, old or new: the emitters sit inside the black torso |
| `deathDust` | OFF | DeathVfx floor dust for the collapses; report only, no picture |
| `deathPuff` | OFF | DeathVfx sick breath and the last breath of the heart; report only, no picture |
| `deathGlow` | OFF | DeathVfx glow: the heart seizure; report only, no picture |
| `deathAccident` | OFF | DeathVfx collapseAccident: the head meeting the floor; report 4 pop reasons to 2, no picture |
| `eyeGlow` | OFF | a stare red eyes: a glint as each opens, World/EyeGlow; report only, not photographed |
| `hauntMist` | OFF | a Specter Mist haunt, UI/HauntBar; seen once as a thin pale roll along the floor against the old fuller puff, not clearly better; the second try lost to the Governor |
| `diveCrash` | ON | the dive crash into the roof, Controllers/DiveController; report FAIL to PASS, 14 emitters to 8, 25% dots to 0, picture: a clean flat blow with a l... |
| `eyesDealEyes` | OFF | the Deathsinger eyes lit, Presentation/EyesDealFx; report only, not photographed |
| `eyesDealIgnite` | OFF | your eyes taking fire, Presentation/EyesDealFx; seen: a bright white star in the middle of the face, the deal red is lost, so not shipped |
| `manualFire` | OFF | the Manual's red fire, UI/WorldFx; seen 2026-11-25 with the real VfxFire (Fx 5): a fan of white spikes with pink fringes, the danger red lost, bigger than the old flame: not better; 2026-11-26 with the v6 sheet and a smaller, dimmer heart layer: one cohesive flame now, but a flat pink silhouette on the lobby's grey, the red still lost: not better |
| `trialWisp` | OFF | the Trial's wisp flame, Onboarding/TrialWisp; seen 2026-11-25 with the real VfxFire: detached white teardrops, the amber lost, the old flame is a single cohesive one: not better; 2026-11-26 v6: a cohesive cream slab, amber lost, twice the old's height: not better |

**World flames (World/Flames, World/ReadyCircle)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `worldCandle` | ON | the maps' candle wicks: ON 2026-11-26 with the v6 candle sheet (Fx 6): in the lobby a teardrop with a dark wick against the old tall narrow shard, ... |
| `worldBrazier` | OFF | the maps' braziers: 41 to 2 particles; with the v6 sheet (2026-11-26) one cohesive flame, but a flat milky silhouette (additive pale on the lobby's grey) against the old's lit glow, report "no dark layer": not better |
| `readyCandles` | ON | the lobby's ring of ready candles: same call as worldCandle, same lamp, ON for the same reason |

**Shared pieces (Presentation/Materialize, Specter/GhostController, DiveController, ViewFx)**

| Flag | State | Why (OFF) or note (ON) |
| --- | --- | --- |
| `materialize` | ON |  |
| `glintGhost` | OFF | built, never seen in the game (the booth does not play it) |
| `glintDive` | OFF | built, never seen in the game (the booth does not play it) |
| `viewfx` | OFF | the shop cards draw the new texture names (ViewFx.RENAMED); off until the cards are seen |

## House rules

These stand, and every new effect follows them.

1. **Grey world, colour is earned.** World and gameplay effects (candles, haze, rain, deaths by plain causes, the Trial's
   wisp, the eyes) live in the game's greys, bone and soft white (`Palette.WORLD`). Red means danger (the UI rule); crimson as
   a tier colour is Godhood's. **Full colour for the shop (the owner, 2026-11-16: "Yes, full colour"):** anything bought
   (emotes, Manual covers, writing, wins, forms, custom deaths) wears its own colour or its tier's at full strength; only its
   white-hot core is white, and its edge is a darker shade of the same hue, never a grey (`Palette.shop`, `Palette.rarity`).
   Each emote keeps the colour chosen for it (The Long Climb and Jackpot Shuffle are green).
2. **No ink.** No pools, splashes, dripping or ink-coloured wisps, and no ink words in player text (the owner, 2026-10-21).
   Pick dust, ash, smoke, embers, light, glass or paper.
3. **No `Trail` instances.** The owner took trails out; streaks are Beams or particles.
4. **The motion comes first.** An effect lands on a beat the body already makes; it never stands in for a missing movement.
5. **One idea per effect.** Each has a motif of its own rather than the same burst in another colour; a higher tier gets more
   layers, not more of the same particle.
6. **Readable from the default camera**, not only in the showpiece shot.
7. **Never hide another player.** Effects stay near the body (about 6 studs), fade within a few seconds and keep off the faces
   of people standing nearby. **No full-screen flash for anyone but the player it belongs to** (`Screen` is this client's own
   screen; post effects go on the camera, never on Lighting).
8. **Reduce motion: nothing that shakes, flashes or spins.** `Screen.*` does nothing under it, and recipes drop spin, beams and
   waves (`Vfx.still()`); this is coded but was not looked at by eye.
9. **Every effect belongs to its owner.** Made under its session, destroyed with it, gone when the emote is cancelled halfway
   (the booth's `leftovers()` is 0 after Stop for every flag that is ON).

**The bar** (what the report's numbers stand for; the review checklist for a new effect): five moments on purpose (gather,
hit, body, break-up, residue; a loop has an ignition, a steady state and an ending); a shaped main layer; three values (a
white-hot core, a body in the colour, a dark layer laid over with `light = 0` so it still reads in a lit room); the core glows
(brightness 2 or more) and the body does not (under 1.2), and skin never glows; a light on the beat; motion like the thing it is
(smoke rises and slows, sparks fall); on the body's beat; one idea from the game's own world (paper, ash, candle, feathers,
chalk, glass, stone, the apple, chains, cold light); inside its budget.

## Timing

- **Anticipation, hit, settle.** A small gather before the beat, the hit on the frame the pose lands, then a slower fall-off
  (2 to 4 times the rise).
- **Beats come from the clip.** `EmoteFx` gets the session's phase and the clip's time (`accent`, `onBeats`, `burst`);
  effects are placed at clip seconds, so a late joiner or a slowed clip still lines up.
- **In and out.** A looping effect fades in over 0.2 to 0.4 s and out over 0.3 to 0.6 s; nothing appears or vanishes in one
  frame. A cancelled emote fades its effects out in 0.2 s.
- **A one-shot sheet needs particle lives of frames / 30 s or more** (a 4x4: 0.55 s, an 8x8: 2.1 s), because flipbooks play at
  most 30 frames a second.
- **Sound with the picture.** Cue slots (`EmoteMedia.CUES`) sit on the same beats; the ids are the owner's.

## The camera

- Lobby only: no camera moves in a case (the owner's rule); effects still play there in full.
- Each showpiece emote gets one move (push-in, low hero, high angle, over the shoulder, side track, orbit, hold), eased with
  Sine InOut, its peak on the key beat. Cuts belong to the Godhood and win cutscenes.
- Scriptable camera at `Enum.RenderPriority.Camera`; always handed back to the player's camera on end, cancel, death, respawn or
  error.

## Animation notes

The game plays its own R6 clips (`PoseController`/`ClipPlayer`, `docs/animation.md`), not Roblox `AnimationTrack`s, so
Roblox's priorities do not apply; the same ideas are ours: clips ease in and out, an upper-body mask leaves the legs to the
movement set, the floor guard keeps soles out of the floor. Each clip is measured by the checks in `art/scripts` and judged by
eye on render sheets.

## Keeping it cheap

- **Reuse.** One emitter per job, fired with `:Emit`; one Highlight per effect; shared textures. Recurring parts come from a pool.
- **Short lives.** Accents live 0.3 to 1.5 s; loops keep their rate under about 40 a second per emitter and their particles
  small (fill rate and overdraw are what cost).
- **Everything belongs to the session** (`EmoteController`): nothing outlives the emote or runs each frame after it ends.
- **Low graphics.** On the lowest quality levels effects drop to their first rung (`EmotePolicy`, `EmoteFx`); a match no longer
  caps them (the owner's call). `World/Governor` cuts particles when frames run slow.
- **Flipbooks may be switched off on weak phones**, so frame 1 of every sheet must read as the thing by itself.
- **Test both ends.** Lowest and highest quality; the phone share (`DGForceDevice=phone`).

## How to test an effect

None of this needs a real match; none of it replaces one.

1. **Numbers first.** In a Studio Play session, the client: `DebugPanel.fx.verify()` (returns `{}` when clean) and
   `DebugPanel.fx.report("<id>")` twice (the first is a warm-up). Then `stylua`/`selene` on changed files and the nine Vfx
   and Emote specs.
2. **Pictures through the private-copy method.** Build the client with Rojo into an rbxm, load a private copy in a Play
   client with `game:GetObjects`, and `require` `Debug.FxBooth` and `Presentation.Vfx.Pilot` from the copy: the copy has your
   edits and a flag flipped there reaches only the copy. Put the effect on the lit backdrop (a black dummy and a black
   book are invisible on dark), take the picture with `screen_capture` and an explicit `camera_position` and `look_at_position`
   (the booth's close camera is `ORIGIN + (0, 3.9, 8.5)` looking at `ORIGIN + (0, 3.2, 0)`), and put before and after side by
   side (a sheet made with .NET `System.Drawing` from PowerShell; Blender's Python has no PIL). Judge on the lit backdrop.
   Notes: `vfx-pilot-booth-capture`, `vfx-rollout-4b-third-batch`, `vfx-rollout-4c`.
3. **Readable booth pictures.** Short and soft effects are gone by the time a capture lands: set the emitters' `TimeScale` to
   0.25 to 0.5 BEFORE emitting (`e.TimeScale = ts; e:Emit(8)`, in its own call), never to 0 or 0.001 and never `Clock.hold(true)`
   (a frozen particle draws at age 0 and is invisible; release the hold before the next effect). Rate emitters do not show in a
   still at all, so booth loops are fed by hand (`emitter:Emit(n)` in a `Clock.every`). The soft sheets (VfxMist, SmokePuff,
   SmokePlume, AshFlakes) are only 25 to 60 percent opaque in the texture: ask for a particle transparency of 0.05 to 0.3. In the
   dark booth use `light` 0.8 and `lit` 0.1 for anything coloured.
4. **Traps that made earlier pictures lie.**
   - The Governor cuts particles after about 10 s of a play session (Studio runs 15 to 20 fps while captured): stop and start
     play before each effect, do the first call as a warm-up, capture at once.
   - Studio must be the FOREGROUND window: a minimised or background Studio draws no 3D (captures come out black, the kit
     stops drawing), and the first capture after another tool call may need the window fronted again.
   - A stage 6000 studs out reads pure black in a play session with an explicit camera: for fire and world flames, stand the
     effect in the real lobby near the player (the lobby's own fog gives the true grey) and put the camera in front of it, not in
     the player's body.
   - A held `fx.at` time is only roughly the real time (a hit marked at 0.4 s can show at 0.7 s).
   - `fx.play` in a command-bar copy of the client can fail with "TweenService:Create ... Instance is null": that copy's
     `LightingController` was never initialised (`booth-fx-play-uninitialised-lighting`).
5. **Cutscenes and wins** are not judged in a private copy (it renders them black): sync scripts first (Rojo), then use the
   place's own client and the Debug gallery (`vfx-rollout-4f` has the route: panel visible by script, the "watch" remote, click
   coordinates offset by the Studio top bar).
6. **Never** start a second Studio or the harness beside the owner's Studio or Roblox player without asking: it has crashed their
   Studio once and the capture folder is cleared while a player runs (`studio-mcp`, `studio-mcp-play-test-traps`, `studio-no-screen`
   and `studio-capture-disturbs-camera` in `docs/agent-memory`).

## What is still open

From the plan's Log, as of 2026-11-26:

- **Fire for the Manual, the Trial and the braziers looks worse than the old flame in the lobby and stays OFF.** The v6 flame is
  one cohesive shape now, but on the lobby's grey it is a flat pale silhouette (the additive tint turns red pink and amber
  cream; alpha-blending the body goes brown), the old flame's lit red glow with a white core reads better, and the new one
  stands 1.5 to 2 times taller. `manualFire`, `trialWisp`, `worldBrazier` are the flags. A fix needs either a redrawn sheet
  with real value contrast and a shorter silhouette (and another Fx import) or the cheaper Luau route (LightEmission about
  0.5, a darker more saturated body colour, the old recipe's soot layer). That, or keeping the old flame, is the owner's call.
- **The twelve other scene deaths and the Blender shots' `fx` events (`ShotPlayer`) were not played** for this work. Only the
  eight win cuts and three scene deaths (lightning, frost, heart) were watched, in the place's own client (stage 4f, partial).
  The ten OFF win fx kinds (wave, bolt, sparks, bloom, ring, dust, embers, motes, ash, drizzle) need a script sync and a run in
  the place's own client before they can be judged. Two win mid-shots (caseClosedCoven, checkmateCoven) read near-empty in
  one run each and should be seen again with no capture before them.
- **The aura's flame tongues (`VfxAuraFlame`) have not been seen in a real emote.** Levels 1 to 3 are ON on the strength of the
  report (FAIL to PASS) and a lit haze, wisps and a floor pool in stills; no tongue could be told apart.
- **Phone, Low graphics and Reduce motion were not eye-checked** for any batch (coded, not looked at).
- **Frame time in a full lobby was never measured.** The world flames' cost is read from the report only (the lobby has one
  mapped candle and twelve ready candles; unlit ones cost nothing).
- **Candles inside a real match** are unseen (the lobby is the only place the new candle was photographed).
- **16 old texture sheets fail `check_textures`** (listed above): they are the old ones that the old recipes still use.
- Smaller ones: `glintGhost`, `glintDive` and `viewfx` are built and never seen in the game; the Black Mirror's tell and the
  Case File and Scale covers were never visible in a booth picture; `LampHaze`, `AirFx`, rain and `MapAmbient` were left
  alone on purpose (`vfx-rollout-4e` has why); textured shapes (the Studio surface-appearance test) were never run.

## Removal plan

Nothing is deleted. The old code and textures stay because every OFF flag falls back to them, and, as the greps below show, a good
part of the old code is still called with no flag at all. Claims checked by grep on 2026-11-26 (`src`, ignoring specs,
`Debug/FxBooth` and `Vfx/Tex.luau`'s own lists).

**1. Old builds that become dead code once a flag is ON for good.** Delete the `else` branch (or the old function the flag
replaces) only after the owner has looked at that effect in the game and agreed to keep the new one. 54 flags are ON; the old
branch of each can go. The ones that take a shared piece with them:

| When this stays ON | This old code has no caller left | Also loses a caller |
| --- | --- | --- |
| `aura1`, `aura2` and `aura3` | `startOld` and its helper `steady` in `Presentation/Aura.luau` (lines 205 to 593; `Aura.start` at 1038 to 1041 is the only caller) | `VfxFlame` (Aura:271), `VfxSlash` (Aura:346) |
| `justAsPlanned` | the old branch of Just As Planned in `EmoteFx/Godhood.luau` (`Recipes.impact`, `FxKit.shape("dome")` at 666 to 670) | `FxKit` (1 of 4 callers) |
| `finalBreakdown` | the old slam in `Godhood.luau` (`Recipes.slam`, `FxKit.rocks`, 816 to 817) | `FxKit`, `Recipes.slam` (1 of 4) |
| `preDawnBonk` | the old Bonk landing in `EmoteFx/Props.luau` (`FxKit.rocks`, `FxKit.shape`, 115 to 116) | `FxKit` |
| `theLongClimb` | the old step ring in `EmoteFx/Strolls.luau` (`FxKit.shape("ring")`, 409) | `FxKit` |
| `worldCandle` and `readyCandles` | the candle branches in `World/Flames.luau` and `World/ReadyCircle.luau` (`Recipes.flame` kind candle) | part of `Recipes.flame`'s candle kind |
| `impact` | the old burst in `Presentation/DeathFx.burst` | |
| `materialize` | the old haze in `Presentation/Materialize.luau` | |
| each other ON flag (`menacing`, `cover`, `coverOxblood`, `coverGilded`, `coverBurnt`, `coverIron`, `writeQuill`, `writeTypewriter`, `writeFire`, `writeKnife`, `writeChalk`, `writeFrost`, `winFxImpact`, `winFxGlint`, `winFxPillar`, `winFxBolt`, `winFxSparks`, `winFxDust`, `diveCrash`, and the 27 other emote flags marked ON) | its old build, inside the same file (the emote ones are wrapped by `flag(name, fresh, old)` in `EmoteFx/<family>.luau`) | |

**2. Old modules.**

- **`Presentation/FxKit.luau` (199 lines): not yet.** Four modules require it: `EmoteFx/Godhood`, `EmoteFx/Props`,
  `EmoteFx/Strolls` (all four of their uses are the old branches in the table above, so they go with `justAsPlanned`,
  `finalBreakdown`, `preDawnBonk`, `theLongClimb` ON for good) and `Presentation/WinCinema` (`FxKit.shape` at 894, 931, 936 and
  `FxKit.light` at 941, in the stamp act and the king's burst: no flag guards these). `UI/Shop/Card.luau` only mentions it in a
  comment. FxKit can be deleted after WinCinema's two spots move to `Fresh` and those four flags are kept.
- **`Vfx/Recipes.luau` (798 lines): not yet.** 38 call sites outside the booth and the module. **15 sit in the nine
  `Presentation/SceneDeaths/*` files, which read no flag at all** (Blackwall, Chip, Clock, Frost, God, Heart, IronMan,
  Lightning, Selection); `WinCinema` (`impact`, `flame`, `twinkle`, `pillar`: 7), `DeathVfx`, `DiveController`,
  `GhostController`, `EmoteFx/Dances`, `Older`, `Shared`, `Poses`, `Godhood`, `World/Flames`, `ReadyCircle` and `UI/WorldFx`
  hold the rest, some inside old branches (the table above) and some behind OFF flags (`worldBrazier`, `manualFire`,
  `glintGhost`, `glintDive`), some unguarded (`twinkle` in `Dances`, `Older` and `Shared`). It can go only when all of these
  are on `Fresh` or the flag branches are deleted, and the old entries in `Vfx/Catalog` (15 references: the booth's "before" rows) go with
  it. Biggest blockers: the nine scene deaths and `WinCinema`.
- `Vfx/Fresh/*`, `Moment`, `Palette`, `Sheets`, `Probe`, `Catalog` and the booth are the kit now: keep.

**3. Old textures.** A PNG leaves only with its builder in `art/scripts/vfx/textures.py` and a bump of the file that carries it
(an Fx or Core import), so do it once, at the end, not per texture. None can go today:

| Old texture | Still referenced by (`src`) | Could go when |
| --- | --- | --- |
| `VfxCandleFlame` | `Recipes.luau:455` only (the candle kind) | `Recipes.flame` has no candle caller: `WinCinema:148,158` and `SceneDeaths/Selection:206` move to `Fresh.flame` (`Flames` and `ReadyCircle` already have, `worldCandle`/`readyCandles` ON). The only old texture with a single referrer |
| `VfxSlash` | `Aura:346` (dead once `aura1`/`aura2`/`aura3` stay ON) and `EmoteFx/Props:689` (Furious Scribbling's WRITE IT slash) | `furiousScribbling` ON for good as well |
| `VfxAsh` | `Recipes.luau:730` (the dissolve) and `WinCinema:1356` (the old held ash kind) | `Recipes.dissolve` has no caller (`SceneDeaths/God`, `IronMan`, `Selection`) and `winFxAsh` is ON for good |
| `VfxFlame` | `Godhood:681`, `TrialWisp:162,181`, `Aura:271`, `Styles` (326, 1305), `Recipes` (507, 533), `GhostController:203` | `trialWisp`, `manualFire`, `worldBrazier`, the old Styles forms and `Recipes.flame` are all gone or ON |
| `VfxMoth` | `UI/Shop/Card.luau:244,251` (the shop card, no flag) and `Styles:1571` (old form) | not while the shop card draws it |
| `VfxCircle`, `VfxPage`, `VfxFeather`, `VfxSmoke`, `VfxDust`, `VfxWisp`, `VfxChunk`, `VfxBurst`, `VfxRing`, `VfxCrack` and the others | live callers with no flag (`Godhood`, `CoverTells`, `Shape`, `SceneDeaths`, `Card`, `Styles`...) | after a move of every caller to a new sheet; most are still the fallbacks in `Tex.FALLBACK` too |

Unused already (no Luau names them except `Debug/FxBooth`'s picture list, the probe's dot list and the fallback table):
`VfxCrackB` (only in `Tex.FALLBACK` and the specs) and, in the Core set, `AuraBolt`, `AuraCrescent`, `AuraHalo`, `AuraSpecks`,
`AuraSpikeRing`, `AuraTwinkle`, `AuraWisp`, `FxPuff`, `FxTear` (`AuraGlow` is used by the UI kit and `AirFx`; `FxShard` and
`FxStatic` have one reference each). They cost nothing in the Fx file, but they ride in Core, so remove them with a later Core
bump, not for their own sake. `Tex.FALLBACK` and `STAND_IN` in `Vfx/Tex.luau` can lose the lines for names the place now has
(everything in Fx 6, which is imported) once nobody runs an older place.

Order of work when the owner says yes: (a) move `SceneDeaths/*` and `WinCinema`'s unflagged spots to `Fresh`; (b) delete the
old branches of the ON flags and `startOld`; (c) delete `FxKit`, then `Recipes`; (d) drop the old sheets nothing names, rebuild
the Fx file (one bump), update `art/budget.json` (the 8.3 megapixels the old sheets cost come back) and the plan's Log.


# Reference kept from the first version of this page

Written at the start of the shop and cosmetics overhaul (2026-10-21) from the research the brief asked for; still true.

## Sources read (2026-10-21)

- Roblox Creator Hub: Particle emitters (`/docs/effects/particle-emitters`), Beams (`/docs/effects/beams`),
  Highlighting objects (`/docs/effects/highlighting`), Post-processing effects
  (`/docs/environment/post-processing-effects`), Camera (`/docs/workspace/camera`), Using animations
  (`/docs/animation/using`), the AnimationTrack and Highlight class references, and the artist curriculum's
  beam/trail/flipbook definitions.
- DevForum threads on starting VFX (beams for fixed spans, particles for volume, meshes for shaped bursts).
- Jujutsu Shenanigans: the "Aura monster" traversal emote watched frame by frame (youtube WCS02c9lgro), robloxden's
  and bloxodes' emote lists (traversal emotes move the player, slower than a walk, while the animation is active).

## The owner's tutorials (2026-10-22/23)

The owner sent tutorials to learn from (read through their captions; the silent ones from their frames):

- goodgood3d (Blender, "the same 5 nodes for 90% of my 3D work"): stylised effects are plain shapes (a shockwave
  dome, rings, spikes) scaled over time on a curve (Scene Time -> Map Range -> Float Curve -> Transform Geometry),
  their look a noise cut into hard steps. Here: `Presentation/FxKit` grows the Core set's `FxDome`, `FxRing`,
  `FxCrescent` and `FxSpikes` on an eased curve (the Float Curve), tinted and glowing; the stepped noise is baked
  in Blender into the `FxPuff` flipbook (4 x 4, `art/scripts/textures.py`).
- MoldySugar (VFX scripting): effect templates cloned at a CFrame; emit every emitter at once, enable a lingering
  layer under the burst; a crater of rocks (`FxKit.rocks`); a camera shake; an impact light (`FxKit.light`); a
  ColorCorrection flash tinted to the effect (EmoteCinema's `flash` and `impact` beats).
- BlenderBuilder (particles): colour from dark to its hue and a size that swells mid-life; LightEmission with the
  colours darkened to match; velocity-aligned orientation and Squash for streaks; white textures, so they tint;
  Drag to gather; TimeScale for a frozen beat.
- Ludius, Disobeyedcrab (cutscenes): a camera animated with the body (our Blender shot lists), the player locked
  and kept safe while it plays, an easing chosen for each move, a roll, a lower FOV, easing back into the player's
  camera at the end. Moon Animator (two): never linear keys (quad, quart). Pidgey's showcase: beams in layers (a
  white core inside coloured shells), a swirling vortex, thick smoke, white streaks.

## The aura tutorials (2026-10-24)

The owner: "make the vfx very high quality and not just those simple particles". Three tutorials, read:

- Twist VFX, "How to Learn Roblox Aura VFX in 1 Hour" (captions): every emitter fades in and out by size or
  transparency, never pops; LightEmission 1 takes a texture's black away; LightInfluence 0; a glow held steady by
  two particles half a life apart on a V of transparency; spec textures, sparingly; off-centre textures turned as
  they go for wisps; faint ambient smoke behind; ground effects laid flat (VelocityPerpendicular, Speed 0.001, never
  0), rings growing out, a ground glow, a spiked ring; two beams spiralling up, mirrored by their curve; a lens
  flare small behind; few particles alive per emitter (the rate against the lifetime); enable everything together
  so the layers stay in step; make it in daylight, not only in the dark.
- TerKungTH, the ground aura guide (frames; it has no speech): crescent slashes spinning on the floor, stars and
  flares small with a high rate, smoke very transparent with a long life, a halo ring behind the head, light
  streaks; Top + VelocityPerpendicular for anything on the ground.
- TerKungTH, the body aura guide (frames): smoke, specs, glitter flares and lightning on the limbs (emitters in
  the body's parts, not one big box: his own "mistake" was one cloud swallowing the body).

Here: `Presentation/Aura` builds these layers by level (1: the steady glow, specks, limb flares, a light; 2: and
wisps, smoke and the ground's ripple, glow, spiked ring and spinning slashes; 3: and two spiral beams, a halo,
lightning sparks and an edge of light), from white textures baked in `art/scripts/textures.py` (`AuraGlow`,
`AuraSpecks`, `AuraTwinkle`, `AuraHalo`, `AuraCrescent`, `AuraSpikeRing`, `AuraWisp`, `AuraBolt`; carried in the
Core set). Every emote from Sealed up wears one under its own effect (`Controllers/EmoteFx`: Sealed level 1,
Condemned 2, Godhood 3, a few showpieces a level up), in its tier's colour or its own.

## The tools

| Tool | Use it for | Notes from the docs |
| --- | --- | --- |
| `ParticleEmitter` | dust, sparks, embers, petals, rain streaks, symbols that drift | Rate caps at 400/s (100/s on phones); Lifetime caps at 20 s. `LightEmission` 1 = additive glow, 0 = normal blend. `Squash` stretches a particle into a streak (rain: about 3, with `VelocityParallel`). `ZOffset` layers emitters without changing their size. Fade `Transparency` in and out or particles pop. Flipbooks (2x2, 4x4, 8x8) cap at 30 fps and are dropped on low-memory phones, so the effect must still read without them. Sphere and Cylinder shapes misbehave on Attachments: give them a Part. |
| `:Emit(n)` | bursts on a beat (impacts, a clap, a coin landing) | One emitter reused for every burst; `Rate` stays 0. |
| `Beam` | streaks between two points (a ball's flight, strings, light shafts, speed lines, slashes) | Needs two different Attachments; curve with `CurveSize0/1` along the attachments' X axes; `FaceCamera` or it vanishes edge-on; `TextureMode` Wrap/Static repeat by length, Stretch by count. Streaks that follow a moving hand are Beams between the hand and a lagging attachment, never `Trail` (see the rules). |
| `Highlight` | an outline or fill on a body or prop for a beat (a reveal, a glare) | Up to 255 on screen at once (older pages said 31); a disabled one still takes a slot. Creating or destroying one rebuilds geometry and can hitch, so keep one per effect and change its properties. The first one on screen costs up to about 1 ms on phones. |
| `PointLight` / `SpotLight` / `SurfaceLight` | the light an effect throws on the body and floor | Tween `Brightness` up and down with the beat; never leave one on. |
| Post effects (`ColorCorrectionEffect`, `BloomEffect`, `BlurEffect`, `DepthOfFieldEffect`) | grading a cutscene, a flash | Parented to the **camera** they reach one player only; parented to Lighting, everyone. Ours always go on the camera and are restored when the shot ends (`Cinema`, `EmoteCinema`). |
| `BillboardGui` | manga bubbles, symbols that must face the camera (ゴゴゴ, ドドド), floating text | `MaxDistance` so it never clutters far away; `AlwaysOnTop` off so walls hide it. |
| Parts and meshes (Neon, glass, SmoothPlastic) | shaped one-off pieces: steps forming under a foot, shards, a shockwave ring | Anchored, `CanCollide`/`CanQuery`/`CanTouch` off, `CastShadow` off; tweened in size and transparency. |
| `TweenService` | every fade and grow | `Sine`/`Quad` InOut for camera and light, `Back` Out for a pop-in (a bubble), `Exponential` Out for a flash falling away. |
