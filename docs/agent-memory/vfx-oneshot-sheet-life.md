---
name: vfx-oneshot-sheet-life
description: A one-shot flipbook sheet needs particle lives of frames / 30 seconds or more (the rate caps at 30): 4x4 sheets 0.55 s, 8x8 sheets 2.1 s; the fallback grows a still image by hand
---
`Sheets.oneShotFps` gives a one-shot sheet the rate `frames / life` so its last frame lands at the particle's death, but
Roblox flipbooks play at 30 frames a second at most. So a 16-frame sheet (VfxImpactA/B/C, VfxShock, VfxGlint, VfxSlashA/B)
lives 0.55 s or more, and a 64-frame sheet (VfxSmokePuff, VfxDustRoll, VfxFireBurst) 2.1 s or more, or its last frames are
never shown. The fresh recipes (Presentation/Vfx/Fresh) follow it: impacts live 0.55 to 0.7 s, the 8 x 8 sheets 2 to 2.4 s,
and the quick part of the effect is a separate short layer (the white-hot core is a second, smaller sheet particle).
`Common.size(texture, flat, grown)` gives a sheet that is really there a flat size (its frames already grow and erode) and
the old still picture that stands in until the Fx import a size grown by hand.

**Why:** a hit has to read in two or three frames, but a sheet is a whole life. **How to apply:** when a recipe's particle
must be short, use a short sheet (a glint) or a second layer; do not shorten a sheet below frames / 30. Unchecked: whether the
engine clamps at 30 or skips frames; judge it by eye in the booth after the import. Related: [[vfx-sheets-fallback-grid]],
[[vfx-fresh-recipes]].
