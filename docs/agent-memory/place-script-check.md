---
name: place-script-check
description: "Before a Rojo sync into the shared place, hash every script on both sides and match each stale one to a pushed commit; the Assistant (MCP) cannot fetch localhost"
metadata:
  type: reference
---

How the 2026-11-06 sync was checked before pressing Accept (45 scripts updated, 9 removed, nothing of anyone else's
lost):

1. In Studio, by the MCP's `execute_luau`: walk the Rojo roots (ReplicatedStorage.Shared, ServerScriptService.Server,
   StarterPlayerScripts.Client, ReplicatedFirst.DGCover, StarterCharacterScripts.Animate) and return one line per
   script, `path=length:hash`. The hash is an Adler-style sum over the bytes (`a = (a + byte) % 65521`,
   `b = (b + a) % 65521`, `b * 65536 + a`), read with `buffer.fromstring` / `buffer.readu8`; 519 scripts take a
   few seconds with a `task.wait()` every 40.
2. Hash the repo the same way, keyed by the place path Rojo gives each file (`init*.luau` names its folder;
   `.server`/`.client`/`.spec` endings as Rojo reads them). The tool result is long: read it back out of the
   session transcript (`.jsonl`) instead of copying it.
3. For every script that differs, look for the place's hash in that file's `git log` (`git show <commit>:<path>`).
   All found = the place is only behind, so the sync is safe. One not found = someone's live, unpushed work in the
   place: stop and ask. Place-only scripts: check `git log --diff-filter=D`; deleted in a pushed commit = stale.
4. Then the Rojo plugin's own list (Connect, read the whole list, Accept) should show exactly that set.

Traps:
- The MCP's `execute_luau` cannot reach the PC: `HttpService:GetAsync("http://localhost:...")` fails with "domain
  ... is not in the Assistant HTTP allowlist". Files can't be pulled into Studio that way, so a script sync still
  needs the Rojo plugin (one click on its Connect toast, then Accept).
- `assets/*` folders carry `ignoreUnknownInstances`, so Rojo leaves imported models there alone.
- The 3D importer's yellow triangle on Maps_Lobby is only "File Dimensions" (3090 x 943 x 3044 studs); it imports.

Related: [[studio-no-screen]], [[studio-mcp]], [[pictures-by-mcp]].
