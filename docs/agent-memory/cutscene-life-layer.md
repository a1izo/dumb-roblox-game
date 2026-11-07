---
name: cutscene-life-layer
description: Since 2026-11-07 every cutscene actor gets a runtime life layer (Anim/Life, attribute DGLife) and every acting.walking walk swings its arms; what each does and where it gives way
metadata:
  type: project
---

Asked 2026-11-07: "make all the cutscenes and animations 100x better ... so that movements dont look stiff and ai made".
Two causes found in the acting: holds froze dead (alive() was baked into some shots only, and it fills the acting file:
twelve actors over 22 s took one past the 200k-character limit), and every walker but the HQ intro's two walked with
its arms hanging (only that shot had its own `swing`).

- **Anim/Life.luau**: a last pass in PoseController (step 5, after the clips, the planted feet and the floor guard) for a
  character with the attribute `DGLife` (0..1). ShotPlayer sets it to 1 on every actor and to 0 during a freeze-frame.
  It lays on: a breath (in over 2/5 of a 3.4-4.6 s cycle; the chest leans back 0.7 degrees, the head kept level, the
  arms ease out 0.9), the weight's slow drift (0.75 degrees of roll, the hips turned back so the soles stay), glances
  (the head moves 2.6/1.3 degrees in 0.22 s every 1.4-3.2 s), and lags from the body's own path: the head trails a
  turn (0.085 s of it, at most 14 degrees) and the arms swing on when the body stops or starts (a spring at 11 rad/s,
  damping 0.55). On a joint the clip itself moves faster than 25 degrees a second the pass fades out (gone by 95), so
  strikes, reaches and pen strokes land as acted. A body lying down fades it out as its torso tips over (from about
  50 degrees off upright, gone by 90): the fallen and the dead neither breathe nor glance. Nothing of it is in the
  acting files.
- **acting.walking(arms=True)**: the arms swing 14 degrees either way against the legs (more for a faster walk), 6% of
  a cycle behind them, the shoulders turn 3 degrees against the hips and the head keeps to the front; an arm keyed
  more than 28 degrees forward (carrying something) swings a quarter as far. `arms=False` for a walk with its own
  swing (the HQ intro's figure).

**Why:** the user called the movement stiff and "ai made"; the HQ intro's review (round 12, cutscene-quality-bar) had
already named dead holds and dead free arms.
**How to apply:** keep breath, glances and weight out of new acting (the layer does them); act the big moves, holds and
beats in the shot. A shot that must hold a body perfectly still (a statue, a corpse) sets DGLife to 0 on it. After a
walk change, rebuild the clips (`run_anims.py -- --add <clips>`, comma-separated) and run `run_cinema.py -- <Shot>
--clear`. Related: [[cutscene-pipeline]], [[cutscene-quality-bar]].
