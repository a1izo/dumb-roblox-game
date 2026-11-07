---
name: collision-matches-drawing
description: Everything a body can reach is solid as drawn (2026-11-07): props collide by their own mesh or by blocks cut from their shape, the lobby's rocks by their mesh, check_v2 walks the measured shapes, find_ghosts.py finds what is still walked into
metadata:
  type: project
---

Asked 2026-11-07: "make it so you cant noclip through anything at all ... make everything solid so that it matches the
structure too". Map meshes never collide (SceneBuilder dress()); a venue's colliders, floors and ramps, and each prop's
own collision, are all there is. What changed, and how to keep it:

- **Props solid by their own mesh** (`props.prop(collide=True)`): Roblox's "Default" collision of an imported mesh. Measured
  on RealmBillowA against PreciseConvexDecomposition: 0.33 studs apart on average, 2 at worst (precise took 2.6 s for
  that one rock, too slow at a server's start). The whole rock kit (props_realm.py) is mesh-solid now; rocks.py lays no
  core or foot walls any more (they stood past concave creases as invisible walls and short of bulges). The rock kit's
  models are tagged LCameraBlock by SceneBuilder, so the camera stops at them.
- **Blocks cut from a prop's shape** (`props.prop(solids=True)`, build_props.cut_solids): for open or thin things a hull
  would fill (a tent, a roped pine, a cherry tree, a signal on its pole, a string of lanterns, a bus shelter). Slices a
  stud tall up to 8.5 over its foot, each slice's cross-section on a 0.25 grid (coarser until at most 48 blocks),
  written to the catalog as `solids`; SceneBuilder.solidFor lays them; they win over the old SOLID table.
- **The catalog takes collide and solids from the builder's code**, not from Props.blend, so a flag changed in code needs
  no prop rebuild: `run_props.py -- --catalog` writes the catalog again (it builds and saves nothing).
- **check_v2 walks the real shapes**: the venue export measures every mesh-solid prop as columns (maps/propcols.py: a
  ray dropped through the mesh on a 1-stud grid, 0.5 for small props) into the sidecar's `propCols`; World uses them
  (ColsSolid) instead of the prop's whole box, and lays the catalog's cut solids. Low ledges (a collider 1 stud tall or
  less that blocks no sight line: a kerb, a heater's sill) are left out of "stands in a wall or collider".
- **find_ghosts.py** (art/scripts): every walkable spot's body column against every drawn triangle; anything drawn with
  nothing solid within 0.35 studs is listed by owner. After the pass: Meeting 0; the rest only grass (SpikeGrass), noren,
  snow a foot sinks into, and stair treads (by design, below). Run it after any map or prop change.
- **Stairs** (city.stairs): the walking slope now runs through the middle of every riser (half a tread before the first
  step, a level solid over the top half tread and half a stud onto the landing), so a foot is never more than half a
  step into a tread or over it (it sank a whole step before). `guard_from=0` starts a flight's guards at its first
  step, where a rail or glass runs its whole length (Tokyo's escalators, stair rails and metro stairs).
- Pieces drawn with `s.box` that a body meets get `collide=True` (`query=False` when it should block no sight line);
  a wall fixture sticking out at head height (CRT banks, chalkboards, heater sills, AC units) is a thing a body walks
  into.

**Why:** the user walked through rocks, crystals, bones, tents, trees, tables and wall fixtures, and was stopped by
invisible walls round the rocks' feet.
**How to apply:** a new prop that stands where people walk collides by its mesh, or gets `solids=True` when it is
open or thin; never leave one walk-through except grass, curtains, snow or rugs. After a change: run_props `--catalog`,
export the venues, check_v2, find_ghosts. A new big collide=True prop shows a solid stand-in box until it is imported,
so a gate or anything in a way people walk gets `collide=False` plus colliders from the venue (landmarks.academy_gate).
Related: [[realm-rock-kit]], [[check-v2-reach]], [[lobby-remake-v2]].
