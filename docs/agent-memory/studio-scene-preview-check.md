---
name: studio-scene-preview-check
description: How to look at a scene death's 2D layer (HUDs, kanji, battle screens, end text) in the user's own Studio with no harness: a temporary LocalScript, an attribute, screen_capture; 3D does not show
metadata:
  type: reference
---

Found 2026-11-14 when the harness could take no pictures (the user's Roblox player was open). In the user's Studio,
through the Studio MCP:

1. In the Edit datamodel, make a LocalScript `DGTempScenePreview` in StarterPlayerScripts (ScriptEditorService
   UpdateSourceAsync) that requires Client.Presentation.WinCinema and calls `WinCinema.preview("scene:" .. name)` when
   `workspace:GetAttribute("DGPreviewScene")` changes.
2. start_stop_play, then from the Server datamodel set the attribute, `task.wait(t)` to the moment wanted, then
   `screen_capture`. Only the UI shows (no 3D in Studio's captures), which is exactly the scenes' HUD layers.
3. To measure something too quick to catch (a 0.5 s slash), poll PlayerGui from the Client datamodel each frame.
4. ALWAYS stop play and destroy `DGTempScenePreview` before save_place (check no leftovers).

Also: execute_luau's Server and Client datamodels are separate VMs (fresh module copies: DataService.get is nil there,
Net remotes from there do nothing). To test a client system, make instances it reacts to (tags, attributes) or send
real input with user_keyboard_input. TweenService did not advance in the harness on 2026-11-13/14 (it does in Studio).
Related: [[studio-cutscene-testing]], [[imports-by-open-cloud]].
