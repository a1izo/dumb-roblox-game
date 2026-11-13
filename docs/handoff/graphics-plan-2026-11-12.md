# Graphics plan: from balanced lighting to a great-looking game

Written 2026-11-12 for another agent to carry out. The owner's words: "i want the graphics to be insanely good" and
"my game theoretically runs very heavily on its aesthetics". The lighting was balanced the same day (commit
1402c421); this plan is what comes after. Do the phases in order. Each phase is one commit that stands on its own.

## Read these first (15 minutes, saves hours)

- `docs/agent-memory/lighting-rework-2026-11.md`: every lighting decision and every trap so far. Read all of it.
- `docs/agent-memory/lighting-sweep-2026-11.md`: how rooms were measured (`art/scripts/maps/room_light.py`).
- `docs/agent-memory/workflow.md`: how work is delivered here (checks, commits, getting things into the place).
- `docs/agent-memory/studio-mcp.md`, `studio-no-screen.md`, `imports-by-open-cloud.md`: how to look at the game and
  how imports reach the place without taking the owner's screen.
- `docs/agent-memory/protect-user-assets-edits.md`: never stage, format or check out `src/shared/Assets.luau`.
- `docs/agent-memory/mobile-and-perf-2026-11.md`: the performance limits. Every phase below adds cost.

## Rules that apply to every phase

1. **Look before and after.** Nothing is done until you have seen it in a Studio play test. Take a "before" capture
   and an "after" capture from the same camera for each phase and compare them yourself.
2. **Judge only at full quality.** Studio's play-test Quality Level must be 21 (`settings().Rendering.QualityLevel`
   from the Edit datamodel). On Automatic, Roblox uses voxel lighting and nothing here shows.
3. **Use the player's real camera.** `screen_capture` with its own `camera_position` renders a view the engine does
   not light. Pin the real camera instead (BindToRenderStep at `RenderPriority.Last.Value + 50`, Scriptable, set
   CFrame) and capture with no camera arguments. Capture twice: the first frame after a change is often stale.
4. **Change one thing at a time** when tuning, and compare captures. HQ has lightning that washes frames white.
5. **Clear old maps before building one in a test**: destroy every `LGameMap` in workspace, then
   `MapService.build("<MapId>")` from the Server datamodel. Map ids: `TaskForceHQ`, `UniversityCampus`,
   `TokyoDistrict`. A map's origin is near z = 3000.
6. **Tune live first, then write the values into the repo.** Emulate on the play-test client with `execute_luau`,
   find values that look right, then put the same numbers in code. Never edit the shared Team Create place by hand.
7. **Respect the specs.** `src/server/Tests/LightingPresets.spec.luau` holds the owner's limits: map ambient between
   32 and 56 (brightest channel), `bloomThreshold >= 1.8` on every preset (the owner chose this so skin never
   glows; HQ is 2.2). Do not loosen a spec to make a change pass.
8. **Checks before every commit**: `selene src`, `stylua --check` on the changed Luau files only (never the
   generated files under `src/server/Maps/Scenes/`), `python scripts/check_terms.py`,
   `rojo build default.project.json -o <scratch>/check.rbxl`, and for a changed venue
   `"C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/maps/check_v2.py <Venue>`.
9. **Exports.** `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python
   art/scripts/run_maps.py -- <Venue> --export` (Venue: Agency, Campus, Tokyo). Export one venue per run (several at
   once leaves stray `art/blend/Maps_A_B.blend` files). If the export's version number goes up, the meshes changed
   and the owner must re-import that FBX, or the map builds as a grey box. Say so in the commit and in your report,
   with the file name and version. Lights alone never bump the version.
10. **Commit style**: one long plain sentence as the title, then what changed, why, what was checked and what was
    not seen. Fetch and merge origin before pushing; another agent pushes to main all day.
11. **Stop and ask the owner** if a phase needs a new texture upload, makes the frame rate drop below 45 on the
    owner's machine at Quality 21, or changes how a room plays (sight lines, hiding places).

## How to look at the game (the loop you will repeat)

1. Open the place in Studio if it is not open (see `studio-no-screen.md`; park the window off screen, restore its
   placement before closing). `list_roblox_studios` gives the `studio_id`.
2. `start_stop_play(true)`. On the Server: wait 5 s, destroy every `LGameMap`, `require` MapService (find the
   ModuleScript named `MapService` under ServerScriptService), `build(<MapId>)`, pivot the player's character to
   `info.spawns[1]`.
3. On the Client: disable every ScreenGui in PlayerGui, set `LocalTransparencyModifier = 1` on the character's
   parts, pin the camera as in rule 3.
4. Capture, change one value, wait 4 s, capture twice, compare.
5. `start_stop_play(false)` when done. Everything changed in play is thrown away.

Standard cameras (world space; use the same ones for before and after):

| Map | Camera position | Look at | Shows |
|---|---|---|---|
| HQ | (-30, 9, 3035) | (-70, 2, 3000) | the bullpen |
| HQ | (30, 6, 3022) | (52, 4, 3030) | the lobby's east glass wall |
| Campus | (-20, 8, 3060) | (-20, 3, 2990) | the avenue and the clock tower |
| Campus | (30, 7, 2945) | (18, 3, 2925) | brick walls beside lamp posts |
| Tokyo | (-60, 8, 2935) | (0, 2, 2905) | the crossing and the arcade's mouth |
| Tokyo | (-20, 7, 2920) | (30, 4, 2960) | the arcade's wall and the street |

## Where things live

- Looks per venue (fill, grade, bloom, haze): `src/shared/LightingPresets.luau`. Blended on the client by
  `src/client/World/LightingController.luau`.
- Post effects: `src/client/World/PostFx.luau` (depth of field, grain). Light shafts and dust:
  `src/client/World/LampHaze.luau`. Lightning: `src/client/World/Lightning.luau`. Rain and snow:
  `src/client/World/RainController.luau`.
- How a lamp is built in the game: `addLight` in `src/server/Maps/SceneBuilder.luau` (the `SOFT` table softens
  ceiling pools and adds the "Bounce" light). Prop lamps: `propLights` in the same file, from
  `src/shared/ModelCatalog.luau`.
- Where lamps are placed: `art/scripts/maps/lightbook.py` (shared helpers: `pool`, `ceiling`, `wall`, `facade`,
  `post`, `stop_pools`) and each venue under `art/scripts/maps/venues/<agency|campus|tokyo>/`.
- Flat materials and their fallbacks: `art/scripts/maps/matlib.py`, written to `src/shared/SceneMaterials.luau`.
  `dress` in SceneBuilder applies them (it already supports `reflectance` and `transparency` per look).
- Scanned textures: `art/scripts/maps/scanlib.py` (colour, normal, roughness, metalness per material).

## Phase 1: real shadows from a few lamps per room (biggest gain)

**Why.** No lamp casts a shadow today, so furniture and people float and rooms read flat.

**History you must know.** Turning `Shadows` on at runtime for the lamps nearest the player made lamps go dark
("as soon as I walk in a certain radius the light just turns off"). LightingController now only gives shadows to
lamps BUILT with `Shadows = true`. So shadows must be decided in the map generator, per lamp, and tested live.

**Steps.**
1. In a play test on HQ, pick the bullpen. On the client, set `Shadows = true` on ONE ceiling pool
   (a SpotLight in a part named `Light`) and capture. Check three things: the lamp still lights the floor; the
   desks under it throw shadows; the lamp's own fitting does not block it. If the lamp goes dark, its source is
   inside a mesh: note which fitting, and move the light lower in that fitting's helper (`fit.panel`,
   `fit.downlight`, `kit.tube_light`, `kit.pendant`) until it clears.
2. Walk the camera towards and away from that lamp and turn round. The lamp must stay lit. If it goes dark as you
   approach, stop and write down what you saw in `lighting-rework-2026-11.md`; do not ship shadows on that fitting.
3. Find the budget: turn shadows on for 2, 4, 6, 8 lamps in view and read the frame rate each time
   (count RenderStepped over 2 s; Studio must be on screen or parked off screen, not minimised). Keep the highest
   count that holds 55 fps or more at Quality 21 on this machine.
4. Add a `shadows=True` option to `lightbook.pool` and pass it from the venue files for chosen lamps only: one or
   two per room, the lamp over the room's main feature (the interview table, the print scanner, the map table,
   the reception desk). Never two shadow lamps within 20 studs of each other.
5. The "Bounce" light never casts shadows. Leave it.
6. Low quality mode and the governor already cut shadows (`fewShadows` in LightingPresets.resolve). Check that Low
   quality mode turns these off: in `applyLamps`, a lamp with `canShadow` gets `light.Shadows = key`; confirm the
   built shadow lamps are the keys and that `keyLights` covers them.
7. Export the venue (lights only: the version must not change), run check_v2, capture before and after.

**Done when.** In each of HQ's main rooms a desk or table throws a visible shadow, no lamp goes dark when you walk
up to it or turn away, and the frame rate holds. Then repeat for Campus interiors and Tokyo's shops. Outdoor lamp
posts: try shadows on the University's posts (tree branches across snow would look superb); keep them only if the
frame rate holds with a whole avenue in view.

## Phase 2: Tokyo's wet street

**Why.** The road reads as a pure black void (its asphalt scan is near black). Tokyo is a rainy neon night: the road
should mirror the signs.

**Steps.**
1. In a play test, find the road meshes (`Map_Tokyo_AsphaltWet_<n>`). Live, try on one: a SurfaceAppearance with
   low roughness is what makes reflections. Read the mesh's SurfaceAppearance maps first (ColorMap, RoughnessMap,
   MetalnessMap). Try, one at a time: `Reflectance` 0.15 to 0.35 on the part; a lighter `Color` under the
   SurfaceAppearance; `Lighting.EnvironmentSpecularScale` 0.6 to 1.
2. If the part's properties are not enough, the roughness map must change: in `scanlib.py` find how AsphaltWet's
   roughness is made and lower it (wet tarmac is about 0.15 to 0.3 with darker puddles), and lift the colour map a
   little so it is dark grey, not black. This needs `run_maps.py -- Tokyo --export --retexture` and new texture
   uploads: stop and tell the owner before uploading (rule 11), or follow `imports-by-open-cloud.md` if the owner
   has already agreed.
3. Check the crossing's white stripes still read and the road does not turn into a mirror (it should hint at the
   signs, not copy them).

**Done when.** From the first Tokyo camera, the road shows soft coloured reflections of the neon and the lit
windows, and no part of the street is pure black.

## Phase 3: coloured light from what glows

**Why.** Signs, screens and windows glow but light nothing, so the glow looks painted on.

**Steps.**
1. Tokyo: list the big lit signs and screens (`s.sign(...)` with a glow, `s.screen(...)`, neon boxes in
   `art/scripts/maps/venues/tokyo/`). For each large one, add a `lightbook.facade` light in the sign's colour:
   range 14 to 22, brightness 0.6 to 1.2, facing out of the wall. One light per sign, at the sign's face, never
   floating in the air (the owner's rule: every light sits in a visible source).
2. Keep the check_v2 `lamps` rule passing (no two lit lamps within 3 studs; overlap under the venue's
   `lamp_budget`). Tokyo has no budget set: add `"lamp_budget": 12` to its CHECKS and fix what it flags.
3. HQ: monitors already have spill lights; check each sits at its screen and is blue-white, 0.5 to 0.8.
4. Campus: lit windows seen from outside should spill warm light onto the snow below them: a `lightbook.facade`
   under each lit ground-floor window group, range 12, brightness 0.5.
5. Tune live first (rule 6), then write, export (lights only), capture.

**Done when.** Standing in a Tokyo alley, the walls and ground near a pink sign are tinted pink, near a cyan sign
cyan, and the tints fall off within about 20 studs.

## Phase 4: contact darkness

**Why.** Roblox computes no ambient occlusion you can control. Where a wall meets a floor or a desk stands on
carpet, a soft dark edge makes everything look grounded. It was promised to the owner on 2026-11-01 and never done.

**Steps.**
1. Cheapest route first: thin dark gradient strips. `matlib.py` already has alpha looks (wear drawn on walls; see
   `dress` in SceneBuilder, `look.alpha`). Make one soft black-to-clear gradient texture (256 x 32) and place it
   as: a 0.6-stud strip on the floor along every inner wall (the `fit.partition` helper in each venue knows where
   walls are), and a soft dark rectangle under each desk, table, sofa and cabinet prop (the prop's catalog size
   gives the footprint; grow it by 0.4).
2. Try it live on one HQ room first by placing a Decal or a thin part with the texture, so you can judge strength
   before touching the generator. Aim for "you would miss it if it went", about 35% black at the edge.
3. This changes meshes, so the venue's version goes up and the owner must re-import (rule 9).

**Done when.** In a capture of the bullpen, each desk has a soft dark patch under it and the wall bases have a soft
dark line, and neither reads as a drawn stripe.

## Phase 5: air you can see

**Steps.**
1. Tokyo alleys: low fog sheets that catch the neon. Use the pattern in `LampHaze.luau` (camera-facing Beams with
   the `AuraGlow` texture) or soft ParticleEmitters, tinted by the nearest sign's colour, very faint.
2. Campus: snow haze round each lamp post's head (a faint warm glow sphere, a Beam cone down), and denser falling
   snow inside each lamp's cone than outside it.
3. HQ: the shafts exist. Make them a touch stronger near the outside glass, where the city's light comes in.
4. All of it off in Low quality mode (`Motion.isLow()`), still under Reduce motion (`Motion.isReduced()`).

**Done when.** Each map has one kind of visible air that the other two do not.

## Phase 6: light on characters

**Steps.**
1. A faint rim light so a player separates from a dark background: try a low-brightness PointLight (0.25, range 6,
   the map's cool fill colour) attached behind each character's head on the client, or a `Highlight` with only a
   very faint outline. Judge it on faces: the game is about staring at faces and reading names.
2. It must not reveal a hiding player through a wall and must go out in a blackout (see `World/Blackout.luau`).
   If either cannot be guaranteed, drop this phase and say so.

## Phase 7: tell low-quality players

A script cannot change a player's graphics setting. Read
`UserSettings():GetService("UserGameSettings").SavedQualityLevel` on the client; when it is Automatic or under 7,
show one small notice the first time they enter a map. Use `Kit.notice` (see `ui-notice-component.md`) and the UI
text style (`ui-text-style.md`: short, plain, no em dashes). Suggested text: "Raise Graphics Quality in the Roblox
menu to see the full lighting". Show it once per session.

## What is out of scope

- The lobby (the Grey Realm), the meeting room and the cutscene sets: other agents own their looks.
- Ray tracing or true bounced light: Roblox has neither. The target is one of the best-looking Roblox games.
- Any layout change. Walls, doors and props stay where they are.

## Report after each phase

Write to the owner in plain words: what changed and where to look, the before and after pictures, the frame rate,
which imports are needed (file name and version) or "script sync only", what was checked and what was not seen.
Add what you learned to `docs/agent-memory/lighting-rework-2026-11.md`.

## Status, 2026-11-13 (carried out by another agent)

Phases 1 to 7 are in the code and checked; phase 4 was switched on later the same day (Agency v33). Pictures in
`docs/graphics-2026-11-13/`; what was learned in `docs/agent-memory/lighting-rework-2026-11.md`.

| Phase | State | What the owner has to do |
|---|---|---|
| 1 shadows | 20 HQ pools, 12 Campus, a few in Tokyo built to cast; the nearest few are keyed. Root cause of "lamps go dark" found and fixed (a shadow spot within ~1 stud of a ceiling is dark). Lights only: no version change. | Rojo sync (SceneBuilder, LightingController, Scenes data) |
| 2 wet street | The road borrows ConcreteDark's colour map so it is no longer black. No mirror of the signs is possible. A brighter AsphaltWet needs a retexture and an upload. | Say yes to the retexture and upload if wanted |
| 3 sign light | 79 coloured spots from Tokyo's big signs, Tokyo lamp budget 12 (its check now passes) | Rojo sync |
| 4 contact darkness | `maps/contact.py` + `CONTACT_DARKNESS` in Agency, ON (the owner said yes): Agency is v33, so HQ is a grey box until the FBX is imported | Import `DeathsGambitMaps_Agency.fbx` v33 with the Rojo sync, then look at the bullpen |
| 5 air | `World/AirFx` (Tokyo haze, Campus halos and snow cones), `LampHaze` (HQ glass boost) | Rojo sync |
| 6 rim light | `World/RimLight` | Rojo sync |
| 7 notice | `World/QualityNotice` | Rojo sync |

Not done from the plan: HQ's monitor spill check and the Campus window spill lights (phase 3 steps 3 and 4), pendants
with a point light (interview rooms) as shadow lamps, a frame rate read on the owner's machine.
