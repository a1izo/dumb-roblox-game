"""Command-line entry to rebuild the animations and export them (background Blender):

    blender -b --factory-startup --python art/scripts/run_anims.py [-- --keep]

Rebuilds the rig and every action from anims.py, writes src/shared/Anim/Clips.luau and saves
art/blend/Animations.blend. With --keep, the actions in the saved .blend are exported as they
are (use this after editing curves by hand in Blender).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    blend = os.path.join(common.BLEND, "Animations.blend")
    if "--keep" in argv and os.path.exists(blend):
        bpy.ops.wm.open_mainfile(filepath=blend)
        import export_anims

        arm = bpy.data.objects["R15"]
    else:
        import anims
        import export_anims
        import rig

        arm = rig.build_rig()
        anims.build(arm)
    print("[anims]", export_anims.export(arm))
    common.save_blend("Animations.blend")


main()
