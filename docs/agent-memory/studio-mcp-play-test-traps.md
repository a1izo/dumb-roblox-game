---
name: studio-mcp-play-test-traps
description: Studio MCP play-test traps found 2026-11-14: execute_luau's require gives module COPIES, screen_capture shows no 3D when Studio is not in front (15 fps), Debug replies did not come back; what works instead
---

Tried to watch the Luau match scenes (verdict, arrest, outro, Oculus deal) through the Studio MCP in the owner's place
(Edit mode, free, the owner had said yes to MCP use). It did not work; what was learned ([[studio-mcp]],
[[studio-cutscene-testing]]):

- **`require` in `execute_luau` returns a private copy of each game module** (the Client and Server data models both).
  `require(...Services.Match).active` is false, a `Bots.add(5)` adds bots the game does not know, and
  `MatchmakingService.startNow` returns false because the copy's loop never ran. Reading or driving game state by
  requiring services is useless. Use what the game really shares: instances in the workspace (`Bot1`, `LGameMap`),
  the remotes in `ReplicatedStorage.LGameRemotes` (find them as instances; `Net.event("State")` throws on the copy),
  and `_G`, which IS shared between `execute_luau` calls (a probe can park results there; the tool returns "no output"
  for a script that waits long, so start work with `task.spawn`, return at once and read `_G` in the next call).
- **`screen_capture` in Play returns no 3D** when Studio is not the window in front: a dark frame with only Roblox's
  top-left buttons, and `RenderStepped` ran at 14.9 fps. Full frames need Studio in front (the owner's screen).
- **Firing the `Debug` remote from the client reached the server but no reply came** (no `Notify`, no `Cue`, no
  snapshot in 8 s), so the match cues could not be fired from the MCP. The fill bots and start match calls seemed to run
  (bots stood in `workspace`, `LGameMap` built); the cue calls did not.
- A match started this way plays its own intro and briefing cutscenes on the same camera for a minute; a probe that also
  takes the camera reads nonsense. Wait them out, or use `skipCutscenes`, before measuring.
- Stop the play test you started (`start_stop_play false`) and confirm `get_studio_state` says Edit before leaving.

**How to apply:** for a look at a Luau match scene, either ask for the owner's screen (Studio in front, then
`screen_capture` and the debug panel's Show tab), or have the owner play the cue and send what they see. Do not spend a
session on the MCP route alone.
