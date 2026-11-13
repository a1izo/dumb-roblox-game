---
name: animation-plan-2026-11
description: The owner's 2026-11-13 verdict on animations and cutscenes (only RoleMuerto, maybe RoleDiavolo, are good) and the plan that answers it, with the order the owner set
metadata:
  type: project
---

On 2026-11-13 the owner said: "everything besides the muerto intro cutscene and maybe the diavolo one feels very low
quality blocky stiff not cinematic and generally sloppy". The order the owner set for the rework: map intros, role
intros and the meeting intro first; then deaths (animations, cutscenes, effects); then winning cutscenes; then emotes
and base movement.

The plan: `docs/handoff/animation-cutscene-plan-2026-11-13.md`.

What the comparison behind it found (counts of calls in the shot modules that day): RoleMuerto and RoleDiavolo each
have a reference file in `art/refs/cinema/`, moving operator cameras, twelve to nineteen effect events on the
acting's beats and hands placed on targets. RoleAce, RoleOperative, RoleButler and MeetingIntro have no reference
file, six to eight locked camera keys each and two to five effects; RoleAce has three body keys in 17.5 seconds and
RoleOperative places no hand on anything.

**Why:** the owner's game leans on how it looks, and fourteen earlier rounds of cutscene rework were mostly turned
down, so the plan adds measurement (a motion report calibrated on RoleMuerto, spacing strips, a silhouette check)
and a pilot scene with a stop for the owner's verdict.
**How to apply:** RoleMuerto is the bar and is never changed. Rebuild weak scenes from a watched reference; do not
polish them. Ask before restructuring IntroCampus (a restructure was reverted once) and before touching
RoleDiavolo. One scene, one commit, one report, then wait for the owner. Related: [[cutscene-pipeline]],
[[cutscene-quality-bar]], [[animation-bar]], [[cutscene-footwork]], [[cutscene-life-layer]].
