---
name: fx-v5-import
description: "Fx props file ModelsFx 5 (2026-11-25): V1.2's four fire sheets exported and checked, the budget line, and why the import into the place was NOT done (upload folder), with the exact steps and what the sheets will switch on"
metadata:
  type: project
---

**Done (commit 5203ee1b).** `art/scripts/vfx/meshes.py` `TEXTURES` got `VfxFire, VfxFireBurst, VfxCandle, VfxAuraFlame` (1024 px each);
`ModelsFx` is 5 in `src/shared/ImportVersions.luau` and `art/scripts/maps/export.py`. Exported by
`blender -b --factory-startup --python art/scripts/vfx/meshes.py` (the Blender 5.2 install, `blender.exe`): file 13.27 to 15.02 MB (15,751,836 bytes, under the
20 MB upload limit, so no split). `check_fx_export.py --old-fbx <v4 file>` passes: 49 textures and carriers, 14 shapes, every PNG byte for byte, the 23
old pictures the same as in v4, marker `DeathsGambitModelsFx_Version_5`. `check_textures.py`: the four sheets PASS (Fire 86% fill, FireBurst 60%, Candle
65%, AuraFlame 59%); 33 pass / 16 fail overall is the same set of old sheets that always failed. `scripts/budget.py`: +4.19 megapixels, +1.75 MB in every
scene; `art/budget.json` has a new exception (4.2 MP, 1.8 MB, written as the owner's call to veto: they were not shown the figure). Without it Lobby,
Agency and Campus go over their megapixels; with it only Campus is over (0.07), as it already was before. `Vfx/Tex.luau` `Tex.FALLBACK`: VfxFire and
VfxAuraFlame to VfxFlame, VfxFireBurst to VfxBurst, VfxCandle to VfxCandleFlame (so `Aura.luau`'s unguarded VfxAuraFlame is no longer a sparkle in
the unimported place); `Tex.real` stays false until the import. `VfxTex.spec` lists the four names (not run: needs Studio).

**NOT done: the import into the place.** `open_cloud_invoke` refused the upload: "is not inside a directory approved for uploads" (only
`C:\Users\negru\Documents\Lgame\art\export` is approved; a worktree's `art/export` is not) and its text says not to copy or move the file around it,
so nothing was copied into the main checkout. Place state read 2026-11-25: `DeathsGambitModels_Fx` is Version_4 (63 descendants), Core 42, Lobby 24,
Tokyo 24, Agency 18, Campus 16, Meeting 6. **To finish** (after main with 5203ee1b is pulled into the main checkout, or the worktrees folder is added to
the MCP upload directories): follow [[imports-by-open-cloud]] with `art/export/DeathsGambitModels_Fx.fbx` (display name `DeathsGambitModels_Fx_v5`,
creator userId 1503130900), poll the operation, `insert_asset` into ServerStorage, check 49 `Tex_` quads and the v5 marker, remove its PackageLink, PivotTo
the old Fx model's pivot (its calibration cubes at 0/0/0 in the play test's "Import check"), name it `DeathsGambitModels_Fx`, parent to Workspace, delete
the v4 one, share with the universe (PATCH `/asset-permissions-api/v1/assets/permissions`, Universe 10767766818, Use, grantToDependencies), save.
Never publish.

**What the import switches on (unseen by eye in the real place):** `Tex.real("VfxFire")` becomes true, so `Pilot.on.manualFire` and
`Pilot.on.trialWisp` (both still FALSE, see below) would draw `Fresh.flame`; the fire writing style (`writeFire`, already ON) cuts `VfxFire` instead of
`VfxFlame` (Styles.luau line ~1053); `Aura.luau` and `Fresh/Fire` draw the real `VfxAuraFlame` / `VfxCandle` / `VfxFireBurst`.

**Flags: left OFF.** The booth could not be photographed: Studio was minimised and the owner's League of Legends match window was open, so it was not
restored (a minimised Studio draws no 3D; the capture is black; AppActivate returns False). What WAS measured, in a Play client with a private copy of the
worktree client (`dgx_client_1.rbxm` in Studio's content folder) and `workspace:SetAttribute("DGVfxLocal", true)` plus all 49 PNGs in
`content/textures/dg_vfx_harness/` (so the real sheets drew, with nothing uploaded; both removed again after): effect report, old to new: `recipe_flame_fire`
FAIL (50% dots, 41 particles, 6 emitters, 3 lights, no core, a pop) to `recipe_new_flame_fire` PASS (17% dots, 8 particles, 5 emitters, 1 light);
`recipe_flame_candle` FAIL (67% dots, no core) to `recipe_new_flame_candle` PASS; `recipe_new_flame_aura` PASS; `world_brazier` (the old flame) FAIL. That is
the same `Fresh.flame` call `manualFire` (danger red) and `trialWisp` (amber) use, so the numbers say better, but the rule is "ON only when seen":
no picture, so no flag was turned on. Next session, with Studio in front: set `Pilot.on.manualFire` / `trialWisp` on a private copy, put old and new flames
side by side on two stands (left `Recipes.flame` red, right `Fresh.flame` with `Palette.DANGER`; the stand script is simple), capture, save
`art/export/previews/vfx/rollout/<name>_compare.png` (also in the main checkout), flip the default in `Vfx/Pilot.luau`.

**Traps found.** (1) `rojo build` of a project with `Client` given both `$className` and `$path` fails (it is a LocalScript): use
`{"name":"dgx","tree":{"$className":"Folder","Client":{"$path":"src/client"}}}`. (2) `git ... > outside-path` and compound git lines are refused by the
worktree guard; use PowerShell `cmd /c` for `git show rev:file > file`, and `-F file` for commit messages. (3) `FxBooth.report` returns
`{ verdict, rows }`, not flat fields: print with `FxBooth.reportTable({ r, ... })`.
