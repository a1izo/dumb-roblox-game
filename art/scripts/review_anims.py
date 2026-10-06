"""Contact sheets of animation frames for review (background Blender):

    blender -b --factory-startup --python art/scripts/review_anims.py -- out.png [--angle=35] [--cols=8] \
        [--size=300] clip[:t] clip@8 ...

`clip` shows `cols` frames spread over the clip (one row per clip); `clip:t` one frame at t seconds;
`clip@n` n frames spread over the clip. Angles are in degrees round the character (0 = front,
90 = the character's left side, -90 = right side).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import preview  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    out = argv[0]
    angle, cols, size = 35.0, 8, 300
    items = []
    for a in argv[1:]:
        if a.startswith("--angle="):
            angle = float(a.split("=")[1])
        elif a.startswith("--cols="):
            cols = int(a.split("=")[1])
        elif a.startswith("--size="):
            size = int(a.split("=")[1])
        else:
            items.append(a)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(common.BLEND, "Animations.blend"))
    arm = bpy.data.objects["R6"]
    shots = []
    for item in items:
        if ":" in item:
            name, t = item.split(":")
            shots.append((name, float(t), angle))
            continue
        name, _, n = item.partition("@")
        count = int(n) if n else cols
        action = bpy.data.actions[name]
        length = float(action["length"])
        loop = bool(action["loop"])
        for i in range(count):
            frac = i / count if loop else i / max(1, count - 1)
            shots.append((name, length * frac, angle))
    path = preview.sheet(arm, shots, os.path.splitext(os.path.basename(out))[0], columns=cols, size=size)
    print("[review]", path)


main()
