---
name: own-furniture-2026-11
description: Each case map has its own furniture now (17 models, maps/ownprops.py); how the swap works and what to keep when adding more
metadata:
  type: project
---

Asked 2026-11-02: "make way more detailed assets so we dont reuse them in every other map". The maps' scripts still
ask for "Chair", "Desk" and so on; `art/scripts/maps/ownprops.py` is one table saying which model each map really uses,
applied in `Scene.prop`. Nothing in the maps' placement lines changed, and the first batch moved no prop.

- Models are in `art/scripts/props_mapown.py`, sets Campus, Agency and Tokyo (Models Campus 14, Agency 15, Tokyo 20).
  341 placed rows swapped: Campus 118, Agency 206, Tokyo 17.
- The catalog carries `base` (the shared prop a model stands for). Until a set's import lands, `SceneBuilder` shows the
  base prop there, not a grey stand-in box, so a script sync ahead of the import does no harm.
- `cinema/clearance.py` reads a model as its base, so `shot.allow` lists and `DESK_TOPS` keep working unchanged.
- `Tests/OwnFurniture.spec.luau` holds every model to its base's pivot, collision and footprint (0.1 studs over at most).
- The shared props stay in Core: emotes, win cuts, Styles, the shop and the Sets still use them, and Meeting and Sets
  venues are not in the table.

**Why:** seats, colliders, walk checks and shots were all measured against the old boxes.

**How to apply:** a new own model keeps its base's footprint, seat height (chair 1.745, bench 1.6, sofa 1.845) and desk
height (3.05). `mk.ground` recentres on the bounding box, so anything sticking out (a pull, a padlock) moves the whole
prop: keep the box inside the base's. Add it to `OWN`, bump the set's VERSION by hand, export the set, then run
`run_maps.py -- <Venue> --export`; the map's own version does not change, so restore that venue's FBX and blend rather
than committing them.

Modelling traps found on these, all fixed in `props_mapown.py` (reuse its helpers):

- Never `mk.soften` a capped cylinder: smoothing tilts its long faces toward the ends and the bake turns them to
  crumpled foil. Use `roll()`, an open tube.
- Foliage: `mk.sheet` offsets its back face down Z, so where a leaf hangs both faces lie in one plane and bake black.
  Use `blade()`, which offsets along the normals. Thousands of loose tiny leaves also bake black: keep a frond one
  connected sheet.
- A dome over about 25 degrees splits into six UV islands per nail, and a hundred nails left half the sofa's map empty.
  Draw long rows in the colour instead (`dotted()`, `punched()`, `lattice()`: no triangles, no islands).
- `spline()` overshoots where a long span meets a short one (a rail's corner): use `loop()` arcs there.
- A material's last name word picks its scan: `X_RollLeather` is not leather, `XRoll_Leather` is.

Still shared after the first batch: see the audit (props in 2+ case maps); memory left is the limit, Agency most of all.
