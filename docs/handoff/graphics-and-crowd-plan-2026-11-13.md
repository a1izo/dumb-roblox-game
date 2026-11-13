# Graphics plan, part two, and the Tokyo crowd's logic

Written 2026-11-13 for another agent to carry out. The owner's words: "something like this for photo ref, and do all
of those, and while youre at it fix the logic of the npcs on the tokyo map".

This follows `docs/handoff/graphics-plan-2026-11-12.md` (phases 1 to 7: shadows, the wet street, coloured light from
signs, contact darkness, visible air, rim light, the low-quality notice). Every rule in that file still applies here:
look before and after at Quality 21 through the player's real camera, tune live first, one commit per phase, the
checks before every commit, say loudly when an export bumps a venue's version. Read it first, and its reading list.

There are two parts. Part A is graphics (phases 8 to 15). Part B is the Tokyo crowd (phases C1 to C6). They touch
different files and can be done by two agents at once, with one caution at the end of this file.

## Before you start

On 2026-11-13 the working tree held another agent's uncommitted work on phases 1 to 7 (`lightbook.py`,
`SceneBuilder.luau`, `LightingController.luau`, the venue files, and new `World/AirFx.luau`, `World/RimLight.luau`,
`World/QualityNotice.luau`). Check `git log` and `git status` to see what has landed. Do not redo a landed phase,
and do not start a graphics phase here on top of someone else's uncommitted edits to the same files.

## The owner's reference pictures

Both are in `docs/handoff/refs/`. They are the target for interiors. Open them before every capture you judge.

**`ref-office-single-key.png`: a small office lit by one ceiling panel.** What makes it work:

- One key light. The ceiling panel is the brightest thing in frame and lights the middle of the room. A desk lamp
  is the only other source and it is small and warm-white.
- The light falls off hard. The far wall under the panel is bright, the near third of the frame is close to black,
  and the furniture nearest the camera is a silhouette that frames the picture.
- Every object is grounded: a dark line where wall meets floor, darkness under the desks and behind the cabinet.
- Two-tone walls: a dark lower band and a pale upper wall. The paint is slightly glossy, so the wall catches a soft
  streak of the lamp.
- A cool teal-blue grade with low saturation. One or two small colour accents only (a red poster, a blue folder).
- Detail everywhere, none of it loud: ceiling tile grid, pipes on the wall, a cork board with paper, a filing
  cabinet with labels, boxes on top of a cupboard, a wall clock.
- Fine film grain and a soft glow round the lamp.

**`ref-lab-corridor-red.webp`: a dark corridor beside a lit lab.** What makes it work:

- The corridor has almost no light of its own. It is lit by what spills from the lab through a glass wall and by
  one red exit sign at the far end.
- The red sign colours the wall, the ceiling and the floor near it, then stops. Red is the only strong colour.
- The floor is glossy and mirrors both the red sign and the white lab light as long soft streaks.
- You see into a lit room from a dark one. The window frames are black bars against the bright room.
- Inside the lab the light is local: strips under the wall cabinets, small task lights on the benches, pools not a
  flood.
- Overhead signs and a door at the end give the eye somewhere to go.

**Where the owner's standing rules override the pictures.** Do not break these to get closer to a reference:

- Map ambient stays between 32 and 56 on its brightest channel and `bloomThreshold` stays at 1.8 or more
  (`src/server/Tests/LightingPresets.spec.luau`). On 2026-11-12 the owner said rooms were "blindingly strong in most
  places, completely unlit in others". So get the contrast from shadows, baked darkness and where lamps are placed,
  never from lowering the fill. A silhouette must always show and a face up close must read.
- No heavy blur. The owner had a global depth of field deleted.
- Every light sits in a visible source. Never two lit lamps within 3 studs. Stay inside each venue's `lamp_budget`.
- No layout changes. Walls, doors and props that decide sight lines stay where they are.

# Part A: graphics

## Phase 8: one finished room per map

**Why.** Three finished rooms set the bar for everything else and show the owner the direction early, before the
work is spread over three maps.

**The rooms.**

| Map | Room | Reference | Camera |
|---|---|---|---|
| HQ | one small office or the archive (a room with one ceiling fitting and a desk) | the office picture | from the doorway, eye height, looking at the far wall |
| University | the forensic lab and the corridor outside it | the corridor picture | in the corridor, looking along the glass wall |
| Tokyo | the mouth of the arcade from the crossing (the first Tokyo camera in the earlier plan) | neither: neon over wet road | the earlier plan's camera |

Pick the exact HQ room by walking the map in a play test: the one whose shape is nearest the picture. Write the
room and the camera position into this file under this table when you have chosen.

**Steps.**
1. Capture each room now, at Quality 21 and at Quality 3. Save them as `docs/handoff/refs/before-<map>-q21.jpg`
   and `before-<map>-q3.jpg`.
2. Put the capture beside its reference and write down, in one list per room, what the reference has that the
   capture lacks. Use the bullet lists above as the checklist.
3. Phases 9 to 13 each begin in these three rooms and only then go to the rest of the map.
4. When phases 9 to 13 are done in a room, capture it again as `after-<map>-q21.jpg` and `after-<map>-q3.jpg`
   and show the owner the pairs before rolling out.

**Done when.** The owner has seen before and after pairs for the three rooms and has said which parts to keep.

## Phase 9: shading baked into the map meshes

**Why.** Roblox has no ambient occlusion you can control, and on low quality levels its lighting falls back to
coarse blocks. Darkness baked into the mesh itself shows for every player on every device. This is the biggest
single gain left, and it is what grounds every object in the office picture.

**What exists.** The map generator (`art/scripts/maps/mesher.py`, `export.py`) writes no vertex colours today. The
earlier plan's phase 4 proposed thin gradient strips instead. If phase 4 has landed, keep its strips where they
look good and add this on top. If it has not, do this instead of it.

**Steps.**
1. Prove the route first, with one mesh. In Blender, give one small HQ wall mesh a vertex colour layer that
   darkens it toward the floor, export it as its own FBX, import it into a scratch place, and look at Quality 21
   and Quality 3. Check two cases: a mesh with a SurfaceAppearance and a mesh with a plain colour. Roblox applies
   FBX vertex colours to a MeshPart, but whether they still show under a SurfaceAppearance must be seen, not
   assumed. If they do not show under a SurfaceAppearance, stop and report: the fallback is phase 4's strips plus
   darkening painted into each material's colour map near edges.
2. Work out the darkness per vertex in the generator, after a venue's meshes are built: for each vertex, cast
   about 32 rays over the hemisphere of its normal against the venue's whole geometry (`mathutils.bvhtree`), reach
   6 studs, and take the share that hit something. Props count as blockers (use their collision boxes from the
   catalog), so a desk darkens the floor under it.
3. A big flat wall has vertices only at its corners, so the darkness has nowhere to sit. Add edge loops 0.5 and
   1.5 studs in from every inner crease (wall to floor, wall to wall, wall to ceiling) and round each prop's
   footprint. Count the triangles of every mesh after: Studio refuses 20,000 or more per mesh
   (`docs/agent-memory/mesh-triangle-limit.md`).
4. Cap the strength: the darkest vertex keeps 55 percent of its colour. Aim for "you would miss it if it went".
5. Make it an option per venue (`BAKE_SHADE = True` in the venue module, as `STOP_POOLS` is), on for Agency first.
6. This changes meshes: the venue's version goes up and the owner must import the new FBX. Say so.
7. Props: check whether the prop bake (`art/scripts/props.py`) already bakes occlusion into each prop's colour
   texture. If not, add it there the same way for the props in the three rooms first.

**Done when.** In the HQ room at Quality 3, with every lamp's contribution gone to blocks, corners and the floor
under furniture are still visibly darker than open floor, and at Quality 21 nothing reads as a painted stripe.

## Phase 10: glossy floors and a sheen on painted walls

**Why.** The corridor picture is half reflection. The office picture's wall catches the lamp. Today most surfaces
are fully matt.

**Steps.**
1. Live, in the University corridor: on the floor mesh, read its SurfaceAppearance maps, then try a plain grey
   RoughnessMap value by swapping in a test texture from Studio's own content folder (the trick in
   `docs/agent-memory/lighting-rework-2026-11.md`, 2026-11-06, needs no upload). Try roughness 0.15, 0.25, 0.35.
   Also try `Lighting.EnvironmentSpecularScale` from 0.6 to 1.
2. Find the value where the exit sign and the lab's light show as long soft streaks and the floor does not become
   a mirror. Polished vinyl and stone want about 0.2 to 0.3. Painted walls want about 0.5 to 0.6, down from fully
   rough.
3. Write the values in `art/scripts/maps/scanlib.py` for those materials only: lab and corridor vinyl, HQ's lobby
   stone, HQ's office floors, the painted wall looks. Carpet, concrete, brick and snow stay rough.
4. This needs retextured exports and new texture uploads (`--retexture`, `docs/agent-memory/imports-by-open-cloud.md`).
   The owner asked for this work on 2026-11-13. Still list every upload in your report.
5. Tokyo's road is the earlier plan's phase 2. Do not redo it. Use the same roughness for puddles on pavements if
   phase 2 left them dry.

**Done when.** From the corridor camera the floor shows the red of the exit sign and the white of the lab as soft
streaks, and a player standing on it is not mirrored sharply.

## Phase 11: light placed like the pictures

**Why.** Both pictures get their mood from where the light is not.

**Steps.**
1. One key per small room. In each small office, store and interview room, one ceiling fitting is the key and
   casts shadows (phase 1 of the earlier plan added the option). Any second ceiling fitting in a room under about
   200 square studs becomes a dead fitting on the venue's deliberate pattern, or goes. A desk lamp stays as the
   small second source.
2. Dark corridor, lit room. Where a corridor runs beside a room with interior glass (the University lab, HQ's
   glazed offices and security), take the corridor's own lamps down to one in three and let the room light it
   through the glass. Check the corridor still reads: a silhouette must show along its whole length.
3. Exit signs that light. Over each door that has one, the sign gets one small light in its own colour (red in
   HQ, where the beacons already are; green or red on the University, whichever its signs are), range 12 to 16,
   brightness 0.6 to 1.0, at the sign's face. One per sign. Keep `check_v2`'s `lamps` rule passing.
4. Local light in work rooms. In the lab, the canteen kitchen and HQ's print room, add strip lights under wall
   cabinets (`kit.tube_light`, short, cool white, range 6) and lower the ceiling pools over the same benches so
   the room is lit from its work surfaces.
5. Two-tone walls. Agency already has dados (`docs/agent-memory/agency-interiors-2026-11.md`). Give the offices
   and corridors that lack one a darker lower band 3.5 studs high. University corridors too.
6. Tune live, then write the numbers, export (lights only do not bump the version; the dado changes meshes and
   does).

**Done when.** The HQ room has one clear key and a near-black foreground with readable silhouettes, and the
University corridor is lit mostly by the lab and the exit sign.

## Phase 12: surface detail

**Why.** The cold rooms (HQ security, the University lab) were noted as flat. The pictures are full of small quiet
detail.

**Steps.**
1. Ceilings: a tile grid on office ceilings (a normal-mapped material, not geometry), and runs of pipe or conduit
   along one wall near the ceiling in service rooms and corridors.
2. Walls: `matlib.py` already has alpha looks for wear. Add a small set: scuffs at chair height, a stain under a
   pipe joint, a darker patch round a light switch, tape marks. Place them from the generator with a seeded
   random, at most three per wall, never repeated side by side.
3. Paper: cork boards with pinned sheets, labels on cabinet drawers, a wall clock, a fire notice by each door.
   The Agency has framed prints (`PrintsAgency`); do the same for notices.
4. Things on top of things: boxes on cupboards, files on desks, a mug, a coat on a chair. Use props that exist in
   the venue's own set (`docs/agent-memory/own-furniture-2026-11.md`: no prop stands in two case maps).
5. Do not block a walk or change a hiding place. Run `check_v2` and `find_ghosts.py` after.

**Done when.** A capture of the HQ room, with the lamp turned off live, still reads as a real office from its
shapes and surfaces alone.

## Phase 13: things that move

**Why.** A room where nothing moves reads as a model, however well it is lit.

**Steps.** All client-side, built from the map's own parts, off in Low quality mode (`Motion.isLow()`), still
under Reduce motion (`Motion.isReduced()`). Follow the pattern of `World/LampHaze.luau` and `World/AirFx.luau`.

- HQ: a slow ceiling fan in two rooms, blinds that sway a little by the outside glass, rain running down the
  outside glass, a monitor whose picture changes every few seconds, one tube that buzzes and flickers (the dead
  and flickering fittings exist; add the sound).
- University: breath in the cold outdoors (a faint puff at each walking character's head, own client only if
  cost matters), snow sliding off a roof edge now and then, a lab machine with a blinking light, a clock whose
  hand moves.
- Tokyo: neon that flickers on two or three signs on a fixed pattern, steam from vents and from the ramen bar,
  hanging signs and cables that sway, vending machine screens that cycle, drips from awnings.

One kind of thing per commit. Read the frame rate before and after with a whole street or floor in view.

**Done when.** Standing still for ten seconds anywhere in the three finished rooms, at least two things move.

## Phase 14: characters

**Why.** The game is about staring at faces, and the characters are the plainest thing on screen. R6 stays (the
owner's decision, `docs/agent-memory/r6-cutscene-redo.md`).

**Steps.**
1. Look at a suited R6 character under the HQ room's key at 6 studs. Note what reads cheap.
2. Suits (`src/shared/Suit.luau`): a cloth normal map and a roughness map so the jacket catches the key and the
   shirt does not. Check the bloom rule holds on pale skin and white shirts.
3. Never re-add suit fists (`docs/agent-memory/owner-rejected-changes.md`).
4. The rim light is the earlier plan's phase 6. If it landed, judge it in the three rooms and tune it there.

**Done when.** A character standing in the dark third of the HQ room separates from the wall behind, and one under
the key shows cloth, not flat colour.

## Phase 15: the look at low quality

**Why.** Most players are on phones or Automatic. A script cannot raise their setting. The notice (earlier phase
7) only tells them.

**Steps.**
1. Capture the three rooms at Quality 1, 3, 5 and 10, on the play-test client.
2. Find what breaks at each level (lamps as blocks, no shadows, no pools) and what still holds (baked shading,
   materials, grade, fog, motion).
3. In `LightingController.luau`, read the client's quality level and, under the level where pools are lost,
   blend toward a low-quality variant of the preset: a little more fill inside the spec's limits, a stronger
   grade, more haze. The aim is a flat but deliberate picture, not a broken dark one.
4. Phones: check the result with `DGForceDevice` (`docs/agent-memory/mobile-and-perf-2026-11.md`).

**Done when.** The Quality 3 captures of the three rooms look like a darker, simpler version of the same game,
with no room that is plain black or evenly grey.

# Part B: the Tokyo crowd

The owner asked for the crowd's logic to be fixed and did not say which behaviour looks wrong. The list below is
from reading the code on 2026-11-13. It was not watched in a play test. **Before changing anything, watch the
crowd for five minutes** in a play test of `TokyoDistrict` (the scramble, the arcade, one dead-end street, the
station doors) and tick off which of these you see. If the owner names something not on this list, that comes
first.

## How it works today

- `art/scripts/maps/venues/tokyo/crowd.py` lays the walk graph: 261 nodes, 270 links, 6 of them crossings, 4
  posts. It is written to `src/server/Maps/Scenes/Tokyo/Layout/init.luau` by the Tokyo export.
- `src/server/Maps/Mechanics/TokyoDistrict/CrowdSim.luau` moves 50 walkers as numbers. `Crowd.luau` beside it
  keeps the history for sight lines and name-tag cover. `init.luau` steps it and sends snapshots five times a
  second.
- `src/client/World/Crowd.luau` draws bodies between snapshots, 0.3 seconds late.
- `src/server/Tests/CrowdSim.spec.luau` steps the sim by hand. It is deterministic for a given `Random`.

## What is wrong, from the code

1. **Walkers do not see each other.** `CrowdSim:step` minds players and the intro's marks and nothing else. Two
   walkers can stand on the same spot, a fast one walks through a slow one, and a group waiting at a kerb is
   spread only by a random 0 to 3 studs along the walk.
2. **Nobody is going anywhere.** `_pick` chooses a random way on at every node. Walkers wander, double back
   across the district, and at each of the graph's 14 dead ends they walk to the end, stand for 2.5 to 7
   seconds and walk back. The dead ends are the barricades at the map's edge, where a person would leave.
3. **Everyone jogs at one speed.** `PACE` is 13.5 to 16 studs a second. A player moves at 16. The whole crowd
   moves at a player's full speed, all alike.
4. **Starts, stops and turns snap.** `walker.speed = want` has no acceleration, so a walker goes from full pace
   to zero in one step. At a node the heading jumps to the next link's direction.
5. **Pauses have no reason.** 12 percent of walks end in a 1.5 to 4 second stop at whatever node is there,
   facing the way they were walking. Nobody turns to a shop window or looks at a phone.
6. **Waiting at the kerb faces the wrong way.** A waiting walker keeps the heading of the pavement it arrived on,
   not of the crossing it is waiting for.
7. **The crowd is thin where it matters.** 50 walkers are seeded evenly over 2,541 studs of walks, about one per
   51 studs. Name-tag cover needs 2 walkers within 5 studs. The scramble, which is meant to be the place to
   vanish into, is rarely that dense.
8. **Faults in the graph.** Two links are laid twice (114 to 115, and 149 to 256), which doubles the odds of
   those turns. 27 links are 1 stud wide or less, where a walker cannot keep left or step round anyone.
9. **On the client.** A body's ground height is looked up every 0.4 seconds, so bodies step up and down kerbs
   late. Bodies beyond the device cap appear and vanish with no fade. The clerks at the four posts stand with no
   life at all.

## What must not change

- The server holds no bodies. The sim stays plain maths and deterministic, so the specs can step it.
- Walkers block sight lines where clients saw them (`Crowd.bodiesAt`, `DRAWN_BEHIND`).
- A walker held up for `PIN_TIME` steps through the player, and the client lets its own player through sooner.
  This was the owner's call on 2026-10-27: collision kept, nobody stuck.
- Walkers keep left. Crossings are walked only on the walk signal. Nobody walks over a station or a spawn
  (`MapContract.validateCrowd`).
- Snapshots go by an unreliable remote, which has a small size limit. Measure the encoded snapshot
  (`MapSync.encode`) before adding a field or a walker.

## Phase C1: fix the graph

In `crowd.py`: `Walks.link` skips a pair that is already linked. `_tie` and `join` are where the doubles come
from. For the narrow links, try to move the node pair to a wider line; where the pavement really is that narrow,
mark the link `single = true` so the sim sends walkers along it one way at a time. Add both as rules in
`check_v2` (no double link, no link under 1.5 wide without `single`). Tokyo export, lights and layout only: the
version should not change, check that it did not.

## Phase C2: trips, not wandering

1. In `crowd.py`, mark the nodes people come from and go to as `ends`: each barricade end, each station door, and
   a door node for the konbini, the ramen bar, the game centre and the arcade's far end. Give each a weight
   (station and scramble streets heavy, lanes light).
2. In `CrowdSim`, each walker has a destination. Its route is the shortest path over the graph (261 nodes: work
   it out once per trip). `_pick` follows the route. Keep the "not straight onto another crossing" rule.
3. At a map-edge end the walker is set `shown = false`, waits 2 to 8 seconds, and comes back in at an edge end
   with a new destination. At a door end it does the same (it went inside). The client already hides a walker
   that is not shown and already shows a moved walker at its new place at once (`LEAP`).
4. Seed the round with walkers already part-way along trips, so the street is not empty at the start.

## Phase C3: walkers that mind each other

1. A coarse grid over the walkers, rebuilt each step (50 bodies: cheap).
2. Following: a walker with a slower one ahead on its own side within 4 studs matches its pace, or, if the walk
   is wide enough and nobody is coming, moves out and passes.
3. Oncoming on a narrow walk: the one nearer its end goes first, the other waits at its node.
4. Standing: no two standing walkers within 1.6 studs. At a kerb, each takes the nearest free place in two or
   three rows across the walk's width.
5. Never let this trap a player: the existing step-through and yield rules run after it and win.

## Phase C4: how they move

1. Three kinds of walker, picked at seeding: strollers at 7 to 9 studs a second (a quarter of them), walkers at
   10 to 12 (half), people in a hurry at 13 to 15 (a quarter). Check the walk clip's speed follows
   (`LocomotionController.setSpeed`) so feet do not slide.
2. Speed eases: about 20 studs a second squared up and 30 down.
3. Turns ease: the heading turns at no more than 360 degrees a second, and a walker starts its turn a stud before
   the node.
4. At a kerb, turn to face the crossing while waiting.
5. `HURRY` on the crossing stays.

## Phase C5: pauses with a reason

1. In `crowd.py`, lay pause spots beside the walks with a facing: shop windows, vending machines, the route map
   in the station hall, the railing over the river, under an awning. A spot holds one walker.
2. A walker passing a free spot takes it with a small chance, steps off the walk to it, turns to its facing,
   stands 3 to 10 seconds, and goes on with its trip. Remove the old placeless pause.
3. A standing walker plays a small idle (looking at a phone, looking up at a sign, shifting weight). Use
   `Anim/Life` (`docs/agent-memory/cutscene-life-layer.md`) for breath and glances. A new clip needs the
   animation pipeline: one phone clip is enough to start. Send the idle's kind in the snapshot only if the size
   allows, otherwise pick it on the client from the walker's number.
4. The four clerks get the same life layer and, now and then, a turn of the head toward a player who comes
   within 8 studs.

## Phase C6: density and the client

1. Weight trips so that more of them pass through the scramble, the arcade and the station doors. Measure, in a
   spec, how often 2 walkers are within 5 studs of the scramble's centre over a five-minute run: aim for most of
   the walk phase.
2. Only then consider raising `Crowd.WALKERS` from 50 (the client already caps what it draws at 18 to 40 by
   device). Measure the snapshot size and the frame rate on a phone first.
3. Ground height: look it up every frame for bodies within 20 studs of the camera, keep 0.4 seconds beyond.
4. Bodies entering or leaving the drawn set fade over 0.3 seconds, or are only swapped while off screen.

## Tests and the done-test

Add to `CrowdSim.spec.luau`, one or more per phase: no two walkers within 1.2 studs after a five-minute run with
no players; no walker ever on a crossing while the cars have had their light for more than its crossing time;
every trip ends at an end node; no walker turns back mid-walk except at a blocked single-file link; speed never
changes by more than the acceleration allows in a step; the same `Random` seed gives the same run. Keep every
existing spec passing: where one encodes the old wandering (a dead end's linger, the placeless pause), change it
with the behaviour and say so in the commit.

**Done when.** Watching the scramble for two full lamp cycles in a play test: groups form at the kerbs in rows
and face the road, they cross together and thin out, nobody walks through anybody but a player who blocked them,
nobody stands facing a wall, people of different speeds pass each other, and people leave at the map's edges
and others arrive.

# Working at the same time as the lighting agent

- Part B's Lua (`CrowdSim.luau`, `Crowd.luau`, `World/Crowd.luau`, the spec) is nobody else's. Start there.
- Part B's `crowd.py` changes reach the game through a Tokyo export, which rewrites everything under
  `src/server/Maps/Scenes/Tokyo/`. On 2026-11-13 the lighting agent had uncommitted Tokyo exports. Export Tokyo
  only after their work is on main and merged into yours, and commit only the files your change is meant to
  alter.
- Part A waits for phases 1 to 7 to land. It builds on their lamps, shadows and effects.
- Fetch and merge origin before every push. Never stage `src/shared/Assets.luau`.

# Report after each phase

As in the earlier plan: what changed and where to look, before and after pictures, the frame rate, which imports
are needed (file name and version) or "script sync only", what was checked and what was not seen. Add what you
learned to `docs/agent-memory/` (lighting notes in `lighting-rework-2026-11.md`; the crowd deserves a file of its
own once its first phase lands).

## Status of Part B, 2026-11-13 (carried out by another agent)

How the crowd was watched, with the numbers before the rework, is in `docs/agent-memory/tokyo-crowd-2026-11.md`
(`scripts/crowd/watch.luau`, run through the bundle in `docs/agent-memory/spec-bundle-via-rbxasset.md`). Every item of
"What is wrong, from the code" was confirmed except 9, which is on the client and needs a drawn crowd.

| Phase | State | What the owner has to do |
|---|---|---|
| C1 graph | Done: no double links, 21 of the 27 narrow walks widened, the 6 left marked `single`; `check_v2` and `MapContract` hold both rules. Tokyo export changed only the layout data: Maps v47 kept. | Script sync only |
| C2 trips | Done: 20 ends in the layout (hall doors, edge barricades, three shop doors, the arcade's far end, the dead ends), a route table per end, trips with 2 to 8 s out of the world at each end, walkers seeded part-way along trips. No more U-turns or dead-end lingering. The placeless pause stays for C5. Tokyo export: layout data only, Maps v47 kept. | Script sync only |
