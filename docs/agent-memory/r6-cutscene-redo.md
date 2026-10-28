---
name: r6-cutscene-redo
description: "Started 2026-10-06 - lock game to R6, redo every clip on the Sketchfab R6 rig, replace all cutscenes; plan + decisions inside"
metadata:
  node_type: memory
  type: project
  originSessionId: 77501874-126d-4d88-adac-442fa1338f87
  modified: 2026-10-06T18:31:28.431Z
---

Plan file: C:\Users\user\.claude\plans\a-lot-has-changed-lovely-tome.md (agreed in a grilling session,
every decision there). Key decisions that are easy to get wrong:
- Rig: switched on 2026-10-06 from Sketchfab to Aeresei's DevForum "R6 IK + FK Blender Rig" V2.22
  (control rig + InternalArmature; key the control rig, sample InternalArmature; no Cautioned plugin
  needed). File goes in art/rig/; credit the author.
- Players keep their own avatar converted to R6; the server enforces it.
- Cutscene cameras are authored in Blender on the real venue and exported to Luau; review is MP4
  previews per batch, then Studio.
- Deaths move to right after the Death's Gambit phase (3 causes, 9 map-specific scenes).
- Random players (never role-linked) star in intros; no cutscene may leak a secret role.
- Rating ceiling Moderate + a "Reduced violence" player setting; victory poses retired with refunds;
  win cutscenes go in a registry so the shop can sell more later.

**Why:** the user wants every old animation and cutscene scrapped; quality bar as in [[map-remake-project]].
**How to apply:** follow the plan's phase order (R6 + gameplay clips first); respect
[[protect-user-assets-edits]] when adding voice slots; [[windows-lf-endings]] for generated files.

**Progress (2026-10-06):** Phase 1 + 2 done and committed (458e21b): R6 lock, rig pipeline (art/scripts/rig.py,
gait.py, anims.py, video_anims.py, check_export.py), 41 gameplay clips, victory poses retired (profile v3 refund).
Preview videos in art/export/previews/anims/ (gitignored) wait for the user review. The DevForum rig sits in
art/rig/ (gitignored). Lessons: the rig file turns bone rotation inheritance OFF (set it ON); Blender 5 video
output needs image_settings.media_type = VIDEO; background renders must not be started with an inner `&`.
Death collapse clips (3 per cause) are KEPT as the base for the death scenes. Next: Phase 3 (cutscene framework).


**Style verdict (2026-10-07):** v1 cartoony = "too silly", v2 restrained = "too stiff". Approved direction (v3,
279c088 + 8d6feaf): fluid R6 style where limbs SLIDE as well as turn (animlib.J, motion.py springs + smooth
curves, legs slide to plant feet). Walk = long steps, slouched, serious; run = long driven strides, leaning in.
