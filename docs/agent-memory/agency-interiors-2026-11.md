---
name: agency-interiors-2026-11
description: HQ's security office, observation room, director's office and lounge dressed to the lobby's finish (2026-11-05); the kits it added (rugs, framed prints, coffers, dados) and the traps hit
metadata:
  type: project
---

On 2026-11-05 Agency HQ's barest rooms (views 3, 4, 8, 11 in `maps/venues/agency/__init__.py`) were dressed as part of
the "lobby quality everywhere" pass: Maps Agency v29, 110,552 of 112,761 triangles, 92.4 of 96.41 MP.

What exists now, all reusable:

- **Rugs** (`maps/rugs.py`): `rugs.lay(s, x, z, w, d, rot, y, field)`. A field (`RugField` oxblood, `RugFieldNavy`
  indigo: a lattice drawn over the Carpet016 scan) inside a mitred border band (`RugBorder`, lozenges in madder and
  indigo with gold). 18 triangles a rug, no collider. Registered in `scanlib.LIBRARY` like the facades.
- **Framed prints**: the Agency has its own sheet in `maps/prints.py` (`SHEETS["Agency"]`: two citations, the city at
  night, the tower's blueprint, the 38F evacuation plan, the observation room's "quiet" notice). `fit.framed(s, x, y,
  z, rot, w, index, frame)` hangs one: 12 triangles, half a blank `kit.picture`. Regenerate the sheet with
  `blender -b --factory-startup --python art/scripts/maps/prints.py -- Agency`.
- **Dados and panelling**: `fit.partition(..., dado_n=(mat, rail[, stiles]))` / `dado_s`: the lower wall in another
  finish to a rail at `fit.DADO_H` (2.8, under a glass partition's sill and casings), with upright stiles when a
  spacing is given (`kit.trims` "stiles"). Two-tone paint in security, walnut panelling with black stiles in
  observation, walnut with wood stiles in the lounge and the director's office (damask above).
- **Coffers**: `fit.coffers(s, poly, ceiling, xs, zs, insets)`: a band round any polygon (concave too) at a per-edge
  inset (0.3 at a wall's face, 1.0 clear of the curtain wall's blinds and broad mullions) and beams on chosen lines,
  6 triangles a beam. Put the room's downlights in cell centres (the lounge's and director's were moved to fit).
- **Near towers**: `outside.tower` is now `skyline.block` (NightOffice/NightTile) with `eye=P.L1`: a new optional
  `skyline.block(eye=...)` gives three quarters of `most` to the floors from 120 studs under the eye up. It freed about
  2,000 triangles; default `eye=None` leaves Campus and Tokyo unchanged.

Second pass, the same evening (Maps Agency v30): the break room (walnut dado on both walls, the city print, a clock, a
rug in the sofa's corner) and the training room (dark dado, three framed prints on the east wall's solid stretch, a
clock over the glass). The analysts' office was left: its walls are clear glass nearly all round. Agency is at 110,834
of 112,761 triangles after it.

Traps hit (all fixed):

- `finders.zfight` flags parallel faces within 0.02 studs (bucketed, so keep 0.04): a print 0.005 off its frame, a
  bulkhead's edge trim 0.02 under its soffit, and panelling stiles whose face landed exactly on a broad mullion's side
  (it stands 0.15 out from a wall's face where the wall meets the glass). Stiles are now only 0.02 proud.
- `finders` "stretch" flags a texture laid non-square: the rug border's repeat must be as long as the band is wide.
- Dark flat fabric panels on a wall read as switched-off screens in the previews; padded leather squares read as
  soundproofing.
- Every `--export` that changes meshes bumps the version from the committed scene module. After a scratch export,
  `git checkout HEAD -- src/server/Maps/Scenes/<Venue> src/shared/ImportVersions.luau` before the final export, so the
  user gets one new version, not two.
- WallClock's pivot is its middle (ModelCatalog pivot "centre"): placed by a base height it hung half over the glass
  under a lintel, and check_v2 called it floating.
- Meeting-set props (BookcaseTall, FloorGlobe, DrinksTrolley, Sideboard, WallClock, ClubChair) stand in no other case
  map, so the Agency may use them under the own-furniture rule; the director's steel ArchiveShelf row is now walnut
  BookcaseTall.

**Why:** the user asked (2026-11-05) for every map brought up to the remade lobby's finish, slowly and judged in each
map's own preview views. **How to apply:** dress the next rooms with these kits; check `art/export/scenes/<Venue>.json`
finds for zfight/stretch in the rooms you touched after each export. Related: [[skyline-facades]],
[[floor-change-walls]], [[lighting-rework-2026-11]], [[own-furniture-2026-11]], [[check-v2-needs-venue-export]].
