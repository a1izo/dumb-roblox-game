---
name: realm-rock-kit
description: Every rock in the lobby is a shape of the realm's rock kit (realmrock.py, Lobby set props "Realm..."), placed by lobby/rocks.py with colliders from its own footprint; the checks treat them as terrain
metadata:
  type: project
---

Lobby remake, 2026-11-03: the procedural faceted rocks (flat-shaded rings, 53k of the map's triangles) became a kit of
lofted rock shapes, `art/scripts/realmrock.py` (crags, spires, two twisted columns, mesas, boulders, needles, slabs,
floating stones, the Spire Ascent's spire), with strata ledges, joints, fracture planes, smooth shading and ash on every
ledge. They are tiled props ([[tiled-props]]) in the Lobby set, instanced ~1100 times.

- `KIT` recipes; `*Far` variants (a third of the corners) stand in past 300 studs, for small ones, and for the out-of-reach
  second ridge (`terrain.far`, `lighter=True`). Instances total ~900k triangles before Roblox's own mesh LOD.
- `lobby/terrain.py` keeps the old call names (`rock`, `spire`, `mesa`, `boulder`, `column`, `needle_field`,
  `floating_rock`) and picks the kit shape nearest the asked proportions (`fit`), so the layout did not move.
- `lobby/rocks.py` stands a shape: `s.prop` sunk by its `sink`, a core collider (up to its visible top, never past it: things
  stand on a mesa's top) and walls along `realmrock.footprint` (read off the faces between rings, so it works at any scale).
  `rocks.FEET` collects the feet for the ground's ash banks (only rocks stood on the plain, y 0).
- Foot walls rise only to the rock's own top (`min(FOOT_H, top)`), and a rock under 1.5 studs gets none: until
  2026-11-04 every rock's walls stood 9 studs, so the slabs breaking through the ash and the low boulders were fenced
  by invisible walls you could not step over.
- A billow's foot reaches much further than it looks (RealmBillowC at 0.9: ~12 studs). Before standing rocks beside a
  way in, measure with `rocks.outline(key, x, z, rot, sc)` and keep the way clear (landmarks.grotto does).
- The climb's stones are `RealmFloaterA/B`; since 2026-11-04 they circle the Chain Heap's GreatChain and its checkpoints
  are GearPlatform props (the spire `RealmSpireAscent` and the flag-topped `RealmFloaterFlag` are gone).
- Checks: `maps/catalog.is_terrain` (keys "Realm...") keeps kit rocks out of prop overlaps and of the sunk/float finder:
  they interpenetrate, sink and hang on purpose. Everything else is still caught by their colliders.

- Since 2026-11-04 ([[lobby-remake-v2]]): billowing cliffs (`RealmBillowA/B/C`, `RealmBillowShelf`: recipe `billows`, a
  union of domes so a crease runs between the bulbs), the throne's table (`RealmThroneRock`), cave drips, a colossal
  tusk (recipe `mat` BoneOld), and kind `cluster` (parts leaned and turned: `RealmShardsA/B/C`, `RealmShardSpire`, pale
  surface RealmShard). `only_far` recipes exist only for their far variant; `FAR_SKIP` keeps unused far variants out.

**Why:** the lobby read as low-poly; rocks are in every view.
**How to apply:** new rock goes through the kit (add a recipe, build with `run_props.py -- <Key>`, export Lobby); never draw
faceted rock in the map again. A recipe change moves footprints: export the venue again and run check_v2.
