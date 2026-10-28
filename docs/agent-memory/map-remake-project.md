---
name: map-remake-project
description: Inkbound map remake in Blender; revision 2 (2026-09-26) after playtest #1 - compact 400x300 maps, real-scale tall buildings, hand-placed, new assets
metadata:
  node_type: memory
  type: project
  originSessionId: 3775ab85-6cf0-485d-965b-a9e1a8e90d56
  modified: 2026-09-27T11:31:17.860Z
---

Rebuilding all maps (Tokyo, Campus, HQ, lobby, meeting room) with the Blender pipeline in
art/scripts/maps. Plan file: C:\Users\user\.claude\plans\my-current-roblox-game-iridescent-whistle.md

Revision 2 (2026-09-26), after the user playtested the 1000x800 Tokyo pilot and found it way too
big, lamp posts spammed, repetitive (no new assets), ramps poor and buildings tiny:
- round maps ~400x300 studs (~35 s corner to corner); frame rate was fine, no perf budget
- real Tokyo scale: ground floor 14 studs, upper floors 12, windows sized to floors; towers 12-20 floors
- ~12 rich hand-furnished interiors, every station inside one; other ground floors closed shopfronts
- stairs/escalators only (no slopes, ramps, hills); lights only on real fixtures (300-500)
- full new asset set (building kit + ~45 props + station variants); everything hand-placed, no random fill
- Tokyo keeps station (underground platform + train), sakura river through the south third,
  scramble crossing, police box, yokocho + karaoke tower on the far bank, covered shopping street
  + department store; train arrives on a loop, screens animate; signs mostly Japanese
- review flow: top-down plan + massing renders -> user OK -> finished slice (crossing + station)
  -> user imports and walks -> rest of the map

Revision 3 (2026-09-27): layout approved; decorate the whole map in one pass. Every light sits in
a visible fixture (no algorithmic lamp placement, no floating lights). River: water wall to wall,
no stairs down, nobody can get in. Edges: the city carries on past the map; street ends get tall
real barriers (site fence + police tape, modelled in Blender), not invisible walls.
Revision 4 (2026-09-27, plan C:\Users\user\.claude\plans\its-too-bright-in-modular-tide.md): after
playtest #2 the user said layout good, build quality poor. Decided:
- props detailed semi-real, all ~60 rebuilt, approval sheets sent in batches plus an F2 line-up;
- one pass;
- metro: gates lead straight onto switchback stairs (no escalator), dim cool lighting;
- dept store: grand corner entrance;
- fake rooms behind every window, trees with branches + solid clumps;
- vehicles placed properly;
- all interiors refurnished with plan renders;
- workstation screens sit where each prop says.
Status 2026-09-27 evening: revision 4 built, Tokyo check_v2 passes (incl. the new overlap test);
prop sheets (art/export/previews/sheet_*.png) and room plans (room_Tokyo_*.png) sent for review;
user to import InkboundModels_Tokyo.fbx (v2) + InkboundMaps_Tokyo.fbx (v20). The user committed
bbe756e themselves mid-pass; later work is uncommitted.
Lesson: Blender previews missed Roblox-only faults (import turn, glare, void through one-sided
faces), so verify in Roblox terms (calibration per import, opaque backs, lighting per zone).
Next venues after Tokyo sign-off: Ashen Realm lobby, Campus, HQ, meeting room.

**Why:** quality over quantity was the user's explicit direction after playtest #1.
**How to apply:** follow the plan file; see [[maps-not-symmetrical]], [[protect-user-assets-edits]],
[[windows-lf-endings]]. Anything that can't be made to look good gets cut, not shipped rough.
