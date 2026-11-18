---
name: vfx-pilot-redo-traps
description: The pilot redo (2026-11-18): why booth stills of soft effects lied (Governor cuts after the first seconds, rate emitters, 25 to 60 percent opaque sheets), and where each piloted effect stands
---
**Booth stills are only true in the first seconds of a play test.** `World/Governor` cuts particles when frames run slow (the
Studio window runs 15 to 20 fps while captured): after about 10 s `Vfx.quiet()` is true (the fresh menace and rate loops
vanish) and `Emit.share()` thins bursts. Stop and start play before every effect, bring Studio to the front (`ShowWindow`
plus Alt tap plus `SetForegroundWindow`), then do the `fx.at` calls at once (first one is the warm-up) and capture. A held
`fx.at` time is only roughly the real time (a hit marked at 0.4 s can show at 0.7 s).
**Rate emitters did not show in stills at all**, so booth loops are fed by hand (`emitter:Emit(n)` in a `Clock.every`), as
`Fresh/Menace` and the cover entry in `Catalog` now do.
**The soft sheets (VfxMist, SmokePuff, SmokePlume, AshFlakes) are only 25 to 60 percent opaque in the texture itself** (max alpha
160 for Mist): a particle transparency of 0.5 on top makes them invisible. Ask for 0.05 to 0.3. Also `light` is the glow
(LightEmission) and `lit` the scene's influence: in the dark booth use light 0.8, lit 0.1 for anything coloured.
**Where the three stand:** impact ON (crisp star, no cloud; residue still barely visible at 1 s); cover ON (report FAIL to PASS,
glint and frost clearly visible on the lightened slab, which now faces the camera); menacing OFF (the Aura of EmoteFx adds
about 15 emitters and 2 lights, so the pose can never meet the 12 and 2 budget by changing the haze alone; the new menace
(`Fresh.menace`) was not seen to read over the aura).
