---
name: core43-campus36-import
description: "Models Core v43 and Maps Campus v36 imported into the place by Open Cloud (2026-11-26): asset ids, alignment per file, place v653 saved not published"
metadata:
  type: project
---

**IMPORTED 2026-11-26 (place saved v653, not published)**, by the route in [[imports-by-open-cloud]] from the main checkout, nothing refused.

- `art/export/DeathsGambitModels_Core.fbx` (16,306,428 bytes), display name `DeathsGambitModels_Core_v43`: asset **138679793350371**, marker `DeathsGambitModelsCore_Version_43` (replaces v42), 187 MeshParts, 116 SurfaceAppearances, 303 descendants after the PackageLink went. Raw import came in turned about -178.5 degrees at (126.3, 40.3, 4063.8); put back with `PivotTo(CFrame.new(old pivot position))` (no rotation), so Calib_PropsCore_O (75.19, -27.57, 88.40) and _X (+64 in x), _Y (+64 in y) read as v42's did.
- `art/export/DeathsGambitMaps_Campus.fbx` (17,935,548 bytes), `DeathsGambitMaps_Campus_v36`: asset **95829169651247**, marker `DeathsGambitMapsCampus_Version_36` (replaces v35), 383 descendants. Maps keep their turn: the new import had the same rotation as the old model, so `PivotTo(old model's pivot)` put Calib_Campus_O at (75.19, 1745.73, 88.40) and X/Y cubes exactly where v35's were (X at (11.21, ., 90.07)).
- Both named `DeathsGambitModels_Core` / `DeathsGambitMaps_Campus`, parent Workspace, old ones destroyed, nothing left in ServerStorage, no duplicates in Workspace.
- Shared with universe 10767766818 (Use, grantToDependencies): `successAssetIds [138679793350371, 95829169651247]`, no errors.
- The place's Campus was v35 before (a v35 place does not build as a grey box; only the repo's constant 36 does until the import). The new science-hall exit sign (x 53, z 37.6, y 10.4 in map units) is merged into a mesh, so it cannot be found by name; checked by version marker only. Not seen by eye, no play test run.
- Place state after: Core 43, Campus 36 (others as in ImportVersions.luau). Scripts were not touched.
