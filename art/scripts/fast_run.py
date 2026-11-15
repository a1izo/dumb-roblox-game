"""Run one cutscene's checks without waiting two minutes for every other scene (background Blender):

    blender -b --factory-startup --python art/scripts/fast_run.py -- <script.py> <its arguments...>

    DG_ONLY=intro_campus,role_ace   (the shot modules to import; default intro_campus; empty imports none)
    DG_PRE=<file.py>                (run this first: patch cinema.acting.body_reach and the like before a module uses it)

Two imports are skipped: the `emotes` package's __init__ (it builds and settles all 70 emote clips, about 1.5 minutes;
`emotes.kit`, which every shot module uses, still imports) and `cinema/shots/__init__.py` (it imports every cutscene).
The script then sees only the shots named in DG_ONLY. For example (the Campus intro's lint, spacing strip, clearance and
export each take about 25 seconds to a few minutes instead of two more):

    ... --python art/scripts/fast_run.py -- run_cinema.py --lint IntroCampus
    ... --python art/scripts/fast_run.py -- review_strip.py IntroCampus noticer 12.3 13.7 out.png --cols=5 --step=0.1
    ... --python art/scripts/fast_run.py -- run_cinema.py --export IntroCampus

Not for run_anims.py (a bake wants the emotes built, since it exports the whole library) and not for a shot that uses
an emote clip from the package's own modules (none does today).
"""

import importlib
import os
import runpy
import sys
import types

SCRIPTS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPTS)
pkg = types.ModuleType("emotes")
pkg.__path__ = [os.path.join(SCRIPTS, "emotes")]
sys.modules["emotes"] = pkg

import cinema  # noqa: E402

shots_pkg = types.ModuleType("cinema.shots")
shots_pkg.__path__ = [os.path.join(SCRIPTS, "cinema", "shots")]
sys.modules["cinema.shots"] = shots_pkg
cinema.shots = shots_pkg
if os.environ.get("DG_PRE"):
    runpy.run_path(os.environ["DG_PRE"], run_name="dg_pre")
for mod in [m for m in os.environ.get("DG_ONLY", "intro_campus").split(",") if m]:
    importlib.import_module("cinema.shots." + mod)

argv = sys.argv[sys.argv.index("--") + 1:]
target = argv[0]
if not os.path.isabs(target):
    target = os.path.join(SCRIPTS, target)
sys.argv = [target, "--"] + argv[1:]
runpy.run_path(target, run_name="__main__")
