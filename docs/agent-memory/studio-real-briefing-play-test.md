---
name: studio-real-briefing-play-test
description: How to play a role cutscene through the REAL briefing in the owner's place with the Studio MCP (forceRole, fillBots, startMatch), log the camera and effects, and sample an actor's body every frame; and how Studio was reopened onto the place from its start page (2026-11-15, RoleAce)
metadata:
  type: reference
---

The debug cue (`Debug:FireServer("cue", {kind="shot", extra=Name})`) plays a shot with `ShotPlayer.play(name, {cast})` only.
The real briefing (`BriefingScreen.show`) also passes `at`, `length` (stretched to the voice clip), `onCard` and a `stop` that
checks the phase, then shows the role card. To run the real one for a role:

1. `f = game.ReplicatedStorage.LGameRemotes` from the **Client** DM of `execute_luau`; `f.Debug:FireServer("forceRole",
   {userId = lp.UserId, role = "L"})` (the next match only; `"L"` is Ace, see `RoundService.ROLE_SHOTS`), then
   `fillBots {total = 6}`, wait 2 s, `startMatch`. The match plays its map intro first (about 30 s, `phase=Intro`), then
   `phase=Briefing` plays the role's shot, then the role card (about 6 s), then `Investigation`.
2. A logger in the same call (`task.spawn`, results parked in `_G`, read in the next call): each second `f.GetSnapshot:InvokeServer()`
   (`state.phase`, `private.role`), the camera's `CameraType` and `FieldOfView`, the camera's children that are not `LampHaze`
   (a shot's `ShotGrade`, `CinemaFocus`, `CinemaTint`, `CinemaCctv` must all be gone after it), the descendants of
   `PlayerGui.DeathsGambitCinematic` (about 1 when the letterbox is off), `PlayerGui.DeathsGambitOverlay.Briefing.Visible` (the role card)
   and `PlayerGui.DeathsGambitHUD.Enabled`. In the real run for Ace everything came back at the end: letterbox, effects, HUD, the card.
   In a case the game's own camera reads `Scriptable` again in free roam: that is not a stuck cutscene.
3. **Sampling an actor** (to measure a walk): the stage is `workspace.DeathsGambitStage.Set`; an actor is `Actor_<name>` (a bot is
   `Actor_Bot1`); a prop it holds is a descendant (`TeaTray`); the cast props stand beside them (`Teacup`). A `RenderStepped`
   connection can log `HumanoidRootPart.Position`, its yaw, each leg's position relative to the root, the torso's lean and the tray's
   `CFrame.UpVector.Y`. Speed, the cycle and the stop all show in those numbers.
4. Stop the play test you started (`start_stop_play false`) and check `get_studio_state` says Edit.

**Studio at its start page** (`list_roblox_studios` says "Place is not open"): `Start-Process RobloxStudioBeta.exe -ArgumentList
-task,EditPlace,-placeId,130650608236392,-universeId,10767766818 -WindowStyle Minimized` opened the place in the Studio that
was already running (a second, empty start-page process stays behind); the MCP then listed the place. Check `Get-Process
RobloxStudioBeta` first and never do it while someone's Studio is in the place. The Studio id changes every time.
Killing Blender renders by command line was refused by the classifier: let a stale render finish and render again.
Related: [[studio-mcp-play-test-traps]], [[studio-cutscene-testing]].
