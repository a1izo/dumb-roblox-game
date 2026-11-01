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
