---
name: studio-no-screen
description: "Reading and testing the real Team Create place with no screen control: a temporary plugin in a second, minimised Studio; what it can't do; never accept a Rojo diff holding someone's unpushed work"
metadata:
  node_type: memory
  type: reference
  modified: 2026-11-01T05:30:00.000Z
---

Screen control shares the person's one mouse and keyboard and needs Studio in front, so they lose their PC and keys get
mixed (2026-10-31: Ctrl+A and Ctrl+Return arrived as plain "a" and "r" while they typed, and a virtual desktop would not
help). A plugin in a second Studio needs none of that. Tested 2026-11-01, Roblox running beside it the whole time.

**How:** put a temporary plugin in `%LOCALAPPDATA%\Roblox\Plugins\` (a plain `.lua` file), start
`RobloxStudioBeta.exe -task EditPlace -placeId 130650608236392 -universeId 10767766818` with `-WindowStyle Minimized`,
keep its windows (and its play test's) minimised with `ShowWindow(h, 7)` (SW_SHOWMINNOACTIVE: the window in front stays
in front), and read `print`s from that Studio's newest `Roblox\logs\*_Studio_*_last.log`. Then close that Studio and
delete the plugin.

- Guard the plugin: `game.GameId ~= 10767766818` returns. It also loads in play-test data models, so branch on
  `RunService:IsRunning()` / `:IsServer()` / `:IsEdit()`.
- A plugin reads every script's `.Source` and the imports (`*_Version_*` markers under workspace).
- A real play test: `StudioTestService:ExecutePlayModeAsync({})` from edit mode, `:EndTest("done")` from the server side.
  The spec suite runs in it with the real imports, so this is the only headless way to test code that needs them (the
  rojo-built test place has none, so `Suit.hand`'s imported fist never runs there). Mute the Studio's audio session, or
  the game's music plays over theirs.
- Studio only loads plugins on start: a new or changed file does nothing to a Studio already open ("Hot reload ... not
  actually enabled" in its log).
- Opening the place a second time makes the same account's Studio already in it leave the session and go back to its
  start page. Nothing is lost (the edits are in the Team Create session), but it stays open and may not close by itself.

**A few scripts into the place without Rojo (2026-11-06):** generate a one-shot plugin that holds main's text of each
script in a long string plus the hash of the version it replaces, and calls `ScriptEditorService:UpdateSourceAsync` only
when the place's `.Source` still hashes to that old version (else it warns SKIP: someone's live work). Start the place's
Studio minimised so it loads, read its `[tag]` lines from the newest Studio log, then delete the plugin file. Team
Create keeps the edit: a close and reopen showed both scripts at main's hashes, with no File > Save.

**Before every launch, look for a Studio already in the place** (`Get-Process RobloxStudioBeta`, its command line):
the user may have reopened theirs since the last check. On 2026-11-06 a launch 17 minutes after one check sent the
user's own Studio back to its start page.

**What still needs the screen:** the 3D importer's dialogs (about 20 s each, then the upload runs by itself) and File >
Save to Roblox. Check first whether they are needed: the other developer often imports the new versions into the shared
session themselves.

**Rojo in the shared place:** before accepting a sync, read its whole list. On 2026-10-31 it wanted to change
`Shared.Assets` (sound ids kept in a local, never-committed Assets.luau) and `Kit.*` (UI not pushed yet): the place held
the other developer's live work, and Accept would have reverted it to our checkout. Abort. Their sync carries our
pushes once they pull, so check the place's `.Source` before assuming a sync is needed at all.

Related: [[parallel-agent-merges]], [[protect-user-assets-edits]], [[studio-cutscene-testing]].

**Every changed script at once (2026-11-08):** the same one-shot plugin, generated for every `src` file changed since
the place's last sync commit (`git diff --name-only <last> HEAD`), each with every hash its file has had lately (blob
ids from `git log --raw`, read in one `git cat-file --batch`): 61 updated and 8 created in one minimised launch, 0
skipped. New scripts are made with `Instance.new` + `UpdateSourceAsync`. Files deleted in the repo are only reported.
The place's scripts are at main 90a60109 (the lobby's old Geometry `Colliders1`/`Colliders2` modules are left in it,
unused).
