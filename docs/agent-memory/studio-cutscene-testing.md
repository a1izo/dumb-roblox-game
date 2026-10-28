---
name: studio-cutscene-testing
description: "How to inspect a Blender cutscene in Studio via computer use (command bar debug cues, debug camera) and the game-vs-Blender gaps found 2026-10-28"
metadata:
  node_type: memory
  type: reference
  originSessionId: 77501874-126d-4d88-adac-442fa1338f87
  modified: 2026-10-28T04:48:27.498Z
---

Checking a shot in Studio (user allowed screen use 2026-10-28):
- Command bar: multi-line, runs with the Run button (Enter only adds a line). Client tab = client context. Clipboard typing once pasted stale clipboard text: clear the bar (ctrl+a, Delete) and re-type.
- Debug cues without the panel (a case's shoulder cam locks the mouse, so panel clicks miss): `require(game.ReplicatedStorage.Shared.Net).event("Debug"):FireServer("cue", {kind="shot", extra="IntroTokyo"})`; also "nextMap" {mapId="TokyoDistrict"}, "fillBots" {total=6}, "startMatch", "endMatch". "pause" TOGGLES (call once). Shots only play in a match; pause the match first or the next phase's cutscene takes the camera.
- Slow motion: `game.Players.LocalPlayer:SetAttribute("ShotRate", 0.25)`; the shot clock shows on top.
- Look anywhere during a shot: BindToRenderStep at Camera+10 setting CurrentCamera.CFrame relative to a model found in workspace.DeathsGambitStage (props/actors are client-only there).
- Output: Window > Output.

Game vs Blender gaps found: NOT the Grimoire's facing — a half turn added for it (MANUAL_TURN) was a misread (from a camera in front of an actor, their right is screen-left) and was removed 2026-10-28; the game book matches Blender; props got no catalog lamps in cutscenes (ShotPlayer now adds them); map geometry is merged per material, so a shot cannot hide one part of the map — change the map source instead. Related: [[cutscene-quality-bar]].
