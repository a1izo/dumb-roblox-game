---
name: protect-user-assets-edits
description: "Never format, stage, checkout or revert the user's own edits in src/shared/Assets.luau (music ids)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: e0a8eefd-e2a0-48a4-ab1d-6b46638f9f43
  modified: 2026-09-25T23:22:20.454Z
---

The user edits `src/shared/Assets.luau` by hand (music ids, 4-space indentation) and leaves it uncommitted. Never run stylua on the whole `src` tree while it has local changes, never `git checkout`/`git restore` it, and never stage it in commits (use `git add -A -- . ':!src/shared/Assets.luau'`).

**Why:** On 2026-09-26 a `stylua src` reformatted the file and a follow-up `git checkout` to undo that wiped the user's 16 music ids; they had to be rebuilt from the session transcript.

**How to apply:** Format explicit file lists (`git diff --name-only | grep -v Assets.luau | xargs stylua`) and check `git diff --stat src/shared/Assets.luau` before and after risky commands. See [[music-audio-permissions]].
