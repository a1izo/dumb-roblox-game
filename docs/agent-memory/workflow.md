---
name: workflow
description: The user's 2026-11-12 "remember all this workflow": the whole delivery chain (brief, slices, checks, harness, place update with no screen) and the traps hit, so no step is skipped or repeated
metadata:
  type: feedback
---

How a request is delivered here, start to finish (the user: "remember all this workflow so you dont make any mistakes
in the future", 2026-11-12):

1. **Brief first**: a big message becomes docs/handoff/big-list-<date>.md (items sorted, the user's words kept) and the
   pictures are copied to art/refs/<topic>_<date>/; a memory line points at it. Work in the user's order, one slice
   at a time; log each slice at the bottom of the brief.
2. **Each slice**: change, then stylua + selene (tools in the a64f6e97 scratchpad), scripts/check_terms.py,
   scripts/budget.py for art; the harness (run.ps1 -Min; -Attr "DGForceDevice=phone" plays as a phone) with a probe
   that measures what was asked (not just "no errors"); specs must pass; commit with the negru identity + Co-Authored-By;
   push to main. Look at pictures myself before calling anything done.
3. **Into the place, with no screen** (repo docs/agent-memory/imports-by-open-cloud.md): fingerprint the place's scripts
   (hashes to the Studio log) and compare with the repo's history first; scripts by an rbxm model (big syncs) or
   multi_edit (small ones), then compare hashes again; FBX by Open Cloud upload -> insert in ServerStorage -> check ->
   unlink package -> pivot onto the old -> swap -> delete the old; files over 20 MB via run_maps --split; ALWAYS share
   every upload with universe 10767766818 (asset-permissions, grantToDependencies); play test by start_stop_play and
   read get_console_output; save_place; never publish (the user's call).
4. **Traps hit**: ModelLibrary.install() must never run after start (it swallowed the built lobby); execute_luau's
   Client VM is not the game's (its module copies are fresh); screen_capture shows no 3D; PreloadAsync says Failure
   for images that draw; a re-export can reformat src/shared/Scenes data (restore it if only formatting changed);
   Studio's emulator reports a keyboard; a Rojo popup in Studio is not needed.
5. **The user's standing taste from 2026-11-12**: no emojis anywhere; the pencil/boil look only on gameplay UI (not
   cutscenes, death scenes, debug); nothing placed mathematically (natural placement); scene deaths copied 1:1.

Related: [[feedback-keep-going]], [[feedback-expand-prompts]], [[studio-place-update]], [[feedback-scene-deaths-1for1]].
