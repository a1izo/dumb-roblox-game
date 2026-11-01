---
name: floor-change-walls
description: Owner's rule (2026-11-01) - wherever a floor's material changes there is a wall (with a doorway where people pass), except HQ's Bureau sign wall
metadata:
  type: feedback
---

Wherever one floor finish meets another, the owner expects a wall between them (with a doorway where people walk
through); open seams read as "missing walls". The only exception they named is HQ's Bureau sign wall in the lobby,
which is fine as it stands.

**Why:** 2026-11-01 play test of HQ: the lobby's marble ran straight into the lounge's herringbone, the corridor's
carpet into the lobby and the 39F deck, and the analysts' carpet into the corridor, with no wall; the meeting bell and
the planters, placed "against the wall", stood in the open.
**How to apply:** after any layout change, sweep every floor boundary against the partitions on the same level (a
scratch script that samples region edges and checks fit.partition calls per y0 did it for HQ), and keep props meant
to stand against a wall within a wall's reach. Related: [[lighting-rework-2026-11]], [[map-remake-project]].
