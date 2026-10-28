---
name: parallel-agent-merges
description: "Another agent pushes to origin/main in parallel; check for a half-done merge before committing, and rebuild binaries after merges"
metadata:
  node_type: memory
  type: project
  originSessionId: 77501874-126d-4d88-adac-442fa1338f87
  modified: 2026-10-14T13:03:10.326Z
---

Another Claude session works on the same repo and pushes to origin/main (map surfaces, scanned materials, lobby). On 2026-10-11 a pull was left half done (MERGE_HEAD present) and my next `git add -A` + commit silently turned into a merge commit with conflict markers in matlib.py, SceneMaterials.luau, maps/export.py and ModelCatalog.luau, and kept only my side of Props.blend, Animations.blend and the Core/Tokyo FBXs.

**Why:** git can't merge binaries or generated files; both agents bump the same VERSION numbers and regenerate the same catalogs.

**How to apply:** before committing, check `git status` for "still merging" / `.git/MERGE_HEAD`, and `git grep -l -I -e "^<<<<<<< "` for markers. After any merge where both sides touched art: start from their Props.blend, build my changed props into it (`run_props.py -- <keys>`), re-export each touched set (`--export --set X`, which regenerates ModelCatalog), rerun run_anims.py, re-export changed venues, and bump export.py VERSION past both sides. Their pipeline needs the scans in art/source (`python art/scripts/sources.py fetch`, ~900 MB, CC0; already downloaded on this machine). Related: [[protect-user-assets-edits]].

2026-10-14 lessons: the other agent's Core export (v6) silently dropped my cutscene props (NotebookOpen, Smartphone, CRTTelevision, ShrineDoor, Teacup, TeaTray, BureauBadge) and the Tex_Face* carriers, because their Props.blend lacked them; I rebuilt them in and exported Core v7. After any merge, grep the exported FBXs for my prop names. Also: since their code-built rig, `run_anims.py` (full, or `--add`) rewrites ALL of src/shared/Anim/Clips and the acting files with drift/losses; never commit that output. Rebuild with `--add <Clip>`, splice only that clip's block into HEAD's files, and `git checkout` the rest (and Animations.blend).
