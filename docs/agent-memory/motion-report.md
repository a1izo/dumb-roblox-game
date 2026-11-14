---
name: motion-report
description: art/scripts/check_motion.py (2026-11-14, plan Tool 1) puts the animation bar's nine traits on any clip as numbers with a PASS/FAIL; how to run it, what it reads, the calibrated limits and the traps found building it
metadata:
  type: reference
---

`art/scripts/check_motion.py` is Tool 1 of [[animation-plan-2026-11]]: "is this stiff" as numbers, on the traits in
[[animation-bar]]. Run it with Blender's Python (numpy only, writes nothing):
`"C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/check_motion.py --shot RoleAce --detail`.
Select by clip name, cutscene (`--shot`, or the bare name), `--all`, `--emotes`, `--movement`; `--lead` drops a scene's
extras; `--table`, `--json`, `--worst N`, `--selftest`. Exit 1 when a clip that counts fails, 2 for an unknown name.

- **It reads the committed exported keys** (`src/shared/Cinema/Acting/<Shot>.luau`, `src/shared/Anim/Clips`) on the
  game's own cubic (`cubic.py`), not `Animations.blend`. So rebuild and export a clip before measuring it, or you
  measure the old one. Moves under 6 degrees a second never count (the export thins at 0.6 degrees and the life layer
  covers breath: [[cutscene-life-layer]]).
- **The legs are left out** (footwork plans them, [[cutscene-footwork]]); a walker's hips swing 80 degrees and would
  drown every share. The hips also counter-rotate the root, so joint-space leg motion is not the legs' own motion.
- **Calibration** (RoleMuerto passes, RoleAce fails; numbers in the plan under Tool 1): the traits that separate them
  are the dead limb (one joint still over 8 s; Ace's left arm 17.5 s), torso share (under 4%; Muerto 15%, Ace 1%),
  and same timing (14 of 17 Ace head turns take 0.18 s). The plan's "whole upper body frozen" does not separate them
  (the neck always drifts); a fifth of torso share would fail Muerto itself; three metronome repeats would too (its
  torso makes four, so five). Overshoot is printed but not judged: Muerto's strokes flow, none settle.
- **Anticipation sign trap**: a move drawn back first starts at its farthest point back, so the joint stood further
  *along* the move's direction a moment earlier. Measure the pull as the joint's earlier position projected on the
  move direction, positive, bounded to 5 to 50% of the move (a stroke as big as the move is the move before).
- **Reversal trap**: a wind-up that snaps back past where the move began (a 3-frame move) is invisible to a
  distance-from-start test; the move finder also watches progress along the first direction.
- **Extras** (slots `everyone:N`, `extra:N`) are only noted (`info`); a clip no actor plays is skipped (IntroCampus
  carries 5 unused walkers); a clip the story keeps still goes in `FREEZE_OK` or `--frozen-ok` (today
  `RoleButler_ace`). A loop is not judged on repeating; emotes are not judged on mirrored held poses; the movement set
  only on freezing (its `idle` clips fail: the shoulders never move over 0.6 degrees).
- It is a floor: RoleOperative and RoleDiavolo pass, which says nothing about missing hand targets or locked cameras.
  After touching a measuring, run `--selftest`.
