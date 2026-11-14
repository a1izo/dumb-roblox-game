---
name: studio-mcp-play-test-traps
description: Studio MCP play-test traps (2026-11-14): execute_luau's require gives module COPIES, screen_capture needs Studio in front, and with both handled the Debug cues and screenshots DO work; the recipe is in the match-scenes audit
---

Tried three times on 2026-11-14 to watch the Luau match scenes (verdict, arrest, outro, Oculus deal, Manual shot)
through the Studio MCP in the owner's place. The first try got nothing, the third saw five of six scenes, so the
route works once these are handled ([[studio-mcp]], [[studio-cutscene-testing]],
[[studio-capture-disturbs-camera]]):

- **`require` in `execute_luau` returns a private copy of each game module** (the Client and Server data models both).
  `require(...Services.Match).active` is false, a `Bots.add(5)` adds bots the game does not know, and
  `MatchmakingService.startNow` returns false because the copy's loop never ran. Reading or driving game state by
  requiring services is useless. Use what the game really shares: instances in the workspace (`Bot1`, `LGameMap`),
  the remotes in `ReplicatedStorage.LGameRemotes` (find them as instances; `Net.event("State")` throws on the copy),
  and `_G`, which IS shared between `execute_luau` calls (a probe can park results there; a script that waits more
  than a few seconds may return "no output", so start long work with `task.spawn` and read `_G` in the next call; waits
  up to 17 s did return fine in 2026-11-14's third try).
- **`screen_capture` in Play returns no 3D** when Studio is not the window in front: a dark frame with only Roblox's
  top-left buttons, and `RenderStepped` ran at 14.9 fps. With Studio in front (the owner's "screen ok") it is 60 fps and
  the stills show the game. `AppActivate(<pid>)` returned True on the third try.
- **The `Debug` remote works** (an earlier note here said it did not): `fillBots`, `startMatch`, `skipTo`, `pause` and
  `cue` all took effect once a match with bots was running. The earlier failure was a match that had not started yet.
- A match started this way plays its own intro and briefing cutscenes on the camera for about 20 s, and `CameraType`
  reads `Custom` while they do. Wait on the cue's own clock, not on the camera type.
- Bots wander and the phase timer runs: skip to `Meeting`, send `pause` once (a toggle; it survives `skipTo`), or
  everything moves under the cue.
- **"Foreground" by the OS is not enough** (2026-11-15): with the Claude app on top, `AppActivate` returned False, the
  game ran at 12 to 16 fps, `execute_luau` on the Client failed with "Target is not reachable" and `screen_capture` gave
  only Roblox's top-left buttons, although the foreground window's title read Studio. Fix: ask the user to click the Studio
  window, then check 60 fps with a 2 s `RenderStepped` count before any still. Do not keep stealing the focus: do the
  non-Studio work first and run the stills in one batch.
- **A play test cannot run new repo code.** The place's scripts are older than main and writes into the shared place are
  refused ([[studio-shared-place-write-blocked]]); the Client's `require` gives private copies whose `Cinema.letterbox`
  errors. To judge a lighting or look change, force its resolved values onto `Lighting` and the grade each frame (a
  `BindToRenderStep` after the controller) and drive `BookStage` from a copy with a `CameraDirector` copy's token.
- Stop the play test you started (`start_stop_play false`) and confirm `get_studio_state` says Edit before leaving.

**How to apply:** to look at a Luau match scene, ask once for "Studio in front, screen ok", then follow "How to watch
them" in [animation-audit-match-scenes-2026-11-14.md](../handoff/animation-audit-match-scenes-2026-11-14.md): it has the
fill-bots / skipTo / pause setup, the clock and logger, how to take a still at a chosen second, and how to send a cue
with full data from the Server DM.
