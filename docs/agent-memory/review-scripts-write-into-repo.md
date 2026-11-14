---
name: review-scripts-write-into-repo
description: review_anims.py, review_win.py and review_emote.py write their sheets under art/export/previews inside the repo; how to redirect them to a scratch folder, and which of them still work
---

`art/scripts/review_anims.py` (`out.png` becomes `<previews>/out.png`, tile scratch `_tile.png`), `review_win.py` (`<previews>/wins/<cut>/`)
and `review_emote.py` (`<previews>/emotes/<clip>/`) all write under `common.PREVIEWS` (`art/export/previews`). Part of that folder is tracked
(`previews/deaths/*`) and `review_anims.py`'s plain sheet name is not gitignored, so a render leaves untracked files in the repo.

**How to apply:** to keep sheets out of the repo, run the script through a two-line wrapper that sets `common.PREVIEWS` before it runs:

```python
import os, runpy, sys
sys.path.insert(0, os.path.join(ROOT, "art", "scripts")); import common
common.PREVIEWS = os.environ["SHEETS"]; os.makedirs(common.PREVIEWS, exist_ok=True)
runpy.run_path(os.path.join(ROOT, "art", "scripts", os.environ["REVIEW"]), run_name="__main__")
```

and run `blender.exe -b --factory-startup --python wrapper.py -- <the script's own arguments>` (Blender 5.2 lives in
`C:\Program Files\Blender Foundation\Blender 5.2`; a 3-clip, 12-column sheet takes about 25 s). `review_anims.py` takes clip names as
`clip@12` (12 frames over the clip), `--angle=180` for the view from behind (the game's camera), `--cols`, `--size`. `check_anims.py` needs
numpy: run it with Blender's own Python (`...\Blender 5.2\5.2\python\bin\python.exe`), not the system Python 3.11.

`review_deaths.py` renders `deathcuts.CUTS`, which has been empty since the death styles and shop death cuts were removed
([deaths-current-state-2026-11-14](deaths-current-state-2026-11-14.md)): do not run it, it rewrites `DeathCuts.luau`.
