---
name: lighting-rework-2026-11
description: Owner's lighting decisions (2026-11-01) - cinematic noir, fewer lights, stable shadow keys, window-only lightning, ceiling fittings on room-aligned layouts; HQ first
metadata:
  type: project
---

The owner's lighting rework, decided 2026-11-01 after a grilling round. HQ (Agency) goes first; the owner checks it in a
Studio play test before the same rules go to Campus, Tokyo, the lobby and the meeting room.

Complaints that started it: lamps pop and shadows jump as you walk; a lamp you walked near and turned away from goes
out and never comes back; lighting looks cheap; there is no shading.

Decisions:
- Look: cinematic noir. Pools of light with dark but readable gaps (a silhouette always shows, a face up close
  reads); only a blackout goes near black. Colours per map: HQ amber pools over blue-grey shadow, Campus warm over
  snow blue, Tokyo neon over blue.
- Fewer, better lights: one light per fitting, at its face; a light budget per room. Shadow keys picked per room and
  held (no reshuffle as you walk). Shadow quality setting Low / Normal / High = 2 / 6 / 8 keys.
- Effects: depth of field (setting Off / Subtle / Cinematic; Subtle = far blur only in play, stronger in cutscenes and
  meetings), film grain (setting on/off; subtle in play, heavier in meetings, the vote and blackouts), a grade per
  map, baked contact darkness under furniture.
- Lightning: a real moonlight burst through each outside window, fading with distance into the next room. Away from a
  big outside window: no flash at all, only the thunder's thud and the room's lamps flickering.
- Fittings: one type per ceiling, by room (panels for offices, bullpen, canteen; tubes for archive, lockup, servers;
  one bare hanging lamp over an interview table; downlights or pendants for lobby, atrium, ops), aligned to the
  room's long axis, lamps over what matters (desks, stations, doors) with darker walkways between. A few dead
  fittings on a deliberate pattern (a row, a corridor's far end), some flickering. Emergency lights are red beacons
  over doors, never bars on the ceiling panels. Screen and rack glow sits at the screen. Campus: fix the 4 odd lamp
  posts and turn all 48 along their paths.

**Why:** the "turn away and it never comes back" bug is Roblox's engine dropping lights where too many overlap (up to
15 range spheres on one point in HQ before this), made worse by LightingController moving the shadow keys every
40 studs.
**How to apply:** never stack lights or add a light with no fitting; keep any point at eye height within the venue's
lamp_budget (lamps on the floor below count: Roblox lights leak through slabs); place ceiling lamps with lightbook's shared placer, not hand lists. Related:
[[map-remake-project]], [[maps-not-symmetrical]].

Status 2026-11-01: HQ done in code and exported (Maps Agency v25), not yet seen in a Studio play test. What exists:
- Client: World/PostFx (depth of field, film grain), World/Lightning (window bursts from colliders whose Look is
  CurtainGlass; add a map's outside-glass look to WINDOW_LOOKS when rolling it out), LightingController keys held
  (KEY_HOLD, other floors scored further), settings shadowQuality / depthOfField / filmGrain.
- Generator: lightbook.grid/snap/long_rot/reach, agency fit.ceiling_lights (kind, over, dead, flicker) and
  fit.beacon (emergency over doors), kit.tube_light on/flicker, kit.pendant lit=False for a cluster's extra shades.
- Check: check_v2 "lamps" (stacked lamps under 3 studs, eye-height overlap over CHECKS["lamp_budget"]); HQ budget 12,
  now at most 10 (was 15), 123 lit lamps (was 135). Run it with Blender's Python:
  "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/maps/check_v2.py Agency
- Not done yet: baked contact darkness under furniture; Campus/Tokyo/lobby/meeting rollout.
- Trap (2026-11-01): any venue export that changes its meshes bumps the scene version; until the owner imports the
  new DeathsGambitMaps_<Venue>.fbx (removing the old one), the game builds that venue as a GREYBOX (colliders shown as
  boxes, mesh-only walls missing, the void showing). The owner read that as "you broke the map". Say so loudly with
  every export, with the FBX name and version.
- 2026-11-01: World/LampHaze adds soft beam shafts and dust under ceiling lamps (indoor "atmosphere": Roblox's
  Atmosphere shows nothing at room distances). Campus lamp posts moved off the paths (grounds.py lamp(), rot along).
- ROOT CAUSE of "walk near a lamp and it turns off" (found 2026-11-01): LightingController gives the nearest lamps
  Shadows = true, and a lamp whose light sits inside a mesh (a desk lamp's bulb in its shade, a panel light in its
  glow face, a pendant's bulb) is then blacked out by its own fitting. Fix: only lamps marked clear (mesher light
  clear=True -> export "clear = true" -> SceneBuilder attribute LShadowOk) or built with shadows may become keys.
  Every new fitting must put its light clear of its own mesh and pass clear=True, or it never casts shadows.
- 2026-11-01, later: even lamps placed clear of every mesh went dark in HQ when given shadows at runtime, while the
  other maps (no lamp given shadows) kept theirs. LightingController now gives runtime shadows only to lamps BUILT
  with Shadows = true (the meeting rig); the Shadows setting row is gone from the panel (the setting key is unused).
  The engine reason is not known; don't re-enable runtime lamp shadows without testing in Studio first.
- 2026-11-02, seen live through Studio MCP: Studio's PLAY-test quality (settings().Rendering.QualityLevel) was
  Automatic (the owner had only set Edit Quality Level to 21). On it the client fell back to voxel lighting: a bright
  probe PointLight lit the floor in coarse 4-stud blocks, ceiling lamps lit only the ceiling, no pools anywhere, so
  "lamps vanish" and "no shaders" were mostly the quality level. Judge the look only at QualityLevel 21. Studio in
  the background also throttles to ~15 fps, so fps read through MCP is not the game's.
- The place's Lighting held stock effects (Atmosphere, Bloom, DepthOfField, SunRays) beside ours; LightingController
  now removes effects with Roblox's default names at start.
- 2026-11-02, the look tuned live (Studio MCP, play-test QualityLevel 21): what made HQ flat was the FILL, not the
  lamps. Ambient 44,49,66 lit every surface evenly; at 16,18,28 (env diffuse 0.12) the rooms go dark and the lamps
  carve pools. Round ceiling lamps 13 studs up put ~1/6 of their light on the floor and lit the ceiling instead, so
  ceiling fittings are now lightbook.pool: a SpotLight down, 70 degrees, range 26, 5x the nominal brightness. Target
  frame: docs/hq-noir-look-2026-11-02.jpg. Captures through the MCP lag a frame or two and the lightning flashes vary
  them: change one thing at a time and compare.
- 2026-11-02 TRAP: screen_capture with camera_position/look_at_position renders a camera the engine does not light
  for (lamps missing, colour washed out): HQ and the University looked flat grey that way and lit properly through
  the player's real camera. Pin the real camera instead (BindToRenderStep at RenderPriority.Last + 50, Scriptable,
  set CFrame) and capture with no camera arguments. Also: the lobby pre-builds the next map, so clear every
  LGameMap before MapService.build in a test, or two maps overlap.
- Rollout 2026-11-02: lightbook.ceiling is now lightbook.pool for every map (POOL_ANGLE 80, POOL_RANGE 28, POOL_GAIN
  8.5). Presets retuned live through the real camera: HQ fill 22,24,36; Campus 24,27,38 (moon 0.6); Tokyo 26,24,40
  (moon 0.45, exposure 0.1; it was 80,72,102 at exposure 0.4); their Inside/Under zones lowered alike. CampusLamp's
  light 3.2 / 26 / 120 degrees (props_campus.py and ModelCatalog.luau). Lobby (Grey Realm) and meeting room not
  retuned: not looked at live.
- 2026-11-03: two LightingPresets specs have failed since this rollout, known and left alone: "keeps the rebuilt maps
  readable at night" (ambient 45 or brighter, the noir fills are about 26) and "never lets bloom catch lit skin"
  (bloomThreshold 1.8 or higher, TaskForceHQ's is 1.5). The first limit is simply out of date. The second needs a look
  by whoever owns HQ's bloom: check lit skin there before lowering the spec's limit.
  - 2026-11-06: the first is FIXED (7550c7fb): the brightest fill channel of HQ, Campus and Tokyo must sit between 32
    and 56 (28 read black, 66 read flat). A spec can be run without a play test: execute_luau in Edit, the spec's
    text in an unparented ModuleScript's Source, require it with a small describe/it/expect table.
  - 2026-11-06, the bloom one LOOKED AT (play test, QL21, real camera pinned): an R6 avatar in bare pale skin
    (255, 220, 190) under HQ's brightest pool (the staff locker room, b31 at 12 studs, drop 12.3) blooms hard at 1.5
    (edges and face washed out), still glows at 1.8, holds its edges at 2.0 and is as clean as bloom off at 2.2. The
    spec was right; HQ's preset is the outlier. At 2.2 HQ's reception keeps its look: only the soft halo on lit
    white surfaces (X-ray scanner, lift frames) goes, the downlights keep their glow. Campus and Tokyo (1.9) not looked
    at. A RobloxPlayerBeta left running with no window (its game closed) did not stop the captures.
  - 2026-11-06: the user picked 2.2: HQ's bloomThreshold is 2.2 (e5b191a7), intensity 0.7 and size 26 kept. In the
    place (synced by a one-shot plugin, see [[studio-no-screen]]) the LightingPresets spec runs 13 of 13.
- 2026-11-06, looked at live (Studio MCP, play-test QualityLevel 21, the place's own Studio parked off screen):
  - FIXED: ceiling pools went on through their own floor. Lamps cast no shadows, so a pool 13 studs up with range 28
    lit the storey below: HQ's 39F lamps lit 38F's ceiling, blew out its pillars and whiteboards, put a white halo on
    the security office's monitor bank and doubled the lamps on every point of 38F. `lightbook.stop_pools` (run by
    export.write_scene_v2 for venues with STOP_POOLS = True: Agency, Campus, Tokyo) cuts each pool to its floor + 1
    (the drop to an upward opaque face 7+ studs down that two of five rays, 3 studs apart, agree on: a desk under the
    lamp or a stairwell beside it does not count) and multiplies its brightness by up to 1.7, the measured match: a
    range-13 pool needs ~1.7x to light its floor like range 28 at 12 studs (Roblox's falloff is not physical; a lamp
    16 up lights its floor MORE than one 12 up). HQ's 38F pools get 1.4x more on top (agency L1_POOL_LIFT): the
    approved 38F look had been partly 39F's leak. 2.4 everywhere blew out Tokyo's tiled station hall. Lights do not
    bump a venue's version: this reaches the game by script sync alone. Sets, meeting room and lobby not opted in
    (not looked at with it).
  - Lobby (Grey Realm: bowl, grotto) and meeting room looked at live and left as they are: grey and readable, the war
    room warm with its chairs in silhouette. The lobby's dive fix (2be66fd7) could not be tried: the place's
    LobbyRift/DiveController were older than it (no ENTER_ABOVE, no busy), so scripts were not synced.
  - Still leaking, not fixed: prop lamps from the catalog (DeskLamp r13 on 39F reaches 38F's upper half).
  - FIXED the same day (the user: "brighten skies"): the night skies rendered BLACK at the noir exposure (even
    Roblox's default sky), so the far cities' towers vanished and their lit windows floated in nothing.
    skies.py now writes each graded sky LIFT times brighter in linear light: Tokyo 8, Campus 8, Agency 12 (its
    storm sky is graded darker). Picked in a play test by loading test faces from Studio's own content folder
    (rbxasset://textures/<folder>/..., written into %LOCALAPPDATA%\Roblox\Versions\<ver>\content\textures and
    deleted after): no upload needed to try a texture live. 4 was still near black, 16 lifted far facades.
  - Cold clinical rooms (HQ security, the Campus forensic lab) read flat and bright: white walls and tile under 80
    degree pools. A 60 degree cone gave real pools there in a live test; not changed (POOL_ANGLE is every map's).
  - Captures: Studio minimised draws no 3D (grey frames). Park its window off screen with SetWindowPos at
    (-1960, 0, 1920x1080, SWP_NOACTIVATE) and restore it after. The first capture after a move or change is often a
    frame stale, and lightning flashes wash frames white or blue: capture twice.
- 2026-11-12 (owner: "blindingly strong in most places, completely unlit in others; make maps distinct"): pools alone
  gave hard discs with black between. SceneBuilder now builds each ceiling pool on Agency/Campus/Tokyo softer
  (SOFT: 0.55x, at least 100 degrees, scaled down under low ceilings) with a "Bounce" PointLight low under it; the
  presets got more fill (within the spec's 32..56), contrast ~0.1 and a grade per map (HQ cool steel tint, Campus
  warm tint, Tokyo saturated violet, bloom 0.9). CampusLamp 3.2 -> 2.2. Tuned by emulating on a play-test client
  (not synced into the place, not committed at the time of writing). Tokyo's asphalt stays near black (its scan).
- 2026-11-12: the plan for what comes after the balance pass (shadows, wet street, coloured light, contact darkness, air, rim light, low-quality notice), written for another agent: docs/handoff/graphics-plan-2026-11-12.md
- 2026-11-13, the graphics plan (docs/handoff/graphics-plan-2026-11-12.md) carried out, phase by phase (pictures in
  docs/graphics-2026-11-13/):
  - Phase 1, shadows: ROOT CAUSE of the lamps going dark found: a shadow-casting spot within ~1 stud of the ceiling lights
    nothing (and a shadowed spot is ~3x dimmer than an unshadowed one): see [[shadow-lamps-ceiling-clearance]]. 20 pools
    in HQ, 12 on the Campus and a few in Tokyo (station hall, platform, arcade) are built to cast; the controller keys
    the nearest few. Version unchanged (lights only). Nearest 10 held 60 fps at QL21 here ([[studio-frame-rate-measure]]).
  - Phase 2, Tokyo's road: the road's colour map is near black (that is why no light showed on it; Reflectance and a
    polished roughness map changed nothing). SceneBuilder now lends it ConcreteDark's colour map (BORROWED_COLOUR): a
    dark violet-grey street with lamp sheen, no upload. It does NOT mirror the signs (Roblox has no reflections of
    lights). The proper fix, a brighter AsphaltWet in maps/scanlib.py (retexture + upload), is the owner's call.
  - Phase 3, light from signs: lightbook.sign_glow, 79 coloured spots out of Tokyo's big fascia signs and vertical signs
    (range 14 to 19, brightness 0.6 to 1.2, none above y 20, none within 9 studs of each other). Tokyo has a lamp
    budget now (12) and lightbook.unstack takes out stacked lamps at export (UNSTACK in the venue): its check_v2 was
    never run before and flagged 24 problems, all gone. HQ's monitor spills and Campus' window spill were not added.
  - Phase 4, contact darkness: maps/contact.py (stepped layers of the flat look ContactDark under furniture and along
    wall feet; 151 pieces and 168 walls in HQ, preview in docs/graphics-2026-11-13). OFF (Agency CONTACT_DARKNESS =
    False): it adds meshes, so Agency goes up a version and HQ is a grey box until the new FBX is imported, and it could
    not be looked at in the real place. Switch on, export, import, look at the bullpen.
  - Phase 5, air: World/AirFx (Tokyo neon haze round the signs' lights, Campus halos and snow cones at the lamp posts)
    and LampHaze (HQ shafts up to 1.8x stronger within 26 studs of the outside glass). Low quality off, Reduce motion
    keeps them still.
  - Phase 6, rim light: World/RimLight, a 0.4 / 6.5 PointLight past each other player's head, away from the camera,
    only while a ray from the camera reaches the head, off in a blackout, in Low quality and outside a map.
  - Phase 7: World/QualityNotice, one Kit.notice once per session in a map when the saved quality is Automatic or under 7.
  - Not in the place: none of these scripts or the new Scenes data are synced into the owner's place (a classifier
    blocks script writes into the shared place, [[studio-shared-place-write-blocked]]): the owner's Rojo sync does it.
