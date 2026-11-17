# VFX rework plan: every effect in the game, from cheap to made for it

Written 2026-11-16 for other agents (cheaper models included) to carry out. The owner's words: "currently anything
that uses vfx such as animations, emotes, cosmetics etc look horrible and cheap". The ask: rework all of it.

**Update 2026-11-16: Ace's verdict styles are gone** (the owner: "remove ace shop and verdict styles completely"). `Presentation/Verdicts.luau`, the verdict stills in `Styles.luau` and the `verdict` family are deleted: skip every verdict row, count and ticket below.

How to use this file. Read Parts 1 to 3 once, whole. Then take the next open ticket in the Status block, do exactly
that ticket, commit it by itself, log it at the bottom, and stop where the ticket says stop. A ticket is written so
it can be done without the conversation that produced this plan. If a ticket is unclear or a gate cannot be met,
write what you found in the Log and ask the owner; do not guess a third time.

**You must be able to look at pictures.** Every ticket from Stage 1 on ends with you opening the image you made and
judging it against a reference. A model that cannot read images must not take those tickets.

## Status (2026-11-16, the day the plan was written)

Nothing is built that changes a look. V0.3 (the texture check) is done and V0.1's code is on main but not yet played in Studio (the owner's Studio was in a play session on 2026-11-16): see the Log. The order is fixed:

| Stage | What | Tickets | Gate before the next stage |
|---|---|---|---|
| 0 | Tools and the "before" record | V0.1 to V0.5 | The booth plays every effect; before sheets exist |
| 1 | The texture and mesh library | V1.1 to V1.7 | Every new texture passes the texture check and the eye |
| 2 | The kit | V2.1 to V2.6 | Specs pass; old callers still work |
| 3 | The pilot: three effects | V3.1 to V3.3 | **The owner's verdict. Hard stop.** |
| 4 | Roll out by family | V4a to V4f | A sheet report per family; the owner's word on the first batch of each |
| 5 | Close | V5.1 | docs/vfx.md rewritten to what was built |

Stage 0 tickets V0.1, V0.3 and V0.4 touch different files and can run at the same time in separate sessions. So can
Stage 1 (Python and Blender) and Stage 2 (Luau), because the texture names are fixed in this file (Part 5).

## Decided by the owner

- **Colour (2026-11-16: "Yes, full colour").** Asked whether shop effects (emotes, cosmetics) should use full colour
  instead of the grey rule, the owner said yes. So: anything bought in the shop (emotes, Manual covers, writing
  styles, verdicts, win cutscenes, Deathsinger forms, custom deaths) wears its own colour at full strength, or its
  tier's colour when it has none of its own. Do not wash a shop effect toward grey, bone or white: only its
  white-hot core is white. World and gameplay effects (candles, haze, rain, deaths by plain causes, the Trial's
  wisp, the eyes) were not part of the question and keep `docs/vfx.md` rule 1. Each emote keeps the colour already
  chosen for it (The Long Climb green, Jackpot Shuffle green, the aura colours in `EmoteFx`'s `AURAS`); crimson as
  a *tier* colour is still Godhood's.

## Open questions for the owner (work goes on with the defaults)

1. **Where textures come from.** Default: made here, by Blender simulation and by script, nothing borrowed (the
   2026-10-24 commit: "drawn for the game, not borrowed"). Free CC0 packs or generated images only on the owner's yes.
2. **The bar.** The references on file are Ink Game's emotes and Jujutsu Shenanigans' bursts (2026-10-24). If the
   owner can name three to five exact effects they think are great, V0.4 uses those first.

## Read these first

- `docs/vfx.md`: the tools, the house rules and the owner's tutorials. Its rules stand unless this file says
  otherwise. Rules that are never broken: no ink, no `Trail` instances, never hide another player, no full-screen
  flash for anyone but the player it belongs to, nothing under Reduce motion that shakes, flashes or spins.
- `docs/emotes.md`: tiers, rungs, where an emote may play.
- `docs/agent-memory/INDEX.md`, and from it: `workflow.md`, `protect-user-assets-edits.md`,
  `owner-rejected-changes.md`, `parallel-agent-merges.md`, `windows-lf-endings.md`, `mobile-and-perf-2026-11.md`,
  `cutscene-lag-2026-11-15.md`, `win-cutscene-fx.md`, `scene-death-hits-and-blood.md`, `studio-mcp.md`,
  `studio-no-screen.md`, `imports-by-open-cloud.md`, `harness-paths-stale.md`, `studio-capture-disturbs-camera.md`.
- `docs/handoff/animation-cutscene-plan-2026-11-13.md`, Parts 2 and 3 only: this plan copies its method (measure
  first, a pilot, the owner's gate), and its "The owner's taste, in one place" list applies here too.

# Part 1: what there is

About 24,000 lines of Luau make or call effects. Everything is client-side and built in code from one kit; nothing
is authored in Studio.

**The kit**

| Piece | Where | Notes |
|---|---|---|
| VFX kit | `src/client/Presentation/Vfx/` (12 modules, about 2,500 lines) | `Emit` (particles from plain specs), `Shape` (meshes grown and faded), `Beams`, `Light`, `Screen` (shake, flash, lens punch), `Ground` (marks, debris), `Rim`, `Clock` (one clock, can be held for pictures), `Ease`, `Tex` (texture ids by name), `Recipes` (impact, slam, twinkle, pillar, flame, dissolve) |
| Older layer | `Presentation/FxKit.luau` (199) | A thin layer over the kit; called by `EmoteFx`, `WinCinema`, `UI/Shop/Card` |
| Aura | `Presentation/Aura.luau` (575) | Three levels, worn by 13 emote clips |
| For 3D views | `Presentation/ViewFx.luau` (223) | Kit textures drawn as images over a ViewportFrame (shop cards) |
| Textures | `art/scripts/vfx/textures.py`, `volumes.py`; out to `art/export/textures/` | 23 `Vfx*`, 8 `Aura*`, 5 `Fx*`, `Spark`, `Snowflake`. Carried into the place by the Fx props file (`ModelsFx` version 3) as quads named `Tex_<name>` |
| Meshes | `art/scripts/vfx/meshes.py`, `art/scripts/props_fx.py` | 11 `Vfx*` shapes, 4 `Fx*` shapes |

**What uses it**

| Family | Where | Size |
|---|---|---|
| Emotes | `src/client/Controllers/EmoteFx.luau` | 4,231 lines in one file, 84 effect entries |
| Deaths | `Presentation/DeathFx.luau`, `DeathVfx.luau`, `CustomDeaths.luau`, `Fallen.luau`, `SceneDeaths/` (15 scenes plus `Splat`, `Sets`, `Cast`) | about 10,500 lines |
| Cutscenes | `Presentation/ShotPlayer.luau` ("fx" events of the Blender shots), `WinCinema.luau` (the "fx" act of the 8 win cuts), `Verdicts.luau` (6, rebuilt 2026-11-16), `Presenters/EyesDeal.luau`, `BookStage.luau`, `Materialize.luau` | |
| Cosmetics | `Presentation/Styles.luau` (1,941: writing 6, verdict stills 6, death styles, Deathsinger forms 6), `World/CoverTells.luau` (Manual covers 7), `World/GhostVisibility.luau` | Shop kinds with an effect: emote 59, reason 15, grimoire 7, writing 6, verdict 6, win 6, specter 6 |
| Gameplay moments | `World/EyeGlow.luau`, `UI/WorldFx.luau` (the Manual's red fire), `UI/HauntBar.luau`, `Controllers/DiveController.luau`, `Onboarding/TrialWisp.luau`, `Specter/GhostController.luau` | |
| World, always on | `World/Flames.luau`, `ReadyCircle.luau`, `AirFx.luau`, `LampHaze.luau`, `RainController.luau`, `MapAmbient.luau` | Seen every second of play |

`grep -rlE "Vfx\.|FxKit|Aura\." src --include=*.luau` gives the full list of callers; V0.1 turns it into a catalogue.

# Part 2: why it looks cheap

What was checked on 2026-11-16, and how. **Nothing was watched in the game for this plan** (Studio was in the
owner's own play session); V0.2 does the watching and may add to this list.

**Ruled out: missing imports.** `Vfx/Tex.luau` falls back to Roblox's stock sparkle when the Fx file is not
imported. A read-only look at the running place showed the real textures are there (121 carrier quads, every
`Vfx*` name resolves). So the cheap look is the art and how it is used, not a stand-in. One loose end: `Tex_FxPuff`
did not resolve; V0.2 checks whether anything still asks for it.

**1. The textures are maths, not drawings or simulations.** All of them are drawn by numpy formulas. Rendered over
the dark realm with `art/scripts/vfx/preview.py`: the impact burst is a clip-art star, the flare is a four-point
star with a circle round it, the flame is a flat teardrop, the smoke is a soft ball.

**2. The subject fills a fraction of its cell.** Measured (box round alpha over 0.1, share of the cell; and the
spread of brightness inside the shape, where flat is near 0):

| Texture | Cell | Subject fills | Tone spread | Read as |
|---|---|---|---|---|
| VfxSmoke | 128 px | 19% (29% at most) | 0.044 | a 55 px grey ball stretched over a 4 stud particle |
| VfxWisp | 128 px | 6% | 0.059 | almost nothing |
| VfxCandleFlame | 128 px | 20% | 0.18 | a 50 px flame |
| VfxDust | 128 px | 24% | 0.20 | |
| VfxAsh | 64 px | 18% | 0.19 | |
| VfxFlame | 128 px | 39% | 0.27 | |
| VfxCrack | 1024 px | 50% | 0.005 | a one-tone line drawing |

Blurry, flat and small is most of what "cheap" means in a particle.

**3. Nearly everything is built from the same few dots.** Counting `tex = "..."` in `src` (374 uses): VfxGlow 52,
VfxEmber 50, VfxFlare 46, VfxSmoke 43, VfxDust 32, VfxStreak 30. Those six are 68% of all uses; the three plain
dots (glow, ember, flare) are 40%. The shaped textures (burst, slash, spike, crack, page, circle, feather, moth) are
20 uses together, 5%. In the running place 254 of 476 live emitters and beams wore VfxGlow. So every effect is the
same soft dot in another colour, which is exactly what `docs/vfx.md` rule 5 forbids.

**4. Nothing erodes.** Every particle leaves by fading its transparency. Good stylised effects leave by breaking
up: the shape is eaten away from its edges by noise. Roblox particles cannot do that in a shader, so it has to be
drawn into the flipbook's frames. No texture here does it; the flipbooks only wobble.

**5. Effects were written as numbers and never looked at as pictures.** There is a motion report, a spacing strip
and a silhouette check for animation. For effects there is nothing: no stage to play one effect alone, no sheet of
its moments, no reference frames to hold it against. `Clock.hold` exists for pictures and no tool uses it.

**6. One file of 4,231 lines.** `EmoteFx.luau` cannot be held in a cheaper model's head, so edits there are local
patches on patches.

**7. Things to confirm by eye in V0.2** (likely, not measured): additive-only effects vanish against lit walls and
daylight because they have no dark layer behind them; cores do not bloom (the place's bloom threshold was 1.8, so
only a `bright` of about 2 or more glows); Neon shapes with no texture read as plastic; effects that pop in or cut
off; effects too small to read from the follow camera at 18 studs.

# Part 3: the bar

An effect is good when all of these are true. This list is the review checklist for every ticket in Stages 3 and 4.

1. **It has five moments**, each on purpose: *gather* (0.1 to 0.3 s before the hit: something drawn in, a dimming,
   a glint), *hit* (1 to 2 frames: the biggest and brightest it ever is), *body* (the shape of the idea: the
   flame, the slash, the ring), *break-up* (it erodes; it does not just fade), *residue* (1 to 3 s of something
   left: drifting ash, a scorch, a last ember, thin smoke). A loop (an aura, a flame) has an ignition, a steady
   state that never repeats visibly, and an ending.
2. **It has a shape of its own.** The main layer is a shaped texture or a mesh, never VfxGlow, VfxEmber or
   VfxFlare. Those three are support only: a halo behind, specks round, a glint on top.
3. **It has three values.** A white-hot core, a body in the effect's colour, a darker edge or a dark layer behind.
   The dark layer is laid over, not added (`light = 0`), so the effect still reads in a lit room.
4. **The core glows and the body does not.** Core `bright` 2 or more so bloom catches it; body under 1.2. Skin
   never glows (the owner's bloom rule).
5. **It lights the scene.** A light on the beat, falling off 2 to 4 times slower than it rose. No shadows from it.
6. **It moves like the thing it is.** Smoke rises and slows, sparks fall, dust rolls along the floor, embers
   wander. Speeds are uneven. Nothing travels at a steady rate.
7. **It lands on the body's beat** (`docs/vfx.md` rule 4) and is sized to read from the default follow camera.
8. **It is one idea** from the game's own world: paper and pages, ash, candle flame and smoke, feathers and crows,
   chalk, glass, stone, the apple, chains, cold light. Never ink.
9. **It costs what its tier allows** (Part 9), plays at the phone share and on Low graphics without falling apart,
   and is gone when its owner is gone.

# Part 4: Stage 0, tools and the "before" record

Build these first. They change no look. One commit each.

## V0.1 The catalogue and the booth

**Goal:** play any one effect, alone, by name, anywhere, and hold it at chosen moments.

- New `src/client/Presentation/Vfx/Catalog.luau`: a list of entries `{ id, family, source, tier, hit, length,
  play }`. `play(stage)` starts the effect on the stage's dummy (an R6 body the stage gives, with `stage.floor` and
  `stage.body`) and returns a stop function. `hit` is the second its main beat lands; `length` the seconds to watch.
  Families: `recipe`, `aura`, `emote`, `death`, `scenedeath`, `win`, `verdict`, `writing`, `cover`, `form`,
  `moment`, `world`.
- Fill it without copying effect code: call what the game calls. Recipes directly; `Aura.start` at levels 1 to 3;
  every emote through `EmoteFx.play(body, clip, true)` (add `EmoteFx.clips()` returning the names in `FX`); deaths
  through the same calls `Presenters/Death` makes; cosmetics through `Styles` and `CoverTells`. Scene deaths, win
  cuts and verdicts are whole scenes: list them with `play` calling the gallery (`WinCinema.preview`), not rebuilt.
- New `src/client/Debug/FxBooth.luau` and an "Effects" tab in `Debug/DebugPanel.luau`, beside the cutscene gallery
  (`docs/agent-memory/debug-cutscene-gallery.md`): a far-off cell like the scene deaths' (`World/Away` already
  parks the crowd and rain when the camera is 900 studs out), a mid-grey floor and back wall, a dummy, and three
  switches: backdrop `dark` / `lit` (a bright room: light walls, full ambient), camera `follow` (18 studs back,
  as a player sees an emote) / `close`, and `hold`. Buttons: one per catalogue entry grouped by family, Play, Stop.
  Harness hooks like the gallery's: `FxBooth.list()`, `FxBooth.play(id, opts)`, `FxBooth.stop()`,
  `FxBooth.at(id, seconds)` (plays and holds the kit's clock at that second after `hit`).
- A spec `src/server/Tests/VfxCatalog.spec.luau` (data only): ids unique; every emote clip with an effect has an
  entry; every family is one of the list.

**Done when:** every entry plays in the booth in a Studio play test with no error in the output, and Stop leaves
nothing in `Camera.DGVfx`. Specs pass.

## V0.2 The before sheets and the watched list

**Goal:** a picture record of every effect as it is today, and a list of faults seen by eye.

- A harness probe `FxPics` (copy `docs/handoff/harness/DeathPics.server.luau` and `DeathPicsClient.client.luau`;
  fix the paths first as `docs/agent-memory/harness-paths-stale.md` says). For each catalogue entry, on both
  backdrops from the follow camera: `FxBooth.at(id, t)` for t = -0.15, 0, 0.05, 0.15, 0.4, 1.0, 2.0 after the hit,
  one picture each (`CaptureService`), labelled `<id> <backdrop> <t>`. Run with workspace attribute `DGVfxLocal`
  so the real textures draw from the content folder.
- Sheets with `docs/handoff/harness/pics_sheet.py` (its `sys.path` line points at another machine: fix it): one row
  per effect and backdrop, seven frames across. Out to `art/export/previews/vfx/before/` (gitignored; keep them on
  disk, do not commit).
- Open every sheet. For each effect write one line in `docs/handoff/vfx-audit-2026-11.md`: id, what it is meant to
  be, and which of the nine points of Part 3 it misses. Mark the worst twenty. Answer the open items of Part 2
  point 7 with what you saw.
- If the harness cannot run (it needs a second Studio; never start it while the owner's Studio is in a play
  session, it crashed their Studio once), use the Studio MCP in the owner's place once it is out of Play: play
  through `FxBooth`, capture with `screen_capture` (Studio must be in front; ask for the screen first; take
  pictures and log numbers in separate runs).

**Done when:** the audit file lists every catalogue id with a verdict, and the sheets exist. Commit the audit file.

## V0.3 The texture check

**Goal:** a number for "small, flat, blurry", so a new texture cannot be worse than the bar.

- New `art/scripts/vfx/check_textures.py` (numpy only, run with Blender's Python, writes nothing). Per texture,
  per flipbook cell, print and judge:
  - **fill**: the box round alpha over 0.1 as a share of the cell. Fail under 55% for flipbooks and round
    subjects (halos and specks are exempt by a list at the top of the script).
  - **edge**: any alpha over 0.02 within 3 px of a cell's edge fails (frames bleed into each other when blended).
  - **tone**: the spread of brightness inside alpha over 0.5. Fail under 0.12 (a flat fill).
  - **motion**: mean change between neighbouring frames. Fail under 0.01 (a flipbook that does not move). For a
    loop, the last frame to the first must be no bigger a step than the average.
  - **erosion** (sheets marked one-shot): alpha coverage must fall by more than half over the last third of the
    frames, and the count of separate islands must rise (it breaks up; it does not only fade).
  - **size**: sheets are 1024 x 1024; 8 x 8 gives 128 px cells, 4 x 4 gives 256 px.
- Calibrate as the motion report was: today's VfxSmoke (fill 19%, tone 0.044), VfxWisp (6%), VfxCandleFlame (20%)
  and VfxCrack (tone 0.005) must fail. Print the before table into this file under this ticket.
- `--selftest` with made-up arrays of known answers.

**Done when:** the script runs over `art/export/textures/Vfx*.png`, those four fail, the self-test passes.

## V0.4 The reference boards

**Goal:** something real to hold each family against. No effect is designed from imagination.

- For each of these families find two or three clips and take frame sheets with the browser method in
  `docs/agent-memory/youtube-reference-hunting.md`: hit and slam, slash, aura (idle and ignition), fire and candle,
  smoke and dust, lightning, dissolve to ash, a pillar of light, glints and sparkles, magic circle on the floor,
  paper and feathers in the air. Sources: the owner's named games first (Ink Game emotes, Jujutsu Shenanigans),
  then anime impact frames, then real footage for smoke and fire.
- Write `art/refs/vfx/<family>.toml`: source link, times watched, and for each of the five moments what is on
  screen in words: shapes, how many layers, which is brightest, colours, how long each moment lasts in frames, how
  it leaves. Eight or more lines per family. Save the sheets beside it.
- Do not copy a named game's effect one for one. Take the structure (moments, layers, timing), not the drawing.

**Done when:** eleven `.toml` files exist with their sheets. Commit them.

## V0.5 The effect report

**Goal:** the bar of Part 3 as numbers, read from the kit itself while an effect plays in the booth.

- New `src/client/Presentation/Vfx/Probe.luau`: off by default. When on, `Emit.make`, `Emit.burst`, `Beams.make`,
  `Shape.grow`, `Light.flash` and `Screen.*` each record `{ t, kind, tex, count, size, life, bright, light }` (one
  line of code in each; no cost when off).
- `FxBooth.report(id)` plays the effect with the probe on and prints one line, `PASS` or `FAIL` with reasons:
  - **dots**: share of layers whose texture is VfxGlow, VfxEmber, VfxFlare or their Aura twins. Fail over half,
    or when no layer has a shaped texture or mesh.
  - **moments**: something starts before `hit` (gather); the largest and brightest layer starts within 0.05 s of
    `hit`; something is still alive 1.0 s after `hit` (residue). Loops: an ignition burst and at least four layers.
  - **pops**: a particle that lives over 0.6 s and is born over half opaque at more than a third of its size; or
    one that dies under 90% transparent without shrinking to nothing.
  - **values**: at least one layer with `light` under 0.5 (the dark layer) for effects over 3 studs across; at
    least one with `bright` 2 or more (the core).
  - **light**: a light on the beat for tier `sealed` and up.
  - **cost**: peak particles alive (count, or rate times life) and peak big sprites (size 8 studs or more).
    Against Part 9's budgets.
- Run it over the whole catalogue and paste the table into the audit file.

**Done when:** the table exists. The report is a floor, not a judge: passing it does not make an effect good.

# Part 5: Stage 1, the library

The biggest single lever: every effect in the game draws from these. Names are fixed here so Stage 2 can be written
at the same time. Old names stay in the files until Stage 4 has moved every caller off them.

**Rules for every texture**

- White and grey so the game tints it, with real value: bright core, mid body, darker edge. Two kinds: *light*
  (added, black is nothing) and *matter* (laid over: smoke, dust, ash, paper; lit from above, shadowed below).
- The subject fills 80% of its cell at its largest, with 4 px clear at every edge.
- Organic, never symmetric: uneven rays, broken edges, no perfect circles.
- One-shot sheets are a whole life: born, full by a fifth of the frames, eroding from the half, islands at the end.
- Loops close: the last frame runs into the first.
- Flipbooks may be switched off on weak phones. Frame 1 of every sheet must read as the thing by itself.
- Pass `check_textures.py`, then be looked at with `preview.py` over dark and over light, tinted in two colours.
- Before choosing sizes read the current Creator Hub particle page: on 2026-11-16 it says flipbook layouts are
  2x2, 4x4, 8x8 or custom, at most 30 frames a second, with space between frames, example sheet 1024 x 1024.

**Two ways to make them**

- **Route S, simulated** (smoke, dust, fire): a Blender gas simulation baked and rendered to frames, then packed
  with `vfx/draw.py`. Start from `art/scripts/vfx/volumes.py` (it renders a made-up volume in Cycles; it does not
  simulate). Read the fluid chapter of the Blender manual first (`blender -b`, the manual bundled with the Blender
  MCP, or docs.blender.org for 5.2); a headless bake needs the domain's cache set to a folder in the scratchpad.
  Light from above and one side, film transparent, the camera square on. If a bake will not run headless after two
  tries, fall back to the volume route with noise that is carried upward and stretched over the frames, and say so
  in the Log.
- **Route E, eroded** (slashes, bursts, rings, arcs, stylised flame): in numpy with `vfx/noise.py`. A shape mask,
  times layered noise, cut by a threshold that rises frame by frame so the shape is eaten from its thin parts
  first; a gradient inside for the three values. This is the "noise cut into hard steps" of the owner's first
  tutorial, animated.

**The textures** (one ticket per group; sheet sizes may change if the texture check asks)

| Ticket | Name | Kind | Sheet | Route | What it is |
|---|---|---|---|---|---|
| V1.1 | VfxSmokePuff | matter | 8x8 one-shot | S | a billow from a point, lit top, dark belly, thinning to wisps |
| V1.1 | VfxSmokePlume | matter | 8x8 loop | S | a column rising |
| V1.1 | VfxDustRoll | matter | 8x8 one-shot | S | dust rolling along the floor from a hit, seen from the side |
| V1.1 | VfxMist | matter | 4x4 loop | S | a slow bank of fog (lamp haze, hems, the realm) |
| V1.2 | VfxFire | light | 8x8 loop | S | fire whose tongues tear off and climb |
| V1.2 | VfxFireBurst | light | 8x8 one-shot | S | a ball of fire opening and turning to smoke |
| V1.2 | VfxCandle | light | 8x8 loop | E | the realm's pale candle flame with a dark heart at the wick and a bright body |
| V1.2 | VfxAuraFlame | light | 4x4 loop | E | a drawn anime flame tongue for auras |
| V1.3 | VfxImpactA, B, C | light | 4x4 one-shot | E | three impact bursts: sharp, heavy, soft; rays that break into shards |
| V1.3 | VfxShock | light | 4x4 one-shot | E | a shock ring whose band thins and breaks |
| V1.3 | VfxGlint | light | 4x4 one-shot | E | a star that opens, turns and closes (no circle round it) |
| V1.3 | VfxSparks | light | 2x2 random | E | four spark streaks: straight, bent, forked, short |
| V1.4 | VfxSlashA, B | light | 4x4 one-shot | E | a slash arc that sweeps along its curve and tears away behind |
| V1.4 | VfxArc | light | 4x4 random | E | sixteen lightning arcs with branches, for beams and sparks |
| V1.4 | VfxEnergyWisp | light | 4x4 loop | E | a curling wisp of light |
| V1.5 | VfxAshFlakes | matter | 4x4 loop | E | tumbling flakes with a lit side (remake of VfxAsh at 256 px cells) |
| V1.5 | VfxShards | matter | 4x4 random | E | chunks of stone and glass with shaded faces |
| V1.5 | VfxPaper | matter | 4x4 loop | E | a page tumbling, both sides, written lines on one |
| V1.5 | VfxFeatherTumble | matter | 4x4 loop | E | a black feather turning |
| V1.6 | VfxCrackA, B | matter | single 1024 | E | floor cracks with depth: dark groove, lit lip |
| V1.6 | VfxScorch | matter | single 1024 | E | a burn mark, soft outside, hard inside |
| V1.6 | VfxSigil | light | single 1024 | E | the floor circle (remake of VfxCircle) with uneven hand-drawn line weight |

VfxGlow, VfxEmber and VfxStreak stay as they are: they are support.

**V1.7 Meshes and the import.**
- In `art/scripts/vfx/meshes.py` give every shape UVs made for a texture that flows when the mesh turns: `u` round
  the shape, `v` along its height. Add `VfxSlashArc` (a curved blade, `v` across the blade), `VfxTwister` (a
  tapering spiral shell) and `VfxShell` (a full sphere shell with the pole hidden).
- One Studio test, written down in the Log: does a `SurfaceAppearance` with `AlphaMode` Transparency on a kit mesh
  fade with the part's `Transparency`, tint with `SurfaceAppearance.Color` from a script, and glow with
  `EmissiveStrength` / `EmissiveTint` (new properties listed on the Creator Hub class page on 2026-11-16)? If yes,
  textured glowing meshes replace Neon everywhere in Stage 2. If no, meshes stay Neon and are used less.
- Bump the Fx props file (`ModelsFx` 3 to 4) only once, at the end of Stage 1, with every new texture and mesh in
  it. The export rewrites binaries (`docs/agent-memory/export-restores-binaries.md`). Until the owner's place has
  version 4, the booth and harness read the PNGs from the content folder (`DGVfxLocal`), so no upload is needed to
  work. `Vfx/Tex.luau`'s `STAND_IN` gets an old-name fallback for each new name so the live place never shows a
  sparkle while it waits for the import.

**Done when (each of V1.1 to V1.6):** the texture check passes, the preview picture is in the Log entry's notes,
and you have compared it by eye with the family's reference sheet and written two lines on how it differs.

# Part 6: Stage 2, the kit

Luau only. Old function names keep working until Stage 4 has moved their callers.

- **V2.1 Split EmoteFx.** `Controllers/EmoteFx.luau` becomes `Controllers/EmoteFx/init.luau` plus one module per
  family (`Shared`, `Poses`, `Dances`, `Props`, `Strolls`, `Duos`, `Everyone`), none over about 700 lines. No
  behaviour change: the list from `EmoteFx.clips()` is the same before and after, specs pass, the booth plays all
  84. Fetch and merge first, do it in one sitting and push at once: other agents edit this file.
- **V2.2 Flipbook lives.** In `Emit`: add every new sheet to `SHEETS` with its grid and mode; a one-shot sheet
  sets its frame rate from the particle's life so the last frame lands at its death; `variants = true` picks a
  random cell and holds it (for the 2x2 and 4x4 random sheets).
- **V2.3 The envelope.** New `Vfx/Moment.luau`: `Moment.play(at, { gather = fn, hit = fn, body = fn, residue = fn,
  lead = 0.2 })` runs the parts on the kit's clock around one hit time, so every recipe has the five moments by
  construction and the probe can see them.
- **V2.4 Ramps.** `Emit` specs take `ramp = { core, body, edge }` (three colours) in place of `color`, expanded to
  a ColorSequence white-hot at birth, body through the middle, edge at death; and `Vfx/Palette.luau` holds the
  ramps: one per rarity tier (`src/shared/Rarity.luau`), the world's greys, danger red, and each emote's own.
  Shop ramps are full colour (the owner, 2026-11-16): the body is the item's colour at full saturation and the
  edge is a darker, deeper shade of the same hue, never a grey.
- **V2.5 Recipes, remade and added** in `Vfx/Recipes.luau` (split it by family if it passes 800 lines). Each built
  on `Moment`, each with a dark layer, each from the new textures, each against its reference file:
  `impact` (styles `sharp`, `heavy`, `soft`), `slam`, `slash`, `glint` (replaces `twinkle`), `pillar`, `flame`,
  `fireBurst`, `smokePuff`, `dustKick`, `dissolve`, `arc` (lightning between two points), `charge` (a gather that
  holds and can be released), `sigil` (a floor circle drawn in, held, burnt out), `scatter` (paper, feathers or
  shards thrown and settling), `mist`.
- **V2.6 Shapes.** `Shape.grow` wears textures by default once V1.7's test says how; `FxKit` becomes calls to the
  recipes and is deleted when its three callers are moved.

**Done when:** specs pass (`rojo build`, the spec run the repo uses), stylua and selene clean on changed files
only, the booth plays the old and new recipes side by side, and each new recipe passes the effect report.

# Part 7: Stage 3, the pilot

Three effects, one from each thing the owner named, taken through the whole loop of Part 8.

- **V3.1 The hit:** `Recipes.impact` and `Recipes.slam` as a death uses them (the burst of `DeathFx`). It is under
  almost everything, so it lifts the most at once.
- **V3.2 An emote:** Menacing Pose with its aura (`Aura` level 2 and the emote's own effect).
- **V3.3 A cosmetic:** the highest-rarity Manual cover's tell in `World/CoverTells.luau`.

For each: the before sheet, the after sheet from the same booth and camera, the reference sheet, the effect
report's line before and after.

**Then stop.** Report to the owner (the template in Part 9) and say what is needed to see it in the game: a script
sync, and the Fx file version 4 imported (`docs/agent-memory/imports-by-open-cloud.md`; share every upload with
universe 10767766818). If the owner does not call it clearly better, ask what still reads as cheap, change Parts 3
to 6 of this file to answer it, and redo the pilot. Do not start Stage 4 on a "meh". After two turn-downs, stop and
ask what is wrong instead of guessing a third time.

# Part 8: Stage 4, the roll-out

## The loop for one effect

1. **Before.** Its sheet from V0.2, its audit line, its effect report line.
2. **Say it.** One sentence: what this effect is, and which motif of Part 3 point 8 it uses. If two effects in the
   same family would get the same sentence, one of them needs a new idea.
3. **Reference.** Open the family's `.toml` and sheet. Write the five moments for this effect with times, as five
   lines in a comment above its code.
4. **Build.** From recipes and new textures. Main layer shaped. Dark layer behind. Core bright. Light on the beat.
   Residue. Timed from the clip's beat (`accent`, `onBeats`), never from a guess.
5. **After.** The booth sheet on both backdrops. Put before, after and reference side by side and look. Fix what
   is weaker than the reference. Then the effect report: it must pass.
6. **In place.** Watch it once where it really plays (the lobby, a case, the cutscene), from the player's own
   camera, at full speed. Check: lands on the beat, not inside the floor or a wall, does not cover a neighbour's
   face, gone when the emote is cancelled halfway.
7. **Both ends.** Low graphics and the phone share (`DGForceDevice=phone`): it still reads. Reduce motion: no
   shake, flash or spin.
8. **Log it.**

One family, one commit per batch of at most six effects, each batch with its sheets named in the Log. After the
**first batch of each family**, show the owner and wait for their word; later batches of that family go on without
a stop unless the owner said otherwise.

## The order

**V4a. The shared pieces.** The rest of the recipes' callers that are not in a family below, `Aura` levels 1 and
3, `Materialize`, `ViewFx` (shop cards draw the same textures as images: move it to the new names).

**V4b. Emotes** (`Controllers/EmoteFx/`), 84 entries. Order: the four Godhood emotes and the power poses, then
Condemned, Sealed, Penned; within a tier, the audit's worst first. Scrawl emotes get nothing new (their tier is
"the motion alone"). Keep each emote's own idea and colour as `docs/emotes.md` and the code's dated comments give
them (The Long Climb is green; Jackpot Shuffle is green luck, never flames; the aura only on emotes about power).
Rungs stay: a higher tier gets more layers, not more of the same particle.

**V4c. Cosmetics.** Manual covers (`CoverTells`, 7), writing styles (`Styles`, 6), verdicts (`Verdicts`, 6:
rebuilt 2026-11-16, so only move them to the new textures and recipes, change no staging), Deathsinger forms
(`Styles` and `GhostVisibility`, 6: retired from sale, still owned and worn), the win cuts' "fx" act kinds
(`WinCinema.ACTS.fx`: impact, glint, pillar, wave, bolt, light, sparks, bloom, ring, dust, embers, motes, ash,
drizzle; the data in `WinCuts.luau` does not change).

**V4d. Deaths and gameplay moments.** `DeathFx`, `DeathVfx`, `CustomDeaths`; `EyeGlow`; the Manual's red fire
(`UI/WorldFx`); `HauntBar`; the dive's crash; `TrialWisp`; `EyesDeal`. Deaths keep the rating: no gore.

**V4e. The world.** Candles and braziers (`Flames`, `ReadyCircle`: move to VfxCandle and VfxFire), `LampHaze` and
`AirFx` (move to VfxMist), rain, `MapAmbient`'s particles. These are seen all the time, so they must be the
cheapest: measure frames before and after in a full lobby. Do not change any lamp, brightness or shadow: the
lighting rework's decisions stand (`docs/agent-memory/lighting-rework-2026-11.md`).

**V4f. Scenes.** The 15 scene deaths, the Blender shots' "fx" events (`ShotPlayer`), the win cutscenes. They get
the new look from the kit without being touched. Then one pass each: play it, and replace only effects that still
read as weak. Scene deaths copy their source one for one (the owner's rule): put the source frame beside ours for
each effect beat. Change no timing, camera or acting here. RoleMuerto is never changed.

# Part 9: working rules

**Budgets** (starting numbers; V0.5 measures, V4e's frame check may tighten them):

| Tier of effect | Particles alive at peak | Sprites of 8 studs or more alive | Emitters | Lights |
|---|---|---|---|---|
| World loop (a candle, haze) | 12 | 1 | 4 | 0 (the prop has the lamp) |
| Accent (Penned, a step, a glint) | 60 | 2 | 6 | 1 |
| Showpiece (Sealed, Condemned, a death) | 250 | 6 | 12 | 2 |
| Scene (Godhood, a scene death, a win) | 600 | 10 | 20 | 3 |

Every rate and burst already passes through `Emit.share()` (60% on touch, 40% on Low or under pressure). Design at
100% and check at 40%. Loops keep under 40 particles a second per emitter. Lights never cast shadows. Reuse
textures: a new texture costs memory on every phone.

**Files and commits**

- Never stage, format or check out `src/shared/Assets.luau` or `art/rig`. Add your own files by name; other agents
  have work in the tree.
- Other agents push to main all day. Before every commit check for `MERGE_HEAD`; fetch and merge before every push;
  rebuild binaries after a merge that touched them.
- Python on this machine writes CRLF unless told: `newline="\n"`. Stylua and selene only on files you changed.
  Never stylua generated data.
- One ticket, one commit. The commit message says what changed in plain words and what the owner needs to do to
  see it (a script sync, or an import with the file and version).
- UI text you add (the booth's buttons) follows `docs/agent-memory/ui-text-style.md`. No emojis anywhere.
- Never edit the live Team Create place by hand. Look and play-test through the Studio MCP; ask before taking the
  owner's screen; never start the harness while the owner's Studio is in a play session.
- Sound: an effect that needs a new sound gets a line in your report for the owner. Do not touch the ids.

**Stop and ask** when: an effect's idea or colour would change from what the owner set; something the owner removed
would come back (`owner-rejected-changes.md`); a new mesh or texture would need a second Fx version bump; an effect
cannot meet its budget and still look right; a scene's timing or camera would have to change; the pilot or a first
batch was turned down twice.

**A thing that is not better does not ship.** If the after sheet is not clearly better than the before, keep the
old effect and say so in the Log.

**The report after the pilot and after each first batch**, in plain words for the owner:

- What was changed, as a list of effects, each with its one sentence.
- Where the before and after sheets are, and the reference used with its link.
- The effect report's line before and after.
- What is needed to see it in the game.
- Sounds wanted.
- What was checked and what was not seen (say plainly if it was only seen in the booth).

Then add what you learned to `docs/agent-memory/` (one fact per file, a line in INDEX.md) and log below.

## V5.1 Close

Rewrite `docs/vfx.md` to describe what was built (the tools table, the texture list, the recipes, the loop, the
budgets), delete the old textures and their builders that no caller uses, and delete `FxKit`. Update the "Effects"
section of `docs/emotes.md`.

# Log

(Each finished ticket: date, ticket, what was done, numbers before and after, what was not seen, the owner's
verdict where there was a gate.)

- 2026-11-16, the plan written. Checked that day: the place has the real Fx textures (no stand-ins), the texture
  measurements of Part 2, the usage counts of Part 2. Not done: no effect was watched in the game.
- 2026-11-16, the owner's answer on colour: "Yes, full colour" for shop effects (see "Decided by the owner").
  `docs/vfx.md` rule 1 amended to match.
- 2026-11-16, V0.3 the texture check (a tool: nothing to sync or import). `art/scripts/vfx/check_textures.py`, run with
  Blender's Python: `check_textures.py [--calibrate] [--detail] [--table] [--selftest]`. It reads `Vfx*.png` from
  `art/export/textures` (or the main checkout's folder), judges each by the grid and mode declared in a table at the
  top (today's textures from `Vfx/Emit.luau` SHEETS and `textures.py`, plan Part 5's new names too) and writes nothing.
  The five checks are the ticket's. Choices where the ticket was open: fill is judged on the largest cell (a
  one-shot is born small); tone on the median over cells with 24 or more solid pixels, as the standard deviation of
  the mean of r, g, b; motion is the mean over the whole cell of (|alpha change| + |premultiplied brightness change|)
  / 2, and a loop's wrap may be up to 1.5 x the average step (a good smooth loop's wrap is the average give or take
  noise, so "no bigger than the average" would fail half of them); islands are 8-connected and over 5 px, and a
  one-shot must have more of them in the last third than in its fullest frame. Beam bands, halos, specks and
  whole-frame singles (page, feather, slash, spike) are exempt from the checks that do not apply to them, by name in
  the table. Calibration: VfxSmoke (largest cell 29%, mean 19%), VfxWisp (17%, mean 5%) and VfxCandleFlame (21%, mean
  20%) fail fill, VfxCrack fails tone (0.000), as the ticket asks (`--calibrate` checks it). The tone numbers in
  Part 2 (Smoke 0.044, Wisp 0.059, Candle 0.18, Crack 0.005) could not be reproduced by any variant tried (std of the
  mean, 709 or max brightness, alpha over 0.1 or 0.5, per cell or pooled): this script gets 0.013, 0.000, 0.059 and
  0.000; every fill figure in Part 2 matches. The "before" table, 2026-11-16, 23 textures, 7 pass, 16 fail (size on
  legacy sheets is judged against the new 1024 x 1024 rule, so Ash, Chunk, Dust, Moth and Wisp fail it by design):

  | texture | kind | size | fill max (mean) | edge cells | tone | motion | erosion | verdict |
  |---|---|---|---|---|---|---|---|---|
  | VfxAsh | 4x4 loop | 256x256 | 24% (18%) | 0/16 | 0.211 | 0.027 wrap 0.017 | - | FAIL <- size, fill |
  | VfxBurst | single | 1024x1024 | 72% (72%) | 0/1 | 0.167 | - | - | PASS |
  | VfxCandleFlame | 8x8 loop | 1024x1024 | 21% (20%) | 3/64 | 0.059 | 0.001 | - | FAIL <- fill, edge, tone, motion |
  | VfxChunk | 2x2 random | 256x256 | 49% (41%) | 0/4 | 0.148 | - | - | FAIL <- size, fill |
  | VfxCircle | single | 1024x1024 | 96% (96%) | 0/1 | 0.025 | - | - | FAIL <- tone |
  | VfxColumn | single | 256x256 | - | - | 0.092 | - | - | FAIL <- tone |
  | VfxCrack | single | 1024x1024 | 50% (50%) | 0/1 | 0.000 | - | - | FAIL <- fill, tone |
  | VfxDust | 4x4 oneshot | 512x512 | 31% (24%) | 0/16 | 0.198 | 0.014 | cov 20%>15% isl 1>1 | FAIL <- size, fill, erosion |
  | VfxEmber | single | 128x128 | - | 0/1 | - | - | - | PASS (exempt: fill, tone) |
  | VfxFeather | single | 128x256 | - | - | 0.110 | - | - | FAIL <- tone |
  | VfxFlame | 8x8 loop | 1024x1024 | 49% (39%) | 46/64 | 0.257 | 0.008 | - | FAIL <- fill, edge, motion |
  | VfxFlare | single | 512x512 | - | 0/1 | - | - | - | PASS (exempt: fill, tone) |
  | VfxGlow | single | 256x256 | - | 0/1 | - | - | - | PASS (exempt: fill, tone) |
  | VfxMoth | 2x2 loop | 256x256 | 50% (33%) | 0/4 | 0.086 | 0.110 wrap 0.114 | - | FAIL <- size, fill, tone |
  | VfxPage | single | 256x356 | - | - | 0.102 | - | - | FAIL <- tone |
  | VfxRing | single | 512x512 | 82% (82%) | 0/1 | 0.034 | - | - | FAIL <- tone |
  | VfxRingBand | single | 128x1024 | - | - | 0.097 | - | - | FAIL <- tone |
  | VfxSlash | single | 512x256 | - | - | 0.111 | - | - | FAIL <- tone |
  | VfxSlashBand | single | 128x1024 | - | - | 0.151 | - | - | PASS (exempt: fill, edge) |
  | VfxSmoke | 8x8 oneshot | 1024x1024 | 29% (19%) | 0/64 | 0.013 | 0.003 | cov 19%>3% isl 1>2 | FAIL <- fill, tone, motion |
  | VfxSpike | single | 128x512 | - | - | 0.154 | - | - | PASS (exempt: fill, edge) |
  | VfxStreak | single | 64x512 | - | - | - | - | - | PASS (exempt: fill, edge, tone) |
  | VfxWisp | 4x4 oneshot | 512x512 | 17% (5%) | 15/16 | 0.000 | 0.005 | cov 7%>0% isl 1>1 | FAIL <- size, fill, edge, tone, motion, erosion |

  Seen while building it: VfxFlame bleeds into its neighbours (alpha over 0.02 within 3 px of the edge in 46 of 64
  cells) and its motion is only just under the limit (0.0079, 64 frames at a small step each); VfxMoth's wrap step
  (0.114) is the same size as its average (0.110), a clean 4-frame loop; VfxCircle and VfxRing are one-tone line
  drawings (tone 0.025, 0.034); VfxDust and VfxWisp never break into islands (erosion fails: they fade). Not checked:
  the preview pictures were not looked at, and no flipbook was played in the engine.
- 2026-11-16, V0.1 (the catalogue and the booth): code merged to main (b92b1227): Presentation/Vfx/Catalog.luau, Debug/FxBooth.luau, an Effects tab in the debug panel, EmoteFx.clips(), VfxCatalog.spec. Checked: stylua, selene, rojo build, check_terms. NOT checked: the specs and the booth have not run; the Studio play test (every entry plays, Stop leaves nothing in Camera.DGVfx, FxBooth.verify() returns {}) waits for Studio to be free. Not done, so V0.1 is not closed.
- 2026-11-16, check C1 (the first graphics plan, phases 1 to 7, in the owner's place): by the records all seven are in the place (v608, scripts as of 1dcb59dc), but the place itself could not be read because Studio was in Play. See docs/handoff/graphics-plan-place-check-2026-11-16.md.
- 2026-11-17, V1.3 light textures, impacts (art/scripts/vfx/tex_impact.py; no Luau, nothing to sync; the Fx import comes at the end of Stage 1). Made, Route E (shape field, minus noise bites, minus a rising threshold; drawn at 2x and boxed down): `VfxImpactA` (sharp: 11 uneven bent rays, 9 hairlines, a fan of short spikes, a hard white core), `VfxImpactB` (heavy: 9 thick wedges, 8 stubs, a big ragged core, dark cracks inside), `VfxImpactC` (soft: 8 clubs of light that swell and move out of the core, they come away as blobs), `VfxShock` (a ring that races out then thins, white-hot outer edge, gaps open into arcs), `VfxGlint` (a four-point star with unequal arms, no ring, turns a quarter way, arms shorten and break into beads), `VfxSparks` (2x2 random, 512 px cells, head up: straight, bent, forked, short). All 4x4 sheets are 16 frames of 256 px; frame 1 is a small readable burst; full by frame 4; erosion from frame 7. Sheets are in `art/export/textures/`, the pictures (each sheet over dark added as light and over light grey laid over, tinted orange and cyan, all 16 frames) in `art/export/previews/vfx/after/<name>_look.png`. check_textures (`--table`), 2026-11-17:

  | texture | kind | size | fill max (mean) | edge cells | tone | motion | erosion | verdict |
  |---|---|---|---|---|---|---|---|---|
  | VfxImpactA | 4x4 oneshot | 1024x1024 | 90% (63%) | 0/16 | 0.178 | 0.022 | cov 5%>0% isl 1>8 | PASS |
  | VfxImpactB | 4x4 oneshot | 1024x1024 | 91% (57%) | 0/16 | 0.167 | 0.036 | cov 4%>0% isl 1>3 | PASS |
  | VfxImpactC | 4x4 oneshot | 1024x1024 | 89% (54%) | 0/16 | 0.177 | 0.046 | cov 11%>0% isl 1>13 | PASS |
  | VfxShock | 4x4 oneshot | 1024x1024 | 81% (56%) | 0/16 | 0.228 | 0.063 | cov 4%>0% isl 1>8 | PASS |
  | VfxGlint | 4x4 oneshot | 1024x1024 | 82% (42%) | 0/16 | 0.185 | 0.015 | cov 2%>0% isl 1>7 | PASS |
  | VfxSparks | 2x2 random | 1024x1024 | - | 0/4 | 0.127 | - | - | PASS (exempt: fill) |

  Against the references and the old textures (VfxBurst, VfxFlare, VfxRing, which are clip art: even spikes, a perfect circle, a ring round a cross): hit and slam sheet (hit_slam_impact_frames_survey): the real frames are hard-edged radial strokes of very uneven length with one dense hub, and ours match that (A and B), but ours have no full-frame wash or noisy smoke edge and C is a soft clump with no match in that sheet; they leave by shards, not by the reference's noise-eaten wipe. Glint sheet (glints_one_life): the reference star has a white core with one clearly longer vertical arm that shrinks to a dot with arms going first; ours has the vertical arm longer and thicker and the arms go first, but it also turns, which the reference does not, and its haze is fainter than the reference's grey halo. Lightning sheet (anime fine) for the sparks: the reference forks are angular with sharp kinks, ours are straight runs with elbows and one side branch, less jagged. Better than the old three: yes, all six replace nothing yet (Stage 4 moves callers); VfxBurst, VfxFlare, VfxRing stay until then. Weak: the three impacts share one family of silhouette (a star), so in use they differ more by size and colour than by outline; the dark cracks in B are hairlines and barely read at game size; Shock's last two frames are empty (it vanishes by frame 14); Sparks' streaks are vertical only (for VelocityParallel); the erosion is shards of noise, not the reference's smoky wipe. Not checked: nothing was played in the engine, no Roblox flipbook tint or blend was seen, the real size in game was not judged, the sheets were not imported.
- 2026-11-17, V1.4 light textures, slashes, arcs and the wisp (art/scripts/vfx/tex_slash.py; no Luau, nothing to sync or import yet; the Fx import comes at the end of Stage 1). Made, Route E, drawn at 2x and boxed down: `VfxSlashA` (4x4 one-shot: a thin fast blade, a long shallow arc corner to corner, hard white outer edge, soft notched inner edge, two faint wake lines and a veil; born as a short stroke, full by frame 3, from frame 6 the trailing end tears into streak lines and specks), `VfxSlashB` (4x4 one-shot: a wide heavy crescent, thick body with a dark grey rim and a white-hot outer band, big teeth torn out of the inner edge, dark slits along it; it breaks off in chunks and the horn lasts longest), `VfxArc` (4x4 random: sixteen standalone bolts from the top of the cell to the bottom, kinked and jittered, forks and twigs, white thread in a bright body in a faint glow; plain, heavy, thin, a Y, wide diagonals, a bow, two strands crossing, a short one ending in a spray, a tree, a zigzag, three tines, stubby forks, twigs, wide forks; some have sparks), `VfxEnergyWisp` (4x4 loop: three strands that share a root and wind into spiral curls; a wave runs up them, the edges fray into fibres that flow toward the tips; it closes exactly after 16 frames). Pictures (each sheet over dark added as light and over light grey laid over, tinted orange and cyan, all 16 frames) in `art/export/previews/vfx/after/<name>_look.png`. check_textures (`--table`), 2026-11-17:

  | texture | kind | size | fill max (mean) | edge cells | tone | motion | erosion | verdict |
  |---|---|---|---|---|---|---|---|---|
  | VfxSlashA | 4x4 oneshot | 1024x1024 | 67% (41%) | 0/16 | 0.248 | 0.013 | cov 2%>0% isl 1>5 | PASS |
  | VfxSlashB | 4x4 oneshot | 1024x1024 | 63% (42%) | 0/16 | 0.249 | 0.028 | cov 3%>0% isl 1>3 | PASS |
  | VfxArc | 4x4 random | 1024x1024 | 88% (45%) | 0/16 | 0.199 | - | - | PASS |
  | VfxEnergyWisp | 4x4 loop | 1024x1024 | 64% (60%) | 0/16 | 0.237 | 0.030 wrap 0.033 | - | PASS |

  Against the references. Slash (slash_ice_fine, slash_basic): the reference crescent is a hard white band with thin concentric streaks inside, notches cut in the inner edge, and it leaves as three grey curved lines and specks; ours matches that structure (hard white outer edge, notched inner edge, streaks, break-up into lines and specks), but its arcs are shorter than the reference's three-quarter circle and it has no curled tip or faint ring behind (A has a veil instead); fill is 63 to 67% of the cell's box, over the check's 55% but under the plan's 80%. Lightning (lightning_anime_fine): the reference forks are two to three straight tines with sharp kinks, near-white core and a cyan edge; ours are kinked runs with forks, white in the middle and colour outside, but the reference's arcs are short and radiate from a ball while ours run top to bottom, and ours have no full-white frame (and must not, docs/vfx.md rule 7). Wisp (aura sheets): the references show soft mottled masses; ours is a drawn tendril with a bright core and a darker fibrous edge, a different thing, because no reference clip shows a curl of light alone. Better than the old VfxSlash (a thin one-tone arc line), VfxSlashBand (a smooth gradient strip) and VfxWisp (6% of its cell, near invisible): yes. All four replace nothing yet (Stage 4 moves callers). Weak: A holds frames 4 to 7 almost still (its motion is 0.013, just over the floor) and is thin enough that at 18 studs it may read as a line; B's silhouette is a clean moon with the interest on its inner edge only, and its last frames are specks; the arcs all run vertically and sixteen is few if one effect fires many (rotate and mirror in Emit); the wisp's edge fray is subtle (the strands read as smooth ribbons at small size), its tips are hair thin, and it looks more like a feather than a curl of smoke. Not checked: nothing was played in the engine, no Roblox flipbook tint or blend was seen, how a Beam would map the arcs was not checked, the real size in game was not judged, the sheets were not imported. Traps are in `docs/agent-memory/slash-arc-wisp-textures.md`.
- 2026-11-17, V1.5 matter textures (art/scripts/vfx/tex_matter.py; no Luau, nothing to sync or import yet; the Fx import comes at the end of Stage 1). Matter is laid over, lit from above and shadowed below, white and grey. Made, Route E (numpy): the three tumblers turn a flat shape in 3D (a rotation matrix, orthographic; the shape's width follows cos of its angle, each side has its own albedo, Lambert shading from the world normal, an edge light on the side that faces the light) and one scale and centre is fitted over all 16 frames; `VfxPaper` (4x4 loop: a page that flips once over and wobbles, torn top edge, a folded corner, a bend and a crease; the front has faint ruled lines, a margin line, a heading and lines of scribble marks, never letters; the back is blank, a shade darker, with the lines faintly through it), `VfxAshFlakes` (4x4 loop, the remake of VfxAsh at 256 px: an uneven chip with a crumbled rim, bites, a hole, pale mottle and dark char patches, cupped and crinkled, turning about a slanted axis while it spins in its plane: a pale lit face, a dark back and an edge-on sliver follow each other), `VfxFeatherTumble` (4x4 loop: a black feather turning about its length while it sways; wider vane on one side, barbs that end at their own places so the rim is serrated, strands at the edge and in the downy base, a split, a shining shaft, a bare quill, a lit rim on the side facing the light), `VfxShards` (4x4 random, a ray-cast of planes: sixteen standalone chunks, eight of stone (block, wedge, pebble, splinter, slab, chunk, flake, stub: flat faces each with its own tone, chipped edges, grain, the odd crack, lit arrises) and eight of glass (thin plates with edges at angles, triangles, quads, a pentagon, slivers, a bright streak across the broad face, alpha 0.64 on the face and nearly solid on the edges)). Sheets are in `art/export/textures/`, pictures (each whole sheet laid over dark and over light grey, tinted warm and cool, all 16 cells) in `art/export/previews/vfx/after/<name>_look.png`. check_textures (`--table`), 2026-11-17:

  | texture | kind | size | fill max (mean) | edge cells | tone | motion | erosion | verdict |
  |---|---|---|---|---|---|---|---|---|
  | VfxAshFlakes | 4x4 loop | 1024x1024 | 65% (47%) | 0/16 | 0.135 | 0.100 wrap 0.111 | - | PASS |
  | VfxShards | 4x4 random | 1024x1024 | 84% (67%) | 0/16 | 0.182 | - | - | PASS |
  | VfxPaper | 4x4 loop | 1024x1024 | 81% (49%) | 0/16 | 0.121 | 0.104 wrap 0.138 | - | PASS |
  | VfxFeatherTumble | 4x4 loop | 1024x1024 | 73% (67%) | 0/16 | 0.124 | 0.043 wrap 0.034 | - | PASS |

  Against the references. Ash and dust (dissolve_ash_fine): the reference grains are tiny, warm in tone, lit on the side facing the light and dark in the lee, in a cloud; ours is ONE big flake per cell with the same lit-side and lee idea, but it is far larger than a grain, grey not warm (the game tints it), and it reads closer to a pumice chip than to burnt paper; fill is 65% at most (the plan says 80%). Paper (paper_feathers_paper_burst): the reference sheets are near-white (about 235) with grey (about 190) on the bent ones, flat squares to edge-on slivers; ours matches that (flat to sliver, a bend and a crease split lit and shaded, a blank grey back) but is more contrasty (the tone floor needed it), is more like a notebook leaf than a loose sheet, and its scribbles are sparse dashes and waves. Feather (paper_feathers_feathers): the reference is white vanes with a thin dark shaft, asymmetric and ragged, foreshortening from oval to narrow as it turns; ours is the same shape change and asymmetry but black (barbs 0.15 to 0.35 with a lit rim and a bright shaft), so over a dark backdrop only the rim and shaft read until the game tints it light. Shards (hit_slam_impact_frames_end shows only smoky dust, no shards, so no direct reference): the owner's rule says stone, glass and dust instead of ink; ours are the clean faceted chunks of the old VfxChunk idea made with real depth. Better than the old VfxAsh (a small flat shard shape on a 64 px grid, one tone), VfxChunk (four flat polygons), VfxPage (a flat notebook spread, one image, no turn) and VfxFeather (a single flat oval with chevron lines): yes, all four; nothing is replaced yet (Stage 4 moves callers). Weak: the flake is lumpy with a strong camouflage mottle and half its loop is the darker back (it has no ash-like soft powdery edge); the paper's back side is a plain stained sheet and the crease shade can read like a shadow cast by something else; the feather's loop moves slowly in the check (0.043, the lowest of the four) and its edge-on frames are hair thin (min_nz clamp 0.1); stone shadows are lifted (0.4 ambient) so the stone reads flat on some cells; glass reads a little like polished metal at small size (a streak and sharp edges, not transparent enough); in Shards cell 13 (a long glass triangle) is the thinnest, a box fill of 46% against the check's 55% floor, which the sheet passes on its largest cell (84%), and the rest are 58 to 84%. Not checked: nothing was played in the engine, no Roblox flipbook tint, blend or lighting was seen, the real size in game was not judged, the sheets were not imported, a sheet's 256 px cell at 18 studs was not looked at. Traps are in `docs/agent-memory/matter-textures-tumble.md`.
- 2026-11-17, V1.1 matter textures, smoke, dust and mist (art/scripts/vfx/tex_smoke.py; no Luau, nothing to sync or import yet; the Fx import comes at the end of Stage 1). Matter: laid over, lit from above and one side, white and grey (the grey is the smoke's own light and shade), 1024 x 1024 sheets. How they were made (Route S, with changes the ticket allowed for): the gas simulation is Blender's Mantaflow, baked headless (`bpy.ops.fluid.bake_data`, cache in a scratch folder, 64 to 140 frames at 128 to 160 voxels), the baked density is read out of the cache's OpenVDB files with Blender's own `openvdb` module and each frame is lit and ray-marched in numpy (orthographic from the side, the sun above and to one side, a self-shadow march so the top is lit and the belly dark), then framed, eroded, looped and packed with vfx/draw.py. Why not Cycles: a headless Cycles render of the baked domain showed nothing (alpha 0 with a plain Principled Volume, with and without noise baked) while a visible mesh in the same scene rendered; two tries, then the own ray-marcher. Mantaflow's noise upres writes empty grids when baked headless, so the grid is simply finer. The traps are in docs/agent-memory/smoke-sim-headless.md. Same-day rework history: the first sims were mushrooms, hairy mats and a pillar; what worked is below.
  `VfxSmokePuff` (8x8 one-shot): a source that swells from a small ball (so frame 1 is a small puff, full by about frame 13) with a radial burst and a little turbulence; the sim gives the mass and its drift, a 3D noise cube sampled relative to the cloud's own centre and radius gives the cauliflower lumps (so they grow with the cloud instead of sliding through it), and a rising cut on the density (noise-carried, thin parts first, from 40% of the life) erodes it into wisps. The window follows the cloud (the sim drifts up; the particle does the drifting in game), fitted so the largest frame fills 90% of the cell. `VfxSmokePlume` (8x8 loop): a fat billowing column from the sim (steady state, frames 56 to 140), lumps carried upward on a tiling noise cube (one climb per half loop, tile period 64 so it closes) and the first 20 frames crossfaded with the sim frames after the loop's end so the last frame runs into the first; stretched 1.2 sideways (a plume is amorphous and the check wants width). `VfxDustRoll` (8x8 one-shot): the puff's recipe with the source half sunk in a floor (the domain's floor collision), spread wider than tall, floor kept at the bottom of every cell, and stretched 1.5 vertically so it is not a flat bar in a square cell (the check wants a box of 55%); the particle can scale it back. `VfxMist` (4x4 loop, 256 px cells): NOT a simulation, and this is the fallback the ticket names, used on purpose: a baked smoke sim of a fog bank came out as cigarette streaks with hard edges at the domain wall, so the bank is a 3D noise volume (soft billows, a wobbly outline, thin front to back, denser low down) whose noise orbits through space in three layers at 1x, 2x and 3x the loop rate, which closes exactly, lit the same way.

  | texture | kind | size | fill max (mean) | edge cells | tone | motion | erosion | verdict |
  |---|---|---|---|---|---|---|---|---|
  | VfxSmokePuff | 8x8 oneshot | 1024x1024 | 72% (48%) | 0/64 | 0.187 | 0.013 | cov 38%>0% isl 1>2 | PASS |
  | VfxSmokePlume | 8x8 loop | 1024x1024 | 69% (63%) | 0/64 | 0.184 | 0.014 wrap 0.014 | - | PASS |
  | VfxDustRoll | 8x8 oneshot | 1024x1024 | 65% (42%) | 0/64 | 0.157 | 0.012 | cov 43%>0% isl 1>3 | PASS |
  | VfxMist | 4x4 loop | 1024x1024 | 75% (74%) | 0/16 | 0.147 | 0.025 wrap 0.021 | - | PASS |

  Preview pictures: art/export/previews/vfx/after/VfxSmokePuff_look.png, VfxSmokePlume_look.png, VfxDustRoll_look.png, VfxMist_look.png. Each shows 16 frames of its sheet (every 4th of 64, or all 16): rows 1-2 over the dark realm laid over in white, rows 3-4 the same added as light, rows 5-6 over a light floor tinted warm, rows 7-8 over a light floor tinted cold. (Rebuild with `blender -b --factory-startup --python art/scripts/vfx/tex_smoke.py -- --sim` then `python art/scripts/vfx/tex_smoke.py --post --look`.)

  Against the references (smoke_dust.toml and its sheets; the same day's eyes, not the game's). Puff against the dust-ring frames (smoke_dust_impact_fine, 0.5 to 0.75 s): the reference is a rosette of cauliflower lumps with radial streaks that breaks into clumps and sags; ours is a rounder lumpy ball with a lit top and a dark belly that thins to wisps, but it has no hollow middle and no radial streaks, and it ends in one or two wisps rather than a field of islands (isl 1 to 2). Plume against the rising-smoke frames (smoke_dust_plume): the reference is a thin braided stem that rolls into paired curls and one big billow; ours is a fat ragged column with lumpy shading and no paired curls (the sim's own curls are lost under the lumps and the sideways stretch), so it reads as a column of smoke but not as that one. Dust against the stock bursts (smoke_dust_impact_fine, 14 to 15.5 s, and the ring): the reference is a flat wedge with a pointed tail or a hollow rosette in the ground's tan; ours is a floor-hugging mound that rises into a streaky, hairy-topped bush (the sim's sinking fingers survive the blur) and is not a ring or a wedge; it does not roll along the floor. Mist against the fog frames (smoke_dust_fog): the reference is an edgeless mass with slow curls and thin filaments at the edges; ours is a compact soft patch with a clear outline, much smaller than a fog bank, and it churns in place rather than curling.
  What is weak: the dust is the weakest (streaky top, no real roll, last frames near empty because the sim has thinned out); the plume has no stem and no paired curls; the mist is a blob, not a bank; the puff's last third is mostly one small wisp. The vertical stretch of the dust (1.5) and the sideways stretch of the plume (1.2) are art-directed to get past the fill check, not physics; the game should scale those particles back. The erosion and lumps run on the density in numpy (the sim only fades), so the break-up edges are the noise's, not the gas's. Not done and not checked: nothing was played in the engine (no flipbook was seen in game or on a lit floor), the old VfxSmoke, VfxDust and VfxWisp stay untouched and in use, and a re-look in the booth over the realm's real light is owed. By eye the puff and plume are clearly better than VfxSmoke (a 19% soft grey ball with no lumps); the dust is larger, shaded and erodes where VfxDust (31%, never breaks up) does not, but it is not clearly better by eye, so keep VfxDust until the pilot decides; the mist is new (no old equivalent). Old names stay until Stage 4 in any case.
- 2026-11-17, V1.6 floor textures (art/scripts/vfx/tex_floor.py; no Luau, nothing to sync or import yet; the Fx import comes at the end of Stage 1). Four single 1024 px images, Route E (numpy), seen from above, white and grey. `VfxCrackA` (matter: a spider crack from an impact point: a ragged hole, 11 radial cracks at uneven angles of which four run to the edge, webbed by short links, branches, hairlines, 70 chips), `VfxCrackB` (matter: one long fracture corner to corner that swells and pinches shut and kinks like split stone, three branches, a second hairline fracture beside it, 11 hairlines, 80 chips, broken edges), `VfxScorch` (matter, no glow: a hard ragged charred edge, a browned band inside it, a dark crust of plates with pale ash seams and ash patches, ember pits; outside it soft soot in streaks and spatter), `VfxSigil` (light: rings and a seven-point star drawn with a brush, the weight swelling and thinning, every ring a spiral that does not close, dry-brush tails, a band of abstract marks (spirals, triangles, diamonds, dot rows, ring-with-bar; no letters), irregular ticks, nodes, a five-sided inner figure, a spiral at the middle, a soft glow). The cracks are shaded from a height field, not drawn as lines: the groove is a hole, its lip a bevel, chips are bumps, the light comes from above left, so the lip on the lower right of a groove is lit (white) and the one on the upper left is dark; flat floor is clear, so the floor shows through (see `docs/agent-memory/floor-textures-cracks-scorch-sigil.md`). Sheets are in `art/export/textures/`, pictures (cracks and scorch laid over a made-up light floor and a dark one, each plain and tinted; the sigil added over dark in orange and cool, white, and laid over light) in `art/export/previews/vfx/after/<name>_look.png`. check_textures (`--table`), 2026-11-17:

  | texture | kind | size | fill max (mean) | edge cells | tone | motion | erosion | verdict |
  |---|---|---|---|---|---|---|---|---|
  | VfxCrackA | single | 1024x1024 | 92% (92%) | 0/1 | 0.324 | - | - | PASS |
  | VfxCrackB | single | 1024x1024 | 93% (93%) | 0/1 | 0.313 | - | - | PASS |
  | VfxScorch | single | 1024x1024 | 94% (94%) | 0/1 | 0.127 | - | - | PASS |
  | VfxSigil | single | 1024x1024 | 91% (91%) | 0/1 | 0.134 | - | - | PASS |

  Against the references and the old textures (VfxCrack: one tone, tone 0.000, thin lines with a faint bruise; VfxCircle: tone 0.025, a clock face of even rings and ticks). Cracks against hit_slam (the 4.1 s frame, white cracks all running to a bright star at the floor): the reference's cracks are graphic white lines that branch from one point, ours branch from one point too, but ours are matter with depth (a black groove, a lit lip, chips), not a two-tone drawing, and nothing in ours glows at the hit. They also differ from the crater in the magic_circle sheet (a ring of broken rock round a hole): ours has the ragged hole only at the centre, no raised rim of rubble. Scorch against fire_candle (which has no scorch frame; its S3 floor ribbon leaves nothing behind, and magic_circle's S1 residue, a dark cracked ring of ground round a small lit disc, is the nearest): ours is an irregular burn with a hard crusted edge and soft soot, not a neat ring round a light, and it has no lit centre, because the ticket asks for no glow. Sigil against magic_circle S2 (white lines on a glow, three or four bands of tiny text-like marks, a curtain of rays at the rim): ours has the bands of marks, the white-line-on-glow look and a few rays, but no ray curtain and no ellipse (the floor decal is flat), and its marks are abstract, never text. Better than the old three: yes, clearly (tone 0.32 and 0.31 against 0.000; 0.134 against 0.025). Weak: A's cracks look more like a branching root or tree than a pure radial web (links are few at game size) and the lip highlight is only an edge on a light floor (it needs a mid or dark floor to read); B's lower half is a hairline and the top left is crowded; both are one pattern each, so two cracks in a room will look alike (rotate and mirror in the code that places them); the scorch's ash patches are cloudy and a little bright, its pits are small dark crescents more than ember holes, and its tone (0.127) is only just over the 0.12 floor (the pale ash is what carries it); the sigil's star is thin next to the rings and the glow is subtle; no tint was tried that is not grey, orange or blue. Not checked: nothing was played in the engine, no Roblox decal or texture tint was seen, the real size in game was not judged, the sheets were not imported. The hairlines (1 to 3 px at 1024) disappear below about 256 px on screen. VfxCrack and VfxCircle stay until Stage 4 moves their callers.
- 2026-11-17, V1.7 meshes, the MESH half (art/scripts/vfx/meshes.py, new art/scripts/vfx/check_meshes.py, art/export/previews/vfx/after/meshes_uv_sheet.png; no Luau, nothing to sync or import yet; the Fx import comes at the end of Stage 1). The one UV rule now: u runs ONCE round the shape's axis (0 to 1, seam on +X, closed, one lattice step wide like every column), v runs UP it (0 at the base or foot, 1 at the tip; Blender's v counts up, so an upright picture stands upright). Per shape, what the UV did before and does now: VfxRing (flat: u round once, v inner edge 0 to outer 1; was u across, v round twice), VfxDome (u round once, v rim 0 to top 1; was swapped, v round twice), VfxTube (u once, v foot 0 to top 1; was u twice round, v = 1 - up), VfxCone (same; the old text said v 0 at the foot, the code gave 1), VfxSwirl (a helical band: u along the ribbon once from its foot, v across from lower edge 0 to upper 1; was u across, v along three times), VfxCrescent (a band: u along from tail 0 to head 1, v across from inner 0 to outer cutting edge 1; was u across, v along with 1 at the tail), VfxSphere (u once, v south pole 0 to north 1; was u twice, v = 1 - up; its rows stop 0.4% short of the poles, a hole nothing shows, and a texture pinches there), VfxShard (the lower point's u sat on a face's edge so each lower face's picture leaned; now the middle of its column, and each belt vertex's v is its own height instead of 0.45), VfxRock (was a plan view, u = x, v = y, so its sides smeared; now round the Z axis, v lowest to highest, the faces over the +X seam cut in two there, 25 triangles instead of 20, nothing stretches). Unchanged because they already followed the rule: VfxSpikes (each spike u round, v root 0 to tip 1) and VfxPage (flat: u across, v up). Nothing in `src` puts a texture on any of these but the Manual's page (Godhood.luau), which did not change, so no caller's look moved. Three new shapes, added to BUILDERS (so the NEXT full export carries them): VfxSlashArc (a 100 degree blade of radius 1 centred on +X in the ground's plane, 0.01 wide at both tips, 0.31 in the middle, cupped 0.3 of its width; u along the arc tail 0 to head 1, v across inner 0 to outer cutting edge 1; 384 triangles), VfxTwister (a funnel open at both ends, radius 0.12 at its foot z 0 to 1 at its top z 2, the wall three lobes that twist 1.25 turns up it and swell as they rise, the axis wandering 0.06; u round once along the lobes' own spiral, v foot 0 to top 1; 1152 triangles), VfxShell (a full sphere of radius 1 drawn on both sides, 32 by 16; each pole is ONE vertex with a fan whose corner takes the middle of its own column, so seen from above the pole is a clean fan and nothing swirls; the last 1/16 of the texture's rows at each end is the pole cap, so a texture for it keeps its top and bottom rows quiet; 1920 triangles). A thing found on the way and fixed for every doubled shape: a face and its back twin share every vertex, so Blender gave their corner normals as zero vectors or the front's pushed onto the back (corner normal against its own face normal: -1.00 on ring, dome, tube, cone, swirl, crescent, page). Neon and ForceField hide this; a lit SurfaceAppearance texture would shade wrongly. `_two_sided_normals` now sets custom normals (the front faces' average at each place, the back face the opposite); every doubled shape reads 0.7 to 1.00 and the normals survive an FBX export and re-import into a scratch folder (the repo's FBX was not touched). check_meshes (`blender -b --factory-startup --python art/scripts/vfx/check_meshes.py -- [--no-render] [--scratch DIR] [--sheet PNG]`), 2026-11-17: 14 shapes, 0 failed. Every shape has all UVs inside 0..1, u and v each spanning 0.000 to 1.000, no degenerate faces, the seam closed on the 10 that wrap, the seam's texture density 1.00 of its row's median on ring, dome, tube, cone, sphere, shell and 1.23 on the twister (its seam sits on a lobe crest, so the real surface is wider there), the most triangles 4096 (the dome; the importer refuses 20,000). The contact sheet art/export/previews/vfx/after/meshes_uv_sheet.png has the three new shapes and all eleven old ones under a test picture (u as hue, which goes once round, v as brightness, dark at 0 and bright at 1, a 16 by 16 checker over both): views A and B from two sides, C square on to the seam, or from above for a shape with a pole. By eye: the rainbow runs round every tube, cone, dome, sphere, shell and twister and the brightness climbs foot to tip; the ring's and crescent's and slash arc's rainbow runs along them and the brightness across; the twister's stripes wind up it and its top view is a spiral; the shell and sphere from above show a clean fan, no pinch point; no seam jump anywhere. Weak: the twister is a wide short funnel (2 tall, 2 across at the top) and at small size reads as a bowl as much as wind; the slash arc is plain (one cup, no twist); VfxShell's 1920 and VfxDome's 4096 triangles are not "a few hundred" (the double drawing doubles them; far under the limit). The four Fx* props in props_fx.py (FxDome, FxRing, FxCrescent, FxSpikes) are baked Core props, not part of this file's UV rule, and were not touched. NOT done (still open for V1.7): the Studio SurfaceAppearance test (AlphaMode Transparency fade, Color tint, EmissiveStrength/EmissiveTint) because it needs Studio; the full export and the ModelsFx 3 to 4 bump (the FBX, ImportVersions and Props were not touched); `Shape.luau` knows nothing of the three new meshes (it needs KEYS and MADE entries: VfxSlashArc 2 x 2 x 0.1 flat like VfxCrescent, VfxTwister 2 x 2 x 2 standing on its foot like the cone, VfxShell 2 x 2 x 2 centred like the sphere, so `lift` must treat "shell" like "sphere"); Stage 2's V2.6 is where a texture goes on them. Not checked: nothing was lit or seen in Roblox, the real FBX was not rebuilt, how Roblox treats the doubled faces' normals was not seen, no texture other than the test picture was tried.
- 2026-11-17, V1.1 send-back rework: VfxDustRoll and VfxMist (art/scripts/vfx/tex_smoke.py, the two PNGs and their previews; nothing to sync or import). VfxSmokePuff and VfxSmokePlume unchanged (accepted). `VfxMist` is rebuilt as a bank: five hand-set soft layers (thickness 0.24 to 0.30 of the bank, low to high) broken into long patches by noise stretched along the bank, each layer drifting one whole noise period per loop (alternating directions, so frame 16 is frame 0 again), fading to nothing before the cell's sides and top and bottom so there is no outline, lit softly from above (darker below) and with the thin edge pulled to the frame's mean grey so no bright rim shows round it. Still not a simulation (the plan's fallback, same reason as before). Numbers: fill 77% (76% mean), edge 0/16, tone 0.128, motion 0.019 (wrap 0.017), PASS. Against smoke_dust_fog: the reference is an edgeless mass with slow curls and bright and dark sides; ours is now a wide soft haze with no outline, brighter at the top and drifting in layers, but its layers are faint (the bands read as a gentle horizontal grain, not clear strata), it fills the whole cell like a block of haze with slightly squared corners, and it has no curls. `VfxDustRoll` is rebuilt as dust spreading along the floor from a hit, seen from the side, with the floor kept at the bottom of every cell and NO vertical stretch. It is NOT a gas simulation: the baked sims tried (a swelling ball on the floor, two outward jets along it, jets under a low closed ceiling, a heavy block slumping with positive and with negative buoyancy density, a long low block) each either rolled the dust up into lobes or a bush or slumped it into a film a few voxels thin that could not be read; the plan's own fallback applies. So it is the volume route: a made-up cast of about 40 billowing cloudlets per side flown out along the floor with drag (the fast, big, higher ones are the head and outrun the rest, the slow ones are the body, low flat sheets fill between, long faint wisps trail), each with its own noise lumps carried with it, the hit's own puff standing over the origin and sinking, lit with the same ray-march, then eaten from its thin parts by a rising noise cut into islands. Numbers: fill 24% at the largest cell (mean 14%), edge 0/64, tone 0.159, motion 0.004, erosion cov 10%>1% islands 1>5; the check FAILS on fill (needs 55%) and motion (needs 0.01), PASS on size, edge, tone and erosion. Why those two fail and are left failing: a mass that is honestly low and wide is about 0.4 as tall as it is wide at its tallest, so with 82% of the cell width used (the rest is the cell margin and the edge fade) its box is 82% x 30% = about 25% of the cell, and a mass that covers a quarter of the cell cannot move the cell-wide mean step above 0.01. It could only pass by stretching it tall or by cutting the cell to a part of the cloud, which was ruled out. Against smoke_dust_impact_fine (the 14 to 15.5 s ground sheet and the ring): the reference is a flat wedge with a pointed tail on one side and puffs on the other, hollow in the ring; ours is two lumpy mounds spreading apart along the floor (the head higher and bigger, the body a lower saddle between them, wisps at the end), fast at the front and thinning into islands, so it does read as dust going out along the ground, but there is no forward curl to the head (the head is a lump, not a roll), the lumps are noise lumps (round and a little soft, not torn), and the tail is not a long pointed wedge. Not clearly better than the old VfxDust by eye, but it is the only one of the two that erodes, spreads along the floor and is lit; the old VfxDust stays in use until the pilot or the owner chooses. Plain verdict for the coordinator: the mist is no longer a blob but is a modest haze; the dust still fails two of the six checks and has no curl, so by the send-back's own rule it should go to the owner as it stands. Not seen in the engine.
- 2026-11-17, coordinator, Stage 1 state: V1.1 to V1.6 are on main and every sheet passes check_textures EXCEPT VfxDustRoll (fill 24%, motion 0.004: a low wide dust mass cannot fill a square cell; sent back once, failed again, so it is the owner's call: keep the old VfxDust, or accept a failing DustRoll, or take the 2 more tries of a different approach). V1.7's mesh half is on main; its Studio emissive test, the full export and the ModelsFx 3 to 4 bump are still open. No texture has been seen in the engine.
