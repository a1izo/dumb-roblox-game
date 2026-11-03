---
name: lobby-ground-relief
description: The lobby's ground is one relief mesh (lobby/ground.py) over flat collision floors; it stays level under paving; mesher smooth pieces and the ground flag for the finders
metadata:
  type: project
---

Lobby remake, 2026-11-03. What is seen of the ground is `art/scripts/maps/venues/lobby/ground.py`: a height field from the
basin out to REACH (424, a square; past it the far plain lies level at -0.15), a 4-stud grid over the basin and 8 beyond,
jittered so no rows show. Swells, wind ripples, dunes past the ridge, ash banked against every rock's foot (`rocks.FEET`);
scree (RockGrey) in a ragged apron round rock feet and crusts (RealmCrust) in patches, their edges cut along their own
contour lines (`_split`), never a sawtooth of grid cells.

- Collision is unchanged: flat floors at 0 (terrain.ground). The relief stays low where people walk (WALK 0.3, BANK 0.7)
  so feet sink a little into ash; it lies at LOW -0.06 under everything laid on the ground (`level_places`: footprints,
  paving discs, the ways, the causeways, the plateaus), so paving at 0 never fights it.
- Surfaces are the lobby's own `RealmAsh` / `RealmCrust` (darker than the Ash the cutscene sets share: never regrade a
  shared surface for one venue).
- `mesher.Scene.smooth()` (a block whose faces weld and shade smooth, creases over 58 degrees kept) and `Scene.mesh(...,
  normals, ground=True)` (a whole smooth piece with its own normals, seamless across tiles) are new; bones, the rift's throat,
  chasm walls, plateau sides and clouds use `smooth()`.
- `ground=True` pieces are skipped by `finders.oneside`: a height field faces up, and what hides its far side from an eye is
  a prop, which the finder does not see (it flagged ash behind kit rocks).
- It costs ~52k of the lobby's 117k map triangles; the fine grid stops at INNER 176 for that.

**Why:** the flat ash plane was the second biggest thing in every view.
**How to apply:** anything new laid on the lobby's ground goes into `level_places` (or the plan's footprints) so the relief
stays under it.
