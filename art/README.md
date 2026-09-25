# Inkbound art (Blender)

Everything here is made by the Python scripts in `art/scripts`, so it can be rebuilt, changed
and re-exported at any time. Blender 5.2 (any recent 4.x+ should work). 1 Blender unit = 1 stud.

| Folder | What it holds |
| --- | --- |
| `scripts/` | The build scripts (run with Blender, see below) |
| `scripts/maps/` | The map scenes: texture library, geometry kit, one script per venue |
| `data/r15_rig.json` | Roblox's own R15 rig (joints and part sizes), from `r15_extract.py` |
| `blend/Animations.blend` | The R15 rig with every animation as an action (open it to tweak curves) |
| `blend/Props.blend` | Every prop, baked |
| `blend/Maps.blend` | The five map scenes |
| `export/InkboundModels.fbx` | All props and effect textures (Studio import #1) |
| `export/InkboundMaps.fbx` | The map scenes with their tiling textures (Studio import #2) |
| `export/textures/` | Baked prop textures, effect textures, and `maps/` (tiling colour, normal and roughness maps) |
| `export/previews/` | Renders of every pose, prop and map, for review |

## The two imports in Studio

Meshes and images must be uploaded under your account, which only Studio can do. For each of
`art/export/InkboundModels.fbx` and `art/export/InkboundMaps.fbx`:

1. **Home > Import 3D** (or File > Import 3D), pick the file, keep the defaults, press **Import**.
2. That's it. The importer drops the model into Workspace; when the game starts, the server
   moves every `Inkbound...` import into **ReplicatedStorage > InkboundAssets** and prints what
   it found in the Output ("Blender models: 33 of 33 found."). You can also drag them there
   yourself, which keeps the editor view clean.

Importing a newer version: delete the old imported model first (the game uses the first one it
finds with a given name).

Nothing breaks before an import: props fall back to their part-built versions and each venue
builds its old part-made map.

## Animations: no upload needed

`gait.py` generates the movement clips (idle, walk, run, land) with leg IK on the real R15 rig:
planted feet move back exactly as fast as the body moves, and each clip exports its stride so
the game advances the cycle by distance (scaled to each avatar's leg length). `anims.py` keys
the other animations in the game's joint convention; `posekit.py` keeps feet planted when the
hips move and fits poses that end on the ground to the floor. `export_anims.py` writes
`src/shared/Anim/Clips.luau`, which the game plays on every character itself.

```
blender -b --factory-startup --python art/scripts/run_anims.py            # rebuild and export
blender -b --factory-startup --python art/scripts/review_anims.py -- out.png 30 run:0 run:0.1
blender -b --factory-startup --python art/scripts/verify_ingame.py        # Blender rig vs game maths
```

`verify_ingame.py` poses a real R15 body from `Clips.luau` with the same maths as the game
(`rbxsim.py`), next to the Blender rig, so export mistakes show up as two different poses.

## Map scenes

Each venue (`scripts/maps/venues/lobby.py`, `meeting.py`, `agency.py`, `campus.py`,
`tokyo.py`) builds its architecture from the kit (`kit.py`, `urban.py`) on the same layout as
the Luau map module, so stations, spawns, sheets, drop points and hoods keep their places.

```
blender -b --factory-startup --python art/scripts/run_maps.py -- --preview            # renders
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --preview      # one venue
blender -b --factory-startup --python art/scripts/run_maps.py -- --export             # all venues
python art/scripts/maps/contract_check.py                                             # gameplay checks
```

`--export` writes:
- `export/InkboundMaps.fbx`: meshes named `Scene_<Venue>_<Material>_<n>` (one material per
  mesh, textures tiling in world space) plus three calibration cubes (`Calib_Maps_O/X/Y`) the
  game uses to undo any scale or rotation the importer applied.
- `src/server/Maps/Scenes/<Venue>.luau`: invisible colliders (walls, furniture, roofs; windows
  block sight lines like the solid walls they replaced), props from the prop library, lights,
  signs and particle emitters.
- `src/shared/SceneMaterials.luau`: colours for the flat materials (metal, glass, neon...).

`contract_check.py` tests the exported colliders and props against each map's `layout()`: desks
clear, worker spots free, screens visible from at least 3 of 8 sides, sheets resting on a
surface, spawns, hoods and drop points not inside anything. Run it after changing a venue.

## Props and textures

```
blender -b --factory-startup --python art/scripts/run_props.py            # build and bake all
blender -b --factory-startup --python art/scripts/run_props.py -- Desk    # just one
blender -b --factory-startup --python art/scripts/run_textures.py         # effect textures
blender -b --factory-startup --python art/scripts/run_props.py -- --export  # FBX + catalog
```

`--export` writes `export/InkboundModels.fbx` and `src/shared/ModelCatalog.luau` (each prop's
size in studs, pivot, material and glow colours). `ModelLibrary` fixes scale and orientation
from the catalog, so the importer's unit and axis settings do not matter.

Effect textures ride along on small quads named `Tex_<name>`. If you would rather upload the
PNGs yourself, paste their ids into `Assets.textures` in `src/shared/Assets.luau`.

## Adding a prop

1. Add a builder to `scripts/props.py` or `scripts/props_world.py` with `@prop("Name", ...)`,
   facing -Y, standing on z = 0 (for `pivot="bottom"`). Glowing parts go in the second list.
2. Rebuild and export as above, then re-import the FBX in Studio.
3. Place it from a map with `b:placeModel("Name", x, z, rot)`, or from a scene with
   `s.prop("Name", x, z, rot)`.
