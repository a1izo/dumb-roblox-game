---
name: station-puzzles
description: "Case-file puzzles (2026-11-01 redesign): drawn in ink on the task window's paper, Common kit, misses cost a lock, specs per design"
metadata:
  type: project
---

The 16 case-file puzzles were redesigned on 2026-11-01 because the owner said the stations felt low quality.
Logic lives in src/shared/Tasks (PuzzleKit, Puzzles/*). Views live in src/client/UI/Puzzles, built only from
Puzzles/Common.

- Views are written for the dark (C.bone = ink, C.g0 = sheet) and the task window's paper turns them to ink on
  paper. Never use a colour off the ink ramp or a lerped colour: Paper can't swap it, so it shows near-black on the sheet.
  Common.INK/GREY/SOFT/FAINT/SHEET/CARD/SHADE are the names to draw with. Red only marks a pick (a ring for right,
  a cross for wrong) or the struck-through report line.
- Common.target(ctx, props, onClick) is the pickable card: the red hand on hover or selection, a gamepad focus mark,
  and no click while ctx.busy(). ctx.miss(gui, text) is the wrong-pick feedback. It locks every pick for
  1.1 s (TaskScreen.MISS_LOCK), so guessing costs more than thinking.
- Fingerprints are drawn from features (PuzzleKit.print / printVariant / printKey and Common.print). A decoy is
  always exactly one feature off.
- Keep minSeconds at 3 or below: the debug bots answer 3 to 7 s after starting (server/Debug/Bots.luau).
- Puzzles.spec has a "Puzzle designs" block checking each generator's promise (one exact Enhance match, Cipher
  options of one length, Dial's rule points at one call...). Extend it when a generator changes.
- Not yet seen in a Studio play test as of the redesign commit.
