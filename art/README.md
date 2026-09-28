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
| `blend/Maps.blend` | The map scenes not rebuilt yet |
| `blend/Maps_<Venue>.blend` | A rebuilt big map (Tokyo, Agency) |
| `export/InkboundModels.fbx` | All props and effect textures (Studio import #1) |
| `export/InkboundModels_<Set>.fbx` | The props made for one map (Tokyo, Agency), imported like the others |
| `export/InkboundMaps.fbx` | The map scenes not rebuilt yet, with their tiling textures (Studio import #2) |
| `export/InkboundMaps_<Venue>.fbx` | One rebuilt big map each (Studio import, one per map) |
| `export/textures/` | Baked prop textures, effect textures, and `maps/` (tiling colour, normal and roughness maps) |
| `export/previews/` | Renders of every pose, prop and map, for review |

## The two imports in Studio

Meshes and images must be uploaded under your account, which only Studio can do. For each of
`art/export/InkboundModels.fbx` and `art/export/InkboundMaps.fbx` (and each
`InkboundModels_<Set>.fbx` and `InkboundMaps_<Venue>.fbx` beside them):

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

Each older venue (`scripts/maps/venues/lobby.py`, `meeting.py`, `campus.py`) builds its
architecture from the kit (`kit.py`, `urban.py`) on the same layout as the Luau map module, so
stations, spawns, sheets, drop points and hoods keep their places. The rebuilt big maps (`tokyo/`,
`agency/`) are packages that place their gameplay spots themselves (below).

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

### The rebuilt big maps (Tokyo, Agency HQ)

A venue whose module sets `FORMAT = 2` (`scripts/maps/venues/tokyo/`) is a whole map made here:
its streets, buildings and **gameplay spots** (stations, spawns, sheets, drop points, hoods,
named areas with intro marks, the tip box and board, plus spare spots of every kind) are all
placed by the venue script, and the game reads them from the generated scene data. The Luau map
module is three lines (`Maps/TokyoDistrict.luau`).

Tokyo is 400 x 300 studs at real scale (ground floors 14 studs, the floors above 12). Its script
is a package, one file per job: `plan.py` (streets, the river, the station and every building's
footprint, height and use), `ground.py`, `river.py` (water wall to wall, railings with an
invisible wall above them), `station.py` (the metro), `styles.py` (each building's look, set by
hand), `interiors.py` (the rooms you can walk into, with the stations in them), `dressing.py`
(street furniture and every lamp, placed by hand), `edges.py` (the city carrying on past the
map, and a fence with police tape across every street that leaves it) and `gameplay.py`.
Buildings are made by the kit in `maps/buildings.py` (facades, shopfronts, signs, roofs).

Agency HQ (`scripts/maps/venues/agency/`, map `TaskForceHQ`) is the Agency's two floors, 38F
(y 0) and 39F (y 14), high in the Kagegaoka Central Tower: a 200 x 150 plate with its south-east
corner cut, an off-centre core (the lifts, closed service rooms, a fire stair) with a corridor
round it, and over the lobby the atrium, where a grand stair climbs to the operations deck facing
the video wall. `plan.py` (the plate, the core, the stairs and every room of both floors),
`shell.py` (slabs, the curtain wall, the core, the fire stair, the atrium), `fit.py` (partitions:
clear glass lets a letter flash through, frosted glass, shut blinds and the one-way mirror do not;
furniture, stairs and railings with their invisible guards, ceiling fittings), `lower.py` and
`upper.py` (each floor's rooms with their stations), `outside.py` (the city 440 studs down, the
neighbouring towers, car lights, rain on the glass, the helicopter's pass; flat colours and big
mesh chunks, `far_chunk`, since it is all far away) and `gameplay.py`. Its props are the `Agency`
set (`props_agency.py`, `InkboundModels_Agency.fbx`).

```
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --plan      # top-down plans
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --massing   # blocks only
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --preview   # street-level views
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --export
python art/scripts/maps/check_v2.py Tokyo            # full check (a few minutes); --quick skips the walk
python art/scripts/maps/walkdebug.py Tokyo x y z 40  # where can you walk from here?
```

`--export` writes, for that venue only (other venues are left alone):
- `export/InkboundMaps_Tokyo.fbx`: meshes `Map_Tokyo_<Material>_<n>`, calibration cubes
  `Calib_Tokyo_O/X/Y` and a marker `InkboundMapsTokyo_Version_<n>`. The version only goes up when
  the meshes change; only then does Studio need a new import (delete the old one first).
- `src/server/Maps/Scenes/Tokyo/`: `Layout` (gameplay spots, spare spots, zones), `Geometry`
  (colliders, floor triangles, ramps, the steps drawn over them), `Dressing` (props, lights, signs,
  screens, sound sources and the metro train's timetable). Long lists are split into parts so no
  script gets too long for Studio.
- `src/shared/MapBounds.luau` (the Specter box) and `src/shared/SceneMaterials.luau` (merged).
- `export/scenes/Tokyo.json`: the same data for the checks (not committed).

Without the import the game builds the map as a greybox from the colliders (in their materials'
colours, streets painted, lamps as small glowing fittings), so a map change can be played before
it is imported.

Every light belongs to something you can see: a lamp in the map's meshes, or a prop that carries
its own (street lights, lanterns, fridges, the train; `lights` in the catalog). A lantern string
can be placed unlit (`s.prop(..., dark=True)`). The client's `World/MapAmbient` plays the
screens' loops (adverts, camera feeds, the night news, a sector map), the sound sources (silent
until their `Assets.sfx` slot has an id), the train that pulls into the platform every two
minutes, the aircraft lights blinking on towers, the rain on a tower's glass and the police
helicopter sweeping its searchlight past the windows.

`check_v2.py` checks the contract at every floor height; that nothing of the game's stands on a
road, crossing, water, track or stairs (zones); that every spot can be walked to from the spawns
and how long corner to corner takes (aim: 30-45 s; a venue can set its own target and the
points to measure between, `CHECKS` in its module); how much of the walkable ground is lit (a
report, not a pass mark: `previews/light_Tokyo.png` shows the dark parts in red); and how alike
the map is to its own mirror image (it must not be symmetrical).

The kit for big maps: `maps/geo2d.py` (plane geometry: clipping, covering, polylines),
`maps/city.py` (ground surfaces that never overlap, exact floors, streets, lanes grown into the
blocks, terraces, stairs, slopes, shops, multi-storey buildings, lamps), `maps/layout.py` (the
gameplay spots and zones).

## Props and textures

```
blender -b --factory-startup --python art/scripts/run_props.py            # build and bake all
blender -b --factory-startup --python art/scripts/run_props.py -- Desk    # just one
blender -b --factory-startup --python art/scripts/run_textures.py         # effect textures
blender -b --factory-startup --python art/scripts/run_props.py -- --export  # FBX + catalog
blender -b --factory-startup --python art/scripts/run_props.py -- --set Tokyo --preview  # one set
blender -b --factory-startup --python art/scripts/run_props.py -- --set Tokyo --export
```

`--export` writes `export/InkboundModels.fbx` (or `InkboundModels_<Set>.fbx` with `--set`) and
`src/shared/ModelCatalog.luau` (each prop's size in studs, pivot, material, glow colours, the
lights it carries and its set). `ModelLibrary` fixes scale and orientation
from the catalog, so the importer's unit and axis settings do not matter.

Effect textures ride along on small quads named `Tex_<name>`. If you would rather upload the
PNGs yourself, paste their ids into `Assets.textures` in `src/shared/Assets.luau`.

## Adding a prop

1. Add a builder to `scripts/props.py` or `scripts/props_world.py` with `@prop("Name", ...)`,
   facing -Y, standing on z = 0 (for `pivot="bottom"`). Glowing parts go in the second list.
   A map's own props go in their own file (`props_tokyo.py`, `props_tokyo_shops.py`,
   `props_stations.py`) with `set="Tokyo"`; `lights=` gives the lights it carries.
2. Rebuild and export as above, then re-import the FBX in Studio.
3. Place it from a map with `b:placeModel("Name", x, z, rot)`, or from a scene with
   `s.prop("Name", x, z, rot)`.
