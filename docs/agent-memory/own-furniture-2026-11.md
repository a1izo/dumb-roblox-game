---
name: own-furniture-2026-11
description: Each case map has its own furniture now (24 models, maps/ownprops.py); how the swap works and what to keep when adding more
metadata:
  type: project
---

Asked 2026-11-02: "make way more detailed assets so we dont reuse them in every other map". The maps' scripts still
ask for "Chair", "Desk" and so on; `art/scripts/maps/ownprops.py` is one table saying which model each map really uses,
applied in `Scene.prop`. Nothing in the maps' placement lines changed, and the first batch moved no prop.

- Models are in `art/scripts/props_mapown.py`, sets Campus, Agency and Tokyo (Models Campus 14, Agency 15, Tokyo 20).
  375 placed rows swapped: Campus 141, Agency 215, Tokyo 19.
- The catalog carries `base` (the shared prop a model stands for). Until a set's import lands, `SceneBuilder` shows the
  base prop there, not a grey stand-in box, so a script sync ahead of the import does no harm.
- `cinema/clearance.py` reads a model as its base, so `shot.allow` lists and `DESK_TOPS` keep working unchanged.
- `Tests/OwnFurniture.spec.luau` holds every model to its base's pivot, collision and footprint (0.1 studs over at most).
- The shared props stay in Core: emotes, win cuts, Styles, the shop and the Sets still use them, and Meeting and Sets
  venues are not in the table.

**Why:** seats, colliders, walk checks and shots were all measured against the old boxes.

**How to apply:** a new own model keeps its base's footprint, seat height (chair 1.745, bench 1.6, sofa 1.845), desk
height (3.05) and, for anything stackable, its full height (a crate stands on a crate in HQ). `mk.ground` recentres on the bounding box, so anything sticking out (a pull, a padlock) moves the whole
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
- A font's thin strokes (`=`, `+`) are lost in the bake at a prop's texel density: size text at 0.34 or more on a big prop,
  or draw the stroke as a box.
- `check_v2` reads the finds saved at `run_maps.py --export`: after changing a model's size, export the venue again before
  trusting it. `find_defects.py` measures afresh.

After both batches (2026-11-03): Agency 96.34 of 96.41 MP, Campus 128.69 of 129.03, Tokyo 163.62 of 167.94. Agency and
Campus are full, so any more own models there need a smaller texture elsewhere, or a new budget exception from the user.
Props in all three case maps went from 16 to 8: WaterCooler, PoliceTape, PinBoard, VendingBlue, VendingWhite, Planter,
DrinkFridge, MealTicketMachine. 28 more are in two of the three, mostly street things.
