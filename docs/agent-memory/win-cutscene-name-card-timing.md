---
name: win-cutscene-name-card-timing
description: In a match the win cutscene's "<side> wins" card is on screen from the cue's start, not timed to the ending pose; WinCinema keeps the last frame only 0.35 s; measured end holds of the 8 win clips
---

Found 2026-11-14 (Stage 3 inventory). The plan asks each winning cutscene to end on a pose that holds 1.5 s or more "as the winning side's name
is written in". In the code the name is not written on the ending: `Presenters/Outro.luau` plays the cut (`WinCinema.play`, the lead's
cutscene, on every screen) from the cue's start and shows the typewriter card `"<side> wins"` (`Cinema.card`, y 0.74) from the first second
until the cut is stopped (`firstShot` seconds in), then the names are written in the Manual. `WinCinema.TAIL` holds the last frame 0.35 s.

Measured from the exported clips (upper body within 6 degrees of its final pose, counted back from the end): winFinalPage 2.0 s, winCheckmateCoven 1.7,
winCaseClosed 1.5, winCaseClosedCoven 1.5 (1.47), winNewWorldBureau 1.4, winFinalPageBureau 0.9, winNewWorld 0.8, winCheckmate 0.8. These are interim
numbers, not the motion report's.

**How to apply:** when a win cutscene is re-acted, hold its ending pose the 1.5 s inside the clip (the 8 s length is fixed by the cut data); if the
owner wants the card on the ending pose, that is a change in `Outro.luau`, so ask first. Inventory:
`docs/handoff/animation-inventory-stages-2-4-2026-11-14.md`.
