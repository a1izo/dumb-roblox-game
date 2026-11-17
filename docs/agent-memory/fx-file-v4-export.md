---
name: fx-file-v4-export
description: "How the Fx props file (ModelsFx 4, 2026-11-17) is exported and checked: meshes.py alone, the version in two places, check_fx_export.py, the budget exception, the old-name fallbacks, what is not in it"
metadata:
  type: reference
---

The Fx props file (`art/export/DeathsGambitModels_Fx.fbx`) is built by `blender -b --factory-startup --python
art/scripts/vfx/meshes.py` (7 seconds) and nothing else: it does not read Props.blend, writes no ModelCatalog and
touches no other set, so an Fx export leaves Core and Props.blend alone. Its carrier quads are the names in
`meshes.TEXTURES`, each read from `art/export/textures/<name>.png` and embedded byte for byte; a new texture is carried
only when its name is added to that list. The version is bumped by hand in TWO places before the export (the marker
mesh reads it): `art/scripts/maps/export.py` VERSION and `src/shared/ImportVersions.luau`.

Check it with `blender -b --factory-startup --python art/scripts/vfx/check_fx_export.py -- [--old-fbx PATH]` (PATH from
`git show <rev>:art/export/DeathsGambitModels_Fx.fbx` into a file): every PNG embedded byte for byte, old pictures equal
to the old file's, every carrier and shape present with UVs inside 0..1, the version marker, the calibration cubes.

`Vfx/Tex.luau` `Tex.FALLBACK` maps each new texture name to the old one it wears while the place has an older Fx file;
add a line there for every name you add to `meshes.TEXTURES` (spec VfxTex.spec lists the new names).

Costs: the Fx file counts in the budget of EVERY scene (scripts/budget.py), so 22 new 1024 px sheets cost 23 megapixels
and 11 megabytes in each (a recorded exception in `art/budget.json`), and `MapPreloader` fetches every Fx carrier on a
join, phones included. Campus was already over its megapixels by 0.11 before then. V1.2's fire sheets were not on main
on 2026-11-17: the next Fx bump must again be one export with ModelsFx raised in both places.

**Why:** the plan bumps the Fx file once, at the end of Stage 1, so the owner imports once. **How to apply:** do not
run `run_props.py --export --set Fx` (it writes an empty Fx file). Related: [[vfx-rework-plan-2026-11]],
[[vfx-mesh-uv-rule]], [[export-restores-binaries]], [[imports-by-open-cloud]].
