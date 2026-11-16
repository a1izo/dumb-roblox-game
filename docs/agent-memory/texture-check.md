---
name: texture-check
description: art/scripts/vfx/check_textures.py (2026-11-16, plan ticket V0.3) judges VFX textures on fill, edge, tone, motion, erosion and size; how to run it, what it assumes, and what its first run found
metadata:
  type: reference
---

`art/scripts/vfx/check_textures.py` puts "small, flat, blurry" on a VFX texture as numbers (ticket V0.3 of
[[vfx-rework-plan-2026-11]]). Run it with Blender's Python (numpy only, writes nothing):
`"C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/vfx/check_textures.py [names] [--calibrate] [--detail] [--table] [--selftest]`.
It reads `art/export/textures/Vfx*.png` (tracked in git, so a worktree has it; it falls back to the main checkout's
folder when it does not, and `--dir` points elsewhere) and takes each texture's grid and mode (loop, oneshot, random,
single) from the table at the top of the script, not from the PNG. A new texture (plan Part 5 names are already in
the table) is judged by what it declares; add a line for any name not there, or it is judged as a single image.

- Fill is judged on the LARGEST cell (a one-shot is born small); tone on the median over cells; a loop's wrap step may
  be 1.5 x the average (`LOOP_SLACK`); a one-shot must break into more islands in its last third than in its fullest
  frame. Sheets must be 1024 x 1024, so the legacy 256, 512 px sheets fail size by design.
- The tone figures in the plan's Part 2 (Smoke 0.044 and so on) do not come out of this measure (0.013 for Smoke, 0.000
  for Wisp); the fill figures do. Do not "fix" the script to match them without knowing how they were measured.
- `--calibrate` asserts that VfxSmoke, VfxWisp, VfxCandleFlame (fill) and VfxCrack (tone) fail; exit code 1 when they
  do not. After changing a measuring, run `--selftest` (made-up arrays with known answers).
- It is a floor, like [[motion-report]]: passing only rules out small, flat, still and bleeding textures.
