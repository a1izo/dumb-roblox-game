# Death's Gambit art (Blender)

Everything here is made by the Python scripts in `art/scripts`, so it can be rebuilt, changed
and re-exported at any time. Blender 5.2 (any recent 4.x+ should work). 1 Blender unit = 1 stud.

| Folder | What it holds |
| --- | --- |
| `scripts/` | The build scripts (run with Blender, see below) |
| `scripts/maps/` | The scenes: texture library, geometry kit, one package per venue |
| `data/r15_rig.json` | Roblox's own R15 rig (joints and part sizes), from `r15_extract.py` |
| `blend/Animations.blend` | The R15 rig with every animation as an action (open it to tweak curves) |
| `blend/Props.blend` | Every prop, baked |
| `blend/Maps_<Venue>.blend` | Each venue's scene (Lobby, Meeting, Agency, Campus, Tokyo) |
| `export/DeathsGambitModels_Core.fbx` | The props every venue and the game itself use (Grimoire, hood, stations, tip box, board, paper, desks...) with the effect and UI textures |
| `export/DeathsGambitModels_<Set>.fbx` | The props made for one venue (Tokyo, Agency, Campus, Lobby, Meeting) |
| `export/DeathsGambitMaps_<Venue>.fbx` | One venue's scene each, with its tiling textures |
| `export/textures/` | Baked prop textures, effect textures, and `maps/` (tiling colour, normal and roughness maps) |
| `export/previews/` | Renders of every pose, prop and map, for review |

## The imports in Studio

Meshes and images must be uploaded under your account, which only Studio can do. For each
`art/export/DeathsGambitModels_<Set>.fbx` (Core and one per venue) and each
`art/export/DeathsGambitMaps_<Venue>.fbx`:

1. **Home > Import 3D** (or File > Import 3D), pick the file, keep the defaults, press **Import**.
2. That's it. The importer drops the model into Workspace; when the game starts, the server
   moves every `DeathsGambit...` import (and any older `Inkbound...` one) into **ReplicatedStorage > DeathsGambitAssets** and prints what
   it found in the Output ("Blender models: 33 of 33 found."). You can also drag them there
   yourself, which keeps the editor view clean.

Importing a newer version: delete the old imported model first (the game uses the first one it
finds with a given name).

Nothing breaks before an import: props fall back to their part-built versions and every venue
is built as a greybox (below).

`InkboundModels.fbx` and `InkboundMaps.fbx` are retired (their props moved to the Core set, the
lobby and the meeting room got scenes of their own). The game sets an import of either aside and
warns; delete them from the place.

**After the rename to Death's Gambit** every file is called `DeathsGambit...` (props, scenes, markers, the
store folder). Imports made before it (`InkboundModels_<Set>.fbx`, `InkboundMaps_<Venue>.fbx`) keep working: the
game reads both names and uses the newer import when both are in the place. To finish the switch, import the
eleven new files, check the Output (`[DeathsGambit] ...` lines), then delete the old `Inkbound...` imports.
The Core file also carries the new UI textures, so the new lettering and panels need it.

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

Every venue is a package in `scripts/maps/venues/` with `FORMAT = 2`: the lobby (`lobby/`), the
meeting room (`meeting/`) and the maps (`tokyo/`, `agency/`, `campus/`). Export one venue at a
time (each saves its own `Maps_<Venue>.blend`).

```
blender -b --factory-startup --python art/scripts/run_maps.py -- Lobby --preview      # renders
blender -b --factory-startup --python art/scripts/run_maps.py -- Lobby --export
blender -b --factory-startup --python art/scripts/run_maps.py -- Meeting --export
```

### The lobby and the meeting room

The lobby (`scripts/maps/venues/lobby/`) is the Grey Realm, a never-ending wasteland: cracked ash running to the
horizon (the plain is built out to 1500 studs and the fog closes at 1300, so its edge is never seen), huge
twisted columns, mesas and spires standing out of the haze, walls of cloud on the skyline and, far north, one
colossal blade standing in a rock mound. The walkable part is a rough basin about 320 studs across, bordered by
a continuous ridge of rock, needle fields and spires (an invisible wall follows its edge, open only where the
two causeways leave), with a second ridge behind it for depth. Two causeways of old stone cross deep chasms
(cracks cut out of the plain) and climb a flight of steps onto two raised plateaus: the Spire Ascent (west)
and the rune courtyard (north-east). A few rocks float high in the sky, the only things that do.
`plan.py` (every place, with its own overlap check; `python plan.py` runs it), `terrain.py` (the basin's
ground with the rift cut out, the endless plain `far_plain`, the ridge `edge`, the chasms `chasm`, the plateau
sides, and the realm's own shapes: `column` (fluted, twisted), `needle`, `floating_rock`, `arch`,
`cloud_bank`, `horn`, `blade`), `landmarks.py` (the spawn terrace, the plaza and the Grimoire's plinth, the
title monolith, the eight steles, the bone throne, the Academy's ring of pillars, the dice rock, the
stone-toss cairn, the cleft and the needle ledge, the carcass), `islets.py` (the two causeways and plateaus,
the Spire Ascent's spiral of stones round a twisted spire, the rune courtyard), `formations.py` (the world
beyond: spires, mesas, columns, arches, horns, ribs, ridges, dunes, cloud banks, floating rocks), `rift.py`
(the hole through the ground, its ruined rim, and Kagegaoka at night far below, dim and pale, built at a third
of its size), `dressing.py` (dead trees, braziers, lantern posts, bones, the particles, the sounds, the roots
and banners that sway; placed by hand) and `gameplay.py`. The lobby's Luau builds what shows text or does
something at the scene's `anchors` (`s.anchor`): `Maps/Lobby.luau` (the title, the eight boards, the spawn, the
Academy), `Maps/LobbyGames.luau` (the mini-games' objects) and `Maps/LobbyDecor.luau` (the things that sway).
Its props are the `Lobby` set (`props_lobby.py`, `DeathsGambitModels_Lobby.fbx`). The lobby's sky, clouds, fog and
ambience are runtime: `client/World/RealmSky.luau`, `WindSway.luau`, `Audio/RealmAmbience.luau`, and the
`lobby` preset in `shared/LightingPresets.luau`; their numbers are in each module's `TUNING`.

The lobby's sounds are synthesised by `scripts/audio/make_realm_audio.py` into `art/audio/` (see its
README for the upload steps and the `Assets.sfx` slots).

The meeting room (`scripts/maps/venues/meeting/`) is the Agency's war room, 60 x 60 x 18 as it
always was: `plan.py` (the room's numbers: the table, the twelve standing places, the screen, the
board, the windows, the mezzanine), `room.py` (parquet and the round carpet, walnut panelling
under damask, pilasters, the coffered ceiling with the spotlight and the brass halo, the
Specters' mezzanine), `furnish.py` (the table's round colliders and chairs, the screen wall, the
case wall of photographs and red string, bookcases, sideboard, clock, radiators, the corners) and
`outside.py` (the city far below the windows, rain on the glass). `Maps/MeetingRoom.luau` builds
the screen, the board, the seats and the Specters' spots at its anchors. Its props are the
`Meeting` set (`props_meeting.py`, `DeathsGambitModels_Meeting.fbx`).

### The maps (Tokyo, Agency HQ, University Campus)

Each map (`scripts/maps/venues/tokyo/`) is a whole map made here:
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
set (`props_agency.py`, `DeathsGambitModels_Agency.fbx`).

University Campus (`scripts/maps/venues/campus/`, map `UniversityCampus`) is Kagegaoka
University on the eve of its entrance exam, a winter night in light snow: 300 x 220 studs inside
its brick wall. The red gate (taped off by the police) opens on an avenue of bare ginkgos that
runs up to the forecourt and the Great Auditorium, whose clock tower's hands creep to midnight as
the investigation runs out. Round it: Law & Letters with its arcade, the library (its reading
room has a gallery with a stair at each end), the pond hollow 5 studs down with its frozen pond
and bridge, the concrete club house, the cafeteria, the Faculty of Science with its forensic
medicine lab, and the snowed-over tennis court (look-only). `plan.py` (every footprint, door,
room, path and height, with its own overlap check), `masonry.py` (brick Gothic walls with arched
openings, snowy gable and hip roofs, the clock tower, the arcade, the red gate, the guard booth),
`fit.py` (the Agency's fittings, plus `clear_of_stations`: the build fails when something solid
stands within 5 studs of a station's worker side), `ground.py` (lawns under snow, shovelled paths,
the hollow and the pond), `auditorium.py`, `library.py`, `faculties.py`, `student.py`,
`grounds.py` (every lamp and tree placed by hand), `outside.py` (snowy streets past the gates,
the city, the Central Tower on the skyline) and `gameplay.py`. Its props are the `Campus` set
(`props_campus.py`, `DeathsGambitModels_Campus.fbx`). Snow lies where the ground's look is `Snow`:
the client leaves footprints there (`World/FootprintController`), never on the shovelled
`SnowPath`.

```
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --plan      # top-down plans
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --massing   # blocks only
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --preview   # street-level views
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --export
python art/scripts/maps/check_v2.py Tokyo            # full check (a few minutes); --quick skips the walk
python art/scripts/maps/walkdebug.py Tokyo x y z 40  # where can you walk from here?
```

To look over a map by hand (props in roads, in walls, facing the wrong way), render it into a scratch
folder, never the tracked previews:

```
blender -b --factory-startup --python art/scripts/run_maps.py -- Campus --proplan --out <dir>
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --proplan --levels ground --region -60,-110,0,-60 --out <dir>
blender -b --factory-startup --python art/scripts/run_maps.py -- Tokyo --eyes "px,py,pz,tx,ty,tz[,lens];..." --out <dir>
```

`--proplan` renders each level in tiles (`--tile 50x38 --ppu 34 --bright 2.2`) from above with every prop
placed: its number and name, a magenta arrow for the way its front faces, a 10-stud grid with
coordinates, and a `.txt` legend per tile that gives each prop's position, rotation and the script line
that placed it (`Scene.prop_src`). `--eyes` renders perspective views from any spot (Roblox studs). They
are aids for looking, nothing decides where a prop goes.

`--export` writes, for that venue only (other venues are left alone), here for Tokyo:
- `export/DeathsGambitMaps_Tokyo.fbx`: meshes `Map_Tokyo_<Material>_<n>`, calibration cubes
  `Calib_Tokyo_O/X/Y` and a marker `DeathsGambitMapsTokyo_Version_<n>`. The version only goes up when
  the meshes change; only then does Studio need a new import (delete the old one first).
- `src/server/Maps/Scenes/Tokyo/`: `Layout` (gameplay spots, spare spots, zones), `Geometry`
  (colliders, floor triangles, ramps, the steps drawn over them), `Dressing` (props, lights, signs,
  screens, sound sources and the metro train's timetable). Long lists are split into parts so no
  script gets too long for Studio.
- `src/shared/MapBounds.luau` (a map's Specter box) and `src/shared/SceneMaterials.luau` (merged).
- `export/scenes/Tokyo.json`: the same data for the checks (not committed).

Without the import the game builds the map as a greybox from the colliders (in their materials'
colours, streets painted, lamps as small glowing fittings), so a map change can be played before
it is imported.

Every light belongs to something you can see: a lamp in the map's meshes, or a prop that carries
its own (street lights, lanterns, fridges, the train; `lights` in the catalog). A lantern string
can be placed unlit (`s.prop(..., dark=True)`). The client's `World/MapAmbient` plays the
screens' loops (adverts, camera feeds, the night news, a sector map, an old film), the sound
sources (silent until their `Assets.sfx` slot has an id), the train that pulls into the platform
every two minutes, the aircraft lights blinking on towers, the rain on a tower's glass, snow
slipping off branches, the police helicopter sweeping its searchlight past the windows, and the
campus clock tower (its hands, and the bell tolling twelve when the Grimoire phase begins).

`check_v2.py` checks the contract at every floor height; that nothing of the game's stands on a
road, crossing, water, track or stairs (zones); that every spot can be walked to from the spawns
and how long corner to corner takes (aim: 30-45 s; a venue can set its own target and the
points to measure between, `CHECKS` in its module); how much of the walkable ground is lit (a
report, not a pass mark: `previews/light_Tokyo.png` shows the dark parts in red); and how alike
the map is to its own mirror image (it must not be symmetrical; `CHECKS["symmetry"]` sets a
venue's own limit, None where being symmetrical is the point, as in the meeting room).

The kit for big maps: `maps/geo2d.py` (plane geometry: clipping, covering, polylines),
`maps/city.py` (ground surfaces that never overlap, exact floors, streets, lanes grown into the
blocks, terraces, stairs, slopes, shops, multi-storey buildings, lamps), `maps/layout.py` (the
gameplay spots and zones).

## Props and textures

```
blender -b --factory-startup --python art/scripts/run_props.py            # build and bake all
blender -b --factory-startup --python art/scripts/run_props.py -- Desk    # just one
blender -b --factory-startup --python art/scripts/run_textures.py         # effect textures
blender -b --factory-startup --python art/scripts/run_props.py -- --set Core --export  # FBX + catalog
blender -b --factory-startup --python art/scripts/run_props.py -- --set Tokyo --preview  # one set
blender -b --factory-startup --python art/scripts/run_props.py -- --set Tokyo --export
```

`--export` (with `--set`) writes `export/DeathsGambitModels_<Set>.fbx` and
`src/shared/ModelCatalog.luau` (each prop's size in studs, pivot, material, glow colours, the
lights it carries and its set). The Core set's file also carries the effect and UI textures. `ModelLibrary` fixes scale
from the catalog and undoes the importer's turn of each file with its three calibration cubes (positions only).
`ModelLibrary` can also give every prop a half turn (`facingTurn`, default OFF, set 2026-10-05 after ON showed them backwards in Studio 0.741; the gallery shows which is right
(an earlier Studio showed them backwards without it). The gallery's "Flip facing +
gallery" button tries the other setting. The prop's pivot is kept upright through the primary part's `PivotOffset`: with a
primary part the pivot takes that part's orientation, so without it `PivotTo` (what every map placement uses)
would undo the half turn. The Prop gallery's message says "Half-turn ON/OFF" when a place runs these scripts.

Effect textures ride along on small quads named `Tex_<name>`. If you would rather upload the
PNGs yourself, paste their ids into `Assets.textures` in `src/shared/Assets.luau`.

## Adding a prop

1. Add a builder to `scripts/props.py` or `scripts/props_world.py` with `@prop("Name", ...)`,
   facing -Y, standing on z = 0 (for `pivot="bottom"`). Glowing parts go in the second list.
   Those are the Core set (the default). A venue's own props go in their own file
   (`props_tokyo.py`, `props_tokyo_shops.py`, `props_stations.py` with `set="Tokyo"`,
   `props_agency.py`, `props_campus.py`, `props_lobby.py`, `props_meeting.py`); `lights=`
   gives the lights it carries. Build a set on its own (`--set Campus`): a bare run rebuilds
   every set.
2. Rebuild and export as above, then re-import the FBX in Studio.
3. Place it from a map with `b:placeModel("Name", x, z, rot)`, or from a scene with
   `s.prop("Name", x, z, rot)`.
