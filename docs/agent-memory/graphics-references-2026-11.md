---
name: graphics-references-2026-11
description: The owner's two photo references for interiors (2026-11-13) and the plan built on them, with the Tokyo crowd's logic fixes
metadata:
  type: project
---

On 2026-11-13 the owner gave two reference pictures for how interiors should look, kept in `docs/handoff/refs/`:

- `ref-office-single-key.png`: a small office under one ceiling panel. One key light, hard falloff to a near-black
  foreground of silhouettes, grounded furniture, two-tone glossy walls, a cool teal grade, quiet detail everywhere.
- `ref-lab-corridor-red.webp`: a dark corridor lit by a lab seen through glass and one red exit sign. A glossy floor
  that mirrors both, black window frames against the lit room, local task light inside the lab.

The owner also asked, the same day, for everything suggested beyond the first graphics plan (baked shading, one
finished room per map, motion, surface detail, characters, the look at low quality) and for the Tokyo crowd's logic
to be fixed. The plan for all of it: `docs/handoff/graphics-and-crowd-plan-2026-11-13.md`.

**Why:** the owner's game "runs very heavily on its aesthetics" and the references are the first concrete target
for interiors.
**How to apply:** open the two pictures before judging any interior capture. The owner's standing limits still win
over them (fill within the spec, no skin bloom, no heavy blur, a light only in a visible source). The owner did not
say which crowd behaviour looks wrong: the plan's list is from reading the code, so watch the crowd and ask if
unsure. Related: [[lighting-rework-2026-11]], [[lighting-sweep-2026-11]].

**2026-11-14, phase 8:** the three finished rooms and their cameras are in the plan (HQ's sergeant's office from its door,
the University's science hall looking north along the lab's glass, Tokyo's crossing and arcade mouth). Before pictures at
Quality 21 and 3 are `docs/handoff/refs/before-<hq|uni|tokyo>-q<21|3>.jpg`, with the gap lists in the plan. A map's world
position is its local studs plus 3000 in z (a camera without it looks at the lobby). Studio was minimised, which draws no
3D: park it off screen ([[lighting-sweep-2026-11]]) and put it back minimised (flags 2, showCmd 2) afterwards. The quality
level can be set from the Client datamodel (`settings().Rendering.QualityLevel = Enum.QualityLevel.Level03`) mid-test.
Phase 9 is closed: [[vertex-colours-ignored-under-surfaceappearance]].
