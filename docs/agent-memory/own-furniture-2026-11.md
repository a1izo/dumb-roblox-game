---
name: own-furniture-2026-11
description: No prop stands in two case maps any more (64 own models, maps/ownprops.py); how the swap works and what to keep when adding more
metadata:
  type: project
---

Asked 2026-11-02: "make way more detailed assets so we dont reuse them in every other map", then 2026-11-03: "remove old
models that are reused and make new high quality ones, and dont ask me what to do because ill be awway". The maps' scripts
still ask for "Chair", "Desk" and so on; `art/scripts/maps/ownprops.py` is one table saying which model each map really
uses, applied in `Scene.prop`. Nothing in the maps' placement lines changed, and no prop moved. As of 2026-11-03 no prop
stands in two of the three case maps (36 did that morning, 16 of them in all three).

- Models are in `art/scripts/props_mapown.py` and `props_mapown2.py`, sets Campus, Agency and Tokyo (Models Core 34, Campus
  15, Agency 16, Tokyo 21). 495 placed rows swapped: Campus 212, Agency 260, Tokyo 23.
- The old furniture the game itself still names (emotes, win cuts, shop, Sets) was remade in `props_core.py` under its old
  keys: Chair, OfficeChair, Bookshelf (lighter than before: the library places 95), FilingCabinet.
- Gone for good, builders and textures: the seven Hat props, SuitHandL/R, ShrineDoor, Notebook, Hydrant, VendingMachine.
- A map may send several shared props to one model (Agency's three vending machines, Campus's two desks): the last named in
  `OWN` is the model's `base`. `RETIRED` holds what a map still asks for but no longer exists as a fallback.
- `snow_on()` (props_mapown2) drapes a snow sheet over any parts by casting down onto them: the University's cars, bicycle,
  cone and pole are the street models under snow, not new shapes. It needs `flat` high enough to miss a windscreen.
- The catalog carries `base` (the shared prop a model stands for). Until a set's import lands, `SceneBuilder` shows the
  base prop there, not a grey stand-in box, so a script sync ahead of the import does no harm.
- `cinema/clearance.py` reads a model as its base, so `shot.allow` lists and `DESK_TOPS` keep working unchanged.
- `SceneBuilder.solidFor` gives a model its base's solid, and `check_v2` and `finders` read a model as its base for their
  name lists (FEET, WALLS, MAY_TOUCH, HANGING): a bicycle's collider and the tape strung on a fence depend on it.
- `Tests/OwnFurniture.spec.luau` holds every model to its base's pivot, collision and footprint (0.1 studs over at most).
- Meeting and Sets venues are not in the table. Props there may still repeat a Core model.

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

After the third round (2026-11-03): Agency 93.15 of 96.41 MP, Campus 127.63 of 129.03, Tokyo 158.11 of 167.94, Lobby 58.59,
Meeting 59.38. Dropping Core's Desk, Sofa and Crate to 512 with a 128 normal paid for it: they hardly appear now.
A model can also be wider than its base's spot even inside the 0.1 rule: `VendingMachine` was 2.7 deep where VendingBlue is
3.1, so one model standing for both must fit the shallower.
