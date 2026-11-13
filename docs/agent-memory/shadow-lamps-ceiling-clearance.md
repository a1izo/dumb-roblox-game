---
name: shadow-lamps-ceiling-clearance
description: "A shadow-casting spot goes DARK within ~1 stud of a ceiling and is ~3x dimmer than the same spot without shadows: how shadows are built into the pools now (2026-11-13)"
metadata:
  type: project
---

Found 2026-11-13 in a Studio play test at QL21 (HQ's bullpen, one pool alone on a grey pad with every other light off):

- A SpotLight with Shadows = true that hangs less than about a stud under a ceiling face lights NOTHING. Dark at 0.8 under
  the ceiling, lit at 1.1. HQ's pools hung 0.5 to 0.7 under it. This is the "walk near a lamp and it turns off" bug of
  2026-11-01, whose cause was "not known".
- A shadowed spot lights its floor at about a third of what the same spot does without shadows (8 against 24: equal).
  A PointLight with shadows lit fine too but was not tried for pools.

How the game does it now: `lightbook.pool(..., shadows=True)` hangs the lamp SHADOW_DROP (1.0) lower and writes
shadows = true; SceneBuilder (SOFT pools) builds such a pool SHADOW_GAIN (3) brighter and tags it LShadowGain;
LightingController gives Shadows only to the nearest `keyLights` of the lamps BUILT with them (as before) and divides
the gain back off any that are not keys (`brightnessOf`). Pick the lamps in the venue files: Agency
`fit.ceiling_lights(..., shadows=[points])`, Campus `fit.panel(..., shadows=True)`, Tokyo `kit.tube_light(shadows=...)`
and the arcade's pendants. One or two a room, never two within 20 studs. Never a flickering lamp (pool() drops it).

**Why:** shadows are what ground furniture and people; the lamps could not have them for 12 days.
**How to apply:** a new fitting that should cast shadows hangs >= 1.5 under its ceiling face. Measured on this machine:
the nearest 10 shadow lamps held 60 fps in HQ's bullpen at QL21 (the presets only ever key 4 to 6, Low graphics 2).
Related: [[lighting-rework-2026-11]], [[studio-frame-rate-measure]].

Point lights too (2026-11-13, later): HQ's two interview-room pendants (a point light 5 studs under the ceiling, range 15)
are built to cast shadows (`kit.pendant(..., point=True, shadows=True)`). A shadowed point light was NOT dark: alone in the
room it threw the table's, the chairs' and the cuffs' shadows across the floor and the walls fell dark, and the room's
white floor, blown out by the same lamp without shadows, stopped being white. No gain is needed for them (SceneBuilder
tags only the spot pools). The two lamps are 15 studs apart, inside the 20-stud rule's spirit only because each is in its
own room.
