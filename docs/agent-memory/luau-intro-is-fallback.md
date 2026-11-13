---
name: luau-intro-is-fallback
description: Presenters/Intro.luau (the Luau case opening with vignettes and the falling Grimoire) plays on no live map, since all three have a Blender intro; do not spend time polishing it (2026-11-14)
---

`RoundService.INTRO_SHOTS` names a Blender intro for every live map (UniversityCampus = IntroCampus, TokyoDistrict =
IntroTokyo, TaskForceHQ = IntroAgency), and `Intro.luau` hands over to `ShotPlayer` whenever `data.shot` exists, the
debug panel's intro button included. The Luau version (establishing shot, four 1.6 s vignettes, the book falling onto
the landmark) only runs for a map with no exported intro. Found 2026-11-14 in the audit of the match scenes built in
Luau, [animation-audit-match-scenes-2026-11-14.md](../handoff/animation-audit-match-scenes-2026-11-14.md).

**Why it matters:** an audit of "the intro" that reads this file is auditing nothing a player sees. **How to apply:** to
change what a player sees at the start of a match, edit the map's Blender shot (`art/scripts/cinema/shots/intro_*.py`);
touch `Intro.luau` only when a new map ships without one. The other five Luau match scenes (verdict, arrest, outro, the
Oculus deal and the Manual's writing shot) are all live; their faults are in that audit file.
