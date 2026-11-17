---
name: fire-flame-textures
description: art/scripts/vfx/tex_fire.py (ticket V1.2, 2026-11-17) makes VfxFire, VfxFireBurst, VfxCandle, VfxAuraFlame; the 4 px rule differs per cell size, spine-tongues beat noise cones, the candle's halo carries its fill
metadata:
  type: reference
---

`art/scripts/vfx/tex_fire.py` (numpy only; `TEX_QUICK=1` draws at 1x, about 30 s for all four; full build a few minutes).
No gas sim was run: VfxFire/VfxFireBurst are hand-built volumes (the V1.1 dust precedent), the candle and aura are drawn.

- **4 px clear depends on the cell:** SAFE 0.962 is 4 px only for 256 px cells. A 128 px cell needs 0.93 (`safe_of`); with 0.962 all 64 cells failed `edge`.
- **A noise-cut cone is a mound, not fire.** Noise bites on a triangular body gave "a hill with a ragged top" however hard the bite. What reads as fire is separate tongues (`_spine` + `_tongue`: a curve from a turning tangent, width s^p (1-s)^q) each with its own sway, and a torn-off teardrop climbing off each tip once a loop; then bite their depth (distance to edge) with scrolling noise.
- **Loops close by whole harmonics:** `harm()` sums sines of integer multiples of the loop, `pulse()` is a once-per-loop bump, noise scrolls by whole periods (`pnoise`).
- **Candle fill is the halo's:** a narrow teardrop alone fills ~25% of its cell; a soft alpha 0.36 halo (wide gaussian) is what puts the box at 65%. Said plainly in the Log; no vertical stretch.
- **Aura tongue:** tangent angle = theta0 + bend*sin(2 pi 0.85 s) + curl*smoothstep^1.4 gives an S and a hook; `sin(pi*1.15*s)` alone leans the whole thing into a leaf.
- Not on the Fx file: a second bump (ModelsFx 5) is the owner's call; see [[fx-file-v4-export]], [[slash-arc-wisp-textures]].
