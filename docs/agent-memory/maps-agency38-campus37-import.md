---
name: maps-agency38-campus37-import
description: "Maps Agency v38 and Maps Campus v37 imported by Open Cloud (2026-11-26, place v657 saved, not published) and what the phase 12 wear marks, pipes and notices look like in Roblox"
metadata:
  type: project
---

**IMPORTED 2026-11-26 (place saved v657, not published)** from the main checkout's `art/export`, by the route in [[imports-by-open-cloud]] and [[core43-campus36-import]], nothing refused.

- `DeathsGambitMaps_Agency.fbx` (12,868,156 bytes), display name `DeathsGambitMaps_Agency_v38`: asset **120589437467503**, operation eb18363a-58dd-402d-89c1-38ecc4973ef5, Approved, marker `DeathsGambitMapsAgency_Version_38`, 545 descendants after the PackageLink went. `PivotTo(old pivot)` put Calib_Agency_O at (75.19, 699.64, 88.40) and X/Y exactly where v37's were.
- `DeathsGambitMaps_Campus.fbx` (17,992,172 bytes), `DeathsGambitMaps_Campus_v37`: asset **72746878782513**, operation db886ab7-97e8-4191-a23d-699cd25e7282, Approved, marker `DeathsGambitMapsCampus_Version_37`, 384 descendants; O (75.19, 1745.73, 88.40), X/Y exact.
- Old models destroyed, one of each in Workspace, nothing left in ServerStorage; shared with universe 10767766818 (`successAssetIds [120589437467503, 72746878782513]`, no errors). The scripts of the place already equalled main (Pilot, Fire, IronMan, WinCuts, ImportVersions, SceneMaterials hashed the same as the repo), ImportVersions says MapsAgency 38, MapsCampus 37.
- Open Cloud shape again: `files [{name:"fileContent", path, contentType:"model/fbx"}]`, body `{"request":"<json string>"}`; PATCH permissions body `{requests:[{assetId (number), grantToDependencies:true}], subjectType:"Universe", subjectId:"10767766818", action:"Use"}`.

**Pictures with no screen control (Edit mode, 2026-11-26):** `screen_capture` with an explicit `camera_position` / `look_at_position` works in the existing Edit-mode Studio with 3D showing (no foreground trick needed this time; about 1 call in 4 answers "Request timeout", just repeat it). Plan coordinates to world: `O + ex*x + (-0.0261, 0, -0.99966)*z + (0, h, 0)` where O is the venue's Calib_<V>_O cube and ex = (X - O)/64 (Agency and Campus share the turn); floor h = 0 is O.y. Edit mode has no scene lights, so the maps read dark blue; Lighting Ambient/OutdoorAmbient raised to 0.8 and ExposureCompensation 0.6 for the shots, then put back (0, 0.27451, 0). Where the wear quads are: import the FBX in Blender (`import_scene.fbx`, x_b = -plan x, y_b = plan z, z_b = height) and print the `Map_Agency_WearOffice_1` faces; `CreateEditableMeshFromPartAsync` does not exist in execute_luau.

**What they look like in Roblox (HQ security office, interview hall, copy room, University forensic lab):**
- Notices sit flat on the wall, none floating, no z-fight seen; the AgencyNotes sheet reads (fire notice, roster, QUIET sign), the campus box-built fire notice reads as a notice. Wall clocks fine. Pipes hang at the ceiling with clamps and collars, nothing crossing a window or door.
- Scuff and grime marks are faint soft mottling on the tan and grey walls (read as dirt, do not repeat noticeably) and invisible on a dark dado (dark on dark: wasted, harmless).
- The stain under a pipe collar renders as a thin black hairline starting about half a stud below the collar; its soft grey halo is not visible, so it reads as a drip or crack, not a damp stain. Left as is (a sheet redraw plus two re-imports for a hairline).
- The pipe's Steel material is a lumpy white-grey marble look at close range (close shot `roblox_agency_copy_pipe_stain_close.jpg`); a smoother pipe material or a larger UV scale would suit.
- Not shot: the University clock (timed out) and the Agency's 39F rooms. Pictures in `art/export/previews/graphics-2026-11-26/roblox_*.jpg` (untracked).
