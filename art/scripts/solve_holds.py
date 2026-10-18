"""Solves where emote props sit in the hand and writes it into src/shared/Anim/EmoteMeta.luau (background
Blender, it needs the rig):

    blender -b --factory-startup --python art/scripts/solve_holds.py [-- clip/Model ...]

Each prop emote in art/scripts/emotes/ lists HOLDS: for a prop, the body part it is welded to, the key pose
that matters (the fist at the bag, the crisp raised...), and where the prop's pivot must be then (torso frame)
and how it is turned. This works out the weld (`at`) that puts it there and rewrites the EmoteMeta line tagged
`-- hold: clip/Model`, so the game, the checks and the preview renders all hold it the same way.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import emotemeta  # noqa: E402
from emotes import kit  # noqa: E402


def all_holds():
    import emotes  # noqa: F401  (every family module)

    holds = {}
    for name in ("dances", "poses", "props", "strolls", "duos"):
        module = sys.modules.get("emotes." + name)
        holds.update(getattr(module, "HOLDS", {}) if module else {})
    return holds


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    holds = all_holds()
    wanted = argv or sorted(holds)
    text = open(emotemeta.META, encoding="utf-8").read()
    changed = 0
    for key in wanted:
        part, pose, position, rotation = holds[key]
        steps = kit.hold(part, pose, position, rotation)
        line = kit.luau_steps(steps)
        # (a hold is a prop's `at`, or the `to` of a move into a hand)
        pattern = re.compile(r"((?:at|to) = )\{.*?\}(,\s*-- hold: " + re.escape(key) + r"\b)")
        new, n = pattern.subn(lambda m: m.group(1) + line + m.group(2), text)
        if n != 1:
            print(f"[holds] {key}: no single `-- hold: {key}` line in EmoteMeta ({n} found)")
            continue
        if new != text:
            changed += 1
        text = new
        print(f"[holds] {key}: {line}")
    with open(emotemeta.META, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"[holds] {changed} changed")


main()
