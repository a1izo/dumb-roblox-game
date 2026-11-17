---
name: vfx-shape-textures-off
description: Shape.grow knows VfxSlashArc, VfxTwister and VfxShell (V2.6) and has a textured opt-in that stays off (Shape.TEXTURED = false) until the Studio SurfaceAppearance test of V1.7 is run
---
`Presentation/Vfx/Shape.luau` (2026-11-17, ticket V2.6): kinds `slashArc` (VfxSlashArc, 2 x 2 x 0.1, flat like the crescent:
no lift), `twister` (VfxTwister, 2 x 2 x 2 standing on its foot like the cone) and `shell` (VfxShell, 2 x 2 x 2 centred; the
lift rule and the stand-in ball treat it like the sphere). Before the Fx import only a sphere, dome or shell shows (a ball);
the others stay unseen, as the other kit shapes do.

Textures on meshes are NOT the default. The plan wanted `Shape.grow` to wear textures once V1.7's test says how: does a
`SurfaceAppearance` with AlphaMode Transparency / Color / Emissive on a kit mesh fade with the part's Transparency, tint from a
script and glow with EmissiveStrength? That test needs Studio and has not been run. Until it has: `options.texture` (a named
texture, as before) still works, and the new `options.textured = true` wears `Shape.TEXTURES[kind]` only while
`Shape.TEXTURED` is true; both ship as `false` and `{}`. When the test says yes, fill TEXTURES and turn TEXTURED on; if no,
meshes stay Neon.

**Why:** V1.7's test gates the whole Stage 2 look of meshes. **How to apply:** do not make a textured mesh the default
before the test; `FxKit` and its three callers are not touched (the pilot and roll-out move them). Related:
[[vfx-mesh-uv-rule]], [[fx-file-v4-export]].
