---
name: windows-lf-endings
description: "On this Windows machine, Python patch scripts must write files with newline=\"\\n\" or stylua flags whole-file CRLF diffs"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3775ab85-6cf0-485d-965b-a9e1a8e90d56
  modified: 2026-09-26T18:36:45.679Z
---

When patching repo files with Python on this Windows machine, open files with
`open(path, "w", encoding="utf-8", newline="\n")`. The default writes CRLF, and `stylua --check src`
then reports a whole-file diff. Also, bash heredocs containing some quote mixes fail in this
shell; writing a patch script to the scratchpad and running it is reliable.

**Why:** happened during the map remake ([[map-remake-project]]); 14 files had to be converted back to LF.
**How to apply:** use newline="\n" in any Python write; when formatting, run stylua on the changed files only,
never on src/shared/Assets.luau ([[protect-user-assets-edits]]).

Also: writing a repo file from Python sometimes fails once with OSError Errno 22 (a transient
lock on Windows); retry the write after a second or two rather than treating it as a real error.

Also (2026-10-28): passing file paths to stylua ignores `.styluaignore`, so it reformats the GENERATED one-line scene files (src/server/Maps/Scenes/, Cinema/Shots, Anim/Clips) into thousands of lines. Filter those paths out of the list before running stylua.
