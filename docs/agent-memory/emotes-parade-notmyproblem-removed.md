---
name: emotes-parade-notmyproblem-removed
description: Parade March and Not My Problem (strolls) were removed completely on 2026-11-16 at the owner's word; what went, migration v12, orphaned Blender actions
metadata:
  type: feedback
---

The owner (2026-11-16): "remove parade march and not my problem". Gone: shop items emote_parade_march and
emote_not_my_problem, clips paradeMarch/paradeMarchWalk and notMyProblem/notMyProblemWalk (generated Clips parts 4 and 5
and the Index), their EmoteFx entries, EmoteMedia slots, art scripts (anims_emotes.py, strolls.py, settle.py) and
art/refs/emotes tomls. Strolls are now three: The Long Climb, Griddy, Mushroom Stroll. 68 emotes (11 free, 57 shop).
Profiles: migration v11 -> v12 drops owned, wishlist, new-cards, equipped/stance and the wheel slots, no refund.

**Why:** "Removal is final": no replacement, no asking.
**How to apply:** do not re-add them. The four Blender actions are still inside art/blend/Animations.blend (orphaned,
nothing exports them any more); the next time someone rebuilds that file they simply do not come back.
