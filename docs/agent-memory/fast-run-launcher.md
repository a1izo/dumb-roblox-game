---
name: fast-run-launcher
description: art/scripts/fast_run.py (2026-11-15) runs lint, spacing strips, clearance, export or stills for one cutscene without importing the other scenes or building the 70 emote clips; the command, what it skips, when not to use it
metadata:
  type: reference
---

Every script that imports the shot modules (`run_cinema.py`, `review_strip.py`, `review_stills.py`) first builds all nine
cutscenes and, through `from emotes.kit import ...`, all 70 emote clips: two minutes before a one-second job
([[review-stills]], [[spacing-strip]]). `art/scripts/fast_run.py` skips both imports:

```
blender -b --factory-startup --python art/scripts/fast_run.py -- run_cinema.py --lint IntroCampus
blender -b --factory-startup --python art/scripts/fast_run.py -- review_strip.py IntroCampus noticer 12.3 13.7 out.png --cols=5 --step=0.1
```

- It replaces the `emotes` package and `cinema.shots` by empty stand-ins (`emotes.kit` still imports; `emotes/__init__`
  and `cinema/shots/__init__` do not run) and imports only the modules in `DG_ONLY` (default `intro_campus`, comma
  separated; empty imports none). `DG_PRE=<file.py>` runs a patch file first.
- Measured 2026-11-15 on the Campus intro: lint and a spacing strip take 25 seconds in all (the intro's own build
  included); `--clear` and the stills still build the venue (about 3 minutes).
- **Do not use it for `run_anims.py`** (a bake wants the emotes built and exports the whole library) or for a shot that
  needs an emote clip from the package's own modules (none does today).
- **A reach check:** a `DG_PRE` file can wrap `cinema.acting.body_reach` before the module is imported and log, for every
  placed hand, the fist's distance from its target and from the shoulder pivot. Run on the Campus noticer it found
  writing targets 0.4 studs out of reach, and left hands 0.3 short on a turned, leaning body ([[r6-reach-limits]]).

**Why:** the loop of change, check, look was 12 minutes per change ([[review-stills]]); the checks that read the module
(lint, strips) need none of the 2 minutes. **How to apply:** use it for every check that reads the module; bake and
render the way [[cutscene-pipeline]] says.
