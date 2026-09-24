# Inkbound art (Blender)

Everything here is made by the Python scripts in `art/scripts`, so it can be rebuilt, changed
and re-exported at any time. Blender 5.2 (any recent 4.x+ should work). 1 Blender unit = 1 stud.

| Folder | What it holds |
| --- | --- |
| `scripts/` | The build scripts (run with Blender, see below) |
| `blend/Animations.blend` | The R15 rig with every animation as an action (open it to tweak curves) |
| `blend/Props.blend` | Every prop, baked |
| `export/InkboundModels.fbx` | All props and effect textures, for the one-time Studio import |
| `export/textures/` | Baked prop textures and the effect textures (ink splats, rain, smoke...) |
| `export/previews/` | Renders of every pose and prop, for review |

## Animations: no upload needed

`anims.py` keys 28 animations on an R15 rig (`rig.py`) in the game's joint convention, with
snappy, overshooting timing in the spirit of Ink Game. `export_anims.py` samples them and writes
`src/shared/Anim/Clips.luau`, which the game plays on every character itself (no animation
uploads). To change an animation:

1. Edit the keys in `art/scripts/anims.py` (or open `blend/Animations.blend`, edit the action,
   save), then run in Blender's Python console or with the MCP add-on:

   ```python
   import sys; sys.path.insert(0, r"<repo>/art/scripts")
   import rig, anims, export_anims
   arm = bpy.data.objects["R15"]
   anims.build(arm)          # skip this line if you edited the actions by hand
   export_anims.export(arm)
   ```

2. Rojo syncs the new `Clips.luau` straight into the game.

## Props and textures: one import in Studio

Rebuild (optional, takes about 2 minutes):

```
blender -b --factory-startup --python art/scripts/run_props.py            # build and bake all
blender -b --factory-startup --python art/scripts/run_props.py -- Desk    # just one
blender -b --factory-startup --python art/scripts/run_textures.py         # effect textures
blender -b --factory-startup --python art/scripts/run_props.py -- --export  # FBX + catalog
```

`--export` writes `export/InkboundModels.fbx` and `src/shared/ModelCatalog.luau` (each prop's
size in studs, pivot, material and glow colours).

Meshes and images must be uploaded to Roblox under your account, which only Studio can do:

1. In Studio: **Home > Import 3D** (or File > Import 3D) and pick `art/export/InkboundModels.fbx`.
2. Keep the defaults (it imports as a model; rig type: none). Press **Import**.
3. Move the imported model into **ReplicatedStorage > InkboundAssets** (Rojo leaves it alone
   there). To keep it in the repo too, right-click it > **Save to File** as
   `assets/shared/Models/InkboundModels.rbxm`.

That is all. On the next match the maps, the meeting room, cutscenes and effects use the
Blender props and textures. `ModelLibrary` fixes scale and orientation from the catalog, so the
importer's unit and axis settings do not matter. Until the import, everything falls back to the
part-built versions, and effects fall back to Roblox's default particle.

Effect textures ride along on small quads named `Tex_<name>`. If you would rather upload the
PNGs yourself, paste their ids into `Assets.textures` in `src/shared/Assets.luau`.

## Adding a prop

1. Add a builder to `scripts/props.py` or `scripts/props_world.py` with `@prop("Name", ...)`,
   facing -Y, standing on z = 0 (for `pivot="bottom"`). Glowing parts go in the second list.
2. Rebuild and export as above, then re-import the FBX in Studio.
3. Place it from a map with `b:placeModel("Name", x, z, rot)` (it returns nil when the prop is
   not imported yet, so give it a fallback or let it be optional as `Style.prop` does).
