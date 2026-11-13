---
name: export-restores-binaries
description: "A lights-only venue export still rewrites the venue's FBX, .blend, light-map PNG and ImportVersions.luau: git checkout those, commit only the Scenes data and scripts"
metadata:
  type: feedback
---

2026-11-13, exporting Agency, Campus and Tokyo for new lamps: the version in Scenes/<Venue>/init.luau did not move (so no
re-import), but `git status` showed art/export/DeathsGambitMaps_<Venue>.fbx (bytes differ, meshes the same), art/blend/
Maps_<Venue>.blend, art/export/previews/light_<Venue>.png (also by check_v2) and src/shared/ImportVersions.luau changed.
`git checkout --` all of them before committing. ImportVersions "ModelsFx = 2 -> 3" comes from export.py's own table
(VERSIONS, ModelsFx 3) disagreeing with the committed file: not ours to bump without the Fx import. Keep only the
Scenes data (Dressing/init.luau and the stats line of init.luau) and the scripts. The three exports took 1 to 3 minutes.
