---
name: tiled-props
description: Props can wear the maps' own tiling scan surfaces instead of a bake (props.prop tiled=True); how they are built, split per surface, and where the lobby uses them
metadata:
  type: project
---

Since the lobby remake (2026-11-03) a prop can be `@prop(..., tiled=True)`: no unwrap, no bake. Its faces carry map
materials (`maps/matlib`, e.g. RockGrey, RealmAsh, Basalt, RuinFlag, BlackTrim) with UVs in repeats of each surface, so a
house-sized thing gets the map surfaces' density (RockGrey: 73 px/stud) instead of a blurry bake, and shares their textures
(no new megapixels).

- A builder returns one ready mesh (the rock kit, `props_realm.py`: UVs laid by `realmrock.py`) or parts built with modelkit
  (`props_monolith.py`): `build_props._tiled` merges parts with `mk.merge` (bevels applied) and lays UVs from the six sides
  with `props_realm.tile_uvs`; a single ready mesh keeps its UVs and gets smooth shading with creases at 55 degrees.
- **One surface per mesh**: `build_props._split_surfaces` cuts every surface after the first into a piece
  `<Key>_<Surface>` (catalog `parts`, which `ModelLibrary` clones in with the prop). No prop before wore two surfaces on one
  mesh, and the importer's handling of that was never seen, so never export one.
- The catalog's fallback colour comes from the first surface's map texture (`dg_tiled`).
- Previews: `run_maps.place_props` now places a prop's pieces too.
- Glow parts (`<Key>_Glow`) work as on any prop (the monolith's red crack cores).

**Why:** big rocks and architecture baked at 512-1024 px read soft and cost megapixels; the lobby had 2 MP to spare.
**How to apply:** use it for large stone things and anything placed by the hundred; keep baked props for hero props seen
at arm's length that need AO and painted detail (the Academy's steles and altars, braziers). Related: [[realm-rock-kit]].
