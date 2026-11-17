---
name: matter-textures-tumble
description: art/scripts/vfx/tex_matter.py (ticket V1.5, 2026-11-17) makes VfxAshFlakes, VfxShards, VfxPaper, VfxFeatherTumble; how a flat shape is turned in 3D with numpy, the fit pass, and the traps (tone floor on matter, edge-on clamp, shard ray-cast)
metadata:
  type: reference
---

`art/scripts/vfx/tex_matter.py` builds the four V1.5 MATTER sheets (laid over, lit from above, white and grey). Blender's Python,
numpy only. A full build is about 5 minutes; `TEX_QUICK=1` draws at 1x for looking at shapes (never for the final PNGs).
`--preview DIR` writes `<name>_look.png` (the whole sheet laid over dark and over light, two tints; tracked) and
`<name>_strip.png` (8 frames at full size; scratch only).

- **Tumbling a flat shape:** a rotation matrix R (local u right, v down, w at the viewer), orthographic. For each screen pixel the
  point on the plane is found by solving z from `n . p = 0` (`plane_map`), giving local (u, v); a shape function returns a margin
  m (positive inside, in the shape's own units) and an albedo for each side; shading is Lambert from the world normal (a local
  bend or crinkle goes in as a normal tilt, `world_normal`). Which side shows is `sign(R[2,2])`. Edge-on, `nz` is clamped to
  +-min_nz so the shape stays a thin sliver (that is its thickness): 0.07 paper, 0.1 feather, 0.16 ash.
- **Loops close** because every angle is `2 pi t` plus sines of `2 pi t` (uneven speed, still periodic) and the noise lives in
  the shape's own coordinates (static).
- **Fit pass** (`fit_loop`): a loop is drawn once at low resolution to find the union of all frames' extents, then one scale and
  centre is used for all 16 (a tumbling thing never rescales). Union fit means the largest frame reaches 0.93 of the cell on one
  axis; fill (box area) then depends on tilt, so a long thing (the feather) is kept on a diagonal base tilt to pass the 55% floor.
- **Tone floor bites matter:** the check wants a brightness spread of 0.12 inside alpha over 0.5, per median cell. A bright
  page or a back side that is one grey fails. Fix with lit/shadow contrast (bend `py = 0.62 v` so the top is lit and the bottom
  is not), darker marks, show-through of the front's lines on the back, stains; a thin flake's back needs back-light (0.3) or it is
  a dark blob for half the loop.
- **Shards are a ray-cast**, not a rotated plane: a convex body is a list of planes `n . p <= d`; along z the nearest upper bound is
  the face, the largest lower bound the back; `top - bottom > 0` is the silhouette. A face's normal gives its shade, the gap to the
  second-nearest bound gives the lit arris. Glass is a plate (two big planes plus an edge plane per polygon edge, edges tilted a
  little off square) with a bright streak across the big faces and alpha 0.64 on them; stone is 6 jittered planes plus chamfers
  with per-face tone, grain and cracks. Each cell is fitted on its own (it is a random sheet). Thin ones are rolled onto a diagonal so
  they fill the cell.
- **Preview trap:** these are matter, so the useful picture is laid over the LIGHT backdrop; `preview.py`'s "added" half is meaningless
  for them (use this file's own `--preview`).
