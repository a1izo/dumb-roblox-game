---
name: vfx-pilot-booth-capture
description: The effects pilot (2026-11-18): Vfx/Pilot.luau flags, what each piloted effect scored, and how pictures of the booth were taken by the Studio MCP (explicit camera on screen_capture works)
---
**Flags:** `src/client/Presentation/Vfx/Pilot.luau`, `Pilot.on = { impact, menacing, cover }`. impact = `DeathFx.burst` plays
`Fresh.impact` (heavy for deaths, grey with a red edge); cover = the Black Mirror (the dearest legendary Manual cover) reads
`CoverTells.STYLES.mirror` through a metatable at call time, so the flag can be flipped in a play test; menacing = the first
pose's haze (Poses.luau, `fresh = true` on that entry only) and is OFF (worse report, nothing visible in the booth).
Flipping a flag in a play test needs the PlayerScripts copy of Pilot (the same table the game uses).

**Effect report, before to after** (booth, dark): death_floor FAIL (no gather, pops, no core, 103 particles vs 60, 9 emitters vs 6)
to FAIL (no gather, hit 0.07 s off because the new hit comes 0.06 s after the call, 7 emitters vs 6; peak 31 particles);
emote_menacingPose FAIL (24 emitters) to FAIL (26 emitters, 3 lights); cover_mirror FAIL (all dots, no shape) to PASS.

**Taking pictures through the MCP (works, 2026-11-18):** Studio must be the foreground window (SetForegroundWindow plus a
tap of Alt from PowerShell worked where AppActivate said False; render drops to 15 fps otherwise, but stills still showed 3D).
Give `screen_capture` an explicit `camera_position` and `look_at_position` (the booth's close camera is ORIGIN+(0,3.9,8.5)
looking at ORIGIN+(0,3.2,0), ORIGIN = 6000,650,6000): the capture takes that view even though the player's camera is
elsewhere. Do `fx.at(id, t)` in one `execute_luau` (spawn it and poll until it returns) and the capture in the next call.
The booth dummy is solid black and a black book or smoke on it, or on the dark backdrop, is nearly invisible: judge on the
lit backdrop. The cover booth book faces away from the +Z camera; its tell is tiny. Sheets are built with .NET System.Drawing
from PowerShell (Blender's Python has no PIL): `art/export/previews/vfx/pilot/raw/make_sheets.ps1`.
