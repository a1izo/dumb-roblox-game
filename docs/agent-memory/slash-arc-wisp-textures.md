---
name: slash-arc-wisp-textures
description: art/scripts/vfx/tex_slash.py (ticket V1.4, 2026-11-17) makes VfxSlashA/B, VfxArc and VfxEnergyWisp; the stroke coordinates, the NaN trap, the loop-exact noise trick and the quick-look switch
metadata:
  type: reference
---

`art/scripts/vfx/tex_slash.py` builds the four V1.4 sheets (numpy only, Blender's Python). A full build is about 5 minutes;
`TEX_QUICK=1` draws at 1x (about 20 s a sheet) for looking at shapes, never for the final PNGs. `--preview DIR` writes
`<name>_look.png` and `<name>_strip.png` (big cells) into DIR; only the `_look` pictures are tracked.

- **Slashes** are an arc of a circle through two points (`arc_geometry`), with `stroke_coords` giving s along it, dr across it
  and a (length). Everything (width, notches, wake lines, streak noise, the tear) is written in s and dr, so the stroke can
  be reshaped by changing two points and a bulge. The head grows from 50 to 100% of the arc in frames 1-4; the tear is a
  front that moves along s from frame 6, each streak letting go at its own place (front + noise); little specks are born
  where the front passes. This is what makes the check's islands rule pass (a thin stroke otherwise just shortens).
- **Streaks, not blobs:** noise for a stroke is anisotropic (`fbm_xy`: low frequency along, high across), so what is left
  of an eroded stroke is thin curved lines, as in the slash reference.
- **NaN trap:** `(1 - s) ** 0.9` with s a hair over 1 gives NaN; NaN pixels propagate through `np.maximum` and write as cut-off
  wedges. Clip s to 0..1.
- **A loop that closes exactly:** noise with `period=(Pa, None, Pz)` and the coordinate shifted by `Pa * k/16` (flow along the
  wisp) and z = `Pz * k/16` is identical at k = 16 and k = 0 (`_periodic_noise`; `time_scales=False` keeps the z period whole
  for every octave). A travelling wave `sin(2 pi (cycles * s - k/16))` closes the same way.
- **Arcs run top to bottom** (like VfxSparks, head up) and the 16 are a table of specs (`ARC_SPECS`), not one random recipe, so
  they differ in kind (Y, double strand, spray, tree, wide diagonals). If a beam needs them along its length, turn the UVs.
