---
name: smoke-sim-headless
description: How art/scripts/vfx/tex_smoke.py makes smoke and dust sheets from a headless Blender gas bake (2026-11-17), and the four traps the first attempts hit (REPLAY cache bakes one frame, noise upres writes empty grids, Cycles shows nothing, np.roll wraps)
metadata:
  type: reference
---

`art/scripts/vfx/tex_smoke.py` (plan ticket V1.1) makes VfxSmokePuff, VfxSmokePlume and VfxDustRoll from Blender's
Mantaflow gas simulation, baked with `blender -b` and read back as density; VfxMist is a noise volume (see below).
Run it with Blender (`--sim`) then, if you like, plain numpy Python (`--post`); `--cache` is a scratch folder,
`--out` writes the PNGs elsewhere, `--quick` halves the grid for trying a setting.

What was learned the hard way:

- **The domain's `cache_type` must be `'ALL'`** before `bpy.ops.fluid.bake_data()`. The default `'REPLAY'` finishes
  "complete" and writes one frame.
- **Mantaflow's noise upres (`use_noise`, `bake_noise`) writes empty grids when baked headless** (`density_noise` has 0
  active voxels, in UNI and OpenVDB alike). Raise the base `resolution_max` instead.
- **A headless Cycles render of the baked domain showed nothing** (alpha 0 with a plain Principled Volume, noise baked
  or not), while a visible mesh in the same scene rendered. So the baked density is read with Blender's own `openvdb`
  module (`vdb.read(path, "density").copyToArray(arr, ijk=(0,0,0))`; the full grid size is `resolution_max` on the
  longest side and proportional on the others, `ds.domain_resolution` reads 0 headless) and lit/ray-marched in numpy.
- **`np.roll` blurs wrap round the grid**: a dust cloud on the floor smeared a faint line onto the domain's top row and
  made every frame's box the full height. Blur with edge padding.
- Flow objects must be `hide_render` only if you render with Cycles; the ico sphere of the emitter shows otherwise.
- A source that grows (object scale keyframed) makes a puff that is born small; a one-off radial `v_normal` burst
  with a stationary source is born big. A strong force field blast threw the smoke out of the domain; do not.
- Looks: the sim gives the mass and its breaking up; the cauliflower is a fixed 3D noise cube sampled relative to the
  cloud's own centroid and radius (so lumps grow with the cloud instead of sliding through it). Frames are framed by
  following the cloud (puff) or its floor (dust) because the sim drifts and the texture check wants 80% fill.
- A steady column or fog gives almost no per-frame change when it is opaque (the texture check's motion floor is
  0.01): keep the sigma low so alpha varies inside it.
