---
name: death-cutscene-bot-victim
description: 2026-11-15 "the death animation doesn't play in a match": Fallen.bodyOf only knew real Players, so a debug bot's death had no body to film (no table cutscene, no body-from-above card); how it was reproduced and the probe recipe
metadata:
  type: reference
---

**Cause.** `Presentation/Fallen.bodyOf(userId)` read `Players:GetPlayerByUserId`, which has nobody for a test bot (a
negative user id). `Presenters/Death` films `Fallen.bodyOf(data.userId)`, so for a bot victim of a plain cause (heart
attack, disease, accident) it fell through to a bare `task.wait(total)`: the book closed, the camera went straight back to
the player's own, and the wide / push / witness / body-from-above cuts, the red outline and rim light, the cause card and
the dipped lamps never ran. A scene death still played (its set is built far away), but the "body from above" card after it
was skipped. The body itself did fall (ActingController uses `Characters.byUserId`, which knows bots), so the match looked
like "the animation doesn't play". Fixed 2026-11-15: `Fallen.bodyOf` goes through `Characters.byUserId`.

**Who sees it.** Only a match with debug bots (Studio solo tests, the debug panel's fillBots). Real players are real
`Player`s, so a real-player victim already filmed. Do not chase this for a live server.

**Reproduced in the real flow** (the owner's place, Studio Play, bots filled, a match in Investigation): from the Client
datamodel a probe on `RenderStepped` logged the camera every frame while `ReplicatedStorage.LGameRemotes.Debug:FireServer(
"kill", { userId = botId, cause = "Heart attack" })` ran (bot id from `workspace.Bot2:GetAttribute("BotUserId")`). Before the
fix: camera Scriptable on the book stage for about 3.5 s, then CameraType Custom (the player's own camera) for the rest of
the fall, torso Y dropping 2.4 studs. A scene cause ("A broken heart") on another bot ran its scene cell
(camera at about -6000, 650, 6000) for the full 12 s, so scene deaths were never the broken part. `skipTo` to the next
Investigation (`{ phase = "Investigation", round = 2 }`) resets between kills. The place's scripts matched the repo exactly
(19 death-chain files hashed equal), so this was the code players had.

**Not seen:** the fixed cutscene playing. The place's scripts are older than the repo, writes into it are refused, and
`require` in `execute_luau` gives private module copies, so new client code cannot run in the owner's place until the owner's
Rojo sync. What was run on the new code: the old and the new `Fallen` side by side in a Play session I started (bundle via
[spec-bundle-via-rbxasset](spec-bundle-via-rbxasset.md)), a tagged model with BotUserId -1002 in workspace: old `bodyOf` nil,
new `bodyOf` the model, the local player's own character the same in both.

**How to apply:** any new client code that looks a character up by user id must use `Characters.byUserId`, never
`Players:GetPlayerByUserId` alone; `Presenters/Death` has no fallback when the body is nil. After the owner's next sync, kill a
bot with a plain cause and watch for the wide shot, the push to the body and the cause card.

Related: [[deaths-current-state-2026-11-14]], [[studio-mcp-play-test-traps]], [[death-loadout-2026-11]].
