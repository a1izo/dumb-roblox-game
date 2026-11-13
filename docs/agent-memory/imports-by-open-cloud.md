---
name: imports-by-open-cloud
description: "Imports and script syncs with no screen and no importer (2026-11-11): Open Cloud uploads through the Studio MCP, insert, line up, share with the universe; scripts as an rbxm model"
metadata:
  type: reference
---

Done 2026-11-11 in the user's open Studio (place 130650608236392, universe 10767766818), all through the Studio MCP,
nothing on their screen. Their MCP Permissions (Assistant > ... > Settings > MCP Permissions) must allow **Publish &
manage assets** and list `C:\Users\negru\Documents\Lgame\art\export` under **Open Cloud upload directories** (Save at
the bottom). The HTTP allow list did NOT work for 127.0.0.1 even when saved: don't plan on fetching from localhost.

**An FBX import:** `open_cloud_invoke` POST `/assets/v1/assets` (assetType Model, creator userId 1503130900 =
Kenshi_89, the signed-in user; file in art/export, 20 MB max each), poll `/assets/v1/operations/<id>`, then
`insert_asset` into ServerStorage, check it (meshes, SurfaceAppearances, marker), remove its PackageLink, PivotTo the
old import's pivot, rename to the importer's name, parent to Workspace, delete the old version. Checked against the
importer on the same file (Agency props v18): all 89 meshes identical in place, turn and size relative to the
calibration cubes, so ModelLibrary treats both alike.
**Then share them with the game:** PATCH `/asset-permissions-api/v1/assets/permissions` with subjectType Universe,
subjectId 10767766818, action Use, requests [{assetId, grantToDependencies = true}] for every uploaded model. The
uploads belong to Kenshi_89, the game to realALEXTEM.
**Over 20 MB:** `run_maps.py <Venue> --export --split N` writes DeathsGambitMaps_<Venue>_A..: A has the venue's marker,
B.. markers of their own kind (Maps<Venue>B...), all carry the calibration cubes; after inserting, translate each part
so its Calib_<Venue>_O sits on A's (or the old import's). Scenes v7 went in as 4 parts of ~16 MB.
**Scripts:** `rojo build` a project whose root Folder maps Shared/Server/Client/DGCover/Animate to src, upload the .rbxm as
a Model, insert into ServerStorage (scripts there don't run), copy each Source into the place's twin with
ScriptEditorService:UpdateSourceAsync (create the missing, skip Shared.Assets), destroy the model. Classify first:
print every place script's hash to the Studio log ([DGHASH]) and compare with the repo's history (anything not from
the repo is someone's live work: skip it).

Traps: a play test is needed to prove it (start_stop_play; specs print in get_console_output); execute_luau in the
Client datamodel runs in its own Lua VM (requiring a game module gives a fresh copy, not the game's); screen_capture
showed no 3D at all in this Studio; never call ModelLibrary.install() at run time (it gathers "imports" from
Workspace and took the built lobby once). Related: [[studio-no-screen]], [[studio-mcp]].

2026-11-13: the Scenes venue's export is not deterministic (its version goes up on every run, a few vertices move by a
thousandth: the sculpted angel's modifiers). Export it ONCE with `--split 4` and upload those parts; the whole
DeathsGambitMaps_Scenes.fbx in git is older than the parts (they are too big to commit). Tokyo's map is over 20 MB
too: `--split 2`. `run_props.py --export --set Fx` writes an EMPTY Fx file: the Fx set is built by
`art/scripts/vfx/textures.py` then `art/scripts/vfx/meshes.py`.
