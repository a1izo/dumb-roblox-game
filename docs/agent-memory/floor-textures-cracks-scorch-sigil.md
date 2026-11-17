---
name: floor-textures-cracks-scorch-sigil
description: art/scripts/vfx/tex_floor.py (ticket V1.6, 2026-11-17) makes VfxCrackA/B, VfxScorch, VfxSigil; cracks shaded from a height field (groove, bevel, chips), the brush-stroke canvas for the sigil, and the traps
metadata:
  type: reference
---

`art/scripts/vfx/tex_floor.py` builds the four V1.6 single 1024 images (numpy only, Blender's Python; a full build is about
4 minutes, `TEX_QUICK=1` draws at 1x in under a minute, for looking at shapes only). `--preview DIR` writes `<name>_look.png`
(2 x 2: cracks and scorch laid over a light and a dark made-up floor in two tints; the sigil added over dark in orange and cool,
white, and laid over light).

- **Cracks are a height field, not drawn lines.** A `Field` keeps the signed distance to tapered segments and the half width of the
  nearest one. The groove is a hole (`H = -bh`), the lip is `H = -bh * exp(-d / (0.38 lw))` (steepest at the groove's edge), chips are
  bumps. Lambert from the gradient with the light up-left gives a lit lip (white) on the lower right of a groove and a dark one on
  the upper left. Alpha is `|lambert - flat|`, so flat floor is clear and the floor shows through; colour is white where lit, near
  black where not. That is why a crack reads on a light floor AND a dark one.
- **Segments are rasterised per bounding box** (`Field.seg`), not over the whole grid: 3000 segments at 2048 px take seconds.
- **Branch rate and taper decide whether it reads as a spider or a tree**: radials need a low branch rate (0.05), straight walks
  (wander 0.04) and a fast taper (power 1.3); with 0.085 and a slow taper the first A was one lopsided bush.
- **Alpha-weighted shading kills the AO smudge trap:** an ambient-occlusion band wider than about 2.4 lip widths turns into a muddy
  halo along the whole crack.
- **Sigil strokes** (`Brush`): a polyline with a width and value per point, anti-aliased, `dry` thins the end into streaks. A ring is a
  spiral of 1.03 turns (it does not close), radius wobbling by a few sines, weight a smooth random curve 0.4 to 1.7 x, heavy at the
  start and thin at the end. Glyph marks must be chosen so none reads as a letter: comb, zigzag, staircase and crescent did
  (E, Z, S, C), so they were dropped; spirals, triangles, diamonds, dot rows, ring-with-bar stay.
- **Scorch:** a hard edge from a warped, lobed radius plus noise, soft soot and spatter outside, three values inside (a charred
  line at the edge, a lighter scorched band, a dark core with ash seams from Worley cells). Pits need a warped lattice, or they are
  perfect circles and read as bubbles.
