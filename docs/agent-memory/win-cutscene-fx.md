---
name: win-cutscene-fx
description: 2026-11-15 the eight win cutscenes re-acted (no mirrored arms, wind-ups, endings held 1.6 s+) and given a WinCuts "fx" act that plays the VFX kit from plain data; kinds, how `on`/`place` work, and how to check a clip's end hold
metadata:
  type: reference
---

The user (2026-11-14, item 11): every cutscene at the death scenes' level of VFX, scenarios and animation. The eight
win cutscenes (`src/shared/Cinema/WinCuts.luau`, clips `art/scripts/emotes/wins.py`) were the first after the deaths.

- **The "fx" act** (`WinCinema.ACTS.fx`): `{ at, act = "fx", kind, place | on (+ offset), face, color, scale, seconds }`.
  `place` is the star's floor frame; `on` is a set part or prop's name or the star's body part ("Head", "Right Arm"),
  moved by `offset` (in the floor frame's axes, not the part's). Kinds: impact, glint, pillar, wave (flat ring),
  bolt (needs `to`), light, sparks, bloom, ring (camera-facing), dust, and held ones over a `box` for `seconds`: embers,
  motes, ash, drizzle. `WinCuts.spec` checks the kind and that it plays at something. Plain data, so
  `emotemeta.read` (review_win.py) still parses the file.
- **The clips**: Tool 1 (`check_motion.py`) passes all eight. Mirrored arms were two hands behind the back or flat on a
  table; now one arm works while the other rests. Wind-ups only count when the pull is 5-50% of the move and the move
  finder sees a reversal; a hand already at full reach (an armrest) barely turns, so pull it sideways, not further out.
- **The ending hold** (the plan's 1.5 s): `bigmoves.py`-style check = from the end back, every acting joint within 6
  degrees of its final pose. Land the final pose by about 6.3 s and only breathe after it (1-3 degrees).
- Retimed with their clips: finalPageBureau (shut 5.2, sealed 5.85, standing 6.4), newWorld (the spread at 5.62),
  newWorldBureau (down to the chest 6.05), checkmateCoven (no walk-off: pivots at 5.86-6.32 and faces the camera).
- In a match the "<side> wins" card still runs from the cue's start ([[win-cutscene-name-card-timing]]).
- Redone again 2026-11-24 (cameras, key/rim lights, six clips re-acted, the old acting kept as wins_old.py): [[win-cutscenes-redo-2026-11-24]].
