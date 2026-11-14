---
name: bounce-lights-are-the-flat-wash
description: "The flat even look of Agency and Campus rooms came from the SceneBuilder Bounce lights, not the fill: how it was found (2026-11-14), the per-room fix (FILL_ROOMS), and Studio MCP traps hit"
metadata:
  type: project
---

Graphics plan phase 11 (2026-11-14). Every ceiling pool on Agency, Campus and Tokyo gets a round shadowless "Bounce" PointLight
(an Attachment named Bounce under its Light part, range up to 20) from SceneBuilder.SOFT (the 2026-11-12 balance pass). Test
that found it, University science hall at Quality 21: all lights off + ambient, EnvironmentDiffuseScale and Lighting.Brightness
zeroed = black; ambient/env/brightness zeroed with the lights on = no visible change; only the 38 Bounce lights at 25% = pools,
falloff, dark foreground (mean luminance 0.434 to 0.277). They also lit the next room through walls (range 20, no shadows).

**Why it matters:** if a room reads flat, look at the Bounce lights first, not LightingPresets (the spec holds the ambient to
32..56 and it is not the source anyway). **How to apply:** per-room control lives in the venue's `FILL_ROOMS`
(`(x0, z0, x1, z1, y0, y1, factor)`, agency/__init__.py, campus/__init__.py), read by lightbook.fit_fill at export; ranges are
kept to the room automatically (median wall distance x 1.25). A factor inferred from the room's shape was tried and failed
(neighbouring pools of one hall got 0.38 to 0.89), so it is chosen by hand. HQ's sergeant's office 0.4, the science hall 0.3.

Traps met the same day: a lights-only export that crashes in write_scene_v2 AFTER `shutil.rmtree(folder)` leaves the venue's
Scenes folder deleted (git checkout it); the Studio play test can end by itself when the connection drops (the Client/Server
datamodels then say "not available in Edit mode": start play again); Studio un-parks itself to minimised (re-park, see
[[lighting-sweep-2026-11]]); a Rojo `serve` was running and synced SceneBuilder.luau into the place within minutes but NOT the
regenerated Dressing data, so check the place's `.Source` before judging an export; `execute_luau` cannot read
`Lighting.Technology` (lacking RobloxScript capability). Related: [[lighting-rework-2026-11]], [[graphics-references-2026-11]].
