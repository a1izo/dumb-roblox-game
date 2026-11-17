---
name: route-e-noise-cut-traps
description: Building eroded (Route E) VFX sheets in numpy (art/scripts/vfx/tex_impact.py, ticket V1.3, 2026-11-17): the traps that cost iterations, and the shape of a field-plus-noise-minus-threshold frame
metadata:
  type: reference
---

`art/scripts/vfx/tex_impact.py` makes VfxImpactA/B/C, VfxShock, VfxGlint, VfxSparks. Its frame recipe is the pattern for
any eroded sheet (V1.4's slashes and arcs reuse it): a shape field f (1 on the spine or core, 0 at the edge, weaker
toward thin tips), then `g = f - bite(noise) - threshold(k)`, `alpha = clip(g / aaw, 0, 1)`, value from g (white where g
is large, grey toward the edge). Draw at 2x the cell and box down (`D.resize`) so thin tips are anti-aliased.

- **Noise must only bite, never add.** `g = f + amp * n - thr` with signed noise turns every empty pixel with n > 0 into
  a blob (coverage 86% in frame 1). Use `f - amp * (0.5 - 0.5 * n)`.
- **Alpha is `g / aaw`, not `g / aaw + 0.5`.** The +0.5 makes outside pixels (g = 0) half opaque.
- **Make the taper weak, or tips just shorten.** With a strong tip falloff the threshold eats rays tip first and the
  burst only shrinks; flatten the body (0.5 + 0.5 * (1 - t) ** 0.5) so the noise cuts rays into dashes and shards.
- **The check's islands rule needs a connected fullest frame.** Frames 4 to 8 should be one island (hub and rays
  joined); the tail must then hold more. A late empty last frame is fine for a particle, but keep a few specks in the
  frames before it.
- **Hold frames freeze the motion check** (step 0.0003 for frames 4 to 6): give the rays a small per-frame shiver (reach
  by a few percent, bend a little) or let the scale creep.
- **4 px clear:** a window that is 1 up to 0.95 and 0 from 0.962 (cell runs -1..1) keeps `edge` at 0 whatever the noise does.
- **A shock ring breaks by an angular gap mask**, not by thinning alone: a noise over the angle (looped on a circle) with a
  rising cut, soft ends; thinning alone gives a hair-thin intact circle.
- **Sparks sheets are head up** (the game stretches them with VelocityParallel, like VfxStreak); the straight, bent,
  forked and short streaks are all vertical and centred.
