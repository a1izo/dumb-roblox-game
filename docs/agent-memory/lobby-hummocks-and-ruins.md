---
name: lobby-hummocks-and-ruins
description: 2026-11-14 the lobby's open ground rises in real hummocks (ground.py hill/slabs/lift: terrain ramps under them) and carries wreckage (dressing.ruins); what keeps off what, and the checks' terrain flag
metadata:
  type: project
---

Asked 2026-11-14: "make the terrain better not just straight (in the lobby)", "make everything more ruined".

- `lobby/ground.py` `Field.hill`: hummocks up to HILL (3.6) studs in the open of the basin, in patches with flat between,
  0 within HILL_PAD of anything level (level_places), every other footprint (`quiet_places`), every hole, every rock's foot
  and every ruin (`dressing.STOOD`), full height HILL_FADE (12) further out. Added into `height`, so the relief mesh, the
  backing sheet and the rest follow.
- They are solid: `slabs` lays one `s.ramp` per 8-stud cell on the ground's own plane (flagged `terrain`, query on), which
  the game builds as its usual Ramp parts. The flat floor at 0 stays under them, so the relief only ever rises.
  check_v2's stair_ends skips `terrain` ramps. A level stretch is a ramp of almost no slope, not a collider (a collider
  there reads as a wall to "stands in a wall or collider").
- `lift` raises every non-rock prop standing at the level onto the hummock under it (grass, bones, flowers). The float
  finder still names a few of them (a known false report).
- `dressing.ruins`: RUINS lists wanted spots (x, z, lie, kind: column, colonnade, wall, slabs); each takes the nearest
  clear ground within 30 studs (16 of 30 stand), built from RuinStone with obox/tube/cylinder and colliders. A column's
  stump needs its top cap (the oneside finder).
- Budget: +0.2 MB allowance for the Lobby (art/budget.json, 2026-11-14). Maps_Lobby v48.

Related: [[lobby-ground-relief]], [[lobby-remake-v2]], [[check-v2-reach]].
