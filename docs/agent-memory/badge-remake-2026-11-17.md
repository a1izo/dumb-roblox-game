---
name: badge-remake-2026-11-17
description: BureauBadge (Core 42) remade as designed shapes raised in real relief and drawn into its texture; how the pieces fit, the pipeline hooks added, the traps
metadata:
  type: project
---

The owner 2026-11-16: "make the badge way more high quality". The badge is now three files in art/scripts:
badge_design.py (flat shapes with heights: shield, rolled rim, layered eagle, laurels, cloisonne ribbon/seal/plate,
stroked block-letter font), badge_mesh.py (raises them with bmesh, the wallet halves turned 2.2 degrees into a valley,
raised stitches, stitched window, and the UV layout) and badge_paint.py (numpy painter: pure Python, `python
art/scripts/badge_paint.py outdir` previews shield/card/leather with no Blender).

- Shield and card faces are laid flat in two big rectangles of the 1024 map and drawn over the baked maps in `finish`;
  the leather halves share one rectangle (painted pebble grain, own normal), stitches share a flat thread patch.
- Pipeline hooks added: build_props else-branch honours `more["laid"]`/`"into"` (unwrapped BEFORE centring, so the
  builder's coordinates hold); modelkit.bake calls a `finish` with 4 parameters as finish(colour, normal, rough, metal).
- Normal map 512 (budget exception +0.2 MP in art/budget.json), rough/metal stay 256: enamel = metal 0, rough 0.1.
- Trap: `run_props.py --export --set Core` rewrites ModelCatalog.luau in a compact one-line format; patch only the
  BureauBadge entry into the committed file instead of keeping the rewrite.
- Trap: review_badge.py (renders at 3, 2, 1.2 studs) sets the camera's sensor_fit before the angle, else the first view
  is wrong. Optional args: alternate blend and texture folder to render an older badge.
- Tris 8112 -> 5078. Not seen in Roblox.
