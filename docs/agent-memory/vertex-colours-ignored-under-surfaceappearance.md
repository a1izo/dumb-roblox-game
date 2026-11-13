---
name: vertex-colours-ignored-under-surfaceappearance
description: "Roblox ignores a mesh's vertex colours when it has a SurfaceAppearance (seen 2026-11-14), so shading baked into map meshes cannot work for the textured materials; how it was tested without an upload"
metadata:
  type: project
---

Phase 9 of the graphics plan (docs/handoff/graphics-and-crowd-plan-2026-11-13.md) wanted ambient occlusion baked into the
map meshes as vertex colours. Tested 2026-11-14 in a Studio play test at Quality 21, real camera, three 8 x 8 stud walls
built at run time on the client and lit alike:

- plain colour MeshPart + vertex colour (4% at the foot to full at 6 studs): the gradient shows clearly;
- MeshPart with a SurfaceAppearance (a map's concrete maps copied on) + the same vertex colour: NO gradient, identical to the
  control without vertex colours (tried with a mild and with a near-black gradient, so it is not clipping).

So vertex colours are dead for all 114 textured map materials (each becomes a SurfaceAppearance). The 85 flat materials
(glass, neon, fittings, a few paints) are the ones that should not be shaded anyway.

**Why it matters:** any "bake darkness into the mesh" idea (vertex AO, a colour layer in the FBX) is closed. Darkness has to
be geometry (the stacked ContactDark layers of maps/contact.py: furniture, wall feet; ceiling creases and inside corners are
not done), a light, or a dark map material. **How to apply:** do not rebuild a vertex-colour baker. A flat-material baker
would run (the ray, BVH and crease-grid code worked on Agency in 8 to 35 s, 71k triangles from 39k when limited to faces
over 3 studs and 1.2 wide), but it has nothing to shade.

**How it was tested with no upload:** `AssetService:CreateEditableMesh()` on the Client datamodel (vertices, UVs, normals,
`AddColor`, `SetFaceColors`), `AssetService:CreateMeshPartAsync(Content.fromObject(mesh))`, then a SurfaceAppearance whose
maps are copied from any imported map MeshPart (read its `ColorMap` etc). It works in Studio play tests, so run-time
EditableMesh/EditableImage is the way to try a material or a mesh idea without the importer or an upload. Not tried: the
same through an FBX import; not expected to differ (it is the renderer's SurfaceAppearance path).
Related: [[lighting-rework-2026-11]], [[graphics-references-2026-11]].
