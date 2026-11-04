---
name: check-v2-reach
description: check_v2 "ok" does not mean every place can be walked to; its corner walk snaps to the nearest reached spot. List the anchors that must be reachable in the venue's CHECKS["reach"]
metadata:
  type: feedback
---

check_v2's walk times go between the reached walk spots nearest each corner (`corner_times`, `nearest_node`), and its
"reach" line only counts spots. So a closed-off room or a raised area nobody can climb onto passes silently: on
2026-11-04 the lobby printed "Lobby: ok" while the Academy's grotto was shut (foot walls of the rocks at its mouth) and
both plateaus' tops lay over the upper half of their causeways' steps (a 4-stud step).

`anchors_reached` (2026-11-04): a venue's `CHECKS["reach"]` names anchors (or prefixes ending in `*`); each must have a
reached walk spot within 4 studs across, from 9 under it to 3 over it. The lobby lists every game's anchor.

**Why:** a map can look right in renders and pass every other check while a game in it cannot be reached.
**How to apply:** when a venue gains a place people must get to (a station, a game, a room), add its anchor to
`CHECKS["reach"]`; after moving rocks, walls or floors, export and run check_v2. Related: [[realm-rock-kit]],
[[lobby-remake-v2]].
