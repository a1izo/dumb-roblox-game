---
name: vfx-mesh-uv-rule
description: "The Vfx* kit meshes' UV rule (u once round, v up; V1.7, 2026-11-17), the doubled-face normals trap, and how check_meshes.py draws them"
metadata:
  type: project
---

`art/scripts/vfx/meshes.py` (the Fx props file's Vfx* shapes) follows one UV rule since 2026-11-17: u runs once round
the axis (seam on +X, closed), v runs up from the base (0) to the tip (1); flat or banded shapes say in their
docstring how they are laid out (ring: v inner 0 to outer 1; crescent and slash arc: u along, v across with the
cutting edge at 1). Before that it was "image rows along the shape, textures twice round" (the opposite). The new shapes
are VfxSlashArc, VfxTwister and VfxShell; they are in `BUILDERS`, so the next full export carries them.

**Trap:** every shape is drawn twice (a face and its back twin) and the twins share all their vertices. Blender then
gives corner normals of zero length, or the front's pushed onto the back, so a lit texture shades wrongly (Neon and
ForceField hide it). `_two_sided_normals` in meshes.py sets custom normals; keep it when adding a doubled shape.

**How to check:** `blender -b --factory-startup --python art/scripts/vfx/check_meshes.py -- [--no-render]` prints
triangles, UV range, seam closed, seam stretch and degenerate faces per shape and writes
`art/export/previews/vfx/after/meshes_uv_sheet.png` (u as hue, v as brightness, a checker). Importing a mesh's FBX back
into Blender drops the back twins (validate removes duplicates), so it cannot show the back faces.

**Why:** a texture that flows when the mesh turns needs u round and v up. **How to apply:** put no texture on a kit mesh
whose UVs you have not seen on the sheet; a texture for VfxShell keeps its top and bottom 1/16 of rows quiet (the pole
cap). The Studio SurfaceAppearance test and the ModelsFx 3 to 4 bump were still open when this was written.
