"""Contact sheets of animation frames for review (background Blender):

    blender -b --factory-startup --python art/scripts/review_anims.py -- out.png angle clip:time ...
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402
import preview  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    out, angle = argv[0], float(argv[1])
    shots = [(a.split(":")[0], float(a.split(":")[1]), angle) for a in argv[2:]]
    bpy.ops.wm.open_mainfile(filepath=os.path.join(common.BLEND, "Animations.blend"))
    arm = bpy.data.objects["R15"]
    world = bpy.context.scene.world
    path = preview.sheet(arm, shots, os.path.splitext(out)[0], columns=min(6, len(shots)), size=300)
    print("[review]", path)


main()
