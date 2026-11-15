---
name: ryuk-is-eight-rigid-parts
description: Ryuk (the "Specter" model, 2026-11-14) is eight Anchored MeshParts with no joints, used in only two scenes; Materialize fades him per part, his pivot is at his toes; what can move and what a rig would cost
metadata:
  type: reference
---

The owner's complaint (2026-11-14) that Ryuk looks stiff "because he is not rigged" is right: the `Specter` model in
`ModelsCore` is one body MeshPart plus `_Face`, `_Hair`, `_Collar`, `_Gear` and three `_Glow` MeshParts, all Anchored,
no Weld, no Motor6D, no Bone (read in the live place through the Studio MCP). It is used by exactly two scenes: the
Diavolo role card (`art/scripts/cinema/shots/role_kira.py`) and the Oculus deal (`Presenters/EyesDeal.luau`).

- The only free motion is the whole model through its path keys (position and three angles). Its pivot is at his
  **toes**: tip him about his hips instead by correcting the position with the rotation (`ryuk()` in `role_kira.py`);
  a lean about the toes swings his head like a plank on a hinge, which is how the old scene read as stiff.
- His head (`_Face`, `_Hair`, `_Glow`, `_Glow2`) and mane and gear are separate parts, so a head turn or a swaying mane
  needs Luau only, no import (not built; the owner chooses).
- `Materialize.appear` fades each PART by where its centre stands on the model (body and skirt 0.4 of his height,
  mane 0.7, head and eyes 0.8), so he dissolves in as slabs, head last (from about 0.65 of the time), not as a wipe up
  his body. Time the shot's camera and the cut so the head's arrival is on screen.
- A rig by pieces or a skinned mesh are model imports (a stop-and-ask item); costs and options in
  [ryuk-specter-findings-2026-11-14.md](../handoff/ryuk-specter-findings-2026-11-14.md).

**Why:** next agent asked to "make Ryuk less stiff" starts from the facts, not from a guess about a rig.
**How to apply:** move him with `ryuk()`; do not promise an arm or head move without the owner's choice of option 1b or 2.
Related: [[cutscene-pipeline]], [[owner-rejected-changes]].
