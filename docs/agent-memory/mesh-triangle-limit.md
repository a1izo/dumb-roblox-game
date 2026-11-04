---
name: mesh-triangle-limit
description: Studio's 3D importer refuses any mesh of 20,000 triangles or more; count every exported mesh, and cut small rounds first
metadata:
  type: project
---

Roblox Studio's 3D importer refuses a mesh of 20,000 triangles or more, and the rest of the FBX still imports, so the
prop is simply missing in the place. It has happened twice: the lobby's PracticeAltar at 20,356 (2026-11-03) and the
Agency's StationCRTBank at 24,011 (cut to 17,243 on 2026-11-04, Agency props v18).

The catalog's `tris` (`src/shared/ModelCatalog.luau`) counts a whole prop, its `_Glow` meshes and pieces included. The
limit is per mesh, so the main mesh is what has to fit. To count each mesh as the importer will, import the exported
FBX in a background Blender and count `len(loop_triangles)` per mesh object.

The CRT bank's weight was its keyboard: 84 keys with a 0.008-stud round in two segments, 108 triangles a key, about
9,100 in all. `modelkit.coarse_bevels(parts, width=0.01)` turns every bevel that narrow into one plain chamfer (44
triangles a box) and shades the part smooth, which looks the same at a prop's texel size.

**Why:** a round finer than a texel of the bake adds triangles nobody can see, and dozens of small rounded parts in
one prop add up past the limit.

**How to apply:** after any props export, check that no mesh in the set's FBX is at or over 20,000 (aim under
19,000). When one is, take a triangle census of its parts first (build the prop in a blank scene and count each part
with its modifiers evaluated) and cut the many small rounded parts before anything big enough to see. Keep size,
pivot, anchor and screen slot as they were, and bump the set's VERSION by hand
([props-blend-can-be-stale](props-blend-can-be-stale.md)).
