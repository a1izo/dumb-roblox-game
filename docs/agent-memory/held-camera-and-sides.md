---
name: held-camera-and-sides
description: RoleDiavolo's cameras redone 2026-11-14 ("stale when it's not camera POV"): the held() helper for a bent camera path with a spring aim, and which side of a person a camera can use (a raised arm hides the face, a second subject hides behind the first)
metadata:
  type: feedback
---

The owner (2026-11-14): RoleDiavolo's non-POV shots were "stale". The POV shots are the three hidden cameras (the
`cctv` effect: locked off on purpose); the other five were all one move, a slow creep in from the front at a
head-and-shoulders size. What the redo taught:

- `held(t0, t1, path, aim, fov, roll, shake, seed, lag)` in `art/scripts/cinema/shots/role_kira.py` is the
  `framing.pan(operator=True)` spring and breathing on a path of two or **three points** (a bend), with the aim any
  function of time (`on("Head")`, or a blend between two bodies). Copy it for a move that `framing.pan`'s straight drift
  cannot do (a pull-out that curves round to find someone). Keep it in the scene's file: other sessions edit framing.py.
- **A raised arm hides the face from the camera on its side.** The crisp is raised on Diavolo's left, so from his left
  the held pose shows an arm block and a chin; from his right the face and the crisp both read. Check which arm is
  raised at the held pose before choosing a side.
- **A second subject hides behind the first when the camera is on the line through them.** Ryuk stands behind
  Diavolo's right; from his front left they are 13 degrees apart (one head in front of the other), from his front right
  3 studs apart. For a reveal, shoot from the side perpendicular to the line between them.
- Alternate sides and sizes cut to cut (B high centre, C close left, D low right and wider, E tight frontal then
  pulling out to the right, F low centre-right), and give each shot something in front of the lens: the lamp's glow, the
  chip bag. A camera lower than the desk top (2.7 studs here) shows only the desk's front face.
- A hand insert at 2 studs is all arm: R6 arms are 1 stud boxes. Stand back to 4 or 5 studs and go high.

**Why:** the same "stale" complaint will come back on the other scenes; this is what changed it.
**How to apply:** scout free-camera stills (`review_stills.py`, `t@px,py,pz,tx,ty,tz,fov`) before writing a camera.
Related: [[cutscene-pipeline]], [[review-stills]], [[ryuk-is-eight-rigid-parts]], [[r6-near-arm-occlusion]].
