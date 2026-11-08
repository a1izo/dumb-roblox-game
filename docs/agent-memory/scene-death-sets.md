---
name: scene-death-sets
description: The scene deaths' sets are Blender-modelled (venue Scenes, its own FBX, built on the client per scene, one 1000-stud cell each), lit by LightingPresets.scenes; how they load, the traps found testing them in the real place
---

Asked 2026-11-08 ("why are the scenarios so low quality?"): the nine scene deaths' sets were ctx:part boxes. Now:

- **Venue `Scenes`** (`art/scripts/maps/venues/scenes`, `run_maps.py -- Scenes --export`): one set per scene in its own
  cell 1000 studs along X (`plan.py`: patriot 0, blackwall 1, walrider 2, sam 3, ironman 4, selection 5), each drawn
  in its scene's own space (y up, origin where the scene's first actor stands). `GROUP` keeps every mesh inside one
  cell (mesher `Scene.group`). Helpers in `parts.py`: height fields with skirts, lumpy rocks, grass tufts, bare trees
  (bent_tube), bevelled arched headstones, extrusions (tessellated), a saloon car. New surfaces in
  `maps/scenesurf.py` (a meadow drawn blade by blade, graded scans). Skies: `art/scripts/scene_skies.py` draws five
  cube skies (Mist, Dusk, Ember, Requiem, God) carried on `Tex_` quads.
- **Data goes to `src/shared/Scenes`** (module `DATA_DIR`), not the server: no server builds this venue. Generated,
  so it is in `.styluaignore`. `write_versions` reads it too (`MapsScenes`).
- **Client build**: `SceneDeaths/Sets.luau` clones the cell's meshes from the store (calibrated like SceneBuilder),
  dresses them by SceneMaterials, places its lamps/props/signs; `ctx:set()` in a scene; without the import the scene
  builds its old part set (`standIn`). Void scenes skip their box when `ctx:imported()`.
- **Light**: `LightingPresets.scenes[name]` via `LightingController.scene(name)` while a scene plays (it used to get
  whatever map look the far-off camera fell in). Scene looks aim the sun with a fine search (`aimSun(aim, true)`):
  the venues' four-hour search put a dusk sun on the horizon (black desert). Venue looks keep the coarse search.
- **Traps seen in the real place (play test by MCP)**: (1) the engine lights a place a moment after the camera jumps
  there: every scene played from its start opens on black for ~0.75 s; (2) first use downloads meshes and sky
  textures: the join preloader covers the store, but a test right after an import shows pop-in; (3) MCP
  `execute_luau` modules are a separate VM copy (LightingController uninitialised) and it resets a Scriptable camera
  after any call that changed it: drive scenes from an injected LocalScript in PlayerGui listening to an attribute,
  and screenshot the play viewport with computer-use (MCP `screen_capture` only sees the edit view); (4) stylua
  reformats generated data unless ignored, which breaks hash-checked syncs.
- **Script sync without Rojo or a second Studio**: hash-checked patches by byte offset through MCP `execute_luau`
  (Edit) in the user's open Studio (scratchpad patch_mcp.py pattern: per file, old hash, ops applied end to start,
  new hash checked before `UpdateSourceAsync`).

Related: [[deaths-batch2]], [[studio-no-screen]], [[mesh-triangle-limit]].
