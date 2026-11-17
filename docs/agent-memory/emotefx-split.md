---
name: emotefx-split
description: Controllers/EmoteFx is a folder since 2026-11-17 (ticket V2.1): where each clip's effect lives, how modules share helpers, and the two traps (the double GOLD, EmoteFx.thud)
---

`src/client/Controllers/EmoteFx.luau` (4,233 lines) was split by moving code only, no logic change. Callers still do
`require(Controllers.EmoteFx)`; Rojo makes the folder's `init.luau` the module and the others its children.

- `init.luau`: the public API (`play`, `rung`, `has`, `clips`, `thud`, `pock`, `wisp`), the `RUNG`, `AURAS` and `LEVEL`
  tables, and the merge of the families' tables into `FX`.
- `Shared.luau`: helpers used by more than one family (`accent`, `onBeats`, `burst`, `pieces`, `glint`, `hand`,
  `onHead`, `floorUnder`, `mine`, `stepDust`, `signLabel`, `after`...) and the colours more than one family uses
  (`CRIMSON`, `GOLD` as a ColorSequence, `PAPER`, `THOUGHT`, `GLINT`).
- Families, each returning a table of clip id -> effect function: `Godhood` (New World, Reaper's Eyes, Just As
  Planned, Final Breakdown), `Poses` (Menacing Pose x6, Low Battery and its charge, the S11 accents), `Dances` (S10,
  Jackpot Shuffle), `Props` (S12), `Older` (chip and pen, Apple Bite, puppets, Write in the Air, Ace's crouch, L's
  chair), `Strolls` (The Long Climb, Griddy, Mushroom Stroll), `Duos`, `Everyone` (everyone's, Scrawl and Penned).
- To add an effect: put `FX.<id> = ...` in the family that fits, add its rung to `RUNG` in init, and (for the booth)
  its first beat to the Catalog's `FIRST_BEAT`. A clip id must be in exactly one family (init merges them with no
  duplicate check; a later family silently overwrites an earlier one).

**Traps**
- `EmoteFx` (the public table) is created in `Shared.luau` and handed out as `Common.EmoteFx`, so any family can call
  `EmoteFx.thud(...)` at run time while `init` defines it. Never `require` init from a family: that is a cycle.
- Two different `GOLD`s existed in the one file (a Color3 at the top for New World, a ColorSequence further down for
  the dances and coinFlip). Now `Godhood.luau` has its own Color3 `GOLD` and the shared one is the ColorSequence.
  A name can mean two things in one file; a split must check each use (selene's undefined/unused lints caught the rest).
- A family module's requires climb one more `.Parent` than init's (`script.Parent.Parent.Parent.Presentation...`).
- stylua and selene are enough to check a move like this; the proof was a script comparing the FX key lists and a
  multiset of the non-blank lines (only scaffolding added). The booth's `verify()` and a play test need Studio.
