---
name: skyline-facades
description: The city beyond Agency, Campus and Tokyo is built by maps/skyline.block in four night facade textures (maps/facades.py); how to tune it within the triangle budgets
metadata:
  type: project
---

Since 2026-11-05 every building past the maps' edges (Agency's view down from 38F, the blocks round the Campus walls,
Tokyo's city past its streets) comes from `maps/skyline.block`. They used to be flat-coloured boxes with lit quads
pasted on, and that read as boxes next to the remade lobby.

- **Facades.** `maps/facades.py` draws four night facades over photographed scans (NightOffice ribbon glazing,
  NightFlats with balconies, NightBrick with stone sills and lintels, NightTile cladding). One repeat is two 6-stud
  bays by one 12-stud floor, 512 px, registered in `scanlib.LIBRARY`. A wall is ONE face whatever its windows: the bay
  grid is fitted to its length (`skyline._bays`), and its floors line up with `buildings.floor_levels`.
- **Lit windows** are Neon quads (WindowLit / WindowCool) laid exactly over each style's glass (`skyline.WINDOWS`, the
  same numbers as `facades.STYLES[...]["glass"]`). Change a style's glass and the glows follow; keep the openings
  symmetric in their bay (the glows assume it). On NightOffice a lit run is one glow however many bays it spans, so
  its runs are long and cheap; on the punched styles each window is its own glow.
- **Budget knobs.** `lit` is the share of windows lit; `most` caps the glows per building and then picks them at
  random over the whole building (without the pick they all landed on the lowest floors). `detail` 0/1/2 adds a
  cornice, a lift room, then a water tank and plant. Each venue's caller sets these by distance.
- Costs measured 2026-11-05 (map triangles): Agency far blocks 28,852 (were 29,090), Campus 38,850 (were 30,940),
  Tokyo 67,850 (were 104,586: it had one quad per lit window). Tokyo has about 44,000 triangles free since; Agency
  about 2,700, Campus about 7,800.
- Each building draws from its own `random.Random(rng.random())` so tuning a building never moves the layout.

**Why:** the user asked (2026-11-05) for the lobby's level of quality everywhere; the skyline is in nearly every
outdoor view of three maps.
**How to apply:** for the far city call `skyline.block` (or `buildings.far`, which wraps it); never draw window quads
by hand out there. Measure a change's triangles per venue before exporting (each venue's budget is in
`scripts/budget.py`). Related: [[lighting-rework-2026-11]], [[mesh-triangle-limit]].
